# Emacs Zenbones light theme implementation plan

## Reasoning

The Neovim configuration selects the default light variant of Zenbones by
setting `termguicolors`, setting `background` to `light`, and loading
`zenbones` at `profiles/common/.config/nvim/init.lua:18-22` and
`profiles/common/.config/nvim/init.lua:224`. It does not set a Zenbones
lightness override, transparent background, solid border, solid line-number,
non-current-window, italic, or diagnostic-text option. The Emacs port must
therefore reproduce the opaque default Zenbones light scheme, including its
default italic comments and strings, rather than one of the `bright`, `dim`, or
transparent variants. The relevant defaults are documented at
`refs/zenbones.nvim/doc/zenbones.md:67-87`. The reviewed source revisions are
Zenbones `8304d8df9b823ff11e103afa62f38c39f534abe6` and Lush
`9c60ec2279d62487d942ce095e49006af28eed6e`, pinned at
`profiles/common/.config/nvim/nvim-pack-lock.json:15-17` and
`profiles/common/.config/nvim/nvim-pack-lock.json:69-71`.

The existing Emacs theme is a repository-owned, standalone subset of Doom One
Light at `profiles/common/.config/emacs/themes/mig-one-light-theme.el`. It
already covers core UI, syntax, completion, ANSI colors, Markdown, Org, Magit,
Which Key, Evil, and Gptel. Replacing that file with another focused local
theme is simpler and more complete than adding an Emacs theme package and then
layering a second override theme over it. The replacement must retain the
current package coverage, add the configured but currently uncovered modes,
and use inheritance where an upstream package already exposes stable semantic
faces.

The configuration's terminal buffers are Ghostel buffers, not buffers owned by
the standalone Ghostty application. The UI labels a target as `ghostty` but
requires `ghostel`, lists `ghostel-buffer-list`, and creates the target with
`ghostel-create` at `profiles/common/.config/emacs/my-send-text.el:187-212`.
Ghostel is the preferred term-sessions frontend at
`profiles/common/.config/emacs/init.el:1116-1170`. Ghostel remaps buffer
`default` through `ghostel-default` at
`refs/ghostel/lisp/ghostel.el:4851-4865`, derives its 16-color palette from
`ghostel-color-*` face foregrounds at
`refs/ghostel/lisp/ghostel.el:3648-3664`, and refreshes live terminals after a
theme change at `refs/ghostel/lisp/ghostel.el:3676-3700`. The Emacs theme can
therefore style Ghostel exactly without adding a standalone Ghostty config.

This plan is independently executable. It changes appearance only. It does not
change keybindings, layout, completion behavior, language-server behavior,
terminal input behavior, Org workflow semantics, package installation, or the
Neovim configuration.

## Goals

- Replace the local One Light theme with a standalone Emacs theme named
  `mig-zenbones-light`.
- Match the pinned default Zenbones light palette and highlight semantics used
  by Neovim.
- Make native Tree-sitter fontification the authoritative programming-language
  color path for every configured `*-ts-mode`, at maximum font-lock detail.
- Cover every major mode, minor-mode UI, and package surface configured by the
  Emacs setup.
- Apply the same background, foreground, cursor, selection, and ANSI palette to
  embedded Ghostel terminal buffers.
- Preserve JetBrains Mono, inline-code metrics, Eglot hint height, completion
  window sizing, and all non-appearance behavior.
- Add behavior-focused validation for palette values, face inheritance, major
  mode coverage, and Ghostel palette extraction.

## Non-goals

- Do not modify `profiles/common/.config/nvim/init.lua` or the pinned Neovim
  packages.
- Do not add an external Emacs theme package or a runtime dependency on Lush,
  Lua, or Neovim.
- Do not add `profiles/common/.config/ghostty/config`. Standalone Ghostty
  application windows are outside this plan.
- Do not add vterm, built-in `term`, `ansi-term`, Eshell, or Comint as terminal
  frontends. Their existing ANSI rendering may inherit the global ANSI faces,
  but no new terminal frontend is introduced.
- Do not add per-buffer theme hooks, advice, overlays, or mode-specific theme
  toggling.
- Do not retain `mig-one-light` as an alias or compatibility shim.
- Do not change font family, font size, text scaling, frame transparency,
  window layout, or package behavior.

## Status

- Plan: complete
- Implementation: in progress
- Current phase: Phase 3
- Target: Emacs 31.1+
- Primary configuration: `profiles/common/.config/emacs/init.el`
- Current theme: `profiles/common/.config/emacs/themes/mig-one-light-theme.el`
- Target theme: `profiles/common/.config/emacs/themes/mig-zenbones-light-theme.el`
- Tests: `profiles/common/.config/emacs/appearance-test.el`
- Read-only color reference: `refs/zenbones.nvim`
- Read-only terminal reference: `refs/ghostel`

During execution, update this section and each Phase status only after that
phase's validation passes.

## Source-of-truth hierarchy

When sources appear to disagree, use this order:

1. The active Neovim options in `profiles/common/.config/nvim/init.lua` decide
   which Zenbones variant and options are in scope.
2. The HSLuv palette and semantic highlight formulas in
   `refs/zenbones.nvim/lua/zenbones/util.lua:50-79` and
   `refs/zenbones.nvim/lua/zenbones/specs/light.lua:3-588` define intent.
3. The checked-in generated RGB values in
   `refs/zenbones.nvim/colors/zenbones.vim:249-464` define the exact pinned RGB
   output.
4. The generated Ghostty scheme at
   `refs/zenbones.nvim/extras/ghostty/zenbones_light:1-37` defines terminal
   foreground, background, selection, cursor, and ANSI values.
5. Emacs and package upstream face inheritance decide which Emacs face names
   consume each semantic role.

Do not sample colors from screenshots or substitute named terminal colors.
Use the literal RGB values in this plan.

The generated Vim groups, derived RGB values, ANSI slots, terminal defaults,
selection background, and cursor colors are exact ports. Emacs-only surfaces
such as the minibuffer, secondary selection, Org workflow states, Magit
branches, Dape, Consult, Embark, and Dired have no Zenbones upstream mapping.
Their mappings below are deliberate repository-owned translations. These
translations are normative for implementation and must not be reinterpreted
during execution.

The installed Ghostel and evil-ghostel packages are pinned to
`94eace59046c275d6c8f3c065489f6bbdb4f037b` at
`profiles/common/.config/emacs/install-packages.el:10-19`. The read-only
`refs/ghostel` checkout is revision
`53c73e9b78a21b0a9d7b66e4db38e80ef1fc93e3`. The face remap, ANSI inheritance,
palette extraction, and theme synchronization contracts used by this plan are
present in both revisions. The installed pin is authoritative for runtime
verification; the read-only checkout supplies codepointers.

## Exact palette contract

Define named palette bindings in the theme implementation so the repeated
colors are written once and face declarations consume semantic names. Do not
repeat raw hex literals across dozens of face specifications.

### Base and semantic colors

| Theme binding | Zenbones role | Hex | Required use |
| --- | --- | --- | --- |
| `bg` | `bg` | `#F0EDEC` | Default background and ANSI black |
| `fg` | `fg` | `#2C363C` | Default foreground and ANSI white |
| `fg-match` | `p1.fg1` | `#3E4B53` | Fuzzy secondary match |
| `fg-identifier` | `p1.fg2` | `#44525B` | Variables, properties, link labels |
| `fg-special` | `p1.fg3` and `fg1` | `#4F5E68` | Builtins, special constructs, bright white |
| `fg-constant` | `p1.fg4` | `#556570` | Constants, strings, numbers, quotes |
| `fg-secondary` | `p1.fg5` | `#5E6F7B` | Conceal and completion metadata |
| `rose` | `rose` | `#A8334C` | Error, deletion, failure |
| `leaf` | `leaf` | `#4F6C31` | Success, addition, completion |
| `wood` | `wood` | `#944927` | Warning and caution |
| `water` | `water` | `#286486` | Information and changed state |
| `blossom` | `blossom` | `#88507D` | Hint, match, secondary accent |
| `sky` | `sky` | `#3B8992` | Link and cyan accent |
| `bg1` | `bg1` | `#CFC1BA` | Bright black and strong neutral divider |
| `rose1` | `rose1` | `#94253E` | Bright red ANSI slot |
| `leaf1` | `leaf1` | `#3F5A22` | Bright green ANSI slot |
| `wood1` | `wood1` | `#803D1C` | Bright yellow ANSI slot |
| `water1` | `water1` | `#1D5573` | Bright blue ANSI slot |
| `blossom1` | `blossom1` | `#7B3B70` | Bright magenta ANSI slot |
| `sky1` | `sky1` | `#2B747C` | Bright cyan ANSI slot |

`bg_bright` (`#F8F6F5`) and `bg_dim` (`#E8E4E3`) are reference values only.
Do not use either because the active Neovim setup uses default lightness.

### Derived UI colors

| Theme binding | Hex | Exact semantic target |
| --- | --- | --- |
| `comment` | `#948985` | Italic comments and subdued prose metadata |
| `line-number` | `#A4968F` | Line numbers, sign column, separators |
| `non-text` | `#BBABA3` | Whitespace and non-text glyphs |
| `delimiter` | `#8E817B` | Punctuation, brackets, markup delimiters |
| `type` | `#6A5549` | Types, classes, raw code |
| `cursor-line` | `#E9E4E2` | Current line and generic passive highlight |
| `color-column` | `#E6C5BD` | Fill column and source reference highlight |
| `float-bg` | `#DDD6D3` | Tooltip and floating surface |
| `float-border` | `#786D68` | Floating border |
| `popup-bg` | `#DAD3CF` | Completion popup |
| `popup-selection` | `#C4B6AF` | Selected completion |
| `popup-scrollbar` | `#B2A39B` | Popup scrollbar |
| `popup-thumb` | `#F7F6F5` | Popup scrollbar thumb |
| `selection` | `#CBD9E3` | Active region and Ghostty selection |
| `search` | `#DEB9D6` | Search and matching pair |
| `active-search` | `#C074B2` | Current incremental search result |
| `mode-line` | `#D6CDC9` | Active mode line |
| `mode-line-inactive-bg` | `#E1DCD9` | Inactive mode line and tab fill |
| `mode-line-inactive-fg` | `#596A76` | Inactive mode line text |
| `inlay-fg` | `#A38C80` | Eglot and Dape inlay hints |
| `inlay-bg` | `#EBE7E6` | Inlay hints and rendered code blocks |
| `spell-fg` | `#974352` | Misspelled and duplicate word foreground |
| `diff-add-bg` | `#CBE5B8` | Added line highlight |
| `diff-change-bg` | `#D4DEE7` | Changed line highlight |
| `diff-delete-bg` | `#EBD8DA` | Deleted line highlight |
| `diff-text-bg` | `#A9BED1` | Changed text within a changed line |

