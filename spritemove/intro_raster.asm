//==================================================================
// INTRO_RASTER - the raster bar overture
//
// Imported by main.asm into spare RAM at $6b00. Not buildable on its
// own: it uses main.asm's register labels, row_offset_lo/hi, check_exit
// and the sine table intro_sprites.asm generates at $6600.
//
// WHAT IT IS
// ----------
// The demo now opens with this, in plain text mode, with
// eight raster bars flying over a black screen while the handle and five
// labels arrive one at a time. Then it hands over to intro.asm: the
// title labels on black, then vertical bars, then a fade to black.
//
// HOW A BAR IS DRAWN
// ------------------
// There is no per-cell work here at all. Everything is one byte per
// RASTER LINE in a page-aligned buffer:
//
//     RB_BUF[line] = the colour $d020 and $d021 should hold on that line
//
// A frame is then two halves that never overlap:
//
//   rb_show   from line 56 to line 250, wait for each line and write its
//             byte to BOTH the border and the background. In text mode
//             $d021 is the paper the characters sit on, so one write
//             stripes the border and the screen together and the bars
//             pass BEHIND the letters.
//   the rest  everything else - music, keyboard, the bar movement and the
//             rebuild of the buffer - happens between line 250 and line 56
//             of the next frame, i.e. in the ~117 lines the display is not
//             using. That is about 7300 cycles and the budget below is
//             built to fit inside it.
//
// The wait loop is `cpy $d012 / bne`, seven cycles, and a PAL line is 63 -
// exactly nine iterations. Because 63 divides by 7 the loop detects every
// line at the SAME cycle offset, so the bar edges line up down the screen
// instead of shearing.
//
// A badline is the one thing that upsets that: it halts the CPU for 40
// cycles, 40 does not divide by 7, and the loop comes out of it on a new
// phase. The detection offset therefore walks around a seven-cycle cycle
// as the screen goes down, and the write has to land early enough to be
// invisible at EVERY one of those seven offsets. Hence the shape of
// rs_line: the colour byte is loaded BEFORE the wait, so detection is
// followed by nothing but the two stores and $d020 has the new colour by
// cycle 8-14 of the line. Six of the seven offsets put that inside the
// horizontal blank, ahead of the visible left border; the seventh clips
// it by a couple of cycles and leaves a sliver of the previous line's
// colour in the border. Measured over ten consecutive PAL frames in VICE
// that is 8.5% of the lit lines, down from a solid eight-line staircase
// when the load sat after the wait instead of before it.
//
// (Measure it with `x64sc -pal`. This machine's vicerc defaults x64sc to
// NTSC, where the frame is 65 cycles a line over 263 lines and none of
// the numbers in this file apply.)
//
// Six is as good as this gets without a cycle-exact loop, and a cycle-
// exact loop needs a stable entry AND per-badline padding - at which
// point the loop has no slack left, and the first frame whose off-screen
// work runs a few cycles long desynchronises it for good. Tried; the
// screen went blank every third frame. The polling loop is self-healing
// by construction, which is worth more here than the last 8%.
//
// WHERE A BAR COMES FROM
// ----------------------
// Each of the eight bars is four bytes of state and nothing else:
//
//     y = ctr + asr(sin(ph + off) - 128, sh + gsh)
//
//   ph   the bar's own phase, advanced by spd every frame
//   off  a fixed offset into the sine: what makes eight bars on one
//        sine look like eight independent bars
//   sh   amplitude, as a shift: 1 is +/-64 lines, 2 is +/-32, and so on
//   ctr  the line the bar swings about
//   gsh  a GLOBAL extra shift, 0-7, added to every bar's own. Raising it
//        collapses the whole set into a single line and lowering it blows
//        it back open - which is the entire implode/explode effect, for
//        one byte and no extra code
//
// The subtract of $80 before the shift and the arithmetic shift right
// (`cmp #$80 / ror`, carry = sign) are what keep the swing centred on ctr
// however far gsh squeezes it. A plain `lsr` would drag every bar towards
// the top of the screen as the amplitude came down.
//
// THE MOVEMENT MODES
// -----------------------
// A mode is just 40 bytes - off, spd, sh, ctr and a palette pick for each
// of the eight bars - copied into the working arrays by rb_set_mode. The
// behaviour is entirely in the numbers:
//
//   0 WAVE     one speed, phases an eighth of a turn apart: the bars read
//              as a single wave travelling down the screen and back
//   1 SCISSOR  pairs half a turn apart, so each pair closes on itself and
//              crosses. Four crossings, staggered along the screen
//   2 FAN      one phase, amplitudes 64/32/16/8 mirrored: the bars nest
//              inside one another and breathe in and out together
//   3 CHAOS    eight different speeds (1,2,3,5,7,4,6,9) about eight
//              different centres - no two bars ever repeat the same
//              relationship, so the field never looks like a pattern
//   4 IMPLODE  one speed, phases a quarter apart, and gsh driven from 0
//              to 7 (or 7 back to 0): the bars either converge into one
//              thick bar in the middle of the screen or erupt out of it
//
// rb_script runs eight steps of them, each step switching mode and
// bringing up one more label, so the overture builds rather than loops.
//
// THE LABELS
// ----------
// Six 40-column rows of screen codes - the handle first and then five
// labels under it - written straight into the screen
// with their colour RAM left black, then brought up over eight frames
// through a per-label colour ramp (rb_do_fade). The fade is the only
// reason the text does not just pop: 40 colour cells a frame for eight
// frames is 640 cycles, which the budget has room for once a label.
//
// RUN/STOP works throughout - rb_vwork calls check_exit every frame.
//==================================================================

