function Invoke-BKGraphPagedRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Uri,

        [Parameter()]
        [ValidateRange(1, 10000)]
        [int]$MaximumPages = 1000
    )

    if (-not (Get-Command -Name Invoke-MgGraphRequest -ErrorAction SilentlyContinue)) {
        throw "Invoke-MgGraphRequest is unavailable. Import Microsoft.Graph.Authentication."
    }

    $items = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri
    $page = 0

    while (-not [string]::IsNullOrWhiteSpace($nextLink)) {
        $page++

        if ($page -gt $MaximumPages) {
            throw "Maximum page limit of $MaximumPages was reached."
        }

        $response = Invoke-MgGraphRequest `
            -Method GET `
            -Uri $nextLink `
            -OutputType PSObject `
            -ErrorAction Stop

        if ($response.PSObject.Properties.Name -contains "value") {
            foreach ($item in @($response.value)) {
                $items.Add($item)
            }
        }
        else {
            $items.Add($response)
        }

        $nextLink = [string]$response.'@odata.nextLink'
    }

    return @($items)
}
