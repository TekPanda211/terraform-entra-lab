function Write-BKAssessmentHeader {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter()][string]$Subtitle
    )
    $line = "-" * 60
    Write-Host ""
    Write-Host $line
    Write-Host $Title -ForegroundColor Cyan
    if (-not [string]::IsNullOrWhiteSpace($Subtitle)) { Write-Host $Subtitle }
    Write-Host $line
}
