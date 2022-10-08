" Location:     autoload/gerrit/fugitive.vim
" Maintainer:   Mark Korondi <korondi.mark@gmail.com>

" see: fugitive_browse_handlers
function! gerrit#fugitive#url(opts, ...) abort

    if a:0 || type(a:opts) != type({})
        return ''
    endif


    if a:opts.type =~# 'commit'
        let commit = a:opts.commit
    elseif  a:opts.type =~# 'ref'
        let commit = a:opts.commit
    elseif a:opts.type =~# 'tree'
        let commit = expand("<cword>") 
    else
        let commit = gerrit#change_id()
    endif

    let url  = 'https://' . gerrit#domain() . '/#/q/' . commit

    return url
endfunction


