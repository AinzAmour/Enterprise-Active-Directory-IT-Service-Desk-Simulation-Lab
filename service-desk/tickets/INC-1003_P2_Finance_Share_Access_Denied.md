# Incident Runbook: INC-1003 (P2 - High)

## Ticket Metadata
| Field | Value |
|:---|:---|
| **Incident ID** | **INC-1003** |
| **Priority** | **P2 - High (Department Disruption)** |
| **Caller / Reporter** | Alexander Wright (Director of Finance) |
| **Category** | Storage & File Services |
| **Subcategory** | SMB File Share / NTFS Permissions |
| **Configuration Item (CI)** | `\\AGL-FS01\Finance` |
| **Assignment Group** | `IT-DesktopSupport-Tier2` |
| **Assigned To** | Carlos Mendez (Tier 2 Desktop Support Specialist) |
| **State** | **Closed** |
| **Created** | 2026-09-22 13:10:00 EST |
| **Resolved** | 2026-09-22 14:05:22 EST |
| **SLA Target / Met** | 4 Hours / **MET (55 minutes elapsed)** |

---

## 1. Initial User Report
At 13:10 EST, multiple Finance department members (Senior Accountants, Billing Specialists) submitted tickets reporting that their mapped `S:\` department drive showed a red 'X', and clicking the folder produced:
> *"Windows cannot access \\AGL-FS01\Finance. You do not have permission to access \\AGL-FS01\Finance. Contact your network administrator to request access."*

---

## 2. Investigation & Diagnostic Log

### Step 2.1: Verify SMB Share Availability
Tested network path from administrative console:
```powershell
Test-NetConnection -ComputerName "AGL-FS01" -Port 445
# Result: TcpTestSucceeded : True (SMB port is reachable)

Get-SmbShare -CimSession "AGL-FS01" -Name "Finance"
# Share exists: Path: D:\Shares\Finance, ShareState: Online
```

### Step 2.2: Audit Share Permissions vs. NTFS Permissions
```powershell
# Check Share Permissions (Network layer)
Get-SmbShareAccess -CimSession "AGL-FS01" -Name "Finance"
# Output:
# AccountName: "Everyone", AccessRight: Full, AccessControlType: Allow (Share permissions are wide open).

# Check NTFS Access Control List (Disk layer)
Invoke-Command -ComputerName "AGL-FS01" -ScriptBlock {
    Get-Acl -Path "D:\Shares\Finance" | Format-List AccessToString
}
```
**Diagnostic Finding**: The NTFS ACL only contained:
- `NT AUTHORITY\SYSTEM`: FullControl
- `BUILTIN\Administrators`: FullControl

The resource access group `APEX\DL-Share-Finance-RW` was completely missing from the ACL.
*Inquiry with Backup Operator*: A folder restore had been performed at 12:45 EST using a backup utility that restored files without preserving original security descriptors (NTFS flags).

---

## 3. Remediation & Recovery

Restored the standard AGDLP permission model on `AGL-FS01`:

```powershell
Invoke-Command -ComputerName "AGL-FS01" -ScriptBlock {
    $sharePath = "D:\Shares\Finance"
    $acl = Get-Acl -Path $sharePath

    # Define Domain Local security groups
    $financeRwSid = New-Object System.Security.Principal.NTAccount("APEX\DL-Share-Finance-RW")
    $financeRoSid = New-Object System.Security.Principal.NTAccount("APEX\DL-Share-Finance-RO")

    # Rule 1: Finance Staff Read/Write (Modify)
    $rwRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $financeRwSid, "Modify", "ContainerInherit,ObjectInherit", "None", "Allow"
    )

    # Rule 2: Finance Read-Only Auditors
    $roRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $financeRoSid, "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow"
    )

    $acl.AddAccessRule($rwRule)
    $acl.AddAccessRule($roRule)

    # Apply ACL recursively
    Set-Acl -Path $sharePath -AclObject $acl
}
```

Alternatively using native `icacls`:
```cmd
icacls "D:\Shares\Finance" /grant "APEX\DL-Share-Finance-RW":(OI)(CI)M /T /C
```

---

## 4. Verification & Resolution
1. Contacted Director of Finance Alexander Wright to test access from workstation `AGL-WS01`.
2. User opened `\\AGL-FS01\Finance`, successfully opened the `2026_Q3_Budget.xlsx` file, saved a test change, and confirmed complete resolution.
3. Updated Backup Software SOP to mandate the `--preserve-acls` parameter during any future restore operations.
