//==================================================================
// PHYSICS_TABLES - assembly-time lookup tables for the ball physics
//
// Imported by main.asm; not buildable on its own (it needs MUL_TABLES,
// COLL_TAB, BALL_DIAM and SEP_MAX from main.asm's constants). Pure data:
// the code that reads it is mul8, mul_vn and check_pair in main.asm.
//==================================================================

//------------------------------------------------------------------
// Quarter-square multiply tables, for mul8.
//
//     a * b = floor((a + b)^2 / 4) - floor((a - b)^2 / 4)
//
// exactly, for any unsigned bytes a and b (a + b and a - b have the same
// parity, so the two floors drop the same remainder). sqr1 holds
// floor(i^2 / 4) for i = 0..510; sqr2 holds floor((i - 255)^2 / 4), so
// that indexing it with (255 - a) + b gives floor((b - a)^2 / 4) with no
// absolute value to take. Each table is 512 bytes and starts on a page:
// mul8 patches a page offset into the low byte of the table address.
//------------------------------------------------------------------
* = MUL_TABLES "Multiply Tables"
sqr1_lo:    .fill 512, <floor(i * i / 4)
sqr1_hi:    .fill 512, >floor(i * i / 4)
sqr2_lo:    .fill 512, <floor((i - 255) * (i - 255) / 4)
sqr2_hi:    .fill 512, >floor((i - 255) * (i - 255) / 4)

//------------------------------------------------------------------
// Collision table - everything check_pair needs about two balls whose
// centers are |dx|, |dy| pixels apart (both 0..BALL_DIAM-1), so the
// 6502 never takes a square root or divides.
//
// 20 rows (|dy|) of 20 records (|dx|), 8 bytes each:
//
//   +0  nx      |dx| / d, the collision normal, in 128ths (0..128)
//   +1  ny      |dy| / d, likewise
//   +2  sepx    8.8 px: how far to push EACH ball apart along X
//   +4  sepy    8.8 px: the same along Y
//   +6  unused, so a record is 8 bytes and |dx| * 8 indexes it
//
// d = sqrt(dx^2 + dy^2). A record of all zeros means d >= BALL_DIAM: the
// balls do not touch - a true circle test, not a box. Two balls exactly
// on top of each other (d = 0) get the normal (1, 0).
//
// The normal is quantized so that nx^2 + ny^2 is as close to 128^2 as
// the rounding allows. That matters: a velocity exchange along a normal
// that is slightly too short is slightly inelastic, and the balls would
// lose a little energy on every single collision and slowly grind to a
// halt. Picking the best of the nine neighbouring roundings leaves an
// error that is as often a hair too long as too short, which averages
// out instead of adding up.
//
// The push apart is half the overlap each, capped at SEP_MAX so a deep
// overlap (two balls spawned on top of each other) eases apart over a
// few frames instead of jumping.
//------------------------------------------------------------------
* = COLL_TAB "Collision Table"
.for (var ady = 0; ady < BALL_DIAM; ady++) {
    .for (var adx = 0; adx < BALL_DIAM; adx++) {
        .var d = sqrt(adx * adx + ady * ady)
        .if (d >= BALL_DIAM) {
            .fill 8, 0
        } else {
            .var ux = 1.0
            .var uy = 0.0
            .if (d > 0) {
                .eval ux = adx / d
                .eval uy = ady / d
            }
            .var bx = round(ux * 128)
            .var by = round(uy * 128)
            .var bestx = bx
            .var besty = by
            .var besterr = abs(bx * bx + by * by - 16384)
            .for (var ox = -1; ox <= 1; ox++) {
                .for (var oy = -1; oy <= 1; oy++) {
                    .var cx = bx + ox
                    .var cy = by + oy
                    .if (cx >= 0 && cx <= 128 && cy >= 0 && cy <= 128) {
                        .var err = abs(cx * cx + cy * cy - 16384)
                        .if (err < besterr) {
                            .eval bestx = cx
                            .eval besty = cy
                            .eval besterr = err
                        }
                    }
                }
            }
            .var sep = min((BALL_DIAM - d) / 2, SEP_MAX)
            .var sx = round(ux * sep * 256)
            .var sy = round(uy * sep * 256)
            .byte bestx, besty, <sx, >sx, <sy, >sy, 0, 0
        }
    }
}

// Row addresses, so check_pair can find row |dy| without a multiply.
coll_row_lo:    .fill BALL_DIAM, <(COLL_TAB + i * BALL_DIAM * 8)
coll_row_hi:    .fill BALL_DIAM, >(COLL_TAB + i * BALL_DIAM * 8)
