BeforeAll {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $loader = Join-Path $repoRoot "scripts\PowerShell\Shared\Import-BKSharedFramework.ps1"
    . $loader
}

Describe "Blackknight Shared Framework" {
    It "loads every required helper" {
        foreach ($name in @(
            "ConvertTo-BKArray",
            "Get-BKPropertyValue",
            "New-BKFinding",
            "Measure-BKScore",
            "New-BKAssessmentResult",
            "Export-BKJson",
            "Invoke-BKGraphPagedRequest",
            "Test-BKRequiredGraphScopes"
        )) {
            Get-Command $name -CommandType Function -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
    }

    It "creates a normalized finding" {
        $finding = New-BKFinding -Severity High -Category Identity -Title "Test finding"
        $finding.Severity | Should -Be "High"
        $finding.Title | Should -Be "Test finding"
        $finding.Timestamp | Should -Not -BeNullOrEmpty
    }

    It "calculates weighted scores" {
        $score = Measure-BKScore -Findings @(
            New-BKFinding -Severity High -Category Test -Title One
            New-BKFinding -Severity Medium -Category Test -Title Two
        )
        $score.Score | Should -Be 87
        $score.Health | Should -Be "Healthy"
    }

    It "creates standardized assessment results" {
        $result = New-BKAssessmentResult -Engine Test -Operation Validate
        $result.Platform | Should -Be "Blackknight One"
        $result.Engine | Should -Be "Test"
        $result.Operation | Should -Be "Validate"
    }

    It "exports valid JSON" {
        $path = Join-Path $TestDrive "result.json"
        @{ status = "ok" } | Export-BKJson -Path $path
        Test-Path $path | Should -BeTrue
        (Get-Content $path -Raw | ConvertFrom-Json).status | Should -Be "ok"
    }
}
