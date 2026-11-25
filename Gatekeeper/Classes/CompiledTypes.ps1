# Full port: every Gatekeeper domain type (previously PowerShell `class`/`enum`
# definitions scattered across Classes/*.ps1 and Enums/Effect.ps1) compiled
# once, here, as C# via Add-Type.
#
# WHY: Pester 6 Run.Parallel runs each test file's worker in its own runspace,
# but *in the same process* (confirmed empirically: workers share $env: and
# the CLR's process-wide TypeAccelerators table). Every runspace that imports
# this module via `class`/`enum` keywords compiles its OWN distinct CLR type
# per name. The shared, process-wide TypeAccelerators table can only bind one
# name to one Type at a time, so whichever runspace imports last wins that
# slot, and every other runspace's already-built objects fail
# `-is`/`Should -BeOfType`/argument-transformation checks against a
# same-named-but-unrelated Type (confirmed via a narrow Condition-only spike
# before this full port: converting just Condition eliminated 100% of its
# identity failures under Run.Parallel with zero sequential regression).
#
# A C#-compiled type is JIT-compiled once per AppDomain (i.e. once per
# process, not once per import), so every runspace shares the identical Type -
# there is no "last writer wins" collision for any of them anymore.
#
# ORDERING: runs as the FIRST entry in Gatekeeper.psd1's ScriptsToProcess.
# ScriptsToProcess scripts run in the caller's session, directly, BEFORE
# RootModule (Gatekeeper.psm1) is even invoked - and Property.ps1/
# FeatureFlag.ps1 (still listed later in ScriptsToProcess, now otherwise
# empty) historically defined types that referenced each other
# (`class Rule { [Condition]$Condition }`, etc). Putting the compile+register
# step anywhere later - inside Gatekeeper.psm1, or after those files - throws
# "Unable to find type [...]" before RootModule ever loads (confirmed).
#
# Gatekeeper.psm1's own Classes/*.ps1 dot-source loop also picks this file up
# a second time per import (it's a wildcard glob, not an explicit list) - that
# is intentional and harmless: the guard below makes re-running this file any
# number of times a no-op after the first real compile.
#
# Guarded with a Monitor lock on $TypeAcceleratorsClass: it is the SAME Type
# instance in every runspace in this process, so locking on it serializes the
# check-then-compile against concurrent importers (confirmed necessary: two
# runspaces racing here without a lock hit "already exists" errors on shared,
# unsynchronized process-wide state - same TOCTOU shape as any such race).
$TypeAcceleratorsClass = [PSObject].Assembly.GetType(
    'System.Management.Automation.TypeAccelerators'
)
[System.Threading.Monitor]::Enter($TypeAcceleratorsClass)
try {
    if (-not ('Gatekeeper.FeatureFlag' -as [type])) {
        Add-Type -Language CSharp -ReferencedAssemblies 'System.Management.Automation', 'System.Linq', 'System.Collections', 'System.Text.RegularExpressions' -TypeDefinition @'
using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Text;

namespace Gatekeeper
{
    // Shared helpers for the handful of operations (JSON (de)serialization,
    // file I/O cmdlets, schema validation, warnings, reading module config)
    // that only make sense as actual PowerShell cmdlet calls - re-entering
    // the CURRENT runspace's pipeline (not a separate one) so nested calls
    // behave exactly as if invoked from script: they see the same session
    // state, stream redirection, and preference variables as the caller.
    internal static class PSInterop
    {
        private static PowerShell NewPS()
        {
            return PowerShell.Create(RunspaceMode.CurrentRunspace);
        }

        public static Hashtable ToHashtable(IDictionary dict)
        {
            if (dict is Hashtable h) { return h; }
            var result = new Hashtable();
            foreach (DictionaryEntry entry in dict) { result[entry.Key] = entry.Value; }
            return result;
        }

        public static bool TestPath(string path)
        {
            using (var ps = NewPS())
            {
                ps.AddCommand("Test-Path").AddParameter("Path", path);
                var results = ps.Invoke<bool>();
                return results.Count > 0 && results[0];
            }
        }

        public static bool TestPathLiteralLeaf(string literalPath)
        {
            using (var ps = NewPS())
            {
                ps.AddCommand("Test-Path").AddParameter("LiteralPath", literalPath).AddParameter("PathType", "Leaf");
                var results = ps.Invoke<bool>();
                return results.Count > 0 && results[0];
            }
        }

        public static string GetContentRaw(string path)
        {
            using (var ps = NewPS())
            {
                ps.AddCommand("Get-Content").AddParameter("Path", path).AddParameter("Raw");
                var results = ps.Invoke<string>();
                return results.Count > 0 ? results[0] : null;
            }
        }

        public static string GetContentRawLiteral(string literalPath)
        {
            using (var ps = NewPS())
            {
                ps.AddCommand("Get-Content").AddParameter("LiteralPath", literalPath).AddParameter("Raw");
                var results = ps.Invoke<string>();
                return results.Count > 0 ? results[0] : null;
            }
        }

        // Calls the PUBLIC ConvertFrom-Json -AsHashtable cmdlet directly rather
        // than Gatekeeper's own private ConvertFrom-JsonToHashtable wrapper:
        // this method can be reached from code running OUTSIDE the module's own
        // session state (e.g. a test calling [PropertySet]::FromFile(...)
        // directly), where PRIVATE module functions are not resolvable even
        // though PowerShell.Create(RunspaceMode.CurrentRunspace) reuses the
        // ambient runspace (confirmed empirically: "ConvertFrom-JsonToHashtable
        // is not recognized" when called this way). ConvertFrom-Json is a
        // built-in cmdlet, always resolvable regardless of caller scope.
        public static Hashtable ConvertFromJsonToHashtable(string json)
        {
            using (var ps = NewPS())
            {
                ps.AddCommand("ConvertFrom-Json").AddParameter("InputObject", json).AddParameter("AsHashtable");
                var results = ps.Invoke();
                return results.Count > 0 ? results[0].BaseObject as Hashtable : null;
            }
        }

        public static bool TestJsonCommandExists()
        {
            using (var ps = NewPS())
            {
                ps.AddCommand("Get-Command").AddParameter("Name", "Test-Json").AddParameter("ErrorAction", "SilentlyContinue");
                var results = ps.Invoke();
                return results.Count > 0;
            }
        }

        public static bool TestJson(string path, string schemaFile)
        {
            using (var ps = NewPS())
            {
                ps.AddCommand("Test-Json").AddParameter("Path", path).AddParameter("SchemaFile", schemaFile);
                var results = ps.Invoke<bool>();
                return results.Count > 0 && results[0];
            }
        }

        public static string ResolvePath(string path)
        {
            using (var ps = NewPS())
            {
                ps.AddCommand("Resolve-Path").AddParameter("Path", path);
                var results = ps.Invoke();
                if (results.Count == 0) { throw new ItemNotFoundException("Cannot find path: " + path); }
                var pathInfo = (PathInfo)results[0].BaseObject;
                return pathInfo.Path;
            }
        }

        public static string ResolveLiteralPathProviderPath(string literalPath)
        {
            using (var ps = NewPS())
            {
                ps.AddCommand("Resolve-Path").AddParameter("LiteralPath", literalPath);
                var results = ps.Invoke();
                if (results.Count == 0) { throw new ItemNotFoundException("Cannot find path: " + literalPath); }
                var pathInfo = (PathInfo)results[0].BaseObject;
                return pathInfo.ProviderPath;
            }
        }

        public static bool ConvertToJsonSupportsEnumsAsStrings()
        {
            using (var ps = NewPS())
            {
                ps.AddCommand("Get-Command").AddParameter("Name", "ConvertTo-Json");
                var results = ps.Invoke();
                if (results.Count == 0) { return false; }
                var cmdInfo = (CommandInfo)results[0].BaseObject;
                return cmdInfo.Parameters.ContainsKey("EnumsAsStrings");
            }
        }

        public static string ConvertToJson(object obj, int depth, bool enumsAsStrings)
        {
            using (var ps = NewPS())
            {
                ps.AddCommand("ConvertTo-Json").AddParameter("InputObject", obj).AddParameter("Depth", depth);
                if (enumsAsStrings) { ps.AddParameter("EnumsAsStrings"); }
                var results = ps.Invoke<string>();
                return results.Count > 0 ? results[0] : null;
            }
        }

        public static void SetContent(string path, string value)
        {
            using (var ps = NewPS())
            {
                ps.AddCommand("Set-Content").AddParameter("Path", path).AddParameter("Value", value);
                ps.Invoke();
            }
        }

        public static void MoveItemForce(string path, string destination)
        {
            using (var ps = NewPS())
            {
                ps.AddCommand("Move-Item").AddParameter("Path", path).AddParameter("Destination", destination).AddParameter("Force");
                ps.Invoke();
            }
        }

        public static string SplitPathParent(string filePath)
        {
            using (var ps = NewPS())
            {
                ps.AddCommand("Split-Path").AddParameter("Path", filePath).AddParameter("Parent");
                var results = ps.Invoke<string>();
                return results.Count > 0 ? results[0] : null;
            }
        }

        public static void NewItemDirectory(string path)
        {
            using (var ps = NewPS())
            {
                ps.AddCommand("New-Item").AddParameter("ItemType", "Directory").AddParameter("Path", path);
                ps.Invoke();
            }
        }

        public static Hashtable ImportGatekeeperConfig()
        {
            using (var ps = NewPS())
            {
                ps.AddCommand("Import-GatekeeperConfig");
                var results = ps.Invoke();
                return results.Count > 0 ? results[0].BaseObject as Hashtable : null;
            }
        }
    }

    public enum Effect
    {
        Allow,
        Deny,
        Audit,
        Warn
    }

    public enum Operator
    {
        Equals,
        NotEquals,
        GreaterThan,
        GreaterThanOrEqual,
        LessThan,
        LessThanOrEqual,
        In,
        NotIn
    }

    public static class GatekeeperPath
    {
        public static string ResolveJsonFilePath(string path)
        {
            if (string.IsNullOrWhiteSpace(path))
            {
                throw new ArgumentException("File path cannot be empty.");
            }
            if (WildcardPattern.ContainsWildcardCharacters(path))
            {
                throw new ArgumentException("File path cannot contain wildcard characters: " + path);
            }
            if (!PSInterop.TestPathLiteralLeaf(path))
            {
                throw new ArgumentException("File not found: " + path);
            }
            string resolved = PSInterop.ResolveLiteralPathProviderPath(path);
            if (System.IO.Path.GetExtension(resolved) != ".json")
            {
                throw new ArgumentException("File path must point to a .json file: " + path);
            }
            bool isUnc = new Uri(resolved).IsUnc;
            if (isUnc && !AllowUncPaths())
            {
                throw new ArgumentException(
                    "UNC file paths are not permitted unless enabled via the Security.AllowUncPaths configuration: " + path);
            }
            return resolved;
        }

        public static bool AllowUncPaths()
        {
            try
            {
                var config = PSInterop.ImportGatekeeperConfig();
                if (config == null) { return false; }
                var security = config["Security"] as Hashtable;
                if (security == null) { return false; }
                var allow = security["AllowUncPaths"];
                return allow != null && Convert.ToBoolean(allow);
            }
            catch
            {
                return false;
            }
        }
    }

    public class Condition
    {
        public object AllOf;
        public object AnyOf;
        public object Not;
        public string Property;
        public string Operator;
        public object Value;

        public Condition(Hashtable data)
        {
            if (data == null)
            {
                throw new ArgumentException("Data cannot be null.");
            }

            var groupKeys = new List<string>();
            foreach (var key in new[] { "AllOf", "AnyOf", "Not" })
            {
                if (data.ContainsKey(key) && data[key] != null)
                {
                    groupKeys.Add(key);
                }
            }
            if (groupKeys.Count > 1)
            {
                throw new ArgumentException(
                    "Condition may only define one of: AllOf, AnyOf, Not. Got: " + string.Join(", ", groupKeys));
            }
            bool hasGroup = groupKeys.Count > 0;
            bool hasProperty = data.ContainsKey("Property") && data["Property"] != null;
            if (hasGroup && hasProperty)
            {
                throw new ArgumentException(
                    "Condition with AllOf, AnyOf, or Not cannot also have Property, Operator, and Value defined.");
            }
            if (hasProperty)
            {
                bool hasOperator = data.ContainsKey("Operator") && data["Operator"] != null;
                bool hasValue = data.ContainsKey("Value") && data["Value"] != null;
                if (!hasOperator || !hasValue)
                {
                    throw new ArgumentException(
                        "Condition with Property must also have Operator and Value defined.");
                }
            }
            if (hasProperty)
            {
                Property = data["Property"].ToString();
            }
            if (data.ContainsKey("Operator") && data["Operator"] != null)
            {
                // Validated eagerly, same as Effect (see Rule.ParseEffect): the
                // original PowerShell `class Condition` declared [Operator]$Operator,
                // so an invalid value threw immediately at construction time via
                // PowerShell's own enum coercion. The initial C# port missed this
                // (kept Operator as a plain string with no validation) - caught by
                // code review, not by any test (no test constructs a Condition with
                // a bad Operator directly; the one existing bad-operator test only
                // checks a generic Should -Throw via Test-Condition's own evaluation-
                // time switch, so moving validation earlier doesn't break it).
                Operator = ParseOperator(data["Operator"]).ToString();
            }
            if (data.ContainsKey("Value") && data["Value"] != null)
            {
                Value = data["Value"];
            }
            if (data.ContainsKey("AllOf") && data["AllOf"] != null)
            {
                AllOf = ConvertList(data["AllOf"]);
            }
            if (data.ContainsKey("AnyOf") && data["AnyOf"] != null)
            {
                AnyOf = ConvertList(data["AnyOf"]);
            }
            if (data.ContainsKey("Not") && data["Not"] != null)
            {
                Not = ConvertList(data["Not"]);
            }
        }

        // Used by New-ConditionGroup.ps1: composes a group condition (AllOf/
        // AnyOf/Not) from already-built child Condition objects, rather than
        // from raw hashtables. Missed in the initial port - New-ConditionGroup
        // has no test coverage, so neither the sequential nor parallel suite
        // caught its absence; added for parity with the original PowerShell
        // `class`'s second constructor.
        public Condition(string connective, object[] conditions)
        {
            var list = ConvertList(conditions);
            switch (connective)
            {
                case "AllOf": AllOf = list; break;
                case "AnyOf": AnyOf = list; break;
                case "Not": Not = list; break;
                default: throw new ArgumentException("Unknown operator: " + connective);
            }
        }

        // Fully-qualified Gatekeeper.Operator (the enum type), not the bare
        // name: inside this class, unqualified `Operator` resolves to the
        // instance field above (string), which would shadow the enum type.
        private static Gatekeeper.Operator ParseOperator(object value)
        {
            if (value is Gatekeeper.Operator o) { return o; }
            return (Gatekeeper.Operator)System.Enum.Parse(typeof(Gatekeeper.Operator), value.ToString(), true);
        }

        // Accepts items that are already Condition instances (the
        // New-ConditionGroup path) as well as raw Hashtables (the
        // Hashtable-constructor path) - ToString() always casts AllOf/AnyOf/
        // Not to List<Condition>, so both constructors must store the same
        // uniform representation.
        private static List<Condition> ConvertList(object source)
        {
            var result = new List<Condition>();
            foreach (var item in (IEnumerable)source)
            {
                result.Add(item is Condition c ? c : new Condition((Hashtable)item));
            }
            return result;
        }

        public static Condition FromJson(string json)
        {
            var data = PSInterop.ConvertFromJsonToHashtable(json);
            return new Condition(data);
        }

        public bool IsValid()
        {
            if (AllOf != null || AnyOf != null || Not != null) { return true; }
            return Property != null && Operator != null && Value != null;
        }

        public override string ToString()
        {
            var sb = new StringBuilder();
            if (AllOf != null)
            {
                sb.Append("AllOf(");
                sb.Append(string.Join(", ", ((List<Condition>)AllOf).Select(c => c.ToString())));
                sb.Append(")");
            }
            if (AnyOf != null)
            {
                sb.Append("AnyOf(");
                sb.Append(string.Join(", ", ((List<Condition>)AnyOf).Select(c => c.ToString())));
                sb.Append(")");
            }
            if (Not != null)
            {
                sb.Append("Not(");
                sb.Append(string.Join(", ", ((List<Condition>)Not).Select(c => c.ToString())));
                sb.Append(")");
            }
            if (Property != null && Operator != null && Value != null)
            {
                sb.Append(Property + " " + Operator + " " + Value);
            }
            return sb.ToString();
        }
    }

    public class PropertyValidation
    {
        public int? Minimum;
        public int? Maximum;
        public int? MinLength;
        public int? MaxLength;
        public string Pattern;

        public PropertyValidation(Hashtable data)
        {
            if (data.ContainsKey("Minimum") && data["Minimum"] != null) { Minimum = Convert.ToInt32(data["Minimum"]); }
            if (data.ContainsKey("Maximum") && data["Maximum"] != null) { Maximum = Convert.ToInt32(data["Maximum"]); }
            if (data.ContainsKey("MinLength") && data["MinLength"] != null) { MinLength = Convert.ToInt32(data["MinLength"]); }
            if (data.ContainsKey("MaxLength") && data["MaxLength"] != null) { MaxLength = Convert.ToInt32(data["MaxLength"]); }
            if (data.ContainsKey("Pattern")) { Pattern = data["Pattern"]?.ToString(); }
        }

        public Hashtable ToHashtable()
        {
            var data = new Hashtable();
            if (Minimum.HasValue) { data["Minimum"] = Minimum.Value; }
            if (Maximum.HasValue) { data["Maximum"] = Maximum.Value; }
            if (MinLength.HasValue) { data["MinLength"] = MinLength.Value; }
            if (MaxLength.HasValue) { data["MaxLength"] = MaxLength.Value; }
            if (!string.IsNullOrEmpty(Pattern)) { data["Pattern"] = Pattern; }
            return data;
        }
    }

    public class Property
    {
        public string Name;
        public string Type;
        public object[] Enum;
        public PropertyValidation Validation;

        public Property(string name, Hashtable data)
        {
            Name = name;
            Type = data["Type"] as string;

            if (data.ContainsKey("Enum"))
            {
                Enum = ToObjectArray(data["Enum"]);
            }

            if (data.ContainsKey("Validation") && data["Validation"] != null)
            {
                Validation = new PropertyValidation((Hashtable)data["Validation"]);
            }
        }

        private static object[] ToObjectArray(object source)
        {
            if (source == null) { return null; }
            if (source is object[] arr) { return arr; }
            var list = new List<object>();
            foreach (var item in (IEnumerable)source) { list.Add(item); }
            return list.ToArray();
        }

        public Hashtable ToHashtable()
        {
            var data = new Hashtable();
            data["Type"] = Type;
            if (Enum != null) { data["Enum"] = Enum; }
            if (Validation != null) { data["Validation"] = Validation.ToHashtable(); }
            return data;
        }

        // The last warning message ValidateCore wanted to emit, or null if
        // the most recent call was valid. ValidateCore cannot reliably write a
        // real, redirectable WarningRecord itself: a nested
        // PowerShell.Create(RunspaceMode.CurrentRunspace) call to Write-Warning
        // writes straight to the host, bypassing the calling pipeline's own
        // stream redirection (confirmed empirically - a test capturing
        // warnings via `& { ... } 3>&1` saw nothing). The real Write-Warning
        // call happens in a genuine PowerShell ScriptMethod "Validate" (see
        // the bottom of this script, registered via Update-TypeData), which
        // runs as actual script code in the caller's own pipeline and so
        // threads correctly through 3>&1/$WarningPreference - it calls this
        // method, then emits LastValidationWarning itself if non-null.
        public string LastValidationWarning;

        public bool ValidateCore(object Value)
        {
            LastValidationWarning = null;
            if (Validation == null) { return true; }
            switch (Type)
            {
                case "integer":
                {
                    long v = Convert.ToInt64(Value);
                    if (Validation.Minimum.HasValue && v < Validation.Minimum.Value)
                    {
                        LastValidationWarning = string.Format(
                            "Value for '{0}' ({1}) is less than minimum allowed ({2})", Name, Value, Validation.Minimum.Value);
                        return false;
                    }
                    if (Validation.Maximum.HasValue && v > Validation.Maximum.Value)
                    {
                        LastValidationWarning = string.Format(
                            "Value for '{0}' ({1}) is greater than maximum allowed ({2})", Name, Value, Validation.Maximum.Value);
                        return false;
                    }
                    break;
                }
                case "string":
                {
                    string s = Value.ToString();
                    if (Validation.MinLength.HasValue && s.Length < Validation.MinLength.Value)
                    {
                        LastValidationWarning = string.Format(
                            "Value for '{0}' is shorter than MinLength ({1})", Name, Validation.MinLength.Value);
                        return false;
                    }
                    if (Validation.MaxLength.HasValue && s.Length > Validation.MaxLength.Value)
                    {
                        LastValidationWarning = string.Format(
                            "Value for '{0}' is longer than MaxLength ({1})", Name, Validation.MaxLength.Value);
                        return false;
                    }
                    if (!string.IsNullOrEmpty(Validation.Pattern))
                    {
                        try
                        {
                            var re = new System.Text.RegularExpressions.Regex(
                                Validation.Pattern,
                                System.Text.RegularExpressions.RegexOptions.None,
                                TimeSpan.FromMilliseconds(250));
                            if (!re.IsMatch(s))
                            {
                                LastValidationWarning = string.Format(
                                    "Value for '{0}' does not match pattern '{1}'", Name, Validation.Pattern);
                                return false;
                            }
                        }
                        catch (System.Text.RegularExpressions.RegexMatchTimeoutException)
                        {
                            LastValidationWarning = string.Format("Pattern evaluation timed out for '{0}'", Name);
                            return false;
                        }
                    }
                    break;
                }
            }
            return true;
        }
    }

    public class PropertySet
    {
        public string Name;
        public string FilePath;
        public Hashtable Properties;

        public PropertySet(string name)
        {
            Name = name;
            Properties = new Hashtable();
        }

        public PropertySet(Hashtable rawData)
        {
            Properties = new Hashtable();
            foreach (var keyObj in rawData.Keys)
            {
                string key = keyObj.ToString();
                if (key == "$schema") { continue; }
                Properties[key] = new Property(key, (Hashtable)rawData[keyObj]);
            }
        }

        // Set once, from the OUTER PowerShell wrapper script (Classes/
        // CompiledTypes.ps1 itself, which has a real, reliable $PSScriptRoot -
        // unlike a nested nested PowerShell.Create() call, and unlike a
        // Get-Module lookup, which isn't guaranteed to find "Gatekeeper" from
        // every calling scope). See the bottom of this script.
        public static string SchemaFile;

        public static PropertySet FromFile(string filePath)
        {
            if (!PSInterop.TestPath(filePath))
            {
                throw new ArgumentException("File path given did not exist: " + filePath);
            }
            if (PSInterop.TestJsonCommandExists())
            {
                bool validProperties = PSInterop.TestJson(filePath, SchemaFile);
                if (!validProperties)
                {
                    throw new ArgumentException("Properties file is not valid.");
                }
            }
            string json = PSInterop.GetContentRaw(filePath);
            var data = PSInterop.ConvertFromJsonToHashtable(json);
            if (data == null)
            {
                throw new ArgumentException("Failed to create hashtable from json file");
            }
            var ps = new PropertySet(data);
            ps.FilePath = PSInterop.ResolvePath(filePath);
            ps.Name = System.IO.Path.GetFileNameWithoutExtension(ps.FilePath);
            return ps;
        }

        public static PropertySet FromJson(string json)
        {
            var data = PSInterop.ConvertFromJsonToHashtable(json);
            return new PropertySet(data);
        }

        public PropertySet AddProperty(Property property)
        {
            Properties.Add(property.Name, property);
            return this;
        }

        public Property GetProperty(string name)
        {
            return Properties[name] as Property;
        }

        public string[] GetNames()
        {
            var names = new string[Properties.Keys.Count];
            Properties.Keys.CopyTo(names, 0);
            return names;
        }

        public bool ContainsKey(string name)
        {
            return Properties.ContainsKey(name);
        }

        public void Save()
        {
            if (FilePath == null)
            {
                throw new ArgumentException("No file path specified to save PropertySet.");
            }
            string parent = PSInterop.SplitPathParent(FilePath);
            if (!PSInterop.TestPath(parent))
            {
                PSInterop.NewItemDirectory(parent);
            }
            var hashtable = new Hashtable();
            hashtable["$schema"] = "https://raw.githubusercontent.com/PowerShell/Gatekeeper/main/Schemas/Properties.json";
            foreach (var key in Properties.Keys)
            {
                hashtable[key] = ((Property)Properties[key]).ToHashtable();
            }
            string json = PSInterop.ConvertToJson(hashtable, 10, false);
            string tmpPath = FilePath + ".tmp";
            PSInterop.SetContent(tmpPath, json);
            PSInterop.MoveItemForce(tmpPath, FilePath);
        }
    }

    public class Rule
    {
        public string Name;
        public string Description;
        public Effect Effect;
        public Condition Condition;

        public Rule(string name)
        {
            Name = name;
        }

        public Rule(Hashtable data)
        {
            Name = data["Name"] as string;
            Description = data["Description"] as string;
            if (data.ContainsKey("Effect") && data["Effect"] != null)
            {
                Effect = ParseEffect(data["Effect"]);
            }
            if (data.ContainsKey("Condition") && data["Condition"] != null)
            {
                var condVal = data["Condition"];
                if (condVal is Condition c)
                {
                    Condition = c;
                }
                else if (condVal is Hashtable h)
                {
                    Condition = new Condition(h);
                }
                else
                {
                    throw new ArgumentException("Unknown type for Condition: " + condVal.GetType().FullName);
                }
            }
        }

        internal static Effect ParseEffect(object value)
        {
            if (value is Effect e) { return e; }
            return (Effect)System.Enum.Parse(typeof(Effect), value.ToString(), true);
        }
    }

    public class FeatureFlag
    {
        public string Name;
        public string Description;
        public string[] Tags;
        public Version Version;
        public string Author;
        public Effect DefaultEffect;
        public Rule[] Rules;
        public string FilePath;

        public FeatureFlag() { }

        public FeatureFlag(Hashtable data)
        {
            Name = data["Name"] as string;
            Description = data["Description"] as string;
            Tags = ToStringArray(data["Tags"]);
            if (data["Version"] != null)
            {
                var versionData = data["Version"];
                if (versionData is IDictionary dict)
                {
                    object buildObj = dict.Contains("Build") ? dict["Build"] : null;
                    int b = buildObj == null ? 0 : Convert.ToInt32(buildObj);
                    int major = Convert.ToInt32(dict["Major"]);
                    int minor = Convert.ToInt32(dict["Minor"]);
                    Version = b >= 0 ? new Version(major, minor, b) : new Version(major, minor);
                }
                else
                {
                    Version = new Version(versionData.ToString());
                }
            }
            Author = data["Author"] as string;
            if (data["DefaultEffect"] != null)
            {
                DefaultEffect = Rule.ParseEffect(data["DefaultEffect"]);
            }
            var rulesList = new List<Rule>();
            if (data["Rules"] != null)
            {
                foreach (var item in (IEnumerable)data["Rules"])
                {
                    rulesList.Add(item is Rule r ? r : new Rule((Hashtable)item));
                }
            }
            Rules = rulesList.ToArray();
        }

        private static string[] ToStringArray(object source)
        {
            if (source == null) { return null; }
            if (source is string[] arr) { return arr; }
            var list = new List<string>();
            foreach (var item in (IEnumerable)source) { list.Add(item?.ToString()); }
            return list.ToArray();
        }

        public static FeatureFlag FromJson(string json)
        {
            var data = PSInterop.ConvertFromJsonToHashtable(json);
            return new FeatureFlag(data);
        }

        public static FeatureFlag FromFile(string filePath)
        {
            if (!PSInterop.TestPath(filePath))
            {
                throw new ArgumentException("File not found: " + filePath);
            }
            string json = PSInterop.GetContentRaw(filePath);
            var featureFlag = FromJson(json);
            featureFlag.FilePath = filePath;
            return featureFlag;
        }

        public void Save()
        {
            if (FilePath == null)
            {
                throw new ArgumentException("No file path specified to save FeatureFlag.");
            }
            bool enumsAsStrings = PSInterop.ConvertToJsonSupportsEnumsAsStrings();
            string json = PSInterop.ConvertToJson(this, 10, enumsAsStrings);
            string tmpPath = FilePath + ".tmp";
            PSInterop.SetContent(tmpPath, json);
            PSInterop.MoveItemForce(tmpPath, FilePath);
        }
    }

    public class ConditionTransformAttribute : ArgumentTransformationAttribute
    {
        public override object Transform(EngineIntrinsics engineIntrinsics, object inputData)
        {
            if (inputData == null)
            {
                throw new ArgumentNullException("Condition", "Rule has no Condition. Each rule must define a 'Condition'.");
            }
            // PowerShell's own `-is`/`-as` operators transparently see through a
            // PSObject wrapper to the underlying .NET object; a raw C# `is`
            // pattern match does not, so unwrap explicitly here (confirmed:
            // without this, an ordered dictionary arriving via parameter
            // binding is still boxed as PSObject at this point and falls
            // through to "Cannot convert type ... PSObject").
            if (inputData is PSObject pso) { inputData = pso.BaseObject; }
            if (inputData is Condition) { return inputData; }
            if (inputData is IDictionary dict) { return new Condition(PSInterop.ToHashtable(dict)); }
            if (inputData is string s)
            {
                string resolvedPath = GatekeeperPath.ResolveJsonFilePath(s);
                string json = PSInterop.GetContentRawLiteral(resolvedPath);
                return Condition.FromJson(json);
            }
            throw new InvalidOperationException("Cannot convert type to Condition: " + inputData.GetType().FullName);
        }

        public override string ToString()
        {
            return "[ConditionTransformAttribute()]";
        }
    }

    public class PropertySetTransformAttribute : ArgumentTransformationAttribute
    {
        public override object Transform(EngineIntrinsics engineIntrinsics, object inputData)
        {
            if (inputData == null) { return null; }
            if (inputData is PSObject pso) { inputData = pso.BaseObject; }
            if (inputData is PropertySet) { return inputData; }
            if (inputData is IDictionary dict) { return new PropertySet(PSInterop.ToHashtable(dict)); }
            throw new InvalidOperationException("Cannot convert type to PropertySet: " + inputData.GetType().FullName);
        }

        public override string ToString()
        {
            return "[PropertySetTransformAttribute()]";
        }
    }

    public class FeatureFlagTransformAttribute : ArgumentTransformationAttribute
    {
        public override object Transform(EngineIntrinsics engineIntrinsics, object inputData)
        {
            if (inputData == null)
            {
                throw new ArgumentNullException("FeatureFlag", "FeatureFlag cannot be null.");
            }
            if (inputData is PSObject pso) { inputData = pso.BaseObject; }
            if (inputData is FeatureFlag) { return inputData; }
            if (inputData is IDictionary dict) { return new FeatureFlag(PSInterop.ToHashtable(dict)); }
            if (inputData is string s)
            {
                string resolvedPath = GatekeeperPath.ResolveJsonFilePath(s);
                string json = PSInterop.GetContentRawLiteral(resolvedPath);
                return FeatureFlag.FromJson(json);
            }
            throw new InvalidOperationException("Cannot convert type to FeatureFlag: " + inputData.GetType().FullName);
        }

        public override string ToString()
        {
            return "[FeatureFlagTransformAttribute()]";
        }
    }
}
'@
    }
    $acceleratorTypes = @{
        'Effect'                        = [Gatekeeper.Effect]
        'Operator'                      = [Gatekeeper.Operator]
        'Condition'                     = [Gatekeeper.Condition]
        'Property'                      = [Gatekeeper.Property]
        'PropertySet'                    = [Gatekeeper.PropertySet]
        'Rule'                           = [Gatekeeper.Rule]
        'FeatureFlag'                    = [Gatekeeper.FeatureFlag]
        'ConditionTransformAttribute'    = [Gatekeeper.ConditionTransformAttribute]
        'PropertySetTransformAttribute'  = [Gatekeeper.PropertySetTransformAttribute]
        'FeatureFlagTransformAttribute'  = [Gatekeeper.FeatureFlagTransformAttribute]
    }
    foreach ($name in $acceleratorTypes.Keys) {
        [void]$TypeAcceleratorsClass::Remove($name)
        $TypeAcceleratorsClass::Add($name, $acceleratorTypes[$name])
    }
} finally {
    [System.Threading.Monitor]::Exit($TypeAcceleratorsClass)
}

