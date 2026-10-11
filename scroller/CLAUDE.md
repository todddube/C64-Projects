# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

This is the `scroller/` project inside the C64-Projects repo. The repo-root `CLAUDE.md`
covers the toolchain, the NTSC-first policy, the `c64-reviewer` agent and the demo
conventions. This file covers only what is specific to this project.

## What it is

Two demo parts in a loop, with Nightshift (Agemixer) playing throughout and never
restarting:

1. **STARDUST** (`scroller.asm`), until its scroll text has gone by once (~31 s NTSC).
2. A curtain wipe to black (`wipe.asm`), then **ARCADE** (`arcade.asm`) for 30 s.
3. Another curtain wipe, and back to 1.

Every curtain picks its direction (down or up) and its glow palette (cool, fire, toxic,
neon) at random.

**STARDUST**, a space scroller. The screen has four parts:
- a logo of 8 Y-expanded letter sprites;
- a ringed multicolor planet with a moon that orbits in front of it and behind it, and a
  ship with a flickering thruster;
- a parallax char starfield over a fixed background sky;
- a horizon glow, then a DYCP scroller (each letter at its own height) riding over copper
  bars. Nightshift (Agemixer) plays throughout.

It opens with a start-up wipe (`scroller_intro.asm`): black, a raster wipe down to solid
blue with a light-blue/white glow edge (inside a black border), a ~1.7 s pause, a wipe
back up to black, then the demo. The wipe has sound: two detuned saws swell in on black and rise with the first
wipe, and a filtered-noise whoosh closes with the second. RUN/STOP resets to BASIC,
during the wipe as well. The start-up wipe plays once, at power-on, not on every loop.

**ARCADE**, an homage to the golden-age arcade games:
- `1UP` / `HIGH SCORE` header. Things scored below add to it, and the high score follows
  it once it is beaten. The score carries over from one visit to the next;
- a Galaxian formation (chars) swaying with fine scroll, with a Galaga fighter shooting
  up at it and a bee and a butterfly looping a figure eight in front of it;
- Asteroids: a rotating ship (16 headings) firing at six drifting, bouncing rocks that
  blow up into debris and come back in from an edge;
- a Pac-Man corridor. Pac-Man eats the dots up to the power pill with the four ghosts
  behind him. Then everyone turns around, the ghosts go blue, and he eats them for
  200/400/800/1600;
- a double-height scroller with a rainbow running through it.

## Build and run

`scroller.asm` is the project's main source. It `#import`s `scroller_intro.asm`,
`wipe.asm`, `arcade.asm`, `arcade_data.asm`, `scroller_data.asm` and `arcade_sprites.asm`,
none of which can be built on its own. The order matters: `scroller_data.asm` ends with
the STARDUST sprite art at `$3200-$33ff`, and `arcade_sprites.asm` carries on at `$3400`. Build from this directory, because
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
| `$0400` | screen (both parts); sprite pointers at `$07f8` |
| `$0800-$0fff` | ARCADE charset: ROM screen codes 0-63, custom `$40-$7f`, double-height font top halves `$80-$bf` and bottom halves `$c0-$ff`. Built at start-up |
| `$1000-$1d77` | Nightshift (not relocatable). Its player writes zero page `$f8/$f9` |
| `$1e00-$1fff` | `STAR_SINK`: stars in rows covered by the curtain draw here, and their colors land at `$f200-$f3ff`. Keep both ranges free |
| `$2000-$27ff` | main charset: `BLANK`, 64 one-pixel star glyphs (`$40-$7f`), 2 twinkles. Built at start-up |
| `$2800-$2fff` | DYCP charset: column `c` is chars `c*6+1..c*6+6`, i.e. 48 contiguous bytes |
| `$3000-$31ff` | logo letter sprites, built at start-up from the character ROM |
| `$3200-$33ff` | planet ×4, ship, flame ×2, moon. Generated at assembly time in `scroller_data.asm` |
| `$3400-$3ebf` | ARCADE's 43 sprites, generated at assembly time in `arcade_sprites.asm` |
| `$4000-$9bbd` | code, then tables |

Zero page: STARDUST `$10-$32`, intro `$33-$42`, ARCADE `$43-$67`, wipe `$68-$78`
(declared in `scroller.asm`, which uses them before `wipe.asm` is imported), plus the
shared `temp1-4`, `loop_i`, `frame_count` and `ptr1/ptr2` from `zeropage.asm`.

The demo runs with `$01 = $35`: BASIC and the KERNAL are banked out, and the IRQ and NMI
vectors are the hardware ones at `$fffe/$fffa`. `$33` is used only while reading the
character ROM in `start`. `exit_demo` sets `$37` back before `jmp ($fffc)`.

`BLANK` (char 0) must stay empty in **both** charsets. Rows 17-18 hold it, and
`irq_bars` switches `$d016`/`$d018` in the middle of row 17. For the same reason the wipe's
`SD_EDGE` (`$fe`) and `SD_SOLID` (`$ff`) are kept identical in both STARDUST charsets (the
DYCP charset only uses chars 1-240).

## Start-up wipe

