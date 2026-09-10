# Emacs Completion Refinement Part 2

This native-only design is superseded for implementation by
`dev/plans/9-emacs-completion-refinment-pt2-toggle-completions.md`. Preserve
this document as a design record; its Phase statuses remain pending.

## Final Completion Stack

The finished common Emacs profile uses one completion frontend wherever Emacs
completion APIs apply:

```text
In-buffer completion
  -> Eglot, file, Dabbrev, Ispell, or major-mode CAPF
  -> built-in completion engine and category-specific matching styles
  -> native *Completions*
  -> native candidate acceptance

Minibuffer completion
  -> completing-read, read-file-name, project, or command completion table
  -> built-in completion engine
  -> native *Completions*
  -> native acceptance or Embark action

Live search and navigation
  -> Consult file, line, buffer, ripgrep, recent-file, Imenu, or Xref command
  -> built-in completing-read
  -> native *Completions*
  -> preview, jump, Embark Collect, or Embark Export

Persistent result surfaces
  -> Embark Collect for a stable candidate snapshot
  -> Embark Export for specialized Dired, Ibuffer, Occur, Grep, or Xref output
  -> native Eglot, Flymake, Evil marks, and Evil jumps buffers where those
     commands already provide the correct persistent interface
```

Stack ownership is explicit:

| Layer | Final owner | Contract |
| --- | --- | --- |
| Candidate production | CAPFs, `fd`, `rg`, project.el, Xref, Eglot | Each source owns candidate discovery and domain semantics. |
| Completion engine | Built-in Emacs completion | `basic`, `partial-completion`, and `flex` remain category-specific. |
| Candidate frontend | Native `*Completions*` | This is the only completion-list frontend for CAPF, minibuffer, Consult, file, buffer, and Xref selection. |
| Live search adapter | Consult | Consult owns asynchronous processes, refresh, preview, cancellation, and result lookup. |
| Actions and persistence | Embark and `embark-consult` | Embark owns actions, Collect snapshots, and specialized exports. |
| Reusable command options | Transient | Transient stores validated options for files, buffers, lines, and ripgrep. It is not a completion frontend. |

Ivy, Counsel, and the Emacs fzf adapter are removed. Consult, Embark,
`embark-consult`, and Transient remain. Do not add Vertico, Corfu, Company,
Orderless, Marginalia, Cape, or another completion frontend.

### In-buffer completion

`C-SPC` continues to display completion-at-point candidates. Eglot, the
repository file CAPF, Dabbrev completion, Ispell, and major modes continue to
provide candidates through the standard CAPF contract configured at
`profiles/common/.config/emacs/init.el:481-600`.

- Point and editable text remain in the source buffer.
- Candidates appear in native `*Completions*`; Completion Preview remains
  disabled.
- `TAB` and `C-n` move forward, while `S-TAB`, `<backtab>`, and `C-p` move
  backward while completion-in-region is active.
- `M-g M-c` focuses the associated `*Completions*` window.
- `C-q` creates an Embark Collect snapshot of displayed candidates.
- Native candidate acceptance remains responsible for Eglot `textEdit`,
  `additionalTextEdits`, snippets, and completion exit functions.
- `M-/` remains direct `dabbrev-expand`; `C-M-/` remains
  `dabbrev-completion` through the native completion frontend.

Do not replace `completion-in-region-function` with Consult or an alternate
frontend. Consult produces search and navigation candidates; it does not own
in-buffer insertion.

### Minibuffer completion

All ordinary `completing-read`, buffer, command, project, and file prompts use
native `*Completions*` under the configuration at
`profiles/common/.config/emacs/init.el:481-575`.

- `C-n` and `C-p` move the selected candidate without replacing editable
  minibuffer input.
- `TAB` retains native prefix completion and directory descent for file names.
- `RET` accepts a valid candidate or valid literal input according to the
  prompt's require-match contract.
- `S-RET` uses `minibuffer-complete-and-exit`, the public validated exit path.
  It may submit literal text in permissive prompts and must not bypass a
  must-match prompt.
- `C-q` collects the displayed candidate set.
- `C-c .` opens Embark actions.
- Global `C-q` remains `quoted-insert` outside active completion contexts.
- Minibuffer `M-n` and `M-p` remain history navigation. The planned `M-p`
  file-options binding is limited to Evil normal and visual states.

The Emacs 31 native completion collector at
`profiles/common/.config/emacs/init.el:501-546` remains until a real
completion-list test proves that the installed Embark collector no longer
enters its non-terminating traversal. Do not replace a working compatibility
boundary based only on package source inspection.

### Files, C-x C-f, and recursive discovery

`C-x C-f` and `SPC f h` remain hierarchical open-or-create commands backed by
`read-file-name` through `my/find-file` at
`profiles/common/.config/emacs/my-file-picker.el:158-168,243-262`. They show
one directory level at a time in native `*Completions*`, support local and
TRAMP paths, and retain literal file creation. `C-c C-r` continues to switch
between hierarchical and recursive discovery without losing the root or a
transferable literal query.

Recursive file discovery uses public `consult-fd` locally and on remote hosts
where remote `fd` exists. The existing portable `consult-find` fallback
remains for remote hosts without `fd`. Results appear in native
`*Completions*` and use native Embark file actions.

The final direct and configurable file bindings are:

| Binding | Final behavior |
| --- | --- |
| `C-x C-f`, `SPC f h` | Hierarchical local or TRAMP open/create through native file completion. |
| `SPC f f` | Project file selection through project.el and native completion. |
| `C-p`, `SPC f p` | Run recursive Consult file discovery immediately with saved/default options. |
| `M-p`, `SPC f P` | Open the recursive file options Transient. |
| `SPC f F` | Retain the explicit recursive all-files command and its existing universe. |
| `SPC f D` | Retain recursive search below the current file's directory. |
| `SPC f R` | Retain hierarchical `/sshx:` entry. |
| `SPC f o` | Recent-file selection through Consult and native completion. |

Remove `C-S-p`. `SPC f P` is the portable canonical options binding and
`M-p` is the direct normal/visual companion to `C-p`.

The file options Transient controls project versus current-directory root,
hidden files, ignored files, symlink following, and insensitive, smart, or
sensitive case. Defaults remain project root, hidden and ignored files
included, symlinks not followed, `.git` excluded, and case insensitive.

Case choices apply to local or remote `fd`. The portable remote `find`
fallback remains case insensitive because portable `find` implementations do
not share one reliable sensitive/smart-case interface. If smart or sensitive
case is selected for a remote host without `fd`, stop with a clear user error
instead of silently ignoring the saved option. Hidden files remain naturally
included by `find`; ignore-file semantics remain unavailable on that fallback.

### Fuzzy matching and streaming

The final stack distinguishes bounded fuzzy matching from external recursive
search:

- Built-in `flex` remains the fuzzy matcher for bounded Eglot, project-file,
  buffer, command, line, and other applicable completion categories at
  `profiles/common/.config/emacs/init.el:481-486`.
- Hierarchical file-name completion remains `basic` plus
  `partial-completion`, preserving path-component and TRAMP behavior.
- `consult-fd` streams recursive file matches as `fd` produces them. With
  `consult-async-split-style` set to nil, the entire query is sent to `fd`;
  this provides live unordered path regexp matching, not fzf subsequence
  scoring or globally fzf-ranked output.
- `consult-ripgrep` streams matching lines as line-buffered `rg` output
  arrives. It performs content regexp or fixed-string search, not fuzzy
  ranking.

The plan intentionally chooses streaming, one native completion frontend, and
reliable Embark integration over exact fzf ranking. Sorted `fzf --filter`
waits for its producer to finish before emitting globally ranked results.
Adding Consult around that pipeline cannot make it stream. `fzf --no-sort`
can stream, but it removes the ranking that justified the additional stack.
Do not introduce private `consult--async-*` integration to recreate a partial
fzf adapter.

### Search, selection, and navigation matrix

Every currently configured search or selection form has an explicit final
surface and case contract:

| Binding | Domain | Final surface | Options and persistence |
| --- | --- | --- | --- |
| `C-s` | Incremental current-buffer text search | Native Isearch in the source buffer, not `*Completions*` | Insensitive by default; native in-session case toggle remains available. |
| Evil `/`, `?`, `*`, `#`, `n`, `N` | Evil current-buffer search and repeat | Evil search overlays and search history, not `*Completions*` | `evil-ex-search-case` is insensitive by default; inline Evil case escapes remain authoritative. |
| `SPC /`, `SPC s l` | Current-buffer line search | `consult-line`, native `*Completions*`, live preview | Saved line options; `SPC s L` opens the menu. |
| `SPC s b` | Multi-buffer line search | `consult-line-multi`, native `*Completions*`, live preview | Saved case and buffer-scope options; `SPC s B` opens the menu. |
| `SPC s g` | Project/default-root content search | `consult-ripgrep`, native `*Completions*`, streamed `rg` output | Saved ripgrep options; `SPC s G` opens the menu. |
| `SPC s w` | Region-or-symbol seeded content search | The same Consult ripgrep route with preserved seed | Shares ripgrep settings; `SPC s W` opens the same menu. |
| `C-x b`, `SPC ,`, `SPC b b` | Buffer selection | `consult-buffer`, native `*Completions*` | Saved case and scope; all means the current live-buffer-only source, while project intentionally uses `consult-project-buffer` and its project buffers, project recent files, and project-root sources. `SPC b B` opens the menu. |
| `SPC ?`, `SPC s h` | Isearch history | `consult-isearch-history`, native `*Completions*` | Inherits the common completion case policy; no empty menu. |
| `SPC s c`, `M-x` | Command selection | Built-in command completion, native `*Completions*` | Inherits command `flex` and common case; no menu. |
| `SPC s k` | Kill-ring selection | `consult-yank-from-kill-ring`, native `*Completions*`, preview | Inherits common case; no persistent backend options. |
| `SPC s s` | Current-buffer symbols | `consult-imenu`, native `*Completions*`, preview | Inherits common case and Consult narrowing; no menu. |
| `SPC s S` | Xref apropos | Xref backend with `consult-xref` result presentation | Backend owns query semantics; no menu. This existing uppercase command prevents an `s`/`S` menu pair. |
| `gd`, `SPC s d`, `C-c e d` | Definitions | Xref/Eglot, with Consult for multiple Xref results | Language server or Xref backend owns query case; no menu. |
| `gD`, `SPC s D`, `C-c e D` | Declarations | Eglot/Xref, with Consult for multiple results | Backend-owned semantics; existing uppercase semantic binding remains. |
| `gi`, `SPC s i` | Implementations | Eglot/Xref, with Consult for multiple results | Backend-owned semantics; no menu. |
| `SPC s r`, `C-c e R` | References | Xref/Eglot, with Consult for multiple results | Backend-owned semantics; no menu. |
| `SPC s t`, `C-c e t` | Type definitions | Eglot/Xref, with Consult for multiple results | Backend-owned semantics; no menu. |
| `SPC s I`, `SPC s O` | Call hierarchies | Native Eglot hierarchy buffers | Already persistent and backend-owned; no menu. |
| `SPC m`, `SPC s m` | Evil marks | Native Evil marks view | No matching or menu. |
| `SPC j`, `SPC s j` | Evil jumps | Native Evil jumps view | No matching or menu. |
| `SPC f o` | Recent files | `consult-recent-file`, native `*Completions*` | Inherits file case; no separate scope options. |
| `K`, `SPC c h`, `C-c e h` | Symbol documentation | Native ElDoc buffer | Backend-owned lookup with a persistent documentation buffer; no menu. |
| `SPC s H` | Face lookup | Native Help buffer | Direct lookup with a persistent Help buffer; no menu. |
| `[d`, `]d`, `SPC d p`, `SPC d n` | Previous or next diagnostic | Native Flymake navigation | Direct navigation over current diagnostic state; no completion or menu. |
| `SPC d f`, `SPC d l` | Buffer or project diagnostics | Native Flymake diagnostic list | Already persistent; no completion or menu. |

Lowercase runs immediately and uppercase opens options only for configurable
families: files (`p`/`P`), lines (`l`/`L`, `b`/`B`), ripgrep (`g`/`G`,
`w`/`W`), and buffers (`b`/`B` inside the buffer namespace). Commands whose
scope is intrinsic, whose options already exist in-session, or whose semantics
belong to a language server do not receive empty Transients.

### Case behavior

Case-insensitive matching is the code default at every layer owned by the
profile:

- `completion-ignore-case` is non-nil for generic and Consult-backed
  completion filtering.
