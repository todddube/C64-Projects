* = $0801
.byte $0B,$08,$EF,$00,$9E,$32,$30,$36
.byte $31,$00,$00,$00
   sei
   inc $d030
   lda #$38
   sta $01
   ldx #$34

label_0817
   lda $0842, x
   sta $01ff, x
   dex
   bne label_0817
   ldx #$bf

label_0822
   lda $0875, x
   sta $00f6, x
   dex
   bne label_0822
   ldy #$25

label_082d
   dex
   lda $2ca2, x
   sta $8be5, x
   txa
   bne label_082d
   dec $0833
   dec $0830
   dey
   bne label_082d
   jmp $0116
   pha
   lda $6877
   rol
   sta $f7
   inc $0202
   bne label_0852
   inc $0203

label_0852
   pla
   rts
   inx
   txa

label_0856
   asl $f7
   bne label_085d
   jsr $0200

label_085d
   bcc label_0871
   inx
   cpx #$08
   bne label_0856
   beq label_0871
   ldx #$07
   inx

label_0869
   asl $f7
   bne label_0870
   jsr $0200

label_0870
   rol

label_0871
   dex
   bne label_0869
   clc
   rts
   nop #$03
   sta $0801
   inc $fa
   bne label_0881
   inc $fb

label_0881
   dex
   rts

label_0883
   ldy $f8
   ldx #$02
   jsr $022f
   sta $f8
   tya

label_088d
   ldx #$06
   jsr $022f
   jsr $00f9

label_0895
   ldy #$00
   tya
   ldx #$02
   jsr $022f
   cmp $f8
   bne label_088d
   jsr $0211
   sta $2d
   lsr
   bne label_08e8
   jsr $0225
   lsr
   bcc label_08f6
   jsr $0225
   lsr
   bcc label_0883
   iny
   jsr $0211
   sta $2d
   cmp #$80
   bcc label_08ca
   ldx #$01
   jsr $0226
   sta $2d
   jsr $0211
   tay

label_08ca
   jsr $0211
   tax
   lda $01a5, x
   cpx #$10
   bcc label_08db
   txa
   ldx #$04
   jsr $0226

label_08db
   ldx $2d
   inx

label_08de
   jsr $00f9
   bne label_08de
   dey
   bne label_08de

label_08e6
   beq label_0895

label_08e8
   jsr $0211
   cmp #$ff
   beq label_0912
   sbc #$00
   ldx #$00
   jsr $022f

label_08f6
   sta $2e
   jsr $0223
   adc $fa
   ldx $2d
   sta $2d
   lda $fb
   sbc $2e
   sta $2e
   inx

label_0908
   lda ( $2d ), y
   iny
   jsr $00f9
   bne label_0908
   beq label_08e6

label_0912
   lda #$37
   sta $01
   dec $d030
   lda $fa
   sta $2d
   lda $fb
   sta $2e
   cli
   jmp label_0817
   brk
   asl $20e0
   slo ( $0c, x)
   php
   slo $05
   pla
   isc $0a04, x
   slo $140b

label_0935
   php
   slo $00
   shx $3228, y
   bmi label_0974
   and ( $29 ), y
   jsr label_203a
   sax $5620
   sre ( $43, x)
   nop $1326, x
   nop $12
   nop $10
   ora ( $cf, x)
   rra $41
   cmp ( $b6, x)
   sbc ( $e3, x)
   alr #$15
   rla $59d4, x
   beq label_0913
   bvs label_0935
   sta $20, x
   ora ( $bf ), y
   isc $e4
   brk
   jam
   nop $18
   bpl label_098f
   slo ( $e9, x)
   isc $a7b2, y
   nop
   tas $d1e8, y

label_0974
   rti
   nop
   sta $3a, x
   lsr $8a
   sta ( $b1, x)
   dex
   and $a1
   nop
   rla ( $a0, x)
   jam
   lax $dcf8
   isc $01a9, y
   sta $d41a
   nop #$66

label_098f = * + 1
   dcp $ffa4, y
   dcp $26f0
   nop $88, x
   rol $0f
   php
   ldx $79
   dey
   jsr label_2323
   rol $a6
   dcp $573e
   rts
   rts
   nop $8f
   isc $49, x
   adc $cccd
   and $0284, x
   lax ( $34 ), y
   jam
   lda $b9b2, y
   anc #$b7
   ldx $23, y
   rra $8bcb
   sta $0a68, x
   ldx $26
   dey
   nop $54, x
   nop #$4e
   dex
   asl
   jmp $b54e
   txa
   lsr $0aad, x
   lsr $0ab5
   bmi label_0a25
   brk
   lsr $2f
   php
   dec $ad
   php

label_09dd = * + 1
   bcs label_0a24
   cmp ( $f1 ), y
   sbc $2902, y
   slo $9f11, y
   lda ( $f9 ), y
   dcp ( $a5 ), y
   sbc #$51
   eor $26
   nop $09, x
   sei
   adc $a7de, x
   dec $87
   txs
   ror $42
   isc $a65e, x
   eor ( $80 ), y
   lsr $58cc
   ldy $80, x
   rla $1280
   jam
   adc $fe, x
   bmi label_09dd
   ora $c5
   dex
   nop $81, x
   and $81, x
   nop $bcc6, x
   jam
   rol $a773
   rla $ce, x
   rla $f220
   jam
   nop $5f53, x
   rla $c2, x

label_0a24
   nop #$17
   lax ( $19 ), y
   jam
   nop $502b, x
   cmp ( $60 ), y
   rol $abcb
   cmp $324c, y
   isc $1308, x
   cmp ( $d1 ), y
   asl $9dd2, x
   sax $39ba
   isc ( $c5, x)
   rla ( $94 ), y
   alr #$96
   nop
   adc $8c7f, y

label_0a4a = * + 1
   nop $28
   sbc #$e5
   ldy $e9, x
   sbc $ab
   ldx $8b
   cpx $cd
   adc ( $29 ), y
   rol $f7
   php
   ora $29
   ldy $02
   nop $85, x
   sax $11
   eor ( $18, x)
   cmp ( $91, x)
   slo $b1da, y
   sre $0901
   sta $d1da
   eor #$01
   sta $8400, x
   nop
   ora ( $dd ), y
   ldy $604f
   nop
   bcc label_0a96
   nop $e9, x
   rts
   jam
   lda ( $af ), y
   ldy $eb, x
   sre ( $05 ), y
   bpl label_0a8b

label_0a8b = * + 2
   slo $1a98, y
   cmp $51
   nop $ce, x
   lda #$54
   sre ( $28 ), y
   sre ( $ea, x)

label_0a96
   nop $57, x
   jam
   rol $a1, x
   ldx #$98
   cpx $b9
   tax
   jsr label_2056
   sta $3f10
   sre $d361, x
   nop
   iny
   sta $cc7f, x
   beq label_0b09
   nop $e319, x
   jam
   anc #$00
   and ( $32, x)
   sre ( $54, x)
   jam
   adc ( $8f ), y
   cpx #$8b
   slo $7a, x
   nop $72
   sbc $1674, y
   dcp $80, x
   bcc label_0a4a
   iny
   nop $6d, x
   pla
   sta $f8cb
   lax $18, y
   rla $2e, x
   ldx #$da
   bne label_0af8
   dec $47, x
   lsr $6294, x
   and #$92
   adc $bd64, y
   dcp $40, x
   dcp ( $6e, x)
   adc $e1f1, y
   ldy $e4
   isc ( $d0 ), y
   arr #$7f
   rla $ff
   jam
   jam
   rti
   ora $c4ad

label_0af8
   sty $4b, x
   clv
   cmp ( $6d ), y
   lsr $3e
   cmp $d8
   isc $0f09, y
   sta $d418

label_0b09 = * + 2
   jsr $6abd
   ora $b08f, x
   sbc $93e4
   beq label_0b1d
   bpl label_0b1a
   lda $7648, x
   jam
   eor $99, x

label_0b1a
   slo ( $82, x)

label_0b1d = * + 1
   sbx #$42
   sax $21, y
   lda $03
   anc #$c4
   pla
   lda $f053, y
   ldy $ed2f
   cpy $7d22
   jam5e, x
   ora ( $ae ), y
   cld
   rol $fe y
   and $7a, x)
   bcs label_0b53
   lda $03)
   anc #$c412, x
   pla $133e, x
   lda $f053, y
   ldy $ed2f
   cpy $7d22c6, x)
   isc $215e, x
   sbc $8f
   nop
   sre ( $48 ), y $38a6, x
   slo ( $64, x) x
   rla $cd
   sre ( $1e, x)
   nop $0112, x
   ora $133e, x = * + 2
   tax
   dec $14, x
   isc ( $c6, x)
   ror $03, x $bac6, y
   cli
label_0b53
   rol $38a6, x, y
   nop $c4bc, x
   sre $719d, y ( $3c, x)
   asl
 $a2f2, x
label_0b5f = * + 282
   dec $0ad7
   lsr $65b6, x $48, x
   jam
   sbc $bac6, y
   cli
   rla $60 ), y
   isc $9a3d, y $3a, x
   jam
   sax ( $3c, x)
   rol $b274
   shy $a2f2, x6, x
   sty $0e82
   rts
   dec $48, x
   slo $f581, x $2d09, x
   dcp $795a75 ), y
   lda #$b8
   sre ( $fa ), y3
   ora $3a, x
   lax $7c85
   jam
   rla $55
   dcp $a3d6, x
   stx $79 x
   sbc
   bpl label_0bb2
   slo ( $2e ), y
   nop $fc

label_0bb2
   lda $33ef, x
   ane #$4e
   asl $17
   rol $b982, x
   jam
   asl $01, x
   sre $c9b2, y
   inx
   ora $fc, x
   sha $037a, y
   sbc $0c22, x
   sre ( $dc ), y
   nop
   txa
   clv
   shx $83e0, y
   slo $25, x
   jam
   cmp #$74
   cmp $12, x
   jam
   nop $8b94, x
   pla
   nop $b0de
   asl $6884
   dcp ( $72 ), y
   jam
   nop #$59
   tay
   jam
   sta $32f7
   jam
   iny
   nop $ac, x
   dcp $41
   ora ( $00, x)
   sre $dc, x
   lsr $7f29

label_0bfc
   isc ( $5c ), y
   and ( $ab ), y
   jam
   and $f3
   inx
   rra $a622, y
   ora $38
   dec $e8d0
   nop $f8, x
   rla $5e
   jam

label_0c11
   dcp $3082, x
   lax $56, y
   rla ( $ed ), y
   asl $f7
   ora $b5, x
   lda ( $9c, x)
   jmp ( $c202 )
   ora ( $93, x)
   lax ( $59 ), y
   beq label_0bfc
   sha ( $f3 ), y
   jam
   nop #$85
   nop #$7d
   jsr $a067
   cpy #$80
   asl $9397, x
   lda $a94f
   nop $5cc7, x
   nop #$1f
   jam
   nop
   isc $a631
   slo $ae72, x
   slo $9f71, x
   sta $b82c
   cpx #$f6
   jam
   slo ( $34, x)
   ldx #$bb
   plp
   and $fb
   plp
   asl $3b, x
   plp
   bpl label_0c80
   asl $34
   jam
   ldx $09
   ora ( $ec, x)
   shy $0209, x
   sbc #$d5
   jmp ( $58e6 )
   asl $76, x
   ldy $e3, x
   ldx #$cf
   ora ( $7a ), y
   bne label_0cc2
   sbc $e7
   cpx $94
   dec $012b
   eor $a864

label_0c80 = * + 1
   nop $87, x
   dec $67ad
   sre $ac63, x
   nop
   cld
   lda $81
   sre $175d
   jam
   brk
   nop
   bcs label_0cb3
   ora #$f0
   nop #$27
   cmp $6a, x
   cmp #$0b
   jam
   bvs label_0cdc
   sax ( $69, x)
   and $20, x
   jam
   adc #$54
   lax $df
   nop $ec, x
   anc #$57
   inc $3300, x
   slo ( $a9 ), y
   anc #$79

