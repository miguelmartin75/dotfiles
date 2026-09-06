# Emacs Refinement

## Status

- Overall: in progress, 2/6 phases complete
- Current phase: Phase 3
- Commit policy: one new Git commit after each accepted phase

Phase status:

- Phase 1: complete
- Phase 2: complete
- Phase 3: in progress
- Phase 4: pending
- Phase 5: pending
- Phase 6: pending

## Goal

Make the common Emacs profile's search, file discovery, Markdown editing,
terminal entry points, typography, and prose colors behave predictably without
replacing the established Consult plus native `*Completions*` architecture.

The resulting configuration must make `#` ordinary input in Consult searches,
preserve editable minibuffer input while selecting candidates, provide a local
fzf-ranked `C-p` file picker, record accepted file visits in Evil's jump list,
make Markdown nested-list editing match the stated contract, open terminals at
the requested scope, and render readable scaled and colored prose.

## Current Codebase Context

- `profiles/common/.config/emacs/init.el` owns package configuration, global
  keys, native completion settings, Markdown mode setup, writing mode, and
  theme loading.
- `profiles/common/.config/emacs/my-file-picker.el` owns hierarchical,
  recursive, project, and TRAMP file selection.
- `profiles/common/.config/emacs/my-send-text.el` owns direct Ghostel split
  creation and terminal-send targets. `my-window-layouts.el` owns durable
  project and task-scoped terminal layouts.
- `profiles/common/.config/emacs/themes/mig-zenbones-light-theme.el` owns all
  shared faces for Markdown, Org, line numbers, and the mode line.
- `dev/plans/emacs-completion-refinment.md` establishes the retained native
  completion contract. This plan changes only the explicitly requested C-p
  path; it does not enable `ivy-mode` globally.

## Decisions

1. Keep Consult, Embark, and native `*Completions*` as the common completion
   system. Do not add Vertico, Corfu, Company, Orderless, Marginalia, or a
   global Ivy mode.
2. Use Counsel only as the local `C-p` adapter because `counsel-fzf` provides
   the requested fzf ranking. Declare Ivy and Counsel in the provisioner, but
   invoke Ivy only inside that command. Remote C-p continues to use the
   existing Consult file picker.
3. Preserve the current all-files discovery policy for local C-p: `fd` lists
   regular files, includes hidden and ignored paths, follows links, and omits
   `.git`. Keep `SPC f F` bound to the existing Consult all-files picker.
4. Keep normal and visual Markdown `TAB` and `C-i` as Evil forward jump. Add
   list indentation only in Markdown insert state. Preserve native table and
   code-block keymaps through their higher-priority context maps.
5. A second `RET` on an empty nested Markdown item promotes it one level. A
   top-level empty item retains the existing exit and deletion behavior.
6. Cmd+J means the exact current buffer `default-directory`, not a normalized
   project root. Cmd+A opens the existing task-scoped coding-agent layout.
7. Writing-mode line counters must scale with writing text. The theme must
   retain default-face inheritance for gutter line numbers, and headings must
   use a restrained hierarchy shared by Markdown, Org, and Outline faces.

## Dependency Graph

```text
Phase 1 native completion contract
  -> Phase 2 fzf file picker and accepted-file jump contract

Phase 3 Markdown list editing
Phase 4 terminal entry points
Phase 5 writing typography and prose palette
  -> Phase 6 aggregate validation
```

Phases 3 through 5 are independent after Phase 1, but are executed serially
to keep each commit focused and reviewable.

## Phase 1: Repair Consult and Native Completion Behavior

### Changes

1. In `profiles/common/.config/emacs/init.el`, set
   `consult-async-split-style` to `nil`. This removes Consult's default Perl
   splitter, where `#query#filter` has a special async-query meaning.
2. Restore `minibuffer-completion-auto-choose` to `nil` so existing C-n and
   C-p minibuffer bindings move candidate selection without replacing the
   input text.
3. Remove the global `consult-preview-at-point-mode` completion-list hook.
   Consult commands retain their own source preview state, while normal
   candidate lists stay visible and usable.
4. Bind `S-<return>` in `minibuffer-local-map` to literal minibuffer
   submission. It must create a file or buffer for non-require-match prompts
   without accepting a highlighted near match. Require-match prompts retain
   their normal validation.
5. Update `appearance-test.el` to assert the corrected native completion
   contract rather than the later auto-insertion and global-preview behavior.

### Success Criteria

- `#` is searched literally by `SPC s g` and the existing Consult file picker.
- C-n and C-p keep focus and editable text in the minibuffer while moving the
  selected completion.
- Grep candidates remain visible without globally previewing the first one.
- Shift-RET submits literal text only where Emacs permits literal input.

### Implementation Status

Completed 2026-09-06. Consult's async splitter is disabled, native completion
selection no longer auto-inserts candidates, and ordinary completion lists no
longer install global Consult preview. Shift-RET invokes `exit-minibuffer`.
Focused ERT coverage verifies the configuration and that C-n/C-p move a visible
native completion selection without changing the source input. Validation:
focused ERT 2/2, `check-parens`, and `git diff --check`.

## Phase 2: Add fzf File Discovery and Evil Jump Correctness

### Changes

1. Add `ivy` and `counsel` to `profiles/common/.config/emacs/install-packages.el`.
2. Add a local-only C-p command in `my-file-picker.el` that resolves the
   project/default root, calls `counsel-fzf` with that root, and retains the
   existing recursive Consult picker for TRAMP roots. Configure the fzf source
   to preserve the current `fd` all-files discovery policy.
