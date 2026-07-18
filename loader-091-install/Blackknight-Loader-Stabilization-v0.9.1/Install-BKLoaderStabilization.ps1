[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$RepositoryRoot
)

$ErrorActionPreference = "Stop"

$repositoryPath = [System.IO.Path]::GetFullPath($RepositoryRoot)
$payloadRoot = Join-Path -Path $PSScriptRoot -ChildPath "payload"

if (-not (Test-Path -LiteralPath $repositoryPath -PathType Container)) {
    throw "Repository root was not found: $repositoryPath"
}

$moduleManifest = Join-Path -Path $repositoryPath -ChildPath "scripts\PowerShell\Platform\Blackknight-Platform.psd1"
if (-not (Test-Path -LiteralPath $moduleManifest -PathType Leaf)) {
    throw "Blackknight platform manifest was not found: $moduleManifest"
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$backupRoot = Join-Path -Path $repositoryPath -ChildPath ".blackknight-backups\loader-$timestamp"
$payloadFiles = @(Get-ChildItem -LiteralPath $payloadRoot -File -Recurse)

foreach ($sourceFile in $payloadFiles) {
    $relativePath = [System.IO.Path]::GetRelativePath($payloadRoot, $sourceFile.FullName)
    $destinationPath = Join-Path -Path $repositoryPath -ChildPath $relativePath
    $destinationParent = Split-Path -Path $destinationPath -Parent

    if (Test-Path -LiteralPath $destinationPath -PathType Leaf) {
        $backupPath = Join-Path -Path $backupRoot -ChildPath $relativePath
        $backupParent = Split-Path -Path $backupPath -Parent
        New-Item -Path $backupParent -ItemType Directory -Force | Out-Null
        Copy-Item -LiteralPath $destinationPath -Destination $backupPath -Force
    }

    if ($PSCmdlet.ShouldProcess($destinationPath, "Install loader stabilization file")) {
        New-Item -Path $destinationParent -ItemType Directory -Force | Out-Null
        Copy-Item -LiteralPath $sourceFile.FullName -Destination $destinationPath -Force
    }
}

$parseFailures = [System.Collections.Generic.List[object]]::new()
$powerShellRoot = Join-Path -Path $repositoryPath -ChildPath "scripts\PowerShell"

foreach ($file in @(Get-ChildItem -LiteralPath $powerShellRoot -Filter "*.ps1" -File -Recurse)) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName,
        [ref]$tokens,
        [ref]$errors
    )

    if ($errors.Count -gt 0) {
        $parseFailures.Add(
            [PSCustomObject]@{
                File   = $file.FullName
                Errors = @($errors | ForEach-Object { $_.Message }) -join "; "
            }
        )
    }
}

if ($parseFailures.Count -gt 0) {
    $parseFailures | Format-Table -AutoSize | Out-Host
    throw "$($parseFailures.Count) PowerShell file(s) failed syntax validation. Backups are available at $backupRoot"
}

Write-Host ""
Write-Host "Blackknight loader stabilization installed successfully."
Write-Host "Backup: $backupRoot"
Write-Host ""
Write-Host "Reload with:"
Write-Host "  Remove-Module Blackknight-Platform -ErrorAction SilentlyContinue"
Write-Host "  Import-Module '$moduleManifest' -Force"
