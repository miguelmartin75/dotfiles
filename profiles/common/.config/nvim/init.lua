vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.history = 500
vim.opt.wildignore = { "*/tmp/*", "*.so", "*.swp", "*.zip", "*\\tmp\\*", "*.exe" }
vim.opt.autoread = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.wrap = false
vim.opt.backupdir = vim.fn.stdpath("cache") .. "/backup//"
vim.opt.backupext = ".bak"
vim.opt.spell = false
vim.opt.spelllang = { "en_au" }
vim.opt.foldlevelstart = 20
vim.opt.mouse = ""
vim.opt.termguicolors = true
vim.opt.background = "light"
vim.opt.cursorline = true
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.whichwrap:append("<,>,h,l")
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.lazyredraw = true
vim.opt.timeoutlen = 500
vim.opt.showmatch = true
vim.opt.matchtime = 2
vim.opt.visualbell = true

local filetype_options = vim.api.nvim_create_augroup("FiletypeOptions", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
    group = filetype_options,
    pattern = "*",
    callback = function(ev)
        local filetype = vim.bo[ev.buf].filetype
        if filetype == "markdown" or filetype == "text" or filetype == "gitcommit" then
            vim.opt_local.spell = true
        else
            vim.opt_local.spell = false
        end
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    group = filetype_options,
    pattern = { "css", "html", "nim", "javascript", "typescript", "php" },
    callback = function()
        vim.opt_local.tabstop = 2
        vim.opt_local.softtabstop = 2
        vim.opt_local.shiftwidth = 2
    end,
})

local package_hooks = vim.api.nvim_create_augroup("PackageHooks", { clear = true })

vim.api.nvim_create_autocmd("PackChanged", {
    group = package_hooks,
    callback = function(ev)
        local name = ev.data.spec.name
        local kind = ev.data.kind

        if (kind == "install" or kind == "update") and (name == "nvim-treesitter" or name == "firenvim") then
            vim.cmd.packadd(name)

            if name == "nvim-treesitter" then
                local success, result = pcall(function()
                    return require("nvim-treesitter").update():wait(300000)
                end)

                if not success then
                    vim.notify("nvim-treesitter update failed: " .. result, vim.log.levels.ERROR)
                elseif result == false then
                    vim.notify("nvim-treesitter parser update failed", vim.log.levels.ERROR)
                end
            elseif vim.env.NVIM_SKIP_EXTERNAL_INSTALL ~= "1" then
                local success, err = pcall(vim.fn["firenvim#install"], 0)
                if not success then
                    vim.notify("Firenvim install failed: " .. err, vim.log.levels.ERROR)
                end
            end
        end
    end,
})

