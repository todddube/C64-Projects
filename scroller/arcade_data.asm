//==============================================================================
// FILE:        arcade_data.asm
// PROJECT:     STARDUST - imported by scroller.asm, not buildable on its own
// DESCRIPTION: The ARCADE part's tables: custom chars, the static screen,
//              the formation, motion tables, sprite shadows and scroll text.
//==============================================================================

//==============================================================================
// SCRIPT HELPERS
//==============================================================================

// Screen code of a character: its index in ALPHA (codes 0-63; '~' marks
// the ones no text here uses)
.var ALPHA = "@abcdefghijklmnopqrstuvwxyz[~]^~ !~#$%&'()*+,-./0123456789:;<=>?"
.errorif ALPHA.size() != 64, "ALPHA must list screen codes 0-63"
.function scr(ch) {
    .for (var i = 0; i < 64; i++) {
        .if (ALPHA.charAt(i) == ch) .return i
    }
    .return ARC_BLANK
}

// 8 pixels of a '#' art row, starting at column off
.function artByte(line, off) {
    .var v = 0
    .for (var k = 0; k < 8; k++) {
        .eval v = v * 2
        .if (line.charAt(off + k) == "#") .eval v = v + 1
    }
    .return v
}

//==============================================================================
// CUSTOM CHARS ($40-$7f)
//==============================================================================

// Galaxian aliens, 16 x 8 (two chars), two frames each
.var ALIENS = List().add(
    List().add(                     // flagship
        List().add("......####......", "...#.######.#...", "..############..",
                   ".##.#.####.#.##.", "################", "##.##########.##",
                   "#...##....##...#", "....#......#...."),
        List().add("......####......", ".#..########..#.", "..############..",
                   ".##.#.####.#.##.", "################", ".#.##########.#.",
                   "...##......##...", "..##........##..")),
    List().add(                     // escort
        List().add("#......##......#", "##....####....##", ".##..######..##.",
                   "..############..", "...##.####.##...", "....########....",
                   "....#..##..#....", "...#........#..."),
        List().add("......####......", "..#..######..#..", ".##.########.##.",
                   "################", "#..##.####.##..#", "....########....",
                   ".....#.##.#.....", "......#..#......")),
    List().add(                     // drone
        List().add("......#..#......", ".......##.......", "..#..######..#..",
                   ".##.########.##.", "##.##.####.##.##", "#...########...#",
                   "....#..##..#....", "...#........#..."),
        List().add("......#..#......", ".......##.......", ".....######.....",
                   "..#.########.#..", ".##.#.####.#.##.", "################",
                   "#..#...##...#..#", "...#........#..."))).lock()

// Chars $40-$45 for one frame: type t's left half at $40 + 2t, right half
// at $41 + 2t
.function alienChars(f) {
    .var out = List()
    .for (var t = 0; t < 3; t++) {
        .for (var half = 0; half < 2; half++) {
            .for (var r = 0; r < 8; r++) {
                .eval out.add(artByte(ALIENS.get(t).get(f).get(r), half * 8))
            }
        }
    }
    .return out
}

.var glyphs = List()
.for (var i = 0; i < 64 * 8; i++) .eval glyphs.add(0)
.macro SetGlyph(code, bytes) {
    .for (var j = 0; j < 8; j++) .eval glyphs.set((code - $40) * 8 + j, bytes.get(j))
}
.var frame0 = alienChars(0)
.for (var i = 0; i < 48; i++) .eval glyphs.set(i, frame0.get(i))
SetGlyph(CH_WALL,   List().add($00, $ff, $00, $00, $00, $00, $ff, $00))
SetGlyph(CH_DOT_T,  List().add($00, $00, $00, $00, $00, $00, $00, $18))
SetGlyph(CH_DOT_B,  List().add($18, $00, $00, $00, $00, $00, $00, $00))
SetGlyph(CH_PILL_T, List().add($00, $00, $00, $00, $18, $3c, $7e, $7e))
SetGlyph(CH_PILL_B, List().add($7e, $7e, $3c, $18, $00, $00, $00, $00))
SetGlyph(ARC_SOLID, List().add($ff, $ff, $ff, $ff, $ff, $ff, $ff, $ff))

