# AGENTS.md

- Explicit user instructions override this file.
- Examples clarify intent but do not expand the requested scope.
- Read and analyze the files relevant to the request before changing them.
- Do not add backwards-compatibility support unless requested. Preserve behavior outside the requested change.
- Do not create a pull request or merge request without authorization. Prefer making the required changes locally.
- Always export symbols publicly.

## Work in Small Steps

Use this process for code, plans, research, reports, and tutorials. It governs how to develop the result; the final answer or artifact does not need to show every intermediate step.

1. Identify the full request, including applicable rules, existing contracts, and required failure behavior.
2. Produce the most direct useful result supported by the current information.
3. Compare that result with the full request and identify the next missing or incorrect part.
4. Add or revise only what is needed to address that part.
5. Check the whole result again. Repeat until the request is complete or further progress is blocked.

Add work only when the user requests it, a rule or contract requires it, or the requested result would not work without it. Do not add code structure, options, dependencies, edge cases, research, recommendations, sections, or phases merely because they might be useful later.

Working in small steps must not reduce the final scope. Before declaring completion, handle everything the user requested, including required behavior when something fails. Stop with a partial result only if the user explicitly asks for that part alone or asks you to pause, or if further progress is blocked. When blocked, explain the blocker and what remains.

## Implementation

- Make the smallest complete change that satisfies the request. For a bug fix, establish and address the root cause.
- Do not require a separate proposal or Simplification Review before implementation.
- Keep the patch within the requested scope and change only the files and code needed for the result.
- Do not add unrelated features, cleanup, refactors, configuration, fallbacks, logging, dependencies, or compatibility support.
- Do not fix unrelated problems. If one blocks the requested work, make only the minimum blocking fix and report it.
- Implement the requested behavior and required failure handling. Do not add speculative edge-case handling.
- Validate external or untrusted input at system boundaries. Trust data whose internal contract guarantees that it is valid.
- Do not add or modify tests unless explicitly requested. Existing tests may be run; report any limits in what was validated.
- When several in-scope cases are involved, use Muratori to derive shared code from the concrete cases. If an existing abstraction hides the affected behavior, use Inverse Muratori first.
- Prefer built-in language features, the standard library, and platform APIs over dependencies or indirection.
- Prefer normal control flow over excessive early returns. Use early returns for genuine guards, invalid input, empty cases, or terminating searches.
- Do not make code denser merely to reduce its line count.

## Semantic Compression and Decompression

Semantic compression means deriving shared code from concrete cases that genuinely perform the same operation. The cases must match in the behavior that matters: input contracts, effects, failure behavior, and results. Similar-looking text alone does not justify an abstraction.

Semantic decompression is the inverse: expanding an existing shared construct into explicit affected cases so their behavior and differences can be understood before deciding whether the shared structure still belongs.

"Muratori" is the compression process:

1. Implement each affected concrete case as direct, readable, linear code.
2. Make each case work before designing shared structure.
3. Compare the cases and identify only the behavior they prove they share.
4. Extract and name that behavior while keeping case-specific behavior local.
5. If another case does not fit, revise the shared code or keep that case on a separate path.

"Inverse Muratori" makes obscured affected cases explicit:

1. Limit the work to the affected in-scope path.
2. Inline only the indirection needed to understand or change that path, make implicit behavior explicit, and separate conflated cases.
3. Preserve existing behavior unless the requested change requires otherwise.
4. Make each explicit case correct and understandable.
5. Recompress only when multiple cases prove they share the same behavior. Recompression is optional.

Apply either process only within the requested scope. Temporary local repetition is acceptable when it reveals meaningful differences. Optimize for clarity and ease of maintenance, not line count. Do not use either process to justify a wholesale rewrite or unrelated cleanup.

## Complexity

- Branching by itself is not a reason to refactor.
- Refactor for complexity only when the affected control flow is difficult to understand or change safely.
- If an existing abstraction hides the affected behavior, apply Inverse Muratori first. If the control flow remains difficult, extract the largest coherent chunk and reassess.
- Do not mechanically split code into many small helpers.

## Debugging

- Inspect the relevant code and available evidence before attributing a cause. Establish the cause from the actual control path, data, logs, a reproduction, or test results.
- If the cause remains unclear, state what is known and unknown, and clearly label any hypothesis.
- Fix the established cause within scope. Do not mask failures with unrelated validation, retries, fallbacks, or broad exception handling.

## Sub-agents

Honor explicit requests to use sub-agents. Use the requested number and roles, infer only omitted details, and use at least one when the number is unspecified. Keep delegated work within the authorized scope and read-only when the user's request is read-only.

Without an explicit request, delegate only bounded, independent work that can run in parallel with other useful main-session work or keep unnecessary details out of the main-session context. Do not delegate mechanically. Prefer read-only investigation when multiple agents would otherwise edit overlapping code.

