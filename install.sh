#!/usr/bin/env bash
set -euo pipefail

template_repo="${AVC_TEMPLATE_REPO:-cezaraf/avc-template}"
template_ref="${AVC_TEMPLATE_REF:-main}"
target_dir="."
project_name=""
harness="auto"
dry_run=0
force=0
start_memory=0
wire_memory=0
temporary_root=""

usage() {
  cat <<'EOF'
Install AVC/XP and ai-memory routing into an existing Git repository.

Usage:
  ./install.sh [options]
  curl -fsSL https://raw.githubusercontent.com/cezaraf/avc-template/main/install.sh | bash -s -- [options]

Options:
  --target PATH       Git repository root to update (default: current directory)
  --project NAME      ai-memory/config project id (default: target basename)
  --harness NAME      auto, generic, codex, claude-code, opencode, or all
  --dry-run           Report planned target writes without changing the target
  --force             Replace conflicting AVC-owned configuration/state
  --start-memory      Bootstrap/reuse the pinned loopback ai-memory service
  --wire-memory       Wire ai-memory globally for claude-code or opencode
  -h, --help          Show this help

The installer never initializes Git, commits, pushes, changes dependencies, or
touches product source. Existing AGENTS.md, CLAUDE.md, and .gitignore content is
preserved outside line-delimited managed blocks.
EOF
}

fail() {
  printf 'avc-template: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [[ -n "${temporary_root}" && -d "${temporary_root}" ]]; then
    rm -R -- "${temporary_root}"
  fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) [[ $# -ge 2 ]] || fail "--target requires a path"; target_dir="$2"; shift 2 ;;
    --project) [[ $# -ge 2 ]] || fail "--project requires a name"; project_name="$2"; shift 2 ;;
    --harness) [[ $# -ge 2 ]] || fail "--harness requires a name"; harness="$2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --force) force=1; shift ;;
    --start-memory) start_memory=1; shift ;;
    --wire-memory) wire_memory=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

case "${harness}" in
  auto|generic|codex|claude-code|opencode|all) ;;
  *) fail "unsupported harness '${harness}'; use auto, generic, codex, claude-code, opencode, or all" ;;
esac

[[ -d "${target_dir}" ]] || fail "target does not exist: ${target_dir}"
target_dir="$(cd -- "${target_dir}" && pwd -P)"
git_root="$(git -C "${target_dir}" rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "${git_root}" ]] || fail "target must already be a Git repository; initialize it explicitly first"
git_root="$(cd -- "${git_root}" && pwd -P)"
[[ "${git_root}" == "${target_dir}" ]] || fail "--target must be the Git repository root (${git_root})"

if [[ -z "${project_name}" ]]; then
  project_name="$(basename -- "${target_dir}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^[^a-z0-9]+//; s/[^a-z0-9]+$//')"
