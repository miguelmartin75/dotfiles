# Emacs configuration follow-up plan 1

## High-level plan

This follow-up closes the remaining configuration, completion, font,
terminal-state, and text-delivery gaps. Doom Modeline will be removed in
favor of one textual mode line assembled from standard Emacs constructs, and
normal startup will remain offline. The same work will make minibuffer `C-w`
shell-like, configure the Nerd Font fallback required by Neovim inside Ghostel,
make the outer Evil versus inner terminal state contract explicit, and let text
from any live Emacs buffer target a durable zmx session, a Ghostel buffer, an
Emacs process buffer, or a writable Emacs buffer through the public API that
owns that target class. Explicit selection is the default, while an intentionally
invoked per-tab replay can reuse that tab's last successful target.

## Status

- Plan: complete
- Implementation: in progress
- Target: Emacs 31.1+ with dynamic-module support
- Primary configuration: `profiles/common/.config/emacs/init.el`
- Package provisioner: `profiles/common/.config/emacs/install-packages.el`
- macOS provisioner: `provision/local/macos`
- Superseded plan contract: the zmx-only generalized sender in
  `dev/plans/emacs-config-changes.md`

## Decisions

1. Keep normal startup offline. No package, grammar, font, or Ghostel module
   provisioning runs from `init.el`.
2. Replace Doom Modeline with a textual, icon-free `mode-line-format` built from
   standard Emacs, project.el, VC, Evil, and process-owned mode-line constructs.
   Do not recreate Doom Modeline's advice, polling, package integrations, or icon
   machinery.
3. Make Ghostel terminal-first while outer Evil is in insert state: plain Escape
   belongs to the inner shell or TUI, `C-c ESC` explicitly enters outer Evil
   normal state outside char mode, `i` changes only the outer state back to
   insert, and `C-c C-j` explicitly returns the Ghostel axis to semi-char mode.
4. Keep JetBrains Mono for normal text and use `Symbols Nerd Font Mono` only for
   the Unicode Private Use Area ranges that contain Nerd Font symbols.
5. Treat every live Emacs buffer as a valid text source. File-backed, scratch,
   generated, in-memory, read-only, special, indirect, narrowed, remote, and
   process buffers all use the same active-region or accessible-buffer
   extraction path without a major-mode allowlist.
6. Keep durable zmx sessions, Ghostel buffers, Emacs process buffers, and writable
   Emacs buffers as distinct target classes. Each class has different lifetime,
   submission, mutation, and failure semantics. The chooser always names a class
   and concrete target explicitly. It never infers a destination from the source
   or a last-used target; only the separately invoked replay command uses the
   current tab's remembered successful target.
7. Use only public term-sessions, Ghostel, process, buffer, and tab-bar APIs for
   generalized text delivery. Do not inspect terminal output, insert into rendered
   Ghostel buffers, call private send or tab APIs, bypass buffer read-only
   contracts, or key target state by a tab name, index, window, or configuration.

## Current codebase context

- `profiles/common/.config/emacs/init.el:364-375` configures Ghostel and Evil
  Ghostel without an explicit Escape-routing policy.
- `profiles/common/.config/emacs/init.el:395-444` already extracts an active
  region or the accessible portion of any current buffer without checking its
  major mode, but its documentation incorrectly calls the latter the full
  buffer and delivery still targets only named zmx sessions.
- `profiles/common/.config/emacs/init.el:410-444` records annotations across
  buffer types, but narrowed buffers currently produce restriction-relative
  line numbers and literal triple-backtick fences can be closed by source text.
- `profiles/common/.config/emacs/init.el:601-630` owns native Icomplete and
  minibuffer history. Icomplete does not own ordinary minibuffer editing keys.
- `profiles/common/.config/emacs/init.el:645-734` limits Which Function to the
  explicit parser-mode matrix and enables its global mode only after one of those
  parser hooks runs, even though Which Function has a built-in all-supported-modes
  contract independent of Tree-sitter folding and motion.
- `profiles/common/.config/emacs/init.el:766-772` enables Doom Modeline.
- `profiles/common/.config/emacs/init.el:1029-1046` selects JetBrains Mono and
  applies unavailable legacy icon families to the entire `unicode` charset.
- `profiles/common/.config/emacs/install-packages.el:48-72` installs Doom
  Modeline directly; Doom Modeline pulls Nerd Icons and Shrink Path transitively.
- `profiles/common/.config/emacs/install-packages.el:20-23` pins term-sessions
  to a revision whose public send action does not expose the selected session
  entry for replayable, location-aware storage.
- `profiles/common/.config/emacs/install-packages.el:11-14` pins Ghostel to a
  revision whose public buffer enumeration does not distinguish an accepting PTY
  from an exited terminal buffer and whose public send calls can return without
  delivering input after exit.
- `refs/ghostel/README.org:395-485` documents Ghostel input modes, and
  `:1459-1538` documents Evil Escape routing.
- `refs/ghostel/extensions/evil-ghostel/evil-ghostel.el:725-765` already sends
  `C-w` to the PTY in outer Evil insert state plus Ghostel semi-char mode.
- `refs/ghostel/lisp/ghostel.el:1682-1713` and `:5278-5285` define the current
  public send and buffer-enumeration APIs but no public PTY-liveness predicate.
- `refs/emacs-term-sessions/term-sessions-actions.el:389-398` shows that the
  pinned `term-sessions-action-send-text-to-session` hides its selected entry in
  an internal action callback, so it cannot create a replayable target descriptor
  using only public APIs.
- `refs/emacs-term-sessions/term-sessions-zmx.el:402-416` exports the public raw
  zmx send boundary, while `refs/emacs-term-sessions/term-sessions-frontends.el:414-463`
  shows the public open-or-create boundary and the currently private
  location-aware entry reader.

