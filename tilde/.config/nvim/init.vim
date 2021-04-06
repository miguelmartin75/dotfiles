" load plugins
call plug#begin('~/.vim/plugged')

Plug 'alaviss/nim.nvim'

""" colour scheme
Plug 'arcticicestudio/nord-vim'

" LSP
Plug 'neovim/nvim-lspconfig'

" linting
Plug 'dense-analysis/ale'

""" text-editing/manipulation/movement
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'

" treesitter
Plug 'nvim-treesitter/nvim-treesitter'
Plug 'nvim-treesitter/playground'
Plug 'nvim-treesitter/nvim-treesitter-textobjects'
Plug 'nvim-treesitter/nvim-treesitter-refactor'

" tmux
Plug 'christoomey/vim-tmux-navigator'

" snippets
Plug 'SirVer/ultisnips'
Plug 'miguelmartin75/ultisnips-snippets'

Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'

" TODO
Plug 'ncm2/ncm2'
Plug 'roxma/nvim-yarp'
Plug 'ncm2/ncm2-ultisnips'
Plug 'ncm2/ncm2-bufword'
Plug 'ncm2/ncm2-path'

" conjure
Plug 'Olical/conjure', {'tag': 'v4.16.0'}

" fennel
Plug 'Olical/aniseed', { 'tag': 'v3.16.0' }
Plug 'bakpakin/fennel.vim'

"Plug 'nvim-lua/completion-nvim'

"Plug 'deoplete-plugins/deoplete-lsp'
"
"" deoplete
"if has('nvim')
"  Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
"else
"  Plug 'Shougo/deoplete.nvim'
"  Plug 'roxma/nvim-yarp'
"  Plug 'roxma/vim-hug-neovim-rpc'
"endif
"let g:deoplete#enable_at_startup = 1

call plug#end()

syntax on

" ===== UI/Colours =====

" highlight current line cursor is on
set cursorline

" use relative numbers
set number
set relativenumber

" show current position
set ruler

" height of the command bar
set cmdheight=1

" make backspace act like backspace
set backspace=eol,start,indent
set whichwrap+=<,>,h,l

" ignorecase by default for searches
" smartcase => use case if captial 
" letters are introduced in the pattern
set ignorecase
set smartcase

" Highlight search results
set hlsearch

" Use incremental search
set incsearch

" don't redraw while executing macros (good performance config)
set lazyredraw

" for some regex chars to be non-escaped
" use \v to enable all regex chars to be non-escaped
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

" ===== Text Editing =====

" auto read files when changed from other programs
set autoread

" Use spaces instead of tabs
set expandtab

" Be smart when using tabs, most notably 
" to backspace the correct amount of spaces
set smarttab

" Set the tab width
set shiftwidth=4

" \t size
set tabstop=4

" Set auto-indentation
set autoindent

" Wrap lines
set wrap

" visual linebreak
set lbr
set tw=80

" store swap files elsewhere
set dir=~/.vim/backup/swap//,~/.vim/backup/tmp//,~/.vim/backup//

" automatically change to the dir where the file is
"set autochdir

" use some spell checking :)
" for code, this will only spell check
" within comments
set spell spelllang=en_au

" code folding
set foldmethod=syntax
set foldlevelstart=20

" ===== re-maps =====

" space as leader
nnoremap <Space> <Nop>
let mapleader=" "

" for wrapped lines
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

" easy way to move around windows
map <C-j> <C-W>j
map <C-k> <C-W>k
map <C-h> <C-W>h
map <C-l> <C-W>l

" q and qa for buffers
map <leader>q :bd<cr>
map <leader>qa :%bd<cr>

nnoremap <F1> <nop>
nnoremap Q <nop>
nnoremap K <nop>
vnoremap K <nop>

" buffers

" set hidden basically allows you to 
" open another buffer without saving changes
set hidden
nnoremap <leader>a :bp<CR>
nnoremap <leader>d :bn<CR>

" ==== UI ====
set background=dark
set termguicolors
colorscheme nord

" ===== Plugin Config =====


" add a highlight for 81 chars
highlight ColorColumn ctermbg=magenta
call matchadd('ColorColumn', '\%81v', 100)

" ===== Plugin-specific Remaps =====

" ==== Telescope ====
"autocmd FileType TelescopePrompt call deoplete#custom#buffer_option('auto_complete', v:false)
autocmd BufEnter * call ncm2#enable_for_buffer()

autocmd User Ncm2Plugin call ncm2#register_source({
\   'name': 'nim.nvim',
\   'priority': 9,
\   'scope': ['nim'],
\   'mark': 'nim',
\   'on_complete': {ctx -> nim#suggest#sug#GetAllCandidates({start, candidates -> ncm2#complete(ctx, start, candidates)})}
\})

nnoremap <C-p> <cmd>Telescope find_files<cr>
nnoremap <leader>. <cmd>Telescope buffers<cr>
nnoremap <leader>, <cmd>Telescope buffers<cr>
nnoremap <leader>g <cmd>Telescope live_grep<cr> 
nnoremap <leader>h <cmd>Telescope help_tags<cr>

" --- Completion
" close preview when we leave insert mode
autocmd InsertLeave * if pumvisible() == 0 | pclose | endif 

" use tab to navigate omni completion
" TODO: port to lua or fennel
inoremap <expr><TAB> pumvisible() ? "\<C-n>" : "\<TAB>"
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<S-TAB>"

" Set completeopt to have a better completion experience
set completeopt=menuone,noinsert,noselect

" Avoid showing message extra message when using completion
set shortmess+=c

" Press enter key to trigger snippet expansion
" The parameters are the same as `:help feedkeys()`
"inoremap <silent> <expr> <CR> ncm2_ultisnips#expand_or("\<CR>", 'n')
" https://github.com/ncm2/ncm2-ultisnips/issues/11
autocmd BufNewFile,BufRead * inoremap <silent> <buffer> <expr> <cr> ncm2_ultisnips#expand_or("\<CR>", 'n')

" c-j c-k for moving in snippet
let g:UltiSnipsExpandTrigger		= "<Plug>(ultisnips_expand)"
let g:UltiSnipsJumpForwardTrigger	= "<c-j>"
let g:UltiSnipsJumpBackwardTrigger	= "<c-k>"
let g:UltiSnipsRemoveSelectModeMappings = 0
let g:UltiSnipsEditSplit="vertical"
let g:UltiSnipsSnippetDirectories = ["~/.vim/plugged/ultisnips-snippets/UltiSnips"]

" ale
" TODO: port to LSP or alternative
nnoremap ]a :ALENextWrap<CR>
nnoremap [a :ALEPreviousWrap<CR>
nnoremap ]A :ALELast
nnoremap [A :ALEFirst

" ==== Competitive Programming ====

autocmd filetype cpp nnoremap <leader>c :w <bar> !c++ -std=c++14 % -o %:r -Wall<CR>
autocmd filetype cpp nnoremap <leader>r <bar> :te ./%:r <CR>

autocmd BufWinEnter,WinEnter term://* startinsert

" Lua configurations
" TODO: port to fennel? idk
lua require('config')

" Use aniseed for rest of configuration
lua require('aniseed.env').init({ module = 'init' })

