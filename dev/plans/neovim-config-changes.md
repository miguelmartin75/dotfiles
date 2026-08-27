# Neovim configuration alignment plan

## Status

- Plan: complete
- Implementation: in progress
- Target: a sufficiently recent Neovim with `vim.pack`, `vim.lsp.config`, `vim.lsp.completion`, `vim.snippet`, `vim.system`, and current diagnostic APIs
- Primary configuration: `profiles/common/.config/nvim/init.lua`
- Implementation note: the configuration moved from the original `tilde/.config/nvim/init.lua` code pointers to the primary configuration path above; line numbers must be resolved against the current file before each phase.

## Goal

Rebuild the Neovim configuration around two constraints from `refs/editor-philosophy.md:1`:

1. Preserve programmer cognition by keeping recall, diagnosis, and semantic decisions explicit.
2. Prefer native Neovim primitives, then small owned Lua, then external tools, and use plugins only when they encapsulate substantial behavior.

The resulting editor should automatically provide verification and bookkeeping such as parsing, diagnostics, Git state, and LSP progress. Completion, documentation, search, and navigation should run only after an explicit command or mapping.

## Recommended architecture

Keep `tilde/.config/nvim/init.lua` as one compact, ordered configuration for leader setup, options, package declarations, plugin setup, LSP, diagnostics, search, and keymaps. The current file is long mainly because it contains overlapping and dead subsystems, so splitting every ordinary section into a Lua module would add indirection without earning it.

Use this startup order in `tilde/.config/nvim/init.lua`:

1. Set `vim.g.mapleader` and `vim.g.maplocalleader`.
2. Set core options and create required augroups.
3. Register `vim.pack` hooks, then add packages.
4. Configure retained plugins.
5. Configure LSP, diagnostics, completion, and language-specific behavior.
6. Define search/cwd commands and direct keymaps.

## Decisive subsystem choices

| Area | Decision | Reason |
| --- | --- | --- |
| Package management | Replace Packer with `vim.pack`, load the declared packages during init, and track the generated pack lockfile | The configuration does not use meaningful lazy loading, so a second package framework has no benefit. |
| LSP definitions | Keep `nvim-lspconfig` initially | The eight names at `tilde/.config/nvim/init.lua:338` depend on its command, filetype, and root defaults. Remove it only in a later change that supplies complete local server definitions. |
| Completion | Remove Blink and use built-in explicit completion first | The current automatic menu, documentation, insertion, and ghost text at `tilde/.config/nvim/init.lua:224` directly intercept recall. |
| Snippets | Use `vim.snippet` | No programmable snippet requirement exists. |
| Search picker | Keep Snacks and remove Telescope plus `telescope-fzf-native` | Most current picker mappings already use Snacks. One picker preserves interactive fuzzy selection without duplicate infrastructure. |
| Exhaustive text search | Use `rg` through `grepprg`, `:grep`, and quickfix | This composes an external search tool with durable native result navigation. |
| Mapping discovery | Remove WhichKey and add an explicit keymap search command | Described mappings can be discovered on demand using Neovim APIs and `vim.ui.select`. |
| Git | Keep Gitsigns and remove `mini.diff` | Gitsigns owns substantial asynchronous Git state; the current `mini.diff` source is disabled. |
| General diff | Use native diff commands and mappings | No second diff plugin is needed for file comparison. |
| Lint and format | Use LSP diagnostics and `vim.lsp.buf.format` | No current use case justifies none-ls, Conform, or a lint orchestration plugin. |
| Treesitter | Keep Treesitter and Treesitter Context, add `nvim-treesitter-textobjects` from `main`, and use native node selection | Parsing and portable query-backed function/parameter operations are substantial functionality; Neovim already owns generic syntax-node selection. |
| Prose editing | Remove Goyo and Pencil; use `Snacks.zen()` for focus mode and direct buffer-local prose options | Snacks already supplies the layout behavior, while native wrapping, formatting, and spelling cover the configured prose workflow without another plugin. |
| AI integration | Remove Sidekick and stale CodeCompanion hooks without adding a replacement in this refactor | Agent integration is outside this plan's editor-core scope. |
| Conversation UI | Defer it | The Markdown conversation tree in `refs/editor-philosophy.md:610` is an optional project and is not needed to align the editor configuration. |

## Plugin disposition

### Retain

