# Gatekeeper Testing Plan

## Executive Summary

This document outlines a comprehensive testing strategy for the Gatekeeper PowerShell module. The plan addresses current test coverage gaps, defines testing categories, and provides a prioritized implementation roadmap.

## Current Testing Status

### Existing Test Coverage

**Currently Tested (10 test files):**
- ✅ `Test-FeatureFlag` - Core evaluation logic
- ✅ `Test-Condition` - Condition evaluation
- ✅ `Read-PropertySet` - PropertySet loading
- ✅ `Read-FeatureFlag` - FeatureFlag loading
- ✅ `Get-DefaultContext` - Default context generation
- ✅ `Convert-ToTypedValue` - Type conversion (private)
- ✅ Meta tests - File formatting, encoding
- ✅ Manifest tests - Module manifest validation
- ✅ Help tests - Comment-based help
- ✅ Fixtures tests - Test data validation

### Missing Test Coverage (13 functions)

**Configuration Management:**
- ❌ `Export-GatekeeperConfig`
- ❌ `Import-GatekeeperConfig`
- ❌ `Get-FeatureFlagFolder`
- ❌ `Get-PropertySetFolder`
- ❌ `Get-PropertySet`

**Object Creation:**
- ❌ `New-FeatureFlag`
- ❌ `New-Rule`
- ❌ `New-ConditionGroup`
- ❌ `New-Condition`
- ❌ `New-PropertySet`
- ❌ `New-Property`

**Persistence:**
- ❌ `Save-FeatureFlag`
- ❌ `Save-PropertySet`

**Classes & Infrastructure:**
- ❌ Class tests (FeatureFlag, PropertySet, Rule, ConditionGroup, etc.)
- ❌ Enum tests (Effect)
- ❌ Type accelerator tests
- ❌ Argument transformation tests

## Testing Strategy

### Test Categories

#### 1. Unit Tests
Test individual functions and methods in isolation.

**Priority: HIGH**

**Scope:**
- All public functions (18 total)
- All private functions (2 total)
- All classes (Property, FeatureFlag)
- All enums (Effect)

**Coverage Goals:**
- 90%+ code coverage for critical paths
- 100% of public API surface
- All parameter combinations and validation
- Edge cases and boundary conditions

#### 2. Integration Tests
Test interactions between components.

**Priority: HIGH**

**Scope:**
- Full evaluation pipeline (PropertySet → Context → FeatureFlag → Result)
- Configuration system integration
- JSON schema validation
- File I/O operations (Read/Save)
- Type accelerator registration
- Argument transformation

**Test Scenarios:**
- Load PropertySet from file → Create Context → Evaluate FeatureFlag
- Create objects via New-* functions → Save to file → Read back → Validate
- Configuration changes → Effect on module behavior
- Invalid inputs → Proper error handling

#### 3. Functional Tests
Test complete user workflows end-to-end.

**Priority: MEDIUM**

**Scenarios:**
- **Scenario 1: First-time setup**
  - Bootstrap module
  - Create PropertySet
  - Create FeatureFlag
  - Test evaluation

- **Scenario 2: Feature rollout**
  - Create feature with Deny default
  - Add Allow rule for staging
  - Add Allow rule for 10% production
  - Test evaluation across contexts

- **Scenario 3: Configuration management**
  - Export configuration
  - Modify settings
  - Import configuration
  - Verify behavior changes

- **Scenario 4: Complex conditions**
  - Create nested condition groups (AllOf/AnyOf/Not)
  - Test with multiple property types
  - Verify correct logical evaluation

#### 4. Validation Tests
Test data validation and schema enforcement.

**Priority: HIGH**

**Scope:**
- JSON schema validation for FeatureFlags
- JSON schema validation for PropertySets
- Property type validation (string, integer, boolean)
- Property constraints (min/max, enum, regex)
- Rule validation (conditions, effects)

**Test Cases:**
- Valid schemas → Success
- Invalid schemas → Clear error messages
- Type mismatches → Validation failure
- Constraint violations → Descriptive errors

#### 5. Error Handling Tests
Test error conditions and failure modes.

**Priority: HIGH**

**Scenarios:**
- Missing required files
- Corrupted JSON
- Invalid property types
- Type conversion failures
- Schema validation failures
- Missing configuration
- Permission errors
- Circular dependencies

**Expectations:**
- Clear, actionable error messages
- Fail-safe defaults (return $false when uncertain)
- No unhandled exceptions
- Proper warning/verbose output

#### 6. Performance Tests
Test execution speed and resource usage.

**Priority: LOW**

**Scope:**
- Large PropertySets (100+ properties)
- Complex FeatureFlags (50+ rules)
- Deep condition nesting (10+ levels)
- Rapid evaluation (1000+ calls/second)
- Memory usage under load

