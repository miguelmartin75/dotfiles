# Org and Markdown Table Cell-Wrap Support

## Status

- Overall: complete, 3/3 phases complete
- Current phase: N/A

Phase status:

- Phase 1: complete
- Phase 2: complete
- Phase 3: complete

Final review:

- Status: complete, no findings.
- The complete three-phase implementation was reviewed against this plan for
  provisioning, mode integration, keybinding behavior, source preservation,
  exclusions, regression coverage, scope, and repository guidelines.

Update this section during execution whenever a phase starts or completes.

## Goal

Make wide Org and Markdown pipe tables readable inside the active Emacs
window by enabling cell-aware, display-only wrapping through
`markdown-table-wrap-pretty`.

The primary implementation target is
`profiles/common/.config/emacs/init.el`. The implementation must cover Org,
classic `markdown-mode`, `gfm-mode`, and Emacs 31's built-in
`markdown-ts-mode`. It must preserve the canonical one-line-per-row table
source used by saving, copying, searching, exporting, Git, Org formulas, and
Markdown renderers.

The result is a pretty reading view, not a multiline source-table editor.
Editing a displayed table must reveal its raw source automatically. The user
can then toggle the table back to its wrapped view.

## Relevant Code

- `profiles/common/.config/emacs/init.el:1-16` documents explicit package
  provisioning and the requirement that normal startup remain offline.
- `profiles/common/.config/emacs/init.el:264-266` configures Olivetti, whose
  narrower text area must be respected by table rendering.
- `profiles/common/.config/emacs/init.el:385` enables Visual Line mode
  globally. That mode wraps complete source lines and does not understand
  table cell boundaries.
- `profiles/common/.config/emacs/init.el:677-681` configures fallback
  `markdown-mode` and is the appropriate neighborhood for the shared pretty
  table package declaration.
- `profiles/common/.config/emacs/init.el:1131-1144` dispatches Markdown table
  alignment to the selected Markdown implementation.
- `profiles/common/.config/emacs/init.el:1148-1167` installs Markdown-local
  Evil structure and table bindings, including `SPC o m` for alignment.
- `profiles/common/.config/emacs/init.el:1262-1263` installs the shared
  Markdown setup in `markdown-ts-mode` and classic Markdown buffers.
- `profiles/common/.config/emacs/init.el:1314-1430` contains the main Org
  configuration.
- `profiles/common/.config/emacs/init.el:1721-1830` defines the shared leader
  map and its `SPC o` commands.
- `profiles/common/.config/emacs/init.el:1866-1879` exposes the shared leader
  map in Evil normal and visual states.
- `profiles/common/.config/emacs/install-packages.el:10-44` declares and
  verifies packages installed from pinned Git revisions.
- `profiles/common/.config/emacs/markdown-parity-test.el:340-429` verifies
  effective Markdown and Org bindings and is the existing integration-test
  surface for the shared editing workflow.
- `dev/plans/6-emacs-md-and-org-alignment.md` documents the base Org and
  Markdown editing contract.
- `dev/plans/6-emacs-md-and-org-alignment-followups.md` documents the current
  list, table, and `RET` behavior that this work must preserve.

## Verified Constraints

### Pipe-table semantics

Neither GFM nor native Org pipe tables have a multiline cell representation.
A physical newline terminates the source row. Rewriting a long cell as
several pipe-table lines would therefore create additional logical rows for
Markdown renderers and Org's table machinery.

`markdown-table-wrap-pretty` avoids that problem by leaving the buffer text
unchanged and placing wrapped display overlays over each raw table line. Its
modification hooks remove those overlays before an edit, so native Org,
Markdown, Evil, undo, and export continue operating on canonical source.

### Package behavior

The reviewed upstream baseline is commit
`f846b77d13f34fba57c80214c1a61e00c94048a3`, dated 2026-08-06. The repository
contains both `markdown-table-wrap.el` and the optional
`markdown-table-wrap-pretty.el` companion. Only one package checkout is
required.

The minor mode provides:

- Per-cell wrapping within a width allocated to each column.
- A shared visual row height based on the tallest wrapped cell.
- Unicode box borders by default.
- Lossless rerendering after window-width changes, debounced by 0.3 seconds.
- Point-aware, region-aware, and whole-buffer toggling through
  `markdown-table-wrap-pretty-toggle`.
