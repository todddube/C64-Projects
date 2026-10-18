# Build current C64 project with KickAssembler

$ARGUMENTS = optional path to project directory (defaults to current project context)

Use the `c64-toolchain` skill (c64-agent-kit). Its script does the build, the output
filtering and the build log:

```
python3 ~/.claude/skills/c64-toolchain/scripts/c64.py build <project>/<source>.asm
```

Finding the source: prefer `main.asm`; if the project has no `main.asm` but exactly one
top-level `.asm` file (e.g. `scroller/scroller.asm`), that file is the main source. If
there are several and no `main.asm`, ask which one.

Output is `<project>/bin/<source>.prg`, full log in `<project>/bin/buildlog.txt`. A clean
build prints only `Writing prg file: <name>.prg` (plus any deliberate `.print` output in
the source). Never add `-showmem`, `-symbolfile`, `-vicesymbols`, `-debug` or `-bytedump`
unless asked for that one build (`--vicesymbols`, or `-- -showmem`).

On **success**: report the .prg path, then ask "Run in VICE? (y/n)"; if yes, run
`python3 ~/.claude/skills/c64-toolchain/scripts/c64.py run <prg>` (NTSC by default; add
`--pal` for the second check).

On **failure**: show the error, identify file and line, explain the cause and suggest a fix
(see the `c64-kickassembler` skill's error table).
