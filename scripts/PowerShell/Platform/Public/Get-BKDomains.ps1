function Get-BKDomains {
    [CmdletBinding()]
    param()

    Write-BKLog -Message "Collecting domain information..." -Level Info

    try {
        Connect-BKGraph -Scopes @(
            "Domain.Read.All",
            "Directory.Read.All"
        ) | Out-Null

        $domains = Get-MgDomain -All -ErrorAction Stop

        $domains | ForEach-Object {
            [PSCustomObject]@{
                Id                 = $_.Id
                IsInitial          = $_.IsInitial
                IsDefault          = $_.IsDefault
                IsVerified         = $_.IsVerified
                AuthenticationType = $_.AuthenticationType
                SupportedServices  = ($_.SupportedServices -join ", ")
                Timestamp          = (Get-Date).ToUniversalTime().ToString("o")
            }
        }
    }
    catch {
        Write-BKLog -Message $_.Exception.Message -Level Error
        throw
    }
}