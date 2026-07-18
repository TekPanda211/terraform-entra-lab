function Invoke-BKEngine {
    <#
    .SYNOPSIS
    Invokes a registered Blackknight engine operation.

    .DESCRIPTION
    Resolves the engine entry point from engine.json, validates every supplied
    parameter against the actual script command metadata, and invokes only
    supported parameters. This prevents wrappers and callers from forwarding
    stale parameters such as Path to engines that do not implement them.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Operation = "Assessment",

        [Parameter()]
        [hashtable]$Parameters = @{},

        [Parameter()]
        [switch]$PassThru
    )

    $engine = @(
        Get-BKEngineRegistry -Refresh |
            Where-Object {
                $_.Name -eq $Name -or $_.DisplayName -eq $Name
            }
    ) | Select-Object -First 1

    if ($null -eq $engine) {
        throw "Blackknight engine was not found: $Name"
    }

    if (-not $engine.IsValid) {
        throw (
            "Blackknight engine '$($engine.Name)' is invalid: " +
            ($engine.ValidationErrors -join "; ")
        )
    }

    $entryPointName = $null
    if ($null -ne $engine.EntryPoints) {
        $entryPointProperty = $engine.EntryPoints.PSObject.Properties |
            Where-Object { $_.Name -eq $Operation } |
            Select-Object -First 1

        if ($null -ne $entryPointProperty) {
            $entryPointName = [string]$entryPointProperty.Value
        }
    }

    if ([string]::IsNullOrWhiteSpace($entryPointName)) {
        throw "Engine '$($engine.Name)' does not declare operation '$Operation'."
    }

    $entryPointPath = Join-Path -Path $engine.Root -ChildPath $entryPointName
    if (-not (Test-Path -LiteralPath $entryPointPath -PathType Leaf)) {
        throw "Engine entry point was not found: $entryPointPath"
    }

    $commandInfo = Get-Command -Name $entryPointPath -ErrorAction Stop
    $supportedParameters = @($commandInfo.Parameters.Keys)
    $unsupportedParameters = @(
        $Parameters.Keys |
            Where-Object { $_ -notin $supportedParameters }
    )

    if ($unsupportedParameters.Count -gt 0) {
        throw (
            "Engine '$($engine.Name)' operation '$Operation' does not support parameter(s): " +
            ($unsupportedParameters -join ", ") +
            ". Supported parameters: " +
            (($supportedParameters | Sort-Object) -join ", ")
        )
    }

    $invokeParameters = @{}
    foreach ($key in $Parameters.Keys) {
        $invokeParameters[$key] = $Parameters[$key]
    }

    if ($PassThru.IsPresent -and $commandInfo.Parameters.ContainsKey("PassThru")) {
        $invokeParameters["PassThru"] = $true
    }

    return & $entryPointPath @invokeParameters
}
