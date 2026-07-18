function Get-BKEngine {
    <#
    .SYNOPSIS
    Returns registered Blackknight One engines.

    .DESCRIPTION
    Provides the public, read-only view of the internal engine registry.
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Name,

        [Parameter()]
        [string]$Category,

        [Parameter()]
        [switch]$IncludeInvalid,

        [Parameter()]
        [switch]$Refresh
    )

    $engines = @(
        Get-BKEngineRegistry `
            -IncludeInvalid:$IncludeInvalid.IsPresent `
            -Refresh:$Refresh.IsPresent
    )

    if (-not [string]::IsNullOrWhiteSpace($Name)) {
        $engines = @(
            $engines |
                Where-Object {
                    $_.Name -like $Name -or
                    $_.DisplayName -like $Name
                }
        )
    }

    if (-not [string]::IsNullOrWhiteSpace($Category)) {
        $engines = @(
            $engines |
                Where-Object {
                    $_.Category -like $Category
                }
        )
    }

    return $engines
}
