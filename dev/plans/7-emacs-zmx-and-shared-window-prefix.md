# Emacs zmx and shared window-prefix workflow implementation plan

## Reasoning

Emacs currently exposes three related workflows with different interaction
contracts. `SPC w` is the source of truth for window operations, `C-b` exposes a
terminal-only subset of that map, and `SPC t z` opens or creates a durable zmx
session without using the package's location-aware completion. Reopening an
existing zmx frontend also preserves its previous outer Evil state, so a terminal
left in Normal state reopens in Normal state even though the command is intended
to produce an input-ready terminal.

Unify these workflows around two explicit contracts. First, selecting a zmx
session should behave like `find-file`: one completion lists existing local and
known remote sessions, while unmatched input creates a new local session. Opening
a zmx terminal through `SPC t z` should always finish in Ghostel semi-char mode
and outer Evil Insert state. Second, every window operation should be defined
once under `SPC w`; state-specific `C-b` prefix maps should inherit that shared
map instead of copying its leaves.

The pinned term-sessions revision already contains the internal machinery for
location-aware open-or-create completion, but it does not expose that machinery
as a supported public reader. It also does not consistently return the opened
frontend buffer on every creation path. Extend the upstream package contract
first, publish a reachable reviewed revision, then update the dotfiles pin and
consume only the new public APIs. Do not repeat the previous private-selector
compromise or pin an unpublished local revision.

This is a standalone plan. It does not add follow-ups to earlier Emacs plans and
does not reopen their completed phases.

## Goals

- Give `SPC t z` one location-aware completion for existing and new zmx
  sessions.
- Remove the separate `existing` versus `create new` zmx menu from the explicit
  text-target chooser.
- Preserve the full zmx identity as session name plus backend directory,
  including already-known TRAMP locations.
- Make every successful `SPC t z` open or reopen finish in Ghostel semi-char
  mode and outer Evil Insert state.
- Keep `s-<escape>` as a one-way Ghostel Insert-to-Normal escape hatch.
- Define navigation, split creation, resizing, closing, balancing, focus, Winner,
  and tab operations once under `SPC w`.
- Expose the same shared window operations under `C-b` in regular Evil Normal
  and Visual states and in Ghostel Evil Insert state.
- Preserve regular Evil Insert and minibuffer `C-b`, Ghostel char-mode
  passthrough, terminal literal Ctrl-B, and regular Normal/Visual page-up.
- Keep normal Emacs startup offline and package provisioning explicit and
  reproducible.

## Status

- Plan: complete
- Implementation: in progress
- Overall: 1/4 phases complete
- Current phase: Phase 2 - Publish and pin the unified term-sessions API
- Target: Emacs 31.1+
- Primary configuration: `profiles/common/.config/emacs/init.el`
- Terminal workflow module: `profiles/common/.config/emacs/my-send-text.el`
- Dotfiles package provisioner:
  `profiles/common/.config/emacs/install-packages.el`
- Upstream package checkout: `refs/emacs-term-sessions`
- Existing dotfiles tests:
  `profiles/common/.config/emacs/leader-bindings-test.el` and
  `profiles/common/.config/emacs/send-text-targets-test.el`
- Upstream package tests: `refs/emacs-term-sessions/term-sessions-tests.el`

## Scope and terminology

- Ghostel is the Emacs terminal renderer. The user-facing target label remains
  `ghostty`, but this plan does not configure the standalone Ghostty
  application.
- zmx owns durable terminal sessions. A session is identified by its logical
  name and backend directory, not by the name of a disposable Ghostel frontend
  buffer.
- Outer Evil state controls Emacs editing commands such as Normal, Visual, and
  Insert state.
- Inner Ghostel input mode controls terminal event routing. Semi-char mode sends
  ordinary input to the PTY while preserving Emacs escape keys. Char mode sends
  every key inward except its `M-RET` escape hatch.
- `SPC w` is the canonical shared window-command map. `C-b` is another entry
  point, not a second implementation table.
- `refs/emacs-term-sessions` is a separate Git repository ignored by the
  dotfiles repository. Its upstream change, review, publication, and tests are
  separate from the dotfiles commit history.
- The existing modification to
  `dev/plans/emacs-workflow-agentic-support.md` is unrelated user work and must
  not be changed, staged, reverted, or included while executing this plan.

## Execution, commit, and review policy

- Execute the phases in order because the dotfiles integration depends on the
  published term-sessions contract.
