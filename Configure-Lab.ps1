# ============================================================
# ORSUBANK AD RED TEAM LAB V3 - HARDENED STAGED SETUP
# ============================================================
#
# Single script for DC01 and WS01.
# Run it, reboot when told, run it again. 3 runs per machine.
#
#   DC01: Run 1/3 -> reboot -> Run 2/3 -> auto-reboot -> Run 3/3 -> done
#   WS01: Run 1/3 -> reboot -> Run 2/3 -> reboot -> Run 3/3 -> done
#
# Usage:
#   .\Configure-Lab.ps1              (auto-detect role and stage)
#   .\Configure-Lab.ps1 -Role DC     (force DC mode)
#   .\Configure-Lab.ps1 -Role WS     (force WS mode)
#   .\Configure-Lab.ps1 -Reset       (wipe progress, start from Stage 1)
#
# All output is logged to C:\LabSetup\setup.log
# ============================================================

param(
    [ValidateSet("DC", "WS")]
    [string]$Role,
    [switch]$Reset
)

# ============================================================
# NETWORK CONFIG (change these if your network is different)
# ============================================================
$DCHostname     = "DC01"
$WSHostname     = "WS01"
$DCIPAddress    = "192.168.100.10"
$WSIPAddress    = "192.168.100.20"
$SubnetPrefix   = 24
$Gateway        = "192.168.100.1"
$DomainFQDN     = "orsubank.local"
$DomainNetBIOS  = "ORSUBANK"
$DSRMPassword   = "DSRMPass@2024!"

# ============================================================
# BOOTSTRAP: log dir, logging, execution policy check
# ============================================================
$labDir   = "C:\LabSetup"
$logFile  = "$labDir\setup.log"
$stageFile = "$labDir\stage.txt"

if (-not (Test-Path $labDir)) {
    New-Item -Path $labDir -ItemType Directory -Force | Out-Null
}

# Start transcript so everything is saved to a log file
try { Stop-Transcript -ErrorAction SilentlyContinue } catch {}
Start-Transcript -Path $logFile -Append -Force | Out-Null

Write-Host "[*] Logging to $logFile" -ForegroundColor Gray

# ============================================================
# EXECUTION POLICY CHECK
# ============================================================
$currentPolicy = Get-ExecutionPolicy -Scope Process
if ($currentPolicy -eq "Restricted") {
    Write-Host "[!] Execution policy is Restricted. Setting to Bypass for this session." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
}

# ============================================================
# ADMIN CHECK
# ============================================================
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] ERROR: Run this as Administrator." -ForegroundColor Red
    Write-Host "    Right-click PowerShell -> Run as Administrator" -ForegroundColor Yellow
    Stop-Transcript
    exit 1
}

# ============================================================
# HELPER FUNCTIONS
# ============================================================

function Wait-ForADReady {
    # After a DC promotion reboot, AD services take time to start.
    # This waits up to 120 seconds for the NTDS service and AD module.
    param([int]$MaxWaitSeconds = 120)

    Write-Host "    [*] Waiting for Active Directory services to be ready..." -ForegroundColor Gray
    $waited = 0
    while ($waited -lt $MaxWaitSeconds) {
        $ntds = Get-Service -Name NTDS -ErrorAction SilentlyContinue
        if ($ntds -and $ntds.Status -eq "Running") {
            try {
                Import-Module ActiveDirectory -ErrorAction Stop
                Get-ADDomain -ErrorAction Stop | Out-Null
                Write-Host "    [+] AD services are ready (waited ${waited}s)" -ForegroundColor Green
                return $true
            } catch {
                # AD module loaded but domain not responsive yet
            }
        }
        Start-Sleep -Seconds 5
        $waited += 5
        if (($waited % 15) -eq 0) {
            Write-Host "    [*] Still waiting... (${waited}s)" -ForegroundColor Gray
        }
    }
    Write-Host "    [!] AD services did not become ready in ${MaxWaitSeconds}s" -ForegroundColor Red
    return $false
}

function Test-ServiceExists {
    param([string]$ServiceName)
    return [bool](Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)
}

function New-LabService {
    # Creates a Windows service if it does not already exist.
    param(
        [string]$Name,
        [string]$BinPath,
        [string]$Description,
        [string]$StartType = "auto"
    )
    if (Test-ServiceExists $Name) {
        Write-Host "    [=] Service exists: $Name" -ForegroundColor DarkGray
        return
    }
    sc.exe create $Name binPath= $BinPath start= $StartType 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        sc.exe description $Name $Description 2>$null | Out-Null
        Write-Host "    [+] Service created: $Name" -ForegroundColor Green
    } else {
        Write-Host "    [!] Failed to create service: $Name (exit code $LASTEXITCODE)" -ForegroundColor Yellow
    }
}

function Test-ACEExists {
    # Check if a specific ACE already exists on an AD object.
    param(
        [string]$TargetDN,
        [System.Security.Principal.SecurityIdentifier]$IdentitySID,
        [string]$Rights
    )
    try {
        $acl = Get-Acl "AD:\$TargetDN"
        foreach ($ace in $acl.Access) {
            if ($ace.IdentityReference -match $IdentitySID.Value -and $ace.ActiveDirectoryRights -match $Rights) {
                return $true
            }
        }
    } catch {}
    return $false
}

