# Emacs completion refinement plan

## How the finished system works

Emacs completion has four separate jobs. A source produces candidates, the
built-in completion engine filters and ranks them, `*Completions*` displays
them, and Embark acts on or exports them. Keeping those jobs separate prevents
the search UI from breaking Eglot completion or snippet insertion.

The finished configuration uses these paths:

```text
Code, paths, words, and spelling
  -> Eglot or another completion-at-point function
  -> built-in completion engine
  -> built-in *Completions*
  -> normal completion acceptance

Lines, grep results, buffers, and navigation targets
  -> Consult command
  -> built-in completing-read
  -> built-in *Completions*
  -> jump, Embark action, or persistent export

Definitions, references, diagnostics, and build errors
  -> Eglot/Xref, Flymake, or Compilation
  -> Consult selection when useful
  -> persistent Xref, Flymake, Grep, Occur, or Compilation buffer
```

`*Completions*` remains the only candidate-list frontend. Consult is added as a
producer for live search and asynchronous commands, not as the
`completion-in-region-function`. This distinction keeps typing in the source
buffer so Eglot can refine candidates and apply snippets, `textEdit`, and
`additionalTextEdits` correctly.

File discovery has two modes. Hierarchical mode lists one directory at a time
and can create a new file. Recursive mode discovers every file below a project
or directory and fuzzily filters the complete set. Separate entry keys make the
initial choice predictable, and `C-c C-r` switches modes without discarding the
current root or simple query.

### The minibuffer and `*Completions*` are different places

The minibuffer is the one-line input area at the bottom of the frame. Commands
such as `find-file`, `consult-line`, and `consult-ripgrep` read the path or query
there. It is not the candidate menu.

`*Completions*` is a separate buffer that displays the candidates produced from
that input. It can remain visible and update while point stays in the
minibuffer. In that state, `C-n` and `C-p` change the highlighted candidate
without moving point out of the input area. `M-g M-c` explicitly moves point
into the `*Completions*` buffer when direct list navigation or inspection is
useful. From the results buffer, `M-g M-c` returns to an active minibuffer; `q`
closes the results window and returns to a source buffer after CAPF completion.
The same window is also used by source-buffer completion, but point normally
remains in the source buffer so Eglot can observe further edits.

No arrow-key bindings are added by this plan. `C-n` and `C-p` are the consistent
next and previous keys while typing. In a hierarchical file minibuffer, `TAB`
retains its distinct Emacs meaning: complete a common path prefix or descend
into a directory.

## End-state keybindings

### Completion and actions

| Context | Key | End-state behavior |
| --- | --- | --- |
| Insert state | `C-SPC` | Open all applicable completion-at-point candidates in `*Completions*` |
| Source completion active | `TAB` / `S-TAB` | Select next / previous candidate, matching the Neovim popup workflow |
| Source completion active | `C-n` / `C-p` | Secondary next / previous aliases for Neovim muscle memory |
| Source completion active | `RET` | Accept the selected candidate; insert a newline when nothing is selected |
| Source completion active | `M-RET` | Explicitly accept the selected candidate |
| Typing in a completion minibuffer | `C-n` / `C-p` | Select next / previous visible candidate while point remains in the input area |
| Typing in a completion minibuffer | `TAB` | Complete a common prefix or descend into a file directory; never unconditional cycling |
| Typing in a completion minibuffer | `RET` | Accept the selected candidate or submit the minibuffer input |
| Focus inside the `*Completions*` results buffer | `TAB` / `S-TAB`, `C-n` / `C-p`, or `n` / `p` | Move to the next / previous candidate |
| Focus inside the `*Completions*` results buffer | `RET` | Choose the candidate at point |
| Source buffer or completion minibuffer | `M-g M-c` | Move focus to the visible `*Completions*` results buffer |
| Results buffer associated with a minibuffer | `M-g M-c` | Return focus to the minibuffer input area |
| Results buffer associated with source CAPF | `q` | Close the results window and return focus to the source buffer |
| Candidate or ordinary target | `C-c .` | Open Embark actions without conflicting with Flyspell's `C-.` and `C-;` |
| Embark action prompt | `SPC` | Select or deselect the current target |
| Embark action prompt | `A` | Apply one chosen action to selected targets, or all targets when none are selected |
| Embark action prompt | `S` | Create a persistent Embark Collect snapshot |
| Embark action prompt | `E` | Export to a specialized buffer such as Dired, Ibuffer, Occur, Grep, or Xref |
| Any active prompt or completion | `C-g` | Cancel and restore the original buffer and point |

`TAB` has a strict contextual contract:

```text
Active completion list     -> select the next candidate
Active Yasnippet field     -> move to the next snippet field
Otherwise                  -> ordinary major-mode indentation
```

The states must be mutually exclusive. The implementation must not depend on
one minor-mode keymap accidentally outranking another.

### Search and navigation

| Key | Command | End-state behavior |
| --- | --- | --- |
| `C-s` | `isearch-forward` | Immediate incremental search in the current buffer without opening a list |
| `SPC /`, `SPC s l` | `consult-line` | Live fuzzy line candidates in `*Completions*` with source preview |
| `SPC s b` | `(consult-line-multi t)` wrapper | Live line search across all open buffers |
| `SPC s g` | `consult-ripgrep` | Live asynchronous project grep using `rg` |
| `SPC s w` | region-or-symbol seeded `consult-ripgrep` wrapper | Search the project for the selected text or symbol at point |
| `SPC ?`, `SPC s h` | `consult-isearch-history` | Reuse a saved search string |
| `SPC s c` | `execute-extended-command` | Select an Emacs command through `*Completions*` |
| `SPC s k` | `consult-yank-from-kill-ring` | Preview and insert an entry from the kill ring |
| `SPC s s` | `consult-imenu` | Live current-document symbols with preview |
| `SPC s S` | `xref-find-apropos` shown by `consult-xref` | Query Eglot workspace symbols, then filter and preview returned locations |

