# Emacs in-buffer Git hunk workflow

## Status

- Overall: in progress, 2/4 phases complete
- Current phase: Phase 3
- Scope: local and TRAMP file buffers, Git working-tree review, and queued
  annotations sent through the existing target transport

## Goal

Show edits made on disk by a coding agent inside an existing Emacs server,
mark unstaged Git hunks in the source buffer, and provide a compact review loop
for navigation, preview, stage, revert, annotation, and explicit delivery to a
coding agent.

The interaction should preserve the high-frequency Neovim bindings at
`profiles/common/.config/nvim/init.lua:195-216`:

| Intent | Neovim | Emacs target | Meaning |
| --- | --- | --- | --- |
| Previous hunk | `[h` | `[h` | Move to the previous unstaged hunk |
| Next hunk | `]h` | `]h` | Move to the next unstaged hunk |
| Preview hunk | `SPC g p` | `SPC g p` | Show the current unified hunk inline |
| Stage hunk | `SPC g s` | `SPC g s` | Stage the current unstaged hunk |
| Revert hunk | `SPC g r` | `SPC g r` | Confirm, then discard the current working-tree hunk |
| Annotate hunk | none | `SPC g a` | Queue a note with source and patch context |
| View annotations | none | `SPC r v` | Open the thread-like annotation queue |
| Send annotations | none | `SPC r s` | Choose a target and send the complete queue |
| Repository Git UI | separate | `SPC g g` | Keep Magit authoritative |

`SPC g b` and `SPC g d` from Neovim remain outside this plan. Magit already
owns blame and arbitrary revision diffs, so duplicating them in source-buffer
glue would add no required capability.

## Decisions

1. Enable built-in `global-auto-revert-mode` so a clean visiting buffer picks
   up an external coding-agent write. Never auto-revert a buffer with unsaved
   local edits.
2. Pin `diff-hl` version 1.11.1 at reviewed commit
   `3d9552c575fd14ac98ac97bf3c19cdef39f79305` with `package-vc`. This exact
   revision contains the inline overlay backend and the hunk action map.
3. Use `diff-hl` only for source-buffer Git hunk state and actions. Keep Magit
   responsible for repository state, staging review, unstage, history, and
   commits.
4. Set `diff-hl-show-staged-changes` to nil. The gutter then compares the
   working tree with the Git index, so staging a reviewed hunk removes its
   marker. Unstaging it in Magit makes it visible again.
5. Use `diff-hl-flydiff-mode` for unsaved live updates and the documented Magit
   refresh hook for index changes.
6. Keep the existing Difftastic package and Magit bindings unchanged at
   `profiles/common/.config/emacs/install-packages.el:28-36` and
   `profiles/common/.config/emacs/init.el:567-579`. Difftastic remains an
   optional structural diff view in its own buffer.
7. Extend the existing annotation queue at
   `profiles/common/.config/emacs/my-send-text.el:279-324`. Do not introduce a
   second queue, auto-send comments, or make the queue depend on a particular
   terminal or agent.
8. Keep the package's confirmation for direct hunk revert. Replace the inline
   preview's unsafe lowercase `r` action, which bypasses confirmation, with one
   owned interactive command that closes the preview and invokes the confirmed
   revert command.
9. Call `SPC g s` "stage hunk" in Which Key and documentation. Staging is a
   useful accept signal for a review pass, but it does not commit the change and
   must not be presented as a permanent agent-level acceptance operation.

## Built-in Emacs audit

The referenced article correctly identifies useful stock Emacs diff features,
but none supplies the complete source-buffer workflow.

