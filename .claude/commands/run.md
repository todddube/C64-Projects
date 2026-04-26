# Run a C64 .prg file in VICE x64sc emulator

$ARGUMENTS = path to .prg file (required). If not given, look for a .prg in the nearest bin/ directory.

Launch the program in the VICE C64 emulator:

```
/Applications/vice-arm64-gtk3/bin/x64sc -autostart <path-to.prg>
```

Flags to know:
- `-autostart` — loads and RUNs the program automatically
- `-nativemonitor` — opens the built-in machine language monitor
- `-moncommands <file>` — runs monitor commands on startup (useful with .sym files)

Steps:
1. Resolve the .prg path from $ARGUMENTS or find bin/*.prg nearest to context
2. Run x64sc with -autostart
3. Report the PID and note that VICE opens in a separate window
4. If a matching .sym file exists alongside the .prg, mention that it can be loaded in the VICE monitor with `ll <file>.sym`
