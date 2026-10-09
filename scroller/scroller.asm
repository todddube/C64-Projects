//==============================================================================
// FILE:        scroller.asm
// PROJECT:     STARDUST - a space scroller for the Commodore 64
// DESCRIPTION: Sprite logo, ringed planet with an orbiting moon, a ship,
//              parallax starfield, horizon glow and a DYCP scroller riding
//              over copper bars, to Nightshift by Agemixer.
// TARGET:      NTSC 6567R8 first (17095 cycles/frame), PAL second.
// START-UP:    black, a raster wipe down to blue, a pause, a wipe back up
//              to black (scroller_intro.asm), then the demo.
// EXIT:        RUN/STOP resets to BASIC. RESTORE is ignored.
// CREATED:     2026-10-09 by RetroDubTRVA
//==============================================================================
//
// SCREEN, TOP TO BOTTOM (raster lines are the same on NTSC and PAL)
//
//   line  30          irq_top: logo sprites in, then the music tick
//   rows  0-16        starfield (custom charset at $2000)
//     lines 52-106      the logo: 8 Y-expanded letter sprites
//   line 108          irq_mid: the same 8 sprites become ship, flame,
//                     moon and the 2x2 planet
//     lines 118-185     the planet, moon and ship
//   line 192          irq_bars: $d016 fine scroll + DYCP charset on,
//                     then one $d021 write per line down to line 250
//   lines 194-202     horizon glow (fixed part of the bar buffer;
//                     line 194 ends row 17, 195-202 are row 18)
//   rows 19-24        DYCP scroller (charset at $2800) over copper bars
//   line 251          back to black / 40 columns / main charset,
//                     frame_flag tells the main loop to start the frame
//
// FRAME ORDER (main loop, starting at line 251)
//   advance_scroll, update_logo, update_mid   before irq_top copies them
//   draw_dycp                                 finished long before row 19
//   build_bars                                before irq_bars reads it
//   update_stars, update_twinkle, check_exit
//
// THE BAR WRITES. irq_bars polls $d012 and writes $d021 as soon as the line
// changes, which lands at cycle 6-12 of the line: inside the left border,
// before the display window opens at cycle ~16, and before a badline stops
// the CPU at cycle 15. So the bars are clean without a stable raster, as
// long as no sprite is displayed on those lines (sprite DMA would stall the
// write). The scene's sprites all end by line 185.
//
// MEMORY
//   $0400-$07ff  screen + sprite pointers
//   $1000-$1d77  Nightshift (PSID, not relocatable; uses zero page $f8/$f9)
//   $2000-$27ff  main charset: blank + star glyphs   (built at start-up)
//   $2800-$2fff  DYCP charset: 40 columns x 6 chars  (drawn every frame)
//   $3000-$31ff  logo letter sprites                 (built at start-up)
//   $3200-$33ff  planet x4, ship, flame x2, moon     (assembled in)
//   $4000-       code and tables
//   KERNAL and BASIC are banked out ($01 = $35); the IRQ and NMI vectors
//   are the hardware ones at $fffe/$fffa.
//==============================================================================

#import "../C64-Standards/include/c64_constants.asm"
#import "../C64-Standards/include/zeropage.asm"

.var music = LoadSid("Nightshift.sid")

BasicUpstart2(start)

//==============================================================================
// CONSTANTS
//==============================================================================

.label MAIN_CHARSET   = $2000
.label DYCP_CHARSET   = $2800
.label LOGO_SPRITES   = $3000
.label ART_SPRITES    = $3200

.const D018_MAIN      = $18             // screen $0400, chars $2000
.const D018_DYCP      = $1a             // screen $0400, chars $2800
.const D018_KERNAL    = $15             // power-on value, for the exit

.const PTR_LOGO       = LOGO_SPRITES / 64   // $c0-$c7
.const PTR_PLANET     = ART_SPRITES / 64    // $c8-$cb: TL, TR, BL, BR
.const PTR_SHIP       = PTR_PLANET + 4      // $cc
.const PTR_FLAME      = PTR_PLANET + 5      // $cd, $ce
.const PTR_MOON       = PTR_PLANET + 7      // $cf

// Screen layout
.const STAR_ROWS      = 17              // rows 0-16 hold the starfield
.const DYCP_ROW       = 19              // first scroller row
.const DYCP_ROWS      = 6               // 48 lines of wave room
.const BLANK          = $00             // blank in BOTH charsets
.const STAR_CHAR      = $40             // $40-$7f: dot at pixel row v, column k
                                        // = STAR_CHAR + v * 8 + k
.const TWINKLE_BIG    = $80
.const TWINKLE_SMALL  = $81

// Raster lines
.const LINE_TOP       = 30
.const LINE_MID       = 108
.const LINE_BARS      = 192
.const BAR_FIRST      = 194
.const BAR_COUNT      = 57              // lines 194-250
.const HORIZON        = 9               // first 9 bar lines are fixed

