function Get-BKAuthenticationMethodsSummary {
    [CmdletBinding()]
    param(
        [switch]$SkipGraphConnect
    )

    Write-BKLog -Message "Collecting authentication methods registration summary..." -Level Info

    try {
        if (-not $SkipGraphConnect) {
            Connect-BKGraph -Scopes @(
                "AuditLog.Read.All",
                "Directory.Read.All"
            ) | Out-Null
        }

        $details = Get-MgReportAuthenticationMethodUserRegistrationDetail -All -ErrorAction Stop

        $totalUsers = ($details | Measure-Object).Count
        $mfaRegistered = ($details | Where-Object { $_.IsMfaRegistered -eq $true } | Measure-Object).Count
        $mfaCapable = ($details | Where-Object { $_.IsMfaCapable -eq $true } | Measure-Object).Count
        $passwordlessCapable = ($details | Where-Object { $_.IsPasswordlessCapable -eq $true } | Measure-Object).Count
        $ssprRegistered = ($details | Where-Object { $_.IsSsprRegistered -eq $true } | Measure-Object).Count
        $adminUsers = ($details | Where-Object { $_.IsAdmin -eq $true } | Measure-Object).Count

        $mfaRegisteredPercent = if ($totalUsers -gt 0) { [math]::Round(($mfaRegistered / $totalUsers) * 100, 2) } else { 0 }
        $mfaCapablePercent = if ($totalUsers -gt 0) { [math]::Round(($mfaCapable / $totalUsers) * 100, 2) } else { 0 }
        $passwordlessPercent = if ($totalUsers -gt 0) { [math]::Round(($passwordlessCapable / $totalUsers) * 100, 2) } else { 0 }
        $ssprRegisteredPercent = if ($totalUsers -gt 0) { [math]::Round(($ssprRegistered / $totalUsers) * 100, 2) } else { 0 }

        [PSCustomObject]@{
            TotalUsers                 = $totalUsers
            AdminUsers                 = $adminUsers
            MfaRegistered              = $mfaRegistered
            MfaRegisteredPercent       = $mfaRegisteredPercent
            MfaCapable                 = $mfaCapable
            MfaCapablePercent          = $mfaCapablePercent
            PasswordlessCapable        = $passwordlessCapable
            PasswordlessCapablePercent = $passwordlessPercent
            SsprRegistered             = $ssprRegistered
            SsprRegisteredPercent      = $ssprRegisteredPercent
            Timestamp                  = (Get-Date).ToUniversalTime().ToString("o")
        }
    }
    catch {
        Write-BKLog -Message $_.Exception.Message -Level Error
        throw
    }
}