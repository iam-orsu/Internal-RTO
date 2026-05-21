# ============================================================
# ORSUBANK AD RED TEAM LAB V4 - AUTOMATED SETUP
# ============================================================
#
# Single script for DC01 and WS01.
# Uses VMware NAT (default adapter). No manual network config.
#
# How it works:
#   1. Create a VM with default NAT network adapter
#   2. Install Windows, set Administrator password
#   3. Run this script. It auto-detects the network.
#   4. It reboots and continues automatically. 3 runs per machine.
#
#   DC01: Run 1/3 -> reboot -> Run 2/3 -> auto-reboot -> Run 3/3 -> done
#   WS01: Run 1/3 -> reboot -> Run 2/3 -> reboot -> Run 3/3 -> done
#
# Usage:
#   .\Configure-Lab.ps1              (auto-detect everything)
#   .\Configure-Lab.ps1 -Role DC     (force DC mode)
#   .\Configure-Lab.ps1 -Role WS     (force WS mode)
#   .\Configure-Lab.ps1 -Reset       (wipe progress, start over)
#
# All output logged to C:\LabSetup\setup.log
# ============================================================

param(
    [ValidateSet("DC", "WS")]
    [string]$Role,
    [switch]$Reset
)

# ============================================================
# LAB CONFIG
# ============================================================
$DomainFQDN     = "orsubank.local"
$DomainNetBIOS  = "ORSUBANK"
$DSRMPassword   = "DSRMPass@2024!"
$DCHostname     = "DC01"
$WSHostname     = "WS01"

# ============================================================
# BOOTSTRAP
# ============================================================
$labDir    = "C:\LabSetup"
$logFile   = "$labDir\setup.log"
$stageFile = "$labDir\stage.txt"
$netConf   = "$labDir\network.conf"

if (-not (Test-Path $labDir)) {
    New-Item -Path $labDir -ItemType Directory -Force | Out-Null
}

# Copy script to lab dir so auto-resume can find it
$scriptInLab = "$labDir\Configure-Lab.ps1"
if ($PSCommandPath -and ($PSCommandPath -ne $scriptInLab)) {
    Copy-Item $PSCommandPath $scriptInLab -Force -ErrorAction SilentlyContinue
}

try { Stop-Transcript -ErrorAction SilentlyContinue } catch {}
Start-Transcript -Path $logFile -Append -Force | Out-Null
Write-Host "[*] Logging to $logFile" -ForegroundColor Gray

# Execution policy
$currentPolicy = Get-ExecutionPolicy -Scope Process
if ($currentPolicy -eq "Restricted") {
    Write-Host "[!] Setting execution policy to Bypass for this session." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
}

# Admin check
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] ERROR: Run this as Administrator." -ForegroundColor Red
    Write-Host "    Right-click PowerShell -> Run as Administrator" -ForegroundColor Yellow
    try { Stop-Transcript } catch {}
    exit 1
}


# ============================================================
# HELPER: Auto-detect VMware NAT network
# ============================================================
function Find-LabNetwork {
    # 1. Check saved config (from a previous run)
    if (Test-Path $netConf) {
        $conf = @{}
        Get-Content $netConf | ForEach-Object {
            if ($_ -match '^(\w+)=(.+)$') {
                $conf[$Matches[1]] = $Matches[2].Trim()
            }
        }
        if ($conf.ContainsKey("Subnet") -and $conf.ContainsKey("DCIPAddress")) {
            Write-Host "    [=] Using saved config: $($conf.Subnet).0/24" -ForegroundColor DarkGray
            return $conf
        }
    }

    Write-Host "    [*] Auto-detecting VMware NAT subnet..." -ForegroundColor Gray

    $adapters = Get-NetAdapter | Where-Object {
        $_.Status -eq "Up" -and
        $_.InterfaceDescription -notlike "*Loopback*" -and
        $_.InterfaceDescription -notlike "*Bluetooth*"
    }

    # 2. Try DHCP addresses (fresh VM, first run)
    foreach ($adapter in $adapters) {
        $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notlike "169.254.*" -and $_.PrefixOrigin -eq "Dhcp" } |
            Select-Object -First 1

        if ($ipConfig) {
            $ip = $ipConfig.IPAddress
            $octets = $ip.Split(".")
            $subnet = "$($octets[0]).$($octets[1]).$($octets[2])"

            $conf = @{
                Subnet        = $subnet
                DCIPAddress   = "$subnet.10"
                WSIPAddress   = "$subnet.20"
                KaliIPAddress = "$subnet.30"
                Gateway       = "$subnet.2"
                SubnetPrefix  = "24"
                AdapterIndex  = [string]$adapter.ifIndex
                AdapterName   = $adapter.Name
                DetectedFrom  = $ip
            }

            $conf.GetEnumerator() | Sort-Object Key | ForEach-Object {
                "$($_.Key)=$($_.Value)"
            } | Set-Content $netConf

            Write-Host "    [+] Detected NAT subnet: $subnet.0/24 (from DHCP: $ip)" -ForegroundColor Green
            Write-Host "    [+] DC: $subnet.10 | WS: $subnet.20 | Gateway: $subnet.2" -ForegroundColor Green
            return $conf
        }
    }

    # 3. No DHCP found. Check if our static IP is already set (re-run)
    foreach ($adapter in $adapters) {
        $ipConfig = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notlike "169.254.*" } |
            Select-Object -First 1

        if ($ipConfig) {
            $ip = $ipConfig.IPAddress
            $octets = $ip.Split(".")
            $lastOctet = [int]$octets[3]

            if ($lastOctet -eq 10 -or $lastOctet -eq 20) {
                $subnet = "$($octets[0]).$($octets[1]).$($octets[2])"
                $conf = @{
                    Subnet        = $subnet
                    DCIPAddress   = "$subnet.10"
                    WSIPAddress   = "$subnet.20"
                    KaliIPAddress = "$subnet.30"
                    Gateway       = "$subnet.2"
                    SubnetPrefix  = "24"
                    AdapterIndex  = [string]$adapter.ifIndex
                    AdapterName   = $adapter.Name
                    DetectedFrom  = $ip
                }

                $conf.GetEnumerator() | Sort-Object Key | ForEach-Object {
                    "$($_.Key)=$($_.Value)"
                } | Set-Content $netConf

                Write-Host "    [+] Found existing lab IP: $ip (subnet: $subnet.0/24)" -ForegroundColor Green
                return $conf
            }
        }
    }

    return $null
}


