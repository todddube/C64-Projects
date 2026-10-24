//============================================================
// Sprite#1, the exhaust flame: follows the ship one sprite width
// behind it (the ship flies left, so to its right), cycles its
// 4 shapes and flickers between two colours. It is shown exactly
// when the ship is, so it blinks with it after a respawn, and is
// hidden while the ship explodes.
//============================================================

update_flame:       lda $d000                      // X = ship X + FLAME_DX
                    clc
                    adc #FLAME_DX
                    sta $d002
                    lda $d010
                    and #%00000001                 // ship's 9th bit...
                    adc #$00                       // ...plus the carry of the add
                    and #%00000001                 // (wraps at 512 like the ship)
                    asl                            // into Sprite#1's bit
                    sta tmp1
                    lda $d010
                    and #%11111101
                    ora tmp1
                    sta $d010

                    lda $d001                      // same Y as the ship
                    sta $d003

                    lda ship_state
                    cmp #SHIP_EXPLODING
                    beq flame_hide

                    lda $d015
                    and #%00000001                 // copy the ship's enable bit
                    asl
                    sta tmp1
                    lda $d015
                    and #%11111101
                    ora tmp1
                    sta $d015

                    inc flame_timer
                    lda flame_timer
                    lsr                            // a new shape every 2 frames
                    and #%00000011                 // 4 shapes
                    clc
                    adc #sprite_pointer_flame
                    sta sprite_pointers + 1

                    ldx #FLAME_COLOR_A             // flicker every 2 frames
                    lda flame_timer
                    and #%00000010
                    beq !+
                    ldx #FLAME_COLOR_B
!:                  stx $d028
                    rts

flame_hide:         lda $d015
                    and #%11111101
                    sta $d015
                    rts