**Benchmarks:**
- Simple evaluation: < 10ms
- Complex evaluation: < 100ms
- Schema validation: < 50ms
- File operations: < 200ms

#### 7. Security Tests
Test security-related functionality.

**Priority: MEDIUM**

**Scope:**
- Script injection in logging scriptblocks
- Path traversal in file operations
- Configuration tampering
- Schema bypass attempts
- Type confusion attacks

**Validation:**
- No arbitrary code execution
- Proper input sanitization
- Safe file path handling
- Secure default configurations

#### 8. Regression Tests
Prevent reintroduction of fixed bugs.

**Priority: MEDIUM**

**Process:**
- Document known issues in CHANGELOG.md
- Create test for each bug fix
- Tag with issue number
- Verify fix remains effective

## Test Implementation Plan

### Phase 1: Critical Coverage (Weeks 1-2)
**Goal: Cover all untested public functions**

1. **New-* Functions** (Priority 1)
   - `New-FeatureFlag.tests.ps1`
   - `New-Rule.tests.ps1`
   - `New-ConditionGroup.tests.ps1`
   - `New-Condition.tests.ps1`
   - `New-PropertySet.tests.ps1`
   - `New-Property.tests.ps1`

2. **Save-* Functions** (Priority 1)
   - `Save-FeatureFlag.tests.ps1`
   - `Save-PropertySet.tests.ps1`

3. **Configuration Functions** (Priority 2)
   - `Get-PropertySet.tests.ps1`
   - `Export-GatekeeperConfig.tests.ps1`
   - `Import-GatekeeperConfig.tests.ps1`
   - `Get-FeatureFlagFolder.tests.ps1`
   - `Get-PropertySetFolder.tests.ps1`

### Phase 2: Infrastructure & Integration (Weeks 3-4)
**Goal: Test core infrastructure and cross-component behavior**

4. **Class Tests** (Priority 1)
   - `Classes/PropertySet.tests.ps1`
   - `Classes/FeatureFlag.tests.ps1`
   - `Classes/Rule.tests.ps1`
   - `Classes/ConditionGroup.tests.ps1`

5. **Integration Tests** (Priority 1)
   - `Integration.tests.ps1` - Full evaluation pipeline
   - `Transformation.tests.ps1` - Argument transformations
   - `TypeAccelerators.tests.ps1` - Type registration

6. **Validation Tests** (Priority 1)
   - `Schema.tests.ps1` - JSON schema validation
   - `PropertyValidation.tests.ps1` - Type & constraint validation

### Phase 3: Quality & Hardening (Weeks 5-6)
**Goal: Ensure robustness and reliability**

7. **Error Handling** (Priority 1)
   - `ErrorHandling.tests.ps1` - Comprehensive error scenarios
   - Update existing tests with negative test cases

8. **Functional Tests** (Priority 2)
   - `Scenarios.tests.ps1` - End-to-end workflows

9. **Performance Tests** (Priority 3)
   - `Performance.tests.ps1` - Benchmarking and profiling

10. **Security Tests** (Priority 2)
    - `Security.tests.ps1` - Security validation

### Phase 4: Coverage Analysis & Refinement (Week 7)
**Goal: Achieve 90%+ code coverage**

11. **Code Coverage Analysis**
    - Run Pester with CodeCoverage
    - Identify untested code paths
    - Add targeted tests for gaps

12. **Documentation**
    - Update test documentation
    - Add testing guidelines
    - Document test fixtures and helpers

## Test Infrastructure

### Test Helpers and Fixtures

**Create shared test utilities:**

1. **`tests/Helpers/TestHelpers.psm1`**
   - Common setup/teardown functions
   - Mock data generators
   - Assertion helpers
   - Test context builders

2. **`tests/fixtures/` Enhancements**
   - Add more PropertySet samples
   - Add more FeatureFlag samples
   - Add invalid/malformed samples
   - Add edge case samples

3. **`tests/Helpers/Mocks.psm1`**
   - Mock Configuration module
   - Mock file system operations
   - Mock logging behaviors

### Pester Configuration

**Create `PesterConfiguration.psd1`:**

```powershell
@{
    Run = @{
        Path = './tests'
        ExcludePath = @('./tests/fixtures/*')
        PassThru = $true
    }
    CodeCoverage = @{
        Enabled = $true
        Path = './Gatekeeper/**/*.ps1'
        OutputFormat = 'JaCoCo'
        OutputPath = './out/coverage.xml'
    }
    TestResult = @{
        Enabled = $true
        OutputFormat = 'NUnitXml'
        OutputPath = './out/testResults.xml'
    }
    Should = @{
        ErrorAction = 'Stop'
    }
    Output = @{
        Verbosity = 'Detailed'
    }
}
```

### CI/CD Integration

**GitHub Actions Workflow (`.github/workflows/test.yml`):**

