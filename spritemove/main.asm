//==================================================================
// SPRITEMOV - Eight Wandering Balls, Stars, Sparks and Ping SFX
// KickAssembler v5.25 / Commodore 64 (6502)
//
// Build:  java -jar /Applications/KickAssembler/KickAss.jar main.asm -odir bin
// Run:    /Applications/vice-arm64-gtk3/bin/x64sc -autostart bin/main.prg
//
// Files:  main.asm          the demo itself (this file)
//         sprite_gen.asm    assembly-time ball graphics
//         intro.asm         the opening sequence
//         intro_gfx.asm     the intro's hi-res bitmap and cell fields
//         intro_sprites.asm the flying logo sprites and the sine table
//         intro_text.asm    glyph rows lifted from the character ROM
//         intro_raster.asm  the raster bar overture and the wipe's bars
//         music.asm         PSID import of Nightshift.sid
//         All of them are #imported below; none assembles on its own.
//==================================================================
//
// WHAT THIS PROGRAM DOES
// ----------------------
// Eight multicolor sprites - shaded balls, every sprite the VIC has -
// drift around a black, starry screen with smooth, organic, random motion.
// Each ball spins as it moves, faster when it moves faster and reversing
// when it turns. A short bell-like ping plays on the SID whenever a ball
// bounces off an edge or off another ball - low for a wall, higher and
// randomly pitched for a ball-to-ball hit. A ball-to-ball hit also throws
// an ASCII spark onto the text screen at the point of contact and makes
// the two balls swap colors.
//
// The vertical border is held open (see main_loop), so the balls use the
// whole visible picture from top to bottom rather than just the 25-row
// text window: they fly over the status row and on down into what would
// be the bottom border.
//
// The demo opens on a raster bar overture: eight colour bars flying over
// a black text screen through five movement modes - a travelling wave,
// crossing scissors, a nested fan, eight independent tempos, and an
// implosion into a single line - while the handle and five labels fade up
// one at a time between them. See intro_raster.asm.
//
// The bitmap intro then holds for a beat and brings up a title card -
// name, date and version - out of nothing. A dithered spiral tunnel then blends in around it, its colors
// rotating in time with a SID tune (Nightshift by Ari Yliaho), the title
// lifts off the bitmap as a flying sprite copy, and lands back into the
// carving before the white-out. See intro.asm.
//
// The bottom two text rows are a menu: a legend of the keys on row 23 and
// the speed bar on row 24. The cursor keys or + / - change the speed, R
// restarts from the top of the intro, and Q or RUN/STOP end the demo and
// hand the machine back with a clean READY. prompt.
//
// The program never returns to BASIC; it runs a frame-locked main loop
// until RUN/STOP is pressed, which resets the machine back to a clean
// READY. prompt (see check_exit).
//
// MAP OF THIS FILE
// ----------------
//   1. Hardware register labels        VIC-II, screen/color RAM, CIA1, SID
//   2. Zero page variables             per-ball tables + scratch/state
//   3. Constants                       screen limits, effect tuning
//   4. Macros                          EaseVelocity, Negate16, ScaleVel
//   5. start / main_loop               one-time setup, intro, then per frame:
//        play_intro         (once) raster overture, bitmap intro + music,
//                           then the reveal
//        check_exit         RUN/STOP -> silence hardware, reset
//        update_input       keyboard -> speed level, status bar
//        update_sprites     ease, scale, integrate, edge bounce, spin frame
//        check_collisions   all 28 ball pairs, push apart, swap colors
//        apply_positions    write all 8 sprite positions to the VIC
//        update_effects     impact sparks, star twinkle, cooldowns
//        update_sound       age the ping cooldown
//   6. Helper routines                 reverse_x/y, new_heading, random_speed,
//                                      init_stars, draw_status,
//                                      spawn_spark,
//                                      draw_speed_bar, push_ball, sound, RNG
//   7. Data tables                     colors, status text, spark slots,
//                                      star positions, row offsets
//   8. #import "sprite_gen.asm"        8 shaded ball frames
//      #import "intro.asm"            the opening sequence (its own header)
//      #import "music.asm"            PSID import of the intro tune
//      #import "intro_gfx.asm"        spiral bitmap + carved logo + fields
//      #import "intro_sprites.asm"    the flying logo + sine table
//      #import "intro_raster.asm"     the raster bar overture + wipe bars
//        (both pull in intro_text.asm - glyph rows, assembly time only)
//
// MEMORY LAYOUT
// -------------
//   $0002-$0072  zero page variables (see below)
//   $0400-$07e7  text screen: stars, status row 24 (the sprite pointers
//                live at $07f8-$07ff inside the same 1K block)
//   $0801        BASIC stub "10 SYS 8768"  (8768 = $2240)
//   $0900-$09ff  raster bar line buffer: one colour per raster line
//   $3fff        VIC idle fetch - what the VIC displays in the opened
//                border, zeroed at start-up (see VIC_IDLE_FETCH)
//   $1000-$1d77  Nightshift.sid - player and music data, at its own load
//                address (invisible to the VIC, which sees char ROM here)
//   $2000-$21ff  8 ball frames, 64 bytes each  (VIC blocks $80-$87)
//   $2240-...    code and data tables
//   $3000-$3fe7  intro cell fields (4 x 1000 values, CPU only)
//   $4000-$5f3f  intro bitmap      (VIC bank 1, 8000 bytes)
//   $6000-$63e7  intro video matrix (VIC bank 1, filled at run time)
//   $63f8-$63ff  intro sprite pointers (VIC bank 1)
//   $6400-$65ff  intro logo sprites (VIC bank 1, 8 x 64 bytes)
//   $6600-$66ff  intro sine table   (CPU only)
//   $6700-$6ae7  intro wipe field   (CPU only)
//   $6b00-...    intro_raster.asm's code and data (CPU only)
//
// SPRITE ROLES
// ------------
//   sprites 0-7  the balls   (multicolor, 8 animation frames each)
// All eight of the VIC's sprites are balls. Lower-numbered sprites are
// drawn on top, so ball 0 passes in front of ball 7.
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
//     R                         restart from the top of the intro
//     Q, RUN/STOP               end the demo (resets the machine)
// Holding a speed key auto-repeats every KEY_REPEAT frames. The bottom
// The bottom TWO text rows are the menu: row 23 is a fixed legend of the
// keys, row 24 carries the speed bar and is redrawn on change.
//
// EDGE HANDLING
// -------------
// The vertical border is held open (see main_loop), so the playfield is
// the whole visible picture from top to bottom rather than the 25-row
// text window. Hard bounce limits are X 22..322 and Y 56..250: the balls
// fly over and below the status row, down into what would be the bottom
// border. When a ball reaches an edge its position is clamped and the
// velocity (and target) on that axis is reversed. The other axis is left
// alone, so a ball hitting the right wall while moving down keeps moving
// down - a clean reflection.
//
// Y 56 is a hardware floor, not a style choice. A sprite is triggered when
// the low 8 bits of the raster match its Y, and PAL lines 256..311 repeat
// the low bytes 0..55 - lines that are visible once the bottom border is
// open. A ball at Y < 56 is therefore drawn a second time as a ghost near
// the bottom of the screen. Verified in VICE: at MIN_Y 20 the top ball has
// a twin in the bottom border, at 56 it does not.
//
// X cannot be widened. The side borders are still closed, and a sprite
// outside the 24..343 window is clipped by them rather than drawn. Opening
// them needs a cycle-exact $d016 write on every raster line, which is a
// stable-raster IRQ effect and does not fit next to this much physics.
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
// stick together. Each hit also fires a ping and throws off a spark.
//
// ANIMATION
// ---------
// The eight 24x21 multicolor frames at $2000 are not hand-drawn: a
// KickAssembler script in sprite_gen.asm ray-shades a sphere with
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
// The intro has the whole SID to itself: Nightshift.sid plays on all three
// voices, driven one tick per frame from play_intro. init_sound then zeroes
// every register and takes voice 1 back for the sound effects, so the tune
// does not play under the demo. For the rest of the demo:
//
// SID voice 1 is a triangle wave with an instant attack, a ~200 ms decay
// and no sustain, and the filter bypassed - one plucked ping per trigger,
// which dies on its own with no per-frame envelope work. Every wall bounce
// and ball-to-ball hit calls trigger_ping with a pitch: PING_WALL ($24,
// a low knock) for a wall, one of $30/$38/$40/$48 picked at random for a
// ball-to-ball hit, so repeated hits do not sound mechanical. A PING_COOL
// cooldown of 6 frames keeps a cluster of contacts from machine-gunning.
//
// VISUAL EFFECTS
// --------------
//   * Starfield     - 32 '.' / '*' characters are scattered over the text
//                     screen at start-up. Every other frame one random star
//                     is given a random shade so the field twinkles.
//   * Impact spark  - a ball-to-ball hit writes a random ASCII spark
//                     ('*', '+', a filled or hollow circle) into the text
//                     cell at the point of contact. It cools from white
//                     through yellow and red over SPARK_LEN frames, then
//                     the cell's original character and color are put back
//                     (so a star underneath survives). Four sparks can be
//                     on screen at once.
//   * Intro reveal  - the opening runs in hi-res bitmap mode out of
//                     VIC bank 1, so it shares nothing with the demo's
//                     text screen and sprites; the handoff switches the
//                     bank, $d018 and $d016 back with DEN off, and the
//                     balls are simply there when it comes on. See
//                     intro.asm for the animation itself.
//   * Color swap    - colliding balls exchange body colors, and their
//                     A short cooldown stops the swap
//                     bouncing back and forth while the balls separate.
//
// FRAME TIMING
// ------------
// The main loop polls the raster ($d012) for line $fa, which is below the
// last text row after all sprites have been drawn. Positions written at
// that point are picked up cleanly on the next frame with no tearing. No
// IRQs are used; the CPU has nothing else to do.
//
// That same sync point is what holds the vertical border open: line 250 is
// the last line before the VIC would raise its border flip-flop, so the
// loop switches to 24 rows there and back to 25 once the frame's work is
// done. See main_loop.
//
//==================================================================

