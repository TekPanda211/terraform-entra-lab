function Get-BKTenant {
    [CmdletBinding()]
    param()

    Write-BKLog -Message "Collecting tenant information from Microsoft Graph..." -Level Info

    try {
        $graph = Connect-BKGraph -Scopes @(
            "Organization.Read.All",
            "Directory.Read.All",
            "User.Read.All",
            "Group.Read.All"
        )

        $org = Get-MgOrganization -ErrorAction Stop | Select-Object -First 1
        $domains = Get-MgDomain -All -ErrorAction Stop
        $users = Get-MgUser -All -Property Id,UserType,AccountEnabled -ErrorAction Stop
        $groups = Get-MgGroup -All -Property Id,DisplayName,SecurityEnabled,MailEnabled,AssignableToRole -ErrorAction Stop
        $subscribedSkus = Get-MgSubscribedSku -All -ErrorAction SilentlyContinue

        $guestUsers = $users | Where-Object { $_.UserType -eq "Guest" }
        $enabledUsers = $users | Where-Object { $_.AccountEnabled -eq $true }
        $disabledUsers = $users | Where-Object { $_.AccountEnabled -eq $false }
        $securityGroups = $groups | Where-Object { $_.SecurityEnabled -eq $true }
        $roleAssignableGroups = $groups | Where-Object { $_.AssignableToRole -eq $true }

        [PSCustomObject]@{
            TenantName           = $org.DisplayName
            TenantId             = $graph.TenantId
            Account              = $graph.Account
            VerifiedDomains      = ($domains | Measure-Object).Count
            InitialDomain        = ($domains | Where-Object { $_.IsInitial -eq $true }).Id
            TotalUsers           = ($users | Measure-Object).Count
            EnabledUsers         = ($enabledUsers | Measure-Object).Count
            DisabledUsers        = ($disabledUsers | Measure-Object).Count
            GuestUsers           = ($guestUsers | Measure-Object).Count
            TotalGroups          = ($groups | Measure-Object).Count
            SecurityGroups       = ($securityGroups | Measure-Object).Count
            RoleAssignableGroups = ($roleAssignableGroups | Measure-Object).Count
            SubscribedSkus       = ($subscribedSkus | Measure-Object).Count
            Timestamp            = (Get-Date).ToUniversalTime().ToString("o")
        }
    }
    catch {
        Write-BKLog -Message $_.Exception.Message -Level Error
        throw
    }
}