# Enterprise Active Directory & IT Service Desk Simulation Lab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a production-grade, resume-ready GitHub repository simulating an Enterprise Active Directory (Windows Server 2022) environment paired with an ITIL Service Desk (ServiceNow & Jira Service Management workflows, 10 realistic ticket runbooks, 5 SOPs, and PowerShell automation).

**Architecture:** A dual-domain structure combining infrastructure automation (modular PowerShell scripts for DC promotion, OU hierarchy, 100+ CSV user provisioning, GPO baselines, and Tier 0-2 RBAC delegation) with enterprise service management (ServiceNow/Jira queues, SLA matrices, incident response logs, and SOP runbooks).

**Tech Stack:** Windows Server 2022, Active Directory Domain Services (AD DS), Group Policy Management, Windows PowerShell 5.1 / PowerShell 7, PSScriptAnalyzer, ITIL v4, ServiceNow & Jira Service Management, Markdown, Mermaid.js.

**Spec:** `docs/superpowers/specs/2026-09-25-enterprise-ad-servicedesk-lab-design.md`

## Global Constraints
- Target Domain: `corp.apexlogistics.local` (NetBIOS: `APEX`)
- Network Subnet: `192.168.10.0/24` (DC: `192.168.10.10`, Client: `192.168.10.50`)
- Operating Systems: Windows Server 2022 Datacenter, Windows 10/11 Enterprise
- All PowerShell scripts must include `[CmdletBinding()]`, structured parameter blocks, error handling (`try/catch`), verbose logging, and comment-based help.
- All tickets must include standardized metadata: Ticket ID, Priority (P1-P4), Source, Category, Affected CI, SLA Targets, Problem Description, Troubleshooting Transcripts, Root Cause Analysis, and Verification.

---

### Task 1: Repository Scaffolding, CI/CD Quality Gate & Architecture Documentation

**Files:**
- Create: `.github/workflows/psscriptanalyzer.yml`
- Create: `docs/architecture/lab-network-topology.md`
- Create: `docs/architecture/active-directory-design.md`
- Create: `docs/architecture/tiered-admin-model.md`
- Create: `docs/guides/hyperv-setup-guide.md`
- Create: `docs/guides/virtualbox-setup-guide.md`
- Create: `LICENSE`

**Interfaces:**
- Produces: Base directory hierarchy, GitHub Actions linting workflow, hypervisor lab setup guides, and network/OU architecture markdown files for the documentation suite.

- [ ] **Step 1: Create GitHub Actions workflow for PSScriptAnalyzer linting**
  Create `.github/workflows/psscriptanalyzer.yml` to automatically lint all PowerShell scripts in `/scripts` on push and PR.
- [ ] **Step 2: Create MIT LICENSE file**
  Create `LICENSE` in repository root.
- [ ] **Step 3: Create lab network topology documentation**
  Create `docs/architecture/lab-network-topology.md` with complete IP schema, virtual switch configuration, and Mermaid diagram.
- [ ] **Step 4: Create Active Directory design documentation**
  Create `docs/architecture/active-directory-design.md` detailing domain structure, DNS integration, and OU hierarchy.
- [ ] **Step 5: Create Tiered Administration Model documentation**
  Create `docs/architecture/tiered-admin-model.md` specifying Tier 0 (Domain Admins), Tier 1 (Server Admins), and Tier 2 (Workstation Admins / Service Desk).
- [ ] **Step 6: Create Hyper-V and VirtualBox VM provisioning guides**
  Create `docs/guides/hyperv-setup-guide.md` and `docs/guides/virtualbox-setup-guide.md` with step-by-step instructions, RAM/vCPU allocations, and network adapter settings.
- [ ] **Step 7: Verify files and commit**
  Verify markdown rendering and commit with message: `"docs: establish architecture specifications, hypervisor setup guides, and CI workflow"`.

---

### Task 2: Simulated Employee Dataset & Infrastructure Automation Scripts

**Files:**
- Create: `data/users_dataset.csv`
- Create: `scripts/01_Setup-DomainController.ps1`
- Create: `scripts/02_Build-OUStructure.ps1`
- Create: `scripts/03_Create-SecurityGroups.ps1`
- Create: `scripts/04_BulkProvision-Users.ps1`
- Test: `tests/Test-ScriptsSyntax.ps1`

**Interfaces:**
- Consumes: OU structure and domain names from `docs/architecture/active-directory-design.md`.
- Produces: `data/users_dataset.csv` (100+ realistic enterprise employees), PowerShell scripts for DC setup, OU hierarchy creation, security group creation, and bulk user provisioning.

- [ ] **Step 1: Generate enterprise employee dataset CSV**
  Create `data/users_dataset.csv` containing 100+ unique employee records spanning Executive, IT, HR, Finance, Engineering, and Sales departments with fields: `FirstName`, `LastName`, `SAMAccountName`, `EmailAddress`, `Department`, `Title`, `EmployeeID`, `Manager`, `OfficePhone`, `Company`.
