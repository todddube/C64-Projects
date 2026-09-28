# Build current C64 project with KickAssembler

$ARGUMENTS = optional path to project directory (defaults to current project context)

Find the project's main source file. Prefer `main.asm`; if the project has no `main.asm` but exactly one top-level `.asm` file (e.g. `scroller/scroller.asm`), that file is the main source. Build with KickAssembler:

```
java -jar /Applications/KickAssembler/KickAss.jar <source>.asm -odir bin 2>&1 | tee bin/buildlog.txt | grep -vE '^//|^parsing$|^flex pass|^Output pass$|^Output dir:|^$|^ +(Music:|init |\$)'
```

`/Applications/KickAssembler/KickAss.cfg` is read automatically on every build (it sits beside `KickAss.jar`); it sets only `-libdir .`, and command-line options override it, so `-odir bin` always wins. It deliberately has no `-showmem` and no `-symbolfile`. The grep strips the banner and pass lines, so a clean build prints only `Writing prg file: <name>.prg` — plus any deliberate `.print` output from the source itself (`spritemove` prints three lines about the imported tune). Anything else is an error or warning.

If a build suddenly fails with `Inputfile '-something' doesn't exist` or `Already have an inputfile`, check that cfg first: its options take a value after a SPACE (`-libdir .`), and `-libdir=.` or `-output-dir=.` are both parsed as filenames. The full unfiltered output is always in `bin/buildlog.txt`. Never add `-showmem`, `-symbolfile`, `-debug` or `-bytedump` unless asked for that one build.

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
