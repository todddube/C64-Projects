# CLAUDE.md

Guidance for Claude Code in this repository: Commodore 64 demos in 6502 assembly
(KickAssembler) by **RetroDubTRVA**.

## Tooling comes from c64-agent-kit

The general C64 knowledge and tools live in **[c64-agent-kit](https://github.com/todddube/c64-agent-kit)**
(local checkout `~/Documents/Github/c64-agent-kit`), installed globally as Agent Skills in
`~/.claude/skills/` (symlinks: `git pull` there updates them). Use them instead of
recalling details:

| Skill | Use it for |
|---|---|
| `c64-toolchain` | `python3 ~/.claude/skills/c64-toolchain/scripts/c64.py doctor / build / run / shot / peek / mon` |
| `c64-kickassembler` | syntax, directives, error messages |
| `c64-hardware` | VIC-II, SID, CIA, memory map, 6502 cycles: read it, don't recall addresses |
| `c64-demo-framework` | takeover skeleton, NTSC/PAL detection, music tempo, borders, blanking |
| `c64-code-review` | the review checklist |
| `c64-vice-debugging` | breakpoints on raster line/cycle, stopwatch, profiler |
| `c64-disassembly` | Regenerator 2000 → rebuildable KickAssembler source |

The **`c64-reviewer`** subagent (`~/.claude/agents/c64-reviewer.md`) runs the
`c64-code-review` skill. Use it after writing or changing C64 assembly. Brief it with a mode
(STATIC by default, MEASURED, or FOLLOW-UP), at most ~1000 lines of source, and "target
NTSC". `spritemove/agent_recomm.md` has the timing data behind those limits.

The `6502-*` skills (instruction set, memory map, Merlin, SWEET16, 6502-to-Rust) come with
the kit too: github.com/sunsided/6502-skills is a submodule at `vendor/6502-skills`, and the
kit's installer links them into `~/.claude/skills/`.

Fix general C64 knowledge in the kit (and push it), not here. This file holds only what is
specific to this repository.

## Target platform: NTSC (US) first

The owner runs **NTSC** C64s. Every demo is designed, budgeted and tested for the NTSC
6567R8 first: 263 lines, 65 cycles/line, **17095 cycles/frame**, 59.83 Hz. PAL must keep
working where that is cheap (detect at start-up). A design that only fits a PAL frame is a
bug. Test with `c64.py ... --ntsc` (the default) first, `--pal` second. Tell subagents
explicitly to target NTSC.

## Local tools (macOS)

`c64.py doctor` finds them. For reference:
- KickAssembler v5.25: `/Applications/KickAssembler/` (`KickAss.jar`, `KickAssembler.pdf`,
  `Examples/`). `KickAss.cfg` beside the jar is read on every build and sets only
  `-libdir .`. Never add `-showmem`, `-symbolfile`, `-debug` or `-bytedump` to it; pass
  them for a single build only.
- VICE (arm64/GTK3): `/Applications/vice-arm64-gtk3/bin/x64sc` (also `c1541`, `petcat`).
- Regenerator 2000: `/Applications/regenerator/regenerator2000`.

Slash commands in `.claude/commands/`: `/build [path]`, `/build-all`, `/run [prg]`,
`/c64-new <name>`, all wrappers around the kit.

## Repository layout

A "project" is a directory with `main.asm`, **or** a directory whose single top-level
`.asm` is the main source (`scroller/scroller.asm`). Directories with several `.asm` files
and no `main.asm` (`c64_lessons/lesson11/` step files, `demos/`, `Galactic Rasterbar/`)
are not auto-buildable; name the file explicitly. Build output goes to `<project>/bin/`.

`C64-Standards/include/` holds this repo's shared KickAssembler includes
(`c64_constants.asm`, `zeropage.asm`), imported relative to the source, e.g.
`#import "../C64-Standards/include/c64_constants.asm"` from a project folder.

### Project Structure
1. **c64_lessons/**: Progressive tutorials. `lesson01`..`lesson10b` each have a `main.asm` (07/08/09/10b also `#import` their local `memorymap.asm` + `charset_1.asm`); no external dependencies. `lesson11` is the exception — no `main.asm`, just standalone `step_1_`..`step_4_` / `optimized-step4.asm` files showing incremental sprite development
2. **kickass_examples/**: The official KickAssembler example projects (scripting, PSID import, Koala import, libraries, ...)
3. **demos/**: Standalone demo sources (`demo1.asm`) plus reference `.prg`/`.d64` files that are *not* built from source. `demos/plasma/` (`main.asm`) is PLASMA: a three-layer colour plasma (16 dither chars in screen RAM on even frames, a 16-colour hue-wheel palette in colour RAM on odd frames, and a per-row `$d021` gradient from 25 raster IRQs), KERNAL banked out, no music. The 190-byte size-coded original it grew from (loads at `$0326`, starts through the CHROUT vector) is kept as an annotated appendix comment at the end of `main.asm`; it is not assembled
4. **spritemove/** (`main.asm`): 4-16 rolling checkered "Boing" ball sprites with elastic billiard-style collisions (default 8, `B`/`SHIFT+B`; past 8 a raster IRQ multiplexes them over the VIC's 8 sprites), starfield, ASCII impact sparks and SID ping SFX. It opens with a text-mode raster bar overture, then the title as sprite labels on plain black, a pause, and vertical raster bars (color-RAM columns under a screen of solid blocks) sweeping sideways while the labels float on damped springs toward random targets, joined by luminance fades, set to `Nightshift.sid`. All demo logic is in `main.asm`, heavily commented — read its header before editing. It imports seven data/sequence files, none buildable on their own: `intro.asm` (the opening sequence), `intro_raster.asm` (the overture), `intro_sprites.asm` (the label sprites and sine table; pulls in `intro_text.asm`, glyph rows from the character ROM), `music.asm` (PSID import), `sprite_gen.asm` (128 ray-shaded rolling-ball frames filling `$2000-$3fff`) and `physics_tables.asm` (quarter-square multiply tables and the collision-normal table).
   **Its code segment starts at `$4000`, not the usual `$0810`** — a PSID player is not relocatable and Nightshift loads at `$1000-$1d77`, and the 128 ball frames fill `$2000-$3fff`. The whole intro runs in bank 0 text mode on the demo's own screen; the label sprites sit at `$0c00`. It detects NTSC/PAL at start-up: the tune is held at PAL tempo on NTSC (`music_tick`) and intro phase counters use `BeatDec` so they stay on the beat
5. **scroller/** (`scroller.asm` + `scroller_intro.asm` + `scroller_data.asm`): "STARDUST" space scroller by RetroDubTRVA. It opens with a raster wipe (black, down to blue, a pause, back up to black), then has a sprite logo, a ringed planet with an orbiting moon and a ship (the same 8 sprites reused below the logo), a parallax char starfield, and a DYCP scroller over polled `$d021` copper bars, set to `Nightshift.sid`. After one pass of its scroll text, a random curtain wipe (`wipe.asm`) hands over to **ARCADE** (`arcade.asm`, `arcade_data.asm`, `arcade_sprites.asm`), a 30-second homage to Galaxian, Galaga, Asteroids and Pac-Man with a double-height scroller. Another wipe hands back, in a loop, and the music keeps playing throughout. It runs with BASIC and the KERNAL banked out (`$01=$35`); STARDUST runs on three chained raster IRQs, ARCADE on seven. The NTSC budget is tight (about 9 lines of slack), so read `scroller/CLAUDE.md` before adding per-frame work. It imports the shared standards from this repo's `C64-Standards/include/` (`c64_constants.asm`, `zeropage.asm`) as `../C64-Standards/include/...`
6. **Galactic Rasterbar/**: Reverse-engineering project. `*_disasm.asm` / `*_todd.asm` are Regenerator 2000 output in **64tass syntax** (`;` comments, `label = $xxxx`), not KickAssembler — re-export with `--assembler kick` before building with KickAss. Original binary is in `orig/`

### File Organization Pattern
```
project_directory/
├── main.asm          # Main source file
├── memorymap.asm     # Memory constants (advanced projects)
├── charset_1.asm     # Custom character sets
├── *.sid             # SID music files (lessons 10+)
├── font-project.pe   # Font editor project files
├── bin/              # Build outputs
│   ├── main.prg     # Compiled program
│   ├── buildlog.txt # Build information
│   └── *.prg-vice.log # VICE emulator test logs
```

## Repo conventions

- **RUN/STOP exits every demo** that takes over the machine: `check_exit` once per frame,
  `exit_demo` through `jmp ($fffc)` with no `cli`, and the NMI vector taken so RESTORE
  cannot warm-start BASIC. The `c64-demo-framework` skill has the reference code;
  `spritemove/main.asm` (`check_exit`, `exit_demo`, `NMI_RTI`) is the in-repo example.
- Credit every demo to **RetroDubTRVA**.
- Commit straight to `main`.

### Naming
- **Sprite Variables**: `sprite_N_property` or `fish_N_dir_x` format
- **Direction Variables**: `_dir_x` and `_dir_y` suffixes for movement vectors
- **Animation Frames**: `sprite_name_frame_N` for animation sequences
- **Step Files**: Numbered progression (step_1_, step_2_) for tutorial development


## CI/CD
There are **no GitHub Actions** (no `.github/workflows/`). The only pipeline is
`c64_lessons/azure-pipelines.yml`, inherited from the upstream course repo: it has
`trigger: none` (never runs automatically), needs a self-hosted agent pool named `Pi4`
with KickAss.jar in `/usr/local/bin`, and only builds directories containing `main.asm`
— so it covers most `c64_lessons/*` but **not** `spritemove/`, `scroller/`, `demos/` or
`lesson11/`. Its CD stage `lftp mput`s the .prg files to `/Usb0/Dev` on the Ultimate II+.

In practice builds are local only; `bin/` output is committed for several projects and
deployment to the cartridge is manual.

## Hardware Integration

- **Primary target**: Ultimate II+ cartridge
- **Emulation**: VICE emulator for testing
- **Deployment**: Manual FTP upload to `/Usb0/Dev/` on the cartridge (the Azure pipeline that automated this is disabled with `trigger: none`)
- **Testing**: Log files indicate extensive VICE emulator usage

