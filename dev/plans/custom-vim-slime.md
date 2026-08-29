# Custom tmux REPL delivery plan

## Status

- Plan: proposed
- Implementation: not started
- Target: a sufficiently recent Neovim with `vim.system`, current buffer APIs, and current user-command APIs
- Current implementation reference: the `vim-slime` package locked at `profiles/common/.config/nvim/nvim-pack-lock.json:53`
- Primary configuration: `profiles/common/.config/nvim/init.lua`
- Prerequisite plan: `dev/plans/neovim-config-changes.md`, completed through its final acceptance phase
- Existing test fixture from the prerequisite: `dev/tests/neovim/minimal_init.lua`
- New modules:
  - `profiles/common/.config/nvim/lua/transport/tmux.lua`
  - `profiles/common/.config/nvim/lua/repl.lua`
- New tests:
  - `dev/tests/neovim/transport/tmux_test.lua`
  - `dev/tests/neovim/repl_test.lua`
  - `dev/tests/neovim/custom_vim_slime_integration.lua`

## Goal

Replace the installed vim-slime plugin with a small owned Lua implementation for tmux REPL parity. It is source-to-selected-tmux input delivery only, not an Emacs-equivalent terminal-session platform.

The replacement must preserve the established high-frequency workflow before vim-slime is removed:

- Normal `<C-c><C-c>` sends the current paragraph.
- Visual `<C-c><C-c>` sends the exact characterwise, linewise, or blockwise selection.
- Normal `<C-c>v` configures the tmux target.
- Python multiline input uses the configured IPython `%cpaste` transaction.
- Compatibility commands `SlimeSend`, `SlimeSend0`, `SlimeSend1`, `SlimeSendCurrentLine`, and `SlimeConfig` remain usable after cutover.

The implementation must follow the infrastructure order in `refs/editor-philosophy.md:1`: use Neovim APIs for extraction and state, `vim.system` for subprocesses, and tmux as the external delivery mechanism. It must not reproduce vim-slime backends or language integrations that this configuration does not use.

## Prerequisite and one-way dependency

Complete every phase and success criterion in `dev/plans/neovim-config-changes.md` before starting this plan. That refactor is independently complete, retains vim-slime unchanged, and requires no code or decision from this plan.

This plan is a downstream follow-up. It creates the owned tmux transport and `repl.lua`, proves parity beside the still-installed vim-slime plugin, cuts over the mappings and compatibility commands, and finally removes vim-slime.

No phase in this plan is a prerequisite for, or part of the acceptance criteria of, `dev/plans/neovim-config-changes.md`.

## Audited current behavior

The compatibility contract is based on the locked vim-slime revision and the active configuration. Phase 1 must obtain that exact revision from the lockfile before it records fixtures.

### Commands and mappings

The locked vim-slime revision defines:

- `:SlimeConfig`: configure the target for the current buffer.
- `:[range]SlimeSend`: send complete lines in the Ex range.
- `:SlimeSend1 {text}`: send command arguments followed by a carriage return.
- `:SlimeSend0 {text}`: send command arguments without adding a carriage return.
- `:SlimeSendCurrentLine`: send the current line followed by a carriage return.

Its default mappings install:

- Normal `<C-c><C-c>` through the `ip` paragraph text object.
- Visual `<C-c><C-c>` for the current visual selection.
- Normal `<C-c>v` for target configuration.

The current configuration has no `SlimeSend1` caller. Preserve the compatibility command for manual and external callers after cutover.

### Extraction and editor state

The locked vim-slime revision handles characterwise, linewise, and blockwise operator regions. It temporarily uses the unnamed register, restores the register value and type, and restores the window view for operator-driven sends.

The owned implementation must produce the same sent text without mutating registers. Use current buffer and region APIs, normalize reversed visual selections, respect inclusive and exclusive endpoints, and preserve cursor position and window view.