## Phase 1: Replace Doom Modeline with a native mode line

Status: complete

### Mode-line contract

Use one direct default `mode-line-format` with two aligned groups. Preserve the
built-in constructs themselves so their mouse maps, help text, buffer-local
overrides, and mode-owned updates continue to work.

| Side | Exact standard constructs | Purpose |
| --- | --- | --- |
| Left | `"%e"`, `mode-line-front-space`, Evil's state tag, `mode-line-modified`, `mode-line-remote`, `mode-line-window-dedicated`, `mode-line-buffer-identification`, `(project-mode-line project-mode-line-format)`, `(vc-mode vc-mode)` | Retain the memory-full indication and show outer editing state, buffer state and identity, local/TRAMP context, project, and version-control state. |
| Right | `mode-line-format-right-align`, `mode-line-misc-info`, `mode-line-modes`, `mode-line-position`, `mode-line-end-spaces` | Show global status, major/minor modes, narrowing, recursive edit, process state, and position. |

`mode-line-buffer-identification` must remain intact because Ghostel installs a
buffer-local identification containing the terminal title. `mode-line-modes`
must remain intact because it includes `mode-line-process`; Ghostel publishes
`:Char`, `:Line`, `:Copy`, and `:Emacs` there. Semi-char intentionally has no
Ghostel suffix. `mode-line-misc-info` must remain intact so the built-in Which
Function presentation can serve every major mode that supports it.

### Changes

1. Remove the Doom Modeline `use-package` block at
   `profiles/common/.config/emacs/init.el:766-772`.
2. Before the Evil `use-package` block and therefore before `(evil-mode 1)`, set
   `mode-line-compact` to `long`, set `project-mode-line` to `t`, and install the
   exact textual format above with `setq-default`. Keep
   `mode-line-format-right-align` as the boundary between the left and right
   groups. This ordering matters because `evil-refresh-mode-line` makes the mode
   line buffer-local when Evil is enabled; setting only the default afterward
   leaves already-existing startup buffers on the old format.
3. In Evil's `:init` section, before `(evil-mode 1)`, set the supported
   `evil-mode-line-format` anchor to `(after . mode-line-front-space)` so Evil
   places exactly one `evil-mode-line-tag` there. Do not evaluate `evil-state`
   through a custom redisplay helper.
4. In the same pre-enable Evil configuration, replace the abbreviated state
   strings by setting `evil-normal-state-tag`, `evil-insert-state-tag`,
   `evil-visual-state-tag`, `evil-visual-char-tag`, `evil-visual-line-tag`,
   `evil-visual-block-tag`, `evil-replace-state-tag`, `evil-operator-state-tag`,
   `evil-motion-state-tag`, and `evil-emacs-state-tag`. Use readable text such as
   `NORMAL`, `INSERT`, `VISUAL`, `V-LINE`, `V-BLOCK`, `REPLACE`, `OPERATOR`,
   `MOTION`, and `EMACS`, styled through built-in semantic faces such as
   `success`, `warning`, `error`, `shadow`, and `mode-line-emphasis`. Do not add a
   parallel collection of custom state faces.
5. Decouple Which Function from parser setup:

   - Replace the explicit `which-func-modes` language list at
     `profiles/common/.config/emacs/init.el:645-657` with `t`, the built-in
     contract for every major mode that supports Which Function.
   - Enable `which-function-mode` once as a global mode outside
     `my/parser-tools-mode`.
   - Remove the conditional global-mode activation at
     `profiles/common/.config/emacs/init.el:712-713` from the parser helper.
   - Keep Tree-sitter parser creation, Hideshow configuration, and Evil function
     motions on the existing explicit, validated mode and hook lists. Do not
     infer folding or motion support merely because Which Function can use a
     mode's Imenu data.
6. Do not add custom Git polling, language-version subprocesses, icon lookup, or
   duplicate Eglot/Flymake state to the format.
7. Remove `doom-modeline` from
   `profiles/common/.config/emacs/install-packages.el`. Do not add direct
   `nerd-icons` or `shrink-path` dependencies. Existing installed package
   directories may remain; this plan does not destructively clean user package
   trees.
8. Remove the stale `M-x nerd-icons-install-fonts` comment. The system-level
   Symbols Nerd Font used by Ghostel is independent of the Nerd Icons Lisp
   package and is handled in Phase 3.

### Verification

- Run `check-parens` and byte-compile `init.el` to a temporary output directory.
- Start a clean graphical Emacs and `emacs -nw`; confirm the native mode line is
  readable in both environments.
- Confirm startup buffers such as `*scratch*`, buffers created after startup, and
  Ghostel buffers all use the intended default or their documented buffer-local
  specialization, rather than retaining Doom Modeline's format.
- Switch through Evil normal, insert, character/line/block visual, replace,
  operator, motion, and Emacs states. Confirm exactly one readable state tag.
- Open normal, modified, read-only, local project, VC-controlled, dedicated-window,
  and TRAMP buffers and confirm their standard indicators remain functional.
- Start a real Ghostel PTY and switch between semi-char, char, line, copy, and
  Emacs input modes. Confirm the Evil tag and Ghostel process label remain visible
  simultaneously and the terminal title remains in buffer identification.
- Exercise compilation, Eglot/Flymake, narrowed, recursive-edit, and ordinary
  process-backed buffers. Confirm their standard mode-owned status remains visible.
- Confirm Which Function activates in parser-backed modes and in representative
  non-parser modes with Imenu support, remains absent when a mode cannot provide
  function context, and does not enable parser creation, Hideshow, or Evil
  function motions outside the explicit parser hook list.
