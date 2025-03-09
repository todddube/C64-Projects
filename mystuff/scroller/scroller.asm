// Basic upstart
.pc = $0801 "Basic Upstart"
:BasicUpstart($0c00)

.pc = $0c00 "Main Program"

start:
    sei         // Disable interrupts
    lda #$7f    // Disable CIA interrupts
    sta $dc0d
    sta $dd0d

    lda #$35    // Bank out BASIC and KERNAL ROM
    sta $01

    lda #$1b    // Set screen control register
    sta $d011   // Enable screen, 25 rows
    lda #$08    // Set scroll position to 0
    sta $d016

init_screen:
    ldx #$00
    lda #$20    // Space character
clear:          // Clear screen
    sta $0400,x
    sta $0500,x
    sta $0600,x
    sta $06e8,x
    dex
    bne clear

main_loop:
    lda scroll_counter
    sec
    sbc #$01    // Decrease scroll counter
    and #$07    // Keep within 0-7
    sta scroll_counter
    sta $d016   // Update horizontal scroll register

    bne skip_char   // If not zero, skip character shift

    // Shift characters left
    ldx #$00
shift_loop:
    lda $0401,x     // Get char from next position
    sta $0400,x     // Store in current position
    inx
    cpx #39         // Do for first 39 chars
    bne shift_loop

    // Get new character
    ldx text_pos
    lda scroll_text,x
    bne not_end
    ldx #$00        // Reset to start if end reached
    stx text_pos
    lda scroll_text // Get first char again
not_end:
    sta $0400+39    // Put new char in last position
    inc text_pos

skip_char:
    // Simple raster wait
    lda #$ff
wait_raster:
    cmp $d012
    bne wait_raster
    jmp main_loop

scroll_counter: .byte $07
text_pos:      .byte $00
scroll_text:   .text "HELLO, THIS IS A SMOOTH SCROLLING TEXT DEMO FOR THE COMMODORE 64!   "
               .byte $00
