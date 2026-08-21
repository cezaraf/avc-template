---
name: avc-amend
description: Create an explicit AVC/XP amendment when scope, acceptance, lane, dependency, rollback, risk, or authority must change; use instead of silently drifting the active run.
---

# Amend the active contract

Act as Navigator. State the evidence that invalidated the current assumption,
the exact proposed change, affected acceptance ids/nodes/paths/gates, new risk,
and rollback impact. Preserve the old value and increment the run revision.

Lane promotion may proceed when configured evidence confirms the trigger.
Lane reduction, scope expansion, oracle change after freeze, dependency,
migration, waiver, and external authority require the human decision specified
in `.avc/config.yaml`. Until that decision exists, record the proposal and
return `BLOCKED` or `NEEDS_AMENDMENT` without changing the authorized value.

Invalidate stale evidence and graph nodes after an accepted amendment. Return
the canonical result; never disguise a repair as an amendment.
