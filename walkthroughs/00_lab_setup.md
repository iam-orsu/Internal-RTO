# Module 00: Lab Setup

## What This Module Covers

Before we touch a single tool or run a single command, we need a functioning Active Directory lab. This module walks you through building one from scratch. But before the build, we need to understand why we are doing this and what the end goal looks like.

By the end of this module you will have:

- A Domain Controller running Windows Server 2022 (DC01)
- A domain-joined workstation running Windows 10/11 (WS01)
- A Kali Linux attacker machine
- All three on the same internal network, talking to each other
- A fully configured domain called orsubank.local with users, groups, services, and intentional misconfigurations

---

## Why Are We Building This Lab?

Most people learn Active Directory attacks by reading blog posts or watching someone else do it. That gives you surface-level knowledge. You can memorize tool names and flags but when you sit in front of a real engagement, you freeze because you never built the thing you are trying to break.

This lab exists so you can build, break, and understand Active Directory from the inside. You will set up the domain yourself. You will create the users. You will configure the misconfigurations. And then you will exploit every single one of them. When you understand why something is vulnerable, you stop being a script runner and start being a pentester.

This is not a CTF. There are no flags to capture. This is a simulation of a real corporate network, stripped down to its core so you can focus on learning the attacks without needing 16 GB of RAM and five virtual machines.

---

## Why Do Modern Internal AD Attacks Still Work?

Active Directory has been around since Windows 2000. That is over two decades. So why do pentesters still find the same issues in 2025?

**1. Backward compatibility is king.**
Microsoft cannot just remove old features. Thousands of enterprises depend on NTLM, on legacy delegation, on protocols designed in the early 2000s. Removing them would break production. So they stay enabled by default, and attackers abuse them.

**2. Defaults are dangerous.**
A fresh Active Directory install comes with settings that are convenient but insecure. LLMNR is on. NTLM is allowed. Machine Account Quota is 10 (meaning any user can join up to 10 computers to the domain). Pre-authentication is not enforced by default on some setups. These defaults exist because Microsoft prioritizes "it works out of the box" over "it is secure out of the box."

**3. Admins misconfigure things.**
Even in well-funded companies, you will find service accounts with passwords that never expire, users added to Domain Admins "temporarily" who stay there for years, ACLs that give random groups write access to sensitive objects, and certificates templates that let any authenticated user request a certificate as anyone else. The attack surface is not just technical. It is human.

**4. Kerberos is complex and trust-based.**
Kerberos was designed for trusted networks. It assumes that if you have a valid ticket, you are who you say you are. The entire ticket-granting system can be abused if you get access to the right hashes or keys. Golden Tickets, Silver Tickets, delegation abuse, and roasting attacks all come from how Kerberos handles trust.

**5. Detection is hard.**
Many AD attacks look like normal admin activity. A DCSync looks like domain controller replication. A Pass-the-Hash looks like a normal NTLM login. A Kerberoast request looks like a normal service ticket request. Blue teams struggle to catch these without proper monitoring and baselines.

---

## What Will You Learn?

Here is the full attack chain you will execute across all modules:

| Module | What You Learn | Real-World Skill |
|:-------|:---------------|:-----------------|
| 00 (this one) | Build and configure an AD lab from scratch | Understanding AD architecture |
| 01 | Enumerate the domain with LDAP, BloodHound, PowerView | Mapping attack paths |
| 02 | Escalate privileges on a local machine | Getting from low-priv to local admin |
| 03 | Dump credentials from memory, registry, DPAPI | Harvesting passwords and hashes |
| 04 | Kerberoast and AS-REP Roast service/user accounts | Cracking Kerberos tickets offline |
| 05 | Abuse ACLs to take over users, groups, and objects | Exploiting permission misconfigurations |
| 06 | Abuse delegation (unconstrained, constrained, RBCD) | Impersonating users across services |
| 07 | Exploit ADCS misconfigurations (ESC1, ESC4, ESC8) | Certificate-based domain takeover |
| 08 | Coerce authentication and relay NTLM hashes | Forcing machines to authenticate to you |
| 09 | Move laterally and achieve domain dominance | DCSync, Golden Tickets, full compromise |

Every module teaches the concept first, then walks you through the attack, then explains what happened and why it worked. No "just run this tool" nonsense.

---

## How Attacks Flow in a Real Enterprise

In a real internal pentest, the attack chain usually looks like this:

```
Initial Access (phishing, VPN creds, physical access)
        |
        v
Local Enumeration (who am I, what machine is this, what domain)
        |
        v
Domain Enumeration (BloodHound, LDAP queries, find attack paths)
        |
        v
Credential Access (dump LSASS, SAM, cached creds, DPAPI)
        |
        v
Privilege Escalation (weak services, misconfigs, token abuse)
        |
        v
Lateral Movement (Pass-the-Hash, Pass-the-Ticket, WMI, PSRemoting)
        |
        v
Domain Escalation (Kerberoast, ACL abuse, delegation, ADCS)
        |
        v
Domain Dominance (DCSync, Golden Ticket, persistence)
```

In our lab, we skip the initial access part (we assume you already have a low-privilege shell on the workstation) and focus on everything after that. This is where the actual skill is. Getting initial access in an engagement is often a phishing email or a VPN credential. The real test of a pentester is what you do after you land on a machine.

---

## Why Only 1 DC + 1 Workstation + Kali?

You might wonder if three machines are enough. Short answer: yes, for learning the core attacks.

**What works perfectly with this setup:**

- All Kerberos attacks (Kerberoast, AS-REP Roast, delegation abuse, Golden/Silver Tickets)
- All credential dumping (LSASS, SAM, DPAPI, cached creds, DCSync)
- All ACL abuse (GenericAll, WriteDACL, WriteOwner, Shadow Creds)
- All ADCS attacks (ESC1, ESC4, ESC8, Golden Certificates)
- NTLM relay and coercion attacks (PrinterBug, PetitPotam, WebDAV)
- Domain enumeration with BloodHound and LDAP
- Local privilege escalation on the workstation
- Pass-the-Hash and Pass-the-Ticket from WS01 to DC01

**What we are skipping (and why it is fine):**

- Multi-hop lateral movement (WS01 to WS02 to WS03): This needs multiple workstations. The concept is the same as single-hop movement, just repeated. Once you can move from WS01 to DC01, you understand lateral movement.
- Forest and trust attacks: These need multiple domains/forests. Important for senior roles, but the fundamentals covered here come first.
- Exchange/SCCM/SQL Server attacks: These need dedicated servers. Good to know, but they are extensions of the same credential and delegation abuse you will learn here.

The point is: with 3 VMs and about 8 GB of RAM total, you can practice 90% of the attacks that show up in real internal pentests and interviews. Adding more machines does not teach you new concepts. It just adds more targets to repeat the same techniques on.

---

## Why Learning AD Pentesting Will Help Your Career

This section is for anyone, especially if you are based in India and aiming at the US, EU, or global cybersecurity market. AD pentesting is not just a technical skill. It is one of the most direct paths to high-paying, remote-friendly offensive security roles.

### The Market Reality

The cybersecurity talent shortage is real and growing. In 2025, the global shortage is estimated at over 3.5 million unfilled positions. The US and EU cannot fill their internal pentest roles domestically. Companies in New York, London, Berlin, and Singapore are hiring remote pentesters from India, Eastern Europe, and Latin America because they simply do not have enough local talent.

Internal network pentesting, specifically Active Directory, is the single most in-demand specialization within offensive security. Every major consulting firm (Deloitte, EY, KPMG, Accenture Security), every specialized security firm (SpecterOps, NetSPI, Bishop Fox, Mandiant), and every large enterprise with an in-house red team needs people who can compromise Active Directory. This is not a niche skill. It is the core of enterprise offensive security.

### Why AD Skills Specifically?

Here is what makes AD pentesting different from other cybersecurity paths:

**1. It is hard to automate away.**
Web application scanning is increasingly automated. Vulnerability scanning is commodity work. But internal AD pentesting requires understanding complex trust relationships, business context, and chaining multiple misconfigurations together. AI tools can help, but they cannot replace the human judgment needed to navigate a real enterprise network without causing outages or getting detected.

**2. The pay is significantly higher than general IT security.**
A general SOC analyst in India might earn 6 to 12 LPA. A pentester with strong AD skills who works with US/EU clients can earn 25 to 60 LPA (remote) or $120K to $200K+ if you relocate or work with a US firm directly. The gap is massive because the skill is rare and the demand is constant.

**3. It opens doors to red team and adversary simulation roles.**
AD pentesting is the foundation of red teaming. Once you can compromise a domain, you can learn evasion, C2 frameworks, and adversary simulation. Red team operators are the highest-paid offensive security professionals, and every single one of them started by learning AD attacks.

