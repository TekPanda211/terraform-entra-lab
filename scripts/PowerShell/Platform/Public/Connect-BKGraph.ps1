function Connect-BKGraph {

    [CmdletBinding()]
    param(
        [string[]]$Scopes = @(
            "User.Read.All",
            "Group.Read.All",
            "Directory.Read.All"
        )
    )

    Write-BKLog -Message "Checking Microsoft Graph connection..." -Level Info

    try {

        $context = Get-MgContext -ErrorAction SilentlyContinue

        if (-not $context) {

            Write-BKLog -Message "Connecting to Microsoft Graph..." -Level Info

            Connect-MgGraph -Scopes $Scopes -NoWelcome

            $context = Get-MgContext
        }

        Write-BKLog -Message "Connected to tenant: $($context.TenantId)" -Level Success

        return [PSCustomObject]@{

            Connected = $true

            TenantId = $context.TenantId

            Account = $context.Account

            Environment = $context.Environment

            Scopes = $context.Scopes
        }

    }

    catch {

        Write-BKLog -Message $_.Exception.Message -Level Error

        throw
    }

}