# Python Cluster/OS Overlay Controller Plan

## Design and High-Level Direction

Build one thin repository-local Python controller for deterministic dotfile overlays. The public repository owns the controller and public profiles. Optional private Git repositories are cloned once beneath an ignored `.private/` root and may provide profile files, provisioning entry points, or both.

The controller resolves literal files only. It does not implement templates, a manifest, persistent state, secret storage, custom encryption, package management, or a general plugin system. Git synchronizes source repositories. Python selects and projects files. `rsync` and SSH provide generic remote push and pull. Provisioning remains an explicit primitive, while `setup` provides the one-command local bootstrap workflow.

Use one ignored private container per namespace and bundle. When one private repository owns profiles and provisioning, clone it once at the container root. When profiles and provisioning are genuinely separate repositories, clone each once at its corresponding resolved subdirectory. The controller consumes the same paths in either layout and never inspects Git metadata.

End-state public repository and optional private bundle:

```text
dotfiles/
|-- .gitignore
|-- README.md
|-- run.py
|-- profiles/
|   |-- common/
|   |   `-- .config/...                 # optional audited cross-OS shared files
|   `-- local/
|       `-- macos/                     # current tilde/ tree, preserving default behavior
|           `-- .config/...
|-- provision/
|   `-- local/                         # cluster
|       `-- macos                     # optional executable Bash script for macOS defaults
|-- .private/                           # ignored by the public repository
|   `-- work/
|       `-- nv/                        # ignored private bundle container
|           |-- .git/                  # present only for one combined clone
|           |-- README.md
|           |-- profiles/              # may instead be a separate Git clone
|           |   |-- common/
|           |   |   `-- .config/...     # private cross-OS shared work files
|           |   |-- local/
|           |   |   `-- macos/          # private local macOS overrides
|           |   |-- aws/
|           |   |   `-- ubuntu/
|           |   `-- lepton/
|           |       `-- ubuntu/
|           `-- provision/             # may instead be a separate Git clone
|               |-- local/             # cluster
|               |   `-- macos          # operating system entry point
|               |-- aws/
|               |   `-- ubuntu
|               `-- lepton/
|                   `-- ubuntu
|-- dev/plans/python-script-setup.md
`-- refs/                               # ignored read-only references
    `-- run.py
```

The public repository adds the anchored ignore `/.private/`. When one private repository contains both directory trees, clone it once with:

```bash
git clone <private-url> .private/work/nv
```

When they are separate repositories, use the same ignored container without duplicating either clone:

```bash
mkdir -p .private/work/nv
git clone <private-profile-url> .private/work/nv/profiles
git clone <private-provision-url> .private/work/nv/provision
```

In the split layout, the profile repository root contains `common/` plus cluster directories such as `local/`, `aws/`, and `lepton/`. Each cluster contains one directory per supported operating system. The provisioning repository root uses the same `<cluster>/<os>` partition, with one executable at each terminal path. These produce the same resolved paths as the combined layout.

Do not add private repositories as public submodules, record their URLs in the public repository, auto-clone them, or search arbitrary directories for them.

## Status

- Plan state: complete (5/5 phases implemented).
- Current phase: N/A.
- Next up: N/A.
- During execution, update this section and each Phase status only after that phase's validation passes.
- `refs/run.py` and `refs/mcu` are read-only references and must never be modified.

## Controller Contract

### Cluster identifiers, operating systems, and private bundle resolution

Every profile-aware command accepts `--profile`, which selects a cluster and defaults to `local`. Projection always resolves a cluster and operating system together.

Support two identifier forms:

- Public profile: `<cluster>`, for example `local`.
- Private bundle profile: `<namespace>/<bundle>/<cluster>`, for example `work/nv/lepton`.

Each component must match `[a-z0-9][a-z0-9_-]*`. Reject absolute paths, backslashes, empty components, `.`, `..`, and the reserved cluster name `common`. Do not accept any other component count.

Resolve `local` from the public repository. Parse `work/nv/lepton` into `.private/work/nv/` as the bundle container and `lepton` as the cluster. Parsing returns these deterministic candidate paths without requiring either profile or provisioning content. Each command validates only the content it needs and reports the exact missing path with a short clone/setup explanation.

Projection commands also select an operating system:

- `setup` and `clean` operate on the current machine. Their optional `--os` overrides host detection; otherwise map Darwin to `macos` and use the lowercase Linux `ID` from `/etc/os-release`.
- `push` and `pull` accept an optional positional `TARGET`. When it is omitted, they use the current machine with the same optional `--os` behavior as other local commands. When it is present, they require explicit `--os` because the remote target may differ from the controller host.
- `render` may target a different system, so it requires explicit `--os`.
- `provision` keeps its required positional operating system argument and never infers it from the controller host.

