// plasma_190 - a 190-byte size-coded character plasma (the original that
// demos/plasma/main.asm grew from). Kept as a reference; not auto-built.
// KickAssembler syntax. Build into a scratch dir if you want the .prg:
//   python3 ~/.claude/skills/c64-toolchain/scripts/c64.py build plasma_190.asm --odir /tmp/x
//
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
