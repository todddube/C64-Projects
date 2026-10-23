//===============================
// check for a single key press
//===============================

check_keyboard:
                lda #%11111111      // CIA#1 port A: output
                sta ddra
                lda #%00000000      // CIA#1 port B: input
                sta ddrb

check_space:    lda #%01111111      // select row 7
                sta pra
                lda prb             // load column information
                and #%10010000      // bit 4 = SPACE, bit 7 = RUN/STOP: either exits
                cmp #%10010000
                bne exit_to_basic

check_d:        lda #%11111011      // select row 2
                sta pra
                lda prb
                and #%00000100      // 'd' key
                beq go_down

check_u:        lda #%11110111      // select row 3
                sta pra
                lda prb
                and #%01000000      // 'u' key
                beq go_up
                rts

go_up:          lda $d001
                cmp #$1e            // too high? then skip
                beq skip
                dec $d001           // sprite up
                rts

go_down:        lda $d001
                cmp #$ff            // too low? then skip
                beq skip
                inc $d001           // sprite down
                rts

// The original jumped to $ea81 from inside a JSR, which unwinds the
// stack wrongly and leaves the raster IRQ installed. A reset through
// the KERNAL vector is the clean way back to BASIC.
exit_to_basic:  lda #$00
                sta $d015           // turn off all sprites
                sta $d01a           // no more raster IRQs
                jmp ($fffc)         // reset to BASIC

skip:           rts                 // leave the Y coordinate alone
