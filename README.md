# MOS 1.1

The monitor operating system for MSAP-2, written in MSAP-2 assembly. At reset an immutable loader in U36 validates `MOS.BIN` from microSD and copies its complete 8 KiB runtime image into shadow SRAM. A hardware latch then replaces the lower EEPROM window with read-only SRAM and starts MOS at `0x0000`.

U36 also retains a complete MOS fallback. A missing card, missing or malformed `MOS.BIN`, stalled disk response, or failed Fletcher checksum leaves the shadow disabled and enters that immutable UART monitor instead. Removing the card and pressing RESET therefore always provides recovery without reprogramming an EEPROM.

## Commands

| Command | Action |
|---|---|
| `A [AAAA]` | assemble mode - one instruction per line at the shown address; `; comments`, a bare hex address moves the cursor, empty line ends, bare `A` resumes |
| `D AAAA` | dump 32 bytes |
| `E AAAA BB ..` | enter bytes |
| `R AAAA` / `R NAME` / `R` | run at a 14-bit address, or load a file from disk and run it (bare `R` runs the user area at `0x2000`); `RTS` returns and prints A/X |
| `L NAME [AAAA]` | load from disk (default `2000`) |
| `S NAME AAAA NN` | save NN bytes |
| `X NAME` | delete a file |
| `F` | list files |
| `C` | clear the screen |
| `H` | help |

`BRK` (opcode `37`) anywhere in a program stops it and prints `BRK @AAAA A=.. X=..` - a software breakpoint.

## Contracts

- **Syscall jump table** (stable, link against these): PUTC `0x010`, GETC `0x013`, PUTS `0x016` (pointer at `0x3F00/01`), GETLN `0x019` (line at `0x3F20`), EXIT `0x01C`.
- **Serial console**: a TL16C550D occupies ports `8` through `15`. On cold start MOS sets DLAB, writes divisor `0x000C` for the 1.8432 MHz reference, selects 8 data bits/no parity/1 stop bit, clears the FIFOs, and then uses port `8` for data and port `13` for line status. Status bit 0 means receive data ready and bit 5 means transmit holding register empty.
- **Interrupts**: the ROM IRQ vector at `0x008` is `jmp (0x3F1A)` - hook interrupts by writing your handler address to RAM at `0x3F1A/1B`. The monitor resets it to a default `RTI` at every prompt.
- **Memory after boot**: write-protected MOS shadow SRAM at `0x0000-0x1FFF`, contiguous user-program space `0x2000-0x3EEF` (7,920 bytes), run trampoline `0x3EF0-0x3EFF`, monitor workspace `0x3F00-0x3F9F`, and stack `0x3FA0-0x3FFF` growing down from `0x3FFF`.
- **Disk loads**: `L` and named `R` reject any destination and length that would write outside `0x2000-0x3EEF`, reporting `OUT OF RANGE`. Explicit `R AAAA` remains an expert escape hatch for any real 14-bit address.
- **Disk saves**: `S` may read any 14-bit source range, including MOS or workspace, but rejects an address, length, or wrap that crosses `0x3FFF`. `S`, EDIT `.S`, and EDIT `.A` wait for the coprocessor's completion byte after all data has been written and the file has been synced and closed. They print `OK` only for `01`; `00` reports `SAVE FAILED`.
- **Recovery vector**: factory address `0x003` is a fixed jump into fallback MOS. The U36 reset vector is the only patched part of the runtime image; it enters the loader at `0x1C00`.
- **Overlay control**: output port `6` sets the shadow latch. Only hardware reset clears it. The loader executes `OUT #6; JMP 0` from upper RAM at `0x3EF0`, so the instruction stream remains valid while the lower mapping changes.
- The monitor never writes to its lower 8 KiB. `R` runs programs through an upper-RAM trampoline, and interrupt hooks go through the RAM vector.

## Deploying MOS

Copy the generated `MOS.BIN` to the root of a FAT16/FAT32 microSD card. It is an exact 8,208-byte container:

| Offset | Bytes | Meaning |
| ---: | ---: | --- |
| `0x0000` | 4 | `M2OS` |
| `0x0004` | 1 | format version `1` |
| `0x0005` | 1 | header length `16` |
| `0x0006` | 2 | load address `0x0000`, little-endian |
| `0x0008` | 2 | payload length `0x2000`, little-endian |
| `0x000A` | 2 | entry address `0x0000`, little-endian |
| `0x000C` | 2 | Fletcher-16 `sum1`, `sum2` over the payload |
| `0x000E` | 2 | zero flags and reserved bytes |
| `0x0010` | 8192 | clean, zero-padded MOS runtime image |

The loader allows approximately five to six seconds for the initial SD service and up to about two seconds for each subsequent response byte. Ready responses proceed immediately. Any timeout or validation error goes to fallback MOS without asserting the overlay latch. The first implementation intentionally keeps bulk UART OS upload out of the immutable loader; UART recovery is the complete factory MOS monitor.

## Disk protocol

Commands are NUL-terminated ASCII written to port `2`; MOS polls port `5` before every response byte.

| Command | Request after NUL | Response |
| --- | --- | --- |
| `L NAME` | none | 16-bit little-endian length and data; `FF FF` means missing or too large for the protocol |
| `S NAME` | 16-bit little-endian length and data | `01` only after successful sync and close; `00` on open, write, sync, or close failure |
| `F` | none | sorted `NAME SIZEB\n` rows followed by zero |
| `D NAME` | none | `01` if deleted; `00` if absent or failed |

`FF FF` is reserved, so a load whose physical file is 65,535 bytes or larger is reported as missing.

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

Requires the `msap-asm` assembler (`../8-bit_CPU_Programmer/assembler`), Node.js, and the installed MSAP-2 simulator dependencies (`npm install` in `../MSAP-2/simulator`). Produces:

- `mos.bin` and `mos.lst` - variable-length fallback MOS assembly output.
- `boot.bin` and `boot.lst` - immutable loader assembled at `0x1C00`.
- `dist/mos-runtime-8k.bin` - clean 8 KiB shadow-SRAM payload.
- `dist/MOS.BIN` - deployable 16-byte header plus the runtime payload.
- `dist/factory-rom-8k.bin` - U36's mapped 8 KiB, containing fallback MOS, bootloader, and a reset-vector patch.
- `simulator/src/rom/mos-rom.json`, `factory-rom.json`, and `mos-bin.json` - byte-identical simulator images.
- `ed.bin`, `ed.lst`, and the simulator's EDIT payload.

The packer fails if fallback MOS reaches the reserved `0x1C00` boundary, boot code exceeds `0x1FFF`, either reset vector is wrong, the fixed fallback vector is absent, or the container is not exactly 8,208 bytes. The production export pads `factory-rom.json` to U36's complete 32 KiB with `0xFF`.
