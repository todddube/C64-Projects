//==================================================================
// SPRITEMOV - 4 to 16 Wandering Balls, Stars, Sparks and Ping SFX
// KickAssembler v5.25 / Commodore 64 (6502)
//
// Build:  java -jar /Applications/KickAssembler/KickAss.jar main.asm -odir bin
// Run:    /Applications/vice-arm64-gtk3/bin/x64sc -ntsc -autostart bin/main.prg
//
// Target: NTSC first (US machines: 263 lines x 65 cycles = 17095 cycles a
// frame, 60 Hz), PAL second. detect_video picks the standard at start-up;
// the tune is kept at its PAL tempo on NTSC (music_tick) and the overture
// gives up a few band lines to fit NTSC's shorter vertical blank.
//
// Files:  main.asm          the demo itself (this file)
//         sprite_gen.asm    assembly-time ball graphics
//         intro.asm         the opening sequence
//         intro_sprites.asm the intro's label sprites and the sine table
//         intro_text.asm    glyph rows lifted from the character ROM
//         intro_raster.asm  the raster bar overture
//         music.asm         PSID import of Nightshift.sid
//         All of them are #imported below; none assembles on its own.
//==================================================================
//
// WHAT THIS PROGRAM DOES
// ----------------------
// Shaded multicolor balls - 8 to start, 4 to 16 with B / SHIFT+B - drift
// around a black, starry screen with smooth, organic, random motion. Past
// eight they are multiplexed: a raster IRQ re-uses each of the VIC's eight
// hardware sprites for a second ball further down the screen (mux_irq).
// Each ball spins as it moves, faster when it moves faster and reversing
// when it turns. A short bell-like ping plays on the SID whenever a ball
// bounces off an edge or off another ball - low for a wall, higher and
// randomly pitched for a ball-to-ball hit. A ball-to-ball hit also throws
// an ASCII spark onto the text screen at the point of contact and makes
// the two balls swap colors.
//
// The vertical border is held open (see mux_irq), so the balls use the
// whole visible picture from top to bottom rather than just the 25-row
// text window: they fly over the status row and on down into what would
// be the bottom border.
//
// The demo opens on a raster bar overture: eight colour bars flying over
// a black text screen through five movement modes - a travelling wave,
// crossing scissors, a nested fan, eight independent tempos, and an
// implosion into a single line - while the handle and six labels fade up
// one at a time between them. See intro_raster.asm.
//
// The intro then fades a title card - name, date and version, as sprite
// labels - up out of black and holds it there, with nothing behind it.
// Vertical raster bars fade in and sweep sideways across the screen while
// the labels lift off and float on damped springs toward random targets,
// all to a SID tune (Nightshift by Ari Yliaho). The labels glide home and
// everything fades to black into the demo. See intro.asm.
//
// The bottom two text rows are a menu: a legend of the keys on row 23 and
// the speed bar and ball count on row 24. The cursor keys or + / - change
// the speed, B / SHIFT+B the number of balls, R restarts from the top of
// the intro, and Q or RUN/STOP end the demo and hand the machine back with
// a clean READY. prompt.
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
//        detect_video       (once) NTSC or PAL
//        play_intro         (once) raster overture, labels + bars + music,
//                           then the reveal
//        init_mux           (once) hand the sprites to the raster IRQ
//        check_exit         RUN/STOP / Q -> silence hardware, reset; R
//        update_input       keyboard -> speed level, ball count, status bar
//        rescale_some       catch the velocity cache up after a speed change
//        update_sprites     integrate, edge bounce, spin frame (+ easing)
//        sort_balls         ball_order ascending by Y
//        check_collisions   Y-pruned pair sweep, half per frame, push apart
//        build_list         the multiplexer's write list from this frame
//        update_effects     impact sparks, star twinkle, cooldowns
//        update_sound       age the ping cooldown
//      mux_irq              raster IRQ chain: band 0 + sprite re-use +
//                           the open border
//   6. Helper routines                 reverse_x/y, new_heading, random_speed,
//                                      init_stars, draw_status,
//                                      spawn_spark,
//                                      draw_speed_bar, push_ball, sound, RNG
//   7. Data tables                     colors, status text, spark slots,
//                                      star positions, row offsets
//   8. #import "sprite_gen.asm"        8 shaded ball frames
//      #import "intro.asm"            the opening sequence (its own header)
//      #import "music.asm"            PSID import of the intro tune
//      #import "intro_sprites.asm"    the label sprites + sine table
//      #import "intro_raster.asm"     the raster bar overture + fade-out bars
//        (intro_sprites.asm pulls in intro_text.asm - glyph rows,
//        assembly time only)
//
// MEMORY LAYOUT
// -------------
//   $0002-$0014  zero page: the intro's variables, ntsc, music_div,
//                beat_hold
//   $007a-$00ad  zero page: the demo's globals and the IRQ's state
//   $00f8-$00f9  zero page: Nightshift's player (traced: nothing else)
//   $0314-$0315  IRQ vector -> mux_irq during the demo
//   $0318-$0319  NMI vector -> nmi_ignore (RESTORE does nothing)
//   $0400-$07e7  text screen: stars, status rows 23-24 (the sprite
//                pointers live at $07f8-$07ff inside the same 1K block)
//   $0801        BASIC stub "10 SYS 8768"  (8768 = $2240)
//   $0900-$0a0b  raster bar line buffer: one colour per raster line
//   $0c00-$0dff  intro label sprites (8 x 64 bytes, VIC blocks $30-$37)
//   $1000-$1d77  Nightshift.sid - player and music data, at its own load
//                address (invisible to the VIC, which sees char ROM here)
//   $2000-$21ff  8 ball frames, 64 bytes each  (VIC blocks $80-$87)
//   $2240-$3fff  code and data tables (Main Code; ends ~$3580)
//   $3fff        VIC idle fetch - what the VIC displays in the opened
//                border, zeroed at start-up (see VIC_IDLE_FETCH)
//   $6600-$66ff  intro sine table   (CPU only)
//   $6b00-$73ff  intro_raster.asm's code and data (CPU only; ends ~$7190)
//   $8400-$857f  BALL_STATE: 24 per-ball tables x 16
//   $8600-$873f  the multiplexer's double-buffered write list
//
// SPRITE ROLES
// ------------
//   sprites 0-7  the balls   (multicolor, 8 animation frames each)
// All eight of the VIC's sprites are balls. With up to 8 balls each has
// its own sprite; past 8, sprite k shows the k-th highest ball (band 0)
// and is then re-used, mid-frame, for the (k+8)-th (see build_list).
// Lower-numbered sprites are drawn on top.
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
// The stored velocities are "base" velocities. Each is scaled by a global
// speed level into an "effective" velocity, which is what integration and
// spin use:
//
//       effective = base * speed / 8          (speed = 1..16)
//
// so level 8 is the base speed, the default of 4 is half speed, and 16 is
// double. The multiply is a 16x5-bit shift-and-add on the magnitude, then
// the sign is restored (see ScaleVel). The effective velocity is CACHED
// per ball (evx/evy): it is recomputed only while a ball eases up to
// speed, and a few balls a frame after the level changes - a bounce just
// negates it along with the base velocity. Recomputing it every frame was
// ~600 cycles a ball, more than 16 balls can afford in an NTSC frame.
//
// Keys (CIA1 matrix scanned directly, no kernal):
//     CRSR up, CRSR right, +    faster
//     CRSR down, CRSR left, -   slower
//     B / SHIFT+B               one ball more / fewer (4..16)
//     R                         restart from the top of the intro
//     Q, RUN/STOP               end the demo (resets the machine)
// Holding a speed or ball key auto-repeats every KEY_REPEAT frames. A
// joystick in port 1 shares the matrix's column lines, so while it is
// pushed the keyboard is ignored (RUN/STOP and Q still work).
// The bottom TWO text rows are the menu: row 23 is a fixed legend of the
// keys, row 24 carries the speed bar and ball count, redrawn on change.
//
// EDGE HANDLING
// -------------
// The vertical border is held open (see mux_irq), so the playfield is
// the whole visible picture from top to bottom rather than the 25-row
// text window. Hard bounce limits are X 22..322 and Y 56..250: the balls
// fly over and below the status row, down into what would be the bottom
// border. When a ball reaches an edge its position is clamped and the
// velocity (and target) on that axis is reversed. The other axis is left
// alone, so a ball hitting the right wall while moving down keeps moving
// down - a clean reflection.
//
// Y 56 is a hardware floor on PAL, not a style choice. A sprite is
// triggered when the low 8 bits of the raster match its Y, and PAL lines
// 256..311 repeat the low bytes 0..55 - lines that are visible once the
// bottom border is open. (NTSC only repeats 0..6 on lines 256..262, so it
// could go higher; one limit for both keeps the two standards identical.) A ball at Y < 56 is therefore drawn a second time as a ghost near
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
// After every physics step, pairs of balls are tested in software
// (the VIC's $d01e collision register only says *that* a sprite touched
// something, not which one, and only for non-transparent pixels). Two
// balls touch when the distance between their centers is under the
// 20 px ball diameter, approximated as
//       |dx| < 20  and  |dy| < 20  and  |dx| + |dy| < 30
// (a box with the corners cut off - close enough to a circle). Only
// pairs within 20 px in Y are tested at all (the Y-sorted ball_order makes
// that a short walk), and only half of them each frame - see
// check_collisions.
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
//   * Intro reveal  - the opening runs in the demo's own text screen,
//                     filled with solid blocks for the vertical bars; the
//                     handoff clears it back to spaces with DEN off, and
//                     the balls are simply there when it comes on. See
//                     intro.asm for the animation itself.
//   * Color swap    - colliding balls exchange body colors. A short
//                     cooldown stops the swap bouncing back and forth
//                     while the balls separate.
//
// FRAME TIMING
// ------------
// The intro is polled, with interrupts off. The demo is not: once init_mux
// runs, every sprite write and the open-border trick happen in a raster
// IRQ chain (mux_irq) - line 16 for band 0 and RSEL back on, one IRQ per
// re-used sprite, line 248 for RSEL off - and the main loop only computes.
// It builds a write list from one sorted snapshot, the top IRQ swaps it
// in, and the main loop waits for that swap before starting the next
// frame. A main loop that runs long just means the IRQ shows the previous
// list again: a repeated frame, never a torn one.
//
// Measured on NTSC (VICE x64sc -ntsc, 600 frames each, balls at speed):
//     8 balls   ~5000 cycles a frame average,  ~6100 worst
//    12 balls   ~8400 average, ~10600 worst
//    16 balls  ~12600 average, ~14400 worst  - of 17095; no late frames
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
.label VIC_IRQ_STATUS       = $d019 // write 1s to acknowledge
.label VIC_IRQ_ENABLE       = $d01a // bit 0 = raster IRQ

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
.label CIA1_TIMER_A_LO      = $dc04     // timer A, low byte (free-running)
.label CIA1_ICR             = $dc0d     // timer/IRQ mask and latch
.label CIA1_TIMER_A_HI      = $dc05     // free-running timer, used for the
                                        // RNG seed: it keeps counting with
                                        // interrupts off, unlike the jiffy
                                        // clock at $a2
