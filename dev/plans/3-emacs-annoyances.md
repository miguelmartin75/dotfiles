# Emacs annoyances implementation plan

## Goals grouped by area

### Keybindings

- Restore the historical direct writing bindings: `SPC Z`, `SPC z`, and
  `SPC v`.
- Add direct `SPC l` for line numbers while retaining `SPC h l` as its nested
  alias.
- Add direct workspace and layout bindings under `SPC p`, `SPC e`, `SPC T`,
  `SPC A`, `SPC G`, `SPC M`, and `SPC W` without displacing the restored
  writing workflow.
- Make the same normal-state and visual-state leader maps reachable in Magit
  while preserving Magit's native space behavior outside those states.
- Retain `SPC w z` as the nested alias for the new primary-buffer-aware
  `SPC e` focus action. Preserve the grouped AI, Git, terminal, and manual
  window commands alongside the new direct bindings.

### Layouts and workspaces

- Treat one tab as one project or folder task workspace, identified by a full
  normalized root rather than its mutable tab name.
- Provide deterministic focus, terminal, coding-agent, Gptel, and Magit
  layouts through one configurable catalog.
- Preserve the primary editing buffer, companion choice, terminal target, and
  AI context independently for concurrent linked Git worktrees.
- Rebuild layouts from live resources without killing buffers, terminal
  processes, or durable zmx sessions.

### Other UI, typography, and completion changes

- Show logical relative line numbers by default in programming buffers.
- Render Eglot inlay hints and backtick-delimited Markdown inline code at the
  same apparent height as surrounding text.
- Raise the maximum height of the `*Completions*` window from 10 to 14 lines
  while retaining the current eager, one-column native completion UI.

The complete state, conflict, command, and behavior contract for every binding
changed or deliberately preserved by this plan is in
`Complete keybinding contract` below.

## Reasoning

Use one tab as one task workspace, and give the tab an explicit normalized
directory property named `my/workspace-root`. The property is the identity;
the tab name is only a label. Layouts read that root and never infer ownership
from the selected companion buffer, a terminal's current directory, a branch
name, or the visible tab name.

This design supports linked Git worktrees without special Git parsing. An
Emacs 31.1 fixture with the shape below produced these results:

| Directory | Emacs project result | Planned workspace behavior |
| --- | --- | --- |
| `<repo-dir>/` | No project | May be an ordinary folder workspace, but `SPC p` is the fast path to select a source worktree. |
| `<repo-dir>/.bare/` | No project | Only an explicitly selected bare-repository control workspace; it is never substituted for a source worktree. |
| `<repo-dir>/branch1/` | Project rooted at `branch1/` | Independent task tab and layout state. |
| `<repo-dir>/branch2/` | Project rooted at `branch2/` | Independent task tab and layout state. |

Git linked worktrees share repository metadata while retaining distinct
working trees, `HEAD`, and index state. Emacs `project.el` recognizes each
linked worktree's `.git` file as a separate project. Therefore `branch1/` and
`branch2/` already provide the correct task identities even when Emacs was
started from their common parent. No manual tag is required. Running `SPC p`
once for each worktree creates or selects two independently rooted task tabs,
and layouts, terminal targets, agents, Gptel conversations, and Magit buffers
remain separate.

The tab name must not be used as a key. Emacs describes tabs as named window
configurations, but names can be edited and are not required to be unique.
The implementation may derive a friendly initial name from the root basename;
renaming it or giving two tabs the same name must not change workspace
ownership. An explicit rebind command changes the root property and clears the
tab's context-dependent layout cache without killing its buffers or processes.

Markdown inline code has a separate but related typography cause. The
configuration sets `default` to JetBrains Mono but does not bind `fixed-pitch`
to that face. Both Emacs 31 `markdown-ts-mode` and package `markdown-mode`
derive inline code from a fixed-pitch code face, so the generic `Monospace`
family may have visibly smaller metrics. Make the repo theme's `fixed-pitch`
face inherit `default`, then explicitly keep both inline-code faces at relative
height `1.0`. This fixes the shared font contract instead of compensating with
an arbitrary enlargement for one Markdown implementation.

Preserve the pre-rebuild writing workflow exactly: `SPC Z` enters zoomed
writing mode, `SPC z` enters unzoomed writing mode, and `SPC v` returns to the
default editing view. The functions still exist, so only their direct leader
entries were lost. Because the proposed focus layout has not been implemented
yet, move that layout to free `SPC e` instead of displacing established muscle
memory or adding compatibility aliases.

Promoting a common action to a direct leader key is additive. Keep its existing
nested route for discovery and muscle memory. `SPC h l` continues to call the
native line-number toggle alongside direct `SPC l`. `SPC w z` continues to mean
focus editing, but both it and direct `SPC e` must call the new
primary-buffer-aware focus action rather than leaving the nested key on raw
`delete-other-windows` with different behavior.

Magit requires a state-local leader integration. Its shared major-mode map
binds plain `SPC` to diff scrolling, and Evil Collection elevates Magit's maps
above the global Evil state maps. Bind the existing normal and visual leader
maps to `SPC` through Evil's public `evil-define-key` on `magit-mode-map`.
This changes only Evil normal and visual states. Magit's displaced scroll-up
action remains on `S-SPC`, while Insert, Emacs, and Transient input retain their
native behavior.

The current native completion setup already exposes the intended control:
`completions-max-height` is the maximum height of the `*Completions*` window.
It is currently set to 10 together with eager display and one-column output.
Set that variable directly to 14. No display-buffer rule, advice, or window
resizing hook is needed.

References:

- Git worktree model: https://git-scm.com/docs/git-worktree.html
- Emacs project model: https://www.gnu.org/software/emacs/manual/html_node/emacs/Projects.html
- Emacs tab-bar model: https://www.gnu.org/software/emacs/manual/html_node/emacs/Tab-Bars.html

## Status

- Plan: complete
- Implementation: not started
- Target: Emacs 31.1+
- Primary configuration: `profiles/common/.config/emacs/init.el`
- Theme: `profiles/common/.config/emacs/themes/mig-one-light-theme.el`
- Package provisioner: `profiles/common/.config/emacs/install-packages.el`
- Existing terminal tests: `profiles/common/.config/emacs/send-text-targets-test.el`
- Planned layout tests: `profiles/common/.config/emacs/window-layouts-test.el`
- Prior architecture: `dev/plans/emacs-config-changes.md` and
  `dev/plans/emacs-config-changes-followups-1.md`

The current configuration contains a recently rebuilt native completion block
starting at `profiles/common/.config/emacs/init.el:915`. Preserve its eager,
one-column architecture while changing only the requested maximum window
height.

