# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.1](https://github.com/chainbase-labs/Agentkey/compare/v1.2.0...v1.2.1) (2026-05-01)


### Bug Fixes

* **security:** notify-only update check + interactive upgrade flow ([#21](https://github.com/chainbase-labs/Agentkey/issues/21)) ([a05efd5](https://github.com/chainbase-labs/Agentkey/commit/a05efd565f2cce3d66ff7beec32ba8be0fc8dbb4))

## [1.2.0](https://github.com/chainbase-labs/Agentkey/compare/v1.1.0...v1.2.0) (2026-04-27)


### Features

* **install:** auto-detect agents, route MCP auth to QR mode for remote installs ([#18](https://github.com/chainbase-labs/Agentkey/issues/18)) ([29176d1](https://github.com/chainbase-labs/Agentkey/commit/29176d1aae5ba05ee64b402e8f2e2635df31c4ed))

## [1.1.0](https://github.com/chainbase-labs/agentkey/compare/agentkey-skill-v1.0.0...agentkey-skill-v1.1.0) (2026-04-23)


### Features

* cache update check result for 24h ([#5](https://github.com/chainbase-labs/agentkey/issues/5)) ([27e0ebe](https://github.com/chainbase-labs/agentkey/commit/27e0ebe20e3af26667ff852a318b2f8439964372))

## [1.0.0] - 2026-04-22

Initial public release.

### Added
- Unified AgentKey Skill for Claude Code, Claude Desktop, Cursor, and other Skills-CLI-compatible agents
- Coverage: 12 social media platforms (Twitter/X, Reddit, 小红书, Instagram, 知乎, TikTok, 抖音, B站, 微博, Threads, YouTube, LinkedIn), web search, web scraping, crypto/blockchain data
- One-command installers: `scripts/install.sh` (macOS/Linux) and `scripts/install.ps1` (Windows)
- `npx skills add chainbase-labs/agentkey` as the Skills-CLI install path
- MCP server registration via `npx -y @agentkey/mcp --auth-login`
