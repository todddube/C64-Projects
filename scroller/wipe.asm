//==============================================================================
// FILE:        wipe.asm
// PROJECT:     STARDUST - imported by scroller.asm, not buildable on its own
// DESCRIPTION: The curtain wipe that closes each part, and the hand-over
//              between parts (display off, music on a lone raster IRQ).
//==============================================================================
//
// THE CURTAIN. A part's screen is covered row by row with a SOLID char
// (all 8 lines set) in black, so it works over anything: stars, text, copper
// bars. Sprites are put behind the foreground ($d01b = $ff), and a solid
// char's pixels are foreground, so the curtain covers them too.
//
// The leading edge is line exact: the edge row holds an EDGE char whose
// glyph is rewritten every frame to show the top k lines (wiping down) or
// the bottom k lines (wiping up). Behind it a glow band trails in whole rows:
//   edge row, row behind   c0     (brightest)
//   2 rows behind          c1
//   3 rows behind          c2
//   4 rows behind          black, and so on
// Rows are counted as a distance d from the starting edge, so the same code
// wipes down (row = d) and up (row = 24 - d). Rows are only repainted when
// the edge crosses into a new one, every 8 / W_SPEED frames.
//
// Each wipe picks its direction and its palette at random.
//
// THE LOCK. While a row is covered (or is the edge row), the part must not
// write into it, or it would punch a hole in the curtain. row_locked says
// whether a row is covered; w_lock_lo..w_lock_hi is the covered range.
//
// A PART'S CHARSETS must hold, at codes w_edge and w_solid, an EDGE glyph
// (rewritten here through w_g1 and w_g2) and a SOLID glyph ($ff x 8).
//==============================================================================

.const W_SPEED       = 3                // lines per frame (~1.25 s a wipe)
.const W_DONE        = 28               // d of the last row to paint: 24 + 4

// Zero page $68-$78 (w_on ... w_tmp) is declared in scroller.asm, which
// uses it before this file is imported.

//------------------------------------------------------------------------------
// wipe_reset: no wipe, nothing locked. Every part calls it on entry.
//------------------------------------------------------------------------------
wipe_reset:
    lda #$00
    sta w_on
    sta w_lock_hi
    lda #$ff                    // lo > hi: no row is in the range
    sta w_lock_lo
    rts

//------------------------------------------------------------------------------
// wipe_start: random direction and palette, then the first edge row.
// The caller sets w_edge, w_solid, w_g1 and w_g2 first.
//------------------------------------------------------------------------------
wipe_start:
    jsr rnd                     // stir in the raster, so the wipes are not
    eor VIC_RASTER              // the same sequence on every run
    bne !+
    lda #$a7                    // the LFSR must never hold 0
!:  sta seed
    and #$01
    sta w_dir
    jsr rnd
    and #$03
    tax
    lda w_pal0, x
    sta w_c0
    lda w_pal1, x
    sta w_c1
    lda w_pal2, x
    sta w_c2
    lda #$00
    sta w_pos
    lda #$ff
    sta w_drawn
    sta VIC_SPRITE_PRI          // sprites behind the curtain
    lda #$01
    sta w_on
    jmp wipe_paint

//------------------------------------------------------------------------------
// wipe_step: one frame of the wipe. Returns C set once every row is black.
// Up to ~2700 cycles on a frame where the edge crosses into a new row.
//------------------------------------------------------------------------------
wipe_step:
    lda w_pos
    clc
    adc #W_SPEED
    sta w_pos
wipe_paint:
    lda w_pos                   // the edge glyph: k = w_pos & 7 lines
    and #$07
    asl
    asl
    asl
    ldx w_dir
    beq !+
    ora #$40                    // second half of w_glyphs: from the bottom
!:  tax
    ldy #$00
!:  lda w_glyphs, x
    sta (w_g1), y
    sta (w_g2), y
    inx
    iny
    cpy #$08
    bne !-

wp_rows:                        // paint every row the edge has crossed into
    lda w_pos
    lsr
    lsr
    lsr
    cmp w_drawn
    beq wp_done
    inc w_drawn
    jsr w_cross
    jmp wp_rows
wp_done:
    lda w_drawn
    cmp #W_DONE                 // C set: the last row is black
    bcc !+
    lda #$02
    sta w_on
!:  rts

//------------------------------------------------------------------------------
// w_cross: the edge has just entered distance row w_drawn
//------------------------------------------------------------------------------
w_cross:
    ldx w_drawn                 // the new edge row: EDGE in c0
    lda w_edge
    jsr w_row_chars
    ldx w_drawn
    lda w_c0
    jsr w_row_color
    ldx w_drawn                 // the old edge row: SOLID (already c0)
    dex
    lda w_solid
    jsr w_row_chars
    ldx w_drawn                 // the glow fades down the rows behind
    dex
    dex
    lda w_c1
    jsr w_row_color
    ldx w_drawn
    dex
    dex
    dex
    lda w_c2
    jsr w_row_color
    lda w_drawn
    sec
    sbc #$04
    tax
    lda #COLOR_BLACK
    jsr w_row_color

    lda w_dir                   // the covered range, edge row included
    bne !+
    lda #$00                    // down: rows 0..d
    sta w_lock_lo
    lda w_drawn
    sta w_lock_hi
    rts
