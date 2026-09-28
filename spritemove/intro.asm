//==================================================================
// INTRO - the opening sequence: music, a retro sunset-grid bitmap, then
// the reveal
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
//     $00-$0f   a backdrop cell, stepping with pal_phase
//     $10-$1f   a logo cell,      stepping with text_phase
//
// build_tabs fills all 32 entries of vmtab, so that one lookup resolves
// both layers. This is how the logo keeps its own ramp, its own rotation
// and its own glint in a mode with no color RAM to give it: the two
// layers are separated per cell instead of per bit pair, and intro_gfx.asm
// clears the backdrop out of any cell a letter touches so nothing bleeds.
//
// The picture is a retro sunset grid, not a spiral tunnel: sunset bands
// in the sky, a perspective checkerboard floor below the horizon, and a
// striped badge sun sat on the line between them (see intro_gfx.asm for
// how each is built - it is all rows, columns and one small circle, no
// polar math anywhere). Swapping which field drives the color changes
// WHICH axis the eye follows - rows, columns or a diagonal - while the
// bitmap itself never moves a single pixel.
//
// THE PHASES
// ----------
//   Z  INTRO_Z_LEN frames  nothing. A black screen while the tune starts.
//                          intro_setup has already blacked the field and
//                          left fade_stage 0, so this phase paints nothing
//                          at all - the screen stays black because nothing
//                          rewrites it
//   T  INTRO_T_LEN frames  the title card: the carving is lit (text ramp
//                          hot) while fade_stage is still 0, so the name,
//                          date and version arrive out of a black screen
//                          with no backdrop behind them. They arrive
//                          exactly where the flying copy will later land,
//                          because this IS the carving it lands into
//   A  INTRO_A_LEN frames  wide horizontal bands (wave field A). The
//                          three band colors come alive one at a time
//                          (fade_stage 1 then 2) UNDERNEATH the lit
//                          title, so the sunset assembles around the
//                          name rather than replacing it
//   B  INTRO_B_LEN frames  vertical column bands (field B) sweep the
//                          floor grid left and right, and the rotation
//                          speed ramps from one step every 8 frames up
//                          to one every frame
//   C  INTRO_C_LEN frames  tight diagonal bands (field C), stepped twice
//                          a frame: a fast glitchy shimmer runs corner
//                          to corner
//   D  INTRO_D_LEN frames  a last burst, then the whole field ramps to
//                          white through intro_flash (a flat constant
//                          fill, so the flash lands in one frame)
//   W  INTRO_W_LEN frames  the white sheet drops as a curtain, top to
//                          bottom, with a per-column glitch stagger, until
//                          the screen is black and the display can be
//                          handed to the balls without the mode switch
//                          ever showing
//
// The logo appears twice and never at the same time. It is lit in the
// carving for T and A - the title card, and the sunset coming up around
// it - then phase B puts the carving out at the same moment the sprite
// copy lifts off it, so the title reads as taking flight. Through B and F
// the carving is a dark, unreadable plate - present and shaped but not
// legible - while the sprites fly. When they switch off at the start of
// C the carving lights to chrome again, so the flying logo reads as
// landing back into the bitmap it started from.
//
// The name is carved and packed at scale 2 (16 x 16 a character) and the
// date and version at scale 1 (8 x 8), so the date reads as small print
// under the title. See intro_gfx.asm for the carve and intro_sprites.asm
// for the flying copy; the two have to agree or the logo would not land
// on itself.
//
// RUN/STOP works throughout: intro_sync calls check_exit every frame.
//
// This used to be a polar spiral tunnel - every phase description above
// once talked about arms, rings and a vortex. See intro_gfx.asm's header
// for why it is a sunset grid instead and what replaced each piece.
//==================================================================

