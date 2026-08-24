# Platform adapters

The kernel is tool-agnostic:

- policy and commands: `.avc/config.yaml`;
- operational state: `.avc/run.yaml`;
- role contracts: `.avc/roles/`;
- canonical skills: `.agents/skills/`;
- project facts: `AGENTS.md`.

Adapters provide discovery, model tier, sandbox, tool permissions, and
lifecycle hooks. Do not maintain different workflow semantics per platform.

## Codex

Codex reads `AGENTS.md`, discovers repo skills from `.agents/skills`, and loads
trusted project configuration from `.codex/config.toml`. Define custom project
agents in `.codex/agents/`, lifecycle hooks in `.codex/hooks.json`, and command
policy in `.codex/rules/*.rules`.

Example `.codex/agents/avc-scout.toml`:

```toml
name = "avc_scout"
description = "Read-only AVC/XP scout for mapping the smallest factual code, test, command, and risk surface before implementation."
sandbox_mode = "read-only"
developer_instructions = """
Read .avc/roles/scout.md and follow it as the canonical authority contract.
Require a context capsule with run_id, revision, head, node, outcome, relevant
files, commands, stop conditions, and output schema.
Return only the canonical structured result. Do not edit.
"""
```

Example `.codex/agents/avc-builder.toml`:

```toml
name = "avc_builder"
description = "Single-writer AVC/XP builder for one authorized vertical slice after oracle and scope gates pass."
sandbox_mode = "workspace-write"
developer_instructions = """
Read .avc/roles/builder.md and follow it as the canonical authority contract.
Edit only the active node allowlist. Never edit .avc/run.yaml, policy, roles,
skills, protected paths, or the frozen oracle. Return the canonical result.
"""
```

Example `.codex/agents/avc-verifier.toml`:

```toml
name = "avc_verifier"
description = "Independent AVC/XP verifier that owns the behavioral oracle and validates the current HEAD without fixing production code."
sandbox_mode = "workspace-write"
developer_instructions = """
Read .avc/roles/verifier.md. Writes are limited to configured acceptance paths
before freeze and evidence after freeze. Never edit production code or relax
acceptance. Reject stale HEAD or revision.
"""
```

Example `.codex/agents/avc-reviewer.toml`:

```toml
name = "avc_reviewer"
description = "Read-only independent AVC/XP reviewer focused on correctness, regression, simplicity, security, contracts, and missing tests."
sandbox_mode = "read-only"
developer_instructions = """
Read .avc/roles/reviewer.md. Review the diff and evidence on the exact HEAD.
Return reproducible findings in the canonical schema. Never edit or silently
fix code.
"""
```

Recommended `.codex/config.toml` fragment:

```toml
[agents]
max_concurrent_threads_per_session = 4
```

Map portable hooks to `.codex/hooks.json`:

| Portable event | Codex lifecycle point |
| --- | --- |
| `before_write` | `PreToolUse` |
| `after_write` | `PostToolUse` |
| `after_subagent` | `SubagentStop` |
| `before_compact` | `PreCompact` |
| `before_stop` | `Stop` |
| session bootstrap/resume/finalize | `SessionStart` / `UserPromptSubmit` / `SessionEnd` |

The executable adapter in this repository also declares ai-memory as a
required streamable-HTTP MCP in `.codex/config.toml`. Its read tools are
auto-approved and write tools require approval. Start the pinned loopback
runtime before opening a new task; required MCP startup is intentionally
fail-closed.

Use hooks only after reviewing scripts because repository hooks execute local
code.

