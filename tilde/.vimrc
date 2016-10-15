" General
" ========

" we're using vim, not vi
set nocompatible

" http://superuser.com/questions/356970/smooth-scrolling-for-vim-in-mac-terminal-iterm
set mouse=niv "or set mouse=a

" set command history to 500
set history=500

set wildignore+=*/tmp/*,*.so,*.swp,*.zip     " MacOSX/Linux
set wildignore+=*\\tmp\\*,*.swp,*.zip,*.exe  " Windows

" change cursor shape in insert mode
" such a lovely thing :)

" OS X
if exists('$TMUX')
    let &t_SI = "\<Esc>]50;CursorShape=1\x7"
    let &t_EI = "\<Esc>]50;CursorShape=0\x7"
else
    let &t_SI = "\<Esc>]50;CursorShape=1\x7"
    let &t_EI = "\<Esc>]50;CursorShape=0\x7"
endif

syntax enable

" =================
" UI/Colours
" =================

" highlight current line cursor is on
set cursorline

" use relative numbers
set number
set relativenumber

" show current position
set ruler

" height of the command bar
set cmdheight=2

" make backspace act like backspace
set backspace=eol,start,indent
set whichwrap+=<,>,h,l

" Ignore case when searching
set ignorecase

" When searching try to be smart about cases
set smartcase

" Highlight search results
set hlsearch

" Use incremental search
set incsearch

" don't redraw while executing macros (good performance config)
set lazyredraw

" for regex
set magic

" Show matching brackets when the text indicator is over them
set showmatch
" How many tenths of a second to blink when matching brackets
set mat=2

" No annoying sounds on errors
set noerrorbells
set visualbell
set t_vb=
set tm=500

" Always show the status line
set laststatus=2

" ====================
" Text/editing-related
" ===================

" auto read files when changed from other programs
set autoread

" Use spaces instead of tabs
set expandtab

" Be smart when using tabs,
" namely to backspace the correct amount of spaces
set smarttab

" Set the tab width
set shiftwidth=4

" \t size
set tabstop=4

" Set auto-indentation
set autoindent

" Wrap lines
set wrap

" Linebreak on 500 characters
set lbr
set tw=500

" store swap files elsewhere
set dir=~/.vim/backup/swap//,~/.vim/backup/tmp//,~/.vim/backup//,.

" automatically change to the dir where the file is
"set autochdir

" use some spell checking :)
" for code, this will only spell check
" within comments
set spell spelllang=en_au

" code folding
set foldmethod=syntax
set foldlevel=0

" =============================
" Re-maps (not plugin specific)
" =============================

map j gj
map k gk

" normal re-map leader-p to 
" paste from the system clipboard
nmap <leader>p "+p

" insert re-map CTRL-p to paste 
" from the clipboard
imap <C-p> <C-r>+

" yank re-map for system clipboard
nmap Y "+y
nmap YY "+yy
vmap Y "+y

" toggle highlight
map <leader><cr> :set hls!<cr>

" Smart way to move between windows
map <C-j> <C-W>j
map <C-k> <C-W>k
map <C-h> <C-W>h
map <C-l> <C-W>l

" q for buffers is <leader>q
map <leader>q :bd<cr>
map <leader>qa :1,1000 bd!<cr>

nnoremap <F1> <nop>
nnoremap Q <nop>
nnoremap K <nop>
vnoremap K <nop>

" delete word in insert mode
imap <C-b> <Esc>ldw

" ========
" Plugins
" ========

call plug#begin('~/.vim/plugged')

""" Colour scheme
Plug 'w0ng/vim-hybrid'

""" Lang
Plug 'moll/vim-node', { 'for' : 'javascript' }
Plug 'wting/rust.vim', { 'for' : 'rust' }

""" Syntax-checking/auto-completion
Plug 'phildawes/racer', { 'do': 'cargo build --release', 'for': 'rust' }
Plug 'scrooloose/syntastic', { 'on': 'SyntasticCheck' }
Plug 'Valloric/YouCompleteMe', { 'do': './install.sh --clang-completer', 'for': ['c', 'cpp', 'objc', 'objcpp', 'cs', 'python', 'rust'] }

""" Snippets
Plug 'SirVer/ultisnips'
Plug 'miguelmartin75/ultisnips-snippets'

""" Text-editing/manipulation/movement
Plug 'ervandew/supertab'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'joequery/Stupid-EasyMotion'
Plug 'majutsushi/tagbar', { 'on': 'TagbarToggle' }

""" File Browsing
Plug 'scrooloose/nerdtree', { 'on' : ['NERDTree', 'NERDTreeToggle'] }
Plug 'kien/ctrlp.vim', { 'on': 'CtrlP' }

""" Git
Plug 'tpope/vim-fugitive'

call plug#end()

" ==============
" Plugin config
" ==============

augroup load_insert_mode_plugs
    autocmd!
    autocmd InsertEnter * call plug#load('ultisnips') | autocmd! load_insert_mode_plugs
augroup END

" NerdTree
" ----------

let g:NERDShutUp=1

let NERDTreeShowBookmarks=1
let NERDTreeIgnore=['\.DS_Store', '\.pyc', '\~$', '\.swo$', '\.swp$', '\.git', '\.hg', '\.svn', '\.bzr']
let NERDTreeChDirMode=0
let NERDTreeQuitOnOpen=1
let NERDTreeMouseMode=2
let NERDTreeShowHidden=1
let NERDTreeKeepTreeInNewTab=1
let g:nerdtree_tabs_open_on_gui_startup=0

" Ultisnips
" ---------
let g:UltiSnipsSnippetsDir = "~/.vim/plugged/ultisnips-snippets/UltiSnips"

" YCM
" ----

let g:ycm_min_num_of_chars_for_completion = 1
let g:ycm_confirm_extra_conf = 0

" http://stackoverflow.com/a/18685821
" make YCM compatible with UltiSnips (using supertab)
let g:ycm_key_list_select_completion = ['<C-n>', '<Down>']
let g:ycm_key_list_previous_completion = ['<C-p>', '<Up>']
let g:SuperTabDefaultCompletionType = 'context'

" remove the preview window automatically
let g:ycm_autoclose_preview_window_after_insertion = 1

" better key bindings for UltiSnipsExpandTrigger
let g:UltiSnipsExpandTrigger = "<tab>"
let g:UltiSnipsJumpForwardTrigger = "<tab>"
let g:UltiSnipsJumpBackwardTrigger = "<s-tab>"

"let g:ycm_cache_omnifunc = 0
let g:ycm_semantic_triggers =  {
\   'c' : ['->', '.'],
\   'objc' : ['->', '.'],
\   'ocaml' : ['.', '#'],
\   'cpp,objcpp' : ['->', '.', '::'],
\   'perl' : ['->'],
\   'php' : ['->', '::'],
\   'cs,java,javascript,d,python,perl6,scala,vb,elixir,go' : ['.'],
\   'vim' : ['re![_a-zA-Z]+[_\w]*\.'],
\   'ruby' : ['.', '::'],
\   'lua' : ['.', ':'],
\   'erlang' : [':'],
\   'rust' : ['::', '.'],
\ }

" CtrlP
" ------

" have to setup a remapping 
" because with vim-plug, CtrlP is
" not initialised, lol.
nmap <c-p> :CtrlP<CR>
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'

" Hybrid
" -------

" colour scheme
if has("unix")
    let s:uname = system("uname -s")
    if s:uname == "Linux\n" || $SSH_CONNECTION
        let g:hybrid_use_Xresources = 1
    elseif s:uname == "Darwin\n"
        let g:hybrid_use_iTerm_colors = 1
    endif
endif

" must set the color scheme here, in order for vim 
" load it properly
silent! colorscheme hybrid

set background=dark


" ==========================
" Re-maps (plugin specific)
" ==========================

" NerdTree
" --------
map <C-e> :NERDTreeToggle<CR>:NERDTreeMirror<CR>


" Stupid-EasyMotion
" ------------------
map <C-o> <Leader><Leader>w
map <C-i> <Leader><Leader>W

" Tagbar
" ------
nmap <Leader>t :TagbarToggle<CR> 

" ==============
" Auto-commands
" ==============

" Remember info about open buffers on close
set viminfo^=%

augroup text_editing:
    autocmd!
    " Return to last edit position when opening files (You want this!)
    autocmd BufReadPost *
          \ if line("'\"") > 0 && line("'\"") <= line("$") |
     \   exe "normal! g`\"" |
     \ endif

    autocmd FileType text,markdown setlocal tw=100
augroup END