# ============================================================
# HELPER: Set static IP
# ============================================================
function Set-LabStaticIP {
    param(
        [string]$IPAddress,
        [int]$Prefix,
        [string]$GatewayAddr,
        [string[]]$DNSServers
    )

    Write-Host "`n[*] Configuring network..." -ForegroundColor Yellow

    $adapter = Get-NetAdapter | Where-Object {
        $_.Status -eq "Up" -and
        $_.InterfaceDescription -notlike "*Loopback*" -and
        $_.InterfaceDescription -notlike "*Bluetooth*"
    } | Select-Object -First 1

    if (-not $adapter) {
        Write-Host "    [!] No active network adapter found." -ForegroundColor Red
        Get-NetAdapter | Format-Table Name, Status, InterfaceDescription -AutoSize
        return $false
    }

    Write-Host "    [*] Adapter: $($adapter.Name) ($($adapter.InterfaceDescription))" -ForegroundColor Gray

    # Already set?
    $currentIP = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -eq $IPAddress }

    if ($currentIP) {
        Write-Host "    [=] IP already $IPAddress" -ForegroundColor DarkGray
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $DNSServers
        Write-Host "    [+] DNS: $($DNSServers -join ', ')" -ForegroundColor Green
        return $true
    }

    # Disable DHCP first (prevents conflict when setting static IP)
    try {
        Set-NetIPInterface -InterfaceIndex $adapter.ifIndex -Dhcp Disabled -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    } catch {}

    # Remove old IPs
    Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -notlike "169.254.*" } |
        Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
    try { Remove-NetRoute -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue 2>$null } catch {}

    try {
        New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $IPAddress `
            -PrefixLength $Prefix -DefaultGateway $GatewayAddr -ErrorAction Stop | Out-Null
        Write-Host "    [+] IP: $IPAddress/$Prefix | Gateway: $GatewayAddr" -ForegroundColor Green
    } catch {
        try {
            New-NetIPAddress -InterfaceIndex $adapter.ifIndex -IPAddress $IPAddress `
                -PrefixLength $Prefix -ErrorAction Stop | Out-Null
            Write-Host "    [+] IP: $IPAddress/$Prefix (no gateway)" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Failed: $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }

    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $DNSServers
    Write-Host "    [+] DNS: $($DNSServers -join ', ')" -ForegroundColor Green

    # Set network profile to Private (prevents firewall blocking lab traffic)
    try {
        Get-NetConnectionProfile -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue |
            Where-Object { $_.NetworkCategory -eq "Public" } |
            Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue
    } catch {}

    # Allow ICMP (ping) through firewall
    try {
        New-NetFirewallRule -DisplayName "Lab-ICMP" -Direction Inbound -Protocol ICMPv4 `
            -IcmpType 8 -Action Allow -Profile Any -ErrorAction SilentlyContinue | Out-Null
    } catch {}

    return $true
}


# ============================================================
# HELPER: Auto-resume after reboot
# ============================================================
function Register-LabResume {
    $scriptPath = "$labDir\Configure-Lab.ps1"
    if (-not (Test-Path $scriptPath)) { return }

    # Save current role so it persists across reboots
    $roleFile = "$labDir\role.txt"
    if ($Role) { Set-Content -Path $roleFile -Value $Role -Force }

    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    # Use Start-Process -Verb RunAs to ensure elevation on workstations
    # Pass -Role so the menu does not show again after reboot
    $cmd = "powershell.exe -ExecutionPolicy Bypass -NoProfile -Command `"Start-Process powershell -Verb RunAs -ArgumentList '-ExecutionPolicy Bypass -NoExit -File \`"$scriptPath\`" -Role $Role'`""
    Set-ItemProperty -Path $regPath -Name "LabSetup" -Value $cmd -Force
    Write-Host "    [+] Auto-resume registered (will continue at next login)" -ForegroundColor Green
}

function Unregister-LabResume {
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
    Remove-ItemProperty -Path $regPath -Name "LabSetup" -ErrorAction SilentlyContinue
}


# ============================================================
# HELPER: Wait for AD services after reboot
# ============================================================
function Wait-ForADReady {
    param([int]$MaxWaitSeconds = 120)

    Write-Host "    [*] Waiting for AD services..." -ForegroundColor Gray
    $waited = 0
    while ($waited -lt $MaxWaitSeconds) {
        $ntds = Get-Service -Name NTDS -ErrorAction SilentlyContinue
        if ($ntds -and $ntds.Status -eq "Running") {
            try {
                Import-Module ActiveDirectory -ErrorAction Stop
                Get-ADDomain -ErrorAction Stop | Out-Null
                Write-Host "    [+] AD is ready (waited ${waited}s)" -ForegroundColor Green
                return $true
            } catch {}
        }
        Start-Sleep -Seconds 5
        $waited += 5
        if (($waited % 15) -eq 0) {
            Write-Host "    [*] Still waiting... (${waited}s)" -ForegroundColor Gray
        }
    }
    Write-Host "    [!] AD not ready after ${MaxWaitSeconds}s" -ForegroundColor Red
    return $false
}