- `read-buffer-completion-ignore-case` is non-nil for buffer completion.
- `read-file-name-completion-ignore-case` is non-nil on every platform.
- `case-fold-search` is non-nil and `search-upper-case` is nil so uppercase
  Isearch input does not silently enable sensitive matching.
- `evil-ex-search-case` is `insensitive` for Evil `/`, `?`, `*`, and `#`.
- Local and remote `consult-fd` calls pass an explicit fd case flag.
- The portable remote `consult-find` fallback is explicitly insensitive. It
  rejects smart or sensitive saved modes rather than pretending to honor them.
- `consult-ripgrep` calls pass an explicit rg case flag rather than inheriting
  Consult's upstream `--smart-case` default.
- Xref and Eglot backend queries retain backend-defined case semantics. Only
  selection among returned candidates follows the native completion policy.

File, line, multi-buffer line, ripgrep, and buffer Transients expose a
sensitive override. File and ripgrep menus may also expose smart case because
`fd` and `rg` implement it directly. The remote portable `find` limitation is
reported before search starts. Saved overrides apply only to the associated
command family and do not mutate unrelated global completion state.

### Collect and export

`C-q` always means Embark Collect when a native completion UI is active. It
creates a stable snapshot of candidates currently known to the completion
session; it does not wait for an external producer to finish. This makes
incremental Consult file and ripgrep output essential for useful collection
during long searches.

Embark's export action remains available for specialized persistent results:

- files export to Dired;
- buffers export to Ibuffer;
- line searches export to Occur where supported;
- ripgrep exports to Grep through `embark-consult`;
- Xref candidates export to an Xref result buffer where supported.

Consult preview remains command-local. Do not restore the global
`consult-preview-at-point-mode` completion-list hook. Keep
`consult-async-split-style` nil so `#` and other punctuation remain ordinary
query text.

## Status

- Overall: planned
- Current milestone: Phase 1
- Commit policy: one new Git commit after each accepted Phase

Phase status:

- Phase 1: pending
- Phase 2: pending
- Phase 3: pending
- Phase 4: pending
- Phase 5: pending

## Goal

Consolidate in-buffer completion, minibuffer completion, file discovery, line
search, content search, buffer selection, and navigation on native
`*Completions*`, Consult, and Embark. Remove the Ivy/Counsel/fzf exception,
stream long-running external results, make case-insensitive matching explicit
and overridable, and add consistent lowercase immediate and uppercase options
bindings for configurable search families.

## Current Codebase Context

- `profiles/common/.config/emacs/init.el:443-635` configures Consult, Counsel,
  Embark, native completion, CAPF, line search, and ripgrep wrappers.
- `profiles/common/.config/emacs/init.el:1832,1893-1971,2100-2102` owns
  `C-x C-f`, Isearch, leader search bindings, and the current C-p/C-S-p pair.
- `profiles/common/.config/emacs/my-file-picker.el:1-379` owns hierarchical,
  recursive, project, TRAMP, fzf, Transient, toggle, and Evil jump behavior.
- `profiles/common/.config/emacs/install-packages.el:53-83` provisions
  Consult, Counsel, Ivy, Embark, and `embark-consult`.
- `profiles/common/.config/emacs/appearance-test.el:456-608` covers native
  completion, candidate navigation, and Collect.
- `profiles/common/.config/emacs/my-file-picker-test.el:1-631` covers file
  routing, picker toggles, Transient settings, Collect, and Evil jumps.
- `profiles/common/.config/emacs/leader-bindings-test.el:1-370` covers leader,
  state, and Which Key behavior.
- `profiles/common/.config/emacs/gui-smoke-test.el:23-120` exercises C-p,
  ripgrep, C-x C-f, and Evil jump integration with mocked prompt boundaries.
- `dev/plans/emacs-completion-refinment.md` documents the original native
  completion contract.
- `dev/plans/8-emacs-refinment.md:353-458` documents the current fzf
  Transient and native Collect follow-ups that this plan supersedes only where
  explicitly stated.

## Decisions

1. Keep native `*Completions*`, Consult, Embark, and `embark-consult` as the
   completion and action architecture.
2. Remove Ivy, Counsel, and fzf from the Emacs completion path. Do not add a
   replacement completion frontend.
3. Choose streamed `consult-fd` results over exact fzf ranking. Do not describe
   fd regexp matching as fzf-equivalent fuzzy ranking.
