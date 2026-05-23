# Module 00: Lab Setup

Build your attack lab from scratch. By the end of this module, you will have a fully functional, isolated lab environment with two virtual machines, proper networking, detection telemetry, and clean snapshots ready for every exercise in this course.

**Time required:** 2-3 hours (mostly waiting for downloads and installations)

**What you will build:**
- A Windows 11 virtual machine (the target/victim endpoint)
- A Kali Linux virtual machine (the attacker workstation)
- A Host-Only network connecting both VMs (isolated from the internet)
- Sysmon installed on the Windows VM for detection telemetry
- All required tools installed on both machines
- Clean snapshots you can revert to at any time

**Hypervisor:** This course uses **VMware Workstation Pro** exclusively. It is free for personal use since 2024 and provides excellent performance.

---

## Table of Contents

- [Part 1: Downloading Everything You Need](#part-1-downloading-everything-you-need)
- [Part 2: Installing VMware Workstation Pro](#part-2-installing-vmware-workstation-pro)
- [Part 3: Creating the Windows VM](#part-3-creating-the-windows-vm)
- [Part 4: Creating the Kali Linux VM](#part-4-creating-the-kali-linux-vm)
- [Part 5: Networking -- The Dual Adapter Setup](#part-5-networking----the-dual-adapter-setup)
- [Part 6: Installing Sysmon on Windows](#part-6-installing-sysmon-on-windows)
- [Part 7: Configuring the Windows VM](#part-7-configuring-the-windows-vm)
- [Part 8: Configuring the Kali VM](#part-8-configuring-the-kali-vm)
- [Part 9: Verifying Everything Works](#part-9-verifying-everything-works)
- [Part 10: Taking Snapshots](#part-10-taking-snapshots)
- [Part 11: Troubleshooting](#part-11-troubleshooting)

---

## Part 1: Downloading Everything You Need

Before we do anything, let us download all the large files first. Start all of these downloads at the same time and let them run while you read ahead.

### 1.1 VMware Workstation Pro

1. Open your browser and go to: **https://www.vmware.com/products/desktop-hypervisor/workstation-and-fusion**
2. Scroll down and find the **VMware Workstation Pro** section
3. Click the **Download** button for Windows
4. If the site asks you to create a Broadcom account, create one (it is free)
5. Download the installer (approximately 600 MB)

> **Note:** Since 2024, VMware Workstation Pro is completely free for personal use. You do not need to purchase a license. During installation, select "Use VMware Workstation 17 for Personal Use" when prompted.

### 1.2 Windows 11 Enterprise Evaluation ISO

1. Open your browser and go to: **https://www.microsoft.com/en-us/evalcenter/evaluate-windows-11-enterprise**
2. Click **Download the ISO - 64 bit** (under "ISO - Enterprise" section)
3. Fill in the registration form:
   - First name, last name: Anything is fine
   - Work email: Use any email address
   - Company: Anything is fine
   - Country: Select your country
   - Phone: Any number
4. Click **Submit**
5. Select your language (English is recommended for this course)
6. Click **Download** -- the ISO is approximately **5-6 GB**

> **Why Windows 11?** Windows 11 is what modern enterprises deploy in 2026. It includes Smart App Control, enhanced SmartScreen, and the latest Defender features. VMware Workstation Pro handles TPM 2.0 emulation automatically, so there are no extra steps needed.

### 1.3 Kali Linux Pre-Built VM

1. Open your browser and go to: **https://www.kali.org/get-kali/#kali-virtual-machines**
2. Find the **VMware** column
3. Click the **Download** button (the `.7z` file)
4. The download is approximately **3-4 GB** compressed

> **Important:** Download the **pre-built VM image**, NOT the ISO installer. The pre-built image is ready to boot immediately -- no installation required.

### 1.4 Sysmon

1. Open your browser and go to: **https://learn.microsoft.com/en-us/sysinternals/downloads/sysmon**
2. Scroll down to the **Downloads** section
3. Click **Download Sysmon** -- this downloads a file called `Sysmon.zip` (approximately 3 MB)
4. Save it somewhere easy to find (like your `Downloads` folder)

### 1.5 Sysmon Configuration File

1. Open your browser and go to: **https://github.com/SwiftOnSecurity/sysmon-config**
2. Click the green **Code** button (top right of the file list)
3. Click **Download ZIP**
4. Save it somewhere easy to find (like your `Downloads` folder)

Alternatively, you can directly download just the config file:
1. On the same GitHub page, click the file named **sysmonconfig-export.xml**
2. Click the **Raw** button (top right of the file content)
3. Right-click anywhere on the page and click **Save as...**
4. Save it as `sysmonconfig-export.xml`

### 1.6 7-Zip (For Extracting Kali)

The Kali VM download is a `.7z` archive. You need 7-Zip to extract it:

1. Go to: **https://www.7-zip.org/**
2. Download the **64-bit Windows x64** installer (the first `.exe` link on the page)
3. Run the installer and click **Install** -- it takes 5 seconds
4. Click **Close**

### 1.7 Download Checklist

Before continuing, make sure you have all of these downloading or downloaded:

```
[ ] VMware Workstation Pro installer (~600 MB)
[ ] Windows 11 Enterprise Evaluation ISO (~5-6 GB)
[ ] Kali Linux VMware pre-built VM (.7z file, ~3-4 GB)
[ ] Sysmon.zip from Microsoft Sysinternals (~3 MB)
[ ] sysmonconfig-export.xml from SwiftOnSecurity GitHub
[ ] 7-Zip installer (for extracting the Kali .7z file)
```

---

## Part 2: Installing VMware Workstation Pro

### 2.1 Run the Installer

1. Double-click the VMware installer you downloaded (something like `VMware-workstation-full-17.x.x-xxxxx.exe`)
2. If Windows asks "Do you want to allow this app to make changes?", click **Yes**
3. The VMware setup wizard opens

### 2.2 Walk Through the Installer

1. **Welcome screen:** Click **Next**
2. **License Agreement:** Check **I accept the terms in the license agreement**, then click **Next**
3. **Custom Setup:** Leave the installation path as default (`C:\Program Files (x86)\VMware\VMware Workstation\`). Make sure **Enhanced Keyboard Driver** is checked. Click **Next**
4. **User Experience Settings:** Uncheck both boxes (telemetry and update checks -- they are not needed). Click **Next**
5. **Shortcuts:** Leave both checked (Desktop and Start Menu shortcuts). Click **Next**
6. **Ready to Install:** Click **Install**
7. Wait for the installation to complete (1-2 minutes)
8. Click **Finish**

### 2.3 First Launch

1. Double-click the **VMware Workstation Pro** shortcut on your Desktop
2. When prompted for a license:
   - Select **Use VMware Workstation 17 for Personal Use**
   - Click **Continue**
   - Click **Finish**
3. VMware Workstation opens to the Home screen

You should see the VMware home screen with options like "Create a New Virtual Machine", "Open a Virtual Machine", etc.

---

## Part 3: Creating the Windows VM

### 3.1 Start the New VM Wizard

1. In VMware, click **File** in the top menu bar
2. Click **New Virtual Machine...**
3. The "New Virtual Machine Wizard" opens
4. Select **Typical (recommended)** and click **Next**

### 3.2 Select the Windows ISO

1. Select **Installer disc image file (iso)**
2. Click **Browse...**
3. Navigate to where you downloaded the Windows 11 ISO (probably your `Downloads` folder)
4. Select the ISO file and click **Open**
5. VMware should detect it as "Windows 11 x64" and show a message about Easy Install
6. Click **Next**

### 3.3 Easy Install Information

VMware's Easy Install will automate the Windows setup. Fill in:

1. **Windows product key:** Leave this blank (the evaluation edition does not need one)
2. **Version of Windows to install:** Select **Windows 11 Enterprise**
3. **Full name:** Type `user`
4. **Password:** Type `Password123!` (or any password you will remember)
5. **Confirm password:** Type the same password again
6. Click **Next**

### 3.4 Name and Location

1. **Virtual machine name:** Type `Windows-Target`
2. **Location:** Leave the default path, or click **Browse** to choose a drive with enough space (the VM will need approximately 50 GB)
3. Click **Next**

### 3.5 Disk Size

1. **Maximum disk size:** Type `60` (GB)
2. Select **Store virtual disk as a single file** (better performance than splitting)
3. Click **Next**

### 3.6 Customize Hardware (Important)

1. Click the **Customize Hardware...** button (do NOT click Finish yet)
2. In the Hardware window, configure:

**Memory:**
- Click **Memory** on the left side
- Move the slider to **4096 MB** (or type `4096` in the box)
- If your host has 16+ GB RAM, set this to **8192 MB** for better performance

**Processors:**
- Click **Processors** on the left side
- Set **Number of processor cores** to `2`
- If your host has 8+ cores, set this to `4`

**Display:**
- Click **Display** on the left side
- Check **Accelerate 3D graphics** if available
- This gives you smooth display inside the VM

3. Click **Close** to return to the wizard
4. Click **Finish**

### 3.7 Wait for Windows Installation

VMware will now automatically:
1. Boot from the ISO
2. Install Windows 11 Enterprise
3. Create the user account you specified
4. Install VMware Tools (display drivers, clipboard sharing, etc.)

**This takes approximately 15-25 minutes.** Go make yourself some tea.

When it finishes, you will see the Windows desktop. The VM is ready.

### 3.8 Verify VMware Tools

VMware Tools should have been installed automatically. To verify:

1. Look at the bottom-right corner of the VMware window
2. You should see a status bar -- if VMware Tools is installed, you will NOT see any yellow warning about VMware Tools
3. Try resizing the VMware window -- the Windows desktop inside should resize automatically

If VMware Tools was NOT installed automatically:
1. In the VMware menu bar, click **VM**
2. Click **Install VMware Tools...**
3. Inside the Windows VM, open **File Explorer**
4. Click on the **DVD Drive (D:)** that appeared
5. Double-click **setup64.exe**
6. Follow the installer: click **Next** > **Next** > **Typical** > **Install** > **Finish**
7. Click **Yes** to restart the VM

---

## Part 4: Creating the Kali Linux VM

### 4.1 Extract the Kali VM

1. Open **File Explorer** on your host machine
2. Navigate to where you downloaded the Kali `.7z` file (probably your `Downloads` folder)
3. Right-click the `.7z` file
4. Click **7-Zip > Extract Here** (or **Extract to "kali-linux-..."** to put it in its own folder)
5. Wait for extraction to finish (1-2 minutes). It will create a folder containing several files including a `.vmx` file

### 4.2 Open the Kali VM in VMware

1. In VMware, click **File** in the top menu bar
2. Click **Open...**
3. Navigate to the folder you extracted in the previous step
4. Find the file that ends in `.vmx` (for example, `kali-linux-2025.1-vmware-amd64.vmx`)
5. Select it and click **Open**
6. The Kali VM now appears in your VMware library on the left side

### 4.3 Adjust Kali Resources

Before booting Kali, let us give it proper resources:

1. Click on the **Kali** VM in the left sidebar to select it
2. Click **Edit virtual machine settings** (or right-click > Settings)
3. Configure:

**Memory:**
- Click **Memory** on the left
- Set it to **4096 MB** (4 GB)

**Processors:**
- Click **Processors** on the left
- Set **Number of processor cores** to `2`

4. Click **OK**

### 4.4 First Boot

1. Click the **Power on this virtual machine** button (the green play triangle)
2. If VMware asks "Did you move or copy this virtual machine?", click **I Copied It**
3. Kali will boot to the login screen

### 4.5 Log In

1. The default credentials are:
   - **Username:** `kali`
   - **Password:** `kali`
2. Type the username and password at the login screen
3. You should see the Kali desktop

### 4.6 Change the Default Password

The first thing you must do is change the default password. Everyone in the world knows the default Kali password is `kali`.

1. Right-click anywhere on the Kali desktop
2. Click **Open Terminal Here** (or find Terminal in the top menu bar)
3. A terminal window opens
4. Type the following command and press Enter:

```bash
passwd
```

5. It will ask: `Current password:` -- type `kali` and press Enter (you will not see the characters as you type, that is normal)
6. It will ask: `New password:` -- type your new password and press Enter
7. It will ask: `Retype new password:` -- type it again and press Enter
8. You should see: `passwd: password updated successfully`

---

## Part 5: Networking -- The Dual Adapter Setup

This is the most important configuration step. If the networking is wrong, nothing else in this course will work.

### 5.1 Why Two Adapters?

Every VM in our lab gets two network adapters. Here is why:

```
Adapter 1: NAT
  What it does:  Gives the VM internet access
  How it works:  The VM shares your host machine's internet connection
  IP address:    Assigned automatically by VMware (you do not pick it)
  When you use it: Installing tools, downloading updates, browsing documentation

Adapter 2: Host-Only (VMnet1)
  What it does:  Creates a private network ONLY between your VMs
  How it works:  VMware creates a virtual network switch that exists only on your machine
  IP address:    We will set this manually (static IP)
  When you use it: ALL exercises in this course -- attack traffic stays here
```

**Why do we need both?**

- **NAT alone will not work** because VMware NAT gives each VM a separate internal IP on a separate subnet. The two VMs cannot directly communicate with each other over NAT.
- **Host-Only alone will not work** because Host-Only has no internet access. You need internet during setup to install tools and updates.
- **Both together** give you internet when you need it AND a private attack network for exercises.

### 5.2 Verify the Host-Only Network Exists

VMware creates a default Host-Only network (VMnet1) during installation. Let us verify it:

1. In VMware, click **Edit** in the top menu bar
2. Click **Virtual Network Editor...**
3. A small window opens. If everything is grayed out, click the **Change Settings** button at the bottom (this requires admin access -- click **Yes** when Windows asks)
4. You should see a list of virtual networks. Look for:
   - **VMnet1** with Type **Host-only**
   - **VMnet8** with Type **NAT**
5. Click on **VMnet1** (Host-only) to select it
6. Note the **Subnet IP** at the bottom (it is usually something like `192.168.190.0` or `192.168.85.0` -- whatever it is, write it down)
7. Make sure **Connect a host virtual adapter to this network** is checked
8. Make sure **Use local DHCP service to distribute IP addresses to VMs** is checked
9. Click **OK**

> **Write this down now:** Your VMnet1 subnet is: `192.168._____.0`
> For the rest of this guide, I will use `192.168.85.0` as an example. **Replace `192.168.85` with YOUR actual subnet wherever you see it.**

### 5.3 Add the Second Adapter to the Windows VM

The Windows VM already has one adapter (NAT, added during creation). We need to add a second one:

1. **Shut down the Windows VM** if it is running (Start menu > Power > Shut down)
2. Click on the **Windows-Target** VM in the left sidebar
3. Click **Edit virtual machine settings**
4. At the bottom of the hardware list, click the **Add...** button
5. Select **Network Adapter** from the list
6. Click **Finish**
7. A new "Network Adapter 2" appears in the hardware list
8. Click on **Network Adapter 2** to select it
9. On the right side, select **Host-only: A private network shared with the host**
10. Make sure it says **VMnet1** (if there are multiple host-only networks, pick VMnet1)
11. Click **OK**

### 5.4 Add the Second Adapter to the Kali VM

Repeat the exact same process for Kali:

1. **Shut down the Kali VM** if it is running (click the power icon in the top-right corner of the Kali desktop, then Shut Down)
2. Click on the **Kali** VM in the left sidebar
3. Click **Edit virtual machine settings**
4. Click **Add...** at the bottom
5. Select **Network Adapter**
6. Click **Finish**
7. Click on the new **Network Adapter 2**
8. Select **Host-only: A private network shared with the host**
9. Make sure it says **VMnet1**
10. Click **OK**

### 5.5 Boot Both VMs

1. Start the **Windows-Target** VM (click the green play button)
2. Start the **Kali** VM (click the green play button)
3. Wait for both to fully boot and reach their desktops

### 5.6 Confirm the IP Address on Windows (Host-Only Adapter)

VMware Workstation Pro runs a local DHCP service on the Host-Only (VMnet1) network. These DHCP-assigned IP addresses are highly stable and do not fluctuate in normal lab usage, meaning you do not need to configure complex static IPs. Let us find and confirm the IP address assigned to your Windows VM:

1. In the Windows VM, open a PowerShell window.
2. Run the following command:

```powershell
ipconfig
```

3. Look for the Ethernet adapter corresponding to the Host-Only network (typically named "Ethernet 1" or similar, which does not have a Default Gateway listed).
4. Confirm that its IPv4 address is:
   - `192.168.85.128` (Windows)

### 5.7 Confirm the IP Address on Kali (Host-Only Adapter)

Now we will find and confirm the IP address assigned to your Kali VM:

1. In the Kali VM, open a terminal.
2. Run the following command:

```bash
ip a
```

3. Look for your Host-Only adapter (typically `eth1`).
4. Confirm that its IPv4 address is:
   - `192.168.85.129` (Kali)

### 5.8 Final IP Address Table

| Machine | Role | NAT IP (Adapter 1) | Host-Only IP (Adapter 2) |
|:--------|:-----|:-------------------|:-------------------------|
| **Windows-Target** | Victim endpoint | Automatic (DHCP) | `192.168.85.128` (Windows) |
| **Kali** | Attacker workstation | Automatic (DHCP) | `192.168.85.129` (Kali) |

**Write these IPs down.** You will use them in every module of this course.

---

## Part 6: Installing Sysmon on Windows

Sysmon (System Monitor) is a free tool from Microsoft Sysinternals that logs detailed information about everything that happens on the system: which processes start, what command lines they use, which network connections they make, which files they create, and which DLLs they load.

Without Sysmon, you are blind to what defenders see. **This is not optional for this course.**

### 6.1 Why Sysmon Matters

Windows has built-in event logging, but it is limited:

| Feature | Without Sysmon | With Sysmon |
|:--------|:---------------|:------------|
| Process creation | Basic (Event ID 4688) | Detailed (Event ID 1): full command line, parent process, user, file hash |
| Network connections | Not logged by default | Every connection mapped to the exact process (Event ID 3) |
| File creation | Not logged | Logged with full path and creating process (Event ID 11) |
| DLL loads | Not logged | Logged with path, hash, and signature (Event ID 7) |
| DNS queries | Not logged | Logged with the domain name and requesting process (Event ID 22) |

In every module of this course, after executing an attack technique, you will switch to the Sysmon log to see exactly what was recorded. This is how you develop the "attacker-defender dual perspective."

### 6.2 Transfer Files Into the Windows VM

You need to get two files into the Windows VM:
- `Sysmon.zip` (from Microsoft)
- `sysmonconfig-export.xml` (from SwiftOnSecurity)

**Method 1: Drag and Drop (Easiest)**

If VMware Tools is installed (it should be from Part 3):
1. On your host machine, open **File Explorer** and navigate to your `Downloads` folder
2. Find `Sysmon.zip` and `sysmonconfig-export.xml` (or the SwiftOnSecurity ZIP you downloaded)
3. Drag both files from your host's File Explorer INTO the VMware window showing the Windows desktop
4. They will be copied to the Windows VM's Desktop

**Method 2: Shared Folder**

If drag-and-drop does not work:
1. In VMware, click **VM** in the top menu
2. Click **Settings...**
3. Click the **Options** tab at the top
4. Click **Shared Folders** on the left
5. Under "Folder sharing", select **Always enabled**
6. Click **Add...** and browse to a folder on your host (like your `Downloads` folder)
7. Click **OK** twice
8. Inside the Windows VM, open **File Explorer**
9. Navigate to **Network > vmware-host > Shared Folders** -- your shared folder appears here
10. Copy the files from here to the Desktop

**Method 3: Download Directly Inside the VM**

If neither works, just open Edge inside the Windows VM and download the files again from the same URLs (Part 1.4 and 1.5).

### 6.3 Extract Sysmon

1. Inside the Windows VM, navigate to wherever you put `Sysmon.zip` (Desktop, Downloads, etc.)
2. **Right-click** on `Sysmon.zip`
3. Click **Extract All...**
4. In the "Extract to" field, type: `C:\Tools\Sysmon`
5. Click **Extract**
6. A File Explorer window opens showing the extracted files. You should see: `Sysmon.exe`, `Sysmon64.exe`, and `Eula.txt`

### 6.4 Copy the Configuration File

1. Find `sysmonconfig-export.xml` (if you downloaded the full SwiftOnSecurity ZIP, extract it first, then find the `.xml` file inside)
2. **Copy** the `sysmonconfig-export.xml` file
3. **Paste** it into `C:\Tools\Sysmon\` (the same folder as the Sysmon executables)

Your `C:\Tools\Sysmon\` folder should now contain:
```
C:\Tools\Sysmon\
  Eula.txt
  Sysmon.exe
  Sysmon64.exe
  sysmonconfig-export.xml
```

### 6.5 Install Sysmon

1. Click the **Start** button
2. Type `PowerShell`
3. In the search results, you will see **Windows PowerShell**
4. **Right-click** on it
5. Click **Run as administrator**
6. If Windows asks "Do you want to allow this app to make changes?", click **Yes**
7. The PowerShell window opens with a blue background and the title says "Administrator"

Now type these commands one at a time, pressing Enter after each:

```powershell
cd C:\Tools\Sysmon
```

```powershell
.\Sysmon64.exe -accepteula -i sysmonconfig-export.xml
```

Wait a few seconds. You should see output like:

```
System Monitor v15.xx - System activity monitor
By Mark Russinovich and Thomas Garnier
Copyright (C) 2014-2024 Microsoft Corporation
Using rule file: sysmonconfig-export.xml

Sysmon64 installed.
SysmonDrv installed.
Starting SysmonDrv.
SysmonDrv started.
Starting Sysmon64..
Sysmon64 started.
```

If you see "Sysmon64 started" at the end, the installation was successful.

### 6.6 Verify Sysmon Is Running

Still in the same Administrator PowerShell window, type:

```powershell
Get-Service Sysmon64
```

You should see:

```
Status   Name               DisplayName
------   ----               -----------
Running  Sysmon64           Sysmon64
```

The status must say `Running`. If it says `Stopped`, type:

```powershell
Start-Service Sysmon64
```

### 6.7 View Sysmon Logs in Event Viewer

Let us make sure Sysmon is actually logging events:

1. Press **Win + R** (the Windows key and the R key at the same time)
2. Type `eventvwr.msc` and press **Enter**
3. The Event Viewer window opens
4. On the left side, click the arrow next to **Applications and Services Logs** to expand it
5. Click the arrow next to **Microsoft** to expand it
6. Click the arrow next to **Windows** to expand it
7. Scroll down and find **Sysmon** -- click the arrow next to it
8. Click **Operational**
9. You should see events in the center panel. These are Sysmon events being logged in real time

**Quick test to confirm it works:**

1. Open **Notepad** (Start > type `notepad` > press Enter)
2. Go back to the Event Viewer window
3. Click **Refresh** (the icon with two green arrows at the top, or press F5)
4. Look for the newest events at the top of the list
5. Find an event with Task Category **"Process Create (rule: ProcessCreate)"**
6. Click on it
7. In the bottom panel, you should see details including:
   - `Image: C:\Windows\system32\notepad.exe`
   - `CommandLine: "C:\Windows\system32\notepad.exe"`
   - `ParentImage:` (whatever launched Notepad)

**This is exactly what a SOC analyst sees when something runs on a machine.** You will use this view throughout the entire course.

### 6.8 Viewing Sysmon Logs with PowerShell

Event Viewer is great for browsing, but PowerShell is faster for targeted searches. Here are the commands you will use most often:

**View the last 10 process creation events:**

```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 10 |
    Where-Object { $_.Id -eq 1 } |
    Format-List TimeCreated, Message
```

**View the last 5 network connection events:**

```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 20 |
    Where-Object { $_.Id -eq 3 } |
    Select-Object -First 5 |
    Format-List TimeCreated, Message
```

**Search for a specific process name (e.g., certutil):**

```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 100 |
    Where-Object { $_.Id -eq 1 -and $_.Message -match "certutil" } |
    Format-List TimeCreated, Message
```

You do not need to memorize these now. We will use them step-by-step in every module.

### 6.9 Sysmon Event ID Reference

Bookmark this table. You will refer to it throughout the course:

| Event ID | Name | What It Logs | When We Use It |
|:---------|:-----|:-------------|:---------------|
| **1** | Process Create | Process name, command line, parent process, hashes, user | Every module |
| **3** | Network Connection | Source/destination IP:port, process name | Module 03, 04 |
| **7** | Image Loaded | DLL loads with path, hash, signature | Module 04 |
| **11** | File Create | File path, creating process | Module 03 |
| **13** | Registry Value Set | Key, value, data | Module 07 |
| **22** | DNS Query | Domain name, requesting process | Module 04 |
| **25** | Process Tampering | Process hollowing/herpaderping detection | Module 07 |

### 6.10 Enable Command Line Logging (Extra Layer)

Sysmon already captures command lines, but let us also enable the built-in Windows logging as a second source:

In the same Administrator PowerShell window:

```powershell
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit" /v ProcessCreationIncludeCmdLine_Enabled /t REG_DWORD /d 1 /f
```

You should see: `The operation completed successfully.`

Then:

```powershell
auditpol /set /subcategory:"Process Creation" /success:enable
```

You should see: `Success`

Now Windows Security Event ID 4688 will also include full command lines alongside Sysmon Event ID 1.

---

## Part 7: Configuring the Windows VM

### 7.1 Create the Tools and Labs Folders

Open Administrator PowerShell (if you closed the one from Part 6, open it again: Start > type `PowerShell` > right-click > Run as administrator):

```powershell
New-Item -ItemType Directory -Path "C:\Tools" -Force
New-Item -ItemType Directory -Path "C:\Tools\Sysmon" -Force
New-Item -ItemType Directory -Path "C:\Tools\Labs" -Force
```

> **Note:** The `C:\Tools\Sysmon` folder already exists from Part 6.3. The `-Force` flag means it will not error if the folder already exists.

### 7.2 Verify .NET Framework (Required for MSBuild Exercises)

Several exercises in Module 04 use `msbuild.exe`, which is part of .NET Framework. It is pre-installed on Windows 11. Let us verify:

```powershell
Test-Path "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe"
```

This should return `True`. If it returns `True`, you are good.

> **Note:** `msbuild.exe` is NOT in your system PATH by default, so `Get-Command msbuild.exe` may return nothing. That is normal. We will always use the full path: `C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe`

### 7.3 Verify LOLBINs Are Present

Run this script to check that all Living-off-the-Land Binaries (LOLBINs) we will use in this course exist on the system:

```powershell
$lolbins = @(
    "certutil.exe",
    "mshta.exe",
    "rundll32.exe",
    "bitsadmin.exe",
    "regsvr32.exe",
    "wscript.exe",
    "cscript.exe",
    "curl.exe"
)

foreach ($bin in $lolbins) {
    $result = Get-Command $bin -ErrorAction SilentlyContinue
    if ($result) {
        Write-Host "[OK] $bin found at $($result.Source)" -ForegroundColor Green
    } else {
        Write-Host "[MISSING] $bin NOT FOUND" -ForegroundColor Red
    }
}

# Check msbuild separately (not in PATH)
$msbuild = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe"
if (Test-Path $msbuild) {
    Write-Host "[OK] msbuild.exe found at $msbuild" -ForegroundColor Green
} else {
    Write-Host "[MISSING] msbuild.exe NOT FOUND at $msbuild" -ForegroundColor Red
}
```

All entries should show `[OK]` in green. These are built-in Windows binaries that should always be present.

### 7.4 Configure Microsoft Edge

Edge is the default browser on Windows 11. We will use it as the target for HTML smuggling exercises.

1. Click the **Start** button and open **Microsoft Edge**
2. If Edge shows a "Welcome" or "Set up" wizard, skip through it (click Skip or Not Now for everything)

**Change the download behavior:**

3. Click the **three dots (...)** in the top-right corner of Edge
4. Click **Settings**
5. In the left sidebar, click **Downloads**
6. You will see **Location** -- leave it as the default (`C:\Users\user\Downloads`)
7. Find the toggle for **Ask me what to do with each download** -- turn it **OFF**
8. This makes downloads go directly to the Downloads folder without asking every time

**Set tracking prevention to Basic:**

9. In the left sidebar, click **Privacy, search, and services**
10. Under **Tracking prevention**, select **Basic**
11. This prevents Edge from blocking content on our local lab pages

**Leave SmartScreen ON:**

> **Do NOT disable SmartScreen.** SmartScreen being active during exercises IS the lesson. You will see which techniques trigger it and which bypass it.

### 7.5 Configure Windows Defender

> **Do NOT disable Windows Defender.** The purpose of this course is to understand how delivery chains interact with real defenses. Disabling Defender defeats the purpose.

The only change we make is adding an exclusion for our labs folder so that harmless exercise files do not get quarantined:

In Administrator PowerShell:

```powershell
Add-MpPreference -ExclusionPath "C:\Tools\Labs"
```

This tells Defender: "Do NOT scan files inside `C:\Tools\Labs`." Defender still actively monitors everything else on the system.

---

## Part 8: Configuring the Kali VM

### 8.1 Update the System

Before installing any tools, update Kali to the latest packages.

1. Open a terminal in Kali (right-click desktop > Open Terminal Here)
2. Run:

```bash
sudo apt update && sudo apt upgrade -y
```

3. When prompted for your password, type the password you set in Part 4.6
4. If asked "Do you want to continue?", type `Y` and press Enter
5. Wait for the update to finish (10-20 minutes depending on internet speed)

### 8.2 Install Required Tools

Most tools come pre-installed on Kali, but let us make sure everything we need is present. Run this single command:

```bash
sudo apt install -y apache2 python3 python3-pip curl wget net-tools dnsutils vim nano tmux xxd
```

Each of these tools serves a specific purpose:

| Tool | Purpose |
|:-----|:--------|
| `apache2` | Full web server for hosting HTML pages with custom MIME types |
| `python3` | Python HTTP server for quick file serving |
| `curl` and `wget` | Downloading files and testing HTTP connections |
| `net-tools` | Network utilities like `ifconfig` and `netstat` |
| `dnsutils` | DNS tools like `dig` and `nslookup` |
| `vim` and `nano` | Text editors for creating lab files |
| `tmux` | Terminal multiplexer for running multiple terminals in one window |
| `xxd` | Hex dump tool for examining file contents |

### 8.3 Create the Lab Directories

```bash
mkdir -p ~/labs/payloads
mkdir -p ~/labs/html
mkdir -p ~/labs/scripts
```

This creates:
- `~/labs/payloads/` -- for payload files served to the Windows VM
- `~/labs/html/` -- for HTML smuggling pages
- `~/labs/scripts/` -- for automation scripts

### 8.4 Test the Python HTTP Server

The Python HTTP server is how we will serve files to the Windows VM during exercises. Let us test it now:

1. Create a test file:

```bash
echo "If you can read this, your lab network works!" > ~/labs/test.txt
```

2. Start the HTTP server:

```bash
cd ~/labs
python3 -m http.server 8080
```

3. You should see: `Serving HTTP on 0.0.0.0 port 8080 (http://0.0.0.0:8080/) ...`
4. **Leave this running** -- do NOT close this terminal. We will test it from the Windows VM in the next section.
5. To stop it later, press `Ctrl+C`

### 8.5 Set Up Apache Web Server

For exercises that need custom MIME types or more complex web server features, we use Apache:

1. Open a **new** terminal tab (right-click the terminal title bar > New Tab, or press Ctrl+Shift+T)
2. Start Apache:

```bash
sudo systemctl start apache2
```

3. Enable it to start automatically when Kali boots:

```bash
sudo systemctl enable apache2
```

4. Verify it is running:

```bash
sudo systemctl status apache2
```

You should see a green dot and `active (running)`. Press `q` to exit the status view.

5. Create a test page:

```bash
echo "<h1>Kali Attack Server - Apache is working</h1>" | sudo tee /var/www/html/index.html
```

Apache serves files from `/var/www/html/` by default.

---

## Part 9: Verifying Everything Works

This is the moment of truth. We will verify four things:
1. VMs can ping each other
2. The Windows VM can load web pages from the Kali VM
3. Sysmon logs the connection
4. Both web servers work (Python and Apache)

### 9.1 Ping Test: Kali to Windows

In the Kali terminal:

```bash
ping -c 4 192.168.85.128
```

> **Note:** `192.168.85.128` (Windows) is the IP address of your Windows target VM.

Expected output:

```
PING 192.168.85.128 (192.168.85.128) 56(84) bytes of data.
64 bytes from 192.168.85.128: icmp_seq=1 ttl=128 time=0.5 ms
64 bytes from 192.168.85.128: icmp_seq=2 ttl=128 time=0.4 ms
64 bytes from 192.168.85.128: icmp_seq=3 ttl=128 time=0.3 ms
64 bytes from 192.168.85.128: icmp_seq=4 ttl=128 time=0.4 ms
```

If you see replies, the Kali VM can reach the Windows VM. If you see "Destination Host Unreachable" or timeouts, go to Part 11 (Troubleshooting).

### 9.2 Ping Test: Windows to Kali

In the Windows VM, open PowerShell and run:

```powershell
ping 192.168.85.129
```

> **Note:** `192.168.85.129` (Kali) is the IP address of your Kali attacker VM.

Expected output:

```
Reply from 192.168.85.129: bytes=32 time<1ms TTL=64
Reply from 192.168.85.129: bytes=32 time<1ms TTL=64
Reply from 192.168.85.129: bytes=32 time<1ms TTL=64
Reply from 192.168.85.129: bytes=32 time<1ms TTL=64
```

### 9.3 HTTP Test: Python Server

Make sure the Python HTTP server is still running on Kali (from Part 8.4).

1. In the Windows VM, open **Microsoft Edge**
2. In the address bar, type: `http://192.168.85.129:8080/test.txt` (Kali)
3. Press Enter
4. You should see the text: **"If you can read this, your lab network works!"**

### 9.4 HTTP Test: Apache Server

1. In Edge, type in the address bar: `http://192.168.85.129` (Kali)
2. Press Enter
3. You should see: **"Kali Attack Server - Apache is working"**

### 9.5 Sysmon Test: Verify Detection Telemetry

This is the most important verification. We want to confirm that Sysmon logged the HTTP connection you just made.

1. In the Windows VM, open **Administrator PowerShell**
2. Run:

```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 50 |
    Where-Object { $_.Id -eq 3 -and $_.Message -match "192.168.85" } |
    Select-Object -First 1 |
    Format-List TimeCreated, Message
```

You should see output like:

```
TimeCreated : 5/23/2026 10:30:42 AM
Message     : Network connection detected:
              ...
              Image: C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe
              ...
              DestinationIp: 192.168.85.129
              DestinationPort: 8080
              ...
```

**This confirms the entire pipeline works:**
- Kali serves content (attacker)
- Windows connects and downloads (victim)
- Sysmon records everything (defender visibility)

**Congratulations. Your lab is fully operational.**

---

## Part 10: Taking Snapshots

Snapshots save the exact state of a VM at a specific moment. If an exercise breaks something, you revert to the snapshot and you are back to a clean state in 10 seconds.

### 10.1 Take a "Clean Lab" Snapshot of the Windows VM

1. In VMware, click on the **Windows-Target** VM in the left sidebar
2. In the top menu, click **VM**
3. Click **Snapshot**
4. Click **Take Snapshot...**
5. In the "Name" field, type: `Clean Lab - Module 00 Complete`
6. In the "Description" field, type: `Sysmon installed, networking configured, tools verified, Defender active`
7. Check **Capture the virtual machine's memory** (this saves the running state -- you can resume exactly where you left off)
8. Click **Take Snapshot**
9. Wait a few seconds for VMware to save the snapshot

### 10.2 Take a "Clean Lab" Snapshot of the Kali VM

Repeat the same process:

1. Click on the **Kali** VM in the left sidebar
2. Click **VM > Snapshot > Take Snapshot...**
3. Name: `Clean Lab - Module 00 Complete`
4. Description: `Tools installed, networking configured, Apache running`
5. Check **Capture the virtual machine's memory**
6. Click **Take Snapshot**

### 10.3 Snapshot Strategy

Take a new snapshot before starting modules that create files or change settings:

| When | Snapshot Name |
|:-----|:-------------|
| After completing Module 00 | `Clean Lab - Module 00 Complete` (you just did this) |
| Before Module 03 exercises | `Before Module 03 - HTML Smuggling` |
| Before Module 04 exercises | `Before Module 04 - LOLBINs` |
| Before Module 08 capstone | `Before Module 08 - Capstone` |

### 10.4 How to Revert to a Snapshot

When you need to go back to a clean state:

1. Click on the VM in the left sidebar
2. Click **VM > Snapshot > Snapshot Manager...**
3. A tree of snapshots appears
4. Click on the snapshot you want to restore
5. Click **Go To**
6. VMware asks "Are you sure?" -- click **Yes**
7. The VM reverts to the saved state in a few seconds

---

## Part 11: Troubleshooting

### Problem: VMs Cannot Ping Each Other

**Symptom:** `ping 192.168.85.128` from Kali returns "Destination Host Unreachable" or times out.

**Solution 1: Windows Firewall is blocking ping**

Windows Firewall blocks ICMP (ping) by default. Allow it:

1. In the Windows VM, open Administrator PowerShell
2. Run:

```powershell
New-NetFirewallRule -DisplayName "Allow ICMPv4-In" -Protocol ICMPv4 -IcmpType 8 -Direction Inbound -Action Allow
```

3. Try pinging again from Kali

**Solution 2: Adapters are on different VMnets**

1. Check the Windows VM: click **VM > Settings** > look at Network Adapter 2 -- it should say **Host-only (VMnet1)**
2. Check the Kali VM: click **VM > Settings** > look at Network Adapter 2 -- it should ALSO say **Host-only (VMnet1)**
3. Both MUST be on the same VMnet

**Solution 3: DHCP IP was not assigned properly**

In the Windows VM, run `ipconfig /all` and verify:
- One adapter has a gateway (this is NAT -- correct)
- The other adapter has your Host-Only IP `192.168.85.128` (Windows)

In the Kali VM, run `ip a` and verify:
- `eth0` has a NAT IP (like `192.168.233.136`)
- `eth1` has your Host-Only IP `192.168.85.129` (Kali)

If either adapter lacks an IP, try requesting one:
- Windows: `ipconfig /renew`
- Kali: `sudo dhclient eth0` or `sudo dhclient eth1`

**Solution 4: Interface is down on Kali**

```bash
sudo ip link set eth1 up
```

### Problem: Windows VM Has No Internet

**Symptom:** Edge cannot load any websites.

**Check:** Run `ipconfig` -- Network Adapter 1 (NAT) should have an IP like `192.168.xx.xx` assigned by DHCP. If it has no IP:

1. Click **VM > Settings**
2. Check that **Network Adapter** (the first one) is set to **NAT**
3. Make sure **Connected** and **Connect at power on** are both checked
4. Click OK and restart the VM

**Check:** Did you accidentally set a static IP on the NAT adapter? The NAT adapter should be set to "Obtain an IP address automatically" (DHCP).

### Problem: Sysmon Not Logging Events

**Symptom:** Event Viewer shows no events under Sysmon > Operational.

**Fix 1: Verify Sysmon is running:**

```powershell
Get-Service Sysmon64
```

If it shows `Stopped`:

```powershell
Start-Service Sysmon64
```

**Fix 2: Verify the config was loaded:**

```powershell
C:\Tools\Sysmon\Sysmon64.exe -c
```

This should print the loaded rules. If it says "No rules installed":

```powershell
C:\Tools\Sysmon\Sysmon64.exe -c C:\Tools\Sysmon\sysmonconfig-export.xml
```

**Fix 3: Reinstall Sysmon:**

```powershell
C:\Tools\Sysmon\Sysmon64.exe -u force
C:\Tools\Sysmon\Sysmon64.exe -accepteula -i C:\Tools\Sysmon\sysmonconfig-export.xml
```

### Problem: Python HTTP Server Shows "Address Already in Use"

**Symptom:** When you run `python3 -m http.server 8080`, it says the port is already in use.

**Fix:** Use a different port:

```bash
python3 -m http.server 9090
```

Then access it from Windows at `http://192.168.85.129:9090/` (Kali) instead.

Or kill whatever is using port 8080:

```bash
sudo fuser -k 8080/tcp
```

### Problem: VMware Says "Cannot Connect the Virtual Device"

**Symptom:** VMware shows an error about CD/DVD or network adapter when starting a VM.

**Fix:** This usually means the ISO or network device from the original configuration is not found. Click **No** or **OK** to dismiss the warning. The VM will still boot fine.

### Problem: Not Enough RAM

**Symptom:** VMs are very slow, your host machine freezes.

**Fix:** Reduce VM memory allocation:
- Windows VM: Minimum **3072 MB** (3 GB) -- below this it becomes unusable
- Kali VM: Minimum **2048 MB** (2 GB) -- works for terminal-based exercises
- Total: 5 GB for VMs, leaving the rest for your host

**Tip:** Close browsers and other heavy apps on your host machine before running the lab.

**Tip:** Do not run both VMs simultaneously during initial setup. Set up one, shut it down, set up the other.

---

## Lab Setup Complete

If you have reached this point and completed all the verifications in Part 9, your lab is ready.

### Final Checklist

```
[x] VMware Workstation Pro installed and licensed (personal use)
[x] Windows 11 VM created with 4+ GB RAM, 2+ CPU cores
[x] Kali Linux VM imported with 4+ GB RAM, 2+ CPU cores
[x] VMware Tools working on Windows VM (auto-resize, drag-and-drop)
[x] Dual adapter networking: NAT (internet) + Host-Only VMnet1 (attack network)
[x] Host-Only IPs confirmed: Windows = 192.168.85.128, Kali = 192.168.85.129
[x] Sysmon installed on Windows with SwiftOnSecurity configuration
[x] Sysmon is actively logging (verified via Event Viewer and PowerShell)
[x] Command line logging enabled (Event ID 4688)
[x] .NET Framework / msbuild.exe verified on Windows
[x] All LOLBINs verified present on Windows
[x] Edge configured (SmartScreen ON, auto-download ON, tracking Basic)
[x] Defender active with exclusion for C:\Tools\Labs only
[x] Kali updated and tools installed
[x] Python HTTP server tested
[x] Apache web server running
[x] Ping tests passed (both directions)
[x] HTTP test passed (Windows loaded page from Kali)
[x] Sysmon logged the HTTP connection (Event ID 3 verified)
[x] Clean snapshots taken for both VMs
```

**Next module:** [01_defense_landscape.md](01_defense_landscape.md) -- Understanding every layer of defense before you try to bypass any of them.
