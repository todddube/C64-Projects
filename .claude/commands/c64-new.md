# Scaffold a new C64 KickAssembler project

$ARGUMENTS = project name (required). Ask if not provided.

Use the `c64-demo-framework` skill (c64-agent-kit):

1. Create `<project-name>/` at the repo root with a `bin/` folder.
2. Copy `~/.claude/skills/c64-demo-framework/templates/main.asm` to
   `<project-name>/main.asm` and replace `<name>` in its header with the project name.
   Credit the demo to RetroDubTRVA.
3. If the project wants the shared constants, `#import "../C64-Standards/include/c64_constants.asm"`
   and delete the template's duplicate labels.
4. Build and look at it:
   ```
   python3 ~/.claude/skills/c64-toolchain/scripts/c64.py build <project-name>/main.asm
   python3 ~/.claude/skills/c64-toolchain/scripts/c64.py shot <project-name>/bin/main.prg --seconds 1 --out /tmp/<project-name>.png
   ```
   The screenshot shows `NTSC` (or `PAL`) at the top left.
