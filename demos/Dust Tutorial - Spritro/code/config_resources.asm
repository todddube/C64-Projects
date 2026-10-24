//============================================================
// External binaries, loaded to fixed addresses
//============================================================

.label address_sprites = $2000     // 16 ship sprite frames
.label address_chars   = $3800     // charset (last 2K slot in VIC bank 0)
.label address_sprites2 = $2400    // shapes added in data_sprites.asm, right after the ship

// SpritePad .spr: 3 header bytes (colours) then 16 x 64 bytes
.var spr_file = LoadBinary("resources/sprites.spr")
* = address_sprites "Sprites"
.fill 16 * 64, spr_file.get(i + 3)

// PSID tune: LoadSid strips the header and places the data at the
// tune's own load address. The tutorial shipped empty_1000.sid
// (4-Mat's silent "Empty (512 bytes)" placeholder at $1001, still in
// resources/ for reference); this build plays "Nightshift" by
// Agemixer (Ari Yliaho, 2001), the repo's intro tune, which loads at
// $1000-$1d77 (init $1d70, play $1003), below the ship frames at
// $2000. It is a 50 Hz tune: see music_tick in main.asm for NTSC.
.var music = LoadSid("resources/Nightshift.sid")
* = music.location "SID"
.fill music.size, music.getData(i)
.errorif music.location + music.size > address_sprites, "the tune overlaps the ship sprites at $2000"

// CharPad .ctm: 24 byte header, then 48 chars x 8 bytes
.var font_file = LoadBinary("resources/rambo_font.ctm")
* = address_chars "Charset"
.fill 48 * 8, font_file.get(i + 24)
