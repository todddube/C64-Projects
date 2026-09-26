# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Reference Documentation

### C64 Tools Location (macOS)

- **KickAssembler v5.25**: `/Applications/KickAssembler/`
  - `KickAss.jar` - Assembler executable
  - `KickAssembler.pdf` - Official documentation manual
  - `Examples/` - Official KickAssembler example projects
- **Java**: System default install (Java 26+, verified in PATH)
- **Regenerator 2000**: `/Applications/regenerator/regenerator2000`
  - Interactive 6502 TUI disassembler for Commodore 8-bit machines
  - Full 6502 support including undocumented opcodes
  - Supports: `.prg`, `.crt`, `.d64`, `.d71`, `.d81`, `.t64`, `.vsf`, `.bin`, `.raw`, `.regen2000proj`, `.dis65`
  - Exports to KickAssembler (use `--assembler kick`), 64tass, ACME, ca65
  - MCP server mode: `--mcp-server` (HTTP port 3000) or `--mcp-server-stdio`
  - VICE debugger integration: `--vice localhost:6502`
  - Docs: https://regenerator2000.readthedocs.io/
- **VICE Emulator (arm64/GTK3)**: `/Applications/vice-arm64-gtk3/`
  - CLI binary: `/Applications/vice-arm64-gtk3/bin/x64sc` — primary C64 emulator
  - App bundle: `/Applications/vice-arm64-gtk3/x64sc.app`
  - Other emulators: x128, x64dtv, xplus4, xpet, xvic
- Always follow KickAssembler v5.25 syntax and directives as specified in the manual
- Follow C64 6502 assembler standards and conventions

### Build Alias (add to ~/.zshrc for convenience)
```bash
alias kickass='java -jar /Applications/KickAssembler/KickAss.jar'
```

## C64 Reference Docs and Review Agent

`.claude/c64-reference/` holds the hardware and assembler references this repo reviews
against. Read these instead of recalling register addresses from memory:

| File | Covers |
|---|---|
| `memory-map.md` | full address map, `$01` bank switching, zero page ownership, the clean-exit sequence |
| `vic-ii.md` | `$D000-$D02E`, VIC bank select via `$DD00`, `$D018` screen/charset/bitmap mapping, display modes, PAL/NTSC raster and badline timing, sprites, DEN blanking |
| `sid-cia.md` | SID voice/filter registers and gate handling, CIA 1/2, the full keyboard matrix |
| `6502.md` | addressing modes with cycle counts, flags, signed and 8.8 fixed-point idioms, NMOS pitfalls |
| `kickassembler.md` | the complete v5.25 directive table, syntax, encodings, color constants, CLI options — extracted from `KickAssembler.pdf` |
| `review-checklist.md` | the review rubric (CPU, memory/banking, VIC-II, raster/IRQ, SID, repo conventions) |

`.claude/agents/c64-reviewer.md` defines a **`c64-reviewer`** subagent that reads those docs
and works the checklist over changed assembly. It reads and builds but never edits. Use it
after writing or changing C64 assembly, or when a demo misbehaves (garbage graphics, IRQ
lockup, silent SID, crash on exit).

## Build Commands

### Local Development (macOS)
```bash
# Build any assembly file with KickAssembler
java -jar /Applications/KickAssembler/KickAss.jar filename.asm

# Build with specific output directory and filename
java -jar /Applications/KickAssembler/KickAss.jar main.asm -odir bin -o projectname.prg

# Build output goes to bin/. KickAssembler names the .prg after the source
# file (main.asm -> bin/main.prg) unless -o is given.
# Generated files: .prg only (plus buildlog.txt when tee'd as below)

# Minimal-output build (the standard form used here):
java -jar /Applications/KickAssembler/KickAss.jar main.asm -odir bin 2>&1 | tee bin/buildlog.txt | grep -vE '^//|^parsing$|^flex pass|^Output pass$|^Output dir:|^$|^ +(Music:|init |\$)'
# A clean build prints exactly one line: "Writing prg file: main.prg".
# Anything else is an error/warning. Full output is kept in bin/buildlog.txt.
# The last alternative in the grep strips KickAssembler's PSID import
# banner ("Music: ...", the load range, "init/play"), which a project that
# #imports a .sid prints on a SUCCESSFUL build - without it, spritemove
# looks like it emitted three warnings every time.
#
# /Applications/KickAssembler/KickAss.cfg is deliberately EMPTY: no -showmem
# (memory map), no -symbolfile (.sym), no -debug (.dbg). Never add those by
# default; pass one on the command line only for a single build that needs it
# (e.g. -symbolfile for a Regenerator/VICE-monitor session, -showmem to check
# segment placement).

# Run in VICE emulator (macOS arm64)
/Applications/vice-arm64-gtk3/bin/x64sc program.prg

# Run with autostart (loads and runs immediately)
/Applications/vice-arm64-gtk3/bin/x64sc -autostart program.prg
```