- Use GPT-5.6-terra at xhigh reasoning for implementation sub-agents.
- Finish every phase with a focused Git commit containing only that phase's
  implementation and status update. Never combine changes from two phases in
  one commit. Because `refs/emacs-term-sessions` is a separate repository,
  Phase 2 has its upstream commit there and a separate dotfiles commit for the
  plan status and reachable package pin.
- Do not run sub-agent review after individual phases. Run one GPT-5.6-sol
  xhigh review only after all implementation work is present, and have it
  review the complete plan, both repositories' full diffs and commit series,
  and the complete validation evidence.
- Resolve every actionable holistic-review finding, rerun affected validation,
  and record the final result in Phase 4 before declaring the plan complete.

## Current behavior and root causes

### Zmx selection is split across incompatible prompts

- `profiles/common/.config/emacs/my-send-text.el:333-348` implements
  `my/open-or-create-zmx-session-in-split`. Its interactive form uses raw
  `read-string`, so `SPC t z` does not list existing local or remote sessions.
- `profiles/common/.config/emacs/my-send-text.el:108-140` implements the zmx
  branch of the explicit text-target chooser. It first asks for `existing` or
  `create new`; existing selection then opens a second completion.
- `profiles/common/.config/emacs/my-send-text.el:19` declares and
  `:123-128` calls the private
  `term-sessions--read-existing-session-entry` function.
- The two-step target chooser was introduced because the pinned package exposes
  no public reader that combines location-aware existing entries with unmatched
  creation input. That API boundary, rather than a separate action menu, is the
  root problem.
- `refs/emacs-term-sessions/term-sessions-frontends.el:367-401` already owns the
  required find-file-like completion internally. It returns the selected full
  entry when a candidate matches and a name/current-directory entry for
  unmatched text.
- `refs/emacs-term-sessions` currently has unpublished local commit `acc8726`,
  which exposes only existing-session selection. The dotfiles provisioner pins
  reachable upstream revision `0815dbea006128df1d61e9d29e5a8ada53b349c1`
  at `profiles/common/.config/emacs/install-packages.el:20-23`. Do not pin
  `acc8726` or another local-only revision.

### Reused zmx buffers preserve stale interaction state

- `profiles/common/.config/emacs/init.el:1523-1550` configures new Ghostel
  buffers to start in outer Evil Insert state and binds `s-<escape>` only in
  that state.
- A fresh Ghostel buffer correctly starts with outer Evil Insert and inner
  semi-char state.
- `refs/emacs-term-sessions/term-sessions-frontends.el:409-414` pops an existing
  session frontend buffer and returns it without applying a frontend resume
  policy.
- `refs/emacs-term-sessions/term-sessions-frontends.el:434-436` takes that reuse
  path before the Ghostel adapter runs. The adapter's semi-char normalization at
  `:80-108` is therefore bypassed for an already-open frontend.
- `my/open-or-create-zmx-session-in-split` ignores the value returned by
  `term-sessions-open`, so it cannot normalize the selected frontend after a
  successful open.
- The live failure state was outer Evil Normal plus inner Ghostel semi-char.
  `s-<escape>` correctly resolved to no command because it is an Insert-state
  escape hatch, not a Normal-state toggle.
- On a fresh Ghostel open, the current package's Ghostel wrapper ends with
  `rename-buffer` and can return a string rather than the opened buffer. The
  upstream open API must guarantee a buffer result before the dotfiles depend
  on it.

### The shared window map is incomplete and `C-b` is terminal-only

- `profiles/common/.config/emacs/init.el:1737-1842` creates and populates
  `my/leader-map`. Its `w` submap has navigation, close, swap, balance,
  maximize, delete-other-windows, Winner, and tab operations, but no split or
  resize operations.
- `profiles/common/.config/emacs/init.el:1844-1858` creates
  `my/terminal-window-map`, parents it to the shared `SPC w` submap, adds
  terminal-specific `C-b C-b`, and binds the map only in Ghostel Evil Insert
  state.
- In a regular Evil Normal buffer, `C-b` remains `evil-scroll-page-up`. In a
  regular Evil Insert buffer, it remains `backward-char`. `C-b h/j/k/l` is
  undefined in both.
- `profiles/common/.tmux.conf:1,18-35` uses `C-b` as its prefix, `v` and `s` for
  left/right and top/bottom splits, `h/j/k/l` for selection, and `H/J/K/L` for
  resizing.
- `profiles/common/.config/nvim/init.lua:634-649` already keeps window and tab
  commands under the `<leader>w` hierarchy. Emacs should retain the same single
  source-of-truth shape.

### Test gaps

- `profiles/common/.config/emacs/leader-bindings-test.el:161-195` verifies the
  terminal-local `C-b` map only after explicitly forcing Evil Insert state. It
  does not cover regular Normal/Visual `C-b`, split creation, resizing, fresh
  initial state, or reopened terminal state.
- `profiles/common/.config/emacs/send-text-targets-test.el:249-386` asserts the
  two-step zmx chooser by design.
- `profiles/common/.config/emacs/send-text-targets-test.el:757-786` checks the
  split command's prompts, directory, display action, and saved target, but
  stubs away the returned frontend and never asserts its final Evil or Ghostel
  state.

## Historical context

These commits explain the current behavior but do not own this new plan:

- `f3bd6b6` introduced the persistent Ghostel and zmx workflow.
- `4efde5b` configured new Ghostel buffers to start in Evil Insert state.
- `f5b4769` added the current `s-<escape>` binding.
- `adb01c0` introduced generalized delivery and `SPC t z`.
- `70b3aab` finalized explicit target selection and the two-step zmx chooser.
- `3abcfcf`, `768202c`, and `f8de451` added and verified the terminal-local
  `C-b` and `M-SPC` maps.
- `acc8726` in `refs/emacs-term-sessions` exposes existing-only selection but
  is not published on the configured upstream remote.
- `ed50655` implements Markdown and Org table wrapping and is unrelated to
  terminal state, zmx selection, or window prefixes.

## Decisions

1. Keep `SPC w` as the only implementation table for shared window and tab
   operations. Both `C-b` maps inherit it.
2. Add split and resize commands directly to the shared map. Do not duplicate
   them in state-specific maps.
3. Match the repository's tmux bindings with `v`, `s`, and `H/J/K/L`. Also add
   tmux-default `%` and `"` split aliases because they are familiar and were
   explicitly requested.
4. Use public Evil commands for split and resize behavior. Set the supported
   split-placement options so new windows appear to the right or below and are
   selected consistently with Vim/tmux expectations.
5. Bind the shared window prefix under `C-b` only in Evil Normal and Visual
   states. Do not bind it in regular Evil Insert, Emacs state, or minibuffers.
6. Keep a separate terminal child map for Ghostel Evil Insert so `C-b C-b` can
   send literal Ctrl-B through public `ghostel-send-key`.
7. Keep a separate editor child map for Evil Normal and Visual so `C-b C-b` can
   preserve the prior `evil-scroll-page-up` operation.
8. Do not override Ghostel char mode. Its higher-precedence emulation map keeps
   all keys, including `C-b`, terminal-owned until `M-RET` exits char mode.
9. Keep `M-SPC` as the terminal-local route to the complete leader map. The new
   `C-b` behavior supplements it but does not replace or globalize it.
10. Keep `s-<escape>` one-way from Ghostel Insert to Evil Normal. Fix the
    opener's postcondition instead of adding a Normal-state toggle.
11. Add a supported public term-sessions reader for the unified selection. Do
    not copy its completion table, query zmx independently, advise an interactive
    command, scrape minibuffer state, or call a private package function.
12. Have the public selector state whether the result matched an existing
    session. Existing selection remains headless in the send-target flow; only
    unmatched creation needs to open a frontend before delivery.
13. Make `term-sessions-open` and `term-sessions-open-with-frontend` return the
    exact frontend buffer on both reuse and fresh-open paths. Document and test
    that return contract upstream.
14. Publish the reviewed upstream commit at the original repository URL before
    changing the dotfiles pin. A local commit hash is not an installable
    dependency.
15. Preserve caller `default-directory` before any completion or display
    changes. An unmatched session name creates in that captured directory.
16. Save a tab target only after selection, required creation, state
    normalization, and any requested delivery succeed. Preserve the old target
    on cancellation or failure.
17. Do not attempt to kill a zmx session when a later normalization or delivery
    step fails. Creation and terminal output may already be externally visible.
18. Extend the existing focused ERT tests rather than adding source-content
    assertions or proliferating one-assertion tests.

## Complete zmx selection contract

After the user selects `zmx` as a target, exactly one zmx-specific completion is
shown.