- [ ] **Step 2: Create Domain Controller Setup script**
  Create `scripts/01_Setup-DomainController.ps1` with static IP configuration, feature installation, and forest promotion logic.
- [ ] **Step 3: Create OU Hierarchy Creation script**
  Create `scripts/02_Build-OUStructure.ps1` with automated provisioning of `ApexGlobal`, `Administration`, `Departments`, `Groups`, `Devices`, and `Service Accounts` with accidental deletion protection.
- [ ] **Step 4: Create Security Groups script**
  Create `scripts/03_Create-SecurityGroups.ps1` provisioning core RBAC, departmental, and resource-access groups.
- [ ] **Step 5: Create Bulk User Provisioning script**
  Create `scripts/04_BulkProvision-Users.ps1` reading `users_dataset.csv`, generating random secure passwords, assigning users to OUs and security groups, and creating home folders.
- [ ] **Step 6: Create and run syntax & parameter verification test**
  Create `tests/Test-ScriptsSyntax.ps1` to parse all scripts with `[System.Management.Automation.Language.Parser]` and ensure 0 syntax errors.
- [ ] **Step 7: Commit**
  Commit with message: `"feat: add enterprise employee dataset and core AD automation scripts"`.

---

### Task 3: Delegation of Control, Group Policy Hardening & Daily Ops Toolkit

**Files:**
- Create: `scripts/05_Delegate-ServiceDeskPermissions.ps1`
- Create: `scripts/06_Deploy-GPOBaselines.ps1`
- Create: `scripts/07_DailyOps-ServiceDeskToolkit.ps1`
- Modify: `tests/Test-ScriptsSyntax.ps1`

**Interfaces:**
- Consumes: Security groups from `scripts/03_Create-SecurityGroups.ps1` and OUs from `scripts/02_Build-OUStructure.ps1`.
- Produces: Least-privilege Service Desk ACL delegation, automated GPO baseline deployment, and an interactive CLI tool for Tier 1/2 operators.

- [ ] **Step 1: Create Service Desk Delegation script**
  Create `scripts/05_Delegate-ServiceDeskPermissions.ps1` delegating password reset, account unlock, and contact modification permissions over the `Departments` OU to `SEC-ServiceDesk-Tier1`.
- [ ] **Step 2: Create Group Policy Baseline Deployment script**
  Create `scripts/06_Deploy-GPOBaselines.ps1` generating and linking GPOs for legal logon banner, 15-minute screen timeout, script block audit logging, and drive mapping.
- [ ] **Step 3: Create Interactive Service Desk Daily Operations CLI Toolkit**
  Create `scripts/07_DailyOps-ServiceDeskToolkit.ps1` with menu options for: Account Search & Status, Unlock & Reset Password, Add/Remove Group Membership, and Employee Offboarding/Deprovisioning.
- [ ] **Step 4: Run syntax tests across all scripts**
  Execute `tests/Test-ScriptsSyntax.ps1` to ensure all scripts pass syntax parsing.
- [ ] **Step 5: Commit**
  Commit with message: `"feat: add service desk delegation, GPO baselines, and daily ops administrative toolkit"`.

---

### Task 4: ITIL Framework, SLA Matrix & ServiceNow / Jira Service Desk Mapping

**Files:**
- Create: `docs/itil/servicenow-jira-framework.md`
- Create: `docs/itil/escalation-matrix.md`

**Interfaces:**
- Produces: ITIL incident and request lifecycle definitions, priority determination matrix, SLA timers, queue routing rules, and custom field mappings.

- [ ] **Step 1: Author ITIL service management framework doc**
  Create `docs/itil/servicenow-jira-framework.md` specifying Incident vs Service Request workflows, state machines (`New` -> `Assigned` -> `In Progress` -> `Pending` -> `Resolved` -> `Closed`), SLA matrices (P1-P4), and platform configuration guides for ServiceNow & Jira Service Management.
- [ ] **Step 2: Author Service Desk escalation matrix**
  Create `docs/itil/escalation-matrix.md` with explicit criteria and contact hierarchies for Tier 1 (Help Desk), Tier 2 (Desktop/Application Support), and Tier 3 (Systems Engineering & Security).
- [ ] **Step 3: Commit**
  Commit with message: `"docs: add ITIL service management framework and escalation matrix"`.

---

### Task 5: Real-World Service Desk Incident & Request Runbooks