# PropertySet.FromFile needs the Properties.json schema's real on-disk path.
# $PSScriptRoot is reliable HERE (this is a real script file being processed),
# unlike inside a nested PowerShell.Create() call or a Get-Module lookup from
# arbitrary caller scope (both tried and rejected - see comments above).
# The static field is process-wide (same compiled Type, same AppDomain), so
# this technically runs once per runspace's ScriptsToProcess pass but every
# runspace in this process loads the same module from the same location and
# computes the identical value - redundant, but harmless, writes.
[Gatekeeper.PropertySet]::SchemaFile = Join-Path $PSScriptRoot '..\Schemas\Properties.json'

# Property.Validate's warning side effect must be real, redirectable
# PowerShell script code (Write-Warning called from genuine script context
# threads correctly through 3>&1/$WarningPreference in the caller; a nested
# PowerShell.Create(RunspaceMode.CurrentRunspace) call from inside the C#
# method does not - confirmed empirically, see ValidateCore's comment).
# -Force makes repeat registration (every runspace's ScriptsToProcess pass,
# plus Gatekeeper.psm1's own Classes/*.ps1 dot-source loop re-running this
# same file) an idempotent no-op instead of an error.
Update-TypeData -TypeName 'Gatekeeper.Property' -MemberType ScriptMethod -MemberName 'Validate' -Force -Value {
    param($Value)
    $result = $this.ValidateCore($Value)
    if (-not $result -and $this.LastValidationWarning) {
        Write-Warning $this.LastValidationWarning
    }
    return $result
}
