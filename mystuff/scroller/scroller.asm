// Basic upstart program
.pc = $0801 "Basic Upstart"
:BasicUpstart($0c00)

// Main program
.pc = $0c00 "Main Program"

    // Constants
    .const SPRITE_0_POINTER = $07f8
    .const SPRITE_ENABLE = $d015
    .const SPRITE_0_X = $d000
    .const SPRITE_0_Y = $d001
    .const SPRITE_0_COLOR = $d027
    .const RND = $d41b      // Random number generator

init:   
    lda #$0f        // White color
    sta SPRITE_0_COLOR
    
    lda #$80        // Point to sprite data
    sta SPRITE_0_POINTER
    
    lda #$01        // Enable sprite 0
    sta SPRITE_ENABLE
    
    // Initial position
    lda #100
    sta SPRITE_0_X
    sta SPRITE_0_Y

mainloop:
    jsr move_sprite
    jsr wait_frame
    jmp mainloop

move_sprite:
    // Update X position with momentum
    lda RND         // Get random number
    and #$03        // Limit to 0-3
    sec
    sbc #$01        // Convert to -1 to +1
    clc
    adc SPRITE_0_X  // Add to current X position
    
    // Screen X boundary check (0-255)
    cmp #250        // Check right boundary
    bcc check_left
    lda #249        // Bounce from right
check_left:
    cmp #20         // Check left boundary
    bcs save_x
    lda #21         // Bounce from left
save_x:
    sta SPRITE_0_X

    // Update Y position with momentum
    lda RND         // Get another random number
    and #$03        // Limit to 0-3
    sec
    sbc #$01        // Convert to -1 to +1
    clc
    adc SPRITE_0_Y  // Add to current Y position
    
    // Screen Y boundary check (50-250)
    cmp #220        // Check bottom boundary
    bcc check_top
    lda #219        // Bounce from bottom
check_top:
    cmp #50         // Check top boundary
    bcs save_y
    lda #51         // Bounce from top
save_y:
    sta SPRITE_0_Y
    rts

wait_frame:
    lda #$ff
    cmp $d012
    bne wait_frame
    rts

direction_x:
    .byte 1, -1, 0, 0   // Right, Left, No move, No move

direction_y:
    .byte 0, 0, 1, -1   // No move, No move, Down, Up

// Sprite data at $2000
.pc = $2000 "SpriteBox"
sprite_data:
    .byte %11111111, %11111111, %11111100
    .byte %10000000, %00000000, %00000100
    .byte %10000000, %00000000, %00000100
    .byte %10000000, %00000000, %00000100
    .byte %10000000, %00000000, %00000100
    .byte %10000000, %00000000, %00000100
    .byte %10000000, %00000000, %00000100
    .byte %10000000, %00000000, %00000100
    .byte %10000000, %00000000, %00000100
    .byte %10000000, %00000000, %00000100
    .byte %10000000, %00000000, %00000100
    .byte %10000000, %00000000, %00000100
    .byte %10000000, %00000000, %00000100
    .byte %10000000, %00000000, %00000100
    .byte %10000000, %00000000, %00000100
    .byte %10000000, %00000000, %00000100
    .byte %10000000, %00000000, %00000100
    .byte %10000000, %00000000, %00000100
    .byte %10000000, %00000000, %00000100
    .byte %10000000, %00000000, %00000100
    .byte %11111111, %11111111, %11111100