# fugitive-gerrit.vim

An extension to fugitive.vim for [gerrit](https://www.gerritcodereview.com/) support

## Features

* **`:GerritComments`** populates the QuickFix window with (unresolved) comments for the current ChangeId

    Note: `<Enter>` on a commentin the QuickFix window opens the readonly fugitive object; to edit
    the file's latest version, use [`:Gedit`][]
    afterwards

    * `:GerritComments include-resolved` includes already resolved comments too

    * `:GerritComments include-checks` includes comments from automated systems (linters etc)

[`:Gedit`]: https://github.com/tpope/vim-fugitive/blob/46652a304f0b89f36d70cee954d77e467ec0f6de/doc/fugitive.txt#L138

* **`gx`** on a comment in the QuickFix window opens the comment on gerrit web

* **[`:GBrowse`][]** to browse a file / selected line on gerrit web.

    To enable for your domain, add the following configuration to your vimrc:

    ```vim
    let g:fugitive_gerrit_domains = ['gerrit.mycompany.com']
    ```

[`:GBrowse`]: https://github.com/tpope/vim-fugitive/blob/46652a304f0b89f36d70cee954d77e467ec0f6de/doc/fugitive.txt#L234

## Configuration

```vim
let g:gerrit_wrap_comments = 1
```
* Set to `0` to disable wrapping comments in the QuickFix window. Comments tend to be longer than
what would fit in one line, therefore the default setting is to wrap them into multiple lines.


## Credits:
* [vim-fugitive](https://github.com/tpope/vim-fugitive)
* [fugitive-gitee](https://github.com/LinuxSuRen/fugitive-gitee.vim/)

