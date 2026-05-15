#!/usr/bin/env bash
#
# AgentKey installer for macOS and Linux
# Usage: curl -fsSL https://agentkey.app/install.sh | bash
#        curl -fsSL https://agentkey.app/install.sh | bash -s -- --yes
#        curl -fsSL https://agentkey.app/install.sh | bash -s -- --interactive
#        curl -fsSL https://agentkey.app/install.sh | bash -s -- --only claude-code,cursor
#        curl -fsSL https://agentkey.app/install.sh | bash -s -- --remote
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
# Format: <agent-id>|<marker>[,<marker>...]
#   marker types:  cmd:foo            — `command -v foo`
#                  path:/abs/or/~path — file or dir exists (~ expands to $HOME)
AGENT_MARKERS=(
    "claude-code|path:~/.claude.json,cmd:claude,path:~/Library/Application Support/Claude,path:~/.config/Claude"
    "cursor|path:~/.cursor,cmd:cursor"
    "codex|path:~/.codex,cmd:codex"
    "gemini-cli|path:~/.gemini,cmd:gemini"
    "opencode|path:~/.opencode,cmd:opencode"
    "openclaw|path:~/.openclaw"
    "qwen-code|path:~/.qwen,cmd:qwen"
    "iflow-cli|path:~/.iflow,cmd:iflow"
    "windsurf|path:~/.windsurf,cmd:windsurf"
    "warp|path:~/.warp,path:~/Library/Application Support/dev.warp.Warp-Stable"
    "amp|cmd:amp"
    "crush|cmd:crush"
    "goose|cmd:goose"
    "droid|cmd:droid"
    "kode|cmd:kode"
    "kilo|cmd:kilo"
    "kimi-cli|path:~/.kimi,cmd:kimi"
    "kiro-cli|path:~/.kiro,cmd:kiro"
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
  --remote            Force remote-install mode: print URL + QR for the auth step,
                      do NOT auto-open a local browser. Use this when running over
                      SSH, in Docker, or via OpenClaw / Claude Code remote channels.
  --local             Force local mode (auto-open browser) and bypass remote heuristics
  --skip-skill        Skip the skill install step (only run MCP auth)
  --skip-mcp          Skip the MCP auth step (only install the skill)
  -h, --help          Show this help

Behavior:
  Interactive mode is the default when a terminal is reachable; otherwise it
  falls back to --yes. The installer auto-detects which AI agents are on this
  machine and pre-selects them for skill installation. Remote-install mode is
  auto-detected from \$HOME/.openclaw, SSH env vars, and missing \$DISPLAY;
  override with --remote / --local.
EOF
}

# ── Helpers: agent + remote detection ─────────────────────────────────────

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

