# ============================================================
# ORSUBANK AD RED TEAM LAB - KERBEROASTING VULNERABILITY SCRIPT
# ============================================================
# Script Name: Enable-Kerberoasting.ps1
# Purpose: Creates vulnerable service accounts with SPNs for Kerberoasting practice
# Location: Run on DC01 (Domain Controller)
# Reboot Required: No
# 
# WHAT THIS SCRIPT DOES:
# - Creates 4 service accounts with weak passwords
# - Assigns Service Principal Names (SPNs) to each account
# - SPNs allow attackers to request TGS tickets
# - Weak passwords can be cracked offline with Hashcat
#
# WHY THIS IS VULNERABLE:
# In real environments, service accounts often have:
# - Weak passwords (easier to remember)
# - Never-expiring passwords
# - SPNs that allow Kerberoasting
# This script simulates these real-world misconfigurations.
# ============================================================

# Verify running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[!] ERROR: Run this script as Administrator!" -ForegroundColor Red
    exit 1
}

# Verify running on Domain Controller
if (-NOT (Get-WmiObject Win32_ComputerSystem).PartOfDomain) {
    Write-Host "[!] ERROR: This script must be run on a domain-joined machine!" -ForegroundColor Red
    exit 1
}

Write-Host @"

╔══════════════════════════════════════════════════════════════════╗
║         ORSUBANK - ENABLE KERBEROASTING VULNERABILITY            ║
║                                                                  ║
║  This script creates service accounts vulnerable to              ║
║  Kerberoasting attacks for Red Team training purposes.           ║
╚══════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# ============================================================
# SERVICE ACCOUNT DEFINITIONS
# ============================================================
# Each service account is defined with:
# - Name: What the account is called
# - SamAccountName: Login name
# - Password: Intentionally weak (for cracking practice)
# - SPN: Service Principal Name (required for Kerberoasting)
# - Description: What service this "runs"
# ============================================================

$ServiceAccounts = @(
    @{
        Name = "SQL Server Service"
        SamAccountName = "sqlservice"
        Password = "MYpassword123#"
        SPN = "MSSQLSvc/DC01.orsubank.local:1433"
        Description = "SQL Server Database Service Account"
    },
    @{
        Name = "HTTP Service"
        SamAccountName = "httpservice"
        Password = "Summer2024!"
        SPN = "HTTP/web.orsubank.local"
        Description = "Web Server Service Account"
    },
    @{
        Name = "IIS Application Pool"
        SamAccountName = "iisservice"
        Password = "P@ssw0rd"
        SPN = "HTTP/app.orsubank.local"
        Description = "IIS Application Pool Service Account"
    },
    @{
        Name = "Backup Service"
        SamAccountName = "backupservice"
        Password = "SQLAgent123!"
        SPN = "MSSQLSvc/DC01.orsubank.local:1434"
        Description = "Database Backup Service Account"
    }
)

# ============================================================
# CREATE SERVICE ACCOUNTS
# ============================================================

Write-Host "[*] Creating service accounts in ServiceAccounts OU..." -ForegroundColor Yellow

# Verify ServiceAccounts OU exists
$ServiceAccountsOU = "OU=ServiceAccounts,DC=orsubank,DC=local"
if (-NOT (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ServiceAccountsOU'" -ErrorAction SilentlyContinue)) {
    Write-Host "[+] Creating ServiceAccounts OU..." -ForegroundColor Yellow
    New-ADOrganizationalUnit -Name "ServiceAccounts" -Path "DC=orsubank,DC=local" -ProtectedFromAccidentalDeletion $false
}

foreach ($Account in $ServiceAccounts) {
    
    # Check if account already exists
    $ExistingAccount = Get-ADUser -Filter "SamAccountName -eq '$($Account.SamAccountName)'" -ErrorAction SilentlyContinue
    
    if ($ExistingAccount) {
        Write-Host "[!] Account $($Account.SamAccountName) already exists. Updating SPN..." -ForegroundColor Yellow
        
        # Update SPN if account exists
        Set-ADUser -Identity $Account.SamAccountName -ServicePrincipalNames @{Add=$Account.SPN}
    }
    else {
        # Create new service account
        $SecurePassword = ConvertTo-SecureString $Account.Password -AsPlainText -Force
        
        New-ADUser `
            -Name $Account.Name `
            -SamAccountName $Account.SamAccountName `
            -UserPrincipalName "$($Account.SamAccountName)@orsubank.local" `
            -Description $Account.Description `
            -Path $ServiceAccountsOU `
            -AccountPassword $SecurePassword `
            -Enabled $true `
            -PasswordNeverExpires $true `
            -CannotChangePassword $true `
            -ServicePrincipalNames $Account.SPN
        
        Write-Host "[+] Created: $($Account.SamAccountName)" -ForegroundColor Green
        Write-Host "    Password: $($Account.Password)" -ForegroundColor DarkGray
        Write-Host "    SPN: $($Account.SPN)" -ForegroundColor DarkGray
    }
}

# ============================================================
# VERIFICATION
# ============================================================

Write-Host "`n[*] Verifying Kerberoasting configuration..." -ForegroundColor Yellow

# List all accounts with SPNs (these are Kerberoastable)
Write-Host "`n[+] Accounts with SPNs (Kerberoastable targets):" -ForegroundColor Cyan
Get-ADUser -Filter {ServicePrincipalName -ne "$null"} -Properties ServicePrincipalName, Description | 
    Select-Object SamAccountName, ServicePrincipalName, Description |
    Format-Table -AutoSize

# Count of Kerberoastable accounts
$KerberoastableCount = (Get-ADUser -Filter {ServicePrincipalName -ne "$null"}).Count
Write-Host "[+] Total Kerberoastable accounts: $KerberoastableCount" -ForegroundColor Green

# ============================================================
# ATTACK INSTRUCTIONS
# ============================================================

Write-Host @"

╔══════════════════════════════════════════════════════════════════╗
║                    KERBEROASTING READY!                          ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  From your Kali box, use these credentials to test:              ║
║                                                                  ║
║  Service Account     Password          SPN                       ║
║  ─────────────────────────────────────────────────────────────   ║
║  sqlservice          MYpassword123#    MSSQLSvc/DC01...:1433     ║
║  httpservice         Summer2024!       HTTP/web.orsubank.local   ║
║  iisservice          P@ssw0rd          HTTP/app.orsubank.local   ║
║  backupservice       SQLAgent123!      MSSQLSvc/DC01...:1434     ║
║                                                                  ║
║  ATTACK COMMAND (Sliver):                                        ║
║  > execute-assembly Rubeus.exe kerberoast /nowrap               ║
║                                                                  ║
║  CRACK WITH HASHCAT:                                             ║
║  $ hashcat -m 13100 hashes.txt rockyou.txt                      ║
║                                                                  ║
║  Walkthrough: walkthroughs/02_kerberoasting.md                   ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Green

Write-Host "[✓] Kerberoasting vulnerability configured successfully!" -ForegroundColor Green
Write-Host "`n"
