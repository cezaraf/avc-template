# Start here

This repository is both the reference and an executable, risk-adaptive Agile
Vibe Coding starter. Codex governance is project-local and cross-session
continuity is provided by a pinned ai-memory runtime.

For installation into another repository, start with `README.md` and
`./install.sh --help`. The installer keeps the `.avc` kernel canonical and
selects only the requested harness adapters.

## Read in this order

1. `AGILE-VIBE-CODING-OS.md` — rationale, operating model, risk lanes, XP
   mapping, state, graph, gates, authority, playbooks, metrics, migration, and
   rollout.
2. `AGENTS.md` — active project instructions and ai-memory routing.
3. `.avc/config.yaml` — commands, lanes, risk triggers, budgets, and
   authority. A fresh install generates it from `.avc/templates/config.avc.yaml`,
   not from this repository's own `.avc/config.yaml` (which is correct only
   for validating avc-template's own kernel installation).
4. `.avc/run.yaml` — the single active operational state; a fresh install
   generates it from `.avc/templates/run.bootstrap.yaml` (`.avc/run.example.yaml`
   at the root is a longer, hand-annotated reference for the same shape, not
   what the installer copies).
5. `.avc/roles/` — five canonical authority contracts.
6. `.agents/skills/` — ten AVC workflows plus ai-memory's managed routing
   skills.
7. `.codex/` — the executable Codex adapter: config, agents, hooks, rules, and
   required MCP.
8. `PLATFORM-ADAPTERS.md` — Codex, Claude Code, and OpenCode mappings.

The root `config.yaml` and `run.example.yaml` are inert reference examples, not
what a fresh install writes. `install.sh` writes a target's `.avc/config.yaml`
and `.avc/run.yaml` from `.avc/templates/config.avc.yaml` and
`.avc/templates/run.bootstrap.yaml` respectively; both live under `.avc/templates/`
alongside the installer's other product templates.

## Bootstrap this repository

Prerequisites are Git, Python 3 with PyYAML, Docker Compose, `curl`, and `jq`.

1. Run `./.avc/scripts/bootstrap-ai-memory.sh`. It installs the pinned binary
   under ignored project runtime state and starts the loopback-only container.
2. Run `./.avc/scripts/ci.sh` for structural and policy checks.
3. Run `./.avc/scripts/qa-ai-memory.sh` for live MCP acceptance.
4. Start a new Codex task from this repository so `.codex/config.toml`, hooks,
   rules, project agents, skills, and the required MCP are reloaded.
5. Run `python3 .avc/bin/avc.py doctor` whenever local setup changes.

Do not commit, push, create a PR, merge, deploy, add dependencies, or alter
acceptance without the authority declared in `.avc/config.yaml`.

## Copying the starter into another project

Copy `AGENTS.md`, `.avc/`, `.agents/`, `.codex/`, `.ai-memory.toml`, and the
relevant adapter documentation into a branch or worktree. Then replace project
identity, commands, risk paths, acceptance, and the active run before building.
Start with the core AVC skills. This template selects AVC as the exclusive
operating contract; `governed` remains a native AVC lane and never invokes SDD.
Choose SDD only as a separate human-selected workflow after closing or
abandoning the active AVC run. The ai-memory project marker must be unique to
the destination.

## Core rule

Completeness is coverage of failure modes, not mandatory ceremony. If an
artifact, agent, skill, or report does not change a decision or enforce an
invariant, remove it from the default path.
