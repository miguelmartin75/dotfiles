#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.12"
# dependencies = ["msup"]
# ///

import os
import platform
import re
import shlex
import subprocess
import sys
from collections.abc import Callable, Sequence
from contextlib import AbstractContextManager
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from tempfile import TemporaryDirectory
from typing import Annotated

from msup.cli import CliArg, cli

REPO_ROOT = Path(__file__).resolve().parent
PROFILES_DIR_NAME = "profiles"
PRIVATE_DIR_NAME = ".private"
COMMON_CLUSTER_NAME = "common"
LOCAL_CLUSTER_NAME = "local"
GIT_DIR_NAME = ".git"
PLACEHOLDER_FILE_NAME = ".gitkeep"
COMPONENT_PATTERN = re.compile(r"[a-z0-9][a-z0-9_-]*")
STAGING_PLACEHOLDER = Path("<staging>")


@dataclass(frozen=True)
class Profile:
    identifier: str
    namespace: str | None
    bundle: str | None
    cluster: str


@dataclass(frozen=True)
class ProfileLayer:
    name: str
    root: Path


@dataclass(frozen=True)
class ManagedFile:
    relative_path: Path
    source_path: Path
    owner: ProfileLayer


HostOsDetector = Callable[[], tuple[str | None, list[str]]]
Runner = Callable[[Sequence[str], bool, Path], None]
ProvisionRunner = Callable[[Sequence[str], bool, Path, dict[str, str]], None]
StagingDirectoryCreator = Callable[[], AbstractContextManager[str]]


def find_invalid_ancestor(
    root: Path, relative_directory: Path
) -> tuple[Path, bool] | None:
    """Find the first symlinked or non-directory ancestor below a trusted root."""
    ancestor_path = root
    result: tuple[Path, bool] | None = None
    for component in relative_directory.parts:
        ancestor_path /= component
        if ancestor_path.is_symlink():
            result = ancestor_path, True
            break
        elif ancestor_path.exists() and not ancestor_path.is_dir():
            result = ancestor_path, False
            break
        elif not ancestor_path.exists():
            break
    return result


def parse_profile(identifier: str) -> tuple[Profile | None, list[str]]:
    errors: list[str] = []
    parts = identifier.split("/")
    if len(parts) not in (1, 3):
        errors.append(
            "profile must be a public <cluster> or private "
            "<namespace>/<bundle>/<cluster> identifier"
        )
    else:
        for component in parts:
            if COMPONENT_PATTERN.fullmatch(component) is None:
                errors.append(f"invalid profile component: {component!r}")
        if parts[-1] == COMMON_CLUSTER_NAME:
            errors.append(
                f"{COMMON_CLUSTER_NAME!r} is reserved and cannot be a profile cluster"
            )

    result: Profile | None = None
    if not errors:
        if len(parts) == 1:
            result = Profile(identifier, None, None, parts[0])
        else:
            result = Profile(identifier, parts[0], parts[1], parts[2])
    return result, errors


def detect_os(
    system_name: str | None = None,
    os_release_path: Path = Path("/etc/os-release"),
) -> tuple[str | None, list[str]]:
    errors: list[str] = []
    system = platform.system() if system_name is None else system_name
    result: str | None = None
    if system == "Darwin":
        result = "macos"
    elif system == "Linux":
        try:
            os_release = os_release_path.read_text()
        except OSError:
            errors.append(f"cannot read {os_release_path}; pass --os explicitly")
        else:
            for line in os_release.splitlines():
                if line.startswith("ID="):
                    value = line.removeprefix("ID=").strip()
                    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
                        value = value[1:-1]
                    result = value.lower()
                    break
            if result is None:
                errors.append(
                    f"{os_release_path} has no ID entry; pass --os explicitly"
                )
    else:
        errors.append(
            f"unsupported host operating system {system!r}; pass --os explicitly"
        )

    if result is not None and COMPONENT_PATTERN.fullmatch(result) is None:
        errors.append(
            f"detected invalid operating system {result!r}; pass --os explicitly"
        )
        result = None
    return result, errors


def resolve_os(
    requested_os: str | None,
    detect_host_os: HostOsDetector = detect_os,
) -> tuple[str | None, list[str]]:
    errors: list[str] = []
    result = requested_os
    if result is None:
        result, errors = detect_host_os()
    elif COMPONENT_PATTERN.fullmatch(result) is None:
        errors.append(f"invalid operating system component: {result!r}")
        result = None
    return result, errors


