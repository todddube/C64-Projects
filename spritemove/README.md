# spritemove

A Commodore 64 demo in 6502 assembly: a raster bar overture, a hi-res bitmap
intro with a carved and flying logo, then eight shaded balls drifting around a
starfield with collision sparks and SID ping effects, using the full height of
the screen — the vertical border is held open, so the balls fly into it.

Written for **KickAssembler v5.25**, tested in **VICE x64sc** (PAL), targeted at
an **Ultimate II+** cartridge.

---

## Build and run

```bash
# Build. Four lines are expected: three from music.asm's .print (the tune's
# name and its load/init/play addresses) and "Writing prg file: main.prg".
java -jar /Applications/KickAssembler/KickAss.jar main.asm -odir bin

# Run
/Applications/vice-arm64-gtk3/bin/x64sc -autostart bin/main.prg
```

Output is `bin/main.prg`, about 25 KB. The repo's `/build` and `/run` slash
commands do both steps.

To *see* a particular moment without watching in real time, let VICE run a fixed
number of cycles in warp and screenshot on the way out:

```bash
/Applications/vice-arm64-gtk3/bin/x64sc -autostart bin/main.prg \
    -warp -limitcycles 12000000 -exitscreenshot /tmp/shot.png
```

Autostart costs roughly 3.2M cycles before the intro's first frame (measured;
it grows with the `.prg`), and PAL runs 985248 cycles a second. The overture is
450 frames and the bitmap intro 830, so the balls appear around 28M.

**Pass `-pal`.** A `vicerc` with `MachineVideoStandard=2` makes `x64sc` default
to NTSC, where a line is 65 cycles over 263 raster lines — the off-screen window
the overture budgets against shrinks from 117 lines to 68 and none of the cycle
counts in `intro_raster.asm` hold. This demo is a PAL demo; measure it as one.

Note that `-limitcycles` stops the emulator wherever it lands, which is usually
part way down a frame — the screenshot is then the part of that frame drawn so
far, with the rest black. To get whole frames, find one cycle count that lands
in the vertical blank and step from it in multiples of 19656 (a PAL frame).

---

## Controls

| Key | Action |
|---|---|
| `+` / `-` or `CRSR` | Speed level, 1-16 (default 4 = half base speed) |
| `R` | Restart from the very top of the intro |
| `Q` or `RUN/STOP` | End the demo, back to a `READY.` prompt |

The bottom **two** text rows are the menu — a fixed legend of the keys on row 23,
and the speed bar plus the exit key on row 24:

```
SPEED +/- OR CRSR    R=RESTART  Q=QUIT
SPD[####............] RUN/STOP=END
```

`R` works during the intro as well as during the demo, because it is scanned in
`check_exit`, which both the intro loop and the main loop call every frame. It
silences the SID, hides the sprites, waits for the key to come back up (otherwise
holding it would restart on every frame and freeze on the intro's first black
frame) and jumps to `start`. `start` resets the stack pointer for exactly this
reason — the jump comes from several `jsr`s deep, so without it every restart
would strand a return address and the stack would eventually wrap into zero page.

`Q` and `RUN/STOP` share keyboard row `$7f` — bits 6 and 7 — so one matrix read
tests both.

`RUN/STOP` does not return to BASIC — the demo has overwritten BASIC's zero
page, so there is nothing sane to return to. It silences the SID, clears the
sprites and jumps through the KERNAL reset vector at `$fffc`, which gives a
normal `READY.` prompt. `RUN/STOP+RESTORE` is defused at startup by masking
CIA2's NMI, because `sei` does not mask NMI and a warm start would land on the
same trashed zero page.

---

## What it does

### The overture (~9 seconds)

Before the bitmap intro there is a raster bar sequence in plain text mode:
eight colour bars flying over a black screen while the handle and five labels
fade up one at a time. See `intro_raster.asm`.

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

The script runs eight steps of them, opening on an explosion out of a single
line and closing on the implosion back into one, so the overture is bracketed
by the same move played both ways. It ends on a white strobe that the labels
vanish into, and hands over to the bitmap intro on a black screen.

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

