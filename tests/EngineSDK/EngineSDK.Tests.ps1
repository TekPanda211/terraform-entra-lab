BeforeAll {
    $repositoryRoot = [System.IO.Path]::GetFullPath(
        (Join-Path -Path $PSScriptRoot -ChildPath "..\..")
    )

    $modulePath = Join-Path `
        -Path $repositoryRoot `
        -ChildPath "scripts\PowerShell\Platform\Blackknight-Platform.psd1"

    Import-Module $modulePath -Force
}

Describe "Blackknight Engine SDK" {
    It "exports Get-BKEngine" {
        Get-Command Get-BKEngine -ErrorAction Stop |
            Should -Not -BeNullOrEmpty
    }

    It "exports New-BKEngine" {
        Get-Command New-BKEngine -ErrorAction Stop |
            Should -Not -BeNullOrEmpty
    }

    It "discovers at least one valid engine" {
        @(Get-BKEngine).Count |
            Should -BeGreaterThan 0
    }

    It "does not export internal registry helpers" {
        Get-Command Get-BKEngineRegistry `
            -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
    }
}
