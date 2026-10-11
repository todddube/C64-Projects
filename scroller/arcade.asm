//==============================================================================
// FILE:        arcade.asm
// PROJECT:     STARDUST - imported by scroller.asm, not buildable on its own
// DESCRIPTION: ARCADE, the second part: an homage to Galaxian, Galaga,
//              Asteroids and Pac-Man, with a double-height scroller. It runs
//              ~30 seconds, then a random curtain wipe hands back to STARDUST.
//==============================================================================
//
// SCREEN, TOP TO BOTTOM
//
//   rows  0-1    1UP / HIGH SCORE, the score counting up       (chars)
//   rows  3-6    Galaxian formation, swaying: $d016 fine scroll at line 73,
//                coarse by redrawing the four rows             (chars)
//   lines 70-122   band A sprites: Galaga fighter, its shot, a bee and a
//                  butterfly looping in front of the formation
//   row   9      caption
//   line 127     band B sprites: Asteroids ship (16 headings), its shot,
//                six rocks that bounce in lines 136-187 and blow up when hit
//   row  17      captions
//   line 188     band C sprites: Pac-Man and the four ghosts. Pac-Man eats
//                the dots right to the power pill, the ghosts turn blue and
//                flee, he eats them for 200/400/800/1600, then it starts over
//   rows 18-21   the maze corridor: walls, dots, the pill       (chars)
//   rows 23-24   double-height scroller, $d016 at line 228      (chars)
//
// IRQ CHAIN (rewrites $fffe and $d012, like STARDUST)
//   line  20  irq_arc_top   band A sprites, then the music
//   line  73  irq_arc_sway  $d016 for the formation (row 2 is empty)
//   line 108  irq_arc_unsway $d016 back (row 7 is empty)
//   line 127  irq_arc_b     band B sprites
//   line 188  irq_arc_c     band C sprites and their multicolors
//   line 228  irq_arc_scr   $d016 for the scroller (row 22 is empty)
//   line 251  irq_arc_end   $d016 back, frame_flag for the main loop
// A band's sprites must end before the next band's IRQ moves them, and
// start a few lines after it: A ends by 125, B is Y 136-167, C is Y 203.
//
// MEMORY
//   $0800-$0fff  charset: ROM screen codes 0-63, custom $40-$7f, the
//                double-height font at $80-$bf (top) and $c0-$ff (bottom).
//                Built at start-up, while the character ROM is banked in.
//   $3400-$3ebf  43 sprites (arcade_sprites.asm)
//   zero page    $43-$67 (and $68-$78 for the wipe, wipe.asm)
//==============================================================================

.label ARC_CHARSET   = $0800
.label ARC_SPRITES   = $3400
.const ARC_PTR       = ARC_SPRITES / 64     // $d0
.const D018_ARC      = $12                  // screen $0400, chars $0800
.const ARC_BLANK     = $20                  // space
.const ARC_EDGE      = $7e                  // the wipe's chars
.const ARC_SOLID     = $7f
.const CH_ALIEN      = $40                  // $40-$45: 3 alien types x 2 chars
.const CH_WALL       = $48
.const CH_DOT_T      = $49                  // a dot is two chars, rows 19-20
.const CH_DOT_B      = $4a
.const CH_PILL_T     = $4b
.const CH_PILL_B     = $4c
.const CH_BIG_TOP    = $80                  // double-height font
.const CH_BIG_BOT    = $c0

// Sprites, in the order arcade_sprites.asm builds them
.const SP_PAC_R0     = 0
.const SP_PAC_R1     = 1
.const SP_PAC_C      = 2
.const SP_PAC_L0     = 3
.const SP_PAC_L1     = 4
.const SP_GHOST_R    = 5                    // 2 skirt frames each
.const SP_GHOST_L    = 7
.const SP_FRIGHT     = 9
.const SP_PTS        = 11                   // 200, 400, 800, 1600
.const SP_BULLET     = 15
.const SP_DOT        = 16
.const SP_FIGHTER    = 17
.const SP_BEE        = 18                   // 2 frames
.const SP_BFLY       = 20                   // 2 frames
.const SP_SHIP       = 22                   // 16 headings
.const SP_ROCK       = 38                   // 3 shapes
.const SP_EXPL       = 41                   // 2 frames
.const SP_COUNT      = 43

// Screen rows
.const FORM_ROW      = 3                    // rows 3-6
.const ROW_DOTS      = 19                   // rows 19-20
.const PILL_COL      = 37
.const ROW_SCR       = 23                   // rows 23-24

// Raster lines
.const ARC_LINE_TOP  = 20
.const ARC_LINE_SWAY = 73
.const ARC_LINE_UNSWAY = 108
.const ARC_LINE_B    = 127
.const ARC_LINE_C    = 188
.const ARC_LINE_SCR  = 228
.const ARC_LINE_END  = 251