fi
[[ "${project_name}" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || fail "project must match ^[a-z0-9][a-z0-9._-]*$"

script_dir=""
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd -P || true)"
fi

if [[ -n "${script_dir}" && -f "${script_dir}/.avc/config.yaml" && -d "${script_dir}/.agents/skills" ]]; then
  source_root="${script_dir}"
else
  command -v curl >/dev/null 2>&1 || fail "curl is required for remote installation"
  command -v tar >/dev/null 2>&1 || fail "tar is required for remote installation"
  temporary_root="$(mktemp -d /tmp/avc-template-install.XXXXXX)"
  archive="${temporary_root}/template.tar.gz"
  curl -fsSL "https://github.com/${template_repo}/archive/refs/heads/${template_ref}.tar.gz" -o "${archive}"
  tar -xzf "${archive}" -C "${temporary_root}"
  source_root="$(find "${temporary_root}" -mindepth 1 -maxdepth 1 -type d -name 'avc-template-*' -print -quit)"
  [[ -n "${source_root}" && -f "${source_root}/.avc/config.yaml" ]] || fail "downloaded archive does not contain the AVC template"
fi

source_root="$(cd -- "${source_root}" && pwd -P)"
in_place=0
[[ "${source_root}" == "${target_dir}" ]] && in_place=1

if [[ "${harness}" == "auto" ]]; then
  if [[ -d "${target_dir}/.codex" ]]; then
    harness="codex"
  elif [[ -d "${target_dir}/.claude" || -f "${target_dir}/CLAUDE.md" ]]; then
    harness="claude-code"
  elif [[ -d "${target_dir}/.opencode" || -f "${target_dir}/opencode.json" ]]; then
    harness="opencode"
  else
    harness="generic"
  fi
fi

marker_path="${target_dir}/.avc/.installed-by-avc-template"
if [[ -d "${target_dir}/.avc" && ! -f "${marker_path}" && "${in_place}" -eq 0 && "${force}" -eq 0 ]]; then
  fail "target already has an unmanaged .avc directory; inspect it and rerun with --force only if replacement is intended"
fi

plan() {
  if [[ "${dry_run}" -eq 1 ]]; then
    printf 'DRY-RUN %s\n' "$*"
  else
    printf 'AVC %s\n' "$*"
  fi
}

copy_tree() {
  local source_relative="$1"
  local target_relative="$2"
  local source_path="${source_root}/${source_relative}"
  local target_path="${target_dir}/${target_relative}"
  [[ -d "${source_path}" ]] || fail "template directory is missing: ${source_relative}"
  plan "sync ${target_relative}/"
  [[ "${dry_run}" -eq 1 ]] && return
  if [[ "$(cd -- "${source_path}" && pwd -P)" == "$(mkdir -p -- "${target_path}" && cd -- "${target_path}" && pwd -P)" ]]; then
    return
  fi
  cp -R -- "${source_path}/." "${target_path}/"
}

copy_file() {
  local source_relative="$1"
  local target_relative="$2"
  local source_path="${source_root}/${source_relative}"
  local target_path="${target_dir}/${target_relative}"
  [[ -f "${source_path}" ]] || fail "template file is missing: ${source_relative}"
  plan "write ${target_relative}"
  [[ "${dry_run}" -eq 1 ]] && return
  mkdir -p -- "$(dirname -- "${target_path}")"
  if [[ "$(readlink -f -- "${source_path}")" == "$(readlink -f -- "${target_path}" 2>/dev/null || true)" ]]; then
    return
  fi
  cp -- "${source_path}" "${target_path}"
}

merge_block() {
  local target_relative="$1"
  local block_file="$2"
  local start_marker="$3"
  local end_marker="$4"
  local target_path="${target_dir}/${target_relative}"
  plan "merge managed block into ${target_relative}"
  [[ "${dry_run}" -eq 1 ]] && return
  mkdir -p -- "$(dirname -- "${target_path}")"
  if [[ ! -f "${target_path}" ]]; then
    cp -- "${block_file}" "${target_path}"
    printf '\n' >> "${target_path}"
    return
  fi
  local start_count end_count
  start_count="$(grep -Fxc -- "${start_marker}" "${target_path}" || true)"
  end_count="$(grep -Fxc -- "${end_marker}" "${target_path}" || true)"
  if [[ "${start_count}" != "${end_count}" || "${start_count}" -gt 1 ]]; then
    fail "${target_relative} contains malformed or duplicate ${start_marker} markers"
  fi
  local merged
  merged="$(mktemp "${target_path}.tmp.XXXXXX")"
  awk -v start="${start_marker}" -v end="${end_marker}" -v block="${block_file}" '
    function emit_block( line) {
      while ((getline line < block) > 0) print line
      close(block)
    }
    $0 == start {
      if (!replaced) emit_block()
      replaced = 1
      skipping = 1
      next
    }
    skipping {
      if ($0 == end) skipping = 0
      next
    }
    { print }
    END {
      if (!replaced) {
        if (NR > 0) print ""
        emit_block()
      }
    }
  ' "${target_path}" > "${merged}"
  mv -- "${merged}" "${target_path}"
}

copy_tree ".avc/bin" ".avc/bin"
copy_tree ".avc/hooks" ".avc/hooks"
copy_tree ".avc/roles" ".avc/roles"
copy_tree ".avc/scripts" ".avc/scripts"
copy_tree ".avc/ai-memory" ".avc/ai-memory"
copy_tree ".avc/templates" ".avc/templates"
copy_file ".avc/tests/test_avc.py" ".avc/tests/test_avc.py"
copy_tree ".agents/skills" ".agents/skills"
copy_file "AGILE-VIBE-CODING-OS.md" ".avc/docs/AGILE-VIBE-CODING-OS.md"
copy_file "PLATFORM-ADAPTERS.md" ".avc/docs/PLATFORM-ADAPTERS.md"
copy_file "START-HERE.md" ".avc/docs/START-HERE.md"

generated_dir="${temporary_root:-$(mktemp -d /tmp/avc-template-generated.XXXXXX)}"
if [[ -z "${temporary_root}" ]]; then
  temporary_root="${generated_dir}"
fi

if [[ ! -f "${target_dir}/.avc/config.yaml" || "${force}" -eq 1 ]]; then
  generated_config="${generated_dir}/config.yaml"
  awk -v project="${project_name}" '
    $0 == "project:" { in_project = 1; print; next }
    in_project && $0 ~ /^  name:/ { print "  name: " project; in_project = 0; next }
    { print }
  ' "${source_root}/.avc/templates/config.avc.yaml" > "${generated_config}"
  plan "write .avc/config.yaml for ${project_name}"
  if [[ "${dry_run}" -eq 0 ]]; then
    cp -- "${generated_config}" "${target_dir}/.avc/config.yaml"
  fi
else
  plan "preserve existing .avc/config.yaml"
fi

if [[ ! -f "${target_dir}/.avc/run.yaml" || "${force}" -eq 1 ]]; then
  if ! current_head="$(git -C "${target_dir}" rev-parse --verify HEAD 2>/dev/null)"; then
    current_head="UNBORN"
  fi
  generated_run="${generated_dir}/run.yaml"
  sed -e "s/__PROJECT__/${project_name}/g" -e "s/__HEAD__/${current_head}/g" \
    "${source_root}/.avc/templates/run.bootstrap.yaml" > "${generated_run}"
  plan "write bootstrap .avc/run.yaml"
  if [[ "${dry_run}" -eq 0 ]]; then
    cp -- "${generated_run}" "${target_dir}/.avc/run.yaml"
  fi
else
  plan "preserve existing .avc/run.yaml"
fi

if [[ ! -f "${target_dir}/.ai-memory.toml" || "${force}" -eq 1 ]]; then
  generated_memory="${generated_dir}/ai-memory.toml"
  awk -v project="${project_name}" '
    /^project[[:space:]]*=/ { print "project = \"" project "\""; next }
    { print }
  ' "${source_root}/.ai-memory.toml" > "${generated_memory}"
  plan "write .ai-memory.toml for ${project_name}"
  if [[ "${dry_run}" -eq 0 ]]; then
    cp -- "${generated_memory}" "${target_dir}/.ai-memory.toml"
  fi
else
  plan "preserve existing .ai-memory.toml"
fi

ai_memory_block="${generated_dir}/AGENTS.ai-memory.md"
awk '/^<!-- ai-memory:start -->$/,/^<!-- ai-memory:end -->$/' "${source_root}/AGENTS.md" > "${ai_memory_block}"
[[ -s "${ai_memory_block}" ]] || fail "canonical ai-memory AGENTS block is missing"
merge_block "AGENTS.md" "${source_root}/.avc/templates/AGENTS.avc.md" "<!-- avc:start -->" "<!-- avc:end -->"
merge_block "AGENTS.md" "${ai_memory_block}" "<!-- ai-memory:start -->" "<!-- ai-memory:end -->"
merge_block ".gitignore" "${source_root}/.avc/templates/gitignore.avc" "# avc-template:start" "# avc-template:end"

install_codex=0
install_claude=0
install_opencode=0
case "${harness}" in
  codex) install_codex=1 ;;
  claude-code) install_claude=1 ;;
  opencode) install_opencode=1 ;;
  all) install_codex=1; install_claude=1; install_opencode=1 ;;
  generic) ;;
