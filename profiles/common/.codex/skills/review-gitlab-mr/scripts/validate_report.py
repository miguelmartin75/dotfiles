#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Validate objective structural requirements for a GitLab review report."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


REVIEW_H1_RE = re.compile(r"^# Review: `[^`\n]+`$", re.MULTILINE)
FINDING_RE = re.compile(r"^### P([0-3]):\s+\S.*$", re.MULTILINE)
POINTER_RE = re.compile(
    r"(?<![A-Za-z0-9_./:-])"
    r"(?!(?:https?|file)://)"
    r"(?!/)"
    r"(?:[A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+:([1-9]\d*)"
    r"\b(?![-:]\d)"
)
STATUS_RE = re.compile(r"^Status:\s+(Passed|Failed|Not run)\s*$", re.MULTILINE)
REVIEW_VERSION_RE = re.compile(r"^Review version: `([1-9]\d*)`\s*$", re.MULTILINE)
SNAPSHOT_STATUS_RE = re.compile(r"^Snapshot status:\s+Current\s*$", re.MULTILINE)
SNAPSHOT_CHECKED_AT_RE = re.compile(
    r"^Snapshot checked at: `\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z`\s*$",
    re.MULTILINE,
)
SHA_FIELDS = ("Target tip SHA", "Head SHA", "Merge-base SHA")
TEST_SUBSECTIONS = (
    "Existing coverage",
    "Validation gaps",
    "Test changes",
)
DISALLOWED_CHARACTERS = {
    "\u2014": "em dash",
    "\u2018": "left smart single quote",
    "\u2019": "right smart single quote",
    "\u201c": "left smart double quote",
    "\u201d": "right smart double quote",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--simple-format",
        action="store_true",
        help="also require LF-only text, no tabs, no em dashes, and no smart quotes",
    )
    parser.add_argument(
        "--allow-test-changes",
        action="store_true",
        help="allow content other than 'Not requested.' in the Test changes subsection",
    )
    parser.add_argument("report", type=Path, help="Markdown report to validate")
    return parser.parse_args()


def read_report(path: Path) -> tuple[str | None, list[str]]:
    try:
        data = path.read_bytes()
    except OSError as exc:
        return None, [f"cannot read {path}: {exc}"]

    try:
        result = data.decode("utf-8")
    except UnicodeDecodeError as exc:
        return None, [f"report is not valid UTF-8: {exc}"]

    return result, []


def mask_fenced_code(text: str) -> str:
    """Mask fenced code before scanning Markdown structure while preserving offsets."""
    result: list[str] = []
    fence_character: str | None = None
    fence_length = 0

    for line in text.splitlines(keepends=True):
        match = re.match(r"^ {0,3}(`{3,}|~{3,})", line)
        marker = match.group(1) if match is not None else None
        if fence_character is None:
            if marker is None:
                result.append(line)
                continue
            fence_character = marker[0]
            fence_length = len(marker)
        elif marker is not None and marker[0] == fence_character and len(marker) >= fence_length:
            if not line[match.end() :].strip():
                fence_character = None
                fence_length = 0

        if line.endswith("\n"):
            result.append(" " * (len(line) - 1) + "\n")
        else:
            result.append(" " * len(line))

    return "".join(result)


def section_matches(text: str, heading: str) -> list[re.Match[str]]:
    return list(re.finditer(rf"^## {re.escape(heading)}\s*$", text, re.MULTILINE))


def section_body(text: str, match: re.Match[str]) -> str:
    next_heading = re.search(r"^##\s+", text[match.end() :], re.MULTILINE)
    end = len(text) if next_heading is None else match.end() + next_heading.start()
    return text[match.end() : end]


def validate_simple_format(text: str) -> list[str]:
    errors: list[str] = []
    if "\r" in text:
        errors.append("report must use LF line endings; carriage returns were found")
    if "\t" in text:
        errors.append("report contains a tab character")
    for character, name in DISALLOWED_CHARACTERS.items():
        if character in text:
            errors.append(f"report contains a disallowed {name}")
    return errors


def validate_findings(text: str) -> tuple[list[str], list[re.Match[str]]]:
    errors: list[str] = []
    findings = list(FINDING_RE.finditer(text))
    priorities = [int(match.group(1)) for match in findings]
    if priorities != sorted(priorities):
        errors.append("finding headings must be ordered from P0 through P3")

    for finding in findings:
        next_heading = re.search(r"^#{1,3}\s+", text[finding.end() :], re.MULTILINE)
        end = len(text) if next_heading is None else finding.end() + next_heading.start()
        body = text[finding.end() : end]
        if POINTER_RE.search(body) is None:
            errors.append(f"finding lacks a repository-relative path:line pointer: {finding.group(0)}")

    no_findings = list(re.finditer(r"^No findings\.$", text, re.MULTILINE))
    if findings and no_findings:
        errors.append("report cannot contain findings and the literal 'No findings.'")
    elif not findings and len(no_findings) != 1:
        errors.append("report must contain P0-P3 findings or one literal 'No findings.' line")

    return errors, findings


