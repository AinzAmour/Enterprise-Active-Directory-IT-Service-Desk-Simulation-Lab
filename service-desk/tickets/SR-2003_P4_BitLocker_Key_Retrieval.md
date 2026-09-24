# Service Request Runbook: SR-2003 (P4 - Low / Security Recovery)

## Ticket Metadata
| Field | Value |
|:---|:---|
| **Service Request ID** | **SR-2003** |
| **Priority** | **P4 - Low / Urgent User Assistance** |
| **Caller / Reporter** | Ethan Rodriguez (Lead Software Engineer) |
| **Category** | Workstation & Endpoint Security |
| **Subcategory** | BitLocker Drive Encryption / TPM Recovery |
| **Configuration Item (CI)** | `AGL-WS-ENG02` / Ethan Rodriguez |
| **Assignment Group** | `IT-DesktopSupport-Tier2` |
| **Assigned To** | Carlos Mendez (Tier 2 Desktop Support Specialist) |
| **State** | **Closed** |
| **Created** | 2026-09-24 17:10:00 EST |
| **Resolved** | 2026-09-24 17:28:15 EST |
| **SLA Target / Met** | 24 Hours / **MET (18 minutes elapsed)** |

---

## 1. Initial User Report
Caller Ethan Rodriguez phoned the Service Desk from his personal mobile device:
> *"I updated the BIOS firmware on my Dell Precision corporate laptop (`AGL-WS-ENG02`) this afternoon. Upon rebooting, the system boots into a blue screen titled 'BitLocker recovery'. It says: 'Enter the recovery key for this drive. Drive label: OS C: Recovery Key ID: 4A7B9F12-...'. I cannot get into Windows without this 48-digit key."*

---

## 2. Caller Identity Verification (Security Protocol)
Before disclosing any BitLocker numerical recovery password, Tier 2 technician adhered to strict corporate verification:
1. Confirmed Employee ID: `EMP-1052`.
2. Verified manager: Lucas Robinson (`lrobinson` - VP of Engineering).
3. Sent one-time verification passcode to employee's authenticated mobile number on file. Passcode confirmed by caller.

---

## 3. Active Directory BitLocker Key Query

Using PowerShell on the Domain Controller (`AGL-DC01`) or Tier 2 PAW:

```powershell
# 1. Search for Computer Object
$computerName = "AGL-WS-ENG02"
$computer = Get-ADComputer -Filter "Name -eq '$computerName'"

if (-not $computer) {
    Write-Error "Computer '$computerName' not found in Active Directory."
    exit 1
}

# 2. Query child msFVE-RecoveryInformation objects under the computer object
$bitlockerKeys = Get-ADObject -Filter "objectClass -eq 'msFVE-RecoveryInformation'" `
                              -SearchBase $computer.DistinguishedName `
                              -Properties msFVE-RecoveryPassword, whenCreated

Write-Host "Found $($bitlockerKeys.Count) recovery key(s) for $computerName:" -ForegroundColor Cyan

foreach ($k in $bitlockerKeys) {
    # Extract Key ID from CN (e.g. {4A7B9F12-xxxx-...})
    $keyId = ($k.Name -split '{')[1] -replace '}', ''
    [PSCustomObject]@{
        ComputerName = $computerName
        KeyID        = $keyId
        RecoveryKey  = $k.'msFVE-RecoveryPassword'
        BackupDate   = $k.whenCreated
    }
}
```

### Command Output:
```
ComputerName : AGL-WS-ENG02
KeyID        : 4A7B9F12-78B1-4691-8B23-95C48A181290
RecoveryKey  : 419283-098234-581928-192847-092834-182938-492019-382910
BackupDate   : 9/15/2026 11:22:04 AM
```

Technician verified that the first 8 characters of the Key ID (`4A7B9F12`) matched the screen displayed on the user's laptop.

---

## 4. Recovery Execution & TPM Stabilization
1. Technician read the 48-digit numerical recovery key slowly over the phone in blocks of six digits.
2. User entered the digits on the BitLocker prompt; Windows successfully unlocked and booted into the desktop.
3. Because the BIOS firmware change altered the Trusted Platform Module (TPM) platform validation profile (PCR 7 / PCR 11), the technician instructed the user to open an elevated PowerShell prompt to reseal the TPM with the new hardware state:
   ```cmd
   manage-bde -protectors -disable C:
   manage-bde -protectors -enable C:
   ```
4. User performed a test reboot; laptop booted directly into Windows without requiring the BitLocker key.
5. Ticket documented and closed.