- `nvim-treesitter/nvim-treesitter`, `nvim-treesitter/nvim-treesitter-textobjects` on its `main` branch, and `nvim-treesitter-context`: parser-backed highlighting and folds, a deliberately small function/parameter selection and motion layer, native syntax-node selection, and bounded structural context. The textobjects plugin is a direct package whose compatible revision is recorded in `packlockfile`; do not use the frozen legacy module bundled with the old `nvim-treesitter` architecture.
- `lewis6991/gitsigns.nvim`: live Git state and hunk operations.
- `folke/snacks.nvim`: the one interactive fuzzy picker.
- `neovim/nvim-lspconfig`: server definition database for the existing server list.
- `j-hui/fidget.nvim`: LSP progress only. Remove the unrelated custom CodeCompanion progress layer.
- `mcchrish/zenbones.nvim` and `rktjmp/lush.nvim`: the selected colorscheme and its dependency.
- `jpalardy/vim-slime`: retain unchanged as the primary send-text, send-selection, and REPL workflow. Preserve its tmux target, IPython, and dispatch settings at `tilde/.config/nvim/init.lua:490`.
- `glacambre/firenvim`, `godlygeek/tabular`, `jubnzv/mdeval.nvim`, `tpope/vim-surround`, `tpope/vim-repeat`, and `christoomey/vim-tmux-navigator`: retain as distinct browser, Markdown, editing, and tmux workflows, then exercise each during the final plugin audit.

### Remove

- `wbthomason/packer.nvim` and its bootstrap at `tilde/.config/nvim/init.lua:1`.
- `nvim-telescope/telescope.nvim` and `telescope-fzf-native.nvim` at `tilde/.config/nvim/init.lua:58`.
- `williamboman/nvim-lsp-installer`, `folke/lua-dev.nvim`, and `nvimtools/none-ls.nvim` at `tilde/.config/nvim/init.lua:47`.
- `folke/which-key.nvim`, `folke/sidekick.nvim`, `echasnovski/mini.diff`, and `saghen/blink.cmp` at `tilde/.config/nvim/init.lua:64`.
- `tjdevries/colorbuddy.vim`, which has no setup or consumer.
- `ziglang/zig.vim`, because recent Neovim filetype support plus Treesitter and `zls` cover the configured Zig workflow. Restore it only for a named feature that those layers do not provide.
- `nvim-lua/plenary.nvim`, because none of the retained package declarations require it after Telescope is removed.
- `nvim-mini/mini.icons`, because the retained configuration does not need icon rendering and currently asks it for ASCII output only.
- `junegunn/goyo.vim`, because the already-retained Snacks package provides centered focus mode, UI toggles, and state restoration through `Snacks.zen()`.
- `reedes/vim-pencil`, because the current configuration never initializes it and the required prose behavior is covered directly by buffer-local native options and commands.

The final package list must document a one-line user-facing purpose for every retained plugin. Fix verification failures in retained workflows without reopening the package selection unless implementation uncovers a concrete incompatibility.

## Current problems to eliminate

- The declaration at `tilde/.config/nvim/init.lua:48` installs `lua-dev.nvim`, while `tilde/.config/nvim/init.lua:307` requires `neodev`. A clean package store should fail here, so an apparently working setup may depend on undeclared stale files.
- Packer build hooks at `tilde/.config/nvim/init.lua:8`, `tilde/.config/nvim/init.lua:10`, `tilde/.config/nvim/init.lua:61`, and `tilde/.config/nvim/init.lua:77` do not translate into `vim.pack` specifications. Treesitter and Firenvim update actions need deliberate replacements; the FZF and Blink hooks disappear with those plugins.
- Telescope and Snacks implement overlapping selection workflows at `tilde/.config/nvim/init.lua:58`, `tilde/.config/nvim/init.lua:88`, and `tilde/.config/nvim/init.lua:356`.
- Blink advertises automatic completion behavior at `tilde/.config/nvim/init.lua:224`, and its capability augmentation at `tilde/.config/nvim/init.lua:336` couples LSP startup to the completion plugin.
- `vim.lsp.buf.formatting` and `vim.lsp.buf.range_formatting` at `tilde/.config/nvim/init.lua:779`, plus `vim.lsp.diagnostic` at `tilde/.config/nvim/init.lua:788`, are obsolete on recent Neovim.
- The LSP attachment callback at `tilde/.config/nvim/init.lua:316` uses a stale capability field and clears a shared augroup per buffer, allowing multiple client attachments to replace one another's hooks.
- Treesitter folding at `tilde/.config/nvim/init.lua:487` is overwritten by syntax folding at `tilde/.config/nvim/init.lua:545`.
- The terminal autocmd at `tilde/.config/nvim/init.lua:553` forces insert mode whenever a terminal window is re-entered.
- `<leader>p` is both a complete clipboard mapping at `tilde/.config/nvim/init.lua:650` and a prefix for LSP picker mappings at `tilde/.config/nvim/init.lua:770`.
- File finding, buffer-line search, buffer deletion, implementation lookup, and type-definition lookup each have duplicate mappings in `tilde/.config/nvim/init.lua:717`.
- Literal `TODO` map bodies at `tilde/.config/nvim/init.lua:746` execute normal-mode keystrokes instead of representing placeholders.
- `set rtp+=/usr/local/bin/` at `tilde/.config/nvim/init.lua:498` confuses the executable path with Neovim's runtime path.
- The TypeScript filetype autocmd at `tilde/.config/nvim/init.lua:565` prints stale debug output.
- Dead code includes `t`, unused `ops` members, `local M`, the commented completion implementation, old tab helpers, the disabled `mini.diff` setup, and CodeCompanion handlers without a declared CodeCompanion plugin.