- Org hline normalization from `|---+---|` to the parser's internal form.
- Display-only removal of Org width cookies such as `<20>` and `<r10>`.
- Preservation of a following `#+TBLFM:` line outside the table overlay.
- Rejection of Markdown fenced tables and Org source-block tables.

Tables start raw by default even when the minor mode is enabled. Automatic
pretty display requires listing each exact `major-mode` symbol in
`markdown-table-wrap-pretty-default-on-major-modes`.

### Mode integration

The exact default-pretty list must be:

```elisp
'(org-mode markdown-mode gfm-mode markdown-ts-mode)
```

Only these three hooks are required:

```elisp
org-mode-hook
markdown-mode-hook
markdown-ts-mode-hook
```

Do not add `gfm-mode-hook`. The installed `gfm-mode` runs its parent
`markdown-mode-hook`, so the shared Markdown hook already enables the minor
mode. `gfm-mode` must still appear in the exact default-pretty list because
the upstream option compares the value of `major-mode` directly.

Emacs 31 defines `markdown-ts-mode` from `text-mode` and then registers
`markdown-mode` as an additional derived parent. Consequently, the upstream
`derived-mode-p 'markdown-mode` branch already applies its Markdown code-fence
guard in built-in `markdown-ts-mode`. Do not add advice, a mode shim, or a
second fence parser.

## Decisions

1. Use `markdown-table-wrap-pretty` as the single Org and Markdown display
   layer. Do not implement a repository-owned renderer.
2. Keep source tables canonical. Do not insert backslashes, `<br>` tags,
   continuation rows, hard line breaks, or `table.el` syntax.
3. Pin the upstream repository through the existing `package-vc` provisioner
   at `f846b77d13f34fba57c80214c1a61e00c94048a3`. A pinned revision is preferred
   because this young display package controls overlays, modification hooks,
   and window-resize behavior in core writing modes.
4. Keep installation outside normal startup. Do not add `:ensure`, package
   refreshes, or `package-vc-install` calls to `init.el`.
5. Enable the minor mode and initial pretty display automatically in every
   configured Org and Markdown mode.
6. Preserve the upstream defaults for Unicode borders, resize rerendering,
   and the 0.3 second resize debounce. Add configuration only where the
   desired behavior differs from upstream defaults.
7. Bind the shared toggle to `SPC o w` through `my/leader-map`. Do not add
   duplicate bindings to three major-mode maps.
8. Preserve `SPC o m` as Markdown table alignment and all native Org and
   Markdown table navigation and mutation commands.
9. Accept unsupported table shapes by leaving them raw. Do not add local
   parsing workarounds around the upstream package.

## Target Behavior

| Context | Initial display | Edit behavior | `SPC o w` |
| --- | --- | --- | --- |
| Org table with header, hline, and body | Pretty and cell-wrapped | Reveal raw source | Toggle table at point |
| GFM table in `markdown-mode` | Pretty and cell-wrapped | Reveal raw source | Toggle table at point |
| GFM table in `gfm-mode` | Pretty and cell-wrapped | Reveal raw source | Toggle table at point |
| GFM table in `markdown-ts-mode` | Pretty and cell-wrapped | Reveal raw source | Toggle table at point |
| Point outside a table | Existing tables retain their state | Native editing | Toggle all recognized tables |
| Active visual region | Recognized tables retain their state | Native Evil selection | Toggle overlapping tables |
| Markdown fenced code block | Raw | Native code editing | Ignore table-like lines |
| Org source block | Raw | Native source editing | Ignore table-like lines |
| Org `#+TBLFM:` line | Raw and visible | Native formula editing | Never cover or modify it |
| Unsupported table shape | Raw | Native editing | Leave unchanged |

## Accepted Upstream Limitations

- A recognized table requires a separator row and a header before it.
- Header-only tables are not decorated because the renderer requires at least
  one body row.
- Separatorless Org tables therefore remain raw.
- Table lines must begin with optional whitespace followed by `|`. Borderless
  GFM tables are unsupported.
- Markdown fenced code blocks are excluded, but indented code blocks are not
  covered by the package's explicit fence guard.
- The display is implemented with buffer overlays. If one buffer is visible
  in two windows with different widths, it cannot have a distinct rendering
  width in each window simultaneously.
- The renderer recognizes Markdown inline spans. Org-specific inline markup,
  especially Org links, may remain visually literal inside the pretty table.