//------------------------------------------------------------------
// play_intro - run the whole opening sequence, then leave the VIC in
// text mode with the display still off, ready for start to draw the
// stars and the status bar before it enables DEN.
//------------------------------------------------------------------
play_intro:
    // The raster bar overture comes FIRST, in plain text mode, and it is
    // what starts the tune (intro_setup used to). See intro_raster.asm: it
    // returns with the screen black and the titles cleared away, so the
    // switch into bitmap mode below is as invisible as the one back out.
    jsr raster_titles

    jsr intro_setup

    //---- Phase Z: nothing at all. The tune starts over a black screen ----
    // intro_setup has already blacked the field and left fade_stage 0, so
    // no painting is needed here - nothing rewrites the screen, so it
    // simply stays black while the music gets going.
    ldx #$00
    jsr set_spiral_ramp         // full brightness: nothing flying yet
    ldx #$00
    jsr set_text_ramp           // and the carving unlit, so truly blank
    lda #>INTRO_WAVE_A
    sta wave_pg
    lda #INTRO_Z_LEN
    sta intro_t
pz_loop:
    jsr intro_sync
    dec intro_t
    bne pz_loop

    //---- Phase T: the title card - name, date and version, on black ----
    // fade_stage is still 0, so every spiral cell stays black; only the
    // logo cells have a live ramp. The letters therefore arrive out of
    // nothing, and they arrive exactly where the flying copy will later
    // land, because this IS the carving it lands into.
    ldx #$01
    jsr set_text_ramp           // hot: the carving lights up
    lda #INTRO_T_LEN
    sta intro_t
pt_loop:
    jsr intro_sync
    inc text_phase              // the glint keeps moving along the letters
    jsr build_tabs
    jsr paint_sweep             // two pages a frame: the title is up in two
    dec intro_t
    bne pt_loop

    //---- Phase A: the sunset blends in around the title ----
    // The logo stays lit right through this: the horizontal bands come up
    // underneath it, so the picture assembles around the name rather than
    // replacing it. Phase B puts the carving out again as the flying copy
    // takes off.
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
    lda intro_t                 // bands speed up gently, 5 frames down to 4
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

    //---- Phase B: the grid scan accelerates, the logo flies in ----
    ldx #$01
    jsr set_spiral_ramp         // the picture holds back for the logo
    ldx #$00
    jsr set_text_ramp           // put the title card out: the carving goes
                                // dark as the flying copy lifts off it, so
                                // there is still only ever one logo lit
    jsr flow_logo_on
    lda #>INTRO_WAVE_B
    sta wave_pg
    lda #INTRO_B_LEN
    sta intro_t
pb_loop:
    jsr intro_sync
    jsr flow_sprites            // sprite registers first, at raster 250
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
    dec intro_t
    bne pb_loop

    //---- Phase F: the plasma field - the picture swims instead of scanning ----
    lda #>INTRO_WAVE_D
    sta wave_pg
    lda #$01
    sta pal_step
    sta pal_tick
    lda #INTRO_F_LEN
    sta intro_t
pf_loop:
    jsr intro_sync
    jsr flow_sprites            // sprite registers first, at raster 250
    jsr advance_palette
    jsr build_tabs
    jsr paint_sweep
    dec intro_t
    bne pf_loop

    //---- Phase C: the flying logo lands - sprites off, carving ignites ----
    lda #$00
    sta VIC_SPRITE_ENABLE       // the only copy left is the one in the bitmap
    lda #>INTRO_WAVE_C          // the tight diagonal field: the shimmer
    sta wave_pg                 // winds up instead of carrying on swimming
    ldx #$00
    jsr set_spiral_ramp         // nothing to read over now: full brightness
    ldx #$01
    jsr set_text_ramp
    lda #INTRO_C_LEN
    sta intro_t
pc_loop:
    jsr intro_sync
    inc text_phase              // glint at double speed too (16 frames a lap)
    inc text_phase
    jsr advance_palette
    jsr advance_palette         // double speed: the shimmer winds up
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
    bcs pd_rotate               // still scanning
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

    //---- Phase W: the white sheet drops as a curtain ----
    lda #$00                    // the sheet is going out, so the frame goes
    sta VIC_BORDER              // with it: phase D left the border white, and
                                // leaving it there would ring the darkening
                                // screen in the brightest thing on display
    lda #>INTRO_WIPE            // the one field that does not repeat
    sta wave_pg
    lda #$05                    // and the border gets the raster bars back:
    jsr rb_set_mode             // mode 5, four bars in a fifty-line slot
    lda #INTRO_W_LEN
    sta intro_t
