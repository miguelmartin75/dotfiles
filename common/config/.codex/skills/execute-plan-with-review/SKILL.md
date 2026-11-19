---
name: execute-plan-with-review
description: Execute or resume implementation or modification under user-selected or unambiguously active plans, with integration, validation, state updates, and a combined final review. Use only when the requested outcome includes implementation or modification under the plan; do not use for read-only plan work.
---

# Execute Plan With Review

Use this skill only when the requested outcome is executing or resuming implementation or modification under a user-selected or unambiguously active plan. It also covers plan-owned follow-ups routed from another execution workflow. Do not discover and execute unrelated plans merely because they exist.

Do not use this skill for read-only analysis, investigation, research, explanation, review, or plan creation, even when the user requests sub-agents.

## Establish Scope And State

Before editing:

1. Read the repository-root `AGENTS.md` and every applicable nested `AGENTS.md` in full.
2. Read each selected plan in full, including its recorded status, phases, code pointers, dependencies, and success criteria.
3. Read the relevant implementation and surrounding code. Inspect repository guidance or architecture documentation when it materially affects the work.
4. Preserve unrelated work already present in the worktree.

Resolve the selected plan set and its current state with this precedence:

1. The user's current direction.
2. The selected plan files.
3. The current session's established execution state.
4. Relevant Git history that records earlier plan execution or follow-up state.

Use lower-precedence sources to fill gaps, not to override higher-precedence direction. A plan file is optional when the current session or relevant Git history provides an unambiguous active plan or follow-up with enough information to execute safely. Do not create a plan file unless requested.

Before execution, normalize any plan recovered from session state or Git history in the current session into a self-contained plan that satisfies the applicable `AGENTS.md` planning requirements. This does not require creating a plan file.

Ask the user only when unresolved ambiguity would materially change the implementation, selected scope, ownership, or required outcome. Otherwise make the smallest reasonable assumption, record it when useful, and continue.

## Verify The Plan

Compare every selected plan with the current code before implementation:

- Confirm code pointers still identify the intended surfaces.
- Confirm assumptions and dependencies still hold.
- Confirm phase ordering reflects real technical dependencies.
- When related cases may share internal code, confirm the plan makes direct concrete cases work before shared extraction. When existing indirection obscures affected behavior, require only the necessary in-scope, behavior-preserving decompression before behavior changes; reconcile premature abstraction and unrelated refactoring.
- Confirm success criteria are observable and sufficient to establish completion.
- Reconcile recorded completed or in-progress work with the actual code and available validation evidence.

Correct stale plan state when the evidence is clear. If a missing or conflicting requirement prevents safe execution, mark the affected work blocked and request the specific decision or information needed.

Update plan state at meaningful boundaries: when a phase starts, completes, materially changes, becomes blocked, or reaches a review-loop outcome. Record important corrected assumptions, dependencies, code pointers, review/remediation outcomes, and success-criteria status. Do not update state after every worker batch when no meaningful plan state changed.

## Execute In Dependency Order

Build a practical dependency graph across all selected plans and follow-ups. Execute ready work in dependency order. Multiple ready phases may proceed together when their contracts and file ownership do not conflict and integration risk is acceptable.

Establish required cross-worker contracts before dependent or parallel work. These include public APIs, schemas, CLI surfaces, cross-module data shapes, persistence formats, and lifecycle or ownership rules. Internal shared helpers are not prerequisite contracts: make direct concrete cases work first, then keep semantic comparison and shared extraction under one owner. Keep foundational contract decisions in the main session or give them one clear owner; do not let workers independently redefine the same contract or abstraction.

Delegate according to `AGENTS.md`. Delegated work must remain bounded and non-overlapping. Each worker should receive:

- The relevant goal, plan section, and verified assumptions.
- Exact owned files or surfaces and explicit exclusions.
- Applicable repository instructions and established shared contracts.
- Expected behavior, failure handling, and useful validation commands.
- A reminder to preserve unrelated changes and avoid editing outside its assignment.

Workers may investigate or implement their assigned scope, but the main session owns integration. The main session must inspect their changes and relevant surrounding code, resolve overlaps, confirm plan conformance, and reject or correct unsupported work. Where cases may share internal code, compare the working cases and retain only behavior proven shared; keep case-specific behavior local. If opaque indirection had to be decompressed, keep that work limited to the affected path and preserve existing behavior except where the plan requires a change.

Use narrow validation while iterating, then run the applicable integrated validation after ready work is combined. Validation should be proportional to risk and should cover required or documented behavior and reproducible failure paths.

## Review

By default, begin the combined final review after all user-selected phases and follow-ups have been implemented and proportionate available validation has been performed. An earlier review is appropriate only at a stable milestone when delay creates material risk or likely rework, and it does not replace the final combined review.

Before the review loop, set its controls. The default stopping set is all priorities, P0 through P2. Honor a user-selected subset or threshold, such as P0-P1; supported findings outside that set are reported but are not fixed or used to keep the loop open unless the user requests them. Honor an optional user-specified positive maximum number of review iterations. Without a maximum, the loop remains evidence-driven.

Each iteration must use a new review sub-agent that neither implemented work nor reviewed an earlier iteration. Apply the reviewer defaults and review criteria from `AGENTS.md`. Review the complete selected implementation against the user request, selected plans, success criteria, and validation evidence, not only the latest remediation.

The main session must independently verify every finding against the code and plan. Apply only accepted, in-scope fixes in the stopping set, inspect the resulting changes, rerun applicable validation, and reassess every selected success criterion. Do not adopt speculative, stylistic, or scope-expanding recommendations.

After each iteration, update plan state with the review outcome, accepted remediation, validation result, and success-criteria status. Report supported out-of-set findings without fixing them unless the user requests them. After applying any accepted fix, or when validation exposes a task-owned issue, resolve the issue where possible, run applicable validation, and repeat the complete integrated final review with a new review sub-agent. An iteration converges when it ends with no accepted in-scope finding in the stopping set, unsatisfied selected success criterion, or task-owned validation failure. If the maximum iteration count is reached before a converged iteration, including when the cap prevents review of a fix, record non-convergence and stop without claiming a clean review or success. If a blocker prevents convergence, mark the affected work blocked, record what remains, and stop without claiming success.

## Completion And Git

Before reporting completion, independently confirm all user-selected phases and follow-ups against their applicable success criteria, the integrated code, and final validation. Keep plan state honest: leave unselected work pending, mark incomplete or blocked selected work as such, identify what remains, and do not claim success from partial implementation.

Create local Git commits for the completed selected work by default unless the user opts out or the repository prohibits commits. Commit only task-owned changes, keep commits logical, and do not impose one commit per phase or follow-up. Use branches, pushes, history edits, or PR/MR operations only when the user requests them or the repository explicitly requires them. Never rewrite published history. Publish changes only with authorization.