// Positions. Sprite X is kept in 2-pixel units ("xs", 0-183), so it fits a
// byte; sxs doubles it into the shadow and its MSB. xs 0 and 172-183 are
// off the screen, so things wrap there out of sight.
.const XS_WRAP       = 184
.const FIGHTER_Y     = 105
.const GBUL_START    = FIGHTER_Y - 7        // shot's lines are Y+8..Y+11
.const GBUL_TOP      = 60
.const SHIP_XS       = 86                   // screen center
.const SHIP_Y        = 146
.const RK_YMIN       = 136
.const RK_YMAX       = 166
.const PAC_Y         = 203                  // corridor center is line 211

// The bands have no slack: a band's last sprite line (Y + 21) must come
// before the next band's IRQ moves the sprites
.errorif FIGHTER_Y + 21 >= ARC_LINE_B, "band A runs into irq_arc_b"
.errorif RK_YMAX + 21 >= ARC_LINE_C, "band B runs into irq_arc_c"

.const ARC_FRAMES_NTSC = 1795               // 30 s at 59.83 Hz
.const ARC_FRAMES_PAL  = 1500               // 30 s at 50 Hz

//==============================================================================
// ZERO PAGE ($43-$67)
//==============================================================================

.label a_timer       = $43                  // $43-$44: frames left
.label a_sway_t      = $45
.label a_coarse      = $46                  // formation column offset drawn
.label a_fine        = $47                  // $d016 for the formation
.label a_scroll      = $48                  // $d016 for the scroller
.label a_text        = $49                  // $49-$4a: next scroll text byte
.label a_score       = $4b                  // $4b-$4d: BCD, low byte first
.label a_dirty       = $4e                  // redraw the score
.label a_colt        = $4f
.label fighter_t     = $50
.label fighter_x     = $51
.label gbul_y        = $52                  // 0: no shot
.label gbul_x        = $53
.label div_t         = $54
.label ship_head     = $55                  // 0-15, clockwise from up
.label a_spin        = $56                  // +1 or -1
.label a_turn_t      = $57
.label a_fire_t      = $58
.label ab_life       = $59                  // Asteroids shot, 0: none
.label ab_xl         = $5a                  // position and velocity, 8.8
.label ab_xh         = $5b
.label ab_yl         = $5c
.label ab_yh         = $5d
.label ab_dxl        = $5e
.label ab_dxh        = $5f
.label ab_dyl        = $60
.label ab_dyh        = $61
.label pac_xl        = $62                  // 8.8, in xs
.label pac_xh        = $63
.label pac_phase     = $64                  // 0 chase, 1 frightened, 2 reset
.label pac_wait      = $65
.label a_lastcol     = $66                  // last column Pac-Man ate in
.label pts_t         = $67                  // frames the points stay up

//==============================================================================
// ENTRY
//==============================================================================

//------------------------------------------------------------------------------
// arcade_enter: from part_blackout (display off, irq_idle running)
//------------------------------------------------------------------------------
arcade_enter:
    jsr arc_init
    jsr part_sync
    sei
    lda #ARC_LINE_TOP
    sta VIC_RASTER
    lda #<irq_arc_top
    sta $fffe
    lda #>irq_arc_top
    sta $ffff
    lda #$1b                    // display on from the next frame
    sta VIC_CTRL1
    lda #$01
    sta VIC_IRQ_STATUS
    lda #$00
    sta frame_flag
    cli

//------------------------------------------------------------------------------
// arc_loop: one pass per frame, from line 251. The bands are updated in the
// order the beam needs them: A before line 20, B before 127, C before 188.
//------------------------------------------------------------------------------
arc_loop:
    lda frame_flag
    beq arc_loop
    lda #$00
    sta frame_flag

    jsr arc_update
    lda w_on
    bne al_wipe
    lda a_timer                 // 30 seconds, then the curtain
    bne !+
    dec a_timer + 1
!:  dec a_timer
    lda a_timer
    ora a_timer + 1
    bne al_tail
    jsr arc_wipe_start
    jmp al_tail
al_wipe:
    jsr wipe_step
    bcc al_tail
    jsr part_blackout           // all black: back to STARDUST
    ldx #20
    jsr wait_frames
    jmp stardust_enter
al_tail:
    jsr check_exit
    inc frame_count
    lda frame_flag              // the next frame already started: the
    beq arc_loop                // work overran (read with vice_peek)
    inc overruns
    jmp arc_loop

arc_update:
    jsr arc_band_a
    jsr arc_formation
    jsr arc_asteroids
    jsr arc_pac
    jsr arc_scroller
    jsr arc_header
    jmp arc_colors

arc_wipe_start:
    lda #$08                    // 40 columns in every band, so the
    sta a_wide                  // curtain's glow rows keep one width
    lda #ARC_EDGE
    sta w_edge
    lda #ARC_SOLID
    sta w_solid
    lda #<(ARC_CHARSET + ARC_EDGE * 8)
    sta w_g1
    sta w_g2
    lda #>(ARC_CHARSET + ARC_EDGE * 8)
    sta w_g1 + 1
    sta w_g2 + 1
    jmp wipe_start