| Selection | Result | Frontend behavior | Durable target |
| --- | --- | --- | --- |
| Existing local candidate | Preserve its name and local backend directory | `SPC t z` opens or reuses it; sending text does not open it | `(:type zmx :name NAME :directory DIRECTORY)` |
| Existing known remote candidate | Preserve its name and TRAMP backend directory exactly | `SPC t z` opens or reuses it; sending text does not open it | Same descriptor shape with remote directory |
| Unmatched typed name | Create an entry using the caller's captured directory | Open/create before `SPC t z` returns or before text delivery | Same descriptor shape without transient selection metadata |
| Empty or cancelled selection | Abort without opening, sending, or saving | None | Prior target preserved |
| Selection or open error | Signal the package error | Do not start later steps | Prior target preserved |

The public package reader returns a location-aware entry with an explicit
transient marker:

```elisp
(:name NAME :directory DIRECTORY :existing t)
```

for an existing candidate, or:

```elisp
(:name NAME :directory DIRECTORY :existing nil)
```

for unmatched creation input. Existing package metadata such as `:cwd`,
`:where`, and `:session` may remain on existing entries. The dotfiles remove the
transient `:existing` decision marker when constructing the durable tab target.

With a prefix argument, `SPC t z` prompts for a creation command only after an
unmatched new name is selected. Selecting an existing session never asks for or
applies a creation command.

## Complete terminal-open state contract

`SPC t z` is an explicit input-ready terminal command. After a successful local
or remote open, its selected Ghostel frontend has these states regardless of its
prior state:

| Previous frontend state | Final Ghostel input mode | Final Evil state |
| --- | --- | --- |
| No frontend buffer | semi-char | Insert |
| Insert and semi-char | semi-char | Insert |
| Normal or Visual | semi-char | Insert |
| char | semi-char | Insert |
| line, copy, or Emacs input mode | semi-char | Insert |

Normalize in this order:

1. Call public `ghostel-semi-char-mode` in the returned frontend buffer.
2. Call public `evil-ghostel-insert` so Evil enters Insert through the
   terminal-aware cursor synchronization path.

Afterward, `s-<escape>` enters outer Evil Normal state once. It does not change
the Ghostel input mode. `i`, `o`, or Return returns to terminal-aware Insert.

## Complete shared window command contract

All rows live in the shared `SPC w` submap. The editor and terminal `C-b` maps
inherit these exact bindings.

| Suffix | `SPC w` | `C-b` in supported states | Command |
| --- | --- | --- | --- |
| `h` | `SPC w h` | `C-b h` | `evil-window-left` |
| `j` | `SPC w j` | `C-b j` | `evil-window-down` |
| `k` | `SPC w k` | `C-b k` | `evil-window-up` |
| `l` | `SPC w l` | `C-b l` | `evil-window-right` |
| `v` | `SPC w v` | `C-b v` | `evil-window-vsplit` |
| `%` | `SPC w %` | `C-b %` | `evil-window-vsplit` |
| `s` | `SPC w s` | `C-b s` | `evil-window-split` |
| `"` | `SPC w "` | `C-b "` | `evil-window-split` |
| `H` | `SPC w H` | `C-b H` | `evil-window-decrease-width` |
| `J` | `SPC w J` | `C-b J` | `evil-window-increase-height` |
| `K` | `SPC w K` | `C-b K` | `evil-window-decrease-height` |
| `L` | `SPC w L` | `C-b L` | `evil-window-increase-width` |
| `q` | `SPC w q` | `C-b q` | `delete-window` |
| `x` | `SPC w x` | `C-b x` | `window-swap-states` |
| `=` | `SPC w =` | `C-b =` | `balance-windows` |
| `|` | `SPC w |` | `C-b |` | `maximize-window` |
| `z` | `SPC w z` | `C-b z` | `delete-other-windows` |
| `u` | `SPC w u` | `C-b u` | `winner-undo` |
| `r` | `SPC w r` | `C-b r` | `winner-redo` |
| `t c` | `SPC w t c` | `C-b t c` | `tab-bar-new-tab` |
| `t q` | `SPC w t q` | `C-b t q` | `tab-bar-close-tab` |
| `t [` | `SPC w t [` | `C-b t [` | `tab-bar-switch-to-prev-tab` |
| `t ]` | `SPC w t ]` | `C-b t ]` | `tab-bar-switch-to-next-tab` |