.label CIA2_PORT_A          = $dd00      // bits 0-1 = VIC bank select
.label CIA2_DDR_A           = $dd02      // bits 0-1 must be outputs
.label CIA2_ICR             = $dd0d      // NMI mask/latch
.label IRQ_VECTOR           = $0314      // kernal IRQ vector: $ff48 saves
                                         // A/X/Y then jmp ($0314)
.label KERNAL_IRQ_EXIT      = $ea81      // pla/tay/pla/tax/pla/rti
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
// Only single-byte globals live here now - the per-ball tables moved out
// to BALL_STATE (absolute RAM) when the ball count went past 8: 24 tables
// of 16 balls will not fit in zero page. Zero page is still used for the
// globals because they are read constantly and (ptr),y has no absolute
// form at all.
//
// $02..$8f belong to BASIC normally, but we never return to BASIC and
// the kernal's IRQ handler never runs (sei through the intro, our own
// IRQ in the demo), so they are ours.
//
//   $02-$14  the intro's variables, plus ntsc / music_div / beat_hold
//   $7a-$ad  the demo's globals, sort/collision scratch, the IRQ's state
//   BALL_STATE (absolute, not zero page)  24 per-ball tables, see below
//
// THE INTRO'S OWN VARIABLES OVERLAP temp/temp2. play_intro runs to
// completion before start touches a single ball byte, so the two are
// never live at the same time. Nightshift's player uses only $f8/$f9 -
// traced from its init and play entries - so it collides with neither.
// If the tune is ever swapped for another, re-check that first.
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
.label rescale_n    = $8f       // balls still to rescale after a speed
                                // change (counts down, a few per frame)
                                // $90-$92 free (were the evx/evy scratch,
                                // now per-ball tables in BALL_STATE)
.label key_shift    = $93       // nonzero if either shift key is down
.label key_delta    = $94       // +1 / -1 speed change requested, 0 = none
.label active_balls = $95       // how many of MAX_BALLS are in play, 4..16

