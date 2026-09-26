# C64 Memory Map

Sources: *Commodore 64 Programmer's Reference Guide* (Commodore, 1982); MOS 6510/6567/6581
datasheets. Cross-checked against the working code in this repo.

## Full map (default bank configuration, `$01 = $37`)

| Range | Size | Contents |
|-------|------|----------|
| `$0000-$0001` | 2 B | 6510 CPU I/O port: `$00` = data direction, `$01` = bank/datasette control. **Never clobber.** |
| `$0002-$00FF` | 254 B | Zero page — 1 cycle faster and 1 byte shorter per access than absolute |
| `$0100-$01FF` | 256 B | CPU hardware stack, grows **down** from `$01FF` |
| `$0200-$02FF` | 256 B | BASIC/KERNAL input buffer and workspace |
| `$0300-$03FF` | 256 B | KERNAL/BASIC indirect vectors (IRQ `$0314/15`, BRK `$0316/17`, NMI `$0318/19`) |
| `$0400-$07E7` | 1000 B | Default screen RAM (40x25 characters) |
| `$07F8-$07FF` | 8 B | Sprite pointers for the default screen (block = address / 64) |
| `$0800-$9FFF` | ~38 KB | BASIC program RAM — free for machine code. BASIC programs start at `$0801` |
| `$A000-$BFFF` | 8 KB | BASIC ROM, or RAM when banked out |
| `$C000-$CFFF` | 4 KB | Always RAM, never banked. Good scratch/code area |
| `$D000-$D3FF` | 1 KB | VIC-II registers (47 registers, mirrored every `$40`) |
| `$D400-$D7FF` | 1 KB | SID registers (29 registers, mirrored every `$20`) |
| `$D800-$DBFF` | 1 KB | Color RAM — **4-bit nibbles**, upper nibble reads as garbage. Never banked out |
| `$DC00-$DCFF` | 256 B | CIA 1 — keyboard matrix, joystick, IRQ timers |
| `$DD00-$DDFF` | 256 B | CIA 2 — serial bus, user port, **VIC bank select**, NMI timers |
| `$DE00-$DFFF` | 512 B | I/O expansion (cartridge) |
| `$E000-$FFFF` | 8 KB | KERNAL ROM, or RAM when banked out. Vectors: NMI `$FFFA`, RESET `$FFFC`, IRQ/BRK `$FFFE` |

Under the ROM and I/O areas there is always RAM. Writes to `$A000-$BFFF` and `$E000-$FFFF`
go to RAM even while the ROM is banked in; writes to `$D000-$DFFF` go to I/O unless I/O is
banked out.

## Bank switching — `$01` (6510 port, with `$00 = $2F`)

| Bits 2-0 | `$A000-$BFFF` | `$D000-$DFFF` | `$E000-$FFFF` |
|---|---|---|---|
| `%111` (`$37`) | BASIC ROM | I/O | KERNAL ROM | *default* |
| `%110` (`$36`) | RAM | I/O | KERNAL ROM | *typical demo setup* |
| `%101` (`$35`) | RAM | I/O | RAM | *all RAM except I/O* |
| `%100` (`$34`) | RAM | RAM | RAM | *64 KB RAM, no I/O* |
| `%011` (`$33`) | BASIC ROM | CHAR ROM | KERNAL ROM | |
| `%001` (`$31`) | RAM | CHAR ROM | RAM | *read the character ROM* |

Bit 3 = datasette write, bit 4 = datasette sense, bit 5 = datasette motor.
Preserve bits 3-5 when changing banks: `lda $01 : and #$f8 : ora #$35 : sta $01`.

**Disable interrupts (`sei`) before banking out the KERNAL** — the IRQ handler lives there.

## Zero page

| Range | Normal owner | Safe for machine code? |
|---|---|---|
| `$00-$01` | 6510 I/O port | **No** — hardware register |
| `$02-$8F` | BASIC working storage | Yes, if you never return to BASIC |
| `$90-$FA` | KERNAL working storage | Yes, if KERNAL calls are not used |
| `$FB-$FE` | Unused by BASIC/KERNAL | **Yes, always** — the 4 classic free bytes |
| `$FF` | BASIC float scratch | Usually yes |

`$A0-$A2` is the jiffy clock, incremented by the KERNAL IRQ — a handy RNG seed *before*
you `sei`, and useless after.

Also commonly used as safe scratch: `$0334-$033B` (unused tape buffer area) and the whole
of `$C000-$CFFF`.

## Exiting a program that took over the machine

A program that did `sei`, wrote over `$02-$8F` and/or banked out ROM cannot `rts` back to
BASIC — BASIC's state is gone. Exit through the KERNAL RESET vector after putting the
hardware back:

```assembly
    lda #$00
    ldx #$18
!:  sta $d400, x        // silence the SID
    dex
    bpl !-
    sta $d015           // sprites off
    lda #$1b
    sta $d011           // display on, 25 rows, text mode
    lda #$37
    sta $01             // default banks back
    cli
    jmp ($fffc)         // KERNAL RESET -> clean READY.
```

See `.claude/c64-reference/review-checklist.md` and `spritemove/spritemov.asm` (`exit_demo`).