.label RB_BUF       = $0900     // one colour per raster line, page aligned
.label RB_TOP       = 56        // first line rb_show drives. 56 and not 51
.label RB_BOT       = 250       // because a raster low byte under 56 is
.label RB_BOT_NTSC  = 232       // NTSC: 49 fewer lines a frame, so the band
                                // gives up its last 18 to the off-screen
                                // half - see rb_setup
                                // ambiguous - PAL lines 256-311 repeat 0-55 -
                                // and rb_show has to be able to tell which
                                // line it is looking at without a counter
.label RB_COUNT     = 8         // bars
.label RB_H         = 12        // lines in one bar
.label RB_STRIPS    = 4         // colour strips to pick from
.label RB_LABELS    = 7
.label RB_STEPS     = 9         // steps in rb_script

* = $6b00 "Intro Raster"

//------------------------------------------------------------------
// raster_titles - the overture. Ends with the screen black, the text
// cleared and the VIC still in text mode, so intro_setup can take over
// without anything showing.
//------------------------------------------------------------------
raster_titles:
    jsr rb_setup
    lda #$00
    sta rb_step
rt_step:
    ldx rb_step
    lda rs_mode, x
    jsr rb_set_mode             // also zeroes every phase and gsh
    ldx rb_step
    lda rs_gmode, x
    sta rb_gmode
    lda rs_gdiv, x
    sta rb_gdiv
    sta rb_gcnt
    lda rb_gmode
    cmp #$02                    // an explode has to START collapsed, or the
    bne rt_gsh_ok               // first frame shows the bars already open
    lda #$07
    sta rb_gsh
rt_gsh_ok:
    ldx rb_step
    lda rs_lab, x               // $ff = this step brings up no new label
    bmi rt_no_label
    jsr rb_label_on
rt_no_label:
    ldx rb_step
    lda rs_len, x
    sta rb_stept
rt_frame:
    jsr rb_show                 // lines 56..250: the bars
    jsr rb_vwork                // line 250..56: music, keys, fade, gsh
    jsr rb_move                 // ...and next frame's bar positions
    jsr rb_build                // ...and next frame's line buffer
    BeatDec(rb_stept)           // in tune ticks: the steps land on the beat
    bne rt_frame
    inc rb_step
    lda rb_step
    cmp #RB_STEPS
    bne rt_step

//------------------------------------------------------------------
// rb_outro - the bars have just imploded into one line in the middle of
// the screen, so blow the whole buffer out flat: light grey, four frames
// of white, then down through grey to black. The labels are still up, so
// they vanish into the white and come back out of it as the sheet darkens.
// On the first black frame ro_dark blacks out their colour RAM, so they
// leave with the sheet instead of sitting lit on black and snapping off.
//------------------------------------------------------------------
rb_outro:
    lda #$00
    sta rb_step                 // the counter has to live in memory: rb_fill
ro_loop:                        // uses X and rb_show uses Y
    ldx rb_step
    lda ro_flash, x
    jsr rb_fill                 // flat: no bars in the flash
    jsr rb_show
    lda rb_step
    cmp #(ro_black - ro_flash)
    bne ro_lit
    jsr ro_dark                 // first black frame: labels go out with it
