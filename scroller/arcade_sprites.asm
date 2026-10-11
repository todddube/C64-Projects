//==============================================================================
// FILE:        arcade_sprites.asm
// PROJECT:     STARDUST - imported by scroller.asm, not buildable on its own
// DESCRIPTION: The ARCADE part's 43 sprites at $3400-$3ebf, all generated at
//              assembly time: Pac-Man, ghosts, points, the Galaga fighter and
//              bugs, the Asteroids ship (16 headings), rocks and debris.
//==============================================================================

//------------------------------------------------------------------------------
// Builders
//------------------------------------------------------------------------------

// Hires sprite from text art, '#' = pixel. The art's top-left corner lands
// on (x0, y0) of the 24 x 21 sprite; rows may be any width up to 24.
.macro ArtSprite(rows, x0, y0) {
    .for (var r = 0; r < 21; r++) {
        .for (var b = 0; b < 3; b++) {
            .var v = 0
            .for (var k = 0; k < 8; k++) {
                .eval v = v * 2
                .var ar = r - y0
                .var ac = b * 8 + k - x0
                .if (ar >= 0 && ar < rows.size() && ac >= 0) {
                    .var line = rows.get(ar)
                    .if (ac < line.size()) {
                        .if (line.charAt(ac) == "#") .eval v = v + 1
                    }
                }
            }
            .byte v
        }
    }
    .byte 0
}

// Multicolor version, 12 columns: '.' transparent, 'W' $d025, 'B' the
// sprite's own color, 'P' $d026
.function mcPair(c) {
    .if (c == "W") .return 1
    .if (c == "B") .return 2
    .if (c == "P") .return 3
    .return 0
}
.macro ArtSpriteMC(rows, y0) {
    .for (var r = 0; r < 21; r++) {
        .for (var b = 0; b < 3; b++) {
            .var v = 0
            .for (var k = 0; k < 4; k++) {
                .eval v = v * 4
                .var ar = r - y0
                .if (ar >= 0 && ar < rows.size()) {
                    .eval v = v + mcPair(rows.get(ar).charAt(b * 4 + k))
                }
            }
            .byte v
        }
    }
    .byte 0
}

