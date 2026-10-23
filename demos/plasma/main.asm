// PLASMA - a very multi-colour 40x25 character plasma for the Commodore 64
// by RetroDubTRVA. KickAssembler v5.x.
//
// Build: python3 ~/.claude/skills/c64-toolchain/scripts/c64.py build main.asm
// Run:   python3 ~/.claude/skills/c64-toolchain/scripts/c64.py run bin/main.prg
//
// Grew out of plasma_190, a 190-byte size-coded plasma that drew four
// shades of one colour; its annotated source is the appendix at the end
// of this file. This version keeps the idea -
// a separable plasma, value = column_wave[x] + row_wave[y], looked up through
// a table - and layers three colour sources on top of each other:
//
//   1. SCREEN RAM   16 ordered-dither characters (0 = empty .. 15 = solid),
//                   chosen by plasma A. Redrawn on even frames.
//   2. COLOUR RAM   the character's colour, taken from a 16-entry palette that
//                   loops smoothly through all 16 C64 colours, chosen by
//                   plasma B (different waves, speeds and directions). Redrawn
//                   on odd frames. Because the dither mixes this colour with
//                   the background, the two plasmas interfere and the result no
//                   longer looks separable.
//   3. BACKGROUND   $D021 changes on every character row from a rolling
//                   gradient of dark colours: 25 raster IRQs a frame, each
//                   waiting for cycle 0 of the row's first line so the write
//                   lands in the left border, before the badline stall.
//
// Speed. Each plasma layer is one fully unrolled routine: for every column
// "ldy #value" (patched each frame with column_wave[x]) and then, for the 25
// rows, "lda (row_pointer),y / sta cell". Each row pointer is lut + row_wave[y],
// so the table lookup and the addition cost nothing extra: 9 cycles per cell,
// 9080 cycles for 1000 cells. Waves are kept in 0..127 so pointer + Y never
// crosses a page. Per frame on NTSC (17095 cycles): ~9.1k layer + ~1.5k wave
// setup + ~2.7k raster IRQs + ~1k badlines = ~14.3k. The zero-page byte
// `overrun` counts frames that took longer than a frame; it stays at 0.
//
// Platform: NTSC first (263 lines, 65 cycles), PAL works too. On PAL the
// waves get an extra step every fifth frame (6 steps per 5 frames) so the
// animation moves at the same speed. Sprites must stay off: the raster
// IRQ's timing margin assumes no sprite DMA.
//
// Memory:
//   $02-$11      zero page variables (see below)
//   $40-$71      25 row pointers for the unrolled layer code
//   $0400        screen (VIC bank 0), $d800 colour RAM
//   $0810-       code and the IRQ handler
//   $1800-$1eff  tables: four sine tables, two lookup tables, background
//                gradient. CPU-only RAM: the VIC sees character ROM here.
//   $2000-$207f  the 16 dither characters ($d018 = $18)
//   $2800-$4fb1  the two unrolled layer routines (2 x 5081 bytes)
//
// Keys: RUN/STOP exits through the KERNAL reset vector.

//------------------------------------------------------------------
// Hardware
//------------------------------------------------------------------
.label VIC_CONTROL1   = $d011
.label VIC_RASTER     = $d012
.label VIC_SPRITE_ON  = $d015
.label VIC_CONTROL2   = $d016
.label VIC_MEMORY     = $d018
.label VIC_IRQ_STATUS = $d019
.label VIC_IRQ_ENABLE = $d01a
.label BORDER         = $d020
.label BACKGROUND     = $d021
.label SID            = $d400
.label COLOR_RAM      = $d800
.label CIA1_PRA       = $dc00
.label CIA1_PRB       = $dc01
.label CIA1_DDRA      = $dc02
.label CIA1_DDRB      = $dc03
.label CIA1_ICR       = $dc0d
.label CIA2_ICR       = $dd0d
.label NMI_VECTOR     = $0318
.label SCREEN         = $0400

