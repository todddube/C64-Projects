# spritemove

A Commodore 64 demo in 6502 assembly: a multicolor bitmap intro with a carved
and flying logo, then four shaded balls drifting around a starfield with
trails, collision sparks and SID ping effects.

Written for **KickAssembler v5.25**, tested in **VICE x64sc** (PAL), targeted at
an **Ultimate II+** cartridge.

---

## Build and run

```bash
# Build (a clean build prints exactly one line: "Writing prg file: main.prg")
java -jar /Applications/KickAssembler/KickAss.jar main.asm -odir bin

# Run
/Applications/vice-arm64-gtk3/bin/x64sc -autostart bin/main.prg
```

Output is `bin/main.prg`, about 24 KB. The repo's `/build` and `/run` slash
commands do both steps.

To *see* a particular moment without watching in real time, let VICE run a fixed
number of cycles in warp and screenshot on the way out:

```bash
/Applications/vice-arm64-gtk3/bin/x64sc -autostart bin/main.prg \
    -warp -limitcycles 12000000 -exitscreenshot /tmp/shot.png
```

Autostart costs roughly 4M cycles before the intro's first frame, and PAL runs
985248 cycles a second.

---

## Controls

| Key | Action |
|---|---|
| `+` / `-` or `CRSR` | Speed level, 1-16 (default 4 = half base speed) |
| `RUN/STOP` | Ends the demo |

The bottom text row is a status bar: `SPD [####............] +/- CRSR STOP=END`.

`RUN/STOP` does not return to BASIC — the demo has overwritten BASIC's zero
page, so there is nothing sane to return to. It silences the SID, clears the
sprites and jumps through the KERNAL reset vector at `$fffc`, which gives a
normal `READY.` prompt. `RUN/STOP+RESTORE` is defused at startup by masking
CIA2's NMI, because `sei` does not mask NMI and a warm start would land on the
same trashed zero page.

---

## What it does

### The intro (~13 seconds)

A multicolor bitmap spiral, generated at assembly time, that never changes a
single pixel at run time — all the motion is colour.

The trick is that the spiral only claims **three** of the four bit-pair values
multicolor bitmap mode offers (`mod(..., 3)` in `intro_gfx.asm`), leaving `11`
— colour RAM — reserved entirely for the logo. So one bitmap holds two
interleaved pictures that can never interfere: the bands, lit from the video
matrix, and the letters, lit from colour RAM. Each has its own ramp, its own
rotation and its own fade.

Because both are per-*cell*, animating the whole screen is two 1000-byte table
lookups rather than a redraw. `paint_sweep` recolours one 256-cell page per
frame at 31 cycles a cell — about 8200 cycles — and rotates through the four
pages, so the screen refreshes top to bottom every four frames while the ramps
keep turning. That reads as a wave travelling down through the spiral rather
than as tearing.

The sequence:

| Phase | Frames | What happens |
|---|---|---|
| A | 112 (~2.2s) | Concentric rings ripple up out of black, the second band colour joining half way |
| B | 176 (~3.5s) | The spiral field takes over and accelerates; the logo flies in |
| F | 224 (~4.5s) | The tight three-turn field; the logo keeps flowing |
| C | 112 (~2.2s) | Sprites switch off and the carved logo ignites to chrome |
| D | 24 (~0.5s) | White flash, then the handoff to the balls |

The logo appears twice and never at the same time. Through A, B and F it is a
set of black holes punched in the spiral — present and shaped, but unreadable —
while a sprite copy flies over the top. When the sprites switch off at the start
of C the carving lights up, so the flying logo reads as *landing* in the bitmap.

**Why two copies.** A bitmap cannot move; redrawing 8000 bytes is nowhere near a
frame. Sprites are the only thing on this machine that moves for free. So the
logo is built once from glyph rows lifted from the C64 character ROM and emitted
twice — carved into the bitmap by `intro_gfx.asm`, packed into sprites by
`intro_sprites.asm` (3 characters per sprite, every font row stored twice,
X-expanded to 16x16). None of the font reaches the `.prg`; by run time the
letters are already pixels.

The flight path comes from one 256-entry sine table read with a byte index, so
nothing ever needs clamping: a horizontal **drift** (5.1s) that all four sprites
of a word share so it stays a word, a **bob** (2.6s) that moves it as one body,
and a small per-sprite **ripple** (1s) a quarter period apart along the word so
it undulates. Three periods sharing no common factor, so the path never repeats
in the 8 seconds it is up. The date carries a half-period offset, so the two
words swing against each other and cross.

The music is *Nightshift* by Ari Yliaho (Agemixer), imported from PSID and
driven one tick per frame at a fixed raster line.

### The demo

Four multicolor sprites — ray-shaded balls, generated at assembly time — drift
around a black starfield with smooth random motion. Each ball spins as it moves
(faster when it moves faster, reversing when it turns) and drags a dark ghost
disc behind it, showing where it was `TRAIL_DELAY` frames ago.

