# Incident Runbook: INC-1005 (P3 - Medium)

## Ticket Metadata
| Field | Value |
|:---|:---|
| **Incident ID** | **INC-1005** |
| **Priority** | **P3 - Medium** |
| **Caller / Reporter** | Noah Kim (Tier 1 Help Desk Analyst) |
| **Category** | Workstation & Endpoint Management |
| **Subcategory** | Group Policy Application / SYSVOL |
| **Configuration Item (CI)** | `AGL-WS01` / `GPO-Sec-InteractiveLogon` |
| **Assignment Group** | `IT-DesktopSupport-Tier2` |
| **Assigned To** | Carlos Mendez (Tier 2 Desktop Support Specialist) |
| **State** | **Closed** |
| **Created** | 2026-09-23 14:20:00 EST |
| **Resolved** | 2026-09-23 15:15:45 EST |
| **SLA Target / Met** | 8 Hours / **MET (55 minutes elapsed)** |

---

## 1. Initial User Report
Technician Noah Kim observed while staging new corporate laptop `AGL-WS01` that after joining the machine to `corp.apexlogistics.local`, the legal notice warning banner failed to appear upon reboot, and the 15-minute screen timeout policy was not enforcing.

---

## 2. Investigation & Diagnostic Log

### Step 2.1: Run Group Policy Result Diagnostic (`gpresult`)
Executed on the client workstation `AGL-WS01`:
```cmd
gpresult /r /scope:computer
```
**Diagnostic Findings**:
```
The following GPOs were not applied because they were filtered out
-------------------------------------------------------------------
    GPO-Sec-InteractiveLogon
        Filtering:  Denied (Security)
```
The computer account could not read the GPO from the Domain Controller's SYSVOL share!

### Step 2.2: Analyze GPO Security Filtering Permissions
Under Microsoft Security Bulletin MS16-072, Group Policy processing runs under the **Computer Account** context (not the user context). Therefore, every GPO requires `Domain Computers` or `Authenticated Users` to have **Read** permissions on the GPO security filter.

Inspected GPO permissions on `AGL-DC01`:
```powershell
Get-GPPermissions -Name "GPO-Sec-InteractiveLogon" -All | Select-Object Trustee, Permission
```
*Output*:
- `APEX\Domain Admins`: GpoEditDeleteModifySecurity
- `APEX\SEC-Tier2-WorkstationAdmins`: GpoApply
- **`Authenticated Users`**: **MISSING** (Had been accidentally removed when targeting specific admins).

Because `Authenticated Users` was removed and `Domain Computers` was not added, the workstation `AGL-WS01$` had zero rights to read the GPO files in `\\corp.apexlogistics.local\sysvol\corp.apexlogistics.local\Policies\{GUID}`.

---

## 3. Remediation & Recovery

```powershell
# Restore 'Authenticated Users' Read permission to the GPO
Set-GPPermissions -Name "GPO-Sec-InteractiveLogon" `
                  -TargetName "Authenticated Users" `
                  -TargetType Group `
                  -PermissionLevel GpoRead

# Ensure 'Domain Computers' also possesses Read permissions explicitly
Set-GPPermissions -Name "GPO-Sec-InteractiveLogon" `
                  -TargetName "Domain Computers" `
                  -TargetType Group `
                  -PermissionLevel GpoApply

Write-Host "[+] GPO security filtering permissions restored." -ForegroundColor Green
```

### Refresh Policy on Client Workstation (`AGL-WS01`):
```cmd
gpupdate /force
```
*Output*:
```
Updating policy...
Computer Policy update has completed successfully.
User Policy update has completed successfully.
```

---

## 4. Verification & Validation
1. Inspected Windows Application Event Log on `AGL-WS01`:
   - **Event ID 1502 (`GroupPolicy`)**: *"The Group Policy settings for the computer were processed successfully. There were no changes detected since the last successful policy processing."*
2. Re-ran `gpresult /r /scope:computer`:
   - `GPO-Sec-InteractiveLogon` now displayed under: **"Applied Group Policy Objects"**.
3. Rebooted `AGL-WS01`: The corporate legal notice *"APEX GLOBAL LOGISTICS - AUTHORIZED ACCESS ONLY"* displayed successfully prior to the credential prompt.
