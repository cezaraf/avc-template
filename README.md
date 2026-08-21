# AVC Template

AVC Template is a harness-agnostic operating kernel for AI-assisted software
development. It combines small vertical slices, executable acceptance,
independent verification, risk-adaptive governance, and project-scoped
[ai-memory](https://github.com/akitaonrails/ai-memory) continuity.

The workflow contract is portable. Harness-specific files are adapters, not
separate versions of the process.

## Install into an existing project

The target must already be the root of a Git repository.

```bash
curl -fsSL https://raw.githubusercontent.com/cezaraf/avc-template/main/install.sh \
  | bash -s -- --target . --harness auto
```

The safe default installs files only. To also start or reuse the pinned local
ai-memory service:

```bash
curl -fsSL https://raw.githubusercontent.com/cezaraf/avc-template/main/install.sh \
  | bash -s -- --target . --harness auto --start-memory
```

Review first with a no-write preview:

```bash
curl -fsSL https://raw.githubusercontent.com/cezaraf/avc-template/main/install.sh \
  | bash -s -- --target . --harness all --dry-run
```

## Supported harnesses

| `--harness` | Installed adapter |
| --- | --- |
| `auto` | Detects project-local harness files; falls back to `generic` |
| `generic` | `AGENTS.md`, `.agents/skills`, AVC kernel, and ai-memory routing |
| `codex` | Generic kernel plus project-local `.codex` MCP, hooks, rules, and agents |
| `claude-code` | Generic kernel plus `CLAUDE.md` and `.claude/skills` links |
| `opencode` | Generic kernel; OpenCode discovers `AGENTS.md` and `.agents/skills` directly |
| `all` | Installs every non-conflicting adapter above |

“Harness-agnostic” means that state, authority, roles, skills, evidence, and
risk policy remain canonical under `.avc` and `.agents`. A harness that can read
repository instructions and Agent Skills can use the generic adapter. Native
lifecycle hooks and MCP wiring still depend on capabilities exposed by each
harness.

## Use as a GitHub template

After creating a repository through GitHub's **Use this template** action,
clone it and replace the distribution's own bootstrap state:

```bash
./install.sh --target . --harness all --force
```

`--force` is appropriate in this specific case because the copied `.avc`
directory belongs to AVC Template. In an unrelated existing project, inspect
conflicts before using it.

## Installer behavior

```text
./install.sh [--target PATH]
             [--project NAME]
             [--harness auto|generic|codex|claude-code|opencode|all]
             [--dry-run] [--force] [--start-memory] [--wire-memory]
```

The installer:

- refuses targets that are not exact Git repository roots;
- never initializes Git, changes dependencies, commits, pushes, or edits
  product source;
- preserves existing `AGENTS.md`, `CLAUDE.md`, and `.gitignore` content outside
  line-delimited managed blocks;
- is idempotent for its managed blocks and canonical skills;
- refuses an unmanaged existing `.avc` directory unless `--force` is explicit;
- preserves existing `.avc/config.yaml`, `.avc/run.yaml`, and
  `.ai-memory.toml` on ordinary re-runs;
- scopes generated config and memory markers to `--project`;
- keeps runtime binaries, memory client state, and evidence out of Git.

For Claude Code or OpenCode, `--wire-memory` explicitly applies ai-memory's
native client configuration and hooks. It modifies that harness's user
configuration, so it is never implied by a normal install. Codex wiring is
project-local and ships with its adapter.

## What is installed

```text
AGENTS.md                         managed AVC + ai-memory instruction blocks
.ai-memory.toml                  stable project identity and capture exclusions
.avc/config.yaml                 commands, lanes, risk, authority, evidence
.avc/run.yaml                    one active operational story
.avc/roles/                      Navigator, Scout, Builder, Verifier, Reviewer
.avc/bin/avc.py                  doctor, fingerprint, result validation
.avc/hooks/                      scope, lifecycle, and ai-memory adapters
.avc/scripts/                    CI, ai-memory bootstrap, live MCP QA
.avc/templates/                  portable contracts and launchers
.agents/skills/                  ten AVC skills + five managed ai-memory skills
.codex/                          optional Codex adapter
.claude/                         optional Claude Code skill links
```

Narrative rationale and platform mappings are installed under `.avc/docs/`.

## After installation

Install prerequisites and validate the kernel:

```bash
./.avc/scripts/bootstrap-ai-memory.sh
python3 .avc/bin/avc.py doctor
./.avc/scripts/ci.sh
./.avc/scripts/qa-ai-memory.sh
```

Then configure product-specific commands in `.avc/config.yaml` and replace the
blocked bootstrap story through `avc-start`. The usual sequence is:

```text
avc-start → avc-scout → avc-freeze-oracle → avc-build-slice
          → avc-verify → avc-review → human acceptance
```

Risk can promote the lane automatically. Scope expansion, lane reduction,
frozen-oracle changes, dependencies, migrations, gate waivers, and external
effects remain subject to the authority declared in the project.

## Requirements

- Bash, Git, Python 3, and PyYAML;
- `curl` and `tar` for remote installation;
- Docker Compose, `curl`, and `jq` for the bundled ai-memory runtime and live
  QA;
- the selected AI harness only when its native adapter is requested.

The ai-memory runtime is pinned to v1.29.0 and loopback by default. Retrieved
memory is historical data, never executable authority. Assistant final-turn
capture is disabled, and capture exclusions drop recognized sensitive file
operations before spool or network transport.

## Development

```bash
./.avc/scripts/ci.sh
python3 .avc/bin/avc.py doctor
./.avc/scripts/qa-ai-memory.sh
```

The active development contract is [.avc/run.yaml](.avc/run.yaml). Design
rationale lives in [AGILE-VIBE-CODING-OS.md](AGILE-VIBE-CODING-OS.md), and
adapter details live in [PLATFORM-ADAPTERS.md](PLATFORM-ADAPTERS.md).

## License

[MIT](LICENSE)