Set `evil-vsplit-window-right` and `evil-split-window-below` to non-nil so split
placement is deterministic. Evil's resize commands retain their native numeric
prefix behavior and use their normal single-step default. Do not add one-use
resize wrapper functions.

`C-b C-b` remains state-specific and therefore does not belong to the shared
`SPC w` table:

| Context | `C-b` | `C-b C-b` |
| --- | --- | --- |
| Regular Evil Normal or Visual | Editor window child map | `evil-scroll-page-up` |
| Ghostel Evil Normal or Visual | Editor window child map | `evil-scroll-page-up` |
| Ghostel Evil Insert plus semi-char | Terminal window child map | Send literal Ctrl-B with `ghostel-send-key` |
| Ghostel char mode | Sent inward by Ghostel | Sent inward by Ghostel |
| Regular Evil Insert | `backward-char` | Existing Insert behavior |
| Minibuffer | `backward-char` | Existing minibuffer behavior |
| Evil Emacs state | Existing binding | Existing Emacs-state behavior |

## Reload and ownership model

`my/leader-map` and its submaps are recreated during every full init evaluation.
The child prefix maps must therefore also be recreated and reparented after the
shared binding table is complete:

```text
my/leader-map
  `w` shared window map
    -> my/editor-window-map
         direct `C-b` leaf: evil-scroll-page-up
    -> my/terminal-window-map
         direct `C-b` leaf: send literal Ctrl-B
```

- Bind `my/editor-window-map` to `C-b` in global Evil Normal and Visual state.
- Bind `my/terminal-window-map` to `C-b` only in
  `evil-ghostel-mode-map` Evil Insert state.
- Leave the existing terminal-local `M-SPC` binding to `my/leader-map` intact.
- Rebinding on reload is intentional and prevents either child from retaining a
  stale parent map.

## Phase 1: Complete the shared window command surface

Status: complete

### Changes

1. In `profiles/common/.config/emacs/init.el`, configure
   `evil-vsplit-window-right` and `evil-split-window-below` with the existing
   Evil settings.
2. Add the split and resize rows from the complete contract directly to the
   existing shared `SPC w` binding table.
3. Preserve every existing `SPC w` binding and its command.
4. Create and recreate `my/editor-window-map` after the shared table is fully
   populated. Parent it to `(keymap-lookup my/leader-map "w")` and bind its
   direct `C-b` leaf to `evil-scroll-page-up`.
5. Keep `my/terminal-window-map` as a separate child of the same shared map and
   retain its direct literal Ctrl-B leaf.
6. Bind the editor child under `C-b` in global Evil Normal and Visual states.
   Keep the terminal child under `C-b` in Ghostel Evil Insert state.
7. Add concise Which Key descriptions for split and resize leaves. Do not
   duplicate inherited labels on each child map.
8. Expand the existing focused test in
   `profiles/common/.config/emacs/leader-bindings-test.el` rather than adding a
   set of source-structure tests.

### Verification

- In regular source buffers, verify `SPC w` and Evil Normal/Visual `C-b` resolve
  every shared navigation, split, resize, and existing window/tab leaf to the
  same command.
- Verify `C-b C-b` resolves to `evil-scroll-page-up` in regular and Ghostel
  Normal/Visual states.
- In Ghostel Insert plus semi-char, verify the same inherited leaves and one
  literal Ctrl-B send.
- Verify Ghostel char mode continues to send `C-b` inward and exits through
  `M-RET`.
- Verify regular Insert and a real minibuffer retain `backward-char`.
- Evaluate `init.el` twice and confirm both child maps inherit the new current
  shared map rather than the previous init's map.

### Success criteria

- Every mapping in the shared window contract is reachable under `SPC w`.
- The same mappings are reachable under `C-b` in regular Evil Normal/Visual and
  Ghostel Evil Insert states.
- State-specific `C-b C-b`, regular Insert, minibuffer, Emacs state, Ghostel
  char mode, and `M-SPC` behaviors remain intact.
- Split placement and resize direction match the documented contract.
- The focused leader ERT suite and reload probe pass.

### Implementation outcome

- Added the complete shared split and resize vocabulary to `SPC w`, then
  inherited it from separate editor and terminal `C-b` child maps.
- Preserved state-specific `C-b C-b`, regular Insert, minibuffer, Emacs state,
  Ghostel char mode, and terminal `M-SPC` ownership.
- Confirmed both child maps are recreated and reparented after two complete
  `init.el` reloads.
