//==============================================================================
// FILE:        scroller.asm
// PROJECT:     Enhanced Scroller Demo
// DESCRIPTION: Raster bars, starfield, color cycling text demo
//              Inspired by classic C64 demo effects
// REFERENCE:   https://tnd64.unikat.sk/assemble_it6.html
// AUTHOR:      C64 Standards Project
// VERSION:     1.0
//==============================================================================

//------------------------------------------------------------------------------
// Include C64 Standard Library
//------------------------------------------------------------------------------
#import "../../C64-Standards/include/c64_constants.asm"
#import "../../C64-Standards/include/zeropage.asm"

//------------------------------------------------------------------------------
// BASIC Loader - Using KickAssembler built-in
//------------------------------------------------------------------------------
BasicUpstart2(Start)

//==============================================================================
// CONSTANTS
//==============================================================================

.label SCROLL_LINE      = 24          // Screen row for scroller (bottom)
.label STAR_AREA_START  = 3           // Row where stars begin
.label STAR_AREA_END    = 22          // Row where stars end
.label NUM_STARS        = 24          // Number of stars

//==============================================================================
// ZERO PAGE VARIABLES
// Using standard library zero page allocation
//==============================================================================

.label text_ptr         = zp_free_1   // $02 - Scroll text pointer
.label star_phase       = temp1       // $E7 - Star animation phase
.label color_offset     = temp2       // $E8 - Rainbow color offset
.label raster_color     = temp3       // $E9 - Raster bar color index
.label bounce_index     = temp4       // $EA - Bounce sine table index

//==============================================================================
// MAIN CODE
//==============================================================================

* = $0810 "Main Code"

//------------------------------------------------------------------------------
// Start: Main entry point
//------------------------------------------------------------------------------
Start:
    sei

    // Set colors - black background, blue border
    lda #COLOR_BLACK
    sta VIC_BORDER
    lda #COLOR_BLACK
    sta VIC_BACKGROUND

    // Standard screen setup
    lda #$1B
    sta VIC_CTRL1
    lda #$08
    sta VIC_CTRL2

    // Initialize variables
    lda #$07
    sta scroll_x
    lda #$00
    sta text_ptr
    sta frame_count
    sta star_phase
    sta color_offset
    sta raster_color
    sta bounce_index

    // Clear screen
    jsr ClearScreenRam

    // Initialize stars
    jsr InitStars

    // Initialize scroll text colors
    jsr InitTextColors

    cli

//------------------------------------------------------------------------------
// MainLoop: Main program loop
//------------------------------------------------------------------------------
MainLoop:
    // Wait for raster at bottom of screen
    lda #$F8
!waitRaster:
    cmp VIC_RASTER
    bne !waitRaster-

    // Do raster bar effect while beam travels down
    jsr DoRasterBars

    // Update all effects
    jsr UpdateScroller
    jsr UpdateStarfield
    jsr UpdateTextColors

    inc frame_count

    jmp MainLoop

//==============================================================================
// SUBROUTINES
//==============================================================================

//------------------------------------------------------------------------------
// DoRasterBars: Color cycling border effect
//------------------------------------------------------------------------------
DoRasterBars:
    ldx raster_color
    inx
    txa
    and #$3F
    sta raster_color
    tax

    // Cycle through colors on border
    ldy #$08
!rasterLoop:
    lda raster_colors, x
    sta VIC_BORDER

    // Small delay
    nop
    nop
    nop
    nop

    inx
    txa
    and #$0F
    tax
    dey
    bne !rasterLoop-

    // Reset border to blue
    lda #COLOR_BLUE
    sta VIC_BORDER
    rts

//------------------------------------------------------------------------------
// ClearScreenRam: Clear screen and set colors
//------------------------------------------------------------------------------
ClearScreenRam:
    lda #SC_SPACE
    ldx #$00
!clearLoop:
    sta SCREEN_RAM, x
    sta SCREEN_RAM + $100, x
    sta SCREEN_RAM + $200, x
    sta SCREEN_RAM + $2E8, x
    lda #COLOR_WHITE
    sta COLOR_RAM, x
    sta COLOR_RAM + $100, x
    sta COLOR_RAM + $200, x
    sta COLOR_RAM + $2E8, x
    lda #SC_SPACE
    dex
    bne !clearLoop-
    rts

//------------------------------------------------------------------------------
// InitStars: Initialize starfield positions and properties
//------------------------------------------------------------------------------
InitStars:
    ldx #NUM_STARS - 1