## Global implementation decisions

1. Remove `profiles/common/.config/emacs/themes/mig-one-light-theme.el` and add
   `profiles/common/.config/emacs/themes/mig-zenbones-light-theme.el` in the
   same change. Do not keep duplicate theme files.
2. Define and provide only `mig-zenbones-light`. Update the load call at
   `profiles/common/.config/emacs/init.el:260-263` and all tests that name
   `mig-one-light`.
3. Keep `custom-theme-load-path` unchanged. Keep the `t` no-confirm argument to
   `load-theme`; no new `custom-safe-themes` hash is required.
4. Set the theme variable `frame-background-mode` to `light`.
5. Keep direct RGB face specs for graphical and true-color terminal frames.
   Do not add separate 256-color or 16-color branches.
6. Keep `fixed-pitch` inheriting `default`. Do not change the font assignment
   at `profiles/common/.config/emacs/init.el:280-294`.
7. Put colors in the theme. The only non-face appearance changes are the
   explicit Org TODO keyword mapping described below, because Org selects
   per-keyword faces through a variable, and `treesit-font-lock-level` set to
   `4`, because Emacs otherwise omits detailed Tree-sitter capture groups.
8. Prefer package face inheritance over duplicating properties. Add direct
   properties where inheritance would otherwise expose raw named colors,
   lose Zenbones backgrounds, or fail to give Ghostel an exact palette.
9. Theme faces may be declared before their package is loaded. Do not add
   `with-eval-after-load` blocks solely to set faces.
10. Preserve current face metric contracts, including relative height `1.0`
    for Eglot hints and Markdown inline code.
11. Set `treesit-font-lock-level` to `4` beside `treesit-enabled-modes` at
    `profiles/common/.config/emacs/init.el:808-818`. Emacs 31 defaults this
    variable to level 3, which omits part of the function, operator, bracket,
    delimiter, property, and other detailed capture vocabulary. Level 4 is
    required for the complete Zenbones syntax contract in this plan.
12. Do not add or replace Tree-sitter font-lock rules, query captures, feature
    lists, or per-language hooks. Built-in `*-ts-mode` rules decide which
    standard face represents a syntax node; the theme decides how that face
    looks.

## Programming highlighting priority and fallback boundary

Apply programming-language highlighting in this strict order:

1. Native Tree-sitter fontification is authoritative for `c-ts-mode`,
   `c++-ts-mode`, `rust-ts-mode`, `lua-ts-mode`, `python-ts-mode`, `js-ts-mode`,
   `typescript-ts-mode`, and `tsx-ts-mode`, which are enabled at
   `profiles/common/.config/emacs/init.el:808-818`.
2. Native `markdown-ts-mode` fontification is authoritative for Markdown when
   both pinned Markdown grammars are available. The dispatch is at
   `profiles/common/.config/emacs/init.el:898-909`.
3. The standard Emacs 31 `font-lock-*` faces are the shared semantic API for
   programming `*-ts-mode` colors. Theme all of them. Do not create separate
   color tables for C, C++, Rust, Lua, Python, JavaScript, TypeScript, or TSX.
   Classic C, C++, Rust, Lua, Python, JavaScript, and TypeScript counterparts
   use the same generic faces only when their configured grammar is unavailable.
4. Mode-specific faces are permitted only when a configured mode emits a face
   that cannot be represented by the shared font-lock contract. The TSX JSX
   faces and Markdown Tree-sitter faces listed below are required examples.
5. Language-specific mode faces are fallback color vocabulary. In the current
   configuration, Nim, Odin, and Zig parsers are created only for structural
   navigation and folding at `profiles/common/.config/emacs/init.el:822-895`;
   their package major modes still own fontification. PHP has no pinned
   Tree-sitter grammar, so `php-mode` is necessarily the active PHP highlighter.
   Encode all of these mode faces, but make them inherit the shared semantic
   palette and never let them define the Tree-sitter color contract.

The pinned grammar inventory is at
`profiles/common/.config/emacs/install-tree-sitter-grammars.el:4-36`. Keep its
revisions and installation policy unchanged. This plan changes how captures
are displayed, not which parsers are installed.

## Complete face contract

The following mappings are required. A face listed in an inheritance group
must inherit the named parent without adding another foreground or background.

### Core frame, editing, and search faces

| Faces | Required attributes |
| --- | --- |
| `default` | fg `fg`, bg `bg` |
| `fixed-pitch` | inherit `default` |
| `variable-pitch` | preserve upstream family behavior; do not set a color |
| `bold`, `italic`, `bold-italic` | weight/slant only |
| `cursor` | fg `bg`, bg `fg` |
| `fringe` | inherit `default`, fg `line-number` |
| `region` | fg `fg`, bg `selection`, extend |
| `secondary-selection` | bg `diff-change-bg`, extend |
| `highlight`, `hl-line` | bg `cursor-line`, extend |
| `shadow` | fg `comment` |
| `tooltip` | fg `fg`, bg `float-bg` |
| `child-frame-border` | bg `float-border` |
| `scroll-bar` | fg `popup-thumb`, bg `popup-scrollbar` |
| `vertical-border`, `window-divider`, `window-divider-first-pixel`, `window-divider-last-pixel` | fg `line-number` |
| `line-number` | fg `line-number`, normal weight, no inherited underline or strike-through |
| `line-number-current-line` | fg `fg`, bold, no inherited underline or strike-through |
| `escape-glyph`, `homoglyph`, `nobreak-space` | fg `fg-special`, bold |
| `trailing-whitespace` | bg `rose` |
| `link` | fg `sky`, underline |
| `link-visited` | fg `blossom1`, underline |
| `error` | fg `rose` |
| `warning` | fg `wood` |
| `success` | fg `leaf` |
| `match`, `lazy-highlight`, `show-paren-match` | fg `fg`, bg `search` |
| `isearch` | fg `bg`, bg `active-search`, bold |
| `isearch-fail`, `show-paren-mismatch` | fg `bg`, bg `rose`, bold |

When `whitespace-mode` is enabled manually, map
`whitespace-big-indent`, `whitespace-hspace`, `whitespace-indentation`,
`whitespace-newline`, `whitespace-page-delimiter`, `whitespace-space`,
`whitespace-space-after-tab`, `whitespace-space-before-tab`, and
`whitespace-tab` to fg `non-text`. Map `whitespace-empty`,
`whitespace-missing-newline-at-eof`, and `whitespace-trailing` to fg `rose` and
bg `diff-delete-bg`. This is support coverage only; do not enable
`whitespace-mode`.

### Emacs 31 font-lock faces

| Faces | Required attributes |
| --- | --- |
| `font-lock-comment-face`, `font-lock-comment-delimiter-face`, `font-lock-doc-face` | fg `comment`, italic |
| `font-lock-string-face`, `font-lock-regexp-face`, `font-lock-constant-face` | fg `fg-constant`, italic |
| `font-lock-number-face` | fg `fg-constant`, normal slant |
| `font-lock-variable-name-face`, `font-lock-variable-use-face`, `font-lock-property-name-face`, `font-lock-property-use-face` | fg `fg-identifier` |
| `font-lock-function-name-face`, `font-lock-function-call-face` | fg `fg` |
| `font-lock-keyword-face`, `font-lock-operator-face`, `font-lock-preprocessor-face`, `font-lock-negation-char-face` | fg `fg`, bold |
| `font-lock-type-face` | fg `type` |
| `font-lock-builtin-face`, `font-lock-escape-face`, `font-lock-doc-markup-face` | fg `fg-special`, bold |
| `font-lock-bracket-face`, `font-lock-delimiter-face`, `font-lock-misc-punctuation-face`, `font-lock-punctuation-face` | fg `delimiter` |
| `font-lock-regexp-grouping-backslash`, `font-lock-regexp-grouping-construct` | fg `fg-special`, bold |
| `font-lock-warning-face` | inherit `warning` |

This deliberately removes One Light's chromatic keyword/function/string
separation. Zenbones uses weight and slant for most syntax differentiation at
`refs/zenbones.nvim/lua/zenbones/specs/light.lua:126-165`.

`font-lock-regexp-grouping-backslash` and
`font-lock-regexp-grouping-construct` are generic and classic-mode support
faces. None of the eight configured native programming Tree-sitter modes emits
them directly. Keep them themed for fallback completeness, but do not use them
as Tree-sitter verification targets.

### Frame chrome, minibuffer, completion, and navigation

| Faces | Required attributes |
| --- | --- |
| `minibuffer-prompt` | fg `fg`, bold |
| `mode-line`, `mode-line-active` | fg `fg`, bg `mode-line` |
| `mode-line-inactive` | fg `mode-line-inactive-fg`, bg `mode-line-inactive-bg` |
| `mode-line-emphasis`, `mode-line-buffer-id` | fg `fg`, bold |
| `mode-line-highlight` | inherit `highlight` |
| `header-line` | inherit `mode-line` |
| `tab-bar` | fg `mode-line-inactive-fg`, bg `mode-line-inactive-bg` |
| `tab-bar-tab` | fg `fg`, bg `mode-line`, bold |
| `tab-bar-tab-inactive` | fg `mode-line-inactive-fg`, bg `mode-line-inactive-bg` |
| `tab-bar-tab-group-current` | inherit `tab-bar-tab` |
| `tab-bar-tab-group-inactive` | inherit `tab-bar-tab-inactive` |
| `tab-bar-tab-ungrouped` | inherit `tab-bar-tab` |
| `tab-bar-tab-highlight` | inherit `highlight` |
| `completions-common-part` | fg `fg`, bold |
| `completions-first-difference` | fg `fg-identifier` |
| `completions-annotations` | fg `fg-secondary` |
| `completions-group-separator` | fg `line-number` |
| `completions-group-title` | fg `fg-special`, bg `popup-bg`, bold |
| `completions-highlight` | inherit `highlight` |
| `icomplete-first-match` | fg `blossom`, bold |
| `icomplete-selected-match` | fg `fg`, bg `popup-selection` |
| `icomplete-section` | fg `fg-special`, bg `popup-bg`, bold |
| `icomplete-vertical-selected-prefix-indicator-face` | fg `leaf`, bold |
| `icomplete-vertical-unselected-prefix-indicator-face` | fg `line-number` |
| `xref-file-header` | fg `fg`, bold |
| `xref-line-number` | fg `line-number` |
| `xref-match` | fg `fg`, bg `search`, bold |

Consult faces must map as follows:

- `consult-highlight-match`: fg `fg-match`, bold.
- `consult-preview-match`: fg `blossom`, bold.
- `consult-highlight-mark`: fg `leaf`, bold.
- `consult-preview-line`: bg `cursor-line`, extend.
- `consult-preview-insertion`: bg `selection`, extend.
- `consult-narrow-indicator`: fg `fg-special`, bold.
- `consult-async-running`: inherit `warning`.
- `consult-async-finished`: inherit `success`.
- `consult-async-failed`: inherit `error`.
- `consult-async-split`: fg `delimiter`.
- `consult-help`, `consult-grep-context`: fg `comment`.
- `consult-key`: fg `fg`, bold.
- `consult-line-number`, `consult-line-number-prefix`,
  `consult-line-number-wrapped`: fg `line-number`.
