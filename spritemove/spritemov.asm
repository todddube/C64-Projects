// Sprite Movement Demo - KickAssembler
// Simple bouncing ball sprite with smooth movement

BasicUpstart2(start)

// VIC-II Sprite Registers
.label SPRITE_PTR_0   = $07F8
.label SPRITE_POS_X   = $D000
.label SPRITE_POS_Y   = $D001
.label SPRITE_X_MSB   = $D010
.label SPRITE_ENABLE  = $D015
.label SPRITE_COLOR   = $D027
.label RASTER         = $D012
.label BORDER_COLOR   = $D020
.label BG_COLOR       = $D021

// Zero page variables for speed
.label sprite_x       = $02
.label sprite_y       = $03
.label dir_x          = $04
.label dir_y          = $05
.label anim_timer     = $06
.label anim_frame     = $07

// Sprite boundaries
.label MIN_X = $18
.label MAX_X = $58
.label MIN_Y = $32
.label MAX_Y = $E2

* = $0810 "Main Code"

start:
    // Set border and background colors
    lda #$00
    sta BORDER_COLOR
    sta BG_COLOR

    // Initialize sprite color (light blue)
    lda #$0E
    sta SPRITE_COLOR

    // Enable sprite 0
    lda #$01
    sta SPRITE_ENABLE

    // Clear X MSB (sprite in left half of screen)
    lda #$00
    sta SPRITE_X_MSB

    // Set sprite pointer to first frame at $2000 ($2000/64 = $80)
    lda #$80
    sta SPRITE_PTR_0

    // Initialize position (center of screen)
    lda #$A0
    sta sprite_x
    lda #$64
    sta sprite_y

    // Initialize direction (moving right and down)
    lda #$01
    sta dir_x
    sta dir_y

    // Initialize animation
    lda #$00
    sta anim_timer
    sta anim_frame

mainloop:
    // Wait for raster line 255 (frame sync)
    lda #$FF
wait_raster:
    cmp RASTER
    bne wait_raster

    // Flash border briefly to show timing
    inc BORDER_COLOR

    // Update sprite position
    jsr move_sprite

    // Update animation
    jsr animate_sprite

    // Apply position to hardware
    lda sprite_x
    sta SPRITE_POS_X
    lda sprite_y
    sta SPRITE_POS_Y

    // Restore border color
    lda #$00
    sta BORDER_COLOR

    jmp mainloop

// Move sprite and handle bouncing
move_sprite:
    // Update X position
    lda sprite_x
    clc
    adc dir_x
    sta sprite_x

    // Check X boundaries
    cmp #MAX_X
    bcs reverse_x
    cmp #MIN_X
    bcc reverse_x
    jmp check_y

reverse_x:
    // Reverse X direction: negate dir_x
    lda dir_x
    eor #$FF
    clc
    adc #$01
    sta dir_x
    // Undo the move that went out of bounds
    lda sprite_x
    clc
    adc dir_x
    adc dir_x
    sta sprite_x

check_y:
    // Update Y position
    lda sprite_y
    clc
    adc dir_y
    sta sprite_y

    // Check Y boundaries
    cmp #MAX_Y
    bcs reverse_y
    cmp #MIN_Y
    bcc reverse_y
    rts

reverse_y:
    // Reverse Y direction: negate dir_y
    lda dir_y
    eor #$FF
    clc
    adc #$01
    sta dir_y
    // Undo the move that went out of bounds
    lda sprite_y
    clc
    adc dir_y
    adc dir_y
    sta sprite_y
    rts

// Animate sprite frames
animate_sprite:
    inc anim_timer
    lda anim_timer
    and #$07            // Change frame every 8 ticks
    bne no_frame_change

    inc anim_frame
    lda anim_frame
    and #$03            // 4 frames (0-3)
    sta anim_frame
    clc
    adc #$80            // Add base sprite pointer
    sta SPRITE_PTR_0

no_frame_change:
    rts

// Sprite data at $2000
* = $2000 "Sprite Data"

// Frame 0 - Ball (centered)
.byte %00000000, %00111100, %00000000
.byte %00000000, %01111110, %00000000
.byte %00000001, %11111111, %10000000
.byte %00000001, %11111111, %10000000
.byte %00000001, %11111111, %10000000
.byte %00000001, %11111111, %10000000
.byte %00000000, %01111110, %00000000
.byte %00000000, %00111100, %00000000
.fill 21*3 - 24, 0      // Pad to 63 bytes
.byte 0                  // 64th byte

// Frame 1 - Ball (squished horizontal)
.byte %00000000, %00011000, %00000000
.byte %00000000, %01111110, %00000000
.byte %00000001, %11111111, %10000000
.byte %00000011, %11111111, %11000000
.byte %00000011, %11111111, %11000000
.byte %00000001, %11111111, %10000000
.byte %00000000, %01111110, %00000000
.byte %00000000, %00011000, %00000000
.fill 21*3 - 24, 0
.byte 0

// Frame 2 - Ball (centered again)
.byte %00000000, %00111100, %00000000
.byte %00000000, %01111110, %00000000
.byte %00000001, %11111111, %10000000
.byte %00000001, %11111111, %10000000
.byte %00000001, %11111111, %10000000
.byte %00000001, %11111111, %10000000
.byte %00000000, %01111110, %00000000
.byte %00000000, %00111100, %00000000
.fill 21*3 - 24, 0
.byte 0

// Frame 3 - Ball (squished vertical)
.byte %00000000, %00111100, %00000000
.byte %00000000, %11111111, %00000000
.byte %00000000, %11111111, %00000000
.byte %00000001, %11111111, %10000000
.byte %00000001, %11111111, %10000000
.byte %00000000, %11111111, %00000000
.byte %00000000, %11111111, %00000000
.byte %00000000, %00111100, %00000000
.fill 21*3 - 24, 0
.byte 0
