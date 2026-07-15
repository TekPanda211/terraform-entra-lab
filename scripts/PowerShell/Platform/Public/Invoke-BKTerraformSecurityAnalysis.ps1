function Invoke-BKTerraformSecurityAnalysis {
    <#
    .SYNOPSIS
    Runs the Blackknight One Terraform Security Analyzer.

    .DESCRIPTION
    Provides the public platform command for invoking the Terraform
    security-analysis engine.

    The analyzer evaluates Terraform configuration for security and
    engineering risks, including:

    - Backend and state hygiene
    - Terraform and provider version constraints
    - Dependency lock-file presence
    - Remote module version pinning
    - Sensitive variables and outputs
    - Potential hardcoded secrets
    - Privileged-resource lifecycle protection
    - Broad Azure role assignments
    - Public network exposure
    - Storage-account TLS configuration
    - Key Vault purge protection

    This command does not modify Terraform configuration or infrastructure.

    .PARAMETER Path
    Specifies the Terraform project directory.

    .PARAMETER HclDiscovery
    Supplies an existing HCL Discovery V2 result. When omitted, the security
    engine performs or obtains its own HCL discovery as implemented by the
    engine.

    .PARAMETER ExportJson
    Exports the security-analysis report as JSON.

    .PARAMETER OutputPath
    Specifies the destination path for the JSON report.

    .PARAMETER PassThru
    Returns the complete Terraform security-analysis object.

    .EXAMPLE
    Invoke-BKTerraformSecurityAnalysis

    .EXAMPLE
    $SecurityAnalysis =
        Invoke-BKTerraformSecurityAnalysis `
            -Path ".\terraform" `
            -ExportJson `
            -PassThru

    .EXAMPLE
    $HclDiscovery =
        Invoke-BKTerraformHclDiscovery `
            -Path ".\terraform" `
            -PassThru

    $SecurityAnalysis =
        Invoke-BKTerraformSecurityAnalysis `
            -Path ".\terraform" `
            -HclDiscovery $HclDiscovery `
            -PassThru
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Path = ".\terraform",

        [Parameter()]
        [AllowNull()]
        [object]$HclDiscovery,

        [Parameter()]
        [switch]$ExportJson,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath =
            ".\reports\terraform\terraform-security-analysis.json",

        [Parameter()]
        [switch]$PassThru
    )

    $engineRelativePath =
        "..\..\Terraform\Invoke-BKTerraformSecurityAnalysis.ps1"

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
        throw (
            "Terraform security-analysis engine was not found: " +
            $engineScript
        )
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
        Path       = $resolvedPath
        ExportJson = $ExportJson.IsPresent
        OutputPath = $OutputPath
        PassThru   = $PassThru.IsPresent
    }

    if ($null -ne $HclDiscovery) {
        $invokeParameters.HclDiscovery =
            $HclDiscovery
    }

    Write-Verbose "Terraform security-analysis wrapper started."
    Write-Verbose "Security engine: $engineScript"
    Write-Verbose "Terraform project: $resolvedPath"
    Write-Verbose "Existing HCL discovery supplied: $($null -ne $HclDiscovery)"
    Write-Verbose "Export JSON: $($ExportJson.IsPresent)"
    Write-Verbose "Output path: $OutputPath"

    try {
        $engineOutput = @(
            & $engineScript @invokeParameters
        )

        $result = $engineOutput |
            Where-Object {
                $null -ne $_ -and
                $null -ne $_.PSObject -and
                $_.PSObject.Properties.Name -contains "Operation" -and
                $_.Operation -eq "SecurityAnalysis"
            } |
            Select-Object -Last 1

        if (
            $PassThru.IsPresent -and
            $null -eq $result
        ) {
            throw (
                "Terraform security analysis completed without returning " +
                "a valid SecurityAnalysis result object."
            )
        }

        if ($PassThru.IsPresent) {
            return $result
        }
    }
    catch {
        $message =
            "Terraform security analysis failed: $($_.Exception.Message)"

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