//============================================================
// point the VIC at the custom charset, turn off multicolour
// characters, then output five lines of text (the tutorial had three)
//============================================================

write_text:     lda $d018
                ora #$0e            // charset at $3800: $0400 + $0200 * $0e
                sta $d018
                lda $d016           // turn off multicolour characters
                and #$ef            // by clearing bit 4 of $d016
                sta $d016

                ldx #$00            // (the original relied on X being 0 here)
loop_text:      lda line1,x         // copy 40 chars of each line
                sta $0428,x         // row 1
                lda line2,x
                sta $0478,x         // row 3
                lda line3,x
                sta $0720,x         // row 20 (the tutorial put it on 22)
                lda line4,x
                sta $0770,x         // row 22 (added)
                lda line5,x
                sta $07c0,x         // row 24 (added)
                inx
                cpx #$28
                bne loop_text
                rts