## Current behavior and root causes

### Line numbers

- The pre-rebuild configuration bound `display-line-numbers-mode` directly to
  `SPC l`. Commit `544f123` moved it into the help group as `SPC h l`; the
  current binding is at `profiles/common/.config/emacs/init.el:1299`.
- `SPC l` is currently unused, so the old direct interaction can be restored
  without a conflict.
- `profiles/common/.config/emacs/init.el:1417` disables the global mode and sets
  `display-line-numbers-type` to `visual`. It never enables the buffer-local
  mode for source buffers.
- Emacs treats `visual` and `relative` as different modes. `relative` counts
  logical buffer lines; `visual` counts wrapped screen lines. The requested
  source-editing behavior is `relative`.

### Eglot inlay hint height

- Emacs 31.1's built-in Eglot defines `eglot-inlay-hint-face` with a height of
  `0.8` and inheritance from `shadow`. Its type and parameter hint faces inherit
  that base face.
- `profiles/common/.config/emacs/init.el:844` configures Eglot behavior but does
  not override the face.
- `profiles/common/.config/emacs/themes/mig-one-light-theme.el:58` styles
  `shadow` but does not style the Eglot inlay face, so Eglot's smaller upstream
  default remains visible.

### Markdown inline-code height

- `profiles/common/.config/emacs/init.el:1107` prefers built-in
  `markdown-ts-mode` when both Markdown parsers are available, and falls back to
  package `markdown-mode` or `gfm-mode`.
- Emacs 31's `markdown-ts-code-span` inherits `markdown-ts-code-block`, whose
  upstream base is `fixed-pitch`. Package `markdown-inline-code-face` inherits
  `markdown-code-face`, whose upstream base is also `fixed-pitch`.
- `profiles/common/.config/emacs/init.el:1455` sets `default` to JetBrains Mono
  at 13.5 points but leaves `fixed-pitch` on its generic `Monospace` family.
  Equal nominal point sizes can therefore have different visible glyph
  metrics.
- `profiles/common/.config/emacs/themes/mig-one-light-theme.el:163` styles
  package Markdown faces but does not establish a shared fixed-pitch family or
  style built-in `markdown-ts-code-span`.

### Completion window height

- The native completion block at
  `profiles/common/.config/emacs/init.el:944` enables eager display, formats
  candidates in one column, and sets `completions-max-height` to 10 at
  `profiles/common/.config/emacs/init.el:955`.
- Emacs defines `completions-max-height` as the maximum height of the
  `*Completions*` buffer window. The current value is therefore the direct
  reason the completion window stops at 10 lines.
- The requested value is 14. This is a maximum, not a forced minimum: fewer
  candidates may still produce a shorter window.

### Window layouts

- The configuration already has the required low-level pieces:
  - a 50 percent right split action at
    `profiles/common/.config/emacs/init.el:454`;
  - tab-local terminal target state at
    `profiles/common/.config/emacs/init.el:460`;
  - plain Ghostel and zmx split commands at
    `profiles/common/.config/emacs/init.el:677` and
    `profiles/common/.config/emacs/init.el:696`;
  - Gptel at `profiles/common/.config/emacs/init.el:253`;
  - Magit at `profiles/common/.config/emacs/init.el:105`;
  - tab-bar workspaces at `profiles/common/.config/emacs/init.el:1148`;
  - Winner undo and redo bindings at
    `profiles/common/.config/emacs/init.el:1233` and mode enablement at
    `profiles/common/.config/emacs/init.el:1473`.
- `SPC w z` runs raw `delete-other-windows`. It focuses whichever window is
  selected, so invoking it from a terminal, Gptel, or Magit pane can discard the
  editing view instead of restoring it.
- Saved window states and registers capture concrete buffers and positions.
  They become stale when a terminal frontend is killed and cannot resolve a new
  zmx attachment or a Magit buffer for a different project.
- `project-current` returns no project for a linked-worktree container or its
  `.bare` repository, while each checked-out worktree is a separate VC project.
  The shared Git common directory is therefore the wrong layout identity.
- `project-name` and tab names are human-readable labels, not unique identity.
  Full normalized roots are required to distinguish equal branch or directory
  basenames in different repositories.
- Local term-sessions identity uses backend and session name, not working
  directory. Reusing a generic zmx name such as `agent` would collide across
  worktrees unless automatic names include the full workspace identity.
- Gptel buffers do not carry project identity. Their workspace association must
  be recorded in tab-local layout state.

### Leader ergonomics

The shared leader at `profiles/common/.config/emacs/init.el:1202` currently uses
lowercase `a`, `b`, `c`, `d`, `f`, `g`, `h`, `o`, `r`, `s`, `t`, and `w` as
groups. Direct bindings exist only for a few frequent actions such as `SPC ,`,
`SPC /`, `SPC m`, and `SPC j` at
`profiles/common/.config/emacs/init.el:1210`. The direct keys selected below are
currently free and do not require dismantling the useful lower-frequency
groups.

### Writing-mode shortcut regression

- Immediately before commit `544f123`, the direct leader bindings were
  `SPC Z` to `my/write-mode` with label `zen mode`, `SPC z` to
  `my/write-mode-no-zoom` with label `zen mode no zoom`, and `SPC v` to
  `my/default-mode` with label `code mode`.
- Commit `544f123` replaced General with the owned sparse leader restricted to
  Evil normal and visual states. It retained the commands but omitted their
  bindings.
- The commands remain at `profiles/common/.config/emacs/init.el:1496`:
  `my/write-mode` enables Olivetti at width 60, scales text to 3, and disables
  line numbers; `my/write-mode-no-zoom` uses width 120, scale 0, and no line
  numbers; `my/default-mode` disables Olivetti, restores scale 0, and enables
  line numbers.
- `my/center-window` also remains, but Git history contains no leader binding
  for it. Do not invent one as part of shortcut preservation.

### Magit leader precedence

- The normal and visual leaders are installed only in global Evil state maps at
  `profiles/common/.config/emacs/init.el:1325`.
- Magit's shared `magit-mode-map`, inherited by status, diff, log, process, and
  other Magit major modes, binds plain `SPC` to
  `magit-diff-show-or-scroll-up`.
- Evil Collection makes the Magit maps overriding maps. Evil's local
  mode-and-state bindings outrank those overriding maps, but the current global
  state binding does not. A batch probe in `magit-status-mode` therefore
  resolves normal-state `SPC` to Magit scrolling instead of
  `my/normal-leader-map`.
