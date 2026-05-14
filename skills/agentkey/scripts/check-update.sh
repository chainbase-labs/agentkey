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
LOCAL_VERSION="1.5.0" # x-release-please-version

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

# Inline `auto_upgrade_enabled=` kv pair for emit_telemetry callers.
auto_upgrade_flag() {
    if [ "${AGENTKEY_AUTO_UPGRADE:-0}" = "1" ] || [ -f "$CONFIG_DIR/auto-upgrade" ]; then
        echo "auto_upgrade_enabled=1"
    else
        echo "auto_upgrade_enabled=0"
    fi
}

# Emit a single-line TELEMETRY event to stdout for SKILL.md to forward via MCP.
# Args: event_name kv_pairs...
# Honors opt-out (file / env) and 24h client-side dedup per LOCAL_VERSION.
# Server does the strict per-user dedup; this is just defensive bandwidth control.
emit_telemetry() {
    emit_telemetry_enabled || return 0
    local event="$1"; shift

    local hb="${TMPDIR:-/tmp}/agentkey-heartbeat-$LOCAL_VERSION"
    if [ -f "$hb" ]; then
        local mtime age
        # Linux GNU stat uses `-c %Y`; macOS BSD stat uses `-f %m`. GNU first
        # because on Linux `-f %m` is invalid and some builds (Ubuntu 24.04 CI)
        # pollute stdout with filesystem info even on failure — which would
        # poison the arithmetic below under `set -u`. Numeric guard is the
        # belt-and-suspenders defense.
        mtime=$(stat -c %Y "$hb" 2>/dev/null || stat -f %m "$hb" 2>/dev/null || echo 0)
        case "$mtime" in
            ''|*[!0-9]*) mtime=0 ;;
        esac
        age=$(( ${NOW:-$(date +%s)} - mtime ))
        if [ "$age" -ge 0 ] && [ "$age" -lt "$TELEMETRY_HEARTBEAT_TTL" ]; then
            return 0
        fi
    fi
    touch "$hb" 2>/dev/null || true

    printf 'TELEMETRY %s skill_version=%s' "$event" "$LOCAL_VERSION"
    for kv in "$@"; do printf ' %s' "$kv"; done
    printf '\n'
}

# Sanity check the embedded version first — if release-please ever fails to
# sync this line, exit silently rather than emit garbage. Runs before any
# emit_telemetry call so a malformed LOCAL_VERSION can't poison the heartbeat
# file path ($TMPDIR/agentkey-heartbeat-$LOCAL_VERSION).
case "$LOCAL_VERSION" in
    [0-9]*.[0-9]*.[0-9]*) ;;
    *) exit 0 ;;
esac

# Disabled by user ("Never ask again") — exit silently.
if [ -f "$DISABLED_FILE" ]; then
    emit_telemetry skill_loaded update_state=disabled "$(auto_upgrade_flag)"
    exit 0
fi

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
    # GNU `stat -c %Y` first (Linux). BSD `stat -f %m` only as fallback for
    # macOS. Some GNU stat builds (Ubuntu 24.04 in CI) print filesystem info
    # to stdout even when `-f %m` is invalid, which would poison MTIME and
    # blow up the arithmetic below under `set -u`. The numeric guard at the
    # end strips that out defensively if both forms ever produce garbage.
    MTIME=$(stat -c %Y "$CACHE_FILE" 2>/dev/null \
            || stat -f %m "$CACHE_FILE" 2>/dev/null \
            || echo 0)
    case "$MTIME" in
        ''|*[!0-9]*) MTIME=0 ;;
    esac
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
                emit_telemetry skill_loaded update_state=up_to_date "$(auto_upgrade_flag)"
                exit 0
                ;;
            "UPGRADE_AVAILABLE")
                if [ "$CACHED_OLD" = "$LOCAL_VERSION" ] && [ -n "$CACHED_NEW" ]; then
                    if check_snooze "$CACHED_NEW"; then
                        emit_telemetry skill_loaded update_state=snoozed "latest_version=$CACHED_NEW" "$(auto_upgrade_flag)"
                        exit 0
                    fi
                    echo "UPGRADE_AVAILABLE $CACHED_OLD $CACHED_NEW"
                    emit_telemetry skill_loaded update_state=upgrade_available "latest_version=$CACHED_NEW" "$(auto_upgrade_flag)"
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
    emit_telemetry skill_loaded update_state=up_to_date "$(auto_upgrade_flag)"
    exit 0
fi

# Newer version available — cache the result, then suppress output if snoozed.
MSG="UPGRADE_AVAILABLE $LOCAL_VERSION $LATEST_VERSION"
echo "$MSG" > "$CACHE_FILE" 2>/dev/null || true
if check_snooze "$LATEST_VERSION"; then
    emit_telemetry skill_loaded update_state=snoozed "latest_version=$LATEST_VERSION" "$(auto_upgrade_flag)"
    exit 0
fi
echo "$MSG"
emit_telemetry skill_loaded update_state=upgrade_available "latest_version=$LATEST_VERSION" "$(auto_upgrade_flag)"
