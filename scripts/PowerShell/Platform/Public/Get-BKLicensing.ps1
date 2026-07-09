function Get-BKLicensing {
    [CmdletBinding()]
    param()

    Write-BKLog -Message "Collecting licensing information..." -Level Info

    try {
        Connect-BKGraph -Scopes @(
            "Organization.Read.All",
            "Directory.Read.All"
        ) | Out-Null

        $skus = Get-MgSubscribedSku -All -ErrorAction Stop

        $skus | ForEach-Object {
            [PSCustomObject]@{
                SkuId             = $_.SkuId
                SkuPartNumber     = $_.SkuPartNumber
                ConsumedUnits     = $_.ConsumedUnits
                EnabledUnits      = $_.PrepaidUnits.Enabled
                SuspendedUnits    = $_.PrepaidUnits.Suspended
                WarningUnits      = $_.PrepaidUnits.Warning
                AppliesTo         = $_.AppliesTo
                Timestamp         = (Get-Date).ToUniversalTime().ToString("o")
            }
        }
    }
    catch {
        Write-BKLog -Message $_.Exception.Message -Level Error
        throw
    }
}