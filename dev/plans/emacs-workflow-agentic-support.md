# Emacs Org work-item and agentic workflow implementation plan

## Status

- Plan: draft, project section schema confirmed
- Implementation: not started
- Current phase: Phase 1
- Core completion boundary: Phases 1 through 6 and the mandatory Phase 9 checks
- Optional integration: Phases 7 and 8 add Linear without gating the Org-only workflow
- Target: Emacs 31.1+
- Primary configuration: `profiles/common/.config/emacs/init.el`
- Package provisioner: `profiles/common/.config/emacs/install-packages.el`
- Private task data: local files below `~/org/`, outside this repository

Update this status and every phase status with measured outcomes during
execution. Do not mark a phase complete until its success criteria and
applicable verification pass.

## Outcome

Build an Emacs-centered workflow whose complete baseline is an Org project
file, not an external tracker:

```text
Org project file
  curated docs, task headings, personal TODO state, note links, and project log
        |
        +-> journal.org
        |     chronological private log linked by Org ID
        |
        +-> optional Linear association
        |     team-visible issue context and reviewed comment publication
        |
        +-> Emacs task tab
              live projection of one workspace root and one Org task
                    |
                    +-> native Codex through codex app-server
                    +-> Gptel for lightweight chat and rewriting
                    +-> Ghostel/zmx for Claude, remote Codex, and fallback
                    +-> agent event buffer for progress and attention
```

Org is sufficient with no Linear account, executable, API key, identifier,
URL, module load, or network. Org remains the private workflow control plane
and owns local task identity and personal TODO state. The journal owns
chronology only. When a task is associated with Linear, Linear owns only the
team-visible issue state and communication. Org TODO state and Linear workflow
state are separate dimensions and never synchronize automatically.

Partition work by project. The recommended default is one file at
`~/org/work/projects/<project-key>.org`. A project that needs adjacent note or
artifact files can instead use `~/org/work/projects/<project-key>/index.org`.
A shared `projects.org` file with one heading per project remains configurable,
but it is not the default. A task keeps its detailed notes below its heading or
links one existing Org or Markdown file.

Emacs tabs hold only live projections. Codex app-server, Gptel, terminal agents,
and lifecycle events remain separate surfaces because they have different
protocols and lifecycle guarantees.

## Proposed project file

Use one project heading as the storage boundary with exactly three standard
sections in this order: `Docs`, `Tasks`, and `Log`. `Docs` is a curated index of
durable project documentation, especially repository Markdown shared with
teammates. `Active` is the only task subtree for open work; completed or
canceled tasks move to `Archive` only through an explicit archive command.
`Log` is the dated project chronology.

Recommended default path:

```text
~/org/work/projects/dotfiles.org
```

Example contents:

```org
#+title: dotfiles
#+filetags: :work:project:

* dotfiles
:PROPERTIES:
:ID: project-org-id
:PROJECT_KEY: dotfiles
:PROJECT_ROOT: /Users/migmartin/repos/dotfiles/
:END:

** Docs
- [[file:/Users/migmartin/repos/dotfiles/docs/architecture.md][Architecture]]
- [[file:/Users/migmartin/repos/dotfiles/docs/agent-workflow.md][Agent workflow]]

** Tasks
*** Active
**** DOING Add project-aware Emacs agent workflow
:PROPERTIES:
:ID: task-org-id
:WORK_KEY: emacs-agent-workflow
:WORKSPACE_ROOT: /Users/migmartin/repos/dotfiles/
:NOTE_FILE: ~/org/notes/emacs-agent-workflow.md
:SESSION_BACKEND: codex-native
:END:

*** Archive :ARCHIVE:
**** DONE Retire the old journal work-task capture
:PROPERTIES:
:ID: archived-task-org-id
:WORK_KEY: retire-journal-work-capture
:END:

** Log
*** 2026
**** 2026-09 September
***** 2026-09-03 Thursday
****** 09:30 [[id:task-org-id][emacs-agent-workflow]]
Decided to keep Linear optional and use Org IDs as the durable identity.
```

The example task intentionally has no narrative subsections. The minimum valid
task is a TODO heading with a property drawer containing `ID`. `WORK_KEY`,
`WORKSPACE_ROOT`, note/session properties, free-form body text, and any
user-chosen task subsections are added only when relevant.

`Docs` is a curated project documentation index, not an automatically generated
list of task notes. A task-specific file remains linked through `NOTE_FILE` and
appears under `Docs` only when it becomes a durable project reference. Keep
repository Markdown as the shared source of truth and link it from Org; do not
mirror its content into the project file.

The project `Log` datetree is for optional detailed project chronology. The
global `~/org/journal.org` remains the concise cross-project daily index and
links to the task Org ID plus any selected detail note. Do not automatically
write the same text to both places.

The directory form uses the same `index.org` contents:

```text
~/org/work/projects/dotfiles/
  index.org
  notes/
    emacs-agent-workflow.md
```

The shared-file form repeats the complete project heading, beginning at
`* dotfiles`, for every project. Project and task Org IDs remain canonical, so
changing storage form does not require rewriting journal links.

## Goals

- Start or resume a local Org task by selecting an existing task or creating
  one from a title, with an optional human-facing local key.
- Partition curated docs, tasks, archive, and optional dated logs by project
  while keeping the global journal as the cross-project daily index.
- Maintain one durable Org `ID` per task regardless of whether any external
  tracker is associated.
- Keep one timestamped daily log in `~/org/journal.org`, with every entry
  linking back to the Org task and optionally to an Org or Markdown detail note.
- Show local tasks in the Org agenda while keeping the daily journal outside
  the agenda.
- Bind the Org task, normalized workspace root, note, agent session, terminal,
  and review buffers to one Emacs task tab without using the tab name as an
  identity.
- Add a full-fidelity native Codex surface while retaining Gptel and the working
  Ghostel/zmx terminal flow.
- Let Codex and Claude report bounded lifecycle events to a running GUI,
  daemon, or direct `emacs -nw` session through a fixed, data-only entry point.
- Permit narrowly reviewed editor context tools without exposing a generic
  Elisp evaluator to prompts.
- Support local Emacs editing remote files through TRAMP without giving a
  shared remote host arbitrary control of the local Emacs process.
- Draft a provider-neutral status update from local notes and logs.
- Optionally associate an Org task with Linear, inspect current issue metadata,
  and publish a comment only after explicit human review and confirmation.

## Non-goals

- Do not require Linear or another tracker for task creation, TODO state,
  journaling, agent context, layouts, events, MCP, or remote work.
- Do not mirror Org TODO keywords to Linear states or Linear states to Org TODO
  keywords.
- Do not overwrite a local task title from Linear after optional initial
  import.
- Do not implement bidirectional synchronization, background polling, issue
  creation, or automatic status transitions.
- Do not write every agent event, prompt, transcript, or tool result into the
  journal.
- Do not publish local paths, private reasoning, raw transcripts, secrets, or
  unreviewed agent text to Linear.
- Do not replace the existing terminal sender with Codex-specific protocol
  handling.
- Do not build `workd`, SQLite state, or a custom dashboard in this plan.
- Do not replace zmx with tmux merely to anticipate a future dashboard.
- Do not make native Codex over TRAMP a baseline requirement before live
  support is proven.
- Do not expose an Emacs TCP server or forward a raw Emacs server socket from a
  shared or untrusted host.
- Do not add a generic tracker framework before a second real tracker exists.
- Do not mirror content between Org and Markdown. Keep shared repository
  documentation in Markdown and link it from the private Org control plane.

## Current codebase findings

### Org and journal

- Org configuration begins at
  `profiles/common/.config/emacs/init.el:1289`.
- Existing journal captures use `file+datetree` at
  `profiles/common/.config/emacs/init.el:1320-1349`. They create meetings, logs,
  personal tasks, work tasks, and journal entries in `~/org/journal.org`.
- The work TODO capture at
  `profiles/common/.config/emacs/init.el:1346-1347` mixes task state with
  chronology. Redirect work-task capture through the project storage resolver
  into the selected project's `Tasks/Active` subtree; keep the personal journal
  captures unchanged.
