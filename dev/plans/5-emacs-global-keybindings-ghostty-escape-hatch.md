# Emacs terminal escape-hatch keybindings implementation plan

## Reasoning

Ghostel terminal buffers normally use Evil Insert state so shell input can go
directly to the terminal. The shared leader map is currently reachable only
through `SPC` in Evil Normal and Visual states. Moving windows from a live
shell therefore requires leaving Insert state even though the requested action
belongs to Emacs rather than the terminal.

Provide two complementary terminal-local escape hatches. `C-b` should behave
like a tmux prefix for the existing Emacs window commands, while `M-SPC` should
open the complete shared leader map when a less common command is needed. Keep
both bindings scoped to Evil Insert state in Ghostel buffers. A global
`M-SPC` binding would unnecessarily replace Emacs's existing `cycle-spacing`
command in ordinary editing buffers.

The `C-b` prefix must reuse the current `SPC w` submap rather than duplicate
its leaves. A child keymap with the existing window map as its parent provides
one source of truth while allowing the terminal-only `C-b C-b` literal-send
binding. Plain Ghostel terminals and zmx sessions then share the same behavior
because term-sessions renders zmx attachments through Ghostel.

This plan is independently implementable. It changes no project association,
terminal creation, session lifetime, layout, or window-command semantics.

## Goals

- Add a tmux-style `C-b` window prefix in Ghostel and Ghostel-rendered zmx
  buffers while entering terminal input in Evil Insert state.
- Reuse the complete existing `SPC w` hierarchy without copying its bindings.
- Keep literal Ctrl-B available as `C-b C-b`, including for shell
  backward-character input and nested tmux.
- Add `M-SPC` as a terminal-local route to the complete shared leader map.
- Preserve Ghostel char mode as an all-keys-to-terminal mode with `M-RET` as
  its exit.
- Preserve current key behavior in ordinary buffers and in Ghostel Normal,
  Visual, and Emacs states.

## Status

- Plan: complete
- Implementation: complete
- Target: Emacs 31.1+
- Primary configuration: `profiles/common/.config/emacs/init.el`
- Planned tests: `profiles/common/.config/emacs/leader-bindings-test.el`
- Package pins: `profiles/common/.config/emacs/install-packages.el:10`

## Terminology and scope

- Ghostel is the Emacs terminal renderer configured at
  `profiles/common/.config/emacs/init.el:963`.
- Ghostty is an external terminal application. The requested plan filename
  retains that name, but no Ghostty configuration is changed.
- zmx owns persistent terminal sessions. The term-sessions configuration at
  `profiles/common/.config/emacs/init.el:1003` selects Ghostel as its frontend,
  so a zmx attachment is also a `ghostel-mode` buffer.
- Outer Evil state controls whether Emacs editing commands are active. Inner
  Ghostel input mode controls whether keys are interpreted by Emacs or sent to
  the PTY. This plan targets outer Evil Insert state while Ghostel is outside
  char mode.
- Project association for zmx buffers is outside this keybinding-only plan.

## Current behavior and root causes

### Terminal input ownership

- The Ghostel and Evil Ghostel setup is at
  `profiles/common/.config/emacs/init.el:963-997`.
- Every `ghostel-mode` buffer enables `evil-ghostel-mode` through the hook at
  `profiles/common/.config/emacs/init.el:986`, so the same mode-local solution
  covers plain Ghostel and zmx attachments.
- Evil Ghostel starts in Insert state at
  `profiles/common/.config/emacs/init.el:975`.
- Evil Ghostel currently treats Insert-state `C-b` as a terminal passthrough,
  matching the shell/readline backward-character binding.
- Ghostel semi-char mode currently sends `M-SPC` to the terminal.
- Ghostel char mode installs its keymap through Emacs's emulation-map layer.
  That layer outranks minor-mode and Evil state maps, sends both `C-b` and
  `M-SPC` inward, and retains `M-RET` as its escape hatch. The implementation
  must not modify `ghostel-char-mode-map`.

### Existing leader and window hierarchy

- `my/leader-map` is recreated at
  `profiles/common/.config/emacs/init.el:1179-1185` and populated at
  `profiles/common/.config/emacs/init.el:1187-1283`.
- The existing `w` hierarchy contains selection, deletion, swapping,
  balancing, maximizing, delete-other-windows, winner history, and tab
  commands at `profiles/common/.config/emacs/init.el:1207-1221`.
- Normal and Visual state leaders inherit from the shared map and bind it to
  `SPC` at `profiles/common/.config/emacs/init.el:1297-1316`.
- No shared leader route is installed in Evil Insert state.
- Which Key labels the shared window and tab prefixes at
  `profiles/common/.config/emacs/init.el:1329-1357`.