//------------------------------------------------------------------------------
// arc_init: screen, state and shadows, with the display off
//------------------------------------------------------------------------------
arc_init:
    jsr wipe_reset
    lda #$00
    sta a_wide
    ldx #$00                    // the static screen, 1000 chars and colors
!:  lda arc_scr, x
    sta SCREEN_RAM, x
    lda arc_scr + $100, x
    sta SCREEN_RAM + $100, x
    lda arc_scr + $200, x
    sta SCREEN_RAM + $200, x
    lda arc_scr + $2e8, x
    sta SCREEN_RAM + $2e8, x
    lda arc_col, x
    sta COLOR_RAM, x
    lda arc_col + $100, x
    sta COLOR_RAM + $100, x
    lda arc_col + $200, x
    sta COLOR_RAM + $200, x
    lda arc_col + $2e8, x
    sta COLOR_RAM + $2e8, x
    inx
    bne !-

    ldx #23                     // sprite shadows: pointers, colors, Y
!:  lda sh_ptr_init, x
    sta sh_ptr, x
    lda sh_col_init, x
    sta sh_col, x
    lda sh_y_init, x
    sta sh_y, x
    lda #$00
    sta sh_xh, x
    dex
    bpl !-
    ldx #2
!:  lda sh_mc_init, x
    sta sh_mc, x
    dex
    bpl !-
    lda #SHIP_XS                // the ship never moves
    ldy #8
    jsr sxs

    ldx #<ARC_FRAMES_PAL
    ldy #>ARC_FRAMES_PAL
    lda ntsc
    beq !+
    ldx #<ARC_FRAMES_NTSC
    ldy #>ARC_FRAMES_NTSC
!:  stx a_timer
    sty a_timer + 1

    lda #$00
    sta a_sway_t
    sta fighter_t
    sta div_t
    sta gbul_y
    sta ship_head
    sta ab_life
    sta pac_phase
    sta pac_xl
    sta pac_xh
    sta pts_t
    lda #$ff
    sta a_coarse                // the formation draws on the first update
    sta a_lastcol
    lda #$07
    sta a_scroll
    lda #$01
    sta a_spin
    sta a_dirty
    lda #10
    sta a_turn_t
    lda #30
    sta a_fire_t
    lda #<arc_text
    sta a_text
    lda #>arc_text
    sta a_text + 1

    ldx #5                      // rocks spread across the band
!:  jsr rk_spawn
    lda rk_init_x, x
    sta rk_xh, x
    lda #$00
    sta rk_state, x
    dex
    bpl !-

    lda #D018_ARC
    sta VIC_MEMSETUP
    lda #$08
    sta VIC_CTRL2
    lda #$00
    sta VIC_SPRITE_PRI          // sprites in front of the chars
    sta VIC_SPRITE_EXP_X
    sta VIC_SPRITE_EXP_Y
    jmp arc_update              // the first frame's shadows and formation

//------------------------------------------------------------------------------
// arc_reset_score: 000000, high score 010000. Once, at start-up: the score
// carries on from one visit to the next.
//------------------------------------------------------------------------------
arc_reset_score:
    lda #$00
    sta a_score
    sta a_score + 1
    sta a_score + 2
    sta a_hi
    sta a_hi + 1
    lda #$01
    sta a_hi + 2
    rts

//------------------------------------------------------------------------------
// build_arc_font: the charset at $0800. Needs the character ROM ($01 = $33).
//------------------------------------------------------------------------------
build_arc_font:
    ldx #$00                    // screen codes 0-63 as they are
!:  lda CHAR_ROM, x
    sta ARC_CHARSET, x
    lda CHAR_ROM + $100, x
    sta ARC_CHARSET + $100, x
    lda arc_glyphs, x           // and the custom chars, $40-$7f
    sta ARC_CHARSET + $200, x
    lda arc_glyphs + $100, x
    sta ARC_CHARSET + $300, x
    inx
    bne !-

    ldx #$00                    // double height, made bold: line j of the
baf_char:                       // top half is ROM line j/2, of the bottom
    .for (var p = 0; p < 2; p++) {      // half ROM line 4 + j/2
        .for (var j = 0; j < 8; j++) {
            lda CHAR_ROM + p * $100 + floor(j / 2), x
            sta tmp
            lsr
            ora tmp
            sta ARC_CHARSET + CH_BIG_TOP * 8 + p * $100 + j, x
            lda CHAR_ROM + p * $100 + 4 + floor(j / 2), x
            sta tmp
            lsr
            ora tmp
            sta ARC_CHARSET + CH_BIG_BOT * 8 + p * $100 + j, x
        }
    }
    txa
    clc
    adc #$08
    tax
    beq !+
    jmp baf_char
!:  rts

//==============================================================================
// INTERRUPTS
//==============================================================================

