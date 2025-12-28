// Sprite Movement Demo - KickAssembler
// 8 smooth floating spinning ball sprites
// Random wandering movement across entire screen
// Follows C64 6502 and KickAssembler standards

BasicUpstart2(start)

//--------------------------------------------------
// VIC-II Sprite Registers
//--------------------------------------------------
.label SPRITE_PTRS       = $07f8
.label VIC_SPRITE_X      = $d000
.label VIC_SPRITE_Y      = $d001
.label VIC_SPRITE_X_MSB  = $d010
.label VIC_RASTER        = $d012
.label VIC_SPRITE_ENABLE = $d015
.label VIC_SPRITE_EXPAND_Y = $d017
.label VIC_SPRITE_EXPAND_X = $d01d
.label VIC_SPRITE_PRIORITY = $d01b
.label VIC_SPRITE_MULTI  = $d01c
.label VIC_BORDER        = $d020
.label VIC_BACKGROUND    = $d021
.label VIC_SPRITE_COLOR  = $d027

//--------------------------------------------------
// Screen RAM for trails
//--------------------------------------------------
.label SCREEN_RAM        = $0400
.label COLOR_RAM         = $d800

//--------------------------------------------------
// Zero Page Variables
//--------------------------------------------------
// Sprite X positions: 16-bit (8.8 fixed point)
.label sprite_x_lo       = $02      // $02-$09 - fractional
.label sprite_x_hi       = $0a      // $0a-$11 - whole pixel
.label sprite_x_msb      = $12      // $12-$19 - high bit (X > 255)

// Sprite Y positions: 16-bit
.label sprite_y_lo       = $1a      // $1a-$21 - fractional
.label sprite_y_hi       = $22      // $22-$29 - whole pixel

// Sprite velocities (signed)
.label sprite_vel_x      = $2a      // $2a-$31
.label sprite_vel_y      = $32      // $32-$39

// Animation frame for each sprite
.label sprite_frame      = $3a      // $3a-$41
.label sprite_anim_speed = $42      // $42-$49 - animation speed per sprite

// Direction change timers
.label sprite_timer      = $4a      // $4a-$51

// General variables
.label random_seed       = $52
.label frame_count       = $53
.label current_sprite    = $54
.label temp              = $55
.label temp2             = $56
.label x_msb_accumulator = $57

//--------------------------------------------------
// Constants
//--------------------------------------------------
.label MIN_X             = 24
.label MAX_X_LO          = 64       // 320 = $140
.label MAX_X_HI          = 1
.label MIN_Y             = 50
.label MAX_Y             = 229
.label NUM_FRAMES        = 8        // 8 spinning frames

//--------------------------------------------------
// Sprite data location
//--------------------------------------------------
.label SPRITE_DATA       = $2000
.label SPRITE_PTR_BASE   = SPRITE_DATA / $40

* = $0810 "Main Code"

//--------------------------------------------------
// Main Entry Point
//--------------------------------------------------
start:
    sei

    // Keep default screen colors (commented out)
    // lda #$00
    // sta VIC_BORDER
    // sta VIC_BACKGROUND

    // Clear screen to prevent stray characters
    lda #$20                        // Space character
    ldx #$00
clear_loop:
    sta SCREEN_RAM, x
    sta SCREEN_RAM + $100, x
    sta SCREEN_RAM + $200, x
    sta SCREEN_RAM + $2e8, x
    dex
    bne clear_loop

    // Initialize random seed
    lda VIC_RASTER
    ora #$37
    sta random_seed

    jsr init_sprites

    cli

//--------------------------------------------------
// Main Loop
//--------------------------------------------------
main_loop:
    lda #$fa
wait_raster:
    cmp VIC_RASTER
    bne wait_raster

    jsr update_all_sprites
    jsr update_animations
    jsr apply_sprite_positions
    // jsr update_trails           // Disabled - was causing stray characters

    inc frame_count

    jmp main_loop

