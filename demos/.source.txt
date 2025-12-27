* = $0326
   rol
   slo ( $ed, x)
   inc $78, x
   lda #$05
   sta $63
   lda #$1f
   sta $61
   sta $d018
   ldy #$3f
   ldx #$00

label_033a:
   inc $61

label_033c:
   lda $63
   sta $62

label_0340:
   lda $61
   sta $9000, x
   sta $90c0, y
   eor #$ff
   sta $9080, x
   sta $9040, y
   sta $3820, x
   inx
   dey
   bmi label_036b
   dec $62
   bpl label_0340
   inc $61
   dec $63
   clc
   lda $64
   adc $63
   asl
   sta $64
   bcs label_033c
   bne label_033a

label_036b:
   iny

label_036c:
   lda #$04
   sta $0030, y
   lda $fe
   sta $0050, y
   adc #$28
   cmp $fe
   sta $fe
   bcs label_0381
   inc $036d

label_0381:
   iny
   cpy #$20
   bne label_036c

label_0386:
   ldy $24
   ldx $25
   lda #$d0
   sta $0396

label_038f:
   lda $9000, x
   adc $9000, y
   sta $80
   txa
   adc #$f9
   tax
   iny
   dec $0396
   bmi label_038f
   lda #$18
   sta $21

label_03a5:
   ldy $21
   lda $00b0, y
   sta $20
   lda $0030, y
   sta $03c7
   lda $0050, y
   sta $03c6
   ldx #$27

label_03ba:
   lda $80, x
   adc $20
   lsr
   lsr
   lsr
   tay
   lda $0030, y
   sta $1e00, x
   dex
   bpl label_03ba
   dec $21
   bpl label_03a5
   lda $26
   adc #$03
   sta $26
   sta $24
   lda $27
   adc #$01
   sta $27
   sta $25
   jmp label_0386
