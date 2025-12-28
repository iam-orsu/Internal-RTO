# ============================================================
# ORSUBANK AD RED TEAM LAB - MASTER MENU
# ============================================================
# Script Name: lab-menu.ps1
# Purpose: Interactive menu to enable all lab vulnerabilities
# Location: Run on DC01 (copy to workstations for local options)
# 
# USAGE:
# 1. Copy entire AD-RTO folder to target machine
# 2. Open PowerShell as Administrator
# 3. Run: .\lab-menu.ps1
# 4. Select options to enable vulnerabilities
# ============================================================

# Verify running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "`n[!] ERROR: Run this script as Administrator!" -ForegroundColor Red
    Write-Host "    Right-click PowerShell -> Run as Administrator`n" -ForegroundColor Yellow
    pause
    exit 1
}

# Get script location
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ServerScripts = Join-Path $ScriptPath "lab-config\server"
$WorkstationScripts = Join-Path $ScriptPath "lab-config\workstation"

function Show-Banner {
    Clear-Host
    Write-Host @"

╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║     ██████╗ ██████╗ ███████╗██╗   ██╗██████╗  █████╗ ███╗   ██╗██╗  ██╗     ║
║    ██╔═══██╗██╔══██╗██╔════╝██║   ██║██╔══██╗██╔══██╗████╗  ██║██║ ██╔╝     ║
║    ██║   ██║██████╔╝███████╗██║   ██║██████╔╝███████║██╔██╗ ██║█████╔╝      ║
║    ██║   ██║██╔══██╗╚════██║██║   ██║██╔══██╗██╔══██║██║╚██╗██║██╔═██╗      ║
║    ╚██████╔╝██║  ██║███████║╚██████╔╝██████╔╝██║  ██║██║ ╚████║██║  ██╗     ║
║     ╚═════╝ ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝     ║
║                                                                              ║
║              AD RED TEAM LAB - VULNERABILITY CONFIGURATION                   ║
║                                                                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Domain: orsubank.local    |    Machine: $($env:COMPUTERNAME.PadRight(10))   |    $(Get-Date -Format "yyyy-MM-dd HH:mm")     ║
╚══════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan
}

function Show-Menu {
    Write-Host @"
┌──────────────────────────────────────────────────────────────────────────────┐
│                         VULNERABILITY OPTIONS                                │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  SERVER SCRIPTS (Run on DC01):                                               │
│  ─────────────────────────────                                               │
│  [1] Enable Kerberoasting       - Create service accounts with SPNs          │
│  [2] Enable AS-REP Roasting     - Disable pre-authentication for users       │
│  [3] Enable Credential Exposure - WDigest + disable LSA Protection           │
│  [4] Enable Excessive Privileges - ACL abuse scenarios (GenericAll, etc.)    │
│  [5] Enable Domain Admin Path   - Create paths to DA (coming soon)           │
│  [6] Enable Delegation Vulns    - Unconstrained/constrained delegation       │
│                                                                              │
│  WORKSTATION SCRIPTS (Run on WS01/WS02):                                     │
│  ────────────────────────────────────────                                    │
│  [7] Enable Local Priv Esc      - Unquoted paths, AlwaysInstallElevated      │
│  [8] Enable Lateral Movement    - PSRemoting, WMI, RDP, admin shares         │
│  [9] Enable Persistence         - Scheduled tasks, registry keys             │
│                                                                              │
│  QUICK OPTIONS:                                                              │
│  ──────────────                                                              │
│  [A] Enable ALL Server Vulns    - Run options 1-6 (recommended for DC01)     │
│  [B] Enable ALL Workstation     - Run options 7-9 (run on WS01 & WS02)       │
│                                                                              │
│  OTHER:                                                                      │
│  ──────                                                                      │
│  [V] View Current Status        - Check which vulnerabilities are enabled    │
│  [H] Help                       - Show attack progression guide              │
│  [Q] Quit                       - Exit this menu                             │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘

"@ -ForegroundColor White
}

