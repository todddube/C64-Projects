# SID and CIA Reference

## SID 6581/8580 — `$D400-$D418` (write-only except `$D419-$D41C`)

Per voice *n* (voice 1 base `$D400`, voice 2 `$D407`, voice 3 `$D40E`):

| Offset | Register | Meaning |
|---|---|---|
| +0 / +1 | FREQ lo / hi | 16-bit frequency. `Fout = FREQ * clock / 16777216` (PAL clock 985248 Hz, NTSC 1022730 Hz) |
| +2 / +3 | PW lo / hi | 12-bit pulse width; `$800` = square. Only used by the pulse waveform |
| +4 | CONTROL | bit 7 noise, 6 pulse, 5 sawtooth, 4 triangle, 3 test, 2 ring mod, 1 sync, **0 gate** |
| +5 | ATTACK/DECAY | attack in the high nibble, decay in the low nibble (0 fastest, 15 slowest) |
| +6 | SUSTAIN/RELEASE | sustain **level** high nibble, release **rate** low nibble |

| Addr | Register | Meaning |
|---|---|---|
| `$D415` | FC lo | filter cutoff, low 3 bits |
| `$D416` | FC hi | filter cutoff, high 8 bits (this is the one you sweep) |
| `$D417` | RES/FILT | resonance in the high nibble; low nibble routes voice 1/2/3 and ext into the filter (bits 0-3) |
| `$D418` | MODE/VOL | bit 7 voice 3 off, bit 6 high-pass, bit 5 band-pass, bit 4 low-pass, bits 3-0 master volume |
| `$D419/$D41A` | POTX/POTY | paddle inputs (read) |
| `$D41B` | OSC3 | voice 3 oscillator output (read) — a free random source with the noise waveform |
| `$D41C` | ENV3 | voice 3 envelope output (read) |

**Gate handling:** setting bit 0 of CONTROL starts the attack/decay/sustain phase; clearing
it starts release. To retrigger a sound cleanly, write the waveform with gate **off** first
(resets the envelope), then with gate on.

Only one waveform bit should normally be set at a time; combining them on a 6581 produces
undefined (though sometimes musically useful) output.

The 6581 and 8580 filters differ substantially — a cutoff sweep tuned on one sounds wrong on
the other. VICE models both; `x64sc` defaults to 6581.

Registers are mirrored every `$20` through `$D400-$D7FF`. Reading write-only registers
returns junk, so keep a shadow copy in RAM if you need to read-modify-write.

## CIA 1 — `$DC00-$DC0F` (keyboard, joystick, IRQ source)

| Addr | Register |
|---|---|
| `$DC00` | Port A — keyboard **row** select (write, active low) / joystick 2 |
| `$DC01` | Port B — keyboard **column** read (active low) / joystick 1 |
| `$DC02` | DDR A — set to `$FF` (output) to scan the keyboard |
| `$DC03` | DDR B — set to `$00` (input) to scan the keyboard |
| `$DC04/05` | Timer A lo/hi |
| `$DC06/07` | Timer B lo/hi |
| `$DC08-0B` | Time of day: tenths, seconds, minutes, hours |
| `$DC0D` | ICR — read: which interrupt fired (**clears on read**); write: enable/disable |
| `$DC0E/0F` | CRA / CRB — timer control |

CIA 1 generates **IRQ**. `lda #$7f : sta $dc0d` disables all its interrupt sources — do this
before installing a raster IRQ, then `lda $dc0d` to acknowledge anything pending.

### Keyboard matrix

Write a row mask (active low) to `$DC00`, read columns from `$DC01`. A **clear** bit means
pressed.

| Row (`$DC00`) | bit 7 | bit 6 | bit 5 | bit 4 | bit 3 | bit 2 | bit 1 | bit 0 |
|---|---|---|---|---|---|---|---|---|
| `$FE` (0) | CRSR ↓/↑ | F5 | F3 | F1 | F7 | CRSR →/← | RETURN | DEL |
| `$FD` (1) | L SHIFT | E | S | Z | 4 | A | W | 3 |
| `$FB` (2) | X | T | F | C | 6 | D | R | 5 |
| `$F7` (3) | V | U | H | B | 8 | G | Y | 7 |
| `$EF` (4) | N | O | K | M | 0 | J | I | 9 |
| `$DF` (5) | , | @ | : | . | - | L | P | + |
| `$BF` (6) | / | ↑ | = | R SHIFT | HOME | ; | * | £ |
| `$7F` (7) | **RUN/STOP** | Q | C= | SPACE | 2 | CTRL | ← | 1 |

The cursor keys are single keys: SHIFT decides up vs down and left vs right, so test the
shift bits (row 1 bit 7 or row 6 bit 4) as well.

**RUN/STOP = row `$7F`, bit 7** — the repo's standard demo exit key, see
`review-checklist.md`.

Restore the row select to `$FF` after scanning so a stuck row does not confuse later reads.

## CIA 2 — `$DD00-$DD0F` (serial bus, user port, VIC bank, NMI source)

| Addr | Register |
|---|---|
| `$DD00` | Port A — **bits 0-1 select the VIC bank (inverted)**, serial bus lines in bits 3-7 |
| `$DD01` | Port B — user port |
| `$DD02/03` | DDR A / DDR B — set bits 0-1 of DDR A to output before changing the bank |
| `$DD04-0F` | Timers, TOD, ICR, control — same layout as CIA 1 |

CIA 2 generates **NMI**, which cannot be masked by `sei`. Disable it with
`lda #$7f : sta $dd0d : lda $dd0d` before taking over the machine, or RUN/STOP+RESTORE will
jump into the KERNAL from under your code.

VIC bank values for `$DD00` bits 1-0: `%11` = bank 0 `$0000-$3FFF`, `%10` = bank 1
`$4000-$7FFF`, `%01` = bank 2 `$8000-$BFFF`, `%00` = bank 3 `$C000-$FFFF`. See `vic-ii.md`.
