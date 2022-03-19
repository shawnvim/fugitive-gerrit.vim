" Location:     autoload/gerrit/fugitive.vim
" Maintainer:   Mark Korondi <korondi.mark@gmail.com>

" see: fugitive_browse_handlers
function! gerrit#fugitive#url(opts, ...) abort
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