## Project-root and path contract

Adopt one explicit contract before rebuilding search mappings:

- The global cwd is the project root for file finding, text search, and relative path completion.
- Neovim never changes cwd merely because a buffer or window changed.
- LSP roots remain protocol-specific and never silently become picker or grep roots.
- Add an explicit action that sets global cwd to the nearest Git root by locating `.git` with `vim.fs.root`.
- Add an explicit action that sets global cwd to the current buffer directory using `vim.fn.fnamemodify` and `vim.api.nvim_set_current_dir`.
- If no `.git` ancestor exists, notify the user and leave cwd unchanged.
- If the current buffer has no filename, buffer-directory cwd and picker actions notify the user and leave cwd unchanged.
- Provide one explicit buffer-directory file picker as the exceptional non-project scope.
- Pass the selected cwd explicitly to project-scoped Snacks file pickers. Do not override protocol-specific LSP scope or cwd-independent picker sources.
- Avoid interpolating `%:p:h` into Ex commands. Paths containing spaces and special characters must work through APIs.

## Target mapping contract

Use direct `vim.keymap.set` calls with `desc` metadata. One canonical hierarchical mapping owns each operation, with one short alias only for operations used often enough to justify it.

| Prefix | Ownership |
| --- | --- |
| `<leader>f` | Files and cwd |
| `<leader>b` | Buffers |
| `<leader>w` | Windows and tabs |
| `<leader>s` | Text, symbols, references, commands, and other explicit retrieval |
| `<leader>c` | LSP code actions, rename, format, hover, signature, and inlay hints |
| `<leader>d` | Diagnostic navigation, float, location list, and quickfix list |
| `<leader>g` | Gitsigns and Git operations |
| `<leader>h` | Help, options, introspection, and keymap search |

Retain standard short aliases such as `gd`, `gD`, `gi`, `K`, `[d`, `]d`, `[h`, and `]h` only when they are the single allowed high-frequency alias. Keep `<leader>p` as clipboard paste and remove the old `<leader>p...` family entirely.

The keymap search command must combine `vim.api.nvim_get_keymap(mode)` with `vim.api.nvim_buf_get_keymap(0, mode)`, include modes and descriptions in its labels, omit group-only placeholders, and use `vim.ui.select`. It is display-only: after selection it shows the exact lhs, mode, scope, and description but does not call a callback or execute an arbitrary rhs outside its mapping context.

## Phase 1: Establish a clean native package and startup baseline

Status: complete

This phase must produce a usable editor before deeper behavior changes.

### Changes

1. Move leader assignment from `tilde/.config/nvim/init.lua:640` to the first lines of the file and express it in Lua.
2. Replace `packadd packer.nvim` and the `require('packer').startup` block at `tilde/.config/nvim/init.lua:1` with one ordered `vim.pack.add(specs, { confirm = false, load = true })` call. `load = true` is required so retained Vimscript plugin files such as surround, vim-slime, and tmux-navigator are sourced during init rather than only placed on `runtimepath`.
3. Register any `PackChanged` update hooks before the first `vim.pack.add` call:
   - Filter on `ev.data.spec.name` and `ev.data.kind` and handle only successful install/update events for the relevant package.
   - Unconditionally call `vim.cmd.packadd(ev.data.spec.name)` for the affected package before calling its code. During a fresh install the spec can be marked active before its plugin and autoload files have been sourced, so checking `ev.data.active` is insufficient.
   - After a Treesitter package update, call `require('nvim-treesitter').update():wait(300000)` and report timeout or update failures visibly.
   - Declare `nvim-treesitter-textobjects` from its `main` branch next to `nvim-treesitter`. It has no build hook. Let `vim.pack` record both package revisions in `packlockfile`, and review/update them together because the textobjects plugin consumes the parser/query runtime provided by the current `nvim-treesitter` architecture.
   - After a Firenvim install or update, call `vim.fn['firenvim#install'](0)` and report failures visibly. Skip only when `NVIM_SKIP_EXTERNAL_INSTALL=1`, which is reserved for the isolated test environment below, then verify the native-host update separately in the deliberate real user environment.
   - Do not imitate Packer build hooks with `vim.system` when the plugin exposes a supported Lua, Ex, or Vim function API.