// Logo
.const LOGO_Y         = 52
.const LOGO_X0        = 33
.const LOGO_STEP      = 34

// Everything else
.const SCROLL_SPEED   = 2               // pixels per frame
.const NUM_STARS      = STAR_ROWS       // one moving star per row
.const NUM_TWINKLE    = 10
.const SHIP_WRAP      = 360             // ship x wraps here (off the right)

// Colors
.var DYCP_COLORS = List().add(COLOR_GREY, COLOR_LIGHT_GREY, COLOR_WHITE,
                              COLOR_WHITE, COLOR_LIGHT_GREY, COLOR_GREY)
.const PLANET_DARK    = COLOR_BROWN     // $d025 (bit pair 01)
.const PLANET_MID     = COLOR_ORANGE    // own color (bit pair 10)
.const PLANET_LIGHT   = COLOR_YELLOW    // $d026 (bit pair 11)

//==============================================================================
// ZERO PAGE
// temp1-3, scroll_x, frame_count and ptr1/ptr2 come from zeropage.asm.
// $f8/$f9 belong to the Nightshift player.
//==============================================================================

.label tmp            = temp1           // $06
.label tmp2           = temp2           // $07
.label tmp3           = temp3           // $08

.label frame_flag     = $10             // set by irq_bars at line 251
.label text_ptr       = $11             // $11-$12: next scroll text byte
.label dycp_p1        = $13             // wave phases
.label dycp_p2        = $14
.label dycp_d016      = $15             // $d016 for the scroller rows
.label ntsc           = $16             // nonzero on NTSC
.label music_div      = $17             // music_tick's 6-frame counter
.label logo_t         = $18
.label sway_t         = $19
.label color_t        = $1a
.label planet_t       = $1b
.label ship_t         = $1c
.label orbit_t        = $1d
.label ship_x         = $1e             // $1e-$1f
.label src            = $20             // $20-$21
.label dst            = $22             // $22-$23
.label e0             = $24             // expand3 output, left to right
.label e1             = $25
.label e2             = $26
.label seed           = $27
.label letter         = $28
.label glyph_row      = $29
.label irq_a          = $2a
.label irq_x          = $2b
.label irq_y          = $2c
.label overruns       = $2d             // frames whose work missed line 251
.label prof_max       = $2e             // latest line the work has ended on
.label px             = $30             // $30-$31: planet x
.label py             = $32             // planet y

// The start-up wipe (scroller_intro.asm). Free again once the demo runs.
.label in_lines       = $33             // $33-$34: raster lines per frame
.label in_last        = $35             // $35-$36: in_lines - 4
.label in_pos         = $37             // $37-$38: wipe edge, lines from top
.label in_off         = $39             // $39-$3a: border_at's target
.label in_col         = $3b             // border_at's color
.label in_plo         = $3c             // border_at: line before the target
.label in_phi         = $3d             //   (bit 8 as $d011 bit 7)
.label in_alo         = $3e             //   and the target's low byte
.label in_cnt         = $3f
.label in_i           = $40
.label raster_max     = $41             // detect_video: highest line, low byte

//==============================================================================
// MAIN CODE
//==============================================================================

* = $4000 "Main Code"

//------------------------------------------------------------------------------
// start: one-time setup, then falls into main_loop
//------------------------------------------------------------------------------
start:
    sei
    cld
    ldx #$ff
    txs

    // No CIA interrupts. $dd0d also masks CIA 2's NMI sources, but not
    // RESTORE - that is what the NMI vector below is for.
    lda #$7f
    sta CIA1_ICR
    sta CIA2_ICR
    lda CIA1_ICR
    lda CIA2_ICR
    lda #$00
    sta VIC_IRQ_ENABLE
    lda #$ff
    sta VIC_IRQ_STATUS

    // Hardware vectors. Writes under the KERNAL ROM always land in RAM.
    // $0318 as well, for the moment before the KERNAL is banked out.
    lda #<nmi_ignore            // $0318 (used while the KERNAL is in)
    sta $0318                   // first, whole, then $fffa
    lda #>nmi_ignore
    sta $0319
    lda #<nmi_ignore
    sta $fffa
    lda #>nmi_ignore
    sta $fffb
    lda #<irq_top
    sta $fffe
    lda #>irq_top
    sta $ffff

    lda #$0b                    // display off while everything is built
    sta VIC_CTRL1
    lda #COLOR_BLACK
    sta VIC_BORDER
    sta VIC_BACKGROUND
    sta VIC_SPRITE_EN

    lda #$33                    // character ROM at $d000, no I/O
    sta $01
    jsr build_font
    jsr build_logo
    lda #$35                    // RAM + I/O, BASIC and KERNAL out
    sta $01

    jsr init_charsets
    jsr init_screen
    jsr init_vars               // clears $10-$30, so before detect_video
    jsr detect_video
    jsr init_stars
    jsr intro                   // black, wipe to blue, pause, wipe to black

    lda #music.startSong - 1
    ldx #$00
    ldy #$00
    jsr music.init

    // Shadows for the first frame, before the first IRQ reads them
    jsr advance_scroll
    jsr update_logo
    jsr update_mid
    jsr build_bars

    lda #D018_MAIN
    sta VIC_MEMSETUP
    lda #$08                    // 40 columns, no fine scroll
    sta VIC_CTRL2
    lda #$00
    sta VIC_SPRITE_PRI          // sprites in front of the stars
    sta VIC_SPRITE_EXP_X
    lda #PLANET_DARK
    sta VIC_SPRITE_MC0
    lda #PLANET_LIGHT
    sta VIC_SPRITE_MC1

    lda #LINE_TOP
    sta VIC_RASTER
    lda #$1b                    // display on, 25 rows, raster bit 8 = 0
    sta VIC_CTRL1
    lda #$01
    sta VIC_IRQ_ENABLE
    sta VIC_IRQ_STATUS
    cli