// A 21 x 24 grid of 0s, for line drawing
.function newGrid() {
    .var g = List()
    .for (var y = 0; y < 21; y++) {
        .var row = List()
        .for (var x = 0; x < 24; x++) .eval row.add(0)
        .eval g.add(row)
    }
    .return g
}
.macro GridPlot(g, x, y) {
    .var px = round(x)
    .var py = round(y)
    .if (px >= 0 && px < 24 && py >= 0 && py < 21) .eval g.get(py).set(px, 1)
}
.macro GridLine(g, x0, y0, x1, y1) {
    .var steps = ceil(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    .for (var i = 0; i <= steps; i++) {
        GridPlot(g, x0 + (x1 - x0) * i / steps, y0 + (y1 - y0) * i / steps)
    }
}
// Closed polygon through the points of pts (a List of [x, y])
.macro GridPoly(g, pts) {
    .for (var i = 0; i < pts.size(); i++) {
        .var a = pts.get(i)
        .var b = pts.get(mod(i + 1, pts.size()))
        GridLine(g, a.get(0), a.get(1), b.get(0), b.get(1))
    }
}
.macro GridSprite(g) {
    .for (var r = 0; r < 21; r++) {
        .for (var b = 0; b < 3; b++) {
            .var v = 0
            .for (var k = 0; k < 8; k++) .eval v = v * 2 + g.get(r).get(b * 8 + k)
            .byte v
        }
    }
    .byte 0
}

//------------------------------------------------------------------------------
// Art
//------------------------------------------------------------------------------

// Pac-Man: a 13-pixel disc centered on (11.5, 8), mouth half-angle in
// degrees, facing 0 (right) or 180 (left)
.function pacPix(x, y, face, mouth) {
    .var dx = x + 0.5 - 12
    .var dy = y + 0.5 - 8.5
    .var r2 = dx * dx + dy * dy
    .if (r2 > 6.6 * 6.6) .return 0
    .if (mouth == 0 || r2 < 1.2) .return 1
    .var a = toDegrees(atan2(-dy, dx))
    .var d = abs(a - face)
    .if (d > 180) .eval d = 360 - d
    .if (d < mouth) .return 0
    .return 1
}
.macro PacSprite(face, mouth) {
    .for (var r = 0; r < 21; r++) {
        .for (var b = 0; b < 3; b++) {
            .var v = 0
            .for (var k = 0; k < 8; k++) .eval v = v * 2 + pacPix(b * 8 + k, r, face, mouth)
            .byte v
        }
    }
    .byte 0
}

.var GHOST_TOP = List().add(
    "....BBBB....",
    "...BBBBBB...",
    "..BBBBBBBB..").lock()
.var GHOST_EYES_R = List().add(
    "..BWWBBWWB..",
    "..BWPBBWPB..",
    "..BWPBBWPB..",
    "..BWWBBWWB..").lock()
.var GHOST_EYES_L = List().add(
    "..BWWBBWWB..",
    "..BPWBBPWB..",
    "..BPWBBPWB..",
    "..BWWBBWWB..").lock()
.var FRIGHT_FACE = List().add(
    "..BBBBBBBB..",
    "..BBWBBWBB..",
    "..BBBBBBBB..",
    "..BBBBBBBB..",
    "..BBWBWBWB..",
    "..BWBWBWBB..").lock()
.var GHOST_BODY = List().add(
    "..BBBBBBBB..",
    "..BBBBBBBB..",
    "..BBBBBBBB..",
    "..BBBBBBBB..",
    "..BBBBBBBB..").lock()
.var FRIGHT_BODY = List().add(
    "..BBBBBBBB..",
    "..BBBBBBBB..",
    "..BBBBBBBB..").lock()
.var SKIRT_A = List().add("..BB.BB.BB..").lock()
.var SKIRT_B = List().add("..B..BB..B..").lock()

.function joinLists(a, b, c, d) {
    .var out = List()
    .for (var i = 0; i < a.size(); i++) .eval out.add(a.get(i))
    .for (var i = 0; i < b.size(); i++) .eval out.add(b.get(i))
    .for (var i = 0; i < c.size(); i++) .eval out.add(c.get(i))
    .for (var i = 0; i < d.size(); i++) .eval out.add(d.get(i))
    .return out
}

// 3 x 5 digits for the ghost points
.var DIGIT_ART = List().add(
    List().add("###", "#.#", "#.#", "#.#", "###"),      // 0
    List().add(".#.", "##.", ".#.", ".#.", "###"),      // 1
    List().add("###", "..#", "###", "#..", "###"),      // 2
    List().add("###", "..#", "###", "..#", "###"),      // 3
    List().add("#.#", "#.#", "###", "..#", "..#"),      // 4
    List().add("###", "#..", "###", "..#", "###"),      // 5
    List().add("###", "#..", "###", "#.#", "###"),      // 6
    List().add("###", "..#", "..#", "..#", "..#"),      // 7
    List().add("###", "#.#", "###", "#.#", "###"),      // 8
    List().add("###", "#.#", "###", "..#", "###")).lock()      // 9
.function numberArt(n) {
    .var digits = List()                // least significant first
    .var v = n
    .for (; v > 0; ) {
        .eval digits.add(mod(v, 10))
        .eval v = floor(v / 10)
    }
    .var rows = List()
    .for (var r = 0; r < 5; r++) {
        .var line = ""
        .for (var i = digits.size() - 1; i >= 0; i--) {
            .eval line = line + DIGIT_ART.get(digits.get(i)).get(r) + "."
        }
        .eval rows.add(line)
    }
    .return rows
}

.var BULLET = List().add("##", "##", "##", "##").lock()
.var DOT = List().add("##", "##").lock()

.var FIGHTER = List().add(
    ".......#.......",
    ".......#.......",
    "......###......",
    "......###......",
    "..#...###...#..",
    "..#..#####..#..",
    "..#.#######.#..",
    "..###########..",
    ".#############.",
    "###############",
    "###.#######.###",
    "##...#.#.#...##",
    "#.....#.#.....#").lock()

.var BEE_A = List().add(
    "..#.......#..",
    "...#.....#...",
    "....#####....",
    "..#########..",
    ".##.#####.##.",
    "####.###.####",
    "#############",
    "##..#####..##",
    "#....###....#",
    ".....###.....",
    "......#......").lock()
.var BEE_B = List().add(
    "..#.......#..",
    "...#.....#...",
    "....#####....",
    "#.#########.#",
    "###.#####.###",
    ".###.###.###.",
    "..#########..",
    "....#####....",
    ".....###.....",
    ".....###.....",
    "......#......").lock()
.var BFLY_A = List().add(
    "....#.....#....",
    ".....#...#.....",
    "##....###....##",
    "###..#####..###",
    "####.#####.####",
    ".#############.",
    "..###########..",
    ".#############.",
    "####.#####.####",
    "###...###...###",
    "##.....#.....##").lock()
.var BFLY_B = List().add(
    "....#.....#....",
    ".....#...#.....",
    "......###......",
    ".#...#####...#.",
    "###..#####..###",
    "###############",
    "..###########..",
    "###############",
    "###..#####..###",
    ".#....###....#.",
    "...............").lock()

//------------------------------------------------------------------------------
// The sprites. Pointer = ARC_PTR + the SP_ constant in arcade.asm, so the
// order here must match those constants.
//------------------------------------------------------------------------------

* = ARC_SPRITES "Arcade Sprites"

.errorif * != ARC_SPRITES + SP_PAC_R0 * 64, "SP_PAC_R0 out of step"
PacSprite(0, 40)                    // SP_PAC_R0: wide open, right
PacSprite(0, 20)                    // SP_PAC_R1: half open
PacSprite(0, 0)                     // SP_PAC_C: closed
PacSprite(180, 40)                  // SP_PAC_L0
PacSprite(180, 20)                  // SP_PAC_L1

.errorif * != ARC_SPRITES + SP_GHOST_R * 64, "SP_GHOST_R out of step"
ArtSpriteMC(joinLists(GHOST_TOP, GHOST_EYES_R, GHOST_BODY, SKIRT_A), 2)
ArtSpriteMC(joinLists(GHOST_TOP, GHOST_EYES_R, GHOST_BODY, SKIRT_B), 2)
ArtSpriteMC(joinLists(GHOST_TOP, GHOST_EYES_L, GHOST_BODY, SKIRT_A), 2)
ArtSpriteMC(joinLists(GHOST_TOP, GHOST_EYES_L, GHOST_BODY, SKIRT_B), 2)
ArtSpriteMC(joinLists(GHOST_TOP, FRIGHT_FACE, FRIGHT_BODY, SKIRT_A), 2)
ArtSpriteMC(joinLists(GHOST_TOP, FRIGHT_FACE, FRIGHT_BODY, SKIRT_B), 2)

.errorif * != ARC_SPRITES + SP_PTS * 64, "SP_PTS out of step"
ArtSprite(numberArt(200), 6, 6)
ArtSprite(numberArt(400), 6, 6)
ArtSprite(numberArt(800), 6, 6)
ArtSprite(numberArt(1600), 4, 6)

.errorif * != ARC_SPRITES + SP_BULLET * 64, "SP_BULLET out of step"
ArtSprite(BULLET, 11, 8)            // SP_BULLET: Galaga shot
ArtSprite(DOT, 11, 9)               // SP_DOT: Asteroids shot, on the center
ArtSprite(FIGHTER, 4, 4)            // SP_FIGHTER
ArtSprite(BEE_A, 5, 0)              // SP_BEE
ArtSprite(BEE_B, 5, 0)
ArtSprite(BFLY_A, 4, 0)             // SP_BFLY
ArtSprite(BFLY_B, 4, 0)

// SP_SHIP: the Asteroids ship at 16 headings, clockwise from straight up,
// rotated about (11.5, 10)
.errorif * != ARC_SPRITES + SP_SHIP * 64, "SP_SHIP out of step"
.for (var h = 0; h < 16; h++) {
    .var a = toRadians(h * 22.5)
    .var shape = List().add(List().add(0, -8), List().add(-6, 7),
                            List().add(0, 4), List().add(6, 7))
    .var pts = List()
    .for (var i = 0; i < shape.size(); i++) {
        .var sx = shape.get(i).get(0)
        .var sy = shape.get(i).get(1)
        .eval pts.add(List().add(11.5 + sx * cos(a) - sy * sin(a),
                                 10 + sx * sin(a) + sy * cos(a)))
    }
    .var g = newGrid()
    GridPoly(g, pts)
    GridSprite(g)
}

// SP_ROCK: three lumpy outlines, 10 vertices each
.errorif * != ARC_SPRITES + SP_ROCK * 64, "SP_ROCK out of step"
.var ROCK_SHAPES = List().add(
    List().add(9.5, 8.0, 9.5, 7.0, 9.0, 9.5, 6.5, 9.5, 8.5, 9.0),
    List().add(8.0, 9.5, 9.5, 8.5, 6.0, 9.0, 9.5, 8.0, 9.5, 7.0),
    List().add(6.0, 5.0, 6.5, 6.0, 4.5, 6.5, 6.0, 5.0, 6.5, 6.0)).lock()
.for (var s = 0; s < 3; s++) {
    .var radii = ROCK_SHAPES.get(s)
    .var pts = List()
    .for (var i = 0; i < 10; i++) {
        .var a = toRadians(i * 36 + 10)
        .eval pts.add(List().add(11.5 + radii.get(i) * 1.15 * cos(a),
                                 10 + radii.get(i) * sin(a)))
    }
    .var g = newGrid()
    GridPoly(g, pts)
    GridSprite(g)
}

// SP_EXPL: debris, two frames flying apart
.errorif * != ARC_SPRITES + SP_EXPL * 64, "SP_EXPL out of step"
.for (var f = 0; f < 2; f++) {
    .var g = newGrid()
    .for (var i = 0; i < 12; i++) {
        .var a = toRadians(i * 30 + 7 * f + mod(i * 37, 11))
        .var r = (f == 0 ? 3.5 : 7.5) + mod(i * 5, 3)
        GridPlot(g, 11.5 + r * 1.2 * cos(a), 10 + r * sin(a))
        GridPlot(g, 12.5 + r * 1.2 * cos(a), 10 + r * sin(a))
    }
    GridSprite(g)
}

.errorif * != ARC_SPRITES + SP_COUNT * 64, "SP_COUNT out of step"
.errorif * > $3fc0, "arcade sprites run into $3fff, the VIC's idle byte"
