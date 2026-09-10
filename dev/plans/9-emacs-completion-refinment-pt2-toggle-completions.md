# Emacs Completion Refinement Part 2: Toggleable Completion Stacks

## Final Completion Stacks

The finished common Emacs profile provides two complete, runtime-selectable
completion stacks behind stable profile-owned commands. The native stack is the
startup default. The active stack can be changed without restarting Emacs when
no minibuffer, completion-at-point session, or Transient is active.

This plan is self-contained. It does not require implementation of another plan
first.

```text
Stable user bindings
  -> profile-owned command facades
  -> dispatch on my/completion-stack

Shared in-buffer completion
  -> Eglot, file, Dabbrev, Ispell, or major-mode CAPF
  -> built-in completion-in-region
  -> native *Completions*
  -> native candidate acceptance

Stack A: native-consult
  ordinary minibuffer prompts
    -> built-in completing-read or read-file-name
    -> native *Completions*

  search and navigation
    -> Consult
    -> built-in completing-read
    -> native *Completions*
    -> preview, Embark actions, Collect, or Export

  recursive local files
    -> consult-fd
    -> streamed fd output
    -> native *Completions*

Stack B: ivy-counsel
  ordinary minibuffer prompts
    -> Ivy

  selected search and navigation
    -> Ivy, Counsel, or Swiper

  project content search
    -> repository-owned dynamic Ivy reader
    -> streamed rg JSON process output

  recursive local files
    -> fd file enumeration
    -> fzf matching and global ranking
    -> repository-owned Ivy file reader

  Xref, diagnostics, call hierarchies, and remote fallback
    -> explicit native result or completion surfaces
```

The stack toggle never changes the CAPF sources, completion tables, Eglot
server requests, completion category metadata, or native completion acceptance.
Every CAPF remains source-buffer-backed so Eglot can refine incomplete results
and apply snippets, `textEdit`, `additionalTextEdits`, and exit functions
correctly.

The two stacks deliberately expose different recursive-file tradeoffs:

- `native-consult` favors incremental results. `consult-fd` displays paths
  while `fd` is still producing them, but it does not provide globally sorted
  fzf subsequence ranking.
- `ivy-counsel` favors actual fzf ranking. A repository-owned Ivy reader starts
  `fd` and fzf with argv-based process APIs, but sorted filter output does not
  publish the final global order until the producer reaches end of file.

Layer ownership is explicit:

| Layer | `native-consult` | `ivy-counsel` | Contract |
| --- | --- | --- | --- |
| CAPF candidate production | Eglot, file CAPF, Dabbrev, Ispell, major modes | Same | Candidate sources never change with the stack. |
| Completion-in-region engine | Built-in Emacs | Built-in Emacs | Ivy never installs completion-in-region. |
| CAPF frontend | Native `*Completions*` | Native `*Completions*` | Input remains in the source buffer. |
| Ordinary minibuffer frontend | Native `*Completions*` | Ivy | This is the primary toggled frontend layer. |
| Search implementations | Consult | Selected Ivy, Counsel, and Swiper commands | Stable facades select the implementation. |
| Recursive local files | `consult-fd` | Safe repository-owned Ivy reader over `fd` and fzf processes | Streaming and exact fzf ranking remain distinct choices. |
| Hierarchical files | `read-file-name`, native frontend | `read-file-name`, Ivy frontend | `C-x C-f` remains local/TRAMP-aware and create-capable. |
| Xref | Consult presentation | Native Xref result buffers | Consult is not run through Ivy. |
| Diagnostics and call hierarchies | Native buffers | Native buffers | Existing domain-specific persistent views remain unchanged. |
| Persistent completion results | Embark Collect and Export | Ivy Occur and command-specific Counsel Occur | Each frontend owns its candidate snapshot. |
| Reusable settings | Transient | The same profile-owned Transients | Settings express intent and each backend translates it. |

Do not enable `counsel-mode`. It broadly remaps commands outside the selected
surface. Enable only `ivy-mode`, keep Ivy away from completion-in-region, and
bind selected Counsel and Swiper commands through profile-owned facades.

Consult documents Ivy as an unsupported completion UI. No Consult command may
enter its candidate-selection prompt while `completing-read-function` is
`ivy-completing-read`. Commands that must retain Consult in the Ivy stack use a
narrow, explicit native adapter that
dynamically binds `ivy-mode` to nil and `completing-read-function` to
`completing-read-default` around the entire Consult call. This suppresses
Ivy's minor-mode keymap and reader without calling the global mode setter. The
adapter must not expose a Consult prompt to `ivy-completing-read` or mutate the
selected stack.

### Shared in-buffer completion

`C-SPC` starts native completion-at-point in both stacks. The existing native
`*Completions*` display and key contract remains active:

- `TAB` and `C-n` select the next candidate.
- `S-TAB`, `<backtab>`, and `C-p` select the previous candidate.
- `RET` retains the source mode's normal behavior unless native completion owns
  a selected candidate.
- `M-RET` explicitly accepts the selected candidate where configured.
- `M-g M-c` focuses the associated `*Completions*` window.
- `C-q` creates an Embark Collect snapshot.
- `C-g` cancels without transferring editable input to a minibuffer.

`M-/` remains direct `dabbrev-expand`. `C-M-/` remains
`dabbrev-completion` through native completion-in-region.

Set `ivy-do-completion-in-region` to nil before Ivy is first enabled. Record
the native value of `completion-in-region-function` during initialization and
assert after every transition that Ivy has not replaced it.

### Ordinary minibuffer completion

In `native-consult`, ordinary `completing-read`, project, command, buffer, and
file prompts use native `*Completions*`.

- Editable input remains in the minibuffer.
- `C-n` and `C-p` move the candidate selection without replacing input.
- `TAB` retains native prefix completion and directory descent.
- `RET` accepts according to the prompt's require-match contract.
- `S-RET` uses the public, validated `minibuffer-complete-and-exit` path. It must
  not bypass require-match validation with `exit-minibuffer`.
- `C-q` invokes the native Embark collector.

In `ivy-counsel`, ordinary `completing-read` and `read-file-name` prompts use
Ivy. Ivy owns selection, filtering, its minibuffer keymap, and literal-input
semantics. `C-q` invokes `ivy-occur`, and Ivy's normal action dispatcher remains
available. Embark remains loaded for at-point actions and native CAPF, but does
not replace Ivy's ordinary minibuffer action model.

### `C-x C-f`

`C-x C-f` and `SPC f h` remain bound to `my/find-file`, which continues to call
`read-file-name` rather than `counsel-find-file`.

- `native-consult` shows each directory level in native `*Completions*`.
- `ivy-counsel` shows the same `read-file-name` table in Ivy.
- Both stacks support local paths, TRAMP paths, directory descent, and literal
  file creation.
- Literal submission must follow the active frontend's documented semantics
  and the underlying require-match contract.
- `C-c C-r` continues to switch between hierarchical and recursive discovery,
  but the implementation must not suspend and refresh an outer frontend using
  assumptions specific to native `*Completions*`.

### File-picker controller

Replace the current nested-minibuffer refresh design with a frontend-neutral
controller. One controller owns the file visit, transaction, cancellation, and
Evil jump. Each frontend adapter performs one prompt and returns one of:

```text
selected path
toggle to hierarchical
toggle to recursive
cancel
```

`C-c C-r` records a toggle result and exits the current prompt. The controller
then starts the other prompt. It does not keep a native or Ivy minibuffer
suspended, call `minibuffer-completion-help` against Ivy, or mutate an active
frontend beneath its event loop.

