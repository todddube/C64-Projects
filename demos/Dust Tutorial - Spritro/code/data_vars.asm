//============================================================
// State of the objects added to the tutorial (plain RAM in
// the code segment; the ship's own two bytes stay in zero
// page as in the tutorial)
//============================================================

ship_state:       .byte 0         // SHIP_FLYING / EXPLODING / RESPAWNED
ship_timer:       .byte 0         // frames left in the current state
flash_timer:      .byte 0         // screen flash frames left
flame_timer:      .byte 0         // frame counter for the exhaust animation
fire_cooldown:    .byte 0         // frames until the next rocket may launch

rocket_active:    .byte 0, 0      // Sprite#2, #3
rocket_x_lo:      .byte 0, 0
rocket_x_hi:      .byte 0, 0      // 9th X bit
rocket_y:         .byte 0, 0

ast_state:        .fill 4, 0      // Sprite#4 to #7: AST_OFF / DRIFTING / EXPLODING
ast_x_lo:         .fill 4, 0
ast_x_hi:         .fill 4, 0
ast_y:            .fill 4, 0
ast_speed:        .fill 4, 0      // 1 or 2 pixels per frame, rightwards
ast_timer:        .fill 4, 0      // explosion frames left
ast_spawn_timer:  .byte 1         // frames until the next spawn attempt

rnd_seed:         .byte $a5       // 8-bit LFSR state, reseeded from CIA timer A

tmp1:             .byte 0         // scratch (not zero page, see config_symbols.asm)
tmp2:             .byte 0
controls:         .byte 0         // bit 0 up, bit 1 down, bit 4 fire, from keys + joystick

coll_ax_lo:       .byte 0         // the two boxes compared by sub_collisions.asm:
coll_ax_hi:       .byte 0         // object A: X low byte, X 9th bit, Y
coll_ay:          .byte 0
coll_bx_lo:       .byte 0         // object B
coll_bx_hi:       .byte 0
coll_by:          .byte 0

sfx_pew_timer:    .byte 0         // SID registers are write-only, so the
sfx_pew_freq:     .byte 0         // sweeping frequencies are shadowed here
sfx_boom_timer:   .byte 0
sfx_boom_freq:    .byte 0

ntsc:             .byte 0         // 1 on NTSC, 0 on PAL (detect_video in main.asm)
music_div:        .byte 5         // NTSC: counts the frames between skipped play calls