### Retained native navigation

| Key | Command | End-state behavior |
| --- | --- | --- |
| `SPC <RET>` | search-highlight toggle | Show or hide the current Isearch highlight |
| `SPC s H` | `describe-face` | Inspect the face at point; this is not a candidate picker |
| `SPC m`, `SPC s m` | `evil-show-marks` | Open Evil's native marks view |
| `SPC j`, `SPC s j` | `evil-show-jumps` | Open Evil's native jump-list view |

These commands intentionally keep their native Evil or Emacs buffers. Not
every navigation surface becomes a Consult picker merely because Consult is
installed.

### Files, directories, buffers, and SSH

| Key | Discovery mode | End-state behavior |
| --- | --- | --- |
| `C-x C-f`, `SPC f h` | Hierarchical | Open or create a local or TRAMP file one directory level at a time |
| `SPC f f` | Recursive project | Fuzzy project files while respecting project and VCS ignores |
| `C-p`, `SPC f F` | Recursive all-files | Async fuzzy files below the project/default root, including hidden and ignored files |
| `SPC f D` | Recursive current directory | Async fuzzy files below the current file's directory |
| `SPC f o` | Recent | Preview and open `recentf` entries |
| `SPC f r` | Root control | Set the current buffer's `default-directory` to its project/Git root |
| `SPC f d` | Root control | Set the current buffer's `default-directory` to the current file's directory |
| `SPC ,`, `SPC b b` | Buffers | Fuzzy live-buffer selection with preview |
| Active hierarchical or recursive file picker | `C-c C-r` | Suspend the current picker and enter the other discovery mode while preserving root and simple query |
| `SPC f R` | Remote hierarchical | Start `find-file` with `/sshx:` prefilled, then select an SSH host and remote path through `*Completions*` |

Examples:

- `C-x C-f /sshx:omnistation:~/` opens a remote home directory when that
  hostname resolves. Add `Host omnistation` to `~/.ssh/config` if it should be a
  discoverable alias.
- `C-x C-f /sshx:user@machine:/repo/src/` uses an explicit remote user.
- In `/repo/src/mod`, press `C-c C-r` to recursively search below the current
  directory. Canceling returns to the unchanged hierarchical prompt.
- From a recursive remote picker, press `C-c C-r` to return to one-level remote
  path navigation without losing the host prefix.

### Words, spelling, LSP, and diagnostics

| Key | Command | End-state behavior |
| --- | --- | --- |
| `M-/` | `dabbrev-expand` | Insert and cycle buffer-derived word expansions quickly |
| `C-M-/` | `dabbrev-completion` | Show all buffer-derived word candidates in `*Completions*` |
| `M-$` | `ispell-word` | Correct the current misspelling; this is separate from prefix completion |
| `gd`, `SPC s d` | `xref-find-definitions` | Jump or select definitions through `consult-xref` |
| `gD`, `SPC s D` | `eglot-find-declaration` | Jump or select declarations |
| `gi`, `SPC s i` | `eglot-find-implementation` | Jump or select implementations |
| `SPC s t` | `eglot-find-typeDefinition` | Jump or select type definitions |
| `SPC s r` | `xref-find-references` | Filter references and optionally export a persistent Xref buffer |
| `SPC s I` | incoming call hierarchy lambda | Open Eglot's persistent incoming-call hierarchy |
| `SPC s O` | outgoing call hierarchy lambda | Open Eglot's persistent outgoing-call hierarchy |
| `K`, `SPC c h` | `eldoc-doc-buffer` | Show documentation for the symbol at point |
| `SPC c a` | `eglot-code-actions` | Select and apply a contextual LSP operation |
| `SPC c r` | `eglot-rename` | Apply a workspace rename |
| `[d`, `]d`, `SPC d p`, `SPC d n` | Flymake navigation | Move between diagnostics |
| `SPC d f`, `SPC d l` | Flymake diagnostic lists | Open persistent buffer/project diagnostic buffers |

## End-state behavior by domain

| Domain | Candidate producer | Display or result surface | Actions and persistence |
| --- | --- | --- | --- |
| LSP text completion | Eglot CAPF | Live source-backed `*Completions*` | Standard acceptance only, preserving snippets and LSP edits |
| Explicit file path in a source buffer | `my/file-completion-at-point` | `*Completions*` | Standard insertion; Embark generic actions where supported |
| Hierarchical files | `find-file` / `read-file-name` | `*Completions*` | Embark file actions or export to Dired |
| Project files | `project-find-file` | Fuzzy `*Completions*` | Embark file actions or Dired export |
| Recursive all-files | `consult-fd`, remote fallback `consult-find` | Async `*Completions*` with preview | Open file or export candidates to Dired |
| Buffers | `consult-buffer` limited to live-buffer source | `*Completions*` with preview | Embark buffer actions or Ibuffer export |
| Recent files | `consult-recent-file` | `*Completions*` with preview | Open or use Embark file actions |
| Current-buffer lines | `consult-line` | Live `*Completions*` plus source preview | Jump or export to editable Occur |
| Open-buffer lines | `consult-line-multi` | Live `*Completions*` plus cross-buffer preview | Jump or export to Occur |
| Project grep | `consult-ripgrep` | Async live `*Completions*` plus preview | Jump or export to Emacs 31 editable Grep |
| Commands | `execute-extended-command` | Fuzzy `*Completions*` | Embark command actions |
| Kill ring | `consult-yank-from-kill-ring` | `*Completions*` plus insertion preview | Insert selected text |
| Buffer words | Dabbrev | Direct cycle or `*Completions*` | Insert selected word |
| Dictionary words | Ispell CAPF in supported text modes | `*Completions*` | Insert selected word |
| Spelling correction | Ispell/Flyspell | Correction prompt | Replace misspelling; not forced into a generic picker |
| Document symbols | Eglot-backed Imenu plus `consult-imenu` | `*Completions*` plus preview | Jump or export when supported |
| Workspace symbols | Eglot Xref backend plus `xref-find-apropos` | Query, then `consult-xref` locations | Jump or export to Xref |
| Definitions and references | Eglot Xref backend plus `consult-xref` | `*Completions*` for multiple locations | Export to persistent Xref |
| Call hierarchy | Eglot hierarchy UI | Persistent hierarchy buffer | Expand incoming/outgoing call relations |
| Diagnostics | Flymake | Native diagnostic list or optional `consult-flymake` | Persistent Flymake list |
| Build and test errors | Compilation/Ghostel compilation | Compilation buffer | `next-error` / `previous-error` navigation |
| Generic candidate snapshot | Embark Collect | Persistent read-only Collect buffer | Mark and apply actions |

