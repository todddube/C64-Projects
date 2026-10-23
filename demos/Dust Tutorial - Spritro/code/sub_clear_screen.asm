//============================================================
// clear screen and turn it black
//============================================================

clear_screen:   ldx #$00
                stx $d020           // border colour
                stx $d021           // screen colour
clear_loop:     lda #$20            // space
                sta $0400,x         // fill four blocks of 256 chars
                sta $0500,x
                sta $0600,x
                sta $06e8,x
                lda #$0c            // dark grey in colour RAM,
                sta $d800,x         // the initial colour of the text
                sta $d900,x
                sta $da00,x
                sta $dae8,x
                inx
                bne clear_loop
                rts