// Sort and collision scratch. See BALL_STATE below for ball_order
// itself (a per-ball ARRAY, so it lives there, not here).
.label sort_i        = $96      // insertion sort: outer index i
.label sort_j         = $97      // insertion sort: inner (shifting) index j
                                 // $98-$9c free (the polled bands' scratch)
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
.label pair_ay        = $9f       // check_collisions: ball A's y_pix, the
                                   // inner loop's pruning reference. Its
                                   // own byte because check_pair and
                                   // spawn_spark both use temp2 as scratch

// Raster IRQ multiplexer state (see mux_irq). The IRQ owns these; the
// main loop only ever touches dl_ready (and reads dl_front).
.label dl_front       = $a0       // write list the IRQ is showing: 0 / 16
.label dl_ready       = $a1       // main loop -> IRQ: the back list is
                                   // complete, swap at the next top IRQ
.label irq_e          = $a2       // next write-list entry to apply
.label irq_end        = $a3       // one past the last entry this frame
.label irq_bottom     = $a4       // 0 until the line-248 border write
.label irq_phase      = $a5       // 0 = next IRQ is the top one
.label bld_slot       = $a6       // build_list: scratch
.label bld_e          = $a7       // build_list: next entry index
.label bld_en         = $a8       // build_list: band 0's $d015
.label bld_msb        = $a9       // build_list: band 0's $d010
.label irq_line       = $aa       // mux_irq: the compare line just set
.label bld_line       = $ab       // build_list: re-use entry's line
.label bld_hw         = $ac       // build_list: re-use entry's sprite
.label bld_msbbit     = $ad       // build_list: re-use entry's $d010 bit

//------------------------------------------------------------------
// BALL_STATE - the per-ball tables, OUT of zero page.
//
// The VIC has 8 hardware sprites; this demo multiplexes MAX_BALLS
// logical balls across them with a raster IRQ (see mux_irq). Zero
// page has no room for that: 18 tables x 16 balls is 288 bytes, more
// than all of $02-$FF. So they live in ordinary RAM at $8400, well
// clear of everything the intro assembles in. The CPU sees RAM there whatever VIC bank is
// selected - bank switching only changes what the VIC CHIP fetches.
//
// They used to sit on top of the intro's old cell fields, on the theory
// that the intro is finished before the first ball byte is written.
// That is only true once: R replays the intro, whose data is assembled
// in and never regenerated.
//
// Moving off zero page costs nothing per access: `lda table,x` is 4
// cycles whether table is zero page or absolute (only zero-page,X is
// special-cased by the 6502, and only for the NON-indexed forms this
// file never uses) - one extra opcode byte, no extra cycles. The tables
// are 16 bytes each from a page boundary, so no index crosses a page
// and none pays the page-crossing cycle. `ptr`
// above is the one table that could not move: (ptr),y has no absolute
// form on the 6502.
//
// Every table is MAX_BALLS bytes, computed as an offset so raising
// MAX_BALLS later (e.g. to try 24 balls in 3 bands) is a single-constant
// change, not a relayout.
//------------------------------------------------------------------
.label MAX_BALLS    = 16        // compiled ceiling; active_balls <= this
.label BALL_STATE   = $8400     // clear of all assembled-in data:
                                 // free RAM (no cartridge, BASIC ROM is
                                 // not until $a000). NOT on top of the
                                 // wave fields - they are assembled-in
                                 // data, and R restarts the intro, which
                                 // reads them again. Ball tables written
                                 // over wave A garbled the top 7 rows of
                                 // every intro after the first.

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
                                                     // copied into the write
                                                     // list by build_list
.label ball_color   = BALL_STATE + 16 * MAX_BALLS  // this ball's body color,
                                                     // same story
.label ball_order   = BALL_STATE + 17 * MAX_BALLS  // ball indices, sorted
                                                     // ascending by y_pix each
                                                     // frame - see sort_balls
.label evx_lo       = BALL_STATE + 18 * MAX_BALLS  // X velocity scaled by the
.label evx_hi       = BALL_STATE + 19 * MAX_BALLS  // speed level, 8.8: what
.label evy_lo       = BALL_STATE + 20 * MAX_BALLS  // the ball actually moves
.label evy_hi       = BALL_STATE + 21 * MAX_BALLS  // per frame. Cached - see
                                                     // scale_ball
.label ease_left    = BALL_STATE + 22 * MAX_BALLS  // frames of easing left
.label slot_free    = BALL_STATE + 23 * MAX_BALLS  // build_list: first line
                                                     // each hardware sprite is
                                                     // free again (8 used)
.label BALL_TABLES  = 24

// The multiplexer's write list, double buffered: the main loop fills the
// back half while the IRQ shows the front half (dl_front = 0 or 16 picks
// which). Entry 0-7 is band 0 - hardware sprite k = entry k, written all
// at once by the top IRQ. Entries 8.. are re-uses, one per extra ball:
// hardware sprite w_slot gets this ball once the raster reaches w_line.
.label WRITE_LIST   = $8600
.label w_x          = WRITE_LIST + 0 * $20   // X low 8 bits
.label w_y          = WRITE_LIST + 1 * $20
.label w_ptr        = WRITE_LIST + 2 * $20
.label w_col        = WRITE_LIST + 3 * $20
.label w_msb        = WRITE_LIST + 4 * $20   // hw_bit[slot] if X >= 256
.label w_slot       = WRITE_LIST + 5 * $20   // entries 8..: hardware sprite
.label w_line       = WRITE_LIST + 6 * $20   // entries 8..: raster line
.label w_end        = WRITE_LIST + 7 * $20   // [0]/[16]: entry count
.label w_en         = WRITE_LIST + 8 * $20   // [0]/[16]: band 0's $d015
.label w_msb0       = WRITE_LIST + 9 * $20   // [0]/[16]: band 0's $d010

// The intro's own variables (zero page; they share temp/temp2 with the demo).
.label bar_i        = $02       // bars_build: the bar being drawn
.label fade_rate    = $03       // frames between fade steps
.label spr_lvl      = $04       // label sprites' brightness, 0 black .. 7 full
.label flow_t       = $05       // free-running frame count: hue + ripple
.label bk_lvl       = $06       // the bars' brightness, 0 black .. 7 full
.label flow_t3      = $07       // ripple phase along each label
.label spr_msb      = $08       // X bit 8 bits gathered for $d010
.label bar_x        = $09       // bars_build: its left column, signed
.label bar_n        = $0a       // bars_build: columns left to draw
.label intro_t      = $0c       // ticks left in the current phase
.label bk_goal      = $0d       // the level bk_lvl is fading toward
.label spr_goal     = $0e       // the level spr_lvl is fading toward
.label fade_tick    = $0f       // countdown to the next fade step
.label rnd          = $10       // the wander's 8-bit LFSR, never 0
.label ripple_sh    = $11       // ripple shift: 8 = flat, 6 = full wave