- `profiles/common/.config/emacs/init.el:51` records `journal.org` in Custom's
  `org-agenda-files`, while the later runtime assignment at
  `profiles/common/.config/emacs/init.el:1376` leaves only `~/org/life.org`.
  Replace both with one explicit runtime agenda containing `life.org` and every
  existing primary project Org file. Keep `journal.org` and directory-form
  auxiliary note files outside the agenda.
- Org Roam already indexes `~/org/` and starts database autosync at
  `profiles/common/.config/emacs/init.el:1456-1463`. Do not add another note
  index.
- `profiles/common/.config/emacs/my-org-datetree.el:13-55` owns generic dated
  copy and refile operations. `my/refile-to-journal` uses it at
  `profiles/common/.config/emacs/init.el:1492-1499`. Preserve both behaviors.
- The Org leader map at `profiles/common/.config/emacs/init.el:1815-1821` has
  room for task workflow commands.

### Terminal, Gptel, and native Codex gap

- Ghostel and term-sessions are configured at
  `profiles/common/.config/emacs/init.el:1501-1555`. Ghostel renders the PTY and
  zmx owns durable terminal sessions.
- `profiles/common/.config/emacs/my-send-text.el:48-226` delivers unstructured
  text to zmx, Ghostel, ordinary processes, or writable buffers. Preserve this
  agent-neutral, one-way transport.
- Gptel at `profiles/common/.config/emacs/init.el:1621-1648` uses an Anthropic
  backend. Its normal and visual bindings are at
  `profiles/common/.config/emacs/init.el:1802` and
  `profiles/common/.config/emacs/init.el:1866-1874`.
- Gptel can use OpenAI models, but a Gptel conversation does not own Codex CLI
  threads, sandbox state, skills, approvals, or app-server lifecycle. Keep it
  for chat and rewrite work.
- OpenAI documents `codex app-server` as the rich-client interface for
  authentication, conversation history, approvals, and streamed events.
  `codex exec --json` is suitable for one-shot automation, not the requested
  interactive Emacs UI.
- `emacs-codex-ide` uses app-server and provides ordinary Emacs transcript
  buffers, native diffs, links, approvals, model and sandbox controls, and
  session resumption. It is the recommended native Codex client. Because it is
  a community package over an evolving interface, commit-pin it and keep the
  terminal fallback.

### Emacs server and TRAMP gap

- `profiles/common/.config/emacs/init.el:120` sets only
  `server-kill-new-buffers`. Direct GUI and `emacs -nw` processes do not start a
  stable named server.
- TRAMP configuration is at `profiles/common/.config/emacs/init.el:122-169`.
  `tramp-use-connection-share` is disabled, so an existing TRAMP connection is
  not a supported reverse-tunnel transport.
- `auto-revert-remote-files` is intentionally nil at
  `profiles/common/.config/emacs/init.el:116`. Remote agents need an explicit
  clean-buffer refresh path, and modified buffers must never be reverted.
- TRAMP transports files and remote processes. It does not transport an
  `emacsclient` request from a remote agent to local Emacs.

### Existing plan relationships

- `dev/plans/emacs-config-changes.md:221-243` and
  `dev/plans/emacs-config-changes-followups-1.md:140-174` established explicit,
  agent-neutral terminal delivery. Native Codex is a parallel structured
  protocol.
- `dev/plans/4-emacs-diff-in-buffer.md:36-66` and
  `dev/plans/4-emacs-diff-in-buffer.md:259-278` remain authoritative for local
  external writes, Git hunk review, and unsaved-buffer protection.
- `dev/plans/5-emacs-global-keybindings-ghostty-escape-hatch.md` remains
  unchanged.
- `dev/plans/3-emacs-annoyances-layouts.md:65-73` is a completed plan whose
  implementation has not started. Phase 1 of this plan extracts and implements
  its canonical normalized-root and tab lookup/property primitives because the
  task workflow needs them immediately. Phase 4 later implements layouts.
- Retain the prior plan's deterministic layout recipes and Gptel, Magit, and
  terminal providers. Supersede its zmx-only coding-agent contract at
  `dev/plans/3-emacs-annoyances-layouts.md:412-449` with native Codex and
  terminal-agent backends.
- The repository still pins term-sessions revision
  `0815dbea006128df1d61e9d29e5a8ada53b349c1` at
  `profiles/common/.config/emacs/install-packages.el:20-23`. The later pin in
  the unimplemented layout plan is not current repository state.

## Ownership and identity

Use independent identities and never conflate them:

1. A project Org `ID` and `PROJECT_KEY` identify the durable project grouping.
   The storage path is configurable and is not its identity.
2. A task Org `ID` is the durable task identity and primary key for journal links,
   tab state, agent routing, and resumption.
3. `WORK_KEY` is an optional, immutable, project-scoped local label. It can be
   `parser-refactor`, `ENG-123`, or a generated `work-YYYYMMDD-HHMMSS` value.
   It is not a remote identity.
4. The normalized local or TRAMP root is the live workspace identity. Linked
   worktrees may share a project file while retaining distinct task roots.
5. Optional Linear UUID is the durable identity only inside the Linear
   adapter. Linear identifier and URL are mutable display references.

One normalized root owns one managed Emacs task tab. A tab has exactly one
active Org task at a time. Rebinding another task requires confirmation and
clears only task-specific buffer caches. It does not kill processes, zmx
sessions, buffers, or task data. Concurrent tasks in one repository should use
separate linked worktrees.

The task heading survives tab deletion, Emacs restart, branch rename, agent
restart, terminal detachment, and Linear failure. The tab is only a live
projection.

`PROJECT_ROOT` is the initial discovery hint, not the project identity and not
a list of every worktree. When the same project key is encountered from another
root, prompt to reuse the existing project Org ID or choose another key. A task's
`WORKSPACE_ROOT` remains the exact live root for that task.

## Core Org task contract

### Paths and agenda

Add configurable defaults in `my-workflow.el`:

```text
project storage root   ~/org/work/projects/
storage style          file
file style             ~/org/work/projects/<project-key>.org
directory style        ~/org/work/projects/<project-key>/index.org
shared style           ~/org/work/projects.org
daily journal          ~/org/journal.org
optional detail note   any user-selected .org or .md file
```

Expose `my/work-project-storage-style` with values `file`, `directory`, or
`shared`; default to `file`. Derive the initial project key from `project-name`
and let the user edit it. If the resolved path or shared-file heading already
belongs to a different project, require an explicit existing-project choice or
a different key. Never overwrite based only on a colliding directory name.

Create a project file, directory, and heading structure on the first explicit
task creation, project log entry, or work-task capture, not during startup. At
startup, set `org-agenda-files` from existing `~/org/life.org` plus only the
primary Org file for each discovered project. For directory style, include
`<project-key>/index.org`, not every `.org` note below the directory. Register a
new primary file immediately so it appears in the same Emacs session. This
avoids an agenda error on a fresh machine and avoids creating private data as a
startup side effect. Keep `journal.org` outside the agenda.

Redirect the existing `T` capture through an owned target function. It resolves
or prompts for a project, creates the required parent directory and project
headings, then returns the `Tasks/Active` target. Do not rely on an Org file
capture target to create missing parents.

Do not add private `~/org/` data to this repository.

### Project and task schema

Use the complete shape in `Proposed project file`. A project file has one
project heading and exactly three standard branches:

```org
* Project name
:PROPERTIES:
:ID: project-org-id
:PROJECT_KEY: project-key
:PROJECT_ROOT: initial-normalized-root
:END:

** Docs

** Tasks
*** Active
**** TODO Task title
:PROPERTIES:
:ID: task-org-id
:WORK_KEY: project-scoped-key
:WORKSPACE_ROOT: /absolute/local/or/TRAMP/root/
:END:

*** Archive :ARCHIVE:

** Log
*** YYYY
**** YYYY-MM Month
***** YYYY-MM-DD Day
```

Rules:

- Create the project-level `Docs`, `Tasks`, and `Log` headings in that order.
  Their user-authored content is optional; `Docs` has no required internal
  schema, `Tasks` contains `Active` and `Archive`, and `Log` follows the
  datetree shape when entries exist. Any additional user-authored content or
  subsections are optional; the workflow still owns `Tasks/Active`,
  `Tasks/Archive`, and the `Log` datetree conventions.