//--------------------------------------------------
// Initialize All 8 Sprites
//--------------------------------------------------
init_sprites:
    lda #$ff
    sta VIC_SPRITE_ENABLE

    lda #$00
    sta VIC_SPRITE_X_MSB
    sta VIC_SPRITE_EXPAND_X
    sta VIC_SPRITE_EXPAND_Y
    sta VIC_SPRITE_PRIORITY
    sta VIC_SPRITE_MULTI

    // Set sprite colors (bright rainbow)
    lda #$02                        // Red
    sta VIC_SPRITE_COLOR + 0
    lda #$08                        // Orange
    sta VIC_SPRITE_COLOR + 1
    lda #$07                        // Yellow
    sta VIC_SPRITE_COLOR + 2
    lda #$05                        // Green
    sta VIC_SPRITE_COLOR + 3
    lda #$03                        // Cyan
    sta VIC_SPRITE_COLOR + 4
    lda #$0e                        // Light blue
    sta VIC_SPRITE_COLOR + 5
    lda #$04                        // Purple
    sta VIC_SPRITE_COLOR + 6
    lda #$0a                        // Light red
    sta VIC_SPRITE_COLOR + 7

    // Initialize each sprite
    ldx #$00
init_loop:
    stx current_sprite

    // Random X position across full screen
    jsr get_random
    sta sprite_x_hi, x
    jsr get_random
    sta sprite_x_lo, x
    jsr get_random
    and #$01
    sta sprite_x_msb, x

    // Random Y position
    jsr get_random
    and #$7f
    clc
    adc #$50
    sta sprite_y_hi, x
    jsr get_random
    sta sprite_y_lo, x

    // Random X velocity (varied speeds, both directions)
    jsr get_random
    and #$7f                        // 0-127
    clc
    adc #$10                        // 16-143
    sta temp
    jsr get_random
    and #$01
    beq init_vel_x_pos
    lda temp
    eor #$ff
    clc
    adc #$01
    sta temp
init_vel_x_pos:
    lda temp
    sta sprite_vel_x, x

    // Random Y velocity
    jsr get_random
    and #$7f
    clc
    adc #$10
    sta temp
    jsr get_random
    and #$01
    beq init_vel_y_pos
    lda temp
    eor #$ff
    clc
    adc #$01
    sta temp
init_vel_y_pos:
    lda temp
    sta sprite_vel_y, x

    // Random starting animation frame
    jsr get_random
    and #$07                        // 0-7
    sta sprite_frame, x

    // Random animation speed (2-5)
    jsr get_random
    and #$03
    clc
    adc #$02
    sta sprite_anim_speed, x

    // Random direction change timer
    jsr get_random
    ora #$40                        // 64-255 frames
    sta sprite_timer, x

    // Set initial sprite pointer
    lda sprite_frame, x
    clc
    adc #SPRITE_PTR_BASE
    sta SPRITE_PTRS, x

    inx
    cpx #$08
    beq init_done
    jmp init_loop
init_done:
    rts

//--------------------------------------------------
// Update All Sprites - Smooth Random Floating
//--------------------------------------------------
update_all_sprites:
    ldx #$00
update_loop:
    stx current_sprite

    // Check if time to change direction randomly
    dec sprite_timer, x
    bne no_dir_change

    // Randomly adjust both velocities for wandering effect
    jsr randomize_direction

no_dir_change:
    // Update X position
    lda sprite_vel_x, x
    bmi move_x_neg

    // Moving right
    clc
    adc sprite_x_lo, x
    sta sprite_x_lo, x
    lda sprite_x_hi, x
    adc #$00
    sta sprite_x_hi, x
    lda sprite_x_msb, x
    adc #$00
    sta sprite_x_msb, x
    jmp check_x

move_x_neg:
    // Moving left
    clc
    adc sprite_x_lo, x
    sta sprite_x_lo, x
    lda sprite_x_hi, x
    adc #$ff
    sta sprite_x_hi, x
    lda sprite_x_msb, x
    adc #$ff
    and #$01
    sta sprite_x_msb, x

check_x:
    // Check right boundary (X > 320)
    lda sprite_x_msb, x
    beq check_x_left
    lda sprite_x_hi, x
    cmp #MAX_X_LO
    bcs bounce_x
    jmp update_y

check_x_left:
    lda sprite_x_hi, x
    cmp #MIN_X
    bcc bounce_x
    jmp update_y

bounce_x:
    // Reverse X and pick new random velocity
    lda sprite_vel_x, x
    eor #$ff
    clc
    adc #$01
    sta sprite_vel_x, x
    // Clamp position
    lda sprite_x_msb, x
    bne clamp_x_right
    lda #MIN_X
    sta sprite_x_hi, x
    lda #$00
    sta sprite_x_msb, x
    jmp update_y
clamp_x_right:
    lda #MAX_X_LO
    sec
    sbc #$10
    sta sprite_x_hi, x
    lda #$01
    sta sprite_x_msb, x

