// C64 Standard Constants
// Compatible with KickAssembler v5.25

//------------------------------------------------------------------------------
// VIC-II Registers
//------------------------------------------------------------------------------
.label VIC_SPRITE0_X    = $D000
.label VIC_SPRITE0_Y    = $D001
.label VIC_SPRITE1_X    = $D002
.label VIC_SPRITE1_Y    = $D003
.label VIC_SPRITE2_X    = $D004
.label VIC_SPRITE2_Y    = $D005
.label VIC_SPRITE3_X    = $D006
.label VIC_SPRITE3_Y    = $D007
.label VIC_SPRITE4_X    = $D008
.label VIC_SPRITE4_Y    = $D009
.label VIC_SPRITE5_X    = $D00A
.label VIC_SPRITE5_Y    = $D00B
.label VIC_SPRITE6_X    = $D00C
.label VIC_SPRITE6_Y    = $D00D
.label VIC_SPRITE7_X    = $D00E
.label VIC_SPRITE7_Y    = $D00F
.label VIC_SPRITE_X_MSB = $D010
.label VIC_CTRL1        = $D011    // Vertical scroll, screen height, blanking
.label VIC_RASTER       = $D012    // Raster counter
.label VIC_LIGHTPEN_X   = $D013
.label VIC_LIGHTPEN_Y   = $D014
.label VIC_SPRITE_EN    = $D015    // Sprite enable bits
.label VIC_CTRL2        = $D016    // Horizontal scroll, screen width, multicolor
.label VIC_SPRITE_EXP_Y = $D017    // Sprite expand Y
.label VIC_MEMSETUP     = $D018    // Memory pointers
.label VIC_IRQ_STATUS   = $D019    // Interrupt status register
.label VIC_IRQ_ENABLE   = $D01A    // Interrupt enable register
.label VIC_SPRITE_PRI   = $D01B    // Sprite/background priority
.label VIC_SPRITE_MC    = $D01C    // Sprite multicolor select
.label VIC_SPRITE_EXP_X = $D01D    // Sprite expand X
.label VIC_SPRITE_COLL  = $D01E    // Sprite-sprite collision
.label VIC_BG_COLL      = $D01F    // Sprite-background collision
.label VIC_BORDER       = $D020    // Border color
.label VIC_BACKGROUND   = $D021    // Background color 0
.label VIC_BGCOLOR1     = $D022    // Background color 1
.label VIC_BGCOLOR2     = $D023    // Background color 2
.label VIC_BGCOLOR3     = $D024    // Background color 3
.label VIC_SPRITE_MC0   = $D025    // Sprite multicolor 0
.label VIC_SPRITE_MC1   = $D026    // Sprite multicolor 1
.label VIC_SPRITE0_COL  = $D027
.label VIC_SPRITE1_COL  = $D028
.label VIC_SPRITE2_COL  = $D029
.label VIC_SPRITE3_COL  = $D02A
.label VIC_SPRITE4_COL  = $D02B
.label VIC_SPRITE5_COL  = $D02C
.label VIC_SPRITE6_COL  = $D02D
.label VIC_SPRITE7_COL  = $D02E

//------------------------------------------------------------------------------
// SID Registers
//------------------------------------------------------------------------------
.label SID_V1_FREQ_LO   = $D400
.label SID_V1_FREQ_HI   = $D401
.label SID_V1_PW_LO     = $D402
.label SID_V1_PW_HI     = $D403
.label SID_V1_CTRL      = $D404
.label SID_V1_AD        = $D405
.label SID_V1_SR        = $D406
.label SID_V2_FREQ_LO   = $D407
.label SID_V2_FREQ_HI   = $D408
.label SID_V2_PW_LO     = $D409
.label SID_V2_PW_HI     = $D40A
.label SID_V2_CTRL      = $D40B
.label SID_V2_AD        = $D40C
.label SID_V2_SR        = $D40D
.label SID_V3_FREQ_LO   = $D40E
.label SID_V3_FREQ_HI   = $D40F
.label SID_V3_PW_LO     = $D410
.label SID_V3_PW_HI     = $D411
.label SID_V3_CTRL      = $D412
.label SID_V3_AD        = $D413
.label SID_V3_SR        = $D414
.label SID_FILTER_LO    = $D415
.label SID_FILTER_HI    = $D416
.label SID_FILTER_CTRL  = $D417
.label SID_VOLUME       = $D418
.label SID_V3_OSC       = $D41B
.label SID_V3_ENV       = $D41C