- Treat `Docs` as a curated index of durable project documentation, especially
  repository Markdown shared with teammates. Do not populate it automatically
  from task notes and do not copy linked document content into Org.
- Every managed task must have a property drawer, and `ID` is the only property
  required for every task. Generate it before the first save and resolve all
  durable links by that ID.
- Accept an explicit `WORK_KEY` or generate one from the creation timestamp.
  Require uniqueness within the project heading and append the first available
  numeric suffix on a timestamp collision when `my/work-start` binds the task.
  A captured but not yet started task may omit it. Never reinterpret a local key
  as a Linear identifier.
- Keep open tasks below `Tasks/Active`. `my/work-archive` explicitly moves only
  a completed or canceled task below `Tasks/Archive`, preserves its Org ID, and
  never runs merely because an agent reports completion.
- `my/work-project-log` appends a reviewed project-level entry below the `Log`
  datetree. It is separate from the global journal.
- `WORKSPACE_ROOT` is added when the task is bound to work and preserves the
  complete normalized local or TRAMP root.
- `NOTE_FILE`, `EXEC_HOST`, `SESSION_BACKEND`, `SESSION_ID`, and
  `CODEX_THREAD_ID` are optional. Omit them when unset rather than creating
  empty properties.
- When set, `NOTE_FILE` names one existing `.org` or `.md` file. Use an Org
  `file:` link and do not copy the external note content. Keep this link on the
  task; add the same file under `Docs` only when it becomes a durable project
  reference.
- The task body and all task subsections are optional. The workflow must not
  create or require `Outcome`, `Plan`, `Log`, `Decisions`, `Evidence`,
  `Artifacts`, `Update drafts`, or any other narrative heading.
- Store a Codex thread ID only when the selected package exposes one through a
  stable public API. Otherwise its session manager remains authoritative.
- Store terminal sessions through the existing `term-session:` Org link when
  useful. Do not infer agent identity by parsing a process command.
- Never store API tokens, hook secrets, approval decisions, or entire agent
  transcripts.

An Org-only task has no `LINEAR_*` properties, `:linear:` tag, Linear heading,
or placeholder URL. Optional Linear association adds only:

```org
:LINEAR_UUID: resolved-remote-uuid
:LINEAR_ID: ENG-123
:LINEAR_URL: https://linear.app/workspace/issue/ENG-123/slug
:LINEAR_PROVISIONAL: t
```

Omit empty properties. `LINEAR_PROVISIONAL` exists only when the user explicitly
attaches a pasted identifier or URL without an API lookup. Remove it after a
successful identity resolution. Adding or refreshing an association never
changes Org `ID`, `WORK_KEY`, TODO keyword, title, note, workspace root, private
sections, or journal history.

Org TODO is the user's personal next-action state, including for a Linear-linked
task. Linear status is team-visible workflow state. Neither drives the other.

### Daily journal schema

Under the existing Org datetree day, ensure exactly one `Work log` child and
append entries in chronological order:

```org
*** 2026-09-02 Wednesday
**** Work log
- [10:30] [[id:task-org-id][compiler/parser-refactor]] start: Began implementation.
- [13:45] [[id:task-org-id][compiler/parser-refactor]] blocker: Waiting for remote test capacity.
```

The Org ID link is mandatory. Use `<project-key>/<work-key>` as its display label
so identical task keys remain readable in the cross-project journal. Add an
optional `file:` link when `NOTE_FILE` is set and an optional Linear URL only
when a real URL is stored. Never fabricate an external URL from `WORK_KEY` or
`LINEAR_ID`.

Supported explicit log kinds are `start`, `progress`, `decision`, `blocker`,
`handoff`, and `done`. These are log labels, not Org TODO keywords.

The log command may prefill text from a selected agent event, but it must show
the text for review before changing the journal. Agent hooks never append
directly.

## Core user workflow

### Start or resume work

`my/work-start` is an ordered, failure-safe operation:

1. Resolve the current project root, including its TRAMP prefix, derive the
   project key, and select or create the project storage target. Allow an
   explicit directory and project key only when no project exists.
2. Offer tasks below the project's `Tasks/Active` subtree or create one from a
   title and optional project-scoped `WORK_KEY`. It never asks for Linear.
3. Validate project/path collisions, prompts, key uniqueness, note extension,
   existing tab association, and requested rebind before writing.
4. Create or update and save the project/task headings, including both Org IDs.
   A failure here changes neither the journal nor tab context.
5. Append and save the reviewed `start` entry below today's global `Work log`. A
   failure here leaves at most a reusable unbound task and changes no tab
   context.
6. Only after both saves succeed, select or create the normalized-root task tab
   and commit the Org ID as its active context.
7. Open the effective note. Starting an already-bound active task opens it
   without another automatic `start`; a deliberate second work block uses
   `my/work-log` with kind `start`.

If journal save succeeds but tab commit is interrupted, retry detects the same
task/root start entry for the unbound tab and does not append it again. Focused
tests must inject failures after task preparation and after journal save.

### During work

- `my/work-open` opens the active task or its effective detail note.
- `my/work-log` captures one reviewed line and appends it to today's journal.
- `my/work-bind-note` changes `NOTE_FILE` after validating `.org` or `.md`.
- `my/work-set-state` changes the local Org TODO state explicitly.
- `my/work-project-log` appends a reviewed dated entry under the active
  project's `Log` datetree without changing the global journal.
- `my/work-archive` moves a completed or canceled task from `Tasks/Active` to
  `Tasks/Archive` while preserving its Org ID and journal links.
- `my/work-open-session` resumes native Codex through a public package API or
  follows the recorded terminal-session link.
- Existing hunk review and annotation commands remain independent. They do not
  implicitly change the task or journal.

### Wrap up

`my/work-draft-update` assembles an editable Markdown buffer from the task
headline and TODO state, plus explicitly selected free-form task text, project
Docs links or text, Log entries, and current-day journal entries:

```text
Changed
- concise outcome

Current status or blocker
- factual status

Evidence
- tests, review, or shareable artifact links

Next step
- next action
```

The command is useful with no tracker. By default it includes only the task
headline, TODO state, and explicitly selected current-day journal entries. All
task body, project Docs content, and Log entries require selection. Strip
property drawers and targets of local `file:`/TRAMP links while retaining safe
link labels. Scan remaining plain text for absolute paths, home-relative paths,
TRAMP syntax, and common credential forms. A match produces a visible warning
and requires acknowledgement before copy/finalize. This is review assistance,
not a claim of complete secret detection.

Core `C-c C-c` finalizes and copies the reviewed draft. An optional publisher
may consume that finalized buffer only through its own command and another
exact-target preview and confirmation.

## Dependency direction

Keep the dependency graph one-way:

```text
my-workflow.el
  Org, org-id, project/tab APIs, and my-org-datetree only

my-linear.el
  depends on public my-workflow work-item accessors

my-agent-events.el
  depends only on provider-neutral work-context lookup
```

`my-workflow.el` must compile, load, and run when `my-linear.el` is absent. No
native Codex, event, layout, MCP, or TRAMP code may require Linear. Do not build
a generalized tracker protocol yet; keep the single optional adapter in
`my-linear.el`.

## Optional Linear adapter decision

Use Linear's official GraphQL endpoint, `https://api.linear.app/graphql`, from
`my-linear.el`. The adapter is lazy and is invoked only by explicit Linear
commands.

The installed `/opt/homebrew/bin/linear` is version 2.0.0 from the community
`schpet/linear-cli` project. It supports issue, comment, JSON, and raw GraphQL
commands and remains a useful manual/debugging fallback. Do not make it a core
dependency or parse its human output.

Direct GraphQL is the recommended long-term Emacs boundary because it provides
the official endpoint, exact query fields, variables instead of interpolated
query text, deterministic JSON fixtures, and explicit mutation/error handling.
Implement it with built-in asynchronous `url-retrieve`, `json-serialize`,
`json-parse-buffer`, and `auth-source`. No third-party HTTP dependency is
justified.

### Optional Linear commands

- `my/linear-import` queries an identifier or pasted issue URL, then creates a
  normal Org task in the selected/current project or attaches the issue to a
  user-selected existing task.
