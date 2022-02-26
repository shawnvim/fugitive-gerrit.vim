function! s:function(name) abort
  return function(substitute(a:name,'^s:',matchstr(expand('<sfile>'), '<SNR>\d\+_'),''))
endfunction

function! s:gerrit_url(opts, ...) abort
  if a:0 || type(a:opts) != type({})
    return ''
  endif
  let domains = exists('g:fugitive_gerrit_domains') ? g:fugitive_gerrit_domains : []
  let domain_pattern = 'gerrit.com'
  for domain in domains
    let domain_pattern .= '\|' . escape(split(domain, '://')[-1], '.')
  endfor
  if a:opts.commit =~# '^\d\=$'
    let commit = a:opts.repo.rev_parse('HEAD')
  else
    let commit = a:opts.commit
  endif
  let repo = matchstr(a:opts.remote,'^.*\(' . domain_pattern . '\)[^/]*/\zs\(.*\)$')
  let url = "https://" . g:fugitive_gerrit_domains[0] . "/plugins/gitiles/"
  let url .= repo . "/+/" . commit . "/"
  let url .= a:opts.path 
  if a:opts.line1 > 0
    let url .= "#" . a:opts.line1
  endif
  return url
endfunction

if !exists('g:fugitive_gerrit_handlers')
  let g:fugitive_gerrit_handlers = []
endif

call insert(g:fugitive_browse_handlers, s:function('s:gerrit_url'))
