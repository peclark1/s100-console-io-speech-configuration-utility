# S-100 Console I/O Speech Configuration Utility

`VOICE.COM` is an interactive CP/M 2.2 utility for experimenting with and configuring the RC Systems V-Stamp / RC8660 speech synthesizer used with the S100computers Serial I/O Board V3.

The utility was developed and tested for an IMSAI 8080/S-100 system using the Serial I/O board's Z85C30 SCC channel B:

- SCC-B control port: `A0h`
- SCC-B data port: `A2h`
- 19,200 baud
- 8 data bits, no parity, 1 stop bit
- CP/M console input/output through BDOS

## Current version

**V1.2 — 2026-08-16**

V1.2 adds persistent configuration using `VOICE.CFG`.

On startup, `VOICE.COM` looks for `VOICE.CFG` in the current CP/M drive and user area. If the file is present and valid, the saved voice configuration and test phrase are automatically loaded and applied to the V-Stamp. If the file is missing or invalid, the utility safely uses factory defaults.

`VOICE.CFG` occupies one 128-byte CP/M record and includes a signature, format version, settings, test phrase, and checksum.

## Menu

```text
V=select voice   N=next voice     L=volume 0-9
P=pitch 0-99     T=tone 0-2       S=speed 0-13
E=expression 0-9 A=articulation   F=formant 0-99
R=reverb 0-9     C=set test phrase W=save configuration
D=factory defaults SPACE=test phrase Q=quit
```

### Persistence workflow

1. Adjust the voice until it sounds the way you want.
2. Optionally press `C` to replace the test phrase.
3. The status line changes to `Modified - press W to save`.
4. Press `W` to write `VOICE.CFG`.
5. The next time `VOICE.COM` starts, the saved settings are loaded and sent to the speech module automatically.

`D` restores the factory settings and original test phrase in memory. Press `W` afterward if you want the factory configuration to replace the saved configuration permanently.

## Voice presets

The utility exposes the RC8660 preset voices:

0. Perfect Paul
1. Vader
2. Big Bob
3. Precise Pete
4. Ricochet Randy
5. Biff
6. Skip
7. Robo Robert
8. Goliath
9. Alvin
10. Gretchen

Selecting a preset marks the individual parameters as `(preset)`, because the preset itself changes several internal voice parameters. If an individual setting is then overridden, that override is tracked and restored after the preset when a saved configuration is loaded.

## Files

- `VOICE.ASM` — 8080-compatible source
- `VOICE.COM` — ready-to-run CP/M executable
- `VOICE.HEX` — Intel HEX image starting at `0100h`
- `CHANGELOG.md` — version history

## Building

The source uses Intel 8080 instructions and is intended to assemble at `ORG 0100h` with a conventional CP/M-compatible 8080 assembler. If the assembler generates an Intel HEX file, use CP/M `LOAD` to create the `.COM` file.

The checked-in `VOICE.COM` is the executable produced from the checked-in V1.2 source.