- `my/linear-attach` associates an existing Org task. Online mode resolves
  identity before writing. Offline mode requires explicit confirmation and
  records only the supplied identifier or URL plus `LINEAR_PROVISIONAL`.
- `my/linear-refresh` resolves or refreshes the association and shows remote
  title, state, branch, team, and update time in a temporary comparison buffer.
- `my/linear-open` opens a stored URL and is unavailable when no URL is stored.
- `my/linear-publish-comment` consumes a reviewed generic update buffer.

Do not bind a Linear command in the core key set. Keep these commands
discoverable through `M-x` until use justifies a tracker submenu.

### Identity and reconciliation

Query an issue by identifier and request only:

```text
id
identifier
title
url
branchName
state { id name type }
team { id key }
updatedAt
```

Use GraphQL variables. Validate transport status, complete JSON, and the
GraphQL `errors` member even on HTTP 200.

Persist only `LINEAR_UUID`, current `LINEAR_ID`, canonical `LINEAR_URL`, and
the removal of `LINEAR_PROVISIONAL`. Remote title, state, branch, team, and
timestamps remain ephemeral comparison data. Import may use the remote title
once when creating a new local task; refresh never changes the local title or
TODO state. Copying `branchName` into a worktree command requires a separate
explicit action.

Before attaching a resolved UUID, scan every registered primary project file
for that UUID and for conflicting provisional identifiers. If another Org ID
already owns the UUID, make no edits and show both tasks for an explicit
detach/reassign decision. Do not auto-merge headings, rewrite journal history,
or create forwarding stubs. Team moves update only the three namespaced
identity/display properties on the already linked task.

### Authentication

- Read a personal API key from `auth-source` using host `api.linear.app` and
  login `read`. Create it with Linear's `Read` permission and restrict it to the
  required teams.
- If comment publication is enabled, read a separately scoped key using login
  `comments`. Grant only `Read` and `Create comments` for the required teams.
- Send a personal API key as the complete `Authorization` header value, without
  `Bearer`. OAuth tokens use `Authorization: Bearer ACCESS_TOKEN`.
- Keep OAuth outside this single-user plan. A distributed integration would
  require authorization code with PKCE, state validation, token refresh, and
  rotation.
- Never store a key in the repository, Org, environment inherited by agents,
  request logs, hook payloads, Gptel, or MCP.

### Publication contract

Start with `commentCreate` only:

1. Build, review, and finalize a `my/work-draft-update` buffer using the core
   `C-c C-c` copy/finalize action.
2. Invoke `my/linear-publish-comment` explicitly. Phase 8 adds this command only
   when the adapter is loaded and the active task has a resolved Linear UUID.
3. Show the exact Linear identifier, title, URL, and final body.
4. Require a yes-or-no confirmation immediately before mutation.
5. Record the returned comment ID or URL, timestamp, and body digest in a
   lazily created `Publications` subtree below the Org task.
6. Refuse an identical replay unless the user explicitly overrides it.

Do not implement a Linear state mutation in this plan. If added later, it must
use a separately permissioned key, explicit state selection, and its own
confirmation. Org TODO changes, journal entries, agent completion, tests, and
Git commits never mutate Linear.

Linear's official MCP server may optionally give an agent issue context. It
does not replace the deterministic Emacs GraphQL adapter or its publication
confirmation.

## Native Codex decision

Add `codex-ide` from `https://github.com/dgillis/emacs-codex-ide` to the
immutable VC-package table at
`profiles/common/.config/emacs/install-packages.el:10-40`.

The candidate baseline observed during planning is main commit
`5eba84dd58ad8609e8f7e8c4159d4aac90b4f303`. Phase 2 must inspect that commit's
package metadata, app-server calls, process environment, approval handling, MCP
bridge, and tests before accepting it. Record the accepted revision and reason
in this plan. Never install `:newest` or update during normal startup.

Configure it lazily:

- `SPC a a` opens or resumes native Codex for the active Org work context.
- New sessions use the normalized local project root and may include the local
  work key, title, note link, and a user-approved context summary.
- Do not send the whole project file, journal, or optional tracker metadata
  automatically.
- Public package APIs own session creation, resumption, approvals, and diffs.
  Do not inspect package internals to recover thread state.
- Existing `SPC a c`, `SPC a s`, and visual `SPC a r` retain Gptel semantics.
- Ghostel/zmx remains the Claude path, remote-agent default, and Codex fallback.
- App-server protocol state must not become a `my-send-text.el` target.

## Emacs server and agent event ingress

### Named server

Use `main` as the canonical Emacs server name:

```sh
emacs --daemon=main
emacsclient --socket-name=main --create-frame
emacsclient --socket-name=main --tty
```

Direct GUI or `emacs -nw` startup sets `server-name` to `main` and calls
`server-start` only when that named server is not already running. If another
Emacs process owns `main`, the second process is not the automation target. Do
not guess which Emacs frame is focused.

Raw `emacsclient --eval` is arbitrary code execution in Emacs. An agent can
technically use it, but the supported automated contract is the fixed event
wrapper below. Rich inspection or UI actions use the reviewed MCP allowlist.

### Data-only event API

Add `profiles/common/.config/emacs/my-agent-events.el` with one public entry
point. Allow only:

```text
progress
attention
done
error
files-changed
```

Each event contains a schema version, provider, session ID, event ID, kind,
timestamp, workspace cwd, bounded title/body, and a bounded list of relative
changed paths. It may contain an Org work-item ID and normalized workspace root.
File events may also include a provider sequence number and observed file
modification time and size. Tracker metadata is unnecessary for routing.

When Emacs launches an agent session, pass the non-secret Org ID and workspace
root to the reviewed hook wrapper environment. A manually launched agent may
omit them; Emacs then resolves cwd to exactly one normalized-root tab or records
the event as unbound when resolution is ambiguous. A reverse-tunnel listener is
configured with its remote-host/TRAMP-prefix mapping before it accepts remote
cwd values.

Reject unknown keys or kinds, absolute changed paths, parent traversal,
oversized payloads, and task/root mismatches.

Event IDs follow this order:

1. Preserve a provider-supplied unique event ID when available.
2. Otherwise hash the canonical tuple of provider, session ID, hook name,
   turn/tool ID, and provider timestamp.
3. If the payload lacks every unique discriminator, generate one UUID for that
   wrapper invocation.

Deduplicate the exact provider/session/event-ID tuple. Native app-server UI
remains the detailed thread status surface. Do not synthesize a second
`my-agent-events` completion from package UI state; Codex or Claude hooks are
the only lifecycle ingress.

Event handling must:

- enqueue UI work with `run-at-time 0` so server evaluation remains short;
- append to `*Agent Events*`;
- update one lightweight mode-line status;
- use `message` for completion and errors;
- display a buffer only for `attention` and `error`, without selecting a frame
  or stealing the current editing window;
- offer, but never perform, an explicit work-log capture;
- avoid OS notification dependencies until the Emacs-only path is proven.

### emacsclient wrapper

Add `profiles/common/.local/bin/emacs-agent-event` as a small standard-library
adapter shared by Codex and Claude hooks. It accepts explicit fields or maps a
supported provider's JSON stdin into the bounded schema.

The wrapper has two explicit transport modes and never infers one from cwd or
hostname:

- Local or same-host Emacs mode calls `emacsclient --socket-name=main` with one
  constant Lisp expression and `--alternate-editor=false`, then a literal `--`
  before every data argument. This overrides inherited `ALTERNATE_EDITOR` and
  prevents an absent server from starting another Emacs daemon. The expression
  consumes all of `server-eval-args-left`, clears the list, rejects the wrong
  argument count, and calls only the public event entry point.
- Remote-to-local mode is selected only by an explicit
  `EMACS_AGENT_EVENT_SOCKET` path installed with the reviewed tunnel setup. It
  writes one bounded newline-terminated JSON frame to that Unix socket and does
  not invoke remote `emacsclient`.

No title, body, path, ID, or JSON value is interpolated into Lisp source.

Also require `--timeout`, `--quiet`, and `--suppress-output`; preserve
provider-required stdout; never make an approval decision; fail open for agent
execution if Emacs is absent; log only a concise non-secret diagnostic; and do
not pass complete tool inputs or transcripts when stable IDs and summaries are
sufficient.

