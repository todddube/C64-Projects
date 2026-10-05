//==================================================================
// INTRO - the opening sequence: music, a retro sunset-grid bitmap, the
// title labels floating over it, then a fade into the demo
//
// Imported by main.asm into its code segment. The bitmap and its cell
// field are in intro_gfx.asm, the label sprites in intro_sprites.asm, the
// tune in music.asm.
//
// HOW THE BACKDROP ANIMATES
// -------------------------
// The bitmap never changes. It is a HI-RES picture - 320 x 200, one bit
// per pixel - so a cell has exactly two colors and both come from its
// video matrix byte:
//
//     bit 1  ->  high nibble  (the "ink")
//     bit 0  ->  low  nibble  (the "paper")
//
// Color RAM and $d021 are both unused in this mode, so a cell costs ONE
// byte to recolor. The animation is: leave the picture alone, rewrite the
// 1000 video matrix bytes. paint_sweep does it with one lookup per cell
//
//       ldy field,x : lda vmtab,y : sta vm,x
//
// at 18 cycles a cell - two 256-cell pages a frame, the whole screen
// every two frames, for about 9200 cycles. build_tabs rebuilds the
// 16-entry vmtab each frame from the ramp phase AND the fade level, so a
// fade costs nothing extra: it is just a different table.
//
// The one field (intro_gfx.asm) makes the sky's bands drift up and the
// floor's roll down toward the viewer, both away from the horizon, so the
// sunset streams out from behind the sun. It never switches to another
// field - the old intro cycled through four, and that much change under
// the title was the problem this version fixes.
//
// FADES, NOT CUTS
// ---------------
// Every transition is a brightness fade. bk_lvl (backdrop) and spr_lvl
// (labels) run 0 = black .. 7 = full and step one level every fade_rate
// frames toward bk_goal / spr_goal. A phase just sets the goals; the
// fades run themselves. fade_tab maps (level, color) to a darker color
// of the same family by luminance, so a fade passes through real shades
// - orange to brown to black - instead of snapping.
//
// THE LABELS
// ----------
// The name, the date and the version are sprites (intro_sprites.asm),
// grouped into two bodies: the name (sprites 0-3) and the date with the
// version under it (4-7). Each body is a damped spring on X and Y,
// pulled toward a target that the wander re-picks at random every 2-3
// seconds, inside a box of its own. With the spring critically-ish
// damped (k = 1/512, damping 1/16 a frame: zeta ~0.7) a new target is
// never a jump - the label accelerates, glides, and eases in with a few
// percent of overshoot, and a target that changes mid-glide just bends
// the path. The two bodies retarget on their own timers, so they never
// move in step. A small ripple runs along each word on top.
//
// THE PHASES (lengths in tune ticks - see BeatDec)
// ----------
//   Z  black, the tune gets going
//   T  the labels fade in on black at their home - the title card
//   A  the sunset fades up behind the title, slowly
//   F  the labels lift off and float; the backdrop dims a little so
//      they read against it
//   R  they glide home, settle exactly, and the backdrop comes back up
//   O  everything fades to black together, and the demo takes over
//      from a black screen, so the mode switch never shows
//
// RUN/STOP works throughout: intro_sync calls check_exit every frame.
//==================================================================