- Evil Collection retains the displaced Magit scroll-up action on `S-SPC`.
  Unsetting plain `SPC` in the ordinary Magit map would also remove it from
  Insert and Emacs states, so it is not an acceptable fix.

## Decisions

1. Use `display-line-numbers-mode` directly. Do not add a wrapper that merely
   renames the native toggle.
2. Enable line numbers with `prog-mode-hook`, not the global mode plus an
   exception list. Programming modes are the requested default scope, while
   Org, prose, terminal, and special buffers remain off by default.
3. Set the default number type to `relative`. Do not add a cycle among
   absolute, relative, and visual modes without a concrete need for that third
   interaction.
4. Put appearance in the repo-owned theme. Override only
   `eglot-inlay-hint-face`; let Eglot's type and parameter faces continue to
   inherit it.
5. In the repo-owned theme, make `fixed-pitch` inherit the configured monospaced
   `default` face. Set both Markdown inline-code faces to relative height
   `1.0`, preserving their existing colors and backgrounds.
6. Represent layouts as recipes over live buffers. Use one layout catalog, one
   dispatcher, and provider functions that return a live companion buffer.
7. Make one tab represent one task workspace. Store its full normalized project
   or folder root in `my/workspace-root`; apply every layout inside that tab.
   A view change must not create another tab.
8. Select task workspaces with direct `SPC p`. Find an existing tab by its root
   property or create and bind a new tab. Never find a tab by its name.
9. Store the primary editing buffer and cached companions as tab properties,
   following the existing per-tab terminal target design. Invoking a layout
   from its right pane must preserve the associated editing buffer.
10. A layout key selects a layout deterministically. Repeating it must be
   idempotent, not alternate between split and focused states.
11. Layout changes only create, reuse, and display buffers. They must not kill a
    buffer, terminal process, or zmx session.
12. Keep detailed terminal, AI, Git, and manual window operations under their
    current lowercase groups. Promote only the restored writing commands,
    common layouts, line-number toggle, and task workspace selection to direct
    keys. Direct promotion does not remove an existing nested route.
13. Restore `SPC Z`, `SPC z`, and `SPC v` exactly in the shared leader table,
    so they remain available in Evil normal and visual states only. Move the
    new focus-edit layout to `SPC e`; do not wrap, alias, or change the existing
    writing commands.
14. After the leader maps are defined, bind `SPC` state-specifically on
    `magit-mode-map` with public `evil-define-key`: normal uses
    `my/normal-leader-map` and visual uses `my/visual-leader-map`. Do not unset
    Magit's ordinary `SPC`, add per-buffer hooks, or create a global overriding
    minor mode.
15. Set `completions-max-height` directly from 10 to 14 in the existing native
    completion settings. Do not add a `display-buffer-alist` entry or resizing
    hook for `*Completions*`.
16. Retain `SPC h l` as an alias of direct `SPC l`. Retain `SPC w z`, but
    retarget it from raw `delete-other-windows` to the same catalog-backed focus
    action used by `SPC e`, so the two routes cannot diverge.

Use the major-mode map variable, not a quoted minor-mode symbol:

```elisp
(defvar magit-mode-map)
(evil-define-key 'normal magit-mode-map
  (kbd "SPC") my/normal-leader-map)
(evil-define-key 'visual magit-mode-map
  (kbd "SPC") my/visual-leader-map)
```

`evil-define-key` delays these bindings until `magit-mode-map` exists when
Magit is lazy-loaded. If Difftastic has already loaded Magit, it applies them
immediately. In both orders this code runs after Evil Collection setup and
leaves the ordinary Magit map unchanged.

## Complete keybinding contract

Unless a row says otherwise, a leader sequence is available in Evil normal
and visual states through `my/normal-leader-map` and `my/visual-leader-map`.
That includes Magit buffers after the state-local fix. None of these leader
sequences is added to Evil Insert or Emacs state, Ghostel character input, or a
Transient keymap.

| Key | Disposition | Command or map | States and scope | Conflict and exact behavior |
| --- | --- | --- | --- | --- |
| `SPC` | Retained globally, added locally in Magit | `my/normal-leader-map` or `my/visual-leader-map` | Evil normal or visual state globally and in all modes derived from `magit-mode-map` | Magit's overriding map currently wins over the global leader. Add state-local Magit bindings only. Do not change plain space in Insert, Emacs, or Transient input. |
| `SPC l` | Added as a direct alias | `display-line-numbers-mode` | Normal and visual; buffer-local action | Directly toggles logical relative line numbers in the current buffer. `SPC l` is currently free. |
| `SPC h l` | Intentionally retained | `display-line-numbers-mode` | Normal and visual; buffer-local action | Preserves the existing nested help-group route with exactly the same behavior as `SPC l`. |
| `SPC Z` | Restored | `my/write-mode` | Normal and visual | Historical binding. Enables Olivetti width 60, text scale 3, and disables line numbers. No conflict with lowercase `SPC z`. |
| `SPC z` | Restored | `my/write-mode-no-zoom` | Normal and visual | Historical binding. Enables Olivetti width 120, resets text scale, and disables line numbers. This displaces the plan's earlier unimplemented focus-layout proposal, not a current binding. |
| `SPC v` | Restored | `my/default-mode` | Normal and visual | Historical binding. Disables Olivetti, resets text scale, and enables line numbers. |
| `SPC p` | Added | Workspace selection command | Normal and visual | Selects or creates a tab by normalized project or folder root. With a prefix argument, atomically rebinds the current tab. The direct key is currently free. |
| `SPC e` | Added | Catalog `focus` layout through `my/layout-apply` | Normal and visual | Restores the tab's primary edit buffer as the only window. Chosen because `SPC z` belongs to the historical writing workflow. The direct key is currently free. |
| `SPC T` | Added | Catalog `terminal` layout through `my/layout-apply` | Normal and visual | Shows edit left and the selected plain Ghostel or zmx terminal right. Uppercase avoids the retained lowercase terminal group. |
| `SPC A` | Added | Catalog `agent` layout through `my/layout-apply` | Normal and visual | Shows edit left and the tab's coding-agent zmx session right. Uppercase avoids the retained lowercase AI group. |
| `SPC G` | Added | Catalog `gptel` layout through `my/layout-apply` | Normal and visual | Shows edit left and the selected Gptel conversation right. Uppercase avoids the retained lowercase Git group. |
| `SPC M` | Added | Catalog `magit` layout through `my/layout-apply` | Normal and visual | Shows edit left and Magit status for `my/workspace-root` right. Direct key is currently free. |
| `SPC W` | Added | `my/layout-select` | Normal and visual | Opens native completion over all catalog layouts. It is separate from the catalog's recursive entries. Uppercase avoids the retained lowercase window group. |
| `SPC w z` | Retained and retargeted | Catalog `focus` layout through `my/layout-apply` | Normal and visual | Preserves the existing nested focus route, but replaces raw `delete-other-windows` with exactly the same primary-buffer-aware action as `SPC e`. |
| `SPC w u` | Intentionally retained | `winner-undo` | Normal and visual | Keeps layout and manual-window history undo. No conflict with direct layouts. |
| `SPC w r` | Intentionally retained | `winner-redo` | Normal and visual | Keeps layout and manual-window history redo. No conflict with direct layouts. |
| `SPC g g` | Intentionally retained | `magit-status` | Normal and visual, including Magit after the fix | Keeps the general Git command route. `SPC M` is only the workspace layout shortcut. |
| `SPC a c` | Intentionally retained | Normal: `gptel`; visual: `my/gptel-compose-region` | Normal and visual with state-specific AI maps | Keeps conversation creation or region composition. `SPC G` changes only the layout and never consumes the visual selection. |
| `SPC a s` | Intentionally retained | `gptel-send` | Normal and visual | Keeps prompt sending separate from layout selection. |
| `SPC a r` | Intentionally retained | Visual: `gptel-rewrite`; no new normal binding | Evil visual state only | Keeps visual rewrite semantics. The plan does not broaden it to normal state. |
| `SPC t r` | Intentionally retained | `my/send-region-or-buffer-to-last-target` | Normal and visual | Replays to the tab's last target or prompts when absent. Applying `SPC A` synchronizes this target to the visible agent. |
| `S-SPC` in Magit | Intentionally retained | `magit-diff-show-or-scroll-up` | Magit normal and visual states | Preserves the displaced Magit scroll-up action after plain `SPC` becomes the state-local leader. |
| Plain `SPC` in Magit Insert or Emacs state | Intentionally retained | `magit-diff-show-or-scroll-up` from the ordinary Magit map | Magit Insert and Emacs states | The plan must not replace or unset the ordinary Magit binding in these states. Transient input remains governed by its own map. |