local packages = {
    -- Parser-backed highlighting, folding, and query runtime.
    { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
    -- Query-backed text objects that match the current Treesitter runtime.
    { src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects", version = "main" },
    -- Bounded structural context for the current cursor position.
    "https://github.com/nvim-treesitter/nvim-treesitter-context",
    -- Live Git hunk state and operations for tracked buffers.
    "https://github.com/lewis6991/gitsigns.nvim",
    -- Explicit fuzzy pickers for files, buffers, symbols, and search.
    "https://github.com/folke/snacks.nvim",
    -- Language-server definitions for the configured external servers.
    "https://github.com/neovim/nvim-lspconfig",
    -- Progress reporting for language-server requests.
    "https://github.com/j-hui/fidget.nvim",
    -- Theme dependency used by the selected colorscheme.
    "https://github.com/rktjmp/lush.nvim",
    -- The selected low-contrast colorscheme.
    "https://github.com/mcchrish/zenbones.nvim",
    -- Send text and selections to tmux-hosted REPL sessions.
    "https://github.com/jpalardy/vim-slime",
    -- Browser integration through Neovim's Firenvim host.
    "https://github.com/glacambre/firenvim",
    -- Markdown table alignment commands.
    "https://github.com/godlygeek/tabular",
    -- Evaluate code blocks embedded in Markdown.
    "https://github.com/jubnzv/mdeval.nvim",
    -- Surround text objects and editing operations.
    "https://github.com/tpope/vim-surround",
    -- Repeat support for compatible plugin operations.
    "https://github.com/tpope/vim-repeat",
    -- Navigate between Neovim and adjacent tmux panes.
    "https://github.com/christoomey/vim-tmux-navigator",
}

vim.pack.add(packages, { confirm = false, load = true })

local Snacks = require("snacks")
Snacks.setup({
    styles = {},
    picker = {
        layout = {
            preview = "main",
            preset = "ivy",
            position = "bottom",
        },
    },
})

require("gitsigns").setup()
require("fidget").setup()

vim.g.slime_target = "tmux"
vim.g.slime_default_config = { socket_name = "default", target_pane = "{last}" }
vim.g.slime_python_ipython = 1
vim.g.slime_dispatch_ipython_pause = 350
vim.g.markdown_folding = 1

vim.cmd.colorscheme("zenbones")

local on_attach = function(client, bufnr)
    vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"

    if client.server_capabilities.document_highlight then
        vim.api.nvim_exec2([[
            augroup lsp_document_highlight
                autocmd! * <buffer>
                autocmd CursorHold <buffer> lua vim.lsp.buf.document_highlight()
                autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()
            augroup END
        ]], {})
    end
end

local capabilities = vim.lsp.protocol.make_client_capabilities()
local servers = {
    "rust_analyzer",
    "ts_ls",
    "clangd",
    "zls",
    "nim_langserver",
    "lua_ls",
    "ty",
    "ols",
}

for _, lsp in ipairs(servers) do
    vim.lsp.config(lsp, {
        capabilities = capabilities,
        on_attach = on_attach,
    })
    vim.lsp.enable(lsp)
end

require("nvim-treesitter").setup()

require("treesitter-context").setup({
    enable = true,
    max_lines = 0,
    trim_scope = "outer",
    min_window_height = 0,
    patterns = {
        default = {
            "class",
            "function",
            "method",
            "for",
            "while",
            "if",
            "switch",
            "case",
        },
        tex = {
            "chapter",
            "section",
            "subsection",
            "subsubsection",
        },
        rust = {
            "impl_item",
            "struct",
            "enum",
        },
        scala = {
            "object_definition",
        },
        vhdl = {
            "process_statement",
            "architecture_body",
            "entity_declaration",
        },
        markdown = {
            "section",
        },
        elixir = {
            "anonymous_function",
            "arguments",
            "block",
            "do_block",
            "list",
            "map",
            "tuple",
            "quoted_content",
        },
        json = {
            "pair",
        },
        yaml = {
            "block_mapping_pair",
        },
    },
})

vim.keymap.set("n", "<Space>", "<Nop>")
vim.keymap.set("n", "<leader>p", '"+p', { desc = "Paste from system clipboard" })
vim.keymap.set("n", "Y", '"+y', { desc = "Yank to system clipboard" })
vim.keymap.set("n", "YY", '"+yy', { desc = "Yank line to system clipboard" })
vim.keymap.set("x", "Y", '"+y', { desc = "Yank selection to system clipboard" })
vim.keymap.set("n", "<F1>", "<Nop>")
vim.keymap.set("n", "Q", "<Nop>")
vim.keymap.set("x", "K", "<Nop>")

vim.keymap.set("n", "<C-p>", function()
    Snacks.picker.files({ hidden = true, ignored = true, follow = true })
end, { desc = "Find files" })
vim.keymap.set("n", "<C-s>", function()
    Snacks.picker.lines()
end, { desc = "Find lines" })
vim.keymap.set("n", "[d", function()
    vim.diagnostic.goto_prev()
end, { desc = "Previous diagnostic" })
vim.keymap.set("n", "]d", function()
    vim.diagnostic.goto_next()
end, { desc = "Next diagnostic" })
vim.keymap.set("n", "gd", function()
    vim.lsp.buf.definition()
end, { desc = "Go to definition" })
vim.keymap.set("n", "gD", function()
    vim.lsp.buf.declaration()
end, { desc = "Go to declaration" })
vim.keymap.set("n", "gi", function()
    vim.lsp.buf.implementation()
end, { desc = "Go to implementation" })
vim.keymap.set("n", "K", function()
    vim.lsp.buf.hover()
end, { desc = "Hover" })
vim.keymap.set("n", "<leader>ff", function()
    Snacks.picker.files({ hidden = true, follow = true, ignored = true })
end, { desc = "Find file including ignored" })
vim.keymap.set("n", "<leader>fR", function()
    Snacks.picker.recent()
end, { desc = "Open recent file" })
vim.keymap.set("n", "<leader>fn", "<cmd>enew<cr>", { desc = "New file" })
vim.keymap.set("n", "<leader>fc", "<cmd>cd %:p:h<cr>", { desc = "Change global directory" })
vim.keymap.set("n", "<leader>fC", "<cmd>lcd %:p:h<cr>", { desc = "Change local directory" })
vim.keymap.set("n", "<leader>bd", "<cmd>bd<cr>", { desc = "Delete buffer" })
vim.keymap.set("n", "<leader>wh", "<C-W>h", { desc = "Focus left window" })
vim.keymap.set("n", "<leader>wl", "<C-W>l", { desc = "Focus right window" })
vim.keymap.set("n", "<leader>wj", "<C-W>j", { desc = "Focus lower window" })
vim.keymap.set("n", "<leader>wk", "<C-W>k", { desc = "Focus upper window" })
vim.keymap.set("n", "<leader>wq", "<C-W>q", { desc = "Close window" })
vim.keymap.set("n", "<leader>wx", "<C-W>x", { desc = "Exchange window" })
vim.keymap.set("n", "<leader>w=", "<C-W>=", { desc = "Equalize windows" })
vim.keymap.set("n", "<leader>w|", "<C-W>|", { desc = "Maximize window width" })
vim.keymap.set("n", "<leader>tq", "<cmd>tabclose<cr>", { desc = "Close tab" })
vim.keymap.set("n", "<leader>tc", "<cmd>tabnew<cr>", { desc = "Create tab" })
vim.keymap.set("n", "<leader>t[", "<cmd>tabprevious<cr>", { desc = "Previous tab" })
vim.keymap.set("n", "<leader>t]", "<cmd>tabnext<cr>", { desc = "Next tab" })
vim.keymap.set("n", "<leader>/", function()
    Snacks.picker.lines()
end, { desc = "Find line in buffer" })
vim.keymap.set("n", "<leader>?", function()
    Snacks.picker.search_history()
end, { desc = "Search history" })
vim.keymap.set("n", "<leader>m", function()
    Snacks.picker.marks()
end, { desc = "Marks" })
vim.keymap.set("n", "<leader>j", function()
    Snacks.picker.jumps()
end, { desc = "Jump list" })
vim.keymap.set("n", "<leader>s", function()
    Snacks.picker.lsp_symbols()
end, { desc = "LSP symbols" })
vim.keymap.set("n", "<leader>e", function()
    Snacks.picker.commands()
end, { desc = "Commands" })
vim.keymap.set("n", "<leader>.", function()
    Snacks.picker.files()
end, { desc = "Find file" })
vim.keymap.set("n", "<leader>,", function()
    Snacks.picker.buffers()
end, { desc = "Find buffers" })
vim.keymap.set("n", "<leader>g", function()
    Snacks.picker.grep({ follow = true })
end, { desc = "Grep" })
vim.keymap.set("n", "<leader>Gb", function()
    Snacks.picker.grep_buffers()
end, { desc = "Grep buffers" })
vim.keymap.set("n", "<leader>Gw", function()
    Snacks.picker.grep_word()
end, { desc = "Grep word" })
vim.keymap.set("n", "<leader>Gg", function()
    Snacks.picker.git_grep()
end, { desc = "Git grep" })
vim.keymap.set("n", "<leader>pS", function()
    Snacks.picker.lsp_workspace_symbols()
end, { desc = "LSP workspace symbols" })
vim.keymap.set("n", "<leader>pr", function()
    Snacks.picker.lsp_references()
end, { desc = "References" })
vim.keymap.set("n", "<leader>pt", function()
    Snacks.picker.lsp_type_definitions()
end, { desc = "Find type definition" })
vim.keymap.set("n", "<leader>pi", function()
    Snacks.picker.lsp_implementations()
end, { desc = "Go to implementation" })
vim.keymap.set("n", "<leader>pI", function()
    Snacks.picker.lsp_incoming_calls()
end, { desc = "Incoming calls" })
vim.keymap.set("n", "<leader>pO", function()
    Snacks.picker.lsp_outgoing_calls()
end, { desc = "Outgoing calls" })
vim.keymap.set("n", "<leader>cf", function()
    vim.lsp.buf.formatting()
end, { desc = "Format" })
vim.keymap.set("n", "<leader>cF", function()
    vim.lsp.buf.range_formatting()
end, { desc = "Range format" })
vim.keymap.set("n", "<leader>cw", function()
    vim.lsp.buf.add_workspace_folder()
end, { desc = "Add workspace folder" })
vim.keymap.set("n", "<leader>cW", function()
    vim.lsp.buf.remove_workspace_folder()
end, { desc = "Remove workspace folder" })
vim.keymap.set("n", "<leader>cl", function()
    vim.lsp.buf.list_workspace_folders()
end, { desc = "List workspace folders" })
vim.keymap.set("n", "<leader>cD", function()
    vim.lsp.buf.type_definition()
end, { desc = "Type definition" })
vim.keymap.set("n", "<leader>cr", function()
    vim.lsp.buf.rename()
end, { desc = "Rename" })
vim.keymap.set("n", "<leader>ca", function()
    vim.lsp.buf.code_action()
end, { desc = "Code action" })
vim.keymap.set("n", "<leader>ci", function()
    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, { desc = "Toggle inlay hints" })
vim.keymap.set("n", "<leader>cq", function()
    vim.lsp.diagnostic.set_loclist()
end, { desc = "Set diagnostic location list" })
vim.keymap.set("n", "<leader>cQ", function()
    vim.lsp.diagnostic.open_float()
end, { desc = "Open diagnostic float" })
vim.keymap.set("n", "<leader>ho", "<cmd>options<cr>", { desc = "Options" })
vim.keymap.set("n", "<leader>hh", function()
    Snacks.picker.help()
end, { desc = "Help tags" })
vim.keymap.set("n", "<leader>hm", function()
    Snacks.picker.man()
end, { desc = "Man pages" })
vim.keymap.set("n", "<leader><cr>", "<cmd>set hls!<cr>", { desc = "Toggle search highlight" })
vim.keymap.set("n", "<leader>q", "<cmd>bd<cr>", { desc = "Delete buffer" })
vim.keymap.set("n", "<leader>Q", "<cmd>%bd<cr>", { desc = "Delete all buffers" })
vim.keymap.set("n", "<leader>l", function()
    vim.wo.number = not vim.wo.number
    vim.wo.relativenumber = not vim.wo.relativenumber
end, { desc = "Toggle line numbers" })
vim.keymap.set("n", "<leader>n", function()
    vim.api.nvim_put({ os.date("%m/%d/%y %H:%M") }, "l", true, true)
end, { desc = "Insert timestamp" })