An explicit or detected operating system follows the same component grammar. Keep host detection injectable for validation. If detection is unsupported, `/etc/os-release` is missing or malformed, or its result is invalid, fail with a request for explicit `--os`.

Layer precedence is lowest to highest:

1. `profiles/common/`, when it exists.
2. `profiles/<cluster>/<os>/`, when it exists.
3. `.private/<namespace>/<bundle>/profiles/common/`, for private profiles, when it exists.
4. `.private/<namespace>/<bundle>/profiles/<cluster>/<os>/`, required for a private profile.

Projection commands (`push`, `pull`, `clean`, and `render`) require `profiles/<cluster>/<os>/` for a public profile or the corresponding private cluster and operating system directory for a private profile. A private profile may reuse public common and public files for the same cluster and operating system. Later layers override the same home-relative file from earlier layers. `provision` does not resolve or require profile files. `setup` requires a profile whose cluster is `local`, because it pushes into the current machine's home; both `local` and a private identifier ending in `/local` are valid.

Keep all path policy in direct constants and profile parsing code next to `repo_root = Path(__file__).resolve().parent`. Do not add a registry, configuration manifest, environment search path, or home-directory scan.

### Effective file map

Every common or `<cluster>/<os>/` profile directory directly mirrors paths below the target home. There is no intermediate `files/` directory. Build one sorted effective mapping from home-relative path to its winning source file and owner layer.

- Accept regular files only.
- Reject symlinks and special files rather than following them.
- Reject symlinked directories encountered while walking a layer.
- Reject file-versus-directory collisions across layers, such as one layer containing `.config/tool` as a file while another needs `.config/tool/config`.
- Do not treat repository metadata, provisioning files, or `.gitkeep` placeholders as managed files.

Push, pull ownership, clean, and render must consume this same mapping. Directory placement is the ownership model. Do not add a manifest or state database.

The current `tilde/` tree is not assumed to be portable. It contains local-machine and macOS-specific configuration. Migrate it conservatively to `profiles/local/macos/` so the default profile preserves current behavior. Leave public `profiles/common/` empty except for an optional placeholder until individual cross-OS files are deliberately audited and promoted. Do not classify the whole current tree as common during this port.

### Commands

Follow the uv PEP 723 and `msup.cli.cli` structure in `refs/run.py:1-10` and `refs/run.py:158-175`, omitting its local `[tool.uv.sources]` block and unrelated project tasks.

Provide these commands:

- `setup`: provision the current machine when an entry point exists, then push its local profile overlay to the current home.
- `push`: copy the effective overlay to the current home by default, or send it to a remote home through rsync/SSH when positional `TARGET` is supplied.
- `pull`: copy selected or currently managed paths from the current home back to their owner layers by default, or fetch them from a remote home first when positional `TARGET` is supplied.
- `clean`: remove only paths in the current effective mapping from the destination home.
- `render`: copy the effective overlay to an explicitly supplied output directory for another tool to consume.
- `provision`: execute the selected cluster and operating system's provisioning entry point explicitly.

Keep source, destination, private-root, and subprocess boundaries parameterized below the CLI so smoke validation can use temporary directories. Use one logged `run` function modeled on `refs/run.py:22-31` for argument arrays and external commands. It prints commands with `shlex.join`, removes `VIRTUAL_ENV` from child environments, never uses `shell=True`, and skips `subprocess.run` when `dry_run` is true. Prefer `rsync` commands over Python file-copy APIs for projection.

Add `--dry_run` directly through `msup` to `setup`, `push`, `pull`, and `clean`; do not rewrite `sys.argv`. Dry-run mode performs normal parsing, profile resolution, mapping construction, collision checks, path validation, and command construction, then prints sorted affected paths and any external command without copying, removing, modifying profile files, executing provisioning, or starting a subprocess. It is an action preview, not content diff generation.

Do not add atomic destination writes, backup files, content diff generation, conflict merging, rollback, templates, custom cryptography, or chezmoi. Normal file and subprocess failures may stop a command with a clear error.

### Local setup

Use this interface:

```text
./run.py setup
./run.py setup --profile local --os macos
./run.py setup --profile work/nv/local --os macos -- --provision-argument
```

`setup` is the local golden path and is equivalent to a successful optional `provision` followed by a local `push` for the same profile and operating system. It defaults to profile `local`, accepts only profiles whose cluster is `local`, targets `Path.home()` at the production CLI boundary, and never accepts a remote target or `--remote-home`.