LSP completion items are insertion recipes, not source locations. They must not
be treated as a quickfix list or inserted through a generic Embark action.
Definitions, references, implementations, and diagnostics are locations and
belong in Xref, Flymake, Grep, or Compilation buffers.

## Why Consult is included

Consult is not required for built-in `*Completions*`, Eglot CAPF completion,
ordinary file and buffer prompts, or Embark actions. Those pieces continue to
work without it.

Consult is selected for the recommended end state because the requested live
line search, asynchronous recursive grep and file discovery, source previews,
cancel restoration, unified Xref presentation, and Embark exports need more
than a candidate window. Something must repeatedly produce and replace
candidates as the query changes, start and cancel `rg` or `fd`, ignore stale
process output, attach source locations, and preview the current result.
Consult supplies that controller layer through public Emacs completion APIs,
so its results still appear in the built-in `*Completions*` buffer.

Without Consult, built-in `project-find-file` can still discover project files,
built-in Xref can still present persistent locations, and submit-then-display
commands such as `occur` and `project-find-regexp` still work. What is lost is
the consistent live asynchronous `*Completions*` workflow with preview,
cancellation, and specialized Embark export. Recreating that workflow would
mean maintaining a repository-local asynchronous controller, which is a
completion framework rather than a small `init.el` helper. Consult is the least
invasive choice because it does not replace the display frontend and it is not
placed in Eglot's completion-at-point path.

## Decisive architecture choices

1. Keep built-in `*Completions*`. Do not add Vertico, Corfu, Ivy, Company,
   Orderless, Marginalia, or `live-completions` to this plan.
2. Add `consult`, `embark`, and `embark-consult`. Consult owns live search,
   async subprocesses, previews, and Xref presentation. Embark owns contextual
   actions, selection, Collect, and export.
3. Do not set `completion-in-region-function` to
   `consult-completion-in-region`. Eglot completion remains in the source
   buffer so subsequent text is visible to the language server.
4. Do not add `consult-eglot`. It depends on private Consult and Eglot APIs.
   Public Eglot Xref plus `consult-xref` supplies a stable workspace-symbol and
   location workflow, with the accepted tradeoff that workspace symbols use a
   query followed by result filtering rather than a request per character.
5. Use built-in `flex` only for candidate categories that already possess the
   complete candidate set. Keep hierarchical `file` completion on `basic` and
   `partial-completion` because matching cannot replace recursive discovery.
6. Use `fd` for fast local all-files discovery and `find` for remote/TRAMP
   recursive discovery unless the selected remote host has a validated `fd`.
7. Implement both separate file-picker entry keys and the required in-session
   toggle. Use nested public minibuffer sessions rather than mutating
   `minibuffer-completion-table` or calling private `consult--*` functions.
8. Preserve explicit LSP completion startup. The Neovim configuration also sets
   `autotrigger = false`. One `C-SPC` opens the list; subsequent insertion and
   deletion must refine it without another keypress.
9. Keep built-in Completion Preview disabled. It is an alternative
   one-candidate ghost UI, not a fix for a broken eager list.

## Current codebase context

- `profiles/common/.config/emacs/init.el:2-13` declares the Emacs baseline and
  external setup commands. Add `fd` to the documented local prerequisite when
  recursive all-files discovery is implemented.
- `profiles/common/.config/emacs/init.el:47-49` already selects TRAMP `sshx` and
  disables shared connections through saved customization.
- `profiles/common/.config/emacs/init.el:827-838` owns Yasnippet's key policy and
  deliberately leaves idle `TAB` available to the major mode.
- `profiles/common/.config/emacs/init.el:840-875` owns Eglot and Xref behavior.
- `profiles/common/.config/emacs/init.el:911-945` owns built-in completion,
  eager updates, height, help text, file CAPF ordering, and source keys. The
  working tree already includes the Eglot `flex` correction,
  `completions-max-height` 10, and `completion-show-help` nil. It also sets
  `minibuffer-visible-completions` to `up-down`; Phase 2 removes that
  arrow-navigation composition.
- `profiles/common/.config/emacs/init.el:949-953` persists minibuffer search
  rings and recent files.
- `profiles/common/.config/emacs/init.el:1059-1068` enables Flyspell in text and
  programming modes. Flyspell owns `C-.`, `C-;`, `C-,`, and `C-M-i`, so Embark
  uses `C-c .` and `C-SPC` is the only documented universal CAPF key.