The rest of the current lowercase `SPC a`, `SPC g`, `SPC t`, and `SPC w`
groups remains unchanged. The table enumerates every leaf whose behavior the
plan relies on, adds, retargets, restores, or deliberately protects from the
new direct layout keys.

The Emacs package and buffer renderer is named Ghostel. Ghostty is the external
terminal application and is not controlled by these layouts. A plain Ghostel
buffer is owned by Emacs; a zmx session is durable and merely rendered through
Ghostel.

## Workspace and worktree contract

### Root resolution

Represent a task workspace with a full normalized directory, including any
TRAMP prefix. Resolve it as follows:

1. Expand the selected directory and normalize it with
   `file-name-as-directory`.
2. Call nonprompting `project-current` with that directory.
3. If a project exists, use its `project-root`.
4. Otherwise use the selected directory itself as an ordinary folder root.
5. Normalize the final chosen root again with `expand-file-name` and
   `file-name-as-directory`.

Do not use `project-name`, the current branch, the Git common directory, the
tab name, or a `.bare` marker as identity. Do not call local-only
`file-truename` unconditionally because remote workspace roots must preserve
their TRAMP identity.

The public `SPC p` workspace command performs this operation:

1. Prompt through public `project-prompt-project-dir`, which supports known
   projects and explicit arbitrary directories. From a companion window,
   default from the stored primary edit buffer's `default-directory`; from an
   ordinary edit window, use the selected buffer directly.
2. Resolve the normalized workspace root.
3. Search `tab-bar-tabs` for a tab whose `my/workspace-root` property exactly
   matches the root, then select that tab by its public tab index.
4. If none exists, create a tab, set `my/workspace-root` through
   `tab-bar-tabs-set`, derive a friendly initial name from the root basename,
   and show Dired at the root as the initial primary edit buffer.
5. With an explicit prefix argument, rebind the current tab to the selected
   root instead of selecting or creating another tab. Make this atomic: resolve
   the root and prepare its Dired buffer first; then rebuild the tab to that
   buffer, store it as `my/layout-edit-buffer`, commit `my/workspace-root`, and
   clear the companion cache, terminal target, agent target, and send target.
   If preparation or rendering fails, preserve the old root, edit buffer,
   window tree, and caches. Do not kill the old buffers or processes.

In a newly created, unbound tab, the first layout invocation may initialize the
root without prompting from the selected ordinary edit buffer: use its
nonprompting project root when available, otherwise its `default-directory`.
After a tab is bound, layouts never silently change its root. If the selected
file belongs to a different real project, report the mismatch and direct the
user to `SPC p` or explicit rebind. Terminal `cd`, Gptel focus, Magit focus, and
other special buffers must never redirect the workspace.

### Linked-worktree behavior

From `<repo-dir>/`, `SPC p` may select `<repo-dir>/branch1/` and then
`<repo-dir>/branch2/`. This produces two task tabs because the normalized
project roots differ. Each tab owns its edit buffer, terminal selection, zmx
agent descriptor, Gptel conversation, Magit buffer resolution, and last text
target. Layout keys always operate on the selected task tab.

The parent folder is still a valid ordinary folder workspace for operations
that do not require a project. Its Magit provider must report that the root is
not a repository and leave the current layout unchanged. An explicitly chosen
`.bare/` folder may open Magit as a bare-repository control view, but it is not
a source-worktree task and must never redirect automatically to `branch1/` or
`branch2/`. Do not add the parent or `.bare` as a
`project-vc-extra-root-markers` entry because that would collapse the useful
worktree boundaries.

One normalized root maps to one managed task tab. Separate linked worktrees are
therefore sufficient for concurrent branch tasks without a tag. Multiple
independent task tabs for the exact same root are outside this plan; if that
later becomes necessary, add a separate task-instance identifier rather than
overloading the mutable tab name.

## Layout configuration contract

Define `my/window-layouts` near the existing terminal/session configuration at
`profiles/common/.config/emacs/init.el:452`. Each entry contains:

- a stable layout name;
- its direct leader key;
- a Which Key/completion label;
- an optional companion-buffer resolver;
- optional provider settings, such as a root-derived or fixed zmx session and a
  Gptel buffer.

The initial catalog contains `focus`, `terminal`, `agent`, `gptel`, and `magit`.
Adding a layout whose companion already has a public buffer-returning command
requires one catalog entry. A new resolver is warranted only when the resource
has different selection or lifecycle semantics.

