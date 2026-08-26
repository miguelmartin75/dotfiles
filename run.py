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
from dataclasses import dataclass
from pathlib import Path
from typing import Annotated

from msup.cli import CliArg, cli

REPO_ROOT = Path(__file__).resolve().parent
PROFILES_DIR_NAME = "profiles"
PRIVATE_DIR_NAME = ".private"
COMMON_CLUSTER_NAME = "common"
LOCAL_CLUSTER_NAME = "local"
COMPONENT_PATTERN = re.compile(r"[a-z0-9][a-z0-9_-]*")


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
        path_has_symlink = False
        component_path = repo_root
        if component_path.is_symlink():
            errors.append(
                f"{name} layer contains a symlinked path component: {component_path}"
            )
            path_has_symlink = True
        if not path_has_symlink:
            for component in root.relative_to(repo_root).parts:
                component_path /= component
                if component_path.is_symlink():
                    errors.append(
                        f"{name} layer contains a symlinked path component: {component_path}"
                    )
                    path_has_symlink = True
                    break
                if not component_path.exists():
                    break
        if path_has_symlink:
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
                elif dirname == ".git":
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
                elif filename in {".git", ".gitkeep"}:
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
) -> tuple[list[ManagedFile], list[str]]:
    profile, errors = parse_profile(identifier)
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


def run(command: Sequence[str], dry_run: bool, cwd: Path = REPO_ROOT) -> None:
    print("$ " + shlex.join(command), flush=True)
    if not dry_run:
        environment = os.environ.copy()
        environment.pop("VIRTUAL_ENV", None)
        result = subprocess.run(command, cwd=cwd, env=environment, check=False)
        if result.returncode:
            sys.exit(result.returncode)


def push_local(
    mapping: list[ManagedFile],
    home_root: Path,
    dry_run: bool,
    runner: Runner = run,
    cwd: Path = REPO_ROOT,
) -> list[str]:
    result: list[str] = []
    for managed_file in mapping:
        destination = home_root / managed_file.relative_path
        parent_path = home_root
        has_invalid_parent = False
        for component in managed_file.relative_path.parts[:-1]:
            parent_path /= component
            if parent_path.is_symlink():
                result.append(
                    f"destination parent must not be a symlink: {parent_path}"
                )
                has_invalid_parent = True
                break
            elif parent_path.exists() and not parent_path.is_dir():
                result.append(f"destination parent must be a directory: {parent_path}")
                has_invalid_parent = True
                break
        if not has_invalid_parent and destination.is_dir():
            result.append(f"destination must not be a directory: {destination}")

    if not result:
        for managed_file in mapping:
            destination = home_root / managed_file.relative_path
            command = [
                "rsync",
                "-a",
                "--no-owner",
                "--no-group",
                str(managed_file.source_path),
                str(destination),
            ]
            if not dry_run:
                destination.parent.mkdir(parents=True, exist_ok=True)
            runner(command, dry_run, cwd)
    return result


def push(
    profile: Annotated[
        str, CliArg(help="public or private profile identifier")
    ] = LOCAL_CLUSTER_NAME,
    os: Annotated[str | None, CliArg(help="operating system override")] = None,
    dry_run: Annotated[
        bool, CliArg(help="report copies without writing files")
    ] = False,
) -> None:
    mapping, errors = resolve_mapping(profile, os)
    if errors:
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        sys.exit(1)
    errors = push_local(mapping, Path.home(), dry_run)
    if errors:
        for error in errors:
            print(f"error: {error}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    cli(
        {push: "copy the selected profile overlay to the local home directory"},
        description="Deterministic dotfile overlay controller.",
    )
