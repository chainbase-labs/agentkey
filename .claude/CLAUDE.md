# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

AgentKey Skill ships the agent-side half of AgentKey: a single skill that teaches Claude (and any Skills-CLI-compatible agent) how to call the AgentKey MCP tools correctly.

AgentKey has **two pieces** and a full end-user install is two commands:

1. `npx skills add chainbase-labs/agentkey` — installs **this** skill. It does NOT register the MCP server.
2. `npx -y @agentkey/cli --auth-login` — runs the AgentKey CLI (`@agentkey/cli` from `../AgentKey-Server/cli`). It mints an API key via device-code login and writes a remote-HTTP MCP block (pointing at `https://api.agentkey.app/v1/mcp`) into Claude Code, Claude Desktop, and Cursor configs. The hosted MCP server itself lives at `/v1/mcp` on AgentKey-Server.

The skill is useless without the MCP server; the MCP server works without the skill but the agent won't know to prefer it over built-in web search. Keep this mental model when editing docs — do not let either command drift into claiming it does both.

The same repo also works as a Claude Code plugin (via `.claude-plugin/plugin.json` + `.mcp.json`) for users on the plugin marketplace path; in that mode the plugin's `userConfig` + `.mcp.json` substitute for step 2.

## Directory Structure

```
agentkey/
├── .claude-plugin/plugin.json   # Claude Code plugin manifest
├── .mcp.json                    # Auto-registers AgentKey MCP when installed as a plugin
├── skills/agentkey/
│   ├── SKILL.md                 # Decision tree + routing rules (end-user facing)
│   ├── scripts/                 # check-mcp / check-update helpers
│   └── version.txt              # Managed by release-please only — must live inside the skill so it survives `npx skills add`
└── scripts/
    └── uninstall.sh             # End-user cleanup helper
```

## Key Commands

```bash
# Test a local edit against every detected agent
npx skills add .

# Daily commit (does NOT trigger user updates)
git add -A && git commit -m "..." && git push origin main

# Publish a new release
# Releases are cut automatically by release-please on merge to main.
# To manually trigger: merge a conventional-commit PR; release-please will open
# a Release PR; merge that to tag and create the GitHub Release.

# Undo a bad release
git tag -d vX.Y.Z && git push origin :refs/tags/vX.Y.Z
gh release delete vX.Y.Z --repo chainbase-labs/agentkey --yes
```

Releases are driven by [release-please](https://github.com/googleapis/release-please): merged PRs with Conventional Commit messages (`feat:`, `fix:`, `feat!:`, etc.) update an open Release PR that bumps `skills/agentkey/version.txt`, `.claude-plugin/plugin.json` version, and `CHANGELOG.md`. Merging the Release PR tags the release and creates the GitHub Release, which in turn triggers plugin updates for users.

## Version & Release Rules

- `skills/agentkey/version.txt`, `.claude-plugin/plugin.json` version, and `CHANGELOG.md` are managed by release-please based on Conventional Commits — never edit manually except via PR that intentionally amends them.
- `version.txt` lives inside `skills/agentkey/` (not at repo root) so it travels with the skill when the Skills CLI copies the subdirectory. `release-please-config.json` points at this path via `version-file`.
- Tag format: `v` prefix (e.g. `v0.4.5`)
- Plugin updates trigger on **GitHub Release** publication, not on plain commits
- `npx skills update` pulls from the default branch, so main must always be shippable

## Change Checklists

**Changes to `plugin.json`:**
- release-please automatically bumps `version` + `plugin.json` version + `CHANGELOG.md` from merged conventional-commit PRs; maintainers review + merge the generated Release PR rather than editing these files directly

**Changes to `.mcp.json`:**
- Ensure env var name matches `plugin.json` userConfig key via `CLAUDE_PLUGIN_OPTION_` prefix
- Only matters for the Claude Code plugin path; the Skills-CLI path writes MCP config through `npx @agentkey/cli --auth-login`

**Changes to install/uninstall docs:**
- Update both `README.md` and `docs/README_zh.md` together — they mirror each other
- The canonical install is always the two-command sequence (`npx skills add …` + `npx -y @agentkey/cli --auth-login`). Don't imply either command does both.
- Do **not** re-add OpenClaw / per-agent installers without a new design — historical context is in git history (removed in chore/remove-archive-directory)

## Architecture Constraints

- Setup mode in SKILL.md runs `! npx -y @agentkey/cli --auth-login` to authenticate via browser — same command as step 2 of the public install
- `@agentkey/cli --auth-login` auto-writes MCP configs for 16 agents (canonical list lives in `AGENT_REGISTRY` in `../AgentKey-Server/cli/src/lib/mcp-clients.ts`): Claude Code, Claude Desktop, Cursor, Codex, Gemini CLI, OpenCode, Qwen Code, iFlow CLI, Kimi CLI, Kiro CLI, Windsurf, Warp, Amp, Crush, droid, openclaw. The `--only <ids>` flag (used by install.sh's `MCP_TARGETS` and install.ps1's `$McpTargets`) filters this list — its id values MUST match `npx skills add -a` ids, with `claude-desktop` as the one documented MCP-only exception. Goose / kode / kilo still need a manual JSON paste (see SKILL.md's "Fallback" section); when adding more agents server-side, keep `MCP_AUTO_AGENTS` in both install scripts and the cleanup list in both uninstall scripts in sync.
- `.mcp.json` registers the remote-HTTP MCP endpoint (`https://api.agentkey.app/v1/mcp`) in Claude Code plugin mode; API key flows from plugin userConfig → `Authorization: Bearer <key>` header (no stdio binary is launched)
- `README.md` / `docs/README_zh.md` are the public-facing docs; keep them in sync with any structural changes
