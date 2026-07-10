<#
.SYNOPSIS
Blackknight One Trust Engine

.DESCRIPTION
Discovers Conditional Access, named locations, and authentication
registration posture from Microsoft Graph, then produces a transparent
Zero Trust confidence score.

The current confidence model evaluates ten weighted controls:

1. Conditional Access policies discovered
2. Enabled Conditional Access policies
3. Disabled Conditional Access policy hygiene
4. Report-only Conditional Access policy hygiene
5. MFA registration
6. Administrative users without MFA
7. Passwordless readiness
8. SSPR registration
9. System-preferred authentication
10. Named location inventory coverage
#>

[CmdletBinding()]
param(
    [string]$OutputPath = ".\reports\trust",
    [switch]$ExportJson
)

$PlatformModule = Join-Path `
    (Split-Path $PSScriptRoot -Parent) `
    "Platform\Blackknight-Platform.psm1"

if (Test-Path $PlatformModule) {
    Import-Module $PlatformModule -Force
}
else {
    throw "Blackknight Platform module not found at $PlatformModule"
}

function Write-BKTrustSection {
    param(
        [Parameter(Mandatory)]
        [string]$Title
    )

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function New-BKTrustCheck {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet("PASS", "WARN", "FAIL")]
        [string]$Status,

        [Parameter(Mandatory)]
        [ValidateRange(0, 10)]
        [int]$Points,

        [Parameter(Mandatory)]
        [string]$Details,

        [string]$Recommendation
    )

    [PSCustomObject]@{
        Name           = $Name
        Status         = $Status
        Points         = $Points
        MaximumPoints  = 10
        Details        = $Details
        Recommendation = $Recommendation
    }
}

