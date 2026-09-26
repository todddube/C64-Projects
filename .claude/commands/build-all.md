# Build all C64 projects in the repository

Find every project recursively from the repo root. A project is a directory containing `main.asm`, or a directory with no `main.asm` but exactly one top-level `.asm` file (e.g. `scroller/scroller.asm`). Build each with KickAssembler:

```
java -jar /Applications/KickAssembler/KickAss.jar <source>.asm -odir bin 2>&1 | tee bin/buildlog.txt | grep -vE '^//|^parsing$|^flex pass|^Output pass$|^Output dir:|^$|^ +(Music:|init |\$)'
```

The global `/Applications/KickAssembler/KickAss.cfg` is empty (no `-showmem`, no `-symbolfile`), and the grep strips the banner and pass lines, so a clean build prints only `Writing prg file: <name>.prg`; anything else printed is an error or warning. The full unfiltered output is always in `bin/buildlog.txt`. Never add `-showmem`, `-symbolfile`, `-debug` or `-bytedump` unless asked for that one build.

Output is `bin/<source>.prg`. Do not pass `-symbolfile`.

Steps:
1. Use `find . -name "main.asm"` to locate projects, then `find . -maxdepth 2 -name "*.asm"` to catch single-file projects without a `main.asm` (skip `bin/`, `Libs/` and files that are only `#import`ed by another file)
2. For each project directory, create `bin/` if needed, then run KickAssembler
3. Collect results — show a summary table:
   - Project path | Status (✓ / ✗) | Output .prg or error summary
4. For any failures, show the full error and identify the problem

Run builds sequentially (not in parallel) so output is readable.