### Custom Slash Commands (`.claude/commands/`)
- `/build [path]` — Builds the current project with KickAssembler, then offers to run it in VICE
- `/build-all` — Builds every project in the repo and prints a summary table
- `/run [file.prg]` — Runs a .prg in VICE x64sc with `-autostart`
- `/c64-new <name>` — Scaffolds a new project (`main.asm` + `memorymap.asm` + `bin/`)

A "project" is a directory with `main.asm`, **or** a directory whose single top-level
`.asm` is the main source (`scroller/scroller.asm`). The build commands handle both;
don't assume every project is `main.asm`. Directories with
several `.asm` files and no `main.asm` (`c64_lessons/lesson11/` step files, `demos/`,
`Galactic Rasterbar/`) are not auto-buildable — name the file explicitly.

### Run/test workflow used in practice
```bash
# Build (minimal output, see above), then launch VICE in the background and capture its log
java -jar /Applications/KickAssembler/KickAss.jar main.asm -odir bin 2>&1 | tee bin/buildlog.txt | grep -vE '^//|^parsing$|^flex pass|^Output pass$|^Output dir:|^$|^ +(Music:|init |\$)'
nohup /Applications/vice-arm64-gtk3/bin/x64sc -autostart bin/main.prg > bin/main.prg-vice.log 2>&1 &
```
The VICE log always contains "Unknown disk image" / "no CRT header" / tape errors for a
.prg — those are autodetect probes, not failures. The line to look for is
`AUTOSTART: Loading PRG file ... with direct RAM injection`.

To *see* what a demo renders without watching it in real time, let VICE run a fixed
number of cycles in warp mode and screenshot on exit:
```bash
/Applications/vice-arm64-gtk3/bin/x64sc -autostart bin/main.prg \
    -warp -limitcycles 14000000 -exitscreenshot /tmp/shot.png
```
Autostart alone costs roughly 5M cycles (the C64 boots first), and PAL runs ~985248
cycles/second, so `5000000 + seconds * 985248` lands on the frame you want. This is the
fastest way to check an intro, a raster split or a color choice.

### CI/CD
There are **no GitHub Actions** (no `.github/workflows/`). The only pipeline is
`c64_lessons/azure-pipelines.yml`, inherited from the upstream course repo: it has
`trigger: none` (never runs automatically), needs a self-hosted agent pool named `Pi4`
with KickAss.jar in `/usr/local/bin`, and only builds directories containing `main.asm`
— so it covers most `c64_lessons/*` but **not** `spritemove/`, `scroller/`, `demos/` or
`lesson11/`. Its CD stage `lftp mput`s the .prg files to `/Usb0/Dev` on the Ultimate II+.

In practice builds are local only; `bin/` output is committed for several projects and
deployment to the cartridge is manual.

## Disassembly Workflow

### Regenerator 2000 — Interactive TUI Disassembler

Binary: `/Applications/regenerator/regenerator2000`

```bash
# Open a PRG interactively in the TUI
/Applications/regenerator/regenerator2000 program.prg

# Export to KickAssembler .asm (headless, no TUI needed)
/Applications/regenerator/regenerator2000 project.regen2000proj \
  --headless --export_asm output.asm --assembler kick

# Import VICE labels then export annotated assembly
/Applications/regenerator/regenerator2000 program.prg \
  --import_lbl program.sym --export_asm program_disasm.asm --assembler kick

# Export labels only
/Applications/regenerator/regenerator2000 program.prg \
  --export_lbl labels.sym --assembler kick

# Connect to running VICE instance for live debugging
/Applications/vice-arm64-gtk3/bin/x64sc -binarymonitor program.prg &
/Applications/regenerator/regenerator2000 program.prg --vice localhost:6502

# Run as MCP server (HTTP) for programmatic/AI access
/Applications/regenerator/regenerator2000 --mcp-server

# Run as MCP server (stdio) for Claude Code integration
/Applications/regenerator/regenerator2000 --mcp-server-stdio
```