//------------------------------------------------------------------------------
// main_loop: one pass per frame, started by irq_bars at line 251
//------------------------------------------------------------------------------
main_loop:
    lda frame_flag
    beq main_loop
    lda #$00
    sta frame_flag

    jsr advance_scroll
    jsr update_logo
    jsr update_mid
    jsr draw_dycp
    jsr build_bars
    jsr update_stars
    jsr update_twinkle
    jsr check_exit
    inc frame_count

    // Profiling, read with vice_peek: the latest line the work has ended
    // on, and how many frames ran past the next irq_bars.
    lda VIC_RASTER
    cmp prof_max
    bcc !+
    sta prof_max
!:  lda frame_flag
    beq main_loop
    inc overruns
    jmp main_loop

//==============================================================================
// INTERRUPTS
//==============================================================================

//------------------------------------------------------------------------------
// irq_top (line 30): logo sprites, then the music tick
//------------------------------------------------------------------------------
irq_top:
    sta irq_a
    stx irq_x
    sty irq_y

    lda #$ff
    sta VIC_SPRITE_EXP_Y
    lda #$00
    sta VIC_SPRITE_MC
    .for (var i = 0; i < 8; i++) {
        lda logo_x + i
        sta VIC_SPRITE0_X + i * 2
        lda logo_y + i
        sta VIC_SPRITE0_Y + i * 2
        lda logo_col + i
        sta VIC_SPRITE0_COL + i
        lda #PTR_LOGO + i
        sta SPRITE_PTR_BASE + i
    }
    lda logo_msb
    sta VIC_SPRITE_X_MSB
    lda #$ff
    sta VIC_SPRITE_EN

    lda #LINE_MID
    sta VIC_RASTER
    lda #<irq_mid
    sta $fffe
    lda #>irq_mid
    sta $ffff
    lda #$01
    sta VIC_IRQ_STATUS

    jsr music_tick              // up to ~2000 cycles, ends well before 108

    lda irq_a
    ldx irq_x
    ldy irq_y
    rti

//------------------------------------------------------------------------------
// irq_mid (line 108): the logo has finished; reuse the sprites for the scene
//------------------------------------------------------------------------------
irq_mid:
    sta irq_a
    stx irq_x
    sty irq_y

    lda #$00
    sta VIC_SPRITE_EXP_Y
    lda #%01111000              // slots 3-6 (the planet) are multicolor
    sta VIC_SPRITE_MC
    .for (var i = 0; i < 8; i++) {
        lda mid_xlo + i
        sta VIC_SPRITE0_X + i * 2
        lda mid_y + i
        sta VIC_SPRITE0_Y + i * 2
        lda mid_col + i
        sta VIC_SPRITE0_COL + i
        lda mid_ptr + i
        sta SPRITE_PTR_BASE + i
    }
    lda mid_msb
    sta VIC_SPRITE_X_MSB
    lda mid_en
    sta VIC_SPRITE_EN

    lda #LINE_BARS
    sta VIC_RASTER
    lda #<irq_bars
    sta $fffe
    lda #>irq_bars
    sta $ffff
    lda #$01
    sta VIC_IRQ_STATUS

    lda irq_a
    ldx irq_x
    ldy irq_y
    rti

//------------------------------------------------------------------------------
// irq_bars (line 192): scroller split and the per-line background colors
//
// Rows 17-18 are BLANK, which is empty in both charsets, so switching $d016
// and $d018 here (mid line 192, row 17) shows nothing.
//------------------------------------------------------------------------------
irq_bars:
    sta irq_a
    stx irq_x
    sty irq_y

    lda dycp_d016
    sta VIC_CTRL2
    lda #D018_DYCP
    sta VIC_MEMSETUP

    ldx #$00
    ldy #BAR_FIRST
