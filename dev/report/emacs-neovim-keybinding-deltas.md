# Emacs and Neovim effective keybinding deltas

## Scope and method

This report compares the effective keyboard behavior established by
`profiles/common/.config/emacs/init.el` and
`profiles/common/.config/nvim/init.lua`. It treats `SPC` as the leader in
normal and visual state, and compares commands by outcome rather than by
function name. `Same` means the configured keys and practical result align,
`Mismatch` means the same key or mnemonic has materially different behavior,
and `Emacs only` or `Neovim only` marks a one-sided capability.

The explicit mappings are stable repository facts. Package mappings are
effective only after the package loads, and buffer-local LSP, parser, Git,
Markdown, terminal, and special-mode maps exist only in eligible buffers.
Package-default observations use the installed packages represented by
`profiles/common/.config/nvim/nvim-pack-lock.json` and the packages selected
by `profiles/common/.config/emacs/install-packages.el`. Evil Collection calls
`evil-collection-init` without limiting its mode list, so it can change keys
in every supported special mode as installed package versions change
(`profiles/common/.config/emacs/init.el:395-398`). Neovim default observations
refer to the installed 0.12.5 runtime. The report lists important inherited
maps, not every ordinary Vim/Evil editing motion.

## Executive delta

The two configurations deliberately align most leader mnemonics for files,
buffers, windows, tabs, search, LSP, diagnostics, Git hunks, and REPL send.
The largest semantic differences are:

- Neovim pickers have a direct `C-q` path that sends selected items, or all
  items when none are selected, to quickfix. Emacs currently needs
  `C-c . S` for a generic Embark Collect snapshot, or `C-c . E` for a
  type-aware Embark export.
- Neovim has a search-highlight toggle and Emacs has none. In the current
  source the effective key is `SPC RET`, at
  `profiles/common/.config/nvim/init.lua:657-659`. The reported `SPC h`
  binding is not present: `SPC h` is a Help prefix and requires another key
  (`profiles/common/.config/nvim/init.lua:188-189,778-791`).
- Neovim adds tmux-boundary navigation, smart snippet traversal, quickfix and
  location-list workflows, buffer deletion, workspace-folder management, and
  several Neovim 0.12 LSP defaults. Emacs adds window-layout history, remote
  file access, Magit, durable terminal sessions, richer help, Org, extensive
  Markdown structure editing, and AI/review commands.
- Emacs makes `j` and `k` operate on display lines through global visual-line
  behavior; Neovim normally uses file lines and enables wrapping only for
  Markdown and text buffers.

## Core modal navigation and editing

| Status | Semantic operation | Emacs | Neovim | Effective delta |
| --- | --- | --- | --- | --- |
| Same | Vim modal editing | Evil supplies `h/j/k/l`, operators, text objects, registers, marks, macros, `u`, `C-r`, `/`, `?`, `n/N`, `*`, `#`, jumps, and folds | Neovim built-ins supply the corresponding behavior | Broad parity, subject to Evil edge cases |
| Mismatch | Vertical `j` and `k` | `evil-better-visual-line` plus global visual-line mode makes motions follow wrapped display lines (`init.el:385,401-404`) | `j/k` follow file lines; `gj/gk` follow display lines, while wrapping is enabled only for Markdown/text (`init.lua:36-49`) | Muscle memory diverges in wrapped text |
| Neovim only | Horizontal cross-line motion | `h/l` stop at line boundaries by ordinary Evil behavior | `whichwrap` adds `<`, `>`, `h`, and `l` (`init.lua:28`) | Neovim `h/l` may cross a line boundary |
| Same | Function motions | Parser-backed `[m`, `]m`, `[M`, `]M` are installed in normal, visual, and operator state (`init.el:1241-1247`) | Treesitter installs the same keys in normal, visual, and operator mode when captures exist (`init.lua:486-501`) | Same keys; availability depends on parser/query support |
| Neovim only | Structural text objects | No configured parser-specific equivalents | `af/if` select outer/inner function and `aa/ia` outer/inner parameter (`init.lua:486-519`) | Evil retains ordinary text objects but lacks these structural selections |
| Same | Surround editing | `evil-surround` globally enables add/change/delete surroundings (`init.el:390-393`) | `vim-surround` supplies `ys`, `yss`, `cs`, `ds`, visual `S`, and insert surround maps | Nearly identical plugin vocabulary |
| Mismatch | Leave insert state | `C-g` explicitly enters normal state; `C-h` deletes backward and joins (`init.el:369-370`) | Escape leaves insert; `C-g` remains a built-in insert prefix and `C-h` backspaces | Emacs adds a non-Vim escape chord |
| Mismatch | Increment/decrement number | `C-c +` and `C-c -` in normal/visual state (`init.el:406-411`) | Built-in `C-a` and `C-x` | Same capability, different keys |
| Neovim only | Comment operator | No configured Evil comment operator | Neovim 0.12 defaults `gc` and `gcc` | One-sided modal comment vocabulary |
| Neovim only | Insert blank line | No matching modal map | Neovim 0.12 defaults `[SPC` and `]SPC` | One-sided operation |
| Same | Open path or URI | Evil `gx` opens URL at point | Neovim 0.12 `gx` uses the system handler | Equivalent intent |

## Search, highlighting, marks, and jumps

| Status | Operation | Emacs | Neovim | Delta |
| --- | --- | --- | --- | --- |
| Same | Incremental buffer search | Vim `/` plus explicit `C-s` in normal, visual, and insert state (`init.el:1718-1719`) | Vim `/`; no global `C-s` search map | `/` aligns; `C-s` is Emacs only |
| Emacs only | Search current selection | `evil-visualstar` makes visual `*`/`#` search selected text (`init.el:388`) | Normal Vim visual search does not natively use the selection | Emacs adds selection-aware star search |
| Neovim only | Toggle search match highlighting | No leader equivalent | `SPC RET` toggles `hlsearch` (`init.lua:657-659`) | Requested parity gap. The reported `SPC h` is stale or mistaken; current `SPC h` opens Help |
| Same | Current-buffer line picker | `SPC /`, `SPC s l` -> `consult-line` | Same keys -> `Snacks.picker.lines` | Same outcome |
| Same | Search history | `SPC ?`, `SPC s h` -> `consult-isearch-history` | Same keys -> Snacks search history | Same outcome |
| Same | Search open buffers | `SPC s b` -> `consult-line-multi` across all buffers | `SPC s b` -> Snacks `grep_buffers` | Similar result; filtering and preview UI differ |
| Same | Project grep | `SPC s g` -> `consult-ripgrep` | `SPC s g` -> Snacks grep using global cwd | Same intent |
| Mismatch | Search word or selection | `SPC s w` searches active region, including escaped multiline text, or symbol at point (`init.el:531-553`) | `SPC s w` invokes Snacks grep-word against global cwd (`init.lua:706-708`) | Emacs supports arbitrary/multiline selection; Neovim is word-oriented |
| Same | Marks and jumps picker | `SPC m`/`SPC s m`, `SPC j`/`SPC s j` use Evil lists | Same keys use Snacks pickers | Neovim has fuzzy picker UI; Emacs uses Evil list UI |
| Mismatch | Highlight inspection | `SPC s H` describes the face at point | `SPC s H` opens a picker of highlight groups | Same mnemonic, different target and UI |
| Neovim only | Timestamp | None | `SPC s n` inserts `%m/%d/%y %H:%M` below the cursor (`init.lua:709-711`) | One-sided utility |

## Pickers, candidate actions, and result persistence

