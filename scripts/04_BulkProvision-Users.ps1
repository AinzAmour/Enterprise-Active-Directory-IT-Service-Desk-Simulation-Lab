<#
.SYNOPSIS
    Automates bulk user provisioning from CSV dataset for Apex Global Logistics.

.DESCRIPTION
    Reads data/users_dataset.csv and creates fully configured Active Directory accounts:
    - Normalizes departmental naming and routes to designated Organizational Units.
    - Configures attributes: UPN, DisplayName, Email, Title, EmployeeID, OfficePhone, Company.
    - Sets initial secure password with ChangePasswordAtLogon = $true.
    - Adds accounts to departmental security groups and corporate distribution lists.
    - Automatically provisions Service Desk technicians into SEC-ServiceDesk-Tier1 / Tier2.
    - Creates local/network user home directory with restricted NTFS permissions.

.PARAMETER CsvPath
    Path to the employee dataset CSV. Default: data/users_dataset.csv

.PARAMETER DefaultPassword
    Initial temporary password for provisioned accounts. Default: 'ApexInitial2026!'

.PARAMETER CreateHomeDirectories
    Switch to create user home directory folders on disk. Default: $true

.PARAMETER HomeShareRoot
    Root directory where user home folders are created. Default: 'C:\UserHomes'

.EXAMPLE
    .\04_BulkProvision-Users.ps1 -CsvPath "..\data\users_dataset.csv"
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $false)]
    [string]$CsvPath = "$PSScriptRoot\..\data\users_dataset.csv",

    [Parameter(Mandatory = $false)]
    [string]$DefaultPassword = "ApexInitial2026!",

    [Parameter(Mandatory = $false)]
    [bool]$CreateHomeDirectories = $true,

    [Parameter(Mandatory = $false)]
    [string]$HomeShareRoot = "C:\UserHomes"
)

# Import Active Directory Module
if (-not (Get-Module -Name ActiveDirectory -ListAvailable)) {
    Write-Error "The ActiveDirectory PowerShell module is required. Please install RSAT-AD-PowerShell."
    exit 1
}
Import-Module ActiveDirectory

$domainObj = Get-ADDomain
$domainDN = $domainObj.DistinguishedName
$domainUPN = $domainObj.DNSRoot

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " [AGL LAB] Bulk User Provisioning Engine                         " -ForegroundColor Cyan
Write-Host " Target Domain: $domainUPN ($domainDN)                           " -ForegroundColor Cyan
Write-Host " Ingesting Data: $CsvPath                                        " -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# Validate CSV file existence
if (-not (Test-Path -Path $CsvPath)) {
    Write-Error "Could not find employee dataset at '$CsvPath'. Please verify path."
    exit 1
}

$users = Import-Csv -Path $CsvPath
Write-Host " [i] Successfully loaded $($users.Count) employee records from CSV.`n" -ForegroundColor Yellow

# Department to OU and Group Mapping Dictionary
$deptMap = @{
    "Executive"              = @{ OU = "OU=Executive,OU=Departments,OU=ApexGlobal,$domainDN"; Group = "GLB-Executive-Staff" }
    "Information Technology" = @{ OU = "OU=InformationTechnology,OU=Departments,OU=ApexGlobal,$domainDN"; Group = "GLB-IT-Staff" }
    "Human Resources"        = @{ OU = "OU=HumanResources,OU=Departments,OU=ApexGlobal,$domainDN"; Group = "GLB-HR-Staff" }
    "Finance"                = @{ OU = "OU=Finance,OU=Departments,OU=ApexGlobal,$domainDN"; Group = "GLB-Finance-Staff" }
    "Engineering"            = @{ OU = "OU=Engineering,OU=Departments,OU=ApexGlobal,$domainDN"; Group = "GLB-Engineering-Staff" }
    "Logistics"              = @{ OU = "OU=Logistics,OU=Departments,OU=ApexGlobal,$domainDN"; Group = "GLB-Logistics-Staff" }
    "SalesMarketing"         = @{ OU = "OU=SalesMarketing,OU=Departments,OU=ApexGlobal,$domainDN"; Group = "GLB-SalesMarketing-Staff" }
}

# Ensure Home Share root directory exists if requested
if ($CreateHomeDirectories -and (-not (Test-Path -Path $HomeShareRoot))) {
    New-Item -ItemType Directory -Path $HomeShareRoot -Force | Out-Null
    Write-Host " [i] Created Home Share root directory at '$HomeShareRoot'." -ForegroundColor Gray
}

$securePassword = ConvertTo-SecureString $DefaultPassword -AsPlainText -Force
$createdCount = 0
$skippedCount = 0
$errorCount = 0