- `consult-file`, `consult-buffer`, `consult-bookmark`: inherit `default`.
- `consult-separator`: fg `delimiter`.
- `consult-imenu-prefix`: fg `fg-special`, bold.

Embark faces must map as follows:

- `embark-keybinding`, `embark-keybinding-repeat`: fg `leaf`.
- `embark-keymap`: fg `fg-special`, italic.
- `embark-target`: inherit `highlight`.
- `embark-verbose-indicator-documentation`: fg `comment`.
- `embark-verbose-indicator-title`: fg `fg`, bold.
- `embark-verbose-indicator-shadowed`: inherit `shadow`.
- `embark-collect-candidate`: inherit `default`.
- `embark-collect-group-title`: fg `fg-special`, bold.
- `embark-collect-group-separator`: fg `line-number`.
- `embark-collect-annotation`: inherit `completions-annotations`.
- `embark-selected`: inherit `match`.

### Diagnostics, spell checking, compilation, and debugging

| Faces | Required attributes |
| --- | --- |
| `eglot-inlay-hint-face` | inherit `shadow`, fg `inlay-fg`, bg `inlay-bg`, height `1.0` |
| `eglot-type-hint-face`, `eglot-parameter-hint-face` | inherit `eglot-inlay-hint-face` |
| `flymake-error` | red wave underline using `rose`; do not recolor normal text |
| `flymake-warning` | brown wave underline using `wood`; do not recolor normal text |
| `flymake-note` | green wave underline using `leaf`; do not recolor normal text |
| `flyspell-incorrect` | fg `spell-fg`, red wave underline using `rose` |
| `flyspell-duplicate` | fg `spell-fg`, brown wave underline using `wood` |
| `compilation-error` | inherit `error`, bold |
| `compilation-warning` | inherit `warning` |
| `compilation-info` | inherit `success` |
| `compilation-line-number`, `compilation-column-number` | fg `line-number` |

Eglot publishes diagnostics through Flymake. Do not invent `eglot-error`,
`eglot-warning`, `eglot-info`, or `eglot-hint` faces. Complete the Eglot-specific
contract as follows:

- `eglot-code-action-indicator-face`: inherit `warning`, bold.
- `eglot-diagnostic-tag-deprecated-face`: inherit `shadow`, strike-through.
- `eglot-diagnostic-tag-unnecessary-face`: inherit `shadow`.
- `eglot-highlight-symbol-face`: fg `fg`, bg `color-column`, bold.
- `eglot-mode-line`: inherit `mode-line`, fg `water`, bold.
- `eglot-semantic-abstract`: inherit `font-lock-keyword-face`.
- `eglot-semantic-async`: inherit `font-lock-preprocessor-face`.
- `eglot-semantic-class`, `eglot-semantic-decorator`, `eglot-semantic-enum`,
  `eglot-semantic-interface`, `eglot-semantic-struct`, `eglot-semantic-type`,
  and `eglot-semantic-typeParameter`: inherit `font-lock-type-face`.
- `eglot-semantic-comment`: inherit `font-lock-comment-face`.
- `eglot-semantic-documentation`: inherit `font-lock-doc-face`.
- `eglot-semantic-declaration`, `eglot-semantic-definition`,
  `eglot-semantic-function`, `eglot-semantic-method`,
  `eglot-semantic-modification`, and `eglot-semantic-modifier`: inherit
  `font-lock-function-name-face`.
- `eglot-semantic-defaultLibrary`: inherit `font-lock-builtin-face`.
- `eglot-semantic-deprecated`: inherit
  `eglot-diagnostic-tag-deprecated-face`.
- `eglot-semantic-enumMember`, `eglot-semantic-number`, and
  `eglot-semantic-readonly`: inherit `font-lock-constant-face`.
- `eglot-semantic-event`, `eglot-semantic-parameter`, and
  `eglot-semantic-variable`: inherit `font-lock-variable-name-face`.
- `eglot-semantic-property`: inherit `font-lock-property-use-face`.
- `eglot-semantic-keyword`, `eglot-semantic-namespace`, and
  `eglot-semantic-static`: inherit `font-lock-keyword-face`.
- `eglot-semantic-macro`: inherit `font-lock-preprocessor-face`.
- `eglot-semantic-operator`: inherit `font-lock-operator-face` instead of its
  upstream function-name inheritance.
- `eglot-semantic-regexp`: inherit `font-lock-regexp-face`.
- `eglot-semantic-string`: inherit `font-lock-string-face`.

Complete every Flymake display channel:

- `flymake-error`: wave underline in `rose`, with ordinary text foreground.
- `flymake-warning`: wave underline in `wood`, with ordinary text foreground.
- `flymake-note`: wave underline in `leaf`, with ordinary text foreground.
- `flymake-error-echo`: inherit `compilation-error`.
- `flymake-warning-echo`: inherit `compilation-warning`.
- `flymake-note-echo`: inherit `compilation-info`.
- `flymake-error-echo-at-eol`: inherit
  `(flymake-end-of-line-diagnostics-face compilation-error)`.
- `flymake-warning-echo-at-eol`: inherit
  `(flymake-end-of-line-diagnostics-face compilation-warning)`.
- `flymake-note-echo-at-eol`: inherit
  `(flymake-end-of-line-diagnostics-face compilation-info)`.
- `flymake-error-fringe`: inherit `compilation-error`.
- `flymake-warning-fringe`: inherit `compilation-warning`.
- `flymake-note-fringe`: inherit `compilation-info`.
- `flymake-end-of-line-diagnostics-face`: retain its upstream empty base face;
  do not assign color, height, or font properties.
- `flymake-eol-information-face`: inherit
  `flymake-end-of-line-diagnostics-face`, fg `comment`, italic.

Set compilation mode-line state explicitly:

- `compilation-mode-line-run`: inherit `compilation-warning`.
- `compilation-mode-line-exit`: inherit `compilation-info`, bold.
- `compilation-mode-line-fail`: inherit `compilation-error`, bold.

Dape faces must map as follows:

- `dape-breakpoint-face`: fg `rose`, bold.
- `dape-breakpoint-until-face`: fg `comment`, italic.
- `dape-log-face`: fg `water`.
- `dape-expression-face`: fg `blossom`.
- `dape-hits-face`: fg `leaf`.
- `dape-exception-description-face`: inherit `(error tooltip)`.
- `dape-source-line-face`: bg `color-column`, extend.
- `dape-repl-error-face`: inherit `error`.
- `dape-header-line-active-face`: inherit `mode-line`.
- `dape-header-line-inactive-face`: inherit `mode-line-inactive`.
- `dape-header-line-hover-face`: inherit `mode-line-highlight`.
- `dape-inlay-hint-face`: inherit `eglot-inlay-hint-face`, height `1.0`.
- `dape-inlay-hint-highlight-face`: fg `fg`, bg `search`, height `1.0`.
- `dape-minibuffer-hint-separator-face`: fg `line-number`.

### ANSI and diff primitives

Set both foreground and background of each `ansi-color-*` face to the same
slot value, matching the convention used by the current theme and allowing
the face to represent either ANSI foreground or background.

| Face | Slot | Hex |
| --- | ---: | --- |
| `ansi-color-black` | 0 | `#F0EDEC` |
| `ansi-color-red` | 1 | `#A8334C` |
| `ansi-color-green` | 2 | `#4F6C31` |
| `ansi-color-yellow` | 3 | `#944927` |
| `ansi-color-blue` | 4 | `#286486` |
| `ansi-color-magenta` | 5 | `#88507D` |
| `ansi-color-cyan` | 6 | `#3B8992` |
| `ansi-color-white` | 7 | `#2C363C` |
| `ansi-color-bright-black` | 8 | `#CFC1BA` |
| `ansi-color-bright-red` | 9 | `#94253E` |
| `ansi-color-bright-green` | 10 | `#3F5A22` |
| `ansi-color-bright-yellow` | 11 | `#803D1C` |
| `ansi-color-bright-blue` | 12 | `#1D5573` |
| `ansi-color-bright-magenta` | 13 | `#7B3B70` |
| `ansi-color-bright-cyan` | 14 | `#2B747C` |
| `ansi-color-bright-white` | 15 | `#4F5E68` |

Diff faces must map as follows:

- `diff-added`: fg `leaf`, bg `diff-add-bg`, extend.
- `diff-removed`: fg `rose`, bg `diff-delete-bg`, extend.
- `diff-changed`: fg `water`, bg `diff-change-bg`, extend.
- `diff-refine-added`: fg `fg`, bg `diff-add-bg`, bold.
- `diff-refine-removed`: fg `fg`, bg `diff-delete-bg`, bold.
- `diff-refine-changed`: fg `fg`, bg `diff-text-bg`, bold.
- `diff-context`: fg `fg`.
- `diff-header`: fg `comment`.
- `diff-file-header`: fg `fg`, bold.
- `diff-hunk-header`: fg `line-number`, bg `cursor-line`.
- `diff-index`: fg `wood`.
- `diff-changed-unspecified`: fg `water`, bg `diff-change-bg`, extend.
- `diff-indicator-added`: fg `leaf`, bold.
- `diff-indicator-removed`: fg `rose`, bold.
- `diff-indicator-changed`: fg `water`, bold.
- `diff-function`: fg `fg-special`, bold.
- `diff-nonexistent`: fg `rose`, bg `diff-delete-bg`, extend.
- `diff-error`: inherit `error`.

These primitives are also the color source for diff-hl inline previews and
Difftastic ANSI output. Do not add a parallel diff palette.

### Tree-sitter programming modes and fallback major modes

At `treesit-font-lock-level` 4, the complete Emacs 31 font-lock table above is
the primary color contract for `c-ts-mode`, `c++-ts-mode`, `rust-ts-mode`,
`lua-ts-mode`, `python-ts-mode`, `js-ts-mode`, `typescript-ts-mode`, and
`tsx-ts-mode`. Preserve the face assigned by each built-in mode's Tree-sitter
rules. Do not remap captures in `init.el`.

The exact emitted-face matrix at level 4 is:

- `c-ts-mode` and `c++-ts-mode`: `font-lock-bracket-face`,
  `font-lock-comment-face`, `font-lock-constant-face`,
  `font-lock-delimiter-face`, `font-lock-doc-face`, `font-lock-escape-face`,
  `font-lock-function-call-face`, `font-lock-function-name-face`,
  `font-lock-keyword-face`, `font-lock-negation-char-face`,
  `font-lock-number-face`, `font-lock-operator-face`,
  `font-lock-preprocessor-face`, `font-lock-property-name-face`,
  `font-lock-property-use-face`, `font-lock-string-face`,
  `font-lock-type-face`, `font-lock-variable-name-face`,
  `font-lock-variable-use-face`, and `font-lock-warning-face`.
