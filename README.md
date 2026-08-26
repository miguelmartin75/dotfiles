# dotfiles

This repository provides deterministic profile overlays for dotfiles. `run.py`
selects literal files from a public or optional private profile and projects
them with `rsync`. It does not manage secrets, templates, package managers, or
persistent state.

Run every command from the repository root.

## Prerequisites

- Install [uv](https://docs.astral.sh/uv/). The `run.py` shebang uses uv to
  provide its declared script dependency on first use.
- Local projection requires `rsync`.
- Remote projection requires `rsync` locally and on the target, plus working
  SSH authentication. A target does not need Python, uv, this repository, or a
  private profile clone.

The checked-in public local profile is macOS-specific. Local commands detect
macOS or the Linux `ID` in `/etc/os-release`; pass `--os` to override that
detection.

## Start here

On a new machine, use setup locally or give it a raw SSH target:

```bash
./run.py setup
./run.py setup --profile local --os macos
./run.py setup --profile work/nv/local --os macos -- --provision-argument
./run.py setup --target user@host --profile work/nv/aws --os ubuntu
./run.py setup --target user@host --profile work/nv/aws --os ubuntu --remote_home /home/user -- --provision-argument
```

`setup` optionally runs the selected local
`provision/<cluster>/<os>` entry point first, then performs the corresponding
local or remote push. `--target` defaults to the literal value `local`; that
value detects the operating system unless `--os` is supplied, accepts only a
profile whose cluster is `local`, writes to the current home, and rejects
`--remote_home`. Any other target is treated as a raw SSH target, requires
explicit `--os`, accepts any valid profile, and uses the same `--remote_home`
rules as push. If no matching
provisioner exists, setup reports that provisioning was skipped and still
pushes the profile. Provisioners always run on the controller in their existing
working directory and context. Arguments after `--` are forwarded unchanged
only to the provisioner; the target is not forwarded implicitly.

## Repository layout

```text
dotfiles/
|-- .gitignore
|-- README.md
|-- run.py
|-- profiles/
|   |-- common/                       # optional files shared by every host
|   |-- platform/
|   |   `-- linux/                    # optional files shared by Linux profiles
|   `-- local/
|       `-- macos/                 # files mirrored below a home directory
|-- provision/
|   `-- local/
|       `-- macos                  # optional executable macOS provisioner
|-- .private/                      # ignored, optional private bundle root
|   `-- work/
|       `-- nv/
|           |-- .git/              # combined layout only
|           |-- profiles/          # combined or separate profile clone
|           `-- provision/         # combined or separate provision clone
|-- dev/plans/
`-- refs/                          # read-only references; do not modify
```

`profiles/common/` is optional. Add only files deliberately audited to be
shared across operating systems. `profiles/platform/<platform>/` is also
optional and shares files across profiles on one platform. Every profile
directory directly mirrors paths below the destination home, with no `files/`
wrapper.

## Profiles and overlays

A profile is either a public cluster or a private bundle cluster:

```text
<cluster>
<namespace>/<bundle>/<cluster>
```

Each component must match `[a-z0-9][a-z0-9_-]*`. The `common` and `platform`
cluster names are reserved. Examples are `local` and `work/nv/aws`.
Operating-system values use the same component grammar.

For a private profile such as `work/nv/aws`, files resolve only beneath
`.private/work/nv/`. Later layers win for the same home-relative path:

1. `profiles/common/`
2. `profiles/platform/<platform>/`
3. `profiles/<cluster>/<os>/`
4. `.private/<namespace>/<bundle>/profiles/common/`
5. `.private/<namespace>/<bundle>/profiles/platform/<platform>/`
6. `.private/<namespace>/<bundle>/profiles/<cluster>/<os>/`

Projection commands require the selected public or private profile directory.
Private profiles may reuse public common, platform, and cluster files. The
platform is `macos` when `--os macos` is selected. Every other supported
operating-system value is a Linux distribution ID and uses platform `linux`.
Regular files are the only managed content; symlinks, special files, and
conflicting file-versus-directory paths are rejected.

## Commands

### Push

Push projects the effective overlay. Without a target it writes to the current
home directory and never deletes unrelated files.

```bash
./run.py push
./run.py push --profile local --os macos
./run.py push user@host --profile work/nv/aws --os ubuntu
./run.py push user@host --profile work/nv/aws --os ubuntu --remote_home /home/user
./run.py push --profile local --os macos --diff
./run.py push user@host --profile work/nv/aws --os ubuntu --diff
```

With `TARGET`, push stages the validated mapping and makes one `rsync` transfer
to the target. A remote push requires explicit `--os`. `--remote_home` must be
an absolute POSIX path; omitting it uses the target's `~/`. Push never uses
`rsync --delete`.

`--diff` prints a unified content diff without changing the local or remote
destination. Removed lines show the current destination and added lines show
the selected profile content. Remote diff fetches only the managed destination
paths into temporary local staging before comparing them.

### Pull

Pull copies from the current home without a target, or fetches selected paths
from a raw SSH target first. With no `--path`, it pulls every path in the
current mapping.

```bash
./run.py pull --profile local --os macos
./run.py pull --path .config/nvim .vimrc --profile local --os macos --layer owner
./run.py pull --path .config/termite/config --profile local --os ubuntu --layer platform
./run.py pull --path emacs/init.el --profile local --os macos
./run.py pull --path "$HOME/.config/emacs/init.el" --profile local --os macos
./run.py pull user@host --path .config/nvim .vimrc --profile work/nv/aws --os ubuntu --layer profile
./run.py pull user@host --path .config/nvim --profile work/nv/aws --os ubuntu --layer profile --remote_home /home/user
./run.py pull user@host --path /home/user/.config/emacs/init.el --profile work/nv/aws --os ubuntu --remote_home /home/user
./run.py pull --path .vimrc --profile local --os macos --diff
./run.py pull user@host --path .vimrc --profile work/nv/aws --os ubuntu --layer profile --diff
```

Place the optional `TARGET` immediately after `pull`. `--path` is one native
multi-value option: put all selections after that one flag, before the next
option. Repeated `--path` flags are not supported. A home-relative selection
first matches an exact managed file or managed directory. Otherwise it matches
complete path components in managed paths, so `emacs/init.el` matches
`.config/emacs/init.el`, while `mac` does not match `emacs`. A partial match
selects only matching managed files. A no-match selection remains exact, so it
can deliberately add a new file with `--layer common`, `--layer platform`, or
`--layer profile`.

An absolute local path must be below the current home directory and is treated
as its exact home-relative path. An absolute remote path requires an explicit
absolute `--remote_home` and must be below that directory. Absolute selections
never use partial matching. Paths containing traversal, `.git`, or `.gitkeep`
are rejected. Selecting the home root itself is rejected.

`--layer owner` is the default. Existing files return to the layer that owns
the winning effective file. New files require `--layer common`, `--layer
platform`, or `--layer profile`. For private profiles, those explicit layers
point into the private bundle. A pull fails when an explicit lower layer would
be hidden by a later layer.

Remote pull also requires explicit `--os`, transfers only the selected paths,
and applies the same ownership rules locally. The controller does not discover
SSH targets, Teleport routes, or infrastructure-specific connection rules.

`--diff` resolves the same owner or explicit layer as pull, then prints a
unified content diff without changing profile files. Removed lines show the
current repository-layer destination and added lines show the selected home
content. Remote diff uses the same selected-path staging fetch as remote pull.

### Content diffs

Push and pull accept `--diff` as a no-write content preview. They invoke the
system `diff` command and treat both identical files and reported differences
as successful outcomes. A missing action destination is compared as
`/dev/null`. Binary-file reporting is whatever the installed `diff` provides.

Diff and dry-run are separate modes and cannot be combined. Dry-run reports
planned actions and external commands without contacting a remote. Diff reads
actual source and destination contents, so a remote diff contacts its target
and creates only transient local staging data.

### Clean

Clean removes only files in the current effective mapping from the current
home, tolerates missing files, and leaves directories in place.

```bash
./run.py clean --profile local --os macos
./run.py clean --profile local --os macos --dry_run
```

There is no manifest or state database. A source file that was removed or
renamed is no longer in the current mapping, so a prior copy can remain in the
home directory after clean. The command does not scan broadly or compensate
with `rsync --delete`.

### Render

Render writes the effective overlay to an explicit directory for another tool
to consume. It requires `--os`, creates the output directory, overwrites
matching managed files, and preserves unrelated output files.

```bash
./run.py render /tmp/dotfiles-overlay --profile local --os macos
./run.py render /tmp/aws-overlay --profile work/nv/aws --os ubuntu
```

Use an empty output directory when an exact artifact is needed. Render is
generic: Lepton archive creation, encoding, pod creation, and delivery remain
private-bundle behavior.

### Provision

Provisioning is explicit. It resolves one executable entry point for the
selected cluster and operating system. For private profiles, a private entry
point takes precedence and the public entry point is the fallback.

```bash
./run.py provision macos --profile local
./run.py provision ubuntu --profile work/nv/lepton -- --target pod-name
```

`provision` never infers the operating system and never projects profiles.
Provisioners own package installation, target creation, operating-system
defaults, mounts, and target discovery. `setup` is the only command that
combines optional provisioning with a local or remote push.

## Dry runs

`setup`, `push`, `pull`, and `clean` accept `--dry_run`. A dry run performs
normal parsing and local validation, then prints sorted affected paths and
external commands without copying, removing, changing profile files, executing
a provisioner, or contacting a remote target.

```bash
./run.py setup --profile local --os macos --dry_run -- --provision-argument
./run.py setup --target user@host --profile work/nv/aws --os ubuntu --dry_run -- --provision-argument
./run.py push user@host --profile work/nv/aws --os ubuntu --dry_run
./run.py pull user@host --path .config/nvim .vimrc --profile work/nv/aws --os ubuntu --layer profile --dry_run
./run.py clean --profile local --os macos --dry_run
```

Remote dry runs cannot verify remote file contents or directory expansion
without contacting the target. Setup dry runs preview both provisioning and
projection without creating staging files, executing a provisioner, starting a
subprocess, writing locally, or contacting the target. `render` and `provision`
are explicit actions and do not have a dry-run mode.

## Private bundles

`.private/` is ignored. Clone private repositories manually and do not add them
as public submodules, record their URLs here, or expect the controller to clone
or discover them.

When one private repository contains both profile and provisioning trees, clone
it once at the bundle container:

```bash
git clone <private-bundle-url> .private/work/nv
```

When profiles and provisioners are separate repositories, clone each once at
its resolved directory:

```bash
mkdir -p .private/work/nv
git clone <private-profile-url> .private/work/nv/profiles
git clone <private-provision-url> .private/work/nv/provision
```

Both layouts expose the same controller paths. In the split layout, the profile
repository root contains `common/`, `platform/<platform>/`, and cluster
directories such as `aws/`, while the provisioning repository root contains
matching `<cluster>/<os>` executables.

## Remote Ubuntu targets

Install `rsync` on a new Ubuntu target before the first remote push. The
controller itself is not installed there:

```bash
ssh user@server 'sudo apt-get update && sudo apt-get install -y rsync'
./run.py push user@server --profile work/nv/aws --os ubuntu
```

This remains an explicit target-preparation step. It can also be owned by a
private provisioner or server image.

## Secrets

Profiles and rendered output must not contain credentials, tokens, private
keys, `.secrets`, Vault values, or platform secret values. Private Git
repositories are not secret stores. Use Git, SSH, Teleport, Vault, environment
injection, or the target platform for authentication and secret delivery; the
controller never reads or writes secret values.

## Migration

| Legacy workflow | Replacement |
| --- | --- |
| `./install` | `./run.py setup`, or `./run.py push --profile local --os macos` when provisioning is separate. |
| `scripts/self_update` | `./run.py pull --profile local --os macos` to update the owning profile layer from the local home. |
| Broken `./clean` script | `./run.py clean --profile local --os macos`. |
| MCU sync flows | Explicit remote `push` and `pull` with a raw SSH target and explicit `--os`. |
| MCU provisioning flows | Remote `setup` when local provisioning plus generic push is sufficient, or explicit `provision` and private-bundle orchestration. |
| Lepton archive and pod workflows | Keep private. A private provisioner may render an overlay and perform its own archive and delivery steps. |

## License

See [LICENSE](LICENSE).
