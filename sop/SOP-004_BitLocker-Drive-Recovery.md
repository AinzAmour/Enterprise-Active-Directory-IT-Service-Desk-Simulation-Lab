# SOP-004: BitLocker Drive Encryption Recovery Key Retrieval

**Document ID**: SOP-004  
**Category**: Endpoint Security & Hardware Recovery  
**Target Audience**: Tier 2 Desktop Support, Tier 1 Escalations  
**Required AD Group**: `SEC-ServiceDesk-Tier2` (Delegated BitLocker Read Rights)  
**Governing Policy**: SEC-POL-05 (Endpoint Encryption & Cryptographic Key Management)  

---

## 1. Overview & Security Protocols
Apex Global Logistics mandates full-disk encryption (BitLocker with XTS-AES 256) across all corporate Windows laptops. When hardware or firmware alterations occur (BIOS updates, motherboard replacements, TPM tamper triggers), Windows prompts for a **48-digit numerical recovery key**.

> [!WARNING]
> A BitLocker recovery key grants full access to raw disk contents. Disclosing a key to an unauthorized person constitutes a critical data breach.

---

## 2. Mandatory Verification Gate
Before querying Active Directory for a recovery key, verify:
1. Caller is the assigned asset custodian in the IT Asset Management system.
2. Employee ID matches Active Directory records.
3. User reads the **Recovery Key ID** (displayed on the blue BitLocker recovery screen, e.g., `4A7B9F12-...`).
4. **Out-of-Band Validation**: Send a temporary SMS / push confirmation to the employee's registered corporate phone.

---

## 3. Recovery Key Retrieval Methods

### Method A: PowerShell Active Directory Query (Fastest)
From an administrative management console:

```powershell
$computerName = "AGL-WS01" # Target workstation hostname

# Query Active Directory for msFVE-RecoveryInformation child objects
$keys = Get-ADObject -Filter "objectClass -eq 'msFVE-RecoveryInformation'" `
                     -SearchBase (Get-ADComputer -Identity $computerName).DistinguishedName `
                     -Properties msFVE-RecoveryPassword, whenCreated

if (-not $keys) {
    Write-Error "No BitLocker recovery keys found for '$computerName' in Active Directory."
    exit 1
}

Write-Host "Found $($keys.Count) BitLocker Key(s) for $computerName:" -ForegroundColor Cyan

foreach ($k in $keys) {
    $keyGuid = ($k.Name -split '{')[1] -replace '}', ''
    [PSCustomObject]@{
        Workstation = $computerName
        KeyID       = $keyGuid
        KeyPrefix   = $keyGuid.Substring(0, 8) # Matches screen prompt
        RecoveryKey = $k.'msFVE-RecoveryPassword'
        BackupDate  = $k.whenCreated
    }
}
```

### Method B: Graphical Interface (ADUC)
1. Open `dsa.msc` (Active Directory Users and Computers).
2. Right-click the domain node (`corp.apexlogistics.local`) $\rightarrow$ **Find...**
3. Select **Find: BitLocker Recovery Information**.
4. In the **Recovery Key ID (first 8 characters)** field, enter the first 8 characters provided by the user (e.g., `4A7B9F12`).
5. Click **Find Now**. The matching computer name and 48-digit recovery password will be displayed.

---

## 4. Key Delivery & TPM Stabilization

1. Dictate the 48-digit numerical recovery key to the user in groups of 6 digits:
   - Example: `419283 - 098234 - 581928 - 192847 - 092834 - 182938 - 492019 - 382910`
2. Once the user enters the key and reaches the Windows desktop, the TPM protector must be refreshed to avoid prompting for the key on every subsequent reboot.
3. Open an elevated Command Prompt / PowerShell on the client machine and execute:
   ```cmd
   manage-bde -protectors -disable C:
   manage-bde -protectors -enable C:
   ```
4. Verify BitLocker protection status:
   ```cmd
   manage-bde -status C:
   ```
   *Expected output: Protection Status: Protection On.*
5. Have the user reboot once to confirm normal, unprompted startup.
