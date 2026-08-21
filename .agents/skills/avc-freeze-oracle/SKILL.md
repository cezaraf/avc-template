---
name: avc-freeze-oracle
description: Define and freeze the independent behavioral oracle for an AVC/XP story before Builder work, using executable acceptance where possible and an explicit human witness only when execution cannot express the outcome.
---

# Freeze the behavioral oracle

Follow `.avc/roles/verifier.md`. Work only from the current outcome, examples,
non-goals, lane, and verified baseline. Create the smallest acceptance signal
that fails for the intended reason. Write only configured acceptance paths.

Map every acceptance id to an executable test, contract check, runtime probe,
or explicit human witness. Record the exact command and expected observation.
Freeze only after the signal and its ownership are clear. After freeze, never
weaken or edit it without a human-approved amendment.

Do not implement product behavior. Return the canonical result and request the
Navigator transition only when the oracle is independently reproducible.
