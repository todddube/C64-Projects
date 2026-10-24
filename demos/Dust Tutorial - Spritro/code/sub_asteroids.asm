//============================================================
// Sprite#4 to #7, the asteroids. Every AST_SPAWN_FRAMES a rock
// starts at X = 0 on a random row with a random speed and drifts
// right, against the ship's direction, until it leaves at X = 344
// or gets blown up (asteroid_explode, from sub_collisions.asm),
// which plays the 4 explosion shapes in its place.
//============================================================

update_asteroids:   dec ast_spawn_timer
                    bne ast_move_all
                    lda #AST_SPAWN_FRAMES
                    sta ast_spawn_timer
                    ldx #$03                       // find a free slot...
ast_find:           lda ast_state,x
                    beq ast_spawn
                    dex
                    bpl ast_find
                    bmi ast_move_all               // (none free, try later)

ast_spawn:          lda #AST_DRIFTING              // ...and start a rock in it
                    sta ast_state,x
                    lda #$00
                    sta ast_x_lo,x
                    sta ast_x_hi,x
                    jsr random
                    and #%01111111
                    clc
                    adc #AST_Y_MIN                 // Y = 56..183
                    sta ast_y,x
                    jsr random
                    and #%00000001
                    clc
                    adc #$01                       // speed 1 or 2
                    sta ast_speed,x
                    lda rnd_seed                   // one of the 2 rock shapes
                    and #%00000100
                    lsr
                    lsr
                    clc
                    adc #sprite_pointer_asteroid
                    sta sprite_pointers + 4,x
                    lda #AST_COLOR
                    sta $d02b,x

ast_move_all:       ldx #$03
ast_loop:           lda ast_state,x
                    beq ast_off
                    cmp #AST_EXPLODING
                    beq ast_boom

                    lda ast_x_lo,x                 // drifting: X += speed (16-bit)
                    clc
                    adc ast_speed,x
                    sta ast_x_lo,x
                    lda ast_x_hi,x
                    adc #$00
                    sta ast_x_hi,x
                    beq ast_show                   // X < 256: on screen
                    lda ast_x_lo,x
                    cmp #AST_X_MAX_LO
                    bcc ast_show                   // X < 344: still on screen
                    lda #AST_OFF                   // gone off the right edge
                    sta ast_state,x
                    jmp ast_off

ast_boom:           dec ast_timer,x                // exploding: next shape
                    bne !+
                    lda #AST_OFF                   // explosion over
                    sta ast_state,x
                    jmp ast_off
!:                  lda ast_timer,x                // timer 15..12 -> shape 0 ...
                    sec                            // 3..1 -> shape 3 (as the ship)
                    sbc #$01
                    lsr
                    lsr
                    eor #%00000011
                    clc
                    adc #sprite_pointer_explosion
                    sta sprite_pointers + 4,x

ast_show:           txa                            // Sprite#4+x registers
                    asl
                    tay
                    lda ast_x_lo,x
                    sta $d008,y
                    lda ast_y,x
                    sta $d009,y
                    lda ast_x_hi,x                 // 9th bit into $d010
                    beq !+
                    lda ast_bitmask,x
!:                  sta tmp1
                    lda ast_bitmask,x
                    eor #$ff
                    and $d010
                    ora tmp1
                    sta $d010
                    lda $d015                      // and switch it on
                    ora ast_bitmask,x
                    sta $d015
                    jmp ast_next

ast_off:            lda ast_bitmask,x              // not live: sprite off
                    eor #$ff
                    and $d015
                    sta $d015
ast_next:           dex
                    bmi !+                         // (loop too long for a bpl)
                    jmp ast_loop
!:                  rts

ast_bitmask:        .byte %00010000, %00100000, %01000000, %10000000

//------------------------------------------------------------
// blow up asteroid X: first explosion shape now, the rest from
// update_asteroids. Keeps X and Y.
//------------------------------------------------------------
asteroid_explode:   lda #AST_EXPLODING
                    sta ast_state,x
                    lda #EXPLOSION_FRAMES
                    sta ast_timer,x
                    lda #EXPLOSION_COLOR
                    sta $d02b,x
                    lda #sprite_pointer_explosion
                    sta sprite_pointers + 4,x
                    jmp sfx_boom