For a local recursive root, the controller dispatches to `consult-fd` or
the repository-owned Ivy fzf reader. The Ivy adapter must not reuse
`counsel-fzf-cmd`: upstream `counsel-fzf` interpolates raw Ivy input into a
shell command string, which cannot preserve arbitrary quotes and shell
metacharacters safely.

Implement the local Ivy fzf path with this explicit process boundary:

1. Start `fd` with `make-process` and a list-valued `:command` containing one
   validated argument per element. Request NUL-delimited output.
2. Start fzf separately with a list-valued command, enable NUL-delimited input
   and output, and pass the editable query as the value of an fzf `--filter`
   argument, never as shell text.
3. Forward `fd` output to the fzf process through process filters and close
   fzf input when `fd` exits. Parse completed NUL-delimited records while
   retaining an incomplete trailing record between chunks. Do not construct a
   shell pipeline.
4. On each Ivy input change, cancel both processes from the prior generation
   before starting the next pair.
5. Tag every pair with a generation value so a stale filter or sentinel cannot
   publish candidates into a newer query.
6. Publish completed fzf output through the public `ivy-update-candidates`
   entry point used by a public `ivy-read` dynamic collection.
7. Own cleanup with `unwind-protect`; success, quit, error, and replacement all
   close both processes and their temporary buffers.
8. Store the latest root and candidates in repository-owned session state so
   C-q can produce a Dired result without reading private Ivy variables or
   rerunning an unsafe shell command.

This path retains actual fzf filtering and ranking while accepting that sorted
results arrive only after `fd` has finished and fzf has emitted its final list.

For a remote root:

- `native-consult` uses remote `consult-fd` when remote `fd` exists and the
  portable `consult-find` fallback otherwise.
- `ivy-counsel` exits the Ivy prompt and runs the same remote route through the
  native completion adapter for the complete Consult call.
- No local `fd`, `fzf`, or `rg` process receives a TRAMP path.
- Portable remote `find` is explicitly case-insensitive only and has no VCS
  ignore-file semantics. Smart or sensitive saved case must produce a clear
  user error before that fallback starts.

## Runtime Stack Contract

Add `profiles/common/.config/emacs/my-completion-stack.el` with these public
symbols:

- `my/completion-stack-default`, whose value is `native-consult`;
- `my/completion-stack`, the applied runtime state, which is nil only during
  startup and otherwise is `native-consult` or `ivy-counsel`;
- `my/completion-stack-saved`, the Savehist-restored preference;
- `my/set-completion-stack`;
- `my/toggle-completion-stack`;
- `my/completion-stack-menu`;
- stable facade commands for every stack-dependent binding.

Add only `my/completion-stack-saved` to `savehist-additional-variables`. Leave
the applied `my/completion-stack` nil until startup validates the restored
preference and calls the setter. An absent or invalid saved value becomes
`my/completion-stack-default`. The setter updates both variables only after
frontend and Xref activation succeeds, so restored preference can never make
an unapplied stack look active.

Recommended stack controls:

| Binding | Behavior |
| --- | --- |
| `SPC s v` | Toggle immediately between stacks. |
| `SPC s V` | Open the completion-stack Transient. |
| Menu `n` | Select `native-consult` and exit. |
| Menu `i` | Select `ivy-counsel` and exit. |
| Menu `t` | Toggle and exit. |
| `C-g` | Exit without changing the active stack. |

The setter is the sole owner of frontend state and must be idempotent:

1. Reject a transition while a minibuffer, completion-in-region session, or
   Transient is active. Do not abort user input automatically.
2. Treat selecting the already-applied `my/completion-stack` as a no-op.
3. Before entering `ivy-counsel`, load Ivy, set
   `ivy-do-completion-in-region` to nil, verify the native
   `completion-in-region-function`, and enable `ivy-mode`.
4. Do not enable `counsel-mode`.
5. Before entering `native-consult`, disable `ivy-mode` and verify that
   `completing-read-function` is the captured native reader.
6. Restore the stack-specific Xref presenters and update the applied and saved
   stack variables only after all transition steps succeed.
7. If activation fails, restore the previous frontend, Xref presenters,
   applied state, and saved preference, then signal the original error.
8. Do not unload package features or delete result buffers. Loading a package
   is permanent for the Emacs process; activation is not.
9. Switching stacks starts no subprocess, performs no package refresh, and
   contacts no remote host.
10. A second `init.el` load and `my/soft-reload` must not duplicate hooks,
    collectors, advice, keymap composition, or Transient definitions.

Existing `*Completions*`, Ivy Occur, Embark Collect, Dired, Ibuffer, Occur,
Grep, Xref, Flymake, and call-hierarchy buffers remain usable after a toggle.
They are persistent result buffers, not active frontend state.

Do not scan `process-list` and kill processes during an ordinary transition.
The active-session guard means Consult, Ivy, Counsel, and Swiper prompts have
already run their own unwind cleanup before the toggle can execute.

## Stable Command Facades

Bindings must target profile-owned commands rather than direct package
commands. The facades select a command implementation; `ivy-mode` separately
selects the frontend for ordinary Emacs completion calls.

Remove the unconditional Consult `switch-to-buffer` remap. A stable buffer
facade must own `C-x b`, `SPC ,`, and `SPC b b`, so package minor-mode remaps do
not bypass the selected stack.

Replace `consult--source-buffer` with a repository-owned source using
Consult's documented source-plist contract and public `buffer-list` and
`buffer-name` data. The native all-buffer scope remains live-buffer-only
without retaining a private Consult source symbol.

| Facade | `native-consult` | `ivy-counsel` |
| --- | --- | --- |
| `my/select-buffer` | `consult-buffer` | `ivy-switch-buffer` |
| `my/select-command` | `execute-extended-command` | `counsel-M-x` |
| `my/search-incremental` | `isearch-forward` | `swiper-isearch` |
| `my/search-line` | `consult-line` | `swiper-isearch` |
| `my/search-lines` | `consult-line-multi` | `swiper-all` for all-open scope; `consult-line-multi` through the native adapter for project scope |
| `my/search-ripgrep` | `consult-ripgrep` | Safe repository-owned Ivy rg reader |
| `my/search-ripgrep-region-or-symbol` | Seeded `consult-ripgrep` | Seeded safe Ivy rg reader |
| `my/select-kill-ring` | `consult-yank-from-kill-ring` | `counsel-yank-pop` |
| `my/select-imenu` | `consult-imenu` | `counsel-imenu` |
| `my/select-recent-file` | `consult-recent-file` | `counsel-recentf` |
| `my/select-isearch-history` | `consult-isearch-history` | The same command through the native completion adapter |
| `my/find-file-recursive-configured` | Local or remote Consult route | Local Ivy fzf reader or explicit native remote route |

Use one shared dispatch function only where it materially reduces repeated
stack selection across more than three facades. Keep domain-specific argument
preparation, preview restoration, and result handling in each facade rather
than building a generic framework.

## Complete Command and Search Matrix

### Completion, files, and buffers

