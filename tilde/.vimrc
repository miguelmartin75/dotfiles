call plug#begin('~/.vim/plugged')

""" ui
Plug 'majutsushi/tagbar', { 'on': 'TagbarToggle' }

" typing
"Plug 'junegunn/goyo.vim'
"Plug 'reedes/vim-pencil'

""" colour scheme
Plug 'arcticicestudio/nord-vim'

Plug 'autozimu/LanguageClient-neovim', {
    \ 'branch': 'next',
    \ 'do': 'bash install.sh',
\ }
Plug 'dense-analysis/ale'

"Plug 'nvim-treesitter/nvim-treesitter'
"Plug 'nvim-treesitter/playground'
"Plug 'nvim-treesitter/nvim-treesitter-textobjects'
"Plug 'nvim-treesitter/nvim-treesitter-refactor'

" todo: test other repl-based plugins
"Plug 'Olical/conjure'
Plug 'jpalardy/vim-slime'

""" text-editing/manipulation/movement
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'

" tmux
Plug 'christoomey/vim-tmux-navigator'

" snippets
"Plug 'SirVer/ultisnips'
"Plug 'miguelmartin75/ultisnips-snippets'

" files
if has('mac')
    Plug '/usr/local/opt/fzf'
else
    Plug '~/.fzf'
endif
Plug 'junegunn/fzf.vim'

" deoplete
if has('nvim')
  Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
else
  Plug 'Shougo/deoplete.nvim'
  Plug 'roxma/nvim-yarp'
  Plug 'roxma/vim-hug-neovim-rpc'
endif
let g:deoplete#enable_at_startup = 1

call plug#end()

" ===== General =====

let g:slime_target = "tmux"
let g:slime_paste_file = "$HOME/.slime_paste"

set completeopt=menu,noselect

set rtp+=/usr/local/bin/
set mouse=nv

" set command history to 500
set history=500

set wildignore+=*/tmp/*,*.so,*.swp,*.zip     " MacOSX/Linux
set wildignore+=*\\tmp\\*,*.swp,*.zip,*.exe  " Windows

" change cursor to line in insert mode
if exists('$TMUX')
    let &t_SI = "\<Esc>]50;CursorShape=1\x7"
    let &t_EI = "\<Esc>]50;CursorShape=0\x7"
else
    let &t_SI = "\<Esc>]50;CursorShape=1\x7"
    let &t_EI = "\<Esc>]50;CursorShape=0\x7"
endif

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

" Don't wrap lines
set nowrap

" visual linebreak
"set lbr
"set tw=80

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

" ===== Plugin Config =====

" close preview when we leave insert mode
autocmd InsertLeave * if pumvisible() == 0 | pclose | endif 

" use tab to navigate omni completion
inoremap <expr><TAB> pumvisible() ? "\<C-n>" : "\<TAB>"
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<S-TAB>"

" Trigger configuration
let g:UltiSnipsExpandTrigger="<C-j>"
let g:UltiSnipsJumpForwardTrigger="<c-n>"
let g:UltiSnipsJumpBackwardTrigger="<c-b>"

"" If you want :UltiSnipsEdit to split your window.
let g:UltiSnipsEditSplit="vertical"
let g:UltiSnipsSnippetDirectories = ["~/.vim/plugged/ultisnips-snippets/UltiSnips"]

" :e to emulate NerdTree
let g:netrw_banner = 0
let g:netrw_liststyle = 3
let g:netrw_browse_split = 4
let g:netrw_altv = 1
let g:netrw_winsize = 25
nmap <C-e> :Lexplore<cr>

" colour scheme
set background=dark
set termguicolors
colorscheme nord

" add a highlight for 81 chars
highlight ColorColumn ctermbg=magenta
call matchadd('ColorColumn', '\%81v', 100)

" ===== Plugin-specific Remaps =====

" ale
nnoremap ]a :ALENextWrap<CR>
nnoremap [a :ALEPreviousWrap<CR>
nnoremap ]A :ALELast
nnoremap [A :ALEFirst

" fzf.vim
nnoremap <Leader>. :Files<cr>
nnoremap <Leader>, :Buffers<cr>
nnoremap <Leader>< :Buffers<cr>

" Tagbar
nmap <Leader>t :TagbarToggle<CR> 

" LanguageClient-neovim
nnoremap <silent> K :call LanguageClient#textDocument_hover()<CR>
nnoremap <silent> gd :call LanguageClient#textDocument_definition()<CR>
nnoremap <silent> cn :call LanguageClient#textDocument_rename()<CR>
nnoremap <silent> <Leader>s :call LanguageClient#textDocument_documentSymbol()<CR>

" ===== Auto-commands =====

augroup text_editing
    autocmd!
    " Return to last edit position when opening files (You want this!)
    autocmd BufReadPost *
          \ if line("'\"") > 0 && line("'\"") <= line("$") |
     \   exe "normal! g`\"" |
     \ endif
    "autocmd Filetype text,markdown,mkd call WriteMode()
augroup END

function! WriteMode()
	if !exists('#goyo')
		Goyo 80
	endif
endfunction

if !empty(glob("~/.fb-vimrc"))
    source ~/.fb-vimrc
else
    let g:LanguageClient_serverCommands = {
    \ 'cpp': ['clangd'],
    \ 'rust': ['~/.cargo/bin/rustup', 'run', 'stable', 'rls'],
    \ 'javascript': ['/usr/local/bin/javascript-typescript-stdio'],
    \ 'javascript.jsx': ['tcp://127.0.0.1:2089'],
    \ 'python': ['/usr/local/bin/pyls'],
    \ 'ruby': ['~/.rbenv/shims/solargraph', 'stdio'],
    \ }
endif

" Competitive Programming
autocmd filetype cpp nnoremap <leader>c :w <bar> !c++ -std=c++14 % -o %:r -Wall<CR>
autocmd filetype cpp nnoremap <leader>r <bar> :te %:r <CR>

autocmd BufWinEnter,WinEnter term://* startinsert

" doesn't work due to abi...
lua <<EOF
--require'nvim-treesitter.configs'.setup {
--  ensure_installed = "maintained", -- one of "all", "maintained" (parsers with maintainers), or a list of languages
--  highlight = {
--    enable = true,              -- false will disable the whole extension
--  },
--  incremental_selection = {
--    enable = true,
--    keymaps = {
--      init_selection = "gnn",
--      node_incremental = "grn",
--      scope_incremental = "grc",
--      node_decremental = "grm",
--    },
--  },
--  --indent = {
--  --  enable = true
--  --}
--  refactor = {
--    highlight_definitions = { enable = true },
--    smart_rename = {
--      enable = true,
--      keymaps = {
--        smart_rename = "grr",
--      },
--    },
--    --highlight_current_scope = { enable = true },
--  },
--}
--
---- Treesitter stops syntax files from being loaded so need to redefine commentstrings for 
---- languages we care about.
--local commentstrings = {
--  python  = '#',
--  json    = '#',
--  bash    = '#',
--  lua     = '--',
--  verilog = '//'
--}

--require'nvim-treesitter'.define_modules {
--  fixspell = {
--    enable = true,
--    attach = function(bufnr, lang)
--      local cs = commentstrings[lang]
--      vim.cmd(
--        ('syntax match spellComment "%s.*" contains=@Spell'):format(cs)
--      )
--    end,
--    detach = function(bufnr)
--    end,
--    is_supported = function(lang)
--      if commentstrings[lang] == nil then
--        return false
--      end
--      if require('nvim-treesitter.query').get_query(lang, 'highlights') == nil then
--        return false
--      end
--      return true
--    end
--  }
--}
EOF

set foldmethod=expr
set foldexpr=nvim_treesitter#foldexpr()

nnoremap <M-x> :Commands<CR>

"set g:python3_host_prog='/home/miguelmartin/anaconda3/bin/python3'
"set autochdir
