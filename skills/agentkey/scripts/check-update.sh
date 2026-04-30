#!/bin/bash
# AgentKey — Notify when a newer release is available on GitHub.
# Notify-only: this script never modifies the install. It tells the agent
# there's a new version; the agent surfaces a prompt and (with the user's
# consent) invokes the upgrade.
#
# Result cached in TMPDIR for fast repeat invocations. Persistent state
# (snooze, disable, auto-upgrade flag) lives under ~/.config/agentkey/.
#
# Outputs a single line, or nothing:
#   UP_TO_DATE                       — local matches latest release
#   UPGRADE_AVAILABLE <old> <new>    — local differs from latest release
#                                      AND not currently snoozed/disabled
#   (empty / silent)                 — disabled, snoozed, no version file,
#                                      network down, or unexpected response

REPO="chainbase-labs/agentkey"
CACHE_TTL_UP_TO_DATE=3600     # 60 min — detect new releases quickly
CACHE_TTL_UPGRADE=43200       # 12 h — keep nagging once an upgrade is known
CURL_TIMEOUT=3

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." 2>/dev/null && pwd)}"
VERSION_FILE="$PLUGIN_ROOT/version.txt"
CACHE_FILE="${TMPDIR:-/tmp}/agentkey-update-check"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agentkey"
DISABLED_FILE="$CONFIG_DIR/update-disabled"
SNOOZE_FILE="$CONFIG_DIR/update-snoozed"

# Disabled by user ("Never ask again") — exit silently.
if [ -f "$DISABLED_FILE" ]; then
    exit 0
fi

LOCAL_VERSION=$(tr -d '[:space:]' < "$VERSION_FILE" 2>/dev/null)
if [ -z "$LOCAL_VERSION" ]; then
    exit 0
fi

# check_snooze <remote_version> → returns 0 (snoozed) or 1 (not snoozed).
# Snooze file format: "<version> <level> <epoch>" where level 1=24h, 2=48h, 3+=7d.
# A new remote version invalidates the snooze.
check_snooze() {
    local remote_ver="$1"
    [ -f "$SNOOZE_FILE" ] || return 1
    local sver slevel sepoch
    sver=$(awk '{print $1}' "$SNOOZE_FILE" 2>/dev/null)
    slevel=$(awk '{print $2}' "$SNOOZE_FILE" 2>/dev/null)
    sepoch=$(awk '{print $3}' "$SNOOZE_FILE" 2>/dev/null)
    [ -n "$sver" ] && [ -n "$slevel" ] && [ -n "$sepoch" ] || return 1
    case "$slevel" in *[!0-9]*) return 1 ;; esac
    case "$sepoch" in *[!0-9]*) return 1 ;; esac
    [ "$sver" = "$remote_ver" ] || return 1
    local duration
    case "$slevel" in
        1) duration=86400 ;;
        2) duration=172800 ;;
        *) duration=604800 ;;
    esac
    local now
    now=$(date +%s)
    [ $((sepoch + duration)) -gt "$now" ]
}

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
        case "$CACHED" in
            "UP_TO_DATE")
                echo "UP_TO_DATE"
                exit 0
                ;;
            "UPGRADE_AVAILABLE "*)
                CACHED_OLD=$(echo "$CACHED" | awk '{print $2}')
                if [ "$CACHED_OLD" = "$LOCAL_VERSION" ]; then
                    CACHED_NEW=$(echo "$CACHED" | awk '{print $3}')
                    if check_snooze "$CACHED_NEW"; then
                        exit 0
                    fi
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
    exit 0
fi

if [ "$LOCAL_VERSION" = "$LATEST_VERSION" ]; then
    echo "UP_TO_DATE" > "$CACHE_FILE" 2>/dev/null
    echo "UP_TO_DATE"
    exit 0
fi

# Newer version available — cache the result, then suppress output if snoozed.
MSG="UPGRADE_AVAILABLE $LOCAL_VERSION $LATEST_VERSION"
echo "$MSG" > "$CACHE_FILE" 2>/dev/null
if check_snooze "$LATEST_VERSION"; then
    exit 0
fi
echo "$MSG"
