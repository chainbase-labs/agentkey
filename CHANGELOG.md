# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0](https://github.com/chainbase-labs/Agentkey/compare/v1.2.4...v1.3.0) (2026-05-12)


### Features

* **skill:** broaden description for dynamic provider catalog ([#32](https://github.com/chainbase-labs/Agentkey/issues/32)) ([3b45366](https://github.com/chainbase-labs/Agentkey/commit/3b453662635d0246b17d01de0f02fdd917ceaec9))

## [1.2.4](https://github.com/chainbase-labs/Agentkey/compare/v1.2.3...v1.2.4) (2026-05-09)


### Bug Fixes

* **skill:** eliminate Hermes scanner findings ([#28](https://github.com/chainbase-labs/Agentkey/issues/28)) ([41e1724](https://github.com/chainbase-labs/Agentkey/commit/41e172486acbe593e8df5977c68f72d28a5f84ff))

## [1.2.3](https://github.com/chainbase-labs/Agentkey/compare/v1.2.2...v1.2.3) (2026-05-08)


### Bug Fixes

* **update-check:** ship version.txt inside skill so npx-skills-add installs find it ([#26](https://github.com/chainbase-labs/Agentkey/issues/26)) ([bc740c8](https://github.com/chainbase-labs/Agentkey/commit/bc740c80154720c29cf5ec6df5773f030bd868c9))

## [1.2.2](https://github.com/chainbase-labs/Agentkey/compare/v1.2.1...v1.2.2) (2026-05-08)


### Bug Fixes

* republish skill with updated find_tools guidance ([#24](https://github.com/chainbase-labs/Agentkey/issues/24)) ([b7d3a80](https://github.com/chainbase-labs/Agentkey/commit/b7d3a80fffb610c2358dfc370b57e458873aef8f))

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
