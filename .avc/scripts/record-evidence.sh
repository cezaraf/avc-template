#!/usr/bin/env bash
# Run a command, capture argv/exit_code/duration_ms, and write an
# evidence.json-shaped file (see .avc/templates/evidence.json). Ships as a
# canonical helper so builders don't hand-roll evidence timing themselves.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  record-evidence.sh --run-id ID --node NODE --head HEAD --out PATH [--agent NAME] -- CMD [ARGS...]
  record-evidence.sh --selftest

Writes an evidence.json-shaped file to --out with run_id, node, head, command,
cwd, started_at/finished_at (UTC, ISO 8601), duration_ms, exit_code, and
environment. Evidence is always written, whether the wrapped command passed
or failed. This script's own exit code IS the wrapped command's exit code
(so it composes with && / set -e as expected) — the same value is also in
the written file's "exit_code" field.
EOF
}

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"
}

json_escape_array() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1:]))' "$@"
}

# Prints "<epoch_ms>\t<iso8601_with_millis>Z" from one `date` call.
# NOTE: `%3N` (truncate-to-3-digits) is not reliable across `date`
# implementations — some return full 9-digit nanoseconds regardless of the
# numeric prefix. Always request plain `%N` and divide explicitly; force
# base-10 (`10#$n`) since a zero-padded nanosecond string is otherwise
# misread as an invalid octal literal in bash arithmetic.
now_ms_iso() {
  local raw s n hms ms
  raw="$(date -u +'%s %N %Y-%m-%dT%H:%M:%S')"
  s="${raw%% *}"; raw="${raw#* }"
  n="${raw%% *}"; hms="${raw#* }"
  ms=$(( s * 1000 + 10#${n} / 1000000 ))
  printf '%s\t%s.%03dZ\n' "${ms}" "${hms}" $((10#${n} / 1000000))
}

selftest() {
  local t0 t1 dur
  t0="$(now_ms_iso | cut -f1)"
  sleep 0.2
  t1="$(now_ms_iso | cut -f1)"
  dur=$((t1 - t0))
  if (( dur < 150 || dur > 2000 )); then
    echo "FAIL selftest: expected duration_ms in [150,2000] for a 200ms sleep, got ${dur}" >&2
    exit 1
  fi
  echo "PASS selftest: duration_ms=${dur} for a 200ms sleep"
  exit 0
}

run_id=""
node=""
head=""
out=""
agent="null"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --selftest) selftest ;;
    --run-id) run_id="$2"; shift 2 ;;
    --node) node="$2"; shift 2 ;;
    --head) head="$2"; shift 2 ;;
    --out) out="$2"; shift 2 ;;
    --agent) agent="$(json_escape "$2")"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "${run_id}" && -n "${node}" && -n "${head}" && -n "${out}" ]] || { usage >&2; exit 2; }
[[ $# -gt 0 ]] || { echo "no command given after --" >&2; usage >&2; exit 2; }

cwd="$(pwd -P)"
IFS=$'\t' read -r t0 started_at < <(now_ms_iso)

set +e
"$@"
exit_code=$?
set -e

IFS=$'\t' read -r t1 finished_at < <(now_ms_iso)
duration_ms=$((t1 - t0))

mkdir -p "$(dirname -- "${out}")"
{
  printf '{\n'
  printf '  "run_id": %s,\n' "$(json_escape "${run_id}")"
  printf '  "node": %s,\n' "$(json_escape "${node}")"
  printf '  "head": %s,\n' "$(json_escape "${head}")"
  printf '  "command": %s,\n' "$(json_escape_array "$@")"
  printf '  "cwd": %s,\n' "$(json_escape "${cwd}")"
  printf '  "started_at": %s,\n' "$(json_escape "${started_at}")"
  printf '  "finished_at": %s,\n' "$(json_escape "${finished_at}")"
  printf '  "duration_ms": %d,\n' "${duration_ms}"
  printf '  "exit_code": %d,\n' "${exit_code}"
  printf '  "environment": null,\n'
  printf '  "artifacts": [],\n'
  printf '  "agent": %s\n' "${agent}"
  printf '}\n'
} > "${out}"

echo "wrote ${out} (exit_code=${exit_code} duration_ms=${duration_ms})"
exit "${exit_code}"