- Check narrow and split windows for overflow; allow Emacs's compact mode to
  compress the format rather than adding bespoke truncation code.
- Confirm `doom-modeline` has no package entry in `install-packages.el`, no
  configuration block in `init.el`, and no loaded feature after startup. Confirm
  provisioning into an empty temporary package directory no longer installs Nerd
  Icons or Shrink Path through Doom Modeline; report any independent retained
  package owner separately.

### Success criteria

- The default mode line is defined entirely through standard Emacs
  configuration in `init.el`.
- The mode line is textual, icon-free, and understandable without Doom Modeline.
- Outer Evil state and non-default Ghostel input mode are simultaneously visible.
- Buffer, remote, project, VC, process, minor-mode, and position information uses
  its upstream standard contract.
- Mode-specific buffer-local mode lines continue to override the default.
- Which Function uses its built-in all-supported-modes contract independently of
  the explicit Tree-sitter folding and motion matrix.
- Fresh package provisioning has no direct or transitive Doom Modeline stack.

### Measured outcome

- On 2026-08-31, `check-parens`, byte compilation of `init.el` and
  `install-packages.el` to `/private/tmp`, and `git diff --check` passed. Byte
  compilation retained existing free-variable and deferred-package warnings but
  produced both requested `.elc` files without errors.
- A guarded clean batch load passed with package, VC, URL, and grammar
  installation entry points replaced by errors. Runtime assertions confirmed
  the exact native default mode-line structure, exactly one Evil state-tag
  construct in startup and newly created buffers, buffer-local override
  behavior, global Which Function configuration, and no loaded Doom Modeline
  feature.
- Automated visual inspection and a real Ghostel PTY remain part of Phase 5
  acceptance. The available runner could not allocate `/dev/tty` for an
  `emacs -nw` visual session.

## Phase 2: Make minibuffer word killing and Ghostel key ownership predictable

Status: complete

### Changes

1. Set the Emacs 31.1 user option `kill-region-dwim` to `unix-word` in the editing
   basics section of `profiles/common/.config/emacs/init.el`.

   - Keep `C-w` bound to the standard `kill-region` command.
   - With an active region, retain normal region killing.
   - Without an active region, kill the preceding whitespace-delimited shell word.
   - Do not add Icomplete-specific keymaps, minibuffer hooks, or a custom command.

2. Use `setopt` to configure the supported Evil Ghostel user options
   `evil-ghostel-initial-state` as `insert` and `evil-ghostel-escape` as
   `terminal` at `profiles/common/.config/emacs/init.el:373-375`.
3. Document Evil state and Ghostel input mode as independent axes, with these
   transitions:

   - While outer Evil is in insert state, `evil-ghostel-escape` set to `terminal`
     sends plain Escape to the inner shell or TUI without consulting
     alternate-screen detection. It does not redefine Escape in outer normal
     state.
   - Outside Ghostel char mode, `C-c ESC` enters outer Evil normal state once.
   - `i` changes only the outer Evil state back to insert. It does not leave
     Ghostel line, copy, or Emacs input mode.
   - `C-c C-j` is the explicit return to Ghostel semi-char mode.
   - `C-c M-d` enters Ghostel char mode when a TUI needs every key. Char mode
     sends even `C-c ESC` inward, so `M-RET` must leave char mode before outer
     Evil commands are available again.
   - In Ghostel semi-char mode plus outer Evil insert state, `C-w` reaches the
     PTY. Outer Evil normal state retains its `C-w` window prefix. Once delivered,
     the inner application decides what `C-w` means.

4. Do not add per-key Ghostel forwarding maps. The pinned Evil Ghostel extension
   already forwards the standard control-key set correctly.
5. Rely on the Phase 1 mode line for observability: Evil's textual tag shows the
   outer state, while Ghostel's supported process suffix shows non-default input
   mode. Do not read `ghostel--input-mode` or other private variables.

### Verification

- In `M-x` and `C-x C-f`, type two whitespace-separated tokens and confirm `C-w`
  removes the last token. Repeat with a path containing punctuation and confirm
  whitespace, not Emacs syntax, defines the boundary.
- Activate a minibuffer region and confirm `C-w` still kills exactly that region.
- In a normal Ghostel shell with outer Evil insert state and Ghostel semi-char
  mode, confirm Escape goes inward, `C-c ESC` enters outer `NORMAL`, and `i`
  returns only the outer axis to `INSERT`.
- Run Neovim inside Ghostel. Confirm Escape reaches Neovim, `C-w` reaches Neovim
  from outer insert, and Neovim normal mode can consume the following window key.
- Exercise the useful combinations of outer normal/insert and Ghostel semi-char,
  char, line, copy, and Emacs modes. Confirm `i`, `C-c C-j`, `C-c ESC`, and
  `M-RET` affect only the documented axis and that mode-line labels match.
- Restart Emacs before final acceptance so existing buffer-local Evil Ghostel
  routing state cannot mask the configured default.

### Success criteria

- Minibuffer `C-w` behaves like shell input without replacing standard region
  semantics.
- Insert-state Escape routing is deterministic and no longer changes based on
  alternate-screen detection.
- Normal terminal input needs no custom forwarding map, and outer navigation has
  one explicit entry and exit path.

### Measured outcome

- On 2026-08-31, `check-parens`, byte compilation of `init.el` to
  `/private/tmp`, and `git diff --check` passed with only the existing deferred
  package and free-variable warnings.
- A guarded batch load confirmed `kill-region-dwim` is `unix-word`, `C-w`
  remains the inherited standard `kill-region` binding in minibuffer maps, a
  punctuation-containing shell word is removed as one token, and an active
  region retains exact region-kill behavior.
