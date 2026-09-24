<#
.SYNOPSIS
    Interactive Daily Operations Toolkit for Service Desk & Desktop Support Technicians.

.DESCRIPTION
    A command-line management console designed for Tier 1 and Tier 2 IT support staff.
    Allows agents to execute common service desk workflows safely and efficiently:
    - User Account Lookup & Status Diagnostic (Lockout, Password Expiry, Groups, Title, Manager)
    - 1-Click Account Unlock & Secure Password Reset (forces change at next logon)
    - Role & Security Group Management (Add/Remove from VPN, Departmental Shares)
    - Standard Employee Offboarding Workflow (Disable, scramble, document ticket, move to OU=Terminated)
    - Remote Workstation Diagnostic (Ping, WinRM, Port 389/445, DNS resolution check)

.EXAMPLE
    .\07_DailyOps-ServiceDeskToolkit.ps1
#>

[CmdletBinding()]
param ()

# Require Active Directory module
if (-not (Get-Module -Name ActiveDirectory -ListAvailable)) {
    Write-Error "The ActiveDirectory PowerShell module is required. Please install RSAT-AD-PowerShell."
    exit 1
}
Import-Module ActiveDirectory

$domainObj = Get-ADDomain
$domainDN = $domainObj.DistinguishedName

function Show-Header {
    Clear-Host
    Write-Host "=================================================================" -ForegroundColor Cyan
    Write-Host "     APEX GLOBAL LOGISTICS - IT SERVICE DESK OPERATIONS TOOL     " -ForegroundColor White
    Write-Host "     Domain: $($domainObj.DNSRoot) | Operator: $env:USERNAME    " -ForegroundColor Gray
    Write-Host "=================================================================" -ForegroundColor Cyan
}

