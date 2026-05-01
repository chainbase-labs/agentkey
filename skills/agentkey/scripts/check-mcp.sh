#!/bin/bash
# AgentKey — Check MCP registration and API key status
#
# Output codes:
#   MCP_OK             — server registered and API key found
#   MCP_NO_KEY         — server registered but API key not found anywhere
#   MCP_NOT_CONFIGURED — server not registered at all
set -e

# --- Helper: check all known key locations ---
check_key_exists() {
    # 1. Check ~/.claude.json MCP env (set by `claude mcp add -e AGENTKEY_API_KEY=...`)
    #    This is the primary cross-platform storage — works on Mac, Linux, and Windows.
    if [ -f "$HOME/.claude.json" ]; then
        local key_val
        key_val=$(python3 -c "
import json, os
try:
    with open(os.path.expanduser('~/.claude.json')) as f:
        d = json.load(f)
    print(d.get('mcpServers', {}).get('agentkey', {}).get('env', {}).get('AGENTKEY_API_KEY', ''))
except Exception: pass
" 2>/dev/null | tr -d '[:space:]')
        [ -n "$key_val" ] && return 0
    fi

    # 2. Check ~/.env.local (Mac/Linux fallback, written by setup-key.sh)
    local env_file="$HOME/.env.local"
    if [ -f "$env_file" ]; then
        local key_val
        key_val=$(grep "^AGENTKEY_API_KEY=" "$env_file" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"' | tr -d "'" | tr -d '[:space:]')
        [ -n "$key_val" ] && return 0
    fi

    return 1
}

# --- Helper: check a JSON config file for agentkey MCP registration ---
check_json_registered() {
    local file="$1"
    [ -f "$file" ] || return 1
    grep -q "mcpServers" "$file" 2>/dev/null || return 1
    grep -q '"agentkey"' "$file" 2>/dev/null || return 1
    return 0
}

# --- Helper: find claude CLI ---
find_claude() {
    command -v claude 2>/dev/null && return 0
    for p in "$HOME/.local/bin/claude" "/usr/local/bin/claude" \
             "/opt/homebrew/bin/claude" "$HOME/.npm-global/bin/claude"; do
        [ -x "$p" ] && echo "$p" && return 0
    done
    return 1
}

# ============================================================
# Step 1: Is agentkey registered anywhere?
# ============================================================
REGISTERED=0

# Check ~/.claude.json (user-scope via `claude mcp add --scope user`)
if check_json_registered "$HOME/.claude.json"; then
    REGISTERED=1
fi

# Check project .mcp.json as fallback
if [ $REGISTERED -eq 0 ]; then
    CLAUDE_BIN=$(find_claude 2>/dev/null || true)
    if [ -n "$CLAUDE_BIN" ]; then
        MCP_LIST=$("$CLAUDE_BIN" mcp list 2>/dev/null || true)
        if echo "$MCP_LIST" | grep -q "agentkey"; then
            REGISTERED=1
        fi
    fi
fi

if [ $REGISTERED -eq 0 ]; then
    echo "MCP_NOT_CONFIGURED"
    exit 1
fi

# ============================================================
# Step 2: Is the API key present anywhere?
# ============================================================
if check_key_exists; then
    echo "MCP_OK"
    exit 0
fi

echo "MCP_NO_KEY"
exit 1