| Binding | Domain | `native-consult` | `ivy-counsel` | Persistent surface |
| --- | --- | --- | --- | --- |
| `C-SPC` | Eglot, file, Ispell, and major-mode CAPFs | Native completion-in-region | Same | Native acceptance; C-q Embark Collect |
| `M-/` | Dabbrev expansion | `dabbrev-expand` | Same | None |
| `C-M-/` | Dabbrev completion | Native completion-in-region | Same | C-q Embark Collect |
| `C-x C-f`, `SPC f h` | Hierarchical local/TRAMP open or create | `my/find-file`, native frontend | `my/find-file`, Ivy frontend | Native Collect or Ivy Occur |
| `C-p`, `SPC f p` | Configured recursive project/default-root files | Streaming `consult-fd` | Local safe Ivy fzf reader; remote native Consult adapter | Dired Export or repository-owned fzf Dired result |
| `M-p`, `SPC f P` | Recursive file options | Shared Transient | Same | Runs the selected facade on action |
| `SPC f f` | Project files | project.el, native frontend | project.el, Ivy frontend | Frontend-specific persistence |
| `SPC f F` | Fixed recursive all-files universe | Consult route | Local safe Ivy fzf reader; remote native Consult adapter | Frontend-specific persistence |
| `SPC f D` | Recursive current-file directory | Consult route | Local safe Ivy fzf reader; remote native Consult adapter | Frontend-specific persistence |
| `SPC f R` | Hierarchical `/sshx:` entry | Native file completion | Ivy file completion | Frontend-specific persistence |
| `SPC f o` | Recent files | `consult-recent-file` | `counsel-recentf` | Embark Export or Ivy Occur |
| `C-x b`, `SPC ,`, `SPC b b` | Buffer selection | `consult-buffer` | `ivy-switch-buffer` | Ibuffer Export or Ivy Occur |
| `SPC b B` | Buffer options | Shared Transient | Same | Runs `my/select-buffer` |

### Text search and selection

| Binding | Domain | `native-consult` | `ivy-counsel` | Persistent surface |
| --- | --- | --- | --- | --- |
| `C-s` | Incremental current-buffer search | Native Isearch | `swiper-isearch` | Isearch state or Swiper Occur |
| Evil `/`, `?`, `*`, `#`, `n`, `N` | Evil search and repeat | Evil | Evil | Evil search history |
| `SPC /`, `SPC s l` | Current-buffer line search | `consult-line` | `swiper-isearch` | Occur Export or Swiper Occur |
| `SPC s L` | Current-buffer line options | Shared Transient | Same | Runs `my/search-line` |
| `SPC s b` | Multi-buffer line search | `consult-line-multi` | `swiper-all` for all-open; native Consult adapter for project scope | Embark Occur/Export or Swiper Occur |
| `SPC s B` | Multi-buffer line options | Shared Transient | Same | Runs `my/search-lines` |
| `SPC s g` | Project/default-root content search | `consult-ripgrep` | Safe Ivy rg reader | Grep Export or repository-owned Grep result |
| `SPC s G` | Ripgrep options | Shared Transient | Same | Explicit unseeded action |
| `SPC s w` | Region-or-symbol seeded content search | Seeded `consult-ripgrep` | Seeded safe Ivy rg reader | Grep Export or repository-owned Grep result |
| `SPC s W` | Seeded ripgrep options | Same ripgrep Transient | Same | Explicit seeded action |
| `SPC ?`, `SPC s h` | Isearch history | `consult-isearch-history` | `consult-isearch-history` through the native completion adapter | Embark Collect/Export |
| `M-x`, `SPC s c` | Emacs commands | Built-in command completion | `counsel-M-x` | Embark actions or Ivy actions |
| `SPC s k` | Kill ring | `consult-yank-from-kill-ring` | `counsel-yank-pop` | Frontend-specific persistence |
| `SPC s s` | Current-buffer symbols | `consult-imenu` | `counsel-imenu` | Frontend-specific persistence |

### Xref, Eglot, diagnostics, and native navigation

| Binding | Domain | `native-consult` | `ivy-counsel` | Result surface |
| --- | --- | --- | --- | --- |
| `SPC s S` | Workspace symbol/Xref apropos | Xref with Consult presentation | Native Xref presentation | Xref result buffer where multiple results exist |
| `gd`, `SPC s d`, `C-c e d` | Definitions | Eglot/Xref with Consult presentation | Eglot/Xref with native presentation | Xref |
| `gD`, `SPC s D`, `C-c e D` | Declarations | Eglot/Xref with Consult presentation | Eglot/Xref with native presentation | Xref |
| `gi`, `SPC s i` | Implementations | Eglot/Xref with Consult presentation | Eglot/Xref with native presentation | Xref |
| `SPC s r`, `C-c e R` | References | Eglot/Xref with Consult presentation | Eglot/Xref with native presentation | Xref |
| `SPC s t`, `C-c e t` | Type definitions | Eglot/Xref with Consult presentation | Eglot/Xref with native presentation | Xref |
| `SPC s I`, `SPC s O` | Incoming/outgoing calls | Native Eglot hierarchy | Same | Persistent hierarchy buffer |
| `K`, `SPC c h`, `C-c e h` | Documentation | Native ElDoc | Same | ElDoc buffer |
| `[d`, `]d`, `SPC d p`, `SPC d n` | Diagnostic movement | Native Flymake | Same | Direct navigation |
| `SPC d f`, `SPC d l` | Buffer/project diagnostics | Native Flymake | Same | Persistent diagnostic list |
| `SPC m`, `SPC s m` | Evil marks | Native Evil | Same | Persistent marks view |
| `SPC j`, `SPC s j` | Evil jumps | Native Evil | Same | Persistent jumps view |
| `SPC s H` | Face inspection | Native Help | Same | Help buffer |
| `SPC s v`, `SPC s V` | Stack toggle/menu | Profile controller | Same | No completion result |

The Xref activation state owns both `xref-show-xrefs-function` and
`xref-show-definitions-function`. Capture their native values before installing
Consult. Entering `native-consult` assigns both Consult presenters. Entering
`ivy-counsel` restores the captured native presenters. Do not hardcode private
Xref implementation symbols.

## Transient Options and Backend Translation

The lowercase leader command runs immediately. Its uppercase companion opens
the relevant options menu. Transient records are stack-neutral; adapters
translate recognized values into backend arguments.

### Files: `M-p`, `SPC f P`

- root: project or current directory;
- include hidden files;
- include ignored files;
- follow symlinks;
- case: insensitive, smart, or sensitive;
- `RET`: save and run;
- `C-g`: cancel without saving;
- standard Transient reset: restore code defaults.

`native-consult` translates settings into a dynamically bound public
`consult-fd-args` list. `ivy-counsel` translates file-universe settings into
separate argv lists for the repository-owned `fd` and fzf processes. The
editable query is one fzf argument. `fd` enumerates the universe in the fzf
path; fzf owns query matching and ranking.

### Current-buffer lines: `SPC s L`

- case: insensitive or sensitive;
- origin: point or buffer top;
- `RET`: save and run.

Adapters bind case locally and restore point and window start on cancellation.
Do not mutate global case variables to implement one invocation.

### Multi-buffer lines: `SPC s B`

- case: insensitive or sensitive;
- scope: all eligible open buffers or current project;
- `RET`: save and run.

`consult-line-multi` receives an explicit buffer universe. `swiper-all` owns its
documented eligible-buffer universe. In the Ivy stack, project scope uses
`consult-line-multi` through the narrow native completion adapter with a
bounded buffer list built from public project.el information. Do not advise
Swiper, invent another Ivy line reader, or use private Ivy candidate-push
state.

### Buffers: `SPC b B`

- case: insensitive or sensitive;
- scope: all live buffers or project sources;
- `RET`: save and run.

`native-consult` uses a live-buffer-only Consult source for all scope and
`consult-project-buffer` for project scope. Document that the latter includes
project virtual sources, not only live buffers. `ivy-counsel` uses
`ivy-switch-buffer` for all scope and a profile-owned `completing-read` table
built from public project.el buffers/files for project scope.

Project file selection must also stop binding
`project-read-file-name-function` to private
`project--read-file-absolute`. Build the project-file table from public
`project-current`, `project-root`, and `project-files`, retain relative
display names with absolute values, and pass the table through ordinary
`completing-read`. It will use the selected native or Ivy minibuffer frontend.

### Ripgrep: `SPC s G`, `SPC s W`

- root: project or current directory;
- include hidden files;
- include ignored files;
- follow symlinks;
- case: insensitive, smart, or sensitive;
- matching: regexp or fixed string;
- optional glob;
- optional file type;
- context line count;
- `RET`: save and run unseeded search;
- `w`: save and run region-or-symbol seeded search;
- `C-g`: cancel without saving.

Do not use `counsel-rg` for these facades. At the pinned revision it recognizes
`" -- "` inside editable input as extra command arguments and transforms the
remaining query through Ivy's regexp builder. Those semantics conflict with
the plan's recognized-options-only process boundary and literal seeded input.

Implement the Ivy rg path as a repository-owned public `ivy-read` dynamic
collection:

1. Do not start rg for an empty query. On non-empty input, create one
   list-valued rg command from recognized Transient values and the query.
2. Pass roots, globs, types, context, and the query as separate argv values to
   `make-process`. After recognized options, pass `-e`, the query as its value,
   then a literal `--` argv sentinel before every root. This makes a leading
   hyphen part of the pattern and prevents option-like roots from becoming
   options. Never invoke a shell and never parse an embedded `" -- "` as
   control syntax.
3. Use `--json` and parse complete JSON records from the process filter. Store
   file, line, column, and match text as candidate metadata instead of parsing
   a colon-delimited display string.
4. In fixed mode, pass `--fixed-strings`; in regexp mode, pass the editable
   query unchanged as the rg pattern. Add `--multiline` for multiline seeds and
   pass newline-containing input as one argv value.
5. Pass an explicit rg case flag for every invocation. Do not rely on query
   capitalization.
6. Cancel the previous process on each input change, tag every invocation with
   a generation value, and ignore stale filters and sentinels.
7. Stream parsed matches through the public `ivy-update-candidates` entry point
   while rg is running. Use `unwind-protect` to close the process and temporary
   buffer on accept, quit, error, or replacement.
8. Keep current typed candidates in repository-owned session state. C-q creates
   a `grep-mode` result buffer from that state without rerunning rg or reading
   private Ivy variables.

This adapter preserves literal region/symbol seeds, including spaces,
regexp punctuation, option-like text, embedded `" -- "`, and newlines, while
still allowing explicit regexp mode.

Menus without meaningful saved settings are not added. History, command,
kill-ring, Imenu, recent-file, Xref/Eglot, call hierarchy, diagnostics, marks,
jumps, and Help retain direct commands.

## Case Contract

The profile's code defaults remain explicitly case-insensitive:

- `completion-ignore-case` is non-nil;
- `read-buffer-completion-ignore-case` is non-nil;
- `read-file-name-completion-ignore-case` is non-nil on every platform;
- `case-fold-search` is non-nil;
- `search-upper-case` is nil so uppercase Isearch input does not silently
  enable sensitive matching;
- `evil-ex-search-case` is `insensitive`;
- `ivy-case-fold-search-default` is `t`, not `auto`;
- local and remote `fd`, local fzf, and both rg routes receive explicit case
  flags where the command family owns a saved case setting.

Saved overrides are dynamically bound for one command family and do not mutate
unrelated global settings. Native completion variables do not configure Ivy,
Swiper, Counsel, `fd`, `fzf`, or `rg`. Every adapter must translate the saved
intent at its own boundary.

Completion-table metadata remains authoritative when an upstream table owns
case semantics. Eglot and Xref backend queries retain backend-defined case
behavior in both stacks.

## Actions and Persistent Results

`C-q` means "persist the visible candidates" only inside an active completion
UI:

- native CAPF, native minibuffer, and Consult/native prompts use
  `my/completion-collect` and Embark Collect;
- Ivy, Counsel, and Swiper prompts use `ivy-occur` or the command-specific
  Occur function registered by Counsel;
- the repository-owned Ivy fzf prompt uses its repository-owned Dired exporter
  over the current safe session state;
- the repository-owned Ivy rg prompt uses its repository-owned `grep-mode`
  exporter over typed candidate metadata;
- global `C-q` remains `quoted-insert` outside a completion UI.

Retain `C-c .` for Embark actions. In an Ivy prompt, Ivy's own `M-o` action
dispatcher remains the primary action surface. Do not try to force one action
implementation across both frontends.

Remove the existing fzf-specific Embark collector, Ivy setup hook, Embark
default-action override, `counsel-fzf` shell command, and private Ivy state
access. Record the accepted Evil jump after the repository-owned Ivy reader
returns successfully. The finished architecture must not depend on
`counsel--fzf-dir`, `ivy--old-cands`, `ivy--queue-exhibit`, `ivy-last`, private
Consult async functions, or new advice around package internals.

## Dependencies

Provision every directly used package explicitly:

- `consult`;
- `embark`;
- `embark-consult`;
- `transient`;
- `ivy`;
- `counsel`;
- `swiper`.

Do not rely on transitive dependencies or mutable archive heads. Provision the
direct packages with `package-vc` from this reviewed set before any completion
module or test loads them:

| Packages | Repository | Revision |
| --- | --- | --- |
| Ivy, Counsel, Swiper | `https://github.com/abo-abo/swiper.git` | `0d02f5063d36ff4fa6138f0973c83c6d3874fba0` |
| Consult | `https://github.com/minad/consult.git` | `1b217ca2fb8bcfc4bb56feef829d1bb2b61c85b1` |
| Embark, `embark-consult` | `https://github.com/oantolin/embark.git` | `87e53827cf6659dcc4ac4e54be9af34aeca44f6e` |
| Transient | `https://github.com/magit/transient.git` | `03c8ccc6aab24021787aada2be12d64cb1f436e8` |

Call the public `package-vc-commit` function on every installed package
descriptor and require the revision in this table. A missing,
archive-installed, mixed-revision, or mismatched direct package must produce
one actionable provisioning error. Do not silently accept an installed archive
copy or update to an unreviewed branch head. Do not install or use `ivy-xref`;
the Ivy stack intentionally preserves native Xref presentation. Keep the four
revisions in a named installer table because they are protocol boundaries, not
incidental literals.

External tools:

- `fd` for native local discovery, safe fzf universe production, and preferred
  remote recursive discovery;
- `fzf` for `ivy-counsel` local recursive discovery only;
- `rg` for both content-search implementations;
- portable remote `find` for the existing remote fallback.

Missing programs produce a clear error when the affected command is invoked.
Selecting a stack does not eagerly run or validate external programs.

## Current Codebase Context

- `profiles/common/.config/emacs/init.el:443-635` configures Consult, Counsel,
  Embark, native completion, CAPF behavior, line search, and ripgrep.
- `profiles/common/.config/emacs/init.el:450-465` currently installs an
  unconditional Consult buffer remap and Consult Xref presenters; both must
  become stack-aware.
- `profiles/common/.config/emacs/init.el:481-600` owns the shared native
  completion and CAPF contract.
- `profiles/common/.config/emacs/init.el:602-605` owns Savehist and the search
  rings that can also persist the selected stack.