- Loading Evil Ghostel confirmed its initial state is registered as `insert` and
  its Escape routing default is `terminal`. Real Ghostel, Neovim, and mode-line
  interaction checks remain part of Phase 5 acceptance.

## Phase 3: Provision and scope the Nerd Font fallback

Status: complete

### Changes

1. Add `font-symbols-only-nerd-font` to `provision/local/macos` so the macOS setup
   path installs `Symbols Nerd Font Mono` independently of Doom Modeline or Nerd
   Icons.
2. Add `Symbols Nerd Font Mono` to the graphical-Emacs prerequisites in the top
   comments of `profiles/common/.config/emacs/init.el`. Non-macOS machines must
   provide the same family through their system font installation path.
3. Keep JetBrains Mono as the normal text font and preserve the ordinary Apple
   emoji/symbol fallbacks at `profiles/common/.config/emacs/init.el:1034-1039`.
4. Remove the six legacy `set-fontset-font` calls at
   `profiles/common/.config/emacs/init.el:1041-1046`.
5. Prepend `Symbols Nerd Font Mono` only for:

   - BMP Private Use Area: `#xe000` through `#xf8ff`.
   - Supplementary Private Use Area-A: `#xf0000` through `#xffffd`.

   Do not assign it to the full `unicode` charset or to Supplementary Private Use
   Area-B. Ghostel reserves U+10EEEE in Area-B for Kitty graphics placeholders.
6. Do not change Neovim's Snacks icons or add `mini.icons`/
   `nvim-web-devicons`; changing the icon producer would still require an
   appropriate terminal font.

### Verification

- On macOS, run the provisioner twice and confirm the font cask is installed
  idempotently.
- In graphical Emacs, confirm `(find-font (font-spec :family "Symbols Nerd Font
  Mono"))` succeeds.
- Render ordinary Greek, CJK, and emoji characters alongside U+F105, U+F0214,
  U+F024B, and U+F0770. Confirm ordinary text keeps its existing font behavior and
  only PUA symbols resolve through Symbols Nerd Font Mono.
- In Ghostel copy mode, inspect a picker glyph with `C-u C-x =` or
  `M-x ghostel-debug-glyph-at-point` and confirm the selected font family.
- Open Neovim inside Ghostel, press `C-p`, and confirm the Snacks prompt, file,
  and directory icons render with stable terminal cell alignment.
- Restart Emacs before validation because fontset and composition results may be
  cached after first display.

### Success criteria

- Neovim picker symbols render in Ghostel without replacing the primary text font.
- Fresh macOS setup installs the required system font without relying on the
  removed Nerd Icons Lisp package.
- The fallback is limited to the exact character ranges that require it and does
  not interfere with ordinary Unicode or Ghostel's Kitty graphics placeholder.

### Measured outcome

- On 2026-08-31, `bash -n`, `check-parens`, byte compilation of `init.el` to
  `/private/tmp`, a guarded full batch load, and `git diff --check` passed with
  only the existing deferred-package and free-variable warnings.
- Runtime interception confirmed exactly two `Symbols Nerd Font Mono` mappings,
  both prepended: U+E000-U+F8FF and U+F0000-U+FFFFD. No whole-Unicode or U+10EEEE
  mapping was introduced, and the JetBrains Mono and Apple fallback face
  configuration remained intact.
- Homebrew installed `font-symbols-only-nerd-font` 3.5.1 successfully. Repeating
  the same command reported the latest version already installed, confirming the
  scoped provisioning step is idempotent. Fontconfig resolves `Symbols Nerd
  Font Mono`; graphical Emacs and Ghostel/Neovim glyph rendering remain part of
  Phase 5 acceptance.

## Phase 4: Generalize text delivery with explicit selection and per-tab replay

Status: pending

### Source contract

| Source shape | Extraction boundary | Scope |
| --- | --- | --- |
| Active region | `buffer-substring-no-properties` from `region-beginning` through `region-end` | Any live Emacs buffer with an active region. |
| No active region | `buffer-substring-no-properties` from `point-min` through `point-max` | The current buffer's accessible contents. Narrowing is respected and hidden text is not widened into the payload. |

The source path must not inspect `major-mode`, `buffer-file-name`, read-only
state, process ownership, or local versus TRAMP location. File-backed, scratch,
generated, in-memory, read-only, special, indirect, narrowed, remote, and process
buffers all expose text through the same public buffer boundary. Source text
properties are intentionally removed before delivery.

### Target contract

| Target class | Saved descriptor | Selection and delivery boundary | Submission or mutation semantics |
| --- | --- | --- | --- |
| Durable zmx session | `(:type zmx :name NAME :directory DIRECTORY)` | A new public existing-session selector returns `NAME` and `DIRECTORY`; bind `default-directory` to `DIRECTORY` and call `term-sessions-send`. | Send exact text plus one carriage return. It is a logical name-and-location address, independent of an Emacs frontend buffer. |
| Ghostel buffer | `(:type ghostel :buffer BUFFER)` | `ghostel-buffer-list`, the required public `ghostel-buffer-live-p`, `ghostel-paste-string`, and `ghostel-send-key` on the returned original buffer. | Bracket-paste exact text, then send one terminal-aware Return. Dead or exit-racing terminals signal instead of succeeding as no-ops. |
| Emacs process buffer (raw text) | `(:type process :buffer BUFFER :process PROCESS)` | `buffer-list`, `get-buffer-process`, `process-live-p`, and `process-send-string` on the original pair. | Send exact raw text with no appended carriage return or newline. The process protocol owns framing and submission. |
| Writable Emacs buffer (insert at point) | `(:type buffer :buffer BUFFER)` | `buffer-list`, `buffer-live-p`, `buffer-read-only`, and `insert` on the original buffer. | Insert exact plain text at its current point without saving, displaying, switching to, or submitting the buffer. |