ro_lit:
    jsr music_tick
    jsr check_exit
    inc rb_step
    lda rb_step
    cmp #(ro_flash_end - ro_flash)
    bne ro_loop

    // Take the titles away. They have to go: start cleared the text
    // screen BEFORE calling play_intro and never clears it again, so
    // "R E T R O D U B T R V A" would otherwise still be sitting across
    // row 4 when the balls came up. ro_dark has already blacked out their
    // colour RAM, so nobody sees this happen.
    lda #$20                    // space
    ldx #$00
ro_clear:
    sta SCREEN_RAM, x
    sta SCREEN_RAM + $100, x
    sta SCREEN_RAM + $200, x
    sta SCREEN_RAM + $2e8, x
    dex
    bne ro_clear
    rts

// ro_dark - all colour RAM to black. Called once, after rb_show on the
// flash's first black frame, so it runs in the lower border / vertical blank. It is
// ~6.4K cycles, so the next frame's band starts late - a few lines on
// PAL, ~60 on NTSC - invisible, because that frame's band is black too.
ro_dark:
    lda #$00
    ldx #$00
rd_loop:
    sta COLOR_RAM, x
    sta COLOR_RAM + $100, x
    sta COLOR_RAM + $200, x
    sta COLOR_RAM + $2e8, x
    dex
    bne rd_loop
    rts

ro_flash:
    .byte $0f, $01, $01, $01, $01, $0f, $0c, $0b
ro_black:
    .byte $00, $00
ro_flash_end:

//------------------------------------------------------------------
// rb_setup - text mode out of bank 0, a blank black screen, a black line
// buffer and the tune started.
//
// Everything the VIC needs is written out in full rather than assumed:
// this runs on a cold start, where the kernal's values are still in
// place, AND on a restart from the R key, where the demo has had the VIC
// to itself.
//------------------------------------------------------------------
rb_setup:
    // The off-screen half (music, keys, bar movement, the buffer rebuild)
    // has to fit between the bottom of the band and line RB_TOP of the
    // next frame. PAL gives it 118 lines; NTSC only 69, about 4500
    // cycles, against a measured worst case of ~6400 for the work (music
    // ~1770 of it). Ending the band 18 lines early on NTSC buys ~1170
    // cycles and still frames the lowest label (row 21, lines 219-226).
    // Measured over the whole NTSC overture: one late frame, the first.
    lda #RB_BOT
    ldx ntsc
    beq !+
    lda #RB_BOT_NTSC
!:  sta rs_bot_a + 1
    clc
    adc #$01
    sta rs_bot_b + 1

    lda #$00
    sta VIC_SPRITE_ENABLE       // nothing but bars and characters
    sta VIC_BORDER
    sta VIC_BACKGROUND
    sta rb_fade
    sta rb_step

    lda #CTRL1_BLANK            // DEN off across the register writes below,
    sta VIC_CONTROL1            // so no half-set mode is ever displayed -
                                // whatever state the VIC arrives in.

    lda CIA2_DDR_A              // VA14/VA15 outputs, then VIC bank 0
    ora #$03
    sta CIA2_DDR_A
    lda CIA2_PORT_A
    and #$fc
    ora #$03
    sta CIA2_PORT_A
    lda #$14                    // screen $0400, character ROM at $1000
    sta VIC_MEMORY_SETUP
    lda #$08                    // MCM off, 40 columns, no X scroll
    sta VIC_CONTROL2
    lda #CTRL1_25ROWS           // DEN on: characters, and therefore badlines
    sta VIC_CONTROL1

    lda #$20                    // a screen of spaces...
    ldx #$00
rsu_screen:
    sta SCREEN_RAM, x
    sta SCREEN_RAM + $100, x
    sta SCREEN_RAM + $200, x
    sta SCREEN_RAM + $2e8, x
    dex
    bne rsu_screen
    lda #$00                    // ...in black on black, so a label is
    ldx #$00                    // invisible until its fade brings it up
rsu_colour:
    sta COLOR_RAM, x
    sta COLOR_RAM + $100, x
    sta COLOR_RAM + $200, x
    sta COLOR_RAM + $2e8, x
    dex
    bne rsu_colour

    lda #$ff
    sta rb_built_back           // first rb_build floods the band
    lda #$00
    jsr rb_fill                 // a black buffer for the first frame, which
                                // is displayed before rb_build has ever run
    lda #$00                    // song 1 of 1. The tune runs from HERE now,
    jsr MUSIC_INIT              // not from intro_setup - the overture is the
    rts                         // start of the intro, so it is where the
                                // music starts

