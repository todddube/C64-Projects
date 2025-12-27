// Aquarium Simulation - Two Fish Demo
// Lifelike fish movement with smooth animation
// Follows KickAssembler and C64 6502 standards

BasicUpstart2(main)

//--------------------------------------------------
// VIC-II Register Labels
//--------------------------------------------------
.label VIC_SPRITE_0_X    = $d000
.label VIC_SPRITE_0_Y    = $d001
.label VIC_SPRITE_1_X    = $d002
.label VIC_SPRITE_1_Y    = $d003
.label VIC_SPRITE_X_MSB  = $d010
.label VIC_RASTER        = $d012
.label VIC_SPRITE_ENABLE = $d015
.label VIC_CTRL2         = $d016
.label VIC_SPRITE_EXPAND_Y = $d017
.label VIC_MEMORY        = $d018
.label VIC_BORDER        = $d020
.label VIC_BACKGROUND    = $d021
.label VIC_SPRITE_EXPAND_X = $d01d
.label VIC_SPRITE_0_COLOR = $d027
.label VIC_SPRITE_1_COLOR = $d028
.label SPRITE_PTRS       = $07f8

//--------------------------------------------------
// Zero Page Variables (fast access)
//--------------------------------------------------
.label fish0_x_lo        = $02      // Fish 0 X position (16-bit for sub-pixel)
.label fish0_x_hi        = $03
.label fish0_y_lo        = $04      // Fish 0 Y position (16-bit)
.label fish0_y_hi        = $05
.label fish0_vel_x       = $06      // Fish 0 X velocity (signed)
.label fish0_vel_y       = $07      // Fish 0 Y velocity (signed)
.label fish0_frame       = $08      // Current animation frame
.label fish0_anim_timer  = $09      // Animation delay counter
.label fish0_facing      = $0a      // 0 = right, 1 = left

.label fish1_x_lo        = $0b      // Fish 1 X position
.label fish1_x_hi        = $0c
.label fish1_y_lo        = $0d      // Fish 1 Y position
.label fish1_y_hi        = $0e
.label fish1_vel_x       = $0f      // Fish 1 X velocity
.label fish1_vel_y       = $10      // Fish 1 Y velocity
.label fish1_frame       = $11      // Current animation frame
.label fish1_anim_timer  = $12      // Animation delay counter
.label fish1_facing      = $13      // 0 = right, 1 = left

.label frame_count       = $14      // Global frame counter
.label bubble_timer      = $15      // Bubble animation timer
.label random_seed       = $16      // Random number seed

//--------------------------------------------------
// Movement Constants
//--------------------------------------------------
.label WATER_TOP         = $3a      // Top boundary (below border)
.label WATER_BOTTOM      = $e8      // Bottom boundary
.label WATER_LEFT        = $18      // Left boundary
.label WATER_RIGHT       = $40      // Right boundary (needs MSB check)
.label FISH0_SPEED       = $02      // Goldfish - medium speed
.label FISH1_SPEED       = $03      // Tropical - faster

//--------------------------------------------------
// Sprite Pointer Calculations
//--------------------------------------------------
.label SPRITE_BASE       = $2000
.label SPRITE_PTR_BASE   = SPRITE_BASE / $40  // = $80

* = $0810 "Main Code"

//--------------------------------------------------
// Main Program Entry
//--------------------------------------------------
main:
    sei                             // Disable interrupts during setup

    // Set up aquarium colors
    lda #$06                        // Blue border (water edge)
    sta VIC_BORDER
    lda #$0e                        // Light blue background (water)
    sta VIC_BACKGROUND

    // Initialize variables
    jsr init_fish
    jsr init_random

    cli                             // Re-enable interrupts

//--------------------------------------------------
// Main Loop - Frame Synchronized
//--------------------------------------------------
main_loop:
    // Wait for raster at bottom of visible screen
    lda #$fa
wait_raster:
    cmp VIC_RASTER
    bne wait_raster

    // Update game state
    jsr update_fish_0
    jsr update_fish_1
    jsr update_animations
    jsr apply_positions

    // Increment frame counter
    inc frame_count

    // Small delay to avoid double-triggering on same raster
    ldx #$10
