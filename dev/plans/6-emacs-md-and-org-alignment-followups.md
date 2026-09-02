# Org and Markdown Editing Alignment Follow-ups

## Status

- Overall: complete, 3/3 phases complete
- Current phase: N/A
- Parent plan: `dev/plans/6-emacs-md-and-org-alignment.md`

Phase status:

- Phase 1: complete
- Phase 2: complete
- Phase 3: complete

## Goal

Finish the Org and Markdown editing parity work in two areas:

1. Replace the vendored `org-autolist` implementation with a small, local,
   list-aware `RET` contract. `RET` creates or splits an item only when point
   is inside a list item and otherwise preserves the active mode's native
   behavior.
2. Make Markdown `M-j` and `M-k` operate on the structure actually at point.
   Headings, list items, and table rows keep their structural movement, while
   ordinary prose swaps with the immediately adjacent paragraph without ever
   moving its enclosing heading.

The result must work in Org, `markdown-ts-mode`, and fallback `markdown-mode`.
It must use the selected upstream mode commands where they already implement
the required behavior and add only the missing paragraph-region operation.

## Historical Relevant Code (Pre-implementation Baseline)

The following pointers record the configuration before this follow-up was
implemented. They are retained as historical evidence and do not describe the
current runtime.

- `profiles/common/.config/emacs/init.el:85-93` reloads repository-owned Emacs
  files and still includes `org-autolist.el`.
- `profiles/common/.config/emacs/init.el:674-676` configures fallback
  `markdown-mode`.
- `profiles/common/.config/emacs/init.el:678-716` defines the shared Markdown
  structural dispatcher and the four structural commands.
- `profiles/common/.config/emacs/init.el:783-802` installs Markdown-local Evil
  bindings.
- `profiles/common/.config/emacs/init.el:883-897` registers the shared Markdown
  setup hooks.
- `profiles/common/.config/emacs/init.el:984` disables electric indentation in
  Org buffers.
- `profiles/common/.config/emacs/init.el:1102-1108` requires and enables
  `org-autolist`.
- `profiles/common/.config/emacs/org-autolist.el:75-131` advises `org-return`
  with list insertion, empty-item, description-list, and link behavior.
- `profiles/common/.config/emacs/org-autolist.el:133-197` adds unrelated
  Backspace advice and controls both pieces through a minor mode.
- `profiles/common/.config/emacs/markdown-parity-test.el:15-79` tests Markdown
  heading, list, and table movement.
- `profiles/common/.config/emacs/markdown-parity-test.el:81-180` tests effective
  Markdown, Org, and global binding scope.
- `dev/plans/6-emacs-md-and-org-alignment.md` documents the completed base
  implementation and the original parity contract.

## Verified Pre-implementation Behavior (Historical)

The following observations record the baseline behavior before the completed
implementation described below.

### Return behavior

The effective Evil insert-state commands are:

| Mode | Current `RET` command | Result after `- some list` |
| --- | --- | --- |
| Org | advised `org-return` | Creates `- ` through `org-autolist` |
| `markdown-ts-mode` | `markdown-ts-newline` | Inserts an indented continuation line |
| `markdown-mode` | `markdown-enter-key` | Inserts a plain newline with the current setting |

The relevant upstream commands already provide most of the target behavior:

- `markdown-ts-insert-list-item` creates a sibling at the end of an item,
  splits text at point, increments ordered markers, and delegates to
  `markdown-ts-newline` outside a list.
- `markdown-enter-key` creates or splits an item when
  `markdown-indent-on-enter` is `indent-and-new-item`, and otherwise retains
  its table and ordinary newline behavior.
- `org-insert-item` creates or splits an item at point, increments ordered
  markers, and can preserve a checkbox when passed a non-nil checkbox argument.
- `org-return` remains the correct fallback for Org paragraphs, headings,
  links, tables, and other non-list contexts.

Emacs maps the graphical `[return]` function event to ASCII `RET` through
`function-key-map`. Tree-sitter Markdown also owns a direct `<return>` binding
inside its table minor map. The follow-up must bind `RET` only and must not add
a broad `<return>` override.

### Structural movement behavior

Org `org-metaup` and `org-metadown` move the object at point:

- A heading line moves its subtree.
- A list marker moves its item tree.
- A table location moves its row.
- An ordinary paragraph swaps with the previous or next Org element instead of
  moving the enclosing heading.