### Disassembly Key Concepts
- **Project files** (`.regen2000proj`): Save labels, comments, data-type annotations — use these for iterative reverse engineering sessions
- **Assembler format**: Always use `--assembler kick` to export KickAssembler-compatible syntax
- **VICE label import**: `.sym` files pre-annotate a disassembly, but the standard build does NOT produce one — pass `-symbolfile` for that single build (see Build Commands)
- **Headless mode**: `--headless` requires a `.regen2000proj` file; use for CI/export scripts
- **Data types**: In TUI, mark regions as Code, Byte, Word, PETSCII Text, Screencode Text, etc.
- **MCP integration**: The `--mcp-server-stdio` mode allows Claude Code to drive disassembly programmatically

### Reverse Engineering Workflow
1. Build project with `-symbolfile` to get `.prg` and `.sym` (the standard
   build emits `.prg` only)
2. Open `.prg` in Regenerator 2000 with `--import_lbl` pointing to `.sym`
3. Annotate in TUI: mark data regions, add labels/comments, run auto-analysis
4. Save as `.regen2000proj` for iterative work
5. Export with `--export_asm` and `--assembler kick` to get annotated source

## Architecture Overview

### Project Structure
1. **c64_lessons/**: Progressive tutorials. `lesson01`..`lesson10b` each have a `main.asm` (07/08/09/10b also `#import` their local `memorymap.asm` + `charset_1.asm`); no external dependencies. `lesson11` is the exception — no `main.asm`, just standalone `step_1_`..`step_4_` / `optimized-step4.asm` files showing incremental sprite development
2. **kickass_examples/**: The official KickAssembler example projects (scripting, PSID import, Koala import, libraries, ...)
3. **demos/**: Standalone demo sources (`demo1.asm`, `plasma_190.asm`) plus reference `.prg`/`.d64` files that are *not* built from source
4. **spritemove/** (`main.asm`): Four physics-driven multicolor ball sprites with ghost trails, starfield, ASCII impact sparks and SID ping SFX, opening with a multicolor-bitmap spiral intro set to `Nightshift.sid`. All demo logic is in `main.asm`, heavily commented — read its header before editing. It imports four data/sequence files, none of them buildable on their own: `intro.asm` (the opening sequence), `intro_gfx.asm` (the spiral bitmap, generated at assembly time), `music.asm` (PSID import) and `sprite_gen.asm` (the ray-shaded ball frames + trail disc).
   **Its code segment starts at `$2240`, not the usual `$0810`** — a PSID player is not relocatable and Nightshift loads at `$1000-$1d77`. The intro runs in VIC bank 1 (bitmap `$4000`, video matrix `$6000`) and switches back to bank 0 text mode for the demo
5. **scroller/** (`scroller.asm`): Raster bars + scroller + SID music. **Depends on the sibling repo `C64-Standards`** — imports are written `../../C64-Standards/include/...`, resolved relative to `scroller/`, i.e. `Github/C64-Standards/include/` (`c64_constants.asm`, `zeropage.asm`) — it must be checked out next to this repo or the build fails on `#import`
6. **Galactic Rasterbar/**: Reverse-engineering project. `*_disasm.asm` / `*_todd.asm` are Regenerator 2000 output in **64tass syntax** (`;` comments, `label = $xxxx`), not KickAssembler — re-export with `--assembler kick` before building with KickAss. Original binary is in `orig/`

### Standard Assembly Structure
```assembly
BasicUpstart2(main)  // Standard C64 BASIC launcher
main:
  // Program code here
```

### Memory Organization
- **Screen memory**: `$0400` (VIC.SCREEN)
- **Color RAM**: `$D800` (VIC.COLOR_RAM)
- **VIC-II registers**: `$D000-$D3FF` (VIC.MEMORY_SETUP, VIC.BORDER_COLOR, etc.)
- **Sprite registers**: `$D000-$D00F` (positions), `$D010` (X MSB), `$D015` (enable), `$D027-$D02E` (colors), `$D01E` (collision)
- **SID registers**: `$D400-$D7FF` (SID.VOICE3_LSB_FREQ, etc.)
- **Custom character sets**: `$3000` (common location to avoid SID conflicts)
- **Sprite data**: `$2000` (standard location, `$40` byte increments)
- **Zero page variables**: `$80-$86` (movement directions, counters)
- **Program code**: `$1000` (common load address)

### Library System
Located in `kickass_examples/08.Namespace and libraries/Libs/`:
- **MyStdLibs.lib**: Master library import
- **MyFunctions.lib**: Utility functions with namespace support
- **MyMacros.lib**: Reusable code macros
- **MyIrqRoutines.lib**: Interrupt handling utilities

Import pattern:
```assembly
#import "memorymap.asm"    // Memory constants
#import "charset_1.asm"    // Character set data
```

### File Organization Pattern
```
project_directory/
├── main.asm          # Main source file
├── memorymap.asm     # Memory constants (advanced projects)
├── charset_1.asm     # Custom character sets
├── *.sid             # SID music files (lessons 10+)
├── font-project.pe   # Font editor project files
├── bin/              # Build outputs
│   ├── main.prg     # Compiled program
│   ├── main.sym     # Symbol table — only when built with -symbolfile
│   ├── buildlog.txt # Build information
│   └── *.prg-vice.log # VICE emulator test logs
```

## Development Workflow

1. **Edit** `.asm` source files
2. **Build** with KickAssembler locally or via CI
3. **Test** with VICE emulator (evident from `.prg-vice.log` files)
4. **Deploy** to hardware via Ultimate II+ cartridge

### Testing Strategy
- **VICE Emulator**: Primary testing platform with detailed logging
- **Log Files**: `.prg-vice.log` files capture ROM loading, startup, and execution details
- **Build Verification**: Memory maps and symbol tables generated for debugging
- **Hardware Testing**: Ultimate II+ cartridge for final validation
- **Progressive Development**: Step-by-step files (lesson11) show incremental testing approach

## Demo Conventions

### Exit key: RUN/STOP ends the demo
Every demo in this repo that takes over the machine (`sei`, own keyboard scan,
BASIC's zero page reused) must provide a `check_exit` routine called once per
frame from the main loop. RUN/STOP is keyboard row 7 (`$7f` -> `$dc00`), column
bit 7, active low:

```assembly
check_exit:
    lda #$7f
    sta $dc00
    lda $dc01
    and #$80
    beq exit_demo           // bit clear = pressed
    lda #$ff
    sta $dc00
    rts
```

`exit_demo` silences the SID (`$d400..$d418`), clears `$d015`, restores `$d011`
to `$1b`, deselects the keyboard rows, then `jmp ($fffc)` — the kernal RESET
vector. Do **not** `rts` back to BASIC: these demos overwrite `$02-$8f`, so
BASIC will crash. Do **not** `cli` first either: `$fffc` does its own `sei`, and
an IRQ taken in that window runs the kernal handler on the trashed zero page.
Because `sei` does not mask NMI, `start` should also write `$7f` to `$dd0d` and
read it back, or RUN/STOP+RESTORE will warm-start BASIC over the same memory.
`/c64-new` scaffolds this routine into `main.asm`.

Reference implementation: `spritemove/main.asm` (`check_exit` / `exit_demo`).

### Blanking the screen (intro reveals)
Clearing DEN (bit 4 of `$d011`, i.e. `$0b` instead of `$1b`) switches the whole
display off — text, color RAM *and* sprites — leaving a flat sheet of border
color. Set border and background to the same value first so nothing flickers
when DEN comes back on. `spritemove/main.asm` (`play_intro`) uses this for a
blue-screen opening with a SID swoop, then sets DEN and reveals the animation.

## Common Patterns

### Sprite Programming
- **Data Organization**: Sprites at `$2000` with `$40` byte increments (`$2000`, `$2040`, `$2080`)
- **Pointer Calculation**: `address / $40` (e.g., `lda #$80` for sprite at `$2000`)
- **Movement Variables**: Zero page storage pattern `fish_N_dir_x` at `$80-$86`
- **Boundary Detection**: Standard limits X:`$30-$d0`, Y:`$50-$e0`
- **Direction Reversal**: `eor #$ff` followed by `adc #$01` for bouncing
- **Animation**: Frame switching using `and #$10` masks for timing

### Frame Synchronization
- **Raster Polling**: `lda #255`, `cmp $d012`, `bne *-3` for frame timing
- **Variable Speed**: Frame counters with bit masking for different movement rates
- **Multi-sprite Animation**: Sequential sprite pointer switching for frame animation

### Graphics Programming
- Custom character set usage for enhanced graphics (located at `$3000`)
- Sprite collision detection using `$d01e` register
- Color cycling and visual effects using `VIC.COLOR_RAM`
- Dual-height font rendering (top/bottom character pairs offset by 127)
- Fine scrolling with `VIC.XSCROLL` (`$d016`) and coarse scrolling coordination

### Code Organization
- Modular design with `#import` system
- Namespace usage for libraries (VIC:{}, SID:{})
- Consistent memory mapping with constants in `memorymap.asm`
- Standard program structure with setup/main loop/subroutines

## Hardware Integration

- **Primary target**: Ultimate II+ cartridge
- **Emulation**: VICE emulator for testing
- **Deployment**: Manual FTP upload to `/Usb0/Dev/` on the cartridge (the Azure pipeline that automated this is disabled with `trigger: none`)
- **Testing**: Log files indicate extensive VICE emulator usage

## KickAssembler Features

Reference: `/Applications/KickAssembler/KickAssembler.pdf`

This codebase makes extensive use of KickAssembler's advanced features:
- Namespace and library system for code organization
- Macro system for code reuse
- Import system for modular development
- Scripting capabilities for advanced operations
- Graphics conversion utilities

### KickAssembler Syntax Standards
- Use `.label` for constants: `.label SPRITE_PTR = $07F8`
- Use `.byte` for data bytes (supports binary: `%00111100`, hex: `$3C`, decimal: `60`)
- Use `.word` for 16-bit values
- Use `.fill count, value` to fill memory regions
- Use `* = $address "Label"` for memory segments
- Use `#import "filename.asm"` for includes
- Use `//` for comments (C-style)
- Use `BasicUpstart2(label)` macro for BASIC startup

## C64 6502 Assembler Standards

### Instruction Set Conventions
- Use lowercase for mnemonics: `lda`, `sta`, `jsr`, `rts`
- Use `#` prefix for immediate values: `lda #$00`
- Use `$` prefix for hexadecimal: `$D000`, `$FF`
- Use `%` prefix for binary: `%00001111`

### Zero Page Usage
- `$00-$01`: 6510 CPU I/O port (do not use)
- `$02-$7F`: Available for variables (prefer for speed)
- `$80-$FF`: BASIC/Kernal usage (safe when BASIC disabled)

### Common Register Patterns
```assembly
// Two's complement negation (for direction reversal)
eor #$FF
clc
adc #$01

// Raster sync wait
lda #$FF
cmp $D012
bne *-3

// Indirect indexed addressing for tables
ldy #$00
lda (ptr),y
```

### Memory-Mapped I/O
- VIC-II: `$D000-$D3FF`
- SID: `$D400-$D7FF`
- Color RAM: `$D800-$DBFF`
- CIA1: `$DC00-$DCFF`
- CIA2: `$DD00-$DDFF`

## Common Build Errors

### Missing import (scroller)
```
Error: File not found: ../../C64-Standards/include/c64_constants.asm
```
The `C64-Standards` repo is not cloned beside this one. Clone it to
`/Users/todddube/Documents/Github/C64-Standards` or inline the needed constants.

### Branch Too Far
When loops exceed 127 bytes, relative branches fail with:
```
Error: relative address is illegal (jump distance is too far: -131)
```
**Fix**: Replace `bne label` with `beq done` + `jmp label`:
```assembly
// Before (fails if loop > 127 bytes)
    inx
    cpx #$08
    bne loop

// After (works for any distance)
    inx
    cpx #$08
    beq done
    jmp loop
done:
```

## Project Conventions

### Naming Patterns
- **Sprite Variables**: `sprite_N_property` or `fish_N_dir_x` format
- **Direction Variables**: `_dir_x` and `_dir_y` suffixes for movement vectors
- **Animation Frames**: `sprite_name_frame_N` for animation sequences
- **Step Files**: Numbered progression (step_1_, step_2_) for tutorial development

### File Types and Usage
- **Font Projects**: `.pe` files for character set design using font editors
- **Progressive Lessons**: Step-by-step implementation files in lesson directories
- **Build Outputs**: `.prg` (program) and `buildlog.txt` by default; `.sym` (symbols) and `.dbg` (debug) only when `-symbolfile` / `-debug` is passed for that build
- **Test Logs**: `.prg-vice.log` files from VICE emulator sessions

### Development Patterns
- **Incremental Development**: Build complexity progressively (lessons 7-11 demonstrate this)
- **Hardware-First Design**: Code optimized for Ultimate II+ cartridge deployment
- **Emulator Testing**: VICE integration for rapid iteration before hardware testing