update_y:
    // Update Y position
    lda sprite_vel_y, x
    bmi move_y_neg

    clc
    adc sprite_y_lo, x
    sta sprite_y_lo, x
    lda sprite_y_hi, x
    adc #$00
    sta sprite_y_hi, x
    jmp check_y

move_y_neg:
    clc
    adc sprite_y_lo, x
    sta sprite_y_lo, x
    lda sprite_y_hi, x
    adc #$ff
    sta sprite_y_hi, x

check_y:
    lda sprite_y_hi, x
    cmp #MAX_Y
    bcs bounce_y
    cmp #MIN_Y
    bcc bounce_y
    jmp next_sprite

bounce_y:
    lda sprite_vel_y, x
    eor #$ff
    clc
    adc #$01
    sta sprite_vel_y, x
    // Clamp
    lda sprite_y_hi, x
    cmp #$80
    bcs clamp_y_top
    lda #MAX_Y
    sec
    sbc #$05
    sta sprite_y_hi, x
    jmp next_sprite
clamp_y_top:
    lda #MIN_Y
    sta sprite_y_hi, x

next_sprite:
    ldx current_sprite
    inx
    cpx #$08
    beq update_done
    jmp update_loop
update_done:
    rts

//--------------------------------------------------
// Randomize Direction - For organic floating
//--------------------------------------------------
randomize_direction:
    // Generate new random X velocity
    jsr get_random
    and #$7f                        // 0-127
    clc
    adc #$18                        // 24-151
    sta temp
    jsr get_random
    and #$01
    beq rand_x_pos
    lda temp
    eor #$ff
    clc
    adc #$01
    sta temp
rand_x_pos:
    lda temp
    sta sprite_vel_x, x

    // Generate new random Y velocity
    jsr get_random
    and #$7f
    clc
    adc #$18
    sta temp
    jsr get_random
    and #$01
    beq rand_y_pos
    lda temp
    eor #$ff
    clc
    adc #$01
    sta temp
rand_y_pos:
    lda temp
    sta sprite_vel_y, x

    // Reset timer (40-167 frames)
    jsr get_random
    and #$7f
    clc
    adc #$28
    sta sprite_timer, x

    rts

//--------------------------------------------------
// Update Spinning Animations
//--------------------------------------------------
update_animations:
    ldx #$00
anim_loop:
    // Check if it's time to advance frame
    lda frame_count
    and sprite_anim_speed, x        // Different speed per sprite
    bne anim_skip

    // Advance to next frame
    inc sprite_frame, x
    lda sprite_frame, x
    and #$07                        // Wrap at 8 frames
    sta sprite_frame, x

    // Update sprite pointer
    clc
    adc #SPRITE_PTR_BASE
    sta SPRITE_PTRS, x

anim_skip:
    inx
    cpx #$08
    bne anim_loop
    rts

//--------------------------------------------------
// Apply Sprite Positions to VIC-II
//--------------------------------------------------
apply_sprite_positions:
    lda #$00
    sta x_msb_accumulator

    ldx #$00
    ldy #$00
apply_loop:
    lda sprite_x_hi, x
    sta VIC_SPRITE_X, y

    lda sprite_y_hi, x
    sta VIC_SPRITE_Y, y

    // Build MSB byte
    lda sprite_x_msb, x
    beq no_msb
    lda x_msb_accumulator
    ora msb_bits, x
    sta x_msb_accumulator
no_msb:
    iny
    iny
    inx
    cpx #$08
    bne apply_loop

    lda x_msb_accumulator
    sta VIC_SPRITE_X_MSB
    rts

msb_bits:
    .byte $01, $02, $04, $08, $10, $20, $40, $80

//--------------------------------------------------
// Update Trails Effect
//--------------------------------------------------
update_trails:
    lda frame_count
    and #$03
    bne skip_trails

    jsr fade_trails

    ldx #$00
draw_loop:
    stx current_sprite

    // Calculate column
    lda sprite_x_hi, x
    sec
    sbc #$18
    lsr
    lsr
    lsr
    ldy sprite_x_msb, x
    beq no_add_msb
    clc
    adc #$20
no_add_msb:
    cmp #$28
    bcc col_valid
    lda #$27
col_valid:
    sta temp

    // Calculate row
    lda sprite_y_hi, x
    cmp #$32                        // Check if Y < 50
    bcc skip_draw                   // Skip if off top of screen
    sec
    sbc #$32
    lsr
    lsr
    lsr
    cmp #$19
    bcc row_valid
    jmp skip_draw                   // Skip if off bottom
