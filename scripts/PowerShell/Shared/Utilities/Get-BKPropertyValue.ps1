function Get-BKPropertyValue {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name,

        [Parameter()]
        [AllowNull()]
        [object]$DefaultValue = $null
    )

    if ($null -eq $InputObject) {
        return $DefaultValue
    }

    foreach ($candidate in $Name) {
        $property = $InputObject.PSObject.Properties[$candidate]

        if ($null -ne $property) {
            return $property.Value
        }
    }

    return $DefaultValue
}