//------------------------------------------------------------------
// rb_show - the display half of the frame: drive $d020 and $d021 from
// the line buffer, line RB_TOP to line RB_BOT.
//
// Three loops, and the first two are the ones that make it safe:
//
//   rs_past  wait until the raster has LEFT the band. Without it, a frame
//            whose off-screen work finished in under one raster line would
//            see 250 still standing in $d012, decide that was a legal
//            start line and drive the bars backwards from there.
//   rs_sync  wait until the raster reaches RB_TOP. Coming out of rs_past
//            the low byte counts 0..55 through lines 256..311 and 0..55
//            again, so `bcc` sits through both and lands on line 56 exactly.
//   rs_line  one write per line.
//
// If the off-screen work ever DOES overrun into the band, rs_sync falls
// straight through and the bars simply start at whatever line we are on:
// the frame is short at the top rather than lost altogether.
//------------------------------------------------------------------
rb_show:
rs_past:
    ldy VIC_RASTER
rs_bot_a:
    cpy #RB_BOT                 // <- patched by rb_setup (RB_BOT_NTSC)
    bcs rs_past                 // still inside/below the band
rs_sync:
    ldy VIC_RASTER
    cpy #RB_TOP
    bcc rs_sync                 // above it: wait for the top of the band
rs_line:
    lda RB_BUF, y               // 4   THE COLOUR IS FETCHED BEFORE THE WAIT:
rsl_wait:                       //     nothing may stand between detecting
    cpy VIC_RASTER              // 4   the line and changing the border
    bne rsl_wait                // 3   (seven cycles a turn, and a PAL line
    sta VIC_BORDER              // 4   is nine of them exactly)
    sta VIC_BACKGROUND          // 4   the paper behind the characters
    iny                         // 2
rs_bot_b:
    cpy #RB_BOT + 1             // 2   <- patched by rb_setup
    bne rs_line                 // 3
rs_end:
    lda #$00                    // the band is 56..250; everything outside it
    sta VIC_BORDER              // is black, so the two borders and the five
    sta VIC_BACKGROUND          // lines above the band do not hold the last
    rts                         // bar's colour for the rest of the frame

//------------------------------------------------------------------
// rb_vwork - the housekeeping half, between line 250 and line 56.
//------------------------------------------------------------------
rb_vwork:
    jsr music_tick              // one tick, at a fixed point in the frame
    jsr check_exit              // RUN/STOP bails out, R restarts
    jsr rb_do_fade              // bring the newest label up a step

    lda rb_gmode                // 0 = amplitude is fixed this step
    beq rv_done
    BeatDec(rb_gcnt)
    bne rv_done
    lda rb_gdiv
    sta rb_gcnt
    lda rb_gmode
    cmp #$01
    bne rv_open
    lda rb_gsh                  // 1: squeeze shut, and stop at 7 - one more
    cmp #$07                    // shift and sin would vanish entirely
    beq rv_done
    inc rb_gsh
    rts
rv_open:
    lda rb_gsh                  // 2: open back out, and stop at 0
    beq rv_done
    dec rb_gsh
rv_done:
    rts

//------------------------------------------------------------------
// rb_move - one frame of movement for all eight bars.
//
//     y = ctr + asr(sin(ph + off) - 128, sh + gsh)
//
// `cmp #$80 / ror` is the arithmetic shift: cmp puts the sign bit into
// the carry and ror rotates it back in at the top, so a negative swing
// stays negative however many times it is halved. sh + gsh is therefore
// a pure amplitude control that never moves the centre of the swing.
//
// sh is never stored as 0, so the shift loop always runs at least once.
//------------------------------------------------------------------
rb_move:
    ldx #RB_COUNT - 1
rm_loop:
    lda rb_ph, x
    clc
    adc rb_spd, x               // the bar's own tempo
    sta rb_ph, x
    clc
    adc rb_off, x               // ...plus its fixed place in the set
    tay

    lda rb_sh, x                // amplitude = own shift + the global one
    clc
    adc rb_gsh
    sta rb_tmp

    lda INTRO_SIN, y            // 0..255 ...
    sec
    sbc #$80                    // ...as -128..127, so the swing is centred
    ldy rb_tmp
