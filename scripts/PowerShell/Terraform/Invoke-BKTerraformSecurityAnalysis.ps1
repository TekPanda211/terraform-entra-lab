[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Path = ".\terraform",

    [Parameter()]
    [AllowNull()]
    [object]$HclDiscovery,

    [Parameter()]
    [switch]$SkipInit,

    [Parameter()]
    [switch]$IncludeSource,

    [Parameter()]
    [switch]$ExportJson,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath =
        ".\reports\terraform\terraform-security-analysis.json",

    [Parameter()]
    [switch]$PassThru
)

$ErrorActionPreference = "Stop"

function Test-BKTerraformHclSourceAvailable {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Discovery
    )

    if ($null -eq $Discovery) {
        return $false
    }

    $sourceObjects = @(
        @($Discovery.Resources)
        @($Discovery.DataSources)
        @($Discovery.Modules)
        @($Discovery.Variables)
        @($Discovery.Outputs)
    ) |
        Where-Object {
            $null -ne $_
        }

    if ($sourceObjects.Count -eq 0) {
        return $false
    }

    $objectsWithSource = @(
        $sourceObjects |
            Where-Object {
                $_.PSObject.Properties.Name -contains "Source" -and
                -not [string]::IsNullOrWhiteSpace(
                    [string]$_.Source
                )
            }
    )

    return $objectsWithSource.Count -gt 0
}

function Get-BKTerraformSourceText {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return ""
    }

    if (
        $null -eq $InputObject.PSObject -or
        $InputObject.PSObject.Properties.Name -notcontains "Source"
    ) {
        return ""
    }

    $sourceText = [string]$InputObject.Source

    if ([string]::IsNullOrWhiteSpace($sourceText)) {
        return ""
    }

    return $sourceText
}

function Add-BKTerraformSecurityFinding {
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
        [string]$File,

        [Parameter()]
        [int]$Line = 0,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Recommendation
    )

    $null = $Collection.Add(
        [PSCustomObject]@{
            Severity       = $Severity
            Category       = $Category
            Title          = $Title
            Details        = $Details
            Resource       = $Resource
            File           = $File
            Line           = $Line
            Recommendation = $Recommendation
        }
    )
}

function Get-BKTerraformSecurityHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [double]$Score,

        [Parameter(Mandatory)]
        [int]$CriticalCount,

        [Parameter(Mandatory)]
        [int]$HighCount
    )

    if ($CriticalCount -gt 0) {
        return "Needs Attention"
    }

    if ($HighCount -gt 0) {
        return "Warning"
    }

    if ($Score -ge 95) {
        return "Excellent"
    }

    if ($Score -ge 85) {
        return "Healthy"
    }

    if ($Score -ge 70) {
        return "Warning"
    }

    return "Needs Attention"
}

function Get-BKObjectSource {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$InputObject
    )

    if (
        $null -eq $InputObject -or
        $null -eq $InputObject.PSObject -or
        $InputObject.PSObject.Properties.Name -notcontains "Source"
    ) {
        return ""
    }

    return [string]$InputObject.Source
}

function Test-BKVersionConstraintBounded {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Constraint
    )

    if ([string]::IsNullOrWhiteSpace($Constraint)) {
        return $false
    }

    $normalized = $Constraint.Trim()

    if ($normalized -in @("*", ">= 0", ">=0")) {
        return $false
    }

    if ($normalized -match '^>=\s*\d+(?:\.\d+){0,2}$') {
        return $false
    }

    return $true
}

function Test-BKHardcodedSensitiveAssignment {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Source = ""
    )

    $pattern = '(?im)^\s*(client_secret|secret|password|token|access_key|private_key|certificate_password)\s*=\s*"([^"$]{4,})"\s*$'

    return @(
        [regex]::Matches(
            $Source,
            $pattern
        )
    )
}

Write-Host ""
Write-Host "============================================================" `
    -ForegroundColor Cyan
Write-Host "        BLACKKNIGHT TERRAFORM SECURITY ANALYZER" `
    -ForegroundColor Cyan
