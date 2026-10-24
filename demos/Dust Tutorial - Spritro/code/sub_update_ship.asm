//============================================================
// Updates Sprite#0, the ship. The tutorial's part moves it right
// to left and steps its animation; added around it are the
// explosion and respawn states used by the collision feature:
//   SHIP_FLYING     moves and animates
//   SHIP_EXPLODING  shows the explosion shapes, does not move
//   SHIP_RESPAWNED  flying again but blinking and invulnerable
//============================================================

update_ship:        lda ship_state
                    beq ship_move                  // flying
                    cmp #SHIP_EXPLODING
                    beq ship_exploding
                                                   // respawned: count down the
                    dec ship_timer                 // invulnerability...
                    bne ship_blink
                    lda #SHIP_FLYING               // ...then fly for real again
                    sta ship_state
                    lda $d015
                    ora #%00000001                 // and stay switched on
                    sta $d015
                    jmp ship_move
ship_blink:         lda ship_timer
                    and #%00000100                 // 4 frames on, 4 frames off
                    beq !+
                    lda #%00000001
!:                  sta tmp1
                    lda $d015
                    and #%11111110
                    ora tmp1
                    sta $d015

//------------------------------------------------------------
// the tutorial's movement and animation
//------------------------------------------------------------
// The original toggled the 9th bit after the low byte reached 0, so X
// went $101 -> $000 -> $0ff and the ship vanished for a frame at x=256.
// It also flew the whole invisible stretch from X=23 round to X=344;
// now it jumps straight from just off the left edge to just off the
// right edge, so it is away for a moment, not three seconds.
ship_move:          lda $d010
                    and #%00000001                 // 9th bit clear and...
                    bne !+
                    lda $d000
                    cmp #SHIP_X_MIN                // ...just off the left edge?
                    bne !+
                    lda #<SHIP_X_MAX               // then wrap to the right edge
                    sta $d000
                    lda $d010
                    ora #%00000001
                    sta $d010
                    jmp animate_ship
!:                  lda $d000                      // low byte about to wrap?
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
                    sta sprite_pointers

dec_ship_frame:     inc sprite_pointers            // next sprite shape
                    dec sprite_ship_current_frame
                    beq reset_ship_frames          // wrap after the last frame

delay_animation:    rts

//------------------------------------------------------------
// exploding: step the explosion shapes, then respawn
//------------------------------------------------------------
ship_exploding:     dec ship_timer
                    bne ship_boom_frame
                    lda #SHIP_RESPAWNED            // explosion over: back mid-screen
                    sta ship_state                 // at the same X, as the ship
                    lda #SHIP_RESPAWN_FRAMES
                    sta ship_timer
                    lda #SHIP_RESPAWN_Y
                    sta $d001
                    lda #sprite_frames_ship - 1    // as the animation leaves them
                    sta sprite_ship_current_frame  // after its first wrap (the
                    lda #sprite_pointer_ship + 1   // colour cycle reads the counter)
                    sta sprite_pointers
                    lda #sprite_ship_color
                    sta $d027
                    rts
ship_boom_frame:    lda ship_timer                 // timer 15..12 -> shape 0,
                    sec                            // 11..8 -> 1, 7..4 -> 2,
                    sbc #$01                       // 3..1 -> shape 3
                    lsr
                    lsr
                    eor #%00000011
                    clc
                    adc #sprite_pointer_explosion
                    sta sprite_pointers
                    rts

//------------------------------------------------------------
// the ship hit something: start the explosion (ignored while
// it is already exploding or still invulnerable). Uses A only.
//------------------------------------------------------------
ship_crash:         lda ship_state
                    bne crash_done
                    lda #SHIP_EXPLODING
                    sta ship_state
                    lda #EXPLOSION_FRAMES
                    sta ship_timer
                    lda #EXPLOSION_COLOR
                    sta $d027
                    lda #sprite_pointer_explosion  // first shape this frame
                    sta sprite_pointers
                    lda #FLASH_FRAMES
                    sta flash_timer
                    lda $d015                      // visible even if it was
                    ora #%00000001                 // mid-blink
                    sta $d015
                    jsr sfx_boom
crash_done:         rts