- The focused leader ERT suite passed 6/6 tests. `check-parens` and
  `git diff --check` passed for the changed Phase 1 files.

## Phase 2: Publish and pin the unified term-sessions API

Status: pending

### Changes

1. Work in the separate `refs/emacs-term-sessions` Git repository. Preserve the
   useful location-aware and lazy-loading changes in unpublished commit
   `acc8726`, but do not publish its existing-only API as the final contract.
2. Add public autoloaded `term-sessions-read-session-entry`, which invokes the
   package-owned location-aware completion with creation allowed.
3. Keep public `term-sessions-read-existing-session-entry` for callers that
   require a match, implemented through the same private completion core.
4. Return the explicit `:existing t` or `:existing nil` marker described above
   without losing existing name, backend directory, cwd, remote, annotation, or
   completion-category metadata.
5. Make interactive `term-sessions-open` use the public unified reader.
6. Make `term-sessions-open` and `term-sessions-open-with-frontend` return the
   exact opened or reused frontend buffer. Correct the Ghostel adapter and any
   other frontend adapter that currently returns an incidental string or other
   value.
7. Document the two public readers, the creation marker, location semantics,
   and the buffer return contract in `refs/emacs-term-sessions/README.org` and
   function docstrings.
8. Extend `refs/emacs-term-sessions/term-sessions-tests.el` with focused
   behavior checks for:
   - existing local selection;
   - existing known-remote selection;
   - unmatched creation input in the captured current directory;
   - require-match existing selection;
   - cancellation;
   - exact `:existing` marker semantics;
   - exact buffer return on reuse and fresh Ghostel open.
9. Run the complete upstream ERT and MELPA-oriented load, byte-compile,
   checkdoc, and package-lint checks available in its CI workflow.
10. Create a coherent upstream Git commit and publish it through an authorized
    branch or accepted upstream change. Confirm the final hash is fetchable from
    `https://github.com/ArthurHeymans/emacs-term-sessions.git` before continuing.
11. Update only the term-sessions revision in
    `profiles/common/.config/emacs/install-packages.el` to that reachable hash.
12. Provision an isolated clean Emacs package directory, load the new public
    APIs, and run the full provisioner a second time to verify idempotency.

### Verification

Run the upstream suite from its repository:

```sh
emacs -Q --batch -L . -l term-sessions-tests.el \
  -f ert-run-tests-batch-and-exit
```

Run the upstream CI-equivalent checks documented by the checkout. Then run the
dotfiles provisioner in an isolated package environment at least twice and
verify the installed descriptor reports the exact new revision.

### Success criteria

- One supported public reader handles existing local, existing known-remote,
  and unmatched new session input.
- Its return value preserves location identity and states whether the candidate
  existed.
- The existing-only reader still requires a completion match.
- Every successful open API path returns the exact frontend buffer.
- The full upstream suite passes.
- The reviewed commit is reachable from the configured original URL.
- Fresh installation and a second provisioner run use the exact new pin without
  network work during normal Emacs startup.

## Phase 3: Unify zmx workflows and enforce input-ready opens

Status: pending

### Changes

1. Update deferred declarations in
   `profiles/common/.config/emacs/init.el` and
   `profiles/common/.config/emacs/my-send-text.el` to use public
   `term-sessions-read-session-entry`, `term-sessions-open`,
   `ghostel-semi-char-mode`, and `evil-ghostel-insert` contracts.
2. Remove every call and declaration of
   `term-sessions--read-existing-session-entry` from repository-owned code.
3. Change `my/open-or-create-zmx-session-in-split` to:
   - capture the caller's directory before prompting;
   - invoke the public unified reader once;
   - prompt for an optional creation command only when `:existing` is nil and a
     prefix argument was supplied;
   - bind the existing right-side display action;
   - pass the full selected entry to `term-sessions-open`;
   - capture the returned frontend buffer;
   - normalize it with `ghostel-semi-char-mode`, then
     `evil-ghostel-insert`;
   - save only the durable name/directory descriptor after success.
4. Change the zmx branch of `my/send-text-to-target` to use the same one public
   reader invocation after the top-level `zmx` choice.
5. When the selector reports an existing session, send directly without
   opening a frontend. When it reports a new name, open/create it through
   `term-sessions-open` before delivery and normalize any displayed Ghostel
   frontend through the same public state calls.