esac

if [[ "${install_codex}" -eq 1 ]]; then
  copy_tree ".codex" ".codex"
fi

if [[ "${install_claude}" -eq 1 ]]; then
  merge_block "CLAUDE.md" "${source_root}/.avc/templates/CLAUDE.launcher.md" "<!-- avc-claude:start -->" "<!-- avc-claude:end -->"
  for skill_dir in "${source_root}/.agents/skills"/*; do
    [[ -d "${skill_dir}" ]] || continue
    skill_name="$(basename -- "${skill_dir}")"
    link_path="${target_dir}/.claude/skills/${skill_name}"
    link_target="../../.agents/skills/${skill_name}"
    plan "link .claude/skills/${skill_name} -> ${link_target}"
    [[ "${dry_run}" -eq 1 ]] && continue
    mkdir -p -- "$(dirname -- "${link_path}")"
    if [[ -L "${link_path}" && "$(readlink -- "${link_path}")" == "${link_target}" ]]; then
      continue
    fi
    if [[ -e "${link_path}" || -L "${link_path}" ]]; then
      [[ "${force}" -eq 1 ]] || fail "Claude skill path already exists: ${link_path}; use --force only after inspection"
      rm -R -- "${link_path}"
    fi
    ln -s -- "${link_target}" "${link_path}"
  done
fi

if [[ "${install_opencode}" -eq 1 ]]; then
  plan "enable OpenCode through AGENTS.md and canonical .agents/skills discovery"
fi

plan "write AVC ownership marker"
if [[ "${dry_run}" -eq 0 ]]; then
  mkdir -p -- "${target_dir}/.avc/evidence"
  : > "${target_dir}/.avc/evidence/.gitkeep"
  cat > "${marker_path}" <<EOF
version=1
source=${template_repo}@${template_ref}
project=${project_name}
harness=${harness}
EOF
  chmod 0755 "${target_dir}/.avc/bin/avc.py" "${target_dir}/.avc/hooks/"*.py "${target_dir}/.avc/scripts/"*.sh
fi

if [[ "${dry_run}" -eq 0 && "${start_memory}" -eq 1 ]]; then
  "${target_dir}/.avc/scripts/bootstrap-ai-memory.sh"
fi

if [[ "${dry_run}" -eq 0 && "${wire_memory}" -eq 1 ]]; then
  [[ "${harness}" != "all" && "${harness}" != "generic" ]] || fail "--wire-memory requires one explicit supported harness"
  if [[ ! -x "${target_dir}/.avc/tools/ai-memory/bin/ai-memory" ]]; then
    "${target_dir}/.avc/scripts/bootstrap-ai-memory.sh"
  fi
  memory_binary="${target_dir}/.avc/tools/ai-memory/bin/ai-memory"
  case "${harness}" in
    codex)
      plan "Codex ai-memory is already project-local in .codex/config.toml and .codex/hooks.json"
      ;;
    claude-code|opencode)
      "${memory_binary}" install-mcp --client "${harness}" --apply
      "${memory_binary}" install-hooks --agent "${harness}" --apply
      ;;
  esac
fi

if [[ "${dry_run}" -eq 1 ]]; then
  printf 'DRY-RUN complete: target was not modified.\n'
else
  printf 'Installed AVC/XP for project %s with harness=%s.\n' "${project_name}" "${harness}"
  printf 'Next: configure product commands, run python3 .avc/bin/avc.py doctor --offline, then use avc-start.\n'
  if [[ "${start_memory}" -eq 0 ]]; then
    printf 'ai-memory files are installed but runtime startup was not requested; run ./.avc/scripts/bootstrap-ai-memory.sh.\n'
  fi
fi
