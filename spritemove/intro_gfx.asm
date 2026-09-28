//==================================================================
// INTRO_GFX - the intro's hi-res bitmap and its four cell fields,
// all generated at assembly time
//
// Imported by main.asm; not buildable on its own. Pure data generation.
//
// HI-RES, NOT MULTICOLOR
// ----------------------
// 320 x 200, one bit per pixel - double the horizontal resolution of
// multicolor mode, at the price of two colors per 8x8 cell instead of
// four. Both come from the video matrix byte:
//
//     bit 1  ->  video matrix HIGH nibble   (the "ink")
//     bit 0  ->  video matrix LOW  nibble   (the "paper")
//
// Color RAM is not used by this mode at all, and $d021 is not either, so
// unlike multicolor there is no global color to work around: every cell
// is a free two-color pair. That also makes the animation cheaper - one
// byte per cell instead of two - which is why paint_sweep can afford two
// pages a frame here where it could only manage one before.
//
// GETTING SHADING OUT OF TWO COLORS: DITHERING
// --------------------------------------------
// The pattern below is computed as a continuous intensity 0..1 and then
// thresholded against a 4x4 ordered (Bayer) matrix. Where the intensity
// is near 0 or 1 the result is solid paper or solid ink; in between it
// breaks into a regular dot pattern whose density tracks the intensity.
// At 320 pixels those dots are small enough to read as shading, so a
// two-color cell shows an apparent gradient between its two colors. This
// is what stops a hi-res picture looking flat.
//
// WHAT THE PATTERN IS - A RETRO SUNSET GRID, NOT A TUNNEL
// ---------------------------------------------------------
// The picture used to be a polar spiral tunnel: every pixel's shape came
// from its distance and angle to the screen centre. This is the opposite
// shape - built entirely from ROWS and COLUMNS, on purpose, so nothing
// in it reads as concentric or rotating:
//
//   sky    py < HORIZON_Y - flat horizontal sunset bands, the height of
//          a stripe warped very slightly by two hoisted sine tables so
//          the edges breathe instead of ruling dead straight, plus a
//          per-band HASH jitter that nudges each stripe's edge a little
//          early or late - the "random raster lines" texture: real 8-bit
//          hardware scanlines are never perfectly even, and this bakes
//          that unevenness into the picture on purpose
//   floor  py >= HORIZON_Y - a perspective checkerboard, the classic
//          Out Run floor: screen X is divided by depth before it is
//          tiled, so the squares narrow toward the horizon exactly the
//          way a real floor recedes, and a FOG term dithers the near
//          tiles crisp and the far ones toward grey static so the
//          horizon disappears into haze rather than snapping off
//   sun    a plain circle sat on the horizon, cut by horizontal stripes
//          that widen toward the bottom (spacing grows with sqrt of the
//          distance from the top of the disc) - the sunset-badge sun
//          every 80s cover uses. It is the only round thing on screen,
//          it does not rotate, and it is drawn with a squared-distance
//          test rather than sqrt/atan2 - there is no angle anywhere in
//          this file any more
//
// The logo sits in the lower third exactly as before: logo_cell forces
// those cells to text_px and NOTHING ELSE, so the sun and the grid are
// simply masked out under the letters regardless of where they overlap -
// the picture underneath never has to know the logo is there.
//==================================================================

#import "intro_text.asm"

//------------------------------------------------------------------
// near_text draws the knockout outline one pixel to each side of a
// glyph. That only works while every lit pixel is inside bits 6..1 of its
// font row: a pixel in bit 7 or bit 0 sits hard against the character
// cell edge, and its outline would fall in the neighbouring character
// where the next glyph may already have claimed it. Every glyph in the
// C64 font used here satisfies that, but nothing enforces it, so the
// build checks rather than trusts - a future glyph that breaks it would
// otherwise just quietly lose one side of its outline.
//------------------------------------------------------------------
.for (var i = 0; i < NAME_ROWS.size(); i++) {
    .errorif (NAME_ROWS.get(i) & $81) != 0, "Name glyph uses bit 7 or bit 0 - near_text cannot outline it"
}
.for (var i = 0; i < DATE_ROWS.size(); i++) {
    .errorif (DATE_ROWS.get(i) & $81) != 0, "Date glyph uses bit 7 or bit 0 - near_text cannot outline it"
}
.for (var i = 0; i < VER_ROWS.size(); i++) {
    .errorif (VER_ROWS.get(i) & $81) != 0, "Version glyph uses bit 7 or bit 0 - near_text cannot outline it"
}