//------------------------------------------------------------------
// play_intro - run the whole opening sequence, then leave the VIC in
// text mode with the display still off, ready for start to draw the
// stars and the status bar before it enables DEN.
//------------------------------------------------------------------
play_intro:
    // The raster bar overture comes FIRST, in plain text mode, and it is
    // what starts the tune. See intro_raster.asm: it returns with the
    // screen black and the titles cleared away, so the switch into bitmap
    // mode below is as invisible as the one back out.
    jsr raster_titles

    jsr intro_setup

    //---- Phase Z: black while the tune gets going ----
    lda #INTRO_Z_LEN
    jsr intro_phase

    //---- Phase T: the title card fades in on black ----
    jsr flow_logo_on            // on, but at spr_lvl 0: black on black
    lda #$07
    sta spr_goal
    lda #$04                    // 28 frames up
    sta fade_rate
    lda #INTRO_T_LEN
    jsr intro_phase

    //---- Phase A: the sunset rises behind the title ----
    lda #$07
    sta bk_goal
    lda #$0c                    // a slow sunrise: 84 frames up
    sta fade_rate
    lda #INTRO_A_LEN
    jsr intro_phase

    //---- Phase F: the labels float free ----
    lda #$04                    // hold the picture back so the one-color
    sta bk_goal                 // sprites read against it: at level 4 no
                                // backdrop color is brighter than grey
    lda #$08
    sta fade_rate
    lda #$01
    sta wander_on
    sta wander_t                // the name lifts off first...
    lda #$30
    sta wander_t + 1            // ...the date follows 48 frames later
    lda #INTRO_F_LEN
    jsr intro_phase
    lda #INTRO_F_LEN            // twice: a phase length is one byte
    jsr intro_phase

    //---- Phase R: home again, and the picture comes back up ----
    lda #$00
    sta wander_on               // also eases the ripple back out
    ldx #$03
pr_home:
    lda ax_home, x
    sta ax_tgt, x
    dex
    bpl pr_home
    lda #$01
    sta homing                  // snap the last pixel once they are slow
    lda #$07
    sta bk_goal
    lda #$0c
    sta fade_rate
    lda #INTRO_R_LEN
    jsr intro_phase

    //---- Phase O: everything fades to black together ----
    lda #$00
    sta bk_goal
    sta spr_goal
    lda #$04                    // 28 frames down, inside the 48
    sta fade_rate
    lda #INTRO_O_LEN
    jsr intro_phase

    lda #$00                    // the labels are black by now: switching
    sta VIC_SPRITE_ENABLE       // them off is invisible
    jmp intro_to_text           // tail call: back to text mode, display off

//------------------------------------------------------------------
// intro_phase - run one phase of A tune ticks: sync, labels, paint.
//------------------------------------------------------------------
intro_phase:
    sta intro_t
ip_loop:
    jsr intro_sync
    jsr flow_sprites            // sprite registers first, at the top
    jsr intro_paint
    BeatDec(intro_t)            // in tune ticks, not frames (NTSC)
    bne ip_loop
    rts

//------------------------------------------------------------------
// intro_paint - one frame of the backdrop: fades, ramp, table, sweep.
//------------------------------------------------------------------
intro_paint:
    jsr step_fades
    jsr advance_palette
    jsr build_tabs
    jmp paint_sweep             // tail call

//------------------------------------------------------------------
// intro_setup - black bitmap field, VIC into hi-res bitmap mode out of
// bank 1, every fade at black and both labels parked at home.
//
// The field is painted black *before* the mode switch, so the first thing
// the VIC shows in bitmap mode is a clean black screen rather than
// whatever was in $6000. Everything here is reset, not assumed: R replays
// the whole intro.
//------------------------------------------------------------------
intro_setup:
    lda #$00
    sta VIC_SPRITE_ENABLE       // no sprites until the title card
    sta VIC_BORDER
    sta VIC_BACKGROUND          // unused in hi-res bitmap, kept black so
                                // the switch in and out of the mode is clean
    sta pal_phase
    sta paint_page              // the sweep starts at the top of the screen
    sta bk_lvl                  // everything starts black...
    sta bk_goal
    sta spr_lvl
    sta spr_goal                // ...and stays there until a phase says so
    sta flow_t
    sta flow_t3
    sta wander_on
    sta homing
    lda #$08
    sta ripple_sh               // ripple off: 8 shifts leave nothing
    lda #$05                    // the ramp steps every 5 frames: a slow,
    sta pal_step                // steady stream, never a flicker
    sta pal_tick
    lda #$01
    sta fade_tick
    lda #$04
    sta fade_rate

    ldx #$03                    // both labels at home, at rest
