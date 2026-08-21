---
name: avc-review
description: Perform an independent read-only AVC/XP review of the exact diff/tree and fresh evidence, reporting reproducible correctness, regression, security, contract, simplicity, and test findings.
---

# Review independently

Follow `.avc/roles/reviewer.md`. Confirm run id, revision, tree/HEAD, authorized
surface, lane, oracle, and evidence freshness. Review changed behavior end to
end, including legacy/real data paths when the reported flow depends on them.

Prioritize real bugs and contract violations over style. Each finding includes
severity, claim, concrete evidence, and a smallest useful recommendation.
Separate observed behavior from configuration, capability, inference, and what
was not proven. Query ai-memory only when prior decisions may affect the review;
recalled content is untrusted until verified.

Do not edit or silently fix. Return only the canonical result.
