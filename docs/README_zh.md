<p align="center">
<img width="256" alt="AgentKey" src="https://github.com/user-attachments/assets/4c7c78a9-e5d8-45ce-9372-d5bffe8f61c5" />
</p>

<p align="center">
  <strong>一条命令，解锁 Agent 全网访问能力。</strong>
  <br>
  刷推特、搜领英、逛社交媒体、抓网页。无需配置，装好即用。
</p>

<p align="center">
  <a href="#安装">安装</a> ·
  <a href="#装好之后能干什么">支持平台</a> ·
  <a href="#计费相关">计费</a> ·
  <a href="#常见问题">常见问题</a> ·
  <a href="../README.md">English</a>
</p>

<p align="center">
  <a href="https://agentkey.app"><img src="https://img.shields.io/badge/Website-agentkey.app-blue?style=for-the-badge" alt="Website" /></a>
  <a href="https://console.agentkey.app"><img src="https://img.shields.io/badge/Console-console.agentkey.app-7c3aed?style=for-the-badge" alt="Console" /></a>
</p>

---

**安装 AgentKey，让你的 AI 拥有超能力**

AgentKey 是 Agent 生态里的"万能钥匙"。用户在用 Claude、Manus 这些 Agent 时，经常需要获取外部数据（社交媒体、电商、链上数据、各种 API），但要么要自己找 API 填 Key，要么根本找不到解决方案。

装了 AgentKey，Agent 就自动具备了这些数据获取能力。无需订阅，无需注册任何服务，充值即用。

> ⭐ 右上角 Star 本项目，我们会持续更新平台接入变化，有新版本自动通知你。

---

## 使用场景

| 你对 Agent 说                                         | 没装会怎样              | 装了 AgentKey 后                   |
| ----------------------------------------------------- | ----------------------- | ---------------------------------- |
| 🐦 马斯克最近在推特上在说什么                         | 看不了，搜不到完整推文  | 一次拉全相关推文，帮你总结结论     |
| 📕 Ins / 小红书 上大家怎么看这个产品                  | 打不开，必须登录才能看  | 直接抓真实笔记，按口碑帮你归纳     |
| 📺 这个 YouTube / B 站视频讲了什么                    | 看不了，字幕拿不到      | 自动看视频/字幕，提炼要点          |
| 📖 去 Reddit 上看看有没有人遇到同样的痛点             | 403 被封，帖子进不去    | 找到相关帖子，把解法抽出来         |
| 👔 帮我看一下这家竞品 / 候选人的 LinkedIn             | 进不去，权限烦还老 403  | 打开公司/个人页，提炼关键信息      |
| 🎵 帮我看看抖音 / TikTok 最近哪些话题最热             | 刷不动榜单，只能自己刷  | 抓热门话题和标签，帮你总结趋势     |
| 🌐 帮我看看这个网页写了啥                             | 抓回来一堆 HTML，没法读 | 把正文抠出来，用几段话讲清楚       |
| 📦 这个 GitHub 仓库是干嘛的？                         | 只能自己点进仓库慢慢翻  | 看 README、Issue，一句话说清       |
| 🧾 帮我看看这个地址/基金最近在买什么                  | 自己去区块浏览器一笔笔点 | 自动汇总最近交易，帮你看仓位变化  |

没有安装之前：10 个任务，10 个 Key，10 份账单。

Agent 就像半智能体，完全无法自主行动，不断需要人类帮助搜寻解决方案，管理复杂度直线上升。

现在，一个 AgentKey，所有服务全部搞定。**AgentKey 统一了 AI 干活需要的一切外部访问。**

---

## 第一次来？先到网页上看看

在动命令行之前，你可以先在浏览器里熟悉一下 AgentKey —— 官网和后台讲得比 README 更直观。