**4. Remote work is the norm, not the exception.**
Internal pentesting used to require being on-site. Not anymore. VPN access to client networks, remote lab access, and cloud-based infrastructure mean that a pentester in Hyderabad can do the same engagement as someone in New York. The only difference is the timezone, and most US firms are fine with a 4 to 6 hour overlap.

### How to Position Yourself for US/EU Roles

The Indian cybersecurity market is growing, but US and EU roles pay 3 to 10 times more for the same work. Here is how to get there:

**1. Build a portfolio, not just certifications.**
OSCP and CRTO are important. But what actually gets you hired is demonstrating that you can find and exploit real misconfigurations. Build labs, write detailed blog posts explaining attack chains, contribute to open-source security tools, and document your methodology. Hiring managers in the US care more about what you can demonstrate than what certificate you have on your LinkedIn.

**2. Learn to write professional reports.**
The biggest gap between Indian pentesters and US/EU pentesters is not technical skill. It is communication. US and EU clients expect clear, professional reports that explain risk in business terms. Practice writing findings with: a clear title, a risk rating, a technical explanation that a developer can follow, and a remediation recommendation. If you can write a report that a CISO can understand and a developer can act on, you are more valuable than someone who can find twice as many bugs but cannot explain them.

**3. Understand compliance frameworks.**
US companies operate under SOC 2, PCI-DSS, HIPAA, and NIST frameworks. EU companies deal with GDPR, NIS2, and ISO 27001. Knowing how your pentest findings map to these frameworks makes you immediately more useful to consulting firms that serve these markets. You do not need to be a compliance expert. You just need to understand the basics so you can frame your findings in the right context.

**4. Target consulting firms first.**
Consulting firms (Big 4, specialized security firms) are the easiest entry point for international pentesters. They have global delivery models, they are used to remote teams, and they constantly need AD pentesters for their assessment workload. Once you have 2 to 3 years at a consulting firm on your resume, you can move to higher-paying in-house red team roles at tech companies.

**5. The OSCP is your visa.**
OSCP is not the best certification for learning, but it is the certification that US and EU hiring managers recognize. Think of it as a filter. If you have OSCP + strong AD skills + good communication, you pass the initial screening. CRTO (Certified Red Team Operator) is the second certification that matters. It specifically covers AD attacks with Cobalt Strike, which is exactly what enterprise red teams use.

### What the Career Path Looks Like

| Year | Role | Typical Pay (Remote, US Client) |
|:-----|:-----|:-------------------------------|
| 0 to 1 | Junior Pentester / Security Analyst | $30K to $50K |
| 1 to 3 | Pentester (focus on AD/internal) | $60K to $100K |
| 3 to 5 | Senior Pentester / Red Team Operator | $100K to $150K |
| 5+ | Red Team Lead / Principal Consultant | $150K to $250K+ |

These numbers are for remote work with US clients or US-based firms. If you relocate to the US or EU, the numbers are higher but so is the cost of living. The key point is that even remote roles from India at the $60K to $100K range represent top-tier income by Indian standards, and the demand is only growing.

### The Bottom Line

Active Directory pentesting is not just a module in a course. It is a career accelerator. The skills you learn here, understanding Kerberos, NTLM, ACLs, certificates, delegation, and how they all connect, are the same skills that Fortune 500 companies pay $300+/hour for during consulting engagements. Every company that runs Windows runs Active Directory. Every company that runs Active Directory needs someone who can test it. That person could be you, from anywhere in the world.

---

## Lab Network Layout

Here is what we are building:

```
+------------------------------------------------------------+
|        VMware NAT Network (auto-detected subnet)           |
|        Example: 192.168.138.0/24                           |
|                                                            |
|   +------------+   +------------+   +----------------+     |
|   |   DC01     |   |   WS01     |   |   Kali         |     |
|   | .10        |   | .20        |   | DHCP or .30    |     |
|   | Win Srv    |   | Win 10/11  |   | Linux          |     |
|   | 2022       |   |            |   |                |     |
|   +------------+   +------------+   +----------------+     |
|                                                            |
|   Domain: orsubank.local                                   |
|   DC01: Domain Controller, DNS, ADCS                       |
|   WS01: Domain-joined workstation                          |
|   Kali: Attacker machine (not domain-joined)               |
|   Gateway: .2 (VMware NAT, provides internet)              |
+------------------------------------------------------------+
```

The subnet is auto-detected by the setup script. Whatever VMware assigns as the NAT range (commonly 192.168.x.0/24), the script reads it and assigns .10 for DC, .20 for WS, and suggests .30 for Kali. You do not need to know or configure this manually.