4. Track the generated file named by `packlockfile` alongside the configuration. Do not edit the lockfile by hand.
5. Apply the plugin retain/remove decisions above. Replace the remaining Telescope-only `oldfiles` and `vim_options` mappings at `tilde/.config/nvim/init.lua:729` and `tilde/.config/nvim/init.lua:792` before deleting Telescope.
6. Place plugin setup after `vim.pack.add` returns, then apply the colorscheme after Zenbones is available.
7. Remove the mismatched `neodev` require before testing with a clean package directory.
8. Convert intentional options from the large Vimscript block at `tilde/.config/nvim/init.lua:485` to `vim.opt` or `vim.o`. Remove defaults, duplicate `syntax` and filetype commands, identical tmux cursor branches, invalid runtimepath modification, and misleading comments.
9. Disable global spell checking and enable it only for `markdown`, `text`, and `gitcommit` buffers.
10. Replace the shell-backed timestamp action with `os.date` or `vim.fn.strftime`.

### Implementation result

- Replaced Packer with one eager `vim.pack` package graph and tracked the generated 16-package lockfile.
- Registered Treesitter and Firenvim update hooks before package activation; isolated startup skips only the external Firenvim host installation.
- Removed every package and package-bound setup selected for removal, including the custom `rust_analyzer` override requested during implementation.
- Converted the retained editor options and mappings to Lua, kept spelling buffer-local, and replaced the shell timestamp command with `os.date`.
- Current `nvim-treesitter` `main` no longer provides `nvim-treesitter.configs`, so the clean-start baseline uses its top-level `setup()` API before Phase 4 adds parser activation and textobjects.
- Clean isolated bootstrap and second startup passed. Steady-state `hyperfine` measurement over 10 runs improved from 174.8 ms +/- 9.0 ms for the old `~/.config/nvim/init.lua` to 112.5 ms +/- 12.2 ms for this phase, or 1.55x faster. Startup produced no messages and left `v:errmsg` empty.
- The real user-environment Firenvim native-host installation remains part of the Phase 4 specialty workflow verification because it writes outside the isolated test tree.

### Verification

- Create a temporary XDG fixture with `mktemp -d`, copy `tilde/.config/nvim` into its `XDG_CONFIG_HOME/nvim`, and point `XDG_DATA_HOME`, `XDG_STATE_HOME`, and `XDG_CACHE_HOME` into the same temporary root. Start Neovim headlessly twice against that copied config. The first run covers package installation and the second covers steady-state ordering without reading or writing the real package store.
- Run the temporary bootstrap with `NVIM_SKIP_EXTERNAL_INSTALL=1` so it skips `firenvim#install(0)`. Exercise that hook separately in the real user environment because it writes the browser native-host integration outside the temporary Neovim state.
- Run `:checkhealth vim.pack` and inspect the lockfile.
- Confirm every retained plugin module, command, or behavior loads without relying on an old Packer package tree.
- Search the configuration for `packer`, `telescope`, `neodev`, `lua-dev`, `nvim-lsp-installer`, `none-ls`, `sidekick`, `mini.diff`, and removed plugin setup names.

### Success criteria

- `vim.pack` is the only package manager.
- Startup succeeds from an empty managed package directory and on the next launch.
- No retained setup runs before its package is available.
- Every retained package has a stated purpose and every removed package has no remaining `require`, command, mapping, or hook.

## Phase 2: Rebuild LSP, diagnostics, formatting, and explicit completion

Status: complete

### Changes

1. Keep the server list at `tilde/.config/nvim/init.lua:338`, but verify each name is still supplied by `nvim-lspconfig`: `rust_analyzer`, `ts_ls`, `clangd`, `zls`, `nim_langserver`, `lua_ls`, `ty`, and `ols`.
2. Treat each language server executable as a system or development-environment prerequisite. Document its executable name and do not install it through Neovim.
3. Configure common LSP behavior with current `vim.lsp.config` and enable the server list with `vim.lsp.enable`.
4. Configure `lua_ls` directly with LuaJIT/Neovim runtime information and the Neovim runtime library. Add exceptional plugin library paths only when a real diagnostic or completion gap demonstrates the need.
5. Replace the `on_attach` implementation at `tilde/.config/nvim/init.lua:316` with one idempotent `LspAttach` autocmd:
   - Use `client:supports_method('textDocument/documentHighlight')`.
   - Create buffer-local highlight and clear-reference autocmds only once.
   - Clean up on `LspDetach` when the final supporting client leaves.
   - Let the colorscheme own the LSP reference highlight groups; do not install hard-coded replacement colors.
6. Remove Blink capability augmentation. Enable built-in LSP completion per attached supporting client with `vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = false })`.
7. Bind `<C-Space>` in insert mode to `vim.lsp.completion.get()`. Preserve native semantic completion choices:
   - `<C-x><C-o>` for LSP/omni completion.
   - `<C-x><C-f>` for paths.
   - `<C-x><C-n>` for buffer keywords.
   - `<C-x><C-l>` for whole lines.
   - `<C-y>` to accept a selected completion item.