// Copy band b's shadows to the VIC. Only A is used.
.macro BandCopy(b) {
    .for (var i = 0; i < 8; i++) {
        lda sh_y + b * 8 + i
        sta VIC_SPRITE0_Y + i * 2
        lda sh_x + b * 8 + i
        sta VIC_SPRITE0_X + i * 2
        lda sh_ptr + b * 8 + i
        sta SPRITE_PTR_BASE + i
        lda sh_col + b * 8 + i
        sta VIC_SPRITE0_COL + i
    }
    lda sh_msb + b
    sta VIC_SPRITE_X_MSB
    lda sh_mc + b
    sta VIC_SPRITE_MC
    lda sh_en + b
    sta VIC_SPRITE_EN
}

// Point $fffe at the next handler and $d012 at its line, and ack this one
.macro NextIrq(handler, line) {
    lda #line
    sta VIC_RASTER
    lda #<handler
    sta $fffe
    lda #>handler
    sta $ffff
    lda #$01
    sta VIC_IRQ_STATUS
}

irq_arc_top:
    sta irq_a
    stx irq_x
    sty irq_y
    BandCopy(0)
    NextIrq(irq_arc_sway, ARC_LINE_SWAY)
    jsr music_tick              // ends by line ~60, well before 73
    lda irq_a
    ldx irq_x
    ldy irq_y
    rti

irq_arc_sway:
    pha
    lda a_fine
    ora a_wide
    sta VIC_CTRL2
    NextIrq(irq_arc_unsway, ARC_LINE_UNSWAY)
    pla
    rti

irq_arc_unsway:
    pha
    lda #$08
    sta VIC_CTRL2
    NextIrq(irq_arc_b, ARC_LINE_B)
    pla
    rti

irq_arc_b:
    pha
    BandCopy(1)
    NextIrq(irq_arc_c, ARC_LINE_C)
    pla
    rti

irq_arc_c:
    pha
    BandCopy(2)
    lda #COLOR_WHITE            // ghost eyes
    sta VIC_SPRITE_MC0
    lda #COLOR_BLUE             // and pupils
    sta VIC_SPRITE_MC1
    NextIrq(irq_arc_scr, ARC_LINE_SCR)
    pla
    rti

irq_arc_scr:
    pha
    lda a_scroll
    ora a_wide
    sta VIC_CTRL2
    NextIrq(irq_arc_end, ARC_LINE_END)
    pla
    rti

irq_arc_end:
    pha
    lda #$08
    sta VIC_CTRL2
    inc frame_flag
    NextIrq(irq_arc_top, ARC_LINE_TOP)
    pla
    rti

//==============================================================================
// PER-FRAME WORK
//==============================================================================

//------------------------------------------------------------------------------
// sxs: A = x in 2-pixel units, Y = shadow slot (band * 8 + sprite).
// Keeps X.
//------------------------------------------------------------------------------
sxs:
    asl
    sta sh_x, y
    lda #$00
    rol
    sta sh_xh, y
    rts

// Pack band b's X MSBs into sh_msb + b
.macro PackMsb(b) {
    lda #$00
    sta tmp
    .for (var i = 7; i >= 0; i--) {
        lda sh_xh + b * 8 + i
        lsr
        rol tmp
    }
    lda tmp
    sta sh_msb + b
}

//------------------------------------------------------------------------------
// add_score: score += A (BCD units) + X (BCD hundreds). With interrupts off:
// an IRQ does not clear the decimal flag on an NMOS 6502, so the music
// would run in decimal mode.
//------------------------------------------------------------------------------
add_score:
    sei
    sed
    clc
    adc a_score
    sta a_score
    txa
    adc a_score + 1
    sta a_score + 1
    lda #$00
    adc a_score + 2
    sta a_score + 2
    cld
    cli
    lda #$01
    sta a_dirty
    rts

//------------------------------------------------------------------------------
// arc_band_a: the Galaga fighter, its shot, and the bee and butterfly
// looping a figure eight in front of the formation
//------------------------------------------------------------------------------
arc_band_a:
    inc fighter_t
    ldy fighter_t
    lda fighter_x_tab, y
    sta fighter_x
    ldy #0
    jsr sxs
    lda #%00001101              // fighter and the two bugs
    sta tmp3

    lda gbul_y
    bne ga_up
    lda frame_count             // a shot every 32 frames
    and #$1f
    bne ga_bugs
    lda fighter_x
    sta gbul_x
    lda #GBUL_START
    sta gbul_y
    bne ga_show
ga_up:
    sec
    sbc #4
    sta gbul_y
    cmp #GBUL_TOP
    bcs ga_show
    lda #$00
    sta gbul_y
    beq ga_bugs
ga_show:
    lda gbul_y
    sta sh_y + 1
    lda gbul_x
    ldy #1
    jsr sxs
    lda tmp3
    ora #%00000010
    sta tmp3

