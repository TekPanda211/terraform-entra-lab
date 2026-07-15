function Invoke-BKTerraformAssessment {
    <#
    .SYNOPSIS
    Runs the complete Blackknight One Terraform assessment.

    .DESCRIPTION
    Provides the public platform entry point for the Blackknight One
    Terraform assessment engine.

    The assessment can perform:

    - Terraform project inventory
    - Terraform HCL architecture discovery
    - Terraform configuration validation
    - Terraform execution-plan analysis
    - Two-phase Terraform drift confirmation
    - Combined confidence scoring
    - Release-readiness evaluation
    - Optional JSON report generation

    This command does not run terraform apply.

    .PARAMETER Path
    Specifies the Terraform project directory.

    .PARAMETER VariableFile
    Specifies an optional Terraform variable file.

    .PARAMETER SkipInit
    Skips Terraform initialization in supported assessment phases.

    .PARAMETER SkipHclDiscovery
    Skips Terraform HCL architecture discovery.

    .PARAMETER SkipPlan
    Skips Terraform execution-plan analysis.

    .PARAMETER SkipDrift
    Skips Terraform drift detection.

    .PARAMETER IncludeFileDetails
    Includes detailed Terraform file inventory information.

    .PARAMETER IncludeHclSource
    Includes parsed HCL source text in the assessment result and JSON report.

    .PARAMETER ExportJson
    Exports the combined Terraform assessment as JSON.

    .PARAMETER OutputPath
    Specifies the destination path for the JSON report.

    .PARAMETER PassThru
    Returns the complete Terraform assessment object.

    .EXAMPLE
    Invoke-BKTerraformAssessment

    .EXAMPLE
    $Assessment = Invoke-BKTerraformAssessment `
        -Path ".\terraform" `
        -ExportJson `
        -PassThru

    .EXAMPLE
    $Assessment = Invoke-BKTerraformAssessment `
        -Path ".\terraform" `
        -IncludeHclSource `
        -ExportJson `
        -PassThru

    .EXAMPLE
    Invoke-BKTerraformAssessment `
        -Path ".\terraform" `
        -SkipHclDiscovery `
        -SkipDrift
    #>

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
        [string]$OutputPath =
            ".\reports\terraform\terraform-assessment.json",

        [Parameter()]
        [switch]$PassThru
    )

    $engineRelativePath =
        "..\..\Terraform\Invoke-BKTerraformAssessment.ps1"

    $engineScript = Join-Path `
        -Path $PSScriptRoot `
        -ChildPath $engineRelativePath

    $engineScript = [System.IO.Path]::GetFullPath(
        $engineScript
    )

    if (
        -not (
            Test-Path `
                -LiteralPath $engineScript `
                -PathType Leaf
        )
    ) {
        throw "Terraform assessment engine was not found: $engineScript"
    }

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

    $resolvedVariableFile = $null

    if (
        -not [string]::IsNullOrWhiteSpace(
            $VariableFile
        )
    ) {
        if (
            -not (
                Test-Path `
                    -LiteralPath $VariableFile `
                    -PathType Leaf
            )
        ) {
            throw "Terraform variable file was not found: $VariableFile"
        }

        $resolvedVariableFile = (
            Resolve-Path `
                -LiteralPath $VariableFile `
                -ErrorAction Stop
        ).Path
    }

    $invokeParameters = @{
        Path               = $resolvedPath
        SkipInit           = $SkipInit.IsPresent
        SkipHclDiscovery   = $SkipHclDiscovery.IsPresent
        SkipPlan           = $SkipPlan.IsPresent
        SkipDrift          = $SkipDrift.IsPresent
        IncludeFileDetails = $IncludeFileDetails.IsPresent
        IncludeHclSource   = $IncludeHclSource.IsPresent
        ExportJson         = $ExportJson.IsPresent
        OutputPath         = $OutputPath
        PassThru           = $PassThru.IsPresent
    }

    if (
        -not [string]::IsNullOrWhiteSpace(
            $resolvedVariableFile
        )
    ) {
        $invokeParameters.VariableFile =
            $resolvedVariableFile
    }

    Write-Verbose "Terraform assessment wrapper started."
    Write-Verbose "Terraform engine: $engineScript"
    Write-Verbose "Terraform project: $resolvedPath"
    Write-Verbose "Skip initialization: $($SkipInit.IsPresent)"
    Write-Verbose "Skip HCL discovery: $($SkipHclDiscovery.IsPresent)"
    Write-Verbose "Skip plan analysis: $($SkipPlan.IsPresent)"
    Write-Verbose "Skip drift detection: $($SkipDrift.IsPresent)"
    Write-Verbose "Include file details: $($IncludeFileDetails.IsPresent)"
    Write-Verbose "Include HCL source: $($IncludeHclSource.IsPresent)"
    Write-Verbose "Export JSON: $($ExportJson.IsPresent)"
    Write-Verbose "Output path: $OutputPath"

    if ($resolvedVariableFile) {
        Write-Verbose "Terraform variable file: $resolvedVariableFile"
    }

    try {
        $engineOutput = @(
            & $engineScript @invokeParameters
        )

        $result = $engineOutput |
            Where-Object {
                $null -ne $_ -and
                $null -ne $_.PSObject -and
                $_.PSObject.Properties.Name -contains "Operation" -and
                $_.Operation -eq "FullAssessment"
            } |
            Select-Object -Last 1

        if (
            $PassThru.IsPresent -and
            $null -eq $result
        ) {
            throw (
                "Terraform assessment completed without returning a valid " +
                "FullAssessment result object."
            )
        }

        if ($PassThru.IsPresent) {
            return $result
        }
    }
    catch {
        $message =
            "Terraform assessment failed: $($_.Exception.Message)"

        if (
            Get-Command `
                -Name "Write-BKLog" `
                -ErrorAction SilentlyContinue
        ) {
            Write-BKLog `
                -Message $message `
                -Level Error
        }

        throw $message
    }
}