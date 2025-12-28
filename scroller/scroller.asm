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
// Load SID music file
//------------------------------------------------------------------------------
.var music = LoadSid("Nightshift.sid")

//------------------------------------------------------------------------------
// BASIC Loader - Using KickAssembler built-in
//------------------------------------------------------------------------------
BasicUpstart2(Start)

//==============================================================================
// CONSTANTS
//==============================================================================

//------------------------------------------------------------------------------
// WAVE CONFIGURATION - Change WAVE_ROWS to adjust wave amplitude (2-8)
//------------------------------------------------------------------------------
.const WAVE_ROWS        = 6           // Number of rows for wave effect (2-8)
                                      // 2 = subtle wave, 8 = dramatic wave

.label WAVE_TOP_ROW     = 25 - WAVE_ROWS  // Top row of wave area (calculated)
.label WAVE_MASK        = WAVE_ROWS - 1   // Mask for row offset (must be power of 2 - 1)
.label STAR_AREA_START  = 3               // Row where stars begin
.label STAR_AREA_END    = WAVE_TOP_ROW - 1  // Row where stars end (above wave)
.label NUM_STARS        = 24              // Number of stars

//==============================================================================
// ZERO PAGE VARIABLES
// Using standard library zero page allocation
//==============================================================================

.label text_ptr         = zp_free_1   // $02 - Scroll text pointer
.label star_phase       = temp1       // $E7 - Star animation phase
.label color_offset     = temp2       // $E8 - Rainbow color offset
.label raster_color     = temp3       // $E9 - Raster bar color index
.label bounce_index     = temp4       // $EA - Bounce sine table index
.label wave_phase       = loop_i      // $EB - Wave animation phase

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
    sta wave_phase

    // Clear screen
    jsr ClearScreenRam

    // Initialize stars
    jsr InitStars

    // Initialize scroll text colors
    jsr InitTextColors

    // Initialize SID music
    lda #music.startSong - 1
    ldx #0
    ldy #0
    jsr music.init

    // Set up raster IRQ for music playback
    lda #<IrqHandler
    sta $0314
    lda #>IrqHandler
    sta $0315

    lda #$80                        // Raster line for IRQ
    sta VIC_RASTER
    lda VIC_CTRL1
    and #$7F                        // Clear raster bit 8
    sta VIC_CTRL1

    lda #$7F                        // Disable CIA interrupts
    sta $DC0D
    sta $DD0D
    lda $DC0D                       // Acknowledge pending
    lda $DD0D

    lda #$01                        // Enable raster IRQ
    sta VIC_IRQ_ENABLE
    asl VIC_IRQ_STATUS              // Acknowledge any pending

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

//------------------------------------------------------------------------------
// IrqHandler: Raster interrupt for SID music playback
//------------------------------------------------------------------------------
IrqHandler:
    asl VIC_IRQ_STATUS              // Acknowledge raster IRQ
    jsr music.play                  // Play music
    jmp $EA81                       // Return from interrupt

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
// InitTextColors: Initialize rainbow colors for all wave rows
//------------------------------------------------------------------------------
InitTextColors:
    ldx #39
!initColorLoop:
    txa
    and #$0F
    tay
    lda rainbow_colors, y
    // Initialize colors for all wave rows (generated based on WAVE_ROWS)
    .for (var row = 0; row < WAVE_ROWS; row++) {
        sta COLOR_RAM + ((WAVE_TOP_ROW + row) * 40), x
    }
    dex
    bpl !initColorLoop-
    rts

//------------------------------------------------------------------------------
// UpdateScroller: Handle horizontal scrolling text with wave + bounce effect
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

    // Update wave phase (controls wave animation speed)
    inc wave_phase
    inc wave_phase                  // Wave moves faster than scroll

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
    bne !doWave+

    // Shift the text buffer left
    ldx #$00
!shiftBuffer:
    lda text_buffer + 1, x
    sta text_buffer, x
    inx
    cpx #39
    bne !shiftBuffer-

    // Get next character from text
    ldx text_ptr
    lda scroll_text, x
    bne !storeChar+
    // Reset to beginning
    ldx #$00
    stx text_ptr
    lda scroll_text
!storeChar:
    sta text_buffer + 39
    inc text_ptr

!doWave:
    // Now draw the wavy text from buffer to screen
    jsr DrawWavyText
    rts

//------------------------------------------------------------------------------
// DrawWavyText: Draw text buffer with sine wave vertical displacement
//------------------------------------------------------------------------------
DrawWavyText:
    // First clear all wave rows (generated based on WAVE_ROWS)
    lda #SC_SPACE
    ldx #39
