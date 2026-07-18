$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Blackknight One module bootstrap
# ---------------------------------------------------------------------------

$moduleRoot = $PSScriptRoot
$powerShellRoot = [System.IO.Path]::GetFullPath(
    (
        Join-Path `
            -Path $moduleRoot `
            -ChildPath ".."
    )
)

# ---------------------------------------------------------------------------
# Load shared framework
# ---------------------------------------------------------------------------

$sharedFrameworkLoader = Join-Path `
    -Path $powerShellRoot `
    -ChildPath "Shared\Import-BKSharedFramework.ps1"

if (
    Test-Path `
        -LiteralPath $sharedFrameworkLoader `
        -PathType Leaf
) {
    . $sharedFrameworkLoader
}
else {
    throw (
        "Blackknight Shared Framework loader was not found: " +
        $sharedFrameworkLoader
    )
}

# ---------------------------------------------------------------------------
# Build engine registry
# ---------------------------------------------------------------------------

$script:BKEngineRegistry = [PSCustomObject]@{
    PowerShellRoot = $powerShellRoot
    RefreshedAt    = $null
    Engines        = @()
}

try {
    $null = Get-BKEngineRegistry `
        -PowerShellRoot $powerShellRoot `
        -Refresh `
        -IncludeInvalid
}
catch {
    Write-Warning (
        "Blackknight engine registry initialization failed: " +
        $_.Exception.Message
    )
}
# ---------------------------------------------------------------------------
# Load engine-private helpers
# ---------------------------------------------------------------------------

$enginePrivateFiles = @(
    Get-ChildItem `
        -Path $powerShellRoot `
        -Directory `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -notin @(
                "Platform"
                "Shared"
            )
        } |
        ForEach-Object {
            $privatePath = Join-Path `
                -Path $_.FullName `
                -ChildPath "Private"

            if (
                Test-Path `
                    -LiteralPath $privatePath `
                    -PathType Container
            ) {
                Get-ChildItem `
                    -Path $privatePath `
                    -Filter "*.ps1" `
                    -File `
                    -ErrorAction SilentlyContinue
            }
        } |
        Sort-Object FullName
)

foreach ($privateFile in $enginePrivateFiles) {
    Write-Verbose (
        "Loading engine-private helper: " +
        $privateFile.FullName
    )

    . $privateFile.FullName
}

# ---------------------------------------------------------------------------
# Load platform-private functions
# ---------------------------------------------------------------------------

$platformPrivateFiles = @(
    Get-ChildItem `
        -Path (
            Join-Path `
                -Path $moduleRoot `
                -ChildPath "Private"
        ) `
        -Filter "*.ps1" `
        -File `
        -ErrorAction SilentlyContinue |
        Sort-Object FullName
)

foreach ($privateFile in $platformPrivateFiles) {
    Write-Verbose (
        "Loading platform-private function: " +
        $privateFile.FullName
    )

    . $privateFile.FullName
}

# ---------------------------------------------------------------------------
# Load platform-public functions
# ---------------------------------------------------------------------------

$publicFiles = @(
    Get-ChildItem `
        -Path (
            Join-Path `
                -Path $moduleRoot `
                -ChildPath "Public"
        ) `
        -Filter "*.ps1" `
        -File `
        -ErrorAction SilentlyContinue |
        Sort-Object FullName
)

foreach ($publicFile in $publicFiles) {
    Write-Verbose (
        "Loading public function: " +
        $publicFile.FullName
    )

    . $publicFile.FullName
}

# ---------------------------------------------------------------------------
# Export only public platform commands
# ---------------------------------------------------------------------------

$publicFunctionNames = @(
    $publicFiles |
        ForEach-Object {
            $_.BaseName
        } |
        Sort-Object -Unique
)

Export-ModuleMember `
    -Function $publicFunctionNames
