#!/usr/bin/env bash
#
# dev-smoke.sh — sandboxed regression suite for installer + uninstaller + MCP
# writer strategies. Nothing in this script touches your real $HOME — every
# phase creates its own mktemp -d sandbox and tears it down on exit.
#
# Run before opening a PR that changes:
#   - scripts/install.sh / install.ps1
#   - scripts/uninstall.sh / uninstall.ps1
#   - AgentKey-Server/cli/src/lib/mcp-clients.ts
#   - The AGENT_REGISTRY contract in general
#
# Usage:
#   scripts/dev-smoke.sh                # run all phases
#   scripts/dev-smoke.sh 1              # run only phase 1
#   scripts/dev-smoke.sh 2 4            # run phases 2 and 4
#   AGENTKEY_CLI_SRC=/path/to/cli scripts/dev-smoke.sh   # override
#
# Phases:
#   1. Unit tests        — npm test in cli/ (registry + skill-meta)
#   2. Installer sandbox — --list-agents, --only edge cases (no real npx work)
#   3. Writers sandbox   — call every AGENT_REGISTRY writer; assert schemas
#   4. Uninstaller sandbox — scrub fakes; assert decoys preserved

# Keep `-e` off so one failing assertion does not stop the smoke run before the
# remaining phases report their own failures.
set -uo pipefail

# ── Locate repos ──────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_REPO="$(dirname "$SCRIPT_DIR")"

# Find the sibling AgentKey-Server/cli repo (the npm-published @agentkey/cli
# source). Try in order:
#   1. $AGENTKEY_CLI_SRC env var (manual override)
#   2. Direct sibling of skill repo (main worktree case)
#   3. Climb up from a git worktree (3 levels up from .claude/worktrees/<name>)
#   4. Fall back to a generic sibling path so the error message is actionable
_find_cli_src() {
    local cand
    for cand in \
        "${AGENTKEY_CLI_SRC:-}" \
        "$SKILL_REPO/../AgentKey-Server/cli" \
        "$SKILL_REPO/../../../../AgentKey-Server/cli"
    do
        [ -z "$cand" ] && continue
        if [ -d "$cand" ] && [ -f "$cand/package.json" ]; then
            (cd "$cand" && pwd); return
        fi
    done
    # Nothing found — return the first candidate so the error message
    # tells the user what we looked for.
    printf '%s\n' "${AGENTKEY_CLI_SRC:-$SKILL_REPO/../AgentKey-Server/cli}"
}
CLI_SRC="$(_find_cli_src)"

# ── UI ────────────────────────────────────────────────────────────────────
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    GREEN=$'\033[38;2;0;220;150m'; RED=$'\033[38;2;230;57;70m'
    YELLOW=$'\033[38;2;255;176;32m'; CYAN=$'\033[38;2;0;200;180m'
    DIM=$'\033[38;2;110;118;132m'; BOLD=$'\033[1m'; NC=$'\033[0m'
else
    GREEN=''; RED=''; YELLOW=''; CYAN=''; DIM=''; BOLD=''; NC=''
fi

PASS=0; FAIL=0; SKIP=0
FAIL_REASONS=()

ok()    { PASS=$((PASS+1)); printf "  ${GREEN}✓${NC} %s\n" "$*"; }
fail()  { FAIL=$((FAIL+1)); FAIL_REASONS+=("$*"); printf "  ${RED}✗${NC} %s\n" "$*"; }
skip()  { SKIP=$((SKIP+1)); printf "  ${DIM}-${NC} %s\n" "$*"; }
info()  { printf "  ${DIM}›${NC} %s\n" "$*"; }
phase() { printf "\n${CYAN}${BOLD}── %s ──${NC}\n" "$*"; }

assert_contains() {
    local name="$1" needle="$2" haystack="$3"
    if printf '%s' "$haystack" | grep -qF -- "$needle"; then
        ok "$name"
    else
        fail "$name (expected to contain '$needle')"
    fi
}

assert_not_contains() {
    local name="$1" needle="$2" haystack="$3"
    if printf '%s' "$haystack" | grep -qF -- "$needle"; then
        fail "$name (must NOT contain '$needle')"
    else
        ok "$name"
    fi
}

assert_file_has() {
    local name="$1" path="$2" needle="$3"
    if [ -f "$path" ] && grep -qF -- "$needle" "$path"; then
        ok "$name"
    else
        fail "$name (file $path missing or doesn't contain '$needle')"
    fi
}