def validate_report(
    text: str, *, simple_format: bool, allow_test_changes: bool = False
) -> list[str]:
    errors = validate_simple_format(text) if simple_format else []
    prose = mask_fenced_code(text)

    h1_headings = re.findall(r"^#\s+.+$", prose, re.MULTILINE)
    review_h1s = REVIEW_H1_RE.findall(prose)
    if len(h1_headings) != 1 or len(review_h1s) != 1:
        errors.append("report must contain exactly one H1, formatted '# Review: `<target>`'")

    h2_headings = list(re.finditer(r"^##\s+.+$", prose, re.MULTILINE))

    required_sections = (
        "Recommendation",
        "Recommended code shape",
        "LOC estimate",
        "Test review",
        "Validation status",
    )
    positions: dict[str, int] = {}
    bodies: dict[str, str] = {}
    section_match_by_heading: dict[str, re.Match[str]] = {}
    for heading in required_sections:
        matches = section_matches(prose, heading)
        if len(matches) != 1:
            errors.append(f"report must contain exactly one '## {heading}' section")
            continue
        positions[heading] = matches[0].start()
        bodies[heading] = section_body(prose, matches[0])
        section_match_by_heading[heading] = matches[0]
        if not bodies[heading].strip():
            errors.append(f"the {heading} section must not be empty")

    if all(heading in positions for heading in required_sections):
        ordered = [positions[heading] for heading in required_sections]
        if ordered != sorted(ordered):
            errors.append("required sections must follow the report contract order")
        if h2_headings and h2_headings[0].start() != positions["Recommendation"]:
            errors.append("Recommendation must be the first level-2 section")
        if h2_headings and h2_headings[-1].start() != positions["Validation status"]:
            errors.append("Validation status must be the final level-2 section")

    test_review = bodies.get("Test review")
    if test_review is not None:
        subsection_positions: list[int] = []
        test_changes_body: str | None = None
        test_review_start = section_match_by_heading["Test review"].end()
        for heading in TEST_SUBSECTIONS:
            matches = list(re.finditer(rf"^### {re.escape(heading)}\s*$", test_review, re.MULTILINE))
            if len(matches) != 1:
                errors.append(f"Test review must contain exactly one '### {heading}' subsection")
                continue
            subsection_positions.append(matches[0].start())
            next_subsection = re.search(r"^###\s+", test_review[matches[0].end() :], re.MULTILINE)
            end = (
                len(test_review)
                if next_subsection is None
                else matches[0].end() + next_subsection.start()
            )
            body = test_review[matches[0].end() : end]
            if not body.strip():
                errors.append(f"the '{heading}' test subsection must not be empty")
            if heading == "Test changes":
                test_changes_body = text[
                    test_review_start + matches[0].end() : test_review_start + end
                ]
        if len(subsection_positions) == len(TEST_SUBSECTIONS) and subsection_positions != sorted(
            subsection_positions
        ):
            errors.append("Test review subsections must follow the required order")
        if not allow_test_changes and test_changes_body is not None:
            if test_changes_body.strip() != "Not requested.":
                errors.append(
                    "Test changes must be exactly Not requested unless --allow-test-changes is supplied."
                )

    loc_body = bodies.get("LOC estimate")
    if loc_body is not None:
        basis = re.match(r"\s*Measurement basis:\s+\S.*$", loc_body, re.MULTILINE)
        if basis is None:
            errors.append("LOC estimate must start with a non-empty 'Measurement basis:' line")

    finding_errors, findings = validate_findings(prose)
    errors.extend(finding_errors)
    if "Recommendation" in positions and "Recommended code shape" in positions:
        start = positions["Recommendation"]
        end = positions["Recommended code shape"]
        if any(not start < finding.start() < end for finding in findings):
            errors.append("prioritized findings must appear before Recommended code shape")
        no_findings = re.search(r"^No findings\.$", prose, re.MULTILINE)
        if not findings and no_findings is not None and not start < no_findings.start() < end:
            errors.append("'No findings.' must appear before Recommended code shape")

    validation = bodies.get("Validation status")
    if validation is not None:
        if STATUS_RE.search(validation) is None:
            errors.append(
                "Validation status must include 'Status: Passed', 'Status: Failed', or 'Status: Not run'"
            )
        if REVIEW_VERSION_RE.search(validation) is None:
            errors.append("Validation status is missing a positive-integer 'Review version' field")
        if SNAPSHOT_STATUS_RE.search(validation) is None:
            errors.append("Validation status must include 'Snapshot status: Current'")
        if SNAPSHOT_CHECKED_AT_RE.search(validation) is None:
            errors.append("Validation status is missing an RFC 3339 UTC 'Snapshot checked at' field")
        for label in SHA_FIELDS:
            pattern = rf"^{re.escape(label)}: `[0-9a-fA-F]{{40}}`\s*$"
            if re.search(pattern, validation, re.MULTILINE) is None:
                errors.append(f"Validation status is missing a 40-character '{label}' field")

    return errors


def main() -> int:
    args = parse_args()
    text, errors = read_report(args.report)
    if text is not None:
        errors.extend(
            validate_report(
                text,
                simple_format=args.simple_format,
                allow_test_changes=args.allow_test_changes,
            )
        )

    if errors:
        print(f"INVALID: {args.report}", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(f"VALID: {args.report}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