8. Use `completeopt` settings that do not preselect or insert a candidate. Do not enable inline completion, automatic documentation, ghost text, or automatic signature help.
9. Use `vim.snippet` for completion-item snippet expansion and default snippet placeholder navigation. Add custom snippet mappings only if the defaults conflict with retained mappings.
10. Replace deprecated formatting mappings at `tilde/.config/nvim/init.lua:779` with `vim.lsp.buf.format()`. Use one normal-mode mapping for the buffer and one visual-mode mapping that lets the current API infer the visual selection instead of maintaining range calculations.
11. Configure built-in diagnostics for automatic signs, underline, and concise virtual text or current-line virtual lines. Keep floats, navigation, location lists, and quickfix population explicit.
12. Replace diagnostic navigation and list calls with current `vim.diagnostic.jump`, `vim.diagnostic.open_float`, `vim.diagnostic.setloclist`, and `vim.diagnostic.setqflist` APIs.
13. Use LSP diagnostics and formatting only. If a concrete non-LSP tool is later required, add a direct `:make`/`errorformat` or `vim.system` integration before considering a plugin.

### Implementation result

- Enabled all eight current `nvim-lspconfig` definitions through shared built-in client configuration and kept every server executable as an external prerequisite.
- Configured `lua_ls` for LuaJIT and the Neovim runtime without plugin-specific library paths or a custom `rust_analyzer` override.
- Added one idempotent attach/detach lifecycle for explicit completion and document highlights; a simulated two-client buffer retained hooks after the first detach and removed them after the final detach.
- Replaced deprecated format and diagnostic calls with current normal/visual formatting and diagnostic jump, float, location-list, and quickfix APIs.
- Preserved explicit completion through `<C-Space>`, native completion modes, native snippet handling, and `<C-y>` acceptance without automatic menus, documentation, signatures, or ghost text.
- Clean isolated startup and the available `clangd` attachment passed. Missing server executables remain documented environment prerequisites. A paired 20-run `hyperfine` sample measured Phase 1 at 120.3 ms +/- 49.9 ms and Phase 2 at 119.5 ms +/- 42.0 ms; system-noise outliers affected both samples, no material regression was observed, startup produced no messages, and `v:errmsg` remained empty.

### Verification

- Run `:checkhealth vim.lsp` and confirm every installed server attaches with its intended root.
- Exercise a buffer with two attached clients and verify document highlight autocmds are neither duplicated nor erased.
- Verify definitions, references, implementation, type definition, hover, signature, rename, code action, inlay toggle, format, and visual range format.
- Type without invoking completion and confirm no menu, documentation, signature, ghost text, or suggestion appears.
- Exercise all four native completion modes and accept an LSP completion item that contains a snippet or additional text edit.
- Confirm diagnostics remain automatic and can be jumped, floated, and exported to location and quickfix lists explicitly.

### Success criteria

- LSP uses only Neovim's built-in client plus `nvim-lspconfig` definitions.
- Language servers are external prerequisites, not editor-managed packages.
- Completion and documentation appear only after explicit invocation.
- Diagnostics remain automatic verification.
- No deprecated LSP or diagnostic API name remains.

## Phase 3: Consolidate root-aware search and canonical mappings

Status: complete

### Changes

1. Implement the project-root contract above before configuring any picker.
2. Set `grepprg` to `rg --vimgrep --smart-case` and set a matching `grepformat`.
3. Add a canonical project grep mapping that prompts for a pattern, shell-escapes the pattern, invokes `grep!` through structured `vim.cmd` arguments so Ex separators cannot be injected, and opens quickfix only when results exist.
4. Pass the global cwd only to project-scoped Snacks file selection. Keep oldfiles global, keep buffers/help/man/commands/marks/jumps independent of cwd, and let LSP selectors use their protocol-defined roots.
5. Delete all Telescope setup and extension loading at `tilde/.config/nvim/init.lua:304` and `tilde/.config/nvim/init.lua:356`.
6. Translate real WhichKey mappings at `tilde/.config/nvim/init.lua:717` to direct `vim.keymap.set` calls. Delete group-only entries, literal `TODO` maps, and all historical commented mapping code.
7. Apply the target mapping namespaces. Eliminate the identified duplicate find-file, line-search, buffer-delete, implementation, and type-definition bindings.
8. Replace `:cd %:p:h` and `:lcd %:p:h` string interpolation at `tilde/.config/nvim/init.lua:731` with path-safe Lua APIs.
9. Implement explicit keymap search from global and current-buffer maps and place it under `<leader>h`.
10. Add a non-persistent headless acceptance check that enumerates the resulting keymaps, fails on unintended exact-map/prefix conflicts, and groups mappings by normalized description to expose semantic duplicates. Do not add this audit to runtime configuration.

