# SOP-001: User Account Lockout Triage & Password Reset Procedure

**Document ID**: SOP-001  
**Category**: Identity & Access Management  
**Target Audience**: Tier 1 Help Desk Analysts, Tier 2 Desktop Support  
**Required AD Group**: `SEC-ServiceDesk-Tier1`  
**Governing Policy**: SEC-POL-02 (Corporate Identity Security Policy)  

---

## 1. Purpose & Scope
This Standard Operating Procedure (SOP) governs the mandatory identity verification, account unlocking, and temporary password reset workflows for employees of Apex Global Logistics. It applies to all inbound phone, portal, and walk-up requests.

---

## 2. Mandatory Caller Identity Verification
> [!CAUTION]
> To defend against social engineering and SIM swap attacks, technicians must **NEVER** reset a password or provide credentials without completing positive verification.

Before executing a password reset or unlock, verify **at least two** of the following:
1. **Employee ID Number** (cross-referenced with `EmployeeID` attribute in Active Directory).
2. **Direct Manager Name** (cross-referenced with `Manager` attribute).
3. **Out-of-Band Callback**: Call the user back at their corporate telephone number listed in Active Directory.

---

## 3. Step-by-Step Execution

### Method A: Daily Operations CLI Toolkit (Recommended)
1. Launch PowerShell as an administrator and execute:
   ```powershell
   .\scripts\07_DailyOps-ServiceDeskToolkit.ps1
   ```
2. Select **Option 2: Unlock Account & Reset Password**.
3. Enter the user's `sAMAccountName` (e.g., `jwilson`).
4. Review current lockout status.
5. Enter `y` to issue a secure temporary password.
6. Provide the generated password to the user securely.

---

### Method B: Native PowerShell Cmdlets
```powershell
$sam = "jwilson"

# 1. Inspect lockout status and bad password count
Get-ADUser -Identity $sam -Properties LockedOut, BadLogonCount, LastBadPasswordAttempt | 
    Select-Object Name, LockedOut, BadLogonCount, LastBadPasswordAttempt

# 2. Unlock the account
Unlock-ADAccount -Identity $sam

# 3. Generate random temporary password
$tempPass = "ApexTemp$((Get-Random -Minimum 1000 -Maximum 9999))!"
$secPass = ConvertTo-SecureString $tempPass -AsPlainText -Force

# 4. Set password and mandate change at next logon
Set-ADAccountPassword -Identity $sam -NewPassword $secPass -Reset
Set-ADUser -Identity $sam -ChangePasswordAtLogon $true

Write-Host "Temporary Password: $tempPass" -ForegroundColor Yellow
```

---

### Method C: Graphical Interface (Active Directory Users and Computers - ADUC)
1. Open `dsa.msc` from your Tier 2 administrative workstation.
2. Navigate to `OU=Departments,OU=ApexGlobal,DC=corp,DC=apexlogistics,DC=local` and open the user's department OU.
3. Right-click the user object $\rightarrow$ **Reset Password**:
   - Type a temporary password compliant with corporate complexity (12+ characters, upper, lower, digit, symbol).
   - Check **"User must change password at next logon"**.
   - Check **"Unlock the user's account"** (if locked).
   - Click **OK**.

---

## 4. Troubleshooting Repeated Lockouts
If an account re-locks immediately after being unlocked:
1. Query Domain Controller Security Event Log for **Event ID 4740**:
   ```powershell
   Get-WinEvent -FilterHashtable @{LogName='Security'; Id=4740} -MaxEvents 3 |
       Where-Object { $_.Properties[0].Value -eq $sam } |
       Select-Object TimeCreated, @{N='CallerComputer';E={$_.Properties[1].Value}}
   ```
2. Identify the `CallerComputer` causing the failed attempts:
   - If mobile device (e.g., iPhone/iPad), place in Airplane mode until password is updated.
   - If workstation, clear cached credentials in Windows Credential Manager (`control /name Microsoft.CredentialManager`).
   - If a background Windows service or mapped drive is running under the user's credential, update the service logon.
