#!/usr/bin/env bash
#
# AgentKey installer for macOS and Linux
# Usage: curl -fsSL https://agentkey.app/install.sh | bash
#        curl -fsSL https://agentkey.app/install.sh | bash -s -- --yes
#        curl -fsSL https://agentkey.app/install.sh | bash -s -- --interactive
#        curl -fsSL https://agentkey.app/install.sh | bash -s -- --only claude-code,cursor
#        curl -fsSL https://agentkey.app/install.sh | bash -s -- --skip-mcp
#
# The whole procedural body is wrapped in `main()` so that under `curl | bash`
# bash reads the entire script into memory (as a function definition) before
# executing any of it. Without this wrapper, `exec < /dev/tty` would clobber
# bash's own script-source fd and the shell would hang trying to read the rest
# of itself from the terminal.

set -euo pipefail

# ── Constants ─────────────────────────────────────────────────────────────
SKILL_REPO="chainbase-labs/agentkey"
CLI_PACKAGE="@agentkey/cli"
NODE_MIN_MAJOR=18

# ── Agent markers ─────────────────────────────────────────────────────────
# Subset of vercel-labs/skills' 45 supported agent IDs that have reliable
# on-disk markers (config dirs / binaries on PATH). Agents we can't probe
# cleanly (mostly VS Code extensions like cline/continue/roo) just don't get
# pre-detected — the user can pass --all-agents or --only to include them.
# Sync source: https://github.com/vercel-labs/skills (Supported Agents table).
#
# IMPORTANT: ids here MUST match the `--only` ids accepted by both
# `npx skills add -a` and `npx -y @agentkey/cli --auth-login --only`.
# That alignment is what lets the installer drive both halves with one list.
#
# `claude-desktop` is the documented exception — it isn't in the skills CLI
# (Desktop installs skills into a sandbox path the CLI can't write), but
# Desktop's MCP config IS auto-writable, so we list it separately and pass
# it ONLY to the MCP --only filter (see SKILL_TARGETS / MCP_TARGETS below).
#
# Format: <agent-id>|<marker>[,<marker>...]
#   marker types:  cmd:foo            — `command -v foo`
#                  path:/abs/or/~path — file or dir exists (~ expands to $HOME)
AGENT_MARKERS=(
    "claude-code|path:~/.claude.json,cmd:claude"
    "claude-desktop|path:/Applications/Claude.app,path:~/Applications/Claude.app,path:~/Library/Application Support/Claude/claude_desktop_config.json,path:~/Library/Application Support/Claude,path:~/.config/Claude/claude_desktop_config.json,path:~/.config/Claude"
    "cursor|path:~/.cursor,cmd:cursor"
    "codex|path:~/.codex,cmd:codex"
    "gemini-cli|path:~/.gemini,cmd:gemini"
    "opencode|path:~/.config/opencode,path:~/.opencode,cmd:opencode"
    "openclaw|path:~/.openclaw,cmd:openclaw"
    "qwen-code|path:~/.qwen,cmd:qwen"
    "iflow-cli|path:~/.iflow,cmd:iflow"
    "windsurf|path:~/.codeium/windsurf,path:~/.windsurf,cmd:windsurf"
    "warp|path:~/.warp,path:~/Library/Application Support/dev.warp.Warp-Stable"
    "amp|path:~/.config/amp,cmd:amp"
    "crush|path:~/.config/crush,cmd:crush"
    "goose|path:~/.config/goose,cmd:goose"
    "droid|cmd:droid"
    "kode|cmd:kode"
    "kilo|cmd:kilo"
    "kimi-cli|path:~/.kimi,cmd:kimi"
    "kiro-cli|path:~/.kiro,cmd:kiro"
)

# Agent ids that are MCP-only (no skill install path). These get passed to
# `--auth-login --only` but NEVER to `npx skills add -a`.
MCP_ONLY_AGENTS=(claude-desktop)