The fixed helper prevents quoting mistakes and accidental injection. It is not
a security boundary against another process that can open the raw Emacs server
socket.

Use Codex and Claude lifecycle hooks for semantic events. Install Codex hooks
only after explicit `/hooks` review, and preserve hook-specific stdout and exit
contracts. Do not parse terminal rendering or scrollback to infer agent state.

## Reviewed Emacs tool access

The optional `emacs-codex-ide` MCP bridge is separate from notifications:

```text
app-server       Codex threads, streaming, diffs, and approvals
hook event API   one-way lifecycle and attention notifications
MCP bridge       on-demand structured inspection or approved UI action
```

Keep the bridge disabled during the native-client pilot. Audit its tools and
initially allow only the smallest read surface needed for:

- current buffer, region, and point;
- visible windows;
- diagnostics;
- symbol or text search;
- explicitly requested buffer or file text.

Do not expose arbitrary Elisp evaluation, unrestricted file writes, process
creation, buffer killing, or generic function dispatch. If upstream cannot
enforce an allowlist, leave the bridge disabled until a local allowlisting
adapter exists. A later UI action such as showing a requested file must be
named, validated, scoped to the active Org task/root, and approval-gated.

## SSH and TRAMP topology

TRAMP and `emacsclient` solve different problems:

| Emacs | Agent | Event route | File route | Baseline |
| --- | --- | --- | --- | --- |
| Local | Local | Local `main` server socket | Local or TRAMP buffers in local Emacs | Supported |
| Remote | Same remote host | Remote named server socket | Remote filesystem | Supported |
| Local | Remote | Dedicated event-only reverse Unix socket | Local Emacs uses TRAMP | Supported after Phase 6 |
| Local | Remote | Raw Emacs socket reverse-forward | Local Emacs uses TRAMP | Trusted-host escape hatch only |
| Local | Remote native app-server | Package-specific remote process/path mapping | TRAMP | Deferred until proven |

### Default remote workflow

Keep local Emacs as the editor and run remote Codex or Claude in a remote zmx
session rendered by Ghostel. The Org task stores the TRAMP root and optional
term-session link. Loss of the event tunnel never prevents terminal attachment,
editing, task logging, or review.

For a remote Emacs and same-host agent, use that remote Emacs instance's named
socket. TRAMP is irrelevant in that topology.

### Event-only reverse tunnel

`my-agent-events.el` creates a separate local Unix-domain listener accepting
bounded line-delimited JSON events. Use a dedicated SSH process with `-N`,
`ExitOnForwardFailure=yes`, and `StreamLocalBindMask=0177` to reverse-forward a
stable socket path in a remote private directory. Set that path explicitly as
`EMACS_AGENT_EVENT_SOCKET` only for the intended remote agent/hook environment.

Enforce a 64 KiB maximum frame before JSON parsing, including when no newline
arrives. Accept exactly one event per connection, use a 2 second idle/read
timeout, and close malformed, oversized, extra-frame, or stalled clients. Bound
the parsed title to 256 bytes, body to 8 KiB, and changed paths to 128 entries
of at most 1024 bytes each.

Lifecycle and ownership rules:

- Create the local listener directory with mode `0700` and the local socket
  with mode `0600`.
- Create the remote socket directory with mode `0700`; after forwarding,
  verify the socket is owned by the remote user and not accessible to group or
  other users.
- Before unlinking a stale path, verify it is a socket inside the configured
  private directory and is owned by the expected user. Refuse other paths.
- Track the dedicated listener and SSH process objects. Teardown removes only
  the socket path created by that listener and only after another ownership and
  type check.
- Use a race-free stable-path restart: stop and reap the old SSH forward,
  validate and remove its remote socket, then start the replacement and require
  forward success. Accept the brief notification downtime; agent execution
  continues and falls back to the terminal workflow if replacement fails.
- Do not use automatic `StreamLocalBindUnlink` because it bypasses the explicit
  owner/type validation and can unlink an unexpected endpoint.

Do not reuse the TRAMP connection. Do not forward the Emacs server socket by
default. A raw server forward gives the remote account arbitrary local Elisp,
including access to unsaved buffers, secrets visible to Emacs, local files, and
local process creation.

### Remote changed files

Associate each listener/tunnel with one trusted remote identity: TRAMP method,
user, host, optional hop, and socket generation. Treat the event cwd only as a
remote absolute localname. Construct the local TRAMP filename from the trusted
listener association, never from a client-supplied TRAMP prefix, and then
compare it with the task's normalized TRAMP root. Two hosts exposing the same
remote `/src/foo` path must map to different task roots.

Keep the latest sequence per provider/session/root/path. Reject duplicate or
lower sequence numbers within the same session. A new session ID starts a new
sequence space. An event without a sequence is deduplicated by event ID but is
not ordered by its wall-clock timestamp. Timestamps are display metadata only;
never compare clocks across SSH hosts for buffer safety.

For an accepted event:

- Read current remote file attributes and compare them with any provider
  observed modification time and size.
- If the visiting buffer is modified, never revert it. Raise `attention`, show
  the conflict, and leave local and remote content untouched.
- If the buffer is clean, use `verify-visited-file-modtime` and current file
  attributes from the remote filesystem. Revert explicitly only when the
  buffer is clean and the current disk state differs from its visited state.
- If the buffer already reflects current disk state, ignore the notification.
  A stale notification cannot roll content backward because current remote
  attributes, not provider time, decide whether to refresh.
- If the file is unvisited, record the event and do not open or refresh a
  buffer.

Never enable global remote auto-revert polling as a substitute.

## Workspace design from `refs/eng-workflow.md`

`refs/eng-workflow.md:5-67` maps a work item to a machine, worktree, and tmux
session. `refs/eng-workflow.md:245-277` recommends tmux when tmux owns a grouped
editor, shell, agent, and test workspace. It separates local GUI Emacs plus
TRAMP from the remote terminal group at `refs/eng-workflow.md:320-376`.

Generalize its Linear-first identity into this ownership model:

```text
local task identity/state  Org task in its project file
private chronology         journal.org
detail notes               Org task body or linked Org/Markdown file
optional team tracker      Linear adapter
task presentation          Emacs tab and deterministic layouts
persistent PTY             zmx
PTY rendering              Ghostel
native Codex thread        codex app-server
semantic events            Codex/Claude hooks
```

Emacs already owns grouping and presentation, so independent zmx sessions are
sufficient. A remote `emacs -nw` setup may still run inside tmux, and a future
cross-editor dashboard may adopt one tmux session per work item. Preserve
`SESSION_BACKEND` for that later choice. Do not add tmux control mode, SQLite,
or `workd` now.

## Keybinding contract

Add only provider-neutral direct routes after their commands exist:

| Key | Command | Behavior |
| --- | --- | --- |
| `SPC o w` | `my/work-start` | Select, create, resume, or open an Org task and bind the task tab. |
| `SPC o l` | `my/work-log` | Append one reviewed entry to today's work log. |
| `SPC o u` | `my/work-draft-update` | Build a generic editable status update. |
| `SPC a a` | `my/work-codex` | Open or resume native Codex for the active Org task. |
| `SPC A` | Layout catalog agent entry | Show the selected native or terminal agent backend after Phase 4. |

Retain all current Gptel, terminal, review, Org, and Magit keys. Do not bind
these commands in Ghostel char mode or replace terminal escape hatches. Keep
optional Linear commands under `M-x` initially.

## Files to add or change

### Add

- `profiles/common/.config/emacs/my-workflow.el`
  - Project storage resolver, project/task schema, task selection and creation,
    dated project Log, archive movement, note binding, normalized root/tab
    context, journal append, update draft, and interactive commands.
- `profiles/common/.config/emacs/my-agent-events.el`
  - Event schema, event entry point, event buffer, mode line, deduplication,
    safe display, Unix listener, and clean-only file refresh.
- `profiles/common/.local/bin/emacs-agent-event`
  - Fixed-expression local `emacsclient` and provider hook adapter.
- `profiles/common/.config/emacs/my-workflow-test.el`
  - Behavior-focused task, agenda, journal, link, failure, tab, and draft tests.
- `profiles/common/.config/emacs/my-agent-events-test.el`
  - Schema, payload safety, ID derivation, routing, display, ordering,
    deduplication, and refresh tests.
