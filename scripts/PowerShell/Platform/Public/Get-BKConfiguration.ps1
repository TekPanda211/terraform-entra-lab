function Get-BKConfiguration {
    [PSCustomObject]@{
        PlatformName        = "Blackknight One"
        Version             = "0.4.0-alpha"
        Environment         = "Development"
        OutputRoot          = ".\reports"
        ConfidenceThreshold = 80
        Timestamp           = (Get-Date).ToUniversalTime().ToString("o")
    }
}