pw_loop:
    jsr intro_sync

    // The bars are rebuilt BEFORE the paint and displayed AFTER it. There
    // is no other order that works. paint_sweep is 150-162 lines long and
    // the music has already taken the frame to around line 20, so a slot
    // anywhere in the top half leaves the paint running past line 250 -
    // intro_sync then misses its sync and the whole iteration costs two
    // frames, which is one music tick per two frames and an audible drag
    // on the tune. Putting the slot in the TAIL of the frame instead lets
    // the paint have all the room it needs and gives the bars whatever is
    // left: on a light frame the paint ends near 180 and the slot runs its
    // full 205-248, on a heavy one it starts lower and the band is simply
    // shorter. It can never overrun, because it stops at 248 either way.
    lda #INTRO_W_LEN            // squeeze the bars shut as the wipe closes:
    sec                         // gsh 0 -> 3, i.e. +/-32 lines down to +/-4
    sbc intro_t
    lsr
    lsr
    lsr
    sta rb_gsh
    jsr rb_move
    jsr rb_band_build

    lda #INTRO_W_LEN            // wipe_t = (elapsed frames) / 2, so each of
    sec                         // the 16 steps gets the two frames the
    sbc intro_t                 // sweep needs to cover the whole screen
    lsr
    sta wipe_t
    jsr build_wipe_tabs
    jsr paint_sweep
    jsr rb_band                 // ...and the tail of the frame is the bars'
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

    lda #CTRL1_BLANK            // DEN off across the switch: for the ~20
    sta VIC_CONTROL1            // cycles between the bank change and $d018
                                // the VIC would otherwise be in text mode
                                // reading bitmap bytes as a screen. Under
                                // half a scanline and I could not see it,
                                // but this makes it provably invisible.

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

    // The tune is NOT started here any more. raster_titles runs before
    // this and calls MUSIC_INIT itself, so re-initialising it now would
    // restart the song from bar one just as the bitmap arrives.
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
bt_ink:
    lda pal_ramp, y             // <- patched by set_spiral_ramp: full or dim
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
    lda text_off, y             // <- patched by set_text_ramp: off or hot
    asl                         // the letter is the ink, in the HIGH
    asl                         // nibble; see bt_paper below for the LOW
    asl
    asl
    sta temp
bt_paper:
    lda dark_ramp, y            // <- patched by set_text_ramp: dark_ramp
    ora temp                    // while off, black_ramp (i.e. 0) while hot
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
    sta flow_t                  // phase 0 of every sine is the carved
    sta flow_t3                 // position: the name comes up at (88, 187)
    lda #FLOW_T2_HOME           // and the date at (144, 211), exactly where
    sta flow_t2                 // the title card was standing
    lda #$07
    sta ripple_sh               // ripple silent, then eased in over 24 frames
    lda #INTRO_HOLD
    sta flow_hold               // hold that pose before anything moves

    lda #$00                    // MUST be reloaded: the three registers below
    sta VIC_SPRITE_MULTI        // want $00 and the stores used to inherit it
    sta VIC_SPRITE_EXPAND_Y     // from further up. Setting flow_hold broke
    sta VIC_SPRITE_PRIORITY     // that - they got INTRO_HOLD ($96) instead,
                                // i.e. %10010110, so sprites 1, 2, 4 and 7
                                // turned multicolor, Y-expanded and
                                // priority-behind all at once.
    // Put real coordinates in $d000-$d00f BEFORE enabling: until
    // flow_sprites has run they hold whatever the kernal left, which is
    // X=0/Y=0 - invisible only because the side border covers it.
    jsr flow_sprites
    lda #%00001111              // the name only: 8 x 16 data -> 16 x 16 on
    sta VIC_SPRITE_EXPAND_X     // screen. The date's sprites stay 1:1, so
                                // it reads as small print under the title.
    lda #$ff
    sta VIC_SPRITE_ENABLE
    rts

