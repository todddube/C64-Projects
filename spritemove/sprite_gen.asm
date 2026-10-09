//==================================================================
// SPRITE_GEN - assembly-time sprite graphics for SPRITEMOV
//
// Imported by main.asm; not buildable on its own (it needs SPRITE_DATA,
// ROLL_X_PHASES and ROLL_Y_PHASES from main.asm's constants). Nothing in
// here is read at run time by the CPU - it only places bytes for the VIC
// to fetch, so it is separated from the demo logic it never touches.
//==================================================================

//------------------------------------------------------------------
// Sprite Data - 128 frames of a rolling, checkered ball
//
// A KickAssembler script ray-shades a sphere wrapped in a checker - the
// Amiga "Boing" ball - under a light that stays FIXED (top left, toward
// the viewer). What changes from frame to frame is the surface: the
// checker is rotated under the light, so the ball rolls rather than the
// light orbiting it.
//
// Rolling has two independent phases, one per screen axis:
//
//   a  rolling right: the sphere turns about the screen's vertical axis
//   b  rolling down:  it turns about the screen's horizontal axis
//
// For every pixel of the disc the surface normal n = (nx, ny, nz) is
// computed and turned into two angles,
//
//   phi = atan2(nx, nz)   longitude - constant along great circles
//                         through the top and bottom of the ball
//   psi = atan2(ny, nz)   the same around the horizontal axis
//
// and the checker square is picked from (phi - a, psi - b). Pure
// horizontal motion slides the phi lines across the ball exactly as a
// real rotation would and leaves the psi lines where they are; vertical
// motion does the reverse. A diagonal roll is not the exact composite
// rotation, but it is path-independent (the same position always shows
// the same frame) and at 20 px nobody can tell the difference.
//
// The checker squares are 45 degrees, so the pattern repeats every 90
// degrees of roll. A 90-degree roll of a radius-10.2 ball covers
//   10.2 * pi / 2 = 16.0 px
// of travel, so 16 px of movement is exactly one period on each axis:
//
//   X: 8 phases  -> one step per 2 px, the width of a multicolor pixel
//   Y: 16 phases -> one step per 1 px, the height of a sprite line
//
// i.e. the frame steps match the sprite's own resolution on each axis,
// and the texture moves at exactly the speed a ball rolling without
// slipping would show. Frame index = y_phase * 8 + x_phase, so the frame
// pointer is just $80 | (y_phase << 3) | x_phase - see update_sprites.
//
// Bit pairs, leftmost pixel in the top bits:
//   00 = transparent
//   01 = $d025  white: the light checker squares, and the specular spot
//   10 = $d027+n this ball's color: the dark checker squares
//   11 = $d026  dark grey: the shadow crescent on the far side
//
// Each frame is 63 bytes (21 rows x 3 bytes) plus 1 pad byte = 64 bytes,
// the VIC's sprite block size. 128 frames fill $2000-$3fff exactly; the
// very last pad byte is $3fff, the VIC's idle fetch in the opened
// border, which must be 0 - and is.
//------------------------------------------------------------------
* = SPRITE_DATA "Sprite Data"

.const RADIUS   = 10.2          // ~20 px wide, 21 lines tall
.const CENTER_X = 12.0          // pixel center of a 24 px wide sprite
.const CENTER_Y = 10.5          // line center of a 21 line sprite
.const CELL     = PI / 4        // checker square: 45 degrees
.const PERIOD   = 2 * CELL      // the checker repeats every 90 degrees

// The light: up and to the left, mostly toward the viewer. Normalized.
.const LX0 = -0.45
.const LY0 = -0.55
.const LZ0 = 0.70
.const LLEN = sqrt(LX0 * LX0 + LY0 * LY0 + LZ0 * LZ0)
.const LX = LX0 / LLEN
.const LY = LY0 / LLEN
.const LZ = LZ0 / LLEN

.const SHADOW   = 0.18          // Lambert below this: shadow crescent
.const SPECULAR = 0.97          // and above this: the white glint

.for (var yp = 0; yp < ROLL_Y_PHASES; yp++) {
    .for (var xp = 0; xp < ROLL_X_PHASES; xp++) {
        .var a = xp * PERIOD / ROLL_X_PHASES    // horizontal roll
        .var b = yp * PERIOD / ROLL_Y_PHASES    // vertical roll
        .for (var row = 0; row < 21; row++) {
            .var bits = 0                       // 24-bit row, pair by pair
            .for (var col = 0; col < 12; col++) {
                // Multicolor pixels are 2 screen pixels wide, so the
                // pixel center is col * 2 + 1 in real pixels.
                .var dx = (col * 2 + 1) - CENTER_X
                .var dy = (row + 0.5) - CENTER_Y
                .var pair = 0                   // default: transparent
                .if (sqrt(dx * dx + dy * dy) < RADIUS) {
                    .var nx = dx / RADIUS
                    .var ny = dy / RADIUS
                    .var nz = sqrt(max(0, 1.0 - nx * nx - ny * ny))
                    .var lit = nx * LX + ny * LY + nz * LZ
                    .var phi = atan2(nx, nz) - a
                    .var psi = atan2(ny, nz) - b
                    .var check = (floor(phi / CELL) + floor(psi / CELL)) & 1
                    .if (lit < SHADOW) {
                        .eval pair = %11        // shadow
                    } else .if (lit > SPECULAR || check == 0) {
                        .eval pair = %01        // white square / glint
                    } else {
                        .eval pair = %10        // colored square
                    }
                }
                .eval bits = bits | (pair << ((11 - col) * 2))
            }
            .byte (bits >> 16) & $ff, (bits >> 8) & $ff, bits & $ff
        }
        .byte 0                                 // pad to 64 bytes
    }
}
.errorif * != SPRITE_DATA + ROLL_X_PHASES * ROLL_Y_PHASES * 64, "ball frames are not 64 bytes each"
.errorif * > VIC_IDLE_FETCH + 1, "ball frames run past the end of VIC bank 0"
