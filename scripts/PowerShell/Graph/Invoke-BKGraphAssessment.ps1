[CmdletBinding()]
param(
    [Parameter()]
    [switch]$IncludeObjects,

    [Parameter()]
    [switch]$ExportJson,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath =
        ".\reports\graph\graph-assessment.json",

    [Parameter()]
    [switch]$PassThru
)

$ErrorActionPreference = "Stop"

function Add-BKGraphAssessmentFinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Collection,

        [Parameter(Mandatory)]
        [ValidateSet(
            "Informational",
            "Low",
            "Medium",
            "High",
            "Critical"
        )]
        [string]$Severity,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Category,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Details,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Resource,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Recommendation
    )

    $finding = [PSCustomObject]@{
        Severity       = $Severity
        Category       = $Category
        Title          = $Title
        Details        = $Details
        Resource       = $Resource
        Recommendation = $Recommendation
    }

    $null = $Collection.Add($finding)
}

function Add-BKGraphRecommendation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$Collection,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Recommendation
    )

    if (
        -not [string]::IsNullOrWhiteSpace(
            $Recommendation
        )
    ) {
        $null = $Collection.Add($Recommendation)
    }
}

function Get-BKGraphAssessmentHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [double]$Confidence,

        [Parameter(Mandatory)]
        [int]$CriticalFindings,

        [Parameter(Mandatory)]
        [int]$HighFindings
    )

    if ($CriticalFindings -gt 0) {
        return "Needs Attention"
    }

    if ($HighFindings -gt 0) {
        return "Warning"
    }

    if ($Confidence -ge 98) {
        return "Excellent"
    }

    if ($Confidence -ge 90) {
        return "Healthy"
    }

    if ($Confidence -ge 75) {
        return "Warning"
    }

    return "Needs Attention"
}

function Get-BKGraphAssessmentResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Output
    )

    return (
        $Output |
            Where-Object {
                $null -ne $_ -and
                $null -ne $_.PSObject -and
                $_.PSObject.Properties.Name -contains "Operation" -and
                $_.Operation -eq "TenantDiscovery"
            } |
            Select-Object -Last 1
    )
}

function Test-BKGraphScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Scopes,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$RequiredScopes
    )

    foreach ($requiredScope in $RequiredScopes) {
        if ($Scopes -contains $requiredScope) {
            return $true
        }
    }

    return $false
}

function Get-BKSeverityWeight {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet(
            "Informational",
            "Low",
            "Medium",
            "High",
            "Critical"
        )]
        [string]$Severity
    )

    switch ($Severity) {
        "Critical" {
            return 5
        }

        "High" {
            return 4
        }

        "Medium" {
            return 3
        }

        "Low" {
            return 2
        }

        default {
            return 1
        }
    }
}

Write-Host ""
Write-Host "============================================================" `
    -ForegroundColor Cyan
Write-Host "            BLACKKNIGHT GRAPH ASSESSMENT" `
    -ForegroundColor Cyan
