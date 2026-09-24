<#
.SYNOPSIS
    Automates deployment of Group Policy Security Baselines for Apex Global Logistics.

.DESCRIPTION
    Creates, configures, and links production-grade Group Policy Objects (GPOs):
    1. GPO-Sec-InteractiveLogon: Legal notice caption and text warning banner on logon.
    2. GPO-Sec-ScreenTimeout: Enforces 15-minute screen lock with password prompt.
    3. GPO-Sec-ScriptBlockLogging: Enables PowerShell Script Block Logging (Event ID 4104).
    4. GPO-Sec-DisableLLMNR: Disables Link-Local Multicast Name Resolution (mitigates Responder/PtH attacks).
    Links GPOs to the appropriate levels in the OU hierarchy.

.PARAMETER DomainDN
    Distinguished Name of the domain. Default: dynamic.

.EXAMPLE
    .\06_Deploy-GPOBaselines.ps1
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $false)]
    [string]$DomainDN
)

# Import GroupPolicy Module
if (-not (Get-Module -Name GroupPolicy -ListAvailable)) {
    Write-Error "The GroupPolicy PowerShell module is required. Please install GPMC feature."
    exit 1
}
Import-Module GroupPolicy
Import-Module ActiveDirectory

$domainObj = Get-ADDomain
if (-not $DomainDN) {
    $DomainDN = $domainObj.DistinguishedName
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " [AGL LAB] Enterprise Group Policy Baseline Deployment Engine    " -ForegroundColor Cyan
Write-Host " Target Domain: $DomainDN                                        " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# Helper Function: Create or Retrieve GPO
function Get-OrCreateGPO {
    param ([string]$Name, [string]$Comment)
    $gpo = Get-GPO -Name $Name -ErrorAction SilentlyContinue
    if (-not $gpo) {
        Write-Host " [+] Creating GPO: '$Name'..." -ForegroundColor Green
        $gpo = New-GPO -Name $Name -Comment $Comment -ErrorAction Stop
    } else {
        Write-Host " [=] GPO '$Name' already exists." -ForegroundColor DarkGray
    }
    return $gpo
}

# Helper Function: Link GPO to OU
function Link-GPOToOU {
    param ([string]$GPOName, [string]$TargetOUDN)
    try {
        $existingLink = Get-GPO -Name $GPOName | Get-GPOReport -ReportType Xml | Select-String -Pattern $TargetOUDN
        if (-not $existingLink) {
            Write-Host "      Linking '$GPOName' -> '$TargetOUDN'..." -ForegroundColor Gray
            New-GPLink -Name $GPOName -Target $TargetOUDN -LinkEnabled Yes -ErrorAction SilentlyContinue | Out-Null
        } else {
            Write-Host "      GPO '$GPOName' is already linked to '$TargetOUDN'." -ForegroundColor DarkGray
        }
    } catch {
        Write-Warning "Could not verify/create link for '$GPOName' to '$TargetOUDN': $_"
    }
}

# -------------------------------------------------------------------------
# 1. GPO-Sec-InteractiveLogon (Legal Warning Banner)
# -------------------------------------------------------------------------
Write-Host "`n[1/4] Configuring 'GPO-Sec-InteractiveLogon'..." -ForegroundColor Yellow
$gpoLogon = Get-OrCreateGPO -Name "GPO-Sec-InteractiveLogon" -Comment "Mandatory legal warning banner for corporate endpoints"

if ($PSCmdlet.ShouldProcess("GPO-Sec-InteractiveLogon", "Configure Registry Values")) {
    $regKeyLogon = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    Set-GPRegistryValue -Name "GPO-Sec-InteractiveLogon" -Key $regKeyLogon `
        -ValueName "legalnoticecaption" -Type String -Value "APEX GLOBAL LOGISTICS - AUTHORIZED ACCESS ONLY" | Out-Null
    Set-GPRegistryValue -Name "GPO-Sec-InteractiveLogon" -Key $regKeyLogon `
        -ValueName "legalnoticetext" -Type String -Value "This system is restricted to authorized Apex Global Logistics personnel. All activities are monitored and logged. Unauthorized use is prohibited and subject to legal prosecution." | Out-Null
}
Link-GPOToOU -GPOName "GPO-Sec-InteractiveLogon" -TargetOUDN "OU=ApexGlobal,$DomainDN"

# -------------------------------------------------------------------------
# 2. GPO-Sec-ScreenTimeout (15-Minute Inactive Lock)
# -------------------------------------------------------------------------
Write-Host "`n[2/4] Configuring 'GPO-Sec-ScreenTimeout'..." -ForegroundColor Yellow
$gpoScreen = Get-OrCreateGPO -Name "GPO-Sec-ScreenTimeout" -Comment "Enforces 15-minute screensaver inactivity lock with password prompt"

if ($PSCmdlet.ShouldProcess("GPO-Sec-ScreenTimeout", "Configure Registry Values")) {
    $regKeyScreen = "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop"
    Set-GPRegistryValue -Name "GPO-Sec-ScreenTimeout" -Key $regKeyScreen -ValueName "ScreenSaveActive" -Type String -Value "1" | Out-Null
    Set-GPRegistryValue -Name "GPO-Sec-ScreenTimeout" -Key $regKeyScreen -ValueName "ScreenSaverIsSecure" -Type String -Value "1" | Out-Null
    Set-GPRegistryValue -Name "GPO-Sec-ScreenTimeout" -Key $regKeyScreen -ValueName "ScreenSaveTimeOut" -Type String -Value "900" | Out-Null
}
Link-GPOToOU -GPOName "GPO-Sec-ScreenTimeout" -TargetOUDN "OU=Departments,OU=ApexGlobal,$DomainDN"

# -------------------------------------------------------------------------
# 3. GPO-Sec-ScriptBlockLogging (PowerShell Audit Trail - Event ID 4104)
# -------------------------------------------------------------------------
Write-Host "`n[3/4] Configuring 'GPO-Sec-ScriptBlockLogging'..." -ForegroundColor Yellow
$gpoLogging = Get-OrCreateGPO -Name "GPO-Sec-ScriptBlockLogging" -Comment "Enables PowerShell Script Block and Command Execution Logging for SIEM / SOC audit"

if ($PSCmdlet.ShouldProcess("GPO-Sec-ScriptBlockLogging", "Configure Registry Values")) {
    $regKeyLogging = "HKLM\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
    Set-GPRegistryValue -Name "GPO-Sec-ScriptBlockLogging" -Key $regKeyLogging -ValueName "EnableScriptBlockLogging" -Type DWord -Value 1 | Out-Null
}
Link-GPOToOU -GPOName "GPO-Sec-ScriptBlockLogging" -TargetOUDN "OU=Devices,OU=ApexGlobal,$DomainDN"

# -------------------------------------------------------------------------
# 4. GPO-Sec-DisableLLMNR (Mitigate Credential Sniffing / Responder)
# -------------------------------------------------------------------------
Write-Host "`n[4/4] Configuring 'GPO-Sec-DisableLLMNR'..." -ForegroundColor Yellow
$gpoLLMNR = Get-OrCreateGPO -Name "GPO-Sec-DisableLLMNR" -Comment "Disables LLMNR protocol on workstations to prevent poisoner credential theft"

if ($PSCmdlet.ShouldProcess("GPO-Sec-DisableLLMNR", "Configure Registry Values")) {
    $regKeyLLMNR = "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient"
    Set-GPRegistryValue -Name "GPO-Sec-DisableLLMNR" -Key $regKeyLLMNR -ValueName "EnableMulticast" -Type DWord -Value 0 | Out-Null
}
Link-GPOToOU -GPOName "GPO-Sec-DisableLLMNR" -TargetOUDN "OU=Workstations,OU=Devices,OU=ApexGlobal,$DomainDN"

Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host " [AGL LAB] Group Policy Baselines Successfully Deployed!        " -ForegroundColor Cyan
Write-Host " Execute 'gpupdate /force' on target endpoints to apply.        " -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
