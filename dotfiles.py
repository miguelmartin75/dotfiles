import os
import re
import shlex
import subprocess
import sys
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from tempfile import TemporaryDirectory

REPO_ROOT = Path(__file__).resolve().parent
GIT_DIR_NAME = ".git"
PLACEHOLDER_FILE_NAME = ".gitkeep"
COMPONENT_PATTERN = re.compile(r"[a-z0-9][a-z0-9_-]*")
STAGING_PLACEHOLDER = Path("<staging>")
EXACT_FILE_RSYNC_ARGS = ("rsync", "-a", "--checksum", "--no-owner", "--no-group")


@dataclass(frozen=True)
class ProfileLayer:
    name: str
    root: Path


@dataclass(frozen=True)
class ManagedFile:
    relative_path: Path
    source_path: Path
    owner: ProfileLayer


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


def resolve_layers(
    root: Path,
    operating_system: str,
    platform: str | None = None,
    host: str | None = None,
    trusted_root: Path = REPO_ROOT,
) -> tuple[list[ProfileLayer], list[str]]:
    """Resolve ordered destinations; absent config directories are valid."""
    errors: list[str] = []
    layers: list[ProfileLayer] = []
    for label, value in (
        ("operating system", operating_system),
        ("platform", platform),
        ("host", host),
    ):
        if value is not None and COMPONENT_PATTERN.fullmatch(value) is None:
            errors.append(f"invalid {label} component: {value!r}")
    if root.is_symlink():
        errors.append(f"layer root must not be a symlink: {root}")
    elif not root.is_dir():
        errors.append(f"layer root must be a directory: {root}")
    try:
        relative_root = root.relative_to(trusted_root)
    except ValueError:
        errors.append(f"layer root must be below the public checkout: {root}")
    else:
        invalid_ancestor = find_invalid_ancestor(trusted_root, relative_root)
        if invalid_ancestor is not None:
            errors.append(
                f"layer root contains an invalid path component: {invalid_ancestor[0]}"
            )
    if errors:
        return layers, errors

    candidates = [ProfileLayer("common", root / "common" / "config")]
    if operating_system not in {"macos", "linux"}:
        candidates.append(ProfileLayer("family", root / "os/linux/config"))
    os_root = root / "os" / operating_system
    candidates.append(ProfileLayer("os", os_root / "config"))
    if platform is not None:
        candidates.append(
            ProfileLayer("platform", os_root / "platforms" / platform / "config")
        )
    if host is not None:
        candidates.append(ProfileLayer("host", os_root / "hosts" / host / "config"))
    for layer in candidates:
        invalid_ancestor = find_invalid_ancestor(
            trusted_root, layer.root.relative_to(trusted_root)
        )
        if invalid_ancestor is not None:
            errors.append(
                f"{layer.name} layer contains an invalid path component: "
                f"{invalid_ancestor[0]}"
            )
        else:
            layers.append(layer)
    return layers, errors


def resolve_setup(
    root: Path,
    operating_system: str,
    platform: str | None = None,
    host: str | None = None,
    setup_platform: str | None = None,
    trusted_root: Path = REPO_ROOT,
) -> tuple[Path | None, list[str]]:
    """Select one recipe. An invalid present candidate stops selection."""
    errors: list[str] = []
    for label, value in (
        ("operating system", operating_system),
        ("platform", platform),
        ("host", host),
        ("setup platform", setup_platform),
    ):
        if value is not None and COMPONENT_PATTERN.fullmatch(value) is None:
            errors.append(f"invalid {label} component: {value!r}")
    try:
        relative_root = root.relative_to(trusted_root)
    except ValueError:
        errors.append(f"setup root must be below the public checkout: {root}")
    else:
        invalid_ancestor = find_invalid_ancestor(trusted_root, relative_root)
        if invalid_ancestor is not None:
            errors.append(
                f"setup root contains an invalid path component: {invalid_ancestor[0]}"
            )
    if root.is_symlink() or not root.is_dir():
        errors.append(f"setup root must be a real directory: {root}")
    if errors:
        return None, errors

    os_root = root / "os" / operating_system
    candidates: list[Path] = []
    if host is not None:
        candidates.append(os_root / "hosts" / host / "setup")
    if platform is not None:
        candidates.append(os_root / "platforms" / platform / "setup")
    if setup_platform is not None and setup_platform != platform:
        candidates.append(os_root / "platforms" / setup_platform / "setup")
    candidates.append(os_root / "setup")
    for candidate in candidates:
        invalid_ancestor = find_invalid_ancestor(
            trusted_root, candidate.relative_to(trusted_root).parent
        )
        if invalid_ancestor is not None:
            return None, [
                "setup entry point contains an invalid path component: "
                f"{invalid_ancestor[0]}"
            ]
        elif candidate.is_symlink():
            return None, [f"setup entry point must not be a symlink: {candidate}"]
        elif candidate.exists():
            if candidate.is_file() and os.access(candidate, os.X_OK):
                return candidate, []
            else:
                return None, [
                    f"setup entry point must be a regular executable file: {candidate}"
                ]

    return None, []


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
                                f"{source_path} and "
                                f"{mapping[existing_path].source_path}"
                            )
                    else:
                        mapping[relative_path] = ManagedFile(
                            relative_path, source_path, layer
                        )

    result = sorted(mapping.values(), key=lambda file: file.relative_path.as_posix())
    return result, errors


