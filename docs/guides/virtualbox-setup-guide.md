# VirtualBox & VMware Workstation Lab Setup Guide

This guide covers building the **Apex Global Logistics (AGL)** Enterprise Active Directory lab using **Oracle VirtualBox** or **VMware Workstation Pro / Player** (cross-platform compatible across Windows, macOS Intel, and Linux hosts).

---

## 1. Prerequisites & Downloads
- **Hypervisor**:
  - [Oracle VM VirtualBox 7.x](https://www.virtualbox.org/) + Extension Pack
  - OR [VMware Workstation Pro / Player](https://www.vmware.com/products/workstation-pro.html) (Free for personal use)
- **Evaluation ISOs**:
  - [Windows Server 2022 Evaluation ISO](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2022)
  - [Windows 10/11 Enterprise Evaluation ISO](https://www.microsoft.com/en-us/evalcenter/evaluate-windows-11-enterprise)
- **Host Specs**: 16 GB+ RAM, 80 GB SSD free space.

---

## 2. Network Configuration

### Option A: VirtualBox Internal Network
To ensure isolated, conflict-free domain traffic between your Domain Controller and Workstations:
1. Open VirtualBox $\rightarrow$ **Tools** $\rightarrow$ **Network Manager** $\rightarrow$ **NAT Networks**.
2. Click **Create** to add a new NAT Network:
   - **Network Name**: `AGL-NatNetwork`
   - **IPv4 Prefix**: `192.168.10.0/24`
   - **Enable DHCP**: **UNCHECK** (Important: `AGL-DC01` will serve DHCP, or we will use static IPs to prevent conflict).
   - **Supports IPv6**: Uncheck.
3. Both VMs (`AGL-DC01` and `AGL-WS01`) will attach their Adapter 1 to this `AGL-NatNetwork`.

### Option B: VMware Workstation Custom Virtual Network
1. Open VMware Workstation $\rightarrow$ **Edit** $\rightarrow$ **Virtual Network Editor**.
2. Select or Add **VMnet2**:
   - Set type to **NAT**.
   - **Subnet IP**: `192.168.10.0`
   - **Subnet Mask**: `255.255.255.0`
   - **NAT Settings**: Gateway IP `192.168.10.1`.
   - **Use local DHCP service**: **UNCHECK**.
3. Set the network adapter on both VMs to **Custom: Specific virtual network (VMnet2)**.

---

## 3. Creating the Domain Controller (`AGL-DC01`)

1. **New VM Creation**:
   - Name: `AGL-DC01`
   - Type: `Microsoft Windows`
   - Version: `Windows 2022 (64-bit)`
   - Memory: **4096 MB** (4 GB)
   - Processors: **2 vCPUs**
   - Disk: **50 GB VDI / VMDK** (Dynamically allocated)
2. **Mount ISO & Boot**:
   - Mount the Windows Server 2022 ISO in Storage.
   - Start the VM and choose **Windows Server 2022 Datacenter (Desktop Experience)**.
   - Complete installation and set Administrator password.
3. **Guest Additions / VMware Tools**:
   - Install Guest Additions / VMware Tools for smooth mouse integration, screen auto-resizing, and clipboard sharing.

---

## 4. Creating the Client Workstation (`AGL-WS01`)

1. **New VM Creation**:
   - Name: `AGL-WS01`
   - Version: `Windows 10 / 11 (64-bit)`
   - Memory: **4096 MB** (4 GB)
   - Processors: **2 vCPUs**
   - Disk: **40 GB**
   - Network: Connected to `AGL-NatNetwork` or `VMnet2`.
2. **Operating System Setup**:
   - Install Windows 10/11 Enterprise or Pro.
   - Configure a local temporary admin account (e.g., `LocalAdmin`).

---

## 5. Joining the Workstation to the Domain

Once `AGL-DC01` has been promoted using `scripts/01_Setup-DomainController.ps1`:
1. On `AGL-WS01`, open PowerShell as Administrator and configure static DNS pointing to the DC:
   ```powershell
   # Identify adapter name
   $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
   
   # Set static IP and primary DNS to AGL-DC01
   New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress 192.168.10.50 -PrefixLength 24 -DefaultGateway 192.168.10.1
   Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses 192.168.10.10
   
   # Verify connectivity to Domain Controller
   Test-NetConnection -ComputerName 192.168.10.10 -Port 53
   Test-NetConnection -ComputerName "corp.apexlogistics.local" -Port 389
   
   # Join to corporate domain
   Add-Computer -DomainName "corp.apexlogistics.local" -Restart
   ```
2. Enter the Domain Administrator credentials when prompted (`APEX\Administrator`).
3. The workstation will reboot and show the corporate logon banner.