//------------------------------------------------------------------
// flow_sprites - move the eight flying sprites one frame.
//
// Everything comes out of one 256-entry sine table read with a byte
// index, so nothing needs clamping and nothing can leave the screen.
//
//   X   24 + sin(flow_t + group) / 2  ->  24..151, plus the sprite's
//       place in its word - 0/48/96/144 for the X-expanded name, and
//       0/24/48/72 for the 1:1 date. The four sprites of a word stay
//       locked together and the word drifts as a whole.
//
//   Y   FLOW_Y_BASE + sin(flow_t2) / 2  ->  84..211, the word bobbing as
//       ONE body with every sprite sharing the term, so it never comes
//       apart, plus sin(flow_t3 + i/4 turn) / 16, a wobble that runs
//       along the word and makes it undulate. 84..226 all told.
//
// IT OPENS ON THE CARVED POSITION, EXACTLY
// ----------------------------------------
// flow_logo_on parks every phase at 0, and x_phase/y_phase are chosen so
// that phase 0 of each sine IS the spot the logo is carved into the
// bitmap: the name at (88, 187), the date at (144, 211). The carving goes
// dark in the same routine that lights the sprites, so the title does not
// move by a pixel as one copy hands over to the other - it simply stops
// being bitmap and starts being sprites. Get those phases wrong and the
// logo teleports at the handoff, which is what FLOW_Y_BASE exists for:
// the old path topped out at Y 192 and could not reach the carved date at
// all. Check bitmap (px, py) -> sprite (px + 24, py + 51) if the carve
// ever moves.
//
// flow_hold then freezes every counter for INTRO_HOLD frames. Because the
// pose is a point on the same sine path, motion resumes from it
// continuously - the words simply start moving from where they stood. The
// ripple is the one term that cannot start on the path, since no phase
// puts all four sprites at zero at once; ripple_sh fades it in over 24
// frames instead, so it does not snap on at up to 15 pixels.
//
// flow_t runs at 1 a frame, flow_t2 at 2 and flow_t3 at 5, so the drift
// comes round in 5.1 seconds, the bob in 2.6 and the ripple in 1: three
// periods that share no common factor, so the path never repeats inside
// the 8 seconds it is on screen. The name's X phase sits before the
// sine's peak and the date's after it, so the two words drift apart as
// they rise rather than travelling together.
//
// About 850 cycles for all eight.
//
// WHERE THIS MAY BE CALLED FROM
// -----------------------------
// Immediately after intro_sync, while the raster is on line 250 - never
// at the end of the frame's work. Moving a sprite's Y while the raster is
// inside the sprite band drops the sprite for that frame (the Y compare
// never matches, because Y moved from above the raster to below it) or
// draws it twice. The band here tops out at Y = 226 (the name's sprite
// runs 16 rows below that, to 242), so writing at 250 is
// unconditionally clear of it. Called at the end of the work instead, it
// lands around raster 196-205 (measured) - still correct, but by four
// raster lines, and anything that lightened the frame would turn that
// into intermittent letter flicker.
//------------------------------------------------------------------
flow_sprites:
    lda flow_hold               // still holding the entry pose?
    beq fs_advance
    dec flow_hold
    jmp fs_setup                // leave every phase where it is
fs_advance:
    inc flow_t
    inc flow_t2
    inc flow_t2                 // the bob runs at twice the drift rate
    lda flow_t3
    clc
    adc #$05                    // and the ripple faster again
    sta flow_t3

    lda ripple_sh               // ease the ripple in over 24 frames: one
    cmp #$04                    // shift less every 8, 7 -> 4
    beq fs_ripple_full
    lda flow_t
    and #$07
    bne fs_ripple_full
    dec ripple_sh
