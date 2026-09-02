# Emacs workspace layouts implementation plan

## Reasoning

Use one tab as one task workspace, identified by a full normalized directory
property named `my/workspace-root`. The root is the identity; the tab name is
only a label. Layouts must read that root and never infer ownership from the
selected companion buffer, a terminal's current directory, a branch name, or
the visible tab name.

This design supports linked Git worktrees without special Git parsing. For a
bare clone with this shape:

```text
<repo-dir>/
  .bare/
  branch1/
  branch2/
```

Emacs `project.el` does not treat the parent or `.bare/` as source projects,
while each linked worktree is a separate VC project. `branch1/` and `branch2/`
therefore provide the correct task identities even when Emacs starts in their
common parent. Selecting each worktree creates two independently rooted task
tabs. No manual tab tag is required.

Do not key state by the tab name. Emacs tabs are named window configurations,
but names can change and need not be unique. Derive a friendly initial name
from the root basename, while storing ownership in the root property. An
explicit rebind command changes the root and clears context-dependent caches
without killing buffers, processes, or durable zmx sessions.

Layouts should be recipes over live buffers, not saved window states. A saved
window configuration cannot resolve a killed terminal frontend, attach a
durable zmx session again, or choose the correct Magit buffer for a newly
selected root. A catalog plus resource-specific buffer providers can rebuild a
deterministic view while keeping the task's edit buffer and companion choices.

This plan is independently implementable. It contains its own workspace
selection, layout bindings, Magit leader precedence boundary, package pin
change, provider contracts, tests, and validation. It does not require any
writing-shortcut, line-number, typography, or completion change.

References:

- Git worktree model: https://git-scm.com/docs/git-worktree.html
- Emacs project model: https://www.gnu.org/software/emacs/manual/html_node/emacs/Projects.html
- Emacs tab-bar model: https://www.gnu.org/software/emacs/manual/html_node/emacs/Tab-Bars.html

## Goals

- Treat one tab as one project or folder task workspace, identified by a full
  normalized root rather than its mutable name.
- Provide deterministic focus, terminal, coding-agent, Gptel, and Magit layouts
  through one configurable catalog.
- Make workspace and layout selection direct leader actions while retaining the
  existing nested focus, AI, Git, terminal, and manual window routes.
- Preserve the primary edit buffer, companion selection, terminal target,
  agent target, and AI context independently across linked worktrees.
- Rebuild layouts from live resources without killing buffers, terminal
  processes, or durable zmx sessions.
- Make layout shortcuts reachable from a Magit companion window in Evil normal
  and visual states.

## Status

- Plan: complete
- Implementation: not started
- Target: Emacs 31.1+
- Primary configuration: `profiles/common/.config/emacs/init.el`
- Package provisioner: `profiles/common/.config/emacs/install-packages.el`
- Existing terminal tests: `profiles/common/.config/emacs/send-text-targets-test.el`
- Planned layout tests: `profiles/common/.config/emacs/window-layouts-test.el`

## Current behavior and root causes

### Existing primitives

- Magit is configured at `profiles/common/.config/emacs/init.el:105`.
- Gptel is configured at `profiles/common/.config/emacs/init.el:253`.
- term-sessions is configured at
  `profiles/common/.config/emacs/init.el:440`.
- The current 50 percent right-split action is at
  `profiles/common/.config/emacs/init.el:454`.
- Tab-local terminal send-target state starts at
  `profiles/common/.config/emacs/init.el:460` and is updated near
  `profiles/common/.config/emacs/init.el:654`.
- The code calls a private term-sessions selector at
  `profiles/common/.config/emacs/init.el:558`.
- Plain Ghostel and zmx split commands are at
  `profiles/common/.config/emacs/init.el:677` and
  `profiles/common/.config/emacs/init.el:696`.
- Tab-bar configuration begins at
  `profiles/common/.config/emacs/init.el:1148`.
