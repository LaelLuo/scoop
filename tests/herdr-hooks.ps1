param([string]$Root, [string]$Manifest, [ValidateSet('pre_install', 'post_install', 'pre_uninstall')] [string]$Phase, [switch]$DenyListing, [ValidateSet('none','create-link','remove-link')] [string]$Fault = 'none')
$ErrorActionPreference = 'Continue'
$env:APPDATA = Join-Path $Root 'roaming'
$env:LOCALAPPDATA = Join-Path $Root 'local'
$dir = Join-Path $Root 'app'
$persist_dir = Join-Path $Root 'persist'
function info([string]$Message) { Write-Output $Message }
$definition = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
if ($Fault -eq 'create-link') {
    function New-Item {
        [CmdletBinding()] param([string]$ItemType, [string]$Path, [string]$Target)
        if ($ItemType -eq 'SymbolicLink') { Write-Error 'Injected link creation permission failure'; return }
        Microsoft.PowerShell.Management\New-Item @PSBoundParameters
    }
}
if ($Fault -eq 'remove-link') {
    function Remove-Item {
        [CmdletBinding()] param([string]$LiteralPath, [switch]$Force)
        Write-Error 'Injected link removal permission failure'
    }
}
$originalAcl = $null
try {
    if ($DenyListing) {
        $originalAcl = Get-Acl -LiteralPath $env:APPDATA
        $deniedAcl = Get-Acl -LiteralPath $env:APPDATA
        $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($sid, 'ListDirectory', 'Deny')
        [void]$deniedAcl.AddAccessRule($rule)
        Set-Acl -LiteralPath $env:APPDATA -AclObject $deniedAcl
    }
    & ([scriptblock]::Create($definition.$Phase -join "`n"))
} finally {
    if ($null -ne $originalAcl) { Set-Acl -LiteralPath $env:APPDATA -AclObject $originalAcl }
}