//------------------------------------------------------------------
// Zero page
//------------------------------------------------------------------
.label ntsc        = $02        // 1 on an NTSC VIC, 0 on PAL
.label frame       = $03        // frame counter; bit 0 picks the layer
.label frame_flag  = $04        // set by the last row IRQ, cleared by wait_frame
.label overrun     = $05        // frames the main loop missed (diagnostic)
.label pal_tick    = $06        // PAL only: every 6th frame steps the waves twice
.label line_poll   = $07        // IRQ: first raster line of the row being set up
.label bg_idx      = $08        // IRQ: index into bg_gradient for that row
.label bg_phase    = $09        // bg_idx at row 0; scrolls the gradient
// Wave phases. Each layer sums two sine tables along the columns and two
// along the rows; the phase is where the table is read for column/row 0.
.label ph_c1a      = $0a
.label ph_c1b      = $0b
.label ph_r1a      = $0c
.label ph_r1b      = $0d
.label ph_c2a      = $0e
.label ph_c2b      = $0f
.label ph_r2a      = $10
.label ph_r2b      = $11

.label row_ptr     = $40        // 25 pointers, $40-$71: lut + row_wave[y]

//------------------------------------------------------------------
// Tuning
//------------------------------------------------------------------
.const ROWS        = 25
.const COLS        = 40
.const FIRST_LINE  = 51         // raster line of the first pixel row (yscroll 3)
.const LAST_POLL   = FIRST_LINE + 8 * ROWS       // 251: past the last row
.const BG_ROW_STEP = 6          // gradient index step per character row
.const BG_SPEED    = 2          // gradient scroll per frame

// Phase speeds per frame (two's complement for backwards)
.const SPD_C1A = 2
.const SPD_C1B = -3
.const SPD_R1A = 1
.const SPD_R1B = 2
.const SPD_C2A = 3
.const SPD_C2B = 1
.const SPD_R2A = -2
.const SPD_R2B = 1

// Bytes per column in the unrolled layer code: ldy #imm + 25 x (lda (zp),y + sta abs)
.const COL_STRIDE = 2 + ROWS * 5

BasicUpstart2(start)

//==================================================================
// Code
//==================================================================
* = $0810 "Code"
start:
    sei
    ldx #$ff
    txs
    cld

    lda #$7f                    // CIA 2: mask NMI sources, ack pending
    sta CIA2_ICR
    lda CIA2_ICR
    lda #$7f                    // CIA 1: mask timer IRQs, ack pending
    sta CIA1_ICR
    lda CIA1_ICR

    // RESTORE is wired straight to /NMI. While the KERNAL is still banked in
    // its handler jumps through $0318; nmi_ignore sits at $xx47 like the
    // default $fe47 so one store flips the vector atomically.
    lda NMI_VECTOR
    cmp #<nmi_ignore
    beq !+
    lda #<nmi_ignore
    sta NMI_VECTOR
!:  lda #>nmi_ignore
    sta NMI_VECTOR + 1

    lda #$ff                    // keyboard: port A drives rows,
    sta CIA1_DDRA
    lda #$00                    // port B reads columns
    sta CIA1_DDRB

    jsr detect_video

    // Hardware vectors: writes under the ROM land in RAM, then bank the
    // BASIC and KERNAL ROMs out so IRQs come straight to irq_row.
    lda #<nmi_ignore
    sta $fffa
    lda #>nmi_ignore
    sta $fffb
    lda #<irq_row
    sta $fffe
    lda #>irq_row
    sta $ffff
    lda #$35
    sta $01

    // Video: hires text, 25 rows, screen $0400, charset $2000, black
    lda #$1b
    sta VIC_CONTROL1
    lda #$c8
    sta VIC_CONTROL2
    lda #$18
    sta VIC_MEMORY
    lda #$00
    sta BORDER
    sta BACKGROUND
    sta VIC_SPRITE_ON
    jsr clear_screen

    // Variables
    lda #$00
    sta frame
    sta frame_flag
    sta overrun
    sta pal_tick
    sta bg_phase
    sta bg_idx
    ldx #ph_r2b - ph_c1a
!:  sta ph_c1a, x               // all phases start at 0
    dex
    bpl !-
    lda #>lut_char              // layer 1 row pointers: high bytes never change
    jsr set_row_ptr_hi          // (layer 2 sets its own before drawing)

    // Raster IRQ: fire one line above each character row
    lda #FIRST_LINE
    sta line_poll
    lda #FIRST_LINE - 1
    sta VIC_RASTER
    lda VIC_CONTROL1
    and #$7f                    // raster compare bit 8 = 0
    sta VIC_CONTROL1
    lda #$ff
    sta VIC_IRQ_STATUS          // ack anything pending
    lda #$01
    sta VIC_IRQ_ENABLE
    cli

