[CmdletBinding()]
param(
    [Parameter()]
    [switch]$IncludeObjects,

    [Parameter()]
    [switch]$ExportJson,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath =
        ".\reports\conditional-access\conditional-access-assessment.json",

    [Parameter()]
    [switch]$PassThru
)

$ErrorActionPreference = "Stop"

function Get-BKCAProperty {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string[]]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    foreach ($candidate in $Name) {
        $property = $InputObject.PSObject.Properties[$candidate]

        if ($null -ne $property) {
            return $property.Value
        }
    }

    return $null
}

function ConvertTo-BKCAArray {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return @()
    }

    return @($Value)
}

function ConvertTo-BKCAStringArray {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Value
    )

    return @(
        ConvertTo-BKCAArray -Value $Value |
            ForEach-Object {
                [string]$_
            } |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            }
    )
}

function Invoke-BKCAPagedGraphRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Uri
    )

    $items = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri

    while (-not [string]::IsNullOrWhiteSpace($nextLink)) {
        $response = Invoke-MgGraphRequest `
            -Method GET `
            -Uri $nextLink `
            -OutputType PSObject `
            -ErrorAction Stop

        if ($response.PSObject.Properties.Name -contains "value") {
            foreach ($item in @($response.value)) {
                if ($null -ne $item) {
                    $null = $items.Add($item)
                }
            }
        }
        elseif ($null -ne $response) {
            $null = $items.Add($response)
        }

        $nextLink = [string](
            Get-BKCAProperty `
                -InputObject $response `
                -Name @("@odata.nextLink", "odata.nextLink")
        )
    }

    return @($items)
}

function Add-BKCAFinding {
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

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Details,

        [Parameter()]
        [AllowNull()]
        [string]$Resource,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Recommendation
    )

    $weights = @{
        Informational = 0
        Low           = 1
        Medium        = 3
        High          = 8
        Critical      = 15
    }

    $null = $Collection.Add(
        [PSCustomObject]@{
            Severity       = $Severity
            Category       = $Category
            Title          = $Title
            Details        = $Details
            Resource       = $Resource
            Recommendation = $Recommendation
            Penalty        = $weights[$Severity]
        }
    )
}

function Test-BKCAContainsAny {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Value,

        [Parameter(Mandatory)]
        [string[]]$Candidate
    )

    $values = ConvertTo-BKCAStringArray -Value $Value

    foreach ($item in $Candidate) {
        if ($item -in $values) {
            return $true
        }
    }

    return $false
}

