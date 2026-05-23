# Module 01: The Defense Landscape

Before you can bypass any defense, you must deeply understand how it works. This module teaches every layer of security that stands between an attacker and code execution on a modern Windows 11 enterprise endpoint.

Most beginner courses skip this and jump straight to "how to bypass." That is a mistake. When a technique fails during an engagement and you do not understand WHY it failed, you are stuck. When you understand the defense stack, you can diagnose failures, adapt, and choose the right technique for the situation.

**What you will learn:**
- How Windows decides whether to trust or block a downloaded file
- The internal mechanics of Mark-of-the-Web (MOTW)
- How SmartScreen and Smart App Control make reputation decisions
- What browsers do when you download a file
- How email gateways inspect attachments and links
- How AMSI inspects script content at runtime
- What Attack Surface Reduction (ASR) rules block
- How all these layers work together as a defense stack

**Lab exercises included:** You will trigger and observe each defense layer in your lab.

---

## Table of Contents

- [Part 1: Mark-of-the-Web (MOTW) -- How Windows Tags Files](#part-1-mark-of-the-web-motw----how-windows-tags-files)
- [Part 2: SmartScreen -- Reputation-Based Blocking](#part-2-smartscreen----reputation-based-blocking)
- [Part 3: Smart App Control -- The New Gatekeeper](#part-3-smart-app-control----the-new-gatekeeper)
- [Part 4: Browser Download Security](#part-4-browser-download-security)
- [Part 5: Email Gateways and Network Security](#part-5-email-gateways-and-network-security)
- [Part 6: AMSI -- Script Content Inspection](#part-6-amsi----script-content-inspection)
- [Part 7: Windows Defender and Attack Surface Reduction Rules](#part-7-windows-defender-and-attack-surface-reduction-rules)
- [Part 8: The Full Defense Stack](#part-8-the-full-defense-stack)

---

## Part 1: Mark-of-the-Web (MOTW) -- How Windows Tags Files

MOTW is the foundation of the entire Windows file trust model. Every other defense in this module depends on it. If you understand nothing else from this course, understand MOTW.

### 1.1 What Is MOTW?

When you download a file from the internet (through a browser, email client, or chat app), Windows silently attaches a hidden tag to that file. This tag says: "This file came from the internet. Do not trust it blindly."

That tag is called the **Mark-of-the-Web**, and it is the reason Windows shows you warnings, blocks macros, and runs SmartScreen checks on downloaded files.

Here is the key insight: **if a file does not have this tag, Windows treats it as a local, trusted file.** No warnings. No SmartScreen. No macro blocking. Nothing.

This is why attackers have spent years finding ways to strip or avoid MOTW. And it is why you need to understand exactly how it works.

### 1.2 How MOTW Works Technically: The Zone.Identifier ADS

MOTW is implemented using a feature of the NTFS file system called **Alternate Data Streams (ADS)**.

**What is an Alternate Data Stream?**

On NTFS (the file system used by Windows), every file has a "main" data stream -- this is the file content you see when you open it. But NTFS also allows files to have additional, hidden data streams attached to them. These are called Alternate Data Streams.

Think of it like a sticky note attached to a file. The sticky note is invisible in File Explorer, but Windows can read it.

When you download a file, Windows (or your browser) creates an ADS named `Zone.Identifier` and attaches it to the downloaded file. This ADS contains a small text block that looks like this:

```ini
[ZoneTransfer]
ZoneId=3
ReferrerUrl=https://phishing-site.com/page
HostUrl=https://phishing-site.com/malware.exe
```

The most important field is `ZoneId`. It tells Windows where this file came from:

| ZoneId | Zone Name | Meaning |
|:-------|:----------|:--------|
| **0** | My Computer | File was created locally. Fully trusted. |
| **1** | Local Intranet | File came from an internal network share. Mostly trusted. |
| **2** | Trusted Sites | File came from a site the user explicitly trusted. |
| **3** | Internet | **File came from the internet. This is the one that triggers all the security checks.** |
| **4** | Restricted Sites | File came from a blocked/untrusted site. Most restricted. |

**The critical takeaway:** When `ZoneId=3` (Internet), Windows treats the file with suspicion. When `ZoneId` is absent or 0, Windows treats it as trusted.

### 1.3 Who Creates the Zone.Identifier?

Two mechanisms create this tag:

**Mechanism 1: The IAttachmentExecute API**

This is the official Windows API for handling downloaded files. When a browser or email client downloads a file, it calls the Windows Attachment Execution Service via the `IAttachmentExecute` interface. This service:
1. Determines the security zone of the source URL
2. Creates the `Zone.Identifier` ADS on the downloaded file
3. Triggers an antivirus scan via `IOfficeAntivirus`

**Mechanism 2: Direct Write by the Browser**

Modern Chromium-based browsers (Chrome, Edge) often write the `Zone.Identifier` ADS directly themselves, bypassing the legacy `IAttachmentExecute` API for reliability reasons. The browser uses `IInternetSecurityManager` to determine the correct zone and then writes the ADS directly.

**Both methods produce the same result:** the downloaded file gets tagged with `ZoneId=3`.

### 1.4 What MOTW Triggers

When a file has `ZoneId=3`, Windows activates several security checks:

| Defense Layer | What Happens |
|:-------------|:-------------|
| **SmartScreen** | Checks the file's hash and publisher signature against Microsoft's cloud reputation database. Can block execution entirely. |
| **Office Protected View** | Word, Excel, and PowerPoint open the file in a read-only sandbox. The yellow banner says "PROTECTED VIEW: Be careful -- files from the Internet can contain viruses." |
| **VBA Macro Blocking** | Since 2022, macros in internet-sourced Office documents are hard-blocked. No "Enable Content" button. |
| **Script Blocking** | PowerShell scripts (.ps1), JavaScript (.js), VBScript (.vbs) files are restricted or blocked when run from internet-sourced locations. |
| **Windows Defender** | Performs additional scanning on MOTW-tagged files before allowing execution. |

**If the file does NOT have MOTW:**
- SmartScreen does not check it
- Office opens it normally (no Protected View, macros can run)
- Scripts run without restriction
- Defender still scans it, but with less scrutiny

This is why stripping MOTW has been such a valuable technique for attackers.

### 1.5 When MOTW Fails to Propagate

MOTW relies on NTFS Alternate Data Streams. ADS only exists on NTFS. This means MOTW breaks when:

1. **File is copied to a non-NTFS filesystem:** If you copy a file to a FAT32 or exFAT USB drive, the Zone.Identifier ADS is silently dropped. Copy it back to NTFS, and the file is now "clean" -- no MOTW.

2. **File is inside a container format:** When you download an ISO, VHD, or ZIP file, the container itself gets MOTW. But when you open the container and extract files from it, the files inside may or may not inherit the MOTW tag. This depends on the extraction software and the container format. This is the entire basis of the container-based bypass techniques we will cover in Module 02.

3. **Third-party archive software does not propagate MOTW:** If a user extracts a ZIP using 7-Zip (which has MOTW propagation disabled by default), the extracted files lose their MOTW tag.

4. **File attributes prevent writing the ADS:** If a file is read-only, the system may fail to write the Zone.Identifier stream.

### 1.6 Lab Exercise: Inspecting MOTW

Let us see MOTW in action in your lab.

**Step 1: Download a file from Kali**

On your Kali VM, make sure the Python HTTP server is running:

```bash
cd ~/labs
echo "This is a test file downloaded from the internet." > testfile.txt
python3 -m http.server 8080
```

On your Windows VM, open Edge and navigate to:

```
http://192.168.85.129:8080/testfile.txt
```

> **Note:** `192.168.85.129` (Kali) is the Host-Only IP address of your Kali VM.

The file will download to `C:\Users\user\Downloads\testfile.txt`.

**Step 2: Inspect the Zone.Identifier ADS**

Open Administrator PowerShell on the Windows VM and run:

```powershell
Get-Content -Path "$env:USERPROFILE\Downloads\testfile.txt" -Stream Zone.Identifier
```

You should see output like:

```
[ZoneTransfer]
ZoneId=3
HostUrl=http://192.168.85.129:8080/testfile.txt
```

`ZoneId=3` confirms Windows tagged this file as coming from the Internet zone.

**Step 3: List all ADS on a file**

```powershell
Get-Item -Path "$env:USERPROFILE\Downloads\testfile.txt" -Stream *
```

This shows all data streams on the file. You will see:
- `:$DATA` -- the main file content (the text you downloaded)
- `Zone.Identifier` -- the MOTW tag

**Step 4: Remove MOTW manually**

You can strip MOTW from a file using the `Unblock-File` cmdlet:

```powershell
Unblock-File -Path "$env:USERPROFILE\Downloads\testfile.txt"
```

Now check again:

```powershell
Get-Content -Path "$env:USERPROFILE\Downloads\testfile.txt" -Stream Zone.Identifier
```

You should get an error: `Could not open the alternate data stream 'Zone.Identifier'`. The MOTW tag is gone. Windows now treats this file as a trusted local file.

**Step 5: See MOTW disappear on FAT32**

If you have a USB drive formatted as FAT32, copy the downloaded file to it and then copy it back. The Zone.Identifier will be gone. (This is optional -- the PowerShell exercise above demonstrates the concept.)

**What you just learned:**
- MOTW is a hidden text tag (ADS) attached to downloaded files
- It contains the ZoneId that tells Windows where the file came from
- It can be inspected, removed, and manipulated
- It only exists on NTFS -- it disappears on other file systems

---

## Part 2: SmartScreen -- Reputation-Based Blocking

### 2.1 What Is SmartScreen?

SmartScreen is Microsoft's cloud-based reputation system. When you try to run an executable that came from the internet (i.e., it has MOTW with ZoneId=3), Windows sends information about that file to Microsoft's servers. Microsoft checks the file against its database and returns a verdict: safe, unknown, or malicious.

SmartScreen is NOT an antivirus. It does not scan the file for malware signatures. It checks the file's **reputation**:
- Has this file been seen before?
- How many people have downloaded and run it?
- Is it signed by a known, trusted publisher?
- Is the publisher's certificate widely used or brand new?

### 2.2 What SmartScreen Checks

When SmartScreen evaluates a file, it looks at:

| Factor | What It Means |
|:-------|:-------------|
| **File hash** | Has Microsoft seen this exact file before? If millions of users have run it without problems, it is probably safe. |
| **Digital signature** | Is the file signed with a code-signing certificate? Is the certificate from a trusted Certificate Authority? |
| **Publisher reputation** | How old is this publisher's certificate? How many other files has this publisher signed? Has Microsoft seen issues with this publisher? |
| **Download URL** | Has this URL been reported for distributing malware? Is it associated with phishing campaigns? |
| **File age** | How recently was this file first seen? Brand-new files with no history are treated with more suspicion. |

### 2.3 The Three SmartScreen Verdicts

When SmartScreen finishes its check, one of three things happens:

**Verdict 1: Known Safe**
- SmartScreen has seen this file before, it is widely used, and it is signed by a reputable publisher
- Result: The file runs immediately with no warning
- Example: Running the official 7-Zip installer downloaded from 7-zip.org

**Verdict 2: Unknown / Low Reputation**
- SmartScreen has not seen this file before, or it is not signed, or the signature is new
- Result: A blue warning screen appears: "Windows protected your PC -- Microsoft Defender SmartScreen prevented an unrecognized app from starting"
- The user CAN still run it by clicking "More info" then "Run anyway"
- This is what happens with most custom-compiled programs

**Verdict 3: Known Malicious**
- SmartScreen recognizes this file as malware or from a known malicious source
- Result: A red warning screen appears, and the user CANNOT easily bypass it
- The file may also be quarantined by Defender

### 2.4 SmartScreen's Dependency on MOTW

Here is the critical detail: **SmartScreen only checks files that have MOTW (ZoneId=3).**

If a file does not have MOTW, SmartScreen does not check it at all. The file runs directly.

This is why MOTW bypass techniques are so powerful. Bypassing MOTW does not just remove one security check -- it removes the trigger for SmartScreen, Protected View, and macro blocking simultaneously.

### 2.5 Lab Exercise: Triggering SmartScreen

Let us trigger SmartScreen and see what happens.

**Step 1: Create a simple C program on Kali**

On Kali, open a terminal and create a simple C program:

```bash
cat > ~/labs/payloads/hello.c << 'EOF'
#include <stdio.h>
int main() {
    printf("Hello from a custom unsigned executable!\n");
    printf("This is NOT malware. SmartScreen just does not recognize me.\n");
    return 0;
}
EOF
```

Compile it as a Windows executable using mingw:

```bash
sudo apt install -y gcc-mingw-w64-x86-64
x86_64-w64-mingw32-gcc ~/labs/payloads/hello.c -o ~/labs/payloads/hello.exe
```

Serve it:

```bash
cd ~/labs/payloads
python3 -m http.server 8080
```

**Step 2: Download and run it on Windows**

1. On the Windows VM, open Edge
2. Go to `http://192.168.85.129:8080/hello.exe` (Kali)
3. The file downloads
4. Open File Explorer and navigate to Downloads
5. Double-click `hello.exe`

**What you should see:** A blue SmartScreen warning: "Windows protected your PC"

This happens because:
- The file has MOTW (downloaded from the internet via Edge)
- The file is unsigned (no code-signing certificate)
- SmartScreen has never seen this file before (unknown reputation)

**Step 3: Check what Sysmon logged**

Even though SmartScreen blocked the initial execution attempt, Sysmon logs the event. Open Administrator PowerShell:

```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 30 |
    Where-Object { $_.Id -eq 1 -and $_.Message -match "hello" } |
    Format-List TimeCreated, Message
```

If you clicked "Run anyway" to bypass the SmartScreen warning, you will see the process creation event with the full command line and parent process chain.

**What you just learned:**
- SmartScreen blocks unknown/unsigned executables downloaded from the internet
- The block is a WARNING that users can bypass (for unknown files)
- SmartScreen depends on MOTW to trigger
- Sysmon captures the execution regardless of SmartScreen's verdict

---

## Part 3: Smart App Control -- The New Gatekeeper

### 3.1 What Is Smart App Control?

Smart App Control (SAC) is a newer security feature introduced in Windows 11. It is fundamentally different from SmartScreen:

| Feature | SmartScreen | Smart App Control |
|:--------|:-----------|:------------------|
| **When it triggers** | Only for files with MOTW (downloaded from internet) | **ALL executables**, regardless of where they came from |
| **Can the user bypass it?** | Yes -- "Run anyway" button | **No.** If SAC blocks something, there is no override |
| **What it checks** | File hash reputation, URL reputation | Code signing validation + AI prediction model |
| **Where it runs** | Standard user-space | **Kernel-level** via Hyper-V Secure Kernel (VBS). Tamper-resistant |
| **Availability** | Windows 10 and 11 | **Windows 11 only** |

### 3.2 How SAC Decides What to Allow

SAC uses two checks:

**Check 1: Code Signing Validation**
- Is the executable signed with a valid code-signing certificate?
- Is the certificate from a trusted Certificate Authority?
- If yes, the app is allowed to run

**Check 2: AI Prediction via Microsoft Intelligent Security Graph**
- If the app is not signed (or the signature is unknown), SAC sends information about it to Microsoft's cloud AI service
- The AI model predicts whether the app is likely to be safe or malicious based on patterns it has learned from billions of files
- If the AI predicts it is safe, the app runs. If not, it is blocked

**The key difference from SmartScreen:** SAC has **no user override**. If SAC blocks an application, there is no "Run anyway" option. The app simply cannot run.

### 3.3 SAC Modes

SAC operates in one of three modes:

| Mode | Behavior |
|:-----|:---------|
| **Evaluation** | SAC runs silently in the background, observing your software usage. It decides whether your machine is a good candidate for enforcement. This is the default on fresh Windows 11 installs. |
| **On (Enforcement)** | SAC actively blocks untrusted and unsigned applications. No user override. |
| **Off** | SAC is disabled entirely. |

**Important change in 2026:** Previously, once you turned SAC off, you could NOT turn it back on without reinstalling Windows. As of the April 2026 update, SAC can be toggled on and off freely.

### 3.4 Why SAC Matters for Red Teams

SAC represents a fundamental shift in Windows security:
- SmartScreen only applies to downloaded files (files with MOTW). Bypass MOTW, bypass SmartScreen.
- SAC applies to ALL executables regardless of origin. Bypassing MOTW does NOT bypass SAC.
- SAC cannot be bypassed by user interaction (no "click through" option)

This means on endpoints where SAC is enabled and enforced, traditional payload delivery is significantly harder. Unsigned custom tools will simply not run.

### 3.5 Lab Exercise: Check SAC Status on Your VM

On your Windows VM, let us check whether SAC is active:

1. Click the **Start** button
2. Type **Windows Security** and press Enter
3. In the Windows Security app, click **App & browser control**
4. Look for **Smart App Control**
5. Click on **Smart App Control settings**

You will see one of three states: Evaluation, On, or Off.

On a fresh Windows 11 evaluation install, SAC is typically in **Evaluation** mode or **Off**. For our lab exercises, we want SAC **Off** so that our custom executables can run. If it is on, turn it off for the duration of this course.

> **Note:** In a real enterprise engagement, SAC may be enforced via policy. Understanding that SAC exists and how it differs from SmartScreen is crucial for knowing when your techniques will fail.

---

## Part 4: Browser Download Security

### 4.1 How Browsers Decide What Is Dangerous

When you download a file through Chrome or Edge, the browser does not just hand you the file. It evaluates the download and may warn you, block you, or allow it silently.

Browsers classify downloads into categories:

| Category | Examples | What Happens |
|:---------|:---------|:-------------|
| **Not Dangerous** | `.txt`, `.pdf`, `.jpg`, `.png`, `.mp3` | Downloads silently, no warning |
| **Potentially Dangerous (Allow on User Gesture)** | Some file types allowed only if the user explicitly clicked a download link | Minor warning or allowed with click |
| **Dangerous** | `.exe`, `.dll`, `.bat`, `.cmd`, `.msi`, `.scr`, `.ps1`, `.vbs`, `.js`, `.wsf` | Warning dialog shown, file may be blocked |

### 4.2 Chrome and Edge: The Two-Tier Warning System

In mid-2024, Chrome (and by extension, Edge) redesigned their download warnings into two tiers:

**Tier 1: Suspicious (Gray Warning)**
- Shows a gray triangle icon next to the download
- The file is potentially risky, but the browser is not certain
- The user can proceed with one extra click

**Tier 2: Dangerous (Red Warning)**
- Shows a red stop sign icon
- The browser has high confidence the file is dangerous (known malware, or file type that is almost always malicious)
- The user must explicitly choose to keep the file

### 4.3 Enhanced Protection Mode (Edge/Chrome)

Both browsers offer an "Enhanced Protection" mode in their security settings:

| Feature | Standard Protection | Enhanced Protection |
|:--------|:-------------------|:-------------------|
| **Download scanning** | Basic metadata check | **Automatic deep scan**: file is uploaded to cloud for analysis |
| **Encrypted archives** | Not scanned | **Browser prompts for ZIP password**, uploads for deep scan, deletes after |
| **Phishing protection** | Known phishing site database | Predictive AI-based phishing detection |
| **URL checking** | Checked against local database (updated periodically) | Checked in **real-time** against cloud database |

### 4.4 Insecure Download Blocking

Starting in 2020, browsers began progressively blocking "mixed content" downloads:

- If you are on an HTTPS page and it tries to download a file via HTTP (not HTTPS), the browser blocks it
- This prevents attackers from using a legitimate HTTPS site to deliver payloads via insecure HTTP channels
- The blocking was rolled out gradually by file type: executables first, then archives, then disk images, then all file types

### 4.5 How Browsers Apply MOTW

When Edge downloads a file, it creates the `Zone.Identifier` ADS with `ZoneId=3`. This is how the browser tells Windows that the file came from the internet.

But here is an important detail: **the browser records the source URL in the MOTW tag.**

```ini
[ZoneTransfer]
ZoneId=3
ReferrerUrl=https://evil-site.com/download-page
HostUrl=https://evil-site.com/payload.exe
```

The `HostUrl` and `ReferrerUrl` fields are used by:
- SmartScreen (to check URL reputation)
- Forensic investigators (to determine where a file came from)
- Some EDR products (to correlate downloads with phishing campaigns)

### 4.6 Lab Exercise: Browser Download Behavior

**Step 1: Download different file types and observe browser behavior**

On Kali, create several files of different types:

```bash
cd ~/labs/payloads
echo "harmless text" > safe.txt
echo "<html><body>Hello</body></html>" > page.html
echo "@echo off" > script.bat
echo "MZ" > fake.exe
```

Start the HTTP server:

```bash
python3 -m http.server 8080
```

On the Windows VM in Edge, try downloading each one:
- `http://192.168.85.129:8080/safe.txt` (Kali) -- should download silently
- `http://192.168.85.129:8080/page.html` (Kali) -- should download silently
- `http://192.168.85.129:8080/script.bat` (Kali) -- Edge may warn you
- `http://192.168.85.129:8080/fake.exe` (Kali) -- Edge will likely warn (dangerous file type)

Notice how the browser treats different file types with different levels of suspicion.

**Step 2: Check MOTW on each downloaded file**

In PowerShell:

```powershell
$files = Get-ChildItem "$env:USERPROFILE\Downloads" -File | Sort-Object LastWriteTime -Descending | Select-Object -First 4
foreach ($file in $files) {
    Write-Host "`n--- $($file.Name) ---" -ForegroundColor Cyan
    try {
        Get-Content -Path $file.FullName -Stream Zone.Identifier -ErrorAction Stop
    } catch {
        Write-Host "No Zone.Identifier (no MOTW)" -ForegroundColor Yellow
    }
}
```

All four files should have `ZoneId=3` because they were all downloaded from the same HTTP server.

---

## Part 5: Email Gateways and Network Security

### 5.1 What Is a Secure Email Gateway (SEG)?

In enterprise environments, emails do not go directly to the user's inbox. They pass through a Secure Email Gateway (SEG) that inspects every message before delivery.

```
[External Sender] --> [Email Gateway] --> [User Inbox]
                          |
                    Scans for:
                    - Known malware signatures
                    - Suspicious attachments
                    - Malicious URLs
                    - Phishing indicators
                    - Sender reputation
```

Common SEG products: Microsoft Defender for Office 365, Proofpoint, Mimecast, Barracuda, Cisco IronPort.

### 5.2 What Email Gateways Block

Most enterprise email gateways block the following attachment types outright:

| Blocked by Default | Why |
|:-------------------|:----|
| `.exe`, `.dll`, `.scr`, `.com` | Executable files -- almost never legitimate in email |
| `.bat`, `.cmd`, `.ps1`, `.vbs`, `.js`, `.wsf` | Script files -- same reason |
| `.iso`, `.img`, `.vhd`, `.vhdx` | Disk images -- commonly used for MOTW bypass (see Module 02) |
| `.msi`, `.msp` | Installer packages -- potential for silent installation |
| `.hta` | HTML Application -- executes as a trusted application |

This is why you cannot simply email a `.exe` to a target and expect it to arrive. The email gateway will strip the attachment or reject the entire email.

### 5.3 How Gateways Inspect URLs

Email gateways do not just scan attachments. They also inspect every URL in the email body:

1. **Static URL scanning:** The gateway extracts all URLs from the email and checks them against known malicious URL databases
2. **URL rewriting:** Many gateways (especially Microsoft Defender for Office 365) rewrite URLs to point through a proxy. When the user clicks the link, the click goes through the gateway's proxy first, which checks the destination in real-time
3. **Sandbox detonation:** Some gateways follow the URL, download whatever is at the destination, and execute it in a sandbox to see if it is malicious

### 5.4 What Gateways Cannot See

Email gateways have blind spots. These blind spots are exactly what modern attackers exploit:

| Blind Spot | Why It Exists | How Attackers Exploit It |
|:-----------|:-------------|:------------------------|
| **HTML smuggling** | The email contains a clean HTML file. The malicious payload is assembled by JavaScript AFTER delivery, on the user's endpoint. The gateway only sees HTML and JavaScript -- no binary. | Module 03 covers this in depth |
| **Links to trusted cloud services** | Email gateways allowlist major cloud domains (sharepoint.com, googleapis.com, dropbox.com). They cannot block these without breaking legitimate business email. | Attackers host payloads on SharePoint, OneDrive, Google Drive |
| **Password-protected archives** | If a ZIP file is password-protected, the gateway cannot open it to scan the contents. | Attackers include the password in the email body: "Password: Invoice2026" |
| **QR codes** | URLs embedded in QR code images are invisible to text-based URL scanners. Only gateways with OCR and QR decoding can analyze them. | Module 05 covers QR phishing |
| **Delayed payload delivery** | The URL in the email is clean at delivery time. Hours later, the attacker swaps the content at that URL to something malicious. | The gateway already checked and approved the URL |

### 5.5 Why This Matters

Understanding email gateway limitations explains why modern initial access has shifted away from "attach malware to an email." Instead, attackers:
- Use **HTML smuggling** to deliver payloads through clean HTML
- Host payloads on **trusted cloud platforms** to bypass URL scanning
- Use **QR codes** to bypass text-based URL extraction
- Exploit **collaboration tools** (Teams, Slack) that bypass email security entirely

We will cover each of these in Modules 03 and 05.

---

## Part 6: AMSI -- Script Content Inspection

### 6.1 What Is AMSI?

AMSI (Antimalware Scan Interface) is a Windows API that allows antivirus/EDR products to inspect script content at runtime, BEFORE the script is executed.

Without AMSI, here is what happens when you run a PowerShell script:
1. User runs `powershell.exe -f script.ps1`
2. PowerShell reads the script file
3. PowerShell executes the script
4. Antivirus only sees that `powershell.exe` ran -- it has no visibility into what the script DID

With AMSI:
1. User runs `powershell.exe -f script.ps1`
2. PowerShell reads the script file
3. **PowerShell sends the script content to AMSI**
4. **AMSI passes the content to the installed antivirus/EDR**
5. **Antivirus scans the script content for known malicious patterns**
6. If clean, PowerShell executes the script. If malicious, execution is blocked.

### 6.2 Which Applications Use AMSI?

AMSI is not just for PowerShell. These Windows components send content to AMSI for scanning:

| Application | What Gets Scanned |
|:------------|:-----------------|
| **PowerShell** (5.0+) | Script blocks, module contents, interactive commands |
| **Windows Script Host** (wscript/cscript) | VBScript and JScript content |
| **JavaScript / VBScript** in Office macros | Macro code before execution |
| **VBA macros** in Office | Macro content |
| **.NET** (4.8+) | In-memory assembly loading (`Assembly.Load()`) |
| **mshta.exe** | HTA file content |

### 6.3 What AMSI Catches

AMSI is particularly effective against:

- **Obfuscated PowerShell:** Even if a script uses Base64 encoding, string concatenation, or variable substitution to hide its intent, AMSI sees the **decoded, final command** right before execution
- **Fileless attacks:** Because AMSI inspects content in memory at runtime, it can catch malicious commands even when no malicious file exists on disk
- **Known attack tools:** Commands from Mimikatz, PowerSploit, Empire, and other common post-exploitation tools are detected by AMSI signatures

### 6.4 AMSI Limitations

AMSI is powerful, but it has limitations:

1. **It only sees what is sent to it:** Applications must explicitly integrate with AMSI. If a custom application runs a script engine that does not call AMSI, the script content is not inspected.

2. **It can be bypassed:** Because AMSI runs in user-mode (inside the process), attackers with code execution can potentially disable it by patching the `amsi.dll` in memory. This is a well-known technique, but it is also well-detected by modern EDRs.

3. **It is signature-based:** AMSI relies on the antivirus engine's signatures. Truly novel or sufficiently obfuscated scripts may slip through.

### 6.5 PowerShell Constrained Language Mode

In addition to AMSI, Windows has another script-level defense: **Constrained Language Mode (CLM)**.

When Constrained Language Mode is active, PowerShell restricts which .NET types and methods can be used. This prevents attackers from:
- Calling arbitrary .NET APIs
- Using reflection to load malicious assemblies
- Invoking Win32 API functions via P/Invoke
- Accessing COM objects

CLM is typically enforced via Windows Defender Application Control (WDAC) policies or AppLocker. In enterprise environments with proper WDAC policies, PowerShell automatically switches to Constrained Language Mode for untrusted scripts.

### 6.6 Lab Exercise: Seeing AMSI in Action

**Step 1: Trigger an AMSI detection**

Open PowerShell on the Windows VM (regular PowerShell, not Administrator) and type:

```powershell
"Invoke-Mimikatz"
```

Just typing this string may not trigger AMSI. But try this -- a string that AMSI commonly detects:

```powershell
[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
```

If Windows Defender's AMSI integration is working, you should see an error like:

```
At line:1 char:1
+ [Ref].Assembly.GetType('System.Management.Automation.Amsi ...
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
This script contains malicious content and has been blocked by your antivirus software.
```

This is AMSI catching a known malicious pattern in real-time, before the command executes.

**Step 2: Check PowerShell language mode**

```powershell
$ExecutionContext.SessionState.LanguageMode
```

On a standard Windows 11 install without WDAC/AppLocker, this will return `FullLanguage`. In an enterprise with proper policies, it would return `ConstrainedLanguage`.

**What you just learned:**
- AMSI inspects script content at runtime
- It catches known malicious patterns even in interactive sessions
- It works for PowerShell, VBScript, JScript, and .NET assemblies
- Constrained Language Mode is a separate, additional restriction on PowerShell

---

## Part 7: Windows Defender and Attack Surface Reduction Rules

### 7.1 Windows Defender in 2026

Windows Defender (officially "Microsoft Defender Antivirus") is no longer the basic, easy-to-bypass antivirus it once was. In Windows 11, it includes:

- **Signature-based scanning:** Detects known malware by file hash and byte patterns
- **Behavioral monitoring:** Watches process behavior in real time (suspicious process injection, credential access, etc.)
- **Cloud-delivered protection:** Sends suspicious samples to Microsoft for AI analysis in near real-time
- **Tamper Protection:** Prevents malware from disabling Defender (requires admin + elevated privilege to turn off)
- **AMSI integration:** Inspects script content as described in Part 6
- **Network protection:** Blocks connections to known malicious domains
- **Controlled folder access:** Prevents unauthorized modifications to protected folders (anti-ransomware)

### 7.2 Attack Surface Reduction (ASR) Rules

ASR rules are a set of configurable policies that block specific behaviors commonly associated with attacks. They are the most underappreciated defense layer.

Here are the ASR rules most relevant to initial access:

| ASR Rule | What It Blocks | Impact on Attackers |
|:---------|:--------------|:-------------------|
| **Block executable content from email client and webmail** | Prevents executables dropped by Outlook or web-based email from running | Blocks email-delivered payloads |
| **Block all Office applications from creating child processes** | Office apps cannot spawn cmd.exe, powershell.exe, mshta.exe, etc. | Kills macro-based execution chains |
| **Block Office applications from creating executable content** | Office apps cannot write .exe, .dll, .scr files to disk | Prevents macro droppers |
| **Block JavaScript or VBScript from launching downloaded executable content** | Scripts cannot run executables they downloaded | Breaks script-based downloaders |
| **Block execution of potentially obfuscated scripts** | AMSI-flagged obfuscated scripts are blocked | Catches encoded/obfuscated PowerShell |
| **Block process creations originating from PSExec and WMI commands** | WMI and PsExec cannot create new processes | Limits lateral movement |
| **Block untrusted and unsigned processes that run from USB** | Unsigned executables from USB drives are blocked | Prevents USB-based attacks |

### 7.3 Are ASR Rules Always On?

No. ASR rules are NOT enabled by default in all Windows installations. They require:
- Microsoft Defender Antivirus as the primary AV (not a third-party AV)
- Configuration via Group Policy, Intune, or PowerShell

In enterprise environments managed by IT, ASR rules are commonly enabled. On a standalone Windows 11 evaluation install (like our lab), they may not be active.

### 7.4 Lab Exercise: Check ASR Rule Status

Let us see which ASR rules are active on our lab VM.

In Administrator PowerShell:

```powershell
Get-MpPreference | Select-Object -ExpandProperty AttackSurfaceReductionRules_Ids
```

If this returns nothing, no ASR rules are configured. Let us enable a few relevant ones for educational purposes:

```powershell
# Block Office from creating child processes
Add-MpPreference -AttackSurfaceReductionRules_Ids D4F940AB-401B-4EFC-AADC-AD5F3C50688A -AttackSurfaceReductionRules_Actions Enabled

# Block JavaScript/VBScript from launching downloaded content
Add-MpPreference -AttackSurfaceReductionRules_Ids D3E037E1-3EB8-44C8-A917-57927947596D -AttackSurfaceReductionRules_Actions Enabled

# Block execution of potentially obfuscated scripts
Add-MpPreference -AttackSurfaceReductionRules_Ids 5BEB7EFE-FD9A-4556-801D-275E5FFC04CC -AttackSurfaceReductionRules_Actions Enabled
```

Verify they are set:

```powershell
Get-MpPreference | Select-Object AttackSurfaceReductionRules_Ids, AttackSurfaceReductionRules_Actions
```

> **Note:** In later modules, if an ASR rule blocks an exercise you are trying to perform, that IS the lesson. You are seeing exactly what enterprise defenders deploy.

---

## Part 8: The Full Defense Stack

### 8.1 Putting It All Together

Now that you understand each defense layer individually, let us see how they work together. When a user downloads and runs a file from the internet, here is the complete chain of security checks:

```
Step 1: EMAIL GATEWAY
  Email arrives at the organization's email gateway
  Gateway scans: attachment types, URL reputation, sender reputation
  If blocked: email is quarantined, never reaches the user
  If clean: email is delivered to inbox

Step 2: BROWSER DOWNLOAD
  User clicks a link in the email
  Browser downloads the file
  Browser applies MOTW (Zone.Identifier with ZoneId=3)
  Browser shows warning for dangerous file types (.exe, .bat, etc.)

Step 3: SMARTSCREEN
  User tries to run the downloaded file
  SmartScreen checks: file hash reputation, publisher signature, URL reputation
  If blocked: blue/red warning screen shown
  If clean: file proceeds to next check

Step 4: SMART APP CONTROL (Windows 11)
  If SAC is enabled, it checks: code signing + AI prediction
  If blocked: file cannot run (no user override)
  If clean: file proceeds to next check

Step 5: WINDOWS DEFENDER
  Defender scans the file: signatures, behavioral analysis, cloud AI
  If detected: file is quarantined
  If clean: file proceeds to execution

Step 6: ASR RULES
  If the execution pattern matches an ASR rule
  (e.g., Office spawning PowerShell, script launching an EXE)
  Execution is blocked

Step 7: AMSI (for scripts)
  If the file is a script (PowerShell, VBS, JS, HTA)
  Script content is sent to AMSI for real-time scanning
  If detected: script is blocked mid-execution

Step 8: EXECUTION
  If the file passed ALL checks, it runs
  Sysmon and Defender continue monitoring its behavior
```

### 8.2 The Attacker's Perspective

Looking at this stack from the attacker's perspective:

- **Step 1 (Email Gateway):** This is why attackers use HTML smuggling, cloud-hosted delivery, and collaboration tools instead of direct email attachments
- **Step 2 (Browser/MOTW):** This is why attackers have spent years finding MOTW bypass techniques (ISO, VHD, LNK exploits, 7-Zip behavior)
- **Step 3 (SmartScreen):** This is why bypassing MOTW is so valuable -- it disables SmartScreen too
- **Step 4 (SAC):** This is the hardest layer to bypass. It does not depend on MOTW and has no user override
- **Step 5 (Defender):** This is why custom-compiled, unsigned tools trigger alerts
- **Step 6 (ASR Rules):** This is why attackers avoid obvious chains like "Office -> PowerShell"
- **Step 7 (AMSI):** This is why raw PowerShell commands from known tools get caught instantly

### 8.3 Lab Exercise: Walking a File Through the Stack

Let us manually walk a file through every defense layer and see what happens at each stage.

**Step 1: Create a test batch script on Kali**

```bash
cat > ~/labs/payloads/test-chain.bat << 'EOF'
@echo off
echo [*] If you see this, the file passed all security checks.
echo [*] SmartScreen: passed or bypassed
echo [*] Defender: not blocked
echo [*] ASR Rules: not triggered
echo [*] AMSI: not applicable (batch file)
whoami
pause
EOF
```

Serve it:

```bash
cd ~/labs/payloads
python3 -m http.server 8080
```

**Step 2: Download on Windows**

Open Edge and go to `http://192.168.85.129:8080/test-chain.bat` (Kali)

**Step 3: Observe each layer**

1. **MOTW:** Check the Zone.Identifier:
   ```powershell
   Get-Content -Path "$env:USERPROFILE\Downloads\test-chain.bat" -Stream Zone.Identifier
   ```
   You should see `ZoneId=3`.

2. **SmartScreen:** Double-click the file. You may see a SmartScreen warning (because .bat files are considered potentially dangerous). If you see a warning, click "More info" then "Run anyway" for this exercise.

3. **Defender:** Defender should not block this file because it contains no malicious content.

4. **ASR Rules:** If you enabled the "Block JavaScript/VBScript from launching downloaded content" ASR rule earlier, it may or may not apply to .bat files (ASR rules are specific about which script types they target).

5. **Execution:** If the file passes everything, a command prompt window opens showing the output of `whoami`.

**Step 4: Check Sysmon telemetry**

After running the script, check Sysmon:

```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 30 |
    Where-Object { $_.Id -eq 1 -and $_.Message -match "test-chain" } |
    Format-List TimeCreated, Message
```

You should see:
- A process creation event for `cmd.exe` (which runs .bat files)
- The full command line
- The parent process (explorer.exe, because you double-clicked it)

This is exactly what a SOC analyst would see. Even though the file passed all defenses, the execution was logged.

### 8.4 The Key Insight

**No single defense layer is unbreakable.** Every layer has been bypassed at some point. The power comes from **layering** -- an attacker must bypass ALL layers simultaneously.

This is also the attacker's opportunity: each layer has a specific trigger condition. If you understand those triggers, you can find paths that avoid triggering specific layers:

- Avoid MOTW trigger: container formats, archive extraction, copy-paste
- Avoid SmartScreen: remove MOTW (SmartScreen depends on it)
- Avoid email gateway: use cloud hosting, HTML smuggling, or non-email channels
- Avoid AMSI: use compiled binaries instead of scripts, or use LOLBINs
- Avoid ASR rules: use execution chains that do not match ASR patterns

The rest of this course will show you exactly how each of these paths works, what still works in 2026, what is dead, and what defenders see when each technique is used.

---

## Summary

| Defense Layer | What It Does | What Triggers It | Key Weakness |
|:-------------|:-------------|:----------------|:-------------|
| **MOTW** | Tags downloaded files with origin zone | Browser/email client downloads | Only exists on NTFS; breaks in container formats and some archivers |
| **SmartScreen** | Reputation-based blocking of unknown files | MOTW (ZoneId=3) on executable files | Depends entirely on MOTW -- no MOTW means no SmartScreen |
| **Smart App Control** | Blocks unsigned/untrusted apps with no override | ALL executable launches (MOTW not required) | Not enabled by default; requires modern hardware |
| **Browser Security** | Warns on dangerous file types, blocks mixed content | File type classification during download | Cannot prevent client-side file assembly (HTML smuggling) |
| **Email Gateway** | Blocks malicious attachments and URLs | Email delivery | Cannot see inside HTML smuggling, password-protected ZIPs, QR codes, or cloud-hosted content |
| **AMSI** | Real-time script content inspection | PowerShell, VBScript, JScript, .NET, HTA execution | Only covers script-based execution; does not apply to compiled binaries |
| **Defender / AV** | Signature + behavioral + cloud-based detection | File access, execution, behavior | Custom/unknown tools may not match signatures |
| **ASR Rules** | Blocks specific dangerous behavior patterns | Predefined behavior matches (e.g., Office spawning shell) | Must be explicitly enabled; does not cover all execution chains |

**Next module:** [02_history_of_dead_techniques.md](02_history_of_dead_techniques.md) -- Learning from the graveyard of techniques that attackers used from 2022-2026, why they died, and what replaced them.
