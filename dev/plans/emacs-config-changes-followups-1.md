# Emacs configuration follow-up plan 1

## High-level plan

This follow-up closes the remaining configuration, completion, font,
terminal-state, and text-delivery gaps. Doom Modeline will be removed in
favor of one textual mode line assembled from standard Emacs constructs, and
normal startup will remain offline. The same work will make minibuffer `C-w`
shell-like, configure the Nerd Font fallback required by Neovim inside Ghostel,
make the outer Evil versus inner terminal state contract explicit, and let text
from any live Emacs buffer target a zmx session, an ordinary Emacs buffer, or a
Ghostty terminal through local integration boundaries and the public delivery
API that owns each transport. Explicit selection is the default, while an
intentionally invoked per-tab replay can reuse that tab's last successful target
or open the picker when none exists.

## Status

- Plan: complete
- Implementation: complete
- Target: Emacs 31.1+ with dynamic-module support
- Primary configuration: `profiles/common/.config/emacs/init.el`
- Package provisioner: `profiles/common/.config/emacs/install-packages.el`
- macOS provisioner: `provision/local/macos`
- Superseded plan contract: the zmx-only generalized sender in
  `dev/plans/emacs-config-changes.md`

## Follow-up F1: Contain terminal package integration locally

- Owner: `emacs-config-changes-followups-1`
- Status: complete
- Context: the first Phase 4 implementation depended on unpublished Ghostel and
  term-sessions commits. Publishing forks or pull requests is outside the
  configuration's scope, and the original upstream URLs must remain usable.
- Solution: restore reachable upstream package revisions, represent Ghostel
  identity as its buffer and public Emacs process object, validate that pair
  around public Ghostel sends, and call the pinned term-sessions private
  location-aware selector at one explicit local boundary in `init.el`.
- Affected: `profiles/common/.config/emacs/init.el`,
  `profiles/common/.config/emacs/install-packages.el`,
  `profiles/common/.config/emacs/send-text-targets-test.el`, and this plan.

## Follow-up F2: Pick a target when replay has none

- Owner: `emacs-config-changes-followups-1`
- Status: complete
- Context: `SPC t r` is the fast replay command, but a new tab or a tab whose
  stale object target was cleared has no current target. Requiring a separate
  `SPC t R` invocation adds an unnecessary failure step.
- Solution: when the current tab has no saved target, pass the already extracted
  text to the normal explicit target chooser. Keep existing-target replay
  prompt-free, and keep stale-target failures as errors so a partially attempted
  delivery never also opens a picker in the same invocation.
- Affected: `profiles/common/.config/emacs/init.el`,
  `profiles/common/.config/emacs/send-text-targets-test.el`, and this plan.
- Measured outcome: the focused ERT suite passed 4 of 4 tests, including exact
  text delegation for a targetless tab and completion-free replay for a tab with
  a saved target. The correctness review found no issues; `check-parens`,
  temporary byte compilation, and `git diff --check` passed.

## Follow-up F3: Unify buffer target selection

- Owner: `emacs-config-changes-followups-1`
- Status: complete
- Context: the four-class picker exposes implementation transports as top-level
  choices. A live Ghostel buffer can consequently appear as a Ghostel target, a
  raw process target, and a writable insertion target. Its writable appearance
  also changes with Ghostel input mode, and native Ghostel's associated process
  is a lifecycle event pipe rather than the PTY input boundary.
- Solution: offer exactly `zmx` and `buffer` as the require-match top-level
  choices. Preserve the existing zmx flow. For `buffer`, require Ghostel and
  enumerate each buffer once in `buffer-list` order. Classify a member of
  `ghostel-buffer-list` only as Ghostel when its associated process is live;
  include it regardless of `buffer-read-only`, and omit it rather than falling
  through when dead. Classify each remaining non-Ghostel buffer as a raw process
  target when it has a live associated process or as an insertion target when it
  is writable. When both apply, list the buffer once and prompt for `send raw
  text` or `insert at point` after buffer selection. Omit buffers with neither
  transport. Keep delivery descriptors, stale identity handling, per-tab replay,
  and non-display behavior unchanged.