- `profiles/common/.config/emacs/my-linear.el`
  - Optional async GraphQL association, comparison, and confirmed publication.
  - Add only in Phase 7.
- `profiles/common/.config/emacs/my-linear-test.el`
  - Optional adapter identity, collision, error, non-overwrite, permission,
    confirmation, and replay tests.
- `profiles/common/.codex/hooks.json`
  - Minimal reviewed lifecycle hooks invoking the wrapper. Add only after
    confirming composition with existing user/project hooks and documenting
    `/hooks` trust review.

### Change

- `profiles/common/.config/emacs/init.el`
  - Load core modules, configure paths, start the named server, redirect work
    TODO capture, set the explicit agenda, configure native Codex lazily, add
    keys, and preserve existing transports.
- `profiles/common/.config/emacs/install-packages.el`
  - Add one reviewed immutable `codex-ide` VC pin.
- `profiles/common/.config/emacs/my-org-datetree-test.el`
  - Change only if a genuinely shared date primitive is added to
    `my-org-datetree.el`; otherwise leave the generic helper untouched.
- `profiles/common/.config/emacs/leader-bindings-test.el`
  - Verify behavior and command reachability without searching source text.
- `dev/plans/3-emacs-annoyances-layouts.md`
  - In Phase 1, record that root/tab ownership moved to this plan. In Phase 4,
    update status and replace the superseded zmx-only agent provider.
- This plan
  - Record phase status, accepted pins, live topology results, optional Linear
    scope, and deviations.

## Alternatives rejected

- Make Linear the core task namespace: rejected because local tasks, agenda,
  journaling, agents, layouts, and remote work must function without it.
- Store work TODOs in `journal.org`: chronology and current task state have
  different retention and agenda behavior.
- Use one global `tasks.org` file by default: it loses useful project boundaries
  for Docs, Tasks, Log, capture, archive, and agenda navigation. Keep the
  shared-file form configurable for users who prefer it.
- Generate one Org file per work item: it creates unnecessary file sprawl and
  makes project docs, logs, and archives harder to browse. Use one primary
  file per project and durable Org IDs.
- Add a generalized tracker adapter registry: only one optional tracker adapter
  is currently in scope. Namespaced Linear functions and properties are
  simpler.
- Depend on `schpet/linear-cli` from Elisp: it is useful and installed, but its
  community command output is not the stable application boundary. Keep it for
  manual use and GraphQL debugging.
- Duplicate every Linear field in Org: it creates synchronization conflicts.
  Persist identity and URL only; display the rest ephemerally.
- Generate both Markdown and Org task records: keep Org as the private workflow
  control plane and link shared repository Markdown or existing detail notes
  without mirroring their content.
- Use Gptel as the Codex harness: Gptel does not own Codex app-server threads,
  sandboxing, approvals, or skills.
- Build a custom app-server client now: pilot and pin `emacs-codex-ide` before
  accepting that maintenance cost.
- Use ACP through `agent-shell` by default: reconsider only if a unified
  Claude/Codex buffer UI becomes more important than direct Codex fidelity.
- Make app-server a `my-send-text` target: that discards structured thread,
  approval, diff, and tool state.
- Let agents call arbitrary `emacsclient --eval`: use the event wrapper for
  notifications and reviewed MCP tools for structured interaction.
- Forward raw Emacs sockets from shared GPU hosts: use the narrow event socket.
- Parse terminal output for completion: use provider lifecycle hooks.
- Adopt tmux control mode inside Emacs now: zmx and Emacs already own the
  required persistence and presentation.

## Phase 1: Deliver project-partitioned Org tasks and daily logging

Status: pending

### Changes

1. Add `my-workflow.el` with configurable project storage root/style and journal
   path. Default to one `<project-key>.org` file; support directory `index.org`
   and shared-file forms through the same heading contract.
2. Implement project resolution and collision handling, project/task Org IDs,
   Active task selection and creation, project-scoped local keys, local TODO
   state, local/TRAMP task roots, note binding, and effective-note opening. Do
   not parse or add any Linear field or require task narrative subsections.
3. Extract and implement the canonical normalized-root, task-tab lookup/create,
   and tab-property primitives from `dev/plans/3-emacs-annoyances-layouts.md`.
   Update that plan to identify these primitives as implemented here. Do not
   implement layout recipes yet.
4. Implement one `Work log` heading per datetree day and reviewed append for
   the six log kinds. Always link the Org ID and optionally the detail note.
5. Implement optional project `Log` datetree append without automatically
   duplicating global journal text.
6. Implement the ordered `my/work-start` save and tab-commit behavior, including
   explicit confirmation before rebind.
7. Implement `my/work-set-state`, explicit completed-task archive movement, and
   the provider-neutral editable update draft.
8. Load the module in `init.el` and `my/soft-reload`, redirect work TODO capture
   through the directory-creating target function, add `SPC o w`, `SPC o l`,
   and `SPC o u`, remove the stale Custom agenda value, and build
   `org-agenda-files` from existing `life.org` and primary project files.
   Register newly created project files immediately and exclude auxiliary note
   files.
9. Add focused ERT tests with temporary project/journal storage in all three
   layouts. Test with
   `my-linear.el` unavailable and never touch the real `~/org/` tree.

### Success criteria

- With no Linear executable, module, auth-source entry, or network, a title-only
  start creates the project structure, one Active Org TODO, journal backlink,
  and bound tab context.
- A new project contains only the standard `Docs`, `Tasks`, and `Log`
  branches. A new task requires only its heading and property drawer; every
  narrative body or subsection is optional.
- Existing tasks resume by Org ID or project-scoped local key without duplicate
  headings or automatic start entries.
- Two projects with the same task key remain distinct. A project-name/path
  collision never overwrites an existing project heading.
- Two tasks on one day share one date and `Work log`; one task across multiple
  days retains the same Org ID.
- Local work TODOs from every primary project file appear in the agenda. The
  journal, directory-form auxiliary notes, and archived subtree remain absent.
- `org-agenda` works before any project file exists and includes a primary file
  immediately after capture or `my/work-start` creates it.
- Project Log entries use the documented datetree, while the global journal
  receives only its separate concise entry. Explicit archive preserves task Org
  IDs and existing journal links.
- An Org task can hold its detail or link an existing Markdown or Org file.
  Invalid extensions fail before metadata changes.
- Rebinding requires confirmation and does not kill buffers or processes.
- Injected failure after task save leaves a reusable unbound task. Failure after
  journal save is retry-idempotent and leaves tab state unchanged.
- The generic draft defaults to the documented section allowlist, strips local
  link targets and property drawers, warns on remaining path-like or credential
  text, and never claims perfect secret detection.
- A new Org-only task contains no `LINEAR_*` properties, Linear tags, headings,
  or placeholder URLs.

## Phase 2: Pilot native Codex locally

Status: pending

### Changes

1. Audit the candidate `emacs-codex-ide` commit, run its upstream tests, and
   record the accepted immutable revision.
2. Add the accepted VC package to the explicit provisioner and provision it
   outside normal startup.
3. Add lazy configuration and `my/work-codex` without enabling MCP.
4. Start or resume a session at the active local root. Include only local task
   key/title and user-approved note context.
5. Record a public stable thread ID when available; otherwise rely on the
   package session manager.
6. Add `SPC a a` and document one-command Ghostel/zmx fallback.

### Success criteria

- An Org-only work context opens a normal Emacs Codex session buffer.
- Streaming, links, approvals, diff navigation, model/sandbox controls,
  interruption, and resumption work against the installed Codex CLI.
- A second worktree gets independent task and session context.
- Gptel and Ghostel/zmx behave as before.
- App-server failure leaves Emacs responsive and terminal fallback usable.
- Normal startup performs no package or network operation.

## Phase 3: Establish the named server and local agent events

Status: pending

### Changes

1. Configure named server `main` for daemon, direct GUI, and direct `emacs -nw`.
2. Add `my-agent-events.el` with the bounded schema, deterministic ID rules,
   task/root routing, event buffer, mode-line state, deduplication, and
   non-focus-stealing display.
3. Add the fixed-expression wrapper. Put literal `--` before data, consume and
   clear every `server-eval-args-left` value, and reject wrong argument counts.
