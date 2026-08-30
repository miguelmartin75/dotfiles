# Emacs configuration alignment plan

## Status

- Plan: complete
- Implementation: Phases 1-7 complete
- Target: Emacs 31.1+ with dynamic-module support, `package-vc`, Eglot, Flymake, Xref, project.el, Icomplete, and native Tree-sitter
- Primary configuration: `profiles/common/.config/emacs/init.el`
- Terminal references: `refs/ghostel/README.org`, `refs/emacs-term-sessions/README.org`
- Prerequisite: satisfied on 2026-08-29. `emacs --batch --eval '(princ emacs-version)'` prints `31.1`.

## Startup performance

Measure each accepted phase with Hyperfine using one warmup and five timed runs of:

```sh
emacs -Q --batch -l profiles/common/.config/emacs/init.el --eval '(princ "CONFIG_LOADED\\n")'
```

Times are wall-clock process durations. `+/-` values are sample standard
deviations, matching Hyperfine. Deltas compare each row's mean with the
immediately preceding row.

| State | Revision | Mean | Median | Range | Delta |
| --- | --- | --- | --- | --- | --- |
| Before Phase 1 | `fbee7f8` | 8.130 s +/- 1.911 s | 7.379 s | 7.160-11.543 s | baseline |
| After Phase 1 | Phase 1 commit | 3.966 s +/- 0.093 s | 4.002 s | 3.817-4.042 s | -4.164 s (-51.2%) |
| After Phase 2 | Phase 2 commit | 2.807 s +/- 0.061 s | 2.810 s | 2.734-2.898 s | -1.159 s (-29.2%) |
| After Phase 3 | Phase 3 commit | 2.665 s +/- 0.020 s | 2.661 s | 2.637-2.686 s | -0.142 s (-5.1%) |
| After Phase 4 | Phase 4 commit | 2.826 s +/- 0.054 s | 2.815 s | 2.781-2.919 s | +0.161 s (+6.0%) |
| After Phase 5 | Phase 5 commit | 2.972 s +/- 0.169 s | 2.911 s | 2.863-3.271 s | +0.146 s (+5.2%) |
| After Phase 6 | Phase 6 commit | 2.907 s +/- 0.157 s | 2.856 s | 2.806-3.185 s | -0.064 s (-2.2%) |
| After Phase 7 | Phase 7 commit | 2.333 s +/- 0.743 s | 1.967 s | 1.933-3.654 s | -0.574 s (-19.8%) |

The baseline completed with exit status 0 on every measured run, but logged a non-fatal `use-package` error because `corfu-map` was unbound.

## Goal

Rebuild the Emacs configuration around the principles in `refs/editor-philosophy.md:1`:

1. Keep completion, documentation, search, semantic navigation, and AI actions explicit.
2. Prefer native Emacs features, then small owned Elisp, then external tools, and use packages only for substantial behavior.

The result uses no completion frontend or completion-source package. Native CAPF powers explicit `completion-at-point`; Icomplete improves minibuffer selection only. Ghostel is the sole terminal renderer. `zmx`, accessed through `term-sessions.el`, owns persistent session lifetime. Whisper and Vterm are removed.

## Target mapping contract

Install one sparse `SPC` leader map in Evil normal and visual states only. Do not make `SPC` a leader in insert or Emacs states. `N` means normal state, `V` means visual state, and `I` means insert state. A mapping marked `N, V` is present in both states; a visual command must still have the region or selection its command requires.

Use direct native commands where they exist. New owned commands are limited to the operations that need data assembly or a missing native interaction: `my/project-find-regexp-at-point`, `my/project-run-command`, `my/term-sessions-send-region-or-buffer`, `my/annotate-region`, `my/annotate-send-all`, `my/gptel-compose-region`, and the optional `my/tmux-paste-region-or-buffer`. Do not create a compatibility wrapper merely to rename a native command.

### Files and buffers

| Key | Command | States | Purpose |
| --- | --- | --- | --- |
| `SPC f f` | `project-find-file` | N, V | Find a file in the current local or TRAMP project. |
| `C-p` | `project-find-file` | N, V | High-frequency alias for project file finding. |
| `SPC f o` | `recentf-open-files` | N, V | Open a recent file with native minibuffer completion. |
| `SPC b b` | `switch-to-buffer` | N, V | Switch buffers. |
| `SPC ,` | `switch-to-buffer` | N, V | High-frequency buffer-switching alias. |

Do not carry Neovim's global-cwd and buffer-directory commands forward. Emacs uses the current buffer's project and buffer-local `default-directory`, including for TRAMP buffers. `SPC f F`, `SPC f d`, `SPC f D`, and new-file creation remain unbound until a concrete native workflow needs them.

### Windows and tabs

| Key | Command | States | Purpose |
| --- | --- | --- | --- |
| `SPC w h` | `evil-window-left` | N, V | Focus the window to the left. |
| `SPC w j` | `evil-window-down` | N, V | Focus the window below. |
| `SPC w k` | `evil-window-up` | N, V | Focus the window above. |
| `SPC w l` | `evil-window-right` | N, V | Focus the window to the right. |
| `SPC w q` | `delete-window` | N, V | Close the selected window. |
| `SPC w x` | `window-swap-states` | N, V | Exchange the selected window's state with another window. |
| `SPC w =` | `balance-windows` | N, V | Equalize window sizes. |
| `SPC w |` | `maximize-window` | N, V | Maximize the selected window's width. |
| `SPC w z` | `delete-other-windows` | N, V | Focus the selected window. |
| `SPC w u` | `winner-undo` | N, V | Restore the previous window layout. |
| `SPC w r` | `winner-redo` | N, V | Reapply a reverted window layout. |
| `SPC w t c` | `tab-bar-new-tab` | N, V | Create a tab-bar tab. |
| `SPC w t q` | `tab-bar-close-tab` | N, V | Close the selected tab-bar tab. |
| `SPC w t [` | `tab-bar-switch-to-prev-tab` | N, V | Select the previous tab-bar tab. |
| `SPC w t ]` | `tab-bar-switch-to-next-tab` | N, V | Select the next tab-bar tab. |

### Search, symbols, and references

| Key | Command | States | Purpose |
| --- | --- | --- | --- |
| `SPC s l` | `occur` | N, V | Find a line in the current buffer. |
| `SPC /` | `occur` | N, V | High-frequency current-buffer line-search alias. |
| `SPC s g` | `project-find-regexp` | N, V | Search the current project with its configured native backend, normally ripgrep. |
| `SPC s w` | `my/project-find-regexp-at-point` | N, V | Search the current project for the word at point. |
| `SPC s s` | `imenu` | N, V | Navigate symbols in the current buffer. |
| `SPC s S` | `xref-find-apropos` | N, V | Search workspace symbols through Xref or Eglot. |
| `SPC s d` | `xref-find-definitions` | N, V | Find a definition through Xref or Eglot. |
| `SPC s D` | `eglot-find-declaration` | N, V | Find an LSP declaration when the server supports it. |
| `SPC s r` | `xref-find-references` | N, V | Find references through Xref or Eglot. |
| `SPC s i` | `eglot-find-implementation` | N, V | Find LSP implementations when supported. |
| `SPC s t` | `eglot-find-typeDefinition` | N, V | Find an LSP type definition when the server supports it. |
| `SPC s I` | `eglot-show-call-hierarchy` | N, V | Show the native unified incoming and outgoing call hierarchy. |
| `SPC s b` | `multi-occur` | N, V | Search selected open buffers, including unsaved contents. |
| `SPC s H` | `describe-face` | N, V | Complete and describe a face or highlight definition. |
| `SPC s m` / `SPC m` | `evil-show-marks` | N, V | Show Evil's selectable local and global marks list. |
| `SPC s j` / `SPC j` | `evil-show-jumps` | N, V | Show Evil's selectable jump list. |

Use native Isearch history rather than a separate search-history picker: `C-s` starts Isearch and `M-p` / `M-n` traverse its persisted history. Leave `SPC s h` and `SPC ?` unbound. Native Emacs and Evil cover highlights, marks, jumps, open-buffer grep, type definitions, and call hierarchy, though their UIs do not provide the uniform fuzzy filtering and live preview of Neovim's Snacks pickers.

### Code actions and completion

| Key | Command | States | Purpose |
| --- | --- | --- | --- |
| `SPC c f` | `eglot-format` | N, V | Format the buffer or selected region explicitly. |
| `SPC c r` | `eglot-rename` | N, V | Rename the identifier at point. |
| `SPC c a` | `eglot-code-actions` | N, V | Request and apply an explicit code action. |
| `SPC c h` | `eldoc-doc-buffer` | N, V | Show explicit Eglot or mode documentation at point. |
| `SPC c i` | `eglot-inlay-hints-mode` | N, V | Toggle Eglot inlay hints for the current buffer. |

There is no separate native public Eglot command for a standalone signature-help request, so `SPC c s` remains unbound. `SPC c h` and `K` deliberately combine hover and signature information through Eldoc. Eglot supplies initial LSP workspace folders from the active `project.el` project and its `project-external-roots`; runtime add, remove, and list editing mappings remain unbound because Eglot exposes no equivalent public interactive workflow.

### Diagnostics and debugging

