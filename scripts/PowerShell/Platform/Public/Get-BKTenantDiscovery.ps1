function Get-BKTenantDiscovery {
    <#
    .SYNOPSIS
    Discovers and normalizes core Microsoft Entra tenant information.

    .DESCRIPTION
    Collects foundational Microsoft Graph data for the currently connected
    Microsoft Entra tenant.

    The command discovers:

    - Microsoft Graph connection context
    - Organization information
    - Verified domains
    - Subscribed licenses
    - Users
    - Groups
    - Devices
    - Service principals
    - Command and dataset availability
    - Collection warnings and errors

    The command is designed to return partial results when the connected
    identity lacks access to one or more Microsoft Graph datasets.

    This discovery object is intended to become the shared data source for
    Blackknight One Identity, Trust, Governance, and Correlation engines.

    .PARAMETER IncludeObjects
    Includes normalized user, group, device, and service-principal objects in
    the returned result. By default, summary counts are returned without the
    complete object collections.

    .PARAMETER ExportJson
    Exports the discovery result as JSON.

    .PARAMETER OutputPath
    Specifies the destination path for the JSON report.

    .PARAMETER PassThru
    Returns the complete tenant-discovery object.

    .EXAMPLE
    Get-BKTenantDiscovery

    .EXAMPLE
    $Discovery = Get-BKTenantDiscovery `
        -IncludeObjects `
        -ExportJson `
        -PassThru
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$IncludeObjects,

        [Parameter()]
        [switch]$ExportJson,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath =
            ".\reports\graph\tenant-discovery.json",

        [Parameter()]
        [switch]$PassThru
    )

    $ErrorActionPreference = "Stop"

    function Test-BKGraphCommand {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Name
        )

        return $null -ne (
            Get-Command `
                -Name $Name `
                -ErrorAction SilentlyContinue
        )
    }

    function Add-BKGraphCollectionStatus {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [System.Collections.Generic.List[object]]$Collection,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Dataset,

            [Parameter(Mandatory)]
            [ValidateSet(
                "Collected",
                "Unavailable",
                "Failed",
                "Skipped"
            )]
            [string]$Status,

            [Parameter()]
            [int]$Count = 0,

            [Parameter()]
            [AllowNull()]
            [AllowEmptyString()]
            [string]$Command,

            [Parameter()]
            [AllowNull()]
            [AllowEmptyString()]
            [string]$Message
        )

        $null = $Collection.Add(
            [PSCustomObject]@{
                Dataset = $Dataset
                Status  = $Status
                Count   = $Count
                Command = $Command
                Message = $Message
            }
        )
    }

    function Invoke-BKGraphCollection {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Dataset,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$CommandName,

            [Parameter()]
            [hashtable]$Parameters = @{},

            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [System.Collections.Generic.List[object]]$CollectionStatus,

            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [System.Collections.Generic.List[object]]$Warnings
        )

        if (-not (Test-BKGraphCommand -Name $CommandName)) {
            Add-BKGraphCollectionStatus `
                -Collection $CollectionStatus `
                -Dataset $Dataset `
                -Status "Unavailable" `
                -Command $CommandName `
                -Message "Required Microsoft Graph command is not available."

            $null = $Warnings.Add(
                [PSCustomObject]@{
                    Dataset = $Dataset
                    Type    = "CommandUnavailable"
                    Message = "$CommandName is not installed or loaded."
                }
            )

            return @()
        }

        try {
            $items = @(
                & $CommandName @Parameters
            )

            Add-BKGraphCollectionStatus `
                -Collection $CollectionStatus `
                -Dataset $Dataset `
                -Status "Collected" `
                -Count $items.Count `
                -Command $CommandName `
                -Message "Dataset collected successfully."

            return $items
        }
        catch {
            Add-BKGraphCollectionStatus `
                -Collection $CollectionStatus `
                -Dataset $Dataset `
                -Status "Failed" `
                -Command $CommandName `
                -Message $_.Exception.Message

            $null = $Warnings.Add(
                [PSCustomObject]@{
                    Dataset = $Dataset
                    Type    = "CollectionFailure"
                    Message = $_.Exception.Message
                }
            )

            return @()
        }
    }

    function Get-BKCollectionHealth {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [int]$Collected,

            [Parameter(Mandatory)]
            [int]$Failed,

            [Parameter(Mandatory)]
            [int]$Unavailable
        )

        if ($Failed -gt 0) {
            return "Warning"
        }

        if ($Unavailable -gt 0) {
            return "Partial"
        }

        if ($Collected -gt 0) {
            return "Excellent"
        }

        return "Needs Attention"
    }

    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor Cyan
    Write-Host "              BLACKKNIGHT TENANT DISCOVERY" `
        -ForegroundColor Cyan
    Write-Host "============================================================" `
        -ForegroundColor Cyan

    try {
        if (-not (Test-BKGraphCommand -Name "Get-MgContext")) {
            throw (
                "Microsoft Graph PowerShell is not installed or loaded. " +
                "Get-MgContext is unavailable."
            )
        }

        $graphContext = Get-MgContext `
            -ErrorAction SilentlyContinue

        if ($null -eq $graphContext) {
            throw (
                "No active Microsoft Graph connection was found. " +
                "Run Connect-BKGraph or use dashboard option 2 first."
            )
        }

        if (
            [string]::IsNullOrWhiteSpace(
                [string]$graphContext.TenantId
            )
        ) {
            throw "The active Microsoft Graph context has no tenant ID."
        }

        Write-Host ""
        Write-Host "Connected Tenant" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"
        Write-Host "Account      : $($graphContext.Account)"
        Write-Host "Tenant ID    : $($graphContext.TenantId)"
        Write-Host "Environment  : $($graphContext.Environment)"
        Write-Host "Auth Type    : $($graphContext.AuthType)"

        $collectionStatus =
            [System.Collections.Generic.List[object]]::new()

        $warnings =
            [System.Collections.Generic.List[object]]::new()

        #
        # Core tenant data
        #

        Write-Host ""
        Write-Host "Collecting organization information..." `
            -ForegroundColor Yellow

        $organizations = Invoke-BKGraphCollection `
            -Dataset "Organization" `
            -CommandName "Get-MgOrganization" `
            -CollectionStatus $collectionStatus `
            -Warnings $warnings

        Write-Host "Collecting domains..." `
            -ForegroundColor Yellow

        $domains = Invoke-BKGraphCollection `
            -Dataset "Domains" `
            -CommandName "Get-MgDomain" `
            -Parameters @{
                All = $true
            } `
            -CollectionStatus $collectionStatus `
            -Warnings $warnings

        Write-Host "Collecting subscribed licenses..." `
            -ForegroundColor Yellow

        $subscribedSkus = Invoke-BKGraphCollection `
            -Dataset "Licenses" `
            -CommandName "Get-MgSubscribedSku" `
            -Parameters @{
                All = $true
            } `
            -CollectionStatus $collectionStatus `
            -Warnings $warnings

        #
        # Directory objects
        #

        Write-Host "Collecting users..." `
            -ForegroundColor Yellow

        $users = Invoke-BKGraphCollection `
            -Dataset "Users" `
            -CommandName "Get-MgUser" `
            -Parameters @{
                All      = $true
                Property = @(
                    "id"
                    "displayName"
                    "userPrincipalName"
                    "userType"
                    "accountEnabled"
                    "createdDateTime"
                    "onPremisesSyncEnabled"
                )
            } `
            -CollectionStatus $collectionStatus `
            -Warnings $warnings

        Write-Host "Collecting groups..." `
            -ForegroundColor Yellow

        $groups = Invoke-BKGraphCollection `
            -Dataset "Groups" `
            -CommandName "Get-MgGroup" `
            -Parameters @{
                All      = $true
                Property = @(
                    "id"
                    "displayName"
                    "description"
                    "groupTypes"
                    "mailEnabled"
                    "securityEnabled"
                    "isAssignableToRole"
                    "membershipRule"
                    "createdDateTime"
                )
            } `
            -CollectionStatus $collectionStatus `
            -Warnings $warnings

        Write-Host "Collecting devices..." `
            -ForegroundColor Yellow

        $devices = Invoke-BKGraphCollection `
            -Dataset "Devices" `
            -CommandName "Get-MgDevice" `
            -Parameters @{
                All      = $true
                Property = @(
                    "id"
                    "displayName"
                    "accountEnabled"
                    "operatingSystem"
                    "operatingSystemVersion"
                    "trustType"
                    "isCompliant"
                    "isManaged"
                    "approximateLastSignInDateTime"
                )
            } `
            -CollectionStatus $collectionStatus `
            -Warnings $warnings

        Write-Host "Collecting service principals..." `
            -ForegroundColor Yellow

        $servicePrincipals = Invoke-BKGraphCollection `
            -Dataset "ServicePrincipals" `
            -CommandName "Get-MgServicePrincipal" `
            -Parameters @{
                All      = $true
                Property = @(
                    "id"
                    "appId"
                    "displayName"
                    "servicePrincipalType"
                    "accountEnabled"
                    "appOwnerOrganizationId"
                    "createdDateTime"
                )
            } `
            -CollectionStatus $collectionStatus `
            -Warnings $warnings

        #
        # Normalize organization
        #

        $organization = $organizations |
            Select-Object -First 1

        $normalizedOrganization = if ($null -ne $organization) {
            [PSCustomObject]@{
                Id                  = [string]$organization.Id
                DisplayName         = [string]$organization.DisplayName
                TenantType          = [string]$organization.TenantType
                CountryLetterCode   = [string]$organization.CountryLetterCode
                PreferredLanguage   = [string]$organization.PreferredLanguage
                OnPremisesSyncEnabled = (
                    [bool]$organization.OnPremisesSyncEnabled
                )
                CreatedDateTime     = $organization.CreatedDateTime
                VerifiedDomains     = @(
                    $organization.VerifiedDomains
                )
            }
        }
        else {
            $null
        }

        #
        # Normalize domains
        #

        $normalizedDomains = @(
            foreach ($domain in $domains) {
                [PSCustomObject]@{
                    Id                    = [string]$domain.Id
                    IsDefault             = [bool]$domain.IsDefault
                    IsInitial             = [bool]$domain.IsInitial
                    IsVerified            = [bool]$domain.IsVerified
                    AuthenticationType    = [string]$domain.AuthenticationType
                    AvailabilityStatus    = [string]$domain.AvailabilityStatus
                    SupportedServices     = @($domain.SupportedServices)
                }
            }
        )

        #
        # Normalize licensing
        #

        $normalizedLicenses = @(
            foreach ($sku in $subscribedSkus) {
                $enabledUnits = 0
                $suspendedUnits = 0
                $warningUnits = 0

                if ($null -ne $sku.PrepaidUnits) {
                    $enabledUnits =
                        [int]$sku.PrepaidUnits.Enabled

                    $suspendedUnits =
                        [int]$sku.PrepaidUnits.Suspended

                    $warningUnits =
                        [int]$sku.PrepaidUnits.Warning
                }

                [PSCustomObject]@{
                    SkuId           = [string]$sku.SkuId
                    SkuPartNumber   = [string]$sku.SkuPartNumber
                    CapabilityStatus = [string]$sku.CapabilityStatus
                    ConsumedUnits   = [int]$sku.ConsumedUnits
                    EnabledUnits    = $enabledUnits
                    SuspendedUnits  = $suspendedUnits
                    WarningUnits    = $warningUnits
                    AvailableUnits  = [math]::Max(
                        0,
                        $enabledUnits - [int]$sku.ConsumedUnits
                    )
                    ServicePlans    = @($sku.ServicePlans)
                }
            }
        )

        #
        # Normalize object summaries
        #

        $enabledUsers = @(
            $users |
                Where-Object {
                    $_.AccountEnabled -eq $true
                }
        ).Count

        $disabledUsers = @(
            $users |
                Where-Object {
                    $_.AccountEnabled -eq $false
                }
        ).Count

        $guestUsers = @(
            $users |
                Where-Object {
                    $_.UserType -eq "Guest"
                }
        ).Count

        $memberUsers = @(
            $users |
                Where-Object {
                    $_.UserType -eq "Member"
                }
        ).Count

        $securityGroups = @(
            $groups |
                Where-Object {
                    $_.SecurityEnabled -eq $true
                }
        ).Count

        $microsoft365Groups = @(
            $groups |
                Where-Object {
                    $_.GroupTypes -contains "Unified"
                }
        ).Count

        $dynamicGroups = @(
            $groups |
                Where-Object {
                    $_.GroupTypes -contains "DynamicMembership"
                }
        ).Count

        $roleAssignableGroups = @(
            $groups |
                Where-Object {
                    $_.IsAssignableToRole -eq $true
                }
        ).Count

        $enabledDevices = @(
            $devices |
                Where-Object {
                    $_.AccountEnabled -eq $true
                }
        ).Count

        $managedDevices = @(
            $devices |
                Where-Object {
                    $_.IsManaged -eq $true
                }
        ).Count

        $compliantDevices = @(
            $devices |
                Where-Object {
                    $_.IsCompliant -eq $true
                }
        ).Count

        $enabledServicePrincipals = @(
            $servicePrincipals |
                Where-Object {
                    $_.AccountEnabled -eq $true
                }
        ).Count

        #
        # Collection health
        #

        $collectedDatasets = @(
            $collectionStatus |
                Where-Object {
                    $_.Status -eq "Collected"
                }
        ).Count

        $failedDatasets = @(
            $collectionStatus |
                Where-Object {
                    $_.Status -eq "Failed"
                }
        ).Count

        $unavailableDatasets = @(
            $collectionStatus |
                Where-Object {
                    $_.Status -eq "Unavailable"
                }
        ).Count

        $collectionHealth = Get-BKCollectionHealth `
            -Collected $collectedDatasets `
            -Failed $failedDatasets `
            -Unavailable $unavailableDatasets

        $confidence = if ($collectionStatus.Count -gt 0) {
            [math]::Round(
                (
                    $collectedDatasets /
                    $collectionStatus.Count
                ) * 100,
                2
            )
        }
        else {
            0
        }

        $result = [PSCustomObject]@{
            Platform    = "Blackknight One"
            Engine      = "MicrosoftGraph"
            Operation   = "TenantDiscovery"
            GeneratedAt = (
                Get-Date
            ).ToUniversalTime().ToString("o")

            Context = [PSCustomObject]@{
                Account      = [string]$graphContext.Account
                TenantId     = [string]$graphContext.TenantId
                Environment  = [string]$graphContext.Environment
                AuthType     = [string]$graphContext.AuthType
                ContextScope = [string]$graphContext.ContextScope
                Scopes       = @($graphContext.Scopes)
            }

            Summary = [PSCustomObject]@{
                Health                    = $collectionHealth
                Confidence                = $confidence
                OrganizationName          = if ($organization) {
                    [string]$organization.DisplayName
                }
                else {
                    $null
                }
                TenantId                  = [string]$graphContext.TenantId
                Domains                   = $domains.Count
                VerifiedDomains           = @(
                    $domains |
                        Where-Object {
                            $_.IsVerified -eq $true
                        }
                ).Count
                SubscribedSkus            = $subscribedSkus.Count
                Users                     = $users.Count
                EnabledUsers              = $enabledUsers
                DisabledUsers             = $disabledUsers
                MemberUsers               = $memberUsers
                GuestUsers                = $guestUsers
                Groups                    = $groups.Count
                SecurityGroups            = $securityGroups
                Microsoft365Groups        = $microsoft365Groups
                DynamicGroups             = $dynamicGroups
                RoleAssignableGroups      = $roleAssignableGroups
                Devices                   = $devices.Count
                EnabledDevices            = $enabledDevices
                ManagedDevices            = $managedDevices
                CompliantDevices          = $compliantDevices
                ServicePrincipals         = $servicePrincipals.Count
                EnabledServicePrincipals  = $enabledServicePrincipals
                CollectedDatasets         = $collectedDatasets
                FailedDatasets            = $failedDatasets
                UnavailableDatasets       = $unavailableDatasets
                WarningCount              = $warnings.Count
            }

            Organization = $normalizedOrganization
            Domains      = $normalizedDomains
            Licenses     = $normalizedLicenses

            Objects = if ($IncludeObjects.IsPresent) {
                [PSCustomObject]@{
                    Users = @(
                        foreach ($user in $users) {
                            [PSCustomObject]@{
                                Id                     = [string]$user.Id
                                DisplayName            = [string]$user.DisplayName
                                UserPrincipalName      = [string]$user.UserPrincipalName
                                UserType               = [string]$user.UserType
                                AccountEnabled         = [bool]$user.AccountEnabled
                                CreatedDateTime        = $user.CreatedDateTime
                                OnPremisesSyncEnabled  = $user.OnPremisesSyncEnabled
                            }
                        }
                    )

                    Groups = @(
                        foreach ($group in $groups) {
                            [PSCustomObject]@{
                                Id                 = [string]$group.Id
                                DisplayName        = [string]$group.DisplayName
                                Description        = [string]$group.Description
                                GroupTypes         = @($group.GroupTypes)
                                MailEnabled        = [bool]$group.MailEnabled
                                SecurityEnabled    = [bool]$group.SecurityEnabled
                                IsAssignableToRole = [bool]$group.IsAssignableToRole
                                MembershipRule     = [string]$group.MembershipRule
                                CreatedDateTime    = $group.CreatedDateTime
                            }
                        }
                    )

                    Devices = @(
                        foreach ($device in $devices) {
                            [PSCustomObject]@{
                                Id                            = [string]$device.Id
                                DisplayName                   = [string]$device.DisplayName
                                AccountEnabled                = [bool]$device.AccountEnabled
                                OperatingSystem               = [string]$device.OperatingSystem
                                OperatingSystemVersion        = [string]$device.OperatingSystemVersion
                                TrustType                      = [string]$device.TrustType
                                IsCompliant                    = $device.IsCompliant
                                IsManaged                      = $device.IsManaged
                                ApproximateLastSignInDateTime  = (
                                    $device.ApproximateLastSignInDateTime
                                )
                            }
                        }
                    )

                    ServicePrincipals = @(
                        foreach (
                            $servicePrincipal in
                            $servicePrincipals
                        ) {
                            [PSCustomObject]@{
                                Id                     = (
                                    [string]$servicePrincipal.Id
                                )
                                AppId                  = (
                                    [string]$servicePrincipal.AppId
                                )
                                DisplayName            = (
                                    [string]$servicePrincipal.DisplayName
                                )
                                ServicePrincipalType   = (
                                    [string]$servicePrincipal.ServicePrincipalType
                                )
                                AccountEnabled         = (
                                    [bool]$servicePrincipal.AccountEnabled
                                )
                                AppOwnerOrganizationId = (
                                    [string]$servicePrincipal.AppOwnerOrganizationId
                                )
                                CreatedDateTime        = (
                                    $servicePrincipal.CreatedDateTime
                                )
                            }
                        }
                    )
                }
            }
            else {
                $null
            }

            CollectionStatus = @($collectionStatus)
            Warnings         = @($warnings)
        }

        Write-Host ""
        Write-Host "Tenant Discovery Summary" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"
        Write-Host "Organization          : $($result.Summary.OrganizationName)"
        Write-Host "Tenant ID             : $($result.Summary.TenantId)"
        Write-Host "Domains               : $($result.Summary.Domains)"
        Write-Host "Subscribed SKUs       : $($result.Summary.SubscribedSkus)"
        Write-Host "Users                 : $($result.Summary.Users)"
        Write-Host "Groups                : $($result.Summary.Groups)"
        Write-Host "Devices               : $($result.Summary.Devices)"
        Write-Host "Service Principals    : $($result.Summary.ServicePrincipals)"
        Write-Host "Collected Datasets    : $collectedDatasets"
        Write-Host "Failed Datasets       : $failedDatasets"
        Write-Host "Unavailable Datasets  : $unavailableDatasets"
        Write-Host "Discovery Confidence  : $confidence%"
        Write-Host "Discovery Health      : $collectionHealth"

        if ($warnings.Count -gt 0) {
            Write-Host ""
            Write-Host "Collection Warnings" `
                -ForegroundColor DarkYellow
            Write-Host "------------------------------------------------------------"

            $warnings |
                Select-Object `
                    Dataset,
                    Type,
                    Message |
                Format-Table -Wrap -AutoSize |
                Out-Host
        }

        if ($ExportJson.IsPresent) {
            $outputDirectory = Split-Path `
                -Path $OutputPath `
                -Parent

            if (
                -not [string]::IsNullOrWhiteSpace(
                    $outputDirectory
                ) -and
                -not (
                    Test-Path `
                        -LiteralPath $outputDirectory
                )
            ) {
                New-Item `
                    -Path $outputDirectory `
                    -ItemType Directory `
                    -Force |
                    Out-Null
            }

            $result |
                ConvertTo-Json `
                    -Depth 40 |
                Set-Content `
                    -LiteralPath $OutputPath `
                    -Encoding utf8

            Write-Host ""
            Write-Host (
                "[Success] Exported tenant discovery to $OutputPath"
            ) -ForegroundColor Green
        }

        Write-Host ""
        Write-Host "============================================================" `
            -ForegroundColor Cyan

        if ($PassThru.IsPresent) {
            return $result
        }
    }
    catch {
        if (
            Test-BKGraphCommand `
                -Name "Write-BKLog"
        ) {
            Write-BKLog `
                -Message $_.Exception.Message `
                -Level Error
        }
        else {
            Write-Error $_.Exception.Message
        }

        throw
    }
}