$PublicFunctions = Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue
$PrivateFunctions = Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue

foreach ($Function in @($PublicFunctions + $PrivateFunctions)) {
    . $Function.FullName
}

Export-ModuleMember -Function $PublicFunctions.BaseName