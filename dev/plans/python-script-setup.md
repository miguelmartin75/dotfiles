# Python Role-Overlay Controller Plan

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
|   |   `-- files/                     # optional audited public shared files
|   `-- local/
|       `-- files/                     # current tilde/ tree, preserving default behavior
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
|           |   |   `-- files/         # private shared work files
|           |   |-- local/
|           |   |   `-- files/         # private local-machine overrides
|           |   |-- aws/
|           |   |   `-- files/
|           |   `-- lepton/
|           |       `-- files/
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

In the split layout, the profile repository root contains `common/`, `local/`, `aws/`, and other role directories. The provisioning repository root contains cluster directories, each with one executable per supported operating system. These produce the same resolved paths as the combined layout.

Do not add private repositories as public submodules, record their URLs in the public repository, auto-clone them, or search arbitrary directories for them.

## Status

- Plan state: 0/5 phases implemented.
- Current phase: Phase 1.
- Next up: establish the public/private layout, profile resolution, and a working default local install.
- During execution, update this section and each Phase status only after that phase's validation passes.
- `refs/run.py` and `refs/mcu` are read-only references and must never be modified.

## Controller Contract

### Profile identifiers and private bundle resolution

Every profile-aware command accepts `--profile`. Its default is always `local`.

Support two identifier forms:

- Public profile: `<role>`, for example `local`.
- Private bundle profile: `<namespace>/<bundle>/<role>`, for example `work/nv/lepton`.

Each component must match `[a-z0-9][a-z0-9_-]*`. Reject absolute paths, backslashes, empty components, `.`, `..`, and the reserved role name `common`. Do not accept any other component count.

Resolve `local` from the public repository. Parse `work/nv/lepton` into `.private/work/nv/` as the bundle container and `lepton` as the role. Parsing returns these deterministic candidate paths without requiring either profile or provisioning content. Each command validates only the content it needs and reports the exact missing path with a short clone/setup explanation.

Layer precedence is lowest to highest:

1. `profiles/common/files/`, when it exists.
2. `profiles/<role>/files/`, when it exists.
3. `.private/<namespace>/<bundle>/profiles/common/files/`, for private profiles, when it exists.
4. `.private/<namespace>/<bundle>/profiles/<role>/files/`, required for a private profile.

Projection commands (`install`, `capture`, `clean`, `render`, `push`, and `pull`) require `profiles/<role>/files/` for a public profile or the private role directory for a private profile. A private profile may reuse public common and public role files. Later layers override the same home-relative file from earlier layers. `provision` does not resolve or require profile files. `setup` requires a profile whose role is `local`, because it installs into the current machine's home; both `local` and a private identifier ending in `/local` are valid.

Keep all path policy in direct constants and profile parsing code next to `repo_root = Path(__file__).resolve().parent`. Do not add a registry, configuration manifest, environment search path, or home-directory scan.

### Effective file map

Every `files/` directory mirrors paths below the target home. Build one sorted effective mapping from home-relative path to its winning source file and owner layer.

- Accept regular files only.
- Reject symlinks and special files rather than following them.
- Reject symlinked directories encountered while walking a layer.
- Reject file-versus-directory collisions across layers, such as one layer containing `.config/tool` as a file while another needs `.config/tool/config`.
- Do not treat repository metadata, provisioning files, or `.gitkeep` placeholders as managed files.

Install, capture ownership, clean, render, push, and pull must consume this same mapping. Directory placement is the ownership model. Do not add a manifest or state database.

The current `tilde/` tree is not assumed to be portable. It contains local-machine and macOS-specific configuration. Migrate it conservatively to `profiles/local/files/` so the default profile preserves current behavior. Leave public `profiles/common/files/` absent or empty until individual files are deliberately audited and promoted. Do not classify the whole current tree as common during this port.

### Commands

Follow the uv PEP 723 and `msup.cli.cli` structure in `refs/run.py:1-10` and `refs/run.py:158-175`, omitting its local `[tool.uv.sources]` block and unrelated project tasks.

Provide these commands:

- `setup`: provision the current machine when an entry point exists, then install its local profile overlay.
- `install`: copy the effective overlay to `Path.home()` by default.
- `capture`: copy explicitly named home-relative files back to their owner or an explicitly selected layer.
- `clean`: remove only paths in the current effective mapping from the destination home.
- `render`: copy the effective overlay to an explicitly supplied output directory for another tool to consume.
- `push`: materialize the effective mapping temporarily and send it to a remote home through rsync/SSH.
- `pull`: fetch only current effective paths from a remote home and copy them back to their existing owner layers.
- `provision`: execute the selected cluster and operating system's provisioning entry point explicitly.

Keep source, destination, private-root, and subprocess boundaries parameterized below the CLI so smoke validation can use temporary directories. Use argument arrays and `subprocess.run(..., check=True)` for external commands. Print commands with `shlex.join`, remove `VIRTUAL_ENV` from child environments as in `refs/run.py:22-31`, and never use `shell=True`.

Add `--dry-run` to `setup`, `install`, `capture`, `clean`, `push`, and `pull`. Dry-run mode performs normal parsing, profile resolution, mapping construction, collision checks, path validation, and command construction, then prints sorted affected paths and any external command without copying, removing, modifying profile files, executing provisioning, or starting a subprocess. It is an action preview, not content diff generation.

Do not add atomic destination writes, backup files, content diff generation, conflict merging, rollback, templates, custom cryptography, or chezmoi. Normal file and subprocess failures may stop a command with a clear error.

### Local setup

Use this interface:

```text
./run.py setup
./run.py setup --profile local --os macos
./run.py setup --profile work/nv/local --os macos -- --provision-argument
```

`setup` is the local golden path and is equivalent to a successful optional `provision` followed by `install` for the same profile. It defaults to profile `local`, accepts only profiles whose role is `local`, targets `Path.home()` at the production CLI boundary, and never accepts a remote target or `--remote-home`.

When `--os` is omitted, detect the current host because `setup` is local-only. Map Darwin to `macos`. On Linux, use the lowercase `ID` from `/etc/os-release`. If detection is unsupported, the file is missing or malformed, or the resulting component is invalid, fail with a request for explicit `--os`. An explicit `--os` follows the profile component grammar and overrides detection. Keep OS detection and the home root injectable for validation.

Resolve provisioning with the same private-first and public-fallback rules as `provision`. Provisioning is optional for `setup`: when no matching entry point exists, print that it was skipped and continue to install. If an entry point exists, run it first and stop without installing if it fails. Forward arguments after `--` only to that entry point. `setup --dry-run` reports whether provisioning would run or be skipped and previews the subsequent install without executing either operation.

Do not extend `setup` to remote targets. Remote provisioning may create a target, discover its SSH address, or embed a rendered overlay during target creation, so it cannot be composed generically with `push` without introducing a target-discovery protocol. Keep remote workflows explicit with `provision` and `push`, or allow a private provisioner to call `render` and deliver the overlay when provisioning and initial projection are inseparable.

### Local install and clean

`install --profile local` is equivalent to omitting `--profile`. Installation creates parent directories and uses `shutil.copy2` to overwrite each effective file. It never deletes unrelated home files.

`clean` unlinks only current effective file paths, tolerates missing files, and leaves directories in place. Because there is no manifest, files removed or renamed in a source profile are not remembered and may remain on a previously installed target. Document this limitation. Do not compensate with a broad home-directory scan or `rsync --delete`.

### Capture and ownership

Use this interface:

```text
./run.py capture PATH... [--profile local] [--layer owner|common|profile]
```

`PATH` values are home-relative files or directories. Reject absolute paths, traversal, special files, final symlinks, and symlinked parents that could escape the supplied home root.

`--layer` defaults to `owner`:

- For an existing effective path, write back to the layer that currently owns the winning file.
- For a new path, require explicit `--layer common` or `--layer profile`.
- For a public profile, `common` means public common and `profile` means the public role.
- For a private profile, `common` means the private bundle's common layer and `profile` means the private bundle's selected role.
- If an explicit target layer would be hidden by a later existing layer, fail and explain which layer would still win.

Resolve directory capture ownership independently per regular file in sorted order. Capture creates parents and uses `shutil.copy2`. It does not sweep the home directory, delete source files, infer new-path ownership, or rewrite another layer.

