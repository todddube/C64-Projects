# Scaffold a new C64 KickAssembler project

$ARGUMENTS = project name (required). Ask if not provided.

Create a new project directory at the repo root with this structure:

```
<project-name>/
├── main.asm        # Main source file with BasicUpstart2 launcher
├── memorymap.asm   # Memory constants
└── bin/            # Build output (empty, gitkeep)
```

main.asm template:
```
// <project-name> - Commodore 64 demo
// KickAssembler v5.25

#import "memorymap.asm"

BasicUpstart2(main)

* = $1000 "Main"
main:
    // --- setup ---

    // --- main loop ---
loop:
    lda #$ff
    cmp $d012
    bne *-3

    jmp loop
```

memorymap.asm template:
```
// Memory map constants for <project-name>

.label SCREEN     = $0400
.label COLOR_RAM  = $D800
.label BORDER     = $D020
.label BACKGROUND = $D021
```

After creating files, run `/build` to verify it compiles clean.
