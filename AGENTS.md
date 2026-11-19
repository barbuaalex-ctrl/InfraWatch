# InfraWatch working rules

- The user explicitly normalized the development baseline to v0.9.0 for app and agent. The earlier 4.2.1/4.2.2/4.3.0 agent labels were arbitrary and are retired. Future agent increments start from 0.9.0 (0.9.1, etc.); do not restore the retired numbering.

- Work on the standalone application here. DevOps/cloud changes require a separate user request.
- Every user-visible agent change or agent packaging change must increment `app/agent/version.json` in that same logical change. Use a PATCH bump for fixes and small improvements, MINOR for new features, MAJOR for incompatible changes. Never reuse a previously delivered agent version for changed agent contents.
- `app/agent/version.json` is the single source for the agent version; keep the agent title, download page, ZIP filename and embedded version consistent.
- All agent ZIPs must contain one top-level folder named `InfraWatch-Agent`, with the agent files inside it.
- Preserve existing config.json and connection.json when updating installed agents; do not discard device pairing or stored user data.
- The user rejected the separate public homepage/publication UI. Keep the original dashboard at `/` with login/logout; no public status page, publishing controls or separate admin landing page. Internal API authentication remains until explicitly approved otherwise; the automatic approval reviewer blocked removing those protections during the revert.