A hi-res bitmap **retro sunset grid** — sky bands, a perspective checkerboard
floor and a striped badge sun on the horizon between them — generated at
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
- **floor** (below the horizon) — a perspective checkerboard: screen X is
  divided by depth before it is tiled, so the squares narrow toward the
  horizon the way a real floor recedes, and a fog term dithers the near tiles
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
cell rather than a redraw. `paint_sweep` recolours one 256-cell page per
frame at 31 cycles a cell — about 8200 cycles — and rotates through the four
pages, so the screen refreshes top to bottom every four frames while the ramps
keep turning. The four fields no longer turn a spiral; they sweep the same
fixed picture along rows, columns or a diagonal:

| Field | What it looks like |
|---|---|
| A row bands | Wide horizontal bands drift down through the sky and floor together, like the sunset itself cycling colour |
| B column bands | Vertical bands sweep left-right across the grid, like a searchlight scanning the floor |
| C diagonal bands | Tight, fast diagonal bands — a glitchy scanline shimmer |
| D plasma | Unchanged: a non-linear swimming field, organic rather than geometric |

The sequence:

| Phase | Frames | What happens |
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
`intro_sprites.asm` (3 characters per sprite, every font row stored twice,
X-expanded to 16x16). None of the font reaches the `.prg`; by run time the
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
driven one tick per frame at a fixed raster line.

### The demo

Eight multicolor sprites — ray-shaded balls, generated at assembly time — drift
around a black starfield with smooth random motion. Each ball spins as it moves,
faster when it moves faster and reversing when it turns.

Eight is not a round number picked for looks: it is every sprite the VIC-II has,
and it is also exactly what zero page will hold. Fifteen per-ball tables at 8
bytes each is 120 bytes, `$02-$79`, leaving `$7a-$94` for all global state.
There is no room for a ninth ball, and none for a second table per ball — which
is why the ghost trails that used to occupy sprites 4-7 are gone.

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

#### The open border

The balls are not confined to the 25-row text window. Every frame the main loop
switches `$d011` to 24 rows *on line 250* — the last line before the VIC would
raise its vertical border flip-flop — so the flip-flop is never set and the
sprites carry on through the bottom border and the next frame's top one. It
switches back to 25 rows after the frame's work, by which point the raster is
thousands of cycles past 251. No IRQ; it rides the raster sync the loop already
had.

The playfield is therefore **X 22..322, Y 56..250**. The status bar stays on text
row 24 because the opened border can only display sprites, not characters — so
row 24 is the lowest line the VIC can put text on, and the balls simply fly over
it and on down past it.

`MIN_Y` is 56 rather than 0 for a hardware reason: a sprite triggers when the low
8 bits of the raster match its Y, and PAL lines 256–311 repeat the low bytes
0–55. With the bottom border open those lines are visible, so a ball at Y < 56 is
drawn a second time as a ghost near the bottom of the screen. Confirmed in VICE —
at `MIN_Y` 20 the top ball has a visible twin, at 56 it does not.

The **side** borders are still closed, so X cannot be widened: a sprite outside
the 24..343 window is clipped rather than drawn. Opening them needs a cycle-exact
`$d016` write on every raster line — a stable-raster IRQ costing roughly 12600 of
a PAL frame's 19656 cycles, which does not fit next to this much physics.

---

## Files

| File | Contents |
|---|---|
| `main.asm` | The demo: registers, zero page, main loop, physics, collisions, trails, sparks, sound, status bar |
| `sprite_gen.asm` | Assembly-time ball frames (8) |
| `intro.asm` | The opening sequence: phases, sweep, palette and glint tables, sprite flow |
| `intro_gfx.asm` | The spiral bitmap with the logo carved in, plus the cell fields |
| `intro_sprites.asm` | The flying logo sprites and the sine table |
| `intro_text.asm` | Glyph rows for the name, date and `v1.0`, lifted from the C64 character ROM |
| `intro_raster.asm` | The raster bar overture and the border bars over the closing wipe |
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
$0900-$09ff  raster bar line buffer: one colour per raster line
$3fff        VIC idle fetch - displayed in the opened border, zeroed at
             start-up
$1000-$1d77  Nightshift.sid - player and data at its own load address
$2000-$21ff  8 ball frames, 64 bytes each   (VIC blocks $80-$87)
             shared by all eight balls; each ball's pointer picks its
             own current frame
