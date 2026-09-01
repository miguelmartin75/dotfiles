# Emacs Forge, GitHub, GitLab, and diff support plan

## Status

- Plan: ready for implementation
- Implementation: not started
- Current phase: Phase 0
- Target: Emacs 31.1+, Magit, Forge, optional Difftastic, GitHub.com, GitHub Enterprise Server, GitLab.com, and GitLab 19.3 self-managed instances on arbitrary HTTPS hosts and ports. Older GitLab servers are capability-gated as described below.
- Primary configuration: `profiles/common/.config/emacs/init.el:101`
- Package provisioner: `profiles/common/.config/emacs/install-packages.el:1`
- Planned owned provider module: `profiles/common/.config/emacs/my-forge-review.el`
- Planned ERT suite: `profiles/common/.config/emacs/my-forge-review-test.el`
- Planned user guide: `profiles/common/.config/emacs/forge-review.md`
- Existing implementation baseline: local Git, Magit status, Magit blame, ordinary Magit diffs, and optional Difftastic Magit bindings work. Forge and provider review support are absent.

## Goal

Make Emacs the complete Git and hosted-review interface for local and TRAMP projects. Keep Magit responsible for the repository and commit graph, use Forge for its native issue and pull-request or merge-request workflows, and add one owned provider module for functionality Forge does not model completely. The owned module must support full positioned review discussions on GitHub and GitLab without parsing terminal-oriented CLI output.

The result must cover:

- status, staging, unstage, discard, local diffs, revision diffs, history, log, commit, branch, rebase, merge, cherry-pick, stash, fetch, pull, push, tags, worktrees, and blame through Magit;
- issues and pull requests or merge requests through Forge, including creation, editing, general comments, state transitions, labels, assignees, milestones, checkout, worktrees, and browser links;
- GitHub and GitLab inline review threads, replies, resolution state, pending review submission, approvals, change requests, and current review state;
- creation, editing, deletion, discard, and publication for the text-line, multiline, and file-level review note and draft lifecycle enumerated in this plan;
- branch, commit, and issue associations with pull requests or merge requests;
- notifications on GitHub and todos on GitLab;
- CI checks, jobs, pipelines, logs, and browser links;
- GitLab.com and multiple self-managed GitLab instances, including an arbitrary endpoint such as `https://gitlab.example.com:8443` and a distinct SSH port;
- GitHub.com and GitHub Enterprise Server using the same provider boundary;
- syntax-aware local and hosted change diffs through Difftastic when `difft` is available, with ordinary Magit diffs as the complete fallback;
- explicit network access only. Normal startup remains offline.

The complete review scope is code review on textual diffs and files. Provider reactions, GitLab image-position notes and suggestions, suggestion application, and administrative actions such as dismissing another user's GitHub review are outside this workflow. Preserve and render suggestion metadata returned with discussions, and offer the exact provider browser location for unsupported interaction types. Do not broaden "complete" to every endpoint exposed by either provider.

## Decisive architecture

Use the following ownership boundaries:

| Capability | Owner | Reason |
| --- | --- | --- |
| Local Git state and mutation | Magit | Magit already owns the repository model, transients, diffs, blame, and worktrees. |
| Issues, PRs/MRs, general posts, branch association, checkout, and topic browsing | Forge | Forge is the native Magit integration for GitHub and GitLab and persists explicitly pulled topic data locally. |
| Structural local and PR/MR range diffs | `difftastic.el` | The reviewed package already supplies Magit and Forge bindings in `refs/difftastic.el/difftastic-bindings.el:184`. |
| Inline review threads, replies, resolution, approvals, notifications/todos, commit associations, and detailed CI | `my-forge-review.el` | Forge does not provide the entire cross-provider inline discussion and notification surface. This behavior needs an explicit, tested provider contract. |
| Authentication and API transport | Forge Auth Source for Forge; `gh api` and `glab api` for the owned module | Each client supports its provider, enterprise or self-host instances, credential storage, and JSON API output. The module does not read tokens or parse human-readable output. |
| Browser opening | Forge where available; provider module for exact diff line, job, notification, and blame URLs | URLs must use the selected instance record, never a hard-coded public host. |

Do not build thin Elisp wrappers for commands that Forge or Magit already expose in their transients. Keep `SPC g g` as the only repository-scoped global Git entry point. Add owned commands to Forge topic and review buffer menus, and add at most one `SPC g n` mapping for the cross-repository notification or todo inbox because no repository topic buffer owns that operation.

Do not scrape `gh`, `glab`, Magit, Forge, or browser text. Provider API calls must use stable provider endpoints through `gh api` or `glab api` with JSON responses. Do not depend on the experimental `glab mr note` command family. Decode JSON with `json-parse-buffer` using alists or plists consistently. Capture stdout and stderr separately, require a zero exit status, and surface the provider error body without exposing credentials.

## Host and repository contract

Define one public Custom variable, `my/forge-instances`, in `my-forge-review.el`. Each entry is a plist with the common fields and provider-specific fields shown below:

```elisp
'((:id "gitlab-corp"
   :provider gitlab
   :web-base "https://gitlab.example.com:8443"
   :api-base "https://gitlab.example.com:8443/api/v4"
   :https-git-base "https://gitlab.example.com:8443"
   :forge-git-host "gitlab.example.com"
   :forge-ssh-alias "gitlab-corp"
   :cli-host "gitlab.example.com"
   :cli-api-host "gitlab.example.com:8443"
   :cli-origin "https://gitlab.example.com:8443"
   :ssh-host "gitlab.example.com"
   :ssh-port 2222
   :ssh-user "git")
  (:id "github-public"
   :provider github
   :web-base "https://github.com"
   :api-base "https://api.github.com"
   :https-git-base "https://github.com"
   :forge-git-host "github.com"
   :cli-host "github.com"
   :ssh-host "github.com"
   :ssh-port 22
   :ssh-user "git"))
```

