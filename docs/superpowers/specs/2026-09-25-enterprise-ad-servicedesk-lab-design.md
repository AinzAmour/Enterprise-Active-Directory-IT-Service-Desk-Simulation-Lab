# Design Specification: Enterprise Active Directory & IT Service Desk Simulation Lab

**Date**: 2026-09-25  
**Domain**: Identity & Access Management (IAM), Systems Administration, ITIL Service Desk Operations  
**Target Organization**: Apex Global Logistics (`corp.apexlogistics.local`)  

---

## 1. Project Overview & Objective

The objective of this project is to build an enterprise-grade, portfolio-ready GitHub repository simulating an **Enterprise Active Directory & IT Service Desk Environment**. It bridges the gap between infrastructure systems engineering (Windows Server 2022, Active Directory DS, Group Policy, PowerShell automation) and operational IT service management (ITIL framework, ServiceNow / Jira Service Management workflows, incident response, and standard operating procedures).

The target audience for this portfolio project includes technical recruiters, hiring managers, and senior engineers evaluating candidates for:
- Systems Administrator / Junior Infrastructure Engineer
- IT Support Specialist / Desktop Support Engineer (Tier 2/3)
- Identity & Access Management (IAM) Operations Analyst
- IT Service Desk Lead / Incident Coordinator

---

## 2. Architecture & Infrastructure Specifications

### 2.1 Identity & Network Topology
- **Organization Name**: Apex Global Logistics (AGL)
- **Domain Name**: `corp.apexlogistics.local` (NetBIOS: `APEX`)
- **Network Subnet**: `192.168.10.0/24`
- **Core Virtual Machines**:
  1. **`AGL-DC01` (Windows Server 2022 Datacenter)**:
     - IP Address: `192.168.10.10` / Gateway: `192.168.10.1` / Primary DNS: `127.0.0.1`
     - Roles: Active Directory Domain Services (AD DS), DNS Server, DHCP Server.
  2. **`AGL-FS01` (Windows Server 2022 - Optional Member Server)**:
     - IP Address: `192.168.10.20`
     - Role: Enterprise File & Storage Services (Department Shares, User Home Directories).
  3. **`AGL-WS01` (Windows 10/11 Enterprise / Pro Workstation)**:
     - IP Address: `192.168.10.50` (or dynamic via DHCP)
     - Role: Domain-joined corporate client endpoint for policy verification and ticket testing.

### 2.2 Active Directory Organizational Unit (OU) Model
Adheres to the Microsoft Tiered Administration / Enterprise Access Model:
```
corp.apexlogistics.local
└── ApexGlobal (Root Organizational Unit)
    ├── Administration
    │   ├── Tier 0 - Identity & Domain Admins
    │   ├── Tier 1 - Infrastructure & Server Admins
    │   └── Tier 2 - Service Desk & Workstation Admins
    ├── Departments
    │   ├── Executive
    │   ├── Information Technology
    │   ├── Human Resources
    │   ├── Finance & Accounting
    │   ├── Engineering & Logistics
    │   └── Sales & Marketing
    ├── Groups
    │   ├── Role-Based Access Control (RBAC)
    │   ├── Departmental Security Groups
    │   └── Distribution Lists
    ├── Devices
    │   ├── Servers (Tier 1 Member Servers)
    │   └── Workstations (Tier 2 Desktops & Laptops)
    └── Service Accounts
        ├── Managed Service Accounts (gMSAs)
        └── Service Principals
```

### 2.3 Least-Privilege Delegation (Service Desk RBAC)
To reflect real-world enterprise security, Tier 1/2 Service Desk staff do not hold `Domain Admins` rights. Instead:
- Security Group: `SEC-ServiceDesk-Tier1`
- Security Group: `SEC-ServiceDesk-Tier2`
- Delegated Permissions:
  - Reset Passwords and force change at next logon on `OU=Departments,OU=ApexGlobal,DC=corp,DC=apexlogistics,DC=local`.
  - Unlock user accounts.
  - Modify contact info (telephone, title, office).
  - Add/Remove members in selected distribution and departmental security groups.
  - Read BitLocker recovery keys via dedicated Tier 2 delegation.

---

## 3. PowerShell Automation Suite

All scripts feature `[CmdletBinding()]`, structured parameter validation, verbose/debug streams, console status color coding, and log-file output.

1. **`01_Setup-DomainController.ps1`**:
   - Validates execution environment and admin privileges.
   - Configures static network adapter settings.
   - Installs AD-Domain-Services and RSAT.
   - Promotes server to new forest root `corp.apexlogistics.local`.
2. **`02_Build-OUStructure.ps1`**:
   - Provisions root and sub-OUs with `ProtectedFromAccidentalDeletion = $true`.
