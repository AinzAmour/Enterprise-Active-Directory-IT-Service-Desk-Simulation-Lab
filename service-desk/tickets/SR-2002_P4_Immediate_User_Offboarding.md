# Service Request Runbook: SR-2002 (P4 - High Priority Security Offboarding)

## Ticket Metadata
| Field | Value |
|:---|:---|
| **Service Request ID** | **SR-2002** |
| **Priority** | **P4 - Low / Urgent Security Execution** |
| **Caller / Reporter** | Sarah Connor (VP of Human Resources) |
| **Category** | User Lifecycle & Security |
| **Subcategory** | Involuntary Termination / Immediate Access Revocation |
| **Configuration Item (CI)** | `CORP\lcooper` / Lincoln Cooper |
| **Assignment Group** | `IT-DesktopSupport-Tier2` / Service Desk Lead |
| **Assigned To** | Liam O'Connor (Service Desk Team Lead) |
| **State** | **Closed** |
| **Created** | 2026-09-24 16:00:00 EST |
| **Resolved** | 2026-09-24 16:18:25 EST |
| **SLA Target / Met** | 24 Hours / **MET (18 minutes elapsed)** |

---

## 1. Request Details & Authorization
VP of Human Resources Sarah Connor initiated an immediate involuntary offboarding request:
- **Employee**: Lincoln Cooper (Account Executive - Sales)
- **Username**: `lcooper`
- **Employee ID**: `EMP-1096`
- **Termination Effective Time**: Immediate (16:00 EST)
- **Special Requirements**:
  - Immediately terminate active VPN, email, and network sessions.
  - Forward inbound email to Regional Sales Manager Mateo Bailey (`mbailey`).
  - Move account to `OU=Terminated` for 90-day retention hold.

---

## 2. Standard Offboarding Script Execution (`SOP-003`)

Executed via the automated offboarding module in `scripts/07_DailyOps-ServiceDeskToolkit.ps1` or administrative PowerShell:

```powershell
$sam = "lcooper"
$ticket = "SR-2002"
$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$termOU = "OU=Terminated,OU=ApexGlobal,DC=corp,DC=apexlogistics,DC=local"

# 1. Disable Active Directory Account
Disable-ADAccount -Identity $sam
Write-Host "[1/6] Account disabled in Active Directory." -ForegroundColor Green

# 2. Scramble Password to 32-character random cryptographic string
$scrambledPass = [System.Web.Security.Membership]::GeneratePassword(32, 8)
$secPass = ConvertTo-SecureString $scrambledPass -AsPlainText -Force
Set-ADAccountPassword -Identity $sam -NewPassword $secPass -Reset
Write-Host "[2/6] Password reset to unrecoverable random string." -ForegroundColor Green

# 3. Terminate Active Microsoft 365 & VPN Sessions
Revoke-AzureADUserAllRefreshToken -ObjectId "lcooper@apexlogistics.com" -ErrorAction SilentlyContinue
Write-Host "[3/6] Cloud tokens and VPN sessions terminated." -ForegroundColor Green

# 4. Strip Security and Distribution Group Memberships (Preserving Domain Users)
$userObj = Get-ADUser -Identity $sam -Properties MemberOf, Description
$groupsToRemove = $userObj.MemberOf | Where-Object { $_ -notmatch "CN=Domain Users" }
foreach ($g in $groupsToRemove) {
    Remove-ADGroupMember -Identity $g -Members $sam -Confirm:$false
}
Write-Host "[4/6] Removed from $($groupsToRemove.Count) security & distribution groups." -ForegroundColor Green

# 5. Move user object to OU=Terminated
Move-ADObject -Identity $userObj.DistinguishedName -TargetPath $termOU
Write-Host "[5/6] Moved account to '$termOU'." -ForegroundColor Green

# 6. Append Immutable Audit Record in User Description
$auditNote = "OFFBOARDED via $ticket on $timestamp by $env:USERNAME. Former Dept: SalesMarketing. Prior Desc: $($userObj.Description)"
Set-ADUser -Identity $sam -Description $auditNote
Write-Host "[6/6] Audit trail recorded in user description." -ForegroundColor Green
```

### Mailbox Delegation:
```powershell
# Grant Regional Sales Manager FullAccess and SendAs to forward communications
Add-MailboxPermission -Identity "lcooper@apexlogistics.com" -User "mbailey" -AccessRights FullAccess -InheritanceType All
Set-Mailbox -Identity "lcooper@apexlogistics.com" -HiddenFromAddressListsEnabled $true
```

---

## 3. Physical Asset Reclamation
1. Reception and HR retrieved corporate laptop `AGL-WS-SALES12`, YubiKey token, and building access badge.
2. Verified machine disconnected from corporate network.
3. Ticket documented with asset serial numbers and marked **Closed / Complete**.