- Editing removes the pretty overlay and leaves the table raw until the user
  toggles it again. Do not add automatic idle redisplay after edits without a
  separate user requirement.

## Phase 1: Provision the Reviewed Package

Status: complete.

1. Add `markdown-table-wrap` to the `vc-packages` list in
   `profiles/common/.config/emacs/install-packages.el`.
2. Use the repository URL
   `https://github.com/dnouri/markdown-table-wrap.git` and pin commit
   `f846b77d13f34fba57c80214c1a61e00c94048a3`.
3. Do not declare `markdown-table-wrap-pretty` as a second package. The pinned
   checkout supplies both library files.
4. Run the package provisioner twice to exercise installation and the
   existing revision/idempotency check.
5. In a clean batch Emacs process, initialize packages and verify that both
   `markdown-table-wrap` and `markdown-table-wrap-pretty` can be located and
   required.

Success criteria:

- The provisioner installs the exact reviewed commit.
- Both libraries are available after provisioning.
- A second provisioner run succeeds without changing the installed revision.
- Normal Emacs startup still performs no network access or package
  installation.

Implementation result:

- Added the single pinned `markdown-table-wrap` checkout to the explicit VC
  provisioner. In an isolated package directory, the provisioner installed
  revision `f846b77d13f34fba57c80214c1a61e00c94048a3`, completed a second
  idempotent run, and a clean batch process located and required both supplied
  libraries. The isolated run avoided an unrelated locally installed Ghostel
  revision that does not match its existing repository pin.

## Phase 2: Configure Pretty Tables and the Shared Toggle

Status: complete.

1. Add a `use-package markdown-table-wrap-pretty` declaration near the
   existing `markdown-mode` declaration in
   `profiles/common/.config/emacs/init.el`.
2. Defer the public minor mode and toggle commands. Do not use
   `:after (markdown-mode org markdown-ts-mode)`, because waiting for every
   listed feature would couple activation to unrelated mode load order.
3. Set `markdown-table-wrap-pretty-default-on-major-modes` during `:init` to
   the exact four-mode list documented above so hook execution decorates
   existing tables immediately.
4. Enable `markdown-table-wrap-pretty-mode` from `org-mode-hook`,
   `markdown-mode-hook`, and `markdown-ts-mode-hook` through the same
   `use-package` declaration.
5. Do not customize the renderer's border, resize, or debounce options. Their
   upstream defaults already match the target behavior.
6. Add `("o w" . markdown-table-wrap-pretty-toggle)` to the shared leader
   binding list. This supplies `SPC o w` in Evil normal and visual states via
   the existing leader-map parents.
7. Do not modify `my/markdown-align-table`, `my/markdown-setup`, Org's `RET`
   binding, or native table keymaps. Pretty rendering must remain orthogonal
   to table structure and mutation.

The intended configuration shape is:

```elisp
(use-package markdown-table-wrap-pretty
  :commands (markdown-table-wrap-pretty-mode
             markdown-table-wrap-pretty-toggle)
  :init
  (setq markdown-table-wrap-pretty-default-on-major-modes
        '(org-mode markdown-mode gfm-mode markdown-ts-mode))
  :hook
  ((org-mode . markdown-table-wrap-pretty-mode)
   (markdown-mode . markdown-table-wrap-pretty-mode)
   (markdown-ts-mode . markdown-table-wrap-pretty-mode)))
```

Success criteria:

- Opening any of the four target modes enables the minor mode.
- Recognized tables already present when the mode hook runs start pretty.
- `SPC o w` toggles the table at point, all tables when point is outside a
  table, and overlapping tables for an active region.
- `SPC o m` and all existing table commands retain their current bindings.
- Reloading `init.el` does not install or update packages.

Implementation result:

- Added the shared deferred package declaration with the exact four-mode
  default list and the three required hooks. Added `SPC o w` through
  `my/leader-map`; batch checks confirmed immediate decoration in all four
  modes while preserving the existing Markdown alignment binding.

## Phase 3: Add Focused Regression Coverage and Validate Display Behavior

Status: complete.

1. Extend `profiles/common/.config/emacs/markdown-parity-test.el` with one
   focused integration test instead of duplicating the upstream renderer's
   unit-test suite.
