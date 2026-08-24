#!/usr/bin/env python3
"""Small, deterministic AVC/XP doctor and schema validator."""

from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tomllib
from typing import Any

try:
    import yaml
except ImportError:  # pragma: no cover - exercised by doctor on lean hosts
    yaml = None


ROOT = Path(__file__).resolve().parents[2]
REQUIRED_RESULT_KEYS = (
    "status",
    "summary",
    "facts",
    "changed_paths",
    "commands",
    "findings",
    "risks_discovered",
    "requested_transition",
    "state_revision",
    "head",
)
ALLOWED_STATUSES = {"PASS", "FAIL", "BLOCKED", "NEEDS_AMENDMENT"}
CORE_SKILLS = {
    "avc-start",
    "avc-scout",
    "avc-freeze-oracle",
    "avc-build-slice",
    "avc-verify",
    "avc-review",
    "avc-live-qa",
    "avc-amend",
    "avc-spike",
    "avc-retro",
}
MEMORY_SKILLS = {
    "ai-memory-durable-pages",
    "ai-memory-handoff",
    "ai-memory-learning-maintenance",
    "ai-memory-retrieval",
    "ai-memory-routing-install",
}


def load_yaml(path: Path) -> Any:
    if yaml is None:
        raise RuntimeError("PyYAML is required: install the python3-yaml package")
    with path.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle)


def tree_fingerprint(root: Path = ROOT) -> str:
    git = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "HEAD"],
        check=False,
        capture_output=True,
        text=True,
    )
    if git.returncode == 0:
        return git.stdout.strip()

    digest = hashlib.sha256()
    ignored_parts = {".git", "runtime", "tools", "__pycache__"}
    for path in sorted(root.rglob("*")):
        if not path.is_file() or any(part in ignored_parts for part in path.parts):
            continue
        relative = path.relative_to(root).as_posix()
        if relative.startswith(".avc/evidence/") and not relative.endswith(".gitkeep"):
            continue
        digest.update(relative.encode())
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return f"UNBORN:{digest.hexdigest()}"


