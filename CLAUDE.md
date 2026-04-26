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

## Build Commands

### Local Development (macOS)
```bash
# Build any assembly file with KickAssembler
java -jar /Applications/KickAssembler/KickAss.jar filename.asm

# Build with specific output directory and filename
java -jar /Applications/KickAssembler/KickAss.jar main.asm -odir bin -o projectname.prg

# Build output will be in same directory or bin/ subdirectory
# Generated files: .prg (program), .sym (symbols), .dbg (debug info)

# Run in VICE emulator (macOS arm64)
/Applications/vice-arm64-gtk3/bin/x64sc program.prg

# Run with autostart (loads and runs immediately)
/Applications/vice-arm64-gtk3/bin/x64sc -autostart program.prg
```

### Custom Slash Commands (Claude Code agents)
- `/build` — Builds the current project's main.asm with KickAssembler
- `/build-all` — Builds all main.asm files in the repo
- `/c64-new` — Scaffolds a new C64 project with standard structure
- `/disassemble` — Disassembles a .prg (or other supported file) using Regenerator 2000

### CI/CD Integration
- **GitHub Actions**: Builds all `main.asm` files in subdirectories on push/PR to main branch
  - Uses Java 21 (Zulu distribution) and downloads KickAssembler from official source
  - Outputs to `${{runner.workspace}}/build/` with directory-named PRG files
  - Artifacts retained for 1 day
- **Azure DevOps**: Builds and deploys to Ultimate II+ cartridge via FTP
  - Requires private build agent with Java, KickAssembler, and lftp installed
  - Deploys to `/Usb0/Dev/` directory on Ultimate II+ via FTP
  - Uses variable group `c64` for FTP credentials
- Build logs are stored in `buildlog.txt` in each project's `bin/` directory

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
- **VICE label import**: Use `.sym` files from KickAssembler builds to pre-annotate disassembly
- **Headless mode**: `--headless` requires a `.regen2000proj` file; use for CI/export scripts
- **Data types**: In TUI, mark regions as Code, Byte, Word, PETSCII Text, Screencode Text, etc.
- **MCP integration**: The `--mcp-server-stdio` mode allows Claude Code to drive disassembly programmatically

### Reverse Engineering Workflow
1. Build project to get `.prg` and `.sym` files
2. Open `.prg` in Regenerator 2000 with `--import_lbl` pointing to `.sym`
3. Annotate in TUI: mark data regions, add labels/comments, run auto-analysis
4. Save as `.regen2000proj` for iterative work
5. Export with `--export_asm` and `--assembler kick` to get annotated source

## Architecture Overview

### Project Structure
The codebase is organized into five main areas:

1. **c64_lessons/**: Progressive tutorial projects from basic to advanced topics
2. **kickass_examples/**: Advanced KickAssembler feature demonstrations
3. **demos/**: Complete demo programs with visual effects
4. **spritemove/**, **scroller/**: Individual project directories
5. **bin/**: Global build output directory

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
│   ├── main.sym     # Symbol table
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
- **Deployment**: Automated FTP upload to `/Usb0/Dev/` on cartridge
- **Testing**: Log files indicate extensive VICE emulator usage

## KickAssembler Features

Reference: `C:\C64\KickAssembler\KickAssembler.pdf`

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
- **Build Outputs**: `.prg` (program), `.sym` (symbols), `.dbg` (debug), `buildlog.txt`
- **Test Logs**: `.prg-vice.log` files from VICE emulator sessions

### Development Patterns
- **Incremental Development**: Build complexity progressively (lessons 7-11 demonstrate this)
- **Hardware-First Design**: Code optimized for Ultimate II+ cartridge deployment
- **Emulator Testing**: VICE integration for rapid iteration before hardware testing