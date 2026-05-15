# AgentKey Skill-Meta Protocol v1

Contract between **AgentKey-Server** (the hosted MCP server at `/v1/mcp`) and **`chainbase-labs/agentkey`** (this skill repo). The server publishes the skill's latest version + client-specific upgrade instructions via a dedicated MCP tool; the skill (via the agent) reads it and tells the user how to upgrade.

This protocol exists because some MCP clients — notably Claude Desktop — cannot execute the inline `bash` block in `SKILL.md` Step 0, so the in-skill update-check path silently fails there. Routing the check through the always-on MCP server makes upgrades discoverable on every client.

## Tool contract

The server MUST expose a tool named exactly `agentkey_skill_meta` via `list_tools`. The tool MUST:

- Take **no required parameters** (an empty `{}` input is valid)
- Be safe to call repeatedly (idempotent, no side effects)
- Return a JSON object conforming to `SkillMetaResponse` (see schema)
- Respond in **under 200 ms in the steady state** (use a cached GitHub Releases lookup)
- Never throw on network failure — fall back gracefully (see §Failure modes)

The tool's `description` in `list_tools` MUST instruct the agent to call it **once per session, before any business tool call**, and MUST NOT make the agent believe it has business value (it is purely metadata).

Suggested description:

> Internal AgentKey skill metadata. Call once at session start with `{}` to retrieve the latest skill version and client-specific upgrade instructions. The response is non-actionable metadata; do not surface its raw JSON to the user. Compare `skill_version_latest` against this skill's `version:` frontmatter and follow `update_command` / `update_doc_url` if they differ.

## Response shape (v1)

```ts
interface SkillMetaResponse {
  /** Protocol version. Always 1 in this spec. Bumped only for breaking changes. */
  protocol_version: 1;

  /** Latest published skill release tag, without 'v' prefix. e.g. "1.3.0".
   *  Empty string allowed only when the server cannot reach GitHub (see Failure modes). */
  skill_version_latest: string;

  /** Lowercase short name of the MCP client that called this tool.
   *  Derived from MCP `initialize`'s `clientInfo.name`. Examples:
   *  "claude" (Claude Desktop), "claude-code", "cursor", "codex", "unknown".
   *  Servers MUST emit "unknown" rather than throwing if clientInfo is absent. */
  client_detected: string;

  /** Stable upgrade documentation URL. MUST be present in EVERY response, for EVERY
   *  client, EVERY protocol version. This is the bottom-of-the-barrel fallback the
   *  skill rule can always recommend if it doesn't understand anything else. */
  update_doc_url: string;

  /** Optional. Concrete one-line upgrade instruction for this client.
   *  - When kind="shell": a verbatim shell command the user runs in a terminal
   *  - When kind="manual_ui": a short instruction like "Settings → Capabilities → Skills → reinstall"
   *  Servers SHOULD include this whenever they have a known recipe for the detected client. */
  update_command?: string;

  /** Optional. Indicates how to interpret `update_command`. */
  update_command_kind?: "shell" | "manual_ui";

  /** Optional. URL to the human-readable release notes for skill_version_latest.
   *  Typically the GitHub Release page. */
  release_notes_url?: string;
}
```

The wire JSON Schema is in [skill-meta-v1.schema.json](./skill-meta-v1.schema.json). The TypeScript interface above is normative for human readers; the JSON Schema is normative for CI validation.

### Required vs. optional — and why

Five guarantees the skill rule depends on across all v1 servers:

1. `protocol_version === 1` (router)
2. `skill_version_latest` is a string
3. `client_detected` is a string
4. `update_doc_url` is a string (fallback that always works)
5. Adding new optional fields MUST NOT bump `protocol_version`

If you cannot guarantee #1–#4 in your implementation, you are not v1-compliant; emit `protocol_version: 0` (reserved) or omit the tool entirely.

## Client identifier conventions

Servers SHOULD map MCP `clientInfo.name` to lowercase short names:

| `clientInfo.name` substring (case-insensitive) | `client_detected` value |
|---|---|
| `claude code`                                   | `claude-code` |
| `claude` (no "code")                            | `claude` |
| `cursor`                                        | `cursor` |
| `codex`                                         | `codex` |
| `cline`                                         | `cline` |
| `windsurf`                                      | `windsurf` |
| `continue`                                      | `continue` |
| anything else                                   | `unknown` |

The list grows over time; adding a new client to the map is a non-breaking change.

## Server behavior

### Caching

The server MUST cache the GitHub Releases lookup. Recommended:

- TTL: 24 h
- Cache path: `${XDG_CACHE_HOME:-$HOME/.cache}/agentkey/skill-version.json` (Linux/macOS) or `%LOCALAPPDATA%\agentkey\skill-version.json` (Windows)
- Concurrent requests: deduplicate (one in-flight fetch per process)
- Cache structure: `{ tag: string, fetched_at: number, etag?: string }` — the optional `etag` lets the next refresh do a conditional `GET` and avoid rate limit cost

