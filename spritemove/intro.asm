//==================================================================
// INTRO - the opening sequence: music, a spiral bitmap, then the reveal
//
// Imported by main.asm into its code segment. The bitmap and the three
// wave fields are in intro_gfx.asm; the tune is in music.asm.
//
// HOW THE ANIMATION WORKS
// -----------------------
// The bitmap never changes. It is a HI-RES picture - 320 x 200, one bit
// per pixel - so a cell has exactly two colors and both come from its
// video matrix byte:
//
//     bit 1  ->  high nibble  (the "ink")
//     bit 0  ->  low  nibble  (the "paper")
//
// Color RAM and $d021 are both unused in this mode, which means there is
// no global color to design around and every cell is a free pair. It also
// means a cell costs ONE byte to recolor rather than two.
//
// So the animation is: leave the picture alone, rewrite the 1000 video
// matrix bytes. paint_sweep does it with a single indexed lookup per cell
//
//       ldy field,x : lda vmtab,y : sta vm,x
//
// at 18 cycles a cell, which is cheap enough to repaint two 256-cell
// pages a frame - the whole screen every two frames - for about 9200
// cycles.
//
// THE FIELD CARRIES THE LAYER, NOT JUST THE PHASE
// -----------------------------------------------
// Every cell's field byte is a ramp position in its low nibble and a
// LAYER in bit 4:
//
//     $00-$0f   a spiral cell, stepping with pal_phase
//     $10-$1f   a logo cell,  stepping with text_phase
//
// build_tabs fills all 32 entries of vmtab, so that one lookup resolves
// both layers. This is how the logo keeps its own ramp, its own rotation
// and its own glint in a mode with no color RAM to give it: the two
// layers are separated per cell instead of per bit pair, and intro_gfx.asm
// clears the spiral out of any cell a letter touches so nothing bleeds.
//
// Because the picture holds four superimposed patterns - spiral, counter
// spiral, rings and plasma, all inside a checkered tunnel - swapping
// which field drives the color changes WHICH of them the eye picks out.
// The bitmap is fixed; the structure on screen is not.
//
// THE FOUR PHASES
// ---------------
//   A  INTRO_A_LEN frames  concentric rings (wave field A). The three band
//                          colors come alive one at a time (fade_stage
//                          1, 2, 3) over a black screen while the tune's
//                          intro plays, and the rings ripple outward
//   B  INTRO_B_LEN frames  the 1-turn spiral field (B) takes over and the
//                          rotation speed ramps from one step every 8
//                          frames up to one every frame
//   C  INTRO_C_LEN frames  the tight 3-turn field (C), ramp stepped twice
//                          a frame: the spiral winds up and blurs
//   D  INTRO_D_LEN frames  a last burst, then the whole field ramps to
//                          white through intro_flash (a flat constant
//                          fill, so the flash lands in one frame)
//   W  INTRO_W_LEN frames  the white sheet is eaten from the edges in,
//                          spiralling toward the middle, until the screen
//                          is black and the display can be handed to the
//                          balls without the mode switch ever showing
//
// The logo appears twice and never at the same time. Through A, B and F
// it is a set of black holes punched in the spiral - present, shaped,
// unreadable - while the sprite copy flies over the top. When the sprites
// switch off at the start of C the carving lights to chrome, so the
// flying logo reads as landing in the bitmap.
//
// RUN/STOP works throughout: intro_sync calls check_exit every frame.
//==================================================================

//------------------------------------------------------------------
// play_intro - run the whole opening sequence, then leave the VIC in
// text mode with the display still off, ready for start to draw the
// stars and the status bar before it enables DEN.
//------------------------------------------------------------------
play_intro:
    jsr intro_setup

    //---- Phase A: rings ripple up out of black, logo still unlit ----
    ldx #$00
    jsr set_text_ramp
    lda #>INTRO_WAVE_A
    sta wave_pg
    lda #INTRO_A_LEN
    sta intro_t
