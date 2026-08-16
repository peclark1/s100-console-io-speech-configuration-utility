# Changelog

## V1.2 — 2026-08-16

- Added persistent configuration in `VOICE.CFG`.
- Automatically loads and applies saved settings at startup.
- Added `W` command to save the current configuration.
- Added persistent user-defined test phrase with `C`.
- Added configuration status display: factory/no file, loaded/saved, modified, save failure, or invalid configuration.
- Added signature, format version, range validation, and checksum to the configuration file.
- Preserves RC8660 preset semantics: only explicitly overridden parameters are reapplied after a preset.
- `D` now restores factory voice settings and the original test phrase; saving remains explicit.

## V1.1 — 2026-08-16

- Fixed menu command dispatch by preserving the command character across BDOS console output.
- Confirmed working on the IMSAI hardware.

## V1.0 — 2026-08-16

- Initial interactive V-Stamp / RC8660 voice laboratory.
- Added voice presets, volume, pitch, tone, speed, expression, articulation, formant, reverb, custom speech text, and test phrase.
