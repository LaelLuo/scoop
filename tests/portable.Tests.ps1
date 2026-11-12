BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\scripts\portable.psm1'
    Import-Module $modulePath -Force
    function global:info { param([string]$Message) }
}

AfterAll {
    Remove-Module portable -ErrorAction SilentlyContinue
    Remove-Item Function:\info -ErrorAction SilentlyContinue
}

Describe 'portable.psm1 symlink mappings' {
    BeforeAll {
        function New-Fixture([string]$Root) {
            $fixture = @{
                Root = $Root
                AppData = Join-Path $Root 'roaming-root'
                Persist = Join-Path $Root 'persist\app'
            }
            New-Item -ItemType Directory -Path $fixture.AppData, (Join-Path $Root 'app') -Force | Out-Null
            $fixture.Context = @{ Dir = (Join-Path $Root 'app'); PersistDir = $fixture.Persist }
            $fixture
        }

        function Get-LinkState([string]$Path) {
            $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
            if (-not $item) { return 'missing' }
            if (-not $item.LinkType) { return 'plain' }
            return "$($item.LinkType)->$(@($item.Target)[0])"
        }

        $script:dirMapping = @{ Label = 'roaming'; Source = 'AppData/MyApp'; Target = '$persist_dir/roaming'; Strategy = 'symlink'; EnsureTarget = $true; TargetType = 'directory' }
        $script:fileMapping = @{ Label = 'blocker'; Source = 'AppData/myapp-updater'; Target = '$persist_dir/local/myapp-updater'; Strategy = 'symlink'; EnsureTarget = $true; TargetType = 'file' }
    }

    BeforeEach {
        $script:savedAppData = $env:APPDATA
        $script:fx = New-Fixture (Join-Path $TestDrive ([guid]::NewGuid().ToString('N')))
        $env:APPDATA = $fx.AppData
        $script:dirLink = Join-Path $fx.AppData 'MyApp'
        $script:dirTarget = Join-Path $fx.Persist 'roaming'
        $script:fileLink = Join-Path $fx.AppData 'myapp-updater'
        $script:fileTarget = Join-Path $fx.Persist 'local\myapp-updater'
    }

    AfterEach {
        $env:APPDATA = $savedAppData
    }

    It 'reports the capability in the current session' {
        Test-PortableSymlinkCapability | Should -BeTrue
    }

    It 'migrates a real directory into persist and links it as SymbolicLink' {
        New-Item -ItemType Directory -Path $dirLink -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $dirLink 'settings.json') -Value 'keep' -NoNewline

        Invoke-PortableMappings -Action Install -Context $fx.Context -Mappings @($dirMapping)

        (Get-Item -LiteralPath $dirLink -Force).LinkType | Should -Be 'SymbolicLink'
        Test-PortableSymlinkTarget $dirLink $dirTarget | Should -BeTrue
        Get-Content -LiteralPath (Join-Path $dirLink 'settings.json') -Raw | Should -Be 'keep'
        Get-Content -LiteralPath (Join-Path $dirTarget 'settings.json') -Raw | Should -Be 'keep'
    }

    It 'links a file mapping as a file SymbolicLink' {
        Invoke-PortableMappings -Action Install -Context $fx.Context -Mappings @($fileMapping)

        $item = Get-Item -LiteralPath $fileLink -Force
        $item.LinkType | Should -Be 'SymbolicLink'
        $item.PSIsContainer | Should -BeFalse
        Test-PortableSymlinkTarget $fileLink $fileTarget | Should -BeTrue
    }

    It 'keeps an already correct SymbolicLink without recreating it' {
        Invoke-PortableMappings -Action Install -Context $fx.Context -Mappings @($dirMapping)
        Mock New-PortableNativeSymlink -ModuleName portable -ParameterFilter { $Link -eq $dirLink } { throw 'must not recreate' }

        { Invoke-PortableMappings -Action Install -Context $fx.Context -Mappings @($dirMapping) } | Should -Not -Throw

        Should -Invoke New-PortableNativeSymlink -ModuleName portable -ParameterFilter { $Link -eq $dirLink } -Times 0 -Exactly
        Test-PortableSymlinkTarget $dirLink $dirTarget | Should -BeTrue
    }

    It 'replaces a Junction with a SymbolicLink without touching the junction target' {
        $foreign = Join-Path $fx.Root 'foreign'
        New-Item -ItemType Directory -Path $foreign -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $foreign 'keep.txt') -Value 'foreign' -NoNewline
        New-Item -ItemType Junction -Path $dirLink -Target $foreign | Out-Null

        Invoke-PortableMappings -Action Install -Context $fx.Context -Mappings @($dirMapping)

        Test-PortableSymlinkTarget $dirLink $dirTarget | Should -BeTrue
        Get-Content -LiteralPath (Join-Path $foreign 'keep.txt') -Raw | Should -Be 'foreign'
    }

    It 'uninstall removes only the link and keeps persist data' {
        Invoke-PortableMappings -Action Install -Context $fx.Context -Mappings @($dirMapping, $fileMapping)
        Set-Content -LiteralPath (Join-Path $dirTarget 'data.txt') -Value 'persist' -NoNewline

        Invoke-PortableMappings -Action Uninstall -Context $fx.Context -Mappings @($dirMapping, $fileMapping)

        Get-LinkState $dirLink | Should -Be 'missing'
        Get-LinkState $fileLink | Should -Be 'missing'
        Get-Content -LiteralPath (Join-Path $dirTarget 'data.txt') -Raw | Should -Be 'persist'
        Test-Path -LiteralPath $fileTarget | Should -BeTrue
    }

    It 'aborts uninstall before unlinking when the capability check fails' {
        Invoke-PortableMappings -Action Install -Context $fx.Context -Mappings @($dirMapping, $fileMapping)
        $before = @((Get-LinkState $dirLink), (Get-LinkState $fileLink))
        Mock Test-PortableSymlinkCapability -ModuleName portable { $false }

        { Invoke-PortableMappings -Action Uninstall -Context $fx.Context -Mappings @($dirMapping, $fileMapping) } | Should -Throw '*cannot create SymbolicLinks*'

        @((Get-LinkState $dirLink), (Get-LinkState $fileLink)) | Should -Be $before
        Test-PortableSymlinkTarget $dirLink $dirTarget | Should -BeTrue
    }

    It 'aborts install before touching sources when the capability check fails' {
        New-Item -ItemType Directory -Path $dirLink -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $dirLink 'settings.json') -Value 'keep' -NoNewline
        Mock Test-PortableSymlinkCapability -ModuleName portable { $false }
        Mock info -ModuleName portable {}

        { Invoke-PortableMappings -Action Install -Context $fx.Context -Mappings @($dirMapping) -Log } | Should -Throw '*cannot create SymbolicLinks*'

        Get-LinkState $dirLink | Should -Be 'plain'
        Get-Content -LiteralPath (Join-Path $dirLink 'settings.json') -Raw | Should -Be 'keep'
        Should -Invoke info -ModuleName portable -Times 0 -Exactly
    }

    It 'throws and never logs Linked when the link cannot be created' {
        Mock New-PortableNativeSymlink -ModuleName portable -ParameterFilter { $Link -eq $dirLink } {}
        Mock New-Item -ModuleName portable -ParameterFilter { $ItemType -eq 'SymbolicLink' } {}
        Mock info -ModuleName portable {}

        { Invoke-PortableMappings -Action Install -Context $fx.Context -Mappings @($dirMapping) -Log } | Should -Throw '*Failed to create SymbolicLink*'

        Get-LinkState $dirLink | Should -Be 'missing'
        Should -Invoke info -ModuleName portable -ParameterFilter { $Message -like '*Linked*' } -Times 0 -Exactly
    }

    It 'refuses to replace a non-link item at the link path' {
        Mock Copy-PortableData -ModuleName portable {}
        Mock Remove-Item -ModuleName portable -ParameterFilter { @($Path) -contains $dirLink } {}
        New-Item -ItemType Directory -Path $dirLink -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $dirLink 'settings.json') -Value 'keep' -NoNewline

        { Invoke-PortableMappings -Action Install -Context $fx.Context -Mappings @($dirMapping) } | Should -Throw '*not a link*'

        Get-Content -LiteralPath (Join-Path $dirLink 'settings.json') -Raw | Should -Be 'keep'
    }

    It 'links across volumes when SCOOP_PORTABLE_TEST_CROSS_ROOT is set' -Skip:(-not $env:SCOOP_PORTABLE_TEST_CROSS_ROOT) {
        $crossRoot = Join-Path $env:SCOOP_PORTABLE_TEST_CROSS_ROOT ([guid]::NewGuid().ToString('N'))
        try {
            $context = @{ Dir = $fx.Context.Dir; PersistDir = (Join-Path $crossRoot 'persist\app') }
            $target = Join-Path $context.PersistDir 'roaming'
            ([System.IO.Path]::GetPathRoot($target)) | Should -Not -Be ([System.IO.Path]::GetPathRoot($dirLink))

            Invoke-PortableMappings -Action Install -Context $context -Mappings @($dirMapping)
            Set-Content -LiteralPath (Join-Path $dirLink 'via-link.txt') -Value 'cross' -NoNewline

            Test-PortableSymlinkTarget $dirLink $target | Should -BeTrue
            Get-Content -LiteralPath (Join-Path $target 'via-link.txt') -Raw | Should -Be 'cross'

            Invoke-PortableMappings -Action Uninstall -Context $context -Mappings @($dirMapping)
            Get-LinkState $dirLink | Should -Be 'missing'
            Test-Path -LiteralPath (Join-Path $target 'via-link.txt') | Should -BeTrue
        }
        finally {
            $item = Get-Item -LiteralPath $dirLink -Force -ErrorAction SilentlyContinue
            if ($item -and $item.LinkType) { [System.IO.Directory]::Delete($dirLink) }
            Remove-Item -LiteralPath $crossRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