- The leader table begins at `profiles/common/.config/emacs/init.el:1202`.
- Winner undo and redo are bound at
  `profiles/common/.config/emacs/init.el:1233`; Winner is enabled at
  `profiles/common/.config/emacs/init.el:1473`.

### Layout behavior

- `SPC w z` calls raw `delete-other-windows`. Invoking it from a terminal,
  Gptel, or Magit pane can retain the companion and discard the editing view.
- Saved window states and registers capture concrete buffers and positions.
  They become stale when a terminal frontend dies and cannot select resources
  for another project.
- `project-current` returns no project for a linked-worktree container or its
  `.bare` repository, while each checked-out worktree is a separate project.
  The shared Git common directory is therefore the wrong task identity.
- Project names, branch names, and tab names are mutable or non-unique labels.
  A full normalized root is needed to distinguish equal basenames in separate
  repositories.
- Local term-sessions identity uses backend location and session name, not
  working directory. A generic session name such as `agent` can collide across
  worktrees unless automatic names incorporate the workspace identity.
- Gptel buffers do not carry project identity, so their task association must
  be stored as tab-local state.

### Magit leader precedence

- The normal and visual leaders are installed only in global Evil state maps
  at `profiles/common/.config/emacs/init.el:1325`.
- Magit's shared `magit-mode-map` binds plain `SPC` to
  `magit-diff-show-or-scroll-up`, and Evil Collection gives that overriding map
  precedence over global state maps.
- Layout shortcuts therefore would not be reachable from the Magit companion
  pane unless the existing leader maps are installed state-locally on
  `magit-mode-map`.
- `S-SPC` already retains the displaced Magit scroll action. Insert, Emacs, and
  Transient input must remain native.

## Decisions

1. Represent layouts as recipes over live buffers. Use one layout catalog, one
   dispatcher, and provider functions that return live companion buffers.
2. Make one tab represent one task root. Store the normalized root in
   `my/workspace-root`; switching a layout never creates another tab.
3. Select or create task tabs by root through direct `SPC p`. Never use the tab
   name as identity.
4. Store the primary edit buffer, companion cache, terminal target, agent
   target, and generic send target as tab properties.
5. Make each direct layout key deterministic and idempotent. Repeating a key
   does not alternate between split and focused views.
6. Layout actions create, reuse, and display buffers only. They never kill a
   buffer, process, or zmx session.
7. Keep lower-frequency terminal, AI, Git, and manual window operations in
   their current groups. Direct promotion is additive.
8. Use `SPC e` for focus edit and retain `SPC w z` as an exact alias of the
   same primary-buffer-aware action. Reserve `SPC z` for the historical
   unzoomed writing action; this layout plan does not add or change it.
9. Bind `SPC` state-specifically on `magit-mode-map` in normal and visual
   states so layouts work from a Magit companion. If the exact entries already
   exist, reuse them. Never unset Magit's ordinary map entry.
10. Generalize the existing right-split action and share it between terminal
    transport and layout rendering.
11. Use public package entry points and preserve deferred loading.

The state-local Magit boundary is:

```elisp
(defvar magit-mode-map)
(evil-define-key 'normal magit-mode-map
  (kbd "SPC") my/normal-leader-map)
(evil-define-key 'visual magit-mode-map
  (kbd "SPC") my/visual-leader-map)
```

This plan must produce these entries even when no other keybinding work has
been implemented. `evil-define-key` handles both deferred and already-loaded
Magit without forcing startup loading.

## Complete keybinding contract

Unless a row says otherwise, each leader sequence is available in Evil normal
and visual states globally and in modes derived from `magit-mode-map`. None is
added to Evil Insert or Emacs state, Ghostel character input, or Transient.