fs_ripple_full:
fs_setup:
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
    lda #$00                    // while holding, the ripple is switched off
    ldy flow_hold               // entirely: a quarter-period stagger along
    bne fs_ripple_done          // the word is motion, and a title that is
    lda y_ripple, x             // meant to be still must be dead flat
    clc
    adc flow_t3
    tay
    lda INTRO_SIN, y
    ldy ripple_sh               // shift 7 -> 4, i.e. amplitude 1 -> 15.
fs_ripple_shift:                // Suppressed entirely during the hold, this
    lsr                         // would otherwise snap on at up to 15 px the
    dey                         // frame the hold expires - a second, smaller
    bne fs_ripple_shift         // jump right where we just removed the big one
fs_ripple_done:
    sta temp
    lda y_phase, x              // then the WHOLE word: the same term for
    clc                         // all four, which is what keeps it reading
    adc flow_t2                 // as a word instead of loose letters
    tay
    lda INTRO_SIN, y
    lsr                         // 0..127 of travel
    clc
    adc #FLOW_Y_BASE            // 84: the TOP of the flight path, so the
    clc
    adc temp                    // 84..226, never past the visible bottom
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

          // Phase 0 of each sine IS the carved position, so the flying
          // copy comes up exactly where the title card was standing.
          //   name  sin[$00] -> x =  64 + 24 =  88   (carve px  64)
          //   date  sin[$54] -> x = 120 + 24 = 144   (carve px 120)
          //   name  sin[$65] -> y = 103 + 84 = 187   (carve py 136)
          //   date  sin[$40] -> y = 127 + 84 = 211   (carve py 160)
          // The date's X phase is past the sine's peak and the name's is
          // before it, so the two words drift apart rather than together;
          // both Y phases are past the peak, so both rise off the bottom.
x_phase:  .byte $00, $00, $00, $00, $54, $54, $54, $54
y_phase:  .byte $65, $65, $65, $65, $40, $40, $40, $40
y_ripple: .byte $00, $28, $50, $78, $00, $28, $50, $78   // 1/4 turn apart
          // The name is X-expanded so its sprites are 48 px apart; the
          // date is not, so its three-character sprites are 24 px apart.
x_place:  .byte $00, $30, $60, $90, $00, $18, $30, $48
msb_bit:  .byte $01, $02, $04, $08, $10, $20, $40, $80

spr_ramp:                       // The flying logo's colors, and every one
    .byte $03, $03, $03, $03    // of them is a BRIGHT color the BITMAP CANNOT
    .byte $0d, $0d, $0d, $0d    // SHOW. A hi-res sprite has one color and no
    .byte $0a, $0a, $0a, $0a    // way to carry an outline, so the only thing
    .byte $0e, $0e, $0e, $0e    // keeping the letters off the picture is
                                // hue. pal_ramp and dark_ramp between them
                                // use $00,$01,$02,$04,$06,$07,$08,$0b, so the
                                // logo flies in cyan, light green, light red
                                // and light blue and can never sit on its own
                                // color. White went wrong because the bands
                                // are white too; plain green went wrong
                                // because it is as dark as the paper.

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
// set_spiral_ramp - how bright the picture is allowed to be, X = 0 full,
// 1 dimmed.
//
// This exists because of the flying logo. A hi-res sprite has one color
// and cannot carry an outline, so the only thing separating the letters
// from the picture is contrast - and a dithered hi-res field with white
// in it will swallow anything. Rather than fight it with the sprite
// colors, the picture gets out of the way: while the logo flies the ink
// comes from pal_dim, and the moment the sprites switch off it goes back
// to pal_ramp. The intro reads better for it too - the field holds back
// while the logo is the subject, then blazes when the logo lands.
//------------------------------------------------------------------
set_spiral_ramp:
    lda sramp_lo, x
    sta bt_ink + 1
    lda sramp_hi, x
    sta bt_ink + 2
    rts

sramp_lo:  .byte <pal_ramp, <pal_dim
sramp_hi:  .byte >pal_ramp, >pal_dim

