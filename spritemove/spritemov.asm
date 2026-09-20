//==================================================================
// SPRITEMOV - Smooth Wandering Balls with Trails, Stars and Swoosh SFX
// KickAssembler v5.25 / Commodore 64 (6502)
//
// Build:  java -jar /Applications/KickAssembler/KickAss.jar spritemov.asm -odir bin
// Run:    /Applications/vice-arm64-gtk3/bin/x64sc -autostart bin/spritemov.prg
//==================================================================
//
// WHAT THIS PROGRAM DOES
// ----------------------
// Four multicolor sprites - shaded balls - drift around a black, starry
// screen with smooth, organic, random motion. Each ball spins as it moves
// (faster when it moves faster, reversing when it turns) and drags a dark
// "ghost" disc behind it. A soft filtered-noise "swoosh" plays on the SID
// whenever a ball bounces off an edge or off another ball; ball-to-ball
// hits also flash the background and make the two balls swap colors.
//
// The bottom text row is a status bar showing the current speed level.
// The cursor keys or + / - change it while the program runs.
//
// The program never returns to BASIC; it runs a frame-locked main loop
// forever. Reset the machine to exit.
//
// MAP OF THIS FILE
// ----------------
//   1. Hardware register labels        VIC-II, screen/color RAM, CIA1, SID
//   2. Zero page variables             per-ball tables + scratch/state
//   3. Constants                       screen limits, effect tuning
//   4. Macros                          EaseVelocity, Negate16, ScaleVel
//   5. start / main_loop               one-time setup, then once per frame:
//        update_input       keyboard -> speed level, status bar
//        update_sprites     ease, scale, integrate, edge bounce, spin frame
//        check_collisions   all 6 ball pairs, push apart, swap colors
//        update_trails      ring buffer of past positions -> trail sprites
//        apply_positions    write all 8 sprite positions to the VIC
//        update_effects     impact flash fade, star twinkle, cooldowns
//        update_sound       swoosh envelope / filter sweep
//   6. Helper routines                 reverse_x/y, new_heading, random_speed,
//                                      set_trail_color, init_stars, draw_status,
//                                      draw_speed_bar, push_ball, sound, RNG
//   7. Data tables                     colors, status text, history buffers
//   8. Generated sprite graphics       8 shaded ball frames + 1 trail disc
//
// MEMORY LAYOUT
// -------------
//   $0002-$006e  zero page variables (see below)
//   $0400-$07e7  text screen: stars, status row 24 (the sprite pointers
//                live at $07f8-$07ff inside the same 1K block)
//   $0801        BASIC stub "10 SYS 2064"
//   $0810-...    code and data tables
//   $2000-$21ff  8 ball frames, 64 bytes each  (VIC blocks $80-$87)
//   $2200-$223f  trail disc frame              (VIC block  $88)
//
// SPRITE ROLES
// ------------
//   sprites 0-3  the balls   (multicolor, 8 animation frames)
//   sprites 4-7  the trails  (hi-res, one shared disc frame, darker color)
// Lower-numbered sprites are drawn on top, so every ball is in front of
// every trail.
//
// HOW THE MOVEMENT WORKS
// ----------------------
// Everything is done in 8.8 fixed point: one byte of whole pixels and one
// byte of 1/256ths of a pixel. This gives sub-pixel precision so a ball can
// move at, say, 0.3 pixels per frame and still look smooth.
//
//   * Position     - X needs 9 bits (0..319 visible, up to 511 in VIC), so
//                    X is  x_msb : x_lo : x_frac  (bit 8, pixel, fraction).
//                    Y fits in 8 bits:   y_pix : y_frac.
//   * Velocity     - signed 8.8 (vx_hi:vx_lo). Positive = right/down.
//   * Target vel   - signed 8.8 (tvx_hi:tvx_lo). Where the ball *wants* to go.
//
// Each ball is given ONE random heading at start-up (random base speed
// 0.25..1.25 px/frame on each axis, random sign) and keeps it. The only
// things that ever change a ball's direction are:
//   * reaching the edge of the screen  (that axis is reflected)
//   * touching another ball            (pushed apart, see below)
//
// Every frame the velocity is eased toward the target:
//
//       vel += (target - vel) / 16
//
// With no periodic retargeting the target only differs from the velocity
// right after start-up, so the balls accelerate smoothly from rest into
// their heading and then travel in a straight line. Bounces flip both
// velocity and target together, so they are instant, like a billiard ball.
//
// SPEED CONTROL
// -------------
// The stored velocities are "base" velocities. Every frame each one is
// scaled by a global speed level before it is used:
//
//       effective = base * speed / 8          (speed = 1..16)
//
// so level 8 is the base speed, the default of 4 is half speed, and 16 is
// double. The multiply is a 16x5-bit shift-and-add on the magnitude, then
// the sign is restored (see ScaleVel). Only the effective velocity is used
// for integration and spin, so changing the level never disturbs the
// headings, bounces or easing.
//
// Keys (CIA1 matrix scanned directly, no kernal):
//     CRSR up, CRSR right, +    faster
//     CRSR down, CRSR left, -   slower
// Holding a key auto-repeats every KEY_REPEAT frames. The bottom text row
// shows "SPEED [####............] CRSR UP/DN +/-" and is redrawn on change.
//
// EDGE HANDLING
// -------------
// The balls travel all the way to the edge of the visible screen (the
// ball's circle touches the border). Hard bounce limits are X 22..322 and
// Y 50..221 (the bottom limit keeps the ball above the status row). When
// a ball reaches an edge its position is clamped and the velocity (and
// target) on that axis is reversed. The other axis is left alone, so a
// ball hitting the right wall while moving down keeps moving down - a
// clean reflection.
//
// BALL-TO-BALL COLLISIONS
// -----------------------
// After every physics step all 6 sprite pairs are tested in software
// (the VIC's $d01e collision register only says *that* a sprite touched
// something, not which one, and only for non-transparent pixels). Two
// balls touch when the distance between their centers is under the
// 20 px ball diameter, approximated as
//       |dx| < 20  and  |dy| < 20  and  |dx| + |dy| < 30
// (a box with the corners cut off - close enough to a circle).
// On contact each ball's velocity AND target are forced to point away
// from the other ball on both axes. Forcing the sign (instead of simply
// reversing) means overlapping balls always separate and never jitter or
// stick together. Each hit also fires a swoosh.
//
// ANIMATION
// ---------
// The eight 24x21 multicolor frames at $2000 are not hand-drawn: a
// KickAssembler script at the bottom of this file ray-shades a sphere with
// a light source that rotates 45 degrees per frame. Bit pairs map to:
//     01 = highlight (white, $d025)   10 = body (per-sprite $d027+n)
//     11 = shadow (dark grey, $d026)  00 = transparent
//
// The frame shown is taken from an "animation accumulator" that adds the
// velocity every frame. Bits 3..5 of its whole-pixel byte select the frame,
// so one frame step happens every 8 pixels travelled - the ball appears to
// roll, and the roll direction follows the movement direction.
//
// SOUND
// -----
// SID voice 1 is a noise generator routed through the low-pass filter.
// A swoosh is triggered by every wall bounce and ball-to-ball hit.
// When a swoosh is triggered the gate opens and, over 32 frames, the filter
// cutoff sweeps up and back down while the noise pitch slides downward.
// Volume is kept low (4/15) so it sits in the background. A random cooldown
// of 40..103 frames prevents the sound from becoming a constant hiss.
//
// VISUAL EFFECTS
// --------------
//   * Ghost trails  - sprites 4..7 are solid dark discs (hi-res, one per
//                     ball) that show where each ball was TRAIL_DELAY frames
//                     ago. A 16-slot ring buffer of past positions is
//                     written every frame and read back TRAIL_DELAY slots
//                     behind, so the trail follows the real path, bounces
//                     included.
//                     The trail color is a darker shade of the ball color.
//   * Starfield     - 32 '.' / '*' characters are scattered over the text
//                     screen at start-up. Every other frame one random star
//                     is given a random shade so the field twinkles.
//   * Impact flash  - a ball-to-ball hit flashes the background grey for a
//                     few frames (a small table drives the fade back).
//   * Color swap    - colliding balls exchange body colors, and their
//                     trails follow. A short cooldown stops the swap
//                     bouncing back and forth while the balls separate.
//
// FRAME TIMING
// ------------
// The main loop polls the raster ($d012) for line $fa, which is in the
// lower border after all sprites have been drawn. Positions written at that
// point are picked up cleanly on the next frame with no tearing. No IRQs
// are used; the CPU has nothing else to do.
//
//==================================================================

