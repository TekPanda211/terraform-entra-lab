function New-BKFinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Informational", "Low", "Medium", "High", "Critical")]
        [string]$Severity,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Category,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Title,

        [AllowEmptyString()]
        [string]$Details = "",

        [AllowEmptyString()]
        [string]$Resource = "",

        [AllowEmptyString()]
        [string]$Recommendation = "",

        [AllowEmptyString()]
        [string]$Source = "",

        [AllowEmptyString()]
        [string]$RuleId = "",

        [hashtable]$Metadata = @{}
    )

    [PSCustomObject]@{
        Severity       = $Severity
        Category       = $Category
        Title          = $Title
        Details        = $Details
        Resource       = $Resource
        Recommendation = $Recommendation
        Source          = $Source
        RuleId          = $RuleId
        Metadata        = @{} + $Metadata
        Timestamp       = (Get-Date).ToUniversalTime().ToString("o")
    }
}