pa_loop:
    jsr intro_sync
    lda intro_t                 // the second band color joins half way in
    cmp #INTRO_A_LEN / 2
    bcs pa_stage1
    lda #$02
    jmp pa_set
pa_stage1:
    lda #$01
pa_set:
    sta fade_stage
    lda intro_t                 // rings speed up gently, 5 frames down to 4
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr
    clc
    adc #$04
    sta pal_step
    jsr advance_palette
    jsr build_tabs
    jsr paint_sweep
    dec intro_t
    bne pa_loop

    //---- Phase B: spiral accelerates, the logo flies in ----
    jsr flow_logo_on            // carved logo stays dark: one logo at a time
    lda #>INTRO_WAVE_B
    sta wave_pg
    lda #INTRO_B_LEN
    sta intro_t
pb_loop:
    jsr intro_sync
    lda intro_t                 // step = intro_t / 32 + 1: 6 frames down to 1
    lsr
    lsr
    lsr
    lsr
    lsr
    clc
    adc #$01
    sta pal_step
    jsr advance_palette
    jsr build_tabs
    jsr paint_sweep
    jsr flow_sprites
    dec intro_t
    bne pb_loop

    //---- Phase F: the plasma field - the bands swim and the tunnel pops ----
    lda #>INTRO_WAVE_D
    sta wave_pg
    lda #$01
    sta pal_step
    sta pal_tick
    lda #INTRO_F_LEN
    sta intro_t
pf_loop:
    jsr intro_sync
    jsr advance_palette
    jsr build_tabs
    jsr paint_sweep
    jsr flow_sprites
    dec intro_t
    bne pf_loop

    //---- Phase C: the flying logo lands - sprites off, carving ignites ----
    lda #$00
    sta VIC_SPRITE_ENABLE       // the only copy left is the one in the bitmap
    ldx #$02
    jsr set_text_ramp
    lda #INTRO_C_LEN
    sta intro_t
pc_loop:
    jsr intro_sync
    inc text_phase              // glint at double speed too (16 frames a lap)
    inc text_phase
    jsr advance_palette
    jsr advance_palette         // double speed: the spiral winds up
    jsr build_tabs
    jsr paint_sweep
    dec intro_t
    bne pc_loop

    //---- Phase D: last burst, then ramp the whole field to white ----
    lda #INTRO_D_LEN
    sta intro_t
pd_loop:
    jsr intro_sync
    lda intro_t
    cmp #8
    bcs pd_rotate               // still spiralling
    tax                         // last 8 frames: cyan -> lt blue -> white
    lda intro_flash, x
    sta VIC_BORDER              // border too, so it is one flat sheet
    tax                         // same color in both video matrix nibbles
    asl
    asl
    asl
    asl
    stx temp
    ora temp
    sta vm_byte
    jsr flash_field             // flat fill: the whole screen in one frame
    jmp pd_next
pd_rotate:
    inc text_phase
    inc text_phase
    jsr advance_palette
    jsr advance_palette
    jsr build_tabs
    jsr paint_sweep
pd_next:
    dec intro_t
    bne pd_loop

    //---- Phase W: the white sheet is sucked back into the vortex ----
    lda #>INTRO_WIPE            // the one field that does not repeat
    sta wave_pg
    lda #INTRO_W_LEN
    sta intro_t
pw_loop:
    jsr intro_sync
    lda #INTRO_W_LEN            // wipe_t = (elapsed frames) / 2, so each of
    sec                         // the 16 steps gets the two frames the
    sbc intro_t                 // sweep needs to cover the whole screen
    lsr
    sta wipe_t
    jsr build_wipe_tabs
    jsr paint_sweep
    dec intro_t
    bne pw_loop

    jmp intro_to_text           // tail call: back to text mode, display off
                                // - and the screen is already black, so the
                                // mode switch itself is invisible

