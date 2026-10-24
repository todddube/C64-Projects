//============================================================
// Controls, read straight from the CIA#1 keyboard matrix as in
// the tutorial, plus joystick port 2:
//   U / joystick up      ship up
//   D / joystick down    ship down
//   SPACE / fire button  launch a rocket   (the tutorial's SPACE exited)
//   RUN/STOP             back to BASIC
// The presses are gathered into 'controls' (bit 0 up, bit 1 down,
// bit 4 fire) and acted on afterwards, so key and stick combine.
//============================================================

check_keyboard:     lda #%11111111      // CIA#1 port A: output (rows)
                    sta ddra
                    lda #%00000000      // CIA#1 port B: input (columns)
                    sta ddrb
                    lda #$00
                    sta controls

check_space:        lda #%01111111      // select row 7
                    sta pra
                    lda prb             // load column information
                    sta tmp1
                    and #%10000000      // bit 7 = RUN/STOP: exit
                    beq exit_to_basic
                    lda tmp1
                    and #%00010000      // bit 4 = SPACE: fire
                    bne check_d
                    lda #%00010000
                    sta controls

check_d:            lda #%11111011      // select row 2
                    sta pra
                    lda prb
                    and #%00000100      // 'd' key
                    bne check_u
                    lda controls
                    ora #%00000010
                    sta controls

check_u:            lda #%11110111      // select row 3
                    sta pra
                    lda prb
                    and #%01000000      // 'u' key
                    bne check_joystick
                    lda controls
                    ora #%00000001
                    sta controls

check_joystick:     lda #%11111111      // no row selected: port A now reads
                    sta pra             // joystick 2 (active low)
                    lda pra
                    eor #$ff
                    and #%00010011      // bit 0 up, bit 1 down, bit 4 fire
                    ora controls
                    sta controls

#if AUTOFIRE
                    lda controls           // test builds (-define AUTOFIRE) hold
                    ora #%00010001      // fire and up, so rockets, hits and
                    sta controls           // the top wall can be checked in VICE
#endif
                    lda ship_state      // no steering while exploding
                    cmp #SHIP_EXPLODING
                    beq controls_done
                    lda controls
                    and #%00000001
                    beq !+
                    dec $d001           // sprite up (the walls stop it,
!:                  lda controls           // see sub_collisions.asm)
                    and #%00000010
                    beq !+
                    inc $d001           // sprite down
!:                  lda controls
                    and #%00010000
                    beq controls_done
                    jsr fire_rocket
controls_done:      rts

// Tell the main loop to shut the intro down (see main.asm); the
// original jumped to $ea81 from inside this JSR, which cannot work.
exit_to_basic:      lda #$01
                    sta exit_flag
                    rts
