# SOP-005: Shared Folder NTFS & Share Permissions Management

**Document ID**: SOP-005  
**Category**: Storage & File Services  
**Target Audience**: Tier 1 Help Desk, Tier 2 Desktop Support, SysAdmins  
**Required AD Group**: `SEC-ServiceDesk-Tier2` / Server Operators  
**Governing Policy**: INF-POL-03 (Data Access & File Server Security Policy)  

---

## 1. Permission Architecture (Share vs. NTFS)
When a user accesses files across the network, Windows evaluates two independent layers of security. The **most restrictive** permission wins:

```
[ Client Workstation ]
        │ (Network SMB Request)
        ▼
┌─────────────────────────────────┐
│ Share Permissions (Network Gate)│  --> Standard Practice: Set to "Everyone: Full Control" or
└───────────────┬─────────────────┘      "Authenticated Users: Change / Read"
                │ (Passed)
                ▼
┌─────────────────────────────────┐
│  NTFS Permissions (Disk Gate)   │  --> Enforce granular Least Privilege using AGDLP:
└───────────────┬─────────────────┘      Domain Local Security Groups (DL-Share-*)
                │ (Evaluated)
                ▼
      [ Actual File / Folder ]
```

---

## 2. Standard Enterprise Share Template

For any departmental share on `AGL-FS01` (e.g., `D:\Shares\Logistics`):

| Principal / Security Group | NTFS Permission | Inheritance | Justification |
|:---|:---|:---|:---|
| **`NT AUTHORITY\SYSTEM`** | Full Control | This folder, subfolders & files | OS and backup operations |
| **`BUILTIN\Administrators`** | Full Control | This folder, subfolders & files | Administrative maintenance |
| **`APEX\DL-Share-<Dept>-RW`** | Modify | This folder, subfolders & files | Standard departmental staff (create, edit, delete files) |
| **`APEX\DL-Share-<Dept>-RO`** | Read & Execute | This folder, subfolders & files | Departmental auditors / cross-functional viewers |

---

## 3. Provisioning a New Department Share

### PowerShell Procedure (Run on File Server `AGL-FS01`):
```powershell
$shareName = "Logistics"
$folderPath = "D:\Shares\$shareName"
$domainNetBIOS = "APEX"

# 1. Create directory if not present
if (-not (Test-Path -Path $folderPath)) {
    New-Item -ItemType Directory -Path $folderPath -Force | Out-Null
}

# 2. Break inheritance and configure explicit NTFS permissions
$acl = Get-Acl -Path $folderPath
$acl.SetAccessRuleProtection($true, $false) # Isolate from root C: drive inheritance

# Helper to create access rules
function New-Rule($trustee, $rights) {
    $sid = New-Object System.Security.Principal.NTAccount($trustee)
    return New-Object System.Security.AccessControl.FileSystemAccessRule(
        $sid, $rights, "ContainerInherit,ObjectInherit", "None", "Allow"
    )
}

$acl.AddAccessRule((New-Rule "NT AUTHORITY\SYSTEM" "FullControl"))
$acl.AddAccessRule((New-Rule "BUILTIN\Administrators" "FullControl"))
$acl.AddAccessRule((New-Rule "$domainNetBIOS\DL-Share-$shareName-RW" "Modify"))
$acl.AddAccessRule((New-Rule "$domainNetBIOS\DL-Share-$shareName-RO" "ReadAndExecute"))

Set-Acl -Path $folderPath -AclObject $acl

# 3. Create SMB Network Share with Authenticated Users Full Control
New-SmbShare -Name $shareName `
             -Path $folderPath `
             -FullAccess "Authenticated Users" `
             -Description "Corporate $shareName Department Share" `
             -ErrorAction SilentlyContinue
```

---

## 4. Granting User Access to an Existing Share
> [!IMPORTANT]
> **NEVER add individual user accounts directly to NTFS ACLs.** Always manage access through group membership!

When a user requests access to a file share:
1. Verify ticket approval from the data owner / department manager.
2. Determine required access level:
   - For Read/Write access: Add user to `GLB-<Department>-Staff`, which is nested inside `DL-Share-<Department>-RW`.
   - For Read-Only access: Add user to `DL-Share-<Department>-RO`.
3. Command:
   ```powershell
   Add-ADGroupMember -Identity "DL-Share-Logistics-RW" -Members "jwilson"
   ```
4. **Kerberos Token Refresh**: The user must log off and log back into Windows (or execute `klist purge`) for the new group membership SID to be added to their Kerberos ticket granting token (TGT).
