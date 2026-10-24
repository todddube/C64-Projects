//============================================================
// Controls, read straight from the CIA#1 keyboard matrix as in
// the tutorial, plus joystick port 2:
//   CRSR down / joystick down        ship down
//   SHIFT + CRSR (up) / joystick up  ship up
//   SPACE / fire button              launch a rocket (the tutorial's SPACE exited)
//   RUN/STOP                         back to BASIC
// (The tutorial used U and D.) The C64 has one vertical cursor
// key, CRSR down, with SHIFT giving up, exactly as in BASIC; both
// shift keys count. The presses are gathered into 'controls'
// (bit 0 up, bit 1 down, bit 4 fire) and acted on afterwards, so
// key and stick combine.
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
                    bne !+
                    jmp exit_to_basic   // (too far for a branch now)
!:                  lda tmp1
                    and #%00010000      // bit 4 = SPACE: fire
                    bne check_cursor
                    lda #%00010000
                    sta controls

check_cursor:       lda #%11111110      // select row 0
                    sta pra
                    lda prb
                    and #%10000000      // bit 7 = CRSR down/up key
                    bne check_joystick  // not pressed
                    lda #%11111101      // select row 1
                    sta pra
                    lda prb
                    and #%10000000      // bit 7 = left SHIFT
                    beq cursor_up
                    lda #%10111111      // select row 6
                    sta pra
                    lda prb
                    and #%00010000      // bit 4 = right SHIFT
                    beq cursor_up
                    lda controls        // unshifted: down
                    ora #%00000010
                    sta controls
                    bne check_joystick  // (always: bit 1 is set)
cursor_up:          lda controls        // shifted: up
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
                    lda controls        // test builds (-define AUTOFIRE) hold
                    ora #%00010001      // fire and up, so rockets, hits and
                    sta controls        // the top wall can be checked in VICE
#endif
                    lda ship_state      // no steering while exploding
                    cmp #SHIP_EXPLODING
                    beq controls_done
                    lda controls
                    and #%00000001
                    beq !+
                    dec $d001           // sprite up (the walls stop it,
!:                  lda controls        // see sub_collisions.asm)
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