label_0cb3 = * + 1
   lsr $94, x
   adc #$3c
   sta $a053, x
   tsx
   sax $a9, y
   lax $0c3a, y
   sha $294c, y

label_0cc2
   ora ( $27, x)
   jam
   rol
   lsr $a781
   jam
   nop $ce
   nop #$27
   jam
   nop $ce
   nop #$a7
   jam
   tas $0f85, y
   sre ( $22 ), y
   nop $13, x

label_0cdc = * + 1
   eor ( $4c ), y
   slo $b5, x
   nop #$88
   lxa #$7b
   nop
   sha $ce7f, y
   asl $a9, x
   jmp $59c9
   nop $3897, x
   brk
   lsr $5601, x
   nop $cc
   sre $6b31, x
   and ( $8a, x)
   sbx #$cc
   dcp $c3
   eor $ce00
   slo $5a49, x
   cmp $85
   pha
   alr #$23
   ane #$57
   lda #$df
   ldy #$0a
   cpy $f86e
   sei
   nop $5c, x
   sha $3b35, y
   rra ( $3c ), y
   nop $eb, x
   asl $348c
   sbc ( $64 ), y
   cmp ( $58, x)
   rra $6131
   and ( $a6, x)
   lax $019c, y
   inc $7201, x
   sbc $7202, y
   sbc $c95f, y
   anc #$93
   shy $2da8, x
   adc $2ad2, x
   stx $eb
   sre ( $c0 ), y
   eor $a9c5, y
   dec $d732
   nop
   inx
   nop $43, x
   nop $a9, x
   dcp ( $08 ), y
   nop #$96
   lax $38
   ane #$54

label_0d54
   sbc $519e, y
   anc #$d0
   lda $2c
   slo ( $7b ), y
   sre ( $9c, x)
   eor $0d, x
   rra $27cf, y
   dey
   anc #$46
   stx $b909
   lda ( $c6, x)
   rol
   dcp $5fb8
   sha ( $c2 ), y
   ldy $48, x
   cpy #$9a
   shy $e2d0, x
   nop $67, x
   cmp $3c79, x
   and #$44
   jam
   pla
   eor $c5
   asl $4629
   adc $8ad7
   ldx $e114, y
   dec $84
   nop $a250, x
   sre ( $e6 ), y
   cmp $c534, x
   sbc ( $4c, x)
   nop $4166, x
   inc $5ebe, x
   ora ( $5e, x)
   ldy $bc04, x
   adc $77
   ldx #$e7
   bpl label_0e0e
   isc $825b, x
   dcp $0909, y
   sre $58a8, y
   rts
   pla
   pla
   bvs label_0e30
   nop #$88
   bcc label_0d54
   ldy #$a8
   clv
   cpy #$d0
   cld
   inx
   sbc $1101, y
   and ( $39, x)
   eor #$59
   adc ( $89 ), y
   lda ( $b9, x)
   cmp ( $f2 ), y
   nop #$51
   jam
   sre ( $94 ), y
   sta $d7, x
   clc
   txs
   slo $5f9d, y
   jsr $e4e2
   isc $29
   arr #$ee
   adc ( $34 ), y
   rla $7a, x
   ldx $e53f, y
   isc $e9
   cpx $2d6d
   dcp $9f
   anc #$5d
   asl
   sbc $9745
   tay
   sec
   sta $1db7
   jam
   eor $0736, x
   jam
   dcp $17be, y
   cmp $c0f0, x
   dec $8d7f
   slo $d7
   ldy $64

label_0e0e
   nop $14, x
   ora $56, x
   rra $fa6b, x
   and ( $b1 ), y
   lda ( $35 ), y
   rol $b9, x
   nop $0f, x
   nop $0503, x
   nop #$8a

label_0e22
   cpy $800c
   eor ( $f7, x)
   rla ( $8f ), y
   rts
   brk
   cpx #$3b
   cpx $c6

label_0e30 = * + 1
   and $01f4, x
   rra $847f, y
   sty $f7e7
   sax $fa
   stx $e4bf
   pha
   rra $0a, x
   rla $cb67, y
   nop $0884, x
   sty $13
   sax $8b6f
   isc $05af, y
   nop $f4b9, x
   isc $f291, y
   sbc $0080, y
   bvc label_0e85

label_0e59
   plp
   bit $20
   nop #$8c
   nop #$09
   beq label_0e59
   dcp $ff8c
   ora ( $30 ), y
   sty $8030
   sbc #$f8
   lax ( $3f, x)
   tsx
   beq label_0e92
   sax $84
   nop #$87
   rla $87
   sax ( $cf, x)
   jam
   cpy $88d1
   dcp $8398

label_0e81 = * + 1
   rol $3d, x
   sre $96ca, x

label_0e85
   sty $374f
   isc $ff, x
   isc ( $00 ), y
   ora ( $05 ), y
   slo ( $0a, x)

label_0e92 = * + 2
   and $02ff
   bit $90
   ane #$a0
   slo $0ef1, x
   slo $3fbe, x
   cpx #$04
   brk
   asl $e3e9, x
   inc $04
   bcs label_0eac
   sta $55
   bcc label_0eb4

label_0eac = * + 1
   and $c141, x
   cpx #$16
   brk
   ldx $42, y

label_0eb4 = * + 1
   slo ( $93 ), y
   cpy #$05
   ror $e120
   bit $017c
   jam
   slo ( $7e, x)
   slo ( $78, x)
   ora $27
   bcs label_0f29
   lax $e8, y
   jam
   jam
   sta ( $9c, x)
   dcp $01, x
   slo $01, x
   sax $02, y
   slo $02, x
   sax $03, y
   slo $03, x
   sax $04, y
   slo $04, x
   sax $05, y
   slo $05, x

label_0ee0
   sax $06, y
   slo ( $06 ), y
   lax $0797
   slo $07, x
   clv
   isc $16, x
   rra $b5cf
   cmp ( $ad, x)
   rra $f771, x
   sta $9c22, x
   bvs label_0e81
   adc ( $b2 ), y
   clc
   tya
   ora $9c, x
   and ( $1c, x)
   nop $02
   sec
   dec $96fe, x
   bpl label_0ee0
   beq label_0f23
   rti
   anc #$e3
   dex
   nop
   ror $8b02, x
   sbc $f9be, y
   sha ( $63 ), y
   jam
   and $8f
   iny
   cpx $fc
   sbc $5200, x
   sax $e0

label_0f23
   nop $97, x
   cmp $f7, x
   cpy $73

label_0f29
   slo $0c92, x
   ror $a749, x
   isc $eb
   asl
   lda ( $2f, x)
   ldy $aa, x
   ldy $2730
   slo $95ed, x
   rla ( $05 ), y
   lda $5130, y
   lax $8637, y
   nop
   isc ( $fc ), y
   sbc $15
   ora $e27e
   txs
   clc
   nop $8692, x
   ldx $4ff8, y
   dcp $ee88
   ldx $7322, y
   nop #$43
   lax $ec88
   sed
   sha ( $e3 ), y
   isc ( $15, x)
   cmp ( $d0, x)
   plp
   sbc $eb, x
   sha $3d21, y
   adc $4a83, x
   sbc ( $f7 ), y
   rla $c7
   cpx #$00
   jam
   nop $bd
   sbc $ec, x

label_0f7a
   clv
   bit $f6f5
   lax $3881, y
   isc $95, x
   ora $92
   sbc #$de
   inc $fa, x
   nop $16
   rra ( $8f ), y
   nop $bdfc, x
   txs
   ora $99
   inc $e5, x
   bcc label_0f7a
   dec $ad57, x
   rol $a6bb, x
   lax ( $df ), y
   rla $25, x
   sbc $63b9, x
   lax ( $dc ), y
   brk
   ora $1f03
   lax ( $06 ), y
   jam
   nop
   rol $2e, x
   rol $13
   sbx #$d6
   lsr
   lsr $3e57
   isc $aa1b, x
   lsr $f957, x
   adc $d54f
   nop $3bf9, x
   isc $087d, y
   slo $08, x
   clv
   nop $fc1e, x
   rla ( $7f ), y
   nop $3c, x
   dec $7f0d
   rra $874d, x
   sbc ( $94 ), y
   sre $12dc, x
   ldy #$5f
   eor #$7b
   nop $77fe, x
   sec
   brk
   jam
   nop $26
   lax ( $6f ), y
   lda $eb, x
   nop $142a, x
   rti
   tya
   nop $df
   isc $498a, y
   nop #$4e
   rla $5edf, x
   jam
   cld
   jmp ( $9640 )
   eor ( $29, x)
   sre ( $98, x)
   nop $07
   lsr $d5
   lsr
   nop $12ab, x
   nop $fc92, x
   jam
   cpy #$d3
   jam
   sre ( $c0 ), y
   nop $4d, x
   nop $9b, x
   sty $e5, x
   lsr
   lda #$b8
   lxa #$28
   adc $6f, x
   stx $60
   stx $97, y
   inc $b7, x
   dec $dc, x
   rol $f4, x
   lda $8e
   ora $97
   and $be, x
   and $c5
   ora $e3, x
   rol $0f, x
   ror $19
   ror $9d31, x
   jam
   rra $3599
   tas $1360, y
   jam
   rla ( $53, x)
   isc ( $65 ), y
   slo ( $76, x)
   lax ( $9c ), y
   nop $eb6a, x
   nop $0101, x
   eor ( $c3, x)

label_1056 = * + 1
   sax ( $cf, x)
   ora $aaae, y
   lda $bc, x
   cpy #$7d
   clv
   nop $4464, x
   jmp $007e
   bpl label_1097
   bit $6236
   lsr $7c
   nop $1b0e, x
   and ( $30, x)
   asl $0000, x
   sta ( $9d, x)
   rla $43
   arr #$31
   dcp ( $70 ), y
   bvs label_1056
   lda ( $c7 ), y
   nop #$60
   ldy #$83
   sbc ( $86, x)
   cld
   rti
   cld
   nop $4c, x
   iny
   adc $f118, y
   ldx $3a, y
   bne label_10d7
   brk
   php

label_1097 = * + 2
   dcp $81e1
   ora ( $02, x)
   nop $00aa
   asl $02
   asl $44
   jmp ( $2038 )
   bit $2c
   bmi label_1120
   jmp $cb46
   ora ( $0e, x)
   nop $8c, x
   asl $37
   nop $8f
   nop
   jam
   stx $84, y
   nop $1d17, x
   and $2222, y
   sei
   cli
   rra $c9
   dec $e3
   sty $4d06
   jmp ( $036b )
   adc ( $d3, x)
   ror $40, x
   nop
   nop $71
   cpy #$e4
   cpy #$80
   sta ( $e1, x)
   brk

label_10d7
   bmi label_10f1
   sbc $57c5, y
   jam
   and $9d
   rts
   ora ( $64 ), y
   sbx #$31
   dec $e1, x
   ora $a0b0, y
   cpx #$c3
   adc ( $05 ), y
   and $47a9

label_10f1 = * + 1
   dec $8b
   slo $8603
   sty $b8ca
   ora $0f93, y
   jam
   nop $0f26, x

label_10ff
   jam
   nop $19
   lsr $41
   cpx $65
   eor ( $73 ), y
   slo $c201, x
   bvc label_10ff
   eor ( $e5, x)
   clv
   brk

label_1113 = * + 2
   nop $080c, x
   ora $de36, y
   rol $0c
   asl $573f, x
   eor ( $14, x)
   anc #$bf

label_1120
   lax $0898, y
   sre $2682
   plp

label_1128 = * + 1
   eor ( $00, x)
   txa
   sta ( $23, x)
   ror $c9
   cpx $49
   nop $91d8, x
   nop $0090, x
   php
   nop $4365, x
   cpy $3314
   rol $04, x
   php
   slo ( $33 ), y
   sre ( $40, x)
   sbc ( $04, x)
   ora $22
   nop $1f, x
   eor ( $a0 ), y
   adc ( $3c, x)
   rla ( $e6, x)
   rol $58
   php
   jsr $82e0
   rol $81, x
   jam
   nop
   sax ( $02, x)
   pha
   ldy #$38
   plp
   shy $b74d, x
   inx
   lax $969e
   nop
   rra $e093
   nop #$50
   brk

label_116e
   pla
   jam
   bpl label_1113
   sei
   brk
   pla
   cmp $6939, y
   iny
   sta $0070, y
   bmi label_11f0
   bmi label_1128
   sre $9786, x
   sty $88
   dcp ( $7c ), y
   sty $18, x
   ora ( $38, x)
   beq label_11ad
   jam
   ora $e511, y
   ora $8d04, x
   dcp $7414

label_1198 = * + 1
   slo $301e, y
   rol $0323, x
   asl $2055, x
   clv
   sty $1fcd
   php
   sre $a1d1
   slo $31, x

label_11aa
   sre ( $0c ), y

label_11ad = * + 1
   rla ( $d4, x)
   stx $f0, y
   bvc label_122a
   cpy $408d
   php
   cmp $95
   nop $4e02, x
   jam
   dex
   nop #$22
   slo $1c38, y
   slo $01
   lax $07
   dec $4f, x
   beq label_116e
   bvs label_11ea
   sec
   sbc ( $46, x)
   nop #$25
   nop $136c, x
   lda #$b9
   cmp $a5, x
   jam
   nop #$cf
   sty $88
   cmp ( $b4 ), y
   dec $4c
   sed
   cpy $f985
   eor #$04
   cpy $80

label_11ea = * + 1
   nop #$85
   slo ( $0f ), y
   tya
   nop $91, x

label_11f0
   ora #$9f

label_11f2
   ora ( $d1 ), y
   ora $8f, x

label_11f7 = * + 1
   bcc label_1198
   sbc $f161, x
   cli
   cpy #$3c
   nop $c0

label_1201 = * + 1
   shy $4385, x
   cmp ( $14, x)
   rra $32bf, x
   jam
   clc
   slo $040c, x
   bvc label_11f2
   slo $9310
   ora ( $03 ), y
   jam
   bcs label_11f7
   stx $c382
   txa
   nop
   anc #$00
   anc #$7f
   isc ( $20, x)
   sta $9d
   sbc $5a6b, y
   cli
   bcc label_11aa

label_122a
   jam
   rol $46
   lsr $91cb
   sta ( $9c ), y
   jam
   nop
   asl $82
   stx $cc
   ora $ce07
   bit $67
   cpy $0c
   php
   jam
   ldy $a724, x
   lax ( $1e ), y
   sta $05
   sre $82
   isc ( $c6, x)
   nop $a1
   plp
   ldy #$30
   nop $4646, x
   txa
   slo ( $ed, x)
   ane #$0b
   nop
   rti
   bit $2c
   adc #$62
   lsr $66
   sta ( $0b, x)

label_1263
   ora ( $23 ), y
   jam
   dcp ( $86, x)
   bit $41
   eor ( $4b, x)
   nop
   ror
   isc ( $63 ), y
   jam
   bcs label_127d
   bcc label_127b
   nop $18, x
   cli
   ldx #$3e

label_127b = * + 1
   bcc label_12b3

label_127d = * + 1
   ora ( $fb, x)
   clc
   jam
   sha ( $77 ), y
   sed
   jam
   bcc label_12fc
   asl
   plp
   isc $c0c0, y
   bmi label_12bd
   lxa #$f2
   rra $c1f0, y
   sta $669e, y
   adc $87
   cpx $a6
   rra ( $19 ), y
   tax

label_129e = * + 2
   nop $d39e, x
   dcp $27bc, x
   sre ( $c7 ), y
   and $7ff5, y
   dcp $c07e
   ldy $c2, x
   rla ( $9e ), y
   isc ( $3a ), y
   bcs label_129e

label_12b3 = * + 1
   sty $c9, x

label_12b4
   tas $5f35, y
   sha ( $de ), y
   pla
   sta $1f, x

label_12bd = * + 1
   slo $98ad, x
   shy $f64e, x
   bcs label_12b4
   shx $1f5f, y
   asl $9d, x
   asl $a4, x
   and $c586
   nop #$85
   lax $5d, y
   sax $85, y
   stx $c5
   ldy $44, x
   isc $67, x
   ldx $da16, y
   rra $42, x
   lda $1e, x
   rts
   jsr $cd60
   sax $9c14
   asl $c5, x
   sta $42, x
   lsr $2cac
   and $2e3b
   ror $394c
   nop $aaa2
   dey
   stx $7f

label_12fc = * + 1
   nop $8c
   jmp ( $bb39 )
   las $1f38, y
   inc $fdfc, x
   nop $db99, x
   tya
   jam
   nop $f238, x
   rra $f067
   isc $bfff, x
   and ( $6c ), y
   lsr $6744, x
   asl $47, x
   stx $3c
   sta $1e39, x
   asl $7d7d, x
   beq label_139e
   isc $f7fb, y
   sbc ( $e1, x)
   sbx #$b3
   rla $86, x

label_132e
   isc $0e
   asl $68a5, x
   eor $fbff, x
   sax $f7
   rla $7e7f, x
   isc $efff, x
   isc $efcf, x
   cmp $9edc
   rol $defe, x
   shx $3d7c, y
   sta $58c8, x
   rra $91, x
   lda $9f
   dec $0646
   nop $bb08, x
   nop
   lsr $f8f8, x
   jam
   stx $6d2c
   cmp $85db, x
   nop #$7c
   isc ( $b1, x)
   beq label_132e
   nop $d9
   and $7cfa, y
   jam
   iny
   ldy $04
   sre $1cbb, x
   ora ( $b3 ), y
   isc $f7, x
   inc $1c10
   inc $6c70, x
   eor $31, x
   rla ( $a6, x)
   dec $06, x
   nop
   jmp $e2cc
   lda ( $f1 ), y
   rra ( $27 ), y
   lax $9e8f
   dcp $c2

label_1393 = * + 2
   sha $d254, y
   sre $07, x
   rol $e1e1
   sax $662e
   dcp $04, x

label_139e
   cmp $1f9e
   ldy $7c7a, x
   bvs label_1393
   isc $a6e6, y
   lsr $1a
   adc $31
   jam
   sha $3d1e, y
   tay
   isc ( $be ), y
   nop
   sre $ff
   sax ( $f3, x)
   isc $e7, x
   isc $0eef
   shy $f83c, x
   bvs label_13ee
   ldx $60e7, y
   lsr $0302, x
   rla $7cbd, x
   and $c3a4, y
   php
   rla $51e9, x
   dcp $2693, y
   sbc $df
   ldx $03, y
   rla $6e
   slo ( $6f, x)
   isc $c3f7, x
   txs
   dcp ( $ca, x)
   nop $4c, x
   cmp #$fb
   isc $ec, x
   cpy $47a3

label_13ee = * + 1
   asl $05fa, x

label_13f2 = * + 2
   eor $e0cb, x
   lda ( $a0 ), y
   dcp ( $e3 ), y
   asl $39, x
   sbc #$33
   rla $87be, x
   slo $b5e9, y
   inc $93, x
   cpy $6d18
   lda $06
   rol $55bb, x
   inc $3df0, x
   inc $2ed4
   nop
   bvs label_1483
   nop $9a
   lsr
   isc $a3fc, x
   sax $7b, y
   anc #$df
   nop $36b9, x
   nop $b1, x
   las $7f34, y
   inc $697c, x
   sty $c2
   nop
   nop $c3, x
   dcp $9ca6, y
   nop
   sha $f63f, y
   sec
   ror $6ffd, x
   rla $70, x
   cld
   inx
   dcp $8791, y
   rra ( $a3, x)
   rla $0e
   ror $e70e, x
   isc $0d
   lda #$0a
   rla $9499, y
   sed
   lda $4d81, x
   nop $b9
   lsr
   sty $61, x
   sbc ( $64, x)
   lax $42, y
   sty $9b39
   stx $00, y
   adc $a8dc, y
   bne label_1476
   sax $b284
   bvs label_13f2
   lsr $c1
   sed
   inc $963f, x
   nop $5c30, x
   sha $4bd1, y

label_1476
   slo $8ec3, x
   and $0b8d, x
   ldx $38, y
   isc $dc
   cmp ( $66 ), y

label_1483 = * + 1
   ldy $92, x
   sre $0fa6, x
   ror $36e5
   lax $36
   rts
   inc $6f
   rti
   cmp $a720, y
   rra $efef
   jam
   jam

label_1499 = * + 1
   nop $92f5
   jam
   cpy $3a1d
   jam
   jam
   ora $2014
   nop $1b3e, x
   clc
   sec
   rra $67, x
   cpx $586f
   sei
   cmp $f84f, x
   ora $43b6, y
   nop $7f1e
   ror $1c, x
   eor ( $e1 ), y
   jam
   jam
   rla ( $9d, x)
   eor #$e3
   sbc #$d1
   lax $8e
   dcp ( $43, x)
   rts
   slo ( $6f, x)
   nop
   nop $6f
   jmp $d240
   sty $aa, x
   sbc $ffef
   las $3637, y
   eor $6e34, y

label_14dd = * + 1
   ror $b27c
   sre $2f
   lax $7926
   lda ( $06, x)
   rla $0773, y
   ror $ff7e, x
   dcp $83, x
   arr #$09
   shy $9f2e, x
   cli
   beq label_1499
   sax $33
   sre ( $db ), y
   nop $19, x
   nop $3777, x
   and #$41
   nop #$4e
   sbc ( $7e, x)
   iny
   ora $7a
   jam
   lax ( $b7, x)
   bmi label_14dd
   dec $db9d, x
   sha ( $a7 ), y
   sax $8704
   dcp $d6, x
   sty $b1, x
   adc ( $93, x)
   sha ( $f6 ), y
   ora ( $72, x)

label_151f
   brk
   inc $84
   nop $ee, x
   sre $f2
   asl $9f
   cpy #$9c
   nop
   dec $7493
   slo $fe
   bcc label_15a8
   adc $1f
   rra $e7
   sbc $f5f9, y
   ror $7e4f, x
   isc $b7
   sty $0b
   sec
   jam
   sax $efc9
   shy $daf7, x
   sbc ( $80, x)
   eor $e6f5, y
   ora ( $3d, x)
   sed
   inc $70de, x
   rla $bf
   ror $c755, x
   adc ( $d8, x)
   cmp $3f67
   dec $dd, x
   nop $4a, x
   cmp $666b
   plp
   isc $25ae, x
   bit $2c3c
   lda $e126
   adc #$d1
   ror
   jam
   cmp $996c
   ror $5b
   adc $d9, x
   sei
   cli
   jmp ( $445b )
   sre $1f7e
   shx $f1fd, y
   adc $74a7
   anc #$4e
   rla $3ebf, x
   adc $a7
   slo $c1c9
   cpx $d459
   rol $ef
   rla $0f0b, x
   lsr $9bcf
   bcc label_151f
   nop $6e4b, x
   jam
   sta ( $21, x)
   cpy #$e2
   nop $02

label_15a8
   jam
   sbc ( $21, x)
   ldy $02
   sta ( $e7, x)
   sre $46fc, y
   bpl label_15f4
   stx $44
   jam
   lda $0c
   rla $0a68, x
   slo $93
   lda $59f2, y

label_15c2 = * + 1
   sta $81c2, x
   nop #$21
   cmp $26ea, y
   eor $61bd, y
   anc #$3c
   lsr $ba
   inx
   sre ( $cf, x)
   sty $09d6
   slo ( $20, x)
   lsr $09, x
   nop $05

label_15de = * + 2
   slo $0107
   ora $cc05
   sta $20, x
   bpl label_1632
   cmp $98e3
   nop $3434, x
   nop $3f10, x
   asl $c8, x
   ora $33, x