The example documents the schema. Do not commit a real company hostname, username, project path, token, or certificate. A machine-specific configuration may set any number of entries through Custom or a non-repository local settings file.

The fields have distinct meanings and must not be inferred from each other:

- `:web-base` is the absolute HTTPS origin used for browser links.
- `:api-base` is the absolute API prefix. GitLab normally appends `/api/v4`; GitHub Enterprise normally uses `/api/v3` for REST and also needs its GraphQL endpoint where applicable.
- `:https-git-base` is the absolute prefix for HTTPS clone URLs.
- `:forge-git-host` is the bare DNS host parsed from an HTTPS Git remote and used as Forge's primary `GITHOST`. It does not include the web port. `:forge-ssh-alias` is optional and supplies a second `GITHOST` entry when SSH uses an alias or a different endpoint.
- `:cli-host` is the provider CLI credential and configuration key. It is a DNS hostname, without a scheme. `:cli-api-host` is the GitLab API authority accepted by `glab auth login --api-host` and may include a port. `:cli-origin` is the full HTTPS origin used only where a current `glab` command explicitly documents a URL-valued host environment variable. GitHub uses `gh api --hostname` with its configured enterprise hostname.
- `:ssh-host`, `:ssh-port`, and `:ssh-user` document and construct the SSH endpoint. For a nonstandard port, use an entry in `~/.ssh/config` and make the SSH remote host match `:forge-ssh-alias`. Keep `:forge-git-host` for HTTPS remotes. Do not emit scp-style `git@host:path` URLs containing a port because that syntax cannot represent one.

Normalize origins by scheme, lowercase DNS name, canonical default port, and trimmed trailing slash. Preserve project-path case. Select an instance by matching the current repository's configured Forge remote against `:forge-git-host`, `:forge-ssh-alias`, or `:https-git-base`. If zero or multiple records match, stop with an actionable error and offer the configured instance IDs. Never silently fall back from a self-hosted repository to GitHub.com or GitLab.com.

Support arbitrary self-managed GitLab origins in the form `https://DNS-HOST[:PORT]`. Explicitly reject a URL path prefix and a literal IPv6 authority with a message that these are upstream Forge and CLI routing limitations. Do not strip the prefix, reinterpret the IPv6 address, or silently route the instance to another origin.

Generate the corresponding `forge-alist` entries without discarding user entries:

```elisp
("gitlab.example.com"                  ; GITHOST for HTTPS Git remote
 "gitlab.example.com:8443/api/v4"     ; APIHOST, no URL scheme
 "gitlab.example.com:8443"            ; WEBHOST and stable instance ID
 forge-gitlab-repository)
```

Forge historically requires `APIHOST` as an authority plus path rather than a full URL. Strip only the `https://` prefix when producing its tuple. Retain the explicit port in `APIHOST` and `WEBHOST`, but keep the HTTPS Git `GITHOST` bare as Forge expects. When `:forge-ssh-alias` is present, generate a second tuple with that alias as `GITHOST` and the same `APIHOST`, `WEBHOST`, and class. Treat `WEBHOST` as immutable after repositories from that instance enter Forge's database. Confirm port handling against the accepted Forge release before accepting Phase 1. Do not rewrite the requested endpoint or hide a failed compatibility check.

Forge 0.6.8 parses a URL port separately but matches `forge-alist` using the bare Git host. A single `https://HOST:PORT` instance is therefore supported by the tuple above, but two instances that share one DNS name and differ only by web port are ambiguous when their Forge remotes both use HTTPS. Require a unique `GITHOST` per simultaneously configured Forge instance. For the same-DNS topology, use a distinct SSH alias as the canonical Forge remote for each instance or reject the ambiguous records. Do not claim that the ignored HTTPS port distinguishes those records.

Phase 1 is a hard compatibility gate for the accepted Forge and Ghub versions. The required `https://HOST:PORT` Forge workflow must pass before later phases begin. Do not retain a partial provider-only fallback that omits Forge-owned issue, MR, checkout, worktree, or topic-editing operations.

Git remotes remain the source of repository identity. Support HTTPS remotes, normal SSH remotes, and SSH aliases. Resolve the namespace and repository from the remote path, strip only a terminal `.git`, and URL-encode GitLab's complete project path when it is used as `:id` in API endpoints. Do not infer repository identity from `default-directory` alone.

## Interaction contract

The primary interaction remains:

| Context | Entry | Purpose |
| --- | --- | --- |
| Any local or TRAMP project buffer | `SPC g g` | Open `magit-status`. |
| Magit status | `N` | Open the existing Forge dispatch for issues, PRs/MRs, topic pulls, creation, and browsing. |
| Forge PR/MR topic | existing Forge post menu plus a `Review` column | Open hosted diff, start or resume review, add, edit, or delete an inline note, reply, resolve or unresolve its thread, manage drafts, submit approval or changes requested, inspect CI, and open the exact browser location. |
| Any buffer | `SPC g n` | Open a tabulated inbox containing GitHub notifications and GitLab todos from every explicitly configured and authenticated instance. |

Use native Forge commands for add repository, pull, create issue, create PR/MR, create general comment, edit, close or reopen, browse, branch association, checkout, and worktree creation. Document discoverable keys from the installed Forge version in the final configuration comments instead of copying unstable transient keys into the leader map.

Add a read-only `my-forge-review-mode` buffer for hosted diffs and review threads. Render one file section per changed file with ordinary unified diff hunks, provider line metadata, thread summaries, and CI summary. Reuse `diff-mode` faces and navigation. Each displayed old or new line must carry text properties containing provider, instance ID, repository identity, topic number, diff version ID, old path, new path, old line, new line, head SHA, base SHA, and start SHA where the provider requires them. Commands must read these properties instead of recomputing a position from visible text.

Difftastic remains a parallel visualization, not the source of API positions. It may reorder or omit unchanged lines and cannot be used to calculate an inline-comment location. All positioned comments are created from the provider's canonical diff/version metadata in `my-forge-review-mode`.

