# Incident Runbook: INC-1001 (P1 - Critical)

## Ticket Metadata
| Field | Value |
|:---|:---|
| **Incident ID** | **INC-1001** |
| **Priority** | **P1 - Critical (Outage)** |
| **Caller / Reporter** | David Zhao (IT Infrastructure Director) |
| **Category** | Identity & Access / Network Services |
| **Subcategory** | Active Directory DNS / Kerberos Authentication |
| **Configuration Item (CI)** | `AGL-DC01.corp.apexlogistics.local` |
| **Assignment Group** | `IT-SysAdmin-Tier3` |
| **Assigned To** | Elena Rostova (Senior Systems Administrator) |
| **State** | **Closed** |
| **Created** | 2026-09-21 08:14:02 EST |
| **Resolved** | 2026-09-21 09:22:18 EST |
| **SLA Target / Met** | 2 Hours / **MET (1h 8m elapsed)** |

---

## 1. Initial User Report & Symptoms
At 08:14 EST, the Service Desk received a surge of inbound calls from employees in Logistics and Sales reporting that their corporate laptops failed to log in, displaying the error:
> *"There are currently no logon servers available to service the logon request."*

Simultaneously, member server `AGL-FS01` reported authentication drops when clients attempted to mount departmental SMB file shares.

---

## 2. Investigation & Diagnostic Log

### Step 2.1: Verify Network Connectivity from Client Workstation
From `AGL-WS01`, executed basic network connectivity tests:
```powershell
# Check IP and assigned DNS server
Get-NetIPConfiguration

# Output:
# IPv4 Address     : 192.168.10.50
# Default Gateway  : 192.168.10.1
# DNS Servers      : 192.168.10.10

# Ping Domain Controller
Test-Connection -ComputerName 192.168.10.10 -Count 2
# Result: 0% loss, Average latency 1ms (Layer 3 connectivity is healthy).
```

### Step 2.2: Test Active Directory DNS SRV Records
Kerberos authentication and DC locator require DNS SRV records in `_msdcs.corp.apexlogistics.local`:
```cmd
nslookup -type=SRV _ldap._tcp.dc._msdcs.corp.apexlogistics.local 192.168.10.10
```
**Diagnostic Finding**: The command returned `*** AGL-DC01.corp.apexlogistics.local can't find _ldap._tcp.dc._msdcs.corp.apexlogistics.local: Non-existent domain`.
The DNS Server service on `AGL-DC01` had failed to register the primary Kerberos and LDAP locator records following an ungraceful host server reboot overnight.

### Step 2.3: Check DNS Server Service & Event Viewer Logs
On `AGL-DC01`:
```powershell
Get-Service -Name DNS, NTDS, Netlogon | Select-Object Name, Status, StartType
```
*Output*:
- `DNS`: Running
- `NTDS`: Running
- `Netlogon`: **Stopped** (StartupType: Automatic)

Event Viewer showed Event ID 5774 (`NETLOGON`):
> *"The dynamic registration of the DNS record '_ldap._tcp.dc._msdcs.corp.apexlogistics.local' failed on DNS server '192.168.10.10'."*

---

## 3. Root Cause Analysis (RCA)
During an automated virtualization host patching restart, the `Netlogon` service on `AGL-DC01` attempted to register its Kerberos SRV records before the `DNS` server service had completely initialized its Active Directory-integrated zone database. As a result, the dynamic registration timed out, and the Netlogon service crashed into a stopped state. Without active SRV records, domain client workstations could not discover the Domain Controller.

---

## 4. Remediation & Recovery Steps

```powershell
# 1. Start the Netlogon Service
Start-Service -Name Netlogon
Set-Service -Name Netlogon -StartupType Automatic

# 2. Force dynamic DNS registration of Active Directory SRV records
nltest /dsregdns
ipconfig /registerdns

# 3. Restart DNS Server service to flush and re-index zone cache
Restart-Service -Name DNS

# 4. Verify Active Directory Domain Controller Locator records
nltest /dclist:corp.apexlogistics.local
nltest /dsgetdc:corp.apexlogistics.local
```

### Verification from Workstation (`AGL-WS01`):
```powershell
# Query SRV record again
Resolve-DnsName -Name "_ldap._tcp.dc._msdcs.corp.apexlogistics.local" -Type SRV

# Output confirms AGL-DC01 returned with Port 389, Weight 100, Priority 0.

# Verify domain secure channel trust
Test-ComputerSecureChannel -Verbose
# Output: True
```

---

## 5. Preventative Action & Post-Incident Items
1. Configured service dependency in the Windows Registry to ensure `Netlogon` depends on the `DNS` service being fully available before starting (`HKLM\SYSTEM\CurrentControlSet\Services\Netlogon\DependOnService`).
2. Configured PRTG / Nagios monitoring alert for Netlogon service state and SRV record resolution checks every 60 seconds.
