//==================================================================
// INTRO_TEXT - the glyph rows for the logo, used twice
//
// Script-time data only: these lists are read by intro_gfx.asm while it
// carves the logo into the bitmap and by intro_sprites.asm while it
// builds the flying copy, and NONE of it reaches the .prg. There is no
// font in memory at run time - by then the letters are already pixels,
// in the bitmap and in the sprites.
//
// The rows were lifted once from the C64 character ROM's lower-case set
// (where $41-$5a are the capitals and 1-26 the lower case), so the logo is
// in the machine's own font rather than something hand-drawn. Bit 7 of
// each row is the leftmost pixel.
//
// NAME_CHARS must stay a multiple of 3 and at most 12: intro_sprites.asm
// packs 3 characters into each of 4 sprites.
//==================================================================

// "RetroDubTRVA" - 12 glyphs x 8 rows, lifted from the C64 character ROM
.var NAME_ROWS = List()
.eval NAME_ROWS.add($7c, $66, $66, $7c, $78, $6c, $66, $00)   // "R"
.eval NAME_ROWS.add($00, $00, $3c, $66, $7e, $60, $3c, $00)   // "e"
.eval NAME_ROWS.add($00, $18, $7e, $18, $18, $18, $0e, $00)   // "t"
.eval NAME_ROWS.add($00, $00, $7c, $66, $60, $60, $60, $00)   // "r"
.eval NAME_ROWS.add($00, $00, $3c, $66, $66, $66, $3c, $00)   // "o"
.eval NAME_ROWS.add($78, $6c, $66, $66, $66, $6c, $78, $00)   // "D"
.eval NAME_ROWS.add($00, $00, $66, $66, $66, $66, $3e, $00)   // "u"
.eval NAME_ROWS.add($00, $60, $60, $7c, $66, $66, $7c, $00)   // "b"
.eval NAME_ROWS.add($7e, $18, $18, $18, $18, $18, $18, $00)   // "T"
.eval NAME_ROWS.add($7c, $66, $66, $7c, $78, $6c, $66, $00)   // "R"
.eval NAME_ROWS.add($66, $66, $66, $66, $66, $3c, $18, $00)   // "V"
.eval NAME_ROWS.add($18, $3c, $66, $7e, $66, $66, $66, $00)   // "A"

// "2026-09-26" - 10 glyphs x 8 rows, lifted from the C64 character ROM
.var DATE_ROWS = List()
.eval DATE_ROWS.add($3c, $66, $06, $0c, $30, $60, $7e, $00)   // "2"
.eval DATE_ROWS.add($3c, $66, $6e, $76, $66, $66, $3c, $00)   // "0"
.eval DATE_ROWS.add($3c, $66, $06, $0c, $30, $60, $7e, $00)   // "2"
.eval DATE_ROWS.add($3c, $66, $60, $7c, $66, $66, $3c, $00)   // "6"
.eval DATE_ROWS.add($00, $00, $00, $7e, $00, $00, $00, $00)   // "-"
.eval DATE_ROWS.add($3c, $66, $6e, $76, $66, $66, $3c, $00)   // "0"
.eval DATE_ROWS.add($3c, $66, $66, $3e, $06, $66, $3c, $00)   // "9"
.eval DATE_ROWS.add($00, $00, $00, $7e, $00, $00, $00, $00)   // "-"
.eval DATE_ROWS.add($3c, $66, $06, $0c, $30, $60, $7e, $00)   // "2"
.eval DATE_ROWS.add($3c, $66, $60, $7c, $66, $66, $3c, $00)   // "6"

.const NAME_CHARS = 12
.const DATE_CHARS = 10
