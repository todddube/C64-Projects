//============================================================
// Sprite#2 and #3, the rockets. SPACE or the joystick button
// launches one from the ship's nose (fire_rocket, called from
// check_keyboard); update_rockets flies them left at ROCKET_SPEED
// and retires them off the left edge. Collisions with asteroids
// are in sub_collisions.asm.
//============================================================

update_rockets:     ldx #$01
rocket_loop:        lda rocket_active,x
                    beq rocket_off

                    lda rocket_x_lo,x              // X -= ROCKET_SPEED (16-bit)
                    sec
                    sbc #ROCKET_SPEED
                    sta rocket_x_lo,x
                    lda rocket_x_hi,x
                    sbc #$00
                    sta rocket_x_hi,x
                    bmi rocket_kill                // went below X = 0
                    bne rocket_show                // still at X >= 256
                    lda rocket_x_lo,x
                    cmp #ROCKET_X_MIN
                    bcc rocket_kill                // off the left edge

rocket_show:        txa                            // Sprite#2+x registers
                    asl
                    tay
                    lda rocket_x_lo,x
                    sta $d004,y
                    lda rocket_y,x
                    sta $d005,y
                    lda rocket_x_hi,x              // 9th bit into $d010
                    beq !+
                    lda rocket_bitmask,x
!:                  sta tmp1
                    lda rocket_bitmask,x
                    eor #$ff
                    and $d010
                    ora tmp1
                    sta $d010
                    lda $d015                      // and switch it on
                    ora rocket_bitmask,x
                    sta $d015
                    jmp rocket_next

rocket_kill:        lda #$00
                    sta rocket_active,x
rocket_off:         lda rocket_bitmask,x           // not live: sprite off
                    eor #$ff
                    and $d015
                    sta $d015
rocket_next:        dex
                    bpl rocket_loop

                    lda fire_cooldown              // tick the launch cooldown
                    beq !+
                    dec fire_cooldown
!:                  rts

rocket_bitmask:     .byte %00000100, %00001000     // Sprite#2, Sprite#3

//------------------------------------------------------------
// launch a rocket if the cooldown has passed and a slot is free
//------------------------------------------------------------
fire_rocket:        lda fire_cooldown
                    bne fire_done
                    ldx #$00
                    lda rocket_active
                    beq fire_slot
                    ldx #$01
                    lda rocket_active + 1
                    bne fire_done                  // both in flight
fire_slot:          lda #$01
                    sta rocket_active,x
                    lda $d000                      // X = ship X - ROCKET_DX
                    sec
                    sbc #ROCKET_DX
                    sta rocket_x_lo,x
                    lda $d010
                    and #%00000001
                    sbc #$00                       // (a negative result is
                    sta rocket_x_hi,x              //  retired on the next update)
                    lda $d001                      // Y = ship centre row
                    clc
                    adc #ROCKET_DY
                    sta rocket_y,x
                    lda #FIRE_COOLDOWN
                    sta fire_cooldown
                    jsr sfx_pew
fire_done:          rts