!initStarLoop:
    // Pseudo-random X position (0-39)
    txa
    asl
    asl
    eor #$A5
    and #$27                        // 0-39
    sta star_x, x

    // Pseudo-random Y position in star area
    txa
    asl
    eor #$5A
    and #$0F
    clc
    adc #STAR_AREA_START
    cmp #STAR_AREA_END
    bcc !starYOk+
    lda #STAR_AREA_START
!starYOk:
    sta star_y, x

    // Speed based on index (1-3)
    txa
    and #$03
    clc
    adc #$01
    sta star_speed, x

    // Character based on speed
    txa
    and #$03
    tay
    lda star_chars, y
    sta star_char, x

    dex
    bpl !initStarLoop-

    // Draw initial stars
    jsr DrawAllStars
    rts

//------------------------------------------------------------------------------
// DrawAllStars: Draw all stars at their initial positions
//------------------------------------------------------------------------------
DrawAllStars:
    ldx #NUM_STARS - 1
!drawInitLoop:
    lda star_y, x
    tay
    lda row_lo, y
    sta ptr1
    lda row_hi, y
    sta ptr1_hi
    ldy star_x, x
    lda star_char, x
    sta (ptr1), y

    // Set color
    lda star_y, x
    tay
    lda row_lo_color, y
    sta ptr2
    lda row_hi_color, y
    sta ptr2_hi
    lda star_speed, x
    tay
    lda star_colors, y
    ldy star_x, x
    sta (ptr2), y

    dex
    bpl !drawInitLoop-
    rts

//------------------------------------------------------------------------------
// InitTextColors: Initialize rainbow colors for scroll text line
//------------------------------------------------------------------------------
InitTextColors:
    ldx #39
!initColorLoop:
    txa
    and #$0F
    tay
    lda rainbow_colors, y
    sta COLOR_RAM + (SCROLL_LINE * 40), x
    dex
    bpl !initColorLoop-
    rts

//------------------------------------------------------------------------------
// UpdateScroller: Handle horizontal scrolling text with bounce effect
//------------------------------------------------------------------------------
UpdateScroller:
    // Update bounce effect - get Y offset from sine table
    inc bounce_index
    ldx bounce_index
    lda bounce_table, x

    // Combine with standard VIC_CTRL1 settings
    // $1B = %00011011 = DEN + RSEL + Y-scroll of 3
    // We modify the Y-scroll (bits 0-2) for the bounce
    ora #$18                        // DEN + RSEL bits
    sta VIC_CTRL1

    // Decrease scroll position
    dec scroll_x
    lda scroll_x
    and #$07
    sta scroll_x
    ora #$08                        // Multi-color off, 40 cols
    sta VIC_CTRL2

    // Check if we need to shift characters
    lda scroll_x
    cmp #$07
    bne !scrollerDone+

    // Shift all characters left
    ldx #$00
!shiftChars:
    lda SCREEN_RAM + (SCROLL_LINE * 40) + 1, x
    sta SCREEN_RAM + (SCROLL_LINE * 40), x
    inx
    cpx #39
    bne !shiftChars-

    // Get next character from text
    ldx text_ptr
    lda scroll_text, x
    bne !storeChar+
    // Reset to beginning
    ldx #$00
    stx text_ptr
    lda scroll_text
!storeChar:
    sta SCREEN_RAM + (SCROLL_LINE * 40) + 39
    inc text_ptr

!scrollerDone:
    rts

//------------------------------------------------------------------------------
// UpdateStarfield: Parallax scrolling star effect
//------------------------------------------------------------------------------
UpdateStarfield:
    inc star_phase

    ldx #NUM_STARS - 1
!updateStarLoop:
    // Check if it's time to move this star
    lda star_phase
    and star_speed, x
    bne !skipStarMove+

    // Erase old star
    lda star_y, x
    tay
    lda row_lo, y
    sta ptr1
    lda row_hi, y
    sta ptr1_hi
    ldy star_x, x
    lda #SC_SPACE
    sta (ptr1), y

    // Move star left
    dec star_x, x
    bpl !drawStar+

    // Star went off screen - wrap to right
    lda #39
    sta star_x, x

    // New pseudo-random Y position
    lda star_phase
    eor star_y, x
    and #$0F
    clc
    adc #STAR_AREA_START
    cmp #STAR_AREA_END
    bcc !newYOk+
    lda #STAR_AREA_START
