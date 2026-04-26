# Build current C64 project with KickAssembler

$ARGUMENTS = optional path to project directory (defaults to current project context)

Find the nearest `main.asm`. Build with KickAssembler:

```
java -jar /Applications/KickAssembler/KickAss.jar main.asm -odir bin -o <dirname>.prg
```

Steps:
1. Identify which project — use $ARGUMENTS path if given, else find main.asm in current context
2. Create `bin/` if it doesn't exist
3. Run KickAssembler, capture all output
4. On **success**: report the .prg output path, then ask "Run in VICE emulator? (y/n)"
   - If yes: `/Applications/vice-arm64-gtk3/bin/x64sc -autostart bin/<dirname>.prg`
5. On **failure**: paste full error output, identify the file + line number, explain the cause, and suggest a fix

Always show the exact commands used.