delay:
    dex
    bne delay

    jmp main_loop

//--------------------------------------------------
// Initialize Fish Starting Positions and Velocities
//--------------------------------------------------
init_fish:
    // Fish 0 - Goldfish (orange, starts center-left)
    lda #$60
    sta fish0_x_hi
    lda #$00
    sta fish0_x_lo
    lda #$80
    sta fish0_y_hi
    lda #$00
    sta fish0_y_lo
    lda #FISH0_SPEED
    sta fish0_vel_x
    lda #$01
    sta fish0_vel_y
    lda #$00
    sta fish0_frame
    sta fish0_anim_timer
    sta fish0_facing              // Facing right

    // Fish 1 - Tropical fish (cyan, starts center-right)
    lda #$b0
    sta fish1_x_hi
    lda #$00
    sta fish1_x_lo
    lda #$60
    sta fish1_y_hi
    lda #$00
    sta fish1_y_lo
    lda #FISH1_SPEED
    eor #$ff                      // Negate - start moving left
    clc
    adc #$01
    sta fish1_vel_x
    lda #$02
    sta fish1_vel_y
    lda #$00
    sta fish1_frame
    sta fish1_anim_timer
    lda #$01
    sta fish1_facing              // Facing left

    // Enable both sprites
    lda #%00000011
    sta VIC_SPRITE_ENABLE

    // Clear X MSB (both sprites on left side of screen)
    lda #$00
    sta VIC_SPRITE_X_MSB

    // Set sprite colors
    lda #$08                      // Orange for goldfish
    sta VIC_SPRITE_0_COLOR
    lda #$03                      // Cyan for tropical
    sta VIC_SPRITE_1_COLOR

    // Set initial sprite pointers
    lda #SPRITE_PTR_BASE          // Fish 0 right-facing frame 0
    sta SPRITE_PTRS
    lda #SPRITE_PTR_BASE + 4      // Fish 1 left-facing frame 0
    sta SPRITE_PTRS + 1

    rts

//--------------------------------------------------
// Initialize Random Seed
//--------------------------------------------------
init_random:
    lda VIC_RASTER                // Use raster as seed
    ora #$80                      // Ensure non-zero
    sta random_seed
    rts

//--------------------------------------------------
// Get Random Number (simple LFSR)
//--------------------------------------------------
get_random:
    lda random_seed
    asl
    bcc no_eor
    eor #$1d                      // Polynomial for 8-bit LFSR
no_eor:
    sta random_seed
    rts

//--------------------------------------------------
// Update Fish 0 Position and Behavior
//--------------------------------------------------
update_fish_0:
    // Update X position (16-bit add for smooth movement)
    lda fish0_vel_x
    bmi fish0_move_left

fish0_move_right:
    // Moving right - add velocity to position
    clc
    lda fish0_x_lo
    adc fish0_vel_x
    sta fish0_x_lo
    lda fish0_x_hi
    adc #$00
    sta fish0_x_hi

    // Set facing right
    lda #$00
    sta fish0_facing

    // Check right boundary
    lda fish0_x_hi
    cmp #$40                      // Right edge (X > $140 screen coords)
    bcc fish0_check_y

    // Hit right wall - reverse and add slight randomness
    jsr get_random
    and #$01                      // Random 0-1
    clc
    adc #FISH0_SPEED
    eor #$ff
    clc
    adc #$01
    sta fish0_vel_x
    lda #$01
    sta fish0_facing              // Now facing left
    jmp fish0_check_y

fish0_move_left:
    // Moving left - subtract velocity from position
    clc
    lda fish0_x_lo
    adc fish0_vel_x               // Add negative velocity
    sta fish0_x_lo
    lda fish0_x_hi
    adc #$ff                      // Carry the sign
    sta fish0_x_hi

    // Set facing left
    lda #$01
    sta fish0_facing

    // Check left boundary
    lda fish0_x_hi
    cmp #WATER_LEFT
    bcs fish0_check_y

    // Hit left wall - reverse
    jsr get_random
    and #$01
    clc
    adc #FISH0_SPEED
    sta fish0_vel_x
    lda #$00
    sta fish0_facing              // Now facing right