!:  lda #24                     // up: rows 24-d..24
    sec
    sbc w_drawn
    bcs !+
    lda #$00
!:  sta w_lock_lo
    lda #24
    sta w_lock_hi
    rts

//------------------------------------------------------------------------------
// w_row_chars / w_row_color: fill distance row X with A, in screen RAM or
// in color RAM. Rows off the screen (X >= 25, which includes X < 0) are
// skipped.
//------------------------------------------------------------------------------
w_row_chars:
    ldy #$00
    beq w_row
w_row_color:
    ldy #>(COLOR_RAM - SCREEN_RAM)
w_row:
    sta w_val
    cpx #25
    bcs wr_out
    lda w_dir
    beq !+
    stx w_tmp                   // wiping up: distance d is row 24 - d
    lda #24
    sec
    sbc w_tmp
    tax
!:  tya
    clc
    adc w_row_hi, x
    sta ptr1_hi
    lda w_row_lo, x
    sta ptr1
    lda w_val
    ldy #39
!:  sta (ptr1), y
    dey
    bpl !-
wr_out:
    rts

//------------------------------------------------------------------------------
// row_locked: A = screen row. Returns C set if the curtain covers it.
// Keeps X and Y.
//------------------------------------------------------------------------------
row_locked:
    cmp w_lock_lo
    bcc rl_free
    cmp w_lock_hi
    beq rl_locked
    bcs rl_free
rl_locked:
    sec
    rts
rl_free:
    clc
    rts

//==============================================================================
// HAND-OVER BETWEEN PARTS
//
// part_blackout -> wait_frames -> (next part builds its screen) -> part_sync
// -> the part installs its own IRQ chain and turns the display on.
// In between, irq_idle at LINE_TOP keeps the music going and ticks
// frame_flag, so the tune never stops.
//==============================================================================

//------------------------------------------------------------------------------
// irq_idle: the music and nothing else
//------------------------------------------------------------------------------
irq_idle:
    sta irq_a
    stx irq_x
    sty irq_y
    lda #$01
    sta VIC_IRQ_STATUS
    jsr music_tick
    inc frame_flag
    lda irq_a
    ldx irq_x
    ldy irq_y
    rti

//------------------------------------------------------------------------------
// part_blackout: call with the curtain all black. Display and sprites off
// (seamless, since the screen is already black), irq_idle takes over.
//------------------------------------------------------------------------------
part_blackout:
    sei
    lda #<irq_idle
    sta $fffe
    lda #>irq_idle
    sta $ffff
    lda #LINE_TOP
    sta VIC_RASTER
    lda #$0b                    // display off, raster bit 8 = 0
    sta VIC_CTRL1
    lda #$08
    sta VIC_CTRL2
    lda #$00
    sta VIC_SPRITE_EN
    sta frame_flag
    lda #$01
    sta VIC_IRQ_STATUS
    cli
    rts

//------------------------------------------------------------------------------
// wait_frames: X frames of whatever is showing, RUN/STOP checked each frame
//------------------------------------------------------------------------------
wait_frames:
    lda frame_flag
    beq wait_frames
    lda #$00
    sta frame_flag
    jsr check_exit
    dex
    bne wait_frames
    rts

//------------------------------------------------------------------------------
// part_sync: wait for irq_idle, then for line 60, past the VIC's DEN check
// at line 48. A part that turns the display on after this shows nothing
// until the next frame, when its own IRQ chain is already running.
//------------------------------------------------------------------------------
part_sync:
    lda #$00
    sta frame_flag
!:  lda frame_flag
    beq !-
!:  lda VIC_RASTER
    cmp #60
    bcc !-
    rts

//==============================================================================
// TABLES
//==============================================================================

w_row_lo:
    .fill 25, <(SCREEN_RAM + i * 40)
w_row_hi:
    .fill 25, >(SCREEN_RAM + i * 40)

// EDGE glyphs: [k * 8 + line] wiping down (top k lines set), then + $40
// wiping up (bottom k lines set)
w_glyphs:
    .for (var k = 0; k < 8; k++) {
        .fill 8, i < k ? $ff : $00
    }
    .for (var k = 0; k < 8; k++) {
        .fill 8, i >= 8 - k ? $ff : $00
    }

// Four glow palettes: cool, fire, toxic, neon
w_pal0:
    .byte COLOR_WHITE, COLOR_YELLOW, COLOR_LIGHT_GREEN, COLOR_CYAN
w_pal1:
    .byte COLOR_LIGHT_BLUE, COLOR_ORANGE, COLOR_GREEN, COLOR_PURPLE
w_pal2:
    .byte COLOR_BLUE, COLOR_RED, COLOR_DARK_GREY, COLOR_BLUE