foreach ($emp in $users) {
    $sam = $emp.SAMAccountName.Trim()
    $upn = "$sam@$domainUPN"
    $dept = $emp.Department.Trim()
    $title = $emp.Title.Trim()

    # Determine target OU and primary group
    $mapping = $deptMap[$dept]
    if (-not $mapping) {
        Write-Warning " [!] Unknown department '$dept' for user '$sam'. Falling back to Departments root."
        $targetOU = "OU=Departments,OU=ApexGlobal,$domainDN"
        $targetGroup = $null
    } else {
        $targetOU = $mapping.OU
        $targetGroup = $mapping.Group
    }

    # Check if user already exists
    $existing = Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Host " [=] User '$sam' already exists. Skipping." -ForegroundColor DarkGray
        $skippedCount++
        continue
    }

    if ($PSCmdlet.ShouldProcess($sam, "New-ADUser")) {
        try {
            $userParams = @{
                SamAccountName        = $sam
                UserPrincipalName     = $upn
                Name                  = "$($emp.FirstName) $($emp.LastName)"
                GivenName             = $emp.FirstName
                Surname               = $emp.LastName
                DisplayName           = "$($emp.FirstName) $($emp.LastName)"
                EmailAddress          = $emp.EmailAddress
                Title                 = $title
                Department            = $dept
                OfficePhone           = $emp.OfficePhone
                Company               = $emp.Company
                EmployeeID            = $emp.EmployeeID
                Path                  = $targetOU
                AccountPassword       = $securePassword
                Enabled               = $true
                ChangePasswordAtLogon = $true
            }

            New-ADUser @userParams -ErrorAction Stop

            # Assign to Departmental Global Group
            if ($targetGroup) {
                Add-ADGroupMember -Identity $targetGroup -Members $sam -ErrorAction SilentlyContinue
            }

            # Assign to Universal Broadcast Distribution List
            Add-ADGroupMember -Identity "DLST-All-Employees" -Members $sam -ErrorAction SilentlyContinue

            # Role-Based Provisioning: IT Support Roles
            if ($title -match "Service Desk|Help Desk") {
                Add-ADGroupMember -Identity "SEC-ServiceDesk-Tier1" -Members $sam -ErrorAction SilentlyContinue
                Add-ADGroupMember -Identity "DLST-IT-ServiceDesk" -Members $sam -ErrorAction SilentlyContinue
                Write-Host "      -> Added '$sam' to 'SEC-ServiceDesk-Tier1' role." -ForegroundColor Magenta
            }
            if ($title -match "Desktop Support|Support Specialist|Systems Administrator") {
                Add-ADGroupMember -Identity "SEC-ServiceDesk-Tier2" -Members $sam -ErrorAction SilentlyContinue
                Add-ADGroupMember -Identity "SEC-Tier2-WorkstationAdmins" -Members $sam -ErrorAction SilentlyContinue
                Write-Host "      -> Added '$sam' to 'SEC-ServiceDesk-Tier2' and 'SEC-Tier2-WorkstationAdmins'." -ForegroundColor Magenta
            }
            if ($dept -eq "Finance") {
                Add-ADGroupMember -Identity "DL-Share-Finance-RW" -Members $sam -ErrorAction SilentlyContinue
            }
            if ($dept -eq "Logistics") {
                Add-ADGroupMember -Identity "DL-Share-Logistics-RW" -Members $sam -ErrorAction SilentlyContinue
            }

            # Create User Home Directory & Set NTFS ACLs
            if ($CreateHomeDirectories) {
                $userHome = Join-Path -Path $HomeShareRoot -ChildPath $sam
                if (-not (Test-Path -Path $userHome)) {
                    New-Item -ItemType Directory -Path $userHome -Force | Out-Null

                    # Configure NTFS ACLs: Disable inheritance, grant User & Admins FullControl
                    $acl = Get-Acl -Path $userHome
                    $acl.SetAccessRuleProtection($true, $false) # Break inheritance, remove copied rules

                    # Rule 1: Grant User Full Control
                    $userSid = (New-Object System.Security.Principal.NTAccount("$($domainObj.NetBIOSName)\$sam"))
                    $userRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                        $userSid, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
                    )
                    $acl.AddAccessRule($userRule)

                    # Rule 2: Grant Domain Admins Full Control
                    $adminSid = (New-Object System.Security.Principal.NTAccount("$($domainObj.NetBIOSName)\Domain Admins"))
                    $adminRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                        $adminSid, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
                    )
                    $acl.AddAccessRule($adminRule)

                    # Rule 3: Grant SYSTEM Full Control
                    $systemSid = (New-Object System.Security.Principal.NTAccount("NT AUTHORITY\SYSTEM"))
                    $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                        $systemSid, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
                    )
                    $acl.AddAccessRule($systemRule)

                    Set-Acl -Path $userHome -AclObject $acl -ErrorAction SilentlyContinue
                }
            }

            Write-Host " [+] Provisioned: $sam ($dept - $title)" -ForegroundColor Green
            $createdCount++
        } catch {
            Write-Error " [!] Failed provisioning user '$sam': $_"
            $errorCount++
        }
    }
}

Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host " [AGL LAB] Provisioning Summary                                 " -ForegroundColor Cyan
Write-Host " Successfully Created : $createdCount" -ForegroundColor Green
Write-Host " Skipped (Existing)   : $skippedCount" -ForegroundColor DarkGray
Write-Host " Errors Encountered   : $errorCount" -ForegroundColor Red
Write-Host "=================================================================" -ForegroundColor Cyan
