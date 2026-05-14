#!/usr/bin/env bash
#
# AgentKey uninstaller for macOS and Linux
# Usage: curl -fsSL https://agentkey.app/uninstall.sh | bash
#        curl -fsSL https://agentkey.app/uninstall.sh | bash -s -- --keep-marketplace
#        curl -fsSL https://agentkey.app/uninstall.sh | bash -s -- --force-in-repo
#
# Cleans up everything install.sh (and the legacy two-command flow) ever wrote:
#   1. Skill files in every agent   (via `skills remove` — fans across 40+ agents)
#   2. MCP server entries           (Claude Code / Claude Desktop / Cursor configs)
#   3. Claude Code plugin + marketplace registrations (legacy plugin install path)
#   4. Plugin / marketplace / npx caches
#   5. Shell RC exports + CLAUDE.md sections (legacy)
#   6. MCP stdio log

set -euo pipefail

KEEP_MARKETPLACE=false
FORCE_IN_REPO=false
SKIP_SKILL_REMOVE=false
for arg in "$@"; do
    case "$arg" in
        --keep-marketplace)   KEEP_MARKETPLACE=true ;;
        --force-in-repo)      FORCE_IN_REPO=true ;;
        --skip-skill-remove)  SKIP_SKILL_REMOVE=true ;;
        -h|--help)
            cat <<EOF
AgentKey uninstaller (macOS / Linux)

Usage:
  curl -fsSL https://agentkey.app/uninstall.sh | bash [-s -- OPTIONS]

Options:
  --keep-marketplace    Keep the Claude Code plugin marketplace registration
  --force-in-repo       Allow running inside the AgentKey-Skill source repo
  --skip-skill-remove   Skip 'npx skills remove' (only clean configs/caches)
  -h, --help            Show this help
EOF
            exit 0 ;;
    esac
done

# ── Colors ────────────────────────────────────────────────────────────────
# Use $'...' so variables hold real ESC bytes (works in both printf and heredoc).
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    BOLD=$'\033[1m'; SUCCESS=$'\033[38;2;0;220;150m'; INFO=$'\033[38;2;136;146;176m'
    WARN=$'\033[38;2;255;176;32m'; ERROR=$'\033[38;2;230;57;70m'
    MUTED=$'\033[38;2;110;118;132m'; NC=$'\033[0m'
else
    BOLD=''; SUCCESS=''; INFO=''; WARN=''; ERROR=''; MUTED=''; NC=''
fi

info()    { printf "  ${INFO}›${NC} %s\n" "$*"; }
ok()      { printf "  ${SUCCESS}✓${NC} %s\n" "$*"; }
warn()    { printf "  ${WARN}!${NC} %s\n" "$*"; }
skipped() { printf "  ${MUTED}-${NC} %s\n" "$*"; }
step()    { printf "\n  ${BOLD}%s${NC}\n" "$*"; }

# ── Safety rail ──────────────────────────────────────────────────────────
if [ -f ".claude-plugin/plugin.json" ] \
   && grep -q '"name"[[:space:]]*:[[:space:]]*"agentkey"' .claude-plugin/plugin.json 2>/dev/null \
   && ! $FORCE_IN_REPO; then
    printf "\n  ${BOLD}AgentKey — Uninstall${NC}\n\n"
    printf "  ${ERROR}Refusing to run inside the AgentKey-Skill source repo.${NC}\n"
    printf "  Running here would wipe this repo's own .mcp.json and CLAUDE.md.\n"
    printf "  Re-run with ${BOLD}--force-in-repo${NC} if you really mean it.\n\n"
    exit 2
fi

printf "\n  ${BOLD}AgentKey — Uninstall${NC}\n"
printf "  ${MUTED}https://agentkey.app${NC}\n"

# ── 1. Remove the skill via skills CLI ────────────────────────────────────
step "1. Skill files"

if $SKIP_SKILL_REMOVE; then
    skipped "Skipped (--skip-skill-remove)"
elif ! command -v npx >/dev/null 2>&1; then
    warn "npx not found — skipping 'skills remove' (manual: npx skills remove agentkey -g)"
