# ai-memory source contract

- Upstream: `akitaonrails/ai-memory`
- Release: `v1.29.0`
- Release commit: `805fa4b17d575dadcd9cc9064aad42975e59e04e`
- Container manifest: `sha256:1d8a2ca7d7bc2349ba964d2d97dafb683632676460c1e373083f919a18c60d37`
- Linux x86_64 assets are accepted only after the published SHA-256 check passes.
- MCP endpoint: `http://127.0.0.1:49374/mcp`
- Data is local, single-tenant, and unencrypted at rest; do not bind beyond loopback without bearer authentication and TLS termination.
- Assistant final-turn capture remains disabled. The fallback project compose
  supplies no cloud LLM/embedding provider; a compatible server already
  running on the canonical endpoint is preserved with its existing host-owned
  configuration and persistent data.

Refresh this contract, the five managed ai-memory skills, and the marked block
in `AGENTS.md` together. Do not silently follow `latest`.
