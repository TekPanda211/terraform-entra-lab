function Show-BKDashboard {
    <#
    .SYNOPSIS
    Opens the interactive Blackknight One operations dashboard.

    .DESCRIPTION
    Provides a menu-driven launcher for Blackknight One assessments and
    platform operations.

    Dashboard options:

    1. Terraform Assessment
    2. Microsoft Graph Assessment
    3. Conditional Access What If
    4. Identity Assessment
    5. Trust Assessment
    6. Governance Assessment
    7. Correlation Assessment
    8. Operations Assessment
    9. Platform Validation
    10. Command Inventory
    11. Microsoft Graph Connection
    12. Platform Settings

    The dashboard remains open until the user selects Quit.

    .PARAMETER TerraformPath
    Specifies the default Terraform project directory.

    .PARAMETER ReportRoot
    Specifies the root directory for generated reports.

    .PARAMETER ExportReports
    Automatically exports reports from assessments that support JSON output.

    .PARAMETER NoClear
    Prevents the console from being cleared between menu displays.

    .EXAMPLE
    Show-BKDashboard

    .EXAMPLE
    Show-BKDashboard `
        -TerraformPath ".\terraform" `
        -ExportReports

    .EXAMPLE
    Show-BKDashboard -NoClear
    #>

    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$TerraformPath = ".\terraform",

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ReportRoot = ".\reports",

        [Parameter()]
        [switch]$ExportReports,

        [Parameter()]
        [switch]$NoClear
    )

    $ErrorActionPreference = "Stop"

    # Resolve dashboard paths before creating scriptblock closures so the
    # closures capture stable, non-null values even if a child assessment
    # reloads or removes the Blackknight module.
    $candidateRoot = Get-Item `
        -LiteralPath (Get-Location).Path `
        -ErrorAction Stop

    $repoRoot = $null

    while ($null -ne $candidateRoot) {
        $candidateModulePath = Join-Path `
            -Path $candidateRoot.FullName `
            -ChildPath (
                "scripts\PowerShell\Platform\" +
                "Blackknight-Platform.psm1"
            )

        if (
            Test-Path `
                -LiteralPath $candidateModulePath `
                -PathType Leaf
        ) {
            $repoRoot = $candidateRoot.FullName
            break
        }

        $candidateRoot = $candidateRoot.Parent
    }

    if ([string]::IsNullOrWhiteSpace($repoRoot)) {
        $repoRoot = (Get-Location).Path
    }

    $resolvedTerraformPath = if (
        [System.IO.Path]::IsPathRooted($TerraformPath)
    ) {
        [System.IO.Path]::GetFullPath($TerraformPath)
    }
    else {
        [System.IO.Path]::GetFullPath(
            (
                Join-Path `
                    -Path $repoRoot `
                    -ChildPath $TerraformPath
            )
        )
    }

    $resolvedReportRoot = if (
        [System.IO.Path]::IsPathRooted($ReportRoot)
    ) {
        [System.IO.Path]::GetFullPath($ReportRoot)
    }
    else {
        [System.IO.Path]::GetFullPath(
            (
                Join-Path `
                    -Path $repoRoot `
                    -ChildPath $ReportRoot
            )
        )
    }


    $sbWriteBKDashboardHeader = {
        [CmdletBinding()]
        param()

        if (-not $NoClear.IsPresent) {
            Clear-Host
        }

        Write-Host ""
        Write-Host "============================================================" `
            -ForegroundColor Cyan
        Write-Host "                    BLACKKNIGHT ONE" `
            -ForegroundColor Cyan
        Write-Host "              ENTERPRISE ASSESSMENT PLATFORM" `
            -ForegroundColor Cyan
        Write-Host "============================================================" `
            -ForegroundColor Cyan
        Write-Host ""
    }.GetNewClosure()

    $sbWriteBKDashboardMenu = {
        [CmdletBinding()]
        param()

        Write-Host "Assessment Engines" -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"
        Write-Host "  [1] Terraform Assessment"
        Write-Host "  [2] Microsoft Graph Assessment"
        Write-Host "  [3] Conditional Access What If"
        Write-Host ""
        Write-Host "Identity and Security" -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"
        Write-Host "  [4] Identity Assessment"
        Write-Host "  [5] Trust Assessment"
        Write-Host "  [6] Governance Assessment"
        Write-Host "  [7] Correlation Assessment"
        Write-Host ""
        Write-Host "Platform" -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"
        Write-Host "  [8] Operations Assessment"
        Write-Host "  [9] Platform Validation"
        Write-Host " [10] Command Inventory"
        Write-Host ""
        Write-Host "Configuration" -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"
        Write-Host " [11] Microsoft Graph Connection"
        Write-Host " [12] Platform Settings"
        Write-Host ""
        Write-Host "  [Q] Quit"
        Write-Host ""
    }.GetNewClosure()

    $sbWaitBKDashboard = {
        [CmdletBinding()]
        param()

        Write-Host ""
        $null = Read-Host "Press Enter to return to the dashboard"
    }.GetNewClosure()

    $sbTestBKDashboardCommand = {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Name
        )

        return $null -ne (
            Get-Command `
                -Name $Name `
                -ErrorAction SilentlyContinue
        )
    }.GetNewClosure()

    $sbGetBKDashboardRepoRoot = {
        [CmdletBinding()]
        param()

        $candidate = Get-Item `
            -LiteralPath (Get-Location).Path `
            -ErrorAction Stop

        while ($null -ne $candidate) {
            $modulePath = Join-Path `
                -Path $candidate.FullName `
                -ChildPath (
                    "scripts\PowerShell\Platform\" +
                    "Blackknight-Platform.psm1"
                )

            if (
                Test-Path `
                    -LiteralPath $modulePath `
                    -PathType Leaf
            ) {
                return $candidate.FullName
            }

            $candidate = $candidate.Parent
        }

        return (Get-Location).Path
    }.GetNewClosure()

    $sbResolveBKDashboardPath = {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Path,

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$BasePath
        )

        if ([System.IO.Path]::IsPathRooted($Path)) {
            return [System.IO.Path]::GetFullPath($Path)
        }

        return [System.IO.Path]::GetFullPath(
            (
                Join-Path `
                    -Path $BasePath `
                    -ChildPath $Path
            )
        )
    }.GetNewClosure()

    $sbInvokeBKDashboardScript = {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string[]]$CandidatePaths,

            [Parameter()]
            [hashtable]$Parameters = @{},

            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$DisplayName
        )

        $scriptPath = $CandidatePaths |
            Where-Object {
                Test-Path `
                    -LiteralPath $_ `
                    -PathType Leaf
            } |
            Select-Object -First 1

        if ([string]::IsNullOrWhiteSpace($scriptPath)) {
            Write-Host ""
            Write-Host "[NOT AVAILABLE] $DisplayName" `
                -ForegroundColor DarkYellow
            Write-Host "No registered command or engine script was found."
            Write-Host ""
            Write-Host "Checked paths:"

            foreach ($candidatePath in $CandidatePaths) {
                Write-Host "  $candidatePath"
            }

            return $null
        }

        Write-Verbose "Invoking engine script: $scriptPath"

        return & $scriptPath @Parameters
    }.GetNewClosure()


    $sbReadBKDashboardYesNo = {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [ValidateNotNullOrEmpty()]
            [string]$Prompt,

            [Parameter()]
            [bool]$Default = $false
        )

        $suffix = if ($Default) { "[Y/n]" } else { "[y/N]" }
        $response = Read-Host "$Prompt $suffix"

        if ([string]::IsNullOrWhiteSpace($response)) {
            return $Default
        }

        return $response -match '^(Y|YES)$'
    }.GetNewClosure()

    $sbConnectBKDashboardGraph = {
        [CmdletBinding()]
        param(
            [Parameter()]
            [string[]]$RequiredScopes = @(),

            [Parameter()]
            [switch]$ForceReconnect
        )

        if (-not (& $sbTestBKDashboardCommand -Name "Connect-MgGraph")) {
            throw "Connect-MgGraph is unavailable. Install or import the Microsoft Graph PowerShell SDK."
        }

        $currentContext = $null
        if (& $sbTestBKDashboardCommand -Name "Get-MgContext") {
            $currentContext = Get-MgContext -ErrorAction SilentlyContinue
        }

        $missingScopes = @()
        if ($null -ne $currentContext -and $RequiredScopes.Count -gt 0) {
            $currentScopes = @($currentContext.Scopes | ForEach-Object { [string]$_ })
            $missingScopes = @($RequiredScopes | Where-Object { $_ -notin $currentScopes })
        }

        $reconnectRequired = $ForceReconnect.IsPresent -or $null -eq $currentContext -or $missingScopes.Count -gt 0

        if (-not $reconnectRequired) {
            return $currentContext
        }

        if ($null -ne $currentContext) {
            Write-Host ""
            Write-Host "Current Microsoft Graph connection" -ForegroundColor Cyan
            Write-Host "------------------------------------------------------------"
            $currentContext | Select-Object Account,TenantId,Environment,AuthType,Scopes | Format-List | Out-Host

            if ($missingScopes.Count -gt 0) {
                Write-Host ""
                Write-Host ("The current connection is missing required scopes: " + ($missingScopes -join ", ")) -ForegroundColor DarkYellow
            }

            $reconnect = & $sbReadBKDashboardYesNo -Prompt "Reconnect Microsoft Graph?" -Default $true
            if (-not $reconnect) {
                if ($missingScopes.Count -gt 0) {
                    throw "The current Graph context does not have the required scopes."
                }
                return $currentContext
            }

            if (& $sbTestBKDashboardCommand -Name "Disconnect-MgGraph") {
                Disconnect-MgGraph | Out-Null
            }
        }

        Write-Host ""
        Write-Host "Microsoft Graph Connection" -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------"
        Write-Host "Enter a tenant ID, or press Enter to select the tenant during sign-in."
        $tenantId = Read-Host "Tenant ID"

        if (-not [string]::IsNullOrWhiteSpace($tenantId) -and $tenantId -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
            throw "The tenant ID is not a valid GUID."
        }

        $connectionParameters = @{ ContextScope = "Process"; NoWelcome = $true }
        if ($RequiredScopes.Count -gt 0) { $connectionParameters.Scopes = @($RequiredScopes | Sort-Object -Unique) }
        if (-not [string]::IsNullOrWhiteSpace($tenantId)) { $connectionParameters.TenantId = $tenantId }

        Connect-MgGraph @connectionParameters
        $newContext = Get-MgContext -ErrorAction SilentlyContinue
        if ($null -eq $newContext) { throw "Microsoft Graph did not return an active context." }
        if (-not [string]::IsNullOrWhiteSpace($tenantId) -and $newContext.TenantId -ne $tenantId) {
            throw "The connected tenant does not match the requested tenant."
        }

        Write-Host ""
        Write-Host "Connected Microsoft Graph Context" -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------"
        $newContext | Select-Object Account,TenantId,Environment,AuthType,Scopes | Format-List | Out-Host
        return $newContext
    }.GetNewClosure()

    $sbShowBKDashboardGraphConnection = {
        [CmdletBinding()]
        param()

        $context = & $sbConnectBKDashboardGraph -RequiredScopes @("Policy.Read.ConditionalAccess","User.Read.All")
        Write-Host ""
        Write-Host "Active Graph connection" -ForegroundColor Green
        $context | Select-Object Account,TenantId,Environment,AuthType,Scopes | Format-List | Out-Host
    }.GetNewClosure()

    $sbShowBKDashboardSettings = {
        [CmdletBinding()]
        param()

        Write-Host ""
        Write-Host "Platform Settings" -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"
        Write-Host "Repository Root : $repoRoot"
        Write-Host "Terraform Path  : $resolvedTerraformPath"
        Write-Host "Report Root     : $resolvedReportRoot"
        Write-Host "Export Reports  : $($ExportReports.IsPresent)"
        Write-Host "Clear Console   : $(-not $NoClear.IsPresent)"
        Write-Host ""
        Write-Host "Settings are currently supplied through Show-BKDashboard parameters." -ForegroundColor DarkYellow
    }.GetNewClosure()

    $sbInvokeBKDashboardTerraform = {
        [CmdletBinding()]
        param()

        Write-Host ""
        Write-Host "Terraform Assessment" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        if (
            -not (
                Test-Path `
                    -LiteralPath $resolvedTerraformPath `
                    -PathType Container
            )
        ) {
            Write-Host ""
            Write-Host "[ERROR] Terraform directory was not found:" `
                -ForegroundColor Red
            Write-Host $resolvedTerraformPath

            return
        }

        $parameters = @{
            Path     = $resolvedTerraformPath
            PassThru = $true
        }

        if ($ExportReports.IsPresent) {
            $parameters.ExportJson = $true
            $parameters.OutputPath = Join-Path `
                -Path $resolvedReportRoot `
                -ChildPath "terraform\terraform-assessment.json"
        }
        else {
            $exportChoice = Read-Host `
                "Export the Terraform assessment to JSON? [Y/N]"

            if ($exportChoice -match '^(Y|YES)$') {
                $parameters.ExportJson = $true
                $parameters.OutputPath = Join-Path `
                    -Path $resolvedReportRoot `
                    -ChildPath "terraform\terraform-assessment.json"
            }
        }

        if (
            & $sbTestBKDashboardCommand `
                -Name "Invoke-BKTerraformAssessment"
        ) {
            $result =
                Invoke-BKTerraformAssessment @parameters
        }
        else {
            $result = & $sbInvokeBKDashboardScript `
                -CandidatePaths @(
                    (
                        Join-Path `
                            -Path $repoRoot `
                            -ChildPath (
                                "scripts\PowerShell\Terraform\" +
                                "Invoke-BKTerraformAssessment.ps1"
                            )
                    )
                ) `
                -Parameters $parameters `
                -DisplayName "Terraform Assessment"
        }

        if (
            $null -ne $result -and
            $null -ne $result.Summary
        ) {
            Write-Host ""
            Write-Host "Terraform Executive Result" `
                -ForegroundColor Cyan
            Write-Host "------------------------------------------------------------"

            $result.Summary |
                Format-List |
                Out-Host
        }
    }.GetNewClosure()

    $sbInvokeBKDashboardGraph = {
        [CmdletBinding()]
        param()

        Write-Host ""
        Write-Host "Microsoft Graph Assessment" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"
        Write-Host ""

        if (
            -not (
                & $sbTestBKDashboardCommand `
                    -Name "Connect-MgGraph"
            )
        ) {
            Write-Host (
                "[NOT AVAILABLE] Connect-MgGraph is not installed " +
                "or loaded."
            ) -ForegroundColor DarkYellow

            return
        }

        $currentContext = $null

        if (
            & $sbTestBKDashboardCommand `
                -Name "Get-MgContext"
        ) {
            $currentContext = Get-MgContext `
                -ErrorAction SilentlyContinue
        }

        if ($null -ne $currentContext) {
            Write-Host "Current Microsoft Graph connection:" `
                -ForegroundColor Cyan

            $currentContext |
                Select-Object `
                    Account,
                    TenantId,
                    Environment,
                    AuthType |
                Format-List |
                Out-Host

            $disconnectChoice = Read-Host (
                "Disconnect the current Microsoft Graph session? [Y/N]"
            )

            if ($disconnectChoice -match '^(Y|YES)$') {
                if (
                    & $sbTestBKDashboardCommand `
                        -Name "Disconnect-MgGraph"
                ) {
                    Disconnect-MgGraph |
                        Out-Null

                    Write-Host ""
                    Write-Host (
                        "Current Microsoft Graph session disconnected."
                    ) -ForegroundColor Green
                }
            }
        }

        $availableEnvironments = @()

        if (
            & $sbTestBKDashboardCommand `
                -Name "Get-MgEnvironment"
        ) {
            $availableEnvironments = @(
                Get-MgEnvironment |
                    Sort-Object Name
            )
        }

        $selectedEnvironment = "Global"

        if ($availableEnvironments.Count -gt 0) {
            Write-Host ""
            Write-Host "Available Microsoft Graph environments:" `
                -ForegroundColor Cyan
            Write-Host ""

            for (
                $index = 0;
                $index -lt $availableEnvironments.Count;
                $index++
            ) {
                Write-Host (
                    "  [{0}] {1}" -f
                    ($index + 1),
                    $availableEnvironments[$index].Name
                )
            }

            Write-Host ""
            Write-Host "Press Enter to use the Global public cloud."

            $environmentSelection = Read-Host (
                "Select Microsoft Graph environment"
            )

            if (
                -not [string]::IsNullOrWhiteSpace(
                    $environmentSelection
                )
            ) {
                $environmentNumber = 0

                if (
                    [int]::TryParse(
                        $environmentSelection,
                        [ref]$environmentNumber
                    ) -and
                    $environmentNumber -ge 1 -and
                    $environmentNumber -le
                    $availableEnvironments.Count
                ) {
                    $selectedEnvironment =
                        $availableEnvironments[
                            $environmentNumber - 1
                        ].Name
                }
                else {
                    Write-Host ""
                    Write-Host (
                        "Invalid environment selection. Using Global."
                    ) -ForegroundColor DarkYellow
                }
            }
        }

        Write-Host ""
        Write-Host "Target Tenant" `
            -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------"
        Write-Host (
            "Enter the Microsoft Entra tenant ID you want to assess."
        )
        Write-Host (
            "Example: 00000000-0000-0000-0000-000000000000"
        )
        Write-Host ""
        Write-Host (
            "Press Enter without a tenant ID to choose the tenant " +
            "during sign-in."
        )

        $tenantId = Read-Host "Tenant ID"

        if (
            -not [string]::IsNullOrWhiteSpace(
                $tenantId
            ) -and
            $tenantId -notmatch (
                '^[0-9a-fA-F]{8}-' +
                '[0-9a-fA-F]{4}-' +
                '[0-9a-fA-F]{4}-' +
                '[0-9a-fA-F]{4}-' +
                '[0-9a-fA-F]{12}$'
            )
        ) {
            Write-Host ""
            Write-Host (
                "[ERROR] The tenant ID is not a valid GUID."
            ) -ForegroundColor Red

            return
        }

        $connectedWithBlackknight = $false

        if (
            & $sbTestBKDashboardCommand `
                -Name "Connect-BKGraph"
        ) {
            $bkGraphCommand = Get-Command `
                -Name "Connect-BKGraph" `
                -ErrorAction SilentlyContinue

            $supportsTenantId =
                $bkGraphCommand.Parameters.ContainsKey(
                    "TenantId"
                )

            $supportsEnvironment =
                $bkGraphCommand.Parameters.ContainsKey(
                    "Environment"
                )

            if (
                $supportsTenantId -and
                $supportsEnvironment
            ) {
                $bkConnectionParameters = @{
                    Environment = $selectedEnvironment
                }

                if (
                    -not [string]::IsNullOrWhiteSpace(
                        $tenantId
                    )
                ) {
                    $bkConnectionParameters.TenantId =
                        $tenantId
                }

                Write-Host ""
                Write-Host "Connecting through Connect-BKGraph..." `
                    -ForegroundColor Yellow

                Connect-BKGraph @bkConnectionParameters

                $connectedWithBlackknight = $true
            }
        }

        if (-not $connectedWithBlackknight) {
            $connectionParameters = @{
                Environment  = $selectedEnvironment
                ContextScope = "Process"
                NoWelcome    = $true
            }

            if (
                -not [string]::IsNullOrWhiteSpace(
                    $tenantId
                )
            ) {
                $connectionParameters.TenantId =
                    $tenantId
            }

            Write-Host ""
            Write-Host (
                "Connecting directly through Microsoft Graph PowerShell..."
            ) -ForegroundColor Yellow

            Connect-MgGraph @connectionParameters
        }

        $graphContext = Get-MgContext `
            -ErrorAction SilentlyContinue

        if ($null -eq $graphContext) {
            Write-Host ""
            Write-Host (
                "[ERROR] Microsoft Graph did not return an active context."
            ) -ForegroundColor Red

            return
        }

        Write-Host ""
        Write-Host "Connected Microsoft Graph Context" `
            -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------"

        $graphContext |
            Select-Object `
                Account,
                TenantId,
                Environment,
                AuthType,
                ContextScope,
                Scopes |
            Format-List |
            Out-Host

        if (
            -not [string]::IsNullOrWhiteSpace(
                $tenantId
            ) -and
            $graphContext.TenantId -ne $tenantId
        ) {
            Write-Host ""
            Write-Host (
                "[WARNING] The connected tenant does not match " +
                "the requested tenant."
            ) -ForegroundColor Red

            Write-Host "Requested tenant : $tenantId"
            Write-Host "Connected tenant : $($graphContext.TenantId)"
            Write-Host ""
            Write-Host (
                "The assessment was stopped to prevent collection " +
                "from the wrong tenant."
            ) -ForegroundColor Red

            return
        }

        Write-Host ""
        $continueChoice = Read-Host (
            "Run the Graph assessment against this tenant? [Y/N]"
        )

        if ($continueChoice -notmatch '^(Y|YES)$') {
            Write-Host ""
            Write-Host "Microsoft Graph assessment cancelled." `
                -ForegroundColor DarkYellow

            return
        }

        if (
            & $sbTestBKDashboardCommand `
                -Name "Invoke-BKGraphAssessment"
        ) {
            Write-Host ""
            Write-Host "Microsoft Graph Assessment" `
                -ForegroundColor Cyan
            Write-Host "------------------------------------------------------------"

            $graphAssessmentParameters = @{
                IncludeObjects = $true
                PassThru       = $true
            }

            if ($ExportReports.IsPresent) {
                $graphAssessmentParameters.ExportJson = $true

                $graphAssessmentParameters.OutputPath = Join-Path `
                    -Path $resolvedReportRoot `
                    -ChildPath "graph\graph-assessment.json"
            }
            else {
                $exportChoice = Read-Host (
                    "Export the Graph assessment to JSON? [Y/N]"
                )

                if ($exportChoice -match '^(Y|YES)$') {
                    $graphAssessmentParameters.ExportJson = $true

                    $graphAssessmentParameters.OutputPath = Join-Path `
                        -Path $resolvedReportRoot `
                        -ChildPath "graph\graph-assessment.json"
                }
            }

            $graphAssessment =
                Invoke-BKGraphAssessment `
                    @graphAssessmentParameters

            if (
                $null -ne $graphAssessment -and
                $null -ne $graphAssessment.Summary
            ) {
                Write-Host ""
                Write-Host "Graph Executive Result" `
                    -ForegroundColor Cyan
                Write-Host "------------------------------------------------------------"

                $graphAssessment.Summary |
                    Format-List |
                    Out-Host
            }
        }
        elseif (
            & $sbTestBKDashboardCommand `
                -Name "Get-BKTenantDiscovery"
        ) {
            Write-Host ""
            Write-Host (
                "Graph assessment command unavailable. " +
                "Running tenant discovery instead."
            ) -ForegroundColor DarkYellow

            Get-BKTenantDiscovery `
                -IncludeObjects `
                -PassThru |
                Out-Host
        }
        else {
            Write-Host ""
            Write-Host (
                "The Graph connection succeeded, but no Graph " +
                "assessment or tenant-discovery command is available."
            ) -ForegroundColor DarkYellow
        }
    }.GetNewClosure()


    $sbInvokeBKDashboardConditionalAccess = {
        [CmdletBinding()]
        param()

        Write-Host ""
        Write-Host "Conditional Access What If" -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        if (-not (& $sbTestBKDashboardCommand -Name "Invoke-BKConditionalAccessWhatIf")) {
            Write-Host ""
            Write-Host "[NOT AVAILABLE] Invoke-BKConditionalAccessWhatIf is not loaded." -ForegroundColor DarkYellow
            return
        }

        $null = & $sbConnectBKDashboardGraph -RequiredScopes @("Policy.Read.ConditionalAccess","User.Read.All")

        Write-Host ""
        Write-Host "Scenario" -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------"
        Write-Host "  [1] Administrator from non-compliant Windows device"
        Write-Host "  [2] Standard user from compliant Windows device"
        Write-Host "  [3] Guest user from foreign country"
        Write-Host "  [4] Legacy authentication attempt"
        Write-Host "  [5] High-risk user sign-in"
        Write-Host "  [6] Emergency access account"
        Write-Host "  [7] Custom scenario"
        Write-Host ""

        $scenarioSelection = Read-Host "Select scenario"
        $scenario = @{ DevicePlatform="windows"; ClientAppType="browser"; SignInRiskLevel="none"; UserRiskLevel="none"; IsCompliant=$false; Country="US" }

        switch ($scenarioSelection) {
            "2" { $scenario.IsCompliant = $true }
            "3" { $scenario.Country = "" }
            "4" { $scenario.ClientAppType = "other" }
            "5" { $scenario.SignInRiskLevel = "high"; $scenario.UserRiskLevel = "high" }
            "7" { $scenario.DevicePlatform=""; $scenario.ClientAppType=""; $scenario.SignInRiskLevel=""; $scenario.UserRiskLevel=""; $scenario.Country=""; $scenario.Remove("IsCompliant") }
        }

        Write-Host ""
        Write-Host "Identity" -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------"
        $userPrincipalName = Read-Host "User principal name"
        if ([string]::IsNullOrWhiteSpace($userPrincipalName)) {
            Write-Host "[ERROR] A user principal name is required." -ForegroundColor Red
            return
        }

        Write-Host ""
        Write-Host "Application" -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------"
        Write-Host "  [1] Microsoft Graph"
        Write-Host "  [2] Azure Management"
        Write-Host "  [3] Exchange Online"
        Write-Host "  [4] SharePoint Online"
        Write-Host "  [5] Microsoft Teams"
        Write-Host "  [6] Custom application ID"
        Write-Host ""

        $applicationSelection = Read-Host "Select application"
        $applicationPresets = @{
            "1" = @{ Name="Microsoft Graph"; Id="00000003-0000-0000-c000-000000000000" }
            "2" = @{ Name="Azure Management"; Id="797f4846-ba00-4fd7-ba43-dac1f8f63013" }
            "3" = @{ Name="Exchange Online"; Id="00000002-0000-0ff1-ce00-000000000000" }
            "4" = @{ Name="SharePoint Online"; Id="00000003-0000-0ff1-ce00-000000000000" }
            "5" = @{ Name="Microsoft Teams"; Id="1fec8e78-bce4-4aaf-ab1b-5451cc387264" }
        }

        if ($applicationSelection -eq "6") {
            $applicationId = Read-Host "Application ID"
            $applicationName = "Custom Application"
        }
        elseif ($applicationPresets.ContainsKey($applicationSelection)) {
            $applicationId = $applicationPresets[$applicationSelection].Id
            $applicationName = $applicationPresets[$applicationSelection].Name
        }
        else {
            $applicationId = $applicationPresets["1"].Id
            $applicationName = $applicationPresets["1"].Name
        }

        if ($scenarioSelection -in @("3","7")) {
            $country = Read-Host "Two-letter country code [US]"
            if ([string]::IsNullOrWhiteSpace($country)) { $country = "US" }
            $scenario.Country = $country.ToUpperInvariant()
        }

        if ($scenarioSelection -eq "7") {
            $platform = Read-Host "Device platform [windows/android/iOS/linux/macOS]"
            if ([string]::IsNullOrWhiteSpace($platform)) { $platform = "windows" }
            $scenario.DevicePlatform = $platform

            $clientApp = Read-Host "Client type [browser/mobileAppsAndDesktopClients/other]"
            if ([string]::IsNullOrWhiteSpace($clientApp)) { $clientApp = "browser" }
            $scenario.ClientAppType = $clientApp

            $signInRisk = Read-Host "Sign-in risk [none/low/medium/high]"
            if ([string]::IsNullOrWhiteSpace($signInRisk)) { $signInRisk = "none" }
            $scenario.SignInRiskLevel = $signInRisk

            $userRisk = Read-Host "User risk [none/low/medium/high]"
            if ([string]::IsNullOrWhiteSpace($userRisk)) { $userRisk = "none" }
            $scenario.UserRiskLevel = $userRisk

            $complianceChoice = Read-Host "Device compliance [C]ompliant, [N]on-compliant, [U]nspecified"
            switch ($complianceChoice.ToUpperInvariant()) {
                "C" { $scenario.IsCompliant = $true }
                "N" { $scenario.IsCompliant = $false }
                default { $scenario.Remove("IsCompliant") }
            }
        }

        $ipAddress = Read-Host "Source IP address [optional]"
        $appliedOnly = & $sbReadBKDashboardYesNo -Prompt "Show applied policies only?" -Default $false
        $exportJson = if ($ExportReports.IsPresent) { $true } else { & $sbReadBKDashboardYesNo -Prompt "Export the result to JSON?" -Default $true }

        $parameters = @{
            UserPrincipalName   = $userPrincipalName
            ApplicationId      = $applicationId
            DevicePlatform     = $scenario.DevicePlatform
            ClientAppType      = $scenario.ClientAppType
            SignInRiskLevel    = $scenario.SignInRiskLevel
            UserRiskLevel      = $scenario.UserRiskLevel
            AppliedPoliciesOnly = $appliedOnly
            PassThru           = $true
        }

        if (-not [string]::IsNullOrWhiteSpace($scenario.Country)) { $parameters.Country = $scenario.Country }
        if ($scenario.ContainsKey("IsCompliant")) { $parameters.IsCompliant = $scenario.IsCompliant }
        if (-not [string]::IsNullOrWhiteSpace($ipAddress)) { $parameters.IpAddress = $ipAddress }
        if ($exportJson) {
            $parameters.ExportJson = $true
            $parameters.OutputPath = Join-Path -Path $resolvedReportRoot -ChildPath "conditional-access\conditional-access-what-if.json"
        }

        Write-Host ""
        Write-Host "Scenario Summary" -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------"
        Write-Host "User          : $userPrincipalName"
        Write-Host "Application   : $applicationName"
        Write-Host "Application ID: $applicationId"
        Write-Host "Platform      : $($scenario.DevicePlatform)"
        Write-Host "Client Type   : $($scenario.ClientAppType)"
        Write-Host "Country       : $($scenario.Country)"
        Write-Host "Sign-in Risk  : $($scenario.SignInRiskLevel)"
        Write-Host "User Risk     : $($scenario.UserRiskLevel)"
        if ($scenario.ContainsKey("IsCompliant")) { Write-Host "Compliant     : $($scenario.IsCompliant)" } else { Write-Host "Compliant     : Not specified" }
        Write-Host ""

        if (-not (& $sbReadBKDashboardYesNo -Prompt "Run this Conditional Access simulation?" -Default $true)) {
            Write-Host "Conditional Access simulation cancelled." -ForegroundColor DarkYellow
            return
        }

        $result = Invoke-BKConditionalAccessWhatIf @parameters
        if ($null -ne $result -and $null -ne $result.Summary) {
            Write-Host ""
            Write-Host "Conditional Access Executive Result" -ForegroundColor Cyan
            Write-Host "------------------------------------------------------------"
            $result.Summary | Format-List | Out-Host

            Write-Host ""
            Write-Host "Next Actions" -ForegroundColor Yellow
            Write-Host "------------------------------------------------------------"
            Write-Host "  [1] Run another Conditional Access simulation"
            Write-Host "  [2] Return to dashboard"
            Write-Host ""
            if ((Read-Host "Select next action") -eq "1") { & $sbInvokeBKDashboardConditionalAccess }
        }
    }.GetNewClosure()

    $sbInvokeBKDashboardIdentity = {
        [CmdletBinding()]
        param()

        Write-Host ""
        Write-Host "Identity Assessment" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        $parameters = @{}

        if ($ExportReports.IsPresent) {
            $parameters.ExportJson = $true
        }

        if (
            & $sbTestBKDashboardCommand `
                -Name "Invoke-BKIdentityAssessment"
        ) {
            Invoke-BKIdentityAssessment @parameters |
                Out-Host

            return
        }

        if (
            & $sbTestBKDashboardCommand `
                -Name "Invoke-BKIdentityDiscovery"
        ) {
            Invoke-BKIdentityDiscovery @parameters |
                Out-Host

            return
        }

        & $sbInvokeBKDashboardScript `
            -CandidatePaths @(
                (
                    Join-Path `
                        -Path $repoRoot `
                        -ChildPath (
                            "scripts\PowerShell\Identity\" +
                            "Invoke-BKIdentityAssessment.ps1"
                        )
                )
                (
                    Join-Path `
                        -Path $repoRoot `
                        -ChildPath (
                            "scripts\PowerShell\Identity\" +
                            "Invoke-BKIdentityDiscovery.ps1"
                        )
                )
            ) `
            -Parameters $parameters `
            -DisplayName "Identity Assessment" |
            Out-Host
    }.GetNewClosure()

    $sbInvokeBKDashboardTrust = {
        [CmdletBinding()]
        param()

        Write-Host ""
        Write-Host "Trust Assessment" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        $parameters = @{}

        if ($ExportReports.IsPresent) {
            $parameters.ExportJson = $true
        }

        if (
            & $sbTestBKDashboardCommand `
                -Name "Invoke-BKTrustAssessment"
        ) {
            Invoke-BKTrustAssessment @parameters |
                Out-Host

            return
        }

        if (
            & $sbTestBKDashboardCommand `
                -Name "Invoke-BKTrustDiscovery"
        ) {
            Invoke-BKTrustDiscovery @parameters |
                Out-Host

            return
        }

        & $sbInvokeBKDashboardScript `
            -CandidatePaths @(
                (
                    Join-Path `
                        -Path $repoRoot `
                        -ChildPath (
                            "scripts\PowerShell\Trust\" +
                            "Invoke-BKTrustAssessment.ps1"
                        )
                )
                (
                    Join-Path `
                        -Path $repoRoot `
                        -ChildPath (
                            "scripts\PowerShell\Trust\" +
                            "Invoke-BKTrustDiscovery.ps1"
                        )
                )
            ) `
            -Parameters $parameters `
            -DisplayName "Trust Assessment" |
            Out-Host
    }.GetNewClosure()

    $sbInvokeBKDashboardGovernance = {
        [CmdletBinding()]
        param()

        Write-Host ""
        Write-Host "Governance Assessment" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        $parameters = @{}

        if ($ExportReports.IsPresent) {
            $parameters.ExportJson = $true
        }

        if (
            & $sbTestBKDashboardCommand `
                -Name "Invoke-BKGovernanceAssessment"
        ) {
            Invoke-BKGovernanceAssessment @parameters |
                Out-Host

            return
        }

        if (
            & $sbTestBKDashboardCommand `
                -Name "Invoke-BKIdentityGovernanceAssessment"
        ) {
            Invoke-BKIdentityGovernanceAssessment @parameters |
                Out-Host

            return
        }

        & $sbInvokeBKDashboardScript `
            -CandidatePaths @(
                (
                    Join-Path `
                        -Path $repoRoot `
                        -ChildPath (
                            "scripts\PowerShell\Governance\" +
                            "Invoke-BKGovernanceAssessment.ps1"
                        )
                )
                (
                    Join-Path `
                        -Path $repoRoot `
                        -ChildPath (
                            "scripts\PowerShell\Governance\" +
                            "Invoke-BKIdentityGovernanceAssessment.ps1"
                        )
                )
            ) `
            -Parameters $parameters `
            -DisplayName "Governance Assessment" |
            Out-Host
    }.GetNewClosure()

    $sbInvokeBKDashboardCorrelation = {
        [CmdletBinding()]
        param()

        Write-Host ""
        Write-Host "Correlation Assessment" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        $parameters = @{}

        if ($ExportReports.IsPresent) {
            $parameters.ExportJson = $true
        }

        if (
            & $sbTestBKDashboardCommand `
                -Name "Invoke-BKCorrelationAssessment"
        ) {
            Invoke-BKCorrelationAssessment @parameters |
                Out-Host

            return
        }

        if (
            & $sbTestBKDashboardCommand `
                -Name "Invoke-BKCorrelation"
        ) {
            Invoke-BKCorrelation @parameters |
                Out-Host

            return
        }

        & $sbInvokeBKDashboardScript `
            -CandidatePaths @(
                (
                    Join-Path `
                        -Path $repoRoot `
                        -ChildPath (
                            "scripts\PowerShell\Correlation\" +
                            "Invoke-BKCorrelationAssessment.ps1"
                        )
                )
                (
                    Join-Path `
                        -Path $repoRoot `
                        -ChildPath (
                            "scripts\PowerShell\Correlation\" +
                            "Invoke-BKCorrelation.ps1"
                        )
                )
            ) `
            -Parameters $parameters `
            -DisplayName "Correlation Assessment" |
            Out-Host
    }.GetNewClosure()

    $sbInvokeBKDashboardOperations = {
        [CmdletBinding()]
        param()

        Write-Host ""
        Write-Host "Operations Assessment" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        $parameters = @{}

        if ($ExportReports.IsPresent) {
            $parameters.ExportJson = $true
        }

        if (
            & $sbTestBKDashboardCommand `
                -Name "Invoke-BKOperationsAssessment"
        ) {
            Invoke-BKOperationsAssessment @parameters |
                Out-Host

            return
        }

        if (
            & $sbTestBKDashboardCommand `
                -Name "Invoke-BKOperationsDiscovery"
        ) {
            Invoke-BKOperationsDiscovery @parameters |
                Out-Host

            return
        }

        & $sbInvokeBKDashboardScript `
            -CandidatePaths @(
                (
                    Join-Path `
                        -Path $repoRoot `
                        -ChildPath (
                            "scripts\PowerShell\Operations\" +
                            "Invoke-BKOperationsAssessment.ps1"
                        )
                )
                (
                    Join-Path `
                        -Path $repoRoot `
                        -ChildPath (
                            "scripts\PowerShell\Operations\" +
                            "Invoke-BKOperationsDiscovery.ps1"
                        )
                )
            ) `
            -Parameters $parameters `
            -DisplayName "Operations Assessment" |
            Out-Host
    }.GetNewClosure()

    $sbInvokeBKDashboardPlatformValidation = {
        [CmdletBinding()]
        param()

        Write-Host ""
        Write-Host "Platform Validation" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        if (
            -not (
                & $sbTestBKDashboardCommand `
                    -Name "Test-BKPlatform"
            )
        ) {
            Write-Host ""
            Write-Host "[NOT AVAILABLE] Test-BKPlatform is not loaded." `
                -ForegroundColor DarkYellow

            return
        }

        Test-BKPlatform |
            Out-Host
    }.GetNewClosure()

    $sbShowBKDashboardCommands = {
        [CmdletBinding()]
        param()

        Write-Host ""
        Write-Host "Blackknight One Command Inventory" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        $moduleCommands = @(
            Get-Command `
                -Module "Blackknight-Platform" `
                -ErrorAction SilentlyContinue
        )

        if ($moduleCommands.Count -eq 0) {
            $moduleCommands = @(
                Get-Command `
                    -Name "*-BK*" `
                    -ErrorAction SilentlyContinue
            )
        }

        if ($moduleCommands.Count -eq 0) {
            Write-Host "No Blackknight commands are loaded." `
                -ForegroundColor DarkYellow

            return
        }

        $moduleCommands |
            Sort-Object Name |
            Select-Object `
                Name,
                CommandType,
                Source |
            Format-Table -AutoSize |
            Out-Host

        Write-Host ""
        Write-Host "Total commands: $($moduleCommands.Count)"
    }.GetNewClosure()

    $exitDashboard = $false

    while (-not $exitDashboard) {
        & $sbWriteBKDashboardHeader
        & $sbWriteBKDashboardMenu

        $selection = Read-Host "Enter selection"

        try {
            switch (($selection.Trim()).ToUpperInvariant()) {
                "1" { & $sbInvokeBKDashboardTerraform; & $sbWaitBKDashboard }
                "2" { & $sbInvokeBKDashboardGraph; & $sbWaitBKDashboard }
                "3" { & $sbInvokeBKDashboardConditionalAccess; & $sbWaitBKDashboard }
                "4" { & $sbInvokeBKDashboardIdentity; & $sbWaitBKDashboard }
                "5" { & $sbInvokeBKDashboardTrust; & $sbWaitBKDashboard }
                "6" { & $sbInvokeBKDashboardGovernance; & $sbWaitBKDashboard }
                "7" { & $sbInvokeBKDashboardCorrelation; & $sbWaitBKDashboard }
                "8" { & $sbInvokeBKDashboardOperations; & $sbWaitBKDashboard }
                "9" { & $sbInvokeBKDashboardPlatformValidation; & $sbWaitBKDashboard }
                "10" { & $sbShowBKDashboardCommands; & $sbWaitBKDashboard }
                "11" { & $sbShowBKDashboardGraphConnection; & $sbWaitBKDashboard }
                "12" { & $sbShowBKDashboardSettings; & $sbWaitBKDashboard }
                "Q" { $exitDashboard = $true }
                "QUIT" { $exitDashboard = $true }
                "EXIT" { $exitDashboard = $true }
                default {
                    Write-Host ""
                    Write-Host "[INVALID SELECTION] Enter a number from 1 through 12, or Q to quit." -ForegroundColor Red
                    Start-Sleep -Seconds 2
                }
            }
        }
        catch {
            Write-Host ""
            Write-Host "Operation failed:" `
                -ForegroundColor Red
            Write-Host $_.Exception.Message `
                -ForegroundColor Red

            if (
                & $sbTestBKDashboardCommand `
                    -Name "Write-BKLog"
            ) {
                Write-BKLog `
                    -Message (
                        "Dashboard operation failed: " +
                        $_.Exception.Message
                    ) `
                    -Level Error
            }

            & $sbWaitBKDashboard
        }
    }

    & $sbWriteBKDashboardHeader
    Write-Host "Blackknight One dashboard closed." `
        -ForegroundColor Cyan
    Write-Host ""
}