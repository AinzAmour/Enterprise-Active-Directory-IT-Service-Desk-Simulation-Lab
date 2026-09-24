# Incident Runbook: INC-1006 (P3 - Medium)

## Ticket Metadata
| Field | Value |
|:---|:---|
| **Incident ID** | **INC-1006** |
| **Priority** | **P3 - Medium** |
| **Caller / Reporter** | Levi Carter (Senior Dispatch Coordinator) |
| **Category** | Hardware & Peripherals |
| **Subcategory** | Network Printing / Print Spooler |
| **Configuration Item (CI)** | `PRN-DOCK-01` / `AGL-FS01` (Print Server) |
| **Assignment Group** | `IT-ServiceDesk-Tier1` |
| **Assigned To** | Aisha Patel (Tier 1 Help Desk Analyst) |
| **State** | **Closed** |
| **Created** | 2026-09-24 07:45:12 EST |
| **Resolved** | 2026-09-24 08:30:20 EST |
| **SLA Target / Met** | 8 Hours / **MET (45 minutes elapsed)** |

---

## 1. Initial User Report
At 07:45 EST, Levi Carter opened an urgent morning dispatch ticket:
> *"The warehouse shipping terminal cannot print bill-of-lading documents. The network printer 'PRN-DOCK-01' shows as offline on all 4 dispatch workstations, and warehouse trucks cannot depart without signed paper manifests."*

---

## 2. Investigation & Diagnostic Log

### Step 2.1: Test Network Connectivity to Printer Hardware
Pinged the thermal network printer IP directly:
```powershell
Test-Connection -ComputerName 192.168.10.180 -Count 2
# Result: 0% packet loss, ping response <2ms (Physical printer hardware is online and responding).
```

### Step 2.2: Inspect Windows Print Server Spooler Status (`AGL-FS01`)
Investigated the corporate print server managing the queue:
```powershell
Invoke-Command -ComputerName "AGL-FS01" -ScriptBlock {
    Get-Printer -Name "PRN-DOCK-01" | Select-Object Name, DriverName, PortName, PrinterStatus, JobCount
}
# Output:
# Name          : PRN-DOCK-01
# PrinterStatus : Error
# JobCount      : 18
```
*Finding*: 18 print jobs were queued. The oldest job had corrupted data sent from an incompatible label formatting script, locking the Windows Print Spooler thread.

---

## 3. Remediation & Recovery

Executed remote recovery script on print server `AGL-FS01`:

```powershell
Invoke-Command -ComputerName "AGL-FS01" -ScriptBlock {
    Write-Host "[1/3] Stopping Windows Print Spooler service..." -ForegroundColor Yellow
    Stop-Service -Name Spooler -Force

    Write-Host "[2/3] Purging corrupted spool files (.SPL / .SHD)..." -ForegroundColor Yellow
    $spoolPath = "C:\Windows\System32\spool\PRINTERS\*"
    Remove-Item -Path $spoolPath -Force -ErrorAction SilentlyContinue

    Write-Host "[3/3] Restarting Print Spooler service..." -ForegroundColor Yellow
    Start-Service -Name Spooler

    # Verify queue status
    Get-Printer -Name "PRN-DOCK-01" | Select-Object Name, PrinterStatus, JobCount
}
# Result: PrinterStatus: Normal, JobCount: 0.
```

### Client Workstation Verification:
Contacted Levi Carter on terminal `AGL-WS-DOCK01`:
1. Printer `PRN-DOCK-01` transitioned from "Offline" to "Ready".
2. Dispatched a test Bill of Lading PDF; document printed immediately.
3. Informed dispatcher that the 18 purged stuck jobs needed to be re-printed from the logistics dispatch portal.