6. Preserve exact zmx delivery as text followed by one carriage return.
7. Preserve current tab-local replay behavior. Replaying a saved target performs
   no completion and no frontend open.
8. Preserve prior targets on cancellation, selection failure, open failure,
   state-normalization failure, or delivery failure. Do not roll back a session
   that may already have been created.
9. Update existing cases in
   `profiles/common/.config/emacs/send-text-targets-test.el` instead of adding
   many narrow tests. Table-drive local existing, remote existing, and new
   selections where that keeps the test direct.

### Verification

- Assert exactly one zmx-specific completion after choosing the zmx class and
  no `existing`/`create new` action prompt.
- Assert existing selection does not open a frontend in the send-target path.
- Assert new selection opens before sending and retains the captured source
  directory.
- Assert `SPC t z` passes the full entry and existing display action, consumes
  the exact returned buffer, calls semi-char before Evil Insert, and saves only
  afterward.
- Prepare reused Ghostel buffers in Normal, Visual, char, copy, line, and Emacs
  input states and confirm the documented final state.
- Assert local and remote durable descriptors preserve the exact selector
  directory and omit transient `:existing` metadata.
- Assert cancellation and each failure boundary preserve the previous tab
  target.

### Success criteria

- `SPC t z` presents one completion that selects existing sessions or accepts a
  new name.
- Every successful `SPC t z` result is a selected Ghostel semi-char plus Evil
  Insert buffer, including reused frontends previously left in Normal or char
  state.
- `s-<escape>` then enters Evil Normal state once without changing the Ghostel
  input mode.
- The send-target zmx path has the same one-prompt selection semantics without
  displaying existing sessions unnecessarily.
- Local and remote identity, exact delivery, replay, and failure preservation
  remain correct.
- The complete send-target ERT suite passes.

## Phase 4: Integrated acceptance and closeout

Status: pending

### Changes

1. Re-read the complete diff in both Git repositories for scope, public API
   consistency, reload safety, and test quality.
2. Run the complete upstream term-sessions test and package checks.
3. Run the dotfiles leader and send-target ERT suites plus every existing Emacs
   suite affected by loading `init.el`.
4. Run `check-parens` and byte compilation or guarded load checks for each
   changed Emacs Lisp file.
5. Run `git diff --check` independently in the dotfiles and term-sessions
   repositories.
6. Run the isolated package provisioner twice and guarded offline double startup
   with package refresh, installation, and VC installation entry points disabled.
7. Reload the user's running Emacs server and exercise a real local zmx session:
   - select an existing session from the first `SPC t z` completion;
   - type an unmatched name and create a session;
   - leave a frontend in Evil Normal plus Ghostel semi-char and reopen it;
   - leave a frontend in Ghostel char mode and reopen it;
   - confirm both reopen paths finish semi-char plus Insert;
   - confirm `s-<escape>`, `i`, `o`, and Return follow the state contract.
8. In regular and Ghostel buffers, exercise navigation, both split naming
   schemes, resize directions, close, balance, focus, Winner, and tab operations
   under both `SPC w` and `C-b`.
9. Confirm regular Insert, minibuffer, Evil Emacs state, Ghostel char mode,
   terminal `C-b C-b`, editor `C-b C-b`, and `M-SPC` remain unchanged.
10. Exercise known-remote selection when an existing TRAMP connection is
    available. Record it as environment-dependent rather than failing the plan
    solely because no remote is connected.
11. Update only this plan's status and measured outcomes. Do not edit or add
    follow-ups to earlier plan files.

### Validation commands

At minimum, run:

```sh
emacs --batch -Q \
  -l profiles/common/.config/emacs/leader-bindings-test.el \
  -f ert-run-tests-batch-and-exit

emacs --batch -Q \
  -l profiles/common/.config/emacs/send-text-targets-test.el \
  -f ert-run-tests-batch-and-exit

emacs -Q --batch -L refs/emacs-term-sessions \
  -l refs/emacs-term-sessions/term-sessions-tests.el \
  -f ert-run-tests-batch-and-exit

git diff --check
git -C refs/emacs-term-sessions diff --check
```

Use the repository's established guarded startup and package-provisioning probes
for the remaining checks. Do not weaken tests or suppress errors to make a
validation command pass.

### Success criteria

- All automated upstream and dotfiles tests pass.
- Parentheses, compilation/load, whitespace, exact-pin, provisioning,
  idempotency, reload, and offline-startup checks pass.