// Shared by the intro and the demo, set by detect_video in start.
.label ntsc         = $12       // nonzero on an NTSC VIC (263 lines)
.label music_div    = $13       // music_tick's 6-frame counter
.label beat_hold    = $14       // nonzero on a frame music_tick skipped

//------------------------------------------------------------------
// Constants
//------------------------------------------------------------------
.label HW_SPRITES   = 8       // all eight the VIC has - fixed, always this
.label ACTIVE_BALLS_MIN     = 4
.label ACTIVE_BALLS_DEFAULT = 8       // the original ball count
.label ACTIVE_BALLS_MAX     = MAX_BALLS

// $d011 bit patterns. RSEL (bit 3) picks 25 rows or 24; mux_irq
// flips it every frame to hold the vertical border open (see mux_irq).
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
.label TOP_LINE     = 16        // mux_irq's top IRQ: band 0 + RSEL on.
                                 // After every bottom-border ball has
                                 // been drawn on NTSC and PAL alike, and
                                 // long before MIN_Y - see mux_irq
.label BOTTOM_LINE  = 248       // mux_irq's border write: RSEL off in the
                                 // 248-250 window
.label SLOT_HOLD    = 23        // lines a sprite stays busy after its Y:
                                 // 21 drawn + 1 start delay + 1 margin
.label RE_MARGIN    = 3         // lines the IRQ needs between a sprite
                                 // coming free and its next ball's Y
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

.errorif BALL_STATE + BALL_TABLES * MAX_BALLS > WRITE_LIST, "BALL_STATE runs into WRITE_LIST"

// Opening sequence. After the overture everything runs in text mode
// out of VIC bank 0, so the label sprites have to live in bank 0 too:
// $0c00-$0dff is free RAM the VIC can see (the character ROM shadow is
// only $1000-$1fff) and clear of RB_BUF ($0900-$0a0b) below it.
.label INTRO_SPR    = $0c00     // 8 x 64 bytes, the intro labels (bank 0)
.label INTRO_SPR_PTR = INTRO_SPR / $40   // = $30, the VIC block number
.label INTRO_SIN    = $6600     // 256-entry sine, one period (intro_sprites)
.label INTRO_Z_LEN  = 30        // black after the overture    (~0.6 s PAL)
.label INTRO_T_LEN  = 180       // the title fades in and holds (~3.6 s)
.label INTRO_F_LEN  = 200       // the bars sweep and the labels float,
                                // run twice: intro_t is one byte (~8 s)
.label INTRO_R_LEN  = 160       // the labels glide home       (~3.2 s)
.label INTRO_O_LEN  = 48        // everything fades to black   (~1.0 s)

// The labels' home: the title card's resting place, in sprite
// coordinates, centred on the screen. The name block is 4 X-expanded
// sprites (192 x 16), the date block 4 plain ones (96 px wide) with
// "v1.0" packed under the date in the same sprites (see intro_sprites):
// 44 lines top to bottom, centred on line 150.
.label NAME_HOME_X  = 24 + (320 - 192) / 2     // = 88
.label NAME_HOME_Y  = 128
.label DATE_HOME_X  = 24 + (320 - 96) / 2      // = 136
.label DATE_HOME_Y  = 152

// Where the wander may send them. Each label's own box - the name in the
// top half, the date in the bottom - so they never cross. The spring
// overshoots by a few percent at most, so every box keeps clear of the
// visible edge (X 24..343, Y 50..249).
.label NAME_MIN_X   = 32        // .. NAME_MIN_X + NAME_RNG_X = 144
.label NAME_RNG_X   = 112
.label NAME_MIN_Y   = 60        // .. 124, bottom row 140
.label NAME_RNG_Y   = 64
.label DATE_MIN_X   = 32        // .. 240, right edge 336
.label DATE_RNG_X   = 208
.label DATE_MIN_Y   = 156       // .. 220, "v1.0" ends at 240
.label DATE_RNG_Y   = 64

// Speed control
.label SPEED_MIN    = 1
.label SPEED_MAX    = 16
.label SPEED_DEFAULT = 4        // half of base speed
.label KEY_REPEAT   = 6         // frames between repeats while a key is held
.label EASE_FRAMES  = 64        // frames a new ball eases up to its heading:
                                // the gap closes by 1/16 a frame, so ~46
                                // frames take the largest one under 1/16 px
.label RESCALE_PER_FRAME = 4    // balls rescale_some redoes per frame
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

// ScaleVel - out = vel * speed / 8, signed 16-bit. X must hold the ball
// index; out is a per-ball table pair, indexed by X like vel. Uses Y,
// temp, m0..m2, p0..p2, vsign.
//
// It scales the MAGNITUDE and puts the sign back afterwards, so
// ScaleVel(-v) is exactly -ScaleVel(v). That is what lets the result be
// cached: a bounce that negates v negates the cached value too, instead
// of paying ~300 cycles to recompute it (see scale_ball).
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
    sta outlo, x
    lda #$00
    sbc p0 + 1
    sta outhi, x
    jmp done
store:
    lda p0
    sta outlo, x
    lda p0 + 1
    sta outhi, x
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

    jsr detect_video            // NTSC or PAL: tune tempo, overture band

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
    jsr play_intro              // overture + labels and bars, ends in text mode
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
    ldx #SPARK_SLOTS - 1        // no sparks: after R, slots still burning
!:  sta spark_timer, x          // from the last run would "restore" old
    dex                         // cells onto the fresh screen
    bpl !-
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

    lda #$00
    sta VIC_SPRITE_ENABLE       // the top IRQ turns on the ones in use
    sta rescale_n               // at rest: the cache is already right
    lda #CTRL1_25ROWS           // DEN on: text mode, stars and status appear
    sta VIC_CONTROL1
    jsr init_mux                // sprites -> raster IRQ; ends with cli

//------------------------------------------------------------------
// Main Loop - one physics step per displayed frame (60 Hz NTSC, 50 PAL)
//
// The main loop never touches a sprite register. It steps the physics,
// sorts the balls by Y, resolves collisions and then build_list turns
// that ONE consistent snapshot into a write list for the multiplexer
// IRQ (mux_irq), which does every sprite write at the raster line it
// has to happen on. The list is double buffered: the main loop fills
// the back half while the IRQ shows the front half, and the top IRQ
// swaps them only once dl_ready says a list is complete.
//
// So the loop's cost no longer has to fit between two raster lines - it
// only has to fit a frame, and if it ever does not, the IRQ simply shows
// the last complete list again (a repeated frame, never a torn one).
//
// Sync: dl_ready goes 1 when build_list finishes and back to 0 when the
// top IRQ takes the list, so "wait for dl_ready == 0" is "wait until the
// list just built is on its way to the screen" - once per frame.
//------------------------------------------------------------------
main_loop:
ml_wait:
    lda dl_ready
    bne ml_wait

    jsr check_exit              // RUN/STOP / Q quit, R restarts
    jsr update_input            // keyboard: speed level, ball count
    jsr rescale_some            // catch up after a speed change
    jsr update_sprites          // physics, edges, animation frame
    jsr sort_balls              // ball_order ascending by Y
    jsr check_collisions        // ball-to-ball contact, push apart
    jsr build_list              // snapshot -> back write list, dl_ready=1
    jsr update_effects          // impact sparks, twinkling stars
    jsr update_sound            // age the ping cooldown
    inc frame_count
    jmp main_loop