- `profiles/common/.config/emacs/init.el:1099-1163` defines the current static
  Occur, project grep, Imenu, Xref, Flymake, and Gptel leader commands.
- `profiles/common/.config/emacs/init.el:1192-1223` owns leader submaps and the
  current normal/visual `C-p` project-file binding.
- `profiles/common/.config/emacs/init.el:1252-1300` configures TRAMP completion,
  remote paths, copy behavior, and performance.
- `profiles/common/.config/emacs/install-packages.el:8-96` is the only package
  provisioning path. Add Consult, Embark, and Embark Consult here; normal
  startup remains offline.
- `profiles/common/.config/nvim/init.lua:226-257` configures Neovim's explicit
  LSP completion without autotrigger.
- `profiles/common/.config/nvim/init.lua:528-548` uses `C-Space` to request
  completion and conditional `TAB` / `S-TAB` for candidates and snippets.
- `profiles/common/.config/nvim/init.lua:578-632` defines recursive file and
  buffer pickers.
- `profiles/common/.config/nvim/init.lua:661-729` defines live line, grep, and
  LSP entity pickers.
- `dev/plans/emacs-config-changes.md:652-702` previously removed Consult because
  the retained configuration did not need it. The live line/grep and persistent
  export requirements in this plan provide the new, limited justification.

## Known gaps and required diagnoses

### Live line and grep candidates

`occur`, `multi-occur`, and `project-find-regexp` run after the query is
submitted. Built-in `*Completions*` can filter a precomputed line table, but a
complete replacement would still need source preview, restoration on cancel,
async `rg` startup, debounce, cancellation, stale-result suppression, parsing,
and location metadata. Consult already implements those responsibilities and
uses ordinary `completing-read`, so its candidates appear in built-in
`*Completions*`.

Example end state:

```text
SPC s g
type "deprecated_api"
results stream into *Completions*
RET jumps to one result
C-c . E exports the current set to an editable grep-mode buffer
```

### Eglot list requires repeated `C-SPC`

`completion-eager-update` maintains an active completion session but does not
start one. Requiring one `C-SPC` is expected. Requiring another `C-SPC` after
each character is not expected.

Diagnose the actual boundary before adding a hook:

1. Reproduce with one server and record the source position and prefix.
2. Confirm `C-SPC` resolves to `completion-help-at-point`.
3. Check `completion-in-region-mode` immediately after opening the list and
   after each insertion or deletion.
4. Check that `*Completions*` remains visible and that CAPF start/end bounds
   remain valid.
5. Record the first non-nil function in `completion-at-point-functions` before
   and after typing. Temporarily remove `my/file-completion-at-point` to isolate
   CAPF ordering.
6. Reproduce without Evil and Yasnippet.
7. Substitute a fixed synthetic CAPF. If it also becomes stale, the problem is
   the core completion lifecycle rather than Eglot or the server.
8. Inspect `M-x eglot-events-buffer` for `didChange`,
   `textDocument/completion`, cancellation, returned items, and
   `CompletionList.isIncomplete`.
9. Compare `basic` against the `eglot-capf` flex override to separate candidate
   production from filtering.
10. Build a minimal `emacs -Q` reproduction before treating an Emacs 31/Eglot
    interaction as an upstream defect.

Expected LSP behavior:

- A complete server list can be cached and filtered locally.
- A list with `isIncomplete: true` should produce new server requests as the
  source prefix changes.
- Standard completion acceptance must call Eglot's exit function for snippets,
  lazy resolution, text edits, and additional edits.

Do not add polling, `post-command-hook` reinvocation, or advice around private
`completions--*` or `eglot--*` functions until the first failing boundary is
demonstrated.

### Hierarchical versus recursive fuzzy files

Fuzzy filtering and recursive discovery are different. `find-file` lists one
directory level; `flex` can only rank that level. `project-find-file` first
produces all project paths, so flex can match across nested relative paths.
`consult-fd` and `consult-find` stream recursive candidates asynchronously.

The current normal/visual `C-p` is already recursive because it calls
`project-find-file`. The planned `C-p` change is not what makes it recursive;
it changes the candidate universe to match Neovim's `C-p`: hidden and ignored
files below the chosen root are included. `SPC f f` remains the safer
project-aware recursive picker that respects project and VCS ignores.

The current `project-file` category defaults to substring matching in Emacs
31. Configure the relevant categories explicitly:

```elisp
(setq completion-category-overrides
      '((eglot-capf (styles flex))
        (project-file (styles flex))
        (buffer (styles flex))
        (command (styles flex))
        (file (styles basic partial-completion))))
```

Leave Consult location categories on their documented defaults because async
grep input is a search expression, not only a fuzzy filename.

If `C-p` appears directory-bound, verify the actual state before changing code:

- `C-p` is bound to `project-find-file` only in Evil normal/visual states.
- Inspect `default-directory` and `(project-root (project-current t))`.
- Check whether the expected path belongs to `(project-files
  (project-current t))`.
- Use include-all project discovery to distinguish ignore rules from matching.
- Check nested repositories and missing root markers.

### SSH and TRAMP

Current use already goes through built-in `*Completions*`:

```text
C-x C-f
type /sshx:
select a host from SSH configuration or known hosts
type :~/
select one remote directory level at a time
```

Add any stable machine name such as `omnistation` as a `Host` alias in
`~/.ssh/config`; do not hardcode personal hosts in `init.el`. Apply the existing
SSH config completion functions explicitly to both `ssh` and `sshx` and verify
that host completion does not connect to every candidate.