# Sandbox helper: each phase calls `sandbox_init` to get a fresh tmpdir and
# `sandbox_clean` to tear it down. Trapped so Ctrl-C still cleans up.
SANDBOX=""
sandbox_init() {
    SANDBOX="$(mktemp -d -t agentkey-smoke.XXXXXX)"
    info "sandbox: $SANDBOX"
}
sandbox_clean() {
    [ -n "$SANDBOX" ] && [ -d "$SANDBOX" ] && rm -rf "$SANDBOX"
    SANDBOX=""
}
trap 'sandbox_clean' EXIT INT TERM

# ──────────────────────────────────────────────────────────────────────────
# Phase 1: Unit tests
# ──────────────────────────────────────────────────────────────────────────
phase_1() {
    phase "Phase 1: Unit tests (cli)"
    if [ ! -d "$CLI_SRC" ]; then
        skip "@agentkey/cli source not found at $CLI_SRC — set AGENTKEY_CLI_SRC to override"
        return
    fi

    # Subshells under nvm often fall back to an older default Node, even when
    # the parent shell has a current one. `node:test` (used by tsx --test)
    # needs Node 18+. Detect explicitly and skip with a hint rather than
    # surfacing a cryptic "bad option: --test" error.
    local node_major
    node_major="$(cd "$CLI_SRC" && node --version 2>/dev/null | sed -nE 's/^v([0-9]+).*/\1/p')"
    if [ -z "$node_major" ]; then
        skip "node not found in cli subshell"
        return
    fi
    if [ "$node_major" -lt 18 ] 2>/dev/null; then
        skip "subshell Node is v$node_major (need >=18). Try: \`nvm alias default 20\` or \`nvm use 20\` then re-run."
        return
    fi

    info "running: cd $CLI_SRC && npm test  (node v$node_major)"
    local out
    if out="$(cd "$CLI_SRC" && npm test 2>&1)"; then
        local count
        count="$(printf '%s' "$out" | sed -nE 's/.*tests ([0-9]+).*/\1/p' | head -1)"
        if printf '%s' "$out" | grep -qE 'fail (0|0$)'; then
            ok "all $count tests pass"
        else
            fail "npm test reported failures"
            printf '%s\n' "$out" | tail -10
        fi
    else
        fail "npm test exited non-zero"
        if printf '%s' "$out" | grep -q 'bad option: --test'; then
            info "hint: a child process picked up an older Node. Check \`which node\` inside $CLI_SRC."
        fi
        printf '%s\n' "$out" | tail -15
    fi
}

# ──────────────────────────────────────────────────────────────────────────
# Phase 2: Installer sandbox — exercise install.sh logic without network
# ──────────────────────────────────────────────────────────────────────────
phase_2() {
    phase "Phase 2: Installer sandbox"
    sandbox_init

    # Seed enough markers so detect_agents() finds a varied set.
    mkdir -p "$SANDBOX/.cursor" \
             "$SANDBOX/.codex" \
             "$SANDBOX/.gemini" \
             "$SANDBOX/.qwen" \
             "$SANDBOX/Library/Application Support/Claude"
    touch "$SANDBOX/.claude.json"

    # Test 1: --list-agents output shape
    info "test: --list-agents"
    local listed
    listed="$(HOME="$SANDBOX" bash "$SKILL_REPO/scripts/install.sh" --list-agents 2>&1)"
    assert_contains "lists claude-code"        "claude-code"    "$listed"
    assert_contains "lists claude-desktop"     "claude-desktop" "$listed"
    assert_contains "lists cursor"             "cursor"         "$listed"
    assert_contains "lists codex"              "codex"          "$listed"
    assert_contains "lists gemini-cli"         "gemini-cli"     "$listed"
    assert_contains "lists qwen-code"          "qwen-code"      "$listed"

    # Test 2: --only claude-desktop must skip the skill step (MCP-only edge case)
    info "test: --only claude-desktop --skip-mcp --yes  (edge case)"
    local out
    out="$(HOME="$SANDBOX" bash "$SKILL_REPO/scripts/install.sh" \
        --only claude-desktop --skip-mcp --yes 2>&1)"
    assert_contains  "skill step skipped for MCP-only ids" \
        "MCP-only (no skill install path)" "$out"
    assert_contains  "MCP step skipped via --skip-mcp"    "Skipped (--skip-mcp)" "$out"
    assert_not_contains "no skills add invocation"         "Running: npx"        "$out"

    # Test 3: auto-detect path doesn't crash under set -u (the $TARGETS bug repro)
    info "test: auto-detect with --skip-skill --skip-mcp --yes"
    out="$(HOME="$SANDBOX" bash "$SKILL_REPO/scripts/install.sh" \
        --skip-skill --skip-mcp --yes 2>&1)"
    assert_contains "auto-detect runs"   "Detected agents on this host" "$out"
    assert_contains "claude-desktop detected" "claude-desktop"           "$out"
    assert_not_contains "no unbound var error" "unbound variable"        "$out"

    sandbox_clean
}

