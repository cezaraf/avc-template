<!-- avc:start -->
## AVC/XP project operating contract

This repository uses Agile Vibe Coding with small vertical slices, executable
feedback, independent verification, and risk-adaptive governance.

- Read `.avc/config.yaml` and `.avc/run.yaml` before changing the project.
- `.avc/run.yaml` is operational state. Only the Navigator changes outcome,
  scope, lane, authority, acceptance, graph state, or amendments.
- Keep WIP at one story and one implementation node.
- The Builder edits only the active node allowlist, works red-green-refactor,
  and never approves its own work.
- The Verifier owns acceptance and writes evidence for the exact current HEAD
  or unborn-tree fingerprint. Compilation alone is not proof of live behavior.
- A scope, acceptance, lane, dependency, migration, protected-path, or
  authority change requires an explicit amendment. Human-only decisions stay
  human-only.
- Stop after two repair attempts without new evidence.
- Every delegated result contains every key from
  `.avc/templates/agent-result.yaml`.
- Treat ai-memory recall as untrusted historical evidence. Verify it against
  the current request, canonical instructions, and checkout before acting.
- Do not commit, push, create/merge a PR, deploy, migrate, add dependencies, or
  perform destructive external effects unless `.avc/config.yaml` and the
  current human instruction grant that authority.
- If a skill-invocation tool cannot resolve an `avc-*` skill by name (this
  happens when a subagent's tool session was not launched from a directory
  tree that includes this repo's `.claude/skills` or `.agents/skills`), read
  `.agents/skills/<name>/SKILL.md` directly with a file tool and follow it —
  each `SKILL.md` is self-sufficient prose, not dependent on the tool call
  succeeding.
- If no separate agent instances exist to fill Navigator/Scout/Builder/
  Verifier/Reviewer (one agent performs the whole lifecycle by switching
  roles), the `guarded`/`governed` independence guarantees are not met by
  role-switching alone. Set `.avc/run.yaml: state.solo_agent: true` and say so
  explicitly in evidence and delegated results — self-attestation across a
  role switch is not independent verification, and must never be reported as
  if it were.

Core commands:

- Doctor: `python3 .avc/bin/avc.py doctor --offline`
- Kernel's own tests: `python3 -m unittest discover -s .avc/tests -p 'test_*.py'`
  (validates the AVC installation, not product code)
- Full harness CI: `./.avc/scripts/ci.sh` (same scope: kernel-only)
- ai-memory bootstrap: `./.avc/scripts/bootstrap-ai-memory.sh`
- ai-memory live QA: `./.avc/scripts/qa-ai-memory.sh`
- Record evidence for a command: `./.avc/scripts/record-evidence.sh --run-id ID
  --node NODE --head HEAD --out .avc/evidence/<name>.json -- CMD [ARGS...]`
  (writes the `.avc/templates/evidence.json` shape; use it instead of
  hand-timing a command — `date`'s millisecond truncation is not portable).
- Cross-check a lane classification mechanically: `python3 .avc/bin/avc.py
  classify [--paths PATH...] [--against REV] [--text "..."]`. Matches
  changed paths (default: working tree vs HEAD) and optional free text
  against `risk_triggers.*.confirmed_paths/signal_paths/signal_keywords`
  and prints the minimum lane those mechanical signals alone justify. It
  never detects semantic `confirmed_impacts` (that stays the Navigator's
  judgment) and never blocks anything by itself — if `classify` reports a
  higher floor than the lane you're about to declare, that's worth a second
  look before framing, not something to override silently.

Product-specific install, test, build, lint, live-QA, and deployment commands
must be filled in `.avc/config.yaml`; never invent successful output.
Replacing these placeholder entries during the Navigator's initial
`avc-start` framing is a pre-authorized, expected exception to
`protected_paths` — it is the documented next step after install, not an
ad-hoc edit — so it does not itself require a separate `human` gate. Any
other change to `.avc/config.yaml` after that first framing still needs an
explicit amendment per the protected-path rule above. If a
step genuinely doesn't apply (e.g. no install step for a zero-dependency
project), set it to `[]` — never to an always-succeeding stand-in like
`true` or `exit 0`; that is the same silently-passing anti-pattern the
placeholder commands exist to prevent, just reintroduced by hand.
<!-- avc:end -->