- `profiles/common/.config/emacs/init.el:1832,1893-1971,2100-2102` owns
  `C-x C-f`, leader search bindings, and the current `C-p`/`C-S-p` pair.
- `profiles/common/.config/emacs/my-file-picker.el:1-379` owns hierarchical,
  recursive, project, TRAMP, the current Counsel fzf path, Transient, Collect, toggle, and Evil
  jump behavior.
- `profiles/common/.config/emacs/my-file-picker.el:82-106` contains the current
  private-Ivy fzf collector boundary targeted for removal.
- `profiles/common/.config/emacs/my-file-picker.el:158-241` contains the
  nested picker and native refresh lifecycle targeted for replacement.
- `profiles/common/.config/emacs/my-file-picker.el:343-357` binds the private
  `project--read-file-absolute` function targeted for replacement with a
  public project.el completion table.
- `profiles/common/.config/emacs/install-packages.el:53-83` provisions Consult,
  Counsel, Ivy, Embark, and `embark-consult`, but does not list every direct
  dependency explicitly.
- `profiles/common/.config/emacs/appearance-test.el:456-608` covers native
  completion, candidate navigation, and native Collect.
- `profiles/common/.config/emacs/my-file-picker-test.el:1-641` covers picker
  transfer, local/remote routing, fzf settings, Collect, and Evil jumps.
- `profiles/common/.config/emacs/leader-bindings-test.el:1-372` covers leader,
  state, and Which Key behavior.
- `profiles/common/.config/emacs/gui-smoke-test.el:23-120` exercises C-p,
  ripgrep, hierarchical file visits, and Evil jump return.
- `dev/plans/8-emacs-refinment.md:122-158,353-458` records the completed fzf,
  persistent-options, and native Collect work. Preserve its execution history.
- `dev/plans/9-emacs-completion-refinment-pt2.md` describes a native-only
  alternative. This plan replaces it as the implementation target rather than
  depending on it.

## Status

- Overall: in progress
- Current milestone: Phase 5 (pending)
- Commit policy: one new Git commit after each accepted Phase

Phase status:

- Phase 1: complete
- Phase 2: complete
- Phase 3: complete
- Phase 4: complete
- Phase 5: pending
- Phase 6: pending

## Goal

Provide two reliable completion and search experiences in one Emacs process:
a native `*Completions*`/Consult/Embark stack optimized for streamed external
results, and a native-CAPF/Ivy/Counsel/Swiper stack that retains real fzf
ranking for local recursive files. Keep bindings and saved search options
stable while the selected frontend and command implementations change.

## Decisions

1. Keep native completion-in-region and native CAPF acceptance invariant.
2. Make `native-consult` the code default, persist a separate saved preference
   through Savehist, and keep applied runtime state distinct.
3. Toggle only while no minibuffer, completion-in-region session, or Transient
   is active.
4. Use stable profile-owned facade commands. Do not rewrite many global and
   Evil keymaps during every toggle.
5. Enable `ivy-mode` only for `ivy-counsel`; never enable `counsel-mode`.
6. Set `ivy-do-completion-in-region` to nil before Ivy is enabled and assert
   the invariant after every transition.
7. Never run a Consult prompt through Ivy. Use native Xref presenters in the
   Ivy stack and a narrow native adapter for remote recursive files, Isearch
   history, and project-scoped multi-buffer lines.
8. Keep `C-x C-f` on `my/find-file` and `read-file-name` in both stacks.
9. Use a frontend-neutral file-picker controller instead of suspended nested
   minibuffers and frontend-specific refresh.
10. Keep Transient values stack-neutral and translate them at each backend.
11. Use Embark Collect/Export for native and Consult prompts, Ivy/Counsel Occur
    where supported, and repository-owned typed exporters for custom fzf and rg
    readers.
12. Keep exact fzf ranking and streaming as explicit alternative behaviors;
    do not claim that either path provides both.
13. Keep all matching case-insensitive by default and pass explicit flags to
    each external producer or matcher.
14. Preserve native Eglot, Flymake, call-hierarchy, Evil marks/jumps, ElDoc,
    and Help result surfaces.
15. Add no new dependency on private Ivy, Counsel, Consult, Xref, or project.el
    APIs.
16. Keep Ivy, Counsel, Swiper, Consult, Embark, `embark-consult`, and Transient
    as explicit, exact-revision runtime dependencies.
17. Remove `C-S-p`; keep `C-p` immediate, `M-p` as its normal/visual options
    companion, and lowercase/uppercase leader pairs for configurable families.
18. Update this plan's status and evidence during implementation. Do not rewrite
    completed historical plan records.

## Dependency Graph

```text
Phase 1 pinned dependencies, shared CAPF, and stack lifecycle
  -> Phase 2 stable command facades
    -> Phase 3 stack-aware file discovery
      -> Phase 4 search options and complete command coverage
        -> Phase 5 actions, persistence, and cleanup
          -> Phase 6 integrated validation and documentation
```

## Phase 1: Establish Shared Completion and Stack Lifecycle

### Implementation Status

Completed 2026-09-09 in the Phase 1 milestone commit. The installer now
provisions all seven direct completion dependencies from the reviewed VC
revisions, validates filtered VC descriptors with `package-vc-commit`, and
reports missing, archive-only, conflicting, or mismatched installations in one
actionable error. Exact VC installs may coexist with lower-priority archive
copies because package-vc gives the reviewed checkout precedence; a clean
isolated one-pass provision accepted every required revision.

`my-completion-stack.el` captures native minibuffer, completion-in-region, and
both Xref presenters once. Its setter transactionally switches ordinary
minibuffer and Xref presentation, preserves native CAPF completion, rejects
active UI transitions, rolls back failures, and exposes the toggle and
Transient controls. Savehist restores only the preference and startup applies
it through the setter. Validation: installer ERT 7/7, stack lifecycle ERT 8/8,
appearance ERT 14/14, leader ERT 10/10, saved Ivy and invalid-preference startup
probes, double init plus soft reload, clean pinned-package provisioning, clean
module byte compilation, `check-parens`, and `git diff --check`. Real graphical
minibuffer and language-server item acceptance remain in Phase 6 integrated
validation.

### Changes

1. Update `profiles/common/.config/emacs/install-packages.el` to provision and
   validate every package in the reviewed revision table before loading any
   completion module or test. Verify clean installation and rejection of
   archive, missing, and mismatched copies first.
2. Add `profiles/common/.config/emacs/my-completion-stack.el` with the validated
   stack state, captured native frontend and Xref functions, idempotent setter,
   toggle, active-session guard, and stack Transient. Capture both native Xref
   presenter values before the current Consult assignments execute.
3. Load the module from `profiles/common/.config/emacs/init.el` after native
   completion variables and package declarations are available and before
   applying the persisted startup choice.
4. Set `ivy-do-completion-in-region` to nil before any `ivy-mode` activation.
   Keep the existing CAPF list and native completion maps unchanged.
5. Replace minibuffer `S-RET` bound directly to `exit-minibuffer` with
   `minibuffer-complete-and-exit` so permissive and must-match prompts use the
   public validated path.
6. Implement activation as a transaction. Restore the prior applied state and
   saved preference if loading or activation fails. Repeated selection of the
   active stack is a no-op.
7. Add only `my/completion-stack-saved` to
   `savehist-additional-variables` before `savehist-mode` is enabled. Keep
   `my/completion-stack` nil during bootstrap. After Savehist restores the
   preference, validate it, substitute `my/completion-stack-default` when
   absent or invalid, and call the setter exactly once to establish frontend,
   Xref, applied state, and saved state together.
