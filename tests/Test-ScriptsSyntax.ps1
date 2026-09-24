<#
.SYNOPSIS
    Automated Syntax and Parse Validator for Enterprise Lab PowerShell scripts.

.DESCRIPTION
    Iterates through all .ps1 scripts in the /scripts folder and analyzes their AST
    using System.Management.Automation.Language.Parser. Fails with non-zero exit code
    if any syntax error is detected.
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [string]$ScriptsDirectory
)

if (-not $ScriptsDirectory) {
    if ($PSScriptRoot) {
        $ScriptsDirectory = Join-Path -Path $PSScriptRoot -ChildPath "..\scripts"
    } else {
        $ScriptsDirectory = ".\scripts"
    }
}
$ScriptsDirectory = [System.IO.Path]::GetFullPath($ScriptsDirectory)


Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " [TEST SUITE] PowerShell AST Syntax Verification                " -ForegroundColor Cyan
Write-Host " Target Directory: $ScriptsDirectory                             " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

if (-not (Test-Path -Path $ScriptsDirectory)) {
    Write-Error "Scripts directory '$ScriptsDirectory' does not exist."
    exit 1
}

$scriptFiles = Get-ChildItem -Path $ScriptsDirectory -Filter "*.ps1" -Recurse
if ($scriptFiles.Count -eq 0) {
    Write-Warning "No .ps1 scripts found in '$ScriptsDirectory'."
    exit 0
}

$totalErrors = 0
$testedCount = 0

foreach ($file in $scriptFiles) {
    $testedCount++
    $tokens = $null
    $errors = $null
    
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null

    if ($errors.Count -gt 0) {
        Write-Host " [FAIL] $($file.Name) - $($errors.Count) syntax error(s):" -ForegroundColor Red
        foreach ($err in $errors) {
            Write-Host "        Line $($err.Extent.StartLineNumber): $($err.Message)" -ForegroundColor Red
        }
        $totalErrors += $errors.Count
    } else {
        Write-Host " [PASS] $($file.Name)" -ForegroundColor Green
    }
}

Write-Host "`n-----------------------------------------------------------------"
Write-Host "Tested $testedCount script(s). Total Errors: $totalErrors" -ForegroundColor $(if ($totalErrors -eq 0) { "Green" } else { "Red" })
Write-Host "=================================================================" -ForegroundColor Cyan

if ($totalErrors -gt 0) {
    exit 1
} else {
    exit 0
}