- Affected: `profiles/common/.config/emacs/init.el`,
  `profiles/common/.config/emacs/send-text-targets-test.el`, and this plan.
- Success criteria: the top-level UI contains only `zmx` and `buffer`; every
  eligible buffer appears once; live Ghostel buffers remain selectable in
  read-only input modes and always use public Ghostel paste and Return; dead
  Ghostel buffers are absent; generic process and insertion behavior remains
  explicit and unchanged; targetless replay reaches the same picker.
- Measured outcome: the focused ERT suite passed 4 of 4 tests with the existing
  test count, covering exact top-level choices, ordered one-entry buffer
  classification, read-only Ghostel delivery, dead Ghostel omission, ordinary
  raw-process and insertion delivery, ambiguous operation selection, and
  targetless replay. The correctness review found no issues; `check-parens`,
  temporary byte compilation, and `git diff --check` passed with only existing
  deferred-package and free-variable warnings.

## Follow-up F4: Create terminal targets from the picker

- Owner: `emacs-config-changes-followups-1`
- Status: complete
- Context: the F3 picker can send only to existing destinations. Its buffer
  family correctly includes live Ghostel terminals, but it cannot create one
  when none exists, while zmx creation is available only through a separate key
  binding.
- Solution: offer exactly `zmx`, `buffer`, and `ghostty` as require-match
  top-level choices. Preserve F3's `buffer` behavior: list each live Ghostel
  buffer exactly once with Ghostel delivery precedence, then classify ordinary
  buffers through raw-process or insertion delivery. Under `ghostty`, also offer
  every live Ghostel buffer plus a `create new` candidate even when no Ghostel
  buffer exists. This overlap is intentional: `buffer` remains a complete picker
  for existing Emacs buffer objects, while `ghostty` owns terminal creation.
  Creation prompts for an optional name, uses the existing
  right-side split action and source directory, validates the returned public
  buffer/process pair, and sends through public Ghostel paste and Return.
  Under `zmx`, first offer `existing` or `create new` because the pinned package
  exposes no public location-aware enumeration API that can share one completion
  table with a synthetic action. Existing selection keeps the pinned private
  selector boundary. Creation prompts for a name, calls public
  `term-sessions-open` in the source directory and existing right-side split,
  then sends through public `term-sessions-send`. Both creation flows save the
  resulting descriptor only after delivery succeeds, preserve the prior target
  on cancellation or failure, and leave any successfully created visible state
  inspectable rather than attempting rollback.
- Affected: `profiles/common/.config/emacs/init.el`,
  `profiles/common/.config/emacs/send-text-targets-test.el`, and this plan.
- Success criteria: the top-level UI contains exactly `zmx`, `buffer`, and
  `ghostty`; `buffer` retains each live Ghostel target exactly once and never
  sends it through a generic transport; both terminal families expose
  `create new` without requiring an existing destination; new targets open in a
  right-side split, receive the exact selected text with their existing
  transport semantics, and become the current tab target only after successful
  delivery; existing selection and replay semantics remain unchanged.
- Measured outcome: the focused ERT suite passed 4 of 4 tests, covering both
  creation paths, delivery-before-save behavior, failure preservation, and
  distinct `buffer: <name>` labels for existing Ghostel buffers whose names
  collide with the exact `create new` action. The iterative correctness review
  found and verified the candidate-label fix, then reported no remaining
  findings. `check-parens`, temporary byte compilation, and `git diff --check`
  passed with only the existing deferred-package and free-variable warnings.

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
6. Keep `zmx`, `buffer`, and `ghostty` as the only top-level target choices.
   `buffer` selects every eligible existing buffer, gives live Ghostel targets
   exclusive transport precedence, and asks for the operation only when an
   ordinary buffer supports both raw process input and insertion. `ghostty` also
   selects an existing live Ghostel terminal or explicitly creates one. This
   family-level overlap is intentional. `zmx` selects an existing durable
   session or explicitly creates one. The chooser never infers a destination
   from the source or a last-used target; only the separately invoked replay
   command uses the current tab's remembered successful target.
7. Use public Ghostel send and enumeration APIs, standard Emacs process, buffer,
   and tab-bar APIs, and public term-sessions delivery APIs. The pinned
   term-sessions revision has no public location-aware existing-session selector,
   so F1 deliberately calls its private selector at one local selection boundary
   after loading `term-sessions-list`. Do not inspect terminal output, insert into
   rendered Ghostel buffers, call private send or tab APIs, bypass buffer
   read-only contracts, or key target state by a tab name, index, window, or
   configuration.

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

Status: complete; local integration revised by F1, replay fallback by F2,
picker unification by F3, and terminal creation completed by F4

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

| Transport | Saved descriptor | Selection and delivery boundary | Submission or mutation semantics |
| --- | --- | --- | --- |
| Durable zmx session | `(:type zmx :name NAME :directory DIRECTORY)` | The pinned private existing-session selector returns `NAME` and `DIRECTORY`; bind `default-directory` to `DIRECTORY` and call public `term-sessions-send`. | Send exact text plus one carriage return. It is a logical name-and-location address, independent of an Emacs frontend buffer. |
| Ghostel buffer | `(:type ghostel :buffer BUFFER :process PROCESS)` | `ghostel-buffer-list`, `get-buffer-process`, `process-live-p`, `ghostel-paste-string`, and `ghostel-send-key` on the returned original buffer/process pair. | Bracket-paste exact text, then send one terminal-aware Return. Validate the original process association before and after each public send so dead or replaced terminals signal locally. |
| Emacs process buffer (raw text) | `(:type process :buffer BUFFER :process PROCESS)` | `buffer-list`, `get-buffer-process`, `process-live-p`, and `process-send-string` on the original pair. | Send exact raw text with no appended carriage return or newline. The process protocol owns framing and submission. |
| Writable Emacs buffer (insert at point) | `(:type buffer :buffer BUFFER)` | `buffer-list`, `buffer-live-p`, `buffer-read-only`, and `insert` on the original buffer. | Insert exact plain text at its current point without saving, displaying, switching to, or submitting the buffer. |

The user-visible top-level choices are exactly `zmx`, `buffer`, and `ghostty`.
`buffer` includes live Ghostel targets with exclusive Ghostel delivery
precedence alongside the two ordinary buffer transports. `ghostty` intentionally
offers the same live Ghostel targets plus creation.

### Per-tab target state

The target belongs to the current tab, never to a global last-target variable.
Read the public `tab-bar-tabs` list, locate its documented `(current-tab ...)`
entry, add or replace that alist's custom `my/send-text-last-target` property,
and write the updated list with public `tab-bar-tabs-set`. Preserve the rest of
the tab entry and all other tabs. Do not use `tab-bar--*` APIs or derive identity
from a tab name, tab index, selected window, or window configuration.

- A newly created tab has no target. Switching, renaming, and moving tabs retain
  the descriptor because it travels with that tab's entry. Closing a tab discards
  it, unless Emacs tab undo restores that logical tab. Invoking replay with no
  descriptor opens the normal explicit target chooser with the same extracted
  text; a successful selection stores the chosen target on that tab.
- Store a descriptor only after the chosen delivery or creation command returns
  successfully. A canceled chooser, a selection failure, or a delivery failure
  leaves the prior descriptor intact.
- A killed or replaced Ghostel, process, or writable-buffer object invalidates
  and clears that descriptor on the attempted replay. Never resolve a same-named
  replacement. A Ghostel or generic process must still be live and still be the
  selected buffer's associated original process. Validate a Ghostel pair before
  delivery and after each public send; a failed validation signals locally. A
  writable buffer that becomes read-only rejects that attempt but retains its
  descriptor.
