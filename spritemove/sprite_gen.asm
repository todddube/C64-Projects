//==================================================================
// SPRITE_GEN - assembly-time sprite graphics for SPRITEMOV
//
// Imported by main.asm; not buildable on its own (it needs SPRITE_DATA
// and TRAIL_DATA from main.asm's constants). Nothing in here is read at
// run time by the CPU - it only places bytes for the VIC to fetch, so it
// is separated from the demo logic it never touches.
//==================================================================

//------------------------------------------------------------------
// Sprite Data - 8 shaded sphere frames, generated at assembly time
//
// Instead of hand-drawn bitmaps, a KickAssembler script ray-shades a
// sphere. For every frame f the light direction rotates by f * 45
// degrees around the viewing axis. For every pixel:
//
//   1. Is it inside the circle? (distance from center < RADIUS)
//   2. If so, compute the sphere's surface normal at that point:
//        n = (dx/R, dy/R, sqrt(1 - dx^2/R^2 - dy^2/R^2))
//   3. Lambert shading: brightness = n . light
//   4. Threshold the brightness into 3 tones: highlight / body / shadow
//
// Multicolor sprites are 12 "wide pixels" x 21 lines (each wide pixel is
// 2 screen pixels), so dx uses (col*2 + 1) to get the pixel center in
// real pixels. Bit pairs, leftmost pixel in the top bits:
//   00 = transparent
//   01 = $d025  highlight (white)
//   10 = $d027+n sprite body color
//   11 = $d026  shadow (dark grey)
//
// Each frame is 63 bytes (21 rows x 3 bytes) plus 1 pad byte = 64 bytes,
// which is the VIC's sprite block size.
//------------------------------------------------------------------
* = SPRITE_DATA "Sprite Data"

.const RADIUS   = 10.2          // ~20 px wide, 21 lines tall
.const CENTER_X = 12.0          // pixel center of a 24 px wide sprite
.const CENTER_Y = 10.5          // line center of a 21 line sprite

.for (var f = 0; f < 8; f++) {
    .var angle = f * 2 * PI / 8         // light rotates 45 deg per frame
    .var lx = cos(angle) * 0.55         // in-plane light components
    .var ly = sin(angle) * 0.55
    .var lz = 0.83                      // toward the viewer (keeps center lit)
    .for (var row = 0; row < 21; row++) {
        .var bits = 0                   // 24-bit row, built pair by pair
        .for (var col = 0; col < 12; col++) {
            .var dx = (col * 2 + 1) - CENTER_X
            .var dy = (row + 0.5) - CENTER_Y
            .var d = sqrt(dx * dx + dy * dy)
            .var pair = 0               // default: transparent
            .if (d < RADIUS) {
                .var nx = dx / RADIUS
                .var ny = dy / RADIUS
                .var nz = sqrt(1.0 - nx * nx - ny * ny)
                .var lit = nx * lx + ny * ly + nz * lz
                .if (lit > 0.93) {
                    .eval pair = %01     // highlight
                } else .if (lit < 0.22) {
                    .eval pair = %11     // shadow
                } else {
                    .eval pair = %10     // body
                }
            }
            .eval bits = bits | (pair << ((11 - col) * 2))
        }
        .byte (bits >> 16) & $ff, (bits >> 8) & $ff, bits & $ff
    }
    .byte 0                             // pad to 64 bytes
}

//------------------------------------------------------------------
// Trail Sprite - one solid hi-res disc, slightly smaller than the ball
//
// Hi-res sprites are 24 x 21 one-bit pixels: bit set = sprite color
// ($d027+n), clear = transparent. The disc peeks out from behind the
// ball as it moves, so it only needs to be roughly ball-sized.
//------------------------------------------------------------------
* = TRAIL_DATA "Trail Sprite"

.const TRAIL_RADIUS = 9.2

.for (var row = 0; row < 21; row++) {
    .var bits = 0
    .for (var col = 0; col < 24; col++) {
        .var dx = (col + 0.5) - CENTER_X
        .var dy = (row + 0.5) - CENTER_Y
        .if (sqrt(dx * dx + dy * dy) < TRAIL_RADIUS) {
            .eval bits = bits | (1 << (23 - col))
        }
    }
    .byte (bits >> 16) & $ff, (bits >> 8) & $ff, bits & $ff
}
.byte 0                                 // pad to 64 bytes
