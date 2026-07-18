function Test-BKRequiredGraphScopes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$RequiredScopes,

        [Parameter()]
        [switch]$ThrowOnMissing
    )

    if (-not (Get-Command -Name Get-MgContext -ErrorAction SilentlyContinue)) {
        throw "Get-MgContext is unavailable. Import Microsoft.Graph.Authentication."
    }

    $context = Get-MgContext -ErrorAction SilentlyContinue

    if ($null -eq $context) {
        throw "No active Microsoft Graph context exists."
    }

    $currentScopes = @($context.Scopes | ForEach-Object { [string]$_ })
    $missingScopes = @(
        $RequiredScopes |
            Where-Object {
                $_ -notin $currentScopes
            }
    )

    $result = [PSCustomObject]@{
        TenantId       = $context.TenantId
        Account        = $context.Account
        RequiredScopes = @($RequiredScopes)
        CurrentScopes  = $currentScopes
        MissingScopes  = $missingScopes
        IsSatisfied    = $missingScopes.Count -eq 0
    }

    if ($ThrowOnMissing.IsPresent -and -not $result.IsSatisfied) {
        throw "Missing Microsoft Graph scopes: $($missingScopes -join ', ')"
    }

    return $result
}
