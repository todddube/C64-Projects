//============================================================
// Updates the X position and animation frame of Sprite#0.
// The sprite moves from right to left.
//============================================================

// The original toggled the 9th bit after the low byte reached 0, so X
// went $101 -> $000 -> $0ff and the ship vanished for a frame at x=256.
update_ship:        lda $d000                      // low byte about to wrap?
                    bne !+
                    lda $d010                      // then flip the 9th X bit first
                    eor #$01
                    sta $d010
!:                  dec $d000                      // X--

animate_ship:       lda delay_animation_pointer    // flag is 0 or 1
                    eor #$01                       // flip it
                    sta delay_animation_pointer
                    beq delay_animation            // animate every other frame
                    lda sprite_ship_current_frame
                    bne dec_ship_frame

reset_ship_frames:  lda #sprite_frames_ship        // restart the animation
                    sta sprite_ship_current_frame
                    lda #sprite_pointer_ship       // first sprite shape
                    sta screen_ram + $3f8

dec_ship_frame:     inc screen_ram + $3f8          // next sprite shape
                    dec sprite_ship_current_frame
                    beq reset_ship_frames          // wrap after the last frame

delay_animation:    rts