Use this catalog shape:

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

`nil` agent and Gptel settings mean select once and cache the result for the
current workspace tab. A fixed `:session`, optional zmx `:command`, or Gptel
`:buffer` makes that entry prompt-free. A literal fixed buffer or session is an
explicit request to share that resource across workspaces; automatic resources
remain root-scoped. Keep provider-specific settings in the entry that consumes
them instead of introducing parallel global configuration.

Accept three zmx `:session` forms: `nil` selects and caches an existing session,
a string names an intentionally shared session, and a function receives the
layout name and normalized workspace root and returns a root-scoped name. The
standard root-scoped naming function uses a sanitized root basename plus the
role and the first eight characters of `(secure-hash 'sha1 root)`. Function
form is an opt-in for a prompt-free configured session and may create a missing
session only when the entry also supplies `:command`. A literal string is the
only form that intentionally shares one session across roots.

Use `my/layout-select` for catalog completion and `my/layout-apply` for all
layout-entry bindings. Install `SPC e`, `SPC T`, `SPC A`, `SPC G`, and `SPC M`
from the catalog so changing a layout key or label is a data-only edit. Bind
`SPC W` separately to `my/layout-select` and give it a separate Which Key label;
the selector is not itself a recursive layout entry. The catalog is the single
source of truth for layout dispatch and layout labels.

### Tab-local state

Add small current-tab property accessors and use them for:

- `my/workspace-root`, the tab's authoritative normalized project or folder;
- `my/layout-edit-buffer`, the tab's primary editing buffer;
- `my/layout-companion-buffers`, an alist of layout name to cached live buffer;
- `my/layout-terminal-target`, the tab's plain-terminal zmx descriptor;
- `my/layout-agent-target`, the tab's coding-agent zmx descriptor;
- the existing `my/send-text-last-target` property.

This shared access is used more than three times and removes the repeated
manual `tab-bar-tabs` scan and rewrite at
`profiles/common/.config/emacs/init.el:460` and
`profiles/common/.config/emacs/init.el:654`.

Mark the rendered left and right windows with a `my/layout-role` window
parameter. When a layout is invoked from a companion window, recover the saved
edit buffer. A selected ordinary buffer in the edit window may promote its
current live buffer only when its real project root matches
`my/workspace-root`, or when it is a non-project buffer whose
`default-directory` is inside the folder workspace. This lets switching files
inside the task update the layout source without allowing a file from another
worktree to silently rebind the tab. Stored non-file editing buffers remain
valid when explicitly selected as the primary buffer. If a cached companion
has been killed, resolve it again. A prefix argument forces companion selection
again even when the cache is live.

### Rendering algorithm

`my/layout-apply` performs the following operation in order:

1. Resolve and validate the layout entry.
2. Read or initialize the tab's workspace root, then validate the selected
   primary edit buffer against that root.
3. Determine the primary edit buffer from the selected window role and the
   current tab property.
4. Resolve the companion with `default-directory` bound to the workspace root
   before changing the visible tree, using
   `save-window-excursion` because package entry points may display or select
   their buffers.
5. Reduce the current tab to one ordinary window, display the edit buffer there,
   and mark it with the edit role.
6. For a companion layout, display the returned buffer to the right using the
   shared 50 percent `display-buffer-in-direction` action and mark that window
   with the companion role.
7. Select the editing window and update tab-local state only after the layout
   succeeds.

Rename `my/send-text-right-split-action` at
`profiles/common/.config/emacs/init.el:454` to the general
`my/right-split-action`, then update the existing terminal send and creation
callers. Terminal transport and layout rendering should share this display
policy rather than duplicate it.

## Companion provider contracts

### Terminal

`my/layout-terminal-buffer` returns a buffer and does not own final placement.
It always binds `default-directory` to `my/workspace-root`. On first use, or
with a prefix argument, it selects between:

- project Ghostel, using `ghostel-project` under a real project root so it
  returns and reuses that project's terminal at
  `refs/ghostel/lisp/ghostel.el:5290`;
- folder Ghostel, using public `ghostel-create` under an ordinary folder root
  and caching the returned buffer in the current workspace tab;
- an existing zmx session, selected with
  `term-sessions-read-existing-session-entry` and attached by passing the full
  returned entry to `term-sessions-open-with-frontend` with creation disabled;
- a new zmx session, for which the user enters a logical name, the provider
  derives its root-scoped physical name, constructs an owned entry containing
  `:type`, `:name`, `:directory`, and `:cwd`, and passes it to
  `term-sessions-open` with the selected command.

Do not call `ghostel-project` for an ordinary folder because its
`project-current t` contract would prompt for an unrelated project. Cache the
returned buffer for prompt-free reuse. term-sessions returns only the frontend
buffer, so retain the known full selected or constructed descriptor separately
as `my/layout-terminal-target` and as the current tab's text target. This keeps
`SPC t r` attached to the visible terminal after its disposable frontend is
killed.

term-sessions does not include working directory in local session identity.
Any interactively or function-configured new zmx session therefore needs a
root-derived physical name:
sanitized root basename, logical role, and a short stable hash of the full
normalized root, for example `branch1-agent-a1b2c3d4`. Derive the name through
the catalog's session callback or new-session path so identical worktree
basenames in different repositories cannot collide. An exact literal
`:session` remains an intentional cross-workspace share.

Add both `term-sessions-read-existing-session-entry` and
`term-sessions-open-with-frontend` to the deferred `use-package :commands` at
`profiles/common/.config/emacs/init.el:443`, alongside the existing
`term-sessions-open`. This preserves lazy loading without calling private
autoload boundaries.

### Coding agent

`my/layout-agent-buffer` associates visibility and text delivery with the same
zmx descriptor:

1. Reuse the separate tab-local `my/layout-agent-target` descriptor when it is
   configured as a zmx identity.
2. Otherwise use the public `term-sessions-read-existing-session-entry` at
   `refs/emacs-term-sessions/term-sessions-frontends.el:404`, then save the full
   selected entry as the tab's coding-agent target. An owned descriptor must
   contain at least `:type`, `:name`, `:directory`, and `:cwd`; name plus
   directory identify attachment and send transport, while cwd is scope
   metadata.
3. Attach a selected existing target with public
   `term-sessions-open-with-frontend` and creation disabled, then return its
   buffer. If the zmx session itself has ended, require explicit reselection
   instead of silently replacing the agent with a login shell.
4. After successful attachment, copy the agent descriptor into
   `my/send-text-last-target` so `SPC t r` addresses the visible agent.