is_home:
    lda ax_home, x
    sta pos_hi, x
    sta ax_tgt, x
    lda #$00
    sta pos_lo, x
    sta vel_lo, x
    sta vel_hi, x
    dex
    bpl is_home

    lda CIA1_TIMER_A_LO         // seed the wander from the free-running
    eor VIC_RASTER              // jiffy timer and the beam, so each run
    ora #$01                    // floats differently. An LFSR must never
    sta rnd                     // hold 0, hence the ora

    jsr flash_field             // all-black field before anything is visible

    lda #CTRL1_BLANK            // DEN off across the switch: for the ~20
    sta VIC_CONTROL1            // cycles between the bank change and $d018
                                // the VIC would otherwise be in text mode
                                // reading bitmap bytes as a screen.

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

    // The tune is NOT started here. raster_titles runs before this and
    // calls MUSIC_INIT itself, so re-initialising it now would restart the
    // song from bar one just as the bitmap arrives.
    rts

//------------------------------------------------------------------
// intro_sync - one frame of housekeeping: lower-border sync, music,
// RUN/STOP. The caller then has the rest of the frame.
//------------------------------------------------------------------
intro_sync:
    lda #$fa                    // same line 250 sync as the main loop
is_wait:
    cmp VIC_RASTER
    bne is_wait
    jsr music_tick              // one tick of the tune, at a fixed raster
    jsr check_exit              // RUN/STOP bails out of the intro
    lda #$fa                    // do not run twice on the same line
is_leave:
    cmp VIC_RASTER
    beq is_leave
    rts

//------------------------------------------------------------------
// advance_palette - age the rotation counter and step the ramp phase.
//------------------------------------------------------------------
advance_palette:
    BeatDec(pal_tick)
    bne ap_done
    lda pal_step                // reload and step the phase on
    sta pal_tick
    inc pal_phase
ap_done:
    rts

//------------------------------------------------------------------
// step_fades - every fade_rate frames, move bk_lvl and spr_lvl one level
// toward their goals. Animation, not timing, so a plain dec.
//------------------------------------------------------------------
step_fades:
    dec fade_tick
    bne sf_done
    lda fade_rate
    sta fade_tick
    lda bk_lvl
    cmp bk_goal
    beq sf_spr
    bcc sf_bk_up
    dec bk_lvl
    jmp sf_spr
sf_bk_up:
    inc bk_lvl
sf_spr:
    lda spr_lvl
    cmp spr_goal
    beq sf_done
    bcc sf_spr_up
    dec spr_lvl
    rts
sf_spr_up:
    inc spr_lvl
sf_done:
    rts

//------------------------------------------------------------------
// build_tabs - this frame's 16-entry lookup table for paint_sweep.
//
//   ink    pal_ramp at the cell's ramp position, high nibble
//   paper  dark_ramp half a turn behind, low nibble - mostly black, so
//          the pattern sits on a dark field the way $d021 did in
//          multicolor (hi-res has no background color to anchor it)
//
// Both pass through fade_tab at bk_lvl, so the fade is folded into the
// same table the rotation is. ~16 x 60 cycles: about 1000 a frame.
//------------------------------------------------------------------
build_tabs:
    lda bk_lvl                  // level * 16: the row of fade_tab to read
    asl
    asl
    asl
    asl
    sta bk_off
    ldx #$00
bt_loop:
    txa                         // this entry's place in the ramp
    clc
    adc pal_phase
    and #$0f
    sta temp2
    tay
    lda pal_ramp, y             // the ink...
    ora bk_off
    tay
    lda fade_hi, y              // ...faded, already in the high nibble
    sta temp
    lda temp2                   // the paper, half a turn behind
    clc
    adc #$08
    and #$0f
    tay
    lda dark_ramp, y
    ora bk_off
    tay
    lda fade_tab, y
    ora temp
    sta vmtab, x
    inx
    cpx #$10
    bne bt_loop
    rts

//------------------------------------------------------------------
// flow_logo_on - point the VIC at the label sprites and switch them on.
//
// The sprite pointers live at $63f8, the last eight bytes of the video
// matrix page. paint_sweep and flash_field both stop at $63e7, so they
// can never walk over them. Called at spr_lvl 0, so the labels come on
// black and fade up from there.
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
    sta VIC_SPRITE_MULTI        // hi-res, one color each
    sta VIC_SPRITE_EXPAND_Y
    sta VIC_SPRITE_PRIORITY     // in front of the picture
    // Put real coordinates in $d000-$d00f BEFORE enabling: until
    // flow_sprites has run they hold whatever the kernal left.
    jsr flow_sprites
    lda #%00001111              // the name only: 8 x 16 data -> 16 x 16 on
    sta VIC_SPRITE_EXPAND_X     // screen. The date's sprites stay 1:1, so
                                // it reads as small print under the title.
    lda #$ff
    sta VIC_SPRITE_ENABLE
    rts

