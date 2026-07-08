function Export-BKJsonReport {
    param(
        [Parameter(Mandatory)]
        [object]$Data,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $folder = Split-Path $Path -Parent

    if (!(Test-Path $folder)) {
        New-Item -Path $folder -ItemType Directory -Force | Out-Null
    }

    $Data | ConvertTo-Json -Depth 10 | Out-File -FilePath $Path -Encoding utf8

    Write-BKLog -Message "Exported JSON report to $Path" -Level Success
}