| Key | Disposition | Command or map | Scope and exact behavior |
| --- | --- | --- | --- |
| `SPC` | Retained globally, ensured locally in Magit | `my/normal-leader-map` or `my/visual-leader-map` | Makes the same leader reachable from a Magit companion in normal and visual states only. |
| `SPC p` | Added | Workspace selection command | Selects or creates a tab by normalized project or folder root. With a prefix argument, atomically rebinds the current tab. |
| `SPC e` | Added | Catalog `focus` through `my/layout-apply` | Restores the tab's primary edit buffer as the only window. |
| `SPC T` | Added | Catalog `terminal` through `my/layout-apply` | Shows edit left and the selected plain Ghostel or zmx terminal right. Uppercase preserves the lowercase terminal group. |
| `SPC A` | Added | Catalog `agent` through `my/layout-apply` | Shows edit left and the tab's coding-agent zmx session right. Uppercase preserves the lowercase AI group. |
| `SPC G` | Added | Catalog `gptel` through `my/layout-apply` | Shows edit left and the selected Gptel conversation right. Uppercase preserves the lowercase Git group. |
| `SPC M` | Added | Catalog `magit` through `my/layout-apply` | Shows edit left and Magit status for `my/workspace-root` right. |
| `SPC W` | Added | `my/layout-select` | Opens native completion over catalog layouts. It is not a recursive catalog entry. |
| `SPC w z` | Retained and retargeted | Catalog `focus` through `my/layout-apply` | Becomes an exact alias of `SPC e` instead of calling raw `delete-other-windows`. |
| `SPC w u` | Intentionally retained | `winner-undo` | Preserves manual and explicit layout history undo. |
| `SPC w r` | Intentionally retained | `winner-redo` | Preserves manual and explicit layout history redo. |
| `SPC g g` | Intentionally retained | `magit-status` | Remains the general Git route. `SPC M` changes only the view. |
| `SPC a c` | Intentionally retained | Normal: `gptel`; visual: `my/gptel-compose-region` | Remains conversation creation or visual-region composition. `SPC G` never consumes a selection. |
| `SPC a s` | Intentionally retained | `gptel-send` | Keeps prompt sending separate from view selection. |
| `SPC a r` | Intentionally retained | Visual: `gptel-rewrite`; no new normal binding | Keeps its current visual-only semantics. |
| `SPC t r` | Intentionally retained | `my/send-region-or-buffer-to-last-target` | Sends to the tab's last target. Applying `SPC A` synchronizes this target to the visible agent. |
| `SPC z` | Reserved and unchanged | Historical `my/write-mode-no-zoom` binding when present | Focus edit must not claim this key. This plan does not install or remove the writing binding. |
| `S-SPC` in Magit | Intentionally retained | `magit-diff-show-or-scroll-up` | Preserves scrolling after plain `SPC` becomes the normal or visual leader. |
| Plain `SPC` in Magit Insert or Emacs state | Intentionally retained | `magit-diff-show-or-scroll-up` from the ordinary Magit map | The ordinary Magit binding remains unchanged outside normal and visual states. |

All other current leader groups and leaves remain unchanged.

The Emacs package and buffer renderer is Ghostel. Ghostty is an external
terminal application and is outside these layouts. A plain Ghostel buffer is
owned by Emacs; a zmx session is durable and only rendered through Ghostel.

## Workspace and worktree contract

### Root resolution

Represent a task workspace with a full normalized directory, including any
TRAMP prefix:

1. Expand the selected directory and normalize it with
   `file-name-as-directory`.
2. Call nonprompting `project-current` with that directory.
3. If a project exists, use its `project-root`.
4. Otherwise use the selected directory itself as an ordinary folder root.
5. Normalize the final root again with `expand-file-name` and
   `file-name-as-directory`.

Do not use `project-name`, branch name, Git common directory, tab name, or a
`.bare` marker as identity. Do not call local-only `file-truename`
unconditionally because remote roots must retain their TRAMP identity.

### Workspace selection

The direct `SPC p` command performs this operation:

1. Prompt through public `project-prompt-project-dir`, which supports known
   projects and explicit directories. From a companion window, default from
   the saved primary edit buffer's `default-directory`; from an ordinary edit
   window, use the selected buffer directly.