//------------------------------------------------------------------
// Main loop: one layer per frame
//------------------------------------------------------------------
main_loop:
    jsr wait_frame
    jsr check_exit
    inc frame
    jsr advance_phases
    lda ntsc
    bne !+
    inc pal_tick                // PAL: 50 frames a second, so step
    lda pal_tick                // the waves a 6th time every 5 frames
    cmp #5
    bcc !+
    lda #$00
    sta pal_tick
    jsr advance_phases
!:  lda frame
    and #$01
    bne !+
    jsr draw_char_layer
    jmp main_loop
!:  jsr draw_color_layer
    jmp main_loop

//------------------------------------------------------------------
// wait_frame - block until the row-24 IRQ has set frame_flag.
// If it was set more than once we were late; count it. The read and
// clear are done with IRQs off so a late flag cannot slip in between
// (the next IRQ is at line 50, a long way off).
//------------------------------------------------------------------
wait_frame:
    lda frame_flag
    beq wait_frame
    sei
    lda frame_flag
    cmp #$02
    bcc !+
    inc overrun
!:  lda #$00
    sta frame_flag
    cli
    rts

//------------------------------------------------------------------
// advance_phases - move every wave by its speed
//------------------------------------------------------------------
advance_phases:
    lda ph_c1a
    clc
    adc #SPD_C1A
    sta ph_c1a
    lda ph_c1b
    clc
    adc #SPD_C1B
    sta ph_c1b
    lda ph_r1a
    clc
    adc #SPD_R1A
    sta ph_r1a
    lda ph_r1b
    clc
    adc #SPD_R1B
    sta ph_r1b
    lda ph_c2a
    clc
    adc #SPD_C2A
    sta ph_c2a
    lda ph_c2b
    clc
    adc #SPD_C2B
    sta ph_c2b
    lda ph_r2a
    clc
    adc #SPD_R2A
    sta ph_r2a
    lda ph_r2b
    clc
    adc #SPD_R2B
    sta ph_r2b
    lda bg_phase
    clc
    adc #BG_SPEED
    sta bg_phase
    rts

//------------------------------------------------------------------
// set_row_ptr_hi - A = high byte of the lookup table for this layer
//------------------------------------------------------------------
set_row_ptr_hi:
    .for (var r = 0; r < ROWS; r++) {
        sta row_ptr + r * 2 + 1
    }
    rts

//------------------------------------------------------------------
// Wave setup macros. Both read two sine tables with X and Y walking
// up from the phase, average them (result 0..127) and store.
//------------------------------------------------------------------
// Row waves go into the low bytes of the 25 row pointers.
.macro RowWaves(sinA, sinB) {
    .for (var r = 0; r < ROWS; r++) {
        lda sinA, x
        clc
        adc sinB, y
        lsr
        sta row_ptr + r * 2
        inx
        iny
    }
}
// Column waves are patched into the "ldy #" of each unrolled column.
.macro ColWaves(sinA, sinB, code) {
    .for (var c = 0; c < COLS; c++) {
        lda sinA, x
        clc
        adc sinB, y
        lsr
        sta code + c * COL_STRIDE + 1
        inx
        iny
    }
}

//------------------------------------------------------------------
// draw_char_layer - plasma A -> dither characters in screen RAM
//------------------------------------------------------------------
draw_char_layer:
    lda #>lut_char
    jsr set_row_ptr_hi
    ldx ph_r1a
    ldy ph_r1b
    RowWaves(sin7, sin2)
    ldx ph_c1a
    ldy ph_c1b
    ColWaves(sin3, sin5, char_code)
    jmp char_code

//------------------------------------------------------------------
// draw_color_layer - plasma B -> palette colours in colour RAM
//------------------------------------------------------------------
draw_color_layer:
    lda #>lut_color
    jsr set_row_ptr_hi
    ldx ph_r2a
    ldy ph_r2b
    RowWaves(sin5, sin3)
    ldx ph_c2a
    ldy ph_c2b
    ColWaves(sin2, sin7, color_code)
    jmp color_code

//------------------------------------------------------------------
// irq_row - raster IRQ, one line above every character row.
// Sets $d021 for the row in the left border of its first line, which
// is a badline. The poll below is a 7-cycle loop whose read of $d012
// lands in cycles 0-6 after the line changes, so the sta's three
// reads happen in cycles 3-11 and its write in cycle 6-12. On a
// badline BA drops at cycle 12 and the CPU stalls on its first read
// from cycle 15 (three cycles of grace); the write cycle is never
// stalled, and pixels start at cycle ~17. The loop must not cross a
// page (checked below) and sprites must stay off, or the margin is
// gone. Only A and X are used. The last row also resets for the next
// frame and raises frame_flag.
//------------------------------------------------------------------
irq_row:
    pha
    txa
    pha
    ldx bg_idx
    lda bg_gradient, x          // A = this row's background colour
    ldx line_poll               // X = the row's first raster line
