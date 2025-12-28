# 🏗️ ORSUBANK AD Red Team Lab Setup Guide
## Complete Beginner's Guide to Building Your Lab from Scratch

> [!NOTE]
> **Difficulty:** Beginner-friendly (Zero IT knowledge required)
> **Time Required:** 4-6 hours
> **Cost:** Free (using evaluation versions)
> **What you'll build:** A complete Active Directory domain for Red Team practice

---

## 📋 Table of Contents
1. [What You're Building](#1-what-youre-building)
2. [Hardware Requirements](#2-hardware-requirements)
3. [Software Downloads](#3-software-downloads)
4. [Creating Virtual Machines](#4-creating-virtual-machines)
5. [Installing Windows Server 2025 (DC01)](#5-installing-windows-server-2025-dc01)
6. [Configuring Domain Controller](#6-configuring-domain-controller)
7. [Creating Domain Users](#7-creating-domain-users)
8. [Installing Windows 11 (WS01 & WS02)](#8-installing-windows-11-ws01--ws02)
9. [Joining Workstations to Domain](#9-joining-workstations-to-domain)
10. [Setting Up Kali Linux (Attacker Machine)](#10-setting-up-kali-linux-attacker-machine)
11. [Verifying Lab Setup](#11-verifying-lab-setup)
12. [Network Topology](#12-network-topology)
13. [Troubleshooting](#13-troubleshooting)

---

## 1. What You're Building

### Understanding the Lab (Explained Simply)

**What is this lab?**
Think of this as building a small company network in your computer. You'll create:
- A main "boss" computer that manages everyone (Domain Controller)
- Two employee computers (Workstations)
- An attacker computer to practice hacking (Kali Linux)

**What is Active Directory?**
Active Directory (AD) is like a company phone book combined with a security system:
- It knows who works at the company (users)
- It knows what computers exist (machines)
- It controls who can access what (permissions)
- It's what attackers want to compromise!

**Why ORSUBANK?**
We're simulating a bank's network because:
- Banks have valuable data (money!)
- Real attackers target banks
- You'll learn realistic attack scenarios
- Banking environment = impressive on your resume

### Lab Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    ORSUBANK LAB NETWORK                     │
│                    Network: 192.168.100.0/24                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───────────────┐    ┌───────────────┐   ┌───────────────┐│
│  │     DC01      │    │     WS01      │   │     WS02      ││
│  │ Domain Ctrl   │    │ Workstation 1 │   │ Workstation 2 ││
│  │ Server 2025   │    │ Windows 11    │   │ Windows 11    ││
│  │ 192.168.100.10│    │ 192.168.100.20│   │ 192.168.100.30││
│  └───────────────┘    └───────────────┘   └───────────────┘│
│                                                             │
│                   ┌───────────────┐                        │
│                   │     KALI      │                        │
│                   │ Attacker Box  │                        │
│                   │ 192.168.100.100│                       │
│                   └───────────────┘                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### IP Address Reference Card
| Machine | Role | IP Address | Username |
|---------|------|------------|----------|
| DC01 | Domain Controller | 192.168.100.10 | Administrator |
| WS01 | Workstation 1 | 192.168.100.20 | vamsi.krishna |
| WS02 | Workstation 2 | 192.168.100.30 | ravi.teja |
| KALI | Attacker Box | 192.168.100.100 | kali |

---

## 2. Hardware Requirements

### Minimum Requirements
Your computer needs:
- **RAM:** 16 GB minimum (32 GB recommended)
- **CPU:** 4 cores minimum (8 cores recommended)
- **Disk:** 200 GB free space (SSD strongly recommended)
- **Network:** Any internet connection for downloads

### Resource Allocation Per VM
| Virtual Machine | RAM | CPU | Disk |
|-----------------|-----|-----|------|
| DC01 (Server 2025) | 4 GB | 2 cores | 50 GB |
| WS01 (Windows 11) | 4 GB | 2 cores | 50 GB |
| WS02 (Windows 11) | 4 GB | 2 cores | 50 GB |
| Kali Linux | 4 GB | 2 cores | 40 GB |
| **TOTAL** | **16 GB** | **8 cores** | **190 GB** |

**Pro Tip:** You don't need to run all VMs at once. For most attacks:
- DC01 + WS01 + Kali (minimum 12 GB RAM needed)
- Add WS02 only for lateral movement practice

---

## 3. Software Downloads

### Required Downloads

**1. VMware Workstation Pro (Free for Personal Use)**
- Download: https://www.vmware.com/products/desktop-hypervisor/workstation-and-fusion
- Alternative: VirtualBox (https://www.virtualbox.org) - fully free

**2. Windows Server 2025 (180-day Evaluation)**
- Download: https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2025
- Select "ISO" download option
- No payment or credit card required
- Size: ~5 GB

**3. Windows 11 (Evaluation)**
- Download: https://www.microsoft.com/en-us/software-download/windows11
- Select "Windows 11 multi-edition ISO"
- Or use Media Creation Tool
- Size: ~5.5 GB

**4. Kali Linux**
- Download: https://www.kali.org/get-kali/#kali-virtual-machines
- Select "VMware" or "VirtualBox" version (pre-built)
- Size: ~3 GB (compressed)

### Download Checklist
- [ ] VMware Workstation Pro or VirtualBox installed
- [ ] Windows Server 2025 ISO downloaded
- [ ] Windows 11 ISO downloaded (download twice - for WS01 and WS02)
- [ ] Kali Linux VM downloaded and extracted

---

## 4. Creating Virtual Machines

### Setting Up VMware/VirtualBox Network

**First, create an internal network so all VMs can talk to each other:**

**In VMware Workstation:**
1. Edit → Virtual Network Editor
2. Click "Add Network" → Select VMnet2
3. Set to "Host-only"
4. Subnet IP: 192.168.100.0
5. Subnet mask:  255.255.255.0
6. Uncheck "Connect a host virtual adapter to this network" (optional)
7. Click Apply and OK

**In VirtualBox:**
1. File → Host Network Manager
2. Create a new host-only network
3. Set IPv4 Address: 192.168.100.1
4. Set IPv4 Network Mask: 255.255.255.0
5. Disable DHCP Server

### Creating DC01 VM (Domain Controller)

**In VMware:**
1. File → New Virtual Machine
2. Select "Custom (advanced)" → Next
3. Choose "I will install the operating system later"
4. Guest OS: Microsoft Windows → Windows Server 2022 (closest to 2025)
5. Virtual Machine Name: DC01
6. Number of processors: 2, Cores per processor: 1
7. Memory: 4096 MB (4 GB)
8. Network: Use Host-only (VMnet2)
9. Hard disk: 50 GB
10. Finish

**After creating:**
1. Edit Virtual Machine Settings
2. CD/DVD → Use ISO image file → Select Windows Server 2025 ISO
3. Network Adapter → Select Custom (VMnet2)

### Creating WS01 and WS02 VMs (Workstations)

Repeat the process for both workstations:

**Settings for WS01:**
- Name: WS01
- OS: Windows 11
- RAM: 4 GB
- CPU: 2 cores
- Disk: 50 GB
- Network: Host-only (VMnet2)
- ISO: Windows 11 ISO

**Settings for WS02:**
- Name: WS02
- (Same as WS01)

---

## 5. Installing Windows Server 2025 (DC01)

### Step-by-Step Installation

1. **Power on DC01 VM**
   - Press any key to boot from DVD

2. **Windows Setup Screen**
   - Language: English (or your preference)
   - Click "Next"
   - Click "Install now"

3. **Select Edition**
   - Choose "Windows Server 2025 Standard (Desktop Experience)"
   - Important: Select "Desktop Experience" or you won't have GUI!
   - Accept license terms

4. **Installation Type**
   - Select "Custom: Install Windows only (advanced)"
   - Select the hard drive (Drive 0)
   - Click "Next"

5. **Wait for Installation (10-20 minutes)**

6. **Set Administrator Password**
   - Password suggestion: `LabAdmin123!`
   - This is the local Administrator password
   - Remember this password!

7. **Login with Ctrl+Alt+Delete**
   - In VMware: Ctrl+Alt+Insert
   - Enter Administrator password

### Post-Installation Setup

**Step 1: Set Computer Name**
```powershell
# Open PowerShell as Administrator
# Right-click Start → Windows PowerShell (Admin)

# Rename computer to DC01
Rename-Computer -NewName "DC01" -Restart
```

Wait for restart, then log back in.

**Step 2: Set Static IP Address**
```powershell
# Open PowerShell as Administrator

# First, find your network adapter name
Get-NetAdapter

# Set static IP (replace "Ethernet0" with your adapter name if different)
New-NetIPAddress -InterfaceAlias "Ethernet0" -IPAddress 192.168.100.10 -PrefixLength 24 -DefaultGateway 192.168.100.1

# Set DNS to itself (will be DNS server)
Set-DnsClientServerAddress -InterfaceAlias "Ethernet0" -ServerAddresses 192.168.100.10
```

**Step 3: Verify Network Settings**
```powershell
# Verify IP configuration
ipconfig /all

# Expected output should show:
# IPv4 Address: 192.168.100.10
# Subnet Mask: 255.255.255.0
# DNS Servers: 192.168.100.10
```

---

## 6. Configuring Domain Controller

### What is a Domain Controller?

**Simple Explanation:**
A Domain Controller is the "boss" computer that manages all users and computers in the network. It's like the HR department and security office combined - it knows who everyone is and what they're allowed to do.

### Installing Active Directory

**Step 1: Install AD DS Role**
```powershell
# Open PowerShell as Administrator

# Install Active Directory Domain Services role
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# This installs:
# - Active Directory Domain Services (the main AD software)
# - Management tools (like Active Directory Users and Computers)
```

Wait for installation to complete (5-10 minutes).

**Step 2: Promote to Domain Controller**
```powershell
# Create the ORSUBANK.LOCAL forest
Import-Module ADDSDeployment

Install-ADDSForest `
    -DomainName "orsubank.local" `
    -DomainNetBiosName "ORSUBANK" `
    -ForestMode "WinThreshold" `
    -DomainMode "WinThreshold" `
    -InstallDNS:$true `
    -SafeModeAdministratorPassword (ConvertTo-SecureString "DSRMPassword123!" -AsPlainText -Force) `
    -Force:$true

# BREAKDOWN:
# -DomainName "orsubank.local" : Our domain name (like a company name)
# -DomainNetBiosName "ORSUBANK" : Short name for the domain
# -ForestMode/DomainMode : Latest Windows features enabled
# -InstallDNS : Makes this server the DNS server too
# -SafeModeAdministratorPassword : Recovery password (save this!)
```

**The server will restart automatically.**

**Step 3: Verify Domain Creation**
```powershell
# After restart, log in as ORSUBANK\Administrator

# Verify domain
Get-ADDomain

# Expected output should show:
# DNSRoot: orsubank.local
# Forest: orsubank.local
# Name: orsubank

# Verify domain controller
Get-ADDomainController

# Expected output should show DC01 as domain controller
```

---

## 7. Creating Domain Users

### Creating Organizational Units (OUs)

**What are OUs?**
OUs are like folders for organizing users, groups, and computers. Think of them as departments in a company.

```powershell
# Create OUs for organizing our lab
New-ADOrganizationalUnit -Name "BankEmployees" -Path "DC=orsubank,DC=local" -ProtectedFromAccidentalDeletion $false
New-ADOrganizationalUnit -Name "ServiceAccounts" -Path "DC=orsubank,DC=local" -ProtectedFromAccidentalDeletion $false
New-ADOrganizationalUnit -Name "Workstations" -Path "DC=orsubank,DC=local" -ProtectedFromAccidentalDeletion $false

# Verify OUs were created
Get-ADOrganizationalUnit -Filter 'Name -like "*"' | Select-Object Name, DistinguishedName
```

### Creating Banking Staff Users (10 Users)

```powershell
# ============================================
# ORSUBANK DOMAIN USERS - BANKING STAFF
# ============================================

# Store password for users (will be changed individually)
$DefaultPassword = ConvertTo-SecureString "OrsUBank2024!" -AsPlainText -Force

# --- MANAGEMENT ---

# 1. Vamsi Krishna - Bank Manager
New-ADUser -Name "Vamsi Krishna" `
    -SamAccountName "vamsi.krishna" `
    -UserPrincipalName "vamsi.krishna@orsubank.local" `
    -GivenName "Vamsi" `
    -Surname "Krishna" `
    -Title "Bank Manager" `
    -Department "Management" `
    -Path "OU=BankEmployees,DC=orsubank,DC=local" `
    -AccountPassword $DefaultPassword `
    -Enabled $true `
    -PasswordNeverExpires $true
Write-Host "[+] Created: vamsi.krishna (Bank Manager)" -ForegroundColor Green

# 2. Ammulu Orsu - IT Manager / Domain Admin
New-ADUser -Name "Ammulu Orsu" `
    -SamAccountName "ammulu.orsu" `
    -UserPrincipalName "ammulu.orsu@orsubank.local" `
    -GivenName "Ammulu" `
    -Surname "Orsu" `
    -Title "IT Manager" `
    -Department "IT" `
    -Path "OU=BankEmployees,DC=orsubank,DC=local" `
    -AccountPassword $DefaultPassword `
    -Enabled $true `
    -PasswordNeverExpires $true
# Make ammulu.orsu a Domain Admin
Add-ADGroupMember -Identity "Domain Admins" -Members "ammulu.orsu"
Write-Host "[+] Created: ammulu.orsu (IT Manager - DOMAIN ADMIN)" -ForegroundColor Green

# --- IT DEPARTMENT ---

# 3. Lakshmi Devi - System Administrator
New-ADUser -Name "Lakshmi Devi" `
    -SamAccountName "lakshmi.devi" `
    -UserPrincipalName "lakshmi.devi@orsubank.local" `
    -GivenName "Lakshmi" `
    -Surname "Devi" `
    -Title "System Administrator" `
    -Department "IT" `
    -Path "OU=BankEmployees,DC=orsubank,DC=local" `
    -AccountPassword $DefaultPassword `
    -Enabled $true `
    -PasswordNeverExpires $true
Write-Host "[+] Created: lakshmi.devi (System Administrator)" -ForegroundColor Green

# 4. Ravi Teja - Network Administrator
New-ADUser -Name "Ravi Teja" `
    -SamAccountName "ravi.teja" `
    -UserPrincipalName "ravi.teja@orsubank.local" `
    -GivenName "Ravi" `
    -Surname "Teja" `
    -Title "Network Administrator" `
    -Department "IT" `
    -Path "OU=BankEmployees,DC=orsubank,DC=local" `
    -AccountPassword $DefaultPassword `
    -Enabled $true `
    -PasswordNeverExpires $true
Write-Host "[+] Created: ravi.teja (Network Administrator)" -ForegroundColor Green

# --- BRANCH STAFF ---

# 5. Pranavi - Branch Manager
New-ADUser -Name "Pranavi" `
    -SamAccountName "pranavi" `
    -UserPrincipalName "pranavi@orsubank.local" `
    -GivenName "Pranavi" `
    -Surname "" `
    -Title "Branch Manager" `
    -Department "Branch Operations" `
    -Path "OU=BankEmployees,DC=orsubank,DC=local" `
    -AccountPassword (ConvertTo-SecureString "Branch123!" -AsPlainText -Force) `
    -Enabled $true `
    -PasswordNeverExpires $true
Write-Host "[+] Created: pranavi (Branch Manager)" -ForegroundColor Green

# 6. Harsha Vardhan - Customer Service Manager
New-ADUser -Name "Harsha Vardhan" `
    -SamAccountName "harsha.vardhan" `
    -UserPrincipalName "harsha.vardhan@orsubank.local" `
    -GivenName "Harsha" `
    -Surname "Vardhan" `
    -Title "Customer Service Manager" `
    -Department "Customer Service" `
    -Path "OU=BankEmployees,DC=orsubank,DC=local" `
    -AccountPassword (ConvertTo-SecureString "Customer2024!" -AsPlainText -Force) `
    -Enabled $true `
    -PasswordNeverExpires $true
Write-Host "[+] Created: harsha.vardhan (Customer Service Manager)" -ForegroundColor Green

# 7. Divya - Loan Officer
New-ADUser -Name "Divya" `
    -SamAccountName "divya" `
    -UserPrincipalName "divya@orsubank.local" `
    -GivenName "Divya" `
    -Surname "" `
    -Title "Loan Officer" `
    -Department "Loans" `
    -Path "OU=BankEmployees,DC=orsubank,DC=local" `
    -AccountPassword $DefaultPassword `
    -Enabled $true `
    -PasswordNeverExpires $true
Write-Host "[+] Created: divya (Loan Officer)" -ForegroundColor Green

# 8. Kiran Kumar - Financial Analyst
New-ADUser -Name "Kiran Kumar" `
    -SamAccountName "kiran.kumar" `
    -UserPrincipalName "kiran.kumar@orsubank.local" `
    -GivenName "Kiran" `
    -Surname "Kumar" `
    -Title "Financial Analyst" `
    -Department "Finance" `
    -Path "OU=BankEmployees,DC=orsubank,DC=local" `
    -AccountPassword (ConvertTo-SecureString "Finance1!" -AsPlainText -Force) `
    -Enabled $true `
    -PasswordNeverExpires $true
Write-Host "[+] Created: kiran.kumar (Financial Analyst)" -ForegroundColor Green

# --- OPERATIONS ---

# 9. Madhavi - Operations Manager
New-ADUser -Name "Madhavi" `
    -SamAccountName "madhavi" `
    -UserPrincipalName "madhavi@orsubank.local" `
    -GivenName "Madhavi" `
    -Surname "" `
    -Title "Operations Manager" `
    -Department "Operations" `
    -Path "OU=BankEmployees,DC=orsubank,DC=local" `
    -AccountPassword $DefaultPassword `
    -Enabled $true `
    -PasswordNeverExpires $true
Write-Host "[+] Created: madhavi (Operations Manager)" -ForegroundColor Green

# 10. Sai Kiran - Compliance Officer
New-ADUser -Name "Sai Kiran" `
    -SamAccountName "sai.kiran" `
    -UserPrincipalName "sai.kiran@orsubank.local" `
    -GivenName "Sai" `
    -Surname "Kiran" `
    -Title "Compliance Officer" `
    -Department "Compliance" `
    -Path "OU=BankEmployees,DC=orsubank,DC=local" `
    -AccountPassword $DefaultPassword `
    -Enabled $true `
    -PasswordNeverExpires $true
Write-Host "[+] Created: sai.kiran (Compliance Officer)" -ForegroundColor Green

# ============================================
# VERIFICATION
# ============================================
Write-Host "`n[*] All 10 banking staff users created!" -ForegroundColor Cyan
Get-ADUser -Filter * -SearchBase "OU=BankEmployees,DC=orsubank,DC=local" | Select-Object Name, SamAccountName, Enabled | Format-Table
```

### User Reference Table
| # | Name | Username | Role | Password | Notes |
|---|------|----------|------|----------|-------|
| 1 | Vamsi Krishna | vamsi.krishna | Bank Manager | OrsUBank2024! | Initial access target |
| 2 | Ammulu Orsu | ammulu.orsu | IT Manager | OrsUBank2024! | **DOMAIN ADMIN** |
| 3 | Lakshmi Devi | lakshmi.devi | System Administrator | OrsUBank2024! | ACL abuse target |
| 4 | Ravi Teja | ravi.teja | Network Administrator | OrsUBank2024! | WS02 user |
| 5 | Pranavi | pranavi | Branch Manager | Branch123! | AS-REP vulnerable |
| 6 | Harsha Vardhan | harsha.vardhan | Customer Service | Customer2024! | AS-REP vulnerable |
| 7 | Divya | divya | Loan Officer | OrsUBank2024! | - |
| 8 | Kiran Kumar | kiran.kumar | Financial Analyst | Finance1! | AS-REP vulnerable |
| 9 | Madhavi | madhavi | Operations Manager | OrsUBank2024! | - |
| 10 | Sai Kiran | sai.kiran | Compliance Officer | OrsUBank2024! | - |

---

## 8. Installing Windows 11 (WS01 & WS02)

### Installing WS01

1. **Power on WS01 VM**
2. **Boot from Windows 11 ISO**
3. **Installation Steps:**
   - Language: English
   - Click "I don't have a product key"
   - Select Windows 11 Pro
   - Custom install
   - Select Drive 0 → Next

4. **OOBE Setup (Out of Box Experience):**
   - Region: Your region
   - Keyboard: Your layout
   - **IMPORTANT:** When asked to connect to network, click "I don't have internet"
   - Then click "Continue with limited setup"
   - This lets you create a LOCAL account

5. **Create Local Account:**
   - Username: `LocalAdmin`
   - Password: `LocalAdmin123!`
   - Security questions: Any answers (you won't need them)

6. **Decline all tracking options**
   - Turn off all privacy settings

### Setting Up WS01 Network

After installation and login:

**Step 1: Rename Computer**
```powershell
# Open PowerShell as Administrator

# Rename to WS01
Rename-Computer -NewName "WS01" -Restart
```

**Step 2: Set Static IP**
```powershell
# After restart, open PowerShell as Administrator

# Find network adapter name
Get-NetAdapter

# Set static IP for WS01
New-NetIPAddress -InterfaceAlias "Ethernet0" -IPAddress 192.168.100.20 -PrefixLength 24 -DefaultGateway 192.168.100.1

# Point DNS to Domain Controller
Set-DnsClientServerAddress -InterfaceAlias "Ethernet0" -ServerAddresses 192.168.100.10
```

**Step 3: Verify Connectivity to DC01**
```powershell
# Test connection to Domain Controller
ping 192.168.100.10

# Test DNS resolution
nslookup orsubank.local

# Should return: 192.168.100.10
```

### Repeat for WS02

Same process, but use:
- Computer name: WS02
- IP Address: 192.168.100.30
- Same DNS: 192.168.100.10

---

## 9. Joining Workstations to Domain

### Join WS01 to ORSUBANK Domain

**Method 1: GUI**
1. Right-click Start → System
2. Click "Domain or workgroup" → Change settings
3. Click "Change" next to computer name
4. Select "Domain" and enter: `orsubank.local`
5. Enter credentials:
   - Username: `ORSUBANK\Administrator`
   - Password: `LabAdmin123!`
6. Click OK → Restart

**Method 2: PowerShell**
```powershell
# Join domain
Add-Computer -DomainName "orsubank.local" -Credential ORSUBANK\Administrator -Restart

# When prompted, enter Administrator password
```

### Verify Domain Join
```powershell
# After restart, log in as:
# Username: ORSUBANK\vamsi.krishna
# Password: OrsUBank2024!

# Verify domain membership
(Get-WmiObject Win32_ComputerSystem).Domain
# Should return: orsubank.local
```

### Repeat for WS02

Same process:
- Join to orsubank.local
- Login as: ORSUBANK\ravi.teja

---

## 10. Setting Up Kali Linux (Attacker Machine)

### Import Pre-Built Kali VM

1. **Extract downloaded Kali VM**
2. **In VMware:** File → Open → Select the .vmx file
3. **In VirtualBox:** File → Import Appliance → Select .ova file

### Configure Network

**Step 1: Set to Host-Only Network**
1. Edit VM Settings
2. Network Adapter → Custom → VMnet2 (same as other VMs)

**Step 2: Set Static IP**
```bash
# Login to Kali (default: kali / kali)

# Edit network configuration
sudo nano /etc/network/interfaces

# Add these lines:
auto eth0
iface eth0 inet static
    address 192.168.100.100
    netmask 255.255.255.0
    gateway 192.168.100.1
    dns-nameservers 192.168.100.10

# Save (Ctrl+O) and Exit (Ctrl+X)

# Restart networking
sudo systemctl restart networking
```

**Step 3: Verify Connectivity**
```bash
# Test connection to DC01
ping 192.168.100.10

# Test connection to WS01
ping 192.168.100.20

# Test connection to WS02
ping 192.168.100.30

# Test DNS resolution
nslookup orsubank.local 192.168.100.10
```

### Install Sliver C2

```bash
# Update Kali
sudo apt update && sudo apt upgrade -y

# Install Sliver C2
curl https://sliver.sh/install | sudo bash

# Verify installation
sliver-server version
```

---

## 11. Verifying Lab Setup

### Verification Checklist

**On DC01:**
```powershell
# Verify domain
Get-ADDomain | Select-Object DNSRoot, NetBIOSName, DomainMode

# Verify users (should show 10 banking staff + service accounts)
Get-ADUser -Filter * | Select-Object Name, SamAccountName, Enabled | Format-Table

# Verify Domain Admins
Get-ADGroupMember "Domain Admins" | Select-Object Name

# Should show: Administrator, ammulu.orsu
```

**On WS01:**
```powershell
# Verify domain membership
(Get-WmiObject Win32_ComputerSystem).Domain

# Verify can reach DC
Test-Connection 192.168.100.10

# Verify vamsi.krishna can log in
# Login as ORSUBANK\vamsi.krishna with password OrsUBank2024!
```

**On Kali:**
```bash
# Verify can reach all machines
ping -c 2 192.168.100.10  # DC01
ping -c 2 192.168.100.20  # WS01
ping -c 2 192.168.100.30  # WS02

# Verify Sliver is installed
which sliver-server
```

---

## 12. Network Topology

### Complete Lab Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                        ORSUBANK ACTIVE DIRECTORY LAB                     │
│                          orsubank.local (192.168.100.0/24)              │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│    ┌──────────────────────────────────────────────────────────────┐     │
│    │                     DOMAIN CONTROLLER                        │     │
│    │  ┌────────────────────────────────────────────────────────┐  │     │
│    │  │  DC01                                                   │  │     │
│    │  │  Windows Server 2025                                    │  │     │
│    │  │  IP: 192.168.100.10                                    │  │     │
│    │  │  Role: Domain Controller, DNS Server                    │  │     │
│    │  │  Domain: orsubank.local                                 │  │     │
│    │  │                                                          │  │     │
│    │  │  Services:                                               │  │     │
│    │  │  - Active Directory Domain Services                      │  │     │
│    │  │  - DNS Server                                            │  │     │
│    │  │  - Kerberos (port 88)                                    │  │     │
│    │  │  - LDAP (port 389)                                       │  │     │
│    │  │  - SMB (port 445)                                        │  │     │
│    │  └────────────────────────────────────────────────────────┘  │     │
│    └──────────────────────────────────────────────────────────────┘     │
│                               │                                          │
│                               │ (DNS, Auth, GPO)                        │
│              ┌────────────────┼────────────────┐                        │
│              │                │                │                        │
│              ▼                ▼                ▼                        │
│    ┌────────────────┐ ┌────────────────┐ ┌────────────────┐            │
│    │     WS01       │ │     WS02       │ │     KALI       │            │
│    │  Windows 11    │ │  Windows 11    │ │  Linux         │            │
│    │  192.168.100.20│ │  192.168.100.30│ │  192.168.100.100│           │
│    │                │ │                │ │                │            │
│    │ Primary User:  │ │ Primary User:  │ │ Role:          │            │
│    │ vamsi.krishna  │ │ ravi.teja      │ │ ATTACKER       │            │
│    │                │ │                │ │                │            │
│    │ (Initial       │ │ (Lateral       │ │ Tools:         │            │
│    │  Access Target)│ │  Movement)     │ │ - Sliver C2    │            │
│    │                │ │                │ │ - BloodHound   │            │
│    └────────────────┘ └────────────────┘ │ - Mimikatz     │            │
│                                          │ - Rubeus       │            │
│                                          └────────────────┘            │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘

DOMAIN USERS (10 Banking Staff):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
│ Management    │ vamsi.krishna (Manager), ammulu.orsu (IT Mgr/DA)       │
│ IT Dept       │ lakshmi.devi (SysAdmin), ravi.teja (NetAdmin)          │
│ Branch Staff  │ pranavi, harsha.vardhan, divya, kiran.kumar            │
│ Operations    │ madhavi, sai.kiran                                      │
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 13. Troubleshooting

### Common Issues

**Issue: Cannot ping DC01 from WS01**
```powershell
# On DC01, check firewall
Get-NetFirewallRule -DisplayName "*ICMP*"

# Enable ICMPv4
New-NetFirewallRule -DisplayName "Allow ICMPv4-In" -Protocol ICMPv4 -IcmpType 8 -Direction Inbound -Action Allow
```

**Issue: Cannot join domain**
```powershell
# Verify DNS is set correctly on workstation
nslookup orsubank.local

# If fails, manually set DNS:
Set-DnsClientServerAddress -InterfaceAlias "Ethernet0" -ServerAddresses 192.168.100.10
```

**Issue: User cannot login**
```powershell
# On DC01, verify user exists and is enabled
Get-ADUser -Identity "vamsi.krishna" | Select-Object Enabled

# Reset password if needed
Set-ADAccountPassword -Identity "vamsi.krishna" -Reset -NewPassword (ConvertTo-SecureString "NewPassword123!" -AsPlainText -Force)
```

**Issue: Kali cannot reach Windows machines**
```bash
# Verify network adapter is on correct network
ip addr show

# If IP is wrong, restart networking
sudo systemctl restart networking
```

---

## ✅ Lab Setup Complete!

**You now have:**
- [x] DC01 running orsubank.local domain
- [x] 10 banking staff users created
- [x] WS01 and WS02 joined to domain
- [x] Kali Linux ready for attacks
- [x] Network connectivity verified

**What's Next:**
1. Run PowerShell vulnerability scripts (Step 2-7)
2. Start with [00. Initial Access Walkthrough](./walkthroughs/00_initial_access_sliver_setup.md)

---

**📁 Location:** C:\Users\vamsi\Desktop\AD-RTO\LAB_SETUP_GUIDE.md

---
