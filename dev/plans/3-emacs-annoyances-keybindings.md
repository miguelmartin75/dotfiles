# Emacs keybindings implementation plan

## Reasoning

Frequent editing actions should be one key after `SPC`, while grouped routes
remain available for discovery and existing muscle memory. The implementation
should extend the owned sparse leader maps directly instead of adding a second
leader framework or command wrappers.

Line-number behavior belongs in this plan because the direct toggle and its
default state form one user-facing contract. Programming buffers should start
with logical relative line numbers, and both `SPC l` and the existing
`SPC h l` route should call the native buffer-local toggle.

Magit needs a state-local leader binding. Its shared major-mode map binds plain
`SPC` to diff scrolling, and Evil Collection gives Magit's maps precedence over
the global Evil state maps. Bind the existing leader maps to `SPC` through
Evil's public `evil-define-key` on `magit-mode-map` for normal and visual states
only. This preserves Magit's native plain-space behavior in Insert and Emacs
states and keeps the displaced scroll action on `S-SPC`. If the exact
state-local entries already exist, they satisfy this plan and must not be
duplicated.

This plan is independently implementable. It changes no workspace, layout,
terminal, Gptel, Magit layout, font, theme, or completion behavior.

## Goals

- Restore the historical direct writing bindings `SPC Z`, `SPC z`, and
  `SPC v`.
- Add direct `SPC l` while retaining `SPC h l` as an equivalent nested route.
- Enable logical relative line numbers by default in programming buffers.
- Make the normal-state and visual-state leader maps reachable in all Magit
  major modes without changing other Evil states or Transient input.
- Preserve lower-frequency grouped bindings.

## Status

- Plan: complete
- Implementation: in progress
- Target: Emacs 31.1+
- Primary configuration: `profiles/common/.config/emacs/init.el`
- Planned tests: `profiles/common/.config/emacs/leader-bindings-test.el`
- Prior architecture: `dev/plans/emacs-config-changes.md` and
  `dev/plans/emacs-config-changes-followups-1.md`

## Current behavior and root causes

### Leader structure

- The shared leader table begins at
  `profiles/common/.config/emacs/init.el:1202`; normal and visual maps are
  assembled at `profiles/common/.config/emacs/init.el:1302` and installed
  globally at `profiles/common/.config/emacs/init.el:1325`.
- Lowercase `a`, `b`, `c`, `d`, `f`, `g`, `h`, `o`, `r`, `s`, `t`, and `w`
  are groups. Only a few frequent commands are direct leader entries.
- `SPC l`, `SPC Z`, `SPC z`, and `SPC v` are currently free.

### Line numbers

- The pre-rebuild configuration bound `display-line-numbers-mode` directly to
  `SPC l`. Commit `544f123` moved it to `SPC h l`; the current nested binding
  is at `profiles/common/.config/emacs/init.el:1299`.
- `profiles/common/.config/emacs/init.el:1417` disables the global mode and
  sets `display-line-numbers-type` to `visual` on the next line. It does not
  enable the buffer-local mode for source buffers.
- `visual` counts wrapped screen lines. The requested `relative` mode counts
  logical buffer lines.
- The terminal disable-hook loop at
  `profiles/common/.config/emacs/init.el:1425` is unnecessary once line
  numbers are enabled only from `prog-mode-hook` because those terminal modes
  do not derive from `prog-mode`.

### Writing shortcuts

- Immediately before commit `544f123`, the direct leader bindings were
  `SPC Z` to `my/write-mode`, `SPC z` to `my/write-mode-no-zoom`, and `SPC v`
  to `my/default-mode`.
- The commands remain at `profiles/common/.config/emacs/init.el:1496`.
  `my/write-mode` uses Olivetti width 60, text scale 3, and no line numbers;
  `my/write-mode-no-zoom` uses width 120, text scale 0, and no line numbers;
  `my/default-mode` disables Olivetti, restores scale 0, and enables line
  numbers.
- `my/center-window` also remains, but Git history contains no leader binding
  for it. Do not invent one.

### Magit leader precedence

- The normal and visual leaders exist only in global Evil state maps.
- Magit's shared `magit-mode-map`, inherited by status, diff, log, process,
  and other Magit modes, binds plain `SPC` to
  `magit-diff-show-or-scroll-up`.
- Evil Collection makes Magit's maps overriding maps, so the ordinary global
  state binding loses. A mode-and-state binding on `magit-mode-map` has the
  required precedence.
- Evil Collection retains the scroll-up action on `S-SPC`. Unsetting ordinary
  `SPC` in `magit-mode-map` would also remove it from Insert and Emacs states.

## Decisions

