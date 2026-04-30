#!/bin/bash
# AgentKey — Notify when a newer release is available on GitHub.
# Notify-only: this script never modifies the install. It tells the agent
# there's a new version; the user runs the update manually.
#
# Result cached in TMPDIR to keep repeat skill invocations fast.
#
# Outputs a single line, or nothing:
#   UP_TO_DATE                       — local matches latest release
#   UPGRADE_AVAILABLE <old> <new>    — local differs from latest release
#   (empty / silent)                 — no version file, network down, or
#                                      unexpected response (we retry next time)

REPO="chainbase-labs/agentkey"
CACHE_TTL_UP_TO_DATE=3600     # 60 min — detect new releases quickly
CACHE_TTL_UPGRADE=43200       # 12 h — keep nagging once an upgrade is known
CURL_TIMEOUT=3

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"
VERSION_FILE="$PLUGIN_ROOT/version.txt"
CACHE_FILE="${TMPDIR:-/tmp}/agentkey-update-check"

LOCAL_VERSION=$(tr -d '[:space:]' < "$VERSION_FILE" 2>/dev/null)
if [ -z "$LOCAL_VERSION" ]; then
    exit 0
fi

# Fast path: recent cache hit — avoids the GitHub API round-trip (~1.5s).
if [ -f "$CACHE_FILE" ]; then
    MTIME=$(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    AGE=$(( $(date +%s) - MTIME ))
    CACHED=$(head -1 "$CACHE_FILE" 2>/dev/null || true)
    case "$CACHED" in
        "UP_TO_DATE")          TTL=$CACHE_TTL_UP_TO_DATE ;;
        "UPGRADE_AVAILABLE "*) TTL=$CACHE_TTL_UPGRADE ;;
        *)                     TTL=0 ;;
    esac
    if [ "$AGE" -ge 0 ] && [ "$AGE" -lt "$TTL" ]; then
        # Cached UPGRADE_AVAILABLE may be stale w.r.t. the local version (user
        # might have updated since we cached). Re-emit only if old still matches.
        case "$CACHED" in
            "UP_TO_DATE")
                echo "UP_TO_DATE"
                exit 0
                ;;
            "UPGRADE_AVAILABLE "*)
                CACHED_OLD=$(echo "$CACHED" | awk '{print $2}')
                if [ "$CACHED_OLD" = "$LOCAL_VERSION" ]; then
                    echo "$CACHED"
                    exit 0
                fi
                # Local moved on — fall through to re-check.
                ;;
        esac
    fi
fi

# Slow path: fetch latest release tag from GitHub.
LATEST_TAG=$(curl -sf --max-time "$CURL_TIMEOUT" \
    "https://api.github.com/repos/$REPO/releases/latest" 2>/dev/null \
    | grep -m1 '"tag_name"' \
    | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
LATEST_VERSION=${LATEST_TAG#[vV]}

# Validate response looks like a version number — rejects HTML error pages,
# rate-limit JSON, and other surprises that slipped past curl -f.
if ! echo "$LATEST_VERSION" | grep -qE '^[0-9]+\.[0-9.]+$'; then
    # Network failure or unexpected response — stay silent and don't cache,
    # so the next call retries.
    exit 0
fi

if [ "$LOCAL_VERSION" = "$LATEST_VERSION" ]; then
    echo "UP_TO_DATE" > "$CACHE_FILE" 2>/dev/null
    echo "UP_TO_DATE"
    exit 0
fi

# Newer version available — notify only. Never modifies the install.
MSG="UPGRADE_AVAILABLE $LOCAL_VERSION $LATEST_VERSION"
echo "$MSG" > "$CACHE_FILE" 2>/dev/null
echo "$MSG"