BasicUpstart2(start)            // emits a "10 SYS 8768" BASIC stub at $0801
                                // (8768 = $2240, where the code starts)

//------------------------------------------------------------------
// VIC-II Registers
//------------------------------------------------------------------
.label SPRITE_PTRS          = $07f8 // 8 sprite data pointers (block = addr/64)
.label VIC_SPRITE_X         = $d000 // sprite 0 X; sprite n X is at $d000+n*2
.label VIC_SPRITE_Y         = $d001 // sprite 0 Y; sprite n Y is at $d001+n*2
.label VIC_SPRITE_X_MSB     = $d010 // bit n = bit 8 of sprite n's X position
.label VIC_CONTROL1         = $d011 // bit 4 (DEN) = display enable; $1b = normal
.label VIC_RASTER           = $d012 // current raster line (low 8 bits)
.label VIC_SPRITE_ENABLE    = $d015 // bit n = sprite n visible
.label VIC_CONTROL2         = $d016 // bit 4 (MCM) = multicolor; $08 = normal
.label VIC_MEMORY_SETUP     = $d018 // video matrix (bits 7-4) / charset or bitmap
.label VIC_SPRITE_EXPAND_Y  = $d017 // bit n = sprite n double height
.label VIC_SPRITE_PRIORITY  = $d01b // bit n = sprite n behind background
.label VIC_SPRITE_MULTI     = $d01c // bit n = sprite n multicolor mode
.label VIC_SPRITE_EXPAND_X  = $d01d // bit n = sprite n double width
.label VIC_BORDER           = $d020
.label VIC_BACKGROUND       = $d021
.label VIC_SPRITE_MCOLOR0   = $d025 // shared multicolor 0 (bit pair 01)
.label VIC_SPRITE_MCOLOR1   = $d026 // shared multicolor 1 (bit pair 11)
.label VIC_SPRITE_COLOR     = $d027 // sprite n color at $d027+n (bit pair 10)

.label VIC_IDLE_FETCH       = $3fff // last byte of VIC bank 0: the VIC's idle
                                    // fetch, i.e. what it reads in an opened
                                    // border. $39ff instead if ECM is set

.label SCREEN_RAM           = $0400 // default text screen, 1000 bytes
.label COLOR_RAM            = $d800 // one color nibble per screen cell
.label LEGEND_ROW           = 23 * 40 // key legend row  (offset 920)
.label STATUS_ROW           = 24 * 40 // bottom text row (offset 960)

//------------------------------------------------------------------
// CIA1 keyboard matrix: write a row mask (active low) to PORT_A, read
// the column bits (active low) from PORT_B.
//------------------------------------------------------------------
.label CIA1_PORT_A          = $dc00
.label CIA1_PORT_B          = $dc01
.label CIA1_DDR_A           = $dc02
.label CIA1_DDR_B           = $dc03
.label CIA1_ICR             = $dc0d     // timer/IRQ mask and latch
.label CIA1_TIMER_A_HI      = $dc05     // free-running timer, used for the
                                        // RNG seed: it keeps counting with
                                        // interrupts off, unlike the jiffy
                                        // clock at $a2
.label CIA2_PORT_A          = $dd00      // bits 0-1 = VIC bank select
.label CIA2_DDR_A           = $dd02      // bits 0-1 must be outputs
.label CIA2_ICR             = $dd0d      // NMI mask/latch
.label NMI_VECTOR           = $0318      // kernal NMI vector: $fe43 does
                                         // sei then jmp ($0318)

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
// Each per-sprite value is an 8-byte table indexed by X (X = sprite 0..7),
// e.g. "lda x_lo, x". Zero page is used because indexed zero-page access
// is one cycle faster and one byte shorter than absolute addressing.
//
// $02..$8f belong to BASIC normally, but we never return to BASIC and
// interrupts are disabled, so they are ours.
//
// EIGHT BALLS IS WHAT ZERO PAGE WILL HOLD. Fifteen per-ball tables at 8
// bytes each is 120 bytes, $02-$79, which leaves $7a-$94 for everything
// global. There is no room for a ninth ball and none for a second table
// per ball - which is the real reason the ghost trails had to go, quite
// apart from wanting their sprites back.
//
//   $02-$95  global state (RNG, timers, scratch, speed, keyboard, ptr)
//   BALL_STATE (absolute, not zero page)  18 per-ball tables, see below
//
// THE INTRO'S OWN VARIABLES OVERLAP THIS GLOBAL BLOCK ($02-$10 plus
// temp/temp2). play_intro runs to completion before start touches a
// single ball byte, so the two are never live at the same time.
// Nightshift has zero page scratch of its own and we have no
// disassembly of it, so the evidence that the two do not collide is
// empirical: the intro renders correctly under VICE. It has never been
// checked on real hardware. If the tune is ever swapped for another,
// this is the first thing to re-test.
//------------------------------------------------------------------

// Global state, all single bytes (nothing here is a per-ball array any
// more - see BALL_STATE below for those). Everything from $7a on is
// written after play_intro returns.
.label seed         = $7a       // 16-bit RNG state ($7a low, $7b high)
.label frame_count  = $7c       // free-running frame counter
.label temp         = $7d       // scratch, low byte of 16-bit temporaries
.label temp2        = $7e       // scratch, high byte (shared with the intro)
.label ping_cool    = $7f       // frames until another ping may be triggered
.label want_sx      = $80       // collision: desired X velocity sign ($00/$ff)
.label want_sy      = $81       // collision: desired Y velocity sign ($00/$ff)
.label save_x       = $82       // collision: saved ball index
.label swap_cool    = $83       // frames until balls may swap colors again
.label ptr          = $84       // 16-bit pointer for (ptr),y access ($84/$85)
                                 // MUST stay zero page: indirect indexed
                                 // addressing has no absolute form
.label m0           = $86       // ScaleVel: 24-bit multiplicand ($86..$88)
.label p0           = $89       // ScaleVel: 24-bit product ($89..$8b)
.label vsign        = $8c       // ScaleVel: sign of the input velocity
.label speed        = $8d       // global speed level 1..16 (8 = base speed)
.label key_timer    = $8e       // auto-repeat countdown while a key is held
.label evx_lo       = $8f       // effective X velocity this frame, 8.8
.label evx_hi       = $90
.label evy_lo       = $91       // effective Y velocity this frame, 8.8
.label evy_hi       = $92
.label key_shift    = $93       // nonzero if either shift key is down
.label key_delta    = $94       // +1 / -1 speed change requested, 0 = none
.label active_balls = $95       // how many of MAX_BALLS are in play, 4..16

// Sprite multiplexing scratch: sort_balls' insertion sort, apply_band's
// per-band raster write, and the busy-wait between bands. See BALL_STATE
// above for ball_order itself (a per-ball ARRAY, so it lives there, not
// here - these are all single bytes).
.label sort_i        = $96      // insertion sort: outer index i
.label sort_j         = $97      // insertion sort: inner (shifting) index j
.label band1_trigger  = $98      // raster line to wait for before band 1
.label band_base      = $99      // apply_band: which ball_order slot its
                                  // hardware sprite 0 starts at (0 or 8)