//------------------------------------------------------------------
// init_mux - first write list, then hand the sprites to the raster IRQ.
// Called from start with interrupts still disabled; ends with cli.
//------------------------------------------------------------------
init_mux:
    lda #$00
    sta dl_front                // IRQ shows half 0 (empty: $d015 = 0)
    sta dl_ready
    sta irq_phase               // first IRQ is the top one
    sta w_en                    // half 0 shows nothing until the swap
    sta w_msb0
    lda #HW_SPRITES
    sta w_end                   // and has no re-use entries
    jsr sort_balls
    jsr build_list              // half 16, dl_ready = 1

    lda #<mux_irq
    sta IRQ_VECTOR
    lda #>mux_irq
    sta IRQ_VECTOR + 1
    lda #TOP_LINE
    sta VIC_RASTER              // compare line, bit 8 = $d011 bit 7 = 0
    lda #CTRL1_25ROWS
    sta VIC_CONTROL1
    lda #$01
    sta VIC_IRQ_ENABLE          // raster IRQ only (CIA 1 is masked)
    sta VIC_IRQ_STATUS          // drop anything already latched
    cli
    rts

//------------------------------------------------------------------
// mux_irq - the sprite multiplexer and the open border, on a raster IRQ
// chain. Entered through the kernal ($ff48 has saved A/X/Y), left through
// $ea81, which restores them.
//
// TOP (irq_phase 0, line TOP_LINE = 16): back to 25 rows, swap in a fresh
// write list if one is ready, write band 0 - hardware sprites 0-7 - in
// one go, then schedule the chain. Line 16 is the earliest line that is
// safe on BOTH standards: a ball as low as MAX_Y = 250 is drawn on lines
// 251-271, which on NTSC (263 lines) runs on to line 8 of the next frame
// and on PAL (312) ends at 271. And it is well above MIN_Y = 56, the
// highest a band 0 ball can start. Writing band 0 at line 252, as the
// polled version did, rewrote sprites that were still being drawn in
// the open bottom border.
//
// CHAIN (irq_phase 1): two kinds of event, in raster order -
//   - re-use entries: hardware sprite w_slot takes the ball in that
//     entry once the raster reaches w_line, the first line after the
//     sprite's previous ball has finished (build_list works that out);
//   - BOTTOM_LINE (248): RSEL off, which holds the vertical border open.
//     The VIC sets its border flip-flop on line 247 with RSEL=0 or line
//     251 with RSEL=1; switching to RSEL=0 in 248-250 means the line it
//     now waits for is already past, so no bottom border this frame and
//     no top border next frame. The top IRQ switches RSEL back on.
// The handler applies everything that is due, then sets the compare line
// for the next event. If that line has already gone by (several entries
// due together), it loops instead of returning: a compare line that is
// already past would not fire until the next frame and stall the chain.
//------------------------------------------------------------------
mux_irq:
    lda #$01
    sta VIC_IRQ_STATUS          // acknowledge the raster IRQ
    lda irq_phase
    beq mi_top
    jmp mi_loop

mi_top:
    lda #CTRL1_25ROWS           // 25 rows again, ready for next line 248
    sta VIC_CONTROL1
    lda dl_ready
    beq mi_keep                 // main loop late: show the old list again
    lda dl_front
    eor #$10
    sta dl_front
    lda #$00
    sta dl_ready                // -> main loop may build the next one
mi_keep:
    ldx dl_front
    .for (var k = 0; k < 8; k++) {
        lda w_x + k, x
        sta VIC_SPRITE_X + k * 2
        lda w_y + k, x
        sta VIC_SPRITE_Y + k * 2
        lda w_ptr + k, x
        sta SPRITE_PTRS + k
        lda w_col + k, x
        sta VIC_SPRITE_COLOR + k
    }
    lda w_en, x
    sta VIC_SPRITE_ENABLE
    lda w_msb0, x
    sta VIC_SPRITE_X_MSB
    txa
    clc
    adc #HW_SPRITES
    sta irq_e                   // first re-use entry
    lda w_end, x
    sta irq_end
    lda #$00
    sta irq_bottom
    lda #$01
    sta irq_phase
    jmp mi_schedule

mi_loop:
    lda irq_bottom
    bne mi_entries
    lda VIC_RASTER
    cmp #BOTTOM_LINE
    bcc mi_entries
    lda #CTRL1_24ROWS           // open the border - first, it has a window
    sta VIC_CONTROL1            // of three lines and entries can wait
    inc irq_bottom
mi_entries:
    ldx irq_e
    cpx irq_end
    bcs mi_schedule             // no entries left
    lda irq_bottom
    bne mi_apply                // past the bottom: anything left is overdue
    lda VIC_RASTER
    cmp w_line, x
    bcc mi_schedule             // not due yet
mi_apply:
    ldy w_slot, x
    lda w_ptr, x
    sta SPRITE_PTRS, y
    lda w_col, x
    sta VIC_SPRITE_COLOR, y
    lda VIC_SPRITE_X_MSB        // this sprite's bit only - the other seven
    and msb_clear, y            // are still showing their own balls
    ora w_msb, x
    sta VIC_SPRITE_X_MSB
    tya
    asl
    tay
    lda w_x, x
    sta VIC_SPRITE_X, y
    lda w_y, x                  // Y last: it is what arms the sprite
    sta VIC_SPRITE_Y, y
    inc irq_e
    jmp mi_loop

mi_schedule:
    ldx irq_e
    cpx irq_end
    bcs mi_no_entry
    lda w_line, x               // next entry's line...
    ldy irq_bottom
    bne mi_set
    cmp #BOTTOM_LINE            // ...unless the border write comes first
    bcc mi_set
    lda #BOTTOM_LINE
    bne mi_set
mi_no_entry:
    lda irq_bottom
    bne mi_to_top
    lda #BOTTOM_LINE
mi_set:
    sta VIC_RASTER
    sta irq_line
    lda VIC_RASTER
    cmp irq_line
    bcs mi_loop                 // already there or past: do it now
    jmp KERNAL_IRQ_EXIT