ga_bugs:
    inc div_t
    ldx div_t
    lda div_x, x
    ldy #2
    jsr sxs
    lda div_y, x
    sta sh_y + 2
    txa                         // the butterfly, half a loop behind
    eor #$80
    tax
    lda div_x, x
    ldy #3
    jsr sxs
    lda div_y, x
    sta sh_y + 3
    lda frame_count             // wings flap every 8 frames
    lsr
    lsr
    lsr
    and #$01
    tax
    clc
    adc #ARC_PTR + SP_BEE
    sta sh_ptr + 2
    txa
    clc
    adc #ARC_PTR + SP_BFLY
    sta sh_ptr + 3

    lda tmp3
    sta sh_en + 0
    PackMsb(0)
    rts

//------------------------------------------------------------------------------
// arc_formation: Galaxian sway. Fine scroll goes to irq_arc_sway; when the
// column offset changes, the four rows are redrawn from form_img (each row
// padded with 10 blanks on the left, so offset c reads from 10 - c).
// Unrolled: ~1300 cycles on a redraw. Every 16 frames the aliens flap.
//------------------------------------------------------------------------------
arc_formation:
    lda #FORM_ROW
    jsr row_locked
    bcs af_out
    lda #FORM_ROW + 3
    jsr row_locked
    bcc !+
af_out:
    rts
!:

    inc a_sway_t
    ldy a_sway_t
    lda form_sway, y            // 0-72 pixels
    tax
    and #$07
    sta a_fine                  // bit 3 clear: 38 columns
    txa
    lsr
    lsr
    lsr
    cmp a_coarse
    bne !+
    jmp af_flap
!:  sta a_coarse
    eor #$ff                    // Y = 10 - coarse
    sec
    adc #10
    tay
    .for (var r = 0; r < 4; r++) {
        .for (var i = 0; i < 40; i++) {
            lda form_img + r * 50 + i, y
            sta SCREEN_RAM + (FORM_ROW + r) * 40 + i
        }
    }

af_flap:
    lda frame_count
    and #$0f
    bne af_out2
    ldx #47                     // frame (frame_count / 16) & 1
    lda frame_count
    and #$10
    beq !+
    ldx #95
!:  ldy #47
!:  lda alien_frames, x
    sta ARC_CHARSET + CH_ALIEN * 8, y
    dex
    dey
    bpl !-
af_out2:
    rts

//------------------------------------------------------------------------------
// arc_asteroids: the ship turns and fires; rocks drift, wrap left and
// right, bounce top and bottom, and blow up when the shot finds them.
// Band B slots: 0 ship, 1 shot, 2-7 rocks.
//------------------------------------------------------------------------------
arc_asteroids:
    dec a_turn_t                // a notch every 10 frames, and now and
    bne as_ship                 // then the other way
    lda #10
    sta a_turn_t
    lda ship_head
    clc
    adc a_spin
    and #$0f
    sta ship_head
    jsr rnd
    cmp #24
    bcs as_ship
    lda a_spin
    eor #$fe                    // +1 <-> -1
    sta a_spin
as_ship:
    lda ship_head
    clc
    adc #ARC_PTR + SP_SHIP
    sta sh_ptr + 8
    lda #%11111101              // ship and rocks; the shot if it flies
    sta tmp3

    lda ab_life
    bne as_move
    dec a_fire_t
    beq !+
    jmp as_rocks
!:
    lda #16
    sta a_fire_t
    ldx ship_head               // fire along the heading, from the center
    lda ab_dxl_tab, x
    sta ab_dxl
    lda ab_dxh_tab, x
    sta ab_dxh
    lda ab_dyl_tab, x
    sta ab_dyl
    lda ab_dyh_tab, x
    sta ab_dyh
    lda #SHIP_XS
    sta ab_xh
    lda #SHIP_Y
    sta ab_yh
    lda #$80
    sta ab_xl
    sta ab_yl
    lda #40
    sta ab_life

as_move:
    lda ab_xl
    clc
    adc ab_dxl
    sta ab_xl
    lda ab_xh
    adc ab_dxh
    cmp #XS_WRAP
    bcc as_bx
    lda #$00                    // off the right: in on the left
    bit ab_dxh
    bpl as_bx
    lda #XS_WRAP - 1            // off the left: in on the right
as_bx:
    sta ab_xh
    lda ab_yl
    clc
    adc ab_dyl
    sta ab_yl
    lda ab_yh
    adc ab_dyh
    sta ab_yh
    cmp #RK_YMIN                // out of the band: gone
    bcc as_kill
    cmp #RK_YMAX + 1
    bcs as_kill
    dec ab_life
    bne !+
    jmp as_rocks
!:

    ldx #5                      // a hit: within 12 pixels across and
as_hit:                         // 9 lines down of a rock's center
    lda rk_state, x
    bne as_hnext
    lda ab_xh
    sec
    sbc rk_xh, x
    bcs !+
    eor #$ff
    adc #$01