# Agent ids whose MCP registration the installer can drive automatically.
# Skipped agents (goose / kode / kilo) still get the skill, but the user
# must register MCP manually for them. Keep this in sync with
# AGENT_REGISTRY in AgentKey-Server/cli/src/lib/mcp-clients.ts.
MCP_AUTO_AGENTS=(
    claude-code claude-desktop cursor codex gemini-cli opencode
    qwen-code iflow-cli kimi-cli kiro-cli windsurf warp
    amp crush droid openclaw
)

# ── Colors (only if stdout is a TTY) ─────────────────────────────────────
# Use $'...' so variables hold real ESC bytes — otherwise heredoc output prints
# the literal string "\033[1m" instead of applying the SGR code.
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    BOLD=$'\033[1m'
    ACCENT=$'\033[38;2;0;200;180m'   # AgentKey teal
    INFO=$'\033[38;2;136;146;176m'
    SUCCESS=$'\033[38;2;0;220;150m'
    WARN=$'\033[38;2;255;176;32m'
    ERROR=$'\033[38;2;230;57;70m'
    MUTED=$'\033[38;2;110;118;132m'
    NC=$'\033[0m'
else
    BOLD=''; ACCENT=''; INFO=''; SUCCESS=''; WARN=''; ERROR=''; MUTED=''; NC=''
fi

# ── UI helpers ────────────────────────────────────────────────────────────
ui_banner() {
    printf "\n"
    printf "${ACCENT}   █████   ██████  ███████ ███    ██ ████████ ██   ██ ███████ ██    ██${NC}\n"
    printf "${ACCENT}  ██   ██ ██       ██      ████   ██    ██    ██  ██  ██       ██  ██ ${NC}\n"
    printf "${ACCENT}  ███████ ██   ███ █████   ██ ██  ██    ██    █████   █████     ████  ${NC}\n"
    printf "${ACCENT}  ██   ██ ██    ██ ██      ██  ██ ██    ██    ██  ██  ██         ██   ${NC}\n"
    printf "${ACCENT}  ██   ██  ██████  ███████ ██   ████    ██    ██   ██ ███████    ██   ${NC}\n"
    printf "\n"
    printf "  ${BOLD}One command. Full internet access for your AI agent.${NC}\n"
    printf "  ${MUTED}https://agentkey.app${NC}\n\n"
}

ui_info()  { printf "  ${INFO}›${NC} %s\n" "$*"; }
ui_ok()    { printf "  ${SUCCESS}✓${NC} %s\n" "$*"; }
ui_warn()  { printf "  ${WARN}!${NC} %s\n" "$*"; }
ui_error() { printf "  ${ERROR}✗${NC} %s\n" "$*" >&2; }
ui_step()  { printf "\n  ${BOLD}%s${NC}\n" "$*"; }
ui_muted() { printf "    ${MUTED}%s${NC}\n" "$*"; }

die() { ui_error "$*"; exit 1; }

print_help() {
    cat <<EOF
AgentKey installer for macOS and Linux

Usage:
  curl -fsSL https://agentkey.app/install.sh | bash
  curl -fsSL https://agentkey.app/install.sh | bash -s -- [OPTIONS]

Options:
  --yes, -y           Non-interactive: install skill to every detected agent, no prompts
  --interactive       Force interactive mode (fails if no TTY/terminal is reachable)
  --only <a,b,c>      Only install skill for these agents (comma-separated, e.g. claude-code,cursor)
  --all-agents        Skip auto-detection; let 'skills' CLI install for every detected agent
  --list-agents       Print the agents we'd auto-select on this machine and exit
  --skip-skill        Skip the skill install step (only run MCP auth)
  --skip-mcp          Skip the MCP auth step (only install the skill)
  --no-telemetry      Disable anonymous usage telemetry (writes
                      ~/.config/agentkey/telemetry-disabled so the skill
                      stays opted-out across runs)
  -h, --help          Show this help

Behavior:
  Interactive mode is the default when a terminal is reachable; otherwise it
  falls back to --yes. The installer auto-detects which AI agents are on this
  machine and pre-selects them for skill installation. The auth step always
  attempts to open a browser and also prints the URL — so SSH / Docker /
  OpenClaw users can copy the URL to any device with a browser.
EOF
}