When `--os` is omitted, use the shared local host detection defined for profile resolution. Keep OS detection and the home root injectable for validation.

Resolve provisioning with the same private-first and public-fallback rules as `provision`. Provisioning is optional for `setup`: when no matching entry point exists, print that it was skipped and continue to push. If an entry point exists, run it first and stop without pushing if it fails. Forward arguments after `--` only to that entry point. `setup --dry_run` reports whether provisioning would run or be skipped and previews the subsequent local push without executing either operation.

Do not extend `setup` to remote targets. Remote provisioning may create a target, discover its SSH address, or embed a rendered overlay during target creation, so it cannot be composed generically with `push` without introducing a target-discovery protocol. Keep remote workflows explicit with `provision` and `push`, or allow a private provisioner to call `render` and deliver the overlay when provisioning and initial projection are inseparable.

### Local push and clean

Use this interface:

```text
./run.py push
./run.py push --profile local --os macos
```

Local `push --profile local` is equivalent to omitting `--profile`. Both forms detect the current operating system unless `--os` is supplied. Local push uses the shared logged `run` function to execute `rsync` commands that create parent directories and overwrite each effective file in `Path.home()`. It never deletes unrelated home files.

`clean` unlinks only current effective file paths, tolerates missing files, and leaves directories in place. Because there is no manifest, files removed or renamed in a source profile are not remembered and may remain in a home directory after an earlier push. Document this limitation. Do not compensate with a broad home-directory scan or `rsync --delete`.

### Pull and ownership

Use this interface:

```text
./run.py pull [TARGET] [--path PATH [PATH ...]] [--profile local] [--os macos] [--layer owner|common|profile]
```

Without `--path`, pull every path in the current effective mapping. One native multi-value `msup` option, `--path PATH [PATH ...]`, selects home-relative files or directories and allows new files to be added deliberately. The installed `msup` collection mapping uses `nargs="*"` and does not expose an append action, so repeated `--path` occurrences are not supported; do not patch its parser or rewrite `sys.argv`. Keeping selections behind `--path` leaves the optional positional `TARGET` unambiguous. Reject absolute paths, traversal, special files, final symlinks, and symlinked parents that could escape the supplied home root.

`--layer` defaults to `owner`:

- For an existing effective path, write back to the layer that currently owns the winning file.
- For a new path, require explicit `--layer common` or `--layer profile`.
- For a public profile, `common` means public common and `profile` means the selected public `<cluster>/<os>` directory.
- For a private profile, `common` means the private bundle's common layer and `profile` means the private bundle's selected `<cluster>/<os>` directory.
- If an explicit target layer would be hidden by a later existing layer, fail and explain which layer would still win.

Resolve directory pull ownership independently per regular file in sorted order. Local pull reads from `Path.home()`, creates profile-layer parents, and uses the shared logged `run` function with `rsync`. It does not sweep the home directory, delete source files, infer new-path ownership, or rewrite another layer.

### Generic render

Use this interface:

```text
./run.py render OUTPUT_DIRECTORY --profile local --os macos
./run.py render OUTPUT_DIRECTORY --profile work/nv/lepton --os ubuntu
```

`render` creates the output directory when needed, projects only the validated effective mapping with home-relative paths through the shared logged `run` function and `rsync`, and overwrites matching files. It does not clean unrelated output files. Callers that need an exact artifact should provide an empty temporary directory.

`render` is intentionally generic. The public controller has no Lepton archive, base64, pod creation, or `LEPTON_DOTFILES_ARCHIVE` command. Private work provisioning may call `render` into a temporary directory and then own any work-specific tar, base64, and pod-delivery behavior.

### Remote push and pull mode

Use this transport-only interface:

```text
./run.py push user@host --profile local --os macos
./run.py push root@resolved-teleport-host --profile work/nv/lepton --os ubuntu
./run.py pull user@host --profile work/nv/aws --os ubuntu
./run.py pull user@host --path .config/tool --profile work/nv/aws --os ubuntu --layer profile
```

Target discovery and authentication remain outside the controller. In particular, the private work bundle may retain helpers equivalent to `tssh-url` from `refs/mcu/clusters/laptop/.zshrc-work`, then pass the resulting ordinary SSH destination to `push` or `pull`. Do not hardcode NVIDIA hostnames, Teleport labels, or private infrastructure rules into public Python code.

For remote `push`:

1. Materialize the validated effective mapping under `tempfile.TemporaryDirectory` using its home-relative paths.
2. Invoke one `rsync -a --no-owner --no-group <staging>/ <target>:<remote-home>/` command.
3. Default the remote home expression to `~/`; allow an explicit absolute POSIX `--remote-home`.
4. Never pass `--delete`.