!:  cmp #6
    bcs as_hnext
    lda ab_yh
    sec
    sbc rk_yh, x
    bcs !+
    eor #$ff
    adc #$01
!:  cmp #9
    bcs as_hnext
    lda #24                     // boom: 24 frames of debris
    sta rk_state, x
    lda #$50
    ldx #$00
    jsr add_score
    jmp as_kill
as_hnext:
    dex
    bpl as_hit
    lda ab_xh
    ldy #9
    jsr sxs
    lda ab_yh
    sta sh_y + 9
    lda #%11111111
    sta tmp3
    bne as_rocks
as_kill:
    lda #$00
    sta ab_life

as_rocks:
    ldx #5
as_rk:
    lda rk_state, x
    beq as_alive
    dec rk_state, x
    bne as_boom
    jsr rk_spawn                // debris gone: a new rock from an edge
    jmp as_alive
as_boom:
    lda rk_state, x             // the debris spreads out halfway through
    cmp #12
    lda #ARC_PTR + SP_EXPL
    bcs !+
    lda #ARC_PTR + SP_EXPL + 1
!:  jmp as_draw

as_alive:
    lda rk_vx, x
    bmi as_left
    clc
    adc rk_xl, x
    sta rk_xl, x
    lda rk_xh, x
    adc #$00
    cmp #XS_WRAP
    bcc as_xs
    lda #$00
    beq as_xs
as_left:
    clc
    adc rk_xl, x
    sta rk_xl, x
    lda rk_xh, x
    adc #$ff
    cmp #XS_WRAP
    bcc as_xs
    lda #XS_WRAP - 1
as_xs:
    sta rk_xh, x

    lda rk_vy, x
    bmi as_up
    clc
    adc rk_yl, x
    sta rk_yl, x
    lda rk_yh, x
    adc #$00
    cmp #RK_YMAX
    bcc as_ys
    jsr rk_flip
    lda #RK_YMAX
    bne as_ys
as_up:
    clc
    adc rk_yl, x
    sta rk_yl, x
    lda rk_yh, x
    adc #$ff
    cmp #RK_YMIN
    bcs as_ys
    jsr rk_flip
    lda #RK_YMIN
as_ys:
    sta rk_yh, x
    lda rk_ptr, x

as_draw:                        // A = pointer; slot 10 + rock
    pha
    txa
    clc
    adc #10
    tay
    pla
    sta sh_ptr, y
    lda rk_yh, x
    sta sh_y, y
    lda rk_xh, x
    jsr sxs
    dex
    bmi !+
    jmp as_rk
!:  lda tmp3
    sta sh_en + 1
    PackMsb(1)
    rts

rk_flip:                        // bounce: vy = -vy
    lda rk_vy, x
    eor #$ff
    clc
    adc #$01
    sta rk_vy, x
    rts

//------------------------------------------------------------------------------
// rk_spawn: rock X comes in from the left or right edge, at a random
// height, speed and shape. Keeps X.
//------------------------------------------------------------------------------
rk_spawn:
    jsr rnd                     // 64-127/256 xs a frame: 0.5-1 pixel
    and #$3f
    ora #$40
    sta tmp2
    jsr rnd
    and #$01
    beq rs_left
    lda #XS_WRAP - 1
    sta rk_xh, x
    lda tmp2
    eor #$ff
    clc
    adc #$01
    jmp rs_vx
rs_left:
    sta rk_xh, x                // A = 0
    lda tmp2
rs_vx:
    sta rk_vx, x
    jsr rnd
    and #$1f
    cmp #RK_YMAX - RK_YMIN
    bcc !+
    sbc #RK_YMAX - RK_YMIN
!:  adc #RK_YMIN
    sta rk_yh, x
    jsr rnd
    and #$3f
    sec
    sbc #$20                    // -32..31 /256 lines a frame
    sta rk_vy, x
    jsr rnd
    and #$03
    cmp #$03
    bcc !+
    lda #$00
!:  clc
    adc #ARC_PTR + SP_ROCK
    sta rk_ptr, x
    rts

//------------------------------------------------------------------------------
// arc_pac: the corridor. Band C slots: 0 Pac-Man, 1-4 ghosts, 5 points.
//   phase 0  Pac-Man runs right eating dots, the ghosts behind him
//   phase 1  he ate the pill: all turn left, the ghosts blue and slower;
//            he eats each one he catches (200, 400, 800, 1600)
//   phase 2  off the left edge: a pause, the dots come back, phase 0
//------------------------------------------------------------------------------
arc_pac:
    lda #ROW_DOTS               // curtain over the dots: no char writes
    jsr row_locked
    lda #$00
    rol
    sta pac_lock
    lda #ROW_DOTS + 1
    jsr row_locked
    lda #$00
    rol
    ora pac_lock
    sta pac_lock

    lda #$00
    sta tmp3                    // band C enable bits
    lda pac_phase
    beq ap_chase
    cmp #$01
    bne !+
    jmp ap_fright
