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
// WHAT THE PATTERN IS
// -------------------
// Four things summed into one intensity field, so that different cell
// fields later pick out different structures in the same fixed bitmap:
//
//   spiral    the main arms, a triangle wave of  dist/R + angle*arms
//   counter   a second spiral turning the OTHER way at a different arm
//             count - where the two cross they beat against each other
//             and throw moire
//   rings     a radial sine, concentric shockwaves over the whole field
//   plasma    three summed sines in x, y and x+y, which breaks up the
//             regularity so the bands breathe instead of being perfect
//
// and then the CHECKERED TUNNEL: the field is divided into rings by
// distance and sectors by angle, and in every other cell of that
// checkerboard the intensity is INVERTED. Inverting rather than masking
// keeps all the texture and flips which color carries it, so the
// checkerboard reads as a tunnel receding into the middle while the
// detail inside each cell stays alive.
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

.const CENTER_PX = 160.0        // 320 pixels across
.const CENTER_PY = 100.0        // 200 lines down
.const ASPECT    = 1.2          // a hi-res pixel is ~1.2x taller than wide
                                // on a 4:3 screen, so circles need dy
                                // scaled by this to come out round

.const RING1 = 26.0             // main spiral: pixels per band
.const ARMS1 = 5.0              //              bands added per turn
.const RING2 = 17.0             // counter spiral, turning the other way
.const ARMS2 = 3.0
.const RINGK = 0.16             // radial pulse rings: ~39 pixels per ring
.const TUNR  = 42.0             // checkered tunnel: pixels per ring
.const TUNN  = 8.0              //                   sectors around

// The logo, drawn at 2 bitmap pixels per font pixel in both directions,
// so a character is 16 x 16 - square on screen, and the same size it was
// in multicolor. Centred, in the lower third, clear of the vortex.
.const NAME_X = (320 - NAME_CHARS * 16) / 2     // = 64
.const NAME_Y = 136
.const DATE_X = (320 - DATE_CHARS * 16) / 2     // = 80
.const DATE_Y = 160

//------------------------------------------------------------------
// Hoisted sine tables. The plasma's three terms depend only on px, py
// and px+py, so they are computed once each here rather than 64000 times
// in the pixel loop - that keeps the loop down to one sqrt, one atan2
// and one sin per pixel, the same as the old multicolor version despite
// there being twice as many pixels and four times as much pattern.
//------------------------------------------------------------------
.var SIN_PX = List()
.for (var i = 0; i < 320; i++) { .eval SIN_PX.add(sin(i * 0.075)) }
.var SIN_PY = List()
.for (var i = 0; i < 200; i++) { .eval SIN_PY.add(sin(i * 0.110)) }
.var SIN_PD = List()
.for (var i = 0; i < 520; i++) { .eval SIN_PD.add(sin(i * 0.045)) }

// 4x4 ordered dither. Reading (py&3, px&3) out of this and comparing
// against the intensity is the whole of the shading.
.var BAYER = List().add( 0,  8,  2, 10,
                        12,  4, 14,  6,
                         3, 11,  1,  9,
                        15,  7, 13,  5)

//------------------------------------------------------------------
// tri - triangle wave, period 1, rising 0..1 then falling 1..0. Used
// instead of a sine for the spirals because its straight flanks give the
// arms a crisper edge once dithered.
//------------------------------------------------------------------
.function tri(v) {
    .var f = v - floor(v)
    .if (f > 0.5) { .return 2 - 2 * f }
    .return 2 * f
}

//------------------------------------------------------------------
// glyph_px / near_text / text_px - the logo, in hi-res coordinates:
// 16 pixels per character across, 2 bitmap lines per font row down.
//------------------------------------------------------------------
.function glyph_px(px, py, rows, x, y, n) {
    .if (py < y || py >= y + 16) { .return 0 }
    .if (px < x || px >= x + n * 16) { .return 0 }
    .var ci  = floor((px - x) / 16)
    .var bit = floor(mod(px - x, 16) / 2)
    .var row = floor((py - y) / 2)
    .if ((rows.get(ci * 8 + row) & (128 >> bit)) != 0) { .return 1 }
    .return 0
}

.function text_px(px, py) {
    .if (glyph_px(px, py, NAME_ROWS, NAME_X, NAME_Y, NAME_CHARS) != 0) { .return 1 }
    .if (glyph_px(px, py, DATE_ROWS, DATE_X, DATE_Y, DATE_CHARS) != 0) { .return 1 }
    .return 0
}

