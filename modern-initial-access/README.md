# Modern Initial Access -- Enterprise Delivery Chains, Trust Abuse, and Detection-Aware Tradecraft

A standalone, beginner-to-advanced offensive security course that teaches how modern adversaries gain initial access to enterprise networks in 2026.

This is **not** a malware development course. It teaches delivery chain mechanics, trust boundary abuse, staging concepts, execution flow understanding, and detection-aware tradecraft from the perspective of a professional red team operator.

Every attack technique is paired with its corresponding detection telemetry, so you learn both offense and defense simultaneously.

---

## Who This Course Is For

- Security professionals learning red team operations
- Penetration testers who want to understand modern delivery chains
- Blue teamers who want to understand what attackers actually do in 2026
- Students building their offensive security skill set from scratch

## Prerequisites

- Basic understanding of Windows (file system, processes, command prompt)
- Basic understanding of Linux (terminal, file system, package management)
- Basic understanding of networking (IP addresses, ports, HTTP)
- A computer with at least 16 GB RAM and 80 GB free disk space
- No prior red team or penetration testing experience required

---

## Course Roadmap

```
Module 00: Lab Setup
    Build your attack lab from scratch
    Windows VM, Kali VM, networking, Sysmon, browser config, snapshots

Module 01: The Defense Landscape
    Understand every layer of defense before trying to bypass any of them
    MOTW, SmartScreen, Smart App Control, browser security, email gateways, AMSI, EDR

Module 02: A History of What Died and Why
    Learn from the graveyard of techniques (2022-2026)
    VBA macros, ISO/VHD bypass, OneNote abuse, LNK Stomping, CVE timeline

Module 03: Browser Delivery and HTML Smuggling
    The delivery technique that survived everything
    JavaScript Blob API, encoding layers, cloud-hosted delivery, detection telemetry

Module 04: LOLBINs and Execution Chains
    Chaining trusted binaries to execute untrusted code
    certutil, mshta, msbuild, rundll32, DLL sideloading, detection per binary

Module 05: Modern Workflow Abuse
    Exploiting the tools the organization already trusts
    ClickFix/pastejacking, Teams abuse, QR phishing, cloud-hosted delivery

Module 06: Identity-First Initial Access
    Why modern attackers log in instead of breaking in
    OAuth consent phishing, device code phishing, AitM concepts, session theft

Module 07: Detection and OPSEC
    How professionals think about operational security
    Staging concepts, forensic footprint, Sysmon telemetry, OPSEC hierarchy

Module 08: Capstone Simulation
    Full attack chain with simultaneous detection analysis
    End-to-end delivery chain, detection timeline, operator decision-making
```

---

## Lab Architecture

```
+---------------------------------------------------+
|                  YOUR HOST MACHINE                 |
|                                                    |
|  +---------------------+  +---------------------+ |
|  |    KALI LINUX VM     |  |    WINDOWS 11 VM    | |
|  |    (Attacker)        |  |   (Victim/Target)   | |
|  |                      |  |                      | |
|  |  - Python HTTP server|  |  - Microsoft Edge    | |
|  |  - Sliver C2 (opt.)  |  |  - Sysmon installed  | |
|  |  - curl / wget       |  |  - .NET Framework    | |
|  |  - Web server tools  |  |  - PowerShell 5.1+   | |
|  |                      |  |  - Defender (enabled) | |
|  |  Adapter 1: NAT      |  |  Adapter 1: NAT      | |
|  |  Adapter 2: Host-Only|  |  Adapter 2: Host-Only | |
|  +--------|-------------+  +--------|-------------+ |
|           |                         |                |
|           +--------+  +------------+                 |
|                    |  |                               |
|              +-----|--|------+                        |
|              | Host-Only Net |                        |
|              | VMnet1        |                        |
|              +---------------+                        |
+---------------------------------------------------+
```

### Hypervisor: VMware Workstation Pro

This course uses **VMware Workstation Pro** exclusively. It is free for personal use since 2024.

### Network Design: Dual Adapter Setup

Each VM gets TWO network adapters:

| Adapter | Type | Purpose |
|:--------|:-----|:--------|
| **Adapter 1** | NAT | Internet access for updates, downloads, tool installation |
| **Adapter 2** | Host-Only (VMnet1) | Isolated attack network where VMs communicate with each other |

**Why dual adapters?**
- NAT gives you internet access for setup and tool installation
- Host-Only (VMnet1) creates an isolated network where your attack traffic never leaves your machine
- During exercises, you can disable the NAT adapter to simulate an air-gapped environment
- This mirrors real enterprise network segmentation

---

## Tooling Stack

### Windows VM (Victim/Target)

| Tool | Purpose | Source |
|:-----|:--------|:-------|
| Windows 11 | Target operating system | Free evaluation ISO from Microsoft (90-day) |
| Sysmon | Detection telemetry (process, network, file events) | Free from Microsoft Sysinternals |
| SwiftOnSecurity Sysmon Config | Production-quality Sysmon rules | Free from GitHub |
| Microsoft Edge | Default browser, HTML smuggling target | Pre-installed |
| .NET Framework | Required for msbuild.exe exercises | Pre-installed on Windows 11 |
| PowerShell 5.1+ | Log analysis, MOTW inspection | Pre-installed |

### Kali Linux VM (Attacker)

| Tool | Purpose | Source |
|:-----|:--------|:-------|
| Python 3 | HTTP server for payload hosting | Pre-installed on Kali |
| curl | HTTP requests and testing | Pre-installed on Kali |
| Sliver C2 | Optional C2 framework (capstone only) | Free, open-source |
| apache2 | Alternative web server | Pre-installed on Kali |
| Visual Studio Code / vim | File editing | Pre-installed or easily installed |

---

## Detection Stack

All detection in this course uses **free, built-in tools**. No commercial SIEM or EDR required.

| Component | What It Does | Key Event IDs |
|:----------|:-------------|:--------------|
| **Sysmon** | Process creation, network connections, file creation, DLL loads, registry changes | EID 1, 3, 7, 11, 13, 22, 25 |
| **Windows Security Log** | Process creation (with command line), logon events | EID 4688, 4624 |
| **Windows Event Viewer** | Log browsing and filtering | Built into Windows |
| **PowerShell** | Log querying and analysis | `Get-WinEvent` cmdlet |

---

## Safety Boundaries

> **IMPORTANT**: Every exercise in this course is designed to be safe and non-destructive.

- All "payloads" are harmless: they launch `calc.exe`, run `whoami`, or write text files
- No actual malware, shellcode, or weaponized documents are created
- No destructive actions are performed on any system
- All traffic stays within the isolated Host-Only network
- Defender remains enabled on the Windows VM (this is intentional -- you learn what it catches)
- Every exercise clearly states what it does before you run it

**This course teaches you to UNDERSTAND delivery chains, not to build weapons.**

---

## Folder Structure

```
modern-initial-access/
    README.md                   <-- You are here
    walkthroughs/
        00_lab_setup.md
        01_defense_landscape.md
        02_history_of_dead_techniques.md
        03_browser_delivery_and_html_smuggling.md
        04_lolbins_and_execution_chains.md
        05_modern_workflow_abuse.md
        06_identity_first_access.md
        07_detection_and_opsec.md
        08_capstone_simulation.md
    labs/
        (lab files created as you progress through each module)
```

---

## How to Use This Course

1. Start with **Module 00** to build your lab environment
2. Follow the modules **in order** -- each builds on the previous one
3. **Do every lab exercise** -- reading alone will not build the skills
4. **Take snapshots** before each module so you can roll back if something breaks
5. **Read the detection sections** -- understanding what defenders see is what separates a script kiddie from a professional

---

## Estimated Time

| Module | Estimated Time |
|:-------|:---------------|
| 00 - Lab Setup | 2-3 hours |
| 01 - Defense Landscape | 2-3 hours |
| 02 - History of Dead Techniques | 1-2 hours (reading + discussion) |
| 03 - Browser Delivery and HTML Smuggling | 3-4 hours |
| 04 - LOLBINs and Execution Chains | 3-4 hours |
| 05 - Modern Workflow Abuse | 2-3 hours |
| 06 - Identity-First Access | 2-3 hours (conceptual + demos) |
| 07 - Detection and OPSEC | 2-3 hours |
| 08 - Capstone Simulation | 3-4 hours |
| **Total** | **~20-30 hours** |
