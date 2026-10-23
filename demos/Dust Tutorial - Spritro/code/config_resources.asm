//============================================================
// External binaries, loaded to fixed addresses
//============================================================

.label address_sprites = $2000     // 16 ship sprite frames
.label address_chars   = $3800     // charset (last 2K slot in VIC bank 0)

// SpritePad .spr: 3 header bytes (colours) then 16 x 64 bytes
.var spr_file = LoadBinary("resources/sprites.spr")
* = address_sprites "Sprites"
.fill 16 * 64, spr_file.get(i + 3)

// PSID tune: LoadSid strips the header and places it at its own
// load address ($1000); init $11ed, play $1004
.var music = LoadSid("resources/empty_1000.sid")
* = music.location "SID"
.fill music.size, music.getData(i)

// CharPad .ctm: 24 byte header, then 48 chars x 8 bytes
.var font_file = LoadBinary("resources/rambo_font.ctm")
* = address_chars "Charset"
.fill 48 * 8, font_file.get(i + 24)
