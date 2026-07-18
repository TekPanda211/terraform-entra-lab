function Get-BKEngineCategory {
    <#
    .SYNOPSIS
    Returns registered Blackknight One engines grouped or filtered by category.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Category = "*",

        [Parameter()]
        [switch]$IncludeInvalid,

        [Parameter()]
        [switch]$Refresh
    )

    $engines = @(
        Get-BKEngine `
            -Category $Category `
            -IncludeInvalid:$IncludeInvalid.IsPresent `
            -Refresh:$Refresh.IsPresent
    )

    return @(
        $engines |
            Sort-Object Category, DisplayName
    )
}