rm_shift:
    cmp #$80                    // carry = sign
    ror                         // arithmetic shift right: halve, keep sign
    dey
    bne rm_shift
    clc
    adc rb_ctr, x
    sta rb_y, x                 // the bar's top line this frame
    dex
    bpl rm_loop
    rts

//------------------------------------------------------------------
// rb_build - repaint the line buffer: flat backdrop, then the eight bars
// from the back forwards, so bar 0 crosses in front of bar 7.
//
// A bar is a straight copy of a 12-byte colour strip, no blending: where
// two bars meet, the lower-numbered one simply wins. That reads as one
// bar passing in front of another, which is what the crossing modes want.
//
// rb_y can run a little past the bottom of the band, and the tail of such
// a bar wraps round inside the page into lines 0..11. Those lines are
// never displayed - rb_show starts at 56 - so the wrap is harmless and
// costs no clamping.
//
// Incremental, because the full version - flood all 195 lines, then copy
// the bars a line at a time - measured 4100 cycles, and an NTSC frame has
// only ~4500 off-screen cycles for EVERYTHING (music included). So:
//   - put the backdrop back on just the 8 x 12 lines last frame's bars
//     covered (rb_oldy), unrolled: ~560 cycles;
//   - copy the eight new bars, each strip unrolled: ~1100 cycles.
// The full flood only happens when the backdrop colour itself changes
// (rb_built_back), which also covers the very first frame.
//------------------------------------------------------------------
rb_build:
    lda rb_back
    cmp rb_built_back
    beq rbd_erase
    sta rb_built_back           // new backdrop: flood the whole band
    jsr rb_fill
    jmp rbd_plot
rbd_erase:                      // A = rb_back
    ldx #RB_COUNT - 1
rbd_erase_bar:
    ldy rb_oldy, x
    .for (var k = 0; k < RB_H; k++) {
        sta RB_BUF + k, y       // runs up to $0a0a past a bar at Y 255:
    }                           // free RAM, and never displayed
    dex
    bpl rbd_erase_bar
rbd_plot:                       // back to front: bar 0 ends up on top
    ldx #RB_COUNT - 1
rbd_plot_bar:
    lda rb_y, x
    sta rb_oldy, x              // what next frame has to erase
    tay
    stx rb_bar
    lda rb_pal, x
    tax
    .for (var k = 0; k < RB_H; k++) {
        lda rb_strips + k, x
        sta RB_BUF + k, y
    }
    ldx rb_bar
    dex
    bpl rbd_plot_bar
    rts

//------------------------------------------------------------------
// rb_fill - flood lines RB_TOP..RB_BOT with A. Three stores a turn over
// 65 turns is exactly the 195 lines of the band.
//------------------------------------------------------------------
rb_fill:
    ldx #65
rfi_loop:
    sta RB_BUF + RB_TOP - 1, x      //  56..120
    sta RB_BUF + RB_TOP + 64, x     // 121..185
    sta RB_BUF + RB_TOP + 129, x    // 186..250
    dex
    bne rfi_loop
    rts

//------------------------------------------------------------------
// rb_plot_bars - draw bars rb_bar down to 0 into the buffer. X indexes
// the strip and Y the buffer, so the bar counter has to live in memory.
//------------------------------------------------------------------
rb_plot_bars:
    ldx rb_bar
    ldy rb_y, x
    lda rb_pal, x               // where this bar's strip starts...
    tax
    clc
    adc #RB_H                   // ...and where it ends
    sta rb_end
rpb_line:
    lda rb_strips, x
    sta RB_BUF, y
    iny
    inx
    cpx rb_end
    bne rpb_line
    dec rb_bar
    bpl rb_plot_bars
    rts

//------------------------------------------------------------------
// rb_set_mode - load mode A into the working arrays.
//
// rb_off, rb_spd, rb_sh, rb_ctr and rb_pal are eight bytes each and
// CONTIGUOUS, in that order, so the whole mode is one 40-byte copy with a
// single index rather than five loops. A mode block in rb_modes is laid
// out the same way.
//
// Every phase and the global shift are zeroed with it, so a mode change
// is a clean cut to a known pose - the modes are meant to land on the
// beat, not to be blended.
//------------------------------------------------------------------
rb_set_mode:
    sta rb_tmp                  // mode * 40 = mode * 32 + mode * 8
    asl
    asl
    asl
    sta rb_tmp2                 // mode * 8
    lda rb_tmp
    asl
    asl
    asl
    asl
    asl                         // mode * 32  (six modes, so no overflow)
    clc
    adc rb_tmp2
    clc
    adc #<rb_modes
    sta sm_src + 1
    lda #>rb_modes
    adc #$00
    sta sm_src + 2
    ldx #$00