//------------------------------------------------------------------
// intro_setup - black bitmap field, VIC into multicolor bitmap mode out
// of bank 1, music initialised.
//
// The field is painted black *before* the mode switch, so the first thing
// the VIC shows in bitmap mode is a clean black screen rather than
// whatever was in $6000.
//------------------------------------------------------------------
intro_setup:
    lda #$00
    sta VIC_SPRITE_ENABLE       // no sprites until the reveal
    sta VIC_BORDER
    sta VIC_BACKGROUND          // unused in hi-res bitmap, kept black so
                                // the switch in and out of the mode is clean
    sta pal_phase
    sta text_phase
    sta fade_stage              // every band color still black
    sta vm_byte
    sta paint_page              // the sweep starts at the top of the screen
    lda #$08                    // slowest rotation: one step every 8 frames
                                // (phase A overwrites this from frame one)
    sta pal_step
    sta pal_tick
    jsr flash_field             // all-black field before anything is visible

    lda CIA2_DDR_A              // VA14/VA15 have to be outputs to select a bank
    ora #$03
    sta CIA2_DDR_A
    lda CIA2_PORT_A             // VIC bank 1 = $4000-$7fff
    and #$fc
    ora #$02
    sta CIA2_PORT_A
    lda #$80                    // video matrix $6000, bitmap $4000
    sta VIC_MEMORY_SETUP
    lda #$08                    // MCM OFF: hi-res, 320 pixels, 40 columns
    sta VIC_CONTROL2
    lda #$3b                    // BMM (bit 5) on, DEN on: the bitmap appears
    sta VIC_CONTROL1

    lda #$00                    // song 1 of 1
    jsr MUSIC_INIT
    rts

//------------------------------------------------------------------
// intro_sync - one frame of housekeeping: lower-border sync, music,
// RUN/STOP. The caller then has the rest of the frame for the sweep.
//------------------------------------------------------------------
intro_sync:
    lda #$fa                    // same line 250 sync as the main loop
is_wait:
    cmp VIC_RASTER
    bne is_wait
    jsr MUSIC_PLAY              // one tick of the tune, at a fixed raster
    jsr check_exit              // RUN/STOP bails out of the intro
    lda #$fa                    // do not run twice on the same line
is_leave:
    cmp VIC_RASTER
    beq is_leave
    rts

//------------------------------------------------------------------
// advance_palette - age the rotation counter and step the ramp phase.
// Called twice a frame where the effect wants double speed.
//------------------------------------------------------------------
advance_palette:
    dec pal_tick
    bne ap_done
    lda pal_step                // reload and step the phase on
    sta pal_tick
    inc pal_phase
ap_done:
    rts

//------------------------------------------------------------------
// build_tabs - collapse this frame's two rotations into the two 16-entry
// lookup tables the sweep indexes.
//
//   vmtab[$00-$0f]  a spiral cell: ink high nibble, paper low nibble,
//                   the two half a ramp apart so they never coincide
//   vmtab[$10-$1f]  a logo cell: the letter's color as ink, black paper
//
// One table, because the fields carry the layer in bit 4 of every cell -
// so the sweep resolves both layers with a single `lda vmtab,y` and the
// logo keeps its own ramp and its own phase in a mode with no color RAM.
// vmtab turns with pal_phase through pal_ramp, the top half turns with
// text_phase through whichever ramp is patched into bt_src, and
// fade_stage gates the spiral's two colors in for the phase A fade-up.
//
// 32 entries at ~60 cycles is around 2000 cycles a frame - the sweep is
// still the expensive half.
//------------------------------------------------------------------
build_tabs:
    //---- entries $00-$0f: the spiral's cells ----
    ldx #$00