## Provider API boundary

Represent provider-neutral values with `cl-defstruct` types for instance, repository, change request, diff version, file change, diff line, thread, note, review state, CI run, and inbox item. This is justified because the values cross parsing, rendering, and mutation boundaries. Keep provider-specific JSON keys inside two adapters:

- `my-forge-github-*` translates GitHub REST and GraphQL JSON into provider-neutral values and builds GitHub requests.
- `my-forge-gitlab-*` translates GitLab REST JSON into provider-neutral values and builds GitLab requests.

Expose a small operation set used by the UI: fetch change request, fetch changed files and diff version, fetch threads, create, edit, or delete a thread note, reply, resolve, unresolve, begin, update, discard, or submit a pending review, submit approve, submit request-changes, attempt the capability-gated `reviewed` transition for the current user's GitLab request-changes state, submit comment-only review, fetch review state, find change requests for branch or commit, fetch closing issues, fetch inbox, fetch CI, rerun failed CI where authorized, and return browser URLs.

All list operations must handle provider pagination until the provider reports exhaustion. Respect `Link` headers or use documented CLI pagination facilities that still return one valid JSON stream. Put a configurable item ceiling on inbox and history queries and report truncation visibly. For an opened PR/MR, fetch every page the provider exposes and report any provider-side limit instead of implying that omitted files or positions are available.

### Provider diff limits

Provider APIs can omit diff content. GitHub caps the pull-request files endpoint at 3,000 files. GitLab can mark diffs `collapsed` or `too_large`, and server limits can prevent retrieval of a commentable patch. Treat these states as first-class data:

- attempt collapsed-diff expansion only through an endpoint and request shape documented by the detected server version; if no stable expansion contract is available, keep the file unavailable instead of guessing at an internal per-file endpoint;
- render binary, generated, too-large, or otherwise unavailable files as non-commentable entries with the provider's reason;
- offer the local Magit range, Difftastic when available, and the provider browser as read-only fallbacks;
- never manufacture an API position for provider-omitted content; and
- make any GitHub 3,000-file cap or GitLab overflow visible in the review header and acceptance evidence.

"Complete" in this plan means the explicitly enumerated text-line, multiline, file-level, draft, thread, approval, association, inbox, and CI lifecycle. It does not mean every provider API feature or bypassing documented provider or administrator limits.

### GitHub details

- Fetch PR metadata and files from stable REST endpoints.
- Fetch review comments and create comments or reviews through the pull-request review REST endpoints.
- Use the current PR head commit plus the file's `path`, `side`, `line`, and optional `start_side` and `start_line`. Support file-level comments with the documented `subject_type=file`. Do not use the deprecated integer `position` parameter.
- Use a pending review to collect multiple inline comments, then submit `COMMENT`, `APPROVE`, or `REQUEST_CHANGES`. Make the pending state visible and require confirmation before submission.
- Reply through the documented review-comment replies endpoint.
- Edit and delete the current user's published review comments through the documented endpoints. Allow a pending review and its comments to be listed, updated, deleted, or discarded before submission.
- Fetch review thread node IDs and resolution state through GitHub GraphQL. Resolve and unresolve with `resolveReviewThread` and `unresolveReviewThread` mutations.
- Fetch review decision, latest reviews, required approving review count, mergeability, and requested reviewers. Display authorization failures rather than treating them as a negative review state.
- Find PRs associated with a commit using the REST commit-to-pulls endpoint. Find the PR for a branch with Forge metadata first, then the provider API.
- Fetch closing issue references through GitHub GraphQL. Create an association by inserting an explicit closing keyword such as `Closes #123` into the PR body; do not invent a hidden local relationship.
- Fetch notifications through the notifications REST API and mark an item read only on an explicit command.
- Fetch check runs and commit statuses for the PR head SHA. Offer browser links and explicit rerun through documented actions endpoints when authorized.

### GitLab details

- Fetch MR metadata and files from `/projects/:id/merge_requests/:iid/diffs?unidiff=true`, the latest diff-version SHA tuple from `/versions`, and discussions through GitLab REST v4. Do not implement against the deprecated `/changes` endpoint, which is scheduled for removal in API v5.
- Before creating a positioned discussion, fetch the latest `/versions` entry and use its `base_commit_sha`, `start_commit_sha`, and `head_commit_sha`. Populate `position[position_type]=text`, `old_path`, `new_path`, and the correct old/new line combination. An added line has only `new_line`, a removed line has only `old_line`, and an unchanged context line has both.
- For multiline positions, populate `position[line_range][start]` and `position[line_range][end]` with the required `line_code` and `type` plus the applicable `old_line` and `new_line`. Consume a provider-returned line code when available. Otherwise construct GitLab's documented `<SHA1(filename)>_<old>_<new>` form from the canonical diff path and hunk counters, using `new_path` when present and `old_path` otherwise. Test added-only, removed-only, context, and renamed-path values against server-returned line codes. Support documented file-level notes without fabricating a text-line position.
- Store the diff version and SHAs with every rendered line. If the MR head changes before mutation, refresh and require the user to select a position in the new diff. Never submit a comment against stale SHAs automatically.
- Create a thread with the MR discussions endpoint, reply with the discussion notes endpoint, and resolve or unresolve using the discussion note update endpoint. Display outdated discussions even when their original position no longer exists.
- Edit and delete the current user's published notes through the discussion note endpoints. Preserve server IDs across every refresh.
- Use GitLab Draft Notes API endpoints for a batch review: create, list, update, and delete draft notes, then publish the batch explicitly. Keep immediate Discussions API submission available for a single thread. Display draft ownership, support discarding a batch, and prevent a second publish after the server has accepted the batch.
- Publish a GitLab review with `reviewer_state=reviewed` or `reviewer_state=requested_changes`. Treat requested changes as distinct from approval or unapproval. Probe whether a follow-up `draft_notes/bulk_publish` with `reviewer_state=reviewed` and no pending drafts removes the current user's requested-changes state. Enable that API action only when the live probe passes; otherwise expose GitLab's browser removal action and label direct API removal unavailable. State and test that blocking requested changes requires the applicable GitLab version and Premium or Ultimate tier; on other instances, display the non-blocking state honestly.
- Approve and unapprove with the MR approval endpoints. Fetch approval state and approval rules when the instance tier exposes them. Treat `403` or a missing premium field as an unavailable capability, not an empty approval set.
- Find MRs for a branch through source-branch filtering and for a commit through `/repository/commits/:sha/merge_requests`.
- Fetch issues closed by the MR through `/closes_issues`. Create an association by inserting GitLab closing or related references into the MR description.
- Fetch todos from `/todos`, preserve pagination and action names, and mark a todo done only on an explicit command. This is the GitLab notification-equivalent because Forge cannot provide GitLab notifications.
- Fetch pipelines for the MR and jobs for the selected pipeline. Display status, failure reason, timestamps, and web URL. Fetch logs only on request. Retry or cancel only after explicit confirmation and only when the API says the action is available.
- Pass the selected instance's credential key through `glab api --hostname :cli-host` and put its complete URL-encoded project path directly in the REST endpoint. Let the authenticated host record supply `:cli-api-host`. Neither `glab api` nor `gh api` receives a `--repo` argument. Never rely on current-directory placeholders or GitLab.com as an implicit default, and do not pass a URL to a hostname-only flag.

