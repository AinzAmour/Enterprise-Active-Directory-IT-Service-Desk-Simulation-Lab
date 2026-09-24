<#
.SYNOPSIS
    Provisions Departmental, RBAC, and Resource Access Security Groups for Apex Global Logistics.

.DESCRIPTION
    Creates the standardized security and distribution groups adhering to the AGDLP access control framework.
    Groups are populated in the appropriate containers under OU=Groups.

.PARAMETER DomainDN
    Distinguished Name of the Active Directory domain root. Default: dynamic discovery.

.EXAMPLE
    .\03_Create-SecurityGroups.ps1
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $false)]
    [string]$DomainDN
)

# Import Active Directory Module
if (-not (Get-Module -Name ActiveDirectory -ListAvailable)) {
    Write-Error "The ActiveDirectory PowerShell module is required. Please install RSAT-AD-PowerShell."
    exit 1
}
Import-Module ActiveDirectory

if (-not $DomainDN) {
    try {
        $DomainDN = (Get-ADDomain).DistinguishedName
    } catch {
        $DomainDN = "DC=corp,DC=apexlogistics,DC=local"
    }
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " [AGL LAB] Provisioning Security & Access Control Groups         " -ForegroundColor Cyan
Write-Host " Target Domain DN: $DomainDN                                    " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

$groupsPathRoot = "OU=Groups,OU=ApexGlobal,$DomainDN"
$rbacPath = "OU=Security-RBAC,$groupsPathRoot"
$deptPath = "OU=Security-Departmental,$groupsPathRoot"
$distPath = "OU=Distribution-Lists,$groupsPathRoot"

$groupDefinitions = @(
    # RBAC Privileged & Access Groups
    @{ Name = "SEC-Tier0-IdentityAdmins"; Scope = "Global"; Category = "Security"; Path = $rbacPath; Desc = "Tier 0 Domain Controllers & Identity Plane Administrators" },
    @{ Name = "SEC-Tier1-ServerAdmins"; Scope = "Global"; Category = "Security"; Path = $rbacPath; Desc = "Tier 1 Member Server & Infrastructure Administrators" },
    @{ Name = "SEC-Tier2-WorkstationAdmins"; Scope = "Global"; Category = "Security"; Path = $rbacPath; Desc = "Tier 2 Desktop & Endpoint Support Technicians" },
    @{ Name = "SEC-ServiceDesk-Tier1"; Scope = "Global"; Category = "Security"; Path = $rbacPath; Desc = "Tier 1 Help Desk Technicians (Delegated Password Reset & Unlock)" },
    @{ Name = "SEC-ServiceDesk-Tier2"; Scope = "Global"; Category = "Security"; Path = $rbacPath; Desc = "Tier 2 Escalation Technicians (BitLocker Recovery, GPO Audit)" },
    @{ Name = "SEC-VPN-Users"; Scope = "Global"; Category = "Security"; Path = $rbacPath; Desc = "Authorized corporate VPN remote access users" },
    @{ Name = "SEC-LAPS-Auditors"; Scope = "DomainLocal"; Category = "Security"; Path = $rbacPath; Desc = "Authorized readers for Microsoft LAPS local administrator passwords" },

    # Departmental Global Membership Groups
    @{ Name = "GLB-Executive-Staff"; Scope = "Global"; Category = "Security"; Path = $deptPath; Desc = "Corporate Executive Leadership personnel" },
    @{ Name = "GLB-IT-Staff"; Scope = "Global"; Category = "Security"; Path = $deptPath; Desc = "Information Technology and Systems personnel" },
    @{ Name = "GLB-HR-Staff"; Scope = "Global"; Category = "Security"; Path = $deptPath; Desc = "Human Resources and People Operations personnel" },
    @{ Name = "GLB-Finance-Staff"; Scope = "Global"; Category = "Security"; Path = $deptPath; Desc = "Finance, Accounting, and Payroll personnel" },
    @{ Name = "GLB-Engineering-Staff"; Scope = "Global"; Category = "Security"; Path = $deptPath; Desc = "Software Engineering, DevOps, and Product personnel" },
    @{ Name = "GLB-Logistics-Staff"; Scope = "Global"; Category = "Security"; Path = $deptPath; Desc = "Global Logistics, Fleet, and Warehouse personnel" },
    @{ Name = "GLB-SalesMarketing-Staff"; Scope = "Global"; Category = "Security"; Path = $deptPath; Desc = "Sales, Customer Success, and Marketing personnel" },

    # Resource Access Domain Local Groups (File Shares)
    @{ Name = "DL-Share-Finance-RW"; Scope = "DomainLocal"; Category = "Security"; Path = $rbacPath; Desc = "Read-Write permission to \\AGL-FS01\Finance" },
    @{ Name = "DL-Share-Finance-RO"; Scope = "DomainLocal"; Category = "Security"; Path = $rbacPath; Desc = "Read-Only permission to \\AGL-FS01\Finance" },
    @{ Name = "DL-Share-HR-Confidential"; Scope = "DomainLocal"; Category = "Security"; Path = $rbacPath; Desc = "Confidential Read-Write access to \\AGL-FS01\HR" },
    @{ Name = "DL-Share-Logistics-RW"; Scope = "DomainLocal"; Category = "Security"; Path = $rbacPath; Desc = "Read-Write permission to \\AGL-FS01\Logistics" },
    @{ Name = "DL-Share-IT-RW"; Scope = "DomainLocal"; Category = "Security"; Path = $rbacPath; Desc = "Read-Write permission to \\AGL-FS01\IT_Ops" },
    @{ Name = "DL-Share-Common-RO"; Scope = "DomainLocal"; Category = "Security"; Path = $rbacPath; Desc = "Read-Only permission to company-wide public share" },

    # Distribution Groups (Email Communication)
    @{ Name = "DLST-All-Employees"; Scope = "Universal"; Category = "Distribution"; Path = $distPath; Desc = "Broadcast distribution list for all corporate employees" },
    @{ Name = "DLST-IT-ServiceDesk"; Scope = "Universal"; Category = "Distribution"; Path = $distPath; Desc = "Inbound notifications for IT Service Desk tickets" },
    @{ Name = "DLST-Emergency-Response"; Scope = "Universal"; Category = "Distribution"; Path = $distPath; Desc = "Incident Management team for P1/P2 corporate outages" }
)

$createdCount = 0
$existingCount = 0

foreach ($grp in $groupDefinitions) {
    $existingGroup = Get-ADGroup -Filter "Name -eq '$($grp.Name)'" -ErrorAction SilentlyContinue

    if (-not $existingGroup) {
        if ($PSCmdlet.ShouldProcess($grp.Name, "New-ADGroup")) {
            try {
                New-ADGroup -Name $grp.Name `
                            -GroupScope $grp.Scope `
                            -GroupCategory $grp.Category `
                            -Path $grp.Path `
                            -Description $grp.Desc `
                            -ErrorAction Stop
                Write-Host " [+] Created $($grp.Category) Group: $($grp.Name) ($($grp.Scope))" -ForegroundColor Green
                $createdCount++
            } catch {
                Write-Error " [!] Failed to create group '$($grp.Name)': $_"
            }
        }
    } else {
        Write-Host " [=] Group already exists: $($grp.Name)" -ForegroundColor DarkGray
        $existingCount++
    }
}

Write-Host "`nSummary: $createdCount groups created, $existingCount pre-existing." -ForegroundColor Cyan
Write-Host "Security and Distribution group provisioning completed successfully." -ForegroundColor Green