.const CENTER_PX = 160.0        // 320 pixels across
.const ASPECT    = 1.2          // a hi-res pixel is ~1.2x taller than wide
                                 // on a 4:3 screen, so the sun needs dy
                                 // scaled by this to come out round

.const HORIZON_Y   = 92.0       // sky above this line, floor grid below it
.const BAND_H      = 15.0       // sunset stripe height in the sky, pixels.
                                 // Wide and calm on purpose: this is the
                                 // backdrop the flying logo sprites travel
                                 // over (see intro.asm flow_sprites), and
                                 // a thin, busy stripe pattern there was
                                 // fighting the sprite text for attention
                                 // instead of sitting behind it
.const GRID_SPACING = 32.0      // world-space width of one floor tile,
                                 // same reasoning: big calm tiles instead
                                 // of a dense checkerboard
.const FLOOR_K     = 620.0      // perspective strength: bigger = steeper
                                 // recession, the tiles narrow faster
.const FOG_Z       = 44.0       // depth (px below the horizon) at which
                                 // the floor stops dithering into fog and
                                 // reads as crisp tiles

.const SUN_CY        = HORIZON_Y  // the sun sits centred on the horizon
.const SUN_R          = 40.0      // its radius
.const SUN_STRIPE_K   = 0.60      // how fast the cut stripes widen going
                                   // down the disc (spacing grows with
                                   // sqrt of distance from the top)

// The logo, in the lower third, clear of the grid's busiest tiles. Each
// string carries its own scale in bitmap pixels per font pixel, so the
// name reads as the title and the date and version sit under it as small
// print:
//
//   name    scale 2  -> 16 x 16 a character
//   date    scale 1  ->  8 x  8 a character
//   v1.0    scale 1  ->  8 x  8 a character
//
// The sprite copy has to agree with this: intro_sprites.asm doubles the
// name's rows and leaves the date's single, and flow_logo_on X-expands
// only the name's four sprites.
.const NAME_SCALE = 2
.const DATE_SCALE = 1
.const VER_SCALE  = 1

.const NAME_X = (320 - NAME_CHARS * 8 * NAME_SCALE) / 2     // = 64
.const NAME_Y = 136
.const DATE_X = (320 - DATE_CHARS * 8 * DATE_SCALE) / 2     // = 120
.const DATE_Y = 160
.const VER_X  = (320 - VER_CHARS  * 8 * VER_SCALE)  / 2     // = 144
.const VER_Y  = 172

//------------------------------------------------------------------
// Hoisted sine tables, so the sky and floor warps cost one table lookup
// a pixel instead of a sin() call. SIN_PX and SIN_PD only depend on px
// and px+py - used to make the sunset stripes breathe instead of ruling
// dead straight. SIN_PY only depends on py - used as a gentle per-row
// "heat haze" wobble in the floor grid.
//------------------------------------------------------------------
.var SIN_PX = List()
.for (var i = 0; i < 320; i++) { .eval SIN_PX.add(sin(i * 0.075)) }
.var SIN_PY = List()
.for (var i = 0; i < 200; i++) { .eval SIN_PY.add(sin(i * 0.070)) }
.var SIN_PD = List()
.for (var i = 0; i < 520; i++) { .eval SIN_PD.add(sin(i * 0.045)) }

// 4x4 ordered dither. Reading (py&3, px&3) out of this and comparing
// against the intensity is the whole of the shading.
.var BAYER = List().add( 0,  8,  2, 10,
                        12,  4, 14,  6,
                         3, 11,  1,  9,
                        15,  7, 13,  5)

//------------------------------------------------------------------
// tri - triangle wave, period 1, rising 0..1 then falling 1..0. Used for
// the sunset bands because its straight flanks give a stripe a crisper
// edge once dithered than a sine would.
//------------------------------------------------------------------
.function tri(v) {
    .var f = v - floor(v)
    .if (f > 0.5) { .return 2 - 2 * f }
    .return 2 * f
}

//------------------------------------------------------------------
// hash01 - a deterministic pseudo-random value in [0, 1) from an integer
// index. The classic "scrambled sine" hash: multiply a sine by a large
// irrational-ish constant and keep only the fractional part, which walks
// all over [0, 1) for consecutive integer n with no visible period at
// the scale this is used at.
//
// It is deterministic, not random - the same n always hashes to the same
// value, on every build. That is exactly what is wanted here: the point
// is to make each stripe's edge or each wipe cell's timing look
// irregular to the EYE, not to differ from run to run (KickAssembler has
// no runtime randomness to offer anyway, this all happens at build time).
//------------------------------------------------------------------
.function hash01(n) {
    .var s = sin(n * 12.9898 + 78.233) * 43758.5453
    .return s - floor(s)
}

