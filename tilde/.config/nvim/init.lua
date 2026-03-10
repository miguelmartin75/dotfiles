vim.cmd [[packadd packer.nvim]]

require('packer').startup(function()
    -- basics
    use 'nvim-lua/plenary.nvim'

    use 'wbthomason/packer.nvim'
    use { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate' }
    use { 'nvim-treesitter/nvim-treesitter-context' }
    use { 'glacambre/firenvim', run = function() vim.fn['firenvim#install'](0) end }

    -- UI/colors
    use { 'nvim-mini/mini.icons', config = function() require('mini.icons').setup({ style = 'ascii' }) end }
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

    use {
    	'nvim-telescope/telescope.nvim', requires = { {'nvim-lua/plenary.nvim'} }
    }
    use {'nvim-telescope/telescope-fzf-native.nvim', run = 'make' }
    -- use 'L3MON4D3/LuaSnip' -- TODO: maybe?
    
    use {
        'folke/which-key.nvim',
        commit = "6c1584eb76b55629702716995cca4ae2798a9cca"
    }
    use { 'folke/sidekick.nvim' }
    use { 'folke/snacks.nvim' }

    use {
      "echasnovski/mini.diff",
    }

    use {
        'saghen/blink.cmp',
        build = 'cargo build --release',

    }
end)

-- AUTO-COMPLETE
local function t(str)
    -- Adjust boolean arguments as needed
    return vim.api.nvim_replace_termcodes(str, true, true, true)
end

local Snacks = require('snacks')
Snacks.setup({
    styles = {},
    picker = {
        layout = {
            preview = "main",
            preset = "ivy",
            position = "bottom",
        },
    }
})

ops = {
    insert_now = function()
        local cmd = "date +'\\%D \\%H:\\%M'"
        vim.cmd("read !" .. cmd)
    end,
    send_text = function(txt)
        vim.cmd("SlimeSend1 " .. txt)
    end,
    lldb_set_breakpoint_line = function()
        local current_ln = vim.api.nvim_win_get_cursor(0)[1]
        -- local current_file = vim.api.nvim_buf_get_name(0)
        local current_file = vim.fn.expand('%')
        local debug_cmd = string.format('b %s:%d', current_file, current_ln)
        ops.send_text(debug_cmd)
    end,
    -- super_tab = my_tab,
    -- super_rev_tab = my_rev_tab,
    toggle_line_numbers = function()
        vim.cmd([[
        set invnumber
        set invrelativenumber
        ]])
    end,
    rename_file = function()
        print("TODO")
    end,
    toggle_inlay = function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
    end
}



-- diff
-- TODO
local diff = require("mini.diff")
diff.setup({
  source = diff.gen_source.none(),
})

-- AI
local sidekick = require('sidekick')
sidekick.setup {
    cli = {
      mux = {
        backend = "tmux",
        enabled = true,
      },
    },
}

local progress = require("fidget.progress")

local cc_indicator = {}
cc_indicator.handles = {}

function cc_indicator:init()
  local group = vim.api.nvim_create_augroup("CodeCompanionFidgetHooks", {})

  vim.api.nvim_create_autocmd({ "User" }, {
    pattern = "CodeCompanionRequestStarted",
    group = group,
    callback = function(request)
      local handle = cc_indicator:create_progress_handle(request)
      cc_indicator:store_progress_handle(request.data.id, handle)
    end,
  })

  vim.api.nvim_create_autocmd({ "User" }, {
    pattern = "CodeCompanionRequestFinished",
    group = group,
    callback = function(request)
      local handle = cc_indicator:pop_progress_handle(request.data.id)
      if handle then
        cc_indicator:report_exit_status(handle, request)
        handle:finish()
      end
    end,
  })
end

function cc_indicator:store_progress_handle(id, handle)
  cc_indicator.handles[id] = handle
end

function cc_indicator:pop_progress_handle(id)
  local handle = cc_indicator.handles[id]
  cc_indicator.handles[id] = nil
  return handle
end

function cc_indicator:create_progress_handle(request)
  return progress.handle.create({
    title = " Requesting assistance (" .. request.data.strategy .. ")",
    message = "In progress...",
    lsp_client = {
      name = cc_indicator:llm_role_title(request.data.adapter),
    },
  })
end

function cc_indicator:llm_role_title(adapter)
  local parts = {}
  table.insert(parts, adapter.formatted_name)
  if adapter.model and adapter.model ~= "" then
    table.insert(parts, "(" .. adapter.model .. ")")
  end
  return table.concat(parts, " ")
end

function cc_indicator:report_exit_status(handle, request)
  if request.data.status == "success" then
    handle.message = "Completed"
  elseif request.data.status == "error" then
    handle.message = " Error"
  else
    handle.message = "󰜺 Cancelled"
  end
end

cc_indicator.init()


-- https://github.com/ioreshnikov/nvim/blob/425c048a3377d167c43f72f9695763ab241f0258/init.lua#L882
require("blink.cmp").setup({
    enabled = function() return not vim.tbl_contains({ "lua", "markdown" }, vim.bo.filetype) end,
    keymap = { 
        preset = 'default',
        ['<Tab>'] = { 'select_next', 'fallback' },
        ['<S-Tab>'] = { 'select_prev', 'fallback' },
        ['<C-k>'] = { 'show_signature', 'hide_signature', 'fallback' },
        ['<C-space>'] = { 'show', 'show_documentation', 'hide_documentation' },
    },
    appearance = {
      nerd_font_variant = 'none'
    },
    sources = {
      default = { 'lsp', 'path', 'snippets', 'buffer', },
      -- per_filetype = {
      --   codecompanion = { "codecompanion" },
      -- }
    },

    completion = {
        list = { 
            selection = { 
                preselect = false,
                auto_insert = true
            },
        },
        menu = {
          auto_show = true,

          draw = {
            columns = {
              { "label", "label_description", gap = 1 },
              { "kind_icon", "kind" }
            },
          }
        },
        documentation = { auto_show = true },
        ghost_text = { enabled = true }
    },
    signature = { enabled = true },
    -- fuzzy = { implementation = "prefer_rust_with_warning" },
    fuzzy = { implementation = "lua" },
})

local cmp = require'blink.cmp'
-- TODO
-- cmp.setup({
-- 	window = {
--         -- TODO
-- 		--completion = cmp.config.window.bordered(),
-- 		--documentation = cmp.config.window.bordered(),
-- 	},
-- 	mapping = cmp.mapping.preset.insert({
--         ['<C-Space>'] = cmp.mapping.complete(),
-- 	}),
-- 	sources = cmp.config.sources({
-- 		{ name = 'nvim_lsp' },
-- 	}, {
-- 		{ name = 'buffer' },
-- 	}, {
--         name = 'path'
--     })
-- })
-- 
-- cmp.setup.cmdline('/', {
-- 	mapping = cmp.mapping.preset.cmdline(),
-- 	sources = {
-- 		{ name = 'buffer' }
-- 	}
-- })
-- 
-- cmp.setup.cmdline(':', {
-- 	mapping = cmp.mapping.preset.cmdline(),
-- 	sources = cmp.config.sources({
-- 		{ name = 'path' }
-- 	}, {
-- 		{ name = 'cmdline' }
-- 	})
-- })

-- IMPORTS
local wk = require"which-key"
local telescope = require"telescope"
local luadev = require("neodev").setup({})

-- LSP

require'nvim-lsp-installer'.setup {}
require'fidget'.setup{}

local M = {}

local on_attach = function(client, bufnr)
    local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end

    buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

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

local capabilities = require('blink.cmp').get_lsp_capabilities()

local servers = { 
    'rust_analyzer',
    'ts_ls',
    'clangd',
    'zls',
    'nim_langserver',
    'lua_ls',
    'ty',
    'ols',
}
for _, lsp in pairs(servers) do
    vim.lsp.config(lsp, {
        capabilities = capabilities,
        on_attach = on_attach,
    })
    vim.lsp.enable(lsp)
end

-- TELESCOPE
-- local actions = require"telescope-actions" -- TODO

telescope.setup {
    pickers = {
        find_files = {
            hidden = true
        },
    },
    defaults = {
      file_ignore_patterns = {
        "node_modules",
        "build",
        "dist",
        "yarn.lock",
        ".git",
      },
    },
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


-- VIM OPTIONS
vim.cmd([[
set foldmethod=expr
set foldexpr=nvim_treesitter#foldexpr()

" REPL
" slime config
let g:slime_target = "tmux"
let g:slime_default_config = {"socket_name": "default", "target_pane": "{last}"}
let g:slime_python_ipython = 1
let g:slime_dispatch_ipython_pause = 350
" let g:slime_paste_file = "/tmp/.slime_paste"

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
set backupdir=~/.cache/nvim/backup//
set backupext=.bak

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
" autocmd filetype cpp nnoremap <leader>c :w <bar> !c++ -std=c++14 % -o %:r -Wall<CR>
" autocmd filetype cpp nnoremap <leader>r <bar> :te %:r <CR>

autocmd BufWinEnter,WinEnter term://* startinsert

filetype plugin indent on
syntax enable

augroup FileTypeSpecificAutocommands
    autocmd!
    autocmd FileType css* setlocal tabstop=2 softtabstop=2 shiftwidth=2
    autocmd FileType html* setlocal tabstop=2 softtabstop=2 shiftwidth=2
    autocmd FileType nim* setlocal tabstop=2 softtabstop=2 shiftwidth=2
    autocmd FileType javascript* setlocal tabstop=2 softtabstop=2 shiftwidth=2
    autocmd FileType typescript* setlocal tabstop=2 softtabstop=2 shiftwidth=2
    autocmd FileType typescript* :echom "typescipt"
    autocmd FileType php setlocal tabstop=2 softtabstop=2 shiftwidth=2
augroup END

let g:markdown_folding = 1

" UI
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
" imap <C-p> <C-r>+

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

-- KEY BINDINGS

-- local function my_tab()
--     --print("tab hit", cmp.visible())
--     if cmp.is_visible() then
--         cmp.select_next_item()
--         -- return t"<C-n>"
--     else
--         -- return t"<Tab>"
--         vim.fn.sendkeys(t"<Tab>")
--     end
-- end
-- 
-- local function my_rev_tab()
--     if cmp.visible() then
--         cmp.select_prev_item()
--         -- return t"<C-p>"
--     else
--         -- return t"<S-Tab>"
--         vim.fn.sendkeys(t"<S-Tab>")
--     end
-- end

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


wk.add({
    {"<C-p>", function() Snacks.picker.files({hidden = true, follow = true}) end, desc = "Find files"},
    {"<C-s>", function() Snacks.picker.lines() end, desc = "line grep"},
    {"[d", function() vim.diagnostic.goto_prev() end, desc = "prev diag"},
    {"]d", function() vim.diagnostic.goto_next() end, desc = "next diag"},
    {"gd", function() vim.lsp.buf.definition() end, desc = "goto definition"},
    {"gD", function() vim.lsp.buf.declaration() end, desc = "goto declaration"},
    {"gi", function() vim.lsp.buf.implementation() end, desc = "goto implementation"},
    {"K", function() vim.lsp.buf.hover() end, desc = "hover"},
    {"<leader>", group = "leader"},
    {"<leader>f", group = "file"},
    {"<leader>ff", function() Snacks.picker.files({hidden = true, follow = true, ignored = true}) end, desc = "Find File (incl. ignored)" },
    {"<leader>fR", "<cmd>Telescope oldfiles<cr>", desc = "Open Recent File" },
    {"<leader>fn", "<cmd>enew<cr>", desc = "New File" },
    {"<leader>fc", "<cmd>cd %:p:h<cr>", desc = "cd (global)"},
    {"<leader>fC", "<cmd>lcd %:p:h<cr>", desc = "cd (local)"},

    {"<leader>b", group = "buffer"},
    {"<leader>bd", "<cmd>bd<cr>", desc = "Delete Buffer" },

    {"<leader>w", group = "window"},
    {"<leader>wh", "<C-W>h", desc = "Left" },
    {"<leader>wl", "<C-W>l", desc = "Right" },
    {"<leader>wj", "<C-W>j", desc = "Down" },
    {"<leader>wk", "<C-W>k", desc = "Up" },
    {"<leader>wq", "<C-W>q", desc = "Quit window" },
    {"<leader>wx", "<C-W>x", desc = "Swap previous window" },
    {"<leader>w=", "<C-W>=", desc = "Equal height&width" },
    {"<leader>w|", "<C-W>|", desc = "Expand window" },
    {"<leader>wz", "TODO", desc = "Focus" },
    {"<leader>wu", "TODO", desc = "Undo window" },

    {"<leader>t", group = "tab"},
    {"<leader>tq", "<cmd>tabclose<cr>", desc = "close tab"},
    {"<leader>tc", "<cmd>tabnew<cr>", desc = "create tab"},
    {"<leader>t[", "<cmd>tabprevious<cr>", desc = "previous tab"},
    {"<leader>t]", "<cmd>tabnext<cr>", desc = "next tab"},

    {"<leader>/", function() Snacks.picker.lines() end, desc = "find line in buffer"},
    {"<leader>?", function() Snacks.picker.search_history() end, desc = "Search history"},
    {"<leader>m", function() Snacks.picker.marks() end, desc = "marks"},
    {"<leader>j", function() Snacks.picker.jumps() end, desc = "Jump list"},
    {"<leader>s", function() Snacks.picker.lsp_symbols() end, desc = "LSP Symbols"},
    {"<leader>e", function() Snacks.picker.commands() end, desc = "Commands"},
    {"<leader>.", function() Snacks.picker.files() end, desc = "Find File"},
    {"<leader>,", function() Snacks.picker.buffers() end, desc = "Find Buffers"},
    {"<leader>g", function() Snacks.picker.grep() end, desc = "grep"},

    {"<leader>G", group = "grep"},
    {"<leader>Gb", function() Snacks.picker.grep_buffers() end, desc = "grep buffers"},
    {"<leader>Gw", function() Snacks.picker.grep_word() end, desc = "grep words"},
    {"<leader>Gg", function() Snacks.picker.git_grep() end, desc = "git grep"},

    {"<leader>p", group = "more pickers"},
    {"<leader>pS", function() Snacks.picker.lsp_workspace_symbols() end, desc = "LSP Workspace Symbols" },
    {"<leader>pr", function() Snacks.picker.lsp_references() end, desc = "References" },
    {"<leader>pt", function() Snacks.picker.lsp_type_definitions() end, desc = "Find T[y]pe Definition" },
    {"<leader>pi", function() Snacks.picker.lsp_implementations() end, desc = "Goto Implementation" },
    {"<leader>pI", function() Snacks.picker.lsp_incoming_calls() end, desc = "C[a]lls Incoming" },
    {"<leader>pO", function() Snacks.picker.lsp_outgoing_calls() end, desc = "C[a]lls Outgoing" },

    {"<leader>c", group = "code/lsp"},
    {"<leader>cf", function() vim.lsp.buf.formatting() end, desc = "format"},
    {"<leader>cF", function() vim.lsp.buf.range_formatting() end, desc = "range format"},
    {"<leader>cw", function() vim.lsp.buf.add_workspace_folder() end, desc = "add workspace folder"},
    {"<leader>cW", function() vim.lsp.buf.remove_workspace_folder() end, desc = "remove workspace folder"},
    {"<leader>cl", function() vim.lsp.buf.list_workspace_folders() end, desc = "list workspace folders"},
    {"<leader>cD", function() vim.lsp.buf.type_definition() end, desc = "type definition"},
    {"<leader>cr", function() vim.lsp.buf.rename() end, desc = "rename"},
    {"<leader>ca", function() vim.lsp.buf.code_action() end, desc = "action"},
    {"<leader>ci", function() ops.toggle_inlay() end, desc = "toggle inlays"},
    {"<leader>cq", function() vim.lsp.diagnostic.set_loclist() end, desc = "set diag loc"},
    {"<leader>cQ", function() vim.lsp.diagnostic.open_float() end, desc = "open diag float"},

    {"<leader>h", group = "help/inspect"},
    {"<leader>ho", "<cmd>Telescope vim_options<cr>", desc = "vim options"},
    {"<leader>hh", function() Snacks.picker.help() end, desc = "help tags"},
    {"<leader>hm", function() Snacks.picker.man() end, desc = "man pages"},

    {"<leader><cr>",  "<cmd>set hls!<cr>", desc = "Toggle highlight"},
    {"<leader>q",  "<cmd>bd<cr>", desc = "Delete buffer"},
    {"<leader>Q",  "<cmd>%bd<cr>", desc = "Kill all buffers"},
    -- {"<leader>a", "<cmd>bp<cr>", desc = "previous buffer"},
    -- {"<leader>d", "<cmd>bn<cr>", desc = "next buffer"},
    {"<leader>l", function() ops.toggle_line_numbers() end, desc = "toggle line numbers"},
    {"<leader>n",  function() ops.insert_now() end, desc = "insert now" },

    {mode="n"},
})

-- ai bindings
wk.add({
    {
        "<tab>",
        function()
            if not require("sidekick").nes_jump_or_apply() then
                return "<Tab>" -- fallback to normal tab
            end
        end,
        expr = true,
        desc = "Goto/Apply Next Edit Suggestion",
    },
    {
        "<c-.>",
        function() require("sidekick.cli").toggle() end,
        desc = "Sidekick Toggle",
        mode = { "n", "t", "i", "x" },
    },
    {
        "<leader>aa",
        function() require("sidekick.cli").toggle() end,
        desc = "Sidekick Toggle CLI",
    },
    {
        "<leader>as",
        function() require("sidekick.cli").select() end,
        -- Or to select only installed tools:
        -- require("sidekick.cli").select({ filter = { installed = true } })
        desc = "Select CLI",
    },
    {
        "<leader>ad",
        function() require("sidekick.cli").close() end,
        desc = "Detach a CLI Session",
    },
    {
        "<leader>at",
        function() require("sidekick.cli").send({ msg = "{this}" }) end,
        mode = { "x", "n" },
        desc = "Send This",
    },
    {
        "<leader>af",
        function() require("sidekick.cli").send({ msg = "{file}" }) end,
        desc = "Send File",
    },
    {
        "<leader>av",
        function() require("sidekick.cli").send({ msg = "{selection}" }) end,
        mode = { "x" },
        desc = "Send Visual Selection",
    },
    {
        "<leader>ap",
        function() require("sidekick.cli").prompt() end,
        mode = { "n", "x" },
        desc = "Sidekick Select Prompt",
    },
    -- Example of a keybinding to open Claude directly
    {
        "<leader>ac",
        function() require("sidekick.cli").toggle({ name = "cursor", focus = true }) end,
        desc = "Sidekick Toggle Cursor",
    },
})