- Real local zmx creation and reuse demonstrate the exact selection and state
  contracts.
- `SPC w` and `C-b` expose the same shared window commands in their documented
  states.
- Preserved key ownership behaves exactly as documented.
- The upstream revision is reachable and the dotfiles working tree contains
  only this plan's intended implementation changes plus untouched pre-existing
  user work.
- This plan is marked complete with measured outcomes; earlier plan files remain
  unchanged.

## Alternatives rejected

- Keep raw `read-string` for `SPC t z`: it cannot discover or disambiguate
  existing local and remote sessions.
- Keep the `existing` versus `create new` action menu: it adds a prompt for a
  distinction completion can infer from whether the input matched.
- Call private `term-sessions--read-session-entry` or the current private
  existing selector: this creates another unsupported package boundary and was
  the reason the two dotfiles flows diverged.
- Reimplement zmx listing, TRAMP discovery, completion annotations, and entry
  identity in the dotfiles: term-sessions already owns those contracts.
- Shell out to `zmx list` from repository code: this would duplicate package
  parsing and omit known remote locations.
- Call `term-sessions-open` interactively and scrape the selected buffer: it
  couples data selection to display side effects and cannot keep existing
  send-target selection headless.
- Always open an existing session before sending text: target selection should
  not steal focus or create an unnecessary frontend.
- Pin `acc8726` or another unpublished reference commit: a clean machine cannot
  fetch it from the configured URL.
- Treat a frontend buffer name as zmx identity: buffers are disposable and
  title changes can rename them; durable identity is name plus backend location.
- Bind `s-<escape>` in Evil Normal as a toggle: it would mask the opener's broken
  postcondition and make an escape hatch state-dependent.
- Override Ghostel char mode: char mode deliberately routes all keys to a TUI
  and already has `M-RET` as its escape hatch.
- Copy all `SPC w` leaves into each `C-b` map: duplicated key tables drift.
- Bind `C-b` globally or in all Insert states: this would replace standard
  `backward-char` in editing buffers and minibuffers.
- Put state-specific `C-b C-b` on the shared `SPC w` map: that would make a
  shared leader leaf depend on the caller's state. Child maps isolate the two
  required meanings.
- Add custom one-use split or resize wrappers: Evil already provides direct,
  count-aware commands and supported split-placement options.
- Turn `C-b z` into a reversible tmux zoom toggle: the existing shared command
  is `delete-other-windows`; changing its semantics is outside this plan.

## References

Repository code:

- `profiles/common/.config/emacs/init.el:1523-1550`
- `profiles/common/.config/emacs/init.el:1737-1858`
- `profiles/common/.config/emacs/my-send-text.el:108-140`
- `profiles/common/.config/emacs/my-send-text.el:333-348`
- `profiles/common/.config/emacs/leader-bindings-test.el:147-195`
- `profiles/common/.config/emacs/send-text-targets-test.el:249-386`
- `profiles/common/.config/emacs/send-text-targets-test.el:757-786`
- `profiles/common/.config/emacs/install-packages.el:20-23`
- `profiles/common/.tmux.conf:1-35`
- `profiles/common/.config/nvim/init.lua:634-649`
- `refs/emacs-term-sessions/term-sessions-frontends.el:367-466`
- `refs/emacs-term-sessions/term-sessions-tests.el:641-788`
- `refs/ghostel/extensions/evil-ghostel/evil-ghostel.el:506-520`
- `refs/ghostel/extensions/evil-ghostel/evil-ghostel.el:855-939`

Upstream projects:

- https://github.com/ArthurHeymans/emacs-term-sessions
- https://github.com/dakra/ghostel

## Final success criteria

- Zmx selection uses one public, location-aware existing-or-create completion in
  every repository-owned workflow.
- `SPC t z` always returns an input-ready Ghostel semi-char plus Evil Insert
  frontend and records the correct durable target only after success.
- `s-<escape>` remains a reliable one-way Insert-to-Normal escape hatch.
- `SPC w` owns the complete documented window command vocabulary.
- `C-b` exposes that same vocabulary in regular Evil Normal/Visual and Ghostel
  Evil Insert states while preserving all documented state-specific exceptions.
- The public term-sessions API is tested, documented, published, reachable, and
  exactly pinned.
- All upstream, dotfiles, provisioner, startup, reload, and live interaction
  checks pass without modifying earlier plan files or unrelated user work.