//------------------------------------------------------------------
// flow_sprites - write the eight label sprites, then move the labels on
// for next frame.
//
//   X   the body's X + the sprite's place in its word (0/48/96/144 for
//       the X-expanded name, 0/24/48/72 for the 1:1 date block)
//   Y   the body's Y + a ripple: sin(flow_t3 + a quarter turn per
//       sprite) >> ripple_sh, so a wave runs along the word. ripple_sh 8
//       is flat; the wander eases it to 6 (0..3 px) and back
//   col a hue that walks along the word, through fade_tab at spr_lvl
//
// The registers are written FIRST, from last frame's positions, and the
// springs run after. That keeps every write right after intro_sync, at
// the top of the frame: below the lowest label (the date's last row is
// at most line 244) and far above the highest (Y 57). Moving a
// sprite's Y while the raster is inside it drops or doubles it for a
// frame. One frame of latency in where a label is drawn is invisible.
//------------------------------------------------------------------
flow_sprites:
    lda spr_lvl                 // level * 16: the row of fade_tab to read
    asl
    asl
    asl
    asl
    sta spr_off
    lda #$00
    sta spr_msb
    ldx #$00
fs_loop:
    stx temp2                   // temp2 = sprite number n

    //---- X: the body, then this sprite's place in the word ----
    ldy spr_ax_x, x
    lda pos_hi, y
    clc
    adc x_place, x
    sta temp                    // X low byte (sta leaves the carry alone,
    bcc fs_no_msb               // so it still says whether we passed 255)
    lda msb_bit, x
    ora spr_msb
    sta spr_msb
fs_no_msb:
    txa
    asl                         // sprite n's X/Y registers are at +2n
    tay
    lda temp
    sta VIC_SPRITE_X, y

    //---- Y: the body, plus the ripple running along the word ----
    lda y_ripple, x
    clc
    adc flow_t3
    tay
    lda INTRO_SIN, y
    ldy ripple_sh
fs_ripple:
    lsr
    dey
    bne fs_ripple
    ldy spr_ax_y, x
    clc
    adc pos_hi, y
    sta temp
    txa
    asl
    tay
    lda temp
    sta VIC_SPRITE_Y, y

    //---- color: the hue walks along the word, then the fade ----
    lda flow_t
    lsr
    lsr
    lsr                         // a new hue every 8 frames
    clc
    adc temp2                   // ...offset along the word
    and #$0f
    tay
    lda spr_ramp, y
    ora spr_off
    tay
    lda fade_tab, y
    sta VIC_SPRITE_COLOR, x     // color registers are at +n, not +2n

    inx
    cpx #$08
    bne fs_loop
    lda spr_msb
    sta VIC_SPRITE_X_MSB
    // fall through: move the labels on for next frame

//------------------------------------------------------------------
// wander - next frame's label positions: retarget, ripple, springs.
//------------------------------------------------------------------
wander:
    inc flow_t
    lda flow_t3
    clc
    adc #$03                    // the ripple: one lap every 85 frames
    sta flow_t3

    lda flow_t                  // ease the ripple every 16 frames: in to
    and #$0f                    // 6 while wandering, out to 8 (flat) when
    bne wd_ripple_done          // not, so it never snaps on or off
    lda wander_on
    beq wd_ripple_out
    lda ripple_sh
    cmp #$06
    beq wd_ripple_done
    dec ripple_sh
    jmp wd_ripple_done
wd_ripple_out:
    lda ripple_sh
    cmp #$08
    beq wd_ripple_done
    inc ripple_sh
wd_ripple_done:

    lda wander_on
    beq wd_springs
    ldx #$01                    // body 1 (date), then body 0 (name)
