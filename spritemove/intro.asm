//==================================================================
// INTRO - the opening sequence after the raster bar overture: the
// title labels on black, a pause, then vertical raster bars sweeping
// sideways while the labels float, and a fade into the demo
//
// Imported by main.asm into its code segment. The label sprites are in
// intro_sprites.asm, the tune in music.asm. The overture before this is
// intro_raster.asm, and it leaves exactly what this needs: text mode out
// of VIC bank 0, a screen of spaces, every color black, the tune playing.
//
// VERTICAL BARS IN TEXT MODE
// --------------------------
// The overture's bars are horizontal: one color per RASTER LINE, written
// as the beam passes. Vertical bars are the other axis - one color per
// COLUMN - and a column is something text mode already has. Fill the
// screen with the solid block (screen code $a0, reverse space) and every
// cell shows nothing but its color RAM nibble, so
//
//     col_buf[x]  ->  color RAM, every row, column x
//
// is the whole effect. bars_build draws five shaded bars into the 40-byte
// col_buf from sines, and two unrolled copies spread it down the screen.
// No raster polling at all, so the frame has room for the labels too.
//
// RACING THE BEAM, NOT DOUBLE BUFFERING
// -------------------------------------
// Color RAM is at a fixed address; it cannot be double buffered. So the
// copy is split and timed against the beam instead:
//
//   sync at line 250
//   flow_sprites   sprite registers, below every label           ~800
//   copy_rows0     rows 0-5,   needed by line 51                 ~1560
//   copy_rows6     rows 6-12,  needed by line 99                 ~1760
//   music_tick     the tune, check_exit                          ~1800
//   copy_rows13    rows 13-24, needed by line 155                ~2760
//   wander         next frame's label positions                  ~600
//   bars_build     next frame's col_buf                          ~1200
//
// Each block is column by column, so its TOP row is the last one
// finished: rows 0-12 as one block measured done at NTSC line 56, five
// lines after row 0 starts drawing. Three blocks put the deadline on
// each block's top row instead, and every one is met with margin.
//
// About 10500 cycles of the NTSC frame's 17095, and the beam never
// overtakes a write: every row shows one frame's col_buf, never half of
// two. On PAL the vertical blank is 49 lines longer, so it only gets
// easier.
//
// THE LABELS
// ----------
// The name, the date and the version are sprites (intro_sprites.asm),
// grouped into two bodies: the name (sprites 0-3) and the date with the
// version under it (4-7). Each body is a damped spring on X and Y,
// pulled toward a target that the wander re-picks at random every 2-3
// seconds, inside a box of its own. With k = 1/512 and damping 1/16 a
// frame (zeta ~0.7) a new target is never a jump - the label accelerates,
// glides, and eases in with a few percent of overshoot, and a target that
// changes mid-glide just bends the path. The two bodies retarget on their
// own timers, so they never move in step. A small ripple runs along each
// word on top.
//
// FADES, NOT CUTS
// ---------------
// bk_lvl (the bars) and spr_lvl (the labels) run 0 = black .. 7 = full
// and step one level every fade_rate frames toward bk_goal / spr_goal.
// A phase just sets the goals. fade_tab maps (level, color) to a darker
// shade of the same hue, so a bar fades blue -> dark blue -> black
// rather than snapping.
//
// THE PHASES (lengths in tune ticks - see BeatDec)
// ----------
//   Z  black: a breath after the overture
//   T  the labels fade in on black at their home, then hold - the title
//      card, with nothing behind it
//   F  the bars fade in and sweep, and the labels lift off and float
//   R  the labels glide home and settle exactly; the bars keep going
//   O  bars and labels fade to black together, and the demo takes over
//      from a black screen
//
// RUN/STOP works throughout: every frame calls check_exit.
//==================================================================

//------------------------------------------------------------------
// play_intro - the overture, then the sequence above. Returns in text
// mode out of bank 0 with the display OFF and a screen of spaces, ready
// for start to draw the stars and the status bar before it enables DEN.
//------------------------------------------------------------------
play_intro:
    // The raster bar overture comes FIRST, and it is what starts the tune.
    // See intro_raster.asm: it returns with the screen black and the
    // titles cleared away.
    jsr raster_titles

    jsr intro_setup

    //---- Phase Z: a breath of black after the overture ----
    lda #INTRO_Z_LEN
    jsr intro_phase

    //---- Phase T: the title card fades in on black, then holds ----
    jsr flow_logo_on            // on, but at spr_lvl 0: black on black
    lda #$07
    sta spr_goal
    lda #$04                    // 28 frames up, then the pause
    sta fade_rate
    lda #INTRO_T_LEN
    jsr intro_phase

    //---- Phase F: the bars come up and the labels float free ----
    lda #$07
    sta bk_goal
    lda #$08                    // the bars fade in over ~1 s while they move
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

    //---- Phase R: the labels glide home ----
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

    jmp intro_to_text           // tail call: sprites off, screen cleared

//------------------------------------------------------------------
// intro_phase - run one phase of A tune ticks. One frame is the
// beam-raced sequence described in the header; the order matters.
//------------------------------------------------------------------
intro_phase:
    sta intro_t
ip_loop:
    jsr intro_sync              // line 250
    jsr flow_sprites            // sprite registers, below every label
    jsr copy_rows0              // rows 0-5 ahead of the beam
    jsr copy_rows6              // rows 6-12
    jsr music_tick              // one tick of the tune
    jsr check_exit              // RUN/STOP bails out of the intro
    jsr copy_rows13             // rows 13-24
    jsr wander                  // next frame's label positions
    jsr step_fades
    jsr bars_move
    jsr bars_build              // next frame's col_buf
    BeatDec(intro_t)            // in tune ticks, not frames (NTSC)
    bne ip_loop
    rts

//------------------------------------------------------------------
// intro_setup - a screen of solid blocks in black, every fade at black,
// both labels parked at home, the bars at their starting phases.
//
// Everything here is reset, not assumed: R replays the whole intro.
// The overture left color RAM black, so filling the screen with blocks
// is invisible - black blocks on a black background.
//------------------------------------------------------------------
intro_setup:
    lda #$00
    sta VIC_SPRITE_ENABLE       // no sprites until the title card
    sta VIC_BORDER
    sta VIC_BACKGROUND
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

    ldx #BAR_COUNT - 1          // every bar back at its starting phase
is_bars:
    lda #$00
    sta bar_ph_lo, x
    lda bar_off, x
    sta bar_ph_hi, x
    dex
    bpl is_bars

    lda CIA1_TIMER_A_LO         // seed the wander from the free-running
    eor VIC_RASTER              // jiffy timer and the beam, so each run
    ora #$01                    // floats differently. An LFSR must never
    sta rnd                     // hold 0, hence the ora

    ldx #$00                    // col_buf, color RAM and the screen: black
    txa                         // everywhere, so the blocks go in unseen
is_col:
    sta col_buf, x
    inx
    cpx #40
    bne is_col
    ldx #$00
is_screen:
    lda #$00
    sta COLOR_RAM, x
    sta COLOR_RAM + $100, x
    sta COLOR_RAM + $200, x
    sta COLOR_RAM + $2e8, x
    lda #$a0                    // reverse space: a solid 8 x 8 block in its
    sta SCREEN_RAM, x           // color RAM color. Stops at $07e7, short of
    sta SCREEN_RAM + $100, x    // the sprite pointers at $07f8
    sta SCREEN_RAM + $200, x
    sta SCREEN_RAM + $2e8, x
    inx
    bne is_screen
    rts

//------------------------------------------------------------------
// intro_sync - wait for line 250. The frame's work follows in
// intro_phase, in the order the beam needs it.
//------------------------------------------------------------------
intro_sync:
    lda #$fa
is_wait:
    cmp VIC_RASTER
    bne is_wait
    rts

//------------------------------------------------------------------
// copy_rows0 / copy_rows6 / copy_rows13 - col_buf down a block of rows
// of color RAM, column by column, unrolled over the rows: 5 cycles a
// cell. Split three ways so each block is done before the beam reaches
// its first row (see the header).
//------------------------------------------------------------------
.macro CopyRows(first, last) {
    ldx #39
loop:
    lda col_buf, x
    .for (var r = first; r <= last; r++) {
        sta COLOR_RAM + r * 40, x
    }
    dex
    bpl loop
    rts
}
copy_rows0:     CopyRows(0, 5)
copy_rows6:     CopyRows(6, 12)
copy_rows13:    CopyRows(13, 24)

