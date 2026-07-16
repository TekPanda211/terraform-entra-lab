[CmdletBinding(DefaultParameterSetName = "UserId")]
param(
    [Parameter(Mandatory, ParameterSetName = "UserId")]
    [ValidateNotNullOrEmpty()]
    [string]$UserId,

    [Parameter(Mandatory, ParameterSetName = "UserPrincipalName")]
    [ValidateNotNullOrEmpty()]
    [string]$UserPrincipalName,

    [Parameter(Mandatory, ParameterSetName = "ServicePrincipal")]
    [ValidateNotNullOrEmpty()]
    [string]$ServicePrincipalId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$ApplicationId,

    [ValidateSet(
        "android",
        "iOS",
        "linux",
        "macOS",
        "windows",
        "windowsPhone",
        "unknownFutureValue"
    )]
    [string]$DevicePlatform = "windows",

    [ValidateSet(
        "all",
        "browser",
        "mobileAppsAndDesktopClients",
        "exchangeActiveSync",
        "easSupported",
        "other",
        "unknownFutureValue"
    )]
    [string]$ClientAppType = "browser",

    [ValidateSet(
        "none",
        "low",
        "medium",
        "high",
        "hidden",
        "unknownFutureValue"
    )]
    [string]$SignInRiskLevel = "none",

    [ValidateSet(
        "none",
        "low",
        "medium",
        "high",
        "hidden",
        "unknownFutureValue"
    )]
    [string]$UserRiskLevel = "none",

    [ValidateSet(
        "none",
        "low",
        "medium",
        "high",
        "hidden",
        "unknownFutureValue"
    )]
    [string]$ServicePrincipalRiskLevel = "none",

    [string]$IpAddress,

    [ValidatePattern("^[A-Za-z]{2}$")]
    [string]$Country,

    [Nullable[bool]]$IsCompliant,
   
    [ValidateSet(
        "AzureAD",
        "ServerAD",
        "Workplace",
        "EntraID",
        "unknownFutureValue"
    )]
    [string]$TrustType,

    [switch]$AppliedPoliciesOnly,

    [switch]$ExportJson,

    [ValidateNotNullOrEmpty()]
    [string]$OutputPath =
        ".\reports\conditional-access\conditional-access-what-if.json",

    [switch]$PassThru
)

$ErrorActionPreference = "Stop"

function Get-BKObjectProperty {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string[]]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    foreach ($candidate in $Name) {
        $property =
            $InputObject.PSObject.Properties[$candidate]

        if ($null -ne $property) {
            return $property.Value
        }
    }

    return $null
}

function ConvertTo-BKStringArray {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return @()
    }

    return @(
        @($Value) |
            ForEach-Object {
                [string]$_
            } |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            }
    )
}

function Get-BKConditionalAccessClassification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Policy
    )

    $classifications =
        [System.Collections.Generic.List[string]]::new()

    $grantControls =
        Get-BKObjectProperty `
            -InputObject $Policy `
            -Name @(
                "GrantControls"
                "grantControls"
            )

    $sessionControls =
        Get-BKObjectProperty `
            -InputObject $Policy `
            -Name @(
                "SessionControls"
                "sessionControls"
            )

    $builtInControls =
        ConvertTo-BKStringArray `
            -Value (
                Get-BKObjectProperty `
                    -InputObject $grantControls `
                    -Name @(
                        "BuiltInControls"
                        "builtInControls"
                    )
            )

    if ($builtInControls -contains "block") {
        $null = $classifications.Add("Block")
    }

    if ($builtInControls -contains "mfa") {
        $null = $classifications.Add("MFA")
    }

    if (
        $builtInControls -contains "compliantDevice" -or
        $builtInControls -contains "domainJoinedDevice" -or
        $builtInControls -contains "approvedApplication" -or
        $builtInControls -contains "compliantApplication"
    ) {
        $null = $classifications.Add("Device")
    }

    $authenticationStrength =
        Get-BKObjectProperty `
            -InputObject $grantControls `
            -Name @(
                "AuthenticationStrength"
                "authenticationStrength"
            )

    if ($null -ne $authenticationStrength) {
        $null = $classifications.Add(
            "AuthenticationStrength"
        )
    }

    if ($null -ne $sessionControls) {
        $null = $classifications.Add("Session")
    }

    if ($classifications.Count -eq 0) {
        $null = $classifications.Add("Other")
    }

    return @(
        $classifications |
            Sort-Object -Unique
    )
}

Write-Host ""
Write-Host "============================================================" `
    -ForegroundColor Cyan