### Reload behavior

- `my/soft-reload` reloads the complete configuration at
  `profiles/common/.config/emacs/init.el:85-93`.
- Because `my/leader-map` is a newly allocated object after every reload, a
  terminal prefix map must also be recreated and reparented. Retaining an old
  terminal map would leave it inheriting from a stale `w` map.
- Evil Ghostel is lazy-loaded. The terminal bindings must work whether the
  package loads before or after the leader maps are built.

## Decisions

1. Bind `C-b` and `M-SPC` only for Evil Insert state on
   `evil-ghostel-mode-map`. Do not add either key globally or to all Evil
   Insert buffers.
2. Build `my/terminal-window-map` after `my/leader-map` is fully populated and
   set its parent to `(keymap-lookup my/leader-map "w")`.
3. Add only one direct leaf to `my/terminal-window-map`: `C-b`, which sends one
   literal Ctrl-B with the public `ghostel-send-key` function. Keep the
   one-use command inline rather than adding a named wrapper.
4. Install the Insert-state bindings inside
   `with-eval-after-load 'evil-ghostel` with `evil-define-key*`. This runs after
   Evil Ghostel's own Ctrl passthrough definitions and applies immediately if
   the package is already loaded.
5. Do not add `C-b` or `M-SPC` to `ghostel-keymap-exceptions`. The Evil
   Insert-state auxiliary map already has the required precedence in
   semi-char mode, and changing the exception list would broaden the behavior
   to non-Evil Ghostel input.
6. Do not modify `ghostel-char-mode-map`. In char mode, `C-b` and `M-SPC`
   continue to reach the terminal. The user exits with `M-RET` before using an
   Emacs escape hatch.
7. Add Which Key metadata only for the direct `C-b` literal-send leaf. Allow
   the inherited window and tab maps to retain their existing labels.
8. Do not add zmx-specific hooks or maps. Its Ghostel frontend inherits these
   bindings automatically.
9. Preserve every current window command exactly. In particular, inherited
   `C-b z` runs `delete-other-windows`; it is not a reversible tmux zoom
   toggle. A true zoom toggle would be a separate behavior change.

Use this structure after the existing shared leader table is populated:

```elisp
(defvar my/terminal-window-map nil
  "Window prefix map for terminal input in Evil Insert state.")

(setq my/terminal-window-map (make-sparse-keymap))
(set-keymap-parent my/terminal-window-map
                   (keymap-lookup my/leader-map "w"))
(keymap-set my/terminal-window-map "C-b"
            (lambda ()
              (interactive)
              (ghostel-send-key "b" "ctrl")))

(with-eval-after-load 'evil-ghostel
  (evil-define-key* 'insert evil-ghostel-mode-map
    (kbd "C-b") my/terminal-window-map
    (kbd "M-SPC") my/leader-map))
```

Recreating and rebinding these owned maps on every init evaluation is
intentional. It mirrors the existing leader-map lifecycle and prevents stale
parents after `my/soft-reload`.

## Complete keybinding contract

The terminal-specific rows apply to plain Ghostel and Ghostel-rendered zmx
buffers in outer Evil Insert state while Ghostel is outside char mode.

| Key | Command or map | Exact behavior |
| --- | --- | --- |
| `C-b` | `my/terminal-window-map` | Starts the terminal-local window prefix. An invalid suffix is an undefined Emacs prefix sequence and is not forwarded to the PTY. |
| `C-b h` | `evil-window-left` | Selects the window to the left, inherited from `SPC w h`. |
| `C-b j` | `evil-window-down` | Selects the window below, inherited from `SPC w j`. |
| `C-b k` | `evil-window-up` | Selects the window above, inherited from `SPC w k`. |
| `C-b l` | `evil-window-right` | Selects the window to the right, inherited from `SPC w l`. |
| `C-b q` | `delete-window` | Deletes the selected Emacs window, inherited from `SPC w q`. |
| `C-b x` | `window-swap-states` | Swaps window states, inherited from `SPC w x`. |
| `C-b =` | `balance-windows` | Balances the current frame's windows, inherited from `SPC w =`. |
| `C-b \|` | `maximize-window` | Runs the existing maximize command, inherited from `SPC w \|`. |
| `C-b z` | `delete-other-windows` | Deletes other windows, inherited from `SPC w z`; this is not a reversible zoom toggle. |
| `C-b u` | `winner-undo` | Restores the previous window configuration, inherited from `SPC w u`. |
| `C-b r` | `winner-redo` | Reapplies the next window configuration, inherited from `SPC w r`. |
| `C-b t c` | `tab-bar-new-tab` | Creates an Emacs tab, inherited from `SPC w t c`. |
| `C-b t q` | `tab-bar-close-tab` | Closes the current Emacs tab, inherited from `SPC w t q`. |
| `C-b t [` | `tab-bar-switch-to-prev-tab` | Selects the previous Emacs tab, inherited from `SPC w t [`. |
| `C-b t ]` | `tab-bar-switch-to-next-tab` | Selects the next Emacs tab, inherited from `SPC w t ]`. |
| `C-b C-b` | Inline `ghostel-send-key` command | Sends exactly one literal Ctrl-B to the PTY. With inner tmux, `C-b C-b z` sends tmux its prefix and then `z`. |
| `M-SPC` | `my/leader-map` | Opens the complete shared leader. For example, `M-SPC w z` reaches the same command as `SPC w z`. |
| `SPC` in Ghostel Normal or Visual state | Existing state-specific leader | Remains unchanged. |
| `C-b` or `M-SPC` in Ghostel char mode | `ghostel--send-event` | Continues inward to the terminal. Exit char mode with `M-RET` before using the Emacs prefixes. |
| `C-b` or `M-SPC` outside Ghostel Insert state | Existing binding | Ordinary buffer behavior, including `M-SPC` as `cycle-spacing`, remains unchanged. |

