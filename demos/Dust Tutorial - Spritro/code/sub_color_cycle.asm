//============================================================
// 1. colour cycle over the text, using the ship's animation
//    frame counter as the colour source
// 2. slower colour cycle on the side borders via delay_counter
//    (a tutorial quirk: the colour run below reaches black and
//    leaves before column 40 every frame, so it never triggers)
//============================================================

color_cycle:    ldx #$00                        // column counter

color_init:     lda sprite_ship_current_frame   // always $00-$0f
                cmp #$0f                        // at $0f skip the +1
                beq color_inc
                adc #$01                        // otherwise +1, so black never appears

color_inc:      sta $d828,x                     // colour RAM line 1
                sta $d878,x                     // line 2
                sta $db70,x                     // line 3
                sta $dbc0,x                     // line 4 (added)
                sbc #$01                        // next colour

                cmp #$00                        // black? then stop for this frame
                beq color_exit

                inx
                cpx #$28                        // all 40 columns done?
                bne color_inc
                lda delay_counter
                cmp #$34
                beq border_color                // time to switch the border colour
                inc delay_counter
color_exit:     rts
border_color:   lda $d020
                eor #$08                        // flip between blue and light blue
                sta $d020
                lda #$00
                sta delay_counter
                rts