function Set-LabACE {
    # Add an ACE to an AD object, skipping if it already exists.
    param(
        [string]$TargetDN,
        [System.DirectoryServices.ActiveDirectoryAccessRule]$Rule,
        [string]$Label
    )
    try {
        $acl = Get-Acl "AD:\$TargetDN"
        # Check for existing similar rule
        $exists = $false
        foreach ($ace in $acl.Access) {
            $sidMatch = $ace.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value -eq $Rule.IdentityReference.Value
            if ($sidMatch -and $ace.ActiveDirectoryRights -eq $Rule.ActiveDirectoryRights) {
                $exists = $true
                break
            }
        }
        if ($exists) {
            Write-Host "    [=] ACE exists: $Label" -ForegroundColor DarkGray
        } else {
            $acl.AddAccessRule($Rule)
            Set-Acl "AD:\$TargetDN" $acl
            Write-Host "    [+] $Label" -ForegroundColor Green
        }
    } catch {
        Write-Host "    [!] ACE error ($Label): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Disable-WindowsDefender {
    # Best-effort Defender disabling. Checks for Tamper Protection.
    Write-Host "[*] Disabling Windows Defender..." -ForegroundColor Yellow

    # Check Tamper Protection
    try {
        $tamper = (Get-MpComputerStatus -ErrorAction Stop).IsTamperProtected
        if ($tamper) {
            Write-Host ""
            Write-Host "    ============================================================" -ForegroundColor Red
            Write-Host "    TAMPER PROTECTION IS ON - MANUAL STEP NEEDED" -ForegroundColor Red
            Write-Host "    ============================================================" -ForegroundColor Red
            Write-Host ""
            Write-Host "    Tamper Protection blocks this script from disabling Defender." -ForegroundColor Yellow
            Write-Host "    Please do this manually:" -ForegroundColor Yellow
            Write-Host "      1. Open Windows Security (search 'Windows Security' in Start)" -ForegroundColor White
            Write-Host "      2. Click 'Virus & threat protection'" -ForegroundColor White
            Write-Host "      3. Click 'Manage settings' under 'Virus & threat protection settings'" -ForegroundColor White
            Write-Host "      4. Turn OFF 'Tamper Protection'" -ForegroundColor White
            Write-Host "      5. Turn OFF 'Real-time protection'" -ForegroundColor White
            Write-Host "      6. Come back here and press Enter to continue" -ForegroundColor White
            Write-Host ""
            Read-Host "    Press Enter after disabling Tamper Protection"
        }
    } catch {
        # Defender might not be installed (Server Core), continue
    }

    try {
        Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop
        Write-Host "    [+] Real-time protection disabled" -ForegroundColor Green
    } catch {
        Write-Host "    [!] Could not disable real-time protection: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    try {
        Set-MpPreference -DisableIOAVProtection $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableScriptScanning $true -ErrorAction SilentlyContinue
    } catch {}

    # Registry-level disable (works after reboot if Tamper Protection is off)
    $defenderPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
    if (-not (Test-Path $defenderPath)) { New-Item -Path $defenderPath -Force | Out-Null }
    Set-ItemProperty -Path $defenderPath -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force
    $rtpPath = "$defenderPath\Real-Time Protection"
    if (-not (Test-Path $rtpPath)) { New-Item -Path $rtpPath -Force | Out-Null }
    Set-ItemProperty -Path $rtpPath -Name "DisableRealtimeMonitoring" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $rtpPath -Name "DisableBehaviorMonitoring" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $rtpPath -Name "DisableIOAVProtection" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $rtpPath -Name "DisableScanOnRealtimeEnable" -Value 1 -Type DWord -Force
    Write-Host "    [+] Defender registry policies set (takes effect after reboot)" -ForegroundColor Green

    # Add exclusions
    try {
        Add-MpPreference -ExclusionPath "C:\Tools" -ErrorAction SilentlyContinue
        Add-MpPreference -ExclusionPath "C:\LabSetup" -ErrorAction SilentlyContinue
        Add-MpPreference -ExclusionPath "C:\Users" -ErrorAction SilentlyContinue
        Write-Host "    [+] Exclusions added: C:\Tools, C:\LabSetup, C:\Users" -ForegroundColor Green
    } catch {}
}

function Set-LabStaticIP {
    # Set a static IP on the first active adapter.
    param(
        [string]$IPAddress,
        [int]$Prefix,
        [string]$GatewayAddr,
        [string[]]$DNSServers
    )

    Write-Host "`n[*] Configuring network..." -ForegroundColor Yellow

    # Check if running via RDP (IP change would kill the session)
    $rdpSession = Get-CimInstance Win32_LogonSession | Where-Object { $_.LogonType -eq 10 }
    if ($rdpSession) {
        Write-Host "    [!] WARNING: You appear to be connected via RDP." -ForegroundColor Red
        Write-Host "    [!] Changing the IP will disconnect you." -ForegroundColor Red
        Write-Host "    [!] Connect using the VM console (VMware/Hyper-V) instead." -ForegroundColor Red
        $reply = Read-Host "    Continue anyway? (yes/no)"
        if ($reply -ne "yes") {
            Write-Host "    [*] Skipping IP change. Set the IP manually and re-run." -ForegroundColor Yellow
            return
        }
    }

    $adapter = Get-NetAdapter | Where-Object {
        $_.Status -eq "Up" -and
        $_.InterfaceDescription -notlike "*Loopback*" -and
        $_.InterfaceDescription -notlike "*Bluetooth*"
    } | Select-Object -First 1

    if (-not $adapter) {
        Write-Host "    [!] No active network adapter found." -ForegroundColor Red
        Write-Host "    [!] Available adapters:" -ForegroundColor Yellow
        Get-NetAdapter | Format-Table Name, Status, InterfaceDescription -AutoSize
        Write-Host "    [!] Connect the host-only network adapter and try again." -ForegroundColor Yellow
        Stop-Transcript
        exit 1
    }
    Write-Host "    [*] Using adapter: $($adapter.Name) ($($adapter.InterfaceDescription))" -ForegroundColor Gray

    # Get current IPs, filter out APIPA (169.254.x.x) and link-local
    $currentIPs = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike "169.254.*" }
    $hasCorrectIP = $currentIPs | Where-Object { $_.IPAddress -eq $IPAddress }

    if (-not $hasCorrectIP) {
        # Save stage file BEFORE changing IP (in case it kills the session)
        Write-Host "    [*] Setting IP to $IPAddress/$Prefix..." -ForegroundColor Gray

        # Remove existing IPv4 addresses (not APIPA)
        $currentIPs | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
        Remove-NetRoute -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue

        try {
            New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $IPAddress `
                -PrefixLength $Prefix -DefaultGateway $GatewayAddr -ErrorAction Stop | Out-Null
            Write-Host "    [+] IP set to $IPAddress/$Prefix (gateway: $GatewayAddr)" -ForegroundColor Green
        } catch {
            # Gateway might not exist in host-only network, try without it
            try {
                New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $IPAddress `
                    -PrefixLength $Prefix -ErrorAction Stop | Out-Null
                Write-Host "    [+] IP set to $IPAddress/$Prefix (no gateway)" -ForegroundColor Green
            } catch {
                Write-Host "    [!] Failed to set IP: $($_.Exception.Message)" -ForegroundColor Red
                Stop-Transcript
                exit 1
            }
        }
    } else {
        Write-Host "    [=] IP already set to $IPAddress" -ForegroundColor DarkGray
    }

    # Set DNS
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $DNSServers
    Write-Host "    [+] DNS set to: $($DNSServers -join ', ')" -ForegroundColor Green
}

# ============================================================
# ROLE AUTO-DETECTION
# ============================================================
if (-not $Role) {
    $domainRole = (Get-CimInstance Win32_ComputerSystem).DomainRole
    if ($domainRole -in @(4, 5)) {
        $Role = "DC"
    } else {
        $Role = "WS"
    }
    Write-Host "[*] Auto-detected role: $Role" -ForegroundColor Cyan
}

# ============================================================
# STAGE TRACKING (safe parsing)
# ============================================================
if ($Reset) {
    Remove-Item $stageFile -Force -ErrorAction SilentlyContinue
    Write-Host "[*] Progress reset. Starting from Stage 1." -ForegroundColor Yellow
}

$stage = 1
if (Test-Path $stageFile) {
    $stageRaw = (Get-Content $stageFile -Raw).Trim()
    if ($stageRaw -eq "done") {
        $stage = "done"
    } elseif ($stageRaw -match '^\d+$') {
        $stage = [int]$stageRaw
    } else {
        Write-Host "[!] Stage file is corrupted ('$stageRaw'). Resetting to Stage 1." -ForegroundColor Yellow
        $stage = 1
    }
}

# ============================================================
# BANNER
# ============================================================
Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host "   ORSUBANK AD RED TEAM LAB V3" -ForegroundColor Cyan
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host "  Machine:  $($env:COMPUTERNAME)" -ForegroundColor Gray
Write-Host "  Role:     $Role" -ForegroundColor Gray
Write-Host "  Stage:    $stage of 3" -ForegroundColor Gray
Write-Host "  Log:      $logFile" -ForegroundColor Gray
Write-Host "  Time:     $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host ""


# ############################################################
#                     DC STAGES
# ############################################################