4. Keep `C-x C-f` hierarchical, create-capable, local/TRAMP-aware, and native.
5. Make case-insensitive behavior explicit across native completion, Isearch,
   Evil search, fd, and rg. Keep family-local overrides.
6. Make lowercase configurable leader commands execute immediately and their
   uppercase counterparts open Transient options.
7. Give menus only to file, buffer, line, and ripgrep families with meaningful
   reusable settings. Cover every other search form explicitly without adding
   empty menus.
8. Keep `C-q` as Collect, retain Embark Export for specialized result buffers,
   and preserve global `quoted-insert` outside completion.
9. Preserve TRAMP fallback behavior, literal file creation, picker toggling,
   cancellation, and accepted-only Evil jump recording.
10. Integrate through public Consult commands and documented dynamically bound
    argument variables. Do not add new `consult--*` dependencies.
11. Make incompatible symbol and binding changes directly. Do not add aliases
    for the removed fzf commands.

## Dependency Graph

```text
Phase 1 native case and completion contract
  -> Phase 2 streaming file discovery and stack removal
  -> Phase 3 line and buffer options
  -> Phase 4 ripgrep and complete search coverage
  -> Phase 5 aggregate validation and documentation
```

## Phase 1: Establish the Native Completion and Case Contract

### Changes

1. In `profiles/common/.config/emacs/init.el:443-600`, retain the native
   `*Completions*` settings, category-specific completion styles, editable
   selection, disabled Completion Preview, and native C-q routing. Replace the
   direct S-RET `exit-minibuffer` binding with
   `minibuffer-complete-and-exit`, so explicit submission follows the public
   require-match-aware exit path.
2. Set explicit insensitive defaults for generic, buffer, and file completion.
   Set native Isearch and Evil search to remain insensitive even when a query
   contains uppercase characters.
3. Preserve `basic` plus `partial-completion` for hierarchical files. Preserve
   `flex` for Eglot CAPF, project files, buffers, commands, and applicable
   bounded candidate sets.
4. Verify the installed Embark collector against real Emacs 31.1 minibuffer,
   completion-at-point, and focused `*Completions*` sessions. Retain
   `my/completion-list-candidates` if the upstream traversal still does not
   terminate; remove it only if behavioral tests prove the workaround is no
   longer necessary.
5. Keep `consult-async-split-style` nil and confirm `#` remains literal for
   recursive file and ripgrep queries.
6. Extend `profiles/common/.config/emacs/appearance-test.el` with behavioral
   mixed-case CAPF, buffer, filename, Isearch, and Evil search cases. Add
   permissive and must-match S-RET cases. Do not test source-code text
   existence.

### Success Criteria

- CAPF and minibuffer candidates use native `*Completions*` only.
- Differently cased generic, buffer, and file candidates match by default.
- Uppercase Isearch and Evil search input remains case insensitive.
- Eglot completion acceptance retains source-owned insertion behavior.
- C-n/C-p selection does not replace editable minibuffer input.
- S-RET accepts literal input in a permissive prompt and refuses invalid input
  in a must-match prompt.
- C-q collection and ordinary global C-q behavior remain correct.
- Literal `#` queries remain literal.

## Phase 2: Replace Counsel fzf with Streaming Consult File Discovery

### Changes

1. In `profiles/common/.config/emacs/my-file-picker.el`, replace
   `my/find-file-fzf-root` with a directly named recursive Consult command.
   Extend the existing recursive-session path at lines 170-187 to accept the
   saved file options without changing the fixed behavior of unrelated file
   entry points.
2. Use a dynamic `consult-fd-args` binding and public `consult-fd` for local
   discovery. Preserve regular files only, `.git` exclusion, and the selected
   hidden, ignored, symlink, and case settings.
3. Retain remote `consult-fd` when `fd` exists remotely and the current
   `consult-find` fallback otherwise. Keep the fallback explicitly
   case-insensitive. Reject smart or sensitive saved case modes with a clear
   user error when the selected remote host lacks `fd`. Document that portable
   `find` also has no VCS-ignore concept and cannot reproduce every fd option.
   Do not run a local executable against a TRAMP path.
4. Rename the fzf Transient and its constants to generic file-discovery names.
   Add case choices and preserve recognized-argument filtering,
   `:remember-value '(export save)`, C-g cancellation, and standard Transient
   reset.
