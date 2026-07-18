function Export-BKJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [ValidateRange(2, 100)]
        [int]$Depth = 30,

        [switch]$Compress,

        [switch]$PassThru
    )

    process {
        $resolvedOutputPath = if ([System.IO.Path]::IsPathRooted($Path)) {
            [System.IO.Path]::GetFullPath($Path)
        }
        else {
            [System.IO.Path]::GetFullPath((Join-Path -Path (Get-Location).Path -ChildPath $Path))
        }

        $directory = Split-Path -Path $resolvedOutputPath -Parent

        if (-not [string]::IsNullOrWhiteSpace($directory) -and
            -not (Test-Path -LiteralPath $directory -PathType Container)) {
            New-Item -Path $directory -ItemType Directory -Force | Out-Null
        }

        $jsonParameters = @{ Depth = $Depth }
        if ($Compress.IsPresent) { $jsonParameters.Compress = $true }

        $InputObject |
            ConvertTo-Json @jsonParameters |
            Set-Content -LiteralPath $resolvedOutputPath -Encoding utf8 -ErrorAction Stop

        if ($PassThru.IsPresent) {
            return Get-Item -LiteralPath $resolvedOutputPath -ErrorAction Stop
        }
    }
}
