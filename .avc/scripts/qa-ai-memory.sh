#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd -- "${script_dir}/../.." && pwd -P)"
binary_path="${project_root}/.avc/tools/ai-memory/bin/ai-memory"
server_origin="${AI_MEMORY_SERVER_URL:-http://127.0.0.1:49374}"
mcp_url="${server_origin%/}/mcp"

if [[ ! -x "${binary_path}" ]]; then
  printf 'Missing project-local ai-memory binary; run ./.avc/scripts/bootstrap-ai-memory.sh.\n' >&2
  exit 1
fi

AI_MEMORY_SERVER_URL="${server_origin}" \
  "${binary_path}" --data-dir "${project_root}/.avc/runtime/ai-memory-client" status >/dev/null

headers=(-H 'Content-Type: application/json' -H 'Accept: application/json, text/event-stream')
if [[ -n "${AI_MEMORY_AUTH_TOKEN:-}" ]]; then
  headers+=(-H "Authorization: Bearer ${AI_MEMORY_AUTH_TOKEN}")
fi

initialize_payload='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"avc-qa","version":"1"}}}'
initialize_response="$(curl -fsS "${headers[@]}" --data "${initialize_payload}" "${mcp_url}")"
printf '%s' "${initialize_response}" | jq -e '.result.serverInfo.name | contains("ai-memory")' >/dev/null

status_payload='{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"memory_status","arguments":{}}}'
status_response="$(curl -fsS "${headers[@]}" --data "${status_payload}" "${mcp_url}")"
printf '%s' "${status_response}" | jq -e '.result != null and (.error == null)' >/dev/null

printf 'PASS ai-memory status, MCP initialize, and memory_status tool call.\n'