2. Resolve the normalized workspace root.
3. Search `tab-bar-tabs` for a tab whose `my/workspace-root` exactly matches,
   then select it by public tab index.
4. If none exists, create a tab, store the root through `tab-bar-tabs-set`,
   derive a friendly initial name from the basename, and show Dired at the root
   as the initial primary edit buffer.
5. With a prefix argument, rebind the current tab. Resolve the root and prepare
   its Dired buffer first, then rebuild the tab, store it as
   `my/layout-edit-buffer`, commit the new root, and clear companion, terminal,
   agent, and send-target state. If preparation or rendering fails, preserve
   the old root, edit buffer, windows, and caches. Do not kill old resources.

In a new unbound tab, the first layout may initialize the root without a prompt
from the selected ordinary edit buffer: use its project root when available,
otherwise its `default-directory`. After a tab is bound, layouts never silently
change the root. A file from another real project reports a mismatch and
directs the user to `SPC p` or explicit rebind. Terminal `cd`, Gptel focus,
Magit focus, and other special buffers never redirect the workspace.

### Linked worktrees

From `<repo-dir>/`, selecting `branch1/` and `branch2/` produces two task tabs
because their normalized roots differ. Each tab owns its edit buffer, terminal
selection, agent descriptor, Gptel conversation, Magit resolution, and last
text target.

The parent remains a valid ordinary folder workspace for non-project tasks.
Its Magit provider reports that the root is not a repository and leaves the
layout unchanged. An explicitly selected `.bare/` folder may open Magit as a
bare control view, but it never substitutes for a worktree. Do not add the
parent or `.bare` to `project-vc-extra-root-markers`, which would collapse the
useful worktree boundaries.

One normalized root maps to one managed task tab. Separate worktrees support
concurrent branch tasks without a tag. Multiple independent task tabs for the
exact same root are outside this plan; add a task-instance identifier later if
that becomes necessary instead of overloading the mutable tab name.

## Layout catalog contract

Define `my/window-layouts` near the current terminal/session configuration at
`profiles/common/.config/emacs/init.el:452`. Each entry contains:

- a stable layout name;
- its direct leader key;
- a Which Key and completion label;
- an optional companion-buffer resolver;
- optional provider settings such as a zmx session, command, or Gptel buffer.

Use this initial shape:

```elisp
(defcustom my/window-layouts
  '((focus
     :key "e"
     :label "Focus edit")
    (terminal
     :key "T"
     :label "Edit + terminal"
     :buffer-function my/layout-terminal-buffer)
    (agent
     :key "A"
     :label "Edit + coding agent"
     :buffer-function my/layout-agent-buffer
     :session nil
     :command nil)
    (gptel
     :key "G"
     :label "Edit + Gptel"
     :buffer-function my/layout-gptel-buffer
     :buffer nil)
    (magit
     :key "M"
     :label "Edit + Magit"
     :buffer-function my/layout-magit-buffer))
  "Named window layouts and their direct leader bindings."
  :type 'sexp)
```

`nil` agent and Gptel settings mean select once and cache for the current task
tab. A fixed `:session`, optional zmx `:command`, or Gptel `:buffer` makes an
entry prompt-free. A literal fixed buffer or session is an explicit request to
share that resource across workspaces; automatic resources remain root-scoped.

Accept three zmx `:session` forms:

- `nil` selects and caches an existing session;
- a string names an intentionally shared session;
- a function receives the layout name and normalized root and returns a
  root-scoped physical name.

The standard root-scoped name uses a sanitized root basename, role, and the
first eight characters of `(secure-hash 'sha1 root)`, for example
`branch1-agent-a1b2c3d4`. Function form may create a missing session only when
the entry also supplies `:command`. A literal string is the only intentional
cross-workspace sharing form.

Use `my/layout-select` for catalog completion and `my/layout-apply` for every
entry binding. Install `SPC e`, `SPC T`, `SPC A`, `SPC G`, and `SPC M` from the
catalog so changing a key or label is a data-only edit. Bind `SPC W` separately
because the selector is not a recursive catalog entry.