# Detect "remote install" — a context where auto-opening a browser on this
# host is futile because the user isn't sitting in front of it. Mutates
# nothing; returns 0 (true) for remote, 1 (false) for local.
detect_remote() {
    [ "$FORCE_LOCAL" = true ]  && return 1
    [ "$FORCE_REMOTE" = true ] && return 0

    # OpenClaw runtime — the project owner confirms ~/.openclaw exists in
    # any host where OpenClaw is installed/active. Most reliable single
    # signal because it doesn't depend on env-var inheritance through the
    # docker → channel → shell chain.
    [ -d "$HOME/.openclaw" ] && return 0

    # Generic SSH session.
    [ -n "${SSH_CONNECTION:-}" ] && return 0
    [ -n "${SSH_TTY:-}" ]        && return 0

    # Headless Linux (no GUI session).
    if [ "$(uname -s)" = "Linux" ] \
       && [ -z "${DISPLAY:-}" ] \
       && [ -z "${WAYLAND_DISPLAY:-}" ]; then
        return 0
    fi

    return 1
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
    # FORCE_REMOTE / FORCE_LOCAL are read by detect_remote(). Declared as
    # plain (non-`local`) so the helpers see them — they're dynamic-scope
    # accessible either way in bash, but explicit assignment here keeps
    # `set -u` happy.
    FORCE_REMOTE=false
    FORCE_LOCAL=false

    while [ $# -gt 0 ]; do
        case "$1" in
            -y|--yes)          MODE=noninteractive; shift ;;
            --interactive)     MODE=interactive; shift ;;
            --only)            ONLY_AGENTS="${2:-}"; shift 2 ;;
            --only=*)          ONLY_AGENTS="${1#*=}"; shift ;;
            --all-agents)      ALL_AGENTS=true; shift ;;
            --list-agents)     LIST_AGENTS=true; shift ;;
            --remote)          FORCE_REMOTE=true; shift ;;
            --local)           FORCE_LOCAL=true; shift ;;
            --skip-skill)      SKIP_SKILL=true; shift ;;
            --skip-mcp)        SKIP_MCP=true; shift ;;
            -h|--help)         PRINT_HELP=true; shift ;;
            *)                 ui_warn "Unknown argument: $1"; shift ;;
        esac
    done

    if $PRINT_HELP; then print_help; exit 0; fi
    if $FORCE_REMOTE && $FORCE_LOCAL; then
        die "--remote and --local are mutually exclusive"
    fi

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

    # ── 2. Install the AgentKey skill ─────────────────────────────────────
    if ! $SKIP_SKILL; then
        ui_step "2. Install the AgentKey skill"

        # Resolve target agent list:
        #   1. --only wins (manual override)
        #   2. else --all-agents ⇒ no -a (let skills CLI auto-detect everything)
        #   3. else our auto-detection ⇒ -a <detected list>
        #   4. else (nothing detected) ⇒ no -a (fall back to skills CLI default)
        local TARGETS=""
        if [ -n "$ONLY_AGENTS" ]; then
            TARGETS="$ONLY_AGENTS"
            ui_info "Targeting agents from --only: $TARGETS"
        elif $ALL_AGENTS; then
            ui_info "Installing for every agent the 'skills' CLI detects (--all-agents)"
        else
            TARGETS="$(detect_agents)"
            if [ -n "$TARGETS" ]; then
                ui_ok "Detected agents on this host: $TARGETS"
                ui_muted "(override with --only <ids>, or use --all-agents)"
            else
                ui_info "No agents auto-detected — letting 'skills' CLI scan."
            fi
        fi

        local SKILLS_ARGS=(-y skills add "$SKILL_REPO" -g)
        if [ -n "$TARGETS" ]; then
            # `skills` CLI accepts -a as either repeated or comma-separated.
            # We pass each ID individually for maximum compatibility.
            local AGENT_LIST=()
            IFS=',' read -ra AGENT_LIST <<<"$TARGETS"
            SKILLS_ARGS+=(-a "${AGENT_LIST[@]}")
        fi
        # Always pass -y in noninteractive mode AND when we already resolved
        # an explicit target list — there's nothing left to ask the user.
        if [ "$MODE" = noninteractive ] || [ -n "$TARGETS" ]; then
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
            "$HOME/.warp/skills/agentkey"; do
            [ -f "$_dir/SKILL.md" ] && { _agentkey_found=true; break; }
        done
        if ! $_agentkey_found; then
            die "Skill install reported success but no agentkey SKILL.md was created — likely a network or git clone failure. Retry: npx -y skills add $SKILL_REPO -g -y"
        fi
        ui_ok "Skill installed"
    else
        ui_step "2. Install the AgentKey skill"
        ui_muted "Skipped (--skip-skill)"
    fi

    # ── 3. MCP authentication ────────────────────────────────────────────
    # Always run auth-login. The CLI itself decides whether the existing
    # token can be reused or a fresh device-code flow is needed — the
    # installer no longer second-guesses by sniffing config files (which
    # produced false positives across the stdio → HTTP schema change).
    if $SKIP_MCP; then
        ui_step "3. Register the MCP server"
        ui_muted "Skipped (--skip-mcp)"
    else
        # Decide local-vs-remote and route the MCP CLI flags accordingly.
        local IS_REMOTE=false
        if detect_remote; then IS_REMOTE=true; fi

        local AUTH_ARGS=(--auth-login)
        if $IS_REMOTE; then
            ui_step "3. Register the MCP server (remote auth: scan QR with phone)"
            ui_info "Detected remote install context — printing QR + URL instead of opening a browser here."
            if [ -d "$HOME/.openclaw" ]; then
                ui_muted "  reason: \$HOME/.openclaw exists (OpenClaw runtime)"
            elif [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_TTY:-}" ]; then
                ui_muted "  reason: SSH session detected"
            elif [ "$(uname -s)" = "Linux" ]; then
                ui_muted "  reason: Linux without \$DISPLAY / \$WAYLAND_DISPLAY"
            fi
            ui_muted "Override with --local if you want a browser opened on this machine instead."
            AUTH_ARGS+=(--no-browser)
        else
            ui_step "3. Register the MCP server (browser login)"
            ui_info "Opening your browser for AgentKey device authentication ..."
            ui_muted "When auth finishes, the MCP server is written into Claude Code / Claude Desktop / Cursor configs."
        fi
        echo

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