def resolve_profile_layers(
    profile: Profile,
    operating_system: str,
    repo_root: Path = REPO_ROOT,
) -> tuple[list[ProfileLayer], list[str]]:
    public_profiles_root = repo_root / PROFILES_DIR_NAME
    candidates: list[tuple[str, Path, bool]] = [
        ("public common", public_profiles_root / COMMON_CLUSTER_NAME, False),
        (
            "public profile",
            public_profiles_root / profile.cluster / operating_system,
            profile.namespace is None,
        ),
    ]
    if profile.namespace is not None and profile.bundle is not None:
        private_profiles_root = (
            repo_root
            / PRIVATE_DIR_NAME
            / profile.namespace
            / profile.bundle
            / PROFILES_DIR_NAME
        )
        candidates.extend(
            [
                ("private common", private_profiles_root / COMMON_CLUSTER_NAME, False),
                (
                    "private profile",
                    private_profiles_root / profile.cluster / operating_system,
                    True,
                ),
            ]
        )

    errors: list[str] = []
    layers: list[ProfileLayer] = []
    for name, root, required in candidates:
        invalid_ancestor: tuple[Path, bool] | None = None
        if repo_root.is_symlink():
            errors.append(
                f"{name} layer contains a symlinked path component: {repo_root}"
            )
        else:
            invalid_ancestor = find_invalid_ancestor(
                repo_root, root.relative_to(repo_root)
            )
        if invalid_ancestor is not None:
            ancestor_path, is_symlink = invalid_ancestor
            if is_symlink:
                errors.append(
                    f"{name} layer contains a symlinked path component: {ancestor_path}"
                )
            else:
                errors.append(
                    f"{name} layer parent must be a directory: {ancestor_path}"
                )
        if repo_root.is_symlink() or invalid_ancestor is not None:
            continue
        if root.is_dir():
            layers.append(ProfileLayer(name, root))
        elif required:
            if profile.namespace is None:
                errors.append(f"missing required {name} layer: {root}")
            else:
                errors.append(
                    f"missing required {name} layer: {root}; clone or set up the private profile bundle"
                )
        elif root.exists():
            errors.append(f"{name} layer must be a directory: {root}")
    return layers, errors


def build_effective_mapping(
    layers: list[ProfileLayer],
) -> tuple[list[ManagedFile], list[str]]:
    mapping: dict[Path, ManagedFile] = {}
    errors: list[str] = []
    for layer in layers:
        for directory, dirnames, filenames in os.walk(
            layer.root, topdown=True, followlinks=False
        ):
            directory_path = Path(directory)
            next_dirnames: list[str] = []
            for dirname in sorted(dirnames):
                candidate_path = directory_path / dirname
                if candidate_path.is_symlink():
                    errors.append(
                        f"symlinked directory in {layer.name} layer: {candidate_path}"
                    )
                elif dirname == GIT_DIR_NAME:
                    continue
                else:
                    next_dirnames.append(dirname)
            dirnames[:] = next_dirnames

            for filename in sorted(filenames):
                source_path = Path(directory) / filename
                if source_path.is_symlink():
                    errors.append(
                        f"symlinked file in {layer.name} layer: {source_path}"
                    )
                elif filename in {GIT_DIR_NAME, PLACEHOLDER_FILE_NAME}:
                    continue
                elif not source_path.is_file():
                    errors.append(
                        f"non-regular file in {layer.name} layer: {source_path}"
                    )
                else:
                    relative_path = source_path.relative_to(layer.root)
                    collision_paths: list[Path] = []
                    for existing_path in mapping:
                        if (
                            relative_path in existing_path.parents
                            or existing_path in relative_path.parents
                        ):
                            collision_paths.append(existing_path)
                    if collision_paths:
                        for existing_path in collision_paths:
                            errors.append(
                                "file-directory collision between "
                                f"{source_path} and {mapping[existing_path].source_path}"
                            )
                    else:
                        mapping[relative_path] = ManagedFile(
                            relative_path, source_path, layer
                        )

    result = sorted(mapping.values(), key=lambda file: file.relative_path.as_posix())
    return result, errors


def resolve_mapping(
    identifier: str,
    requested_os: str | None,
    repo_root: Path = REPO_ROOT,
    detect_host_os: HostOsDetector = detect_os,
    require_explicit_os: bool = False,
) -> tuple[list[ManagedFile], list[str]]:
    profile, errors = parse_profile(identifier)
    operating_system: str | None = None
    if require_explicit_os and requested_os is None:
        errors.append("--os is required for render and remote targets")
    else:
        operating_system, os_errors = resolve_os(requested_os, detect_host_os)
        errors.extend(os_errors)
    result: list[ManagedFile] = []
    if profile is not None and operating_system is not None:
        layers, layer_errors = resolve_profile_layers(
            profile, operating_system, repo_root
        )
        errors.extend(layer_errors)
        if not layer_errors:
            result, mapping_errors = build_effective_mapping(layers)
            errors.extend(mapping_errors)
    return result, errors


def run(
    command: Sequence[str],
    dry_run: bool,
    cwd: Path = REPO_ROOT,
    context: dict[str, str] | None = None,
) -> None:
    print("$ " + shlex.join(command), flush=True)
    if not dry_run:
        environment = os.environ.copy()
        environment.pop("VIRTUAL_ENV", None)
        if context is not None:
            environment.update(context)
        result = subprocess.run(command, cwd=cwd, env=environment, check=False)
        if result.returncode:
            sys.exit(result.returncode)


