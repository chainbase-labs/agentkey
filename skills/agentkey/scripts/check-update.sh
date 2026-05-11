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
#   (empty / silent)                 — disabled, snoozed, embedded version
#                                      malformed, network down, or unexpected
#                                      response

# Strict-ish mode: catch unset vars and silent pipe failures. We deliberately
# do *not* set -e — several code paths intentionally rely on commands failing
# silently (curl with no network, optional files missing, cache writes on a
# read-only TMPDIR, etc.) and we guard each one with `|| true` / explicit
# fallbacks instead.
set -u
set -o pipefail

REPO="chainbase-labs/agentkey"
CACHE_TTL_UP_TO_DATE=3600     # 60 min — detect new releases quickly
CACHE_TTL_UPGRADE=43200       # 12 h — keep nagging once an upgrade is known
CURL_TIMEOUT=3

# Local version is embedded at release time — no filesystem traversal,
# no dependency on CLAUDE_PLUGIN_ROOT or the skill's installed layout.
# release-please syncs this line on every release via the `extra-files`
# entry in release-please-config.json. Do not edit by hand.
LOCAL_VERSION="1.2.4" # x-release-please-version

CACHE_FILE="${TMPDIR:-/tmp}/agentkey-update-check"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agentkey"
DISABLED_FILE="$CONFIG_DIR/update-disabled"
SNOOZE_FILE="$CONFIG_DIR/update-snoozed"
TELEMETRY_DISABLED_FILE="$CONFIG_DIR/telemetry-disabled"
TELEMETRY_HEARTBEAT_TTL=86400   # 24h client-side dedup

# Telemetry: the skill itself never sends — it only emits a "TELEMETRY ..."
# line to stdout for SKILL.md to dispatch via MCP. Opt-out via file or env.
emit_telemetry_enabled() {
    [ "${AGENTKEY_TELEMETRY:-1}" = "0" ] && return 1
    [ -f "$TELEMETRY_DISABLED_FILE" ] && return 1
    return 0
}

# Disabled by user ("Never ask again") — exit silently.
if [ -f "$DISABLED_FILE" ]; then
    exit 0
fi

# Sanity check the embedded version — if release-please ever fails to sync
# this line, exit silently rather than emit garbage.
case "$LOCAL_VERSION" in
    [0-9]*.[0-9]*.[0-9]*) ;;
    *) exit 0 ;;
esac

# Cache `date +%s` once — used by both the cache age math and snooze expiry.
NOW=$(date +%s)

# check_snooze <remote_version> → returns 0 (snoozed) or 1 (not snoozed).
# Snooze file format: "<version> <level> <epoch>" where level 1=24h, 2=48h, 3+=7d.
# A new remote version invalidates the snooze.
check_snooze() {
    local remote_ver="$1"
    [ -f "$SNOOZE_FILE" ] || return 1

    # Single-pass read replaces the previous 3× awk fork. Also closes the
    # race where the file could be rewritten between fields.
    local sver="" slevel="" sepoch="" _rest=""
    read -r sver slevel sepoch _rest < "$SNOOZE_FILE" 2>/dev/null || return 1

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

    [ $((sepoch + duration)) -gt "$NOW" ]
}

# Fast path: recent cache hit — avoids the GitHub API round-trip (~1.5s).
if [ -f "$CACHE_FILE" ]; then
    MTIME=$(stat -f %m "$CACHE_FILE" 2>/dev/null \
            || stat -c %Y "$CACHE_FILE" 2>/dev/null \
            || echo 0)
    AGE=$(( NOW - MTIME ))

    # Single-pass read of the cache line. Empty / corrupted cache → all
    # fields stay empty and fall through to slow path.
    CACHED_KIND="" CACHED_OLD="" CACHED_NEW="" _rest=""
    read -r CACHED_KIND CACHED_OLD CACHED_NEW _rest < "$CACHE_FILE" 2>/dev/null || true

    case "$CACHED_KIND" in
        "UP_TO_DATE")        TTL=$CACHE_TTL_UP_TO_DATE ;;
        "UPGRADE_AVAILABLE") TTL=$CACHE_TTL_UPGRADE ;;
        *)                   TTL=0 ;;
    esac

    if [ "$AGE" -ge 0 ] && [ "$AGE" -lt "$TTL" ]; then
        case "$CACHED_KIND" in
            "UP_TO_DATE")
                echo "UP_TO_DATE"
                exit 0
                ;;
            "UPGRADE_AVAILABLE")
                if [ "$CACHED_OLD" = "$LOCAL_VERSION" ] && [ -n "$CACHED_NEW" ]; then
                    if check_snooze "$CACHED_NEW"; then
                        exit 0
                    fi
                    echo "UPGRADE_AVAILABLE $CACHED_OLD $CACHED_NEW"
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
    | sed 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/') || true
LATEST_VERSION="${LATEST_TAG#[vV]}"

# Validate response looks like a version number — rejects HTML error pages,
# rate-limit JSON, and other surprises that slipped past curl -f.
case "$LATEST_VERSION" in
    [0-9]*.[0-9]*.[0-9]*) ;;
    *) exit 0 ;;
esac

if [ "$LOCAL_VERSION" = "$LATEST_VERSION" ]; then
    echo "UP_TO_DATE" > "$CACHE_FILE" 2>/dev/null || true
    echo "UP_TO_DATE"
    exit 0
fi

# Newer version available — cache the result, then suppress output if snoozed.
MSG="UPGRADE_AVAILABLE $LOCAL_VERSION $LATEST_VERSION"
echo "$MSG" > "$CACHE_FILE" 2>/dev/null || true
if check_snooze "$LATEST_VERSION"; then
    exit 0
fi
echo "$MSG"
