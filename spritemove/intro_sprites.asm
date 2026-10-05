//==================================================================
// INTRO_SPRITES - the intro's labels (name, date, version), generated
// at assembly time from the glyph rows in intro_text.asm
//
// Imported by main.asm; not buildable on its own. No run-time code.
//
// WHY SPRITES
// -----------
// Sprites are the only thing on this machine that moves for free: eight
// X/Y register pairs a frame and the VIC does the rest - and they sit
// in front of the vertical bars without the bars ever having to know.
//
// THE PACKING
// -----------
// A sprite is 24 pixels across - exactly 3 characters at 8 pixels each -
// and 21 rows deep. The two labels are packed at different scales:
//
//   sprites 0-3  the name, 3 characters each, every font row stored TWICE
//                so 8 font rows fill 16 sprite rows. X-expanded at run
//                time, so a character is 16 x 16 on screen.
//   sprites 4-7  the date and, under it, the version - 12 character slots
//                at the font's own size (8 x 8), not expanded. The date's
//                10 characters sit in slots 1-10 on rows 0-7, "v1.0" in
//                slots 4-7 on rows 12-19, so both are centred in the
//                96-pixel block and move together as one label.
//
// flow_logo_on writes %00001111 to $d01d for exactly this reason, and
// x_place spaces the date's sprites 24 pixels apart against the name's 48.
//
// Sprite n's data is at INTRO_SPR + n * 64, so its VIC block number is
// INTRO_SPR / 64 + n = $30 + n. They live at $0c00 in VIC bank 0, the
// bank the whole intro runs in; the demo's ball sprites at $2000 take
// the pointers back once the intro is over.
//==================================================================

#import "intro_text.asm"

.errorif DATE_CHARS > 11, "the date must fit slots 1-10 of the date sprites"
.errorif VER_CHARS > 12, "the version must fit the date sprites' 12 slots"

//------------------------------------------------------------------
// spr_row - the byte for character `ci` of `rows` at sprite row `r`,
// or 0 where the sprite runs past the end of the string or past the
// 16 rows the doubled glyph occupies.
//------------------------------------------------------------------
.function spr_row(rows, n, ci, r) {
    .if (r >= 16 || ci >= n) { .return 0 }
    .return rows.get(ci * 8 + floor(r / 2))
}

//------------------------------------------------------------------
// date_row - the date block's byte for slot `slot` at sprite row `r`:
// the date on rows 0-7, the version on rows 12-19, each centred in the
// 12 slots, blank everywhere else.
//------------------------------------------------------------------
.const DATE_SLOT0 = floor((12 - DATE_CHARS) / 2)
.const VER_SLOT0  = floor((12 - VER_CHARS) / 2)

.function date_row(slot, r) {
    .var d = slot - DATE_SLOT0
    .if (r < 8 && d >= 0 && d < DATE_CHARS) { .return DATE_ROWS.get(d * 8 + r) }
    .var v = slot - VER_SLOT0
    .if (r >= 12 && r < 20 && v >= 0 && v < VER_CHARS) { .return VER_ROWS.get(v * 8 + r - 12) }
    .return 0
}

* = INTRO_SPR "Intro Label Sprites"

.for (var s = 0; s < 4; s++) {              // sprites 0-3: the name
    .for (var r = 0; r < 21; r++) {
        .for (var c = 0; c < 3; c++) {
            .byte spr_row(NAME_ROWS, NAME_CHARS, s * 3 + c, r)
        }
    }
    .byte 0                                  // pad 63 -> 64
}

.for (var s = 0; s < 4; s++) {              // sprites 4-7: date + version
    .for (var r = 0; r < 21; r++) {
        .for (var c = 0; c < 3; c++) {
            .byte date_row(s * 3 + c, r)
        }
    }
    .byte 0
}

//------------------------------------------------------------------
// The sine table the ripple is read from: one full period over 256
// entries, 0-255, so indexing it with a byte counter wraps for free and
// no clamping is ever needed. flow_sprites shifts it down to whatever
// amplitude it wants.
//------------------------------------------------------------------
* = INTRO_SIN "Intro Sine Table"
.for (var i = 0; i < 256; i++) {
    .byte round(127.5 + 127.5 * sin(i * 2 * PI / 256))
}