!newYOk:
    sta star_y, x

!drawStar:
    // Draw star at new position
    lda star_y, x
    tay
    lda row_lo, y
    sta ptr1
    lda row_hi, y
    sta ptr1_hi
    ldy star_x, x
    lda star_char, x
    sta (ptr1), y

    // Set star color based on speed
    lda star_y, x
    tay
    lda row_lo_color, y
    sta ptr2
    lda row_hi_color, y
    sta ptr2_hi
    lda star_speed, x
    tay
    lda star_colors, y
    ldy star_x, x
    sta (ptr2), y

!skipStarMove:
    dex
    bpl !updateStarLoop-
    rts

//------------------------------------------------------------------------------
// UpdateTextColors: Rainbow color cycling effect
//------------------------------------------------------------------------------
UpdateTextColors:
    // Only update every 4 frames
    lda frame_count
    and #$03
    bne !colorsDone+

    inc color_offset

    ldx #39
!colorLoop:
    txa
    clc
    adc color_offset
    and #$0F
    tay
    lda rainbow_colors, y
    sta COLOR_RAM + (SCROLL_LINE * 40), x
    dex
    bpl !colorLoop-

!colorsDone:
    rts

//==============================================================================
// DATA TABLES
//==============================================================================

// Raster bar colors
raster_colors:
    .byte COLOR_BROWN, COLOR_RED, COLOR_ORANGE, COLOR_LIGHT_RED
    .byte COLOR_YELLOW, COLOR_WHITE, COLOR_YELLOW, COLOR_LIGHT_RED
    .byte COLOR_ORANGE, COLOR_RED, COLOR_BROWN, COLOR_BLACK
    .byte COLOR_BLACK, COLOR_BLACK, COLOR_BLACK, COLOR_BLACK

// Star characters (different densities)
star_chars:
    .byte $2E                       // .
    .byte $51                       // Filled circle
    .byte $2A                       // *
    .byte $51                       // Filled circle

// Star colors by speed (slower = dimmer)
star_colors:
    .byte COLOR_BLACK               // Not used (speed 0)
    .byte COLOR_DARK_GREY           // Slow
    .byte COLOR_GREY                // Medium
    .byte COLOR_LIGHT_GREY          // Fast
    .byte COLOR_WHITE               // Fastest

// Rainbow color table
rainbow_colors:
    .byte COLOR_RED, COLOR_ORANGE, COLOR_YELLOW, COLOR_GREEN
    .byte COLOR_LIGHT_GREEN, COLOR_CYAN, COLOR_LIGHT_BLUE, COLOR_PURPLE
    .byte COLOR_BLUE, COLOR_PURPLE, COLOR_LIGHT_BLUE, COLOR_CYAN
    .byte COLOR_LIGHT_GREEN, COLOR_GREEN, COLOR_YELLOW, COLOR_ORANGE

// Bounce sine table - 256 entries, values 0-7 for Y-scroll
// Creates a gentle up/down bouncing motion
bounce_table:
    .fill 256, 3 + round(2.5 * sin(toRadians(i * 360 / 64)))

// Screen row address tables (low bytes)
row_lo:
    .byte <(SCREEN_RAM + 0*40), <(SCREEN_RAM + 1*40), <(SCREEN_RAM + 2*40)
    .byte <(SCREEN_RAM + 3*40), <(SCREEN_RAM + 4*40), <(SCREEN_RAM + 5*40)
    .byte <(SCREEN_RAM + 6*40), <(SCREEN_RAM + 7*40), <(SCREEN_RAM + 8*40)
    .byte <(SCREEN_RAM + 9*40), <(SCREEN_RAM + 10*40), <(SCREEN_RAM + 11*40)
    .byte <(SCREEN_RAM + 12*40), <(SCREEN_RAM + 13*40), <(SCREEN_RAM + 14*40)
    .byte <(SCREEN_RAM + 15*40), <(SCREEN_RAM + 16*40), <(SCREEN_RAM + 17*40)
    .byte <(SCREEN_RAM + 18*40), <(SCREEN_RAM + 19*40), <(SCREEN_RAM + 20*40)
    .byte <(SCREEN_RAM + 21*40), <(SCREEN_RAM + 22*40), <(SCREEN_RAM + 23*40)
    .byte <(SCREEN_RAM + 24*40)

