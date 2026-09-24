# Incident Runbook: INC-1007 (P3 - Medium)

## Ticket Metadata
| Field | Value |
|:---|:---|
| **Incident ID** | **INC-1007** |
| **Priority** | **P3 - Medium** |
| **Caller / Reporter** | Penelope Baker (Senior Fleet Operations Manager) |
| **Category** | Network & Remote Access |
| **Subcategory** | Corporate SSL-VPN / NPS Radius Authentication |
| **Configuration Item (CI)** | `VPN-GW01` / `AGL-DC01` (NPS Server) |
| **Assignment Group** | `IT-ServiceDesk-Tier1` |
| **Assigned To** | Noah Kim (Tier 1 Help Desk Analyst) |
| **State** | **Closed** |
| **Created** | 2026-09-24 11:30:15 EST |
| **Resolved** | 2026-09-24 11:48:40 EST |
| **SLA Target / Met** | 8 Hours / **MET (18 minutes elapsed)** |

---

## 1. Initial User Report
Caller Penelope Baker submitted a ticket while traveling on business:
> *"I am trying to log into the corporate VPN using the Cisco AnyConnect / FortiClient software from my hotel room. It prompts for my Active Directory credentials and Microsoft Authenticator MFA, accepts both, but then throws an immediate error: 'Login Denied: Unauthorized network access policy'."*

---

## 2. Investigation & Diagnostic Log

### Step 2.1: Audit Network Policy Server (NPS) Authentication Logs
On Domain Controller / RADIUS Server `AGL-DC01`:
```powershell
Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    Id = 6273 # Network Policy Server discarded or denied connection
} -MaxEvents 5 | Where-Object { $_.Properties[0].Value -eq 'pbaker' } | ForEach-Object {
    [PSCustomObject]@{
        TimeCreated = $_.TimeCreated
        AccountName = $_.Properties[0].Value
        ReasonCode  = $_.Properties[2].Value
        ReasonDesc  = $_.Properties[4].Value
    }
}
```
**Diagnostic Findings**:
- **AccountName**: `pbaker`
- **ReasonCode**: `65`
- **ReasonDesc**: *"The user does not match any of the network policies configured on the server."*

### Step 2.2: Inspect Active Directory Group Memberships
Inspected user object `pbaker` in Active Directory:
```powershell
(Get-ADUser -Identity "pbaker" -Properties MemberOf).MemberOf
```
*Output*:
- `CN=GLB-Logistics-Staff,OU=Security-Departmental,OU=Groups,OU=ApexGlobal,DC=corp,DC=apexlogistics,DC=local`
- `CN=DLST-All-Employees,OU=Distribution-Lists,OU=Groups,OU=ApexGlobal,DC=corp,DC=apexlogistics,DC=local`

**Root Cause**: The Corporate VPN Network Policy requires users to be members of the AD security group `SEC-VPN-Users`. Penelope had recently transferred into the Fleet Operations Management role and her previous department manager had not submitted a formal VPN entitlement request.

---

## 3. Remediation & Verification

### Step 3.1: Manager Approval & Role Provisioning
Verified written email approval from Supply Chain Director Carter Adams (`cadams`).

### Step 3.2: Add User to VPN Security Group
```powershell
Add-ADGroupMember -Identity "SEC-VPN-Users" -Members "pbaker" -Verbose

# Verify group membership
Get-ADGroupMember -Identity "SEC-VPN-Users" | Where-Object { $_.SamAccountName -eq 'pbaker' }
```

### Step 3.3: Verification with End User
1. Instructed Penelope Baker to attempt VPN connection again from her remote client.
2. User entered credentials and approved MFA prompt.
3. VPN tunnel established successfully; IP assigned: `10.200.5.42`.
4. User confirmed successful access to `\\AGL-FS01\Logistics` and the corporate ERP portal.