8. Bind `SPC s v` to the immediate toggle and `SPC s V` to the selection menu.
   Add accurate Which Key labels that include the currently selected stack
   where supported without rebuilding keymaps.
9. Add a focused `my-completion-stack-test.el` for lifecycle behavior rather
   than expanding unrelated appearance tests with state-machine cases.

### Success Criteria

- Ordinary minibuffer completion visibly switches between native
  `*Completions*` and Ivy.
- A clean install reports the exact reviewed commit for every direct package
  before any completion package is loaded.
- CAPF candidates remain in native `*Completions*` in both stacks.
- Editing source text during an Eglot completion causes source-backed
  refinement in both stacks.
- Native acceptance preserves plain insertion, snippets, `textEdit`,
  `additionalTextEdits`, and exit functions.
- Toggling is rejected without state mutation during a live minibuffer, CAPF,
  or Transient.
- The same guard rejects toggling while a Consult, Ivy rg, Swiper, or fzf
  process-backed prompt owns the active minibuffer.
- Restoring `ivy-counsel` from Savehist performs real Ivy and Xref activation;
  it cannot be mistaken for an already-applied no-op.
- Native to Ivy to native round trips restore the exact captured frontend and
  Xref state.
- Repeated setters, soft reload, and a second init load add no duplicate state.
- S-RET accepts valid literal input and cannot escape a must-match prompt.

## Phase 2: Introduce Stable Command Facades

### Implementation Status

Completed 2026-09-09 in the Phase 2 milestone commit. Seven profile-owned
facades now dispatch interactive buffer, command, incremental-search,
kill-ring, Imenu, recent-file, and Isearch-history commands without rewriting
bindings during stack transitions. Native buffer selection uses a
repository-owned Consult source built from public live-buffer APIs. The narrow
native adapter suppresses Ivy dynamically for the complete Consult Isearch
history call, and Ivy C-q is configured once for `ivy-occur` without changing
global C-q.

Direct C-x b, M-x, Evil C-s, and Phase 2 leader keys now resolve to the stable
facades. Table-driven ERT verifies both backend mappings and interactive prefix
forwarding, while focused tests cover the public buffer source, native adapter
restoration, and one-time Ivy map setup. The cumulative combined reviewer found
that `quit` could bypass the Phase 1 transaction rollback; the accepted
follow-up handles both `error` and `quit`, re-signals the original condition,
and includes a simulated partial-activation quit test. Validation: completion
stack ERT 12/12, appearance ERT 14/14, leader ERT 11/11, clean module byte
compilation, `check-parens`, `git diff --check`, real Ivy binding assertions,
double init, soft reload, and a fresh no-findings confirmation review. File,
line, and ripgrep commands remain deferred to Phases 3 and 4.

### Changes

1. Add the buffer, command, incremental-search, kill-ring, Imenu, recent-file,
   and Isearch-history facades to `my-completion-stack.el`. Use direct
   conditional dispatch and preserve each command's interactive behavior,
   initial input, history, and prefix args. File facades arrive in Phase 3 and
   line/ripgrep facades arrive in Phase 4.
2. Replace the unconditional Consult `switch-to-buffer` remap and direct leader
   bindings with stable facades. Ensure Ivy's minor-mode remaps cannot bypass
   the selected facade for explicitly configured keys.
3. Replace the private `consult--source-buffer` dependency with a
   repository-owned Consult source plist whose candidates come from public
   `buffer-list` and `buffer-name` calls. Preserve the live-buffer-only all
   scope and keep project scope on the documented `consult-project-buffer`
   behavior.
4. Bind C-s in Evil normal, visual, and insert states to
   `my/search-incremental`. Keep this distinct from `my/search-line` because
   native Isearch and Consult line search have different interaction and
   persistence contracts.
5. Route `consult-isearch-history` through the native completion adapter in the
   Ivy stack. Keep `search-ring` and `regexp-search-ring` unchanged across restarts.
   Do not add a second history parser merely to make this prompt use Ivy.
6. Configure `ivy-minibuffer-map` once after Ivy loads: C-q uses `ivy-occur`,
   normal Ivy actions remain available, and no global C-q binding changes.
7. Add table-driven tests for the Phase 2 facades under both stack values and
   assert the selected public backend and preserved arguments. Defer the full
   command matrix assertion until Phase 4 and Phase 6.

### Success Criteria

- Every Phase 2 key resolves to a stable profile-owned command.
- Every Phase 2 facade reaches its documented backend.
- Native all-buffer selection uses only public Consult and Emacs APIs while
  retaining its live-buffer-only universe.
- No Consult candidate reader runs through `ivy-completing-read`.
- Both Xref presenter variables change and restore atomically.
- Stack transitions do not rewrite or accumulate global, Evil, or leader
  bindings.
- Isearch history is selectable in both stacks and survives restart.
- The Evil normal/visual C-p file binding does not replace C-p candidate
  navigation inside native CAPF, native minibuffer, or Ivy minibuffer maps.
- M-p remains minibuffer history navigation in both frontends and opens file
  options only from the intended Evil normal/visual binding.

## Phase 3: Make File Discovery Stack-Aware

### Implementation Status

Completed 2026-09-09 in the Phase 3 milestone commit. File discovery now uses
one frontend-neutral controller whose prompt adapters return explicit selected,
toggle, or cancel results. Local native discovery uses public `consult-fd`;
local Ivy discovery uses separate argv-only `fd` and fzf processes with NUL
framing, platform filename coding, generation ownership, public dynamic
candidate updates, and complete cleanup. Remote Consult calls remain inside the
native-completion adapter, while project selection uses only public project.el
data with exact-first and case-folded canonical path mapping.

The shared Transient translates root, file-universe, symlink, and case intent
at each backend. C-q exports the current safe fzf candidate snapshot to Dired,
and the controller records exactly one Evil jump after a successful
cross-buffer visit. The combined review found and resolved Unicode decoding,
case-folded project lookup, and fzf no-match status handling; two fresh
confirmation passes resolved the signal-status edge and reported no remaining
findings. Validation: picker ERT 13/13, completion stack ERT 12/12, appearance
ERT 14/14, leader ERT 12/12, affected GUI smoke ERT 2/2, real Unicode fd/fzf
runtime probes, double init plus soft reload, clean module byte compilation,
`check-parens`, and `git diff --check`. Line and ripgrep search remain assigned
to Phase 4.

### Changes

1. Refactor `profiles/common/.config/emacs/my-file-picker.el` around the
   frontend-neutral controller result protocol. Remove suspended outer prompt
   refresh and make each session own its complete lifecycle.
2. Replace direct use of `my/find-file-fzf-root` with
   `my/find-file-recursive-configured`. Keep implementation-specific functions
   as backend adapters, not user-facing bindings.
3. Implement local `native-consult` discovery through public `consult-fd`.
   Implement local `ivy-counsel` discovery through the repository-owned,
   argv-safe `ivy-read` adapter over separate `fd` and fzf processes.
4. Translate the shared root, hidden, ignored, symlink, and case options into
   validated backend-specific argument lists.
5. Preserve remote `consult-fd` and portable `consult-find`. In the Ivy stack,
   dynamically bind `ivy-mode` to nil and `completing-read-function` to
   `completing-read-default` around the entire remote Consult call. Do not
   call the global Ivy mode setter for this command.
6. Preserve hierarchical/recursive `C-c C-r` query transfer, including literal
   filename recovery and incomplete TRAMP host rejection.
