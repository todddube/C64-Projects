//============================================================
// Collision detection, all in software so each pair is known:
//   1. the ship against the top and bottom walls
//   2. each drifting asteroid against each rocket in flight
//   3. each drifting asteroid against the ship
// Two objects collide when their boxes overlap; a box test is a
// 16-bit X difference (9-bit sprite X) and an 8-bit Y difference.
//============================================================

check_collisions:   lda ship_state
                    cmp #SHIP_EXPLODING
                    bne !+                         // nothing hits a fireball
                    rts
!:

                    lda $d001                      // 1. walls
                    cmp #TOP_WALL
                    bcc ship_hits_top
                    cmp #BOTTOM_WALL
                    bcc coll_asteroids
                    lda #BOTTOM_WALL - 1           // park the ship on the wall so
                    sta $d001                      // the explosion shows there
                    jmp ship_hits_wall
ship_hits_top:      lda #TOP_WALL
                    sta $d001
ship_hits_wall:     lda #SHIP_FLYING               // walls hit even a freshly
                    sta ship_state                 // respawned, invulnerable ship
                    jmp ship_crash

coll_asteroids:     ldx #$03                       // 2. every drifting asteroid...
coll_ast:           lda ast_state,x
                    cmp #AST_DRIFTING
                    bne coll_ast_next
                    lda ast_x_lo,x                 // ...is object A
                    sta coll_ax_lo
                    lda ast_x_hi,x
                    sta coll_ax_hi
                    lda ast_y,x
                    sta coll_ay

                    ldy #$01                       // ...against each rocket (object B)
coll_rocket:        lda rocket_active,y
                    beq coll_rocket_next
                    lda rocket_x_lo,y
                    sta coll_bx_lo
                    lda rocket_x_hi,y
                    sta coll_bx_hi
                    lda rocket_y,y
                    sta coll_by
                    jsr box_rocket_asteroid        // carry set = hit
                    bcc coll_rocket_next
                    lda #$00                       // the rocket is spent...
                    sta rocket_active,y
                    lda rocket_bitmask,y           // ...its sprite goes off now
                    eor #$ff
                    and $d015
                    sta $d015
                    jsr asteroid_explode           // ...and the rock blows up
                    jmp coll_ast_next              // (it is gone, so next rock)
coll_rocket_next:   dey
                    bpl coll_rocket

                    lda ship_state                 // 3. ...against the ship, unless
                    bne coll_ast_next              // it is still invulnerable
                    lda $d000
                    sta coll_bx_lo
                    lda $d010
                    and #%00000001
                    sta coll_bx_hi
                    lda $d001
                    sta coll_by
                    jsr box_ship_asteroid
                    bcc coll_ast_next
                    jsr asteroid_explode           // both go up
                    jsr ship_crash
coll_ast_next:      dex
                    bpl coll_ast
coll_done:          rts

//------------------------------------------------------------
// Box test between object A (coll_ax_lo/hi, coll_ay) and object B
// (coll_bx_lo/hi, coll_by). Hit, carry set, when
//    -addx <= ax - bx < w - addx   and   -addy <= ay - by < h - addy
// The Y test adds addy to the 8-bit difference: a carry means the
// difference was negative but within range. Y positions on this
// screen differ by at most 180, so that wrap is unambiguous.
//------------------------------------------------------------
.macro BoxCheck(addx, w, addy, h) {
                    lda coll_ax_lo                 // dx = ax - bx (16-bit)
                    sec
                    sbc coll_bx_lo
                    sta tmp1
                    lda coll_ax_hi
                    sbc coll_bx_hi
                    sta tmp2
                    lda tmp1                      // dx + addx must be 0..w-1
                    clc
                    adc #addx
                    sta tmp1
                    lda tmp2
                    adc #$00
                    bne miss                       // negative or >= 256: miss
                    lda tmp1
                    cmp #w
                    bcs miss
                    lda coll_ay                    // dy = ay - by (8-bit)
                    sec
                    sbc coll_by
                    clc
                    adc #addy                      // dy + addy must be 0..h-1
                    bcs hit                        // (wrapped: dy was -addy..-1)
                    cmp #h
                    bcc hit
miss:               clc
                    rts
hit:                sec
                    rts
}

// asteroid pixels span X+0..X+21, Y+2..Y+14; a rocket is X+0..X+8
// on rows Y+0..Y+2, so they touch for ax-rx in -21..8, ay-ry in -14..0
box_rocket_asteroid: BoxCheck(21, 30, 14, 15)

// the ship spans X+0..X+23, Y+3..Y+18; a little lenient on purpose
box_ship_asteroid:   BoxCheck(18, 36, 14, 28)

//------------------------------------------------------------
// screen flash after a crash: white for FLASH_FRAMES frames
//------------------------------------------------------------
flash_update:       lda flash_timer
                    beq flash_off
                    dec flash_timer
                    lda #FLASH_COLOR
                    sta $d021
                    rts
flash_off:          lda #sprite_background_color
                    sta $d021
                    rts