- `rust-ts-mode`: `font-lock-bracket-face`, `font-lock-builtin-face`,
  `font-lock-comment-face`, `font-lock-constant-face`,
  `font-lock-delimiter-face`, `font-lock-doc-face`, `font-lock-escape-face`,
  `font-lock-function-call-face`, `font-lock-function-name-face`,
  `font-lock-keyword-face`, `font-lock-number-face`,
  `font-lock-operator-face`, `font-lock-preprocessor-face`,
  `font-lock-property-name-face`, `font-lock-property-use-face`,
  `font-lock-string-face`, `font-lock-type-face`,
  `font-lock-variable-name-face`, `font-lock-variable-use-face`, and
  `font-lock-warning-face`.
- `lua-ts-mode`: `font-lock-bracket-face`, `font-lock-builtin-face`,
  `font-lock-comment-delimiter-face`, `font-lock-comment-face`,
  `font-lock-constant-face`, `font-lock-delimiter-face`,
  `font-lock-escape-face`, `font-lock-function-call-face`,
  `font-lock-function-name-face`, `font-lock-keyword-face`,
  `font-lock-number-face`, `font-lock-operator-face`,
  `font-lock-property-name-face`, `font-lock-property-use-face`,
  `font-lock-punctuation-face`, `font-lock-string-face`,
  `font-lock-variable-name-face`, `font-lock-variable-use-face`, and
  `font-lock-warning-face`.
- `python-ts-mode`: `font-lock-bracket-face`, `font-lock-builtin-face`,
  `font-lock-comment-face`, `font-lock-constant-face`,
  `font-lock-delimiter-face`, `font-lock-doc-face`, `font-lock-escape-face`,
  `font-lock-function-call-face`, `font-lock-function-name-face`,
  `font-lock-keyword-face`, `font-lock-misc-punctuation-face`,
  `font-lock-number-face`, `font-lock-operator-face`,
  `font-lock-property-name-face`, `font-lock-property-use-face`,
  `font-lock-string-face`, `font-lock-type-face`,
  `font-lock-variable-name-face`, and `font-lock-variable-use-face`.
- `js-ts-mode`: `font-lock-bracket-face`, `font-lock-comment-face`,
  `font-lock-constant-face`, `font-lock-delimiter-face`,
  `font-lock-doc-face`, `font-lock-doc-markup-face`,
  `font-lock-escape-face`, `font-lock-function-call-face`,
  `font-lock-function-name-face`, `font-lock-keyword-face`,
  `font-lock-misc-punctuation-face`, `font-lock-number-face`,
  `font-lock-operator-face`, `font-lock-property-use-face`,
  `font-lock-regexp-face`, `font-lock-string-face`, `font-lock-type-face`,
  `font-lock-variable-name-face`, and `font-lock-variable-use-face`.
- `typescript-ts-mode` and `tsx-ts-mode`: `font-lock-bracket-face`,
  `font-lock-comment-face`, `font-lock-constant-face`,
  `font-lock-delimiter-face`, `font-lock-escape-face`,
  `font-lock-function-call-face`, `font-lock-function-name-face`,
  `font-lock-keyword-face`, `font-lock-misc-punctuation-face`,
  `font-lock-number-face`, `font-lock-operator-face`,
  `font-lock-property-name-face`, `font-lock-property-use-face`,
  `font-lock-regexp-face`, `font-lock-string-face`, `font-lock-type-face`,
  `font-lock-variable-name-face`, and `font-lock-variable-use-face`.

The level-4 feature groups that must be active and exercised are:

| Mode | Level-4 feature groups |
| --- | --- |
| `c-ts-mode`, `c++-ts-mode` | bracket, delimiter, error, function, operator, property, variable |
| `rust-ts-mode` | bracket, delimiter, error, function, operator, property, variable |
| `lua-ts-mode` | bracket, delimiter, escape, function, operator, property, punctuation, variable |
| `python-ts-mode` | bracket, delimiter, function, operator, variable, property |
| `js-ts-mode` | bracket, delimiter, function, operator, property |
| `typescript-ts-mode` | operator, function, bracket, delimiter |
| `tsx-ts-mode` | function, bracket, delimiter |

Add the only configured programming Tree-sitter faces that sit outside the
shared font-lock table:

- `typescript-ts-jsx-tag-face`: inherit `font-lock-builtin-face`.
- `typescript-ts-jsx-attribute-face`: inherit
  `font-lock-property-name-face`.

These two overrides reproduce the Zenbones Tree-sitter `@tag` to `Special` and
`@tag.attribute` to `@property` mappings at
`refs/zenbones.nvim/lua/zenbones/specs/light.lua:305-307`. Do not retain the
upstream TSX inheritance for these two faces.

The following mappings are fallback coverage for package language modes at
`profiles/common/.config/emacs/init.el:663-672`. They must resolve to the same
semantic colors as the primary Tree-sitter path and must not define independent
palette roles:

- `nim-font-lock-export-face`: inherit `font-lock-builtin-face`.
- `nim-font-lock-pragma-face`: inherit `font-lock-preprocessor-face`.
- `nim-non-overloadable-face`: inherit `font-lock-builtin-face`.
- `nim-font-lock-number-face`: inherit `font-lock-number-face`.
- `zig-multiline-string-face`: inherit `font-lock-string-face`.
- `php-string`: inherit `font-lock-string-face`.
- `php-keyword`, `php-class-declaration`, `php-class-declaration-spec`,
  `php-namespace-declaration`, `php-import-declaration`, `php-class-modifier`,
  `php-method-modifier`, `php-visibility-modifier`, and
  `php-control-structure`: inherit `font-lock-keyword-face`.
- `php-builtin` and `php-magical-constant`: inherit
  `font-lock-builtin-face`.
- `php-function-name`: inherit `font-lock-function-name-face`.
- `php-function-call-standard`, `php-function-call-traditional`,
  `php-method-call-standard`, `php-method-call-traditional`,
  `php-static-method-call-standard`, and
  `php-static-method-call-traditional`: inherit
  `font-lock-function-call-face`.
- `php-variable-name`: inherit `font-lock-variable-name-face`.
- `php-property-name`: inherit `font-lock-property-name-face`.
- `php-type`, `php-class`, `php-doc-$this`, and `php-doc-class-name`: inherit
  `font-lock-type-face`.
- `php-constant`, `php-constant-assign`, and `php-this`: inherit
  `font-lock-constant-face`.
- `php-php-tag`: inherit `font-lock-preprocessor-face`.
- `php-doc-annotation-tag`: inherit `font-lock-doc-markup-face`.
- `php-doc-variable-sigil`: fg `delimiter`.
- `php-variable-sigil`, `php-this-sigil`, and `php-doc-$this-sigil`: fg
  `delimiter`.
- `php-operator`, `php-assignment-op`, `php-comparison-op`, `php-logical-op`,
  `php-arithmetic-op`, `php-inc-dec-op`, `php-string-op`, `php-object-op`,
  `php-pipe-op`, `php-paamayim-nekudotayim`, and `php-errorcontrol-op`: inherit
  `font-lock-operator-face`.
- Do not assign independent PHP hues.
- `css-proprietary-property`: inherit `warning`.
- `css-property`: fg `fg-identifier`.
- `css-selector`: fg `fg`, bold.

Odin mode exposes no independent color face requiring an override; its tokens
must continue to inherit standard font-lock faces. The shell, Python, Emacs
Lisp, and C source modes used by Org Babel at
`profiles/common/.config/emacs/init.el:994-1000`, plus built-in CSS, HTML/SGML,
JavaScript, Python, Lisp, and C-family fallbacks configured at
`profiles/common/.config/emacs/init.el:224-237`, also inherit the same standard
font-lock contract.

No extra color faces are required for parser folding, `hs-minor-mode`,
which-function, Evil motions, or Eglot mode identity.

### Markdown, GFM, and Markdown Tree-sitter

Both package Markdown and built-in Markdown Tree-sitter are selected at
`profiles/common/.config/emacs/init.el:674-676` and
`profiles/common/.config/emacs/init.el:896-909`. Cover both implementations.

Package Markdown faces:

- `markdown-header-face` and `markdown-header-face-1` through
  `markdown-header-face-6`: fg `fg`, bold.
- `markdown-header-rule-face`: fg `delimiter`.
- `markdown-header-delimiter-face`, `markdown-markup-face`,
  `markdown-line-break-face`, `markdown-hr-face`, and
  `markdown-html-tag-delimiter-face`: fg `delimiter`.
- `markdown-bold-face`: inherit `bold`.
- `markdown-italic-face`: inherit `italic`.
- `markdown-strike-through-face`: strike-through only.
- `markdown-list-face`, `markdown-gfm-checkbox-face`, `markdown-math-face`,
  `markdown-html-entity-face`: fg `fg-special`, bold.
- `markdown-blockquote-face`: fg `fg-constant`, italic.
- `markdown-code-face`, `markdown-pre-face`: inherit `fixed-pitch`, fg `type`,
  bg `inlay-bg`, extend.
- `markdown-inline-code-face`: inherit
  `(markdown-code-face markdown-pre-face)`, height `1.0`, no extended
  background past the inline span.
- `markdown-table-face`: fg `fg`.
- `markdown-language-keyword-face`: fg `fg`, bold.
- `markdown-language-info-face`: fg `fg-secondary`, italic.
- `markdown-link-face`: fg `fg-identifier`, underline.
- `markdown-url-face`, `markdown-plain-url-face`: fg `comment`, underline.
- `markdown-missing-link-face`: inherit `error`.
- `markdown-reference-face`, `markdown-footnote-text-face`: fg `fg-constant`.
- `markdown-footnote-marker-face`: fg `fg-special`, bold.
- `markdown-link-title-face`: fg `fg-constant`, italic.
- `markdown-comment-face`: inherit `font-lock-comment-face`.
- `markdown-metadata-key-face`: fg `fg`, bold.
- `markdown-metadata-value-face`: fg `fg-constant`, italic.
- `markdown-highlight-face`, `markdown-highlighting-face`: inherit `highlight`.
- `markdown-html-tag-name-face`: fg `fg-special`, bold.
- `markdown-html-attr-name-face`: fg `fg-identifier`.
- `markdown-html-attr-value-face`: inherit `font-lock-string-face`.

Markdown Tree-sitter faces:

- `markdown-ts-heading-1` through `markdown-ts-heading-6` and
  `markdown-ts-setext-heading`: fg `fg`, bold.
