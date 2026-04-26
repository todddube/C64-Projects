# Build all C64 projects in the repository

Find every `main.asm` file recursively in the repo root. Build each with KickAssembler:

```
java -jar /Applications/KickAssembler/KickAss.jar main.asm -odir bin -o <dirname>.prg
```

Steps:
1. Use `find . -name "main.asm"` to locate all projects
2. For each project directory, create `bin/` if needed, then run KickAssembler
3. Collect results — show a summary table:
   - Project path | Status (✓ / ✗) | Output .prg or error summary
4. For any failures, show the full error and identify the problem

Run builds sequentially (not in parallel) so output is readable.
