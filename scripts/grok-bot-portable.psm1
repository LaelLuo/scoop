# Grok Bot portable mappings: create/remove owned symlinks only.
# Never copy-delete existing user data (unlike scripts/portable.psm1).
# Existing ordinary directories refuse install; use the migration playbook.

function Get-GrokBotProcessName {
    if ($env:GROK_BOT_PORTABLE_PROCESS_NAME) { return $env:GROK_BOT_PORTABLE_PROCESS_NAME }
    return 'Grok Bot'
}

function Assert-GrokBotNotRunning {
    if ($env:GROK_BOT_PORTABLE_SKIP_PROCESS_CHECK -eq '1') { return }
    $name = Get-GrokBotProcessName
    $procs = @(Get-Process -Name $name -ErrorAction SilentlyContinue)
    if ($procs.Count -gt 0) {
        throw "Grok Bot is running (process '$name', count=$($procs.Count)). Quit the app before install/update/uninstall. Scoop will not stop the process."
    }
}

function Get-GrokBotPathEntry([string]$Path) {
    [void][System.IO.Path]::GetFullPath($Path)
    try { return Get-Item -LiteralPath $Path -Force -ErrorAction Stop }
    catch {
        if ($_.CategoryInfo.Category -ne 'ObjectNotFound') { throw }
        $parent = Split-Path -Parent $Path
        $name = Split-Path -Leaf $Path
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $Path) { throw }
        $parentEntry = Get-GrokBotPathEntry $parent
        if ($null -eq $parentEntry) { return $null }
        if (-not $parentEntry.PSIsContainer) { throw "Grok Bot path parent is not a directory: $parent" }
        $entries = @(Get-ChildItem -LiteralPath $parent -Force -ErrorAction Stop | Where-Object Name -EQ $name)
        if ($entries.Count -gt 0) { throw "Cannot inspect existing Grok Bot path: $Path" }
        return $null
    }
}

function Resolve-GrokBotMappingPath([string]$Path, [hashtable]$Context) {
    if ($Path -match '^AppData/(.+)$') { return Join-Path $env:APPDATA $matches[1] }
    if ($Path -match '^LocalAppData/(.+)$') { return Join-Path $env:LOCALAPPDATA $matches[1] }
    if ($Path -match '^\$persist_dir[/\\](.+)$') { return Join-Path $Context.PersistDir $matches[1] }
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    throw "Unsupported Grok Bot mapping path: $Path"
}

function Test-GrokBotOwnedLink($Item, [string]$Source, [string]$Target) {
    if ($null -eq $Item -or $Item.LinkType -ne 'SymbolicLink' -or @($Item.Target).Count -ne 1) { return $false }
    $actualPath = [string]$Item.Target
    if (-not [System.IO.Path]::IsPathRooted($actualPath)) { $actualPath = Join-Path (Split-Path -Parent $Source) $actualPath }
    $actual = [System.IO.Path]::GetFullPath($actualPath).TrimEnd('\', '/')
    $expected = [System.IO.Path]::GetFullPath($Target).TrimEnd('\', '/')
    return $actual.Equals($expected, [System.StringComparison]::OrdinalIgnoreCase)
}

function Assert-GrokBotMapping([hashtable]$Pair) {
    $item = Get-GrokBotPathEntry $Pair.Source
    $target = Get-GrokBotPathEntry $Pair.Target
    if ($null -ne $target -and (-not $target.PSIsContainer -or $target.LinkType)) {
        throw "Grok Bot persist target must be a real directory: $($Pair.Target)"
    }
    if ($null -ne $item -and (-not (Test-GrokBotOwnedLink $item $Pair.Source $Pair.Target) -or $null -eq $target)) {
        throw "Grok Bot path must be preserved: $($Pair.Source). Existing ordinary data or foreign/broken links stop installation. Back up/rename per migration playbook (hash verify); Scoop will not delete them."
    }
}

function Ensure-GrokBotDirectory([string]$Path) {
    $entry = Get-GrokBotPathEntry $Path
    if ($null -eq $entry) { New-Item -ItemType Directory -Path $Path -ErrorAction Stop | Out-Null }
    $entry = Get-GrokBotPathEntry $Path
    if ($null -eq $entry -or -not $entry.PSIsContainer -or $entry.LinkType) { throw "Grok Bot requires a real directory: $Path" }
}

function Invoke-PortableMappings {
    param(
        [ValidateSet('PreInstall', 'Install', 'Uninstall', 'PostUninstall')] [string]$Action,
        [hashtable]$Context,
        [array]$Mappings,
        [switch]$Log
    )
    $ErrorActionPreference = 'Stop'
    Assert-GrokBotNotRunning
    $pairs = @($Mappings | ForEach-Object {
        if ($_.Strategy -ne 'symlink' -or ($_.TargetType -and $_.TargetType -ne 'directory')) {
            throw 'Grok Bot only supports directory symlink mappings.'
        }
        @{
            Source = (Resolve-GrokBotMappingPath $_.Source $Context)
            Target = (Resolve-GrokBotMappingPath $_.Target $Context)
            Label  = $_.Label
        }
    })
    foreach ($pair in $pairs) { Assert-GrokBotMapping $pair }

    if ($Action -in @('PreInstall', 'Install')) {
        foreach ($pair in $pairs) {
            Assert-GrokBotMapping $pair
            Ensure-GrokBotDirectory $pair.Target
            $item = Get-GrokBotPathEntry $pair.Source
            if ($null -eq $item) {
                Ensure-GrokBotDirectory (Split-Path -Parent $pair.Source)
                New-Item -ItemType SymbolicLink -Path $pair.Source -Target $pair.Target -ErrorAction Stop | Out-Null
            }
            Assert-GrokBotMapping $pair
            if (-not (Test-GrokBotOwnedLink (Get-GrokBotPathEntry $pair.Source) $pair.Source $pair.Target)) {
                throw "Grok Bot mapping was not created: $($pair.Source)"
            }
            if ($Log) { Write-Host "[Portable Mode] Linked $($pair.Label) -> $($pair.Target)" }
        }
    }
    else {
        foreach ($pair in $pairs) {
            Assert-GrokBotMapping $pair
            $item = Get-GrokBotPathEntry $pair.Source
            if ($null -ne $item) {
                if (-not (Test-GrokBotOwnedLink $item $pair.Source $pair.Target)) {
                    throw "Grok Bot link is not owned by this manifest: $($pair.Source)"
                }
                Remove-Item -LiteralPath $pair.Source -Force -ErrorAction Stop
                if ($null -ne (Get-GrokBotPathEntry $pair.Source)) { throw "Grok Bot link was not removed: $($pair.Source)" }
                if ($Log) { Write-Host "[Portable Mode] Removed symbolic link: $($pair.Source)" }
            }
        }
    }
}