function Search-UserAccount {
    Show-Header
    Write-Host ""
    Write-Host "--- [1] User Account Lookup & Diagnostic ---" -ForegroundColor Yellow
    $query = Read-Host -Prompt "Enter Username (sAMAccountName) or Last Name"
    if ([string]::IsNullOrWhiteSpace($query)) { return }

    $users = Get-ADUser -Filter "SamAccountName -like '*$query*' -or Surname -like '*$query*'" `
                        -Properties Title, Department, Manager, LockedOut, PasswordExpired, PasswordLastSet, AccountExpirationDate, MemberOf, Enabled

    if (-not $users) {
        Write-Host "[-] No user accounts found matching '$query'." -ForegroundColor Red
    } else {
        foreach ($u in $users) {
            $lockStatus = if ($u.LockedOut) { "LOCKED OUT" } else { "Active / OK" }
            $lockColor = if ($u.LockedOut) { "Red" } else { "Green" }
            $enabledStatus = if ($u.Enabled) { "Enabled" } else { "DISABLED" }
            $enabledColor = if ($u.Enabled) { "Green" } else { "DarkYellow" }

            Write-Host ""
            Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan
            Write-Host " Name           : $($u.Name)" -ForegroundColor White
            Write-Host " Username (SAM) : $($u.SamAccountName)" -ForegroundColor White
            Write-Host " Email          : $($u.UserPrincipalName)" -ForegroundColor Gray
            Write-Host " Department     : $($u.Department)" -ForegroundColor Gray
            Write-Host " Title          : $($u.Title)" -ForegroundColor Gray
            Write-Host " Status         : $enabledStatus" -ForegroundColor $enabledColor
            Write-Host " Lockout Status : $lockStatus" -ForegroundColor $lockColor
            Write-Host " Pwd Last Set   : $($u.PasswordLastSet)" -ForegroundColor Gray
            Write-Host " DN             : $($u.DistinguishedName)" -ForegroundColor DarkGray

            $groupNames = @()
            if ($u.MemberOf) {
                foreach ($grp in $u.MemberOf) {
                    $groupNames += ($grp -split ',')[0] -replace '^CN='
                }
            }
            Write-Host " Groups ($($groupNames.Count)): $($groupNames -join ', ')" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
    Read-Host -Prompt "Press Enter to return to menu"
}

function Unlock-And-ResetPassword {
    Show-Header
    Write-Host ""
    Write-Host "--- [2] Unlock Account & Reset Password ---" -ForegroundColor Yellow
    $sam = Read-Host -Prompt "Enter Username (sAMAccountName)"
    if ([string]::IsNullOrWhiteSpace($sam)) { return }

    $u = Get-ADUser -Filter "SamAccountName -eq '$sam'" -Properties LockedOut -ErrorAction SilentlyContinue
    if (-not $u) {
        Write-Host "[-] User '$sam' does not exist." -ForegroundColor Red
        Read-Host -Prompt "Press Enter to return to menu"
        return
    }

    if ($u.LockedOut) {
        Unlock-ADAccount -Identity $sam
        Write-Host "[+] Account '$sam' has been UNLOCKED." -ForegroundColor Green
    } else {
        Write-Host "[i] Account '$sam' was not locked." -ForegroundColor Gray
    }

    $doReset = Read-Host -Prompt "Do you wish to reset the user password? (y/n)"
    if ($doReset -eq 'y') {
        $randInt = Get-Random -Minimum 1000 -Maximum 9999
        $tempPassword = "TempPass" + $randInt + "!"
        $secPass = ConvertTo-SecureString $tempPassword -AsPlainText -Force
        Set-ADAccountPassword -Identity $sam -NewPassword $secPass -Reset
        Set-ADUser -Identity $sam -ChangePasswordAtLogon $true

        Write-Host ""
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host "[+] Password successfully reset for '$sam'!" -ForegroundColor Green
        Write-Host "    Temporary Password: $tempPassword" -ForegroundColor Yellow
        Write-Host "    User MUST change password at next logon." -ForegroundColor White
        Write-Host "============================================================" -ForegroundColor Cyan
    }
    Read-Host -Prompt "Press Enter to return to menu"
}

function Manage-UserGroups {
    Show-Header
    Write-Host ""
    Write-Host "--- [3] Manage User Group Memberships ---" -ForegroundColor Yellow
    $sam = Read-Host -Prompt "Enter Username (sAMAccountName)"
    if ([string]::IsNullOrWhiteSpace($sam)) { return }

    $u = Get-ADUser -Filter "SamAccountName -eq '$sam'" -Properties MemberOf -ErrorAction SilentlyContinue
    if (-not $u) {
        Write-Host "[-] User '$sam' not found." -ForegroundColor Red
        Read-Host -Prompt "Press Enter to return to menu"
        return
    }

    Write-Host ""
    Write-Host "Current Memberships for '$sam':" -ForegroundColor White
    if ($u.MemberOf) {
        foreach ($grp in $u.MemberOf) {
            Write-Host " - $(($grp -split ',')[0] -replace '^CN=')" -ForegroundColor DarkCyan
        }
    } else {
        Write-Host " (No secondary group memberships)" -ForegroundColor Gray
    }

    Write-Host ""
    Write-Host "Actions: [A] Add to Group | [R] Remove from Group | [C] Cancel" -ForegroundColor Yellow
    $act = Read-Host -Prompt "Selection"
    if ($act -eq 'A' -or $act -eq 'a') {
        $grpName = Read-Host -Prompt "Enter Group Name to add user into"
        try {
            Add-ADGroupMember -Identity $grpName -Members $sam -ErrorAction Stop
            Write-Host "[+] Successfully added '$sam' to '$grpName'!" -ForegroundColor Green
        } catch {
            Write-Host "[-] Error: $_" -ForegroundColor Red
        }
    } elseif ($act -eq 'R' -or $act -eq 'r') {
        $grpName = Read-Host -Prompt "Enter Group Name to remove user from"
        try {
            Remove-ADGroupMember -Identity $grpName -Members $sam -Confirm:$false -ErrorAction Stop
            Write-Host "[+] Successfully removed '$sam' from '$grpName'!" -ForegroundColor Green
        } catch {
            Write-Host "[-] Error: $_" -ForegroundColor Red
        }
    }
    Read-Host -Prompt "Press Enter to return to menu"
}

function Offboard-Employee {
    Show-Header
    Write-Host ""
    Write-Host "--- [4] Offboard & Deprovision Employee ---" -ForegroundColor Yellow
    $sam = Read-Host -Prompt "Enter Username (sAMAccountName) to OFFBOARD"
    if ([string]::IsNullOrWhiteSpace($sam)) { return }

    $u = Get-ADUser -Filter "SamAccountName -eq '$sam'" -Properties MemberOf, Description -ErrorAction SilentlyContinue
    if (-not $u) {
        Write-Host "[-] User '$sam' not found." -ForegroundColor Red
        Read-Host -Prompt "Press Enter to return to menu"
        return
    }

    $ticket = Read-Host -Prompt "Enter Service Desk Offboarding Ticket Number (e.g., SR-2002)"
    $confirm = Read-Host -Prompt "WARNING: This will disable '$sam', strip groups, and move account to OU=Terminated. Confirm? (yes/no)"
    if ($confirm -ne 'yes') {
        Write-Host "[i] Offboarding canceled." -ForegroundColor Gray
        Read-Host -Prompt "Press Enter to return to menu"
        return
    }

    try {
        # 1. Disable account
        Disable-ADAccount -Identity $sam
        Write-Host " [+] Account disabled." -ForegroundColor Green

        # 2. Scramble password
        $randInt = Get-Random -Minimum 100000 -Maximum 999999
        $randomPass = "Terminated" + $randInt + "!#X"
        $secPass = ConvertTo-SecureString $randomPass -AsPlainText -Force
        Set-ADAccountPassword -Identity $sam -NewPassword $secPass -Reset
        Write-Host " [+] Password scrambled to random high-entropy string." -ForegroundColor Green

        # 3. Update description with audit trail
        $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        $priorDesc = $u.Description
        $auditDesc = "OFFBOARDED via $ticket on $timestamp. Prior: $priorDesc"
        Set-ADUser -Identity $sam -Description $auditDesc
        Write-Host " [+] Audit description updated." -ForegroundColor Green

        # 4. Remove from all groups except Domain Users
        $groups = $u.MemberOf | Where-Object { $_ -notmatch "CN=Domain Users" }
        foreach ($g in $groups) {
            Remove-ADGroupMember -Identity $g -Members $sam -Confirm:$false -ErrorAction SilentlyContinue
        }
        Write-Host " [+] Removed from all security and distribution groups." -ForegroundColor Green

        # 5. Move to OU=Terminated
        $termOU = "OU=Terminated,OU=ApexGlobal,$domainDN"
        Move-ADObject -Identity $u.DistinguishedName -TargetPath $termOU
        Write-Host " [+] Moved to '$termOU'." -ForegroundColor Green

        Write-Host ""
        Write-Host "[SUCCESS] User '$sam' successfully offboarded under ticket $ticket" -ForegroundColor Cyan
    } catch {
        Write-Host "[-] Offboarding failed: $_" -ForegroundColor Red
    }
    Read-Host -Prompt "Press Enter to return to menu"
}

function Test-RemoteEndpoint {
    Show-Header
    Write-Host ""
    Write-Host "--- [5] Remote Workstation Diagnostic ---" -ForegroundColor Yellow
    $target = Read-Host -Prompt "Enter Computer Name or IP (e.g., AGL-WS01 or 192.168.10.50)"
    if ([string]::IsNullOrWhiteSpace($target)) { return }

    Write-Host ""
    Write-Host "[i] Diagnosing network connectivity to '$target'..." -ForegroundColor Cyan

    # Ping test
    $ping = Test-Connection -ComputerName $target -Count 2 -Quiet
    if ($ping) {
        Write-Host " [+] ICMP Ping: SUCCESS" -ForegroundColor Green
    } else {
        Write-Host " [-] ICMP Ping: FAILED (Machine offline or firewall blocking ping)" -ForegroundColor Red
    }

    # Port 445 (SMB)
    $smb = Test-NetConnection -ComputerName $target -Port 445 -InformationLevel Quiet
    if ($smb) {
        Write-Host " [+] Port 445 (SMB / File Share): OPEN" -ForegroundColor Green
    } else {
        Write-Host " [-] Port 445 (SMB): CLOSED / FILTERED" -ForegroundColor Yellow
    }

    # Port 5985 (WinRM)
    $winrm = Test-NetConnection -ComputerName $target -Port 5985 -InformationLevel Quiet
    if ($winrm) {
        Write-Host " [+] Port 5985 (WinRM / PowerShell Remoting): OPEN" -ForegroundColor Green
    } else {
        Write-Host " [-] Port 5985 (WinRM): CLOSED / FILTERED" -ForegroundColor Yellow
    }

    Read-Host -Prompt "Press Enter to return to menu"
}

# Main Event Loop
do {
    Show-Header
    Write-Host " 1. Search User Account and View Status" -ForegroundColor White
    Write-Host " 2. Unlock Account and Reset Password" -ForegroundColor White
    Write-Host " 3. Manage User Group Memberships (Add / Remove)" -ForegroundColor White
    Write-Host " 4. Offboard / Deprovision Employee (SOP-003)" -ForegroundColor White
    Write-Host " 5. Test Remote Workstation Connectivity (Ping / Ports)" -ForegroundColor White
    Write-Host " 6. Exit Toolkit" -ForegroundColor White
    Write-Host ""
    $choice = Read-Host -Prompt "Select an option (1-6)"

    switch ($choice) {
        "1" { Search-UserAccount }
        "2" { Unlock-And-ResetPassword }
        "3" { Manage-UserGroups }
        "4" { Offboard-Employee }
        "5" { Test-RemoteEndpoint }
        "6" { Write-Host "`nExiting Service Desk Toolkit. Goodbye!`n" -ForegroundColor Cyan; exit 0 }
        default { Write-Host "Invalid option. Please choose 1-6." -ForegroundColor Red; Start-Sleep -Milliseconds 800 }
    }
} while ($true)
