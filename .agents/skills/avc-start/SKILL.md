---
name: avc-start
description: Start or reframe one AVC/XP story by capturing a small observable outcome, examples, non-goals, risk lane, scope budget, commands, and next factual signal. Use before implementation when no valid active run exists.
---

# Start an AVC/XP story

Act as the Navigator and read `AGENTS.md`, `.avc/config.yaml`, and the current
`.avc/run.yaml` if present. Query ai-memory for related prior decisions when the
subsystem or task is non-trivial; validate recalled claims against current
instructions and checkout state.

Capture one vertical outcome, why it matters, explicit non-goals, one to three
observable examples, reversibility, the smallest initial allow/deny surface,
and known commands. Classify risk from `.avc/config.yaml: risk_triggers`:
`confirmed_impacts` and a lane's `confirmed_paths` promote a lane on their
own; `signal_keywords` and a lane's `signal_paths` are scouting signals only
(never proof) — a path that only *names* a convention (e.g. `**/auth/**`)
must not by itself force a lane the way a real confirmed impact does. Run
`python3 .avc/bin/avc.py classify` as a mechanical cross-check on the
path/keyword side of this before declaring the lane — it never replaces your
judgment on semantic `confirmed_impacts`, but a floor it reports above what
you're about to declare is worth a second look. Unknown risk is at least
`guarded`. Promotion is autonomous for the Navigator; reduction is
human-only.

Create or amend `.avc/run.yaml` only as Navigator. Keep the oracle `draft`, the
graph to one Scout node, and implementation inactive until baseline, frame, and
oracle gates pass. Do not invent commands, HEAD, acceptance, or human authority.

Return the canonical result from `.avc/templates/agent-result.yaml` and stop
with `BLOCKED` when outcome/acceptance authority cannot be inferred safely.