3. **`03_Create-SecurityGroups.ps1`**:
   - Provisions RBAC security groups, departmental groups, and resource-access groups.
4. **`04_BulkProvision-Users.ps1`**:
   - Ingests `data/users_dataset.csv` (100+ realistic enterprise employees).
   - Generates deterministic secure passwords, initializes user accounts with complete attributes, populates department OUs, assigns default group memberships, and initializes home folder directories with strict NTFS ACLs.
5. **`05_Delegate-ServiceDeskPermissions.ps1`**:
   - Configures granular ACLs over the Departments OU using `dsacls` and `Set-Acl` for `SEC-ServiceDesk-Tier1`.
6. **`06_Deploy-GPOBaselines.ps1`**:
   - Automates the creation and linking of baseline GPOs (Interactive Legal Banner, 15-minute Inactive Screen Lock, PowerShell Script Block Logging, LAPS / Local Admin restrictions, and Departmental Drive Mapping).
7. **`07_DailyOps-ServiceDeskToolkit.ps1`**:
   - Command-line administrative toolkit for Service Desk agents:
     - Search user account details & status.
     - Unlock account & reset password.
     - Add/remove user from AD groups.
     - Terminate/offboard employee (disable account, clear groups, move to Terminated OU).

---

## 4. ITIL Service Desk Framework & Ticketing System

Modeled after **ServiceNow** and **Jira Service Management**:

### 4.1 SLA & Priority Matrix
| Priority | Severity | Response SLA | Resolution SLA | Escalation Target |
|:---|:---|:---|:---|:---|
| **P1 - Critical** | Organization-wide outage, authentication failure, core server down | 15 Minutes | 2 Hours | Tier 3 / Lead Systems Engineer |
| **P2 - High** | Department-wide service disruption, VIP / Executive outage | 30 Minutes | 4 Hours | Tier 2 / Systems Administrator |
| **P3 - Medium** | Single user degraded productivity, GPO issue, VPN failure | 2 Hours | 8 Hours | Tier 1 / Service Desk Specialist |
| **P4 - Low** | Standard service requests (onboarding, password reset, equipment) | 4 Hours | 24-48 Hours | Tier 1 Service Desk |

### 4.2 Realistic Ticket Scenarios (`/service-desk/tickets/`)
1. `INC-1001_P1_DNS_Authentication_Failure.md`: DNS SRV record mismatch causing workstation trust relationship failure.
2. `INC-1002_P2_VIP_Executive_Account_Lockout.md`: CFO locked out before board meeting; audit trail reveals brute-force attempt from misconfigured mobile device.
3. `INC-1003_P2_Finance_Share_Access_Denied.md`: NTFS inheritance broken after monthly share backup restore.
4. `INC-1004_P3_Phishing_Incident_Triage.md`: Suspicious credential-harvesting email reported; account containment and password reset.
5. `INC-1005_P3_GPO_Replication_Failure.md`: Workstations failing to receive security banner; troubleshooting SYSVOL replication and `gpupdate`.
6. `INC-1006_P3_Logistics_Printer_Mapping.md`: GPO-targeted print spooler queue offline for shipping dock.
7. `INC-1007_P3_VPN_Access_Denied.md`: Network Policy Server (NPS) radius rejection due to missing `SEC-VPN-Users` group membership.
8. `SR-2001_P4_New_Hire_Onboarding.md`: Provisioning Logistics Specialist with AD account, groups, email, and home folder.
9. `SR-2002_P4_Immediate_User_Offboarding.md`: Terminated sales employee; immediate session disconnect, account disablement, and asset reclamation.
10. `SR-2003_P4_BitLocker_Key_Retrieval.md`: Remote employee locked out by TPM tamper trigger; BitLocker key retrieval via AD DS.

---

## 5. Standard Operating Procedures (SOPs)
1. `SOP-001_User-Account-Lockout-and-Password-Reset.md`
2. `SOP-002_Employee-Onboarding-and-Provisioning.md`
3. `SOP-003_Employee-Offboarding-and-Security-Revocation.md`
4. `SOP-004_BitLocker-Drive-Recovery.md`
5. `SOP-005_Shared-Folder-NTFS-and-Share-Permissions.md`

---

## 6. Portfolio Showcase & Resume Deliverables
- **`README.md`**: Professional, badge-adorned documentation featuring network topology diagrams, OU architecture diagrams, PowerShell code highlights, and simulation walkthroughs.
- **`portfolio/RESUME_BULLETS.md`**: Tailored, high-impact resume bullet points formatted for ATS optimization.
- **`portfolio/INTERVIEW_TALKING_POINTS.md`**: Comprehensive STAR-method (Situation, Task, Action, Result) interview guide for technical behavioral interviews.
