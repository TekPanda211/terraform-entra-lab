function Invoke-BKEngine {
    <#
    .SYNOPSIS
    Invokes a registered Blackknight engine operation.
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

    $invokeParameters = @{}
    foreach ($key in $Parameters.Keys) {
        $invokeParameters[$key] = $Parameters[$key]
    }

    if ($PassThru.IsPresent) {
        $commandInfo = Get-Command -Name $entryPointPath -ErrorAction SilentlyContinue
        if ($null -ne $commandInfo -and $commandInfo.Parameters.ContainsKey("PassThru")) {
            $invokeParameters.PassThru = $true
        }
    }

    return & $entryPointPath @invokeParameters
}