- `markdown-ts-delimiter`, `markdown-ts-table-delimiter-cell`,
  `markdown-ts-hard-line-break-backslash`,
  `markdown-ts-hard-line-break-backslash-hidden`,
  `markdown-ts-hard-line-break-space`,
  `markdown-ts-hard-line-break-space-hidden`, and
  `markdown-ts-thematic-break`: fg `delimiter`.
- `markdown-ts-bold`, `markdown-ts-emphasis`, and
  `markdown-ts-strikethrough`: weight, slant, and strike-through only.
- `markdown-ts-link`: fg `fg-identifier`, underline.
- `markdown-ts-link-destination`: fg `comment`, underline.
- `markdown-ts-block-quote`: fg `fg-constant`, italic.
- `markdown-ts-code-block`, `markdown-ts-indented-code-block`, and
  `markdown-ts-in-code-block`: inherit `fixed-pitch`, fg `type`, bg `inlay-bg`,
  extend.
- `markdown-ts-code-span`: inherit
  `(markdown-ts-code-block font-lock-constant-face)`, height `1.0`, with no
  extended background outside the inline span.
- `markdown-ts-code-block-markup-hidden`: bg `inlay-bg`.
- `markdown-ts-language-keyword`: fg `fg`, bold.
- `markdown-ts-list-marker`, `markdown-ts-task-checked`, and
  `markdown-ts-task-unchecked`: fg `fg-special`, bold.
- `markdown-ts-entity-reference`, `markdown-ts-numeric-character-reference`,
  `markdown-ts-latex`, and `markdown-ts-html-tag`: fg `fg-special`, normal
  weight.
- `markdown-ts-html-block`: inherit `default`.
- `markdown-ts-table`, `markdown-ts-table-cell`, `markdown-ts-in-table`: fg
  `fg`.
- `markdown-ts-table-header`: fg `fg`, bold.

### Org, Agenda, Babel, Roam, and citations

Org and the research packages are configured at
`profiles/common/.config/emacs/init.el:923-1108`.

Base Org faces:

- `org-default`: inherit `default`.
- `org-document-title`: fg `fg`, bold.
- `org-document-info`: fg `fg`.
- `org-document-info-keyword`, `org-meta-line`, `org-drawer`, `org-archived`,
  and `org-special-keyword`: fg `comment`.
- `org-level-1` through `org-level-8` and `outline-1` through `outline-8`: fg
  `fg`, bold. Remove the current rainbow heading colors and do not introduce
  per-level size changes.
- `org-block`, `org-inline-src-block`: bg `inlay-bg`, extend.
- `org-block-begin-line`, `org-block-end-line`: fg `comment`, bg `inlay-bg`,
  italic, extend.
- `org-code`, `org-verbatim`, `org-latex-and-related`, `org-formula`, and
  `org-macro`: fg `type`.
- `org-quote`, `org-verse`: fg `fg-constant`, bg `inlay-bg`, italic, extend.
- `org-link`, `org-target`: fg `fg-identifier`, underline.
- `org-footnote`: fg `fg-special`.
- `org-table`, `org-table-row`: fg `fg`.
- `org-table-header`: fg `fg`, bold.
- `org-list-dt`: fg `fg-special`, bold.
- `org-property-value`: fg `fg-constant`.
- `org-tag`, `org-tag-group`: fg `comment`, normal weight.
- `org-priority`, `org-warning`, `org-imminent-deadline`: fg `rose`.
- `org-hide`: fg `bg`.
- `org-ellipsis`: fg `delimiter`, bg `bg`, no underline.
- `org-checkbox`: fg `fg-special`, bold.
- `org-checkbox-statistics-done`: fg `leaf`.
- `org-checkbox-statistics-todo`: fg `wood`.
- `org-clock-overlay`: bg `selection`.
- `org-column`: bg `float-bg`.
- `org-column-title`: fg `fg`, bg `float-bg`, bold.
- `org-dispatcher-highlight`: fg `bg`, bg `blossom`, bold.
- `org-mode-line-clock`: inherit `mode-line`.
- `org-mode-line-clock-overrun`: fg `rose`, inherit mode-line background.

Define `org-todo-keyword-faces` through `custom-theme-set-variables` with this
exact mapping for the keywords configured at
`profiles/common/.config/emacs/init.el:925-929`:

| Keyword | Attributes |
| --- | --- |
| `PROJ` | fg `water`, bold |
| `TODO` | fg `fg`, bold, underline |
| `REVIEW` | fg `blossom`, bold |
| `POST` | fg `sky`, bold |
| `DOING` | fg `wood`, bold |
| `BLOCKED` | fg `rose`, bold |
| `DONE` | fg `leaf`, bold |
| `CANCELED` | fg `comment`, strike-through |

Set the fallback `org-todo` to fg `fg`, bold, underline; `org-done` and
`org-headline-done` to fg `leaf`; and `org-headline-todo` to inherit
`org-todo`.

Agenda and scheduling faces:

- `org-date`, `org-date-selected`, `org-sexp-date`: fg `wood`; selected date
  also uses `selection` background.
- `org-scheduled`, `org-scheduled-today`: fg `wood`; today is bold.
- `org-scheduled-previously`: fg `rose`.
- `org-upcoming-deadline`: fg `wood`.
- `org-upcoming-distant-deadline`: fg `comment`.
- `org-agenda-structure`, `org-agenda-structure-filter`,
  `org-agenda-structure-secondary`: fg `fg`, bold.
- `org-agenda-date`: fg `fg`.
- `org-agenda-date-weekend`: fg `comment`.
- `org-agenda-date-today`, `org-agenda-date-weekend-today`: fg `fg`, bold,
  underline.
- `org-agenda-current-time`: fg `water`, bold.
- `org-agenda-done`: fg `leaf`.
- `org-agenda-dimmed-todo-face`: fg `comment`.
- `org-agenda-clocking`: bg `selection`.
- `org-agenda-restriction-lock`: bg `search`.
- `org-agenda-filter-category`, `org-agenda-filter-effort`,
  `org-agenda-filter-regexp`, `org-agenda-filter-tags`: fg `blossom`, bold.
- `org-agenda-calendar-daterange`: inherit `org-date`.
- `org-agenda-calendar-event`: inherit `default`.
- `org-agenda-calendar-sexp`: inherit `default`.
- `org-agenda-column-dateline`: inherit `org-column`, fg `line-number`.
- `org-agenda-diary`: inherit `default`.
- `org-time-grid`: fg `line-number`.

Citation and research faces:

- `org-cite` and `org-ref-ref-face`: fg `sky`, underline.
- `org-cite-key` and `org-ref-label-face`: fg `fg-identifier`, underline.
- `org-ref-cite-face`: fg `wood`, underline.
- `org-ref-glossary-face`: fg `blossom`.
- `org-ref-acronym-face`: fg `fg-special`.
- `org-ref-bad-cite-key-face` and
  `org-ref-cite-invalid-local-prefix/suffix-face`: inherit `error`.
- `org-ref-cite-global-prefix/suffix-face`, `org-ref-cite-&-face`, and
  `org-ref-cite-local-prefix/suffix-face`: fg `comment`.

Org Roam faces:

- `org-roam-header-line`: inherit `header-line`.
- `org-roam-title`, `org-roam-preview-heading`: fg `fg`, bold.
- `org-roam-olp`, `org-roam-dim`: fg `comment`.
- `org-roam-preview-heading-highlight`: bg `cursor-line`, bold.
- `org-roam-preview-heading-selection`: bg `selection`, bold.
- `org-roam-preview-region`, `org-roam-overlay`: bg `cursor-line`, extend.
- `org-roam-dailies-calendar-note`: fg `sky`, bold.

gscholar-bibtex faces:

- `gscholar-bibtex-title`: fg `fg`, bold, height `1.4`.
- `gscholar-bibtex-subtitle`: fg `comment`, height `1.0`.

Org Fragtog requires no direct face. Its LaTeX preview already requests the
active theme's default foreground and background at
`profiles/common/.config/emacs/init.el:1044-1053`.

### Magit, Git commit, rebase, blame, and diff-hl

Magit and diff-hl are configured at
`profiles/common/.config/emacs/init.el:565-606`. Cover the full installed Magit
face vocabulary so no raw named colors remain visible.

References and branches:

- `magit-branch-current`: fg `water`, bold.
- `magit-branch-local`: fg `sky`.
- `magit-branch-remote`, `magit-branch-remote-head`: fg `leaf`.
- `magit-branch-upstream`: fg `water`.
- `magit-branch-warning`: inherit `warning`.
- `magit-head`: fg `water`, bold.
- `magit-refname`, `magit-refname-stash`, `magit-refname-wip`,
  `magit-refname-pullreq`: fg `fg-special`; stash uses `blossom`, WIP uses
  `wood`, and pull requests use `sky`.
- `magit-tag`: fg `wood`.
- `magit-hash`, `magit-dimmed`: fg `comment`.
- `magit-filename`: fg `type`.

Sections, logs, and process state:

- `magit-section-heading`: fg `fg`, bold, extend.
- `magit-section-secondary-heading`: fg `fg-special`, bold, extend.
- `magit-section-highlight`: bg `cursor-line`, extend.
- `magit-section-heading-selection`: fg `blossom`, bold, extend.
- `magit-section-child-count`: fg `comment`.
- `magit-left-margin`: inherit `default`.
- `magit-log-author`: fg `wood`.
- `magit-log-date`: fg `water`.
- `magit-log-graph`: fg `comment`.
- `magit-process-ok`: inherit `success`.
- `magit-process-ng`: inherit `error`.
- `magit-mode-line-process`: inherit `mode-line`, fg `water`.
- `magit-mode-line-process-error`: inherit `mode-line`, fg `rose`.
- `magit-header-line`, `magit-header-line-log-select`: inherit `header-line`.
- `magit-header-line-key`: fg `fg`, bold.

Diffs:

- `magit-diff-added`: fg `leaf`, no forced background, extend.
- `magit-diff-added-highlight`: fg `fg`, bg `diff-add-bg`, extend.
- `magit-diff-removed`: fg `rose`, no forced background, extend.
- `magit-diff-removed-highlight`: fg `fg`, bg `diff-delete-bg`, extend.
- `magit-diff-base`, `magit-diff-our`, `magit-diff-their`: fg `water`, no
  forced background, extend.
- `magit-diff-base-highlight`, `magit-diff-our-highlight`, and
  `magit-diff-their-highlight`: fg `fg`, bg `diff-change-bg`, extend.
- `magit-diff-context`: fg `fg`, bg `bg`, extend.
- `magit-diff-context-highlight`: fg `fg`, bg `cursor-line`, extend.
- `magit-diff-file-heading`: fg `fg`, bold, extend.
- `magit-diff-file-heading-highlight`: bg `cursor-line`, bold, extend.
- `magit-diff-file-heading-selection`: bg `selection`, bold, extend.
- `magit-diff-hunk-heading`: fg `line-number`, bg `mode-line-inactive-bg`,
  extend.