For remote `pull`:

1. With no explicit paths, generate a temporary sorted `--files-from` list containing every path in the current effective mapping. With explicit paths, fetch only those validated selections.
2. Pull those paths from `<target>:<remote-home>/` into a temporary staging directory with rsync.
3. Apply the same owner, explicit layer, new-path, directory recursion, and shadowing rules as local pull, then project each staged regular file to its resolved layer through the shared logged `run` function and `rsync`.
4. Do not discover or import unselected remote files, change ownership, delete source files, infer new-path ownership, or follow remote symlinks.

Push and pull are intentionally one-way operations, not automatic two-way synchronization. Both overwrite their selected destination on the happy path. Pull fails if an expected selected remote file is missing. Temporary staging guarantees that remote operations use the same winning paths and exclusions as local push, local pull, and render. It is transient transport preparation, not atomic destination replacement or persistent state.

The local and remote systems require rsync and working SSH authentication. A new Ubuntu server does not need Python, uv, msup, Git, or either dotfile repository. Install rsync through the server image, manually, or through an explicit profile provisioner before the first push.

Example new Ubuntu flow:

```bash
ssh user@server 'sudo apt-get update && sudo apt-get install -y rsync'
./run.py push user@server --profile work/nv/aws --os ubuntu
```

The public plan does not execute this example during validation.

### Provisioning and private repositories

Provisioning is optional and never runs from `render`, `push`, `pull`, or `clean`. Only the explicit `provision` primitive and the local `setup` orchestration command execute a provisioning entry point.

Use this interface:

```text
./run.py provision macos --profile local
./run.py provision ubuntu --profile work/nv/lepton -- --target pod-name
```

The required positional operating system component follows the same `[a-z0-9][a-z0-9_-]*` grammar as a profile component. It names the target operating system, such as `macos` or `ubuntu`; `provision` never infers it from the controller host. For provisioning, the selected profile supplies the cluster component. Resolve exactly one `<cluster>/<os>` entry point without resolving profile file layers:

- Public profile: `provision/<cluster>/<os>`.
- Private profile: prefer `.private/<namespace>/<bundle>/provision/<cluster>/<os>`; if absent, fall back to `provision/<cluster>/<os>` when the public entry point exists.

Require the operating system entry point to be a regular, non-symlink executable. Invoke it directly, set its working directory to its cluster directory, remove `VIRTUAL_ENV` from its environment, set non-secret `DOTFILES_REPO_ROOT`, `DOTFILES_PROFILE`, and `DOTFILES_OS` context variables, and forward arguments following `--` unchanged. `provision/local/macos` is a Bash script with `#!/usr/bin/env bash`; other entry points may select Bash, Python, or another interpreter through their shebang. Do not implement a provisioning plugin API or automatically compose multiple entry points.

Provisioning owns package installation, macOS defaults, cluster setup, pod creation, mounts, and target discovery. Profile files own only configuration projected into a home directory. A private provisioner may call `render` and deliver that rendered overlay when target creation and initial projection are inseparable; this is provisioner-specific behavior and does not make the generic `provision` command perform an additional automatic `push`.

Private Git repositories are not secret stores. Keep credentials, tokens, private keys, `.secrets`, Vault values, and platform secret material outside every profile and rendered output. Authentication remains the responsibility of Git, SSH, Teleport, Vault, environment injection, or the target platform. The controller never reads or writes secret values.

## Phase 1: Layout, resolution, and default local push

Status: complete.

Deliver the smallest working local overlay while preserving current local-machine behavior.

Work:

1. Add `/.private/` to `.gitignore` without changing unrelated ignore entries.
2. Add root `run.py` with the uv header, `msup` command mapping, repository constants, cluster parsing, injectable host OS detection, deterministic public/private `<cluster>/<os>` layer resolution, regular-file validation, collision checks, and the sorted effective mapping.
3. Move the current `tilde/` tree unchanged to `profiles/local/macos/`. Do not promote any file to public common during the initial port.
4. Implement local `push`, including `--dry_run`, with `Path.home()` at the production CLI boundary and injectable roots for temporary-directory validation.
5. Run focused smoke checks for detected and explicit operating systems, default `local`, all four precedence layers for the same OS, strict separation between macOS and Ubuntu files, parent creation, overwrite behavior, dry-run action reporting without writes, symlink rejection, and file-versus-directory collisions.
6. Update this plan to `1/5 phases implemented` only after Phase 1 validation passes, then set the current phase to Phase 2.

Implementation results:

- Added the executable `run.py` controller with native `msup` CLI mapping, collected boundary errors, deterministic public/private layer ownership, and sorted effective mappings.
- Local push uses the shared logged `run` function with exact-path `rsync` commands. `--dry_run` prints those commands without creating parents or starting subprocesses.
- Source layer ancestors and destination parents are validated without following symlinks. Destination preflight collects all errors before any projection command runs.
- Migrated all 13 tracked `tilde/` files to `profiles/local/macos/` as byte-identical Git renames with their modes preserved.
- Temporary-directory smoke validation covered the Phase 1 success criteria, source and destination boundary regressions, actual `msup` help, real `rsync` projection, Ruff, formatting, and Git diff checks.

Affected code pointers:

- `.gitignore`
- `run.py` (new)
- `profiles/local/macos/` (new location for `tilde/` contents)
- `profiles/common/` (optional future shared layer without a `files/` wrapper)
- `tilde/` (remove after migration)
- `refs/run.py:1-31` (read-only reference)

Phase success criteria:

- `./run.py push` and `./run.py push --profile local` resolve the same detected operating system and profile layers.
- The default local push projects every file previously managed under `tilde/`.
- Profile resolution never mixes files from different operating systems.
- `push --dry_run` reports the same sorted local destinations as a real push without changing them.
- A private identifier resolves only beneath the deterministic `.private/<namespace>/<bundle>/` root.
- Profile precedence and owner reporting are identical regardless of the current working directory.
- Validation never reads from or writes to the real home directory.

## Phase 2: Local pull ownership and cleanup

Status: complete.

Add explicit reverse flow without gradually forking common files into profile overrides.

Work:

1. Implement native multi-value `--path PATH [PATH ...]` selections for local pull through the real `msup` CLI boundary, including documented option placement. No paths selects the current effective mapping. Phase 3 adds the optional positional remote target.
2. Implement local owner-based pull, explicit common/profile layers, directory recursion, new-path rules, shadowed-layer rejection, and `--dry_run` action reporting.
3. Implement `clean` and its `--dry_run` mode from the same effective mapping used by push and pull.
4. Smoke-check public and private owners, new paths, explicit layers, traversal rejection, clean selection, missing clean targets, and dry-run behavior with temporary roots.
5. Document in CLI help that clean cannot remove paths no longer present in the current source mapping.
6. Update this plan to `2/5 phases implemented` only after Phase 2 validation passes, then set the current phase to Phase 3.

Implementation results:

- Added local pull with native multi-value `--path PATH [PATH ...]`, owner/common/profile routing, sorted directory expansion, and real `msup` option placement. Repeated `--path` flags remain unsupported because `msup` exposes no append action and argument rewriting is prohibited.
- Existing files update their actual winning public or private owner by default. Explicit private common/profile selections resolve only beneath the deterministic ignored private bundle roots.
- New files require explicit ownership and are rejected when excluded from the mapping or when they would create a file/directory collision. Explicit lower-layer writes are rejected when a later layer would still win.
- Pull uses exact-path checksum-enabled `rsync` commands through the shared logged runner. All selections, source paths, destination layers, and errors are preflighted before any command runs.
- Added mapping-only clean with full preflight, missing-target tolerance, directory preservation, and `--dry_run` action reporting.
- Temporary-directory validation covered public/private ownership, new and explicit layers, directory recursion, traversal and symlink boundaries, exclusions, collisions, clean behavior, dry-run equivalence, real rsync, native CLI help, Ruff, formatting, and Git diff checks.

Affected code pointers:

- `run.py`
- `profiles/local/macos/`
- temporary public and private common/profile fixtures used only during validation

Phase success criteria:

- Existing paths pull back to their winning owner by default.
- New paths require explicit common or profile ownership.
- Explicit `common` or `profile` pulls for a private profile write only inside its ignored private bundle. Owner-mode pulls continue to update each effective file's actual public or private winning owner.
- Push, pull, and clean use the exact same effective mapping.
- Pull cannot escape the supplied home or repository layer roots.
- Pull and clean dry runs perform full validation and report actions without changing home or profile files.

## Phase 3: Generic render and remote push/pull mode

Status: complete.

Project the same validated mapping to explicit output directories and persistent SSH targets.

Work:

1. Reuse and extend the logged subprocess helper established in Phase 1.
2. Implement generic `render` from the effective mapping.
3. Extend push so a positional `TARGET` selects remote mode, requires explicit `--os`, stages temporarily, and performs one rsync operation with no delete behavior. Preserve the existing no-target local push path.
4. Extend pull so a positional `TARGET` selects remote mode, requires explicit `--os`, stages selected paths through rsync, and applies the same owner-layer rules as local pull. Preserve the existing no-target local pull path.
5. Implement raw SSH target handling and `--remote-home` validation. Reject `--remote-home` when positional `TARGET` is omitted. Keep Teleport and private target discovery outside public Python.
6. Smoke-check push and pull through a temporary fake `rsync` executable, covering exact argument arrays, staging contents, owner writes, missing remote files, subprocess failures, dry-run behavior, and absence of `--delete`.
7. Compare temporary local push output, explicit render output, and staged remote push output for the same fixture.
8. Update this plan to `3/5 phases implemented` only after Phase 3 validation passes, then set the current phase to Phase 4.

Implementation results:

- Added `render OUTPUT_DIRECTORY --os OS` through the same validated mapping and checksum-enabled rsync projection used by local push. Render creates its root, overwrites managed paths, and preserves unrelated output files.
- Added optional positional raw SSH targets to push and pull. Remote mode requires explicit `--os`, defaults the remote home to `~/`, validates explicit absolute POSIX homes without dot traversal, and rejects remote-only options in local mode.
- Remote push projects only managed files into a temporary staging root and performs one no-delete transport rsync. Remote pull uses a sorted `--files-from` list with explicit recursion, stages only selected paths, and reuses local ownership routing for repository writes.
- Remote dry runs create no staging directory or files, start no subprocess, and use stable conceptual staging paths. They validate all locally available contracts and state that remote contents and directory expansion cannot be verified without contact.
- Temporary fake-transport and real local-rsync validation covered exact argument arrays, winning staging contents, render/local/remote equivalence, recursive remote pull, owner writes, missing paths, failure propagation, dry-run isolation, no `--delete`, real CLI ordering, Ruff, formatting, and Git diff checks.

Affected code pointers:

- `run.py`
- `refs/mcu/clusters/*/sync.sh` (read-only transport reference)
- `refs/mcu/clusters/laptop/.zshrc-work:61-92` (read-only private work-flow reference)
- `refs/mcu/clusters/lepton/container_setup.sh:24-29` (read-only private work-flow reference)

Phase success criteria:

- Local push, render, and remote push produce the same effective files and winning contents when given the same cluster and operating system.
- Remote push and pull invoke logged rsync commands with argument arrays and no shell.
- Push never transfers source repository metadata, placeholders, symlinks, or provisioning files; pull never imports unmanaged files.
- The target does not require the controller or either Git repository.
- Pull updates the current owner layer for each managed path.
- Push and pull dry runs validate and report their complete planned actions without contacting a remote target.

## Phase 4: Provisioning and private bundle integration

Status: complete.

Add explicit provisioning and the local setup golden path while keeping remote orchestration explicit.

Work:

1. Reuse the operating system component validation added in Phase 1 to implement public/private `<cluster>/<os>` provisioning resolution, private-first fallback, executable validation, working directory, environment handling, and argument forwarding after `--`.
2. Move the six useful macOS `defaults write` operations from `scripts/osx` into the executable Bash script `provision/local/macos`. Use `#!/usr/bin/env bash` and do not carry forward the obsolete Homebrew installer.
3. Implement local-only `setup` as optional provision followed by local push. Enforce a `local` profile cluster, reuse the injectable host OS detection and home boundaries established in Phase 1, accept explicit `--os`, forward provisioner arguments after `--`, and add `--dry_run`.
4. Validate both supported physical layouts with temporary directories: one combined bundle root, and separate profile/provision repository roots beneath the same ignored container. The controller does not inspect `.git/`.
5. Smoke-check operating system validation, public fallback for the same cluster and operating system, private override, executable requirements, context variables, forwarded arguments, subprocess failure propagation, and a provision-only private repository with no profile directory.
6. Smoke-check setup with detected and explicit operating systems, absent optional provisioners, provisioning failure before push, rejected non-local clusters, private local profiles, forwarded arguments, dry-run behavior, and successful provision-then-push ordering. Never use the real home or host provisioner during validation.
7. Document the combined and split private repository layouts. Each private repository is cloned once, and both layouts expose identical controller paths.
8. Keep MCU cluster setup, Teleport helpers, Lepton archive creation, pod creation, and secret injection in the private bundle when that repository is migrated. A private Lepton entry point may call the public generic `render` command, then perform its own tar/base64 delivery. Do not copy private infrastructure details into public files.
9. Update this plan to `4/5 phases implemented` only after Phase 4 validation passes, then set the current phase to Phase 5.

Implementation results:

- Added explicit public/private provisioning resolution with deterministic private-first fallback, regular non-symlink executable validation, direct argument arrays, provisioner working directories, and non-secret context variables.
- Added local-only setup orchestration. It detects or accepts the operating system, optionally runs the selected provisioner, stops on provisioning failure, and then projects the validated local profile mapping.
- Added native `msup` provisioner argument forwarding after `--` for both provision and setup. The generated `--provision_args` help entry remains an unavoidable upstream parser artifact; product code does not rewrite arguments.
- Migrated the six active macOS defaults operations to executable `provision/local/macos` with fail-fast shell behavior and omitted the obsolete Homebrew installer.
- Temporary-directory validation covered combined and split private layouts, provision-only bundles, private override and public fallback, exact arguments, environment and working directory, executable and containment boundaries, setup ordering, failure propagation, dry-run isolation, native CLI help, Ruff, formatting, Bash syntax, and Git diff checks.

Affected code pointers:

- `run.py`
- `provision/local/macos` (new executable Bash script)
- `scripts/osx` (migration source)
- `refs/mcu/clusters/*/setup.sh` (read-only private migration reference)
- `refs/mcu/clusters/lepton/container_setup.sh` (read-only private migration reference)

Phase success criteria:

- One clone at `.private/work/nv/` can supply all private profile and provisioning cluster/operating-system pairs.
- Separate clones at `.private/work/nv/profiles/` and `.private/work/nv/provision/` can supply the same paths without cloning either repository twice.
- A provision-only private repository can run `provision` without a corresponding profile directory. Projection commands still require their selected profile directory.
- No projection primitive executes provisioning. Only `setup` composes optional provisioning with local push.
- The explicit `provision` command resolves one exact `<cluster>/<os>` executable and never infers the target operating system from the controller host.
- Provisioning receives arguments unchanged and failures stop the command.
- `./run.py setup` detects the local operating system, optionally provisions `local`, and pushes the default profile to the current home in that order.
- Setup skips a missing optional provisioner, never pushes after a provisioning failure, rejects non-local clusters, and never targets a remote host.
- Setup dry-run previews both stages without executing the provisioner or writing to the home directory.
- Private bundle absence never affects the default public local workflow.

## Phase 5: Documentation and legacy Bash removal

Status: complete.

Make `run.py` the maintained public interface after all replacement behavior is validated.

Work:

1. Rewrite `README.md` with the uv prerequisite, final repository tree, identifier grammar, `setup` as the default local onboarding path, local and remote push/pull behavior, dry-run behavior, overlay precedence, pull ownership, clean limitations, private clone setup, generic render, Ubuntu rsync prerequisite, provisioning entry points, and secrets boundary.
2. Document command examples with the exact option ordering accepted by the real CLI.
3. Document migration from `./install` to `./run.py setup` or local push, from `scripts/self_update` to local pull, from the broken `./clean` to clean, and from the relevant MCU sync and provision flows to remote push, remote pull, provision, and private orchestration. State that Lepton archive behavior remains private.
4. Run the focused temporary-directory smoke checks and CLI help before deleting legacy files.
5. Delete `install`, `clean`, `scripts/mv_dotfiles`, `scripts/self_update`, `scripts/osx`, `scripts/linux`, and `scripts/variables.sh`. Remove `scripts/` if it becomes empty.
6. Search tracked files for stale active references to legacy commands and `tilde/`. Preserve historical migration references in this plan.
7. Keep all of `refs/`, including `refs/mcu`, unchanged.
8. Update plan status to `complete (5/5 phases implemented)` and `Next up: N/A` only after final validation passes.

Implementation results:

- Rewrote `README.md` around the uv-driven Python controller, setup-first onboarding, exact native command ordering, deterministic overlays, owner-aware pull, clean limitations, render, provisioning, remote rsync, private bundle layouts, and the secrets boundary.
- Documented native one-option multi-value `--path` selection and provisioner argument forwarding after `--` without recommending generated upstream parser artifacts.
- Documented direct migration from the removed local Bash workflows and the public/private boundary for remote MCU and Lepton orchestration.
- Smoke-checked all command help surfaces and replacement workflows with isolated homes, outputs, transports, and provisioners before removing the legacy entry points.
- Deleted `install`, `clean`, and the five legacy scripts after validation. The empty `scripts/` directory was removed, and all of `refs/` remained unchanged.
- Final validation covered native CLI parsing, local and remote dry runs, real isolated local rsync projection, overlay ownership, render, provisioning, Ruff, formatting, Python and Bash syntax, deletion scope, stale-reference gates, and Git diff checks.

Affected code pointers:

- `README.md`
- `run.py`
- `install` (delete)
- `clean` (delete)
- `scripts/mv_dotfiles` (delete)
- `scripts/self_update` (delete)
- `scripts/osx` (delete after migration)
- `scripts/linux` (delete)
- `scripts/variables.sh` (delete)

Phase success criteria:

- `README.md` documents only commands, paths, and limitations that exist.
- `README.md` leads with `./run.py setup` for a new local machine and presents local/remote push and pull, provision, render, and clean as explicit lower-level workflows.
- The public repository contains no private clone URL or private infrastructure rule.
- The Python controller replaces useful current Bash behavior without absorbing provisioning or secret management.
- Legacy files are removed only after replacement smoke checks pass.

## References

- `refs/run.py:1-31` and `refs/run.py:158-175`: uv runner, subprocess logging, and `msup` command mapping reference.
- `refs/mcu/clusters/*/sync.sh`: current common/profile rsync behavior to replace.
- `refs/mcu/clusters/laptop/.zshrc-work:61-92`: private Lepton archive and pod creation flow that stays outside public `run.py`.
- `refs/mcu/clusters/lepton/container_setup.sh:24-29`: private archive extraction contract.
- `scripts/osx:11-67`: current macOS defaults and obsolete Homebrew bootstrap source.
- [uv script dependencies](https://docs.astral.sh/uv/guides/scripts/#declaring-script-dependencies)
- [rsync manual](https://download.samba.org/pub/rsync/rsync.1)

## Final Validation

Run only non-mutating validation against real user and remote state:

```bash
./run.py --help
git diff --check
git status --short
! git grep -nE 'scripts/(mv_dotfiles|self_update|osx|linux|variables\.sh)|\./install|\./clean|tilde/' -- . ':(exclude)dev/plans/python-script-setup.md' ':(exclude)README.md'
awk '
  /^## Migration$/ { in_migration = 1; next }
  /^## / { in_migration = 0 }
  !in_migration && /scripts\/(mv_dotfiles|self_update|osx|linux|variables\.sh)|\.\/install|\.\/clean|tilde\// { found = 1; print }
  END { exit found }
' README.md
```

Use temporary directories and temporary fake executables for focused setup, local and remote push, local and remote pull, clean, render, provisioning, dry-run, and CLI smoke checks. Keep these checks in the execution transcript rather than adding a permanent test module. Do not run those commands against the real home, remote hosts, Teleport, private repositories, or the host package manager during validation.

## Overall Success Criteria

- The plan's end-state structure is implemented, with public profiles in the main repository and each optional private repository cloned once under ignored `.private/` paths.
- `--profile` selects a cluster and defaults to `local` for every profile-aware command.
- Every projection resolves one exact `<cluster>/<os>` profile. Local commands detect the host operating system unless overridden; render and remote transport require explicit `--os`.
- `./run.py setup` is the local golden path: it detects or accepts the host operating system, optionally provisions the local cluster and operating system, and pushes that exact profile to the current home in order.
- Public `local` preserves every currently managed `tilde/` file unless a later audited move to public common is intentional and validated.
- Private identifiers and operating systems resolve deterministically as `.private/<namespace>/<bundle>/profiles/<cluster>/<os>/` without scanning outside the checkout.
- `profiles/common/` directly mirrors the home directory without a `files/` wrapper.
- Public common, public `<cluster>/<os>`, private common, and private `<cluster>/<os>` precedence is identical for push, pull, clean, and render.
- Local and remote pull update existing owner layers by default and require explicit ownership for new files.
- Provisioning is optional. The explicit primitive resolves `provision/<cluster>/<os>`; local `setup` may invoke it before a local push. Provisioning may share one private repository with profiles or come from its own single clone without changing resolved paths.
- Remote push sends only the validated effective mapping, and remote pull fetches only its selected paths.
- Setup never hides remote orchestration. Remote provisioning and push remain explicit unless a private provisioner owns target creation and rendered-overlay delivery.
- Dry-run modes perform full local validation and report sorted paths and commands without changing files, executing provisioners, starting subprocesses, or contacting remote systems.
- Removed or renamed source paths are documented as non-convergent without an explicit current mapping.
- Secrets, credentials, private keys, Vault values, and platform secret values remain outside profiles, rendered output, and the controller.
- The implementation remains direct Python using the standard library plus `msup`, the shared logged `run` function, temporary transport staging, rsync, and SSH.
- There are no templates, manifests, state databases, atomic destination writes, backups, custom cryptography, or chezmoi.
- Focused smoke checks cover happy paths and bounded path validation without adding a permanent test module or touching real user, private, remote, or package-manager state.