5. Bind `C-p` and `SPC f p` to immediate saved/default discovery. Bind `M-p`
   in Evil normal and visual states and `SPC f P` to the options menu. Remove
   `C-S-p`. Preserve minibuffer and completion-in-region C-p navigation.
6. Delete the Counsel action rebinding, Ivy setup hook, fzf minibuffer map,
   Ivy candidate collector, fzf command construction, and private Ivy/Counsel
   state declarations at `my-file-picker.el:12-28,45-49,82-106,291-326`.
7. Reuse native C-q collection and Consult file metadata. Preserve source
   markers and call public `evil-set-jump` only after a successful
   cross-buffer visit.
8. Remove `counsel` and `ivy` from
   `profiles/common/.config/emacs/install-packages.el:53-83` and remove the
   Counsel `use-package` declaration from `init.el:467-468`. Add `transient`
   explicitly to the direct package inventory because repository code requires
   it; `package-installed-p` can satisfy that dependency from either a built-in
   or installed package.
9. Replace fzf/Ivy-specific tests in
   `profiles/common/.config/emacs/my-file-picker-test.el:390-557` and
   `profiles/common/.config/emacs/gui-smoke-test.el:23-86` with public
   Consult/native behavior tests.

### Success Criteria

- C-p begins displaying matching file candidates before a controlled slow
  producer finishes.
- C-p and `SPC f p` run immediately; M-p and `SPC f P` open the same options.
- File discovery is insensitive by default. Local and remote fd support the
  saved case override; remote find rejects unsupported smart/sensitive modes.
- Hidden and ignored files are included by default, symlinks are not followed,
  and `.git` is excluded.
- C-q collects the candidates already displayed during a running file search;
  file export produces Dired where supported.
- Local and TRAMP discovery, C-x C-f toggling, cancellation, accepted visits,
  and Evil C-o return remain correct.
- No Emacs runtime path loads Ivy, Counsel, or fzf.

## Phase 3: Add Line and Buffer Search Options

### Changes

1. Add `profiles/common/.config/emacs/my-search.el` for the cohesive set of
   line, buffer, and ripgrep wrappers and Transients. Load it beside
   `my-file-picker.el` from `profiles/common/.config/emacs/init.el`; keep file
   discovery in `my-file-picker.el`.
2. Add a current-buffer line wrapper that reads saved line settings and invokes
   public `consult-line`. Its Transient exposes insensitive or sensitive case
   and search origin at point or buffer top.
3. Extend the current multi-buffer wrapper at `init.el:609-612` into a command
   that reads saved multi-line settings and invokes public
   `consult-line-multi`. Its Transient exposes case and project or all-open
   buffer scope.
4. Add a buffer-selection wrapper over public `consult-buffer` and
   `consult-project-buffer`. Its Transient exposes insensitive or sensitive
   case and an explicit source choice. The all scope keeps the current
   live-buffer-only `consult-buffer` source. The project scope intentionally
   uses Consult's public project command and includes project buffers, project
   recent files, and the project-root source. Do not add a new dependency on
   private Consult source symbols.
5. Bind `SPC /` and `SPC s l` to immediate current-buffer line search and
   `SPC s L` to its menu. Bind `SPC s b` to immediate multi-buffer line search
   and `SPC s B` to its menu. Bind `C-x b`, `SPC ,`, and `SPC b b` to immediate
   buffer selection and `SPC b B` to its menu.
6. Give each family its own saved Transient values. Lowercase aliases use the
   current active values while a menu is open, otherwise saved values, and
   otherwise code defaults. C-g must not save in-progress changes.
7. Preserve Consult preview restoration, location metadata, C-q Collect, and
   specialized Occur or Ibuffer export.
8. Add focused behavioral coverage in
   `profiles/common/.config/emacs/my-search-test.el`; extend
   `leader-bindings-test.el` for direct/menu pairs and Which Key labels.

### Success Criteria

- `SPC s l` and `SPC s b` update candidates and preview locations on every
  input edit.
- Line, multi-buffer line, and buffer selection are insensitive by default and
  sensitive only when their saved option requests it.
- Buffer all scope contains live buffers only; buffer project scope contains
  exactly the documented Consult project sources, including virtual entries.