| Key | Command | States | Purpose |
| --- | --- | --- | --- |
| `SPC d p` | `flymake-goto-prev-error` | N, V | Visit the previous diagnostic. |
| `SPC d n` | `flymake-goto-next-error` | N, V | Visit the next diagnostic. |
| `SPC d f` | `flymake-show-buffer-diagnostics` | N, V | Show diagnostics for the current buffer. |
| `SPC d l` | `flymake-show-project-diagnostics` | N, V | Show diagnostics for the current project. |
| `SPC d D` | `dape` | N, V | Explicitly choose and launch a configured DAP session. |

`[d` and `]d` are aliases for previous and next Flymake diagnostics. Dape has no mode hook or default debugger role; use its own explicit UI after `SPC d D`.

### Git

| Key | Command | States | Purpose |
| --- | --- | --- | --- |
| `SPC g g` | `magit-status` | N, V | Open project Git status, diffs, staging, hunk actions, branches, and history. |

Magit status owns diff, stage, reset, blame, and hunk interactions. Do not recreate Neovim Gitsigns-style direct hunk bindings in the leader map.

On machines where `(executable-find "difft")` succeeds, explicitly install `difftastic.el` through `package-vc`, pinned to the reviewed source under `refs/difftastic.el`, and enable `difftastic-bindings-mode`. Configure its public `difftastic-bindings-alist` for Magit contexts only instead of adding owned wrapper commands or leader bindings: `M-d` and `M-c` in the Magit diff transient, `M-RET` in Magit blame, and `M-d` in Magit file dispatch. Do not enable the package's unrelated Dired or Forge bindings. When `difft` is absent, do not install, require, or enable `difftastic.el`; ordinary Magit diffs remain the complete fallback.

### Terminals and REPLs

| Key | Command | States | Purpose |
| --- | --- | --- | --- |
| `SPC t p` | `ghostel-project` | N, V | Open an ordinary project terminal at the current local or TRAMP directory. |
| `SPC t t` | `term-sessions-open` | N, V | Open or create a named durable zmx session. |
| `SPC t l` | `term-sessions-list` | N, V | List and manage known terminal sessions. |
| `SPC t h` | `term-sessions-history` | N, V | Show history for a selected terminal session. |
| `SPC t o` | `term-sessions-store-org-link` | N, V | Store an Org link for a selected terminal session. |
| `SPC t c` | `my/project-run-command` | N, V | Select and run a catalogued project task in Ghostel. `Compile` is the default selection. |
| `SPC t r` | `my/term-sessions-send-region-or-buffer` | N, V | Send the active region, or the full buffer, to a selected named zmx session. |
| `C-c C-c` | `my/term-sessions-send-region-or-buffer` | V | Alias for the generalized sender when the visual-state override is reliable. |
| `SPC t m` | `my/tmux-paste-region-or-buffer` | N, V | Optional explicit delivery to a selected non-Emacs tmux pane. |

`SPC t m` is absent unless the optional tmux adapter is implemented. If `C-c C-c` cannot cleanly override Evil visual state, leave it unchanged and retain `SPC t r` as the sole generalized sender. Python mode's specialized `C-c` commands remain outside this leader contract.

### Review

| Key | Command | States | Purpose |
| --- | --- | --- | --- |
| `SPC r a` | `my/annotate-region` | V | Add the selected region to the agent-agnostic annotation queue. |
| `SPC r s` | `my/annotate-send-all` | N, V | Prompt for an optional request and send all queued annotations to a selected named zmx session. |

The `SPC r` group owns code-review collection and dispatch. Annotation delivery still delegates to the shared terminal-session transport, but its user-facing actions do not live under the terminal prefix.

### AI

| Key | Command | States | Purpose |
| --- | --- | --- | --- |
| `SPC a c` | `gptel` | N | Open an explicit Gptel conversation. |
| `SPC a c` | `my/gptel-compose-region` | V | Open a Gptel conversation prefilled with the selected code and context, without submitting it. |
| `SPC a s` | `gptel-send` | N, V | Submit an explicit Gptel request for an in-place response. |
| `SPC a r` | `gptel-rewrite` | V | Request an explicit rewrite of the selected region. |

The `SPC a` group is only for Gptel. Terminal coding agents use the agent-neutral `SPC r a` and `SPC r s` review workflow instead.

### Org, research, and help

| Key | Command | States | Purpose |
| --- | --- | --- | --- |
| `SPC o a` | `org-agenda` | N, V | Open the Org agenda. |
| `SPC o c` | `org-capture` | N, V | Capture an Org entry. |
| `SPC o n` | `org-roam-node-find` | N, V | Find an Org Roam node. |
| `SPC o i` | `org-roam-node-insert` | N, V | Insert an Org Roam node link. |
| `SPC o j` | `my/goto-journal` | N, V | Open the personal journal workflow. |
| `SPC o t` | `org-set-tags-command` | N, V | Set tags with native minibuffer completion. |
| `SPC o r` | `org-table-recalculate-buffer-tables` | N, V | Recalculate Org tables in the current buffer. |
| `SPC o RET` | `org-babel-execute-src-block` | N, V | Explicitly execute the Org source block at point. |
| `SPC h o` | `customize` | N, V | Open Emacs customization options. |
| `SPC h h` | `info` | N, V | Browse installed Emacs and package manuals. |
| `SPC h m` | `man` | N, V | Open a manual page. |
| `SPC h f` | `describe-function` | N, V | Describe a function. |
| `SPC h v` | `describe-variable` | N, V | Describe a variable. |
| `SPC h c` | `describe-command` | N, V | Describe an interactive command. |
| `SPC h k` | `describe-key` | N, V | Describe a key sequence. |
| `SPC h l` | `display-line-numbers-mode` | N, V | Toggle line numbers in the current buffer. |

### High-frequency aliases and insert-state completion

| Key | Command | States | Purpose |
| --- | --- | --- | --- |
| `gd` | `xref-find-definitions` | N | Find the definition at point. |
| `gD` | `eglot-find-declaration` | N | Find the declaration at point. |
| `gi` | `eglot-find-implementation` | N | Find the implementation at point. |
| `K` | `eldoc-doc-buffer` | N | Show explicit documentation and signature information at point. |
| `[d` | `flymake-goto-prev-error` | N | Visit the previous diagnostic. |
| `]d` | `flymake-goto-next-error` | N | Visit the next diagnostic. |
| `[m` / `]m` | Native Tree-sitter defun motion | N, V, O | Move to the previous or next function start with count and jump history. |
| `[M` / `]M` | Native Tree-sitter defun motion | N, V, O | Move to the previous or next function end with count and jump history. |
| `C-s` | `isearch-forward` | N, V, I | Start native incremental search. |
| `C-SPC` | `completion-at-point` | I | Request explicit CAPF completion outside terminal buffers. |
| `C-M-i` | `completion-at-point` | I | Terminal-safe explicit-completion fallback. |
| `M-/` | `dabbrev-expand` | I | Request explicit dabbrev completion. |
| `TAB` / `S-TAB` | Native completion candidate movement | Completion transient map only | Select the next or previous candidate only while explicit completion is active. |
| `TAB` / `S-TAB` | Yasnippet field movement | Active snippet map only | Move through placeholders only after an explicit Eglot snippet completion expands. |

Completion candidate movement takes priority when completion and a snippet are both active. Keep normal `TAB` indentation and editing behavior when neither transient interaction is active. Keep standard Isearch keys and use `M-p` / `M-n` inside Isearch for persisted search history.

## Text and buffer transport contract

This configuration has separate explicit routes for source text. Do not introduce a generic package that guesses a target, scrapes terminal output, or silently inserts terminal output into the source buffer.

| Route | Sending | Receiving | Lifetime and boundary |
| --- | --- | --- | --- |
| Source to native Python | `run-python` starts an Emacs-owned `inferior-python-mode` process. `python-shell-send-region`, `python-shell-send-buffer`, and `python-shell-send-defun` perform Python-aware evaluation. | Output remains in `*Python*`. | Ephemeral local or TRAMP-remote Comint process. This is the only route that supports the built-in Python send commands. |
| Source to named REPL | `my/term-sessions-send-region-or-buffer` sends the active region, or the full buffer when no region is active, plus one carriage return to an explicitly selected `zmx` session. Bind it to `SPC t r` in normal and visual states and to `C-c C-c` in Evil visual state. | Inspect output in the Ghostel attachment or with `term-sessions-history`; do not copy it into the source automatically. | The generalized vim-slime replacement. `zmx` owns persistence; Ghostel only renders the attached terminal. |
| Annotation queue to a coding agent | `my/annotate-region` records a selected region from any buffer with its text snapshot, buffer or file identity, line range, major mode, and an annotation. Bind it to visual `SPC r a`. `my/annotate-send-all` accepts an optional additional prompt, formats all queued annotations, and sends the result to an explicitly selected named session. Bind it to `SPC r s`. | Inspect the agent response in its Ghostel attachment; do not scrape it back into an Emacs buffer. | Agent-agnostic terminal transport: the selected zmx session may run Codex or any other coding agent with a text composer. The queue is in memory and clears only after a successful send. |
| Source to tmux pane | An optional explicit adapter writes the text with `tmux load-buffer`, pastes it with `tmux paste-buffer`, then sends Return. | No reverse transport. | Only for a deliberately chosen existing pane. It is not a second persistent-session system. |
| Source to Gptel | Explicit `gptel-send`, `gptel-rewrite`, or an owned compose-region command. | Gptel inserts the result in its conversation or requested target. | Gptel request state only. Never submit a selected region to AI implicitly. |

