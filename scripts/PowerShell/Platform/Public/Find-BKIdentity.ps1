function Find-BKIdentity {
    <#
    .SYNOPSIS
    Searches the Blackknight One identity graph.

    .DESCRIPTION
    Filters correlated Microsoft Entra identities by authentication,
    privilege, directory roles, account state, user type, and attention
    indicators.

    The command returns structured identity objects and does not format
    the results. Use Show-BKIdentity to display an individual profile.

    .PARAMETER Search
    Searches display name, user principal name, object ID, department,
    job title, and company name.

    .PARAMETER Privileged
    Returns privileged identities.

    .PARAMETER WithoutMfa
    Returns identities that are not registered for MFA.

    .PARAMETER WithoutPasswordless
    Returns identities that are not passwordless capable.

    .PARAMETER WithoutSspr
    Returns identities that are not registered for SSPR.

    .PARAMETER RequiresAttention
    Returns identities with one or more attention indicators.

    .PARAMETER HasDeprecatedRole
    Returns identities with deprecated directory-role assignments.

    .PARAMETER RoleName
    Returns identities assigned a matching directory role.

    .PARAMETER UserType
    Filters identities by Member or Guest.

    .PARAMETER Disabled
    Returns disabled identities.

    .PARAMETER Enabled
    Returns enabled identities.

    .PARAMETER SkipGraphConnect
    Reuses an existing Microsoft Graph connection.
    #>

    [CmdletBinding(DefaultParameterSetName = "All")]
    param(
        [Parameter(Position = 0)]
        [string]$Search,

        [switch]$Privileged,

        [switch]$WithoutMfa,

        [switch]$WithoutPasswordless,

        [switch]$WithoutSspr,

        [switch]$RequiresAttention,

        [switch]$HasDeprecatedRole,

        [string]$RoleName,

        [ValidateSet("Member", "Guest")]
        [string]$UserType,

        [Parameter(ParameterSetName = "Disabled")]
        [switch]$Disabled,

        [Parameter(ParameterSetName = "Enabled")]
        [switch]$Enabled,

        [switch]$SkipGraphConnect
    )

    Write-BKLog `
        -Message "Searching the Blackknight identity graph..." `
        -Level Info

    try {
        $graphParameters = @{}

        if ($SkipGraphConnect) {
            $graphParameters.SkipGraphConnect = $true
        }

        $results = @(
            Get-BKIdentityGraph @graphParameters
        )

        if (-not [string]::IsNullOrWhiteSpace($Search)) {
            $searchValue = $Search.Trim()

            $results = @(
                $results |
                    Where-Object {
                        (
                            $_.DisplayName -and
                            $_.DisplayName -like "*$searchValue*"
                        ) -or
                        (
                            $_.UserPrincipalName -and
                            $_.UserPrincipalName -like "*$searchValue*"
                        ) -or
                        (
                            $_.Id -and
                            $_.Id -like "*$searchValue*"
                        ) -or
                        (
                            $_.Department -and
                            $_.Department -like "*$searchValue*"
                        ) -or
                        (
                            $_.JobTitle -and
                            $_.JobTitle -like "*$searchValue*"
                        ) -or
                        (
                            $_.CompanyName -and
                            $_.CompanyName -like "*$searchValue*"
                        )
                    }
            )
        }

        if ($Privileged) {
            $results = @(
                $results |
                    Where-Object {
                        $_.IsPrivileged -eq $true
                    }
            )
        }

        if ($WithoutMfa) {
            $results = @(
                $results |
                    Where-Object {
                        $_.IsMfaRegistered -ne $true
                    }
            )
        }

        if ($WithoutPasswordless) {
            $results = @(
                $results |
                    Where-Object {
                        $_.IsPasswordlessCapable -ne $true
                    }
            )
        }

        if ($WithoutSspr) {
            $results = @(
                $results |
                    Where-Object {
                        $_.IsSsprRegistered -ne $true
                    }
            )
        }

        if ($RequiresAttention) {
            $results = @(
                $results |
                    Where-Object {
                        $_.RequiresAttention -eq $true
                    }
            )
        }

        if ($HasDeprecatedRole) {
            $results = @(
                $results |
                    Where-Object {
                        $_.HasDeprecatedRole -eq $true
                    }
            )
        }

        if (-not [string]::IsNullOrWhiteSpace($RoleName)) {
            $results = @(
                $results |
                    Where-Object {
                        @(
                            $_.DirectoryRoles |
                                Where-Object {
                                    $_ -like "*$RoleName*"
                                }
                        ).Count -gt 0
                    }
            )
        }

        if (-not [string]::IsNullOrWhiteSpace($UserType)) {
            $results = @(
                $results |
                    Where-Object {
                        $_.UserType -eq $UserType
                    }
            )
        }

        if ($Disabled) {
            $results = @(
                $results |
                    Where-Object {
                        $_.AccountEnabled -ne $true
                    }
            )
        }

        if ($Enabled) {
            $results = @(
                $results |
                    Where-Object {
                        $_.AccountEnabled -eq $true
                    }
            )
        }

        return @(
            $results |
                Sort-Object `
                    @{ Expression = "RequiresAttention"; Descending = $true },
                    @{ Expression = "IsPrivileged"; Descending = $true },
                    DisplayName
        )
    }
    catch {
        Write-BKLog `
            -Message $_.Exception.Message `
            -Level Error

        throw
    }
}