BasicUpstart2(start)            // emits a "10 SYS 2064" BASIC stub at $0801

//------------------------------------------------------------------
// VIC-II Registers
//------------------------------------------------------------------
.label SPRITE_PTRS          = $07f8 // 8 sprite data pointers (block = addr/64)
.label VIC_SPRITE_X         = $d000 // sprite 0 X; sprite n X is at $d000+n*2
.label VIC_SPRITE_Y         = $d001 // sprite 0 Y; sprite n Y is at $d001+n*2
.label VIC_SPRITE_X_MSB     = $d010 // bit n = bit 8 of sprite n's X position
.label VIC_RASTER           = $d012 // current raster line (low 8 bits)
.label VIC_SPRITE_ENABLE    = $d015 // bit n = sprite n visible
.label VIC_SPRITE_EXPAND_Y  = $d017 // bit n = sprite n double height
.label VIC_SPRITE_PRIORITY  = $d01b // bit n = sprite n behind background
.label VIC_SPRITE_MULTI     = $d01c // bit n = sprite n multicolor mode
.label VIC_SPRITE_EXPAND_X  = $d01d // bit n = sprite n double width
.label VIC_BORDER           = $d020
.label VIC_BACKGROUND       = $d021
.label VIC_SPRITE_MCOLOR0   = $d025 // shared multicolor 0 (bit pair 01)
.label VIC_SPRITE_MCOLOR1   = $d026 // shared multicolor 1 (bit pair 11)
.label VIC_SPRITE_COLOR     = $d027 // sprite n color at $d027+n (bit pair 10)

.label SCREEN_RAM           = $0400 // default text screen, 1000 bytes
.label COLOR_RAM            = $d800 // one color nibble per screen cell
.label STATUS_ROW           = 24 * 40 // bottom text row (offset 960)

//------------------------------------------------------------------
// CIA1 keyboard matrix: write a row mask (active low) to PORT_A, read
// the column bits (active low) from PORT_B.
//------------------------------------------------------------------
.label CIA1_PORT_A          = $dc00
.label CIA1_PORT_B          = $dc01
.label CIA1_DDR_A           = $dc02
.label CIA1_DDR_B           = $dc03

//------------------------------------------------------------------
// SID Registers (only voice 1 and the filter are used)
//------------------------------------------------------------------
.label SID_BASE             = $d400 // 29 registers, $d400..$d418
.label SID_V1_FREQ_LO       = $d400 // voice 1 frequency, 16-bit
.label SID_V1_FREQ_HI       = $d401
.label SID_V1_CONTROL       = $d404 // waveform bits 4-7, bit 0 = gate
.label SID_V1_AD            = $d405 // attack (hi nibble) / decay (lo nibble)
.label SID_V1_SR            = $d406 // sustain (hi nibble) / release (lo nibble)
.label SID_FILTER_LO        = $d415 // filter cutoff bits 0-2
.label SID_FILTER_HI        = $d416 // filter cutoff bits 3-10
.label SID_FILTER_RES       = $d417 // resonance (hi nibble) / voice routing (lo)
.label SID_VOLUME           = $d418 // filter mode bits 4-6 / master volume 0-3

//------------------------------------------------------------------
// Zero Page Variables
//
// Each per-sprite value is a 4-byte table indexed by X (X = sprite 0..3),
// e.g. "lda x_lo, x". Zero page is used because indexed zero-page access
// is one cycle faster and one byte shorter than absolute addressing.
//
// $02..$8f belong to BASIC normally, but we never return to BASIC and
// interrupts are disabled, so they are ours. Layout:
//   $02-$41  per-ball tables (4 bytes each)
//   $42-$4e  global state (RNG, timers, collision scratch)
//   $50-$5f  pointer + trail sprite positions
//   $60-$6e  speed scaling scratch, speed level, keyboard state
//------------------------------------------------------------------
.label x_frac       = $02       // X position, fractional part (1/256 px)
.label x_lo         = $06       // X position, whole pixels (low 8 bits)
.label x_msb        = $0a       // X position, bit 8 (0 or 1)
.label y_frac       = $0e       // Y position, fractional part
.label y_pix        = $12       // Y position, whole pixels
.label vx_lo        = $16       // X velocity, signed 8.8, low (fraction)
.label vx_hi        = $1a       // X velocity, signed 8.8, high (whole px)
.label vy_lo        = $1e       // Y velocity, signed 8.8
.label vy_hi        = $22
.label tvx_lo       = $26       // X target velocity, signed 8.8
.label tvx_hi       = $2a
.label tvy_lo       = $2e       // Y target velocity, signed 8.8
.label tvy_hi       = $32
.label anim_lo      = $3a       // spin accumulator, 8.8 (sum of velocities)
.label anim_hi      = $3e       //   bits 3-5 of anim_hi = current frame

.label seed         = $42       // 16-bit RNG state ($42 low, $43 high)
.label frame_count  = $44       // free-running frame counter (debug/handy)
.label temp         = $45       // scratch, low byte of 16-bit temporaries
.label temp2        = $46       // scratch, high byte
.label swoosh_timer = $47       // frames left in current swoosh (0 = idle)
.label swoosh_cool  = $48       // frames until another swoosh may start
.label want_sx      = $49       // collision: desired X velocity sign ($00/$ff)
.label want_sy      = $4a       // collision: desired Y velocity sign ($00/$ff)
.label save_x       = $4b       // collision: saved sprite index
.label flash_timer  = $4d       // frames left in the background impact flash
.label swap_cool    = $4e       // frames until balls may swap colors again
.label ptr          = $50       // 16-bit pointer for (ptr),y access ($50/$51)
.label trail_xlo    = $54       // trail sprite X, whole pixels (4 entries)
.label trail_xmsb   = $58       // trail sprite X, bit 8
.label trail_y      = $5c       // trail sprite Y