- A zmx descriptor remains saved when zmx reports a missing or unreachable
  session. Its `NAME` and `DIRECTORY` are the intended logical address, and
  connectivity or the named session can recover later.

### Local terminal package integration

F1 keeps both original repository URLs and restores the reachable Ghostel
revision `94eace59046c275d6c8f3c065489f6bbdb4f037b` and term-sessions revision
`0815dbea006128df1d61e9d29e5a8ada53b349c1`. No fork, unpublished commit, or
package patch is required.

Ghostel already exposes public buffer enumeration, paste, and terminal-aware key
sends. Its native and Emacs PTY paths also associate their lifecycle process with
the Ghostel buffer, so `init.el` stores that public `get-buffer-process` result
with the buffer. A target is live only while the original buffer remains in
`ghostel-buffer-list`, the original process remains live, and it remains the
buffer's associated process. Check that identity before delivery and after paste
and Return. Do not read `ghostel--process`, `ghostel--term`, or other private
Ghostel state.

The pinned term-sessions revision already contains the required location-aware
selection behavior as `term-sessions--read-existing-session-entry`, but it is
private and only includes known local and TRAMP rows after `term-sessions-list`
is loaded. The zmx chooser explicitly requires `term-sessions-list` and calls
that selector inline at its single use. All zmx delivery and creation remain on
public `term-sessions-send` and `term-sessions-open`. Do not copy the selector,
advise completion, shell out to zmx, or open a frontend solely to discover
identity. The revision pin makes this narrow private dependency auditable.

### Changes

1. Replace `my/term-sessions-send-text` with two transport entry points:

   - `my/send-text-to-target TEXT` always prompts first for a target class and
     then for its concrete target. It delivers before recording the resulting
     descriptor on the current tab.
   - `my/send-text-send-to-last-target TEXT` reads only the current tab's
     `my/send-text-last-target` descriptor. With one, it replays without a
     prompt. With none, it delegates the same TEXT to `my/send-text-to-target`
     so the normal explicit picker performs and records the first delivery.

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
3. The chooser uses require-match native completion. Its top-level choices are
   exactly `zmx`, `buffer`, and `ghostty`. `buffer` presents one concrete
   candidate per eligible buffer, giving a live Ghostel target exclusive
   Ghostel delivery precedence. An ordinary buffer supporting both raw process
   input and insertion receives a final require-match operation prompt with
   exactly `send raw text` and `insert at point`. The chooser never supplies a
   last-used default or infers a destination. A successful explicit delivery
   replaces only the current tab's descriptor.
4. In the zmx chooser branch, offer exactly `existing` and `create new`.
   `existing` requires `term-sessions-list`, calls the pinned private
   `term-sessions--read-existing-session-entry` selector inline, and saves its
   `:name` and `:directory`. `create new` captures the source directory, prompts
   for a name, and calls public `term-sessions-open` with the existing right-side
   split action before delivery. Bind `default-directory` to the selected or
   created directory, then call public `term-sessions-send` with `(concat text
   "\r")`. In replay, use only the stored name and directory and do not re-run a
   selector. Keep zmx errors as errors and retain an existing replay descriptor.
   A create-and-send failure preserves the prior descriptor and does not roll
   back an opened buffer or possibly created session.
5. In the ghostty chooser branch, defer `(require 'ghostel)` until `ghostty` is
   selected. Build unambiguous require-match candidates from live targets in
   `ghostel-buffer-list` and append `create new`, which remains available when
   there are no existing buffers. Existing selection stores the returned buffer
   and process objects, not a name. Creation captures the source directory,
   prompts for an optional buffer name, calls public `ghostel-create` with the
   existing right-side split action, and validates the returned public pair.
   Before delivery and after each public send,
   require the original buffer to be live, remain a member of
   `ghostel-buffer-list`, retain the original associated process, and keep that
   process live. Clear a replay descriptor when validation fails. In the buffer,
   call `ghostel-paste-string` with the text and then `ghostel-send-key` with
   `"return"`. If paste succeeds and Return or a post-send validation fails,
   preserve the annotation queue and chooser's prior descriptor because the
   terminal may already have pasted input; this deliberately non-atomic send is
   neither rollback-safe nor retry-idempotent. Do not inspect Ghostel private
   identity or PTY state, call `ghostel--send-string`, use the generic process
   branch, or insert into the rendered terminal buffer.