# ──────────────────────────────────────────────────────────────────────────
# Phase 3: Writers sandbox — exercise every AGENT_REGISTRY writer
# ──────────────────────────────────────────────────────────────────────────
phase_3() {
    phase "Phase 3: MCP writer schemas"
    if [ ! -d "$CLI_SRC" ]; then
        skip "MCP server not at $CLI_SRC — skipping writer tests"
        return
    fi

    # Ensure dist/ is fresh.
    info "rebuilding cli dist/..."
    if ! (cd "$CLI_SRC" && npm run build >/dev/null 2>&1); then
        fail "npm run build failed"
        return
    fi

    sandbox_init

    # Run every file-write strategy (skip CLI-only ones since those would
    # need real `droid` / `openclaw` binaries on PATH).
    info "running writers for every JSON / TOML agent..."
    local runner="$SANDBOX/runner.mjs"
    cat > "$runner" <<'EOF'
import { pathToFileURL } from "node:url";

const cliModule = process.env.AGENTKEY_CLI_MODULE;
if (!cliModule) {
  throw new Error("AGENTKEY_CLI_MODULE is required");
}
const { AGENT_REGISTRY, writeAgentConfig } = await import(pathToFileURL(cliModule).href);

const SKIP_IDS = new Set(["claude-code", "droid", "openclaw"]);
const ctx = { apiKey: "ak_test_smoke", baseUrl: "https://api.agentkey.app" };

let written = 0, failed = 0;
for (const spec of AGENT_REGISTRY) {
  if (SKIP_IDS.has(spec.id)) { console.log("SKIP " + spec.id); continue; }
  const r = await writeAgentConfig(spec.id, ctx);
  if (r.ok) { written++; console.log("OK   " + spec.id + " -> " + r.detail); }
  else      { failed++;  console.log("ERR  " + spec.id + " -> " + r.error); }
}
console.log("---");
console.log("written=" + written + " failed=" + failed);
EOF
    local writer_out
    writer_out="$(AGENTKEY_CLI_MODULE="$CLI_SRC/dist/lib/mcp-clients.js" HOME="$SANDBOX" node "$runner" 2>&1)"
    if printf '%s' "$writer_out" | grep -q '^ERR '; then
        fail "some writers reported errors:"
        printf '%s\n' "$writer_out" | grep '^ERR '
    else
        ok "every writer reported success"
    fi

    # Schema assertions on the files that landed.
    info "asserting per-agent schemas..."

    # Claude Desktop / Cursor / Gemini / Windsurf / Warp / Qwen / iFlow /
    # Kimi / Kiro all use the same {mcpServers: {agentkey: {command, args, env}}}
    # shape — spot-check a couple.
    assert_file_has "claude-desktop mcpServers.agentkey" \
        "$SANDBOX/Library/Application Support/Claude/claude_desktop_config.json" \
        '"agentkey"'
    assert_file_has "cursor command=npx" \
        "$SANDBOX/.cursor/mcp.json" '"command": "npx"'
    assert_file_has "gemini-cli env API_KEY" \
        "$SANDBOX/.gemini/settings.json" '"AGENTKEY_API_KEY": "ak_test_smoke"'

    # OpenCode — the schema differs: array command + 'environment' (not 'env'),
    # under top-level 'mcp' (not 'mcpServers').
    local oc="$SANDBOX/.config/opencode/opencode.json"
    assert_file_has "opencode uses 'mcp' key"           "$oc" '"mcp":'
    assert_file_has "opencode command is array"         "$oc" '"command": ['
    assert_file_has "opencode uses 'environment' key"   "$oc" '"environment":'
    if grep -q '"mcpServers"' "$oc" 2>/dev/null; then
        fail "opencode must NOT use mcpServers key"
    else
        ok "opencode does not leak mcpServers"
    fi

    # Amp — flat dotted key, not nested.
    local amp="$SANDBOX/.config/amp/settings.json"
    assert_file_has "amp uses flat 'amp.mcpServers' key" "$amp" '"amp.mcpServers":'

    # Crush — mcp.<name> with type:stdio.
    local crush="$SANDBOX/.config/crush/crush.json"
    assert_file_has "crush uses 'mcp' key"     "$crush" '"mcp":'
    assert_file_has "crush has type:stdio"     "$crush" '"type": "stdio"'

    # Codex — TOML.
    local codex="$SANDBOX/.codex/config.toml"
    assert_file_has "codex header [mcp_servers.agentkey]" "$codex" '[mcp_servers.agentkey]'
    assert_file_has "codex env table"          "$codex" 'AGENTKEY_API_KEY = "ak_test_smoke"'

    # Idempotency check — re-run all writers and make sure nothing duplicates.
    info "idempotency: re-running every writer..."
    AGENTKEY_CLI_MODULE="$CLI_SRC/dist/lib/mcp-clients.js" HOME="$SANDBOX" node "$runner" >/dev/null 2>&1
    local agentkey_count
    agentkey_count="$(grep -c '\[mcp_servers\.agentkey\]' "$codex" 2>/dev/null)"
    if [ "$agentkey_count" = "1" ]; then
        ok "codex stanza appears exactly once after double-write"
    else
        fail "codex agentkey stanza count after double-write: $agentkey_count (expected 1)"
    fi

    sandbox_clean
}

