vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.no_markdown_maps = 1

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
local last_edit_position = vim.api.nvim_create_augroup("LastEditPosition", { clear = true })

vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
    group = filetype_options,
    pattern = "*",
    callback = function(ev)
        local prose = vim.bo[ev.buf].filetype == "markdown" or vim.bo[ev.buf].filetype == "text"

        vim.wo.wrap = prose
        vim.wo.linebreak = prose
        vim.wo.breakindent = prose
        vim.wo.spell = prose or vim.bo[ev.buf].filetype == "gitcommit"

        if prose then
            vim.bo[ev.buf].textwidth = 0
        end
    end,
})

vim.api.nvim_create_autocmd("FileType", {
    group = filetype_options,
    pattern = { "css", "html", "nim", "javascript", "typescript", "php" },
    callback = function(ev)
        vim.bo[ev.buf].tabstop = 2
        vim.bo[ev.buf].softtabstop = 2
        vim.bo[ev.buf].shiftwidth = 2
    end,
})

vim.api.nvim_create_autocmd("TermOpen", {
    group = filetype_options,
    callback = function(ev)
        vim.keymap.set("n", "<leader>wi", "i", { buffer = ev.buf, desc = "Enter terminal input" })
    end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
    group = last_edit_position,
    callback = function(ev)
        local position = vim.api.nvim_buf_get_mark(ev.buf, '"')
        if position[1] > 0 and position[1] <= vim.api.nvim_buf_line_count(ev.buf) then
            vim.api.nvim_win_set_cursor(0, position)
        end
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
    -- Discoverable leader-key mappings and group labels.
    "https://github.com/folke/which-key.nvim",
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

-- Maintenance: run :lua vim.pack.update(), review its changes, and confirm the updates you keep.
-- nvim-pack-lock.json records the reviewed package revisions for this configuration.
-- Install language servers and rg outside Neovim; picker and search cwd is the explicit global cwd.

local Snacks = require("snacks")
Snacks.setup({
    styles = {},
    picker = {
        layout = {
            preview = "main",
            preset = "ivy",
            layout = {
                position = "bottom",
            },
        },
        config = function(opts)
            opts.layout.preset = "ivy"
            return opts
        end,
    },
    zen = {},
})

local which_key = require("which-key")
which_key.setup({
    icons = { mappings = false },
})
which_key.add({
    { "<leader>b", group = "Buffers" },
    { "<leader>c", group = "Code" },
    { "<leader>d", group = "Diagnostics" },
    { "<leader>f", group = "Files" },
    { "<leader>g", group = "Git" },
    { "<leader>h", group = "Help" },
    { "<leader>r", group = "REPL" },
    { "<leader>s", group = "Search" },
    { "<leader>t", group = "Terminals and REPL" },
    { "<leader>w", group = "Windows" },
    { "<leader>wt", group = "Tabs" },
})

local gitsigns = require("gitsigns")
gitsigns.setup({
    on_attach = function(bufnr)
        vim.keymap.set("n", "[h", function()
            gitsigns.nav_hunk("prev")
        end, { buffer = bufnr, desc = "Previous hunk" })
        vim.keymap.set("n", "]h", function()
            gitsigns.nav_hunk("next")
        end, { buffer = bufnr, desc = "Next hunk" })
        vim.keymap.set("n", "<leader>gp", gitsigns.preview_hunk, { buffer = bufnr, desc = "Preview hunk" })
        vim.keymap.set("n", "<leader>gs", gitsigns.stage_hunk, { buffer = bufnr, desc = "Stage hunk" })
        vim.keymap.set("n", "<leader>gr", gitsigns.reset_hunk, { buffer = bufnr, desc = "Reset hunk" })
        vim.keymap.set("n", "<leader>gb", gitsigns.blame_line, { buffer = bufnr, desc = "Blame line" })
        vim.keymap.set("n", "<leader>gd", function()
            vim.ui.input({ prompt = "Diff against revision: ", default = "HEAD" }, function(revision)
                if revision and revision ~= "" then
                    gitsigns.diffthis(revision)
                end
            end)
        end, { buffer = bufnr, desc = "Diff against revision" })
    end,
})
require("fidget").setup()

vim.g.slime_target = "tmux"
vim.g.slime_default_config = { socket_name = "default", target_pane = "{last}" }
vim.g.slime_python_ipython = 1
vim.g.slime_dispatch_ipython_pause = 350

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

        if client:supports_method("textDocument/signatureHelp") then
            vim.keymap.set("i", "<C-k>", function()
                vim.lsp.buf.signature_help()
            end, { buffer = ev.buf, desc = "Signature help" })
            vim.b[ev.buf].lsp_signature_help_mapped = true
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

        local has_signature_help_client = false
        for _, client in ipairs(vim.lsp.get_clients({ bufnr = ev.buf, method = "textDocument/signatureHelp" })) do
            if client.id ~= ev.data.client_id then
                has_signature_help_client = true
                break
            end
        end

        if not has_signature_help_client and vim.b[ev.buf].lsp_signature_help_mapped then
            vim.keymap.del("i", "<C-k>", { buffer = ev.buf })
            vim.b[ev.buf].lsp_signature_help_mapped = nil
        end
    end,
})

