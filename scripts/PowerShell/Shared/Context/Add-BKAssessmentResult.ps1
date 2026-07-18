function Add-BKAssessmentResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Context,
        [Parameter(Mandatory, ValueFromPipeline)][object]$Result
    )
    process {
        if (-not $Context.Results) { throw 'The supplied context does not contain a Results collection.' }
        [void]$Context.Results.Add($Result)
        if ($Context.Tenant -and $Context.Tenant.Assessments) { [void]$Context.Tenant.Assessments.Add($Result) }
        $Context.Status = 'Running'
        $Context
    }
}
