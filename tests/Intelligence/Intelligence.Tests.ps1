Describe 'Blackknight Intelligence Framework' {
    BeforeAll {
        $root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        Get-ChildItem "$root/scripts/PowerShell/Shared" -Filter '*.ps1' -File -Recurse | ForEach-Object { . $_.FullName }
    }

    It 'creates a tenant model' {
        $tenant = New-BKTenantModel -TenantId 'test' -DisplayName 'Contoso'
        $tenant.PSTypeNames | Should -Contain 'Blackknight.TenantModel'
        $tenant.Assessments.Count | Should -Be 0
    }

    It 'creates an assessment context' {
        $context = New-BKAssessmentContextCore
        $context.Status | Should -Be 'Created'
        $context.Results.Count | Should -Be 0
    }

    It 'calculates risk from normalized findings' {
        $context = New-BKAssessmentContextCore
        $result = [PSCustomObject]@{ Engine='Test'; Findings=@([PSCustomObject]@{ Title='Risk'; Severity='High'; Engine='Test' }) }
        [void](Add-BKAssessmentResult -Context $context -Result $result)
        $risk = Invoke-BKRiskAssessmentCore -Context $context
        $risk.Score | Should -Be 88
        $risk.High | Should -Be 1
    }

    It 'creates correlations for shared resource keys' {
        $context = New-BKAssessmentContextCore
        [void](Add-BKAssessmentResult -Context $context -Result ([PSCustomObject]@{ Engine='One'; Findings=@([PSCustomObject]@{Title='A';Severity='High';ResourceId='r1';Engine='One'}) }))
        [void](Add-BKAssessmentResult -Context $context -Result ([PSCustomObject]@{ Engine='Two'; Findings=@([PSCustomObject]@{Title='B';Severity='Medium';ResourceId='r1';Engine='Two'}) }))
        @(Invoke-BKCorrelationCore -Context $context).Count | Should -Be 1
    }
}
