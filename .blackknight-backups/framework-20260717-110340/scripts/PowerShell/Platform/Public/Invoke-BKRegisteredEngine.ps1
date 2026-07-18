function Invoke-BKRegisteredEngine {
    <# .SYNOPSIS Invokes a registered engine through the manifest registry. #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)][string]$Name,
        [Parameter()][string]$Operation = "Assessment",
        [Parameter()][hashtable]$Parameters = @{},
        [Parameter()][switch]$PassThru
    )
    Invoke-BKEngine -Name $Name -Operation $Operation -Parameters $Parameters -PassThru:$PassThru.IsPresent
}
