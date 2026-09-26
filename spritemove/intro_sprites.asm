//==================================================================
// INTRO_SPRITES - the flying copy of the logo, generated at assembly
// time from the same glyph rows the bitmap is carved from
//
// Imported by main.asm; not buildable on its own. No run-time code.
//
// WHY SPRITES AT ALL
// ------------------
// The carved logo is pixels in a bitmap that is never rewritten, so it
// cannot move - redrawing 8000 bytes is nowhere near a frame. Sprites are
// the only thing on this machine that moves for free: eight X/Y register
// pairs a frame and the VIC does the rest. So the intro carries the logo
// twice, from one source: carved into the bitmap where it is still, and
// packed into sprites where it flows.
//
// THE PACKING
// -----------
// A sprite is 24 pixels across - exactly 3 characters at 8 pixels each -
// and 21 rows deep. Each font row is stored TWICE, so 8 font rows fill 16
// sprite rows and a character comes out 8 x 16. X expansion ($d01d) then
// doubles the width to 16 x 16, square on screen and the same size as the
// carved logo. The last 5 rows of each sprite are blank.
//
//   sprites 0-3   NAME_CHARS characters of the name, 3 per sprite
//   sprites 4-7   DATE_CHARS characters of the date, 3 per sprite
//
// Sprite n's data is at INTRO_SPR + n * 64, so its VIC block number is
// INTRO_SPR / 64 + n. They live in VIC bank 1 with the intro's bitmap;
// the demo proper uses its own sprites out of bank 0 and never sees these.
//==================================================================

//------------------------------------------------------------------
// spr_row - the byte for character `ci` of `rows` at sprite row `r`,
// or 0 where the sprite runs past the end of the string or past the
// 16 rows the doubled glyph occupies.
//------------------------------------------------------------------
.function spr_row(rows, n, ci, r) {
    .if (r >= 16 || ci >= n) { .return 0 }
    .return rows.get(ci * 8 + floor(r / 2))
}

* = INTRO_SPR "Intro Logo Sprites"

.for (var s = 0; s < 4; s++) {              // sprites 0-3: the name
    .for (var r = 0; r < 21; r++) {
        .for (var c = 0; c < 3; c++) {
            .byte spr_row(NAME_ROWS, NAME_CHARS, s * 3 + c, r)
        }
    }
    .byte 0                                  // pad 63 -> 64
}

.for (var s = 0; s < 4; s++) {              // sprites 4-7: the date
    .for (var r = 0; r < 21; r++) {
        .for (var c = 0; c < 3; c++) {
            .byte spr_row(DATE_ROWS, DATE_CHARS, s * 3 + c, r)
        }
    }
    .byte 0
}

//------------------------------------------------------------------
// The sine table the flow is built from: one full period over 256
// entries, 0-255, so indexing it with a byte counter wraps for free and
// no clamping is ever needed. flow_sprites shifts it down to whatever
// amplitude it wants.
//------------------------------------------------------------------
* = INTRO_SIN "Intro Sine Table"
.for (var i = 0; i < 256; i++) {
    .byte round(127.5 + 127.5 * sin(i * 2 * PI / 256))
}