.label band_slot      = $9a      // apply_band: hardware sprite index 0..7
.label band_enable    = $9b      // apply_band: VIC_SPRITE_ENABLE being built
.label band_msb       = $9c      // apply_band: VIC_SPRITE_X_MSB being built
.label pair_a          = $9d      // check_collisions: ball A's identity,
                                   // held across the inner loop - kept
                                   // separate from check_pair's OWN
                                   // save_x (which check_pair also
                                   // happens to hold ball A in, but that
                                   // is check_pair's internal business,
                                   // not a contract check_collisions
                                   // should depend on)
.label ball_key_timer = $9e       // update_input: B/SHIFT+B's own repeat
                                   // timer, separate from key_timer so
                                   // holding one control never disturbs
                                   // the other's repeat cadence

//------------------------------------------------------------------
// BALL_STATE - the per-ball tables, OUT of zero page.
//
// The VIC has 8 hardware sprites; this demo now multiplexes MAX_BALLS
// logical balls across them with a raster split (see apply_bands). Zero
// page has no room for that: 15 tables x 16 balls is 240 bytes, more
// than all of $02-$FF. So these live in ordinary RAM instead, reusing
// the intro's dead memory - it is done with all of VIC bank 1 by the
// time a single ball byte gets written, and the CPU can read/write
// there regardless of VIC bank (bank-switching only changes what the
// VIC CHIP fetches, never what the CPU sees). This is the same trick
// the zero page block above already plays with the intro's own
// variables.
//
// $3000-$3fe7 (the four wave fields) looks like the obvious spot, and
// was the first thing tried - but Main Code starts at $2240 and only
// had about 40 bytes of headroom before $3000 even BEFORE this file's
// sort/band routines were added, and KickAssembler hard-errors the
// moment Main Code's own bytes reach an address intro_gfx.asm has
// already claimed with `* = INTRO_WAVE_A`. Past the END of the intro's
// memory instead - after intro_raster.asm's code and data, which ends
// around $70d3 - there is nothing else in VIC bank 1 all the way to
// $7fff: safe from Main Code's growth in either direction.
//
// Moving off zero page costs nothing per access: `lda table,x` is 4
// cycles whether table is zero page or absolute (only zero-page,X is
// special-cased by the 6502, and only for the NON-indexed forms this
// file never uses) - one extra opcode byte, no extra cycles. `ptr`
// above is the one table that could not move: (ptr),y has no absolute
// form on the 6502.
//
// Every table is MAX_BALLS bytes, computed as an offset so raising
// MAX_BALLS later (e.g. to try 24 balls in 3 bands) is a single-constant
// change, not a relayout.
//------------------------------------------------------------------
.label MAX_BALLS    = 16        // compiled ceiling; active_balls <= this
.label BALL_STATE   = $7200     // well past intro_raster.asm's own code
                                 // and data, clear to $7fff - see above

.label x_frac       = BALL_STATE + 0  * MAX_BALLS  // X pos, fraction (1/256 px)
.label x_lo         = BALL_STATE + 1  * MAX_BALLS  // X pos, whole pixels (low 8)
.label x_msb        = BALL_STATE + 2  * MAX_BALLS  // X pos, bit 8 (0 or 1)
.label y_frac       = BALL_STATE + 3  * MAX_BALLS  // Y pos, fraction
.label y_pix        = BALL_STATE + 4  * MAX_BALLS  // Y pos, whole pixels
.label vx_lo        = BALL_STATE + 5  * MAX_BALLS  // X velocity, signed 8.8, lo
.label vx_hi        = BALL_STATE + 6  * MAX_BALLS  // X velocity, signed 8.8, hi
.label vy_lo        = BALL_STATE + 7  * MAX_BALLS  // Y velocity, signed 8.8
.label vy_hi        = BALL_STATE + 8  * MAX_BALLS
.label tvx_lo       = BALL_STATE + 9  * MAX_BALLS  // X target velocity, 8.8
.label tvx_hi       = BALL_STATE + 10 * MAX_BALLS
.label tvy_lo       = BALL_STATE + 11 * MAX_BALLS  // Y target velocity, 8.8
.label tvy_hi       = BALL_STATE + 12 * MAX_BALLS
.label anim_lo      = BALL_STATE + 13 * MAX_BALLS  // spin accumulator, 8.8
.label anim_hi      = BALL_STATE + 14 * MAX_BALLS  //   bits 3-5 = current frame
.label ball_ptr     = BALL_STATE + 15 * MAX_BALLS  // this ball's sprite-data
                                                     // pointer (block number),
                                                     // written to hardware
                                                     // only when its band comes
                                                     // up - see apply_bands
.label ball_color   = BALL_STATE + 16 * MAX_BALLS  // this ball's body color,
                                                     // same story
.label ball_order   = BALL_STATE + 17 * MAX_BALLS  // ball indices, sorted
                                                     // ascending by y_pix each
                                                     // frame - see sort_balls

// The intro's own variables, overlapping the ball tables (see above).
.label paint_page   = $02       // which 256-cell page the sweep is on
.label wave_pg      = $03       // high byte of the active cell field
.label text_phase   = $04       // position of the carved logo's glint
.label flow_t       = $05       // flying logo, horizontal sine phase
.label flow_t2      = $06       // flying logo, vertical sine phase
.label flow_t3      = $07       // flying logo, ripple sine phase
.label spr_msb      = $08       // X bit 8 bits gathered for $d010
.label pal_phase    = $09       // position in the spiral's color ramp
.label pal_step     = $0a       // frames between ramp steps
.label pal_tick     = $0b       // countdown to the next ramp step
.label intro_t      = $0c       // frames left in the current phase
.label fade_stage   = $0d       // how many band colors are live (0-2)
.label vm_byte      = $0e       // byte filled into the video matrix
.label wipe_t       = $0f       // how far the closing wipe has got
.label flow_hold    = $10       // frames the flying logo still holds still
.label ripple_sh    = $11       // flying logo, ripple shift: 7 down to 4,
                                // so the ripple fades in after the hold

//------------------------------------------------------------------
// Constants
//------------------------------------------------------------------
.label HW_SPRITES   = 8       // all eight the VIC has - fixed, always this
.label BAND_SIZE     = HW_SPRITES     // balls per raster band = hardware
                                        // sprites; see apply_bands
.label ACTIVE_BALLS_MIN     = 4
.label ACTIVE_BALLS_DEFAULT = 8       // the original ball count
.label ACTIVE_BALLS_MAX     = MAX_BALLS

// $d011 bit patterns. RSEL (bit 3) picks 25 rows or 24; the main loop
// flips it every frame to hold the vertical border open (see main_loop).
.label CTRL1_25ROWS = $1b       // DEN on, RSEL 25 rows, YSCROLL 3 - normal
.label CTRL1_24ROWS = $13       // same with RSEL cleared: 24 rows
.label CTRL1_BLANK  = $0b       // DEN cleared: display off entirely

// Screen edges in sprite coordinates. With the vertical border open the
// playfield is no longer the 25-row text window - sprites are displayed
// from the top border right down through the bottom one, so the limits
// are set by what the screen actually shows.
//
// Y is the interesting axis. A sprite is triggered when the low 8 bits of
// the raster match its Y, and PAL raster lines 256..311 repeat the low
// bytes 0..55. With BOTH borders open those lines are visible, so a ball
// at Y < 56 would be drawn a second time as a ghost in the bottom border.
// MIN_Y is therefore 56 rather than 0 - that is a hardware limit, not a
// cosmetic one.
//
// X cannot grow: the side borders are still closed, so a sprite either
// side of the 24..343 window is simply clipped. See the header.
.label MIN_X        = 22        // left edge (ball touches border)
.label MAX_X_LO     = 66        // right edge = 322 = $142 (MSB=1, lo=$42)
.label MIN_Y        = 56        // top edge: the lowest Y with no ghost twin
.label BAND1_LEAD   = 8         // lines of lead time band 1's raster wait
                                 // gets before the topmost band-1 ball's
                                 // own Y - apply_band costs well under a
                                 // raster line's worth of cycles for its
                                 // eight sprites, so this is generous
.label MAX_Y        = 250       // bottom edge, deep in the opened border:
                                // the disc's last row lands on line 270,
                                // still well inside the visible picture

// Ball-to-ball collision thresholds (see header). Ball diameter is 20 px.
.label BALL_DIAM    = 20
.label BALL_SUM     = 30        // |dx| + |dy| limit, rounds the corners

.label SPRITE_DATA      = $2000             // 8 frames x 64 bytes = $2000..$21ff
.label SPRITE_PTR_BASE  = SPRITE_DATA / $40 // = $80, the VIC block number

// Effects
.label STAR_COUNT   = 32        // stars on the background (power of 2)
.label SWAP_COOL    = 16        // frames between color swaps
.label SPARK_SLOTS  = 4         // impact sparks that can be on screen at once
.label SPARK_LEN    = 10        // frames a spark stays on screen