# ============================================================
# HELPER: Disable Defender
# ============================================================
function Disable-WindowsDefender {
    Write-Host "[*] Disabling Windows Defender..." -ForegroundColor Yellow

    try {
        $tamper = (Get-MpComputerStatus -ErrorAction Stop).IsTamperProtected
        if ($tamper) {
            Write-Host ""
            Write-Host "    ============================================================" -ForegroundColor Red
            Write-Host "    TAMPER PROTECTION IS ON" -ForegroundColor Red
            Write-Host "    ============================================================" -ForegroundColor Red
            Write-Host ""
            Write-Host "    Do this manually:" -ForegroundColor Yellow
            Write-Host "      1. Open Windows Security" -ForegroundColor White
            Write-Host "      2. Virus & threat protection -> Manage settings" -ForegroundColor White
            Write-Host "      3. Turn OFF Tamper Protection" -ForegroundColor White
            Write-Host "      4. Turn OFF Real-time protection" -ForegroundColor White
            Write-Host "      5. Come back and press Enter" -ForegroundColor White
            Write-Host ""
            Read-Host "    Press Enter after disabling Tamper Protection"
        }
    } catch {}

    try {
        Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop
        Write-Host "    [+] Real-time protection disabled" -ForegroundColor Green
    } catch {
        Write-Host "    [!] Could not disable real-time: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    try {
        Set-MpPreference -DisableIOAVProtection $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
        Set-MpPreference -DisableScriptScanning $true -ErrorAction SilentlyContinue
    } catch {}

    $defenderPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
    if (-not (Test-Path $defenderPath)) { New-Item -Path $defenderPath -Force | Out-Null }
    Set-ItemProperty -Path $defenderPath -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force
    $rtpPath = "$defenderPath\Real-Time Protection"
    if (-not (Test-Path $rtpPath)) { New-Item -Path $rtpPath -Force | Out-Null }
    Set-ItemProperty -Path $rtpPath -Name "DisableRealtimeMonitoring" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $rtpPath -Name "DisableBehaviorMonitoring" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $rtpPath -Name "DisableIOAVProtection" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $rtpPath -Name "DisableScanOnRealtimeEnable" -Value 1 -Type DWord -Force
    Write-Host "    [+] Defender registry policies set" -ForegroundColor Green

    try {
        Add-MpPreference -ExclusionPath "C:\Tools" -ErrorAction SilentlyContinue
        Add-MpPreference -ExclusionPath "C:\LabSetup" -ErrorAction SilentlyContinue
        Add-MpPreference -ExclusionPath "C:\Users" -ErrorAction SilentlyContinue
        Write-Host "    [+] Exclusions added" -ForegroundColor Green
    } catch {}
}


# ============================================================
# HELPER: Service creation
# ============================================================
function Test-ServiceExists {
    param([string]$ServiceName)
    return [bool](Get-Service -Name $ServiceName -ErrorAction SilentlyContinue)
}

function New-LabService {
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
        Write-Host "    [!] Failed to create service: $Name" -ForegroundColor Yellow
    }
}


# ============================================================
# HELPER: ACL management
# ============================================================
function Set-LabACE {
    param(
        [string]$TargetDN,
        [System.DirectoryServices.ActiveDirectoryAccessRule]$Rule,
        [string]$Label
    )
    try {
        $entry = [ADSI]"LDAP://$TargetDN"
        $entry.get_Options().SecurityMasks = [System.DirectoryServices.SecurityMasks]::Dacl
        $acl = $entry.psbase.ObjectSecurity
        
        $rules = $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])
        $exists = $false
        foreach ($ace in $rules) {
            if ($ace.IdentityReference.Value -eq $Rule.IdentityReference.Value -and 
                $ace.ActiveDirectoryRights -eq $Rule.ActiveDirectoryRights -and
                $ace.AccessControlType -eq $Rule.AccessControlType) {
                
                # Check ObjectType (GUID) if applicable
                $guidMatch = $true
                if ($Rule.ObjectType -ne [System.Guid]::Empty -or $ace.ObjectType -ne [System.Guid]::Empty) {
                    $guidMatch = ($ace.ObjectType -eq $Rule.ObjectType)
                }
                
                if ($guidMatch) {
                    $exists = $true
                    break
                }
            }
        }
        if ($exists) {
            Write-Host "    [=] ACE exists: $Label" -ForegroundColor DarkGray
        } else {
            $acl.AddAccessRule($Rule)
            $entry.psbase.CommitChanges()
            Write-Host "    [+] $Label" -ForegroundColor Green
        }
    } catch {
        Write-Host "    [!] ACE error ($Label): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}


# ============================================================
# ROLE SELECTION
# ============================================================
if (-not $Role) {
    # If already a DC, skip the menu
    $domainRole = (Get-CimInstance Win32_ComputerSystem).DomainRole
    if ($domainRole -in @(4, 5)) {
        $Role = "DC"
        Write-Host "[*] Detected: This machine is already a Domain Controller." -ForegroundColor Cyan
    } else {
        # Check if role was saved from a previous run
        $roleFile = "$labDir\role.txt"
        if (Test-Path $roleFile) {
            $savedRole = (Get-Content $roleFile -Raw).Trim().ToUpper()
            if ($savedRole -eq "DC" -or $savedRole -eq "WS") {
                $Role = $savedRole
                Write-Host "[*] Using saved role: $Role (from previous run)" -ForegroundColor Cyan
            }
        }

        # If still no role, show menu
        if (-not $Role) {
            Write-Host ""
            Write-Host "  ============================================================" -ForegroundColor Cyan
            Write-Host "   WHAT IS THIS MACHINE?" -ForegroundColor Cyan
            Write-Host "  ============================================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "    [D] Domain Controller  (DC01 - Windows Server)" -ForegroundColor White
            Write-Host "    [W] Workstation        (WS01 - Windows 10/11)" -ForegroundColor White
            Write-Host ""
            do {
                $choice = Read-Host "  Press D or W"
                $choice = $choice.Trim().ToUpper()
            } while ($choice -ne "D" -and $choice -ne "W")

            if ($choice -eq "D") { $Role = "DC" }
            else { $Role = "WS" }

            # Save choice for future runs
            Set-Content -Path "$labDir\role.txt" -Value $Role -Force

            Write-Host ""
            Write-Host "[*] Selected role: $Role" -ForegroundColor Cyan
        }
    }
}


# ============================================================
# STAGE TRACKING
# ============================================================
if ($Reset) {
    Remove-Item $stageFile -Force -ErrorAction SilentlyContinue
    Remove-Item $netConf -Force -ErrorAction SilentlyContinue
    Remove-Item "$labDir\role.txt" -Force -ErrorAction SilentlyContinue
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
        Write-Host "[!] Stage file corrupted. Resetting to Stage 1." -ForegroundColor Yellow
        $stage = 1
    }
}


# ============================================================
# DETECT NETWORK
# ============================================================
Write-Host "`n[*] Network detection..." -ForegroundColor Yellow
$net = Find-LabNetwork

if (-not $net) {
    Write-Host "    [!] Could not detect VMware NAT network." -ForegroundColor Red
    Write-Host "    [!] Make sure:" -ForegroundColor Yellow
    Write-Host "        - VM has a NAT network adapter" -ForegroundColor White
    Write-Host "        - The adapter is connected and has an IP" -ForegroundColor White
    Write-Host "        - Run 'ipconfig' to check" -ForegroundColor White
    try { Stop-Transcript } catch {}
    exit 1
}

$DCIPAddress  = $net.DCIPAddress
$WSIPAddress  = $net.WSIPAddress
$Gateway      = $net.Gateway
$SubnetPrefix = [int]$net.SubnetPrefix


