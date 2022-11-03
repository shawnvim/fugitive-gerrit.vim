" Location:     autoload/gerrit.vim
" Maintainer:   Mark Korondi <korondi.mark@gmail.com>


function gerrit#domain()
    let gitdir = FugitiveGitDir()
    let domain = system('grep pushurl ' . FugitiveGitDir() . "/config | awk -F '://|:' '{printf $2}'")
    if domain == ""
        let domain = system('grep url ' . FugitiveGitDir() . "/config | awk -F '://|:' '{printf $2}'")
    endif
    echom 'Use domain: ' . domain
    return domain
endfunc

" " gerrit#Browse() opens the browser pointing to gerrit at the latest ChangeId  
" " note: netrw required 
" function! gerrit#browse() 
"     call netrw#BrowseX('https://' . gerrit#domain() . '/#/q/' . gerrit#change_id(), 1) 
" endfunction 

" Purpose:
"   Find current gerrit ChangeId.
" Returns:
"   result: current ChangeId or v:null if not found
function! gerrit#change_id() abort
    let l:cli = get(g:, 'fugitive_gerrit_cli', 'git log -1 --format=%b')
    for line in split(system(l:cli), '\n')
        let change_id = matchstr(line, 'Change-Id\s\+:\s\+\zs\([^ ]\+\)')
        if len(change_id) > 0
            return change_id
    endif
  endfor
  return v:null
endfunction

function! gerrit#comments_args(A, L, P)
  let choices = ['include-resolved', 'include-checks', 'latest-only']
  return filter(choices, {k,v->stridx(v,a:A) == 0})
endfunction

function! gerrit#comments(...) abort
  let s:latest_only = index(a:000, 'latest-only') != -1
  let s:include_resolved = index(a:000, 'include-resolved') != -1
  let s:include_checks = index(a:000, 'include-checks') != -1

  let s:fqdn = gerrit#domain()
  let s:change_id = gerrit#change_id()
  let s:remaining_comment_callbacks = 1 + s:include_checks

  if s:change_id is 'None'
    echo 'No reviews found'
    return
  endif

  let s:comments = {}

  function! s:populate_quickfix()
    let s:comment_qitems = []
    let id_to_comment = {}


    for filename in keys(s:comments)
      if index(['/COMMIT_MSG', '/PATCHSET_LEVEL'], filename) != -1
        continue
      endif
      let root_comments = []
      for comment in s:comments[filename]
        let id_to_comment[comment['id']] = comment
      endfor
      for comment in s:comments[filename]
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
"         if ! s:include_resolved && comment['error_type'] ==# 'n'
"           continue
"         endif
"         if s:latest_only && comment.commit_id != s:detail.current_revision
"           continue
"         endif
"         if ! s:include_checks && has_key(comment, 'robot_id')
"           continue
"         endif
        let s:comment_qitems += [{'str': s:comment2cexpr(filename, comment), 'comment': comment, 'detail': s:detail, 'filename': filename}]
      endfor
    endfor

    cexpr []
    caddexpr map(copy(sort(s:comment_qitems, {i1, i2 -> i1['comment']['patch_set'] < i2['comment']['patch_set']})), {_,v -> v.str})
    copen

    let &l:wrap = g:gerrit_wrap_comments

    nnoremap <buffer> gx :call <SID>gerrit_browse_comment_qitem(line('.'))<CR>
  endfunction

  function! s:comments_cb(new_comments)
    for filename in keys(a:new_comments)
      if ! has_key(s:comments, filename)
        let s:comments[filename] = a:new_comments[filename]
      endif
      call extend(s:comments[filename], a:new_comments[filename])
    endfor

    let s:remaining_comment_callbacks -= 1

    if s:remaining_comment_callbacks == 0
      call s:populate_quickfix()
    endif
  endfunction

  function! s:detail_cb(details)
    let s:detail = a:details[0]

    call s:request('https://' . s:fqdn . '/a/changes/' . s:detail.id . '/comments', {'callback': function('s:comments_cb')})
    if s:include_checks
      call s:request('https://' . s:fqdn . '/a/changes/' . s:detail.id . '/robotcomments', {'callback': function('s:comments_cb')})
    endif

    " Ensure that the refs seen here are going to be available locally
    let git_fetch_cmd = ['git', 'fetch', FugitiveRemoteUrl()[7:]] + map(values(s:detail.revisions), {_,v -> v.ref})
    if exists('*FugitiveExecute') && v:version >= 800
      try
        call FugitiveExecute({'argv': git_fetch_cmd}, {->v:null} )
      catch /^fugitive:/
      endtry
    else
      call system(join(git_fetch_cmd, ' '))
    endif
  endfunction

  " Currently handle only one (current) ChangeId
  call s:request('https://' . s:fqdn . '/a/changes/?q=change:'.s:change_id.'&o=ALL_REVISIONS', {'callback': function('s:detail_cb')})

endfunction

function s:comment2cexpr(filename, comment)
    let gitdir = fnamemodify(FugitiveGitDir(),':h')
    let cexpr = 'GERRITCOMMENT:'
        \ . '|' . gitdir . '/' . a:filename 
        \ . '|' . 'Patchset ' . a:comment['patch_set'] . ':' .  a:filename "substitute(a:filename, '\(.\)[^/]\+/', '\1/', 'g')
"         \ . '|'  . 'fugitive://'. FugitiveGitDir() . '//' . a:comment['id'] . '/'. a:filename 
  if has_key(a:comment, 'range')
    let cexpr = cexpr
        \ . '|' . a:comment['range']['start_line'] . '-' . a:comment['range']['end_line']
        \ . '|' . a:comment['range']['start_character'] . '-' . a:comment['range']['end_character']
  else
    let cexpr = cexpr
        \ . '|' . a:comment['line']
  endif
    let cexpr = cexpr
        \ . '|' . a:comment['error_type']
        \ . '|' . '@' . a:comment['author']['username'] . ' ' . a:comment['message'] . ' (' . a:comment['count'] . ' more)' 
  return cexpr
