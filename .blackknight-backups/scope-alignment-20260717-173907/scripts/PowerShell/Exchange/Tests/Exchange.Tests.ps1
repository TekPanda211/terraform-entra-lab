Describe "Exchange engine scaffold" {
    It "has a valid engine manifest" {
        $manifestPath = Join-Path `
            -Path $PSScriptRoot `
            -ChildPath "..\engine.json"

        $manifest = Get-Content `
            -LiteralPath $manifestPath `
            -Raw |
            ConvertFrom-Json

        $manifest.Name |
            Should -Be "Exchange"

        $manifest.Version |
            Should -Be "0.1.0"
    }

    It "contains all declared entry points" {
        $engineRoot =
            Split-Path `
                -Path $PSScriptRoot `
                -Parent

        $entryPoints = @(
            "Invoke-BKExchangeAssessment.ps1"
            "Invoke-BKExchangeDiscovery.ps1"
            "Invoke-BKExchangeAnalyzer.ps1"
        )

        foreach ($entryPoint in $entryPoints) {
            $entryPointPath = Join-Path `
                -Path $engineRoot `
                -ChildPath $entryPoint

            Test-Path `
                -LiteralPath $entryPointPath `
                -PathType Leaf |
                Should -BeTrue
        }
    }
}