bt_loop:
    txa                         // this entry's place in the spiral ramp
    clc
    adc pal_phase
    and #$0f
    tay
    lda pal_ramp, y             // the ink: the bright ramp
    sta temp
    tya                         // the paper: a SEPARATE, mostly black ramp
    clc                         // half a turn behind. Hi-res has no global
    adc #8                      // background color to anchor the picture -
    and #$0f                    // if both colors of a cell are bright the
    tay                         // whole screen shouts and the arms stop
    lda dark_ramp, y            // reading. Keeping paper dark puts the
                                // pattern back on a dark field, the way
                                // $d021 did in multicolor.

    ldy fade_stage              // gate the two colors in one at a time
    cpy #$02
    bcs bt_paper_live
    lda #$00
bt_paper_live:
    sta temp2
    cpy #$01
    bcs bt_ink_live
    lda #$00
    sta temp
bt_ink_live:
    lda temp                    // video matrix byte = ink high, paper low
    asl
    asl
    asl
    asl
    ora temp2
    sta vmtab, x

    //---- entries $10-$1f: the logo's cells, on their own phase ----
    txa
    clc
    adc text_phase
    and #$0f
    tay
bt_src:
    lda text_off, y             // <- patched by set_text_ramp: off/dim/hot
    asl                         // the letter is the ink; the plate it sits
    asl                         // on is always black, so the low nibble
    asl                         // stays 0 and the logo reads clean however
    asl                         // busy the spiral around it gets
    sta vmtab + $10, x

    inx
    cpx #$10
    bne bt_loop
    rts

//------------------------------------------------------------------
// flow_logo_on - point the VIC at the flying logo and switch it on.
//
// The sprite pointers live at $63f8, the last eight bytes of the video
// matrix page. paint_sweep and flash_field both stop at $63e7, so they
// can never walk over them.
//------------------------------------------------------------------
flow_logo_on:
    ldx #$07
flo_ptr:
    txa
    clc
    adc #INTRO_SPR_PTR          // block $90 + n
    sta INTRO_SPR_PTRS, x
    dex
    bpl flo_ptr
    lda #$00
    sta flow_t
    sta flow_t2
    sta flow_t3
    sta VIC_SPRITE_MULTI        // hi-res: one color, sharp letters
    sta VIC_SPRITE_EXPAND_Y     // the doubled font rows give the height
    sta VIC_SPRITE_PRIORITY     // logo in front of the picture
    lda #$ff
    sta VIC_SPRITE_EXPAND_X     // 8 x 16 data -> 16 x 16 on screen
    sta VIC_SPRITE_ENABLE
    rts

//------------------------------------------------------------------
// flow_sprites - move the eight flying sprites one frame.
//
// Everything comes out of one 256-entry sine table read with a byte
// index, so nothing needs clamping and nothing can leave the screen.
//
//   X   24 + sin(flow_t + group) / 2  ->  24..151, plus the sprite's
//       place in its word (0, 48, 96, 144) - the four sprites stay
//       locked together as one word and the word drifts as a whole.
//       24..151 + 144 + 48 wide lands exactly inside the visible 24..343.
//   Y   50 + sin(flow_t2) / 2         ->  the word bobs as ONE body,
//       every sprite in it sharing the term, so it never comes apart,
//       plus sin(flow_t3 + i/4 turn) / 16, a 15 pixel wobble that runs
//       along the word and makes it undulate. 50..192 all told.
//
// flow_t runs at 1 a frame, flow_t2 at 2 and flow_t3 at 5, so the drift
// comes round in 5.1 seconds, the bob in 2.6 and the ripple in 1: three
// periods that share no common factor, so the path never repeats inside
// the 8 seconds it is on screen. The date carries +128 on drift and bob,
// half a period out, so the two words swing against each other and cross.
//
// About 850 cycles for all eight.
//------------------------------------------------------------------
flow_sprites:
    inc flow_t
    inc flow_t2
    inc flow_t2                 // the bob runs at twice the drift rate
    lda flow_t3
    clc
    adc #$05                    // and the ripple faster again
    sta flow_t3
    lda #$00
    sta spr_msb
    ldx #$00
