function Get-BKIdentityGraph {
    <#
    .SYNOPSIS
    Builds the normalized Blackknight One identity graph.

    .DESCRIPTION
    Correlates Microsoft Entra users with authentication registration
    data and active directory-role assignments.

    Current correlation layers:

    - User identity and account state
    - Authentication registration
    - MFA and passwordless readiness
    - SSPR readiness
    - Active directory roles
    - Privileged identity classification
    - Deprecated-role detection
    - Attention and review reasons

    .PARAMETER SkipGraphConnect
    Skips Microsoft Graph connection handling when called by an orchestrator.
    #>

    [CmdletBinding()]
    param(
        [switch]$SkipGraphConnect
    )

    Write-BKLog `
        -Message "Building Blackknight identity graph..." `
        -Level Info

    try {
        if (-not $SkipGraphConnect) {
            Connect-BKGraph -Scopes @(
                "User.Read.All",
                "Directory.Read.All",
                "AuditLog.Read.All",
                "RoleManagement.Read.Directory"
            ) | Out-Null
        }

        $users = @(
            Get-BKUsers -SkipGraphConnect
        )

        $authenticationDetails = @(
            Get-MgReportAuthenticationMethodUserRegistrationDetail `
                -All `
                -ErrorAction Stop
        )

        $directoryRoles = @(
            Get-BKDirectoryRoles -SkipGraphConnect
        )

        # Authentication lookup tables

        $authenticationById = @{}
        $authenticationByUpn = @{}

        foreach ($authenticationRecord in $authenticationDetails) {
            if ($authenticationRecord.Id) {
                $authenticationById[
                    ([string]$authenticationRecord.Id).ToLowerInvariant()
                ] = $authenticationRecord
            }

            if ($authenticationRecord.UserPrincipalName) {
                $authenticationByUpn[
                    $authenticationRecord.
                        UserPrincipalName.
                        ToLowerInvariant()
                ] = $authenticationRecord
            }
        }

        # Directory-role lookup by user principal ID

        $rolesByPrincipalId = @{}

        foreach ($roleAssignment in $directoryRoles) {
            if (-not $roleAssignment.PrincipalId) {
                continue
            }

            $principalKey = (
                [string]$roleAssignment.PrincipalId
            ).ToLowerInvariant()

            if (-not $rolesByPrincipalId.ContainsKey($principalKey)) {
                $rolesByPrincipalId[$principalKey] = @()
            }

            $rolesByPrincipalId[$principalKey] += $roleAssignment
        }

        $identityGraph = foreach ($user in $users) {
            $authentication = $null

            if ($user.Id) {
                $userIdKey = (
                    [string]$user.Id
                ).ToLowerInvariant()

                if ($authenticationById.ContainsKey($userIdKey)) {
                    $authentication = $authenticationById[$userIdKey]
                }
            }

            if (
                -not $authentication -and
                $user.UserPrincipalName
            ) {
                $userUpnKey = (
                    [string]$user.UserPrincipalName
                ).ToLowerInvariant()

                if ($authenticationByUpn.ContainsKey($userUpnKey)) {
                    $authentication = $authenticationByUpn[$userUpnKey]
                }
            }

            $userRoleAssignments = @()

            if ($user.Id) {
                $userRoleKey = (
                    [string]$user.Id
                ).ToLowerInvariant()

                if ($rolesByPrincipalId.ContainsKey($userRoleKey)) {
                    $userRoleAssignments = @(
                        $rolesByPrincipalId[$userRoleKey]
                    )
                }
            }

            $roleNames = @(
                $userRoleAssignments |
                    Select-Object -ExpandProperty RoleName -Unique
            )

            $deprecatedRoles = @(
                $userRoleAssignments |
                    Where-Object { $_.IsDeprecated -eq $true }
            )

            $roleAssignmentsRequiringReview = @(
                $userRoleAssignments |
                    Where-Object { $_.RequiresReview -eq $true }
            )

            $registeredMethods = if ($authentication) {
                @($authentication.MethodsRegistered)
            }
            else {
                @()
            }

            $systemPreferredMethods = if ($authentication) {
                @(
                    $authentication.
                        SystemPreferredAuthenticationMethods
                )
            }
            else {
                @()
            }

            $isAuthenticationAdmin = if ($authentication) {
                $authentication.IsAdmin
            }
            else {
                $null
            }

            $isPrivileged = (
                $userRoleAssignments.Count -gt 0 -or
                $isAuthenticationAdmin -eq $true
            )

            $attentionReasons = @()

            if ($user.AccountEnabled -ne $true) {
                $attentionReasons += "Account disabled"
            }

            if (-not $authentication) {
                $attentionReasons +=
                    "Authentication report data unavailable"
            }
            else {
                if ($authentication.IsMfaRegistered -ne $true) {
                    $attentionReasons += "MFA not registered"
                }

                if (
                    $isPrivileged -and
                    $authentication.IsMfaRegistered -ne $true
                ) {
                    $attentionReasons +=
                        "Privileged identity without MFA"
                }

                if (
                    $authentication.IsPasswordlessCapable -ne $true
                ) {
                    $attentionReasons +=
                        "Not passwordless capable"
                }

                if (
                    $authentication.IsSsprRegistered -ne $true
                ) {
                    $attentionReasons +=
                        "SSPR not registered"
                }
            }

            if ($deprecatedRoles.Count -gt 0) {
                $attentionReasons +=
                    "Deprecated directory role assigned"
            }

            if ($roleAssignmentsRequiringReview.Count -gt 0) {
                $attentionReasons +=
                    "Directory-role assignment requires review"
            }

            $highestRoleSeverity = if (
                @(
                    $userRoleAssignments |
                        Where-Object { $_.Severity -eq "High" }
                ).Count -gt 0
            ) {
                "High"
            }
            elseif (
                @(
                    $userRoleAssignments |
                        Where-Object { $_.Severity -eq "Medium" }
                ).Count -gt 0
            ) {
                "Medium"
            }
            elseif (
                @(
                    $userRoleAssignments |
                        Where-Object {
                            $_.Severity -eq "Informational"
                        }
                ).Count -gt 0
            ) {
                "Informational"
            }
            else {
                "None"
            }

            [PSCustomObject]@{
                Id                = $user.Id
                DisplayName       = $user.DisplayName
                UserPrincipalName = $user.UserPrincipalName
                UserType          = $user.UserType
                AccountEnabled    = $user.AccountEnabled
                Department        = $user.Department
                JobTitle          = $user.JobTitle
                CompanyName       = $user.CompanyName
                EmployeeId        = $user.EmployeeId
                CreatedDate       = $user.CreatedDate

                IsAdmin = $isAuthenticationAdmin

                IsPrivileged        = $isPrivileged
                PrivilegedRoleCount = $userRoleAssignments.Count
                DirectoryRoles      = $roleNames
                RoleAssignments     = $userRoleAssignments

                HasDeprecatedRole = $deprecatedRoles.Count -gt 0

                DeprecatedRoles = @(
                    $deprecatedRoles |
                        Select-Object -ExpandProperty RoleName -Unique
                )

                RoleAssignmentsRequiringReview =
                    $roleAssignmentsRequiringReview.Count

                HighestRoleSeverity = $highestRoleSeverity

                IsMfaRegistered = if ($authentication) {
                    $authentication.IsMfaRegistered
                }
                else {
                    $null
                }

                IsMfaCapable = if ($authentication) {
                    $authentication.IsMfaCapable
                }
                else {
                    $null
                }

                IsPasswordlessCapable = if ($authentication) {
                    $authentication.IsPasswordlessCapable
                }
                else {
                    $null
                }

                IsSsprRegistered = if ($authentication) {
                    $authentication.IsSsprRegistered
                }
                else {
                    $null
                }

                IsSsprCapable = if ($authentication) {
                    $authentication.IsSsprCapable
                }
                else {
                    $null
                }

                IsSsprEnabled = if ($authentication) {
                    $authentication.IsSsprEnabled
                }
                else {
                    $null
                }

                IsSystemPreferredAuthenticationMethodEnabled =
                    if ($authentication) {
                        $authentication.
                            IsSystemPreferredAuthenticationMethodEnabled
                    }
                    else {
                        $null
                    }

                RegisteredMethods = $registeredMethods

                PreferredSecondaryMethod = if ($authentication) {
                    $authentication.
                        UserPreferredMethodForSecondaryAuthentication
                }
                else {
                    $null
                }

                SystemPreferredMethods = $systemPreferredMethods

                AuthenticationLastUpdated = if ($authentication) {
                    $authentication.LastUpdatedDateTime
                }
                else {
                    $null
                }

                RequiresAttention = $attentionReasons.Count -gt 0

                AttentionReasons = @(
                    $attentionReasons |
                        Select-Object -Unique
                )

                Timestamp = (
                    Get-Date
                ).ToUniversalTime().ToString("o")
            }
        }

        return @($identityGraph)
    }
    catch {
        Write-BKLog -Message $_.Exception.Message -Level Error
        throw
    }
}