Remote recursive discovery must preserve the full TRAMP prefix. It uses remote
`find` by default. It may use remote `fd` only after checking that executable on
the already selected connection. Local `/opt/homebrew/bin/fd`, local ignore
files, local symlinks, and the local locate database say nothing about a remote
host. The portable remote all-files wrapper uses the equivalent of
`find . -type f ! -path '*/.git/*'`: hidden and VCS-ignored files are included,
`.git` contents are excluded, and symlinked directories are not followed. This
is intentionally different from local `fd --follow`; changing the remote
symlink policy requires an explicit loop-risk decision.

### Embark and multiple targets

Embark can act on a selected minibuffer or `*Completions*` candidate. Direct
marks in the live list can disappear when eager completion rebuilds the buffer.
Use this workflow for stable multi-selection:

```text
open candidates
C-c . S          create an Embark Collect snapshot
C-n/C-p          navigate
C-c . SPC        select targets
C-c . A          choose one action for the selection
```

Prefer `C-c . E` when a specialized destination exists:

| Candidate type | Persistent export |
| --- | --- |
| Files | Dired |
| Buffers | Ibuffer |
| `consult-line` / `consult-line-multi` | Occur |
| `consult-ripgrep` | Grep |
| Xref locations | Xref |
| Generic strings | Embark Collect |

Eglot completion candidates can receive generic or identifier-oriented Embark
actions, but normal completion acceptance remains authoritative. Do not promise
documentation or definition actions for an unaccepted LSP CompletionItem.

## File-picker toggle contract

A live completion table cannot be safely mutated from `read-file-name` into
Consult's async process state. Implement the toggle as nested public sessions:

1. Both hierarchical and recursive entry wrappers establish a buffer-local
   picker kind, root, and toggle keymap.
2. `C-c C-r` captures `minibuffer-contents-no-properties` and suspends the outer
   picker with `enable-recursive-minibuffers` enabled.
3. Hierarchical to recursive splits the entered path with public file-name
   functions. The directory becomes the recursive root and the leaf becomes
   regexp-quoted initial input.
4. Recursive to hierarchical keeps the recursive root and starts nested
   `read-file-name` with simple text inserted by `minibuffer-with-setup-hook`.
5. Canceling the nested picker catches `quit`, resumes the exact outer root and
   input, and refreshes its `*Completions*` with public
   `minibuffer-completion-help` when necessary.
6. Selecting a file records success, exits the nested picker, then aborts the
   suspended outer picker outside the `quit` catcher. Exactly one selected file
   opens.
7. On a TRAMP root, recursive mode selects `consult-find` unless remote `fd` has
   already been validated. The remote prefix is never stripped.

Only plain text transfers losslessly. Consult regexp syntax, split delimiters,
and `--` command options stay in the suspended recursive session; switching to
hierarchical mode starts at the correct root without pretending that those
expressions are literal filename text.

Implement the stateful toggle in
`profiles/common/.config/emacs/my-file-picker.el`, with focused ERT coverage in
`profiles/common/.config/emacs/my-file-picker-test.el`. This separation is
justified by nested-minibuffer lifecycle and cancellation state; simple entry
bindings remain in `init.el`.

## Implementation phases

## Execution status

- Plan ID: `emacs-completion-refinement`
- Status: implementation complete, interactive validation pending
- Next milestone: complete the recorded interactive validation matrix
- Phase 1: implementation complete
- Phase 2: implementation complete, interactive validation pending
- Phase 3: implementation complete, interactive validation pending
- Phase 4: implementation complete, interactive validation pending
- Phase 5: implementation complete, interactive validation pending
- Phase 6: implementation complete, interactive validation pending
- Phase 7: implementation complete, interactive validation pending
- Overall success criteria: batch-validated where recorded; live Eglot,
  Consult, nested minibuffer, and TRAMP behavior remains pending

## Phase 1: Install Embark and Consult without changing CAPF ownership

### Changes

1. Add `consult`, `embark`, and `embark-consult` to the archive package list at
   `profiles/common/.config/emacs/install-packages.el:45-71`.
2. Add lazy `use-package` blocks near
   `profiles/common/.config/emacs/init.el:911-945`.
3. Bind `C-c .` to `embark-act`. Do not bind `C-.`, `C-;`, or `C-,` because
   Flyspell owns them.
4. Load `embark-consult` after both packages so Consult line, grep, and Xref
   candidates export to specialized modes.
5. Set `xref-show-xrefs-function` and `xref-show-definitions-function` to
   `consult-xref`.
6. Keep `completion-in-region-function` unchanged.

### Success criteria

- A clean package provisioning run installs all three packages; a normal Emacs
  startup performs no network access.
- `C-SPC` still calls Eglot or another CAPF in the source buffer.
- `C-c .` acts on file, buffer, command, and ordinary source targets even when
  Flyspell is active.
- Xref with multiple results is displayed through built-in `*Completions*` and
  can export to a persistent Xref buffer.

## Phase 2: Repair live Eglot refinement and normalize completion navigation

### Changes

1. Run the live-refinement diagnosis before changing hooks. Fix only the first
   demonstrated boundary using public Emacs, Eglot, or server behavior.
2. Add the category-specific styles shown above. Preserve hierarchical file
   semantics and the current Eglot flex ordering correction.
3. In `completion-in-region-mode-map`, bind `TAB` and `C-n` to
   `minibuffer-next-completion`, and `S-TAB`, `<backtab>`, and `C-p` to
   `minibuffer-previous-completion`.
4. In `completion-list-mode-map`, retain native TAB/backtab/n/p and add C-n/C-p
   candidate-aware aliases.
5. Set `minibuffer-visible-completions` to nil so Emacs does not compose plain
   arrow-key candidate navigation into minibuffer or source-completion maps.
   Keep `minibuffer-completion-auto-choose` nil.
6. In `minibuffer-local-completion-map`, bind `C-n` and `C-p` to
   `minibuffer-next-completion` and `minibuffer-previous-completion`. Inherited
   require-match and filename prompts receive the same bindings. Preserve
   native TAB prefix completion, directory descent, RET selection, and M-n/M-p
   history.
7. Bind `M-g M-c` to `switch-to-completions` in
   `completion-in-region-mode-map`. Preserve its native reverse direction to
   the minibuffer from `completion-list-mode-map`; use native `q` to return from
   a CAPF result window to the source.
8. Remove `C-M-i` from the documented universal completion contract because
   Flyspell owns it in Flyspell buffers. Keep `C-SPC` universal.

### Success criteria

- Outside completion, TAB indents.
- One `C-SPC` starts LSP completion and every later insertion/deletion refines
  the visible list without another `C-SPC`.
- Complete server results filter locally; incomplete results issue valid fresh
  requests.
- Candidate acceptance preserves plain insertions, snippets, `textEdit`, and
  `additionalTextEdits`.
- In active source completion, TAB/S-TAB and C-n/C-p navigate and RET accepts
  only a selected candidate.
- While typing in a completion minibuffer, C-n/C-p navigate candidates without
  moving point into `*Completions*`; plain arrow keys retain ordinary
  minibuffer movement or history behavior.
- In file minibuffers, TAB completes prefixes and descends directories.
- Accepting an Eglot snippet starts Yasnippet; TAB/S-TAB then traverse snippet
  fields.
- Buffer, command, project-file, and Eglot candidates exhibit the intended
  fuzzy ranking without changing hierarchical file discovery.
- No private-function advice, polling hook, or Consult CAPF adapter is added.

### Execution notes

- Emacs 31.1 already enables `completion-in-region-mode` and its public eager
  update path after source edits. Eglot reuses only complete candidate sets and
  requests incomplete sets again, so no refresh hook, advice, polling, or
  Consult CAPF adapter was added.
- Batch validation confirmed initial synthetic CAPF activation, category
  configuration, and source, list, require-match, and filename keymaps. The
  post-edit idle-timer behavior and server-specific LSP edit forms remain in
  the interactive validation matrix because batch mode does not drive those
  timers representatively.

## Phase 3: Add live line search, grep, buffers, and persistent exports

### Changes

1. Replace `occur` at `SPC /` and `SPC s l` with `consult-line`.
2. Replace `multi-occur` at `SPC s b` with a direct wrapper around
   `(consult-line-multi t)`.
3. Replace `project-find-regexp` at `SPC s g` with `consult-ripgrep`.
4. Replace `my/project-find-regexp-at-point` with a region-or-symbol wrapper
   that seeds public `consult-ripgrep` input.
5. Add `consult-isearch-history`, `consult-yank-from-kill-ring`,
   `consult-buffer`, `consult-recent-file`, and `consult-imenu` bindings from the
   key table.
6. Limit `consult-buffer` to live-buffer sources so recent files remain in the
   dedicated recent-file command.
7. Retain `occur`, `multi-occur`, and `project-find-regexp` as `M-x` fallbacks.

### Success criteria

- Every line-search character updates `*Completions*` and previews the matching
  source line.
- Every project-grep edit cancels stale `rg` work and streams current results.
- Cancel restores the original buffer and point.
- `C-c . E` exports line results to Occur and grep results to Grep.
- Emacs 31 `occur-edit-mode` and `grep-edit-mode` work without Wgrep.
- Visual `SPC s w` seeds from the selection; normal-state use seeds from the
  symbol at point.

### Execution notes

- Consult now owns the leader-facing live search, buffer, recent-file, command,
  kill-ring, and Imenu entry points. The native `occur`, `multi-occur`, and
  `project-find-regexp` commands remain unchanged as direct fallbacks.
- Offline configuration loading and focused wrapper tests cover the keymap,
  all-buffer scope, region and symbol seeding, regexp quoting, and mark
  deactivation. Live preview restoration, asynchronous process cancellation,
  and specialized Embark export remain in the interactive validation matrix.

## Phase 4: Add explicit recursive file modes and SSH entry

### Changes

1. Add `fd` to the documented external prerequisites and macOS provisioning in
   `provision/local/macos`. Keep `find` as the portable fallback.
2. Bind `SPC f f` to `project-find-file` with fuzzy `project-file` ranking.
3. Add local `consult-fd` wrappers for all-files project/default-root search and
   current-buffer-directory search. Use public wrapper-local arguments for
   `--hidden --no-ignore --follow --type f --exclude .git` in all-files mode.
4. Bind `C-p` and `SPC f F` to all-files recursive search, and `SPC f D` to
   current-buffer-directory recursive search.
5. Keep `C-x C-f` and add `SPC f h` for hierarchical open/create.
6. Preserve `SPC f r` for setting the current buffer's root, add `SPC f d` for
   setting its current file directory, and add `SPC f R`, a thin `find-file`
   entry that prefills `/sshx:` without hardcoding a host.
7. Apply SSH config host completion to both `ssh` and `sshx` at
   `profiles/common/.config/emacs/init.el:1252-1257`.

### Success criteria

- `SPC f f` finds nested project files by fuzzy basename while respecting
  ignores.
- `C-p` and `SPC f F` find hidden/ignored nested files without entering their
  directories manually.
- `SPC f D` searches below the current file's directory without changing
  `default-directory` globally.
- `C-x C-f` remains able to create a new local or remote path.
- `/sshx:` lists configured SSH aliases in `*Completions*` without probing every
  host.
