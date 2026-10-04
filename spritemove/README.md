# spritemove

A Commodore 64 demo in 6502 assembly: a raster bar overture, a hi-res bitmap
intro with a carved and flying logo, then 4 to 16 shaded balls (8 to start)
drifting around a starfield with collision sparks and SID ping effects, using
the full height of the screen — the vertical border is held open, so the balls
fly into it. Past eight balls the VIC's eight sprites are multiplexed by a
raster IRQ.

Written for **KickAssembler v5.25**, targeted at **NTSC** C64s (US machines)
first and PAL second, tested in **VICE x64sc** on both, deployed via an
**Ultimate II+** cartridge.

---

## Build and run

```bash
# Build. Four lines are expected: three from music.asm's .print (the tune's
# name and its load/init/play addresses) and "Writing prg file: main.prg".
java -jar /Applications/KickAssembler/KickAss.jar main.asm -odir bin

# Run (NTSC; drop -ntsc or pass -pal for the PAL check)
/Applications/vice-arm64-gtk3/bin/x64sc -ntsc -autostart bin/main.prg
```

Output is `bin/main.prg`, about 32 KB (`$0801-$83e7`). The repo's `/build` and
`/run` slash commands do both steps.

To *see* a particular moment without watching in real time, let VICE run a fixed
number of cycles in warp and screenshot on the way out:

```bash
/Applications/vice-arm64-gtk3/bin/x64sc -ntsc -autostart bin/main.prg \
    -warp -limitcycles 12000000 -exitscreenshot /tmp/shot.png
```

Autostart costs roughly 3.2M cycles before the intro's first frame (measured;
it grows with the `.prg`). NTSC runs 1022727 cycles a second (a frame is 17095),
PAL 985248 (a frame is 19656). The overture and the bitmap intro are timed in
**tune ticks**, not frames, so they take the same wall-clock time on both: the
balls appear about 26 seconds in.

### NTSC and PAL

`detect_video` reads the highest raster line at start-up (`$106` NTSC, `$137`
PAL) and three things follow from it:

- **Music tempo.** *Nightshift* is a PAL tune, one play call per 50 Hz frame.
  Played once per 60 Hz NTSC frame it runs 20% fast, so `music_tick` skips
  every sixth call on NTSC: 50 plays a second on both.
- **Intro timing.** The phase lengths are frame counts written to land on the
  tune's beats. On a frame `music_tick` skipped, every duration counter holds
  (`BeatDec`), so the phases stay on the beat; the animation still moves on
  every frame.
- **The overture's band.** Its polled raster bars leave the vertical blank for
  everything else — music, bar movement, rebuilding the line buffer. PAL has
  118 lines of it, NTSC only 69 (about 4500 cycles), so on NTSC the band ends at
  line 232 instead of 250 (the lowest label is at lines 219-226).

Note that `-limitcycles` stops the emulator wherever it lands, which is usually
part way down a frame — the screenshot is then the part of that frame drawn so
far, with the rest black. To get whole frames, find one cycle count that lands
in the vertical blank and step from it in multiples of 17095 (NTSC) or 19656
(PAL).

---

## Controls

| Key | Action |
|---|---|
| `+` / `-` or `CRSR` | Speed level, 1-16 (default 4 = half base speed) |
| `B` / `SHIFT+B` | Ball count, 4-16 (default 8) — see Sprite multiplexing below |
| `R` | Restart from the very top of the intro |
| `Q` or `RUN/STOP` | End the demo, back to a `READY.` prompt |

The bottom **two** text rows are the menu — a fixed legend of the keys on row 23,
and the speed bar, the ball count and the exit key on row 24:

```
SPEED +/- CRSR B=BALLS R=RESTART Q=QUIT
SPD[####............] B:08 STOP=END
```

`R` works during the intro as well as during the demo, because it is scanned in
`check_exit`, which both the intro loop and the main loop call every frame. It
silences the SID, hides the sprites, waits for the key to come back up (otherwise
holding it would restart on every frame and freeze on the intro's first black
frame) and jumps to `start`. `start` resets the stack pointer for exactly this
reason — the jump comes from several `jsr`s deep, so without it every restart
would strand a return address and the stack would eventually wrap into zero page.

