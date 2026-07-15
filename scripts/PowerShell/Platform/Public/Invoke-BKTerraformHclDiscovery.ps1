function Invoke-BKTerraformHclDiscovery {
    <#
    .SYNOPSIS
    Runs Blackknight One Terraform HCL Discovery Engine V2.

    .DESCRIPTION
    Provides the public platform command for discovering and analyzing
    Terraform HCL architecture.

    The engine discovers:

    - Terraform files
    - Terraform and provider version constraints
    - Provider configurations
    - Resources
    - Data sources
    - Modules
    - Variables
    - Outputs
    - Locals
    - Backends
    - Import blocks
    - Moved blocks
    - Expression dependencies
    - Explicit dependencies
    - Terraform graph nodes and edges
    - Architecture findings and scoring

    This command does not modify infrastructure.

    .PARAMETER Path
    Specifies the Terraform project directory.

    .PARAMETER SkipInit
    Skips Terraform initialization before generating the dependency graph.

    .PARAMETER IncludeSource
    Includes parsed HCL source text in the returned result and JSON export.

    .PARAMETER ExportJson
    Exports the HCL discovery result as JSON.

    .PARAMETER OutputPath
    Specifies the JSON report destination.

    .PARAMETER PassThru
    Returns the complete HCL discovery object.

    .EXAMPLE
    Invoke-BKTerraformHclDiscovery

    .EXAMPLE
    $Discovery = Invoke-BKTerraformHclDiscovery `
        -Path ".\terraform" `
        -ExportJson `
        -PassThru
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Path = ".\terraform",

        [Parameter()]
        [switch]$SkipInit,

        [Parameter()]
        [switch]$IncludeSource,

        [Parameter()]
        [switch]$ExportJson,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath =
            ".\reports\terraform\terraform-hcl-discovery.json",

        [Parameter()]
        [switch]$PassThru
    )

    $engineScript = Join-Path `
        -Path $PSScriptRoot `
        -ChildPath "..\..\Terraform\Invoke-BKTerraformHclDiscovery.ps1"

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
        throw "Terraform HCL discovery engine was not found: $engineScript"
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

    $invokeParameters = @{
        Path          = $resolvedPath
        SkipInit      = $SkipInit.IsPresent
        IncludeSource = $IncludeSource.IsPresent
        ExportJson    = $ExportJson.IsPresent
        OutputPath    = $OutputPath
        PassThru      = $PassThru.IsPresent
    }

    Write-Verbose "Terraform HCL discovery wrapper started."
    Write-Verbose "HCL engine: $engineScript"
    Write-Verbose "Terraform project: $resolvedPath"
    Write-Verbose "Skip initialization: $($SkipInit.IsPresent)"
    Write-Verbose "Include source: $($IncludeSource.IsPresent)"
    Write-Verbose "Export JSON: $($ExportJson.IsPresent)"
    Write-Verbose "Output path: $OutputPath"

    try {
        $result =
            & $engineScript @invokeParameters

        if ($PassThru.IsPresent) {
            return $result
        }
    }
    catch {
        $message =
            "Terraform HCL discovery failed: $($_.Exception.Message)"

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