row_valid:
    tay
    lda row_lo, y
    clc
    adc temp
    sta temp2
    lda row_hi, y
    adc #$00
    cmp #$04
    bcs skip_draw

    ldy temp2
    lda #$51
    sta SCREEN_RAM, y
    ldx current_sprite
    lda sprite_colors, x
    sta COLOR_RAM, y

skip_draw:
    ldx current_sprite
    inx
    cpx #$08
    bne draw_loop

skip_trails:
    rts

//--------------------------------------------------
// Fade Trails
//--------------------------------------------------
fade_trails:
    ldx #$20
fade_loop:
    jsr get_random
    tay
    lda SCREEN_RAM, y
    cmp #$51
    bne no_fade1
    lda #$20
    sta SCREEN_RAM, y
no_fade1:
    jsr get_random
    tay
    lda SCREEN_RAM + $100, y
    cmp #$51
    bne no_fade2
    lda #$20
    sta SCREEN_RAM + $100, y
no_fade2:
    jsr get_random
    tay
    lda SCREEN_RAM + $200, y
    cmp #$51
    bne no_fade3
    lda #$20
    sta SCREEN_RAM + $200, y
no_fade3:
    dex
    bne fade_loop
    rts

//--------------------------------------------------
// Random Number Generator
//--------------------------------------------------
get_random:
    lda random_seed
    asl
    bcc no_eor
    eor #$1d
no_eor:
    sta random_seed
    rts

//--------------------------------------------------
// Data Tables
//--------------------------------------------------
sprite_colors:
    .byte $02, $08, $07, $05, $03, $0e, $04, $0a

row_lo:
    .byte <(0*40), <(1*40), <(2*40), <(3*40), <(4*40)
    .byte <(5*40), <(6*40), <(7*40), <(8*40), <(9*40)
    .byte <(10*40), <(11*40), <(12*40), <(13*40), <(14*40)
    .byte <(15*40), <(16*40), <(17*40), <(18*40), <(19*40)
    .byte <(20*40), <(21*40), <(22*40), <(23*40), <(24*40)

row_hi:
    .byte >(0*40), >(1*40), >(2*40), >(3*40), >(4*40)
    .byte >(5*40), >(6*40), >(7*40), >(8*40), >(9*40)
    .byte >(10*40), >(11*40), >(12*40), >(13*40), >(14*40)
    .byte >(15*40), >(16*40), >(17*40), >(18*40), >(19*40)
    .byte >(20*40), >(21*40), >(22*40), >(23*40), >(24*40)

//--------------------------------------------------
// Sprite Data - 8 Spinning Ball Frames
// Highlight rotates around the ball
//--------------------------------------------------
* = $2000 "Sprite Data"

// Frame 0 - Highlight top-left
frame0:
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %01111100, %00000000
    .byte %00000001, %11111111, %00000000
    .byte %00000011, %11111111, %10000000
    .byte %00000111, %10011111, %11000000
    .byte %00000111, %00001111, %11000000
    .byte %00001111, %10011111, %11100000
    .byte %00001111, %11111111, %11100000
    .byte %00001111, %11111111, %11100000
    .byte %00001111, %11111111, %11100000
    .byte %00001111, %11111111, %11100000
    .byte %00000111, %11111111, %11000000
    .byte %00000111, %11111111, %11000000
    .byte %00000011, %11111111, %10000000
    .byte %00000001, %11111111, %00000000
    .byte %00000000, %01111100, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte 0

// Frame 1 - Highlight top
* = $2040
frame1:
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %01111100, %00000000
    .byte %00000001, %11111111, %00000000
    .byte %00000011, %11111111, %10000000
    .byte %00000111, %11100111, %11000000
    .byte %00000111, %11000011, %11000000
    .byte %00001111, %11100111, %11100000
    .byte %00001111, %11111111, %11100000
    .byte %00001111, %11111111, %11100000
    .byte %00001111, %11111111, %11100000
    .byte %00001111, %11111111, %11100000
    .byte %00000111, %11111111, %11000000
    .byte %00000111, %11111111, %11000000
    .byte %00000011, %11111111, %10000000
    .byte %00000001, %11111111, %00000000
    .byte %00000000, %01111100, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte 0

