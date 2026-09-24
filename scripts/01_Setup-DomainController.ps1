<#
.SYNOPSIS
    Deploys and configures a Windows Server 2022 Primary Domain Controller for Apex Global Logistics.

.DESCRIPTION
    This script automates the installation and configuration of the Root Domain Controller:
    1. Validates local administrative elevation.
    2. Configures static IPv4 addressing and DNS loopback.
    3. Sets the computer hostname to AGL-DC01.
    4. Installs Active Directory Domain Services (AD DS), DNS, and RSAT administration tools.
    5. Promotes the server to the root Domain Controller for corp.apexlogistics.local.

.PARAMETER DomainName
    The Fully Qualified Domain Name (FQDN) for the forest root. Default: corp.apexlogistics.local

.PARAMETER NetBIOSName
    The NetBIOS domain name. Default: APEX

.PARAMETER IPAddress
    The static IPv4 address for the Domain Controller. Default: 192.168.10.10

.PARAMETER SubnetPrefix
    The CIDR prefix length for the subnet mask. Default: 24 (255.255.255.0)

.PARAMETER Gateway
    The default gateway IPv4 address. Default: 192.168.10.1

.PARAMETER DSRMPassword
    SecureString password for Directory Services Restore Mode (DSRM).

.EXAMPLE
    .\01_Setup-DomainController.ps1 -DomainName "corp.apexlogistics.local" -NetBIOSName "APEX"
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $false)]
    [string]$DomainName = "corp.apexlogistics.local",

    [Parameter(Mandatory = $false)]
    [string]$NetBIOSName = "APEX",

    [Parameter(Mandatory = $false)]
    [string]$ServerHostName = "AGL-DC01",

    [Parameter(Mandatory = $false)]
    [string]$IPAddress = "192.168.10.10",

    [Parameter(Mandatory = $false)]
    [int]$SubnetPrefix = 24,

    [Parameter(Mandatory = $false)]
    [string]$Gateway = "192.168.10.1",

    [Parameter(Mandatory = $false)]
    [System.Security.SecureString]$DSRMPassword
)

# Enforce Administrator privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script requires elevated Administrator privileges. Please re-run from an elevated PowerShell console."
    exit 1
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " [AGL LAB] Initializing Primary Domain Controller Provisioning  " -ForegroundColor Cyan
Write-Host " Target Domain: $DomainName ($NetBIOSName)                       " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# Configure DSRM Password if not supplied
if ($null -eq $DSRMPassword) {
    Write-Warning "No DSRM password provided. Using default lab recovery credential (P@ssw0rd2026!)."
    $DSRMPassword = ConvertTo-SecureString "P@ssw0rd2026!" -AsPlainText -Force
}

# 1. Hostname Verification & Rename
$currentHost = $env:COMPUTERNAME
if ($currentHost -ne $ServerHostName) {
    Write-Host "[1/5] Renaming server from '$currentHost' to '$ServerHostName'..." -ForegroundColor Yellow
    if ($PSCmdlet.ShouldProcess($currentHost, "Rename-Computer to $ServerHostName")) {
        Rename-Computer -NewName $ServerHostName -Force
        Write-Warning "Computer renamed. A system reboot will be executed during forest promotion."
    }
} else {
    Write-Host "[1/5] Hostname is already configured as '$ServerHostName'." -ForegroundColor Green
}

# 2. Static Network Configuration
Write-Host "[2/5] Configuring static IPv4 network adapter settings..." -ForegroundColor Yellow
$activeAdapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -or $_.Status -eq 'Disconnected' } | Select-Object -First 1

if ($activeAdapter) {
    if ($PSCmdlet.ShouldProcess($activeAdapter.Name, "Configure Static IP $IPAddress/$SubnetPrefix")) {
        try {
            # Remove any pre-existing IP addresses on the interface
            Get-NetIPAddress -InterfaceIndex $activeAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                Where-Object { $_.IPAddress -ne $IPAddress } |
                Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

            # Assign static IP and gateway
            $existing = Get-NetIPAddress -InterfaceIndex $activeAdapter.ifIndex -IPAddress $IPAddress -ErrorAction SilentlyContinue
            if (-not $existing) {
                New-NetIPAddress -InterfaceIndex $activeAdapter.ifIndex -IPAddress $IPAddress -PrefixLength $SubnetPrefix -DefaultGateway $Gateway -ErrorAction Stop | Out-Null
            }

            # Configure DNS to loopback for Domain Controller
            Set-DnsClientServerAddress -InterfaceIndex $activeAdapter.ifIndex -ServerAddresses ("127.0.0.1", "192.168.10.10") -ErrorAction Stop
            Write-Host "      Static IP $IPAddress/$SubnetPrefix applied to adapter '$($activeAdapter.Name)'." -ForegroundColor Green
        } catch {
            Write-Warning "Network adapter configuration warning: $_"
        }
    }
} else {
    Write-Warning "No active network adapter detected. Skipping network configuration."
}

# 3. Install Active Directory Domain Services Role and Tools
Write-Host "[3/5] Installing Windows Features: AD-Domain-Services, DNS, RSAT Tools..." -ForegroundColor Yellow
$features = @("AD-Domain-Services", "DNS", "RSAT-AD-Tools", "RSAT-AD-PowerShell", "GPMC")

foreach ($feature in $features) {
    $status = Get-WindowsFeature -Name $feature -ErrorAction SilentlyContinue
    if ($status -and -not $status.Installed) {
        Write-Host "      Installing feature: $feature..." -ForegroundColor Gray
        if ($PSCmdlet.ShouldProcess($feature, "Install-WindowsFeature")) {
            Install-WindowsFeature -Name $feature -IncludeManagementTools -ErrorAction Stop | Out-Null
        }
    } else {
        Write-Host "      Feature '$feature' is already installed." -ForegroundColor Green
    }
}

# 4. Check if Server is already a Domain Controller
$isDC = (Get-CimInstance -ClassName Win32_OperatingSystem).ProductType -eq 2
if ($isDC) {
    Write-Host "[4/5] Server is already promoted to a Domain Controller. Skipping promotion." -ForegroundColor Green
} else {
    # 5. Forest Promotion
    Write-Host "[4/5] Promoting server to Root Forest Domain Controller ($DomainName)..." -ForegroundColor Yellow
    if ($PSCmdlet.ShouldProcess($DomainName, "Install-ADDSForest")) {
        $addsParams = @{
            DomainName                     = $DomainName
            DomainNetbiosName              = $NetBIOSName
            DomainMode                     = "WinThreshold" # Windows Server 2016/2022 functional level
            ForestMode                     = "WinThreshold"
            InstallDns                     = $true
            CreateDnsDelegation            = $false
            DatabasePath                   = "C:\Windows\NTDS"
            LogPath                        = "C:\Windows\NTDS"
            SysvolPath                     = "C:\Windows\SYSVOL"
            SafeModeAdministratorPassword = $DSRMPassword
            Force                          = $true
            NoRebootOnCompletion           = $false
        }

        Write-Host "      Executing Install-ADDSForest. The system will restart automatically upon completion..." -ForegroundColor Cyan
        Install-ADDSForest @addsParams
    }
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " [AGL LAB] Domain Controller Setup Complete!                    " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan
