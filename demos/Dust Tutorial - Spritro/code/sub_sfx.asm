//============================================================
// Sound effects on the SID (only when PLAY_MUSIC is false, see
// config_symbols.asm): voice 1 is the rocket launch, a falling
// sawtooth; voice 2 is the explosion, falling noise. Each has a
// frame timer and a shadow of its frequency high byte, because
// SID registers cannot be read back. All routines use A only, so
// they can be called from inside the X/Y collision loops.
//============================================================

sfx_init:           ldx #$18                       // silence everything...
                    lda #$00
!:                  sta $d400,x
                    dex
                    bpl !-
                    lda #$0f                       // ...then volume up, no filter
                    sta $d418
                    rts

sfx_pew:            lda #%00100000                 // sawtooth, gate off, so the
                    sta $d404                      // envelope restarts
                    lda #$00                       // attack 0, decay 0
                    sta $d405
                    lda #$f8                       // sustain 15, release 8
                    sta $d406
                    lda #PEW_FREQ_HI
                    sta sfx_pew_freq
                    sta $d401
                    lda #$00
                    sta $d400
                    lda #%00100001                 // sawtooth, gate on
                    sta $d404
                    lda #PEW_FRAMES
                    sta sfx_pew_timer
                    rts

sfx_boom:           lda #%10000000                 // noise, gate off
                    sta $d40b
                    lda #$0a                       // attack 0, decay 10 (~0.5 s)
                    sta $d40c
                    lda #$00                       // sustain 0, release 0
                    sta $d40d
                    lda #BOOM_FREQ_HI
                    sta sfx_boom_freq
                    sta $d408
                    lda #$00
                    sta $d407
                    lda #%10000001                 // noise, gate on
                    sta $d40b
                    lda #BOOM_FRAMES
                    sta sfx_boom_timer
                    rts

sfx_update:         lda sfx_pew_timer
                    beq sfx_boom_update
                    dec sfx_pew_timer
                    bne !+
                    lda #%00100000                 // launch sound over: gate off
                    sta $d404
                    jmp sfx_boom_update
!:                  lda sfx_pew_freq               // else keep sweeping down
                    sec
                    sbc #PEW_SWEEP
                    sta sfx_pew_freq
                    sta $d401

sfx_boom_update:    lda sfx_boom_timer
                    beq sfx_done
                    dec sfx_boom_timer
                    bne !+
                    lda #%10000000                 // explosion over: gate off
                    sta $d40b
                    rts
!:                  lda sfx_boom_freq
                    sec
                    sbc #BOOM_SWEEP
                    sta sfx_boom_freq
                    sta $d408
sfx_done:           rts