fish0_check_y:
    // Update Y position
    clc
    lda fish0_y_lo
    adc fish0_vel_y
    sta fish0_y_lo
    lda fish0_y_hi
    adc #$00
    bmi fish0_y_underflow         // Handle negative wrap
    sta fish0_y_hi

    // Check top boundary
    cmp #WATER_TOP
    bcc fish0_reverse_y

    // Check bottom boundary
    cmp #WATER_BOTTOM
    bcs fish0_reverse_y
    jmp fish0_done

fish0_y_underflow:
    lda #WATER_TOP
    sta fish0_y_hi

fish0_reverse_y:
    // Reverse Y direction with slight random variation
    lda fish0_vel_y
    eor #$ff
    clc
    adc #$01
    sta fish0_vel_y

    // Occasionally change Y velocity slightly
    jsr get_random
    and #$07
    cmp #$01
    bne fish0_done

    // Nudge Y velocity
    lda fish0_vel_y
    bmi fish0_nudge_neg
    clc
    adc #$01
    cmp #$04                      // Max Y speed
    bcs fish0_done
    sta fish0_vel_y
    jmp fish0_done

fish0_nudge_neg:
    sec
    sbc #$01
    cmp #$fc                      // Min Y speed (-4)
    bcc fish0_done
    sta fish0_vel_y

fish0_done:
    rts

//--------------------------------------------------
// Update Fish 1 Position and Behavior
//--------------------------------------------------
update_fish_1:
    // Update X position
    lda fish1_vel_x
    bmi fish1_move_left

fish1_move_right:
    clc
    lda fish1_x_lo
    adc fish1_vel_x
    sta fish1_x_lo
    lda fish1_x_hi
    adc #$00
    sta fish1_x_hi

    lda #$00
    sta fish1_facing

    // Check right boundary
    lda fish1_x_hi
    cmp #$40
    bcc fish1_check_y

    // Reverse with randomness
    jsr get_random
    and #$01
    clc
    adc #FISH1_SPEED
    eor #$ff
    clc
    adc #$01
    sta fish1_vel_x
    lda #$01
    sta fish1_facing
    jmp fish1_check_y

fish1_move_left:
    clc
    lda fish1_x_lo
    adc fish1_vel_x
    sta fish1_x_lo
    lda fish1_x_hi
    adc #$ff
    sta fish1_x_hi

    lda #$01
    sta fish1_facing

    // Check left boundary
    lda fish1_x_hi
    cmp #WATER_LEFT
    bcs fish1_check_y

    jsr get_random
    and #$01
    clc
    adc #FISH1_SPEED
    sta fish1_vel_x
    lda #$00
    sta fish1_facing

fish1_check_y:
    clc
    lda fish1_y_lo
    adc fish1_vel_y
    sta fish1_y_lo
    lda fish1_y_hi
    adc #$00
    bmi fish1_y_underflow
    sta fish1_y_hi

    cmp #WATER_TOP
    bcc fish1_reverse_y
    cmp #WATER_BOTTOM
    bcs fish1_reverse_y
    jmp fish1_done

fish1_y_underflow:
    lda #WATER_TOP
    sta fish1_y_hi

fish1_reverse_y:
    lda fish1_vel_y
    eor #$ff
    clc
    adc #$01
    sta fish1_vel_y

fish1_done:
    rts

//--------------------------------------------------
// Update Animation Frames
//--------------------------------------------------
update_animations:
    // Fish 0 animation (slower - every 8 frames)
    inc fish0_anim_timer
    lda fish0_anim_timer
    and #$07
    bne fish0_anim_skip

    inc fish0_frame
    lda fish0_frame
    and #$01                      // 2 frames of animation
    sta fish0_frame

fish0_anim_skip:
    // Calculate sprite pointer for fish 0
    // Right facing: frames 0-1 at $80-$81
    // Left facing: frames 2-3 at $82-$83
    lda fish0_facing
    asl                           // *2 for frame pair offset
    clc
    adc fish0_frame
    clc
    adc #SPRITE_PTR_BASE
    sta SPRITE_PTRS

    // Fish 1 animation (faster - every 4 frames)
    inc fish1_anim_timer
    lda fish1_anim_timer
    and #$03
    bne fish1_anim_skip

    inc fish1_frame
    lda fish1_frame
    and #$01
    sta fish1_frame

