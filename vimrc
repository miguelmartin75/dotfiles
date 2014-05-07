" =======
" General
" =======

" http://superuser.com/questions/356970/smooth-scrolling-for-vim-in-mac-terminal-iterm
set mouse=niv "or set mouse=a
set clipboard=unnamed

set history=500

" auto read files when changed from other programs
set autoread

" Use 4 spaces instead of tabs
set expandtab
set tabstop=4
set shiftwidth=4

" for go syntax highlighting
set rtp+=$GOROOT/misc/vim

filetype plugin indent on
syntax on

" =============
" Vundle Setup
" =============

set nocompatible
filetype off

set rtp+=~/.vim/bundle/vundle
call vundle#rc()

" Let Vundle manage Vundle, required!
Bundle 'gmarik/vundle'

" ====================
" My bundes (plug-ins)
" ====================

" for my colour scheme addiction
Bundle 'flazz/vim-colorschemes'                

" the snippet engine I am using 
Bundle 'SirVer/ultisnips'

" for the actual snippets
Bundle 'honza/vim-snippets'
 
" for file browsing
Bundle 'scrooloose/nerdtree'

" for surrounding text with {}, (), "", <tag></tag>, etc.
Bundle 'tpope/vim-surround'

" for using '.' with remaps (specifically for vim-surround)
Bundle 'tpope/vim-repeat'

Bundle 'wting/rust.vim'

" for auto-completion
"Bundle 'Valloric/YouCompleteMe'

" for easy git commands in Vim
"Bundle 'tpope/vim-fugitive'

" fast motion within a line 
"Bundle 'joequery/Stupid-EasyMotion'            

" for easy HTML writing
"Bundle 'rstacruz/sparkup', {'rtp': 'vim/'}     

"Bundle 'ervandew/supertab'

" for syntax checking
"Bundle 'scrooloose/syntastic'                  

" ===================
" Config for plug-ins
" ===================

" NerdTree
let g:NERDShutUp=1

map <C-e> :NERDTreeToggle<CR>:NERDTreeMirror<CR>
map <leader>e :NERDTreeFind<CR>
nmap <leader>nt :NERDTreeFind<CR>

let NERDTreeShowBookmarks=1
let NERDTreeIgnore=['\.pyc', '\~$', '\.swo$', '\.swp$', '\.git', '\.hg', '\.svn', '\.bzr']
let NERDTreeChDirMode=0
let NERDTreeQuitOnOpen=1
let NERDTreeMouseMode=2
let NERDTreeShowHidden=1
let NERDTreeKeepTreeInNewTab=1
let g:nerdtree_tabs_open_on_gui_startup=0

" ======
"   UI
" ======

" Set (relative) line numbers
set relativenumber

" move the file along when moving using j/k
set so=7

" Use wild menu
set wildmenu
set wildignore=*.o,*~,~.pyc

" Show current position
set ruler

" Height of the command bar
set cmdheight=2

" A buffer becomes hidden when it is abandoned
set hid

" Congigure backspace so it acts as it should act
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

" =======
" Colours
" =======

" Enable syntax
syntax enable

" Set the colour scheme
colorscheme inkpot

" Set utf8 as the standard encoding
set encoding=utf8

" Use Unix as the standard file-type
set ffs=unix,dos,mac


" ===================
" Files/back-ups/etc.
" ===================

" Turn back-up off, since most of this stuff is in SVN, git etc.
set nobackup
set nowb
set noswapfile

" Change directory to the current buffer when opening files.
set autochdir

" =====================
" Text/editing-related
" =====================

" Use spaces instead of tabs
set expandtab

" Be smart when using tabs
set smarttab

" Set the tab width
set shiftwidth=4
set tabstop=4

" Linebreak on 500 characters
set lbr
set tw=500

" Set auto-indentation/smart-indentation
set autoindent
"set smartindent

" Wrap lines
set wrap

" =============================================
" Moving around - tabs, windows, buffers, etc.
" =============================================

" Treat long lines as break lines
map j gj
map k gk

" Map space to search and CTRL-space to backwards search
map <space> /
map <c-space> ?

" Disable highlight when <leader><cr> is pressed
map <silent> <leader><cr> :noh<cr>

" " Smart way to move between windows
map <C-j> <C-W>j
map <C-k> <C-W>k
map <C-h> <C-W>h
map <C-l> <C-W>l

" Close the current buffer
map <leader>bd :Bclose<cr>

" Close all the buffers
map <leader>ba :1,1000 bd!<cr>

" Useful mappings for managing tabs
map <leader>tn :tabnew<cr>
map <leader>to :tabonly<cr>
map <leader>tc :tabclose<cr>
map <leader>tm :tabmove

" Opens a new tab with the current buffer's path
" Super useful when editing files in the same directory
map <leader>te :tabedit <c-r>=expand("%:p:h")<cr>/

" Switch CWD to the directory of the open buffer
map <leader>cd :cd %:p:h<cr>:pwd<cr>

" Specify the behavior when switching between buffers 
try
    set switchbuf=useopen,usetab,newtab
    set stal=2
catch
endtry

" Return to last edit position when opening files (You want this!)
    autocmd BufReadPost *
          \ if line("'\"") > 0 && line("'\"") <= line("$") |
     \   exe "normal! g`\"" |
     \ endif
" Remember info about open buffers on close
set viminfo^=%

" =============
" Status Line
" ============

" Always show the status line
set laststatus=2
