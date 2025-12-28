# ============================================================
# ORSUBANK AD RED TEAM LAB - LATERAL MOVEMENT PATHS
# ============================================================
# Script Name: Enable-LateralMovementPaths.ps1
# Purpose: Configures systems for lateral movement techniques
# Location: Run on WS01 and WS02 (Workstations)
# Reboot Required: No
#
# WHAT THIS SCRIPT DOES:
# - Enables PSRemoting (remote PowerShell)
# - Configures WMI access for remote execution
# - Enables RDP and adds users to Remote Desktop Users
# - Configures admin shares (C$, ADMIN$)
# - Disables remote UAC restrictions
#
# WHY THIS IS VULNERABLE:
# These settings allow attackers to move laterally using:
# - Pass-the-Hash with admin shares
# - PSRemoting with stolen credentials
# - WMI for remote command execution
# - RDP with compromised accounts
# ============================================================

# Verify running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[!] ERROR: Run this script as Administrator!" -ForegroundColor Red
    exit 1
}

Write-Host @"

╔══════════════════════════════════════════════════════════════════╗
║       ORSUBANK - ENABLE LATERAL MOVEMENT PATHS                   ║
║                                                                  ║
║  This script configures the system for lateral movement         ║
║  attacks: PSRemoting, WMI, RDP, and admin shares.               ║
╚══════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

$MachineName = $env:COMPUTERNAME
Write-Host "[*] Configuring lateral movement on: $MachineName" -ForegroundColor Yellow

# ============================================================
# 1. ENABLE PSREMOTING
# ============================================================
# PSRemoting allows remote PowerShell execution
# Uses WinRM service on ports 5985 (HTTP) and 5986 (HTTPS)
# ============================================================

Write-Host "`n[*] Enabling PSRemoting (WinRM)..." -ForegroundColor Yellow

# Enable PSRemoting silently
Enable-PSRemoting -Force -SkipNetworkProfileCheck | Out-Null

# Set WinRM service to automatic start
Set-Service -Name WinRM -StartupType Automatic
Start-Service -Name WinRM

# Allow all hosts to connect
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force

Write-Host "[+] PSRemoting enabled" -ForegroundColor Green
Write-Host "    Port: 5985 (HTTP), 5986 (HTTPS)" -ForegroundColor DarkGray

# ============================================================
# 2. CONFIGURE WMI ACCESS
# ============================================================
# WMI (Windows Management Instrumentation) allows remote management
# Used by attackers for stealthy command execution
# ============================================================

Write-Host "`n[*] Configuring WMI remote access..." -ForegroundColor Yellow

# Enable WMI through firewall
netsh advfirewall firewall set rule group="Windows Management Instrumentation (WMI)" new enable=yes | Out-Null

# Enable DCOM (required for WMI)
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Ole" -Name "EnableDCOM" -Value "Y" -Force

Write-Host "[+] WMI remote access enabled" -ForegroundColor Green

# ============================================================
# 3. ENABLE RDP
# ============================================================
# RDP (Remote Desktop Protocol) allows graphical remote access
# ============================================================

Write-Host "`n[*] Enabling Remote Desktop (RDP)..." -ForegroundColor Yellow

# Enable RDP
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0 -Force

# Enable RDP through firewall
Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue

# Allow RDP for domain users
$RDPGroup = [ADSI]"WinNT://./Remote Desktop Users,group"

# Add specific users to Remote Desktop Users
try {
    $RDPGroup.Add("WinNT://ORSUBANK/lakshmi.devi,user")
    $RDPGroup.Add("WinNT://ORSUBANK/ravi.teja,user")
    $RDPGroup.Add("WinNT://ORSUBANK/vamsi.krishna,user")
    Write-Host "[+] Added domain users to Remote Desktop Users group" -ForegroundColor Green
} catch {
    Write-Host "[!] Could not add some users (may already exist or not on domain)" -ForegroundColor Yellow
}

Write-Host "[+] RDP enabled on port 3389" -ForegroundColor Green

# ============================================================
# 4. CONFIGURE ADMIN SHARES
# ============================================================
# Admin shares (C$, ADMIN$) allow remote file access
# Required for Pass-the-Hash and PSExec-style attacks
# ============================================================

Write-Host "`n[*] Ensuring admin shares are accessible..." -ForegroundColor Yellow

# Enable admin shares (usually enabled by default, but ensure it)
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "AutoShareWks" -Value 1 -Type DWord -Force

# Restart LanmanServer to apply
Restart-Service -Name LanmanServer -Force

Write-Host "[+] Admin shares (C$, ADMIN$) accessible" -ForegroundColor Green