Write-Host "       BLACKKNIGHT CONDITIONAL ACCESS WHAT IF" `
    -ForegroundColor Cyan
Write-Host "============================================================" `
    -ForegroundColor Cyan

try {
    $requiredCommands = @(
        "Get-MgContext"
        "Invoke-MgGraphRequest"
        "Test-MgIdentityConditionalAccess"
    )

    foreach ($commandName in $requiredCommands) {
        if (
            -not (
                Get-Command `
                    -Name $commandName `
                    -ErrorAction SilentlyContinue
            )
        ) {
            throw (
                "Required Microsoft Graph command is unavailable: " +
                $commandName
            )
        }
    }

    $graphContext =
        Get-MgContext `
            -ErrorAction SilentlyContinue

    if ($null -eq $graphContext) {
        throw (
            "No active Microsoft Graph connection exists. Connect with " +
            "Policy.Read.ConditionalAccess before running this command."
        )
    }

    $resolvedIdentity = $null
    $signInIdentity = $null
    $identityType = $null

    switch ($PSCmdlet.ParameterSetName) {
        "UserPrincipalName" {
            Write-Host ""
            Write-Host "Resolving user..." `
                -ForegroundColor Yellow

            $encodedUserPrincipalName =
                [System.Uri]::EscapeDataString(
                    $UserPrincipalName
                )

            $user =
                Invoke-MgGraphRequest `
                    -Method GET `
                    -Uri (
                        "/v1.0/users/$encodedUserPrincipalName" +
                        '?$select=id,displayName,userPrincipalName,userType,accountEnabled'
                    ) `
                    -OutputType PSObject

            if (
                [string]::IsNullOrWhiteSpace(
                    [string]$user.id
                )
            ) {
                throw (
                    "Microsoft Graph did not return a user ID for " +
                    $UserPrincipalName
                )
            }

            $identityType = "User"

            $signInIdentity = @{
                "@odata.type" =
                    "#microsoft.graph.userSignIn"

                userId =
                    [string]$user.id
            }

            $resolvedIdentity = [PSCustomObject]@{
                Type              = "User"
                Id                = [string]$user.id
                DisplayName       = [string]$user.displayName
                UserPrincipalName = [string]$user.userPrincipalName
                UserType          = [string]$user.userType
                AccountEnabled    = $user.accountEnabled
            }
        }

        "ServicePrincipal" {
            $identityType = "ServicePrincipal"

            $signInIdentity = @{
                "@odata.type" =
                    "#microsoft.graph.servicePrincipalSignIn"

                servicePrincipalId =
                    $ServicePrincipalId
            }

            $resolvedIdentity = [PSCustomObject]@{
                Type = "ServicePrincipal"
                Id   = $ServicePrincipalId
            }
        }

        default {
            $identityType = "User"

            $signInIdentity = @{
                "@odata.type" =
                    "#microsoft.graph.userSignIn"

                userId =
                    $UserId
            }

            $resolvedIdentity = [PSCustomObject]@{
                Type = "User"
                Id   = $UserId
            }
        }
    }

    $signInConditions = @{}

    if ($identityType -eq "User") {
        $signInConditions.devicePlatform =
            $DevicePlatform

        $signInConditions.clientAppType =
            $ClientAppType

        $signInConditions.signInRiskLevel =
            $SignInRiskLevel

        $signInConditions.userRiskLevel =
            $UserRiskLevel
    }
    else {
        $signInConditions.servicePrincipalRiskLevel =
            $ServicePrincipalRiskLevel
    }

    if (
        -not [string]::IsNullOrWhiteSpace(
            $IpAddress
        )
    ) {
        $signInConditions.ipAddress =
            $IpAddress
    }

    if (
        -not [string]::IsNullOrWhiteSpace(
            $Country
        )
    ) {
        $signInConditions.country =
            $Country.ToUpperInvariant()
    }

    $deviceInfo = @{}

    if ($null -ne $IsCompliant) {
        $deviceInfo.isCompliant =
            [bool]$IsCompliant
    }

    
    if (
        -not [string]::IsNullOrWhiteSpace(
            $TrustType
        )
    ) {
        $deviceInfo.trustType =
            $TrustType
    }

    if ($deviceInfo.Count -gt 0) {
        $signInConditions.deviceInfo =
            $deviceInfo
    }

    $requestBody = @{
        signInIdentity =
            $signInIdentity

        signInContext = @{
            "@odata.type" =
                "#microsoft.graph.applicationContext"

            includeApplications =
                @($ApplicationId)
        }

        signInConditions =
            $signInConditions

        appliedPoliciesOnly =
            $AppliedPoliciesOnly.IsPresent
    }

    Write-Host ""
    Write-Host "Target Tenant" `
        -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------"
    Write-Host "Account      : $($graphContext.Account)"
    Write-Host "Tenant ID    : $($graphContext.TenantId)"
    Write-Host "Environment  : $($graphContext.Environment)"
    Write-Host "Identity     : $identityType"
    Write-Host "Identity ID  : $($resolvedIdentity.Id)"
    Write-Host "Applications : $($ApplicationId -join ', ')"

    Write-Host ""
    Write-Host "Evaluating Conditional Access policies..." `
        -ForegroundColor Yellow

    Write-Verbose "Conditional Access request body:"

    Write-Verbose (
        $requestBody |
            ConvertTo-Json `
                -Depth 20 `
                -Compress
    )

    $response = @(
        Test-MgIdentityConditionalAccess `
            -BodyParameter $requestBody `
            -ErrorAction Stop
    )

    $policies = @(
        foreach ($policy in $response) {
            if ($null -eq $policy) {
                continue
            }

            $analysisReasons =
                ConvertTo-BKStringArray `
                    -Value (
                        Get-BKObjectProperty `
                            -InputObject $policy `
                            -Name @(
                                "AnalysisReasons"
                                "analysisReasons"
                            )
                    )

            [PSCustomObject]@{
                Id = [string](
                    Get-BKObjectProperty `
                        -InputObject $policy `
                        -Name @(
                            "Id"
                            "id"
                        )
                )

                DisplayName = [string](
                    Get-BKObjectProperty `
                        -InputObject $policy `
                        -Name @(
                            "DisplayName"
                            "displayName"
                        )
                )

                State = [string](
                    Get-BKObjectProperty `
                        -InputObject $policy `
                        -Name @(
                            "State"
                            "state"
                        )
                )

                PolicyApplies = [bool](
                    Get-BKObjectProperty `
                        -InputObject $policy `
                        -Name @(
                            "PolicyApplies"
                            "policyApplies"
                        )
                )

                AnalysisReasons =
                    $analysisReasons

                Classification =
                    Get-BKConditionalAccessClassification `
                        -Policy $policy

                GrantControls =
                    Get-BKObjectProperty `
                        -InputObject $policy `
                        -Name @(
                            "GrantControls"
                            "grantControls"
                        )

                SessionControls =
                    Get-BKObjectProperty `
                        -InputObject $policy `
                        -Name @(
                            "SessionControls"
                            "sessionControls"
                        )
            }
        }
    )

    $appliedPolicies = @(
        $policies |
            Where-Object {
                $_.PolicyApplies
            }
    )

    $notAppliedPolicies = @(
        $policies |
            Where-Object {
                -not $_.PolicyApplies
            }
    )

    $blockPolicies = @(
        $appliedPolicies |
            Where-Object {
                $_.Classification -contains "Block"
            }
    )

    $mfaPolicies = @(
        $appliedPolicies |
            Where-Object {
                $_.Classification -contains "MFA"
            }
    )

    $devicePolicies = @(
        $appliedPolicies |
            Where-Object {
                $_.Classification -contains "Device"
            }
    )

    $sessionPolicies = @(
        $appliedPolicies |
            Where-Object {
                $_.Classification -contains "Session"
            }
    )

    $incompletePolicies = @(
        $notAppliedPolicies |
            Where-Object {
                $_.AnalysisReasons -contains
                "notEnoughInformation"
            }
    )

    $health = if ($blockPolicies.Count -gt 0) {
        "Blocked"
    }
    elseif ($incompletePolicies.Count -gt 0) {
        "Review Required"
    }
    elseif ($appliedPolicies.Count -gt 0) {
        "Protected"
    }
    else {
        "No Applicable Policy"
    }

    $confidence = if (
        $policies.Count -eq 0 -or
        $incompletePolicies.Count -eq 0
    ) {
        100
    }
    else {
        [math]::Round(
            (
                1 -
                (
                    $incompletePolicies.Count /
                    $policies.Count
                )
            ) * 100,
            2
        )
    }

    $findings =
        [System.Collections.Generic.List[object]]::new()

    foreach ($policy in $blockPolicies) {
        $null = $findings.Add(
            [PSCustomObject]@{
                Severity = "High"
                Category = "Block"
                Title = "Access would be blocked"
                Details = (
                    "Policy '$($policy.DisplayName)' applies " +
                    "and includes a block control."
                )
                Resource = $policy.Id
                Recommendation = (
                    "Confirm that blocking the simulated " +
                    "sign-in is intentional."
                )
            }
        )
    }

    foreach ($policy in $incompletePolicies) {
        $null = $findings.Add(
            [PSCustomObject]@{
                Severity = "Medium"
                Category = "Evaluation"
                Title = "Policy could not be fully evaluated"
                Details = (
                    "Policy '$($policy.DisplayName)' reported " +
                    "notEnoughInformation."
                )
                Resource = $policy.Id
                Recommendation = (
                    "Supply additional sign-in conditions and " +
                    "run the evaluation again."
                )
            }
        )
    }

    if (
        $appliedPolicies.Count -eq 0 -and
        $policies.Count -gt 0
    ) {
        $null = $findings.Add(
            [PSCustomObject]@{
                Severity = "Medium"
                Category = "Coverage"
                Title = "No Conditional Access policy applies"
                Details = (
                    "No evaluated policy applies to the supplied " +
                    "sign-in scenario."
                )
                Resource = $graphContext.TenantId
                Recommendation = (
                    "Confirm that the scenario is intentionally " +
                    "outside Conditional Access coverage."
                )
            }
        )
    }

    $result = [PSCustomObject]@{
        Platform    = "Blackknight One"
        Engine      = "ConditionalAccess"
        Operation   = "WhatIfEvaluation"
        GeneratedAt = (
            Get-Date
        ).ToUniversalTime().ToString("o")

        Tenant = [PSCustomObject]@{
            Account     = $graphContext.Account
            TenantId    = $graphContext.TenantId
            Environment = $graphContext.Environment
            AuthType    = $graphContext.AuthType
        }

        Scenario = [PSCustomObject]@{
            Identity       = $resolvedIdentity
            ApplicationIds = @($ApplicationId)
            DevicePlatform = $DevicePlatform
            ClientAppType  = $ClientAppType
            SignInRisk     = $SignInRiskLevel
            UserRisk       = $UserRiskLevel
            IpAddress      = $IpAddress
            Country        = $Country
            IsCompliant    = $IsCompliant
            IsManaged      = $IsManaged
            TrustType      = $TrustType
            AppliedOnly    = (
                $AppliedPoliciesOnly.IsPresent
            )
        }

        Summary = [PSCustomObject]@{
            Health             = $health
            Confidence         = $confidence
            PoliciesEvaluated  = $policies.Count
            PoliciesApplied    = $appliedPolicies.Count
            PoliciesNotApplied = $notAppliedPolicies.Count
            BlockPolicies      = $blockPolicies.Count
            MfaPolicies        = $mfaPolicies.Count
            DevicePolicies     = $devicePolicies.Count
            SessionPolicies    = $sessionPolicies.Count
            IncompletePolicies = $incompletePolicies.Count
            Findings           = $findings.Count
        }

        AppliedPolicies =
            $appliedPolicies

        NotAppliedPolicies =
            $notAppliedPolicies

        Policies =
            $policies

        Findings =
            @($findings)

        Recommendations = @(
            $findings |
                ForEach-Object {
                    $_.Recommendation
                } |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_)
                } |
                Sort-Object -Unique
        )

        Request =
            $requestBody
    }

    Write-Host ""
    Write-Host "Conditional Access What If Summary" `
        -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------"
    Write-Host "Policies Evaluated   : $($result.Summary.PoliciesEvaluated)"
    Write-Host "Policies Applied     : $($result.Summary.PoliciesApplied)"
    Write-Host "Policies Not Applied : $($result.Summary.PoliciesNotApplied)"
    Write-Host "Block Policies       : $($result.Summary.BlockPolicies)"
    Write-Host "MFA Policies         : $($result.Summary.MfaPolicies)"
    Write-Host "Device Policies      : $($result.Summary.DevicePolicies)"
    Write-Host "Session Policies     : $($result.Summary.SessionPolicies)"
    Write-Host "Confidence           : $($result.Summary.Confidence)%"
    Write-Host "Result               : $($result.Summary.Health)"

    if ($appliedPolicies.Count -gt 0) {
        Write-Host ""
        Write-Host "Applied Policies" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        $appliedPolicies |
            Select-Object `
                DisplayName,
                State,
                Classification |
            Format-Table `
                -Wrap `
                -AutoSize |
            Out-Host
    }

    if (
        -not $AppliedPoliciesOnly.IsPresent -and
        $notAppliedPolicies.Count -gt 0
    ) {
        Write-Host ""
        Write-Host "Not Applied Policies" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        $notAppliedPolicies |
            Select-Object `
                DisplayName,
                State,
                AnalysisReasons |
            Format-Table `
                -Wrap `
                -AutoSize |
            Out-Host
    }

    if ($findings.Count -gt 0) {
        Write-Host ""
        Write-Host "Findings" `
            -ForegroundColor Yellow
        Write-Host "------------------------------------------------------------"

        $findings |
            Select-Object `
                Severity,
                Category,
                Title,
                Details |
            Format-Table `
                -Wrap `
                -AutoSize |
            Out-Host
    }

    if ($ExportJson.IsPresent) {
        $outputDirectory =
            Split-Path `
                -Path $OutputPath `
                -Parent

        if (
            -not [string]::IsNullOrWhiteSpace(
                $outputDirectory
            ) -and
            -not (
                Test-Path `
                    -LiteralPath $outputDirectory `
                    -PathType Container
            )
        ) {
            New-Item `
                -Path $outputDirectory `
                -ItemType Directory `
                -Force |
                Out-Null
        }

        $result |
            ConvertTo-Json `
                -Depth 40 |
            Set-Content `
                -LiteralPath $OutputPath `
                -Encoding utf8

        Write-Host ""
        Write-Host (
            "[Success] Exported Conditional Access What If " +
            "report to $OutputPath"
        ) -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "============================================================" `
        -ForegroundColor Cyan

    if ($PassThru.IsPresent) {
        return $result
    }
}
catch {
    if (
        Get-Command `
            -Name "Write-BKLog" `
            -ErrorAction SilentlyContinue
    ) {
        Write-BKLog `
            -Message $_.Exception.Message `
            -Level Error
    }
    else {
        Write-Error $_.Exception.Message
    }

    throw
}