# GUI Critical Test - Quick Reference
# =====================================

## Overview
The Test-GUI-Critical.ps1 script performs automated validation of the WinRepairGUI.ps1 
to ensure it can load without errors. It runs independently without requiring any user interaction.

## How to Run

1. Open PowerShell in the workspace directory:
   .\Test-GUI-Critical.ps1

2. Expected Output:
   - 16 validation checks
   - 100% pass rate confirms GUI is ready to load
   - Exit code 0 = success, exit code 1 = failure

## What It Tests

1. **File Integrity** - Verifies the GUI file exists and is accessible
2. **Syntax Validation** - Checks PowerShell syntax using AST parser
3. **Required Assemblies** - Validates PresentationFramework and Windows.Forms are available
4. **XAML Structure** - Verifies XAML Window definition and element balance
5. **Function Definitions** - Ensures Start-GUI and event handlers are properly defined
6. **Script Scope** - Checks error handling patterns and string delimiters
7. **AST Analysis** - Validates function definition in abstract syntax tree
8. **Dependency Check** - Confirms GUI references required assemblies

## Test Results Interpretation

✓ CRITICAL STATUS: GUI READY TO LOAD
  - All 16 checks passed
  - GUI should initialize without critical errors
  - Exit code: 0

✗ CRITICAL STATUS: GUI LOAD FAILURE RISK
  - One or more checks failed
  - Review "Failed Checks" section for details
  - Exit code: 1

## Usage in CI/CD

The script exits with code 0 on success, 1 on failure, making it suitable for:
- Automated testing pipelines
- Pre-deployment validation
- Continuous integration workflows

Example:
  .\Test-GUI-Critical.ps1
  if ($LASTEXITCODE -eq 0) {
      Write-Host "GUI validation passed"
  } else {
      Write-Host "GUI validation failed"
      exit 1
  }

## Requirements

- PowerShell 5.0 or higher
- WinRepairGUI.ps1 in the same directory
- PresentationFramework assembly (Windows systems)
- No user interaction required

## Files

- Test-GUI-Critical.ps1 - Main test script (this file)
- WinRepairGUI.ps1 - GUI file being tested

## Version

1.1 - MiracleBoot v7.2.0