### Implementation result

- Established the global cwd as the explicit project root for project file selection and native `rg` quickfix search, even when a window has its own local cwd.
- Added path-safe actions for setting the global cwd to a Git root or named buffer directory, plus an exceptional buffer-directory file picker with unnamed-buffer notifications.
- Replaced overlapping search paths with Snacks interactive selectors and a canonical structured `:grep!` flow that uses `--`, shell-escaped input, an explicit global-root path, and durable quickfix results.
- Consolidated direct mappings into the target namespaces, retained the allowed LSP and diagnostic short aliases, restored timestamp and option toggles, and removed the old `<leader>p` picker family.
- Added display-only keymap search over global and current-buffer maps. The non-persistent audit checked 69 configuration mappings with no exact or prefix conflicts and reported only intended canonical/short-alias semantic duplicates.
- Path-with-spaces, local-cwd override, leading-dash pattern, Ex injection, quickfix reopen, unnamed-buffer, and picker scope checks passed. A paired 20-run `hyperfine` sample measured Phase 2 at 107.8 ms +/- 24.6 ms and Phase 3 at 112.2 ms +/- 24.3 ms; the 4.4 ms difference was within the noisy distributions, startup produced no messages, and `v:errmsg` remained empty.

### Verification

- Open a project whose path contains spaces.
- Confirm file finding, project grep, and relative path completion use the global cwd.
- Confirm changing buffers does not change cwd.
- Explicitly set cwd to the Git root and buffer directory and verify both actions are path-safe.
- Confirm `:grep` results populate quickfix and remain navigable after the quickfix window closes and reopens.
- Enumerate normal, visual, insert, terminal, and buffer-local mappings; inspect prefix conflicts and duplicate descriptions.
- Find a rare mapping through keymap search, note its lhs, close the selector, and invoke that lhs normally.

### Success criteria

- Snacks is the only fuzzy picker implementation.
- `rg` plus quickfix is the canonical exhaustive text-search path.
- Root behavior is explicit and identical across file and text search.
- Each meaningful operation has one canonical described mapping.
- No complete mapping is unintentionally the prefix of a mapping family.

## Phase 4: Finish Git, Treesitter, terminal, and specialty workflows

Status: complete

### Changes

1. Configure Gitsigns with direct mappings for previous/next hunk, preview, stage, reset, blame line, and diff against a revision. Put Git actions under `<leader>g` and hunk motion on `[h` and `]h`.
2. Remove the disabled `mini.diff` block at `tilde/.config/nvim/init.lua:133`. Keep native `:diffsplit`, `:diffthis`, `[c`, `]c`, `do`, and `dp` for general comparisons.
3. Migrate from the legacy `require('nvim-treesitter.configs').setup` call at `tilde/.config/nvim/init.lua:395` to the current `nvim-treesitter` main API. Document `tar`, `curl`, a C compiler, and the current supported `tree-sitter-cli` as external prerequisites. Define one parser list for `c`, `cpp`, `rust`, `lua`, `python`, `typescript`, `javascript`, `zig`, `nim`, `odin`, `markdown`, and `markdown_inline`, then call `require('nvim-treesitter').install(parser_list)`. Use `:wait(300000)` only in explicit bootstrap and test paths, not on every normal startup.
4. Add a `FileType` autocmd over the supported filetypes. In its callback, call `vim.treesitter.start(args.buf)`, set the window-local fold expression to `v:lua.vim.treesitter.foldexpr()`, and select `foldmethod=expr`. Do not enable experimental Treesitter indentation; retain Neovim filetype indentation plus the explicit two-space overrides below.
5. After defining parser activation, configure `nvim-treesitter-textobjects` once through its current top-level `setup` API. Enable only `select` and `move`, use the plugin's `textobjects` query group, and set `move.set_jumps = true`. Keep this direct configuration in `tilde/.config/nvim/init.lua`; do not create an owned Treesitter motions module.
6. Extend the `FileType` callback after its successful `vim.treesitter.start(args.buf)` call. Obtain the active parser language and load its `textobjects` query with protected calls. Inspect the query captures before installing described buffer-local mappings, so a missing parser, missing query, or missing capture leaves the buffer's native mappings intact and produces no startup or `FileType` error. Install each operation only when its required capture exists:
   - In Visual and operator-pending modes, map `af` to `@function.outer`, `if` to `@function.inner`, `aa` to `@parameter.outer`, and `ia` to `@parameter.inner` through `nvim-treesitter-textobjects.select.select_textobject`.
   - In Normal, Visual, and operator-pending modes, intentionally replace the built-in `[m`, `]m`, `[M`, and `]M` mappings with query-backed previous function start, next function start, previous function end, and next function end through `nvim-treesitter-textobjects.move`.
   - Preserve counts for every selection and motion callback and verify operator-pending use such as `d2af` and `d2]m`; do not collapse a count to one in a Lua wrapper.
   - Never overwrite `[d`/`]d` diagnostics, `[c`/`]c` native diff motions, `[h`/`]h` Gitsigns hunk motions, native section motions `[[`, `]]`, `[]`, and `][`, `;`/`,` character-search repeat, native `.` repeat, or Neovim's native node selections `an`, `in`, `[n`, `]n`, `[N`, and `]N`.
