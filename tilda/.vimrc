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

filetype plugin on
filetype plugin indent on
syntax on

" =============
" Vundle Setup
" =============

set nocompatible
filetype off

set rtp+=~/.vim/bundle/vundle
call vundle#begin()

" Let Vundle manage Vundle, required!
Plugin 'gmarik/vundle'

" ====================
" My bundes (plug-ins)
" ====================

" for my colour scheme addiction
Plugin 'flazz/vim-colorschemes'                

" the snippet engine I am using 
Plugin 'SirVer/ultisnips'

" for the actual snippets
Plugin 'miguelmartin75/vim-snippets'
 
" for file browsing
Plugin 'scrooloose/nerdtree'

" for surrounding text with {}, (), "", <tag></tag>, etc.
Plugin 'tpope/vim-surround'

" for using '.' with remaps (specifically for vim-surround)
Plugin 'tpope/vim-repeat'

" for rust syntax supoprt
Plugin 'wting/rust.vim'

" for easy insertion completetion
Plugin 'ervandew/supertab'

" for auto completion
Plugin 'Valloric/YouCompleteMe'

" for syntax checking
Plugin 'scrooloose/syntastic'                  

" fuzzy searching files nigga
Plugin 'kien/ctrlp.vim'

" fast motion within a line 
Plugin 'joequery/Stupid-EasyMotion'

" for viewing functions/classes etc.
Plugin 'majutsushi/tagbar'

" for nodejs dev (uni)
Plugin 'moll/vim-node'

call vundle#end()

" ===================
" Config for plug-ins
" ===================

" NerdTree
let g:NERDShutUp=1

map <C-e> :NERDTreeToggle<CR>:NERDTreeMirror<CR>

let NERDTreeShowBookmarks=1
let NERDTreeIgnore=['\.DS_Store', '\.pyc', '\~$', '\.swo$', '\.swp$', '\.git', '\.hg', '\.svn', '\.bzr']
let NERDTreeChDirMode=0
let NERDTreeQuitOnOpen=1
let NERDTreeMouseMode=2
let NERDTreeShowHidden=1
let NERDTreeKeepTreeInNewTab=1
let g:nerdtree_tabs_open_on_gui_startup=0

" Stupid-EasyMotion
map <C-o> <Leader><Leader>w
map <C-i> <Leader><Leader>W

" http://stackoverflow.com/a/18685821
" make YCM compatible with UltiSnips (using supertab)
let g:ycm_key_list_select_completion = ['<C-n>', '<Down>']
let g:ycm_key_list_previous_completion = ['<C-p>', '<Up>']
let g:SuperTabDefaultCompletionType = '<C-n>'

" better key bindings for UltiSnipsExpandTrigger
let g:UltiSnipsExpandTrigger = "<tab>"
let g:UltiSnipsJumpForwardTrigger = "<tab>"
let g:UltiSnipsJumpBackwardTrigger = "<s-tab>"

" Tagbar
nmap <Leader>t :TagbarToggle<CR> 

" ======
"   UI
" ======

" If we're using a gnome-terminal
if $COLORTERM == 'gnome-terminal'
    " then just manually set 256 colours
    " since gnome terminal doesn't like to advertise
    " it's colours :(
    set t_Co=256
endif

" Set (relative) line numbers
set relativenumber
" so we can see the current line number we're on
set number 

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

" store swap files elsewhere
set dir=~/.vim/backup/swap//,~/.vim/backup/tmp//,~/.vim/backup//,.

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

" ================
" General remaps
" ================

map , <Leader>

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
map <leader>bd :bd<cr>

" Close all the buffers
map <leader>ba :1,1000 bd!<cr>

" Useful mappings for managing tabs
map tn :tabnew<cr>
map to :tabonly<cr>
map tc :tabclose<cr>
map tm :tabmove

" Opens a new tab with the current buffer's path
" Super useful when editing files in the same directory
map te :tabedit <c-r>=expand("%:p:h")<cr>/

" Switch CWD to the directory of the open buffer
map cd :cd %:p:h<cr>:pwd<cr>

" Specify the behavior when switching between buffers 
try
    set switchbuf=useopen,usetab,newtab
    set stal=2
catch
endtry


" =============
" Status Line
" ============

" Always show the status line
set laststatus=2

" ==============
" Auto-commands
" ==============

" Return to last edit position when opening files (You want this!)
    autocmd BufReadPost *
          \ if line("'\"") > 0 && line("'\"") <= line("$") |
     \   exe "normal! g`\"" |
     \ endif
" Remember info about open buffers on close
set viminfo^=%

" these autocmds are the autocmds that 
" cannot be implemented elsewhere
" e.g. in ftpplugin

augroup cpp:
    autocmd BufNewFile *.{hpp,h,hxx,hh} exe 'normal ionce		' | exe ':4'
    autocmd BufNewFile main.{cpp,c,cxx,cc} exe 'normal omain	'
augroup END
