function Get-BKDirectoryRoles {
    <#
    .SYNOPSIS
    Collects and resolves active Microsoft Entra directory-role assignments.

    .DESCRIPTION
    Returns normalized active Microsoft Entra directory-role assignments with:

    - Readable role names and descriptions
    - Principal names and principal types
    - Assignment scope
    - Built-in and deprecated-role detection
    - Review severity
    - Review reasons

    This version evaluates active assignments only.
    PIM-eligible assignments should remain a separate correlation layer.

    .PARAMETER SkipGraphConnect
    Skips Microsoft Graph connection handling when called by an orchestrator.
    #>

    [CmdletBinding()]
    param(
        [switch]$SkipGraphConnect
    )

    Write-BKLog `
        -Message "Collecting Microsoft Entra directory-role assignments..." `
        -Level Info

    try {
        if (-not $SkipGraphConnect) {
            Connect-BKGraph -Scopes @(
                "RoleManagement.Read.Directory",
                "Directory.Read.All"
            ) | Out-Null
        }

        # Collect role definitions without forcing optional properties.
        $roleDefinitions = @(
            Get-MgRoleManagementDirectoryRoleDefinition `
                -All `
                -ErrorAction Stop
        )

        # Expand roleDefinition, but do not use -Property because some
        # directory provider responses reject optional selected properties.
        $roleAssignments = @(
            Get-MgRoleManagementDirectoryRoleAssignment `
                -All `
                -ExpandProperty "roleDefinition" `
                -ErrorAction Stop
        )

        # Build a role-definition lookup using both the tenant-specific ID
        # and the service-wide template ID.
        $definitionById = @{}

        foreach ($definition in $roleDefinitions) {
            if ($definition.Id) {
                $definitionById[
                    ([string]$definition.Id).ToLowerInvariant()
                ] = $definition
            }

            if ($definition.TemplateId) {
                $definitionById[
                    ([string]$definition.TemplateId).ToLowerInvariant()
                ] = $definition
            }
        }

        # Resolve every unique principal in one bulk request.
        $principalIds = @(
            $roleAssignments |
                Where-Object { $_.PrincipalId } |
                Select-Object -ExpandProperty PrincipalId -Unique
        )

        $principalById = @{}

        if ($principalIds.Count -gt 0) {
            try {
                $resolvedPrincipals = @(
                    Get-MgDirectoryObjectById `
                        -Ids $principalIds `
                        -ErrorAction Stop
                )

                foreach ($principal in $resolvedPrincipals) {
                    if ($principal.Id) {
                        $principalById[
                            ([string]$principal.Id).ToLowerInvariant()
                        ] = $principal
                    }
                }
            }
            catch {
                Write-BKLog `
                    -Message "Bulk principal resolution failed. Role assignments will continue with unresolved principal metadata. $($_.Exception.Message)" `
                    -Level Warning
            }
        }

        foreach ($assignment in $roleAssignments) {
            $definition = $null

            # Preferred source: expanded relationship.
            if (
                $assignment.RoleDefinition -and
                $assignment.RoleDefinition.DisplayName
            ) {
                $definition = $assignment.RoleDefinition
            }
            elseif ($assignment.RoleDefinitionId) {
                $roleDefinitionKey = (
                    [string]$assignment.RoleDefinitionId
                ).ToLowerInvariant()

                # Secondary source: local definition cache.
                if ($definitionById.ContainsKey($roleDefinitionKey)) {
                    $definition = $definitionById[$roleDefinitionKey]
                }
                else {
                    # Final fallback: direct lookup.
                    try {
                        $definition =
                            Get-MgRoleManagementDirectoryRoleDefinition `
                                -UnifiedRoleDefinitionId $assignment.RoleDefinitionId `
                                -ErrorAction Stop
                    }
                    catch {
                        Write-BKLog `
                            -Message "Unable to resolve role definition $($assignment.RoleDefinitionId)." `
                            -Level Warning
                    }
                }
            }

            $principal = $null

            if ($assignment.PrincipalId) {
                $principalKey = (
                    [string]$assignment.PrincipalId
                ).ToLowerInvariant()

                if ($principalById.ContainsKey($principalKey)) {
                    $principal = $principalById[$principalKey]
                }
            }

            $additionalProperties = if ($principal) {
                $principal.AdditionalProperties
            }
            else {
                $null
            }

            $odataType = if (
                $additionalProperties -and
                $additionalProperties.ContainsKey("@odata.type")
            ) {
                [string]$additionalProperties["@odata.type"]
            }
            else {
                $null
            }

            $principalType = switch -Regex ($odataType) {
                "servicePrincipal$" {
                    "ServicePrincipal"
                    break
                }

                "user$" {
                    "User"
                    break
                }

                "group$" {
                    "Group"
                    break
                }

                default {
                    "Unresolved"
                }
            }

            $principalName = $null

            if (
                $additionalProperties -and
                $additionalProperties.ContainsKey("displayName")
            ) {
                $principalName =
                    [string]$additionalProperties["displayName"]
            }

            if (
                [string]::IsNullOrWhiteSpace($principalName) -and
                $additionalProperties -and
                $additionalProperties.ContainsKey("userPrincipalName")
            ) {
                $principalName =
                    [string]$additionalProperties["userPrincipalName"]
            }

            if (
                [string]::IsNullOrWhiteSpace($principalName) -and
                $additionalProperties -and
                $additionalProperties.ContainsKey("appId")
            ) {
                $principalName =
                    [string]$additionalProperties["appId"]
            }

            if ([string]::IsNullOrWhiteSpace($principalName)) {
                $principalName = [string]$assignment.PrincipalId
            }

            $roleName = if ($definition) {
                [string]$definition.DisplayName
            }
            else {
                "Unknown Role"
            }

            $roleDescription = if ($definition) {
                [string]$definition.Description
            }
            else {
                $null
            }

            $isDeprecated = (
                -not [string]::IsNullOrWhiteSpace($roleDescription) -and
                $roleDescription -match "(?i)deprecated"
            )

            $reviewReasons = @()

            if ($isDeprecated) {
                $reviewReasons += "Deprecated directory role"
            }

            if ($principalType -eq "ServicePrincipal") {
                $reviewReasons += "Role assigned to service principal"
            }

            if ($principalType -eq "Unresolved") {
                $reviewReasons += "Principal type unresolved"
            }

            if ($roleName -eq "Unknown Role") {
                $reviewReasons += "Role definition unresolved"
            }

            $severity = if ($isDeprecated) {
                "High"
            }
            elseif ($principalType -eq "Unresolved") {
                "Medium"
            }
            elseif ($principalType -eq "ServicePrincipal") {
                "Informational"
            }
            else {
                "None"
            }

            [PSCustomObject]@{
                AssignmentId     = $assignment.Id

                PrincipalId      = $assignment.PrincipalId
                PrincipalName    = $principalName
                PrincipalType    = $principalType

                RoleDefinitionId = $assignment.RoleDefinitionId
                RoleName         = $roleName
                RoleDescription  = $roleDescription

                IsBuiltIn = if ($definition) {
                    $definition.IsBuiltIn
                }
                else {
                    $null
                }

                RoleTemplateId = if ($definition) {
                    $definition.TemplateId
                }
                else {
                    $null
                }

                DirectoryScopeId = $assignment.DirectoryScopeId
                AssignmentType   = "Active"

                IsDeprecated      = $isDeprecated
                RequiresReview    = $reviewReasons.Count -gt 0
                Severity          = $severity
                ReviewReasons     = $reviewReasons

                Timestamp = (Get-Date).
                    ToUniversalTime().
                    ToString("o")
            }
        }
    }
    catch {
        Write-BKLog -Message $_.Exception.Message -Level Error
        throw
    }
}