# Emacs appearance and completion implementation plan

## Reasoning

The text-size mismatches share a face-inheritance cause, not a buffer-layout
cause. The configuration sets `default` to JetBrains Mono but leaves
`fixed-pitch` on the generic `Monospace` family. Both Emacs 31
`markdown-ts-mode` and package `markdown-mode` derive inline code from a
fixed-pitch face, so equal nominal sizes can still render with different glyph
metrics. Make the repo theme's `fixed-pitch` face inherit `default`, then keep
both inline-code faces at relative height `1.0`.

Eglot's built-in inlay base face uses height `0.8`. Override only that base
face to height `1.0`; its type and parameter faces already inherit from it.

The native completion block already owns the requested sizing variable.
`completions-max-height` is a maximum, and changing it from 10 to 14 is enough.
No display-buffer policy, advice, or resizing hook is needed.

This plan is independently implementable. It changes no leader maps,
line-number defaults, workspaces, layouts, terminal state, Gptel state, or
Magit behavior.

## Goals

- Render Eglot inlay hints at the same relative text height as source text.
- Render backtick-delimited Markdown inline code with the same font metrics as
  surrounding text in built-in and package Markdown modes.
- Raise the maximum `*Completions*` window height from 10 to 14 while retaining
  eager, one-column native completion.

## Status

- Plan: complete
- Implementation: in progress
- Target: Emacs 31.1+
- Primary configuration: `profiles/common/.config/emacs/init.el`
- Theme: `profiles/common/.config/emacs/themes/mig-one-light-theme.el`
- Planned tests: `profiles/common/.config/emacs/appearance-test.el`

## Current behavior and root causes

### Eglot inlay hints

- Emacs 31.1 defines `eglot-inlay-hint-face` with height `0.8` and inheritance
  from `shadow`. Type and parameter hint faces inherit that base.
- Eglot is configured at `profiles/common/.config/emacs/init.el:844`, but the
  face is not overridden.
- `profiles/common/.config/emacs/themes/mig-one-light-theme.el:58` styles
  `shadow` but not the Eglot inlay base face.

### Markdown inline code

- `profiles/common/.config/emacs/init.el:1107` prefers built-in
  `markdown-ts-mode` when its parsers are available, then falls back to package
  `markdown-mode` or `gfm-mode`.
- Built-in `markdown-ts-code-span` inherits `markdown-ts-code-block`, whose
  base is `fixed-pitch`. Package `markdown-inline-code-face` inherits
  `markdown-code-face`, whose base is also `fixed-pitch`.
- `profiles/common/.config/emacs/init.el:1455` sets `default` to JetBrains Mono
  at 13.5 points but does not bind `fixed-pitch` to it.
- `profiles/common/.config/emacs/themes/mig-one-light-theme.el:163` styles
  package Markdown faces but does not establish the shared font contract or
  style built-in `markdown-ts-code-span`.

### Completion height

- The native completion block at
  `profiles/common/.config/emacs/init.el:944` enables eager display, uses one
  column, and sets `completions-max-height` to 10 at
  `profiles/common/.config/emacs/init.el:955`.
- The variable controls the maximum `*Completions*` window height. Fewer
  candidates may legitimately use a shorter window.

## Decisions

1. Put appearance changes in the repo-owned theme.
2. Set `eglot-inlay-hint-face` to `:height 1.0` and preserve
   `:inherit shadow`. Do not duplicate the type and parameter faces.
3. Make `fixed-pitch` inherit the configured monospaced `default` face.
4. Set package `markdown-inline-code-face` and built-in
   `markdown-ts-code-span` to relative height `1.0`, preserving their existing
   inheritance, colors, and backgrounds.
5. Change `completions-max-height` directly from 10 to 14 in the existing
   native completion settings.
6. Preserve all existing mode dispatch, Eglot toggles, completion styles,
   navigation bindings, and eager one-column behavior.

## Preserved keybinding contract

This plan adds or removes no keybindings. The following existing bindings are
explicit regression boundaries:

| Key | Command | Required behavior |
| --- | --- | --- |
| `C-c e i` | `eglot-inlay-hints-mode` | Remains available in `eglot-mode-map` for buffer-local hint toggling. |
| `SPC c i` | `eglot-inlay-hints-mode` | Remains available from the normal and visual leader maps. |
| `TAB` in `*Completions*` | Existing completion navigation | Remains unchanged after the height adjustment. |
| `S-TAB` in `*Completions*` | Existing reverse completion navigation | Remains unchanged after the height adjustment. |
| `C-n` in `*Completions*` | Existing next-candidate navigation | Remains unchanged after the height adjustment. |
| `C-p` in `*Completions*` | Existing previous-candidate navigation | Remains unchanged after the height adjustment. |

## Alternatives rejected

- Enlarge only one Markdown face by an arbitrary amount: both Markdown
  implementations share the same fixed-pitch metric mismatch.