Future additions or removals under `SPC w` automatically appear under `C-b`
through keymap inheritance. The table above documents the initial contract; it
must not become a second implementation table.

## Alternatives rejected

- Duplicate each `SPC w` leaf under a second prefix: this creates two binding
  tables that can drift. Keymap inheritance keeps one source of truth.
- Bind `C-b` to the entire leader: a short terminal prefix should expose only
  window operations. `M-SPC` provides the complete leader separately.
- Bind `M-SPC` globally: this would replace `cycle-spacing` in ordinary
  editing buffers and still require extra handling for Ghostel's local map.
- Add Ghostel keymap exceptions: the Evil Insert-state map already wins in
  semi-char mode, so changing Ghostel's general exception policy is
  unnecessary.
- Override Ghostel char mode: char mode deliberately gives full-screen TUIs a
  reliable all-keys-inward contract. Its existing `M-RET` exit is sufficient.
- Add separate zmx bindings: zmx is rendered through Ghostel and already runs
  the same mode hook.
- Make `C-b z` a custom zoom toggle in this change: that would diverge from
  `SPC w z` and expand a key-access task into new window-state behavior.
- Add a named literal-send helper: the operation is used once and is clearer
  as a direct interactive lambda.

## Phase 1: Add the terminal-local escape-hatch maps

Status: complete

Success criteria status: satisfied by batch loading, structural checks, active
Ghostel key-resolution probes, and a reload-freshness probe.

### Changes

1. In `profiles/common/.config/emacs/init.el`, after the binding loop ending at
   line 1283, declare and recreate `my/terminal-window-map`.
2. Set its parent to the completed `(keymap-lookup my/leader-map "w")` map.
3. Add the inline `C-b` leaf that calls `(ghostel-send-key "b" "ctrl")`.
4. Register the `evil-define-key*` bindings after Evil Ghostel loads:
   `C-b` to `my/terminal-window-map` and `M-SPC` to `my/leader-map`, both in
   Insert state on `evil-ghostel-mode-map`.
5. Extend the Which Key configuration at
   `profiles/common/.config/emacs/init.el:1329-1357` with the label
   `send Ctrl-B` for `C-b` in `my/terminal-window-map`. Do not duplicate
   inherited window labels.
6. Update the terminal input comment at
   `profiles/common/.config/emacs/init.el:977-985` so it documents both
   semi-char prefixes, `C-b C-b`, and the unchanged char-mode boundary.

### Success criteria

- In Ghostel Insert plus semi-char mode, active `C-b` resolves to
  `my/terminal-window-map` and active `M-SPC` resolves to `my/leader-map`.
- Every `C-b` window leaf resolves through the existing `w` map rather than a
  copied binding.
- `C-b C-b` sends exactly one Ctrl-B through Ghostel's public encoder.
- Ghostel char mode still sends `C-b` and `M-SPC` inward and exits through
  `M-RET`.
- Ordinary buffers, Ghostel non-Insert states, and non-Evil Ghostel behavior
  retain their current keybindings.
- Reloading the configuration recreates a terminal map whose parent is the
  newly recreated shared window map.

## Phase 2: Add behavior-focused regression coverage

Status: complete

Success criteria status: satisfied by the focused active-binding test and the
complete leader-binding ERT suite.

### Changes

Add one focused ERT test to
`profiles/common/.config/emacs/leader-bindings-test.el`:

1. Require `ghostel` and `evil-ghostel` explicitly in the test file.
2. Create a temporary `ghostel-mode` buffer, enable `evil-ghostel-mode`, and
   enter Evil Insert state without starting a real PTY.