ib_line:
    lda bar_buf, x
ib_wait:
    cpy VIC_RASTER              // read on cycle 4: the line change is seen
    bne ib_wait                 // within 7 cycles of it happening
    sta VIC_BACKGROUND          // written by cycle ~12
    inx
    iny
    cpy #BAR_FIRST + BAR_COUNT
    bne ib_line

    lda #COLOR_BLACK            // Y = 251: first line of the bottom border
ib_end:
    cpy VIC_RASTER
    bne ib_end
    sta VIC_BACKGROUND
    lda #$08
    sta VIC_CTRL2
    lda #D018_MAIN
    sta VIC_MEMSETUP

    lda #LINE_TOP
    sta VIC_RASTER
    lda #<irq_top
    sta $fffe
    lda #>irq_top
    sta $ffff
    lda #$01
    sta VIC_IRQ_STATUS
    inc frame_flag

    lda irq_a
    ldx irq_x
    ldy irq_y
    rti

//------------------------------------------------------------------------------
// nmi_ignore: RESTORE lands here instead of in the (banked-out) KERNAL
//------------------------------------------------------------------------------
nmi_ignore:
    rti

//==============================================================================
// SET-UP
//==============================================================================

//------------------------------------------------------------------------------
// detect_video: ntsc = 1 on NTSC, 0 on PAL. Interrupts off.
//
// Runs the raster into lines 256+ and keeps the highest low byte seen there:
// NTSC tops out at $106 (6567R8) or $105 (R56A), PAL at $137. The max, not
// the last read, because the raster can wrap between the two reads.
//------------------------------------------------------------------------------
detect_video:
    lda #$00
    sta ntsc
dv_wait:
    bit VIC_CTRL1
    bpl dv_wait
dv_track:
    lda VIC_RASTER
    cmp ntsc
    bcc !+
    sta ntsc
!:  bit VIC_CTRL1
    bmi dv_track
    lda ntsc
    sta raster_max              // the intro counts the frame's lines from it
    ldx #$00
    cmp #$20
    bcs !+
    inx
!:  stx ntsc
    lda #$05
    sta music_div
    rts

//------------------------------------------------------------------------------
// build_font: font_rows + k*64 + c = row k of screen code c, made bold.
// Needs the character ROM banked in ($01 = $33).
//
// Row-major so draw_dycp can fetch any row of any letter with one lda abs,x.
//------------------------------------------------------------------------------
build_font:
    lda #<CHAR_ROM
    sta src
    lda #>CHAR_ROM
    sta src + 1
    ldx #$00
bf_char:
    .for (var k = 0; k < 8; k++) {
        ldy #k
        lda (src), y
        sta tmp
        lsr
        ora tmp                 // bold: each pixel also lights its right
        sta font_rows + k * 64, x
    }
    lda src
    clc
    adc #$08
    sta src
    bcc !+
    inc src + 1
!:  inx
    cpx #64
    bne bf_char
    rts

//------------------------------------------------------------------------------
// build_logo: the 8 letters of logo_text as sprites, from the character ROM.
// Each glyph pixel becomes 3 sprite pixels across and 2 rows down; with Y
// expansion a letter is 24 x 32. Needs the character ROM ($01 = $33).
//------------------------------------------------------------------------------
build_logo:
    lda #$00
    tax
!:  sta LOGO_SPRITES, x
    sta LOGO_SPRITES + $100, x
    inx
    bne !-

    lda #$00
    sta letter
bl_letter:
    ldx letter
    lda logo_text, x            // src = CHAR_ROM + code * 8
    sta src
    lda #$00
    sta src + 1
    asl src
    rol src + 1
    asl src
    rol src + 1
    asl src
    rol src + 1
    lda src + 1
    clc
    adc #>CHAR_ROM
    sta src + 1

    lda letter                  // dst = LOGO_SPRITES + letter * 64
    lsr
    lsr
    clc
    adc #>LOGO_SPRITES
    sta dst + 1
    lda letter
    and #$03
    asl
    asl
    asl
    asl
    asl
    asl
    sta dst

    lda #$00
    sta glyph_row
bl_row:
    ldy glyph_row
    lda (src), y
    sta tmp
    lsr
    ora tmp                     // bold, like the scroller font
    jsr expand3

    lda glyph_row               // Y = row * 6: two sprite rows per glyph row
    asl
    sta tmp
    asl
    adc tmp
    tay
    .for (var r = 0; r < 2; r++) {
        lda e0
        sta (dst), y
        iny
        lda e1
        sta (dst), y
        iny
        lda e2
        sta (dst), y
        iny
    }

    inc glyph_row
    lda glyph_row
    cmp #$08
    bne bl_row
    inc letter
    lda letter
    cmp #$08
    bne bl_letter
    rts