## Authentication and secrets

Forge and the provider CLIs have separate credential stores and must be configured independently:

- Forge uses Auth Source. Set the provider username in Git config and store the token outside the repository. For the same-host example, document `git config --global 'gitlab.gitlab.example.com:8443.user' USERNAME` and the encrypted Auth Source entry `machine gitlab.example.com:8443 login USERNAME^forge password TOKEN`. When APIHOST and WEBHOST differ, document and test the exact Git username key queried by the accepted Ghub version. Never guess between the API and web authority.
- Authenticate `gh` separately for every GitHub host with `gh auth login --hostname HOST`.
- Authenticate `glab` separately for every GitLab host with `glab auth login --hostname CLI-HOST --api-host API-HOST[:PORT] --api-protocol https --ssh-hostname SSH-HOST`. `--ssh-hostname` never carries an SSH port; Git gets that port from the remote URL or `~/.ssh/config`. Use only flags supported by the accepted version. Validate the resulting host record with `glab auth status --hostname CLI-HOST` and `glab api --hostname CLI-HOST user`. The owned adapter passes `--hostname` on every `glab api` call and does not depend on an ambient default.
- Prefer the OS keyring or encrypted Auth Source. Do not load provider tokens through the repository's existing `~/.secrets` mechanism at `profiles/common/.config/emacs/init.el:92`, put tokens in Custom, pass tokens on the command line, log request headers, or share one token between Forge and a CLI implicitly.
- For a PAT, Forge's complete read/write API workflow requires the `api` scope; the narrower `read_api` and `read_user` scopes are not cumulative additional minimums. For `glab`, follow its current authentication documentation for the complete CLI workflow, currently `api` and `write_repository`. Self-managed OAuth uses its separately documented `openid`, `profile`, `read_user`, `write_repository`, and `api` scopes. GitHub tokens must have repository, issue, pull-request, checks/actions, and notification permissions appropriate to the repository visibility and desired mutations.
- Custom certificate authorities must be trusted independently by all transports. Use system trust or a user-local absolute PEM in `gnutls-trustfiles` for Emacs and Forge, system trust or `http.<url>.sslCAInfo` for Git HTTPS, and the accepted per-host `glab` `ca_cert` setting or a process-local CA bundle where supported. Keep SSH `known_hosts` separate. Do not use `ghub-insecure-hosts`, `skip_tls_verify`, or any insecure TLS bypass; `ghub-insecure-hosts` changes the request to plain HTTP rather than trusting a private CA.

## GitLab server capability contract

GitLab 19.3 is the full-surface baseline. Query `/version` and probe behavior explicitly because self-managed tiers, feature flags, and backports can differ from the nominal version. Cache the result only for the Emacs session and expose an explicit refresh.

| Capability | Documented floor or condition | Adapter behavior |
| --- | --- | --- |
| Unified diff responses | `unidiff` introduced in GitLab 16.5 | Require it for canonical parsing or disable hosted inline positioning. |
| Blocking requested changes | Enabled by default in GitLab 17.2, feature flag removed in 17.3, Premium or Ultimate | Render non-blocking review state on Free; never imply a merge block. |
| Browser removal of a change request | GitLab 17.8 | Probe zero-draft `bulk_publish` with `reviewer_state=reviewed`; otherwise open the browser removal action. |
| `collapsed` and `too_large` markers | GitLab 18.4 | On older servers, infer no capability from missing fields; use overflow and patch-presence checks. |
| Multiline and file-level position shapes | Server must accept the documented Discussions and Draft Notes payload | Enable each command only after sanitized fixture validation and an opt-in live probe. |
| Draft Notes `reviewer_state` | Server must accept `reviewed` and `requested_changes` | Disable request-state submission when the probe fails; retain ordinary comments and approvals. |
| Approval rules and merge blocking | Tier and project policy dependent | Show unavailable separately from zero required approvals. |

HTTP `404`, `403`, or an absent response field is not by itself a capability result. The probe must distinguish missing endpoint, insufficient permission, license restriction, and invalid payload.

## TRAMP and process placement

Magit continues to operate on the remote worktree when `default-directory` is a TRAMP path, using the existing setting at `profiles/common/.config/emacs/init.el:1275`. Forge's Ghub API transport and the owned provider API operations run in local Emacs because their databases and credentials are local and the API does not need the remote worktree. Forge-triggered Git operations still run against the TRAMP worktree.