// Frame 2 - Highlight top-right
* = $2080
frame2:
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %01111100, %00000000
    .byte %00000001, %11111111, %00000000
    .byte %00000011, %11111111, %10000000
    .byte %00000111, %11111001, %11000000
    .byte %00000111, %11110000, %11000000
    .byte %00001111, %11111001, %11100000
    .byte %00001111, %11111111, %11100000
    .byte %00001111, %11111111, %11100000
    .byte %00001111, %11111111, %11100000
    .byte %00001111, %11111111, %11100000
    .byte %00000111, %11111111, %11000000
    .byte %00000111, %11111111, %11000000
    .byte %00000011, %11111111, %10000000
    .byte %00000001, %11111111, %00000000
    .byte %00000000, %01111100, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte 0

// Frame 3 - Highlight right
* = $20c0
frame3:
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %01111100, %00000000
    .byte %00000001, %11111111, %00000000
    .byte %00000011, %11111111, %10000000
    .byte %00000111, %11111111, %11000000
    .byte %00000111, %11111111, %11000000
    .byte %00001111, %11111111, %11100000
    .byte %00001111, %11111100, %11100000
    .byte %00001111, %11111000, %01100000
    .byte %00001111, %11111100, %11100000
    .byte %00001111, %11111111, %11100000
    .byte %00000111, %11111111, %11000000
    .byte %00000111, %11111111, %11000000
    .byte %00000011, %11111111, %10000000
    .byte %00000001, %11111111, %00000000
    .byte %00000000, %01111100, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte 0

// Frame 4 - Highlight bottom-right
* = $2100
frame4:
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %01111100, %00000000
    .byte %00000001, %11111111, %00000000
    .byte %00000011, %11111111, %10000000
    .byte %00000111, %11111111, %11000000
    .byte %00000111, %11111111, %11000000
    .byte %00001111, %11111111, %11100000
    .byte %00001111, %11111111, %11100000
    .byte %00001111, %11111111, %11100000
    .byte %00001111, %11111111, %11100000
    .byte %00001111, %11111001, %11100000
    .byte %00000111, %11110000, %11000000
    .byte %00000111, %11111001, %11000000
    .byte %00000011, %11111111, %10000000
    .byte %00000001, %11111111, %00000000
    .byte %00000000, %01111100, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte 0

// Frame 5 - Highlight bottom
* = $2140
frame5:
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %01111100, %00000000
    .byte %00000001, %11111111, %00000000
    .byte %00000011, %11111111, %10000000
    .byte %00000111, %11111111, %11000000
    .byte %00000111, %11111111, %11000000
    .byte %00001111, %11111111, %11100000
    .byte %00001111, %11111111, %11100000
    .byte %00001111, %11111111, %11100000
    .byte %00001111, %11111111, %11100000
    .byte %00001111, %11100111, %11100000
    .byte %00000111, %11000011, %11000000
    .byte %00000111, %11100111, %11000000
    .byte %00000011, %11111111, %10000000
    .byte %00000001, %11111111, %00000000
    .byte %00000000, %01111100, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte 0

// Frame 6 - Highlight bottom-left
* = $2180
frame6:
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %01111100, %00000000
    .byte %00000001, %11111111, %00000000
    .byte %00000011, %11111111, %10000000
    .byte %00000111, %11111111, %11000000
    .byte %00000111, %11111111, %11000000
    .byte %00001111, %11111111, %11100000
    .byte %00001111, %11111111, %11100000
    .byte %00001111, %11111111, %11100000
    .byte %00001111, %11111111, %11100000
    .byte %00001111, %10011111, %11100000
    .byte %00000111, %00001111, %11000000
    .byte %00000111, %10011111, %11000000
    .byte %00000011, %11111111, %10000000
    .byte %00000001, %11111111, %00000000
    .byte %00000000, %01111100, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte 0

// Frame 7 - Highlight left
* = $21c0
frame7:
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %01111100, %00000000
    .byte %00000001, %11111111, %00000000
    .byte %00000011, %11111111, %10000000
    .byte %00000111, %11111111, %11000000
    .byte %00000111, %11111111, %11000000
    .byte %00001111, %11111111, %11100000
    .byte %00001110, %00111111, %11100000
    .byte %00001100, %00011111, %11100000
    .byte %00001110, %00111111, %11100000
    .byte %00001111, %11111111, %11100000
    .byte %00000111, %11111111, %11000000
    .byte %00000111, %11111111, %11000000
    .byte %00000011, %11111111, %10000000
    .byte %00000001, %11111111, %00000000
    .byte %00000000, %01111100, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte 0