poll:
    cpx VIC_RASTER
    bne poll
    .errorif (poll >> 8) != (* >> 8), "poll loop must not cross a page"
    sta BACKGROUND
    lda #$01
    sta VIC_IRQ_STATUS          // acknowledge
    lda bg_idx
    clc
    adc #BG_ROW_STEP
    sta bg_idx
    txa                         // next row, 8 lines down
    clc
    adc #$08
    cmp #LAST_POLL
    bcc !+
    lda bg_phase                // that was row 24: wrap to row 0
    sta bg_idx
    inc frame_flag
    lda #FIRST_LINE
!:  sta line_poll
    sec
    sbc #$01
    sta VIC_RASTER              // fire one line early, then poll
    pla
    tax
    pla
    rti

//------------------------------------------------------------------
// detect_video - ntsc = 1 on NTSC, 0 on PAL. Interrupts off.
// Keeps the highest raster low byte seen above line 255: NTSC tops
// out at $106, PAL at $137. (From the c64-demo-framework skill.)
//------------------------------------------------------------------
detect_video:
    lda #$00
    sta ntsc
!:  bit VIC_CONTROL1
    bmi !-                      // wait until below line 256
!wait:
    bit VIC_CONTROL1
    bpl !wait-                  // wait for line 256+
!track:
    lda VIC_RASTER
    cmp ntsc
    bcc !+
    sta ntsc
!:  bit VIC_CONTROL1
    bmi !track-                 // until the raster wraps to line 0
    lda ntsc
    ldx #$00
    cmp #$20
    bcs !+                      // PAL
    inx                         // NTSC
!:  stx ntsc
    rts

//------------------------------------------------------------------
// clear_screen - character 0 (empty) everywhere, colour 0
//------------------------------------------------------------------
clear_screen:
    lda #$00
    ldx #$00
!:  sta SCREEN, x
    sta SCREEN + $100, x
    sta SCREEN + $200, x
    sta SCREEN + $2e8, x
    sta COLOR_RAM, x
    sta COLOR_RAM + $100, x
    sta COLOR_RAM + $200, x
    sta COLOR_RAM + $2e8, x
    inx
    bne !-
    rts

//------------------------------------------------------------------
// check_exit - RUN/STOP (row 7, column bit 7, active low) quits
//------------------------------------------------------------------
check_exit:
    lda #$7f
    sta CIA1_PRA
    lda CIA1_PRB
    and #$80
    beq exit_demo
    lda #$ff
    sta CIA1_PRA
    rts

// BASIC's zero page is gone, so never rts: put the hardware back and go
// through the KERNAL RESET vector. No cli - $fffc does its own sei.
exit_demo:
    sei
    lda #$00
    sta VIC_IRQ_ENABLE
    ldx #$18
!:  sta SID, x
    dex
    bpl !-
    sta VIC_SPRITE_ON
    lda #$1b
    sta VIC_CONTROL1
    lda #$2f
    sta $00
    lda #$37                    // ROMs back in
    sta $01
    lda #$ff
    sta CIA1_PRA
    jmp ($fffc)

// nmi_ignore must share its low byte with the KERNAL default ($fe47)
    .fill ($47 - <*) & $ff, 0
nmi_ignore:
    .errorif (nmi_ignore & $ff) != $47, "nmi_ignore must sit at $xx47"
    rti

//==================================================================
// Tables, one page each. $1000-$1fff is RAM to the CPU but character
// ROM to the VIC in bank 0, so it costs no graphics memory.
//==================================================================
    .errorif * > $1800, "code overruns the tables at $1800"

* = $1800 "Tables"

// Sine tables, amplitude 0..127, N cycles across the 256 entries. The
// number is the spatial frequency: sin3 over 40 columns is about half
// a wave, sin7 over 25 rows about two thirds.
.macro SineTable(cycles) {
    .fill 256, round(63.5 + 63.5 * sin(toRadians(i * cycles * 360 / 256)))
}
sin2:   SineTable(2)
sin3:   SineTable(3)
sin5:   SineTable(5)
sin7:   SineTable(7)