- A selected remote host completes one remote directory level at a time.

### Execution notes

- The include-all `fd` arguments are dynamically scoped to the two local
  recursive wrappers, leaving project-aware and other Consult commands on their
  own discovery contracts. Both wrappers reject TRAMP paths until Phase 5
  supplies the remote implementation.
- Offline assertions cover project, default, and current-file roots, exact
  include-all arguments, remote guards, directory setters, leader bindings,
  SSH and SSHX completion registration, and the prefilled `/sshx:` hierarchical
  prompt. Candidate UI and live remote connections remain interactive checks.

## Phase 5: Implement the bidirectional file-picker toggle

### Changes

1. Add `profiles/common/.config/emacs/my-file-picker.el` with the public nested
   minibuffer design in the toggle contract.
2. Add entry wrapper context and a buffer-local `C-c C-r` toggle map to both
   hierarchical and recursive sessions.
3. Preserve exact outer session state on cancel and terminate both sessions
   after one successful selection.
4. Transfer simple leaf input between modes and preserve root only for Consult
   regexp/options syntax that is not a literal path.
5. Choose local `consult-fd`, remote `consult-find`, or remote `consult-fd` only
   after validating the executable on the selected connection. Bind the remote
   `consult-find` wrapper to the documented files-only, hidden-inclusive,
   ignored-inclusive, `.git`-excluding, no-symlink-following arguments.
6. Add `profiles/common/.config/emacs/my-file-picker-test.el` with nested
   session and TRAMP-name fixtures.

### Success criteria

- `C-c C-r` works in both directions.
- Simple root and query text transfer in both directions.
- Cancel restores exact host, directory, query, and candidates.
- Successful selection opens exactly one file and leaves no suspended
  minibuffer.
- Remote mode never runs a local recursive executable against a TRAMP path.
- Remote all-files mode includes hidden and VCS-ignored files, excludes `.git`
  directories and contents, and does not follow symlinked directories.
- Paths with spaces, `~`, absolute roots, explicit remote users, and missing
  remote `fd` behave correctly.

### Execution notes

- File-picker state now lives in `my-file-picker.el`. A dynamically shared
  transaction cell propagates a nested success through suspended prompts,
  while a nested quit leaves the outer minibuffer intact and refreshes its
  public completion display.
- Eight focused ERT tests cover both toggle directions, one-open success,
  cancellation restoration, literal and Consult query transfer, public
  `read-file-name` initial arguments, local and remote backend choice, explicit
  remote users, missing remote `fd`, `.git` pruning, hidden files, and remote
  symlink non-traversal. Live Consult processes and real TRAMP connections
  remain in the interactive validation matrix.

## Phase 6: Complete LSP entity routing

### Changes

1. Route document symbols to `consult-imenu`.
2. Keep workspace symbols on public `xref-find-apropos` and display returned
   locations through `consult-xref`.
3. Keep existing Eglot/Xref definition, declaration, implementation, type,
   reference, code action, rename, ElDoc, and Flymake commands.
4. Split incoming and outgoing hierarchy leader bindings with direct
   interactive lambdas. Do not add trivial one-use helpers.

### Success criteria

- Definitions, references, and workspace symbols can export to Xref.
- Incoming and outgoing call hierarchy commands show the requested direction.

### Execution notes

- Document and workspace symbols retain the public Consult Imenu and Xref
  routes. The two call-hierarchy bindings now pass Emacs 31.1 Eglot's explicit
  `incoming` and `base` direction values directly, with no one-use helper.
- Offline keymap assertions and a stubbed public Eglot call verify both
  directions while the existing definition, declaration, implementation, type,
  reference, action, rename, ElDoc, and Flymake bindings remain unchanged.

## Phase 7: Complete word, spelling, and Embark multi-target workflows

### Changes

1. Keep `M-/` as quick `dabbrev-expand` and add `C-M-/` for
   `dabbrev-completion` through `*Completions*`.
2. Verify Text mode's Ispell completion-at-point source and keep `M-$` for
   correction.
3. Add a dedicated spelling CAPF command only if dictionary completion inside
   programming comments is a demonstrated requirement. Do not reorder Ispell
   ahead of Eglot globally.
4. Validate Embark select, act-all, Collect, and specialized exports in direct
   and minibuffer completion contexts.

### Success criteria

- Word cycling and list selection both work.
- Dictionary completion works in supported prose modes.
- Spelling correction remains available under Flyspell.
- Stable multi-selection occurs in Embark Collect rather than relying on marks
  surviving live `*Completions*` regeneration.
- Generic Embark insertion never replaces Eglot's completion acceptance path.

### Execution notes

- `C-M-/` now exposes Dabbrev candidates through built-in completion while
  `M-/` retains direct cycling. Emacs 31.1 already installs
  `ispell-completion-at-point` in Text mode at hook depth 10 and keeps `M-$` on
  `ispell-word`; no programming-comment spelling source was required.
- Installed Embark defaults already provide `SPC`, `A`, `S`, and `E` for
  selection, act-all, Collect, and export, including specialized file, buffer,
  Consult location, grep, and Xref exporters. Offline assertions confirm that
  completion acceptance remains owned by the built-in completion function.

## Overall success criteria

The implementation is complete, but these criteria are not complete until the
live checks in the validation matrix pass, especially Eglot refinement,
Consult preview and cancellation, nested minibuffer restoration, and real
TRAMP sessions.

- Built-in `*Completions*` is the only candidate list across CAPF, minibuffer,
  Consult search, files, buffers, and navigation commands.
- Search and grep are live, previewable, cancellable, and exportable.
- Hierarchical file traversal, recursive fuzzy discovery, separate entry keys,
  and a bidirectional in-session toggle all work locally and through TRAMP.