//------------------------------------------------------------------------------
// expand3: A (8 pixels) -> e0 e1 e2 (24 pixels), every pixel tripled.
// Uses X and tmp.
//------------------------------------------------------------------------------
expand3:
    sta tmp
    ldx #$08
ex_bit:
    asl tmp                     // C = next pixel, leftmost first
    php
    rol e2
    rol e1
    rol e0
    plp
    php
    rol e2
    rol e1
    rol e0
    plp
    rol e2
    rol e1
    rol e0
    dex
    bne ex_bit
    rts

//------------------------------------------------------------------------------
// init_charsets: both charsets empty, then the star glyphs in the main one:
// 64 one-pixel dots (every row and column of the cell) and two twinkles.
//------------------------------------------------------------------------------
init_charsets:
    lda #$00
    tax
!:  .for (var p = 0; p < 16; p++) {
        sta MAIN_CHARSET + p * $100, x      // $2000-$2fff, both charsets
    }
    inx
    bne !-

    .for (var v = 0; v < 8; v++) {
        .for (var k = 0; k < 8; k++) {
            lda #($80 >> k)
            sta MAIN_CHARSET + (STAR_CHAR + v * 8 + k) * 8 + v
        }
    }
    ldx #15
!:  lda twinkle_glyphs, x
    sta MAIN_CHARSET + TWINKLE_BIG * 8, x
    dex
    bpl !-
    rts

//------------------------------------------------------------------------------
// init_screen: everything BLANK and black, the fixed background stars, then
// the DYCP character grid.
//
// Column c of the scroller shows chars c*6+1 .. c*6+6 top to bottom, so its
// 48 bytes of glyph data are contiguous in the DYCP charset.
//------------------------------------------------------------------------------
init_screen:
    ldx #$00
!:  lda #BLANK
    sta SCREEN_RAM, x
    sta SCREEN_RAM + $100, x
    sta SCREEN_RAM + $200, x
    sta SCREEN_RAM + $2e8, x
    lda #COLOR_BLACK
    sta COLOR_RAM, x
    sta COLOR_RAM + $100, x
    sta COLOR_RAM + $200, x
    sta COLOR_RAM + $2e8, x
    inx
    bne !-

    // The fixed background stars, rows 0-16 (680 cells = 256 + 256 + 168)
    ldx #$00
!:  lda bg_chars, x
    sta SCREEN_RAM, x
    lda bg_chars + $100, x
    sta SCREEN_RAM + $100, x
    lda bg_colors, x
    sta COLOR_RAM, x
    lda bg_colors + $100, x
    sta COLOR_RAM + $100, x
    inx
    bne !-
    ldx #$00                    // counting up: 167 is negative to bpl
!:  lda bg_chars + $200, x
    sta SCREEN_RAM + $200, x
    lda bg_colors + $200, x
    sta COLOR_RAM + $200, x
    inx
    cpx #STAR_ROWS * 40 - $200
    bne !-

    ldx #$00
    lda #$01
is_col:
    .for (var r = 0; r < DYCP_ROWS; r++) {
        sta SCREEN_RAM + (DYCP_ROW + r) * 40, x
        clc
        adc #$01
    }
    inx
    cpx #40
    bne is_col

    ldx #39
is_color:
    .for (var r = 0; r < DYCP_ROWS; r++) {
        lda #DYCP_COLORS.get(r)
        sta COLOR_RAM + (DYCP_ROW + r) * 40, x
    }
    dex
    bpl is_color
    rts

//------------------------------------------------------------------------------
// init_vars: animation state, scroll text, the fixed horizon
//------------------------------------------------------------------------------
init_vars:
    lda #$00
    ldx #$30 - $10
!:  sta $10, x                  // clear our zero page, $10-$30
    dex
    bpl !-
    sta frame_count
    lda #$07
    sta scroll_x
    lda #$a7
    sta seed
    lda #<scroll_text
    sta text_ptr
    lda #>scroll_text
    sta text_ptr + 1

    ldx #39
    lda #$20                    // screen code space
!:  sta text_buffer, x
    dex
    bpl !-

    ldx #HORIZON - 1
!:  lda horizon_colors, x
    sta bar_buf, x
    dex
    bpl !-
    rts

//------------------------------------------------------------------------------
// init_stars: one star per row, random column and sub-pixel, fixed layer.
// Needs init_screen first (it draws the stars into the cleared screen).
//------------------------------------------------------------------------------
init_stars:
    ldx #NUM_STARS - 1
ist_loop:
    lda row_lo, x
    sta star_lo, x
    lda row_hi, x
    sta star_hi, x
    lda bg_row_lo, x
    sta star_bgl, x
    lda bg_row_hi, x
    sta star_bgh, x
    jsr rnd                     // pixel row inside the cell, so the stars
    and #$07                    // do not all line up 8 lines apart
    asl
    asl
    asl
    ora #STAR_CHAR
    sta star_base, x
    jsr rnd
    and #$3f
    cmp #40
    bcc !+
    sbc #24                     // 40-63 -> 16-39 (C is set)
