    .org $0801
    .byte $0b, $08, $01, $00, $9e, $32, $30, $36, $31, $00, $00
    .org $2061

    // Initialize the sprite
    LDX #$00
    STX $D015       // Enable sprite 0
    LDA #$01
    STA $D027       // Set sprite color to white

    // Set sprite pointer to ball sprite data
    LDA #<BallSprite
    STA $07F8
    LDA #>BallSprite
    STA $07F9

    // Main loop
MainLoop:
    JSR MoveSpriteRandomly
    JSR WaitForVBlank
    JMP MainLoop

// Subroutine to move sprite randomly
MoveSpriteRandomly:
    LDA $D000       // Get current X position of sprite 0
    CLC
    ADC RandomValue // Add random value to X position
    STA $D000       // Store new X position

    LDA $D001       // Get current Y position of sprite 0
    CLC
    ADC RandomValue // Add random value to Y position
    STA $D001       // Store new Y position
    RTS

// Subroutine to wait for vertical blank
WaitForVBlank:
    BIT $D011
    BPL WaitForVBlank
    RTS

// Random value (for simplicity, using a fixed value here)
RandomValue:
    .byte $03

// Ball sprite data
BallSprite:
    .byte $3C, $42, $A9, $85, $85, $A9, $42, $3C
    .byte $00, $00, $00, $00, $00, $00, $00, $00

    .org $0800
    .word $0801
    .byte $9e, $32, $30, $36, $31, $00
    .word $0000