The current Markdown commands differ. Outside a table,
`my/markdown-move-up` and `my/markdown-move-down` always delegate to an
upstream subtree command. In both Markdown implementations, point in body text
under a heading can therefore move the entire enclosing heading and its body.

The generic `transpose-paragraphs` command is not a safe replacement. Verified
probes moved prose before its heading and across Markdown structural
boundaries. Paragraph movement needs exact regions and explicit boundary
checks.

## Decisions

1. Delete `profiles/common/.config/emacs/org-autolist.el`. Do not replace its
   obsolete global advice with modern advice or another minor mode.
2. Keep the replacement focused on `RET`. Do not reproduce the old Backspace,
   empty-item outdent/delete, description-list, or link special cases.
3. Bind only `RET`. Preserve function-event translation and the native
   Tree-sitter table `<return>` map.
4. Use public upstream insertion commands. Do not parse Markdown list markers
   in repository code when the selected mode already owns that contract.
5. Treat an item continuation line as part of its containing list item. `RET`
   there splits a sibling item, and `M-j` or `M-k` moves the containing item.
6. Preserve the upstream Tree-sitter Markdown task-list limitation:
   `markdown-ts-insert-list-item` creates a plain sibling bullet instead of an
   unchecked task item. Org and fallback Markdown preserve checkboxes. Do not
   add a regex-based post-insertion repair.
7. Implement paragraph movement as an exact swap of two adjacent paragraph
   bodies using `transpose-regions`. Preserve the separator between them and
   never cross a structural or section boundary.
8. Support point-driven movement and a visual selection contained within one
   paragraph. Reject a visual selection spanning multiple paragraphs before
   changing the buffer.
9. Use a user error at a buffer, section, or structural boundary. Boundary
   failure must leave text, point, mark, and narrowing unchanged.

## Target Behavior

### List-aware `RET`

| Context | Org | `markdown-ts-mode` | `markdown-mode` |
| --- | --- | --- | --- |
| Ordinary prose | Native `org-return` | Native `markdown-ts-newline` fallback | Native `markdown-enter-key` fallback |
| Heading | Native `org-return` | Native newline fallback | Native newline fallback |
| Unordered item at end | Create sibling item | Create sibling item | Create sibling item |
| Middle of item text | Split into sibling items | Split into sibling items | Split into sibling items |
| Item continuation line | Split into sibling items | Split into sibling items | Split into sibling items |
| Ordered item | Increment the marker | Increment the marker | Increment the marker |
| Checked or unchecked task | Create unchecked task item | Create plain sibling bullet | Create unchecked task item |
| Empty item | Create another item through `org-insert-item` | Keep upstream Tree-sitter behavior | Keep upstream fallback behavior |
| Table | Keep native table behavior | Keep native table minor-map behavior | Keep native table behavior |
| Code block | Keep native Org behavior | Keep native code-block minor-map behavior | Keep native Markdown behavior |

Empty-item exit parity and Tree-sitter task-marker parity are intentionally
outside this follow-up. They require policy or parser-specific behavior beyond
the requested create-and-split contract.

### `M-j` and `M-k`

| Context at point | `M-j` | `M-k` |
| --- | --- | --- |
| Heading line | Move subtree down | Move subtree up |
| List item or its continuation | Move item tree down | Move item tree up |
| Table row | Move row down | Move row up |
| Ordinary paragraph | Swap with next paragraph | Swap with previous paragraph |
| No adjacent paragraph in the same container | User error, no mutation | User error, no mutation |
| Beside a heading, list, table, quote, metadata, or code block | User error, no mutation | User error, no mutation |

## Paragraph Swap Design

Add one repository-owned paragraph swap operation used by both movement
directions. The operation owns boundary validation, region exchange, and
point/mark restoration. This shared function is justified by the identical
mutation and restoration rules used by Tree-sitter and fallback paragraph
discovery in both directions.

### Tree-sitter Markdown

1. Obtain the Markdown node at point with `treesit-node-at`.
2. Use `treesit-parent-until` to identify an enclosing `list_item` or
   `paragraph` without calling a private `markdown-ts--*` predicate.
3. Dispatch tables first, list items second, and actual heading lines third.
   Use `outline-on-heading-p` to distinguish a heading line from prose in its
   containing section.
4. For ordinary prose, use the enclosing `paragraph` node as the current body.
5. Select its previous or next named sibling with
   `treesit-node-prev-sibling` or `treesit-node-next-sibling`.