label_15f4 = * + 1
   beq label_160d
   clc
   nop $3b, x
   sty $fc
   cpy $a0eb
   sre $333a
   adc #$13
   and $82, x
   eor ( $c3, x)
   lda $332c, x
   bcs label_166f

label_160d = * + 2
   jsr $503c
   lax ( $8e ), y
   bcs label_15de
   sax $cb
   ror $f33d
   bcc label_163d
   bvc label_161f
   rla ( $31 ), y
   rra ( $f0 ), y

label_161f
   rla $c13e
   jam
   ldy #$b3
   adc $8a70, x
   bmi label_1631
   tya
   nop $a361, x
   brk
   sty $89

label_1631
   asl $66
   ldy #$47
   clc
   dey
   sbc ( $81, x)
   cpx #$bb
   bvs label_1669

label_163d
   dcp $0983, x
   brk
   and $1602, y
   jam
   anc #$c6
   jam
   rti
   sei
   cli
   tay
   ldy #$7e
   ror $63
   ror $61
   sbc $b0, x
   sta $88, x
   lda ( $a1, x)
   and ( $c6, x)
   dcp $01
   adc $95e6, y
   tya
   sta $f17d, x
   cpx $899d
   nop #$a2
   clc

label_1669
   eor $e2c3
   stx $1c
   asl

label_166f
   nop #$fb
   cli
   plp
   nop $04
   ane #$f1
   isc $84
   nop #$58
   ror $2a02
   slo $92c6
   bcc label_16b1
   nop
   stx $70
   nop
   ldx $13
   cmp #$ff
   dcp ( $02 ), y
   ldy #$46
   asl
   lda #$87
   stx $0a
   sbc $f899, y
   asl $12, x
   slo ( $c5, x)
   nop
   clv
   pha
   bne label_16b0
   asl $36da
   and $30, x
   jam
   dcp $8c35
   isc $cadf, x
   nop #$82
   rol

label_16b0 = * + 1
   ldx #$9a

label_16b1
   nop
   lsr
   eor #$02
   php
   stx $e53c
   tya
   tay
   ror $60f8
   lda ( $0c, x)
   lax $be
   dcp $32, x
   slo ( $2c, x)
   ldy $db32
   brk
   cpy #$a1
   sbc ( $a1, x)
   cpy #$c0
   dcp $c5ff, y
   and ( $a2 ), y
   sha ( $e3 ), y
   rol $5a, x
   sre $f7, x
   dcp $d988
   slo $ae01, y
   nop $c946, x
   nop
   arr #$a5
   bit $aa
   lda $8f
   clc
   anc #$64
   nop $35, x
   nop $43, x
   adc $21
   nop $d435, x
   sre $30
   rla $2fe6, y

label_16fd = * + 1
   bvs label_16fd
   isc $efe0
   jam
   slo $c0e3
   nop
   ora $24c4
   jam
   ldx $5b83, y
   alr #$18
   sax $4eee
   and $3e2e, x
   eor $f71e
   sre $75, x
   rra ( $a2 ), y
   bmi label_1753
   nop $59d4, x
   lda $5a94, y
   dcp ( $64, x)
   and ( $02, x)
   cpx $8236
   dcp $bf8f
   sty $de6b
   rol $17, x
   lsr $858d
   lda $5e, x
   nop $9e
   ror $65
   lsr $64, x
   sta $b0, x
   cld
   nop
   jam
   nop $7e
   plp
   adc $fb71
   nop #$ba
   ora ( $cc ), y
   stx $74, y
   sre ( $86, x)

label_1753 = * + 2
   cmp $f197, y
   anc #$fc
   adc ( $1e, x)
   slo $b8e1, x
   anc #$fd
   isc $dc5c, x
   ora $c3, x
   sbc $43
   dcp ( $a3 ), y
   tas $9b2b, y
   bit $f236
   sta $ef83, y
   lax ( $80, x)
   rra $de, x
   isc ( $be, x)
   isc ( $e0, x)
   inc $0f
   sbc $dac1, x
   adc $a7
   cmp ( $d0 ), y
   sre $b1, x
   asl $1bbb, x
   slo ( $5a, x)
   jam
   lda $8deb, x
   tsx
   nop #$18
   sax $c660
   and $8aab, y
   nop $a639, x
   sbc $bac7, x
   lsr $a1, x
   lsr $41, x
   eor #$d0
   rra ( $3e ), y
   ror $c3, x
   cmp $8f
   isc $8214, x
   nop #$be
   rla ( $64 ), y
   rol $6e
   isc ( $f8 ), y
   bvc label_17d5
   ane #$1b
   sbc ( $35, x)
   inc $dc
   cpx $0b
   ora #$bc
   inx
   eor #$dd
   eor $4f6c, y
   bpl label_17f3
   adc $c74f
   brk
   isc $9d
   ora ( $d8, x)
   cli
   nop $3d
   sre $0bf1, x
   lsr $a0, x

label_17d5
   adc $e2
   adc $6b59
   nop $365b, x
   nop
   dcp $34, x
   adc $1a
   inc $df, x
   lda ( $d7, x)
   rol $d4
   ora $56dd, y
   slo ( $e7 ), y
   ldy #$e9
   isc ( $ef ), y
   sre $35, x

label_17f3
   cpx $43
   cpy $4d
   cmp $3eb1
   sbc $cfa7, x
   sre ( $f6 ), y
   ror $bb, x
   ldx $6f, y
   rra $7f5a, y
   rla $10b3
   plp
   brk
   cli
   slo $7d
   nop $6c42, x

label_1811
   rti
   nop #$03
   nop #$80
   ora ( $93, x)
   plp
   nop
   plp
   jam
   and $0032, y
   slo ( $8e, x)
   sax $e848
   ora $ba
   tsx
   ora $800c
   eor ( $42, x)
   cpy #$4a
   ora $40
   sre ( $23, x)
   ldy #$06
   stx $d0e0
   slo $832e, y
   rra $b8d0, y
   ora ( $07, x)
   bcs label_1811
   ldy $b8, x
   lxa #$40
   rol
   lda $a008
   ora #$8d
   slo $d028
   bpl label_17f3
   ldx $043d
   bit $28b4
   sbc #$b4
   dcp $06
   ora $5a1e
   tax
   inc $5b8e
   anc #$2a
   and $bd6d, y
   isc ( $b9, x)
   jam
   nop #$d6
   lxa #$12
   dcp $2536, y
   slo ( $ec, x)
   and $01
   inc $42a6
   sed
   nop $8901, x

label_187c = * + 1
   sre $0d6a
   rol $7346
   anc #$d2
   sre $b00e
   las $b802, y
   rol $c0c5
   adc $8511
   ldy $c1ab
   stx $23
   bvs label_1898
   cld

label_1898 = * + 1
   ldx $97e6
   jam
   stx $2b80
   dec $e8
   nop $87, x
   beq label_187c
   sty $f9, x

label_18a6
   lda ( $2c ), y
   cpy #$6c
   lda $05
   inc $59
   rra $4c8b, y
   ldy $ac, x
   brk
   slo $a9
   jam
   and $d968, x
   ane #$b2
   iny
   las $aa08, y
   nop
   stx $ab20
   arr #$80
   sre ( $73, x)
   and #$91
   lda $8006, y
   bmi label_1938
   sre $d5
   nop
   cmp ( $75, x)
   eor $30d9, x
   cpy $dcb0
   sax $c0
   brk
   arr #$11
   nop $e426, x
   anc #$a3
   nop $3b22, x
   stx $63
   ldy #$3e
   sax $7b11
   lsr $8bb2
   dcp ( $01 ), y
   sre ( $6b, x)
   rol $4fea, x

label_18fa = * + 2
   nop $05b3
   rol $cb64
   rra ( $be ), y
   cmp $e70e, y
   and $0283, y
   rra ( $72, x)
   ldx $2026
   anc #$27
   and ( $76 ), y
   jsr $0630
   and $0099, y
   ora ( $d7, x)
   cmp $90e7
   sax $4e
   shy $5367, x
   adc ( $5c, x)
   bit $30
   bcs label_18a6
   bmi label_1963
   nop $2c24, x
   nop $4a, x
   lda $0436, x
   tay
   inc $0d15, x
   sha $c2d2, y
   sec

label_1938 = * + 1
   bmi label_18fa
   nop $d8, x
   ldx $b5, y
   sha $70e0, y
   txs
   anc #$4e
   ldx $5c91
   nop $0a12
   rla $16
   rol
   sbc ( $e1, x)
   sax $df, y
   sbc #$d4
   sty $1c1e
   and #$42
   nop
   jsr $6c08
   sre $07, x
   rla ( $cf, x)
   sbc $18, x

label_1963 = * + 2
   sha $ccbf, y
   sre ( $de ), y
   clc
   rra $ed
   dcp $0d
   isc ( $6c, x)
   slo $dc
   sha $6153, y
   ldx $36f4, y
   rol $d20d
   asl $86
   isc $5089, x
   lsr
   las $eebe, y
   cld
   lax $d5, y
   txa
   nop #$d4
   nop #$77
   nop #$ef
   sbc $bde2, y
   sbc #$0b
   dec $6c60
   ror $0dbd
   rla $6193, y
   jam
   rol $9a, x
   cpx $c3b5
   isc $4168
   lda $f5c9
   nop
   nop
   lda $b7, x
   nop
   inc $ec
   dey
   arr #$71
   rts
   jsr $9d5c
   nop #$fd
   sbc #$44
   bpl label_19ed
   rol $47b4
   nop #$f4
   isc $26
   pla
   isc $cba3, y
   sbc ( $a3, x)
   stx $4a8f
   ldy $2d2e, x
   dey
   sbc $9f
   lax $0cdd, y
   cmp $62, x
   isc $6f2f
   sre $ef
   rol $f5, x
   sre $d6db, x
   sre $8937, x
   isc $cd
   asl $75, x
   jmp ( $d7d5 )
   slo $d67c, x

label_19ed = * + 2
   ora $d6cb, x
   dec $9b36, x
   lxa #$d5
   ror $7f5a, x
   eor $d9, x
   adc ( $df, x)
   cmp $d769
   sre $8d, x
   ldx $65, y
   stx $ef
   nop $fe, x
   nop $9b, x
   sty $e0f3
   cmp $78fa, y
   dcp $b6e0, x
   rol $97
   dcp $6c
   eor $af, x
   rla $49cb, x
   isc $70f5, y
   jmp ( $db4f )
   rla $d884
   nop $be
   slo ( $62 ), y
   adc $77e9, y
   jmp ( $594f )
   lda $8bed, x
   cpx $18
   slo ( $03, x)
   isc $d886
   lax ( $68, x)
   nop $f83e, x
   arr #$0a
   jam
   ldy $9f
   eor $193e, y
   tsx
   ldx #$28
   dcp $8f, x
   cmp #$d8
   slo $d67b, x
   ora ( $f9 ), y
   adc #$ff
   adc ( $e5, x)
   adc ( $79 ), y
   dcp $476c, y
   ldy $fd
   nop
   ldx $c5, y
   lax $ff66, y
   ora ( $9f, x)
   nop $7e, x
   eor #$ba
   jam
   lsr $399b
   lda $94a7, y
   rra $cacd, y
   sei
   nop $cd, x
   inc $65
   sbx #$2f
   adc $7aac, y
   nop #$4e
   jam
   sbc #$d7
   cpx #$ab
   dec $8e, x
   ora $fe
   isc $686f, y
   sbc $ab, x
   cmp $a2f1, x
   dcp ( $d6, x)
   dcp $633a, y
   sbc $1c
   rra $07, x
   lda $935c
   bcs label_1acd
   and $27
   sta $f61e, y
   shx $80c1, y
   sax $07, y
   ldy $c77f, x
   lda $1d, x
   rla ( $6a ), y
   rra $a5, x
   nop $ef11, x
   adc $1dec
   adc #$ef
   adc $eb
   adc $1d76
   sre $6c, x
   sbc $2c, x
   lda $f42f, y
   rla ( $54, x)
   dec $7b66, x
   shx $7293, y
   clv