Blockwise extraction is display-column based, not byte-column based. Tabs, combining characters, and multibyte characters make a rectangular `nvim_buf_get_text` call incorrect. Treat blockwise extraction as a separately tested behavior.

### Target configuration

The active configuration at `profiles/common/.config/nvim/init.lua` uses:

- Backend: tmux only.
- Socket name: `default`.
- Target pane: `{last}`.
- Configuration scope: a buffer-local target copied from defaults and editable through `<C-c>v`.

The locked vim-slime tmux target accepts either a named socket or an absolute socket path. A named socket maps to `tmux -L`; an absolute path maps to `tmux -S`. Preserve both forms.

### Python and IPython

The active configuration at `profiles/common/.config/nvim/init.lua` enables IPython handling and sets the dispatch pause to 350 milliseconds.

The locked vim-slime Python integration transforms input as follows:

- Multiline input with IPython enabled becomes a four-step transaction: `%cpaste -q\n`, a pause, the source body, and `--\n`.
- Other Python input removes redundant empty lines, dedents by the leading indentation, and inserts suite-terminating blank lines where required, excluding `elif`, `else`, `except`, and `finally` continuations.

Preserve this observable behavior. Test transformation independently from tmux, and serialize the whole IPython sequence so no other REPL send can interleave during the 350 millisecond pause.

### Existing tmux transport

The locked vim-slime tmux target cancels tmux copy mode, loads text through stdin, pastes it into the target, and handles a trailing newline. It chunks text at 1000 characters and uses tmux's unnamed paste buffer.

The owned implementation does not preserve those internal choices. It must preserve delivered text while improving isolation and failure handling:

- Use a unique named tmux buffer per paste.
- Load each paste body in one operation rather than 1000-character chunks.
- Resolve and validate the pane once per logical transaction.
- Report subprocess failures and stderr.
- Delete owned buffers after every paste attempt.
- Serialize transactions per resolved target.

## Recommended architecture

### `profiles/common/.config/nvim/lua/transport/tmux.lua`

Own all tmux process and delivery state:

- Socket argument construction for named and absolute sockets.
- Target resolution to a concrete pane id.
- Collision-resistant named tmux buffers.
- `vim.system` execution with argument lists and stdin.
- Paste sequencing and explicit submit keys.
- Per-target transaction queues.
- Buffer cleanup and concise error reporting.
- A narrow transaction API used by `repl.lua`.

Represent each delivery as an ordered transaction containing paste, nonblocking delay, and narrowly defined key steps. Resolve the target before queueing under the normalized socket plus concrete pane id. Process one transaction at a time for each target while allowing unrelated panes to progress independently.

The transport must not know about Python, paragraphs, filetypes, or buffer state. `repl.lua` owns those semantics and passes target and step data into the transport.

A suitable API shape is:

```lua
transport.enqueue(target, steps, callback)
```

Each target contains `socket_name` and `target_pane`. Each step is one of:

- `{ kind = "paste", text = value }`
- `{ kind = "delay", milliseconds = value }`
- `{ kind = "key", key = "Enter" }`

Only a small allowlist of mechanical keys is valid. Arbitrary content must always use paste steps.

### `profiles/common/.config/nvim/lua/repl.lua`

Own REPL semantics:

- Setup defaults and buffer-local target state.
- Target configuration UI.
- Paragraph, visual, range, current-line, counted-line, motion, and literal-text extraction.
- Filetype-specific transformation.
- Python and IPython transaction construction.
- Temporary parity commands and mappings.
- Final compatibility commands and canonical mappings.
- User-facing notifications.

Keep extraction and transformation as pure functions where practical so they can be tested without tmux.

## Mapping contract

The final owned implementation uses a canonical REPL namespace plus the established high-frequency aliases:

| Mapping | Operation |
| --- | --- |
| `<leader>tr` | Send the whole buffer in normal mode or the exact selection in visual mode. This is the portable source-to-REPL action. |
| `<leader>rs` | Send paragraph in normal mode or selection in visual mode |
| `<leader>rl` | Send current line or count of lines |
| `<leader>rm` | Start the send operator for a motion or text object |
| `<leader>rf` | Send the whole file |
| `<leader>rc` | Configure the current buffer's tmux target |
| `<C-c><C-c>` | High-frequency alias for paragraph or visual selection send |
| `<C-c>v` | High-frequency alias for target configuration |

All mappings use `vim.keymap.set` with descriptions. `<leader>tr` is a direct action, not a prefix. The `<leader>r` namespace remains after migration for Neovim-specific granular REPL operations; it is not temporary compatibility scaffolding.

## Non-goals

Do not reproduce:

- screen, Neovim terminal, Kitty, WezTerm, Zellij, dtach, X11, ConEmu, or other vim-slime targets.
- vim-slime's CoffeeScript, Elm, F#, Haskell, MATLAB, OCaml, Scala, shell, SML, or Stata transformations.
- vim-slime override hooks, paste-file mode, debug compatibility variables, or third-party `<Plug>` compatibility.
- automatic terminal creation or REPL process management.
- a generic backend or asynchronous job framework.
- named `zmx` session lifecycle, discovery, history, attachment, or persistence.
- remote session routing, terminal rendering, output parsing, or compilation.
- source annotations, annotation queues, coding-agent prompts, or agent-specific transport.
- Emacs Python Comint process management, completion, documentation, or output buffers.

If a shared named-session or annotation workflow is needed later, plan it as a separate subsystem with its own target and lifetime contract. Do not extend `transport.tmux` or `repl.lua` beyond tmux REPL delivery.

Do not add cell-delimiter support in the initial implementation because the active configuration has no cell mapping or delimiter. Add it later only for a named current workflow.

## Phase 1: Freeze the observable compatibility contract

Status: not started

### Changes

1. Keep `jpalardy/vim-slime` installed and retain the settings in `profiles/common/.config/nvim/init.lua`.
2. Obtain the exact `vim-slime` source revision recorded in `profiles/common/.config/nvim/nvim-pack-lock.json:53` and use it as the fixture baseline.
3. Add headless extraction fixtures for:
   - Forward and reversed characterwise selections.
   - Inclusive and exclusive characterwise selection.
   - Linewise selection.
   - Blockwise selection across short and long lines.
   - Tabs, combining characters, and multibyte characters in every applicable visual mode.
   - Paragraph selection at the start, middle, and end of a buffer.
   - Ex ranges, counted lines, and operator motions.
4. Record expected newline behavior for all five compatibility commands.
5. Add Python fixtures for a single statement, nested suites, blank lines, decorators, and `elif`, `else`, `except`, and `finally` continuations.
6. Add an integration fixture that captures text sent by the existing vim-slime implementation into a temporary tmux pane. Use the captured bytes as the behavioral baseline where the plugin behavior is intentional.
7. Verify that sends preserve the unnamed register, its register type, cursor position, and window view.
8. Record intentional differences from vim-slime before replacement code is written:
   - Named buffers replace the global unnamed tmux buffer.
   - Whole-payload paste replaces 1000-character chunks.
   - Errors become visible instead of being discarded.
   - Unsupported targets and transformations are omitted.

### Verification

- Run the fixture against the vim-slime package revision recorded in the lockfile.
- Confirm the fixture covers every current mapping, command, configuration value, and Python branch.
- Confirm every intentional difference is internal or improves failure behavior without changing successfully delivered text.

### Success criteria

- Required behavior is executable and recorded before implementation.
- Compatibility is defined by current use, not by vim-slime's complete feature set.
- No existing mapping or command has been replaced.

## Phase 2: Build the owned tmux transport

Status: not started

### Changes

