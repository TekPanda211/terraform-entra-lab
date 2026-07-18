function ConvertTo-BKArray {
    [CmdletBinding()]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Value,

        [Parameter()]
        [switch]$RemoveNullOrEmpty
    )

    $items = @($Value)

    if ($RemoveNullOrEmpty.IsPresent) {
        $items = @(
            $items |
                Where-Object {
                    $null -ne $_ -and
                    -not [string]::IsNullOrWhiteSpace([string]$_)
                }
        )
    }

    return $items
}