## Tab-local state and rendering

### State

Add current-tab property accessors and use them for:

- `my/workspace-root`, the authoritative project or folder root;
- `my/layout-edit-buffer`, the primary editing buffer;
- `my/layout-companion-buffers`, an alist from layout name to cached buffer;
- `my/layout-terminal-target`, the plain-terminal zmx descriptor;
- `my/layout-agent-target`, the coding-agent zmx descriptor;
- the existing `my/send-text-last-target` property.

This access is used more than three times and replaces repeated manual
`tab-bar-tabs` scans and rewrites near
`profiles/common/.config/emacs/init.el:460` and
`profiles/common/.config/emacs/init.el:654`.

Mark rendered windows with a `my/layout-role` window parameter. An invocation
from a companion recovers the saved edit buffer. A selected ordinary edit
buffer may become the new primary only when its real project root matches the
workspace, or when it is a non-project buffer inside the folder workspace.
Stored non-file edit buffers remain valid when explicitly selected. A cached
dead companion is resolved again. A prefix argument forces companion
reselection even when its cache remains live.

### Rendering algorithm

`my/layout-apply` operates in this order:

1. Resolve and validate the catalog entry.
2. Read or initialize the tab root and validate the selected edit buffer.
3. Determine the primary edit buffer from the selected window role and tab
   state.
4. Resolve the companion with `default-directory` bound to the workspace root
   before changing the visible tree. Use `save-window-excursion` because
   package entry points may display or select buffers.
5. Reduce the current tab to one ordinary window, display the edit buffer, and
   mark it with the edit role.
6. For a companion layout, display the returned buffer on the right with the
   shared 50 percent action and mark it with the companion role.
7. Select the edit window and commit tab-local state only after success.

Rename `my/send-text-right-split-action` at
`profiles/common/.config/emacs/init.el:454` to
`my/right-split-action`, then update all existing terminal callers and tests.

## Companion provider contracts

### Terminal

`my/layout-terminal-buffer` returns a buffer and does not own final placement.
It binds `default-directory` to `my/workspace-root`. On first use or forced
reselection, it chooses among:

- project Ghostel, using `ghostel-project` under a real project root so the
  project's terminal is reused;
- folder Ghostel, using public `ghostel-create` under an ordinary folder root
  and caching the returned buffer;
- an existing zmx session, selected with public
  `term-sessions-read-existing-session-entry` and attached by passing the full
  entry to `term-sessions-open-with-frontend` with creation disabled;
- a new zmx session, deriving a root-scoped physical name and constructing an
  owned entry with at least `:type`, `:name`, `:directory`, and `:cwd` before
  passing it to `term-sessions-open` with the chosen command.

Do not call `ghostel-project` for an ordinary folder because its
`project-current t` contract could prompt for an unrelated project. Cache the
returned buffer. Because term-sessions returns only the frontend buffer, retain
the full descriptor separately as the tab's terminal target and generic text
target. This lets `SPC t r` keep addressing the durable session after a
disposable frontend is killed.

Add `term-sessions-read-existing-session-entry` and
`term-sessions-open-with-frontend` to the deferred `use-package :commands` at
`profiles/common/.config/emacs/init.el:443` alongside `term-sessions-open`.

### Coding agent

`my/layout-agent-buffer` associates visibility and text delivery with one full
zmx descriptor:

1. Reuse `my/layout-agent-target` when it is configured as a zmx identity.
2. Otherwise select through public
   `term-sessions-read-existing-session-entry` and save the full entry. An
   owned descriptor includes at least `:type`, `:name`, `:directory`, and
   `:cwd`.
3. Attach an existing target through
   `term-sessions-open-with-frontend` with creation disabled. If the durable
   session has ended, require explicit reselection instead of silently
   replacing it with a shell.
