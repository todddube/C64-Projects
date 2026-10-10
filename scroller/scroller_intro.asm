//==============================================================================
// FILE:        scroller_intro.asm
// PROJECT:     STARDUST - imported by scroller.asm, not buildable on its own
// DESCRIPTION: The start-up wipe. Black, a raster wipe down to solid blue,
//              a pause, then a wipe back up to black, and the demo starts.
//==============================================================================
//
// The border stays black. The wipe is drawn in the background color ($d021)
// over a screen of BLANK chars, so it shows only inside the display window
// (lines 51-250). It runs from start with interrupts off and no sprites;
// every change is one polled $d021 write that lands at cycle 6-12 of its
// line, before a badline stops the CPU (the irq_bars trick).
//
// A frame of the wipe, counted in lines from INTRO_TOP (line 16):
//   0 .. pos+4     blue
//   pos+5 ..       a 12-line glow edge: light blue, white, light blue
//   pos+17 ..      black, up to the next frame's line 16
// Going down, pos climbs from WIPE_FROM (edge just above the window) to
// WIPE_TO (window all blue); going back up, it falls again. Lines are
// counted mod in_lines, measured by detect_video, so a late stripe that
// crosses line 0 on NTSC is still placed correctly.
//
// SOUND. Two detuned sawtooths (voices 1 and 2) swell in on the black
// screen at the start, then rise in pitch with the first wipe and fade out
// over the blue pause. The second wipe gets a different sound: noise on
// voice 3 through a resonant low-pass filter whose cutoff falls with the
// edge, a whoosh that closes as the screen goes black. The SID is cleared
// before music.init. intro_sfx follows the edge once a frame.
//
// RUN/STOP works throughout (check_exit once a frame).
//==============================================================================

.const INTRO_TOP     = 16               // frame starts here (offset 0)
.const INTRO_SPEED   = 3                // lines per frame (~1.2 s a sweep)
.const WIPE_FROM     = 51 - INTRO_TOP - 18   // black from line 50 down
.const WIPE_TO       = 251 - INTRO_TOP - 5   // blue down to line 250
.const INTRO_BLACK   = 30               // frames of black before and after
.const INTRO_HOLD    = 100              // frames of solid blue (~1.7 s)

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

    lda #BLANK                  // an empty screen: all background color
    ldx #$00
!:  sta SCREEN_RAM, x
    sta SCREEN_RAM + $100, x
    sta SCREEN_RAM + $200, x
    sta SCREEN_RAM + $2e8, x
    inx
    bne !-
    lda #COLOR_BLACK
    sta VIC_BORDER
    sta VIC_BACKGROUND
    lda #D018_MAIN              // BLANK is empty in the main charset
    sta VIC_MEMSETUP
    lda #$00                    // 38 columns: the right border hides the
    sta VIC_CTRL2               // last 7 pixels of the line before each write
    lda #$1b                    // display on, 25 rows
    sta VIC_CTRL1

    jsr sid_clear               // the rising saws swell in on black
    lda #$0f
    sta SID_VOLUME
    lda #$a0                    // attack 500 ms
    sta SID_V1_AD
    sta SID_V2_AD
    lda #$f9                    // full sustain, release 750 ms
    sta SID_V1_SR
    sta SID_V2_SR
    lda #$80                    // voice 2 detuned: the two saws beat
    sta SID_V2_FREQ_LO
    lda #$00
    sta in_dir
    sta in_pos + 1              // in_pos stays under 256
    lda #WIPE_FROM
    sta in_pos
    jsr intro_sfx               // pitch for the first frame
    lda #$21                    // sawtooth, gate on
    sta SID_V1_CTRL
    sta SID_V2_CTRL

    lda #COLOR_BLACK
    ldx #INTRO_BLACK
    jsr intro_hold

