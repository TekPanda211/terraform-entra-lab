function Show-BKIdentity {
    <#
    .SYNOPSIS
    Displays a correlated identity intelligence profile.

    .DESCRIPTION
    Uses Get-BKIdentityGraph to display identity, authentication,
    authorization, attention indicators, and directory-role information
    for a selected Microsoft Entra identity.

    .PARAMETER Identity
    A display name, user principal name, or Microsoft Entra object ID.

    .PARAMETER SkipGraphConnect
    Reuses an existing Microsoft Graph connection.
    #>

    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory,
            Position = 0
        )]
        [string]$Identity,

        [switch]$SkipGraphConnect
    )

    function Format-BKIdentityValue {
        param(
            [AllowNull()]
            [object]$Value
        )

        if (
            $null -eq $Value -or
            [string]::IsNullOrWhiteSpace([string]$Value)
        ) {
            return "Not Available"
        }

        return [string]$Value
    }

    function Format-BKBoolean {
        param(
            [AllowNull()]
            [object]$Value
        )

        if ($null -eq $Value) {
            return "Unknown"
        }

        if ($Value -eq $true) {
            return "Yes"
        }

        return "No"
    }

    function Get-BKBooleanColor {
        param(
            [AllowNull()]
            [object]$Value,

            [switch]$FalseIsGood
        )

        if ($null -eq $Value) {
            return "DarkGray"
        }

        if ($FalseIsGood) {
            if ($Value -eq $false) {
                return "Green"
            }

            return "Red"
        }

        if ($Value -eq $true) {
            return "Green"
        }

        return "Red"
    }

    function Write-BKIdentityRow {
        param(
            [Parameter(Mandatory)]
            [string]$Label,

            [AllowNull()]
            [object]$Value,

            [string]$Color = "White"
        )

        Write-Host $Label.PadRight(32) -NoNewline
        Write-Host (
            Format-BKIdentityValue -Value $Value
        ) -ForegroundColor $Color
    }

    function Write-BKIdentityBooleanRow {
        param(
            [Parameter(Mandatory)]
            [string]$Label,

            [AllowNull()]
            [object]$Value,

            [switch]$FalseIsGood
        )

        $color = Get-BKBooleanColor `
            -Value $Value `
            -FalseIsGood:$FalseIsGood

        Write-Host $Label.PadRight(32) -NoNewline
        Write-Host (
            Format-BKBoolean -Value $Value
        ) -ForegroundColor $color
    }

    try {
        $graphParameters = @{}

        if ($SkipGraphConnect) {
            $graphParameters.SkipGraphConnect = $true
        }

        $identityGraph = @(
            Get-BKIdentityGraph @graphParameters
        )

        $normalizedSearch = $Identity.Trim().ToLowerInvariant()

        $matches = @(
            $identityGraph |
                Where-Object {
                    (
                        $_.Id -and
                        ([string]$_.Id).ToLowerInvariant() -eq
                            $normalizedSearch
                    ) -or
                    (
                        $_.UserPrincipalName -and
                        ([string]$_.UserPrincipalName).ToLowerInvariant() -eq
                            $normalizedSearch
                    ) -or
                    (
                        $_.DisplayName -and
                        ([string]$_.DisplayName).ToLowerInvariant() -eq
                            $normalizedSearch
                    )
                }
        )

        if ($matches.Count -eq 0) {
            $matches = @(
                $identityGraph |
                    Where-Object {
                        (
                            $_.UserPrincipalName -and
                            ([string]$_.UserPrincipalName) -like
                                "*$Identity*"
                        ) -or
                        (
                            $_.DisplayName -and
                            ([string]$_.DisplayName) -like
                                "*$Identity*"
                        )
                    }
            )
        }

        if ($matches.Count -eq 0) {
            throw "No identity matched '$Identity'."
        }

        if ($matches.Count -gt 1) {
            Write-Host ""
            Write-Host "Multiple identities matched '$Identity':" `
                -ForegroundColor Yellow

            $matches |
                Select-Object `
                    DisplayName,
                    UserPrincipalName,
                    Id |
                Format-Table -AutoSize

            throw "Use the exact user principal name or object ID."
        }

        $record = $matches[0]

        $identityScore = 100
        $recommendations = @()

        if ($record.AccountEnabled -ne $true) {
            $identityScore -= 10
            $recommendations +=
                "Review whether this disabled identity should remain in the directory."
        }

        if ($record.IsMfaRegistered -ne $true) {
            $identityScore -= 25
            $recommendations +=
                "Register the identity for multifactor authentication."
        }

        if (
            $record.IsPrivileged -eq $true -and
            $record.IsMfaRegistered -ne $true
        ) {
            $identityScore -= 25
            $recommendations +=
                "Require MFA immediately because this identity is privileged."
        }

        if ($record.IsPasswordlessCapable -ne $true) {
            $identityScore -= 15
            $recommendations +=
                "Evaluate passkeys, FIDO2, Windows Hello for Business, or Temporary Access Pass."
        }

        if ($record.IsSsprRegistered -ne $true) {
            $identityScore -= 10
            $recommendations +=
                "Complete self-service password reset registration."
        }

        if ($record.HasDeprecatedRole -eq $true) {
            $identityScore -= 20
            $recommendations +=
                "Review and remove deprecated directory-role assignments."
        }

        if ($record.RoleAssignmentsRequiringReview -gt 0) {
            $identityScore -= 10
            $recommendations +=
                "Review flagged directory-role assignments."
        }

        if ($identityScore -lt 0) {
            $identityScore = 0
        }

        $health = if ($identityScore -ge 85) {
            "Healthy"
        }
        elseif ($identityScore -ge 70) {
            "Warning"
        }
        else {
            "Degraded"
        }

        $healthColor = if ($identityScore -ge 85) {
            "Green"
        }
        elseif ($identityScore -ge 70) {
            "Yellow"
        }
        else {
            "Red"
        }

        Clear-Host

        Write-Host ""
        Write-Host "====================================================================" `
            -ForegroundColor Cyan
        Write-Host "                  BLACKKNIGHT IDENTITY INTELLIGENCE" `
            -ForegroundColor Cyan
        Write-Host "====================================================================" `
            -ForegroundColor Cyan

        Write-Host ""
        Write-Host $record.DisplayName -ForegroundColor Yellow
        Write-Host $record.UserPrincipalName -ForegroundColor Gray

        Write-Host ""
        Write-Host "Identity" -ForegroundColor Yellow
        Write-Host "--------------------------------------------------------------------"

        Write-BKIdentityRow `
            -Label "Object ID" `
            -Value $record.Id

        Write-BKIdentityRow `
            -Label "User Type" `
            -Value $record.UserType

        Write-BKIdentityBooleanRow `
            -Label "Account Enabled" `
            -Value $record.AccountEnabled

        Write-BKIdentityRow `
            -Label "Department" `
            -Value $record.Department

        Write-BKIdentityRow `
            -Label "Job Title" `
            -Value $record.JobTitle

        Write-BKIdentityRow `
            -Label "Company" `
            -Value $record.CompanyName

        Write-Host ""
        Write-Host "Authentication" -ForegroundColor Yellow
        Write-Host "--------------------------------------------------------------------"

        Write-BKIdentityBooleanRow `
            -Label "MFA Registered" `
            -Value $record.IsMfaRegistered

        Write-BKIdentityBooleanRow `
            -Label "MFA Capable" `
            -Value $record.IsMfaCapable

        Write-BKIdentityBooleanRow `
            -Label "Passwordless Capable" `
            -Value $record.IsPasswordlessCapable

        Write-BKIdentityBooleanRow `
            -Label "SSPR Registered" `
            -Value $record.IsSsprRegistered

        Write-BKIdentityBooleanRow `
            -Label "SSPR Capable" `
            -Value $record.IsSsprCapable

        Write-BKIdentityBooleanRow `
            -Label "System Preferred Enabled" `
            -Value $record.IsSystemPreferredAuthenticationMethodEnabled

        Write-BKIdentityRow `
            -Label "Preferred Secondary Method" `
            -Value $record.PreferredSecondaryMethod

        Write-BKIdentityRow `
            -Label "Registered Methods" `
            -Value (
                @($record.RegisteredMethods) -join ", "
            )

        Write-BKIdentityRow `
            -Label "System Preferred Methods" `
            -Value (
                @($record.SystemPreferredMethods) -join ", "
            )

        Write-Host ""
        Write-Host "Authorization" -ForegroundColor Yellow
        Write-Host "--------------------------------------------------------------------"

        Write-BKIdentityBooleanRow `
            -Label "Privileged Identity" `
            -Value $record.IsPrivileged

        Write-BKIdentityRow `
            -Label "Active Role Assignments" `
            -Value $record.PrivilegedRoleCount

        Write-BKIdentityRow `
            -Label "Directory Roles" `
            -Value (
                @($record.DirectoryRoles) -join ", "
            )

        Write-BKIdentityBooleanRow `
            -Label "Deprecated Role Assigned" `
            -Value $record.HasDeprecatedRole `
            -FalseIsGood

        Write-BKIdentityRow `
            -Label "Highest Role Severity" `
            -Value $record.HighestRoleSeverity

        Write-BKIdentityRow `
            -Label "Assignments Requiring Review" `
            -Value $record.RoleAssignmentsRequiringReview

        Write-Host ""
        Write-Host "Identity Health" -ForegroundColor Yellow
        Write-Host "--------------------------------------------------------------------"

        Write-BKIdentityRow `
            -Label "Health" `
            -Value $health `
            -Color $healthColor

        Write-BKIdentityRow `
            -Label "Confidence" `
            -Value "$identityScore%" `
            -Color $healthColor

        Write-BKIdentityBooleanRow `
            -Label "Requires Attention" `
            -Value $record.RequiresAttention `
            -FalseIsGood

        if (@($record.AttentionReasons).Count -gt 0) {
            Write-Host ""
            Write-Host "Attention Indicators" -ForegroundColor Yellow
            Write-Host "--------------------------------------------------------------------"

            foreach ($reason in @($record.AttentionReasons)) {
                Write-Host "- $reason"
            }
        }

        $recommendations = @(
            $recommendations |
                Select-Object -Unique
        )

        if ($recommendations.Count -gt 0) {
            Write-Host ""
            Write-Host "Recommendations" -ForegroundColor Yellow
            Write-Host "--------------------------------------------------------------------"

            foreach ($recommendation in $recommendations) {
                Write-Host "- $recommendation"
            }
        }
        else {
            Write-Host ""
            Write-Host "No identity-specific recommendations were generated." `
                -ForegroundColor Green
        }

        Write-Host ""
        Write-Host "Authentication data updated: $($record.AuthenticationLastUpdated)" `
            -ForegroundColor DarkGray
        Write-Host "====================================================================" `
            -ForegroundColor Cyan
        Write-Host ""

        return $record
    }
    catch {
        Write-BKLog `
            -Message $_.Exception.Message `
            -Level Error

        throw
    }
}