.label m0           = $60       // ScaleVel: 24-bit multiplicand ($60..$62)
.label p0           = $63       // ScaleVel: 24-bit product ($63..$65)
.label vsign        = $66       // ScaleVel: sign of the input velocity
.label speed        = $67       // global speed level 1..16 (8 = base speed)
.label key_timer    = $68       // auto-repeat countdown while a key is held
.label evx_lo       = $69       // effective X velocity this frame, 8.8
.label evx_hi       = $6a
.label evy_lo       = $6b       // effective Y velocity this frame, 8.8
.label evy_hi       = $6c
.label key_shift    = $6d       // nonzero if either shift key is down
.label key_delta    = $6e       // +1 / -1 speed change requested, 0 = none

//------------------------------------------------------------------
// Constants
//------------------------------------------------------------------
.label NUM_SPRITES  = 4

// Screen edges in sprite coordinates. The visible area is X 24..343,
// Y 50..249. The ball's circle occupies columns 2..21 of the 24 px wide
// sprite and all 21 lines, so the ball touches the left border at X = 22,
// the right border at X = 322 and the top at Y = 50. It would touch the
// bottom border at Y = 229, but the status row occupies Y 242..249, so
// the bottom limit is pulled up 8 pixels to 221.
.label MIN_X        = 22        // left edge (ball touches border)
.label MAX_X_LO     = 66        // right edge = 322 = $142 (MSB=1, lo=$42)
.label MIN_Y        = 50        // top edge
.label MAX_Y        = 221       // bottom edge, above the status row (Y 242+)

// Ball-to-ball collision thresholds (see header). Ball diameter is 20 px.
.label BALL_DIAM    = 20
.label BALL_SUM     = 30        // |dx| + |dy| limit, rounds the corners

.label SPRITE_DATA      = $2000             // 8 frames x 64 bytes = $2000..$21ff
.label SPRITE_PTR_BASE  = SPRITE_DATA / $40 // = $80, the VIC block number
.label TRAIL_DATA       = SPRITE_DATA + 8 * 64      // $2200, solid disc frame
.label TRAIL_PTR        = TRAIL_DATA / $40          // = $88

// Effects
.label TRAIL_DELAY  = 10        // trail shows the position this many frames ago
.label HIST_SLOTS   = 16        // ring buffer depth (power of 2, > TRAIL_DELAY)
.label STAR_COUNT   = 32        // stars on the background (power of 2)
.label FLASH_LEN    = 4         // impact flash length in frames
.label SWAP_COOL    = 16        // frames between color swaps

// Speed control
.label SPEED_MIN    = 1
.label SPEED_MAX    = 16
.label SPEED_DEFAULT = 4        // half of base speed
.label KEY_REPEAT   = 6         // frames between repeats while a key is held
.label BAR_COL      = 7         // screen column of the first bar cell
.label BAR_LEN      = 16        // one cell per speed level

//------------------------------------------------------------------
// Macros
//------------------------------------------------------------------

// EaseVelocity - vel += (target - vel) / 16, signed 16-bit.
// X must hold the sprite index. Uses temp/temp2 and Y.
//
// The divide by 16 is done as four arithmetic shifts right. "cmp #$80"
// sets the carry to the sign bit before each "ror" so the sign is
// preserved (a plain lsr would turn negatives into large positives).
.macro EaseVelocity(vlo, vhi, tlo, thi) {
    sec                         // diff = target - vel
    lda tlo, x
    sbc vlo, x
    sta temp
    lda thi, x
    sbc vhi, x
    sta temp2

    ldy #$04                    // diff >>= 4 (arithmetic)
shift:
    lda temp2
    cmp #$80                    // C = bit 7 of high byte (the sign)
    ror temp2                   // rotate sign back in at the top
    ror temp
    dey
    bne shift

    clc                         // vel += diff
    lda vlo, x
    adc temp
    sta vlo, x
    lda vhi, x
    adc temp2
    sta vhi, x
}

// Negate16 - value = -value (two's complement), signed 16-bit table entry.
// X must hold the sprite index. Computes 0 - value with borrow.
.macro Negate16(lo, hi) {
    sec
    lda #$00
    sbc lo, x
    sta lo, x
    lda #$00
    sbc hi, x
    sta hi, x
}

// ScaleVel - out = vel * speed / 8, signed 16-bit. X must hold the sprite
// index; out is a 2-byte zero page pair (not indexed). Uses Y, temp,
// m0..m2, p0..p2, vsign.
//
// The magnitude of vel is multiplied by the 5-bit speed with shift-and-add
// into a 24-bit product, the product is shifted right 3, and the sign is
// put back with a two's complement negate.
.macro ScaleVel(vlo, vhi, outlo, outhi) {
    lda vhi, x
    sta vsign
    bpl positive
    sec                         // m = -vel
    lda #$00
    sbc vlo, x
    sta m0
    lda #$00
    sbc vhi, x
    sta m0 + 1
    jmp multiply
positive:
    lda vlo, x
    sta m0
    lda vhi, x
    sta m0 + 1
multiply:
    lda #$00
    sta m0 + 2
    sta p0
    sta p0 + 1
    sta p0 + 2
    lda speed
    sta temp                    // multiplier bits are shifted out of temp
    ldy #$05                    // speed <= 16 needs 5 bits
mul_loop:
    lsr temp
    bcc no_add
    clc
    lda p0
    adc m0
    sta p0
    lda p0 + 1
    adc m0 + 1
    sta p0 + 1
    lda p0 + 2
    adc m0 + 2
    sta p0 + 2
no_add:
    asl m0
    rol m0 + 1
    rol m0 + 2
    dey
    bne mul_loop

    ldy #$03                    // product >>= 3 (the /8)
div_loop:
    lsr p0 + 2
    ror p0 + 1
    ror p0
    dey
    bne div_loop

    lda vsign
    bpl store
    sec                         // out = -product
    lda #$00
    sbc p0
    sta outlo
    lda #$00
    sbc p0 + 1
    sta outhi
    jmp done
store:
    lda p0
    sta outlo
    lda p0 + 1
    sta outhi
done:
}

* = $0810 "Main Code"

//------------------------------------------------------------------
// Entry Point - one-time setup, then falls into main_loop
//------------------------------------------------------------------
start:
    sei                         // no IRQs: kernal keyboard scan etc. off
                                // (we scan the keyboard ourselves)

    // Clear the text screen to spaces so nothing but sprites is visible.
    // 1000 bytes = 4 x 256 with the last page overlapping ($06e8..$07e7),
    // which stops short of the sprite pointers at $07f8.
    lda #$20                    // screen code for space
    ldx #$00