- `SPC s L`, `SPC s B`, and `SPC b B` expose only their documented options.
- Lowercase bindings never open a Transient.
- Cancel restores the original location and buffer selection.
- C-q snapshots correct candidates and exported results retain valid source
  locations.
- Transient values persist across a fresh Emacs process and reset to code
  defaults.

## Phase 4: Add Ripgrep Options and Complete Search Coverage

### Changes

1. Move the region-or-symbol wrapper at
   `profiles/common/.config/emacs/init.el:614-635` into `my-search.el` and add
   an unseeded ripgrep wrapper. Both read one shared ripgrep settings record.
2. Build a wrapper-local `consult-ripgrep-args` list from recognized values.
   Support root at project or current directory, hidden files, ignored files,
   symlink following, insensitive/smart/sensitive case, regexp or fixed-string
   matching, optional glob or type restriction, and context lines. Treat free
   values as individual process arguments, never unchecked shell fragments.
3. Preserve region and symbol seed escaping. Pass multiline behavior as an rg
   process option rather than mixing it into editable query text, while
   retaining the accepted multiline result behavior.
4. Bind `SPC s g` and `SPC s w` to immediate unseeded and seeded searches.
   Bind both `SPC s G` and `SPC s W` to the shared ripgrep options Transient.
   The menu's Actions group provides explicit exits for unseeded and seeded
   search, avoiding hidden state based on which key opened the same menu.
5. Replace Consult's `--smart-case` default with the selected explicit case
   flag so rg filtering and Consult highlighting agree.
6. Verify the full search matrix at the top of this plan. History, command,
   kill-ring, Imenu, recent-file, Xref/Eglot, call hierarchy, marks, and jumps
   inherit their stated common or backend-owned contracts and receive no empty
   Transient. Preserve the `C-c e d`, `C-c e D`, `C-c e R`, and `C-c e t`
   Eglot-map aliases as entries into the same Xref/Eglot paths.
7. Update `gui-smoke-test.el`, `my-search-test.el`, and
   `leader-bindings-test.el` for ripgrep streaming, stale-process
   cancellation, seed behavior, case, binding, and persistence contracts.

### Success Criteria

- Ripgrep results arrive before a controlled slow producer finishes, and a
  replaced query cannot publish stale candidates.
- `SPC s g` and `SPC s w` run immediately with one shared saved configuration.
- `SPC s G` and `SPC s W` open the same options and expose both explicit search
  actions.
- Default ripgrep remains insensitive even for uppercase query text.
- Each option changes only its documented rg behavior.
- Seeded search preserves literal region/symbol text and multiline matching.
- C-q Collect, Grep export, preview, cancel restoration, and accepted jumps
  preserve correct file and line locations.
- All other search and navigation bindings retain the surfaces documented in
  the final matrix.

## Phase 5: Integrated Validation, Cleanup, and Documentation

### Changes

1. Run real native CAPF and minibuffer sessions with differently cased
   candidates. Verify editable selection, native acceptance, C-q routing, and
   global quoted insert.
2. Run real `fd` and `rg` against temporary trees containing mixed-case,
   hidden, ignored, symlinked, and `.git` paths. Use controlled slow producers
   to observe partial results and stale-process cancellation without desktop
   automation.
3. Verify local and remote hierarchical creation, recursive toggling, remote
   fd, remote find fallback, cancellation, accepted visits, and Evil jumps.
   Record unavailable live TRAMP checks explicitly instead of replacing them
   with mocked success.
4. Test Transient persistence with an isolated temporary values file across
   two Emacs processes. Verify save, reuse by lowercase commands, C-g without
   save, and reset to code defaults.
5. Run `appearance-test.el`, `my-file-picker-test.el`, `my-search-test.el`,
   `leader-bindings-test.el`, and `gui-smoke-test.el`; keep the number of tests
   small by combining related behavior in table-driven cases.
6. Batch-load `init.el` twice, run `check-parens` on changed Emacs Lisp,
   byte-compile owned modules to a temporary directory, and run
   `git diff --check`.
7. Confirm package provisioning is idempotent and normal startup does not
   refresh archives, run a search process, or contact a remote host.
8. Add a short supersession note to `dev/plans/8-emacs-refinment.md` for its
   Counsel fzf follow-up without rewriting completed history. Update this
   plan's Phase statuses and implementation evidence as work completes.

### Success Criteria

- All focused and integration tests pass in the provisioned Emacs 31.1
  environment.
