<#
.SYNOPSIS
    Builds the Enterprise Organizational Unit (OU) Hierarchy for Apex Global Logistics.

.DESCRIPTION
    Creates the standardized OU tree under the domain root following Microsoft's
    Enterprise Access / Tiered Administration model. Protects all OUs against accidental deletion.

.PARAMETER DomainDN
    Distinguished Name of the Active Directory domain root. 
    Default: Determined dynamically from ActiveDirectory module or 'DC=corp,DC=apexlogistics,DC=local'.

.EXAMPLE
    .\02_Build-OUStructure.ps1
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

# Determine Domain DN dynamically if not passed
if (-not $DomainDN) {
    try {
        $DomainDN = (Get-ADDomain).DistinguishedName
    } catch {
        $DomainDN = "DC=corp,DC=apexlogistics,DC=local"
    }
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " [AGL LAB] Building Enterprise Organizational Unit Hierarchy    " -ForegroundColor Cyan
Write-Host " Target Domain DN: $DomainDN                                    " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# Define Organizational Unit schema: Name, Path
$ouDefinitions = @(
    # Root Corporate OU
    @{ Name = "ApexGlobal"; Path = "$DomainDN"; Description = "Top-level corporate container for Apex Global Logistics" },

    # Privileged Administration Tiers
    @{ Name = "Administration"; Path = "OU=ApexGlobal,$DomainDN"; Description = "Tiered Privileged Identity Management" },
    @{ Name = "Tier0-DomainAdmin"; Path = "OU=Administration,OU=ApexGlobal,$DomainDN"; Description = "Tier 0 Identity & Control Plane Admins" },
    @{ Name = "Tier1-ServerAdmin"; Path = "OU=Administration,OU=ApexGlobal,$DomainDN"; Description = "Tier 1 Enterprise Server Administrators" },
    @{ Name = "Tier2-ServiceDesk"; Path = "OU=Administration,OU=ApexGlobal,$DomainDN"; Description = "Tier 2 Workstation & Help Desk Technicians" },

    # Business Departments
    @{ Name = "Departments"; Path = "OU=ApexGlobal,$DomainDN"; Description = "Standard Enterprise User Accounts" },
    @{ Name = "Executive"; Path = "OU=Departments,OU=ApexGlobal,$DomainDN"; Description = "Corporate Executive Leadership" },
    @{ Name = "InformationTechnology"; Path = "OU=Departments,OU=ApexGlobal,$DomainDN"; Description = "IT Systems & Infrastructure Staff" },
    @{ Name = "HumanResources"; Path = "OU=Departments,OU=ApexGlobal,$DomainDN"; Description = "Human Resources & Talent Acquisition" },
    @{ Name = "Finance"; Path = "OU=Departments,OU=ApexGlobal,$DomainDN"; Description = "Finance, Accounting, and Payroll" },
    @{ Name = "Engineering"; Path = "OU=Departments,OU=ApexGlobal,$DomainDN"; Description = "Software Engineering, DevOps, and QA" },
    @{ Name = "Logistics"; Path = "OU=Departments,OU=ApexGlobal,$DomainDN"; Description = "Global Supply Chain & Warehouse Operations" },
    @{ Name = "SalesMarketing"; Path = "OU=Departments,OU=ApexGlobal,$DomainDN"; Description = "Sales, Customer Success, and Marketing" },

    # Groups Container
    @{ Name = "Groups"; Path = "OU=ApexGlobal,$DomainDN"; Description = "Corporate Security & Distribution Groups" },
    @{ Name = "Security-RBAC"; Path = "OU=Groups,OU=ApexGlobal,$DomainDN"; Description = "Role-Based Access Control Security Groups" },
    @{ Name = "Security-Departmental"; Path = "OU=Groups,OU=ApexGlobal,$DomainDN"; Description = "Department Membership Security Groups" },
    @{ Name = "Distribution-Lists"; Path = "OU=Groups,OU=ApexGlobal,$DomainDN"; Description = "Department Email Distribution Groups" },

    # Devices Container
    @{ Name = "Devices"; Path = "OU=ApexGlobal,$DomainDN"; Description = "Corporate Computer Assets" },
    @{ Name = "Servers"; Path = "OU=Devices,OU=ApexGlobal,$DomainDN"; Description = "Tier 1 Infrastructure & Member Servers" },
    @{ Name = "Workstations"; Path = "OU=Devices,OU=ApexGlobal,$DomainDN"; Description = "Tier 2 Desktop & Laptop Workstations" },

    # Service Accounts Container
    @{ Name = "ServiceAccounts"; Path = "OU=ApexGlobal,$DomainDN"; Description = "Enterprise Application Identities" },
    @{ Name = "ManagedServiceAccounts"; Path = "OU=ServiceAccounts,OU=ApexGlobal,$DomainDN"; Description = "Group Managed Service Accounts (gMSA)" },
    @{ Name = "StandardServiceAccounts"; Path = "OU=ServiceAccounts,OU=ApexGlobal,$DomainDN"; Description = "Legacy Service Accounts" },

    # Lifecycle & Offboarding
    @{ Name = "Terminated"; Path = "OU=ApexGlobal,$DomainDN"; Description = "Disabled User Accounts Pending Retention Expiration" }
)

$createdCount = 0
$existingCount = 0

foreach ($ou in $ouDefinitions) {
    $targetDN = "OU=$($ou.Name),$($ou.Path)"
    $existingOU = Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$targetDN'" -ErrorAction SilentlyContinue

    if (-not $existingOU) {
        if ($PSCmdlet.ShouldProcess($targetDN, "New-ADOrganizationalUnit")) {
            try {
                New-ADOrganizationalUnit -Name $ou.Name `
                                         -Path $ou.Path `
                                         -Description $ou.Description `
                                         -ProtectedFromAccidentalDeletion $true `
                                         -ErrorAction Stop
                Write-Host " [+] Created OU: OU=$($ou.Name)" -ForegroundColor Green
                $createdCount++
            } catch {
                Write-Error " [!] Failed to create OU '$targetDN': $_"
            }
        }
    } else {
        Write-Host " [=] OU already exists: OU=$($ou.Name)" -ForegroundColor DarkGray
        $existingCount++
    }
}

Write-Host "`nSummary: $createdCount OUs created, $existingCount pre-existing." -ForegroundColor Cyan
Write-Host "Enterprise OU structure successfully generated." -ForegroundColor Green