!:  jmp ap_reset

ap_chase:
    lda pac_xl                  // 0.75 xs = 1.5 pixels a frame
    clc
    adc #$c0
    sta pac_xl
    lda pac_xh
    adc #$00
    sta pac_xh
    ldy #16
    jsr sxs
    lda frame_count
    lsr
    lsr
    and #$03
    tax
    lda pac_anim_r, x
    sta sh_ptr + 16
    lda #%00000001
    sta tmp3

    lda frame_count             // ghosts look right, skirts swish
    lsr
    lsr
    lsr
    and #$01
    clc
    adc #ARC_PTR + SP_GHOST_R
    sta tmp2
    ldx #3
ac_ghost:
    lda tmp2
    sta sh_ptr + 17, x
    lda ghost_col, x
    sta sh_col + 17, x
    lda pac_xh
    sec
    sbc ghost_off, x
    bcc ac_next                 // still off the left edge
    pha
    txa
    clc
    adc #17
    tay
    pla
    jsr sxs
    lda tmp3
    ora ghost_bit, x
    sta tmp3
ac_next:
    dex
    bpl ac_ghost

    lda pac_lock                // eat what is in front of him
    bne ap_points_j
    lda pac_xh
    sec
    sbc #4
    bcc ap_points_j
    lsr
    lsr
    cmp #40
    bcs ap_points_j
    cmp a_lastcol
    beq ap_points_j
    sta a_lastcol
    tay
    lda SCREEN_RAM + ROW_DOTS * 40, y
    cmp #CH_DOT_T
    bne ac_pill
    lda #ARC_BLANK
    sta SCREEN_RAM + ROW_DOTS * 40, y
    sta SCREEN_RAM + (ROW_DOTS + 1) * 40, y
    lda #$10
    ldx #$00
    jsr add_score
ap_points_j:
    jmp ap_points
ac_pill:
    cmp #CH_PILL_T
    bne ap_points_j
    lda #ARC_BLANK
    sta SCREEN_RAM + ROW_DOTS * 40, y
    sta SCREEN_RAM + (ROW_DOTS + 1) * 40, y
    lda #$50
    ldx #$00
    jsr add_score
    lda #$01                    // power pill: everyone turns around
    sta pac_phase
    lda #$00
    sta fright_t
    sta pac_eaten
    lda #$0f
    sta g_alive
    ldx #3
!:  lda pac_xh
    sec
    sbc ghost_off, x
    sta g_xh, x
    lda #$00
    sta g_xl, x
    dex
    bpl !-
    jmp ap_points

ap_fright:
    lda pac_xl                  // Pac-Man left at 0.75 xs a frame
    sec
    sbc #$c0
    sta pac_xl
    lda pac_xh
    sbc #$00
    sta pac_xh
    cmp #4
    bcs !+
    lda #$02                    // off the left edge: pause, then again
    sta pac_phase
    lda #60
    sta pac_wait
    jmp ap_points
!:  ldy #16
    jsr sxs
    lda frame_count
    lsr
    lsr
    and #$03
    tax
    lda pac_anim_l, x
    sta sh_ptr + 16
    lda #%00000001
    sta tmp3

    inc fright_t
    lda frame_count
    lsr
    lsr
    lsr
    and #$01
    clc
    adc #ARC_PTR + SP_FRIGHT
    sta tmp2
    ldy #COLOR_BLUE             // blue, flashing white near the end
    lda fright_t
    cmp #100
    bcc !+
    lda frame_count
    and #$08
    beq !+
    ldy #COLOR_WHITE
!:  sty temp4

    ldx #3
af_ghost:
    lda g_alive
    and alive_bit, x
    beq af_next
    lda g_xl, x                 // the ghosts flee at half his speed
    sec
    sbc #$60
    sta g_xl, x
    lda g_xh, x
    sbc #$00
    sta g_xh, x
    lda pac_xh                  // caught?
    sec
    sbc g_xh, x
    cmp #5
    bcs af_show
    lda g_alive
    and alive_off, x
    sta g_alive
    lda g_xh, x
    sta pts_x
    lda #ARC_PTR + SP_PTS
    clc
    adc pac_eaten
    sta sh_ptr + 21
    lda #50
    sta pts_t
    stx loop_i                  // add_score uses X
    ldy pac_eaten
    lda pts_bcd, y
    tax
    lda #$00
    jsr add_score
    ldx loop_i
    inc pac_eaten
    jmp af_next
af_show:
    lda tmp2
    sta sh_ptr + 17, x
    lda temp4
    sta sh_col + 17, x
    txa
    clc
    adc #17
    tay
    lda g_xh, x
    jsr sxs
    lda tmp3
    ora ghost_bit, x
    sta tmp3
af_next:
    dex
    bpl af_ghost
    jmp ap_points

ap_reset:
    dec pac_wait
    bne ap_points
    lda pac_lock
    beq !+
    inc pac_wait                // the curtain is over the dots: later
    bne ap_points