| Status | Operation | Emacs Consult/Embark | Neovim Snacks | Delta |
| --- | --- | --- | --- | --- |
| Same | Candidate movement | `C-n/C-p` in completion minibuffers and completion lists (`init.el:469-492`) | `C-n/C-p`, `C-j/C-k`, arrows, and `j/k` in picker windows | Core movement aligns; Snacks has more aliases |
| Mismatch | Multi-select | Embark general action `SPC` selects a candidate after `C-c .` | Picker `TAB` selects and advances; `S-TAB` selects and retreats; `C-a` selects all | Snacks exposes selection directly; Embark routes through its action map |
| Mismatch | Act on candidate | Global `C-c .` -> `embark-act` (`init.el:437-439`) | Picker `RET` confirms; picker-specific keys open splits/tabs or toggle options | Embark has richer target-type action maps but a longer entry chord |
| Mismatch | Persist results | `C-c . S` -> `embark-collect`, a generic tabulated snapshot; `C-c . E` -> `embark-export`, a type-specific buffer | `C-q` sends selected or all picker results to quickfix | Same goal, different container and chord |
| Emacs only | Type-aware exports | `embark-export` produces Dired for files, Ibuffer for buffers, Occur for Consult locations, grep-mode for Consult grep, and xref buffers for Consult xref, falling back to Collect | No type-directed equivalent from the configured picker | This is more semantically capable than a generic quickfix export |
| Emacs only | Persistent-result modal keys | Evil Collection makes Embark Collect open in normal state with `a/A` act/act-all, `E` export, `m` select, and `gr` refresh; Xref results get `C-j/C-k`, `C-n/C-p`, `[[/]]`, `RET`, `o`, and `r` | Quickfix uses Neovim's normal mode and 0.12 `[q`/`]q` navigation | Both are modal, but their result-buffer command vocabularies differ |
| Neovim only | Open candidate elsewhere | No uniform direct Consult keys; use Embark actions | Picker `C-s`, `C-v`, `C-t`, and `S-RET` open split, vertical split, tab, or chosen window | One-sided direct picker UI |
| Neovim only | Picker option toggles | No common direct equivalents | `M-h/M-i/M-r/M-p/M-m/M-f` toggle hidden, ignored, regex, preview, maximize, and follow | One-sided direct picker controls |

### Recommended Embark mapping

Map `C-q` to `embark-export`, not `embark-collect`. Export is the closer
semantic counterpart to Snacks quickfix because it turns a result set into the
native persistent result buffer best suited to its candidate type. With
`embark-consult`, grep results become grep-mode and xrefs become xref buffers;
unsupported candidate types already fall back to `embark-collect`. Mapping
directly to Collect would discard that type-aware behavior.

Shorten candidate actions to `C-.` only in completion minibuffers. Preserve
the existing global `C-c .` binding for acting on targets outside completion
and as a fallback. Do not globally replace `C-.`: Evil normal state already
uses `C-.` for `evil-repeat-pop`, so a global binding would be shadowed there
or require removing useful Evil behavior. Do not bind `C-q` globally either:
outside pickers it is the conventional quoted-insert key and can matter in
ordinary editing and terminal input.

Because Embark currently loads only when `C-c .` is first invoked
(`profiles/common/.config/emacs/init.el:437-439`), add `:demand t` to its
`use-package` declaration. Embark must install its completion metadata hook
before a `*Completions*` buffer is created; otherwise the first export from an
already-open list can recover its candidates but not their type, and therefore
falls back to a generic Collect buffer.

The least invasive exact key scopes are:

```elisp
(keymap-set minibuffer-local-completion-map "C-." #'embark-act)
(keymap-set minibuffer-local-filename-completion-map "C-." #'embark-act)
(keymap-set completion-list-mode-map "C-." #'embark-act)
(keymap-set minibuffer-local-completion-map "C-q" #'embark-export)
(keymap-set minibuffer-local-filename-completion-map "C-q" #'embark-export)
(keymap-set completion-list-mode-map "C-q" #'embark-export)
```

`minibuffer-local-must-match-map` inherits the completion map, while the
filename completion map is independent and therefore needs its own entries.
The completion-list entries cover a focused `*Completions*` window. These
scopes avoid stealing either Evil's normal-state `C-.` or global `C-q`. The
only intentional local conflict is that `C-q` can no longer invoke
quoted-insert inside a completion minibuffer or completion list. `C-c . S`
remains available for an explicitly generic Collect snapshot and `C-c . E`
remains an export alias.

## Files and buffers

| Status | Operation | Emacs | Neovim | Delta |
| --- | --- | --- | --- | --- |
| Same | Find project files | `SPC f f` | `SPC f f` | Both include hidden files and follow links; backend/project-root rules differ |
| Same | Find all files | `SPC f F`, `C-p` -> recursive root picker | Same keys -> Snacks files with hidden and ignored files | Same intent; both override an inherited `C-p` behavior |
| Same | Recent files | `SPC f o` -> Consult recent | `SPC f o` -> Snacks recent | Same |
| Same | Find in buffer directory | `SPC f D` | `SPC f D` | Same outcome |
| Mismatch | Change working directory | `SPC f r`/`SPC f d` change the current buffer's `default-directory` | Same keys change Neovim's global cwd | Same mnemonic, different scope; Emacs is buffer-local, Neovim is process-global |
| Emacs only | General and remote file picker | `SPC f h`, `C-x C-f` use the custom picker; `SPC f R` selects an SSHX path | No remote-specific key | Emacs has explicit TRAMP access |
| Neovim only | New unnamed file | No leader map | `SPC f n` -> `:enew` | Emacs can use ordinary `C-x b`/new file flow but has no matching leader command |
| Same | Buffer picker | `SPC ,`, `SPC b b` -> Consult buffer | Same keys -> Snacks buffers | Same |
| Neovim only | Delete buffers | No leader bindings | `SPC b d` and `SPC q` delete current; `SPC b D` deletes all | Emacs retains `C-x k` and commands but no parity mnemonic |
| Neovim only | Buffer/list traversal defaults | No matching bracket family | Neovim 0.12 `[b`/`]b` move buffers; `[q`/`]q` quickfix; `[l`/`]l` location list; first/last variants use uppercase | One-sided, broad list navigation vocabulary |

## Windows, tmux, zen mode, and tabs

