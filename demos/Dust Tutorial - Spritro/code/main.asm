//===================================
// main.asm triggers all subroutines
// and runs the interrupt routine
//===================================

main:     sei                       // disable interrupts

          jsr clear_screen          // clear the screen
          lda #$00
          sta exit_flag
          jsr init_objects          // ship state, timers, random seed
          jsr detect_video          // NTSC or PAL, for the music tempo
          jsr sfx_init              // silence the SID, volume up
.if (PLAY_MUSIC) {
          lda $f8                   // Nightshift's player uses $f8/$f9 (the
          sta saved_f8              // KERNAL's RS-232 pointers): keep them
          lda $f9                   // for the return to BASIC
          sta saved_f9
          lda #$00                  // subtune 0
          jsr init_sid              // init music routine
}
          jsr write_text            // write five lines of text

          lda #$00                  // animation delay flag, EORed with 1 each frame
          sta delay_animation_pointer

          lda #$01                  // delay counter for side border colour switching
          sta delay_counter

          ldy #$7f                  // $7f = %01111111
          sty $dc0d                 // turn off CIA#1 timer interrupts
          sty $dd0d                 // turn off CIA#2 timer interrupts
          lda $dc0d                 // reading $dc0d/$dd0d cancels pending CIA IRQs
          lda $dd0d

          lda #<nmi                 // RESTORE must not warm-start BASIC
          ldx #>nmi                 // while our IRQ vector is installed
          sta $0318
          stx $0319

          lda #$01                  // interrupt request mask:
          sta $d01a                 // IRQ by raster beam (%00000001)

          lda #<irq                 // point the IRQ vector at our routine
          ldx #>irq
          sta $0314                 // $0314/$0315
          stx $0315

          lda #$00                  // trigger the interrupt at raster line 0,
          sta $d012                 // as the original did. That broke once the
                                    // ship sat at Y=$ff (on NTSC that sprite wraps
                                    // past line 262 and was mid-draw at line 0),
                                    // but now no sprite goes below the bottom wall.
                                    // The frame's work must finish before the
                                    // beam reaches the sprites at line 50 and the
                                    // text at 58: colour RAM is written first,
                                    // sprites next; measured under full load
                                    // that is done by about raster line 38 and
                                    // the music call starts there (32-38),
                                    // ending by about line 65 (NTSC); nothing
                                    // visual follows it
          lda $d011
          and #$7f                  // raster compare bit 8 = 0
          sta $d011
          lda #$01                  // drop any raster IRQ latched before setup,
          sta $d019                 // or the first IRQ fires at a random line

          lda #$06                  // blue border
          sta $d020

          cli                       // enable interrupts
wait_exit: lda exit_flag            // everything runs in the IRQ; the main
          beq wait_exit             // loop only waits for RUN/STOP

//=============================
// back to BASIC: undo everything the intro changed, then rts
// returns through the SYS to the READY prompt. The original
// jumped to $ea81 from inside a JSR, which cannot work, and a
// jmp ($fffc) reset misbehaves with freezer cartridges.
//=============================
          sei
          lda #$00
          sta $d015                 // sprites off
          sta $d01a                 // raster IRQ off
          sta $d418                 // SID volume off
          sta $c6                   // drop keys the KERNAL buffered while we ran
          lda #$01
          sta $d019                 // acknowledge any pending raster IRQ
          lda #$81
          sta $dc0d                 // CIA#1 timer A IRQ back on (KERNAL jiffy/keyboard)
          lda #<$ea31               // stock KERNAL IRQ and NMI vectors
          ldx #>$ea31
          sta $0314
          stx $0315
          lda #<$fe47
          ldx #>$fe47
          sta $0318
          stx $0319
          lda #$1b                  // stock VIC: 25 rows, ROM charset, hires
          sta $d011
          lda #$c8
          sta $d016
          lda #$15
          sta $d018
          lda #$0e                  // light blue border, blue screen
          sta $d020
          lda #$06
          sta $d021
.if (PLAY_MUSIC) {
          lda saved_f8
          sta $f8
          lda saved_f9
          sta $f9
}
          jsr $e544                 // clear the screen
          cli
          rts                       // back to BASIC READY