function Get-BKCAPolicyRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Policy
    )

    $conditions = Get-BKCAProperty `
        -InputObject $Policy `
        -Name @("conditions", "Conditions")

    $users = Get-BKCAProperty `
        -InputObject $conditions `
        -Name @("users", "Users")

    $applications = Get-BKCAProperty `
        -InputObject $conditions `
        -Name @("applications", "Applications")

    $grantControls = Get-BKCAProperty `
        -InputObject $Policy `
        -Name @("grantControls", "GrantControls")

    $sessionControls = Get-BKCAProperty `
        -InputObject $Policy `
        -Name @("sessionControls", "SessionControls")

    $builtInControls = ConvertTo-BKCAStringArray -Value (
        Get-BKCAProperty `
            -InputObject $grantControls `
            -Name @("builtInControls", "BuiltInControls")
    )

    $includeUsers = ConvertTo-BKCAStringArray -Value (
        Get-BKCAProperty `
            -InputObject $users `
            -Name @("includeUsers", "IncludeUsers")
    )

    $excludeUsers = ConvertTo-BKCAStringArray -Value (
        Get-BKCAProperty `
            -InputObject $users `
            -Name @("excludeUsers", "ExcludeUsers")
    )

    $includeGroups = ConvertTo-BKCAStringArray -Value (
        Get-BKCAProperty `
            -InputObject $users `
            -Name @("includeGroups", "IncludeGroups")
    )

    $excludeGroups = ConvertTo-BKCAStringArray -Value (
        Get-BKCAProperty `
            -InputObject $users `
            -Name @("excludeGroups", "ExcludeGroups")
    )

    $includeRoles = ConvertTo-BKCAStringArray -Value (
        Get-BKCAProperty `
            -InputObject $users `
            -Name @("includeRoles", "IncludeRoles")
    )

    $excludeRoles = ConvertTo-BKCAStringArray -Value (
        Get-BKCAProperty `
            -InputObject $users `
            -Name @("excludeRoles", "ExcludeRoles")
    )

    $includeApplications = ConvertTo-BKCAStringArray -Value (
        Get-BKCAProperty `
            -InputObject $applications `
            -Name @("includeApplications", "IncludeApplications")
    )

    $excludeApplications = ConvertTo-BKCAStringArray -Value (
        Get-BKCAProperty `
            -InputObject $applications `
            -Name @("excludeApplications", "ExcludeApplications")
    )

    $clientAppTypes = ConvertTo-BKCAStringArray -Value (
        Get-BKCAProperty `
            -InputObject $conditions `
            -Name @("clientAppTypes", "ClientAppTypes")
    )

    $signInRiskLevels = ConvertTo-BKCAStringArray -Value (
        Get-BKCAProperty `
            -InputObject $conditions `
            -Name @("signInRiskLevels", "SignInRiskLevels")
    )

    $userRiskLevels = ConvertTo-BKCAStringArray -Value (
        Get-BKCAProperty `
            -InputObject $conditions `
            -Name @("userRiskLevels", "UserRiskLevels")
    )

    $servicePrincipalRiskLevels = ConvertTo-BKCAStringArray -Value (
        Get-BKCAProperty `
            -InputObject $conditions `
            -Name @("servicePrincipalRiskLevels", "ServicePrincipalRiskLevels")
    )

    $platforms = Get-BKCAProperty `
        -InputObject $conditions `
        -Name @("platforms", "Platforms")

    $locations = Get-BKCAProperty `
        -InputObject $conditions `
        -Name @("locations", "Locations")

    $devices = Get-BKCAProperty `
        -InputObject $conditions `
        -Name @("devices", "Devices")

    $authenticationStrength = Get-BKCAProperty `
        -InputObject $grantControls `
        -Name @("authenticationStrength", "AuthenticationStrength")

    $authenticationStrengthId = [string](
        Get-BKCAProperty `
            -InputObject $authenticationStrength `
            -Name @("id", "Id")
    )

    $state = [string](
        Get-BKCAProperty `
            -InputObject $Policy `
            -Name @("state", "State")
    )

    [PSCustomObject]@{
        Id = [string](
            Get-BKCAProperty `
                -InputObject $Policy `
                -Name @("id", "Id")
        )
        DisplayName = [string](
            Get-BKCAProperty `
                -InputObject $Policy `
                -Name @("displayName", "DisplayName")
        )
        State = $state
        Enabled = $state -eq "enabled"
        ReportOnly = $state -eq "enabledForReportingButNotEnforced"
        Disabled = $state -eq "disabled"
        CreatedDateTime = Get-BKCAProperty `
            -InputObject $Policy `
            -Name @("createdDateTime", "CreatedDateTime")
        ModifiedDateTime = Get-BKCAProperty `
            -InputObject $Policy `
            -Name @("modifiedDateTime", "ModifiedDateTime")
        TemplateId = [string](
            Get-BKCAProperty `
                -InputObject $Policy `
                -Name @("templateId", "TemplateId")
        )
        IncludeUsers = $includeUsers
        ExcludeUsers = $excludeUsers
        IncludeGroups = $includeGroups
        ExcludeGroups = $excludeGroups
        IncludeRoles = $includeRoles
        ExcludeRoles = $excludeRoles
        IncludeApplications = $includeApplications
        ExcludeApplications = $excludeApplications
        ClientAppTypes = $clientAppTypes
        BuiltInControls = $builtInControls
        AuthenticationStrengthId = $authenticationStrengthId
        HasSessionControls = $null -ne $sessionControls
        HasPlatformCondition = $null -ne $platforms
        HasLocationCondition = $null -ne $locations
        HasDeviceCondition = $null -ne $devices
        SignInRiskLevels = $signInRiskLevels
        UserRiskLevels = $userRiskLevels
        ServicePrincipalRiskLevels = $servicePrincipalRiskLevels
        TargetsAllUsers = "All" -in $includeUsers
        TargetsAllApplications = "All" -in $includeApplications
        TargetsAdminRoles = $includeRoles.Count -gt 0
        TargetsGuests = $null -ne (
            Get-BKCAProperty `
                -InputObject $users `
                -Name @(
                    "includeGuestsOrExternalUsers",
                    "IncludeGuestsOrExternalUsers"
                )
        )
        BlocksAccess = "block" -in $builtInControls
        RequiresMfa = (
            "mfa" -in $builtInControls -or
            -not [string]::IsNullOrWhiteSpace($authenticationStrengthId)
        )
        RequiresCompliantDevice = (
            "compliantDevice" -in $builtInControls
        )
        RequiresDomainJoinedDevice = (
            "domainJoinedDevice" -in $builtInControls
        )
        ProtectsLegacyAuthentication = (
            $clientAppTypes -contains "exchangeActiveSync" -or
            $clientAppTypes -contains "other"
        )
        HasUserRiskCondition = $userRiskLevels.Count -gt 0
        HasSignInRiskCondition = $signInRiskLevels.Count -gt 0
        HasWorkloadRiskCondition = $servicePrincipalRiskLevels.Count -gt 0
        ExclusionCount = (
            $excludeUsers.Count +
            $excludeGroups.Count +
            $excludeRoles.Count +
            $excludeApplications.Count
        )
        Raw = $Policy
    }
}