7. Replace the private `project--read-file-absolute` binding. Build project
   candidates from public `project-current`, `project-root`, and
   `project-files`, show paths relative to the project root, and map the
   selected display value back to an absolute path before visiting it.
8. Preserve source markers and call public `evil-set-jump` only after a
   successful cross-buffer visit. Cancellation or a failed backend creates no
   jump.
9. Bind `C-p` and `SPC f p` to immediate configured discovery. Bind `M-p` in
   Evil normal/visual states and `SPC f P` to options. Remove `C-S-p` without
   changing minibuffer M-p history or CAPF C-p navigation.
10. Delete the private-Ivy fzf collector, setup hook, Embark override,
   `counsel-fzf-cmd`, and `counsel-fzf-action` rebinding. Add one
   repository-owned C-q Dired exporter over the active safe file-session state,
   then record an Evil jump only after the Ivy reader returns a successful
   visit.

### Success Criteria

- A runtime toggle changes local C-p between streamed Consult fd results and
  exact fzf-ranked Ivy results.
- `C-x C-f` remains hierarchical, local/TRAMP-aware, and create-capable in both
  frontends.
- `C-c C-r` changes discovery modes without nested frontend refresh, lost root,
  or lost transferable query.
- Hidden and ignored files are included by default, symlinks are not followed,
  `.git` is excluded, and case is insensitive.
- TRAMP paths never reach local `fd` or fzf.
- Remote native fallback leaves the selected Ivy stack enabled after success,
  cancellation, and error, and scopes its native bindings to that Consult call.
- Project file selection uses no private project.el symbol and preserves
  relative display names, absolute visits, cancellation, and an empty project.
- C-q creates a usable Dired result from current fzf candidates rooted at the
  selected directory without rerunning a shell command.
- Successful cross-buffer visits record exactly one Evil jump; cancel records
  none.

## Phase 4: Add Search Options and Complete Command Coverage

### Implementation Status

Completed 2026-09-09 in the Phase 4 milestone commit. `my-search.el` now owns
stack-aware line, multi-buffer line, buffer, and ripgrep facades plus their
saved Transients. Native routes use public Consult commands, all-open Ivy line
search uses Swiper, project-scoped Ivy line search uses the native adapter, and
local Ivy ripgrep uses one argv-only, generation-owned rg JSON process. Remote
Ivy ripgrep remains inside the native Consult adapter so local processes never
receive TRAMP roots.

The adapters translate case, origin, scope, root, file-universe, matching,
glob, type, and context intent at the owning boundary. The custom rg reader
preserves arbitrary query data, publishes typed match and context candidates,
converts UTF-8 byte offsets to character columns, restores cancelled previews,
and exports the current candidate snapshot to Grep without rerunning rg. The
stable lowercase immediate and uppercase options bindings now cover every
configurable search family.

The combined reviewer covered 764 production and 662 test additions. Review
found and resolved native multiline seed handling, typed trailing-whitespace
preservation, and atomic Consult glob/type/context arguments; a fresh final
confirmation reported no findings. Validation: search ERT 10/10, completion
stack ERT 11/11, file picker ERT 13/13, leader ERT 12/12, appearance ERT
14/14, GUI smoke ERT 7/7, real rg Unicode/context/literal-seed and installed
Consult argument-builder probes, double init plus soft reload, clean module
byte compilation, `check-parens`, and `git diff --check`. Live graphical
completion and persistent-result acceptance remain assigned to Phases 5 and
6.

### Changes

1. Add `profiles/common/.config/emacs/my-search.el` for line, multi-buffer,
   buffer, and ripgrep Transients plus backend adapters. Keep stack lifecycle
   in `my-completion-stack.el` and file transactions in `my-file-picker.el`.
2. Implement current-line, multi-buffer line, buffer, unseeded ripgrep, and
   seeded ripgrep facades with the stack-neutral settings defined above.
3. Implement explicit case translation for native completion, Ivy/Swiper,
   Consult, the repository-owned Ivy rg reader, `fd`, fzf, and rg. Do not rely
   on uppercase-query smart case for the insensitive default.
4. Preserve preview and restore buffer, point, and window start on cancel for
   both implementations.
5. Define all-open and project scope semantics independently. Use `swiper-all`
   for the documented all-open Ivy universe. For Ivy project scope, pass a
   public project.el-derived buffer list to `consult-line-multi` through the
   native completion adapter and label that prompt as native Consult.
6. Build ripgrep process args from recognized values. Preserve literal seed,
   multiline, glob, type, context, hidden, ignore, symlink, root, matching, and
   case behavior across both adapters. Implement the Ivy adapter with
   `make-process`, rg JSON output, typed candidate metadata, generation-based
   stale-result rejection, and `ivy-update-candidates`. Pass the pattern as
   `-e QUERY`, then `--` and the roots. Treat embedded `" -- "` and option-like
   query text as pattern data, never extra process arguments.
7. Apply the complete binding matrix and lowercase immediate/uppercase options
   convention. Do not add empty menus to backend-owned navigation.
8. Add `my-search-test.el` with a small number of table-driven behavioral tests.
   Cover fixed and regexp modes with spaces, regexp punctuation, option-like
   text, embedded `" -- "`, multiline seeds, stale generations, and process
   cleanup. Extend leader and GUI smoke tests for the stable bindings.

### Success Criteria

- Current-line, multi-buffer, buffer, and ripgrep bindings use the documented
  implementation in each stack.
- Lowercase bindings execute immediately; uppercase companions expose only
  meaningful saved settings.
- Case is insensitive by default even when the query contains uppercase text.
- Every saved override reaches both the Emacs-side matcher and external process
  that owns the relevant filtering.
- Consult file and rg paths visibly stream and discard stale results.
- The repository-owned Ivy rg path streams current-generation JSON matches;
  Swiper paths update according to their documented in-process lifecycle.
- Seeded ripgrep preserves literal region/symbol text and multiline matching.
- Ivy rg preserves spaces, shell metacharacters, regexp punctuation,
  option-like text, `" -- "`, and multiline seeds because those values never
  enter a shell command string or an editable-input argument parser.
- Cancellation restores the original location and publishes no stale preview.

## Phase 5: Finish Actions and Persistence

### Changes

1. Verify native `my/completion-collect`, Embark Collect, and specialized
   `embark-consult` exports for native and Consult sessions.
2. Verify `ivy-occur` and registered Counsel/Swiper Occur functions for every
   Ivy-family facade. Verify the repository-owned fzf Dired exporter and rg
   `grep-mode` exporter from typed session state. Retain the standard
   `C-c C-o` alias alongside C-q where the frontend supplies it.
3. Verify Transient values, `my/completion-stack-saved`, and the applied
   `my/completion-stack` across two isolated Emacs processes. C-g must not save
   in-progress values; reset restores code defaults.
4. Confirm that stack selection itself does not check external tools or start
   remote/local processes. Backend commands validate `fd`, fzf, or rg when
   invoked.

### Success Criteria

- C-q means Embark Collect in native interfaces, Ivy/Counsel Occur in supported
  Ivy interfaces, and the typed repository-owned exporter in fzf and rg
  interfaces; global C-q remains `quoted-insert`.
- Exported Dired, Ibuffer, Occur, Grep, and Xref results retain valid target
  metadata.
- Persistent result buffers remain usable after switching stacks.
- No private Ivy candidate collector, private Consult source, private Consult
  async dependency, or private project.el file reader remains.
- The restored saved preference and applied runtime state agree after startup,
  stack changes, failures, and reset.