**Hardware requirements:**

| Machine | RAM | Disk | CPU |
|:--------|:----|:-----|:----|
| DC01 (Windows Server 2022) | 2 GB minimum, 3 GB recommended | 40 GB | 2 cores |
| WS01 (Windows 10/11) | 2 GB minimum, 3 GB recommended | 40 GB | 2 cores |
| Kali Linux | 2 GB minimum | 30 GB | 2 cores |
| **Total** | **6 to 9 GB** | **110 GB** | host needs 4+ cores |

You can run this on a machine with 16 GB of RAM comfortably. If you have only 8 GB, it will be tight but doable if you close everything else.

---

## The Future of AD Pentesting: Is This Still Worth Learning in 2026?

This is a fair question. Cloud is everywhere. Microsoft keeps pushing Entra ID (the thing they used to call Azure AD). Zero Trust is the buzzword of every security conference. So why are we building an on-prem Active Directory lab?

Because the real world has not moved on from Active Directory. Not even close.

### The Numbers Tell the Story

Over 90% of enterprise environments still use on-prem Active Directory in some form. About 40% of organizations running hybrid setups still rely on on-prem AD as their primary identity system. Microsoft released Windows Server 2025 with major new Active Directory features and a new functional level. That does not happen for a technology they plan to retire.

The reason is simple. Enterprises built 20+ years of infrastructure on top of AD. Their line-of-business apps use LDAP. Their authentication flows use Kerberos. Their access control depends on Group Policy. Their compliance frameworks reference OU structures. Ripping all of that out and replacing it with cloud-native identity is a multi-year, multi-million-dollar project that most organizations are not ready for.

So what actually happened is this: companies added cloud identity (Entra ID) on top of their existing AD. They did not replace it. They bridged it.

### How Hybrid Identity Actually Works

In most enterprises today, the setup looks like this:

```
On-Premises                          Cloud
+------------------+                +------------------+
|  Active Directory |  <-- Entra --> |    Entra ID      |
|  (orsubank.local) |     Connect    |  (orsubank.com)  |
|                  |                |                  |
|  Users, Groups   |  sync ------>  |  Cloud Users     |
|  Computers       |                |  Cloud Apps      |
|  GPOs, ADCS      |                |  M365, Azure     |
|  Kerberos, NTLM  |                |  OAuth, SAML     |
+------------------+                +------------------+
```

Entra Connect (previously Azure AD Connect) is the bridge. It runs on a server in the on-prem network and synchronizes user accounts, password hashes, and group memberships from on-prem AD to Entra ID in the cloud. There are three sync methods:

- **Password Hash Sync (PHS):** Hashes of on-prem passwords get synced to the cloud. Most common method. Means the cloud has a copy of your password hash.
- **Pass-through Authentication (PTA):** Cloud authentication requests get forwarded to an on-prem agent that validates them against AD. Password never leaves on-prem.
- **Federation (ADFS):** A full federation server handles authentication. Oldest method, being phased out.

The important thing for pentesters is that this bridge creates new attack paths. Compromise on-prem AD, and you can potentially pivot to the cloud. Compromise a cloud admin, and you might be able to push changes back to on-prem. The Entra Connect server itself is a Tier 0 asset because it has credentials that can replicate directory data in both directions.

### Why ADCS, Kerberos, Delegation, and ACL Abuse Still Matter

You might think these attacks are "old school" and only work on legacy networks. Here is why that is wrong:

**ADCS (Active Directory Certificate Services):** Most enterprises run an internal certificate authority for things like WiFi authentication, VPN certificates, code signing, and encrypted email. ADCS misconfigurations (ESC1 through ESC8) let attackers request certificates as any user, including Domain Admins. These attacks were only publicly documented in 2021 (the SpecterOps "Certified Pre-Owned" paper), so many environments have not been audited for them yet. In 2025, ADCS abuse is still one of the most reliable paths to domain takeover.

**Kerberos:** Every domain-joined machine uses Kerberos to authenticate. That will not change as long as Active Directory exists. Kerberoasting, AS-REP Roasting, delegation abuse, and ticket forging all target the core authentication protocol. These are not bugs that get patched. They are design features being used in ways Microsoft did not intend.

**Delegation:** Any enterprise running multi-tier applications (web server talks to database server on behalf of a user) uses delegation. Unconstrained, constrained, and resource-based constrained delegation are all still configured in production. Misconfigurations here let attackers impersonate any user to any service.