- `magit-diff-hunk-heading-highlight`: fg `fg`, bg `cursor-line`, bold,
  extend.
- `magit-diff-hunk-heading-selection`: fg `blossom`, bg `selection`, bold,
  extend.
- `magit-diff-hunk-region`: bg `selection`, extend.
- `magit-diff-conflict-heading`, `magit-diff-lines-heading`: fg `wood`, bold.
- `magit-diff-conflict-heading-highlight`: fg `wood`, bg `cursor-line`, bold,
  extend.
- `magit-diff-lines-boundary`: fg `blossom`, bg `selection`, bold, extend.
- `magit-diff-revision-summary`: fg `fg`, bold.
- `magit-diff-revision-summary-highlight`: bg `cursor-line`, bold.
- `magit-diff-whitespace-warning`: inherit `error`.
- `magit-diffstat-added`: fg `leaf`.
- `magit-diffstat-removed`: fg `rose`.

Other Magit and Git modes:

- `magit-keyword`: fg `fg`, bold; `magit-keyword-squash`: fg `blossom`, bold.
- `magit-signature-good`: inherit `success`.
- `magit-signature-bad`: inherit `error`.
- `magit-signature-untrusted`: inherit `warning`.
- `magit-signature-expired`: inherit `shadow`.
- `magit-signature-expired-key`: inherit `warning`.
- `magit-signature-revoked`: inherit `error`.
- `magit-signature-error`: inherit `error`.
- `magit-cherry-unmatched`: fg `leaf`.
- `magit-cherry-equivalent`: fg `blossom`.
- `magit-reflog-commit`, `magit-reflog-merge`, and
  `magit-reflog-cherry-pick`: fg `leaf`.
- `magit-reflog-amend` and `magit-reflog-rebase`: fg `blossom`.
- `magit-reflog-checkout`: fg `water`.
- `magit-reflog-reset`: fg `rose`.
- `magit-reflog-remote` and `magit-reflog-other`: fg `sky`.
- `magit-sequence-pick`, `magit-sequence-part`, `magit-sequence-head`, and
  `magit-sequence-done`: fg `leaf`.
- `magit-sequence-stop` and `magit-sequence-drop`: fg `rose`.
- `magit-sequence-onto`: fg `water`.
- `magit-sequence-exec`: fg `wood`.
- `git-rebase-hash`: inherit `magit-hash`.
- `git-rebase-label`: inherit `magit-refname`.
- `git-rebase-description`: inherit `default`.
- `git-rebase-action`: fg `fg`, bold.
- `git-rebase-killed-action`: fg `comment`, strike-through.
- `git-rebase-comment-hash`: fg `comment`.
- `git-rebase-comment-heading`: fg `comment`, bold.
- `git-commit-summary`: fg `fg`, bold.
- `git-commit-overlong-summary`, `git-commit-nonempty-second-line`: inherit
  `error`.
- `git-commit-keyword`, `git-commit-trailer-token`: fg `fg-special`, bold.
- `git-commit-trailer-value`: fg `fg-constant`.
- `git-commit-comment-branch-local`: inherit `magit-branch-local`.
- `git-commit-comment-branch-remote`: inherit `magit-branch-remote`.
- `git-commit-comment-detached`: inherit `warning`.
- `git-commit-comment-heading`: fg `comment`, bold.
- `git-commit-comment-file`: fg `type`.
- `git-commit-comment-action`: fg `fg-special`.
- `magit-blame-highlight`, `magit-blame-heading`: bg `cursor-line`, extend.
- `magit-blame-margin`: inherit `fringe`.
- `magit-blame-dimmed`: fg `comment`.
- `magit-blame-summary`: inherit `default`.
- `magit-blame-hash`: inherit `magit-hash`.
- `magit-blame-name`: inherit `magit-log-author`.
- `magit-blame-date`: inherit `magit-log-date`.
- `magit-bisect-good`: inherit `success`.
- `magit-bisect-skip`: inherit `warning`.
- `magit-bisect-bad`: inherit `error`.

diff-hl uses the core diff faces for fringe and inline hunk presentation. Do
not hard-code a second set of colors in `init.el`. Verify add/change/delete
fringe indicators and the configured inline preview at
`profiles/common/.config/emacs/init.el:576-592`.

### Dired, help, and special buffers

- `dired-directory`: fg `fg`, bold.
- `dired-symlink`: fg `sky`, bold.
- `dired-ignored`: fg `comment`.
- `dired-flagged`: fg `rose`.
- `dired-header`: fg `fg`, bold.
- `dired-mark`: fg `wood`, bold.
- `dired-marked`: fg `blossom`, bg `selection`, bold.
- `dired-perm-write`: fg `fg`, underline.
- `dired-broken-symlink`: inherit `error`.
- `dired-set-id`: fg `wood`, bold.
- `dired-special`: fg `fg-special`, bold.
- `dired-warning`: inherit `warning`.

Help and Info faces:

- `help-argument-name`: fg `fg-identifier`, italic.
- `help-for-help-header`: fg `fg`, bold.
- `help-key-binding`: fg `leaf`, bold.
- `info-header-node`: inherit `shadow`.
- `info-header-xref`, `info-xref`: inherit `link`.
- `info-xref-visited`: inherit `link-visited`.
- `info-index-match`: inherit `match`.
- `info-menu-header`, `info-node`, `info-title-1`, `info-title-2`,
  `info-title-3`, and `info-title-4`: fg `fg`, bold.
- `info-menu-star`: fg `blossom`, bold.
- `Info-quoted`: inherit `font-lock-constant-face`.

Man faces:

- `Man-overstrike`: inherit `bold`.
- `Man-reverse`: fg `bg`, bg `fg`.
- `Man-underline`: inherit `link`.

Widget and Customize faces:

- `widget-button`: inherit `link`, bold.
- `widget-button-pressed`: fg `bg`, bg `blossom`, bold.
- `widget-documentation`: fg `comment`.
- `widget-field`, `widget-single-line-field`: fg `fg`, bg `popup-bg`.
- `widget-inactive`: inherit `shadow`.
- `widget-unselected`: inherit `default`.
- `custom-button`: inherit `widget-button`.
- `custom-button-mouse`: fg `fg`, bg `popup-selection`.
- `custom-button-pressed`: inherit `widget-button-pressed`.
- `custom-button-pressed-unraised`, `custom-button-unraised`, `custom-link`, and
  `custom-visibility`: inherit `link`.
- `custom-changed`, `custom-modified`: inherit `warning`.
- `custom-comment`, `custom-documentation`: fg `comment`.
- `custom-comment-tag`: fg `fg-special`, bold.
- `custom-face-tag`, `custom-group-tag`, `custom-group-tag-1`,
  `custom-variable-tag`: fg `fg`, bold.
- `custom-group-subtitle`: fg `fg-special`, bold.
- `custom-invalid`, `custom-rogue`: inherit `error`.
- `custom-saved`: inherit `success`.
- `custom-set`, `custom-themed`: fg `water`.
- `custom-state`: fg `comment`.
- `custom-variable-button`: fg `fg`, bold.
- `custom-variable-obsolete`: inherit `shadow`, strike-through.

Do not add a second Help, Info, Man, Widget, or Customize palette beyond these
semantic mappings.
- `my/annotations-mode` is derived from `special-mode` and adds no face text
  properties at `profiles/common/.config/emacs/my-send-text.el:439-466`; it
  therefore inherits core, diff, link, and font-lock faces without a dedicated
  face.
- Fundamental mode and Messages buffers inherit core faces. No dedicated mode
  color is required.

### Which Key, Evil, and Gptel

Which Key must mirror Zenbones' Neovim mapping at
`refs/zenbones.nvim/lua/zenbones/specs/light.lua:476-479`:

- `which-key-key-face`: fg `fg`, bold.
- `which-key-group-description-face`: fg `fg-special`, bold.
- `which-key-command-description-face`: fg `fg-constant`, italic.
- `which-key-local-map-description-face`: fg `fg-special`, bold.
- `which-key-separator-face`: fg `line-number`.
- `which-key-special-key-face`: fg `blossom`, bold.
- `which-key-highlighted-command-face`: fg `blossom`, bold.
- `which-key-docstring-face`: fg `comment`, italic.
- `which-key-note-face`: fg `comment`, italic.

Evil faces:

- `evil-ex-commands`: fg `fg`, bold.
- `evil-ex-info`: fg `comment`, italic.
- `evil-ex-search`: inherit `isearch`.
- `evil-ex-lazy-highlight`: inherit `lazy-highlight`.
- `evil-ex-substitute-matches`: fg `rose`, bg `diff-delete-bg`,
  strike-through.
- `evil-ex-substitute-replacement`: fg `leaf`, bg `diff-add-bg`, bold.

Gptel faces:

- `gptel-context-highlight-face`: fg `fg`, bg `inlay-bg`.
- `gptel-context-deletion-face`: fg `rose`, bg `diff-delete-bg`,
  strike-through.
- `gptel-rewrite-highlight-face`: fg `fg`, bg `diff-change-bg`.

### Ghostel terminal buffers

Ghostel's face contract is defined at
`refs/ghostel/lisp/ghostel-faces.el:8-13` and
`refs/ghostel/lisp/ghostel-faces.el:22-144`.

- `ghostel-default`: fg `fg`, bg `bg`.
- `ghostel-fake-cursor`: box color `fg` with the upstream negative one-pixel
  box width retained.
- `ghostel-fake-cursor-box`: inherit `cursor`.
- Restate every `ghostel-color-*` face as inheriting its matching
  `ansi-color-*` face. Do not duplicate the 16 RGB values in Ghostel-specific
  declarations. Effective Ghostel foreground and background values must come
  from the exact ANSI faces above.
- Keep `ghostel-color-palette` in its upstream order. Do not replace or reorder
  the vector.
- Do not add a `ghostel-mode-hook` for colors. Global `region` supplies the
  exact selection colors, global `cursor` supplies the real cursor color, and
  `ghostel-default` plus `ghostel-color-*` supply the native terminal defaults
  and ANSI palette.
- Do not call `ghostel-sync-theme` from the configuration. Ghostel already
  installs theme-change synchronization at
  `refs/ghostel/lisp/ghostel.el:3676-3700`.
- Preserve `ghostel-bold-color` at its upstream value `nil`. Bold text changes
  weight only; it does not implicitly select the bright ANSI slot.

The resulting Ghostel contract must equal the generated Ghostty scheme at
`refs/zenbones.nvim/extras/ghostty/zenbones_light:5-37`:

- Foreground: `#2C363C`
- Background: `#F0EDEC`
- Selection foreground/background: `#2C363C` / `#CBD9E3`
- Cursor color/text: `#2C363C` / `#F0EDEC`
- Palette slots 0 through 15: the ANSI table above in order