!:  sta star_col, x
    jsr rnd
    and #$07
    sta star_sub, x
    lda star_layer, x
    tay
    lda layer_color, y
    sta star_color, x

    lda star_lo, x              // draw it once: update_stars only writes
    sta ptr1                    // the color when a star changes cell
    lda star_hi, x
    sta ptr1_hi
    ldy star_col, x
    lda star_sub, x
    ora star_base, x
    sta (ptr1), y
    lda ptr1_hi
    clc
    adc #>(COLOR_RAM - SCREEN_RAM)
    sta ptr1_hi
    lda star_color, x
    sta (ptr1), y
    dex
    bpl ist_loop
    rts

//------------------------------------------------------------------------------
// rnd: 8-bit Galois LFSR. A = next value. Keeps X and Y.
//------------------------------------------------------------------------------
rnd:
    lda seed
    asl
    bcc !+
    eor #$1d
!:  sta seed
    rts

//==============================================================================
// PER-FRAME WORK
//==============================================================================

//------------------------------------------------------------------------------
// music_tick: Nightshift is a 50 Hz tune. On NTSC skip every sixth call, so
// 5 plays in 6 frames is 50 a second and the tempo matches PAL.
//------------------------------------------------------------------------------
music_tick:
    lda ntsc
    beq mt_play
    dec music_div
    bpl mt_play
    lda #$05
    sta music_div
    rts
mt_play:
    jmp music.play

//------------------------------------------------------------------------------
// advance_scroll: fine scroll, the text shift every 8 pixels, wave phases
//------------------------------------------------------------------------------
advance_scroll:
    lda scroll_x
    sec
    sbc #SCROLL_SPEED
    bpl as_store
    and #$07
    sta scroll_x
    jsr shift_text
    jmp as_d016
as_store:
    sta scroll_x
as_d016:
    lda scroll_x                // 38 columns hide the column entering
    sta dycp_d016               // on the right and leaving on the left

    lda dycp_p1
    clc
    adc #3
    sta dycp_p1
    lda dycp_p2
    sec
    sbc #2
    sta dycp_p2
    rts

//------------------------------------------------------------------------------
// shift_text: text_buffer one left, the next text byte in at column 39
//------------------------------------------------------------------------------
shift_text:
    .for (var c = 0; c < 39; c++) {
        lda text_buffer + c + 1
        sta text_buffer + c
    }
    ldy #$00
    lda (text_ptr), y
    cmp #$ff                    // end marker: start the text again
    bne st_char
    lda #<scroll_text
    sta text_ptr
    lda #>scroll_text
    sta text_ptr + 1
    lda (text_ptr), y
st_char:
    and #$3f                    // font_rows holds screen codes 0-63
    sta text_buffer + 39
    inc text_ptr
    bne !+
    inc text_ptr + 1
!:  rts

//------------------------------------------------------------------------------
// draw_dycp: every column's letter at its own height, in the DYCP charset.
//
// Column c gets a 12-byte block: 2 empty rows, the 8 glyph rows, 2 empty
// rows, at y = tabA[p1 + 7c] + tabB[p2 + 5c] (0..34). The empty rows wipe
// whatever the last frame left, since no column moves more than 1.43 pixels
// a frame, so the charset is never cleared. Unrolled: ~120 cycles a column,
// ~5300 for the lot (measured on NTSC, the largest single job in a frame).
//------------------------------------------------------------------------------
draw_dycp:
    .for (var c = 0; c < 40; c++) {
        .var base = DYCP_CHARSET + (c * DYCP_ROWS + 1) * 8
        ldy dycp_p1
        lda tabA + 7 * c, y
        ldy dycp_p2
        clc
        adc tabB + 5 * c, y
        tay
        ldx text_buffer + c
        lda #$00
        sta base + 0, y
        sta base + 1, y
        .for (var k = 0; k < 8; k++) {
            lda font_rows + k * 64, x
            sta base + 2 + k, y
        }
        lda #$00
        sta base + 10, y
        sta base + 11, y
    }
    rts

//------------------------------------------------------------------------------
// build_bars: the 48 scroller lines of bar_buf - black, then three copper
// bars at their own speeds. Drawn green, blue, red, so red is in front.
//------------------------------------------------------------------------------
build_bars:
    lda #COLOR_BLACK
    .for (var i = 0; i < BAR_COUNT - HORIZON; i++) {
        sta bar_buf + HORIZON + i
    }
    ldx #2
bb_bar:
    lda bar_phase, x
    clc
    adc bar_speed, x
    sta bar_phase, x
    tay
    lda bar_sin, y              // 0..39: top of the 9-line bar
    clc
    adc #HORIZON
    tay
    stx tmp2
    lda bar_grad_ofs, x
    tax
    .for (var i = 0; i < 9; i++) {
        lda bar_grads + i, x
        sta bar_buf + i, y
    }
    ldx tmp2
    dex
    bpl bb_bar
    rts