The exact completion labels in the first column are the user-visible target
classes. Do not prefix them with `Live`. Lowercase `live` remains appropriate
only when stating an actual buffer or process liveness condition.

### Per-tab target state

The target belongs to the current tab, never to a global last-target variable.
Read the public `tab-bar-tabs` list, locate its documented `(current-tab ...)`
entry, add or replace that alist's custom `my/send-text-last-target` property,
and write the updated list with public `tab-bar-tabs-set`. Preserve the rest of
the tab entry and all other tabs. Do not use `tab-bar--*` APIs or derive identity
from a tab name, tab index, selected window, or window configuration.

- A newly created tab has no target. Switching, renaming, and moving tabs retain
  the descriptor because it travels with that tab's entry. Closing a tab discards
  it, unless Emacs tab undo restores that logical tab.
- Store a descriptor only after the chosen delivery or creation command returns
  successfully. A canceled chooser, a selection failure, or a delivery failure
  leaves the prior descriptor intact.
- A killed or replaced Ghostel, process, or writable-buffer object invalidates
  and clears that descriptor on the attempted replay. Never resolve a same-named
  replacement. A process must still be live and still be the selected buffer's
  associated process. A writable buffer that becomes read-only rejects that
  attempt but retains its descriptor. A Ghostel buffer must also pass the public
  `ghostel-buffer-live-p` predicate, and the public send calls must signal if the
  PTY exits before either write completes.
- A zmx descriptor remains saved when zmx reports a missing or unreachable
  session. Its `NAME` and `DIRECTORY` are the intended logical address, and
  connectivity or the named session can recover later.

### Terminal package API prerequisites

The current Ghostel pin at
`profiles/common/.config/emacs/install-packages.el:11-14` cannot support the
plan's dead-target and successful-delivery contracts through public APIs. Add
and review the upstream public function `ghostel-buffer-live-p BUFFER`, which
returns non-nil only when `BUFFER` is a Ghostel buffer whose PTY can accept
input. At the same public boundary, make `ghostel-paste-string` and
`ghostel-send-key` signal `user-error` if the PTY is already dead or exits before
their write completes instead of returning as a no-op. Cover live, exited, and
exit-racing buffers in Ghostel's tests, then update the Ghostel pin to the
resulting reviewed commit. The configuration must not inspect Ghostel's private
process or terminal fields.

The current pinned `term-sessions-action-send-text-to-session` at
`refs/emacs-term-sessions/term-sessions-actions.el:389-398` hides the chosen
entry inside its action callback. It cannot satisfy location-aware replay using
only public APIs. Add and review the upstream public function
`term-sessions-read-existing-session-entry (&optional prompt)` in
`term-sessions-frontends.el`. It must use the package's existing-session
completion and validation and return an entry plist containing at least `:name`
and `:directory`, including the selected local or TRAMP location. Cover local,
remote, require-match, and cancellation behavior in term-sessions tests, then
update the pin at `profiles/common/.config/emacs/install-packages.el:20-23` to
the resulting reviewed commit. The configuration uses only that public function
to construct the descriptor.

With that prerequisite, the config binds the returned or saved directory and
calls public `term-sessions-send` from
`refs/emacs-term-sessions/term-sessions-zmx.el:402-416` with exact text plus one
`"\r"`. Use public `term-sessions-open` from
`refs/emacs-term-sessions/term-sessions-frontends.el:414-463` for the creation
flow. Do not call a private selector, advise or intercept completion, reduce zmx
to a free-form current-directory-only name, shell out to zmx, or open a terminal
solely to discover identity.

### Changes

1. Replace `my/term-sessions-send-text` with two transport entry points:

   - `my/send-text-to-target TEXT` always prompts first for a target class and
     then for its concrete target. It delivers before recording the resulting
     descriptor on the current tab.
   - `my/send-text-send-to-last-target TEXT` never prompts. It reads only the
     current tab's `my/send-text-last-target` descriptor and replays it. With no
     descriptor, signal `user-error` directing the user to the chooser command.

   Remove the old term-sessions-specific owned names and add no compatibility
   aliases.
2. Keep `my/send-region-or-buffer` as the mode-independent chooser source
   command. It extracts an active region without text properties or, with no
   region, `point-min` through `point-max` without widening. Describe the latter
   as `accessible buffer contents`, not `full buffer`. Add
   `my/send-region-or-buffer-to-last-target` with the same extraction path and
   replay entry point. Neither source command adds a supported-mode list,
   process-buffer exception, file requirement, writable-source requirement, or
   source-specific transport branch.
3. The chooser uses require-match native completion in this order: target class,
   then the concrete target. Its target-class choices are exactly `Durable zmx
   session`, `Ghostel buffer`, `Emacs process buffer (raw text)`, and `Writable
   Emacs buffer (insert at point)`. It never supplies a last-used default or
   infers a destination. A successful explicit delivery replaces only the
   current tab's descriptor.
4. In the zmx chooser branch, call the newly public existing-session selector and
   save its `:name` and `:directory`. Bind `default-directory` to that selected
   directory for delivery, then call `term-sessions-send` with `(concat text
   "\r")`. In replay, use only the stored name and directory in the same way;
   do not re-run a selector. Keep zmx errors as errors and retain the descriptor.
