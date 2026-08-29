" Vim configuration

set nocompatible
set encoding=utf-8
set history=1000
set backspace=indent,eol,start

" UI
if has('syntax')
  syntax on
  filetype plugin indent on

  " Statusline highlight groups
  highlight User1 ctermfg=green ctermbg=black
  highlight User2 ctermfg=yellow ctermbg=black
  highlight User3 ctermfg=red ctermbg=black
  highlight User4 ctermfg=blue ctermbg=black
  highlight User5 ctermfg=white ctermbg=black
endif

set ruler
set showmode
set laststatus=2

" Minimal editing
set tabstop=4
set shiftwidth=4
set expandtab
set autoindent

" Minimal search
set incsearch
set ignorecase
set smartcase
set wildmenu

" Keep git branch support used by the statusline.
function! SetGitBranch() abort
  silent let l:branch = system("git rev-parse --abbrev-ref HEAD 2>/dev/null | tr -d '\n'")
  let b:git_branch = strlen(l:branch) > 0 ? 'git[' . l:branch . ']' : ''
endfunction

if has('autocmd')
  augroup GetBranch
    autocmd!
    autocmd BufRead,BufNewFile * call SetGitBranch()
  augroup END
endif

" Statusline configuration
set statusline=
set statusline+=%1*\ %n\ %*
set statusline+=%5*%{&ff}%*
set statusline+=%3*%y%*
set statusline+=%4*\ %<%F%*
set statusline+=%2*%m%*
set statusline+=%1*%=%5l%*
set statusline+=%2*/%L%*
set statusline+=%1*%4v\ %*
set statusline+=%4*\ %{get(b:,'git_branch','')}%*

" FZF file finder
let mapleader = " "
nnoremap <leader>p :FZF<CR>