Write-Host "============================================================" `
    -ForegroundColor Cyan

try {
    if (
        -not (
            Test-Path `
                -LiteralPath $Path `
                -PathType Container
        )
    ) {
        throw "Terraform project directory was not found: $Path"
    }

    $resolvedPath = (
        Resolve-Path `
            -LiteralPath $Path `
            -ErrorAction Stop
    ).Path

    $effectiveHclDiscovery = $HclDiscovery

    $sourceAvailable =
        Test-BKTerraformHclSourceAvailable `
            -Discovery $effectiveHclDiscovery

    if (-not $sourceAvailable) {
        if (
            -not (
                Get-Command `
                    -Name "Invoke-BKTerraformHclDiscovery" `
                    -ErrorAction SilentlyContinue
            )
        ) {
            throw (
                "Terraform HCL source is required for security analysis, " +
                "but Invoke-BKTerraformHclDiscovery is unavailable."
            )
        }

        Write-Verbose (
            "The supplied HCL discovery object does not contain source text. " +
            "Refreshing HCL discovery with IncludeSource enabled."
        )

        Write-Host ""
        Write-Host "Collecting source-enabled HCL discovery data..." `
            -ForegroundColor Yellow

        $hclParameters = @{
            Path          = $resolvedPath
            IncludeSource = $true
            SkipInit      = $SkipInit.IsPresent
            PassThru      = $true
        }

        $discoveryOutput = @(
            Invoke-BKTerraformHclDiscovery @hclParameters
        )

        $effectiveHclDiscovery = $discoveryOutput |
            Where-Object {
                $null -ne $_ -and
                $null -ne $_.PSObject -and
                $_.PSObject.Properties.Name -contains "Operation" -and
                $_.Operation -eq "HclDiscoveryV2"
            } |
            Select-Object -Last 1
    }

    if (
        $null -eq $effectiveHclDiscovery -or
        $effectiveHclDiscovery.Operation -ne "HclDiscoveryV2"
    ) {
        throw "A valid HclDiscoveryV2 object was not available."
    }

    if (
        -not (
            Test-BKTerraformHclSourceAvailable `
                -Discovery $effectiveHclDiscovery
        )
    ) {
        throw (
            "HCL discovery completed, but no source text was returned. " +
            "Security analysis cannot continue."
        )
    }

    $findings =
        [System.Collections.Generic.List[object]]::new()

    Write-Host ""
    Write-Host "Analyzing Terraform security posture..." `
        -ForegroundColor Yellow

    # Backend security
    if (@($effectiveHclDiscovery.Backends).Count -eq 0) {
        Add-BKTerraformSecurityFinding `
            -Collection $findings `
            -Severity "Medium" `
            -Category "State" `
            -Title "No explicit remote backend detected" `
            -Details "Terraform may rely on local state for this project." `
            -Resource $resolvedPath `
            -Recommendation "Use a secured remote backend with encryption, access control, and state locking."
    }

    foreach ($backend in @($effectiveHclDiscovery.Backends)) {
        if ($null -eq $backend) {
            continue
        }

        if ([string]$backend.Type -eq "local") {
            Add-BKTerraformSecurityFinding `
                -Collection $findings `
                -Severity "High" `
                -Category "State" `
                -Title "Local Terraform backend configured" `
                -Details "The configuration explicitly uses the local backend." `
                -Resource "backend.local" `
                -File ([string]$backend.File) `
                -Line ([int]$backend.StartLine) `
                -Recommendation "Migrate shared or production state to a secured remote backend."
        }
    }

    # Lock file and version constraints
    $lockFilePath = Join-Path `
        -Path $resolvedPath `
        -ChildPath ".terraform.lock.hcl"

    if (-not (Test-Path -LiteralPath $lockFilePath -PathType Leaf)) {
        Add-BKTerraformSecurityFinding `
            -Collection $findings `
            -Severity "Medium" `
            -Category "SupplyChain" `
            -Title "Terraform dependency lock file is missing" `
            -Details "Provider selections are not protected by a committed dependency lock file." `
            -Resource $resolvedPath `
            -Recommendation "Run terraform init and commit .terraform.lock.hcl."
    }

    $terraformConstraint = @(
        $effectiveHclDiscovery.VersionConstraints |
            Where-Object {
                $_.Type -eq "Terraform"
            }
    ) | Select-Object -First 1

    if ($null -eq $terraformConstraint) {
        Add-BKTerraformSecurityFinding `
            -Collection $findings `
            -Severity "Medium" `
            -Category "SupplyChain" `
            -Title "Terraform CLI version is not constrained" `
            -Details "The configuration does not declare required_version." `
            -Resource "terraform.required_version" `
            -Recommendation "Declare a tested Terraform version range."
    }

    foreach (
        $providerConstraint in @(
            $effectiveHclDiscovery.VersionConstraints |
                Where-Object {
                    $_.Type -eq "Provider"
                }
        )
    ) {
        if (
            -not (
                Test-BKVersionConstraintBounded `
                    -Constraint ([string]$providerConstraint.Version)
            )
        ) {
            Add-BKTerraformSecurityFinding `
                -Collection $findings `
                -Severity "Medium" `
                -Category "SupplyChain" `
                -Title "Provider version is missing or unbounded" `
                -Details (
                    "Provider {0} does not use a bounded version constraint." -f
                    $providerConstraint.Name
                ) `
                -Resource ([string]$providerConstraint.Name) `
                -File ([string]$providerConstraint.File) `
                -Line ([int]$providerConstraint.StartLine) `
                -Recommendation "Pin the provider to an approved and tested version range."
        }
    }

    foreach ($module in @($effectiveHclDiscovery.Modules)) {
        if ($null -eq $module) {
            continue
        }

        $moduleSource = [string]$module.SourcePath
        $moduleVersion = [string]$module.Version

        $isRemoteModule =
            -not [string]::IsNullOrWhiteSpace($moduleSource) -and
            $moduleSource -notmatch '^(\.|\.\.|[A-Za-z]:\\)'

        if (
            $isRemoteModule -and
            [string]::IsNullOrWhiteSpace($moduleVersion)
        ) {
            Add-BKTerraformSecurityFinding `
                -Collection $findings `
                -Severity "Medium" `
                -Category "SupplyChain" `
                -Title "Remote module version is not pinned" `
                -Details "Remote module $($module.Name) does not declare a version." `
                -Resource ([string]$module.Address) `
                -File ([string]$module.File) `
                -Line ([int]$module.StartLine) `
                -Recommendation "Pin remote modules to an approved immutable version."
        }
    }

    # Sensitive variables and outputs
    foreach ($variable in @($effectiveHclDiscovery.Variables)) {
        if ($null -eq $variable) {
            continue
        }

        $sensitiveName =
            [string]$variable.Name -match
            '(?i)(secret|password|token|credential|private_key|client_secret)'

        if (
            ($variable.Sensitive -or $sensitiveName) -and
            $variable.HasDefault
        ) {
            Add-BKTerraformSecurityFinding `
                -Collection $findings `
                -Severity "Critical" `
                -Category "Secrets" `
                -Title "Sensitive variable has a default value" `
                -Details "Variable $($variable.Name) may embed sensitive material in configuration or state." `
                -Resource ([string]$variable.Address) `
                -File ([string]$variable.File) `
                -Line ([int]$variable.StartLine) `
                -Recommendation "Remove the default and supply the value through an approved secret-management workflow."
        }

        if ($sensitiveName -and -not $variable.Sensitive) {
            Add-BKTerraformSecurityFinding `
                -Collection $findings `
                -Severity "Medium" `
                -Category "Secrets" `
                -Title "Potentially sensitive variable is not marked sensitive" `
                -Details "Variable $($variable.Name) has a sensitive name but sensitive = true was not detected." `
                -Resource ([string]$variable.Address) `
                -File ([string]$variable.File) `
                -Line ([int]$variable.StartLine) `
                -Recommendation "Mark the variable sensitive and prevent it from appearing in normal output."
        }
    }

    foreach ($output in @($effectiveHclDiscovery.Outputs)) {
        if ($null -eq $output) {
            continue
        }

        $appearsSensitive =
            ([string]$output.Name -match
                '(?i)(secret|password|token|credential|private_key|client_secret)') -or
            ([string]$output.Value -match
                '(?i)(secret|password|token|credential|private_key|client_secret)')

        if ($appearsSensitive -and -not $output.Sensitive) {
            Add-BKTerraformSecurityFinding `
                -Collection $findings `
                -Severity "High" `
                -Category "Secrets" `
                -Title "Potentially sensitive output is not protected" `
                -Details "Output $($output.Name) appears to expose sensitive material." `
                -Resource ([string]$output.Address) `
                -File ([string]$output.File) `
                -Line ([int]$output.StartLine) `
                -Recommendation "Mark the output sensitive or remove it."
        }
    }

    # Resource-level security analysis
    $privilegedResourcePatterns = @(
        'azuread_directory_role'
        'azuread_directory_role_assignment'
        'azuread_group_role_management_policy'
        'azuread_privileged_access_group'
        'azurerm_role_assignment'
        'azuread_conditional_access_policy'
        'azuread_application_password'
        'azuread_service_principal_password'
    )

    foreach ($resource in @($effectiveHclDiscovery.Resources)) {
        if ($null -eq $resource) {
            continue
        }

        $resourceType = [string]$resource.Type
        $resourceSource = Get-BKTerraformSourceText `
            -InputObject $resource

        foreach (
            $secretMatch in @(
                Test-BKHardcodedSensitiveAssignment `
                    -Source $resourceSource
            )
        ) {
            $attributeName =
                [string]$secretMatch.Groups[1].Value

            Add-BKTerraformSecurityFinding `
                -Collection $findings `
                -Severity "Critical" `
                -Category "Secrets" `
                -Title "Hardcoded sensitive value detected" `
                -Details "Attribute $attributeName contains a quoted literal value. The value was not included in this report." `
                -Resource ([string]$resource.Address) `
                -File ([string]$resource.File) `
                -Line ([int]$resource.StartLine) `
                -Recommendation "Move the value to an approved secret store or protected variable input."
        }

        $isPrivilegedResource = $false

        foreach ($pattern in $privilegedResourcePatterns) {
            if ($resourceType -like "$pattern*") {
                $isPrivilegedResource = $true
                break
            }
        }

        if (
            $isPrivilegedResource -and
            -not [bool]$resource.PreventDestroy
        ) {
            Add-BKTerraformSecurityFinding `
                -Collection $findings `
                -Severity "Medium" `
                -Category "Lifecycle" `
                -Title "Privileged resource lacks prevent_destroy" `
                -Details "Privileged resource $($resource.Address) can be destroyed without a lifecycle safeguard." `
                -Resource ([string]$resource.Address) `
                -File ([string]$resource.File) `
                -Line ([int]$resource.StartLine) `
                -Recommendation "Evaluate prevent_destroy for privileged or high-impact identity resources."
        }

        if (
            $resourceType -eq "azurerm_role_assignment" -and
            $resourceSource -match
            '(?im)^\s*role_definition_name\s*=\s*"(Owner|Contributor)"\s*$'
        ) {
            $roleName = [string]$matches[1]

            $severity = if ($roleName -eq "Owner") {
                "High"
            }
            else {
                "Medium"
            }

            Add-BKTerraformSecurityFinding `
                -Collection $findings `
                -Severity $severity `
                -Category "Authorization" `
                -Title "Broad Azure role assignment detected" `
                -Details "Resource $($resource.Address) assigns the $roleName role." `
                -Resource ([string]$resource.Address) `
                -File ([string]$resource.File) `
                -Line ([int]$resource.StartLine) `
                -Recommendation "Use the least-privileged custom or built-in role that satisfies the requirement."
        }

        if (
            $resourceType -eq "azurerm_role_assignment" -and
            $resourceSource -match
            '(?im)^\s*scope\s*=\s*"/"\s*$'
        ) {
            Add-BKTerraformSecurityFinding `
                -Collection $findings `
                -Severity "High" `
                -Category "Authorization" `
                -Title "Tenant-root Azure RBAC scope detected" `
                -Details "The role assignment targets the root Azure scope." `
                -Resource ([string]$resource.Address) `
                -File ([string]$resource.File) `
                -Line ([int]$resource.StartLine) `
                -Recommendation "Reduce the role-assignment scope to the smallest required management group, subscription, resource group, or resource."
        }

        if (
            $resourceType -match '^azurerm_(storage_account|key_vault|mssql_server|cosmosdb_account)$' -and
            $resourceSource -match
            '(?im)^\s*public_network_access_enabled\s*=\s*true\s*$'
        ) {
            Add-BKTerraformSecurityFinding `
                -Collection $findings `
                -Severity "High" `
                -Category "NetworkExposure" `
                -Title "Public network access is enabled" `
                -Details "Resource $($resource.Address) explicitly enables public network access." `
                -Resource ([string]$resource.Address) `
                -File ([string]$resource.File) `
                -Line ([int]$resource.StartLine) `
                -Recommendation "Use private endpoints or tightly restricted firewall rules where supported."
        }

        if (
            $resourceType -eq "azurerm_storage_account" -and
            $resourceSource -notmatch
            '(?im)^\s*min_tls_version\s*=\s*"TLS1_2"\s*$'
        ) {
            Add-BKTerraformSecurityFinding `
                -Collection $findings `
                -Severity "Medium" `
                -Category "Encryption" `
                -Title "Storage account TLS minimum is not explicitly TLS 1.2" `
                -Details "The storage account does not explicitly require TLS 1.2 in its HCL." `
                -Resource ([string]$resource.Address) `
                -File ([string]$resource.File) `
                -Line ([int]$resource.StartLine) `
                -Recommendation "Set min_tls_version to TLS1_2."
        }

        if (
            $resourceType -eq "azurerm_key_vault" -and
            $resourceSource -notmatch
            '(?im)^\s*purge_protection_enabled\s*=\s*true\s*$'
        ) {
            Add-BKTerraformSecurityFinding `
                -Collection $findings `
                -Severity "Medium" `
                -Category "Recovery" `
                -Title "Key Vault purge protection is not explicitly enabled" `
                -Details "The Key Vault configuration does not explicitly enable purge protection." `
                -Resource ([string]$resource.Address) `
                -File ([string]$resource.File) `
                -Line ([int]$resource.StartLine) `
                -Recommendation "Enable purge protection for production Key Vaults."
        }
    }

    $criticalFindings = @(
        $findings |
            Where-Object Severity -eq "Critical"
    )

    $highFindings = @(
        $findings |
            Where-Object Severity -eq "High"
    )

    $mediumFindings = @(
        $findings |
            Where-Object Severity -eq "Medium"
    )

    $lowFindings = @(
        $findings |
            Where-Object Severity -eq "Low"
    )

    $informationalFindings = @(
        $findings |
            Where-Object Severity -eq "Informational"
    )

    $penalty =
        ($criticalFindings.Count * 25) +
        ($highFindings.Count * 10) +
        ($mediumFindings.Count * 3) +
        ($lowFindings.Count * 1)

    if ($penalty -gt 100) {
        $penalty = 100
    }

    $score = [math]::Max(
        0,
        100 - $penalty
    )

    $health = Get-BKTerraformSecurityHealth `
        -Score $score `
        -CriticalCount $criticalFindings.Count `
        -HighCount $highFindings.Count

    $decision = if ($criticalFindings.Count -gt 0) {
        "Blocked"
    }
    elseif ($highFindings.Count -gt 0) {
        "Review Required"
    }
    elseif ($mediumFindings.Count -gt 0) {
        "Conditional Pass"
    }
    else {
        "Pass"
    }

    $recommendations = @(
        $findings |
            ForEach-Object {
                [string]$_.Recommendation
            } |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            } |
            Sort-Object -Unique
    )

    $sortedFindings = @(
        $findings |
            Sort-Object `
                @{
                    Expression = {
                        switch ($_.Severity) {
                            "Critical" { 5 }
                            "High" { 4 }
                            "Medium" { 3 }
                            "Low" { 2 }
                            default { 1 }
                        }
                    }
                    Descending = $true
                },
                Category,
                Title
    )

    $result = [PSCustomObject]@{
        Platform    = "Blackknight One"
        Engine      = "Terraform"
        Operation   = "SecurityAnalysis"
        GeneratedAt = (
            Get-Date
        ).ToUniversalTime().ToString("o")

        Project = [PSCustomObject]@{
            Path               = $resolvedPath
            SkipInit           = $SkipInit.IsPresent
            IncludeSource      = $IncludeSource.IsPresent
            SourceWasRefreshed = ($effectiveHclDiscovery -ne $HclDiscovery)
        }

        Summary = [PSCustomObject]@{
            Status                 = "Complete"
            Health                 = $health
            SecurityScore          = $score
            Decision               = $decision
            TotalFindings          = $findings.Count
            CriticalFindings       = $criticalFindings.Count
            HighFindings           = $highFindings.Count
            MediumFindings         = $mediumFindings.Count
            LowFindings            = $lowFindings.Count
            InformationalFindings  = $informationalFindings.Count
            Penalty                = $penalty
            ResourcesAnalyzed      = @($effectiveHclDiscovery.Resources).Count
            VariablesAnalyzed      = @($effectiveHclDiscovery.Variables).Count
            OutputsAnalyzed        = @($effectiveHclDiscovery.Outputs).Count
            ModulesAnalyzed        = @($effectiveHclDiscovery.Modules).Count
            BackendsAnalyzed       = @($effectiveHclDiscovery.Backends).Count
        }

        Findings       = $sortedFindings
        Recommendations = $recommendations
        HclDiscovery   = if ($IncludeSource.IsPresent) {
            $effectiveHclDiscovery
        }
        else {
            $null
        }
    }

    Write-Host ""
    Write-Host "Terraform Security Summary" `
        -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------"
    Write-Host "Project              : $resolvedPath"
    Write-Host "Security Score       : $score%"
    Write-Host "Security Health      : $health"
    Write-Host "Decision             : $decision"
    Write-Host "Resources Analyzed   : $($result.Summary.ResourcesAnalyzed)"
    Write-Host "Variables Analyzed   : $($result.Summary.VariablesAnalyzed)"
    Write-Host "Outputs Analyzed     : $($result.Summary.OutputsAnalyzed)"
    Write-Host "Modules Analyzed     : $($result.Summary.ModulesAnalyzed)"
    Write-Host "Backends Analyzed    : $($result.Summary.BackendsAnalyzed)"
    Write-Host ""
    Write-Host "Critical Findings    : $($criticalFindings.Count)"
    Write-Host "High Findings        : $($highFindings.Count)"
    Write-Host "Medium Findings      : $($mediumFindings.Count)"
    Write-Host "Low Findings         : $($lowFindings.Count)"
    Write-Host "Informational        : $($informationalFindings.Count)"

    if ($sortedFindings.Count -gt 0) {
        Write-Host ""
        Write-Host "Security Findings" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        $sortedFindings |
            Select-Object `
                Severity,
                Category,
                Title,
                Resource,
                File,
                Line |
            Format-Table `
                -Wrap `
                -AutoSize |
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
                -Depth 60 |
            Set-Content `
                -LiteralPath $OutputPath `
                -Encoding utf8

        Write-Host ""
        Write-Host (
            "[Success] Exported Terraform security analysis to " +
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
