# Emacs configuration alignment plan

## Status

- Plan: in progress
- Implementation: Phase 1 complete; Phase 2 pending
- Target: Emacs 31.1+ with dynamic-module support, `package-vc`, Eglot, Flymake, Xref, project.el, Icomplete, and native Tree-sitter
- Primary configuration: `profiles/common/.config/emacs/init.el`
- Terminal references: `refs/ghostel/README.org`, `refs/emacs-term-sessions/README.org`
- Prerequisite: satisfied on 2026-08-29. `emacs --batch --eval '(princ emacs-version)'` prints `31.1`.

## Startup performance

Measure each accepted phase with Hyperfine using one warmup and five timed runs of:

```sh
emacs -Q --batch -l profiles/common/.config/emacs/init.el --eval '(princ "CONFIG_LOADED\\n")'
```

Times are wall-clock process durations. Deltas compare each row's mean with the immediately preceding row.

| State | Revision | Mean | Median | Range | Delta |
| --- | --- | --- | --- | --- | --- |
| Before Phase 1 | `fbee7f8` | 8.130 s +/- 1.911 s | 7.379 s | 7.160-11.543 s | baseline |
| After Phase 1 | Phase 1 commit | 3.966 s +/- 0.093 s | 4.002 s | 3.817-4.042 s | -4.164 s (-51.2%) |

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

Use native Isearch history rather than a separate search-history picker: `C-s` starts Isearch and `M-p` / `M-n` traverse its persisted history. Leave `SPC s h` and `SPC ?` unbound. The Neovim-only highlights, marks, jumps, buffer-grep, type-definition, and call-hierarchy picker mappings have no selected native equivalent in this plan and remain unbound.

### Code actions and completion

| Key | Command | States | Purpose |
| --- | --- | --- | --- |
| `SPC c f` | `eglot-format` | N, V | Format the buffer or selected region explicitly. |
| `SPC c r` | `eglot-rename` | N, V | Rename the identifier at point. |
| `SPC c a` | `eglot-code-actions` | N, V | Request and apply an explicit code action. |
| `SPC c h` | `eldoc-doc-buffer` | N, V | Show explicit Eglot or mode documentation at point. |
| `SPC c i` | `eglot-inlay-hints-mode` | N, V | Toggle Eglot inlay hints for the current buffer. |

There is no separate native public Eglot command for a standalone signature-help request, so `SPC c s` remains unbound. `SPC c h` and `K` are the explicit documentation and signature view. Workspace-folder editing mappings remain unbound because Eglot does not expose an equivalent public native workflow.

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
| `C-s` | `isearch-forward` | N, V, I | Start native incremental search. |
| `C-SPC` | `completion-at-point` | I | Request explicit CAPF completion outside terminal buffers. |
| `C-M-i` | `completion-at-point` | I | Terminal-safe explicit-completion fallback. |
| `M-/` | `dabbrev-expand` | I | Request explicit dabbrev completion. |
| `TAB` / `S-TAB` | Native completion candidate movement | Completion transient map only | Select the next or previous candidate only while explicit completion is active. |