### Generic render

Use this interface:

```text
./run.py render OUTPUT_DIRECTORY --profile local
./run.py render OUTPUT_DIRECTORY --profile work/nv/lepton
```

`render` creates the output directory when needed, copies only the validated effective mapping with home-relative paths, and overwrites matching files with `shutil.copy2`. It does not clean unrelated output files. Callers that need an exact artifact should provide an empty temporary directory.

`render` is intentionally generic. The public controller has no Lepton archive, base64, pod creation, or `LEPTON_DOTFILES_ARCHIVE` command. Private work provisioning may call `render` into a temporary directory and then own any work-specific tar, base64, and pod-delivery behavior.

### Remote push and pull

Use this transport-only interface:

```text
./run.py push user@host --profile local
./run.py push root@resolved-teleport-host --profile work/nv/lepton
./run.py pull user@host --profile work/nv/ubuntu
```

Target discovery and authentication remain outside the controller. In particular, the private work bundle may retain helpers equivalent to `tssh-url` from `refs/mcu/clusters/laptop/.zshrc-work`, then pass the resulting ordinary SSH destination to `push` or `pull`. Do not hardcode NVIDIA hostnames, Teleport labels, or private infrastructure rules into public Python code.

For `push`:

1. Materialize the validated effective mapping under `tempfile.TemporaryDirectory` using its home-relative paths.
2. Invoke one `rsync -a --no-owner --no-group <staging>/ <target>:<remote-home>/` command.
3. Default the remote home expression to `~/`; allow an explicit absolute POSIX `--remote-home`.
4. Never pass `--delete`.

For `pull`:

1. Generate a temporary sorted `--files-from` list containing only paths in the current effective mapping.
2. Pull those paths from `<target>:<remote-home>/` into a temporary staging directory with rsync.
3. Copy each staged file with `shutil.copy2` to the source layer recorded as its current owner.
4. Do not discover or import unmanaged remote files, change ownership, delete source files, or infer new profile paths.

Push and pull are intentionally one-way operations, not automatic two-way synchronization. Both overwrite their selected destination on the happy path. Pull fails if an expected managed remote file is missing. Temporary staging guarantees that remote operations use the same winning paths and exclusions as install and render. It is transient transport preparation, not atomic destination replacement or persistent state.

The local and remote systems require rsync and working SSH authentication. A new Ubuntu server does not need Python, uv, msup, Git, or either dotfile repository. Install rsync through the server image, manually, or through an explicit profile provisioner before the first push.

Example new Ubuntu flow:

```bash
ssh user@server 'sudo apt-get update && sudo apt-get install -y rsync'
./run.py push user@server --profile work/nv/ubuntu
```

The public plan does not execute this example during validation.

### Provisioning and private repositories

Provisioning is optional and never runs from `install`, `render`, `push`, `pull`, `capture`, or `clean`. Only the explicit `provision` primitive and the local `setup` orchestration command execute a provisioning entry point.

Use this interface:

```text
./run.py provision macos --profile local
./run.py provision ubuntu --profile work/nv/lepton -- --target pod-name
```

The required positional operating system component follows the same `[a-z0-9][a-z0-9_-]*` grammar as a profile component. It names the target operating system, such as `macos` or `ubuntu`; `provision` never infers it from the controller host. Host OS detection is limited to local-only `setup`. For provisioning, the selected profile's role supplies the cluster component. Resolve exactly one `<cluster>/<os>` entry point without resolving profile file layers:

- Public profile: `provision/<cluster>/<os>`.
- Private profile: prefer `.private/<namespace>/<bundle>/provision/<cluster>/<os>`; if absent, fall back to `provision/<cluster>/<os>` when the public entry point exists.

Require the operating system entry point to be a regular, non-symlink executable. Invoke it directly, set its working directory to its cluster directory, remove `VIRTUAL_ENV` from its environment, set non-secret `DOTFILES_REPO_ROOT`, `DOTFILES_PROFILE`, and `DOTFILES_OS` context variables, and forward arguments following `--` unchanged. `provision/local/macos` is a Bash script with `#!/usr/bin/env bash`; other entry points may select Bash, Python, or another interpreter through their shebang. Do not implement a provisioning plugin API or automatically compose multiple entry points.