function Invoke-BKTrustDiscovery {
    Write-BKTrustSection "Blackknight Trust Discovery"

    try {
        Connect-BKGraph -Scopes @(
            "Policy.Read.All",
            "AuditLog.Read.All",
            "Directory.Read.All"
        ) | Out-Null

        $conditionalAccessPolicies = @(
            Get-BKConditionalAccessPolicies -SkipGraphConnect
        )

        $namedLocations = @(
            Get-BKNamedLocations -SkipGraphConnect
        )

        $authentication = Get-BKAuthenticationMethodsSummary -SkipGraphConnect

        $enabledPolicies = @(
            $conditionalAccessPolicies |
                Where-Object { $_.State -eq "enabled" }
        )

        $reportOnlyPolicies = @(
            $conditionalAccessPolicies |
                Where-Object {
                    $_.State -eq "enabledForReportingButNotEnforced"
                }
        )

        $disabledPolicies = @(
            $conditionalAccessPolicies |
                Where-Object { $_.State -eq "disabled" }
        )

        $checks = @()

        # 1. Conditional Access inventory

        if ($conditionalAccessPolicies.Count -gt 0) {
            $checks += New-BKTrustCheck `
                -Name "Conditional Access Inventory" `
                -Status "PASS" `
                -Points 10 `
                -Details "$($conditionalAccessPolicies.Count) policies discovered."
        }
        else {
            $checks += New-BKTrustCheck `
                -Name "Conditional Access Inventory" `
                -Status "FAIL" `
                -Points 0 `
                -Details "No Conditional Access policies were discovered." `
                -Recommendation "Create a Conditional Access policy baseline."
        }

        # 2. Enabled Conditional Access policies

        if ($enabledPolicies.Count -gt 0) {
            $checks += New-BKTrustCheck `
                -Name "Enabled Conditional Access" `
                -Status "PASS" `
                -Points 10 `
                -Details "$($enabledPolicies.Count) enabled policies discovered."
        }
        else {
            $checks += New-BKTrustCheck `
                -Name "Enabled Conditional Access" `
                -Status "FAIL" `
                -Points 0 `
                -Details "No enabled Conditional Access policies were discovered." `
                -Recommendation "Enable validated Conditional Access policies."
        }

        # 3. Disabled policy hygiene

        if ($disabledPolicies.Count -eq 0) {
            $checks += New-BKTrustCheck `
                -Name "Disabled Policy Hygiene" `
                -Status "PASS" `
                -Points 10 `
                -Details "No disabled Conditional Access policies detected."
        }
        elseif ($disabledPolicies.Count -le 2) {
            $checks += New-BKTrustCheck `
                -Name "Disabled Policy Hygiene" `
                -Status "WARN" `
                -Points 5 `
                -Details "$($disabledPolicies.Count) disabled policies detected." `
                -Recommendation "Review disabled Conditional Access policies for removal or reactivation."
        }
        else {
            $checks += New-BKTrustCheck `
                -Name "Disabled Policy Hygiene" `
                -Status "FAIL" `
                -Points 0 `
                -Details "$($disabledPolicies.Count) disabled policies detected." `
                -Recommendation "Reduce Conditional Access policy sprawl and remove obsolete disabled policies."
        }

        # 4. Report-only policy hygiene

        if ($reportOnlyPolicies.Count -eq 0) {
            $checks += New-BKTrustCheck `
                -Name "Report-Only Policy Hygiene" `
                -Status "PASS" `
                -Points 10 `
                -Details "No report-only policies require promotion or retirement."
        }
        elseif ($reportOnlyPolicies.Count -le 2) {
            $checks += New-BKTrustCheck `
                -Name "Report-Only Policy Hygiene" `
                -Status "WARN" `
                -Points 5 `
                -Details "$($reportOnlyPolicies.Count) report-only policies detected." `
                -Recommendation "Review report-only results and either enable or retire those policies."
        }
        else {
            $checks += New-BKTrustCheck `
                -Name "Report-Only Policy Hygiene" `
                -Status "FAIL" `
                -Points 0 `
                -Details "$($reportOnlyPolicies.Count) report-only policies detected." `
                -Recommendation "Resolve the Conditional Access report-only policy backlog."
        }

        # 5. MFA registration

        $mfaPercent = [double]$authentication.MfaRegisteredPercent

        if ($mfaPercent -ge 90) {
            $checks += New-BKTrustCheck `
                -Name "MFA Registration" `
                -Status "PASS" `
                -Points 10 `
                -Details "$mfaPercent% of users are registered for MFA."
        }
        elseif ($mfaPercent -ge 80) {
            $checks += New-BKTrustCheck `
                -Name "MFA Registration" `
                -Status "WARN" `
                -Points 8 `
                -Details "$mfaPercent% of users are registered for MFA." `
                -Recommendation "Increase MFA registration to at least 90%."
        }
        elseif ($mfaPercent -ge 60) {
            $checks += New-BKTrustCheck `
                -Name "MFA Registration" `
                -Status "WARN" `
                -Points 5 `
                -Details "$mfaPercent% of users are registered for MFA." `
                -Recommendation "Prioritize MFA registration for unregistered users."
        }
        else {
            $checks += New-BKTrustCheck `
                -Name "MFA Registration" `
                -Status "FAIL" `
                -Points 0 `
                -Details "$mfaPercent% of users are registered for MFA." `
                -Recommendation "Launch an immediate MFA registration campaign."
        }

        # 6. Administrative users without MFA

        $adminsWithoutMfa = [int]$authentication.AdminsWithoutMfa

        if ($adminsWithoutMfa -eq 0) {
            $checks += New-BKTrustCheck `
                -Name "Administrative MFA Coverage" `
                -Status "PASS" `
                -Points 10 `
                -Details "All detected administrative users are registered for MFA."
        }
        else {
            $checks += New-BKTrustCheck `
                -Name "Administrative MFA Coverage" `
                -Status "FAIL" `
                -Points 0 `
                -Details "$adminsWithoutMfa administrative users are not registered for MFA." `
                -Recommendation "Require MFA registration for every administrative account immediately."
        }

        # 7. Passwordless readiness

        $passwordlessPercent = [double]$authentication.PasswordlessCapablePercent

        if ($passwordlessPercent -ge 50) {
            $checks += New-BKTrustCheck `
                -Name "Passwordless Readiness" `
                -Status "PASS" `
                -Points 10 `
                -Details "$passwordlessPercent% of users are passwordless capable."
        }
        elseif ($passwordlessPercent -ge 25) {
            $checks += New-BKTrustCheck `
                -Name "Passwordless Readiness" `
                -Status "WARN" `
                -Points 8 `
                -Details "$passwordlessPercent% of users are passwordless capable." `
                -Recommendation "Continue expanding passwordless authentication adoption."
        }
        elseif ($passwordlessPercent -gt 0) {
            $checks += New-BKTrustCheck `
                -Name "Passwordless Readiness" `
                -Status "WARN" `
                -Points 5 `
                -Details "$passwordlessPercent% of users are passwordless capable." `
                -Recommendation "Create a phased passwordless deployment plan."
        }
        else {
            $checks += New-BKTrustCheck `
                -Name "Passwordless Readiness" `
                -Status "FAIL" `
                -Points 0 `
                -Details "No users are currently passwordless capable." `
                -Recommendation "Evaluate FIDO2, Windows Hello for Business, passkeys, and Temporary Access Pass."
        }

        # 8. SSPR registration

        $ssprPercent = [double]$authentication.SsprRegisteredPercent

        if ($ssprPercent -ge 90) {
            $checks += New-BKTrustCheck `
                -Name "SSPR Registration" `
                -Status "PASS" `
                -Points 10 `
                -Details "$ssprPercent% of users are registered for SSPR."
        }
        elseif ($ssprPercent -ge 80) {
            $checks += New-BKTrustCheck `
                -Name "SSPR Registration" `
                -Status "WARN" `
                -Points 8 `
                -Details "$ssprPercent% of users are registered for SSPR." `
                -Recommendation "Increase SSPR registration to at least 90%."
        }
        elseif ($ssprPercent -ge 60) {
            $checks += New-BKTrustCheck `
                -Name "SSPR Registration" `
                -Status "WARN" `
                -Points 5 `
                -Details "$ssprPercent% of users are registered for SSPR." `
                -Recommendation "Increase SSPR registration and capability coverage."
        }
        else {
            $checks += New-BKTrustCheck `
                -Name "SSPR Registration" `
                -Status "FAIL" `
                -Points 0 `
                -Details "$ssprPercent% of users are registered for SSPR." `
                -Recommendation "Deploy and promote self-service password reset registration."
        }

        # 9. System-preferred authentication

        $systemPreferredPercent = [double]$authentication.SystemPreferredEnabledPercent

        if ($systemPreferredPercent -ge 80) {
            $checks += New-BKTrustCheck `
                -Name "System-Preferred Authentication" `
                -Status "PASS" `
                -Points 10 `
                -Details "$systemPreferredPercent% of users have system-preferred authentication enabled."
        }
        elseif ($systemPreferredPercent -ge 50) {
            $checks += New-BKTrustCheck `
                -Name "System-Preferred Authentication" `
                -Status "WARN" `
                -Points 5 `
                -Details "$systemPreferredPercent% of users have system-preferred authentication enabled." `
                -Recommendation "Expand system-preferred authentication coverage."
        }
        else {
            $checks += New-BKTrustCheck `
                -Name "System-Preferred Authentication" `
                -Status "FAIL" `
                -Points 0 `
                -Details "$systemPreferredPercent% of users have system-preferred authentication enabled." `
                -Recommendation "Enable and validate system-preferred authentication methods."
        }

        # 10. Named location inventory coverage

        $checks += New-BKTrustCheck `
            -Name "Named Location Inventory" `
            -Status "PASS" `
            -Points 10 `
            -Details "$($namedLocations.Count) named locations discovered and inventoried."

        $score = (
            $checks |
                Measure-Object -Property Points -Sum
        ).Sum

        $passed = @(
            $checks |
                Where-Object { $_.Status -eq "PASS" }
        ).Count

        $warnings = @(
            $checks |
                Where-Object { $_.Status -eq "WARN" }
        ).Count

        $failed = @(
            $checks |
                Where-Object { $_.Status -eq "FAIL" }
        ).Count

        $recommendations = @(
            $checks |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_.Recommendation)
                } |
                Select-Object -ExpandProperty Recommendation -Unique
        )

        $evidence = @(
            "Conditional Access policies: $($conditionalAccessPolicies.Count)"
            "Enabled Conditional Access policies: $($enabledPolicies.Count)"
            "Report-only Conditional Access policies: $($reportOnlyPolicies.Count)"
            "Disabled Conditional Access policies: $($disabledPolicies.Count)"
            "Named locations: $($namedLocations.Count)"
            "MFA registration: $($authentication.MfaRegisteredPercent)%"
            "Administrative users without MFA: $($authentication.AdminsWithoutMfa)"
            "Passwordless capability: $($authentication.PasswordlessCapablePercent)%"
            "SSPR registration: $($authentication.SsprRegisteredPercent)%"
            "System-preferred authentication: $($authentication.SystemPreferredEnabledPercent)%"
        )

        $health = if ($failed -gt 0) {
            "Degraded"
        }
        elseif ($warnings -gt 0) {
            "Warning"
        }
        else {
            "Healthy"
        }

        $result = New-BKResult `
            -Engine "Trust Engine" `
            -Version "0.5.0-alpha" `
            -Status "Integrated" `
            -Health $health `
            -Confidence $score `
            -ChecksRun $checks.Count `
            -Passed $passed `
            -Warnings $warnings `
            -Failed $failed `
            -Evidence $evidence `
            -Recommendations $recommendations

        Write-Host ""
        Write-Host "Conditional Access"
        Write-Host "----------------------------------------"
        Write-Host "Total Policies          : $($conditionalAccessPolicies.Count)"
        Write-Host "Enabled Policies        : $($enabledPolicies.Count)"
        Write-Host "Report-Only Policies    : $($reportOnlyPolicies.Count)"
        Write-Host "Disabled Policies       : $($disabledPolicies.Count)"
        Write-Host "Named Locations         : $($namedLocations.Count)"

        Write-Host ""
        Write-Host "Authentication"
        Write-Host "----------------------------------------"
        Write-Host "Total Users             : $($authentication.TotalUsers)"
        Write-Host "Administrative Users    : $($authentication.AdminUsers)"
        Write-Host "MFA Registered          : $($authentication.MfaRegisteredPercent)%"
        Write-Host "Admins Without MFA      : $($authentication.AdminsWithoutMfa)"
        Write-Host "Passwordless Capable    : $($authentication.PasswordlessCapablePercent)%"
        Write-Host "SSPR Registered         : $($authentication.SsprRegisteredPercent)%"
        Write-Host "System Preferred        : $($authentication.SystemPreferredEnabledPercent)%"

        Write-Host ""
        Write-Host "Trust Controls"
        Write-Host "----------------------------------------"

        $checks |
            Format-Table Name, Status, Points, MaximumPoints, Details -AutoSize

        Write-Host ""
        Write-Host "Trust Confidence        : $score%" -ForegroundColor Green
        Write-Host "Trust Health            : $health"
        Write-Host "Passed                  : $passed"
        Write-Host "Warnings                : $warnings"
        Write-Host "Failed                  : $failed"

        if ($recommendations.Count -gt 0) {
            Write-Host ""
            Write-Host "Recommendations" -ForegroundColor Yellow

            foreach ($recommendation in $recommendations) {
                Write-Host "- $recommendation"
            }
        }

        if ($ExportJson) {
            if (-not (Test-Path $OutputPath)) {
                New-Item `
                    -Path $OutputPath `
                    -ItemType Directory `
                    -Force |
                    Out-Null
            }

            $report = [PSCustomObject]@{
                Platform          = "Blackknight One"
                Version           = "0.5.0-alpha"
                GeneratedAt       = (Get-Date).ToUniversalTime().ToString("o")
                Result            = $result
                Checks            = $checks
                ConditionalAccess = [PSCustomObject]@{
                    Total      = $conditionalAccessPolicies.Count
                    Enabled    = $enabledPolicies.Count
                    ReportOnly = $reportOnlyPolicies.Count
                    Disabled   = $disabledPolicies.Count
                    Policies   = $conditionalAccessPolicies
                }
                NamedLocations    = $namedLocations
                Authentication    = $authentication
            }

            $jsonPath = Join-Path $OutputPath "trust-discovery.json"

            Export-BKJsonReport `
                -Data $report `
                -Path $jsonPath
        }

        Write-BKTrustSection "Trust Discovery Complete"
    }
    catch {
        Write-BKLog -Message $_.Exception.Message -Level Error
        throw
    }
}

Invoke-BKTrustDiscovery