sm_loop:
sm_src:
    lda rb_modes, x             // <- patched to this mode's block
    sta rb_off, x               // walks straight on through spd/sh/ctr/pal
    inx
    cpx #40
    bne sm_loop
    lda #$00
    sta rb_gsh
    ldx #RB_COUNT - 1
sm_phase:
    sta rb_ph, x
    dex
    bpl sm_phase
    rts

//------------------------------------------------------------------
// rb_label_on - put label A on screen in black, and arm its fade.
//
// The row address is taken from main.asm's row_offset tables and patched
// into the two stores, which is cheaper than a pointer and means the
// screen and the colour row are indexed by the same Y.
//------------------------------------------------------------------
rb_label_on:
    tax
    lda lab_row, x
    sta rb_fade_row
    tay
    lda row_offset_lo, y
    sta rl_scr + 1
    sta rl_col + 1
    lda row_offset_hi, y
    clc
    adc #>SCREEN_RAM
    sta rl_scr + 2
    lda row_offset_hi, y
    clc
    adc #>COLOR_RAM
    sta rl_col + 2
    lda lab_src_lo, x
    sta rl_src + 1
    lda lab_src_hi, x
    sta rl_src + 2

    txa                         // this label's fade ramp = lab_ramp + n * 8
    asl
    asl
    asl
    clc
    adc #<lab_ramp
    sta rf_ramp + 1
    lda #>lab_ramp
    adc #$00
    sta rf_ramp + 2

    ldy #$00
rl_loop:
rl_src:
    lda lab_text, y             // <- patched: this label's 40 screen codes
rl_scr:
    sta SCREEN_RAM, y           // <- patched: its row
    lda #$00                    // black for now: rb_do_fade brings it up
rl_col:
    sta COLOR_RAM, y            // <- patched: the same row of colour RAM
    iny
    cpy #40
    bne rl_loop
    lda #$08                    // eight frames of fade
    sta rb_fade
    rts

//------------------------------------------------------------------
// rb_do_fade - one step of the newest label's colour fade, or nothing.
// 640 cycles when it runs, which is why it only runs for eight frames
// after a label appears rather than every frame of the overture.
//------------------------------------------------------------------
rb_do_fade:
    lda rb_fade
    beq rdf_done
    dec rb_fade
    lda #$07                    // fade 8..1 counts down, the ramp 0..7 up
    sec
    sbc rb_fade
    tay
rf_ramp:
    lda lab_ramp, y             // <- patched: this label's ramp
    sta rb_tmp
    ldy rb_fade_row
    lda row_offset_lo, y
    sta rf_col + 1
    lda row_offset_hi, y
    clc
    adc #>COLOR_RAM
    sta rf_col + 2
    lda rb_tmp
    ldy #$00
rf_loop:
rf_col:
    sta COLOR_RAM, y            // <- patched: the label's colour row
    iny
    cpy #40
    bne rf_loop
rdf_done:
    rts

//==================================================================
// DATA
//==================================================================

//------------------------------------------------------------------
// rb_script - the overture, eight steps of it.
//
//   mode   which movement mode (see the header)
//   len    frames
//   lab    label to bring up at the start of the step, $ff for none
//   gmode  0 fixed amplitude, 1 squeeze shut, 2 open out
//   gdiv   frames between gsh steps while gmode is 1 or 2
//
// 480 frames, about 9.6 seconds PAL. It opens on an explosion out of a
// single line and closes on the implosion back into one, so the overture
// is bracketed by the same move played both ways. The second-to-last
// step is a quiet beat of its own for the music credit, after the date
// and before the close - everything else has already had its turn.
//------------------------------------------------------------------
rs_mode:  .byte    4,  0,  1,  3,  0,  2,  1,  2,    4
rs_len:   .byte   40, 72, 56, 72, 48, 56, 48, 40,   48
rs_lab:   .byte $ff,  0,  1,  2,  3,  4,  5,  6,  $ff
rs_gmode: .byte    2,  0,  0,  0,  0,  0,  0,  0,    1
rs_gdiv:  .byte    5,  0,  0,  0,  0,  0,  0,  0,    6