6. Require the sibling type to be exactly `paragraph`. A sibling lookup keeps
   both nodes under the same Tree-sitter parent, so the operation cannot cross
   into another section, list item, block quote, table, or code block.
7. Use each paragraph node's start and end positions as the two body regions.
   Leave all text between the regions outside both regions so the separator is
   preserved verbatim.

### Fallback Markdown

1. Dispatch through `markdown-table-at-point-p`,
   `markdown-list-item-at-point-p`, and `markdown-heading-at-point` before
   considering prose.
2. Reject code blocks and other non-prose constructs through the public
   predicates and syntax properties already maintained by `markdown-mode`.
3. Obtain the current paragraph with
   `markdown-bounds-of-thing-at-point 'paragraph`, then normalize only leading
   and trailing blank lines out of the body bounds. Do not strip indentation,
   hard line breaks, or trailing spaces that belong to paragraph text.
4. Move across the intervening blank separator in the requested direction and
   obtain the adjacent paragraph through the same API.
5. Reject an adjacent heading, Setext heading, list, table, fenced or indented
   code block, block quote, thematic break, or metadata block.
6. Resolve the closest preceding Markdown heading for both paragraph starts
   with `markdown-back-to-heading-over-code-block` using its no-error option.
   Require the two heading anchors to match. Two paragraphs before the first
   heading both have a nil anchor and may be swapped.
7. Require the candidate body to be the immediately adjacent prose block after
   normalization. Do not skip over any nonblank structural block.

### Shared mutation and state restoration

1. Complete every context and boundary check before modifying text.
2. Capture point's offset from the current paragraph start. When a visual
   selection is active, require point and mark to lie inside the same current
   paragraph and capture both offsets.
3. Call `transpose-regions` with the two non-overlapping paragraph body
   regions. The untouched middle range preserves exactly one or many blank
   lines and their whitespace.
4. Compute the moved paragraph's new start from the original region lengths
   and separator length. Restore point and, when active, mark from their saved
   offsets.
5. Preserve mark activation for a valid contained selection. A selection that
   crosses a paragraph boundary must signal a user error before mutation.

## Rejected Alternatives

- Keep `org-autolist`: it uses obsolete global advice, couples a list split to
  Evil editing commands, and includes behavior outside the required contract.
- Replace it with `advice-add`: advice would still change every caller of
  `org-return` rather than the requested key behavior.
- Use `transpose-paragraphs`: it does not respect Markdown section ownership
  and can separate prose from its heading.
- Treat prose as its enclosing Markdown section: this is the current defect.
- Reject every prose location: this prevents the requested paragraph swapping.
- Reimplement Tree-sitter checkbox insertion: that would add a brittle parser
  workaround for an upstream limitation unrelated to paragraph movement.

## Phase 1: Replace Legacy List Return Behavior

Status: complete.

1. Remove `org-autolist.el` from the file list in
   `profiles/common/.config/emacs/init.el:85-93`.
2. Remove the `org-autolist` require and enabling hook at
   `profiles/common/.config/emacs/init.el:1104-1108`.
3. Delete `profiles/common/.config/emacs/org-autolist.el`.
4. Add one inline interactive Org return command near the existing Org setup.
   It must:

   - Save the result of `org-in-item-p` once.
   - When inside an item, inspect the item start with
     `org-at-item-checkbox-p` and pass that result to `org-insert-item`.
   - Otherwise call `org-return` interactively so its native table, link,
     heading, and paragraph behavior remains authoritative.

5. Bind `RET` in `org-mode-map` to the new Org command. Do not bind
   `<return>`.
6. Bind `RET` in `markdown-ts-mode-map` to
   `markdown-ts-insert-list-item`. Do not override the code-block or table
   minor maps.
7. Set `markdown-indent-on-enter` to `indent-and-new-item` in the existing
   fallback `markdown-mode` package configuration. Keep
   `markdown-enter-key` as the bound command.
8. Do not add compatibility code for the removed old-style advice. Record that
   an Emacs process which loaded `org-autolist` must be restarted once after
   deployment.

Success criteria:

- The deleted file has no remaining runtime load, hook, package, or test
  dependency. The parent plan may retain it only as historical context and
  must link to this follow-up for the current contract.
- `RET` creates or splits items only in list context in all three modes.
- Org and fallback Markdown preserve ordered items and create unchecked task
  items from checked or unchecked tasks.