| Built-in facility | Useful capability | Missing capability |
| --- | --- | --- |
| `global-auto-revert-mode` | Refreshes a clean visiting buffer after an external write | No Git baseline, gutter, or hunk actions |
| `highlight-changes-mode` | Highlights edits made since the mode was enabled and navigates those edits | Not Git or index aware, not a gutter, no hunk stage or Git revert |
| `vc-diff` and `vc-root-diff` | Produce a Git-aware unified diff | Open a separate `*vc-diff*` buffer instead of annotating the source buffer |
| `diff-mode` | Navigates, refines, applies, and reverse-applies hunks in a patch buffer | Its optional fringe indicators belong to the patch buffer, not the source file; no discrete Git index stage action |
| `vc-ediff` and Ediff | Provide interactive two-way comparison | Separate session, no live gutter or compact source-buffer action loop |
| `smerge-mode` | Navigates and resolves merge conflict markers | Handles conflicts only, not ordinary worktree hunks |
| `vc-gutter` | Not present in the installed Emacs 31.1 standard library | It is not a built-in alternative |

The built-in-only option therefore fails the goal. The least-hacky split is
built-in auto-revert for external writes, built-in VC as the diff substrate,
and external `diff-hl` for the missing source-buffer presentation and actions.

GNU ELPA stable currently advertises `diff-hl` 1.10.0. An ordinary unpinned
archive install would not lock the newer inline backend required by this plan.
The repository already has a deterministic `package-vc` contract in
`profiles/common/.config/emacs/install-packages.el:10-40`, so the reviewed pin
fits the existing provisioner.

## Component boundaries

```text
coding agent writes file
          |
          v
built-in global-auto-revert-mode
refreshes a clean visiting buffer
          |
          v
diff-hl compares working tree with Git index
          |
          +----------------------+----------------------+
          |                      |                      |
          v                      v                      v
    navigate/preview       stage or revert        annotate hunk
          |                      |                      |
          |                      v                      v
          |               Git index or buffer     my/annotations
          |                      |                      |
          +----------------------+                      v
                   |                              SPC r v review
                   v                                     |
             Magit refresh                               v
             updates signs                         SPC r s send
                                                         |
                                                         v
                                              explicit selected target
                                              zmx / buffer / Ghostel
                                                         |
                                                         v
                                                    coding agent
```

There is intentionally no data path from Difftastic into `diff-hl`:

```text
canonical unified diff                 Difftastic structural diff
          |                                      |
          v                                      v
line mapping, stage, revert              separate read-only view
and annotation patch context             for human inspection
```

Difftastic's inline display mode means a single-column structural diff in a
Difftastic output buffer. It is not a source-buffer overlay API, and its output
is not a patch format suitable for Git index mutations. The broader hosted
review plan at
`dev/plans/emacs-config-forge-github-and-gitlab-and-diff-support.md:350-373`
already preserves this same structural-versus-canonical boundary.

## Source-buffer UI

Colors come from the active theme. The letters below are an ASCII substitute
for graphical fringe or terminal margin markers.

```text
+-- profiles/common/.config/emacs/init.el -------------------------+
|    | 563 | ;; Development                                       |
| A  | 564 | (use-package diff-hl                                 |
| M  | 565 |   :init                                              |
| M  | 566 |   (global-diff-hl-mode 1))                           |
|    | 567 |                                                       |
| D  |     | <deleted lines are represented beside an anchor>     |
+------------------------------------------------------------------+
| [h previous   ]h next   SPC g p preview   SPC g s stage          |
| SPC g r confirm + revert   SPC g a annotate   SPC g g Magit      |
+------------------------------------------------------------------+

A = added line
M = modified line
D = deletion anchored between or beside surviving source lines
```

`SPC g p` opens the package's inline overlay without replacing the file
buffer:

```text
| M  | 565 |   (setq diff-hl-show-staged-changes nil)             |
|    | 566 |                                                       |
|    +-- Diff with HEAD -----------------------------------------+ |
|    | @@ -564,1 +564,2 @@                                      | |
|    | -(global-diff-hl-mode 1)                                 | |
|    | +(global-diff-hl-mode 1)                                 | |
|    | +(diff-hl-flydiff-mode 1)                                | |
|    +------------------------------------------------------------+ |
|    | q quit  p previous  n next  e Ediff  r confirm + revert   | |
|    | c copy original  S stage                                  | |
|    +------------------------------------------------------------+ |
```

The direct workflow remains usable without opening the preview:

```text
                    current unstaged hunk
                             |
             +---------------+----------------+
             |               |                |
          SPC g s          SPC g r          SPC g a
             |               |                |
             v               v                v
       stage into index    confirmation     note prompt
             |               |                |
             v               v                v
       marker disappears   revert buffer   queue annotation
             |               |                |
             |               |                v
             |               |            SPC r v
             |               |                |
             |               |                v
             |               |          inspect/edit/remove
             |               |                |
             +---------------+----------------+
                             |
                          continue
                         [h or ]h
```

## Annotation UI and data contract

`my/annotate-current-hunk` must reuse `my/annotations` and the delivery path in
`my/send-text-to-target`. It records both the current source snapshot and the
unified hunk from the pinned `diff-hl-show-hunk-buffer` contract. The patch is
required because a deletion-only hunk has no deleted source text left to select.

A hunk annotation adds these fields to the existing item shape:

- `:source`, `:start-line`, `:end-line`, `:mode`, `:annotation`, and `:text`
  retain their current meaning.
- `:patch` contains the unified current hunk for hunk annotations and is absent
  for ordinary region annotations.
- `:id` is a session-local stable identifier used by the review buffer for edit
  and delete actions.

`my/annotations-show` opens a read-only special-mode buffer. It is a visual
outbound review queue, not a synchronized two-way provider comment thread.
Agent replies remain in the selected target session.

```text
+-- *Review Annotations* ------------------------------------------+
| [1] init.el:564-566                         queued               |
|     Note: Keep Magit authoritative for unstage.                  |
|                                                                  |
|     @@ -564,1 +564,2 @@                                         |
|     -(global-diff-hl-mode 1)                                    |
|     +(global-diff-hl-mode 1)                                    |
|     +(diff-hl-flydiff-mode 1)                                   |
|                                                                  |
| [2] my-send-text.el:303-310                 queued               |
|     Note: Include the patch before the source snapshot.          |
+------------------------------------------------------------------+
| n/p item  RET source  e edit note  d delete  g refresh           |
| s send queue  q quit                                              |
+------------------------------------------------------------------+
```

Sending preserves the current behavior at
`profiles/common/.config/emacs/my-send-text.el:298-324`:

- prompt once for an optional overall request;
- preserve source order rather than the internal push order;
- include a fenced `diff` block when `:patch` is present;
- choose the target explicitly;
- clear the queue only after successful delivery;
- retain the complete queue when target selection or delivery fails.

## Safety and behavior contracts

- External writes refresh only clean visiting buffers. Unsaved user edits are
  never discarded to make an agent edit visible.
- `SPC g r` always asks before destructive hunk revert.
- Lowercase `r` in the inline preview also asks. The upstream preview command
  bypasses `diff-hl-ask-before-revert-hunk`, so the configuration must not leave
  that command bound directly.
- `SPC g s` stages only. Unlike the pinned Gitsigns behavior, it is not a
  stage/unstage toggle. Use `SPC g g` and Magit to unstage.
- Hunk navigation does not wrap and does not reproduce Gitsigns count,
  jumplist, fold-opening, or "Hunk X of Y" behavior. Preserve direct public
  `diff-hl` commands unless measured use demonstrates a need for wrappers.
- Difftastic never supplies line positions or patches for stage, revert, or
  annotation.
- The annotation queue never sends automatically after annotation, stage, or
  revert.
- Remote live refresh must be measured. Keep upstream TRAMP support enabled at
  first; disable `diff-hl` on remote buffers only if the Phase 4 latency check
  demonstrates an unacceptable recurring cost.
- Fringe conflicts with Flymake are a display concern, not a reason to own a
  new diff engine. Verify the actual theme first, then use the package's margin
  mode only if the conflict is material.

## Phase 1: Make external agent edits visible with live gutter state

Status: complete

### Changes

1. Add unconditional `diff-hl` package-vc metadata and reviewed commit
   `3d9552c575fd14ac98ac97bf3c19cdef39f79305` to the initial `vc-packages`
   value at `profiles/common/.config/emacs/install-packages.el:10-27`. Keep the
   conditional Difftastic append at `profiles/common/.config/emacs/install-packages.el:28-36`
   unchanged.