//------------------------------------------------------------------
// logo_cell - does character cell (ccol, crow) contain any logo pixel?
//
// Cells that do are handled completely differently from the rest: the
// spiral is cleared out of them entirely and their color pair comes from
// the logo's own ramp (see the +16 in cell_value below). That is what
// gives the letters an independent color in a mode with no color RAM -
// the separation is per cell rather than per bit pair. The letters end up
// sitting on a chunky, letter-shaped plate cut out of the bands.
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
// pattern_px - the composite intensity at one pixel, already dithered
// down to the single bit the bitmap stores.
//------------------------------------------------------------------
.function pattern_px(px, py) {
    .var dx  = px - CENTER_PX
    .var dy  = (py - CENTER_PY) * ASPECT
    .var d   = sqrt(dx * dx + dy * dy)
    .var a   = atan2(dy, dx) / (2 * PI)

    // The other three patterns WARP THE SPIRAL'S PHASE rather than being
    // averaged into its brightness. Averaging four fields that each run
    // 0..1 lands almost every pixel near 0.5, where an ordered dither is
    // just 50% noise and no structure survives. Displacing the phase
    // instead keeps the triangle wave swinging through its full range, so
    // the arms stay solid and only their edges dither - and the rings,
    // plasma and counter-spiral show up as the arms bulging, breathing
    // and beating against each other.
    .var plasma = (SIN_PX.get(px) + SIN_PY.get(py) + SIN_PD.get(px + py)) / 3
    .var warp = 0.40 * sin(d * RINGK)
    .eval warp = warp + 0.25 * plasma
    .eval warp = warp + 0.35 * tri(d / RING2 - a * ARMS2)

    .var inten = tri(d / RING1 + a * ARMS1 + warp)

    // Push it toward the ends of the range: most of the picture should be
    // solid ink or solid paper, with dithering confined to the band edges
    // where it reads as a soft gradient instead of as static.
    .eval inten = (inten - 0.5) * 2.0 + 0.5
    .if (inten < 0) { .eval inten = 0 }
    .if (inten > 1) { .eval inten = 1 }

    // the checkered tunnel: invert every other ring/sector cell
    // + 1024 keeps the modulo away from negative angles, where
    // KickAssembler (like Java) would return a negative result
    .var tun = floor(d / TUNR) + floor((a + 0.5) * TUNN) + 1024
    .if (mod(tun, 2) != 0) { .eval inten = 1 - inten }

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
                    // the spiral cannot bleed through and pick up the
                    // logo's colors
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
//     $00-$0f   a spiral cell, stepping with pal_phase
//     $10-$1f   a logo cell,  stepping with text_phase
//
// so build_tabs fills a 32-entry table and one `lda vmtab,y` resolves
// both layers at once. The logo's flag is baked into every field, which
// is why the letters keep their own color and their own glint in a mode
// that has no color RAM to give them.
//
// Four fields, switched per phase, so the intro changes structure and
// not just speed. They all read the SAME fixed bitmap - what changes is
// which of the patterns in it the color motion picks out:
//
//   A  concentric rings     - drives the radial pulse, ripples outward
//   B  one turn per lap     - drives the main spiral, a rotating gradient
//   C  three turns, tight   - drives the counter spiral, moire and shimmer
//   D  plasma               - non-radial, so the bands swim instead of
//                             turning, and the tunnel checkerboard pops
//
// Each is page aligned so paint_sweep can patch its page byte directly.
// Cells are sampled at their centre, in the same pixel space and with
// the same aspect correction as the bitmap.
//==================================================================

.function cell_glint(ccol, crow) {
    .return mod(floor(ccol * 0.6 + crow * 0.6) + 128, 16)
}

.function cell_wave(ccol, crow, ring, turns) {
    .var dx = (ccol * 8 + 4) - CENTER_PX
    .var dy = ((crow * 8 + 4) - CENTER_PY) * ASPECT
    .var d  = sqrt(dx * dx + dy * dy)
    .var a  = atan2(dy, dx) / (2 * PI)
    .return mod(floor(d / ring + a * turns) + 1024, 16)
}

//------------------------------------------------------------------
// cell_plasma - a non-radial field, so the color swims across the
// picture instead of turning around the middle.
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
                .byte cell_wave(ccol, crow, 12.0, 0)
            } else .if (kind == 1) {
                .byte cell_wave(ccol, crow, 16.0, 16)
            } else .if (kind == 2) {
                .byte cell_wave(ccol, crow, 9.0, 48)
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
// rises from the edge of the screen toward the centre, with an angular
// term mixed in so the boundary sweeps round as it closes. The white
// sheet left by the flash is therefore eaten from the outside in, in a
// spiral, and the last thing to go is the eye of the vortex.
//
// Because it is just another field, phase W needs no new code in the
// sweep: build_wipe_tabs fills vmtab with black for every entry that has
// already come up and white for the rest, and paint_sweep does the rest.
//==================================================================

.const WIPE_DMAX = 200.0        // furthest a cell centre gets from centre

* = INTRO_WIPE "Intro Wipe Field"
.for (var crow = 0; crow < 25; crow++) {
    .for (var ccol = 0; ccol < 40; ccol++) {
        .var dx = (ccol * 8 + 4) - CENTER_PX
        .var dy = ((crow * 8 + 4) - CENTER_PY) * ASPECT
        .var d  = sqrt(dx * dx + dy * dy)
        .var a  = atan2(dy, dx) / (2 * PI)
        .var t  = floor((1 - d / WIPE_DMAX) * 12 + (a + 0.5) * 3.5)
        .if (t < 0)  { .eval t = 0 }
        .if (t > 15) { .eval t = 15 }
        .byte t
    }
}