mi_to_top:
    lda #$00
    sta irq_phase
    lda #TOP_LINE
    sta VIC_RASTER
    lda #$01                    // writing $d012 with the line the raster is
    sta VIC_IRQ_STATUS          // ON latches an IRQ at once: a mi_set that
    jmp KERNAL_IRQ_EXIT         // hit 248 exactly would otherwise run mi_top
                                // on line ~249. Nothing but line 16 is due.

//------------------------------------------------------------------
// build_list - turn this frame's sorted balls into the back write list.
//
// Band 0 is ball_order[0..7], the eight highest balls, on hardware
// sprites 0-7. Ball ball_order[i] for i >= 8 re-uses hardware sprite
// i & 7, i.e. the sprite of the ball eight places above it in Y order -
// the sprite that comes free earliest, so round robin is as good as a
// search while nothing is skipped, and far cheaper. slot_free[k] is the
// first raster line after sprite k's current ball has been drawn (its
// Y + 21 lines, + 2 for the VIC's one-line start delay and a line of
// margin). The re-use is only possible if that line is at least
// RE_MARGIN lines above the new ball's own Y, so the IRQ has time to
// write the sprite before the raster gets there; if not, the ball is
// left out of this frame (it still moves and collides - it just is not
// drawn) and the sprite stays with its old ball. Because the list is
// sorted by Y, the entries' w_line come out ascending, which is the
// order the IRQ chain walks them in.
//
// Uses A/X/Y, temp (the back half's base), bld_*.
//------------------------------------------------------------------
build_list:
    lda dl_front
    eor #$10
    sta temp                    // back half: 0 or 16
    lda #$00
    sta bld_en
    sta bld_msb
    sta bld_slot                // band 0: slot = ball_order index

bl_band0:
    lda bld_slot
    cmp active_balls
    bcs bl_band0_done
    cmp #HW_SPRITES
    bcs bl_band0_done
    tay
    ldx ball_order, y           // X = ball identity
    lda hw_bit, y
    ora bld_en
    sta bld_en
    lda x_msb, x
    beq bl_b0_lo
    lda hw_bit, y
    ora bld_msb
    sta bld_msb
bl_b0_lo:
    lda y_pix, x
    clc
    adc #SLOT_HOLD              // first line this sprite is free again
    bcc !+
    lda #$ff                    // runs past 255: not re-usable this frame
!:  sta slot_free, y
    tya
    clc
    adc temp
    tay                         // Y = write list index
    lda x_lo, x
    sta w_x, y
    lda y_pix, x
    sta w_y, y
    lda ball_ptr, x
    sta w_ptr, y
    lda ball_color, x
    sta w_col, y
    inc bld_slot
    jmp bl_band0
bl_band0_done:

    lda #HW_SPRITES
    sta bld_e                   // next entry (relative to the half)
    sta bld_slot                // ball_order index, from 8 on
bl_reuse:
    lda bld_slot
    cmp active_balls
    bcc !+
    jmp bl_done
!:
    and #HW_SPRITES - 1
    tay                         // Y = hardware sprite: ball_order index & 7
    ldx bld_slot
    lda ball_order, x
    tax                         // X = ball identity
    lda slot_free, y
    clc
    adc #RE_MARGIN
    bcs bl_skip                 // free line + margin > 255: no room
    cmp y_pix, x
    beq !+
    bcs bl_skip                 // free + margin > ball Y: no room
!:
    sty bld_hw                  // room: hardware sprite Y takes this ball
    lda slot_free, y
    sta bld_line                // ...from the line it comes free
    lda y_pix, x
    clc
    adc #SLOT_HOLD
    bcc !+
    lda #$ff
!:  sta slot_free, y            // and is busy again until this one is drawn
    lda x_msb, x
    beq !+
    lda hw_bit, y               // A = this sprite's $d010 bit, or 0
!:  sta bld_msbbit
    lda bld_e
    clc
    adc temp
    tay                         // Y = write list index
    lda bld_line
    sta w_line, y
    lda bld_hw
    sta w_slot, y
    lda bld_msbbit
    sta w_msb, y
    lda x_lo, x
    sta w_x, y
    lda y_pix, x
    sta w_y, y
    lda ball_ptr, x
    sta w_ptr, y
    lda ball_color, x
    sta w_col, y
    inc bld_e
bl_skip:
    inc bld_slot
    jmp bl_reuse

bl_done:
    ldx temp
    lda bld_en
    sta w_en, x
    lda bld_msb
    sta w_msb0, x
    txa
    clc
    adc bld_e
    sta w_end, x                // absolute: half base + entry count
    lda #$01
    sta dl_ready
    rts

//------------------------------------------------------------------
// The opening sequence lives in its own files: intro.asm is the code
// (title labels, vertical bars, the handoff to the demo screen),
// intro_sprites.asm builds the labels at assembly time, music.asm
// imports the tune.
// play_intro is called once from start, before anything else is set up.
//------------------------------------------------------------------
#import "intro.asm"


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
// detect_video - ntsc = nonzero on an NTSC machine. Interrupts off.
//
// Runs the raster up into its 9th bit (lines 256+) and keeps the highest
// low byte it sees there: an NTSC 6567R8 tops out at line $106 (low byte
// 6; the older R56A at 4), a PAL 6569 at $137 (low byte $37). Anything
// under $20 is NTSC. The max is kept, not the last value read, because
// the raster can wrap to line 0 between reading $d012 and testing bit 8.
//------------------------------------------------------------------
detect_video:
    lda #$00
    sta ntsc                    // scratch: the highest low byte seen
dv_wait:
    bit VIC_CONTROL1            // bit 7 = raster bit 8
    bpl dv_wait                 // wait for line 256+
dv_track:
    lda VIC_RASTER
    cmp ntsc
    bcc !+
    sta ntsc
!:  bit VIC_CONTROL1
    bmi dv_track                // until the raster wraps to line 0
    lda ntsc
    ldx #$00
    cmp #$20
    bcs !+                      // PAL: ntsc = 0
    inx                         // NTSC: ntsc = 1
!:  stx ntsc
    lda #$05
    sta music_div
    lda #$00
    sta beat_hold
    rts

//------------------------------------------------------------------
// music_tick - one tick of the tune, at the tune's own tempo.
//
// Nightshift is a PAL tune (its PSID header says so) written for one
// play call per 50 Hz frame. Called once per 60 Hz NTSC frame it runs 20%
// fast, so on NTSC this skips every sixth call: 5 plays in 6 frames is
// 50 a second. Every frame-locked caller uses this, never MUSIC_PLAY.
//------------------------------------------------------------------
music_tick:
    lda #$00
    sta beat_hold
    lda ntsc
    beq mt_play                 // PAL: every frame
    dec music_div
    bpl mt_play                 // 5, 4, 3, 2, 1, 0: play
    lda #$05                    // -1: the sixth frame - skip it
    sta music_div
    inc beat_hold               // and tell the intro's timers to hold
    rts