### Failure modes

| Failure | Behavior |
|---|---|
| First fetch, no network | Return `skill_version_latest: ""`, omit `update_command` and `release_notes_url`, still include `update_doc_url`. The skill rule treats empty `skill_version_latest` as "unknown, skip the check". |
| GitHub rate limit (HTTP 403) | Same as above. |
| Cache file corrupted | Delete it and refetch; if that also fails, return empty `skill_version_latest`. |
| `clientInfo` missing from `initialize` | Set `client_detected: "unknown"` and omit `update_command`. Still emit valid response. |

The tool MUST NOT throw under any of the above; throwing would crash the agent's `list_tools` enumeration on some clients.

### Update command recipes (recommended baseline)

| `client_detected` | `update_command_kind` | `update_command` |
|---|---|---|
| `claude-code`     | `shell`     | `npx -y skills update -g agentkey` |
| `cursor`          | `shell`     | `npx -y skills update -g agentkey` |
| `codex`           | `shell`     | `npx -y skills update -g agentkey` |
| `claude` (Desktop)| (omit)      | (omit) — skill falls back to `update_doc_url` (GitHub releases) for manual download |
| `unknown`         | (omit)      | (omit) — skill falls back to `update_doc_url` |

Desktop deliberately omits a `shell` command: Desktop installs skills into a sandboxed `~/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin/<UUID>/...` path which is not reachable by `npx skills update`, and no first-party scripted upgrade exists yet. Until one ships, the skill rule directs Desktop users to download the release archive from GitHub and replace the files manually. When a Desktop installer ships, this row can be promoted to `kind: "shell"` without bumping `protocol_version`.

## Skill behavior (this repo)

The SKILL.md rule MUST:

1. At session start, before any business tool call, call `agentkey_skill_meta` once with `{}`
2. If the tool is not in `list_tools`, skip silently (server is pre-v1; fall back to the legacy Step-0 inline bash check)
3. If the call fails (timeout, exception, malformed JSON), skip silently
4. If `response.protocol_version !== 1`, only honor `update_doc_url`; ignore everything else
5. If `response.skill_version_latest === ""`, skip the comparison (server admitted it doesn't know)
6. Compare `response.skill_version_latest` to this skill's `version:` frontmatter (semver string compare; if they differ → prompt user)
7. When prompting, prefer `update_command` (display verbatim, do not modify); fall back to `update_doc_url` only if no command available
8. Never surface raw response JSON to the user

The rule MUST NOT:

- Call `agentkey_skill_meta` more than once per session
- Mutate the response or rewrite it as a different shell command
- Block the user's actual request waiting for the update (prompt once, then proceed)

## Versioning

This is `v1`. The protocol uses **additive evolution**:

- **Allowed without bumping protocol_version**: adding optional fields, adding new `client_detected` enum values, adding new `update_command_kind` enum values (skill rule treats unknown kinds as `manual_ui`)
- **Requires `protocol_version: 2`**: renaming a required field, changing a required field's type, removing a required field, changing the semantics of `update_command`

When v2 ships:

- Server SHOULD emit both responses when possible (e.g. via the v1 tool always returning v1 shape, and a new `agentkey_skill_meta_v2` tool returning v2)
- Or: server emits only v2 but ensures the v1-required fields above are still present (graceful enough for v1 skills to read `update_doc_url`)
- v1 skill rule sees `protocol_version: 2` → falls back to `update_doc_url` (rule 4 above)

This means **v1 skills are never broken by future server upgrades**, regardless of what v2/v3/... add. The cost of that guarantee is the five immortal fields in §Required vs. optional.

## Single source of truth

The schema lives **only here** (`protocol/skill-meta-v1.schema.json`). Server implementations MUST consume this schema, either:

- Vendor it at build time: `curl https://raw.githubusercontent.com/chainbase-labs/agentkey/main/protocol/skill-meta-v1.schema.json > schema/skill-meta-v1.schema.json` and commit
- Or fetch on CI and `diff` against the vendored copy — CI fail forces a sync PR

The server's own CI MUST validate every `SkillMetaResponse` it emits against this schema before responding. The skill repo's CI validates `protocol/example-*.json` fixtures against the schema. Neither side rewrites the schema unilaterally; changes are PRs against this file.

## See also

- [example-response-claude-desktop.json](./example-response-claude-desktop.json) — fixture for Desktop client
- [example-response-claude-code.json](./example-response-claude-code.json) — fixture for Code client
- [example-response-unknown-client.json](./example-response-unknown-client.json) — fixture for unrecognized client
- [example-response-offline.json](./example-response-offline.json) — fixture for the server-offline / rate-limited failure mode
- [docs/SERVER-IMPLEMENTATION.md](../docs/SERVER-IMPLEMENTATION.md) — implementation guide for AgentKey-Server maintainers