`Q` and `RUN/STOP` share keyboard row `$7f` — bits 6 and 7 — so one matrix read
tests both. A joystick in control port 1 is wired onto the same column lines, so
while one is pushed the other keys are ignored (otherwise joystick-down reads as
`R`); the exit keys use bits the joystick never drives and always work.

`RUN/STOP` does not return to BASIC — the demo has overwritten BASIC's zero
page, so there is nothing sane to return to. It silences the SID, clears the
sprites and jumps through the KERNAL reset vector at `$fffc`, which gives a
normal `READY.` prompt. `RUN/STOP+RESTORE` is defused at startup by pointing
the NMI vector `$0318` at an `rti` (`nmi_ignore`): `sei` does not mask NMI,
RESTORE reaches `/NMI` directly, and the kernal's handler would warm-start BASIC
on the same trashed zero page. Masking CIA 2 at `$dd0d` alone cannot stop it.

---

## What it does

### The overture (~10 seconds)

Before the bitmap intro there is a raster bar sequence in plain text mode:
eight colour bars flying over a black screen while the handle, five labels
and a closing music credit fade up one at a time; the labels go dark with the
closing flash rather than snapping off after it. See `intro_raster.asm`.

There is no per-cell work in it at all. Everything is one byte per **raster
line** in a page-aligned buffer at `$0900`, and a frame is two halves that
never overlap: `rb_show` walks lines 56 to 250 waiting for each one and writing
its byte to both `$d020` and `$d021` (in text mode `$d021` is the paper the
characters sit on, so one write stripes the border and the screen together and
the bars pass *behind* the letters), and everything else — music, keyboard, the
bar movement, the rebuild of the buffer — happens in the ~117 lines between 250
and 56, about 7300 cycles.

A bar is four bytes of state:

```
y = ctr + asr(sin(ph + off) - 128, sh + gsh)
```

`ph` advances by `spd` every frame, `off` is the bar's fixed place in the set,
`sh` is amplitude as a shift (1 is ±64 lines), and `gsh` is a **global** extra
shift added to every bar's own — raising it collapses the whole set into one
line and lowering it blows it back open, which is the entire implode/explode
effect for one byte. The subtract of `$80` and the arithmetic shift right
(`cmp #$80 / ror`, carry = sign) are what keep the swing centred on `ctr`
however far `gsh` squeezes it; a plain `lsr` would drag every bar towards the
top of the screen as the amplitude came down.

A movement mode is just 40 bytes — `off`, `spd`, `sh`, `ctr` and a palette pick
for each of the eight bars — so the behaviour is entirely in the numbers:

| Mode | What it looks like |
|---|---|
| WAVE | One speed, phases an eighth of a turn apart: a single wave travelling down the screen and back |
| SCISSOR | Pairs half a turn apart, staggered — four crossings closing on themselves |
| FAN | One phase, amplitudes 64/32/16/8 mirrored: the bars nest inside one another and breathe |
| CHAOS | Eight speeds (1,2,3,5,7,4,6,9) about eight centres — no two bars ever repeat the same relationship |
| IMPLODE | One speed, `gsh` driven 0→7 or 7→0: the bars converge into one thick bar or erupt out of it |

The script runs nine steps of them, opening on an explosion out of a single
line and closing on the implosion back into one, so the overture is bracketed
by the same move played both ways. The last step before the close is a quiet
beat of its own for a "MUSIC BY ARI YLIAHO (AGEMIXER)" credit — the one label
that is *not* letter-spaced like the other six, and capped to a flat grey, so
it reads as smaller and quieter without an actual second font: there is no
sub-8px text in C64 character mode without a full custom charset (`$d018`
selects one charset for the whole screen, so every glyph the other labels use
would have to be duplicated into it just for one credit line). It ends on a
white strobe that the labels vanish into, and hands over to the bitmap intro
on a black screen.

