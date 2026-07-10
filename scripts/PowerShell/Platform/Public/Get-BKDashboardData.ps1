function Get-BKDashboardData {
    <#
    .SYNOPSIS
    Builds normalized dashboard data for Blackknight One.

    .DESCRIPTION
    Reads current engine reports, platform inventory, engine metadata,
    and validation results without making additional Microsoft Graph calls.
    #>

    [CmdletBinding()]
    param(
        [string]$ReportsRoot = ".\reports"
    )

    Write-BKLog -Message "Building Blackknight dashboard data..." -Level Info

    function Read-BKJsonFile {
        param(
            [Parameter(Mandatory)]
            [string]$Path
        )

        if (-not (Test-Path $Path)) {
            return $null
        }

        try {
            Get-Content -Path $Path -Raw -ErrorAction Stop |
                ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-BKLog `
                -Message "Unable to read JSON report at $Path. $($_.Exception.Message)" `
                -Level Warning

            return $null
        }
    }

    function Get-BKReportResults {
        param(
            [object]$Report
        )

        if ($null -eq $Report) {
            return @()
        }

        if ($Report.PSObject.Properties.Name -contains "ValidationResult") {
            return @($Report.ValidationResult)
        }

        if ($Report.PSObject.Properties.Name -contains "Results") {
            return @($Report.Results)
        }

        if ($Report.PSObject.Properties.Name -contains "Result") {
            return @($Report.Result)
        }

        return @($Report)
    }

    try {
        $platform = Get-BKPlatform
        $engines = @($platform.Engines)

        $identityPath = Join-Path $ReportsRoot "identity\identity-discovery.json"
        $trustPath = Join-Path $ReportsRoot "trust\trust-discovery.json"
        $governancePath = Join-Path $ReportsRoot "governance\governance-health.json"
        $operationsPath = Join-Path $ReportsRoot "operations\operations-health.json"
        $validationPath = Join-Path $ReportsRoot "validation\validation-report.json"

        $identityReport = Read-BKJsonFile -Path $identityPath
        $trustReport = Read-BKJsonFile -Path $trustPath
        $governanceReport = Read-BKJsonFile -Path $governancePath
        $operationsReport = Read-BKJsonFile -Path $operationsPath
        $validationReport = Read-BKJsonFile -Path $validationPath

        $identityResults = @(Get-BKReportResults -Report $identityReport)
        $trustResults = @(Get-BKReportResults -Report $trustReport)
        $governanceResults = @(Get-BKReportResults -Report $governanceReport)
        $operationsResults = @(Get-BKReportResults -Report $operationsReport)
        $validationResults = @(Get-BKReportResults -Report $validationReport)

        $allResults = @(
            $identityResults
            $trustResults
            $governanceResults
            $operationsResults
        ) | Where-Object {
            $null -ne $_ -and
            $_.PSObject.Properties.Name -contains "Confidence"
        }

        $overallConfidence = if ($allResults.Count -gt 0) {
            [math]::Round(
                ($allResults.Confidence | Measure-Object -Average).Average,
                2
            )
        }
        else {
            0
        }

        $identityConfidence = if ($identityResults.Count -gt 0) {
            [math]::Round(
                ($identityResults.Confidence | Measure-Object -Average).Average,
                2
            )
        }
        else {
            $null
        }

        $trustConfidence = if ($trustResults.Count -gt 0) {
            [math]::Round(
                ($trustResults.Confidence | Measure-Object -Average).Average,
                2
            )
        }
        else {
            $null
        }

        $governanceConfidence = if ($governanceResults.Count -gt 0) {
            [math]::Round(
                ($governanceResults.Confidence | Measure-Object -Average).Average,
                2
            )
        }
        else {
            $null
        }

        $operationsConfidence = if ($operationsResults.Count -gt 0) {
            [math]::Round(
                ($operationsResults.Confidence | Measure-Object -Average).Average,
                2
            )
        }
        else {
            $null
        }

        $validationConfidence = if ($validationResults.Count -gt 0) {
            [math]::Round(
                ($validationResults.Confidence | Measure-Object -Average).Average,
                2
            )
        }
        else {
            $null
        }

        $recommendations = @(
            $allResults |
                ForEach-Object { @($_.Recommendations) } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -Unique
        )

        $failedChecks = @(
            $allResults |
                Where-Object {
                    $_.PSObject.Properties.Name -contains "Failed"
                } |
                Measure-Object -Property Failed -Sum
        ).Sum

        $warningChecks = @(
            $allResults |
                Where-Object {
                    $_.PSObject.Properties.Name -contains "Warnings"
                } |
                Measure-Object -Property Warnings -Sum
        ).Sum

        $tenantName = $null
        $tenantId = $null
        $totalUsers = $null
        $guestUsers = $null
        $totalGroups = $null
        $subscribedSkus = $null

        if ($identityReport) {
            if ($identityReport.PSObject.Properties.Name -contains "Tenant") {
                $tenantName = $identityReport.Tenant.TenantName
                $tenantId = $identityReport.Tenant.TenantId
                $totalUsers = $identityReport.Tenant.TotalUsers
                $guestUsers = $identityReport.Tenant.GuestUsers
                $totalGroups = $identityReport.Tenant.TotalGroups
                $subscribedSkus = $identityReport.Tenant.SubscribedSkus
            }
        }

        [PSCustomObject]@{
            Platform = [PSCustomObject]@{
                Name            = $platform.Name
                Version         = $platform.Version
                Mission         = $platform.Mission
                NorthStar       = $platform.NorthStar
                EngineCount     = $platform.EngineCount
                ServiceCount    = $platform.ServiceCount
                CapabilityCount = $platform.CapabilityCount
            }

            Tenant = [PSCustomObject]@{
                Name           = $tenantName
                TenantId       = $tenantId
                TotalUsers     = $totalUsers
                GuestUsers     = $guestUsers
                TotalGroups    = $totalGroups
                SubscribedSkus = $subscribedSkus
            }

            Confidence = [PSCustomObject]@{
                Identity   = $identityConfidence
                Trust      = $trustConfidence
                Governance = $governanceConfidence
                Operations = $operationsConfidence
                Validation = $validationConfidence
                Overall    = $overallConfidence
            }

            Findings = [PSCustomObject]@{
                Warnings             = if ($null -eq $warningChecks) { 0 } else { $warningChecks }
                Failures             = if ($null -eq $failedChecks) { 0 } else { $failedChecks }
                RecommendationCount  = $recommendations.Count
                Recommendations      = $recommendations
            }

            Engines = $engines

            Reports = [PSCustomObject]@{
                IdentityAvailable   = Test-Path $identityPath
                TrustAvailable      = Test-Path $trustPath
                GovernanceAvailable = Test-Path $governancePath
                OperationsAvailable = Test-Path $operationsPath
                ValidationAvailable = Test-Path $validationPath
            }

            GeneratedAt = (Get-Date).ToUniversalTime().ToString("o")
        }
    }
    catch {
        Write-BKLog -Message $_.Exception.Message -Level Error
        throw
    }
}