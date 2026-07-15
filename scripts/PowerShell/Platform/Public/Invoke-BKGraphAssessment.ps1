function Invoke-BKGraphAssessment {
    <#
    .SYNOPSIS
    Runs the complete Blackknight One Microsoft Graph assessment.

    .DESCRIPTION
    Provides the public platform command for invoking the Microsoft Graph
    assessment engine.

    The assessment performs:

    - Graph connection validation
    - Tenant discovery
    - Dataset completeness analysis
    - Graph permission coverage analysis
    - Tenant inventory checks
    - Finding generation
    - Confidence scoring
    - Assessment readiness evaluation
    - Optional JSON report export

    .PARAMETER IncludeObjects
    Includes normalized Graph objects in the discovery data returned inside
    the assessment.

    .PARAMETER ExportJson
    Exports the Graph assessment report as JSON.

    .PARAMETER OutputPath
    Specifies the destination path for the JSON report.

    .PARAMETER PassThru
    Returns the complete Graph assessment object.

    .EXAMPLE
    Invoke-BKGraphAssessment

    .EXAMPLE
    $Assessment = Invoke-BKGraphAssessment `
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
            ".\reports\graph\graph-assessment.json",

        [Parameter()]
        [switch]$PassThru
    )

    $engineScript = Join-Path `
        -Path $PSScriptRoot `
        -ChildPath "..\..\Graph\Invoke-BKGraphAssessment.ps1"

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
        throw "Graph assessment engine was not found: $engineScript"
    }

    $invokeParameters = @{
        IncludeObjects = $IncludeObjects.IsPresent
        ExportJson     = $ExportJson.IsPresent
        OutputPath     = $OutputPath
        PassThru       = $PassThru.IsPresent
    }

    Write-Verbose "Graph assessment wrapper started."
    Write-Verbose "Graph engine: $engineScript"
    Write-Verbose "Include objects: $($IncludeObjects.IsPresent)"
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
            "Graph assessment failed: $($_.Exception.Message)"

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