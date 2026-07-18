function Show-BKDashboard {
    <#
    .SYNOPSIS
    Displays the manifest-driven Blackknight One engine dashboard.
    #>
    [CmdletBinding()]
    param(
        [Parameter()][switch]$Once,
        [Parameter()][switch]$PassThru
    )

    do {
        Clear-Host
        Write-Host "Blackknight One" -ForegroundColor Cyan
        Write-Host "Identity-first security engineering for Entra, Graph, Terraform, Azure, and GDAP"
        Write-Host ("=" * 78)

        $engines = @(
            Get-BKEngine -Refresh |
                Where-Object {
                    $_.Enabled -and
                    $_.SupportsDashboard -and
                    $_.HasAssessment -and
                    $_.IsValid
                } |
                Sort-Object Category, DisplayName
        )

        if ($engines.Count -eq 0) {
            Write-Warning "No valid dashboard-enabled assessment engines were discovered."
            return
        }

        $index = 1
        $currentCategory = $null
        foreach ($engine in $engines) {
            if ($engine.Category -ne $currentCategory) {
                $currentCategory = $engine.Category
                Write-Host ""
                Write-Host $currentCategory -ForegroundColor Yellow
                Write-Host ("-" * $currentCategory.Length)
            }

            Write-Host ("[{0}] {1}  v{2}" -f $index, $engine.DisplayName, $engine.Version)
            $index++
        }

        Write-Host ""
        Write-Host "[S] Engine status"
        Write-Host "[R] Refresh registry"
        Write-Host "[Q] Quit"
        Write-Host ""

        $selection = Read-Host "Select an engine"
        if ($selection -match '^[Qq]$') { return }
        if ($selection -match '^[Rr]$') { continue }
        if ($selection -match '^[Ss]$') {
            Get-BKEngineStatus -Refresh |
                Format-Table Name, Category, Version, Status, SupportsGraph -AutoSize
            $null = Read-Host "Press Enter to return to the dashboard"
            continue
        }

        $selectedIndex = 0
        if (-not [int]::TryParse($selection, [ref]$selectedIndex)) {
            Write-Warning "Invalid selection."
            Start-Sleep -Seconds 1
            continue
        }
        if ($selectedIndex -lt 1 -or $selectedIndex -gt $engines.Count) {
            Write-Warning "Selection is outside the available range."
            Start-Sleep -Seconds 1
            continue
        }

        $selectedEngine = $engines[$selectedIndex - 1]
        Clear-Host
        Write-BKAssessmentHeader -Title $selectedEngine.DisplayName -Subtitle $selectedEngine.Description

        try {
            $result = Invoke-BKEngine `
                -Name $selectedEngine.Name `
                -Operation Assessment `
                -PassThru:$PassThru.IsPresent

            if ($PassThru.IsPresent) { return $result }
            if ($null -ne $result) {
                $result | Write-BKAssessmentSummary
                $result | Write-BKAssessmentFindings
                $result | Write-BKAssessmentFooter
            }
        }
        catch {
            Write-Error $_
        }

        if (-not $Once.IsPresent) {
            $null = Read-Host "Press Enter to return to the dashboard"
        }
    } while (-not $Once.IsPresent)
}