For a TRAMP repository:

1. Ask Magit for the selected remote URL through its Git plumbing.
2. Copy only repository identity, branch names, and commit SHAs into local process arguments.
3. Bind provider process `default-directory` to a local temporary directory, not the TRAMP directory, so Emacs does not attempt to execute `gh` or `glab` remotely.
4. Construct the full provider endpoint from the resolved owner or namespace and repository, URL-encode GitLab's complete project path, and pass only hostname, endpoint, and request arguments. Do not use current-repository placeholders, so the CLI does not need a local checkout.
5. Keep local diff rendering API-backed. Difftastic on a TRAMP worktree remains available only if the existing Magit integration can run `difft` in that environment; ordinary Magit diff is the fallback.

Ghub obtains the GitLab username through `git config`; with a TRAMP `default-directory`, that lookup can execute on the remote host. Store the username deterministically in the remote repository's local Git config, while keeping the Forge PAT only in local Emacs Auth Source. The remote host needs Git, network reachability, Git HTTPS or SSH trust, and its own Git credentials for fetch and push. It does not need the Forge or `glab` API token unless remote `glab` execution is explicitly enabled, which is outside the default contract.

No normal startup, project visit, Magit status open, or Forge topic buffer open may authenticate, refresh, or contact a host automatically. Network access occurs only after an explicit pull, inbox, review, CI, browse, or mutation command.

## Phase 0: Lock dependencies and executable capabilities

Status: not started

### Changes

1. Add `forge` to the explicit archive package inventory in `profiles/common/.config/emacs/install-packages.el:49`. Let package.el resolve Forge's declared dependencies.
2. Retain Magit as the Git implementation and retain the pinned optional Difftastic VC package at `profiles/common/.config/emacs/install-packages.el:32`.
3. Declare `gh` and `glab` as optional at startup but required for complete hosted support for their respective configured providers. Add a separate explicit capability check command that reports executable path, semantic version, authenticated configured hosts, JSON/API support, provider API reachability, and each GitLab instance's server version and observable tier capabilities.
4. Accept Forge 0.6.8 or newer only after its host-port and topic workflow passes, record the exact Forge and Ghub versions used for acceptance, and reject an older installed contract with an actionable diagnostic. Use `glab` 1.114.0 as the reviewed baseline because it includes the 2026 nonstandard-port remote fix and the current `auth login` and `api --hostname` contracts; do not accept the installed 1.74.0 for the complete self-host workflow. Record and capability-check the accepted `gh` version and every command and flag instead of relying on version numbers alone.
5. Add comments to the provisioner and init prerequisites describing Forge, `gh`, `glab`, Git, and optional `difft`. Do not install OS executables during Emacs package provisioning.
6. Load `profiles/common/.config/emacs/my-forge-review.el` by deriving the source directory with `(file-name-directory (or load-file-name user-init-file))`, matching the existing theme path pattern at `profiles/common/.config/emacs/init.el:1061`. Do not rely on `user-emacs-directory`, because source-tree batch loads use a different directory. The module may define commands and register `with-eval-after-load 'forge` configuration at startup, but it must not require Forge, run Git, invoke a CLI, read credentials, or contact a host until an explicit command.
7. Add `my-forge-review.el` and `my-forge-review-test.el` to the byte-compilation and deployment verification inventory.

### Verification

- Run the package provisioner twice against an isolated package directory. The first run installs Forge; the second performs no network write or package change.
- Load the init with package refresh, package install, API calls, and URL retrieval replaced by errors.
- Confirm the owned module is loaded, its interactive entry points are defined, and Forge remains unloaded until `magit-status` or a Forge command needs it.
- Exercise the capability command with neither CLI, only `gh`, only `glab`, both CLIs, an unsupported CLI, and `difft` absent.
- Against GitLab 19.3, record probes for `unidiff`, file-level and multiline positions, `collapsed` and `too_large` markers, Draft Notes `reviewer_state`, request-changes removal, approvals, todos, and CI actions. Against an older disposable server or sanitized responses, prove unavailable commands are hidden or disabled with the required server version and tier in the diagnostic.
- Confirm no token or authentication configuration is written under the repository.

### Success criteria

- Package provisioning is deterministic and normal startup remains offline.
- Missing provider CLIs disable only their hosted provider operations and report the exact remediation.
- GitLab server capabilities are explicit per instance; a version or tier gap never appears as an empty data set or generic review failure.
- Local Magit and ordinary diffs work with no `gh`, `glab`, or `difft` installed.

## Phase 1: Configure Forge for public and self-hosted instances

Status: not started

### Changes

1. Add a deferred Forge declaration beside Magit at `profiles/common/.config/emacs/init.el:101`. Do not load Forge at startup solely to configure it.
2. Implement `my/forge-instances`, validation, normalized matching, and `forge-alist` generation in `my-forge-review.el` using the host contract above.
3. Support multiple GitLab and GitHub entries concurrently. Preserve built-in and user-supplied `forge-alist` entries and reject duplicate instance IDs or ambiguous Git-host matches.
4. Document GitLab.com, GitHub.com, self-managed GitLab with HTTPS port 8443, self-managed GitLab with a nonstandard SSH port through an SSH alias, and GitHub Enterprise examples without committing real endpoints. Require unique Forge `GITHOST` values and document the same-DNS/different-port ambiguity.
5. Configure Forge username and Auth Source expectations without reading credentials during startup.
6. Keep repository enrollment and data pulls explicit through Forge's `N` dispatch. Do not call `forge-add-repository`, `forge-pull`, or `forge-pull-notifications` from hooks.

### Verification