//------------------------------------------------------------------
// bars_move - advance every bar's 8.8 phase by its own speed. The
// speeds are fractions of a sine step a frame, so a bar's widest swing
// takes several seconds and its fastest moment is under half a column a
// frame: at character resolution any faster reads as jumping.
//------------------------------------------------------------------
bars_move:
    ldx #BAR_COUNT - 1
bm_loop:
    lda bar_ph_lo, x
    clc
    adc bar_spd, x
    sta bar_ph_lo, x
    lda bar_ph_hi, x
    adc #$00
    sta bar_ph_hi, x
    dex
    bpl bm_loop
    rts

//------------------------------------------------------------------
// bars_build - draw this frame's bars into col_buf.
//
// A bar's left column is
//
//     left = ctr + asr(sin(ph) - 128, sh) - BAR_W / 2
//
// as a SIGNED byte, so a bar can hang off either edge: a cell is drawn
// only when left + i is under 40, and a negative column, read unsigned,
// is 128 or more and fails that same test - one compare clips both
// sides. Later bars are drawn over earlier ones, so they pass in front.
// Every color goes through fade_tab at bk_lvl on the way in.
//------------------------------------------------------------------
bars_build:
    lda bk_lvl                  // level * 16: the row of fade_tab to read
    asl
    asl
    asl
    asl
    sta bk_off
    lda #$00                    // black between the bars
    ldx #39
bb_clear:
    sta col_buf, x
    dex
    bpl bb_clear

    ldx #$00
bb_bar:
    stx bar_i
    ldy bar_ph_hi, x
    lda INTRO_SIN, y            // 0..255 ...
    sec
    sbc #$80                    // ...as -128..127, centred on ctr
    ldy bar_sh, x
bb_shift:
    cmp #$80                    // carry = sign
    ror                         // arithmetic shift right
    dey
    bne bb_shift
    clc
    adc bar_ctr, x              // ctr already has BAR_W / 2 taken off
    sta bar_x                   // the left column, signed

    lda bar_strip, x            // this bar's shading, BAR_W colors
    tay
    ldx bar_x
    lda #BAR_W
    sta bar_n
bb_cell:
    cpx #40                     // off either edge: skip the cell
    bcs bb_skip
    lda bar_shades, y
    ora bk_off
    sty temp
    tay
    lda fade_tab, y
    sta col_buf, x
    ldy temp
bb_skip:
    inx
    iny
    dec bar_n
    bne bb_cell

    ldx bar_i
    inx
    cpx #BAR_COUNT
    bne bb_bar
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
// flow_logo_on - point the VIC at the label sprites and switch them on.
// Called at spr_lvl 0, so the labels come on black and fade up.
//------------------------------------------------------------------
flow_logo_on:
    ldx #$07
flo_ptr:
    txa
    clc
    adc #INTRO_SPR_PTR          // block $30 + n
    sta SPRITE_PTRS, x
    dex
    bpl flo_ptr
    lda #$00
    sta VIC_SPRITE_MULTI        // hi-res, one color each
    sta VIC_SPRITE_EXPAND_Y
    sta VIC_SPRITE_PRIORITY     // in front of the bars
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
// flow_sprites - write the eight label sprites from the current body
// positions.
//
//   X   the body's X + the sprite's place in its word (0/48/96/144 for
//       the X-expanded name, 0/24/48/72 for the 1:1 date block)
//   Y   the body's Y + a ripple: sin(flow_t3 + an eighth of a turn per
//       sprite) >> ripple_sh, so a wave runs along the word. ripple_sh 8
//       is flat; the wander eases it to 6 (0..3 px) and back
//   col a hue that walks along the word, through fade_tab at spr_lvl
//
// Called first thing after the line-250 sync: below the lowest label
// (the date's last row is at most line 244) and far above the highest
// (Y 56). Moving a sprite's Y while the raster is inside it drops or
// doubles it for a frame.
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
    rts

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
// across the widest box is ~3 px a frame.
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
// intro_to_text - hand the machine to the demo: display off, sprites
// off, a screen of spaces, text mode out of bank 0. start then draws the
// stars and status bar into a screen nobody can see yet and enables DEN.
// The blocks go with DEN off - everything is black by now anyway.
//
// The music is left running until init_sound zeroes the SID.
//------------------------------------------------------------------
intro_to_text:
    lda #CTRL1_BLANK            // DEN off: nothing shows while we clear
    sta VIC_CONTROL1
    lda #$00
    sta VIC_SPRITE_ENABLE       // the labels are black by now
    sta VIC_SPRITE_EXPAND_X     // the balls are never expanded
    sta VIC_BORDER              // the black the demo runs on
    sta VIC_BACKGROUND
    ldx #$00
