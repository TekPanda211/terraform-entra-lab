function Test-BKPlatform {
    [CmdletBinding()]
    param()

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Blackknight Platform Validation" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    $results = @()
    $repoRoot = (Get-Location).Path

    function New-BKValidationResult {
        param(
            [Parameter(Mandatory)]
            [string]$Check,

            [Parameter(Mandatory)]
            [bool]$Passed,

            [string]$Details = ""
        )

        [PSCustomObject]@{
            Check   = $Check
            Status  = if ($Passed) { "PASS" } else { "FAIL" }
            Details = $Details
        }
    }

    $platformModule = Join-Path $repoRoot "scripts\PowerShell\Platform\Blackknight-Platform.psm1"
    $coreEngine     = Join-Path $repoRoot "scripts\PowerShell\Core\Invoke-BlackKnight.ps1"
    $configFolder   = Join-Path $repoRoot "config"
    $reportsFolder  = Join-Path $repoRoot "reports"

    $results += New-BKValidationResult -Check "Platform Module" -Passed (Test-Path $platformModule) -Details $platformModule
    $results += New-BKValidationResult -Check "Core Engine" -Passed (Test-Path $coreEngine) -Details $coreEngine
    $results += New-BKValidationResult -Check "Config Folder" -Passed (Test-Path $configFolder) -Details $configFolder
    $results += New-BKValidationResult -Check "Reports Folder" -Passed (Test-Path $reportsFolder) -Details $reportsFolder

    $serviceManifestPath = Join-Path $repoRoot "scripts\PowerShell\Platform\Services\services.json"

    $results += New-BKValidationResult -Check "Service Manifest" -Passed (Test-Path $serviceManifestPath) -Details $serviceManifestPath

    if (Test-Path $serviceManifestPath) {
        try {
            $serviceManifest = Get-Content $serviceManifestPath -Raw | ConvertFrom-Json

            foreach ($service in $serviceManifest.Services) {
                $command = Get-Command $service.Name -ErrorAction SilentlyContinue

                $results += New-BKValidationResult `
                    -Check "Service: $($service.Name)" `
                    -Passed ($null -ne $command) `
                    -Details "$($service.Category) | $($service.Status)"
            }
        }
        catch {
            $results += New-BKValidationResult `
                -Check "Service Manifest Parse" `
                -Passed $false `
                -Details $_.Exception.Message
        }
    }

    $engineRoot = Join-Path $repoRoot "scripts\PowerShell"

    try {
        $engines = Get-BKEngineManifest

        $results += New-BKValidationResult `
            -Check "Engine Registry" `
            -Passed ($engines.Count -gt 0) `
            -Details "$($engines.Count) engine(s) registered"

        foreach ($engine in $engines) {
            $results += New-BKValidationResult `
                -Check "Engine: $($engine.DisplayName)" `
                -Passed (Test-Path $engine.EntryPoint) `
                -Details $engine.EntryPoint
        }
    }
    catch {
        $results += New-BKValidationResult `
            -Check "Engine Registry" `
            -Passed $false `
            -Details $_.Exception.Message
    }

    $psFiles = Get-ChildItem -Path $engineRoot -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue

    foreach ($file in $psFiles) {
        $parseErrors = $null
        [System.Management.Automation.PSParser]::Tokenize(
            (Get-Content $file.FullName -Raw),
            [ref]$parseErrors
        ) | Out-Null

        $results += New-BKValidationResult `
            -Check "Syntax: $($file.Name)" `
            -Passed ($parseErrors.Count -eq 0) `
            -Details $file.FullName
    }

    $results | Format-Table -AutoSize

    $failed = $results | Where-Object { $_.Status -eq "FAIL" }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan

    if ($failed.Count -eq 0) {
        Write-Host "Blackknight Platform Ready" -ForegroundColor Green
        Write-Host "Validation Confidence: 100%"
    }
    else {
        Write-Host "Blackknight Platform Validation Failed" -ForegroundColor Red
        Write-Host "Failures: $($failed.Count)"
    }

    Write-Host "========================================" -ForegroundColor Cyan

    return $results
}