- In isolated Forge databases, add and pull one GitHub.com repository, one GitLab.com repository, and one temporary self-managed GitLab project served on an arbitrary HTTPS port.
- Repeat self-managed GitLab tests with HTTPS Git transport and an SSH config alias pointing at a distinct SSH port.
- Configure two self-managed GitLab instances at once and prove the same namespace/repository name routes to separate Forge IDs, API origins, and browser origins.
- Reject two HTTPS Forge remotes that have the same bare DNS host and differ only by port; repeat with unique SSH aliases and prove the records are then unambiguous.
- Open a local and a TRAMP checkout for each remote form and confirm Forge selects the expected instance.
- Capture outbound requests and prove the configured scheme, authority, port, `/api/v4` path, and project path are preserved exactly.

### Success criteria

- Forge issues and PRs/MRs can be explicitly pulled from GitHub.com, GitLab.com, and `https://HOST:PORT` GitLab without hard-coded host logic.
- Multiple instances coexist without credential, database, or routing collisions.
- No network operation occurs during startup, project discovery, or Magit status creation.

## Phase 2: Complete the native Magit and Forge workflow

Status: not started

### Changes

1. Implement the shared local process runner, instance matching, repository identity, JSON decoding, and the read-only provider adapter operations needed for branch, commit, and closing-issue lookups. Use `gh api` and `glab api` only, with an explicit hostname and fully constructed provider endpoint.
2. Keep the existing `SPC g g` mapping at `profiles/common/.config/emacs/init.el:1152` and use Magit transients for local Git operations.
3. Verify Magit status, stage and unstage, discard, commit, log, revision and range diff, fetch, pull, push, branch, rebase, merge, cherry-pick, stash, tags, and worktrees locally and over TRAMP.
4. Use Magit's blame transient for file and revision blame. Add exact provider browser blame only in the owned module, with URLs derived from the matched instance and URL-encoded revision, path, and line.
5. Use Forge for issue and PR/MR lists, create and edit, general comments, labels, assignees, milestones, close and reopen, branch association, checkout, new worktree checkout, and general browser opening.
6. Use Forge's branch metadata as the primary branch-to-PR/MR association. Add a provider lookup fallback by head/source branch when metadata is absent, then offer to persist the selected association through Forge.
7. Implement commit-to-PR/MR lookup through provider APIs and issue associations through documented closing references. Show associations in a small section in Forge topic buffers.
8. Add no new leader keys for operations already present in Magit or Forge.

### Verification

- Exercise every listed local Git operation in a disposable repository, including a conflict and a linked worktree.
- Against GitHub and GitLab, create an issue, create a PR/MR, add a general comment, edit it, associate a branch, check it out, create a worktree, close and reopen the topic, and open it in the correct browser host.
- Verify commit association using a commit present in one PR/MR and a commit present in none.
- Verify issue association round-trips after adding a closing reference to the PR/MR body.
- Repeat core status, blame, checkout, and topic browsing from a TRAMP worktree.

### Success criteria

- Magit remains the single complete local Git interface.
- Forge owns all hosted operations it supports; the owned module does not duplicate them.
- Branch, commit, and closing-issue associations are visible and navigate to the correct provider and instance.

## Phase 3: Add provider-neutral hosted diffs and inline review

Status: not started

### Changes

1. Extend the Phase 2 transport and read-only adapters with the provider-neutral review structures, pagination, diff retrieval, mutations, and rendering operations described above.
2. Implement `my-forge-review-mode` with changed-file sections, unified hunks, exact old/new line properties, thread summaries, and explicit refresh.
3. Implement GitHub pending reviews, file-level, single-line, and multiline comments, edit and delete, replies, thread resolve and unresolve, draft update and discard, comment-only review submission, approval, request changes, and review-state rendering.
4. Implement GitLab file-level, single-line, and multiline discussions where supported by the instance, published-note edit and delete, draft-note update and discard, explicit batch publication with `reviewed` or `requested_changes`, immediate threads, replies, resolve and unresolve, approval and unapproval, the probed `reviewed` transition or browser fallback for removing the current user's change request, and approval-state rendering.
5. Detect stale head commits and diff versions immediately before every positioned mutation. Refresh and require reselection when stale.
6. Render outdated and unmapped threads in a separate section rather than discarding them.
7. Add provider-specific unit tests using recorded sanitized JSON fixtures for added, removed, context, renamed, deleted, binary, file-level, and multiline changes. Assert GitLab line-code construction for old-only, new-only, context, and renamed paths. Test mapping behavior, not source-code text existence.

### Verification

- On GitHub and GitLab, comment on a file, added line, removed line, unchanged context line, renamed file, and supported multiline range.
- Reply to each provider's thread, resolve it, unresolve it, refresh, and confirm the server remains authoritative.
- Edit and delete a published comment owned by the test user on each provider. Update and discard an unpublished GitHub review and a GitLab draft-note batch.
- Create multiple GitHub draft comments and submit each of `COMMENT`, `APPROVE`, and `REQUEST_CHANGES` in separate disposable reviews.
- Approve and unapprove a GitLab MR and verify approval rules and current state where the test instance tier supports them.
- Publish GitLab `requested_changes`, verify whether it blocks according to the instance tier, probe a zero-draft `bulk_publish` with `reviewer_state=reviewed`, and prove the adapter either removes the state or directs the user to the exact browser action without claiming API support. Prove approval remains a separate state.
- Push a new head while a review buffer is open and confirm no old position can be submitted silently.
- Exercise more than one page of files, threads, notes, and reviews.
- Force CLI nonzero exit, malformed JSON, expired credentials, `401`, `403`, `404`, `409`, `422`, and rate limiting; confirm errors are actionable and no secret appears in `*Messages*` or process buffers.

### Success criteria

- Every currently commentable rendered location round-trips to the same provider diff line after refresh; unavailable and outdated locations remain visible but cannot create a false position.
- Replies and resolution state round-trip on both providers.
- Approval and requested-changes states are explicit and never inferred from comment text.
- Pagination, stale positions, outdated discussions, and permission failures cannot silently lose data.

## Phase 4: Add structural diffs without compromising review positions

Status: not started

