# C64 6502 Code Review Checklist

The rubric the `c64-reviewer` agent works through. Ordered roughly by how often each item
is actually wrong in practice. Every finding must cite a concrete failure: which register,
which value, what the machine does instead of what was intended.

## 1. Correctness of the 6502 itself

- [ ] `clc` before the first `adc`, `sec` before the first `sbc` in every arithmetic chain.
- [ ] Multi-byte add/subtract done low byte first so carry propagates; no `inc` used where
      carry propagation is needed.
- [ ] Signed right shifts use `cmp #$80 : ror`, not `lsr`.
- [ ] `cmp`/`bcc`/`bcs` used for unsigned comparison; `bpl`/`bmi` not mistaken for one.
      Signed comparison needs `sec : sbc : bvc`-style handling or a known-small range.
- [ ] Branch targets within -128..+127 (KickAssembler reports "jump distance is too far";
      fix by inverting the test over a `jmp`).
- [ ] No `jmp ($xxFF)` — the NMOS indirect-jump page bug.
- [ ] Zero page indexing (`lda $f0,x`) wraps in page zero — check it is intended.
- [ ] `(zp),y` pointers live entirely in zero page.
- [ ] Stack balanced: every `pha`/`php` has a matching `pla`/`plp` on every path; no `rts`
      with a dirty stack.
- [ ] `cld` executed if decimal mode could be inherited.
- [ ] Registers preserved across subroutines that callers assume are transparent
      (especially routines called from inside an `ldx`-indexed loop).
- [ ] Self-modifying code is not re-entered from an IRQ between the patch and the use.

## 2. Memory and banking

- [ ] Zero page addresses used are actually free for this program: `$00/$01` never touched
      as memory, `$02-$8F` only when BASIC is not returned to, `$FB-$FE` always safe.
- [ ] `sei` before banking out the KERNAL; bits 3-5 of `$01` preserved when writing it.
- [ ] Code/data do not collide with the screen (`$0400-$07FF`), sprite pointers
      (`screen+$03F8`), I/O (`$D000-$DFFF`), or each other. Check segment `*=` addresses.
- [ ] `BasicUpstart2` programs start at `$0810` or later, not on top of the BASIC stub.
- [ ] Color RAM `$D800-$DBFF` is 4-bit — code does not rely on the upper nibble reading back.

## 3. VIC-II

- [ ] The VIC bank (`$DD00` bits 1-0, inverted, with `$DD02` bits 1-0 set to output) is set
      whenever screen/charset/bitmap/sprite data is not in the default bank 0 layout.
- [ ] No graphics data placed at `$1000-$1FFF` (bank 0) or `$9000-$9FFF` (bank 2) — the VIC
      sees the character ROM there regardless of RAM contents.
- [ ] `$D018` matches the actual screen and charset addresses *within the bank*.
- [ ] Sprite pointers written to `screen + $03F8 + n`, value = data address / 64.
- [ ] Sprite X bit 8 handled via `$D010` for X > 255.
- [ ] `$D011`/`$D016` written with sane values — DEN (bit 4 of `$D011`) set when the display
      should be visible; no invalid ECM+BMM combination.
- [ ] Collision registers `$D01E`/`$D01F` read **once** per frame into a variable; code does
      not assume they persist.
- [ ] Multicolor bit pairs map to the right registers (`01`=`$D025`, `10`=`$D027+n`,
      `11`=`$D026`) and multicolor sprites are enabled in `$D01C`.

## 4. Raster and interrupts

- [ ] Raster IRQ acknowledged by writing to `$D019` in the handler, or it re-fires forever.
- [ ] Raster bit 8 (`$D011.7`) handled for trigger lines above 255; `$D012`-only polling of
      a value below `$38` matches twice per frame on PAL.
- [ ] CIA 1 IRQs (`$DC0D`) and CIA 2 NMIs (`$DD0D`) disabled and acknowledged before taking
      over the machine.
- [ ] IRQ vector written to `$0314/$0315` (KERNAL banked in) or `$FFFE/$FFFF` (banked out) —
      matching the actual bank configuration.
- [ ] Handler ends correctly: `rti` for a raw handler, `jmp $ea31`/`$ea81` when chaining to
      the KERNAL.
- [ ] Handler preserves A/X/Y (or the entry stub does).
- [ ] Cycle budget accounts for badlines (~20 usable cycles on a badline vs 63 PAL).
- [ ] Frame-sync polling waits for the raster to *leave* the trigger line, or the loop can
      run twice in one frame.

## 5. SID

- [ ] Gate retriggered with waveform-off-then-on so the envelope restarts.
- [ ] `$D418` volume non-zero and the filter mode bits set if the filter is used.
- [ ] `$D417` low nibble routes the intended voices into the filter.
- [ ] No read-modify-write on write-only SID registers; shadow copies used instead.
- [ ] All 25 registers cleared at startup so no stale state from BASIC leaks through.

## 6. Repo conventions (`CLAUDE.md`)

- [ ] **RUN/STOP exit**: any demo that takes over the machine has a `check_exit` called once
      per frame, testing row `$7F` bit 7, and an `exit_demo` that silences the SID, clears
      `$D015`, restores `$D011` to `$1B` and `$01` to `$37`, `cli`, then `jmp ($fffc)`.
      It must **not** `rts` back to BASIC after trashing zero page.
- [ ] Keyboard scanning sets `$DC02 = $FF` and `$DC03 = $00` during setup and restores
      `$DC00 = $FF` after scanning.
- [ ] KickAssembler syntax per `kickassembler.md`: `//` comments, `.label` for constants,
      `#import` (not the deprecated `.import source`), `BasicUpstart2(main)`.
- [ ] Builds clean with the standard filtered command — one line, `Writing prg file: ...`.
      No `-showmem`/`-symbolfile`/`-debug` added by default.
- [ ] 64tass-syntax files (`Galactic Rasterbar/*_disasm.asm`) are not assumed to build with
      KickAssembler.

## Reporting

For each finding: file and line, what the code does, what the hardware/CPU actually does,
and the concrete symptom (garbage charset, IRQ lockup, silent SID, crash on exit). Separate
**confirmed defects** from **style or robustness suggestions**. Verify anything uncertain by
building — `java -jar /Applications/KickAssembler/KickAss.jar <file>.asm -odir bin` — rather
than guessing.