mt_play:
    jmp MUSIC_PLAY

// BeatDec - dec v, except on a frame music_tick skipped (beat_hold).
//
// The intro's phase lengths are counted in frames and written to land on
// the tune's beats. Slowing the tune to its PAL tempo on NTSC would leave
// a 60 Hz frame count finishing 20% early, off the beat - so every
// duration counter holds still on the skipped frame, and the intro's
// timing stays in music ticks on both standards. (The animation itself
// still moves every frame: only WHEN things change is locked to the tune.)
//
// Leaves Z as `dec v` would for the usual `BeatDec(v) / bne loop`: on a
// held frame v is reloaded, and it is never 0 mid-count.
.macro BeatDec(v) {
    lda beat_hold
    bne hold
    dec v
    jmp done
hold:
    lda v
done:
}

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

    jsr joy1_active             // a joystick in port 1 pulls the same
    bne ce_done                 // column lines: down would read as R
    lda #$fb                    // row 2: R restarts from the very beginning
    sta CIA1_PORT_A
    lda CIA1_PORT_B
    and #$02                    // R is row $fb, bit 1
    beq restart_demo
ce_done:

    lda #$ff                    // deselect all rows again
    sta CIA1_PORT_A
    rts

//------------------------------------------------------------------
// joy1_active - Z clear if a joystick in control port 1 is pushed or
// fired. Port 1 is wired onto the keyboard's column lines ($dc01), so
// with no row selected any low bit there is the joystick, not a key.
// RUN/STOP and Q (bits 7 and 6) are read before this is consulted: the
// joystick only drives bits 0-4, so the exit keys always work.
//------------------------------------------------------------------
joy1_active:
    lda #$ff
    sta CIA1_PORT_A             // no keyboard row selected
    lda CIA1_PORT_B
    and #$1f                    // up, down, left, right, fire
    cmp #$1f
    rts

//------------------------------------------------------------------
// restart_demo - R: run the whole thing again from the intro.
//
// Called from check_exit, so it works during the intro as well as during
// the demo. Everything the program needs is set up by start, so there is
// little to tear down but the hardware: the multiplexer IRQ has to stop
// (the intro runs polled, interrupts off), the SID has to be silenced
// (the intro re-initialises the tune, but a ping left gated would carry
// over the cut) and the sprites hidden before the mode switch. The intro's
// wave fields are assembled-in data, so nothing of the demo's may sit on
// top of them - see BALL_STATE.
//
// The wait for R to come back up matters: check_exit runs every frame, so
// without it holding the key down would restart the intro on every frame
// and the screen would sit frozen on its first black frame.
//------------------------------------------------------------------
restart_demo:
    sei                         // the intro runs without interrupts
    lda #$00
    sta VIC_IRQ_ENABLE          // and without the multiplexer
    lda #$01
    sta VIC_IRQ_STATUS
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
    sei                         // no more multiplexer IRQs: they would run
    lda #$00                    // on the kernal's vectors mid-reset
    sta VIC_IRQ_ENABLE
    lda #$01
    sta VIC_IRQ_STATUS
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
    lda #%11111111              // every hardware sprite multicolor; which
    sta VIC_SPRITE_MULTI        // are ENABLED is the top IRQ's job

    // Point every hardware sprite at frame 0 before anything can be
    // displayed. The multiplexer IRQ rewrites these every frame, but only
    // once init_mux has started it - and $07f8-$07ff is exactly 8 bytes
    // whatever the ball count.
    ldx #HW_SPRITES - 1
    lda #SPRITE_PTR_BASE
init_ptrs:
    sta SPRITE_PTRS, x
    dex
    bpl init_ptrs

    lda #$00
    sta VIC_SPRITE_X_MSB        // all X < 256 until the IRQ takes over
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
    // register - mux_irq writes that from the write list, whichever
    // hardware sprite the ball lands on this frame.
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
    sta evx_lo, x               // at rest, so the scaled cache is 0 too
    sta evx_hi, x
    sta evy_lo, x
    sta evy_hi, x
    lda #EASE_FRAMES
    sta ease_left, x
    jsr new_heading             // sets tvx/tvy

    // Random spin phase so the balls don't all show the same frame.
    jsr get_random
    sta anim_hi, x
    lsr                         // and the matching sprite frame, so the
    lsr                         // first write list (built in init_mux,
    lsr                         // BEFORE update_sprites) shows a ball,
    and #$07                    // not whatever bytes sat in ball_ptr
    clc
    adc #SPRITE_PTR_BASE
    sta ball_ptr, x
    lda #$00
    sta anim_lo, x

    dex
    bpl init_loop

    // Fall through: ball_order starts as the identity permutation.

//------------------------------------------------------------------
// reset_order - ball_order = 0, 1, .. MAX_BALLS-1 (slot i holds ball i)
//
// update_sprites moves ball IDENTITIES 0..active_balls-1, while
// sort_balls, build_list and check_collisions use whatever identities
// sit in ball_order[0..active_balls-1]. Those are only the same set
// while the slots are a permutation of 0..n-1 - which a sorted list
// stops being the moment active_balls changes (after SHIFT+B, slots
// 0..n-2 hold the n-1 HIGHEST balls, not balls 0..n-2). So every change
// of active_balls calls this; the next sort_balls re-sorts from here.
//------------------------------------------------------------------
reset_order:
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
//   1.  while ease_left > 0 (a ball's first EASE_FRAMES frames in play):
//       ease base velocity toward target, then rescale it by the speed
//       level into evx/evy. After that evx/evy are a CACHE - only a speed
//       change (rescale_some) or a negation (bounce, push) touches them.
//       This is the bulk of the multiplexer's budget: easing plus two
//       ScaleVels was ~900 of the ~1150 cycles a ball used to cost.
//   2.  integrate position (position += effective velocity)
//   3.  edge clamp / bounce (flips the base velocity and target)
//   4.  update spin accumulator and pick the animation frame
//------------------------------------------------------------------
update_sprites:
    ldx active_balls            // runtime count now, not a constant - only
    dex                         // the balls actually in play get stepped,
update_loop:                    // so raising/lowering it changes the cost
    //---- 1. Ease velocity toward target, while the ball spins up ----
    lda ease_left, x
    beq us_eased
    dec ease_left, x
    EaseVelocity(vx_lo, vx_hi, tvx_lo, tvx_hi)
    EaseVelocity(vy_lo, vy_hi, tvy_lo, tvy_hi)
    lda ease_left, x
    and #$03                    // rescale every 4th frame of the ramp
    bne us_eased                // (and on its last, ease_left = 0): the
    jsr scale_ball              // cache lags by 3 frames, nobody can tell