1. Add bindings to the existing owned sparse leader maps. Do not add General,
   another prefix map, or wrappers around native commands.
2. Bind both `SPC l` and `SPC h l` directly to
   `display-line-numbers-mode`.
3. Set `display-line-numbers-type` to `relative` and enable
   `display-line-numbers-mode` from `prog-mode-hook`. Do not enable the global
   mode or maintain a language allowlist.
4. Restore `SPC Z`, `SPC z`, and `SPC v` exactly to their existing commands.
   Do not change those command implementations.
5. Keep direct promotions additive. Do not remove nested bindings merely
   because a direct route exists.
6. Ensure `SPC` is bound state-specifically on `magit-mode-map` after the
   leader maps are complete. Keep one copy of the exact entries. Do not unset
   Magit's ordinary map entry, use per-buffer hooks, or create a global
   overriding minor mode.
7. Keep the leader restricted to Evil normal and visual states.

Use the major-mode map variable, not a quoted minor-mode symbol:

```elisp
(defvar magit-mode-map)
(evil-define-key 'normal magit-mode-map
  (kbd "SPC") my/normal-leader-map)
(evil-define-key 'visual magit-mode-map
  (kbd "SPC") my/visual-leader-map)
```

`evil-define-key` delays these entries until `magit-mode-map` exists when
Magit is lazy-loaded. If another package has already loaded Magit, it applies
them immediately. In both load orders this runs after Evil Collection setup
and leaves the ordinary Magit map unchanged.

## Complete keybinding contract

Unless a row says otherwise, a leader sequence is available in Evil normal
and visual states through `my/normal-leader-map` and
`my/visual-leader-map`. No leader sequence is added to Evil Insert or Emacs
state, Ghostel character input, or a Transient keymap.

| Key | Disposition | Command or map | Scope and exact behavior |
| --- | --- | --- | --- |
| `SPC` | Retained globally, added locally in Magit | `my/normal-leader-map` or `my/visual-leader-map` | Normal and visual states. The state-local Magit entries override Magit's plain-space map only in these states. |
| `SPC l` | Added | `display-line-numbers-mode` | Toggles line numbers buffer-locally. With the planned default, enabled numbers are logical relative numbers. |
| `SPC h l` | Retained | `display-line-numbers-mode` | Remains an exact nested alias of `SPC l`. |
| `SPC Z` | Restored | `my/write-mode` | Enables Olivetti width 60, text scale 3, and disables line numbers. Which Key label: `zen mode`. |
| `SPC z` | Restored | `my/write-mode-no-zoom` | Enables Olivetti width 120, text scale 0, and disables line numbers. Which Key label: `zen mode no zoom`. |
| `SPC v` | Restored | `my/default-mode` | Disables Olivetti, restores text scale 0, and enables line numbers. Which Key label: `code mode`. |
| `SPC g g` | Intentionally retained | `magit-status` | Representative grouped Git command. It must resolve normally inside Magit after the state-local leader fix. |
| `S-SPC` in Magit | Intentionally retained | `magit-diff-show-or-scroll-up` | Preserves Magit scrolling in normal and visual states after plain `SPC` becomes the leader. |
| Plain `SPC` in Magit Insert or Emacs state | Intentionally retained | `magit-diff-show-or-scroll-up` from the ordinary Magit map | This plan must not replace or unset the ordinary binding in these states. |

All other current leader groups and leaves remain unchanged.

## Alternatives rejected

- Remove `SPC h l` after adding `SPC l`: the direct key optimizes frequent use,
  while the nested route preserves discovery and muscle memory.
- Add a line-number wrapper: the native command already has the required
  buffer-local toggle behavior.
- Enable global line numbers plus exception hooks: `prog-mode-hook` expresses
  the requested scope directly and avoids an expanding exception list.
- Keep `visual` line numbers: that counts wrapped display rows rather than
  logical source lines.
- Unset `SPC` in `magit-mode-map`: this would also delete Magit's native space
  behavior from Insert and Emacs states.
- Add Magit mode hooks or a global overriding minor map: one public binding on
  the shared major-mode map covers all derived Magit modes at the correct
  precedence.

## Phase 1: Restore direct editing controls

Status: complete

### Changes

1. Add direct `SPC l` for `display-line-numbers-mode` in the shared leader
   table at `profiles/common/.config/emacs/init.el:1202`.
2. Retain `SPC h l` as the same command.
3. Restore `SPC Z`, `SPC z`, and `SPC v` in the shared table with their
   historical commands.
4. Add Which Key leaf replacements for `Z` as `zen mode`, `z` as
   `zen mode no zoom`, and `v` as `code mode`. Keep the binding table's current
   simple `(key . command)` shape.
