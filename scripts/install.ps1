#Requires -Version 5.1
<#
.SYNOPSIS
    AgentKey installer for Windows
.DESCRIPTION
    Usage:
        irm https://agentkey.app/install.ps1 | iex
        & ([scriptblock]::Create((irm https://agentkey.app/install.ps1))) -Yes
        & ([scriptblock]::Create((irm https://agentkey.app/install.ps1))) -Only "claude-code,cursor"
        & ([scriptblock]::Create((irm https://agentkey.app/install.ps1))) -NoTelemetry

    Behavior mirrors install.sh: checks Node >= 18 (installs via winget/scoop/choco),
    auto-detects which AI agents are installed and runs `npx skills add` for them,
    then `npx @agentkey/cli --auth-login` for device auth. The auth step always
    tries to open a local browser AND prints the URL so headless / SSH users can
    copy it elsewhere. MCP config is written automatically for Claude Code /
    Claude Desktop / Cursor.
#>

[CmdletBinding()]
param(
    [switch]$Yes,
    [switch]$Interactive,
    [string]$Only,
    [switch]$AllAgents,
    [switch]$ListAgents,
    [switch]$SkipSkill,
    [switch]$SkipMcp,
    [switch]$NoTelemetry,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$SkillRepo   = 'chainbase-labs/agentkey'
$CliPackage  = '@agentkey/cli'
$NodeMinMajor = 18

# ── Agent markers (mirror of install.sh) ──────────────────────────────────
# Subset of vercel-labs/skills' 45 supported agent IDs that have reliable
# Windows-side markers. Sync source:
#   https://github.com/vercel-labs/skills (Supported Agents table).
#
# IMPORTANT: ids here MUST match the `--only` ids accepted by both
# `npx skills add -a` and `npx -y @agentkey/cli --auth-login --only`.
# `claude-desktop` is the documented exception (no skill install path, but
# MCP config is writable) — it's listed below and used only for MCP --only.
$AgentMarkers = @(
    @{ Id = 'claude-code';    Markers = @("path:$env:USERPROFILE\.claude.json", 'cmd:claude') }
    @{ Id = 'claude-desktop'; Markers = @("path:$env:LOCALAPPDATA\AnthropicClaude", "path:$env:APPDATA\Claude\claude_desktop_config.json", "path:$env:APPDATA\Claude") }
    @{ Id = 'cursor';         Markers = @("path:$env:USERPROFILE\.cursor", 'cmd:cursor', "path:$env:LOCALAPPDATA\Programs\cursor") }
    @{ Id = 'codex';          Markers = @("path:$env:USERPROFILE\.codex", 'cmd:codex') }
    @{ Id = 'gemini-cli';     Markers = @("path:$env:USERPROFILE\.gemini", 'cmd:gemini') }
    @{ Id = 'opencode';       Markers = @("path:$env:APPDATA\opencode", "path:$env:USERPROFILE\.opencode", 'cmd:opencode') }
    @{ Id = 'openclaw';       Markers = @("path:$env:USERPROFILE\.openclaw", 'cmd:openclaw') }
    @{ Id = 'qwen-code';      Markers = @("path:$env:USERPROFILE\.qwen", 'cmd:qwen') }
    @{ Id = 'iflow-cli';      Markers = @("path:$env:USERPROFILE\.iflow", 'cmd:iflow') }
    @{ Id = 'windsurf';       Markers = @("path:$env:USERPROFILE\.codeium\windsurf", "path:$env:USERPROFILE\.windsurf", 'cmd:windsurf') }
    @{ Id = 'warp';           Markers = @("path:$env:USERPROFILE\.warp") }
    @{ Id = 'amp';            Markers = @("path:$env:APPDATA\amp", 'cmd:amp') }
    @{ Id = 'crush';          Markers = @("path:$env:APPDATA\crush", 'cmd:crush') }
    @{ Id = 'goose';          Markers = @("path:$env:APPDATA\goose", 'cmd:goose') }
    @{ Id = 'droid';          Markers = @('cmd:droid') }
    @{ Id = 'kode';           Markers = @('cmd:kode') }
    @{ Id = 'kilo';           Markers = @('cmd:kilo') }
    @{ Id = 'kimi-cli';       Markers = @("path:$env:USERPROFILE\.kimi", 'cmd:kimi') }
    @{ Id = 'kiro-cli';       Markers = @("path:$env:USERPROFILE\.kiro", 'cmd:kiro') }
)

# Agent ids that are MCP-only (no skill install path). Never passed to
# `npx skills add -a`, only to `--auth-login --only`.
$McpOnlyAgents = @('claude-desktop')

# Agent ids whose MCP registration the installer can drive automatically.
# Mirror of MCP_AUTO_AGENTS in install.sh and AGENT_REGISTRY in
# AgentKey-Server/cli/src/lib/mcp-clients.ts. Keep these three in sync.
$McpAutoAgents = @(
    'claude-code', 'claude-desktop', 'cursor', 'codex', 'gemini-cli',
    'opencode', 'qwen-code', 'iflow-cli', 'kimi-cli', 'kiro-cli',
    'windsurf', 'warp', 'amp', 'crush', 'droid', 'openclaw'
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

# ── Helpers: agent detection ──────────────────────────────────────────────
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
  -SkipSkill        Skip the skill install step (only run MCP auth)
  -SkipMcp          Skip the MCP auth step (only install the skill)
  -NoTelemetry      Disable anonymous usage telemetry (writes
                    %USERPROFILE%\.config\agentkey\telemetry-disabled so
                    the skill stays opted-out across runs)
  -Help             Show this help

Behavior:
  The installer auto-detects which AI agents are on this machine and
  pre-selects them for skill installation. The auth step always tries
  to open a browser and also prints the URL — so SSH / WinRM / Docker
  / OpenClaw users can copy the URL to any device with a browser.
'@
    exit 0
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

# Resolve telemetry intent: -NoTelemetry overrides everything; existing
# %USERPROFILE%\.config\agentkey\telemetry-disabled file means already-opted-out.
$TelemetryOptOutFile = Join-Path $env:USERPROFILE '.config\agentkey\telemetry-disabled'
if ($NoTelemetry) {
    New-Item -ItemType Directory -Path (Split-Path $TelemetryOptOutFile) -Force | Out-Null
    New-Item -ItemType File -Path $TelemetryOptOutFile -Force | Out-Null
    Write-Ok 'Telemetry: disabled (-NoTelemetry)'
} elseif (Test-Path -LiteralPath $TelemetryOptOutFile) {
    Write-Ok "Telemetry: disabled ($TelemetryOptOutFile exists)"
} else {
    Write-Info 'Telemetry: anonymous usage stats enabled (re-run with -NoTelemetry to opt out)'
}

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

# Resolve target agent list — shared between the skill step and the MCP step.
# $AllTargets   — every detected agent, including MCP-only ones (claude-desktop)
# $SkillTargets — $AllTargets minus MCP-only ids (those would fail `skills add`)
# $McpTargets   — $AllTargets filtered to ids the MCP CLI knows how to write
$AllTargets = @()
if ($Only) {
    $AllTargets = @($Only -split ',' | Where-Object { $_ -ne '' })
    Write-Info "Targeting agents from -Only: $($AllTargets -join ', ')"
} elseif ($AllAgents) {
    Write-Info "Installing for every agent the 'skills' CLI detects (-AllAgents)"
} else {
    $AllTargets = @(Get-DetectedAgents)
    if ($AllTargets.Count -gt 0) {
        Write-Ok "Detected agents on this host: $($AllTargets -join ', ')"
        Write-Muted '(override with -Only <ids>, or use -AllAgents)'
    } else {
        Write-Info "No agents auto-detected — letting 'skills' CLI scan."
    }
}

$SkillTargets = @($AllTargets | Where-Object { $_ -notin $McpOnlyAgents })
$McpTargets   = @($AllTargets | Where-Object { $_ -in   $McpAutoAgents })

# ── 2. Install the AgentKey skill ─────────────────────────────────────────
if ($SkipSkill) {
    Write-Step '2. Install the AgentKey skill'
    Write-Muted 'Skipped (-SkipSkill)'
} elseif ($AllTargets.Count -gt 0 -and $SkillTargets.Count -eq 0) {
    # User explicitly selected only MCP-only ids (e.g. `-Only claude-desktop`).
    # There's nothing for `skills add` to do — skip the step entirely rather
    # than fall through to "install for every detected agent."
    Write-Step '2. Install the AgentKey skill'
    Write-Muted "Skipped — selected targets ($($AllTargets -join ',')) are MCP-only (no skill install path)."
} else {
    Write-Step '2. Install the AgentKey skill'

    $skillsArgs = @('-y', 'skills', 'add', $SkillRepo, '-g')
    if ($SkillTargets.Count -gt 0) {
        $skillsArgs += '-a'
        $skillsArgs += $SkillTargets
    }
    # Always pass -y in noninteractive mode AND when we already resolved
    # an explicit target list — there's nothing left to ask the user.
    if ($Mode -eq 'noninteractive' -or $AllTargets.Count -gt 0) {
        $skillsArgs += '-y'
    }

    & npx @skillsArgs
    if ($LASTEXITCODE -ne 0) { Die "Failed to install skill via 'skills' CLI" }
    # The skills CLI sometimes prints "Installation failed" and still
    # exits 0 (e.g. network error during git clone). Verify the skill
    # actually landed on disk before declaring success. Paths must mirror
    # the `path:` markers in $AgentMarkers: most agents live under
    # %USERPROFILE%\.<agent>, but amp / crush / goose / opencode live
    # under %APPDATA%\<agent>.
    $userHome = [Environment]::GetFolderPath('UserProfile')
    $candidatePaths = @(
        (Join-Path $userHome    '.agents\skills\agentkey'),
        (Join-Path $userHome    '.claude\skills\agentkey'),
        (Join-Path $userHome    '.cursor\skills\agentkey'),
        (Join-Path $userHome    '.codex\skills\agentkey'),
        (Join-Path $userHome    '.gemini\skills\agentkey'),
        (Join-Path $userHome    '.opencode\skills\agentkey'),
        (Join-Path $userHome    '.openclaw\skills\agentkey'),
        (Join-Path $userHome    '.qwen\skills\agentkey'),
        (Join-Path $userHome    '.iflow\skills\agentkey'),
        (Join-Path $userHome    '.windsurf\skills\agentkey'),
        (Join-Path $userHome    '.warp\skills\agentkey'),
        (Join-Path $userHome    '.kimi\skills\agentkey'),
        (Join-Path $userHome    '.kiro\skills\agentkey'),
        # APPDATA-rooted agents (parity with install.sh's $HOME/.config/<agent>)
        (Join-Path $env:APPDATA 'amp\skills\agentkey'),
        (Join-Path $env:APPDATA 'crush\skills\agentkey'),
        (Join-Path $env:APPDATA 'goose\skills\agentkey'),
        (Join-Path $env:APPDATA 'opencode\skills\agentkey')
    )
    $agentkeyFound = $false
    foreach ($abs in $candidatePaths) {
        if (Test-Path (Join-Path $abs 'SKILL.md')) {
            $agentkeyFound = $true
            break
        }
    }
    if (-not $agentkeyFound) {
        Die "Skill install reported success but no agentkey SKILL.md was created — likely a network or git clone failure. Retry: npx -y skills add $SkillRepo -g -y"
    }
    Write-Ok 'Skill installed'
}

# ── 3. MCP authentication ────────────────────────────────────────────────
# Always run auth-login. The CLI itself decides whether the existing token
# can be reused or a fresh device-code flow is needed — the installer no
# longer second-guesses by sniffing config files (which produced false
# positives across the stdio → HTTP schema change).
if ($SkipMcp) {
    Write-Step '3. Register the MCP server'
    Write-Muted 'Skipped (-SkipMcp)'
} elseif ($AllTargets.Count -gt 0 -and $McpTargets.Count -eq 0) {
    # User selected ONLY MCP-incompatible agents (goose / kode / kilo via
    # -Only). Running auth-login without --only would silently register MCP
    # in every detected agent, overriding the user's explicit scope. Skip
    # rather than over-register. See PR #41 B1.
    Write-Step '3. Register the MCP server'
    Write-Muted "Skipped — selected agents ($($AllTargets -join ',')) need manual MCP setup (see SKILL.md Fallback section)."
} else {
    # Pin MCP registration to the same agent list the skill step targeted.
    # When McpTargets is empty (auto-detect found nothing), let
    # `@agentkey/cli` do its own detection — same fallback we use for skill
    # install. Older CLI versions silently ignore --only, so this is
    # forward-compatible.
    $authArgs = @('--auth-login')
    if ($McpTargets.Count -gt 0) {
        $authArgs += '--only'
        $authArgs += ($McpTargets -join ',')
    }

    Write-Step '3. Register the MCP server'
    Write-Info 'Opening your browser for AgentKey device authentication ...'
    if ($McpTargets.Count -gt 0) {
        Write-Muted "Will register MCP in: $($McpTargets -join ', ')"
    } else {
        Write-Muted "If a browser doesn't open (SSH / WinRM / Docker / headless), the auth URL is also printed below — open it on any device to finish."
    }
    Write-Host ''

    # Telemetry context for install_completed. Opt-out is honored at the
    # SOURCE: when AGENTKEY_TELEMETRY=0, no other context env vars are
    # exported — hostname-derived fingerprint, agent lists, and installer
    # flags are never computed nor passed to the child `npx @agentkey/cli`
    # process. The server treats AGENTKEY_TELEMETRY=0 as a hard skip.
    if ($NoTelemetry -or (Test-Path -LiteralPath $TelemetryOptOutFile)) {
        $env:AGENTKEY_TELEMETRY = '0'
    } else {
        $env:AGENTKEY_TELEMETRY = '1'

        $_hn    = [System.Net.Dns]::GetHostName()
        $_user  = $env:USERNAME
        $_input = "$_hn|windows|$_user"
        $_bytes = [System.Text.Encoding]::UTF8.GetBytes($_input)
        $_sha   = [System.Security.Cryptography.SHA256]::Create()
        $_hash  = ($_sha.ComputeHash($_bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
        $DeviceFingerprint = $_hash.Substring(0, 16)

        $DetectedAgents = Get-DetectedAgents

        $env:AGENTKEY_INSTALL_SOURCE     = 'one_liner'
        $env:AGENTKEY_DETECTED_AGENTS    = ($DetectedAgents -join ',')
        $env:AGENTKEY_SELECTED_AGENTS    = ($AllTargets -join ',')
        $env:AGENTKEY_INSTALLER_FLAGS    = ($PSBoundParameters.Keys | ForEach-Object { "-$_" }) -join ','
        $env:AGENTKEY_DEVICE_FINGERPRINT = $DeviceFingerprint
    }

    & npx -y $CliPackage @authArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Err 'MCP auth failed.'
        Write-Muted "Retry manually:  npx -y $CliPackage $($authArgs -join ' ')"
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