| Status | Operation | Emacs | Neovim | Delta |
| --- | --- | --- | --- | --- |
| Same | Directional focus | `SPC w h/j/k/l` | Same | Same within editor |
| Neovim only | Cross tmux boundary | No equivalent | `C-h/j/k/l` traverse Neovim splits, then adjacent tmux panes; `C-\` returns to previous pane/split | Added by vim-tmux-navigator in normal mode and terminal mode when inside tmux |
| Same | Close/exchange/equalize/maximize/focus | `SPC w q/x/=/\|/z` | Same | Same intent; exact window state semantics differ |
| Emacs only | Layout history | `SPC w u` winner undo, `SPC w r` winner redo | No configured equivalent | One-sided reversible layout history |
| Mismatch | Zen/write modes | `SPC Z` write mode with zoom, `SPC z` without zoom, `SPC v` restores code mode | `SPC z` toggles Snacks Zen | Emacs offers three explicit states; Neovim one toggle |
| Same | Tab create/close/previous/next | `SPC w t c/q/[/]` | Same | Emacs tab-bar tabs and Neovim tab pages are not identical containers |
| Emacs only | Direct tab selection | `s-1` through `s-9`, `s-{`, `s-}`, `s-t`, `s-w` | Built-in `gt/gT` and `[t`/`]t`, but no configured numeric Super maps | One-sided GUI shortcuts |

## LSP, code actions, and symbols

| Status | Operation | Emacs Eglot | Neovim LSP | Delta |
| --- | --- | --- | --- | --- |
| Same | Definition/declaration/implementation | `gd`, `gD`, `gi` and `SPC s d/D/i` | Same keys | Consult/Xref and Snacks differ in presentation and multi-result handling |
| Same | References/type definition/calls | `SPC s r/t/I/O` | Same | Same intent; outgoing call hierarchy uses Eglot's `base` direction |
| Mismatch | Buffer symbols | `SPC s s` -> `consult-imenu` | `SPC s s` -> LSP document symbols | Emacs works without LSP and may reflect mode imenu; Neovim requires LSP |
| Mismatch | Workspace symbols | `SPC s S` -> Xref apropos | `SPC s S` -> LSP workspace symbols | Similar discovery goal, different provider and scope |
| Same | Format/rename/action/hover/inlay hints | `SPC c f/r/a/h/i`; Eglot also exposes `C-c e ...` aliases (`init.el:634-644,1787-1791`) | Same leader keys | Strong parity; availability depends on server capability |
| Neovim only | Signature help | `eldoc` can display signatures, but no dedicated map | `SPC c s`; buffer-local insert `C-k` when supported (`init.lua:259-264,752-754`) | Direct invocation only in Neovim |
| Neovim only | Workspace folder control | None | `SPC c w`, `SPC c W`, `SPC c l` add/remove/list folders | One-sided LSP administration |
| Neovim only | Neovim 0.12 LSP defaults | No equivalent default family | `grn` rename, `gra` action, `grr` references, `gri` implementation, `grt` type definition, `gO` document symbols, `grx` code lens, and `C-w d` diagnostic at cursor | These remain effective alongside the explicit leader maps |
| Mismatch | `K` documentation | `eldoc-doc-buffer` opens a documentation buffer | LSP hover popup | Same key and information, different persistence/UI |

### LSP multiplexing versus embedded-language documents

Rassumfrassum solves the Python multi-server gap, but it does not solve LSP
inside arbitrary Org or Markdown code blocks. It presents multiple servers as
one LSP server and forwards one document stream to them. It does not parse a
host document into per-language virtual documents or translate coordinates
between a code block and its host buffer. The official Eglot documentation
describes this same-document multiplexing model, and the Rassumfrassum
documentation shows each `textDocument/didOpen` being forwarded to the
underlying servers:

- https://elpa.gnu.org/devel/doc/eglot.html
- https://github.com/joaotavora/rassumfrassum

This distinction has the following effects in the current Emacs setup:

| Context | Current support | Why Rassumfrassum is insufficient |
| --- | --- | --- |
| Ordinary Python file | `rass python` can combine `ty` and `ruff` behind Eglot after replacing the explicit `ty`-only entry (`profiles/common/.config/emacs/init.el:621-632`) | Both servers consume the same Python document, URI, language ID, and coordinate space |
| Org source block | Org can open a block in its language's major mode with `C-c '`, but Eglot does not provide Org source-block virtual documents; upstream support remains an open enhancement | The block needs a stable source URI plus translation of requests, edits, diagnostics, and locations between block coordinates and the Org buffer |
| Markdown fenced block | Emacs 31 `markdown-ts-mode` provides embedded fontification and a limited code-block command context, but not a persistent language-specific LSP document; the fallback `markdown-mode` code-block editor also requires the unconfigured `edit-indirect` package (`profiles/common/.config/emacs/init.el:677-694,1262-1275`; `profiles/common/.config/emacs/install-packages.el:68`) | Sending the complete `.md` document to Python, Rust, or another ordinary language server does not make the fenced regions independent source files |

Retaining Eglot while adding transparent LSP for arbitrary Org and Markdown
code blocks therefore requires new custom software: an embedded-document
adapter that extracts and synchronizes virtual documents per language, assigns
usable URIs and language IDs, and maps positions, diagnostics, edits,
completion, navigation, and workspace operations in both directions. A custom
Rassumfrassum `LspLogic` implementation could be one host for that logic, but
it would be substantially more than a normal multiplexer preset. Tangling a
block to a real source file and editing that file is the simplest robust
workaround, but it is not transparent in-buffer LSP. The existing Eglot Org
request and Org's native edit-buffer behavior are documented at:

- https://github.com/joaotavora/eglot/issues/523
- https://orgmode.org/manual/Editing-Source-Code.html

## Diagnostics

| Status | Operation | Emacs Flymake | Neovim diagnostics | Delta |
| --- | --- | --- | --- | --- |
| Same | Previous/next | `[d`, `]d`, `SPC d p/n` | Same | Same |
| Mismatch | Detail view | `SPC d f` lists all diagnostics for the buffer | `SPC d f` floats the diagnostic at point | Same key, materially different scope |
| Mismatch | Aggregate view | `SPC d l` shows project diagnostics | `SPC d l` fills the current window's location list | Project-wide UI versus window-local list |
| Neovim only | Quickfix diagnostics | None | `SPC d q` fills quickfix | One-sided global navigable list |
| Neovim only | First/last diagnostic | No direct map | Neovim 0.12 defaults `[D` and `]D` | One-sided endpoints |
| Emacs only | Debugger | `SPC d D` launches Dape | No debugger configured | One-sided DAP workflow |

## Git hunks and repository workflows

| Status | Operation | Emacs diff-hl/Magit | Neovim Gitsigns | Delta |
| --- | --- | --- | --- | --- |
| Same | Previous/next hunk | Buffer-local `[h`/`]h` | Same, only after Gitsigns attaches | Same keys |
| Mismatch | Hunk navigation wrapping | diff-hl stops and reports no further hunk | Gitsigns inherits `wrapscan`, which is on by default, so navigation wraps | Same keys, different end behavior |
| Same | Preview/stage/reset | `SPC g p/s/r` | Same | Emacs reset asks for confirmation; Gitsigns reset is immediate |
| Mismatch | Preview reset | In diff-hl's preview, `r` hides then confirms revert (`init.el:573-595`) | Gitsigns preview does not add this exact local shortcut | Emacs-specific preview interaction |
| Emacs only | Repository status and annotations | `SPC g g` Magit status; `SPC g a` annotate current hunk | No status UI or annotation command | Neovim relies on external commands for full repository workflow |
| Neovim only | Blame and revision diff | No matching Emacs leader keys, although Magit exposes these operations | `SPC g b` blames the line; `SPC g d` prompts for a revision to diff | One-sided direct source-buffer shortcuts |

## Completion, snippets, clipboard, and editing

| Status | Operation | Emacs | Neovim | Delta |
| --- | --- | --- | --- | --- |
| Same | Trigger completion | Insert `C-SPC` -> completion help at point, aggregating applicable CAPFs | Insert `C-SPC` -> LSP completion | Same key; Emacs can include files/non-LSP CAPFs, Neovim is LSP-only |
| Mismatch | Candidate movement | `TAB`/`S-TAB` and `C-n/C-p` move completion candidates while completion is active | `TAB`/`S-TAB` move popup candidates, otherwise jump snippet placeholders, otherwise insert a tab | Neovim multiplexes snippets; Emacs has no configured snippet engine |
| Emacs only | Dynamic abbreviation | Insert `M-/` expands dabbrev; `C-M-/` completes dabbrev | No configured equivalent | One-sided text completion |
| Neovim only | Signature/completion insert collision | Emacs leaves the analogous insert key to existing maps | LSP-capable buffers bind insert `C-k` to signature help | Neovim buffer-local map replaces any prior insert `C-k` only while a supporting client is attached |
| Mismatch | System clipboard | `s-c/s-x/s-v` copy/cut/paste selection or whole line; `s-s` saves (`init.el:1652-1656`) | Leader `p` pastes from `+`; normal/visual `Y` yanks to `+`, with `YY` for a line (`init.lua:569-572`) | Different modifier vocabulary; normal `y/p` are not forced to system clipboard in Neovim |
| Mismatch | `C-p` inherited behavior | Explicit file picker replaces Evil paste-pop | Explicit file picker replaces normal-mode upward motion | Same chosen result, different displaced default |
| Emacs only | Cut/copy whole line fallback | Super cut/copy uses current line when no region | `Y`/`YY` only copy; deletion remains Vim operators | Different clipboard ergonomics |

## Help and introspection