### Changes

1. Extend the existing `difftastic-bindings-alist` at `profiles/common/.config/emacs/init.el:106` with the reviewed Forge transient and keymap entries from `refs/difftastic.el/difftastic-bindings.el:199`.
2. Retain the existing Magit diff, show, blame, and file-dispatch bindings. Continue excluding the unrelated Dired entry.
3. Enable `difftastic-forge-pullreq-show-diff` for Forge PR/MR buffers and the Forge post menu.
4. Keep Difftastic conditional on both the explicitly pinned package and `difft`. Do not make Forge conditional on Difftastic.
5. In `my-forge-review-mode`, add an action that opens the same base-to-head range through Difftastic when local refs are available. Label it as a structural visualization and keep inline comment commands in the canonical unified-diff buffer only.

### Verification

- With `difft`, confirm Magit diff, Magit show, Magit blame, file dispatch, Forge GitHub PR, and Forge GitLab MR expose the supplied structural actions.
- Confirm a Difftastic Forge diff uses the expected merge-base to head range.
- Confirm inline review commands are unavailable in Difftastic buffers and remain correct in `my-forge-review-mode`.
- Without `difft` and without the package, load the configuration and complete ordinary Magit and hosted review diffs.

### Success criteria

- Structural diffs work in local and hosted contexts when available.
- Canonical provider positions never depend on Difftastic output.
- Removing Difftastic changes no local Git or hosted review capability other than structural visualization.

## Phase 5: Add inbox, todos, CI, and exact browser navigation

Status: not started

### Changes

1. Add `SPC g n` to the existing leader map near `profiles/common/.config/emacs/init.el:1152` and name it `inbox` in the Which Key Git group at `profiles/common/.config/emacs/init.el:1223`.
2. Implement a tabulated cross-instance inbox with provider, instance, repository, topic, reason or action, unread state, update time, and URL. Refresh only on explicit request.
3. Implement GitHub notification read state and GitLab todo completion as explicit mutations.
4. Add CI summaries to Forge topic and review buffers. GitHub shows checks and statuses; GitLab shows pipelines and jobs. Open details and logs only on request.
5. For GitHub Actions checks, resolve workflow runs and jobs by check suite and head SHA. Follow the documented `302` redirect for expiring log downloads, decode the returned archive or plain text, and never cache a temporary signed URL as a durable link. Third-party checks expose only their provider `details_url` when GitHub cannot supply logs.
6. Add explicit rerun, retry, and cancel actions with provider authorization checks and confirmation for state-changing actions. Use GitHub Actions workflow-run or job rerun and cancellation endpoints and GitLab pipeline or job action endpoints.
7. Build exact browser URLs for repository, issue, PR/MR, diff file and line, thread, commit, blame line, CI run, pipeline, and job using only the matched instance record and provider-returned web URLs.

### Verification

- Fetch at least two pages of GitHub notifications and GitLab todos across two instances, filter them, visit each topic, and explicitly mark one item handled.
- Confirm an inbox refresh failure on one host does not discard successfully fetched items from other hosts and identifies the failed instance.
- Show successful, pending, canceled, and failed CI; open a failed log; rerun or retry a disposable failure; and verify updated status.
- Open one GitHub Actions log through its expiring redirect and one third-party check through `details_url`; prove the signed log URL is not persisted.
- For a nonstandard GitLab port, inspect every generated browser link and prove none routes to GitLab.com or drops the port.
- Start Emacs offline and confirm the inbox is empty or shows cached data without attempting refresh.

### Success criteria

- One explicit inbox covers GitHub notifications and GitLab todos across all configured instances.
- GitHub Actions and GitLab job status and logs are visible without leaving Emacs, while mutations remain explicit. Third-party GitHub check logs use their external `details_url` when GitHub does not expose the content.
- Every browser action preserves provider, scheme, host, port, project, revision, path, and line.

## Phase 6: Harden, document, and accept the complete workflow

Status: not started

### Changes

1. Add `profiles/common/.config/emacs/forge-review.md` for instance records, Forge Auth Source, `gh` auth, `glab` auth, SSH aliases and ports, custom certificate authorities, repository enrollment, large initial pulls, pagination, provider diff limits, and capability diagnostics.
2. Document the distinction between general comments, positioned threads, pending GitHub reviews, GitLab discussions, approvals, notifications, and todos.
3. Add `profiles/common/.config/emacs/my-forge-review-test.el` with ERT coverage for URL normalization, host matching, port preservation, SSH aliases, project-path encoding, JSON parsing, pagination, provider overflow markers, diff line mapping, stale versions, state transitions, and browser URLs.
4. Add opt-in live integration tests driven by environment variables for disposable GitHub and GitLab repositories. Require a self-managed GitLab base URL variable that includes a nondefault port in the acceptance environment.
5. Byte-compile the init, provisioner, and owned module. Run guarded offline loads and the repository's relevant checks.
6. Measure startup with the same command used by `dev/plans/emacs-config-changes.md:20` and record the before and after results. Hosted support must not add network-dependent startup latency.
7. Update this plan after each implementation phase with status, exact verification performed, decisions, deviations, and outcome.

### Verification

- Run all ERT tests and live integration tests against GitHub.com, GitLab.com, and self-managed GitLab on `https://HOST:PORT`.
- Run the self-managed case with a trusted private CA. Verify Emacs/GnuTLS/Forge, Git HTTPS, and `glab` independently, then prove an invalid CA fails without an insecure fallback.
- Complete an end-to-end workflow on each provider: create issue, branch, commit, PR/MR, general comment, inline thread, reply, resolve, approval or requested changes, CI inspection, checkout in a worktree, blame, browser open, inbox handling, and close or merge according to disposable test policy.
- Repeat read-only review and local Git operations from a TRAMP checkout.
- Disable networking and load Emacs repeatedly. Confirm no authentication prompt, DNS request, API process, Forge pull, package refresh, or CLI invocation occurs.
- Scan tracked files and captured logs for tokens, Authorization headers, private hostnames from live tests, and temporary credentials.

