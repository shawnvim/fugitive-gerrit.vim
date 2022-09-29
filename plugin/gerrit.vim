let s:cpo_save = &cpoptions
set cpoptions&vim

if !exists('g:fugitive_browse_handlers')
  let g:fugitive_browse_handlers = []
endif

if index(g:fugitive_browse_handlers, function('gerrit#fugitive#url')) < 0
  call insert(g:fugitive_browse_handlers, function('gerrit#fugitive#url'))
endif

" command! GBrowseGerrit :GBrowse 

command! -complete=customlist,gerrit#comments_args -nargs=* GerritComments :call gerrit#comments(<f-args>)
command! -complete=customlist,gerrit#changes_args  -nargs=* GerritChanges  :call gerrit#changes(<f-args>)

let &cpoptions = s:cpo_save
unlet s:cpo_save