7. Keep the semantic scope deliberately narrow. Defer class, block, loop, conditional, swap, and repeatable-move features until a concrete workflow requires them.
8. Delete the copied Treesitter Context pattern table and configure only the intended behavior, including `max_lines = 3`.
9. Remove both old folding assignments at `tilde/.config/nvim/init.lua:487` and `tilde/.config/nvim/init.lua:545`; the filetype activation above is the only fold implementation.
10. Delete the terminal `WinEnter`/`BufWinEnter` `startinsert` autocmd. Add one explicit mapping that enters terminal input.
11. Rewrite non-Treesitter filetype-specific indentation as a Lua `FileType` autocmd over explicit filetype names. Remove the TypeScript debug message.
12. Configure `Snacks.zen()` as the only focus mode and add one described `<leader>wz` toggle. For `markdown` and `text` buffers, set `wrap`, `linebreak`, `breakindent`, `spell`, and `textwidth=0` locally. Keep native `gj`, `gk`, and `gq` behavior instead of remapping cursor movement or adding automatic prose formatting.
13. Smoke-test every retained specialty plugin by its intended command or behavior and fix configuration or compatibility failures.

### Implementation result

- Added current Gitsigns hunk navigation and mechanical Git actions, with native diff retained for general comparisons.
- Installed and activated the 12 declared current Treesitter parsers in an isolated fixture, enabled query-gated function and parameter textobjects with counted UTF-8-safe selections and motions, and limited Treesitter Context to three lines.
- Kept Markdown on Neovim's native section and node mappings without duplicate built-in Markdown maps or cleanup warnings, and made missing semantic queries degrade without buffer-local semantic mappings.
- Replaced automatic terminal insertion with an explicit terminal-input mapping, added the Snacks Zen toggle, and confined prose window options to markdown, text, and gitcommit buffers.
- Current-parser runtime checks passed across all ten code languages. Deep count coverage passed for locked Lua and Python queries, including reversed endpoints, Visual character/line/block modes, operator-pending use, excessive counts, UTF-8 parameters, motion boundaries, and jumplist behavior.
- Gitsigns passed staged and unstaged hunk attach, navigation, preview, blame, stage, reset, and revision diff checks. Retained specialty plugins passed command, mapping, or API smoke checks.
- Fresh isolated startup produced no messages and left `v:errmsg` empty. A paired 20-run startup measurement increased from 93.1 ms +/- 2.3 ms in Phase 3 to 101.5 ms +/- 3.4 ms in Phase 4, a measured 8.4 ms cost for parser, Git, and specialty workflow activation.
- Browser-host Firenvim integration, a real tmux/slime target, rendered Context height, and fully interactive Zen, surround/repeat, and mdeval behavior remain environment or UI-level manual checks; their configured commands and APIs load successfully.

### Verification

- In a temporary Git repository, create staged and unstaged hunks and exercise every Gitsigns mapping.
- Exercise native diff independently of Gitsigns.
- Open one file for every declared parser and confirm highlighting and folds start without parser errors.
- For `c`, `cpp`, `rust`, `lua`, `python`, `typescript`, `javascript`, `zig`, `nim`, and `odin`, open fixtures containing nested functions and multi-parameter declarations. Where the upstream `textobjects` query exposes all four required captures, verify `af`, `if`, `aa`, and `ia` in Visual and operator-pending modes and all four function motions in Normal, Visual, and operator-pending modes. Treat a missing required capture in a configured code language as an explicit compatibility result to resolve or document, not as an unconditional mapping that later fails at use time.
- Exercise counts from multiple cursor positions, confirm function motions add jumplist entries, and confirm the start/end motions land on the queried range boundaries.
- Open Markdown and Markdown-inline fixtures without a usable function/parameter `textobjects` query and confirm the semantic maps are not installed, no error is raised, and `an`, `in`, `[n`, `]n`, `[N`, and `]N` still provide native node selection.
- Extend the mapping conflict audit to all buffer-local semantic maps. Confirm that only `[m`, `]m`, `[M`, and `]M` are intentional replacements and that diagnostics, diff, hunks, `[[`/`]]`/`[]`/`][` section motions, `;`/`,` character-search repeat, native `.` repeat, and native node selection remain available.
- Confirm sticky context never exceeds the configured cap.
- Enter terminal-normal mode, switch away and back, and confirm Neovim preserves that state.
- Exercise Firenvim, Snacks Zen, native prose wrapping and formatting, Markdown, surround/repeat, REPL, and tmux navigation workflows and fix any retained workflow that fails its smoke test.

