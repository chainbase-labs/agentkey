#Requires -Version 5.1
<#
.SYNOPSIS
    AgentKey installer for Windows
.DESCRIPTION
    Usage:
        irm https://agentkey.app/install.ps1 | iex
        & ([scriptblock]::Create((irm https://agentkey.app/install.ps1))) -Yes
        & ([scriptblock]::Create((irm https://agentkey.app/install.ps1))) -Only "claude-code,cursor"

    Behavior mirrors install.sh: checks Node >= 18 (installs via winget/scoop/choco),
    auto-detects which AI agents are installed and runs `npx skills add` for them,
    then `npx @agentkey/mcp --auth-login` for device auth. The auth step opens a
    local browser by default; under SSH / Docker / OpenClaw it switches to a
    QR + URL flow that the user scans on a phone (`--no-browser` server-side flag).
    MCP config is written automatically for Claude Code / Claude Desktop / Cursor.
#>

[CmdletBinding()]
param(
    [switch]$Yes,
    [switch]$Interactive,
    [string]$Only,
    [switch]$AllAgents,
    [switch]$ListAgents,
    [switch]$Remote,
    [switch]$Local,
    [switch]$ForceMcp,
    [switch]$SkipSkill,
    [switch]$SkipMcp,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$SkillRepo   = 'chainbase-labs/agentkey'
$McpPackage  = '@agentkey/mcp'
$NodeMinMajor = 18

# ── Agent markers (mirror of install.sh) ──────────────────────────────────
# Subset of vercel-labs/skills' 45 supported agent IDs that have reliable
# Windows-side markers. Sync source:
#   https://github.com/vercel-labs/skills (Supported Agents table).
$AgentMarkers = @(
    @{ Id = 'claude-code'; Markers = @("path:$env:USERPROFILE\.claude.json", 'cmd:claude', "path:$env:APPDATA\Claude") }
    @{ Id = 'cursor';      Markers = @("path:$env:USERPROFILE\.cursor", 'cmd:cursor', "path:$env:LOCALAPPDATA\Programs\cursor") }
    @{ Id = 'codex';       Markers = @("path:$env:USERPROFILE\.codex", 'cmd:codex') }
    @{ Id = 'gemini-cli';  Markers = @("path:$env:USERPROFILE\.gemini", 'cmd:gemini') }
    @{ Id = 'opencode';    Markers = @("path:$env:USERPROFILE\.opencode", 'cmd:opencode') }
    @{ Id = 'openclaw';    Markers = @("path:$env:USERPROFILE\.openclaw") }
    @{ Id = 'qwen-code';   Markers = @("path:$env:USERPROFILE\.qwen", 'cmd:qwen') }
    @{ Id = 'iflow-cli';   Markers = @("path:$env:USERPROFILE\.iflow", 'cmd:iflow') }
    @{ Id = 'windsurf';    Markers = @("path:$env:USERPROFILE\.windsurf", 'cmd:windsurf') }
    @{ Id = 'warp';        Markers = @("path:$env:USERPROFILE\.warp") }
    @{ Id = 'amp';         Markers = @('cmd:amp') }
    @{ Id = 'crush';       Markers = @('cmd:crush') }
    @{ Id = 'goose';       Markers = @('cmd:goose') }
    @{ Id = 'droid';       Markers = @('cmd:droid') }
    @{ Id = 'kode';        Markers = @('cmd:kode') }
    @{ Id = 'kilo';        Markers = @('cmd:kilo') }
    @{ Id = 'kimi-cli';    Markers = @("path:$env:USERPROFILE\.kimi", 'cmd:kimi') }
    @{ Id = 'kiro-cli';    Markers = @("path:$env:USERPROFILE\.kiro", 'cmd:kiro') }
)

# ── UI helpers ────────────────────────────────────────────────────────────
function Write-Banner {
    Write-Host ''
    Write-Host '   █████   ██████  ███████ ███    ██ ████████ ██   ██ ███████ ██    ██' -ForegroundColor Cyan
    Write-Host '  ██   ██ ██       ██      ████   ██    ██    ██  ██  ██       ██  ██ ' -ForegroundColor Cyan
    Write-Host '  ███████ ██   ███ █████   ██ ██  ██    ██    █████   █████     ████  ' -ForegroundColor Cyan
    Write-Host '  ██   ██ ██    ██ ██      ██  ██ ██    ██    ██  ██  ██         ██   ' -ForegroundColor Cyan
    Write-Host '  ██   ██  ██████  ███████ ██   ████    ██    ██   ██ ███████    ██   ' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  One command. Full internet access for your AI agent.' -ForegroundColor White
    Write-Host '  https://agentkey.app' -ForegroundColor DarkGray
    Write-Host ''
}

function Write-Step ($text) { Write-Host ''; Write-Host "  $text" -ForegroundColor White }
function Write-Info ($text) { Write-Host "  › $text" -ForegroundColor Gray }
function Write-Ok   ($text) { Write-Host "  ✓ $text" -ForegroundColor Green }
function Write-Warn2($text) { Write-Host "  ! $text" -ForegroundColor Yellow }
function Write-Err  ($text) { Write-Host "  ✗ $text" -ForegroundColor Red }
function Write-Muted($text) { Write-Host "    $text" -ForegroundColor DarkGray }

function Die ($text) { Write-Err $text; exit 1 }

# ── Helpers: agent + remote detection ─────────────────────────────────────
function Test-AgentMarker {
    param([string]$Marker)
    if ($Marker.StartsWith('cmd:')) {
        return [bool](Get-Command $Marker.Substring(4) -ErrorAction SilentlyContinue)
    }
    if ($Marker.StartsWith('path:')) {
        return Test-Path -LiteralPath $Marker.Substring(5)
    }
    return $false
}

function Get-DetectedAgents {
    $hits = New-Object System.Collections.Generic.List[string]
    foreach ($entry in $AgentMarkers) {
        foreach ($m in $entry.Markers) {
            if (Test-AgentMarker $m) { $hits.Add($entry.Id) | Out-Null; break }
        }
    }
    return @($hits | Sort-Object -Unique)
}

# Detect "remote install" — context where opening a browser on this host
# is futile (SSH, Docker, OpenClaw remote channels). Mirrors the bash
# script's logic.
function Test-RemoteInstall {
    if ($script:Local)  { return $false }
    if ($script:Remote) { return $true }

    if (Test-Path -LiteralPath "$env:USERPROFILE\.openclaw") { return $true }
    if ($env:SSH_CONNECTION -or $env:SSH_TTY) { return $true }
    return $false
}

# Cheap "is AgentKey already configured?" check across known MCP config files.
function Test-AlreadyAuthed {
    $configs = @(
        "$env:USERPROFILE\.claude.json",
        "$env:USERPROFILE\.cursor\mcp.json",
        "$env:APPDATA\Claude\claude_desktop_config.json"
    )
    foreach ($cfg in $configs) {
        if (-not (Test-Path -LiteralPath $cfg)) { continue }
        $content = Get-Content -Raw -LiteralPath $cfg -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        if ($content -match '"agentkey"' -and $content -match '"AGENTKEY_API_KEY"\s*:\s*"ak_[A-Za-z0-9_-]+"') {
            return $true
        }
    }
    return $false
}

# ── Help ──────────────────────────────────────────────────────────────────
if ($Help) {
    @'
AgentKey installer for Windows

Usage:
  irm https://agentkey.app/install.ps1 | iex
  & ([scriptblock]::Create((irm https://agentkey.app/install.ps1))) -Yes

Parameters:
  -Yes              Non-interactive: install skill to every detected agent, no prompts
  -Interactive      Force interactive mode (fails if console input is redirected)
  -Only <a,b,c>     Only install skill for these agents (e.g. "claude-code,cursor")
  -AllAgents        Skip auto-detection; let 'skills' CLI install for every detected agent
  -ListAgents       Print the agents we'd auto-select on this machine and exit
  -Remote           Force remote-install mode: print URL + QR for the auth step,
                    do NOT auto-open a local browser. Use this when running over
                    SSH, in WinRM, in a container, or via OpenClaw / Claude Code
                    remote channels.
  -Local            Force local mode (auto-open browser) and bypass remote heuristics
  -ForceMcp         Re-run MCP auth even if AgentKey is already configured
  -SkipSkill        Skip the skill install step (only run MCP auth)
  -SkipMcp          Skip the MCP auth step (only install the skill)
  -Help             Show this help

Behavior:
  The installer auto-detects which AI agents are on this machine and
  pre-selects them for skill installation. Remote-install mode is auto-
  detected from %USERPROFILE%\.openclaw and SSH env vars; override with
  -Remote / -Local.
'@
    exit 0
}

if ($Remote -and $Local) {
    Die '-Remote and -Local are mutually exclusive.'
}

if ($ListAgents) {
    $detected = Get-DetectedAgents
    if ($detected.Count -gt 0) { $detected -join "`n" | Write-Output }
    else { Write-Host 'no agents detected on this host' -ForegroundColor Yellow }
    exit 0
}

Write-Banner

# ── 1. Preflight ──────────────────────────────────────────────────────────
Write-Step '1. Preflight'

# Platform guard
if (-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) {
    Die 'This script targets Windows. On macOS/Linux use install.sh instead.'
}
Write-Ok 'Platform: windows'

# Resolve interactive mode. PowerShell's `iex` runs in the current session, so
# Read-Host works natively even under `irm | iex`. The only thing we need to
# guard is truly redirected input (scheduled tasks, CI with redirected stdin).
$InputRedirected = $false
try { $InputRedirected = [Console]::IsInputRedirected } catch { $InputRedirected = $false }

$Mode = $null
if ($Yes) { $Mode = 'noninteractive' }
elseif ($Interactive) {
    if ($InputRedirected) { Die '-Interactive requested but console input is redirected.' }
    $Mode = 'interactive'
}
elseif ($InputRedirected) {
    $Mode = 'noninteractive'
    Write-Warn2 'No interactive console detected — falling back to -Yes'
}
else {
    $Mode = 'interactive'
}
Write-Ok "Mode: $Mode"

# Node check
function Get-NodeMajor {
    try {
        $v = (& node --version) 2>$null
        if ($v -match '^v(\d+)\.') { return [int]$Matches[1] }
    } catch {}
    return 0
}

function Install-Node {
    Write-Info "Installing Node.js LTS ..."
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install -e --id OpenJS.NodeJS.LTS --silent --accept-source-agreements --accept-package-agreements | Out-Null
    } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop install nodejs-lts | Out-Null
    } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
        choco install nodejs-lts -y | Out-Null
    } else {
        Die 'No package manager found (winget/scoop/choco). Install Node.js LTS manually: https://nodejs.org/'
    }
    # Refresh PATH so this session sees the newly installed node
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [System.Environment]::GetEnvironmentVariable('Path', 'User')
    Write-Ok 'Node.js installed'
}

$nodeMajor = Get-NodeMajor
if ($nodeMajor -ge $NodeMinMajor) {
    Write-Ok "Node.js: v$nodeMajor.x"
} else {
    if ($nodeMajor -gt 0) { Write-Warn2 "Node.js v$nodeMajor found but v$NodeMinMajor+ is required" }
    if ($Mode -eq 'interactive') {
        Write-Host ''
        Write-Host "  Node.js v$NodeMinMajor+ is required but not found." -ForegroundColor White
        $reply = Read-Host '  Install it now? [Y/n]'
        if ($reply -match '^(n|no)$') { Die 'Node.js required. Aborting.' }
    }
    Install-Node
}

if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Die 'npx not found after Node install — please reopen your terminal or reinstall Node.js.'
}

# ── 2. Install the AgentKey skill ─────────────────────────────────────────
if (-not $SkipSkill) {
    Write-Step '2. Install the AgentKey skill'

    # Resolve target agent list:
    #   1. -Only wins (manual override)
    #   2. else -AllAgents ⇒ no -a (let skills CLI auto-detect everything)
    #   3. else our auto-detection ⇒ -a <detected list>
    #   4. else (nothing detected) ⇒ no -a (fall back to skills CLI default)
    $targets = @()
    if ($Only) {
        $targets = $Only -split ',' | Where-Object { $_ -ne '' }
        Write-Info "Targeting agents from -Only: $($targets -join ', ')"
    } elseif ($AllAgents) {
        Write-Info "Installing for every agent the 'skills' CLI detects (-AllAgents)"
    } else {
        $targets = Get-DetectedAgents
        if ($targets.Count -gt 0) {
            Write-Ok "Detected agents on this host: $($targets -join ', ')"
            Write-Muted '(override with -Only <ids>, or use -AllAgents)'
        } else {
            Write-Info "No agents auto-detected — letting 'skills' CLI scan."
        }
    }

    $skillsArgs = @('-y', 'skills', 'add', $SkillRepo, '-g')
    if ($targets.Count -gt 0) {
        $skillsArgs += '-a'
        $skillsArgs += $targets
    }
    # Always pass -y in noninteractive mode AND when we already resolved
    # an explicit target list — there's nothing left to ask the user.
    if ($Mode -eq 'noninteractive' -or $targets.Count -gt 0) {
        $skillsArgs += '-y'
    }

    & npx @skillsArgs
    if ($LASTEXITCODE -ne 0) { Die "Failed to install skill via 'skills' CLI" }
    Write-Ok 'Skill installed'
} else {
    Write-Step '2. Install the AgentKey skill'
    Write-Muted 'Skipped (-SkipSkill)'
}

# ── 3. MCP authentication ────────────────────────────────────────────────
if ($SkipMcp) {
    Write-Step '3. Register the MCP server'
    Write-Muted 'Skipped (-SkipMcp)'
} elseif ((Test-AlreadyAuthed) -and -not $ForceMcp) {
    Write-Step '3. Register the MCP server'
    Write-Ok 'AgentKey is already configured in an MCP client config — skipping auth.'
    Write-Muted 'Re-run with -ForceMcp to authenticate again.'
} else {
    $isRemote = Test-RemoteInstall
    $authArgs = @('--auth-login')

    if ($isRemote) {
        Write-Step '3. Register the MCP server (remote auth: scan QR with phone)'
        Write-Info 'Detected remote install context — printing QR + URL instead of opening a browser here.'
        if (Test-Path -LiteralPath "$env:USERPROFILE\.openclaw") {
            Write-Muted '  reason: %USERPROFILE%\.openclaw exists (OpenClaw runtime)'
        } elseif ($env:SSH_CONNECTION -or $env:SSH_TTY) {
            Write-Muted '  reason: SSH session detected'
        }
        Write-Muted 'Override with -Local if you want a browser opened on this machine instead.'
        $authArgs += '--no-browser'
    } else {
        Write-Step '3. Register the MCP server (browser login)'
        Write-Info 'Opening your browser for AgentKey device authentication ...'
        Write-Muted 'When auth finishes, the MCP server is written into Claude Code / Claude Desktop / Cursor configs.'
    }
    Write-Host ''

    & npx -y $McpPackage @authArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Err 'MCP auth failed.'
        Write-Muted "Retry manually:  npx -y $McpPackage $($authArgs -join ' ')"
        exit 1
    }
    Write-Ok 'MCP server registered'
}

# ── 4. Summary ───────────────────────────────────────────────────────────
Write-Step '✨ Installation complete'
Write-Host ''
Write-Host '  Next steps' -ForegroundColor White
Write-Muted '1. Restart your agent (Claude Code / Cursor / etc.)'
Write-Muted '2. Ask it something that needs the internet:'
Write-Host '       "What has Musk been tweeting about lately?"' -ForegroundColor Cyan
Write-Host ''
Write-Host '  Docs       https://agentkey.app/docs' -ForegroundColor White
Write-Host '  Uninstall  irm https://agentkey.app/uninstall.ps1 | iex' -ForegroundColor White
Write-Host ''