def validate_agent_result(data: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(data, dict):
        return ["result must be a YAML mapping"]
    missing = [key for key in REQUIRED_RESULT_KEYS if key not in data]
    if missing:
        errors.append(f"missing keys: {', '.join(missing)}")
    if data.get("status") not in ALLOWED_STATUSES:
        errors.append("status must be PASS, FAIL, BLOCKED, or NEEDS_AMENDMENT")
    for key in ("facts", "changed_paths", "commands", "findings", "risks_discovered"):
        if key in data and not isinstance(data[key], list):
            errors.append(f"{key} must be a list")
    for index, command in enumerate(data.get("commands") or []):
        if not isinstance(command, dict) or "argv" not in command or "exit_code" not in command:
            errors.append(f"commands[{index}] must contain argv and exit_code")
    for index, finding in enumerate(data.get("findings") or []):
        required = {"severity", "claim", "evidence", "recommendation"}
        if not isinstance(finding, dict) or not required.issubset(finding):
            errors.append(f"findings[{index}] must contain {', '.join(sorted(required))}")
    return errors


def read_skill_frontmatter(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        raise ValueError("missing YAML frontmatter")
    try:
        raw = text.split("---\n", 2)[1]
    except IndexError as exc:
        raise ValueError("unterminated YAML frontmatter") from exc
    data = yaml.safe_load(raw) if yaml else None
    if not isinstance(data, dict):
        raise ValueError("frontmatter must be a mapping")
    return data


def run_doctor(*, offline: bool, strict: bool, json_output: bool) -> int:
    checks: list[dict[str, str]] = []

    def add(status: str, name: str, detail: str) -> None:
        checks.append({"status": status, "name": name, "detail": detail})

    required_files = [
        "AGENTS.md",
        ".avc/config.yaml",
        ".avc/run.yaml",
        ".avc/templates/agent-result.yaml",
        ".avc/hooks/avc_hook.py",
        ".ai-memory.toml",
    ]
    missing = [item for item in required_files if not (ROOT / item).is_file()]
    add("FAIL" if missing else "PASS", "required-files", ", ".join(missing) or "present")

    if yaml is None:
        add("FAIL", "pyyaml", "python3-yaml/PyYAML is not installed")
        config = run = None
    else:
        add("PASS", "pyyaml", yaml.__version__)
        try:
            config = load_yaml(ROOT / ".avc/config.yaml")
            run = load_yaml(ROOT / ".avc/run.yaml")
            add("PASS", "yaml", "config and run parsed")
        except Exception as exc:  # noqa: BLE001 - doctor must report all parse failures
            config = run = None
            add("FAIL", "yaml", str(exc))

    if isinstance(config, dict):
        project_name = config.get("project", {}).get("name")
        operating_model = config.get("operating_model", {})
        provider = config.get("memory", {}).get("provider")
        commands = config.get("commands", {})
        empty_required = [key for key in ("baseline", "fast", "affected", "acceptance", "full_ci") if not commands.get(key)]
        valid_name = isinstance(project_name, str) and re.fullmatch(r"[a-z0-9][a-z0-9._-]*", project_name)
        valid_model = (
            operating_model.get("active") == "avc"
            and "sdd" in operating_model.get("alternatives", [])
            and operating_model.get("selection") == "mutually_exclusive"
            and operating_model.get("switch_requires_human") is True
            and operating_model.get("close_active_run_before_switch") is True
        )
        if valid_name and project_name != "replace-me" and valid_model and provider == "ai-memory" and not empty_required:
            add("PASS", "config-contract", "project, exclusive AVC operating model, memory provider, and gates configured")
        else:
            add("FAIL", "config-contract", f"project={project_name!r} operating_model={operating_model!r} provider={provider!r} empty={empty_required}")

    if isinstance(run, dict):
        required_run = {"version", "run_id", "revision", "head", "story", "scope", "commands", "oracle", "authority", "state", "graph", "discoveries", "amendments", "evidence"}
        absent = sorted(required_run - set(run))
        add("FAIL" if absent else "PASS", "run-schema", ", ".join(absent) or "all top-level keys present")

    codex_config_path = ROOT / ".codex/config.toml"
    if codex_config_path.is_file():
        try:
            with codex_config_path.open("rb") as handle:
                codex_config = tomllib.load(handle)
            server = codex_config.get("mcp_servers", {}).get("ai-memory", {})
            good = server.get("required") is True and server.get("url") == "http://127.0.0.1:49374/mcp"
            add("PASS" if good else "FAIL", "codex-mcp", "required loopback ai-memory MCP" if good else repr(server))
        except Exception as exc:  # noqa: BLE001
            add("FAIL", "codex-config", str(exc))

        try:
            hooks = json.loads((ROOT / ".codex/hooks.json").read_text(encoding="utf-8"))
            events = set(hooks.get("hooks", {}))
            expected = {"SessionStart", "SessionEnd", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PreCompact", "SubagentStart", "SubagentStop", "Stop"}
            absent = sorted(expected - events)
            add("FAIL" if absent else "PASS", "codex-hooks", ", ".join(absent) or "all lifecycle events present")
        except Exception as exc:  # noqa: BLE001
            add("FAIL", "codex-hooks", str(exc))
    else:
        add("PASS", "codex-adapter", "not selected; portable kernel remains active")

    found_skills: set[str] = set()
    skill_errors: list[str] = []
    for skill_file in sorted((ROOT / ".agents/skills").glob("*/SKILL.md")):
        try:
            frontmatter = read_skill_frontmatter(skill_file)
            name = frontmatter.get("name")
            description = frontmatter.get("description")
            if name != skill_file.parent.name or not isinstance(description, str) or not description.strip():
                raise ValueError("name/folder mismatch or empty description")
            found_skills.add(name)
        except Exception as exc:  # noqa: BLE001
            skill_errors.append(f"{skill_file.parent.name}: {exc}")
    missing_skills = sorted((CORE_SKILLS | MEMORY_SKILLS) - found_skills)
    if missing_skills:
        skill_errors.append(f"missing: {', '.join(missing_skills)}")
    add("FAIL" if skill_errors else "PASS", "skills", "; ".join(skill_errors) or f"{len(found_skills)} valid skills")

    fingerprint = tree_fingerprint()
    if fingerprint.startswith("UNBORN:"):
        add("WARN", "git-head", f"repository has no commit; tree fingerprint {fingerprint[7:19]}")
    else:
        add("PASS", "git-head", fingerprint)

    binary = ROOT / ".avc/tools/ai-memory/bin/ai-memory"
    if not binary.is_file():
        binary_path = shutil.which("ai-memory")
        binary = Path(binary_path) if binary_path else binary
    if not binary.is_file():
        add("WARN" if offline else "FAIL", "ai-memory-binary", "run ./.avc/scripts/bootstrap-ai-memory.sh")
    else:
        version = subprocess.run([str(binary), "--version"], check=False, capture_output=True, text=True)
        expected_version = str((config or {}).get("memory", {}).get("version", ""))
        good = version.returncode == 0 and expected_version in version.stdout
        add("PASS" if good else "FAIL", "ai-memory-binary", version.stdout.strip() or version.stderr.strip())

        if not offline:
            env = os.environ.copy()
            env.setdefault("AI_MEMORY_SERVER_URL", "http://127.0.0.1:49374")
            status = subprocess.run(
                [str(binary), "--data-dir", str(ROOT / ".avc/runtime/ai-memory-client"), "status"],
                cwd=ROOT,
                env=env,
                check=False,
                capture_output=True,
                text=True,
                timeout=15,
            )
            detail = (status.stdout or status.stderr).strip().splitlines()
            add("PASS" if status.returncode == 0 else "FAIL", "ai-memory-server", detail[0] if detail else f"exit {status.returncode}")

    if strict:
        for check in checks:
            if check["status"] == "WARN":
                check["status"] = "FAIL"
                check["detail"] = f"strict: {check['detail']}"

    if json_output:
        print(json.dumps({"root": str(ROOT), "fingerprint": fingerprint, "checks": checks}, indent=2))
    else:
        for check in checks:
            print(f"{check['status']:4} {check['name']}: {check['detail']}")
    return 1 if any(check["status"] == "FAIL" for check in checks) else 0


LANE_ORDER = {"flow": 0, "guarded": 1, "governed": 2}


def changed_paths(against: str | None) -> list[str]:
    """Changed paths as posix strings, relative to ROOT. Includes untracked
    new files (a brand-new module's path matters just as much as an edited
    one) and, when --against is given, everything that differs from that
    revision instead of the working tree."""
    paths: set[str] = set()
    if against:
        diff = subprocess.run(
            ["git", "-C", str(ROOT), "diff", "--name-only", against],
            check=False, capture_output=True, text=True,
        )
        paths.update(line.strip() for line in diff.stdout.splitlines() if line.strip())
    else:
        diff = subprocess.run(
            ["git", "-C", str(ROOT), "diff", "--name-only", "HEAD"],
            check=False, capture_output=True, text=True,
        )
        paths.update(line.strip() for line in diff.stdout.splitlines() if line.strip())
        status = subprocess.run(
            ["git", "-C", str(ROOT), "status", "--porcelain", "--untracked-files=all"],
            check=False, capture_output=True, text=True,
        )
        for line in status.stdout.splitlines():
            if line.startswith("??"):
                paths.add(line[3:].strip())
    return sorted(paths)


def classify_paths(config: dict, paths: list[str], text: str | None) -> tuple[str, list[str]]:
    """Mechanical-only classification: matches changed paths (and optional
    free text) against risk_triggers.*.confirmed_paths/signal_paths and
    signal_keywords. Returns the MINIMUM lane these mechanical signals alone
    justify, and the reasons. This never substitutes for a Navigator's
    semantic confirmed_impacts judgment (e.g. "this changes auth
    enforcement") — that stays doctrine, by design; see
    risk_triggers.classification comments in .avc/config.yaml."""
    triggers = config.get("risk_triggers") or {}
    classification = triggers.get("classification") or {}
    floor_lane = classification.get("unknown_signal_minimum_lane", "guarded")

    lane = "flow"
    reasons: list[str] = []

    def promote(new_lane: str, reason: str) -> None:
        nonlocal lane
        if LANE_ORDER[new_lane] > LANE_ORDER[lane]:
            lane = new_lane
        reasons.append(reason)

    for tier in ("guarded", "governed"):
        tier_cfg = triggers.get(tier) or {}
        for pattern in tier_cfg.get("confirmed_paths") or []:
            hits = [p for p in paths if fnmatch.fnmatch(p, pattern)]
            if hits:
                promote(tier, f"confirmed_paths[{tier}] {pattern!r} matched {hits}")
        for pattern in tier_cfg.get("signal_paths") or []:
            hits = [p for p in paths if fnmatch.fnmatch(p, pattern)]
            if hits:
                promote(floor_lane, f"signal_paths[{tier}] {pattern!r} matched {hits} (signal only, floor={floor_lane})")
        if text:
            lowered = text.lower()
            hit_keywords = [kw for kw in tier_cfg.get("signal_keywords") or [] if kw.lower() in lowered]
            if hit_keywords:
                promote(floor_lane, f"signal_keywords[{tier}] {hit_keywords} found in text (signal only, floor={floor_lane})")

    if not reasons:
        reasons.append("no confirmed_paths/signal_paths/signal_keywords matched — mechanical floor is flow")
    return lane, reasons


def main() -> int:
    parser = argparse.ArgumentParser(prog="avc", description="AVC/XP repository harness")
    subparsers = parser.add_subparsers(dest="command", required=True)
    doctor = subparsers.add_parser("doctor", help="validate the active AVC installation")
    doctor.add_argument("--offline", action="store_true", help="skip live ai-memory server health")
    doctor.add_argument("--strict", action="store_true", help="promote warnings to failures")
    doctor.add_argument("--json", action="store_true", help="emit machine-readable output")

    validate = subparsers.add_parser("validate-result", help="validate a canonical agent result")
    validate.add_argument("path", help="YAML file path, or - for stdin")

    subparsers.add_parser("fingerprint", help="print current HEAD or an unborn-tree fingerprint")

    classify = subparsers.add_parser(
        "classify",
        help="mechanical-only risk_triggers check: minimum lane the changed paths (and optional text) justify",
    )
    classify.add_argument("--paths", nargs="+", help="explicit paths to classify instead of the live git diff")
    classify.add_argument("--against", help="git diff against this revision instead of the working tree vs HEAD")
    classify.add_argument("--text", help="free text (e.g. story outcome/commit message) to scan for signal_keywords")
    classify.add_argument("--json", action="store_true", help="emit machine-readable output")
    args = parser.parse_args()

    if args.command == "doctor":
        return run_doctor(offline=args.offline, strict=args.strict, json_output=args.json)
    if args.command == "fingerprint":
        print(tree_fingerprint())
        return 0
    if args.command == "classify":
        if yaml is None:
            print("PyYAML is required", file=sys.stderr)
            return 2
        config = load_yaml(ROOT / ".avc/config.yaml")
        paths = args.paths if args.paths else changed_paths(args.against)
        lane, reasons = classify_paths(config, paths, args.text)
        if args.json:
            print(json.dumps({"lane": lane, "paths": paths, "reasons": reasons}, indent=2))
        else:
            print(f"mechanical minimum lane: {lane}")
            print(f"paths considered ({len(paths)}): {paths}")
            for reason in reasons:
                print(f"  - {reason}")
            print("Note: this never detects semantic confirmed_impacts (e.g. \"changes auth")
            print("enforcement\") — only a Navigator's judgment does. A lane below this")
            print("mechanical minimum is worth a second look, not an automatic block.")
        return 0
    if args.command == "validate-result":
        if yaml is None:
            print("PyYAML is required", file=sys.stderr)
            return 2
        text = sys.stdin.read() if args.path == "-" else Path(args.path).read_text(encoding="utf-8")
        try:
            data = yaml.safe_load(text)
        except Exception as exc:  # noqa: BLE001
            print(f"invalid YAML: {exc}", file=sys.stderr)
            return 1
        errors = validate_agent_result(data)
        if errors:
            print("\n".join(errors), file=sys.stderr)
            return 1
        print("PASS")
        return 0
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