4. After attachment, copy the descriptor to `my/send-text-last-target` so
   `SPC t r` addresses the visible agent.

Perform selection and attachment with `default-directory` bound to the task
root. When a selected or function-configured descriptor exposes `:cwd`,
normalize and compare it with the workspace root. Reject an obvious different
worktree. A literal catalog `:session` is the explicit sharing exception and
bypasses cwd equality while preserving the real descriptor.

Do not infer an agent from the generic zmx send target. That target may be a
shell, REPL, or test process. Later `SPC t r` target selection must not replace
the saved agent association; applying `SPC A` restores the agent as the visible
and active send target.

A fixed session may create a missing session only when the catalog also
supplies the coding-agent command. Keep the default agent-neutral and do not
guess from process command lines.

The provisioner pins term-sessions to
`0815dbea006128df1d61e9d29e5a8ada53b349c1` at
`profiles/common/.config/emacs/install-packages.el:20`. Update the reviewed pin
to `acc872676ad2476187984056e7896aa0ea2b2dfc`, which exposes the existing
location-aware selector publicly. Replace the private selector call at
`profiles/common/.config/emacs/init.el:558`. Normal startup remains offline.

### Gptel

`my/layout-gptel-buffer` prompts for a new or existing conversation name on
first selection, then calls `(gptel name)` noninteractively with
`default-directory` bound to the task root. Cache the returned buffer in the
current tab until it is killed or forced reselection is requested.

Do not invoke Gptel interactively from this layout. In Evil visual state its
interactive contract copies the selected region into the initial prompt, while
a layout command must only change the view. Resolve inside
`save-window-excursion`; the common renderer owns the final split.

An optional catalog buffer name may bypass the first prompt. `SPC a` remains
the group for compose, rewrite, and send operations; `SPC G` only changes the
visible layout.

### Magit

`my/layout-magit-buffer` uses `my/workspace-root` on every call and invokes
public `magit-status-setup-buffer`, Magit's programmatic status entry point.
Let Magit reuse and refresh the repository buffer. Do not call interactive-only
`magit-status` from Lisp or cache one status buffer across roots.

For a non-repository parent, report an actionable error before changing the
visible layout. If `.bare/` was explicitly selected, allow its bare repository
view but never use it as a fallback for a worktree. Worktrees produce distinct
status buffers because their top levels and Git directories differ.

Add `magit-status-setup-buffer` to the deferred Magit commands at
`profiles/common/.config/emacs/init.el:105`. Resolve it inside
`save-window-excursion`; the renderer owns placement.

## Alternatives rejected

- Window states, configurations, or registers: they capture concrete buffers
  and cannot reliably recreate dead frontends or choose resources for another
  root.
- One tab per layout: a tab owns a task root and switches among views. One tab
  per view would fragment the task's state.
- Tab name or branch name as identity: both can change or collide.
- Git common directory as identity: linked worktrees share it and would leak
  task state.
- Parent or `.bare` as extra project root markers: this would collapse the
  useful linked-worktree boundaries.
- Remove nested bindings after adding direct equivalents: keep `SPC w z` and
  the lower-frequency groups for discovery and muscle memory.
- Put focus edit on `SPC z`: that key is reserved for the historical unzoomed
  writing action. Use free `SPC e`.
- Unset ordinary Magit `SPC`: this would alter Insert and Emacs states. Add
  state-local Evil bindings instead.
- Magit mode hooks or a global overriding minor map: one shared major-mode map
  binding covers all derived Magit buffers at the proper precedence.
- Global `display-buffer-alist` rules: scope display behavior to explicit
  layout actions.
- Transient as the layout mechanism: it can present a menu but does not own the
  required task and buffer state.
- Winner as the layout mechanism: keep it for history, but named layouts must
  be deterministic and independent of previous window operations.

## Phase 1: Establish task workspaces and focus editing

Status: pending

### Changes

1. Add current-tab property accessors near
   `profiles/common/.config/emacs/init.el:452`.