//------------------------------------------------------------------
// The colour strips. Twelve lines each, dark at the edges and bright in
// the middle, so a bar has a lit core and does not read as a flat slab.
//
// NOT ONE OF THEM CONTAINS WHITE. The labels are lit in white, light grey,
// cyan, yellow and light green, and $d021 is the paper those characters
// sit on: a white core sweeping under a white row would take the row with
// it. Capping the strips at yellow, cyan, light red and light grey keeps
// every label legible whatever passes behind it.
//------------------------------------------------------------------
rb_strips:
    // 0 ember: dark blue -> red -> orange -> yellow core
    .byte $06, $02, $02, $04, $08, $07, $07, $08, $04, $02, $02, $06
    // 1 ice: blue -> light blue -> cyan core
    .byte $06, $06, $0e, $0e, $03, $03, $03, $03, $0e, $0e, $06, $06
    // 2 toxic: dark grey -> green -> light green core
    .byte $0b, $0b, $05, $05, $0d, $0d, $0d, $0d, $05, $05, $0b, $0b
    // 3 neon: purple -> light red -> light grey core
    .byte $04, $04, $0a, $0a, $0f, $0f, $0f, $0f, $0a, $0a, $04, $04

//------------------------------------------------------------------
// The six modes, 40 bytes each: off[8], spd[8], sh[8], ctr[8], pal[8],
// in the same order and the same size as the working arrays they are
// copied into.
//
// ctr and sh together have to keep a bar inside the band. sh 1 is a
// swing of +/-64 lines, so a centre of 150 covers 86..214 and the bar's
// twelve rows reach 226 - clear of 250. A bar may run off the TOP of the
// band and be clipped, which is how the wave gets to look like it is
// coming in from somewhere.
//------------------------------------------------------------------
rb_modes:
    //---- 0 WAVE: one tempo, phases an eighth of a turn apart ----
    .byte $00, $20, $40, $60, $80, $a0, $c0, $e0     // off
    .byte    3,   3,   3,   3,   3,   3,   3,   3    // spd
    .byte    1,   1,   1,   1,   1,   1,   1,   1    // sh   +/-64
    .byte  150, 150, 150, 150, 150, 150, 150, 150    // ctr
    .byte    0,  12,  24,  36,   0,  12,  24,  36    // pal

    //---- 1 SCISSOR: pairs half a turn apart, staggered along the screen ----
    .byte $00, $80, $18, $98, $30, $b0, $48, $c8     // off
    .byte    5,   5,   5,   5,   5,   5,   5,   5    // spd
    .byte    1,   1,   1,   1,   1,   1,   1,   1    // sh
    .byte  150, 150, 150, 150, 150, 150, 150, 150    // ctr
    .byte    0,  24,  12,  36,   0,  24,  12,  36    // pal

    //---- 2 FAN: one phase, nested amplitudes, mirrored ----
    .byte $00, $00, $00, $00, $80, $80, $80, $80     // off
    .byte    4,   4,   4,   4,   4,   4,   4,   4    // spd
    .byte    1,   2,   3,   4,   1,   2,   3,   4    // sh  64/32/16/8
    .byte  145, 145, 145, 145, 145, 145, 145, 145    // ctr
    .byte    0,  12,  24,  36,  36,  24,  12,   0    // pal

    //---- 3 CHAOS: eight tempos about eight centres ----
    .byte $00, $28, $50, $78, $a0, $c8, $f0, $14     // off
    .byte    1,   2,   3,   5,   7,   4,   6,   9    // spd
    .byte    2,   2,   2,   2,   2,   2,   2,   2    // sh   +/-32
    .byte   80, 105, 130, 155, 180, 205, 130, 180    // ctr
    .byte    0,  12,  24,  36,   0,  12,  24,  36    // pal

    //---- 4 IMPLODE / EXPLODE: gsh does the work, not the table ----
    .byte $00, $80, $20, $a0, $40, $c0, $60, $e0     // off
    .byte    6,   6,   6,   6,   6,   6,   6,   6    // spd
    .byte    1,   1,   1,   1,   1,   1,   1,   1    // sh
    .byte  150, 150, 150, 150, 150, 150, 150, 150    // ctr
    .byte   36,  24,  12,   0,  36,  24,  12,   0    // pal