3. Rebind global Evil normal and visual C-p to this command. Keep `SPC f F`
   on `my/find-file-recursive-root` as the explicit Consult all-files path.
4. Capture source point markers in each file-picker entry path. After, and
   only after, a successful cross-buffer file visit, record the source marker
   with public `evil-set-jump`. Canceled prompts must not create jumps.
5. Extend `my-file-picker-test.el` with local fzf routing, TRAMP fallback,
   accepted visit, canceled visit, and Evil C-o behavior coverage.

### Success Criteria

- Local C-p is fzf-ranked over the documented all-files universe.
- Remote C-p keeps the existing safe Consult and TRAMP behavior.
- C-x C-f, C-p, project-file selection, and picker toggles add an Evil jump
  only after a file is accepted; C-o returns to the exact source location.

### Implementation Status

Completed 2026-09-06. Local `C-p` invokes Counsel fzf with the retained
all-files `fd` universe, while remote roots retain the existing Consult path.
The picker records the caller marker only for successful cross-buffer visits,
including nested picker transactions. Focused coverage verifies local and
remote routing, command construction, canceled and same-buffer fzf actions,
and accepted hierarchical, recursive, and project visits. A real Evil jump
integration test verifies C-o returns to the exact source point and a canceled
visit leaves an isolated jump ring empty. Validation: `my-file-picker-test.el`
12/12, `check-parens`, and `git diff --check`.

## Phase 3: Restore Markdown Nested-List Editing

### Changes

1. Add Markdown insert-state TAB and S-TAB commands in `init.el`. In a list
   item, dispatch to public `markdown-ts-demote` and `markdown-ts-promote` or
   `markdown-demote` and `markdown-promote`. Outside a list, use ordinary
   indentation.
2. Bind both ASCII and function-key Tab events in Markdown major-mode maps so
   table and fenced-code context maps retain their higher precedence.
3. Modify the custom Markdown return functions so an empty nested item on the
   second RET is promoted one level. Keep first-RET sibling creation, top-level
   exit, task-item handling, native tables, and code blocks intact.
4. Update `markdown-parity-test.el` with Tree-sitter and fallback nested-list
   indentation and double-RET examples, plus regression checks for normal
   TAB/C-i, tables, and fenced code.

### Success Criteria

- Insert TAB/S-TAB changes a Markdown list item's nesting in both modes.
- Normal and visual TAB/C-i remain Evil jump-forward.
- Two RET presses after a nested item create one parent-level empty sibling;
  top-level empty-list exit remains unchanged.

## Phase 4: Add CWD and Agent Terminal Entry Points

### Changes

1. Add a reusable Ghostel command for the exact `default-directory`. It must
   reuse a live terminal for that exact directory, create one in the existing
   right-side split when absent, select its window, and save its send target.
   Keep this cache separate from the tab-local project-layout terminal target.
2. Add a focused wrapper for the existing `my/work-codex` task-scoped agent
   layout that selects the companion terminal after it is rendered.
3. Bind Cmd+J to the CWD terminal and Cmd+A to the agent terminal globally and
   in Ghostel input maps, including char mode where global bindings do not win.
4. Bind `SPC f y` to `copy-current-file-path`.
5. Extend terminal, layout, and leader-key tests for reuse, exact directory
   scope, task-scoped agent selection, Ghostel maps, and the path-copy key.

### Success Criteria

- Cmd+J reopens the terminal associated with the exact local or TRAMP CWD.
- Cmd+A reopens the current workspace/task coding-agent terminal and selects it.
- Shell-mode, Babel, and DAPE remain intentionally line-oriented; no global
  terminal replacement occurs.
- `SPC f y` copies a visited file's absolute path.

## Phase 5: Align Writing Typography and Prose Colors

### Changes

1. Restore `line-number` inheritance from `default`, with
   `line-number-current-line` inheriting from `line-number`, so buffer-local
   text scaling reaches the gutter.
2. Add a buffer-local mode-line scaling remap controlled by the existing
   writing-mode and text-scale lifecycle. It must be removed by code/default
   mode and must not change unrelated buffers.
3. Apply the same restrained level palette to classic Markdown headings,
   Tree-sitter Markdown headings, Org levels, and Outline levels. Keep markup
   delimiters muted and preserve all non-heading semantic faces.
4. Extend `appearance-test.el` with face-inheritance, scaled-gutter,
   scaled-writing-mode modeline, Markdown level, and Org level assertions.

### Success Criteria

- Gutter and writing-mode line counters use the active text scale.
- Markdown and Org headings have visible, level-consistent color hierarchy in
  Tree-sitter and fallback rendering.
- Existing code, link, list, table, and inline-code face contracts remain
  unchanged.

## Phase 6: Integrated Verification and Closeout

### Changes

1. Run the focused ERT files for completion, file picker, Markdown, layout,
   leader bindings, and appearance, followed by the repository's retained
   Emacs batch checks.
2. Run `check-parens` and `git diff --check`.
3. Provision the declared `markdown-table-wrap-pretty` package when needed so
   Markdown test startup matches a normal deployment. Do not treat a missing
   local package checkout as a configuration behavior failure.
4. Perform a graphical macOS smoke test of C-p, `SPC s g`, C-x C-f then C-o,
   Markdown list editing, Cmd+J, Cmd+A, and `SPC Z`.
5. Mark this plan complete only after every phase's success criteria have direct
   validation evidence.

### Success Criteria

- All focused automated checks pass in a provisioned environment.
- Manual GUI behavior confirms every user-facing key and rendering contract.
- Every phase is marked complete and committed separately.