term-sessions, ghostel-compile, and zmx attachment buffers require no separate
palette. They use Ghostel or standard compilation/special-mode faces.

### Intentionally inherited surfaces with no independent palette

The following configured packages and modes are explicitly classified as
having no additional color vocabulary. Do not add speculative faces for them:

- Olivetti uses layout only and inherits the buffer's major-mode faces.
- Evil Visualstar, Evil Surround, Evil Collection, Evil Better Visual Line,
  and Evil Numbers use core or Evil faces already mapped above.
- diff-hl inherits core diff faces for add, change, delete, and inline preview.
- Difftastic uses ANSI output plus Magit and diff faces.
- parser folding, hs-minor-mode, which-function, and Tree-sitter navigation use
  core font-lock, line-number, fringe, and highlight faces.
- Org Fragtog uses the active `default` foreground and background for LaTeX
  preview generation.
- Evil Org uses Org and Evil faces.
- Org Roam BibTeX uses Org Roam, Org Ref, completion, and font-lock faces.
- gscholar-bibtex uses the two explicit title faces above, completion faces,
  and standard buffer faces.
- ob-async uses Org, compilation, and standard process faces.
- org-autolist uses Org list and checkbox faces.
- evil-ghostel uses Ghostel, Evil, mode-line, and core semantic faces.
- ghostel-compile uses Ghostel while the process is live and compilation faces
  in its finalized result view.
- term-sessions-core, term-sessions-frontends, term-sessions-zmx, and
  term-sessions-org expose no independent theme faces.
- `tabulated-list-fake-header` inherits `header-line`; term-sessions-list-mode
  uses that face plus core faces.
- `my/annotations-mode` inserts unpropertized text in a `special-mode`
  derivative and therefore uses core, link, and diff faces.
- Fundamental mode and Messages buffers use core faces.
- Org Babel source blocks use Org block faces around the font-lock faces of
  shell, Python, Emacs Lisp, and C.

## Preserved behavior contract

- The custom mode line at `profiles/common/.config/emacs/init.el:241-257`
  retains its exact contents and ordering.
- The font setup at `profiles/common/.config/emacs/init.el:280-294` remains
  unchanged.
- Evil state tags at `profiles/common/.config/emacs/init.el:355-365` retain
  their labels and continue consuming generic semantic faces.
- Completion remains eager, one-column, and 14 lines high.
- Eglot and Dape do not start automatically as a result of theme loading.
- Tree-sitter mode selection and parser behavior remain unchanged. The one
  intentional fontification change is raising `treesit-font-lock-level` from
  its Emacs 31 default of `3` to `4` so all detailed capture groups render.
- Markdown inline code remains height `1.0` and follows the configured default
  font metrics.
- Org TODO keywords, transitions, hooks, capture templates, and agenda files
  remain unchanged; only the displayed faces change.
- Magit commands, Evil integration, diff-hl behavior, and Difftastic bindings
  remain unchanged.
- Ghostel input modes, Evil escape handling, process creation, and
  term-sessions routing remain unchanged.
- Theme loading performs no package installation, network access, native
  module build, or terminal creation.

## Alternatives rejected

- Install an Emacs Zenbones package: it would add a dependency and still need
  substantial repository-specific overrides for Ghostel, Markdown Tree-sitter,
  Org Ref, Magit, Dape, Gptel, and the current metric contracts.
- Keep `mig-one-light` as the theme name while replacing its colors: the name
  and source commentary would be false and would obscure the intentional
  breaking change.
- Load two themes: theme precedence would become order-dependent and package
  faces loaded later could expose mixed One Light and Zenbones values.
- Use only the eight base accent colors: exact Zenbones UI, syntax ramps,
  selection, search, popup, mode-line, inlay, diagnostic, and diff backgrounds
  require the derived colors listed above.
- Preserve rainbow syntax and Org headings: default Zenbones light is
  intentionally weight-driven and close to monochrome.
- Theme Ghostel through a mode hook: Ghostel exposes stable theme faces and a
  built-in theme synchronization path, so a hook would duplicate package
  behavior and risk stale live terminals.
- Add the generated standalone Ghostty config: the configured Emacs buffers
  are Ghostel buffers, and no tracked Ghostty application configuration exists.
- Add broad screenshots or source-content tests: face attributes and rendered
  mode behavior can be tested directly.

## Phase 1: Replace the theme identity and establish the palette

Status: complete

### Changes

1. Rename `profiles/common/.config/emacs/themes/mig-one-light-theme.el` to
   `profiles/common/.config/emacs/themes/mig-zenbones-light-theme.el`. This
   preserves the complete existing face inventory while it is remapped in
   later phases and ensures there is never a duplicate theme file.
2. Replace the theme symbol, commentary, Doom/Atom attribution, and license
   header with `mig-zenbones-light`, the pinned Zenbones and Lush revisions,
   and the Zenbones MIT attribution from `refs/zenbones.nvim/LICENSE`.
3. Add the exact palette bindings above and set `frame-background-mode` to
   `light`.
4. Implement core default, cursor, selection, line-number, search, syntax,
   mode-line, tab-bar, and ANSI faces first. Leave the remaining existing face
   declarations present for later phases instead of temporarily dropping
   coverage.
5. Update `profiles/common/.config/emacs/init.el:260-263` to load only
   `mig-zenbones-light`.
6. Update `profiles/common/.config/emacs/appearance-test.el:9-16` to reload
   `mig-zenbones-light` instead of `mig-one-light`.
7. Do not modify `custom-safe-themes`, font setup, or frame settings outside
   the theme.

### Success criteria

- A clean Emacs 31.1 batch process exits successfully, prints `CONFIG_LOADED`,
  and emits no new theme or package-face warning. Existing unrelated startup
  warnings, including the current org-autolist deprecated positional-argument
  warning, are recorded separately and are not attributed to this change.
- `custom-enabled-themes` contains `mig-zenbones-light` and does not contain
  `mig-one-light`.
- Effective `default` is fg `#2C363C`, bg `#F0EDEC`.
- Effective cursor, region, line-number, search, mode-line, and ANSI faces
  match the exact values in this plan.
- No One Light theme file or theme symbol remains in the tracked Emacs config
  or tests.

## Phase 2: Make Tree-sitter the primary syntax color path

Status: complete

### Changes

1. Set `treesit-font-lock-level` to `4` next to `treesit-enabled-modes`.
2. Implement the full Emacs 31 font-lock mapping, including function-call,
   variable-use, property, operator, punctuation, regexp, escape, and doc
   markup faces omitted by the current theme.
3. Implement the TSX JSX tag and attribute mappings specified above.
4. Validate actual fontified tokens in C, C++, Rust, Lua, Python, JavaScript,
   TypeScript, and TSX buffers before adding fallback-mode overrides.
5. Add the Nim, PHP, Zig, and CSS fallback mappings specified above. Confirm
   that Odin continues to use only the standard font-lock contract.
6. Confirm that Org Babel shell, Python, Emacs Lisp, and C source buffers, plus
   built-in non-Tree-sitter fallbacks, consume the shared syntax roles.
7. Preserve comments and strings as italic because the active Zenbones options
   leave both italic defaults enabled.
8. Do not add per-language Tree-sitter rules, capture remapping, hooks, or
   font-lock keyword rewrites.

### Success criteria

- `treesit-font-lock-level` is `4` and every configured programming
  `*-ts-mode` uses the exact shared syntax colors and attributes.
- Every test buffer enters its expected `*-ts-mode`; a classic-mode fallback is
  a failure when the corresponding pinned grammar is expected.
- Tests prove the actual face and effective color on representative captures
  in C, C++, Rust, Lua, Python, JavaScript, TypeScript, and TSX, including
  level-4 function calls, operators, brackets, delimiters, and properties.
- Keywords and functions use normal foreground, with keywords distinguished by
  bold weight.
- Variables/properties, constants/strings/numbers, types, builtins, comments,
  and punctuation resolve to their specified roles.
- TSX JSX tags resolve through `typescript-ts-jsx-tag-face` to `#4F5E68` and
  bold. JSX attributes resolve through `typescript-ts-jsx-attribute-face` to
  `#44525B` with normal slant.
- No Tree-sitter-fontified token resolves to a One Light hex value or a raw
  named color.
- No package-specific raw named colors appear in Nim, PHP, or Zig buffers.
- Nim, Odin, PHP, and Zig remain in their package major modes; their
  language-specific faces resolve through the shared semantic palette.
- Parser creation, indentation, folding, Flyspell, Eglot, and Evil behavior are
  unchanged.

## Phase 3: Complete Markdown and Org ecosystem coverage

Status: pending

### Changes

1. Implement every Markdown Tree-sitter face mapping listed in this plan, then
   implement classic `markdown-mode` and `gfm-mode` as fallback coverage.
2. Keep package and Tree-sitter Markdown visually equivalent for headings,
   code, links, lists, tables, blockquotes, metadata, and inline markup.
3. Implement the complete Org, Agenda, scheduling, table, block, citation,
   Org Ref, and Org Roam mappings listed above.
4. Add the exact `org-todo-keyword-faces` variable mapping through the theme.
5. Preserve all Org workflow variables and Markdown mode dispatch.

### Success criteria

- `markdown-mode`, `gfm-mode`, and `markdown-ts-mode` render equivalent
  constructs with the same palette and text metrics.
- All Markdown headings and Org levels are monochrome `#2C363C` and bold.
- Inline and fenced code use the correct fixed-pitch metrics and `#EBE7E6`
  background.
- Org TODO keyword faces match the exact state table without changing TODO
  transitions.
- Agenda dates, deadlines, filters, clocking, and completed items remain
  visually distinguishable.
- Org citations, Org Ref invalid keys, Roam previews, and LaTeX fragments are
  legible on the new background.

## Phase 4: Complete development and utility UI coverage

Status: pending

### Changes

1. Implement Magit, Git commit, rebase, reflog, sequence, blame, bisect,
   section, diff, signature, header-line, and process faces exactly as listed.
2. Implement core diff, diff-hl, compilation, Flymake, Flyspell, Eglot, Xref,
   and Dape mappings.
3. Implement completion, Consult, Embark, Which Key, Evil, Dired, help, and
   Gptel mappings.
4. Implement both gscholar-bibtex title faces. Let Olivetti, term-sessions,
   org-fragtog, ob-async, `my/annotations-mode`, fundamental mode, and Messages
   inherit their declared core parents. Do not invent package-specific faces
   where none exist.

### Success criteria

- Magit status, diff, log, process, blame, rebase, reflog, and commit buffers
  contain no default named red/green/blue/magenta/cyan colors.
- Added, changed, removed, context, refined, selected, and conflict states are
  visually distinct and use the exact diff palette.
- Flymake, Flyspell, compilation, Eglot, Xref, and Dape states use consistent
  diagnostic semantics.