Everything moves in **8.8 fixed point**, one byte of whole pixels and one of
1/256ths, so a ball can travel at 0.3 px/frame and still look smooth. X needs 9
bits, so it is carried as `x_msb : x_lo : x_frac`.

Each ball gets one random heading at startup and keeps it. Only two things ever
change direction: reaching an edge (that axis reflects) or touching another ball
(they push apart and swap colours). A bell-like SID ping fires on every bounce —
low for a wall, higher and randomly pitched for a ball-to-ball hit — and a
ball-to-ball hit also throws an ASCII spark onto the text screen at the point of
contact.

Stored velocities are *base* velocities, scaled every frame by the global speed
level (`effective = base * speed / 8`), so changing speed never disturbs the
headings or the bounces.

---

## Files

| File | Contents |
|---|---|
| `main.asm` | The demo: registers, zero page, main loop, physics, collisions, trails, sparks, sound, status bar |
| `sprite_gen.asm` | Assembly-time ball frames (8) and the trail disc |
| `intro.asm` | The opening sequence: phases, sweep, palette and glint tables, sprite flow |
| `intro_gfx.asm` | The spiral bitmap with the logo carved in, plus the cell fields |
| `intro_sprites.asm` | The flying logo sprites and the sine table |
| `intro_text.asm` | Glyph rows for the logo, lifted from the C64 character ROM |
| `music.asm` | PSID import of `Nightshift.sid` |
| `Nightshift.sid` | The intro tune |

None of the `intro_*` files or `sprite_gen.asm` assemble on their own — they are
`#import`ed into `main.asm`'s code segment and depend on its labels.

---

## Memory layout

```
$0002-$0072  zero page (see below)
$0400-$07e7  text screen: stars, status row 24 (sprite pointers at $07f8)
$0801        BASIC stub "10 SYS 8768" (8768 = $2240)
$1000-$1d77  Nightshift.sid - player and data at its own load address
$2000-$21ff  8 ball frames, 64 bytes each   (VIC blocks $80-$87)
$2200-$223f  trail disc frame               (VIC block  $88)
$2240-...    code and data tables
$3000-$33e7  intro text mask   (1000 cell glint values, CPU only)
$3400-$3fe7  intro wave fields (3 x 1000 cell values, CPU only)
$4000-$5f3f  intro bitmap      (VIC bank 1, 8000 bytes)
$6000-$63e7  intro video matrix (VIC bank 1, filled at run time)
$63f8-$63ff  intro sprite pointers (VIC bank 1)
$6400-$65ff  intro logo sprites (VIC bank 1, 8 x 64 bytes)
$6600-$66ff  intro sine table   (CPU only)
```

**The code segment starts at `$2240`, not the usual `$0810`.** A PSID player is
not relocatable and Nightshift loads at `$1000-$1d77`, so the code has to start
above it.

The intro runs in **VIC bank 1** (bitmap `$4000`, video matrix `$6000`, its own
sprites `$6400`) and hands over to **bank 0** text mode for the demo. The two
sprite sets never collide: the demo's live in bank 0 at `$2000`, the intro's in
bank 1.

### Zero page

The intro's variables live in the **gaps between the demo's**, and there are no
gaps left. `$36-$39` is the hole in the per-ball tables — between `tvy_hi`
(`$32-$35`) and `anim_lo` (`$3a`) — and the intro fills it exactly; it also
holds `$4f` and `$52-$53`. Every byte from `$02` to `$72` is now spoken for.

A new 4-entry per-ball array **must not** be placed at `$36`: it would collide
with the intro's sweep and flying-logo state.

---

## Things that are load-bearing

Worth knowing before editing:

- **Carve order in `intro_gfx.asm`.** `near_text` includes its own `(0,0)`
  offset, so it blacks out glyph interiors too, and the carve must come second
  to put them back. Swapping those two lines erases the whole logo silently.
- **Glyph bits.** The knockout outline only works while every lit pixel is in
  bits 6..1 of its font row. This is checked with `.errorif` at build time, so a
  glyph that breaks it fails the build instead of quietly losing one side of its
  outline.
- **`vmtab`/`coltab` alignment.** `.align $20` keeps them off a page edge;
  `paint_sweep` reads both with `lda abs,y` 512 times a frame and a page cross
  there costs ~200 cycles a frame.
- **The sweep stops at `$63e7`**, eleven bytes short of the sprite pointers at
  `$63f8`. Extending it would overwrite them.
- **Phase D is the tightest frame in the intro.** `flash_field` is 13056 cycles,
  leaving the music player ~5400 of a PAL frame and ~2900 of an NTSC one. An
  overrun is benign — `intro_sync` misses line 250 and waits a frame, so the
  white-out stutters rather than breaking.

---

## Verification status

PAL timing was measured in VICE; the intro's per-frame budget and the zero page
and memory layout have been checked against the hardware references in
`.claude/c64-reference/`. Not verified: NTSC, `RUN/STOP` pressed *during* the
intro (reasoned correct — the KERNAL reset re-initialises `$dd00` and `$d018` —
but not exercised with a real keypress), and the cycle budget with the eight
flying sprites stealing DMA during phases B and F.