-- Install these external language-server executables outside Neovim: rust-analyzer,
-- typescript-language-server, clangd, zls, nimlangserver, lua-language-server, ty, ruff, and ols.
local servers = {
    "rust_analyzer",
    "ts_ls",
    "clangd",
    "zls",
    "nim_langserver",
    "lua_ls",
    "ty",
    "ruff",
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

-- nvim-treesitter requires tar, curl, a C compiler, and tree-sitter-cli 0.26.1 or newer.
local parser_filetypes = {
    "c",
    "cpp",
    "rust",
    "lua",
    "python",
    "typescript",
    "javascript",
    "zig",
    "nim",
    "odin",
    "markdown",
    "markdown_inline",
}
-- Neovim 0.12.5's bundled Lua parser matches its bundled Lua queries; current external Lua does not.
if vim.fn.executable("tree-sitter") == 1 then
    require("nvim-treesitter").install(vim.tbl_filter(function(filetype)
        return filetype ~= "lua"
    end, parser_filetypes))
else
    vim.notify("tree-sitter CLI not found; parser installation skipped", vim.log.levels.WARN)
end

require("nvim-treesitter-textobjects").setup({
    select = { lookahead = true },
    move = { set_jumps = true },
})

local treesitter_filetypes = vim.api.nvim_create_augroup("TreesitterFiletypes", { clear = true })

local function selection_range()
    local anchor = vim.fn.getpos("v")
    local start = { anchor[2], anchor[3] - 1 }
    local finish = vim.api.nvim_win_get_cursor(0)
    if finish[1] < start[1] or (finish[1] == start[1] and finish[2] < start[2]) then
        start, finish = finish, start
    end
    return start, finish
end

local function set_visual_selection(start, finish)
    vim.api.nvim_win_set_cursor(0, finish)
    vim.cmd.normal({ "o", bang = true })
    vim.api.nvim_win_set_cursor(0, start)
    vim.cmd.normal({ "o", bang = true })
end

local function next_character(position)
    local row, col = unpack(position)
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
    local next_col = vim.str_byteindex(line, vim.str_utfindex(line, col) + 1)
    if next_col < #line then
        return { row, next_col }
    elseif row < vim.api.nvim_buf_line_count(0) then
        return { row + 1, 0 }
    end
end

local function select_textobject_with_count(textobject)
    local select = require("nvim-treesitter-textobjects.select")
    local count = vim.v.count1

    select.select_textobject(textobject, "textobjects")
    local mode = vim.api.nvim_get_mode().mode
    if count == 1 or (mode ~= "v" and mode ~= "V" and mode ~= "\22") then
        return
    end

    local selection_start, selection_end = selection_range()
    local last_start, last_end = selection_start, selection_end
    set_visual_selection(selection_start, selection_end)

    for _ = 2, count do
        local probe = next_character(last_end)
        local selected = false

        while probe do
            vim.api.nvim_win_set_cursor(0, probe)
            select.select_textobject(textobject, "textobjects")
            local next_start, next_end = selection_range()
            local same_object = next_start[1] == last_start[1]
                and next_start[2] == last_start[2]
                and next_end[1] == last_end[1]
                and next_end[2] == last_end[2]
            local after_last = next_start[1] > last_end[1]
                or (next_start[1] == last_end[1] and next_start[2] > last_end[2])

            if next_start[1] == selection_start[1]
                and next_start[2] == selection_start[2]
                and next_end[1] == probe[1]
                and next_end[2] == probe[2]
            then
                break
            elseif after_last and not same_object then
                selection_end = next_end
                last_start, last_end = next_start, next_end
                set_visual_selection(selection_start, selection_end)
                selected = true
                break
            else
                set_visual_selection(selection_start, selection_end)
                probe = next_character(probe)
            end
        end

        if not selected then
            set_visual_selection(selection_start, selection_end)
            break
        end
    end
end

vim.api.nvim_create_autocmd("FileType", {
    group = treesitter_filetypes,
    pattern = parser_filetypes,
    callback = function(ev)
        local started = pcall(vim.treesitter.start, ev.buf)
        if not started then
            return
        end

        vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
        vim.wo.foldmethod = "expr"

        local has_parser, parser = pcall(vim.treesitter.get_parser, ev.buf)
        if not has_parser then
            return
        end

        local has_language, language = pcall(function()
            return parser:lang()
        end)
        if not has_language then
            return
        end

        local has_query, query = pcall(vim.treesitter.query.get, language, "textobjects")
        if not has_query or not query then
            return
        end

        local captures = {}
        for _, capture in ipairs(query.captures) do
            captures[capture] = true
        end

        if captures["function.outer"] then
            vim.keymap.set({ "x", "o" }, "af", function()
                select_textobject_with_count("@function.outer")
            end, { buffer = ev.buf, desc = "Select function outer" })
            vim.keymap.set({ "n", "x", "o" }, "[m", function()
                require("nvim-treesitter-textobjects.move").goto_previous_start("@function.outer", "textobjects")
            end, { buffer = ev.buf, desc = "Previous function start" })
            vim.keymap.set({ "n", "x", "o" }, "]m", function()
                require("nvim-treesitter-textobjects.move").goto_next_start("@function.outer", "textobjects")
            end, { buffer = ev.buf, desc = "Next function start" })
            vim.keymap.set({ "n", "x", "o" }, "[M", function()
                require("nvim-treesitter-textobjects.move").goto_previous_end("@function.outer", "textobjects")
            end, { buffer = ev.buf, desc = "Previous function end" })
            vim.keymap.set({ "n", "x", "o" }, "]M", function()
                require("nvim-treesitter-textobjects.move").goto_next_end("@function.outer", "textobjects")
            end, { buffer = ev.buf, desc = "Next function end" })
        end

        if captures["function.inner"] then
            vim.keymap.set({ "x", "o" }, "if", function()
                select_textobject_with_count("@function.inner")
            end, { buffer = ev.buf, desc = "Select function inner" })
        end

        if captures["parameter.outer"] then
            vim.keymap.set({ "x", "o" }, "aa", function()
                select_textobject_with_count("@parameter.outer")
            end, { buffer = ev.buf, desc = "Select parameter outer" })
        end

        if captures["parameter.inner"] then
            vim.keymap.set({ "x", "o" }, "ia", function()
                select_textobject_with_count("@parameter.inner")
            end, { buffer = ev.buf, desc = "Select parameter inner" })
        end
    end,
})

require("treesitter-context").setup({
    max_lines = 3,
})

vim.keymap.set("i", "<C-Space>", function()
    vim.lsp.completion.get()
end, { desc = "Complete with LSP" })
vim.keymap.set("i", "<Tab>", function()
    if vim.fn.pumvisible() == 1 then
        return "<C-n>"
    elseif vim.snippet.active({ direction = 1 }) then
        return "<Cmd>lua vim.snippet.jump(1)<CR>"
    else
        return "<Tab>"
    end
end, { expr = true, desc = "Next completion or snippet placeholder" })
vim.keymap.set("i", "<S-Tab>", function()
    if vim.fn.pumvisible() == 1 then
        return "<C-p>"
    elseif vim.snippet.active({ direction = -1 }) then
        return "<Cmd>lua vim.snippet.jump(-1)<CR>"
    else
        return "<S-Tab>"
    end
end, { expr = true, desc = "Previous completion or snippet placeholder" })

vim.keymap.set("n", "[d", function()
    vim.diagnostic.jump({ count = -1 })
end, { desc = "Previous diagnostic" })
vim.keymap.set("n", "]d", function()
    vim.diagnostic.jump({ count = 1 })
end, { desc = "Next diagnostic" })
vim.keymap.set("n", "gd", function()
    Snacks.picker.lsp_definitions()
end, { desc = "Go to definition" })
vim.keymap.set("n", "gD", function()
    Snacks.picker.lsp_declarations()
end, { desc = "Go to declaration" })
vim.keymap.set("n", "gi", function()
    Snacks.picker.lsp_implementations()
end, { desc = "Go to implementation" })
vim.keymap.set("n", "K", function()
    vim.lsp.buf.hover()
end, { desc = "Hover" })

vim.keymap.set("n", "<leader>p", '"+p', { desc = "Paste from system clipboard" })
vim.keymap.set("n", "Y", '"+y', { desc = "Yank motion to system clipboard" })
vim.keymap.set("n", "YY", '"+yy', { desc = "Yank line to system clipboard" })
vim.keymap.set("x", "Y", '"+y', { desc = "Yank selection to system clipboard" })

local function global_cwd()
    return vim.fn.getcwd(-1, -1)
end

vim.keymap.set({ "n", "x" }, "<leader>ff", function()
    Snacks.picker.files({ cwd = global_cwd(), hidden = true, follow = true })
end, { desc = "Find project files" })
vim.keymap.set("n", "<leader>fF", function()
    Snacks.picker.files({ cwd = global_cwd(), hidden = true, ignored = true, follow = true })
end, { desc = "Find all project files" })
vim.keymap.set({ "n", "x" }, "<C-p>", function()
    Snacks.picker.files({ cwd = global_cwd(), hidden = true, ignored = true, follow = true })
end, { desc = "Find all project files" })
vim.keymap.set({ "n", "x" }, "<leader>fo", function()
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

vim.keymap.set({ "n", "x" }, "<leader>bb", function()
    Snacks.picker.buffers()
end, { desc = "Find buffers" })
vim.keymap.set({ "n", "x" }, "<leader>,", function()
    Snacks.picker.buffers()
end, { desc = "Find buffers" })
vim.keymap.set("n", "<leader>bd", "<cmd>bd<cr>", { desc = "Delete buffer" })
vim.keymap.set("n", "<leader>bD", "<cmd>%bd<cr>", { desc = "Delete all buffers" })
vim.keymap.set("n", "<leader>q", "<cmd>bd<cr>", { desc = "Delete buffer" })

vim.keymap.set({ "n", "x" }, "<leader>wh", "<C-W>h", { desc = "Focus left window" })
vim.keymap.set({ "n", "x" }, "<leader>wl", "<C-W>l", { desc = "Focus right window" })
vim.keymap.set({ "n", "x" }, "<leader>wj", "<C-W>j", { desc = "Focus lower window" })
vim.keymap.set({ "n", "x" }, "<leader>wk", "<C-W>k", { desc = "Focus upper window" })
vim.keymap.set({ "n", "x" }, "<leader>wq", "<C-W>q", { desc = "Close window" })
vim.keymap.set({ "n", "x" }, "<leader>wx", "<C-W>x", { desc = "Exchange window" })
vim.keymap.set({ "n", "x" }, "<leader>w=", "<C-W>=", { desc = "Equalize windows" })
vim.keymap.set({ "n", "x" }, "<leader>w|", "<C-W>|", { desc = "Maximize window width" })
vim.keymap.set({ "n", "x" }, "<leader>wz", "<cmd>only<cr>", { desc = "Focus window" })
vim.keymap.set("n", "<leader>z", function()
    Snacks.zen()
end, { desc = "Toggle Zen mode" })
vim.keymap.set({ "n", "x" }, "<leader>wtq", "<cmd>tabclose<cr>", { desc = "Close tab" })
vim.keymap.set({ "n", "x" }, "<leader>wtc", "<cmd>tabnew<cr>", { desc = "Create tab" })
vim.keymap.set({ "n", "x" }, "<leader>wt[", "<cmd>tabprevious<cr>", { desc = "Previous tab" })
vim.keymap.set({ "n", "x" }, "<leader>wt]", "<cmd>tabnext<cr>", { desc = "Next tab" })

vim.keymap.set("n", "<leader>tr", "<cmd>%SlimeSend<cr>", { desc = "Send buffer to REPL" })
vim.keymap.set("x", "<leader>tr", "<Plug>SlimeRegionSend", {
    remap = true,
    desc = "Send selection to REPL",
})

vim.keymap.set({ "n", "x" }, "<leader><cr>", "<cmd>set hlsearch!<cr>", {
    desc = "Toggle search highlighting",
})

vim.keymap.set({ "n", "x" }, "<leader>sl", function()
    Snacks.picker.lines()
end, { desc = "Find line in buffer" })
vim.keymap.set({ "n", "x" }, "<leader>/", function()
    Snacks.picker.lines()
end, { desc = "Find line in buffer" })
vim.keymap.set("n", "<leader>sh", function()
    Snacks.picker.search_history()
end, { desc = "Search history" })
vim.keymap.set("n", "<leader>?", function()
    Snacks.picker.search_history()
end, { desc = "Search history" })
vim.keymap.set("n", "<leader>sH", function()
    Snacks.picker.highlights()
end, { desc = "Highlights" })
vim.keymap.set("n", "<leader>sm", function()
    Snacks.picker.marks()
end, { desc = "Marks" })
vim.keymap.set("n", "<leader>m", function()
    Snacks.picker.marks()
end, { desc = "Marks" })
vim.keymap.set("n", "<leader>sj", function()
    Snacks.picker.jumps()
end, { desc = "Jump list" })
vim.keymap.set("n", "<leader>j", function()
    Snacks.picker.jumps()
end, { desc = "Jump list" })
vim.keymap.set({ "n", "x" }, "<leader>ss", function()
    Snacks.picker.lsp_symbols()
end, { desc = "LSP symbols" })
vim.keymap.set({ "n", "x" }, "<leader>sS", function()
    Snacks.picker.lsp_workspace_symbols()
end, { desc = "LSP workspace symbols" })
vim.keymap.set("n", "<leader>sc", function()
    Snacks.picker.commands()
end, { desc = "Commands" })
vim.keymap.set({ "n", "x" }, "<leader>sd", function()
    Snacks.picker.lsp_definitions()
end, { desc = "Go to definition" })
vim.keymap.set({ "n", "x" }, "<leader>sD", function()
    Snacks.picker.lsp_declarations()
end, { desc = "Go to declaration" })
vim.keymap.set("n", "<leader>sb", function()
    Snacks.picker.grep_buffers()
end, { desc = "Grep buffers" })
vim.keymap.set({ "n", "x" }, "<leader>sw", function()
    Snacks.picker.grep_word({ cwd = global_cwd() })
end, { desc = "Grep word" })
vim.keymap.set("n", "<leader>sn", function()
    vim.api.nvim_put({ os.date("%m/%d/%y %H:%M") }, "l", true, true)
end, { desc = "Insert timestamp" })
vim.keymap.set({ "n", "x" }, "<leader>sg", function()
    Snacks.picker.grep({ cwd = global_cwd() })
end, { desc = "Grep project" })
vim.keymap.set({ "n", "x" }, "<leader>sr", function()
    Snacks.picker.lsp_references()
end, { desc = "References" })
vim.keymap.set("n", "<leader>st", function()
    Snacks.picker.lsp_type_definitions()
end, { desc = "Find type definition" })
vim.keymap.set({ "n", "x" }, "<leader>si", function()
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
vim.keymap.set({ "n", "x" }, "<leader>cr", function()
    vim.lsp.buf.rename()
end, { desc = "Rename" })
vim.keymap.set({ "n", "x" }, "<leader>ca", function()
    vim.lsp.buf.code_action()
end, { desc = "Code action" })
vim.keymap.set("n", "<leader>cs", function()
    vim.lsp.buf.signature_help()
end, { desc = "Signature help" })
vim.keymap.set({ "n", "x" }, "<leader>ch", function()
    vim.lsp.buf.hover()
end, { desc = "Hover" })
vim.keymap.set({ "n", "x" }, "<leader>ci", function()
    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, { desc = "Toggle inlay hints" })

vim.keymap.set({ "n", "x" }, "<leader>dp", function()
    vim.diagnostic.jump({ count = -1 })
end, { desc = "Previous diagnostic" })
vim.keymap.set({ "n", "x" }, "<leader>dn", function()
    vim.diagnostic.jump({ count = 1 })
end, { desc = "Next diagnostic" })
vim.keymap.set({ "n", "x" }, "<leader>df", function()
    vim.diagnostic.open_float()
end, { desc = "Open diagnostic float" })
vim.keymap.set({ "n", "x" }, "<leader>dl", function()
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
vim.keymap.set({ "n", "x" }, "<leader>hl", function()
    vim.wo.number = not vim.wo.number
    vim.wo.relativenumber = not vim.wo.relativenumber
end, { desc = "Toggle line numbers" })
vim.keymap.set("n", "<leader>hk", function()
    Snacks.picker.keymaps()
end, { desc = "Search keymaps" })
