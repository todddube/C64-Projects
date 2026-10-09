# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

This is the `scroller/` project inside the C64-Projects repo. The repo-root `CLAUDE.md`
covers the toolchain, the NTSC-first policy, the `c64-reviewer` agent and the demo
conventions. This file covers only what is specific to this project.

## What it is

**STARDUST**, a space scroller. The screen has four parts:
- a logo of 8 Y-expanded letter sprites;
- a ringed multicolor planet with a moon that orbits in front of it and behind it, and a
  ship with a flickering thruster;
- a parallax char starfield over a fixed background sky;
- a horizon glow, then a DYCP scroller (each letter at its own height) riding over copper
  bars. Nightshift (Agemixer) plays throughout.

It opens with a start-up wipe (`scroller_intro.asm`): black, a raster wipe down to solid
blue with a light-blue/white glow edge, a ~2.5 s pause, a wipe back up to black, then the
demo. RUN/STOP resets to BASIC, during the wipe as well.

## Build and run

`scroller.asm` is the project's main source and it `#import`s `scroller_intro.asm` and
`scroller_data.asm`, which can't be built on their own. Build from this directory, because
the imports and `LoadSid` are relative to it:

```bash
java -jar /Applications/KickAssembler/KickAss.jar scroller.asm -odir bin 2>&1 | tee bin/buildlog.txt | grep -vE '^//|^parsing$|^flex pass|^Output pass$|^Output dir:|^$|^ +(Music:|init |\$)'
/Applications/vice-arm64-gtk3/bin/x64sc -ntsc -autostart bin/scroller.prg
```

A clean build also prints the deliberate `.print` block at the end of `scroller.asm`: a
blank line, `SID Data`, `--------`, then the tune's location/init/play/name/author.

`scroller.prg/.sym/.dbg/.vs` in this directory and `bin/scroller.sym` are tracked
leftovers from older builds of the previous demo. The current build writes only
`bin/scroller.prg`.

## Memory and banking

| Range | Contents |
|---|---|
| `$0400` | screen; sprite pointers at `$07f8` |
| `$1000-$1d77` | Nightshift (not relocatable). Its player writes zero page `$f8/$f9` |
| `$2000-$27ff` | main charset: `BLANK`, 64 one-pixel star glyphs (`$40-$7f`), 2 twinkles. Built at start-up |
| `$2800-$2fff` | DYCP charset: column `c` is chars `c*6+1..c*6+6`, i.e. 48 contiguous bytes |
| `$3000-$31ff` | logo letter sprites, built at start-up from the character ROM |
| `$3200-$33ff` | planet ×4, ship, flame ×2, moon. Generated at assembly time in `scroller_data.asm` |
| `$4000-` | code, then tables |

The demo runs with `$01 = $35`: BASIC and the KERNAL are banked out, and the IRQ and NMI
vectors are the hardware ones at `$fffe/$fffa`. `$33` is used only while reading the
character ROM in `start`. `exit_demo` sets `$37` back before `jmp ($fffc)`.

`BLANK` (char 0) must stay empty in **both** charsets. Rows 17-18 hold it, and
`irq_bars` switches `$d016`/`$d018` in the middle of row 17.

## Start-up wipe

`intro` runs from `start` after `detect_video` and before `music.init`, with interrupts off
and DEN off, so the whole screen is border color and there are no badlines. Every color
change is a polled `$d020` write. `border_at` waits for the line before its target on all
9 bits, then for the target's low byte, so the write lands at cycle ~6-13. Lines count
from `INTRO_TOP` (16) mod the frame's line count, which comes from `raster_max` (stored by
`detect_video`), so the wipe crosses line 0 on NTSC, where lines 0-12 are the bottom
border. The glow stripes are 3 lines apart because the gap from one write to
`border_at`'s first poll is ~130 cycles, which leaves only about half a line spare. It
uses zero page `$33-$41`, which nothing else touches.

## Frame structure

There are three raster IRQs, chained by rewriting `$fffe` and `$d012`:

| Line | Handler | Does |
|---|---|---|
| 30 | `irq_top` | logo sprites from shadows (`logo_*`), then `music_tick` |
| 108 | `irq_mid` | the same 8 sprites become the scene (`mid_*` shadows) |
| 192 | `irq_bars` | `$d016` fine scroll and the DYCP charset on, then polls `$d012` and writes `$d021` from `bar_buf` for lines 194-250. At 251 it restores everything and sets `frame_flag` |

`main_loop` starts each frame at line 251, and the order of its calls matters:
1. `advance_scroll`, `update_logo` and `update_mid` must finish before `irq_top` copies
   their shadows at line 30.
2. `draw_dycp` must finish before the beam reaches row 19 (line 203).
3. `build_bars` must finish before line 194.

The bars are clean without a stable raster because each `sta $d021` lands at cycle 6-12
of its line, before the display window and before a badline stalls the CPU. That only
holds while **no sprite is displayed on lines 192-250**. The scene's Y tables keep every
sprite above line 186.

## Cycle budget (NTSC, measured)

These are measured with VICE on NTSC:

| Item | Cycles per frame |
|---|---|
| `irq_bars` (lines 192-251) | ~3900 |
| Nightshift play (in `irq_top`) | ≤2046 (typically ~1530). On NTSC it runs 5 frames in 6 |
| `draw_dycp` | ~5300 |
| `update_stars` | ~1100 |
| `build_bars` | ~650 |
| `update_mid` | ~480 |
| `update_logo` | ~400 |
| `update_twinkle` | ~300 |

The main loop's work ends by line ~183 on NTSC, against `irq_bars` at 192, which is only
about 9 lines of slack. Anything added per frame has to be paid for somewhere else.

Two debug counters can be checked with `vice_peek.py --mem 002d 002e`:
- `overruns` (`$2d`) counts frames whose work ran past `irq_bars`. It must stay 0.
- `prof_max` (`$2e`) is the latest raster line the work has ended on.

## Things that are easy to break

- **DYCP wipe margin.** `draw_dycp` never clears the charset. Each column's 12-byte block
  has 2 zero rows above and below the glyph, which erase the previous frame. That only
  works while a column moves at most 2 pixels a frame (currently 1.43, from `p1 += 3`,
  `p2 -= 2`, and the tabA/tabB amplitudes). If you raise those, raise the margin as well.
- **Table run-off.** `tabA`, `tabB`, `bob_tab` and `logo_grad` run past 256 entries,
  because the unrolled code folds per-column or per-letter offsets into the table address.
  Changing a step (`7*c`, `5*c`, `24*i`) means changing the table length too.
- **Moon priority.** The moon passes behind the planet by moving between sprite slot 2 (in
  front of the planet's slots 3-6) and slot 7 (behind them), and `mid_en` hides whichever
  slot is unused.
- **Background stars.** `bg_colors` must sit exactly `$300` after `bg_chars`, which an
  `.errorif` checks. `update_stars` restores a cell from these maps when a star leaves it.
- **Scroll text.** It is screen codes ending in `$ff`, and only codes 0-63 have glyphs.
