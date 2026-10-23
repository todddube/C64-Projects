//============================================================
// configuration of the sprite used in the intro
//============================================================

// zero page: current animation frame and the animation delay flag
.label sprite_ship_current_frame = $fb
.label delay_animation_pointer   = $fc

// number of frames (shapes) in the ship animation
.const sprite_frames_ship = 16

// sprite pointer for Sprite#0 ($2000 / 64 = $80)
.const sprite_pointer_ship = address_sprites / $40

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
sta screen_ram + $3f8

//============================================================
// Initialise the VIC-II sprite registers
//============================================================

lda #$01                        // enable Sprite#0
sta $d015

lda #$01                        // multicolour mode for Sprite#0
sta $d01c

lda #$00                        // Sprite#0 has priority over background
sta $d01b

lda #sprite_background_color    // shared background colour
sta $d021

lda #sprite_multicolor_1        // shared multicolour 1
sta $d025

lda #sprite_multicolor_2        // shared multicolour 2
sta $d026

lda #sprite_ship_color          // individual Sprite#0 colour
sta $d027

lda #$01                        // X coordinate 9th bit for Sprite#0
sta $d010

lda #$a0                        // start at the lower right of the screen
sta $d000                       // X = $1a0
lda #$ff
sta $d001                       // Y = $ff
