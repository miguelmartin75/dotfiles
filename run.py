#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.12"
# dependencies = ["msup"]
# ///

import os
import platform
from pathlib import Path, PurePosixPath
from typing import Annotated

from msup.cli import CliArg, cli

from dotfiles import (
    COMPONENT_PATTERN,
    REPO_ROOT,
    ManagedFile,
    ProfileLayer,
    build_effective_mapping,
    exit_on_errors,
    find_invalid_ancestor,
    project_mapping,
    pull_local,
    pull_remote,
    push_remote,
    resolve_layers,
    run,
)

LOCAL_CLUSTER_NAME = "local"


def detect_os() -> tuple[str | None, list[str]]:
    errors: list[str] = []
    system = platform.system()
    result: str | None = None
    if system == "Darwin":
        result = "macos"
    elif system == "Linux":
        try:
            os_release = Path("/etc/os-release").read_text()
        except OSError:
            errors.append("cannot read /etc/os-release; pass --os explicitly")
        else:
            for line in os_release.splitlines():
                if line.startswith("ID="):
                    value = line.removeprefix("ID=").strip()
                    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
                        value = value[1:-1]
                    result = value.lower()
                    break
            if result is None:
                errors.append("/etc/os-release has no ID entry; pass --os explicitly")
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


def resolve_os(requested_os: str | None) -> tuple[str | None, list[str]]:
    errors: list[str] = []
    result = requested_os
    if result is None:
        result, errors = detect_os()
    elif COMPONENT_PATTERN.fullmatch(result) is None:
        errors.append(f"invalid operating system component: {result!r}")
        result = None
    return result, errors


def resolve_mapping(
    profile: str | None,
    requested_os: str | None,
    require_explicit_os: bool = False,
) -> tuple[list[ManagedFile], list[str]]:
    errors: list[str] = []
    operating_system = None
    if require_explicit_os and requested_os is None:
        errors.append("--os is required for render and remote targets")
    else:
        operating_system, errors = resolve_os(requested_os)
    mapping: list[ManagedFile] = []
    if operating_system is not None:
        layers, layer_errors = resolve_layers(REPO_ROOT, operating_system, profile)
        errors.extend(layer_errors)
        if not layer_errors:
            mapping, mapping_errors = build_effective_mapping(layers)
            errors.extend(mapping_errors)
    return mapping, errors