- Native `*Completions*` is the only candidate-list frontend in the Emacs
  completion and Consult paths.
- File and ripgrep searches visibly stream and discard stale work.
- Case-insensitive defaults and every saved override behave consistently.
- All immediate/options bindings and Which Key labels match the final matrix.
- C-x C-f, CAPF, Embark Collect/Export, TRAMP, and Evil jumps retain their
  documented behavior.
- Ivy, Counsel, and the Emacs fzf adapter are absent from configuration,
  provisioning, and tests.
- Documentation describes the final stack without erasing historical records.
- Each Phase has one accepted commit and recorded validation evidence.

## Overall Success Criteria

- In-buffer and minibuffer completion use built-in Emacs completion and native
  `*Completions*`.
- Consult owns live file, line, buffer, ripgrep, recent-file, Imenu, and Xref
  candidate presentation without becoming the CAPF insertion function.
- Embark owns actions, Collect snapshots, and specialized exports.
- C-x C-f remains hierarchical and create-capable; C-p becomes streamed
  recursive Consult discovery.
- Bounded completion retains native `flex`; recursive fd and rg searches are
  accurately documented as streamed regexp/fixed-string searches rather than
  fzf-ranked fuzzy searches.
- Files, buffers, lines, and ripgrep are insensitive by default and expose
  family-local saved overrides where the backend supports them. The remote
  portable find fallback reports unsupported case modes instead of silently
  changing semantics.
- Configurable leader families use lowercase immediate and uppercase options
  bindings.
- Every other current search and navigation form has an explicit final
  frontend, case owner, and persistence contract.
- The final runtime needs Consult, Embark, `embark-consult`, Transient, `fd`,
  and `rg`, but not Ivy, Counsel, or fzf for Emacs.

## Risks and Constraints

- Removing fzf changes result order and removes exact fzf subsequence scoring.
  This is an explicit product decision in exchange for streaming and one
  completion architecture.
- Recursive include-all discovery can be expensive. The safe default never
  follows symlinks and always excludes `.git`.
- `completion-ignore-case` does not control fd, rg, Isearch smart-case, or Evil
  search. Each layer needs its documented setting or process flag.
- Remote POSIX find has no VCS-ignore model or portable smart-case switch. Do
  not claim that its ignored-file or case-override behavior equals fd.
- Transient values outlive code changes. Only recognized values may become
  command arguments, and reset behavior must handle stale saved values.
- Eglot completion candidates are insertion recipes, not generic locations.
  Embark actions must not replace native CAPF acceptance.
- The current native collector and buffer source configuration touch package
  internals. Do not expand those dependencies; verify them against installed
  versions and isolate any retained workaround with behavioral tests.

## Upstream References

- Emacs completion commands:
  https://www.gnu.org/software/emacs/manual/html_node/emacs/Completion-Commands.html
- Emacs completion styles:
  https://www.gnu.org/software/emacs/manual/html_node/emacs/Completion-Styles.html
- Completion in buffers:
  https://www.gnu.org/software/emacs/manual/html_node/elisp/Completion-in-Buffers.html
- Basic completion and case variables:
  https://www.gnu.org/software/emacs/manual/html_node/elisp/Basic-Completion.html
- Isearch:
  https://www.gnu.org/software/emacs/manual/html_node/emacs/Incremental-Search.html
- Xref:
  https://www.gnu.org/software/emacs/manual/html_node/emacs/Xref.html
- TRAMP file-name completion:
  https://www.gnu.org/software/emacs/manual/html_node/tramp/File-name-completion.html
- Consult:
  https://github.com/minad/consult
- Consult grep, find, and asynchronous search:
  https://github.com/minad/consult#grep-and-find
- Embark:
  https://github.com/oantolin/embark
- Embark Consult:
  https://elpa.gnu.org/packages/embark-consult.html
- Transient value persistence:
  https://github.com/magit/transient/blob/main/docs/transient.org#saving-values
- fd hidden and ignored files:
  https://github.com/sharkdp/fd#hidden-and-ignored-files
- ripgrep search behavior:
  https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md
- fzf filtering and sort behavior:
  https://github.com/junegunn/fzf/blob/master/man/man1/fzf.1
- Evil search case behavior:
  https://github.com/emacs-evil/evil/blob/master/evil-vars.el