# ============================================================
# BANNER
# ============================================================
Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host "   ORSUBANK AD RED TEAM LAB V4" -ForegroundColor Cyan
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host "  Machine:  $($env:COMPUTERNAME)" -ForegroundColor Gray
Write-Host "  Role:     $Role" -ForegroundColor Gray
Write-Host "  Stage:    $stage of 3" -ForegroundColor Gray
Write-Host "  Network:  $($net.Subnet).0/24 (NAT)" -ForegroundColor Gray
Write-Host "  DC IP:    $DCIPAddress" -ForegroundColor Gray
Write-Host "  WS IP:    $WSIPAddress" -ForegroundColor Gray
Write-Host "  Gateway:  $Gateway" -ForegroundColor Gray
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

        # Save stage BEFORE IP change
        Set-Content -Path $stageFile -Value "2"

        # Use gateway as DNS fallback (DC is not a DNS server yet in Stage 1)
        Set-LabStaticIP -IPAddress $DCIPAddress -Prefix $SubnetPrefix `
            -GatewayAddr $Gateway -DNSServers @("127.0.0.1", $Gateway)

        # Install AD DS
        Write-Host "`n[*] Installing Active Directory Domain Services..." -ForegroundColor Yellow
        $addsFeature = Get-WindowsFeature AD-Domain-Services
        if (-not $addsFeature.Installed) {
            $result = Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
            if ($result.Success) {
                Write-Host "    [+] AD DS feature installed" -ForegroundColor Green
            } else {
                Write-Host "    [!] AD DS install FAILED." -ForegroundColor Red
                Set-Content -Path $stageFile -Value "1"
                try { Stop-Transcript } catch {}
                exit 1
            }
        } else {
            Write-Host "    [=] AD DS already installed" -ForegroundColor DarkGray
        }

        # Rename
        $renamed = $false
        if ($env:COMPUTERNAME -ne $DCHostname) {
            Write-Host "`n[*] Renaming to $DCHostname..." -ForegroundColor Yellow
            try {
                Rename-Computer -NewName $DCHostname -Force -ErrorAction Stop
                Write-Host "    [+] Rename scheduled (takes effect after reboot)" -ForegroundColor Green
                $renamed = $true
            } catch {
                Write-Host "    [!] Rename failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "`n[=] Hostname already $DCHostname" -ForegroundColor DarkGray
        }

        if ($renamed) {
            Write-Host ""
            Write-Host "  ================================================================" -ForegroundColor Green
            Write-Host "   DC STAGE 1/3 COMPLETE" -ForegroundColor Green
            Write-Host "  ================================================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "  Rebooting in 10 seconds..." -ForegroundColor White
            Write-Host "  After reboot, the script will continue automatically." -ForegroundColor White
            Write-Host "  If it does not, run:  .\Configure-Lab.ps1" -ForegroundColor Gray
            Write-Host ""

            Register-LabResume
            Start-Sleep -Seconds 10
            try { Stop-Transcript } catch {}
            try { Restart-Computer -Force } catch {}
            exit 0
        } else {
            Write-Host "`n[*] No reboot needed for Stage 1. Moving directly to Stage 2..." -ForegroundColor Yellow
            $stage = 2
        }
    }

    # ========================================================
    # DC STAGE 2: Promote to Domain Controller
    # ========================================================
    if ($stage -eq 2) {
        Write-Host "[DC Stage 2/3] Promoting to Domain Controller..." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  Domain: $DomainFQDN" -ForegroundColor White
        Write-Host ""

        # Already a DC?
        $domainRoleCheck = (Get-CimInstance Win32_ComputerSystem).DomainRole
        if ($domainRoleCheck -in @(4, 5)) {
            Write-Host "    [=] Already a Domain Controller. Skipping reboot and proceeding to Stage 3." -ForegroundColor Green
            Set-Content -Path $stageFile -Value "3"
            $stage = 3
        } else {
            # Verify AD DS feature
            $addsCheck = Get-WindowsFeature AD-Domain-Services
            if (-not $addsCheck.Installed) {
                Write-Host "    [!] AD DS not installed. Installing..." -ForegroundColor Yellow
                $result = Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
                if (-not $result.Success) {
                    Write-Host "    [!] AD DS install failed." -ForegroundColor Red
                    try { Stop-Transcript } catch {}
                    exit 1
                }
                Register-LabResume
                Start-Sleep -Seconds 3
                try { Stop-Transcript } catch {}
                try { Restart-Computer -Force } catch {}
                exit 0
            }

            # Save stage 3 BEFORE promotion (promotion auto-reboots)
            Set-Content -Path $stageFile -Value "3"
            Register-LabResume

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

                # Normally unreachable (auto-reboot)
                try { Stop-Transcript } catch {}
                try { Restart-Computer -Force } catch {}
            } catch {
                Write-Host ""
                Write-Host "    [!] Promotion FAILED: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host ""
                Write-Host "    Common fixes:" -ForegroundColor Yellow
                Write-Host "      - 'domain already exists': reboot and run again" -ForegroundColor White
                Write-Host "      - 'access denied': run as Administrator" -ForegroundColor White
                Write-Host ""
                Set-Content -Path $stageFile -Value "2"
                Write-Host "    [*] Stage reset to 2. Fix the issue and run again." -ForegroundColor Yellow
            }
            try { Stop-Transcript } catch {}
            exit 0
        }
    }

    # ========================================================
    # DC STAGE 3: DNS Forwarder + All Vulnerability Config
    # ========================================================
    if ($stage -eq 3) {
        Write-Host "[DC Stage 3/3] Configuring domain and attack paths..." -ForegroundColor Yellow
        Write-Host ""

        Unregister-LabResume

        # Wait for AD
        if (-not (Wait-ForADReady -MaxWaitSeconds 120)) {
            Write-Host "    [!] AD not responding. Wait a minute and run again." -ForegroundColor Red
            try { Stop-Transcript } catch {}
            exit 1
        }

        Import-Module ActiveDirectory -ErrorAction Stop
        $domain = (Get-ADDomain).DistinguishedName
        $employeesOU = "OU=BankEmployees,$domain"
        $serviceOU = "OU=ServiceAccounts,$domain"

        # ---- DNS FORWARDER (keeps internet working) ----
        Write-Host "[0/10] Setting DNS forwarder for internet access..." -ForegroundColor Yellow
        try {
            $currentForwarders = (Get-DnsServerForwarder -ErrorAction SilentlyContinue).IPAddress
            $needsForwarder = $true
            if ($currentForwarders) {
                foreach ($f in $currentForwarders) {
                    if ($f.ToString() -eq $Gateway -or $f.ToString() -eq "8.8.8.8") {
                        $needsForwarder = $false
                        break
                    }
                }
            }
            if ($needsForwarder) {
                Add-DnsServerForwarder -IPAddress $Gateway -ErrorAction SilentlyContinue
                Add-DnsServerForwarder -IPAddress "8.8.8.8" -ErrorAction SilentlyContinue
                Write-Host "    [+] DNS forwarders: $Gateway, 8.8.8.8 (internet will work)" -ForegroundColor Green
            } else {
                Write-Host "    [=] DNS forwarders already set" -ForegroundColor DarkGray
            }
        } catch {
            Write-Host "    [!] DNS forwarder error: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # ---- 1/10: OUs ----
        Write-Host "`n[1/10] Creating Organizational Units..." -ForegroundColor Yellow
        @("BankEmployees", "ServiceAccounts", "Workstations") | ForEach-Object {
            $ouName = $_
            if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$ouName'" -SearchBase $domain -ErrorAction SilentlyContinue)) {
                try {
                    New-ADOrganizationalUnit -Name $ouName -Path $domain -ProtectedFromAccidentalDeletion $false -ErrorAction Stop
                    Write-Host "    [+] Created OU: $ouName" -ForegroundColor Green
                } catch {
                    Write-Host "    [!] Failed OU ${ouName}: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            } else {
                Write-Host "    [=] OU exists: $ouName" -ForegroundColor DarkGray
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

        $attackerUser = Get-ADUser -Filter "SamAccountName -eq 'vamsi.krishna'" | Select-Object -First 1

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
            $acctName = $_
            try {
                Set-ADAccountControl -Identity $acctName -DoesNotRequirePreAuth $true -ErrorAction Stop
                Write-Host "    [+] Pre-auth disabled: $acctName" -ForegroundColor Green
            } catch {
                Write-Host "    [!] Failed for ${acctName}: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        # ---- 5/10: ACL Abuse ----
        Write-Host "`n[5/10] Configuring ACL abuse paths..." -ForegroundColor Yellow

        # GenericAll: vamsi.krishna on lakshmi.devi
        $targetUser = Get-ADUser -Filter "SamAccountName -eq 'lakshmi.devi'" | Select-Object -First 1
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

        $itAdmins = Get-ADGroup -Filter "Name -eq 'IT_Admins'" | Select-Object -First 1
        $wdRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
            $attackerUser.SID,
            [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
        Set-LabACE -TargetDN $itAdmins.DistinguishedName -Rule $wdRule `
            -Label "WriteDACL: vamsi.krishna -> IT_Admins (member of DA)"

        # ForceChangePassword: divya on ammulu.orsu
        $daUser = Get-ADUser -Filter "SamAccountName -eq 'ammulu.orsu'" | Select-Object -First 1
        $divyaUser = Get-ADUser -Filter "SamAccountName -eq 'divya'" | Select-Object -First 1
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
        $saiKiran = Get-ADUser -Filter "SamAccountName -eq 'sai.kiran'" | Select-Object -First 1
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
        Write-Host "    [+] Chain: harsha.vardhan -> HelpDesk -> IT_Support -> Server_Admins -> DA" -ForegroundColor Green

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
        $ws01 = Get-ADComputer -Filter "Name -eq 'WS01'" -ErrorAction SilentlyContinue
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
            Write-Host "    [!] WS01 not joined yet. DCSync rights skipped." -ForegroundColor Yellow
        }

        # ---- 7/10: Delegation ----
        Write-Host "`n[7/10] Configuring delegation..." -ForegroundColor Yellow

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

        $configNC = $null
        $domainUsersSID = $null
        $enrollGuid = [GUID]"0e10c968-78fb-11d2-90d4-00c04f79dc55"

        try { $configNC = (Get-ADRootDSE).configurationNamingContext } catch {}
        try { $domainUsersSID = (Get-ADGroup -Filter "Name -eq 'Domain Users'" | Select-Object -First 1).SID } catch {}

        $adcsInstalled = (Get-WindowsFeature ADCS-Cert-Authority).Installed
        if (-not $adcsInstalled) {
            Write-Host "    [*] Installing ADCS (takes a few minutes)..." -ForegroundColor Gray
            $result = Install-WindowsFeature ADCS-Cert-Authority, ADCS-Web-Enrollment, Web-Windows-Auth -IncludeManagementTools
            if ($result.Success) {
                Write-Host "    [+] ADCS features installed" -ForegroundColor Green
            } else {
                Write-Host "    [!] ADCS install failed." -ForegroundColor Red
            }

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
            Write-Host "    [*] Configuring ESC1..." -ForegroundColor Gray
            try {
                $userTemplateDN = "CN=User,CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNC"
                if (-not (Get-ADObject -Filter "DistinguishedName -eq '$userTemplateDN'" -ErrorAction SilentlyContinue)) {
                    Write-Host "    [!] ESC1: User template not found." -ForegroundColor Yellow
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
                        Set-LabACE -TargetDN $userTemplateDN -Rule $enrollRule -Label "ESC1: Domain Users enroll on User template"
                    }
                    Write-Host "    [+] ESC1: User template allows SAN, Domain Users can enroll" -ForegroundColor Green
                }
            } catch {
                Write-Host "    [!] ESC1 error: $($_.Exception.Message)" -ForegroundColor Yellow
            }

            # ESC4: vamsi.krishna has GenericWrite on WebServer template
            Write-Host "    [*] Configuring ESC4..." -ForegroundColor Gray
            try {
                $webTemplateDN = "CN=WebServer,CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNC"
                if (-not (Get-ADObject -Filter "DistinguishedName -eq '$webTemplateDN'" -ErrorAction SilentlyContinue)) {
                    Write-Host "    [!] ESC4: WebServer template not found." -ForegroundColor Yellow
                } else {
                    $writeRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                        $attackerUser.SID,
                        [System.DirectoryServices.ActiveDirectoryRights]::GenericWrite,
                        [System.Security.AccessControl.AccessControlType]::Allow
                    )
                    Set-LabACE -TargetDN $webTemplateDN -Rule $writeRule -Label "ESC4: vamsi.krishna -> GenericWrite on WebServer template"

                    if ($domainUsersSID) {
                        $enrollRule2 = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                            $domainUsersSID,
                            [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight,
                            [System.Security.AccessControl.AccessControlType]::Allow,
                            $enrollGuid
                        )
                        Set-LabACE -TargetDN $webTemplateDN -Rule $enrollRule2 -Label "ESC4: Domain Users enroll on WebServer template"
                    }
                    certutil -setcatemplates +WebServer 2>$null | Out-Null
                    Write-Host "    [+] ESC4: vamsi.krishna -> GenericWrite on WebServer template" -ForegroundColor Green
                }
            } catch {
                Write-Host "    [!] ESC4 error: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "    [!] Could not read AD config. ESC1/ESC4 skipped." -ForegroundColor Yellow
        }

        # ESC8: Web Enrollment without SSL or EPA
        Write-Host "    [*] Configuring ESC8..." -ForegroundColor Gray
        $esc8Configured = $false
        for ($i = 1; $i -le 5; $i++) {
            try {
                Import-Module WebAdministration -ErrorAction Stop
                # Check if the path exists in IIS configuration before attempting to set properties
                if (Get-WebConfiguration -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site/CertSrv' -filter "system.webServer/security/access" -ErrorAction SilentlyContinue) {
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
                    Set-WebConfigurationProperty `
                        -pspath 'MACHINE/WEBROOT/APPHOST/Default Web Site/CertSrv' `
                        -filter "system.webServer/security/authentication/anonymousAuthentication" `
                        -name "enabled" -value $false -ErrorAction Stop
                    Write-Host "    [+] ESC8: NTLM relay to Web Enrollment (no SSL, no EPA, NTLM forced)" -ForegroundColor Green
                    $esc8Configured = $true
                    break
                } else {
                    throw "IIS virtual directory /CertSrv not registered yet"
                }
            } catch {
                Write-Host "    [*] ESC8 configuration attempt $i failed: $($_.Exception.Message). Retrying in 5 seconds..." -ForegroundColor DarkGray
                Start-Sleep -Seconds 5
            }
        }
        if (-not $esc8Configured) {
            Write-Host "    [!] ESC8 configuration failed after 5 attempts." -ForegroundColor Yellow
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

        # Plant credential files
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
            Write-Host "    [+] Print Spooler running" -ForegroundColor Green
        } else {
            Write-Host "    [!] Print Spooler not running ($spoolerStatus)" -ForegroundColor Yellow
        }

        # ---- VERIFICATION ----
        Write-Host "`n[*] Running verification checks..." -ForegroundColor Cyan
        $passed = 0; $failed = 0

        $userCount = (Get-ADUser -Filter * -SearchBase $employeesOU -ErrorAction SilentlyContinue | Measure-Object).Count
        if ($userCount -ge 10) { Write-Host "    [OK] $userCount domain users" -ForegroundColor Green; $passed++ }
        else { Write-Host "    [FAIL] Only $userCount users (expected 10)" -ForegroundColor Red; $failed++ }

        $spnCount = (Get-ADUser -Filter {ServicePrincipalName -like "*"} -Properties ServicePrincipalName -ErrorAction SilentlyContinue | Measure-Object).Count
        if ($spnCount -ge 5) { Write-Host "    [OK] $spnCount SPN accounts" -ForegroundColor Green; $passed++ }
        else { Write-Host "    [FAIL] Only $spnCount SPN accounts (expected 5+)" -ForegroundColor Red; $failed++ }

        $asrepCount = (Get-ADUser -Filter {DoesNotRequirePreAuth -eq $true} -ErrorAction SilentlyContinue | Measure-Object).Count
        if ($asrepCount -ge 3) { Write-Host "    [OK] $asrepCount AS-REP roastable" -ForegroundColor Green; $passed++ }
        else { Write-Host "    [FAIL] Only $asrepCount AS-REP accounts (expected 3)" -ForegroundColor Red; $failed++ }

        $caService = Get-Service -Name CertSvc -ErrorAction SilentlyContinue
        if ($caService -and $caService.Status -eq "Running") { Write-Host "    [OK] Certificate Authority running" -ForegroundColor Green; $passed++ }
        else { Write-Host "    [FAIL] CA not running" -ForegroundColor Red; $failed++ }

        # Test internet (DNS forwarder)
        $internetOK = Test-Connection 8.8.8.8 -Count 1 -Quiet -ErrorAction SilentlyContinue
        if ($internetOK) { Write-Host "    [OK] Internet access works" -ForegroundColor Green; $passed++ }
        else { Write-Host "    [WARN] No internet (check gateway $Gateway)" -ForegroundColor Yellow }

        Write-Host ""
        Write-Host "    Verification: $passed passed, $failed failed" -ForegroundColor $(if ($failed -eq 0) {"Green"} else {"Yellow"})

        # Mark complete
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
        Write-Host "  Kali setup:" -ForegroundColor White
        Write-Host "    Your Kali VM also uses NAT. It gets internet automatically." -ForegroundColor Gray
        Write-Host "    For a static IP (optional), run on Kali:" -ForegroundColor Gray
        Write-Host "      sudo ip addr add $($net.KaliIPAddress)/24 dev eth0" -ForegroundColor White
        Write-Host "    Set DNS to DC: echo 'nameserver $DCIPAddress' | sudo tee /etc/resolv.conf" -ForegroundColor White
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

        # Save stage BEFORE IP change
        Set-Content -Path $stageFile -Value "2"

        Set-LabStaticIP -IPAddress $WSIPAddress -Prefix $SubnetPrefix `
            -GatewayAddr $Gateway -DNSServers @($DCIPAddress)

        # Rename
        $renamed = $false
        if ($env:COMPUTERNAME -ne $WSHostname) {
            Write-Host "`n[*] Renaming to $WSHostname..." -ForegroundColor Yellow
            try {
                Rename-Computer -NewName $WSHostname -Force -ErrorAction Stop
                Write-Host "    [+] Rename scheduled for after reboot" -ForegroundColor Green
                $renamed = $true
            } catch {
                Write-Host "    [!] Rename failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "`n[=] Hostname already $WSHostname" -ForegroundColor DarkGray
        }

        if ($renamed) {
            Write-Host ""
            Write-Host "  ================================================================" -ForegroundColor Green
            Write-Host "   WS STAGE 1/3 COMPLETE" -ForegroundColor Green
            Write-Host "  ================================================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "  Rebooting in 10 seconds..." -ForegroundColor White
            Write-Host "  After reboot, the script continues automatically." -ForegroundColor White
            Write-Host "  Make sure DC01 is running and fully set up first." -ForegroundColor Yellow
            Write-Host ""

            Register-LabResume
            Start-Sleep -Seconds 10
            try { Stop-Transcript } catch {}
            try { Restart-Computer -Force } catch {}
            exit 0
        } else {
            Write-Host "`n[*] No reboot needed for Stage 1. Moving directly to Stage 2..." -ForegroundColor Yellow
            $stage = 2
        }
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
            Write-Host "    [=] Already joined to $DomainFQDN. Skipping reboot and proceeding to Stage 3." -ForegroundColor Green
            Set-Content -Path $stageFile -Value "3"
            $stage = 3
        } else {
            # Test DC
            Write-Host "    [*] Testing connection to DC01 ($DCIPAddress)..." -ForegroundColor Gray
            if (-not (Test-Connection $DCIPAddress -Count 2 -Quiet)) {
                Write-Host "    [!] Cannot reach DC01 at $DCIPAddress" -ForegroundColor Red
                Write-Host "    [!] Check:" -ForegroundColor Yellow
                Write-Host "        - Is DC01 powered on?" -ForegroundColor White
                Write-Host "        - Did DC01 complete all 3 stages?" -ForegroundColor White
                Write-Host "        - Both VMs using NAT adapter?" -ForegroundColor White
                try { Stop-Transcript } catch {}
                exit 1
            }
            Write-Host "    [+] DC01 reachable" -ForegroundColor Green

            # Test DNS
            Write-Host "    [*] Testing DNS resolution..." -ForegroundColor Gray
            try {
                $dnsResult = Resolve-DnsName $DomainFQDN -ErrorAction Stop
                Write-Host "    [+] DNS resolves $DomainFQDN -> $($dnsResult[0].IPAddress)" -ForegroundColor Green
            } catch {
                Write-Host "    [!] DNS cannot resolve $DomainFQDN" -ForegroundColor Red
                Write-Host "    [!] WS01 DNS must point to $DCIPAddress" -ForegroundColor Yellow
                try { Stop-Transcript } catch {}
                exit 1
            }

            # Join domain
            Write-Host ""
            Write-Host "  Enter domain admin credentials:" -ForegroundColor White
            Write-Host "    Username: $DomainNetBIOS\Administrator" -ForegroundColor White
            Write-Host "    Password: (the one you set on DC01 during Windows install)" -ForegroundColor White
            Write-Host ""

            try {
                $cred = Get-Credential -Message "Enter $DomainNetBIOS\Administrator password" `
                    -UserName "$DomainNetBIOS\Administrator"

                Add-Computer -DomainName $DomainFQDN -Credential $cred -Force -ErrorAction Stop

                Set-Content -Path $stageFile -Value "3"
                Write-Host "    [+] Domain join successful! Rebooting..." -ForegroundColor Green
                Register-LabResume
                Start-Sleep -Seconds 5
                try { Stop-Transcript } catch {}
                try { Restart-Computer -Force } catch {}
            } catch {
                Write-Host "    [!] Domain join FAILED: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host ""
                Write-Host "    Fixes:" -ForegroundColor Yellow
                Write-Host "      - Wrong password: try again" -ForegroundColor White
                Write-Host "      - 'RPC unavailable': check DC01 firewall" -ForegroundColor White
                Write-Host "      - 'Domain not found': run nslookup $DomainFQDN" -ForegroundColor White
                Write-Host ""
            }
            try { Stop-Transcript } catch {}
            exit 0
        }
    }

    # ========================================================
    # WS STAGE 3: All Vulnerability Configuration
    # ========================================================
    if ($stage -eq 3) {
        Write-Host "[WS Stage 3/3] Configuring attack paths..." -ForegroundColor Yellow
        Write-Host ""

        Unregister-LabResume

        # Network profile to Private
        Write-Host "[*] Setting network profile..." -ForegroundColor Yellow
        try {
            Get-NetConnectionProfile | Where-Object { $_.NetworkCategory -ne "DomainAuthenticated" } |
                Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue
            Write-Host "    [+] Network profile set to Private" -ForegroundColor Green
        } catch {
            Write-Host "    [=] Network profile already correct" -ForegroundColor DarkGray
        }

        # Pre-create shared ACL rule (used across multiple sections)
        $everyoneRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "Everyone", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
        )
        $everyoneFileRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            "Everyone", "FullControl", "None", "None", "Allow"
        )

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
        if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer")) {
            New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Force | Out-Null
        }
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" `
            -Name "AlwaysInstallElevated" -Value 1 -Type DWord
        if (-not (Test-Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer")) {
            New-Item -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Force | Out-Null
        }
        Set-ItemProperty -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" `
            -Name "AlwaysInstallElevated" -Value 1 -Type DWord
        Write-Host "    [+] AlwaysInstallElevated (MSI runs as SYSTEM)" -ForegroundColor Green

        # Weak Service Binary
        $weakPath = "C:\Services\VulnService"
        New-Item -Path $weakPath -ItemType Directory -Force | Out-Null
        Copy-Item "C:\Windows\System32\notepad.exe" "$weakPath\vulnservice.exe" -Force
        # ($everyoneRule already created at top of Stage 3)
        $acl = Get-Acl $weakPath; $acl.AddAccessRule($everyoneRule); Set-Acl $weakPath $acl
        $acl = Get-Acl "$weakPath\vulnservice.exe"; $acl.AddAccessRule($everyoneFileRule); Set-Acl "$weakPath\vulnservice.exe" $acl
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
            Write-Host "    [+] Weak registry ACL on RegHijackService" -ForegroundColor Green
        }

        # Stored AutoLogon
        $winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        Set-ItemProperty -Path $winlogonPath -Name "DefaultUserName" -Value "svc_autologon"
        Set-ItemProperty -Path $winlogonPath -Name "DefaultPassword" -Value "AutoLogon@2024!"
        Set-ItemProperty -Path $winlogonPath -Name "DefaultDomainName" -Value $DomainNetBIOS
        Set-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -Value "0"
        Write-Host "    [+] Stored AutoLogon creds: svc_autologon / AutoLogon@2024!" -ForegroundColor Green

        # Vulnerable Scheduled Task
        New-Item -Path "C:\ScheduledTasks" -ItemType Directory -Force | Out-Null
        "Write-Host 'Cleanup task running...'" | Out-File "C:\ScheduledTasks\cleanup.ps1"
        $taskFileAcl = Get-Acl "C:\ScheduledTasks\cleanup.ps1"
        $taskFileAcl.AddAccessRule($everyoneFileRule)
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
        $localPass = ConvertTo-SecureString "LabAdmin@2026!" -AsPlainText -Force
        if (-not (Get-LocalUser -Name "operator" -ErrorAction SilentlyContinue)) {
            try {
                New-LocalUser -Name "operator" -Password $localPass `
                    -PasswordNeverExpires -Description "Lab local admin" -ErrorAction Stop | Out-Null
                Add-LocalGroupMember -Group "Administrators" -Member "operator" -ErrorAction Stop
                Write-Host "    [+] Local admin: operator / LabAdmin@2026!" -ForegroundColor Green
            } catch {
                Write-Host "    [!] Failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "    [=] operator exists" -ForegroundColor DarkGray
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
            # Clean up old WMI objects if they exist from a previous run to avoid "already exists" errors
            Get-CimInstance -Namespace "root\subscription" -ClassName "__EventFilter" -Filter "Name='ORSUFilter'" -ErrorAction SilentlyContinue | Remove-CimInstance -ErrorAction SilentlyContinue
            Get-CimInstance -Namespace "root\subscription" -ClassName "CommandLineEventConsumer" -Filter "Name='ORSUConsumer'" -ErrorAction SilentlyContinue | Remove-CimInstance -ErrorAction SilentlyContinue
            Get-CimInstance -Namespace "root\subscription" -ClassName "__FilterToConsumerBinding" -ErrorAction SilentlyContinue | 
                Where-Object { $_.Filter -match "ORSUFilter" -or $_.Consumer -match "ORSUConsumer" } | 
                Remove-CimInstance -ErrorAction SilentlyContinue

            $filter = Set-WmiInstance -Namespace "root\subscription" -Class "__EventFilter" -Arguments @{
                Name = "ORSUFilter"
                EventNamespace = "root\cimv2"
                QueryLanguage = "WQL"
                Query = "SELECT * FROM __InstanceCreationEvent WITHIN 60 WHERE TargetInstance ISA 'Win32_Process' AND TargetInstance.Name = 'notepad.exe'"
            } -ErrorAction Stop
            $consumer = Set-WmiInstance -Namespace "root\subscription" -Class "CommandLineEventConsumer" -Arguments @{
                Name = "ORSUConsumer"
                CommandLineTemplate = "powershell.exe -WindowStyle Hidden -Command `"Write-Host 'WMI persistence'`""
            } -ErrorAction Stop
            Set-WmiInstance -Namespace "root\subscription" -Class "__FilterToConsumerBinding" -Arguments @{
                Filter = $filter; Consumer = $consumer
            } -ErrorAction Stop | Out-Null
            Write-Host "    [+] WMI event subscription (fileless)" -ForegroundColor Green
        } catch {
            Write-Host "    [!] WMI subscription: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # ---- 4/4: Coercion ----
        Write-Host "`n[4/4] Configuring coercion..." -ForegroundColor Yellow
        $webClient = Get-Service -Name WebClient -ErrorAction SilentlyContinue
        if ($webClient) {
            Set-Service -Name WebClient -StartupType Automatic -ErrorAction SilentlyContinue
            Start-Service -Name WebClient -ErrorAction SilentlyContinue
            $wcStatus = (Get-Service WebClient).Status
            if ($wcStatus -eq "Running") {
                Write-Host "    [+] WebClient running" -ForegroundColor Green
            } else {
                Write-Host "    [!] WebClient status: $wcStatus" -ForegroundColor Yellow
            }
        } else {
            Write-Host "    [!] WebClient not available" -ForegroundColor Yellow
        }

        # ---- VERIFICATION ----
        Write-Host "`n[*] Running verification checks..." -ForegroundColor Cyan
        $passed = 0; $failed = 0

        if (Test-ServiceExists "ORSUUpdateService") { Write-Host "    [OK] ORSUUpdateService" -ForegroundColor Green; $passed++ }
        else { Write-Host "    [FAIL] ORSUUpdateService missing" -ForegroundColor Red; $failed++ }

        if (Test-ServiceExists "VulnService") { Write-Host "    [OK] VulnService" -ForegroundColor Green; $passed++ }
        else { Write-Host "    [FAIL] VulnService missing" -ForegroundColor Red; $failed++ }

        $aie = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Name AlwaysInstallElevated -ErrorAction SilentlyContinue
        if ($aie -and $aie.AlwaysInstallElevated -eq 1) { Write-Host "    [OK] AlwaysInstallElevated" -ForegroundColor Green; $passed++ }
        else { Write-Host "    [FAIL] AlwaysInstallElevated not set" -ForegroundColor Red; $failed++ }

        $winrmStatus = (Get-Service WinRM -ErrorAction SilentlyContinue).Status
        if ($winrmStatus -eq "Running") { Write-Host "    [OK] WinRM running" -ForegroundColor Green; $passed++ }
        else { Write-Host "    [FAIL] WinRM not running" -ForegroundColor Red; $failed++ }

        Write-Host ""
        Write-Host "    Verification: $passed passed, $failed failed" -ForegroundColor $(if ($failed -eq 0) {"Green"} else {"Yellow"})

        # Mark complete
        Set-Content -Path $stageFile -Value "done"

        Write-Host ""
        Write-Host "  ================================================================" -ForegroundColor Green
        Write-Host "   WS01 SETUP COMPLETE" -ForegroundColor Green
        Write-Host "  ================================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "  [!] Reboot WS01 for WDigest/LSA changes." -ForegroundColor Yellow
        Write-Host "  [!] Then re-run on DC01: .\Configure-Lab.ps1 -Role DC -Reset" -ForegroundColor Yellow
        Write-Host "      (to configure WS01-dependent items like DCSync, RBCD)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  [!] After that, start attacking from Kali!" -ForegroundColor Yellow
        Write-Host ""
    }

    if ("$stage" -eq "done") {
        Write-Host "[*] WS01 setup is already complete." -ForegroundColor Green
        Write-Host "    Re-run: .\Configure-Lab.ps1 -Reset" -ForegroundColor Gray
    }
}

Write-Host "[*] Configure-Lab.ps1 finished at $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
try { Stop-Transcript } catch {}