# ──────────────────────────────────────────────────────────────────────────
# Phase 4: Uninstaller sandbox — assert decoys are preserved
# ──────────────────────────────────────────────────────────────────────────
phase_4() {
    phase "Phase 4: Uninstaller sandbox"
    sandbox_init

    # ── Decoy fixtures ────────────────────────────────────────────────────
    # Each fixture mixes a legit agentkey entry with one we MUST NOT touch.
    mkdir -p "$SANDBOX/.cursor" \
             "$SANDBOX/.config/opencode" \
             "$SANDBOX/.config/amp" \
             "$SANDBOX/.config/crush" \
             "$SANDBOX/.codex" \
             "$SANDBOX/.gemini"

    # Cursor: standard mcpServers + a decoy user key containing "agentkey".
    cat > "$SANDBOX/.cursor/mcp.json" <<'EOF'
{
  "mcpServers": {
    "agentkey": { "command": "npx", "args": ["-y", "@agentkey/cli"] },
    "agentkey-helper": { "command": "x" },
    "other-svr": { "command": "y" }
  }
}
EOF

    # OpenCode: mcp.<name> dialect.
    cat > "$SANDBOX/.config/opencode/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "agentkey": { "type": "local", "command": ["npx", "-y", "@agentkey/cli"] },
    "user-svr": { "type": "local", "command": ["x"] }
  }
}
EOF

    # Amp: flat dotted key.
    cat > "$SANDBOX/.config/amp/settings.json" <<'EOF'
{
  "amp.mcpServers": {
    "agentkey": { "command": "npx" },
    "my-svr": { "command": "y" }
  }
}
EOF

    # Crush: mcp.<name> + type:stdio.
    cat > "$SANDBOX/.config/crush/crush.json" <<'EOF'
{
  "mcp": {
    "agentkey": { "type": "stdio", "command": "npx" },
    "keep": { "type": "stdio", "command": "z" }
  }
}
EOF

    # Codex TOML: agentkey block + legacy quoted block + unrelated sections.
    cat > "$SANDBOX/.codex/config.toml" <<'EOF'
model = "gpt-5.1"

[mcp_servers.other]
command = "other"
args = []

[mcp_servers.agentkey]
command = "npx"
args = ["-y", "@agentkey/cli"]
env = { AGENTKEY_API_KEY = "ak_xxx" }

[mcp_servers."agentkey.app AgentKey"]
command = "legacy"