Keep normal `TAB` indentation and editing behavior everywhere else. Keep standard Isearch keys and use `M-p` / `M-n` inside Isearch for persisted search history.

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
| Code completion | Bind explicit native CAPF to `C-SPC` in Evil insert state, retain `C-M-i` as the terminal-safe fallback, and retain explicit dabbrev completion on `M-/`. | This matches Neovim's explicit completion interaction while retaining a reliable TTY key path. Eglot exposes a CAPF directly. No Corfu, Cape, Company, or automatic popup is needed. [CAPF documentation](https://www.gnu.org/software/emacs/manual/html_node/elisp/Completion-in-Buffers.html) |
| Minibuffer completion | Use vertical Icomplete with `basic`, `partial-completion`, and `flex` styles, including explicit in-buffer CAPF candidates. | Fast native selection for files, buffers, commands, search history, and sessions without automatic code suggestions. [Icomplete documentation](https://www.gnu.org/software/emacs/manual/html_node/emacs/Icomplete.html) |
| LSP | Use built-in Eglot, started explicitly per project or buffer. | Eglot integrates Xref, Flymake, Eldoc, formatting, and CAPF without a separate LSP framework. [Eglot features](https://www.gnu.org/software/emacs/manual/html_node/eglot/Eglot-Features.html) |
| DAP | Install and configure Dape, but never start it automatically or make it the default debugger. | Emacs has built-in GUD for GDB, LLDB, and PDB. Dape is an explicit, independently configured DAP client for workflows that need adapter-protocol features. [Dape](https://github.com/svaante/dape) |
| Structural Git diffs | Optionally install and enable `difftastic.el` only when the `difft` executable is present, using its supplied Magit bindings. | This adds syntax-aware review inside existing Magit transients without making an external tool a startup requirement or duplicating the integration. |
| Search | Use project.el, ripgrep-backed Xref, Isearch, Occur, Imenu, and native minibuffer completion. | Removes both the Consult and Ivy/Counsel picker stacks. |
| Parsing | Replace legacy Tree-sitter packages with built-in `treesit`. | Emacs 31 owns parser integration. |
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
- `which-key`, `magit`, `doom-themes`, `doom-modeline`, `olivetti`
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
- Dape, Ghostel, `term-sessions.el`, and Difftastic remained unloaded after normal startup. Ghostel's native module remains an explicit first-use installation for Phase 5.
- Startup mean improved from 8.130 s to 3.966 s across the recorded five-run samples.

## Phase 2: Replace automatic completion and picker stacks

Status: pending

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

## Phase 3: Rebuild language services with Emacs primitives

Status: pending

### Changes

1. Activate Eglot configuration for every language server in the language support contract. Retain only server overrides that Emacs cannot infer.
2. Start Eglot explicitly. Do not use `eglot-ensure`.
3. Retain Flymake diagnostics after an Eglot session starts.
4. Map explicit formatting, code actions, rename, hover, signature help, and Xref commands.
5. Set Xref to use `rg` when available.
6. Replace legacy Tree-sitter packages with native grammar configuration and explicit grammar installation for every parser-backed language in the language support contract.
7. Configure Dape without autostart. Document the `dape` launch and attach commands, adapter installation prerequisites, and each configured adapter's local or remote scope beside the configuration. Start with only verified adapters for active workflows, keeping GUD as the default debugger.
8. Retain Python mode's `C-c C-p`, `C-c C-r`, `C-c C-c`, and `C-M-x` commands for the optional native Python Comint route outside Evil visual state. In Evil visual state, deliberately reserve `C-c C-c` for the generalized zmx sender. Configure IPython only through `python-shell-interpreter` and `python-shell-interpreter-args`, and apply `ghostel-comint-mode` only to `inferior-python-mode-hook` when wanted.

### Verification

- An explicitly started Eglot session supplies diagnostics, Xref, Eldoc, and CAPF.
- Formatting and code actions run only from their mappings.
- A language with an installed native grammar uses `treesit` without legacy packages.
- Each Neovim-configured LSP language can start its corresponding Eglot server, and every parser-backed Neovim language has an installed native grammar.
- A local and TRAMP-remote `run-python` session can evaluate a region and buffer with the native Python commands; its output remains in `*Python*`.
- Dape loads and exposes its documented explicit launch and attach commands, while visiting a project or source buffer starts no DAP session.

### Success criteria

- Eglot, Flymake, Xref, and native Tree-sitter are the only language-service layers.
- Language-server executables remain external system prerequisites.

## Phase 4: Rebuild project retrieval and direct mappings

Status: pending

### Changes

1. Define one sparse owned leader map and bind it directly through Evil.
2. Replace Counsel file/buffer/search actions with `project-find-file`, `switch-to-buffer`, `recentf-open-files`, `project-find-regexp`, Occur, Imenu, and Xref.
3. Add direct Eglot, diagnostics, Magit, review, Org, and help mappings under their owned prefixes.
4. Retain Which Key solely for discovering that map.
5. Resolve duplicate and broken mappings, including `SPC w m` and `cousnel-org-tag`.
6. Bind native file, buffer, search, Eglot, diagnostic, terminal, and Gptel commands to their stated ownership prefixes without shadowing Python mode's specialized `C-c` bindings.
7. Bind `my/annotate-region` to visual `SPC r a` and `my/annotate-send-all` to `SPC r s` under the dedicated review prefix; do not add an agent-specific leader map.
8. When `difft` and the explicitly installed `difftastic.el` package are available, configure `difftastic-bindings-alist` with only the supplied Magit diff, blame, and file-dispatch entries, then enable `difftastic-bindings-mode`. Do not add leader bindings or owned wrappers, and do not enable the package's Dired or Forge entries. Leave Magit unchanged when the executable is absent.

### Verification

- Every leader operation has one canonical mapping.
- No `SPC` leader exists in insert or Emacs state.
- Every project search honors the current project root.
- With `difft` available, the Magit diff, blame, and file-dispatch contexts expose the supplied Difftastic actions and produce a structural diff. Without `difft`, those actions are absent and normal Magit diffs still work.

### Success criteria

- No removed picker command is referenced.
- Search, navigation, and history work through native commands and the minibuffer.
- Review annotations have their own `SPC r` prefix, and optional Difftastic support is contained within Magit.

## Phase 5: Replace Vterm with Ghostel and persistent sessions

Status: pending

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

## Phase 6: Final cleanup and acceptance

Status: pending

### Changes

1. Remove dead declarations, commented replacement systems, and all references to removed packages.
2. Audit every retained package for a named workflow and a one-line purpose.
3. Keep personal Org, research, prose, Git, and explicit Gptel workflows unless they are genuinely unused.
4. Validate fresh startup, native completion, Eglot, Dape's dormant explicit configuration, project search, optional Difftastic Magit integration, the project command catalog, Ghostel, Python Comint, generalized REPL dispatch, annotation dispatch, and persistent sessions.

### Acceptance suite

- Batch-load the configuration from a clean Emacs state.
- Search for removed symbols: `straight`, `quelpa`, `whisper`, `vterm`, `corfu`, `cape`, `company`, `consult`, `counsel`, `ivy`, `tree-sitter`, `ts-fold`, `undo-tree`, and `general`.
- Exercise project file finding, `rg` search, Isearch history, explicit CAPF, Eglot navigation, dormant Dape startup, Magit's Difftastic actions when `difft` is installed and ordinary Magit fallback when it is not, the project-local `Compile`, `Test`, `Check`, and `Fix` catalog tasks in separate Ghostel compilation buffers, native Python Comint, selected-region and full-buffer zmx dispatch, queued annotations with an additional prompt sent to a terminal coding agent, optional tmux delivery, and a persistent remote-capable `zmx` session.

### Overall success criteria

- Startup is offline, deterministic, and uses one package manager.
- No automatic code completion package or automatic completion behavior remains.
- Native Emacs primitives own completion, retrieval, projects, LSP integration, diagnostics, and parsing.
- Ghostel replaces Vterm completely.
- Persistent terminals are durable named `zmx` sessions accessed through Ghostel and native Emacs interfaces.
- Python's Comint workflow and the generalized zmx workflow remain intentionally separate, explicit, and functional locally, remotely, and in `emacs -nw`.
- Dape is installed, configured, and documented without becoming an automatic or default debugger.
- `difftastic.el` integrates structural diffs into Magit only on machines that provide `difft`; its absence does not affect startup or normal Magit workflows.
- Annotation collection works from any buffer and reaches any terminal coding agent through the same named-session transport as `SPC t r`.
- Build, test, check, fix, and future project tasks are data in one per-project catalog and execute through the same Ghostel-backed runner.

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