Write-Host "============================================================" `
    -ForegroundColor Cyan

try {
    if (
        -not (
            Get-Command `
                -Name "Get-BKTenantDiscovery" `
                -ErrorAction SilentlyContinue
        )
    ) {
        throw (
            "Get-BKTenantDiscovery is unavailable. " +
            "Import the Blackknight Platform module first."
        )
    }

    if (
        -not (
            Get-Command `
                -Name "Get-MgContext" `
                -ErrorAction SilentlyContinue
        )
    ) {
        throw (
            "Microsoft Graph PowerShell is unavailable. " +
            "Get-MgContext could not be found."
        )
    }

    $graphContext = Get-MgContext `
        -ErrorAction SilentlyContinue

    if ($null -eq $graphContext) {
        throw (
            "No active Microsoft Graph connection was found. " +
            "Connect to the target tenant before running the assessment."
        )
    }

    if (
        [string]::IsNullOrWhiteSpace(
            [string]$graphContext.TenantId
        )
    ) {
        throw "The active Graph context does not contain a tenant ID."
    }

    Write-Host ""
    Write-Host "Target Tenant" `
        -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------"
    Write-Host "Account      : $($graphContext.Account)"
    Write-Host "Tenant ID    : $($graphContext.TenantId)"
    Write-Host "Environment  : $($graphContext.Environment)"
    Write-Host "Auth Type    : $($graphContext.AuthType)"

    $findings =
        [System.Collections.Generic.List[object]]::new()

    $recommendations =
        [System.Collections.Generic.List[string]]::new()

    #
    # Phase 1: Tenant discovery
    #

    Write-Host ""
    Write-Host "Phase 1 of 3: Tenant discovery" `
        -ForegroundColor Yellow

    $discoveryOutput = @(
        Get-BKTenantDiscovery `
            -IncludeObjects:$IncludeObjects `
            -PassThru
    )

    $discovery =
        Get-BKGraphAssessmentResult `
            -Output $discoveryOutput

    if ($null -eq $discovery) {
        $discovery = $discoveryOutput |
            Where-Object {
                $null -ne $_ -and
                $null -ne $_.Summary -and
                $_.Summary.PSObject.Properties.Name -contains
                "CollectedDatasets"
            } |
            Select-Object -Last 1
    }

    if ($null -eq $discovery) {
        throw (
            "Tenant discovery did not return a valid " +
            "Blackknight discovery object."
        )
    }

    #
    # Phase 2: Collection and permission assessment
    #

    Write-Host ""
    Write-Host "Phase 2 of 3: Dataset and permission assessment" `
        -ForegroundColor Yellow

    $collectionStatus = @(
        $discovery.CollectionStatus
    )

    $failedDatasets = @(
        $collectionStatus |
            Where-Object {
                $_.Status -eq "Failed"
            }
    )

    $unavailableDatasets = @(
        $collectionStatus |
            Where-Object {
                $_.Status -eq "Unavailable"
            }
    )

    foreach ($dataset in $failedDatasets) {
        Add-BKGraphAssessmentFinding `
            -Collection $findings `
            -Severity "High" `
            -Category "DataCollection" `
            -Title "Graph dataset collection failed: $($dataset.Dataset)" `
            -Details ([string]$dataset.Message) `
            -Resource ([string]$dataset.Command) `
            -Recommendation (
                "Review Graph permissions, module availability, and " +
                "the reported collection error."
            )
    }

    foreach ($dataset in $unavailableDatasets) {
        Add-BKGraphAssessmentFinding `
            -Collection $findings `
            -Severity "Medium" `
            -Category "Capability" `
            -Title "Graph dataset unavailable: $($dataset.Dataset)" `
            -Details ([string]$dataset.Message) `
            -Resource ([string]$dataset.Command) `
            -Recommendation (
                "Install or load the Microsoft Graph module that provides " +
                "the required command."
            )
    }

    $currentScopes = @(
        $discovery.Context.Scopes |
            ForEach-Object {
                [string]$_
            }
    )

    $scopeChecks = @(
        [PSCustomObject]@{
            Capability = "Organization and domains"
            Required   = @(
                "Organization.Read.All"
                "Directory.Read.All"
            )
            Severity   = "High"
        }

        [PSCustomObject]@{
            Capability = "Users"
            Required   = @(
                "User.Read.All"
                "Directory.Read.All"
            )
            Severity   = "High"
        }

        [PSCustomObject]@{
            Capability = "Groups"
            Required   = @(
                "Group.Read.All"
                "Directory.Read.All"
            )
            Severity   = "High"
        }

        [PSCustomObject]@{
            Capability = "Devices"
            Required   = @(
                "Device.Read.All"
                "Directory.Read.All"
            )
            Severity   = "Medium"
        }

        [PSCustomObject]@{
            Capability = "Applications and service principals"
            Required   = @(
                "Application.Read.All"
                "Directory.Read.All"
            )
            Severity   = "High"
        }

        [PSCustomObject]@{
            Capability = "Licensing"
            Required   = @(
                "Organization.Read.All"
                "Directory.Read.All"
            )
            Severity   = "Medium"
        }
    )

    foreach ($scopeCheck in $scopeChecks) {
        $scopeAvailable =
            Test-BKGraphScope `
                -Scopes $currentScopes `
                -RequiredScopes $scopeCheck.Required

        if (-not $scopeAvailable) {
            Add-BKGraphAssessmentFinding `
                -Collection $findings `
                -Severity $scopeCheck.Severity `
                -Category "Permissions" `
                -Title "Graph scope coverage missing: $($scopeCheck.Capability)" `
                -Details (
                    "The active Graph context does not contain one of the " +
                    "expected delegated scopes: " +
                    ($scopeCheck.Required -join ", ")
                ) `
                -Resource ([string]$graphContext.Account) `
                -Recommendation (
                    "Reconnect using the least-privileged Graph scope that " +
                    "supports this capability."
                )
        }
    }

    #
    # Phase 3: Tenant inventory assessment
    #

    Write-Host ""
    Write-Host "Phase 3 of 3: Tenant inventory assessment" `
        -ForegroundColor Yellow

    if (
        [string]::IsNullOrWhiteSpace(
            [string]$discovery.Summary.OrganizationName
        )
    ) {
        Add-BKGraphAssessmentFinding `
            -Collection $findings `
            -Severity "High" `
            -Category "Organization" `
            -Title "Organization information was not collected" `
            -Details (
                "The Graph assessment could not determine the tenant " +
                "organization name."
            ) `
            -Resource ([string]$discovery.Summary.TenantId) `
            -Recommendation (
                "Verify Organization.Read.All or Directory.Read.All access."
            )
    }

    if ([int]$discovery.Summary.Domains -eq 0) {
        Add-BKGraphAssessmentFinding `
            -Collection $findings `
            -Severity "High" `
            -Category "Domains" `
            -Title "No tenant domains were discovered" `
            -Details (
                "The tenant discovery result contains no domain records."
            ) `
            -Resource ([string]$discovery.Summary.TenantId) `
            -Recommendation (
                "Verify domain discovery permissions and Graph connectivity."
            )
    }

    if (
        [int]$discovery.Summary.Domains -gt 0 -and
        [int]$discovery.Summary.VerifiedDomains -eq 0
    ) {
        Add-BKGraphAssessmentFinding `
            -Collection $findings `
            -Severity "High" `
            -Category "Domains" `
            -Title "No verified tenant domains were identified" `
            -Details (
                "Domains were returned, but none were reported as verified."
            ) `
            -Resource ([string]$discovery.Summary.TenantId) `
            -Recommendation (
                "Review tenant domain verification and Graph domain data."
            )
    }

    if ([int]$discovery.Summary.SubscribedSkus -eq 0) {
        Add-BKGraphAssessmentFinding `
            -Collection $findings `
            -Severity "Medium" `
            -Category "Licensing" `
            -Title "No subscribed Microsoft licenses were discovered" `
            -Details (
                "The licensing dataset returned no subscribed SKUs."
            ) `
            -Resource ([string]$discovery.Summary.TenantId) `
            -Recommendation (
                "Verify licensing visibility and Organization.Read.All access."
            )
    }

    if ([int]$discovery.Summary.Users -eq 0) {
        Add-BKGraphAssessmentFinding `
            -Collection $findings `
            -Severity "High" `
            -Category "Users" `
            -Title "No users were discovered" `
            -Details (
                "The tenant discovery result contains no user objects."
            ) `
            -Resource ([string]$discovery.Summary.TenantId) `
            -Recommendation (
                "Verify User.Read.All or Directory.Read.All access."
            )
    }

    if ([int]$discovery.Summary.DisabledUsers -gt 0) {
        Add-BKGraphAssessmentFinding `
            -Collection $findings `
            -Severity "Informational" `
            -Category "Users" `
            -Title "Disabled accounts identified" `
            -Details (
                "$($discovery.Summary.DisabledUsers) disabled user accounts " +
                "were discovered."
            ) `
            -Resource ([string]$discovery.Summary.TenantId) `
            -Recommendation (
                "Review disabled accounts for retention, ownership, and " +
                "deprovisioning requirements."
            )
    }

    if ([int]$discovery.Summary.GuestUsers -gt 0) {
        Add-BKGraphAssessmentFinding `
            -Collection $findings `
            -Severity "Low" `
            -Category "ExternalIdentity" `
            -Title "Guest identities present" `
            -Details (
                "$($discovery.Summary.GuestUsers) guest users were discovered."
            ) `
            -Resource ([string]$discovery.Summary.TenantId) `
            -Recommendation (
                "Review guest ownership, recent activity, sponsorship, and " +
                "access-review coverage."
            )
    }

    if ([int]$discovery.Summary.RoleAssignableGroups -gt 0) {
        Add-BKGraphAssessmentFinding `
            -Collection $findings `
            -Severity "Medium" `
            -Category "PrivilegedAccess" `
            -Title "Role-assignable groups identified" `
            -Details (
                "$($discovery.Summary.RoleAssignableGroups) role-assignable " +
                "groups were discovered."
            ) `
            -Resource ([string]$discovery.Summary.TenantId) `
            -Recommendation (
                "Review privileged group ownership, membership, PIM coverage, " +
                "and change control."
            )
    }

    if (
        [int]$discovery.Summary.Devices -gt 0 -and
        [int]$discovery.Summary.ManagedDevices -eq 0
    ) {
        Add-BKGraphAssessmentFinding `
            -Collection $findings `
            -Severity "Medium" `
            -Category "Devices" `
            -Title "No managed devices were identified" `
            -Details (
                "$($discovery.Summary.Devices) directory devices were found, " +
                "but none were reported as managed."
            ) `
            -Resource ([string]$discovery.Summary.TenantId) `
            -Recommendation (
                "Review Intune enrollment, device management, and Graph " +
                "device-property visibility."
            )
    }

    if ([int]$discovery.Summary.ServicePrincipals -eq 0) {
        Add-BKGraphAssessmentFinding `
            -Collection $findings `
            -Severity "High" `
            -Category "Applications" `
            -Title "No service principals were discovered" `
            -Details (
                "The tenant discovery result contains no service principals."
            ) `
            -Resource ([string]$discovery.Summary.TenantId) `
            -Recommendation (
                "Verify Application.Read.All or Directory.Read.All access."
            )
    }

    #
    # Recommendations from findings
    #

    foreach ($finding in $findings) {
        Add-BKGraphRecommendation `
            -Collection $recommendations `
            -Recommendation ([string]$finding.Recommendation)
    }

    #
    # Scoring
    #

    $datasetScore = if (
        $null -ne $discovery.Summary.Confidence
    ) {
        [double]$discovery.Summary.Confidence
    }
    else {
        0
    }

    $scopeChecksPassed = 0

    foreach ($scopeCheck in $scopeChecks) {
        if (
            Test-BKGraphScope `
                -Scopes $currentScopes `
                -RequiredScopes $scopeCheck.Required
        ) {
            $scopeChecksPassed++
        }
    }

    $permissionScore = if ($scopeChecks.Count -gt 0) {
        [math]::Round(
            (
                $scopeChecksPassed /
                $scopeChecks.Count
            ) * 100,
            2
        )
    }
    else {
        0
    }

    $inventoryChecks = 6
    $inventoryChecksPassed = 0

    if (
        -not [string]::IsNullOrWhiteSpace(
            [string]$discovery.Summary.OrganizationName
        )
    ) {
        $inventoryChecksPassed++
    }

    if ([int]$discovery.Summary.Domains -gt 0) {
        $inventoryChecksPassed++
    }

    if ([int]$discovery.Summary.Users -gt 0) {
        $inventoryChecksPassed++
    }

    if ([int]$discovery.Summary.Groups -gt 0) {
        $inventoryChecksPassed++
    }

    if ([int]$discovery.Summary.Devices -ge 0) {
        $inventoryChecksPassed++
    }

    if ([int]$discovery.Summary.ServicePrincipals -gt 0) {
        $inventoryChecksPassed++
    }

    $inventoryScore = [math]::Round(
        (
            $inventoryChecksPassed /
            $inventoryChecks
        ) * 100,
        2
    )

    $criticalFindings = @(
        $findings |
            Where-Object {
                $_.Severity -eq "Critical"
            }
    )

    $highFindings = @(
        $findings |
            Where-Object {
                $_.Severity -eq "High"
            }
    )

    $mediumFindings = @(
        $findings |
            Where-Object {
                $_.Severity -eq "Medium"
            }
    )

    $lowFindings = @(
        $findings |
            Where-Object {
                $_.Severity -eq "Low"
            }
    )

    $informationalFindings = @(
        $findings |
            Where-Object {
                $_.Severity -eq "Informational"
            }
    )

    $findingPenalty =
        ($criticalFindings.Count * 25) +
        ($highFindings.Count * 10) +
        ($mediumFindings.Count * 3) +
        ($lowFindings.Count * 1)

    if ($findingPenalty -gt 100) {
        $findingPenalty = 100
    }

    $baseConfidence = [math]::Round(
        (
            ($datasetScore * 0.45) +
            ($permissionScore * 0.30) +
            ($inventoryScore * 0.25)
        ),
        2
    )

    $assessmentConfidence = [math]::Max(
        0,
        [math]::Round(
            $baseConfidence - $findingPenalty,
            2
        )
    )

    $assessmentHealth =
        Get-BKGraphAssessmentHealth `
            -Confidence $assessmentConfidence `
            -CriticalFindings $criticalFindings.Count `
            -HighFindings $highFindings.Count

    if ($criticalFindings.Count -gt 0) {
        $assessmentDecision = "Blocked"
        $assessmentReason =
            "Critical Graph assessment findings must be resolved."
    }
    elseif ($highFindings.Count -gt 0) {
        $assessmentDecision = "Review Required"
        $assessmentReason =
            "High-severity Graph collection or visibility findings require review."
    }
    elseif ($mediumFindings.Count -gt 0) {
        $assessmentDecision = "Conditional Pass"
        $assessmentReason =
            "Core Graph discovery completed, but medium findings should be reviewed."
    }
    else {
        $assessmentDecision = "Pass"
        $assessmentReason =
            "Microsoft Graph discovery passed the current assessment gates."
    }

    $sortedFindings = @(
        $findings |
            Sort-Object `
                @{
                    Expression = {
                        Get-BKSeverityWeight `
                            -Severity $_.Severity
                    }
                    Descending = $true
                },
                Category,
                Title
    )

    $result = [PSCustomObject]@{
        Platform    = "Blackknight One"
        Engine      = "MicrosoftGraph"
        Operation   = "GraphAssessment"
        GeneratedAt = (
            Get-Date
        ).ToUniversalTime().ToString("o")

        Tenant = [PSCustomObject]@{
            TenantId         = [string]$discovery.Summary.TenantId
            OrganizationName = [string]$discovery.Summary.OrganizationName
            Account          = [string]$discovery.Context.Account
            Environment      = [string]$discovery.Context.Environment
            AuthType         = [string]$discovery.Context.AuthType
        }

        Summary = [PSCustomObject]@{
            Status                 = "Complete"
            Health                 = $assessmentHealth
            Confidence             = $assessmentConfidence
            AssessmentDecision     = $assessmentDecision
            AssessmentReason       = $assessmentReason
            TotalFindings          = $findings.Count
            CriticalFindings       = $criticalFindings.Count
            HighFindings           = $highFindings.Count
            MediumFindings         = $mediumFindings.Count
            LowFindings            = $lowFindings.Count
            InformationalFindings  = $informationalFindings.Count
            CollectedDatasets      = [int]$discovery.Summary.CollectedDatasets
            FailedDatasets         = [int]$discovery.Summary.FailedDatasets
            UnavailableDatasets    = [int]$discovery.Summary.UnavailableDatasets
            Users                  = [int]$discovery.Summary.Users
            Groups                 = [int]$discovery.Summary.Groups
            Devices                = [int]$discovery.Summary.Devices
            ServicePrincipals      = [int]$discovery.Summary.ServicePrincipals
            GuestUsers             = [int]$discovery.Summary.GuestUsers
            DisabledUsers          = [int]$discovery.Summary.DisabledUsers
            RoleAssignableGroups   = [int]$discovery.Summary.RoleAssignableGroups
        }

        Scores = [PSCustomObject]@{
            DatasetCompleteness = $datasetScore
            PermissionCoverage  = $permissionScore
            InventoryCoverage   = $inventoryScore
            FindingPenalty      = $findingPenalty
            Overall             = $assessmentConfidence
        }

        Discovery      = $discovery
        Findings       = $sortedFindings
        Recommendations = @(
            $recommendations |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace(
                        [string]$_
                    )
                } |
                Sort-Object -Unique
        )
    }

    Write-Host ""
    Write-Host "Graph Assessment Summary" `
        -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------"
    Write-Host "Organization          : $($result.Tenant.OrganizationName)"
    Write-Host "Tenant ID             : $($result.Tenant.TenantId)"
    Write-Host "Dataset Score         : $datasetScore%"
    Write-Host "Permission Score      : $permissionScore%"
    Write-Host "Inventory Score       : $inventoryScore%"
    Write-Host "Finding Penalty       : $findingPenalty"
    Write-Host "Overall Confidence    : $assessmentConfidence%"
    Write-Host "Assessment Health     : $assessmentHealth"
    Write-Host "Assessment Decision   : $assessmentDecision"
    Write-Host ""
    Write-Host "Critical Findings     : $($criticalFindings.Count)"
    Write-Host "High Findings         : $($highFindings.Count)"
    Write-Host "Medium Findings       : $($mediumFindings.Count)"
    Write-Host "Low Findings          : $($lowFindings.Count)"
    Write-Host "Informational         : $($informationalFindings.Count)"

    if ($sortedFindings.Count -gt 0) {
        Write-Host ""
        Write-Host "Graph Assessment Findings" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        $sortedFindings |
            Select-Object `
                Severity,
                Category,
                Title,
                Resource |
            Format-Table `
                -Wrap `
                -AutoSize |
            Out-Host
    }

    Write-Host ""
    Write-Host "Assessment Recommendation" `
        -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------"
    Write-Host $assessmentReason

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
                -Depth 50 |
            Set-Content `
                -LiteralPath $OutputPath `
                -Encoding utf8

        Write-Host ""
        Write-Host (
            "[Success] Exported Graph assessment to $OutputPath"
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
        Get-Command `
            -Name "Write-BKLog" `
            -ErrorAction SilentlyContinue
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