nmi:      rti

exit_flag: .byte 0
saved_f8:  .byte 0
saved_f9:  .byte 0

//=============================
// NTSC or PAL: with interrupts off, wait for raster bit 8 ($d011
// bit 7), then keep the highest $d012 low byte seen until the
// raster wraps. PAL reaches $37 (line 311), NTSC only $06 (262).
// (From the c64-demo-framework skill template.)
//=============================
detect_video:
          lda #$00
          sta ntsc                  // scratch: highest low byte seen
!:        bit $d011
          bmi !-                    // wait until below line 256
!:        bit $d011
          bpl !-                    // wait for line 256+
!track:   lda $d012
          cmp ntsc
          bcc !+
          sta ntsc
!:        bit $d011
          bmi !track-               // until the raster wraps to line 0
          lda ntsc
          ldx #$00
          cmp #$20
          bcs !+                    // PAL
          inx                       // NTSC
!:        stx ntsc
          lda #$05
          sta music_div
          rts

//=============================
// Nightshift is a 50 Hz tune. On NTSC the frame IRQ runs 60 times
// a second, so every sixth call is skipped (5 in 6 = 49.9 Hz) and
// the tune keeps its tempo; on PAL it plays every frame.
//=============================
music_tick:
.if (PLAY_MUSIC) {
          lda ntsc
          beq !+                    // PAL: every frame
          dec music_div
          bpl !+                    // 5, 4, 3, 2, 1, 0: play
          lda #$05                  // -1: the sixth frame, skip it
          sta music_div
          rts
!:        jmp play_sid
} else {
          rts
}

//=============================
// one-time setup of the objects added to the tutorial
//=============================
init_objects:
          lda #SHIP_FLYING
          sta ship_state
          lda #$00
          sta ship_timer
          sta flash_timer
          sta flame_timer
          sta fire_cooldown
          sta rocket_active
          sta rocket_active + 1
          sta sfx_pew_timer
          sta sfx_boom_timer
          ldx #$03
!:        sta ast_state,x
          dex
          bpl !-
          lda #$01                  // first rock on the first frame
          sta ast_spawn_timer
          lda $dc04                 // CIA#1 timer A low byte: a different
          ora #$01                  // seed every run (never 0)
          sta rnd_seed
          rts

//================================
// the custom interrupt routine, once per frame at raster line 0
//================================

irq:      dec $d019                 // acknowledge the raster IRQ
                                    // colour RAM first, while the beam is in
                                    // the top border, then the sprite registers
                                    // before it reaches the sprites at line 50:
          jsr color_cycle           // colour cycle on the text
          jsr flash_update          // white screen flash after a crash
          jsr update_ship           // move / animate / explode the ship
          jsr update_flame          // exhaust follows it
          jsr update_rockets        // rockets fly left
          jsr update_asteroids      // rocks drift right
          jsr check_collisions      // walls, rockets vs rocks, rocks vs ship
          jsr check_keyboard        // keyboard / joystick controls (writes
                                    // sprite registers, so before the music)
          jsr music_tick            // the tune, at 50 Hz on both standards
          jsr sfx_update            // then the effects, over the tune's voices

//=============================
// open the top/bottom borders
//=============================

irq_work_done:                      // (a label to measure the frame's work at)
          lda #$00                  // clear potential garbage in $3fff
          sta $3fff

          lda #$f9                  // wait for raster line 249
!:        cmp $d012
          bne !-

          lda $d011                 // switch to 24 rows: trick the VIC into
          and #$f7                  // not closing the border
          sta $d011

          lda #$ff                  // wait for raster line 255
!:        cmp $d012
          bne !-

          lda $d011                 // back to 25 rows for the next frame
          ora #$08
          sta $d011

          jmp $ea81                 // KERNAL IRQ exit: restore registers, rti.
                                    // The original went through $ea31 (jiffy
                                    // clock, keyboard scan); nothing here needs
                                    // those, and their ~20 raster lines after
                                    // line 255 held up the next frame's IRQ