2. Enable `global-auto-revert-mode` in the core editing configuration of
   `profiles/common/.config/emacs/init.el`. Retain the built-in protection for
   modified buffers and do not enable automatic remote-file polling globally.
3. Add a deferred `use-package diff-hl` beside Magit at
   `profiles/common/.config/emacs/init.el:563-579`. Configure
   `diff-hl-show-staged-changes` nil and `diff-hl-ask-before-revert-hunk` t,
   enable `global-diff-hl-mode` and global `diff-hl-flydiff-mode`, and add
   `diff-hl-magit-post-refresh` to `magit-post-refresh-hook`.
4. Verify that the selected backend is
   `diff-hl-show-hunk-inline`. Do not add posframe or popup dependencies.
5. Use the package's default graphical fringe and terminal margin fallback.
   Do not add custom faces until the active theme has been checked.

### Verification

- Run the package provisioner twice in an isolated package directory. Confirm
  the first run installs the reviewed commit and the second performs no network
  or package write.
- Visit a clean tracked file in the running server, modify it through a separate
  process, and confirm Emacs refreshes the buffer and displays the correct
  unstaged markers without manual `revert-buffer`.
- Repeat while the buffer has unsaved local edits and confirm Emacs preserves
  them instead of applying the external write.
- Exercise added, modified, and deleted hunks before save, after save, after a
  Magit refresh, and after an external index update.
- Load the configuration without `difft` and confirm ordinary Magit and
  `diff-hl` still work.

### Success criteria

- Clean buffers show coding-agent writes automatically.
- Unsaved user edits are never overwritten.
- Tracked source buffers show live unstaged hunk state against the Git index.
- Package installation and startup remain deterministic and startup performs no
  package or network mutation.

### Implementation record

Completed: 2026-09-02

- `emacs --batch -Q --eval '<isolated package-vc install and commit assertion>'`
  installed `diff-hl` version 1.11.1 at
  `3d9552c575fd14ac98ac97bf3c19cdef39f79305`. Repeating the isolated
  descriptor assertion printed `DIFF_HL_REUSED
  3d9552c575fd14ac98ac97bf3c19cdef39f79305` without archive refresh or a
  package write. The isolated invocation set `project-list-file` inside the
  temporary package directory so `package-vc` did not write user project
  history.
- `emacs --batch -Q --eval '<diff-hl configuration assertions>'` printed
  `DIFF_HL_CONFIGURATION_OK backend=inline posframe=absent`, confirming the
  explicit inline renderer, unstaged-only state, confirmed revert setting,
  global gutter and flydiff modes, and Magit refresh hook.
- `emacs --batch -Q --eval '<clean and modified auto-revert exercise>'`
  printed `AUTO_REVERT_CLEAN_AND_MODIFIED_CONTRACT_OK
  remote-polling=disabled`: a clean visiting buffer refreshed after a file
  write, while a modified buffer retained its local edit.
- `emacs --batch -Q --eval '<check-parens for install-packages.el and init.el>'`
  printed `CHECK_PARENS_OK`. `git diff --check` completed without output, and
  the configuration contains no custom `diff-hl` faces, margin mode, or
  `posframe` dependency.

Manual acceptance remains for the running graphical and terminal Emacs
servers: external writes, added/modified/deleted Git hunk markers, Magit
index refresh, Difftastic-unavailable startup, and representative TRAMP
latency.

## Phase 2: Add Neovim-compatible hunk navigation and actions

Status: complete

### Changes

1. Bind `[h` and `]h` in Evil normal state through `diff-hl-mode-map`, matching
   the buffer-local Gitsigns contract at
   `profiles/common/.config/nvim/init.lua:197-203`.
2. Extend the existing Git leader group at
   `profiles/common/.config/emacs/init.el:1182-1283` with `SPC g p`,
   `SPC g s`, and `SPC g r`, using `diff-hl-show-hunk`,
   `diff-hl-stage-current-hunk`, and `diff-hl-revert-hunk` directly.
