function New-BKResult {
    param(
        [Parameter(Mandatory)]
        [string]$Engine,

        [string]$Version = "0.4.0-alpha",
        [string]$Status = "Framework",
        [string]$Health = "Healthy",
        [int]$Confidence = 75,
        [int]$ChecksRun = 1,
        [int]$Passed = 1,
        [int]$Warnings = 0,
        [int]$Failed = 0,
        [string[]]$Evidence = @(),
        [string[]]$Recommendations = @()
    )

    [PSCustomObject]@{
        Engine          = $Engine
        Version         = $Version
        Status          = $Status
        Health          = $Health
        Confidence      = $Confidence
        ChecksRun       = $ChecksRun
        Passed          = $Passed
        Warnings        = $Warnings
        Failed          = $Failed
        Timestamp       = (Get-Date).ToUniversalTime().ToString("o")
        Evidence        = $Evidence
        Recommendations = $Recommendations
    }
}