clear_loop:
    sta SCREEN_RAM, x
    sta SCREEN_RAM + $100, x
    sta SCREEN_RAM + $200, x
    sta SCREEN_RAM + $2e8, x
    dex
    bne clear_loop

    // Seed the RNG from things that differ run to run. The xorshift
    // generator gets stuck at zero, so a bit is forced on in each byte.
    lda VIC_RASTER
    ora #$01
    sta seed
    lda $a2                     // kernal jiffy clock, low byte
    ora #$80
    sta seed + 1

    lda #$00                    // black border and background: the stars
    sta VIC_BORDER              // and the ball colors pop against it
    sta VIC_BACKGROUND
    sta flash_timer             // no flash in progress
    sta swap_cool               // color swap allowed
    sta key_timer               // first key press acts immediately
    lda #SPEED_DEFAULT
    sta speed

    lda #$ff                    // CIA1 port A = output (row select),
    sta CIA1_DDR_A              // port B = input (columns)
    lda #$00
    sta CIA1_DDR_B

    jsr init_stars              // scatter the background stars
    jsr draw_status             // status text + speed bar on row 24
    jsr init_sprites            // VIC sprite setup, random ball state
    jsr init_sound              // SID voice 1 as filtered noise

//------------------------------------------------------------------
// Main Loop - runs exactly once per frame (50 Hz PAL / 60 Hz NTSC)
//
// All work happens while the raster is in the lower border, so the VIC
// never displays a half-updated set of sprite positions.
//------------------------------------------------------------------
main_loop:
    lda #$fa                    // wait for raster line 250 (lower border)
wait_raster:
    cmp VIC_RASTER
    bne wait_raster

    jsr update_input            // keyboard: change speed level
    jsr update_sprites          // physics, edges, animation frame
    jsr check_collisions        // ball-to-ball contact, push apart
    jsr update_trails           // record history, fetch delayed positions
    jsr apply_positions         // copy ball + trail positions to the VIC
    jsr update_effects          // impact flash, twinkling stars
    jsr update_sound            // advance swoosh envelope/filter sweep
    inc frame_count

    // Guard against running twice in one frame: if the update ever
    // finished while the raster was still on line $fa, the loop above
    // would fire again immediately. Wait for the raster to move on.
    lda #$fa
wait_leave:
    cmp VIC_RASTER
    beq wait_leave

    jmp main_loop

//------------------------------------------------------------------
// init_sprites - VIC setup and random starting state for all 4 balls
//
// Also sets up the 4 trail sprites: all point at the single disc frame,
// get a dark shade of their ball's color, and start parked at (0,0)
// (off-screen) until the position history has filled.
//------------------------------------------------------------------
init_sprites:
    lda #%11111111              // sprites 0-3 (balls) and 4-7 (trails) on
    sta VIC_SPRITE_ENABLE
    lda #%00001111              // only the balls are multicolor; the trail
    sta VIC_SPRITE_MULTI        // discs are hi-res single color

    lda #$00
    sta VIC_SPRITE_X_MSB        // all X < 256 until apply_positions runs
    sta VIC_SPRITE_EXPAND_X     // normal size
    sta VIC_SPRITE_EXPAND_Y
    sta VIC_SPRITE_PRIORITY     // sprites in front of background

    // Multicolor sprites share two colors across all sprites; the third
    // color is per sprite. These are the sphere's highlight and shadow.
    lda #$01                    // white  -> bit pair 01 (highlight)
    sta VIC_SPRITE_MCOLOR0
    lda #$0b                    // dark grey -> bit pair 11 (shadow)
    sta VIC_SPRITE_MCOLOR1

    ldx #NUM_SPRITES - 1        // per-sprite body color (bit pair 10)
init_colors:
    lda sprite_colors, x
    sta VIC_SPRITE_COLOR, x
    jsr set_trail_color         // trail n = darker shade of ball n
    lda #TRAIL_PTR              // all trails share the one disc frame
    sta SPRITE_PTRS + 4, x
    lda #$00                    // park the trails off-screen until the
    sta trail_xlo, x            // history has filled up
    sta trail_xmsb, x
    sta trail_y, x
    dex
    bpl init_colors

    // Per-sprite state. Loop X = 3 down to 0.
    ldx #NUM_SPRITES - 1
init_loop:
    // Random X in 40..295: random byte + 40, carry becomes the MSB.
    jsr get_random
    clc
    adc #40
    sta x_lo, x
    lda #$00
    adc #$00                    // A = carry from the add (0 or 1)
    sta x_msb, x

    // Random Y in 70..197: 7-bit random + 70, well inside the screen.
    jsr get_random
    and #$7f
    clc
    adc #70
    sta y_pix, x

    // Start at rest. The easing will accelerate the ball toward its
    // one and only random heading so it drifts into motion instead of
    // jumping.
    lda #$00
    sta x_frac, x
    sta y_frac, x
    sta vx_lo, x
    sta vx_hi, x
    sta vy_lo, x
    sta vy_hi, x
    jsr new_heading             // sets tvx/tvy

    // Random spin phase so the balls don't all show the same frame.
    jsr get_random
    sta anim_hi, x
    lda #$00
    sta anim_lo, x

    dex
    bpl init_loop
    rts

//------------------------------------------------------------------
// update_sprites - one physics step for every ball
//
// Per ball, in order:
//   1.  ease base velocity toward target (only matters during start-up)
//   1b. scale base velocity by the speed level -> evx/evy (this frame's
//       actual movement, in 8.8 pixels)
//   2.  integrate position (position += effective velocity)
//   3.  edge clamp / bounce (flips the base velocity and target)
//   4.  update spin accumulator and pick the animation frame
//------------------------------------------------------------------
update_sprites:
    ldx #NUM_SPRITES - 1
update_loop:
    //---- 1. Ease velocity toward target ----
    EaseVelocity(vx_lo, vx_hi, tvx_lo, tvx_hi)
    EaseVelocity(vy_lo, vy_hi, tvy_lo, tvy_hi)

    //---- 1b. Scale by the global speed level ----
    ScaleVel(vx_lo, vx_hi, evx_lo, evx_hi)
    ScaleVel(vy_lo, vy_hi, evy_lo, evy_hi)

    //---- 2a. Integrate X ----
    // X position is 3 bytes (msb:lo:frac) but velocity is only 2 bytes,
    // so the velocity's sign must be extended into the MSB add:
    // add $00 for positive velocity, $ff for negative (plus carry).
    clc
    lda x_frac, x
    adc evx_lo
    sta x_frac, x
    lda x_lo, x
    adc evx_hi
    sta x_lo, x
    lda evx_hi
    and #$80                    // isolate the sign bit (does not touch C)
    beq x_sign_pos              // positive: extension byte is $00 (in A)
    lda #$ff                    // negative: extension byte is $ff
x_sign_pos:
    adc x_msb, x                // carry is still from the x_lo add
    and #$01                    // keep only bit 8
    sta x_msb, x

    //---- 2b. Integrate Y (plain 16-bit add, Y never exceeds 8 bits) ----
    clc
    lda y_frac, x
    adc evy_lo
    sta y_frac, x
    lda y_pix, x
    adc evy_hi
    sta y_pix, x

    //---- 3a. X edge bounce ----
    // Left edge only matters when MSB is 0; right edge only when MSB is 1.
    lda x_msb, x
    bne hard_right
    lda x_lo, x
    cmp #MIN_X
    bcs x_ok                    // x >= 22, fine
    lda #MIN_X                  // clamp to 22 and bounce
    sta x_lo, x
    jsr reverse_x
    jmp x_ok
