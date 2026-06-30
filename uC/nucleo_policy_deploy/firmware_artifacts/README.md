# Firmware Artifacts

This folder is only for selected milestone firmware builds, not routine build
outputs. Keep the normal PlatformIO build products in the external build
directory.

Suggested rule:

- Commit artifacts only for important tested milestones.
- Store each milestone in a dated folder with a manifest.
- Keep both `firmware.bin` and `firmware.elf` only when the ELF is useful for
  later debugging/symbol lookup.
- Do not add every build; replace or add a new milestone only when behavior is
  worth preserving.