def resolve_provisioner(
    profile: str | None,
    operating_system: str,
) -> tuple[Path | None, Path, list[str]]:
    if profile is not None and (
        COMPONENT_PATTERN.fullmatch(profile) is None
        or profile in {"common", "platform"}
    ):
        return None, REPO_ROOT / "provision", [f"invalid profile: {profile!r}"]
    entry_point = REPO_ROOT / "provision"
    if profile is not None:
        entry_point /= profile
    entry_point /= operating_system
    result: Path | None = None
    errors: list[str] = []
    invalid_ancestor = find_invalid_ancestor(
        REPO_ROOT, entry_point.relative_to(REPO_ROOT).parent
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
    elif entry_point.is_symlink():
        errors.append(f"provision entry point must not be a symlink: {entry_point}")
    elif entry_point.exists():
        if entry_point.is_file() and os.access(entry_point, os.X_OK):
            result = entry_point
        else:
            errors.append(
                "provision entry point must be a regular executable file: "
                f"{entry_point}"
            )

    return result, entry_point, errors


def run_provisioner(
    entry_point: Path,
    profile: str | None,
    operating_system: str,
    provision_args: list[str],
    dry_run: bool = False,
) -> None:
    context = {
        "DOTFILES_REPO_ROOT": str(REPO_ROOT),
        "DOTFILES_PROFILE": profile or "",
        "DOTFILES_OS": operating_system,
    }
    run(
        [str(entry_point), *provision_args],
        dry_run,
        entry_point.parent,
        context,
    )


def resolve_remote_home(
    target: str | None, remote_home: str | None
) -> tuple[str | None, list[str]]:
    errors: list[str] = []
    result: str | None = None
    if target is None:
        if remote_home is not None:
            errors.append("--remote_home requires a remote target")
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


def push(
    target: Annotated[
        str | None, CliArg(pos=True, opt=False, help="optional raw SSH target")
    ] = None,
    profile: Annotated[str | None, CliArg(help="optional target profile")] = None,
    os: Annotated[str | None, CliArg(help="operating system override")] = None,
    remote_home: Annotated[
        str | None, CliArg(help="remote home, as an absolute POSIX path")
    ] = None,
    dry_run: Annotated[
        bool, CliArg(help="report copies without writing files")
    ] = False,
    diff: Annotated[
        bool, CliArg(help="show unified content changes without writing files")
    ] = False,
) -> None:
    mapping, errors = resolve_mapping(
        profile, os, require_explicit_os=target is not None
    )
    effective_remote_home, remote_home_errors = resolve_remote_home(target, remote_home)
    errors.extend(remote_home_errors)
    if dry_run and diff:
        errors.append("--dry_run and --diff cannot be combined")
    if errors:
        exit_on_errors(errors)
    if target is None:
        errors = project_mapping(
            mapping, Path.home(), dry_run, "diff" if diff else "push", diff=diff
        )
    else:
        errors = push_remote(mapping, target, effective_remote_home, dry_run, diff)
    if errors:
        exit_on_errors(errors)


def render(
    output_directory: Annotated[
        str, CliArg(pos=True, opt=False, help="output directory for the overlay")
    ],
    profile: Annotated[str | None, CliArg(help="optional target profile")] = None,
    os: Annotated[str | None, CliArg(help="operating system override")] = None,
) -> None:
    mapping, errors = resolve_mapping(profile, os, require_explicit_os=True)
    if errors:
        exit_on_errors(errors)
    errors = project_mapping(
        mapping,
        Path(output_directory),
        False,
        "render",
        create_root=True,
    )
    if errors:
        exit_on_errors(errors)


def clean(
    profile: Annotated[str | None, CliArg(help="optional target profile")] = None,
    os: Annotated[str | None, CliArg(help="operating system override")] = None,
    dry_run: Annotated[
        bool, CliArg(help="report removals without changing files")
    ] = False,
) -> None:
    mapping, errors = resolve_mapping(profile, os)
    if errors:
        exit_on_errors(errors)

    home_root = Path.home()
    targets: list[Path] = []
    if home_root.is_symlink():
        errors.append(f"home root must not be a symlink: {home_root}")
    elif home_root.exists() and not home_root.is_dir():
        errors.append(f"home root must be a directory: {home_root}")

    if not errors:
        for managed_file in mapping:
            destination = home_root / managed_file.relative_path
            invalid_ancestor = find_invalid_ancestor(
                home_root, managed_file.relative_path.parent
            )
            if invalid_ancestor is not None:
                ancestor_path, is_symlink = invalid_ancestor
                if is_symlink:
                    errors.append(f"home parent must not be a symlink: {ancestor_path}")
                else:
                    errors.append(f"home parent must be a directory: {ancestor_path}")
            elif destination.is_symlink():
                errors.append(f"clean target must not be a symlink: {destination}")
            elif not destination.exists():
                continue
            elif destination.is_file():
                targets.append(destination)
            elif not destination.is_dir():
                errors.append(f"clean target must be a regular file: {destination}")

    if errors:
        exit_on_errors(errors)
    for destination in targets:
        print(f"clean: {destination.relative_to(home_root).as_posix()}")
        if not dry_run:
            destination.unlink()


def pull(
    target: Annotated[
        str | None, CliArg(pos=True, opt=False, help="optional raw SSH target")
    ] = None,
    path: Annotated[
        list[str] | None,
        CliArg(help="home-relative, partial, or absolute files or directories"),
    ] = None,
    profile: Annotated[str | None, CliArg(help="optional target profile")] = None,
    os: Annotated[str | None, CliArg(help="operating system override")] = None,
    remote_home: Annotated[
        str | None, CliArg(help="remote home, as an absolute POSIX path")
    ] = None,
    layer: Annotated[
        str, CliArg(help="destination layer: owner, common, platform, or profile")
    ] = "owner",
    dry_run: Annotated[
        bool, CliArg(help="report copies without writing files")
    ] = False,
    diff: Annotated[
        bool, CliArg(help="show unified content changes without writing files")
    ] = False,
) -> None:
    errors: list[str] = []
    if layer not in {"owner", "common", "platform", "profile"}:
        errors.append("layer must be one of: owner, common, platform, profile")
    if layer == "profile" and profile is None:
        errors.append("--layer profile requires --profile")
    operating_system = None
    if target is not None and os is None:
        errors.append("--os is required for render and remote targets")
    else:
        operating_system, os_errors = resolve_os(os)
        errors.extend(os_errors)
    effective_remote_home, remote_home_errors = resolve_remote_home(target, remote_home)
    errors.extend(remote_home_errors)
    if dry_run and diff:
        errors.append("--dry_run and --diff cannot be combined")
    mapping: list[ManagedFile] = []
    layers: list[ProfileLayer] = []
    destination_layer = None
    if operating_system is not None:
        layers, layer_errors = resolve_layers(REPO_ROOT, operating_system, profile)
        errors.extend(layer_errors)
        if not layer_errors:
            mapping, mapping_errors = build_effective_mapping(layers)
            errors.extend(mapping_errors)
            if layer != "owner":
                destination_layer = next(
                    (item for item in layers if item.name == layer), None
                )

    if errors:
        exit_on_errors(errors)
    if target is None:
        errors = pull_local(
            mapping,
            [] if path is None else path,
            layers,
            destination_layer,
            Path.home(),
            dry_run=dry_run,
            diff=diff,
        )
    else:
        errors = pull_remote(
            mapping,
            [] if path is None else path,
            layers,
            destination_layer,
            target,
            effective_remote_home,
            dry_run=dry_run,
            diff=diff,
        )
    if errors:
        exit_on_errors(errors)


def provision(
    os: Annotated[str, CliArg(pos=True, opt=False, help="target operating system")],
    profile: Annotated[str | None, CliArg(help="optional target profile")] = None,
    provision_args: Annotated[
        list[str] | None, CliArg(pos=True, help="arguments for the provisioner")
    ] = None,
) -> None:
    errors: list[str] = []
    profile_value = profile
    operating_system, os_errors = resolve_os(os)
    errors.extend(os_errors)
    entry_point: Path | None = None
    expected_entry_point: Path | None = None
    if operating_system is not None:
        entry_point, expected_entry_point, provision_errors = resolve_provisioner(
            profile_value, operating_system
        )
        errors.extend(provision_errors)
        if entry_point is None and not provision_errors:
            errors.append(
                f"missing required provision entry point: {expected_entry_point}"
            )
    if errors:
        exit_on_errors(errors)
    if entry_point is not None and operating_system is not None:
        run_provisioner(
            entry_point,
            profile_value,
            operating_system,
            [] if provision_args is None else provision_args,
        )


def setup(
    target: Annotated[
        str, CliArg(help="local or a raw SSH target")
    ] = LOCAL_CLUSTER_NAME,
    profile: Annotated[str | None, CliArg(help="optional target profile")] = None,
    os: Annotated[str | None, CliArg(help="operating system override")] = None,
    remote_home: Annotated[
        str | None, CliArg(help="remote home, as an absolute POSIX path")
    ] = None,
    dry_run: Annotated[
        bool, CliArg(help="preview provisioning and copies without writing files")
    ] = False,
    provision_args: Annotated[
        list[str] | None, CliArg(pos=True, help="arguments for the provisioner")
    ] = None,
) -> None:
    errors: list[str] = []
    profile_value = profile
    is_local = target == LOCAL_CLUSTER_NAME
    operating_system: str | None = None
    if not is_local and os is None:
        errors.append("--os is required for render and remote targets")
    else:
        operating_system, os_errors = resolve_os(os)
        errors.extend(os_errors)
    effective_remote_home, remote_home_errors = resolve_remote_home(
        None if is_local else target, remote_home
    )
    errors.extend(remote_home_errors)

    mapping: list[ManagedFile] = []
    entry_point: Path | None = None
    expected_entry_point: Path | None = None
    if operating_system is not None:
        layers, layer_errors = resolve_layers(
            REPO_ROOT, operating_system, profile_value
        )
        errors.extend(layer_errors)
        if not layer_errors:
            mapping, mapping_errors = build_effective_mapping(layers)
            errors.extend(mapping_errors)
        entry_point, expected_entry_point, provision_errors = resolve_provisioner(
            profile_value, operating_system
        )
        errors.extend(provision_errors)

    if errors:
        exit_on_errors(errors)
    if operating_system is not None:
        if entry_point is None:
            print(f"setup: provisioning skipped: {expected_entry_point}")
        else:
            print(f"setup: provisioning {'would run' if dry_run else 'running'}")
            run_provisioner(
                entry_point,
                profile_value,
                operating_system,
                [] if provision_args is None else provision_args,
                dry_run,
            )

        if is_local:
            errors = project_mapping(mapping, Path.home(), dry_run, "push")
        else:
            errors = push_remote(mapping, target, effective_remote_home, dry_run)
    if errors:
        exit_on_errors(errors)


if __name__ == "__main__":
    cli(
        {
            setup: "optionally provision, then push locally or to an SSH target",
            push: "copy the selected profile overlay locally or to an SSH target",
            pull: "copy selected local or remote home files back to profile layers",
            clean: (
                "remove only files in the current mapping; "
                "removed source paths remain"
            ),
            render: "project the selected overlay to an explicit output directory",
            provision: "run one selected provisioning entry point",
        },
        description="Deterministic dotfile overlay controller.",
    )
