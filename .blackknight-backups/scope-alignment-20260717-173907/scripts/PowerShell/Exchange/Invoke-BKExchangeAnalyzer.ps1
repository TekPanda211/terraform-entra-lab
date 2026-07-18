[CmdletBinding()]
param(
    [Parameter()]
    [AllowNull()]
    [object]$Discovery,

    [Parameter()]
    [switch]$PassThru
)

$ErrorActionPreference = "Stop"

# TODO: Implement Exchange analysis.
$result = [PSCustomObject]@{
    Platform    = "Blackknight One"
    Engine      = "Exchange"
    Operation   = "ExchangeAnalysis"
    GeneratedAt = (Get-Date).ToUniversalTime().ToString("o")
    Findings    = @()
}

if ($PassThru.IsPresent) {
    return $result
}
