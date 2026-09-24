# Hyper-V Lab Setup Guide

This guide details how to build and configure the **Apex Global Logistics (AGL)** Enterprise Active Directory lab on a Windows host machine running **Microsoft Hyper-V** (available in Windows 10/11 Pro, Enterprise, and Education).

---

## 1. Prerequisites
- **Host OS**: Windows 10/11 Pro, Enterprise, or Windows Server
- **Hardware Resources**:
  - CPU: 4+ physical cores (Intel VT-x / AMD-V enabled in BIOS/UEFI)
  - RAM: 16 GB minimum (32 GB recommended)
  - Free Storage: 80 GB SSD space
- **ISO Images**:
  - [Windows Server 2022 Evaluation ISO](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2022)
  - [Windows 10/11 Enterprise Evaluation ISO](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-11-enterprise)

---

## 2. Enable Hyper-V Feature
Open an elevated PowerShell prompt (Run as Administrator) on your host and execute:
```powershell
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -All -NoRestart
```
*Restart your computer if prompted.*

---

## 3. Configure the Virtual Network (NAT Switch)
To ensure the lab VMs can communicate with each other over `192.168.10.0/24` while also accessing the internet for updates through the host:

```powershell
# 1. Create Internal Virtual Switch
New-VMSwitch -Name "AGL-Lab-Switch" -SwitchType Internal

# 2. Identify the Interface Index of the new switch adapter on the host
$ifIndex = (Get-NetAdapter -Name "vEthernet (AGL-Lab-Switch)").ifIndex

# 3. Assign the Gateway IP to the host virtual adapter
New-NetIPAddress -IPAddress 192.168.10.1 -PrefixLength 24 -InterfaceIndex $ifIndex

# 4. Configure NAT network so VMs have internet access through the host
New-NetNat -Name "AGL-NAT-Network" -InternalIPInterfaceAddressPrefix "192.168.10.0/24"
```

---

## 4. Virtual Machine Specifications

| VM Name | Generation | vCPU | RAM (Startup / Dynamic) | Virtual Disk (VHDX) | Network Switch | Assigned IP |
|:---|:---|:---|:---|:---|:---|:---|
| **`AGL-DC01`** | Gen 2 | 2 vCPUs | 4096 MB (Dynamic Min 2048 MB) | 50 GB | `AGL-Lab-Switch` | `192.168.10.10` |
| **`AGL-WS01`** | Gen 2 | 2 vCPUs | 4096 MB (Dynamic Min 2048 MB) | 40 GB | `AGL-Lab-Switch` | `192.168.10.50` |
| **`AGL-FS01`** (Optional) | Gen 2 | 2 vCPUs | 2048 MB | 40 GB | `AGL-Lab-Switch` | `192.168.10.20` |

---

## 5. Automated VM Provisioning with PowerShell
Run the following script on your host to rapidly scaffold the lab VMs:

```powershell
# Define storage path for VMs
$LabPath = "C:\HyperV-Labs\AGL-Enterprise"
New-Item -ItemType Directory -Path "$LabPath\Virtual Hard Disks" -Force | Out-Null

# Create Domain Controller VM
New-VM -Name "AGL-DC01" -Generation 2 -MemoryStartupBytes 4GB -SwitchName "AGL-Lab-Switch" `
    -Path $LabPath -NewVHDPath "$LabPath\Virtual Hard Disks\AGL-DC01.vhdx" -NewVHDSizeBytes 50GB
Set-VMMemory -VMName "AGL-DC01" -DynamicMemoryEnabled $true -MinimumBytes 2GB -MaximumBytes 6GB
Set-VMProcessor -VMName "AGL-DC01" -Count 2

# Create Workstation VM
New-VM -Name "AGL-WS01" -Generation 2 -MemoryStartupBytes 4GB -SwitchName "AGL-Lab-Switch" `
    -Path $LabPath -NewVHDPath "$LabPath\Virtual Hard Disks\AGL-WS01.vhdx" -NewVHDSizeBytes 40GB
Set-VMMemory -VMName "AGL-WS01" -DynamicMemoryEnabled $true -MinimumBytes 2GB -MaximumBytes 4GB
Set-VMProcessor -VMName "AGL-WS01" -Count 2

# Attach Windows Server 2022 ISO to AGL-DC01 (Update path to your downloaded ISO)
$ServerISO = "C:\ISOs\WindowsServer2022.iso"
Add-VMDvdDrive -VMName "AGL-DC01" -Path $ServerISO
$dvd = Get-VMDvdDrive -VMName "AGL-DC01"
Set-VMFirmware -VMName "AGL-DC01" -FirstBootDevice $dvd

Write-Host "Lab VMs provisioned successfully! Boot AGL-DC01 to install Windows Server 2022." -ForegroundColor Green
```

---

## 6. Post-Installation Steps
1. Boot `AGL-DC01`, complete the Windows Server 2022 setup (choose **Desktop Experience**).
2. Set the local Administrator password.
3. Open PowerShell on `AGL-DC01` and execute the automation suite in order:
   - `scripts/01_Setup-DomainController.ps1`
   - `scripts/02_Build-OUStructure.ps1`
   - `scripts/03_Create-SecurityGroups.ps1`
   - `scripts/04_BulkProvision-Users.ps1`
   - `scripts/05_Delegate-ServiceDeskPermissions.ps1`
   - `scripts/06_Deploy-GPOBaselines.ps1`
4. Boot `AGL-WS01`, set static DNS to `192.168.10.10`, join to `corp.apexlogistics.local`, and log in with one of the provisioned test users.
