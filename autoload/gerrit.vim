" Location:     autoload/gerrit.vim
" Maintainer:   Mark Korondi <korondi.mark@gmail.com>

" see: fugitive_browse_handlers
function! gerrit#fugitive_url(opts, ...) abort
  if a:0 || type(a:opts) != type({})
    return ''
  endif

  let domains = get(g:, 'fugitive_gerrit_domains', [])
  let domains = map(domains, { _, domain ->  escape(split(domain, '://')[-1], '.') })

  let domain_pattern = join(domains, '\|')

  if a:opts.commit =~# '^\d\=$'
    let commit = a:opts.repo.rev_parse('HEAD')
  else
    let commit = a:opts.commit
  endif

  let [domain, repo] = matchlist(a:opts.remote,'^.*\(' . domain_pattern . '\)[^/]*/\zs\(.*\)$')[1:2]

  let url  = 'https://' . domain . '/plugins/gitiles/' . repo . '/+/' . commit . '/' . a:opts.path 

  if a:opts.line1 > 0
    let url .= '#' . a:opts.line1
  endif

  return url
endfunction

function! s:url_encode(str) abort
  return substitute(a:str, '[?@=&<>%#/:+[:space:]]', '\=submatch(0)==" "?"+":printf("%%%02X", char2nr(submatch(0)))', 'g')
endfunction

function! s:throw(string) abort
  throw 'gerrit: '.a:string
endfunction

function! gerrit#request(path, ...) abort
  if !executable('curl')
    call s:throw('cURL is required')
  endif
  let path = a:path
  let options = a:0 ? a:1 : {}
  let args = s:curl_arguments(path, options)

  " if exists('*FugitiveExecute') && v:version >= 800
  "   try
  "     if has_key(options, 'callback')
  "       return FugitiveExecute({'argv': args}, { r -> r.exit_status || r.stdout ==# [''] ? '' : options.callback(json_decode(join(r.stdout, ' '))) })
  "     endif
  "     let raw = join(FugitiveExecute({'argv': args}).stdout, ' ')
  "     return empty(raw) ? raw : json_decode(raw)
  "   catch /^fugitive:/
  "   endtry
  " endif
  let raw = system(join(map(copy(args), 's:shellesc(v:val)'), ' '))
  if has_key(options, 'callback')
    if !v:shell_error && !empty(raw)
      call options.callback(gerrit#JsonDecode(raw))
    endif
    return {}
  endif
  if raw ==# ''
    return raw
  else
    return json_decode(split(raw, '\n')[1])
  endif
endfunction

function! gerrit#change_id() abort
  for line in split(system('git log remotes/origin/HEAD..HEAD --format=%b'), '\n')
    let change_id = matchstr(line, '^Change-Id:\s\+\zs\([^ ]\+\)')
    if len(change_id) > 0
      return change_id
    endif
  endfor
  return v:null
endfunction

function! gerrit#comments(...) abort
  let latest_only = index(a:000, 'latest-only') != -1
  let include_resolved = index(a:000, 'include-resolved') != -1
  let include_checks = index(a:000, 'include-checks') != -1

  let change_ids = [gerrit#change_id()]
  let fqdn = FugitiveRemote().hostname
  let s:project = FugitiveRemote().path[1:]
  let branch = FugitiveHead(7)
  cexpr []

  if len(change_ids) == 0
    echom 'No reviews found'
    return
  endif

  let refs = []

  for change_id in [change_ids[0]]
    let detail = gerrit#request('https://' . fqdn . '/a/changes/?q=change:'.change_id.'&o=ALL_REVISIONS')[0]
    let change_full_id = detail.id
    for commit in keys(detail.revisions)
      let refs += [detail.revisions[commit].ref]
    endfor

    let comments = gerrit#request('https://' . fqdn . '/a/changes/' . change_full_id . '/comments')
    let robot_comments = gerrit#request('https://' . fqdn . '/a/changes/' . change_full_id . '/robotcomments')
    for filename in keys(robot_comments)
      if ! has_key(comments, filename)
        let comments[filename] = robot_comments[filename]
      endif
      call extend(comments[filename], robot_comments[filename])
    endfor

    let qitems = []
    let id_to_comment = {}

    for filename in keys(comments)
      if index(['/COMMIT_MSG', '/PATCHSET_LEVEL'], filename) != -1
        continue
      endif
      let root_comments = []
      for comment in comments[filename]
        let id_to_comment[comment['id']] = comment
      endfor
      for comment in comments[filename]
        let _c = comment
        let cnt = 0
        while get(_c, 'in_reply_to', '') !=# ''
          let _c = id_to_comment[_c['in_reply_to']]
          let cnt += 1
        endwhile
        if index(root_comments, _c) == -1
          let root_comments += [_c]
        endif
        if ! has_key(comment, 'unresolved')
          let comment['unresolved'] = 1
        endif
        if ! has_key(_c, 'count') || cnt >= _c['count']
          let _c['count'] = cnt
          let _c['error_type'] = comment['unresolved'] ? 'e' : 'n'
        endif
      endfor
      for comment in root_comments
        if ! include_resolved && comment['error_type'] ==# 'n'
          continue
        endif
        if latest_only && comment.commit_id != detail.current_revision
          continue
        endif
        if ! include_checks && has_key(comment, 'robot_id')
          continue
        endif
        if has_key(comment, 'range')
          let qitems += [{'str': 'GERRIT:'
                \ . '|' . 'fugitive://'. FugitiveGitDir() . '//' . comment.commit_id . '/' . filename
                \ . '|' . 'Patchset ' . comment.patch_set . ':' . filename
                \ . '|' . comment['range']['start_line'] . '-' . comment['range']['end_line']
                \ . '|' . comment['range']['start_character'] . '-' . comment['range']['end_character']
                \ . '|' . comment['error_type']
                \ . '|' . '@' . comment['author']['username'] . ' ' . comment['message'] . ' (' . comment['count'] . ' more)' 
                \ , 'filename': filename, 'patchset': comment.patch_set, 'line': comment['range']['start_line'], 'submission_id': detail['submission_id']}]
        else
          let qitems += [{'str': 'GERRIT:'
                \ . '|' . 'fugitive://'. FugitiveGitDir() . '//' . comment.commit_id . '/' . filename
                \ . '|' . 'Patchset ' . comment.patch_set . ':' . filename
                \ . '|' . comment['line']
                \ . '|' . comment['error_type']
                \ . '|' . '@' . comment['author']['username'] . ' ' . comment['message'] . ' (' . comment['count'] . ' more)' 
                \ , 'filename': filename, 'patchset': comment.patch_set, 'line': comment['line'], 'submission_id': detail['submission_id']}]
        endif
      endfor
    endfor
  endfor

  caddexpr map(copy(sort(qitems, {i1, i2 -> matchstr(i1.str, 'Patchset \zs[0-9]\+\ze') > matchstr(i2.str, 'Patchset \zs[0-9]\+\ze') })), {_,v -> v.str})
  copen

  let s:qitems = qitems
  call s:add_qf_mappings()

  call system('git fetch ' . FugitiveRemoteUrl() . ' ' . join(refs, ' '))
  return 
endfunction

function! <SID>gerrit_browse_qitem(linenr)
  let item = s:qitems[a:linenr - 1]
  call netrw#BrowseX('https://' . FugitiveRemote().hostname . '/c/' . s:project . '/+/' . item['submission_id'] . '/' . item['patchset'] . '/' . item['filename'] . '#' . item['line'], 1)
endfunction

function! s:add_qf_mappings()
  nnoremap <buffer> gx :call <SID>gerrit_browse_qitem(line('.'))<CR>
endfunction

augroup quickfix_mappings
  autocmd!
  au QuickFixCmdPost call s:remove_qf_mappings()
augroup END

function! gerrit#comments_args(A, L, P)
  return ['include-resolved', 'include-checks', 'latest-only']
endfunction

function! s:shellesc(arg) abort
  if a:arg =~# '^[A-Za-z0-9_/.-]\+$'
    return a:arg
  elseif &shell =~# 'cmd' && a:arg !~# '"'
    return '"'.a:arg.'"'
  else
    return shellescape(a:arg)
  endif
endfunction

function! s:curl_arguments(path, ...) abort
  let options = a:0 ? a:1 : {}
  let args = ['curl', '-q', '--silent']
  call extend(args, ['-H', 'Accept: application/json'])
  call extend(args, ['-H', 'Content-Type: application/json'])
  call extend(args, ['-A', 'gerrit.vim'])
  if has('win32') && filereadable(expand('~/.netrc'))
    call extend(args, ['--netrc-file', expand('~/.netrc')])
  else
    call extend(args, ['--netrc'])
  endif
  if has_key(options, 'method')
    call extend(args, ['-X', toupper(options.method)])
  endif
  for header in get(options, 'headers', [])
    call extend(args, ['-H', header])
  endfor
  if type(get(options, 'data', '')) != type('')
    call extend(args, ['-d', json_encode(options.data)])
  elseif has_key(options, 'data')
    call extend(args, ['-d', options.data])
  endif
  call add(args, a:path)
  return args
endfunction

let &errorformat = 'GERRIT:|%f|%o|%l|%t|%m,' . &errorformat
let &errorformat = 'GERRIT:|%f|%o|%l-%e|%c-%k|%t|%m,' . &errorformat

augroup quickfix
  autocmd!
  au FileType qf syn match qfUsername /@[^ ]\+/
  au FileType qf syn match qfFileName /^[^|]*/ nextgroup=qfSeparator contains=qfPatchset
  au FileType qf syn match qfPatchset /Patchset [0-9]\+/ contained
augroup END

" gerrit#Browse() opens the browser pointing to gerrit at the latest ChangeId 
" note: netrw required
function! gerrit#browse()
  call netrw#BrowseX('https://' . FugitiveRemote().hostname . '/#/q/' . gerrit#change_id(), 1)
endfunction

hi link qfUsername Constant
hi link qfPatchset Statement
