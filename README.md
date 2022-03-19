# fugitive-gerrit.vim

An extension to fugitive.vim for [gerrit](https://www.gerritcodereview.com/) support

## Features

* Adds support to browse a file / selected line on gerrit web.

    Use fugitive's [`:GBrowse`](https://github.com/tpope/vim-fugitive/blob/46652a304f0b89f36d70cee954d77e467ec0f6de/doc/fugitive.txt#L234) command.

    To enable for your domain, add the following configuration to your vimrc:

    ```vim
    let g:fugitive_gerrit_domains = ['gerrit.mycompany.com', 'review.opendev.org']
    ```

* `:GerritComments` populates the QuickFix window with (unresolved) comments for the current ChangeId

    * `:GerritComments include-resolved` includes already resolved comments too

    * `:GerritComments include-checks` includes comments from automated systems (linters etc)

* Pressing `gx` on an element of the QuickFix window opens the comment on gerrit web

## Credits:
* [vim-fugitive](https://github.com/tpope/vim-fugitive)
* [fugitive-gitee](https://github.com/LinuxSuRen/fugitive-gitee.vim/)

