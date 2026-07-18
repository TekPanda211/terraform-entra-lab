[CmdletBinding()]
param(
    [Parameter()]
    [switch]$PassThru
)

$ErrorActionPreference = "Stop"

# TODO: Implement Exchange discovery.
$result = [PSCustomObject]@{
    Platform    = "Blackknight One"
    Engine      = "Exchange"
    Operation   = "ExchangeDiscovery"
    GeneratedAt = (Get-Date).ToUniversalTime().ToString("o")
    Objects     = @()
}

if ($PassThru.IsPresent) {
    return $result
}