fish1_anim_skip:
    // Calculate sprite pointer for fish 1
    // Right facing: frames 0-1 at $84-$85
    // Left facing: frames 2-3 at $86-$87
    lda fish1_facing
    asl
    clc
    adc fish1_frame
    clc
    adc #SPRITE_PTR_BASE + 4      // Fish 1 sprites start at $84
    sta SPRITE_PTRS + 1

    rts

//--------------------------------------------------
// Apply Positions to VIC-II Hardware
//--------------------------------------------------
apply_positions:
    // Fish 0 X position
    lda fish0_x_hi
    sta VIC_SPRITE_0_X

    // Fish 0 Y position
    lda fish0_y_hi
    sta VIC_SPRITE_0_Y

    // Fish 1 X position
    lda fish1_x_hi
    sta VIC_SPRITE_1_X

    // Fish 1 Y position
    lda fish1_y_hi
    sta VIC_SPRITE_1_Y

    // Handle X MSB for both sprites (for X > 255)
    lda #$00
    ldx fish0_x_hi
    cpx #$00                      // Check if we wrapped (simplified)
    bne no_msb_0
    // Could set MSB here if needed
no_msb_0:
    sta VIC_SPRITE_X_MSB

    rts

//--------------------------------------------------
// Sprite Data - 8 frames total (4 per fish)
//--------------------------------------------------
* = $2000 "Sprite Data"

// Fish 0 (Goldfish) - Right facing, Frame 0
fish0_right_0:
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00011000, %00000000
    .byte %00000000, %00111100, %00000000
    .byte %00000000, %01111110, %00000000
    .byte %00000001, %11111111, %00000000
    .byte %00000011, %11111111, %10000000
    .byte %00001111, %11111111, %11100000
    .byte %00011111, %11111111, %11110000
    .byte %01111111, %11111111, %11111100
    .byte %00011111, %11111111, %11110000
    .byte %00001111, %11111111, %11100000
    .byte %00000011, %11111111, %10000000
    .byte %00000001, %11111111, %00000000
    .byte %00000000, %01111110, %00000000
    .byte %00000000, %00111100, %00000000
    .byte %00000000, %00011000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte 0

// Fish 0 (Goldfish) - Right facing, Frame 1 (tail wagging)
* = $2040
fish0_right_1:
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00011000, %00000000
    .byte %00000000, %00111100, %00000000
    .byte %00000000, %01111110, %00000000
    .byte %00000001, %11111111, %00000000
    .byte %00000011, %11111111, %10000000
    .byte %00000111, %11111111, %11100000
    .byte %00001111, %11111111, %11110000
    .byte %00111111, %11111111, %11111100
    .byte %00001111, %11111111, %11110000
    .byte %00000111, %11111111, %11100000
    .byte %00000011, %11111111, %10000000
    .byte %00000001, %11111111, %00000000
    .byte %00000000, %01111110, %00000000
    .byte %00000000, %00111100, %00000000
    .byte %00000000, %00011000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte 0

// Fish 0 (Goldfish) - Left facing, Frame 0
* = $2080
fish0_left_0:
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00011000, %00000000
    .byte %00000000, %00111100, %00000000
    .byte %00000000, %01111110, %00000000
    .byte %00000000, %11111111, %10000000
    .byte %00000001, %11111111, %11000000
    .byte %00000111, %11111111, %11110000
    .byte %00001111, %11111111, %11111000
    .byte %00111111, %11111111, %11111110
    .byte %00001111, %11111111, %11111000
    .byte %00000111, %11111111, %11110000
    .byte %00000001, %11111111, %11000000
    .byte %00000000, %11111111, %10000000
    .byte %00000000, %01111110, %00000000
    .byte %00000000, %00111100, %00000000
    .byte %00000000, %00011000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte 0

