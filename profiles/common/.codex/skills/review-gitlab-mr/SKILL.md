---
name: review-gitlab-mr
description: Review any GitLab merge request or exact branch from an isolated worktree and produce a standalone, evidence-backed Markdown report that assesses correctness, code shape, reproducible merge-range change size, existing coverage, and validation gaps; do not use to implement fixes.
---

# Review GitLab MR

Review only the changes introduced by a GitLab merge request or exact source branch in any repository. Accept a GitLab MR URL or IID, or an exact branch identifier. Treat optional user concerns and desired code shapes as hypotheses to verify against the code, not as conclusions.

## Authorization boundary

- Do not edit reviewed code.
- Report and worktree creation are allowed.
- Do not commit, push, create or modify an MR, comment, approve, or send review results externally unless the user separately and explicitly requests that action.
- Preserve dirty files, unrelated branches, and existing worktrees. Do not use a developer worktree for target inspection or tests. A persistent review worktree may contain unrelated report changes under the rules below.

## Resolve the repository and revisions

1. Resolve the GitLab project from the MR URL or authoritative MR metadata, then locate a checkout whose remote matches that project. A user-supplied repository path wins. Otherwise use the current repository when it matches. An IID without a project qualifier is valid only when that repository context identifies one project unambiguously. If no matching checkout exists, create an isolated bare clone in a collision-free writable wrapper and record its location. Never fetch an MR ref into a repository for a different project.
2. Detect the selected repository shape before changing anything. A wrapper can contain `.bare` plus sibling worktrees; an ordinary repository can have its Git directory in-place or use linked worktrees. Use `git rev-parse`, `git worktree list --porcelain`, and remote inspection rather than assuming directory names. When a wrapper contains `.bare`, use `git --git-dir=<wrapper>/.bare` for ref and worktree commands; the wrapper itself is not a working tree.
3. Define the wrapper as the directory containing `.bare` for a bare-wrapper layout. For an ordinary clone, use a collision-free, repository-specific sibling worktree root derived from the canonical GitLab host and project path, not the main worktree's parent directly or a project-agnostic shared path. Confirm the chosen paths do not collide with existing worktrees or user files.
4. Resolve MR input through authoritative GitLab metadata. Verify that its project matches the selected remote. Record the project, IID, MR state, exact source project and branch, exact target branch, and reported source SHA. Fetch the target branch and `refs/merge-requests/<iid>/head` from the matching remote into attempt-specific refs. Re-read the metadata, and pin the fetched target-tip SHA only when the MR identity, state, branches, and source SHA still match. Use the moving-revision procedure below when they do not. Do not review a synthetic merge commit.
5. For branch input, validate the exact branch name. Prefer the exact remote branch on the remote matching the current GitLab project and pin its fetched SHA. A local and remote exact-name ref is not ambiguous when both resolve to the same SHA. If exact-name candidates disagree and the user did not qualify the source ref, stop and ask which one to review. Use an explicitly supplied target branch. Otherwise, use the target from exactly one matching open MR; ask the user to choose if multiple MRs match, and fall back to the remote default branch if none match. Never silently assume `main`.
6. Compute and pin the merge base. Inspect only the merge range: `git diff <target-tip-sha>...<head-sha>`, equivalent path and statistic commands, and commits in `<target-tip-sha>..<head-sha>`. Do not attribute pre-existing target-branch code to the change. Record the target tip, head, and merge-base SHAs. If the head cannot be stabilized or any revision cannot be resolved exactly, stop and report the ambiguity.

## Handle moving revisions

Treat an analysis attempt as an immutable snapshot of the pinned MR state, target tip, head, and merge base. Give every reviewer and validation command those exact revisions. Draft outside the persistent review path so an incomplete or stale attempt cannot replace a completed report.

Immediately before publishing, re-read authoritative MR metadata and fetch the source and target into new verification refs. For exact branch input, fetch and compare both exact remote branches. Compare the current MR state, source project and branch, target branch, head SHA, and target-tip SHA with the pinned snapshot.

- If every value matches, record the UTC check time and publish the report for that snapshot.
- If any value changed, discard the temporary draft and all reviewer conclusions tied to that attempt. Pin the new revisions, recompute the merge base and merge-range diff, rerun relevant validation, and repeat the full review. Do not patch the old findings incrementally.
- Allow at most two complete restarts, for three attempts total. If the revisions move again, stop without creating a new report and explain that the MR is changing too frequently for a current review.

A report can become historical after it is published. Its versioned path and recorded revisions identify exactly what was reviewed; a later invocation creates a new version for the then-current snapshot.

## Isolate the review

Create a new detached worktree at the exact head SHA for code inspection. Use a collision-free path dedicated to this review and register it with `git worktree add --detach`; never check out the source branch in an existing worktree.