//------------------------------------------------------------------
// glyph_px / near_text / text_px - the logo, in hi-res coordinates.
// `sc` is bitmap pixels per font pixel, so a character is 8*sc wide and
// 8*sc tall and sc = 1 is the font's own size.
//------------------------------------------------------------------
.function glyph_px(px, py, rows, x, y, n, sc) {
    .if (py < y || py >= y + 8 * sc) { .return 0 }
    .if (px < x || px >= x + n * 8 * sc) { .return 0 }
    .var ci  = floor((px - x) / (8 * sc))
    .var bit = floor(mod(px - x, 8 * sc) / sc)
    .var row = floor((py - y) / sc)
    .if ((rows.get(ci * 8 + row) & (128 >> bit)) != 0) { .return 1 }
    .return 0
}

.function text_px(px, py) {
    .if (glyph_px(px, py, NAME_ROWS, NAME_X, NAME_Y, NAME_CHARS, NAME_SCALE) != 0) { .return 1 }
    .if (glyph_px(px, py, DATE_ROWS, DATE_X, DATE_Y, DATE_CHARS, DATE_SCALE) != 0) { .return 1 }
    .if (glyph_px(px, py, VER_ROWS,  VER_X,  VER_Y,  VER_CHARS,  VER_SCALE)  != 0) { .return 1 }
    .return 0
}

//------------------------------------------------------------------
// logo_cell - does character cell (ccol, crow) contain any logo pixel?
//
// Cells that do are handled completely differently from the rest: the
// backdrop is cleared out of them entirely and their color pair comes
// from the logo's own ramp (see the +16 in cell_glint below). That is
// what gives the letters an independent color in a mode with no color
// RAM - the separation is per cell rather than per bit pair. The letters
// end up sitting on a chunky, letter-shaped plate cut out of the picture,
// whatever that picture is doing underneath.
//------------------------------------------------------------------
.function logo_cell(ccol, crow) {
    .for (var k = 0; k < 8; k++) {
        .for (var q = 0; q < 8; q++) {
            .if (text_px(ccol * 8 + q, crow * 8 + k) != 0) { .return 1 }
        }
    }
    .return 0
}

//------------------------------------------------------------------
// sky_px - the sunset bands above the horizon.
//
// A plain triangle wave in py would rule dead straight stripes; SIN_PX
// and SIN_PD warp the band boundary sideways by a few pixels so the
// edges breathe, and hash01 then nudges each whole STRIPE's phase by up
// to +/-0.65 of a band - large enough to see, small enough that it reads
// as an unstable scanline rather than as noise. That second part is the
// "random raster lines" texture: real CRT scanlines are never perfectly
// even, and this bakes a little of that unevenness in on purpose.
//------------------------------------------------------------------
.function sky_px(px, py) {
    .var warp = 0.6 * (SIN_PX.get(px) + SIN_PD.get(mod(px + py, 520)))
    .var band = (py + warp) / BAND_H
    .var bi = floor(band)
    .var jitter = (hash01(bi) - 0.5) * 0.5   // a light unsteadiness, not a
                                              // ragged edge - see BAND_H
    .var inten = tri(band + jitter)

    // push toward the ends of the range, same reasoning as the old
    // spiral: most of the sky should be solid ink or solid paper, with
    // dithering confined to the band edges where it reads as a soft
    // gradient rather than as static
    .eval inten = (inten - 0.5) * 2.0 + 0.5
    .if (inten < 0) { .eval inten = 0 }
    .if (inten > 1) { .eval inten = 1 }
    .return inten
}

//------------------------------------------------------------------
// floor_px - the perspective checkerboard below the horizon.
//
// z is depth below the horizon in screen pixels (small near the horizon,
// large at the bottom of the screen, the WRONG way round from a normal
// camera distance - but that is exactly what makes FLOOR_K / z grow
// larger near the bottom, which is the scale factor screen X has to be
// DIVIDED by to turn it into world X: a tile near the bottom of the
// screen covers a lot of world space (it is close to the camera) and a
// tile near the horizon covers almost none (it is far away), so
// FLOOR_K / z is small far away and large close up - correct.
//
// tileZ bands the same z into steps, so rows of tiles running ACROSS the
// screen alternate too, not just columns - without it the checkerboard
// would only ever stripe vertically.
//
// fog dithers the near tiles crisp and blends the far ones toward 0.5 -
// flat mid-grey noise - so the horizon disappears into haze exactly the
// way a real floor recedes into fog, rather than the checkerboard
// snapping off at some visible edge.
//------------------------------------------------------------------
.function floor_px(px, py) {
    .var z = py - HORIZON_Y + 1.0
    .var scale = FLOOR_K / z
    .var wobble = 3.0 * SIN_PY.get(py)          // gentle heat-haze wobble,
    .var worldX = ((px - CENTER_PX) + wobble) * scale / 100.0

    .var tileX = floor(worldX / GRID_SPACING)
    .var tileZ = floor(FLOOR_K / (z * GRID_SPACING))
    .var check = mod(tileX + tileZ + 4096, 2)

    .var fog = z / FOG_Z
    .if (fog > 1) { .eval fog = 1 }
    .return 0.5 + (check - 0.5) * fog
}