`intro` runs from `start` after `detect_video` and before `init_screen` and `music.init`,
with interrupts off and no sprites. The border stays black: the wipe is drawn in `$d021`
over a screen of `BLANK` chars, so it only shows inside the display window (lines 51-250).
Every color change is a polled `$d021` write. `color_at` waits for raster bit 8, then
catches the line before its target and the target in two 7-cycle loops, so the write
lands at cycle 6-12, before a badline stalls the CPU (the `irq_bars` trick). Don't add a
cycle to the target loop. A write that early shows on the last 7 pixels of the line above,
so the intro runs in 38 columns (`$d016=$00`) and the right border hides them. Lines count from `INTRO_TOP` (16)
mod the frame's line count, which comes from `raster_max` (stored by `detect_video`).
`in_pos` sweeps `WIPE_FROM`..`WIPE_TO`, the edge's range across the window.

The glow stripes are 4 lines apart because the gap from one write to `color_at`'s first
poll is ~130 cycles, plus 40 when a badline falls in it. `intro_sfx` runs right after the
top-of-frame write, which is why the first stripe is 5 lines down. The intro uses zero
page `$33-$42`, which nothing else touches, uses the SID freely and `sid_clear`s it
before `music.init`, and turns the display back off (`$0b`) when it ends.

## Parts and the curtain wipe

The parts hand over to each other with `jmp`, never `jsr`, so the stack never grows:

```
start -> intro -> music.init -> irq_idle on -> stardust_enter -> main_loop
main_loop: text done -> sd_wipe_start ... wipe done -> part_blackout -> arcade_enter
arc_loop:  30 s     -> arc_wipe_start ... wipe done -> part_blackout -> stardust_enter
```

- `part_blackout` is called once the curtain is all black. It switches the display off
  (`$d011=$0b`, which looks the same) and hands the IRQ to `irq_idle`, a lone IRQ at line
  30 that only plays the music and sets `frame_flag`. 20 black frames follow.
- A part's `_enter` builds its screen with the display off, then `part_sync` waits for
  `irq_idle` and for line 60, past the VIC's DEN check at line 48. Only then does it
  install its own IRQ chain and turn DEN on. The first frame you see is already split
  correctly.
- `stardust_enter` re-runs `init_vars`, which clears `$10-$30`, so it saves and restores
  `ntsc`, `music_div` and `seed` around it.

The curtain (`wipe.asm`) is a row of SOLID chars in black with a glow band behind the edge
(the edge row and the row behind it in `c0`, then `c1`, `c2`, black). The edge itself is
line exact: an EDGE char whose glyph `wipe_step` rewrites every frame to show the top
(or, wiping up, the bottom) `w_pos & 7` lines. Sprites go behind the foreground
(`$d01b=$ff`), so the solid chars cover them. Rows are counted as a distance `d` from the
starting edge. Row = `d` going down and `24 - d` going up. Rows are repainted only when the
edge crosses into a new one: ~2700 cycles on those frames, nothing extra on the others.

While the curtain runs, **a part must not write chars or colors into a covered row**, or
it punches a hole in it. `row_locked` (A = row) returns C set for a covered row. Every
ARCADE char writer checks its rows. STARDUST skips `draw_dycp` (its scroller is all spaces
by then, which is what the 40 trailing spaces in `scroll_text` are for, and which pays
for the wipe) and `update_twinkle`. `sd_lock_stars` points covered rows' stars at
`STAR_SINK`.

## ARCADE frame structure

| Line | Handler | Does |
|---|---|---|
| 20 | `irq_arc_top` | band A sprites (Galaga), then `music_tick` (ends by ~60) |
| 73 | `irq_arc_sway` | `$d016` = formation fine scroll, 38 columns (row 2 is empty) |
| 108 | `irq_arc_unsway` | `$d016` back (row 7 is empty) |
| 127 | `irq_arc_b` | band B sprites (Asteroids) |
| 188 | `irq_arc_c` | band C sprites (Pac-Man), ghost multicolors |
| 228 | `irq_arc_scr` | `$d016` for the scroller (row 22 is empty) |
| 251 | `irq_arc_end` | `$d016` back, `frame_flag` |

Sprite shadows are `sh_*` in `arcade_data.asm`, indexed `band * 8 + sprite` and copied by
the `BandCopy` macro. X is kept in 2-pixel units (`xs`, 0-183) so it fits a byte. `sxs`
doubles it into the shadow and its MSB, and xs 0 and 172-183 are off-screen, so things wrap
out of sight. Bands must not overlap: A ends by line 125, B is Y 136-167 (art fits lines
136-187), C is Y 203. `arc_update` runs the bands in beam order, A, B, C.

`overruns` (`$2d`) counts overrun frames in ARCADE too. It stays 0 on NTSC and PAL.

## STARDUST frame structure

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
  STARDUST's has to end in at least 40 spaces, because the wipe starts when the text wraps
  and `draw_dycp` stops drawing then. ARCADE's text is the same, shown double height.
- **ARCADE sprite order.** `arcade_sprites.asm` builds the sprites in the order of the
  `SP_` constants in `arcade.asm`, with an `.errorif` at each group. Add sprites at the
  end, and keep `$3fc0+` free.
- **ARCADE split rows.** Rows 2, 7 and 22 must stay empty, because the `$d016` writes land
  somewhere in them. The formation is rows 3-6, and its colors are fixed per row, so only
  chars move. `form_img` rows are padded with 10 blanks on the left.
- **KickAss script lists.** Global `List()` constants used in macros need `.lock()`, or
  the multi-pass assembler stops with "unlocked value across passes".
