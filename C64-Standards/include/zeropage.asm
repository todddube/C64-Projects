// C64 Zero Page Allocations
// Compatible with KickAssembler v5.25
//
// Zero page map:
//   $00-$01  6510 I/O port (do not use)
//   $02-$0F  Free for programs (fast access)
//   $10-$7F  Available (BASIC disabled)
//   $80-$FF  BASIC/Kernal (safe when BASIC off)
//   $FB-$FE  Kernal indirect pointers (usable in custom IRQ)

//------------------------------------------------------------------------------
// General-purpose zero page variables
//------------------------------------------------------------------------------
.label zp_free_1        = $02    // General purpose byte 1
.label zp_free_2        = $03    // General purpose byte 2
.label zp_free_3        = $04    // General purpose byte 3
.label zp_free_4        = $05    // General purpose byte 4

//------------------------------------------------------------------------------
// Pointer pairs (for indirect indexed addressing)
//------------------------------------------------------------------------------
.label ptr1             = $FB    // 16-bit pointer 1 (low byte)
.label ptr1_hi          = $FC    // 16-bit pointer 1 (high byte)
.label ptr2             = $FD    // 16-bit pointer 2 (low byte)
.label ptr2_hi          = $FE    // 16-bit pointer 2 (high byte)

//------------------------------------------------------------------------------
// Temp variables (scratch space, not preserved across subroutine calls)
//------------------------------------------------------------------------------
.label temp1            = $06
.label temp2            = $07
.label temp3            = $08
.label temp4            = $09

//------------------------------------------------------------------------------
// Loop / counter variables
//------------------------------------------------------------------------------
.label loop_i           = $0A    // General loop counter i
.label loop_j           = $0B    // General loop counter j

//------------------------------------------------------------------------------
// Scroller / demo specific
//------------------------------------------------------------------------------
.label scroll_x         = $0C    // Current fine scroll X position (0-7)
.label frame_count      = $0D    // Frame counter (increments each frame)
