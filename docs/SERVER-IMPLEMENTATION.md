# Server Implementation Guide — `agentkey_skill_meta`

Implementation handoff for the `@agentkey/mcp` MCP server. Tells the server maintainer exactly what to build so the cross-client skill-update path (Claude Desktop, Cursor, etc.) works.

**Authoritative spec**: [protocol/skill-meta-v1.md](../protocol/skill-meta-v1.md). This doc is implementation guidance, not protocol; if it conflicts with the spec, the spec wins.

## What to build

Add one new MCP tool to the server: `agentkey_skill_meta`. It returns a JSON object describing the latest published skill version and how the detected client should upgrade. The skill rule (already in `chainbase-labs/agentkey`) reads this and prompts the user.

That's the entire feature. No new endpoints, no new env vars (except the optional opt-out below), no new dependencies beyond standard `https` / `fs`.

## Component sketch

```
src/
├── index.ts                         # MCP entry; capture clientInfo.name during initialize
├── tools/
│   ├── ... (existing tools)
│   └── skill-meta.ts                # NEW — handler for agentkey_skill_meta
├── lib/
│   └── github-release-cache.ts      # NEW — cached fetch of latest release tag
└── protocol/
    └── skill-meta-v1.schema.json    # NEW — vendored copy of the spec schema
```

## Step 1 — Capture `clientInfo` on initialize

In your MCP `initialize` handler, persist `params.clientInfo.name` to a module-level variable (or whichever request-scoped storage your server uses). The handler runs once per connection; subsequent tool calls read this value.

```ts
// src/index.ts (sketch)
let clientName = "unknown";

server.setRequestHandler(InitializeRequestSchema, async (req) => {
  clientName = req.params.clientInfo?.name ?? "unknown";
  // ... return capabilities
});

export const getClientName = () => clientName;
```

If your server is already multi-tenant or runs as a daemon serving many MCP sessions, store this per-connection rather than module-level.

## Step 2 — Cached release-tag fetch

GitHub API: `GET https://api.github.com/repos/chainbase-labs/agentkey/releases/latest`. Cache for **24 h** in `${XDG_CACHE_HOME:-$HOME/.cache}/agentkey/skill-version.json` (Windows: `%LOCALAPPDATA%\agentkey\skill-version.json`).

```ts
// src/lib/github-release-cache.ts (sketch)
import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { homedir } from "node:os";

interface Cache {
  tag: string;
  fetched_at: number;  // epoch ms
  etag?: string;
}

const CACHE_PATH = join(
  process.env.XDG_CACHE_HOME ?? join(homedir(), ".cache"),
  "agentkey",
  "skill-version.json"
);
const TTL_MS = 24 * 60 * 60 * 1000;

let inFlight: Promise<string> | null = null;

export async function getLatestSkillVersion(): Promise<string> {
  if (inFlight) return inFlight;
  inFlight = (async () => {
    try {
      const cached = await readCache();
      if (cached && Date.now() - cached.fetched_at < TTL_MS) return cached.tag;
      const fresh = await fetchFromGitHub(cached?.etag);
      if (fresh) await writeCache(fresh);
      return fresh?.tag ?? cached?.tag ?? "";
    } catch {
      return "";  // network/parse failure → skill rule treats as "unknown"
    } finally {
      inFlight = null;
    }
  })();
  return inFlight;
}

async function fetchFromGitHub(prevEtag?: string): Promise<Cache | null> {
  const res = await fetch(
    "https://api.github.com/repos/chainbase-labs/agentkey/releases/latest",
    {
      headers: {
        "User-Agent": "@agentkey/mcp",
        ...(prevEtag ? { "If-None-Match": prevEtag } : {}),
      },
      signal: AbortSignal.timeout(3000),
    }
  );
  if (res.status === 304) return null;            // not modified
  if (!res.ok) return null;                       // 403 rate limit, 5xx, etc.
  const body = (await res.json()) as { tag_name?: string };
  if (!body.tag_name) return null;
  return {
    tag: body.tag_name.replace(/^v/, ""),
    fetched_at: Date.now(),
    etag: res.headers.get("etag") ?? undefined,
  };
}

async function readCache(): Promise<Cache | null> {
  try {
    const raw = await readFile(CACHE_PATH, "utf8");
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

async function writeCache(c: Cache): Promise<void> {
  await mkdir(dirname(CACHE_PATH), { recursive: true });
  await writeFile(CACHE_PATH, JSON.stringify(c), "utf8");
}
```

