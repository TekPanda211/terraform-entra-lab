<#
.SYNOPSIS
Blackknight One Correlation Engine

.DESCRIPTION
Builds a normalized identity graph and evaluates correlated
identity and authentication evidence.
#>

[CmdletBinding()]
param(
    [string]$OutputPath = ".\reports\correlation",
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

function Write-BKCorrelationSection {
    param(
        [Parameter(Mandatory)]
        [string]$Title
    )

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Invoke-BKCorrelation {
    Write-BKCorrelationSection "Blackknight Correlation Engine"

    try {
        Connect-BKGraph -Scopes @(
            "User.Read.All",
            "Directory.Read.All",
            "AuditLog.Read.All"
        ) | Out-Null

        $identities = @(
            Get-BKIdentityGraph -SkipGraphConnect
        )

        $enabledUsers = @(
            $identities |
                Where-Object { $_.AccountEnabled -eq $true }
        )

        $disabledUsers = @(
            $identities |
                Where-Object { $_.AccountEnabled -ne $true }
        )

        $administrativeUsers = @(
            $identities |
                Where-Object { $_.IsAdmin -eq $true }
        )

        $usersWithoutMfa = @(
            $identities |
                Where-Object {
                    $_.IsMfaRegistered -eq $false
                }
        )

        $adminsWithoutMfa = @(
            $identities |
                Where-Object {
                    $_.IsAdmin -eq $true -and
                    $_.IsMfaRegistered -eq $false
                }
        )

        $passwordlessUsers = @(
            $identities |
                Where-Object {
                    $_.IsPasswordlessCapable -eq $true
                }
        )

        $usersWithoutPasswordless = @(
            $identities |
                Where-Object {
                    $_.IsPasswordlessCapable -eq $false
                }
        )

        $usersWithoutSspr = @(
            $identities |
                Where-Object {
                    $_.IsSsprRegistered -eq $false
                }
        )

        $attentionRequired = @(
            $identities |
                Where-Object { $_.RequiresAttention -eq $true }
        )

        $totalUsers = $identities.Count

        $correlationCoverage = if ($totalUsers -gt 0) {
            $correlatedUsers = @(
                $identities |
                    Where-Object {
                        $null -ne $_.IsMfaRegistered
                    }
            ).Count

            [math]::Round(
                ($correlatedUsers / $totalUsers) * 100,
                2
            )
        }
        else {
            0
        }

        $score = 0
        $checksRun = 5
        $passed = 0
        $warnings = 0
        $failed = 0
        $evidence = @()
        $recommendations = @()

        if ($totalUsers -gt 0) {
            $score += 20
            $passed++
            $evidence += "$totalUsers identities correlated."
        }
        else {
            $failed++
            $recommendations += "No identities were available for correlation."
        }

        if ($correlationCoverage -ge 95) {
            $score += 20
            $passed++
            $evidence += "Authentication correlation coverage is $correlationCoverage%."
        }
        elseif ($correlationCoverage -ge 75) {
            $score += 10
            $warnings++
            $recommendations +=
                "Improve authentication correlation coverage beyond $correlationCoverage%."
        }
        else {
            $failed++
            $recommendations +=
                "Authentication correlation coverage is incomplete."
        }

        if ($adminsWithoutMfa.Count -eq 0) {
            $score += 20
            $passed++
            $evidence += "No administrative users without MFA were detected."
        }
        else {
            $failed++
            $recommendations +=
                "Require MFA for all administrative identities immediately."
        }

        if ($usersWithoutMfa.Count -eq 0) {
            $score += 20
            $passed++
            $evidence += "All correlated identities are registered for MFA."
        }
        else {
            $warnings++
            $recommendations +=
                "$($usersWithoutMfa.Count) identities are not registered for MFA."
        }

        if ($passwordlessUsers.Count -gt 0) {
            $score += 20
            $passed++
            $evidence +=
                "$($passwordlessUsers.Count) identities are passwordless capable."
        }
        else {
            $failed++
            $recommendations +=
                "No passwordless-capable identities were detected."
        }

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
            -Engine "Correlation Engine" `
            -Version "0.5.0-alpha" `
            -Status "Integrated" `
            -Health $health `
            -Confidence $score `
            -ChecksRun $checksRun `
            -Passed $passed `
            -Warnings $warnings `
            -Failed $failed `
            -Evidence $evidence `
            -Recommendations $recommendations

        Write-Host ""
        Write-Host "Identity Correlation"
        Write-Host "----------------------------------------"
        Write-Host "Total Identities           : $totalUsers"
        Write-Host "Enabled Identities         : $($enabledUsers.Count)"
        Write-Host "Disabled Identities        : $($disabledUsers.Count)"
        Write-Host "Administrative Identities  : $($administrativeUsers.Count)"
        Write-Host "Correlation Coverage       : $correlationCoverage%"

        Write-Host ""
        Write-Host "Authentication Correlation"
        Write-Host "----------------------------------------"
        Write-Host "Users Without MFA          : $($usersWithoutMfa.Count)"
        Write-Host "Admins Without MFA         : $($adminsWithoutMfa.Count)"
        Write-Host "Passwordless Capable       : $($passwordlessUsers.Count)"
        Write-Host "Without Passwordless       : $($usersWithoutPasswordless.Count)"
        Write-Host "Without SSPR               : $($usersWithoutSspr.Count)"
        Write-Host "Attention Required         : $($attentionRequired.Count)"

        Write-Host ""
        Write-Host "Correlation Confidence     : $score%" -ForegroundColor Green
        Write-Host "Correlation Health         : $health"

        if ($attentionRequired.Count -gt 0) {
            Write-Host ""
            Write-Host "Identities Requiring Attention" -ForegroundColor Yellow
            Write-Host "----------------------------------------"

            $attentionRequired |
                Select-Object `
                    DisplayName,
                    UserPrincipalName,
                    IsAdmin,
                    IsMfaRegistered,
                    IsPasswordlessCapable,
                    @{
                        Name = "Reasons"
                        Expression = {
                            @($_.AttentionReasons) -join "; "
                        }
                    } |
                Format-Table -AutoSize
        }

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
                Platform = "Blackknight One"
                Version = "0.5.0-alpha"
                GeneratedAt = (Get-Date).
                    ToUniversalTime().
                    ToString("o")
                Result = $result
                Summary = [PSCustomObject]@{
                    TotalIdentities = $totalUsers
                    EnabledIdentities = $enabledUsers.Count
                    DisabledIdentities = $disabledUsers.Count
                    AdministrativeIdentities =
                        $administrativeUsers.Count
                    CorrelationCoverage =
                        $correlationCoverage
                    UsersWithoutMfa =
                        $usersWithoutMfa.Count
                    AdminsWithoutMfa =
                        $adminsWithoutMfa.Count
                    PasswordlessCapable =
                        $passwordlessUsers.Count
                    UsersWithoutPasswordless =
                        $usersWithoutPasswordless.Count
                    UsersWithoutSspr =
                        $usersWithoutSspr.Count
                    AttentionRequired =
                        $attentionRequired.Count
                }
                Identities = $identities
            }

            $jsonPath = Join-Path `
                $OutputPath `
                "identity-graph.json"

            Export-BKJsonReport `
                -Data $report `
                -Path $jsonPath
        }

        Write-BKCorrelationSection "Correlation Engine Complete"
    }
    catch {
        Write-BKLog -Message $_.Exception.Message -Level Error
        throw
    }
}

Invoke-BKCorrelation