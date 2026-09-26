# Build current C64 project with KickAssembler

$ARGUMENTS = optional path to project directory (defaults to current project context)

Find the project's main source file. Prefer `main.asm`; if the project has no `main.asm` but exactly one top-level `.asm` file (e.g. `scroller/scroller.asm`), that file is the main source. Build with KickAssembler:

```
java -jar /Applications/KickAssembler/KickAss.jar <source>.asm -odir bin 2>&1 | tee bin/buildlog.txt | grep -vE '^//|^parsing$|^flex pass|^Output pass$|^Output dir:|^$|^ +(Music:|init |\$)'
```

The global `/Applications/KickAssembler/KickAss.cfg` is empty (no `-showmem`, no `-symbolfile`), and the grep strips the banner and pass lines, so a clean build prints only `Writing prg file: <name>.prg`; anything else printed is an error or warning. The full unfiltered output is always in `bin/buildlog.txt`. Never add `-showmem`, `-symbolfile`, `-debug` or `-bytedump` unless asked for that one build.

Output is `bin/<source>.prg` (KickAssembler names it after the source file). Do not pass `-symbolfile`.

Steps:
1. Identify which project — use $ARGUMENTS path if given, else the project in current context
2. Resolve the main source file as described above; if there are several `.asm` files and no `main.asm`, ask which one
3. Create `bin/` if it doesn't exist
4. Run KickAssembler, capture all output
5. On **success**: report the .prg output path, then ask "Run in VICE emulator? (y/n)"
   - If yes: `/Applications/vice-arm64-gtk3/bin/x64sc -autostart bin/<source>.prg`
6. On **failure**: paste full error output, identify the file + line number, explain the cause, and suggest a fix

Always show the exact commands used.
