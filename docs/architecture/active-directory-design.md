# Active Directory Domain Services (AD DS) Architecture & Design

## 1. Domain & Forest Configuration
- **Forest Functional Level**: Windows Server 2016 / 2022
- **Domain Functional Level**: Windows Server 2016 / 2022
- **Fully Qualified Domain Name (FQDN)**: `corp.apexlogistics.local`
- **NetBIOS Name**: `APEX`
- **Root Domain Controller**: `AGL-DC01.corp.apexlogistics.local`
- **Global Catalog (GC)**: Hosted on `AGL-DC01`
- **FSMO Roles**: All 5 flexible single-master operation roles hosted on `AGL-DC01` (Schema Master, Domain Naming Master, RID Master, PDC Emulator, Infrastructure Master).

---

## 2. Organizational Unit (OU) Architecture

The directory follows Microsoft best practices by establishing a single top-level corporate container (`OU=ApexGlobal`) to isolate corporate assets from default built-in Active Directory objects (`CN=Users`, `CN=Computers`). This ensures clean Group Policy inheritance and delegation boundaries.

```
DC=corp,DC=apexlogistics,DC=local
└── OU=ApexGlobal [Company Root Container]
    │
    ├── OU=Administration [Privileged Identity Management]
    │   ├── OU=Tier0-DomainAdmin [Identity, Domain Controllers, Root Admins]
    │   ├── OU=Tier1-ServerAdmin [Member Server Admins, Storage Engineers]
    │   └── OU=Tier2-ServiceDesk [Workstation Admins, Desktop Support, Tier 1/2 Help Desk]
    │
    ├── OU=Departments [Standard Business Users]
    │   ├── OU=Executive [C-Suite, VP, Board Members]
    │   ├── OU=InformationTechnology [IT Infrastructure, Systems, Security Analysts]
    │   ├── OU=HumanResources [People Operations, Recruiters, HR Business Partners]
    │   ├── OU=Finance [Accountants, Financial Analysts, Payroll]
    │   ├── OU=Engineering [Software Developers, DevOps, QA Engineers]
    │   ├── OU=Logistics [Supply Chain Coordinators, Dispatchers, Warehouse Leads]
    │   └── OU=SalesMarketing [Account Executives, SDRs, Marketing Specialists]
    │
    ├── OU=Groups [Directory Security & Distribution]
    │   ├── OU=Security-RBAC [Role-Based Access Control Groups]
    │   ├── OU=Security-Departmental [Department Membership Groups]
    │   └── OU=Distribution-Lists [Email & Notification Lists]
    │
    ├── OU=Devices [Corporate Hardware Assets]
    │   ├── OU=Servers [Tier 1 Infrastructure & Member Servers]
    │   └── OU=Workstations [Tier 2 Client Endpoints - Laptops & Desktops]
    │
    ├── OU=ServiceAccounts [Application & Background Services]
    │   ├── OU=ManagedServiceAccounts [gMSAs for automated tasks]
    │   └── OU=StandardServiceAccounts [Legacy service principals]
    │
    └── OU=Terminated [Disabled & Offboarded Employees - Retention Policy]
```

---

## 3. Security Group Strategy (AGDLP Methodology)
Apex Global Logistics follows the industry standard **AGDLP** pattern:
**A**ccounts $\rightarrow$ **G**lobal Groups $\rightarrow$ **D**omain **L**ocal Groups $\rightarrow$ **P**ermissions.

### 3.1 Departmental Global Groups (`GLB-*`)
Used to group users by business unit:
* `GLB-Executive-Staff`
* `GLB-IT-Staff`
* `GLB-HR-Staff`
* `GLB-Finance-Staff`
* `GLB-Engineering-Staff`
* `GLB-Logistics-Staff`
* `GLB-SalesMarketing-Staff`

### 3.2 Role-Based Access Control (RBAC) Security Groups (`SEC-*`)
Used to grant specific system or administrative capabilities:
* `SEC-Tier0-IdentityAdmins`: Full administrative rights to domain controllers and identity directory.
* `SEC-Tier1-ServerAdmins`: Administrative access to member servers (e.g., `AGL-FS01`).
* `SEC-Tier2-WorkstationAdmins`: Local administrator capabilities over corporate workstations.
* `SEC-ServiceDesk-Tier1`: Delegated rights to reset passwords, unlock accounts, and modify standard user properties over `OU=Departments`.
* `SEC-ServiceDesk-Tier2`: Escalation rights including BitLocker key recovery and GPO verification.
* `SEC-VPN-Users`: Radius / NPS authorization for corporate remote access.

### 3.3 Resource Access Domain Local Groups (`DL-*`)
Applied directly to file systems (NTFS) and share permissions:
* `DL-Share-Finance-RW`: Read/Write access to `\\AGL-FS01\Finance`
* `DL-Share-Finance-RO`: Read-Only access to `\\AGL-FS01\Finance`
* `DL-Share-Logistics-RW`: Read/Write access to `\\AGL-FS01\Logistics`
* `DL-Share-Common-RO`: Read-Only access to company-wide public resources

---

## 4. DNS Architecture
* **Integrated Zone**: Active Directory-Integrated Primary Zone for `corp.apexlogistics.local`.
* **Dynamic Updates**: Secure Only (protects against unauthorized DNS hijacking).
* **Reverse Lookup Zone**: `10.168.192.in-addr.arpa` configured with automatic PTR registration.
* **Forwarders**: Public upstream resolvers configured (`1.1.1.1`, `8.8.8.8`) for recursive external internet resolution.
