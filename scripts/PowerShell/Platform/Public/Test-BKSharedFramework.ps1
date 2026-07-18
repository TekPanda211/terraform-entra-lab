function Test-BKSharedFramework {
    [CmdletBinding()]
    param(
        [switch]$Quiet,
        [switch]$PassThru
    )

    $requiredFunctions = @(
        "ConvertTo-BKArray"
        "Get-BKPropertyValue"
        "New-BKFinding"
        "Measure-BKScore"
        "New-BKAssessmentResult"
        "Export-BKJson"
        "Invoke-BKGraphPagedRequest"
        "Test-BKRequiredGraphScopes"
    )

    $checks = @(
        foreach ($functionName in $requiredFunctions) {
            $command = Get-Command -Name $functionName -CommandType Function -ErrorAction SilentlyContinue
            [PSCustomObject]@{
                Check   = $functionName
                Status  = if ($null -ne $command) { "PASS" } else { "FAIL" }
                Details = if ($null -ne $command) { "Shared helper is loaded." } else { "Shared helper is missing." }
            }
        }
    )

    $failed = @($checks | Where-Object Status -eq "FAIL")
    $frameworkState = Get-Variable -Name BKSharedFramework -Scope Script -ValueOnly -ErrorAction SilentlyContinue

    $result = [PSCustomObject]@{
        Platform       = "Blackknight One"
        Operation      = "SharedFrameworkValidation"
        Status         = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }
        Version        = if ($null -ne $frameworkState) { $frameworkState.Version } else { $null }
        RequiredChecks = $checks.Count
        Passed         = @($checks | Where-Object Status -eq "PASS").Count
        Failed         = $failed.Count
        Checks         = $checks
    }

    if (-not $Quiet.IsPresent) {
        Write-Host ""
        Write-Host "Blackknight Shared Framework" -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------"
        Write-Host "Status  : $($result.Status)"
        Write-Host "Version : $($result.Version)"
        Write-Host "Passed  : $($result.Passed)"
        Write-Host "Failed  : $($result.Failed)"

        if ($failed.Count -gt 0) {
            Write-Host ""
            $failed | Format-Table Check, Status, Details -AutoSize | Out-Host
        }
    }

    if ($PassThru.IsPresent -or $Quiet.IsPresent) {
        return $result
    }
}