wd_body:
    dec wander_t, x
    bne wd_next_body
    jsr rnd_next                // the next pick comes in 110..173 frames:
    and #$3f                    // never a beat, so the two bodies drift
    clc                         // in and out of step
    adc #110
    sta wander_t, x
    stx temp2
    txa
    asl
    tax                         // X = this body's X axis (0 or 2)
    jsr pick_target
    jsr rnd_next                // two throwaway steps: consecutive LFSR
    jsr rnd_next                // outputs are 2x apart, which would lay
                                // every X/Y pair on a few diagonals
    inx                         // and its Y axis (1 or 3)
    jsr pick_target
    ldx temp2
wd_next_body:
    dex
    bpl wd_body

wd_springs:
    ldx #$03
wd_axis:
    jsr spring
    dex
    bpl wd_axis
    rts

//------------------------------------------------------------------
// pick_target - a random target for axis X inside its box:
// ax_min + rnd mod ax_rng.
//------------------------------------------------------------------
pick_target:
    jsr rnd_next
pt_mod:
    cmp ax_rng, x
    bcc pt_in
    sbc ax_rng, x               // carry is set: plain subtract
    jmp pt_mod
pt_in:
    clc
    adc ax_min, x
    sta ax_tgt, x
    rts

//------------------------------------------------------------------
// rnd_next - step the 8-bit Galois LFSR (x^8 + x^4 + x^3 + x^2 + 1).
// Period 255, every value except 0. Returns it in A.
//------------------------------------------------------------------
rnd_next:
    lda rnd
    asl
    bcc rn_done
    eor #$1d
rn_done:
    sta rnd
    rts

//------------------------------------------------------------------
// spring - one frame of axis X: a damped spring toward ax_tgt.
//
//   accel = (target - pos) / 512          in px/frame^2
//   vel   = vel + accel - vel / 16
//   pos   = pos + vel
//
// pos and vel are 8.8 fixed point (pixel . fraction), vel signed. The
// pull is worked out from whole pixels: target - pos_hi is a 9-bit
// signed difference (the carry is its inverted sign), and halving it
// lands it in a signed byte - which, read as 1/256 px, IS diff / 512.
//
// k = 1/512 and damping 1/16 give zeta ~0.7: the label eases in with a
// few percent of overshoot and settles in about two seconds. Peak speed
// across the widest box is ~4 px a frame.
//
// While homing, an axis within -2..+1 px of its target and nearly still
// (|vel| < 1/4 px) is snapped onto it and stopped, so the labels come to
// rest exactly at home and not a fraction of a pixel off it.
//------------------------------------------------------------------
spring:
    lda homing
    beq sp_pull
    lda ax_tgt, x               // diff in -2..1? The pull rounds toward
    sec                         // minus infinity, so -2 and -1 are rest
    sbc pos_hi, x               // points as well as 0 and +1: a window of
    clc                         // -1..1 could leave a label parked 2 px
    adc #$02                    // off home for good
    cmp #$04
    bcs sp_pull
    lda vel_hi, x               // |vel| < 1/4 px?
    beq sp_slow_pos
    cmp #$ff
    bne sp_pull
    lda vel_lo, x
    cmp #$c0
    bcc sp_pull
    bcs sp_snap
sp_slow_pos:
    lda vel_lo, x
    cmp #$40
    bcs sp_pull
sp_snap:
    lda ax_tgt, x
    sta pos_hi, x
    lda #$00
    sta pos_lo, x
    sta vel_lo, x
    sta vel_hi, x
    rts

sp_pull:
    lda ax_tgt, x
    sec
    sbc pos_hi, x
    bcc sp_neg
    lsr                         // diff >= 0: diff / 2, 0..127
    ldy #$00
    beq sp_accel
sp_neg:
    sec                         // diff < 0: shift the sign back in
    ror
    ldy #$ff
sp_accel:
    clc                         // vel += accel, sign-extended through Y
    adc vel_lo, x
    sta vel_lo, x
    tya
    adc vel_hi, x
    sta vel_hi, x

    lda vel_hi, x               // temp2:temp = vel >> 4, arithmetic
    sta temp2
    lda vel_lo, x
    sta temp
    ldy #$04