//------------------------------------------------------------------
// set_text_ramp - choose which ramp the logo is lit through: X = 0 off,
// X = 1 hot. One patch a phase, not a branch in the 16-entry loop.
//------------------------------------------------------------------
set_text_ramp:
    lda ramp_lo, x
    sta bt_src + 1
    lda ramp_hi, x
    sta bt_src + 2
    lda paper_lo, x
    sta bt_paper + 1
    lda paper_hi, x
    sta bt_paper + 2
    rts

// X = 0 off (the logo is engraved but unlit), X = 1 hot (chrome).
// There is deliberately no half-lit ramp: through A, B and F the flying
// sprite copy is on screen, and lighting the carving at the same time
// would put two logos up at once - the one thing the whole two-copy
// design exists to avoid.
ramp_lo:  .byte <text_off, <text_hot
ramp_hi:  .byte >text_off, >text_hot

// The plate's PAPER, patched alongside the ink. Off, it reads dark_ramp -
// the same dark blue/grey the backdrop's own paper cycles through - so
// the plate blends into the picture around it as one more dark patch
// instead of standing out as a flat black rectangle. Hot, it reads
// black_ramp (all zero): phase C wants the carving at full contrast, the
// one moment it is meant to be read.
paper_lo: .byte <dark_ramp, <black_ramp
paper_hi: .byte >dark_ramp, >black_ramp
black_ramp: .fill 16, 0

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
// in one pass instead of over the sweep's four frames. At 7168 cycles it
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
// selected between by set_text_ramp.
//
// These light the letters entirely, but NOT via color RAM - hi-res bitmap
// mode never reads it. A logo cell is flagged by bit 4 of its cell field
// byte, which sends build_tabs to these ramps instead of pal_ramp; the
// color still arrives in the video matrix nibbles like every other cell.
// That flag is what gives the letters their own color and their own glint
// in a mode with only two colors per cell to spend.
//
// Each has to be cyclic for the same reason pal_ramp does. The index is
// masked to $0f before the read, so a ramp is never read past its own 16
// bytes and they do not have to be contiguous.
//------------------------------------------------------------------
pal_dim:                        // pal_ramp with the brightness taken out,
    .byte $00, $00, $06, $06    // used while the flying logo is on screen so
    .byte $09, $09, $0c, $0c    // the letters have something to read against.
    .byte $09, $09, $06, $06    // Black, blue, brown and grey - none of them
    .byte $00, $00, $00, $00    // a color the logo's sprites ever use.

dark_ramp:                      // the paper half of every spiral cell:
    .byte $00, $00, $00, $06    // mostly black, with just enough dark blue
    .byte $06, $0b, $0b, $06    // and dark grey moving through it to keep
    .byte $06, $00, $00, $00    // the field from being flat
    .byte $00, $00, $00, $00

text_off:                       // phases A/B/F: a dark plate, NOT legible.
    .byte $00, $00, $00, $00    // Hi-res forces intro_gfx.asm to clear the
    .byte $00, $06, $00, $00    // whole of any cell a letter touches, so
    .byte $00, $00, $00, $00    // this ramp sits on a paper that is ALWAYS
    .byte $00, $06, $00, $00    // black (see bt_src below) - it only colors
                                // the letter pixels themselves. Earlier this
                                // ran mid-brightness dark blue/grey, which
                                // read as a fully legible ghost copy of the
                                // text sitting right behind the flying
                                // sprite - confusing, and the opposite of
                                // "unreadable". Near-black with just two
                                // faint pulses a lap keeps the plate reading
                                // as inert while the sprite is the one thing
                                // in this whole phase you can actually read.

text_hot:                       // phase C: chrome, and every entry bright
    .byte $0e, $03, $0f, $01    // enough to hold against the spiral at
    .byte $01, $01, $07, $07    // full tilt. Light blue -> cyan -> light
    .byte $01, $01, $0f, $03    // grey -> white, with a yellow spark at
    .byte $0e, $0e, $03, $0f    // the peak, then back down