hard_right:
    lda x_lo, x
    cmp #MAX_X_LO
    bcc x_ok                    // x < 322, fine
    lda #MAX_X_LO               // clamp to 322 and bounce
    sta x_lo, x
    jsr reverse_x
x_ok:

    //---- 3b. Y edge bounce ----
    lda y_pix, x
    cmp #MIN_Y
    bcs y_not_top
    lda #MIN_Y
    sta y_pix, x
    jsr reverse_y
    jmp y_ok
y_not_top:
    cmp #MAX_Y
    bcc y_ok
    lda #MAX_Y
    sta y_pix, x
    jsr reverse_y
y_ok:

    //---- 4. Spin animation ----
    // anim += evx + evy (the distance actually moved this frame), so the
    // roll rate follows the speed level. Moving right or down spins one
    // way; left or up the other. The accumulator wraps naturally.
    clc
    lda anim_lo, x
    adc evx_lo
    sta anim_lo, x
    lda anim_hi, x
    adc evx_hi
    sta anim_hi, x
    clc
    lda anim_lo, x
    adc evy_lo
    sta anim_lo, x
    lda anim_hi, x
    adc evy_hi
    sta anim_hi, x              // A = anim_hi (whole pixels travelled)

    lsr                         // /8: one frame per 8 pixels of travel
    lsr
    lsr
    and #$07                    // frame 0..7
    clc
    adc #SPRITE_PTR_BASE        // block number = $80 + frame
    sta SPRITE_PTRS, x          // VIC reads this pointer next frame

    dex
    bmi update_done
    jmp update_loop             // loop body > 128 bytes, so jmp not bne
update_done:
    rts

//------------------------------------------------------------------
// reverse_x / reverse_y - bounce off a wall
//
// Flip the velocity on that axis. If the *target* still points into the
// wall the easing would immediately drag the ball back, so flip the
// target too when its sign disagrees with the new velocity. Fraction is
// zeroed so the clamped position is exact. Each bounce fires a swoosh
// (throttled by the sound cooldown).
//------------------------------------------------------------------
reverse_x:
    lda #$00
    sta x_frac, x
    Negate16(vx_lo, vx_hi)
    lda vx_hi, x
    eor tvx_hi, x               // bit 7 set => signs differ
    bpl rx_done
    Negate16(tvx_lo, tvx_hi)
rx_done:
    jmp trigger_swoosh          // tail call

reverse_y:
    lda #$00
    sta y_frac, x
    Negate16(vy_lo, vy_hi)
    lda vy_hi, x
    eor tvy_hi, x
    bpl ry_done
    Negate16(tvy_lo, tvy_hi)
ry_done:
    jmp trigger_swoosh          // tail call

//------------------------------------------------------------------
// new_heading - pick the random heading for sprite X (start-up only)
//
// Sets a random signed target velocity on each axis. The ball keeps
// this heading until an edge or another ball changes it.
//------------------------------------------------------------------
new_heading:
    jsr random_speed
    lda temp
    sta tvx_lo, x
    lda temp2
    sta tvx_hi, x

    jsr random_speed
    lda temp
    sta tvy_lo, x
    lda temp2
    sta tvy_hi, x
    rts

//------------------------------------------------------------------
// random_speed - signed random 8.8 speed in temp (lo) / temp2 (hi)
//
// Magnitude is $0040..$013f = 0.25..1.25 pixels per frame (at speed
// level 8; the level scales it further):
//   (random & $7f) + $40        -> $0040..$00bf
//   + (random & $80)            -> adds 0 or half a pixel
// Then a coin flip negates the whole 16-bit value.
//------------------------------------------------------------------
random_speed:
    jsr get_random
    and #$7f
    clc
    adc #$40                    // minimum speed so balls never stall
    sta temp
    jsr get_random
    and #$80                    // optionally +0.5 px per frame
    clc
    adc temp
    sta temp
    lda #$00
    adc #$00                    // carry from the add into the high byte
    sta temp2

    jsr get_random              // coin flip for direction
    and #$01
    beq rs_done
    sec                         // negate: 0 - value
    lda #$00
    sbc temp
    sta temp
    lda #$00
    sbc temp2
    sta temp2
rs_done:
    rts

//------------------------------------------------------------------
// apply_positions - copy ball and trail positions to the VIC-II
//
// X/Y registers are interleaved ($d000 X0, $d001 Y0, $d002 X1, ...), so
// Y steps by 2 while X steps by 1. Trail n is sprite n+4, whose registers
// sit 8 bytes after ball n's. The MSB register packs bit 8 of every
// sprite's X into one byte (bit n = sprite n), assembled with shift-and-or
// from the trail MSBs (bits 7-4) and the ball MSBs (bits 3-0).
//------------------------------------------------------------------
apply_positions:
    ldx #NUM_SPRITES - 1
    ldy #(NUM_SPRITES - 1) * 2
apply_loop:
    lda x_lo, x
    sta VIC_SPRITE_X, y
    lda y_pix, x
    sta VIC_SPRITE_Y, y
    lda trail_xlo, x            // trail n is sprite n + 4, 8 bytes further on
    sta VIC_SPRITE_X + 8, y
    lda trail_y, x
    sta VIC_SPRITE_Y + 8, y
    dey
    dey
    dex
    bpl apply_loop

    lda trail_xmsb + 3          // build %hgfedcba: trails in the high nibble,
    asl                         // balls in the low nibble
    ora trail_xmsb + 2
    asl
    ora trail_xmsb + 1
    asl
    ora trail_xmsb + 0
    asl
    ora x_msb + 3
    asl
    ora x_msb + 2
    asl
    ora x_msb + 1
    asl
    ora x_msb + 0
    sta VIC_SPRITE_X_MSB
    rts

//------------------------------------------------------------------
// update_trails - ghost trail bookkeeping
//
// Slot s of the ring buffer holds all four balls' positions from frame
// s (mod HIST_SLOTS). Entry index = slot * 4 + ball. This frame's
// positions go into slot (frame_count & 15); the trail sprites take
// theirs from slot (frame_count - TRAIL_DELAY) & 15.
//------------------------------------------------------------------
update_trails:
    lda frame_count             // write slot
    and #HIST_SLOTS - 1
    asl
    asl
    sta temp                    // temp = slot * 4
    ldx #NUM_SPRITES - 1
ut_store:
    txa
    clc
    adc temp
    tay                         // Y = slot * 4 + ball
    lda x_lo, x
    sta hist_xlo, y
    lda x_msb, x
    sta hist_xmsb, y
    lda y_pix, x
    sta hist_y, y
    dex
    bpl ut_store

    lda frame_count             // read slot, TRAIL_DELAY frames back
    sec
    sbc #TRAIL_DELAY
    and #HIST_SLOTS - 1
    asl
    asl
    sta temp
    ldx #NUM_SPRITES - 1