sp_asr:
    lda temp2
    cmp #$80                    // carry = the sign bit
    ror temp2
    ror temp
    dey
    bne sp_asr

    sec                         // vel -= vel / 16: the damping
    lda vel_lo, x
    sbc temp
    sta vel_lo, x
    lda vel_hi, x
    sbc temp2
    sta vel_hi, x

    clc                         // pos += vel
    lda pos_lo, x
    adc vel_lo, x
    sta pos_lo, x
    lda pos_hi, x
    adc vel_hi, x
    sta pos_hi, x
    rts

//------------------------------------------------------------------
// The two label bodies, one entry per axis:
//   0 name X   1 name Y   2 date X   3 date Y
// Reset by intro_setup on every run (R replays the intro).
//------------------------------------------------------------------
pos_lo:     .fill 4, 0
pos_hi:     .fill 4, 0
vel_lo:     .fill 4, 0
vel_hi:     .fill 4, 0
ax_tgt:     .fill 4, 0
wander_t:   .fill 2, 0          // frames until each body's next target
wander_on:  .byte 0             // nonzero while the labels float free
homing:     .byte 0             // nonzero: snap onto the target when close
bk_off:     .byte 0             // bk_lvl * 16, for build_tabs
spr_off:    .byte 0             // spr_lvl * 16, for flow_sprites

ax_home:    .byte NAME_HOME_X, NAME_HOME_Y, DATE_HOME_X, DATE_HOME_Y
ax_min:     .byte NAME_MIN_X,  NAME_MIN_Y,  DATE_MIN_X,  DATE_MIN_Y
ax_rng:     .byte NAME_RNG_X,  NAME_RNG_Y,  DATE_RNG_X,  DATE_RNG_Y

// Per sprite: which axes carry it, its place in the word, its $d010 bit
// and its ripple phase (an eighth of a turn apart along the word, so
// neighbouring sprites differ by a pixel or so and the word bends
// rather than breaking into steps).
spr_ax_x: .byte 0, 0, 0, 0, 2, 2, 2, 2
spr_ax_y: .byte 1, 1, 1, 1, 3, 3, 3, 3
          // The name is X-expanded so its sprites are 48 px apart; the
          // date is not, so its three-character sprites are 24 px apart.
x_place:  .byte $00, $30, $60, $90, $00, $18, $30, $48
msb_bit:  .byte $01, $02, $04, $08, $10, $20, $40, $80
y_ripple: .byte $00, $20, $40, $60, $00, $20, $40, $60

spr_ramp:                       // The labels' colors, and every one of them
    .byte $03, $03, $03, $03    // is a BRIGHT color the backdrop never
    .byte $0d, $0d, $0d, $0d    // shows. A hi-res sprite has one color and
    .byte $01, $01, $01, $01    // no outline, so hue and brightness are all
    .byte $0e, $0e, $0e, $0e    // that keeps the letters off the picture:
                                // cyan, light green, white and light blue,
                                // over a sunset of reds and oranges that
                                // phase F dims to no brighter than grey.

//------------------------------------------------------------------
// paint_sweep - recolor TWO 256-cell pages of the screen from the
// field, then leave the sweep on the next pair.
//
// `jsr paint_page_once` followed by falling straight into it runs the
// body twice with one copy of the code; the rts at the end serves both.
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
    ldy INTRO_WAVE_A, x         // <- patched: field + page
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
// The field is page aligned, so the low byte of the page offset can be
// stored into both without any carry handling.
//------------------------------------------------------------------
set_page:
    ldx paint_page
    lda page_lo, x
    sta ps_wave + 1
    sta ps_vm + 1
    lda page_hi, x
    clc
    adc #>INTRO_WAVE_A
    sta ps_wave + 2
    lda page_hi, x
    clc
    adc #>INTRO_VM
    sta ps_vm + 2
    rts

page_lo:  .byte $00, $00, $00, $e8   // the four page offsets into 1000 bytes
page_hi:  .byte $00, $01, $02, $02

//------------------------------------------------------------------
// flash_field - fill the whole video matrix with black, before the
// bitmap is switched on.
//------------------------------------------------------------------
flash_field:
    lda #$00
    ldx #$00