if ($Role -eq "DC") {

    # ========================================================
    # DC STAGE 1: Hostname, IP, AD DS feature, Defender
    # ========================================================
    if ($stage -eq 1) {
        Write-Host "[DC Stage 1/3] Base system setup..." -ForegroundColor Yellow
        Write-Host ""

        Disable-WindowsDefender

        # Save stage early (before IP change that could kill session)
        Set-Content -Path $stageFile -Value "2"

        Set-LabStaticIP -IPAddress $DCIPAddress -Prefix $SubnetPrefix `
            -GatewayAddr $Gateway -DNSServers @($DCIPAddress, "127.0.0.1")

        # -- Install AD DS Feature --
        Write-Host "`n[*] Installing Active Directory Domain Services..." -ForegroundColor Yellow
        $addsFeature = Get-WindowsFeature AD-Domain-Services
        if (-not $addsFeature.Installed) {
            $result = Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
            if ($result.Success) {
                Write-Host "    [+] AD DS feature installed" -ForegroundColor Green
                if ($result.RestartNeeded -eq "Yes") {
                    Write-Host "    [*] Feature install requests a reboot (will happen at end of stage)" -ForegroundColor Gray
                }
            } else {
                Write-Host "    [!] AD DS install FAILED. Check Windows Update and disk space." -ForegroundColor Red
                Write-Host "    [!] Try: Install-WindowsFeature AD-Domain-Services -IncludeManagementTools" -ForegroundColor Yellow
                Set-Content -Path $stageFile -Value "1"
                Stop-Transcript
                exit 1
            }
        } else {
            Write-Host "    [=] AD DS already installed" -ForegroundColor DarkGray
        }

        # -- Rename Computer --
        if ($env:COMPUTERNAME -ne $DCHostname) {
            Write-Host "`n[*] Renaming computer to $DCHostname..." -ForegroundColor Yellow
            try {
                Rename-Computer -NewName $DCHostname -Force -ErrorAction Stop
                Write-Host "    [+] Rename scheduled (takes effect after reboot)" -ForegroundColor Green
            } catch {
                Write-Host "    [!] Rename failed: $($_.Exception.Message)" -ForegroundColor Yellow
                Write-Host "    [!] You can rename manually: Rename-Computer -NewName $DCHostname -Force" -ForegroundColor Yellow
            }
        } else {
            Write-Host "`n[=] Hostname already $DCHostname" -ForegroundColor DarkGray
        }

        Write-Host ""
        Write-Host "  ================================================================" -ForegroundColor Green
        Write-Host "   DC STAGE 1/3 COMPLETE" -ForegroundColor Green
        Write-Host "  ================================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "  What to do next:" -ForegroundColor White
        Write-Host "    1. Machine reboots in 5 seconds" -ForegroundColor White
        Write-Host "    2. Log back in as Administrator" -ForegroundColor White
        Write-Host "    3. Run:  .\Configure-Lab.ps1" -ForegroundColor White
        Write-Host ""
        Write-Host "  NOTE: DNS will not resolve external names until Stage 2" -ForegroundColor Gray
        Write-Host "        completes (this is normal)." -ForegroundColor Gray
        Write-Host ""

        Start-Sleep -Seconds 5
        Stop-Transcript
        Restart-Computer -Force
        exit 0
    }

    # ========================================================
    # DC STAGE 2: Promote to Domain Controller
    # ========================================================
    if ($stage -eq 2) {
        Write-Host "[DC Stage 2/3] Promoting to Domain Controller..." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Domain: $DomainFQDN" -ForegroundColor White
        Write-Host "  This will reboot automatically after promotion." -ForegroundColor White
        Write-Host ""

        # Check if already a DC
        $domainRoleCheck = (Get-CimInstance Win32_ComputerSystem).DomainRole
        if ($domainRoleCheck -in @(4, 5)) {
            Write-Host "    [=] Already a Domain Controller. Skipping." -ForegroundColor DarkGray
            Set-Content -Path $stageFile -Value "3"
            Write-Host "    [*] Run the script again for Stage 3." -ForegroundColor Yellow
            Stop-Transcript
            exit 0
        }

        # Verify AD DS feature is installed (could have failed in Stage 1)
        $addsCheck = Get-WindowsFeature AD-Domain-Services
        if (-not $addsCheck.Installed) {
            Write-Host "    [!] AD DS feature is not installed. Installing now..." -ForegroundColor Yellow
            $result = Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
            if (-not $result.Success) {
                Write-Host "    [!] AD DS install failed. Cannot promote." -ForegroundColor Red
                Stop-Transcript
                exit 1
            }
            Write-Host "    [+] AD DS installed. Rebooting first, then re-run for promotion." -ForegroundColor Green
            # Stay on stage 2 for next run
            Start-Sleep -Seconds 3
            Stop-Transcript
            Restart-Computer -Force
            exit 0
        }

        # Save stage 3 BEFORE promotion (promotion auto-reboots)
        Set-Content -Path $stageFile -Value "3"

        $safeModePass = ConvertTo-SecureString $DSRMPassword -AsPlainText -Force

        try {
            Import-Module ADDSDeployment -ErrorAction Stop

            Install-ADDSForest `
                -DomainName $DomainFQDN `
                -DomainNetbiosName $DomainNetBIOS `
                -SafeModeAdministratorPassword $safeModePass `
                -InstallDns:$true `
                -CreateDnsDelegation:$false `
                -DatabasePath "C:\Windows\NTDS" `
                -LogPath "C:\Windows\NTDS" `
                -SysvolPath "C:\Windows\SYSVOL" `
                -NoRebootOnCompletion:$false `
                -Force:$true

            # Normally we never reach here (auto-reboot)
            Write-Host "    [!] Promotion completed but no auto-reboot. Rebooting now..." -ForegroundColor Yellow
            Stop-Transcript
            Restart-Computer -Force
        } catch {
            Write-Host ""
            Write-Host "    [!] Promotion FAILED: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
            Write-Host "    Common fixes:" -ForegroundColor Yellow
            Write-Host "      - If 'domain already exists': reboot and run script again" -ForegroundColor White
            Write-Host "      - If 'access denied': make sure you are local Administrator" -ForegroundColor White
            Write-Host "      - If 'prerequisite check failed': run the command manually:" -ForegroundColor White
            Write-Host "        Install-ADDSForest -DomainName $DomainFQDN -InstallDns" -ForegroundColor Gray
            Write-Host ""
            # CRITICAL: Reset to stage 2 so user can retry
            Set-Content -Path $stageFile -Value "2"
            Write-Host "    [*] Stage reset to 2. Fix the issue and run the script again." -ForegroundColor Yellow
        }
        Stop-Transcript
        exit 0
    }

    # ========================================================
    # DC STAGE 3: All Vulnerability Configuration
    # ========================================================
    if ($stage -eq 3) {
        Write-Host "[DC Stage 3/3] Configuring all attack paths..." -ForegroundColor Yellow
        Write-Host ""

        # Wait for AD to be fully ready after promotion reboot
        if (-not (Wait-ForADReady -MaxWaitSeconds 120)) {
            Write-Host "    [!] AD is not responding. The DC might still be initializing." -ForegroundColor Red
            Write-Host "    [!] Wait a minute, then run the script again." -ForegroundColor Yellow
            Stop-Transcript
            exit 1
        }

        Import-Module ActiveDirectory -ErrorAction Stop
        $domain = (Get-ADDomain).DistinguishedName
        $employeesOU = "OU=BankEmployees,$domain"
        $serviceOU = "OU=ServiceAccounts,$domain"

        # ---- 1/10: OUs ----
        Write-Host "[1/10] Creating Organizational Units..." -ForegroundColor Yellow
        @("BankEmployees", "ServiceAccounts", "Workstations") | ForEach-Object {
            if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$_'" -SearchBase $domain -ErrorAction SilentlyContinue)) {
                try {
                    New-ADOrganizationalUnit -Name $_ -Path $domain -ProtectedFromAccidentalDeletion $false -ErrorAction Stop
                    Write-Host "    [+] Created OU: $_" -ForegroundColor Green
                } catch {
                    Write-Host "    [!] Failed to create OU $_: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            } else {
                Write-Host "    [=] OU exists: $_" -ForegroundColor DarkGray
            }
        }

        # ---- 2/10: Users ----
        Write-Host "`n[2/10] Creating domain users..." -ForegroundColor Yellow
        $defaultPass = ConvertTo-SecureString "OrsUBank2024!" -AsPlainText -Force

        $users = @(
            @{ Sam="vamsi.krishna"; Name="Vamsi Krishna"; Given="Vamsi"; Surname="Krishna";
               Title="Bank Manager"; Dept="Management"; Pass=$defaultPass },
            @{ Sam="ammulu.orsu"; Name="Ammulu Orsu"; Given="Ammulu"; Surname="Orsu";
               Title="IT Manager"; Dept="IT"; Pass=$defaultPass },
            @{ Sam="lakshmi.devi"; Name="Lakshmi Devi"; Given="Lakshmi"; Surname="Devi";
               Title="System Administrator"; Dept="IT"; Pass=$defaultPass },
            @{ Sam="ravi.teja"; Name="Ravi Teja"; Given="Ravi"; Surname="Teja";
               Title="Network Administrator"; Dept="IT"; Pass=$defaultPass },
            @{ Sam="pranavi"; Name="Pranavi"; Given="Pranavi"; Surname=" ";
               Title="Branch Manager"; Dept="Branch Operations";
               Pass=(ConvertTo-SecureString "Branch123!" -AsPlainText -Force) },
            @{ Sam="harsha.vardhan"; Name="Harsha Vardhan"; Given="Harsha"; Surname="Vardhan";
               Title="Customer Service Manager"; Dept="Customer Service";
               Pass=(ConvertTo-SecureString "Customer2024!" -AsPlainText -Force) },
            @{ Sam="divya"; Name="Divya"; Given="Divya"; Surname=" ";
               Title="Loan Officer"; Dept="Loans"; Pass=$defaultPass },
            @{ Sam="kiran.kumar"; Name="Kiran Kumar"; Given="Kiran"; Surname="Kumar";
               Title="Financial Analyst"; Dept="Finance";
               Pass=(ConvertTo-SecureString "Finance1!" -AsPlainText -Force) },
            @{ Sam="madhavi"; Name="Madhavi"; Given="Madhavi"; Surname=" ";
               Title="Operations Manager"; Dept="Operations"; Pass=$defaultPass },
            @{ Sam="sai.kiran"; Name="Sai Kiran"; Given="Sai"; Surname="Kiran";
               Title="Compliance Officer"; Dept="Compliance"; Pass=$defaultPass }
        )

        foreach ($u in $users) {
            try {
                if (-not (Get-ADUser -Filter "SamAccountName -eq '$($u.Sam)'" -ErrorAction SilentlyContinue)) {
                    New-ADUser -Name $u.Name -SamAccountName $u.Sam `
                        -UserPrincipalName "$($u.Sam)@$DomainFQDN" `
                        -GivenName $u.Given -Surname $u.Surname `
                        -Title $u.Title -Department $u.Dept `
                        -Path $employeesOU -AccountPassword $u.Pass `
                        -Enabled $true -PasswordNeverExpires $true -ErrorAction Stop
                    Write-Host "    [+] Created: $($u.Sam) ($($u.Title))" -ForegroundColor Green
                } else {
                    Set-ADAccountPassword -Identity $u.Sam -Reset -NewPassword $u.Pass -ErrorAction SilentlyContinue
                    Write-Host "    [=] Exists: $($u.Sam), password reset" -ForegroundColor DarkGray
                }
            } catch {
                Write-Host "    [!] Error creating $($u.Sam): $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        Add-ADGroupMember -Identity "Domain Admins" -Members "ammulu.orsu" -ErrorAction SilentlyContinue
        Write-Host "    [+] ammulu.orsu -> Domain Admins" -ForegroundColor Green

        $attackerUser = Get-ADUser "vamsi.krishna"

        # ---- 3/10: Kerberoasting ----
        Write-Host "`n[3/10] Configuring Kerberoasting targets..." -ForegroundColor Yellow

        $serviceAccounts = @(
            @{ Sam="sqlservice"; Name="SQL Server Service"; Pass="MYpassword123#";
               SPN="MSSQLSvc/DC01.orsubank.local:1433"; Desc="SQL Server Database Engine" },
            @{ Sam="httpservice"; Name="HTTP Service"; Pass="Summer2024!";
               SPN="HTTP/web.orsubank.local"; Desc="Web Application Service" },
            @{ Sam="iisservice"; Name="IIS Application Pool"; Pass="P@ssw0rd";
               SPN="HTTP/app.orsubank.local"; Desc="IIS Application Pool Identity" },
            @{ Sam="backupservice"; Name="Backup Service"; Pass="SQLAgent123!";
               SPN="MSSQLSvc/DC01.orsubank.local:1434"; Desc="Database Backup Agent" }
        )

        foreach ($svc in $serviceAccounts) {
            try {
                $secPass = ConvertTo-SecureString $svc.Pass -AsPlainText -Force
                if (-not (Get-ADUser -Filter "SamAccountName -eq '$($svc.Sam)'" -ErrorAction SilentlyContinue)) {
                    New-ADUser -Name $svc.Name -SamAccountName $svc.Sam `
                        -UserPrincipalName "$($svc.Sam)@$DomainFQDN" `
                        -Description $svc.Desc -Path $serviceOU `
                        -AccountPassword $secPass -Enabled $true `
                        -PasswordNeverExpires $true -CannotChangePassword $true `
                        -ServicePrincipalNames $svc.SPN -ErrorAction Stop
                    Write-Host "    [+] $($svc.Sam) | SPN: $($svc.SPN)" -ForegroundColor Green
                } else {
                    Set-ADUser -Identity $svc.Sam -ServicePrincipalNames @{Add=$svc.SPN} -ErrorAction SilentlyContinue
                    Write-Host "    [=] $($svc.Sam) exists, SPN ensured" -ForegroundColor DarkGray
                }
            } catch {
                Write-Host "    [!] Error with $($svc.Sam): $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        # ---- 4/10: AS-REP Roasting ----
        Write-Host "`n[4/10] Configuring AS-REP Roasting targets..." -ForegroundColor Yellow
        @("pranavi", "harsha.vardhan", "kiran.kumar") | ForEach-Object {
            try {
                Set-ADAccountControl -Identity $_ -DoesNotRequirePreAuth $true -ErrorAction Stop
                Write-Host "    [+] Pre-auth disabled: $_" -ForegroundColor Green
            } catch {
                Write-Host "    [!] Failed for $_: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        # ---- 5/10: ACL Abuse ----
        Write-Host "`n[5/10] Configuring ACL abuse paths..." -ForegroundColor Yellow

        # GenericAll: vamsi.krishna on lakshmi.devi
        $targetUser = Get-ADUser "lakshmi.devi"
        $gaRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
            $attackerUser.SID,
            [System.DirectoryServices.ActiveDirectoryRights]::GenericAll,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
        Set-LabACE -TargetDN $targetUser.DistinguishedName -Rule $gaRule `
            -Label "GenericAll: vamsi.krishna -> lakshmi.devi"

        # IT_Admins group + WriteDACL
        if (-not (Get-ADGroup -Filter "Name -eq 'IT_Admins'" -ErrorAction SilentlyContinue)) {
            New-ADGroup -Name "IT_Admins" -GroupScope Global -GroupCategory Security `
                -Path $domain -Description "IT Administrators"
        }
        Add-ADGroupMember -Identity "Domain Admins" -Members "IT_Admins" -ErrorAction SilentlyContinue

        $itAdmins = Get-ADGroup "IT_Admins"
        $wdRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
            $attackerUser.SID,
            [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
        Set-LabACE -TargetDN $itAdmins.DistinguishedName -Rule $wdRule `
            -Label "WriteDACL: vamsi.krishna -> IT_Admins (member of DA)"

        # ForceChangePassword: divya on ammulu.orsu
        $daUser = Get-ADUser "ammulu.orsu"
        $divyaUser = Get-ADUser "divya"
        $fcpGuid = [GUID]"00299570-246d-11d0-a768-00aa006e0529"
        $fcpRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
            $divyaUser.SID,
            [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight,
            [System.Security.AccessControl.AccessControlType]::Allow,
            $fcpGuid
        )
        Set-LabACE -TargetDN $daUser.DistinguishedName -Rule $fcpRule `
            -Label "ForceChangePassword: divya -> ammulu.orsu (DA)"

        # GenericWrite: vamsi.krishna on sai.kiran
        $saiKiran = Get-ADUser "sai.kiran"
        $gwRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
            $attackerUser.SID,
            [System.DirectoryServices.ActiveDirectoryRights]::GenericWrite,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
        Set-LabACE -TargetDN $saiKiran.DistinguishedName -Rule $gwRule `
            -Label "GenericWrite: vamsi.krishna -> sai.kiran (targeted Kerberoasting)"

        # ---- 6/10: DA Paths ----
        Write-Host "`n[6/10] Configuring Domain Admin paths..." -ForegroundColor Yellow

        # Nested group chain
        $groupChain = @(
            @{ Name="HelpDesk_Team"; Desc="First-level support" },
            @{ Name="IT_Support"; Desc="Second-level IT support" },
            @{ Name="Server_Admins"; Desc="Server administrators" }
        )
        foreach ($g in $groupChain) {
            if (-not (Get-ADGroup -Filter "Name -eq '$($g.Name)'" -ErrorAction SilentlyContinue)) {
                New-ADGroup -Name $g.Name -GroupScope Global -GroupCategory Security -Description $g.Desc
            }
        }
        Add-ADGroupMember -Identity "IT_Support" -Members "HelpDesk_Team" -ErrorAction SilentlyContinue
        Add-ADGroupMember -Identity "Server_Admins" -Members "IT_Support" -ErrorAction SilentlyContinue
        Add-ADGroupMember -Identity "Domain Admins" -Members "Server_Admins" -ErrorAction SilentlyContinue
        Add-ADGroupMember -Identity "HelpDesk_Team" -Members "harsha.vardhan" -ErrorAction SilentlyContinue
        Write-Host "    [+] Nested chain: harsha.vardhan -> HelpDesk -> IT_Support -> Server_Admins -> DA" -ForegroundColor Green

        # svc_backup: DA with SPN
        $svcBackupPass = ConvertTo-SecureString "Backup@2024!" -AsPlainText -Force
        if (-not (Get-ADUser -Filter "SamAccountName -eq 'svc_backup'" -ErrorAction SilentlyContinue)) {
            New-ADUser -Name "svc_backup" -SamAccountName "svc_backup" `
                -UserPrincipalName "svc_backup@$DomainFQDN" -Path $serviceOU `
                -AccountPassword $svcBackupPass -Enabled $true `
                -PasswordNeverExpires $true -Description "Backup Service Account"
        }
        Add-ADGroupMember -Identity "Domain Admins" -Members "svc_backup" -ErrorAction SilentlyContinue
        Set-ADUser -Identity "svc_backup" -ServicePrincipalNames @{Add="backup/dc01.orsubank.local"} -ErrorAction SilentlyContinue
        Write-Host "    [+] svc_backup: DA with SPN (Kerberoastable DA)" -ForegroundColor Green

        # DCSync rights for WS01$
        $ws01 = Get-ADComputer "WS01" -ErrorAction SilentlyContinue
        $skippedWS01Items = @()
        if ($ws01) {
            $domainDN = (Get-ADDomain).DistinguishedName
            $ace1 = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                $ws01.SID, "ExtendedRight", "Allow",
                [GUID]"1131f6aa-9c07-11d1-f79f-00c04fc2dcd2"
            )
            $ace2 = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                $ws01.SID, "ExtendedRight", "Allow",
                [GUID]"1131f6ad-9c07-11d1-f79f-00c04fc2dcd2"
            )
            Set-LabACE -TargetDN $domainDN -Rule $ace1 -Label "DCSync (Get-Changes) for WS01$"
            Set-LabACE -TargetDN $domainDN -Rule $ace2 -Label "DCSync (Get-Changes-All) for WS01$"
        } else {
            $skippedWS01Items += "DCSync rights"
            Write-Host "    [!] WS01 not in domain yet. DCSync rights skipped." -ForegroundColor Yellow
        }

        # ---- 7/10: Delegation ----
        Write-Host "`n[7/10] Configuring delegation vulnerabilities..." -ForegroundColor Yellow

        if ($ws01) {
            Set-ADComputer -Identity "WS01" -TrustedForDelegation $true
            Write-Host "    [+] Unconstrained Delegation on WS01" -ForegroundColor Green
        } else {
            $skippedWS01Items += "Unconstrained Delegation"
            Write-Host "    [!] WS01 not found. Unconstrained Delegation skipped." -ForegroundColor Yellow
        }

        # Constrained: svc_web -> CIFS/DC01
        $svcWebPass = ConvertTo-SecureString "WebSvc@2024!" -AsPlainText -Force
        if (-not (Get-ADUser -Filter "SamAccountName -eq 'svc_web'" -ErrorAction SilentlyContinue)) {
            New-ADUser -Name "svc_web" -SamAccountName "svc_web" `
                -UserPrincipalName "svc_web@$DomainFQDN" -Path $serviceOU `
                -AccountPassword $svcWebPass -Enabled $true `
                -PasswordNeverExpires $true -Description "Web Application Service"
        }
        Set-ADUser -Identity "svc_web" -ServicePrincipalNames @{Add="HTTP/intranet.orsubank.local"} -ErrorAction SilentlyContinue
        # Use -Replace to be idempotent (not -Add which fails on re-run)
        Set-ADUser -Identity "svc_web" -Replace @{
            "msDS-AllowedToDelegateTo" = @("CIFS/DC01.orsubank.local", "CIFS/DC01")
        } -ErrorAction SilentlyContinue
        Set-ADAccountControl -Identity "svc_web" -TrustedToAuthForDelegation $true
        Write-Host "    [+] Constrained Delegation: svc_web -> CIFS/DC01" -ForegroundColor Green

        # RBCD: vamsi.krishna can write delegation on WS01
        if ($ws01) {
            $rbcdGuid = [GUID]"3f78c3e5-f79a-46bd-a0b8-9d18116ddc79"
            $rbcdRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                $attackerUser.SID, "WriteProperty", "Allow", $rbcdGuid
            )
            Set-LabACE -TargetDN $ws01.DistinguishedName -Rule $rbcdRule `
                -Label "RBCD write: vamsi.krishna -> WS01"
        } else {
            $skippedWS01Items += "RBCD"
        }

        # ---- 8/10: ADCS ----
        Write-Host "`n[8/10] Installing AD Certificate Services..." -ForegroundColor Yellow

        # Scope ADCS variables outside try blocks
        $configNC = $null
        $domainUsersSID = $null
        $enrollGuid = [GUID]"0e10c968-78fb-11d2-90d4-00c04f79dc55"

        try { $configNC = (Get-ADRootDSE).configurationNamingContext } catch {}
        try { $domainUsersSID = (Get-ADGroup "Domain Users").SID } catch {}

        $adcsInstalled = (Get-WindowsFeature ADCS-Cert-Authority).Installed
        if (-not $adcsInstalled) {
            Write-Host "    [*] Installing ADCS features (this takes a few minutes)..." -ForegroundColor Gray
            $result = Install-WindowsFeature ADCS-Cert-Authority, ADCS-Web-Enrollment -IncludeManagementTools
            if ($result.Success) {
                Write-Host "    [+] ADCS features installed" -ForegroundColor Green
            } else {
                Write-Host "    [!] ADCS feature install failed. ADCS attacks won't work." -ForegroundColor Red
            }

            # Wait for IIS to be ready
            Write-Host "    [*] Starting IIS..." -ForegroundColor Gray
            Start-Service W3SVC -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5

            try {
                Install-AdcsCertificationAuthority -CAType EnterpriseRootCA `
                    -CACommonName "ORSUBANK-CA" -KeyLength 2048 `
                    -HashAlgorithmName SHA256 -ValidityPeriod Years `
                    -ValidityPeriodUnits 10 -Force | Out-Null
                Write-Host "    [+] Enterprise Root CA: ORSUBANK-CA" -ForegroundColor Green
            } catch {
                Write-Host "    [!] CA config: $($_.Exception.Message)" -ForegroundColor Yellow
            }

            Start-Sleep -Seconds 3

            try {
                Install-AdcsWebEnrollment -Force | Out-Null
                Write-Host "    [+] Web Enrollment configured" -ForegroundColor Green
            } catch {
                Write-Host "    [!] Web Enrollment: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "    [=] ADCS already installed" -ForegroundColor DarkGray
        }

        # ESC1: User template allows SAN
        if ($configNC) {
            Write-Host "    [*] Configuring ESC1 (enrollee supplies subject)..." -ForegroundColor Gray
            try {
                $userTemplateDN = "CN=User,CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNC"
                # Verify template exists
                if (-not (Get-ADObject -Identity $userTemplateDN -ErrorAction SilentlyContinue)) {
                    Write-Host "    [!] ESC1: User template not found. Is this an Enterprise CA?" -ForegroundColor Yellow
                } else {
                    $templateObj = [ADSI]"LDAP://$userTemplateDN"
                    $currentFlags = $templateObj.Properties["msPKI-Certificate-Name-Flag"].Value
                    $newFlags = $currentFlags -bor 1
                    $templateObj.Properties["msPKI-Certificate-Name-Flag"].Value = $newFlags
                    $templateObj.CommitChanges()

                    if ($domainUsersSID) {
                        $enrollRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                            $domainUsersSID,
                            [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight,
                            [System.Security.AccessControl.AccessControlType]::Allow,
                            $enrollGuid
                        )
                        $templateAcl = Get-Acl "AD:\$userTemplateDN"
                        $templateAcl.AddAccessRule($enrollRule)
                        Set-Acl "AD:\$userTemplateDN" $templateAcl
                    }
                    Write-Host "    [+] ESC1: User template allows SAN, Domain Users can enroll" -ForegroundColor Green
                }
            } catch {
                Write-Host "    [!] ESC1 error: $($_.Exception.Message)" -ForegroundColor Yellow
            }

            # ESC4: vamsi.krishna has GenericWrite on WebServer template
            Write-Host "    [*] Configuring ESC4 (writable template)..." -ForegroundColor Gray
            try {
                $webTemplateDN = "CN=WebServer,CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNC"
                if (-not (Get-ADObject -Identity $webTemplateDN -ErrorAction SilentlyContinue)) {
                    Write-Host "    [!] ESC4: WebServer template not found." -ForegroundColor Yellow
                } else {
                    $acl = Get-Acl "AD:\$webTemplateDN"
                    $writeRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                        $attackerUser.SID,
                        [System.DirectoryServices.ActiveDirectoryRights]::GenericWrite,
                        [System.Security.AccessControl.AccessControlType]::Allow
                    )
                    $acl.AddAccessRule($writeRule)

                    if ($domainUsersSID) {
                        $enrollRule2 = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                            $domainUsersSID,
                            [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight,
                            [System.Security.AccessControl.AccessControlType]::Allow,
                            $enrollGuid
                        )
                        $acl.AddAccessRule($enrollRule2)
                    }
                    Set-Acl "AD:\$webTemplateDN" $acl
                    certutil -setcatemplates +WebServer 2>$null | Out-Null
                    Write-Host "    [+] ESC4: vamsi.krishna -> GenericWrite on WebServer template" -ForegroundColor Green
                }
            } catch {
                Write-Host "    [!] ESC4 error: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "    [!] Could not read AD configuration. ESC1/ESC4 skipped." -ForegroundColor Yellow
        }

        # ESC8: Web Enrollment without SSL or EPA
        Write-Host "    [*] Configuring ESC8 (HTTP relay target)..." -ForegroundColor Gray
        try {
            Import-Module WebAdministration -ErrorAction Stop
            Set-WebConfigurationProperty `
                -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site/CertSrv' `
                -filter "system.webServer/security/access" `
                -name "sslFlags" -value "None" -ErrorAction Stop
            Set-WebConfigurationProperty `
                -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site/CertSrv' `
                -filter "system.webServer/security/authentication/windowsAuthentication" `
                -name "extendedProtection.tokenChecking" -value "None" -ErrorAction Stop
            Set-WebConfigurationProperty `
                -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site/CertSrv' `
                -filter "system.webServer/security/authentication/windowsAuthentication" `
                -name "enabled" -value $true -ErrorAction Stop
            Write-Host "    [+] ESC8: NTLM relay to Web Enrollment (no SSL, no EPA)" -ForegroundColor Green
        } catch {
            Write-Host "    [!] ESC8 error: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "    [!] If IIS is not ready, reboot and re-run: .\Configure-Lab.ps1 -Role DC -Reset" -ForegroundColor Yellow
        }

        # ---- 9/10: Credential Exposure ----
        Write-Host "`n[9/10] Configuring credential exposure..." -ForegroundColor Yellow

        $wdigestPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest"
        if (-not (Test-Path $wdigestPath)) { New-Item -Path $wdigestPath -Force | Out-Null }
        Set-ItemProperty -Path $wdigestPath -Name "UseLogonCredential" -Value 1 -Type DWord -Force
        Write-Host "    [+] WDigest enabled (cleartext in LSASS after next login)" -ForegroundColor Green

        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value 0 -Type DWord -Force
        Write-Host "    [+] LSA Protection disabled" -ForegroundColor Green

        $dgPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
        if (-not (Test-Path $dgPath)) { New-Item -Path $dgPath -Force | Out-Null }
        Set-ItemProperty -Path $dgPath -Name "EnableVirtualizationBasedSecurity" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LsaCfgFlags" -Value 0 -Type DWord -Force
        Write-Host "    [+] Credential Guard disabled" -ForegroundColor Green

        # Plant files
        @("C:\IT", "C:\Backup", "C:\Scripts") | ForEach-Object {
            New-Item -Path $_ -ItemType Directory -Force | Out-Null
        }

        @"
ORSUBANK IT ADMIN PASSWORDS (CONFIDENTIAL)
-------------------------------------------

Domain Admin Backup Account:
  Username: ammulu.orsu
  Password: OrsUBank2024!

SQL Server SA Account:
  Username: sa
  Password: SQLAdmin@2024!

VPN Emergency Access:
  Username: vpnadmin
  Password: VPNUser123!

Remote Support Tool:
  Username: support
  Password: Support@Bank2024

DO NOT SHARE - FOR IT USE ONLY
Last Updated: 2024-12-01
"@ | Set-Content "C:\IT\passwords.txt"

        @"
ORSUBANK DATABASE CONNECTIONS
------------------------------

Production SQL:
  Server: DC01.orsubank.local
  User: sqlservice
  Password: MYpassword123#

Backup SQL:
  Server: DC01.orsubank.local,1434
  User: backupservice
  Password: SQLAgent123!

Connection String:
Server=DC01.orsubank.local;Database=BankingApp;User Id=sqlservice;Password=MYpassword123#;
"@ | Set-Content "C:\Backup\database_credentials.txt"

        @"
ORSUBANK SERVICE ACCOUNTS
--------------------------

sqlservice     MYpassword123#     SQL Server
httpservice    Summer2024!        Web Server
iisservice     P@ssw0rd           IIS App Pool
backupservice  SQLAgent123!       Backup Agent
svc_backup     Backup@2024!       Backup (DA)
svc_web        WebSvc@2024!       Web App

KEEP SECURE - AUDIT ANNUALLY
"@ | Set-Content "C:\Scripts\service_accounts.txt"
        Write-Host "    [+] Credential files planted" -ForegroundColor Green

        # ---- 10/10: Coercion ----
        Write-Host "`n[10/10] Configuring coercion..." -ForegroundColor Yellow
        Set-Service -Name Spooler -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name Spooler -ErrorAction SilentlyContinue
        $spoolerStatus = (Get-Service -Name Spooler -ErrorAction SilentlyContinue).Status
        if ($spoolerStatus -eq "Running") {
            Write-Host "    [+] Print Spooler running (verified)" -ForegroundColor Green
        } else {
            Write-Host "    [!] Print Spooler is not running (status: $spoolerStatus)" -ForegroundColor Yellow
        }

        # ---- VERIFICATION ----
        Write-Host "`n[*] Running verification checks..." -ForegroundColor Cyan
        $passed = 0; $failed = 0

        # Check users
        $userCount = (Get-ADUser -Filter * -SearchBase $employeesOU -ErrorAction SilentlyContinue | Measure-Object).Count
        if ($userCount -ge 10) { Write-Host "    [OK] $userCount domain users in BankEmployees" -ForegroundColor Green; $passed++ }
        else { Write-Host "    [FAIL] Only $userCount users found (expected 10)" -ForegroundColor Red; $failed++ }

        # Check SPNs
        $spnCount = (Get-ADUser -Filter {ServicePrincipalName -like "*"} -Properties ServicePrincipalName -ErrorAction SilentlyContinue | Measure-Object).Count
        if ($spnCount -ge 5) { Write-Host "    [OK] $spnCount accounts with SPNs" -ForegroundColor Green; $passed++ }
        else { Write-Host "    [FAIL] Only $spnCount SPN accounts (expected 5+)" -ForegroundColor Red; $failed++ }

        # Check AS-REP
        $asrepCount = (Get-ADUser -Filter {DoesNotRequirePreAuth -eq $true} -ErrorAction SilentlyContinue | Measure-Object).Count
        if ($asrepCount -ge 3) { Write-Host "    [OK] $asrepCount AS-REP roastable accounts" -ForegroundColor Green; $passed++ }
        else { Write-Host "    [FAIL] Only $asrepCount AS-REP accounts (expected 3)" -ForegroundColor Red; $failed++ }

        # Check ADCS
        $caService = Get-Service -Name CertSvc -ErrorAction SilentlyContinue
        if ($caService -and $caService.Status -eq "Running") { Write-Host "    [OK] Certificate Authority is running" -ForegroundColor Green; $passed++ }
        else { Write-Host "    [FAIL] CA service not running" -ForegroundColor Red; $failed++ }

        Write-Host ""
        Write-Host "    Verification: $passed passed, $failed failed" -ForegroundColor $(if ($failed -eq 0) {"Green"} else {"Yellow"})

        # ---- Mark Complete ----
        Set-Content -Path $stageFile -Value "done"

        Write-Host ""
        Write-Host "  ================================================================" -ForegroundColor Green
        Write-Host "   DC01 SETUP COMPLETE" -ForegroundColor Green
        Write-Host "  ================================================================" -ForegroundColor Green
        Write-Host ""
        if ($skippedWS01Items.Count -gt 0) {
            Write-Host "  [!] SKIPPED (WS01 not joined yet): $($skippedWS01Items -join ', ')" -ForegroundColor Yellow
            Write-Host "      After WS01 joins, re-run: .\Configure-Lab.ps1 -Role DC -Reset" -ForegroundColor Yellow
            Write-Host ""
        }
        Write-Host "  [!] Reboot DC01 for WDigest/LSA changes." -ForegroundColor Yellow
        Write-Host "  [!] Next: Run this script on WS01." -ForegroundColor Yellow
        Write-Host ""
    }

    if ("$stage" -eq "done") {
        Write-Host "[*] DC01 setup is already complete." -ForegroundColor Green
        Write-Host "    Re-run: .\Configure-Lab.ps1 -Reset" -ForegroundColor Gray
    }
}


# ############################################################
#                    WS STAGES
# ############################################################

if ($Role -eq "WS") {

    # ========================================================
    # WS STAGE 1: Hostname, IP, DNS, Defender
    # ========================================================
    if ($stage -eq 1) {
        Write-Host "[WS Stage 1/3] Base system setup..." -ForegroundColor Yellow
        Write-Host ""

        Disable-WindowsDefender

        # Save stage early (before IP change)
        Set-Content -Path $stageFile -Value "2"

        Set-LabStaticIP -IPAddress $WSIPAddress -Prefix $SubnetPrefix `
            -GatewayAddr $Gateway -DNSServers @($DCIPAddress)

        # Rename
        if ($env:COMPUTERNAME -ne $WSHostname) {
            Write-Host "`n[*] Renaming computer to $WSHostname..." -ForegroundColor Yellow
            try {
                Rename-Computer -NewName $WSHostname -Force -ErrorAction Stop
                Write-Host "    [+] Rename scheduled for after reboot" -ForegroundColor Green
            } catch {
                Write-Host "    [!] Rename failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "`n[=] Hostname already $WSHostname" -ForegroundColor DarkGray
        }

        Write-Host ""
        Write-Host "  ================================================================" -ForegroundColor Green
        Write-Host "   WS STAGE 1/3 COMPLETE" -ForegroundColor Green
        Write-Host "  ================================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "  What to do next:" -ForegroundColor White
        Write-Host "    1. Machine reboots in 5 seconds" -ForegroundColor White
        Write-Host "    2. Log back in as Administrator" -ForegroundColor White
        Write-Host "    3. Make sure DC01 is running (ping $DCIPAddress)" -ForegroundColor White
        Write-Host "    4. Run:  .\Configure-Lab.ps1" -ForegroundColor White
        Write-Host ""

        Start-Sleep -Seconds 5
        Stop-Transcript
        Restart-Computer -Force
        exit 0
    }

    # ========================================================
    # WS STAGE 2: Join Domain
    # ========================================================
    if ($stage -eq 2) {
        Write-Host "[WS Stage 2/3] Joining domain $DomainFQDN..." -ForegroundColor Yellow
        Write-Host ""

        # Already joined?
        $cs = Get-CimInstance Win32_ComputerSystem
        if ($cs.PartOfDomain -and $cs.Domain -eq $DomainFQDN) {
            Write-Host "    [=] Already joined to $DomainFQDN." -ForegroundColor DarkGray
            Set-Content -Path $stageFile -Value "3"
            Write-Host "    [*] Run the script again for Stage 3." -ForegroundColor Yellow
            Stop-Transcript
            exit 0
        }

        # Test DC reachability (ICMP)
        Write-Host "    [*] Testing connection to DC01 ($DCIPAddress)..." -ForegroundColor Gray
        if (-not (Test-Connection $DCIPAddress -Count 2 -Quiet)) {
            Write-Host "    [!] Cannot ping DC01 at $DCIPAddress" -ForegroundColor Red
            Write-Host "    [!] Check:" -ForegroundColor Yellow
            Write-Host "        - Is DC01 powered on?" -ForegroundColor White
            Write-Host "        - Did DC01 complete Stage 2 (domain promotion)?" -ForegroundColor White
            Write-Host "        - Is the network adapter connected?" -ForegroundColor White
            Write-Host "        - Is WS01's DNS set to $DCIPAddress?" -ForegroundColor White
            Stop-Transcript
            exit 1
        }
        Write-Host "    [+] DC01 is reachable (ping OK)" -ForegroundColor Green

        # Test DNS resolution
        Write-Host "    [*] Testing DNS resolution of $DomainFQDN..." -ForegroundColor Gray
        try {
            $dnsResult = Resolve-DnsName $DomainFQDN -ErrorAction Stop
            Write-Host "    [+] DNS resolves $DomainFQDN -> $($dnsResult[0].IPAddress)" -ForegroundColor Green
        } catch {
            Write-Host "    [!] DNS cannot resolve $DomainFQDN" -ForegroundColor Red
            Write-Host "    [!] Check that WS01's DNS is set to $DCIPAddress" -ForegroundColor Yellow
            Write-Host "    [!] Run: Set-DnsClientServerAddress -InterfaceIndex (Get-NetAdapter | Select -First 1).ifIndex -ServerAddresses '$DCIPAddress'" -ForegroundColor Gray
            Stop-Transcript
            exit 1
        }

        # Ask for credentials explicitly (not rely on -Force which tries null creds)
        Write-Host ""
        Write-Host "  Enter domain admin credentials to join the domain:" -ForegroundColor White
        Write-Host "    Username: $DomainNetBIOS\Administrator" -ForegroundColor White
        Write-Host "    Password: (the password you set when installing Windows Server on DC01)" -ForegroundColor White
        Write-Host ""

        try {
            $cred = Get-Credential -Message "Enter $DomainNetBIOS\Administrator password to join domain" `
                -UserName "$DomainNetBIOS\Administrator"

            Add-Computer -DomainName $DomainFQDN -Credential $cred -Force -ErrorAction Stop

            # If we get here, join succeeded. Save stage and reboot.
            Set-Content -Path $stageFile -Value "3"
            Write-Host "    [+] Domain join successful! Rebooting..." -ForegroundColor Green
            Start-Sleep -Seconds 3
            Stop-Transcript
            Restart-Computer -Force
        } catch {
            Write-Host "    [!] Domain join FAILED: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host ""
            Write-Host "    Common fixes:" -ForegroundColor Yellow
            Write-Host "      - Wrong password: try again" -ForegroundColor White
            Write-Host "      - 'RPC server unavailable': DC01 firewall may be blocking" -ForegroundColor White
            Write-Host "      - 'Domain not found': check DNS (nslookup $DomainFQDN)" -ForegroundColor White
            Write-Host ""
            Write-Host "    Stage stays at 2. Fix the issue and run the script again." -ForegroundColor Yellow
            # Stage stays at 2 (we didn't save 3 yet)
        }
        Stop-Transcript
        exit 0
    }

    # ========================================================
    # WS STAGE 3: All Vulnerability Configuration
    # ========================================================
    if ($stage -eq 3) {
        Write-Host "[WS Stage 3/3] Configuring all attack paths..." -ForegroundColor Yellow
        Write-Host ""

        # Force network profile to Private (PSRemoting fails on Public)
        Write-Host "[*] Setting network profile to Private..." -ForegroundColor Yellow
        try {
            Get-NetConnectionProfile | Where-Object { $_.NetworkCategory -ne "DomainAuthenticated" } |
                Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue
            Write-Host "    [+] Network profile set to Private" -ForegroundColor Green
        } catch {
            Write-Host "    [=] Could not change network profile (may already be domain)" -ForegroundColor DarkGray
        }

        # ---- 1/4: Local Privilege Escalation ----
        Write-Host "`n[1/4] Configuring local privilege escalation..." -ForegroundColor Yellow

        # Unquoted Service Path
        $vulnPath = "C:\Program Files\ORSU Bank\Update Service"
        New-Item -Path $vulnPath -ItemType Directory -Force | Out-Null
        Copy-Item "C:\Windows\System32\notepad.exe" "$vulnPath\UpdateSvc.exe" -Force
        New-LabService -Name "ORSUUpdateService" `
            -BinPath "C:\Program Files\ORSU Bank\Update Service\UpdateSvc.exe" `
            -Description "ORSUBANK Automatic Update Service"

        # AlwaysInstallElevated
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Force | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" `
            -Name "AlwaysInstallElevated" -Value 1 -Type DWord
        New-Item -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Force | Out-Null
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" `
            -Name "AlwaysInstallElevated" -Value 1 -Type DWord
        Write-Host "    [+] AlwaysInstallElevated (MSI runs as SYSTEM)" -ForegroundColor Green

        # Weak Service Binary
        $weakPath = "C:\Services\VulnService"
        New-Item -Path $weakPath -ItemType Directory -Force | Out-Null
        Copy-Item "C:\Windows\System32\notepad.exe" "$weakPath\vulnservice.exe" -Force
        $everyoneRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "Everyone", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
        )
        $acl = Get-Acl $weakPath; $acl.AddAccessRule($everyoneRule); Set-Acl $weakPath $acl
        $acl = Get-Acl "$weakPath\vulnservice.exe"; $acl.AddAccessRule($everyoneRule); Set-Acl "$weakPath\vulnservice.exe" $acl
        New-LabService -Name "VulnService" -BinPath "$weakPath\vulnservice.exe" `
            -Description "Vulnerable service with weak file permissions"

        # Weak Registry Permissions
        Copy-Item "C:\Windows\System32\notepad.exe" "C:\Windows\Temp\regsvc.exe" -Force
        New-LabService -Name "RegHijackService" -BinPath "C:\Windows\Temp\regsvc.exe" `
            -Description "Service with weak registry permissions"
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\RegHijackService"
        if (Test-Path $regPath) {
            $regAcl = Get-Acl $regPath
            $regRule = New-Object System.Security.AccessControl.RegistryAccessRule("Everyone", "FullControl", "Allow")
            $regAcl.AddAccessRule($regRule)
            Set-Acl $regPath $regAcl
            Write-Host "    [+] Weak registry ACL set on RegHijackService" -ForegroundColor Green
        } else {
            Write-Host "    [!] RegHijackService registry key not found (service creation may have failed)" -ForegroundColor Yellow
        }

        # Stored AutoLogon
        $winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        Set-ItemProperty -Path $winlogonPath -Name "DefaultUserName" -Value "svc_autologon"
        Set-ItemProperty -Path $winlogonPath -Name "DefaultPassword" -Value "AutoLogon@2024!"
        Set-ItemProperty -Path $winlogonPath -Name "DefaultDomainName" -Value $DomainNetBIOS
        Set-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -Value "0"
        Write-Host "    [+] Stored AutoLogon: svc_autologon / AutoLogon@2024!" -ForegroundColor Green

        # Vulnerable Scheduled Task
        New-Item -Path "C:\ScheduledTasks" -ItemType Directory -Force | Out-Null
        "Write-Host 'Cleanup task running...'" | Out-File "C:\ScheduledTasks\cleanup.ps1"
        $taskFileAcl = Get-Acl "C:\ScheduledTasks\cleanup.ps1"
        $taskFileAcl.AddAccessRule($everyoneRule)
        Set-Acl "C:\ScheduledTasks\cleanup.ps1" $taskFileAcl
        $action = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-ExecutionPolicy Bypass -File C:\ScheduledTasks\cleanup.ps1"
        $trigger = New-ScheduledTaskTrigger -Daily -At "3:00AM"
        $taskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        Register-ScheduledTask -TaskName "ORSUCleanup" -Action $action `
            -Trigger $trigger -Principal $taskPrincipal -Force | Out-Null
        Write-Host "    [+] Scheduled task: ORSUCleanup (SYSTEM, writable script)" -ForegroundColor Green

        # ---- 2/4: Lateral Movement ----
        Write-Host "`n[2/4] Configuring lateral movement..." -ForegroundColor Yellow

        # PSRemoting
        try {
            Enable-PSRemoting -Force -SkipNetworkProfileCheck -ErrorAction Stop 2>$null | Out-Null
            Write-Host "    [+] PSRemoting enabled" -ForegroundColor Green
        } catch {
            Write-Host "    [!] PSRemoting failed: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "    [!] Try changing network profile to Private first" -ForegroundColor Yellow
        }

        Set-Service -Name WinRM -StartupType Automatic -ErrorAction SilentlyContinue
        Start-Service -Name WinRM -ErrorAction SilentlyContinue
        try { Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force -ErrorAction SilentlyContinue } catch {}

        # WMI
        netsh advfirewall firewall set rule group="Windows Management Instrumentation (WMI)" new enable=yes 2>$null | Out-Null
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Ole" -Name "EnableDCOM" -Value "Y" -Force
        Write-Host "    [+] WMI remote access enabled" -ForegroundColor Green

        # RDP
        Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
            -Name "fDenyTSConnections" -Value 0 -Force
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction SilentlyContinue
        Write-Host "    [+] RDP enabled" -ForegroundColor Green

        # Admin shares
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" `
            -Name "AutoShareWks" -Value 1 -Type DWord -Force
        Write-Host "    [+] Admin shares accessible" -ForegroundColor Green

        # Disable remote UAC
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
            -Name "LocalAccountTokenFilterPolicy" -Value 1 -Type DWord -Force
        Write-Host "    [+] Remote UAC disabled (PtH works)" -ForegroundColor Green

        # Local admin
        $localPass = ConvertTo-SecureString "LocalAdmin123!" -AsPlainText -Force
        if (-not (Get-LocalUser -Name "localadmin" -ErrorAction SilentlyContinue)) {
            try {
                New-LocalUser -Name "localadmin" -Password $localPass `
                    -PasswordNeverExpires -Description "Lab local admin" -ErrorAction Stop | Out-Null
                Add-LocalGroupMember -Group "Administrators" -Member "localadmin" -ErrorAction Stop
                Write-Host "    [+] Local admin: localadmin / LocalAdmin123!" -ForegroundColor Green
            } catch {
                Write-Host "    [!] Failed to create localadmin: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "    [=] localadmin exists" -ForegroundColor DarkGray
        }

        # Credential exposure
        $wdigestPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest"
        if (-not (Test-Path $wdigestPath)) { New-Item -Path $wdigestPath -Force | Out-Null }
        Set-ItemProperty -Path $wdigestPath -Name "UseLogonCredential" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value 0 -Type DWord -Force
        Write-Host "    [+] WDigest on, LSA Protection off" -ForegroundColor Green

        # ---- 3/4: Persistence ----
        Write-Host "`n[3/4] Configuring persistence..." -ForegroundColor Yellow

        $persistScript = "C:\Windows\Temp\persistence_demo.ps1"
        "Write-Host 'Persistence demo running'" | Out-File $persistScript

        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
            -Name "ORSUBankUpdater" `
            -Value "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File $persistScript"
        Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" `
            -Name "ORSUBankSync" `
            -Value "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File $persistScript"
        Write-Host "    [+] Registry Run keys set" -ForegroundColor Green

        $startupDir = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
        "@echo off`npowershell -WindowStyle Hidden -Command `"Write-Host 'Startup demo'`"" | `
            Out-File "$startupDir\ORSUStartup.bat" -Encoding ASCII
        Write-Host "    [+] Startup folder: ORSUStartup.bat" -ForegroundColor Green

        $taskAction = New-ScheduledTaskAction -Execute "powershell.exe" `
            -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File $persistScript"
        $startupTrigger = New-ScheduledTaskTrigger -AtStartup
        $systemPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" `
            -LogonType ServiceAccount -RunLevel Highest
        Register-ScheduledTask -TaskName "ORSUStartupSync" -Action $taskAction `
            -Trigger $startupTrigger -Principal $systemPrincipal -Force | Out-Null
        Write-Host "    [+] Scheduled task: ORSUStartupSync (SYSTEM at boot)" -ForegroundColor Green

        # Hidden service
        Copy-Item "C:\Windows\System32\svchost.exe" "C:\Windows\Temp\ORSUHost.exe" -Force -ErrorAction SilentlyContinue
        New-LabService -Name "ORSUHostService" `
            -BinPath "C:\Windows\Temp\ORSUHost.exe -k netsvcs" `
            -Description "ORSU Bank Network Services Host"

        # WMI subscription
        try {
            $filter = Set-WmiInstance -Namespace "root\subscription" -Class "__EventFilter" -Arguments @{
                Name = "ORSUFilter"
                EventNamespace = "root\cimv2"
                QueryLanguage = "WQL"
                Query = "SELECT * FROM __InstanceCreationEvent WITHIN 60 WHERE TargetInstance ISA 'Win32_Process' AND TargetInstance.Name = 'notepad.exe'"
            }
            $consumer = Set-WmiInstance -Namespace "root\subscription" -Class "CommandLineEventConsumer" -Arguments @{
                Name = "ORSUConsumer"
                CommandLineTemplate = "powershell.exe -WindowStyle Hidden -Command `"Write-Host 'WMI persistence'`""
            }
            Set-WmiInstance -Namespace "root\subscription" -Class "__FilterToConsumerBinding" -Arguments @{
                Filter = $filter; Consumer = $consumer
            } | Out-Null
            Write-Host "    [+] WMI event subscription (fileless)" -ForegroundColor Green
        } catch {
            Write-Host "    [!] WMI subscription: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # ---- 4/4: Coercion ----
        Write-Host "`n[4/4] Configuring coercion..." -ForegroundColor Yellow
        $webClient = Get-Service -Name WebClient -ErrorAction SilentlyContinue
        if ($webClient) {
            Set-Service -Name WebClient -StartupType Automatic
            Start-Service -Name WebClient -ErrorAction SilentlyContinue
            $wcStatus = (Get-Service WebClient).Status
            if ($wcStatus -eq "Running") {
                Write-Host "    [+] WebClient running (verified)" -ForegroundColor Green
            } else {
                Write-Host "    [!] WebClient status: $wcStatus" -ForegroundColor Yellow
            }
        } else {
            Write-Host "    [!] WebClient not available. Install Desktop Experience if needed." -ForegroundColor Yellow
        }

        # ---- VERIFICATION ----
        Write-Host "`n[*] Running verification checks..." -ForegroundColor Cyan
        $passed = 0; $failed = 0

        if (Test-ServiceExists "ORSUUpdateService") { Write-Host "    [OK] ORSUUpdateService exists" -ForegroundColor Green; $passed++ }
        else { Write-Host "    [FAIL] ORSUUpdateService missing" -ForegroundColor Red; $failed++ }

        if (Test-ServiceExists "VulnService") { Write-Host "    [OK] VulnService exists" -ForegroundColor Green; $passed++ }
        else { Write-Host "    [FAIL] VulnService missing" -ForegroundColor Red; $failed++ }

        $aie = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Name AlwaysInstallElevated -ErrorAction SilentlyContinue
        if ($aie -and $aie.AlwaysInstallElevated -eq 1) { Write-Host "    [OK] AlwaysInstallElevated is on" -ForegroundColor Green; $passed++ }
        else { Write-Host "    [FAIL] AlwaysInstallElevated not set" -ForegroundColor Red; $failed++ }

        $winrmStatus = (Get-Service WinRM -ErrorAction SilentlyContinue).Status
        if ($winrmStatus -eq "Running") { Write-Host "    [OK] WinRM running" -ForegroundColor Green; $passed++ }
        else { Write-Host "    [FAIL] WinRM not running ($winrmStatus)" -ForegroundColor Red; $failed++ }

        Write-Host ""
        Write-Host "    Verification: $passed passed, $failed failed" -ForegroundColor $(if ($failed -eq 0) {"Green"} else {"Yellow"})

        # ---- Mark Complete ----
        Set-Content -Path $stageFile -Value "done"

        Write-Host ""
        Write-Host "  ================================================================" -ForegroundColor Green
        Write-Host "   WS01 SETUP COMPLETE" -ForegroundColor Green
        Write-Host "  ================================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "  [!] Reboot WS01 for WDigest/LSA changes." -ForegroundColor Yellow
        Write-Host "  [!] After reboot, start attacking from Kali." -ForegroundColor Yellow
        Write-Host ""
    }

    if ("$stage" -eq "done") {
        Write-Host "[*] WS01 setup is already complete." -ForegroundColor Green
        Write-Host "    Re-run: .\Configure-Lab.ps1 -Reset" -ForegroundColor Gray
    }
}

Write-Host "[*] Configure-Lab.ps1 finished at $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
Stop-Transcript | Out-Null
