# Should the c64-reviewer agents be shorter?

**Yes, by default; no, when you need a deep measured review.**

Routine reviews were taking 8-25 minutes when a static read finishes in about 5. The time
did not go into reading the code more carefully. It went into each agent writing its own
VICE remote-monitor harness, polling it with `sleep`, and fighting other agents over the
emulator. Those long runs did find real bugs: the 25 Hz frame drop, the restart corruption
and the NTSC overture overrun all came from measurement. So the fix is not "measure less".
It is "measure only when asked, with a tool that already exists".

Analysis date: 2026-10-04. Data: every subagent transcript for this project, Sep 26 to Oct 4
(`~/.claude/projects/-Users-todddube-Documents-Github-C64-Projects-spritemove/*/subagents/`).

---

## The data

13 `c64-reviewer` runs (all model: opus):

| Date | Task | Minutes | Turns | Tool calls | VICE runs | `sleep`s | Waiting on tools |
|---|---|---|---|---|---|---|---|
| 09-26 | first spritemov.asm review | 2.7 | 14 | 11 | 0 | 0 | 0.0 min |
| 09-26 | spritemov.asm vs checklist | 21.8 | 55 | 30 | 8 | 0 | 6.9 min |
| 09-26 | reworked bitmap intro | 9.8 | 58 | 34 | 10 | 0 | 1.5 min |
| 09-26 | intro follow-up | 6.1 | 35 | 20 | 0 | 0 | 0.3 min |
| 09-26 | intro third pass | 7.5 | 50 | 30 | 3 | 0 | 0.7 min |
| 09-27 | new opening sequence | 10.4 | 57 | 34 | 7 | 0 | 1.6 min |
| 09-27 | whole spritemove vs checklist | 25.0 | 96 | 60 | 14 | 0 | 3.7 min |
| 09-27 | intro_raster.asm (new) | 24.5 | 105 | 61 | 14 | 7 | 5.7 min |
| 10-04 | gfx/sprites/text + docs | 5.1 | 55 | 29 | 0 | 0 | 0.3 min |
| 10-04 | main.asm physics/effects | 7.5 | 32 | 17 | 5 | 6 | 1.2 min |
| 10-04 | main.asm core/multiplexer | 8.3 | 52 | 24 | 4 | 0 | 1.2 min |
| 10-04 | intro + intro_raster | **19.9** | **120** | 54 | 5 | **20** | **9.7 min** |
| 10-04 | review of the rewrite (diff) | 9.3 | 52 | 29 | 6 | 0 | 1.7 min |

| | Runs | Average | Range |
|---|---|---|---|
| No emulator | 3 | **4.6 min** | 2.7-6.1 |
| Ran VICE | 10 | **14.4 min** | 7.5-25.0 |
| All | 13 | 12.1 min | total 158 min |

What the numbers say:

1. **The emulator roughly triples a review**: 14.4 vs 4.6 minutes.
2. **The time is model turns, not waiting.** Only 34.5 of the 158 minutes (22%) were spent
   waiting for tool commands to finish. The rest was 838 turns at about 9 s each. The long
   runs have 96-120 turns because each agent wrote, debugged and re-ran its own one-off
   tooling: monitor clients, instrumented copies, port-collision workarounds. Every
   transcript reinvents the same harness.
3. **`sleep` polling is a marker of the worst runs.** The 19.9-minute run made 20 `sleep`
   calls and spent 9.7 minutes waiting on Bash. It also had to rename the VICE binary to
   survive another agent's `pkill x64sc`.
4. **Scope drives length too.** The two 25-minute runs had "the whole project" or a whole
   new 860-line file plus its diff. The fastest substantial run (5.1 min) had a tight
   brief and no emulator.
5. **The reference docs were not the cost.** Agents read 0-2 of them per run.
6. **Reports were long:** up to 12.5k output tokens. That costs the main session context
   more than agent time, but it adds up.

What the long runs bought, so the trade-off is honest:

- **Today's intro review (19.9 min):** confirmed the R-restart corruption with
  before/after screenshots, measured the NTSC overture overrun, and found the
  one-line logo offset.
- **Physics review (7.5 min):** measured the 25 Hz frame drop at 9 and 16 balls, which
  disproved the claim in the f1200c0 commit message.
- **Review of my rewrite (9.3 min):** proved the `$d012` equal-line latch with a test
  program.