// Copied to $0a00 by build_arc_font
arc_glyphs:
    .fill 64 * 8, glyphs.get(i)

// Both frames, copied over $40-$45 by arc_formation every 16 frames
alien_frames:
    .var frame1 = alienChars(1)
    .fill 48, frame0.get(i)
    .fill 48, frame1.get(i)

//==============================================================================
// THE STATIC SCREEN (copied in by arc_init)
//==============================================================================

.var arcChars = List()
.var arcCols = List()
.for (var i = 0; i < 1000; i++) {
    .eval arcChars.add(ARC_BLANK)
    .eval arcCols.add(COLOR_BLACK)
}
.macro PutText(row, col, text, color) {
    .for (var i = 0; i < text.size(); i++) {
        .eval arcChars.set(row * 40 + col + i, scr(text.charAt(i)))
        .eval arcCols.set(row * 40 + col + i, color)
    }
}
.macro PutChars(row, col0, col1, code, color) {
    .for (var c = col0; c <= col1; c++) {
        .eval arcChars.set(row * 40 + c, code)
        .eval arcCols.set(row * 40 + c, color)
    }
}
.macro PutColors(row, col0, col1, color) {
    .for (var c = col0; c <= col1; c++) .eval arcCols.set(row * 40 + c, color)
}

PutText(0, 3, "1up", COLOR_RED)
PutText(0, 14, "high score", COLOR_RED)
PutText(1, 1, "000000", COLOR_WHITE)
PutText(1, 16, "010000", COLOR_WHITE)
PutText(9, 12, "galaxian 1979 * galaga 1981", COLOR_DARK_GREY)
PutText(17, 1, "asteroids 1979", COLOR_DARK_GREY)
PutText(17, 27, "pac-man 1980", COLOR_DARK_GREY)

// The formation's chars are drawn by arc_formation; its colors are fixed,
// one per row, so they don't have to move with it
.var FORM_COLORS = List().add(COLOR_YELLOW, COLOR_RED, COLOR_PURPLE, COLOR_LIGHT_BLUE).lock()
.for (var r = 0; r < 4; r++) PutColors(FORM_ROW + r, 0, 39, FORM_COLORS.get(r))

// The corridor
PutChars(ROW_DOTS - 1, 0, 39, CH_WALL, COLOR_BLUE)
PutChars(ROW_DOTS + 2, 0, 39, CH_WALL, COLOR_BLUE)
PutChars(ROW_DOTS, 1, PILL_COL - 1, CH_DOT_T, COLOR_LIGHT_RED)
PutChars(ROW_DOTS + 1, 1, PILL_COL - 1, CH_DOT_B, COLOR_LIGHT_RED)
PutChars(ROW_DOTS, PILL_COL, PILL_COL, CH_PILL_T, COLOR_WHITE)
PutChars(ROW_DOTS + 1, PILL_COL, PILL_COL, CH_PILL_B, COLOR_WHITE)

arc_scr:
    .fill 1000, arcChars.get(i)
arc_col:
    .fill 1000, arcCols.get(i)

//==============================================================================
// THE FORMATION
// Galaxian's: 2 flagships, 6 escorts, 8 + 10 drones. Slot s (0-9) of a row
// is screen columns 1 + 3s and 2 + 3s at column offset 0. Each row is
// padded with 10 blanks on the left: at offset c, screen column x shows
// form_img[x + 10 - c].
//==============================================================================

.var FORM_SLOTS = List().add(
    List().add(3, 6),
    List().add(2, 3, 4, 5, 6, 7),
    List().add(1, 2, 3, 4, 5, 6, 7, 8),
    List().add(0, 1, 2, 3, 4, 5, 6, 7, 8, 9)).lock()