Provisioning owns package installation, macOS defaults, cluster setup, pod creation, mounts, and target discovery. Profile files own only configuration projected into a home directory. A private provisioner may call `render` and deliver that rendered overlay when target creation and initial projection are inseparable; this is provisioner-specific behavior and does not make the generic `provision` command perform an additional automatic `install` or `push`.

Private Git repositories are not secret stores. Keep credentials, tokens, private keys, `.secrets`, Vault values, and platform secret material outside every profile and rendered output. Authentication remains the responsibility of Git, SSH, Teleport, Vault, environment injection, or the target platform. The controller never reads or writes secret values.

## Phase 1: Layout, resolution, and default install

Status: not started.

Deliver the smallest working local overlay while preserving current local-machine behavior.

Work:

1. Add `/.private/` to `.gitignore` without changing unrelated ignore entries.
2. Add root `run.py` with the uv header, `msup` command mapping, repository constants, profile parsing, deterministic public/private layer resolution, regular-file validation, collision checks, and the sorted effective mapping.
3. Move the current `tilde/` tree unchanged to `profiles/local/files/`. Do not promote any file to public common during the initial port.
4. Implement local `install`, including `--dry-run`, with `Path.home()` at the production CLI boundary and injectable roots for temporary-directory validation.
5. Run focused smoke checks for default `local`, all four precedence layers, parent creation, overwrite behavior, dry-run action reporting without writes, symlink rejection, and file-versus-directory collisions.
6. Update this plan to `1/5 phases implemented` only after Phase 1 validation passes, then set the current phase to Phase 2.

Affected code pointers:

- `.gitignore`
- `run.py` (new)
- `profiles/local/files/` (new location for `tilde/` contents)
- `profiles/common/files/` (optional future shared layer)
- `tilde/` (remove after migration)
- `refs/run.py:1-31` (read-only reference)

Phase success criteria:

- `./run.py install` and `./run.py install --profile local` resolve identically.
- The default local install projects every file previously managed under `tilde/`.
- `install --dry-run` reports the same sorted destinations as a real install without changing them.
- A private identifier resolves only beneath the deterministic `.private/<namespace>/<bundle>/` root.
- Profile precedence and owner reporting are identical regardless of the current working directory.
- Validation never reads from or writes to the real home directory.

## Phase 2: Capture ownership and cleanup

Status: not started.

Add explicit reverse flow without gradually forking common files into profile overrides.

Work:

1. Implement variadic capture paths through the real `msup` CLI boundary, including documented option placement.
2. Implement owner-based capture, explicit common/profile targets, directory recursion, new-path rules, shadowed-layer rejection, and `--dry-run` action reporting.
3. Implement `clean` and its `--dry-run` mode from the same effective mapping used by install.
4. Smoke-check public and private owners, new paths, explicit targets, traversal rejection, clean selection, missing clean targets, and dry-run behavior with temporary roots.
5. Document in CLI help that clean cannot remove paths no longer present in the current source mapping.
6. Update this plan to `2/5 phases implemented` only after Phase 2 validation passes, then set the current phase to Phase 3.

Affected code pointers:

- `run.py`
- `profiles/local/files/`
- temporary public and private common/profile fixtures used only during validation

Phase success criteria:

- Existing paths capture back to their winning owner by default.
- New paths require explicit common or profile ownership.
- Capturing a private profile writes only inside its ignored private bundle.
- Install and clean use the exact same effective mapping.
- Capture cannot escape the supplied home or repository layer roots.
- Capture and clean dry runs perform full validation and report actions without changing home or profile files.

## Phase 3: Generic render and remote push/pull

Status: not started.

Project the same validated mapping to explicit output directories and persistent SSH targets.

Work:

1. Add the logged subprocess helper derived from `refs/run.py:22-31`.
2. Implement generic `render` from the effective mapping.
3. Implement temporary staging and one rsync push with no delete behavior, plus `push --dry-run` path and command reporting without subprocess execution.
4. Implement managed-path-only remote pull with a generated `--files-from` list and owner-layer writes, plus `pull --dry-run` path, owner, and command reporting without subprocess execution.
5. Implement raw SSH target handling and `--remote-home` validation. Keep Teleport and private target discovery outside public Python.
6. Smoke-check push and pull through a temporary fake `rsync` executable, covering exact argument arrays, staging contents, owner writes, missing remote files, subprocess failures, dry-run behavior, and absence of `--delete`.
7. Compare temporary install output, explicit render output, and staged push output for the same fixture.
8. Update this plan to `3/5 phases implemented` only after Phase 3 validation passes, then set the current phase to Phase 4.

Affected code pointers:

- `run.py`
- `refs/mcu/clusters/*/sync.sh` (read-only transport reference)
- `refs/mcu/clusters/laptop/.zshrc-work:61-92` (read-only private work-flow reference)
- `refs/mcu/clusters/lepton/container_setup.sh:24-29` (read-only private work-flow reference)

Phase success criteria:

- Install, render, and push produce the same effective files and winning contents.
- Remote push and pull invoke logged rsync commands with argument arrays and no shell.
- Push never transfers source repository metadata, placeholders, symlinks, or provisioning files; pull never imports unmanaged files.
- The target does not require the controller or either Git repository.
- Pull updates the current owner layer for each managed path.
- Push and pull dry runs validate and report their complete planned actions without contacting a remote target.

## Phase 4: Provisioning and private bundle integration

Status: not started.

Add explicit provisioning and the local setup golden path while keeping remote orchestration explicit.

Work:

1. Implement explicit operating system selection, public/private `<cluster>/<os>` provisioning resolution, private-first fallback, executable validation, working directory, environment handling, and argument forwarding after `--`.
2. Move the six useful macOS `defaults write` operations from `scripts/osx` into the executable Bash script `provision/local/macos`. Use `#!/usr/bin/env bash` and do not carry forward the obsolete Homebrew installer.
3. Implement local-only `setup` as optional provision followed by install. Enforce a `local` profile role, add injectable host OS and home boundaries, map Darwin to `macos`, read Linux `ID` from `/etc/os-release`, accept explicit `--os`, forward provisioner arguments after `--`, and add `--dry-run`.
4. Validate both supported physical layouts with temporary directories: one combined bundle root, and separate profile/provision repository roots beneath the same ignored container. The controller does not inspect `.git/`.
5. Smoke-check operating system validation, public fallback for the same cluster and operating system, private override, executable requirements, context variables, forwarded arguments, subprocess failure propagation, and a provision-only private repository with no profile directory.
6. Smoke-check setup with detected and explicit operating systems, absent optional provisioners, provisioning failure before install, rejected non-local roles, private local profiles, forwarded arguments, dry-run behavior, and successful provision-then-install ordering. Never use the real home or host provisioner during validation.
7. Document the combined and split private repository layouts. Each private repository is cloned once, and both layouts expose identical controller paths.
8. Keep MCU cluster setup, Teleport helpers, Lepton archive creation, pod creation, and secret injection in the private bundle when that repository is migrated. A private Lepton entry point may call the public generic `render` command, then perform its own tar/base64 delivery. Do not copy private infrastructure details into public files.
9. Update this plan to `4/5 phases implemented` only after Phase 4 validation passes, then set the current phase to Phase 5.

Affected code pointers:

- `run.py`
- `provision/local/macos` (new executable Bash script)
- `scripts/osx` (migration source)
- `refs/mcu/clusters/*/setup.sh` (read-only private migration reference)
- `refs/mcu/clusters/lepton/container_setup.sh` (read-only private migration reference)

Phase success criteria:

- One clone at `.private/work/nv/` can supply all private profile roles and provisioning cluster/operating-system pairs.
- Separate clones at `.private/work/nv/profiles/` and `.private/work/nv/provision/` can supply the same paths without cloning either repository twice.
- A provision-only private repository can run `provision` without a corresponding profile directory. Projection commands still require their selected profile directory.
- No projection primitive executes provisioning. Only `setup` composes optional provisioning with local installation.
- The explicit `provision` command resolves one exact `<cluster>/<os>` executable and never infers the target operating system from the controller host.
- Provisioning receives arguments unchanged and failures stop the command.
- `./run.py setup` detects the local operating system, optionally provisions `local`, and installs the default profile in that order.
- Setup skips a missing optional provisioner, never installs after a provisioning failure, rejects non-local roles, and never targets a remote host.
- Setup dry-run previews both stages without executing the provisioner or writing to the home directory.
- Private bundle absence never affects the default public local workflow.