us_eased:

    //---- 2a. Integrate X ----
    // X position is 3 bytes (msb:lo:frac) but velocity is only 2 bytes,
    // so the velocity's sign must be extended into the MSB add:
    // add $00 for positive velocity, $ff for negative (plus carry).
    clc
    lda x_frac, x
    adc evx_lo, x
    sta x_frac, x
    lda x_lo, x
    adc evx_hi, x
    sta x_lo, x
    lda evx_hi, x
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
    adc evy_lo, x
    sta y_frac, x
    lda y_pix, x
    adc evy_hi, x
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
    adc evx_lo, x
    sta anim_lo, x
    lda anim_hi, x
    adc evx_hi, x
    sta anim_hi, x
    clc
    lda anim_lo, x
    adc evy_lo, x
    sta anim_lo, x
    lda anim_hi, x
    adc evy_hi, x
    sta anim_hi, x              // A = anim_hi (whole pixels travelled)

    lsr                         // /8: one frame per 8 pixels of travel
    lsr
    lsr
    and #$07                    // frame 0..7
    clc
    adc #SPRITE_PTR_BASE        // block number = $80 + frame
    sta ball_ptr, x              // this ball's LOGICAL pointer - the IRQ
                                  // writes it to whichever hardware
                                  // sprite the ball lands on

    dex
    bmi update_done
    jmp update_loop             // loop body > 128 bytes, so jmp not bne
update_done:
    rts

//------------------------------------------------------------------
// scale_ball - evx/evy[X] = vx/vy[X] * speed / 8. Preserves X.
//
// rescale_some - after a speed change, rescale up to RESCALE_PER_FRAME
// balls per frame (all MAX_BALLS, active or not, so a ball switched on
// later already has the right cached velocity). Spread over frames
// because doing all 16 at once is ~9600 cycles: more than half an NTSC
// frame in one go, for a change nobody can see take 4 frames instead
// of 1.
//------------------------------------------------------------------
scale_ball:
    ScaleVel(vx_lo, vx_hi, evx_lo, evx_hi)
    ScaleVel(vy_lo, vy_hi, evy_lo, evy_hi)
    rts

rescale_some:
    lda #RESCALE_PER_FRAME
    sta temp2                   // budget for this frame
rsc_loop:
    ldx rescale_n
    beq rsc_done
    dex
    stx rescale_n
    jsr scale_ball
    dec temp2
    bne rsc_loop
rsc_done:
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
    Negate16(evx_lo, evx_hi)    // keep the cache in step (see ScaleVel)
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
    Negate16(evy_lo, evy_hi)    // keep the cache in step (see ScaleVel)
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
// init_stars - scatter STAR_COUNT stars over the text screen
//
// Each star is a random cell offset 0..895 (rows 0-22: clear of the
// legend and status rows, and of the sprite pointers at $07f8). The offset is remembered so update_effects can
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
    jsr joy1_active             // joystick in port 1: its lines would read
    beq ui_keys                 // as +, CRSR, B... - ignore the keyboard
    rts                         // this frame
ui_keys:

    lda #$fd                    // left shift?
    sta CIA1_PORT_A
    lda CIA1_PORT_B
    and #$80
    beq ui_shifted
    lda #$bf                    // right shift?
    sta CIA1_PORT_A
    lda CIA1_PORT_B
    and #$10
    bne ui_check_b              // no shift: still read B (plain B = more)
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
    lda #MAX_BALLS              // every cached velocity is stale now;
    sta rescale_n               // rescale_some catches up over 4 frames
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
    jsr reset_order               // keep drawn/collided set = moved set
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
// for balls that are actually scattered across the play field.
//
// Each frame only walks every other outer position (by frame parity), so
// a given pair is tested every second frame. That halves the cost - the
// single biggest item in a 16-ball NTSC frame - and costs nothing you can
// see: balls move at most 2.5 px a frame against a 20 px contact zone, so
// a touch is caught at worst one frame late, and while two balls still
// overlap they are tested again two frames on.
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
    eor frame_count             // already done its job for this frame
    lsr                         // C = parity(i) != parity(frame)
    bcc cc_outer
    dec sort_i                  // start on this frame's parity
cc_outer:
    lda sort_i
    bmi cc_done

    tay
    lda ball_order, y
    sta pair_a                  // ball A's identity
    tax
    lda y_pix, x
    sta pair_ay                 // A's y_pix - the pruning reference

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
    lda pair_ay
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
    dec sort_i                  // every OTHER outer position: the rest
    dec sort_i                  // are done next frame (see the header)
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
    lda ball_color, x            // logical, per-ball color, not the
    sta temp                      // hardware register - build_list picks
    lda ball_color, y             // it up into next frame's write list
    sta ball_color, x
    lda temp
    sta ball_color, y
    jsr spawn_spark             // X = A (restored above), Y = B             // ASCII spark at the point of contact
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
    Negate16(evx_lo, evx_hi)    // the cached scaled copy flips with it
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
    Negate16(evy_lo, evy_hi)
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
// Row runs 2..26 now that MAX_Y reaches into the opened bottom border;
// anything from the legend row down is skipped, so a spark never lands
// on the status rows or indexes past row_offset_*. The glyph is random; the cell's old character and color
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
    lsr                         // row 2..26: MAX_Y reaches the open border
    cmp #LEGEND_ROW / 40        // 23+ is the legend, the speed bar, or
    bcs ss_exit                 // off the text screen entirely - no spark
    tay                         // (row_offset_* only has 25 entries)

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
    .byte $10, $20, $40, $80    // one hardware sprite at a time
msb_clear:                      // ~hw_bit: clears one sprite's $d010 bit
    .byte $fe, $fd, $fb, $f7, $ef, $df, $bf, $7f

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

// Star cell offsets into the screen (0..895), low and high bytes
star_lo:    .fill STAR_COUNT, 0
star_hi:    .fill STAR_COUNT, 0
.errorif * > VIC_IDLE_FETCH, "Main Code has reached $3fff, which start zeroes"

//------------------------------------------------------------------
// Sprite graphics - 8 shaded ball frames at $2000,
// both generated at assembly time. Kept in their own file because they are
// pure data generation with no connection to the demo's logic or zero page.
//------------------------------------------------------------------
#import "sprite_gen.asm"

//------------------------------------------------------------------
// The intro tune (PSID, loads at its own $1000) and the intro's label
// sprites ($0c00) and sine table ($6600). All data only.
//------------------------------------------------------------------
#import "music.asm"
#import "intro_sprites.asm"

//------------------------------------------------------------------
// The raster bar overture.
// Code, so it needs somewhere to live: it goes in the spare RAM above the
// intro's sine table, at $6b00 - RAM the VIC is never pointed at.
// It started out in Main Code's spare RAM; that ran out first.
//------------------------------------------------------------------
#import "intro_raster.asm"
