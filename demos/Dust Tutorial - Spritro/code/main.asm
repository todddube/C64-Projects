//===================================
// main.asm triggers all subroutines
// and runs the interrupt routine
//===================================

main:     sei                       // disable interrupts

          jsr clear_screen          // clear the screen
          jsr init_sid              // init music routine
          jsr write_text            // write three lines of text

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

          lda #$14                  // trigger the interrupt at raster line 20:
          sta $d012                 // the original used line 0, which on NTSC is
                                    // inside the ship sprite (Y=$ff wraps past
                                    // line 262), so its registers changed mid-draw
          lda $d011
          and #$7f                  // raster compare bit 8 = 0
          sta $d011
          lda #$01                  // drop any raster IRQ latched before setup,
          sta $d019                 // or the first IRQ fires at a random line

          lda #$06                  // blue border
          sta $d020

          cli                       // enable interrupts
          jmp *                     // infinite loop, everything runs in the IRQ

nmi:      rti

//================================
// the custom interrupt routine
//================================

irq:      dec $d019                 // acknowledge the raster IRQ
          jsr color_cycle           // colour cycle on the text
          jsr play_sid              // play music
          jsr update_ship           // move the ship
          jsr check_keyboard        // keyboard controls

//=============================
// open the top/bottom borders
//=============================

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

          jmp $ea31                 // continue with the KERNAL IRQ routine
