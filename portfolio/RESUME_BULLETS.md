# Resume Bullet Points Guide: Enterprise Active Directory & IT Service Desk Simulation

Use these targeted, achievement-oriented bullet points on your CV or Resume to substantiate your hands-on technical proficiency with **Windows Server 2022**, **Active Directory Domain Services**, **PowerShell automation**, and **ITIL Service Management (ServiceNow & Jira)**.

---

## 1. Role-Targeted Resume Bullet Options

### Track A: IT Support Specialist / Help Desk Tier 1–2
* **Active Directory & Identity Operations**:
  * Administered enterprise Active Directory Domain Services (AD DS) supporting 100+ simulated users across 7 business units; resolved 95%+ of identity incidents within SLA targets utilizing custom PowerShell automation and delegated administrative consoles.
  * Managed user lifecycle operations (onboarding, role changes, involuntary terminations) following ITIL v4 workflows, ensuring positive caller identity verification and immediate token revocation.
  * Diagnosed and remediated recurring account lockouts by querying Security Event ID 4740 logs on Windows Server 2022 Domain Controllers, identifying misconfigured mobile devices and clearing stale cached credentials.
* **Service Desk & ITIL Governance**:
  * Triaged, escalated, and resolved P1 through P4 incidents in ServiceNow and Jira Service Management, adhering to strict SLAs (15-min critical response to 48-hr fulfillment) and maintaining comprehensive audit runbooks.
  * Authored 5 production-ready Standard Operating Procedures (SOPs) for password management, onboarding, involuntary termination, BitLocker recovery, and NTFS permission delegation, accelerating first-contact resolution (FCR).
* **Endpoint & Systems Troubleshooting**:
  * Troubleshot workstation authentication, DNS SRV record lookup failures, and network print spooler bottlenecks across Windows 10/11 client endpoints and Windows Server 2022 infrastructure.
  * Provided secure BitLocker full-disk encryption key retrieval from Active Directory `msFVE-RecoveryInformation` containers, validating TPM platform validation profiles following firmware updates.

---

### Track B: Junior Systems Administrator / Infrastructure Engineer
* **Directory Services & Server Administration**:
  * Deployed and configured a Windows Server 2022 Root Domain Controller (`corp.apexlogistics.local`) featuring integrated DNS zones, reverse lookup tables, and DHCP scope services on an isolated virtual network (`192.168.10.0/24`).
  * Designed and implemented an enterprise Organizational Unit (OU) structure and security group architecture aligned with Microsoft’s Enterprise Access Model (Tier 0 Identity, Tier 1 Servers, Tier 2 Workstations).
  * Enforced fine-grained Group Policy Objects (GPOs) for legal interactive logon banners, 15-minute inactivity screen locks, PowerShell Script Block Logging (Event ID 4104), and LLMNR credential poisoning mitigations.
* **PowerShell Automation & Scripting**:
  * Engineered a modular PowerShell automation suite (`[CmdletBinding()]`, structured error handling, verbose logging) to automate forest promotion, OU provisioning, AGDLP security group deployment, and CSV bulk user creation.
  * Developed an interactive CLI Daily Operations Toolkit for Service Desk staff, automating user status lookups, 1-click password resets, group modifications, and secure offboarding into quarantine OUs.
  * Implemented GitHub Actions CI/CD pipelines incorporating `PSScriptAnalyzer` to validate PowerShell syntax, style guidelines, and code quality across repository commits.

---

### Track C: Identity & Access Management (IAM) Operations Analyst
* **Least-Privilege Security & RBAC**:
  * Implemented granular Active Directory Access Control Entry (ACE) delegation via `dsacls`, authorizing Tier 1 Help Desk staff to perform password resets and account unlocks over `OU=Departments` without granting Domain Admin privileges.
  * Enforced role-based access control (RBAC) following the AGDLP methodology (Accounts $\rightarrow$ Global Groups $\rightarrow$ Domain Local Groups $\rightarrow$ Permissions) for enterprise SMB file shares.
  * Audited and remediated NTFS file permission inheritance breakages and Kerberos ticket-granting token issues across corporate file servers.

---

## 2. Technical Skills Matrix for Resume Skills Section

```
Operating Systems:       Windows Server 2022 Datacenter, Windows 11 Enterprise, Windows 10 Pro
Directory Services:      Active Directory Domain Services (AD DS), Azure AD / Entra ID, DNS, DHCP
Security & Hardening:    Group Policy Objects (GPO), Microsoft LAPS, Tiered Admin Model, BitLocker, AGDLP
ITSM & Ticketing:        ServiceNow ITSM, Jira Service Management (JSM), ITIL v4 Framework, SLA Management
Automation & Scripting:  PowerShell 5.1 / 7, PSScriptAnalyzer, Batch, CI/CD GitHub Actions
Virtualization:          Hyper-V, Oracle VirtualBox, VMware Workstation Pro / Player
Networking Protocols:    TCP/IP, DNS SRV Records, Kerberos, LDAP/LDAPS, SMB 3.1, RADIUS/NPS, ICMP
```

---

## 3. Project Section Summary (Paste directly into Resume)

**Enterprise Active Directory & IT Service Desk Simulation Lab** | *Windows Server 2022, PowerShell, ServiceNow, Jira*
* Architected a complete enterprise domain (`corp.apexlogistics.local`) on Windows Server 2022 with multi-tier OU hierarchy, DNS/DHCP infrastructure, and AGDLP security groups.
* Automated bulk ingestion of 100+ simulated employee records via PowerShell with customized UPN, departmental routing, secure password generation, and automated home folder NTFS ACL provisioning.
* Implemented Microsoft’s Tiered Administration model, applying least-privilege `dsacls` delegation so Tier 1 support technicians execute password resets without Domain Admin privileges.
* Simulated real-world ITIL operations via ServiceNow and Jira Service Management workflows, authoring 10 comprehensive incident/request runbooks (P1 DNS outage, P2 VIP lockout, P3 GPO troubleshooting, P4 BitLocker recovery) and 5 production SOPs.
* Built an automated CI/CD code quality pipeline using GitHub Actions and PSScriptAnalyzer to ensure enterprise scripting standards.