.var FORM_TYPES = List().add(0, 1, 2, 2).lock()
form_img:
    .for (var r = 0; r < 4; r++) {
        .var img = List()
        .for (var j = 0; j < 50; j++) .eval img.add(ARC_BLANK)
        .var slots = FORM_SLOTS.get(r)
        .for (var n = 0; n < slots.size(); n++) {
            .var j = 11 + 3 * slots.get(n)
            .eval img.set(j, CH_ALIEN + 2 * FORM_TYPES.get(r))
            .eval img.set(j + 1, CH_ALIEN + 2 * FORM_TYPES.get(r) + 1)
        }
        .fill 50, img.get(i)
    }

// Sway, 0-72 pixels: offset 0-9 columns plus the fine scroll
form_sway:
    .fill 256, round(36 - 36 * cos(toRadians(i * 360 / 256)))

//==============================================================================
// MOTION
//==============================================================================

// Galaga fighter, x in xs: a slow wander
fighter_x_tab:
    .fill 256, round(86 + 48 * sin(toRadians(i * 360 / 256)) + 14 * sin(toRadians(i * 3 * 360 / 256)))

// The bugs' figure eight in front of the formation
div_x:
    .fill 256, round(86 + 74 * sin(toRadians(i * 360 / 256)))
div_y:
    .fill 256, round(84 + 14 * sin(toRadians(i * 2 * 360 / 256)))

// Asteroids shot velocity per heading, 8.8: 2.5 pixels (1.25 xs) across,
// 2.5 lines down, a frame
.function word16(v) { .return mod(round(v) + 65536, 65536) }
ab_dxl_tab:
    .fill 16, <word16(256 * 1.25 * sin(toRadians(i * 22.5)))
ab_dxh_tab:
    .fill 16, >word16(256 * 1.25 * sin(toRadians(i * 22.5)))
ab_dyl_tab:
    .fill 16, <word16(-256 * 2.5 * cos(toRadians(i * 22.5)))
ab_dyh_tab:
    .fill 16, >word16(-256 * 2.5 * cos(toRadians(i * 22.5)))

rk_init_x:
    .byte 6, 36, 66, 96, 126, 156

// Pac-Man: chomp cycle, open-half-closed-half
pac_anim_r:
    .byte ARC_PTR + SP_PAC_R0, ARC_PTR + SP_PAC_R1, ARC_PTR + SP_PAC_C, ARC_PTR + SP_PAC_R1
pac_anim_l:
    .byte ARC_PTR + SP_PAC_L0, ARC_PTR + SP_PAC_L1, ARC_PTR + SP_PAC_C, ARC_PTR + SP_PAC_L1

// Ghosts: Blinky, Pinky, Inky, Clyde
ghost_off:                          // xs behind Pac-Man
    .byte 14, 26, 38, 50
ghost_col:
    .byte COLOR_RED, COLOR_LIGHT_RED, COLOR_CYAN, COLOR_ORANGE
ghost_bit:                          // their band C enable bits
    .byte %00000010, %00000100, %00001000, %00010000
alive_bit:
    .byte %00000001, %00000010, %00000100, %00001000
alive_off:
    .byte %11111110, %11111101, %11111011, %11110111
pts_bcd:                            // 200, 400, 800, 1600: the hundreds byte
    .byte $02, $04, $08, $16

// The scroller's rainbow, top half and a darker bottom half
scr_top_cols:
    .byte COLOR_WHITE, COLOR_YELLOW, COLOR_YELLOW, COLOR_ORANGE
    .byte COLOR_LIGHT_RED, COLOR_LIGHT_RED, COLOR_PURPLE, COLOR_LIGHT_BLUE
    .byte COLOR_CYAN, COLOR_CYAN, COLOR_LIGHT_GREEN, COLOR_LIGHT_GREEN
    .byte COLOR_YELLOW, COLOR_WHITE, COLOR_CYAN, COLOR_WHITE