[unrelated_section]
key = "val"
EOF

    # Gemini: claude-code per-project shape simulator (nested).
    cat > "$SANDBOX/.claude.json" <<'EOF'
{
  "mcpServers": { "agentkey": { "command": "npx" } },
  "projects": {
    "/path/a": {
      "mcpServers": {
        "agentkey": { "command": "npx" },
        "user-server": { "command": "keep" }
      }
    }
  }
}
EOF

    # ── Run the uninstaller in the sandbox ────────────────────────────────
    info "running uninstall.sh --skip-skill-remove --force-in-repo"
    HOME="$SANDBOX" bash "$SKILL_REPO/scripts/uninstall.sh" \
        --skip-skill-remove --force-in-repo >/dev/null 2>&1 || true

    # ── Assertions: agentkey gone, decoys preserved ───────────────────────
    info "checking: agentkey entries scrubbed"
    assert_not_contains "cursor: agentkey removed" '"agentkey":' "$(cat "$SANDBOX/.cursor/mcp.json")"
    assert_not_contains "opencode: agentkey removed" '"agentkey":' "$(cat "$SANDBOX/.config/opencode/opencode.json")"
    assert_not_contains "amp: agentkey removed" '"agentkey":' "$(cat "$SANDBOX/.config/amp/settings.json")"
    assert_not_contains "crush: agentkey removed" '"agentkey":' "$(cat "$SANDBOX/.config/crush/crush.json")"
    assert_not_contains "codex: agentkey block removed" \
        '[mcp_servers.agentkey]' "$(cat "$SANDBOX/.codex/config.toml")"
    assert_not_contains "codex: legacy block removed" \
        'agentkey.app AgentKey' "$(cat "$SANDBOX/.codex/config.toml")"

    info "checking: decoy user entries preserved"
    assert_contains "cursor: agentkey-helper kept (false-positive guard)" \
        "agentkey-helper" "$(cat "$SANDBOX/.cursor/mcp.json")"
    assert_contains "cursor: other-svr kept" \
        "other-svr" "$(cat "$SANDBOX/.cursor/mcp.json")"
    assert_contains "opencode: user-svr kept" \
        "user-svr" "$(cat "$SANDBOX/.config/opencode/opencode.json")"
    assert_contains "amp: my-svr kept" \
        "my-svr" "$(cat "$SANDBOX/.config/amp/settings.json")"
    assert_contains "crush: keep kept" \
        '"keep"' "$(cat "$SANDBOX/.config/crush/crush.json")"
    assert_contains "codex: [mcp_servers.other] kept" \
        "[mcp_servers.other]" "$(cat "$SANDBOX/.codex/config.toml")"
    assert_contains "codex: [unrelated_section] kept" \
        "[unrelated_section]" "$(cat "$SANDBOX/.codex/config.toml")"
    assert_contains "codex: top-level model= kept" \
        'model = "gpt-5.1"' "$(cat "$SANDBOX/.codex/config.toml")"
    assert_contains "claude.json: per-project user-server kept" \
        "user-server" "$(cat "$SANDBOX/.claude.json")"

    sandbox_clean
}

# ──────────────────────────────────────────────────────────────────────────
# Driver
# ──────────────────────────────────────────────────────────────────────────
main() {
    local selected=("$@")
    if [ ${#selected[@]} -eq 0 ]; then
        selected=(1 2 3 4)
    fi

    printf "${BOLD}AgentKey dev-smoke${NC}\n"
    printf "  ${DIM}skill repo:${NC} %s\n" "$SKILL_REPO"
    printf "  ${DIM}cli:${NC} %s\n" "$CLI_SRC"

    for n in "${selected[@]}"; do
        case "$n" in
            1) phase_1 ;;
            2) phase_2 ;;
            3) phase_3 ;;
            4) phase_4 ;;
            *) echo "Unknown phase: $n (valid: 1-4)" >&2 ;;
        esac
    done

    # ── Summary ───────────────────────────────────────────────────────────
    printf "\n${BOLD}Summary${NC}\n"
    printf "  ${GREEN}pass:${NC} %d   ${RED}fail:${NC} %d   ${DIM}skip:${NC} %d\n" \
        "$PASS" "$FAIL" "$SKIP"
    if [ "$FAIL" -gt 0 ]; then
        printf "\n${RED}${BOLD}Failures:${NC}\n"
        for r in "${FAIL_REASONS[@]}"; do
            printf "  ${RED}-${NC} %s\n" "$r"
        done
        exit 1
    fi
    printf "\n${GREEN}${BOLD}All green.${NC} Ready to PR.\n"
    exit 0
}

main "$@"