1. Implement `profiles/common/.config/nvim/lua/transport/tmux.lua`, loaded as `require('transport.tmux')`, with one public `enqueue(target, steps, callback)` operation.
2. Accept named sockets as `tmux -L <name>` and absolute socket paths as `tmux -S <path>`.
3. Resolve target expressions such as `{last}` once per transaction with `tmux ... display-message -p -t <target> '#{pane_id}'`. Reject an empty pane id or subprocess failure before running any delivery step.
4. Support three validated step types:
   - `{ kind = 'paste', text = value }`
   - `{ kind = 'delay', milliseconds = value }`
   - `{ kind = 'key', key = 'Enter' }`
5. Generate collision-resistant named buffers from the Neovim process id and a monotonic counter. For every paste, reject NUL bytes, load the entire payload through stdin, paste only after a successful load, and delete the owned buffer after the paste attempt.
6. Implement delays with Neovim scheduling rather than `sleep` or a blocking wait, and retain the per-target queue for the delay's full duration.
7. Serialize complete transactions by normalized socket and resolved pane id. Allow transactions for different panes to progress independently.
8. On a failed step, stop the transaction, release the queue, report one concise stage-specific error, and allow the next transaction to run.
9. Never interpolate payload text into a command, invoke a shell, use arbitrary multiline `send-keys`, or leave an owned buffer behind after a paste attempt. Allow only the mechanical `Enter` key.
10. Keep process execution directly visible in this module. Allow tests to replace the narrow execution function and scheduler without introducing a general dependency injection framework.

### Verification

- Run transport tests in a temporary tmux socket and session that cannot affect the user's normal server.
- Verify a transaction containing paste, delay, paste, and `Enter` retains the target queue for its full duration without blocking a different pane.
- Submit interleaved multi-step transactions to the same pane and verify transaction steps remain contiguous.
- Submit transactions to different panes and verify they do not block one another.
- Force target-resolution, load, paste, delay, key, and cleanup failures and verify the reported stage and queue recovery.
- List tmux buffers after success and failure and confirm no owned payload remains.

### Success criteria

- Payload bytes reach the resolved pane without shell interpretation.
- A transaction cannot interleave with another transaction targeting the same pane.
- Concurrent Neovim processes cannot overwrite each other's tmux buffers.
- Missing tmux sessions, invalid targets, and subprocess failures are visible.
- No REPL delivery bypasses the owned transport.

## Phase 3: Implement extraction, commands, and parity mappings

Status: not started

### Changes

1. Implement `profiles/common/.config/nvim/lua/repl.lua` with defaults for socket `default`, target `{last}`, IPython enabled, and a 350 millisecond pause.
2. Store configured targets buffer-locally. Copy setup defaults on first use and allow `<leader>rc` to edit the current buffer's socket and target.
3. List panes through structured `tmux list-panes` arguments and present them through `vim.ui.select`. Keep direct text entry for a valid target expression or absolute socket path.
4. Extract text directly with Neovim region and buffer APIs:
   - Characterwise selection includes the intended endpoint and supports multibyte text.
   - Linewise selection includes complete lines and a trailing newline.
   - Blockwise selection follows display columns when tabs or multibyte characters occur.
   - Paragraph send matches the `ip` text object's region.
   - Motion sends use `operatorfunc` and the native operator marks.
5. Preserve cursor position, window view, unnamed register value, and unnamed register type across all sends.
6. Add temporary commands with non-conflicting names:
   - `:[range]ReplSend`
   - `:ReplSend1`
   - `:ReplSend0`
   - `:ReplSendCurrentLine`
   - `:ReplConfig`
7. Add the canonical `<leader>r` mappings while vim-slime's `<C-c><C-c>`, `<C-c>v`, `<leader>tr`, and `Slime*` commands remain unchanged. Keep `<leader>tr` mapped to vim-slime until Phase 5.
8. Submit all transformed text through `require('transport.tmux')`.

### Verification