label_1acd = * + 2
   and $7978, x
   lda $e6b7, y
   lsr $6f72
   sax $ad79
   sax $ad
   lsr $1afc, x
   isc $7bf5, y
   nop $4e, x
   lsr $9af6, x
   sec
   tsx
   rol
   sbc #$69
   ldx $ce, y
   jam
   isc $a3, x
   eor $d2fa, x
   dcp $a2
   dcp ( $de, x)
   jam
   brk
   dcp $fc
   sbc $26, x
   cmp $ebc9
   rol $6c, x
   and $fe63, y
   jmp ( $bcd5 )
   slo $61
   isc ( $69 ), y
   sbc $e96d
   adc ( $c5, x)
   rol $6c, x
   lax ( $a8 ), y
   sbc $ba, x
   ldx $6d80
   and #$a7
   isc $0d1c, x
   slo $5b
   sta $3732, x
   jam
   sre $ce66
   and $f7da, y
   sre $bb
   nop $7e, x
   sbc #$cd
   rra $7d
   cli
   cpy $d9
   cmp $0233, y
   arr #$2a
   txa
   lax $ace6, y
   rla ( $1f ), y

label_1b3f
   and $1f3d
   lax ( $de, x)
   bvs label_1b3f
   dcp $8f47, x
   rra ( $f5, x)

label_1b4d = * + 2
   asl $33ec, x
   cmp ( $8d, x)
   stx $5a79
   sta ( $54 ), y
   adc $c9ce, x
   isc ( $cd ), y
   cmp $34e7
   sha $172e, y
   sre $9c
   adc $de03, y
   sre $2c
   cpx $bf
   ldy $3792, x
   ora #$1e
   sbc $3159, y
   rla $de78, y
   isc $1f
   rra $556c
   jam
   nop $a1, x
   nop $79, x
   bvs label_1b4d
   adc $53
   sre $fc, x
   dcp $02, x
   adc $64
   cmp $97
   sha ( $f4 ), y
   rra ( $d6 ), y
   jmp $d17d
   sbc #$df
   nop
   and $73
   jam
   slo ( $cc ), y
   lda $9b, x
   sbc $ebf3, y
   nop $08, x
   tsx
   nop $2dc2, x
   ldy $ac40, x
   nop $bced, x
   jmp ( $2dbd )
   nop $a927, x
   and $fbbb, y
   txs
   jsr label_0e22
   isc $976e
   nop $dc24, x
   cmp #$f3
   lax $3a, y
   and $61, x
   isc $2d5a, x
   sax $5a

label_1bca = * + 2
   and $ff6d
   jam
   ldx #$56
   lsr $2816, x
   rra $0d, x
   cmp ( $bb, x)
   and $b3, x
   jam
   clv
   lda $ab27, y
   cmp #$58
   dcp ( $34 ), y
   las $fdf8, y
   rol $faae
   lax $d767, y
   sre ( $4b ), y
   dec $bcef, x
   alr #$c9

label_1bf0
   lda $d5
   cmp ( $3f, x)
   inc $8000, x
   rla $8885, y
   rla $57a3, x
   sbc $3fa8
   sre $b5
   lsr $7f35, x
   lsr $10, x
   and $62, x
   nop $d9
   adc ( $55 ), y
   sbc $4348, y
   dcp ( $a3, x)
   sta ( $3c ), y
   eor $e219, x
   bcs label_1bf0
   and $17

label_1c1b
   slo $05, x
   and ( $1b, x)
   sbc $b7
   sta $555f

label_1c24
   sty $91
   dcp $616d, x
   ror $12
   dcp $7b87
   bvc label_1bca
   dcp $d7ce, y
   ldy $f6, x
   sbc #$ed
   ldy $8f
   bpl label_1c1b
   beq label_1c58
   sre $5e0b
   jam
   nop #$ab
   tas $e602, y
   nop $ab, x
   dec $008c
   sbc #$9b
   shx $5f72, y
   sbc ( $c3 ), y
   cmp $4897, y
   rra $4d, x

label_1c58 = * + 1
   nop $c7, x
   lda $c6, x
   nop $5cd7, x
   dcp $08, x
   lda $aba3, x
   dey
   inx
   ora ( $c3, x)
   jam
   sax $d8
   nop
   bit $d734
   ora $c5
   cmp ( $35, x)
   cpy #$a6
   lax $6a, y
   sed
   ldx $ef, y
   ldy $7c4a
   cpx $b6
   bcs label_1c24
   rla $5d9a, y
   isc $35, x
   slo $a3b7, x
   rra $a181
   lax $47, y
   nop $78, x
   nop #$86
   sax $4f
   cmp ( $c2, x)
   nop
   inc $a8bb
   rla $ff
   dey
   slo $1e02
   jam
   sta $77, x
   lax $8fc5, y
   nop #$51
   slo $0c7f, x
   jam
   ldx #$74
   brk
   sre $f9f9, x
   isc $e4ef
   sax $fbf8
   sbc $e8e2, y
   brk
   tsx
   sbc $c1e5, y
   ldx $69be
   sbx #$ef
   cmp $b0e0
   cmp #$42
   lsr $de, x
   nop $3b
   nop $6cf2, x
   lax $4ac4
   jam
   nop $f5, x
   sta $d3be, x
   dcp ( $d2, x)
   lax $f7, y
   tax
   dcp $5eab, y
   dcp ( $a9 ), y
   isc ( $ee ), y
   arr #$d8
   sbc $183c, x
   lda $23e3, x
   cmp $758a, x
   ror $cf
   dcp $40, x
   txa
   lda #$7f
   nop $5e93, x
   lsr $a4c4
   bcc label_1d03
   lda $5a, x

label_1d03 = * + 2
   rla $e2a3, x
   sax $0ae0
   lda $55a6, x
   sbc #$38
   alr #$9d
   and $4e
   rol $e61c
   isc $65
   sre $f916, x
   cpx #$dd
   ora $de36, x
   ldy #$77
   sta $57eb
   cmp $74e0, x
   dcp $6e8e
   isc $835b
   lsr $c3e0
   sha $78f0, y
   asl $7008
   lax $af61
   sta $3efa, x
   ldx $3778, y
   cpx $0df6
   nop #$43
   tya
   sax $c5
   rra ( $ac, x)
   sbc $dc7a, x
   tay
   lax $b7, y
   tay
   dcp $b0, x
   sta $551e, x
   adc ( $4a ), y
   txa
   nop $55, x
   rra ( $47 ), y
   tax
   ror
   nop $cde5, x
   txs
   isc $4e
   lsr $94, x
   cpx $d4
   cmp $a9f1, y
   cmp #$c0
   php
   tay
   sha ( $97 ), y
   rla $7236, y
   ldx #$22
   dec $b923
   slo $8b, x
   lax $89bf, y
   asl $36, x
   ldx $4d
   brk
   nop #$2b
   sbc ( $1e ), y
   isc ( $f0, x)
   jsr $3a08
   lax $6f3b
   rol
   ldy $dc66, x
   bne label_1dbd
   adc $5985
   rra $e847, y
   jmp $b0f3
   txs
   and $db67, x
   adc ( $20, x)
   eor ( $37, x)
   slo $bc, x
   adc ( $81 ), y
   eor $e3, x
   adc #$e7
   nop $ab, x
   nop #$3b
   ldy $e7bc
   isc $0788, x
   anc #$4d
   tya
   cmp ( $3c ), y

label_1dbd = * + 2
   rla $35b8, x

label_1dc0 = * + 2
   sbc $b4d8, x
   sec
   adc $b7b2, y
   bit $d474
   inc $e6
   adc ( $9c, x)
   rla $7673, y
   lsr $b79a
   rla $83
   lda $97, x
   dcp $640f
   beq label_1dc0
   jmp ( $c7b0 )
   nop $fe68, x
   adc $9c
   rol $f17c, x
   lsr $8026
   lax ( $c4 ), y
   las $76fb, y
   ldx $dd7e
   nop
   ldx $13af, y
   inc $3e
   rol $6bed
   inc $92b9, x
   slo $4b3c
   ldx $2dc7, y
   ldx $b96c, y
   slo ( $ae, x)
   isc $2d9b
   anc #$a3
   inc $ff
   tsx
   nop $dc
   nop $71, x
   rra $9743
   rra $cc, x
   jam
   inc $b9f9
   rla $ad, x
   inx
   nop

label_1e22 = * + 1
   isc $64b6, x
   sty $4e
   sbx #$af
   nop $bb, x
   ora $acd2, x
   isc $28, x
   slo ( $ab, x)
   inc $db
   ror $e3, x
   jam
   lax $e5ea, y

label_1e3a = * + 1
   lxa #$e2
   tsx
   txs
   lax ( $a6, x)
   ldy $fa9b
   ora $6293, y
   rra ( $e7, x)
   lda ( $7b ), y
   sbc #$f0
   ror $1b4e, x
   rla $32, x
   cmp $6698, y
   bvs label_1e22
   inc $6e
   cmp #$d7
   dcp $ac33, y
   beq label_1e3a
   nop $b2, x
   sbc $f2b2, y
   isc $b061, y
   cmp #$7b
   isc $9c
   rla ( $fe ), y
   nop $6e, x
   lsr $beb8
   adc $2a73
   lda $92, x
   nop
   nop #$62
   dcp ( $e2 ), y
   sax $7bb0
   stx $4f, y
   lax ( $72, x)
   sbc #$92
   dey
   jam
   lda $a735, y
   sec
   jam
   nop
   sre $fccf, x
   iny
   nop $550e
   rla ( $a7 ), y
   and $c7a6, y
   tya
   dcp $cf7e
   tya
   dec $ba57, x
   isc ( $b5 ), y
   jam

label_1ea4 = * + 1
   ldx $e863, y
   nop $a7, x
   jam
   inc $66, x
   sta $fec2, y
   jmp ( $4d71 )
   slo ( $63, x)
   inc $0368, x
   sre $02e8, y
   jam
   slo $bf4b
   slo $f460, x
   nop $7dd8, x
   sty $40
   ora $9b, x
   lda $e03b, y
   dcp $3cf5, y
   sre $2611, x
   jam
   sre $e28c, x
   sed
   jam
   lax ( $67 ), y
   ane #$e2
   ldx #$a5
   ldx $912f, y
   isc $ff7f, x
   cmp $f2
   sbc $a6ef, x
   dcp $ff8a, y
   isc $6dd3, x
   rra $e937, x
   ldx $e2, y
   lax $f4ff, y
   dcp $bf5f, y
   nop $db, x
   alr #$b7
   nop
   ror $6f9b, x
   sax $2b, y
   sbc $cff7
   nop $bd, x
   rol $de, x
   sbc $ffa4, y
   inc $fa, x
   adc $7fab
   lda ( $e9, x)
   ldx $ef, y
   anc #$7d
   nop $ea, x
   ora ( $f3 ), y
   cpx $d6
   ora ( $f3 ), y
   nop $db, x
   nop $7f
   isc $6d7a
   lda $6ffa, x
   lax $46, y
   tas $8faf, y
   ldx $fb
   nop
   nop $377d, x
   dcp $e3d3, y
   sbc #$be
   dec $2f9f, x
   eor $f2f6
   sbc $6ffa, y
   lax $87, y
   dcp ( $d3, x)
   adc $b7bd, x
   sta $946f, x
   sbc $00fa, y
   ldx $9a9e, y
   adc $efa7, x
   rra $fe, x
   sbc $e6, x
   sbc $fd4d, y
   isc $ff, x
   sha $daa6, y
   lax $ff, y
   isc $6dd3, x
   isc $e9a1, x
   ldx $ad, y
   isc $f4ff, x
   dcp $b57f, y
   nop $db, x
   rla ( $7d, x)
   and $c036, x
   asl $afff
   dcp ( $6c ), y
   ora $03ff, x
   sbc #$b6
   nop $8d, x
   isc $a6ff, x
   nop
   rra $4bf7, x
   dcp $e1, x
   sax $bfe2
   sta $c7f0
   stx $82
   ldy #$ce
   lda #$db
   isc $7d73, y
   ldx $f99c, y
   nop
   rla $2b, x
   isc $dc, x
   lax ( $f6, x)
   dcp $50
   asl $386c
   isc $f4b0, x
   sha ( $ed ), y
   isc $05
   arr #$7e
   sed
   sre $27
   rra $2347, x
   lsr $8808, x
   tax
   and $e3c6, y
   eor $ae1f
   sbc ( $ed ), y
   and $9f27, y
   ora ( $04, x)
   eor $f9, x
   rol $b41b, x
   cpx $3cb8