**ACL Abuse:** Active Directory permissions are complex. Most environments have accumulated years of permission changes from different admins, migrations, and automated tools. BloodHound finds exploitable ACL paths in nearly every environment it scans. GenericAll, WriteDACL, WriteOwner, and similar permissions are still routinely misconfigured.

### How AI is Changing Offensive Security

AI is not replacing pentesters. But it is changing how the work gets done.

**What AI does well right now:**

- Recon at scale: AI agents can scan every subdomain, port, and service in parallel, then summarize what matters. What used to take a day of manual work now takes minutes.
- Output interpretation: Tools like Nebula and PentestGPT can read the output of Nmap, BloodHound, or Certipy and suggest next steps. Instead of googling error messages, you ask the AI.
- Report writing: Generating finding descriptions, risk ratings, and remediation steps from raw data is where AI saves the most time right now.
- Chaining known techniques: AI can connect "this user has WriteDACL on that group" to "that group has GenericAll on the Domain Admins" faster than most humans can manually trace the path.

**What AI cannot do well (yet):**

- Creative attack chaining that requires business context ("this service account is used by the payroll system, so resetting its password would cause an outage, so instead we should...")
- Judging risk and impact in a way that matters to the client
- Handling unexpected situations where the environment does not match any training data
- Social engineering and physical security testing

**What this means for you:**

The pentesters who will thrive are the ones who understand the fundamentals deeply enough to guide AI tools, validate their output, and handle the cases where automation fails. If you just know how to click buttons in a GUI tool, AI will replace you. If you understand why Kerberos delegation works the way it does, why that ACL is dangerous, and what the business impact of that ADCS misconfiguration is, you become the person who directs the AI, not the person the AI replaces.

That is exactly what this course teaches. Not tool usage. Understanding.

### What Modern Enterprise Attack Paths Look Like Now

The attack paths in 2026 are not fundamentally different from 2020. They are just longer and involve more environments:

```
Phishing / Token Theft / Infostealer
        |
        v
Initial Foothold (on-prem workstation or cloud account)
        |
        v
  +-----+------+
  |            |
  v            v
On-Prem        Cloud
Path           Path
  |            |
  v            v
AD Enum        Entra ID Enum
Kerberoast     App Registration Abuse
ACL Abuse      Conditional Access Bypass
ADCS Abuse     Token Manipulation
Delegation     Service Principal Abuse
  |            |
  v            v
  +-----+------+
        |
        v
Hybrid Pivot (on-prem <-> cloud via Entra Connect)
        |
        v
Domain Dominance / Tenant Takeover
```

The core skill is still the same: understand how identity and trust work, find the weakest link, and chain misconfigurations together until you reach the objective. Whether that objective is the on-prem Domain Admin or the cloud Global Administrator, the methodology is the same.

In this course, we focus on the on-prem side because that is the foundation. Once you understand how Kerberos, NTLM, ACLs, and certificates work in AD, learning the cloud equivalents is straightforward. The concepts transfer. The tools change. The thinking stays.

---

## Hypervisor Setup

You need a hypervisor to run virtual machines. Use one of these:

- **VMware Workstation Pro** (free for personal use since late 2024): best option for Windows hosts
- **VirtualBox** (free, open source): works fine, slightly less polished
- **Hyper-V** (built into Windows Pro/Enterprise): decent but networking can be annoying

This guide uses VMware Workstation as the reference.

### Network Design: NAT Only

Every VM uses a single NAT adapter. That is it. No custom networks, no Virtual Network Editor changes, no dual adapters.

**Why NAT works for this lab:**

- All VMs on the same VMware NAT subnet can already talk to each other (VMware puts them on the same internal virtual switch)
- All VMs get internet access automatically through the NAT gateway
- The setup script auto-detects whatever subnet VMware assigned and sets static IPs for you
- Attack traffic stays inside VMware's virtual network, it never touches your home router
- You do not need to configure anything in Virtual Network Editor

**What the script handles automatically:**

| Task | Old way (manual) | New way (automated) |
|:-----|:-----------------|:--------------------|
| Detect the subnet | You had to know it | Script reads the DHCP address and figures it out |
| Set static IPs | You configured adapter properties manually | Script sets DC to .10 and WS to .20 on whatever subnet VMware uses |
| Set DNS | You typed the DC IP into each adapter | Script does it |
| Set hostname | You went to System Properties | Script does it |
| Internet after DC promotion | DNS broke, you had to add forwarders manually | Script adds DNS forwarders automatically |
| Resume after reboot | You had to remember to re-run the script | Script registers itself to run at next login |

The only things you do manually are: install the OS and set a password. Everything else is scripted.

---

## Step 1: Download the ISOs

You need three things:

### Windows Server 2022 (for DC01)

1. Go to the Microsoft Evaluation Center: https://www.microsoft.com/en-us/evalcenter/evaluate-windows-server-2022
2. Select "ISO" as the download type
3. Fill in the form (use any info, it does not verify)
4. Download the ISO (about 5 GB)
5. The evaluation version is free for 180 days, which is more than enough

### Windows 10 or 11 (for WS01)

1. Go to: https://www.microsoft.com/en-us/software-download/windows10ISO
2. Or for Windows 11: https://www.microsoft.com/en-us/software-download/windows11
3. Download the ISO (about 5 to 6 GB)
4. Windows 10 is lighter on resources. If your host machine has limited RAM, pick Windows 10.

### Kali Linux (attacker machine)

1. Go to: https://www.kali.org/get-kali/#kali-virtual-machines
2. Download the VMware or VirtualBox pre-built image (easier than installing from ISO)
3. Or download the ISO from https://www.kali.org/get-kali/#kali-installer-images if you prefer a manual install
4. The pre-built VM image is about 3 GB compressed

Save all downloads to a folder you can find easily. Something like `C:\Lab-ISOs\` works fine.

---

## Step 2: Create the DC01 Virtual Machine

### VMware Workstation

1. Open VMware Workstation
2. Click "Create a New Virtual Machine"
3. Select "Typical" and click Next
4. Select "I will install the operating system later" and click Next (do NOT select the ISO yet, or VMware will try Easy Install which causes problems)
5. Guest operating system: Microsoft Windows
6. Version: Windows Server 2022
7. Virtual machine name: DC01
8. Location: pick a folder with enough disk space
9. Disk size: 40 GB, select "Store virtual disk as a single file"
10. Click "Customize Hardware"

**Hardware settings:**

- Memory: 3072 MB (3 GB) recommended, 2048 MB (2 GB) minimum
- Processors: 2 cores
- Network Adapter: **NAT** (this is the default, do not change it)
- CD/DVD: Click "Use ISO image file" and browse to your Windows Server 2022 ISO

Click Close, then Finish. That is the entire VM setup.

### Install Windows Server 2022

1. Power on DC01
2. Press any key when prompted to boot from CD
3. Select language and keyboard, click Next
4. Click "Install now"
5. Select **Windows Server 2022 Standard Evaluation (Desktop Experience)**. Do NOT pick the Server Core option. You want the full GUI.
6. Accept the license terms
7. Select "Custom: Install Windows only"
8. Select the 40 GB drive, click Next
9. Wait for installation to complete (takes 5 to 15 minutes depending on your disk)
10. Set the Administrator password when prompted. Use something simple for the lab: `P@ssw0rd123!`

After installation, log in and you will see Server Manager open automatically.

### Install VMware Tools (important)

1. In the VMware menu bar, click VM > Install VMware Tools
2. Inside the VM, open File Explorer, go to the D: drive (CD drive)
3. Run setup64.exe
4. Click through the installer with default options
5. Restart when prompted

VMware Tools gives you proper display drivers, copy-paste between host and VM, drag-and-drop file transfer, and better network adapter performance. Do not skip this.

---

## Step 3: Run the Setup Script on DC01

This is where the automation takes over. No manual network configuration needed.

### Copy the Script

1. Download or copy `Configure-Lab.ps1` to the DC01 VM
2. You can drag and drop it from your host (VMware Tools enables this) or use a shared folder
3. Put it somewhere simple like `C:\Users\Administrator\Desktop\Configure-Lab.ps1`

### Run It

Open PowerShell as Administrator and run:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\Configure-Lab.ps1
```

The script will ask you what this machine is:

```
  ============================================================
   WHAT IS THIS MACHINE?
  ============================================================

    [D] Domain Controller  (DC01 - Windows Server)
    [W] Workstation        (WS01 - Windows 10/11)

  Press D or W: D
```

Type **D** and press Enter. The script saves your choice to `C:\LabSetup\role.txt` so it will not ask again after reboots. It remembers.

You can also skip the menu entirely by passing the role directly:

```powershell
.\Configure-Lab.ps1 -Role DC
```

### What Happens Automatically

**Run 1 (Stage 1/3):**

The script will:
- Ask you to pick D or W (only on first run, saved for future runs)
- Auto-detect your VMware NAT subnet (it reads the DHCP address)
- Show you the detected IPs (something like DC: 192.168.233.10, WS: 192.168.233.20)
- Disable Windows Defender (asks you to turn off Tamper Protection manually if it is on)
- Set a static IP for DC01 on the detected subnet (.10)
- Set the network profile to Private and allow ICMP (so pings work between VMs)
- Install the AD DS feature
- Rename the computer to DC01
- Register itself to auto-run after reboot (passes -Role DC so no menu after reboot)
- Reboot

You do not need to do anything after pressing D. Just watch the output and wait for the reboot.

**Run 2 (Stage 2/3):**

After reboot, the script runs automatically (or you can run it manually). It will:
- Promote the server to a Domain Controller for orsubank.local
- Install DNS
- Auto-reboot after promotion (this is forced by Windows)

**Run 3 (Stage 3/3):**

After the second reboot, the script runs again and does all the heavy lifting:
- Adds DNS forwarders so internet keeps working (points to NAT gateway + 8.8.8.8)
- Creates 3 OUs (BankEmployees, ServiceAccounts, Workstations)
- Creates 10 domain users with realistic roles
- Creates 4 service accounts with SPNs (Kerberoasting targets)
- Disables pre-auth on 3 accounts (AS-REP Roasting targets)
- Configures ACL abuse paths (GenericAll, WriteDACL, ForceChangePassword, GenericWrite)
- Creates nested group chains to Domain Admins
- Sets up delegation (unconstrained on WS01, constrained on svc_web, RBCD write)
- Installs ADCS with Enterprise Root CA
- Configures ESC1 (SAN on User template), ESC4 (writable WebServer template), ESC8 (HTTP relay)
- Enables WDigest, disables LSA Protection and Credential Guard
- Plants credential files in realistic locations
- Starts the Print Spooler for coercion attacks
- Runs verification checks on everything

At the end, it shows you the Kali setup commands (just a static IP and DNS, both optional since Kali on NAT works out of the box).

---

## Step 4: Create and Set Up WS01 (Workstation)

Repeat the VM creation process:

1. Create a new VM in VMware
2. Guest OS: Microsoft Windows, Version: Windows 10 x64 (or Windows 11 x64)
3. Memory: 3 GB, Processors: 2, Disk: 40 GB
4. Network Adapter: **NAT** (default)
5. Attach the Windows 10/11 ISO
6. Install Windows. When it asks "Who's going to use this PC?":
   - Name: `labuser`
   - Password: `P@ssw0rd123!`
   - Skip the security questions (put anything)
7. Skip all the Microsoft privacy/Cortana/tracking screens (turn everything off)
8. Install VMware Tools (VM > Install VMware Tools > run setup64.exe > restart)

This `labuser` account is a local admin by default (first account created on Windows 10/11 always is). The script will rename the machine to WS01 and join the domain. You will not use this account for attacks. It is just for running the setup script.

### Run the Script on WS01

Copy `Configure-Lab.ps1` to WS01 and run it the same way:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\Configure-Lab.ps1
```

The same menu appears. This time type **W** and press Enter.

```
  Press D or W: W
```

The choice is saved. After reboots, the script knows this is WS01 and will not ask again.

**Run 1 (Stage 1/3):** Detects the NAT subnet, disables Defender, sets static IP (.20), sets DNS to DC01's IP, renames to WS01, reboots.

**Run 2 (Stage 2/3):** Tests connectivity to DC01, tests DNS resolution of orsubank.local, asks you for domain admin credentials (ORSUBANK\Administrator), joins the domain, reboots.

**Run 3 (Stage 3/3):** Configures all workstation-side vulnerabilities:
- Unquoted service path, weak service binary, weak registry permissions
- AlwaysInstallElevated
- Stored AutoLogon credentials
- Vulnerable scheduled task (SYSTEM with writable script)
- PSRemoting, WMI, RDP, admin shares
- Remote UAC disabled (for Pass-the-Hash)
- Local admin account (operator / Operator123!)
- WDigest enabled, LSA Protection off
- Persistence mechanisms (Run keys, startup folder, WMI subscription)
- WebClient service for coercion

### After WS01 is Done

Go back to DC01 and run the script one more time to configure the WS01-dependent items:

```powershell
.\Configure-Lab.ps1 -Role DC -Reset
```

This will re-run DC Stage 3 and set up:
- DCSync rights for WS01's machine account
- Unconstrained Delegation on WS01
- RBCD write permission for vamsi.krishna on WS01

---

## Step 5: Set Up Kali Linux

### If Using the Pre-built VMware Image

1. Extract the downloaded archive
2. Open the .vmx file in VMware Workstation
3. The network adapter is already set to NAT by default
4. Boot it up. Default credentials are kali / kali

### If Installing from ISO

1. Create a new VM: Linux, Debian 11 x64
2. Memory: 2 GB, Disk: 30 GB, Network: NAT
3. Install Kali with the graphical installer

### Kali Network Config

Kali on NAT gets internet and a DHCP address automatically. You can start using it right away. For consistency, you can optionally set a static IP:

```bash
# Check what IP you got from DHCP
ip addr show