Perform selection and attachment with `default-directory` bound to
`my/workspace-root`. For a selected or function-configured descriptor that
exposes `:cwd`, normalize and compare it with the workspace root. Reject an
obvious different-worktree target and require explicit reselection; do not
silently attach `branch1`'s agent in the `branch2` task tab. A literal catalog
`:session` is the explicit sharing exception and bypasses cwd equality while
still retaining its actual descriptor for attachment.

Do not infer an agent from an arbitrary zmx send target. That target may be a
shell, REPL, test process, or another durable session. Later use of `SPC t r`
may change the generic send target without changing the saved agent
association; applying `SPC A` restores the agent as the visible and active send
target.

Permit the catalog entry to specify a fixed session name and optional creation
command for a fully prompt-free agent layout. A fixed entry may create a missing
session only when it also supplies the coding-agent command to start. Leave the
default agent-neutral; do not inspect a process command line to guess whether
it is Codex, Claude, or another agent.

The current provisioner pins term-sessions to
`0815dbea006128df1d61e9d29e5a8ada53b349c1` at
`profiles/common/.config/emacs/install-packages.el:20`, which predates this
public selector. Update the reviewed pin to
`acc872676ad2476187984056e7896aa0ea2b2dfc`. That is the single subsequent
upstream commit in the vendored reference, and its purpose is to expose the
existing location-aware selector. Then replace the private selector call at
`profiles/common/.config/emacs/init.el:558` with the public function. Keep
package installation explicit; normal startup must remain offline.

### Gptel

`my/layout-gptel-buffer` prompts for a new or existing conversation buffer name
on first selection, then calls `(gptel name)` noninteractively with
`default-directory` bound to `my/workspace-root`. Cache the buffer in the
current workspace tab and reuse it until it is killed or a prefix argument
requests another conversation. Gptel buffer names are not project identity.
Do not call Gptel interactively from this layout: in Evil visual state, its
interactive contract copies the active region into the initial prompt, while a
layout command must only change the view. Resolve it inside
`save-window-excursion`; the layout renderer, not Gptel's default display
action, owns the final split.

An optional catalog buffer name may bypass the first prompt and make a specific
conversation the default. `SPC a` remains the group for compose, rewrite, and
send operations; `SPC G` changes only the visible layout.

### Magit

`my/layout-magit-buffer` uses `my/workspace-root` every time and calls public
`magit-status-setup-buffer`, which is Magit's programmatic status entry point
and returns the status buffer. Let Magit reuse and refresh that repository
buffer. Do not call the interactive-only `magit-status` from Lisp, and do not
cache one status buffer across workspace roots.

For a non-repository parent folder, report an actionable error before changing
the visible layout. If `.bare/` was explicitly selected, allow Magit to show
the bare repository, but never use it as a fallback for a linked worktree. The
worktree roots themselves produce distinct Magit status buffers because their
top levels and Git directories are distinct.

Add `magit-status-setup-buffer` to the deferred Magit commands declared at
`profiles/common/.config/emacs/init.el:105` so the provider preserves the
configuration's lazy-loading contract.

Resolve Magit inside `save-window-excursion`, then place the returned buffer
through the common layout renderer. `SPC g` remains the Git command group;
`SPC M` is the fast edit-plus-status view.

## Alternatives rejected

- `window-state-get`, `window-state-put`, and window configuration registers:
  these snapshot concrete buffers and positions, so they cannot reliably
  recreate dead terminal frontends or select resources for a new project.
- One tab per layout view: tab-bar represents independent task roots and owns
  their state. A task tab may switch among every layout recipe; multiplying
  tabs for focus, terminal, Gptel, and Magit views would split one workspace's
  ownership. One tab per task root is the chosen model.
- Tab name or branch name as identity: both are presentation values and may be
  duplicated or changed. The normalized root is stable and distinguishes
  linked worktrees directly.
- Git common directory as identity: linked worktrees intentionally share it,
  so this would merge independent task buffers, terminals, agents, and Magit
  state.
- Remove nested bindings after adding direct equivalents: direct keys optimize
  frequent use, while nested routes preserve discovery and muscle memory. Keep
  `SPC h l`, and keep `SPC w z` on the corrected focus behavior.
- Keep focus edit on `SPC z` and move the old writing command: the focus layout
  is new, while `SPC z` is established muscle memory. Preserve the historical
  key and use free `SPC e` for focus edit.
- Unset `SPC` in `magit-mode-map`: this would expose the global Evil leader but
  also delete Magit's native space action from Insert and Emacs states. Add
  state-specific Evil bindings instead.
- Magit mode hooks or a global overriding minor map: a public binding on the
  shared Magit major-mode map handles every derived Magit buffer without
  per-buffer mutation or broader precedence changes.
- Global `display-buffer-alist` rules: these would affect every package display,
  not only explicit layout changes. Scope display actions to layout selection.
- Transient: it can present a menu but does not solve layout state. The native
  leader plus Which Key already supplies discovery.
- Winner as the layout mechanism: keep it for history and recovery, but named
  layouts must be deterministic and independent of the order of prior window
  changes.

## Phase 1: Restore direct editing controls and Magit leader access

Status: pending

### Changes

1. Add direct `SPC l` for `display-line-numbers-mode` in the shared leader
   binding table at `profiles/common/.config/emacs/init.el:1208`. Retain the
   existing `SPC h l` entry as the nested alias.
2. Restore `SPC Z`, `SPC z`, and `SPC v` in the same table with their historical
   commands. Do not add them to Insert or Emacs state maps.
3. In the existing `with-eval-after-load 'which-key` block, add leaf
   replacements for `Z` as `zen mode`, `z` as `zen mode no zoom`, and `v` as
   `code mode`. Do not change the binding table's simple `(key . command)`
   shape just to carry labels.
4. After `my/normal-leader-map` and `my/visual-leader-map` are complete, use
   `evil-define-key` on `magit-mode-map` to install the matching `SPC` map for
   normal and visual states. Rely on Evil's delayed binding support for Magit's
   deferred load; do not force Magit during startup.
5. Set `display-line-numbers-type` to `relative` at
   `profiles/common/.config/emacs/init.el:1418`.
6. Add `display-line-numbers-mode` to `prog-mode-hook` so current and future
   programming modes inherit the default without a language allowlist.
7. Remove the redundant terminal disable-hook loop. Those modes do not derive
   from `prog-mode`, so they remain off without an exception list.
8. Leave the implementations of `my/write-mode`, `my/write-mode-no-zoom`, and
   `my/default-mode` at `profiles/common/.config/emacs/init.el:1496` unchanged.

