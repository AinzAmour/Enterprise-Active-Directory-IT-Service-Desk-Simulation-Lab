<#
.SYNOPSIS
    Automates Least-Privilege Active Directory Delegation for the IT Service Desk.

.DESCRIPTION
    Applies granular Access Control Entries (ACEs) over the Departments Organizational Unit
    (OU=Departments,OU=ApexGlobal,DC=corp,DC=apexlogistics,DC=local) to authorize
    SEC-ServiceDesk-Tier1 to perform day-to-day identity tasks WITHOUT Domain Admin rights:
    - Reset user passwords.
    - Unlock user accounts (Write lockoutTime).
    - Modify standard contact attributes (telephoneNumber, title, office).
    - Manage memberships of designated departmental distribution/security groups.

.PARAMETER DomainDN
    Distinguished Name of the Active Directory domain root. Default: Dynamic.

.PARAMETER TargetOU
    Target OU over which permissions are delegated. Default: OU=Departments,OU=ApexGlobal,<DomainDN>

.PARAMETER DelegateGroup
    Identity of the Service Desk security group. Default: SEC-ServiceDesk-Tier1

.EXAMPLE
    .\05_Delegate-ServiceDeskPermissions.ps1
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [Parameter(Mandatory = $false)]
    [string]$DomainDN,

    [Parameter(Mandatory = $false)]
    [string]$TargetOU,

    [Parameter(Mandatory = $false)]
    [string]$DelegateGroup = "SEC-ServiceDesk-Tier1"
)

# Import Active Directory Module
if (-not (Get-Module -Name ActiveDirectory -ListAvailable)) {
    Write-Error "The ActiveDirectory PowerShell module is required. Please install RSAT-AD-PowerShell."
    exit 1
}
Import-Module ActiveDirectory

$domainObj = Get-ADDomain
if (-not $DomainDN) {
    $DomainDN = $domainObj.DistinguishedName
}
if (-not $TargetOU) {
    $TargetOU = "OU=Departments,OU=ApexGlobal,$DomainDN"
}

Write-Host "=================================================================" -ForegroundColor Cyan
Write-Host " [AGL LAB] Least-Privilege Service Desk ACL Delegation Engine    " -ForegroundColor Cyan
Write-Host " Target OU      : $TargetOU" -ForegroundColor Cyan
Write-Host " Delegate Group : $DelegateGroup" -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor Cyan

# Validate existence of Target OU and Group
$ouExists = Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$TargetOU'" -ErrorAction SilentlyContinue
if (-not $ouExists) {
    Write-Error "Target OU '$TargetOU' not found in Active Directory. Please run 02_Build-OUStructure.ps1 first."
    exit 1
}

$grpExists = Get-ADGroup -Filter "Name -eq '$DelegateGroup'" -ErrorAction SilentlyContinue
if (-not $grpExists) {
    Write-Error "Delegate Group '$DelegateGroup' not found in Active Directory. Please run 03_Create-SecurityGroups.ps1 first."
    exit 1
}

$netbios = $domainObj.NetBIOSName
$trustee = "$netbios\$DelegateGroup"

Write-Host "`n[1/3] Applying Password Reset and Account Unlock permissions..." -ForegroundColor Yellow

if ($PSCmdlet.ShouldProcess($TargetOU, "Apply Service Desk Delegation via dsacls")) {
    try {
        # Permission 1: Reset Password extended right on user child objects
        # /G <trustee>:CA;"Reset Password";user
        $cmdReset = "dsacls `"$TargetOU`" /I:S /G `"${trustee}:CA;Reset Password;user`""
        Write-Host "      Executing: $cmdReset" -ForegroundColor Gray
        cmd.exe /c $cmdReset | Out-Null

        # Permission 2: Read/Write lockoutTime property (Account Unlock)
        # /G <trustee>:RPWP;lockoutTime;user
        $cmdUnlock = "dsacls `"$TargetOU`" /I:S /G `"${trustee}:RPWP;lockoutTime;user`""
        Write-Host "      Executing: $cmdUnlock" -ForegroundColor Gray
        cmd.exe /c $cmdUnlock | Out-Null

        # Permission 3: Read/Write pwdLastSet property (Force change password at next logon)
        # /G <trustee>:RPWP;pwdLastSet;user
        $cmdPwdLastSet = "dsacls `"$TargetOU`" /I:S /G `"${trustee}:RPWP;pwdLastSet;user`""
        Write-Host "      Executing: $cmdPwdLastSet" -ForegroundColor Gray
        cmd.exe /c $cmdPwdLastSet | Out-Null

        Write-Host " [+] Password reset and account unlock delegation applied successfully." -ForegroundColor Green
    } catch {
        Write-Error "Failed applying password delegation: $_"
    }
}

Write-Host "`n[2/3] Delegating Contact Details Modification (Phone, Title, Office)..." -ForegroundColor Yellow
if ($PSCmdlet.ShouldProcess($TargetOU, "Delegate contact attributes")) {
    try {
        # Delegate Read/Write to telephoneNumber, title, physicalDeliveryOfficeName
        $cmdPhone = "dsacls `"$TargetOU`" /I:S /G `"${trustee}:RPWP;telephoneNumber;user`""
        $cmdTitle = "dsacls `"$TargetOU`" /I:S /G `"${trustee}:RPWP;title;user`""
        $cmdOffice = "dsacls `"$TargetOU`" /I:S /G `"${trustee}:RPWP;physicalDeliveryOfficeName;user`""

        cmd.exe /c $cmdPhone | Out-Null
        cmd.exe /c $cmdTitle | Out-Null
        cmd.exe /c $cmdOffice | Out-Null

        Write-Host " [+] Contact information attribute delegation applied successfully." -ForegroundColor Green
    } catch {
        Write-Error "Failed delegating contact attributes: $_"
    }
}

Write-Host "`n[3/3] Delegating Group Membership Management over Departmental Security Groups..." -ForegroundColor Yellow
$groupsOU = "OU=Security-Departmental,OU=Groups,OU=ApexGlobal,$DomainDN"
$groupsOUExists = Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$groupsOU'" -ErrorAction SilentlyContinue

if ($groupsOUExists) {
    if ($PSCmdlet.ShouldProcess($groupsOU, "Delegate group membership management")) {
        try {
            # Permission: Read/Write 'member' property on group objects
            # /G <trustee>:RPWP;member;group
            $cmdGroupMember = "dsacls `"$groupsOU`" /I:S /G `"${trustee}:RPWP;member;group`""
            Write-Host "      Executing: $cmdGroupMember" -ForegroundColor Gray
            cmd.exe /c $cmdGroupMember | Out-Null
            Write-Host " [+] Departmental group membership management delegated successfully." -ForegroundColor Green
        } catch {
            Write-Error "Failed delegating group management: $_"
        }
    }
} else {
    Write-Warning "Groups OU '$groupsOU' not found. Skipping group delegation."
}

Write-Host "`n=================================================================" -ForegroundColor Cyan
Write-Host " [AGL LAB] Service Desk ACL Delegation Complete                 " -ForegroundColor Cyan
Write-Host " Members of '$DelegateGroup' can now service users securely!" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Cyan