fs_loop:
    stx temp2                   // temp2 = sprite number n, held all the way
                                // through; temp is the one scratch byte and
                                // is reused three times below

    //---- X: the word drifts, the sprite sits at its place in the word ----
    lda x_phase, x
    clc
    adc flow_t
    tay
    lda INTRO_SIN, y
    lsr                         // 0..127 of drift
    clc
    adc #$18                    // 24: the left edge of the visible screen
    clc
    adc x_place, x              // 0 / 48 / 96 / 144 across the word
    sta temp                    // X low byte (sta leaves the carry alone,
    bcc fs_no_msb               // so the carry still says whether we passed
    lda msb_bit, x              // 255 and need this sprite's bit in $d010)
    ora spr_msb
    sta spr_msb
fs_no_msb:
    lda temp2
    asl                         // sprite n's X/Y registers are at +2n
    tay
    lda temp
    sta VIC_SPRITE_X, y

    //---- Y: the word bobs as one, then each sprite ripples around it ----
    lda y_ripple, x             // the small per-sprite wobble first, a
    clc                         // quarter period apart along the word
    adc flow_t3
    tay
    lda INTRO_SIN, y
    lsr
    lsr
    lsr
    lsr                         // 0..15 only
    sta temp
    lda y_phase, x              // then the WHOLE word: the same term for
    clc                         // all four, which is what keeps it reading
    adc flow_t2                 // as a word instead of loose letters
    tay
    lda INTRO_SIN, y
    lsr                         // 0..127 of travel
    clc
    adc #$32                    // 50: the top of the flight path
    clc
    adc temp                    // 50..192, never past the visible bottom
    sta temp
    lda temp2
    asl
    tay
    lda temp
    sta VIC_SPRITE_Y, y

    //---- color: the word runs through the ramp, one step per sprite ----
    lda flow_t
    lsr
    lsr                         // a new hue every 4 frames
    clc
    adc temp2                   // ...offset along the word
    and #$0f
    tay
    lda spr_ramp, y
    sta VIC_SPRITE_COLOR, x     // color registers are at +n, not +2n

    inx
    cpx #$08
    bne fs_loop
    lda spr_msb
    sta VIC_SPRITE_X_MSB
    rts

x_phase:  .byte $00, $00, $00, $00, $80, $80, $80, $80   // date is half a
y_phase:  .byte $00, $00, $00, $00, $80, $80, $80, $80   // period behind
y_ripple: .byte $00, $28, $50, $78, $00, $28, $50, $78   // 1/4 turn apart
x_place:  .byte $00, $30, $60, $90, $00, $30, $60, $90   // 0/48/96/144
msb_bit:  .byte $01, $02, $04, $08, $10, $20, $40, $80

spr_ramp:                       // the flying logo's colors, cyclic like
    .byte $01, $01, $07, $07    // every other ramp here: white, yellow,
    .byte $0d, $0d, $03, $03    // light green, cyan, light blue, white
    .byte $0e, $0e, $03, $03
    .byte $0d, $0d, $07, $07

//------------------------------------------------------------------
// build_wipe_tabs - vmtab for one step of the closing wipe.
//
// Every entry whose turn has come up is black, the rest are still the
// white the flash left. Both nibbles get the same color because a wiped
// cell has to go out whatever its pixels are doing, and the logo's half
// of the table ($10-$1f) is filled the same way so the letters go with
// everything else rather than hanging in the dark.
//
// Nothing in paint_sweep changes for this: the wipe is entirely a
// question of what is in vmtab.
//------------------------------------------------------------------
build_wipe_tabs:
    ldx #$00
bw_loop:
    lda #$00                    // black: this cell's turn has passed
    cpx wipe_t
    bcc bw_store
    beq bw_store
    lda #$11                    // white in both nibbles: still standing
bw_store:
    sta vmtab, x
    sta vmtab + $10, x
    inx
    cpx #$10
    bne bw_loop
    rts

