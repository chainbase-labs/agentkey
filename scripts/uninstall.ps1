#Requires -Version 5.1
<#
.SYNOPSIS
    AgentKey uninstaller for Windows
.DESCRIPTION
    Usage:
        irm https://agentkey.app/uninstall.ps1 | iex
        & ([scriptblock]::Create((irm https://agentkey.app/uninstall.ps1))) -KeepMarketplace
        & ([scriptblock]::Create((irm https://agentkey.app/uninstall.ps1))) -ForceInRepo

    Cleans up everything install.ps1 (and the legacy two-command flow) ever wrote:
      1. Skill files in every agent   (via `skills remove`)
      2. MCP server entries           (Claude Code / Claude Desktop / Cursor)
      3. Plugin + marketplace caches
      4. CLAUDE.md sections + npm/npx caches (legacy)
#>

[CmdletBinding()]
param(
    [switch]$KeepMarketplace,
    [switch]$ForceInRepo,
    [switch]$SkipSkillRemove,
    [switch]$Help
)

$ErrorActionPreference = 'Continue'

if ($Help) {
    @'
AgentKey uninstaller (Windows)

Usage:
  irm https://agentkey.app/uninstall.ps1 | iex

Parameters:
  -KeepMarketplace    Keep the Claude Code plugin marketplace registration
  -ForceInRepo        Allow running inside the AgentKey-Skill source repo
  -SkipSkillRemove    Skip 'npx skills remove' (only clean configs/caches)
  -Help               Show this help
'@
    exit 0
}

# ── UI helpers ────────────────────────────────────────────────────────────
function Write-Step ($t) { Write-Host ''; Write-Host "  $t" -ForegroundColor White }
function Write-Info ($t) { Write-Host "  › $t" -ForegroundColor Gray }
function Write-Ok   ($t) { Write-Host "  ✓ $t" -ForegroundColor Green }
function Write-Warn2($t) { Write-Host "  ! $t" -ForegroundColor Yellow }
function Write-Skip ($t) { Write-Host "  - $t" -ForegroundColor DarkGray }
function Write-Err  ($t) { Write-Host "  ✗ $t" -ForegroundColor Red }

# ── Safety rail ──────────────────────────────────────────────────────────
if ((Test-Path '.claude-plugin/plugin.json') -and -not $ForceInRepo) {
    $content = Get-Content '.claude-plugin/plugin.json' -Raw -ErrorAction SilentlyContinue
    if ($content -match '"name"\s*:\s*"agentkey"') {
        Write-Host ''
        Write-Host '  AgentKey — Uninstall' -ForegroundColor White
        Write-Host ''
        Write-Err 'Refusing to run inside the AgentKey-Skill source repo.'
        Write-Host "  Running here would wipe this repo's own .mcp.json and CLAUDE.md." -ForegroundColor DarkGray
        Write-Host '  Re-run with -ForceInRepo if you really mean it.' -ForegroundColor DarkGray
        Write-Host ''
        exit 2
    }
}

Write-Host ''
Write-Host '  AgentKey — Uninstall' -ForegroundColor White
Write-Host '  https://agentkey.app' -ForegroundColor DarkGray

# ── 1. Skill removal via skills CLI ──────────────────────────────────────
Write-Step '1. Skill files'

if ($SkipSkillRemove) {
    Write-Skip 'Skipped (-SkipSkillRemove)'
} elseif (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    Write-Warn2 "npx not found — skipping 'skills remove'"
    Write-Host '     Manual: npx skills remove agentkey -g' -ForegroundColor DarkGray
} else {
    # `skills remove` takes the **skill name** (`agentkey`), not the repo path.
    # The CLI also exits 0 when nothing matches, so we inspect stdout instead.
    Write-Info 'Running: npx -y skills remove agentkey -g -y'
    $removeOutput = (& npx -y skills remove agentkey -g -y 2>&1) -join "`n"
    if ($removeOutput -match 'Successfully removed') {
        Write-Ok 'Skill removed from detected agents'
    } elseif ($removeOutput -match 'No matching skills found') {
        Write-Skip "Not registered with 'skills' CLI (already removed or installed via plugin marketplace)"
    } else {
        Write-Warn2 "'skills remove' produced unexpected output — some agents may still have skill files"
        Write-Host '     Check manually: npx skills list -g' -ForegroundColor DarkGray
    }
}

# ── 2. MCP config cleanup ────────────────────────────────────────────────
Write-Step '2. MCP server entries'

$home2 = [Environment]::GetFolderPath('UserProfile')
$mcpConfigs = @(
    (Join-Path $home2 '.claude.json'),                                            # Claude Code
    (Join-Path $home2 '.cursor\mcp.json'),                                        # Cursor
    (Join-Path $env:APPDATA 'Claude\claude_desktop_config.json')                  # Claude Desktop
)

function Clean-McpConfig($path) {
    if (-not (Test-Path $path)) {
        Write-Skip "$([System.IO.Path]::GetFileName($path)) not found"
        return
    }
    try {
        $raw = Get-Content $path -Raw
        $obj = $raw | ConvertFrom-Json
    } catch {
        Write-Warn2 "Could not parse $path — skipping"
        return
    }

    $removed = 0

    if ($obj.mcpServers) {
        $keys = @($obj.mcpServers.PSObject.Properties.Name)
        foreach ($k in $keys) {
            if ($k -match 'agentkey') {
                $obj.mcpServers.PSObject.Properties.Remove($k)
                $removed++
            }
        }
    }
    # Per-project mcpServers (Claude Code ~/.claude.json shape)
    if ($obj.projects) {
        $projNames = @($obj.projects.PSObject.Properties.Name)
        foreach ($pn in $projNames) {
            $proj = $obj.projects.$pn
            if ($proj.mcpServers) {
                $pkeys = @($proj.mcpServers.PSObject.Properties.Name)
                foreach ($k in $pkeys) {
                    if ($k -match 'agentkey') {
                        $proj.mcpServers.PSObject.Properties.Remove($k)
                        $removed++
                    }
                }
            }
        }
    }

    if ($removed -gt 0) {
        ($obj | ConvertTo-Json -Depth 100) | Set-Content -Path $path -Encoding UTF8
        Write-Ok "Removed $removed entry/entries from $path"
    } else {
        Write-Skip "No agentkey entry in $path"
    }
}

foreach ($cfg in $mcpConfigs) { Clean-McpConfig $cfg }

# ── 3. Claude Code plugin registrations (legacy) ─────────────────────────
Write-Step '3. Claude Code plugin registrations (legacy)'

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Skip 'Claude Code CLI not on PATH — nothing to do here'
} else {
    $pluginList = & claude plugin list 2>$null
    $markets = @()
    if ($pluginList) {
        $markets = $pluginList | Select-String -Pattern 'agentkey@[a-zA-Z0-9_-]+' -AllMatches |
                   ForEach-Object { $_.Matches.Value } | Sort-Object -Unique
    }
    if ($markets.Count -eq 0) {
        Write-Skip 'No agentkey plugin registered'
    } else {
        foreach ($entry in $markets) {
            $name = $entry.Split('@')[0]
            Write-Info "Uninstalling $entry ..."
            & claude plugin uninstall $name --scope user 2>$null
            if ($LASTEXITCODE -eq 0) { Write-Ok "Removed $entry" }
            else { Write-Warn2 "Could not remove $entry" }
        }
    }

    $mcpList = & claude mcp list 2>$null
    if ($mcpList -and ($mcpList -match '^agentkey')) {
        Write-Info "Removing MCP server 'agentkey' via claude CLI ..."
        & claude mcp remove agentkey 2>$null
        if ($LASTEXITCODE -eq 0) { Write-Ok 'MCP server removed' }
        else { Write-Warn2 'Could not remove MCP server via claude CLI' }
    } else {
        Write-Skip "No 'agentkey' MCP via claude CLI"
    }

    if ($KeepMarketplace) {
        Write-Skip 'Marketplace removal skipped (-KeepMarketplace)'
    } else {
        $mktList = & claude plugin marketplace list 2>$null
        $agentkeyMkts = @()
        if ($mktList) {
            $joined = $mktList -join "`n"
            if ($joined -match '(AgentKey-Skill|chainbase-labs/AgentKey-Skill|agentkey-skill|chainbase-labs/agentkey)') {
                $agentkeyMkts = $mktList | Select-String -Pattern '^\s*❯\s+([a-zA-Z0-9_-]+)' |
                                ForEach-Object { $_.Matches[0].Groups[1].Value }
            }
        }
        if ($agentkeyMkts.Count -eq 0) {
            Write-Skip 'No AgentKey marketplace entry'
        } else {
            foreach ($mkt in $agentkeyMkts) {
                Write-Info "Removing marketplace '$mkt' ..."
                & claude plugin marketplace remove $mkt 2>$null
                if ($LASTEXITCODE -eq 0) { Write-Ok "Removed marketplace '$mkt'" }
                else { Write-Warn2 "Could not remove marketplace '$mkt'" }
            }
        }
    }
}

# ── 4. Plugin + marketplace caches ────────────────────────────────────────
Write-Step '4. Plugin / marketplace caches'

$cacheHits = @()
$pluginCache = Join-Path $home2 '.claude\plugins\cache'
if (Test-Path $pluginCache) {
    $cacheHits += Get-ChildItem -Path $pluginCache -Directory -Filter 'agentkey*' -ErrorAction SilentlyContinue
}
$mktCache = Join-Path $home2 '.claude\plugins\marketplaces'
if (Test-Path $mktCache) {
    $cacheHits += Get-ChildItem -Path $mktCache -Directory -Filter '*agentkey*' -ErrorAction SilentlyContinue
}
if ($cacheHits.Count -eq 0) {
    Write-Skip 'No cache found'
} else {
    foreach ($d in $cacheHits) {
        Remove-Item -Recurse -Force $d.FullName -ErrorAction SilentlyContinue
        Write-Ok "Removed $($d.FullName)"
    }
}

# ── 5. CLAUDE.md cleanup (legacy) ─────────────────────────────────────────
Write-Step '5. CLAUDE.md sections (legacy)'

$mdChanged = $false
$candidates = @(
    (Join-Path $home2 '.claude\CLAUDE.md'),
    '.claude\CLAUDE.md',
    'CLAUDE.md'
)
foreach ($md in $candidates) {
    if (-not (Test-Path $md)) { continue }
    $c = Get-Content $md -Raw
    if ($c -notmatch '(AgentKey|agentkey|AGENTKEY)') { continue }
    $c2 = [regex]::Replace($c, '\n# AgentKey\n.*?(?=\n# |\z)', '', 'Singleline')
    $c2 = [regex]::Replace($c2, '\n[^\n]*(\.agentkey|agentkey.*activation\.md|agentkey.*SKILL\.md)[^\n]*', '', 'IgnoreCase')
    if ($c2 -ne $c) {
        Set-Content -Path $md -Value $c2 -Encoding UTF8
        Write-Ok "Removed AgentKey section from $md"
        $mdChanged = $true
    }
}
if (-not $mdChanged) { Write-Skip 'No removable AgentKey section in CLAUDE.md' }

# ── 6. npm / npx caches ───────────────────────────────────────────────────
Write-Step '6. npm / npx caches'

if (Get-Command npm -ErrorAction SilentlyContinue) {
    $globalList = & npm list -g --depth=0 2>$null
    if ($globalList -and ($globalList -match '@agentkey/mcp')) {
        Write-Info 'Uninstalling global @agentkey/mcp ...'
        & npm uninstall -g '@agentkey/mcp' 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Ok 'Removed @agentkey/mcp' }
        else { Write-Warn2 'Could not remove @agentkey/mcp' }
    } else {
        Write-Skip 'Global @agentkey/mcp not installed'
    }
} else {
    Write-Skip 'npm not on PATH'
}

$npxCache = Join-Path $home2 '.npm\_npx'
if (Test-Path $npxCache) {
    $hits = Get-ChildItem -Path $npxCache -Directory -Recurse -Depth 2 -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match 'agentkey' }
    if ($hits) {
        $hits | ForEach-Object { Remove-Item -Recurse -Force $_.FullName -ErrorAction SilentlyContinue }
        Write-Ok 'Cleared agentkey entries from npx cache'
    } else {
        Write-Skip 'No agentkey entries in npx cache'
    }
} else {
    Write-Skip 'No npx cache directory'
}

# ── 7. Residual plugin registries ─────────────────────────────────────────
Write-Step '7. Residual plugin registries'

$regs = @(
    (Join-Path $home2 '.claude\plugins\installed_plugins.json'),
    (Join-Path $home2 '.claude\plugins\known_marketplaces.json'),
    (Join-Path $home2 '.claude\mcp-needs-auth-cache.json')
)

function Scrub-Agentkey($node) {
    $removed = 0
    if ($node -is [System.Management.Automation.PSCustomObject]) {
        $keys = @($node.PSObject.Properties.Name)
        foreach ($k in $keys) {
            if ($k -match 'agentkey') {
                $node.PSObject.Properties.Remove($k)
                $removed++
            } else {
                $removed += Scrub-Agentkey $node.$k
            }
        }
    } elseif ($node -is [System.Collections.IList]) {
        # Rebuild list without agentkey items
        $kept = New-Object System.Collections.ArrayList
        foreach ($item in $node) {
            $s = ($item | ConvertTo-Json -Depth 10 -Compress).ToLower()
            if ($s -match 'agentkey') {
                $removed++
            } else {
                $removed += Scrub-Agentkey $item
                [void]$kept.Add($item)
            }
        }
        return @{ removed = $removed; list = $kept }
    }
    return $removed
}

foreach ($reg in $regs) {
    if (-not (Test-Path $reg)) { continue }
    try {
        $obj = Get-Content $reg -Raw | ConvertFrom-Json
    } catch { continue }

    $res = Scrub-Agentkey $obj
    $n = if ($res -is [hashtable]) { $res.removed } else { $res }
    if ($n -gt 0) {
        ($obj | ConvertTo-Json -Depth 100) | Set-Content -Path $reg -Encoding UTF8
        Write-Ok "Cleaned $n entry/entries from $reg"
    }
}

# ── Done ──────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host '  ✓ Uninstall complete.' -ForegroundColor Green -NoNewline
Write-Host '  Restart your agent to apply changes.' -ForegroundColor White
Write-Host ''
