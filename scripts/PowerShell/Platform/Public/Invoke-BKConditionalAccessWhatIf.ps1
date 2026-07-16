function Invoke-BKConditionalAccessWhatIf {
    <#
    .SYNOPSIS
    Runs a Microsoft Entra Conditional Access What If evaluation.

    .DESCRIPTION
    Provides the public Blackknight One wrapper for the Conditional Access
    What If engine.

    The command evaluates Conditional Access policy applicability for a
    simulated user or service-principal sign-in. It does not modify policies.

    .PARAMETER UserId
    Microsoft Entra user object identifier.

    .PARAMETER UserPrincipalName
    User principal name to resolve through Microsoft Graph.

    .PARAMETER ServicePrincipalId
    Microsoft Entra service-principal object identifier.

    .PARAMETER ApplicationId
    One or more application identifiers included in the simulated sign-in.

    .PARAMETER DevicePlatform
    Device platform used in the simulated sign-in.

    .PARAMETER ClientAppType
    Client application type used in the simulated sign-in.

    .PARAMETER SignInRiskLevel
    Simulated sign-in risk level.

    .PARAMETER UserRiskLevel
    Simulated user risk level.

    .PARAMETER ServicePrincipalRiskLevel
    Simulated workload-identity risk level.

    .PARAMETER IpAddress
    Source IP address used in the simulation.

    .PARAMETER Country
    Two-letter country code used in the simulation.

    .PARAMETER IsCompliant
    Indicates whether the simulated device is compliant.

    .PARAMETER TrustType
    Simulated device trust type.

    .PARAMETER AppliedPoliciesOnly
    Returns only policies that apply to the simulated sign-in.

    .PARAMETER ExportJson
    Exports the evaluation report as JSON.

    .PARAMETER OutputPath
    Destination path for the JSON report.

    .PARAMETER PassThru
    Returns the complete What If evaluation object.
    #>

    [CmdletBinding(DefaultParameterSetName = "UserId")]
    param(
        [Parameter(
            Mandatory,
            ParameterSetName = "UserId"
        )]
        [ValidateNotNullOrEmpty()]
        [string]$UserId,

        [Parameter(
            Mandatory,
            ParameterSetName = "UserPrincipalName"
        )]
        [ValidateNotNullOrEmpty()]
        [string]$UserPrincipalName,

        [Parameter(
            Mandatory,
            ParameterSetName = "ServicePrincipal"
        )]
        [ValidateNotNullOrEmpty()]
        [string]$ServicePrincipalId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ApplicationId,

        [Parameter()]
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

        [Parameter()]
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

        [Parameter()]
        [ValidateSet(
            "none",
            "low",
            "medium",
            "high",
            "hidden",
            "unknownFutureValue"
        )]
        [string]$SignInRiskLevel = "none",

        [Parameter()]
        [ValidateSet(
            "none",
            "low",
            "medium",
            "high",
            "hidden",
            "unknownFutureValue"
        )]
        [string]$UserRiskLevel = "none",

        [Parameter()]
        [ValidateSet(
            "none",
            "low",
            "medium",
            "high",
            "hidden",
            "unknownFutureValue"
        )]
        [string]$ServicePrincipalRiskLevel = "none",

        [Parameter()]
        [string]$IpAddress,

        [Parameter()]
        [ValidatePattern("^[A-Za-z]{2}$")]
        [string]$Country,

        [Parameter()]
        [Nullable[bool]]$IsCompliant,

        [Parameter()]
        [ValidateSet(
            "AzureAD",
            "ServerAD",
            "Workplace",
            "EntraID",
            "unknownFutureValue"
        )]
        [string]$TrustType,

        [Parameter()]
        [switch]$AppliedPoliciesOnly,

        [Parameter()]
        [switch]$ExportJson,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath =
            ".\reports\conditional-access\conditional-access-what-if.json",

        [Parameter()]
        [switch]$PassThru
    )

    $engineScript = Join-Path `
        -Path $PSScriptRoot `
        -ChildPath (
            "..\..\ConditionalAccess\" +
            "Invoke-BKConditionalAccessWhatIf.ps1"
        )

    $engineScript = [System.IO.Path]::GetFullPath(
        $engineScript
    )

    if (
        -not (
            Test-Path `
                -LiteralPath $engineScript `
                -PathType Leaf
        )
    ) {
        throw (
            "Conditional Access What If engine was not found: " +
            $engineScript
        )
    }

    $invokeParameters = @{
        ApplicationId              = @($ApplicationId)
        DevicePlatform             = $DevicePlatform
        ClientAppType              = $ClientAppType
        SignInRiskLevel            = $SignInRiskLevel
        UserRiskLevel              = $UserRiskLevel
        ServicePrincipalRiskLevel = $ServicePrincipalRiskLevel
        AppliedPoliciesOnly        = $AppliedPoliciesOnly.IsPresent
        ExportJson                 = $ExportJson.IsPresent
        OutputPath                 = $OutputPath
        PassThru                   = $PassThru.IsPresent
    }

    switch ($PSCmdlet.ParameterSetName) {
        "UserPrincipalName" {
            $invokeParameters.UserPrincipalName =
                $UserPrincipalName
        }

        "ServicePrincipal" {
            $invokeParameters.ServicePrincipalId =
                $ServicePrincipalId
        }

        default {
            $invokeParameters.UserId =
                $UserId
        }
    }

    if (
        -not [string]::IsNullOrWhiteSpace(
            $IpAddress
        )
    ) {
        $invokeParameters.IpAddress =
            $IpAddress
    }

    if (
        -not [string]::IsNullOrWhiteSpace(
            $Country
        )
    ) {
        $invokeParameters.Country =
            $Country
    }

    if ($null -ne $IsCompliant) {
        $invokeParameters.IsCompliant =
            $IsCompliant
    }

    if (
        -not [string]::IsNullOrWhiteSpace(
            $TrustType
        )
    ) {
        $invokeParameters.TrustType =
            $TrustType
    }

    Write-Verbose "Conditional Access What If wrapper started."
    Write-Verbose "Engine: $engineScript"
    Write-Verbose "Application IDs: $($ApplicationId -join ', ')"
    Write-Verbose "Device platform: $DevicePlatform"
    Write-Verbose "Client application type: $ClientAppType"
    Write-Verbose "Applied policies only: $($AppliedPoliciesOnly.IsPresent)"
    Write-Verbose "Export JSON: $($ExportJson.IsPresent)"
    Write-Verbose "Output path: $OutputPath"

    try {
        $engineOutput = @(
            & $engineScript @invokeParameters
        )

        $result =
            $engineOutput |
                Where-Object {
                    $null -ne $_ -and
                    $_.PSObject.Properties.Name -contains "Operation" -and
                    $_.Operation -eq "WhatIfEvaluation"
                } |
                Select-Object -Last 1

        if (
            $PassThru.IsPresent -and
            $null -eq $result
        ) {
            throw (
                "Conditional Access What If completed without returning " +
                "a valid WhatIfEvaluation result object."
            )
        }

        if ($PassThru.IsPresent) {
            return $result
        }
    }
    catch {
        $message =
            "Conditional Access What If failed: $($_.Exception.Message)"

        if (
            Get-Command `
                -Name "Write-BKLog" `
                -ErrorAction SilentlyContinue
        ) {
            Write-BKLog `
                -Message $message `
                -Level Error
        }

        throw $message
    }
}