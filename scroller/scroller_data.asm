//==============================================================================
// FILE:        scroller_data.asm
// PROJECT:     STARDUST - imported by scroller.asm, not buildable on its own
// DESCRIPTION: Tables, shadow registers, scroll text, and the sprite art
//              (planet, ship, flame, moon) generated at assembly time.
//==============================================================================

//==============================================================================
// FONT AND WAVES
//==============================================================================

// Row k of screen code c is at font_rows + k*64 + c (built by build_font).
// Page aligned, so no lda font_rows + k*64, x ever crosses a page.
.align $100
font_rows:
    .fill 8 * 64, 0

// DYCP wave: y = tabA[p1 + 7c] + tabB[p2 + 5c], 0..34 in a 48-byte column.
// Each table runs on past 256 so the column offset never needs a wrap.
tabA:
    .fill 256 + 7 * 39 + 1, round(10 + 10 * sin(toRadians(i * 360 / 256)))
tabB:
    .fill 256 + 5 * 39 + 1, round(7 + 7 * sin(toRadians(i * 720 / 256)))

// Copper bar tops, 0..39 inside the 48 scroller lines (a bar is 9 lines)
bar_sin:
    .fill 256, round(19.5 + 19.5 * sin(toRadians(i * 360 / 256)))

//==============================================================================
// LOGO
//==============================================================================

logo_text:
    .text "stardust"                // screen codes 1-26: the ROM capitals

// Runs on past 256 for update_logo's per-letter offset (24 * letter)
bob_tab:
    .fill 256 + 24 * 7, LOGO_Y + round(6 + 6 * sin(toRadians(i * 360 / 256)))
sway_tab:
    .fill 256, round(20 + 20 * sin(toRadians(i * 360 / 256)))
// Light blue letters with a cyan-white-cyan highlight sweeping left to
// right. Two copies: update_logo reads logo_grad + 32 - letter + (0..31).
logo_grad:
    .for (var n = 0; n < 2; n++) {
        .fill 24, COLOR_LIGHT_BLUE
        .byte COLOR_CYAN, COLOR_WHITE, COLOR_CYAN
        .fill 5, COLOR_LIGHT_BLUE
    }

// Shadows copied to the VIC by irq_top
logo_x:     .fill 8, 0
logo_y:     .fill 8, 0
logo_col:   .fill 8, 0
logo_msb:   .byte 0

//==============================================================================
// THE SCENE (planet, moon, ship)
//==============================================================================

planet_x_lo:
    .fill 256, <(200 + round(90 * sin(toRadians(i * 360 / 256))))
planet_x_hi:
    .fill 256, >(200 + round(90 * sin(toRadians(i * 360 / 256))))
planet_y:
    .fill 256, 128 + round(10 * sin(toRadians(i * 360 / 256)))
ship_y_tab:
    .fill 256, 150 + round(14 * sin(toRadians(i * 360 / 256)))
orbit_dx:
    .fill 256, round(40 + 40 * cos(toRadians(i * 360 / 256)))
orbit_dy:
    .fill 256, round(8 + 8 * sin(toRadians(i * 360 / 256)))

// Shadows copied to the VIC by irq_mid.
// Slots: 0 ship, 1 flame, 2 moon (front), 3-6 planet, 7 moon (behind)
mid_xlo:    .fill 8, 0
mid_xhi:    .fill 8, 0
mid_y:      .fill 8, 0
mid_ptr:
    .byte PTR_SHIP, PTR_FLAME, PTR_MOON
    .byte PTR_PLANET, PTR_PLANET + 1, PTR_PLANET + 2, PTR_PLANET + 3
    .byte PTR_MOON
mid_col:
    .byte COLOR_LIGHT_GREY, COLOR_YELLOW, COLOR_GREY
    .fill 4, PLANET_MID
    .byte COLOR_GREY
mid_msb:    .byte 0
mid_en:     .byte 0

flame_colors:
    .byte COLOR_YELLOW, COLOR_ORANGE

//==============================================================================
// BARS
//==============================================================================

// One $d021 value per line from 194 to 250, read by irq_bars
bar_buf:
    .fill BAR_COUNT, 0

horizon_colors:
    .byte COLOR_BLACK, COLOR_BLUE, COLOR_LIGHT_BLUE, COLOR_CYAN, COLOR_WHITE
    .byte COLOR_CYAN, COLOR_LIGHT_BLUE, COLOR_BLUE, COLOR_BLACK

// Bar peaks stay off white, so the white letters always read against them
bar_grads:
    .byte COLOR_BROWN, COLOR_RED, COLOR_ORANGE, COLOR_LIGHT_RED, COLOR_YELLOW
    .byte COLOR_LIGHT_RED, COLOR_ORANGE, COLOR_RED, COLOR_BROWN
    .byte COLOR_BLUE, COLOR_PURPLE, COLOR_LIGHT_BLUE, COLOR_LIGHT_BLUE, COLOR_CYAN
    .byte COLOR_LIGHT_BLUE, COLOR_LIGHT_BLUE, COLOR_PURPLE, COLOR_BLUE
    .byte COLOR_DARK_GREY, COLOR_GREEN, COLOR_GREEN, COLOR_LIGHT_GREEN, COLOR_LIGHT_GREEN
    .byte COLOR_LIGHT_GREEN, COLOR_GREEN, COLOR_GREEN, COLOR_DARK_GREY
bar_grad_ofs:
    .byte 0, 9, 18
bar_phase:
    .byte 0, 85, 170
bar_speed:
    .byte 2, 3, 1

//==============================================================================
// STARS
//==============================================================================

row_lo:
    .fill STAR_ROWS, <(SCREEN_RAM + i * 40)
row_hi:
    .fill STAR_ROWS, >(SCREEN_RAM + i * 40)

star_lo:    .fill NUM_STARS, 0
star_hi:    .fill NUM_STARS, 0
star_bgl:   .fill NUM_STARS, 0      // the star's row in bg_chars
star_bgh:   .fill NUM_STARS, 0
star_base:  .fill NUM_STARS, 0      // STAR_CHAR + 8 * its pixel row
star_col:   .fill NUM_STARS, 0
star_sub:   .fill NUM_STARS, 0
star_color: .fill NUM_STARS, 0
star_layer:                         // 0 slow/dim, 1 medium, 2 fast/bright
    .byte 0, 2, 1, 0, 1, 2, 0, 1, 0, 2, 1, 0, 2, 1, 0, 1, 2
.errorif star_layer + NUM_STARS != * , "star_layer needs NUM_STARS entries"

layer_color:
    .byte COLOR_DARK_GREY, COLOR_GREY, COLOR_WHITE
layer_step:                         // pixels this frame; [0] set per frame
    .byte 0, 1, 2

bg_row_lo:
    .fill STAR_ROWS, <(bg_chars + i * 40)
bg_row_hi:
    .fill STAR_ROWS, >(bg_chars + i * 40)

twinkle_glyphs:
    .byte $00, $10, $10, $7c, $10, $10, $00, $00    // TWINKLE_BIG: plus
    .byte $00, $00, $10, $38, $10, $00, $00, $00    // TWINKLE_SMALL

.var TWINKLES = List().add(
    List().add(1, 5),   List().add(3, 30),  List().add(5, 17),
    List().add(7, 36),  List().add(9, 8),   List().add(10, 25),
    List().add(12, 2),  List().add(13, 33), List().add(15, 14),
    List().add(16, 28))
.errorif TWINKLES.size() != NUM_TWINKLE, "TWINKLES needs NUM_TWINKLE entries"
tw_lo:
    .fill NUM_TWINKLE, <(SCREEN_RAM + TWINKLES.get(i).get(0) * 40 + TWINKLES.get(i).get(1))
tw_hi:
    .fill NUM_TWINKLE, >(SCREEN_RAM + TWINKLES.get(i).get(0) * 40 + TWINKLES.get(i).get(1))
tw_phase:
    .byte 0, 7, 13, 20, 26, 3, 17, 10, 23, 29

// 32 steps: dark for most of them, then a flash up to white and back
tw_color_tab:
    .fill 18, COLOR_BLACK
    .byte COLOR_DARK_GREY, COLOR_GREY, COLOR_LIGHT_GREY, COLOR_WHITE, COLOR_WHITE
    .byte COLOR_WHITE, COLOR_LIGHT_GREY, COLOR_GREY, COLOR_DARK_GREY
    .fill 5, COLOR_BLACK
tw_char_tab:
    .fill 20, TWINKLE_SMALL
    .fill 5, TWINKLE_BIG
    .fill 7, TWINKLE_SMALL

//==============================================================================
// BACKGROUND STARS
// The fixed dim stars of rows 0-16, one char and one color per cell, laid out
// at assembly time from a fixed seed (so every build is the same sky).
// bg_colors is exactly $300 after bg_chars: update_stars relies on that.
//==============================================================================

.const BG_STARS = 48
.var BG_COLOR_CHOICES = List().add(COLOR_DARK_GREY, COLOR_BLUE, COLOR_DARK_GREY,
                                   COLOR_GREY, COLOR_PURPLE, COLOR_DARK_GREY)
.var bgChars = List()
.var bgColors = List()
.for (var i = 0; i < STAR_ROWS * 40; i++) {
    .eval bgChars.add(BLANK)
    .eval bgColors.add(COLOR_BLACK)
}
.var seedv = 4242
.for (var n = 0; n < BG_STARS; n++) {
    .eval seedv = mod(seedv * 75 + 74, 65537)
    .var cell = mod(seedv, STAR_ROWS * 40)
    .eval seedv = mod(seedv * 75 + 74, 65537)
    .eval bgChars.set(cell, STAR_CHAR + mod(seedv, 64))
    .eval seedv = mod(seedv * 75 + 74, 65537)
    .eval bgColors.set(cell, BG_COLOR_CHOICES.get(mod(seedv, BG_COLOR_CHOICES.size())))
}

// The twinkle cells hold a dark TWINKLE_SMALL, never a star char, so a moving
// star leaving one restores the twinkle - and update_twinkle, which skips
// cells holding a star char ($40-$7f), is never locked out of its own cell.
.for (var n = 0; n < NUM_TWINKLE; n++) {
    .var cell = TWINKLES.get(n).get(0) * 40 + TWINKLES.get(n).get(1)
    .eval bgChars.set(cell, TWINKLE_SMALL)
    .eval bgColors.set(cell, COLOR_BLACK)
}

.align $100
bg_chars:
    .fill STAR_ROWS * 40, bgChars.get(i)
    .fill $300 - STAR_ROWS * 40, 0
bg_colors:
    .fill STAR_ROWS * 40, bgColors.get(i)
.errorif bg_colors - bg_chars != $300, "bg_colors must be bg_chars + $300"

//==============================================================================
// SCROLL TEXT
//==============================================================================

text_buffer:
    .fill 40, $20

// Demo name and date, shown in the scroller (lowercase: screen codes 1-26).
.const DEMO_NAME   = "stardust"
.const DEMO_AUTHOR = "retrodubtrva"
.const DEMO_DATE   = "2026-10-09"

// Screen codes; $ff marks the end. Only codes 0-63 have glyphs.
scroll_text:
    .text "          welcome aboard the stardust ...   "
    .text DEMO_NAME + " by " + DEMO_AUTHOR + ", created " + DEMO_DATE + " ...   "
    .text "a space scroller for the commodore 64, built ntsc first ...   "
    .text "dycp letters riding copper bars, a ringed planet with an "
    .text "orbiting moon, parallax stars and a lone ship ...   "
    .text "music: "
    .text music.name
    .text " by "
    .text music.author
    .text " ...   written by " + DEMO_AUTHOR + " ...   "
    .text "press run/stop to exit ...   "
    .text "greetings to everyone still coding on the breadbin!"
    .text "   ... " + DEMO_NAME + " - " + DEMO_DATE
    .text "                              "
    .byte $ff

//==============================================================================
// SPRITE ART ($3200-$33ff), generated at assembly time
//==============================================================================

// Ringed planet, 48 x 42 in 2x2 multicolor sprites. Returns the bit pair:
// 0 transparent, 1 dark ($d025), 2 own color, 3 light ($d026).
// Lit from the upper left, with faint bands, 2x2 ordered dither between
// levels. The ring passes in front of the lower half of the globe.
.function planetPix(mx, y) {
    .var rx = mx * 2 + 1 - 24           // hires x of the pixel's centre
    .var ry = y + 0.5 - 21
    .var ringY = ry - rx * 0.22         // tilted ring plane
    .var e = (rx / 23) * (rx / 23) + (ringY / 5.5) * (ringY / 5.5)
    .var d2 = (rx * rx + ry * ry) / (14 * 14)
    .if (e > 0.55 && e < 1.0) {
        .if (d2 > 1.0) .return 2        // ring against space
        .if (ringY > 0) .return 1       // ring in front of the globe
    }
    .if (d2 > 1.0) .return 0
    .var nx = rx / 14
    .var ny = ry / 14
    .var nz = sqrt(1 - d2)
    .var lit = -0.55 * nx - 0.45 * ny + 0.70 * nz + 0.12 * sin(ny * 9)
    .var dither = List().add(0.0, 0.5, 0.75, 0.25).get((mx & 1) + 2 * (y & 1))
    .var level = floor((lit + 0.2) * 2.4 + dither - 0.25)
    .return max(1, min(3, level + 1))
}

// Moon, hires: lit from the upper left like the planet, dithered night side
.function moonPix(x, y) {
    .var rx = x + 0.5 - 12
    .var ry = y + 0.5 - 10.5
    .if (rx * rx + ry * ry > 30) .return 0
    .if (rx > 1.5 && ((x + y) & 1) == 1) .return 0
    .if ((rx + 1.5) * (rx + 1.5) + (ry + 1) * (ry + 1) < 2.5) .return 0
    .return 1
}

// 21 rows of 24 characters, '#' = pixel set
.macro SpriteFromArt(rows) {
    .errorif rows.size() != 21, "sprite art needs 21 rows"
    .for (var r = 0; r < 21; r++) {
        .var line = rows.get(r)
        .errorif line.size() != 24, "sprite art row " + r + " is not 24 wide"
        .for (var b = 0; b < 3; b++) {
            .var v = 0
            .for (var k = 0; k < 8; k++) {
                .eval v = v * 2
                .if (line.charAt(b * 8 + k) == "#") .eval v = v + 1
            }
            .byte v
        }
    }
    .byte 0
}

.const EMPTY_ROW = "........................"

.var SHIP_ART = List().add(
    EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW,
    "......##................",
    "......####..............",
    "......######............",
    ".....##########.........",
    "....####...######.......",
    "...######.##..########..",
    "...####################.",
    "...######.##..########..",
    "....####...######.......",
    ".....##########.........",
    "......######............",
    "......####..............",
    "......##................",
    EMPTY_ROW, EMPTY_ROW, EMPTY_ROW, EMPTY_ROW)

.var FLAME_A = List()
.var FLAME_B = List()
.for (var r = 0; r < 21; r++) {
    .eval FLAME_A.add(EMPTY_ROW)
    .eval FLAME_B.add(EMPTY_ROW)
}
.eval FLAME_A.set(9,  "..##....................")
.eval FLAME_A.set(10, "####....................")
.eval FLAME_A.set(11, "..##....................")
.eval FLAME_B.set(9,  "...#....................")
.eval FLAME_B.set(10, ".###....................")
.eval FLAME_B.set(11, "...#....................")

* = ART_SPRITES "Sprite Art"

// PTR_PLANET + 0..3: top-left, top-right, bottom-left, bottom-right
.for (var s = 0; s < 4; s++) {
    .var sx = (s & 1) * 12
    .var sy = floor(s / 2) * 21
    .for (var r = 0; r < 21; r++) {
        .for (var b = 0; b < 3; b++) {
            .var v = 0
            .for (var k = 0; k < 4; k++) {
                .eval v = v * 4 + planetPix(sx + b * 4 + k, sy + r)
            }
            .byte v
        }
    }
    .byte 0
}

SpriteFromArt(SHIP_ART)             // PTR_SHIP
SpriteFromArt(FLAME_A)              // PTR_FLAME
SpriteFromArt(FLAME_B)              // PTR_FLAME + 1

.for (var r = 0; r < 21; r++) {     // PTR_MOON
    .for (var b = 0; b < 3; b++) {
        .var v = 0
        .for (var k = 0; k < 8; k++) {
            .eval v = v * 2 + moonPix(b * 8 + k, r)
        }
        .byte v
    }
}
.byte 0
