    * = $0801
    .word start
    .word 2019
    .byte $9e
    .text "2061"
    .byte 0

start:
    lda #$00
    sta $d020
    sta $d021

    ldx #$00
clear_screen:
    lda #$20
    sta $0400,x
    sta $0500,x
    sta $0600,x
    sta $0700,x
    inx
    bne clear_screen

    ldx #$00
load_text:
    lda message,x
    sta $0400,x
    inx
    cpx #message_end-message
    bne load_text

scroll:
    jsr $e544
    lda $d012
    cmp #$ff
    bne scroll

    ldx #$00
scroll_text:
    lda $0401,x
    sta $0400,x
    lda $0501,x
    sta $0500,x
    lda $0601,x
    sta $0600,x
    lda $0701,x
    sta $0700,x
    inx
    cpx #$27
    bne scroll_text

    lda #$20
    sta $0427
    sta $0527
    sta $0627
    sta $0727

    jmp scroll

message:
    .text "HELLO WORLD! THIS IS A SCROLLING TEXT DEMO ON THE C64. "
message_end: