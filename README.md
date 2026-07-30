# MOS 1.1

The monitor operating system for MSAP-2, written in MSAP-2 assembly. It boots from a 4KB EEPROM at `0x0000-0x0FFF`, drives the serial console, and gives the machine its personality: a command monitor, a resident line assembler, breakpoint debugging, and a disk filesystem.

## Commands

| Command | Action |
|---|---|
| `A [AAAA]` | assemble mode - one instruction per line at the shown address; `; comments`, a bare hex address moves the cursor, empty line ends, bare `A` resumes |
| `D AAAA` | dump 32 bytes |
| `E AAAA BB ..` | enter bytes |
| `R AAAA` / `R NAME` / `R` | run at an address, or load a file from disk and run it (bare `R` runs the user area at `0x1000`); `RTS` returns and prints A/X |
| `L NAME [AAAA]` | load from disk (default `1000`) |
| `S NAME AAAA NN` | save NN bytes |
| `X NAME` | delete a file |
| `F` | list files |
| `C` | clear the screen |
| `H` | help |

`BRK` (opcode `37`) anywhere in a program stops it and prints `BRK @AAAA A=.. X=..` - a software breakpoint.

## Contracts

- **Syscall jump table** (stable, link against these): PUTC `0x010`, GETC `0x013`, PUTS `0x016` (pointer at `0x1F00/01`), GETLN `0x019` (line at `0x1F20`), EXIT `0x01C`.
- **Serial console**: a TL16C550D occupies ports `8` through `15`. On cold start MOS sets DLAB, writes divisor `0x000C` for the 1.8432 MHz reference, selects 8 data bits/no parity/1 stop bit, clears the FIFOs, and then uses port `8` for data and port `13` for line status. Status bit 0 means receive data ready and bit 5 means transmit holding register empty.
- **Interrupts**: the ROM IRQ vector at `0x008` is `jmp (0x1F1A)` - hook interrupts by writing your handler address to RAM at `0x1F1A/1B`. The monitor resets it to a default `RTI` at every prompt.
- **Memory**: ROM `0x0000-0x0FFF`, user RAM `0x1000-0x1EFF`, system page `0x1F00-0x1FFF` (monitor variables, buffers, run trampoline at `0x1F90`, stack from `0x1FFF` down).
- The monitor never writes to ROM addresses: `R` runs programs through a RAM trampoline, and interrupt hooks go through the RAM vector - so the same image works from a real write-protected EEPROM.

## EDIT - the disk-loaded editor + assembler

`R EDIT` loads the full-screen-less but full-featured editor (`ed.asm`, ~2.5KB) into user RAM. It edits **named source files** and assembles with **labels**:

```
] 10 ldx #0
] 20 top: txa
] 30 add #30
] 40 jsr 10
] 50 inx
] 60 cpx #5
] 70 jnz top
] 80 rts
] .a count        assembles (two passes) and saves binary COUNT to disk
] .s count.s      saves the source itself
] .q
> r count
01234 A=35 X=05
```

Lines are BASIC-style: `NN text` adds/replaces line NN (hex), bare `NN` deletes, `.L` lists, `.O NAME` reopens a saved source, `;` comments, `#<label`/`#>label` for pointer setup. Assembly errors print `ERR @NNNN` with the offending line. The assembler streams pass 2 straight to the disk, so there is no output buffer to collide with - and it reads the opcode table from ROM via the published pointer at `0x01F`, so ED and the monitor can never disagree about the ISA.

Gotcha: `R` treats a pure-hex token as an address, so avoid program names spelled only with 0-9/A-F (that is why the editor is EDIT, not ED).

## Build

```
./build.sh
```

Requires the `msap-asm` assembler (`../8-bit_CPU_Programmer/assembler`) and node. Produces:
- `mos.bin` - the flat 4 KB ROM image (burn to the modular AT28C64B or pad with `0xFF` for production U36 / load into the simulator)
- `mos.lst` - assembly listing
- updates `../MSAP-2/simulator/src/rom/mos-rom.json` (the image the simulator boots) and the assembler repo's byte-parity test fixture

The simulator never assembles this source - it loads the built binary, exactly as the hardware will.