**On raster stability.** The wait loop is `cpy $d012 / bne`, seven cycles, and a
PAL line is 63 — exactly nine iterations, so it detects every line at the same
cycle offset and the bar edges line up down the screen. A badline upsets that:
it halts the CPU for 40 cycles, 40 does not divide by 7, and the loop comes out
on a new phase. So the colour byte is loaded **before** the wait, leaving
nothing between detection and the stores; `$d020` has the new colour by cycle
8-14, which is inside the horizontal blank for six of the seven offsets. The
seventh clips the visible left border and leaves a sliver of the previous
line's colour — 8.5% of lit lines, measured over ten consecutive PAL frames in
VICE, against a solid eight-line staircase when the load sat after the wait.
Closing the last of it needs a cycle-exact loop, which needs a stable entry and
per-badline padding, at which point the loop has no slack and the first frame
whose off-screen work runs long desynchronises it for good. The polling loop is
self-healing by construction, which is worth more here.

### The intro (~17 seconds)

A hi-res bitmap **retro sunset grid** — sky bands, a perspective floor and a striped badge sun on the horizon between them — generated at
assembly time and never changed a single pixel at run time; all the motion is
colour. This used to be a polar spiral tunnel; see below for why it isn't now.

Hi-res gives 320 pixels across but only **two** colours per 8x8 cell, both from
the video matrix byte: high nibble ink, low nibble paper. Colour RAM and `$d021`
are not used by the mode at all, so every cell is a free two-colour pair.
Shading comes from **ordered dithering** — the pattern is computed as a
continuous intensity and thresholded against a 4x4 Bayer matrix, so at 320
pixels the dots read as a gradient between the cell's two colours.

**Rows and columns, not distance and angle.** The old picture built every pixel
from its distance and angle to the screen centre — a spiral tunnel, by
construction. The new one has no `sqrt`/`atan2` in it at all:

- **sky** (above the horizon) — flat horizontal sunset bands, their edges
  warped a few pixels by two hoisted sine tables so they breathe instead of
  ruling dead straight, plus a per-band pseudo-random hash jitter that nudges
  each stripe's edge a little early or late — real scanlines are never
  perfectly even, and that unevenness is baked into the picture on purpose
- **floor** (below the horizon) — meant as a perspective checkerboard: screen
  X is divided by depth before it is tiled, so the squares narrow toward the
  horizon the way a real floor recedes (as tuned, the tiles are so wide that
  below the fog the floor reads as two halves - see the review notes), and a fog term dithers the near tiles
  crisp and the far ones toward grey static so the horizon disappears into
  haze rather than snapping off
- **sun** — a plain circle sat on the horizon, cut by horizontal stripes that
  widen toward the bottom (spacing grows with `sqrt` of distance from the top
  of the disc). The only round thing on screen, and it doesn't rotate.

The logo shares that one bitmap without ever interfering with the backdrop,
because the separation is in the **cell fields** rather than in the picture.
Each field byte carries a ramp position in its low nibble and a flag in **bit
4** saying which ramp: `$00-$0f` is a backdrop cell stepping with `pal_phase`,
`$10-$1f` is a logo cell stepping with `text_phase`. `build_tabs` fills a
32-entry table, and one `lda vmtab,y` resolves both layers at once — which is
how the letters keep their own colour and their own glint in a mode with only
two colours per cell to spend.

Because it is all per-*cell*, animating the whole screen is a table lookup per
cell rather than a redraw. `paint_sweep` recolours two 256-cell pages per
frame at 31 cycles a cell — about 16400 cycles — and rotates through the four
pages, so the screen refreshes top to bottom every two frames while the ramps
keep turning. The four fields no longer turn a spiral; they sweep the same
fixed picture along rows, columns or a diagonal:

| Field | What it looks like |
|---|---|
| A row bands | Wide horizontal bands drift down through the sky and floor together, like the sunset itself cycling colour |
| B column bands | Vertical bands sweep left-right across the grid, like a searchlight scanning the floor |
| C diagonal bands | Tight, fast diagonal bands — a glitchy scanline shimmer |
| D plasma | Unchanged: a non-linear swimming field, organic rather than geometric |

The sequence:

Lengths are in tune ticks (= PAL frames; on NTSC a tick is 6/5 of a frame).