Official references:
[subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents),
[skills](https://learn.chatgpt.com/docs/build-skills),
[hooks](https://learn.chatgpt.com/docs/hooks),
[MCP](https://learn.chatgpt.com/docs/extend/mcp), and
[rules](https://learn.chatgpt.com/docs/agent-configuration/rules).

## Claude Code

Create a short `CLAUDE.md`:

```markdown
# AVC/XP launcher

Read and follow `AGENTS.md`. The active story is `.avc/run.yaml`, policy is
`.avc/config.yaml`, and role authority lives in `.avc/roles/`. Load skills on
demand. This launcher selects AVC; do not load documents or skills from the
alternative SDD operating contract.
```

Define agents under `.claude/agents/`.

Example `.claude/agents/avc-scout.md`:

```markdown
---
name: avc-scout
description: Read-only AVC/XP scout for mapping the smallest factual surface before implementation.
tools: Read, Grep, Glob, Bash
---

Read `.avc/roles/scout.md` and follow it as the canonical authority contract.
Require the AVC context capsule. Do not edit. Return the canonical schema.
```

Example `.claude/agents/avc-builder.md`:

```markdown
---
name: avc-builder
description: Single-writer AVC/XP builder for one authorized vertical slice.
tools: Read, Grep, Glob, Edit, Write, Bash
---

Read `.avc/roles/builder.md`. Edit only the active node allowlist. Never edit
state, policy, roles, skills, protected paths, or a frozen oracle.
```

Example `.claude/agents/avc-verifier.md`:

```markdown
---
name: avc-verifier
description: Independent AVC/XP acceptance and live-behavior verifier.
tools: Read, Grep, Glob, Write, Edit, Bash
---

Read `.avc/roles/verifier.md`. Writes are restricted to acceptance paths before
freeze and evidence after freeze. Never fix production code.
```

Example `.claude/agents/avc-reviewer.md`:

```markdown
---
name: avc-reviewer
description: Independent read-only AVC/XP reviewer for correctness, regression, simplicity, security, and tests.
tools: Read, Grep, Glob, Bash
---

Read `.avc/roles/reviewer.md`. Review the diff on the exact HEAD and return the
canonical schema. Do not edit.
```

Claude Code supports a project skill directory at `.claude/skills/` and
follows symlinked skill directories. Keep `.agents/skills` canonical and create
one symlink per skill:

```bash
mkdir -p .claude/skills
ln -s ../../.agents/skills/avc-start .claude/skills/avc-start
```

Generate all symlinks or Windows-compatible wrapper copies during bootstrap;
do not maintain them by hand. A doctor check should compare target/hash and
report drift.

Map portable hooks in `.claude/settings.json`:

| Portable event | Claude Code event |
| --- | --- |
| `before_write` | `PreToolUse` for Edit/Write |
| `after_write` | `PostToolUse` for Edit/Write |
| `after_subagent` | `SubagentStop` |
| `before_compact` | `PreCompact` |
| `before_stop` | `Stop` |
| role lifecycle | agent frontmatter hooks or `SubagentStart/Stop` |

Official references:
[skills](https://code.claude.com/docs/en/skills),
[subagents](https://code.claude.com/docs/en/sub-agents),
[hooks](https://code.claude.com/docs/en/hooks-guide).

## OpenCode

OpenCode reads `AGENTS.md` and directly discovers `.agents/skills`, so no skill
copy is required. Define agents under `.opencode/agents/`.

Example `.opencode/agents/avc-scout.md`:

```markdown
---
description: Read-only AVC/XP scout for mapping the smallest factual surface before implementation.
mode: subagent
permission:
  edit: deny
  bash:
    "*": ask
    "git status*": allow
    "git diff*": allow
    "rg *": allow
---

Read `.avc/roles/scout.md` and follow it as the canonical authority contract.
Do not edit. Return the canonical schema.
```

Example `.opencode/agents/avc-builder.md`:

```markdown
---
description: Single-writer AVC/XP builder for one authorized vertical slice.
mode: subagent
permission:
  edit: allow
  bash:
    "*": ask
---

Read `.avc/roles/builder.md`. Edit only the active node allowlist and return
the canonical schema.
```

Example `.opencode/agents/avc-verifier.md`:

```markdown
---
description: Independent AVC/XP verifier for acceptance and live behavior.
mode: subagent
permission:
  edit: ask
  bash:
    "*": ask
---

Read `.avc/roles/verifier.md`. Restrict writes to acceptance/evidence paths.
Never edit production code.
```

Example `.opencode/agents/avc-reviewer.md`:

```markdown
---
description: Independent read-only AVC/XP reviewer for correctness, regression, simplicity, security, and tests.
mode: subagent
permission:
  edit: deny
  bash:
    "*": ask
    "git status*": allow
    "git diff*": allow
    "git log*": allow
    "rg *": allow
---

Read `.avc/roles/reviewer.md`. Review the exact HEAD; do not edit.
```

Optional command mapping in `opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "command": {
    "avc-review": {
      "description": "Run independent AVC/XP review",
      "agent": "avc-reviewer",
      "subtask": true,
      "template": "Load the avc-review skill and review the active .avc/run.yaml on the current HEAD."
    }
  }
}
```

Use a local OpenCode plugin only for lifecycle enforcement that cannot be
expressed through permissions, scripts, or CI.

Official references:
[skills](https://opencode.ai/docs/skills/),
[agents](https://opencode.ai/docs/agents/),
[commands](https://opencode.ai/docs/commands/),
[rules](https://opencode.ai/docs/rules/).

## Invocation

| Intent | Codex | Claude Code | OpenCode |
| --- | --- | --- | --- |
| Start | `$avc-start` | `/avc-start` | ask agent to load `avc-start` |
| Scout | `$avc-scout` | `/avc-scout` | load `avc-scout` or dispatch agent |
| Build | `$avc-build-slice` | `/avc-build-slice` | load skill/dispatch Builder |
| Verify | `$avc-verify` | `/avc-verify` | load skill/dispatch Verifier |
| Review | `$avc-review` | `/avc-review` | `/avc-review` if command configured |

Implicit skill selection is convenient; explicit invocation is preferable
while evaluating the framework so run boundaries and metrics remain clear.

## Adapter invariants

- Adapter files never redefine the workflow.
- Every adapter points to the canonical role contract.
- Model names and reasoning tiers remain environment configuration.
- A generated adapter includes source hash/version.
- `avc doctor` detects missing files, stale links/copies, excessive authority,
  unknown commands, and unsupported hooks.
- CI remains the final cross-platform enforcement point.
