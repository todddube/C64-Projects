//============================================================
// Sound effects on the SID, over the music: voice 1 is the rocket
// launch, a falling sawtooth; voice 2 is the explosion, falling
// noise. Each has a frame timer and a shadow of its frequency high
// byte, because SID registers cannot be read back.
//
// Nightshift's player (main.asm, music_tick) writes each voice's
// frequency and control byte every frame and its envelope at note
// starts, so sfx_update runs after it and writes the whole voice
// again (frequency, envelope, waveform with the gate on) while an
// effect lasts; the last write wins. The tune's own note on that
// voice is lost until its next one, which also restores its
// envelope. (If the player gates the voice off and on
// for a new note while the explosion decays, the envelope restarts
// from the top: a short stutter, accepted.) All routines use A
// only, so they can be called from inside the X/Y collision loops.
//============================================================

sfx_init:           ldx #$18                       // silence everything...
                    lda #$00
!:                  sta $d400,x
                    dex
                    bpl !-
                    lda #$0f                       // ...then volume up, no filter
                    sta $d418                      // (the tune sets its own)
                    rts

sfx_pew:            lda #%00100000                 // sawtooth, gate off, so the
                    sta $d404                      // envelope restarts
                    lda #PEW_FREQ_HI
                    sta sfx_pew_freq
                    lda #PEW_FRAMES
                    sta sfx_pew_timer
                    jmp sfx_pew_voice              // then the full voice, gate on

sfx_boom:           lda #%10000000                 // noise, gate off
                    sta $d40b
                    lda #BOOM_FREQ_HI
                    sta sfx_boom_freq
                    lda #BOOM_FRAMES
                    sta sfx_boom_timer
                    jmp sfx_boom_voice

// write every register of voice 1 for the launch sound
sfx_pew_voice:      lda #$00                       // attack 0, decay 0
                    sta $d405
                    lda #$f8                       // sustain 15, release 8
                    sta $d406
                    lda #$00
                    sta $d400                      // frequency low
                    lda sfx_pew_freq
                    sta $d401                      // frequency high (swept)
                    lda #%00100001                 // sawtooth, gate on
                    sta $d404
                    rts

// write every register of voice 2 for the explosion
sfx_boom_voice:     lda #$0a                       // attack 0, decay 10 (~0.5 s)
                    sta $d40c
                    lda #$00                       // sustain 0, release 0
                    sta $d40d
                    sta $d407                      // frequency low
                    lda sfx_boom_freq
                    sta $d408                      // frequency high (swept)
                    lda #%10000001                 // noise, gate on
                    sta $d40b
                    rts

// once per frame, after the music's play call
sfx_update:         lda sfx_pew_timer
                    beq sfx_boom_update
                    dec sfx_pew_timer
                    bne !+
                    lda #%00100000                 // launch sound over: gate off
                    sta $d404
                    jmp sfx_boom_update
!:                  lda sfx_pew_freq               // else keep sweeping down...
                    sec
                    sbc #PEW_SWEEP
                    sta sfx_pew_freq
                    jsr sfx_pew_voice              // ...and reclaim the voice

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
                    jmp sfx_boom_voice
sfx_done:           rts