def resolve_provisioner(
    profile: Profile,
    operating_system: str,
    repo_root: Path = REPO_ROOT,
) -> tuple[Path | None, Path, list[str]]:
    public_entry_point = repo_root / "provision" / profile.cluster / operating_system
    expected_entry_point = public_entry_point
    candidates: list[Path] = [public_entry_point]
    if profile.namespace is not None and profile.bundle is not None:
        private_entry_point = (
            repo_root
            / PRIVATE_DIR_NAME
            / profile.namespace
            / profile.bundle
            / "provision"
            / profile.cluster
            / operating_system
        )
        expected_entry_point = private_entry_point
        candidates.insert(0, private_entry_point)

    result: Path | None = None
    errors: list[str] = []
    for entry_point in candidates:
        if repo_root.is_symlink():
            errors.append(
                f"provision entry point contains a symlinked path component: {repo_root}"
            )
            break
        invalid_ancestor = find_invalid_ancestor(
            repo_root, entry_point.relative_to(repo_root).parent
        )
        if invalid_ancestor is not None:
            ancestor_path, is_symlink = invalid_ancestor
            if is_symlink:
                errors.append(
                    "provision entry point contains a symlinked path component: "
                    f"{ancestor_path}"
                )
            else:
                errors.append(
                    f"provision entry point parent must be a directory: {ancestor_path}"
                )
            break
        if entry_point.is_symlink():
            errors.append(f"provision entry point must not be a symlink: {entry_point}")
            break
        if entry_point.exists():
            if entry_point.is_file() and os.access(entry_point, os.X_OK):
                result = entry_point
            else:
                errors.append(
                    "provision entry point must be a regular executable file: "
                    f"{entry_point}"
                )
            break
    return result, expected_entry_point, errors


def run_provisioner(
    entry_point: Path,
    profile: Profile,
    operating_system: str,
    provision_args: list[str],
    dry_run: bool = False,
    repo_root: Path = REPO_ROOT,
    runner: ProvisionRunner = run,
) -> None:
    context = {
        "DOTFILES_REPO_ROOT": str(repo_root),
        "DOTFILES_PROFILE": profile.identifier,
        "DOTFILES_OS": operating_system,
    }
    runner(
        [str(entry_point), *provision_args],
        dry_run,
        entry_point.parent,
        context,
    )


def project_mapping(
    mapping: list[ManagedFile],
    destination_root: Path,
    dry_run: bool,
    action: str,
    runner: Runner = run,
    cwd: Path = REPO_ROOT,
    create_root: bool = False,
) -> list[str]:
    result: list[str] = []
    if destination_root.is_symlink():
        result.append(f"destination root must not be a symlink: {destination_root}")
    elif destination_root.exists() and not destination_root.is_dir():
        result.append(f"destination root must be a directory: {destination_root}")

    for managed_file in mapping:
        destination = destination_root / managed_file.relative_path
        invalid_ancestor = find_invalid_ancestor(
            destination_root, managed_file.relative_path.parent
        )
        if invalid_ancestor is not None:
            ancestor_path, is_symlink = invalid_ancestor
            if is_symlink:
                result.append(
                    f"destination parent must not be a symlink: {ancestor_path}"
                )
            else:
                result.append(
                    f"destination parent must be a directory: {ancestor_path}"
                )
        elif destination.is_symlink():
            result.append(f"destination must not be a symlink: {destination}")
        elif destination.is_dir():
            result.append(f"destination must not be a directory: {destination}")

    if not result:
        if create_root and not dry_run:
            destination_root.mkdir(parents=True, exist_ok=True)
        for managed_file in mapping:
            destination = destination_root / managed_file.relative_path
            print(f"{action}: {managed_file.relative_path.as_posix()}")
            command = [
                "rsync",
                "-a",
                "--checksum",
                "--no-owner",
                "--no-group",
                str(managed_file.source_path),
                str(destination),
            ]
            if not dry_run:
                destination.parent.mkdir(parents=True, exist_ok=True)
            runner(command, dry_run, cwd)
    return result


def setup_local(
    identifier: str,
    requested_os: str | None,
    provision_args: list[str],
    home_root: Path,
    repo_root: Path = REPO_ROOT,
    detect_host_os: HostOsDetector = detect_os,
    dry_run: bool = False,
    runner: Runner = run,
    provision_runner: ProvisionRunner = run,
) -> list[str]:
    profile, errors = parse_profile(identifier)
    operating_system, os_errors = resolve_os(requested_os, detect_host_os)
    errors.extend(os_errors)
    if profile is not None and profile.cluster != LOCAL_CLUSTER_NAME:
        errors.append("setup requires a profile whose cluster is 'local'")

    mapping: list[ManagedFile] = []
    entry_point: Path | None = None
    expected_entry_point: Path | None = None
    if (
        profile is not None
        and profile.cluster == LOCAL_CLUSTER_NAME
        and operating_system is not None
    ):
        layers, layer_errors = resolve_profile_layers(
            profile, operating_system, repo_root
        )
        errors.extend(layer_errors)
        if not layer_errors:
            mapping, mapping_errors = build_effective_mapping(layers)
            errors.extend(mapping_errors)
        entry_point, expected_entry_point, provision_errors = resolve_provisioner(
            profile, operating_system, repo_root
        )
        errors.extend(provision_errors)

    if not errors and profile is not None and operating_system is not None:
        if entry_point is None:
            print(f"setup: provisioning skipped: {expected_entry_point}")
        else:
            print(f"setup: provisioning {'would run' if dry_run else 'running'}")
            run_provisioner(
                entry_point,
                profile,
                operating_system,
                provision_args,
                dry_run,
                repo_root,
                provision_runner,
            )
        errors.extend(
            project_mapping(mapping, home_root, dry_run, "push", runner, repo_root)
        )
    errors.sort()
    return errors