in_down:                        // wipe down to blue
    jsr intro_frame
    lda in_pos
    clc
    adc #INTRO_SPEED
    sta in_pos
    cmp #WIPE_TO + 1
    bcc in_down

    lda #$20                    // gate off: the saws fade over the pause
    sta SID_V1_CTRL
    sta SID_V2_CTRL

    lda #COLOR_BLUE
    ldx #INTRO_HOLD
    jsr intro_hold

    lda #WIPE_TO                // wipe back up to black
    sta in_pos
    lda #$01
    sta in_dir
    lda #$00                    // the whoosh: noise, instant attack,
    sta SID_V3_AD               // release 1.5 s
    lda #$fa
    sta SID_V3_SR
    lda #$40
    sta SID_V3_FREQ_HI
    lda #$f4                    // resonance 15, filter voice 3
    sta SID_FILTER_CTRL
    lda #$1f                    // low-pass, volume 15
    sta SID_VOLUME
    jsr intro_sfx               // cutoff for the full screen
    lda #$81                    // noise, gate on
    sta SID_V3_CTRL
in_up:
    jsr intro_frame
    lda in_pos
    sec
    sbc #INTRO_SPEED
    sta in_pos
    cmp #WIPE_FROM
    bcs in_up

    lda #$80                    // gate off, the whoosh dies away on black
    sta SID_V3_CTRL
    lda #COLOR_BLACK
    ldx #INTRO_BLACK
    jsr intro_hold
    lda #$0b                    // display off again for the rest of start
    sta VIC_CTRL1
    jmp sid_clear               // silent for music.init

//------------------------------------------------------------------------------
// intro_sfx: the sound follows the edge. in_dir 0 = saw pitch rises with
// in_pos, 1 = the filter closes with it. ~32-39 cycles with the jsr.
//------------------------------------------------------------------------------
intro_sfx:
    lda in_pos + 1              // A = in_pos / 2 (0-156)
    lsr
    lda in_pos
    ror
    ldx in_dir
    bne !+
    clc
    adc #$10
    sta SID_V1_FREQ_HI
    sta SID_V2_FREQ_HI
    rts
!:  sta SID_FILTER_HI
    rts

//------------------------------------------------------------------------------
// sid_clear: every SID register to 0
//------------------------------------------------------------------------------
sid_clear:
    lda #$00
    ldx #$18
!:  sta SID_V1_FREQ_LO, x
    dex
    bpl !-
    rts

//------------------------------------------------------------------------------
// intro_hold: A = background color, X = frames to hold it
//------------------------------------------------------------------------------
intro_hold:
    sta in_col
    stx in_cnt
!:  lda #$00
    sta in_off
    sta in_off + 1
    jsr color_at
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
    jsr color_at
    jsr intro_sfx               // room for it: the edge starts 5 lines down

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
    jsr color_at
    ldy in_i
    iny
    cpy #edge_col_end - edge_col
    bne if_edge
if_done:
    jmp check_exit

// 4 lines apart: from one write to color_at's first poll is ~130 cycles, plus
// 40 more when a badline falls in the gap, so it starts polling by the line
// before its target with about a line to spare. Don't add work to if_edge
// without widening these. The first is 5 lines down to leave room for
// intro_sfx after the top write.
edge_off:
    .byte 5, 9, 13, 17
edge_col:
    .byte COLOR_LIGHT_BLUE, COLOR_WHITE, COLOR_LIGHT_BLUE, COLOR_BLACK
edge_col_end:

//------------------------------------------------------------------------------
// color_at: $d021 = in_col at the start of line INTRO_TOP + in_off
// (mod in_lines). in_off must be ahead of the beam, and 0 means next frame.
//
// Waits for the right half of the frame (raster bit 8), then catches the
// line before the target and the target itself in two 7-cycle loops, so the
// write lands at cycle 6-12. A badline on the line before only stalls the
// second loop, which then keeps polling; one on the target comes after the
// write.
//------------------------------------------------------------------------------
color_at:
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

    ldy in_col
    ldx in_alo
!:  lda VIC_CTRL1               // the right half of the frame first
    and #$80
    cmp in_phi
    bne !-
    lda in_plo
!:  cmp VIC_RASTER              // the line before the target
    bne !-
!:  cpx VIC_RASTER              // the target
    bne !-
    sty VIC_BACKGROUND
    rts