| Phase | Ticks | What happens |
|---|---|---|
| Z | 60 (~1.2s) | Nothing — a black screen while the tune starts. Paints nothing at all; the screen stays black because nothing rewrites it |
| T | 90 (~1.8s) | The title card: the carving lights up while the backdrop is still black, so the name, date and `v1.0` arrive out of nothing — exactly where the flying copy will later land |
| A | 112 (~2.2s) | Wide horizontal bands ripple up *underneath* the lit title, the second band colour joining half way — the sunset assembles around the name rather than replacing it |
| B | 176 (~3.5s) | Vertical column bands sweep the floor grid and accelerate; the logo flies in |
| F | 224 (~4.5s) | The plasma field — the picture swims instead of scanning; the logo keeps flowing |
| C | 112 (~2.2s) | Sprites switch off, the carved logo ignites to chrome, and the tight diagonal field winds up into a fast shimmer |
| D | 24 (~0.5s) | Last burst, then the whole field ramps to white |
| W | 32 (~0.6s) | The white sheet drops as a curtain, top to bottom with a per-column glitch stagger, with raster bars imploding in the side borders alongside it, then the handoff to the balls |

Phase W is the one bitmap phase with room for raster bars, and only just.
`build_wipe_tabs` and `paint_sweep` take 150-162 raster lines and the music has
already carried the frame to around line 20 before either starts, so a slot
anywhere in the **top** half leaves the paint finishing past line 250 —
`intro_sync` then misses its sync and every iteration costs two frames, which
is one music tick per two frames and an audible drag on the tune.

So the slot goes in the **tail**: the buffer is rebuilt before the paint (~35
lines) and displayed after it, from 205 to 248. A light frame leaves the paint
finishing near 180 and the bars get the whole slot; a heavy one starts them
lower and the band is simply shorter. Either way it stops at 248 and the next
`intro_sync` still catches line 250 — measured at 33 PAL frames for the 32
iterations, against 44 when the slot sat at the top.

Only `$d020` is driven — phase W is hi-res bitmap, where `$d021` is not
displayed at all — so what you get is the frame of the picture erupting while
the picture itself is eaten away, with `rb_gsh` squeezing the bars shut in step
with the wipe.

`rb_band`'s "already past the slot" guard has to read the raster's **bit 8**
from `$d011` before it looks at `$d012`. `$d012` is the low eight bits only, so
every line from 256 to 311 reads back as 0-55 and compares *below* the slot —
"still ahead" — when in fact the frame is over and waiting would cost the next
one too.

The logo appears twice and never at the same time. It is lit in the carving for
T and A — the title card, and the sunset rising around it — then phase B puts the
carving out at the same moment the sprite copy lifts off it, so the title reads as
taking flight. Through B and F the carving is a dark, unreadable plate — present
and shaped but not legible — while the sprites fly. Its paper and ink both track
the backdrop's own dark tones (`build_tabs`' `bt_paper`), so the plate blends into
the picture as one more dark patch instead of standing out as a flat black
rectangle or, worse, as a legible ghost copy of the text sitting behind the
sprite. When the carving switches off at the start of C it lights again, so the
logo reads as *landing back* into the bitmap it started from.

The name is carved and packed at scale 2 (16x16 a character); the date and the
`v1.0` label at scale 1 (8x8), so they read as small print under the title. The
carve and the sprite packing have to agree on that or the logo would not land on
itself — `intro_sprites.asm` doubles the name's font rows and leaves the date's
single, `flow_logo_on` X-expands only the name's four sprites, and `x_place`
spaces the date's 24 pixels apart against the name's 48. `v1.0` is carved only:
all eight sprites are spoken for, and a version label has no business flying.