//------------------------------------------------------------------
// set_text_ramp - choose which ramp the logo is lit through, X = 0 off,
// 1 dim, 2 hot. One patch a phase, not a branch in the 16-entry loop.
//------------------------------------------------------------------
set_text_ramp:
    lda ramp_lo, x
    sta bt_src + 1
    lda ramp_hi, x
    sta bt_src + 2
    rts

ramp_lo:  .byte <text_off, <text_dim, <text_hot
ramp_hi:  .byte >text_off, >text_dim, >text_hot

//------------------------------------------------------------------
// paint_sweep - recolor TWO 256-cell pages of the screen from the
// active field, then leave the sweep on the next pair.
//
// Hi-res needs one byte a cell, not two, so a cell costs 18 cycles here
// against 31 in multicolor and there is room to do two pages in the
// frame instead of one. The screen therefore repaints top to bottom
// every TWO frames while the ramps keep turning - twice the refresh of
// the multicolor version, for about 9200 cycles.
//
// `jsr paint_page_once` followed by falling straight into it is not a
// trick for its own sake: it runs the body twice with one copy of the
// code, and the second run is the fall-through, so the rts at the end
// serves both.
//
// Page 3 is the $2e8 overlap that lands the four pages exactly on 1000
// bytes. It rewrites the tail of page 2, which is harmless, and stops at
// $63e7 - eleven bytes short of the sprite pointers at $63f8.
//------------------------------------------------------------------
paint_sweep:
    jsr paint_page_once
paint_page_once:
    jsr set_page
    ldx #$00
ps_loop:
ps_wave:
    ldy INTRO_WAVE_A, x         // <- patched: field base + page
    lda vmtab, y                // ink in the high nibble, paper in the low
ps_vm:
    sta INTRO_VM, x             // <- patched: video matrix + page
    inx
    bne ps_loop
    inc paint_page
    lda paint_page
    and #$03
    sta paint_page
    rts

//------------------------------------------------------------------
// set_page - patch paint_sweep's two addresses for the current page.
// The fields are page aligned, so the low byte of the page offset can be
// stored into both without any carry handling.
//------------------------------------------------------------------
set_page:
    ldx paint_page
    lda page_lo, x
    sta ps_wave + 1
    sta ps_vm + 1
    lda page_hi, x
    clc
    adc wave_pg
    sta ps_wave + 2
    lda page_hi, x
    clc
    adc #>INTRO_VM
    sta ps_vm + 2
    rts

page_lo:  .byte $00, $00, $00, $e8   // the four page offsets into 1000 bytes
page_hi:  .byte $00, $01, $02, $02

//------------------------------------------------------------------
// flash_field - fill the whole video matrix with vm_byte. Used for the
// initial black-out and for the
// closing white flash, where the whole screen has to reach the same color
// in one pass instead of over the sweep's four frames. At ~13000 cycles it
// still outruns the raster, so the frame it runs in shows it arriving as a
// wipe and the screen is uniform from the next frame on - invisible in a
// white-out, which is the only place it is used while anything is on.
//
// These eight frames are the tightest in the intro. 7168 cycles leaves
// the music player about 5400 of the PAL frame, which is ample, but only
// about 2900 on NTSC. If a heavier tune ever overran it the failure is
// benign - intro_sync simply misses line 250 and waits a frame, so the
// white-out stutters by one frame rather than breaking.
//------------------------------------------------------------------
flash_field:
    ldx #$00
ff_loop:
    lda vm_byte
    sta INTRO_VM, x
    sta INTRO_VM + $100, x
    sta INTRO_VM + $200, x
    sta INTRO_VM + $2e8, x
    inx
    bne ff_loop
    rts

