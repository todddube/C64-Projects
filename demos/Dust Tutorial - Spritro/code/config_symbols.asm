//============================================================
// general symbols used in the code
//============================================================

.label screen_ram      = $0400          // screen RAM
.label sprite_pointers = screen_ram + $3f8   // the 8 sprite pointers ($07f8-$07ff)
.label init_sid        = music.init     // music init (Nightshift: $1d70)
.label play_sid        = music.play     // music play (Nightshift: $1003)
.label delay_counter   = $90            // times the border colour switch
.label pra             = $dc00          // CIA#1 port A
.label prb             = $dc01          // CIA#1 port B
.label ddra            = $dc02          // CIA#1 data direction A
.label ddrb            = $dc03          // CIA#1 data direction B

//============================================================
// Music: Nightshift (config_resources.asm) plays under the sound
// effects. Its player rewrites the voices' frequency and control
// bytes each frame, so sub_sfx.asm re-asserts its two voices after
// each play call for as long as an effect lasts (the tune loses
// that voice meanwhile).
// Set this to false to run with the effects only, as the tutorial's
// silent empty_1000.sid did.
//============================================================
.const PLAY_MUSIC = true

//============================================================
// Gameplay constants (added to the tutorial)
//============================================================

// No zero page beyond the tutorial's $fb/$fc/$90: BASIC and the KERNAL
// stay banked in and we return to BASIC, and $03-$06 (the first
// "free" bytes) are really BASIC's USR vectors. Scratch bytes live
// in data_vars.asm instead (tmp1, tmp2, controls, coll_*).

// ship states
.const SHIP_FLYING        = 0
.const SHIP_EXPLODING     = 1
.const SHIP_RESPAWNED     = 2           // flying again, blinking, cannot be hit
.const SHIP_RESPAWN_Y     = $80         // mid-screen
.const SHIP_RESPAWN_FRAMES = 90         // 1.5 s of invulnerability
.const SHIP_X_MIN         = 0           // fully off the left edge (visible from 24)...
.const SHIP_X_MAX         = $158        // ...wraps to just off the right edge (344)

// walls: the ship's sprite Y when its visible rows 3-18 touch the
// top of the screen (raster 50) or the bottom text row (raster 242)
.const TOP_WALL           = $2f         // 47
.const BOTTOM_WALL        = $e0         // 224

// explosions, shared by ship and asteroids
.const EXPLOSION_FRAMES   = 16          // 4 shapes x 4 frames
.const EXPLOSION_COLOR    = $07         // yellow
.const FLASH_FRAMES       = 3           // screen flash when the ship dies
.const FLASH_COLOR        = $01         // white

// exhaust flame, Sprite#1
.const FLAME_DX           = 24          // right behind the ship, which flies left
.const FLAME_COLOR_A      = $07         // yellow
.const FLAME_COLOR_B      = $08         // orange

// rockets, Sprite#2 and #3
.const ROCKET_SPEED       = 6           // pixels per frame, leftwards
.const ROCKET_DX          = 8           // launched from the ship's nose
.const ROCKET_DY          = 9           // at the ship's centre row
.const ROCKET_COLOR       = $01         // white
.const ROCKET_X_MIN       = 16          // retired once off the left edge
.const FIRE_COOLDOWN      = 12          // frames between shots

// asteroids, Sprite#4 to #7
.const AST_OFF            = 0
.const AST_DRIFTING       = 1
.const AST_EXPLODING      = 2
.const AST_SPAWN_FRAMES   = 50          // a new rock every 50 frames if a slot is free
.const AST_Y_MIN          = 56          // spawn Y range: 56 + (0..127)
.const AST_X_MAX_LO       = <$158       // gone once past X = 344 (high bit set)
.const AST_COLOR          = $09         // brown

// sound effects
.const PEW_FRAMES         = 12
.const PEW_FREQ_HI        = $30
.const PEW_SWEEP          = 2           // freq high byte drop per frame
.const BOOM_FRAMES        = 30
.const BOOM_FREQ_HI       = $30
.const BOOM_SWEEP         = 1