# ── Helpers: agent detection ──────────────────────────────────────────────

# Expand a leading "~" to \$HOME (no glob expansion, no eval).
_expand_path() {
    local p="$1"
    case "$p" in
        "~"|"~/"*) printf '%s\n' "$HOME${p#"~"}" ;;
        *)         printf '%s\n' "$p" ;;
    esac
}

# Probe a single marker: cmd:NAME (binary on PATH) or path:PATH (file/dir).
_probe_marker() {
    local m="$1"
    case "$m" in
        cmd:*)  command -v "${m#cmd:}" >/dev/null 2>&1 ;;
        path:*) [ -e "$(_expand_path "${m#path:}")" ] ;;
        *)      return 1 ;;
    esac
}

# Print detected agent IDs as a comma-separated list (empty if none).
detect_agents() {
    local entry id markers marker hits=()
    for entry in "${AGENT_MARKERS[@]}"; do
        id="${entry%%|*}"
        markers="${entry#*|}"
        # Any marker hit ⇒ agent detected.
        IFS=',' read -ra marker_list <<<"$markers"
        for marker in "${marker_list[@]}"; do
            if _probe_marker "$marker"; then
                hits+=("$id")
                break
            fi
        done
    done
    if [ ${#hits[@]} -gt 0 ]; then
        printf '%s\n' "${hits[@]}" | sort -u | paste -sd, -
    fi
}

# Membership helper: is "$1" in the rest of the argument list?
_in_list() {
    local needle="$1"; shift
    local item
    for item in "$@"; do
        [ "$item" = "$needle" ] && return 0
    done
    return 1
}

# Filter a comma-separated id list, keeping only ids that are passed in the
# remaining arguments. Output is comma-separated. Short-circuits on empty
# input so callers don't have to guard.
_filter_csv() {
    local csv="$1"; shift
    [ -z "$csv" ] && return 0
    local id
    local -a ids=() out=()
    IFS=',' read -ra ids <<<"$csv"
    for id in "${ids[@]}"; do
        if _in_list "$id" "$@"; then
            out+=("$id")
        fi
    done
    if [ ${#out[@]} -gt 0 ]; then
        printf '%s\n' "${out[@]}" | paste -sd, -
    fi
}

install_node() {
    local platform="$1"
    ui_info "Installing Node.js v$NODE_MIN_MAJOR+ ..."
    if [ "$platform" = "macos" ]; then
        if command -v brew >/dev/null 2>&1; then
            brew install node >/dev/null 2>&1 || die "brew install node failed"
        else
            die "Homebrew not found. Install Node.js v$NODE_MIN_MAJOR+ manually: https://nodejs.org/"
        fi
    else
        # Linux: NodeSource for apt/dnf/yum; apk for Alpine; otherwise manual
        if command -v apt-get >/dev/null 2>&1; then
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - >/dev/null 2>&1 \
                && sudo apt-get install -y nodejs >/dev/null 2>&1 || die "apt install nodejs failed"
        elif command -v dnf >/dev/null 2>&1; then
            curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo -E bash - >/dev/null 2>&1 \
                && sudo dnf install -y nodejs >/dev/null 2>&1 || die "dnf install nodejs failed"
        elif command -v yum >/dev/null 2>&1; then
            curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo -E bash - >/dev/null 2>&1 \
                && sudo yum install -y nodejs >/dev/null 2>&1 || die "yum install nodejs failed"
        elif command -v apk >/dev/null 2>&1; then
            sudo apk add --no-cache nodejs npm >/dev/null 2>&1 || die "apk add nodejs failed"
        else
            die "No supported package manager found. Install Node.js v$NODE_MIN_MAJOR+ manually: https://nodejs.org/"
        fi
    fi
    ui_ok "Node.js installed"
}

# Compute a stable per-device fingerprint for install_completed dedup.
# spec §6.3: sha256(hostname+platform+username)[:16]. Falls back to a random
# value if neither sha256sum nor shasum is available (extremely rare).
compute_device_fingerprint() {
    local platform="$1"
    local hn user input hash
    hn="$(hostname 2>/dev/null || echo "")"
    user="${USER:-$(id -un 2>/dev/null || echo "")}"
    input="$hn|$platform|$user"
    if command -v sha256sum >/dev/null 2>&1; then
        hash="$(printf '%s' "$input" | sha256sum | cut -c1-16)"
    elif command -v shasum >/dev/null 2>&1; then
        hash="$(printf '%s' "$input" | shasum -a 256 | cut -c1-16)"
    else
        # Last resort: use $RANDOM. Won't dedup across runs but won't crash.
        hash="rnd$(printf '%04x%04x%04x' "$RANDOM" "$RANDOM" "$RANDOM")"
    fi
    printf '%s' "$hash"
}

# ──────────────────────────────────────────────────────────────────────────
# main — wraps the entire procedural body so that under `curl | bash`
# bash finishes reading the script before any fd-rebinding happens.
# ──────────────────────────────────────────────────────────────────────────
main() {
    local MODE=""
    local ONLY_AGENTS=""
    local SKIP_MCP=false
    local SKIP_SKILL=false
    local PRINT_HELP=false
    local LIST_AGENTS=false
    local ALL_AGENTS=false
    local NO_TELEMETRY=false

    # Snapshot original args before the parse loop shifts them away — needed
    # later for AGENTKEY_INSTALLER_FLAGS env passthrough.
    local _orig_args=("$@")

    while [ $# -gt 0 ]; do
        case "$1" in
            -y|--yes)          MODE=noninteractive; shift ;;
            --interactive)     MODE=interactive; shift ;;
            --only)            ONLY_AGENTS="${2:-}"; shift 2 ;;
            --only=*)          ONLY_AGENTS="${1#*=}"; shift ;;
            --all-agents)      ALL_AGENTS=true; shift ;;
            --list-agents)     LIST_AGENTS=true; shift ;;
            --skip-skill)      SKIP_SKILL=true; shift ;;
            --skip-mcp)        SKIP_MCP=true; shift ;;
            --no-telemetry)    NO_TELEMETRY=true; shift ;;
            -h|--help)         PRINT_HELP=true; shift ;;
            *)                 ui_warn "Unknown argument: $1"; shift ;;
        esac
    done

    if $PRINT_HELP; then print_help; exit 0; fi

    if $LIST_AGENTS; then
        local detected
        detected="$(detect_agents)"
        if [ -n "$detected" ]; then
            printf '%s\n' "$detected" | tr ',' '\n'
        else
            printf 'no agents detected on this host\n' >&2
        fi
        exit 0
    fi

    ui_banner

    # ── 1. Preflight ──────────────────────────────────────────────────────
    ui_step "1. Preflight"

    local OS PLATFORM
    OS="$(uname -s)"
    case "$OS" in
        Darwin)  PLATFORM="macos" ;;
        Linux)   PLATFORM="linux" ;;
        *)       die "Unsupported OS: $OS (macOS/Linux only; use install.ps1 on Windows)" ;;
    esac
    ui_ok "Platform: $PLATFORM"

    # Resolve stdin. `curl | bash` eats stdin — but /dev/tty is usually still
    # reachable. Test by *actually opening* /dev/tty in a subshell; `[ -r ]`
    # returns true even when the process has lost its controlling terminal
    # (e.g. backgrounded, daemonized).
    #
    # IMPORTANT: we do NOT `exec < /dev/tty` globally. Under `curl | bash`
    # bash is reading the script from its own stdin (the pipe); a global
    # rebind would hijack bash's script reader and hang after `main` returns
    # (bash would try to read the next byte from /dev/tty instead of EOF).
    # Instead we redirect stdin *per interactive command* below.
    local TTY_AVAILABLE=false
    if ( : < /dev/tty ) >/dev/null 2>&1; then
        TTY_AVAILABLE=true
    fi

    if [ -z "$MODE" ]; then
        if $TTY_AVAILABLE; then
            MODE=interactive
        else
            MODE=noninteractive
            ui_warn "No terminal detected (CI/non-TTY shell) — falling back to --yes"
        fi
    elif [ "$MODE" = interactive ] && ! $TTY_AVAILABLE; then
        die "--interactive requested but no TTY is reachable"
    fi
    ui_ok "Mode: $MODE"

    # Resolve telemetry intent: --no-telemetry overrides everything; existing
    # ~/.config/agentkey/telemetry-disabled file means already-opted-out.
    local TELEMETRY_OPT_OUT_FILE="$HOME/.config/agentkey/telemetry-disabled"
    if $NO_TELEMETRY; then
        mkdir -p "$(dirname "$TELEMETRY_OPT_OUT_FILE")" 2>/dev/null || true
        touch "$TELEMETRY_OPT_OUT_FILE" 2>/dev/null || true
        ui_ok "Telemetry: disabled (--no-telemetry)"
    elif [ -f "$TELEMETRY_OPT_OUT_FILE" ]; then
        ui_ok "Telemetry: disabled (~/.config/agentkey/telemetry-disabled exists)"
    else
        ui_info "Telemetry: anonymous usage stats enabled (re-run with --no-telemetry to opt out)"
    fi

    # Node check
    local NODE_OK=false NODE_VERSION NODE_MAJOR
    if command -v node >/dev/null 2>&1; then
        NODE_VERSION="$(node --version 2>/dev/null | sed 's/^v//')"
        NODE_MAJOR="${NODE_VERSION%%.*}"
        if [ -n "$NODE_MAJOR" ] && [ "$NODE_MAJOR" -ge "$NODE_MIN_MAJOR" ] 2>/dev/null; then
            NODE_OK=true
            ui_ok "Node.js: v$NODE_VERSION"
        else
            ui_warn "Node.js v$NODE_VERSION found but v$NODE_MIN_MAJOR+ is required"
        fi
    fi

    if ! $NODE_OK; then
        if [ "$MODE" = interactive ]; then
            printf "\n  ${BOLD}Node.js v%s+ is required but not found.${NC}\n" "$NODE_MIN_MAJOR"
            printf "  Install it now? [Y/n] "
            local REPLY=""
            # Read directly from the terminal, not from bash's stdin (the pipe)
            read -r REPLY < /dev/tty || REPLY=""
            case "$REPLY" in
                n|N|no|No) die "Node.js required. Aborting." ;;
            esac
        fi
        install_node "$PLATFORM"
    fi

    command -v npx >/dev/null 2>&1 || die "npx not found after Node install — please reinstall Node.js"

    # ── Resolve target agent list ─────────────────────────────────────────
    # Used by step 2 (skill) and step 3 (MCP). Computed once here so both
    # halves see the same source of truth — that's the invariant the unified
    # install+register design depends on. Two derived lists:
    #
    #   ALL_TARGETS  — every detected agent, including MCP-only ones (claude-desktop)
    #   SKILL_TARGETS — ALL_TARGETS minus MCP-only ids (those would error in `skills add`)
    #   MCP_TARGETS  — ALL_TARGETS filtered to ids the MCP CLI knows how to write
    local ALL_TARGETS=""
    if [ -n "$ONLY_AGENTS" ]; then
        ALL_TARGETS="$ONLY_AGENTS"
        ui_info "Targeting agents from --only: $ALL_TARGETS"
    elif $ALL_AGENTS; then
        ui_info "Installing for every agent the 'skills' CLI detects (--all-agents)"
    else
        ALL_TARGETS="$(detect_agents)"
        if [ -n "$ALL_TARGETS" ]; then
            ui_ok "Detected agents on this host: $ALL_TARGETS"
            ui_muted "(override with --only <ids>, or use --all-agents)"
        else
            ui_info "No agents auto-detected — letting 'skills' CLI scan."
        fi
    fi

    local SKILL_TARGETS=""
    local MCP_TARGETS=""
    if [ -n "$ALL_TARGETS" ]; then
        # SKILL_TARGETS: drop MCP-only ids (would fail in `skills add -a`).
        local _id
        local -a _id_list=() _kept=()
        IFS=',' read -ra _id_list <<<"$ALL_TARGETS"
        for _id in "${_id_list[@]}"; do
            if ! _in_list "$_id" "${MCP_ONLY_AGENTS[@]}"; then
                _kept+=("$_id")
            fi
        done
        if [ ${#_kept[@]} -gt 0 ]; then
            SKILL_TARGETS="$(printf '%s\n' "${_kept[@]}" | paste -sd, -)"
        fi
        # MCP_TARGETS: keep only ids the MCP CLI knows how to register.
        MCP_TARGETS="$(_filter_csv "$ALL_TARGETS" "${MCP_AUTO_AGENTS[@]}")"
    fi

    # ── 2. Install the AgentKey skill ─────────────────────────────────────
    if $SKIP_SKILL; then
        ui_step "2. Install the AgentKey skill"
        ui_muted "Skipped (--skip-skill)"
    elif [ -n "$ALL_TARGETS" ] && [ -z "$SKILL_TARGETS" ]; then
        # User explicitly selected only MCP-only ids (e.g. `--only claude-desktop`).
        # There's nothing for `skills add` to do — skip the step entirely
        # rather than fall through to "install for every detected agent."
        ui_step "2. Install the AgentKey skill"
        ui_muted "Skipped — selected targets ($ALL_TARGETS) are MCP-only (no skill install path)."
    else
        ui_step "2. Install the AgentKey skill"

        local SKILLS_ARGS=(-y skills add "$SKILL_REPO" -g)
        if [ -n "$SKILL_TARGETS" ]; then
            # `skills` CLI accepts -a as either repeated or comma-separated.
            # We pass each ID individually for maximum compatibility.
            local AGENT_LIST=()
            IFS=',' read -ra AGENT_LIST <<<"$SKILL_TARGETS"
            SKILLS_ARGS+=(-a "${AGENT_LIST[@]}")
        fi
        # Always pass -y in noninteractive mode AND when we already resolved
        # an explicit target list — there's nothing left to ask the user.
        if [ "$MODE" = noninteractive ] || [ -n "$ALL_TARGETS" ]; then
            SKILLS_ARGS+=(-y)
        fi

        # Route npx's stdin to the terminal so its interactive multi-select can
        # prompt the user — otherwise it inherits bash's piped stdin and breaks.
        # When non-interactive (no TTY), stdin stays as /dev/null via < /dev/null
        # to guarantee npx never blocks waiting for input.
        local npx_stdin="/dev/null"
        if [ "$MODE" = interactive ] && $TTY_AVAILABLE; then
            npx_stdin="/dev/tty"
        fi
        if ! npx "${SKILLS_ARGS[@]}" < "$npx_stdin"; then
            die "Failed to install skill via 'skills' CLI"
        fi
        # The skills CLI sometimes prints "Installation failed" and still
        # exits 0 (e.g. network error during git clone). Verify the skill
        # actually landed on disk before declaring success.
        local _agentkey_found=false _dir
        for _dir in \
            "$HOME/.agents/skills/agentkey" \
            "$HOME/.claude/skills/agentkey" \
            "$HOME/.cursor/skills/agentkey" \
            "$HOME/.codex/skills/agentkey" \
            "$HOME/.gemini/skills/agentkey" \
            "$HOME/.opencode/skills/agentkey" \
            "$HOME/.openclaw/skills/agentkey" \
            "$HOME/.qwen/skills/agentkey" \
            "$HOME/.iflow/skills/agentkey" \
            "$HOME/.windsurf/skills/agentkey" \
            "$HOME/.warp/skills/agentkey" \
            "$HOME/.config/amp/skills/agentkey" \
            "$HOME/.config/crush/skills/agentkey" \
            "$HOME/.config/goose/skills/agentkey" \
            "$HOME/.config/opencode/skills/agentkey" \
            "$HOME/.kimi/skills/agentkey" \
            "$HOME/.kiro/skills/agentkey"; do
            [ -f "$_dir/SKILL.md" ] && { _agentkey_found=true; break; }
        done
        if ! $_agentkey_found; then
            die "Skill install reported success but no agentkey SKILL.md was created — likely a network or git clone failure. Retry: npx -y skills add $SKILL_REPO -g -y"
        fi
        ui_ok "Skill installed"
    fi

    # ── 3. MCP authentication ────────────────────────────────────────────
    # Always run auth-login. The CLI itself decides whether the existing
    # token can be reused or a fresh device-code flow is needed — the
    # installer no longer second-guesses by sniffing config files (which
    # produced false positives across the stdio → HTTP schema change).
    if $SKIP_MCP; then
        ui_step "3. Register the MCP server"
        ui_muted "Skipped (--skip-mcp)"
    elif [ -n "$ALL_TARGETS" ] && [ -z "$MCP_TARGETS" ]; then
        # User selected ONLY MCP-incompatible agents (goose / kode / kilo
        # via --only). Running auth-login without --only would silently
        # register MCP in every detected agent — overriding the user's
        # explicit scope. Skip rather than over-register. See PR #41 B1.
        ui_step "3. Register the MCP server"
        ui_muted "Skipped — selected agents ($ALL_TARGETS) need manual MCP setup (see SKILL.md Fallback section)."
    else
        # Pin MCP registration to the same agent list the skill step
        # targeted. When MCP_TARGETS is empty (auto-detect found nothing),
        # let `@agentkey/cli` do its own detection — same fallback we use
        # for skill install. Older CLI versions silently ignore --only,
        # so this is forward-compatible.
        local AUTH_ARGS=(--auth-login)
        if [ -n "$MCP_TARGETS" ]; then
            AUTH_ARGS+=(--only "$MCP_TARGETS")
        fi

        ui_step "3. Register the MCP server"
        ui_info "Opening your browser for AgentKey device authentication ..."
        if [ -n "$MCP_TARGETS" ]; then
            ui_muted "Will register MCP in: $MCP_TARGETS"
        else
            ui_muted "If a browser doesn't open (SSH / Docker / headless), the auth URL is also printed below — open it on any device to finish."
        fi
        echo

        # Telemetry context for `install_completed`. Opt-out is honored at
        # the SOURCE: when AGENTKEY_TELEMETRY=0, no other context env vars
        # are exported — hostname-derived fingerprint, agent lists, and
        # installer flags are never computed nor passed to the child
        # `npx @agentkey/cli` process. The server treats AGENTKEY_TELEMETRY=0
        # as a hard skip.
        if $NO_TELEMETRY || [ -f "$TELEMETRY_OPT_OUT_FILE" ]; then
            export AGENTKEY_TELEMETRY=0
        else
            export AGENTKEY_TELEMETRY=1
            local _flags=""
            for _f in "${_orig_args[@]:-}"; do
                _flags="${_flags:+$_flags,}$_f"
            done
            export AGENTKEY_INSTALL_SOURCE="one_liner"
            export AGENTKEY_DETECTED_AGENTS="$(detect_agents)"
            export AGENTKEY_SELECTED_AGENTS="${ALL_TARGETS:-}"
            export AGENTKEY_INSTALLER_FLAGS="$_flags"
            export AGENTKEY_DEVICE_FINGERPRINT="$(compute_device_fingerprint "$PLATFORM")"
        fi

        if ! npx -y "$CLI_PACKAGE" "${AUTH_ARGS[@]}"; then
            ui_error "MCP auth failed."
            ui_muted "Retry manually:  npx -y $CLI_PACKAGE ${AUTH_ARGS[*]}"
            exit 1
        fi
        ui_ok "MCP server registered"
    fi

    # ── 4. Summary ───────────────────────────────────────────────────────
    ui_step "✨ Installation complete"
    cat <<EOF

  ${BOLD}Next steps${NC}
    ${MUTED}1.${NC} Restart your agent (Claude Code / Cursor / etc.)
    ${MUTED}2.${NC} Ask it something that needs the internet:
       ${ACCENT}"What has Musk been tweeting about lately?"${NC}

  ${BOLD}Docs${NC}       https://agentkey.app/docs
  ${BOLD}Uninstall${NC}  curl -fsSL https://agentkey.app/uninstall.sh | bash

EOF
}

main "$@"
