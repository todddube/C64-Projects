//==================================================================
// MUSIC - PSID import of the intro tune
//
// Imported by main.asm. LoadSid reads the .sid file at assembly time and
// hands back the load address, the init entry and the play entry; the
// data is then emitted verbatim at the address the tune was written for
// (a PSID's player code is not relocatable, so it has to go there).
//
// Nightshift lands at $1000-$1d77, which is one reason main.asm's code
// segment does not start at the usual $0810 (it is at $4000, above the
// ball frames at $2000-$3fff). That range is invisible to
// the VIC in bank 0 - it sees character ROM at $1000-$1fff - so nothing
// graphical can live there anyway.
//
// The tune plays only during the intro. play_intro calls MUSIC_PLAY once
// per frame from its raster-locked loop, and hands the SID back to
// init_sound (the ping SFX) at the reveal.
//==================================================================

.var music = LoadSid("Nightshift.sid")

.label MUSIC_INIT = music.init
.label MUSIC_PLAY = music.play

* = music.location "Music"
.fill music.size, music.getData(i)

.print "Music: " + music.name + " by " + music.author
.print "  $" + toHexString(music.location) + "-$" + toHexString(music.location + music.size - 1)
.print "  init $" + toHexString(music.init) + "  play $" + toHexString(music.play)