// Fish 0 (Goldfish) - Left facing, Frame 1
* = $20c0
fish0_left_1:
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00011000, %00000000
    .byte %00000000, %00111100, %00000000
    .byte %00000000, %01111110, %00000000
    .byte %00000000, %11111111, %10000000
    .byte %00000001, %11111111, %11000000
    .byte %00000111, %11111111, %11100000
    .byte %00001111, %11111111, %11110000
    .byte %00111111, %11111111, %11111100
    .byte %00001111, %11111111, %11110000
    .byte %00000111, %11111111, %11100000
    .byte %00000001, %11111111, %11000000
    .byte %00000000, %11111111, %10000000
    .byte %00000000, %01111110, %00000000
    .byte %00000000, %00111100, %00000000
    .byte %00000000, %00011000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte 0

// Fish 1 (Tropical) - Right facing, Frame 0
* = $2100
fish1_right_0:
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00111000, %00000000
    .byte %00000000, %01111100, %00000000
    .byte %00000000, %11111110, %00000000
    .byte %00000001, %11111111, %00000000
    .byte %00000011, %11111111, %10000000
    .byte %00000111, %11111111, %11000000
    .byte %00011111, %11111111, %11000000
    .byte %00111111, %11111111, %11100000
    .byte %01111111, %11111111, %11110000
    .byte %00111111, %11111111, %11100000
    .byte %00011111, %11111111, %11000000
    .byte %00000111, %11111111, %11000000
    .byte %00000011, %11111111, %10000000
    .byte %00000001, %11111111, %00000000
    .byte %00000000, %11111110, %00000000
    .byte %00000000, %01111100, %00000000
    .byte %00000000, %00111000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte 0

// Fish 1 (Tropical) - Right facing, Frame 1
* = $2140
fish1_right_1:
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00111000, %00000000
    .byte %00000000, %01111100, %00000000
    .byte %00000000, %11111110, %00000000
    .byte %00000001, %11111111, %00000000
    .byte %00000011, %11111111, %10000000
    .byte %00000111, %11111111, %11000000
    .byte %00001111, %11111111, %11000000
    .byte %00011111, %11111111, %11100000
    .byte %00111111, %11111111, %11110000
    .byte %00011111, %11111111, %11100000
    .byte %00001111, %11111111, %11000000
    .byte %00000111, %11111111, %11000000
    .byte %00000011, %11111111, %10000000
    .byte %00000001, %11111111, %00000000
    .byte %00000000, %11111110, %00000000
    .byte %00000000, %01111100, %00000000
    .byte %00000000, %00111000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte 0

// Fish 1 (Tropical) - Left facing, Frame 0
* = $2180
fish1_left_0:
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00011100, %00000000
    .byte %00000000, %00111110, %00000000
    .byte %00000000, %01111111, %00000000
    .byte %00000000, %11111111, %10000000
    .byte %00000001, %11111111, %11000000
    .byte %00000011, %11111111, %11100000
    .byte %00000011, %11111111, %11111000
    .byte %00000111, %11111111, %11111100
    .byte %00001111, %11111111, %11111110
    .byte %00000111, %11111111, %11111100
    .byte %00000011, %11111111, %11111000
    .byte %00000011, %11111111, %11100000
    .byte %00000001, %11111111, %11000000
    .byte %00000000, %11111111, %10000000
    .byte %00000000, %01111111, %00000000
    .byte %00000000, %00111110, %00000000
    .byte %00000000, %00011100, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte 0

// Fish 1 (Tropical) - Left facing, Frame 1
* = $21c0
fish1_left_1:
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00011100, %00000000
    .byte %00000000, %00111110, %00000000
    .byte %00000000, %01111111, %00000000
    .byte %00000000, %11111111, %10000000
    .byte %00000001, %11111111, %11000000
    .byte %00000011, %11111111, %11100000
    .byte %00000011, %11111111, %11110000
    .byte %00000111, %11111111, %11111000
    .byte %00001111, %11111111, %11111100
    .byte %00000111, %11111111, %11111000
    .byte %00000011, %11111111, %11110000
    .byte %00000011, %11111111, %11100000
    .byte %00000001, %11111111, %11000000
    .byte %00000000, %11111111, %10000000
    .byte %00000000, %01111111, %00000000
    .byte %00000000, %00111110, %00000000
    .byte %00000000, %00011100, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte %00000000, %00000000, %00000000
    .byte 0
