---
name: avc-verify
description: Independently verify an AVC/XP node or story on the exact current tree, producing fresh executable evidence without fixing production code or accepting the outcome for the human.
---

# Verify current behavior

Follow `.avc/roles/verifier.md`. Re-read the run revision, current tree/HEAD,
frozen oracle, lane gates, and evidence invalidation policy. Reject stale input.

Run focused, affected, acceptance, and required live-runtime checks in the
order that minimizes cost while preserving the lane. For UI/MCP/runtime claims,
observe the actual consumer surface; compilation alone is not proof. Record
argv, cwd, timestamps/duration, exit code, environment, and artifacts under
`.avc/evidence/**` only.

Do not repair failures. Return `FAIL` for observed product failure, `BLOCKED`
for unavailable environment/authority, and `NEEDS_AMENDMENT` for changed scope
or acceptance. Human acceptance remains separate.