- The key contract matches Neovim where context permits, while preserving file
  descent, indentation, snippets, and minibuffer history.
- Eglot completion refines after one explicit request and retains full LSP edit
  semantics.
- Embark provides contextual single-target actions, stable collected
  multi-selection, and specialized persistent exports.
- LSP locations use Xref/Flymake/hierarchy buffers rather than pretending that
  completion items are quickfix entries.
- Normal startup remains offline, and all package/external prerequisites are
  reproducibly documented or provisioned.

## Validation matrix

### Static and batch checks

- Run `check-parens` on every changed Emacs Lisp file.
- Byte-compile new local modules to a temporary output directory.
- Run focused ERT for the picker toggle.
- Load `init.el` in Emacs 31.1 batch mode after isolated package provisioning.
- Run `git diff --check`.
- Assert every planned command and keymap binding resolves after lazy packages
  load.

### Interactive completion checks

- `C-SPC` with a plain Eglot candidate, snippet, `textEdit`, and
  `additionalTextEdits`.
- Continued insertion and deletion after one `C-SPC`.
- `./`, `../`, `~/`, and absolute path completion in a source buffer.
- `C-x C-f` directory descent and new-file creation.
- TAB/S-TAB, C-n/C-p, RET, M-RET, cancel, and direct-list navigation.
- Active snippet field traversal after accepting an Eglot snippet.
- Dabbrev cycle/list and Ispell completion/correction.

### Interactive search and export checks

- `consult-line`, `consult-line-multi`, and `consult-ripgrep` with built-in eager
  `*Completions*` and no Vertico/Icomplete.
- Cancel restoration and source preview cleanup.
- Embark single action, selection, act-all, Collect, and export.
- Occur/Grep edit modes, Xref persistence, Dired, Ibuffer, Flymake, and
  Compilation `next-error` navigation.

### File and TRAMP checks

- Project respected-ignore and include-all candidate domains.
- Local all-files and current-directory scopes, hidden paths, ignored paths,
  symlinks, and `.git` exclusion.
- Both toggle directions, cancel in both nested modes, selection in both modes,
  empty input, partial subdirectory, spaces, and Consult split syntax.
- `/sshx:` host candidates without speculative connections.
- Remote one-level completion, remote recursive find, remote project files,
  cancel restoration, explicit users, reauthentication, and remote fd fallback.
- Remote all-files inclusion of hidden and ignored files, `.git` exclusion, and
  non-traversal of symlinked directories.

## Risks and constraints

- `consult-ripgrep` depends on `rg`; local `consult-fd` depends on `fd`; remote
  execution depends on tools installed on the selected host.
- Recursive include-all discovery can traverse large generated trees and
  symlink cycles. Bound the root and exclude VCS metadata.
- `project-find-file` follows the current buffer's project root, while Neovim's
  picker follows its explicit global cwd. Key labels and prompts must display
  the actual root.
- Nested picker query transfer is intentionally partial between literal paths
  and Consult regexp/options syntax.
- Previewing remote or very large files can be expensive. Use Consult's public
  preview customization if measured, not custom process internals.
- Eager live completion can trigger expensive incomplete LSP requests. Inspect
  Eglot events before treating latency as a stale-list defect.
- Direct Embark marks in `*Completions*` are not durable across eager rebuilds.
- Flyspell minor maps override global punctuation keys; use the conflict-free
  `C-c .` binding.

## References

- Emacs completion commands: https://www.gnu.org/software/emacs/manual/html_node/emacs/Completion-Commands.html
- Emacs completion styles: https://www.gnu.org/software/emacs/manual/html_node/emacs/Completion-Styles.html
- Completion-at-point contract: https://www.gnu.org/software/emacs/manual/html_node/elisp/Completion-in-Buffers.html
- File-name completion: https://www.gnu.org/software/emacs/manual/html_node/elisp/File-Name-Completion.html
- Project file commands: https://www.gnu.org/software/emacs/manual/html_node/emacs/Project-File-Commands.html
- Consult: https://github.com/minad/consult
- Embark: https://github.com/oantolin/embark
- Embark Consult: https://elpa.gnu.org/packages/embark-consult.html
- Eglot manual: https://www.gnu.org/software/emacs/manual/html_mono/eglot.html
- Xref: https://www.gnu.org/software/emacs/manual/html_node/emacs/Xref.html
- Flymake: https://www.gnu.org/software/emacs/manual/html_node/flymake/
- Occur: https://www.gnu.org/software/emacs/manual/html_node/emacs/Other-Repeating-Search.html
- Grep and Grep Edit: https://www.gnu.org/software/emacs/manual/html_node/emacs/Grep-Searching.html
- Dired: https://www.gnu.org/software/emacs/manual/html_node/emacs/Dired.html
- Ibuffer: https://www.gnu.org/software/emacs/manual/html_node/emacs/Buffer-Menus.html
- Dynamic abbrevs: https://www.gnu.org/software/emacs/manual/html_node/emacs/Dynamic-Abbrevs.html
- Spelling: https://www.gnu.org/software/emacs/manual/html_node/emacs/Spelling.html
- LSP CompletionItem: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#completionItem
- TRAMP file syntax: https://www.gnu.org/software/emacs/manual/html_node/tramp/File-name-syntax.html
- TRAMP completion: https://www.gnu.org/software/emacs/manual/html_node/tramp/File-name-completion.html
- TRAMP package integration: https://www.gnu.org/software/emacs/manual/html_node/tramp/External-packages.html
- fd hidden and ignored files: https://github.com/sharkdp/fd#hidden-and-ignored-files