4. Add minimal Codex hooks and document equivalent Claude hooks. Review Codex
   hooks explicitly with `/hooks`.
5. Pass non-secret Org ID/root context when an agent is launched from Emacs;
   test cwd-only routing for manually launched agents and reject task/root
   mismatches.
6. Let a selected completion prefill `my/work-log` without automatic writes.
7. Add an isolated server test with a temporary name and socket directory.

### Success criteria

- Daemon GUI/TTY and direct GUI/`-nw` modes receive events at the intended
  named session; multiple processes do not create an ambiguous target.
- `progress`, `attention`, `done`, and `error` render correctly without routine
  focus stealing.
- Quotes, newlines, option-looking strings, and Lisp-looking payloads remain
  inert. The integration test proves they cannot invoke another function.
- Derived IDs deduplicate retried provider events. Native package UI does not
  create a second event-buffer completion.
- Events with and without an Org ID route by normalized root when unambiguous.
  Unbound or ambiguous events remain visible but cannot log or refresh files.
- Codex and Claude continue when Emacs is absent or the wrapper times out.
- An absent server with empty or hostile inherited `ALTERNATE_EDITOR` starts no
  daemon or fallback editor and still fails open for agent execution.
- Hook stdout/exit behavior remains valid and never approves a permission.
- No event changes Org, the journal, or Linear without a user command.

## Phase 4: Complete layouts and agent backends

Status: pending

### Changes

1. Build the deterministic layout catalog and rendering from
   `dev/plans/3-emacs-annoyances-layouts.md` on Phase 1's root/tab primitives.
   Do not introduce a second root or tab identity implementation.
2. Extend tab state with active Org ID, local key, effective note, and selected
   agent backend. Optional Linear fields are derived display data only.
3. Replace the planned zmx-only coding provider with `codex-native`, default for
   local roots, and `terminal-agent`, default for TRAMP and explicit fallback.
4. Make `SPC A` render the selected backend. Only terminal selection updates
   `my/send-text-last-target`.
5. Preserve Gptel, terminal, Magit providers, transactional rendering,
   root-scoped session names, and the public term-sessions migration.
6. Update the old plan's status, superseded text, and actual term-sessions pin.

### Success criteria

- One normalized root owns one tab and one active Org task even when tab labels
  collide.
- Local `SPC A` uses native Codex; TRAMP `SPC A` uses terminal-agent.
- `SPC G`, `SPC T`, and `SPC M` retain Gptel, terminal, and Magit behavior.
- Switching layouts kills no threads, terminals, zmx sessions, tasks, or source
  buffers.
- Native Codex never overwrites the generic send-text target.
- Task, note, agent, terminal, Gptel, and Magit state do not leak between linked
  worktrees.

## Phase 5: Audit and enable narrow Emacs MCP context

Status: pending

### Changes

1. Enumerate every tool exposed by the pinned `emacs-codex-ide` MCP bridge and
   record its parameters and authority.
2. Enable only the read operations listed above, or add a local allowlisting
   adapter if upstream cannot restrict its surface.
3. Scope reads to the active Org task/root unless another target is approved.
4. Add a UI mutation only as a named, validated, approval-gated operation.
5. Keep events and native app-server operation independent of MCP.

### Success criteria

- Codex can inspect only allowed buffer, selection, diagnostic, window, search,
  and requested text context.
- Arbitrary Elisp, unrestricted processes, buffer killing, and unapproved
  writes are unavailable.
- Cross-workspace context requires explicit approval.
- Disabling MCP leaves native Codex, Gptel, terminal agents, and events working.

## Phase 6: Add the remote event relay and TRAMP acceptance

Status: pending

### Changes

1. Add the event-only Unix listener with pre-parse frame bounds, one-event
   connections, timeouts, schema checks, and task/root validation.
2. Enforce local/remote private directory and socket permissions, stale-path
   ownership checks, tracked teardown, and the stop/validate/restart sequence.
3. Add the wrapper's explicit `EMACS_AGENT_EVENT_SOCKET` transport and document
   a dedicated SSH reverse Unix-socket tunnel independent from TRAMP.
4. Bind each listener to a trusted host/TRAMP prefix and map remote localnames
   through it. Implement per-session sequence rejection and clean-only refresh
   from current remote file attributes, never cross-host clock comparisons.
5. Exercise local Emacs plus TRAMP plus remote zmx, and remote `emacs -nw` plus
   a same-host agent.
6. Document raw Emacs socket forwarding only as a trusted single-user-host
   escape hatch with its full authority warning.
7. Evaluate `agent-shell-tramp` only if unified remote buffers become more
   important than direct Codex fidelity.

### Success criteria

- A remote terminal agent reports completion and attention to local GUI and TTY
  frames through the narrow listener.
- The default tunnel exposes no raw Emacs evaluation capability.
- Listener and forwarded socket paths have private modes; cleanup cannot unlink
  an unexpected or differently owned path.
- Clean changed TRAMP buffers refresh. Modified buffers never revert and raise
  attention. Unvisited, duplicate, stale, lower-sequence, and out-of-order
  events do not roll buffer content backward.
- Local emacsclient, explicit remote socket, and same-host remote Emacs modes
  route separately and never infer transport from cwd or host.
- Two remote hosts with the same localname cannot affect each other's tasks or
  buffers.
- Invalid roots, absolute/traversal paths, unknown kinds, and oversized payloads
  are rejected. Missing newlines, extra frames, and stalled clients are closed
  within the configured bounds.
- Tunnel loss degrades to the existing Ghostel/zmx workflow.
- Same-host remote Emacs and agent use their own named socket without TRAMP.

## Phase 7: Add optional Linear association and read context

Status: pending, optional

Skipping this phase leaves the Org workflow complete.

### Changes

1. Add lazy `my-linear.el` using built-in async HTTP, JSON, and `auth-source`.
2. Implement identifier/URL parsing, GraphQL variables, the narrow query, full
   transport validation, and redacted errors.
3. Implement import, attach, refresh, and open. Keep remote comparison fields
   ephemeral and persist only namespaced identity and URL.
4. Online attachment resolves UUID before mutation. Explicit offline attachment
   is provisional and never fabricates a URL.
5. Abort a UUID/provisional collision without edits and show both Org tasks for
   user-directed reassignment.
6. Document the direct API as primary and `linear issue view --json` plus
   `linear api` as manual diagnostics.
7. Add optional adapter tests and a compilation/load test proving the core has
   no dependency on this module.

### Success criteria

- Core commands behave identically with `my-linear.el` missing, unloaded,
  unauthorized, or offline.
- Import creates a normal Org task or attaches to one without changing Org ID,
  local key, TODO state, private content, note, root, or journal history.
- Refresh updates only UUID, identifier, URL, and provisional state. A moved
  issue retains the same Org ID and local title.
- A duplicate resolved UUID causes no mutation and presents both task IDs.
- GraphQL errors on HTTP 200, malformed JSON, authentication failure, timeout,
  and cancellation leave the Org task unchanged.
- The read key appears in no repository/Org file, agent environment, log,
  error, or fixture.

## Phase 8: Add optional reviewed Linear publication

Status: pending, optional

This phase depends on Phase 7 but no core phase depends on it.

### Changes

1. Add explicit `my/linear-publish-comment` consuming a finalized generic
   update buffer. Do not replace the core buffer's `C-c C-c` finalize/copy
   action.
2. Use the separately scoped `Read` plus `Create comments` personal API key.
3. Add exact-target preview, immediate confirmation, body-digest replay
   protection, and lazy publication receipts under the linked Org task.
4. Exercise cancel, failure, duplicate replay, and success on a disposable
   issue before ordinary use.
5. Document Linear MCP as optional agent-side context, not the publication
   contract.

### Success criteria

- The user sees and can edit exact team-facing text before any request.
- Cancel performs no mutation and confirmation targets the exact issue shown.
- Identical accidental replay is rejected.
- Success records only comment ID/URL, timestamp, digest, and final published
  body; it exposes no private paths or notes.
- Failure retains the editable draft and records no false success.
- No status changes as a side effect of comment publication or local activity.
- Without Linear, `my/work-draft-update` remains fully usable for manual sharing.

## Phase 9: End-to-end verification and handoff

Status: pending