ut_fetch:
    txa
    clc
    adc temp
    tay
    lda hist_xlo, y
    sta trail_xlo, x
    lda hist_xmsb, y
    sta trail_xmsb, x
    lda hist_y, y
    sta trail_y, x
    dex
    bpl ut_fetch
    rts

//------------------------------------------------------------------
// set_trail_color - trail sprite X gets a darker shade of ball X's color
//
// Looks the ball's current body color up in dark_colors. Preserves X
// and Y so it can be called from inside the collision loop.
//------------------------------------------------------------------
set_trail_color:
    sty temp2
    lda VIC_SPRITE_COLOR, x
    tay
    lda dark_colors, y
    sta VIC_SPRITE_COLOR + 4, x
    ldy temp2
    rts

//------------------------------------------------------------------
// init_stars - scatter STAR_COUNT stars over the text screen
//
// Each star is a random cell offset 0..999 (a 10-bit random with the
// top page clipped so it stays below 1000 and clear of the sprite
// pointers at $07f8). The offset is remembered so update_effects can
// find the star's color cell again. Most stars are '.', a few are '*'.
//------------------------------------------------------------------
init_stars:
    ldx #STAR_COUNT - 1
is_loop:
    jsr get_random
    sta star_lo, x
    jsr get_random
    and #$03                    // page 0..3 of the screen
    sta star_hi, x
    cmp #$03
    bne is_in_range
    lda star_lo, x              // page 3 only runs to $3e7: keep < $380
    and #$7f
    sta star_lo, x
is_in_range:
    lda star_lo, x
    sta ptr
    lda star_hi, x
    ora #>SCREEN_RAM            // $0400 + offset
    sta ptr + 1
    jsr get_random
    and #$07
    bne is_dot
    lda #$2a                    // '*' one time in eight
    bne is_put
is_dot:
    lda #$2e                    // '.'
is_put:
    ldy #$00
    sta (ptr), y
    lda star_hi, x              // same offset in color RAM
    ora #>COLOR_RAM             // ($d800 + offset; NB: ">a - >b" would
    sta ptr + 1                 //  parse as >(a - >b) in KickAssembler)
    lda #$0b                    // start dim
    sta (ptr), y
    dex
    bpl is_loop
    rts

//------------------------------------------------------------------
// update_input - scan the keyboard and adjust the speed level
//
// Rows are selected by writing an active-low mask to CIA1 port A and the
// columns read back active-low from port B:
//     CRSR down/up   row 0 ($fe) bit 7     '+'   row 5 ($df) bit 0
//     CRSR right/left row 0 ($fe) bit 2    '-'   row 5 ($df) bit 3
//     left shift     row 1 ($fd) bit 7     right shift row 6 ($bf) bit 4
// The cursor keys are shifted for up/left, so shift decides direction.
// While a key is held the change repeats every KEY_REPEAT frames.
//------------------------------------------------------------------
update_input:
    lda #$00
    sta key_delta
    sta key_shift

    lda #$fd                    // left shift?
    sta CIA1_PORT_A
    lda CIA1_PORT_B
    and #$80
    beq ui_shifted
    lda #$bf                    // right shift?
    sta CIA1_PORT_A
    lda CIA1_PORT_B
    and #$10
    bne ui_row5
ui_shifted:
    inc key_shift

ui_row5:
    lda #$df
    sta CIA1_PORT_A
    lda CIA1_PORT_B
    sta temp
    and #$01                    // '+'
    beq ui_faster
    lda temp
    and #$08                    // '-'
    beq ui_slower

    lda #$fe                    // row 0: cursor keys
    sta CIA1_PORT_A
    lda CIA1_PORT_B
    sta temp
    and #$80                    // CRSR up/down key
    bne ui_lr
    lda key_shift
    bne ui_faster               // shifted = up = faster
    beq ui_slower               // plain = down = slower
ui_lr:
    lda temp
    and #$04                    // CRSR left/right key
    bne ui_none
    lda key_shift
    bne ui_slower               // shifted = left = slower
                                // plain = right = faster
ui_faster:
    lda #$01
    sta key_delta
    bne ui_apply
ui_slower:
    lda #$ff
    sta key_delta
    bne ui_apply
ui_none:
    lda #$ff                    // deselect all rows
    sta CIA1_PORT_A
    lda #$00                    // key released: next press acts at once
    sta key_timer
    rts

ui_apply:
    lda #$ff
    sta CIA1_PORT_A
    lda key_timer
    beq ui_change
    dec key_timer               // still holding: wait for the repeat
    rts
ui_change:
    lda #KEY_REPEAT
    sta key_timer
    lda speed
    clc
    adc key_delta
    cmp #SPEED_MIN
    bcc ui_done                 // would go below the minimum
    cmp #SPEED_MAX + 1
    bcs ui_done                 // would go above the maximum
    sta speed
    jmp draw_speed_bar          // tail call
ui_done:
    rts

//------------------------------------------------------------------
// draw_status - write the fixed status text on the bottom row
//------------------------------------------------------------------
draw_status:
    ldx #39
ds_loop:
    lda status_text, x
    sta SCREEN_RAM + STATUS_ROW, x
    lda #$0c                    // grey text
    sta COLOR_RAM + STATUS_ROW, x
    dex
    bpl ds_loop
    // fall through to draw the bar

//------------------------------------------------------------------
// draw_speed_bar - one filled block per speed level, dots for the rest
//------------------------------------------------------------------
draw_speed_bar:
    ldx #BAR_LEN - 1
dsb_loop:
    cpx speed                   // X < speed -> filled cell
    bcc dsb_filled
    lda #$2e                    // '.'
    sta SCREEN_RAM + STATUS_ROW + BAR_COL, x
    lda #$0b                    // dark grey
    bne dsb_color
dsb_filled:
    lda #$a0                    // reverse space = solid block
    sta SCREEN_RAM + STATUS_ROW + BAR_COL, x
    lda #$0d                    // light green
dsb_color:
    sta COLOR_RAM + STATUS_ROW + BAR_COL, x
    dex
    bpl dsb_loop
    rts

//------------------------------------------------------------------
// update_effects - once per frame: swap cooldown, impact flash, twinkle
//------------------------------------------------------------------
update_effects:
    //---- Impact flash: fade the background back to black ----
    lda swap_cool
    beq ue_flash_check
    dec swap_cool
ue_flash_check:
    lda flash_timer
    beq ue_stars
    dec flash_timer
    ldx flash_timer
    lda flash_colors, x
    sta VIC_BACKGROUND

    //---- Twinkle one random star every other frame ----
ue_stars:
    lda frame_count
    and #$01
    bne ue_done
    jsr get_random
    and #STAR_COUNT - 1
    tax
    lda star_lo, x
    sta ptr
    lda star_hi, x
    ora #>COLOR_RAM             // $d800 + offset
    sta ptr + 1
    jsr get_random
    and #$07
    tay
    lda twinkle_colors, y
    ldy #$00
    sta (ptr), y
ue_done:
    rts