- Consult, Embark, Which Key, Evil search, Dired, and Gptel remain readable and
  visually consistent with the equivalent Zenbones Neovim surfaces.

## Phase 5: Apply Zenbones light to Ghostel terminal buffers

Status: pending

### Changes

1. Add `ghostel-default`, both Ghostel cursor faces, and all 16
   `ghostel-color-*` inheritance declarations to the theme.
2. Make each Ghostel color face inherit its exact matching ANSI face and add
   no direct RGB attribute to the Ghostel color face.
3. Preserve the upstream `ghostel-color-palette` ordering and automatic theme
   synchronization.
4. Do not add terminal color hooks, call internal Ghostel functions, or add a
   standalone Ghostty configuration file.
5. Do not set `ghostel-bold-color`; preserve its upstream `nil` behavior.

### Success criteria

- A new Ghostel buffer uses fg `#2C363C`, bg `#F0EDEC`, selection fg/bg
  `#2C363C` / `#CBD9E3`, and cursor text/bg `#F0EDEC` / `#2C363C`.
- ANSI slots 0 through 15 extracted from the Ghostel faces exactly match
  `refs/zenbones.nvim/extras/ghostty/zenbones_light:15-37`.
- A Ghostel buffer that is already open updates after reloading or enabling
  the theme, without manually calling `ghostel-sync-theme`.
- Ghostel char/semi-char state, Evil state, PTY input, scrollback, and process
  behavior are unchanged.
- term-sessions and ghostel-compile buffers display the same palette.

## Phase 6: Add focused automated and visual verification

Status: pending

### Automated test changes

Extend `profiles/common/.config/emacs/appearance-test.el`; do not create a
second theme-only test file. Keep the test count small by using data-driven
tables inside these behavior tests:

1. Update the existing Eglot and Markdown tests to load
   `mig-zenbones-light`, retaining all current metric and inheritance
   assertions.
2. Add one data-driven palette test that checks effective foreground,
   background, weight, slant, underline, and extend attributes for the core UI,
   all semantic font-lock roles, ANSI slots, diagnostics, and diff primitives.
   Check both foreground and background for all 16 ANSI faces.
3. Add one data-driven Tree-sitter token test. For each of `c-ts-mode`,
   `c++-ts-mode`, `rust-ts-mode`, `lua-ts-mode`, `python-ts-mode`, `js-ts-mode`,
   `typescript-ts-mode`, and `tsx-ts-mode`, insert a fixed representative
   snippet, call `font-lock-ensure`, and assert the actual face and effective
   attributes for every syntax category emitted by that snippet. Include a
   level-4 function call, operator, bracket, delimiter, and property case in
   every language where the built-in mode defines that capture. Assert
   `treesit-font-lock-level` is `4`. A missing pinned grammar is a test failure,
   not a skip.
4. Add a Markdown Tree-sitter token case using the pinned `markdown` and
   `markdown-inline` grammars. Assert heading, emphasis, link, list, table,
   quote, fenced code, inline code, and delimiter faces before checking classic
   Markdown fallback parity.
5. Add one data-driven package coverage test that requires the configured
   packages and checks the representative parent face for each mapping family:
   Markdown, Markdown Tree-sitter, Org, Agenda, Org Roam, Org Ref, Magit, Git
   commit/rebase, Dape, Consult, Embark, Which Key, Evil, Dired, and Gptel.
6. In the package coverage test, verify Nim, Odin, PHP, and Zig only after all
   authoritative Tree-sitter token cases pass. These checks validate fallback
   parity and may not weaken or replace the Tree-sitter assertions.
7. Add one Ghostel palette test that requires `ghostel`, verifies
   `ghostel-default`, cursor inheritance, all 16 `ghostel-color-*` effective
   foreground and background values, exact ANSI inheritance, palette vector
   order, and unchanged `ghostel-bold-color` value `nil`. Requiring `ghostel`
   performs Ghostel's normal nonfatal attempt to load an already-installed
   native module. The test must not require that attempt to succeed, start a
   terminal, download a module, or build a module.
8. Test effective face behavior. Do not test for source text, declaration
   existence, line counts, or literal theme-file contents.

### Execution-time face inventory

Before finalizing the theme, start Emacs 31.1 with the configured package
directory, require every feature represented in the Complete face contract,
and enumerate its runtime `face-list`. Classify every applicable face with one
of these outcomes in the implementation review:

1. Explicit face attributes in `mig-zenbones-light`.
2. Explicit inheritance in `mig-zenbones-light` to a face whose final
   attributes are specified in this plan.
3. Intentionally retained upstream inheritance, documented in the no-op list
   above because the package exposes no independent color role.

Do not leave a discovered configured-package face unclassified. If the
installed package revision contains a face not named in this plan, stop the
phase, inspect that face's upstream definition and use, add its exact semantic
parent and attributes to this plan, then implement it. Do not make an ad hoc
mapping or introduce a new palette role during implementation.

The inventory must explicitly require lazily loaded face modules, including
`magit-reflog`, `magit-sequence`, `magit-blame`, `magit-bisect`, `git-commit`,
`git-rebase`, `consult-imenu`, `org-ref-citation-links`,
`org-ref-glossary`, `org-ref-label-link`, `org-ref-ref-links`,
`org-roam-mode`, `org-roam-overlay`, and `org-roam-dailies`. Requiring only the
top-level Magit, Consult, Org Ref, or Org Roam feature is insufficient.

### Automated commands

The validation environment must already be provisioned by the existing
`profiles/common/.config/emacs/install-packages.el` and
`profiles/common/.config/emacs/install-tree-sitter-grammars.el` scripts. This
is a test precondition, not a request to change package pins or grammar pins.
If a configured package such as `diff-hl` or a pinned grammar is missing, stop
validation and provision the environment with those existing scripts before
rerunning the suite. Do not skip the dependent test.

Run from the repository root:

```sh
emacs -Q --batch -l profiles/common/.config/emacs/init.el \
  --eval '(princ "CONFIG_LOADED\n")'

emacs -Q --batch \
  -l profiles/common/.config/emacs/appearance-test.el \
  -f ert-run-tests-batch-and-exit

for test_file in \
  profiles/common/.config/emacs/diff-hl-integration-test.el \
  profiles/common/.config/emacs/leader-bindings-test.el \
  profiles/common/.config/emacs/markdown-parity-test.el \
  profiles/common/.config/emacs/my-file-picker-test.el \
  profiles/common/.config/emacs/my-org-datetree-test.el \
  profiles/common/.config/emacs/send-text-targets-test.el
do
  emacs -Q --batch \
    -L profiles/common/.config/emacs \
    --eval '(progn (require (quote package)) (package-initialize))' \
    -l "$test_file" \
    -f ert-run-tests-batch-and-exit || exit 1
done

emacs -Q --batch \
  --eval '(progn
             (find-file "profiles/common/.config/emacs/themes/mig-zenbones-light-theme.el")
             (check-parens))'

git diff --check
```

Byte-compile into a temporary directory, never beside the source files:

```sh
compile_dir=$(mktemp -d)
trap 'rm -rf "$compile_dir"' EXIT
emacs -Q --batch \
  -l profiles/common/.config/emacs/init.el \
  --eval "(setq byte-compile-dest-file-function
                (lambda (source)
                  (expand-file-name
                   (concat (file-name-nondirectory source) \"c\")
                   \"$compile_dir\")))" \
  -f batch-byte-compile \
  profiles/common/.config/emacs/init.el \
  profiles/common/.config/emacs/themes/mig-zenbones-light-theme.el \
  profiles/common/.config/emacs/appearance-test.el
```

If batch Emacs cannot resolve package faces before packages are initialized,
the command is incorrect. Do not accept unresolved package or face warnings,
weaken assertions, or skip configured package families. Existing unrelated
warnings from loading `init.el` are allowed only when they were captured before
implementation and the command still exits successfully.

### Manual visual matrix

Open one representative buffer for each row and compare it with the exact face
contract rather than subjective similarity:

| Surface | Required sample |
| --- | --- |
| Core editing | Region, cursor line, relative line numbers, matching paren, isearch |
| C and C++ Tree-sitter | Comment, string, number, type, declaration, function call, variable, property, keyword, operator, bracket, delimiter, punctuation |
| Rust Tree-sitter | Comment, string, number, type, macro, declaration, function call, variable, property, keyword, operator, bracket, delimiter |
| Lua and Python Tree-sitter | Comment, string, number, declaration, function call, variable, property, keyword, operator, bracket, delimiter |
| JavaScript, TypeScript, and TSX Tree-sitter | Comment, string, regexp, number, type, declaration, function call, variable, property, keyword, operator, bracket, delimiter, JSX tag, JSX attribute |
| Fallback language mode | Nim, Odin, PHP, and Zig samples after Tree-sitter verification passes |
| Markdown | Same document in `markdown-ts-mode`, `markdown-mode`, and `gfm-mode` |
| Org | Eight heading levels, all TODO states, tags, block, table, link, citation |
| Agenda | Today, weekend, scheduled, overdue, deadline, done, active filter |
| Magit | Status plus highlighted added, changed, removed, context, and hunk headings |
| Git commit/rebase | Summary warning, comments, trailers, active and killed actions |
| Completion | Native completion, Consult match/preview, Embark collect, Which Key |
| Diagnostics | Flymake error/warning/note, Eglot hint, Xref result, Dape source line |
| Gptel | Context, deletion, and rewrite highlights |
| Ghostel | Default text, selection, cursor, normal ANSI, bright ANSI, live theme reload |

### Final success criteria

- All automated commands pass under Emacs 31.1+.
- The active Neovim and Emacs default, syntax, UI, diagnostic, diff, and ANSI
  roles match the pinned Zenbones light source values.
- Native Tree-sitter fontification at level 4 is the verified primary syntax
  color path for every configured programming `*-ts-mode` and for Markdown
  when its two grammars are available.
- Language-specific theme faces are limited to required mode-emitted faces and
  preserve the shared Tree-sitter semantic palette as fallback coverage.
- Every configured major-mode and package surface in this plan has either an
  explicit mapping or an explicit inheritance decision.
- No One Light colors, commentary, theme symbol, load call, or test reference
  remains in the tracked Emacs configuration.
- No external Ghostty config, new package dependency, runtime color hook, or
  compatibility alias is introduced.
- Existing font, completion, keybinding, Org workflow, Magit workflow, Eglot,
  Dape, Markdown dispatch, and Ghostel input behavior remain unchanged.
- The implementation preserves the pre-existing dirty-worktree baseline and
  adds only intended theme, configuration, test, and plan diffs. At plan
  authoring time the unrelated untracked baseline is `.#README.md`,
  `.#test.org`, `.nvimlog`, `nvim.log`, and
  `dev/plans/6-emacs-md-and-org-alignment-followups.md`; do not modify or remove
  those files. Capture the baseline again before Phase 1 in case the user has
  added more worktree changes.