scr_bot_cols:
    .byte COLOR_LIGHT_GREY, COLOR_ORANGE, COLOR_ORANGE, COLOR_RED
    .byte COLOR_RED, COLOR_RED, COLOR_BLUE, COLOR_BLUE
    .byte COLOR_LIGHT_BLUE, COLOR_LIGHT_BLUE, COLOR_GREEN, COLOR_GREEN
    .byte COLOR_ORANGE, COLOR_LIGHT_GREY, COLOR_LIGHT_BLUE, COLOR_LIGHT_GREY

//==============================================================================
// SPRITE SHADOWS: band b, sprite s at [b * 8 + s]. Copied by BandCopy.
//==============================================================================

sh_x:       .fill 24, 0
sh_xh:      .fill 24, 0             // X bit 8, packed into sh_msb
sh_y:       .fill 24, 0
sh_ptr:     .fill 24, 0
sh_col:     .fill 24, 0
sh_msb:     .fill 3, 0
sh_en:      .fill 3, 0
sh_mc:      .fill 3, 0

sh_ptr_init:
    .byte ARC_PTR + SP_FIGHTER, ARC_PTR + SP_BULLET, ARC_PTR + SP_BEE, ARC_PTR + SP_BFLY
    .fill 4, ARC_PTR + SP_BULLET
    .byte ARC_PTR + SP_SHIP, ARC_PTR + SP_DOT
    .fill 6, ARC_PTR + SP_ROCK
    .byte ARC_PTR + SP_PAC_R0
    .fill 4, ARC_PTR + SP_GHOST_R
    .byte ARC_PTR + SP_PTS, ARC_PTR + SP_BULLET, ARC_PTR + SP_BULLET
sh_col_init:
    .byte COLOR_WHITE, COLOR_WHITE, COLOR_YELLOW, COLOR_RED
    .fill 4, COLOR_BLACK
    .byte COLOR_WHITE, COLOR_WHITE
    .byte COLOR_LIGHT_GREY, COLOR_GREY, COLOR_LIGHT_GREY, COLOR_WHITE, COLOR_GREY, COLOR_LIGHT_GREY
    .byte COLOR_YELLOW, COLOR_RED, COLOR_LIGHT_RED, COLOR_CYAN, COLOR_ORANGE, COLOR_CYAN
    .fill 2, COLOR_BLACK
sh_y_init:
    .byte FIGHTER_Y
    .fill 7, 0
    .byte SHIP_Y
    .fill 7, 0
    .fill 6, PAC_Y
    .fill 2, 0
sh_mc_init:                         // the ghosts are multicolor
    .byte $00, $00, %00011110

//==============================================================================
// STATE
//==============================================================================

rk_xl:      .fill 6, 0
rk_xh:      .fill 6, 0
rk_yl:      .fill 6, 0
rk_yh:      .fill 6, 0
rk_vx:      .fill 6, 0              // signed, /256 xs a frame
rk_vy:      .fill 6, 0              // signed, /256 lines a frame
rk_ptr:     .fill 6, 0
rk_state:   .fill 6, 0              // 0 drifting, else frames of debris left

g_xl:       .fill 4, 0              // the frightened ghosts, 8.8 xs
g_xh:       .fill 4, 0
g_alive:    .byte 0
pac_eaten:  .byte 0
fright_t:   .byte 0
pts_x:      .byte 0
pac_lock:   .byte 0                 // the curtain covers the dots
a_wide:     .byte 0                 // $08 while the curtain falls, ORed into
                                    // the 38-column $d016 writes
a_hi:       .fill 3, 0              // high score, BCD

//==============================================================================
// SCROLL TEXT (screen codes 0-63, $ff ends it)
//==============================================================================

arc_text:
    .text "      insert coin ...   ready player one ...   "
    .text "retrodubtrva salutes the golden age of the arcade ...   "
    .text "galaxian (namco, 1979) ... asteroids (atari, 1979) ... "
    .text "pac-man (namco, 1980) ... galaga (namco, 1981) ...   "
    .text "wakka wakka wakka ...   watch out for the tractor beam ...   "
    .text "hyperspace is for cowards ...   one more credit ...   "
    .byte $ff