def resolve_remote_home(
    target: str | None, remote_home: str | None
) -> tuple[str | None, list[str]]:
    errors: list[str] = []
    result: str | None = None
    if target is None:
        if remote_home is not None:
            errors.append("--remote_home requires a positional TARGET")
    else:
        result = "~/"
        if remote_home is not None:
            if (
                "\\" in remote_home
                or not PurePosixPath(remote_home).is_absolute()
                or any(part in {".", ".."} for part in remote_home.split("/"))
            ):
                errors.append("--remote_home must be an absolute POSIX path")
                result = None
            else:
                result = remote_home.rstrip("/") + "/"
    return result, errors


def push_remote(
    mapping: list[ManagedFile],
    target: str,
    remote_home: str,
    dry_run: bool,
    runner: Runner = run,
    cwd: Path = REPO_ROOT,
    create_staging_directory: StagingDirectoryCreator = TemporaryDirectory,
) -> list[str]:
    result: list[str] = []
    if dry_run:
        for managed_file in mapping:
            destination = STAGING_PLACEHOLDER / managed_file.relative_path
            print(f"push: {managed_file.relative_path.as_posix()}")
            runner(
                [
                    "rsync",
                    "-a",
                    "--checksum",
                    "--no-owner",
                    "--no-group",
                    str(managed_file.source_path),
                    str(destination),
                ],
                True,
                cwd,
            )
        runner(
            [
                "rsync",
                "-a",
                "--no-owner",
                "--no-group",
                f"{STAGING_PLACEHOLDER}/",
                f"{target}:{remote_home}",
            ],
            True,
            cwd,
        )
    else:
        with create_staging_directory() as staging_directory:
            staging_root = Path(staging_directory)
            result = project_mapping(mapping, staging_root, False, "push", runner, cwd)
            if not result:
                runner(
                    [
                        "rsync",
                        "-a",
                        "--no-owner",
                        "--no-group",
                        f"{staging_root}/",
                        f"{target}:{remote_home}",
                    ],
                    False,
                    cwd,
                )
    return result


def push(
    target: Annotated[
        str | None, CliArg(pos=True, opt=False, help="optional raw SSH target")
    ] = None,
    profile: Annotated[
        str, CliArg(help="public or private profile identifier")
    ] = LOCAL_CLUSTER_NAME,
    os: Annotated[str | None, CliArg(help="operating system override")] = None,
    remote_home: Annotated[
        str | None, CliArg(help="remote home, as an absolute POSIX path")
    ] = None,
    dry_run: Annotated[
        bool, CliArg(help="report copies without writing files")
    ] = False,
) -> None:
    mapping, errors = resolve_mapping(
        profile, os, require_explicit_os=target is not None
    )
    effective_remote_home, remote_home_errors = resolve_remote_home(target, remote_home)
    errors.extend(remote_home_errors)
    if errors:
        for error in sorted(errors):
            print(f"error: {error}", file=sys.stderr)
        sys.exit(1)
    if target is None:
        errors = project_mapping(mapping, Path.home(), dry_run, "push")
    else:
        errors = push_remote(mapping, target, effective_remote_home, dry_run)
    if errors:
        for error in sorted(errors):
            print(f"error: {error}", file=sys.stderr)
        sys.exit(1)


def collect_selected_paths(
    mapping: list[ManagedFile], paths: list[str]
) -> tuple[set[Path], list[str]]:
    result: set[Path] = set()
    errors: list[str] = []
    if paths:
        for path_text in paths:
            relative_path = Path(path_text)
            if (
                not path_text
                or relative_path.is_absolute()
                or any(part in {".", ".."} for part in path_text.split("/"))
            ):
                errors.append(
                    f"path must be home-relative without traversal: {path_text!r}"
                )
            elif GIT_DIR_NAME in relative_path.parts:
                errors.append(
                    f"selected path cannot include {GIT_DIR_NAME}: {relative_path}"
                )
            elif relative_path.name == PLACEHOLDER_FILE_NAME:
                errors.append(
                    "selected path cannot include "
                    f"{PLACEHOLDER_FILE_NAME}: {relative_path}"
                )
            else:
                result.add(relative_path)
    else:
        result.update(managed_file.relative_path for managed_file in mapping)
    return result, errors