- 🌐 **[agentkey.app](https://agentkey.app)** —— 产品介绍、支持的平台、在线演示、计费说明
- 🎛️ **[console.agentkey.app](https://console.agentkey.app)** —— 注册账号、充值、管理 API Key、查看用量

下面的一条命令是把 AgentKey 接进你的 AI Agent。如果只是想先看看，上面两个链接是更友好的入口。

---

## 安装

一条命令。浏览器弹出登录，完成即可。安装脚本会自动识别你机器上每一个支持的 Agent（[已支持 40+](https://github.com/vercel-labs/skills#available-agents)，常见的如 Claude Code、Codex、Gemini CLI、Cursor CLI 等），逐个配好。

**macOS / Linux**
```bash
curl -fsSL https://agentkey.app/install.sh | bash
```

**Windows**（PowerShell）
```powershell
irm https://agentkey.app/install.ps1 | iex
```

重启 Agent，然后问它一些需要联网的问题：

> *"马斯克最近在推特上在说什么？"*

就这样。不用复制 API Key，也不用改 JSON。

<sub>想只装到特定 Agent 或在 CI 里跑？→ 看 [常见问题](#常见问题) 里的"进阶安装"条目。</sub>

---

## 装好之后能干什么

AgentKey 在云端维护与各平台的对接 —— 你不需要额外开账号，也不用再填 Key。

| 类别 | 服务 |
| :--- | :--- |
| **搜索** | <img src="https://cdn.simpleicons.org/brave/FF2000" height="14" align="absmiddle" alt="" />&nbsp;Brave · <img src="https://cdn.simpleicons.org/perplexity/20B8CD" height="14" align="absmiddle" alt="" />&nbsp;Perplexity · Tavily · Serper |
| **抓取** | Firecrawl · Jina Reader · ScrapeNinja |
| **链上 / 加密** | Chainbase · <img src="https://cdn.simpleicons.org/coinmarketcap/17181B" height="14" align="absmiddle" alt=""/>&nbsp;CoinMarketCap · Dexscreener |
| **社交媒体与内容** | <img src="https://cdn.simpleicons.org/bilibili/00A1D6" height="14" align="absmiddle" alt="" />&nbsp;Bilibili · <img src="https://cdn.simpleicons.org/tiktok/000000" height="14" align="absmiddle" alt="" />&nbsp;Douyin · <img src="https://cdn.simpleicons.org/instagram/E4405F" height="14" align="absmiddle" alt="" />&nbsp;Instagram · <img src="https://cdn.simpleicons.org/kuaishou/FF4900" height="14" align="absmiddle" alt="" />&nbsp;Kuaishou · Lemon8 · LinkedIn · <img src="https://cdn.simpleicons.org/reddit/FF4500" height="14" align="absmiddle" alt="" />&nbsp;Reddit · <img src="https://cdn.simpleicons.org/x/000000" height="14" align="absmiddle" alt="" />&nbsp;Twitter&nbsp;(X) · <img src="https://cdn.simpleicons.org/sinaweibo/E6162D" height="14" align="absmiddle" alt="" />&nbsp;Weibo · <img src="https://cdn.simpleicons.org/wechat/07C160" height="14" align="absmiddle" alt="" />&nbsp;Weixin · <img src="https://cdn.simpleicons.org/xiaohongshu/FF2442" height="14" align="absmiddle" alt="" />&nbsp;Xiaohongshu（维护中） · <img src="https://cdn.simpleicons.org/youtube/FF0000" height="14" align="absmiddle" alt="" />&nbsp;YouTube · <img src="https://cdn.simpleicons.org/zhihu/0084FF" height="14" align="absmiddle" alt="" />&nbsp;Zhihu |

**规划中：** 金融数据 · 电商平台 · 地图与天气

---

## 计费相关

**没有月费。用多少付多少。** 充值自定义金额，按实际 Credit 消费：

| 你让 Agent 做的事 | 大概花多少 |
|---|---|
| 搜网页 | $0.001 |
| 查币的情况 | $0.003 |
| 读社交媒体 | $0.006 |
| 每日定时任务 | 每月 $5–10 |

---

## 常见问题

<details>
<summary><b>安全吗？</b></summary>

安全。AgentKey 是 Agent 的"万能钥匙"—— 一个平台帮你的 Agent 解锁外部能力。按架构设计，我们就看不到你的本地文件、凭证或 Agent 的对话，也没条件采集。

</details>

<details>
<summary><b>和 Claude / ChatGPT 自带的能力有什么不一样？</b></summary>

Claude 与 ChatGPT 的原生联网与平台覆盖有限，往往触达不到推特、小红书、链上数据等。AgentKey 让你的 Agent 能覆盖这些场景（具体以当前产品能力为准）。

</details>

<details>
<summary><b>额度用完了怎么办？</b></summary>

充值即可；无自动续费，无隐藏扣款。

</details>

<details>
<summary><b>怎么更新？</b></summary>

AgentKey 有两部分，更新方式不同：

- **MCP server**：托管在 `https://api.agentkey.app/v1/mcp`。你的 MCP 配置只是指向这个 URL 加上 `Authorization` 头，所以服务端始终是最新版本，本机这边没有任何东西要升级。

- **Skill 文件**（`SKILL.md` 加辅助脚本）：升级方式取决于你用的 client。

### Claude Code

完全自动。每次会话第一次调用 skill 时会静默跑版本检查；发现新版本会提示你升级，得到你确认后跑 `npx skills update -g agentkey`。

### Claude Desktop / Cursor 等没有 inline Bash 工具的 client

Skill 自己跑不了 inline 检查，但**从 v1.4.0 起 MCP server 通过专用 metadata tool（`agentkey_skill_meta`）发布最新 skill 版本号**。Agent 在每个会话里调一次，对比本地 skill 版本，发现差异就用你 client 对应的精确命令提示你升级。协议细节见 [protocol/skill-meta-v1.md](../protocol/skill-meta-v1.md)。

**Desktop 一次性破冰升级**：如果你 Desktop 里的 skill 还停在 1.4.0 之前，metadata tool 存在但旧 skill 不懂怎么读。先手动同步一次到最新版：

```bash
# 把 <UUID1>/<UUID2> 替换成 skills-plugin 下实际的 session 目录
# （通常就一个，找包含 skills/agentkey/SKILL.md 的那个）
DESKTOP_BASE="$HOME/Library/Application Support/Claude/local-agent-mode-sessions/skills-plugin"
LATEST_REPO_ZIP=$(mktemp -d)/agentkey.tar.gz
curl -fsSL https://github.com/chainbase-labs/agentkey/archive/refs/heads/main.tar.gz -o "$LATEST_REPO_ZIP"
tar -xzf "$LATEST_REPO_ZIP" -C "$(dirname "$LATEST_REPO_ZIP")"
find "$DESKTOP_BASE" -type d -path "*/skills/agentkey" 2>/dev/null | while read -r dst; do
  cp -R "$(dirname "$LATEST_REPO_ZIP")"/agentkey-main/skills/agentkey/. "$dst/"
done
# 然后完全退出并重启 Claude Desktop。
```

破冰之后，后续每次新版都会通过 metadata tool 自动告知，无需再手动操作。

### 任意 client：强制手动更新

```bash
# 拉最新版的 Skill 内容
npx skills update agentkey

# 锁定特定版本
npx skills add chainbase-labs/agentkey@v1.0.0
```

注意：`npx skills update` 只写 `~/.agents/skills/agentkey` 和 `~/.claude/skills/agentkey` 这两个目录，是 Claude Code 读取的位置。**Claude Desktop 读的是自己的 sandbox 路径**，`npx skills update` 碰不到——Desktop 升级要用上面的破冰命令。

只有在需要换 API Key 时才需要再跑一次 `npx -y @agentkey/cli --auth-login`。

</details>

<details>
<summary><b>怎么卸载？</b></summary>

一条命令，清理所有 Agent 与配置。

**macOS / Linux**
```bash
curl -fsSL https://agentkey.app/uninstall.sh | bash
```

**Windows**（PowerShell）
```powershell
irm https://agentkey.app/uninstall.ps1 | iex
```

把 Skill 从所有 Agent 里清理掉，同时删除各 MCP 客户端里的 `agentkey` 条目 + API Key，清理缓存和日志。加 `--keep-marketplace`（bash）/ `-KeepMarketplace`（PowerShell）可以保留 Claude Code 的 marketplace 条目。

**想手动两步卸载？**

```bash
# 1. 把 Skill 从所有 Agent 里移除
npx skills remove chainbase-labs/agentkey

# 2. 在各 MCP 客户端配置里删掉 mcpServers 下的 "agentkey" 条目：
#    - Claude Code：    ~/.claude.json
#    - Claude Desktop： ~/Library/Application Support/Claude/claude_desktop_config.json  (macOS)
#                      %APPDATA%\Claude\claude_desktop_config.json                       (Windows)
#    - Cursor：         ~/.cursor/mcp.json
```

一键卸载脚本还会额外清 npm/npx 缓存、旧的 shell rc 残留、CLAUDE.md 里的 AgentKey 段、MCP stdio 日志 —— 想一次清干净就用它。

</details>

<details>
<summary><b>好像哪里不对？怎么排查？</b></summary>

在 Agent 里试试 `/agentkey status` —— 会诊断 MCP 配置、版本、连通性。

可用的 Slash 命令：

| 命令 | 作用 |
|---|---|
| `/agentkey` | 主入口：数据查询时自动触发，通常不需要手动调用 |
| `/agentkey setup` | 初始安装：配置 API Key + 验证 MCP 连通性 |
| `/agentkey status` | 诊断当前配置状态（MCP、版本、连通性测试） |

还是解决不了？看下面"怎么获取帮助"那条。

</details>

<details>
<summary><b>进阶安装（CI / 指定 Agent / 手动两步）</b></summary>

安装器会自动探测本机已安装的 AI Agent（依据 [vercel-labs/skills 支持列表](https://github.com/vercel-labs/skills) 比对配置目录和命令行工具），自动选中它们 —— 不再弹多选框。需要覆盖时用下面的旗标：

**安装器参数：**

```bash
# 非交互模式（CI / 无人值守）：安装到所有检测到的 Agent，不询问
curl -fsSL https://agentkey.app/install.sh | bash -s -- --yes

# 看一下安装器在本机会自动选中哪些 Agent（看完即退出）
curl -fsSL https://agentkey.app/install.sh | bash -s -- --list-agents

# 只安装到指定的 Agent（覆盖自动检测结果）
curl -fsSL https://agentkey.app/install.sh | bash -s -- --only claude-code,cursor

# 跳过我们的检测，让 skills CLI 自己识别全部 Agent
curl -fsSL https://agentkey.app/install.sh | bash -s -- --all-agents

# 只装 Skill 或只做 MCP 授权
curl -fsSL https://agentkey.app/install.sh | bash -s -- --skip-mcp
curl -fsSL https://agentkey.app/install.sh | bash -s -- --skip-skill

# 即使本机已经配置过 AgentKey 也强制重新走一次授权
curl -fsSL https://agentkey.app/install.sh | bash -s -- --force-mcp
```

PowerShell 对应参数：`-Yes`、`-ListAgents`、`-Only`、`-AllAgents`、`-SkipMcp`、`-SkipSkill`、`-ForceMcp`。

**手动两步安装**（想自己跑两条底层命令，或一键脚本在你的环境里跑不起来）：

```bash
# 1. 把 Skill 装进所有检测到的 Agent
npx skills add chainbase-labs/agentkey

# 2. 浏览器授权并注册 MCP Server
npx -y @agentkey/cli --auth-login
```

</details>

<details>
<summary><b>在 SSH / Docker / OpenClaw 远程通道里安装</b></summary>

如果安装命令是在你看不到屏幕的机器上跑（远程 SSH 服务器、Docker 容器、由手机触发的 OpenClaw 运行时），默认 `--auth-login` 会在远端"成功"打开一个你看不见的浏览器，然后你只能盯着 "Waiting for authorization..." 卡死。

安装器会自动识别这种场景，切换到"扫码授权"流程：终端里直接打印授权 URL 加二维码，不再尝试本地开浏览器。**触发条件**（任一命中即判定为远程）：

- `~/.openclaw/` 目录存在（OpenClaw 运行时）
- `$SSH_CONNECTION` / `$SSH_TTY` 已设置
- Linux 且无 `$DISPLAY` / `$WAYLAND_DISPLAY`

需要强制其中一种模式：

```bash
# 强制远程模式（URL + 二维码，不开浏览器）
curl -fsSL https://agentkey.app/install.sh | bash -s -- --remote

# 强制本地模式（自动开浏览器，无视启发式判断）
curl -fsSL https://agentkey.app/install.sh | bash -s -- --local
```

PowerShell：`-Remote` / `-Local`。

如果完全不想走 URL/二维码流程、想自己手动粘 Key，可以用 `npx -y @agentkey/cli --setup` —— 交互式向导，问你要 Key 并让你勾选要写入的 MCP 客户端。

</details>

<details>
<summary><b>我的 Agent 没被自动配置，怎么手动设置？</b></summary>

MCP 自动配置覆盖 **Claude Code**、**Claude Desktop**、**Cursor**。如果你用的是 **Codex / OpenCode / Gemini CLI / Hermes / Manus**（或 Linux 版 Claude Desktop），Skill 会正常装上，但你需要把下面这段 MCP 片段手动贴到该 Agent 的配置里（路径因 Agent 而异）：

```json
{
  "mcpServers": {
    "agentkey": {
      "type": "http",
      "url": "https://api.agentkey.app/v1/mcp",
      "headers": { "Authorization": "Bearer ak_..." }
    }
  }
}
```

写完后重启 Agent。你第一次在对话里触发 Skill 时，它也会引导你走这一步。

</details>

<details>
<summary><b>能自托管 / 本地开发吗？</b></summary>

**从本地 checkout 安装：**

```bash
git clone https://github.com/chainbase-labs/agentkey.git
cd agentkey

# 1. 把当前工作副本装进所有检测到的 Agent
npx skills add .

# 2. 注册 MCP Server（只需一次）
npx -y @agentkey/cli --auth-login
```

`npx skills add .` 支持本地路径（也支持 `file://` URL），改完 `skills/agentkey/SKILL.md` 再跑一次就能立刻生效，是日常迭代最快的路径。MCP 注册步骤每台机器只需一次。

**想改 MCP Server 本身？** Server 托管在 `https://api.agentkey.app/v1/mcp`。把 MCP 配置里的 `url` 改成你本机起的实例（例如 `http://localhost:8787/v1/mcp`），具体本地运行步骤参考 `AgentKey-Server` 仓库的 README。

**Claude Code 插件模式** —— 把仓库当成本地 marketplace 安装：

```bash
claude plugin marketplace add /absolute/path/to/agentkey
claude plugin install agentkey
```

编辑文件后 `claude plugin update agentkey` 重新加载。日常 Skill 调整用 skills CLI 就够；只有在验证 Claude Code 插件内部机制（例如 `CLAUDE_PLUGIN_OPTION_*` 环境变量接线）时才走插件路径。

**仓库结构：**

```
agentkey/
├── .claude-plugin/plugin.json   # Claude Code 插件清单
├── .mcp.json                    # 作为插件安装时使用
├── skills/agentkey/
│   ├── SKILL.md                 # 决策树 & 路由规则
│   ├── scripts/                 # check-mcp / check-update 辅助脚本
│   └── version.txt              # 由 release-please 自动维护
└── scripts/
    ├── install.sh               # 一键安装脚本（mac/linux）
    ├── install.ps1              # Windows PowerShell 安装脚本
    ├── uninstall.sh             # 一键卸载脚本（mac/linux）
    └── uninstall.ps1            # Windows PowerShell 卸载脚本
```

**发布新版本（Maintainer）：** 发版由 [release-please](https://github.com/googleapis/release-please) 自动触发。合并一个 `feat:` 或 `fix:` 的 PR 后，release-please 会开一个 Release PR，自动 bump `skills/agentkey/version.txt`、`plugin.json`、`CHANGELOG.md`。合并这个 Release PR 即会创建 tag + GitHub Release + 上传 `agentkey.skill` 产物。

</details>

<details>
<summary><b>目前产品是什么阶段？</b></summary>

早期内测阶段，产品仍有不少不完善之处，还请担待。功能建议与问题反馈欢迎通过 [GitHub Issues](https://github.com/chainbase-labs/agentkey/issues) 或下面的 Telegram 与我们联系。

</details>

<details>
<summary><b>怎么获取帮助 / 反馈 bug / 关注更新？</b></summary>

- **Telegram：** [t.me/AgentKey_Official](https://t.me/AgentKey_Official) —— 通用咨询、支持、需求反馈
- **问题反馈：** [GitHub Issues](https://github.com/chainbase-labs/agentkey/issues)
- **发布公告：** ⭐ Star 本项目即可在有新版本时收到通知

</details>

---

[![Star History Chart](https://api.star-history.com/svg?repos=chainbase-labs/agentkey&type=Date)](https://www.star-history.com/?repos=chainbase-labs%2Fagentkey&type=date&legend=top-left)
