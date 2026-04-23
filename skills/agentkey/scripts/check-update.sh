#!/bin/bash
# AgentKey — Auto-update to latest GitHub Release.
# Result cached in TMPDIR to keep repeat skill invocations fast.
# Outputs a single line: UP_TO_DATE | UPDATED: vX.Y.Z | UPDATE_FAILED: <reason>

REPO="chainbase-labs/agentkey"
CACHE_TTL_SUCCESS=86400   # 24h for UP_TO_DATE
CACHE_TTL_FAILURE=3600    # 1h for UPDATE_FAILED (retry sooner)
CURL_TIMEOUT=3

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"
VERSION_FILE="$PLUGIN_ROOT/version"
CACHE_FILE="${TMPDIR:-/tmp}/agentkey-update-check"

LOCAL_VERSION=$(tr -d '[:space:]' < "$VERSION_FILE" 2>/dev/null)
if [ -z "$LOCAL_VERSION" ]; then
    echo "UP_TO_DATE"
    exit 0
fi

# Fast path: recent cache hit — avoids the GitHub API round-trip (~1.5s).
if [ -f "$CACHE_FILE" ]; then
    MTIME=$(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    AGE=$(( $(date +%s) - MTIME ))
    case "$(head -1 "$CACHE_FILE" 2>/dev/null)" in
        "UPDATE_FAILED:"*) TTL=$CACHE_TTL_FAILURE ;;
        *)                 TTL=$CACHE_TTL_SUCCESS ;;
    esac
    if [ "$AGE" -ge 0 ] && [ "$AGE" -lt "$TTL" ]; then
        cat "$CACHE_FILE"
        exit 0
    fi
fi

# Remote check — fetch latest release tag.
LATEST_TAG=$(curl -sf --max-time "$CURL_TIMEOUT" \
    "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
    | grep -m1 '"tag_name"' \
    | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
LATEST_VERSION=${LATEST_TAG#[vV]}

# Network failure — stay silent; skip caching so we retry on the next call.
if [ -z "$LATEST_VERSION" ]; then
    echo "UP_TO_DATE"
    exit 0
fi

# Already current.
if [ "$LOCAL_VERSION" = "$LATEST_VERSION" ]; then
    echo "UP_TO_DATE" > "$CACHE_FILE" 2>/dev/null
    echo "UP_TO_DATE"
    exit 0
fi

# Newer version available — attempt git auto-update.
# Shallow-fetch only the target tag (not all tags) for speed.
if [ -d "$PLUGIN_ROOT/.git" ]; then
    if git -C "$PLUGIN_ROOT" fetch --quiet --depth=1 origin \
           "+refs/tags/$LATEST_TAG:refs/tags/$LATEST_TAG" 2>/dev/null \
       && git -C "$PLUGIN_ROOT" checkout --quiet "$LATEST_TAG" 2>/dev/null; then
        # After a successful checkout, subsequent checks are UP_TO_DATE.
        echo "UP_TO_DATE" > "$CACHE_FILE" 2>/dev/null
        echo "UPDATED: v$LATEST_VERSION"
        exit 0
    fi
fi

MSG="UPDATE_FAILED: Run \`/plugin update agentkey\` to update to v$LATEST_VERSION"
echo "$MSG" > "$CACHE_FILE" 2>/dev/null
echo "$MSG"