//------------------------------------------------------------------
// The labels: six rows of 40 screen codes, already centred, so putting
// one up is a straight 40-byte copy with no column arithmetic.
//------------------------------------------------------------------
lab_row:    .byte  4,  7, 11, 14, 17, 20, 21
lab_src_lo: .fill RB_LABELS, <(lab_text + i * 40)
lab_src_hi: .fill RB_LABELS, >(lab_text + i * 40)

// Each label's colour comes up out of black over eight frames. The last
// two entries are the same so the row is already at its final colour on
// the frame the fade stops.
lab_ramp:
    .byte $00, $06, $0e, $03, $0f, $01, $01, $01    // 0 handle    -> white
    .byte $00, $0b, $0c, $0f, $01, $0f, $0c, $0c    // 1 presents  -> grey
    .byte $00, $09, $08, $0a, $07, $01, $07, $07    // 2 title     -> yellow
    .byte $00, $0b, $05, $0d, $0f, $01, $0d, $0d    // 3 strapline -> lt green
    .byte $00, $06, $04, $0e, $0f, $01, $03, $03    // 4 strapline -> cyan
    .byte $00, $06, $04, $0a, $0f, $01, $0f, $0f    // 5 date      -> lt grey
    .byte $00, $0b, $0b, $0c, $0c, $0f, $0c, $0c    // 6 music credit -> grey,
                                                     // never brighter than
                                                     // mid grey - see below

.encoding "screencode_upper"
lab_text:
    .text "        R E T R O D U B T R V A         "
    .text "          - P R E S E N T S -           "
    .text "           S P R I T E M O V            "
    .text "         E I G H T   B A L L S          "
    .text "          O N E   R A S T E R           "
    .text "           2 0 2 6   V 1 . 0            "
    .text "     MUSIC BY ARI YLIAHO (AGEMIXER)     "
// Row 21's credit is the one label that is NOT letter-spaced like the six
// above it - every other row runs its text "R E T R O..." with a blank
// between each glyph, doubling its effective width. There is no smaller
// font in text mode without a whole second character set (every glyph
// the OTHER six labels use would have to be duplicated into it just to
// keep rendering at all, since $d018 selects one charset for the entire
// screen) - not a fair trade for one credit line. Dropping the letter-
// spacing and keeping the colour a flat, capped grey instead does the
// same job at essentially zero cost: dense against the labels' open
// tracking, and dim against their white/yellow/cyan peaks, it reads as
// smaller and quieter without a single pixel actually changing size.

//------------------------------------------------------------------
// State. All of it absolute rather than zero page: the only thing here
// that is touched per raster line is RB_BUF, and everything else is read
// once a bar or once a frame, so the extra cycle of absolute addressing
// costs nothing - and the intro's zero page is already three deep in
// other people's variables.
//
// rb_off..rb_pal MUST stay contiguous and in this order: rb_set_mode
// copies all forty bytes with one index.
//------------------------------------------------------------------
rb_off:     .fill RB_COUNT, 0   // fixed phase offset, the bar's place in the set
rb_spd:     .fill RB_COUNT, 0   // phase steps per frame
rb_sh:      .fill RB_COUNT, 0   // amplitude as a shift, never 0
rb_ctr:     .fill RB_COUNT, 0   // the line the bar swings about
rb_pal:     .fill RB_COUNT, 0   // offset of this bar's strip in rb_strips

rb_ph:      .fill RB_COUNT, 0   // running phase
rb_y:       .fill RB_COUNT, 0   // top line this frame

rb_gsh:     .byte 0             // global extra shift, 0-7: the implode
rb_gmode:   .byte 0             // 0 hold, 1 squeeze shut, 2 open out
rb_gdiv:    .byte 0             // frames per gsh step
rb_gcnt:    .byte 0             // countdown to the next one
rb_back:    .byte 0             // the colour behind the bars
rb_bar:     .byte 0             // rb_plot_bars' loop counter
rb_end:     .byte 0             // rb_plot_bars' strip end index
rb_step:    .byte 0             // which rb_script step is running
rb_stept:   .byte 0             // frames left in it
rb_fade:    .byte 0             // frames of label fade left, 0 = idle
rb_fade_row: .byte 0            // which text row is fading
rb_tmp:     .byte 0
rb_oldy:    .fill RB_COUNT, 0   // rb_build: last frame's bar tops
rb_built_back: .byte $ff        // rb_build: backdrop the buffer holds
rb_tmp2:    .byte 0