Write-Host ""
Write-Host "============================================================" `
    -ForegroundColor Cyan
Write-Host "      BLACKKNIGHT CONDITIONAL ACCESS ASSESSMENT" `
    -ForegroundColor Cyan
Write-Host "============================================================" `
    -ForegroundColor Cyan

try {
    foreach ($commandName in @(
        "Get-MgContext"
        "Invoke-MgGraphRequest"
    )) {
        if (
            -not (
                Get-Command `
                    -Name $commandName `
                    -ErrorAction SilentlyContinue
            )
        ) {
            throw (
                "Required Microsoft Graph command is unavailable: " +
                $commandName
            )
        }
    }

    $graphContext = Get-MgContext `
        -ErrorAction SilentlyContinue

    if ($null -eq $graphContext) {
        throw (
            "No active Microsoft Graph connection exists. Connect with " +
            "Policy.Read.All before running the assessment."
        )
    }

    Write-Host ""
    Write-Host "Target Tenant" `
        -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------"
    Write-Host "Account      : $($graphContext.Account)"
    Write-Host "Tenant ID    : $($graphContext.TenantId)"
    Write-Host "Environment  : $($graphContext.Environment)"
    Write-Host "Auth Type    : $($graphContext.AuthType)"

    Write-Host ""
    Write-Host "Phase 1 of 5: Collecting Conditional Access policies..."

    $rawPolicies = Invoke-BKCAPagedGraphRequest `
        -Uri (
            "/v1.0/identity/conditionalAccess/policies" +
            '?$select=id,displayName,state,createdDateTime,modifiedDateTime,' +
            'templateId,conditions,grantControls,sessionControls'
        )

    $policies = @(
        foreach ($policy in $rawPolicies) {
            Get-BKCAPolicyRecord -Policy $policy
        }
    )

    Write-Host "Phase 2 of 5: Collecting named locations..."

    $namedLocations = @(
        Invoke-BKCAPagedGraphRequest `
            -Uri "/v1.0/identity/conditionalAccess/namedLocations"
    )

    Write-Host "Phase 3 of 5: Collecting authentication strengths..."

    $authenticationStrengths = @()

    try {
        $authenticationStrengths = @(
            Invoke-BKCAPagedGraphRequest `
                -Uri (
                    "/v1.0/policies/authenticationStrengthPolicies" +
                    '?$select=id,displayName,description,policyType,' +
                    'requirementsSatisfied,allowedCombinations,' +
                    'createdDateTime,modifiedDateTime'
                )
        )
    }
    catch {
        Write-Verbose (
            "Authentication-strength inventory was unavailable: " +
            $_.Exception.Message
        )
    }

    Write-Host "Phase 4 of 5: Evaluating policy coverage and hygiene..."

    $findings = [System.Collections.Generic.List[object]]::new()

    $enabledPolicies = @($policies | Where-Object Enabled)
    $reportOnlyPolicies = @($policies | Where-Object ReportOnly)
    $disabledPolicies = @($policies | Where-Object Disabled)
    $allUserPolicies = @($enabledPolicies | Where-Object TargetsAllUsers)
    $adminPolicies = @(
        $enabledPolicies |
            Where-Object {
                $_.TargetsAdminRoles -or
                $_.DisplayName -match '(?i)admin'
            }
    )
    $mfaPolicies = @($enabledPolicies | Where-Object RequiresMfa)
    $legacyPolicies = @(
        $enabledPolicies |
            Where-Object {
                $_.ProtectsLegacyAuthentication -and
                $_.BlocksAccess
            }
    )
    $devicePolicies = @(
        $enabledPolicies |
            Where-Object {
                $_.RequiresCompliantDevice -or
                $_.RequiresDomainJoinedDevice
            }
    )
    $riskPolicies = @(
        $enabledPolicies |
            Where-Object {
                $_.HasUserRiskCondition -or
                $_.HasSignInRiskCondition
            }
    )
    $guestPolicies = @(
        $enabledPolicies |
            Where-Object TargetsGuests
    )
    $workloadPolicies = @(
        $enabledPolicies |
            Where-Object HasWorkloadRiskCondition
    )
    $locationPolicies = @(
        $enabledPolicies |
            Where-Object HasLocationCondition
    )
    $sessionPolicies = @(
        $enabledPolicies |
            Where-Object HasSessionControls
    )
    $authenticationStrengthPolicies = @(
        $enabledPolicies |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace(
                    $_.AuthenticationStrengthId
                )
            }
    )
    $broadExclusionPolicies = @(
        $enabledPolicies |
            Where-Object {
                $_.ExclusionCount -ge 5
            }
    )
    $unassignedPolicies = @(
        $policies |
            Where-Object {
                $_.IncludeUsers.Count -eq 0 -and
                $_.IncludeGroups.Count -eq 0 -and
                $_.IncludeRoles.Count -eq 0
            }
    )

    if ($policies.Count -eq 0) {
        Add-BKCAFinding `
            -Collection $findings `
            -Severity "Critical" `
            -Category "Coverage" `
            -Title "No Conditional Access policies found" `
            -Details "The tenant does not contain Conditional Access policies." `
            -Resource $graphContext.TenantId `
            -Recommendation "Deploy a tested Conditional Access baseline in report-only mode before enforcement."
    }

    if ($adminPolicies.Count -eq 0) {
        Add-BKCAFinding `
            -Collection $findings `
            -Severity "Critical" `
            -Category "Administrators" `
            -Title "No enabled administrator protection policy" `
            -Details "No enabled policy targets administrator roles or is identified as an administrator policy." `
            -Resource $graphContext.TenantId `
            -Recommendation "Require phishing-resistant MFA or a strong authentication strength for privileged roles."
    }

    if ($mfaPolicies.Count -eq 0) {
        Add-BKCAFinding `
            -Collection $findings `
            -Severity "Critical" `
            -Category "Authentication" `
            -Title "No enabled MFA policy detected" `
            -Details "No enabled Conditional Access policy requires MFA or an authentication strength." `
            -Resource $graphContext.TenantId `
            -Recommendation "Require MFA for users and stronger authentication for privileged roles."
    }

    if ($legacyPolicies.Count -eq 0) {
        Add-BKCAFinding `
            -Collection $findings `
            -Severity "High" `
            -Category "LegacyAuthentication" `
            -Title "Legacy authentication is not blocked" `
            -Details "No enabled block policy targets legacy client application types." `
            -Resource $graphContext.TenantId `
            -Recommendation "Enable a tested policy that blocks Exchange ActiveSync and other legacy clients."
    }

    if ($devicePolicies.Count -eq 0) {
        Add-BKCAFinding `
            -Collection $findings `
            -Severity "Medium" `
            -Category "Devices" `
            -Title "No enabled device-control policy detected" `
            -Details "No enabled policy requires a compliant or domain-joined device." `
            -Resource $graphContext.TenantId `
            -Recommendation "Evaluate device-based access controls for sensitive applications and administrative access."
    }

    if ($riskPolicies.Count -eq 0) {
        Add-BKCAFinding `
            -Collection $findings `
            -Severity "Medium" `
            -Category "Risk" `
            -Title "No enabled risk-based policy detected" `
            -Details "No enabled policy evaluates user risk or sign-in risk." `
            -Resource $graphContext.TenantId `
            -Recommendation "Evaluate user-risk and sign-in-risk policies if supported by licensing."
    }

    if ($guestPolicies.Count -eq 0) {
        Add-BKCAFinding `
            -Collection $findings `
            -Severity "Medium" `
            -Category "ExternalIdentity" `
            -Title "No enabled guest-specific policy detected" `
            -Details "No enabled policy explicitly targets guests or external users." `
            -Resource $graphContext.TenantId `
            -Recommendation "Review external-user access and require appropriate authentication controls."
    }

    if ($workloadPolicies.Count -eq 0) {
        Add-BKCAFinding `
            -Collection $findings `
            -Severity "Low" `
            -Category "WorkloadIdentity" `
            -Title "No workload identity risk policy detected" `
            -Details "No enabled policy evaluates service-principal risk." `
            -Resource $graphContext.TenantId `
            -Recommendation "Evaluate workload identity Conditional Access where licensing and operational requirements support it."
    }

    foreach ($policy in $reportOnlyPolicies) {
        $modified = $policy.ModifiedDateTime
        $ageDays = $null

        if ($null -ne $modified) {
            try {
                $ageDays = [math]::Floor(
                    ((Get-Date) - [datetime]$modified).TotalDays
                )
            }
            catch {
                $ageDays = $null
            }
        }

        if ($null -ne $ageDays -and $ageDays -ge 90) {
            Add-BKCAFinding `
                -Collection $findings `
                -Severity "Medium" `
                -Category "Lifecycle" `
                -Title "Long-running report-only policy" `
                -Details "Policy '$($policy.DisplayName)' has remained report-only for approximately $ageDays days." `
                -Resource $policy.Id `
                -Recommendation "Review sign-in impact and either enforce, revise, or retire the policy."
        }
    }

    foreach ($policy in $broadExclusionPolicies) {
        Add-BKCAFinding `
            -Collection $findings `
            -Severity "Medium" `
            -Category "Exclusions" `
            -Title "Policy has broad exclusions" `
            -Details "Policy '$($policy.DisplayName)' contains $($policy.ExclusionCount) explicit exclusions." `
            -Resource $policy.Id `
            -Recommendation "Validate each exclusion, document ownership, and minimize bypass paths."
    }

    foreach ($policy in $unassignedPolicies) {
        Add-BKCAFinding `
            -Collection $findings `
            -Severity "High" `
            -Category "Assignments" `
            -Title "Policy has no user, group, or role assignments" `
            -Details "Policy '$($policy.DisplayName)' has no detectable identity assignments." `
            -Resource $policy.Id `
            -Recommendation "Assign the intended identities or remove the unused policy."
    }

    $duplicatePolicyNames = @(
        $policies |
            Group-Object DisplayName |
            Where-Object {
                $_.Count -gt 1
            }
    )

    foreach ($duplicate in $duplicatePolicyNames) {
        Add-BKCAFinding `
            -Collection $findings `
            -Severity "Low" `
            -Category "Hygiene" `
            -Title "Duplicate policy display name" `
            -Details "$($duplicate.Count) policies use the display name '$($duplicate.Name)'." `
            -Resource $duplicate.Name `
            -Recommendation "Use unique names that identify scope, control, and enforcement state."
    }

    $poorlyNamedPolicies = @(
        $policies |
            Where-Object {
                [string]::IsNullOrWhiteSpace($_.DisplayName) -or
                $_.DisplayName.Length -lt 8
            }
    )

    foreach ($policy in $poorlyNamedPolicies) {
        Add-BKCAFinding `
            -Collection $findings `
            -Severity "Low" `
            -Category "Hygiene" `
            -Title "Policy name lacks descriptive context" `
            -Details "Policy '$($policy.DisplayName)' does not provide enough descriptive context." `
            -Resource $policy.Id `
            -Recommendation "Adopt a consistent naming convention that identifies purpose, audience, and state."
    }

    $penalty = (
        $findings |
            Measure-Object `
                -Property Penalty `
                -Sum
    ).Sum

    if ($null -eq $penalty) {
        $penalty = 0
    }

    $securityScore = [math]::Max(
        0,
        [math]::Round(100 - [double]$penalty, 0)
    )

    $criticalCount = @(
        $findings |
            Where-Object Severity -eq "Critical"
    ).Count

    $highCount = @(
        $findings |
            Where-Object Severity -eq "High"
    ).Count

    $mediumCount = @(
        $findings |
            Where-Object Severity -eq "Medium"
    ).Count

    $lowCount = @(
        $findings |
            Where-Object Severity -eq "Low"
    ).Count

    $health = if ($criticalCount -gt 0) {
        "Critical"
    }
    elseif ($highCount -gt 0) {
        "Needs Attention"
    }
    elseif ($securityScore -ge 90) {
        "Excellent"
    }
    elseif ($securityScore -ge 80) {
        "Healthy"
    }
    elseif ($securityScore -ge 65) {
        "Warning"
    }
    else {
        "Needs Attention"
    }

    $decision = if ($criticalCount -gt 0) {
        "Blocked"
    }
    elseif ($highCount -gt 0) {
        "Conditional Pass"
    }
    elseif ($mediumCount -gt 0) {
        "Conditional Pass"
    }
    else {
        "Pass"
    }

    $recommendation = if ($criticalCount -gt 0) {
        "Resolve critical Conditional Access coverage gaps before relying on the tenant policy baseline."
    }
    elseif ($highCount -gt 0) {
        "Resolve high-severity Conditional Access findings before production enforcement changes."
    }
    elseif ($mediumCount -gt 0) {
        "Core Conditional Access coverage is present, but medium findings should be reviewed."
    }
    else {
        "Conditional Access coverage and policy hygiene passed the current assessment checks."
    }

    Write-Host "Phase 5 of 5: Building executive assessment..."

    $result = [PSCustomObject]@{
        Platform    = "Blackknight One"
        Engine      = "ConditionalAccess"
        Operation   = "ConditionalAccessAssessment"
        GeneratedAt = (
            Get-Date
        ).ToUniversalTime().ToString("o")

        Tenant = [PSCustomObject]@{
            Account     = $graphContext.Account
            TenantId    = $graphContext.TenantId
            Environment = $graphContext.Environment
            AuthType    = $graphContext.AuthType
        }

        Summary = [PSCustomObject]@{
            Status                     = "Complete"
            Health                     = $health
            SecurityScore              = $securityScore
            Decision                   = $decision
            TotalFindings              = $findings.Count
            CriticalFindings           = $criticalCount
            HighFindings               = $highCount
            MediumFindings             = $mediumCount
            LowFindings                = $lowCount
            Policies                   = $policies.Count
            EnabledPolicies            = $enabledPolicies.Count
            ReportOnlyPolicies         = $reportOnlyPolicies.Count
            DisabledPolicies           = $disabledPolicies.Count
            AllUserPolicies            = $allUserPolicies.Count
            AdministratorPolicies      = $adminPolicies.Count
            MfaPolicies                = $mfaPolicies.Count
            LegacyAuthenticationBlocks = $legacyPolicies.Count
            DeviceControlPolicies      = $devicePolicies.Count
            RiskBasedPolicies          = $riskPolicies.Count
            GuestPolicies              = $guestPolicies.Count
            WorkloadIdentityPolicies   = $workloadPolicies.Count
            LocationPolicies           = $locationPolicies.Count
            SessionControlPolicies     = $sessionPolicies.Count
            AuthenticationStrengthPolicies = (
                $authenticationStrengthPolicies.Count
            )
            NamedLocations             = $namedLocations.Count
            AuthenticationStrengths    = $authenticationStrengths.Count
        }

        Scores = [PSCustomObject]@{
            Security = $securityScore
            Penalty  = [math]::Round([double]$penalty, 2)
        }

        Findings = @($findings)
        Recommendation = $recommendation
    }

    if ($IncludeObjects.IsPresent) {
        $result | Add-Member `
            -MemberType NoteProperty `
            -Name Policies `
            -Value $policies

        $result | Add-Member `
            -MemberType NoteProperty `
            -Name NamedLocations `
            -Value $namedLocations

        $result | Add-Member `
            -MemberType NoteProperty `
            -Name AuthenticationStrengths `
            -Value $authenticationStrengths
    }

    Write-Host ""
    Write-Host "Conditional Access Assessment Summary" `
        -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------"
    Write-Host "Policies                  : $($result.Summary.Policies)"
    Write-Host "Enabled                   : $($result.Summary.EnabledPolicies)"
    Write-Host "Report Only               : $($result.Summary.ReportOnlyPolicies)"
    Write-Host "Disabled                  : $($result.Summary.DisabledPolicies)"
    Write-Host "Administrator Policies    : $($result.Summary.AdministratorPolicies)"
    Write-Host "MFA Policies              : $($result.Summary.MfaPolicies)"
    Write-Host "Legacy Auth Blocks        : $($result.Summary.LegacyAuthenticationBlocks)"
    Write-Host "Device Control Policies   : $($result.Summary.DeviceControlPolicies)"
    Write-Host "Risk-Based Policies       : $($result.Summary.RiskBasedPolicies)"
    Write-Host "Guest Policies            : $($result.Summary.GuestPolicies)"
    Write-Host "Workload Identity Policies: $($result.Summary.WorkloadIdentityPolicies)"
    Write-Host "Named Locations           : $($result.Summary.NamedLocations)"
    Write-Host "Security Score            : $($result.Summary.SecurityScore)%"
    Write-Host "Assessment Health         : $($result.Summary.Health)"
    Write-Host "Decision                  : $($result.Summary.Decision)"
    Write-Host ""
    Write-Host "Critical Findings         : $criticalCount"
    Write-Host "High Findings             : $highCount"
    Write-Host "Medium Findings           : $mediumCount"
    Write-Host "Low Findings              : $lowCount"

    if ($findings.Count -gt 0) {
        Write-Host ""
        Write-Host "Conditional Access Findings" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        $findings |
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
    Write-Host $recommendation

    if ($ExportJson.IsPresent) {
        $outputDirectory = Split-Path `
            -Path $OutputPath `
            -Parent

        if (
            -not [string]::IsNullOrWhiteSpace($outputDirectory) -and
            -not (
                Test-Path `
                    -LiteralPath $outputDirectory `
                    -PathType Container
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
            "[Success] Exported Conditional Access assessment to " +
            $OutputPath
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