# Align Org and Markdown Editing in Emacs

## Status

Plan status: in progress.

Implementation status:

- Phase 1: complete
- Phase 2: complete
- Phase 3: complete
- Phase 4: in progress

## Goal

Make Markdown and Org files feel alike for structural editing, folding,
focusing, tables, and sending code to a Ghostel terminal, without replacing
Org's native Babel workflow.

The primary Markdown mode is `markdown-ts-mode`, because
`treesit-ready-p` now reports that both the `markdown` and
`markdown-inline` grammars are installed. The configuration must retain a
consistent fallback for `markdown-mode` on hosts where those grammars are not
available.

## Relevant Code

- `profiles/common/.config/emacs/init.el:647` selects and configures the
  Markdown modes.
- `profiles/common/.config/emacs/init.el:669` enables Markdown Tree-sitter
  parser tools, `outline-minor-mode`, and hideshow.
- `profiles/common/.config/emacs/init.el:730` selects `markdown-ts-mode` for
  `.md` files when the grammars are ready.
- `profiles/common/.config/emacs/init.el:828` configures Org Babel languages.
- `profiles/common/.config/emacs/init.el:901` enables `evil-org-mode`.
- `profiles/common/.config/emacs/init.el:947` enables `org-autolist`.
- `profiles/common/.config/emacs/init.el:963` configures Ghostel and loads
  the generic text sender.
- `profiles/common/.config/emacs/init.el:1259` defines the current Org and
  terminal leader bindings.
- `profiles/common/.config/emacs/init.el:1333` defines visual-state terminal
  send bindings.
- `profiles/common/.config/emacs/my-send-text.el:47` implements Ghostel
  bracketed-paste delivery.
- `profiles/common/.config/emacs/my-send-text.el:227` implements sending the
  active region or accessible buffer.
- `profiles/common/.config/emacs/leader-bindings-test.el` tests effective
  leader bindings.
- `profiles/common/.config/emacs/send-text-targets-test.el` tests target
  selection and replay behavior.
- `dev/plans/5-emacs-global-keybindings-ghostty-escape-hatch.md` is the
  closest existing plan and test convention.

## Current Behavior and Gaps

Org already supplies context-sensitive structural editing through
`evil-org-mode`: `M-j` and `M-k` move headings, list items, and table rows;
`M-h` and `M-l` promote or demote headings and list items, and move table
columns. Org also exposes `g TAB` folding, `C-x n s` subtree focus, native
table editing, and Babel evaluation at `SPC o RET`.

Markdown Tree-sitter has the underlying features but exposes them unevenly:

- `M-<up>`, `M-<down>`, `M-<left>`, and `M-<right>` natively move or
  promote headings and list items. In a Markdown table, they move rows and
  columns.
- Its active `outline-minor-mode` captures `M-j` and `M-k`, making them
  heading-only. `M-h` and `M-l` are also heading-only rather than
  context-sensitive.
- Markdown table commands exist, including row and column insertion,
  deletion, alignment, and traversal, but raw `TAB` and `RET` in Evil normal
  state are intentionally claimed by Evil. They are not as discoverable as
  their Org counterparts.
- Markdown has no built-in equivalent to Org Babel evaluation or result
  insertion. The generic Ghostel sender can send a visual selection, but it
  does not identify a fenced code block.

The historical configuration at `fbee7f8` had no Markdown parity layer,
Ghostel sender, or Markdown code execution. It relied on the older
`markdown-mode` defaults such as `C-c <up>` and `C-c <down>` for movement;
there is no previous behavior to preserve beyond the general Markdown
fallback.

## Decisions

1. Standardize the primary structural chords on `M-h`, `M-j`, `M-k`, and
   `M-l` in Evil normal and visual states. They will be context-sensitive in
   both Org and Markdown: promote, move down, move up, and demote for
   headings and list items; move columns and rows in tables.
2. Keep the native `M-<arrow>` Markdown bindings as documented alternatives.
   They already provide the same operations and should not be replaced.
3. Preserve raw `TAB` and `C-i` in Evil normal state. `C-i` is the existing
   Evil forward-jump key, so changing raw `TAB` would be a global navigation
   regression. Add `g TAB` and `g S-TAB` as Markdown's normal-state folding
   and table-traversal entry points, matching the Org convention.
