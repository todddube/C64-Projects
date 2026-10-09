//==============================================================================
// FILE:        scroller_intro.asm
// PROJECT:     STARDUST - imported by scroller.asm, not buildable on its own
// DESCRIPTION: The start-up wipe. Black, a raster wipe down to solid blue,
//              a pause, then a wipe back up to black, and the demo starts.
//==============================================================================
//
// It runs from start with interrupts off and the display off (DEN = 0), so
// the whole screen is border color and there are no badlines: every change
// is one polled $d020 write. Each lands at cycle ~6-13 of its line, the same
// trick irq_bars uses for $d021.
//
// A frame of the wipe, counted in lines from INTRO_TOP (line 16: vertical
// blank on NTSC, the first visible line on PAL):
//   0 .. pos+2     blue
//   pos+3 ..       a 9-line glow edge: light blue, white, light blue
//   pos+12 ..      black, up to the next frame's line 16
// Going down, pos climbs from 0 to the frame's line count; going back up,
// it falls again. Lines are counted mod in_lines, measured by detect_video,
// so the wipe crosses line 0 on NTSC (lines 0-12 are the bottom border
// there) and works on 262- and 263-line NTSC chips and on PAL.
//
// RUN/STOP works throughout (check_exit once a frame).
//==============================================================================

.const INTRO_TOP     = 16               // frame starts here (offset 0)
.const INTRO_SPEED   = 3                // lines per frame (~1.5 s a sweep)
.const INTRO_BLACK   = 30               // frames of black before and after
.const INTRO_HOLD    = 100              // frames of solid blue (~2.5 s)

//------------------------------------------------------------------------------
// intro: the whole sequence. Needs detect_video (raster_max) first.
//------------------------------------------------------------------------------
intro:
    lda raster_max              // lines = highest line + 1
    clc
    adc #$01
    sta in_lines
    lda #$01                    // ($106 -> 263 on NTSC, $137 -> 312 on PAL)
    sta in_lines + 1
    sec                         // last edge offset that still fits a frame
    lda in_lines
    sbc #$04
    sta in_last
    lda in_lines + 1
    sbc #$00
    sta in_last + 1

    lda #COLOR_BLACK
    ldx #INTRO_BLACK
    jsr intro_hold

    lda #$00                    // wipe down to blue
    sta in_pos
    sta in_pos + 1
in_down:
    jsr intro_frame
    clc
    lda in_pos
    adc #INTRO_SPEED
    sta in_pos
    bcc !+
    inc in_pos + 1
!:  lda in_pos
    cmp in_lines
    lda in_pos + 1
    sbc in_lines + 1
    bcc in_down

    lda #COLOR_BLUE
    ldx #INTRO_HOLD
    jsr intro_hold

    lda in_lines                // wipe back up to black
    sta in_pos
    lda in_lines + 1
    sta in_pos + 1
in_up:
    sec
    lda in_pos
    sbc #INTRO_SPEED
    sta in_pos
    lda in_pos + 1
    sbc #$00
    sta in_pos + 1
    bcc in_done
    jsr intro_frame
    jmp in_up
in_done:
    lda #COLOR_BLACK
    ldx #INTRO_BLACK
    jmp intro_hold

//------------------------------------------------------------------------------
// intro_hold: A = border color, X = frames to hold it
//------------------------------------------------------------------------------
intro_hold:
    sta in_col
    stx in_cnt
!:  lda #$00
    sta in_off
    sta in_off + 1
    jsr border_at
    jsr check_exit
    dec in_cnt
    bne !-
    rts

//------------------------------------------------------------------------------
// intro_frame: one frame of the wipe with its edge at in_pos.
// Edge lines that would run into the next frame are skipped, so at either
// end of a sweep the screen is solid blue.
//------------------------------------------------------------------------------
intro_frame:
    lda #$00
    sta in_off
    sta in_off + 1
    lda #COLOR_BLUE
    sta in_col
    jsr border_at

    ldy #$00
if_edge:
    sty in_i
    clc                         // in_off = in_pos + edge_off[i]
    lda in_pos
    adc edge_off, y
    sta in_off
    lda in_pos + 1
    adc #$00
    sta in_off + 1
    lda in_last                 // past in_last: next frame, stop here
    cmp in_off
    lda in_last + 1
    sbc in_off + 1
    bcc if_done
    lda edge_col, y
    sta in_col
    jsr border_at
    ldy in_i
    iny
    cpy #edge_col_end - edge_col
    bne if_edge
if_done:
    jmp check_exit

// 3 lines apart: from one write to border_at's first poll is ~130 cycles, so
// it starts polling early in the line before its target, with only about
// half a line to spare. Don't add work to if_edge without widening these.
edge_off:
    .byte 3, 6, 9, 12
edge_col:
    .byte COLOR_LIGHT_BLUE, COLOR_WHITE, COLOR_LIGHT_BLUE, COLOR_BLACK
edge_col_end:

//------------------------------------------------------------------------------
// border_at: $d020 = in_col at the start of line INTRO_TOP + in_off
// (mod in_lines). in_off must be ahead of the beam, and 0 means next frame.
//
// Polls the line before the target with all 9 bits, then the target's low
// byte in a 7-cycle loop, so the write is early in the line.
//------------------------------------------------------------------------------
border_at:
    clc                         // YX = prev = INTRO_TOP + in_off - 1
    lda in_off
    adc #INTRO_TOP - 1
    tax
    lda in_off + 1
    adc #$00
    tay
    sec                         // wrap it into the frame
    txa
    sbc in_lines
    sta tmp
    tya
    sbc in_lines + 1
    bcc !+
    tay
    ldx tmp
!:  stx in_plo
    tya                         // bit 8 -> bit 7, as $d011 shows it
    lsr
    ror
    sta in_phi
    inx                         // low byte of the target line
    cpx in_lines
    bne !+
    cpy in_lines + 1
    bne !+
    ldx #$00                    // prev was the last line: target is 0
!:  stx in_alo

ba_wait:
    lda VIC_RASTER
    cmp in_plo
    bne ba_wait
    lda VIC_CTRL1
    and #$80
    cmp in_phi
    bne ba_wait
    ldy in_col
    lda in_alo
!:  cmp VIC_RASTER
    bne !-
    sty VIC_BORDER
    rts