def prepare_pull_targets(
    mapping: list[ManagedFile],
    source_paths: dict[Path, Path],
    layer: str,
    common_layer: ProfileLayer,
    profile_layer: ProfileLayer,
    repo_root: Path,
) -> tuple[list[ManagedFile], list[str]]:
    mapping_by_path = {
        managed_file.relative_path: managed_file for managed_file in mapping
    }
    result: list[str] = []
    targets: list[ManagedFile] = []
    if layer not in {"owner", "common", "profile"}:
        result.append("layer must be one of: owner, common, profile")

    for relative_path, source_path in sorted(
        source_paths.items(), key=lambda item: item[0].as_posix()
    ):
        managed_file = mapping_by_path.get(relative_path)
        owner = managed_file.owner if managed_file is not None else None
        if layer == "common":
            owner = common_layer
        elif layer == "profile":
            owner = profile_layer

        if managed_file is None:
            collision_paths = [
                existing_path
                for existing_path in mapping_by_path
                if (
                    relative_path in existing_path.parents
                    or existing_path in relative_path.parents
                )
            ]
            for existing_path in sorted(
                collision_paths, key=lambda path: path.as_posix()
            ):
                result.append(
                    f"new path {relative_path} has a file-directory collision with "
                    f"managed path {existing_path}"
                )
            if layer == "owner":
                result.append(
                    f"new path requires --layer common or --layer profile: {relative_path}"
                )
            elif not collision_paths and owner is not None:
                targets.append(ManagedFile(relative_path, source_path, owner))
        elif (
            layer != "owner"
            and owner is not None
            and owner != managed_file.owner
            and {
                "public common": 0,
                "public profile": 1,
                "private common": 2,
                "private profile": 3,
            }.get(owner.name, 0)
            < {
                "public common": 0,
                "public profile": 1,
                "private common": 2,
                "private profile": 3,
            }.get(managed_file.owner.name, 0)
        ):
            result.append(
                f"explicit {layer} layer for {relative_path} would be hidden by "
                f"{managed_file.owner.name} layer"
            )
        elif owner is not None:
            targets.append(ManagedFile(relative_path, source_path, owner))

    validated_roots: set[Path] = set()
    invalid_roots: set[Path] = set()
    for managed_file in targets:
        if managed_file.owner.root not in validated_roots:
            validated_roots.add(managed_file.owner.root)
            if not managed_file.owner.root.is_relative_to(repo_root):
                result.append(
                    "destination layer must be inside repository root: "
                    f"{managed_file.owner.root}"
                )
                invalid_roots.add(managed_file.owner.root)
            elif repo_root.is_symlink():
                result.append(
                    "destination layer contains a symlinked path component: "
                    f"{repo_root}"
                )
                invalid_roots.add(managed_file.owner.root)
            else:
                invalid_ancestor = find_invalid_ancestor(
                    repo_root, managed_file.owner.root.relative_to(repo_root)
                )
                if invalid_ancestor is not None:
                    ancestor_path, is_symlink = invalid_ancestor
                    if is_symlink:
                        result.append(
                            "destination layer contains a symlinked path component: "
                            f"{ancestor_path}"
                        )
                    else:
                        result.append(
                            f"destination layer parent must be a directory: {ancestor_path}"
                        )
                    invalid_roots.add(managed_file.owner.root)

        if managed_file.owner.root in invalid_roots:
            continue
        destination = managed_file.owner.root / managed_file.relative_path
        invalid_ancestor = find_invalid_ancestor(
            managed_file.owner.root, managed_file.relative_path.parent
        )
        if invalid_ancestor is not None:
            ancestor_path, is_symlink = invalid_ancestor
            if is_symlink:
                result.append(
                    f"destination parent must not be a symlink: {ancestor_path}"
                )
            else:
                result.append(
                    f"destination parent must be a directory: {ancestor_path}"
                )
        elif destination.is_symlink():
            result.append(f"destination must not be a symlink: {destination}")
        elif destination.exists() and not destination.is_file():
            result.append(f"destination must be a regular file: {destination}")

    result.sort()
    return targets, result