- Tree-sitter Markdown retains its documented plain-bullet task limitation.
- Non-list paragraphs, headings, tables, links, and code blocks retain native
  behavior.

### Implementation record

Completed: 2026-09-02.

- Removed the vendored `org-autolist.el` implementation and every runtime
  reload, require, and hook reference. An Emacs process that loaded its legacy
  advice must be restarted once after deployment.
- Added `my/org-return`, which delegates list insertion to `org-insert-item`
  with checkbox state detected at the item start and delegates all non-list
  contexts to interactive `org-return`.
- Bound only ASCII `RET` to the list-aware commands in Org and Tree-sitter
  Markdown. Configured fallback Markdown to let its existing
  `markdown-enter-key` create list items.
- Batch initialization and focused effective-binding and behavior probes
  passed for Org, `markdown-ts-mode`, and `markdown-mode`. `check-parens` and
  `git diff --check` passed. Batch initialization emitted only expected
  sandbox warnings for user-state files outside the repository.

## Phase 2: Add Safe Markdown Paragraph Swapping

Status: complete.

1. Refactor only `my/markdown-move-up` and `my/markdown-move-down` at
   `profiles/common/.config/emacs/init.el:690-702`. Keep
   `my/markdown-structural-command` for the unchanged `M-h` and `M-l`
   operations.
2. Apply this dispatch order in `markdown-ts-mode`:

   - Table row movement through the public table command.
   - List movement through the existing native subtree command after public
     Tree-sitter ancestry confirms a `list_item`.
   - Heading subtree movement only when `outline-on-heading-p` is non-nil on
     the current line.
   - Paragraph swapping only for an enclosing `paragraph` node.
   - A user error for any unsupported context.

3. Apply the corresponding dispatch order in fallback `markdown-mode`:

   - Table row movement.
   - List item movement.
   - Heading subtree movement only when `markdown-heading-at-point` is
     non-nil.
   - Validated ordinary-paragraph swapping.
   - A user error for any unsupported context.

4. Implement the Tree-sitter and fallback paragraph discovery rules from
   `Paragraph Swap Design` in one linear paragraph-swap operation. Do not add
   builders, generalized node adapters, or one-use boundary helpers.
5. Swap only the paragraph body regions with `transpose-regions`, preserve the
   exact separator, and restore point and a contained visual selection by
   offset.
6. Validate every failure before the mutation. Never use catch-and-rollback as
   ordinary control flow.
7. Keep the existing buffer-local normal and visual `M-j` and `M-k` bindings in
   `my/markdown-setup`.

Success criteria:

- A multiline paragraph swaps up and down with the immediately adjacent
  paragraph in both Markdown implementations.
- Point follows the same character offset within the moved paragraph.
- A visual selection contained within the paragraph follows it with point,
  mark, and activation preserved.
- One or many blank separator lines are byte-for-byte unchanged.
- A paragraph never crosses a heading, list, table, quote, metadata, thematic
  break, code block, section, or buffer boundary.
- Heading, list, and table movement retains the existing native results.
- Body text under a heading never causes the heading subtree to move.

### Implementation record

Completed: 2026-09-02.

- Refactored Markdown movement to dispatch tables, list items, actual heading
  lines, ordinary paragraphs, and unsupported contexts separately in both
  Markdown implementations.
- Added one shared paragraph operation that validates exact adjacent prose
  regions before mutation, swaps only their bodies with `transpose-regions`,
  and restores point and contained active selections by offset.
- Tree-sitter discovery uses public ancestry and named-sibling APIs. Fallback
  discovery uses Markdown paragraph bounds, structural predicates and syntax
  properties, immediate-adjacency checks, and matching heading anchors.
- The existing Markdown parity ERT suite passed 3/3. Focused two-mode probes
  passed for multiline movement in both directions, exact multi-line
  separator preservation, point offsets, contained selections, body text
  beneath a heading, list continuation dispatch, and no-mutation structural
  boundary errors. Batch initialization, `check-parens`, and
  `git diff --check` passed.

## Phase 3: Lock the Follow-up Contract with Tests and Documentation

Status: complete.

1. Extend `profiles/common/.config/emacs/markdown-parity-test.el` instead of
   creating a broad new test harness.