4. Keep Org Babel as in-process evaluation and do not add a Markdown Babel
   result-insertion layer. Markdown code execution will send the entire
   fenced code body to the selected Ghostel target. This is explicit,
   language-agnostic, and uses the existing terminal-selection contract.
5. Use one Markdown parity layer shared by `markdown-ts-mode` and the
   `markdown-mode` fallback. It must dispatch to the appropriate public API
   for the active mode, instead of relying on Tree-sitter-only behavior.

## Verified API constraints

- Emacs 31 provides public Tree-sitter structural, table, outline, and generic
  Tree-sitter node APIs, but no public `markdown-ts-narrow-to-subtree` or fenced
  code body range command. Tree-sitter narrowing must use public outline
  boundaries, and fenced code extraction must use public `treesit-*` node APIs.
- Classic `markdown-mode` has public context-sensitive structure commands and
  `markdown-narrow-to-subtree`. Its fenced construct APIs identify the bounded
  construct, after which a fence-only scan can extract the body.
- Classic `markdown-mode` does not provide native `M-S-<arrow>` table bindings.
  Its documented table insertion/deletion keys remain `C-c S-<arrow>`, while
  `markdown-ts-mode` keeps its native `M-S-<arrow>` bindings. The parity layer
  will not invent a shared direction contract that upstream does not provide.
- Explicit fenced-body delivery can call `my/send-text-to-target` for target
  selection and `my/send-text-send-to-last-target` for replay. The interactive
  region-or-buffer commands do not accept explicit bounds and do not need to be
  refactored.

The viable alternative is to use Markdown's native `M-<arrow>` bindings only
and document the differences. That would leave the requested `M-j` and
`M-k` workflow inconsistent because `outline-minor-mode` wins over a direct
major-mode Evil binding. A mode-local parity layer is the durable solution.

## Target Keybinding Contract

| Group | Org | Markdown after this plan | Notes |
| --- | --- | --- | --- |
| Headings | `M-j`/`M-k` move, `M-h`/`M-l` promote/demote | Same | Markdown uses Tree-sitter commands when available. |
| Lists | `M-j`/`M-k` reorder, `M-h`/`M-l` change nesting | Same | Ordered-list nesting remains subject to Markdown syntax support. |
| Fold or unfold | `g TAB`, `g S-TAB`; Evil `za`/`zc`/`zo`/`zO` | Same | In a table, `g TAB` and `g S-TAB` traverse cells instead. |
| Focus current section | `C-x n s`; `C-x n w` restores | Same | Markdown uses its mode-specific narrow command. |
| Move within a table | `M-h`/`M-l` columns, `M-j`/`M-k` rows | Same | Native Markdown `M-<arrow>` remains available. |
| Add or remove table rows and columns | `M-S-<arrow>` | Tree-sitter: native `M-S-<arrow>`; fallback: native `C-c S-<arrow>` | Preserve each upstream mode's documented directions. |
| Align/recalculate table | `SPC o t` | `C-c C-c` in a table and a Markdown leader alias | Org retains recalculation; Markdown aligns its pipe table. |
| Evaluate or run code at point | `SPC o RET` invokes Babel | `SPC o RET` sends fenced code to Ghostel | Markdown execution does not insert results. |
| Send selected text | Visual `C-c C-c` | Visual `C-c C-c` | Existing generic terminal sender remains unchanged. |
| Choose or replay terminal send target | `SPC t R` / `SPC t r` | Same | Existing cross-mode contract remains unchanged. |

## Phase 1: Add a Markdown Structural Parity Layer

Status: complete.

1. In `profiles/common/.config/emacs/init.el`, add public interactive
   Markdown commands for move-up, move-down, promote, and demote.
2. Each command must dispatch on the active Markdown implementation:

   - In `markdown-ts-mode`, use the `markdown-ts-*` structural APIs. When
     point is in a table, call the matching table row or column movement API.
   - In fallback `markdown-mode`, call its context-sensitive structural API
     such as `markdown-move-up`, `markdown-move-down`, `markdown-promote`,
     and `markdown-demote`.

3. Add a single Markdown setup function called from both Markdown hooks.
   It must use `evil-local-set-key` (or the equivalent buffer-local
   state-map API) to bind the four commands in normal and visual states.
   This is required because a binding installed only in
   `markdown-ts-mode-map` loses to `outline-minor-mode` at runtime.
4. Keep the existing parser and hideshow configuration in
   `my/parser-tools-mode`; extend it rather than duplicating the
   Tree-sitter setup elsewhere.