Define `my/term-sessions-send-text` as the single owned session-selection and zmx-send primitive. It prompts for the named session with the public `term-sessions.el` API, appends one carriage return, and is called by both `my/term-sessions-send-region-or-buffer` and `my/annotate-send-all`. Do not duplicate target selection, TRAMP routing, or terminal-send code in the annotation commands.

Use the named `zmx` route for Python, IPython, shell, Node, and other terminal REPLs when durable shared terminal state is wanted. It sends literal terminal input, so a multiline Python suite may need an intentional terminating blank line; no language-neutral sender can infer that correctly.

Implementation fallback: attempt to bind `C-c C-c` to the generalized sender in Evil visual state, but do not add an Evil, Python-mode, or terminal-keymap workaround if that override proves difficult or unreliable. In that case, keep `SPC t r` as the canonical generalized sender and leave the existing `C-c C-c` binding unchanged.

Use the native Python route only when its Python-aware behavior is valuable: statement, block, defun, or buffer evaluation; Python-aware file paths; Comint output; and Python's process-backed completion and documentation. `python-shell-send-region` and `python-shell-send-buffer` require the process created by `run-python` and cannot target a Ghostel PTY, `zmx` session, or tmux pane. `run-python` may start CPython or IPython, with IPython configured through `python-shell-interpreter` and `python-shell-interpreter-args`. Apply `ghostel-comint-mode` only to `inferior-python-mode-hook` if improved ANSI and hyperlink rendering is desired. It remains a Comint buffer, not a Ghostel terminal or persistent session.

For a remote Python file under `/sshx:host:/repo/`, `run-python` starts its Comint process on `host` when invoked from that buffer. The built-in Python mode handles remote process environment, paths, and temporary files, but the process ends with the Emacs or SSH connection. Use remote `zmx` for a durable Python or IPython REPL. Both routes work in graphical Emacs and `emacs -nw`.

Do not bridge `python-shell` to `zmx` or tmux. Doing so would require a fragile custom adapter for Comint's private evaluation, prompt, and output protocol. Do not send text by discovering Ghostel buffers or calling Ghostel-private functions: choose a session through `term-sessions.el`, which owns local and TRAMP-aware routing.

## Recommended architecture

Keep one ordered configuration in `profiles/common/.config/emacs/init.el`; the current size comes from overlapping and stale subsystems, not a need for modules.

### Fresh-machine bootstrap

Link these dotfiles into `~/.config` before starting Emacs, then run the explicit provisioners in this order:

```sh
emacs --batch -Q -l ~/.config/emacs/install-packages.el
emacs --batch -Q -l ~/.config/emacs/install-tree-sitter-grammars.el
```

Document those commands and their prerequisites in comments at the top of `profiles/common/.config/emacs/init.el`. Normal startup must never invoke either provisioner, refresh package archives, clone repositories, compile native code, or install software. The final package audit must make `install-packages.el` cover every retained third-party declaration before the two-command bootstrap is accepted from an empty package and grammar directory.

The bootstrap requires Emacs 31.1+ with dynamic-module and native Tree-sitter support, Git, and a C/C++ compiler and linker. Language servers, ripgrep, `zmx`, and optional `difft` remain operating-system prerequisites. After Phase 6 configures a stable Ghostel module directory, provision Ghostel's platform-specific native module explicitly through its public download or compile command.

Startup order:

1. Configure package sources and native options without network access or package installation.
2. Configure editor, minibuffer, completion, history, project, and UI behavior.
3. Configure retained personal workflows.
4. Configure Eglot, Flymake, Xref, explicit completion, and Tree-sitter.
5. Configure Ghostel, `term-sessions.el`, and `zmx`.
6. Define direct mappings.

Use `package.el` and bundled `use-package` only. Install or update packages explicitly through `package-vc-install` or `package-install`, never during normal startup. Pin Ghostel and `term-sessions.el` to reviewed revisions, install Dape explicitly, and put Ghostel's downloaded native module in a stable directory outside its package checkout.

## Decisive subsystem choices

