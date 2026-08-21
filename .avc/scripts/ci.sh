#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd -- "${script_dir}/../.." && pwd -P)"
cd -- "${project_root}"

bash -n .avc/scripts/*.sh
python3 -m compileall -q .avc/bin .avc/hooks .avc/tests
python3 -m unittest discover -s .avc/tests -p 'test_*.py'
python3 .avc/bin/avc.py doctor --offline

if [[ -f .codex/rules/avc.rules ]] && command -v codex >/dev/null 2>&1; then
  codex execpolicy check --rules .codex/rules/avc.rules -- git push origin main >/dev/null
  codex execpolicy check --rules .codex/rules/avc.rules -- git reset --hard HEAD >/dev/null
else
  printf 'SKIP Codex execpolicy checks (adapter or codex CLI not installed).\n'
fi

printf 'PASS AVC focused CI\n'