def pull_local(
    mapping: list[ManagedFile],
    paths: list[str],
    layer: str,
    common_layer: ProfileLayer,
    profile_layer: ProfileLayer,
    home_root: Path,
    repo_root: Path = REPO_ROOT,
    dry_run: bool = False,
    runner: Runner = run,
    cwd: Path = REPO_ROOT,
) -> list[str]:
    result: list[str] = []
    source_paths: dict[Path, Path] = {}
    has_explicit_paths = bool(paths)

    can_read_home = True
    if home_root.is_symlink():
        result.append(f"home root must not be a symlink: {home_root}")
        can_read_home = False
    elif home_root.exists() and not home_root.is_dir():
        result.append(f"home root must be a directory: {home_root}")
        can_read_home = False

    selected_paths, selection_errors = collect_selected_paths(mapping, paths)
    result.extend(selection_errors)

    for relative_path in sorted(selected_paths, key=lambda path: path.as_posix()):
        if not can_read_home:
            continue
        source_path = home_root / relative_path
        invalid_ancestor = find_invalid_ancestor(home_root, relative_path.parent)
        if invalid_ancestor is not None:
            ancestor_path, is_symlink = invalid_ancestor
            if is_symlink:
                result.append(f"home parent must not be a symlink: {ancestor_path}")
            else:
                result.append(f"home parent must be a directory: {ancestor_path}")
            continue
        if source_path.is_symlink():
            result.append(f"selected home path must not be a symlink: {source_path}")
        elif source_path.is_file():
            source_paths[relative_path] = source_path
        elif source_path.is_dir() and not has_explicit_paths:
            result.append(f"managed home path must be a regular file: {source_path}")
        elif source_path.is_dir():
            for directory, dirnames, filenames in os.walk(
                source_path, topdown=True, followlinks=False
            ):
                directory_path = Path(directory)
                next_dirnames: list[str] = []
                for dirname in sorted(dirnames):
                    candidate_path = directory_path / dirname
                    candidate_relative_path = candidate_path.relative_to(home_root)
                    if GIT_DIR_NAME in candidate_relative_path.parts:
                        result.append(
                            "selected path cannot include "
                            f"{GIT_DIR_NAME}: {candidate_relative_path}"
                        )
                    elif candidate_relative_path.name == PLACEHOLDER_FILE_NAME:
                        result.append(
                            "selected path cannot include "
                            f"{PLACEHOLDER_FILE_NAME}: {candidate_relative_path}"
                        )
                    elif candidate_path.is_symlink():
                        result.append(
                            f"symlinked directory in selected home path: {candidate_path}"
                        )
                    else:
                        next_dirnames.append(dirname)
                dirnames[:] = next_dirnames

                for filename in sorted(filenames):
                    candidate_path = directory_path / filename
                    candidate_relative_path = candidate_path.relative_to(home_root)
                    if GIT_DIR_NAME in candidate_relative_path.parts:
                        result.append(
                            "selected path cannot include "
                            f"{GIT_DIR_NAME}: {candidate_relative_path}"
                        )
                    elif candidate_relative_path.name == PLACEHOLDER_FILE_NAME:
                        result.append(
                            "selected path cannot include "
                            f"{PLACEHOLDER_FILE_NAME}: {candidate_relative_path}"
                        )
                    elif candidate_path.is_symlink():
                        result.append(
                            f"symlinked file in selected home path: {candidate_path}"
                        )
                    elif candidate_path.is_file():
                        source_paths[candidate_relative_path] = candidate_path
                    else:
                        result.append(
                            f"non-regular file in selected home path: {candidate_path}"
                        )
        elif source_path.exists():
            result.append(f"selected home path must be a regular file: {source_path}")
        elif has_explicit_paths:
            result.append(f"selected home path does not exist: {source_path}")
        else:
            result.append(f"managed home path does not exist: {source_path}")

    targets, target_errors = prepare_pull_targets(
        mapping, source_paths, layer, common_layer, profile_layer, repo_root
    )
    result.extend(target_errors)

    if not result:
        for managed_file in targets:
            destination = managed_file.owner.root / managed_file.relative_path
            print(
                f"pull: {managed_file.relative_path.as_posix()} -> {managed_file.owner.name}"
            )
            if not dry_run:
                destination.parent.mkdir(parents=True, exist_ok=True)
            runner(
                [
                    "rsync",
                    "-a",
                    "--checksum",
                    "--no-owner",
                    "--no-group",
                    str(managed_file.source_path),
                    str(destination),
                ],
                dry_run,
                cwd,
            )
    result.sort()
    return result


def clean_local(
    mapping: list[ManagedFile],
    home_root: Path,
    dry_run: bool,
) -> list[str]:
    result: list[str] = []
    targets: list[Path] = []
    can_clean_home = True
    if home_root.is_symlink():
        result.append(f"home root must not be a symlink: {home_root}")
        can_clean_home = False
    elif home_root.exists() and not home_root.is_dir():
        result.append(f"home root must be a directory: {home_root}")
        can_clean_home = False

    for managed_file in mapping:
        if not can_clean_home:
            continue
        destination = home_root / managed_file.relative_path
        invalid_ancestor = find_invalid_ancestor(
            home_root, managed_file.relative_path.parent
        )
        if invalid_ancestor is not None:
            ancestor_path, is_symlink = invalid_ancestor
            if is_symlink:
                result.append(f"home parent must not be a symlink: {ancestor_path}")
            else:
                result.append(f"home parent must be a directory: {ancestor_path}")
            continue
        if destination.is_symlink():
            result.append(f"clean target must not be a symlink: {destination}")
        elif not destination.exists():
            continue
        elif destination.is_file():
            targets.append(destination)
        elif not destination.is_dir():
            result.append(f"clean target must be a regular file: {destination}")

    if not result:
        for destination in targets:
            print(f"clean: {destination.relative_to(home_root).as_posix()}")
            if not dry_run:
                destination.unlink()
    result.sort()
    return result