```yaml
name: Test

on: [push, pull_request]

jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        powershell-version: ['7.2', '7.3', '7.4']
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v3
      - name: Bootstrap dependencies
        shell: pwsh
        run: ./build.ps1 -Bootstrap
      - name: Run tests
        shell: pwsh
        run: ./build.ps1 -Task Test
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./out/coverage.xml
      - name: Upload test results
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: test-results-${{ matrix.os }}-${{ matrix.powershell-version }}
          path: ./out/testResults.xml
```

**Add coverage reporting:**
- Integrate with Codecov or Coveralls
- Add coverage badge to README.md
- Set minimum coverage threshold (e.g., 80%)

## Quality Metrics

### Success Criteria

**Test Coverage:**
- Overall: ≥ 90%
- Public functions: 100%
- Critical paths (evaluation logic): 100%
- Configuration management: ≥ 85%
- Error handling: ≥ 80%

**Test Quality:**
- All tests pass on Windows, Linux, macOS
- All tests pass on PowerShell 7.2, 7.3, 7.4
- No flaky tests (tests must be deterministic)
- Test execution time: < 2 minutes for full suite
- No test interdependencies (can run in any order)

**Code Quality:**
- All PSScriptAnalyzer rules pass
- No duplicate test code (use helpers)
- Clear test names and descriptions
- Each test validates one behavior
- Arrange-Act-Assert pattern

### Monitoring and Reporting

**Weekly Reports:**
- Test count (total, passing, failing)
- Code coverage percentage
- New tests added
- Test execution time
- Identified gaps

**Per-PR Requirements:**
- New code must include tests
- Coverage cannot decrease
- All tests must pass
- PSScriptAnalyzer must pass

## Testing Best Practices

### Test Structure

**Follow AAA Pattern:**
```powershell
It 'should allow feature when rule matches' {
    # Arrange
    $properties = Read-PropertySet -File "fixtures/Properties.json"
    $context = @{ Environment = 'Production' }
    $featureFlag = New-FeatureFlag -Name 'TestFeature' -DefaultEffect Deny

    # Act
    $result = Test-FeatureFlag -FeatureFlag $featureFlag -Properties $properties -Context $context

    # Assert
    $result | Should -BeTrue
}
```

### Naming Conventions

**Descriptive test names:**
```powershell
# Good
It 'should return false when context property is missing'
It 'should throw when PropertySet has invalid type'
It 'should evaluate AllOf condition as true when all conditions match'

# Bad
It 'works'
It 'test 1'
It 'returns correct value'
```

### Test Data Management

**Use fixtures consistently:**
- Keep fixtures in `tests/fixtures/`
- Use realistic, representative data
- Document fixture purpose
- Version control all fixtures
- Create fixture validation tests

### Mocking Guidelines

**When to mock:**
- External dependencies (file system, network)
- Expensive operations
- Non-deterministic behavior (random, time)
- Configuration module

**When NOT to mock:**
- Internal module functions (test real implementation)
- Simple operations
- Critical business logic

## Appendix: Test Template

**Template for new test files:**

```powershell
BeforeDiscovery {
    $manifest = Import-PowerShellDataFile -Path $env:BHPSModuleManifest
    $outputDir = Join-Path -Path $env:BHProjectPath -ChildPath 'Output'
    $outputModDir = Join-Path -Path $outputDir -ChildPath $env:BHProjectName
    $outputModVerDir = Join-Path -Path $outputModDir -ChildPath $manifest.ModuleVersion
    $outputModVerManifest = Join-Path -Path $outputModVerDir -ChildPath "$($env:BHProjectName).psd1"

    Get-Module $env:BHProjectName | Remove-Module -Force -ErrorAction Ignore
    Import-Module -Name $outputModVerManifest -Verbose:$false -ErrorAction Stop
}

Describe '<FunctionName>' {
    BeforeAll {
        # Common setup
    }

    Context 'Parameter validation' {
        It 'should accept valid parameters' {
            # Test
        }

        It 'should reject invalid parameters' {
            # Test
        }
    }

    Context 'Happy path' {
        It 'should perform expected operation' {
            # Test
        }
    }

    Context 'Error handling' {
        It 'should handle missing input gracefully' {
            # Test
        }

        It 'should provide clear error messages' {
            # Test
        }
    }

    Context 'Edge cases' {
        It 'should handle boundary conditions' {
            # Test
        }
    }
}
```

## Conclusion

This testing plan provides a structured approach to achieving comprehensive test coverage for the Gatekeeper module. By following the phased implementation plan and adhering to the defined quality metrics, the module will achieve enterprise-grade reliability and maintainability.

**Next Steps:**
1. Review and approve this plan
2. Set up CI/CD pipeline
3. Begin Phase 1 implementation
4. Establish weekly progress reviews
5. Adjust plan based on findings