// Screen row address tables (high bytes)
row_hi:
    .byte >(SCREEN_RAM + 0*40), >(SCREEN_RAM + 1*40), >(SCREEN_RAM + 2*40)
    .byte >(SCREEN_RAM + 3*40), >(SCREEN_RAM + 4*40), >(SCREEN_RAM + 5*40)
    .byte >(SCREEN_RAM + 6*40), >(SCREEN_RAM + 7*40), >(SCREEN_RAM + 8*40)
    .byte >(SCREEN_RAM + 9*40), >(SCREEN_RAM + 10*40), >(SCREEN_RAM + 11*40)
    .byte >(SCREEN_RAM + 12*40), >(SCREEN_RAM + 13*40), >(SCREEN_RAM + 14*40)
    .byte >(SCREEN_RAM + 15*40), >(SCREEN_RAM + 16*40), >(SCREEN_RAM + 17*40)
    .byte >(SCREEN_RAM + 18*40), >(SCREEN_RAM + 19*40), >(SCREEN_RAM + 20*40)
    .byte >(SCREEN_RAM + 21*40), >(SCREEN_RAM + 22*40), >(SCREEN_RAM + 23*40)
    .byte >(SCREEN_RAM + 24*40)

// Color RAM row address tables (low bytes)
row_lo_color:
    .byte <(COLOR_RAM + 0*40), <(COLOR_RAM + 1*40), <(COLOR_RAM + 2*40)
    .byte <(COLOR_RAM + 3*40), <(COLOR_RAM + 4*40), <(COLOR_RAM + 5*40)
    .byte <(COLOR_RAM + 6*40), <(COLOR_RAM + 7*40), <(COLOR_RAM + 8*40)
    .byte <(COLOR_RAM + 9*40), <(COLOR_RAM + 10*40), <(COLOR_RAM + 11*40)
    .byte <(COLOR_RAM + 12*40), <(COLOR_RAM + 13*40), <(COLOR_RAM + 14*40)
    .byte <(COLOR_RAM + 15*40), <(COLOR_RAM + 16*40), <(COLOR_RAM + 17*40)
    .byte <(COLOR_RAM + 18*40), <(COLOR_RAM + 19*40), <(COLOR_RAM + 20*40)
    .byte <(COLOR_RAM + 21*40), <(COLOR_RAM + 22*40), <(COLOR_RAM + 23*40)
    .byte <(COLOR_RAM + 24*40)

// Color RAM row address tables (high bytes)
row_hi_color:
    .byte >(COLOR_RAM + 0*40), >(COLOR_RAM + 1*40), >(COLOR_RAM + 2*40)
    .byte >(COLOR_RAM + 3*40), >(COLOR_RAM + 4*40), >(COLOR_RAM + 5*40)
    .byte >(COLOR_RAM + 6*40), >(COLOR_RAM + 7*40), >(COLOR_RAM + 8*40)
    .byte >(COLOR_RAM + 9*40), >(COLOR_RAM + 10*40), >(COLOR_RAM + 11*40)
    .byte >(COLOR_RAM + 12*40), >(COLOR_RAM + 13*40), >(COLOR_RAM + 14*40)
    .byte >(COLOR_RAM + 15*40), >(COLOR_RAM + 16*40), >(COLOR_RAM + 17*40)
    .byte >(COLOR_RAM + 18*40), >(COLOR_RAM + 19*40), >(COLOR_RAM + 20*40)
    .byte >(COLOR_RAM + 21*40), >(COLOR_RAM + 22*40), >(COLOR_RAM + 23*40)
    .byte >(COLOR_RAM + 24*40)

//==============================================================================
// STAR DATA
//==============================================================================

star_x:
    .fill NUM_STARS, 0
star_y:
    .fill NUM_STARS, 0
star_speed:
    .fill NUM_STARS, 0
star_char:
    .fill NUM_STARS, 0

//==============================================================================
// SCROLL TEXT
//==============================================================================

scroll_text:
    // Using screen codes (not PETSCII) for direct screen RAM output
    .text "    welcome to the enhanced scroller demo!   "
    .text "featuring: parallax starfield ... rainbow color cycling text ... "
    .text "raster bar effects ... all classic c64 demo tricks!   "
    .text "greetings to all c64 fans around the world!   "
    .text "this demo was created with kickassembler.   "
    .text "now using c64-standards library for clean code!   "
    .text "                    "
    .byte $00
