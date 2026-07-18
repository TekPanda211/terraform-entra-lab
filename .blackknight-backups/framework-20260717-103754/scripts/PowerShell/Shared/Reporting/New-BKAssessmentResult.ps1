function New-BKAssessmentResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Engine,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Operation,

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
        [hashtable]$Data = @{}
    )

    [PSCustomObject]@{
        Platform        = "Blackknight One"
        Engine          = $Engine
        Operation       = $Operation
        GeneratedAt     = (Get-Date).ToUniversalTime().ToString("o")
        Summary         = $Summary
        Scores          = $Scores
        Findings        = @($Findings)
        Recommendations = @($Recommendations)
        Metadata        = $Metadata
        Data            = $Data
    }
}