Those are findings a static read would have rated only "plausible". **Measurement is worth
keeping; rebuilding the harness every time is not.**

---

## Changes made

### 1. A shared measurement tool: `.claude/tools/vice_peek.py` (new)

```bash
python3 .claude/tools/vice_peek.py PRG --seconds S [--pal] [--mem c000 c03f]... [--shot f.png]
```

- Runs the `.prg` in VICE to an exact emulated time and prints memory ranges and/or saves
  a screenshot. NTSC is the default.
  - Memory reads: warp to just short of the target, then normal speed, polling the CPU
    stopwatch. Measured landing within 115-165 ms of the target, in **9-12 s** of wall
    time.
  - Screenshot-only runs use `-limitcycles`, which is exact, in about 6 s.
- Picks a **free port** per run and kills **only its own** VICE process, so parallel
  agents cannot break each other.
- Replaces what each long run built from scratch. Measuring something becomes: make an
  instrumented copy that leaves its numbers in memory, then run `--mem`.

### 2. `.claude/agents/c64-reviewer.md` — review modes and a budget

New section, **"Review mode and time budget"**:

| Mode | What it does | Budget |
|---|---|---|
| **STATIC** (default when the prompt says nothing) | read, trace values, build once, no emulator | ~25 tool calls, ~5 min |
| **MEASURED** | STATIC plus VICE runs to *confirm named suspicions* or measure a named budget | ~45 tool calls, ~12 min |
| **FOLLOW-UP** | the diff since the last review only | ~15 tool calls |

Rules added to the definition:

- VICE only in MEASURED mode, and only through `vice_peek.py`.
- No `sleep` waits, no `pkill`/`killall x64sc`.
- Stay in scope: anything outside it gets one line under "Out of scope".
- Stop once findings are confirmed; a clean section gets one sentence.
- Build into the agent's **scratch directory**, never the project's `bin/`. The old text
  told it to build into `bin`, which collides with the user's and other agents' builds.
  `-showmem` is now allowed on scratch builds, because checking segment placement needs it.
- Reports capped at about 800 words: defects in full, nits one line each.

(The NTSC-first section added earlier today stays.)

### 3. `CLAUDE.md` — how to call the reviewer

Under the c64-reviewer paragraph:

- say the mode in the prompt;
- give each agent at most about 1000 lines of source;
- say "target NTSC";
- use `vice_peek.py` instead of hand-written monitor scripts.

---

## How to brief reviewers from now on

| Situation | Agents | Mode | Expected |
|---|---|---|---|
| Small change, or "did I break anything?" | 1 | FOLLOW-UP | ~3 min |
| New or rewritten file, up to ~1000 lines | 1 | STATIC | ~5 min |
| A demo misbehaves, or a timing or budget question | 1 per suspicion | MEASURED, naming the suspicion | ~10 min |
| Whole-project audit (like today's) | 3-4, one per ~1000 lines | STATIC first, then MEASURED only for what STATIC flagged as plausible | ~5 min, then ~10 for the follow-ups |

That last row is the biggest single change. Today's audit ran four reviewers at once, each
free to measure anything. The two-pass version gets the same findings and spends emulator
time only on the handful of suspicions that need proof. Estimated: today's ~40 agent-minutes
(longest 20) becomes ~20-25, with no agent over ~12.

## Not changed, and why

- **Model stays opus.** The defects found (IRQ latch timing, raster compare aliasing,
  Y-pruning invariants) are exactly where a smaller model guesses. The time problem was
  turns spent on tooling, not the model.
- **No hard turn limit.** The budgets are guidance in the prompt. A hard cut-off would stop
  an agent mid-proof and lose the finding. If the budgets are routinely ignored,
  reconsider.
- **The reference docs stay.** They are cheap (0-2 reads a run) and they are why the
  findings cite registers correctly.

## Follow-up worth doing

The profiling harnesses written today (in this session's scratchpad: `mkprof.py`,
`dupprof.sh`, `ovprof.py`) are spritemove-specific. They time the main loop or the overture
with CIA 2 timer A, read race-free. A generic version, "wrap these `jsr`s with cycle
counters, leave max/sum in `$c000+`", would let MEASURED reviews of any demo skip that step
too. Not done yet: it needs a cleaner design than the throwaway scripts.