//------------------------------------------------------------------
// check_collisions - test every pair of balls and push touching ones apart
//
// Pairs are visited as (X, Y) with Y < X: (3,2) (3,1) (3,0) (2,1) (2,0)
// (1,0). check_pair is called with X = ball A and Y = ball B.
//------------------------------------------------------------------
check_collisions:
    ldx #NUM_SPRITES - 1
cc_outer:
    txa
    tay
cc_inner:
    dey                         // next partner below X
    bmi cc_next_outer
    jsr check_pair
    jmp cc_inner
cc_next_outer:
    dex
    bne cc_outer                // ball 0 has no partner below it
    rts

//------------------------------------------------------------------
// check_pair - are balls X and Y touching? If so, separate them.
//
// Computes dx = A.x - B.x (16-bit, since X is 9 bits) and dy = A.y - B.y,
// remembers their signs in want_sx/want_sy (the direction A should move
// to get away from B), then applies the distance test from the header.
// On contact: push both balls apart, fire a swoosh, and (unless a swap
// happened recently) swap the two body colors and start the impact flash.
//
// Note: "lda x_lo, y" assembles as absolute,Y ($0006,Y) because the
// 6502 has no zero-page,Y mode for lda - it works, just 1 byte longer.
//------------------------------------------------------------------
check_pair:
    //---- dx = A.x - B.x, then |dx| ----
    sec
    lda x_lo, x
    sbc x_lo, y
    sta temp
    lda x_msb, x
    sbc x_msb, y
    sta temp2                   // $00 or $ff: dx is small, so this is the sign
    sta want_sx                 // A should move in the direction of dx
    bpl cp_dx_abs               // positive: already |dx|
    sec                         // negative: |dx| = 0 - dx
    lda #$00
    sbc temp
    sta temp
    lda #$00
    sbc temp2
    sta temp2
cp_dx_abs:
    lda temp2
    bne cp_done                 // |dx| >= 256, far apart
    lda temp
    cmp #BALL_DIAM
    bcs cp_done                 // |dx| >= 20, not touching

    //---- dy = A.y - B.y, then |dy| ----
    lda #$00
    sta want_sy                 // assume dy positive
    lda y_pix, x
    sec
    sbc y_pix, y
    bcs cp_dy_abs               // C set: A.y >= B.y, already |dy|
    dec want_sy                 // dy negative: want_sy = $ff
    eor #$ff                    // two's complement to get |dy|
    clc
    adc #$01
cp_dy_abs:
    cmp #BALL_DIAM
    bcs cp_done                 // |dy| >= 20, not touching
    clc
    adc temp                    // |dx| + |dy|
    cmp #BALL_SUM
    bcs cp_done                 // corner region, circles do not overlap

    //---- Contact: push A away from B, then B away from A ----
    jsr push_ball               // X = A, want_sx/want_sy already set

    stx save_x
    lda want_sx                 // B wants the opposite signs
    eor #$ff
    sta want_sx
    lda want_sy
    eor #$ff
    sta want_sy
    tya
    tax                         // X = B
    jsr push_ball
    ldx save_x                  // restore X = A for the caller's loop

    jsr trigger_swoosh

    //---- Impact effects: swap body colors and flash the background ----
    // Balls overlap for a few frames while separating; the cooldown
    // makes sure the swap happens once per contact, not every frame.
    lda swap_cool
    bne cp_done
    lda #SWAP_COOL
    sta swap_cool
    lda #FLASH_LEN
    sta flash_timer
    lda VIC_SPRITE_COLOR, x
    sta temp
    lda VIC_SPRITE_COLOR, y
    sta VIC_SPRITE_COLOR, x
    lda temp
    sta VIC_SPRITE_COLOR, y
    jsr set_trail_color         // trail A follows A's new color
    tya
    tax
    jsr set_trail_color         // trail B follows B's new color
    ldx save_x
cp_done:
    rts

//------------------------------------------------------------------
// push_ball - force ball X's velocity and target to the wanted signs
//
// want_sx / want_sy hold $00 (positive) or $ff (negative). For each of
// vx, tvx, vy, tvy: if bit 7 of the value differs from the wanted sign,
// negate it. A value of exactly zero counts as positive; the easing
// toward the (now correctly signed) target takes care of it.
//------------------------------------------------------------------
push_ball:
    lda vx_hi, x
    eor want_sx
    bpl pb_vx_ok
    Negate16(vx_lo, vx_hi)
pb_vx_ok:
    lda tvx_hi, x
    eor want_sx
    bpl pb_tvx_ok
    Negate16(tvx_lo, tvx_hi)
pb_tvx_ok:
    lda vy_hi, x
    eor want_sy
    bpl pb_vy_ok
    Negate16(vy_lo, vy_hi)
pb_vy_ok:
    lda tvy_hi, x
    eor want_sy
    bpl pb_tvy_ok
    Negate16(tvy_lo, tvy_hi)
pb_tvy_ok:
    rts

//------------------------------------------------------------------
// Sound
//------------------------------------------------------------------

// init_sound - silence the SID, then configure voice 1 as a noise source
// through the low-pass filter with a slow attack and long release.
init_sound:
    ldx #$18                    // zero all 25 SID registers
    lda #$00
clear_sid:
    sta SID_BASE, x
    dex
    bpl clear_sid
    sta swoosh_timer
    sta swoosh_cool

    lda #$98                    // attack 9 (~250 ms), decay 8 (~300 ms)
    sta SID_V1_AD
    lda #$09                    // sustain 0, release 9 (~750 ms tail)
    sta SID_V1_SR
    lda #$a1                    // resonance 10 (hi nibble), filter voice 1 (bit 0)
    sta SID_FILTER_RES
    lda #$14                    // bit 4 = low-pass, volume 4 of 15 (quiet)
    sta SID_VOLUME
    lda #$00
    sta SID_FILTER_LO           // cutoff low bits unused; we sweep the high byte
    rts

// trigger_swoosh - start a swoosh unless one is playing or cooling down.
// Uses only A, so callers can keep X = sprite index.
trigger_swoosh:
    lda swoosh_timer
    bne ts_done                 // already playing
    lda swoosh_cool
    bne ts_done                 // too soon after the last one

    lda #$80                    // noise waveform, gate OFF: resets envelope
    sta SID_V1_CONTROL
    lda #$81                    // noise waveform, gate ON: attack starts
    sta SID_V1_CONTROL
    lda #32                     // swoosh lasts 32 frames (~0.6 s)
    sta swoosh_timer
    jsr get_random              // cooldown 40..103 frames after this one
    and #$3f
    clc
    adc #40
    sta swoosh_cool
ts_done:
    rts

// update_sound - called once per frame.
//
// While a swoosh is active (timer t counts 31 down to 0):
//   * filter cutoff rises for the first 16 frames, falls for the last 16
//     (a triangle: $18 -> $54 -> $18), which gives the "sweep" character
//   * noise pitch slides down from $56 to $18 for a passing-by feel
//   * the gate is released with 12 frames left so the release tail
//     overlaps the end of the sweep instead of cutting off abruptly
update_sound:
    lda swoosh_cool             // tick the cooldown
    beq us_check
    dec swoosh_cool
