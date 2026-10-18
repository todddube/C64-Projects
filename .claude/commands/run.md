# Run a C64 .prg file in VICE x64sc emulator

$ARGUMENTS = path to .prg file (required). If not given, look for a .prg in the nearest bin/ directory.

```
python3 ~/.claude/skills/c64-toolchain/scripts/c64.py run <path-to.prg>          # NTSC (this repo's default)
python3 ~/.claude/skills/c64-toolchain/scripts/c64.py run <path-to.prg> --pal    # PAL check
```

It launches VICE detached with `-autostart` and logs to `<prg>-vice.log`. Report the PID
it prints and note that VICE opens in its own window. To see a frame without watching, use
`c64.py shot <prg> --seconds S --out file.png` instead.
