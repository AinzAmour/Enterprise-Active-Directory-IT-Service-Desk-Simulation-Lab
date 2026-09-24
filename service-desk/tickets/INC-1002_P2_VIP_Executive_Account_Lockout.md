# Incident Runbook: INC-1002 (P2 - High / VIP)

## Ticket Metadata
| Field | Value |
|:---|:---|
| **Incident ID** | **INC-1002** |
| **Priority** | **P2 - High (VIP Priority)** |
| **Caller / Reporter** | Victoria Chen (Chief Financial Officer) |
| **Category** | Identity & Access |
| **Subcategory** | Account Lockout / Brute Force Protection |
| **Configuration Item (CI)** | `CORP\vchen` / `AGL-DC01` |
| **Assignment Group** | `IT-ServiceDesk-Tier1` (VIP Escalation) |
| **Assigned To** | Liam O'Connor (Service Desk Team Lead) |
| **State** | **Closed** |
| **Created** | 2026-09-22 09:45:10 EST |
| **Resolved** | 2026-09-22 10:04:35 EST |
| **SLA Target / Met** | 4 Hours / **MET (19 minutes elapsed)** |

---

## 1. Initial User Report
At 09:45 EST, Executive Assistant called the Service Desk emergency direct line:
> *"CFO Victoria Chen is locked out of her laptop in the executive boardroom. She has the Q3 Earnings Call with the Board of Directors in 15 minutes and cannot access her presentation or financial model on the network drive."*

---

## 2. Investigation & Diagnostic Log

### Step 2.1: Verify Account Status in Active Directory
Using PowerShell on the administrative management console:
```powershell
Get-ADUser -Identity "vchen" -Properties LockedOut, BadLogonCount, LastBadPasswordAttempt, lockoutTime

# Output:
# LockedOut                : True
# BadLogonCount            : 5
# LastBadPasswordAttempt   : 9/22/2026 9:44:52 AM
# lockoutTime              : 133714886920000000
```
*Finding*: Account is actively locked out per corporate Fine-Grained Password Policy (lockout threshold: 5 attempts).

### Step 2.2: Track Down the Source Machine of Lockouts (Security Event ID 4740)
To prevent the account from immediately locking again upon unlock, we queried the Domain Controller Security Event Log:
```powershell
Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    Id = 4740
} -MaxEvents 5 | Where-Object { $_.Properties[0].Value -eq 'vchen' } | ForEach-Object {
    [PSCustomObject]@{
        TimeGenerated  = $_.TimeCreated
        TargetUserName = $_.Properties[0].Value
        CallerComputer = $_.Properties[1].Value
    }
}

# Output:
# TimeGenerated       TargetUserName  CallerComputer
# 9/22/2026 9:44:52 AM vchen          VIC-IPAD-PRO
```
*Diagnosis*: The lockout was not caused by human error on her boardroom laptop (`AGL-WS-EXEC01`), but by her secondary mobile device (`VIC-IPAD-PRO`). Her corporate email app was attempting background synchronization using her expired password from the previous day's password cycle.

---

## 3. Remediation & Recovery

```powershell
# 1. Instruct Executive Assistant to place VIC-IPAD-PRO into Airplane Mode temporarily.

# 2. Unlock the account via PowerShell
Unlock-ADAccount -Identity "vchen"

# 3. Verify user unlock status
(Get-ADUser -Identity "vchen" -Properties LockedOut).LockedOut
# Output: False

# 4. User successfully logged into boardroom laptop and verified access to \\AGL-FS01\Finance.
```

---

## 4. Post-Incident Follow-Up
1. Following the conclusion of the board meeting, technician assisted the CFO in updating the cached corporate Wi-Fi and Outlook profile passwords on `VIC-IPAD-PRO` before taking it off Airplane Mode.
2. Verified no further 4740 events were generated for `vchen`.