6. In the buffer chooser, recognize members of `ghostel-buffer-list` first.
   Include each live Ghostel target once regardless of read-only state, use its
   Ghostel descriptor, and omit a dead Ghostel target instead of allowing it to
   fall through to a generic transport. For each remaining buffer with a live
   associated process, make raw process delivery available and store both
   original objects.
   Before delivery or replay, require a live original buffer, a live original
   process, and `(eq PROCESS (get-buffer-process BUFFER))`. Send the exact text
   once with `process-send-string`, with no added terminator and no Comint,
   compilation, terminal, or mode-specific submission command. On failed object
   identity or association validation, clear this tab's descriptor and signal
   `user-error` rather than targeting a replacement.
7. For each non-Ghostel writable buffer, make insertion available, including for
   file-backed, scratch, generated, and other in-memory buffers. If the same
   buffer also has a live process, list it once and ask which operation to use
   after selection. Store the original buffer object for insertion. On delivery
   or replay, a killed object clears this tab's descriptor;
   a still-live buffer that has become read-only signals `user-error` but retains
   it. Otherwise insert exact plain text at its current point, leaving point after
   the text and the buffer modified without saving, displaying, switching to, or
   interpreting it. Never use `inhibit-read-only` or a same-named replacement.
8. Bind `SPC t R` and visual `C-c C-c` to the chooser source command. Bind
   `SPC t r` and visual `C-c C-r` to the replay source command. Update Which Key
   descriptions, docstrings, mapping documentation, and tests to use these names
   and the exact target labels. `my/annotate-send-all` always calls the chooser
   transport and clears `my/annotations` only after successful delivery; it never
   uses replay.
9. Add `my/create-ghostel-terminal-in-split`, bound to `SPC t g`. Prompt for an
   optional Ghostel buffer name before changing layout, preserve the caller's
   `default-directory`, and call public `ghostel-create NAME DISPLAY-ACTION`.
   `DISPLAY-ACTION` uses public `display-buffer-in-direction` with direction
   `right` and `window-width` `0.5` for an equal-width side-by-side split, with
   the new window on the right. After its successful return, capture and validate
   the associated public process, then store `(:type ghostel :buffer BUFFER
   :process PROCESS)` on the current tab. This creates a Ghostel terminal and
   buffer; zmx owns durable sessions.
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
    contract. A new tab's replay delegates the same text to the chooser, while a
    tab with an existing target replays without invoking completion.
  - A chooser selection or delivery failure preserves the old descriptor. Only a
    successful chooser delivery changes the current tab's descriptor; it does
    not change another tab's target.
  - The zmx chooser receives an entry with both name and directory, and chooser
    and replay bind that directory before calling `term-sessions-send` with exact
    text plus exactly one character 13 carriage return. Missing or unreachable
    zmx errors keep the descriptor.
  - The Ghostel branch requires Ghostel only after its class is selected, maps
    completion to buffers from `ghostel-buffer-list` with live associated
    processes, stores the original buffer/process pair, validates that identity
    before and after each public send, pastes before Return, and rejects a killed,
    exited, restarted, or same-named replacement by clearing the saved replay
    target. Paste, Return, and post-send validation failures preserve the
    annotation queue.
  - The process branch stores and rechecks the original buffer/process pair,
    sends exact raw text with no added terminator, and clears a dead, killed, or
    replaced pair rather than resolving by name.
  - The writable-buffer branch inserts once at the original object's current
    point without saving or switching. A killed or replaced object clears the
    descriptor; becoming read-only rejects the send and retains it.
  - The top-level completion contains exactly `zmx`, `buffer`, and `ghostty`.
    Buffer completion contains each eligible object exactly once, includes live
    Ghostel targets with Ghostel delivery precedence, omits dead Ghostel targets,
    and asks explicitly between `send raw text` and `insert at point` for a
    writable process-backed ordinary target. Ghostty completion contains each
    live Ghostel target plus `create new`, and still offers creation with no
    existing target. Zmx completion offers `existing` and `create new`; the
    creation path works with no existing session.
    Annotation delivery uses the chooser and clears the queue only after success.
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
- `SPC t R` and visual `C-c C-c` always select `zmx`, `buffer`, or `ghostty` and
  a concrete existing or explicitly created target. `SPC t r` and visual
  `C-c C-r` replay only the current tab's
  last successful target without prompting, or open the same explicit picker
  when that tab has no saved target.