function Run-Script {
    param (
        [string]$ScriptName,
        [string]$ScriptFolder
    )
    
    $FullPath = Join-Path $ScriptFolder $ScriptName
    
    if (Test-Path $FullPath) {
        Write-Host "`n[*] Running $ScriptName..." -ForegroundColor Yellow
        Write-Host "─" * 60 -ForegroundColor DarkGray
        & $FullPath
        Write-Host "─" * 60 -ForegroundColor DarkGray
    } else {
        Write-Host "`n[!] Script not found: $FullPath" -ForegroundColor Red
        Write-Host "    Make sure the script exists in the lab-config folder." -ForegroundColor Yellow
    }
}

function Show-Status {
    Write-Host "`n[*] Checking vulnerability status..." -ForegroundColor Yellow
    Write-Host "─" * 60 -ForegroundColor DarkGray
    
    # Check Kerberoasting (SPNs)
    $SPNCount = (Get-ADUser -Filter {ServicePrincipalName -ne "$null"} -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host "  Kerberoasting (Service Accounts with SPNs): " -NoNewline
    if ($SPNCount -gt 0) { Write-Host "$SPNCount accounts" -ForegroundColor Green } else { Write-Host "Not configured" -ForegroundColor Red }
    
    # Check AS-REP Roasting
    $ASREPCount = (Get-ADUser -Filter {DoesNotRequirePreAuth -eq $true} -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host "  AS-REP Roasting (Pre-auth disabled): " -NoNewline
    if ($ASREPCount -gt 0) { Write-Host "$ASREPCount users" -ForegroundColor Green } else { Write-Host "Not configured" -ForegroundColor Red }
    
    # Check WDigest
    $WDigest = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" -Name "UseLogonCredential" -ErrorAction SilentlyContinue).UseLogonCredential
    Write-Host "  WDigest (Cleartext passwords): " -NoNewline
    if ($WDigest -eq 1) { Write-Host "ENABLED (Vulnerable)" -ForegroundColor Green } else { Write-Host "Disabled" -ForegroundColor Red }
    
    # Check LSA Protection
    $LSA = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -ErrorAction SilentlyContinue).RunAsPPL
    Write-Host "  LSA Protection: " -NoNewline
    if ($LSA -eq 0) { Write-Host "DISABLED (Vulnerable)" -ForegroundColor Green } else { Write-Host "Enabled (Protected)" -ForegroundColor Red }
    
    # Check WinRM
    $WinRM = (Get-Service WinRM -ErrorAction SilentlyContinue).Status
    Write-Host "  PSRemoting (WinRM): " -NoNewline
    if ($WinRM -eq "Running") { Write-Host "Running" -ForegroundColor Green } else { Write-Host "Not running" -ForegroundColor Red }
    
    # Check RDP
    $RDP = (Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -ErrorAction SilentlyContinue).fDenyTSConnections
    Write-Host "  RDP: " -NoNewline
    if ($RDP -eq 0) { Write-Host "Enabled" -ForegroundColor Green } else { Write-Host "Disabled" -ForegroundColor Red }
    
    Write-Host "─" * 60 -ForegroundColor DarkGray
}

function Show-Help {
    Write-Host @"

╔══════════════════════════════════════════════════════════════════════════════╗
║                        ATTACK PROGRESSION GUIDE                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  RECOMMENDED ATTACK ORDER:                                                   ║
║  ─────────────────────────                                                   ║
║                                                                              ║
║  1. Initial Access         → Start Sliver C2, get foothold on WS01          ║
║     Walkthrough: 00_initial_access_sliver_setup.md                           ║
║                                                                              ║
║  2. Enumeration           → Run BloodHound, map attack paths                 ║
║     Walkthrough: 01_domain_enumeration_bloodhound.md                         ║
║                                                                              ║
║  3. Kerberoasting         → Crack service account passwords                  ║
║     Enable: Option [1]                                                       ║
║     Walkthrough: 02_kerberoasting.md                                         ║
║                                                                              ║
║  4. Credential Dumping    → Dump LSASS for passwords/hashes                  ║
║     Enable: Option [3]                                                       ║
║     Walkthrough: 04_credential_dumping.md                                    ║
║                                                                              ║
║  5. Pass-the-Hash         → Move to WS02 with stolen hashes                  ║
║     Enable: Option [8] on both WS01 and WS02                                 ║
║     Walkthrough: 07_pass_the_hash.md                                         ║
║                                                                              ║
║  6. ACL Abuse             → Escalate to Domain Admin via permissions         ║
║     Enable: Option [4]                                                       ║
║     Walkthrough: 06_acl_abuse.md                                             ║
║                                                                              ║
║  7. Golden Ticket         → Create persistent domain-wide access             ║
║     Walkthrough: 08_golden_ticket.md                                         ║
║                                                                              ║
║  TIP: Run Option [A] on DC01 and Option [B] on WS01/WS02 for full lab!      ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor White
}

# ============================================================
# MAIN MENU LOOP
# ============================================================

do {
    Show-Banner
    Show-Menu
    
    $Choice = Read-Host "Select option"
    
    switch ($Choice.ToUpper()) {
        "1" { Run-Script "Enable-Kerberoasting.ps1" $ServerScripts }
        "2" { Run-Script "Enable-ASREPRoasting.ps1" $ServerScripts }
        "3" { Run-Script "Enable-CredentialExposure.ps1" $ServerScripts }
        "4" { Run-Script "Enable-ExcessivePrivileges.ps1" $ServerScripts }
        "5" { Run-Script "Enable-DomainAdminPath.ps1" $ServerScripts }
        "6" { Run-Script "Enable-DelegationVulnerabilities.ps1" $ServerScripts }
        "7" { Run-Script "Enable-LocalPrivEscVulnerabilities.ps1" $WorkstationScripts }
        "8" { Run-Script "Enable-LateralMovementPaths.ps1" $WorkstationScripts }
        "9" { Run-Script "Enable-PersistenceMechanisms.ps1" $WorkstationScripts }
        "A" {
            Write-Host "`n[*] Enabling ALL server vulnerabilities (1-6)..." -ForegroundColor Cyan
            Run-Script "Enable-Kerberoasting.ps1" $ServerScripts
            Run-Script "Enable-ASREPRoasting.ps1" $ServerScripts
            Run-Script "Enable-CredentialExposure.ps1" $ServerScripts
            Run-Script "Enable-ExcessivePrivileges.ps1" $ServerScripts
            Run-Script "Enable-DomainAdminPath.ps1" $ServerScripts
            Run-Script "Enable-DelegationVulnerabilities.ps1" $ServerScripts
            Write-Host "`n[✓] All 6 server vulnerabilities enabled!" -ForegroundColor Green
        }
        "B" {
            Write-Host "`n[*] Enabling ALL workstation vulnerabilities (7-9)..." -ForegroundColor Cyan
            Run-Script "Enable-LocalPrivEscVulnerabilities.ps1" $WorkstationScripts
            Run-Script "Enable-LateralMovementPaths.ps1" $WorkstationScripts
            Run-Script "Enable-PersistenceMechanisms.ps1" $WorkstationScripts
            Write-Host "`n[✓] All 3 workstation vulnerabilities enabled!" -ForegroundColor Green
        }
        "V" { Show-Status }
        "H" { Show-Help }
        "Q" { 
            Write-Host "`n[*] Goodbye! Happy hacking! 🎯`n" -ForegroundColor Cyan
            exit 
        }
        default { Write-Host "`n[!] Invalid option. Please try again." -ForegroundColor Red }
    }
    
    if ($Choice.ToUpper() -ne "Q") {
        Write-Host "`nPress Enter to continue..." -ForegroundColor DarkGray
        Read-Host
    }
    
} while ($Choice.ToUpper() -ne "Q")