**Files:**
- Create: `service-desk/tickets/INC-1001_P1_DNS_Authentication_Failure.md`
- Create: `service-desk/tickets/INC-1002_P2_VIP_Executive_Account_Lockout.md`
- Create: `service-desk/tickets/INC-1003_P2_Finance_Share_Access_Denied.md`
- Create: `service-desk/tickets/INC-1004_P3_Phishing_Incident_Triage.md`
- Create: `service-desk/tickets/INC-1005_P3_GPO_Replication_Failure.md`
- Create: `service-desk/tickets/INC-1006_P3_Logistics_Printer_Mapping.md`
- Create: `service-desk/tickets/INC-1007_P3_VPN_Access_Denied.md`
- Create: `service-desk/tickets/SR-2001_P4_New_Hire_Onboarding.md`
- Create: `service-desk/tickets/SR-2002_P4_Immediate_User_Offboarding.md`
- Create: `service-desk/tickets/SR-2003_P4_BitLocker_Key_Retrieval.md`

**Interfaces:**
- Consumes: ITIL metadata schema from `docs/itil/servicenow-jira-framework.md` and scripts from `scripts/`.
- Produces: 10 comprehensive ticket runbooks demonstrating diagnostic commands, PowerShell remediation, root cause analysis, and SLA performance.

- [ ] **Step 1: Create P1 Critical Incident (INC-1001)**
  DNS SRV record failure preventing domain authentication enterprise-wide.
- [ ] **Step 2: Create P2 High Incidents (INC-1002, INC-1003)**
  VIP Executive account lockout and broken Finance share NTFS permissions.
- [ ] **Step 3: Create P3 Medium Incidents (INC-1004 through INC-1007)**
  Phishing email triage & account containment, GPO client refresh failure, network print spooler offline, and missing VPN security group.
- [ ] **Step 4: Create P4 Standard Service Requests (SR-2001 through SR-2003)**
  New hire onboarding, immediate termination offboarding, and remote laptop BitLocker key recovery.
- [ ] **Step 5: Commit**
  Commit with message: `"docs: add 10 real-world incident and service request simulation runbooks"`.

---

### Task 6: Standard Operating Procedures (SOPs)

**Files:**
- Create: `sop/SOP-001_User-Account-Lockout-and-Password-Reset.md`
- Create: `sop/SOP-002_Employee-Onboarding-and-Provisioning.md`
- Create: `sop/SOP-003_Employee-Offboarding-and-Security-Revocation.md`
- Create: `sop/SOP-004_BitLocker-Drive-Recovery.md`
- Create: `sop/SOP-005_Shared-Folder-NTFS-and-Share-Permissions.md`

**Interfaces:**
- Consumes: AD hierarchy and PowerShell tools from Task 2 & 3.
- Produces: Professional, standardized runbooks for Tier 1 and Tier 2 analysts with step-by-step GUI and PowerShell instructions.

- [ ] **Step 1: Create SOP-001 (Password Reset & Account Lockout)**
- [ ] **Step 2: Create SOP-002 (Employee Onboarding & Account Provisioning)**
- [ ] **Step 3: Create SOP-003 (Employee Offboarding & Security Revocation)**
- [ ] **Step 4: Create SOP-004 (BitLocker Recovery Key Retrieval)**
- [ ] **Step 5: Create SOP-005 (Shared Folder NTFS & Share Permissions Management)**
- [ ] **Step 6: Commit**
  Commit with message: `"docs: add standard operating procedures for Tier 1-2 Service Desk"`.

---

### Task 7: Portfolio Presentation, Resume Bullets, Interview STAR Prep & Flagship README

**Files:**
- Create: `portfolio/RESUME_BULLETS.md`
- Create: `portfolio/INTERVIEW_TALKING_POINTS.md`
- Create: `README.md`
- Remove: `Enterprise Active Directory & IT Service Desk Simulation Lab.txt` (clean up initial note)

**Interfaces:**
- Consumes: All completed lab modules, scripts, tickets, and architectures.
- Produces: The complete public face of the project designed to maximize recruiter interest, ATS scoring, and interview performance.

- [ ] **Step 1: Create tailored Resume Bullets guide**
  Create `portfolio/RESUME_BULLETS.md` with action-oriented, metrics-driven bullet points for Help Desk, Desktop Support, and Junior SysAdmin CVs.
- [ ] **Step 2: Create Interview STAR Prep guide**
  Create `portfolio/INTERVIEW_TALKING_POINTS.md` with structured Situation, Task, Action, Result scenarios addressing common technical and behavioral interview questions.
- [ ] **Step 3: Clean up temporary draft note**
  Remove `Enterprise Active Directory & IT Service Desk Simulation Lab.txt`.
- [ ] **Step 4: Build flagship README.md**
  Create `README.md` with modern badges, project overview, architecture diagrams, PowerShell code snippets, ticketing scenarios showcase, quick start guide, and resume integration.
- [ ] **Step 5: Final validation test and git commit**
  Verify all links and file paths, run tests, and commit with message: `"docs: build flagship README, portfolio resume bullets, and interview guide"`.