3. Preserve `SPC g g` as `magit-status`. Do not remap ordinary Space in Magit
   or change the precedence contract tested by
   `profiles/common/.config/emacs/leader-bindings-test.el:65-94`.
4. Add Which Key labels for preview, stage, and confirmed revert beside the
   existing Git group label at `profiles/common/.config/emacs/init.el:1329-1357`.
5. Add one interactive safety command that closes an active inline preview and
   then invokes `diff-hl-revert-hunk`. Bind lowercase `r` in
   `diff-hl-show-hunk-map` to this command. Retain the package's `q`, `p`, `n`,
   `e`, `c`, and `S` actions.

### Verification

- From added, modified, and deletion-only hunks, exercise `[h`, `]h`, preview,
  stage, and revert.
- Confirm stage changes the index and removes the marker, while Magit unstage
  makes it visible again.
- Confirm both direct `SPC g r` and preview `r` ask before changing the buffer.
- Confirm canceling either prompt leaves buffer, index, and marker unchanged.
- Confirm the mappings are inactive as hunk navigation outside
  `diff-hl-mode`, while `SPC g g` remains available globally in normal and
  visual states.

### Success criteria

- The five Neovim hunk keys have the same locations and honest Emacs semantics.
- All source-buffer actions call public `diff-hl` commands instead of owned Git
  or patch implementations.
- Destructive revert cannot occur through either advertised UI without a
  confirmation.
- Magit remains the only complete repository and unstage interface.

### Implementation record

Completed: 2026-09-02

- Loaded the configuration against the pinned `diff-hl` source and asserted
  the three leader commands, the buffer-local Evil normal-state `[h` and `]h`
  mappings, and the preview `r` override. The focused batch check printed
  `PHASE2_BINDINGS_AND_DISPATCH_OK`.
- Stubbed the two public revert boundaries and confirmed the preview command
  closes the inline hunk before invoking `diff-hl-revert-hunk`, preserving the
  package's configured confirmation path.
- `check-parens` and `git diff --check` completed successfully. Full hunk
  stage, revert, cancellation, and Magit unstage behavior remains part of the
  Phase 4 temporary-repository integration and interactive acceptance pass.

## Phase 3: Add hunk annotations and a visible review queue

Status: not started

### Changes

1. Add `my/annotate-current-hunk` beside `my/annotate-region` at
   `profiles/common/.config/emacs/my-send-text.el:279-296`. Use
   `diff-hl-mark-hunk` for current source bounds and
   `diff-hl-show-hunk-buffer` for the unified patch. Do not invoke Git or parse
   Difftastic output.
2. Extend annotation items with the optional `:patch` field and a session-local
   stable `:id`. Keep ordinary visual-region annotations working unchanged.
3. Extend `my/annotate-send-all` at
   `profiles/common/.config/emacs/my-send-text.el:298-324` to render an optional
   fenced `diff` block before the current source snapshot.
4. Add `my/annotations-mode` and `my/annotations-show` to the same module. Render
   each queued item as a compact multiline section with source, range, note,
   patch, and status. Provide next, previous, visit source, edit note, delete,
   refresh, send, and quit actions.
5. Bind normal `SPC g a` to hunk annotation and `SPC r v` to the queue. Preserve
   visual `SPC r a` and shared `SPC r s` at
   `profiles/common/.config/emacs/init.el:1267-1316`.

### Verification

- Queue annotations for an added hunk, a mixed hunk, a deletion-only hunk, and
  an arbitrary visual region.
- Confirm every hunk item includes the exact unified patch and usable source
  location, including deleted content that is absent from the working buffer.
- From the queue, navigate, visit source, edit a note, remove an item, refresh,
  and send the remaining ordered items.
- Send to buffer, zmx, and Ghostel targets through the existing chooser. Force a
  target failure and confirm the queue remains intact.
- Confirm no command sends as a side effect of annotating, viewing, staging, or
  reverting.

### Success criteria

