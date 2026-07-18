function Invoke-BKExchangeAssessment {
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$ExportJson,

        [Parameter()]
        [switch]$IncludeObjects,

        [Parameter()]
        [string]$OutputPath = ".\reports\exchange\exchange-assessment.json",

        [Parameter()]
        [switch]$PassThru
    )

    $parameters = @{
        ExportJson = $ExportJson.IsPresent
        IncludeObjects = $IncludeObjects.IsPresent
        OutputPath = $OutputPath
    }

    Invoke-BKEngine -Name "Exchange" -Operation "Assessment" -Parameters $parameters -PassThru:$PassThru.IsPresent
}