| Status | Operation | Emacs | Neovim | Delta |
| --- | --- | --- | --- | --- |
| Mismatch | Main help | `SPC h h` opens Info | `SPC h h` searches help tags | Same key, different help system |
| Same | Manual pages | `SPC h m` | Same | Same |
| Mismatch | Options | `SPC h o` Customize UI | `SPC h o` `:options` | Both configure options, but persistence and UI differ |
| Emacs only | Describe entities | `SPC h f/v/c/k` describes function, variable, command, or key | No matching leader keys | Neovim has `:help`, but not these direct maps |
| Neovim only | Search effective keymaps | No matching picker; `SPC h k` describes one entered key | `SPC h k` opens Snacks keymap picker | Same key has different discovery model |
| Same | Toggle line numbers | `SPC l` and `SPC h l` toggle display numbers | `SPC h l` toggles absolute and relative numbers together | Main shared key is `SPC h l`; Emacs also has shorter `SPC l` |

## Terminals and REPL sending

| Status | Operation | Emacs | Neovim | Delta |
| --- | --- | --- | --- | --- |
| Same | Send buffer/selection | `SPC t r` reuses last target; visual `C-c C-r` also reuses it | Normal `SPC t r` sends buffer; visual sends selection to last tmux target | Same main chord and reuse intent |
| Emacs only | Choose destination | `SPC t R` and visual `C-c C-c` choose a target | vim-slime `C-c v` configures target, but there is no matching leader command | Different interaction; Emacs exposes target selection directly |
| Mismatch | Default `C-c C-c` | Global Emacs evaluates region; visual override sends selection | vim-slime normal sends paragraph and visual sends region | Same chord, mode-dependent and materially different |
| Emacs only | Terminal/session lifecycle | `SPC t p/t/l/h/o/c/g/z` covers project Ghostel, durable session open/list/history/link, project command, Ghostel split, and zmx split | No leader bindings to create/list/manage terminals | Major one-sided terminal workflow |
| Mismatch | Enter terminal input | Ghostel normal `o` or `RET` enters terminal input; insert `s-Escape` exits outer Evil insert | Terminal-buffer normal `SPC w i` enters terminal insert | Same need, different keys and two-axis Ghostel model |
| Mismatch | tmux-aware terminal navigation | Ghostel insert uses `C-b` as a window-prefix and `M-SPC` for leader, but does not automatically cross tmux | Terminal `C-h/j/k/l` crosses splits/panes when `$TMUX` is set | Different terminal multiplexer strategy |

## Markdown and Org

| Status | Operation | Emacs | Neovim | Delta |
| --- | --- | --- | --- | --- |
| Emacs only | Smart list return | Markdown `RET` and Org `RET` create a sibling item or remove an empty item (`init.el:683-756,1291-1316`) | No custom Markdown return | One-sided structured prose behavior |
| Emacs only | Markdown structure motion/editing | Buffer-local normal/visual `M-h/j/k/l` promotes, moves, and demotes headings/items/paragraphs/table cells; `g TAB` and `g S-TAB` cycle; `C-x n s` narrows (`init.el:1146-1167`) | `no_markdown_maps=1` disables legacy Markdown mappings; no replacement structure keys | Major one-sided Markdown surface |
| Emacs only | Markdown tables and fenced code | `SPC o m` aligns table; `SPC o RET`, `SPC t b/B` send fenced code | Tabular and mdeval commands are installed but have no configured keys | Capability exists in Neovim only by command, not keybinding |
| Emacs only | Org workflows | `SPC o a/c/n/i/t/r/RET` for agenda, capture, Roam find/insert, tags, table recalculation, and Babel execution; Evil Org adds modal Org/agenda keys | No Org configuration | Entire semantic area is one-sided |
| Emacs only | Evil Collection special-mode navigation | Embark Collect, Xref, Flymake, Dired, Help, Info, Magit, compilation, comint, Org, and other supported modes gain normal-state Vim navigation | Native Neovim buffers generally already use normal mode | This is important effective behavior, but mode maps are package-version dependent |

## Other one-sided or colliding leader capabilities

| Status | Key | Emacs | Neovim | Consequence |
| --- | --- | --- | --- | --- |
| Emacs only | `SPC a ...` | Gptel send/chat/compose/rewrite | No AI bindings | Whole AI group is absent in Neovim |
| Emacs only | `SPC r ...` | Annotation send/view and visual annotate | No review group beyond which-key label | Whole review workflow is absent in Neovim |
| Mismatch | `SPC g d` | Unbound | Gitsigns diff against revision | No collision in Emacs, but mnemonic parity is incomplete |
| Mismatch | `SPC g b` | Unbound | Gitsigns blame current line | Same |
| Mismatch | `SPC q` | Unbound | Delete buffer | Emacs uses Evil `q` for macro recording only without leader |
| Mismatch | `SPC h` | Help prefix | Help prefix | Neither current config binds bare `SPC h` to search highlighting |

## Success criteria for a parity change

A future parity patch would be complete when all of the following hold:

- Emacs completion minibuffers use `C-.` for `embark-act` and `C-q` for
  `embark-export`, while global `C-c .`, Evil normal `C-.`, and global
  quoted-insert remain intact.
- Emacs has a deliberate search-highlight clear/toggle command, assigned to
  the intended key after resolving whether parity targets current `SPC RET`
  or the reported `SPC h`.
- Any chosen parity work explicitly decides whether to align display-line
  motion, Git hunk wrapping, diagnostic detail/list semantics, buffer deletion,
  snippet traversal, and tmux-boundary navigation rather than treating the
  matching leader labels as sufficient.
- Effective bindings are verified in normal, visual, insert, minibuffer,
  tracked-Git, LSP-attached, Markdown, Org, picker, and terminal contexts.

## Functionality present in Neovim but absent from Emacs

This section isolates configured capabilities rather than repeating every
one-sided key from the tables above. `Absent` means the Emacs configuration
has no equivalent facility. `Partial` means Emacs can reach the same broad
goal, but not with the same automation, presentation, or composition.

### Editing environment and visual context

| Coverage | Neovim capability | Emacs state | User-visible impact |
| --- | --- | --- | --- |
| Absent | Firenvim embeds the configured Neovim inside browser text fields and reinstalls its browser host after relevant package changes (`profiles/common/.config/nvim/init.lua:86-110,138-139`) | No browser-editor host or browser-textarea integration is configured in `init.el` | Browser editing can use the full Neovim setup; Emacs remains a separate application |
| Absent | `nvim-treesitter-context` pins up to three enclosing syntax lines above the viewport (`profiles/common/.config/nvim/init.lua:120-121,524-526`) | Emacs shows only the current function name in the mode line via `which-function-mode`; there is no sticky enclosing-code view (`profiles/common/.config/emacs/init.el:1185-1186`) | Deeply nested code retains visible structural context only in Neovim |
| Absent | `cursorline` continuously highlights the cursor's screen line (`profiles/common/.config/nvim/init.lua:25`) | No `hl-line-mode` or equivalent current-line highlight is enabled | Neovim provides a persistent horizontal cursor locator |
| Partial | Tree-sitter queries provide composable function and parameter text objects, including counted selections (`af`, `if`, `aa`, `ia`) (`profiles/common/.config/nvim/init.lua:406-465,476-520`) | Native Tree-sitter drives font locking, folds, and defun motion, but no syntax-aware operator text objects are configured (`profiles/common/.config/emacs/init.el:1172-1247`) | Emacs can navigate syntax structures but cannot directly apply Evil operators to these query-defined units |

### Language tooling and diagnostics