**Why two copies.** A bitmap cannot move; redrawing 8000 bytes is nowhere near a
frame. Sprites are the only thing on this machine that moves for free. So the
logo is built once from glyph rows lifted from the C64 character ROM and emitted
twice — carved into the bitmap by `intro_gfx.asm`, packed into sprites by
`intro_sprites.asm` (3 characters per sprite; the name's font rows are stored
twice and X-expanded to 16x16, the date's are 1:1, 8x8). None of the font reaches the `.prg`; by run time the
letters are already pixels.

The flying copy **opens on the carved position exactly**. Every phase starts at
0, and `x_phase`/`y_phase` are picked so that phase 0 of each sine is the spot
the logo is carved into the bitmap — the name at sprite (88, 187), the date at
(144, 211). The carving goes dark in the same routine that lights the sprites, so
the title does not move by a pixel as one copy hands over to the other; it stops
being bitmap and starts being sprites. That is what `FLOW_Y_BASE` is for: the
original path ran Y 50..192 and could not reach the carved date at all, so the
logo used to teleport up the screen at the handoff. Bitmap `(px, py)` shows at
sprite `(px + 24, py + 51)` if the carve ever moves.

The flight path comes from one 256-entry sine table read with a byte index, so
nothing ever needs clamping: a horizontal **drift** (5.1s) that all four sprites
of a word share so it stays a word, a **bob** (2.6s) that moves it as one body,
and a small per-sprite **ripple** (1s) a quarter period apart along the word so
it undulates. The ripple is the one term that cannot start on the path — no
phase puts all four sprites at zero at once — so `ripple_sh` fades it in over 24
frames rather than letting it snap on at up to 15 pixels. Three periods sharing no common factor, so the path never repeats
in the 8 seconds it is up. The date carries a half-period offset, so the two
words swing against each other and cross.

The music is *Nightshift* by Ari Yliaho (Agemixer), imported from PSID and
driven from a fixed raster line by `music_tick`: every frame on PAL, five frames
in six on NTSC.

### The demo

Multicolor sprites — ray-shaded balls, generated at assembly time — drift
around a black starfield with smooth random motion, 4 to 16 of them at once
(`B` / `SHIFT+B`, default 8). Each ball spins as it moves, faster when it
moves faster and reversing when it turns.

#### Sprite multiplexing: more balls than the VIC has sprites

The VIC-II has exactly 8 hardware sprites, fixed in silicon — there is no
ninth one to enable. Above 8 active balls, a **raster IRQ chain** (`mux_irq`)
reuses those 8 sprites part way down the frame: once a sprite has finished
drawing one ball, it is reprogrammed for another ball further down.

Every frame the main loop steps the physics, **sorts the balls by Y**
(`sort_balls`, an insertion sort — cheap, because the order barely changes
frame to frame), resolves collisions, and then `build_list` turns that one
snapshot into a **write list** for the IRQ:

- entries 0-7 are **band 0**: the eight highest balls on sprites 0-7;
- ball *i* (for *i* ≥ 8) re-uses sprite *i* & 7 — the sprite of the ball
  eight places above it — from the first raster line after that ball has
  been drawn (its Y + 21 lines + 2). If that line is not at least 3 lines
  above ball *i*'s own Y, there is no time to switch the sprite, and the
  ball is left out of that frame (it still moves and collides). Measured at
  16 balls over 600 frames: no skips.

The IRQ chain then runs every frame:

- **line 16** — the top IRQ: `$d011` back to 25 rows, swap in a fresh write
  list if one is ready, write all of band 0. Line 16 is safe on both
  standards: a ball as low as Y 250 is drawn on lines 251-271, which on NTSC's
  263-line frame runs on to line 8 of the next.
- **each re-use line** — one sprite's X, Y, pointer, colour and its own bit of
  `$d010` (read-modify-write, so the other seven are untouched).
- **line 248** — `$d011` to 24 rows: the open border (below).

The write list is **double buffered**: the main loop fills the back half
while the IRQ shows the front half, and the top IRQ only swaps when the main
loop has said the back half is complete. So the main loop's cost only has to
fit a frame, not a gap between two raster lines — and if it ever runs long,
the IRQ simply shows the last complete list again: a repeated frame, never a
torn one.

Collisions reuse the sort as a sweep: instead of testing all `C(n,2)` pairs
(120 at 16 balls), it walks the Y-sorted list and stops comparing a ball
against lower ones the moment their Y gap reaches the touch radius. Each frame
it walks only every other outer position, so a pair is tested every second
frame — invisible at ≤2.5 px a frame against a 20 px contact zone.

The other big saving is the **velocity cache**: the speed-scaled velocity
(`ScaleVel`, ~300 cycles a call, twice per ball) used to be recomputed for
every ball every frame. It is now stored per ball and only recomputed while a
ball eases up to speed, and a few balls a frame after the speed level changes;
a bounce just negates it along with the base velocity.

Measured on NTSC (VICE `x64sc -ntsc`, 600 frames, balls at speed), out of a
17095-cycle frame:

| Balls | Average | Worst | Late frames |
|---|---|---|---|
| 8 | ~5000 | ~6100 | 0 |
| 12 | ~8400 | ~10600 | 0 |
| 16 | ~12600 | ~14400 | 0 |

Ball *state* doesn't fit in zero page at 16 balls (24 tables x 16 is 384
bytes, more than all of `$02-$FF`), so it lives in ordinary RAM at `$8400`
(`BALL_STATE`). Indexed table access costs the same off zero page (`lda
table,x` is 4 cycles either way, and no table crosses a page). It must **not**
share memory with the intro's wave fields: those are assembled-in data, and
`R` replays the intro from them — an earlier version put the ball tables on
top of wave A and garbled the top of every intro after the first.