// Sound
.label PING_COOL    = 6         // frames between pings (stops machine-gunning)
.label PING_WALL    = $24       // wall bounce pitch (freq high byte)

// Opening sequence. The bitmap lives in VIC bank 1 ($4000-$7fff): the
// bitmap itself at the bottom of the bank, the video matrix 8K above it.
.label INTRO_BITMAP = $4000     // 8000 bytes, generated in intro_gfx.asm
.label INTRO_VM     = $6000     // 1000 video matrix cells, painted by
                                // paint_sweep. In hi-res each byte is two
                                // colors: high nibble ink, low nibble paper
// These four used to sit at $3000-$3fe7, immediately before the bitmap.
// They moved here, overlapping BALL_STATE, when Main Code grew past
// $3000 - see BALL_STATE's own comment. The VIC never fetches these
// (paint_sweep reads them with the CPU only), so unlike the bitmap they
// have no hardware reason to sit next to it, and reusing BALL_STATE's
// footprint is the same "dead by the time the other user starts" trick
// BALL_STATE already documents: play_intro (and every read of these
// four fields) finishes completely before init_sprites writes the
// first byte of ball state. Each still has to start on its OWN page
// boundary - set_page's page_lo table assumes the field's low byte is
// $00 - which is why they are $400 apart rather than packed at 1000.
.label INTRO_WAVE_A = BALL_STATE          // = $7200; rings
.label INTRO_WAVE_B = BALL_STATE + $400   // = $7600; 1 turn
.label INTRO_WAVE_C = BALL_STATE + $800   // = $7a00; 3 turns
.label INTRO_WAVE_D = BALL_STATE + $c00   // = $7e00; plasma - runs to $81e7,
                                            // just past $8000. Free RAM: no
                                            // cartridge is ever present, so
                                            // nothing maps ROM there.
.label INTRO_SPR    = $6400     // 8 x 64 bytes, the flying logo (bank 1)
.label INTRO_SPR_PTR = (INTRO_SPR - $4000) / $40  // = $90. A VIC block number
                                        // is relative to the START OF THE
                                        // BANK, so the bank base has to come
                                        // off first: INTRO_SPR / $40 would be
                                        // $190, which only assembles at all
                                        // because the immediate is truncated
.label INTRO_SPR_PTRS = INTRO_VM + $3f8  // = $63f8, bank 1 sprite pointers
.label INTRO_SIN    = $6600     // 256-entry sine, one period (intro_sprites)
.label INTRO_WIPE   = $6700     // 1000 cell wipe order, 0 first .. 15 last
.label INTRO_Z_LEN  = 60        // blank hold before anything (~1.2 s PAL)
.label INTRO_T_LEN  = 90        // the title card, on black (~1.8 s PAL)
.label INTRO_A_LEN  = 112       // rings fade up       (~2.2 s PAL)
.label INTRO_B_LEN  = 176       // accelerating spiral, logo flies in (~3.5 s)
.label INTRO_F_LEN  = 224       // tight field, logo still flying (~4.5 s)
.label INTRO_C_LEN  = 112       // tight wind-up       (~2.2 s PAL)
.label INTRO_D_LEN  = 24        // last burst + white flash (~0.5 s PAL)
.label INTRO_W_LEN  = 32        // spiral wipe into the demo (~0.64 s PAL)
.label INTRO_HOLD   = 150       // frames the logo holds its entry pose (~3 s)
// The entry pose has to be the carved logo's position EXACTLY, or the
// logo jumps the moment the carving goes dark and the sprites light up.
// Bitmap pixel (px, py) is displayed at sprite coordinates (px + 24,
// py + 51), so the carve at (64, 136) and (120, 160) means the sprites
// must come up at (88, 187) and (144, 211). x_phase and y_phase are
// chosen to put the sine exactly there at phase 0 - see intro.asm.
.label FLOW_Y_BASE  = 84        // bottom of the flight path: Y runs
                                // FLOW_Y_BASE .. FLOW_Y_BASE + 127, i.e.
                                // 84..211, so it reaches the carved date
.label FLOW_T2_HOME = 0         // the home bob phase is baked into y_phase
                                // the date at y=136 - see flow_logo_on

// Speed control
.label SPEED_MIN    = 1
.label SPEED_MAX    = 16
.label SPEED_DEFAULT = 4        // half of base speed
.label KEY_REPEAT   = 6         // frames between repeats while a key is held
.label BAR_COL      = 4         // screen column of the first bar cell
.label BAR_LEN      = 16        // one cell per speed level
.label BALL_COUNT_COL = 24      // screen column of the ball-count's tens
                                 // digit on the status row, see status_text

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

// $0810 is not available any more: Nightshift.sid loads at $1000-$1d77 and
// a PSID's player is not relocatable, so the code goes above the sprite
// data instead. $2240-$3fff is free RAM in VIC bank 0 and the VIC never
// fetches from it.
* = $2240 "Main Code"

//------------------------------------------------------------------
// Entry Point - one-time setup, then falls into main_loop
//------------------------------------------------------------------
start:
    sei                         // no IRQs: kernal keyboard scan etc. off
                                // (we scan the keyboard ourselves)
    ldx #$ff                    // reset the stack. R restarts by jumping
    txs                         // here from inside check_exit, several jsrs
                                // deep, so without this every restart would
                                // strand a return address and the stack
                                // would eventually wrap into zero page
    // sei does not mask NMI, and NMI reaches us two ways. $dd0d turns off
    // CIA 2's own sources (timers, TOD, FLAG); the write masks them and the
    // read acknowledges anything already latched.
    lda #$7f
    sta CIA2_ICR
    lda CIA2_ICR

    // Same for CIA 1's timer IRQs. sei already covers us and is never
    // undone, so this is belt-and-braces, but it means the machine is not
    // relying on the I flag alone to stay out of the kernal.
    lda #$7f
    sta CIA1_ICR
    lda CIA1_ICR

    // RESTORE is the other way, and $dd0d cannot touch it: the key is wired
    // to /NMI through a monostable, not through CIA 2. The kernal handler
    // checks $dd0d, finds no CIA 2 source pending, falls through to the
    // stop-key scan and - with RUN/STOP also held - jumps to BASIC's warm
    // start, on top of the zero page we have overwritten. Taking the NMI
    // vector is what actually stops it; the kernal is banked in, so $0318
    // is the vector it uses.
    lda #<nmi_ignore
    sta NMI_VECTOR
    lda #>nmi_ignore
    sta NMI_VECTOR + 1

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

    lda #$00                    // black border and background: the stars
    sta VIC_BORDER              // and the ball colors pop against it
    sta VIC_BACKGROUND

    lda #$ff                    // CIA1 port A = output (row select),
    sta CIA1_DDR_A              // port B = input (columns)
    lda #$00
    sta CIA1_DDR_B

    // The intro runs FIRST, because the SID player has zero page scratch of
    // its own and there is no guarantee it stays clear of ours. Everything
    // the demo needs is set up afterwards, once the tune has stopped.
    jsr play_intro              // music + spiral bitmap, ends in text mode
                                // with the display still off

    // Seed the RNG. The xorshift generator sticks at zero, so a bit is
    // forced on in each byte. Seeded after the intro, so the SID player
    // cannot have clobbered it.
    //
    // The raster alone is not enough: the intro is frame-locked and always
    // the same length, so it lands on nearly the same line every run. CIA 1
    // timer A keeps counting with interrupts off (the jiffy clock at $a2
    // does not), and nothing here resets it, so its high byte is genuinely
    // different from one run to the next.
    lda VIC_RASTER
    ora #$01
    sta seed
    lda CIA1_TIMER_A_HI
    ora #$80
    sta seed + 1

    lda #$00                    // demo state: set AFTER the intro, because
    sta swap_cool               // the intro's variables share these bytes
    sta key_timer               // with the ball tables
    sta ball_key_timer
    lda #SPEED_DEFAULT
    sta speed

    jsr init_stars              // scatter the background stars
    jsr draw_status             // status text + speed bar on row 24
    jsr init_sprites            // VIC sprite setup, random ball state -
                                 // sets active_balls, so its readout has
                                 // to be drawn AFTER, not as part of the
                                 // draw_status call above
    jsr draw_ball_count
    jsr init_sound              // silence the tune; voice 1 = ping SFX

    // With the vertical border open the VIC spends the border lines in its
    // idle state, fetching from the last byte of the bank ($3fff in bank 0,
    // $39ff if ECM is ever set) instead of from the screen.
    //
    // This is not load-bearing TODAY: in idle state the VIC also forces the
    // color data to 0, so a 1-bit is drawn in black and a 0-bit in $d021 -
    // and $d021 is black, so the opened border is black whatever $3fff
    // holds. It becomes load-bearing the moment the background is not
    // black, which is cheap enough to guarantee in advance.
    lda #$00
    sta VIC_IDLE_FETCH

    lda #CTRL1_25ROWS           // DEN on: text mode, stars and status appear
    sta VIC_CONTROL1
    lda #%11111111              // all eight balls on
    sta VIC_SPRITE_ENABLE

