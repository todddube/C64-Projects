# STARDUST

A Commodore 64 space scroller in 6502 assembly by **RetroDubTRVA**. It has a sprite
logo, a ringed planet with a moon orbiting in front of it and behind it, a ship with a
flickering thruster and a parallax starfield. Along the bottom, a DYCP scroller rides
over copper bars, all to *Nightshift* by Agemixer. It opens with a raster wipe: black,
down to solid blue, a pause, then back up to black.

Once the scroll text has gone by, a curtain wipe closes STARDUST and **ARCADE** takes over
for 30 seconds. It is an homage to Galaxian, Galaga, Asteroids and Pac-Man:
- a swaying Galaxian formation, with a Galaga fighter and a looping bee and butterfly;
- an Asteroids ship blasting rocks;
- Pac-Man eating the dots and the power pill, then eating the ghosts;
- a double-height rainbow scroller.

Then another curtain falls and STARDUST comes back, in a loop. Each curtain picks its
direction and glow colors at random, and the music never stops.

| | |
|---|---|
| ![Start-up raster wipe](screenshots/intro-wipe.png) | ![The demo, with the credits in the scroller](screenshots/scroller-credits.png) |
| The start-up raster wipe | Credits in the DYCP scroller |
| ![Logo, planet and DYCP scroller over copper bars](screenshots/scroller.png) | ![ARCADE](screenshots/arcade.png) |
| Logo, planet and moon, DYCP scroller over copper bars | ARCADE: Galaxian, Galaga, Asteroids and Pac-Man |
| ![The curtain wipe](screenshots/curtain-wipe.png) | |
| A curtain wipe between the parts | |

Screenshots from VICE x64sc, NTSC.

Written for **KickAssembler v5.25**, targeted at **NTSC** C64s first and PAL second.

## Build and run

From this directory:

```bash
java -jar /Applications/KickAssembler/KickAss.jar scroller.asm -odir bin
x64sc -ntsc -autostart bin/scroller.prg
```

RUN/STOP resets to BASIC. Design notes, the memory map and the NTSC cycle budget are in
[`CLAUDE.md`](CLAUDE.md).