| Area | Decision | Reason |
| --- | --- | --- |
| Package management | Use `package.el` and `package-vc`; remove Straight and Quelpa. | Current startup refreshes archives and bootstraps three package systems at `profiles/common/.config/emacs/init.el:2`. |
| Code completion | Bind explicit native CAPF to `C-SPC` in Evil insert state, retain `C-M-i` as the terminal-safe fallback, retain explicit dabbrev completion on `M-/`, and use Yasnippet only for placeholders returned by explicit Eglot completion. | This matches Neovim's explicit trigger, completion-menu navigation, and active-snippet field navigation while retaining a reliable TTY key path. No Corfu, Cape, Company, or automatic popup is needed. [CAPF documentation](https://www.gnu.org/software/emacs/manual/html_node/elisp/Completion-in-Buffers.html) |
| Minibuffer completion | Use vertical Icomplete with `basic`, `partial-completion`, and `flex` styles, including explicit in-buffer CAPF candidates. | Fast native selection for files, buffers, commands, search history, and sessions without automatic code suggestions. [Icomplete documentation](https://www.gnu.org/software/emacs/manual/html_node/emacs/Icomplete.html) |
| LSP | Use built-in Eglot, started explicitly per project or buffer. | Eglot integrates Xref, Flymake, Eldoc, formatting, and CAPF without a separate LSP framework. [Eglot features](https://www.gnu.org/software/emacs/manual/html_node/eglot/Eglot-Features.html) |
| DAP | Install and configure Dape, but never start it automatically or make it the default debugger. | Emacs has built-in GUD for GDB, LLDB, and PDB. Dape is an explicit, independently configured DAP client for workflows that need adapter-protocol features. [Dape](https://github.com/svaante/dape) |
| Structural Git diffs | Optionally install and enable `difftastic.el` only when the `difft` executable is present, using its supplied Magit bindings. | This adds syntax-aware review inside existing Magit transients without making an external tool a startup requirement or duplicating the integration. |
| Search | Use project.el, ripgrep-backed Xref, Isearch, Occur, Imenu, and native minibuffer completion. | Removes both the Consult and Ivy/Counsel picker stacks. |
| Parsing | Replace legacy Tree-sitter packages with built-in `treesit`, native defun motion, Hideshow, and Which Function. | Emacs 31 owns parser integration, structural motion, structural folding, and lightweight function context. Query-backed Evil text objects remain gated on complete language validation. |
| Theme | Vendor a compact standalone `mig-one-light` theme under the Emacs profile and remove the Doom Themes dependency. | A repo-owned native theme preserves the actively used One Light surface without inheriting Doom's 1,258-face compatibility matrix or future upstream face cycles. |
| Terminal renderer | Replace Vterm with Ghostel and `evil-ghostel`. | Ghostel is the one substantial terminal package, with native PTY rendering and maintained Evil integration. [Ghostel](https://github.com/dakra/ghostel) |
| Persistent terminals | Configure `term-sessions.el` with `term-sessions-preferred-frontend` set to `ghostel`; use `zmx` as the session owner. | Sessions survive buffer kills, Emacs restarts, and SSH drops while the remote host and its zmx runtime state remain available. [term-sessions](https://github.com/ArthurHeymans/emacs-term-sessions) |
| Terminal selection | Bind `term-sessions-open` and `term-sessions-list`; do not bind Consult integrations. | They already use `completing-read` and `tabulated-list-mode`: `refs/emacs-term-sessions/term-sessions-zmx.el:333`, `refs/emacs-term-sessions/term-sessions-list.el:66`. |
| REPL dispatch | Use named `zmx` sessions as the generalized text target; retain Python's native Comint route as an optional specialized target; make tmux delivery opt-in. Route annotation queues for any terminal coding agent through the same zmx primitive. | This keeps one durable terminal protocol while preserving Python-mode semantics where they materially help. |
| Project tasks | Keep a per-project command catalog. One owned command selects a task and invokes `ghostel-compile`; do not enable `ghostel-compile-global-mode`. | This provides explicit TTY-aware compilation without global advice or a separate Emacs implementation for each build, test, check, or fix task. |
| Mappings | Replace General with one owned sparse leader map and direct Evil key definitions. Retain Which Key. | `SPC` must not be a leader in insert or Emacs states. |
| AI and transcription | Retain explicit Gptel commands and agent-agnostic terminal annotation dispatch; remove Whisper and audio-device helpers. | AI remains deliberate; transcription is unwanted. |

## Plugin disposition

### Retain

- `evil`, `evil-collection`, `evil-org`, `evil-surround`, `evil-visualstar`, `evil-numbers`
- `which-key`, `magit`, `doom-modeline`, `olivetti`, and the repo-owned `mig-one-light` theme
- `yasnippet`, only for placeholder expansion and navigation from explicitly requested Eglot completions
- `difftastic.el`, only on machines with the external `difft` executable, integrated through `difftastic-bindings-mode`
- Org, Org Roam, bibliography, and prose packages with an active personal workflow
- `gptel`, only through explicit commands
- `dape`, installed and configured with documented explicit launch and attach commands, but never started by a mode hook or project visit
- `ghostel`, `evil-ghostel`, and the bundled explicit `ghostel-compile`
- `term-sessions.el`, with `zmx` installed as an external prerequisite
- Language modes matching the complete Neovim configuration surface:
  - C and C++, Rust, Lua, Python, JavaScript, TypeScript, Zig, Nim, and Odin, each with its Neovim-configured language-server and parser equivalent
  - Markdown, including inline Markdown syntax
  - CSS, HTML, and PHP
  - Plain text and Git commit messages

### Language support contract

Retain or configure the following Emacs modes and native Tree-sitter grammars to match `profiles/common/.config/nvim/init.lua:297` and `:338`. Do not drop a language simply because it lacks a configured Neovim language server.

| Language or content | Neovim support | Emacs target |
| --- | --- | --- |
| C and C++ | `clangd`, parser | Native mode, Eglot through `clangd`, native grammar |
| Rust | `rust-analyzer`, parser | Native mode, Eglot through `rust-analyzer`, native grammar |
| Lua | `lua-language-server`, parser | Native mode, Eglot through `lua-language-server`, native grammar |
| Python | `ty`, Ruff, parser | Native Python mode, Eglot through the configured Python servers, native grammar, and the optional Comint route |
| JavaScript and TypeScript | `typescript-language-server`, parsers | Native modes, Eglot through `typescript-language-server`, native grammars |
| Zig | `zls`, parser | Native mode, Eglot through `zls`, native grammar |
| Nim | `nimlangserver`, parser | Nim mode, Eglot through `nimlangserver`, native grammar |
| Odin | `ols`, parser | Odin mode, Eglot through `ols`, native grammar |
| Markdown | Markdown and inline parsers | Markdown mode and native Markdown grammar support, with retained prose workflow |
| CSS, HTML, PHP | Filetype-specific indentation | Retain their modes and two-space indentation behavior; no new language server is required by this plan |
| Plain text and Git commits | Prose wrapping, spelling | Retain text and Git commit modes with wrapping and spelling |

### Neovim parity follow-up analysis

The Neovim configuration already implements several explicit workflows more completely than the original Emacs plan. The target is behavioral parity through native Emacs ownership where practical, not a claim that Neovim lacked these features.

- Completion at `profiles/common/.config/nvim/init.lua:255` and `:528` is already explicit: LSP autotrigger is disabled, `C-SPC` requests completion, and `TAB` acts only on an active menu or snippet. Phase 2 matches the explicit CAPF and menu behavior. Phase 3 adds narrowly scoped Yasnippet support for Eglot snippet placeholders without adding an automatic completion frontend or idle `TAB` expansion.
- LSP operations at `profiles/common/.config/nvim/init.lua:731` already cover formatting, rename, actions, hover, signatures, inlay hints, diagnostics, and mutable workspace folders. Emacs uses `eglot-format` for region-or-buffer formatting, Eldoc for combined hover and signature display, `eglot-inlay-hints-mode`, and Flymake's native diagnostic lists. `project.el` supplies initial workspace folders; runtime workspace-folder mutation remains intentionally absent because Eglot has no public interactive API for it.
- Picker mappings at `profiles/common/.config/nvim/init.lua:667` cover highlights, marks, jumps, search history, open-buffer grep, type definitions, and directional call hierarchy. Phase 5 uses `describe-face`, `evil-show-marks`, `evil-show-jumps`, `multi-occur`, `eglot-find-typeDefinition`, and the unified `eglot-show-call-hierarchy`. Isearch keeps its persisted in-session history rather than adding an owned picker. Native UIs trade Snacks-style live preview and uniform fuzzy filtering for smaller package and maintenance cost.
- Tree-sitter editing at `profiles/common/.config/nvim/init.lua:337` includes counted function and parameter text objects, function motions, folds, and three-line cursor context. Emacs uses native counted defun motion, Hideshow structural folds, and Which Function context. Full query-backed `af`, `if`, `aa`, and `ia` parity is adopted only if one revision-pinned Evil package validates against the active built-in grammars without loading the legacy `tree-sitter` feature; otherwise the plan records the text-object UI as a deliberate residual gap rather than maintaining per-grammar queries in `init.el`.

### Native Tree-sitter editing contract

- Enable native Tree-sitter modes only when their reviewed grammars are installed. JavaScript requires both the `javascript` and auxiliary `jsdoc` grammars; Markdown requires both `markdown` and `markdown-inline`.
- Enable `hs-minor-mode` and `which-function-mode` in active native parser modes. Evil's existing `z` folding commands must operate through Hideshow without `ts-fold`.
- In Phase 5, add buffer-local Evil motions for `[m`, `]m`, `[M`, and `]M` using Emacs 31's counted Tree-sitter defun navigation. Motions must record Evil jumps and exist only where the active mode supplies a parser-backed defun contract.
- Evaluate revision-pinned `evil-textobj-tree-sitter` only for `af`, `if`, `aa`, and `ia`. Accept it only when query compilation, count behavior, mode-language mappings, and legacy-feature isolation pass for the retained language surface. Do not vendor per-grammar node queries into `init.el`.
- Use Which Function as the maintained context baseline. Do not add a partial three-line context package that omits Lua, Zig, Nim, Odin, or Markdown.

### Remove

- Straight, Quelpa, their bootstraps, and automatic archive refresh/install at `profiles/common/.config/emacs/init.el:2`
- Whisper plus FFmpeg/audio-device code at `profiles/common/.config/emacs/init.el:319`
- Vterm and `my/run-in-vterm` at `profiles/common/.config/emacs/init.el:545`
- Corfu, Cape, Company remnants, and Orderless at `profiles/common/.config/emacs/init.el:623`
- Consult, Embark Consult, Consult Eglot, Counsel, Ivy, Ivy Rich, Ivy Xref, LSP Ivy, and dependent mappings at `profiles/common/.config/emacs/init.el:729`
- `ivy-bibtex`, replacing its entry points with native-completion bibliography commands
- Legacy `tree-sitter`, `tree-sitter-langs`, and `ts-fold` at `profiles/common/.config/emacs/init.el:811`
- Undo Tree and its Evil integration at `profiles/common/.config/emacs/init.el:452`
- General at `profiles/common/.config/emacs/init.el:901`
- Doom Themes after the repo-owned One Light theme replaces its active visual surface
- Stale `vi-tilde-fringe-mode`, stale `company-mode` calls, and unused package declarations discovered in the final audit

## Current problems to eliminate

- Startup reaches the network, installs packages, and evaluates bootstrapped code.
- `TERM` is globally cleared at `profiles/common/.config/emacs/init.el:115`, contaminating child processes.
- Eglot is commented out at `profiles/common/.config/emacs/init.el:599`, while a leader mapping invokes it at `:1002`.
- Corfu enables automatic completion and Cape globally augments CAPFs.
- Consult and Ivy/Counsel duplicate retrieval and completion behavior.
- Vterm carries a large hand-maintained Evil key layer that Ghostel replaces.
- `SPC w m` is defined twice at `profiles/common/.config/emacs/init.el:991` and `:994`.
- `cousnel-org-tag` is misspelled at `:984`.
- Global `TAB` overrides context-sensitive indentation and completion at `:1413`.
- `package-selected-packages` preserves obsolete package state at `:67`.
- `vc-ignore-dir-regexp` includes `tramp-file-name-regexp` at `:1063`, preventing the VC-aware project workflow needed for remote projects.
- Installed Doom Themes 20250920.430 creates an Emacs 31 Gnus face inheritance cycle when CSS mode lazily loads EWW and Gnus. A temporary theme-scoped override keeps Phase 3 web modes usable; Phase 4 removes the dependency entirely with a repo-owned theme.

## Project-root and path contract

- `default-directory` remains buffer-local. Do not create a global cwd.
- Project file, grep, compilation, and terminal actions use `project-current`.
- Eglot server roots remain protocol-specific and never redefine project or terminal scope.
- `ghostel-project` opens an ordinary terminal at the current project root.
- `term-sessions-open` opens or creates a named `zmx` session for the current local or TRAMP directory.
- Ghostel is the only `term-sessions.el` frontend. Its adapter preserves title and directory tracking at `refs/emacs-term-sessions/term-sessions-frontends.el:60`.
- `zmx` must be installed locally and on every remote host where sessions are controlled.
- Org `term-session` links and Babel blocks preserve session identity instead of creating an Emacs-side session store.

## Project command catalog contract

Keep one command catalog per project. The catalog is project data, not a new Elisp command for every task: define `my/project-commands` as a simple, validated directory-local alist of task label and shell command. Store it in the repository's `.dir-locals.el` or another reviewed project-local configuration file. The catalog is always resolved from `project-current`, so the same catalog runs in a local project or at its TRAMP remote root.

`my/project-run-command` is the only owned task runner. It presents the current project's catalog through native `completing-read`, defaults to `Compile`, binds `default-directory` to the project root, then passes the selected shell command to `ghostel-compile`. It gives each task label a distinct Ghostel compilation buffer, allowing an in-progress test and check to coexist. `ghostel-recompile` reruns the selected task unchanged.

Every project begins with these catalog roles, in this order:

| Task | Default command | Catalog rule |
| --- | --- | --- |
| `Compile` | No universal default | The project supplies its exact build command. |
| `Test` | No universal default | The project supplies its exact test-suite command. |
| `Check` | `./run.py check` | Performs additional static analysis for compiled code. A project may override the command. |
| `Fix` | `./run.py check --fix` | Applies the available fixes from the check workflow. A project may override the command. |

Projects may add any further labels, such as `Lint`, `Typecheck`, `Docs`, or a focused test command, without adding a keybinding, new runner, or a Ghostel integration. Do not infer build or test commands from the major mode. Do not enable `ghostel-compile-global-mode`, and do not use a mutable global `compile-command` as the project catalog.

## Remote development contract

Use local Emacs with TRAMP as the sole remote-development architecture:

```text
Local Emacs
  -> /sshx:host:/repo/
       -> remote Git, rg, build tools, language servers, Python/IPython, and zmx
  -> Ghostel renders remote terminal attachments locally
```

- Visit a remote project root such as `/sshx:build-box:/srv/work/api/`. `project-find-file`, `project-find-regexp`, Xref, compilation, Ghostel, and `term-sessions.el` inherit that remote `default-directory`.
- Start Eglot explicitly from the remote source buffer. TRAMP starts the language server on the remote host; Eglot and Xref convert remote paths at their protocol boundaries, while Tree-sitter parsing stays local.
- Require each remote development host to provide a POSIX shell, Git, ripgrep, the relevant project toolchain and language servers in the noninteractive `PATH`, and a reviewed `zmx` release. Install Ghostel shell integration and `xterm-ghostty` terminfo on persistent remote hosts when directory tracking and complete terminal capabilities are wanted.
- Open an ordinary nonpersistent terminal with `ghostel-project`. Open a durable terminal with `term-sessions-open`, which attaches the remote `zmx` session through Ghostel. After an Emacs restart or SSH drop, revisit the remote project or open a saved Org session link, then attach the same session name.
- `term-sessions-list` lists local sessions and already connected TRAMP remotes. It does not scan all SSH hosts after a fresh Emacs start. zmx sessions survive an Emacs restart or SSH drop, but not necessarily a remote reboot or cleanup of their runtime directory.
- Do not nest `local zmx -> ssh -> remote zmx`. The supported shape is TRAMP -> Ghostel -> remote zmx. Do not add a remote Emacs daemon, TCP-forwarded LSP, or `tramp-rpc` to this baseline.
- Remove the current TRAMP-wide VC exclusion. Replace the obsolete `tramp-use-ssh-controlmaster-options` setting with the Emacs 31 `tramp-use-connection-share` setting, but do not force connection sharing for Eglot's remote language-server process or globally enable direct asynchronous `ssh` processes.

## Phase 1: Establish a native, offline startup baseline

Status: complete

### Changes

1. Repair or upgrade Emacs so batch startup works.
2. Remove Straight, Quelpa, archive refresh, and package installation from startup.
3. Keep `package.el` initialization and use bundled `use-package` without `:ensure` or network-backed declarations.
4. Remove stale package selection state and the global `TERM` override.
5. Remove Whisper, its keybinding, and its FFmpeg/audio helpers.
6. Install Ghostel and `term-sessions.el` explicitly through `package-vc`, pinned to the reviewed sources under `refs/ghostel` and `refs/emacs-term-sessions`.
7. Install Dape explicitly through `package.el`. Do not start a debug adapter or add a global Dape mode during startup.
8. Treat `difftastic.el` as a machine capability: when `(executable-find "difft")` succeeds, install it explicitly through `package-vc` from the reviewed `refs/difftastic.el` source. Do not install or load it on machines without `difft`.

### Verification

- `emacs --batch --eval '(princ emacs-version)'` succeeds.
- Loading `init.el` performs no network request or package installation.
- A second startup behaves identically.
- A machine without `difft` loads the configuration without `difftastic.el` being installed or required.

### Success criteria

- `package.el` is the only package manager.
- Startup is deterministic and offline.
- No Whisper-related symbol remains.
- Dape is installed but no debug adapter starts until the user invokes an explicit Dape command.
- Difftastic support is optional and follows the presence of the external `difft` executable.

### Outcome

- `profiles/common/.config/emacs/init.el` uses bundled `use-package` through `package.el` without startup refreshes, installs, `:ensure`, Straight, or Quelpa.
- `profiles/common/.config/emacs/install-packages.el` is the explicit provisioner. It installs Dape from GNU ELPA and passes reviewed revisions through the native `package-vc-install` `REV` argument for Ghostel, `term-sessions.el`, and Difftastic when `difft` is present.
- Installed and verified Ghostel at `7c4cbd9f487b545c3d0452ab749f65eaa3c18b7e`, `term-sessions.el` at `0815dbea006128df1d61e9d29e5a8ada53b349c1`, Difftastic at `f94076985ba46bf629abc9615c9b1fefcc3390ef`, and Dape 0.27.1.
- Two guarded startup loads completed with package installation, archive refresh, VC installation, and synchronous URL retrieval replaced by errors. A simulated machine without `difft` selected and loaded no Difftastic feature.
- Dape, Ghostel, `term-sessions.el`, and Difftastic remained unloaded after normal startup. Ghostel's native module remains an explicit first-use installation for Phase 6.
- Startup mean improved from 8.130 s to 3.966 s across the recorded five-run samples.

## Phase 2: Replace automatic completion and picker stacks

Status: complete

### Changes

1. Remove Corfu, Cape, Company remnants, Orderless, Consult, Ivy, Counsel, and dependent mappings.
2. Enable vertical Icomplete and native completion styles.
3. Bind `completion-at-point` to `C-SPC` in Evil insert state, retain `C-M-i` for terminal frames, and retain `M-/` for explicit dabbrev completion.
4. Enable Icomplete's explicit in-buffer candidate display. Bind `TAB` and `S-TAB` in its native transient completion map only, and disable completion preview and every global CAPF injection.
5. Restore native `C-s` Isearch, enable `savehist-mode` and `recentf-mode`, and remove the global `TAB` override.

### Verification

- Entering insert state never opens a completion menu automatically.
- `C-SPC` invokes CAPF only when requested, and `C-M-i` remains usable in `emacs -nw`.
- `TAB` and `S-TAB` cycle candidates only during an active explicit completion.
- `M-x`, file prompts, buffer prompts, and terminal-session prompts use Icomplete.

### Success criteria

- No completion frontend or source package remains.
- Completion is explicit and native.

### Outcome

- Removed Corfu, Cape, Company remnants, Orderless, Consult, Embark Consult, Consult Eglot, Ivy, Counsel, Ivy Rich, Ivy Xref, and `ivy-bibtex`, including their direct bindings and global CAPF injection.
- Enabled vertical Icomplete for minibuffer and explicit in-buffer completion with `basic`, `partial-completion`, and `flex` styles. Completion Preview remains disabled.
- Bound `C-SPC`, `C-M-i`, and `M-/` directly in Evil insert state. `C-M-i` resolves to `completion-at-point` even when Flyspell is active, while other Evil states retain native bindings.
- Bound `TAB` and `S-TAB` only in `completion-in-region-mode-map`; the global `TAB` binding remains `indent-for-tab-command`.
- Restored native `C-s` Isearch in Evil normal, visual, and insert states, persisted both search rings with Savehist, and enabled Recentf.
- Retained completion-agnostic Org Ref citation, PDF, and URL commands in place of `ivy-bibtex` actions.
- Batch assertions verified key precedence, completion state, removed features, history modes, and config loading. Startup mean improved from 3.966 s to 2.807 s across the recorded five-run samples.

## Phase 3: Rebuild language services with Emacs primitives

Status: complete

### Changes

1. Activate Eglot configuration for every language server in the language support contract. Retain only server overrides that Emacs cannot infer.
2. Start Eglot explicitly. Do not use `eglot-ensure`.
3. Retain Flymake diagnostics after an Eglot session starts.
4. Map `eglot-format` for region-or-buffer formatting plus explicit code actions, rename, combined hover/signature display, inlay hints, and Xref commands.
5. Set Xref to use `rg` when available.
6. Replace legacy Tree-sitter packages with native grammar configuration and explicit pinned grammar installation for every parser-backed language in the language support contract, including Emacs 31 JavaScript's auxiliary `jsdoc` grammar.
7. Configure Dape without autostart. Document the `dape` launch and attach commands, adapter installation prerequisites, and each configured adapter's local or remote scope beside the configuration. Start with only verified adapters for active workflows, keeping GUD as the default debugger.
8. Retain Python mode's `C-c C-p`, `C-c C-r`, `C-c C-c`, and `C-M-x` commands for the optional native Python Comint route outside Evil visual state. In Evil visual state, deliberately reserve `C-c C-c` for the generalized zmx sender. Configure IPython only through `python-shell-interpreter` and `python-shell-interpreter-args`, and apply `ghostel-comint-mode` only to `inferior-python-mode-hook` when wanted.
9. Install Yasnippet explicitly as Eglot's snippet expander. Do not enable idle snippet expansion or automatic completion. Keep `TAB` and `S-TAB` field movement confined to an active snippet map, behind the completion transient map.
10. Enable native Hideshow and Which Function in active Tree-sitter modes. Do not add `ts-fold` or a partial cursor-context package.
11. Retain CSS, HTML, and PHP with two-space indentation through their current public mode variables. While the installed Doom Themes release remains active, apply the smallest theme-scoped Emacs 31 Gnus face-cycle compatibility override; Phase 4 removes the dependency and override together.

### Verification

- An explicitly started Eglot session supplies diagnostics, Xref, Eldoc, and CAPF.
- `eglot-format` formats the active region and otherwise the full buffer; formatting and code actions run only from explicit mappings.
- Explicit Eglot snippet completion expands through Yasnippet. Completion candidates take `TAB` precedence over snippet fields, and ordinary `TAB` remains unchanged when neither is active.
- A language with an installed native grammar uses `treesit` without legacy packages.
- Each Neovim-configured LSP language can start its corresponding Eglot server, and all 14 required native grammars load from the pinned provisioner.
- JavaScript mode loads and fontifies with both `javascript` and `jsdoc`; Markdown selects native mode only with both Markdown grammars and otherwise retains `gfm-mode` or `markdown-mode`.
- Hideshow folds and Which Function context work in representative native C, Python, and TypeScript buffers without loading legacy Tree-sitter features.
- A local and TRAMP-remote `run-python` session can evaluate a region and buffer with the native Python commands; its output remains in `*Python*`.
- Dape loads and exposes its documented explicit launch and attach commands, while visiting a project or source buffer starts no DAP session.
- CSS, HTML, and PHP modes open with two-space indentation and no Gnus face inheritance cycle or obsolete PHP indentation warning.

### Success criteria

- Eglot, Flymake, Xref, and native Tree-sitter are the only language-service layers.
- Code completion and snippet expansion remain explicit.
- Language-server executables remain external system prerequisites.

### Outcome

- Activated dormant built-in Eglot with Emacs 31's inferred server contacts plus only the required Python `ty` and Nim `nimlangserver` overrides. Explicit aliases cover region-or-buffer formatting, code actions, rename, combined Eldoc hover/signatures, navigation, and inlay hints; Xref selects ripgrep when available.
- Installed and verified Dape 0.27.1, PHP mode 20260825.1535, Yasnippet 20250602.1342, and Odin mode at `21c6ff8b49f5eaa2d3b9969feeb08de921f11e92` through the explicit package provisioner. Dape remains restricted to documented `lldb-dap` launch and attach workflows and starts no process during normal startup.
- Added a staged, fail-fast native grammar provisioner for C, C++, Rust, Lua, Python, TypeScript, TSX, JavaScript, JSDoc, Zig, Nim, Odin, Markdown, and inline Markdown. Every pinned grammar compiled, passed isolated fresh-Emacs validation, and was atomically installed. JavaScript and Markdown mode selection passed their auxiliary-grammar checks.
- Replaced legacy Tree-sitter and `ts-fold` with native modes, Hideshow folding, and Which Function context. Representative C, Python, TypeScript, and nested Markdown section tests passed without loading legacy parser features.
- Yasnippet is available only as Eglot's explicit snippet expander. Idle and global `TAB` bindings remain unchanged, completion candidate navigation takes precedence, and active snippet `TAB`, `S-TAB`, `S-<tab>`, and `<backtab>` field navigation passed.
- Retained two-space CSS, HTML, and PHP indentation using public mode variables. A temporary theme-scoped override fixes the installed Doom Themes 20250920.430 Gnus face cycle until Phase 4 removes that dependency.
- Two complete static acceptance loads passed. A real explicitly started `ty` session supplied Eglot-managed Flymake, Xref, Eldoc, and CAPF, then shut down; local native Python region and buffer evaluation both produced output in `*Python*`. No configured service autostarted.
- No TRAMP host was available for a live remote Eglot or Python Comint session. The configuration uses the built-in remote-aware Eglot and Python paths without local-only wrappers; live remote acceptance remains in Phase 7.
- Startup mean improved from 2.807 s to 2.665 s across the recorded five-run sample.

## Phase 4: Vendor the active theme

Status: complete

### Changes

1. Add `profiles/common/.config/emacs/themes/mig-one-light-theme.el` as a compact standalone Emacs theme derived from the actively used Doom One Light palette and retained workflow faces.
2. Use direct colors and stable core-face inheritance. Do not vendor Doom's macro DSL, 1,258 generated face settings, unused package compatibility matrix, or Gnus sibling-face cycles.
3. Include the upstream MIT copyright notice, license text, source commit `556598955c67540eac8811835b327f299ffb58c7`, and attribution URL in the theme file.
4. Add the repo-owned theme directory to `custom-theme-load-path`, load only `mig-one-light`, and remove `doom-themes`, its compatibility override, and its Neotree and Org helper calls.
5. Retain a visual bell only through a small repo-owned implementation if the workflow still needs it. Keep `doom-modeline` independent and style its retained faces in the local theme.

### Verification

- With Doom Themes absent from an isolated package directory, startup loads `mig-one-light` twice offline and no Doom Themes feature is present.
- Representative core, font-lock, region/search, Icomplete, line-number, mode-line, ANSI, compilation, diff, Flymake, Org, Magit, Markdown, Dired, Which Key, Doom Modeline, Evil, Flyspell, and Gptel faces match the active One Light appearance except for documented removals.
- Loading CSS/Gnus, Org, Magit, and Markdown realizes their faces without an inheritance cycle.
- A graphical frame and `emacs -nw` receive a focused visual comparison.

### Success criteria

- The active theme is repo-owned and independent of Doom Themes.
- `init.el` remains readable and does not contain a generated theme dump.
- The phase has its own startup benchmark and commit so the theme delta is attributable.

### Outcome

- Added the 294-line standalone `profiles/common/.config/emacs/themes/mig-one-light-theme.el` with 221 intentional face settings and one theme variable. It preserves the active One Light palette across core UI, syntax, completion, Xref, diagnostics, diffs, prose, Org, Org Agenda, Org Cite, Org Ref, Magit, Which Key, Doom Modeline, Evil, Flyspell, and Gptel.
- Included the upstream MIT notice and source attribution for Doom Themes commit `556598955c67540eac8811835b327f299ffb58c7`. Direct colors replace Doom's runtime blending, unused compatibility faces are omitted, and lower-color terminals deliberately use Emacs's nearest-color approximation.
- Removed the Doom Themes package declaration, its Gnus compatibility override, and its visual bell, Neotree, and Org helpers. The existing explicit no-bell policy remains, Doom Modeline stays independent, and `custom-enabled-themes` contains only `mig-one-light`.
- The theme byte-compiled without warnings. Two guarded full loads, two isolated loads without Doom Themes, retained package face realization, Isearch and line-number parity, Org research faces, CSS/Gnus cycle checks, dead-face checks, and a real pseudo-TTY load all passed.
- No live graphical frame was available for a manual visual comparison. Programmatic face parity and true-color pseudo-TTY acceptance passed; the manual graphical comparison remains in Phase 7.
- Startup mean increased from 2.665 s to 2.826 s across the recorded five-run sample. The 0.161 s regression is retained in the benchmark record for later final optimization rather than hidden.

## Phase 5: Rebuild project retrieval and direct mappings

Status: complete

### Changes

1. Define one sparse owned leader map and bind it directly through Evil.
2. Replace Counsel file/buffer/search actions with `project-find-file`, `switch-to-buffer`, `recentf-open-files`, `project-find-regexp`, Occur, Imenu, and Xref.
3. Add direct Eglot, diagnostics, Magit, review, Org, and help mappings under their owned prefixes.
4. Retain Which Key solely for discovering that map.
5. Resolve duplicate and broken mappings, including `SPC w m` and `cousnel-org-tag`.
6. Bind native file, buffer, search, Eglot, diagnostic, terminal, and Gptel commands to their stated ownership prefixes without shadowing Python mode's specialized `C-c` bindings.
7. Bind `my/annotate-region` to visual `SPC r a` and `my/annotate-send-all` to `SPC r s` under the dedicated review prefix; do not add an agent-specific leader map.
8. When `difft` and the explicitly installed `difftastic.el` package are available, configure `difftastic-bindings-alist` with only the supplied Magit diff, blame, and file-dispatch entries, then enable `difftastic-bindings-mode`. Do not add leader bindings or owned wrappers, and do not enable the package's Dired or Forge entries. Leave Magit unchanged when the executable is absent.
9. Add the native highlight, mark, jump, selected-buffer grep, type-definition, and unified call-hierarchy mappings in the target contract. Keep Isearch history on `C-s`, `M-p`, and `M-n` rather than adding an owned picker.
10. Add buffer-local counted Tree-sitter defun motions for `[m`, `]m`, `[M`, and `]M` where the active mode supplies the native parser contract. Record Evil jumps.
11. Evaluate a revision-pinned `evil-textobj-tree-sitter` only for counted `af`, `if`, `aa`, and `ia`. Adopt it only if the retained grammar and legacy-feature isolation criteria pass; otherwise document the exact residual text-object gap.

### Verification

- Every leader operation has one canonical mapping.
- No `SPC` leader exists in insert or Emacs state.
- Every project search honors the current project root.
- Evil marks and jumps list populated entries and navigate on `RET`; `multi-occur` finds matches across selected buffers including unsaved edits.
- `describe-face`, type definition, and unified call hierarchy work through native completion and Eglot, with prefix direction selection where supported.
- Native Tree-sitter function motions honor counts and record jumps. Any adopted query-backed text objects compile and select correctly without loading legacy `tree-sitter`.
- With `difft` available, the Magit diff, blame, and file-dispatch contexts expose the supplied Difftastic actions and produce a structural diff. Without `difft`, those actions are absent and normal Magit diffs still work.

### Success criteria

- No removed picker command is referenced.
- Search, navigation, and history work through native commands and the minibuffer.
- Review annotations have their own `SPC r` prefix, and optional Difftastic support is contained within Magit.

### Implementation decisions

- Native project discovery retains Emacs's default VC directory exclusions, so `project-try-vc` can inspect both local and TRAMP Git roots. TRAMP connection sharing is configured only through Emacs 31's public `tramp-use-connection-share` option.
- Parser-backed defun motions use `treesit-thing-defined-p`, the same public predicate used by `treesit-major-mode-setup`, so modes such as `python-ts-mode` that define defuns through language-scoped `treesit-thing-settings` receive the mappings.
- The normal and visual leader overlays are named maps. Which Key annotates each overlay's actual `SPC a` binding, preserving state-specific AI commands while leaving insert and Emacs states unchanged and giving Phase 6 direct extension points.
- Phase 5 binds only commands that exist at this stage. `SPC t`, `SPC r`, and visual `SPC a c` remain unbound until Phase 6 defines the terminal transport, annotation queue, project command runner, and Gptel region composer. Their Phase 6 mapping work is not duplicated here.
- `SPC o j` remains unbound because the old configuration referenced an undefined `my/goto-journal`, and the target contract forbids adding an owned compatibility wrapper where no implemented journal workflow exists.
- `evil-textobj-tree-sitter` revision `fecc0e11615df31a6651ce11b012388e53cad4e9` was rejected. Its built-in `treesit` mode-language table omits `nim-mode`, `odin-mode`, and `markdown-ts-mode`; Markdown has no built-in text-object query; and the retained surface therefore cannot pass the required mapping and query gates without repo-owned compatibility mappings or queries. The package's optional `(require 'tree-sitter nil t)` does not load the legacy feature when it is absent, but legacy-feature isolation alone is insufficient for adoption. Counted `af`, `if`, `aa`, and `ia` remain a deliberate residual gap.

### Outcome

- Replaced General and the duplicate legacy bindings with one native sparse leader map, plus named normal and visual overlays for the intentionally state-specific Gptel commands. `SPC` is a leader only in Evil normal and visual states, and Which Key annotates the actual maps users invoke.
- Added the complete Phase 5 native file, buffer, window, tab, project search, symbol, Eglot, Flymake, Dape, Magit, Org, help, mark, jump, highlight, and selected-buffer search mappings. Every bound leaf resolves to an interactive command or valid autoload, while Python's native `C-c` bindings remain intact.
- Added native counted Tree-sitter function-start and function-end motions through Evil's jump-aware section commands. Real Python and C parsers passed count, direction, and jump-list checks.
- Enabled the pinned Difftastic package only when `difft` is available and limited it to the reviewed Magit diff, blame, and file-dispatch entries. Both the Difftastic-present branch and ordinary-Magit fallback passed.
- Restored local and TRAMP VC project discovery by removing the broad remote exclusion and using Emacs 31's public TRAMP connection-sharing option. Local Git and synthetic `/sshx:` project-root discovery passed; no live SSH host was available.
- Guarded offline startup, byte compilation, mapping-state checks, native parser checks, project search delegation, optional Difftastic branches, and two independent review rounds passed. The first review's remote-project, Python-motion, and Which Key findings were corrected; the fresh final review reported no findings.
- Startup mean increased from 2.826 s to 2.972 s across the recorded five-run sample. The 0.146 s regression, including the 3.271 s first-run outlier, remains recorded for the final performance audit.

## Phase 6: Replace Vterm with Ghostel and persistent sessions

Status: complete

### Changes

1. Remove Vterm, `my/run-in-vterm`, all Vterm Evil bindings, and Vterm line-number hooks.
2. Configure Ghostel's native module directory outside its package tree and keep first-use installation explicit.
3. Enable `evil-ghostel`; do not recreate the removed Vterm forwarding map.
4. Configure `ghostel-project` for ordinary project terminals.
5. Configure `term-sessions.el` with Ghostel: `term-sessions-preferred-frontend` = `ghostel`.
6. Bind `ghostel-project`, `term-sessions-open`, `term-sessions-list`, `term-sessions-history`, and optionally `term-sessions-store-org-link`.
7. Add `my/term-sessions-send-text` as the one owned primitive for selecting a named session and delivering text through public `term-sessions.el` APIs. It appends one carriage return and has no knowledge of source-buffer, annotation, or agent details.
8. Add `my/term-sessions-send-region-or-buffer`, which extracts the active region or full buffer and delegates to `my/term-sessions-send-text`. Bind it to `SPC t r` in normal and visual states, and bind `C-c C-c` to the same command in Evil visual state when that override is reliable. Do not inspect Ghostel buffers or call Ghostel-private send functions.
9. Add `my/annotate-region`, which works in any buffer with an active region and queues a text snapshot, buffer or file identity, line range, major mode, and minibuffer annotation. Bind it to visual `SPC r a`. Add `my/annotate-send-all`, which prompts for an optional overall request, formats the queued annotations as an agent-neutral Markdown prompt, delegates to `my/term-sessions-send-text`, and clears the queue only after a successful send. Bind it to `SPC r s`. Do not add Codex-, Gptel-, or other agent-specific transport code.
10. Add explicit Gptel compose-region and rewrite commands under `SPC a`; ensure neither submits automatically. Retain `gptel-send` as the explicit in-place response command.
11. Add an optional `my/tmux-paste-region-or-buffer` only if dispatch to existing tmux panes remains required. It must prompt for a non-Emacs pane, use `load-buffer` followed by `paste-buffer`, then send Return. Do not use `tmux send-keys` for arbitrary multiline source text.
12. Add the project-local `my/project-commands` catalog and its one owned runner, `my/project-run-command`. Require `Compile` and `Test` entries from every project; seed `Check` with `./run.py check` and `Fix` with `./run.py check --fix`, allowing project overrides and additional labels. The runner must use native completion, default to `Compile`, run at the local or TRAMP project root, create a distinct Ghostel compilation buffer for each label, and delegate execution to `ghostel-compile`. Bind it to `SPC t c`.
13. Retain `ghostel-compile` and `ghostel-recompile` as explicit implementation commands. Do not enable Ghostel's global compilation advice or use global `compile-command` as the catalog.
14. Do not install or bind `consult-ghostel` or `term-sessions-consult-session`.

### Verification

- A Ghostel terminal works in local and TRAMP contexts.
- Evil terminal behavior is supplied by `evil-ghostel`.
- A named `zmx` session survives killing its Emacs buffer and restarting Emacs.
- `term-sessions-list` opens, kills, shows history for, and links sessions using native UI.
- A selected source region and a full source buffer can be sent explicitly to a chosen local and remote named zmx session. Confirm Python multiline behavior with an explicit terminating blank line.
- Where the visual-state override is reliable, `C-c C-c` and `SPC t r` invoke the same generalized sender for a visual selection; Python's native `C-c C-c` buffer evaluation remains available outside visual state. Otherwise, verify that `SPC t r` works and leave `C-c C-c` unchanged.
- Annotations from multiple local or TRAMP buffers form one queue. `my/annotate-send-all` accepts an additional prompt and produces the same session-selection interaction as `SPC t r` when targeting a terminal coding agent.
- In `emacs -nw` inside tmux, zmx delivery and the optional tmux pane adapter work without targeting the pane running Emacs.
- `SPC t c` presents the active project's catalog in this order: `Compile`, `Test`, `Check`, and `Fix`; accepting its default runs `Compile`. `Check` and `Fix` use `./run.py check` and `./run.py check --fix` unless the project overrides them. Two selected tasks can remain visible in separate Ghostel compilation buffers.
- Remote project search, Eglot CAPF/Flymake/Xref, Ghostel compilation, and remote zmx reconnection work after a deliberate SSH disconnect.

### Success criteria

- Vterm is absent.
- Ghostel is the only interactive terminal renderer.
- `zmx` owns persistent session lifecycle and `term-sessions.el` remains a thin native-UI client.
- Every project task runs through its project-local command catalog and the one Ghostel-backed runner.

### Outcome

- Removed Vterm, its Evil forwarding map and hooks, `my/run-in-vterm`, and the bespoke CMake command helpers. Ghostel is configured with a stable module directory at `~/.config/emacs/ghostel/`; first interactive use asks before download or compilation, while normal startup remains dormant and offline.
- Added pinned `evil-ghostel` provisioning, the Ghostel Evil hook, explicit Ghostel compilation commands, and component-level `term-sessions.el` configuration with Ghostel as the sole frontend. Loading the selected public components does not load Consult or the umbrella integration.
- Added one public named-session text primitive, explicit region-or-buffer delivery, and an agent-neutral annotation queue. The transport appends one carriage return, preserves source snapshots and local or TRAMP identity, and clears annotations only after a successful send.
- Added non-submitting Gptel region composition and retained explicit rewrite and send operations. Added the terminal and review leader groups, including the visual-only `C-c C-c` sender without changing Python's native mapping outside visual state.
- Added a validated directory-local project task catalog. Native completion preserves `Compile`, `Test`, `Check`, `Fix`, then additional labels; `Compile` remains the default, Check and Fix have reviewed defaults, and each local or TRAMP task receives a distinct Ghostel compilation buffer.
- Omitted the optional tmux adapter because the retained configuration had no source-to-pane workflow. No private Ghostel or term-session APIs, Consult integration, or global Ghostel compilation advice were introduced.
- Guarded offline double startup, focused transport and catalog tests, Emacs 31 Icomplete ordering, byte compilation, and a fresh final review passed. The first review's native completion ordering finding was corrected. The native Ghostel module, durable zmx lifecycle, real SSH reconnection, graphical terminal, and remote session checks remain in Phase 7 because those runtimes were unavailable.
- Startup mean decreased from 2.972 s to 2.907 s across the recorded five-run sample. The 0.064 s improvement includes a 3.185 s first-run outlier and remains subject to the final performance audit.

## Phase 7: Final cleanup and acceptance

Status: complete

### Changes

1. Remove dead declarations, commented replacement systems, and all references to removed packages.
2. Audit every retained package for a named workflow and a one-line purpose.
3. Keep personal Org, research, prose, Git, and explicit Gptel workflows unless they are genuinely unused.
4. Validate fresh startup, native completion, Eglot, Dape's dormant explicit configuration, project search, optional Difftastic Magit integration, the project command catalog, Ghostel, Python Comint, generalized REPL dispatch, annotation dispatch, and persistent sessions.
5. Reconcile `install-packages.el` with every retained third-party package and remove every obsolete package from the provisioner.
6. Add the two explicit fresh-machine bootstrap commands and prerequisites to the top of `init.el`. Do not add startup-time installation or archive refresh.

### Acceptance suite

- Batch-load the configuration from a clean Emacs state.
- From empty temporary package and grammar directories, run the documented package and grammar provisioners, then load `init.el` twice offline.
- Search for removed symbols: `straight`, `quelpa`, `whisper`, `vterm`, `corfu`, `cape`, `company`, `consult`, `counsel`, `ivy`, `tree-sitter`, `ts-fold`, `undo-tree`, and `general`.
- Exercise project file finding, `rg` search, Isearch history, explicit CAPF, Eglot navigation, dormant Dape startup, Magit's Difftastic actions when `difft` is installed and ordinary Magit fallback when it is not, the project-local `Compile`, `Test`, `Check`, and `Fix` catalog tasks in separate Ghostel compilation buffers, native Python Comint, selected-region and full-buffer zmx dispatch, queued annotations with an additional prompt sent to a terminal coding agent, optional tmux delivery, and a persistent remote-capable `zmx` session.

### Overall success criteria

- Startup is offline, deterministic, and uses one package manager.
- No automatic code completion package or automatic completion behavior remains.
- Yasnippet expands only placeholders returned by explicitly requested completion and never owns an idle global `TAB` binding.
- Native Emacs primitives own completion, retrieval, projects, LSP integration, diagnostics, and parsing.
- The repo-owned One Light theme loads without Doom Themes or cyclic face inheritance.
- Ghostel replaces Vterm completely.
- Persistent terminals are durable named `zmx` sessions accessed through Ghostel and native Emacs interfaces.
- Python's Comint workflow and the generalized zmx workflow remain intentionally separate, explicit, and functional locally, remotely, and in `emacs -nw`.
- Dape is installed, configured, and documented without becoming an automatic or default debugger.
- `difftastic.el` integrates structural diffs into Magit only on machines that provide `difft`; its absence does not affect startup or normal Magit workflows.
- Annotation collection works from any buffer and reaches any terminal coding agent through the same named-session transport as `SPC t r`.
- Build, test, check, fix, and future project tasks are data in one per-project catalog and execute through the same Ghostel-backed runner.
- The documented explicit bootstrap recreates every retained package and grammar from empty directories without relying on normal startup.

### Outcome

- Normal startup remains offline and never provisions software. The top of `init.el` names ripgrep, zmx, the selected language servers, aspell, multimarkdown, LaTeX, and dvisvgm as prerequisites, identifies Difftastic as optional, preserves the package and grammar provisioner commands in their required order, and records the explicit post-package Ghostel module download or compilation commands.
- Removed Undo Tree in favor of Evil's native `undo-redo` integration, removed dead package declarations and commented replacement systems, and deferred retained workflows that do not need to load during startup. The repo-owned `mig-one-light` theme remains the active inline/vendor decision.
- The 25-package direct archive inventory is now `dape`, `doom-modeline`, `evil`, `evil-better-visual-line`, `evil-collection`, `evil-numbers`, `evil-org`, `evil-surround`, `evil-visualstar`, `exec-path-from-shell`, `gptel`, `gscholar-bibtex`, `load-env-vars`, `magit`, `markdown-mode`, `nim-mode`, `ob-async`, `olivetti`, `org-fragtog`, `org-ref`, `org-roam`, `org-roam-bibtex`, `php-mode`, `yasnippet`, and `zig-mode`. Doom Modeline declares Nerd Icons as its archive dependency, so the dead All the Icons declaration and direct provisioner entry are removed without a replacement dependency. Which Key remains configured from Emacs 31.1's built-in copy. Other package dependencies remain archive-resolved. Pinned VC inventory remains Ghostel, Evil Ghostel, term-sessions.el, Odin mode, and optional Difftastic.
- Org Roam BibTeX now follows Org Roam without an installed-feature gate; its package dependency loads Bibtex Completion when the ORB command or Org Roam buffer activates the workflow, then loads Org Ref and applies the retained template customization. Flyspell now covers plain text, programming comments, and Git commit messages, with Magit's idempotent commit setup installing its comment-aware predicate.
- The exact final provisioners passed from a new empty temporary root. Package provisioning completed in 121.65 seconds with 25 direct archive packages, 5 reviewed VC packages, and exactly 61 installed descriptors; All the Icons was absent and Doom Modeline resolved Nerd Icons through its declared dependency. All five VC checkouts matched their reviewed revisions. All 14 pinned grammar libraries provisioned and validated in 52.50 seconds.
- Isolated acceptance passed native completion and mappings, Evil states and native undo/redo, project retrieval and ripgrep search, Eglot configuration, dormant Dape, optional Difftastic and its no-`difft` fallback, project task catalogs, generalized session and annotation transport, native Python Comint, all grammar readiness checks, and repeated repo-theme loading. A temporary Ghostel module downloaded and loaded in 3.38 seconds; a live local Ghostel PTY and a live Ghostel-attached zmx session both passed without writing to the active module or session directories.
- Two deployment-equivalent loads against only the exact final fresh package and grammar trees passed with package refresh, package installation, VC installation, URL retrieval, and grammar installation replaced by errors. The loads passed ORB hook, explicit-command, dependency, Org Ref, customization, text and Git commit Flyspell, built-in Which Key, dormant Ghostel, theme reload, native undo, completion, Xref, Flymake, and leader-map checks. Init, both provisioners, and the vendored theme byte-compiled to `/private/tmp` with warnings but no errors.
- Zig is unavailable, so a temporary source build of the Ghostel module is deferred. Local zmx is available and its create, detach, list, history, send, reattach-through-Ghostel, and kill lifecycle passed under `/tmp`. Remote TRAMP, remote Eglot, remote Python, and remote zmx remain deferred because acceptance has no live remote host.
- Startup mean decreased from 2.907 s to 2.333 s across the recorded five-run sample. The 0.574 s improvement is 19.8 percent for the phase and 71.3 percent from the 8.130 s baseline. The final sample retains a 3.654 s cold first-run outlier; its 1.967 s median records the steady process cost without discarding that outlier.

## References

### Codebase

- `refs/editor-philosophy.md:1`
- `profiles/common/.config/emacs/init.el:2`
- `profiles/common/.config/emacs/init.el:545`
- `profiles/common/.config/emacs/init.el:623`
- `profiles/common/.config/emacs/init.el:729`
- `profiles/common/.config/emacs/init.el:901`
- `profiles/common/.config/emacs/init.el:1018`
- `profiles/common/.config/emacs/init.el:1063`
- `profiles/common/.config/nvim/init.lua:255`
- `profiles/common/.config/nvim/init.lua:337`
- `profiles/common/.config/nvim/init.lua:528`
- `profiles/common/.config/nvim/init.lua:667`
- `profiles/common/.config/nvim/init.lua:731`
- `refs/ghostel/README.org:15`
- `refs/ghostel/README.org:1740`
- `refs/emacs-term-sessions/README.org:3`
- `refs/emacs-term-sessions/term-sessions-frontends.el:60`
- `refs/emacs-term-sessions/term-sessions-actions.el:389`
- `refs/emacs-term-sessions/term-sessions-zmx.el:402`
- `refs/difftastic.el/README.org:147`
- `refs/difftastic.el/difftastic-bindings.el:184`

### Upstream documentation

- [Emacs completion at point](https://www.gnu.org/software/emacs/manual/html_node/elisp/Completion-in-Buffers.html)
- [Eglot](https://www.gnu.org/software/emacs/manual/html_node/eglot/Eglot-Features.html)
- [Emacs projects](https://www.gnu.org/software/emacs/manual/html_node/emacs/Projects.html)
- [TRAMP quick start](https://www.gnu.org/software/emacs/manual/html_node/tramp/Quick-Start-Guide.html)
- [TRAMP remote processes](https://www.gnu.org/software/emacs/manual/html_node/tramp/Remote-processes.html)
- [Emacs Python mode](https://github.com/emacs-mirror/emacs/blob/master/lisp/progmodes/python.el)
- [Eglot language-server setup](https://www.gnu.org/software/emacs/manual/html_node/eglot/Setting-Up-LSP-Servers.html)
- [Dape](https://github.com/svaante/dape)
- [Ghostel](https://github.com/dakra/ghostel)
- [term-sessions.el](https://github.com/ArthurHeymans/emacs-term-sessions)
- [Yasnippet](https://github.com/joaotavora/yasnippet)
- [Emacs Tree-sitter source](https://github.com/emacs-mirror/emacs/blob/master/lisp/treesit.el)
- [evil-textobj-tree-sitter](https://github.com/meain/evil-textobj-tree-sitter)
- [Doom Themes source used for `mig-one-light`](https://github.com/doomemacs/themes/tree/556598955c67540eac8811835b327f299ffb58c7)
- [Doom Themes Emacs 31 Gnus face issue](https://github.com/doomemacs/themes/issues/883)