- Target state is a public-tab-bar property with the documented tab lifetime and
  never leaks between tabs or falls back to a name-, index-, window-, or
  configuration-keyed global.
- Each class preserves its target-specific submission, mutation, lifetime, and
  stale-identity semantics. zmx is stored as a recoverable name-and-directory
  logical address; buffer and process targets are object identities.
- The pinned upstream Ghostel revision uses public enumeration and send APIs plus
  the original public Emacs process association. The pinned upstream
  term-sessions revision is isolated behind one documented private selector call;
  zmx delivery and creation remain public.
- Ghostel creation is a terminal/buffer flow; durable sessions are owned by zmx.
- Narrowed-source extraction and annotation line numbers follow their documented
  accessible-text and absolute-location contracts. Annotation Markdown remains
  structurally valid for any contiguous backtick run, and its queue survives any
  signaled selection or delivery failure.

### Measured outcome

- Package-local API experiments established the liveness and location-aware
  selection behavior, but F1 supersedes those unpublished commits with local
  integration against reachable upstream pins.
- The configuration's four focused ERT tests passed, including source and
  annotation behavior, all four transports, stale-target handling, per-tab
  lifetime, the flipped `SPC t r` replay and `SPC t R` chooser mappings, and both
  split creation flows. A real public `tab-bar-tabs` persistence probe reported
  `TAB_STATE_OK`; `check-parens`, temporary byte compilation, guarded startup,
  and `git diff --check` also passed.
- F2 updated the replay contract so a targetless tab opens the normal explicit
  picker with the same extracted text. Existing-target replay remains
  completion-free, and a stale target still clears and signals without opening
  the picker during that failed attempt. The focused suite and correctness
  review passed after the change.
- F3 reduced the top-level picker to `zmx` and `buffer`. The buffer path lists
  each eligible object once, gives Ghostel exclusive precedence regardless of
  read-only input mode, omits dead Ghostel buffers, and asks for an operation
  only when a non-Ghostel buffer supports both raw process input and insertion.
  The focused suite and correctness review passed after the change.
- Fresh provisioning from the original Ghostel and term-sessions repository URLs
  installed the restored reachable revisions exactly, and guarded isolated
  startup loaded the local integration without package or network activity.
- Real Ghostel PTY, zmx, and interactive TTY checks passed in Phase 5. TRAMP,
  graphical, and visual Neovim glyph checks remain environment-dependent.

## Phase 5: Final acceptance and documentation reconciliation

Status: complete

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
  explicit chooser delivery, no-target replay through the picker, and distinct
  prompt-free per-tab replay after switching, renaming, moving, closing, and
  undoing tabs.
- Narrowed-source, absolute annotation line-number, arbitrary-backtick Markdown
  fence, killed/replaced target, read-only destination, and annotation-queue
  failure checks from Phase 4.
- The pinned term-sessions private existing-session selector returns both name
  and directory after `term-sessions-list` is loaded. Confirm chooser and replay
  bind the selected directory and send exactly one appended carriage return
  through public `term-sessions-send`.
- The pinned Ghostel revision exposes public buffer enumeration, paste, and key
  sends. Confirm the locally stored buffer/process pair rejects dead, restarted,
  exit-racing, or replaced Ghostel targets before they can be remembered as
  successful deliveries.
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

### Measured outcome

- The reserved `gpt-5.6-sol` completion review found no substantive
  implementation defect across the four phase commits or the Phase 5 cleanup.
  Its one low-severity docstring finding was corrected and the focused suite
  remained green. The F1 local-integration correctness review also completed
  with no findings.
- `check-parens` and temporary byte compilation passed for `init.el`, both
  provisioners, the focused ERT file, and the theme. A genuinely new guarded
  batch process reported `GUARDED_CLEAN_STARTUP_OK` with package, VC, URL,
  grammar, and module provisioning disabled. The focused configuration suite
  passed 4 of 4 tests, Ghostel's pure-Elisp suite passed 64 of 64 tests,
  term-sessions passed 123 of 123 tests under UTC, the complete Ghostel native
  target passed with 8 environment-dependent skips, `bash -n` passed, and
  `git diff --check` passed in all three repositories.
- A Ghostel 0.52 module built from the restored original-upstream checkout
  completed a real PTY paste-and-Return delivery through the locally stored
  buffer/process pair. A real location-aware selector from the restored
  term-sessions checkout selected, delivered to, and cleaned up an isolated
  temporary zmx session. Real raw-process and writable-buffer delivery also
  passed. Public tab-bar state survived real tab creation, switching, renaming,
  moving, closing, and undo after correcting the pre-existing
  `tab-bar-select-tab-modifiers` value from `super` to `(super)`.
- F1 provisioned a genuinely empty package directory from the tracked original
  URLs. Ghostel and Evil Ghostel installed at
  `94eace59046c275d6c8f3c065489f6bbdb4f037b`, and term-sessions installed at
  `0815dbea006128df1d61e9d29e5a8ada53b349c1`. The installer returned success;
  its optional difftastic test files emitted pre-existing compile failures for
  the absent test-only `el-mock` dependency without preventing installation.
  Descriptor checks confirmed the exact revisions and confirmed that Doom
  Modeline, Nerd Icons, and Shrink Path were absent. A guarded isolated startup
  then loaded the configuration with package installation entry points replaced
  by errors and reported the expected local APIs, flipped bindings, tab option,
  and absent removed features.
- The final one-warmup, five-run sample was 3.208374, 3.110362, 3.223818,
  3.146612, and 3.349866 seconds. Mean was 3.207806 seconds, median was 3.208374
  seconds, sample standard deviation was 0.091758 seconds, and range was
  3.110362-3.349866 seconds. Compared with the documented 1.977039-second
  baseline, the observed mean increased by 1.230767 seconds, or 62.3 percent.
- An Expect-backed pseudo-terminal opened `emacs -nw` successfully and exposed
  the textual `NORMAL` state, modified marker, buffer identity, project,
  modes, and position in the terminal mode line. Screenshot validation was
  omitted by explicit user instruction. Graphical interaction, visual Neovim
  key routing and glyph rendering, live TRAMP delivery, interactive split
  placement, and a full macOS provisioner rerun remain environment-dependent
  acceptance gaps.

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
- Source text can explicitly select `zmx`, `buffer`, or `ghostty`. The terminal
  families can select an existing destination or explicitly create one, while
  buffer selection chooses each eligible object once and preserves its Ghostel,
  raw-process, or insertion transport. Deliberate replay uses the
  last successful target of the current tab and falls back to explicit selection
  when that tab has none. Annotation queues always use explicit selection and
  clear only after success.
- Which Function covers every supporting major mode without broadening the
  explicit Tree-sitter parser, folding, and Evil motion matrix.
- No private Ghostel or tab-bar implementation API is introduced. The only
  private term-sessions dependency is its pinned location-aware selector at the
  documented local chooser boundary.

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
