//============================================================
// Sprite shapes added to the tutorial, drawn as text so they
// can be read and edited in the source. They go right after the
// SpritePad ship frames, at $2400 (pointer $90 onwards).
//
//   hires rows:       24 chars, '#' is a set pixel
//   multicolour rows: 12 chars, each a 2-pixel pair (VIC bit pairs
//                     %01, %10, %11): '.' transparent, '1' $d025,
//                     '2' the sprite's own colour ($d027+n), '3' $d026
// A shape is 21 rows; 'top' blank rows are added above the
// rows given and the rest is padded, then the 64th byte.
//============================================================

.function hbits(s, o) {
    .var v = 0
    .for (var i = 0; i < 8; i++) {
        .eval v = v * 2 + ((s.charAt(o + i) == '#') ? 1 : 0)
    }
    .return v
}

.function mbits(s, o) {
    .var v = 0
    .for (var i = 0; i < 4; i++) {
        .var c = s.charAt(o + i)
        .eval v = v * 4 + ((c == '1') ? 1 : (c == '2') ? 2 : (c == '3') ? 3 : 0)
    }
    .return v
}

.macro SpriteHires(top, rows) {
    .for (var r = 0; r < 21; r++) {
        .var i = r - top
        .if (i >= 0 && i < rows.size()) {
            .byte hbits(rows.get(i), 0), hbits(rows.get(i), 8), hbits(rows.get(i), 16)
        } else {
            .byte 0, 0, 0
        }
    }
    .byte 0
}

.macro SpriteMulti(top, rows) {
    .for (var r = 0; r < 21; r++) {
        .var i = r - top
        .if (i >= 0 && i < rows.size()) {
            .byte mbits(rows.get(i), 0), mbits(rows.get(i), 4), mbits(rows.get(i), 8)
        } else {
            .byte 0, 0, 0
        }
    }
    .byte 0
}

* = address_sprites2 "Sprites added"

// exhaust flame, 4 shapes ($90-$93): sits at ship X + 24, flickers
// yellow/orange ('2'), white core ('3'), grey tips ('1')
SpriteMulti(8, List().add(
    "22..........",
    "2232........",
    "323321......",
    "2232........",
    "22.........."))
SpriteMulti(8, List().add(
    "2...........",
    "2231........",
    "32332.1.....",
    "2231........",
    "2..........."))
SpriteMulti(8, List().add(
    "22..........",
    "22321.......",
    "3233321.....",
    "22321.......",
    "22.........."))
SpriteMulti(8, List().add(
    "2...........",
    "223.........",
    "32321.......",
    "223.........",
    "2..........."))

// rocket ($94): hires dart, nose to the left, in rows 0-2 so it
// launches from the ship's centre row (ROCKET_DY)
SpriteHires(0, List().add(
    ".....####...............",
    "#########...............",
    ".....####..............."))

// asteroids, 2 shapes ($95, $96): brown rock ('2') with dark grey
// craters ('1') and white glints ('3'); about 20 x 13 pixels
SpriteMulti(2, List().add(
    "....2222....",
    "..22221222..",
    ".2221122222.",
    ".2211222223.",
    "22122222233.",
    "22222221223.",
    "2221222222..",
    "22212222222.",
    ".2222122223.",
    ".2222222223.",
    "..22122233..",
    "...222223...",
    "....2222...."))
SpriteMulti(4, List().add(
    "...22222....",
    "..2212222...",
    ".22112222.2.",
    ".2212222232.",
    "222222223222",
    ".22212223222",
    ".2222222222.",
    "..22122233..",
    "...222233...",
    "....222....."))

// explosion, 4 shapes ($97-$9a), shown 4 frames each: a white
// core grows into a yellow ring that breaks into grey sparks
SpriteMulti(8, List().add(
    "....3333....",
    "...322223...",
    "...322223...",
    "....3333...."))
SpriteMulti(6, List().add(
    "....2222....",
    "..22233222..",
    ".2233333322.",
    ".2233333322.",
    "..22233222..",
    "....2222...."))
SpriteMulti(4, List().add(
    "...222222...",
    ".22211112.2.",
    ".21....12.2.",
    "22.......22.",
    "2.........22",
    "2.........2.",
    "22......122.",
    ".21....122..",
    ".2211112....",
    "...222222..."))
SpriteMulti(4, List().add(
    "1..2.....1..",
    "..1...2.....",
    ".2...1....2.",
    "....1...1...",
    "2.........2.",
    "..1..2....1.",
    ".....1.2....",
    "2...1....2..",
    "..2....1...."))