5. In the Ghostel chooser branch, defer `(require 'ghostel)` until that class is
   selected, then build unambiguous require-match candidates from the buffers
   returned by `ghostel-buffer-list` that also pass `ghostel-buffer-live-p`.
   Signal `user-error` when none exist. Store the selected returned object, not a
   name. Before delivery or replay, require the original buffer to be live,
   remain a member of `ghostel-buffer-list`, and still pass
   `ghostel-buffer-live-p`; clear a replay descriptor when any check fails. In
   the buffer, call `ghostel-paste-string` with the text and then
   `ghostel-send-key` with `"return"`. Both public calls must signal if their PTY
   write cannot complete. If paste succeeds and Return fails, preserve the
   annotation queue and descriptor because the terminal may already have pasted
   input; this deliberately non-atomic send is neither rollback-safe nor
   retry-idempotent. Do not inspect Ghostel private identity or PTY state, call
   `ghostel--send-string`, use the generic process branch, or insert into the
   rendered terminal buffer.
6. In the process chooser branch, build unambiguous require-match candidates from
   every buffer with a live associated process and store both original objects.
   Before delivery or replay, require a live original buffer, a live original
   process, and `(eq PROCESS (get-buffer-process BUFFER))`. Send the exact text
   once with `process-send-string`, with no added terminator and no Comint,
   compilation, terminal, or mode-specific submission command. On failed object
   identity or association validation, clear this tab's descriptor and signal
   `user-error` rather than targeting a replacement.
7. In the writable-buffer chooser branch, build unambiguous require-match
   candidates from all live writable `buffer-list` buffers, including file-backed,
   scratch, generated, and other in-memory buffers. Store the original buffer
   object. On delivery or replay, a killed object clears this tab's descriptor;
   a still-live buffer that has become read-only signals `user-error` but retains
   it. Otherwise insert exact plain text at its current point, leaving point after
   the text and the buffer modified without saving, displaying, switching to, or
   interpreting it. Never use `inhibit-read-only` or a same-named replacement.
8. Bind `SPC t r` and visual `C-c C-c` to the chooser source command. Bind
   `SPC t R` and visual `C-c C-r` to the replay source command. Update Which Key
   descriptions, docstrings, mapping documentation, and tests to use these names
   and the exact target labels. `my/annotate-send-all` always calls the chooser
   transport and clears `my/annotations` only after successful delivery; it never
   uses replay.
9. Add `my/create-ghostel-terminal-in-split`, bound to `SPC t g`. Prompt for an
   optional Ghostel buffer name before changing layout, preserve the caller's
   `default-directory`, and call public `ghostel-create NAME DISPLAY-ACTION`.
   `DISPLAY-ACTION` uses public `display-buffer-in-direction` with direction
   `right` and `window-width` `0.5` for an equal-width side-by-side split, with
   the new window on the right. After its successful return and a
   `ghostel-buffer-live-p` check, store `(:type ghostel :buffer BUFFER)` on the
   current tab. This creates a Ghostel terminal and buffer; zmx owns durable
   sessions.
10. Add `my/open-or-create-zmx-session-in-split`, bound to `SPC t z`. Prompt for
    the name before layout changes and, with a prefix argument, for the creation
    command. Capture the caller's `default-directory` as `directory` before any
    prompt or display change. Dynamically bind public
    `display-buffer-overriding-action` to the same right-direction action and
    call public `term-sessions-open` with `(:name NAME :directory directory)` and
    the optional command. Record `(:type zmx :name NAME :directory directory)`
    only after it returns successfully. It is open-or-create because an existing
    name is reused. Cancellation or failure preserves the prior target. Do not
    kill or otherwise roll back a possibly-created zmx session; partial visible
    state after a later failure remains inspectable.
11. Correct annotation source metadata for narrowed buffers by passing a non-nil
    absolute argument to both `line-number-at-pos` calls in `my/annotate-region`.
    The stored line range remains relative to the full underlying buffer although
    selected text remains limited to the accessible region.
12. Make each annotation source block safe for arbitrary backtick content. In
    `my/annotate-send-all`, construct a Markdown fence of at least three
    backticks that is strictly longer than that item's longest contiguous
    backtick run. Use that same computed fence to open and close the item. Keep
    this logic inline at its one formatting site and do not mutate the stored
    source snapshot.

### Verification

- Focused tests stub public boundaries rather than asserting source text exists:

  - Active-region extraction delegates exact plain text from representative
    file-backed, scratch, generated, read-only special, TRAMP, and process
    buffers without checking their modes or target ownership. No-region
    extraction delegates only `point-min` through `point-max`, proving hidden
    narrowed text is not sent.
  - A narrowed annotation records absolute underlying-buffer line numbers while
    retaining accessible text. Annotation text containing three-, four-, and
    longer-backtick runs receives a strictly longer matching fence.
  - Two tabs can select different targets and replay only their own target.
    Switching, renaming, moving, creating a new tab, closing a tab, and undoing a
    close retain, omit, discard, or restore state according to the per-tab
    contract. A new tab's replay signals `user-error` without invoking either
    completion prompt.
  - A chooser selection or delivery failure preserves the old descriptor. Only a
    successful chooser delivery changes the current tab's descriptor; it does
    not change another tab's target.
  - The zmx chooser receives an entry with both name and directory, and chooser
    and replay bind that directory before calling `term-sessions-send` with exact
    text plus exactly one character 13 carriage return. Missing or unreachable
    zmx errors keep the descriptor.
  - The Ghostel branch requires Ghostel only after its class is selected, maps
    completion to buffers from `ghostel-buffer-list` that pass
    `ghostel-buffer-live-p`, validates both conditions again before delivery,
    pastes before Return, and rejects a killed, exited, or same-named replacement
    by clearing the saved replay target. Dead and exit-racing writes signal, and
    paste and Return failures preserve the annotation queue.
  - The process branch stores and rechecks the original buffer/process pair,
    sends exact raw text with no added terminator, and clears a dead, killed, or
    replaced pair rather than resolving by name.
  - The writable-buffer branch inserts once at the original object's current
    point without saving or switching. A killed or replaced object clears the
    descriptor; becoming read-only rejects the send and retains it.
  - Exact completion labels, binding descriptions, and documentation contain no
    `Live ` target prefix. Annotation delivery uses the chooser and clears the
    queue only after success.
  - Both split creation commands prompt before changing layout, preserve the
    caller directory, use an equal-width side-by-side display action with the new
    window on the right, store state only after success, and preserve a prior
    target on cancellation or failure. The Ghostel test requires a live returned
    buffer, and the zmx test confirms the captured directory and no destructive
    rollback after partial creation.

