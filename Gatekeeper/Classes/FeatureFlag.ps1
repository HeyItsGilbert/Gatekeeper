# SPIKE/migration: Rule, FeatureFlag, GatekeeperPath, the Operator enum, and
# the three ArgumentTransformationAttribute classes that used to live here are
# now C#-compiled types defined in Classes/CompiledTypes.ps1 (registered as
# type accelerators from Gatekeeper.psd1's ScriptsToProcess, before this file
# or RootModule ever load). See CompiledTypes.ps1 for why.