//------------------------------------------------------------------
// Main Loop - runs exactly once per frame (50 Hz PAL / 60 Hz NTSC)
//
// Up to MAX_BALLS logical balls are multiplexed across the VIC's 8
// hardware sprites, in up to 2 raster bands (see apply_band). Band 0
// publishes at the top of the frame, same timing this used to be the
// ONLY publish at - the previous frame's physics results, so the VIC
// always reads a complete, consistent set of coordinates and the new
// ones land next frame. Band 1, when there is one, has to publish LATER
// - part way down the very frame it is about to be drawn in - so the
// bulk of the frame's CPU work (update_sprites, sort_balls) is placed
// BETWEEN the two publishes on purpose: that work has to happen
// sometime, and doing it while the raster is travelling from band 0's
// balls to band 1's is exactly the same lines that would otherwise be
// spent idle in a busy-wait. See the sprite-multiplexing plan doc for
// the cycle-budget reasoning this is built to satisfy.
//------------------------------------------------------------------
main_loop:
    lda #$fa                    // wait for raster line 250 (lower border)
wait_raster:
    cmp VIC_RASTER
    bne wait_raster

    // Hold the vertical border open. The VIC sets its vertical border
    // flip-flop on the first line of the bottom border - 251 with RSEL=1,
    // 247 with RSEL=0. Switching to 24 rows here on line 250 means the
    // line it is now waiting for (247) is already behind us, so the
    // flip-flop is never set: no bottom border this frame and no top
    // border on the next one, and the sprites carry on into both.
    lda #CTRL1_24ROWS
    sta VIC_CONTROL1

    // ...and back to 25 rows two lines later, so the next frame can do it
    // again. This waits rather than restoring at the end of the frame's
    // work: the legal window is line 252 to line 246 of the NEXT frame, and
    // restoring after the work put it at line 166-198 (measured) - correct,
    // but only because the work happens to take ~235 raster lines. Anything
    // that made the loop heavier would slide that write into 247-251, set
    // the flip-flop and flash a border top and bottom. Two lines of waiting
    // costs ~130 cycles and makes the border independent of the workload.
    lda #$fc
rs_wait:
    cmp VIC_RASTER
    bne rs_wait
    lda #CTRL1_25ROWS
    sta VIC_CONTROL1

    // Band 0: publish last frame's TOP-of-frame balls (ball_order[0..7],
    // lowest Y first) right at the top, same timing apply_positions
    // always used - the raster is not due at MIN_Y for a good while yet.
    lda #$00
    jsr apply_band
    jsr check_exit              // RUN/STOP quits the demo
    jsr update_input            // keyboard: speed level, ball count

    // The bulk of the frame's CPU work goes HERE, between band 0's
    // publish and band 1's - filling exactly the raster lines that have
    // to elapse anyway for the picture to reach band 1's balls, rather
    // than idling through them. update_sprites computes NEXT frame's
    // positions (the usual one-frame pipeline - see the header above);
    // sort_balls immediately re-sorts them fresh, which is also what
    // decides band 1's trigger line below and what check_collisions
    // sweeps after band 1 fires.
    jsr update_sprites          // physics, edges, animation frame
    jsr sort_balls               // fresh ball_order for band 1 and collisions

    // Band 1: only if there IS one - active_balls <= HW_SPRITES means
    // everything fit in band 0 and there is nothing more to publish.
    lda active_balls
    cmp #HW_SPRITES + 1
    bcc ml_no_band1

    ldy #HW_SPRITES              // ball_order[8]: the topmost band-1 ball
    lda ball_order, y
    tax
    lda y_pix, x
    sec
    sbc #BAND1_LEAD
    bcs ml_trigger_ok             // no borrow: still non-negative
    lda #MIN_Y                    // underflowed - this ball is already
ml_trigger_ok:                    // right near the top; clamp instead
    cmp #MIN_Y
    bcs ml_trigger_store
    lda #MIN_Y                    // never trigger inside the ambiguous
ml_trigger_store:                 // low-byte range PAL lines 256-311 share
    sta band1_trigger             // with 0-55 - see MIN_Y's own comment

    lda band1_trigger
    jsr wait_raster_a
    lda #HW_SPRITES
    jsr apply_band
ml_no_band1:

    // Not time-critical from here on - nothing below touches a VIC
    // register, so it can take however long it takes, same as before.
    jsr check_collisions         // ball-to-ball contact, push apart
    jsr update_effects           // impact sparks, twinkling stars
    jsr update_sound             // age the ping cooldown
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
// The opening sequence lives in its own files: intro.asm is the code
// (music + spiral bitmap + the handoff to text mode), intro_gfx.asm
// generates the bitmap at assembly time, music.asm imports the tune.
// play_intro is called once from start, before anything else is set up.
//------------------------------------------------------------------
#import "intro.asm"


intro_flash:                    // phase D white-out, indexed by intro_t,
    .byte $01, $01, $0f, $0f    // so it reads 7 -> 1: cyan, light blue,
    .byte $0e, $0e, $03, $03    // light grey, white. Entry 0 is unreachable.

//------------------------------------------------------------------
// nmi_ignore - swallow every NMI.
//
// $0318 points here, so RESTORE (alone or with RUN/STOP) reaches an rti
// instead of the kernal's handler, which would otherwise run the stop-key
// scan over our zero page and warm-start BASIC. RUN/STOP on its own is
// unaffected: that is a keyboard matrix read in check_exit, not an NMI.
//------------------------------------------------------------------
nmi_ignore:
    rti

//------------------------------------------------------------------
// check_exit - RUN/STOP ends the demo (the repo-wide demo exit key)
//
// RUN/STOP is row 7 ($7f on port A), column bit 7, active low like every
// other key. Because the demo runs with interrupts off and has written
// all over BASIC's zero page, there is nothing sane to return to: the
// clean exit is to silence the hardware and jump through the kernal
// RESET vector at $fffc, which gives a normal READY. prompt.
//------------------------------------------------------------------
check_exit:
    lda #$7f                    // row 7 carries BOTH exit keys: RUN/STOP is
    sta CIA1_PORT_A             // bit 7 and Q is bit 6, so one read covers
    lda CIA1_PORT_B             // them both
    and #$c0
    cmp #$c0
    bne exit_demo               // either bit clear = that key is down

    lda #$fb                    // row 2: R restarts from the very beginning
    sta CIA1_PORT_A
    lda CIA1_PORT_B
    and #$02                    // R is row $fb, bit 1
    beq restart_demo

    lda #$ff                    // deselect all rows again
    sta CIA1_PORT_A
    rts

//------------------------------------------------------------------
// restart_demo - R: run the whole thing again from the intro.
//
// Called from check_exit, so it works during the intro as well as during
// the demo. Everything the program needs is set up by start, and the
// intro's zero page overlaps the ball tables anyway, so there is nothing
// to tear down but the hardware: the SID has to be silenced (the intro
// re-initialises the tune, but a ping left gated would carry over the
// cut) and the sprites hidden before the mode switch.
//
// The wait for R to come back up matters: check_exit runs every frame, so
// without it holding the key down would restart the intro on every frame
// and the screen would sit frozen on its first black frame.
//------------------------------------------------------------------
restart_demo:
    lda #$00
    ldx #$18                    // silence all 25 SID registers
rd_sid:
    sta SID_BASE, x
    dex
    bpl rd_sid
    sta VIC_SPRITE_ENABLE       // A is still 0: all sprites off

rd_release:
    lda #$fb                    // hold here until R is released
    sta CIA1_PORT_A
    lda CIA1_PORT_B
    and #$02
    beq rd_release
    lda #$ff
    sta CIA1_PORT_A
    jmp start

exit_demo:
    lda #$00
    ldx #$18                    // silence all 25 SID registers
ed_loop:
    sta SID_BASE, x
    dex
    bpl ed_loop
    sta VIC_SPRITE_ENABLE       // A is still 0: all sprites off
    lda #CTRL1_25ROWS           // display on, 25 rows (we may be exiting
    sta VIC_CONTROL1            // the intro, or a frame with the border open)
    lda #$ff
    sta CIA1_PORT_A
                                // no cli: $fffc does sei itself, and an IRQ
                                // taken here would run on trashed zero page
    jmp ($fffc)                 // kernal RESET vector -> clean BASIC