us_check:
    lda swoosh_timer
    beq us_done                 // idle
    dec swoosh_timer

    lda swoosh_timer            // t = 31..0
    cmp #16
    bcc us_falling
    eor #$1f                    // rising half: (31 - t) * 4 + $18
    asl
    asl
    clc
    adc #$18
    jmp us_set_cutoff
us_falling:
    asl                         // falling half: t * 4 + $18
    asl
    clc
    adc #$18
us_set_cutoff:
    sta SID_FILTER_HI

    lda swoosh_timer            // pitch = t * 2 + $18, slides downward
    asl
    clc
    adc #$18
    sta SID_V1_FREQ_HI

    lda swoosh_timer
    cmp #12
    bne us_done
    lda #$80                    // gate off: begin release phase
    sta SID_V1_CONTROL
us_done:
    rts

//------------------------------------------------------------------
// get_random - 16-bit xorshift pseudo-random generator
//
// Returns a random byte in A (the new high byte of the state).
// Preserves X and Y, so it is safe to call inside indexed loops.
// Period is 65535; the state must never be all zero (see seeding).
// Algorithm: x ^= x << 7; x ^= x >> 9; x ^= x << 8.
//------------------------------------------------------------------
get_random:
    lda seed + 1
    lsr
    lda seed
    ror
    eor seed + 1
    sta seed + 1                // high byte of x ^= x << 7 done
    ror                         // A = x >> 9 (high bit from low byte)
    eor seed
    sta seed                    // x ^= x >> 9 and low part of x << 7 done
    eor seed + 1
    sta seed + 1                // x ^= x << 8 done
    rts

//------------------------------------------------------------------
// Data tables (in the code segment, right after the routines)
//------------------------------------------------------------------
sprite_colors:                  // body color per sprite (bit pair 10)
    .byte $02, $0d, $07, $03    // red, light green, yellow, cyan

dark_colors:                    // darker shade of each C64 color, for trails
    .byte $00, $0f, $09, $06    // blk->blk  wht->lgry  red->brn   cyn->blu
    .byte $06, $0b, $00, $08    // pur->blu  grn->dgry  blu->blk   yel->org
    .byte $09, $00, $02, $00    // org->brn  brn->blk   lred->red  dgry->blk
    .byte $0b, $05, $06, $0c    // gry->dgry lgrn->grn  lblu->blu  lgry->gry

flash_colors:                   // background during the impact flash,
    .byte $00, $0b, $0b, $0c    // indexed by flash_timer after the dec

.encoding "screencode_upper"
status_text:                    // 40 columns; the bar is filled in by code
    .text "SPEED [                ] CRSR UP/DN +/- "

twinkle_colors:                 // random star shades (mostly dim)
    .byte $0b, $0c, $0f, $01, $0c, $0b, $0e, $0c

// Trail history ring buffer: HIST_SLOTS slots x NUM_SPRITES balls
hist_xlo:   .fill HIST_SLOTS * NUM_SPRITES, 0
hist_xmsb:  .fill HIST_SLOTS * NUM_SPRITES, 0
hist_y:     .fill HIST_SLOTS * NUM_SPRITES, 0

// Star cell offsets into the screen (0..999), low and high bytes
star_lo:    .fill STAR_COUNT, 0
star_hi:    .fill STAR_COUNT, 0

//------------------------------------------------------------------
// Sprite Data - 8 shaded sphere frames, generated at assembly time
//
// Instead of hand-drawn bitmaps, a KickAssembler script ray-shades a
// sphere. For every frame f the light direction rotates by f * 45
// degrees around the viewing axis. For every pixel:
//
//   1. Is it inside the circle? (distance from center < RADIUS)
//   2. If so, compute the sphere's surface normal at that point:
//        n = (dx/R, dy/R, sqrt(1 - dx^2/R^2 - dy^2/R^2))
//   3. Lambert shading: brightness = n . light
//   4. Threshold the brightness into 3 tones: highlight / body / shadow
//
// Multicolor sprites are 12 "wide pixels" x 21 lines (each wide pixel is
// 2 screen pixels), so dx uses (col*2 + 1) to get the pixel center in
// real pixels. Bit pairs, leftmost pixel in the top bits:
//   00 = transparent
//   01 = $d025  highlight (white)
//   10 = $d027+n sprite body color
//   11 = $d026  shadow (dark grey)
//
// Each frame is 63 bytes (21 rows x 3 bytes) plus 1 pad byte = 64 bytes,
// which is the VIC's sprite block size.
//------------------------------------------------------------------
* = SPRITE_DATA "Sprite Data"

.const RADIUS   = 10.2          // ~20 px wide, 21 lines tall
.const CENTER_X = 12.0          // pixel center of a 24 px wide sprite
.const CENTER_Y = 10.5          // line center of a 21 line sprite

.for (var f = 0; f < 8; f++) {
    .var angle = f * 2 * PI / 8         // light rotates 45 deg per frame
    .var lx = cos(angle) * 0.55         // in-plane light components
    .var ly = sin(angle) * 0.55
    .var lz = 0.83                      // toward the viewer (keeps center lit)
    .for (var row = 0; row < 21; row++) {
        .var bits = 0                   // 24-bit row, built pair by pair
        .for (var col = 0; col < 12; col++) {
            .var dx = (col * 2 + 1) - CENTER_X
            .var dy = (row + 0.5) - CENTER_Y
            .var d = sqrt(dx * dx + dy * dy)
            .var pair = 0               // default: transparent
            .if (d < RADIUS) {
                .var nx = dx / RADIUS
                .var ny = dy / RADIUS
                .var nz = sqrt(1.0 - nx * nx - ny * ny)
                .var lit = nx * lx + ny * ly + nz * lz
                .if (lit > 0.93) {
                    .eval pair = %01     // highlight
                } else .if (lit < 0.22) {
                    .eval pair = %11     // shadow
                } else {
                    .eval pair = %10     // body
                }
            }
            .eval bits = bits | (pair << ((11 - col) * 2))
        }
        .byte (bits >> 16) & $ff, (bits >> 8) & $ff, bits & $ff
    }
    .byte 0                             // pad to 64 bytes
}

//------------------------------------------------------------------
// Trail Sprite - one solid hi-res disc, slightly smaller than the ball
//
// Hi-res sprites are 24 x 21 one-bit pixels: bit set = sprite color
// ($d027+n), clear = transparent. The disc peeks out from behind the
// ball as it moves, so it only needs to be roughly ball-sized.
//------------------------------------------------------------------
* = TRAIL_DATA "Trail Sprite"

.const TRAIL_RADIUS = 9.2

.for (var row = 0; row < 21; row++) {
    .var bits = 0
    .for (var col = 0; col < 24; col++) {
        .var dx = (col + 0.5) - CENTER_X
        .var dy = (row + 0.5) - CENTER_Y
        .if (sqrt(dx * dx + dy * dy) < TRAIL_RADIUS) {
            .eval bits = bits | (1 << (23 - col))
        }
    }
    .byte (bits >> 16) & $ff, (bits >> 8) & $ff, bits & $ff
}
.byte 0                                 // pad to 64 bytes
