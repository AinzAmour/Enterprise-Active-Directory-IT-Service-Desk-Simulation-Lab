# SOP-003: Employee Offboarding & Security Access Revocation

**Document ID**: SOP-003  
**Category**: Identity & Security Operations  
**Target Audience**: Tier 1 Help Desk, Tier 2 Desktop Support, SecOps  
**Required AD Group**: `SEC-ServiceDesk-Tier1` / `SEC-ServiceDesk-Tier2`  
**Governing Policy**: SEC-POL-08 (Employee Separation & Asset Recovery Policy)  

---

## 1. Overview & Classification

| Offboarding Type | Execution Trigger | SLA Target | Key Protocol |
|:---|:---|:---:|:---|
| **Involuntary / Immediate** | HR or Legal notice of immediate separation | **< 15 Minutes** | Immediate session termination, password scramble, account disablement, security escort. |
| **Voluntary / Standard** | Scheduled resignation notice | **End of Business (17:00 EST)** | Coordinate final day handoff, backup personal files, delegate mailbox. |

---

## 2. Technical Offboarding Procedure

### Step 1: Immediate Session & Credential Termination
```powershell
$sam = "target_username"
$ticketId = "SR-2002"
$timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

# 1. Disable Active Directory account
Disable-ADAccount -Identity $sam

# 2. Reset password to 32-character high-entropy cryptographic string
$scrambled = [System.Web.Security.Membership]::GeneratePassword(32, 8)
Set-ADAccountPassword -Identity $sam -NewPassword (ConvertTo-SecureString $scrambled -AsPlainText -Force) -Reset

# 3. Kill active Microsoft 365 cloud sessions and revoke refresh tokens
Revoke-AzureADUserAllRefreshToken -ObjectId "$sam@apexlogistics.com" -ErrorAction SilentlyContinue

Write-Host "[+] Step 1 Complete: Account disabled and sessions killed." -ForegroundColor Green
```

### Step 2: Strip Security & Distribution Group Entitlements
To prevent unauthorized access inheritance if the account is ever temporarily re-enabled for audit:
```powershell
$user = Get-ADUser -Identity $sam -Properties MemberOf, Description
$groupsToRemove = $user.MemberOf | Where-Object { $_ -notmatch "CN=Domain Users" }

foreach ($grp in $groupsToRemove) {
    Remove-ADGroupMember -Identity $grp -Members $sam -Confirm:$false
}

Write-Host "[+] Step 2 Complete: Removed from $($groupsToRemove.Count) groups." -ForegroundColor Green
```

### Step 3: Move Account to Terminated Quarantine OU
```powershell
$domainDN = (Get-ADDomain).DistinguishedName
$termOU = "OU=Terminated,OU=ApexGlobal,$domainDN"

Move-ADObject -Identity $user.DistinguishedName -TargetPath $termOU
Write-Host "[+] Step 3 Complete: Account moved to '$termOU'." -ForegroundColor Green
```

### Step 4: Record Immutable Audit Log in Description
```powershell
$auditEntry = "OFFBOARDED via $ticketId on $timestamp by $env:USERNAME. Prior Title: $($user.Title). Prior Desc: $($user.Description)"
Set-ADUser -Identity $sam -Description $auditEntry
Write-Host "[+] Step 4 Complete: Audit entry written." -ForegroundColor Green
```

### Step 5: Mailbox Delegation & Hide from Global Address List (GAL)
```powershell
# Hide from Outlook Address Book
Set-Mailbox -Identity "$sam@apexlogistics.com" -HiddenFromAddressListsEnabled $true

# Grant Manager Read/Access rights if approved by HR
$manager = (Get-ADUser -Identity $sam -Properties Manager).Manager
if ($manager) {
    Add-MailboxPermission -Identity "$sam@apexlogistics.com" -User $manager -AccessRights FullAccess -InheritanceType All
}
```

---

## 3. Hardware Asset Reclamation
1. Retrieve corporate laptop, charger, security tokens (YubiKey), and building access fobs.
2. Store asset in secure IT storage locker; log serial numbers into asset inventory.
3. Keep user home directory intact for 90 days per legal retention policy before archiving to cold storage.
