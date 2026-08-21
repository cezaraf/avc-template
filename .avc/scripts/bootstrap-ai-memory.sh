#!/usr/bin/env bash
set -euo pipefail

AI_MEMORY_VERSION="1.29.0"
AI_MEMORY_RELEASE="v${AI_MEMORY_VERSION}"
AI_MEMORY_BASE_URL="https://github.com/akitaonrails/ai-memory/releases/download/${AI_MEMORY_RELEASE}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd -- "${script_dir}/../.." && pwd -P)"
install_dir="${project_root}/.avc/tools/ai-memory/bin"
binary_path="${install_dir}/ai-memory"
client_data_dir="${project_root}/.avc/runtime/ai-memory-client"
server_url="${AI_MEMORY_SERVER_URL:-http://127.0.0.1:49374}"
project_name="$(sed -nE 's/^project[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' "${project_root}/.ai-memory.toml" | head -n 1)"
project_name="${project_name:-$(basename -- "${project_root}")}"

case "$(uname -m)" in
  x86_64|amd64) asset="ai-memory-linux-x86_64.tar.gz" ;;
  aarch64|arm64) asset="ai-memory-linux-aarch64.tar.gz" ;;
  *) printf 'Unsupported architecture: %s\n' "$(uname -m)" >&2; exit 2 ;;
esac

if [[ ! -x "${binary_path}" ]] || [[ "$("${binary_path}" --version 2>/dev/null || true)" != "ai-memory ${AI_MEMORY_VERSION}" ]]; then
  download_dir="$(mktemp -d /tmp/avc-ai-memory-install.XXXXXX)"
  trap 'rm -rf -- "${download_dir}"' EXIT
  curl -fsSL "${AI_MEMORY_BASE_URL}/${asset}" -o "${download_dir}/${asset}"
  curl -fsSL "${AI_MEMORY_BASE_URL}/${asset}.sha256" -o "${download_dir}/${asset}.sha256"
  (
    cd -- "${download_dir}"
    sha256sum -c "${asset}.sha256"
  )
  tar -xzf "${download_dir}/${asset}" -C "${download_dir}"
  mkdir -p -- "${install_dir}"
  install -m 0755 "${download_dir}/ai-memory" "${binary_path}"
  rm -rf -- "${download_dir}"
  trap - EXIT
fi

mkdir -p -- "${client_data_dir}"
chmod 0700 "${project_root}/.avc/runtime" "${client_data_dir}"

# Preserve a compatible shared/local service already bound to the canonical
# endpoint. Project scoping is provided by .ai-memory.toml; do not replace or
# split an existing persistent store merely because this repository has a
# fallback compose definition.
if AI_MEMORY_SERVER_URL="${server_url}" \
  "${binary_path}" --data-dir "${client_data_dir}" status >/dev/null 2>&1; then
  server_version="$(curl -fsS "${server_url%/}/admin/status" | jq -r '.version // empty')"
  if [[ "${server_version}" != "${AI_MEMORY_VERSION}" ]]; then
    printf 'ai-memory at %s reports version %s; expected %s. Refusing to reuse it.\n' \
      "${server_url}" "${server_version:-unknown}" "${AI_MEMORY_VERSION}" >&2
    exit 1
  fi
  printf 'ai-memory %s is already ready at %s; preserving the existing service and data.\n' \
    "${AI_MEMORY_VERSION}" "${server_url}"
  exit 0
fi

docker compose -p avc-ai-memory -f "${project_root}/.avc/ai-memory/compose.yaml" up -d

for _attempt in {1..20}; do
  if AI_MEMORY_SERVER_URL="${server_url}" \
    "${binary_path}" --data-dir "${client_data_dir}" status >/dev/null 2>&1; then
    printf 'ai-memory %s is ready at %s for project %s.\n' \
      "${AI_MEMORY_VERSION}" "${server_url}" "${project_name}"
    exit 0
  fi
  sleep 1
done

printf 'ai-memory did not become healthy within 20 seconds.\n' >&2
docker compose -p avc-ai-memory -f "${project_root}/.avc/ai-memory/compose.yaml" ps >&2
exit 1