5. Do not modify Org's `evil-org-mode` bindings. The Org behavior is the
   reference contract.

Success criteria:

- In a Tree-sitter Markdown buffer, `M-j` and `M-k` reorder adjacent
  headings and adjacent list entries.
- In a Markdown table, the same keys move rows and `M-h`/`M-l` move columns.
- In a fallback `markdown-mode` buffer, all four bindings remain available
  and operate on Markdown structure.
- Org keybindings are unchanged.

### Implementation record

Completed: 2026-09-02.

- Added four public context commands and one shared setup hook. Tree-sitter
  Markdown dispatches tables to the public table movement commands and other
  structure to the public heading/list commands; fallback Markdown delegates
  to its four public context commands.
- Focused Tree-sitter checks exercised adjacent headings, list entries, table
  rows and columns, and effective normal/visual local bindings. All passed with
  the installed Markdown grammars.
- Focused fallback checks exercised headings and all four list operations after
  fontification. The observed results moved sibling items, promoted a nested
  item, and demoted an item beneath its preceding sibling. The setup installed
  all four normal/visual local bindings.
- `check-parens` and `git diff --check` completed successfully. Org
  `evil-org-mode` configuration was not changed.

## Phase 2: Align Folding, Focus, and Table Access

Status: complete.

1. Add a Markdown context command for `g TAB`:

   - In a table, advance to the next cell.
   - Elsewhere, cycle the current Markdown heading's visibility.

2. Add a Markdown context command for `g S-TAB`:

   - In a table, move to the previous cell.
   - Elsewhere, cycle buffer-wide heading visibility.

3. Bind both commands buffer-locally in Markdown Evil normal and visual
   states. Keep raw `TAB` and `C-i` untouched and retain Evil's standard
   fold commands as alternatives.
4. Add a Markdown subtree-focus command on `C-x n s`, dispatching to the
   applicable Tree-sitter outline or classic Markdown narrowing API. Leave
   `C-x n w` as the standard `widen` binding.
5. Bind a Markdown table-alignment command under the existing `SPC o`
   leader namespace, using a currently free mnemonic that does not conflict
   with Org's `SPC o t` recalculation binding. The command must reject
   non-table locations with a useful user error. Keep native `C-c C-c` table
   alignment intact.
6. Preserve the real mode-specific table insertion/deletion bindings and
   document their directions in keybinding comments. Tree-sitter Markdown uses
   native `M-S-<arrow>` bindings; fallback `markdown-mode` uses native
   `C-c S-<arrow>` bindings. Do not synthesize a cross-mode remap or swap
   commands behind the user's back.

Success criteria:

- `g TAB` and `g S-TAB` fold Markdown headings and traverse a Markdown table
  in the expected direction.
- `C-x n s` narrows a Markdown heading subtree and `C-x n w` restores the
  full buffer.
- The new Markdown leader table command aligns a pipe table and does not
  shadow Org's table recalculation.
- Normal-state `TAB` still performs the existing Evil `C-i` behavior.

### Implementation record

Completed: 2026-09-02.

- Added public local-cycle, buffer-cycle, subtree-focus, and table-alignment
  commands. They dispatch only through the public APIs verified for each
  Markdown implementation and issue a user error for table alignment outside
  a table.
- Extended the shared Markdown setup with normal/visual `g TAB`, `g S-TAB`,
  `C-x n s`, and `SPC o m`. Focused checks confirmed raw normal-state `TAB`
  and `C-i` retain their existing Evil binding.
- A focused two-mode ERT harness passed 2/2 tests covering local heading
  folding, subtree narrowing and widening, table alignment, next/previous cell
  traversal, non-table alignment errors, and effective bindings.
- Upstream table mutation bindings remain unchanged and are documented in the
  setup: Tree-sitter uses `M-S-<arrow>`, while fallback Markdown uses
  `C-c S-<arrow>`.
- `check-parens` and `git diff --check` completed successfully.

## Phase 3: Send Fenced Markdown Code to Ghostel

Status: complete.

1. Extend `profiles/common/.config/emacs/my-send-text.el` with a public
   interactive command that obtains the fenced code block at point.
2. Use the current major mode's structural parser where available. For
   `markdown-ts-mode`, obtain the code-fence body from the Tree-sitter node;
   for fallback `markdown-mode`, locate the containing opening and closing
   fences with the mode's syntax-aware facilities or a bounded, fence-only
   scan. Exclude the fence delimiters and optional info string from sent
   text.
