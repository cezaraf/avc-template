#!/usr/bin/env python3
"""Project-local adapter from Codex hook payloads to ai-memory's native hook CLI."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys


def find_root(cwd: str | None) -> Path:
    start = Path(cwd).resolve() if cwd else Path.cwd().resolve()
    for candidate in (start, *start.parents):
        if (candidate / ".avc/config.yaml").is_file():
            return candidate
    return Path(__file__).resolve().parents[2]


def context_warning(event: str, message: str) -> dict[str, object]:
    if event in {"session-start", "subagent-start"}:
        hook_name = "SessionStart" if event == "session-start" else "SubagentStart"
        return {
            "hookSpecificOutput": {
                "hookEventName": hook_name,
                "additionalContext": message,
            }
        }
    return {}


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: ai_memory_hook.py <canonical-event>", file=sys.stderr)
        return 2
    event = sys.argv[1]
    raw = sys.stdin.buffer.read()
    try:
        payload = json.loads(raw or b"{}")
    except json.JSONDecodeError:
        payload = {}
    root = find_root(payload.get("cwd") if isinstance(payload, dict) else None)
    binary = root / ".avc/tools/ai-memory/bin/ai-memory"
    if not binary.is_file():
        print(json.dumps(context_warning(event, "ai-memory is required but its project-local binary is missing. Run ./.avc/scripts/bootstrap-ai-memory.sh, then restart Codex.")))
        return 0

    data_dir = root / ".avc/runtime/ai-memory-client"
    data_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    server_url = os.environ.get("AI_MEMORY_SERVER_URL", "http://127.0.0.1:49374")
    command = [
        str(binary),
        "--data-dir",
        str(data_dir),
        "hook",
        "--event",
        event,
        "--agent",
        "codex",
        "--server-url",
        server_url,
    ]
    try:
        result = subprocess.run(
            command,
            input=raw,
            check=False,
            capture_output=True,
            timeout=20,
            env=os.environ.copy(),
        )
    except (OSError, subprocess.TimeoutExpired):
        print(json.dumps(context_warning(event, "ai-memory lifecycle capture failed locally; run ./.avc/scripts/qa-ai-memory.sh before continuing work that depends on memory.")))
        return 0

    if result.returncode != 0:
        print(json.dumps(context_warning(event, "ai-memory lifecycle capture returned a failure; run ./.avc/scripts/qa-ai-memory.sh and inspect only sanitized diagnostics.")))
        return 0
    output = result.stdout.decode("utf-8", errors="replace").strip()
    print(output if output else "{}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