ff_loop:
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
// This frame's lookup table, indexed by a cell's field value 0-15.
// Rebuilt by build_tabs once a frame. Aligned so paint_sweep's 512
// `lda vmtab,y` a frame never cross a page.
//------------------------------------------------------------------
.align $10
vmtab:  .fill 16, 0

//------------------------------------------------------------------
// The backdrop's color ramp. It has to be cyclic - entry 15 leads back
// into entry 0 - or the rotation would jump. Black -> blue -> purple ->
// red -> orange -> yellow -> white and back, so the bands pulse like
// embers.
//------------------------------------------------------------------
pal_ramp:
    .byte $00, $06, $04, $02    // black, blue, purple, red
    .byte $08, $07, $01, $01    // orange, yellow, white, white
    .byte $07, $08, $02, $04    // yellow, orange, red, purple
    .byte $06, $00, $00, $00    // blue, then black for a quarter of the cycle

dark_ramp:                      // the paper half of every cell: mostly
    .byte $00, $00, $00, $06    // black, with just enough dark blue and
    .byte $06, $0b, $0b, $06    // dark grey moving through it to keep the
    .byte $06, $00, $00, $00    // field from being flat
    .byte $00, $00, $00, $00

//------------------------------------------------------------------
// fade_tab[level * 16 + color] - color dimmed to level/7 of its
// brightness, staying inside its own family so a fade passes through
// real shades of the same hue. fade_hi is the same table pre-shifted
// into the high nibble, for build_tabs' ink.
//
// Luminance is the usual 0-32 scale (Pepto's measurements, rounded);
// each family lists its colors dark to bright, and a level picks the
// family member nearest the target luminance without going brighter
// than the color itself.
//------------------------------------------------------------------
.var FADE_LUMA = List().add(0, 32, 10, 20, 12, 16, 8, 24, 12, 8, 16, 10, 15, 24, 15, 20)
.var FADE_FAM = List()
.eval FADE_FAM.add(List().add(0))                       // 0 black
.eval FADE_FAM.add(List().add(0, 11, 12, 15, 1))        // 1 white
.eval FADE_FAM.add(List().add(0, 9, 2))                 // 2 red
.eval FADE_FAM.add(List().add(0, 6, 14, 3))             // 3 cyan
.eval FADE_FAM.add(List().add(0, 6, 4))                 // 4 purple
.eval FADE_FAM.add(List().add(0, 11, 5))                // 5 green
.eval FADE_FAM.add(List().add(0, 6))                    // 6 blue
.eval FADE_FAM.add(List().add(0, 9, 8, 10, 7))          // 7 yellow
.eval FADE_FAM.add(List().add(0, 9, 8))                 // 8 orange
.eval FADE_FAM.add(List().add(0, 9))                    // 9 brown
.eval FADE_FAM.add(List().add(0, 9, 2, 10))             // 10 light red
.eval FADE_FAM.add(List().add(0, 11))                   // 11 dark grey
.eval FADE_FAM.add(List().add(0, 11, 12))               // 12 grey
.eval FADE_FAM.add(List().add(0, 11, 5, 13))            // 13 light green
.eval FADE_FAM.add(List().add(0, 6, 14))                // 14 light blue
.eval FADE_FAM.add(List().add(0, 11, 12, 15))           // 15 light grey

.function fade_color(c, lvl) {
    .var want = FADE_LUMA.get(c) * lvl / 7
    .var fam = FADE_FAM.get(c)
    .var best = 0
    .var bestd = 999
    .for (var i = 0; i < fam.size(); i++) {
        .var m = fam.get(i)
        .var d = abs(FADE_LUMA.get(m) - want)
        .if (d < bestd) {
            .eval best = m
            .eval bestd = d
        }
    }
    .return best
}

fade_tab:
.for (var lvl = 0; lvl < 8; lvl++) {
    .for (var c = 0; c < 16; c++) { .byte fade_color(c, lvl) }
}
fade_hi:
.for (var lvl = 0; lvl < 8; lvl++) {
    .for (var c = 0; c < 16; c++) { .byte fade_color(c, lvl) << 4 }
}
