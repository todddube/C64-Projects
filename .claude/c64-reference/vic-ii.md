# VIC-II Display Mapping (6567 NTSC / 6569 PAL)

Sources: *C64 Programmer's Reference Guide* Appendix; MOS 6567/6569 datasheet;
Christian Bauer, *The MOS 6567/6569 video controller and its application in the
Commodore 64* (the standard cycle-accurate reference).

## Registers

| Addr | Name | Meaning |
|---|---|---|
| `$D000-$D00F` | sprite X/Y | sprite *n*: X at `$D000+n*2`, Y at `$D001+n*2` |
| `$D010` | MSIGX | bit *n* = bit 8 of sprite *n*'s X (X range 0..511) |
| `$D011` | CONTROL1 | bit 7 = raster bit 8, bit 6 = ECM, bit 5 = BMM, **bit 4 = DEN**, bit 3 = RSEL (25/24 rows), bits 2-0 = YSCROLL. Default `$1B` |
| `$D012` | RASTER | read: current raster line (low 8 bits); write: raster IRQ compare line |
| `$D013/$D014` | LPX/LPY | light pen latch |
| `$D015` | SPENA | bit *n* = sprite *n* enabled |
| `$D016` | CONTROL2 | bit 4 = MCM (multicolor text/bitmap), bit 3 = CSEL (40/38 cols), bits 2-0 = XSCROLL. Default `$C8` |
| `$D017` | YXPAND | bit *n* = sprite *n* double height |
| `$D018` | MEMPTR | bits 7-4 = video matrix (screen) `* $0400`, bits 3-1 = char base `* $0800`. Default `$15` |
| `$D019` | IRR | interrupt latch: bit 0 raster, bit 1 sprite-bg, bit 2 sprite-sprite, bit 3 light pen, bit 7 = any. **Write back to acknowledge** |
| `$D01A` | IMR | interrupt enable, same bit layout |
| `$D01B` | SPBGPR | bit *n* = sprite *n* drawn *behind* background |
| `$D01C` | SPMC | bit *n* = sprite *n* is multicolor |
| `$D01D` | XXPAND | bit *n* = sprite *n* double width |
| `$D01E` | SPSPCL | sprite-sprite collision latch — **clears on read** |
| `$D01F` | SPBGCL | sprite-background collision latch — **clears on read** |
| `$D020` | border color | |
| `$D021-$D024` | background 0-3 | bg 1-3 used by multicolor/ECM text |
| `$D025/$D026` | sprite multicolor 0/1 | shared by all sprites (bit pairs `01` and `11`) |
| `$D027-$D02E` | sprite *n* color | bit pair `10` in multicolor, all set bits in hi-res |

Only the low 4 bits of every color register are used. Registers are mirrored every `$40`
through `$D000-$D3FF`.

## The VIC bank — you must set this, `$D018` alone is not enough

The VIC-II can only address **16 KB at a time**. The bank is chosen by the *inverted*
low two bits of CIA 2 port A (`$DD00`):

| `$DD00` bits 1-0 | Bank | VIC sees | Character ROM visible at |
|---|---|---|---|
| `%11` | 0 | `$0000-$3FFF` | `$1000-$1FFF` |
| `%10` | 1 | `$4000-$7FFF` | — |
| `%01` | 2 | `$8000-$BFFF` | `$9000-$9FFF` |
| `%00` | 3 | `$C000-$FFFF` | — |

Set the direction bits first:
```assembly
    lda $dd02
    ora #$03
    sta $dd02           // CIA2 port A bits 0-1 = output
    lda $dd00
    and #$fc
    ora #$03            // %11 = bank 0 ($0000-$3FFF)
    sta $dd00
```

Inside the bank, `$D018` places the screen and characters:
```
screen  = bank_base + (($d018 >> 4) & $0f) * $0400
charset = bank_base + (($d018 >> 1) & $07) * $0800
bitmap  = bank_base + (($d018 >> 3) & $01) * $2000     // bitmap mode
```

**Traps:**
- The VIC *always* reads the character ROM image at `$1000-$1FFF` and `$9000-$9FFF` of
  banks 0 and 2, no matter what RAM is there. You cannot put a charset, bitmap or sprite
  data at `$1000-$1FFF` in bank 0 — this is the single most common "my graphics are
  garbage" bug.