| Coverage | Neovim capability | Emacs state | User-visible impact |
| --- | --- | --- | --- |
| Absent | The declared language servers are enabled automatically, so eligible buffers start clients without an explicit command (`profiles/common/.config/nvim/init.lua:299-328`) | Eglot registers server commands and server definitions, but no `eglot-ensure` hook or global auto-start mode is configured (`profiles/common/.config/emacs/init.el:611-644`) | Neovim language features come online automatically; Emacs requires explicitly starting Eglot |
| Partial | Python directly attaches both `ty` and `ruff` because both server configurations are enabled (`profiles/common/.config/nvim/init.lua:301-310,328`) | The current configuration selects only `ty`, but Eglot 1.20 and newer can expose `ty` and `ruff` through one Rassumfrassum multiplexer connection (`profiles/common/.config/emacs/init.el:621-632`) | Neovim natively manages two clients; Eglot requires the external `rass` multiplexer and a configuration change |
| Partial | Diagnostics render sorted inline virtual text with source labels when multiple producers report issues (`profiles/common/.config/nvim/init.lua:330-335`) | Flymake supplies fringe indicators, navigation, and buffer/project lists, but this configuration adds no line-end diagnostic text presentation (`profiles/common/.config/emacs/init.el:657-661`) | Emacs exposes the diagnostic data, but not Neovim's always-visible inline summary |
| Partial | Native snippets participate in completion: `TAB` and `S-TAB` traverse active placeholders when the popup is closed (`profiles/common/.config/nvim/init.lua:531-548`) | Completion-at-point, file completion, and dabbrev are configured, but there is no snippet engine or placeholder traversal (`profiles/common/.config/emacs/init.el:500-519`) | Emacs completion has broader configured sources, while Neovim alone supports post-completion placeholder navigation |

### Cross-tool workflows and lifecycle