//------------------------------------------------------------------
// init_sprites - VIC setup, plus random starting state for every ball
// the game could ever activate.
//
// All MAX_BALLS are initialised here, not just active_balls of them -
// so raising the count at run time (see update_input's B key) just
// widens the loops that STEP and DISPLAY balls; the extra balls already
// have valid physics state sitting there waiting, rather than needing a
// separate "activate ball N" path that re-inits them on demand.
//------------------------------------------------------------------
init_sprites:
    lda #%11111111              // all eight HARDWARE sprites are always
    sta VIC_SPRITE_ENABLE       // on - multiplexing reprograms what they
    sta VIC_SPRITE_MULTI        // show, never how many are enabled

    // Point every hardware sprite at frame 0 before anything can be
    // displayed. apply_bands rewrites these every frame once a ball is
    // assigned to that slot, but it does not run until after start has
    // enabled the display - so without this the first displayed frame
    // draws all eight from whatever block $07f8-$07ff held at load time.
    // This is the 8 HARDWARE registers, not MAX_BALLS - $07f8-$07ff is
    // always exactly 8 bytes regardless of how many balls are in play.
    ldx #HW_SPRITES - 1
    lda #SPRITE_PTR_BASE
init_ptrs:
    sta SPRITE_PTRS, x
    dex
    bpl init_ptrs

    lda #$00
    sta VIC_SPRITE_X_MSB        // all X < 256 until apply_bands runs
    sta VIC_SPRITE_EXPAND_X     // normal size
    sta VIC_SPRITE_EXPAND_Y
    sta VIC_SPRITE_PRIORITY     // sprites in front of background

    // Multicolor sprites share two colors across all sprites; the third
    // color is per sprite. These are the sphere's highlight and shadow.
    lda #$01                    // white  -> bit pair 01 (highlight)
    sta VIC_SPRITE_MCOLOR0
    lda #$0b                    // dark grey -> bit pair 11 (shadow)
    sta VIC_SPRITE_MCOLOR1

    // Every ball's LOGICAL body color (bit pair 10). Not the hardware
    // register - that gets written per band, from ball_color, by
    // apply_bands. Writing VIC_SPRITE_COLOR directly here would only
    // ever be seen for the balls that happen to land in band 0 on the
    // very first frame.
    ldx #MAX_BALLS - 1
init_colors:
    lda sprite_colors, x
    sta ball_color, x
    dex
    bpl init_colors

    lda #ACTIVE_BALLS_DEFAULT   // start at the original 8; B raises it,
    sta active_balls            // SHIFT+B lowers it (see update_input)

    // Per-ball state, all MAX_BALLS of them. Loop X = MAX_BALLS-1 down to 0.
    ldx #MAX_BALLS - 1
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

    // ball_order starts as the identity permutation (slot i holds ball
    // i). sort_balls only ever permutes entries 0..active_balls-1 among
    // THEMSELVES, so this is the only place that ever needs to write it
    // from scratch - raising active_balls later just widens the range
    // sort_balls sorts; the newly-exposed tail slot already holds its
    // own ball's index, ready to be walked into position next frame.
    ldx #MAX_BALLS - 1
init_order:
    txa
    sta ball_order, x
    dex
    bpl init_order
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
    ldx active_balls            // runtime count now, not a constant - only
    dex                         // the balls actually in play get stepped,
update_loop:                    // so raising/lowering it changes the cost
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
    sta ball_ptr, x              // this ball's LOGICAL pointer - written to
                                  // hardware only when apply_band gets to
                                  // this ball's band, not here directly

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
// zeroed so the clamped position is exact. Each bounce fires a low ping
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
    lda #PING_WALL
    jmp trigger_ping            // tail call

reverse_y:
    lda #$00
    sta y_frac, x
    Negate16(vy_lo, vy_hi)
    lda vy_hi, x
    eor tvy_hi, x
    bpl ry_done
    Negate16(tvy_lo, tvy_hi)
ry_done:
    lda #PING_WALL
    jmp trigger_ping            // tail call

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
// sort_balls - insertion sort ball_order[0..active_balls-1] ascending
// by y_pix[ball_order[i]].
//
// Two levels of indirection: the SORT KEY for slot i is not y_pix[i],
// it is y_pix[ball_order[i]] - ball_order holds ball IDENTITIES, and
// those are what get moved around, not the balls' table rows themselves.
//
// Insertion sort, not anything fancier, because the input is nearly
// sorted every single frame - balls move about a pixel a frame, so last
// frame's order is almost always still correct and each pass is close
// to O(n). It also means a newly activated ball (see update_input) just
// walks into place over its first frame or two: nothing has to notice
// active_balls changed and re-sort specially.
//------------------------------------------------------------------
sort_balls:
    lda #$01
    sta sort_i
si_outer:
    lda sort_i
    cmp active_balls
    bcs si_done                  // i >= active_balls: sorted

    tay
    lda ball_order, y           // the ball to insert this pass
    sta temp                     // temp = its identity
    tay
    lda y_pix, y
    sta temp2                    // temp2 = its sort key

    lda sort_i
    sec
    sbc #$01
    sta sort_j                   // j = i - 1
si_shift:
    lda sort_j
    bmi si_place                 // j < 0: nothing left to compare against
    tay
    lda ball_order, y           // the element sitting at slot j
    tax                          // X = ITS identity, to key off y_pix
    lda y_pix, x
    cmp temp2
    bcc si_place                 // y_pix[ball_order[j]] < our key: stop here

    lda ball_order, y           // still bigger (or equal): shift it up
    iny
    sta ball_order, y
    dec sort_j
    jmp si_shift
si_place:
    lda sort_j
    clc
    adc #$01
    tay
    lda temp
    sta ball_order, y

    inc sort_i
    jmp si_outer
si_done:
    rts

//------------------------------------------------------------------
// wait_raster_a - busy-wait until VIC_RASTER == A.
//
// The same equality-poll idiom main_loop and intro_raster.asm's rb_show
// already use. If the target line has ALREADY passed this frame (the
// caller was slower than expected), this spins all the way round to the
// same line next frame rather than firing late - self-healing, at the
// cost of a dropped frame, exactly like every other raster wait in this
// codebase. See apply_band's caller for why the target is always kept
// clear of the ambiguous low-byte range (see MIN_Y's own comment).
//------------------------------------------------------------------
wait_raster_a:
    cmp VIC_RASTER
    bne wait_raster_a
    rts

//------------------------------------------------------------------
// apply_band - write hardware sprites 0-7 from ball_order[base..base+7],
// where base comes in A (0 for band 0, 8 for band 1).
//
// A hardware slot whose ball_order index would be >= active_balls has
// no real ball this frame (the LAST band, whenever active_balls is not
// a multiple of HW_SPRITES) - it is simply left out of band_enable, so
// VIC_SPRITE_ENABLE hides it outright rather than showing stale X/Y/
// pointer/color from whatever ball last occupied that hardware slot.
//
// X holds the ball's own identity (for the four ball_* table reads);
// Y holds band_slot, then band_slot*2 for the interleaved X/Y registers
// - two different index spaces, both needed at once, hence the split.
//------------------------------------------------------------------
apply_band:
    sta band_base
    lda #$00
    sta band_slot
    sta band_enable
    sta band_msb
ab_loop:
    lda band_slot
    clc
    adc band_base
    cmp active_balls
    bcs ab_next                  // no ball for this hw slot: leave it out
                                  // of band_enable/band_msb and skip it

    tax
    lda ball_order, x
    tax                          // X = the ball's own identity

    ldy band_slot
    lda hw_bit, y
    ora band_enable
    sta band_enable

    lda ball_ptr, x
    sta SPRITE_PTRS, y
    lda ball_color, x
    sta VIC_SPRITE_COLOR, y

    lda x_msb, x
    beq ab_no_msb
    lda hw_bit, y
    ora band_msb
    sta band_msb
ab_no_msb:
    tya
    asl
    tay                          // Y = band_slot * 2, for X/Y registers
    lda x_lo, x
    sta VIC_SPRITE_X, y
    lda y_pix, x
    sta VIC_SPRITE_Y, y

ab_next:
    inc band_slot
    lda band_slot
    cmp #HW_SPRITES
    bne ab_loop

    lda band_enable
    sta VIC_SPRITE_ENABLE
    lda band_msb
    sta VIC_SPRITE_X_MSB
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

    // 'B' changes the ball count - checked before the speed controls
    // and handled completely separately (own timer, own clamp, own
    // redraw), so holding B never also nudges the speed bar. SHIFT+B
    // lowers the count, matching the cursor keys' own shift-reverses
    // convention above; plain B raises it.