# The DC's IP will be on the same subnet, just ending in .10
# For example if Kali got 192.168.138.131, then DC is 192.168.138.10

# Set DNS to the DC (for domain name resolution)
echo "nameserver 192.168.138.10" | sudo tee /etc/resolv.conf

# Test it
nslookup orsubank.local
ping 192.168.138.10
```

Replace 192.168.138 with whatever subnet your VMware NAT uses. The setup script on DC01 prints this information at the end of Stage 3.

### Install Attack Tools

```bash
sudo apt update && sudo apt upgrade -y

# Most tools come pre-installed on Kali. Verify:
which impacket-secretsdump
which bloodhound
which responder
which certipy-ad
which crackmapexec

# If any are missing:
sudo apt install -y bloodhound impacket-scripts responder certipy-ad crackmapexec
pip3 install certipy-ad
```

---

## Verification: Is Everything Working?

Before moving to Module 01, verify the lab is functional.

### From Kali, test connectivity:

```bash
# Ping DC01
ping -c 2 <DC_IP>

# Ping WS01
ping -c 2 <WS_IP>

# Test DNS resolution
nslookup orsubank.local <DC_IP>

# Test LDAP (should return domain info)
ldapsearch -x -H ldap://<DC_IP> -b "DC=orsubank,DC=local" -s base "(objectClass=*)"

# Test SMB (should list shares)
crackmapexec smb <DC_IP> -u "vamsi.krishna" -p "OrsUBank2024!" --shares
```

### From WS01, test domain membership:

```powershell
# Verify domain
systeminfo | findstr /B /C:"Domain"

# Should show: orsubank.local

# Test domain user login
runas /user:ORSUBANK\vamsi.krishna cmd
# Password: OrsUBank2024!
```

If all of these work, your lab is ready. Move on to Module 01.

---

## Troubleshooting Common Issues

### "Cannot reach DC01" during WS01 domain join

This usually means the firewall is blocking traffic. The setup script sets the network profile to Private and allows ICMP automatically. If it still fails:

```powershell
# On DC01, open PowerShell as admin:
Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False

# Test from WS01:
ping <DC_IP>
```

### "DNS cannot resolve orsubank.local" on WS01

The WS01 DNS must point to DC01. Check with:

```powershell
Get-DnsClientServerAddress
```

If it shows 192.168.x.2 (the NAT gateway) instead of 192.168.x.10 (DC01), the static IP setup did not complete properly. Re-run the script or manually set DNS:

```powershell
Set-DnsClientServerAddress -InterfaceIndex (Get-NetAdapter | Where-Object Status -eq "Up" | Select-Object -First 1).ifIndex -ServerAddresses "<DC_IP>"
```

### Internet stops working after DC promotion

This happens because the DC becomes its own DNS server but does not have forwarders yet. Stage 3 adds forwarders automatically. If you need internet before Stage 3 runs:

```powershell
Add-DnsServerForwarder -IPAddress "8.8.8.8"
Add-DnsServerForwarder -IPAddress "<Gateway_IP>"
```

### Script does not auto-resume after reboot

The script uses RunOnce registry keys. If the auto-resume does not trigger, just run it manually:

```powershell
powershell -ExecutionPolicy Bypass -File C:\LabSetup\Configure-Lab.ps1
```

The script tracks its own progress in `C:\LabSetup\stage.txt` and will pick up where it left off.

### Tamper Protection blocks Defender disable

Windows 11 and newer Server versions have Tamper Protection on by default. The script will pause and tell you to turn it off manually. Go to: Windows Security > Virus and threat protection > Manage settings > Turn off Tamper Protection. Then press Enter in the script window.

---

*Module 01: Domain Enumeration is next. You will learn LDAP queries, BloodHound, PowerView, and how to find every attack path in the domain.*