endfunction

function! <SID>gerrit_browse_comment_qitem(linenr)
    let item = s:comment_qitems[a:linenr - 1]
    let project = gerrit#change_id()
    if has_key(item['comment']['range'], 'end_line')
        let line_range = item['comment']['range']['end_line']
    else
        let line_range = item['comment']['range']['line']
    endif

  call netrw#BrowseX('https://' . gerrit#domain() . '/c/' . item['detail']['_number'] . '/' . item['comment']['patch_set'] . '/' . item['filename'] . '@' . line_range, 1)
endfunction

function! gerrit#changes_args(A, L, P)
  let choices = ['include-merged']
  return filter(choices, {k,v->stridx(v,a:A) == 0})
endfunction

function! gerrit#changes(...)
  let s:fqdn = gerrit#domain()
  let s:change_qitems = []

  function! s:changes_cb(changes)
    for change in a:changes
      let s:change_qitems += [{'str': s:change2cexpr(change), 'change': change}]
    endfor


    cexpr []
    caddexpr map(copy(s:change_qitems), {_,v -> v.str})
    copen

    setlocal nowrap

    nnoremap <buffer> gx   :call <SID>gerrit_browse_change_qitem(line('.'))<CR>
    nnoremap <buffer> <CR> :call <SID>gerrit_fetch_change(line('.'))<CR>
  endfunction

  call s:request('https://' . s:fqdn . '/a/changes/?q=' . (a:0>0?a:1.'+':'') . gerrit#change_id() . '&o=DETAILED_ACCOUNTS&o=CURRENT_REVISION', {'callback': function('s:changes_cb')})
endfunction

function s:change2cexpr(change) abort
  let status = has_key(a:change, 'mergeable') && ! a:change['mergeable'] ? 'MCONFL' : a:change['status']
  let status = status ==? 'ABANDONED' ? 'ABANDN' : status
  let cexpr = 'GERRITCHANGE:'
        \ . '|' . strftime('%b %d %H:%M', strptime('%Y-%m-%d %H:%M:%S', a:change['updated'])) . ' ' . printf('%6s', status)
        \ . '|' . '@' . a:change['owner']['username'] . ' ' . a:change['subject']
  return cexpr
endfunction

function! <SID>gerrit_browse_change_qitem(linenr)
  let item = s:change_qitems[a:linenr - 1]
"   let project = gerrit#change_id()
  call netrw#BrowseX('https://' . gerrit#domain() . '/c/' . item['change']['_number'], 1)
endfunction

function! <SID>gerrit_fetch_change(linenr)
  bdelete
  let item = s:change_qitems[a:linenr - 1]
"   let ref = values(values(item['change']['revisions'])[0]['fetch'])[0]['ref']
"   echom ref
  call execute('Git fetch origin | Git checkout FETCH_HEAD | GerritComments include-resolved', 'silent')
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
  let args = ['curl', '-q', '--silent', '--location']
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

function! s:throw(string) abort
  throw 'gerrit: '.a:string
endfunction

function! s:request(path, ...) abort
  if !executable('curl')
    call s:throw('cURL is required')
  endif
  let path = a:path
  let options = a:0 ? a:1 : {}
  let args = s:curl_arguments(path, options)

  if exists('*FugitiveExecute') && v:version >= 800
      try
          let raw = FugitiveExecute({'argv': args}).stdout
          if raw[0] =~# 'Unauth'
              echom 'Unauthorized Gerrit account, please check your account info in ~/.netrc'
              return
          endif
          if has_key(options, 'callback')
              return FugitiveExecute({'argv': args}, { r -> r.exit_status || r.stdout ==# [''] ? '' : options.callback(empty(r.stdout) ? r.stdout : json_decode(r.stdout[1])) })
          endif
          return empty(raw) ? raw : json_decode(raw[1])
      catch /^fugitive:/
      endtry
  endif

  let raw = system(join(map(copy(args), 's:shellesc(v:val)'), ' '))


  if has_key(options, 'callback')
    if !v:shell_error && !empty(raw)
      call options.callback(json_decode(split(raw, '\n')[1]))
    endif
    return {}
  endif

  return empty(raw) ? raw : json_decode(split(raw, '\n')[1])
endfunction


augroup quickfix
  autocmd!
  au FileType qf syn match qfUsername /@[^ ]\+/
  au FileType qf syn match qfFileName /^[^|]*/ nextgroup=qfSeparator contains=qfPatchset,qfStatusNew,qfStatusConflict,qfStatusMerged
  au FileType qf syn match qfPatchset /Patchset [0-9]\+/ contained
  au FileType qf syn match qfStatusNew      /   NEW/ contained
  au FileType qf syn match qfStatusConflict /MCONFL/ contained
  au FileType qf syn match qfStatusMerged   /MERGED/ contained
augroup END

let &errorformat = 'GERRITCOMMENT:|%f|%o|%l|%t|%m,' . &errorformat
let &errorformat = 'GERRITCOMMENT:|%f|%o|%l-%e|%c-%k|%t|%m,' . &errorformat
let &errorformat = 'GERRITCHANGE:|%f|%m,' . &errorformat

hi link qfUsername Constant
hi link qfPatchset Statement
hi link qfStatusNew      Comment
hi link qfStatusConflict Error
hi link qfStatusMerged   DiffAdd

let g:gerrit_wrap_comments = get(g:, 'gerrit_wrap_comments', 1)

