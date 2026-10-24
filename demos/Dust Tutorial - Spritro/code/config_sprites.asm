//============================================================
// configuration of the sprites used in the intro
//   Sprite#0  the ship (the tutorial's only sprite)
//   Sprite#1  its exhaust flame        (added)
//   Sprite#2-3 rockets                 (added)
//   Sprite#4-7 asteroids               (added)
//============================================================

// zero page: current animation frame and the animation delay flag
.label sprite_ship_current_frame = $fb
.label delay_animation_pointer   = $fc

// number of frames (shapes) in the ship animation
.const sprite_frames_ship = 16

// sprite pointer for Sprite#0 ($2000 / 64 = $80)
.const sprite_pointer_ship = address_sprites / $40

// pointers of the shapes added in data_sprites.asm ($2400 / 64 = $90)
.const sprite_pointer_flame     = address_sprites2 / $40       // 4 shapes
.const sprite_pointer_rocket    = sprite_pointer_flame + 4     // 1 shape
.const sprite_pointer_asteroid  = sprite_pointer_rocket + 1    // 2 shapes
.const sprite_pointer_explosion = sprite_pointer_asteroid + 2  // 4 shapes

// shared sprite colours (also in the .spr header, written out by hand here)
.const sprite_background_color = $00
.const sprite_multicolor_1     = $0b
.const sprite_multicolor_2     = $01

// individual colour for Sprite#0
.const sprite_ship_color = $02

//============================================================
// Initialise memory locations not related to the VIC-II
//============================================================

lda #sprite_frames_ship
sta sprite_ship_current_frame

// sprite pointers are the last 8 bytes of screen RAM ($07f8-$07ff)
lda #sprite_pointer_ship
sta sprite_pointers
lda #sprite_pointer_flame
sta sprite_pointers + 1
lda #sprite_pointer_rocket
sta sprite_pointers + 2
sta sprite_pointers + 3

//============================================================
// Initialise the VIC-II sprite registers
//============================================================

lda #%00000011                  // enable Sprite#0 (ship) and #1 (flame);
sta $d015                       // rockets and asteroids switch on when live

lda #%11110011                  // multicolour for ship, flame and asteroids,
sta $d01c                       // hires for the two rockets

lda #$00                        // all sprites have priority over background
sta $d01b
sta $d017                       // no Y expansion
sta $d01d                       // no X expansion

lda #sprite_background_color    // shared background colour
sta $d021

lda #sprite_multicolor_1        // shared multicolour 1
sta $d025

lda #sprite_multicolor_2        // shared multicolour 2
sta $d026

lda #sprite_ship_color          // individual Sprite#0 colour
sta $d027
lda #FLAME_COLOR_A              // flame
sta $d028
lda #ROCKET_COLOR               // rockets
sta $d029
sta $d02a

lda #$01                        // X coordinate 9th bit for Sprite#0
sta $d010

lda #$a0                        // start off the right edge of the screen
sta $d000                       // X = $1a0; the tutorial started at Y = $ff
lda #SHIP_RESPAWN_Y             // in the open bottom border, but that is
sta $d001                       // now below the bottom wall, so mid-screen