def run(
    command: Sequence[str],
    dry_run: bool,
    cwd: Path,
    context: dict[str, str] | None = None,
    expected_returncodes: tuple[int, ...] = (0,),
    capture_output: bool = False,
    input_data: bytes | None = None,
) -> subprocess.CompletedProcess[bytes] | None:
    print("$ " + shlex.join(command), flush=True)
    if not dry_run:
        environment = os.environ.copy()
        environment.pop("VIRTUAL_ENV", None)
        if context is not None:
            environment.update(context)
        result = subprocess.run(  # noqa: PLW1510
            command,
            cwd=cwd,
            env=environment,
            input=input_data,
            stdout=subprocess.PIPE if capture_output else None,
        )
        if result.returncode not in expected_returncodes:
            sys.exit(result.returncode)
        return result
    return None


def exit_on_errors(errors: list[str]) -> None:
    for error in sorted(errors):
        print(f"error: {error}", file=sys.stderr)
    sys.exit(1)


def validate_projection(
    mapping: list[ManagedFile],
    destination_root: Path,
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
        elif destination.exists() and not destination.is_file():
            result.append(f"destination must be a regular file: {destination}")

    return result


def project_mapping(
    mapping: list[ManagedFile],
    destination_root: Path,
    dry_run: bool,
    action: str,
    create_root: bool = False,
    diff: bool = False,
    destination_label_root: str | None = None,
) -> list[str]:
    result = validate_projection(mapping, destination_root)

    if not result:
        if create_root and not dry_run:
            destination_root.mkdir(parents=True, exist_ok=True)
        for managed_file in mapping:
            destination = destination_root / managed_file.relative_path
            print(f"{action}: {managed_file.relative_path.as_posix()}")
            if diff:
                current_path = (
                    destination if destination.exists() else Path("/dev/null")
                )
                destination_label = str(destination)
                if destination_label_root is not None:
                    destination_label = (
                        destination_label_root + managed_file.relative_path.as_posix()
                    )
                run(
                    [
                        "diff",
                        "-u",
                        "--label",
                        destination_label,
                        "--label",
                        str(managed_file.source_path),
                        str(current_path),
                        str(managed_file.source_path),
                    ],
                    False,
                    REPO_ROOT,
                    expected_returncodes=(0, 1),
                )
            else:
                command = [
                    *EXACT_FILE_RSYNC_ARGS,
                    str(managed_file.source_path),
                    str(destination),
                ]
                if not dry_run:
                    destination.parent.mkdir(parents=True, exist_ok=True)
                run(command, dry_run, REPO_ROOT)
    return result


def push_remote(
    mapping: list[ManagedFile],
    target: str,
    remote_home: str,
    dry_run: bool,
    diff: bool = False,
) -> list[str]:
    result: list[str] = []
    if dry_run:
        for managed_file in mapping:
            destination = STAGING_PLACEHOLDER / managed_file.relative_path
            print(f"push: {managed_file.relative_path.as_posix()}")
            run(
                [
                    *EXACT_FILE_RSYNC_ARGS,
                    str(managed_file.source_path),
                    str(destination),
                ],
                True,
                REPO_ROOT,
            )
        run(
            [
                "rsync",
                "-a",
                "--no-owner",
                "--no-group",
                f"{STAGING_PLACEHOLDER}/",
                f"{target}:{remote_home}",
            ],
            True,
            REPO_ROOT,
        )
    elif diff:
        with TemporaryDirectory() as staging_directory:
            staging_root = Path(staging_directory)
            included_paths: set[Path] = set()
            for managed_file in mapping:
                included_paths.add(managed_file.relative_path)
                included_paths.update(managed_file.relative_path.parents)
            included_paths.discard(Path("."))
            include_args: list[str] = []
            for relative_path in sorted(
                included_paths, key=lambda path: path.as_posix()
            ):
                escaped_path = relative_path.as_posix()
                for character in ("\\", "*", "?", "["):
                    escaped_path = escaped_path.replace(character, "\\" + character)
                include_args.append(f"--include=/{escaped_path}")
            run(
                [
                    *EXACT_FILE_RSYNC_ARGS,
                    *include_args,
                    "--exclude=*",
                    f"{target}:{remote_home}",
                    f"{staging_root}/",
                ],
                False,
                REPO_ROOT,
            )
            result = project_mapping(
                mapping,
                staging_root,
                False,
                "diff",
                diff=True,
                destination_label_root=f"{target}:{remote_home}",
            )
    else:
        with TemporaryDirectory() as staging_directory:
            staging_root = Path(staging_directory)
            result = project_mapping(mapping, staging_root, False, "push")
            if not result:
                run(
                    [
                        "rsync",
                        "-a",
                        "--no-owner",
                        "--no-group",
                        f"{staging_root}/",
                        f"{target}:{remote_home}",
                    ],
                    False,
                    REPO_ROOT,
                )
    return result


def collect_selected_paths(
    mapping: list[ManagedFile],
    paths: list[str],
    home_root: Path | PurePosixPath | None = None,
    remote: bool = False,
) -> tuple[set[Path], list[str]]:
    """Resolve exact paths first; relative nonmatches component-match or stay exact.

    Absolute paths below home_root are normalized but always remain exact.
    """
    result: set[Path] = set()
    errors: list[str] = []
    exact_paths = {managed_file.relative_path for managed_file in mapping}
    if paths:
        for path_text in paths:
            if not path_text or any(
                part in {".", ".."} for part in path_text.split("/")
            ):
                errors.append(f"path must not contain traversal: {path_text!r}")
                continue

            candidate_path: Path | PurePosixPath
            if remote:
                candidate_path = PurePosixPath(path_text)
            else:
                candidate_path = Path(path_text)

            relative_path: Path | None = None
            was_absolute = candidate_path.is_absolute()
            if was_absolute:
                if home_root is None:
                    errors.append(
                        "absolute paths require an explicit absolute --remote_home: "
                        f"{path_text!r}"
                    )
                else:
                    try:
                        selected_relative_path = candidate_path.relative_to(home_root)
                    except ValueError:
                        errors.append(
                            f"absolute path must be inside the home root: {path_text!r}"
                        )
                    else:
                        if selected_relative_path == Path("."):
                            errors.append(
                                "path must select a file or directory "
                                "below the home root: "
                                f"{path_text!r}"
                            )
                        else:
                            relative_path = Path(selected_relative_path.as_posix())
            else:
                relative_path = Path(candidate_path.as_posix())

            if relative_path is None:
                continue
            if GIT_DIR_NAME in relative_path.parts:
                errors.append(
                    f"selected path cannot include {GIT_DIR_NAME}: {relative_path}"
                )
            elif PLACEHOLDER_FILE_NAME in relative_path.parts:
                errors.append(
                    "selected path cannot include "
                    f"{PLACEHOLDER_FILE_NAME}: {relative_path}"
                )
            elif was_absolute:
                result.add(relative_path)
            else:
                is_exact_selection = relative_path in exact_paths or any(
                    relative_path in managed_file.relative_path.parents
                    for managed_file in mapping
                )
                if is_exact_selection:
                    result.add(relative_path)
                else:
                    partial_matches = [
                        managed_file.relative_path
                        for managed_file in mapping
                        if any(
                            managed_file.relative_path.parts[
                                index : index + len(relative_path.parts)
                            ]
                            == relative_path.parts
                            for index in range(
                                len(managed_file.relative_path.parts)
                                - len(relative_path.parts)
                                + 1
                            )
                        )
                    ]
                    if partial_matches:
                        result.update(partial_matches)
                    else:
                        result.add(relative_path)
    else:
        result.update(managed_file.relative_path for managed_file in mapping)
    return result, errors


def prepare_pull_targets(
    mapping: list[ManagedFile],
    source_paths: dict[Path, Path],
    layers: list[ProfileLayer],
    destination_layer: ProfileLayer | None,
    trusted_root: Path = REPO_ROOT,
) -> tuple[list[ManagedFile], list[str]]:
    mapping_by_path = {
        managed_file.relative_path: managed_file for managed_file in mapping
    }
    result: list[str] = []
    targets: list[ManagedFile] = []

    for relative_path, source_path in sorted(
        source_paths.items(), key=lambda item: item[0].as_posix()
    ):
        managed_file = mapping_by_path.get(relative_path)
        owner = managed_file.owner if managed_file is not None else None
        if destination_layer is not None:
            owner = destination_layer

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
            if destination_layer is None:
                result.append(
                    "new path requires --layer common, os, platform, or host: "
                    f"{relative_path}"
                )
            elif not collision_paths and owner is not None:
                targets.append(ManagedFile(relative_path, source_path, owner))
        elif (
            destination_layer is not None
            and owner is not None
            and owner != managed_file.owner
            and layers.index(owner) < layers.index(managed_file.owner)
        ):
            result.append(
                f"explicit {owner.name} layer for {relative_path} would be hidden by "
                f"{managed_file.owner.name} layer"
            )
        elif owner is not None:
            targets.append(ManagedFile(relative_path, source_path, owner))

    validated_roots: set[Path] = set()
    invalid_roots: set[Path] = set()
    for managed_file in targets:
        if managed_file.owner.root not in validated_roots:
            validated_roots.add(managed_file.owner.root)
            invalid_ancestor = find_invalid_ancestor(
                trusted_root, managed_file.owner.root.relative_to(trusted_root)
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

    return targets, result


def pull_local(
    mapping: list[ManagedFile],
    paths: list[str],
    layers: list[ProfileLayer],
    destination_layer: ProfileLayer | None,
    home_root: Path,
    dry_run: bool = False,
    diff: bool = False,
    source_label_root: str | None = None,
    selected_paths: set[Path] | None = None,
    trusted_root: Path = REPO_ROOT,
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

    if selected_paths is None:
        selected_paths, selection_errors = collect_selected_paths(
            mapping, paths, home_root
        )
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
                            "symlinked directory in selected home path: "
                            f"{candidate_path}"
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
        mapping, source_paths, layers, destination_layer, trusted_root
    )
    result.extend(target_errors)

    if not result:
        for managed_file in targets:
            destination = managed_file.owner.root / managed_file.relative_path
            print(
                f"{'diff' if diff else 'pull'}: "
                f"{managed_file.relative_path.as_posix()} -> {managed_file.owner.name}"
            )
            if diff:
                current_path = (
                    destination if destination.exists() else Path("/dev/null")
                )
                source_label = str(managed_file.source_path)
                if source_label_root is not None:
                    source_label = (
                        source_label_root + managed_file.relative_path.as_posix()
                    )
                run(
                    [
                        "diff",
                        "-u",
                        "--label",
                        str(destination),
                        "--label",
                        source_label,
                        str(current_path),
                        str(managed_file.source_path),
                    ],
                    False,
                    REPO_ROOT,
                    expected_returncodes=(0, 1),
                )
            elif not dry_run:
                destination.parent.mkdir(parents=True, exist_ok=True)
            if not diff:
                run(
                    [
                        *EXACT_FILE_RSYNC_ARGS,
                        str(managed_file.source_path),
                        str(destination),
                    ],
                    dry_run,
                    REPO_ROOT,
                )
    return result


def pull_remote(
    mapping: list[ManagedFile],
    paths: list[str],
    layers: list[ProfileLayer],
    destination_layer: ProfileLayer | None,
    target: str,
    remote_home: str,
    dry_run: bool = False,
    diff: bool = False,
    trusted_root: Path = REPO_ROOT,
) -> list[str]:
    remote_home_root: PurePosixPath | None = None
    if remote_home.startswith("/"):
        remote_home_root = PurePosixPath(remote_home)
    selected_paths, result = collect_selected_paths(
        mapping, paths, remote_home_root, remote=True
    )
    files_from_paths = sorted(selected_paths, key=lambda path: path.as_posix())
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
        targets, target_errors = prepare_pull_targets(
            mapping,
            source_paths,
            layers,
            destination_layer,
            trusted_root,
        )
        result.extend(target_errors)
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
            run(
                [
                    *EXACT_FILE_RSYNC_ARGS,
                    "--recursive",
                    "--files-from",
                    str(STAGING_PLACEHOLDER / "files-from"),
                    "--from0",
                    f"{target}:{remote_home}",
                    f"{STAGING_PLACEHOLDER}/",
                ],
                True,
                REPO_ROOT,
            )
    elif not result:
        with TemporaryDirectory() as staging_directory:
            staging_root = Path(staging_directory)
            files_from = staging_root / "files-from"
            files_from.write_bytes(
                b"".join(
                    relative_path.as_posix().encode() + b"\0"
                    for relative_path in files_from_paths
                )
            )
            run(
                [
                    *EXACT_FILE_RSYNC_ARGS,
                    "--recursive",
                    "--files-from",
                    str(files_from),
                    "--from0",
                    f"{target}:{remote_home}",
                    f"{staging_root}/",
                ],
                False,
                REPO_ROOT,
            )
            result = pull_local(
                mapping,
                paths,
                layers,
                destination_layer,
                staging_root,
                False,
                diff,
                f"{target}:{remote_home}" if diff else None,
                selected_paths,
                trusted_root,
            )
    return result