def pull_remote(
    mapping: list[ManagedFile],
    paths: list[str],
    layer: str,
    common_layer: ProfileLayer,
    profile_layer: ProfileLayer,
    target: str,
    remote_home: str,
    repo_root: Path = REPO_ROOT,
    dry_run: bool = False,
    runner: Runner = run,
    cwd: Path = REPO_ROOT,
    create_staging_directory: StagingDirectoryCreator = TemporaryDirectory,
) -> list[str]:
    selected_paths, result = collect_selected_paths(mapping, paths)
    files_from_paths = sorted(selected_paths, key=lambda path: path.as_posix())
    if layer not in {"owner", "common", "profile"}:
        result.append("layer must be one of: owner, common, profile")
    if dry_run:
        source_paths: dict[Path, Path] = {}
        for relative_path in files_from_paths:
            matching_files = [
                managed_file
                for managed_file in mapping
                if (
                    managed_file.relative_path == relative_path
                    or relative_path in managed_file.relative_path.parents
                )
            ]
            if matching_files:
                for managed_file in matching_files:
                    source_paths[managed_file.relative_path] = (
                        STAGING_PLACEHOLDER / managed_file.relative_path
                    )
            else:
                source_paths[relative_path] = STAGING_PLACEHOLDER / relative_path
        if layer in {"owner", "common", "profile"}:
            targets, target_errors = prepare_pull_targets(
                mapping, source_paths, layer, common_layer, profile_layer, repo_root
            )
            result.extend(target_errors)
        else:
            targets = []
        if not result:
            for managed_file in targets:
                print(
                    f"pull: {managed_file.relative_path.as_posix()} -> "
                    f"{managed_file.owner.name}"
                )
            print(
                "dry-run: remote contents and directory expansion cannot be "
                "validated without contacting the target"
            )
            runner(
                [
                    "rsync",
                    "-a",
                    "--checksum",
                    "--no-owner",
                    "--no-group",
                    "--recursive",
                    "--files-from",
                    str(STAGING_PLACEHOLDER / "files-from"),
                    f"{target}:{remote_home}",
                    f"{STAGING_PLACEHOLDER}/",
                ],
                True,
                cwd,
            )
    elif not result:
        with create_staging_directory() as staging_directory:
            staging_root = Path(staging_directory)
            files_from = staging_root / "files-from"
            files_from.write_text(
                "".join(
                    f"{relative_path.as_posix()}\n"
                    for relative_path in files_from_paths
                )
            )
            runner(
                [
                    "rsync",
                    "-a",
                    "--checksum",
                    "--no-owner",
                    "--no-group",
                    "--recursive",
                    "--files-from",
                    str(files_from),
                    f"{target}:{remote_home}",
                    f"{staging_root}/",
                ],
                False,
                cwd,
            )
            result = pull_local(
                mapping,
                paths,
                layer,
                common_layer,
                profile_layer,
                staging_root,
                repo_root,
                False,
                runner,
                cwd,
            )
    result.sort()
    return result


def render(
    output_directory: Annotated[
        str, CliArg(pos=True, opt=False, help="output directory for the overlay")
    ],
    profile: Annotated[
        str, CliArg(help="public or private profile identifier")
    ] = LOCAL_CLUSTER_NAME,
    os: Annotated[str | None, CliArg(help="operating system override")] = None,
) -> None:
    mapping, errors = resolve_mapping(profile, os, require_explicit_os=True)
    if errors:
        for error in sorted(errors):
            print(f"error: {error}", file=sys.stderr)
        sys.exit(1)
    errors = project_mapping(
        mapping,
        Path(output_directory),
        False,
        "render",
        create_root=True,
    )
    if errors:
        for error in sorted(errors):
            print(f"error: {error}", file=sys.stderr)
        sys.exit(1)


