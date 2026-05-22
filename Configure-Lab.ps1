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
try {
    $currentPolicy = Get-ExecutionPolicy -Scope Process
    if ($currentPolicy -eq "Restricted") {
        Write-Host "[!] Setting execution policy to Bypass for this session." -ForegroundColor Yellow
        Set-ExecutionPolicy Bypass -Scope Process -Force
    }
} catch {
    Write-Host "[!] Failed to check/set execution policy: $($_.Exception.Message)" -ForegroundColor Yellow
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

        if ($ipConfig -and $ipConfig.IPAddress) {
            try {
                $ip = $ipConfig.IPAddress
                $octets = $ip.Split(".")
                if ($octets.Count -ge 4) {
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
                    } | Set-Content $netConf -Force -ErrorAction Stop

                    Write-Host "    [+] Detected NAT subnet: $subnet.0/24 (from DHCP: $ip)" -ForegroundColor Green
                    Write-Host "    [+] DC: $subnet.10 | WS: $subnet.20 | Gateway: $subnet.2" -ForegroundColor Green
                    return $conf
                }
            } catch {
                Write-Host "    [!] Error processing DHCP adapter $($adapter.Name): $($_.Exception.Message)" -ForegroundColor Yellow
            }
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
        try {
            Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $DNSServers -ErrorAction Stop
            Write-Host "    [+] DNS: $($DNSServers -join ', ')" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Failed to set DNS: $($_.Exception.Message)" -ForegroundColor Yellow
        }
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
            Write-Host "    [!] Failed to set static IP: $($_.Exception.Message)" -ForegroundColor Red
            try {
                Set-NetIPInterface -InterfaceIndex $adapter.ifIndex -Dhcp Enabled -ErrorAction SilentlyContinue
                Write-Host "    [*] Rolled back to DHCP to restore connectivity." -ForegroundColor Yellow
            } catch {}
            return $false
        }
    }

    try {
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $DNSServers -ErrorAction Stop
        Write-Host "    [+] DNS: $($DNSServers -join ', ')" -ForegroundColor Green
    } catch {
        Write-Host "    [!] Failed to set DNS: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Set network profile to Private (prevents firewall blocking lab traffic)
    try {
        Get-NetConnectionProfile -InterfaceIndex $adapter.ifIndex -ErrorAction SilentlyContinue |
            Where-Object { $_.NetworkCategory -eq "Public" } |
            Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue
    } catch {}

    # Disable Windows Defender Firewall on all profiles (Domain, Private, Public)
    try {
        Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False -ErrorAction SilentlyContinue
        Write-Host "    [+] Windows Defender Firewall disabled for all profiles" -ForegroundColor Green
    } catch {
        Write-Host "    [!] Failed to disable Windows Defender Firewall: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    # Allow ICMP (ping) through firewall (as backup if firewall is re-enabled)
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

    try {
        # Save current role so it persists across reboots
        $roleFile = "$labDir\role.txt"
        if ($Role) { Set-Content -Path $roleFile -Value $Role -Force | Out-Null }

        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
        # Use Start-Process -Verb RunAs to ensure elevation on workstations
        # Pass -Role so the menu does not show again after reboot
        $cmd = "powershell.exe -ExecutionPolicy Bypass -NoProfile -Command `"Start-Process powershell -Verb RunAs -ArgumentList '-ExecutionPolicy Bypass -NoExit -File \`"$scriptPath\`" -Role $Role'`""
        Set-ItemProperty -Path $regPath -Name "LabSetup" -Value $cmd -Force | Out-Null
        Write-Host "    [+] Auto-resume registered (will continue at next login)" -ForegroundColor Green
    } catch {
        Write-Host "    [!] Failed to register auto-resume: $($_.Exception.Message)" -ForegroundColor Yellow
    }
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

    try {
        $defenderPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
        if (-not (Test-Path $defenderPath)) { New-Item -Path $defenderPath -Force | Out-Null }
        Set-ItemProperty -Path $defenderPath -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force | Out-Null
        
        $rtpPath = "$defenderPath\Real-Time Protection"
        if (-not (Test-Path $rtpPath)) { New-Item -Path $rtpPath -Force | Out-Null }
        Set-ItemProperty -Path $rtpPath -Name "DisableRealtimeMonitoring" -Value 1 -Type DWord -Force | Out-Null
        Set-ItemProperty -Path $rtpPath -Name "DisableBehaviorMonitoring" -Value 1 -Type DWord -Force | Out-Null
        Set-ItemProperty -Path $rtpPath -Name "DisableIOAVProtection" -Value 1 -Type DWord -Force | Out-Null
        Set-ItemProperty -Path $rtpPath -Name "DisableScanOnRealtimeEnable" -Value 1 -Type DWord -Force | Out-Null
        Write-Host "    [+] Defender registry policies set" -ForegroundColor Green
    } catch {
        Write-Host "    [!] Failed to set some Defender registry policies: $($_.Exception.Message)" -ForegroundColor Yellow
    }

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

function Stop-LabServiceIfRunning {
    param([string]$Name)
    if (Test-ServiceExists $Name) {
        $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq "Running") {
            try {
                Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
                # Wait up to 5 seconds for it to stop
                $timeout = 5
                while ($timeout -gt 0) {
                    $status = (Get-Service -Name $Name -ErrorAction SilentlyContinue).Status
                    if ($status -eq "Stopped" -or $status -eq "StopPending") { break }
                    Start-Sleep -Seconds 1
                    $timeout--
                }
                Start-Sleep -Seconds 1 # Extra grace period for file handles to close
            } catch {}
        }
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

function Add-LabGroupMember {
    param(
        [string]$GroupName,
        [string]$MemberIdentity
    )
    try {
        $group = Get-ADGroup -Identity $GroupName -Properties Member -ErrorAction Stop
        # Resolve member distinguishedName
        $memberDN = $null
        $memberObj = Get-ADUser -Identity $MemberIdentity -ErrorAction SilentlyContinue
        if ($memberObj) {
            $memberDN = $memberObj.DistinguishedName
        } else {
            $memberObj = Get-ADGroup -Identity $MemberIdentity -ErrorAction SilentlyContinue
            if ($memberObj) {
                $memberDN = $memberObj.DistinguishedName
            } else {
                $memberObj = Get-ADComputer -Identity $MemberIdentity -ErrorAction SilentlyContinue
                if ($memberObj) {
                    $memberDN = $memberObj.DistinguishedName
                }
            }
        }
        
        if ($null -eq $memberDN) {
            # Fallback to check by name match if DN cannot be resolved
            $memberDN = $MemberIdentity
        }

        $exists = $false
        if ($group.Member) {
            $memberShort = ($memberDN -replace '^CN=', '').Split(',')[0]
            foreach ($m in $group.Member) {
                $mShort = ($m -replace '^CN=', '').Split(',')[0]
                if ($m -eq $memberDN -or $mShort -eq $memberShort -or $mShort -eq $MemberIdentity) {
                    $exists = $true
                    break
                }
            }
        }

        if ($exists) {
            Write-Host "    [=] Group member exists: $MemberIdentity -> $GroupName" -ForegroundColor DarkGray
        } else {
            Add-ADGroupMember -Identity $GroupName -Members $MemberIdentity -ErrorAction Stop
            Write-Host "    [+] Added member: $MemberIdentity -> $GroupName" -ForegroundColor Green
        }
    } catch {
        # Fallback to direct attempt in case of error
        try {
            Add-ADGroupMember -Identity $GroupName -Members $MemberIdentity -ErrorAction Stop
            Write-Host "    [+] Added member: $MemberIdentity -> $GroupName" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Failed to add $MemberIdentity to ${GroupName}: $($_.Exception.Message)" -ForegroundColor Yellow
        }
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
        try {
            $addsFeature = Get-WindowsFeature AD-Domain-Services -ErrorAction Stop
            if (-not $addsFeature.Installed) {
                $result = Install-WindowsFeature AD-Domain-Services -IncludeManagementTools -ErrorAction Stop
                if ($result.Success) {
                    Write-Host "    [+] AD DS feature installed" -ForegroundColor Green
                } else {
                    Write-Host "    [!] AD DS install FAILED." -ForegroundColor Red
                    Set-Content -Path $stageFile -Value "1" -Force -ErrorAction SilentlyContinue
                    try { Stop-Transcript } catch {}
                    exit 1
                }
            } else {
                Write-Host "    [=] AD DS already installed" -ForegroundColor DarkGray
            }
        } catch {
            Write-Host "    [!] AD DS feature installation error: $($_.Exception.Message)" -ForegroundColor Red
            Set-Content -Path $stageFile -Value "1" -Force -ErrorAction SilentlyContinue
            try { Stop-Transcript } catch {}
            exit 1
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
                Write-Host "    [!] ERROR: Rename failed: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "    [!] Proceeding with incorrect hostname will break Active Directory configuration." -ForegroundColor Yellow
                try { Set-Content -Path $stageFile -Value "1" -Force -ErrorAction SilentlyContinue } catch {}
                try { Stop-Transcript } catch {}
                exit 1
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
            try { Restart-Computer -Force -ErrorAction Stop } catch {}
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
        $domainRoleCheck = 0
        try {
            $domainRoleCheck = (Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).DomainRole
        } catch {
            Write-Host "    [!] CIM DomainRole check failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        if ($domainRoleCheck -in @(4, 5)) {
            Write-Host "    [=] Already a Domain Controller. Skipping reboot and proceeding to Stage 3." -ForegroundColor Green
            try { Set-Content -Path $stageFile -Value "3" -Force -ErrorAction Stop } catch {}
            $stage = 3
        } else {
            # Verify AD DS feature
            try {
                $addsCheck = Get-WindowsFeature AD-Domain-Services -ErrorAction Stop
                if (-not $addsCheck.Installed) {
                    Write-Host "    [!] AD DS not installed. Installing..." -ForegroundColor Yellow
                    $result = Install-WindowsFeature AD-Domain-Services -IncludeManagementTools -ErrorAction Stop
                    if (-not $result.Success) {
                        Write-Host "    [!] AD DS install failed." -ForegroundColor Red
                        try { Stop-Transcript } catch {}
                        exit 1
                    }
                    Register-LabResume
                    Start-Sleep -Seconds 3
                    try { Stop-Transcript } catch {}
                    try { Restart-Computer -Force -ErrorAction Stop } catch {}
                    exit 0
                }
            } catch {
                Write-Host "    [!] AD DS verification failed: $($_.Exception.Message)" -ForegroundColor Red
                try { Stop-Transcript } catch {}
                exit 1
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
                try { Restart-Computer -Force -ErrorAction Stop } catch {}
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
        $skippedWS01Items = @()

        # Wait for AD
        if (-not (Wait-ForADReady -MaxWaitSeconds 120)) {
            Write-Host "    [!] AD not responding. Wait a minute and run again." -ForegroundColor Red
            try { Stop-Transcript } catch {}
            exit 1
        }

        $domain = $null
        try {
            Import-Module ActiveDirectory -ErrorAction Stop
            $domain = (Get-ADDomain).DistinguishedName
        } catch {
            Write-Host "    [!] Failed to load ActiveDirectory module or connect to AD: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "    [!] Stage 3 cannot continue. Fix the AD service and run again." -ForegroundColor Yellow
            try { Stop-Transcript } catch {}
            exit 1
        }

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

        Add-LabGroupMember -GroupName "Domain Admins" -MemberIdentity "ammulu.orsu"

        $attackerUser = Get-ADUser -Filter "SamAccountName -eq 'vamsi.krishna'" -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $attackerUser) {
            Write-Host "    [!] Attacker user vamsi.krishna not found. Some ACL modifications will fail." -ForegroundColor Yellow
        }

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

        # GenericAll: vamsi.krishna on lakshmi.devi
        $targetUser = Get-ADUser -Filter "SamAccountName -eq 'lakshmi.devi'" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($attackerUser -and $targetUser) {
            try {
                $gaRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                    $attackerUser.SID,
                    [System.DirectoryServices.ActiveDirectoryRights]::GenericAll,
                    [System.Security.AccessControl.AccessControlType]::Allow
                )
                Set-LabACE -TargetDN $targetUser.DistinguishedName -Rule $gaRule `
                    -Label "GenericAll: vamsi.krishna -> lakshmi.devi"
            } catch {
                Write-Host "    [!] GenericAll ACE setup failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "    [!] GenericAll skipped: vamsi.krishna or lakshmi.devi not found" -ForegroundColor Yellow
        }

        # IT_Admins group + WriteDACL
        try {
            if (-not (Get-ADGroup -Filter "Name -eq 'IT_Admins'" -ErrorAction SilentlyContinue)) {
                New-ADGroup -Name "IT_Admins" -GroupScope Global -GroupCategory Security `
                    -Path $domain -Description "IT Administrators" -ErrorAction Stop
                Write-Host "    [+] Group created: IT_Admins" -ForegroundColor Green
            }
            Add-LabGroupMember -GroupName "Domain Admins" -MemberIdentity "IT_Admins"
        } catch {
            Write-Host "    [!] IT_Admins setup error: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        $itAdmins = Get-ADGroup -Filter "Name -eq 'IT_Admins'" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($attackerUser -and $itAdmins) {
            try {
                $wdRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                    $attackerUser.SID,
                    [System.DirectoryServices.ActiveDirectoryRights]::WriteDacl,
                    [System.Security.AccessControl.AccessControlType]::Allow
                )
                Set-LabACE -TargetDN $itAdmins.DistinguishedName -Rule $wdRule `
                    -Label "WriteDACL: vamsi.krishna -> IT_Admins (member of DA)"
            } catch {
                Write-Host "    [!] WriteDACL ACE setup failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "    [!] WriteDACL skipped: vamsi.krishna or IT_Admins not found" -ForegroundColor Yellow
        }

        # ForceChangePassword: divya on ammulu.orsu
        $daUser = Get-ADUser -Filter "SamAccountName -eq 'ammulu.orsu'" -ErrorAction SilentlyContinue | Select-Object -First 1
        $divyaUser = Get-ADUser -Filter "SamAccountName -eq 'divya'" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($daUser -and $divyaUser) {
            try {
                $fcpGuid = [GUID]"00299570-246d-11d0-a768-00aa006e0529"
                $fcpRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                    $divyaUser.SID,
                    [System.DirectoryServices.ActiveDirectoryRights]::ExtendedRight,
                    [System.Security.AccessControl.AccessControlType]::Allow,
                    $fcpGuid
                )
                Set-LabACE -TargetDN $daUser.DistinguishedName -Rule $fcpRule `
                    -Label "ForceChangePassword: divya -> ammulu.orsu (DA)"
            } catch {
                Write-Host "    [!] ForceChangePassword ACE setup failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "    [!] ForceChangePassword skipped: ammulu.orsu or divya not found" -ForegroundColor Yellow
        }

        # GenericWrite: vamsi.krishna on sai.kiran
        $saiKiran = Get-ADUser -Filter "SamAccountName -eq 'sai.kiran'" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($attackerUser -and $saiKiran) {
            try {
                $gwRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                    $attackerUser.SID,
                    [System.DirectoryServices.ActiveDirectoryRights]::GenericWrite,
                    [System.Security.AccessControl.AccessControlType]::Allow
                )
                Set-LabACE -TargetDN $saiKiran.DistinguishedName -Rule $gwRule `
                    -Label "GenericWrite: vamsi.krishna -> sai.kiran (targeted Kerberoasting)"
            } catch {
                Write-Host "    [!] GenericWrite ACE setup failed: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "    [!] GenericWrite skipped: vamsi.krishna or sai.kiran not found" -ForegroundColor Yellow
        }

        # ---- 6/10: DA Paths ----
        Write-Host "`n[6/10] Configuring Domain Admin paths..." -ForegroundColor Yellow

        # Nested group chain
        try {
            $groupChain = @(
                @{ Name="HelpDesk_Team"; Desc="First-level support" },
                @{ Name="IT_Support"; Desc="Second-level IT support" },
                @{ Name="Server_Admins"; Desc="Server administrators" }
            )
            foreach ($g in $groupChain) {
                if (-not (Get-ADGroup -Filter "Name -eq '$($g.Name)'" -ErrorAction SilentlyContinue)) {
                    New-ADGroup -Name $g.Name -GroupScope Global -GroupCategory Security -Description $g.Desc -ErrorAction Stop
                    Write-Host "    [+] Created Group: $($g.Name)" -ForegroundColor Green
                } else {
                    Write-Host "    [=] Group exists: $($g.Name)" -ForegroundColor DarkGray
                }
            }
            Add-LabGroupMember -GroupName "IT_Support" -MemberIdentity "HelpDesk_Team"
            Add-LabGroupMember -GroupName "Server_Admins" -MemberIdentity "IT_Support"
            Add-LabGroupMember -GroupName "Domain Admins" -MemberIdentity "Server_Admins"
            Add-LabGroupMember -GroupName "HelpDesk_Team" -MemberIdentity "harsha.vardhan"
            Write-Host "    [+] Chain: harsha.vardhan -> HelpDesk -> IT_Support -> Server_Admins -> DA" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Nested group chain configuration error: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # svc_backup: DA with SPN
        try {
            $svcBackupPass = ConvertTo-SecureString "Backup@2024!" -AsPlainText -Force
            if (-not (Get-ADUser -Filter "SamAccountName -eq 'svc_backup'" -ErrorAction SilentlyContinue)) {
                New-ADUser -Name "svc_backup" -SamAccountName "svc_backup" `
                    -UserPrincipalName "svc_backup@$DomainFQDN" -Path $serviceOU `
                    -AccountPassword $svcBackupPass -Enabled $true `
                    -PasswordNeverExpires $true -Description "Backup Service Account" -ErrorAction Stop
                Write-Host "    [+] Created user: svc_backup" -ForegroundColor Green
            } else {
                Write-Host "    [=] User exists: svc_backup" -ForegroundColor DarkGray
            }
            Add-LabGroupMember -GroupName "Domain Admins" -MemberIdentity "svc_backup"
            Set-ADUser -Identity "svc_backup" -ServicePrincipalNames @{Add="backup/dc01.orsubank.local"} -ErrorAction Stop
            Write-Host "    [+] svc_backup: DA with SPN (backup/dc01.orsubank.local)" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Failed to configure svc_backup: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # DCSync rights for WS01$
        $ws01 = $null
        try {
            $ws01 = Get-ADComputer -Filter "Name -eq 'WS01'" -ErrorAction SilentlyContinue
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
        } catch {
            Write-Host "    [!] Failed to configure DCSync rights: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # ---- 7/10: Delegation ----
        Write-Host "`n[7/10] Configuring delegation..." -ForegroundColor Yellow

        try {
            if ($ws01) {
                Set-ADComputer -Identity "WS01" -TrustedForDelegation $true -ErrorAction Stop
                Write-Host "    [+] Unconstrained Delegation on WS01" -ForegroundColor Green
            } else {
                $skippedWS01Items += "Unconstrained Delegation"
                Write-Host "    [!] WS01 not found. Unconstrained Delegation skipped." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "    [!] Failed to set Unconstrained Delegation on WS01: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # Constrained: svc_web -> CIFS/DC01
        try {
            $svcWebPass = ConvertTo-SecureString "WebSvc@2024!" -AsPlainText -Force
            if (-not (Get-ADUser -Filter "SamAccountName -eq 'svc_web'" -ErrorAction SilentlyContinue)) {
                New-ADUser -Name "svc_web" -SamAccountName "svc_web" `
                    -UserPrincipalName "svc_web@$DomainFQDN" -Path $serviceOU `
                    -AccountPassword $svcWebPass -Enabled $true `
                    -PasswordNeverExpires $true -Description "Web Application Service" -ErrorAction Stop
                    Write-Host "    [+] Created user: svc_web" -ForegroundColor Green
            } else {
                Write-Host "    [=] User exists: svc_web" -ForegroundColor DarkGray
            }
            Set-ADUser -Identity "svc_web" -ServicePrincipalNames @{Add="HTTP/intranet.orsubank.local"} -ErrorAction Stop
            Set-ADUser -Identity "svc_web" -Replace @{
                "msDS-AllowedToDelegateTo" = @("CIFS/DC01.orsubank.local", "CIFS/DC01")
            } -ErrorAction Stop
            Set-ADAccountControl -Identity "svc_web" -TrustedToAuthForDelegation $true -ErrorAction Stop
            Write-Host "    [+] Constrained Delegation: svc_web -> CIFS/DC01" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Failed to configure Constrained Delegation: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # RBCD: vamsi.krishna can write delegation on WS01
        try {
            if ($ws01) {
                if ($attackerUser) {
                    $rbcdGuid = [GUID]"3f78c3e5-f79a-46bd-a0b8-9d18116ddc79"
                    $rbcdRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                        $attackerUser.SID, "WriteProperty", "Allow", $rbcdGuid
                    )
                    Set-LabACE -TargetDN $ws01.DistinguishedName -Rule $rbcdRule `
                        -Label "RBCD write: vamsi.krishna -> WS01"
                } else {
                    Write-Host "    [!] RBCD skipped: vamsi.krishna user not found" -ForegroundColor Yellow
                }
            } else {
                $skippedWS01Items += "RBCD"
            }
        } catch {
            Write-Host "    [!] Failed to configure RBCD: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # ---- 8/10: ADCS ----
        Write-Host "`n[8/10] Installing AD Certificate Services..." -ForegroundColor Yellow

        $configNC = $null
        $domainUsersSID = $null
        $enrollGuid = [GUID]"0e10c968-78fb-11d2-90d4-00c04f79dc55"

        try { $configNC = (Get-ADRootDSE).configurationNamingContext } catch {}
        try { $domainUsersSID = (Get-ADGroup -Filter "Name -eq 'Domain Users'" | Select-Object -First 1).SID } catch {}

        try {
            # Step 1: Install Windows features if not already installed
            $adcsFeature = Get-WindowsFeature ADCS-Cert-Authority
            if (-not $adcsFeature.Installed) {
                Write-Host "    [*] Installing ADCS (takes a few minutes)..." -ForegroundColor Gray
                # Install CA feature + Web-Windows-Auth now; ADCS-Web-Enrollment installed after CA is running
                $result = Install-WindowsFeature ADCS-Cert-Authority, ADCS-Web-Enrollment, Web-Windows-Auth -IncludeManagementTools
                if ($result.Success) {
                    Write-Host "    [+] ADCS features installed" -ForegroundColor Green
                } else {
                    Write-Host "    [!] ADCS install failed." -ForegroundColor Red
                }
            } else {
                Write-Host "    [=] ADCS features already installed" -ForegroundColor DarkGray
            }

            # Step 2: Check if *any* CA is configured using the MS-verified registry subkeys method
            $caConfigured = $false
            $caConfigKey = "HKLM:\SYSTEM\CurrentControlSet\Services\CertSvc\Configuration"
            if (Test-Path $caConfigKey) {
                $subkeys = (Get-Item $caConfigKey -ErrorAction SilentlyContinue).GetSubKeyNames()
                if ($subkeys -and $subkeys.Count -gt 0) {
                    $caConfigured = $true
                    $configuredCAName = $subkeys[0]
                }
            }

            if (-not $caConfigured) {
                Write-Host "    [*] CA not configured. Configuring Enterprise Root CA..." -ForegroundColor Gray
                try {
                    Install-AdcsCertificationAuthority -CAType EnterpriseRootCA `
                        -CACommonName "ORSUBANK-CA" -KeyLength 2048 `
                        -HashAlgorithmName SHA256 -ValidityPeriod Years `
                        -ValidityPeriodUnits 10 -Force -ErrorAction Stop | Out-Null
                    Write-Host "    [+] Enterprise Root CA: ORSUBANK-CA configured" -ForegroundColor Green
                } catch {
                    Write-Host "    [!] CA configuration failed: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            } else {
                Write-Host "    [=] Certificate Authority already configured ($configuredCAName)" -ForegroundColor DarkGray
            }

            # Step 3: Ensure CertSvc is running (required before Install-AdcsWebEnrollment)
            # Per Microsoft docs, CertSvc starts automatically after configuration but must be verified
            Write-Host "    [*] Waiting for CertSvc to start..." -ForegroundColor Gray
            $certSvcReady = $false
            for ($w = 1; $w -le 12; $w++) {
                $svc = Get-Service -Name CertSvc -ErrorAction SilentlyContinue
                if ($svc -and $svc.Status -eq "Running") {
                    $certSvcReady = $true
                    Write-Host "    [+] CertSvc is running" -ForegroundColor Green
                    break
                }
                if ($svc -and $svc.Status -ne "Running") {
                    Start-Service CertSvc -ErrorAction SilentlyContinue
                }
                Start-Sleep -Seconds 5
            }
            if (-not $certSvcReady) {
                Write-Host "    [!] CertSvc did not start within 60s. CA may not function correctly." -ForegroundColor Yellow
            }

            # Step 4: Ensure W3SVC (IIS) is running
            Start-Service W3SVC -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 3

            # Step 5: Configure Web Enrollment (must be AFTER CertSvc is running per Microsoft ordering requirements)
            $webEnrollConfigured = $false
            try {
                Import-Module WebAdministration -ErrorAction SilentlyContinue
                if (Get-Command Get-WebApplication -ErrorAction SilentlyContinue) {
                    $webEnrollConfigured = [bool](Get-WebApplication -Name "certsrv" -ErrorAction SilentlyContinue)
                }
            } catch {}

            if (-not $webEnrollConfigured) {
                Write-Host "    [*] Configuring Web Enrollment (CertSrv)..." -ForegroundColor Gray
                try {
                    Install-AdcsWebEnrollment -Force -ErrorAction Stop | Out-Null
                    Write-Host "    [+] Web Enrollment configured (/CertSrv registered in IIS)" -ForegroundColor Green
                    # IIS reset to ensure the virtual directory is fully registered
                    & "$env:SystemRoot\System32\iisreset.exe" /noforce 2>$null | Out-Null
                    Start-Sleep -Seconds 3
                } catch {
                    Write-Host "    [!] Web Enrollment: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            } else {
                Write-Host "    [=] Web Enrollment (/CertSrv) already configured in IIS" -ForegroundColor DarkGray
            }
        } catch {
            Write-Host "    [!] ADCS configuration error: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # Step 6: Wait for certificate templates to appear in AD Configuration partition
        # After CA installation there is a replication delay before pKICertificateTemplate objects are visible
        # Per MS docs: poll with retry loop rather than a fixed sleep
        $templatesReady = $false
        if ($configNC) {
            $templateContainerDN = "CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNC"
            Write-Host "    [*] Waiting for certificate templates to appear in AD..." -ForegroundColor Gray
            for ($t = 1; $t -le 12; $t++) {
                try {
                    $templateContainer = Get-ADObject -Identity $templateContainerDN -ErrorAction Stop
                    # Also verify at least the User template exists (most basic built-in template)
                    $userTplCheck = Get-ADObject -Identity "CN=User,$templateContainerDN" -ErrorAction Stop
                    if ($templateContainer -and $userTplCheck) {
                        $templatesReady = $true
                        Write-Host "    [+] Certificate templates available in AD (after ${t}x5s wait)" -ForegroundColor Green
                        break
                    }
                } catch {
                    Start-Sleep -Seconds 5
                }
            }
            if (-not $templatesReady) {
                Write-Host "    [!] Certificate templates not yet in AD after 60s. ESC1/ESC4 will be skipped." -ForegroundColor Yellow
            }
        }

        # ESC1: User template allows SAN (CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT = 0x00000001)
        if ($configNC -and $templatesReady) {
            Write-Host "    [*] Configuring ESC1..." -ForegroundColor Gray
            try {
                $userTemplateDN = "CN=User,CN=Certificate Templates,CN=Public Key Services,CN=Services,$configNC"
                $userTemplateObj = Get-ADObject -Identity $userTemplateDN -ErrorAction SilentlyContinue
                if (-not $userTemplateObj) {
                    Write-Host "    [!] ESC1: User template not found in AD." -ForegroundColor Yellow
                } else {
                    # Use ADSI Put()/SetInfo() - the correct MS-documented method
                    # CommitChanges() is NOT correct; SetInfo() commits Put() staged changes
                    $templateAdsi = [ADSI]"LDAP://$userTemplateDN"
                    $currentFlags = [int]$templateAdsi.Properties["msPKI-Certificate-Name-Flag"].Value
                    $newFlags = $currentFlags -bor 0x00000001   # CT_FLAG_ENROLLEE_SUPPLIES_SUBJECT
                    $templateAdsi.Put("msPKI-Certificate-Name-Flag", $newFlags)
                    $templateAdsi.SetInfo()

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
                $webTemplateObj = Get-ADObject -Identity $webTemplateDN -ErrorAction SilentlyContinue
                if (-not $webTemplateObj) {
                    Write-Host "    [!] ESC4: WebServer template not found in AD." -ForegroundColor Yellow
                } else {
                    if ($attackerUser) {
                        $writeRule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                            $attackerUser.SID,
                            [System.DirectoryServices.ActiveDirectoryRights]::GenericWrite,
                            [System.Security.AccessControl.AccessControlType]::Allow
                        )
                        Set-LabACE -TargetDN $webTemplateDN -Rule $writeRule -Label "ESC4: vamsi.krishna -> GenericWrite on WebServer template"
                    } else {
                        Write-Host "    [!] ESC4 skipped: vamsi.krishna user not found" -ForegroundColor Yellow
                    }

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
        } elseif (-not $templatesReady) {
            Write-Host "    [!] ESC1/ESC4 skipped: certificate templates not yet visible in AD." -ForegroundColor Yellow
        } else {
            Write-Host "    [!] Could not read AD config. ESC1/ESC4 skipped." -ForegroundColor Yellow
        }

        # ESC8: Web Enrollment without SSL or EPA (NTLM relay attack surface)
        Write-Host "    [*] Configuring ESC8..." -ForegroundColor Gray

        # Unlock IIS configuration sections globally using correct appcmd /section: syntax (not -section:)
        # Per Microsoft IIS documentation: appcmd unlock config /section:<sectionName>
        # Note: appcmd.exe is a native Win32 binary; -ErrorAction SilentlyContinue is a PS param and does NOT apply
        try {
            $appcmdPath = "$env:SystemRoot\System32\inetsrv\appcmd.exe"
            if (Test-Path $appcmdPath) {
                Write-Host "    [*] Unlocking IIS configuration sections via appcmd..." -ForegroundColor Gray
                & $appcmdPath unlock config "/section:system.webServer/security/authentication/windowsAuthentication" 2>$null | Out-Null
                & $appcmdPath unlock config "/section:system.webServer/security/authentication/anonymousAuthentication" 2>$null | Out-Null
                & $appcmdPath unlock config "/section:system.webServer/security/access" 2>$null | Out-Null
            }
        } catch {}

        $esc8Configured = $false
        for ($i = 1; $i -le 3; $i++) {
            try {
                Import-Module WebAdministration -ErrorAction Stop

                # Per MS docs: use Get-WebApplication to check if /CertSrv virtual directory exists
                $certSrvApp = Get-WebApplication -Name "certsrv" -ErrorAction SilentlyContinue
                if (-not $certSrvApp) {
                    throw "IIS virtual directory /CertSrv not registered yet. Retry $i/3."
                }

                # Use -PSPath 'IIS:\' -Location 'Default Web Site/CertSrv' format (most reliable for locked sections)
                # Per MS docs: this pattern handles sections locked in applicationHost.config correctly

                # Disable SSL requirement (sslFlags = None = 0; 'Ssl' = 8 would require SSL)
                Set-WebConfigurationProperty `
                    -PSPath 'IIS:\' `
                    -Location 'Default Web Site/CertSrv' `
                    -Filter "system.webServer/security/access" `
                    -Name "sslFlags" -Value "None" -ErrorAction Stop

                # Disable Extended Protection (EPA) - tokenChecking must be set on the extendedProtection sub-element
                # tokenChecking values: None=0, Allow=1, Require=2
                Set-WebConfigurationProperty `
                    -PSPath 'IIS:\' `
                    -Location 'Default Web Site/CertSrv' `
                    -Filter "system.webServer/security/authentication/windowsAuthentication/extendedProtection" `
                    -Name "tokenChecking" -Value "None" -ErrorAction Stop

                # Enable Windows Authentication (NTLM)
                Set-WebConfigurationProperty `
                    -PSPath 'IIS:\' `
                    -Location 'Default Web Site/CertSrv' `
                    -Filter "system.webServer/security/authentication/windowsAuthentication" `
                    -Name "enabled" -Value $true -ErrorAction Stop

                # Disable Anonymous Authentication
                Set-WebConfigurationProperty `
                    -PSPath 'IIS:\' `
                    -Location 'Default Web Site/CertSrv' `
                    -Filter "system.webServer/security/authentication/anonymousAuthentication" `
                    -Name "enabled" -Value $false -ErrorAction Stop

                # IIS reset applies config changes cleanly
                & "$env:SystemRoot\System32\iisreset.exe" /noforce 2>$null | Out-Null

                Write-Host "    [+] ESC8: NTLM relay to Web Enrollment (no SSL, no EPA, NTLM forced)" -ForegroundColor Green
                $esc8Configured = $true
                break
            } catch {
                Write-Host "    [*] ESC8 attempt $i failed: $($_.Exception.Message). Retrying in 5s..." -ForegroundColor DarkGray
                Start-Sleep -Seconds 5
            }
        }
        if (-not $esc8Configured) {
            Write-Host "    [!] ESC8 configuration failed after 3 attempts." -ForegroundColor Yellow
        }

        # ---- 9/10: Credential Exposure ----
        Write-Host "`n[9/10] Configuring credential exposure..." -ForegroundColor Yellow

        try {
            $wdigestPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest"
            if (-not (Test-Path $wdigestPath)) { New-Item -Path $wdigestPath -Force | Out-Null }
            Set-ItemProperty -Path $wdigestPath -Name "UseLogonCredential" -Value 1 -Type DWord -Force -ErrorAction Stop
            Write-Host "    [+] WDigest enabled (cleartext in LSASS after next login)" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Failed to enable WDigest: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value 0 -Type DWord -Force -ErrorAction Stop
            Write-Host "    [+] LSA Protection disabled" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Failed to disable LSA Protection: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        try {
            $dgPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
            if (-not (Test-Path $dgPath)) { New-Item -Path $dgPath -Force | Out-Null }
            Set-ItemProperty -Path $dgPath -Name "EnableVirtualizationBasedSecurity" -Value 0 -Type DWord -Force -ErrorAction Stop
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "LsaCfgFlags" -Value 0 -Type DWord -Force -ErrorAction Stop
            Write-Host "    [+] Credential Guard disabled" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Failed to disable Credential Guard: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # Plant credential files
        try {
            @("C:\IT", "C:\Backup", "C:\Scripts") | ForEach-Object {
                if (-not (Test-Path $_)) {
                    New-Item -Path $_ -ItemType Directory -Force | Out-Null
                }
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
"@ | Set-Content "C:\IT\passwords.txt" -ErrorAction Stop

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
"@ | Set-Content "C:\Backup\database_credentials.txt" -ErrorAction Stop

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
"@ | Set-Content "C:\Scripts\service_accounts.txt" -ErrorAction Stop
            Write-Host "    [+] Credential files planted" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Failed to plant credential files: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # ---- 10/10: Coercion ----
        Write-Host "`n[10/10] Configuring coercion..." -ForegroundColor Yellow
        try {
            Set-Service -Name Spooler -StartupType Automatic -ErrorAction Stop
            Start-Service -Name Spooler -ErrorAction Stop
            $spoolerStatus = (Get-Service -Name Spooler -ErrorAction Stop).Status
            if ($spoolerStatus -eq "Running") {
                Write-Host "    [+] Print Spooler running" -ForegroundColor Green
            } else {
                Write-Host "    [!] Print Spooler not running ($spoolerStatus)" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "    [!] Failed to configure Print Spooler: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # ---- VERIFICATION ----
        Write-Host "`n[*] Running verification checks..." -ForegroundColor Cyan
        $passed = 0; $failed = 0

        try {
            $userCount = 0
            $users = Get-ADUser -Filter * -SearchBase $employeesOU -ErrorAction Stop
            if ($users) { $userCount = ($users | Measure-Object).Count }
            if ($userCount -ge 10) { Write-Host "    [OK] $userCount domain users" -ForegroundColor Green; $passed++ }
            else { Write-Host "    [FAIL] Only $userCount users (expected 10)" -ForegroundColor Red; $failed++ }
        } catch {
            Write-Host "    [FAIL] Could not verify domain users count: $($_.Exception.Message)" -ForegroundColor Red; $failed++
        }

        try {
            $spnCount = 0
            $spnUsers = Get-ADUser -Filter {ServicePrincipalName -like "*"} -Properties ServicePrincipalName -ErrorAction Stop
            if ($spnUsers) { $spnCount = ($spnUsers | Measure-Object).Count }
            if ($spnCount -ge 5) { Write-Host "    [OK] $spnCount SPN accounts" -ForegroundColor Green; $passed++ }
            else { Write-Host "    [FAIL] Only $spnCount SPN accounts (expected 5+)" -ForegroundColor Red; $failed++ }
        } catch {
            Write-Host "    [FAIL] Could not verify SPN accounts count: $($_.Exception.Message)" -ForegroundColor Red; $failed++
        }

        try {
            $asrepCount = 0
            $asrepUsers = Get-ADUser -Filter {DoesNotRequirePreAuth -eq $true} -ErrorAction Stop
            if ($asrepUsers) { $asrepCount = ($asrepUsers | Measure-Object).Count }
            if ($asrepCount -ge 3) { Write-Host "    [OK] $asrepCount AS-REP roastable" -ForegroundColor Green; $passed++ }
            else { Write-Host "    [FAIL] Only $asrepCount AS-REP accounts (expected 3)" -ForegroundColor Red; $failed++ }
        } catch {
            Write-Host "    [FAIL] Could not verify AS-REP accounts count: $($_.Exception.Message)" -ForegroundColor Red; $failed++
        }

        try {
            $caService = Get-Service -Name CertSvc -ErrorAction Stop
            if ($caService -and $caService.Status -eq "Running") { Write-Host "    [OK] Certificate Authority running" -ForegroundColor Green; $passed++ }
            else { Write-Host "    [FAIL] CA not running" -ForegroundColor Red; $failed++ }
        } catch {
            Write-Host "    [FAIL] CA service check failed: $($_.Exception.Message)" -ForegroundColor Red; $failed++
        }

        # Test internet (DNS forwarder)
        try {
            $internetOK = Test-Connection 8.8.8.8 -Count 1 -Quiet -ErrorAction SilentlyContinue
            if ($internetOK) { Write-Host "    [OK] Internet access works" -ForegroundColor Green; $passed++ }
            else { Write-Host "    [WARN] No internet (check gateway $Gateway)" -ForegroundColor Yellow }
        } catch {
            Write-Host "    [WARN] Internet connection check failed" -ForegroundColor Yellow
        }

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

        try {
            Disable-WindowsDefender
        } catch {
            Write-Host "    [!] Failed to disable Windows Defender: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # Save stage BEFORE IP change
        try {
            Set-Content -Path $stageFile -Value "2" -ErrorAction Stop
        } catch {
            Write-Host "    [!] Failed to save stage file: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        try {
            Set-LabStaticIP -IPAddress $WSIPAddress -Prefix $SubnetPrefix `
                -GatewayAddr $Gateway -DNSServers @($DCIPAddress)
        } catch {
            Write-Host "    [!] Failed to set static IP: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # Rename
        $renamed = $false
        if ($env:COMPUTERNAME -ne $WSHostname) {
            Write-Host "`n[*] Renaming to $WSHostname..." -ForegroundColor Yellow
            try {
                Rename-Computer -NewName $WSHostname -Force -ErrorAction Stop
                Write-Host "    [+] Rename scheduled for after reboot" -ForegroundColor Green
                $renamed = $true
            } catch {
                Write-Host "    [!] ERROR: Rename failed: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host "    [!] Proceeding with incorrect hostname will break Active Directory configuration." -ForegroundColor Yellow
                try { Set-Content -Path $stageFile -Value "1" -Force -ErrorAction SilentlyContinue } catch {}
                try { Stop-Transcript } catch {}
                exit 1
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

            try { Register-LabResume } catch {}
            Start-Sleep -Seconds 10
            try { Stop-Transcript } catch {}
            try { Restart-Computer -Force -ErrorAction Stop } catch {}
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
        $isJoined = $false
        try {
            $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
            if ($cs -and $cs.PartOfDomain -and $cs.Domain -eq $DomainFQDN) {
                $isJoined = $true
            }
        } catch {
            Write-Host "    [!] Error checking domain join status: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        if ($isJoined) {
            Write-Host "    [=] Already joined to $DomainFQDN. Skipping reboot and proceeding to Stage 3." -ForegroundColor Green
            try { Set-Content -Path $stageFile -Value "3" -ErrorAction Stop } catch {}
            $stage = 3
        } else {
            # Test DC
            Write-Host "    [*] Testing connection to DC01 ($DCIPAddress)..." -ForegroundColor Gray
            $dcReachable = $false
            try {
                if (Test-Connection $DCIPAddress -Count 2 -Quiet) {
                    $dcReachable = $true
                }
            } catch {}
            if (-not $dcReachable) {
                Write-Host "    [!] Ping failed. Trying TCP LDAP port (389) connectivity check..." -ForegroundColor Yellow
                try {
                    $tcpTest = Test-NetConnection -ComputerName $DCIPAddress -Port 389 -WarningAction SilentlyContinue
                    if ($tcpTest.TcpTestSucceeded) {
                        $dcReachable = $true
                    }
                } catch {}
            }
            if (-not $dcReachable) {
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
            $dnsResolved = $false
            try {
                $dnsResult = Resolve-DnsName $DomainFQDN -ErrorAction Stop
                Write-Host "    [+] DNS resolves $DomainFQDN -> $($dnsResult[0].IPAddress)" -ForegroundColor Green
                $dnsResolved = $true
            } catch {
                Write-Host "    [!] DNS cannot resolve $DomainFQDN. Attempting self-repair..." -ForegroundColor Yellow
                try {
                    $repairAdapter = Get-NetAdapter | Where-Object {
                        $_.Status -eq "Up" -and
                        $_.InterfaceDescription -notlike "*Loopback*" -and
                        $_.InterfaceDescription -notlike "*Bluetooth*"
                    } | Select-Object -First 1
                    if ($repairAdapter) {
                        Set-DnsClientServerAddress -InterfaceIndex $repairAdapter.ifIndex -ServerAddresses $DCIPAddress -ErrorAction Stop
                        Write-Host "    [+] Forced adapter DNS to $DCIPAddress. Waiting 5s..." -ForegroundColor Green
                        Start-Sleep -Seconds 5
                        $dnsResult = Resolve-DnsName $DomainFQDN -ErrorAction Stop
                        Write-Host "    [+] DNS resolves $DomainFQDN -> $($dnsResult[0].IPAddress) after repair" -ForegroundColor Green
                        $dnsResolved = $true
                    }
                } catch {
                    Write-Host "    [!] DNS repair failed: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            if (-not $dnsResolved) {
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
                try { Register-LabResume } catch {}
                Start-Sleep -Seconds 5
                try { Stop-Transcript } catch {}
                try { Restart-Computer -Force -ErrorAction Stop } catch {}
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

        try {
            Unregister-LabResume
        } catch {}

        # Network profile to Private
        Write-Host "[*] Setting network profile..." -ForegroundColor Yellow
        try {
            Get-NetConnectionProfile | Where-Object { $_.NetworkCategory -ne "DomainAuthenticated" } |
                Set-NetConnectionProfile -NetworkCategory Private -ErrorAction SilentlyContinue
            Write-Host "    [+] Network profile set to Private" -ForegroundColor Green
        } catch {
            Write-Host "    [=] Network profile already correct" -ForegroundColor DarkGray
        }

        # Pre-create shared ACL rules using language-independent SID S-1-1-0 for "Everyone"
        try {
            $everyoneSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-1-0")
            $everyoneRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $everyoneSID, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
            )
            $everyoneFileRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $everyoneSID, "FullControl", "None", "None", "Allow"
            )
            $everyoneRegRule = New-Object System.Security.AccessControl.RegistryAccessRule(
                $everyoneSID, "FullControl", "Allow"
            )
        } catch {
            Write-Host "    [!] Failed to build Everyone rules: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # ---- 1/4: Local Privilege Escalation ----
        Write-Host "`n[1/4] Configuring local privilege escalation..." -ForegroundColor Yellow

        # Unquoted Service Path
        try {
            Stop-LabServiceIfRunning "ORSUUpdateService"
            $vulnPath = "C:\Program Files\ORSU Bank\Update Service"
            if (-not (Test-Path $vulnPath)) {
                New-Item -Path $vulnPath -ItemType Directory -Force | Out-Null
            }
            Copy-Item "C:\Windows\System32\notepad.exe" "$vulnPath\UpdateSvc.exe" -Force -ErrorAction Stop
            New-LabService -Name "ORSUUpdateService" `
                -BinPath "C:\Program Files\ORSU Bank\Update Service\UpdateSvc.exe" `
                -Description "ORSUBANK Automatic Update Service"
            Write-Host "    [+] Service created: ORSUUpdateService" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Failed to configure ORSUUpdateService: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # AlwaysInstallElevated
        try {
            if (-not (Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer")) {
                New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Force | Out-Null
            }
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" `
                -Name "AlwaysInstallElevated" -Value 1 -Type DWord -Force -ErrorAction Stop
            Write-Host "    [+] AlwaysInstallElevated set in HKLM" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Failed to configure AlwaysInstallElevated HKLM: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        try {
            if (-not (Test-Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer")) {
                New-Item -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Force | Out-Null
            }
            Set-ItemProperty -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Installer" `
                -Name "AlwaysInstallElevated" -Value 1 -Type DWord -Force -ErrorAction Stop
            Write-Host "    [+] AlwaysInstallElevated set in HKCU" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Failed to configure AlwaysInstallElevated HKCU: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # Weak Service Binary
        try {
            Stop-LabServiceIfRunning "VulnService"
            $weakPath = "C:\Services\VulnService"
            if (-not (Test-Path $weakPath)) {
                New-Item -Path $weakPath -ItemType Directory -Force | Out-Null
            }
            Copy-Item "C:\Windows\System32\notepad.exe" "$weakPath\vulnservice.exe" -Force -ErrorAction Stop
            
            if ($everyoneRule -and $everyoneFileRule) {
                $acl = Get-Acl $weakPath
                $acl.AddAccessRule($everyoneRule)
                Set-Acl $weakPath $acl
                
                $aclFile = Get-Acl "$weakPath\vulnservice.exe"
                $aclFile.AddAccessRule($everyoneFileRule)
                Set-Acl "$weakPath\vulnservice.exe" $aclFile
            }
            New-LabService -Name "VulnService" -BinPath "$weakPath\vulnservice.exe" `
                -Description "Vulnerable service with weak file permissions"
            Write-Host "    [+] Weak service binary set up (VulnService)" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Failed to configure VulnService: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # Weak Registry Permissions
        try {
            Stop-LabServiceIfRunning "RegHijackService"
            Copy-Item "C:\Windows\System32\notepad.exe" "C:\Windows\Temp\regsvc.exe" -Force -ErrorAction Stop
            New-LabService -Name "RegHijackService" -BinPath "C:\Windows\Temp\regsvc.exe" `
                -Description "Service with weak registry permissions"
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\RegHijackService"
            if (Test-Path $regPath) {
                if ($everyoneRegRule) {
                    $regAcl = Get-Acl $regPath
                    $regAcl.AddAccessRule($everyoneRegRule)
                    Set-Acl $regPath $regAcl
                    Write-Host "    [+] Weak registry ACL on RegHijackService" -ForegroundColor Green
                }
            } else {
                Write-Host "    [!] RegHijackService registry path not found." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "    [!] Failed to configure RegHijackService: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # Stored AutoLogon
        try {
            $winlogonPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
            if (-not (Test-Path $winlogonPath)) {
                New-Item -Path $winlogonPath -Force | Out-Null
            }
            Set-ItemProperty -Path $winlogonPath -Name "DefaultUserName" -Value "svc_autologon" -Force -ErrorAction Stop
            Set-ItemProperty -Path $winlogonPath -Name "DefaultPassword" -Value "AutoLogon@2024!" -Force -ErrorAction Stop
            Set-ItemProperty -Path $winlogonPath -Name "DefaultDomainName" -Value $DomainNetBIOS -Force -ErrorAction Stop
            Set-ItemProperty -Path $winlogonPath -Name "AutoAdminLogon" -Value "0" -Force -ErrorAction Stop
            Write-Host "    [+] Stored AutoLogon creds: svc_autologon / AutoLogon@2024!" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Failed to configure AutoLogon: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # Vulnerable Scheduled Task
        try {
            if (-not (Test-Path "C:\ScheduledTasks")) {
                New-Item -Path "C:\ScheduledTasks" -ItemType Directory -Force | Out-Null
            }
            "Write-Host 'Cleanup task running...'" | Out-File "C:\ScheduledTasks\cleanup.ps1" -Force -ErrorAction Stop
            
            if ($everyoneFileRule) {
                $taskFileAcl = Get-Acl "C:\ScheduledTasks\cleanup.ps1"
                $taskFileAcl.AddAccessRule($everyoneFileRule)
                Set-Acl "C:\ScheduledTasks\cleanup.ps1" $taskFileAcl
            }
            
            $action = New-ScheduledTaskAction -Execute "powershell.exe" `
                -Argument "-ExecutionPolicy Bypass -File C:\ScheduledTasks\cleanup.ps1"
            $trigger = New-ScheduledTaskTrigger -Daily -At "3:00AM"
            $taskPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
            Register-ScheduledTask -TaskName "ORSUCleanup" -Action $action `
                -Trigger $trigger -Principal $taskPrincipal -Force -ErrorAction Stop | Out-Null
            Write-Host "    [+] Scheduled task: ORSUCleanup (SYSTEM, writable script)" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Failed to configure Scheduled Task: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # ---- 2/4: Lateral Movement ----
        Write-Host "`n[2/4] Configuring lateral movement..." -ForegroundColor Yellow

        # PSRemoting
        try {
            Enable-PSRemoting -Force -SkipNetworkProfileCheck -ErrorAction Stop 2>$null | Out-Null
            Write-Host "    [+] PSRemoting enabled" -ForegroundColor Green
        } catch {
            Write-Host "    [!] PSRemoting failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        try {
            Set-Service -Name WinRM -StartupType Automatic -ErrorAction Stop
            Start-Service -Name WinRM -ErrorAction Stop
            Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force -ErrorAction Stop | Out-Null
            Write-Host "    [+] WinRM service started and TrustedHosts set" -ForegroundColor Green
        } catch {
            Write-Host "    [!] WinRM configuration warning: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # WMI
        try {
            netsh advfirewall firewall set rule group="Windows Management Instrumentation (WMI)" new enable=yes 2>$null | Out-Null
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Ole" -Name "EnableDCOM" -Value "Y" -Force -ErrorAction Stop
            Write-Host "    [+] WMI remote access enabled" -ForegroundColor Green
        } catch {
            Write-Host "    [!] WMI configuration warning: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # RDP
        try {
            Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" `
                -Name "fDenyTSConnections" -Value 0 -Force -ErrorAction Stop
            Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction Stop
            Write-Host "    [+] RDP enabled" -ForegroundColor Green
        } catch {
            Write-Host "    [!] RDP configuration warning: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # Admin shares
        try {
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" `
                -Name "AutoShareWks" -Value 1 -Type DWord -Force -ErrorAction Stop
            Write-Host "    [+] Admin shares accessible" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Admin shares warning: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # Disable remote UAC
        try {
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" `
                -Name "LocalAccountTokenFilterPolicy" -Value 1 -Type DWord -Force -ErrorAction Stop
            Write-Host "    [+] Remote UAC disabled (PtH works)" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Remote UAC warning: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # Local admin
        try {
            $localPass = ConvertTo-SecureString "LabAdmin@2026!" -AsPlainText -Force
            if (-not (Get-LocalUser -Name "operator" -ErrorAction SilentlyContinue)) {
                New-LocalUser -Name "operator" -Password $localPass `
                    -PasswordNeverExpires -Description "Lab local admin" -ErrorAction Stop | Out-Null
                Write-Host "    [+] Local user created: operator" -ForegroundColor Green
            } else {
                Write-Host "    [=] operator user already exists" -ForegroundColor DarkGray
            }
            
            # Translate SID S-1-5-32-544 to local group name (support non-English systems)
            $adminGroupName = (New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")).Translate([System.Security.Principal.NTAccount]).Value.Split("\")[-1]
            
            $isMember = $false
            try {
                $members = Get-LocalGroupMember -Group $adminGroupName -ErrorAction SilentlyContinue
                if ($members) {
                    foreach ($m in $members) {
                        if ($m.Name -match "operator$") {
                            $isMember = $true
                            break
                        }
                    }
                }
            } catch {}

            if (-not $isMember) {
                Add-LocalGroupMember -Group $adminGroupName -Member "operator" -ErrorAction Stop
                Write-Host "    [+] Added operator to local admin group ($adminGroupName)" -ForegroundColor Green
            } else {
                Write-Host "    [=] operator is already a member of local admin group ($adminGroupName)" -ForegroundColor DarkGray
            }
        } catch {
            Write-Host "    [!] Local admin creation/group assignment warning: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # Credential exposure
        try {
            $wdigestPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest"
            if (-not (Test-Path $wdigestPath)) { New-Item -Path $wdigestPath -Force | Out-Null }
            Set-ItemProperty -Path $wdigestPath -Name "UseLogonCredential" -Value 1 -Type DWord -Force -ErrorAction Stop
            Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value 0 -Type DWord -Force -ErrorAction Stop
            Write-Host "    [+] WDigest on, LSA Protection off" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Credential exposure configuration warning: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # ---- 3/4: Persistence ----
        Write-Host "`n[3/4] Configuring persistence..." -ForegroundColor Yellow

        try {
            $persistScript = "C:\Windows\Temp\persistence_demo.ps1"
            "Write-Host 'Persistence demo running'" | Out-File $persistScript -Force -ErrorAction Stop
            Write-Host "    [+] Persistence script created" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Failed to create persistence script: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        try {
            $persistScript = "C:\Windows\Temp\persistence_demo.ps1"
            Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
                -Name "ORSUBankUpdater" `
                -Value "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File $persistScript" -Force -ErrorAction Stop
            Write-Host "    [+] HKCU Run key set" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Failed to set HKCU Run key: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        try {
            $persistScript = "C:\Windows\Temp\persistence_demo.ps1"
            Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" `
                -Name "ORSUBankSync" `
                -Value "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File $persistScript" -Force -ErrorAction Stop
            Write-Host "    [+] HKLM Run key set" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Failed to set HKLM Run key: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        try {
            $startupDir = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
            if (-not (Test-Path $startupDir)) {
                New-Item -Path $startupDir -ItemType Directory -Force | Out-Null
            }
            "@echo off`npowershell -WindowStyle Hidden -Command `"Write-Host 'Startup demo'`"" | `
                Out-File "$startupDir\ORSUStartup.bat" -Encoding ASCII -Force -ErrorAction Stop
            Write-Host "    [+] Startup folder: ORSUStartup.bat" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Failed to set startup script: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        try {
            $persistScript = "C:\Windows\Temp\persistence_demo.ps1"
            $taskAction = New-ScheduledTaskAction -Execute "powershell.exe" `
                -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File $persistScript"
            $startupTrigger = New-ScheduledTaskTrigger -AtStartup
            $systemPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" `
                -LogonType ServiceAccount -RunLevel Highest
            Register-ScheduledTask -TaskName "ORSUStartupSync" -Action $taskAction `
                -Trigger $startupTrigger -Principal $systemPrincipal -Force -ErrorAction Stop | Out-Null
            Write-Host "    [+] Scheduled task: ORSUStartupSync (SYSTEM at boot)" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Failed to register startup scheduled task: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        try {
            Stop-LabServiceIfRunning "ORSUHostService"
            Copy-Item "C:\Windows\System32\svchost.exe" "C:\Windows\Temp\ORSUHost.exe" -Force -ErrorAction Stop
            New-LabService -Name "ORSUHostService" `
                -BinPath "C:\Windows\Temp\ORSUHost.exe -k netsvcs" `
                -Description "ORSU Bank Network Services Host"
            Write-Host "    [+] Hidden service configured (ORSUHostService)" -ForegroundColor Green
        } catch {
            Write-Host "    [!] Failed to configure ORSUHostService: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # WMI subscription
        try {
            # Clean up old WMI objects if they exist from a previous run to avoid "already exists" errors
            Get-WmiObject -Namespace "root\subscription" -Class "__FilterToConsumerBinding" -ErrorAction SilentlyContinue | 
                Where-Object { $_.Filter -match "ORSUFilter" -or $_.Consumer -match "ORSUConsumer" } | 
                Remove-WmiObject -ErrorAction SilentlyContinue
            Get-WmiObject -Namespace "root\subscription" -Class "__EventFilter" -Filter "Name='ORSUFilter'" -ErrorAction SilentlyContinue | 
                Remove-WmiObject -ErrorAction SilentlyContinue
            Get-WmiObject -Namespace "root\subscription" -Class "CommandLineEventConsumer" -Filter "Name='ORSUConsumer'" -ErrorAction SilentlyContinue | 
                Remove-WmiObject -ErrorAction SilentlyContinue

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
        try {
            $webClient = Get-Service -Name WebClient -ErrorAction SilentlyContinue
            if ($webClient) {
                Set-Service -Name WebClient -StartupType Automatic -ErrorAction Stop
                Start-Service -Name WebClient -ErrorAction Stop
                $wcStatus = (Get-Service WebClient).Status
                if ($wcStatus -eq "Running") {
                    Write-Host "    [+] WebClient running" -ForegroundColor Green
                } else {
                    Write-Host "    [!] WebClient status: $wcStatus" -ForegroundColor Yellow
                }
            } else {
                Write-Host "    [!] WebClient not available" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "    [!] Failed to configure WebClient service: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # ---- VERIFICATION ----
        Write-Host "`n[*] Running verification checks..." -ForegroundColor Cyan
        $passed = 0; $failed = 0

        try {
            if (Test-ServiceExists "ORSUUpdateService") { Write-Host "    [OK] ORSUUpdateService" -ForegroundColor Green; $passed++ }
            else { Write-Host "    [FAIL] ORSUUpdateService missing" -ForegroundColor Red; $failed++ }
        } catch {
            Write-Host "    [FAIL] ORSUUpdateService check failed" -ForegroundColor Red; $failed++
        }

        try {
            if (Test-ServiceExists "VulnService") { Write-Host "    [OK] VulnService" -ForegroundColor Green; $passed++ }
            else { Write-Host "    [FAIL] VulnService missing" -ForegroundColor Red; $failed++ }
        } catch {
            Write-Host "    [FAIL] VulnService check failed" -ForegroundColor Red; $failed++
        }

        try {
            $aie = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer" -Name AlwaysInstallElevated -ErrorAction SilentlyContinue
            if ($aie -and $aie.AlwaysInstallElevated -eq 1) { Write-Host "    [OK] AlwaysInstallElevated" -ForegroundColor Green; $passed++ }
            else { Write-Host "    [FAIL] AlwaysInstallElevated not set" -ForegroundColor Red; $failed++ }
        } catch {
            Write-Host "    [FAIL] AlwaysInstallElevated check failed" -ForegroundColor Red; $failed++
        }

        try {
            $winrmService = Get-Service WinRM -ErrorAction SilentlyContinue
            if ($winrmService -and $winrmService.Status -eq "Running") { Write-Host "    [OK] WinRM running" -ForegroundColor Green; $passed++ }
            else { Write-Host "    [FAIL] WinRM not running" -ForegroundColor Red; $failed++ }
        } catch {
            Write-Host "    [FAIL] WinRM service check failed" -ForegroundColor Red; $failed++
        }

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