Why a 3-second timeout: the tool MUST respond fast enough not to block `list_tools` discovery. A 24 h cache means at most one network call per day per machine, and a stale cache is always preferred over a slow response.

## Step 3 — Client → upgrade-recipe map

```ts
// src/tools/skill-meta.ts (sketch)
type Recipe = { command: string; kind: "shell" | "manual_ui" };

const RECIPES: Record<string, Recipe> = {
  "claude-code": { command: "npx -y skills update -g agentkey", kind: "shell" },
  "claude":      { command: "bash <(curl -fsSL https://agentkey.app/update-desktop.sh)", kind: "shell" },
  "cursor":      { command: "npx -y skills update -g agentkey", kind: "shell" },
  "codex":       { command: "npx -y skills update -g agentkey", kind: "shell" },
};

function normalizeClient(raw: string): string {
  const s = raw.toLowerCase().trim();
  if (s.includes("claude code")) return "claude-code";
  if (s.includes("claude"))      return "claude";
  if (s.includes("cursor"))      return "cursor";
  if (s.includes("codex"))       return "codex";
  if (s.includes("cline"))       return "cline";
  if (s.includes("windsurf"))    return "windsurf";
  if (s.includes("continue"))    return "continue";
  return "unknown";
}
```

The Desktop one-liner currently points at a `bash <(curl ...)` because the only reliable way to find Desktop's sandbox path is to inspect `~/Library/Application Support/Claude/...` at runtime. That script is owned by the agentkey.app maintainers; until it ships, emit `update_command_kind: "manual_ui"` with the README URL instead.

## Step 4 — The tool itself

```ts
// src/tools/skill-meta.ts
import { getLatestSkillVersion } from "../lib/github-release-cache.js";
import { getClientName } from "../index.js";

export const SKILL_META_TOOL = {
  name: "agentkey_skill_meta",
  description:
    "Internal AgentKey skill metadata. Call once at session start with `{}` to retrieve the latest skill version and client-specific upgrade instructions. The response is non-actionable metadata; do not surface its raw JSON to the user. Compare `skill_version_latest` against this skill's `version:` frontmatter and follow `update_command` / `update_doc_url` if they differ.",
  inputSchema: {
    type: "object",
    properties: {},
    additionalProperties: false,
  },
} as const;

export async function handleSkillMeta() {
  if (process.env.AGENTKEY_NO_VERSION_BEACON === "1") {
    // user opted out — still return a minimally valid response
    return {
      protocol_version: 1 as const,
      skill_version_latest: "",
      client_detected: normalizeClient(getClientName()),
      update_doc_url: "https://agentkey.app/docs/upgrade",
    };
  }
  const latest = await getLatestSkillVersion();   // never throws; "" on failure
  const client = normalizeClient(getClientName());
  const recipe = RECIPES[client];
  return {
    protocol_version: 1 as const,
    skill_version_latest: latest,
    client_detected: client,
    update_doc_url: "https://agentkey.app/docs/upgrade",
    ...(recipe ? { update_command: recipe.command, update_command_kind: recipe.kind } : {}),
    ...(latest ? { release_notes_url: `https://github.com/chainbase-labs/agentkey/releases/tag/v${latest}` } : {}),
  };
}
```

Register `SKILL_META_TOOL` in your `list_tools` handler, and route invocations of `agentkey_skill_meta` to `handleSkillMeta`. The MCP `CallToolResult` should wrap the JSON in a `content[0]` text block: `{ content: [{ type: "text", text: JSON.stringify(response) }] }`.

## Step 5 — Vendor the schema + CI validation

Copy `protocol/skill-meta-v1.schema.json` from this repo into the server repo at `protocol/skill-meta-v1.schema.json`. Validate every emitted response against it before returning:

```ts
import Ajv from "ajv";
import schema from "../protocol/skill-meta-v1.schema.json" with { type: "json" };