itt_clear:
    lda #$20                    // start cleared the screen BEFORE the
    sta SCREEN_RAM, x           // intro and does not do it again, so the
    sta SCREEN_RAM + $100, x    // blocks have to go here
    sta SCREEN_RAM + $200, x
    sta SCREEN_RAM + $2e8, x
    lda #$00
    sta COLOR_RAM, x
    sta COLOR_RAM + $100, x
    sta COLOR_RAM + $200, x
    sta COLOR_RAM + $2e8, x
    inx
    bne itt_clear
    lda CIA2_PORT_A             // VIC bank 0 - the overture set it already;
    and #$fc                    // restated so this does not depend on it
    ora #$03
    sta CIA2_PORT_A
    lda #$14                    // screen $0400, character ROM at $1000
    sta VIC_MEMORY_SETUP
    lda #$08                    // MCM off, 40 columns, no X scroll
    sta VIC_CONTROL2
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
bk_off:     .byte 0             // bk_lvl * 16, for bars_build
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

spr_ramp:                       // The labels' colors: white, yellow, cyan
    .byte $01, $01, $01, $01    // and light green, the four brightest the
    .byte $07, $07, $07, $07    // machine has. A hi-res sprite has one color
    .byte $03, $03, $03, $03    // and no outline, so brightness is what
    .byte $0d, $0d, $0d, $0d    // keeps the letters off the bars - and
                                // bar_shades below never goes brighter
                                // than light blue / light red / green.

//------------------------------------------------------------------
// The vertical bars. Five of them, each BAR_W columns of shading from
// dark edge to mid-bright core, so a bar reads as a rounded tube and its
// one-column steps soften at the edges. Three swing wide (+/-32 columns,
// most of the screen) and two narrower about the thirds; every speed is
// different, so the bars cross and re-cross and never settle into a
// pattern.
//
//   off    starting phase (high byte; the low byte starts at 0)
//   spd    phase step a frame, in 1/256ths of a sine step
//   sh     amplitude as a shift: 2 = +/-32 columns, 3 = +/-16
//   ctr    centre column, less BAR_W / 2 so the sum is the left column
//   strip  which shading, as an offset into bar_shades
//------------------------------------------------------------------
.label BAR_COUNT = 5
.label BAR_W     = 7
bar_off:    .byte $00, $55, $aa, $40, $c0
bar_spd:    .byte $90, $b0, $70, $d0, $a0
bar_sh:     .byte 2, 2, 2, 3, 3
bar_ctr:    .byte 20 - 3, 20 - 3, 20 - 3, 12 - 3, 28 - 3
bar_strip:  .byte 0 * BAR_W, 1 * BAR_W, 2 * BAR_W, 3 * BAR_W, 4 * BAR_W
bar_ph_lo:  .fill BAR_COUNT, 0
bar_ph_hi:  .fill BAR_COUNT, 0

bar_shades:
    .byte $06, $06, $0e, $0e, $0e, $06, $06     // blue
    .byte $09, $02, $02, $0a, $02, $02, $09     // red
    .byte $0b, $05, $05, $05, $05, $05, $0b     // green
    .byte $06, $04, $04, $04, $04, $04, $06     // purple
    .byte $09, $09, $08, $08, $08, $09, $09     // orange

col_buf:    .fill 40, 0         // this frame's color for each column

//------------------------------------------------------------------
// fade_tab[level * 16 + color] - color dimmed to level/7 of its
// brightness, staying inside its own family so a fade passes through
// real shades of the same hue.
//
// Luminance is the usual 0-32 scale (Pepto's measurements, rounded);
// each family lists its colors dark to bright, and a level picks the
// family member nearest the target luminance, the darker on a tie.
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