### Success criteria

- Gitsigns is the only Git-buffer state plugin and exposes all required mechanical hunk actions.
- General comparison uses native diff.
- The parser list matches actual language workflows and only one fold method is effective.
- Native node selection works without a plugin, while query-backed function/parameter mappings appear only in buffers with the required parser query and captures.
- Function and parameter selections work in Visual and operator-pending use, function boundary motions work with counts in Normal, Visual, and operator-pending use, and function motions populate the jumplist.
- Markdown and any language without the required query degrade cleanly without masking native mappings or producing errors.
- The textobjects package and `nvim-treesitter` are lockfile-tracked and can be reviewed and updated together without using the legacy Treesitter module API.
- Terminal-normal mode survives window changes.
- Snacks Zen is the only focus-mode implementation, and prose buffers use only explicit native buffer-local wrapping, spelling, and formatting behavior.
- No specialty plugin remains without a named, working workflow.

## Phase 5: Final cleanup and acceptance

Status: in progress

### Changes

1. Delete dead helpers, unused imports, copied example tables, commented subsystem configurations, old debugging output, and stale TODOs throughout `tilde/.config/nvim/init.lua`.
2. Keep direct code for one-off actions. Introduce a helper only when behavior is repeated more than three times or owns meaningful state.
3. Normalize all configuration to spaces and LF line endings.
4. Add a short maintenance section near package declarations documenting:
   - `:packupdate` review and confirmation flow.
   - The tracked `packlockfile`.
   - External language-server and `rg` prerequisites.
   - The project-root contract.
5. Run the complete acceptance suite below.

### Acceptance suite

- Parse and format all Lua configuration.
- Start Neovim headlessly twice with no errors or unexpected messages.
- Run `:checkhealth vim.pack`, `:checkhealth vim.lsp`, and health checks for retained plugins.
- Search for removed dependencies, stale API names, literal TODO map bodies, global helper tables, duplicate subsystem setup, and large commented blocks.
- Verify every advertised mapping and run the prefix/duplicate mapping audit.
- Verify core edit, search, quickfix, LSP, diagnostic, format, Git, Treesitter, terminal, and vim-slime REPL workflows.
- Measure startup only to catch regressions or obvious synchronous work. Do not add lazy-loading machinery without a demonstrated problem.

### Overall success criteria

- Neovim starts cleanly from a fresh package state and uses `vim.pack` exclusively.
- Automatic behavior is limited to parsing, diagnostics, Git indicators, indentation, compiler/type feedback, semantic information, and useful progress.
- Completion, documentation, signature help, search, and navigation require explicit invocation.
- There is one LSP layer, one completion strategy, one fuzzy picker, one Git state plugin, and native general diff.
- File finding, grep, and relative path behavior follow one documented cwd policy.
- All mappings are described, discoverable, non-duplicative, and free of accidental exact-prefix ambiguity.
- The active configuration contains no historical experiments, dead handlers, invalid runtime paths, startup dependencies on stale packages, or obsolete APIs.

## References

### Codebase

- Philosophy and target architecture: `refs/editor-philosophy.md:1`
- Preferred package, LSP, completion, formatting, and diagnostic architecture: `refs/editor-philosophy.md:75`
- Search and keymap architecture: `refs/editor-philosophy.md:240`
- Git, diff, Treesitter, Lua, cwd, and terminal architecture: `refs/editor-philosophy.md:359`
- Cleanup and overall target: `refs/editor-philosophy.md:685`
- Current package graph: `tilde/.config/nvim/init.lua:1`
- Current completion, LSP, picker, and Treesitter setup: `tilde/.config/nvim/init.lua:223`
- Current options and autocmds: `tilde/.config/nvim/init.lua:485`
- Current mappings and AI integration: `tilde/.config/nvim/init.lua:671`

### Neovim documentation

- `vim.pack`, lockfile behavior, hooks, and update flow: https://neovim.io/doc/user/pack/
- Built-in LSP configuration, attachment, and explicit completion: https://neovim.io/doc/user/lsp/
- Built-in diagnostics: https://neovim.io/doc/user/diagnostic/
- Built-in snippets: https://neovim.io/doc/user/lua.html#vim.snippet
- Deprecated APIs and their replacements: https://neovim.io/doc/user/deprecated/
- Current `nvim-treesitter` main setup and parser lifecycle: https://github.com/nvim-treesitter/nvim-treesitter
- Neovim native Treesitter node selections and parser/query APIs: https://neovim.io/doc/user/treesitter/
- Current `nvim-treesitter-textobjects` `main` setup, select API, move API, and jumplist behavior: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
- Firenvim post-install integration: https://github.com/glacambre/firenvim
