# Review report contract

The report must stand alone for an engineer who has the repository but has not seen any request, prompt, conversation, or agent work. Never mention those inputs or the review process. State claims as code-review conclusions supported by current merge-range evidence.

## Required progression

Use one H1 in this form:

```markdown
# Review: `<full-source-branch>`
```

Then progress through these sections:

1. `## Recommendation`
2. `## TL;DR` or `## Design path` when a short explanation materially clarifies the intended behavior or simpler implementation
3. Prioritized findings
4. `## Recommended code shape`
5. `## LOC estimate`
6. `## Test review`
7. `## Validation status`

Recommendation, Recommended code shape, LOC estimate, Test review, and Validation status are always required. TL;DR and Design path are optional and should be omitted when they add no decision value.

## Recommendation

Lead with a direct merge recommendation such as approve, request changes, or block. Explain the decisive reason in compact terms. Keep the recommendation consistent with the highest verified finding and validation status.

When implementation size is relevant, report reproducible current merge-range change size. Include a replacement estimate only when a concrete behavior-preserving semantic simplification supports it, and identify what the estimate includes. Physical LOC reduction is not a priority by itself; connect unnecessary structure to maintenance, correctness, or operational consequences. Do not include test-change estimates unless the user explicitly requested test work.

## Findings

Use headings in descending priority order:

```markdown
### P0: Plain-language, consequence-focused title
```

Allowed priorities are P0, P1, P2, and P3. Use consequence-based priority unless the user explicitly supplied a different priority system:

- P0: merge-blocking behavior with severe or broad correctness, security, data-loss, or availability consequences.
- P1: merge-blocking correctness, operational, or maintainability defect with meaningful impact.
- P2: non-blocking defect or important improvement with bounded impact.
- P3: minor cleanup or polish worth addressing.

Every finding must contain at least one exact repository-relative `path:line` pointer. Prefer pointers to changed lines; include surrounding-code pointers only when needed to prove the interaction. Explain:

- the observed behavior,
- the conditions that trigger it,
- the concrete consequence,
- the smallest justified correction, and
- coverage or validation gaps when relevant.

Every finding must end with the smallest actionable correction, phrased as a recommendation or question. For a non-trivial code behavior or structure correction, state what should change, why it is needed, the smallest implementation approach, and brief pseudocode or a representative sketch. For text, configuration, or commands, show the exact replacement or snippet. Do not invent implementation details that the code does not support.

When a finding depends on behavior across functions, files, layers, callbacks, or data transformations, the initial report must include a numbered call path from entry point to consequence. Give repository-relative `path:line` pointers at every meaningful step, show material before-and-after values or data shapes, and identify where compared paths diverge. For a local defect, include only the pointers and evidence needed to prove it.

Do not inflate priority based on hypothetical consequences that the code or operating environment cannot reach. Do not include style preferences without a material consequence. Consolidate findings that share one root cause. If there are no findings, include the literal sentence `No findings.` instead of manufacturing low-value items.

## Design and code shape

Always evaluate whether the change uses the smallest behaviorally complete code shape. Describe boundaries, ownership, data flow, lifecycle, error behavior, and caching or concurrency choices relevant to the change. A compact pseudocode sketch is appropriate when it makes the recommendation unambiguous. Do not demand a rewrite merely because another design is possible. When the current shape is already the smallest justified design, say so explicitly.

When shared code consolidates cases, verify that multiple real cases prove the shared behavior, case-specific behavior remains local, and the abstraction improves lifetime clarity rather than textual deduplication or line count. If indirection obscures affected behavior, make the in-scope cases explicit enough to compare before recommending recompression. Do not recommend unrelated refactors. When proposing a semantic simplification, retain all required observable behavior and identify which current layers remain, which disappear, and how callers are affected.

## LOC estimate

Always measure current lines from the pinned merge range with a reproducible command such as `git diff --numstat`. State whether the counts are additions, net lines, physical lines, or executable lines. Separate core production logic, integration or lifecycle wiring, configuration or schema, and tests when those distinctions make the current change-size measurement clearer. For documentation-only, generated-code-only, or configuration-only changes, report the relevant changed lines and mark a production replacement estimate as not applicable.

Start the section with a concrete basis line:

```markdown
Measurement basis: Added physical lines from `git diff --numstat <base>...<head>`.
```

Replacement sizes are estimates. Give one only when a concrete behavior-preserving semantic simplification supports it, and use ranges that state the retained behavior and module boundaries. When an estimate is justified, report its relevant absolute and percentage reduction. Use zero or state that no justified reduction exists when appropriate. Do not select a target from a desired percentage alone. Do not estimate or require test LOC reduction unless the user explicitly requested test work.

## Test review

Use these subsections exactly:

- `### Existing coverage`: summarize relevant assertions and implementation paths that were inspected. Do not infer coverage from filenames alone.
- `### Validation gaps`: report evidenced coverage gaps or validation limitations without proposing, recommending, planning, requiring, or quantifying test changes.
- `### Test changes`: write `Not requested.` unless the user explicitly requested test recommendations. Only then may this subsection recommend, quantify, or discuss adding, changing, removing, or consolidating tests.

Say `None identified.` for an empty Existing coverage or Validation gaps subsection. The default review assesses existing coverage and reports validation gaps; it does not propose test changes.

## Validation status

Include an explicit status line in this exact shape:

```markdown
Status: Passed
```

Use `Passed`, `Failed`, or `Not run`, followed by the exact commands or checks and their observed outcomes. For commands not run, explain why and list them under a clearly labeled validation-not-run subsection. Never imply that a command was executed when it was only considered, and do not turn unrun validation into a recommendation for test changes.

Include these exact reproducibility fields with lowercase or uppercase 40-character hexadecimal SHAs:

```markdown
Review version: `1`
Snapshot status: Current
Snapshot checked at: `2026-09-04T12:34:56Z`
Target tip SHA: `<sha>`
Head SHA: `<sha>`
Merge-base SHA: `<sha>`
```

Use a positive integer for the review version and an RFC 3339 UTC timestamp for the final freshness check. `Snapshot status: Current` means the MR identity, state, branches, head, and target tip matched the pinned snapshot immediately before this immutable report was written. Never use it for an unchecked or known-stale snapshot.

Follow the destination repository's formatting rules. When its guidance requires LF-only text, no tabs, no em dashes, and no smart quotes, invoke the report validator with `--simple-format`.
