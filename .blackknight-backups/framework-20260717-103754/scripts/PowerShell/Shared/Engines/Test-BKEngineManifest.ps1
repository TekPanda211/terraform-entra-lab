function Test-BKEngineManifest {
    <#
    .SYNOPSIS
    Validates a Blackknight One engine manifest.

    .DESCRIPTION
    Validates required manifest fields, entry-point paths, public command
    declarations, and optional Graph metadata. The function does not load or
    execute an engine.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [object]$Manifest,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ManifestPath,

        [Parameter()]
        [switch]$ThrowOnInvalid
    )

    process {
        $errors = [System.Collections.Generic.List[string]]::new()
        $warnings = [System.Collections.Generic.List[string]]::new()

        foreach ($requiredProperty in @(
            "Name"
            "Version"
            "Description"
        )) {
            $value = Get-BKPropertyValue `
                -InputObject $Manifest `
                -Name $requiredProperty

            if ([string]::IsNullOrWhiteSpace([string]$value)) {
                $errors.Add("Manifest property '$requiredProperty' is required.")
            }
        }

        $entryPoint = [string](
            Get-BKPropertyValue `
                -InputObject $Manifest `
                -Name "EntryPoint"
        )

        $entryPoints = Get-BKPropertyValue `
            -InputObject $Manifest `
            -Name "EntryPoints"

        if (
            [string]::IsNullOrWhiteSpace($entryPoint) -and
            $null -eq $entryPoints
        ) {
            $errors.Add(
                "The manifest must define EntryPoint or EntryPoints."
            )
        }

        $manifestDirectory = $null

        if (-not [string]::IsNullOrWhiteSpace($ManifestPath)) {
            $resolvedManifestPath = [System.IO.Path]::GetFullPath(
                $ManifestPath
            )

            $manifestDirectory = Split-Path `
                -Path $resolvedManifestPath `
                -Parent

            if (
                -not (
                    Test-Path `
                        -LiteralPath $resolvedManifestPath `
                        -PathType Leaf
                )
            ) {
                $errors.Add(
                    "Engine manifest file was not found: $resolvedManifestPath"
                )
            }
        }

        $declaredEntryPoints = [System.Collections.Generic.List[string]]::new()

        if (-not [string]::IsNullOrWhiteSpace($entryPoint)) {
            $declaredEntryPoints.Add($entryPoint)
        }

        if ($null -ne $entryPoints) {
            foreach ($property in $entryPoints.PSObject.Properties) {
                $value = [string]$property.Value

                if (-not [string]::IsNullOrWhiteSpace($value)) {
                    $declaredEntryPoints.Add($value)
                }
            }
        }

        if ($null -ne $manifestDirectory) {
            foreach ($declaredEntryPoint in @(
                $declaredEntryPoints |
                    Sort-Object -Unique
            )) {
                $entryPointPath = Join-Path `
                    -Path $manifestDirectory `
                    -ChildPath $declaredEntryPoint

                if (
                    -not (
                        Test-Path `
                            -LiteralPath $entryPointPath `
                            -PathType Leaf
                    )
                ) {
                    $errors.Add(
                        "Engine entry point was not found: $entryPointPath"
                    )
                }
            }
        }

        $publicCommands = @(
            Get-BKPropertyValue `
                -InputObject $Manifest `
                -Name "PublicCommands" `
                -DefaultValue @()
        )

        foreach ($publicCommand in $publicCommands) {
            if ([string]::IsNullOrWhiteSpace([string]$publicCommand)) {
                $errors.Add(
                    "PublicCommands contains a null or empty command name."
                )
            }
        }

        $supportsGraph = [bool](
            Get-BKPropertyValue `
                -InputObject $Manifest `
                -Name "SupportsGraph" `
                -DefaultValue $false
        )

        $requiredScopes = @(
            Get-BKPropertyValue `
                -InputObject $Manifest `
                -Name @(
                    "RequiredScopes"
                    "MinimumScopes"
                ) `
                -DefaultValue @()
        )

        if ($supportsGraph -and $requiredScopes.Count -eq 0) {
            $warnings.Add(
                "SupportsGraph is true, but no required scopes are declared."
            )
        }

        $result = [PSCustomObject]@{
            Name             = [string]$Manifest.Name
            Version          = [string]$Manifest.Version
            ManifestPath     = $ManifestPath
            IsValid          = $errors.Count -eq 0
            Errors           = @($errors)
            Warnings         = @($warnings)
            EntryPoints      = @(
                $declaredEntryPoints |
                    Sort-Object -Unique
            )
            PublicCommands   = @($publicCommands)
            SupportsGraph    = $supportsGraph
            RequiredScopes   = @($requiredScopes)
            ValidatedAt      = (
                Get-Date
            ).ToUniversalTime().ToString("o")
        }

        if ($ThrowOnInvalid.IsPresent -and -not $result.IsValid) {
            throw (
                "Engine manifest validation failed: " +
                ($result.Errors -join " ")
            )
        }

        return $result
    }
}
