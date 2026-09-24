# SOP-002: Employee Onboarding & Account Provisioning

**Document ID**: SOP-002  
**Category**: User Lifecycle Management  
**Target Audience**: Tier 1 Help Desk, Tier 2 Desktop Support  
**Required AD Group**: `SEC-ServiceDesk-Tier1`  
**Governing Policy**: IAM-POL-01 (Corporate Account Lifecycle Policy)  

---

## 1. Purpose & Standards
Defines the technical workflow for provisioning new user accounts in Active Directory Domain Services, populating corporate group memberships, allocating storage directories, and staging client endpoints.

### Account Naming Conventions:
- **sAMAccountName**: First initial + full last name in lowercase (e.g., John Smith $\rightarrow$ `jsmith`). If collision exists, append middle initial (e.g., `jdsmith`).
- **UserPrincipalName**: `sAMAccountName@corp.apexlogistics.local`
- **Primary Email**: `sAMAccountName@apexlogistics.com`

---

## 2. Pre-Requisites & Ticket Validation
Before creating an account:
1. Ensure a valid ServiceNow / Jira onboarding ticket exists (e.g., `SR-2001`).
2. Verify Human Resources approval and department manager sign-off.
3. Confirm start date, job title, and requested software/entitlements.

---

## 3. Active Directory Provisioning Procedure

```powershell
param (
    [string]$FirstName,
    [string]$LastName,
    [string]$Department,
    [string]$Title,
    [string]$EmployeeID,
    [string]$OfficePhone,
    [string]$ManagerSAM
)

# 1. Generate SAMAccountName and UPN
$sam = ("$($FirstName.Substring(0,1))$LastName").ToLower()
$domainDN = (Get-ADDomain).DistinguishedName
$targetOU = "OU=$Department,OU=Departments,OU=ApexGlobal,$domainDN"

# 2. Secure Temporary Password
$tempPass = "ApexWelcome$((Get-Random -Minimum 1000 -Maximum 9999))!"
$secPass = ConvertTo-SecureString $tempPass -AsPlainText -Force

# 3. Create User Object
New-ADUser -Name "$FirstName $LastName" `
           -GivenName $FirstName `
           -Surname $LastName `
           -DisplayName "$FirstName $LastName" `
           -SamAccountName $sam `
           -UserPrincipalName "$sam@corp.apexlogistics.local" `
           -EmailAddress "$sam@apexlogistics.com" `
           -Title $Title `
           -Department $Department `
           -EmployeeID $EmployeeID `
           -OfficePhone $OfficePhone `
           -Company "Apex Global Logistics" `
           -Path $targetOU `
           -AccountPassword $secPass `
           -Enabled $true `
           -ChangePasswordAtLogon $true

# 4. Assign Manager
if ($ManagerSAM) {
    Set-ADUser -Identity $sam -Manager $ManagerSAM
}

# 5. Add to Departmental Global Group
$deptGroup = "GLB-$Department-Staff"
Add-ADGroupMember -Identity $deptGroup -Members $sam -ErrorAction SilentlyContinue

# 6. Add to Universal Broadcast List
Add-ADGroupMember -Identity "DLST-All-Employees" -Members $sam
```

---

## 4. User Home Directory Provisioning
Automate creating personal storage at `C:\UserHomes\<sAMAccountName>` with explicit NTFS access control:

```powershell
$homeDir = "C:\UserHomes\$sam"
New-Item -ItemType Directory -Path $homeDir -Force | Out-Null

$acl = Get-Acl -Path $homeDir
$acl.SetAccessRuleProtection($true, $false) # Block inheritance

# Rule 1: User Full Control
$userSid = New-Object System.Security.Principal.NTAccount("APEX\$sam")
$userRule = New-Object System.Security.AccessControl.FileSystemAccessRule($userSid, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.AddAccessRule($userRule)

# Rule 2: Domain Admins Full Control
$adminSid = New-Object System.Security.Principal.NTAccount("APEX\Domain Admins")
$adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule($adminSid, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$acl.AddAccessRule($adminRule)

Set-Acl -Path $homeDir -AclObject $acl
```

---

## 5. Workstation Staging Checklist
1. Unbox laptop and boot into PXE / install Windows 11 Enterprise.
2. Join workstation to domain: `Add-Computer -DomainName "corp.apexlogistics.local"`.
3. Move computer object to `OU=Workstations,OU=Devices,OU=ApexGlobal,DC=corp,DC=apexlogistics,DC=local`.
4. Run `gpupdate /force` to apply legal warning banner and screen lock policies.
5. Verify BitLocker drive encryption is active: `manage-bde -status C:`.
6. Ship equipment with new hire welcome packet.
