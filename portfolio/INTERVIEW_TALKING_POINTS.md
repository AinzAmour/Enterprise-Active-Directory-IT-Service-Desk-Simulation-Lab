# Technical Interview Preparation Guide: The STAR Method

This guide provides structured, interview-ready answers utilizing the **STAR Method** (Situation, Task, Action, Result) based on the scenarios simulated in this lab. Use these talking points during technical and behavioral interviews.

---

## Question 1: "Tell me about a time you handled a critical (P1) outage affecting multiple users."

### **Situation**:
During morning operations, multiple departments reported that client workstations could not log into the domain, returning errors stating *"no logon servers available"*, while departmental file shares became unreachable.

### **Task**:
As the systems investigator on the incident bridge, my task was to isolate whether the failure was physical network disruption, Active Directory database corruption, or service degradation, and restore domain authentication within the 2-hour P1 SLA.

### **Action**:
1. Verified Layer 3 ICMP connectivity from a workstation to the Domain Controller, confirming the physical and virtual switch networks were healthy.
2. Executed `nslookup -type=SRV _ldap._tcp.dc._msdcs.corp.apexlogistics.local` against the DC's IP, which returned *"Non-existent domain"*.
3. Inspected server services on the DC and discovered the `Netlogon` service was in a stopped state, logging Event ID 5774. It had timed out trying to register DNS records before the DNS server service had fully mounted its zone database after an overnight host reboot.
4. Restarted `Netlogon`, executed `nltest /dsregdns` and `ipconfig /registerdns` to force dynamic DNS record registration, and flushed the DNS server cache.
5. Ran `Test-ComputerSecureChannel -Verbose` from client endpoints to verify trust restoration.

### **Result**:
Full authentication was restored across all departments in **1 hour and 8 minutes**, well under the 2-hour SLA. To prevent recurrence, I configured an explicit service dependency in the Windows Registry ensuring `Netlogon` waits for the `DNS` service before starting, and instituted synthetic monitoring for DC locator SRV records.

---

## Question 2: "How do you handle a high-stakes VIP request when an executive is locked out right before an important meeting?"

### **Situation**:
Our CFO was locked out of her account 15 minutes before presenting the quarterly earnings report to the Board of Directors in the executive boardroom.

### **Task**:
Quickly unlock the account, identify the root cause of the lockout to prevent it from immediately re-locking during her presentation, and maintain calm under executive pressure.

### **Action**:
1. Acknowledged the urgency with empathy and verified her identity per our VIP protocol.
2. Rather than blindly hitting "unlock", I immediately queried the Domain Controller Security Event Log for **Event ID 4740** to identify the source machine.
3. The audit log identified the calling station as `VIC-IPAD-PRO`—her personal tablet in her office was attempting background mail synchronization with an expired cached password.
4. Instructed her assistant to put the iPad on Airplane Mode immediately, then executed `Unlock-ADAccount -Identity "vchen"`.

### **Result**:
The CFO logged into the boardroom terminal within **19 minutes** of the call and delivered her presentation without interruption. After the meeting, I assisted her in updating the cached credentials on her tablet before taking it off Airplane Mode, permanently resolving the issue.

---

## Question 3: "Why is granting Help Desk technicians 'Domain Admins' rights a dangerous practice, and how do you prevent it?"

### **Situation / Philosophy**:
Granting Tier 1 or Tier 2 support staff `Domain Admins` privileges violates the **Principle of Least Privilege (PoLP)** and creates severe lateral movement vulnerabilities.

### **Technical Rationale**:
If a technician with Domain Admin credentials logs into a standard user workstation to troubleshoot a printer or install software, their Kerberos ticket granting tickets (TGT) and NTLM credentials remain cached in `LSASS.exe` memory. If that workstation has been compromised with malware, an attacker can dump memory using tools like Mimikatz, harvest the Domain Admin hashes, and compromise the entire forest via Pass-the-Hash (PtH).

### **How I Solved It in My Lab**:
1. Implemented Microsoft’s **Tiered Administration Model**:
   - **Tier 0**: Domain Controllers and Forest Identity.
   - **Tier 1**: Member servers and application backends.
   - **Tier 2**: Workstations and client endpoints.
2. Created a dedicated security group `SEC-ServiceDesk-Tier1` and used `dsacls` to delegate explicit, granular permissions over `OU=Departments`:
   - Reset user passwords and write `lockoutTime` (account unlock).
   - Write `pwdLastSet` (force password change at next logon).
   - Modify phone, title, and office attributes.
3. Technicians can perform 100% of their daily user support duties without possessing domain-wide administrative power.

---

## Question 4: "How do you troubleshoot when a Group Policy Object (GPO) is not applying to a workstation?"

### **Approach & Troubleshooting Methodology**:
1. **Command Line Diagnostic**:
   - Run `gpresult /r /scope:computer` and `gpresult /h C:\temp\gpreport.html` to generate an HTML diagnostic report.
   - Check under **Applied GPOs** vs. **Denied GPOs**.
2. **Evaluate Filtering**:
   - If denied due to *"Filtering: Denied (Security)"*, inspect Security Filtering on the GPO. Following Microsoft patch MS16-072, computer accounts evaluate GPOs, so `Domain Computers` or `Authenticated Users` must have Read permissions.
   - If denied due to *"WMI Filter"*, verify if the machine meets the WMI query criteria (e.g., OS version or architecture).
3. **Replication & Network**:
   - Verify workstation DNS points to the Domain Controller.
   - Verify client can access `\\corp.apexlogistics.local\sysvol`.
   - Run `repadmin /showrepl` on the DC to verify Active Directory SYSVOL replication is healthy.
4. **Remediation**:
   - Fix security filtering, execute `gpupdate /force`, and verify **Event ID 1502** in the Windows Application log confirming successful policy processing.

---

## Question 5: "How have you used PowerShell to eliminate manual, repetitive IT tasks?"

### **Talking Point**:
"In my enterprise lab, I recognized that manual user onboarding was slow, error-prone, and inconsistent across departments. I wrote a production-grade PowerShell provisioning script (`BulkProvision-Users.ps1`) that:
- Ingested a CSV dataset of over 100 employee records.
- Normalized departmental data and routed users dynamically into appropriate nested Organizational Units.
- Generated cryptographically secure temporary passwords and set `ChangePasswordAtLogon = $true`.
- Added users to departmental security groups (`GLB-*`), distribution lists, and file share resource groups (`DL-*`).
- Automatically created personal user home directories on our file server and configured strict NTFS Access Control Lists—blocking inheritance and granting the individual employee and Domain Admins Full Control.

I also developed a daily operations CLI utility (`07_DailyOps-ServiceDeskToolkit.ps1`) that allowed Tier 1 agents to search accounts, unlock users, and execute secure offboarding in under 30 seconds."
