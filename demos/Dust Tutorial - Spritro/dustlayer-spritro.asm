//============================================================
// Spritro Tutorial (Dust Tutorial Episode 3), extended
//
// Original code by actraiser/Dustlayer, 2013 (c) http://dustlayer.com
// Tutorial: http://dustlayer.com/c64-coding-tutorials/2013/5/24/episode-3-1-spritro-an-intro-with-a-sprite
// Episodes 3-2 .. 3-9 on dustlayer.com walk through each of the
// original files (SpritePad shapes, ship movement, controls, CharPad
// font, pseudo timers for the colour cycle, relocating the SID).
// Extensions and KickAssembler port by RetroDubTRVA, 2026.
//
// index.asm beside this file is the original ACME index, kept verbatim
// for reference (ACME syntax, it does not build with KickAssembler; the
// pristine tutorial zip is here too). This file is its KickAssembler
// equivalent and the build entry point: it loads the same resources to
// the same addresses and imports code/*.asm in the same order, with the
// added files after them. It is named so the output is
// bin/dustlayer-spritro.prg, the name index.asm's "!to" line gives
// (KickAssembler names the .prg after the source file).
//
// What the tutorial did: a tumbling ship sprite flies right to left
// over four lines of colour-cycled text in a custom font, with the
// top and bottom borders opened, the IRQ chained into the KERNAL's.
// U and D move the ship.
//
// What was added (each in its own code/sub_*.asm, see the IRQ in
// code/main.asm for the per-frame order):
//   - an exhaust flame sprite that trails the ship      (sub_flame)
//   - rockets: SPACE or the joystick 2 button fires,
//     two in flight at once                             (sub_rockets)
//   - asteroids drifting in from the left               (sub_asteroids)
//   - collisions: ship against the top and bottom walls,
//     rockets against rocks, rocks against the ship;
//     explosion animation, screen flash, respawn with a
//     blinking invulnerable spell                       (sub_collisions)
//   - SID sound effects for launches and explosions     (sub_sfx)
//   - joystick port 2 next to the keys                  (sub_check_keyboard)
//   - RUN/STOP exits to BASIC (SPACE used to)
//
// Fixes over the original, each commented where it lives: the stale
// raster latch is cleared before cli, the 9-bit X wrap no longer
// blanks the ship at x=256, and the exit restores the system and
// returns to BASIC instead of jumping to $ea81 from inside a JSR.
// Known tutorial quirk kept as-is: the side-border colour switch in
// sub_color_cycle.asm never runs.
//
// Memory map (as in the tutorial, plus the added shapes):
//   $0801  BASIC loader (SYS 49152)
//   $1001  SID tune (empty_1000.sid loads at $1001; init $11ed, play $1004;
//          kept in memory but not played, see PLAY_MUSIC in config_symbols)
//   $2000  16 ship sprite frames (16 x 64 bytes, pointers $80-$8f)
//   $2400  flame, rocket, asteroid and explosion shapes (pointers $90-$9a)
//   $3800  custom charset (48 chars from rambo_font.ctm)
//   $c000  code
//
// Target: NTSC first (frame IRQ at raster line 0, borders opened at 249),
// PAL works unchanged. Zero page: only $fb/$fc, as in the tutorial.
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

// subroutines called every frame from the IRQ (tutorial)
#import "code/sub_update_ship.asm"
#import "code/sub_check_keyboard.asm"
#import "code/sub_color_cycle.asm"

// subroutines called every frame from the IRQ (added)
#import "code/sub_flame.asm"
#import "code/sub_rockets.asm"
#import "code/sub_asteroids.asm"
#import "code/sub_collisions.asm"
#import "code/sub_sfx.asm"
#import "code/sub_random.asm"

// data
#import "code/data_text.asm"
#import "code/data_vars.asm"

// the added sprite shapes (their own segment at $2400)
#import "code/data_sprites.asm"