!:  ldx #39                     // the dots and the pill come back
!:  lda arc_scr + ROW_DOTS * 40, x
    sta SCREEN_RAM + ROW_DOTS * 40, x
    lda arc_scr + (ROW_DOTS + 1) * 40, x
    sta SCREEN_RAM + (ROW_DOTS + 1) * 40, x
    dex
    bpl !-
    lda #$00
    sta pac_phase
    sta pac_xl
    sta pac_xh
    lda #$ff
    sta a_lastcol

ap_points:
    lda pts_t
    beq ap_en
    dec pts_t
    lda pts_x
    ldy #21
    jsr sxs
    lda tmp3
    ora #%00100000
    sta tmp3
ap_en:
    lda tmp3
    sta sh_en + 2
    PackMsb(2)

    lda pac_lock                // the pill blinks
    bne !++
    ldx #COLOR_WHITE
    lda frame_count
    and #$08
    bne !+
    ldx #COLOR_BLACK
!:  stx COLOR_RAM + ROW_DOTS * 40 + PILL_COL
    stx COLOR_RAM + (ROW_DOTS + 1) * 40 + PILL_COL
!:  rts

//------------------------------------------------------------------------------
// arc_scroller: double height, 2 pixels a frame, rows 23-24
//------------------------------------------------------------------------------
arc_scroller:
    lda #ROW_SCR
    jsr row_locked
    bcs ar_rts
    lda #ROW_SCR + 1
    jsr row_locked
    bcs ar_rts
    lda a_scroll
    sec
    sbc #2
    bmi !+
    sta a_scroll
ar_rts:
    rts
!:  and #$07
    sta a_scroll
    .for (var i = 0; i < 39; i++) {
        lda SCREEN_RAM + ROW_SCR * 40 + i + 1
        sta SCREEN_RAM + ROW_SCR * 40 + i
        lda SCREEN_RAM + (ROW_SCR + 1) * 40 + i + 1
        sta SCREEN_RAM + (ROW_SCR + 1) * 40 + i
    }
    ldy #$00
    lda (a_text), y
    cmp #$ff
    bne !+
    lda #<arc_text
    sta a_text
    lda #>arc_text
    sta a_text + 1
    lda (a_text), y
!:  and #$3f
    ora #CH_BIG_TOP
    sta SCREEN_RAM + ROW_SCR * 40 + 39
    ora #CH_BIG_BOT
    sta SCREEN_RAM + (ROW_SCR + 1) * 40 + 39
    inc a_text
    bne !+
    inc a_text + 1
!:  rts

//------------------------------------------------------------------------------
// arc_header: 1UP blinks; the score (and the high score, when beaten) is
// redrawn when it changes
//------------------------------------------------------------------------------
.macro Digits(src, dst) {
    .for (var b = 0; b < 3; b++) {
        lda src + 2 - b
        lsr
        lsr
        lsr
        lsr
        ora #$30
        sta dst + b * 2
        lda src + 2 - b
        and #$0f
        ora #$30
        sta dst + b * 2 + 1
    }
}

ah_out:
    rts
arc_header:
    lda #0
    jsr row_locked
    bcs ah_out
    ldx #COLOR_RED
    lda frame_count
    and #$10
    bne !+
    ldx #COLOR_BLACK
!:  stx COLOR_RAM + 3
    stx COLOR_RAM + 4
    stx COLOR_RAM + 5
    lda #1
    jsr row_locked
    bcs ah_out
    lda a_dirty
    beq ah_out
    lda #$00
    sta a_dirty
    lda a_score + 2             // beaten the high score?
    cmp a_hi + 2
    bcc ah_draw
    bne ah_new
    lda a_score + 1
    cmp a_hi + 1
    bcc ah_draw
    bne ah_new
    lda a_score
    cmp a_hi
    bcc ah_draw
ah_new:
    lda a_score
    sta a_hi
    lda a_score + 1
    sta a_hi + 1
    lda a_score + 2
    sta a_hi + 2
ah_draw:
    Digits(a_score, SCREEN_RAM + 40 + 1)
    Digits(a_hi, SCREEN_RAM + 40 + 16)
    rts

//------------------------------------------------------------------------------
// arc_colors: a rainbow running along the scroller, every other frame
//------------------------------------------------------------------------------
arc_colors:
    lda frame_count
    and #$01
    bne ac_out
    lda #ROW_SCR
    jsr row_locked
    bcs ac_out
    lda #ROW_SCR + 1
    jsr row_locked
    bcs ac_out
    inc a_colt
    ldx #39
!:  txa
    lsr
    clc
    adc a_colt
    and #$0f
    tay
    lda scr_top_cols, y
    sta COLOR_RAM + ROW_SCR * 40, x
    lda scr_bot_cols, y
    sta COLOR_RAM + (ROW_SCR + 1) * 40, x
    dex
    bpl !-
ac_out:
    rts