# ============================================================
# 5. DISABLE REMOTE UAC RESTRICTIONS
# ============================================================
# LocalAccountTokenFilterPolicy = 1 allows Pass-the-Hash
# Without this, non-RID 500 admin accounts are restricted
# ============================================================

Write-Host "`n[*] Disabling remote UAC restrictions (for Pass-the-Hash)..." -ForegroundColor Yellow

$UACPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
Set-ItemProperty -Path $UACPath -Name "LocalAccountTokenFilterPolicy" -Value 1 -Type DWord -Force

Write-Host "[+] LocalAccountTokenFilterPolicy = 1 (Pass-the-Hash enabled)" -ForegroundColor Green

# ============================================================
# 6. CREATE LOCAL ADMIN ACCOUNT FOR TESTING
# ============================================================
# Create a local admin that exists on multiple machines
# Same password = Pass-the-Hash works across machines!
# ============================================================

Write-Host "`n[*] Creating local admin account for lateral movement testing..." -ForegroundColor Yellow

$LocalAdminUser = "localadmin"
$LocalAdminPass = ConvertTo-SecureString "LocalAdmin123!" -AsPlainText -Force

# Check if user exists
$ExistingUser = Get-LocalUser -Name $LocalAdminUser -ErrorAction SilentlyContinue
if (-NOT $ExistingUser) {
    New-LocalUser -Name $LocalAdminUser -Password $LocalAdminPass -PasswordNeverExpires -Description "Local Admin for Lab Testing" | Out-Null
    Add-LocalGroupMember -Group "Administrators" -Member $LocalAdminUser
    Write-Host "[+] Created local admin: $LocalAdminUser / LocalAdmin123!" -ForegroundColor Green
} else {
    Write-Host "[!] Local admin '$LocalAdminUser' already exists" -ForegroundColor Yellow
}

# ============================================================
# VERIFICATION
# ============================================================

Write-Host "`n[*] Verifying configuration..." -ForegroundColor Yellow

# Check WinRM
$WinRMStatus = (Get-Service WinRM).Status
Write-Host "    WinRM Service: $WinRMStatus" -ForegroundColor $(if($WinRMStatus -eq "Running"){"Green"}else{"Red"})

# Check RDP
$RDPEnabled = (Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server").fDenyTSConnections
Write-Host "    RDP Enabled: $(if($RDPEnabled -eq 0){"Yes"}else{"No"})" -ForegroundColor $(if($RDPEnabled -eq 0){"Green"}else{"Red"})

# Check UAC Filter
$UACFilter = (Get-ItemProperty -Path $UACPath -Name "LocalAccountTokenFilterPolicy" -ErrorAction SilentlyContinue).LocalAccountTokenFilterPolicy
Write-Host "    Pass-the-Hash Ready: $(if($UACFilter -eq 1){"Yes"}else{"No"})" -ForegroundColor $(if($UACFilter -eq 1){"Green"}else{"Red"})

# ============================================================
# ATTACK INSTRUCTIONS
# ============================================================

Write-Host @"

╔══════════════════════════════════════════════════════════════════╗
║               LATERAL MOVEMENT PATHS READY!                       ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  LOCAL ADMIN ACCOUNT (same on WS01 and WS02):                    ║
║  Username: localadmin                                            ║
║  Password: LocalAdmin123!                                        ║
║                                                                  ║
║  ATTACK 1: Pass-the-Hash (Sliver)                                ║
║  ──────────────────────────────────────────                      ║
║  > make-token -u localadmin -d $MachineName -H <NTLM_HASH>       ║
║  > shell dir \\WS02\C$                                           ║
║                                                                  ║
║  ATTACK 2: PSRemoting                                            ║
║  ──────────────────────────────────────────                      ║
║  > execute powershell.exe -Command "Enter-PSSession WS02"        ║
║                                                                  ║
║  ATTACK 3: WMI Execution                                         ║
║  ──────────────────────────────────────────                      ║
║  > execute wmic.exe /node:WS02 process call create "cmd.exe"     ║
║                                                                  ║
║  ATTACK 4: RDP                                                   ║
║  ──────────────────────────────────────────                      ║
║  Connect to WS02:3389 with stolen credentials                    ║
║                                                                  ║
║  Walkthrough: walkthroughs/07_pass_the_hash.md                   ║
║               walkthroughs/07c_wmi_psremoting.md                 ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Green

Write-Host "[✓] Lateral movement paths configured on $MachineName!" -ForegroundColor Green
Write-Host "[!] Run this script on BOTH WS01 and WS02 for full lateral movement lab!" -ForegroundColor Yellow
Write-Host "`n"