ui_check_b:
    lda #$f7                    // row 3: 'B' is bit 4
    sta CIA1_PORT_A
    lda CIA1_PORT_B
    and #$10
    beq ui_ball_change           // held (active low)
    lda #$00                     // released: next press acts at once
    sta ball_key_timer

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
// ui_ball_change - 'B' / SHIFT+B: raise or lower active_balls.
//
// A full mirror of ui_apply/ui_change above, just against active_balls
// instead of speed, with its own repeat timer (ball_key_timer) so
// holding one control never disturbs the other's repeat cadence.
//------------------------------------------------------------------
ui_ball_change:
    lda #$ff
    sta CIA1_PORT_A              // deselect rows, same as ui_apply
    lda ball_key_timer
    beq ui_ball_do
    dec ball_key_timer           // still holding: wait for the repeat
    rts
ui_ball_do:
    lda #KEY_REPEAT
    sta ball_key_timer

    lda key_shift
    bne ui_ball_dec               // shifted: fewer balls
    lda active_balls
    clc
    adc #$01
    jmp ui_ball_clamp
ui_ball_dec:
    lda active_balls
    sec
    sbc #$01
ui_ball_clamp:
    cmp #ACTIVE_BALLS_MIN
    bcc ui_ball_rts               // would go below the minimum
    cmp #ACTIVE_BALLS_MAX + 1
    bcs ui_ball_rts               // would go above the compiled ceiling
    sta active_balls
    jmp draw_ball_count           // tail call
ui_ball_rts:
    rts

//------------------------------------------------------------------
// draw_status - write the fixed status text on the bottom row
//------------------------------------------------------------------
draw_status:
    ldx #39
ds_loop:
    lda legend_text, x          // row 23: the key legend
    sta SCREEN_RAM + LEGEND_ROW, x
    lda #$0b                    // dark grey: it is reference, not state
    sta COLOR_RAM + LEGEND_ROW, x
    lda status_text, x          // row 24: the speed bar and the exit key
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
// draw_ball_count - two decimal digits, active_balls (04..16)
//
// Repeated subtraction rather than a divide: active_balls never exceeds
// MAX_BALLS (16), so this is at most one trip round dbc_tens.
//------------------------------------------------------------------
draw_ball_count:
    lda active_balls
    ldx #$30                    // '0' - screencode digits sit at the same
dbc_tens:                       // values as PETSCII/ASCII ones, $30-$39
    cmp #10
    bcc dbc_ones
    sec
    sbc #10
    inx
    jmp dbc_tens
dbc_ones:
    pha                          // stash the ones digit (0-9) a moment
    txa
    sta SCREEN_RAM + STATUS_ROW + BALL_COUNT_COL
    pla
    clc
    adc #$30
    sta SCREEN_RAM + STATUS_ROW + BALL_COUNT_COL + 1
    lda #$0c                     // grey, matching the rest of the row
    sta COLOR_RAM + STATUS_ROW + BALL_COUNT_COL
    sta COLOR_RAM + STATUS_ROW + BALL_COUNT_COL + 1
    rts

//------------------------------------------------------------------
// update_effects - once per frame: swap cooldown, impact sparks, twinkle
//
// Each live spark slot is redrawn every frame so its color can cool from
// white down through yellow and red. On the last frame the cell is put
// back the way it was found, so a star underneath a spark survives.
//------------------------------------------------------------------
update_effects:
    lda swap_cool
    beq ue_sparks
    dec swap_cool

    //---- Impact sparks: redraw, cool down, then erase ----
ue_sparks:
    ldx #SPARK_SLOTS - 1
ue_spark_loop:
    lda spark_timer, x
    beq ue_spark_next           // slot idle
    dec spark_timer, x
    lda spark_lo, x             // screen cell for this spark
    sta ptr
    lda spark_hi, x
    ora #>SCREEN_RAM
    sta ptr + 1
    ldy spark_timer, x
    beq ue_spark_erase
    lda spark_glyph, x          // still burning: glyph + this frame's shade
    sta temp
    lda spark_ramp, y
    sta temp2
    jmp ue_spark_put
ue_spark_erase:
    lda spark_char_save, x      // burnt out: restore what was underneath
    sta temp
    lda spark_color_save, x
    sta temp2
ue_spark_put:
    ldy #$00
    lda temp
    sta (ptr), y
    lda spark_hi, x             // same offset in color RAM
    ora #>COLOR_RAM
    sta ptr + 1
    lda temp2
    sta (ptr), y
ue_spark_next:
    dex
    bpl ue_spark_loop

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
// check_collisions - test candidate pairs and push touching ones apart
//
// Walks ball_order (sorted ascending by y_pix, freshly built by
// sort_balls this same frame - see there) from the top down. For outer
// position i, the inner position j counts down from i-1, comparing
// ball_order[i] against ball_order[j]. Since the list is Y-sorted,
// ball_order[i]'s y_pix is never less than ball_order[j]'s, so
// y_pix[i] - y_pix[j] is a valid unsigned distance that only GROWS as j
// decreases - the moment it reaches BALL_DIAM (the individual-axis
// touch limit check_pair itself applies to dy, see there), every
// smaller j is at least as far away, so the whole inner loop breaks
// rather than skipping just that one pair.
//
// This turns the pair scan from unconditional O(n^2) into roughly O(n)
// for balls that are actually scattered across the play field, which is
// what makes 16 balls affordable in the same per-frame budget 8 used to
// need - see the plan doc for the cycle math this is built to satisfy.
//
// check_pair itself is unchanged: still called with X = ball A's
// identity, Y = ball B's identity, exactly as when the loop visited
// indices directly. Only how the pair is FOUND changed, not what
// happens once one is.
//------------------------------------------------------------------
check_collisions:
    lda active_balls
    sec
    sbc #$01
    sta sort_i                  // reusing sort_balls' scratch - it has
cc_outer:                       // already done its job for this frame
    lda sort_i
    bmi cc_done

    tay
    lda ball_order, y
    sta pair_a                  // ball A's identity
    tax
    lda y_pix, x
    sta temp2                   // A's y_pix - the pruning reference

    lda sort_i
    sec
    sbc #$01
    sta sort_j
cc_inner:
    lda sort_j
    bmi cc_next_outer

    tay
    lda ball_order, y
    sta temp                    // ball B's identity
    tax
    lda temp2
    sec
    sbc y_pix, x                // A.y - B.y; never borrows, list is sorted
    cmp #BALL_DIAM
    bcs cc_next_outer           // too far apart in Y already - and every
                                 // ball below this one only more so

    ldx pair_a                  // X = ball A
    ldy temp                    // Y = ball B
    jsr check_pair

    dec sort_j
    jmp cc_inner
cc_next_outer:
    dec sort_i
    jmp cc_outer
cc_done:
    rts

//------------------------------------------------------------------
// check_pair - are balls X and Y touching? If so, separate them.
//
// Computes dx = A.x - B.x (16-bit, since X is 9 bits) and dy = A.y - B.y,
// remembers their signs in want_sx/want_sy (the direction A should move
// to get away from B), then applies the distance test from the header.
// On contact: push both balls apart, fire a ping, and (unless a swap
// happened recently) swap the two body colors and throw off a spark.
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

    jsr get_random              // hit pitch: $30 / $38 / $40 / $48
    and #$18
    clc
    adc #$30
    jsr trigger_ping

    //---- Impact effects: swap body colors and throw off a spark ----
    // Balls overlap for a few frames while separating; the cooldown
    // makes sure the swap happens once per contact, not every frame.
    lda swap_cool
    bne cp_done
    lda #SWAP_COOL
    sta swap_cool
    lda ball_color, x            // logical, per-ball color now, not the
    sta temp                      // hardware register directly - apply_band
    lda ball_color, y             // picks it up next time this ball's band
    sta ball_color, x             // comes round
    lda temp
    sta ball_color, y
    tya
    tax
    ldx save_x
    jsr spawn_spark             // ASCII spark at the point of contact
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
// spawn_spark - drop an ASCII spark on the text screen where two balls hit
//
// Called from check_pair with X = ball A and Y = ball B, and preserves
// both (the collision loop still needs them). The spark cell is the
// midpoint of the two ball centers, converted from sprite coordinates to
// a text cell: the ball's center sits 12 px right of and 10 px below the
// sprite position, the display starts at sprite X 24 / Y 50, so
//     column = (mx + 12 - 24) / 8 = (mx - 12) / 8
//     row    = (my + 10 - 50) / 8 = (my - 40) / 8
// Row is 1..22 for any legal ball position, so a spark can never land on
// the status row. The glyph is random; the cell's old character and color
// are saved so update_effects can put them back.
//------------------------------------------------------------------
spawn_spark:
    stx spark_ball_a
    sty spark_ball_b

    //---- mx = (A.x + B.x) / 2, then column = (mx - 12) / 8 ----
    ldy spark_ball_a
    lda x_lo, y
    ldy spark_ball_b
    clc
    adc x_lo, y
    sta temp
    ldy spark_ball_a
    lda x_msb, y
    ldy spark_ball_b
    adc x_msb, y
    sta temp2                   // 16-bit sum, at most $0284
    lsr temp2
    ror temp                    // >> 1: temp/temp2 = mx
    sec
    lda temp
    sbc #12
    sta temp
    lda temp2
    sbc #$00
    sta temp2
    lsr temp2
    ror temp                    // >> 3: temp = column 0..38
    lsr temp2
    ror temp
    lsr temp2
    ror temp

    //---- my = (A.y + B.y) / 2, then row = (my - 40) / 8 ----
    ldy spark_ball_a
    lda y_pix, y
    ldy spark_ball_b
    clc
    adc y_pix, y
    sta temp2
    lda #$00
    rol                         // carry (bit 8 of the sum) into A
    lsr                         // and back out into carry
    ror temp2                   // >> 1: temp2 = my
    lda temp2
    sec
    sbc #40
    lsr
    lsr
    lsr                         // row 1..22
    tay

    //---- cell offset = row * 40 + column, in temp (low) / temp2 (page) ----
    lda row_offset_lo, y
    clc
    adc temp
    sta temp
    lda row_offset_hi, y
    adc #$00
    sta temp2

    //---- If a spark is already burning on this cell, re-arm that slot.
    // Taking a second slot would save the first spark's glyph as the
    // "original" contents and leave it on screen for good.
    ldx #SPARK_SLOTS - 1
