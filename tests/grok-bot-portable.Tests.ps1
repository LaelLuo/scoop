BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\scripts\grok-bot-portable.psm1'
    Import-Module $modulePath -Function Invoke-PortableMappings -Force
    $savedEnvironment = @{
        APPDATA = $env:APPDATA
        LOCALAPPDATA = $env:LOCALAPPDATA
        GROK_BOT_PORTABLE_PROCESS_NAME = $env:GROK_BOT_PORTABLE_PROCESS_NAME
        GROK_BOT_PORTABLE_SKIP_PROCESS_CHECK = $env:GROK_BOT_PORTABLE_SKIP_PROCESS_CHECK
    }
}

AfterAll {
    foreach ($name in $savedEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process')
    }
    Remove-Module grok-bot-portable -ErrorAction SilentlyContinue
}

Describe 'Grok Bot portable mappings' {
    BeforeAll {
        function New-GrokMappings {
            @(
                @{ Label = 'roaming'; Source = 'AppData/Grok Bot'; Target = '$persist_dir/roaming'; Strategy = 'symlink'; TargetType = 'directory' }
                @{ Label = 'programs'; Source = 'LocalAppData/Programs/Grok Bot'; Target = '$persist_dir/programs'; Strategy = 'symlink'; TargetType = 'directory' }
            )
        }

        function New-NsisProgramsTree([string]$Path) {
            New-Item -ItemType Directory -Path (Join-Path $Path 'resources'), (Join-Path $Path 'locales') -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $Path 'Grok Bot.exe') -Value 'fake-exe' -NoNewline
            Set-Content -LiteralPath (Join-Path $Path 'Uninstall Grok Bot.exe') -Value 'fake-uninst' -NoNewline
            Set-Content -LiteralPath (Join-Path $Path 'resources\app.asar') -Value 'asar' -NoNewline
        }
    }

    BeforeEach {
        $script:root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:appData = Join-Path $root 'roaming-root'
        $script:localAppData = Join-Path $root 'local-root'
        $script:persistDir = Join-Path $root 'scoop-persist\grok-bot'
        New-Item -ItemType Directory -Path $appData, (Join-Path $localAppData 'Programs'), (Join-Path $root 'scoop-app') -Force | Out-Null
        $env:APPDATA = $appData
        $env:LOCALAPPDATA = $localAppData
        Remove-Item Env:GROK_BOT_PORTABLE_PROCESS_NAME -ErrorAction SilentlyContinue
        $env:GROK_BOT_PORTABLE_SKIP_PROCESS_CHECK = '1'
        $script:context = @{ Dir = (Join-Path $root 'scoop-app'); PersistDir = $persistDir }
        $script:mappings = @(New-GrokMappings)
        $script:roamingSource = Join-Path $appData 'Grok Bot'
        $script:programsSource = Join-Path $localAppData 'Programs\Grok Bot'
        $script:roamingTarget = Join-Path $persistDir 'roaming'
        $script:programsTarget = Join-Path $persistDir 'programs'
    }

    It 'migrates roaming with matching hash tree and backup, deletes NSIS programs, then links' {
        New-Item -ItemType Directory -Path (Join-Path $roamingSource 'Partitions\x') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $roamingSource 'Preferences') -Value '{"ok":true}' -NoNewline
        Set-Content -LiteralPath (Join-Path $roamingSource 'Partitions\x\keep.txt') -Value 'keep-me' -NoNewline
        New-NsisProgramsTree $programsSource

        Invoke-PortableMappings -Action PreInstall -Context $context -Mappings $mappings

        $roamLink = Get-Item -LiteralPath $roamingSource -Force
        $roamLink.LinkType | Should -Be 'SymbolicLink'
        [IO.Path]::GetFullPath([string]$roamLink.Target) | Should -Be ([IO.Path]::GetFullPath($roamingTarget))
        (Test-Path -LiteralPath (Join-Path $roamingTarget 'Preferences')) | Should -BeTrue
        (Get-Content -LiteralPath (Join-Path $roamingTarget 'Partitions\x\keep.txt') -Raw) | Should -Be 'keep-me'
        $backup = Get-Item -LiteralPath "${roamingSource}.scoop-grok-bot-backup" -Force
        $backup.PSIsContainer | Should -BeTrue
        (Test-Path -LiteralPath (Join-Path $backup.FullName 'Preferences')) | Should -BeTrue

        $progLink = Get-Item -LiteralPath $programsSource -Force
        $progLink.LinkType | Should -Be 'SymbolicLink'
        [IO.Path]::GetFullPath([string]$progLink.Target) | Should -Be ([IO.Path]::GetFullPath($programsTarget))
        (Test-Path -LiteralPath (Join-Path $programsTarget 'Grok Bot.exe')) | Should -BeFalse
        (@(Get-ChildItem -LiteralPath $programsTarget -Force).Count) | Should -Be 0
    }

    It 'is idempotent when owned links already exist' {
        New-Item -ItemType Directory -Path $roamingSource -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $roamingSource 'a.txt') -Value '1' -NoNewline
        New-NsisProgramsTree $programsSource
        Invoke-PortableMappings -Action PreInstall -Context $context -Mappings $mappings
        Invoke-PortableMappings -Action PreInstall -Context $context -Mappings $mappings
        Invoke-PortableMappings -Action Install -Context $context -Mappings $mappings
        (Get-Item -LiteralPath $roamingSource -Force).LinkType | Should -Be 'SymbolicLink'
        (Get-Item -LiteralPath $programsSource -Force).LinkType | Should -Be 'SymbolicLink'
        (Test-Path -LiteralPath (Join-Path $roamingTarget 'a.txt')) | Should -BeTrue
    }

    It 'refuses while a mocked Grok Bot process is running' {
        Remove-Item Env:GROK_BOT_PORTABLE_SKIP_PROCESS_CHECK -ErrorAction SilentlyContinue
        $env:GROK_BOT_PORTABLE_PROCESS_NAME = 'GrokBotFakeProc'
        Mock Get-Process {
            param($Name)
            if ($Name -eq 'GrokBotFakeProc') {
                return [pscustomobject]@{ ProcessName = 'GrokBotFakeProc'; Id = 1 }
            }
            return @()
        } -ModuleName grok-bot-portable
        { Invoke-PortableMappings -Action PreInstall -Context $context -Mappings $mappings } | Should -Throw '*Grok Bot is running*'
    }

    It 'refuses when persist roaming already has different data' {
        New-Item -ItemType Directory -Path $roamingSource, $roamingTarget -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $roamingSource 'a.txt') -Value 'source' -NoNewline
        Set-Content -LiteralPath (Join-Path $roamingTarget 'a.txt') -Value 'persist-other' -NoNewline
        New-NsisProgramsTree $programsSource
        { Invoke-PortableMappings -Action PreInstall -Context $context -Mappings $mappings } | Should -Throw '*refusing to merge*'
        (Test-Path -LiteralPath $roamingSource) | Should -BeTrue
        (Get-Item -LiteralPath $roamingSource -Force).LinkType | Should -BeNullOrEmpty
        (Get-Content -LiteralPath (Join-Path $roamingSource 'a.txt') -Raw) | Should -Be 'source'
    }

    It 'preserves source when copy verification would fail because stage was pre-poisoned differently' {
        # Simulate a leftover stage that does not match source: install must throw and keep source
        New-Item -ItemType Directory -Path $roamingSource, "${roamingTarget}.scoop-grok-bot-stage" -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $roamingSource 'a.txt') -Value 'source-only' -NoNewline
        Set-Content -LiteralPath (Join-Path "${roamingTarget}.scoop-grok-bot-stage" 'a.txt') -Value 'stage-other' -NoNewline
        New-NsisProgramsTree $programsSource
        { Invoke-PortableMappings -Action PreInstall -Context $context -Mappings $mappings } | Should -Throw '*staging data does not match source*'
        (Get-Content -LiteralPath (Join-Path $roamingSource 'a.txt') -Raw) | Should -Be 'source-only'
        (Get-Item -LiteralPath $roamingSource -Force).LinkType | Should -BeNullOrEmpty
    }

    It 'refuses to delete Programs when tree lacks NSIS markers' {
        New-Item -ItemType Directory -Path $programsSource -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $programsSource 'readme.txt') -Value 'not-nsis' -NoNewline
        New-Item -ItemType Directory -Path $roamingSource -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $roamingSource 'a.txt') -Value 'x' -NoNewline
        { Invoke-PortableMappings -Action PreInstall -Context $context -Mappings $mappings } | Should -Throw '*does not look like an NSIS*'
        (Test-Path -LiteralPath (Join-Path $programsSource 'readme.txt')) | Should -BeTrue
    }

    It 'uninstall removes owned links only and keeps persist and roaming backup' {
        New-Item -ItemType Directory -Path $roamingSource -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $roamingSource 'a.txt') -Value 'data' -NoNewline
        New-NsisProgramsTree $programsSource
        Invoke-PortableMappings -Action PreInstall -Context $context -Mappings $mappings
        Invoke-PortableMappings -Action PostUninstall -Context $context -Mappings $mappings
        (Test-Path -LiteralPath $roamingSource) | Should -BeFalse
        (Test-Path -LiteralPath $programsSource) | Should -BeFalse
        (Test-Path -LiteralPath (Join-Path $roamingTarget 'a.txt')) | Should -BeTrue
        (Test-Path -LiteralPath "${roamingSource}.scoop-grok-bot-backup") | Should -BeTrue
        (Test-Path -LiteralPath $programsTarget) | Should -BeTrue
    }
}