- Color RAM is hard-wired at `$D800` and is not affected by the bank.
- Sprite pointers are the last 8 bytes of the **screen** block (`screen + $03F8`), so they
  move when you move the screen.

## Display modes

| ECM (`$D011.6`) | BMM (`$D011.5`) | MCM (`$D016.4`) | Mode |
|---|---|---|---|
| 0 | 0 | 0 | Standard text (40x25, 8x8 chars, per-cell color) |
| 0 | 0 | 1 | Multicolor text (4 colors, 4x8 pixel resolution; color RAM bit 3 selects per cell) |
| 1 | 0 | 0 | Extended background color text (64 chars, 4 backgrounds) |
| 0 | 1 | 0 | Standard bitmap (320x200, 2 colors per 8x8 cell from screen RAM) |
| 0 | 1 | 1 | Multicolor bitmap (160x200, 4 colors per cell: `$D021`, screen hi/lo nibble, color RAM) |
| any | 1 | any with ECM=1 | Invalid modes — display goes black |

Bitmap byte address for pixel (x, y): `bitmap + (y & $F8) * 40 + (y & 7) + (x & $1F8)`.
Screen (color) cell for that pixel: `screen + (y >> 3) * 40 + (x >> 3)`.

## Raster and timing

|  | PAL (6569) | NTSC (6567R8) |
|---|---|---|
| Raster lines per frame | 312 (`$000-$137`) | 263 (`$000-$106`) |
| Cycles per raster line | 63 | 65 |
| Cycles per frame | 19656 | 17095 |
| Frame rate | 50.12 Hz | 59.83 Hz |
| Visible display window | lines 51-250 | lines 51-250 |

Raster line 9 bits: bit 8 lives in `$D011.7`, low 8 bits in `$D012`. Comparing only
`$D012` matches **twice** per frame on PAL for values `< $38`.

Badlines: on any line where `(raster & 7) == ($d011 & 7)` and the display is on, in the
range 48..247, the VIC steals 40-43 cycles to fetch the video matrix, leaving ~20 for the
CPU. Budget effects around this.

Polling `$D012` for a line in the **lower border** (e.g. `$FA` = 250) is the simplest safe
sync: every sprite has been drawn, so positions written there appear cleanly next frame.

Raster IRQ setup:
```assembly
    sei
    lda #$7f
    sta $dc0d           // disable CIA 1 timer IRQs
    sta $dd0d           // disable CIA 2 NMIs
    lda $dc0d           // acknowledge any pending
    lda $dd0d
    lda #$35
    sta $01             // bank out KERNAL (optional; then use $fffe/$ffff)
    lda #<irq
    sta $fffe
    lda #>irq
    sta $ffff
    lda #$01
    sta $d01a           // enable raster IRQ
    lda #$32
    sta $d012           // trigger line
    lda $d011
    and #$7f
    sta $d011           // raster bit 8 = 0
    cli
irq:
    // ... effect ...
    lda #$01
    sta $d019           // ACKNOWLEDGE, or the IRQ fires forever
    // rti, or jmp $ea31 / $ea81 if the KERNAL is banked in
```

## Sprites

- 24x21 pixels hi-res (3 bytes x 21 rows = 63 bytes, padded to 64), or 12x21 in multicolor
  (bit pairs, each pixel double width).
- Data block = address / 64; pointer byte at `screen + $03F8 + n`.
- Multicolor bit pairs: `00` transparent, `01` = `$D025`, `10` = `$D027+n`, `11` = `$D026`.
- Lower sprite numbers have display priority over higher ones.
- Coordinate system is offset from the display: with a 40-column, 25-row screen the
  top-left visible pixel of a sprite sits at X = 24, Y = 50. X needs 9 bits (`$D010`).
- `$D01E`/`$D01F` tell you *that* a collision happened and which sprites were involved,
  but not with what — and they clear on read, so read once per frame into a variable.
  Pixel-accurate pair testing is usually done in software.

## Screen blanking

Clearing DEN (bit 4 of `$D011`, i.e. `$0B` instead of `$1B`) turns the entire display off:
text, bitmap **and sprites** vanish and the whole screen becomes border color. Badlines
stop, so the CPU gets all 63 cycles per line. Set border and background to the same value
before blanking so nothing flickers when DEN comes back on.