- Hunk and region feedback share one ordered annotation queue.
- The queue is visually reviewable and editable before delivery.
- Deleted lines reach the coding agent through canonical unified patch context.
- Existing target selection, failure retention, and explicit-send behavior are
  preserved.

## Phase 4: Harden and accept the complete workflow

Status: not started

### Changes

1. Extend `profiles/common/.config/emacs/leader-bindings-test.el` with focused
   behavior checks for the leader commands, normal-state `[h` and `]h`, Magit
   Space precedence, and the confirmed preview revert binding.
2. Extend `profiles/common/.config/emacs/send-text-targets-test.el:28-112` with
   hunk annotation, patch rendering, review-buffer actions, ordered send, and
   failure-retention cases. Stub only public `diff-hl` boundaries in unit tests.
3. Add one temporary Git repository integration test that exercises real
   `diff-hl` update, stage, revert, and index state. Do not test third-party
   source text or reimplement its test suite.
4. Run batch init loading, ERT, byte compilation, `check-parens`, and
   `git diff --check` for every changed Emacs file.
5. Manually verify the workflow in the graphical Emacs server and a terminal
   frame. Measure one representative TRAMP buffer before deciding whether to
   set `diff-hl-disable-on-remote`.
6. Update this plan after each implemented phase with status, commands run, and
   observed results.

### Verification

- Review one external coding-agent change end to end: automatic refresh,
  markers, hunk navigation, inline preview, selective stage, selective revert,
  annotation queue review, explicit send, agent refinement, and refreshed
  markers.
- Repeat with Difftastic available and unavailable. Confirm it changes only the
  optional structural views in Magit.
- Repeat with an unsaved local edit and prove no external refresh or hunk action
  silently loses that edit.
- Record graphical, terminal, and TRAMP latency and display results in this
  plan.

### Success criteria

- The end-to-end review loop works in the existing Emacs server without opening
  a separate diff buffer for routine hunk review.
- Every state-changing action has one clear owner and an accurate label.
- No repository-owned Git diff parser, Difftastic parser, staging engine, or
  duplicate annotation transport exists.
- The configuration is deterministic, tested, documented, and safe around
  unsaved user edits.

## Final success criteria

- External coding-agent edits appear automatically in clean visiting buffers.
- Added, changed, and deleted Git hunks are visible in the source buffer.
- `[h`, `]h`, `SPC g p`, `SPC g s`, and `SPC g r` match the Neovim key
  locations.
- Stage removes an accepted hunk from the unstaged review surface; Magit can
  unstage it.
- Direct and preview revert both require confirmation.
- `SPC g a`, `SPC r v`, and `SPC r s` provide annotate, review, and explicit
  send without coupling the queue to one coding agent frontend.
- Magit remains authoritative for repository operations, and Difftastic remains
  an optional separate structural visualization.
- The built-in-only limitation and the intentional Gitsigns parity gaps are
  documented rather than hidden behind custom patch machinery.

## References

- Referenced Emacs built-ins article:
  https://karthinks.com/software/even-more-batteries-included-with-emacs/
- Emacs VC old revisions and diffs:
  https://www.gnu.org/software/emacs/manual/html_node/emacs/Old-Revisions.html
- Emacs Diff mode:
  https://www.gnu.org/software/emacs/manual/html_node/emacs/Diff-Mode.html
- Emacs interactive change highlighting:
  https://www.gnu.org/software/emacs/manual/html_node/emacs/Highlight-Interactively.html
- Emacs merge conflict handling:
  https://www.gnu.org/software/emacs/manual/html_node/emacs/Merging.html
- GNU ELPA `diff-hl` package page:
  https://elpa.gnu.org/packages/diff-hl.html
- `diff-hl` upstream source and usage:
  https://github.com/dgutov/diff-hl
- Pinned `diff-hl` revision:
  https://github.com/dgutov/diff-hl/commit/3d9552c575fd14ac98ac97bf3c19cdef39f79305
- Difftastic manual:
  https://difftastic.wilfred.me.uk/
- Difftastic Emacs integration:
  https://github.com/pkryger/difftastic.el