label_1fd3
   nop #$2e
   ror $eb50
   sax ( $7e, x)
   sax $fd49
   sbc $fa, x
   cmp $d9ed, y
   rra $3db9, x
   sax ( $41, x)
   sha ( $a7 ), y
   lax ( $41, x)
   nop $f6, x
   pla
   bne label_1fd3
   cpy $1691
   sax $c3
   iny
   nop #$19
   isc $db, x
   cmp $f8a9, y
   and $863a, x
   ldx $9f9e, y
   shy $a137, x
   isc $c0, x
   sre $9d, x
   rra $e757, x
   slo ( $38, x)
   brk
   nop $74, x
   adc $6772, x
   sbc ( $91 ), y
   cpy $3afc
   ora $14, x
   dcp $c2
   rla $e6
   and $3f97, y
   lax $691d, y
   cpx $1118
   adc $f9
   adc $ee
   ora $1e7a, y
   ror $5f, x
   sha ( $40 ), y
   tya
   cpy $559a
   inc $16

label_203a
   ora $7a3f, x
   inc $62c6, x
   inc $395e, x
   txa

label_2044
   eor $1f
   isc $fd, x
   sha ( $14 ), y
   bit $1c
   sbc $bf56, x
   sty $6d
   sta $d547, x
   lax $b5

label_2056
   slo $145d, x
   cpx #$5b
   ldx $57f7
   sax $44
   rra $d5ee, x
   cmp $84cd, x
   sty $b9
   asl $54e9, x
   rra $ee51, y
   dcp $b332
   jam
   adc $36, x
   eor ( $27, x)

label_2076
   sta $bd47, y
   sax $b5, y

label_207b
   slo $d613, x
   rra ( $de, x)
   rra $bd, x
   eor $bd53, x
   and $ee35
   rla $d979
   rra $0134, x
   bne label_2044
   ora ( $e0, x)
   ldx $0628, y
   nop #$79
   inc $5b
   brk
   sax $5f
   bne label_209e

label_209e
   sre ( $01, x)
   jam
   rla $4c
   sax $4c2c
   sre $f32d
   nop
   ldy $cd70
   sta $13ba, x
   rla $c2
   sbc #$fe
   and $34, x
   lax $77cf
   jam
   bvs label_207b
   adc ( $7a ), y
   cpy $7863
   nop #$e2
   sei
   rra $b5, x
   inc $e9
   php
   lxa #$fa
   adc #$5d
   alr #$d9
   nop
   asl $4d
   rol $402f
   sbx #$93
   ldx #$8e
   bvs label_2076
   rra $bb40
   ane #$12
   isc $e3, x
   lsr $5efe
   ror $5ce8

label_20e9 = * + 1
   ldx $ee
   sta $ff
   nop $0bdd, x
   asl $42
   sta $cd37, x
   dex
   lax ( $79 ), y
   lda ( $91, x)
   jam
   nop
   isc ( $30 ), y
   asl $e4
   ror $1857, x
   cmp ( $ff ), y
   ldx $44b8
   sbc $7457, y
   sha $ff93, y
   tas $6271, y
   sha $9f17, y
   rra ( $3a ), y
   shy $d44d, x
   jam
   cmp $f9
   jsr $ec0a
   adc $da, x
   adc ( $7b, x)
   sax $d24e
   lda $bb64
   bvs label_20e9
   cld
   dcp $075c
   sbc $ebb9, x
   nop $01
   jam
   ora ( $2a, x)
   ora $d0
   dcp $ff, x
   ora $54
   sax $9a
   dey
   anc #$7d
   nop $3ebc, x
   lax ( $83 ), y
   cpx $2d3a
   eor $04
   tax
   slo $37a0
   anc #$50
   and $50, x
   sta $5901
   nop

label_2157
   nop #$2a
   sty $e8
   slo $ca
   nop $15, x
   nop $2b, x
   rti
   rol $56
   ldy #$ca
   lda ( $7a, x)
   brk
   adc #$9c
   lsr $f552
   slo $d7
   nop #$7d
   php
   nop $6c
   sbc #$a4
   ror
   sre ( $a6 ), y
   sta $1382, x
   nop
   asl $c9, x
   dcp ( $ea, x)
   lda $3e, x
   lda $6342
   rra ( $93, x)
   tax
   eor $944e, x
   lda $a1, x
   jam
   brk
   sbc $ebc9, x
   nop $a39e, x
   asl
   sbc $cd, x
   pla
   dcp $4f, x
   sax ( $c9, x)
   stx $b6, y
   rol $5b, x
   nop $f880, x
   sbc $8e, x
   ror $cb
   bvs label_2157
   rti

label_21ad
   tsx
   ldx #$00
   sre $4e
   rla ( $00, x)
   sbc $73
   nop $5712
   rla $01
   adc $42
   jam
   jam
   nop $2f, x
   slo $7225, x
   adc $8496
   asl $5c37
   inc $b171
   stx $f67a
   slo ( $cf, x)
   ror $fa26
   nop
   cmp #$b0
   nop $8dd8, x
   bne label_21ad
   adc $70, x

label_21df
   sax $ee
   bcc label_2261
   sbc #$b9
   stx $34
   ror $99cb
   eor $3c, x
   asl $0272
   lsr
   inc $ae4e
   cpx $ea
   inc $70d7
   isc $4ed1
   beq label_2274
   ane #$cb
   eor $813c, y
   nop
   sbc $8e, x
   cmp $9048, x
   sre $6440, y
   nop #$56
   rla ( $9f ), y
   ora ( $21 ), y
   jam
   ldy #$71
   sre ( $0d, x)
   and ( $55, x)
   nop
   cpx #$a1
   bcs label_21df
   adc $b879
   nop $80, x
   dec $eb
   cmp ( $c9 ), y
   nop #$01
   jsr $b281
   rla label_1b3f
   ldx #$ba
   sed
   tay
   lda $732d, y
   tay
   pla
   sei
   stx $04, y
   tax
   stx $03, y
   cli
   pla
   dcp $5eb0
   rla $a801, x
   nop #$65
   nop #$98
   rla $8b03, x
   and ( $c2 ), y
   sta $07
   txa
   nop $118f
   sty $16, x
   sta $9e1b, y
   jsr label_25a3
   tay
   rol
   lda $b42f

label_2261
   ora ( $a5 ), y
   lda $e1cd, y
   jam
   jsr $5a08
   sed
   nop $51b0, x
   sbc $8a73
   nop $80, x

label_2274 = * + 1
   adc $491f, x
   rla $0de7, x
   jsr $7714
   dcp ( $f7, x)
   nop #$80
   dcp ( $6c, x)
   asl $9374
   tya
   anc #$59
   ror $47, x
   jsr $9bc4
   sre ( $c1 ), y
   eor $f2a9
   cpy #$36
   pha
   ora #$81
   nop $c0, x
   nop #$95
   ror
   jmp ( $630c )
   eor $0b78, y
   lax $16
   lsr $87
   las $7e19, y
   ora ( $c8, x)
   adc ( $65, x)
   jam
   nop $84, x
   adc $2920, x
   dcp ( $a1 ), y
   cpx $08ae
   sbc #$67
   and $da88, y
   dcp $3d, x
   tsx
   inc $fe
   ror $5713, x
   sbc ( $fb ), y
   shx $00f2, y
   nop
   ror $af
   clc
   sta $ae
   sta $b0
   lda $4f
   bmi label_231a
   sty $53
   lsr $2da4

label_22dc = * + 1
   ane #$7f
   lsr $a9
   rra ( $5d, x)
   rla $5ffd, y
   rra ( $60, x)

label_22e7 = * + 1
   dcp $dd
   nop
   ror $03f8, x
   iny
   dcp $31, x
   isc ( $23 ), y
   adc ( $d1, x)
   sta ( $80 ), y
   ora ( $a1, x)
   cmp #$53
   isc $0096, x
   cpy $c8
   dey
   cmp $2d
   jam
   txa
   nop $50
   lsr $2c, x
   stx $78
   lsr $5873, x
   inx
   nop $b0
   clc
   and ( $44, x)
   tsx
   lsr $d1
   tsx
   nop $84, x

label_231a = * + 2
   slo $4a46, x
   cmp ( $de, x)
   nop $85
   nop
   inx
   adc ( $21 ), y

label_2323
   slo $20
   and ( $07, x)
   sax ( $68, x)
   nop $f192, x
   tas $0621, y
   cmp ( $c8, x)
   sty $1e
   rra $80
   sty $e8
   inx
   php
   eor $876e
   dcp ( $21, x)
   bpl label_22e7
   jam
   rol $ef
   jam
   rra $99, x
   anc #$b1
   beq label_22dc
   lda $dc, x
   jam
   ldy $51, x
   plp
   sax ( $43, x)
   lsr $b4, x
   inc $250b
   nop
   jam
   ora ( $24, x)
   brk
   jam
   nop $03
   bmi label_23aa
   txs
   nop $74, x
   isc ( $eb, x)
   sax $e140
   sta $2c08, x
   rol $40
   sbc $2c, x
   lsr $c8, x
   nop $e8
   adc $838b, x
   cli
   sax $41f8
   nop $09
   eor ( $b6, x)
   rol $a0
   ror
   eor ( $48, x)
   anc #$b3
   isc $450e
   adc $a0, x
   rti
   nop $ea, x
   sta $a7af, y
   jmp $07e8
   jsr $81b5
   nop $56, x
   sax $d3
   ora $1d
   jam
   and ( $d7 ), y
   nop $26e9, x
   bcc label_23dd
   jam
   slo $0f
   nop #$d7

label_23aa
   sre $1780
   sre $f780
   sre $e780
   sre $6780
   rla $3085
   and ( $29 ), y
   nop
   and $a1
   jam
   slo $60
   nop
   sbc ( $db, x)
   sre ( $af ), y
   nop
   shx $424c, y
   nop $ed
   cli
   slo $d4
   sbc $e831
   lda $0d82
   nop $b8, x
   bcc label_240f
   cpy #$71

label_23dd = * + 2
   dcp $7be5, y
   sty $2b59
   sbc $ba
   sbc ( $52 ), y
   sta ( $df, x)
   dcp $63, x
   nop
   isc ( $90, x)
   slo $b596, x
   pha
   dec $6b3e, x
   sre ( $c5, x)
   lsr $57c5, x
   eor $3075, x
   bvc label_242a
   bpl label_2436
   dec $50
   ora $dc, x
   shx $480d, y
   cmp $08c4, y
   adc #$e2
   nop #$b1
   sbx #$c5

label_240f
   eor $5e0e
   bit $02
   cmp ( $54 ), y
   brk
   sax $32, y
   stx $649e
   adc #$e6
   ora $3273
   beq label_2496
   bpl label_2433
   lsr $20
   jam

label_242a = * + 2
   jmp $5010
   eor $d4
   dcp $d1, x
   jam
   and ( $f3 ), y

label_2433 = * + 1
   nop $93