## Phase 5: Documentation and legacy Bash removal

Status: not started.

Make `run.py` the maintained public interface after all replacement behavior is validated.

Work:

1. Rewrite `README.md` with the uv prerequisite, final repository tree, identifier grammar, `setup` as the default local onboarding path, direct install behavior, dry-run behavior, overlay precedence, capture ownership, clean limitations, private clone setup, generic render, push/pull direction, Ubuntu rsync prerequisite, provisioning entry points, and secrets boundary.
2. Document command examples with the exact option ordering accepted by the real CLI.
3. Document migration from `./install` to `./run.py setup`, from `scripts/self_update` to capture, from the broken `./clean` to clean, and from the relevant MCU sync and provision flows to explicit push, pull, provision, and private orchestration. State that Lepton archive behavior remains private.
4. Run the focused temporary-directory smoke checks and CLI help before deleting legacy files.
5. Delete `install`, `clean`, `scripts/mv_dotfiles`, `scripts/self_update`, `scripts/osx`, `scripts/linux`, and `scripts/variables.sh`. Remove `scripts/` if it becomes empty.
6. Search tracked files for stale active references to legacy commands and `tilde/`. Preserve historical migration references in this plan.
7. Keep all of `refs/`, including `refs/mcu`, unchanged.
8. Update plan status to `complete (5/5 phases implemented)` and `Next up: N/A` only after final validation passes.

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
- `README.md` leads with `./run.py setup` for a new local machine and presents install, provision, render, push, and pull as explicit lower-level workflows.
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
! git grep -nE 'scripts/(mv_dotfiles|self_update|osx|linux|variables\.sh)|\./install|\./clean|tilde/' -- . ':(exclude)dev/plans/python-script-setup.md'
```

Use temporary directories and temporary fake executables for focused setup, install, capture, clean, render, push, pull, provisioning, dry-run, and CLI smoke checks. Keep these checks in the execution transcript rather than adding a permanent test module. Do not run those commands against the real home, remote hosts, Teleport, private repositories, or the host package manager during validation.

## Overall Success Criteria

- The plan's end-state structure is implemented, with public profiles in the main repository and each optional private repository cloned once under ignored `.private/` paths.
- `--profile` defaults to `local` for every profile-aware command.
- `./run.py setup` is the local golden path: it detects or accepts the host operating system, optionally provisions the local cluster, and installs the local profile in that order.
- Public `local` preserves every currently managed `tilde/` file unless a later audited move to public common is intentional and validated.
- Private identifiers resolve deterministically as `.private/<namespace>/<bundle>/profiles/<role>/files/` without scanning outside the checkout.
- Public common, public role, private common, and private role precedence is identical for install, clean, render, push, pull, and capture ownership.
- Capture updates existing owner layers by default and requires explicit ownership for new files.
- Provisioning is optional. The explicit primitive resolves `provision/<cluster>/<os>`; local `setup` may invoke it before install. Provisioning may share one private repository with profiles or come from its own single clone without changing resolved paths.
- Remote push sends only the validated effective mapping, and remote pull fetches only its current managed paths.
- Setup never hides remote orchestration. Remote provisioning and push remain explicit unless a private provisioner owns target creation and rendered-overlay delivery.
- Dry-run modes perform full local validation and report sorted paths and commands without changing files, executing provisioners, starting subprocesses, or contacting remote systems.
- Removed or renamed source paths are documented as non-convergent without an explicit current mapping.
- Secrets, credentials, private keys, Vault values, and platform secret values remain outside profiles, rendered output, and the controller.
- The implementation remains direct Python using the standard library plus `msup`, ordinary file copies, temporary transport staging, rsync, and SSH.
- There are no templates, manifests, state databases, atomic destination writes, backups, custom cryptography, or chezmoi.
- Focused smoke checks cover happy paths and bounded path validation without adding a permanent test module or touching real user, private, remote, or package-manager state.