// Plasma value (0..254) -> dither character 3..15, four waves across
// the range so the bands fold back on themselves. Never below 3, so
// the colour layer always shows through and the background only tints.
lut_char:
    .fill 256, round(9 + 6 * sin(toRadians(i * 4 * 360 / 256)))

// Plasma value -> colour. The palette is a hue wheel, blue -> cyan ->
// green -> yellow -> white -> red -> purple -> blue, so neighbours
// blend; the range walks round it five times. No black or grey: the
// dark tones come from the dither and the background.
.var palette = List().add($06, $0e, $03, $03, $0d, $05, $07, $01,
                          $01, $0a, $08, $02, $02, $09, $04, $04)
lut_color:
    .errorif (lut_char & $ff) != 0 || (lut_color & $ff) != 0, "lookup tables must be page aligned"
    .fill 256, palette.get(((i * 5) >> 4) & 15)

// Background gradient for the raster rows: dark colours up and down a
// sine, read every BG_ROW_STEP entries per row and scrolled by bg_phase.
.var bg_palette = List().add($00, $00, $00, $0b, $0b, $06, $0b, $0b)
bg_gradient:
    .fill 256, bg_palette.get(floor((0.5 + 0.5 * sin(toRadians(i * 360 / 256))) * 7.99))

//==================================================================
// Charset: 16 ordered-dither levels from a 4x4 Bayer matrix, tiled.
// Level k lights every pixel whose threshold is below k*16/15, so
// level 0 is empty, level 8 a 50% checker, level 15 solid.
//==================================================================
* = $2000 "Charset"
.var bayer = List().add( 0,  8,  2, 10,
                        12,  4, 14,  6,
                         3, 11,  1,  9,
                        15,  7, 13,  5)
.for (var k = 0; k < 16; k++) {
    .for (var r = 0; r < 8; r++) {
        .var bits = 0
        .for (var x = 0; x < 8; x++) {
            .if (bayer.get(((r & 3) << 2) | (x & 3)) < floor(k * 16 / 15)) {
                .eval bits = bits | ($80 >> x)
            }
        }
        .byte bits
    }
}

//==================================================================
// Unrolled layer routines. Column by column: Y = column wave, then
// each row's cell = (row pointer),Y. The "ldy #" operand of column c
// is at code + c * COL_STRIDE + 1 and is patched by ColWaves.
//==================================================================
* = $2800 "Layer code"
.macro LayerCode(target) {
    .for (var c = 0; c < COLS; c++) {
        ldy #$00
        .for (var r = 0; r < ROWS; r++) {
            lda (row_ptr + r * 2), y
            sta target + r * COLS + c
        }
    }
    rts
}
char_code:
    LayerCode(SCREEN)
    .errorif (* - char_code) != COLS * COL_STRIDE + 1, "COL_STRIDE does not match the unrolled code"
color_code:
    LayerCode(COLOR_RAM)

