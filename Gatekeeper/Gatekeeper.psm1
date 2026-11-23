# Dot source public/private functions
$enum = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Enums/*.ps1') -Recurse -ErrorAction Stop)
$classes = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Classes/*.ps1') -Recurse -ErrorAction Stop)
$public = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Public/*.ps1')  -Recurse -ErrorAction Stop)
$private = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Private/*.ps1') -Recurse -ErrorAction Stop)
foreach ($import in @($enum + $classes + $public + $private)) {
    try {
        . $import.FullName
    } catch {
        throw "Unable to dot source [$($import.FullName)]"
    }
}

# Import the configuration
$script:GatekeeperConfiguration = Import-GatekeeperConfig -ErrorAction Stop

Export-ModuleMember -Function $public.Basename

# No per-import type-accelerator registration needed here: every domain type
# (Effect, Operator, Condition, Property, PropertySet, Rule, FeatureFlag, and
# the three ArgumentTransformationAttribute classes) is now C#-compiled and
# registered exactly once via Classes/CompiledTypes.ps1, the first entry in
# Gatekeeper.psd1's ScriptsToProcess - run before RootModule (this file) is
# even invoked. See CompiledTypes.ps1 for why.
