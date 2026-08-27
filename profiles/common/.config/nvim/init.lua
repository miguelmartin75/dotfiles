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
vim.opt.autochdir = false
vim.opt.grepprg = "rg --vimgrep --smart-case"
vim.opt.grepformat = "%f:%l:%c:%m"

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

vim.opt.completeopt = { "menu", "menuone", "noselect" }

local lsp_configuration = vim.api.nvim_create_augroup("LspConfiguration", { clear = true })
local lsp_document_highlight = vim.api.nvim_create_augroup("LspDocumentHighlight", { clear = true })

vim.api.nvim_create_autocmd("LspAttach", {
    group = lsp_configuration,
    callback = function(ev)
        local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))

        if client:supports_method("textDocument/documentHighlight")
            and #vim.api.nvim_get_autocmds({
                group = lsp_document_highlight,
                event = "CursorHold",
                buffer = ev.buf,
            }) == 0
        then
            vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
                group = lsp_document_highlight,
                buffer = ev.buf,
                callback = vim.lsp.buf.document_highlight,
            })
            vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
                group = lsp_document_highlight,
                buffer = ev.buf,
                callback = vim.lsp.buf.clear_references,
            })
        end

        if client:supports_method("textDocument/completion") then
            vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = false })
        end
    end,
})

vim.api.nvim_create_autocmd("LspDetach", {
    group = lsp_configuration,
    callback = function(ev)
        local has_document_highlight_client = false
        for _, client in ipairs(vim.lsp.get_clients({ bufnr = ev.buf, method = "textDocument/documentHighlight" })) do
            if client.id ~= ev.data.client_id then
                has_document_highlight_client = true
                break
            end
        end

        if not has_document_highlight_client then
            vim.api.nvim_clear_autocmds({ group = lsp_document_highlight, buffer = ev.buf })
            vim.lsp.util.buf_clear_references(ev.buf)
        end
    end,
})

-- Install these external language-server executables outside Neovim: rust-analyzer,
-- typescript-language-server, clangd, zls, nimlangserver, lua-language-server, ty, and ols.
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

vim.lsp.config("*", { capabilities = vim.lsp.protocol.make_client_capabilities() })
vim.lsp.config("lua_ls", {
    settings = {
        Lua = {
            runtime = {
                version = "LuaJIT",
                path = { "lua/?.lua", "lua/?/init.lua" },
            },
            workspace = {
                checkThirdParty = false,
                library = { vim.env.VIMRUNTIME },
            },
        },
    },
})
vim.lsp.enable(servers)

vim.diagnostic.config({
    signs = true,
    underline = true,
    virtual_text = { prefix = "●", source = "if_many", spacing = 2 },
    severity_sort = true,
})

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

vim.keymap.set("i", "<C-Space>", function()
    vim.lsp.completion.get()
end, { desc = "Complete with LSP" })

vim.keymap.set("n", "[d", function()
    vim.diagnostic.jump({ count = -1 })
end, { desc = "Previous diagnostic" })
vim.keymap.set("n", "]d", function()
    vim.diagnostic.jump({ count = 1 })
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

vim.keymap.set("n", "<leader>p", '"+p', { desc = "Paste from system clipboard" })

local function global_cwd()
    return vim.fn.getcwd(-1, -1)
end

vim.keymap.set("n", "<leader>ff", function()
    Snacks.picker.files({ cwd = global_cwd(), hidden = true, follow = true })
end, { desc = "Find project files" })
vim.keymap.set("n", "<leader>fF", function()
    Snacks.picker.files({ cwd = global_cwd(), hidden = true, ignored = true, follow = true })
end, { desc = "Find all project files" })
vim.keymap.set("n", "<leader>fo", function()
    Snacks.picker.recent()
end, { desc = "Open recent file" })
vim.keymap.set("n", "<leader>fn", "<cmd>enew<cr>", { desc = "New file" })
vim.keymap.set("n", "<leader>fr", function()
    local path = vim.api.nvim_buf_get_name(0)
    if path == "" then
        path = global_cwd()
    end

    local root = vim.fs.root(path, ".git")
    if root then
        vim.api.nvim_set_current_dir(root)
        vim.notify("Global directory: " .. root)
    else
        vim.notify("No Git root found", vim.log.levels.WARN)
    end
end, { desc = "Set global directory to Git root" })
vim.keymap.set("n", "<leader>fd", function()
    local path = vim.api.nvim_buf_get_name(0)
    if path == "" then
        vim.notify("Current buffer has no filename", vim.log.levels.WARN)
    else
        local dir = vim.fn.fnamemodify(path, ":h")
        vim.api.nvim_set_current_dir(dir)
        vim.notify("Global directory: " .. dir)
    end
end, { desc = "Set global directory to buffer directory" })
vim.keymap.set("n", "<leader>fD", function()
    local path = vim.api.nvim_buf_get_name(0)
    if path == "" then
        vim.notify("Current buffer has no filename", vim.log.levels.WARN)
    else
        Snacks.picker.files({ cwd = vim.fn.fnamemodify(path, ":h"), hidden = true, follow = true })
    end
end, { desc = "Find files in buffer directory" })

vim.keymap.set("n", "<leader>bb", function()
    Snacks.picker.buffers()
end, { desc = "Find buffers" })
vim.keymap.set("n", "<leader>bd", "<cmd>bd<cr>", { desc = "Delete buffer" })
vim.keymap.set("n", "<leader>bD", "<cmd>%bd<cr>", { desc = "Delete all buffers" })

vim.keymap.set("n", "<leader>wh", "<C-W>h", { desc = "Focus left window" })
vim.keymap.set("n", "<leader>wl", "<C-W>l", { desc = "Focus right window" })
vim.keymap.set("n", "<leader>wj", "<C-W>j", { desc = "Focus lower window" })
vim.keymap.set("n", "<leader>wk", "<C-W>k", { desc = "Focus upper window" })
vim.keymap.set("n", "<leader>wq", "<C-W>q", { desc = "Close window" })
vim.keymap.set("n", "<leader>wx", "<C-W>x", { desc = "Exchange window" })
vim.keymap.set("n", "<leader>w=", "<C-W>=", { desc = "Equalize windows" })
vim.keymap.set("n", "<leader>w|", "<C-W>|", { desc = "Maximize window width" })
vim.keymap.set("n", "<leader>wtq", "<cmd>tabclose<cr>", { desc = "Close tab" })
vim.keymap.set("n", "<leader>wtc", "<cmd>tabnew<cr>", { desc = "Create tab" })
vim.keymap.set("n", "<leader>wt[", "<cmd>tabprevious<cr>", { desc = "Previous tab" })
vim.keymap.set("n", "<leader>wt]", "<cmd>tabnext<cr>", { desc = "Next tab" })

vim.keymap.set("n", "<leader>sl", function()
    Snacks.picker.lines()
end, { desc = "Find line in buffer" })
vim.keymap.set("n", "<leader>sh", function()
    Snacks.picker.search_history()
end, { desc = "Search history" })
vim.keymap.set("n", "<leader>sH", "<cmd>set hls!<cr>", { desc = "Toggle search highlight" })
vim.keymap.set("n", "<leader>sm", function()
    Snacks.picker.marks()
end, { desc = "Marks" })
vim.keymap.set("n", "<leader>sj", function()
    Snacks.picker.jumps()
end, { desc = "Jump list" })
vim.keymap.set("n", "<leader>ss", function()
    Snacks.picker.lsp_symbols()
end, { desc = "LSP symbols" })
vim.keymap.set("n", "<leader>sS", function()
    Snacks.picker.lsp_workspace_symbols()
end, { desc = "LSP workspace symbols" })
vim.keymap.set("n", "<leader>sc", function()
    Snacks.picker.commands()
end, { desc = "Commands" })
vim.keymap.set("n", "<leader>sd", function()
    vim.lsp.buf.definition()
end, { desc = "Go to definition" })
vim.keymap.set("n", "<leader>sD", function()
    vim.lsp.buf.declaration()
end, { desc = "Go to declaration" })
vim.keymap.set("n", "<leader>sb", function()
    Snacks.picker.grep_buffers()
end, { desc = "Grep buffers" })
vim.keymap.set("n", "<leader>sw", function()
    Snacks.picker.grep_word()
end, { desc = "Grep word" })
vim.keymap.set("n", "<leader>sn", function()
    vim.api.nvim_put({ os.date("%m/%d/%y %H:%M") }, "l", true, true)
end, { desc = "Insert timestamp" })
vim.keymap.set("n", "<leader>sg", function()
    vim.ui.input({ prompt = "Grep pattern: " }, function(pattern)
        if pattern and pattern ~= "" then
            vim.cmd({
                cmd = "grep",
                bang = true,
                args = { "--", vim.fn.shellescape(pattern), vim.fn.shellescape(global_cwd()) },
            })
            if #vim.fn.getqflist() > 0 then
                vim.cmd.copen()
            else
                vim.notify("No matches for: " .. pattern)
            end
        end
    end)
end, { desc = "Grep project" })
vim.keymap.set("n", "<leader>sr", function()
    Snacks.picker.lsp_references()
end, { desc = "References" })
vim.keymap.set("n", "<leader>st", function()
    Snacks.picker.lsp_type_definitions()
end, { desc = "Find type definition" })
vim.keymap.set("n", "<leader>si", function()
    Snacks.picker.lsp_implementations()
end, { desc = "Go to implementation" })
vim.keymap.set("n", "<leader>sI", function()
    Snacks.picker.lsp_incoming_calls()
end, { desc = "Incoming calls" })
vim.keymap.set("n", "<leader>sO", function()
    Snacks.picker.lsp_outgoing_calls()
end, { desc = "Outgoing calls" })

vim.keymap.set("n", "<leader>cf", function()
    vim.lsp.buf.format()
end, { desc = "Format" })
vim.keymap.set("x", "<leader>cf", function()
    vim.lsp.buf.format()
end, { desc = "Format selection" })
vim.keymap.set("n", "<leader>cw", function()
    vim.lsp.buf.add_workspace_folder()
end, { desc = "Add workspace folder" })
vim.keymap.set("n", "<leader>cW", function()
    vim.lsp.buf.remove_workspace_folder()
end, { desc = "Remove workspace folder" })
vim.keymap.set("n", "<leader>cl", function()
    vim.lsp.buf.list_workspace_folders()
end, { desc = "List workspace folders" })
vim.keymap.set("n", "<leader>cr", function()
    vim.lsp.buf.rename()
end, { desc = "Rename" })
vim.keymap.set("n", "<leader>ca", function()
    vim.lsp.buf.code_action()
end, { desc = "Code action" })
vim.keymap.set("n", "<leader>cs", function()
    vim.lsp.buf.signature_help()
end, { desc = "Signature help" })
vim.keymap.set("n", "<leader>ch", function()
    vim.lsp.buf.hover()
end, { desc = "Hover" })
vim.keymap.set("n", "<leader>ci", function()
    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, { desc = "Toggle inlay hints" })

vim.keymap.set("n", "<leader>dp", function()
    vim.diagnostic.jump({ count = -1 })
end, { desc = "Previous diagnostic" })
vim.keymap.set("n", "<leader>dn", function()
    vim.diagnostic.jump({ count = 1 })
end, { desc = "Next diagnostic" })
vim.keymap.set("n", "<leader>df", function()
    vim.diagnostic.open_float()
end, { desc = "Open diagnostic float" })
vim.keymap.set("n", "<leader>dl", function()
    vim.diagnostic.setloclist()
end, { desc = "Set diagnostic location list" })
vim.keymap.set("n", "<leader>dq", function()
    vim.diagnostic.setqflist()
end, { desc = "Set diagnostic quickfix list" })

vim.keymap.set("n", "<leader>ho", "<cmd>options<cr>", { desc = "Options" })
vim.keymap.set("n", "<leader>hh", function()
    Snacks.picker.help()
end, { desc = "Help tags" })
vim.keymap.set("n", "<leader>hm", function()
    Snacks.picker.man()
end, { desc = "Man pages" })
vim.keymap.set("n", "<leader>hl", function()
    vim.wo.number = not vim.wo.number
    vim.wo.relativenumber = not vim.wo.relativenumber
end, { desc = "Toggle line numbers" })
vim.keymap.set("n", "<leader>hk", function()
    local mappings = {}

    for _, mode in ipairs({ "n", "x", "i", "t" }) do
        for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
            if map.desc and map.desc ~= "" then
                table.insert(mappings, {
                    desc = map.desc,
                    lhs = map.lhs,
                    mode = mode,
                    scope = "global",
                })
            end
        end

        for _, map in ipairs(vim.api.nvim_buf_get_keymap(0, mode)) do
            if map.desc and map.desc ~= "" then
                table.insert(mappings, {
                    desc = map.desc,
                    lhs = map.lhs,
                    mode = mode,
                    scope = "buffer",
                })
            end
        end
    end

    table.sort(mappings, function(left, right)
        return left.lhs < right.lhs
    end)

    vim.ui.select(mappings, {
        prompt = "Keymap",
        format_item = function(item)
            return item.mode .. " " .. item.lhs .. " (" .. item.scope .. "): " .. item.desc
        end,
    }, function(item)
        if item then
            vim.notify(item.mode .. " " .. item.lhs .. " (" .. item.scope .. "): " .. item.desc)
        end
    end)
end, { desc = "Search keymaps" })