//------------------------------------------------------------------------------
// CIA Registers
//------------------------------------------------------------------------------
.label CIA1_BASE        = $DC00
.label CIA1_PORTA       = $DC00
.label CIA1_PORTB       = $DC01
.label CIA1_DDRA        = $DC02
.label CIA1_DDRB        = $DC03
.label CIA1_TIMERA_LO   = $DC04
.label CIA1_TIMERA_HI   = $DC05
.label CIA1_TIMERB_LO   = $DC06
.label CIA1_TIMERB_HI   = $DC07
.label CIA1_ICR         = $DC0D
.label CIA1_CRA         = $DC0E
.label CIA1_CRB         = $DC0F

.label CIA2_BASE        = $DD00
.label CIA2_PORTA       = $DD00
.label CIA2_PORTB       = $DD01
.label CIA2_DDRA        = $DD02
.label CIA2_DDRB        = $DD03
.label CIA2_ICR         = $DD0D
.label CIA2_CRA         = $DD0E
.label CIA2_CRB         = $DD0F

//------------------------------------------------------------------------------
// Memory Locations
//------------------------------------------------------------------------------
.label SCREEN_RAM       = $0400
.label COLOR_RAM        = $D800
.label CHAR_ROM         = $D000    // (when ROM mapped in)
.label SPRITE_PTR_BASE  = $07F8    // Sprite pointers (default screen)

//------------------------------------------------------------------------------
// C64 Colors (0-15)
//------------------------------------------------------------------------------
.label COLOR_BLACK      = 0
.label COLOR_WHITE      = 1
.label COLOR_RED        = 2
.label COLOR_CYAN       = 3
.label COLOR_PURPLE     = 4
.label COLOR_GREEN      = 5
.label COLOR_BLUE       = 6
.label COLOR_YELLOW     = 7
.label COLOR_ORANGE     = 8
.label COLOR_BROWN      = 9
.label COLOR_LIGHT_RED  = 10
.label COLOR_DARK_GREY  = 11
.label COLOR_GREY       = 12
.label COLOR_LIGHT_GREEN = 13
.label COLOR_LIGHT_BLUE = 14
.label COLOR_LIGHT_GREY = 15

//------------------------------------------------------------------------------
// Screen Codes (PETSCII → screen RAM codes)
//------------------------------------------------------------------------------
.label SC_SPACE         = $20    // Space character
.label SC_AT            = $00    // @ symbol
.label SC_A             = $01
.label SC_Z             = $1A
.label SC_HEART         = $53
.label SC_CIRCLE        = $51    // Filled circle
.label SC_CROSS         = $58
.label SC_CHECKER       = $5F

//------------------------------------------------------------------------------
// Kernal Routines
//------------------------------------------------------------------------------
.label KERNAL_CHROUT    = $FFD2
.label KERNAL_GETIN     = $FFE4
.label KERNAL_READST    = $FFB7
.label KERNAL_SETLFS    = $FFBA
.label KERNAL_SETNAM    = $FFBD
.label KERNAL_OPEN      = $FFC0
.label KERNAL_CLOSE     = $FFC3
.label KERNAL_CHKIN     = $FFC6
.label KERNAL_CHKOUT    = $FFC9
.label KERNAL_CLRCHN    = $FFCC

//------------------------------------------------------------------------------
// IRQ Vectors
//------------------------------------------------------------------------------
.label IRQ_VECTOR       = $0314
.label NMI_VECTOR       = $0318
.label KERNAL_IRQ       = $EA31    // Standard kernal IRQ handler
.label KERNAL_IRQ_FAST  = $EA81    // Fast kernal IRQ return
