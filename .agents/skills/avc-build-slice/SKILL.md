---
name: avc-build-slice
description: Implement one authorized AVC/XP vertical node as the single Builder using focused red-green-refactor feedback. Use only after doctor, frame, and frozen-oracle gates pass.
---

# Build one vertical slice

Follow `.avc/roles/builder.md`. Verify run id, revision, tree/HEAD, active node,
authorized paths, oracle status, command, and stop condition before editing.
If any differs from the dispatch capsule, return `BLOCKED`.

Work one hypothesis at a time:

1. reproduce or create the smallest relevant red signal;
2. make the smallest coherent change inside the node allowlist;
3. run the most focused useful check;
4. inspect output and changed paths;
5. refactor only while green;
6. run the node checkpoint gate.

Never edit state, protected files, policy, adapters, or frozen acceptance. New
scope, dependency, migration, risk, or changed acceptance is an amendment, not
an implementation detail. Stop after two repair attempts without new evidence.
Return exact paths/commands in the canonical result; never self-approve.