$2240-...    code and data tables
$3000-$33e7  intro text mask   (1000 cell glint values, CPU only)
$3400-$3fe7  intro wave fields (3 x 1000 cell values, CPU only)
$4000-$5f3f  intro bitmap      (VIC bank 1, 8000 bytes)
$6000-$63e7  intro video matrix (VIC bank 1, filled at run time)
$63f8-$63ff  intro sprite pointers (VIC bank 1)
$6400-$65ff  intro logo sprites (VIC bank 1, 8 x 64 bytes)
$6600-$66ff  intro sine table   (CPU only)
$6700-$6ae7  intro wipe field   (CPU only)
$6b00-...    intro_raster.asm's code and data (CPU only)
```

`intro_raster.asm` lives up in bank 1's spare RAM because the Main Code segment
has no room for it — `$2240-$2f1d` leaves 226 bytes before the cell fields at
`$3000`. It is code, not graphics, and the VIC is never pointed at it.

**The code segment starts at `$2240`, not the usual `$0810`.** A PSID player is
not relocatable and Nightshift loads at `$1000-$1d77`, so the code has to start
above it.

The intro runs in **VIC bank 1** (bitmap `$4000`, video matrix `$6000`, its own
sprites `$6400`) and hands over to **bank 0** text mode for the demo. The two
sprite sets never collide: the demo's live in bank 0 at `$2000`, the intro's in
bank 1.

### Zero page

```
$02-$79  per-ball tables (15 tables x 8 bytes)
$7a-$94  global state (RNG, timers, scratch, speed, keyboard)
```

**The intro's variables deliberately overlap the ball tables** at `$02-$0f`.
`play_intro` runs to completion before `init_sprites` writes a single ball byte,
so the two are never live at the same time. This is what makes eight balls fit
at all. It has one consequence worth remembering: nothing the demo needs may be
written *before* `play_intro` — `speed`, `key_timer` and `swap_cool` are set
after it returns for exactly this reason.

The intro's variables are kept below `$8f` because that is the range the SID
player was checked against. The demo's globals may sit above it, because by then
the player has been silenced.

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
- **The logo's two copies are never lit at once.** `set_text_ramp` has exactly
  two ramps — off and hot — because through A, B and F the flying sprite copy is
  on screen and lighting the carving at the same time would put two logos up,
  which is the one thing the two-copy design exists to avoid. A half-lit ramp
  was removed for this reason; do not add one back without moving the sprites
  out of the way first.
- **`$3fff` must stay zero.** With the vertical border open the VIC spends the
  border lines idle, displaying the last byte of the bank rather than the
  screen. Leave junk there and it tiles the whole opened border.
- **The `$d011` writes in `main_loop` are a pair.** The 24-row write has to land
  on line 250 and the 25-row write has to land after 251. Inserting work between
  the raster sync and the first write, or cutting the frame's work down to almost
  nothing, breaks the border open/closed either way.
- **Phase D is the tightest frame in the intro.** `flash_field` is 13056 cycles,
  leaving the music player ~5400 of a PAL frame and ~2900 of an NTSC one. An
  overrun is benign — `intro_sync` misses line 250 and waits a frame, so the
  white-out stutters rather than breaking.

---

## Verification status

PAL timing was measured in VICE; the intro's per-frame budget and the zero page
and memory layout have been checked against the hardware references in
`.claude/c64-reference/`. A `c64-reviewer` pass has since measured the intro on
**both** PAL and NTSC (680 frames, zero dropped frames on either) and confirmed
the bank/`$d018` mapping, the `intro_to_text` restore order and the exit path
against the actual KERNAL ROM image.

The open border was verified visually in VICE: a scratch build with a red border
shows top and bottom black through to the screen edge with the side borders still
red, and the `MIN_Y` ghost threshold was found by testing rather than reasoning.

Not verified: real hardware (everything here is VICE), `RUN/STOP` pressed
*during* the intro with a real keypress, the cycle budget with the eight flying
sprites stealing DMA during phases B and F, and whether Nightshift's own zero
page use really does stay clear of the intro's `$02-$10` — that one is
empirical, from the intro rendering correctly, not from a disassembly.

A `c64-reviewer` pass found seven defects, **all now fixed**: `RUN/STOP+RESTORE`
was not actually blocked (RESTORE reaches `/NMI` directly and cannot be masked
via `$dd0d`, so `$0318` now points at an `rti`); the border was left white for
the whole closing wipe; `INTRO_SPR_PTR` was computed bank-absolute and only
worked because the assembler truncated the immediate; the sprite pointers were
not initialised before the first displayed frame; `INTRO_WAVE_C` was generated
but never selected, so phase C inherited phase F's plasma; the `text_dim` ramp
was unreachable and has been removed; and the RNG was seeded from the jiffy
clock, which cannot advance with interrupts off.
