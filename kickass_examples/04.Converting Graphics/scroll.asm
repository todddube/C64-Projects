BasicUpstart2(start)
            * = $1000
start:      sei

            jsr $e544
            lda #$18
            sta $d018
            
            .const base_target = $0400+8+11*40
            ldx #0
            ldy #0
            lda #0
            sta scroll_pos

scroll_loop:
            ldx scroll_pos
            ldy #0
			
loop:       lda text,y
            cmp #$ff
            beq exit
            clc
            sta base_target,x
            adc #$40
            sta base_target+40,x
            inx
            adc #$40
            sta base_target,x
            adc #$40
            sta base_target+40,x
            inx
            iny
            jmp loop
exit:
            inc scroll_pos
            jsr delay
            jmp scroll_loop

delay:      ldx #$ff
delay_loop: dex
            bne delay_loop
            rts

scroll_pos: .byte 0

text:       .text "hello world.."
            .byte $ff

//------------------------------------------------------------------------------------
            * = $2000 "Charset"
            .var charsetPic = LoadPicture("2x2char.gif", List().add($000000, $ffffff))   // <- Here we load a gif picture
            .fill $200, charsetPic.getSinglecolorByte(  2*(i>>3),   i&7)                  // <- getSinglecolorByte gives a converted singlecolor byte    
            .fill $200, charsetPic.getSinglecolorByte(  2*(i>>3), 8+(i&7))                // (You can also get a multicolor byte or a raw value)
            .fill $200, charsetPic.getSinglecolorByte(1+2*(i>>3),    i&7) 
            .fill $200, charsetPic.getSinglecolorByte(1+2*(i>>3), 8+(i&7))