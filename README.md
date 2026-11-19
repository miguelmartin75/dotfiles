# dotfiles

`run.py` applies deterministic dotfile overlays with `rsync`. It copies
literal files. It does not manage templates, packages, secrets, or persistent
state.

Run commands from the repository root.

## Prerequisites

- Install [uv](https://docs.astral.sh/uv/).
- Install `rsync` locally.
- For remote commands, install `rsync` on the target and configure SSH access.

Local `setup`, `push`, `pull`, and `clean` detect macOS or the Linux
distribution ID. Use `--os` to override detection. Remote `setup`, `push`, and
`pull` require `--os`.

## Quick start

Set up the local machine, including an optional provisioner:

```bash
./run.py setup
```

Preview and apply the local overlay without provisioning:

```bash
./run.py push --os macos --diff
./run.py push --os macos
```

Push an overlay to an SSH target:

```bash
./run.py push user@host --profile server --os ubuntu
```

Remote targets need only SSH and `rsync`. They do not need this repository,
Python, or uv.

## Configuration layers

Configuration directories mirror paths below the destination home:

```text
common/config/                         # files for every overlay
os/linux/config/                       # Linux-family defaults
os/macos/config/                       # exact OS files
os/ubuntu/config/                      # exact distribution files
os/ubuntu/platforms/server/config/     # selected platform files
os/ubuntu/hosts/my-pod/config/          # selected host files
```

Within each repository, the overlay applies common, Linux-family (for Linux
distributions), exact OS, selected platform, then selected host files. For
`--os linux`, the Linux directory is the exact OS layer and appears once.
Later layers replace whole files at the same home-relative path.

`--profile server --os ubuntu` selects the platform context
`os/ubuntu/platforms/server/`. `--host my-pod` selects
`os/ubuntu/hosts/my-pod/`. Explicit selectors require existing public context
directories, but their `config/` children may be absent for setup-only contexts.
The host selector is independent of an SSH destination.

`private/` is ignored by Git. Work controllers such as `private/nv/run.py`
import the public `dotfiles.py` engine and apply all public layers before all
work layers. Public commands only select public layers.

Only regular files under `config/` are managed. Symlinks, special files, and
file-directory collisions are rejected. Setup executables are outside config.

### Codex agent files

The common profile installs global Codex instructions, language-specific
guidelines, and personal skills under `~/.codex/`. Language guidance is selected
by the installed `~/.codex/AGENTS.md`. Codex hooks are intentionally not
installed.

## Commands

### Push

Copy the effective overlay to the current home or an SSH target:

```bash
./run.py push --os macos
./run.py push user@host --profile server --os ubuntu
./run.py push user@host --profile server --os ubuntu --remote_home /home/user
```

`push` never uses `rsync --delete`, so unrelated destination files remain.
Use `--diff` for a no-write content preview or `--dry_run` to print planned
actions. These options cannot be combined.

### Pull

Copy managed files from a home directory back into config layers:

```bash
./run.py pull --os macos
./run.py pull --path .config/nvim .vimrc --os macos
./run.py pull user@host --path .vimrc --profile server --os ubuntu
```

With no `--path`, `pull` selects the current mapping. Put all path selections
after one `--path` flag. The default `--layer owner` updates the layer that
provides each effective file. New files require an explicit destination:

- `--layer common`: `common/config/`.
- `--layer os`: exact `os/<os>/config/`.
- `--layer platform`: the platform config, requiring `--profile`.
- `--layer host`: the host config, requiring `--host`.

For example, `./run.py pull --os macos --layer os --path .zshrc` updates the
macOS file. Earlier destinations hidden by a later supplying layer are rejected.
The old `profile` destination is removed. `platform` now means the selected
environment; use `os` for exact OS files.

Paths may be home-relative, partial managed paths, or absolute paths below the
home directory. Remote absolute paths require an absolute `--remote_home`.
Traversal, `.git`, `.gitkeep`, and the home root are rejected.

Use `--diff` for a no-write content preview or `--dry_run` to print planned
actions. A remote diff reads the target. A remote dry run does not contact it.

### Clean

Remove files in the current effective mapping from the local home:

```bash
./run.py clean --os macos --dry_run
./run.py clean --os macos
```

`clean` leaves directories and unrelated files in place. Files removed from a
profile are no longer in the mapping, so earlier copies are not removed.

### Render

Write the effective overlay to a directory:

```bash
./run.py render /tmp/dotfiles-overlay --os macos
```

`render` requires `--os`, overwrites managed paths, and preserves unrelated
output files. Use an empty directory when an exact artifact is required.

### Provision and setup

Run a profile provisioner directly:

```bash
./run.py provision macos
./run.py provision ubuntu --profile server -- --extra-argument
```

`provision` does not apply dotfiles. `setup` optionally runs the matching
recipe on the controller, then pushes the overlay:

```bash
./run.py setup --os macos
./run.py setup --target user@host --profile server --os ubuntu
```

Setup selects one executable in this order:

- `os/<os>/hosts/<host>/setup`, when `--host` is selected.
- `os/<os>/platforms/<profile>/setup`, when `--profile` is selected.
- `os/<os>/setup`.

Setup skips an absent recipe; explicit `provision` requires one. An invalid
present candidate or a failed recipe stops the command without fallback.
For macOS, the default recipe is `os/macos/setup`. Arguments after `--` go
only to the selected recipe. Both commands execute it on the controller from
its parent directory, including when dotfiles will be pushed remotely.
`setup`, `push`, `pull`, and `clean` support `--dry_run`.

## Safety and secrets

The controller validates the complete mapping before writing. It rejects
unsafe path traversal, symlinked managed paths, and conflicting file layouts.
Remote targets are raw SSH destinations. `--remote_home`, when supplied, must
be an absolute POSIX path.

Do not put credentials, tokens, private keys, or secret values in profiles or
rendered output. Private Git repositories are not secret stores. Authentication
and secret delivery must be handled outside this controller.

## License

See [LICENSE](LICENSE).