else
    # `skills remove` takes the **skill name** (`agentkey`), not the repo path.
    # The CLI also exits 0 when nothing matches, so we inspect stdout instead.
    info "Running: npx -y skills remove agentkey -g -y"
    REMOVE_OUTPUT="$(npx -y skills remove agentkey -g -y 2>&1 || true)"
    if printf '%s\n' "$REMOVE_OUTPUT" | grep -q "Successfully removed"; then
        ok "Skill removed from detected agents"
    elif printf '%s\n' "$REMOVE_OUTPUT" | grep -q "No matching skills found"; then
        skipped "Not registered with 'skills' CLI (already removed or installed via plugin marketplace)"
    else
        warn "'skills remove' produced unexpected output — some agents may still have skill files"
        warn "Check manually:  npx skills list -g"
    fi
fi

# ── 2. MCP config cleanup ────────────────────────────────────────────────
step "2. MCP server entries"

OS="$(uname -s)"
MCP_CONFIGS=(
    "$HOME/.claude.json"                                                  # Claude Code
    "$HOME/.cursor/mcp.json"                                              # Cursor
)
if [ "$OS" = "Darwin" ]; then
    MCP_CONFIGS+=("$HOME/Library/Application Support/Claude/claude_desktop_config.json")
else
    MCP_CONFIGS+=("$HOME/.config/Claude/claude_desktop_config.json")
fi

have_python() { command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; }
py() { if command -v python3 >/dev/null 2>&1; then python3 "$@"; else python "$@"; fi; }

if ! have_python; then
    warn "python not found — skipping JSON cleanup; edit these files manually:"
    for f in "${MCP_CONFIGS[@]}"; do [ -f "$f" ] && echo "     $f"; done
else
    for cfg in "${MCP_CONFIGS[@]}"; do
        if [ ! -f "$cfg" ]; then
            skipped "$(basename "$cfg") not found"
            continue
        fi
        RESULT=$(py - "$cfg" <<'EOF'
import json, sys
path = sys.argv[1]
try:
    with open(path) as f: d = json.load(f)
except Exception as e:
    print(f"ERROR: {e}"); sys.exit(0)

removed = 0
# Top-level mcpServers.agentkey*
if isinstance(d, dict):
    for k in list(d.get('mcpServers', {}).keys()):
        if 'agentkey' in k.lower():
            del d['mcpServers'][k]; removed += 1
    # Per-project entries (Claude Code ~/.claude.json shape)
    for proj in d.get('projects', {}).values():
        if not isinstance(proj, dict): continue
        for k in list(proj.get('mcpServers', {}).keys()):
            if 'agentkey' in k.lower():
                del proj['mcpServers'][k]; removed += 1
if removed:
    with open(path, 'w') as f:
        json.dump(d, f, indent=2)
print(removed)
EOF
)
        if [ "$RESULT" = "0" ]; then
            skipped "No agentkey entry in $cfg"
        elif [[ "$RESULT" =~ ^[0-9]+$ ]]; then
            ok "Removed $RESULT entry/entries from $cfg"
        else
            warn "Failed to update $cfg: $RESULT"
        fi
    done
fi

# ── 3. Claude Code plugin registrations (legacy) ─────────────────────────
step "3. Claude Code plugin registrations (legacy)"

if ! command -v claude >/dev/null 2>&1; then
    skipped "Claude Code CLI not on PATH — nothing to do here"