//------------------------------------------------------------------
// intro_to_text - undo everything intro_setup did to the VIC, leaving
// text mode out of bank 0 with the display OFF. start then draws the
// stars and status bar into a screen nobody can see yet and enables DEN.
//
// The music is left running until init_sound zeroes the SID.
//------------------------------------------------------------------
intro_to_text:
    lda #$0b                    // DEN off: nothing shows while we switch
    sta VIC_CONTROL1
    lda CIA2_PORT_A             // back to VIC bank 0
    and #$fc
    ora #$03
    sta CIA2_PORT_A
    lda #$14                    // screen $0400, character ROM at $1000
    sta VIC_MEMORY_SETUP
    lda #$08                    // MCM off, 40 columns, no X scroll
    sta VIC_CONTROL2
    lda #$00                    // the black the demo runs on
    sta VIC_BORDER
    sta VIC_BACKGROUND
    rts

//------------------------------------------------------------------
// This frame's two lookup tables, indexed by a cell's wave value 0-15.
// Rebuilt by build_tabs once a frame.
//------------------------------------------------------------------
// Aligned so the table does not straddle a page boundary: paint_sweep
// reads it with `lda abs,y` 512 times a frame, and a page cross there
// would cost an extra cycle on most cells.
.align $20
vmtab:  .fill 32, 0             // $00-$0f spiral cells, $10-$1f logo cells

//------------------------------------------------------------------
// The color ramp the spiral rotates through. It has to be cyclic - entry
// 15 leads back into entry 0 - or the rotation would jump. This one rises
// black -> blue -> purple -> red -> orange -> yellow -> white and falls
// back, so the bands pulse like embers.
//------------------------------------------------------------------
pal_ramp:
    .byte $00, $06, $04, $02    // black, blue, purple, red
    .byte $08, $07, $01, $01    // orange, yellow, white, white
    .byte $07, $08, $02, $04    // yellow, orange, red, purple
    .byte $06, $00, $00, $00    // blue, then black for a quarter of the cycle

//------------------------------------------------------------------
// The logo's three ramps, indexed by the text mask plus text_phase, and
// selected between by set_text_ramp. These are the ONLY thing that ever
// reaches color RAM, and color RAM is the only thing the logo's pixels
// read, so the letters are lit entirely from here.
//
// Each has to be cyclic for the same reason pal_ramp does. They are laid
// out back to back because ramp_lo/ramp_hi index them as one block.
//------------------------------------------------------------------
dark_ramp:                      // the paper half of every spiral cell:
    .byte $00, $00, $00, $06    // mostly black, with just enough dark blue
    .byte $06, $0b, $0b, $06    // and dark grey moving through it to keep
    .byte $06, $00, $00, $00    // the field from being flat
    .byte $00, $00, $00, $00

text_off:                       // phases A/B/F: engraved, not invisible.
    .byte $00, $00, $06, $06    // Hi-res forces intro_gfx.asm to clear the
    .byte $0b, $0b, $06, $06    // whole of any cell a letter touches, so an
    .byte $00, $00, $06, $06    // all-black ramp here would leave a dead
    .byte $0b, $0b, $06, $00    // black slab lying across the picture. Dark
                                // blue and grey instead make that plate read
                                // as an engraved panel with the logo just
                                // legible in it, waiting to be lit.

text_dim:                       // phase B: half emerged. Muted blue and
    .byte $06, $06, $0b, $0b    // grey - always legible inside the black
    .byte $0c, $0c, $0f, $0f    // outline, but well under the spiral, so
    .byte $0c, $0c, $0b, $0b    // the logo is present without taking over
    .byte $06, $06, $06, $06    // while the bands are still the show

text_hot:                       // phase C: chrome, and every entry bright
    .byte $0e, $03, $0f, $01    // enough to hold against the spiral at
    .byte $01, $01, $07, $07    // full tilt. Light blue -> cyan -> light
    .byte $01, $01, $0f, $03    // grey -> white, with a yellow spark at
    .byte $0e, $0e, $03, $0f    // the peak, then back down
