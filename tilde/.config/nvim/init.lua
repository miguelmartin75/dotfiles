vim.cmd [[packadd packer.nvim]]

require('packer').startup(function()
    -- basics
    use 'nvim-lua/plenary.nvim'

    use 'wbthomason/packer.nvim'
    use { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate' }
    use { 'nvim-treesitter/nvim-treesitter-context' }
    --use { 'lewis6991/spellsitter.nvim' }
    use { 'glacambre/firenvim', run = function() vim.fn['firenvim#install'](0) end }

    -- UI/colors
    use {
        "mcchrish/zenbones.nvim",
        -- Optionally install Lush. Allows for more configuration or extending the colorscheme
        -- If you don't want to install lush, make sure to set g:zenbones_compat = 1
        -- In Vim, compat mode is turned on as Lush only works in Neovim.
        requires = "rktjmp/lush.nvim"
    }
    use {
        'lewis6991/gitsigns.nvim', requires = { 'nvim-lua/plenary.nvim' },
        config = function() require('gitsigns').setup() end
    }
    use {'tjdevries/colorbuddy.vim'}

    -- writing
    use 'junegunn/goyo.vim'
    use 'reedes/vim-pencil'

    -- markdown
    use 'godlygeek/tabular'
    -- use 'masukomi/vim-markdown-folding'
    use 'jubnzv/mdeval.nvim'
    
    -- essentials
    use 'tpope/vim-surround'
    use 'tpope/vim-repeat'

    -- langs
    use 'ziglang/zig.vim'

    -- LSP
    use 'j-hui/fidget.nvim'
    use 'neovim/nvim-lspconfig'
    use 'williamboman/nvim-lsp-installer'
    use "folke/lua-dev.nvim"
    use 'nvimtools/none-ls.nvim'

    -- REPL
    use {
        'jpalardy/vim-slime',
        --commit = "947f96bdad01d0cf6e3886c2b0c910f4793b2f96"
    }
    use 'christoomey/vim-tmux-navigator'

    -- completion
    use 'hrsh7th/nvim-cmp'
    use 'hrsh7th/cmp-nvim-lsp'
    use 'hrsh7th/cmp-buffer'
    use 'hrsh7th/cmp-path'
    use 'hrsh7th/cmp-cmdline'

    use {
    	'nvim-telescope/telescope.nvim', requires = { {'nvim-lua/plenary.nvim'} }
    }
    use {'nvim-telescope/telescope-fzf-native.nvim', run = 'make' }
    -- use 'L3MON4D3/LuaSnip' -- TODO
    --
    
    use {
        'folke/which-key.nvim',
        commit = "6c1584eb76b55629702716995cca4ae2798a9cca"
    }

    use { 
        "/usr/share/fb-editor-support/nvim",
        as = "meta.nvim",
    }
end)

-- AUTO-COMPLETE
local cmp = require'cmp'
cmp.setup({
	window = {
        -- TODO
		--completion = cmp.config.window.bordered(),
		--documentation = cmp.config.window.bordered(),
	},
	mapping = cmp.mapping.preset.insert({
        ['<C-Space>'] = cmp.mapping.complete(),
	}),
	sources = cmp.config.sources({
		{ name = 'nvim_lsp' },
	}, {
		{ name = 'buffer' },
	}, {
        name = 'path'
    })
})

cmp.setup.cmdline('/', {
	mapping = cmp.mapping.preset.cmdline(),
	sources = {
		{ name = 'buffer' }
	}
})

cmp.setup.cmdline(':', {
	mapping = cmp.mapping.preset.cmdline(),
	sources = cmp.config.sources({
		{ name = 'path' }
	}, {
		{ name = 'cmdline' }
	})
})

-- IMPORTS
local wk = require"which-key"
local telescope = require"telescope"
local luadev = require("neodev").setup({})

-- LSP

require'nvim-lsp-installer'.setup {}
require'fidget'.setup{}

local M = {}

local on_attach = function(client, bufnr)
    --local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
    local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

    buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

    -- Mappings.
    -- print("LSP attached: ", client.name)
    local opts = {
        mode="n",
        silent=false,
        buffer=bufnr,
    }
    wk.register({
        ["gd"] = {'<Cmd>lua vim.lsp.buf.definition()<CR>', "goto definition"},
        ["gD"] = {'<Cmd>lua vim.lsp.buf.declaration()<CR>', "goto declaration"},
        ["gr" ] = { require('telescope.builtin').lsp_references, "[G]oto [R]eferences" },
        ["<leader>D"] = { vim.lsp.buf.type_definition, 'Type [D]efinition'},
        ["gi"] = {'<Cmd>lua vim.lsp.buf.implementation()<CR>', "goto implementation"},
        ["K"] = {'<Cmd>lua vim.lsp.buf.hover()<CR>', "hover"},
        ["<C-k>"] = {'<cmd>lua vim.lsp.buf.signature_help()<CR>', "signature help"},
        ["<leader>c"] = {
            w = {'<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', "add workspace folder"},
            W = {'<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', "remove workspace folder"},
            l = {'<cmd>lua vim.lsp.buf.list_workspace_folders()<CR>', "list workspace folders"},
            D = {'<cmd>lua vim.lsp.buf.type_definition()<CR>', "type definition"},
            r = {'<cmd>lua vim.lsp.buf.rename()<CR>', "rename"},
            a = {'<cmd>lua vim.lsp.buf.code_action()<CR>', "action"},
        }
    }, opts)
    -- Set some keybinds conditional on server capabilities
    if client.server_capabilities.document_formatting then
        wk.register({
            ["<space>cf"] = {"<cmd>lua vim.lsp.buf.formatting()<CR>", "format"},
        }, opts)
    end
    if client.server_capabilities.document_range_formatting then
        wk.register({
            ["<space>cF"] = {"<cmd>lua vim.lsp.buf.range_formatting()<CR>", "range format"},
        }, opts)
    end

    -- Set autocommands conditional on server_capabilities
    if client.server_capabilities.document_highlight then
        vim.api.nvim_exec([[
        hi LspReferenceRead cterm=bold ctermbg=red guibg=LightYellow
        hi LspReferenceText cterm=bold ctermbg=red guibg=LightYellow
        hi LspReferenceWrite cterm=bold ctermbg=red guibg=LightYellow
        augroup lsp_document_highlight
        autocmd! * <buffer>
            autocmd CursorHold <buffer> lua vim.lsp.buf.document_highlight()
            autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()
        augroup END
        ]], false)
    end
end

local capabilities = require('cmp_nvim_lsp').default_capabilities(vim.lsp.protocol.make_client_capabilities())


-- Use a loop to conveniently call 'setup' on multiple servers and
-- map buffer local keybindings when the language server attaches
local servers = { 'rust_analyzer', 'tsserver' }
for _, lsp in pairs(servers) do
    require('lspconfig')[lsp].setup {
        capabilities = capabilities,
        on_attach = on_attach,
        flags = {
            -- This will be the default in neovim 0.7+
            debounce_text_changes = 150,
        },
    }
end


-- lua; slightly annoying to setup
-- luadev['settings']['Lua']['workspace']['checkThirdParty'] = false
-- luadev["capabilities"] = capabilities
-- luadev["on_attach"] = on_attach
-- luadev["flags"] = { debounce_text_changes = 150 }
-- print(vim.inspect(luadev))
require('lspconfig').sumneko_lua.setup(luadev)

-- TELESCOPE
-- local actions = require"telescope-actions" -- TODO

telescope.setup {
    mappings = {
        i = {
            -- map actions.which_key to <C-h> (default: <C-/>)
            -- actions.which_key shows the mappings for your picker,
            -- e.g. git_{create, delete, ...}_branch for the git_branches picker
            ["<C-h>"] = "which_key",
            --["<C-g>"] = actions.close,
        }
    },
    extensions = {
	    fzf = {
			fuzzy = true,                    -- false will only do exact matching
			override_generic_sorter = true,  -- override the generic sorter
			override_file_sorter = true,     -- override the file sorter
			case_mode = "smart_case",        -- or "ignore_case" or "respect_case"
			-- the default case_mode is "smart_case"
		}
	}
}
telescope.load_extension('fzf')


--vim.cmd([[
--nmap <Leader>, :Telescope
--]])
require("nvim-treesitter.configs").setup{
    -- A list of parser names, or "all"
    ensure_installed = { "c", "cpp", "lua", "python" },
    sync_install = false,
    highlight = {
        enable = true,
        disable = {},
        additional_vim_regex_highlighting = false,
    },
}

require'treesitter-context'.setup{
    enable = true, -- Enable this plugin (Can be enabled/disabled later via commands)
    max_lines = 0, -- How many lines the window should span. Values <= 0 mean no limit.
    trim_scope = 'outer', -- Which context lines to discard if `max_lines` is exceeded. Choices: 'inner', 'outer'
    min_window_height = 0, -- Minimum editor window height to enable context. Values <= 0 mean no limit.
    patterns = { -- Match patterns for TS nodes. These get wrapped to match at word boundaries.
        -- For all filetypes
        -- Note that setting an entry here replaces all other patterns for this entry.
        -- By setting the 'default' entry below, you can control which nodes you want to
        -- appear in the context window.
        default = {
            'class',
            'function',
            'method',
            'for',
            'while',
            'if',
            'switch',
            'case',
        },
        -- Patterns for specific filetypes
        -- If a pattern is missing, *open a PR* so everyone can benefit.
        tex = {
            'chapter',
            'section',
            'subsection',
            'subsubsection',
        },
        rust = {
            'impl_item',
            'struct',
            'enum',
        },
        scala = {
            'object_definition',
        },
        vhdl = {
            'process_statement',
            'architecture_body',
            'entity_declaration',
        },
        markdown = {
            'section',
        },
        elixir = {
            'anonymous_function',
            'arguments',
            'block',
            'do_block',
            'list',
            'map',
            'tuple',
            'quoted_content',
        },
        json = {
            'pair',
        },
        yaml = {
            'block_mapping_pair',
        },
    },
    exact_patterns = {
        -- Example for a specific filetype with Lua patterns
        -- Treat patterns.rust as a Lua pattern (i.e "^impl_item$" will
        -- exactly match "impl_item" only)
        -- rust = true,
    },

    -- [!] The options below are exposed but shouldn't require your attention,
    --     you can safely ignore them.

    zindex = 20, -- The Z-index of the context window
    mode = 'cursor',  -- Line used to calculate context. Choices: 'cursor', 'topline'
    -- Separator between context and content. Should be a single character string, like '-'.
    -- When separator is set, the context will only show up when there are at least 2 lines above cursorline.
    separator = nil,
}


vim.cmd([[
set foldmethod=expr
set foldexpr=nvim_treesitter#foldexpr()
]])

-- REPL
-- slime config
vim.cmd([[
let g:slime_target = "tmux"
let g:slime_default_config = {"socket_name": "default", "target_pane": "{last}"}
let g:slime_python_ipython = 1
let g:slime_dispatch_ipython_pause = 350
]])
--let g:slime_paste_file = "/tmp/.slime_paste"

-- TODO mdrunner or whatever it's called

-- VIM OPTIONS
vim.cmd([[
set rtp+=/usr/local/bin/

" set command history to 500
set history=500

set wildignore+=*/tmp/*,*.so,*.swp,*.zip     " MacOSX/Linux
set wildignore+=*\\tmp\\*,*.swp,*.zip,*.exe  " Windows


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
set lbr
set tw=0

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

" TODO moveme
" Competitive Programming
autocmd filetype cpp nnoremap <leader>c :w <bar> !c++ -std=c++14 % -o %:r -Wall<CR>
autocmd filetype cpp nnoremap <leader>r <bar> :te %:r <CR>

autocmd BufWinEnter,WinEnter term://* startinsert

filetype plugin indent on
syntax enable

augroup FileTypeSpecificAutocommands
    autocmd!
    autocmd FileType javascript* setlocal tabstop=2 softtabstop=2 shiftwidth=2
    autocmd FileType typescript* setlocal tabstop=2 softtabstop=2 shiftwidth=2
    autocmd FileType typescript* :echom "typescipt"
    autocmd FileType php setlocal tabstop=2 softtabstop=2 shiftwidth=2
augroup END

let g:markdown_folding = 1
]])
-- UI
vim.cmd([[
set mouse=

" change cursor to line in insert mode
if exists('$TMUX')
    let &t_SI = "\<Esc>]50;CursorShape=1\x7"
    let &t_EI = "\<Esc>]50;CursorShape=0\x7"
else
    let &t_SI = "\<Esc>]50;CursorShape=1\x7"
    let &t_EI = "\<Esc>]50;CursorShape=0\x7"
endif

syntax on

set termguicolors
set background=light " or dark

colorscheme zenbones

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
]])

-- KEY BINDINGS
local function t(str)
    -- Adjust boolean arguments as needed
    return vim.api.nvim_replace_termcodes(str, true, true, true)
end

local function telescope_cmd(cmd)
    vim.api.nvim_command("Telescope " .. cmd)
end

local function my_tab()
    --print("tab hit", cmp.visible())
    if cmp.visible() then
        --cmp.select_next_item()
        return t"<C-n>"
    else
        return t"<Tab>"
    end
end

local function my_rev_tab()
    if cmp.visible() then
        --cmp.select_prev_item()
        return t"<C-p>"
    else
        return t"<S-Tab>"
        -- vim.fn.sendkeys(t"<S-Tab>")
    end
end


ops = {
    super_tab = my_tab,
    super_rev_tab = my_rev_tab,
    toggle_line_numbers = function()
        vim.cmd([[
        set invnumber
        set invrelativenumber
        ]])
    end,
    find_files = function()
        telescope_cmd("find_files")
    end,
    rename_file = function()
        print("TODO")
    end,
    find_buffers = function()
        telescope_cmd("buffers")
    end
}


vim.cmd([[
" space as leader
nnoremap <Space> <Nop>
let mapleader=" "

" for wrapped lines
" map j gj
" map k gk

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

nnoremap <F1> <nop>
nnoremap Q <nop>
nnoremap K <nop>
vnoremap K <nop>

" set hidden basically allows you to 
" open another buffer without saving changes
set hidden
]])


wk.setup {
    plugins = {
        marks = true, -- shows a list of your marks on ' and `
        registers = true, -- shows your registers on " in NORMAL or <C-r> in INSERT mode
        spelling = {
            enabled = true, -- enabling this will show WhichKey when pressing z= to select spelling suggestions
            suggestions = 20, -- how many suggestions should be shown in the list?
        },
        -- the presets plugin, adds help for a bunch of default keybindings in Neovim
        -- No actual key bindings are created
        presets = {
            operators = true, -- adds help for operators like d, y, ... and registers them for motion / text object completion
            motions = true, -- adds help for motions
            text_objects = true, -- help for text objects triggered after entering an operator
            windows = true, -- default bindings on <c-w>
            nav = true, -- misc bindings to work with windows
            z = true, -- bindings for folds, spelling and others prefixed with z
            g = true, -- bindings for prefixed with g
        },
    },
}

wk.register({
    ["<Tab>"] = {"za", "Toggle fold"},
    ["<C-p>"] = {ops.find_files, "Find files"},
    ["<C-s>"] = {"<cmd>Telescope myles<cr>", "Myles"},
    ["[d"] = {'<cmd>lua vim.diagnostic.goto_prev()<CR>', "prev diag"},
    ["]d"] = {'<cmd>lua vim.diagnostic.goto_next()<CR>', "next diag"},
    ["<leader>q"] = {'<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', "set diag loc"},
    ["<leader>Q"] = {'<cmd>lua vim.lsp.diagnostic.open_float()<CR>', "open diag float"},

}, {mode="n"})

-- TODO
wk.register({
    ["<Tab>"] = {ops.super_tab, "Next completion", expr = true},
    ["<S-Tab>"] = {ops.super_rev_tab, "Reverse completion", expr = true},
}, {mode="i"})

wk.register({
    -- groups
    f = {
        name = "+file",
        f = { ops.find_files, "Find File" },
        r = { ops.rename_file, "Rename file & buffer" },
        R = { "<cmd>Telescope oldfiles<cr>", "Open Recent File" },
        n = { "<cmd>enew<cr>", "New File" },
        c = {"<cmd>cd %:p:h<cr>", "cd (global)"},
        C = {"<cmd>lcd %:p:h<cr>", "cd (local)"},
    },
    b = {
        name = "+buffer",
        f = { "<cmd>Telescope buffers<cr>", "Find File" },
        d = { "<cmd>bd<cr>", "Delete Buffer" },
    },
    w = {
        name = "+window",
        h = { "<C-W>h", "Left" },
        l = { "<C-W>l", "Right" },
        j = { "<C-W>j", "Down" },
        k = { "<C-W>k", "Up" },
        q = { "<C-W>q", "Quit window" },
        x = { "<C-W>x", "Swap previous window" },
        ["="] = { "<C-W>=", "Equal height&width" },
        ["|"] = { "<C-W>|", "Expand window" },
        z = { "TODO", "Focus" },
        u = { "TODO", "Undo window" },
    },
    t = {
        q = {"<cmd>tabclose<cr>", "close tab"},
        c = {"<cmd>tabnew<cr>", "create tab"},
        ["["] = {"<cmd>tabprevious<cr>", "previous tab"},
        ["]"] = {"<cmd>tabnext<cr>", "next tab"},
        -- TODO
    },
    h = {
        name = "+help/inspect",
        o = {"<cmd>Telescope vim_options<cr>", "vim options"},
        h = {"<cmd>Telescope help_tags<cr>", "help tags"},
        m = {"<cmd>Telescope man_pages<cr>", "man pages"},
    },
    t = {
        name = "+telescope (more)",
        r = {"<cmd>Telescope type_references<cr>", "type references"},
        t = {"<cmd>Telescope type_definitions<cr>", "type definitions"},
        i = {"<cmd>Telescope type_implementations<cr>", "type impls"},
        w = {"<cmd>Telescope workspace_symbols<cr>", "workspace symbols"},
    },

    -- shortcuts
    ["/"] = { "<cmd>Telescope current_buffer_fuzzy_find<cr>", "Fuzzy find buffer"},
    ["?"] = { "<cmd>Telescope search_history<cr>", "Search history"},
    ["m"] = { "<cmd>Telescope marks<cr>", "Marks"},
    ["j"] = { "<cmd>Telescope jump_list<cr>", "Jump list"},
    ["s"] = { "<cmd>Telescope lsp_document_symbols<cr>", "LSP Symbols"},
    ["e"] = { "<cmd>Telescope commands<cr>", "Commands"},
    ["."] = { ops.find_files, "Find File"},
    [","] = { ops.find_buffers, "Find Buffers"},

    ["<cr>"] = { "<cmd>set hls!<cr>", "Toggle highlight"},
    ["q"] = { "<cmd>bd<cr>", "Delete buffer"},
    ["qa"] = { "<cmd>%bd<cr>", "Kill all buffers"},
    ["a"] = {"<cmd>bp<cr>", "previous buffer"},
    ["d"] = {"<cmd>bn<cr>", "next buffer"},
    ["l"] = {ops.toggle_line_numbers, "toggle line numbers"},
    ["a"] = {"<cmd>bp<cr>", "previous buffer"},
    ["d"] = {"<cmd>bp<cr>", "next buffer"},

}, {mode = "n", prefix="<leader>"})

-- WORK
local meta = require("meta")
if meta then
    require("plenary.filetype").add_file("meta")
    require("telescope").load_extension("myles")
    require("telescope").load_extension("biggrep")
    local on_attach = require("_lsp").on_attach

    local servers = {
        "rusty@meta",
        "wasabi@meta",
        "pyls@meta",
        "pyre@meta",
        "thriftlsp@meta",
        "cppls@meta",
        "buckls@meta",
        "hh_client",
        -- "hhvm",
    }
    for _, lsp in ipairs(servers) do
      require("lspconfig")[lsp].setup {
            capabilities = capabilities,
            on_attach = on_attach,
            flags = {
                -- This will be the default in neovim 0.7+
                debounce_text_changes = 150,
            },
      }
    end

    require("lspconfig").flow.setup{
      cmd = { 'flow', 'lsp' },
      capabilities = capabilities,
      on_attach = on_attach,
      flags = {
          -- This will be the default in neovim 0.7+
          debounce_text_changes = 150,
      },
    }

    local null_ls = require("null-ls")

    null_ls.setup({
      on_attach = on_attach,
      sources = {
        meta.null_ls.diagnostics.arclint,
        meta.null_ls.formatting.arclint,
      }
    })
        

    require("nvim-treesitter.install").prefer_git = true
    require("nvim-treesitter.install").command_extra_args = {
        curl = { "--proxy", "http://fwdproxy:8080" },
    }
end