2. Implement normalized root resolution and direct `SPC p` selection, including
   lookup by property, tab creation, and atomic prefix rebind.
3. Track the root and primary edit buffer per tab and the edit role per window.
4. Define the `focus` catalog entry and the focus path of `my/layout-apply`.
5. Install `SPC p` and `SPC e` after workspace creation, selection, rebind, and
   deterministic focus work together.
6. Retarget `SPC w z` to the same catalog-backed focus action. Preserve Winner
   and the rest of the manual window group.
7. Add the state-local Magit leader entries required to invoke focus from a
   Magit pane. Reuse exact existing entries if already present.
8. Add focused tests for normalization, tab lookup, failure-preserving rebind,
   edit-buffer validation, Magit active-map access, and repeated focus.

### Success criteria

- Selecting `branch1/` and `branch2/` from their common parent creates two
  independent task tabs without manual tags.
- Root lookup survives tab renaming, reordering, and duplicate visible names.
- Prefix `SPC p` atomically rebinds the tab and preserves old state on failure.
- The parent and `.bare/` remain explicit choices and never replace a worktree.
- `SPC e` and `SPC w z` always produce the same single-window edit view and are
  idempotent.
- Invoking focus from a Magit pane works in normal and visual states while
  native Magit space behavior remains unchanged elsewhere.
- Terminal `cd`, a companion selection, or a file from another worktree cannot
  silently redirect the task root.

## Phase 2: Build the provider foundation

Status: pending

### Changes

1. Update the term-sessions pin to
   `acc872676ad2476187984056e7896aa0ea2b2dfc` and provision it explicitly.
2. Replace the private selector with
   `term-sessions-read-existing-session-entry` and declare the public selector
   and frontend opener in deferred `use-package :commands`.
3. Rename the shared right-split constant and update existing terminal callers
   and tests.
4. Extend tab-local state with terminal target, agent target, companion cache,
   and the existing send target.
5. Implement root-derived zmx physical names and full descriptor retention.

### Success criteria

- Explicit provisioning installs the reviewed revision and its upstream tests
  pass.
- Startup remains offline and term-sessions remains lazy-loaded.
- Existing terminal send and split behavior passes after the generalized name
  and public API change.
- Equal logical session names in different roots cannot collide when names are
  automatic.
- Full selected descriptors remain available after a frontend buffer is
  killed.

## Phase 3: Add configurable companion layouts

Status: pending

### Changes

1. Extend `my/layout-apply` with transactional two-pane rendering and add
   `my/layout-select`.
2. Implement the plain Ghostel and zmx terminal provider with separate project,
   folder, existing-session, and new-session paths.
3. Implement the coding-agent provider with independent tab-local identity,
   cwd validation, durable reattachment, and send-target synchronization.
4. Implement root-bound, noninteractive Gptel conversation selection and
   tab-local reuse.
5. Implement the root-derived Magit provider through
   `magit-status-setup-buffer`, including clear parent-folder failure and
   explicit bare-repository behavior.
6. Add provider entries only after their buffer contracts work. Install
   `SPC T`, `SPC A`, `SPC G`, and `SPC M` from the catalog and bind `SPC W`
   separately. Generate all layout labels from the catalog.
7. Update terminal and layout tests for generalized display, full descriptors,
   provider caching, and public term-sessions functions.

### Success criteria

- Repeating a companion layout produces exactly two 50 percent windows and
  never accumulates splits.
- Switching layouts preserves the edit buffer and replaces only the companion.
- Invoking any layout from either pane preserves the source editor and returns
  focus to it.
- Cancelling or failing provider selection preserves the previous windows and
  tab state.
- Task state and cached buffers never leak between tabs.
- `SPC T` reuses its selected live terminal and resolves it after buffer death.
- `SPC A` shows the same zmx session used by `SPC t r`; killing its frontend
  does not kill the durable session. Selecting another generic send target
  does not overwrite the saved agent.