- Compare owned and vim-slime output for every Phase 1 fixture.
- Verify visual selections in all three visual modes.
- Verify paths, socket names, and pane targets are passed as arguments rather than shell text.
- Verify target state is independent between two source buffers.
- Verify the old and new implementations can target the same pane without sharing tmux buffers or corrupting state.

### Success criteria

- The owned implementation is usable under the canonical `<leader>r` mappings.
- Existing vim-slime remains the rollback path.
- Text extraction does not mutate registers or editor view.
- No REPL delivery bypasses the owned transport.

## Phase 4: Implement Python and serialized IPython delivery

Status: not started

### Changes

1. Port the required Python transformation from the locked vim-slime revision into pure Lua transformation functions in `repl.lua`.
2. For multiline Python with IPython enabled, submit one transport transaction containing:
   - Paste `%cpaste -q\n`.
   - Wait 350 milliseconds.
   - Paste the original source body.
   - Paste `--\n`.
3. Keep the whole transaction in the per-target queue until the terminator completes.
4. Queue sends made during the pause. Never start a second REPL send in the middle of the IPython transaction.
5. On failure, stop the remaining steps, report the failed stage, finalize cleanup, and continue later queued transactions without leaving the queue stalled.
6. Keep the 350 millisecond value configurable in `repl.setup`, with the active behavior as the default.

### Verification

- Compare pure Python transformation output with the Phase 1 fixtures.
- Use a fake transport executor or recorded step runner to verify exact step order and delay without wall-clock-dependent unit tests.
- Use a real IPython process in a temporary tmux pane for an end-to-end multiline function, class, conditional, loop, and exception block.
- Trigger another REPL send during the pause and verify it cannot interleave.
- Force failure at each transaction step and verify later steps do not run.

### Success criteria

- Current Python single-line and multiline behavior is preserved.
- IPython transactions are ordered, nonblocking, and non-interleaving.
- Failure cannot leave the queue permanently stalled.

## Phase 5: Cut over after the parity gate

Status: not started

### Changes

1. Require the Phase 1 through Phase 4 automated suite and manual workflow comparison to pass before changing high-frequency mappings.
2. Disable vim-slime's default mappings while it remains installed for one transition step.
3. Bind:
   - Normal `<C-c><C-c>` to owned paragraph send.
   - Visual `<C-c><C-c>` to owned visual send.
   - Normal `<C-c>v` to owned target configuration.
4. Rebind normal `<leader>tr` to the owned full-buffer sender and visual `<leader>tr` to the owned visual sender.
5. Replace temporary command names with compatibility commands:
   - `:[range]SlimeSend`
   - `:SlimeSend1`
   - `:SlimeSend0`
   - `:SlimeSendCurrentLine`
   - `:SlimeConfig`
6. Keep compatibility commands for manual and external callers.
7. Run the complete parity suite with vim-slime still available as an immediate rollback.
8. Remove `jpalardy/vim-slime` from the `vim.pack` package list only after the owned mappings and commands pass the parity gate.
9. Remove `g:slime_target`, `g:slime_default_config`, `g:slime_python_ipython`, and `g:slime_dispatch_ipython_pause` after their owned Lua equivalents are active.
10. Remove temporary `Repl*` commands. Keep the canonical `<leader>r` mappings, `<leader>tr`, and high-frequency aliases.

### Verification

- Start from an empty temporary package state without vim-slime.
- Confirm all canonical mappings and compatibility commands exist and call only owned Lua.
- Search the active configuration for `vim-slime`, `slime#`, `g:slime_`, `<Plug>Slime`, and undeclared `Slime*` command strings.
- Repeat the manual REPL workflow for plain text, Python, IPython, LLDB if retained, and target reconfiguration.

### Success criteria

- vim-slime is removed only after demonstrated parity.
- High-frequency mappings retain their behavior.
- Required `Slime*` command callers continue to work.
- No temporary coexistence command or plugin-specific configuration remains.

## Phase 6: Final cleanup and acceptance

Status: not started

### Changes

1. Search for and remove any direct tmux subprocess path outside `transport/tmux.lua` or any second delivery queue.
2. Document tmux as an external prerequisite and document the default REPL socket and target.
3. Keep direct code for one-off REPL operations. Add helpers only for behavior used more than three times or for meaningful transport state.
4. Normalize new Lua and test files to spaces and LF line endings.

### Acceptance suite

- Parse and format the new Lua modules.
- Start Neovim headlessly twice from a clean temporary package state.
- Run all pure extraction and Python transformation tests.
- Run all tmux transport integration tests.
- Exercise normal paragraph, all visual modes, Ex range, literal text, current line, operator motion, target configuration, Python, and IPython.
- Verify register, cursor, and window-view preservation.
- Force missing tmux, missing session, invalid socket, invalid pane, load failure, paste failure, and cleanup failure paths.
- Confirm no owned tmux buffers remain after tests.
- Confirm vim-slime is absent from the package list and active runtime path.
- Confirm the prerequisite Neovim refactor still satisfies all of its independent success criteria.

### Overall success criteria

- The configuration owns only the tmux REPL behavior it uses.
- Normal `<C-c><C-c>`, visual `<C-c><C-c>`, and `<C-c>v` preserve the established workflow.
- The canonical `<leader>r` family exposes the described Neovim-specific operations, and `<leader>tr` remains the portable full-buffer or visual-selection sender.
- Required `Slime*` commands remain compatible.
- Python and IPython delivery preserve current transformations and timing.
- Every REPL send uses one safe, serialized tmux transport.
- Payloads are never interpreted by a shell or sent as arbitrary multiline `send-keys` input.
- vim-slime remains installed until parity is demonstrated, then is removed cleanly.
- No unsupported backend, unused filetype integration, or parallel tmux transport is introduced.

## References

### Codebase

- Editor philosophy and infrastructure preference: `refs/editor-philosophy.md:1`
- Tmux transport guidance: `refs/editor-philosophy.md:524`
- Current vim-slime package declaration and settings: `profiles/common/.config/nvim/init.lua:137` and `:219`
- Locked vim-slime source revision: `profiles/common/.config/nvim/nvim-pack-lock.json:53`
- vim-slime commands and mappings: https://github.com/jpalardy/vim-slime/blob/305b4d81ff4630af5137fdeffb54aa0fef14761b/plugin/slime.vim
- vim-slime extraction and dispatch: https://github.com/jpalardy/vim-slime/blob/305b4d81ff4630af5137fdeffb54aa0fef14761b/autoload/slime.vim
- vim-slime tmux delivery: https://github.com/jpalardy/vim-slime/blob/305b4d81ff4630af5137fdeffb54aa0fef14761b/autoload/slime/targets/tmux.vim
- vim-slime Python and IPython transformation: https://github.com/jpalardy/vim-slime/blob/305b4d81ff4630af5137fdeffb54aa0fef14761b/ftplugin/python/slime.vim
- vim-slime configuration precedence: https://github.com/jpalardy/vim-slime/blob/305b4d81ff4630af5137fdeffb54aa0fef14761b/autoload/slime/config.vim
- vim-slime bracketed-paste behavior: https://github.com/jpalardy/vim-slime/blob/305b4d81ff4630af5137fdeffb54aa0fef14761b/autoload/slime/common.vim
- Main Neovim alignment plan: `dev/plans/neovim-config-changes.md`

### Neovim and tmux documentation

- Neovim system calls: https://neovim.io/doc/user/lua.html#vim.system()
- Neovim buffer APIs: https://neovim.io/doc/user/api.html#api-buffer
- Neovim user commands: https://neovim.io/doc/user/api.html#nvim_create_user_command()
- tmux manual: https://man.openbsd.org/tmux