//------------------------------------------------------------------
// pattern_px - the composite intensity at one pixel, already dithered
// down to the single bit the bitmap stores.
//
// The sun is tested FIRST and, inside its disc, completely REPLACES the
// sky or floor pattern rather than blending with it - a badge sat on top
// of the picture, the way the sunset-sun always sits in front of the
// grid it is rising over. Squared distance only: no sqrt, no atan2, no
// angle anywhere in this file.
//------------------------------------------------------------------
.function pattern_px(px, py) {
    .var dxs = px - CENTER_PX
    .var dys = (py - SUN_CY) * ASPECT
    .var sun_d2 = dxs * dxs + dys * dys
    .if (sun_d2 <= SUN_R * SUN_R) {
        .var ly = (py - SUN_CY) + SUN_R         // 0 at the top of the disc
        .if (ly < 0) { .eval ly = 0 }
        .var stripe = floor(sqrt(ly) * SUN_STRIPE_K)
        .if (mod(stripe + 4096, 2) == 0) { .return 1 }
        .return 0
    }

    .var inten = 0
    .if (py < HORIZON_Y) {
        .eval inten = sky_px(px, py)
    } else {
        .eval inten = floor_px(px, py)
    }

    .if (inten > (BAYER.get(mod(py, 4) * 4 + mod(px, 4)) + 0.5) / 16) { .return 1 }
    .return 0
}

//==================================================================
// THE BITMAP
//
// Hi-res layout is the same 8-byte cells as multicolor: cell (row, col)
// at row * 320 + col * 8, byte k of a cell is pixel row k, bit 7 is the
// leftmost pixel. Only the meaning of a bit changes.
//==================================================================

* = INTRO_BITMAP "Intro Bitmap"

.for (var crow = 0; crow < 25; crow++) {
    .for (var ccol = 0; ccol < 40; ccol++) {
        .var is_logo = logo_cell(ccol, crow)
        .for (var k = 0; k < 8; k++) {
            .var py = crow * 8 + k
            .var bits = 0
            .for (var q = 0; q < 8; q++) {
                .var px = ccol * 8 + q
                .var v = 0
                .if (is_logo != 0) {
                    // a logo cell holds the letter and nothing else, so
                    // the sun and grid cannot bleed through and pick up
                    // the logo's colors
                    .eval v = text_px(px, py)
                } else {
                    .eval v = pattern_px(px, py)
                }
                .eval bits = bits | (v << (7 - q))
            }
            .byte bits
        }
    }
}

//==================================================================
// THE CELL FIELDS - the animation layer
//
// One byte per screen cell (40 x 25 = 1000). The low 4 bits are a
// position in a color ramp, and BIT 4 SAYS WHICH RAMP:
//
//     $00-$0f   a backdrop cell, stepping with pal_phase
//     $10-$1f   a logo cell,     stepping with text_phase
//
// so build_tabs fills a 32-entry table and one `lda vmtab,y` resolves
// both layers at once. The logo's flag is baked into every field, which
// is why the letters keep their own color and their own glint in a mode
// that has no color RAM to give them.
//
// Four fields, switched per phase, so the intro changes structure and
// not just speed. They all read the SAME fixed bitmap - what changes is
// which of ROWS, COLUMNS or a DIAGONAL the color motion sweeps along:
//
//   A  row bands      - wide horizontal bands drift down through the sky
//                        and the floor together, like the sunset itself
//                        cycling colour
//   B  column bands    - vertical bands sweep left-right across the
//                        grid, like a searchlight scanning the floor
//   C  diagonal bands  - tight, fast diagonal bands: the closest thing
//                        left to "busy", now a glitchy scanline shimmer
//                        instead of a tightening spiral
//   D  plasma          - unchanged: a non-linear swimming field that
//                        never lined up with the old polar math and
//                        does not need to change now
//
// Each is page aligned so paint_sweep can patch its page byte directly.
// Cells are sampled at their centre, in the same pixel space and with
// the same aspect correction as the bitmap.
//==================================================================

