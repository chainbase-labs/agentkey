# Security Policy

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, email `support@chainbase.com` with:

- A description of the issue
- Steps to reproduce
- Potential impact
- Any suggested mitigation

We will acknowledge your report within 72 hours and keep you informed of the fix timeline.

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x     | ✅        |
| < 1.0   | ❌        |

Pre-1.0 releases are no longer maintained. Please upgrade to the latest 1.x release.

## Disclosure

We follow coordinated disclosure. Once a fix is available, we publish a security advisory via GitHub Security Advisories and credit the reporter (with permission).

## Security Posture

### What this skill does on your machine

The skill ships two helper scripts that the agent invokes:

- **`skills/agentkey/scripts/check-update.sh`** — **notify-only**. At most every 60 minutes (12 hours once an upgrade is known), it calls `https://api.github.com/repos/chainbase-labs/agentkey/releases/latest`, compares the tag against a version constant embedded in the script itself (synced at release time by release-please via `extra-files`), and prints `UPGRADE_AVAILABLE <old> <new>` if they differ. The script does **no** filesystem traversal — there is no `dirname`/`..` path resolution, no read of `version.txt`, no dependency on `CLAUDE_PLUGIN_ROOT`. It also honors a snooze file (`~/.config/agentkey/update-snoozed`, escalating 24h/48h/7d backoff) and a disable file (`~/.config/agentkey/update-disabled`); both are read-only from this script's perspective. The script never runs `git`, never writes to anything except its TMPDIR cache, and never executes downloaded code.

  When the agent sees `UPGRADE_AVAILABLE` it surfaces an `AskUserQuestion` prompt (Yes / Always / Not now / Never). The actual update — `npx skills update agentkey` — runs only after the user picks "Yes" or "Always", or if the user has previously opted into auto-upgrade via `AGENTKEY_AUTO_UPGRADE=1` or `~/.config/agentkey/auto-upgrade`. The agent invokes that command via its own Bash tool, not via this script.
- **`skills/agentkey/scripts/check-mcp.sh`** — reads `~/.claude.json` and `~/.env.local` to verify the AgentKey MCP server is registered and the API key is present. **Read-only**; no network egress; output is a single status code.

### Files the skill reads or writes

| Path | Mode | Purpose |
|---|---|---|
| `~/.claude.json` | read | Detect MCP registration; read `AGENTKEY_API_KEY` env value |
| `~/.env.local` | read | Fallback location for `AGENTKEY_API_KEY` |
| `${TMPDIR}/agentkey-update-check` | read/write | Cache for the update check |
| `~/.config/agentkey/auto-upgrade` | written by the agent on user's "Always keep me up to date" choice; read by Step 0 to skip the prompt | Persistent auto-upgrade opt-in |
| `~/.config/agentkey/update-snoozed` | written by the agent on user's "Not now" choice; read by `check-update.sh` to suppress reminders | Snooze state (`<version> <level> <epoch>`) |
| `~/.config/agentkey/update-disabled` | written by the agent on user's "Never ask again" choice; read by `check-update.sh` to exit silently | Permanent disable for update checks |
| `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS) / `%APPDATA%/Claude/...` (Windows) | written by the separate `npx -y @agentkey/cli --auth-login` command, **not** by the skill | MCP registration |
| `~/.cursor/mcp.json` | written by `--auth-login`, **not** by the skill | MCP registration |

### Network egress from the skill

| Destination | When | Why |
|---|---|---|
| `api.github.com` | At most every 24 hours | Look up the latest release tag |
| `api.agentkey.app` | Each MCP tool call the agent makes | Hosted MCP server — receives the `Authorization` header and serves tool responses |

### Credential handling

- `AGENTKEY_API_KEY` is stored only in user-local config files (paths above).
- The key leaves the user's machine only as the `Authorization` header to AgentKey's own API endpoints.
- The skill collects no telemetry.

### Supply chain

- Releases are cut by [release-please](https://github.com/googleapis/release-please) from merged Conventional-Commit PRs on `main` — no manual artifact uploads, no manual tag pushes.
- The MCP server itself is hosted at `https://api.agentkey.app/v1/mcp`; it is not shipped to user machines. Users interact with it as an HTTP MCP endpoint authenticated by their personal `Authorization: Bearer <key>` header.
- The companion npm package `@agentkey/cli` (installer / auth) is published from the same organization. Users invoke it via `npx -y @agentkey/cli`, which resolves to the latest published version at runtime — same threat model as any other `npx`-launched CLI.
- Future work: SLSA provenance attestation via GitHub OIDC + sigstore; signed npm provenance.

## Scanner false-positive notes

Automated scanners (VirusTotal, ClawScan) may flag this skill as `Suspicious` due to two intentional patterns. We document them here so reviewers can verify intent:

1. **`check-update.sh` contacts GitHub.** Pattern may match "remote-controlled binary update" heuristics. **Why this is intentional:** the script is notify-only — it issues a single `GET https://api.github.com/repos/chainbase-labs/agentkey/releases/latest`, compares the tag against `skills/agentkey/version.txt`, prints a one-line status, and exits. It never writes anywhere except the cache file at `${TMPDIR}/agentkey-update-check`, never invokes `git`, and never executes downloaded code. Update execution lives entirely in the agent's interactive layer (`AskUserQuestion` → `npx skills update`), gated by explicit user consent or a previously persisted opt-in flag.
2. **`check-mcp.sh` reads `*API_KEY*` env values.** Pattern matches "credential harvesting" heuristics. **Why this is intentional:** the read is local-only, never transmitted, and exists purely to confirm `AGENTKEY_API_KEY` is configured before the agent attempts an MCP call. The script's only output is a one-word status code (`MCP_OK` / `MCP_NO_KEY` / `MCP_NOT_CONFIGURED`); the key value itself is discarded.

If you operate a scanner and need additional context to triage, please email `support@chainbase.com`.