### Mandatory automated verification

Run with temporary Org paths. The core test harness stages only the declared
core modules and tests in a temporary directory and uses that directory as its
only repository-owned `load-path`. This remains reproducible even when optional
`my-linear.el` exists in the final checkout and proves no `require`, autoload,
or feature check loads it:

```sh
core_test_dir="$(mktemp -d)"
cp profiles/common/.config/emacs/my-workflow.el \
  profiles/common/.config/emacs/my-workflow-test.el \
  profiles/common/.config/emacs/my-agent-events.el \
  profiles/common/.config/emacs/my-agent-events-test.el \
  profiles/common/.config/emacs/my-org-datetree.el \
  "$core_test_dir/"

emacs -Q --batch -L "$core_test_dir" \
  -l "$core_test_dir/my-workflow-test.el" \
  -f ert-run-tests-batch-and-exit

emacs -Q --batch -L "$core_test_dir" \
  -l "$core_test_dir/my-agent-events-test.el" \
  -f ert-run-tests-batch-and-exit

emacs -Q --batch \
  -l profiles/common/.config/emacs/leader-bindings-test.el \
  -f ert-run-tests-batch-and-exit

emacs -Q --batch \
  -l profiles/common/.config/emacs/send-text-targets-test.el \
  -f ert-run-tests-batch-and-exit

emacs -Q --batch \
  --eval '(progn (find-file "profiles/common/.config/emacs/init.el") (check-parens))'

git diff --check
```

Byte-compile each core module and focused test into a temporary directory. Run
the pinned `emacs-codex-ide` upstream suite separately. Do not add tests that
search source files for declarations.

### Optional Linear verification

Run only when Phase 7 or 8 is implemented:

```sh
emacs -Q --batch \
  -l profiles/common/.config/emacs/my-linear-test.el \
  -f ert-run-tests-batch-and-exit
```

### Mandatory manual verification matrix

1. Create two project files and resume Org-only tasks in each, including the
   same project-scoped local key. Confirm agenda state, distinct stable IDs,
   and no Linear metadata.
2. Exercise the default file layout, directory `index.org` layout, and shared
   multi-project file. Confirm all use the same project/task heading contract
   and auxiliary directory notes do not enter the agenda.
3. Link an Org detail note to one task and a Markdown note to another. Follow
   every task, journal, and detail link.
4. Add one project datetree note and one global journal entry. Confirm neither
   is silently duplicated into the other.
5. Move a completed task to the project Archive and confirm its Org ID and old
   journal links still resolve while the task leaves the active agenda.
6. Use two linked worktrees with colliding tab labels. Verify isolated tasks,
   native sessions, terminal sessions, Gptel, Magit, and events.
7. Review a native Codex change through its session diff and the existing
   source-buffer `diff-hl` workflow.
8. Run Codex and Claude in Ghostel/zmx, use the current explicit sender, and
   receive hook events without parsing terminal output.
9. Test daemon GUI/TTY and direct GUI/`-nw` against named server `main`.
10. Disconnect and reconnect the SSH event tunnel while remote zmx remains
   alive. Test clean, modified, stale, and out-of-order TRAMP file events.
11. Start with no network, no Linear credentials/configuration, `my-linear`
   unloaded, and native Codex unavailable. Confirm task, journal, generic draft,
   Gptel, and terminal workflows remain usable. Phase 1 separately proves the
   pre-adapter case where `my-linear.el` does not exist.

### Optional Linear manual verification

1. Import one disposable Linear issue and attach a second issue to an existing
   Org-only task.
2. Refresh after an identifier/team move fixture and confirm only namespaced
   identity fields change.
3. Trigger a duplicate UUID collision and confirm no heading changes.
4. Draft and publish one comment. Cancel once, induce one GraphQL failure, and
   attempt one identical replay.

### Final success criteria

- One command resolves a project file and starts or resumes an Org-backed task
  from a title or project-scoped key for a local or TRAMP root without Linear.
- Project and task Org IDs remain canonical across file, directory, and shared
  storage layouts. Org TODO remains personal task state.
- The journal is chronology and links to the durable task plus optional Org or
  Markdown detail notes.
- Native Codex, Gptel, terminal agents, events, layouts, MCP, and remote work all
  function without Linear.
- Native local Codex provides streaming, navigation, diffs, approvals, and
  resumable sessions in normal Emacs buffers.
- GUI and `-nw` sessions receive bounded semantic events through one named
  server without evaluating agent-provided Lisp.
- Reviewed MCP tools expose only intended editor context.
- Remote events expose no raw local Emacs authority and never overwrite a
  modified buffer.
- Linear optionally adds team-visible identity/context and reviewed comment
  publication without changing the core task contract.
- Linear failure affects only Linear-specific commands. Every mutation shows
  exact target/content and requires human confirmation.
- Normal startup remains offline, provisioning is deterministic, applicable
  ERT/upstream tests pass, byte compilation and `check-parens` succeed, and
  `git diff --check` is clean.

## References

### Codebase

- `profiles/common/.config/emacs/init.el:51`
- `profiles/common/.config/emacs/init.el:85-92`
- `profiles/common/.config/emacs/init.el:116-169`
- `profiles/common/.config/emacs/init.el:1289-1499`
- `profiles/common/.config/emacs/init.el:1501-1648`
- `profiles/common/.config/emacs/init.el:1795-1880`
- `profiles/common/.config/emacs/install-packages.el:10-100`
- `profiles/common/.config/emacs/my-org-datetree.el:13-55`
- `profiles/common/.config/emacs/my-send-text.el:21-226`
- `dev/plans/emacs-config-changes.md:221-243`
- `dev/plans/emacs-config-changes-followups-1.md:140-174`
- `dev/plans/3-emacs-annoyances-layouts.md:65-73`
- `dev/plans/3-emacs-annoyances-layouts.md:132-156`
- `dev/plans/3-emacs-annoyances-layouts.md:206-269`
- `dev/plans/3-emacs-annoyances-layouts.md:335-465`
- `dev/plans/4-emacs-diff-in-buffer.md:36-66`
- `dev/plans/4-emacs-diff-in-buffer.md:259-278`
- `dev/plans/5-emacs-global-keybindings-ghostty-escape-hatch.md`
- `refs/eng-workflow.md:5-67`
- `refs/eng-workflow.md:245-277`
- `refs/eng-workflow.md:320-376`
- `refs/eng-workflow.md:378-500`

### Codex, Emacs, and remote agents

- [Codex app-server](https://learn.chatgpt.com/docs/app-server)
- [Codex SDK](https://learn.chatgpt.com/docs/codex-sdk)
- [Codex non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode)
- [Codex hooks](https://learn.chatgpt.com/docs/hooks)
- [Claude Code hooks](https://code.claude.com/docs/en/hooks)
- [emacs-codex-ide](https://github.com/dgillis/emacs-codex-ide)
- [Gptel](https://github.com/karthink/gptel)
- [agent-shell](https://github.com/xenodium/agent-shell)
- [agent-shell-tramp](https://github.com/junyi-hou/agent-shell-tramp)
- [GNU Emacs server](https://www.gnu.org/software/emacs/manual/html_node/emacs/Emacs-Server.html)
- [emacsclient options](https://www.gnu.org/software/emacs/manual/html_node/emacs/emacsclient-Options.html)
- [GNU Emacs TCP server warning](https://www.gnu.org/software/emacs/manual/html_node/emacs/TCP-Emacs-server.html)
- [GNU Emacs desktop notifications](https://www.gnu.org/software/emacs/manual/html_node/elisp/Desktop-Notifications.html)
- [TRAMP remote processes](https://www.gnu.org/software/emacs/manual/html_node/tramp/Remote-processes.html)

### Optional Linear adapter

- [Linear GraphQL API](https://linear.app/developers/graphql)
- [Linear API authentication](https://linear.app/developers/oauth-2-0-authentication)
- [Linear API key permissions](https://linear.app/docs/api-and-webhooks)
- [Linear rate limiting](https://linear.app/developers/rate-limiting)
- [Linear issue moves and identifiers](https://linear.app/docs/editing-issues)
- [Linear MCP server](https://linear.app/docs/mcp)
- [schpet/linear-cli](https://github.com/schpet/linear-cli)