| Coverage | Neovim capability | Emacs state | User-visible impact |
| --- | --- | --- | --- |
| Absent | Quickfix and location lists act as shared result transports for picker exports, diagnostics, compiler output, and list navigation (`profiles/common/.config/nvim/init.lua:758-770`; Neovim 0.12 defaults) | Embark Export chooses type-specific buffers and is semantically richer for individual sources, but there is no single shared quickfix/location-list container across those producers (`profiles/common/.config/emacs/init.el:437-443`) | Neovim can normalize heterogeneous results into one familiar list workflow; Emacs uses several specialized result modes |
| Absent | Normal and terminal `C-h/j/k/l` cross editor-window and tmux-pane boundaries, with `C-\` returning to the previous target (`profiles/common/.config/nvim/init.lua:148-149`; plugin defaults) | Emacs provides editor-window movement and Ghostel/tmux sending, but no automatic boundary-crossing navigator (`profiles/common/.config/emacs/init.el:1824-1838`) | Split navigation remains spatially continuous only in the Neovim/tmux stack |
| Partial | `vim.pack` loads the declared package graph, records reviewed revisions, refreshes Tree-sitter parsers after package changes, and repairs Firenvim installation (`profiles/common/.config/nvim/init.lua:84-155`) | Packages and native grammars are provisioned by separate explicit batch commands; normal startup intentionally performs no installation (`profiles/common/.config/emacs/init.el:10-16,1172-1175`) | Neovim automates more dependency follow-through after an update; Emacs favors an offline, manually staged lifecycle |

The highest-impact parity candidates are automatic Eglot startup, Rass-backed
Python `ty` plus `ruff` support, a sticky syntax-context view, inline diagnostic
text, and browser-hosted editing.
The quickfix model is not a straightforward parity target: the recommended
`embark-export` mapping preserves Emacs's useful type-specific result buffers
instead of replacing them with a lowest-common-denominator list.

## Functionality present in Emacs but absent from Neovim

This section compares configured facilities, not just their entry keys.
`Absent` means `init.lua` configures no equivalent workflow. `Partial` means
Neovim covers the broad goal, but lacks important integration, persistence, or
scope provided by the Emacs configuration.

### Files, recovery, and remote work

| Coverage | Emacs capability | Neovim state | User-visible impact |
| --- | --- | --- | --- |
| Absent | Emacs keeps numbered backup generations, prunes them to a defined retention window, and redirects local and TRAMP backup and auto-save data away from source trees (`profiles/common/.config/emacs/init.el:96-111`) | Neovim names a backup directory and extension but does not enable retained backups or configure versioned generations (`profiles/common/.config/nvim/init.lua:5-13`) | Emacs provides a configured history of recoverable pre-save file versions; Neovim has no equivalent retained-version policy |
| Partial | TRAMP integrates SSH/SSHX file access, SSH-config completion, remote PATH lookup, direct asynchronous processes, SCP copying, compilation, Magit, and asynchronous Org execution (`profiles/common/.config/emacs/init.el:122-169`) | Neovim's configured pickers operate on local paths and its remote-facing workflow only sends text to an existing tmux target (`profiles/common/.config/nvim/init.lua:219-223,574-622`) | Neovim can participate in a remote terminal session, but it does not provide the same editor-wide remote file and tool execution environment |
| Partial | Completion combines flex matching with project, buffer, command, file, Eglot, and dabbrev sources; path-like text gets file completion even inside ordinary or LSP-managed buffers (`profiles/common/.config/emacs/init.el:448-517`) | Insert completion is explicitly LSP-only, followed by snippet placeholder traversal (`profiles/common/.config/nvim/init.lua:226,255-257,528-548`) | Emacs completion remains useful without a language server and completes paths in mixed text or code; Neovim's configured insert completion depends on LSP |

### Development, repositories, and execution

| Coverage | Emacs capability | Neovim state | User-visible impact |
| --- | --- | --- | --- |
| Partial | Magit supplies a full repository workbench, while optional Difftastic bindings add syntax-aware diff and show views inside Magit (`profiles/common/.config/emacs/init.el:570-609`) | Gitsigns exposes buffer hunks, blame, and revision diff, but no repository status/porcelain UI or structural diff integration is configured (`profiles/common/.config/nvim/init.lua:195-216`) | Neovim handles source-buffer changes well; staging, history, branch operations, and structural review require another tool |
| Absent | Dape is constrained to LLDB and supports local or TRAMP launch and attach sessions for C, C++, and Rust (`profiles/common/.config/emacs/init.el:648-658`) | The Neovim package graph and development mappings contain no debugger or DAP client (`profiles/common/.config/nvim/init.lua:115-150,731-776`) | Debugging can remain inside Emacs, while Neovim must hand the workflow to an external debugger or another configuration |
| Absent | Ghostel and term-sessions provide project terminals, named durable sessions, session lists and history, stored Org links, and zmx-backed reopening (`profiles/common/.config/emacs/init.el:1503-1555`) | Vim-slime only targets an already available tmux pane and no terminal/session manager is configured (`profiles/common/.config/nvim/init.lua:219-223,651-655`) | Emacs owns terminal creation, discovery, persistence, and recall; Neovim only transmits text to an external session |
| Absent | A project-local command catalog validates named tasks, guarantees Compile and Test entries, supplies Check and Fix defaults, and runs the selection at the project root in a named compilation terminal (`profiles/common/.config/emacs/init.el:1561-1615`) | No project task catalog or task runner is configured in `init.lua`; the execution surface is limited to REPL sending (`profiles/common/.config/nvim/init.lua:219-223,651-655`) | Repeated project commands have a discoverable, project-owned interface only in Emacs |

### Structured writing, knowledge, and research

| Coverage | Emacs capability | Neovim state | User-visible impact |
| --- | --- | --- | --- |
| Absent | Org implements customized task states and logging, capture templates for meetings, journals, tasks, notes, ideas, and periodic reflections, agenda files, hierarchical refiling, and automatic parent state changes from child tasks or checkbox progress (`profiles/common/.config/emacs/init.el:1314-1426`) | Neovim configures prose display and spelling for text-like buffers but has no Org task, capture, agenda, or state automation (`profiles/common/.config/nvim/init.lua:40-55,115-150`) | Emacs is a task and journaling system, not only an Org text editor; no corresponding workflow exists in Neovim |
| Absent | Org Roam maintains an automatically synchronized note graph, and Org Ref, Org Roam BibTeX, and Google Scholar integration connect notes to citations, PDFs, URLs, and bibliography metadata (`profiles/common/.config/emacs/init.el:1456-1486`) | No linked-note database, citation manager, bibliography workflow, or scholarly lookup package is configured (`profiles/common/.config/nvim/init.lua:115-150`) | Knowledge graph navigation and research-source capture are Emacs-only workflows |
| Absent | Org Fragtog automatically previews LaTeX fragments with a configured `dvisvgm` rendering pipeline and scaled transparent output (`profiles/common/.config/emacs/init.el:1434-1443`) | The Neovim Markdown setup has table and code-block plugins but no live mathematical preview facility (`profiles/common/.config/nvim/init.lua:140-143`) | Mathematical notes render inline during editing only in Emacs |
| Partial | Org Babel executes shell, Python, Emacs Lisp, and C blocks without confirmation and adds asynchronous execution with remote-variable injection (`profiles/common/.config/emacs/init.el:158-165,1382-1391,1489`) | `mdeval.nvim` has built-in runners for Bash/sh, C, C++, Lua, Haskell, JavaScript, OCaml, Python, Ruby, and Rust; it executes the current Markdown fence through a temporary file and inserts the result, but no asynchronous or remote-variable integration is configured (`profiles/common/.config/nvim/init.lua:140-143`) | Both editors provide executable prose, but their execution and result models differ, and only Emacs configures an integrated local and remote literate-programming system |
| Partial | Flyspell checks all text modes, programming-mode prose, and Git commit messages, while excluding source strings from the programming-mode check (`profiles/common/.config/emacs/init.el:1278-1287`) | Spelling is enabled only for Markdown, plain text, and Git commit buffers (`profiles/common/.config/nvim/init.lua:14-15,40-50`) | Emacs also catches misspellings in source comments; Neovim leaves programming buffers unchecked |

### Assisted editing and review

| Coverage | Emacs capability | Neovim state | User-visible impact |
| --- | --- | --- | --- |
| Absent | Gptel configures a streaming Anthropic backend for chats and prompts, sends buffer content, rewrites selections, and can seed a new conversation with source path, line range, mode, and selected text (`profiles/common/.config/emacs/init.el:1621-1648,1802,1866-1874`) | The Neovim package graph and leader groups contain no AI client or prompt workflow (`profiles/common/.config/nvim/init.lua:115-150,181-193`) | Contextual AI chat and selection rewriting are available inside Emacs only |

The strongest Emacs-only systems are the Org task and research environment,
TRAMP's remote integration, durable terminal sessions with project task
execution, and Magit with optional Difftastic integration. File completion,
source-comment spelling, and Markdown code evaluation are partial gaps because
Neovim offers narrower versions of the same broad capabilities.

## Suggested Emacs changes

The recommended Emacs changes fall into two groups:

- Direct parity changes make frequently used keys and navigation behavior match
  Neovim.
- Emacs-native choices preserve stronger Emacs abstractions instead of
  imitating quickfix, popup, or document models literally.

### Priority summary

| Priority | Change | Classification | Expected result |
| --- | --- | --- | --- |
| P0 | Eagerly load Embark, then bind `C-q` to `embark-export` and `C-.` to `embark-act` in completion contexts | Direct parity with an Emacs-native result model | Search and completion candidates can be persisted with the same short chord as Snacks, including from focused `*Completions*`, while retaining type-specific Dired, Ibuffer, Occur, grep, and Xref exports |
| P0 | Bind `SPC RET` to a buffer-local Evil search-highlight toggle | Close, buffer-local parity | The active buffer gains the effective Neovim `hlsearch` behavior without consuming the `SPC h` Help prefix; Neovim's option remains global |
| P0 | Make `[h` and `]h` wrap between the first and last Git hunks | Direct parity | Hunk navigation has the same bidirectional, cyclic behavior as Gitsigns |
| P0 | Run Python through `rass python` | Direct functional parity, different architecture | Python buffers receive both `ty` and Ruff services while Eglot retains one direct server connection |
| P1 | Start Eglot automatically in real programming-file buffers | Direct parity | Supported source files receive LSP features automatically, like `vim.lsp.enable` in Neovim |
| P1 | Add `[D` and `]D` for the first and last diagnostic | Direct parity | The diagnostic bracket family matches Neovim 0.12 more closely |
| P1 | Add source-buffer Git blame and revision-diff bindings | Direct parity through Magit | `SPC g b` and `SPC g d` stop being one-sided Neovim shortcuts |
| P1 | Add `SPC b d`, `SPC b D`, and optionally `SPC q` | Direct parity | Common buffer deletion operations use the same leader vocabulary |
| P2 | Add YASnippet and completion-aware placeholder traversal | Direct functional parity | Eglot snippet completions and `TAB`/`S-TAB` placeholder movement approach the native Neovim completion flow |
| P2 | Expose native source-block editing, but keep embedded-document LSP out of the parity patch | Intentionally Emacs-native | Org and Markdown retain their native code-edit workflows without presenting Rassumfrassum as a block-aware LSP solution |

### Completion actions and persistent results

Add `:demand t` to the existing Embark declaration at
`profiles/common/.config/emacs/init.el:437-439`, then add the short actions next
to the completion navigation configuration at
`profiles/common/.config/emacs/init.el:469-492`:

```elisp
(keymap-set minibuffer-local-completion-map "C-." #'embark-act)
(keymap-set minibuffer-local-filename-completion-map "C-." #'embark-act)
(keymap-set completion-list-mode-map "C-." #'embark-act)

(keymap-set minibuffer-local-completion-map "C-q" #'embark-export)
(keymap-set minibuffer-local-filename-completion-map "C-q" #'embark-export)
(keymap-set completion-list-mode-map "C-q" #'embark-export)
```

Including `completion-list-mode-map` is important because the current setup can
move focus into `*Completions*` through `M-g M-c` at
`profiles/common/.config/emacs/init.el:477-478`. Eager loading is also required:
Embark's completion metadata hook must run when the list is created for a first
export from that list to retain its candidate category and select a type-aware
exporter. Without that metadata, it can recover the candidates but falls back
to generic Collect.

Keep global `C-c .` at `profiles/common/.config/emacs/init.el:437-439`. It
remains useful for acting on non-completion targets. Do not bind `C-q` globally
because that would replace `quoted-insert` in unrelated editing contexts.

Use `embark-export`, not `embark-collect`, as the quickfix counterpart. Export
selects a native result mode based on candidate type and falls back to Collect
when no specialized exporter exists. This preserves an Emacs advantage instead
of reducing every result set to a generic list.

### Search highlighting

Bind the parity command to `SPC RET`, matching the current Neovim binding at
`profiles/common/.config/nvim/init.lua:657-659`. Leave `SPC h` as the Help
prefix established at `profiles/common/.config/emacs/init.el:1726-1727`.

A buffer-local toggle, rather than a one-shot `evil-ex-nohighlight`, should update
`evil-ex-search-highlight-all`, remove existing overlays when disabled, and
restore the current search pattern when enabled:

```elisp
(defun my/toggle-evil-search-highlight ()
  "Toggle persistent Evil search-result highlighting in this buffer."
  (interactive)
  (setq-local evil-ex-search-highlight-all
              (not evil-ex-search-highlight-all))
  (if evil-ex-search-highlight-all
      (evil-ex-search-activate-highlight evil-ex-search-pattern)
    (evil-ex-nohighlight))
  (message "Search highlighting %s"
           (if evil-ex-search-highlight-all "enabled" "disabled")))
```

Add `("" . my/toggle-evil-search-highlight)` only if the leader construction
accepts an empty suffix reliably. Otherwise bind `(kbd "RET")` directly on
`my/leader-map` after its prefixes and ordinary bindings have been installed.
This deliberately scopes the setting to the active Emacs buffer; Neovim's
`hlsearch` option is global.

### Git hunk navigation

Both directions already exist at `profiles/common/.config/emacs/init.el:573-591`:

- `[h` calls `diff-hl-previous-hunk`.
- `]h` calls `diff-hl-next-hunk`.

The missing behavior is wrapping, not backward navigation. Add two small
commands that call the native diff-hl operation first and, only on its "No
further hunks found" boundary, search from `point-max` or `point-min`. They
should still report "No hunks found" when the buffer has no hunk at all. Bind
those wrappers to `[h` and `]h` in `diff-hl-mode-map`.

Do not replace diff-hl itself. Its preview, confirmation before reset, Magit
refresh integration, and annotation workflow at
`profiles/common/.config/emacs/init.el:563-609` are useful Emacs-native behavior.

### Diagnostics

Flymake already wraps `[d` and `]d` because `flymake-wrap-around` defaults to
non-nil. Set it explicitly near `profiles/common/.config/emacs/init.el:657-661`
so the intended parity is documented and stable:

```elisp
(setopt flymake-wrap-around t)
```

Add `[D` and `]D` commands that move to the first and last diagnostic in the
current buffer. Keep the existing `SPC d f` buffer list and `SPC d l` project
list at `profiles/common/.config/emacs/init.el:1792-1795`; those persistent
Flymake views are more useful than replacing them with Neovim's floating-at-point
and location-list semantics.

If a short quickfix-like diagnostic entry is desired, bind `SPC d q` to
`flymake-show-project-diagnostics`. Treat it as an alias, not as a replacement
for `SPC d l`.

### Python LSP with `ty` and Ruff

Replace the `ty`-only server entry at
`profiles/common/.config/emacs/init.el:621-632` with:

```elisp
(setf (alist-get '(python-mode python-ts-mode)
                 eglot-server-programs nil nil #'equal)
      '("rass" "python"))
```

Provision `rassumfrassum`, `ty`, and `ruff` together and document the dependency
beside the existing external-server list. For TRAMP projects, all three
executables must be available on the remote host, consistent with the existing
remote-server rule at `profiles/common/.config/emacs/init.el:617-619`.

This closes the practical Python feature gap while leaving architectural
parity `Partial`: Neovim directly attaches two clients, while Eglot talks to
one `rass` process that multiplexes the two underlying servers. The official
Eglot documentation explicitly recommends `rass python` for this combination:
https://elpa.gnu.org/devel/doc/eglot.html.

### Automatic Eglot startup

Neovim enables all declared servers automatically at
`profiles/common/.config/nvim/init.lua:299-328`, while Emacs currently requires
`M-x eglot`.

Add `eglot-ensure` to the supported programming-mode hooks, but limit automatic
startup to real file-visiting buffers. This avoids accidentally starting
language servers in temporary Org source-edit or Markdown indirect buffers:

```elisp
(defun my/eglot-ensure-file-buffer ()
  "Start Eglot automatically for a real source file."
  (when buffer-file-name
    (eglot-ensure)))
```

Use it for the C, C++, Rust, Lua, Python, JavaScript, TypeScript, TSX, Zig, Nim,
and Odin modes already enumerated at
`profiles/common/.config/emacs/init.el:1173-1208`. Do not add `org-mode`,
`markdown-mode`, or `markdown-ts-mode` to these hooks.

Preserve `consult-imenu` and `xref-find-apropos` at
`profiles/common/.config/emacs/init.el:1771-1773`. In an Eglot-managed buffer,
Eglot supplies LSP-backed Imenu and Xref data; without Eglot, the same commands
retain useful mode-native fallbacks. This is preferable to making the leader
keys fail whenever no server is active.

### Org and Markdown code blocks

Rassumfrassum should not be presented as a live embedded-code solution for
arbitrary Org or Markdown documents.

Generic `rass` multiplexing forwards one LSP document to several servers. It
does not parse Org source blocks or Markdown fences into separate virtual
documents. Its multi-language Vue support relies on specialized protocol hooks,
not generic fan-out. There is currently no corresponding built-in Org or
Markdown block-routing preset. See the Rassumfrassum documentation:
https://github.com/joaotavora/rassumfrassum.

A correct embedded-code adapter would need to:

- Extract one virtual document per language or block.
- Assign stable synthetic or real URIs.
- Translate cursor positions and ranges in both directions.
- Map diagnostics, edits, completion replacements, definitions, and workspace
  edits back into the host document.
- Handle block insertion, deletion, indentation, and multiple blocks of the
  same language.
- Coordinate project roots and file-backed imports.

That is new custom software, not an Eglot configuration change. Keep it outside
the keybinding-alignment patch.

For Org, expose the native `org-edit-special` workflow with a discoverable
`SPC o e` alias while preserving `SPC o RET` for Babel execution at
`profiles/common/.config/emacs/init.el:1818-1825`. `C-c '` opens the block body
in its language's major mode, and Org writes the result back when the edit
buffer exits. See https://orgmode.org/manual/Editing-Source-Code.html.

For Markdown, `markdown-edit-code-block` provides a similar `C-c '`
indirect-buffer workflow when `edit-indirect` is installed, but the default
`.md` path prefers `markdown-ts-mode` at
`profiles/common/.config/emacs/init.el:1264-1275`. Do not silently force classic
`markdown-mode` merely to acquire that command. Either add an explicit
Tree-sitter-aware indirect editing feature as a separate task or keep the
current fenced-code send commands at
`profiles/common/.config/emacs/init.el:1161-1167`.

Native block-edit buffers can provide syntax-aware editing and completion, but
should not be advertised as full project-aware LSP documents. For code that
needs reliable definitions, diagnostics, imports, and workspace edits, use real
source files. Org's native tangling workflow is the appropriate
literate-programming path, with `:tangle` and optionally `:comments link` when
navigation back to the Org source matters. See
https://orgmode.org/manual/Extracting-Source-Code.html.

### Additional low-risk parity bindings

Add these only after the P0 navigation and completion changes:

| Key | Suggested Emacs command | Reason |
| --- | --- | --- |
| `SPC g b` | `magit-blame-addition` | Matches the Gitsigns current-line blame mnemonic while using Magit's richer blame mode |
| `SPC g d` | `magit-diff-buffer-file` or a small revision-prompting Magit command | Fills the existing revision-diff gap |
| `SPC b d` | `kill-current-buffer` | Matches the common Neovim buffer-delete path |
| `SPC b D` | A confirmation-based command over ordinary file buffers | Provides bulk deletion without indiscriminately killing process, terminal, or internal buffers |
| `SPC q` | `kill-current-buffer`, if the shorter alias is wanted | Exact Neovim parity, but redundant with `SPC b d` |
| `SPC c s` | `eldoc-print-current-symbol-info` | Adds an explicit signature/documentation request without replacing persistent `K` documentation |

Do not mirror all Neovim 0.12 `gr...` defaults automatically. The existing
`gd`, `gD`, `gi`, `K`, and leader hierarchy already form a coherent Evil
vocabulary at `profiles/common/.config/emacs/init.el:367-381,1764-1791`. Add
only commands that address a demonstrated workflow gap.

### Suggested implementation order

1. Eagerly load Embark, then add completion-context `C-.` and `C-q`.
2. Add `SPC RET` search highlighting.
3. Add cyclic diff-hl wrappers and diagnostic endpoints.
4. Install and configure `rass python`, then verify both `ty` and Ruff
   capabilities.
5. Add file-only automatic Eglot startup.
6. Add the low-risk buffer and Magit aliases.
7. Evaluate snippets and Tree-sitter-aware Markdown block editing as separate
   changes.

### Success criteria

- `C-q` exports candidates from an active minibuffer and from a focused
  `*Completions*` buffer.
- `C-.` opens Embark actions in those same contexts, while global `C-c .`,
  global `C-q`, and Evil normal-state `C-.` remain unchanged.
- `SPC RET` disables visible search matches and restores the current search
  pattern when toggled back on.
- `[h` and `]h` wrap in tracked files, and both report a clear error when no
  hunks exist.
- `[d` and `]d` wrap, while `[D` and `]D` reach the first and last
  current-buffer diagnostic.
- A normal Python file is managed by Eglot through `rass`, with both `ty` and
  Ruff features observable.
- Real supported source files start Eglot automatically; Org, Markdown, and
  temporary block-edit buffers do not.
- `SPC o e` opens an Org block in its native major mode, while `SPC o RET`
  continues to execute the block.
- The report clearly states that generic Rassumfrassum multiplexing is not an
  Org or Markdown code-block extraction layer.

## Suggested Neovim changes

The recommended Neovim changes should align shared workflows without replacing
Neovim-native strengths such as direct multi-client LSP, quickfix, location
lists, picker actions, native modal editing, and tmux navigation.

### Priority 1: direct parity and correctness

| Change | Recommended implementation | Why |
| --- | --- | --- |
| Make hunk navigation policy explicit and add endpoints | Pass `{ wrap = true }` to both Gitsigns `nav_hunk` calls and add `[H`/`]H` for `first`/`last` (`profiles/common/.config/nvim/init.lua:195-203`) | `[h` and `]h` currently wrap only because global `wrapscan` happens to be enabled. An explicit option preserves the intended cycling behavior. Endpoints complete the same uppercase bracket vocabulary already supplied for diagnostics, quickfix, and location lists. |
| Preserve exact visual searches, including multiline selections | Keep `Snacks.picker.grep_word` for normal-mode words. For a single-line visual selection, use a wrapper that passes the text literally without `--word-regexp`. True multiline parity requires a custom finder/parser that consumes `rg --json`, aggregates each match, and creates one correctly positioned picker item (`profiles/common/.config/nvim/init.lua:706-708`) | Adding ripgrep multiline flags to the stock Snacks grep finder is insufficient because its line-oriented parser turns one multiline match into malformed or partial items. The custom parser is required to match the Emacs region-aware search at `profiles/common/.config/emacs/init.el:531-553`. |
| Make buffer symbols work without LSP | Have `SPC s s` use LSP document symbols when a supporting client is attached and fall back to `Snacks.picker.treesitter()` otherwise (`profiles/common/.config/nvim/init.lua:688-690`) | This matches the availability of Emacs `consult-imenu` while preserving richer LSP symbols when available. Keep `SPC s S` LSP-only because there is no honest parser-only equivalent to workspace symbols. |
| Align Markdown table and current-block commands | Add Markdown-local `SPC o m` for `:Tabularize /|`. For exact `SPC t b` parity, extract the current fenced body and pass it to vim-slime's `slime#send(text)` API. Expose `:MdEval` on a separate key only if execute-and-insert-results is wanted (`profiles/common/.config/nvim/init.lua:140-143`) | Tabular and `mdeval.nvim` are already loaded, but `MdEval` is not equivalent to the Emacs terminal-send command: it runs a language-specific command through a temporary file, confirms by default, and inserts the output into the document. It handles only the current block. |
| Add direct REPL target selection | Map `SPC t R` to `<Plug>SlimeConfig` while retaining `C-c v` and the existing send bindings (`profiles/common/.config/nvim/init.lua:219-223,651-655`) | This aligns the visible target-selection workflow with Emacs and exposes functionality vim-slime already provides. |
| Use the existing layout-safe buffer deletion API | Replace `:bd` and `:%bd` with `Snacks.bufdelete()` and `Snacks.bufdelete.all()` for `SPC b d`, `SPC b D`, and `SPC q` (`profiles/common/.config/nvim/init.lua:624-632`) | Snacks is already loaded and its deletion API preserves window layout and prompts for modified buffers. This is safer and closer to Emacs buffer killing than raw `:bd`. |

### Priority 2: improve shared development workflows

| Change | Recommended implementation | Why |
| --- | --- | --- |
| Assign explicit Python LSP responsibilities | Continue attaching both `ty` and `ruff`, but make Python formatting select Ruff explicitly and document which client owns formatting, lint fixes, and type analysis (`profiles/common/.config/nvim/init.lua:299-328,731-736`) | Native concurrent clients are a Neovim strength. Explicit ownership prevents ambiguous formatting or duplicate capabilities while retaining the combined service that Emacs needs an LSP multiplexer to obtain. |
| Add repository status without another plugin | Map `SPC g g` to `Snacks.picker.git_status()` (`profiles/common/.config/nvim/init.lua:158-175,195-216`) | This fills the largest source-navigation gap using an installed dependency and complements Gitsigns. It is not full Magit parity. Add `Snacks.lazygit()` only if a full interactive repository workbench is wanted and `lazygit` is accepted as an external dependency. |
| Add a project terminal entry point | Map `SPC t p` to a project-root `Snacks.terminal()` toggle while keeping vim-slime targeted at tmux (`profiles/common/.config/nvim/init.lua:158-175,219-223`) | This gives Neovim a direct terminal creation path without weakening its tmux-based REPL workflow or adding a terminal plugin. Durable named sessions and history should remain an Emacs-specific facility unless there is a concrete Neovim use case. |
| Make diagnostic scopes explicit instead of forcing identical keys | Keep `SPC d f` as the at-point float, `SPC d l` as the location list, and `SPC d q` as quickfix; improve their descriptions to say `at point`, `window`, and `global` (`profiles/common/.config/nvim/init.lua:762-776`) | These three scopes are useful Neovim-native distinctions. Alignment should happen by adding matching capabilities or aliases in Emacs, not by collapsing Neovim's diagnostic workflow into the Emacs buffer/project split. |
| Add reversible window layout history only if it is used regularly | If winner-style recovery is valuable, add one focused layout-history dependency and map `SPC w u`/`SPC w r` (`profiles/common/.config/nvim/init.lua:634-649`; Emacs reference `profiles/common/.config/emacs/init.el:302`) | Neovim has no built-in equivalent to Winner history. This does not justify a new dependency unless layout undo is a recurring need, so it should follow the dependency-free changes above. |

### Intentionally retain Neovim-native behavior

| Area | Recommendation | Rationale |
| --- | --- | --- |
| Picker result persistence | Keep picker `C-q` exporting to quickfix, along with `TAB`, `S-TAB`, `C-a`, split, tab, preview, and option-toggle actions | This is faster than reproducing Embark's action-map model. Emacs should adopt a scoped `C-q` export binding instead. |
| List navigation | Keep native `[q`/`]q`, `[l`/`]l`, `[b`/`]b`, `[d`/`]d`, and their uppercase endpoint variants | This is a coherent Neovim-wide bracket vocabulary. Emacs can add compatible aliases where its result modes support them. |
| Core cursor motion | Keep file-line `j/k`, cross-line `h/l`, and tmux-aware `C-h/j/k/l` (`profiles/common/.config/nvim/init.lua:11,23,148-149`) | Remapping these to reproduce global Emacs visual-line behavior would alter fundamental Vim semantics. Use `gj/gk` explicitly in wrapped prose. |
| Search highlighting | Keep `SPC RET` as the search-highlight toggle (`profiles/common/.config/nvim/init.lua:657-659`) | `SPC h` is already a Help prefix. Emacs should add `SPC RET` for parity instead of creating a Neovim prefix collision. |
| Help discovery | Keep `SPC h h` as searchable help tags and `SPC h k` as the effective-keymap picker (`profiles/common/.config/nvim/init.lua:778-791`) | Neovim help tags already cover commands, options, functions, and variables. Copying Emacs's separate describe keys would add aliases without adding capability. |
| Working directory | Keep the explicitly documented global cwd model for project pickers (`profiles/common/.config/nvim/init.lua:156,574-622`) | Neovim's picker and terminal ecosystem commonly shares a process-wide project root. Emacs buffer-local `default-directory` is useful but should not be imitated unless simultaneous per-buffer projects are a demonstrated requirement. |
| Org, TRAMP, durable sessions, AI, and review | Leave these editor-specific by default | Reproducing the Emacs systems would add several large subsystems and still provide weaker integration. Use Emacs for these workflows, or add a Neovim equivalent only when Neovim must become the primary host for that specific workflow. |
| Markdown structural editing | Do not port the large custom Emacs heading, list, paragraph, and table motion implementation directly | Keep `no_markdown_maps` until a maintained structural-editing package with acceptable mappings is deliberately selected (`profiles/common/.config/nvim/init.lua:3`; Emacs implementation `profiles/common/.config/emacs/init.el:677-1167`). Binding the already-installed table and code-block commands is worthwhile; cloning hundreds of lines of editor-specific structure logic is not. |
