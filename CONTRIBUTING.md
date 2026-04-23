# Contributing to AgentKey Skill

Thanks for your interest! This doc covers how to propose changes, the commit convention, and how releases are cut.

## Before You Start

- Read the [Code of Conduct](CODE_OF_CONDUCT.md)
- By submitting a pull request, you agree your contribution is licensed under [Apache 2.0](LICENSE)

## Local Development

```bash
git clone https://github.com/chainbase-labs/agentkey.git
cd agentkey

# Install the skill into your local agent for testing
npx skills add .
```

See `scripts/install.sh` / `scripts/install.ps1` for the end-user install path, and `skills/agentkey/SKILL.md` for the skill contract.

## Making Changes

1. Fork and create a feature branch off `main`
2. Make your changes (keep PRs focused — one concern per PR)
3. Open a PR with a Conventional Commits title (see below)
4. Ensure CI passes (commitlint validates your PR title)
5. A maintainer will review and merge

## Conventional Commits

PR titles **must** follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(optional-scope): <description>
```

**Types:**
- `feat:` — new user-facing feature
- `fix:` — bug fix
- `docs:` — documentation only
- `chore:` — tooling, build, dependencies
- `refactor:` — code restructure, no behavior change
- `test:` — test additions/changes
- `ci:` — CI config
- `perf:` — performance improvement
- `style:` — formatting only

**Breaking changes:** add `!` after the type (`feat!: ...`) and explain in the PR body.

**Examples:**
- `feat: add Reddit post search`
- `fix: correct MCP path detection on Windows`
- `docs(readme): update install instructions`
- `feat!: remove deprecated v1 API`

Individual commit messages inside a PR are not validated — the PR title is what matters because all PRs are **squash-merged** using the PR title as the commit message.

## Release Process

Releases are cut automatically by [release-please](https://github.com/googleapis/release-please) based on Conventional Commits on `main`. Contributors never run `git tag` or publish manually.

When conventional commits accumulate on `main`, release-please opens a "Release PR" that bumps `version` / `plugin.json` / `CHANGELOG.md`. Merging that PR cuts the GitHub Release and tag.

## Reporting Bugs and Requesting Features

Use the [issue templates](https://github.com/chainbase-labs/agentkey/issues/new/choose).

For security issues, **do not open a public issue**. Email `support@chainbase.com` — see [SECURITY.md](SECURITY.md).