5. Set `display-line-numbers-type` to `relative` at
   `profiles/common/.config/emacs/init.el:1418`.
6. Add `display-line-numbers-mode` to `prog-mode-hook`.
7. Remove the redundant terminal disable-hook loop. Do not add exceptions for
   modes that do not derive from `prog-mode`.
8. Leave `my/write-mode`, `my/write-mode-no-zoom`, and `my/default-mode`
   unchanged.

### Success criteria

- New programming buffers show logical relative line numbers.
- Org, text, Ghostel, shell, and special buffers do not show line numbers by
  default.
- `SPC l` and `SPC h l` resolve to the same native buffer-local command in
  normal and visual states.
- The three writing bindings reproduce their historical Olivetti width,
  text-scale, and line-number behavior, with the exact Which Key labels.
- None of these leader sequences is installed in Insert or Emacs state.

### Implementation results

- Added the four direct shared-leader bindings and exact Which Key labels while
  retaining the nested `SPC h l` route.
- Set logical relative line numbers and enabled them only from
  `prog-mode-hook`; removed the terminal disable-hook loop.
- Batch checks resolved both line-number routes to the same native command,
  confirmed all three writing commands, and observed line numbers enabled in
  `emacs-lisp-mode` but disabled in `text-mode`.
- Batch startup, `init.el` `check-parens`, and `git diff --check` passed.

## Phase 2: Restore leader access in Magit

Status: complete

### Changes

1. After `my/normal-leader-map` and `my/visual-leader-map` are fully built,
   ensure the state-local `evil-define-key` entries on `magit-mode-map` shown
   above exist exactly once. Reuse and verify them if already present.
2. Preserve the ordinary Magit map and all Transient maps.
3. Do not force Magit to load during startup.

### Success criteria

- Normal and visual `SPC` resolve to the matching leader in Magit status,
  diff, log, and process buffers.
- Representative leaves such as `SPC l` and `SPC g g` resolve normally in
  those buffers.
- `S-SPC` remains `magit-diff-show-or-scroll-up`.
- Insert and Emacs states retain native plain-space behavior, and Transient
  input is unchanged.

### Implementation results

- Added exactly one normal-state and one visual-state `SPC` entry on
  `magit-mode-map` after both leader maps are complete.
- Batch startup confirmed Magit remains unloaded until explicitly required.
- Active Magit status-buffer checks resolved normal and visual `SPC` to their
  matching leader maps, kept `S-SPC` on
  `magit-diff-show-or-scroll-up`, and retained native ordinary-space behavior
  in Insert and Emacs states.
- Batch startup, `init.el` `check-parens`, and `git diff --check` passed.

## Phase 3: Verify the independent keybinding change

Status: pending

### Automated verification

Add a small behavior-focused ERT suite at
`profiles/common/.config/emacs/leader-bindings-test.el`. Group assertions into
three tests:

1. programming-buffer line defaults and direct/nested toggle equivalence;
2. historical writing bindings, labels, and command behavior;
3. Magit active-map precedence across status, diff, log, and process modes,
   including normal, visual, Insert, Emacs, and `S-SPC` behavior.

Test active `key-binding` resolution rather than merely searching source text
or inspecting a map in isolation.

Run:

```sh
emacs -Q --batch -l profiles/common/.config/emacs/init.el \
  --eval '(princ "CONFIG_LOADED\n")'

emacs -Q --batch \
  -l profiles/common/.config/emacs/leader-bindings-test.el \
  -f ert-run-tests-batch-and-exit

emacs -Q --batch \
  --eval '(progn (find-file "profiles/common/.config/emacs/init.el") (check-parens))'

git diff --check
```

Byte-compile `init.el` and the focused test into a temporary directory so no
generated files enter the profile.

### Manual verification

1. Open representative source, Org, text, Ghostel, shell, and special buffers.
   Confirm the default scope and toggle with both line-number routes.
2. Invoke the three writing bindings from normal and visual states. Confirm
   widths, text scales, line-number effects, and Which Key labels.
3. Open Magit status, diff, and log buffers. Confirm leader access in normal
   and visual states, native `S-SPC`, native Insert and Emacs plain space, and
   unchanged Transient input.

### Final success criteria

- Every binding in the contract resolves exactly as documented.
- Frequent line-number and writing actions are one key after `SPC`.
- Existing nested and grouped routes remain available.
- Programming buffers use relative logical line numbers by default without a
  global mode or terminal exception list.
- Startup remains lazy and offline.
- ERT, byte compilation, `check-parens`, and `git diff --check` pass.
- Phase statuses and measured results are recorded in this file during
  implementation.