2. Exercise `org-mode`, `markdown-mode`, `gfm-mode`, and
   `markdown-ts-mode` with recognized table fixtures. Assert that:

   - `markdown-table-wrap-pretty-mode` is enabled after mode setup.
   - `SPC o w` resolves to `markdown-table-wrap-pretty-toggle` in Evil normal
     and visual states.
   - The source buffer string is unchanged after pretty rendering.
   - Public toggle commands add and remove visible table overlays.
   - Editing a pretty table removes its overlays and changes only the user
     insertion.

3. In the same test, cover one Markdown fenced table and one Org source-block
   table. Assert that neither receives a pretty overlay. This specifically
   verifies the effective integration with built-in `markdown-ts-mode` and
   Org's source-block detection.
4. Do not test private implementation functions or duplicate upstream cases
   for parsing, wrapping algorithms, Unicode widths, or inline markup. The
   repository test owns only configuration, source preservation, mode
   coverage, and keybinding integration.
5. Run the complete existing Markdown parity test file:

   ```sh
   emacs --batch -Q \
     -l profiles/common/.config/emacs/markdown-parity-test.el \
     -f ert-run-tests-batch-and-exit
   ```

6. Run `check-parens` on `init.el`, `install-packages.el`, and the changed test
   file, then run `git diff --check`.
7. Perform visible-window checks that a headless ERT test cannot represent
   faithfully:

   - Open a wide GFM table in `markdown-ts-mode`, `markdown-mode`, and
     `gfm-mode`; verify that a long middle cell wraps within its column and
     that neighboring cells retain their row association.
   - Open an Org table using `|---+---|`, width cookies, and a following
     `#+TBLFM:` line; verify wrapping, formula visibility, and unchanged raw
     source.
   - Narrow and widen the window and verify that currently pretty tables
     rerender after the debounce while tables toggled raw remain raw.
   - Repeat in `my/write-mode` and `my/write-mode-no-zoom` to verify interaction
     with Olivetti's narrowed body width.
   - Insert text, undo it, align the table, traverse cells, and add or move a
     row in both Org and Markdown. Verify that the overlay reveals raw source
     before mutation and that native behavior remains correct.

Success criteria:

- The focused integration test passes in all four target modes.
- All existing Markdown and Org parity tests continue to pass.
- Wide middle cells wrap independently without changing row association.
- Saving, copying, searching, Org formulas, and Markdown rendering continue
  to observe the original canonical pipe-table source.
- Window and Olivetti width changes rerender pretty tables without buffer
  mutations.
- Editing, undo, alignment, navigation, and structural table commands remain
  correct after a table has been prettified.
- Unsupported table shapes fail safely by remaining raw.

Implementation result:

- Added one focused integration test covering automatic activation, shared
  Evil bindings, source preservation, public toggling, edit-time reveal, and
  fenced or source-block exclusion across the four target modes. The complete
  parity suite passed 6/6. A visible 200-column terminal-window probe confirmed
  cell wrapping, Org cookie and formula handling, debounced narrow and wide
  rerendering, raw-state preservation, and both Olivetti writing widths without
  source changes. Focused native workflow probes also passed for editing, undo,
  alignment, traversal, row insertion, and row movement.

## Overall Success Criteria

- Org, `markdown-mode`, `gfm-mode`, and `markdown-ts-mode` share one
  cell-aware pretty-table workflow.
- Wide tables fit the active writing width without physical multiline cells
  or changed export semantics.
- Every recognized table defaults to pretty display and has a consistent
  `SPC o w` raw/pretty toggle.
- Markdown fences and Org source blocks are not misidentified as tables.
- The package is reproducibly pinned and normal startup remains offline.
- Existing Evil, Org, and Markdown table behavior is preserved.

## External References

- Package repository and usage:
  https://github.com/dnouri/markdown-table-wrap
- Pretty display implementation:
  https://github.com/dnouri/markdown-table-wrap/blob/f846b77d13f34fba57c80214c1a61e00c94048a3/markdown-table-wrap-pretty.el
- Emacs 31 `markdown-ts-mode` implementation and derived-parent declaration:
  https://github.com/emacs-mirror/emacs/blob/master/lisp/textmodes/markdown-ts-mode.el
- GFM table syntax:
  https://github.github.com/gfm/#tables-extension
- Org table syntax and width cookies:
  https://orgmode.org/manual/Built_002din-Table-Editor.html
