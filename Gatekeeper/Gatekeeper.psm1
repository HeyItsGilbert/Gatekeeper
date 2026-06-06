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

# Define the types to export with type accelerators.
$ExportableTypes = @(
    [PropertySet],
    [Property],
    [FeatureFlag],
    [Rule],
    [Condition],
    [Effect]
)
# Get the internal TypeAccelerators class to use its static methods.
$TypeAcceleratorsClass = [PSObject].Assembly.GetType(
    'System.Management.Automation.TypeAccelerators'
)
# Add type accelerators, replacing any stale registrations from prior module loads.
foreach ($Type in $ExportableTypes) {
    [void]$TypeAcceleratorsClass::Remove($Type.FullName)
    $TypeAcceleratorsClass::Add($Type.FullName, $Type)
}
# Remove type accelerators when the module is removed.
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    foreach ($Type in $ExportableTypes) {
        [void]$TypeAcceleratorsClass::Remove($Type.FullName)
    }
}.GetNewClosure()
