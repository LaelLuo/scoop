BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\scripts\t3-code-portable.psm1'
    Import-Module $modulePath -Function Invoke-PortableMappings -Force
    $savedEnvironment = @{
        USERPROFILE = $env:USERPROFILE
        APPDATA = $env:APPDATA
        LOCALAPPDATA = $env:LOCALAPPDATA
    }
}

AfterAll {
    foreach ($name in $savedEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process')
    }
    Remove-Module t3-code-portable -ErrorAction SilentlyContinue
}

Describe 'T3 Code portable mappings' {
    BeforeAll {
        function New-TestMappings {
            param([string[]]$Paths = @('UserProfile/.t3', 'AppData/t3code-v2'))
            $index = 0
            foreach ($path in $Paths) {
                $target = if ($index -eq 0) { '$persist_dir/home' } else { '$persist_dir/profile-' + $index }
                @{ Label = "mapping-$index"; Source = $path; Target = $target; Strategy = 'junction'; TargetType = 'directory' }
                $index++
            }
        }

        function Get-TestPath([string]$Source) {
            if ($Source -like 'UserProfile/*') { return Join-Path $userProfile $Source.Substring('UserProfile/'.Length) }
            if ($Source -like 'AppData/*') { return Join-Path $appData $Source.Substring('AppData/'.Length) }
            if ($Source -like 'LocalAppData/*') { return Join-Path $localAppData $Source.Substring('LocalAppData/'.Length) }
            throw "Unknown test path: $Source"
        }

        function Get-TestTarget([string]$Target) {
            return Join-Path $persistDir $Target.Substring('$persist_dir/'.Length)
        }
    }

    BeforeEach {
        $script:root = Join-Path $TestDrive ([guid]::NewGuid().ToString('N'))
        $script:userProfile = Join-Path $root 'profile'
        $script:appData = Join-Path $root 'roaming'
        $script:localAppData = Join-Path $root 'local'
        $script:persistDir = Join-Path $root 'scoop-persist\t3-code'
        New-Item -ItemType Directory -Path $userProfile, $appData, $localAppData, (Join-Path $root 'scoop-app') -Force | Out-Null
        $env:USERPROFILE = $userProfile
        $env:APPDATA = $appData
        $env:LOCALAPPDATA = $localAppData
        $script:context = @{ Dir = (Join-Path $root 'scoop-app'); PersistDir = $persistDir }
        Mock Get-Process { @() } -ModuleName t3-code-portable
    }

    It 'allows persist data to evolve through lifecycle and reinstall while retaining the original backup' {
        $mappings = @(New-TestMappings)
        $homeSource = Get-TestPath $mappings[0].Source
        $profile = Get-TestPath $mappings[1].Source
        New-Item -ItemType Directory -Path (Join-Path $homeSource 'userdata\empty'), $profile -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $homeSource 'userdata\thread.json') -Value '{"id":"synthetic"}' -NoNewline
        Set-Content -LiteralPath (Join-Path $profile 'Local State') -Value 'synthetic-state' -NoNewline

        Invoke-PortableMappings -Action PreInstall -Context $context -Mappings $mappings
        Invoke-PortableMappings -Action PreInstall -Context $context -Mappings $mappings
        Invoke-PortableMappings -Action Install -Context $context -Mappings $mappings
        $homeTarget = Get-TestTarget $mappings[0].Target
        Set-Content -LiteralPath (Join-Path $homeTarget 'userdata\new-session.json') -Value '{"id":"created-after-migration"}' -NoNewline
        Invoke-PortableMappings -Action PreInstall -Context $context -Mappings $mappings
        Invoke-PortableMappings -Action Install -Context $context -Mappings $mappings
        Invoke-PortableMappings -Action Uninstall -Context $context -Mappings $mappings

        foreach ($mapping in $mappings) {
            $source = Get-TestPath $mapping.Source
            $target = Get-TestTarget $mapping.Target
            $entry = Get-Item -Force -LiteralPath $source
            $entry.LinkType | Should -Be 'Junction'
            (Get-Item -Force -LiteralPath $entry.Target).FullName | Should -Be $target
            (Test-Path -LiteralPath "${source}.scoop-t3-code-backup") | Should -BeTrue
        }

        Invoke-PortableMappings -Action Uninstall -Context $context -Mappings $mappings
        Invoke-PortableMappings -Action PostUninstall -Context $context -Mappings $mappings

        foreach ($mapping in $mappings) {
            (Test-Path -LiteralPath (Get-TestPath $mapping.Source)) | Should -BeFalse
            (Test-Path -LiteralPath (Get-TestTarget $mapping.Target)) | Should -BeTrue
            (Test-Path -LiteralPath "$((Get-TestPath $mapping.Source)).scoop-t3-code-backup") | Should -BeTrue
        }
        (Test-Path -LiteralPath (Join-Path $homeTarget 'userdata\new-session.json')) | Should -BeTrue
        (Test-Path -LiteralPath (Join-Path "$homeSource.scoop-t3-code-backup" 'userdata\new-session.json')) | Should -BeFalse

        Invoke-PortableMappings -Action PreInstall -Context $context -Mappings $mappings
        Invoke-PortableMappings -Action Install -Context $context -Mappings $mappings
        (Get-Item -Force -LiteralPath (Get-TestPath $mappings[0].Source)).LinkType | Should -Be 'Junction'
        (Test-Path -LiteralPath (Join-Path $homeTarget 'userdata\new-session.json')) | Should -BeTrue
    }

    It 'keeps completed mappings valid after a later path fails and resumes on retry' {
        $mappings = @(New-TestMappings)
        $first = Get-TestPath $mappings[0].Source
        $later = Get-TestPath $mappings[1].Source
        New-Item -ItemType Directory -Path $first -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $first 'data.json') -Value 'preserved' -NoNewline
        Set-Content -LiteralPath $later -Value 'conflict' -NoNewline

        { Invoke-PortableMappings -Action PreInstall -Context $context -Mappings $mappings } | Should -Throw '*must be a real directory*'
        (Get-Item -Force -LiteralPath $first).LinkType | Should -Be 'Junction'
        (Test-Path -LiteralPath "$first.scoop-t3-code-backup\data.json") | Should -BeTrue
        (Test-Path -LiteralPath (Join-Path (Get-TestTarget $mappings[0].Target) 'data.json')) | Should -BeTrue

        Remove-Item -LiteralPath $later -Force
        New-Item -ItemType Directory -Path $later -Force | Out-Null
        Invoke-PortableMappings -Action PreInstall -Context $context -Mappings $mappings
        Invoke-PortableMappings -Action Install -Context $context -Mappings $mappings
        (Get-Item -Force -LiteralPath $first).LinkType | Should -Be 'Junction'
        (Get-Item -Force -LiteralPath $later).LinkType | Should -Be 'Junction'
    }

    It 'accepts absolute target paths after manifest variable expansion' {
        $mapping = @{ Label = 'absolute'; Source = 'UserProfile/.t3'; Target = (Join-Path $persistDir 'absolute-home'); Strategy = 'junction'; TargetType = 'directory' }
        $source = Get-TestPath $mapping.Source

        Invoke-PortableMappings -Action PreInstall -Context $context -Mappings @($mapping)
        Invoke-PortableMappings -Action Install -Context $context -Mappings @($mapping)

        (Get-Item -Force -LiteralPath $source).LinkType | Should -Be 'Junction'
        [IO.Path]::GetFullPath((Get-Item -Force -LiteralPath $source).Target) | Should -Be ([IO.Path]::GetFullPath($mapping.Target))
    }

    It 'fails closed on conflicting persist data without changing either tree' {
        $mappings = @(New-TestMappings -Paths @('UserProfile/.t3'))
        $source = Get-TestPath $mappings[0].Source
        $target = Get-TestTarget $mappings[0].Target
        New-Item -ItemType Directory -Path $source, $target -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $source 'source.txt') -Value 'source' -NoNewline
        Set-Content -LiteralPath (Join-Path $target 'target.txt') -Value 'target' -NoNewline

        { Invoke-PortableMappings -Action PreInstall -Context $context -Mappings $mappings } | Should -Throw '*verification failed*'
        (Test-Path -LiteralPath (Join-Path $source 'source.txt')) | Should -BeTrue
        (Test-Path -LiteralPath (Join-Path $target 'target.txt')) | Should -BeTrue
        (Test-Path -LiteralPath "${source}.scoop-t3-code-backup") | Should -BeFalse
    }

    It 'preserves the source when hash verification fails' {
        $mappings = @(New-TestMappings -Paths @('UserProfile/.t3'))
        $source = Get-TestPath $mappings[0].Source
        New-Item -ItemType Directory -Path $source -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $source 'data.txt') -Value 'source' -NoNewline
        $script:hashCalls = 0
        Mock Get-FileHash {
            $script:hashCalls++
            if ($script:hashCalls -eq 3) { throw 'synthetic hash failure' }
            Microsoft.PowerShell.Utility\Get-FileHash -LiteralPath $LiteralPath -Algorithm $Algorithm
        } -ModuleName t3-code-portable

        { Invoke-PortableMappings -Action PreInstall -Context $context -Mappings $mappings } | Should -Throw '*synthetic hash failure*'
        (Test-Path -LiteralPath (Join-Path $source 'data.txt')) | Should -BeTrue
        (Test-Path -LiteralPath "${source}.scoop-t3-code-backup") | Should -BeFalse
        (Test-Path -LiteralPath "$((Get-TestTarget $mappings[0].Target)).scoop-t3-code-stage") | Should -BeTrue

        Invoke-PortableMappings -Action PreInstall -Context $context -Mappings $mappings
        (Get-Item -Force -LiteralPath $source).LinkType | Should -Be 'Junction'
        (Test-Path -LiteralPath (Join-Path (Get-TestTarget $mappings[0].Target) 'data.txt')) | Should -BeTrue
    }

    It 'checks processes before making the first change' {
        $mappings = @(New-TestMappings -Paths @('UserProfile/.t3'))
        $source = Get-TestPath $mappings[0].Source
        Mock Get-Process { @([pscustomobject]@{ ProcessName = 'T3 Code (Beta)' }) } -ModuleName t3-code-portable

        { Invoke-PortableMappings -Action PreInstall -Context $context -Mappings $mappings } | Should -Throw '*Close all T3 Code processes*'
        (Test-Path -LiteralPath $source) | Should -BeFalse
        (Test-Path -LiteralPath $persistDir) | Should -BeFalse
    }

    It 'blocks the resource monitor as a T3 Code process' {
        $mappings = @(New-TestMappings -Paths @('UserProfile/.t3'))
        Mock Get-Process { @([pscustomobject]@{ ProcessName = 't3-resource-monitor' }) } -ModuleName t3-code-portable

        { Invoke-PortableMappings -Action PreInstall -Context $context -Mappings $mappings } | Should -Throw '*Close all T3 Code processes*'
        (Test-Path -LiteralPath (Get-TestPath $mappings[0].Source)) | Should -BeFalse
    }

    It 'rejects foreign junctions without removing them' {
        $mappings = @(New-TestMappings -Paths @('UserProfile/.t3'))
        $source = Get-TestPath $mappings[0].Source
        $foreign = Join-Path $root 'foreign'
        New-Item -ItemType Directory -Path $foreign -Force | Out-Null
        New-Item -ItemType Junction -Path $source -Target $foreign | Out-Null

        { Invoke-PortableMappings -Action PreInstall -Context $context -Mappings $mappings } | Should -Throw '*external, damaged, or unexpected reparse point*'
        (Get-Item -Force -LiteralPath $source).Target | Should -Be $foreign
    }

    It 'rejects a broken junction without recreating its target' {
        $mappings = @(New-TestMappings -Paths @('UserProfile/.t3'))
        $source = Get-TestPath $mappings[0].Source
        $target = Get-TestTarget $mappings[0].Target
        $movedTarget = Join-Path $root 'moved-target'
        New-Item -ItemType Directory -Path $target -Force | Out-Null
        New-Item -ItemType Junction -Path $source -Target $target | Out-Null
        Move-Item -LiteralPath $target -Destination $movedTarget

        { Invoke-PortableMappings -Action PreInstall -Context $context -Mappings $mappings } | Should -Throw
        (Test-Path -LiteralPath $movedTarget) | Should -BeTrue
        (Test-Path -LiteralPath $target) | Should -BeFalse
    }

    It 'rejects nested reparse points without copying them' {
        $mappings = @(New-TestMappings -Paths @('UserProfile/.t3'))
        $source = Get-TestPath $mappings[0].Source
        $foreign = Join-Path $root 'foreign-child'
        New-Item -ItemType Directory -Path (Join-Path $source 'userdata'), $foreign -Force | Out-Null
        New-Item -ItemType Junction -Path (Join-Path $source 'userdata/external') -Target $foreign | Out-Null

        { Invoke-PortableMappings -Action PreInstall -Context $context -Mappings $mappings } | Should -Throw '*Reparse point inside T3 Code data*'
        (Test-Path -LiteralPath (Join-Path $source 'userdata/external')) | Should -BeTrue
        (Test-Path -LiteralPath (Get-TestTarget $mappings[0].Target)) | Should -BeFalse
    }
}