Keep reports in a persistent review worktree. Unless the user chooses a different location, use `<wrapper>/${USER}/mr-reviews` as the worktree path and `${USER}/mr-reviews` as its branch. Locate registered worktrees before relying on that path. Reuse an existing matching review worktree without disturbing unrelated changes or earlier review versions. If the branch exists without a worktree, add one. Otherwise track the matching remote review branch when it exists, or create the branch from the pinned target tip. Do not reset, pull, merge, rebase, stash, clean, or force-remove existing state as part of review setup.

Choose the report path as follows:

- Use `dev/reviews/<escaped-branch>/<version>-<head-sha>.md` in the persistent review worktree. Use the full lowercase 40-character head SHA.
- A user-provided path overrides this default.

Allocate `<version>` only after the final freshness check succeeds. Scan that branch folder for files matching `<positive-integer>-<40-character-sha>.md`; use `1` when none exist and otherwise use one more than the highest existing integer. Never overwrite or renumber an earlier report. Create the chosen file with no-clobber semantics; if another writer claimed that version, rescan and try the new next version.

Compute `<escaped-branch>` deterministically from a canonical source name. Use the full source branch for same-project changes. For a fork MR, use `<source-project>--<full-source-branch>` so identical branch names from different forks do not collide.

1. Encode the canonical source name as UTF-8.
2. Percent-encode every byte outside `A-Z`, `a-z`, `0-9`, `.`, `_`, and `-` using uppercase hex. In particular, encode `/` as `%2F` and `%` as `%25`; never drop path segments.
3. Use the escaped value directly when it is at most 180 ASCII characters.
4. For a longer value, take the longest prefix no longer than 180 ASCII characters, backing up if necessary so it does not split a `%HH` triplet. Append `--` plus the first 16 lowercase hexadecimal characters of the SHA-256 digest of the complete original UTF-8 bytes. The folder name is at most 198 characters.

This keeps ordinary names readable and collision-free while bounding unusually long filename components.

## Perform the review

Inspect the merge-range diff, surrounding implementation, relevant call sites, repository guidance, and existing tests yourself. Every review must assess the smallest behaviorally complete code shape and measure the current merge-range change size reproducibly. Estimate a smaller replacement only when a concrete behavior-preserving semantic simplification supports it. Physical LOC reduction is not an independent goal. Then spawn these two independent read-only reviewers in parallel, issuing both tasks before waiting for either:

- Correctness and operational risk reviewer.
- Code shape, semantic simplification, merge-range change size, existing coverage, and validation-gap reviewer.

Use `fork_turns="none"`, `model="gpt-5.6-sol"`, and `reasoning_effort="medium"` for both. Give each reviewer the repository/worktree path, exact target/head/merge-base SHAs, merge-range scope, repository guidance paths, and user hypotheses. Tell them not to write files or mutate Git/external state. Require plain-language, consequence-focused findings with path and line evidence, an actionable correction, and the contract's call-path evidence for non-local behavior. Reviewers assess existing coverage and validation gaps, but must not propose, recommend, plan, require, or quantify test changes unless the user explicitly requested test work. Do not give one reviewer the other's conclusions.

Reconcile their output with your own inspection. Personally verify every proposed P0 and P1 against the exact code and applicable behavior. Exclude unsupported or out-of-range claims. Priorities describe demonstrated consequences unless the user explicitly supplied another priority convention. Measure the pinned merge range reproducibly and report the resulting change size. Give a replacement range, assumptions, and relevant absolute and percentage reduction only when a concrete behavior-preserving semantic simplification supports it. Otherwise report zero or no justified reduction, as applicable. Do not include test LOC-reduction estimates or recommend test changes unless the user explicitly requested test work. Assess existing coverage and report validation gaps without proposing test changes by default.

Before drafting, read [references/report-contract.md](references/report-contract.md) completely and follow it. Write the standalone report in the persistent review worktree. After the draft exists, spawn one more independent read-only reviewer with `fork_turns="none"`, `model="gpt-5.6-sol"`, and `reasoning_effort="medium"`. Give it the exact revisions, diff scope, draft path, and report contract. Ask it to check evidence, missed issues, priority, internal consistency, code-shape completeness, change-size arithmetic and semantic-simplification assumptions, coverage and validation-gap treatment, and contract compliance without editing files. Verify its proposed P0/P1 items yourself, revise only where supported, and run:

```bash
<skill-directory>/scripts/validate_report.py <report-path>
```

Resolve the validator script relative to this skill directory. Add `--simple-format` only when the destination repository instructions require LF-only text, no tabs, no em dashes, and no smart quotes. Add `--allow-test-changes` only when the user explicitly authorized test work; otherwise the `### Test changes` body must be exactly `Not requested.`. Also run the repository's relevant exact validation where safe and practical. Clearly distinguish commands actually run from commands considered but not run; do not turn unrun validation into a recommendation for test changes.

After delivery, offer to remove the detached inspection worktree if it is clean. Removal is a separate cleanup action and must not discard generated or user-owned files.
