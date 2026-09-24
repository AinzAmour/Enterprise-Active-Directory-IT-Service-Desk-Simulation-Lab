# Service Request Runbook: SR-2001 (P4 - Low / Fulfillment)

## Ticket Metadata
| Field | Value |
|:---|:---|
| **Service Request ID** | **SR-2001** |
| **Priority** | **P4 - Low (Standard Request)** |
| **Caller / Reporter** | Sophia Taylor (HR Operations Manager) |
| **Category** | User Lifecycle & Identity |
| **Subcategory** | Employee Onboarding / Account Provisioning |
| **Configuration Item (CI)** | Active Directory (`corp.apexlogistics.local`) |
| **Assignment Group** | `IT-ServiceDesk-Tier1` |
| **Assigned To** | Aisha Patel (Tier 1 Help Desk Analyst) |
| **State** | **Closed** |
| **Created** | 2026-09-24 09:00:00 EST |
| **Resolved** | 2026-09-24 10:45:15 EST |
| **SLA Target / Met** | 48 Hours / **MET (1h 45m elapsed)** |

---

## 1. Request Details & Hiring Specifications
HR Operations submitted the new employee onboarding intake form:
- **Employee Name**: Marcus Vance
- **Position Title**: Senior Logistics Coordinator
- **Department**: Logistics (`OU=Logistics,OU=Departments,OU=ApexGlobal,DC=corp,DC=apexlogistics,DC=local`)
- **Manager**: Penelope Baker (`pbaker`)
- **Start Date**: 2026-09-28
- **Hardware Profile**: Standard Logistics Laptop (`AGL-WS-LOG05`) + Dual Monitors
- **Access Requirements**: Logistics Shared Drive (`DL-Share-Logistics-RW`), Corporate VPN (`SEC-VPN-Users`), All Employees Distribution List.

---

## 2. Automated Provisioning Execution

Following Standard Operating Procedure `SOP-002: Employee Onboarding & Account Provisioning`:

```powershell
# 1. Define user attributes
$newUser = @{
    SamAccountName        = "mvance"
    UserPrincipalName     = "mvance@corp.apexlogistics.local"
    Name                  = "Marcus Vance"
    GivenName             = "Marcus"
    Surname               = "Vance"
    DisplayName           = "Marcus Vance"
    EmailAddress          = "mvance@apexlogistics.com"
    Title                 = "Senior Logistics Coordinator"
    Department            = "Logistics"
    EmployeeID            = "EMP-1126"
    OfficePhone           = "+1-555-0226"
    Company               = "Apex Global Logistics"
    Path                  = "OU=Logistics,OU=Departments,OU=ApexGlobal,DC=corp,DC=apexlogistics,DC=local"
    AccountPassword       = (ConvertTo-SecureString "WelcomeApex2026!#" -AsPlainText -Force)
    Enabled               = $true
    ChangePasswordAtLogon = $true
}

# 2. Create Active Directory account
New-ADUser @newUser

# 3. Add to Departmental Global & Resource Access Groups
Add-ADGroupMember -Identity "GLB-Logistics-Staff" -Members "mvance"
Add-ADGroupMember -Identity "DL-Share-Logistics-RW" -Members "mvance"
Add-ADGroupMember -Identity "SEC-VPN-Users" -Members "mvance"
Add-ADGroupMember -Identity "DLST-All-Employees" -Members "mvance"

# 4. Provision Home Directory with strict NTFS ACLs
$homePath = "C:\UserHomes\mvance"
New-Item -ItemType Directory -Path $homePath -Force | Out-Null

$acl = Get-Acl -Path $homePath
$acl.SetAccessRuleProtection($true, $false)
$userRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    (New-Object System.Security.Principal.NTAccount("APEX\mvance")),
    "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
)
$acl.AddAccessRule($userRule)
Set-Acl -Path $homePath -AclObject $acl

Write-Host "[✓] Marcus Vance (mvance) provisioned successfully." -ForegroundColor Green
```

---

## 3. Fulfillment Verification & Asset Delivery
1. Staged and domain-joined client laptop `AGL-WS-LOG05`.
2. Verified GPO application (`gpupdate /force` applied drive mappings for `H:\` Home and `S:\Logistics`).
3. Sent onboarding packet containing temporary credentials and first-day instructions to HR Manager Sophia Taylor via encrypted email.
4. Ticket closed with resolution code: **Fulfilled / Complete**.