Everything moves in **8.8 fixed point**, one byte of whole pixels and one of
1/256ths, so a ball can travel at 0.3 px/frame and still look smooth. X needs 9
bits, so it is carried as `x_msb : x_lo : x_frac`.

Each ball gets one random heading at startup and keeps it. Only two things ever
change direction: reaching an edge (that axis reflects) or touching another ball
(they push apart and swap colours). A bell-like SID ping fires on every bounce —
low for a wall, higher and randomly pitched for a ball-to-ball hit — and a
ball-to-ball hit also throws an ASCII spark onto the text screen at the point of
contact.

Stored velocities are *base* velocities, scaled by the global speed level
(`effective = base * speed / 8`, cached per ball — see above), so changing speed
never disturbs the headings or the bounces.

#### The open border

The balls are not confined to the 25-row text window. Every frame the IRQ
switches `$d011` to 24 rows *on line 248* — after line 247, where the VIC
would raise its vertical border flip-flop with 24 rows, and before 251, where
it would with 25 — so the flip-flop is never set and the sprites carry on
through the bottom border and the next frame's top one. The top IRQ at line 16
switches back to 25 rows, ready for the next frame.

The playfield is therefore **X 22..322, Y 56..250**. The status bar stays on text
row 24 because the opened border can only display sprites, not characters — so
row 24 is the lowest line the VIC can put text on, and the balls simply fly over
it and on down past it.