3. Assert active `key-binding` resolution for both prefix roots.
4. Assert representative inherited routes, including `C-b h`, `C-b z`, and
   `C-b t ]`, equal `(keymap-lookup my/leader-map "w h")`,
   `(keymap-lookup my/leader-map "w z")`, and
   `(keymap-lookup my/leader-map "w t ]")`. Do not use active
   `key-binding` for `SPC w ...` inside Insert-state Ghostel because Ghostel
   owns plain `SPC` there.
5. Assert active `M-SPC w z` equals
   `(keymap-lookup my/leader-map "w z")`.
6. Temporarily replace `ghostel-send-key`, invoke the active `C-b C-b`
   command interactively, and assert one call with exactly `"b"` and
   `"ctrl"`.
7. Enter Ghostel char mode and assert active `C-b` and `M-SPC` resolve to
   `ghostel--send-event`, `M-RET` resolves to `ghostel-semi-char-mode`, and
   the Emacs prefix leaves no longer resolve.
8. In an ordinary `fundamental-mode` temporary buffer in Evil Insert state,
   assert the exact preserved bindings: `C-b` is `backward-char` and `M-SPC`
   is `cycle-spacing`.

Test resolved behavior rather than source-code text. Keep the related
assertions in one test to minimize unit-test count.

### Success criteria

- The test detects regressions in active Evil, Ghostel, and char-mode
  precedence rather than only inspecting isolated maps.
- The test proves the terminal map inherits current window commands.
- The literal Ctrl-B contract is verified without creating a terminal process.
- Existing leader and Magit tests remain unchanged and pass.

## Phase 3: Verify reload behavior and live terminal UX

Status: complete

Automated success criteria status: batch startup, the complete leader-binding
ERT suite, `check-parens`, byte compilation in a temporary directory, reload
freshness, char-mode exit restoration, and `git diff --check` passed. The live
Ghostel, zmx, readline, tmux, Which Key, and ordinary-buffer interaction checks
remain manual.

Final review status: passed with no findings. All repository Emacs ERT suites
passed, with 21 tests and 0 unexpected results.

### Automated verification

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

Also run a batch probe that loads `init.el`, requires Evil Ghostel, loads
`init.el` a second time, and verifies that active terminal roots reference the
current `my/terminal-window-map` and `my/leader-map` objects. Byte-compile the
changed Emacs Lisp into a temporary directory so no generated files enter the
repository.

### Manual verification

1. Open an ordinary Ghostel terminal and a zmx attachment.
2. In Evil Insert plus semi-char mode, exercise every documented `C-b` window
   and tab route. Confirm Which Key displays the inherited hierarchy and the
   `send Ctrl-B` label.
3. Confirm `M-SPC` opens the complete shared leader and that a representative
   command such as `M-SPC w z` resolves correctly.
4. In a shell using readline or equivalent bindings, confirm `C-b C-b` moves
   backward one character.
5. Start inner tmux and confirm `C-b C-b z` sends tmux's prefix and zoom key.
6. Enter Ghostel char mode with `C-c M-d`. Confirm `C-b` and `M-SPC` reach the
   inner TUI, then use `M-RET` and confirm both Emacs routes return.
7. Run `my/soft-reload` and repeat representative `C-b`, `C-b C-b`, and
   `M-SPC` checks.
8. In an ordinary editing buffer, verify Insert-state `C-b` and `M-SPC`
   retain their previous behavior.

### Success criteria

- Batch startup, ERT, `check-parens`, byte compilation, reload probing, and
  `git diff --check` pass.
- Plain Ghostel and zmx attachments expose identical terminal-local prefixes.
- The inherited Which Key hierarchy is discoverable without duplicated
  metadata.
- Nested tmux remains usable through `C-b C-b`.
- Char mode and ordinary editing behavior remain unchanged.

## Final success criteria

- `C-b` is a tmux-style, window-only prefix in Ghostel and zmx Evil Insert
  state outside char mode.
- `C-b` inherits the existing `SPC w` map, so there is one window-binding
  source of truth.
- `C-b C-b` sends a literal Ctrl-B and supports nested tmux input.
- `M-SPC` exposes the complete shared leader only in the affected terminal
  state.
- Ghostel char mode remains a reliable all-keys-inward mode with `M-RET` as
  its escape hatch.
- Current nonterminal keys, Evil Normal and Visual leaders, window commands,
  zmx lifecycle, and project association behavior are unchanged.
- After soft reload, the Insert-state bindings reference the current recreated
  maps, and `my/terminal-window-map` inherits from the current shared `w` map.
- Lazy Evil Ghostel loading does not change the resulting active bindings.
- Automated and manual validation pass.
