[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Path = ".\terraform",

    [Parameter()]
    [string]$VariableFile,

    [Parameter()]
    [switch]$SkipInit,

    [Parameter()]
    [switch]$SkipHclDiscovery,

    [Parameter()]
    [switch]$SkipPlan,

    [Parameter()]
    [switch]$SkipDrift,

    [Parameter()]
    [switch]$IncludeFileDetails,

    [Parameter()]
    [switch]$IncludeHclSource,

    [Parameter()]
    [switch]$ExportJson,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = ".\reports\terraform\terraform-assessment.json",

    [Parameter()]
    [switch]$PassThru
)

$ErrorActionPreference = "Stop"

function Add-BKTerraformAssessmentFinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Collection,

        [Parameter(Mandatory)]
        [ValidateSet("Informational", "Low", "Medium", "High", "Critical")]
        [string]$Severity,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Source,

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

    $null = $Collection.Add(
        [PSCustomObject]@{
            Severity       = $Severity
            Source         = $Source
            Title          = $Title
            Details        = $Details
            Resource       = $Resource
            Recommendation = $Recommendation
        }
    )
}

function Add-BKTerraformRecommendation {
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

    if (-not [string]::IsNullOrWhiteSpace($Recommendation)) {
        $null = $Collection.Add($Recommendation)
    }
}

function Get-BKTerraformAssessmentHealth {
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

function Get-BKTerraformResultObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Output,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Operation,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$SummaryProperty
    )

    $result = $null

    if (-not [string]::IsNullOrWhiteSpace($Operation)) {
        $result = $Output |
            Where-Object {
                $null -ne $_ -and
                $null -ne $_.PSObject -and
                $_.PSObject.Properties.Name -contains "Operation" -and
                $_.Operation -eq $Operation
            } |
            Select-Object -Last 1
    }

    if ($null -eq $result -and -not [string]::IsNullOrWhiteSpace($SummaryProperty)) {
        $result = $Output |
            Where-Object {
                $null -ne $_ -and
                $null -ne $_.PSObject -and
                $_.PSObject.Properties.Name -contains "Summary" -and
                $null -ne $_.Summary -and
                $_.Summary.PSObject.Properties.Name -contains $SummaryProperty
            } |
            Select-Object -Last 1
    }

    return $result
}

function Get-BKTerraformSeverity {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Severity,

        [Parameter()]
        [ValidateSet("Informational", "Low", "Medium", "High", "Critical")]
        [string]$Default = "Informational"
    )

    if ($Severity -in @("Informational", "Low", "Medium", "High", "Critical")) {
        return $Severity
    }

    return $Default
}

function Get-BKTrackedTerraformStateFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ProjectPath
    )

    if (-not (Get-Command -Name "git" -ErrorAction SilentlyContinue)) {
        return @()
    }

    try {
        return @(
            git -C $ProjectPath ls-files 2>$null |
                Where-Object { $_ -match '\.tfstate(\.backup)?$' }
        )
    }
    catch {
        return @()
    }
}

function Get-BKTerraformLocalBlockCount {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object[]]$Locals
    )

    if ($null -eq $Locals -or @($Locals).Count -eq 0) {
        return 0
    }

    return @(
        $Locals |
            Where-Object { $null -ne $_ } |
            ForEach-Object {
                "{0}:{1}" -f ([string]$_.File), ([int]$_.StartLine)
            } |
            Sort-Object -Unique
    ).Count
}

function Get-BKSummaryValue {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Summary,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PropertyName,

        [Parameter()]
        [AllowNull()]
        [object]$DefaultValue = $null
    )

    if (
        $null -ne $Summary -and
        $null -ne $Summary.PSObject -and
        $Summary.PSObject.Properties.Name -contains $PropertyName
    ) {
        return $Summary.$PropertyName
    }

    return $DefaultValue
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "          BLACKKNIGHT TERRAFORM ASSESSMENT" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

