//============================================================
// Spritro Tutorial (Dust Tutorial Episode 3)
// Original code by actraiser/Dustlayer, 2013
// Tutorial: http://dustlayer.com/c64-coding-tutorials/2013/5/24/episode-3-1-spritro-an-intro-with-a-sprite
//
// Episodes 3-2 .. 3-9 on dustlayer.com walk through each file here
// (SpritePad shapes, ship movement, controls, CharPad font, pseudo
// timers for the colour cycle, relocating the SID).
//
// KickAssembler port for the RetroDubTRVA C64-Projects repo.
// index.asm beside this file is the original ACME index, kept verbatim
// for reference (ACME syntax, it does not build with KickAssembler; the
// pristine tutorial zip is here too). This file is its KickAssembler
// equivalent and the build entry point: it loads the same resources to
// the same addresses and imports code/*.asm in the same order, and it is
// named so the output is bin/dustlayer-spritro.prg, the name index.asm's
// "!to" line gives (KickAssembler names the .prg after the source file).
// Three fixes over the original, each commented where it lives:
// IRQ moved to line 20 (line 0 is inside the sprite on NTSC), the
// stale raster latch is cleared before cli, and the 9-bit X wrap no
// longer blanks the ship at x=256. SPACE or RUN/STOP exits by restoring
// the system and returning to BASIC (no reset). Known tutorial quirk kept as-is:
// the side-border colour switch in sub_color_cycle.asm never runs,
// because the colour run hits black before column 40 every frame.
//
// Memory map (as in the tutorial):
//   $0801  BASIC loader (SYS 49152)
//   $1001  SID tune (empty_1000.sid loads at $1001; init $11ed, play $1004)
//   $2000  16 ship sprite frames (16 x 64 bytes)
//   $3800  custom charset (48 chars from rambo_font.ctm)
//   $c000  code
//
// Build: python3 ~/.claude/skills/c64-toolchain/scripts/c64.py build dustlayer-spritro.asm
//============================================================

#import "code/config_resources.asm"

//------------------------------------------------------------
// BASIC loader: 2013 SYS 49152
//------------------------------------------------------------
BasicUpstart2(start)

//------------------------------------------------------------
// all 6502 code assembles consecutively from $c000
//------------------------------------------------------------
* = $c000 "Code"

#import "code/config_symbols.asm"
start:
#import "code/config_sprites.asm"      // falls through into main

// main routine with the custom interrupt
#import "code/main.asm"

// one-time subroutines
#import "code/sub_clear_screen.asm"
#import "code/sub_write_text.asm"

// subroutines called every frame from the IRQ
#import "code/sub_update_ship.asm"
#import "code/sub_check_keyboard.asm"
#import "code/sub_color_cycle.asm"

// data
#import "code/data_text.asm"