### Success criteria

- The complete end-to-end workflow passes for GitHub.com, GitLab.com, and at least one self-managed GitLab instance on an arbitrary HTTPS port.
- Multiple provider instances, HTTPS remotes, SSH aliases, nonstandard SSH ports, TRAMP projects, pagination, stale diffs, and missing optional tools behave as documented.
- GitHub's 3,000-file cap and GitLab collapsed, too-large, binary, and overflow cases are visible, non-commentable where required, and linked to a local or browser fallback.
- Startup remains offline and local Magit remains usable when every hosted integration is unavailable.
- No secret or real private endpoint is committed or logged.
- The plan records implementation status and evidence for every completed phase.

## Final success criteria

- `SPC g g` opens a complete local Git workflow, and Magit remains authoritative for Git state, diffs, history, branches, worktrees, and blame.
- Forge supplies its complete native GitHub and GitLab issue and PR/MR workflow from Magit.
- The owned provider module supplies the enumerated GitHub and GitLab text/file review, reply, resolution, review-state, approval, association, inbox, CI, and exact browser-navigation lifecycle without scraping human-readable output.
- GitLab works on GitLab.com and self-managed instances at arbitrary HTTPS authorities and ports, including separate web, API, HTTPS Git, and SSH endpoints and multiple simultaneous instances.
- Same-DNS instances that differ only by HTTPS port are rejected as ambiguous unless unique SSH aliases provide distinct Forge `GITHOST` values.
- Provider-side diff omissions and size caps are visible and never converted into fabricated review positions.
- Difftastic adds structural local and hosted diffs when installed, while ordinary diffs and all review mutations remain fully functional without it.
- Local and TRAMP repositories select the correct provider locally, and startup performs no provider network work.

## Official references

- Forge manual: https://docs.magit.vc/forge/
- Forge setup for another GitLab instance: https://docs.magit.vc/forge/Setup-for-Another-Gitlab-Instance.html
- Forge host detection and `forge-alist`: https://docs.magit.vc/forge/How-Forge-Detection-Works.html
- Forge branch and worktree association: https://docs.magit.vc/forge/Branching.html
- Forge supported providers and GitLab notification caveat: https://docs.magit.vc/forge/Supported-Forges-and-Hosts.html
- Forge host parsing source: https://github.com/magit/forge/blob/main/lisp/forge-core.el
- Forge GitLab backend source: https://github.com/magit/forge/blob/main/lisp/forge-gitlab.el
- Forge inline review tracking issue: https://github.com/magit/forge/issues/75
- Magit manual: https://magit.vc/manual/magit/
- Emacs Auth Source manual: https://www.gnu.org/software/emacs/manual/html_mono/auth.html
- Emacs GnuTLS trust guidance: https://www.gnu.org/software/emacs/manual/html_node/emacs-gnutls/Help-For-Users.html
- GitHub CLI manual: https://cli.github.com/manual/
- GitHub CLI API command: https://cli.github.com/manual/gh_api
- GitHub REST pull-request files and its 3,000-file cap: https://docs.github.com/en/rest/pulls/pulls#list-pull-requests-files
- GitHub REST pull-request review comments: https://docs.github.com/en/rest/pulls/comments
- GitHub REST pull-request reviews: https://docs.github.com/en/rest/pulls/reviews
- GitHub REST commit association: https://docs.github.com/en/rest/commits/commits#list-pull-requests-associated-with-a-commit
- GitHub REST notifications: https://docs.github.com/en/rest/activity/notifications
- GitHub REST checks: https://docs.github.com/en/rest/checks/runs
- GitHub Actions workflow runs: https://docs.github.com/en/rest/actions/workflow-runs
- GitHub Actions workflow jobs and logs: https://docs.github.com/en/rest/actions/workflow-jobs
- GitHub GraphQL mutations: https://docs.github.com/en/graphql/reference/mutations
- GitHub closing issue keywords: https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/linking-a-pull-request-to-an-issue
- GitLab CLI manual and multiple-host behavior: https://docs.gitlab.com/cli/
- GitLab CLI authentication: https://docs.gitlab.com/cli/authentication/
- GitLab CLI `auth login` host and port flags: https://docs.gitlab.com/cli/auth/login/
- GitLab CLI API command: https://docs.gitlab.com/cli/api/
- GitLab CLI 1.114.0 reviewed baseline: https://gitlab.com/gitlab-org/cli/-/releases/v1.114.0
- GitLab CLI nonstandard-port fix: https://gitlab.com/gitlab-org/cli/-/merge_requests/2747
- GitLab CLI per-host CA configuration: https://gitlab.com/gitlab-org/cli/-/blob/main/README.md
- GitLab merge requests API: https://docs.gitlab.com/api/merge_requests/
- GitLab merge request discussions and diff positions: https://docs.gitlab.com/api/discussions/
- GitLab draft notes API: https://docs.gitlab.com/api/draft_notes/
- GitLab merge request reviews and requested changes: https://docs.gitlab.com/user/project/merge_requests/reviews/
- GitLab merge request approvals API: https://docs.gitlab.com/api/merge_request_approvals/
- GitLab todos API: https://docs.gitlab.com/api/todos/
- GitLab pipelines API: https://docs.gitlab.com/api/pipelines/
- GitLab jobs API: https://docs.gitlab.com/api/jobs/
- GitLab issue closing patterns: https://docs.gitlab.com/user/project/issues/managing_issues/#closing-issues-automatically
- GitLab relative URL installation limitation: https://docs.gitlab.com/install/relative_url/
- `glab` relative URL tracking issue: https://gitlab.com/gitlab-org/cli/-/issues/7920
- Difftastic: https://difftastic.wilfred.me.uk/
- Difftastic Emacs integration: https://github.com/pkryger/difftastic.el