`MIN_Y` is 56 rather than 0 for a hardware reason on PAL: a sprite triggers when
the low 8 bits of the raster match its Y, and PAL lines 256–311 repeat the low
bytes 0–55 (NTSC's 256–262 only repeat 0–6; one limit keeps both the same). With the bottom border open those lines are visible, so a ball at Y < 56 is
drawn a second time as a ghost near the bottom of the screen. Confirmed in VICE —
at `MIN_Y` 20 the top ball has a visible twin, at 56 it does not.

The **side** borders are still closed, so X cannot be widened: a sprite outside
the 24..343 window is clipped rather than drawn. Opening them needs a cycle-exact
`$d016` write on every raster line — a stable-raster effect that would eat most
of an NTSC frame's 17095 cycles, which does not fit next to this much physics.

---

## Files

| File | Contents |
|---|---|
| `main.asm` | The demo: registers, zero page, video standard detection, main loop, multiplexer IRQ, physics, collisions, sparks, sound, status bar |
| `sprite_gen.asm` | Assembly-time ball frames (8) |
| `intro.asm` | The opening sequence: phases, sweep, palette and glint tables, sprite flow |
| `intro_gfx.asm` | The retro sunset-grid bitmap with the logo carved in, plus the cell fields |
| `intro_sprites.asm` | The flying logo sprites and the sine table |
| `intro_text.asm` | Glyph rows for the name, date and `v1.0`, lifted from the C64 character ROM |
| `intro_raster.asm` | The raster bar overture and the border bars over the closing wipe |
| `music.asm` | PSID import of `Nightshift.sid` |
| `Nightshift.sid` | The intro tune |

None of the `intro_*` files or `sprite_gen.asm` assemble on their own — they are
`#import`ed into `main.asm` and depend on its labels. Only `intro.asm` lands
inside Main Code; the others set their own `* =` segments.

---

## Memory layout

```
$0002-$0014  zero page: the intro's variables, ntsc, music_div, beat_hold
$007a-$00ad  zero page: the demo's globals, sort scratch, the IRQ's state
$00f8-$00f9  zero page: Nightshift's player (traced - nothing else)
$0314-$0315  IRQ vector -> mux_irq (demo only)
$0318-$0319  NMI vector -> nmi_ignore
$0400-$07e7  text screen: stars, status rows 23-24 (sprite pointers at $07f8)
$0801        BASIC stub "10 SYS 8768" (8768 = $2240)
$0900-$0a0b  raster bar line buffer: one colour per raster line
$1000-$1d77  Nightshift.sid - player and data at its own load address
$2000-$21ff  8 ball frames, 64 bytes each   (VIC blocks $80-$87)
             shared by all the balls; each ball's pointer picks its
             own current frame
$2240-$3fff  code and data tables (Main Code, ends ~$34c0)
$3fff        VIC idle fetch - displayed in the opened border, zeroed at
             start-up
$4000-$5f3f  intro bitmap      (VIC bank 1, 8000 bytes)
$6000-$63e7  intro video matrix (VIC bank 1, filled at run time)
$63f8-$63ff  intro sprite pointers (VIC bank 1)
$6400-$65ff  intro logo sprites (VIC bank 1, 8 x 64 bytes)
$6600-$66ff  intro sine table   (CPU only)
$6700-$6ae7  intro wipe field   (CPU only)
$6b00-$73ff  intro_raster.asm's code and data (CPU only, ends ~$71b2)
$7400-$83e7  intro wave fields A-D (4 x 1000 at $400 spacing, CPU only)
$8400-$857f  BALL_STATE: 24 per-ball tables x 16 balls
$8600-$873f  the multiplexer's double-buffered write list
```

`intro_raster.asm` lives up in bank 1's spare RAM because Main Code ran out of
room for it. It is code, not graphics, and the VIC is never pointed at it. The
wave fields, `BALL_STATE` and the write list are CPU-only too, so they sit past
the end of bank 1 (`$8000+` is plain RAM: no cartridge maps ROM there). Overlaps
between them are `.errorif` build errors.

**The code segment starts at `$2240`, not the usual `$0810`.** A PSID player is
not relocatable and Nightshift loads at `$1000-$1d77`, so the code has to start
above it.

The intro runs in **VIC bank 1** (bitmap `$4000`, video matrix `$6000`, its own
sprites `$6400`) and hands over to **bank 0** text mode for the demo. The two
sprite sets never collide: the demo's live in bank 0 at `$2000`, the intro's in
bank 1.

### Zero page

```
$02-$11  the intro's variables
$12-$14  ntsc, music_div, beat_hold - shared by intro and demo
$7a-$9f  the demo's globals (RNG, timers, scratch, speed, keyboard, ball
         count, sort and collision scratch)
$a0-$ad  the multiplexer IRQ's state and build_list's scratch
```

The per-ball tables used to live at `$02-$79`, one 8-byte row each — that was
the ceiling zero page could hold. They moved to ordinary RAM (`BALL_STATE`) to
make room for up to 16 balls; see **Sprite multiplexing** above. `ptr` (`$84`)
has to stay in zero page — `(ptr),y` indirect indexed addressing has no
absolute-memory form on the 6502.

**The intro's variables share `temp`/`temp2` with the demo.** `play_intro` runs
to completion before `init_sprites` writes a single byte of demo state, so the
two are never live at the same time. One consequence worth remembering: nothing
the demo needs may be written *before* `play_intro` — `speed`, `key_timer`,
`swap_cool` and the spark slots are set after it returns for exactly this
reason.

Nightshift's player touches only `$f8/$f9` (traced from its init and play
entries), so it collides with neither block. Re-check if the tune is swapped.

---

## Things that are load-bearing

Worth knowing before editing:

- **`vmtab` alignment.** `.align $20` keeps the 32-byte table on one page;
  `paint_sweep` reads it with `lda abs,y` 512 times a frame and a page cross
  there costs ~200 cycles a frame.
- **The sweep stops at `$63e7`**, sixteen bytes short of the sprite pointers at
  `$63f8`. Extending it would overwrite them.
- **The logo's two copies are never lit at once.** `set_text_ramp` has exactly
  two ramps — off and hot — because through A, B and F the flying sprite copy is
  on screen and lighting the carving at the same time would put two logos up,
  which is the one thing the two-copy design exists to avoid. A half-lit ramp
  was removed for this reason; do not add one back without moving the sprites
  out of the way first.
- **`$3fff` must stay zero.** With the vertical border open the VIC spends the
  border lines idle, displaying the last byte of the bank rather than the
  screen. Leave junk there and it tiles the whole opened border.