try {
    $requiredCommands = @(
        "Get-BKTerraformInventory"
        "Test-BKTerraformConfiguration"
    )

    if (-not $SkipHclDiscovery.IsPresent) {
        $requiredCommands += "Invoke-BKTerraformHclDiscovery"
    }

    if (-not $SkipPlan.IsPresent) {
        $requiredCommands += "Test-BKTerraformPlan"
    }

    if (-not $SkipDrift.IsPresent) {
        $requiredCommands += "Test-BKTerraformDrift"
    }

    foreach ($commandName in $requiredCommands) {
        if (-not (Get-Command -Name $commandName -ErrorAction SilentlyContinue)) {
            throw "Required Blackknight command is unavailable: $commandName"
        }
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "Terraform project directory was not found: $Path"
    }

    $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    $resolvedVariableFile = $null

    if (-not [string]::IsNullOrWhiteSpace($VariableFile)) {
        if (-not (Test-Path -LiteralPath $VariableFile -PathType Leaf)) {
            throw "Terraform variable file was not found: $VariableFile"
        }

        $resolvedVariableFile = (
            Resolve-Path -LiteralPath $VariableFile -ErrorAction Stop
        ).Path
    }

    $findings = [System.Collections.Generic.List[object]]::new()
    $recommendations = [System.Collections.Generic.List[string]]::new()

    # Phase 1: Inventory
    Write-Host ""
    Write-Host "Phase 1 of 5: Terraform inventory" -ForegroundColor Yellow

    $inventoryOutput = @(
        Get-BKTerraformInventory `
            -Path $resolvedPath `
            -IncludeFileDetails:$IncludeFileDetails
    )

    $inventory = $inventoryOutput |
        Where-Object {
            $null -ne $_ -and
            $null -ne $_.PSObject -and
            $_.PSObject.Properties.Name -contains "TerraformInstalled" -and
            $_.PSObject.Properties.Name -contains "TerraformFileCount"
        } |
        Select-Object -Last 1

    if ($null -eq $inventory) {
        throw "Terraform inventory did not return a valid inventory object."
    }

    $trackedStateFiles = Get-BKTrackedTerraformStateFiles -ProjectPath $resolvedPath

    if (-not [bool]$inventory.TerraformInstalled) {
        Add-BKTerraformAssessmentFinding `
            -Collection $findings `
            -Severity "Critical" `
            -Source "Inventory" `
            -Title "Terraform CLI unavailable" `
            -Details "Terraform was not found in PATH." `
            -Resource $resolvedPath `
            -Recommendation "Install Terraform and ensure it is available in PATH."
    }

    if ([int]$inventory.TerraformFileCount -eq 0) {
        Add-BKTerraformAssessmentFinding `
            -Collection $findings `
            -Severity "High" `
            -Source "Inventory" `
            -Title "No Terraform configuration found" `
            -Details "No Terraform configuration files were discovered." `
            -Resource $resolvedPath `
            -Recommendation "Add Terraform configuration beneath the assessment root."
    }

    if ([bool]$inventory.ContainsLocalState) {
        if ($trackedStateFiles.Count -gt 0) {
            Add-BKTerraformAssessmentFinding `
                -Collection $findings `
                -Severity "Critical" `
                -Source "Inventory" `
                -Title "Tracked Terraform state detected" `
                -Details "$($trackedStateFiles.Count) Terraform state files are tracked by Git." `
                -Resource $resolvedPath `
                -Recommendation "Remove Terraform state from source control and rotate any exposed secrets."
        }
        else {
            Add-BKTerraformAssessmentFinding `
                -Collection $findings `
                -Severity "Medium" `
                -Source "Inventory" `
                -Title "Ignored local Terraform state detected" `
                -Details "$($inventory.StateFileCount) local Terraform state files were found, but none are tracked by Git." `
                -Resource $resolvedPath `
                -Recommendation "Use a secured remote backend before shared or production deployment."
        }
    }

    # Phase 2: HCL architecture discovery
    $hclDiscovery = $null

    if (-not $SkipHclDiscovery.IsPresent) {
        Write-Host ""
        Write-Host "Phase 2 of 5: Terraform HCL architecture discovery" -ForegroundColor Yellow

        $hclParameters = @{
            Path          = $resolvedPath
            SkipInit      = $SkipInit.IsPresent
            IncludeSource = $IncludeHclSource.IsPresent
            PassThru      = $true
        }

        $hclOutput = @(
            Invoke-BKTerraformHclDiscovery @hclParameters
        )

        $hclDiscovery = Get-BKTerraformResultObject `
            -Output $hclOutput `
            -Operation "HclDiscoveryV2" `
            -SummaryProperty "ArchitectureScore"

        if ($null -eq $hclDiscovery) {
            throw "Terraform HCL discovery did not return a valid HclDiscoveryV2 result object."
        }

        foreach ($hclFinding in @($hclDiscovery.Findings)) {
            if ($null -eq $hclFinding) {
                continue
            }

            $hclSeverity = Get-BKTerraformSeverity -Severity ([string]$hclFinding.Severity)
            $hclTitle = [string]$hclFinding.Title

            if ([string]::IsNullOrWhiteSpace($hclTitle)) {
                $hclTitle = "Terraform HCL architecture finding"
            }

            $hclResource = $resolvedPath

            if ($hclFinding.PSObject.Properties.Name -contains "Resource") {
                $candidateResource = [string]$hclFinding.Resource

                if (-not [string]::IsNullOrWhiteSpace($candidateResource)) {
                    $hclResource = $candidateResource
                }
            }

            Add-BKTerraformAssessmentFinding `
                -Collection $findings `
                -Severity $hclSeverity `
                -Source "HCL" `
                -Title $hclTitle `
                -Details ([string]$hclFinding.Details) `
                -Resource $hclResource `
                -Recommendation ([string]$hclFinding.Recommendation)
        }
    }
    else {
        Write-Host ""
        Write-Host "Phase 2 of 5: HCL discovery skipped" -ForegroundColor DarkYellow
    }

    # Phase 3: Configuration validation
    Write-Host ""
    Write-Host "Phase 3 of 5: Terraform configuration validation" -ForegroundColor Yellow

    $configurationParameters = @{
        Path     = $resolvedPath
        Recurse  = $true
        SkipInit = $SkipInit.IsPresent
        PassThru = $true
    }

    $configurationOutput = @(
        Test-BKTerraformConfiguration @configurationParameters
    )

    $configuration = Get-BKTerraformResultObject `
        -Output $configurationOutput `
        -Operation "ConfigurationValidation" `
        -SummaryProperty "ValidProjects"

    if ($null -eq $configuration) {
        throw "Terraform configuration validation did not return a valid result object."
    }

    foreach ($diagnostic in @($configuration.Diagnostics)) {
        if ($null -eq $diagnostic) {
            continue
        }

        $diagnosticSeverity = ([string]$diagnostic.Severity).ToLowerInvariant()
        $severity = switch ($diagnosticSeverity) {
            "error" { "High" }
            "warning" { "Medium" }
            default { "Informational" }
        }

        $title = [string]$diagnostic.Summary

        if ([string]::IsNullOrWhiteSpace($title)) {
            $title = "Terraform configuration diagnostic"
        }

        Add-BKTerraformAssessmentFinding `
            -Collection $findings `
            -Severity $severity `
            -Source "Configuration" `
            -Title $title `
            -Details ([string]$diagnostic.Detail) `
            -Resource ([string]$diagnostic.File) `
            -Recommendation "Correct the Terraform configuration diagnostic."
    }

    # Phase 4: Plan analysis
    $plan = $null

    if (-not $SkipPlan.IsPresent) {
        Write-Host ""
        Write-Host "Phase 4 of 5: Terraform plan analysis" -ForegroundColor Yellow

        $planParameters = @{
            Path     = $resolvedPath
            SkipInit = $SkipInit.IsPresent
            Refresh  = $true
            PassThru = $true
        }

        if ($resolvedVariableFile) {
            $planParameters.VariableFile = $resolvedVariableFile
        }

        $planOutput = @(
            Test-BKTerraformPlan @planParameters
        )

        $plan = Get-BKTerraformResultObject `
            -Output $planOutput `
            -Operation "PlanAnalysis" `
            -SummaryProperty "TotalChanges"

        if ($null -eq $plan) {
            throw "Terraform plan analysis did not return a valid result object."
        }

        foreach ($change in @($plan.Changes)) {
            if ($null -eq $change) {
                continue
            }

            $planSeverity = Get-BKTerraformSeverity -Severity ([string]$change.Severity)
            $actionSummary = [string]$change.ActionSummary

            if ([string]::IsNullOrWhiteSpace($actionSummary)) {
                $actionSummary = "change"
            }

            Add-BKTerraformAssessmentFinding `
                -Collection $findings `
                -Severity $planSeverity `
                -Source "Plan" `
                -Title "Terraform plan change: $actionSummary" `
                -Details "Proposed change for Terraform resource type $($change.Type)." `
                -Resource ([string]$change.Address) `
                -Recommendation "Review and approve the proposed Terraform change before deployment."
        }
    }
    else {
        Write-Host ""
        Write-Host "Phase 4 of 5: Plan analysis skipped" -ForegroundColor DarkYellow
    }

    # Phase 5: Drift confirmation
    $drift = $null

    if (-not $SkipDrift.IsPresent) {
        Write-Host ""
        Write-Host "Phase 5 of 5: Terraform drift confirmation" -ForegroundColor Yellow

        $driftParameters = @{
            Path     = $resolvedPath
            SkipInit = $SkipInit.IsPresent
            PassThru = $true
        }

        if ($resolvedVariableFile) {
            $driftParameters.VariableFile = $resolvedVariableFile
        }

        $driftOutput = @(
            Test-BKTerraformDrift @driftParameters
        )

        $drift = Get-BKTerraformResultObject `
            -Output $driftOutput `
            -Operation "DriftDetection" `
            -SummaryProperty "ActionableDriftDetected"

        if ($null -eq $drift) {
            throw "Terraform drift detection did not return a valid result object."
        }

        foreach ($driftItem in @($drift.DriftItems)) {
            if ($null -eq $driftItem) {
                continue
            }

            $driftSeverity = Get-BKTerraformSeverity -Severity ([string]$driftItem.Severity)
            $actionSummary = [string]$driftItem.ActionSummary

            if ([string]::IsNullOrWhiteSpace($actionSummary)) {
                $actionSummary = "change"
            }

            Add-BKTerraformAssessmentFinding `
                -Collection $findings `
                -Severity $driftSeverity `
                -Source "Drift" `
                -Title "Confirmed Terraform drift: $actionSummary" `
                -Details "Confirmed drift for Terraform resource type $($driftItem.Type)." `
                -Resource ([string]$driftItem.Address) `
                -Recommendation "Reconcile the live environment with the approved Terraform configuration."
        }
    }
    else {
        Write-Host ""
        Write-Host "Phase 5 of 5: Drift confirmation skipped" -ForegroundColor DarkYellow
    }

    foreach ($finding in $findings) {
        Add-BKTerraformRecommendation `
            -Collection $recommendations `
            -Recommendation ([string]$finding.Recommendation)
    }

    foreach ($component in @($configuration, $plan, $drift)) {
        if (
            $null -eq $component -or
            $component.PSObject.Properties.Name -notcontains "Recommendations"
        ) {
            continue
        }

        foreach ($recommendation in @($component.Recommendations)) {
            Add-BKTerraformRecommendation `
                -Collection $recommendations `
                -Recommendation ([string]$recommendation)
        }
    }

    $inventoryScore = 100

    if (-not [bool]$inventory.TerraformInstalled) {
        $inventoryScore -= 35
    }

    if ([int]$inventory.TerraformFileCount -eq 0) {
        $inventoryScore -= 30
    }

    if ([bool]$inventory.ContainsLocalState) {
        if ($trackedStateFiles.Count -gt 0) {
            $inventoryScore -= 35
        }
        else {
            $inventoryScore -= 10
        }
    }

    if ([int]$inventory.BackendCount -eq 0) {
        $inventoryScore -= 10
    }

    if ([int]$inventory.LockFileCount -eq 0) {
        $inventoryScore -= 5
    }

    $inventoryScore = [math]::Max(0, $inventoryScore)

    $hclScore = if ($SkipHclDiscovery.IsPresent) {
        100
    }
    elseif ($null -ne $hclDiscovery) {
        [double](Get-BKSummaryValue `
            -Summary $hclDiscovery.Summary `
            -PropertyName "ArchitectureScore" `
            -DefaultValue 0)
    }
    else {
        0
    }

    $configurationScore = [double](Get-BKSummaryValue `
        -Summary $configuration.Summary `
        -PropertyName "Confidence" `
        -DefaultValue 0)

    $planScore = if ($SkipPlan.IsPresent) {
        100
    }
    elseif ($null -ne $plan) {
        [double](Get-BKSummaryValue `
            -Summary $plan.Summary `
            -PropertyName "Confidence" `
            -DefaultValue 0)
    }
    else {
        0
    }

    $driftScore = if ($SkipDrift.IsPresent) {
        100
    }
    elseif ($null -ne $drift) {
        [double](Get-BKSummaryValue `
            -Summary $drift.Summary `
            -PropertyName "Confidence" `
            -DefaultValue 0)
    }
    else {
        0
    }

    $assessmentConfidence = [math]::Round(
        (
            ($inventoryScore * 0.15) +
            ($hclScore * 0.20) +
            ($configurationScore * 0.25) +
            ($planScore * 0.20) +
            ($driftScore * 0.20)
        ),
        2
    )

    $criticalFindings = @($findings | Where-Object Severity -eq "Critical")
    $highFindings = @($findings | Where-Object Severity -eq "High")
    $mediumFindings = @($findings | Where-Object Severity -eq "Medium")
    $lowFindings = @($findings | Where-Object Severity -eq "Low")
    $informationalFindings = @($findings | Where-Object Severity -eq "Informational")

    $assessmentHealth = Get-BKTerraformAssessmentHealth `
        -Confidence $assessmentConfidence `
        -CriticalFindings $criticalFindings.Count `
        -HighFindings $highFindings.Count

    if ($criticalFindings.Count -gt 0) {
        $releaseDecision = "Blocked"
        $releaseReason = "Critical Terraform findings must be resolved before deployment."
    }
    elseif ($highFindings.Count -gt 0) {
        $releaseDecision = "Review Required"
        $releaseReason = "High-severity Terraform findings require engineering approval."
    }
    elseif ($mediumFindings.Count -gt 0) {
        $releaseDecision = "Conditional Pass"
        $releaseReason = "No critical blockers were detected, but medium-severity findings should be reviewed."
    }
    else {
        $releaseDecision = "Pass"
        $releaseReason = "Terraform passed the Blackknight One assessment gates."
    }

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
                Source,
                Title
    )

    $confirmedDrift = $null

    if ($null -ne $drift -and $null -ne $drift.Summary) {
        if ($drift.Summary.PSObject.Properties.Name -contains "ActionableDriftDetected") {
            $confirmedDrift = [bool]$drift.Summary.ActionableDriftDetected
        }
        elseif ($drift.Summary.PSObject.Properties.Name -contains "DriftDetected") {
            $confirmedDrift = [bool]$drift.Summary.DriftDetected
        }
    }

    $hclLocalBlocks = 0
    $hclLocalExpressions = 0

    if ($null -ne $hclDiscovery) {
        $hclLocalBlocks = Get-BKTerraformLocalBlockCount -Locals @($hclDiscovery.Locals)
        $hclLocalExpressions = @($hclDiscovery.Locals).Count
    }

    $result = [PSCustomObject]@{
        Platform    = "Blackknight One"
        Engine      = "Terraform"
        Operation   = "FullAssessment"
        GeneratedAt = (Get-Date).ToUniversalTime().ToString("o")

        Project = [PSCustomObject]@{
            Path         = $resolvedPath
            VariableFile = $resolvedVariableFile
        }

        Summary = [PSCustomObject]@{
            Status                 = "Complete"
            Health                 = $assessmentHealth
            Confidence             = $assessmentConfidence
            ReleaseDecision        = $releaseDecision
            ReleaseReason          = $releaseReason
            TotalFindings          = $findings.Count
            CriticalFindings       = $criticalFindings.Count
            HighFindings           = $highFindings.Count
            MediumFindings         = $mediumFindings.Count
            LowFindings            = $lowFindings.Count
            InformationalFindings  = $informationalFindings.Count
            TerraformInstalled     = [bool]$inventory.TerraformInstalled
            TerraformVersion       = [string]$inventory.TerraformVersion
            Projects               = [int]$inventory.ProjectCount
            TerraformFiles         = [int]$inventory.TerraformFileCount
            Providers              = [int]$inventory.RequiredProviderCount
            Resources              = [int]$inventory.ResourceCount
            Modules                = [int]$inventory.ModuleCount
            LocalStateFiles        = [int]$inventory.StateFileCount
            TrackedStateFiles      = $trackedStateFiles.Count
            HclHealth              = if ($hclDiscovery) { [string]$hclDiscovery.Summary.Health } else { "Skipped" }
            HclArchitectureScore   = $hclScore
            HclResources           = if ($hclDiscovery) { [int]$hclDiscovery.Summary.Resources } else { 0 }
            HclDataSources         = if ($hclDiscovery) { [int]$hclDiscovery.Summary.DataSources } else { 0 }
            HclModules             = if ($hclDiscovery) { [int]$hclDiscovery.Summary.Modules } else { 0 }
            HclVariables           = if ($hclDiscovery) { [int]$hclDiscovery.Summary.Variables } else { 0 }
            HclOutputs             = if ($hclDiscovery) { [int]$hclDiscovery.Summary.Outputs } else { 0 }
            HclLocalBlocks         = $hclLocalBlocks
            HclLocalExpressions    = $hclLocalExpressions
            HclDependencies        = if ($hclDiscovery) { [int]$hclDiscovery.Summary.Dependencies } else { 0 }
            HclGraphNodes          = if ($hclDiscovery) { [int]$hclDiscovery.Summary.GraphNodes } else { 0 }
            HclGraphEdges          = if ($hclDiscovery) { [int]$hclDiscovery.Summary.GraphEdges } else { 0 }
            ConfigurationErrors    = [int](Get-BKSummaryValue -Summary $configuration.Summary -PropertyName "Errors" -DefaultValue 0)
            PlanChanges            = if ($plan) { [int](Get-BKSummaryValue -Summary $plan.Summary -PropertyName "TotalChanges" -DefaultValue 0) } else { $null }
            ConfirmedDrift         = $confirmedDrift
        }

        Scores = [PSCustomObject]@{
            Inventory       = $inventoryScore
            HclArchitecture = $hclScore
            Configuration   = $configurationScore
            Plan            = $planScore
            Drift           = $driftScore
            Overall         = $assessmentConfidence
        }

        Inventory      = $inventory
        HclDiscovery   = $hclDiscovery
        Configuration  = $configuration
        Plan           = $plan
        Drift          = $drift
        Findings       = $sortedFindings
        Recommendations = @(
            $recommendations |
                Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
                Sort-Object -Unique
        )
    }

    Write-Host ""
    Write-Host "Assessment Summary" -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------"
    Write-Host "Project              : $resolvedPath"
    Write-Host "Terraform Files      : $($inventory.TerraformFileCount)"
    Write-Host "Managed Resources    : $($inventory.ResourceCount)"
    Write-Host ""
    Write-Host "Inventory Score      : $inventoryScore%"
    Write-Host "HCL Architecture     : $hclScore%"
    Write-Host "Configuration Score  : $configurationScore%"
    Write-Host "Plan Score           : $planScore%"
    Write-Host "Drift Score          : $driftScore%"
    Write-Host "Overall Confidence   : $assessmentConfidence%"
    Write-Host "Assessment Health    : $assessmentHealth"
    Write-Host "Release Decision     : $releaseDecision"

    if ($null -ne $hclDiscovery) {
        Write-Host ""
        Write-Host "HCL Architecture" -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"
        Write-Host "Resources            : $($hclDiscovery.Summary.Resources)"
        Write-Host "Data Sources         : $($hclDiscovery.Summary.DataSources)"
        Write-Host "Modules              : $($hclDiscovery.Summary.Modules)"
        Write-Host "Variables            : $($hclDiscovery.Summary.Variables)"
        Write-Host "Outputs              : $($hclDiscovery.Summary.Outputs)"
        Write-Host "Local Blocks         : $hclLocalBlocks"
        Write-Host "Local Expressions    : $hclLocalExpressions"
        Write-Host "Dependencies         : $($hclDiscovery.Summary.Dependencies)"
        Write-Host "Graph Nodes          : $($hclDiscovery.Summary.GraphNodes)"
        Write-Host "Graph Edges          : $($hclDiscovery.Summary.GraphEdges)"
    }

    Write-Host ""
    Write-Host "Critical Findings    : $($criticalFindings.Count)"
    Write-Host "High Findings        : $($highFindings.Count)"
    Write-Host "Medium Findings      : $($mediumFindings.Count)"
    Write-Host "Low Findings         : $($lowFindings.Count)"
    Write-Host "Informational        : $($informationalFindings.Count)"

    if ($sortedFindings.Count -gt 0) {
        Write-Host ""
        Write-Host "Assessment Findings" -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        $sortedFindings |
            Select-Object Severity, Source, Title, Resource |
            Format-Table -Wrap -AutoSize |
            Out-Host
    }

    Write-Host ""
    Write-Host "Release Recommendation" -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------"
    Write-Host $releaseReason

    if ($ExportJson.IsPresent) {
        $outputDirectory = Split-Path -Path $OutputPath -Parent

        if (
            -not [string]::IsNullOrWhiteSpace($outputDirectory) -and
            -not (Test-Path -LiteralPath $outputDirectory)
        ) {
            New-Item -Path $outputDirectory -ItemType Directory -Force | Out-Null
        }

        $result |
            ConvertTo-Json -Depth 60 |
            Set-Content -LiteralPath $OutputPath -Encoding utf8

        Write-Host ""
        Write-Host "[Success] Exported Terraform assessment to $OutputPath" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan

    if ($PassThru.IsPresent) {
        return $result
    }
}
catch {
    if (Get-Command -Name "Write-BKLog" -ErrorAction SilentlyContinue) {
        Write-BKLog -Message $_.Exception.Message -Level Error
    }
    else {
        Write-Error $_.Exception.Message
    }

    throw
}