3. When point is not in a complete fenced code block, signal a clear user
   error. Do not silently send the current line, region, or entire file.
4. Pass only the extracted code body to
   `my/send-text-send-to-last-target`. Preserve the generic interactive
   region-or-buffer commands, bracketed paste, target picker, and replay rules.
5. Add a companion command that passes the same extracted body to
   `my/send-text-to-target`, using the same target-selection path as `SPC t R`.
6. Add Markdown-local leader bindings:

   - `SPC o RET`: replay the last target and send the fenced code block.
   - `SPC t B`: choose a target and send the fenced code block.
   - `SPC t b`: replay the last target and send the fenced code block.

   `SPC o RET` remains Org-only Babel evaluation outside Markdown. Do not
   overwrite the global selection sender or visual-state `C-c C-c`.

7. Document in the command docstrings that execution occurs in the target
   terminal's current shell or REPL, requires a suitable interpreter there,
   and does not write execution results back into the Markdown file.

Success criteria:

- A Markdown fenced block sends exactly its body, without backticks or the
  language annotation, through the existing Ghostel bracketed-paste path.
- The replay command uses the saved target and the choose command opens the
  existing target picker.
- A non-code location produces a useful error and sends nothing.
- Org `SPC o RET` continues to invoke `org-babel-execute-src-block`.

### Implementation record

Completed: 2026-09-02.

- Added public fenced-code extraction for Tree-sitter Markdown using only the
  enclosing `fenced_code_block` node's public children and
  `code_fence_content` bounds. Classic Markdown uses its public enclosing
  fenced-construct boundary followed by a bounded backtick-or-tilde fence scan,
  rejecting YAML, incomplete fences, and non-code locations.
- Added replay and choose-target commands that pass only the extracted body to
  the existing target APIs. Their docstrings document current shell or REPL
  execution, the required interpreter, and the absence of result insertion.
- Added normal/visual Markdown-local `SPC o RET`, `SPC t b`, and `SPC t B`
  bindings without changing Org Babel or visual selection delivery.
- Focused two-mode checks passed for backtick and tilde bodies, absent/YAML/
  incomplete errors, stubbed replay and target-choice dispatch, and effective
  Markdown, Org, and global bindings. `check-parens` and `git diff --check`
  completed successfully.

## Phase 4: Lock the Contract with Tests and Documentation

Status: in progress.

1. Extend `profiles/common/.config/emacs/leader-bindings-test.el`, or add a
   focused neighboring ERT file, to load the configuration and assert the
   effective local normal and visual bindings in both `markdown-ts-mode` and
   fallback `markdown-mode`.
2. Test the four structural bindings in headings, lists, and a pipe table.
   Check the buffer contents or table position after the command, not merely
   that a symbol is present in a keymap.
3. Test Markdown folding and narrowing using a heading fixture. Assert that
   `g TAB` dispatches to table traversal when point is in a table.
4. Extend `profiles/common/.config/emacs/send-text-targets-test.el` with
   fixtures for Tree-sitter and fallback fenced blocks. Assert that extracted
   text excludes both fences, preserves the body, and reports an error for
   incomplete or absent fences.
5. Add leader-binding tests proving mode-local Markdown `SPC o RET`,
   `SPC t b`, and `SPC t B` do not change the existing Org and generic
   terminal bindings.
6. Run the relevant Emacs batch ERT tests with the repository configuration,
   then manually verify raw input in a GUI or terminal Emacs session using
   `C-h k` for `TAB`, `g TAB`, `M-j`, and `M-S-<arrow>`. Raw key event
   translation differs between GUI and terminal Emacs, so this final check
   must exercise both environments used by the configuration.

Success criteria:

- Automated tests cover behavior in the Tree-sitter and fallback Markdown
  modes, not just static key declarations.
- Existing Org, Ghostel-target, and visual-selection tests still pass.
- Manual checks confirm the intended key events arrive in both supported
  Emacs front ends.

## Completion Criteria

The work is complete when an Org user can edit Markdown headings, lists, and
tables with the same primary structural chords; fold and focus Markdown with
the same normal-state entry points; and run the fenced code at point through
Ghostel using the established terminal target workflow. Org Babel remains
unchanged, and the fallback Markdown mode retains the same user-facing
contract when Tree-sitter grammars are unavailable.