//------------------------------------------------------------------------------
// update_logo: sway, bob and highlight sweep for the 8 letter sprites.
// Unrolled, with the per-letter phase offsets folded into table addresses.
//------------------------------------------------------------------------------
update_logo:
    lda logo_t
    clc
    adc #3
    sta logo_t
    inc sway_t
    lda frame_count
    and #$03
    bne !+
    inc color_t
!:  ldy sway_t
    lda sway_tab, y             // 0..40
    sta tmp
    lda #$00
    sta tmp2                    // X MSBs, collected letter 7 first
    lda color_t
    and #$1f
    tax
    ldy logo_t
    .for (var i = 7; i >= 0; i--) {
        lda #<(LOGO_X0 + i * LOGO_STEP)
        clc
        adc tmp
        sta logo_x + i
        lda #>(LOGO_X0 + i * LOGO_STEP)
        adc #$00
        lsr
        rol tmp2
        lda bob_tab + 24 * i, y         // bob phase: logo_t + 24 * letter
        sta logo_y + i
        lda logo_grad + 32 - i, x       // highlight: color_t - letter
        sta logo_col + i
    }
    lda tmp2
    sta logo_msb
    rts

//------------------------------------------------------------------------------
// update_mid: planet, orbiting moon, ship and flame
//
// Slots: 0 ship, 1 flame, 2 moon in front, 3-6 planet, 7 moon behind.
// A lower sprite number is drawn in front, so the moon swaps between slot 2
// and slot 7 to pass in front of the planet and behind it.
//------------------------------------------------------------------------------
update_mid:
    lda frame_count
    and #$03
    bne !+
    inc planet_t
!:  ldy planet_t
    lda planet_x_lo, y
    sta px
    lda planet_x_hi, y
    sta px + 1
    tya
    asl
    tay
    lda planet_y, y
    sta py

    lda px                      // the 2x2 planet
    sta mid_xlo + 3
    sta mid_xlo + 5
    clc
    adc #24
    sta mid_xlo + 4
    sta mid_xlo + 6
    lda px + 1
    sta mid_xhi + 3
    sta mid_xhi + 5
    adc #$00
    sta mid_xhi + 4
    sta mid_xhi + 6
    lda py
    sta mid_y + 3
    sta mid_y + 4
    clc
    adc #21
    sta mid_y + 5
    sta mid_y + 6

    // Moon: x = px - 28 + (40 + 40 cos), y = py + 3 + (8 + 8 sin)
    inc orbit_t
    ldy orbit_t
    lda px
    clc
    adc orbit_dx, y
    sta tmp
    lda px + 1
    adc #$00
    sta tmp2
    lda tmp
    sec
    sbc #28
    sta tmp
    lda tmp2
    sbc #$00
    sta tmp2
    lda py
    clc
    adc orbit_dy, y
    clc
    adc #3
    sta tmp3
    ldx #2                      // sin > 0 (lower, nearer): in front
    lda #%01111111
    bit orbit_t
    bpl !+
    ldx #7                      // sin < 0: behind the planet
    lda #%11111011
!:  sta mid_en
    lda tmp
    sta mid_xlo, x
    lda tmp2
    sta mid_xhi, x
    lda tmp3
    sta mid_y, x

    // Ship: left to right, wrapping off the right edge, with a slow bob
    inc ship_x
    bne !+
    inc ship_x + 1
!:  lda ship_x + 1
    cmp #>SHIP_WRAP
    bne !+
    lda ship_x
    cmp #<SHIP_WRAP
    bne !+
    lda #$00
    sta ship_x
    sta ship_x + 1
!:  lda ship_t
    clc
    adc #2
    sta ship_t
    tay
    lda ship_y_tab, y
    sta mid_y + 0
    sta mid_y + 1
    lda ship_x
    sta mid_xlo + 0
    sta mid_xlo + 1
    lda ship_x + 1
    sta mid_xhi + 0
    sta mid_xhi + 1

    lda frame_count             // thruster flicker: frame and color
    lsr
    lsr
    and #$01
    tax
    clc
    adc #PTR_FLAME
    sta mid_ptr + 1
    lda flame_colors, x
    sta mid_col + 1

    lda #$00                    // pack the X MSBs, slot 7 first
    sta tmp
    ldx #7
!:  lda mid_xhi, x
    lsr
    rol tmp
    dex
    bpl !-
    lda tmp
    sta mid_msb
    rts