else
    PLUGIN_LIST=$(claude plugin list 2>/dev/null || true)
    MARKETS=$(echo "$PLUGIN_LIST" | grep -oE 'agentkey@[a-zA-Z0-9_-]+' || true)

    if [ -z "$MARKETS" ]; then
        skipped "No agentkey plugin registered"
    else
        while IFS= read -r entry; do
            name="${entry%%@*}"
            info "Uninstalling $entry ..."
            if claude plugin uninstall "$name" --scope user 2>/dev/null; then
                ok "Removed $entry"
            else
                warn "Could not remove $entry — try: claude plugin uninstall $name --scope user"
            fi
        done <<< "$MARKETS"
    fi

    # Legacy MCP registration via `claude mcp`
    if claude mcp list 2>/dev/null | grep -q "^agentkey"; then
        info "Removing MCP server 'agentkey' via claude CLI ..."
        if claude mcp remove agentkey 2>/dev/null; then
            ok "MCP server removed"
        else
            warn "Could not remove MCP server via claude CLI"
        fi
    else
        skipped "No 'agentkey' MCP via claude CLI"
    fi

    # Marketplace entry
    if $KEEP_MARKETPLACE; then
        skipped "Marketplace removal skipped (--keep-marketplace)"
    else
        AGENTKEY_MARKETS=$(claude plugin marketplace list 2>/dev/null \
            | grep -B1 -A1 -E "(AgentKey-Skill|chainbase-labs/AgentKey-Skill|agentkey-skill|chainbase-labs/agentkey)" \
            | grep -oE '^  ❯ [a-zA-Z0-9_-]+' | awk '{print $2}' || true)
        if [ -z "$AGENTKEY_MARKETS" ]; then
            skipped "No AgentKey marketplace entry"
        else
            while IFS= read -r mkt; do
                info "Removing marketplace '$mkt' ..."
                if claude plugin marketplace remove "$mkt" 2>/dev/null; then
                    ok "Removed marketplace '$mkt'"
                else
                    warn "Could not remove marketplace '$mkt'"
                fi
            done <<< "$AGENTKEY_MARKETS"
        fi
    fi
fi

# ── 4. Plugin + marketplace caches ────────────────────────────────────────
step "4. Plugin / marketplace caches"

CACHE_HITS=()
for d in "$HOME/.claude/plugins/cache"/agentkey \
         "$HOME/.claude/plugins/cache"/agentkey-skill \
         "$HOME/.claude/plugins/cache"/agentkey-*; do
    [ -d "$d" ] && CACHE_HITS+=("$d")