- Change the default face or text scale: the source text already has the
  desired metrics.
- Add mode hooks that mutate faces buffer-locally: the theme owns appearance
  and should remain correct after reload.
- Add a `display-buffer-alist` entry or resizing hook for `*Completions*`: the
  native maximum-height variable already provides the exact contract.
- Force a 14-line minimum: the request is a maximum, and short candidate lists
  should remain compact.

## Phase 1: Normalize auxiliary text metrics

Status: complete

### Changes

1. Add `eglot-inlay-hint-face` beside the core and syntax faces in
   `profiles/common/.config/emacs/themes/mig-one-light-theme.el:48`.
2. Set it to `:inherit shadow` and `:height 1.0`.
3. Add `fixed-pitch` beside `default` and make it inherit `default`.
4. Add `:height 1.0` to the existing `markdown-inline-code-face` entry while
   retaining its current inheritance and visual styling.
5. Add `markdown-ts-code-span` with `:height 1.0` and its upstream
   `markdown-ts-code-block` and `font-lock-constant-face` inheritance.
6. Do not change Markdown mode selection, Tree-sitter fontification, Eglot
   mode setup, or existing toggles.

### Success criteria

- The effective Eglot inlay hint height is `1.0` after loading or reloading
  `mig-one-light`.
- Type and parameter hints match normal glyph height while retaining the
  subdued `shadow` color.
- Inline code has effective relative height `1.0` and the same JetBrains Mono
  family as surrounding text in `markdown-ts-mode`, `markdown-mode`, and
  `gfm-mode`.
- Inline code retains the theme's existing foreground, background, and markup
  behavior before and after `text-scale-adjust`.
- Other fixed-pitch content remains monospaced and follows the configured
  default font metrics.

### Implementation results

- Added the shared face inheritance and height overrides in
  `profiles/common/.config/emacs/themes/mig-one-light-theme.el`.
- Batch inspection confirmed `fixed-pitch` inherits `default`,
  `eglot-inlay-hint-face` inherits `shadow` at height `1.0`, and
  `markdown-ts-code-span` retains both upstream parents at height `1.0`.
- Theme `check-parens` and `git diff --check` passed.

## Phase 2: Raise the native completion maximum

Status: pending

### Changes

1. Change `completions-max-height` from 10 to 14 at
   `profiles/common/.config/emacs/init.el:955`.
2. Preserve eager display, eager updates, one-column formatting, category
   styles, and completion navigation.
3. Do not add a global display rule, advice, or a resize hook.

### Success criteria

- More than 14 candidates produce a `*Completions*` window no taller than 14
  lines.
- Fewer candidates may produce a shorter window.
- Completion remains eager and one-column.
- `TAB`, `S-TAB`, `C-n`, and `C-p` retain their current behavior.

## Phase 3: Verify the independent appearance change

Status: pending

### Automated verification

Add a small behavior-focused ERT suite at
`profiles/common/.config/emacs/appearance-test.el`. Group assertions into
three tests:

1. effective Eglot base, type, and parameter hint face height and inheritance;
2. effective fixed-pitch and inline-code family, height, inheritance, and
   text-scale behavior in both Markdown implementations;
3. native completion maximum height and unchanged eager one-column settings.

Do not add tests that search source text for declarations.

Run:

```sh
emacs -Q --batch -l profiles/common/.config/emacs/init.el \
  --eval '(princ "CONFIG_LOADED\n")'

emacs -Q --batch \
  -l profiles/common/.config/emacs/appearance-test.el \
  -f ert-run-tests-batch-and-exit

emacs -Q --batch \
  --eval '(progn (find-file "profiles/common/.config/emacs/themes/mig-one-light-theme.el") (check-parens))'

git diff --check
```

Byte-compile `init.el`, `mig-one-light-theme.el`, and the focused test into a
temporary directory so generated files do not enter the profile.

### Manual verification

1. Start Eglot in a server-backed source buffer, enable inlay hints, and
   compare their glyph height with source text before and after text scaling.
2. Open the same backtick-delimited sample in `markdown-ts-mode` and
   `markdown-mode` or `gfm-mode`. Compare font family, height, foreground, and
   background before and after text scaling.
3. Invoke native completion with more than 14 one-column candidates, then with
   a shorter list. Confirm the maximum and compact behavior and exercise all
   four preserved navigation keys.

### Final success criteria

- Both reported text-size mismatches are removed by stable theme inheritance,
  not buffer-local compensation.
- `*Completions*` uses a 14-line maximum and retains its current interaction.
- No keybinding, layout, workspace, terminal, Gptel, Magit, or line-number
  behavior changes.
- Startup, ERT, byte compilation, `check-parens`, and `git diff --check` pass.
- Phase statuses and measured results are recorded in this file during
  implementation.
