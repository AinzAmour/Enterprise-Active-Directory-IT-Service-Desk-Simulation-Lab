# Incident Runbook: INC-1004 (P3 - Medium / Security)

## Ticket Metadata
| Field | Value |
|:---|:---|
| **Incident ID** | **INC-1004** |
| **Priority** | **P3 - Medium (Security Incident)** |
| **Caller / Reporter** | Harper Ross (HR Coordinator) |
| **Category** | Information Security |
| **Subcategory** | Phishing / Credential Harvesting |
| **Configuration Item (CI)** | `CORP\hross` / Office 365 Exchange Online |
| **Assignment Group** | `IT-ServiceDesk-Tier1` / SecOps Escalation |
| **Assigned To** | Aisha Patel (Tier 1 Help Desk Analyst) |
| **State** | **Closed** |
| **Created** | 2026-09-23 10:15:30 EST |
| **Resolved** | 2026-09-23 11:20:10 EST |
| **SLA Target / Met** | 8 Hours / **MET (1h 4m elapsed)** |

---

## 1. Initial User Report
At 10:15 EST, Harper Ross forwarded a suspicious email to `security@apexlogistics.com` and opened a ticket:
> *"I received an email stating my corporate password will expire in 2 hours with an urgent link to keep my current password. I clicked the link and entered my email and current password, but then it redirected to a blank page. Did I do something wrong?"*

---

## 2. Security Triage & Immediate Containment

Following Corporate Incident Response Procedure (IRP-04: Credential Compromise Containment):

### Step 2.1: Immediate Account Containment
Executed within 4 minutes of ticket receipt:
```powershell
# 1. Reset user password immediately to prevent threat actor logon
$securePass = ConvertTo-SecureString "ContainmentTemp2026!#$" -AsPlainText -Force
Set-ADAccountPassword -Identity "hross" -NewPassword $securePass -Reset

# 2. Revoke all active Kerberos and OAuth refresh tokens
# Forces immediate logout across Microsoft 365, Azure AD, and on-premises sessions
Revoke-AzureADUserAllRefreshToken -ObjectId "hross@apexlogistics.com" -ErrorAction SilentlyContinue

# 3. Disable user account temporarily while investigating endpoint
Disable-ADAccount -Identity "hross"
Write-Host "[!] User 'hross' contained: Password reset, refresh tokens revoked, account disabled." -ForegroundColor Yellow
```

### Step 2.2: Phishing Artifact Analysis
Inspected email headers and destination URL:
- **Sender Address**: `security-update@micosoft-portal-auth.com` (Spoofed domain registered 48 hours ago).
- **Phishing URL**: `hxxps://micosoft-portal-auth[.]com/login/auth.php`
- **Mail Subject**: *"URGENT: Corporate Password Expiration Notice"*

---

## 3. Threat Hunting & Scope Assessment
1. Searched Exchange Online transport logs to identify other corporate recipients of the malicious email:
   ```powershell
   Get-MessageTrace -StartDate (Get-Date).AddDays(-1) -SenderAddress "security-update@micosoft-portal-auth.com"
   ```
   *Findings*: 14 employees received the message. 13 did not click; only `hross` submitted credentials.
2. Deleted malicious message from all 14 inboxes via Exchange Compliance Search:
   ```powershell
   New-ComplianceSearchAction -SearchName "Purge-Phish-20260923" -Purge -PurgeType SoftDelete
   ```
3. Blocked the sender domain and IP at the perimeter email firewall and Cisco Umbrella DNS gateway.

---

## 4. Endpoint Remediation & Return to Service
1. Ran full offline Windows Defender scan on `hross` laptop (`AGL-WS-HR03`). Scan returned clean; no executable payload was downloaded.
2. Re-enabled user account in Active Directory:
   ```powershell
   Enable-ADAccount -Identity "hross"
   Set-ADUser -Identity "hross" -ChangePasswordAtLogon $true
   ```
3. Guided user through a secure password reset at the corporate logon screen.
4. Scheduled user for refresher security awareness training module in KnowBe4.