- **The `$d011` writes in `mux_irq` are a pair.** The 24-row write has to land
  in lines 248-250 and the 25-row write anywhere from 252 to 246 of the next
  frame (the top IRQ does it at 16). `mux_irq` checks the bottom line before it
  applies any sprite entries, so a pile of entries cannot push it past 250.
- **Nothing of the demo's may overlap the intro's wave fields.** They are
  assembled-in data that `R` replays. `.errorif` guards the layout.
- **The main loop never writes a sprite register.** Everything goes through
  `build_list` and the IRQ; a direct write would be overwritten mid-frame, or
  worse, land between a band-0 write and a re-use.
- **Every frame-locked music call goes through `music_tick`, and every intro
  duration counter through `BeatDec`.** Calling `MUSIC_PLAY` directly makes
  the tune 20% fast on NTSC; a plain `dec` on a phase counter drifts the
  phase off the beat.
- **Phase D is the tightest frame in the intro.** `flash_field` is ~7200
  cycles (the comment in `intro.asm` and an older 13056 figure disagree; not
  re-measured). An overrun is benign — `intro_sync` misses line 250 and waits a
  frame, so the white-out stutters rather than breaking.

---

## Verification status

Everything here is VICE (`x64sc`), NTSC first and PAL second; nothing has been
run on real hardware yet.

Measured in VICE on NTSC: the demo's frame budget at 8, 12 and 16 balls (table
above), the overture's off-screen work (one late frame in the whole overture —
the first, which is black anyway), and whole-sequence screenshots on both
standards showing the same phase at the same wall-clock time. The open border
and the `MIN_Y` ghost threshold were verified visually on PAL.

Not verified: real hardware; the `B` key and `R` restart with a real keypress
(both traced in code, and the restart corruption they used to cause was seen in
VICE and is fixed by moving `BALL_STATE`); the 7-cycle polling loop of the
overture on NTSC, where 65 is not a multiple of 7 and the bar edges may show
more slivers than the 8.5% measured on PAL.

### Review, 2026-10-04

A four-agent `c64-reviewer` pass over the whole demo found, and this round
fixed:

- `B` could only ever lower the ball count — plain `B` was never read, so the
  multiplexer was unreachable from the keyboard.
- The polled two-band multiplexer ran at half frame rate above 8 balls (measured
  ~39000 cycles a pass at 16), flickered whole bands, tore balls at the band
  hand-over and in the open bottom border, and published the two bands from
  different snapshots. Replaced by the IRQ multiplexer and velocity cache above.
- `check_collisions` lost its Y-pruning reference to `check_pair`'s scratch, so
  most pairs were never tested, even at 8 balls.
- Lowering the ball count froze one ball and hid another (`ball_order` was not
  reset).
- A collision low on the screen computed text row 25-26 and read past the row
  table — a spark could be written into code, SID or CIA registers.
- `R` replayed the intro over ball state sitting on its wave field A.
- The first demo frame drew sprites from zero page (`ball_ptr` uninitialised).
- The flying logo started one raster line below its carving; the overture's
  labels snapped off after the flash; phase C cut the sprites mid-band; the "1"
  in `v1.0` had two rows swapped.
- NTSC: the overture's work overran into the bar band on ~half its frames, and
  the PAL tune played 20% fast.

Known and not fixed: the floor is not really a checkerboard (its tiles are so
wide the lower floor is two halves), a one-cell hole in the `v1.0` plate, the
sun's aspect ratio, and the overture still says "ONE RASTER".

### Earlier review

An earlier `c64-reviewer` pass found seven defects, **all fixed**: `RUN/STOP+RESTORE`
was not actually blocked (RESTORE reaches `/NMI` directly and cannot be masked
via `$dd0d`, so `$0318` now points at an `rti`); the border was left white for
the whole closing wipe; `INTRO_SPR_PTR` was computed bank-absolute and only
worked because the assembler truncated the immediate; the sprite pointers were
not initialised before the first displayed frame; `INTRO_WAVE_C` was generated
but never selected, so phase C inherited phase F's plasma; the `text_dim` ramp
was unreachable and has been removed; and the RNG was seeded from the jiffy
clock, which cannot advance with interrupts off.
