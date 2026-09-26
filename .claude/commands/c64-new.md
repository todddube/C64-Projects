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

    jsr check_exit              // RUN/STOP ends the demo

    jmp loop

// check_exit - repo convention: RUN/STOP quits every demo.
// RUN/STOP is keyboard row 7 ($7f on CIA1 port A), column bit 7, active
// low. A demo that ran with interrupts off and used BASIC's zero page has
// nothing sane to return to, so exit through the kernal RESET vector.
check_exit:
    lda #$7f
    sta $dc00
    lda $dc01
    and #$80
    beq exit_demo
    lda #$ff
    sta $dc00
    rts

exit_demo:
    lda #$00
    ldx #$18                    // silence the SID
!:  sta $d400, x
    dex
    bpl !-
    sta $d015                   // sprites off
    lda #$1b                    // display on
    sta $d011
    lda #$ff
    sta $dc00
    cli
    jmp ($fffc)                 // kernal RESET -> clean READY.
```

If the demo scans the keyboard itself it must also set the CIA1 data
directions during setup: `lda #$ff : sta $dc02` (port A output) and
`lda #$00 : sta $dc03` (port B input).

memorymap.asm template:
```
// Memory map constants for <project-name>

.label SCREEN     = $0400
.label COLOR_RAM  = $D800
.label BORDER     = $D020
.label BACKGROUND = $D021
```

After creating files, run `/build` to verify it compiles clean.