.function cell_glint(ccol, crow) {
    .return mod(floor(ccol * 0.6 + crow * 0.6) + 128, 16)
}

//------------------------------------------------------------------
// cell_row_wave / cell_col_wave / cell_diag_wave - a cell's fixed offset
// into the color ramp, as a straight line function of its row, column or
// both. `period` is how many rows/columns one full 16-step lap of the
// ramp takes: SMALL periods make tight, busy bands, LARGE ones make slow
// wide ones. There is no distance or angle term anywhere in these - a
// row-wave cell three rows down behaves identically whether it is in the
// dead centre of the screen or hard against the left edge, which is
// exactly the point: nothing here can ever read as radial.
//------------------------------------------------------------------
.function cell_row_wave(crow, period) {
    .return mod(floor(crow / period * 16) + 4096, 16)
}
.function cell_col_wave(ccol, period) {
    .return mod(floor(ccol / period * 16) + 4096, 16)
}
.function cell_diag_wave(ccol, crow, kx, ky) {
    .return mod(floor(ccol * kx + crow * ky) + 4096, 16)
}

//------------------------------------------------------------------
// cell_plasma - a swimming field, unchanged from the spiral version: the
// color moves across the picture rather than along any straight line
// through it, which is what stops the four fields ever looking the same.
//
// The diagonal terms matter: with only sin(ccol) and sin(crow) the field
// is separable and lays down obvious horizontal and vertical stripes a
// cell wide. Adding ccol+crow and ccol-crow breaks that up and gives the
// rounded, isotropic blobs a plasma is supposed to have.
//------------------------------------------------------------------
.function cell_plasma(ccol, crow) {
    .var v = sin(ccol * 0.42) + sin(crow * 0.31)
    .eval v = v + sin((ccol + crow) * 0.27) + sin((ccol - crow) * 0.19)
    .return mod(floor(v * 2.0) + 128, 16)
}

//------------------------------------------------------------------
// emit_field - one 1000-byte field. `kind` picks the motion; logo cells
// ignore it and take the glint instead, flagged with bit 4.
//------------------------------------------------------------------
.macro EmitField(kind) {
    .for (var crow = 0; crow < 25; crow++) {
        .for (var ccol = 0; ccol < 40; ccol++) {
            .if (logo_cell(ccol, crow) != 0) {
                .byte $10 + cell_glint(ccol, crow)
            } else .if (kind == 0) {
                .byte cell_row_wave(crow, 9.0)
            } else .if (kind == 1) {
                .byte cell_col_wave(ccol, 11.0)
            } else .if (kind == 2) {
                .byte cell_diag_wave(ccol, crow, 1.4, 2.0)
            } else {
                .byte cell_plasma(ccol, crow)
            }
        }
    }
}

* = INTRO_WAVE_A "Intro Wave A"
EmitField(0)

* = INTRO_WAVE_B "Intro Wave B"
EmitField(1)

* = INTRO_WAVE_C "Intro Wave C"
EmitField(2)

* = INTRO_WAVE_D "Intro Wave D"
EmitField(3)

//==================================================================
// THE WIPE FIELD - the handoff to the demo
//
// A fifth field, and the only one that is MONOTONIC: every other field
// wraps with mod 16 so its values repeat across the screen, which is
// what makes them cycle. A wipe must not repeat - each cell has to have
// exactly one moment at which it goes out - so this one is a clamped
// ramp instead of a modulo.
//
// The value is the cell's turn in the queue: 0 goes first, 15 last. It
// used to spiral in from the edges; now it is a plain curtain sweeping
// top to bottom (base), with a per-column hash JITTER thrown in so the
// curtain does not fall as one clean line - columns beat each other by a
// cell or two, which reads as a glitchy, staticky collapse rather than a
// wipe. Because it is just another field, phase W needs no new code in
// the sweep: build_wipe_tabs fills vmtab with black for every entry that
// has already come up and white for the rest, and paint_sweep does the
// rest.
//==================================================================

* = INTRO_WIPE "Intro Wipe Field"
.for (var crow = 0; crow < 25; crow++) {
    .for (var ccol = 0; ccol < 40; ccol++) {
        .var base = crow / 24.0 * 15.0
        .var jitter = (hash01(ccol * 7 + crow * 31 + 1) - 0.5) * 4.0
        .var t = floor(base + jitter)
        .if (t < 0)  { .eval t = 0 }
        .if (t > 15) { .eval t = 15 }
        .byte t
    }
}