ss_match:
    lda spark_timer, x
    beq ss_match_next
    lda spark_lo, x
    cmp temp
    bne ss_match_next
    lda spark_hi, x
    cmp temp2
    beq ss_arm
ss_match_next:
    dex
    bpl ss_match

    ldx #SPARK_SLOTS - 1        // otherwise take a free slot, newest first
ss_find:
    lda spark_timer, x
    beq ss_found
    dex
    bpl ss_find
    jmp ss_exit                 // all four still burning: skip this one
ss_found:
    lda temp
    sta spark_lo, x
    lda temp2
    sta spark_hi, x             // page 0..3 of the screen

    lda spark_lo, x             // remember what was in the cell
    sta ptr
    lda spark_hi, x
    ora #>SCREEN_RAM
    sta ptr + 1
    ldy #$00
    lda (ptr), y
    sta spark_char_save, x
    lda spark_hi, x
    ora #>COLOR_RAM
    sta ptr + 1
    lda (ptr), y
    sta spark_color_save, x

ss_arm:
    jsr get_random              // random glyph (preserves X and Y)
    and #$03
    tay
    lda spark_chars, y
    sta spark_glyph, x
    lda #SPARK_LEN
    sta spark_timer, x          // update_effects draws it from here on
ss_exit:
    ldx spark_ball_a
    ldy spark_ball_b
    rts

//------------------------------------------------------------------
// Sound
//------------------------------------------------------------------

// init_sound - silence the SID, then configure voice 1 as a plucked ping:
// a triangle wave with an instant attack, a ~200 ms decay and no sustain,
// so every trigger is one short bell-like hit that dies on its own. The
// filter is bypassed; only the pitch changes from hit to hit.
init_sound:
    ldx #$18                    // zero all 25 SID registers
    lda #$00
clear_sid:
    sta SID_BASE, x
    dex
    bpl clear_sid
    sta ping_cool

    lda #$06                    // attack 0 (instant), decay 6 (~200 ms)
    sta SID_V1_AD
    lda #$00                    // sustain 0, release 0: the decay is the whole note
    sta SID_V1_SR
    sta SID_FILTER_RES          // no resonance, voice 1 not routed to the filter
    sta SID_V1_FREQ_LO          // pitch is set per hit via the high byte only
    lda #$0c                    // filter off, volume 12 of 15
    sta SID_VOLUME
    rts

// trigger_ping - hit A on voice 1, unless a ping is still cooling down.
// A = frequency high byte (higher = brighter ping). Uses only A and the
// scratch byte, so callers can keep X = ball A and Y = ball B.
trigger_ping:
    sta ping_pitch
    lda ping_cool
    bne tp_done                 // too soon after the last one
    lda ping_pitch
    sta SID_V1_FREQ_HI
    lda #$10                    // triangle, gate OFF: resets the envelope
    sta SID_V1_CONTROL
    lda #$11                    // triangle, gate ON: instant attack, then decay
    sta SID_V1_CONTROL
    lda #PING_COOL
    sta ping_cool
tp_done:
    rts

// update_sound - called once per frame. The ping's envelope runs in the
// SID itself (instant attack, short decay, no sustain), so the only thing
// left to do per frame is age the cooldown that spaces the hits out.
update_sound:
    lda ping_cool
    beq us_done
    dec ping_cool
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
sprite_colors:                  // body color per ball (bit pair 10),
    .byte $02, $0d, $07, $03    // MAX_BALLS entries. red, light green,
    .byte $04, $0a, $0e, $08    // yellow, cyan, purple, light red, light
    .byte $02, $0d, $07, $03    // blue, orange, then the same eight again -
    .byte $04, $0a, $0e, $08    // there are only eight colors the sphere
                                 // shading (sprite_gen.asm) was tuned to
                                 // read well in, so balls 8-15 repeat 0-7.
                                 // Multiplexing means two same-colored balls
                                 // can now be on screen in different bands
                                 // at once; that was already possible with
                                 // collisions' color-swap before this, so
                                 // nothing new relies on the 8 being unique.

hw_bit:                         // bit n = hardware sprite n, for building
    .byte $01, $02, $04, $08    // VIC_SPRITE_ENABLE and VIC_SPRITE_X_MSB
    .byte $10, $20, $40, $80    // one hw slot at a time in apply_band

spark_chars:                    // random spark glyph: * + filled/hollow circle
    .byte $2a, $2b, $51, $57

spark_ramp:                     // spark color by frames left (index 0 unused):
    .byte $00, $0b, $09, $02    // dgry, brown, red ...
    .byte $08, $08, $07, $07    // ... orange, yellow ...
    .byte $01, $01              // ... white at the moment of impact

// Screen offset of each text row, so spawn_spark can do row * 40 without
// a multiply. 25 rows, though only 1..22 can ever hold a spark.
row_offset_lo:  .fill 25, (i * 40) & $ff
row_offset_hi:  .fill 25, (i * 40) >> 8

// Impact spark slots: cell offset, saved contents, glyph, frames left
spark_lo:         .fill SPARK_SLOTS, 0
spark_hi:         .fill SPARK_SLOTS, 0
spark_char_save:  .fill SPARK_SLOTS, 0
spark_color_save: .fill SPARK_SLOTS, 0
spark_glyph:      .fill SPARK_SLOTS, 0
spark_timer:      .fill SPARK_SLOTS, 0
spark_ball_a:     .byte 0       // X and Y saved across spawn_spark
spark_ball_b:     .byte 0
ping_pitch:       .byte 0       // trigger_ping's argument

.encoding "screencode_upper"
legend_text:                    // 40 columns: what every key does
    .text "SPEED +/- CRSR B=BALLS R=RESTART Q=QUIT "

status_text:                    // 40 columns; the speed bar and the ball
    .text "SPD[                ] B:00 STOP=END     "   // count digits are
                                 // filled in by code - draw_speed_bar and
                                 // draw_ball_count respectively

twinkle_colors:                 // random star shades (mostly dim)
    .byte $0b, $0c, $0f, $01, $0c, $0b, $0e, $0c

// Star cell offsets into the screen (0..999), low and high bytes
star_lo:    .fill STAR_COUNT, 0
star_hi:    .fill STAR_COUNT, 0

//------------------------------------------------------------------
// Sprite graphics - 8 shaded ball frames at $2000,
// both generated at assembly time. Kept in their own file because they are
// pure data generation with no connection to the demo's logic or zero page.
//------------------------------------------------------------------
#import "sprite_gen.asm"

//------------------------------------------------------------------
// The intro tune (PSID, loads at its own $1000) and the intro's spiral
// bitmap (8000 bytes at $4000, in VIC bank 1). Both are data only.
//------------------------------------------------------------------
#import "music.asm"
#import "intro_gfx.asm"
#import "intro_sprites.asm"

//------------------------------------------------------------------
// The raster bar overture and the border bars over the closing wipe.
// Code, so it needs somewhere to live: it goes in the spare RAM above the
// intro's wipe field, inside VIC bank 1 but well clear of everything the
// VIC is pointed at there (bitmap $4000, matrix $6000, sprites $6400).
// The Main Code segment could not take it - it has 226 bytes left before
// the cell fields at $3000.
//------------------------------------------------------------------
#import "intro_raster.asm"