//------------------------------------------------------------------------------
// update_stars: three parallax layers, moving left a pixel at a time
//
// A star is the char star_base + sub: a dot at pixel column sub, on its own
// pixel row. When sub goes below 0 the star moves to the cell on its left
// (wrapping from column 0 to 39). The cell it leaves gets its background
// star back, char and color, from bg_chars/bg_colors - that only happens on
// a cell change, every 4-16 frames per star, so the fixed stars are nearly
// free. A star in the same cell only rewrites its char.
//------------------------------------------------------------------------------
update_stars:
    lda frame_count             // the slow layer moves every other frame
    and #$01
    sta layer_step
    ldx #NUM_STARS - 1
us_loop:
    ldy star_layer, x
    lda layer_step, y
    beq us_next
    sta tmp
    lda star_lo, x
    sta ptr1
    lda star_hi, x
    sta ptr1_hi
    ldy star_col, x
    lda star_sub, x
    sec
    sbc tmp
    bpl us_same

    clc                         // into the cell on the left
    adc #8
    sta star_sub, x
    lda star_bgl, x             // the cell left behind: background back
    sta ptr2
    lda star_bgh, x
    sta ptr2_hi
    lda (ptr2), y
    sta (ptr1), y
    lda ptr1                    // dst = the row in color RAM
    sta dst
    lda ptr1_hi
    clc
    adc #>(COLOR_RAM - SCREEN_RAM)
    sta dst + 1
    lda ptr2_hi                 // bg_colors = bg_chars + $300
    clc
    adc #$03
    sta ptr2_hi
    lda (ptr2), y
    sta (dst), y
    dey
    bpl !+
    ldy #39
!:  tya
    sta star_col, x
    lda star_sub, x             // the new cell: char and color
    ora star_base, x
    sta (ptr1), y
    lda star_color, x
    sta (dst), y
    dex
    bpl us_loop
    rts
us_same:
    sta star_sub, x             // same cell: the color is already there
    ora star_base, x
    sta (ptr1), y
us_next:
    dex
    bpl us_loop
    rts

//------------------------------------------------------------------------------
// update_twinkle: fixed stars that flash up and fade, each on its own phase.
//
// The flash moves one step every 4 frames, so each star only needs a visit
// every 4 frames: this frame does stars (frame & 3), +4, +8. Spread out like
// that it costs ~300 cycles a frame instead of ~1100 every fourth one.
//------------------------------------------------------------------------------
update_twinkle:
    lda frame_count
    lsr
    lsr
    sta tmp3
    lda frame_count
    and #$03
    tax
ut_loop:
    lda tmp3
    clc
    adc tw_phase, x
    and #$1f
    tay
    lda tw_char_tab, y
    sta tmp
    lda tw_color_tab, y
    sta tmp2
    lda tw_lo, x
    sta ptr2
    lda tw_hi, x
    sta ptr2_hi
    ldy #$00
    lda (ptr2), y               // a moving star is passing through: leave
    and #$c0                    // it be (chars $40-$7f); update_stars puts
    cmp #STAR_CHAR              // the twinkle back from bg_chars as it goes
    beq ut_next
    lda tmp
    sta (ptr2), y
    lda ptr2_hi
    clc
    adc #>(COLOR_RAM - SCREEN_RAM)
    sta ptr2_hi
    lda tmp2
    sta (ptr2), y
ut_next:
    inx
    inx
    inx
    inx
    cpx #NUM_TWINKLE
    bcc ut_loop
    rts

//------------------------------------------------------------------------------
// check_exit: RUN/STOP (row 7, column bit 7, active low) ends the demo
//------------------------------------------------------------------------------
check_exit:
    lda #$7f
    sta CIA1_PORTA
    lda CIA1_PORTB
    and #$80
    beq exit_demo
    lda #$ff
    sta CIA1_PORTA
    rts

//------------------------------------------------------------------------------
// exit_demo: silence everything and reset through the KERNAL.
// No cli: the reset does its own sei, and an IRQ here would find our vectors.
//------------------------------------------------------------------------------
exit_demo:
    sei
    lda #$00
    sta VIC_IRQ_ENABLE
    lda #$ff
    sta VIC_IRQ_STATUS
    lda #$00
    ldx #$18
!:  sta SID_V1_FREQ_LO, x
    dex
    bpl !-
    sta VIC_SPRITE_EN
    lda #$1b
    sta VIC_CTRL1
    lda #$08
    sta VIC_CTRL2
    lda #D018_KERNAL
    sta VIC_MEMSETUP
    lda #$ff
    sta CIA1_PORTA
    lda #$37                    // KERNAL back, so $fffc is the ROM vector
    sta $01
    jmp ($fffc)

#import "scroller_intro.asm"
#import "scroller_data.asm"

//==============================================================================
// SID MUSIC DATA
//==============================================================================

* = music.location "Music"
.fill music.size, music.getData(i)

.print ""
.print "SID Data"
.print "--------"
.print "location=$" + toHexString(music.location)
.print "init=$" + toHexString(music.init)
.print "play=$" + toHexString(music.play)
.print "name=" + music.name
.print "author=" + music.author