- Saved search values survive stack changes without leaking into other command
  families.

## Phase 6: Integrated Validation and Documentation

### Changes

1. Run real native and Ivy ordinary minibuffer prompts plus real CAPF sessions
   in both stacks. Exercise Eglot incomplete completion and complex completion
   items where an available language server supports them.
2. Run real `fd`, fzf, and rg searches over temporary trees containing
   mixed-case, hidden, ignored, symlinked, and `.git` paths. Use a controlled
   slow producer to distinguish streaming Consult output from delayed globally
   ranked fzf output.
3. Exercise available TRAMP hosts for hierarchical completion, remote fd,
   remote find, native adapter scoping, and file creation. Record an
   unavailable live host explicitly rather than replacing it with mocked
   success.
4. Run `my-completion-stack-test.el`, `appearance-test.el`,
   `my-file-picker-test.el`, `my-search-test.el`, `leader-bindings-test.el`, and
   `gui-smoke-test.el`. Keep tests small by combining matrix cases.
5. Batch-load `init.el` twice, invoke `my/soft-reload`, run `check-parens` on
   changed Emacs Lisp, byte-compile owned modules to a temporary directory, and
   run `git diff --check`.
6. Verify that no direct package binding bypasses the facade matrix and that no
   configurable lowercase leader command opens a menu.
7. Add a short supersession note to
   `dev/plans/9-emacs-completion-refinment-pt2.md`. Preserve its design record
   and do not mark its native-only phases complete.
8. Update this plan after every Phase with implementation status, validation
   evidence, deviations, and the accepted commit.

### Success Criteria

- All focused and integration suites pass in the provisioned Emacs 31.1
  environment.
- Both stacks can be selected repeatedly without restarting Emacs or leaking
  frontend state.
- Native CAPF remains live, source-backed, and acceptance-correct in both
  stacks.
- Ordinary minibuffer completion, every search facade, Xref presentation,
  recursive files, and C-q match the active stack matrix.
- Native file and rg paths visibly stream; fzf visibly retains its ranked,
  non-streaming completion behavior.
- `C-x C-f`, TRAMP, file creation, picker toggling, cancellation, and Evil jumps
  retain their documented behavior.
- All case defaults, saved overrides, Transients, and Which Key labels match
  the final contract.
- Startup is offline and starts no file enumeration, content search, or remote
  operation.

## Overall Success Criteria

- `native-consult` and `ivy-counsel` are complete selectable profiles rather
  than a cosmetic `ivy-mode` toggle.
- Native completion-in-region is invariant across both profiles.
- Ordinary minibuffer prompts switch cleanly between native `*Completions*`
  and Ivy.
- Local recursive discovery switches between streamed Consult fd and actual
  fzf-ranked Ivy results.
- Stable user bindings and stack-neutral Transients preserve muscle memory and
  saved intent.
- Consult never runs through `ivy-completing-read`; remote files, Isearch
  history, and project-scoped multi-buffer lines use a bounded native
  completion adapter without changing the selected stack.
- Case defaults are insensitive and every supported override is translated at
  the owning backend boundary.
- Persistent results and accepted navigation retain correct source locations.
- No `counsel-mode`, alternate CAPF frontend, private async integration, or
  package-unload lifecycle is introduced.
- Exact package provisioning, tests, documentation, saved preference, and
  applied runtime state agree with the complete matrices in this plan.

## Risks and Constraints

- A completion stack cannot be changed underneath a live recursive minibuffer.
  The explicit guard is part of the public command contract.
- Ivy mode owns `completing-read-function` and a minor-mode remap. Direct package
  key bindings would bypass the selected facade and must be removed.
- Consult explicitly does not support Ivy as its completion frontend. Every
  retained Consult use in the Ivy profile must dynamically suppress Ivy's
  mode variable and select native `completing-read` for the full Consult call.
- Exact globally sorted fzf results and producer streaming are incompatible in
  the retained `fzf --filter` design. The stacks intentionally expose the two
  alternatives.
- `swiper-all` and `consult-line-multi` do not define identical buffer
  universes. Project scope needs an explicit public adapter and behavioral
  tests.
- `consult-project-buffer` includes virtual project sources. It is not a
  live-buffer-only project filter.
- Portable remote `find` cannot reproduce fd ignore semantics or all case
  modes.
- Ivy Occur and Embark Export produce different buffer modes and action models.
  Persistent-result equivalence means usable targets, not identical UI.
- Saved Transient and stack values outlive code changes. Validate recognized
  values before translating them into process arguments.
- Current installed completion packages may be archive copies or unreviewed
  revisions. Phase 1 must complete exact provisioning and validation before
  any stack implementation is loaded.

## Primary References

- Emacs completion in buffers:
  https://www.gnu.org/software/emacs/manual/html_node/elisp/Completion-in-Buffers.html
- Emacs completion commands:
  https://www.gnu.org/software/emacs/manual/html_node/emacs/Completion-Commands.html
- Emacs completion styles:
  https://www.gnu.org/software/emacs/manual/html_node/emacs/Completion-Styles.html
- Emacs basic completion and case:
  https://www.gnu.org/software/emacs/manual/html_node/elisp/Basic-Completion.html
- Emacs minibuffer internals:
  https://www.gnu.org/software/emacs/manual/html_node/elisp/Minibuffers.html
- Emacs package-vc sources:
  https://www.gnu.org/software/emacs/manual/html_node/emacs/Fetching-Package-Sources.html
- Emacs Xref:
  https://www.gnu.org/software/emacs/manual/html_node/emacs/Xref.html
- Eglot:
  https://www.gnu.org/software/emacs/manual/html_mono/eglot.html
- TRAMP file-name completion:
  https://www.gnu.org/software/emacs/manual/html_node/tramp/File-name-completion.html
- Ivy source and `ivy-do-completion-in-region`:
  https://github.com/abo-abo/swiper/blob/master/ivy.el
- Reviewed Ivy/Counsel/Swiper revision:
  https://github.com/abo-abo/swiper/commit/0d02f5063d36ff4fa6138f0973c83c6d3874fba0
- Counsel commands, fzf integration, and broad remaps:
  https://github.com/abo-abo/swiper/blob/master/counsel.el
- Swiper commands:
  https://github.com/abo-abo/swiper/blob/master/swiper.el
- Consult and supported completion frontends:
  https://github.com/minad/consult
- Reviewed Consult revision:
  https://github.com/minad/consult/commit/1b217ca2fb8bcfc4bb56feef829d1bb2b61c85b1
- Consult asynchronous search:
  https://github.com/minad/consult#asynchronous-search
- Embark and Ivy compatibility:
  https://github.com/oantolin/embark
- Reviewed Embark and embark-consult revision:
  https://github.com/oantolin/embark/commit/87e53827cf6659dcc4ac4e54be9af34aeca44f6e
- Embark Consult:
  https://elpa.gnu.org/packages/embark-consult.html
- Transient saved values:
  https://github.com/magit/transient/blob/main/docs/transient.org#saving-values
- Reviewed Transient revision:
  https://github.com/magit/transient/commit/03c8ccc6aab24021787aada2be12d64cb1f436e8
- fd hidden and ignored files:
  https://github.com/sharkdp/fd#hidden-and-ignored-files
- ripgrep guide:
  https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md
- fzf filter and sorting behavior:
  https://github.com/junegunn/fzf/blob/master/man/man1/fzf.1
- Evil search case behavior:
  https://github.com/emacs-evil/evil/blob/master/evil-vars.el
