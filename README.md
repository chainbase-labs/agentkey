<p align="center">
<img width="256" alt="AgentKey" src="https://github.com/user-attachments/assets/4c7c78a9-e5d8-45ce-9372-d5bffe8f61c5" />
</p>

<p align="center">
  <strong>One command. Full internet access for your AI agent.</strong>
  <br>
  Browse Twitter, search LinkedIn, scrape social media, read any webpage. Zero config. Just install and go.
</p>

<p align="center">
  <a href="#install">Install</a> ·
  <a href="#what-your-agent-can-now-do">Platforms</a> ·
  <a href="#pricing">Pricing</a> ·
  <a href="#faq">FAQ</a> ·
  <a href="docs/README_zh.md">中文</a>
</p>

<p align="center">
  <a href="https://agentkey.app"><img src="https://img.shields.io/badge/Website-agentkey.app-blue?style=for-the-badge" alt="Website" /></a>
  <a href="https://console.agentkey.app"><img src="https://img.shields.io/badge/Console-console.agentkey.app-7c3aed?style=for-the-badge" alt="Console" /></a>
</p>

---

**Install AgentKey. Give your AI superpowers.**

AgentKey is the master key for the agent ecosystem. When using Claude, Manus, or other agents, you often need external data: social media, e-commerce, on-chain data, various APIs. That means hunting down API keys, managing subscriptions, or hitting dead ends.

With AgentKey installed, your agent gains all these data capabilities automatically. No subscriptions, no extra registrations. Top up and go.

> ⭐ Star this repo to get notified whenever we add new platform support or release updates.

---

## Use Cases

| You ask your agent to...                               | Without AgentKey              | With AgentKey                                  |
| ------------------------------------------------------ | ----------------------------- | ---------------------------------------------- |
| 🐦 What has Musk been saying on Twitter lately?        | Can't access, tweets blocked  | Pulls all relevant tweets and summarizes them  |
| 📕 What do people think of this product on Instagram / Xiaohongshu? | Blocked, login required | Scrapes real posts, organizes by sentiment  |
| 📺 What does this YouTube / Bilibili video cover?      | Can't read, no subtitles      | Reads the video/transcript, extracts key points |
| 📖 Find Reddit threads about this pain point           | 403 blocked                   | Finds relevant threads and extracts solutions  |
| 👔 Check this competitor / candidate's LinkedIn        | 403, access issues            | Opens the page, summarizes key info            |
| 🎵 What's trending on Douyin / TikTok right now?       | Can't scrape the hot list     | Pulls trending topics and tags                 |
| 🌐 What does this webpage say?                         | Returns a wall of raw HTML    | Extracts the content, explains it clearly      |
| 📦 What does this GitHub repo do?                      | Have to click through yourself | Reads README & Issues, one-line summary       |
| 🧾 What has this wallet / fund been buying lately?     | Click through a block explorer | Summarizes recent transactions and positions  |

Before AgentKey: 10 tasks → 10 API keys → 10 separate bills.

Your agent is half-capable at best, constantly needing human help to find data, juggling credentials, drowning in complexity.

Now: one AgentKey handles everything. **AgentKey unifies all the external access your AI needs to do real work.**

---

## New here? Start on the web

Before touching the terminal, you can get a feel for AgentKey directly in your browser — the website and console explain things more visually than this README can.

