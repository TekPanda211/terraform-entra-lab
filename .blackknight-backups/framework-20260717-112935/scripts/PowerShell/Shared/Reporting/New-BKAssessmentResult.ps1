function New-BKAssessmentResult {
    <#
    .SYNOPSIS
    Creates the standard Blackknight assessment result object.

    .DESCRIPTION
    Produces schema version 2.0 while retaining legacy properties used by
    existing engines.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Engine,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Operation,

        [Parameter()]
        [string]$EngineVersion = "0.0.0",

        [Parameter()]
        [string]$Category = "General",

        [Parameter()]
        [object]$Summary,

        [Parameter()]
        [object]$Scores,

        [Parameter()]
        [AllowEmptyCollection()]
        [object[]]$Findings = @(),

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]]$Recommendations = @(),

        [Parameter()]
        [hashtable]$Metadata = @{},

        [Parameter()]
        [hashtable]$Data = @{},

        [Parameter()]
        [hashtable]$Objects = @{},

        [Parameter()]
        [hashtable]$Statistics = @{},

        [Parameter()]
        [ValidateRange(0, 100)]
        [double]$Confidence = 100
    )

    $generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    $engineInfo = [PSCustomObject]@{
        Name     = $Engine
        Version  = $EngineVersion
        Category = $Category
    }

    [PSCustomObject]@{
        PSTypeName      = "Blackknight.AssessmentResult"
        SchemaVersion   = "2.0"
        Platform        = "Blackknight One"
        EngineInfo      = $engineInfo
        Engine          = $Engine
        Operation       = $Operation
        GeneratedAt     = $generatedAt
        Status          = if ($null -ne $Summary -and $Summary.PSObject.Properties.Name -contains "Status") { [string]$Summary.Status } else { "Complete" }
        Summary         = $Summary
        Scores          = $Scores
        Findings        = @($Findings)
        Recommendations = @($Recommendations)
        Objects         = $Objects
        Statistics      = $Statistics
        Confidence      = $Confidence
        Metadata        = $Metadata
        Data            = $Data
    }
}