- Automatic terminal and agent names do not collide between worktrees or equal
  basenames in different repositories. A literal session is the only cwd
  validation bypass.
- Entries with the same backend location and name but different `:cwd` remain
  distinguishable for validation.
- `SPC G` reuses its conversation until explicit reselection or buffer death
  and never consumes an Evil visual selection.
- `SPC M` follows the authoritative root after tab selection or rebind.
- The non-repository parent fails before changing the layout; an explicitly
  selected `.bare/` shows only its bare control view.
- No provider creates an extra split or kills a buffer or process.
- Winner undo and redo traverse explicit layout changes.

## Phase 4: Verify the independent layout system

Status: pending

### Automated verification

Add a behavior-focused suite at
`profiles/common/.config/emacs/window-layouts-test.el`. Keep the test count low
by grouping related assertions around these contracts:

1. root resolution, name-independent tab lookup, and atomic rebind;
2. direct/nested focus equivalence, repeated and switching layouts, tab-local
   state, and companion invocation;
3. Magit normal and visual leader access plus preserved `S-SPC`, Insert, Emacs,
   and Transient boundaries;
4. provider return and caching behavior using stubs instead of subprocesses;
5. root-scoped zmx targets, including equal name and location entries with
   different `:cwd`;
6. Gptel and Magit root context, cancellation, and failure preservation.

Update `profiles/common/.config/emacs/send-text-targets-test.el` only for the
generalized split name, full descriptors, and public selector. Do not add tests
that search source text for declarations.

Run:

```sh
emacs -Q --batch -L refs/emacs-term-sessions \
  -l refs/emacs-term-sessions/term-sessions-tests.el \
  -f ert-run-tests-batch-and-exit

emacs -Q --batch -l profiles/common/.config/emacs/init.el \
  --eval '(princ "CONFIG_LOADED\n")'

emacs -Q --batch \
  -l profiles/common/.config/emacs/window-layouts-test.el \
  -f ert-run-tests-batch-and-exit

emacs -Q --batch \
  -l profiles/common/.config/emacs/send-text-targets-test.el \
  -f ert-run-tests-batch-and-exit

emacs -Q --batch \
  --eval '(progn (find-file "profiles/common/.config/emacs/init.el") (check-parens))'

git diff --check
```

Byte-compile `init.el` and both focused tests into a temporary directory so no
generated files enter the profile.

### Manual verification

1. Exercise every direct layout from the editor and from its companion. Repeat
   and switch layouts, then use Winner undo and redo.
2. Confirm `SPC e` and `SPC w z` always return to the same primary edit buffer.
3. Confirm one plain Ghostel project terminal, one local or remote zmx coding
   agent, one Gptel conversation, and one Magit status buffer are reused without
   duplicate windows.
4. Kill only a zmx frontend, apply `SPC A`, and confirm attachment to the
   still-running session.
5. Create a disposable bare clone with `branch1/` and `branch2/` worktrees.
   From the parent, select each with `SPC p` and confirm distinct edit buffers,
   terminals, zmx names, agents, conversations, Magit buffers, and send targets.
6. Rename both worktree tabs to the same visible name and repeat. Then visit the
   parent and `.bare/` explicitly and confirm their documented behavior.
7. From Magit status, diff, and log panes, invoke layout keys in normal and
   visual states. Confirm `S-SPC`, Insert and Emacs plain space, and Transient
   input remain native.

### Final success criteria

- One normalized root owns one task tab and its complete layout state.
- Linked worktrees run as concurrent task workspaces from a common parent
  without tags or name-based identity.
- Every common layout action is one key after `SPC`, while nested and grouped
  routes remain available.
- Adding a layout is localized to the catalog and, only for distinct lifecycle
  semantics, one provider.
- Layout application is deterministic, transactional, and resource-preserving.
- Offline startup, upstream and focused ERT, byte compilation, `check-parens`,
  and `git diff --check` pass.
- Phase statuses and measured results are recorded in this file during
  implementation.