!clearWaveRows:
    .for (var row = 0; row < WAVE_ROWS; row++) {
        sta SCREEN_RAM + ((WAVE_TOP_ROW + row) * 40), x
    }
    dex
    bpl !clearWaveRows-

    // Draw each character at its wave position
    ldx #39                         // Column counter (right to left)
!drawWaveLoop:
    // Calculate wave table index for this column
    // index = wave_phase + (column * 4) for wave frequency
    txa
    asl
    asl                             // x * 4 for wave frequency
    clc
    adc wave_phase
    tay                             // Y = index into wave table

    // Get row offset from wave table
    lda wave_table, y
    and #WAVE_MASK                  // Ensure 0 to WAVE_ROWS-1 range

    // Calculate screen address for this row
    tay                             // Y = row offset (0-3)
    lda wave_row_lo, y
    sta ptr1
    lda wave_row_hi, y
    sta ptr1_hi

    // Also set up color RAM
    lda wave_color_lo, y
    sta ptr2
    lda wave_color_hi, y
    sta ptr2_hi

    // Get character from buffer and draw it
    lda text_buffer, x
    ldy #0
    // Use X as offset since we're drawing column X
    stx temp_x
    txa
    tay
    lda text_buffer, x
    sta (ptr1), y

    // Set rainbow color for this position
    txa
    clc
    adc color_offset
    and #$0F
    tay
    lda rainbow_colors, y
    ldx temp_x
    tay
    // Y now has the column, need to reload color
    lda temp_x
    clc
    adc color_offset
    and #$0F
    tay
    lda rainbow_colors, y
    ldy temp_x
    sta (ptr2), y

    ldx temp_x
    dex
    bpl !drawWaveLoop-

    rts

// Temp storage for X during wave drawing
temp_x: .byte 0

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
// UpdateTextColors: Rainbow color cycling effect for all wave rows
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
    // Update colors for all wave rows (generated based on WAVE_ROWS)
    .for (var row = 0; row < WAVE_ROWS; row++) {
        sta COLOR_RAM + ((WAVE_TOP_ROW + row) * 40), x
    }
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

// Wave sine table - 256 entries, values 0 to WAVE_ROWS-1 for row offset
// Creates the undulating wave effect for text
wave_table:
    .fill 256, round((WAVE_ROWS-1)/2.0 + (WAVE_ROWS-1)/2.0 * sin(toRadians(i * 360 / 32)))

// Wave row screen address tables (generated for WAVE_ROWS rows)
wave_row_lo:
    .for (var row = 0; row < WAVE_ROWS; row++) {
        .byte <(SCREEN_RAM + ((WAVE_TOP_ROW + row) * 40))
    }

wave_row_hi:
    .for (var row = 0; row < WAVE_ROWS; row++) {
        .byte >(SCREEN_RAM + ((WAVE_TOP_ROW + row) * 40))
    }

// Wave row color RAM address tables (generated for WAVE_ROWS rows)
wave_color_lo:
    .for (var row = 0; row < WAVE_ROWS; row++) {
        .byte <(COLOR_RAM + ((WAVE_TOP_ROW + row) * 40))
    }

wave_color_hi:
    .for (var row = 0; row < WAVE_ROWS; row++) {
        .byte >(COLOR_RAM + ((WAVE_TOP_ROW + row) * 40))
    }

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

// Text buffer for wavy scroller (40 characters)
text_buffer:
    .fill 40, SC_SPACE

//==============================================================================
// SCROLL TEXT
//==============================================================================

scroll_text:
    // Using screen codes (not PETSCII) for direct screen RAM output
    .text "    welcome to the enhanced scroller demo!   "
    .text "featuring: parallax starfield ... wavy bouncy text ... "
    .text "rainbow color cycling ... raster bar effects ... "
    .text "and music by "
    .text music.author
    .text " ... all classic c64 demo tricks!   "
    .text "greetings to all c64 fans around the world!   "
    .text "this demo was created with kickassembler.   "
    .text "now using c64-standards library for clean code!   "
    .text "                    "
    .byte $00

//==============================================================================
// SID MUSIC DATA
//==============================================================================

* = music.location "Music"
.fill music.size, music.getData(i)

// Print music info during assembly
.print ""
.print "SID Data"
.print "--------"
.print "location=$"+toHexString(music.location)
.print "init=$"+toHexString(music.init)
.print "play=$"+toHexString(music.play)
.print "name="+music.name
.print "author="+music.author