### Success criteria

- A newly opened programming buffer shows relative logical line numbers.
- Org, text, Ghostel, shell, and special buffers do not show line numbers by
  default.
- `SPC l` turns numbers off and on only in the current buffer from Evil normal
  and visual state.
- `SPC Z`, `SPC z`, and `SPC v` reproduce their historical Olivetti width,
  text-scale, and buffer-local line-number effects in normal and visual states.
  Which Key shows their exact historical leaf labels.
- In Magit status, diff, log, and process buffers, normal and visual `SPC`
  resolve to the matching leader map and representative sequences such as
  `SPC l` and `SPC g g` resolve normally.
- Magit `S-SPC` remains `magit-diff-show-or-scroll-up`. Magit Insert and Emacs
  states retain native plain-space behavior, and Transient input is unchanged.
- `SPC l` and `SPC h l` resolve to the same buffer-local command. No `SPC`
  leader exists in Insert or Emacs state.

## Phase 2: Normalize auxiliary text and completion height

Status: pending

### Changes

1. Add `eglot-inlay-hint-face` beside the core/syntax faces in
   `profiles/common/.config/emacs/themes/mig-one-light-theme.el:48`.
2. Set `:height 1.0` and preserve `:inherit shadow`.
3. Do not duplicate `eglot-type-hint-face` or
   `eglot-parameter-hint-face`; their upstream inheritance is the intended
   contract.
4. Add `fixed-pitch` beside `default` in the theme and make it inherit
   `default`. The configured default is already monospaced, so this removes the
   unintended generic-font metric difference without changing prose faces.
5. Add `:height 1.0` to the existing `markdown-inline-code-face` theme entry,
   retaining its `markdown-code-face` and `markdown-pre-face` inheritance.
6. Add `markdown-ts-code-span` with `:height 1.0` and its upstream
   `markdown-ts-code-block` and `font-lock-constant-face` inheritance. Do not
   replace Tree-sitter fontification or add mode hooks.
7. Leave the Eglot toggles at `profiles/common/.config/emacs/init.el:876` and
   `profiles/common/.config/emacs/init.el:1266` unchanged.
8. Change `completions-max-height` from 10 to 14 in the existing native
   completion settings at `profiles/common/.config/emacs/init.el:955`. Preserve
   eager display, eager update, the one-column format, completion navigation,
   and every category style.

### Success criteria

- The effective inlay hint height is `1.0` after loading or reloading
  `mig-one-light`.
- Type and parameter hints have the same effective height as normal buffer text
  while retaining the subdued `shadow` color.
- `eglot-inlay-hints-mode` still toggles buffer-local hints through its existing
  bindings.
- Backtick-delimited inline code has effective relative height `1.0` and the
  same JetBrains Mono family as surrounding text in `markdown-ts-mode`,
  `markdown-mode`, and `gfm-mode`.
- Inline code retains the theme's existing foreground, background, and markup
  behavior, including after `text-scale-adjust`.
- Other fixed-pitch content continues to use a monospaced face and now follows
  the configured default font metrics consistently.
- With more than 14 native candidates, the `*Completions*` window is at most 14
  lines high. With fewer candidates, Emacs may use fewer lines.
- Completion remains eager and one-column, and the existing `TAB`, `S-TAB`,
  `C-n`, and `C-p` navigation behavior is unchanged.

## Phase 3: Establish task workspaces and focus editing

Status: pending

### Changes

1. Add current-tab property accessors near
   `profiles/common/.config/emacs/init.el:452`.
2. Add normalized `my/workspace-root` resolution and direct `SPC p` workspace
   selection.
   Search tabs by the custom root property, select them by public index, and
   support atomic explicit current-tab rebind with a new Dired primary buffer
   and context-cache clearing.
3. Track the workspace root and primary edit buffer per tab, and the edit role
   per rendered window. Validate ordinary buffers against the stored root.
4. Define the first `my/window-layouts` entry for `focus` and the focus path of
   `my/layout-apply`. Do not bind unresolved companion entries yet.
5. Install direct `SPC p` and `SPC e` only after workspace creation, existing
   tab selection, atomic rebind, and deterministic focus work together.
6. Retain `SPC w z`, but bind it to the same catalog-backed focus action as
   direct `SPC e`. Retain the rest of the manual window group and Winner
   history.
7. Add focused tests for root normalization, name-independent tab lookup,
   failure-preserving rebind, edit-buffer validation, and repeated focus.

### Success criteria

- Starting from a linked-worktree parent, selecting `branch1/` and `branch2/`
  yields two independent task tabs without manual tags.
- `SPC p` selects workspace tabs by normalized root after tabs are renamed,
  reordered, or given duplicate visible names.
- Prefix `SPC p` atomically rebinds the current tab and displays Dired at the
  new root; any failure preserves the old root, edit buffer, windows, and state.
- The parent and `.bare/` remain explicit folder choices and never replace a
  linked worktree implicitly.
- `SPC e` always produces one window containing the task tab's primary edit
  buffer and remains idempotent.
- `SPC w z` produces the identical primary-buffer-aware focus result as
  `SPC e`; neither route calls raw `delete-other-windows` directly.
- A terminal `cd`, selected companion, or file from another worktree cannot
  silently redirect the task root.

## Phase 4: Add complete configurable companion layouts

Status: pending

### Changes

1. Update the reviewed term-sessions pin to
   `acc872676ad2476187984056e7896aa0ea2b2dfc`, provision it explicitly, replace
   the pinned private selector boundary with
   `term-sessions-read-existing-session-entry`, and declare all public frontend
   functions in deferred `use-package :commands`.
2. Generalize the right split action and extend current-tab state with terminal
   target, agent target, companion buffers, and the existing send target.
3. Extend `my/layout-apply` with deterministic two-pane rendering and define
   `my/layout-select`. Bind every provider's `default-directory` to the
   authoritative workspace root.
4. Implement the plain Ghostel/zmx terminal provider with separate project and
   ordinary-folder paths, distinct existing and creation flows, cached buffer
   selection, and separately retained full zmx descriptors.
5. Implement root-derived new zmx names using the root basename, logical role,
   and short stable hash. Treat a literal catalog session name as the sole
   explicit cross-workspace sharing exception.
6. Implement the zmx coding-agent provider with its own full tab-local entry,
   validate available working-directory metadata against the workspace, then
   synchronize the descriptor to the generic send target when the agent layout
   succeeds.
7. Implement the Gptel conversation provider with separate name selection,
   noninteractive root-bound buffer creation, and prompt-free tab-local reuse.
