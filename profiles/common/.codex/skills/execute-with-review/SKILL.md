---
name: execute-with-review
description: Execute a requested implementation or modification through bounded delegated work, main-session integration and validation, and a combined review. Use only when the user also explicitly requests delegation, sub-agents, parallel work, review, or iterative execution; do not use for read-only work. Route implementation follow-ups owned by a plan to execute-plan-with-review.
---

# Execute With Review

Use this skill only when the user requests implementation or modification and also explicitly requests delegation, sub-agents, parallel work, a review pass, or repeated iteration. Do not use it for read-only analysis, investigation, research, explanation, review, or planning, even when the user requests sub-agents. Do not infer permission to delegate from task size alone.

## Routing

If the requested implementation or modification is an explicit follow-up or continuation owned by an existing written or canonical implementation plan, switch to `execute-plan-with-review`. Otherwise use this standalone workflow. Do not create plan state merely to route ordinary work.

## Prepare

- Read the applicable `AGENTS.md` files and any repository guidance they identify.
- Read the relevant implementation, nearby call sites, tests, and documentation needed to understand the requested behavior before editing.
- Inspect Git status and diffs as needed to identify the task baseline, staged work, and unrelated user changes. Preserve unrelated work and do not overwrite, revert, stage, or commit it.
- Clarify only decisions that materially change the requested outcome or require new authority. Otherwise make informed, scoped assumptions and proceed.

## Delegate Implementation

Delegate concrete, bounded work according to `AGENTS.md`. Keep conflict-prone integration, cross-cutting decisions, and immediate blocking analysis in the main session.

Workers with write access must have non-overlapping scopes. Give each worker a compact packet containing:

- the user goal and relevant behavior;
- the exact files or subsystem it owns and what it must avoid;
- applicable repository instructions and important code context;
- expected output and useful validation commands;
- a reminder to preserve unrelated changes and keep the solution direct and in scope.

Use parallel workers only when their work is genuinely independent. Re-scope or sequence work when ownership overlaps. Do not delegate external publication or other mutations beyond the user's authorization.

When related cases may share internal code but their differences are unclear, keep their semantic comparison and any shared extraction under one owner. Implement direct working cases before extracting shared behavior, and do not let parallel workers independently design or revise the same abstraction. If existing indirection obscures affected behavior, first make only the in-scope cases explicit while preserving behavior.

## Integrate And Validate

The main session owns the complete result. After worker changes are available:

1. Inspect the complete task diff, every changed file, and enough surrounding code to understand the integrated behavior.
2. Reconcile overlaps, incomplete interfaces, inconsistent assumptions, and unsupported changes. Compare working cases before retaining only behavior proven shared; keep case-specific behavior local.
3. Confirm the result satisfies the request and applicable repository rules while preserving unrelated work.
4. Run proportionate validation, starting with focused checks and expanding to relevant repository checks according to change risk and available commands.

## Combined Review

By default, begin the combined final review after implementation is complete, the task diff is integrated, and proportionate available validation has been performed. An earlier review is appropriate only at a stable milestone when delay creates material risk or likely rework, and it does not replace the final combined review. Each iteration must use a new review sub-agent that neither implemented the task nor reviewed an earlier iteration. Apply the reviewer defaults and review criteria from `AGENTS.md`. Review the complete task-owned diff rather than isolated worker outputs.

Before the review loop, set its controls. The default stopping set is all priorities, P0 through P2. Honor a user-selected subset or threshold, such as P0-P1; supported findings outside that set are reported but are not fixed or used to keep the loop open unless the user requests them. Honor an optional user-specified positive maximum number of review iterations. Without a maximum, the loop remains evidence-driven.

Give the reviewer the user request, applicable repository instructions, exact review scope, relevant context, and validation evidence.

## Resolve And Finish

Independently verify every reviewer claim against the code and request. Fix only accepted, in-scope findings in the stopping set, inspect the resulting complete diff, and rerun applicable validation. After applying any accepted fix, or when validation exposes a task-owned issue, repeat the complete integrated review with a new review sub-agent. An iteration converges when it ends with no accepted in-scope finding in the stopping set and no task-owned validation failure. If the maximum iteration count is reached before a converged iteration, including when the cap prevents review of a fix, report non-convergence and stop without claiming a clean review or success. If a blocker prevents convergence, stop and report it without claiming success. Report rejected, unresolved, out-of-set, unrelated, or pre-existing findings separately when material.

Create local Git commits for the completed task by default unless the user opts out or the repository prohibits commits. Commit only task-owned changes, keep commits logical, and do not stage unrelated work. Use history edits, branches, pushes, or PR/MR operations only when the user requests them or the repository requires them. Never rewrite published history, and publish only with authorization.

Finish with a concise summary of the implemented behavior, files changed, validation performed and results, review outcome, and any material limitations or follow-ups.
