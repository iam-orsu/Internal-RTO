# ============================================================
# ORSUBANK AD RED TEAM LAB - AS-REP ROASTING VULNERABILITY SCRIPT
# ============================================================
# Script Name: Enable-ASREPRoasting.ps1
# Purpose: Disables Kerberos pre-authentication for specific users
# Location: Run on DC01 (Domain Controller)
# Reboot Required: No
#
# WHAT THIS SCRIPT DOES:
# - Disables Kerberos pre-authentication for 3 users
# - Sets weak passwords that can be cracked with rockyou.txt
# - Makes these accounts vulnerable to AS-REP Roasting
#
# WHY THIS IS VULNERABLE:
# Pre-authentication normally requires proving your password BEFORE
# getting a ticket. Disabling it means attackers can request encrypted
# data without knowing the password, then crack it offline.
#
# REAL-WORLD SCENARIO:
# This setting is sometimes disabled for:
# - Legacy application compatibility
# - Linux/Unix Kerberos clients that don't support pre-auth
# - Misconfiguration by administrators
# ============================================================

# Verify running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[!] ERROR: Run this script as Administrator!" -ForegroundColor Red
    exit 1
}

Write-Host @"

╔══════════════════════════════════════════════════════════════════╗
║        ORSUBANK - ENABLE AS-REP ROASTING VULNERABILITY           ║
║                                                                  ║
║  This script disables Kerberos pre-authentication for           ║
║  specific users, making them vulnerable to AS-REP Roasting.     ║
╚══════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# ============================================================
# VULNERABLE USER DEFINITIONS
# ============================================================
# Users who will have pre-authentication disabled:
# - These are existing banking staff users
# - Their passwords are intentionally weak
# - They can be AS-REP Roasted without authentication
# ============================================================

$VulnerableUsers = @(
    @{
        SamAccountName = "pranavi"
        Password = "Branch123!"
        Title = "Branch Manager"
    },
    @{
        SamAccountName = "harsha.vardhan"
        Password = "Customer2024!"
        Title = "Customer Service Manager"
    },
    @{
        SamAccountName = "kiran.kumar"
        Password = "Finance1!"
        Title = "Financial Analyst"
    }
)

# ============================================================
# DISABLE PRE-AUTHENTICATION
# ============================================================

Write-Host "[*] Disabling Kerberos pre-authentication for vulnerable users..." -ForegroundColor Yellow

foreach ($User in $VulnerableUsers) {
    
    # Check if user exists
    $ADUser = Get-ADUser -Filter "SamAccountName -eq '$($User.SamAccountName)'" -ErrorAction SilentlyContinue
    
    if (-NOT $ADUser) {
        Write-Host "[!] User $($User.SamAccountName) not found! Creating..." -ForegroundColor Yellow
        
        # Create user if doesn't exist
        $SecurePassword = ConvertTo-SecureString $User.Password -AsPlainText -Force
        New-ADUser `
            -Name $User.SamAccountName `
            -SamAccountName $User.SamAccountName `
            -UserPrincipalName "$($User.SamAccountName)@orsubank.local" `
            -Title $User.Title `
            -Path "OU=BankEmployees,DC=orsubank,DC=local" `
            -AccountPassword $SecurePassword `
            -Enabled $true `
            -PasswordNeverExpires $true
    }
    
    # Disable pre-authentication (DONT_REQ_PREAUTH flag)
    # UserAccountControl flag 4194304 = DONT_REQUIRE_PREAUTH
    Set-ADAccountControl -Identity $User.SamAccountName -DoesNotRequirePreAuth $true
    
    # Reset password to ensure it's the weak one we want
    $SecurePassword = ConvertTo-SecureString $User.Password -AsPlainText -Force
    Set-ADAccountPassword -Identity $User.SamAccountName -Reset -NewPassword $SecurePassword
    
    Write-Host "[+] Configured: $($User.SamAccountName)" -ForegroundColor Green
    Write-Host "    Password: $($User.Password)" -ForegroundColor DarkGray
    Write-Host "    Pre-auth: DISABLED (vulnerable)" -ForegroundColor Red
}

# ============================================================
# VERIFICATION
# ============================================================

Write-Host "`n[*] Verifying AS-REP Roasting configuration..." -ForegroundColor Yellow

# List all users with pre-auth disabled
Write-Host "`n[+] Users with pre-authentication DISABLED (AS-REP Roastable):" -ForegroundColor Cyan
Get-ADUser -Filter {DoesNotRequirePreAuth -eq $true} -Properties DoesNotRequirePreAuth, Title |
    Select-Object SamAccountName, Title, DoesNotRequirePreAuth |
    Format-Table -AutoSize

# Count of AS-REP Roastable accounts
$ASREPCount = (Get-ADUser -Filter {DoesNotRequirePreAuth -eq $true}).Count
Write-Host "[+] Total AS-REP Roastable accounts: $ASREPCount" -ForegroundColor Green

# ============================================================
# ATTACK INSTRUCTIONS
# ============================================================

Write-Host @"

╔══════════════════════════════════════════════════════════════════╗
║                   AS-REP ROASTING READY!                         ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  Vulnerable Users (Pre-auth disabled):                           ║
║                                                                  ║
║  Username          Password           Title                      ║
║  ─────────────────────────────────────────────────────────────   ║
║  pranavi           Branch123!         Branch Manager             ║
║  harsha.vardhan    Customer2024!      Customer Service Manager   ║
║  kiran.kumar       Finance1!          Financial Analyst          ║
║                                                                  ║
║  ATTACK COMMAND (Sliver):                                        ║
║  > execute-assembly Rubeus.exe asreproast /nowrap               ║
║                                                                  ║
║  CRACK WITH HASHCAT:                                             ║
║  $ hashcat -m 18200 asrep_hashes.txt rockyou.txt                ║
║                                                                  ║
║  NOTE: Mode 18200 = AS-REP (different from Kerberoast 13100)    ║
║                                                                  ║
║  Walkthrough: walkthroughs/03_asrep_roasting.md                  ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Green

Write-Host "[✓] AS-REP Roasting vulnerability configured successfully!" -ForegroundColor Green
Write-Host "`n"