label_2436 = * + 2
   lda $1504, x
   and ( $54 ), y
   sre $5d0e, y
   jam
   nop $45, x
   slo $5d17
   sre $04a5
   ldx #$63
   nop $94, x
   nop $27
   cmp $ab04, x
   asl $bde9, x
   ora $17, x
   rti
   ldy $0b12
   sty $97fb
   lda ( $b3 ), y
   isc ( $d3, x)
   slo $3588, y
   nop
   sbc $9f
   adc $2175, x
   sbc $d5, x
   and $d4e5
   slo $d7, x
   bvc label_2475

label_2471 = * + 1
   nop $97
   ora ( $99 ), y

label_2475 = * + 1
   isc $8aa0, y
   ldx #$3a
   jam
   jam
   sbc ( $6e, x)
   cmp #$89
   and ( $16 ), y
   jam
   dec $3f50, x
   cld
   cmp label_08e8, x
   asl $fca7, x
   sec
   sha ( $1f ), y
   sha $ee83, y
   dey
   bvc label_24ac

label_2496 = * + 1
   sta ( $c5, x)
   jam
   slo $e0, x
   asl $98
   asl $70ef, x
   jam
   sre $3b

label_24a4 = * + 2
   sbc $361c, x
   nop $3440, x
   ror $cb, x

label_24ac = * + 2
   cpx $c280
   bit $7b81
   sta $2a10
   sty $00eb
   tax
   tya
   sbc ( $4b, x)
   asl $ff, x
   anc #$54
   anc #$35
   inx
   and ( $45 ), y
   jam
   rla ( $f4 ), y
   rol $c173
   inc $40, x
   anc #$5d
   slo ( $0c, x)
   ldx $79, y
   jam
   sbx #$69
   nop $ca05, x
   nop $07
   inc $29
   stx $6b
   eor ( $8b, x)
   isc $6fc5, y
   sre $27
   isc $2e27, x
   nop
   lda ( $c7 ), y
   nop
   ldx #$2a
   rti
   lsr $1c
   ror $6ee4
   isc $145a, x
   rla $fc, x
   jam
   slo $3b, x
   lsr $d235
   slo ( $fb, x)
   bvc label_24a4
   ldy $b68b, x
   sre $b11f
   nop $c7
   inc $2e0e, x
   ldy $ff, x
   sax ( $8b, x)
   ldx #$df
   tsx
   jmp ( $ff31 )
   asl $356c, x
   isc $2e42, x
   ane #$ff
   stx $42, y
   isc $2e0a, x
   sax $2e72
   dcp $3d
   rra $35
   ora $8098
   asl $8892
   nop $53e2, x
   tya
   eor $e9
   bit $22e4
   clv
   brk
   nop $01, x
   jam
   rti
   nop $b914, x
   jam
   lax $d2
   ora #$d8
   tax
   asl $0c
   cpx $00e4
   nop
   jam
   jam
   nop
   sbc ( $8c ), y
   ldy $a5, x
   shx $a98b, y
   nop $ee63
   nop #$15
   and #$44
   brk
   tay
   lax $03c8, y
   jam
   dey
   nop $b9, x
   clc
   eor ( $9b, x)
   clc
   dec $51
   jam
   adc $68
   slo ( $26 ), y
   rra $098c, y
   lda $f2, x
   sbc $243e
   inc $4f, x
   bcc label_258d
   lda #$cd
   nop $80, x
   ldx $48e2, y
   bit $62
   lsr $b60b, x

label_258d = * + 1
   ldx $9d, y
   ldx $9f4f
   asl
   sbc $f4
   asl $8a
   nop $15, x
   lax $41
   rla ( $9d, x)
   and $ca2b, x
   ror $ce2b, x
   rti

label_25a3
   adc ( $15, x)
   jsr $9806
   nop $fd, x
   dec $e6, x
   rra ( $00 ), y
   isc ( $2e ), y
   sre $a899, x
   slo ( $c6, x)
   ldx #$d4
   rra $25
   sre $cbea, x
   eor ( $96, x)
   ldy $17, x
   ldx $1a63, y
   stx $b131
   sax ( $31, x)
   dey
   and ( $22, x)
   jam
   lax ( $f1, x)
   and $b8c0, y
   isc $a0
   brk
   nop
   rla $fb, x
   lda ( $d6, x)
   rol $7143
   slo $e4cc, x
   ora ( $e3, x)
   sha ( $58 ), y
   rla $2095
   ldy $00, x
   sta $8831, y
   nop
   sbc $70, x
   jam
   eor #$80
   bmi label_25f6
   nop #$db

label_25f6 = * + 1
   and $b5, x
   sha ( $01 ), y
   cmp $7b42
   lsr $f2
   jam
   sax ( $7a, x)
   nop
   bvc label_260a
   bpl label_2638
   cpx $89
   sty $57, x

label_260a
   slo $0f36, y
   sty $00, x
   adc $54d9, y
   and ( $9e, x)
   cmp $0f, x
   sha $b516, y
   eor #$41
   asl $bd
   ldx #$bb
   ror $40aa, x
   and ( $7a ), y
   sbc $a422
   ora ( $96 ), y
   jam
   lda #$a2
   nop #$37
   ldy $2eae
   eor ( $7f, x)
   stx $d7
   ldy #$28
   jam

label_2638
   jam
   cmp $904a
   inc $eb6e
   rol $bf
   alr #$2f
   sre ( $17 ), y
   dcp $51
   jmp ( $955e )
   ora $88, x
   lsr
   sta $f780, y
   rol $1a20
   jam
   dec $c0da
   jmp $e4ef
   rla $4c, x
   lda $fc7b
   stx $0f, y
   sha ( $28 ), y
   anc #$5a
   ora ( $95, x)
   tax
   asl $b8b9
   ora ( $1b ), y
   sha $915d, y
   rla $b299, x
   slo $a5
   brk
   txa
   sta $da77, x
   cmp $d004, x
   sre ( $d3 ), y
   isc ( $72, x)
   sta ( $3d, x)
   jam
   sty $eb
   ora #$6e
   lda ( $54 ), y
   eor ( $a5, x)
   asl $e4, x
   stx $0a
   eor ( $ca, x)
   sax $39
   adc ( $39 ), y
   bmi label_26a1
   ldx #$db
   nop #$f9
   sax $4f, y
   nop $35ed

label_26a1
   nop $00, x
   nop #$95
   eor $d5b2, y
   eor $a3be, x
   cli
   rla $6f83
   sbc #$94
   dcp ( $13, x)
   eor $8e71, y
   sre ( $b5 ), y
   jsr label_0c11
   adc $3386, x
   jam
   sta $700e, y
   rol
   sax $2e, y
   rol
   anc #$f7
   sbc #$02
   clv
   sbc $a0, x
   lda $b0fb
   isc $5f60, y
   nop $40ec, x
   jam
   ldx $fb67
   sta $199e, x
   and #$89
   asl $e5dc
   adc $5d
   ldx $32
   isc $a601
   jam
   lda $fbf0
   rra ( $ef, x)
   and $af, x
   sty $e3
   nop $29
   slo $09
   clc
   rra $2e
   nop $0ead, x
   tsx
   sha $3b66, y
   bit $db3e
   sbx #$51
   ldy $d9ac, x
   dex
   sbc ( $9c, x)
   sax $93b3
   rla ( $43 ), y
   sbc ( $4c, x)
   ora $5d, x
   sty $8462
   and ( $e3 ), y
   nop $8fc7, x
   txs
   sei
   lda ( $ec ), y
   eor $5cc8, y
   lax $01
   asl
   sta ( $02 ), y
   cpy #$0d
   cmp $5600
   jam
   sta ( $4f ), y
   bit $be
   sbc #$b8
   sre ( $04 ), y
   ror $65f4
   pha
   bit $6e
   nop $c264, x
   nop
   sta ( $98 ), y

label_2744 = * + 1
   nop $b3
   sta $bb32, y
   rra ( $d3 ), y
   sax $cc1a
   sbc $a8b9, x
   bit $91
   las $2be7, y
   dex
   dcp $0ab0, y
   sbc #$c0
   nop $5087
   pha
   inc $5a92
   rla ( $73, x)
   dec $3b
   nop $9c74, x
   sta $1b3a, y
   adc $ade7
   iny
   tya
   jsr $5b14
   ora ( $bc ), y
   ora ( $91 ), y
   nop $ec29, x
   bvc label_2744
   lax $12, y
   rra $c671, y
   lsr $a7, x
   sta $72
   sei
   sec
   ldx $41
   lda $89, x
   tsx
   eor ( $e8, x)
   lax $e6
   slo $53eb, x
   sta $0b, x
   nop $c3ba, x
   asl $be0e, x
   cpx $d6
   inc $8e4e
   inc $2e
   eor #$f3
   sre ( $ef ), y
   sre ( $19, x)
   jmp $4414
   sbc $21, x
   dcp ( $b2 ), y
   slo $b733, y
   ora #$fb
   cpy #$9f
   lda ( $1b, x)
   sre ( $a6 ), y
   ora #$fa
   lda ( $80, x)
   sbc $0f80, x
   nop
   nop #$fd
   bne label_27d6
   dcp $fd80, x
   ora ( $06 ), y
   nop $40ea, x
   ror $07b8, x
   cpx $7ec0

label_27d6 = * + 1
   cpx #$6d
   nop $89, x
   ora $168d
   rol $c3d3, x
   plp
   sre ( $11, x)
   jmp $a315
   nop
   asl
   pha
   lda #$0b
   rra $363c
   isc ( $25 ), y
   lda #$e7
   eor #$1a
   jam
   inx
   lsr $62, x
   jam
   asl $f5, x
   asl $61
   rra $1488
   sta ( $03, x)
   sre ( $9e ), y
   dcp $69
   sha ( $a7 ), y
   ror $97c3
   adc $1005
   dcp ( $9c ), y
   sre ( $51, x)
   nop $27
   nop $f335, x
   sre $0a04, x
   isc $e281
   nop $a7, x
   lsr $2001, x
   eor ( $b9 ), y
   jam
   sbc ( $53 ), y
   ora $6cde, x
   rla $e6dd
   nop #$5f
   isc ( $99, x)
   ldx $9fb0, y
   tax
   lsr $f738, x
   lda #$d3
   cmp $d206, y
   rra $9042, y
   adc $ab
   isc $c28b, y
   rla $c90b
   asl
   jsr label_0b5f
   cpy #$8a
   jsr $2f2e
   php
   and ( $5f, x)
   sed
   nop $a0, x
   isc $fc37
   dcp $70, x
   slo ( $88, x)
   dec $86, x
   ldx $0c08, y
   sre $38da, x
   lda $a560
   las $a548, y

label_286b
   ldy $a248, x
   nop $d2
   isc $44, x
   brk
   nop #$96
   tax
   rti
   rra $53
   inc $f3
   stx $e702
   ldx $01, y
   rol $41ee
   ldy #$51
   stx $f3
   nop
   ora ( $96, x)
   nop $bb, x
   eor ( $31, x)
   dey
   bit $6e
   isc $93, x
   tya
   cpy #$75
   sbc ( $38 ), y
   pha
   clc
   sbc ( $2e, x)
   ror $39
   adc $20, x
   php
   anc #$22
   lsr
   eor $ff, x
   cmp $e1
   eor #$fe
   jam
   lsr
   bit $00
   jam
   txs
   eor ( $27, x)
   rra ( $7e ), y
   ldy $5e
   rra $33, x
   adc $94, x
   and ( $3c, x)
   cmp ( $9a ), y
   and $76fb, y
   cpy #$0a
   clc
   rol $34
   jam
   rla $ffd7
   sax $b0
   ora ( $42, x)
   sax ( $c5, x)
   asl $a2
   nop $1006, x
   nop
   bit $a1
   adc ( $c0 ), y
   bpl label_293c
   lda ( $88, x)
   asl
   nop #$19
   jam
   nop $3026, x
   slo $ae
   sax ( $cf, x)
   ora ( $eb ), y
   cpy #$c3
   dcp $0a
   sax $f8, y
   cmp ( $26 ), y
   inc $ee27
   sbc $7d6a
   rla $ee
   nop
   clv
   plp
   nop #$27
   rti
   nop $30, x
   slo $21bb, x
   isc $1fb4, y
   las $5a79, y
   asl $142c, x
   nop $c2
   nop $e88d
   asl $f37c
   lsr $5f73, x
   slo $ea01, x
   cmp ( $1b, x)
   ora ( $02, x)
   and $88
   lda $32
   dec $1323, x
   slo $d057, x
   lax $cc, y
   dcp ( $0f, x)
   nop #$74
   sre $80
   rla $eba6, y
   sax $ce
   and $e6, x
   and $f2, x