/*
==================================================================
APPENDIX: plasma_190, the 190-byte original this demo grew from.
Reference only. It is not assembled here, because it loads at $0326
over the KERNAL vectors and starts through the CHROUT vector, which
cannot share a .prg with the BASIC-started program above. To build
it on its own, copy everything between the dashed lines into a file
of its own.
------------------------------------------------------------------

// HOW IT STARTS. There is no BASIC stub. The file loads at $0326, which is
// the KERNAL's CHROUT vector: the first two bytes ($2a $03) replace that
// vector with $032a, the real entry point. The moment the KERNAL prints
// anything after the load (the "READY." prompt), it jumps here and never
// returns. The bytes are written below as instructions (rol / slo) only
// because every byte must be code or the assembler needs .byte; they are
// never executed.
//
// WHAT IT DRAWS. Four shades of the current text colour: a plasma in which
// value = col_wave[x] + row_wave[y], folded through a lookup table into
// one of the characters 4-7, whose bitmaps are generated at start-up as
// bit patterns of rising density. The screen stays at $0400 but the
// charset moves to $3800 ($d018 = $1f), and it draws one frame after the
// other with no raster sync.
//
// MEMORY IT USES (all chosen to be reachable with one-byte addressing):
//   $20        row wave value for the row being drawn
//   $21        row counter 24..0
//   $24/$25    column-table seeds for this frame
//   $26/$27    phase accumulators, stepped every frame
//   $30-$4f    high bytes of the 25 screen-row addresses ($04..$07). The
//              same bytes double as the value->character table, because
//              $04..$07 are exactly the four generated characters.
//   $50-$6f    low bytes of the screen-row addresses
//   $80-$d0    81 column-wave values, filled backwards from $d0
//   $9000-$90ff a 256-entry "sine" (two mirrored ramps, built from the
//              charset generator's counters)
//   $3820-$385f the eight generated characters 4..11 (only 4..7 are shown)
//   $0396, $036d, $03c6/$03c7  self-modified operands inside the code

* = $0326
   rol                  // $2a  } CHROUT vector low/high = $032a: the entry
   slo ( $ed, x)        // $03 $ed: $ed is the old vector high byte's neighbour,
                        //         left so the STOP vector at $0328 stays sane
   inc $78, x           // $f6 $78: filler that lands in the STOP vector ($0328);
                        //         harmless, the demo never calls STOP

// ---------------------------------------------------------------- entry
// Build the sine at $9000 and the character bitmaps at $3820 in one pass.
// $61 is the ramp value, $63 the run length, $62 the run counter and $64
// a feedback accumulator that bends the ramp into a rough sine shape.
   lda #$05
   sta $63              // first run length
   lda #$1f
   sta $61              // ramp starts at $1f
   sta $d018            // screen $0400, charset $3800
   ldy #$3f             // 64 entries per quarter wave, counted down
   ldx #$00

label_033a:
   inc $61              // ramp up

label_033c:
   lda $63
   sta $62              // reload the run counter

label_0340:
   lda $61
   sta $9000, x         // quarter 1: rising ramp
   sta $90c0, y         // quarter 4: the same, mirrored in time
   eor #$ff
   sta $9080, x         // quarter 3: inverted
   sta $9040, y         // quarter 2: inverted and mirrored
   sta $3820, x         // charset row: a byte of the ramp as pixels, so
                        // each successive character has more bits set
   inx
   dey
   bmi label_036b       // 64 entries done
   dec $62
   bpl label_0340       // repeat the same value $62 times
   inc $61
   dec $63              // runs get shorter: the ramp accelerates
   clc
   lda $64
   adc $63
   asl
   sta $64              // feedback; carry/zero decide how to continue
   bcs label_033c
   bne label_033a

// ---------------------------------------------------------------- row tables
// 32 entries of screen-row address high ($30-$4f) and low ($50-$6f)
// bytes: $0400, $0428, $0450 ... The high byte is bumped by patching the
// "lda #$04" operand whenever the low byte wraps.
label_036b:
   iny                  // Y = 0

label_036c:
   lda #$04             // operand at $036d, incremented on wrap
   sta $0030, y
   lda $fe
   sta $0050, y
   adc #$28             // next row is 40 bytes on
   cmp $fe
   sta $fe
   bcs label_0381       // no wrap
   inc $036d            // wrapped: next high byte

label_0381:
   iny
   cpy #$20
   bne label_036c

// ---------------------------------------------------------------- frame loop
// Column waves: 81 values at $d0 down to $80, each sine[x] + sine[y]
// with X stepping backwards through the sine and Y forwards. The store
// address is the "sta $80" operand at $0396, which is also the loop
// counter: it starts at $d0 and runs down to $80.
label_0386:
   ldy $24
   ldx $25
   lda #$d0
   sta $0396

label_038f:
   lda $9000, x
   adc $9000, y
   sta $80              // operand self-modified: $d0, $cf ... $80
   txa
   adc #$f9             // X -= 7 (plus carry), a second frequency
   tax
   iny
   dec $0396
   bmi label_038f

// Draw 25 rows, bottom to top. For each cell: (col_wave + row_wave) / 8
// gives 0..31, which indexes the $30-$4f table, whose bytes $04..$07 are
// the character numbers. The row's wave value is col_wave[$b0 + row].
   lda #$18
   sta $21

label_03a5:
   ldy $21
   lda $00b0, y
   sta $20              // row wave
   lda $0030, y
   sta $03c7            // patch the sta below: screen row high
   lda $0050, y
   sta $03c6            //                     screen row low
   ldx #$27

label_03ba:
   lda $80, x
   adc $20
   lsr
   lsr
   lsr
   tay
   lda $0030, y         // value -> character 4..7
   sta $1e00, x         // operand patched to the screen row
   dex
   bpl label_03ba
   dec $21
   bpl label_03a5

// Advance the two phases at different speeds and go again.
   lda $26
   adc #$03
   sta $26
   sta $24
   lda $27
   adc #$01
   sta $27
   sta $25
   jmp label_0386

------------------------------------------------------------------
*/