2. Add one focused list-return test covering Org, Tree-sitter Markdown, and
   fallback Markdown:

   - Effective Evil insert-state `RET` command.
   - Unordered item creation at end of line.
   - Mid-item and continuation-line splits.
   - Ordered marker increment.
   - Org and fallback unchecked-task creation.
   - Tree-sitter plain-bullet task behavior.
   - Native non-list paragraph behavior.
   - Native table and Tree-sitter code-block behavior.

3. Extend the structural behavior test for both Markdown implementations:

   - Move adjacent heading subtrees from their heading lines.
   - Move adjacent item trees from item content.
   - Move table rows.
   - Swap two multiline prose paragraphs in both directions.
   - Preserve point line and column within the moved paragraph.
   - Preserve a separator containing multiple blank lines and spaces exactly.
   - Preserve a visual selection contained within the moved paragraph.

4. Add boundary fixtures for the start and end of a section and for prose
   adjacent to a heading, list, table, block quote, metadata block, thematic
   break, and fenced code block. For each failure, assert the user error and
   byte-identical buffer, point, mark, activation, and narrowing.
5. Update `dev/plans/6-emacs-md-and-org-alignment.md` where it names
   `org-autolist` or describes the old Markdown movement dispatch. Link the
   completed follow-up plan rather than rewriting its historical
   implementation record.
6. Run validation without graphical input or operating-system-level synthetic
   input:

   ```sh
   emacs -Q --batch \
     -l profiles/common/.config/emacs/markdown-parity-test.el \
     -f ert-run-tests-batch-and-exit
   ```

7. Run the existing leader and send-target ERT suites to prove Org Babel,
   Markdown fenced-code delivery, and global target bindings remain unchanged.
8. Run batch init loading, byte compilation to a temporary directory,
   `check-parens` for every changed Emacs Lisp file, and
   `git diff --check`.
9. Update this plan after each phase with completion status, commands run, and
   observed results.

Success criteria:

- Tests exercise behavior in Org and both Markdown implementations rather than
  only inspecting static key declarations.
- Paragraph swaps and every forbidden boundary are covered by content and
  point-state assertions.
- Existing Org Babel, Markdown fenced-code, leader, target, and visual send
  behavior remains green.
- All changed Emacs Lisp loads and byte-compiles without new errors.

### Implementation record

Completed: 2026-09-02.

- Extended the existing Markdown parity suite to exercise effective list-aware
  `RET` behavior in Org and both Markdown implementations, including native
  Tree-sitter table and code-block context maps.
- Expanded structural behavior coverage for heading subtrees, item trees and
  continuation lines, table rows and columns, multiline paragraph swaps,
  exact whitespace separators, point offsets, and contained active
  selections.
- Added parameterized no-mutation boundary fixtures for section limits,
  headings, lists, tables, block quotes, parsed metadata, thematic breaks,
  fenced and indented code, raw HTML, reference definitions, and
  cross-paragraph selections. Each failure checks the full buffer plus point,
  mark, activation, and narrowing.
- Corrected fallback blank-line matching to recognize tab-containing
  separators after the new fixture exposed the escaped-tab defect.
- The whole-plan review exposed fallback raw HTML and reference definitions as
  additional non-prose boundaries. Added public upstream checks for both as
  current and adjacent contexts, with focused no-mutation regression fixtures.
- Relabeled the original relevant-code and verified-behavior sections as the
  historical pre-implementation baseline so the completed plan does not
  present removed `org-autolist` state as current.
- Updated the completed parent plan only at stale current-contract references,
  linking this follow-up while preserving its historical implementation
  record.
- Final validation passed: Markdown parity ERT 5/5, leader ERT 6/6,
  send-target ERT 5/5, batch initialization, `check-parens`, temporary byte
  compilation of `init.el` and `markdown-parity-test.el`, and
  `git diff --check`. Byte compilation produced both artifacts with existing
  deferred-package and free-variable warnings but no errors.

## Final Success Criteria

- `org-autolist.el` is removed, and `init.el` contains the only repository-owned
  Org `RET` customization.
- `RET` creates or splits a list item only inside a list and delegates to the
  native mode behavior everywhere else.
- Markdown `M-j` and `M-k` operate on the heading, item, table row, or paragraph
  actually at point.
- Paragraphs move only across immediately adjacent prose within the same
  structural container, preserving separators, cursor position, and contained
  visual selections.
- No operation moves prose across headings or other structural boundaries.
- Org Babel and Markdown fenced-code delivery remain unchanged.
- A one-time Emacs restart is the only deployment step required to discard the
  already-active legacy advice from an existing server.