def pull(
    target: Annotated[
        str | None, CliArg(pos=True, opt=False, help="optional raw SSH target")
    ] = None,
    path: Annotated[
        list[str] | None,
        CliArg(help="home-relative files or directories to copy back"),
    ] = None,
    profile: Annotated[
        str, CliArg(help="public or private profile identifier")
    ] = LOCAL_CLUSTER_NAME,
    os: Annotated[str | None, CliArg(help="operating system override")] = None,
    remote_home: Annotated[
        str | None, CliArg(help="remote home, as an absolute POSIX path")
    ] = None,
    layer: Annotated[
        str, CliArg(help="destination layer: owner, common, or profile")
    ] = "owner",
    dry_run: Annotated[
        bool, CliArg(help="report copies without writing files")
    ] = False,
) -> None:
    profile_value, errors = parse_profile(profile)
    operating_system: str | None = None
    if target is not None and os is None:
        errors.append("--os is required for render and remote targets")
    else:
        operating_system, os_errors = resolve_os(os)
        errors.extend(os_errors)
    effective_remote_home, remote_home_errors = resolve_remote_home(target, remote_home)
    errors.extend(remote_home_errors)
    mapping: list[ManagedFile] = []
    common_layer: ProfileLayer | None = None
    profile_layer: ProfileLayer | None = None
    if profile_value is not None and operating_system is not None:
        layers, layer_errors = resolve_profile_layers(profile_value, operating_system)
        errors.extend(layer_errors)
        if profile_value.namespace is None:
            profiles_root = REPO_ROOT / PROFILES_DIR_NAME
            common_layer = ProfileLayer(
                "public common", profiles_root / COMMON_CLUSTER_NAME
            )
            profile_layer = ProfileLayer(
                "public profile",
                profiles_root / profile_value.cluster / operating_system,
            )
        else:
            profiles_root = (
                REPO_ROOT
                / PRIVATE_DIR_NAME
                / profile_value.namespace
                / profile_value.bundle
                / PROFILES_DIR_NAME
            )
            common_layer = ProfileLayer(
                "private common", profiles_root / COMMON_CLUSTER_NAME
            )
            profile_layer = ProfileLayer(
                "private profile",
                profiles_root / profile_value.cluster / operating_system,
            )
        if not layer_errors:
            mapping, mapping_errors = build_effective_mapping(layers)
            errors.extend(mapping_errors)

    if errors:
        for error in sorted(errors):
            print(f"error: {error}", file=sys.stderr)
        sys.exit(1)
    if common_layer is not None and profile_layer is not None:
        if target is None:
            errors = pull_local(
                mapping,
                [] if path is None else path,
                layer,
                common_layer,
                profile_layer,
                Path.home(),
                dry_run=dry_run,
            )
        else:
            errors = pull_remote(
                mapping,
                [] if path is None else path,
                layer,
                common_layer,
                profile_layer,
                target,
                effective_remote_home,
                dry_run=dry_run,
            )
    if errors:
        for error in sorted(errors):
            print(f"error: {error}", file=sys.stderr)
        sys.exit(1)


def clean(
    profile: Annotated[
        str, CliArg(help="public or private profile identifier")
    ] = LOCAL_CLUSTER_NAME,
    os: Annotated[str | None, CliArg(help="operating system override")] = None,
    dry_run: Annotated[
        bool, CliArg(help="report removals without changing files")
    ] = False,
) -> None:
    mapping, errors = resolve_mapping(profile, os)
    if errors:
        for error in sorted(errors):
            print(f"error: {error}", file=sys.stderr)
        sys.exit(1)
    errors = clean_local(mapping, Path.home(), dry_run)
    if errors:
        for error in sorted(errors):
            print(f"error: {error}", file=sys.stderr)
        sys.exit(1)


def provision(
    os: Annotated[str, CliArg(pos=True, opt=False, help="target operating system")],
    profile: Annotated[
        str, CliArg(help="public or private profile identifier")
    ] = LOCAL_CLUSTER_NAME,
    provision_args: Annotated[
        list[str] | None, CliArg(pos=True, help="arguments for the provisioner")
    ] = None,
) -> None:
    profile_value, errors = parse_profile(profile)
    operating_system, os_errors = resolve_os(os)
    errors.extend(os_errors)
    entry_point: Path | None = None
    expected_entry_point: Path | None = None
    if profile_value is not None and operating_system is not None:
        entry_point, expected_entry_point, provision_errors = resolve_provisioner(
            profile_value, operating_system
        )
        errors.extend(provision_errors)
        if entry_point is None and not provision_errors:
            if profile_value.namespace is None:
                errors.append(
                    f"missing required provision entry point: {expected_entry_point}"
                )
            else:
                errors.append(
                    "missing required provision entry point: "
                    f"{expected_entry_point}; clone or set up the private provision bundle"
                )
    if errors:
        for error in sorted(errors):
            print(f"error: {error}", file=sys.stderr)
        sys.exit(1)
    if (
        entry_point is not None
        and profile_value is not None
        and operating_system is not None
    ):
        run_provisioner(
            entry_point,
            profile_value,
            operating_system,
            [] if provision_args is None else provision_args,
        )


def setup(
    profile: Annotated[
        str, CliArg(help="public or private local profile identifier")
    ] = LOCAL_CLUSTER_NAME,
    os: Annotated[str | None, CliArg(help="operating system override")] = None,
    dry_run: Annotated[
        bool, CliArg(help="preview provisioning and copies without writing files")
    ] = False,
    provision_args: Annotated[
        list[str] | None, CliArg(pos=True, help="arguments for the provisioner")
    ] = None,
) -> None:
    errors = setup_local(
        profile,
        os,
        [] if provision_args is None else provision_args,
        Path.home(),
        dry_run=dry_run,
    )
    if errors:
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    cli(
        {
            setup: "provision and push the local profile overlay",
            push: "copy the selected profile overlay locally or to an SSH target",
            pull: "copy selected local or remote home files back to profile layers",
            clean: "remove only files in the current mapping; removed source paths remain",
            render: "project the selected overlay to an explicit output directory",
            provision: "run one selected provisioning entry point",
        },
        description="Deterministic dotfile overlay controller.",
    )