done
if [ -d "$HOME/.claude/plugins/marketplaces" ]; then
    for d in "$HOME/.claude/plugins/marketplaces"/*agentkey*; do
        [ -d "$d" ] && CACHE_HITS+=("$d")
    done
fi

if [ ${#CACHE_HITS[@]} -eq 0 ]; then
    skipped "No cache found"
else
    for d in "${CACHE_HITS[@]}"; do
        rm -rf "$d" && ok "Removed $d"
    done
fi

# ── 5. Shell RC environment exports (legacy) ──────────────────────────────
step "5. Shell environment exports (legacy)"

changed=false
for RC in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
    [ -f "$RC" ] || continue
    if grep -q "agentkey-env-start" "$RC" 2>/dev/null; then
        if have_python; then
            py - "$RC" <<'EOF'
import re, sys
p = sys.argv[1]
c = open(p).read()
n = re.sub(r'\n# agentkey-env-start.*?# agentkey-env-end', '', c, flags=re.DOTALL)
if n != c: open(p, 'w').write(n)
EOF
            ok "Cleaned agentkey env block from $RC"
            changed=true
        else
            warn "python not found — edit $RC manually (look for 'agentkey-env-start')"
        fi
    fi
done
$changed || skipped "No agentkey env block in any shell RC"

# ── 6. CLAUDE.md cleanup (legacy) ─────────────────────────────────────────
step "6. CLAUDE.md sections (legacy)"

md_changed=false
for CLAUDE_MD in "$HOME/.claude/CLAUDE.md" ".claude/CLAUDE.md" "CLAUDE.md"; do
    [ -f "$CLAUDE_MD" ] || continue
    grep -q "AgentKey\|agentkey\|AGENTKEY" "$CLAUDE_MD" 2>/dev/null || continue
    if have_python; then
        OUT=$(py - "$CLAUDE_MD" <<'EOF'
import re, sys
p = sys.argv[1]
c = open(p).read()
c2 = re.sub(r'\n# AgentKey\n.*?(?=\n# |\Z)', '', c, flags=re.DOTALL)
c2 = re.sub(r'\n[^\n]*(\.agentkey|agentkey.*activation\.md|agentkey.*SKILL\.md)[^\n]*', '', c2, flags=re.IGNORECASE)
if c2 != c:
    open(p, 'w').write(c2)
    print("CHANGED")
else:
    print("NO_MATCH")
EOF
)
        if [ "$OUT" = "CHANGED" ]; then
            ok "Removed AgentKey section from $CLAUDE_MD"
            md_changed=true
        fi
    else
        warn "python not found — edit $CLAUDE_MD manually"
    fi
done
$md_changed || skipped "No removable AgentKey section in CLAUDE.md"

# ── 7. npm / npx caches ───────────────────────────────────────────────────
step "7. npm / npx caches"

if command -v npm >/dev/null 2>&1; then
    if npm list -g --depth=0 2>/dev/null | grep -q "@agentkey/mcp"; then
        info "Uninstalling global @agentkey/mcp ..."
        if npm uninstall -g @agentkey/mcp >/dev/null 2>&1; then
            ok "Removed @agentkey/mcp"
        else
            warn "Could not remove @agentkey/mcp — try: npm uninstall -g @agentkey/mcp"
        fi
    else
        skipped "Global @agentkey/mcp not installed"
    fi
else
    skipped "npm not on PATH"
fi

if [ -d "$HOME/.npm/_npx" ]; then
    NPX_HITS=$(find "$HOME/.npm/_npx" -maxdepth 3 -type d -iname "*agentkey*" 2>/dev/null || true)
    if [ -n "$NPX_HITS" ]; then
        echo "$NPX_HITS" | xargs rm -rf
        ok "Cleared agentkey entries from npx cache"
    else
        skipped "No agentkey entries in npx cache"
    fi
else
    skipped "No ~/.npm/_npx directory"
fi

# ── 7b. AgentKey config dir (snooze/disable/telemetry state) ─────────────
step "7b. AgentKey config directory"

AGENTKEY_CFG="$HOME/.config/agentkey"
if [ -d "$AGENTKEY_CFG" ]; then
    rm -rf "$AGENTKEY_CFG" && ok "Removed $AGENTKEY_CFG"
else
    skipped "No $AGENTKEY_CFG directory"
fi

# ── 8. Residual artifacts ─────────────────────────────────────────────────
step "8. Residual artifacts"

# 8a. MCP stdio log (macOS only; Claude Desktop path)
MCP_LOG_MAC="$HOME/Library/Logs/Claude/mcp-server-agentkey.log"
if [ -f "$MCP_LOG_MAC" ]; then
    rm -f "$MCP_LOG_MAC" && ok "Removed $MCP_LOG_MAC"
fi

# 8b. Plugin registry JSONs — strip any agentkey-keyed entries
if have_python; then
    for REG in "$HOME/.claude/plugins/installed_plugins.json" \
               "$HOME/.claude/plugins/known_marketplaces.json" \
               "$HOME/.claude/mcp-needs-auth-cache.json"; do
        [ -f "$REG" ] || continue
        RESULT=$(py - "$REG" <<'EOF'
import json, sys
p = sys.argv[1]
try:
    with open(p) as f: d = json.load(f)
except Exception: sys.exit(0)

def scrub(obj):
    removed = 0
    if isinstance(obj, dict):
        for k in list(obj.keys()):
            if 'agentkey' in k.lower(): del obj[k]; removed += 1
            else: removed += scrub(obj[k])
    elif isinstance(obj, list):
        kept = []
        for item in obj:
            s = json.dumps(item).lower() if not isinstance(item, str) else item.lower()
            if 'agentkey' in s: removed += 1
            else: removed += scrub(item); kept.append(item)
        obj[:] = kept
    return removed

n = scrub(d)
if n:
    with open(p, 'w') as f: json.dump(d, f, indent=2)
print(n)
EOF
)
        if [[ "$RESULT" =~ ^[0-9]+$ ]] && [ "$RESULT" -gt 0 ]; then
            ok "Cleaned $RESULT entry/entries from $REG"
        fi
    done
fi

# ── Done ──────────────────────────────────────────────────────────────────
printf "\n  ${BOLD}✓ Uninstall complete.${NC}  Restart your agent to apply changes.\n\n"
