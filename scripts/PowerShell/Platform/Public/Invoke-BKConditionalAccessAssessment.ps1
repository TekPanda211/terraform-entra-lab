function Invoke-BKConditionalAccessAssessment {
    <#
    .SYNOPSIS
    Runs the Blackknight One Conditional Access assessment.

    .DESCRIPTION
    Provides the public platform wrapper for the Conditional Access assessment
    engine. The assessment inventories live Microsoft Entra Conditional Access
    policies, named locations, authentication strengths, coverage, and policy
    hygiene. It does not modify tenant configuration.

    .PARAMETER IncludeObjects
    Includes normalized policy, named-location, and authentication-strength
    objects in the returned assessment.

    .PARAMETER ExportJson
    Exports the assessment as JSON.

    .PARAMETER OutputPath
    Destination for the JSON assessment report.

    .PARAMETER PassThru
    Returns the complete assessment object.
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
            ".\reports\conditional-access\conditional-access-assessment.json",

        [Parameter()]
        [switch]$PassThru
    )

    $engineScript = Join-Path `
        -Path $PSScriptRoot `
        -ChildPath (
            "..\..\ConditionalAccess\" +
            "Invoke-BKConditionalAccessAssessment.ps1"
        )

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
            "Conditional Access assessment engine was not found: " +
            $engineScript
        )
    }

    $parameters = @{
        IncludeObjects = $IncludeObjects.IsPresent
        ExportJson     = $ExportJson.IsPresent
        OutputPath     = $OutputPath
        PassThru       = $PassThru.IsPresent
    }

    Write-Verbose "Conditional Access assessment wrapper started."
    Write-Verbose "Engine: $engineScript"
    Write-Verbose "Include objects: $($IncludeObjects.IsPresent)"
    Write-Verbose "Export JSON: $($ExportJson.IsPresent)"
    Write-Verbose "Output path: $OutputPath"

    try {
        $engineOutput = @(
            & $engineScript @parameters
        )

        $result = $engineOutput |
            Where-Object {
                $null -ne $_ -and
                $_.PSObject.Properties.Name -contains "Operation" -and
                $_.Operation -eq "ConditionalAccessAssessment"
            } |
            Select-Object -Last 1

        if (
            $PassThru.IsPresent -and
            $null -eq $result
        ) {
            throw (
                "Conditional Access assessment completed without returning " +
                "a valid result object."
            )
        }

        if ($PassThru.IsPresent) {
            return $result
        }
    }
    catch {
        $message =
            "Conditional Access assessment failed: $($_.Exception.Message)"

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