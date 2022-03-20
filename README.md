# fugitive-gerrit.vim

A plugin to fugitive.vim for [gerrit](https://www.gerritcodereview.com/) support

## Features

* **`:GerritChanges`** populates the QuickFix window with change request in the current repository

    * Filtering works e.g `:GerritChanges owner:myusername`

    * **`gx`** on a change request in the QuickFix window opens it in on gerrit web

    * **`<Enter>`** on a change request in the QuickFix window checks it out locally

* **`:GerritComments`** populates the QuickFix window with (unresolved) comments for the current ChangeId

    Note: `<Enter>` on a commentin the QuickFix window opens the readonly fugitive object; to edit
    the file's latest version, use [`:Gedit`][]
    afterwards

    * `:GerritComments include-resolved` includes already resolved comments too

    * `:GerritComments include-checks` includes comments from automated systems (linters etc)

    * **`gx`** on a comment in the QuickFix window opens the comment on gerrit web

[`:Gedit`]: https://github.com/tpope/vim-fugitive/blob/46652a304f0b89f36d70cee954d77e467ec0f6de/doc/fugitive.txt#L138


* **[`:GBrowse`][]** to browse a file / selected line on gerrit web.

    To enable for your domain, add the following configuration to your vimrc:

    ```vim
    let g:fugitive_gerrit_domains = ['gerrit.mycompany.com']
    ```

[`:GBrowse`]: https://github.com/tpope/vim-fugitive/blob/46652a304f0b89f36d70cee954d77e467ec0f6de/doc/fugitive.txt#L234

## Installation

0. Prerequisites

    In order to use this plugin, you will need `curl`, `git`, and [`vim-fugitive`][] installed.

1. Use your favorite vim plugin manager to install fugitive-gerrit.vim

    As an example with [Vim-Plug](https://github.com/junegunn/vim-plug), add the GitHub path for this repository to your `~/.vimrc`:

    ```vim
    Plug 'tpope/vim-fugitive'
    Plug 'kmARC/fugitive-gerrit.vim'
    ```

    Then run the command `:PlugInstall` in Vim. See the Vim-Plug documentation for more information.

2. Set up [`.netrc`][] for gerrit authentication

    1. Head over to your gerrit HTTP credential settings `https://gerrit.mycompany.com/settings/#HTTPCredentials`

    2. Take note of your username 

    3. Generate a new password

    4. Amend your `$HOME/.netrc` with your `<username>` and newly generated `<password>`:

        ```netrc
        machine gerrit.mycompany.com login <username> password <password>
        ```

[`.netrc`]: https://curl.se/docs/manual.html#netrc
[`vim-fugitive`]: https://github.com/tpope/vim-fugitive

## Configuration

```vim
let g:gerrit_wrap_comments = 1
```
* Set to `0` to disable wrapping comments in the QuickFix window. Comments tend to be longer than
what would fit in one line, therefore the default setting is to wrap them into multiple lines.


## Credits:
* [vim-fugitive](https://github.com/tpope/vim-fugitive)
* [fugitive-gitee](https://github.com/LinuxSuRen/fugitive-gitee.vim/)

