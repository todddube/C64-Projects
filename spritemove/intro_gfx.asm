//==================================================================
// INTRO_GFX - the intro's hi-res bitmap and its cell field,
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
// THERE IS NO LOGO IN THE BITMAP
// ------------------------------
// The title, date and version used to be carved in here as well as
// packed into sprites, and the intro handed the logo from one copy to
// the other. The carving cost a dark, letter-shaped plate cut out of the
// picture while the sprites flew, and a visible handoff each way. Now
// the labels are sprites only (intro_sprites.asm) and every cell of this
// bitmap is picture.
//==================================================================

.const CENTER_PX = 160.0        // 320 pixels across
.const ASPECT    = 1.2          // a hi-res pixel is ~1.2x taller than wide
                                 // on a 4:3 screen, so the sun needs dy
                                 // scaled by this to come out round

.const HORIZON_Y   = 92.0       // sky above this line, floor grid below it
.const BAND_H      = 15.0       // sunset stripe height in the sky, pixels.
                                 // Wide and calm on purpose: this is the
                                 // backdrop the label sprites travel
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
// is to make each stripe's edge look
// irregular to the EYE, not to differ from run to run (KickAssembler has
// no runtime randomness to offer anyway, this all happens at build time).
//------------------------------------------------------------------
.function hash01(n) {
    .var s = sin(n * 12.9898 + 78.233) * 43758.5453
    .return s - floor(s)
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
        .for (var k = 0; k < 8; k++) {
            .var py = crow * 8 + k
            .var bits = 0
            .for (var q = 0; q < 8; q++) {
                .eval bits = bits | (pattern_px(ccol * 8 + q, py) << (7 - q))
            }
            .byte bits
        }
    }
}

//==================================================================
// THE CELL FIELD - the animation layer
//
// One byte per screen cell (40 x 25 = 1000), each a position 0-15 in
// the backdrop's color ramp. build_tabs turns pal_phase into a 16-entry
// table every frame and paint_sweep looks every cell up in it, so a
// color sits wherever field + pal_phase lands on it - and as pal_phase
// climbs, every color slides toward LOWER field values.
//
// There is one field, and it is built so that slide reads as travel:
//
//   sky    field RISES going down the screen, 16 steps every SKY_ROWS
//          rows, so the bands drift UP, away from the horizon
//   floor  field FALLS going down, as -sqrt(depth below the horizon):
//          the steps crowd together near the horizon and spread out
//          toward the bottom, the same recession as the checkerboard,
//          so the bands roll DOWN the floor toward the viewer
//
// Both move away from the horizon at once: the sun sits still on the
// line and the world streams out from behind it. The old intro switched
// between row, column, diagonal and plasma fields; one field that never
// changes shape is what keeps the picture calm under the labels.
//
// Page aligned so paint_sweep can patch its page byte directly.
//==================================================================
.const SKY_ROWS   = 9.0         // rows for one lap of the ramp in the sky
.const FIELD_K    = 3.2         // floor steps per sqrt(pixel) of depth

.function cell_field(ccol, crow) {
    .var cy = crow * 8 + 4                      // the cell's centre line
    .if (cy < HORIZON_Y) {
        .return mod(floor(crow / SKY_ROWS * 16) + 4096, 16)
    }
    .return mod(floor(-sqrt(cy - HORIZON_Y) * FIELD_K) + 4096, 16)
}

* = INTRO_WAVE_A "Intro Wave A"
.for (var crow = 0; crow < 25; crow++) {
    .for (var ccol = 0; ccol < 40; ccol++) {
        .byte cell_field(ccol, crow)
    }
}