8. Implement the workspace-root-derived Magit provider through
   `magit-status-setup-buffer` without cross-root caching or parent-to-bare
   fallback.
9. Expand `my/window-layouts` with terminal, agent, Gptel, and Magit only after
   each provider works. Install `SPC T`, `SPC A`, `SPC G`, and `SPC M` from the
   catalog; bind `SPC W` separately; expose all layout labels to Which Key.
10. Update existing terminal functions and tests for the generalized split
    action, full descriptors, and public term-sessions functions.

### Success criteria

- Repeating any two-pane layout produces exactly two 50 percent windows and
  never accumulates splits.
- Switching layouts preserves the left editing buffer and replaces only the
  right companion.
- Layout state, agent association, and cached buffers do not leak across tabs.
- The parent folder and `.bare/` never replace a linked worktree implicitly.
  Magit reports a clear error for the non-repository parent; an explicitly
  selected `.bare/` shows only its bare-repository control view.
- Cancelling or failing companion selection leaves the previous visible layout
  and tab state intact.
- `SPC T` reuses the selected live terminal and resolves it again after its
  Emacs buffer is killed.
- Explicit provisioning installs the reviewed term-sessions revision, and its
  upstream test suite passes before configuration integration tests run.
- `SPC A` shows the same zmx session used by `SPC t r`; killing the Ghostel
  attachment does not kill the durable zmx session. Selecting an unrelated zmx
  send target does not replace the saved agent association.
- New terminal sessions and configured function-form agent sessions do not
  collide between worktrees or equal worktree basenames in different
  repositories. A literal shared catalog session works across roots and is the
  only bypass for cwd equality.
- Two selected entries with the same name and backend location but different
  `:cwd` values remain distinguishable for workspace validation.
- `SPC G` reuses the selected conversation until explicit reselection or buffer
  death and never copies an Evil visual selection into the conversation.
- `SPC M` follows `my/workspace-root` after selecting another task tab or
  rebinding the current one.
- Invoking each layout from either left or right preserves the source editor and
  returns focus to it.
- No provider creates an extra split or kills a buffer or process.
- Winner undo and redo can traverse explicit layout changes.

## Phase 5: Verify behavior and document completion

Status: pending

### Automated verification

Add a small behavior-focused suite in
`profiles/common/.config/emacs/window-layouts-test.el`. Keep the test count low
by grouping related assertions around six contracts:

1. line defaults, direct/nested line-number alias equivalence, Eglot and both
   Markdown inline-code face contracts, text scaling, and the native
   `*Completions*` maximum height;
2. historical writing bindings and behavior, plus Magit normal/visual leader
   precedence while Insert, Emacs, and `S-SPC` retain native behavior;
3. root resolution, tab lookup independent of name, and explicit rebind;
4. direct/nested focus alias equivalence, repeated/switching layouts, tab-local
   state, and companion invocation;
5. provider return/caching behavior using stubs instead of real subprocesses;
6. root-scoped zmx target state, including equal name/location entries with
   different `:cwd`, plus Gptel and Magit context.

For the leader-precedence contract, require Magit and Evil Collection and
iterate temporary buffers using `magit-status-mode`, `magit-diff-mode`,
`magit-log-mode`, and `magit-process-mode`. In each, force normal and visual
states and assert the exact `key-binding` results for `SPC` and a representative
leader sequence such as `SPC g g`. In the status buffer, also assert Insert and
Emacs `SPC` plus normal and visual `S-SPC`. This tests active-map precedence
rather than merely inspecting map contents while keeping state-isolation
assertions focused.

Update `profiles/common/.config/emacs/send-text-targets-test.el` only where the
general split name and public selector change its existing terminal contracts.
Do not add tests that search source text for declarations.

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

Byte-compile `init.el`, `mig-one-light-theme.el`, and the focused tests to a
temporary directory so generated files do not enter the profile.

### Manual verification

1. Open representative source, Org, and Ghostel buffers. Confirm the default
   line-number scope and toggle with both `SPC l` and `SPC h l` in each relevant
   buffer. Confirm both routes call the same buffer-local command.
2. Invoke `SPC Z`, `SPC z`, and `SPC v` from normal and visual states. Confirm
   their historical Olivetti widths, text scales, and line-number effects, and
   confirm those leader sequences are absent in Insert and Emacs states.
3. Open Magit status, diff, and log buffers. Confirm normal and visual leader
   sequences work, `S-SPC` still scrolls through Magit, and Insert and Emacs
   states retain native space behavior.
4. Start Eglot in a server-backed source file, enable inlay hints, and compare
   their glyph height with surrounding code before and after text scaling.
5. Open the same backtick-delimited inline-code sample in `markdown-ts-mode`
   and `markdown-mode` or `gfm-mode`. Compare its font family and glyph height
   with surrounding text before and after text scaling.
6. Invoke native completion with more than 14 one-column candidates. Confirm
   `*Completions*` is at most 14 lines high, then use a shorter candidate list
   and confirm Emacs may shrink the window. Verify `TAB`, `S-TAB`, `C-n`, and
   `C-p` navigation still work.
7. Exercise every direct layout from the editor and from its companion. Confirm
   `SPC e` and `SPC w z` produce the identical focus result. Repeat and switch
   layouts, then use Winner undo and redo.
8. Confirm one plain Ghostel project terminal, one local or remote zmx coding
   agent, one Gptel conversation, and one Magit status buffer are reused without
   duplicate windows.
9. Kill only the Emacs frontend for the zmx session, select `SPC A` again, and
   confirm it reattaches to the still-running session.
10. Create a disposable bare clone with linked `branch1/` and `branch2/`
   worktrees. Start in their parent, use `SPC p` to open each, and confirm
   distinct edit buffers, terminals, zmx names, agents, Gptel conversations,
   Magit status buffers, and send targets.
11. Rename both worktree tabs to the same visible name and repeat the layout
   checks. Confirm state remains rooted correctly. Then visit the parent and
   `.bare/` explicitly and confirm the documented folder and bare-repository
   behavior.

### Final success criteria

- All scoped annoyances are resolved without another package or global window
  policy.
- Every common action in this plan is one key after `SPC`.
- Lower-frequency grouped commands remain available and discoverable.
- Layout additions are localized to the catalog and, only when required, one
  resource-specific resolver.
- Linked worktrees can run as concurrent task workspaces from a common parent
  without manual tab tags or tab-name-based identity.
- Offline startup, focused ERT tests, byte compilation, `check-parens`, and
  `git diff --check` pass.
- Phase statuses and measured verification results are recorded in this file as
  implementation proceeds.
