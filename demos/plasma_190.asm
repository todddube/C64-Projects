//
// **** Plasma Demo

* = $0326 "Plasma"

// $0326 (ind) - output character                 
rol
.label ROM_STOPi   =*+$01
        .byte $03,$ED //slo ($ED,x)
.label ROM_GETINi   =*+$01
        inc $78,x
.label ROM_CLALLi   =*+$01
        lda #$05
        sta $63
.label ROM_LOADi   =*+$01
        lda #$1F
.label ROM_SAVEi   =*+$01
        sta $61
        sta $D018    //VIC Memory Control Register
        ldy #$3F
        ldx #$00
b033A:  inc $61
b033C:  lda $63
        sta $62
b0340:  lda $61
        sta $9000,x
        sta $90C0,y
        eor #$FF
        sta $9080,x
        sta $9040,y
        sta $3820,x
        inx 
        dey 
        bmi b036B
        dec $62
        bpl b0340
        inc $61
        dec $63
        clc 
        lda $64
        adc $63
        asl 
        sta $64
        bcs b033C
        bne b033A
b036B:  iny 
.label a036D   =*+$01
b036C:  lda #$04
        sta $0030,y
        lda $FE
        sta $0050,y
        adc #$28
        cmp $FE
        sta $FE
        bcs b0381
        inc a036D
b0381:  iny 
        cpy #$20
        bne b036C
j0386:  ldy $24
        ldx $25
        lda #$D0
        sta a0396
b038F:  lda $9000,x
        adc $9000,y
.label a0396   =*+$01
        sta $80
        txa 
        adc #$F9
        tax 
        iny 
        dec a0396
        bmi b038F
        lda #$18
        sta $21
b03A5:  ldy $21
        lda $00B0,y
        sta $20
        lda $0030,y
        sta a03C7
        lda $0050,y
        sta a03C6
        ldx #$27
b03BA:  lda $80,x
        .text "e JJJ"
        tay 
        lda $0030,y
.label a03C6   =*+$01
.label a03C7   =*+$02
        sta $1E00,x
        dex 
        bpl b03BA
        dec $21
        bpl b03A5
        lda $26
        adc #$03
        sta $26
        sta $24
        lda $27
        adc #$01
        sta $27
        sta $25
        jmp j0386