- By default, use `gpt-5.6-terra` at `xhigh` for code investigation and implementation.
- By default, use `gpt-5.6-sol` at `medium` for written plans, descriptions, and review.
- By default, use a fresh, read-only sub-agent for each review.
- Give each sub-agent fresh, task-specific context. Do not reuse agents for unrelated work, and stop agents that are no longer needed.

## Writing

Match the length, structure, and explanation to the task, audience, and complexity. State the main point early, then include needed context, reasoning, evidence, caveats, decisions, and next actions.

Make reports, tutorials, plans, and other standalone artifacts understandable without prior conversation. Include the objective, relevant scope and assumptions, conclusion, and any background or meaningful alternatives the reader needs. Do not add detail or sections that are not needed to understand or use the result.

- Prefer plain language. Use technical terms when they improve precision, and define unfamiliar or project-specific terms when first used.
- For research, answer the exact question first. Add additional sources, comparisons, or related topics only when the available information is missing, conflicts, or cannot support the answer.
- In reports, lead with the main finding, order findings by importance, distinguish facts, inferences, and recommendations, and place evidence near each claim.
- Group material by what makes the result easiest to understand, not by the order in which the work was done.
- Make non-trivial recommendations actionable: state what should change, why, and the smallest implementation approach. Include supporting material only when evidence supports it and it improves clarity: use pseudocode or a representative sketch for behavior or structure changes, and an exact replacement for text, commands, or configuration. Do not invent unsupported implementation details.
- For tutorials, state the outcome and prerequisites. Build the smallest useful result first, add required capabilities in dependency order while verifying each step, and finish by verifying the full result.
- Repeat information only to record scope or assumptions, resolve ambiguity, or make the artifact self-contained.

## Review

- Review correctness and requested scope first. Then check whether each changed part is necessary and in scope.
- By default, classify findings as:
  - P0: a severe defect that broadly prevents safe use, release, or recovery.
  - P1: a defect that blocks required behavior or has meaningful impact on a substantial path.
  - P2: a bounded defect or unnecessary in-scope change that does not block the overall result.
- Report only proven problems. Do not invent requirements, report unrelated repository problems, or present preferences as defects.
- Give each finding a consequence-focused title, evidence, and the smallest correction. Use concrete before-and-after behavior when helpful.
- For a cross-boundary finding, give the shortest numbered path that proves the consequence. Cite repository-relative `path:line` locations and show relevant value changes or divergence. For a local finding, include only local proof.
- Prefer corrections that reduce the patch without losing required behavior. Label relevant pre-existing problems separately. Say when there are no findings.

### Simplification Review

A Simplification Review is optional. Perform it only when requested or required by an active skill. Review the completed candidate; for code, review the integrated implementation after validation.

Use a fresh, read-only sub-agent that recommends changes but does not edit. If the Simplification Review is part of a broader review, use the same reviewer for both.

Classify each non-trivial addition by the first reason that applies. Treat mutually dependent additions as one group:

1. Requested or required by a rule or existing contract.
2. Otherwise proven necessary for the requested result.
3. Otherwise needed only because of another design choice.
4. Otherwise optional or unrelated.

A Simplification Review first decides whether each addition belongs.

Recommend removing, combining, or directly replacing an addition or mutually dependent group, together with anything that depends only on it, when the remaining result would still meet the request and applicable rules. For anything retained, name the exact requirement that would fail without it. Do not challenge explicit requirements merely to make the result smaller.

For necessary changed code, use Muratori or Inverse Muratori only to assess its shape.

## Planning

For tasks that require a plan:

- Make the plan self-contained and executable without prior conversation. Include the objective, relevant scope and assumptions, and enough background to execute it.
- Start with the most direct path supported by current information. For a complex task, build toward a complete plan by adding only required work. Check the plan against the full request.
- If meaningful alternatives exist, describe them briefly, choose one, and explain why.
- Reference relevant files using repository-relative paths and include sourced URLs when external resources matter.
- Make affected cases explicit and correct before extracting shared behavior. If an existing abstraction hides the cases, plan to expose them before changing them. Skip decompression when cases are already clear, and do not refactor outside the affected path.

Use a small number of dependency-ordered sections named `Phase`. Each phase must state:

- The actions to perform.
- How the result will be validated.
- The success criteria and checkable result required before dependent work begins.

Keep work that must be implemented and checked together in one phase. Add another phase only for required work that depends on an earlier result or check; do not add phases for possible future work. Keep phase status current during execution.

## Formatting

- Use ASCII punctuation in prose, source text, and comments. Natural-language and user-visible UI or CLI text may use Unicode when appropriate.
- Use LF line endings and spaces for indentation. Do not use tabs or decorative Unicode.