- 🌐 **[agentkey.app](https://agentkey.app)** — Product overview, supported platforms, live demos, pricing details
- 🎛️ **[console.agentkey.app](https://console.agentkey.app)** — Sign up, top up credits, manage your API key, track usage

The one-line install below is what plugs AgentKey into your AI agent. If you only want to look around first, the two links above are the friendlier starting point.

---

## Install

One command. A browser tab opens for login, then you're done. The installer auto-detects every agent on your machine ([40+ supported](https://github.com/vercel-labs/skills#available-agents). Common examples include Claude Code, Codex, Gemini CLI, and Cursor CLI, etc.) and configures each one.

**macOS / Linux**
```bash
curl -fsSL https://agentkey.app/install.sh | bash
```

**Windows** (PowerShell)
```powershell
irm https://agentkey.app/install.ps1 | iex
```

Restart your agent, then ask it something that needs the internet:

> *"What has Musk been tweeting about lately?"*

That's it. No API key to copy, no JSON to edit. 

<sub>Need to target specific agents or run in CI? → See the "Advanced install options" item in the [FAQ](#faq).</sub>

---

## What your agent can now do

AgentKey maintains cloud-side integrations with each platform — no extra accounts, no extra keys.

  | Category | Services |
  | :--- | :--- |
  | **Search** | <img src="https://cdn.simpleicons.org/brave/FF2000" height="14" align="absmiddle" alt="" />&nbsp;Brave · <img src="https://cdn.simpleicons.org/perplexity/20B8CD" height="14" align="absmiddle" alt="" />&nbsp;Perplexity · Tavily · Serper |
  | **Scrape** | Firecrawl · Jina Reader · ScrapeNinja |
  | **On-chain / Crypto** | Chainbase · <img src="https://cdn.simpleicons.org/coinmarketcap/17181B" height="14" align="absmiddle" alt="" />&nbsp;CoinMarketCap · Dexscreener |
  | **Social & Content** | <img src="https://cdn.simpleicons.org/bilibili/00A1D6" height="14" align="absmiddle" alt="" />&nbsp;Bilibili · <img src="https://cdn.simpleicons.org/tiktok/000000" height="14" align="absmiddle" alt="" />&nbsp;Douyin · <img src="https://cdn.simpleicons.org/instagram/E4405F" height="14" align="absmiddle" alt="" />&nbsp;Instagram · <img src="https://cdn.simpleicons.org/kuaishou/FF4900" height="14" align="absmiddle" alt="" />&nbsp;Kuaishou · Lemon8 · LinkedIn · <img src="https://cdn.simpleicons.org/reddit/FF4500" height="14" align="absmiddle" alt="" />&nbsp;Reddit · <img src="https://cdn.simpleicons.org/x/000000" height="14" align="absmiddle" alt="" />&nbsp;Twitter&nbsp;(X) · <img src="https://cdn.simpleicons.org/sinaweibo/E6162D" height="14" align="absmiddle" alt="" />&nbsp;Weibo · <img src="https://cdn.simpleicons.org/wechat/07C160" height="14" align="absmiddle" alt="" />&nbsp;Weixin · <img src="https://cdn.simpleicons.org/xiaohongshu/FF2442" height="14" align="absmiddle" alt="" />&nbsp;Xiaohongshu&nbsp;(maintenance) · <img src="https://cdn.simpleicons.org/youtube/FF0000" height="14" align="absmiddle" alt="" />&nbsp;YouTube · <img src="https://cdn.simpleicons.org/zhihu/0084FF" height="14" align="absmiddle" alt="" />&nbsp;Zhihu |

**Planned:** Financial data · E-commerce · Maps & Weather

---

## Pricing

**No monthly fee. Pay only for what you use.** Top up any amount, spend by credit:

| What you ask your agent to do | Approx. cost |
|-------------------------------|--------------|
| Web search | $0.001 |
| Crypto / token lookup | $0.003 |
| Social media read | $0.006 |
| Daily scheduled task | ~$5–10 / month |

---

## FAQ

<details>
<summary><b>Is it safe?</b></summary>

Yes. AgentKey is a master key — one platform that unlocks external capabilities for your agent. By design, we have no access to your local files, your credentials, or your agent's conversations. There's nothing for us to collect.

</details>

<details>
<summary><b>How is this different from Claude / ChatGPT's built-in web access?</b></summary>

Native web access in Claude and ChatGPT has limited platform coverage. It often can't reach Twitter, Xiaohongshu, on-chain data, etc. AgentKey fills those gaps.

</details>

<details>
<summary><b>What if I run out of credits?</b></summary>

Just top up. No auto-renewal, no hidden charges.

</details>

<details>
<summary><b>How do I update?</b></summary>

**You don't have to — updates are automatic by default.** Your MCP config uses `npx -y @agentkey/mcp`, which re-resolves to the latest published version every time your agent restarts. In Claude Code plugin mode, AgentKey also checks GitHub Releases at runtime and applies a silent in-place update, notifying you:

```
Claude: AgentKey Skill updated to v1.1.0.
```

**If you'd rather force it manually:**

```bash
# Refresh the skill content
npx skills update agentkey

# Pin a specific version
npx skills add chainbase-labs/agentkey@v1.0.0
```

Re-run `npx -y @agentkey/mcp --auth-login` only when you want to rotate your API key.

</details>

<details>
<summary><b>How do I uninstall?</b></summary>

One command, cleans every agent and config file.

**macOS / Linux**
```bash
curl -fsSL https://agentkey.app/uninstall.sh | bash
```

**Windows** (PowerShell)
```powershell
irm https://agentkey.app/uninstall.ps1 | iex
```

Removes the skill from every agent, strips the `agentkey` MCP entry + API key from all MCP client configs, and clears caches/logs. Pass `--keep-marketplace` (bash) / `-KeepMarketplace` (PowerShell) to retain the Claude Code plugin marketplace entry.

**Prefer manual two-step?**

```bash
# 1. Remove the skill from every agent
npx skills remove chainbase-labs/agentkey

# 2. Delete the "agentkey" entry under mcpServers in each MCP client config:
#    - Claude Code:     ~/.claude.json
#    - Claude Desktop:  ~/Library/Application Support/Claude/claude_desktop_config.json  (macOS)
#                       %APPDATA%\Claude\claude_desktop_config.json                      (Windows)
#    - Cursor:          ~/.cursor/mcp.json
```

The one-command uninstaller additionally cleans npm/npx caches, legacy shell rc entries, CLAUDE.md sections, and MCP stdio logs — use that if you want a fully clean slate.

</details>

<details>
<summary><b>Something's not working — how do I check?</b></summary>

Inside your agent, try `/agentkey status` — it diagnoses your MCP config, version, and connectivity.

Available slash commands:

| Command | What it does |
|---------|--------------|
| `/agentkey` | Auto-triggered during data queries — you usually don't call it manually |
| `/agentkey setup` | First-time setup: configure API key + verify MCP connectivity |
| `/agentkey status` | Diagnose current config (MCP, version, connectivity test) |

Still stuck? See the "Where do I get help" item below.

</details>

<details>
<summary><b>Advanced install options (CI / specific agents / manual two-step)</b></summary>

The installer auto-detects which AI agents you have on this machine (by probing well-known config dirs and binaries from the [vercel-labs/skills supported-agents list](https://github.com/vercel-labs/skills)) and pre-selects them — no multi-select prompt. Override with the flags below.

**Installer flags:**

```bash
# Non-interactive (CI / unattended): install to every detected agent, no prompts
curl -fsSL https://agentkey.app/install.sh | bash -s -- --yes

# See which agents the installer would auto-select on this host (and exit)
curl -fsSL https://agentkey.app/install.sh | bash -s -- --list-agents

# Only install the skill for specific agents (overrides auto-detection)
curl -fsSL https://agentkey.app/install.sh | bash -s -- --only claude-code,cursor

# Skip our agent detection; let `skills` CLI install for every agent it finds
curl -fsSL https://agentkey.app/install.sh | bash -s -- --all-agents

# Only the skill, or only the MCP auth
curl -fsSL https://agentkey.app/install.sh | bash -s -- --skip-mcp
curl -fsSL https://agentkey.app/install.sh | bash -s -- --skip-skill

# Re-authenticate even if AgentKey is already configured locally
curl -fsSL https://agentkey.app/install.sh | bash -s -- --force-mcp
```

PowerShell equivalents: `-Yes`, `-ListAgents`, `-Only`, `-AllAgents`, `-SkipMcp`, `-SkipSkill`, `-ForceMcp`.

**Manual two-step install** (if you'd rather run the two underlying commands yourself, or the one-line installer can't reach your machine):

```bash
# 1. Install the skill into every detected agent
npx skills add chainbase-labs/agentkey

# 2. Authenticate and register the MCP server
npx -y @agentkey/mcp --auth-login
```

</details>

<details>
<summary><b>Installing over SSH, inside Docker, or via OpenClaw / Claude Code remote channels</b></summary>

When the installer runs on a machine you can't see (an SSH server, a Docker container, an OpenClaw runtime triggered from your phone), the default `--auth-login` would silently spawn a browser on the *remote* host — invisible to you.

The installer detects this automatically and switches to a **scan-from-phone** flow: it prints the auth URL plus a terminal QR code, and skips the browser auto-open. Detection signals (any one fires):

- `~/.openclaw/` exists (OpenClaw runtime)
- `$SSH_CONNECTION` / `$SSH_TTY` set
- Linux without `$DISPLAY` / `$WAYLAND_DISPLAY`

Force the mode either way:

```bash
# Force remote mode (URL + QR, no browser)
curl -fsSL https://agentkey.app/install.sh | bash -s -- --remote

# Force local mode (auto-open browser, ignore heuristics)
curl -fsSL https://agentkey.app/install.sh | bash -s -- --local
```

PowerShell: `-Remote` / `-Local`.

If you'd rather skip the URL/QR flow entirely and type a key manually, `npx -y @agentkey/mcp --setup` opens an interactive wizard that asks for the key and lets you pick which MCP clients to write to.

</details>

<details>
<summary><b>My agent isn't on the auto-configured list — how do I set it up manually?</b></summary>

MCP auto-configuration covers **Claude Code**, **Claude Desktop**, and **Cursor**. For **Codex / OpenCode / Gemini CLI / Hermes / Manus** (or Linux Claude Desktop), the skill still installs automatically — but you'll need to paste this MCP snippet into the agent's own config (path varies per agent):

```json
{
  "mcpServers": {
    "agentkey": {
      "command": "npx",
      "args": ["-y", "@agentkey/mcp"],
      "env": { "AGENTKEY_API_KEY": "ak_..." }
    }
  }
}
```

Then restart the agent. The skill's first-run activation will also walk you through this.

</details>

<details>
<summary><b>Can I self-host or develop against this?</b></summary>

**Install from a local checkout:**

```bash
git clone https://github.com/chainbase-labs/agentkey.git
cd agentkey

# 1. Install your working tree into every detected agent
npx skills add .

# 2. Register the MCP server (if you haven't already)
npx -y @agentkey/mcp --auth-login
```

`npx skills add .` accepts a local path (or a `file://` URL) — run it again after each edit to `skills/agentkey/SKILL.md`. The MCP step only needs to run once per machine.

**Iterating on the MCP server itself?** Point the MCP config's `command` at `node /path/to/AgentKey-Server/mcp-server/dist/index.js`, then `pnpm --filter @agentkey/mcp build` in the server repo between iterations.

**Claude Code plugin mode** — add the repo as a local marketplace:

```bash
claude plugin marketplace add /absolute/path/to/agentkey
claude plugin install agentkey
```

Reload with `claude plugin update agentkey` after edits. Use the skills-CLI path for day-to-day edits; the plugin path only for testing Claude Code plugin internals (e.g. MCP env-var wiring through `CLAUDE_PLUGIN_OPTION_*`).

**Repo layout:**

```
agentkey/
├── .claude-plugin/plugin.json   # Claude Code plugin manifest
├── .mcp.json                    # Used when installed as a plugin
├── skills/agentkey/
│   ├── SKILL.md                 # Decision tree + routing rules
│   ├── scripts/                 # check-mcp / check-update helpers
│   └── version.txt              # Managed by release-please
└── scripts/
    ├── install.sh               # One-command installer (mac/linux)
    ├── install.ps1              # Windows PowerShell installer
    ├── uninstall.sh             # One-command uninstaller (mac/linux)
    └── uninstall.ps1            # Windows PowerShell uninstaller
```

**Release a new version (maintainers):** releases are cut automatically by [release-please](https://github.com/googleapis/release-please). Merging a PR with a `feat:` or `fix:` title opens a Release PR that bumps `skills/agentkey/version.txt`, `plugin.json`, and `CHANGELOG.md`. Merging the Release PR creates the tag + GitHub Release + uploads the `agentkey.skill` asset.

</details>

<details>
<summary><b>What stage is the product at?</b></summary>

Early access. There are rough edges and we appreciate your patience. Feature requests and bug reports are welcome via [GitHub Issues](https://github.com/chainbase-labs/agentkey/issues) or Telegram (see below).

</details>

<details>
<summary><b>Where do I get help / report bugs / follow updates?</b></summary>

- **Telegram:** [t.me/AgentKey_Official](https://t.me/AgentKey_Official) — general questions, support, feature requests
- **Bug reports:** [GitHub Issues](https://github.com/chainbase-labs/agentkey/issues)
- **Release announcements:** ⭐ star this repo to get notified

</details>

---

[![Star History Chart](https://api.star-history.com/svg?repos=chainbase-labs/agentkey&type=Date)](https://www.star-history.com/?repos=chainbase-labs%2Fagentkey&type=date&legend=top-left)
