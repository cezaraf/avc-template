---
name: avc-live-qa
description: Validate an AVC/XP outcome through the real consumer surface such as UI, API, CLI, MCP, preview, or deployed runtime, preserving separate evidence from local tests and CI.
---

# Run live QA

Act as Verifier. Identify the consumer surface, environment, authentication,
seed/legacy data, observable states, and required artifacts from the active run.
Run the configured `live_qa` command or the narrowest equivalent already
authorized by policy.

For UI, check loading, error, empty, success, navigation, console, and network
when applicable. For API/CLI/MCP, invoke the real handler or protocol and inspect
the actual response. Do not infer runtime success from build output.

Do not mutate production data or broaden authority. Record environment and
artifacts separately from focused tests and CI. Return the canonical result.