- Manually send one-line and multiline text from file-backed, `*scratch*`,
  generated in-memory, read-only special, narrowed indirect, TRAMP, Comint, and
  other process buffers to representative targets.
- Insert text into a selected file-backed buffer, `*scratch*`, and a generated
  in-memory buffer. Confirm the destination is modified at its existing point but
  is neither displayed nor saved automatically.
- Send raw text with an explicit caller-provided line terminator to a selected
  process buffer and confirm the generic branch adds no extra terminator or
  mode-specific submission behavior.
- Send one-line and multiline text to a Ghostel buffer, then kill or replace each
  selected Ghostel, process, and writable-buffer target between enumeration and
  delivery. Confirm the original-object contract never targets a same-named
  replacement.
- Send to a named zmx session with no attached Emacs buffer and to a selected
  remote Ghostel buffer. Confirm the saved zmx location and Ghostel PTY own their
  respective routing without custom TRAMP logic.
- Confirm Python's native Comint evaluation commands and project compilation
  routes remain separate from the generalized raw-process transport.

### Success criteria

- Any live Emacs buffer can provide an active region or accessible buffer
  contents without a mode, file, mutability, process, or location allowlist.
- `SPC t r` and visual `C-c C-c` always select one exact target class and a
  concrete target. `SPC t R` and visual `C-c C-r` replay only the current tab's
  last successful target and never prompt.
- Target state is a public-tab-bar property with the documented tab lifetime and
  never leaks between tabs or falls back to a name-, index-, window-, or
  configuration-keyed global.
- Each class uses supported public APIs and preserves its target-specific
  submission, mutation, lifetime, and stale-identity semantics. zmx is stored as
  a recoverable name-and-directory logical address; buffer and process targets
  are object identities.
- The pinned Ghostel revision provides `ghostel-buffer-live-p` and
  failure-signaling public sends, and the pinned term-sessions revision provides
  `term-sessions-read-existing-session-entry`. No private package API is
  introduced.
- Ghostel creation is a terminal/buffer flow; durable sessions are owned by zmx.
- Narrowed-source extraction and annotation line numbers follow their documented
  accessible-text and absolute-location contracts. Annotation Markdown remains
  structurally valid for any contiguous backtick run, and its queue survives any
  signaled selection or delivery failure.

## Phase 5: Final acceptance and documentation reconciliation

Status: pending

### Changes

1. Reconcile comments, package inventory, mapping documentation, and the
   generalized source, target, per-tab replay, and split-creation contracts with
   the final implementation.
2. Update implementation status in this file after each accepted phase and
   record measured outcomes without rewriting completed historical work.
3. Remove stale symbols and files only after their replacements pass:

   - `doom-modeline` configuration and package entry.
   - Legacy all-Unicode icon-font rules and Nerd Icons installation comment.
   - Old term-sessions-specific owned sender names and zmx-only descriptions.
   - Old implicit last-used destination wording and target labels with a `Live `
     prefix.
   - Parser-only Which Function activation and the explicit `which-func-modes`
     allowlist.

### Acceptance suite

- `check-parens` and byte compilation to a temporary directory for `init.el`, the
  two Elisp provisioners `install-packages.el` and
  `install-tree-sitter-grammars.el`, and any focused Elisp test file.
- One guarded clean startup with package refresh, package installation, VC
  installation, URL retrieval, grammar installation, and module installation
  replaced by errors. Do not describe a second in-process load as equivalent to
  clean startup.
- `bash -n provision/local/macos`, followed by a macOS provisioner idempotency
  check including Symbols Nerd Font Mono.
- Native Icomplete initial candidates for `M-x` and `C-x C-f`, plus shell-style
  `C-w` and active-region behavior.
- Graphical and `emacs -nw` mode-line acceptance across Evil states, Ghostel
  modes, local/TRAMP buffers, VC/project buffers, narrow windows, processes,
  diagnostics, and minor modes.
- Real Ghostel font and key-routing checks with Neovim's `C-p` picker.
- Source extraction from file-backed, scratch, generated, read-only special,
  narrowed indirect, TRAMP, Comint, and other process buffers.
- Real durable zmx, Ghostel, raw process-buffer, and writable-buffer delivery,
  including multiline and remote cases where environments are available. Verify
  explicit chooser delivery, no-target replay without prompting, and distinct
  per-tab replay after switching, renaming, moving, closing, and undoing tabs.
- Narrowed-source, absolute annotation line-number, arbitrary-backtick Markdown
  fence, killed/replaced target, read-only destination, and annotation-queue
  failure checks from Phase 4.
- The reviewed term-sessions pin exposes the required public existing-session
  selector `term-sessions-read-existing-session-entry` with both name and
  directory. Confirm chooser and replay bind the selected directory and send
  exactly one appended carriage return through public `term-sessions-send`.
- The reviewed Ghostel pin exposes `ghostel-buffer-live-p`, and its public paste
  and key sends signal on dead or exit-racing PTYs. Confirm dead Ghostel buffers
  cannot be selected or remembered as successful deliveries.
- Both `SPC t g` and `SPC t z` use an equal-width side-by-side split with the new
  window on the right, preserve target state on cancellation or failure, and
  leave any partial zmx creation inspectable without destructive rollback.
- In `init.el` and `install-packages.el`, check that the Doom Modeline
  configuration, package entry, and feature load are absent. Confirm clean
  provisioning does not acquire Nerd Icons or Shrink Path through Doom Modeline;
  do not require repository-wide textual absence of `doom-modeline`.
- `git diff --check` and repository formatting checks.
- Record the same one-warmup, five-run startup benchmark used by
  `dev/plans/emacs-config-changes.md`, comparing the final mean, median, range,
  and sample standard deviation with the current baseline.

### Overall success criteria

- `init.el` is the single source for the default mode line.
- Normal startup remains offline and does not provision software.
- Doom Modeline and its unused Lisp dependency stack are absent from fresh
  provisioning and startup.
- The native mode line exposes textual Evil state, Ghostel input/process state,
  buffer identity, remote/project/VC context, modes, and position using standard
  upstream constructs.
- Minibuffer `C-w`, Ghostel Escape routing, and terminal `C-w` ownership are
  predictable and documented.
- Nerd Font glyphs render inside Ghostel without changing ordinary text fonts or
  broad Unicode fallback behavior.
- Every live Emacs buffer can provide an active region or accessible contents
  without a source-mode allowlist, including file-backed, scratch, generated,
  read-only, special, indirect, narrowed, remote, and process buffers.
- Source text can explicitly select Durable zmx session, Ghostel buffer, Emacs
  process buffer (raw text), or Writable Emacs buffer (insert at point), while
  only deliberate replay uses the last successful target of the current tab.
  Annotation queues always use explicit selection and clear only after success.
- Which Function covers every supporting major mode without broadening the
  explicit Tree-sitter parser, folding, and Evil motion matrix.
- No private Ghostel, term-sessions, or tab-bar implementation API is introduced.

## References

### Codebase

- `provision/local/macos:1-12`
- `profiles/common/.config/emacs/init.el:1-19`
- `profiles/common/.config/emacs/init.el:295-375`
- `profiles/common/.config/emacs/init.el:381-444`
- `profiles/common/.config/emacs/init.el:601-734`
- `profiles/common/.config/emacs/init.el:760-795`
- `profiles/common/.config/emacs/init.el:1026-1046`
- `profiles/common/.config/emacs/install-packages.el:1-98`
- `profiles/common/.config/emacs/install-packages.el:11-14`
- `profiles/common/.config/emacs/install-packages.el:20-23`
- `profiles/common/.config/nvim/init.lua:578-586`
- `refs/ghostel/README.org:163-223`
- `refs/ghostel/README.org:395-485`
- `refs/ghostel/README.org:1459-1538`
- `refs/ghostel/README.org:1993-2037`
- `refs/ghostel/extensions/evil-ghostel/evil-ghostel.el:61-93`
- `refs/ghostel/extensions/evil-ghostel/evil-ghostel.el:725-889`
- `refs/ghostel/lisp/ghostel.el:1682-1713`
- `refs/ghostel/lisp/ghostel.el:2241-2321`
- `refs/ghostel/lisp/ghostel.el:5278-5285`
- `refs/ghostel/lisp/ghostel-module-install.el:413-506`
- `refs/ghostel/build.zig:7-12`
- `refs/ghostel/build.zig.zon:4`
- `refs/emacs-term-sessions/term-sessions-actions.el:389-398`
- `refs/emacs-term-sessions/term-sessions-zmx.el:402-416`
- `refs/emacs-term-sessions/term-sessions-frontends.el:414-463`

### Upstream documentation

- [Mode-line variables](https://www.gnu.org/software/emacs/manual/html_node/elisp/Mode-Line-Variables.html)
- [Mode-line data structures](https://www.gnu.org/software/emacs/manual/html_node/elisp/Mode-Line-Data.html)
- [Project mode-line support](https://www.gnu.org/software/emacs/manual/html_node/emacs/Projects.html)
- [VC mode-line behavior](https://www.gnu.org/software/emacs/manual/html_node/emacs/VC-Mode-Line.html)
- [Buffer list](https://www.gnu.org/software/emacs/manual/html_node/elisp/Buffer-List.html)
- [Tab bars](https://www.gnu.org/software/emacs/manual/html_node/emacs/Tab-Bars.html)
- [Narrowing](https://www.gnu.org/software/emacs/manual/html_node/elisp/Narrowing.html)
- [Input to processes](https://www.gnu.org/software/emacs/manual/html_node/elisp/Input-to-Processes.html)
- [Emacs 31 `kill-region-dwim`](https://github.com/emacs-mirror/emacs/blob/emacs-31/etc/NEWS.31)
- [Modifying fontsets](https://www.gnu.org/software/emacs/manual/html_node/emacs/Modifying-Fontsets.html)
- [Symbols-only Nerd Font guidance](https://github.com/ryanoasis/nerd-fonts/discussions/969)
- [Homebrew Symbols Nerd Font cask](https://formulae.brew.sh/cask/font-symbols-only-nerd-font)
- [Evil mode-line state tags](https://github.com/emacs-evil/evil/blob/334a636621577e77f834bca0c6ecdcec67c6ff1e/evil-core.el)
- [Ghostel](https://github.com/dakra/ghostel)
- [term-sessions.el](https://github.com/ArthurHeymans/emacs-term-sessions)