const ajv = new Ajv();
const validate = ajv.compile(schema);

export async function handleSkillMeta() {
  const response = /* ... as above ... */;
  if (!validate(response)) {
    // schema bug; fail loudly in dev, but DO NOT throw at runtime — emit
    // a minimum-viable v1 response so the agent's list_tools doesn't break
    console.error("[skill-meta] response failed schema:", validate.errors);
    return {
      protocol_version: 1 as const,
      skill_version_latest: "",
      client_detected: "unknown",
      update_doc_url: "https://agentkey.app/docs/upgrade",
    };
  }
  return response;
}
```

Add a CI workflow on the server side that diffs the vendored schema against this repo's authoritative copy:

```yaml
# .github/workflows/protocol-drift.yml (in @agentkey/mcp repo)
on:
  pull_request:
  schedule: [{cron: '0 12 * * 1'}]
jobs:
  drift:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Fetch upstream schema
        run: curl -fsSL https://raw.githubusercontent.com/chainbase-labs/agentkey/main/protocol/skill-meta-v1.schema.json > /tmp/upstream.json
      - name: Diff against vendored copy
        run: diff /tmp/upstream.json protocol/skill-meta-v1.schema.json
```

CI failure on `diff` is the signal: "upstream protocol changed, sync your vendored copy (and update the implementation if a new field was added)".

## Required tests

Three categories — all should exist in the server repo's test suite before shipping:

1. **Schema conformance** (per fixture). For each of the four `protocol/example-response-*.json` fixtures in this repo, your `handleSkillMeta` should be able to produce a response matching one of them (modulo dynamic fields like `release_notes_url`).

2. **Failure modes**. Mock the GitHub API to return:
   - 200 with a valid tag → response has `skill_version_latest` set
   - 403 (rate limit) → response has `skill_version_latest: ""`
   - Network error → response has `skill_version_latest: ""`
   - 200 with malformed JSON → response has `skill_version_latest: ""`
   - All four → `validate(response) === true`

3. **Client detection**. For each known `clientInfo.name` ("Claude", "Claude Code", "Cursor", "Codex", "Anthropic Computer Use Demo", ""), the normalized `client_detected` matches the spec table, and the recipe map either provides a command or is absent.

## Performance budget

- `list_tools` exposing the new tool: +1 entry, no extra latency
- First call to `agentkey_skill_meta` with cold cache: ≤ 3 s (network), then cached
- Subsequent calls: ≤ 10 ms (file read + JSON parse)
- Memory: < 1 KB cached, no goroutines / timers needed

## Opt-out

Honor the env var `AGENTKEY_NO_VERSION_BEACON=1`: tool stays registered (so the skill rule doesn't fall through to legacy bash), but emits a minimum-viable response with empty `skill_version_latest`. The skill rule then skips the version comparison silently.

## What NOT to do

| Anti-pattern | Why not |
|---|---|
| Throw on network failure | Crashes `list_tools` on some clients; user sees broken MCP server |
| Skip registering the tool when cache is empty | Skill rule then falls through to inline-bash path on Desktop, which doesn't work — defeats the entire feature |
| Add the version string to every tool's `description` as a side channel | We considered it as a transition mechanism for old skills, but it pollutes prompt context with every `list_tools` call and is hard to retire. Keep the channel single-purpose |
| Auto-execute the upgrade from inside the server | Cross-process writes to a client's sandbox directory; sandbox path changes break us; bad debuggability. Notify + instruct, don't auto-mutate |
| Skip the `update_doc_url` field | It's the only field guaranteed to exist across all protocol versions. Skill rules that don't understand future fields fall back to it. Without it they have nothing to show the user |

## Release coordination with this repo

1. Implement and merge in `@agentkey/mcp`
2. `npm publish` a new version
3. (Verify) Any user with `npx -y @agentkey/mcp` in their config will pick it up on next agent restart automatically
4. In this repo, a new skill release (`v1.4.0`) ships the SKILL.md rule that reads the metadata tool
5. Existing skill versions (≤1.3.x) silently ignore the new tool — no regression; they continue to use the inline bash path on Claude Code and have no upgrade path on Desktop (status quo)
6. New skill versions (≥1.4.0) work everywhere
