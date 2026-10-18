# Build all C64 projects in the repository

Find every project from the repo root. A project is a directory containing `main.asm`, or a
directory with no `main.asm` but exactly one top-level `.asm` file (e.g.
`scroller/scroller.asm`). Skip `bin/`, `Libs/`, `C64-Standards/` and files that are only
`#import`ed by another file. `c64_lessons/lesson11/`, `demos/` and `Galactic Rasterbar/`
are not auto-buildable.

Build each, sequentially, with the `c64-toolchain` skill:

```
python3 ~/.claude/skills/c64-toolchain/scripts/c64.py build <dir>/<source>.asm
```

A non-zero exit status means the build failed. Then show a summary table:
Project path | Status (✓ / ✗) | Output .prg or error summary. For failures, show the full
error and identify the problem.

If *every* project fails at once, check `KickAss.cfg` beside `KickAss.jar` first (options
take a value after a space: `-libdir .`).