label_293c
   sre ( $76 ), y
   lxa #$83
   jam
   txs
   rra ( $38, x)
   plp
   nop #$b9
   sre $21b5, y
   isc $18, x
   bvc label_29a3
   sbc $d91e
   clc
   ora $b211, x
   cpy #$58
   rla ( $a0, x)
   and ( $f7, x)
   sre $d9
   sax $db
   ora $3a
   inx
   eor #$42
   rol $a5
   alr #$6d
   nop #$70
   ora ( $b7 ), y
   bcs label_29c3
   ldy $c0, x
   nop
   ora ( $55, x)
   rol $11
   tax
   lsr $82
   lda #$fc
   jam
   rra $2c
   ora $8348
   lsr $11c4, x
   lax $70
   lsr $a33a
   lax ( $aa ), y
   sbc #$0e
   sty $69
   jam
   ror $a791, x
   sbc #$26
   sta $10
   cmp $ea
   sax $a2, y
   jam
   ror
   sbc $4e, x
   sbc ( $2c ), y
   dcp ( $21, x)
   nop

label_29a3
   jam
   nop $9f, x
   sty $449b
   ldx $80, y
   nop
   bit $af
   rol
   clv
   rla $3c1b, x
   jam
   nop $ba, x
   rol $35
   lsr $0a
   nop $9b, x
   rol $2094, x
   tay
   and $5c, x

label_29c3 = * + 1
   jsr $610b
   and $ef60
   tya
   and $a1
   anc #$6f
   ora $0004, y
   clc
   ora $3dd4, x
   sre $ed
   and $4e, x
   sta $4a, x
   isc ( $47, x)
   ldy $42
   eor #$88
   sre ( $b1, x)
   rol $b4, x
   ora ( $b3, x)
   sha ( $d9 ), y
   eor #$94
   cmp #$ce
   anc #$20
   nop $c7, x
   lda ( $c7 ), y
   eor #$46
   lsr $8045
   nop
   jam
   sha ( $fe ), y
   ldx #$e5
   lax $ab
   sax $27, y
   lax $07
   sty $9200
   asl $9e
   adc $d258, x
   bcs label_2a56
   bne label_2a15
   slo $f3
   lax $0013

label_2a15 = * + 1
   eor ( $98, x)
   jmp $9a4f
   jam
   cld
   rol $67
   jmp label_1ea4
   and $3e, x
   ora $c0, x
   ora #$cd
   sbc ( $d1 ), y
   slo ( $64, x)
   rla $27, x
   sha $910a, y
   cld
   lda $8a1d
   cmp ( $d8 ), y
   lda $8a1d
   nop
   iny
   nop $7e8e, x
   eor $c84f
   sbc $e3

label_2a42
   lax ( $8e, x)
   bmi label_2a85
   cpy $e3
   isc ( $9b, x)
   stx $3e10
   clv
   sre ( $bc, x)
   sec
   rti
   pla
   nop #$fd
   clv

label_2a56
   rra ( $7c, x)
   lda ( $03 ), y
   tsx
   isc ( $06, x)
   beq label_2a42
   slo ( $a2, x)
   asl $38fb
   isc ( $a3 ), y
   sec
   inc $98ea, x
   dcp $63a1, x
   inc $e9
   sed
   eor #$76
   slo $0ae5
   nop $ff10, x
   adc ( $17, x)
   sbc $11, x
   isc $92c6, x
   rra $32be, x
   sbc #$37

label_2a85 = * + 1
   ldy $efc8
   iny
   sre $fc8e
   sbc $18
   isc $53d4
   sbc $af26, x
   sbc ( $03 ), y
   cpy $fb57
   rla ( $bd ), y
   lda $5cf1, y
   slo $ee
   isc $f7
   adc $83, x
   ldx $3882, y
   dcp $629d, x
   asl $e8
   sax $ee
   sbc $03
   nop $5eae, x
   cmp $f34f
   slo ( $68, x)
   isc $36ce
   isc $ef5d, y
   lda $c3a8, x
   sha $6480, y
   slo $5af0, y
   jmp ( $ff37 )
   jam
   slo $fd, x
   inc $83, x
   nop $57e8, x
   sbc $05, x
   isc $6740, x
   isc $4fe3, y
   sbc $e306
   rra $6e20, x
   rla $87f3, y

label_2ae2
   rra ( $bf, x)
   sec
   ror $fb3b, x
   sed
   asl $0fff
   ldy $f0
   slo $8bc7, x
   bvc label_2ae2
   adc $fdd6, y
   sec
   rra $fe06, x
   nop $be6a, x
   stx $64, y
   plp
   cmp ( $96 ), y
   bit $82
   ldy $14, x
   nop $2c24, x
   bit $3c34
   jam
   jam
   nop $04
   asl $00
   rra $d887, x
   rra $0f8e, y
   sre ( $c8 ), y
   nop
   nop $c463, x
   slo ( $d1, x)
   ora $1355, x
   nop $c9
   ora $1357, x
   shy $ba1f, x
   slo $e964, x
   lax $61
   isc ( $9c, x)
   ora $1dda, x
   sty $3b03
   ldy $4562
   lda ( $52 ), y
   brk
   sha ( $ac ), y

label_2b41 = * + 1
   bit $91
   clc
   dcp $9658, y
   sha ( $78 ), y
   dcp $94a8, y
   ldy $dc
   isc $6d, x
   lax ( $89 ), y
   sta $decf
   adc ( $65 ), y
   clc
   ldy #$00
   adc ( $b3 ), y
   jam
   nop $2e
   nop $7d52, x
   eor $0c, x
   jam
   cmp $adb3, y
   sta $9c, x
   nop #$17
   and $a5, x
   rol $b81a
   and $90, x
   bcc label_2ba5
   bmi label_2b41
   rra $e5
   nop #$d0
   cmp ( $0d, x)
   ldy $30
   ldx #$6c
   nop
   jmp ( $2f37 )
   sax $6f
   dcp $2e, x
   inc $0508, x
   sre ( $61 ), y
   lda $51, x
   sbc $5118
   asl $460b
   nop #$0b
   asl $34
   sta $3c1c, x
   cmp ( $dd, x)
   ldy $66d2, x
   asl $d6, x
   nop

label_2ba5 = * + 1
   cmp $9925, y
   dec $9ab3, x
   dcp $8b41
   nop $f7
   jam
   sed
   sec
   sbc $b6
   bne label_2bbf
   cpx $b5
   beq label_2bbe
   eor $4f, x
   sed

label_2bbf = * + 2

label_2bbe = * + 1
   jmp label_286b
   ror $d5a4, x
   isc ( $26 ), y
   brk
   and $26, x
   rla ( $b1 ), y
   ldy #$24
   rol $18
   nop #$99
   bvs label_2ba5
   slo ( $a1, x)
   nop $5800, x
   iny
   dey
   arr #$37
   cpy #$15
   sax $35c0
   bmi label_2c09
   nop
   rra ( $38, x)
   nop #$2c
   dec $2cdf, x
   nop
   dec $f3c6
   lsr $e849, x
   dec $d5
   dcp $8845, y
   jam
   ldy $86
   sbc $60, x
   nop $a2

label_2bff = * + 2
   ora $aa28
   jmp ( $010f )

label_2c04 = * + 1
   rol $f2, x
   cmp $70c8, x

label_2c09 = * + 1
   isc $f4d0, y
   rra $e62a
   jam
   dec $a6, x
   lax $08f0, y
   bvs label_2c04
   sre $854f
   rol $29
   tsx
   rol
   asl $fe, x
   slo $8100, y
   sre $7911
   nop $434b
   sre $2931, x
   anc #$7a
   cmp $c1
   ora ( $24, x)
   adc $2d
   lda $b135
   rol $18
   nop #$37
   and #$7a
   and $b023
   cli
   dec $a098, x
   php
   ldx $bc
   beq label_2c65
   sta $c2

label_2c4b = * + 1
   bvc label_2c82
   nop $8280
   nop #$5c
   rla ( $69, x)
   rra $7019
   sax ( $ca, x)
   and #$9b
   ora #$a9
   tas $2306, y
   sre ( $ac, x)
   nop $5830, x
   php

label_2c65
   sbc $12
   slo $ae1c, y
   ora $adfe, x
   rra $b4, x
   cpy $14
   jmp $ebd7
   ora $ec2d, x
   slo $78, x
   ora $5476
   shy $6ef7, x
   nop $eeed, x

label_2c82
   bvs label_2c4b
   sre $fc09, y
   brk
   jam
   ora ( $a3, x)
   asl
   cmp #$d7
   isc $0e48, y
   sei
   adc ( $f4 ), y
   ora ( $c7, x)
   rra $66, x
   sre $01, x
   rti
   sec
   ora $69, x
   nop #$7b
   jam
   dec $c374, x
   ror $98, x
   sbc $d715
   and $26, x
   rra ( $03 ), y
   sbc #$1b
   lda $6c82, x
   sbc $3326, y
   dcp $9e8f, x
   nop $6c, x
   brk

label_2cbb
   pha
   cpx $e482
   rol $b0, x
   jam
   dec $ccbc
   isc $63

label_2cc7
   ror $8e
   ror $1f, x
   cpx $a8
   sbc $7c3a, y
   dex
   dec $f5b1, x
   sta ( $c7 ), y
   slo ( $00, x)
   cmp $6d
   lda $6db3, y
   cmp ( $b4, x)

label_2ce1 = * + 2
   ror $b67e
   nop $d6e7, x
   ror $ddb6, x
   rra $d6
   ror $d4f5, x
   jam
   sre $9f1b
   adc $b9, x
   bne label_2cc7
   lax ( $c7 ), y
   ora $736e, x
   nop $a0, x
   sbc ( $c2 ), y
   jam
   isc $5b55, x
   shy $262d, x
   nop $306e, x
   adc ( $c3 ), y
   ora $d99c, x
   slo ( $c7 ), y
   sre $355e
   nop #$5a
   bvc label_2cbb
   ldx #$52
   rts
   jmp ( $3664 )
   rla ( $06, x)
   nop #$64
   asl
   asl $858b, x
   cmp ( $86, x)
   nop #$27
   lxa #$24
   sax $60, y
   dcp ( $c0 ), y
   nop #$c4
   iny
   cld
   cpy $88
   jmp $9033
   dec $93
   ora $44a2
   ldx #$c0
   nop $17
   dec $04
   sei
   lda $9fbd
   nop $8dad, x
   ora #$9a
   adc $89
   tya
   sre $8663
   dcp $66, x
   jam
   slo $1a6d, y
   lax $c453
   eor $5e02, y
   jam
   cmp $5ed3, x
   bmi label_2d82
   anc #$6d
   rti
   and ( $4d, x)
   sta $e0
   rol $760d, x
   eor $5478
   eor $556d
   ane #$83
   alr #$6d
   sbx #$85
   jsr $9d10
   ora ( $5c ), y
   clv
   and $5c, x

label_2d82 = * + 1
   dcp $71, x
   eor ( $1a ), y
   nop $b690, x
   tax
   ldy #$b0
   sbc ( $95, x)
   nop #$24
   adc ( $4a ), y
   rti
   jam
   nop
   rra ( $aa, x)
   nop
   isc $aea3, y
   nop
   lda ( $a4 ), y
   slo ( $60 ), y
   lax $ff
!byte $E0
