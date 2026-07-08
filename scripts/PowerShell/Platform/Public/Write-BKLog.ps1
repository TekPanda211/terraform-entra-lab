function Write-BKLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet("Info", "Success", "Warning", "Error", "Debug")]
        [string]$Level = "Info"
    )

    $color = switch ($Level) {
        "Info" { "White" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Debug" { "Gray" }
    }

    Write-Host "[$Level] $Message" -ForegroundColor $color
}