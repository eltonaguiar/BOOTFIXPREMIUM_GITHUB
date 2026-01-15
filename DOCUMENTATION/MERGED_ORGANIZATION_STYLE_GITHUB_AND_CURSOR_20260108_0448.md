# MERGED ORGANIZATION STYLE GITHUB_AND_CURSOR - 20260108_0448

Purpose: unify the clean UI philosophy from Cursor with the hardened testing/documentation discipline from GitHub.

## Top-Level Structure
- `MiracleBoot.ps1` + `RunMiracleBoot.cmd`: primary entry points
- `WinRepairCore.ps1`: core engine (boot, driver, diagnostics, repair)
- `WinRepairGUI.ps1`: WPF GUI (clean layout, status bar, rich tabs)
- `WinRepairTUI.ps1`: text UI for WinRE/WinPE
- `HELPER SCRIPTS/`: supporting utilities and small helper flows
- `DOCS/` + `DOCUMENTATION/`: authoritative documentation + runbooks
- `TEST/` + `VALIDATION/`: QA gates and automated checks

## Merged UI Style
- Keep the UI visually clean, tool-driven, and predictable.
- Favor grouped action panels with simple copy and strong defaults.
- Always surface long-running progress in a status bar (elapsed time + progress).
- Avoid UI clutter by collapsing advanced options into tab sections.

## Merged Engineering Style
- Keep core logic in `WinRepairCore.ps1`, GUI should delegate.
- Prefer explicit helper functions for dangerous operations (BCD, registry, DISM).
- Add logs for every destructive action and surface safe previews.
- Preserve GitHub QA gates and validation scripts; they are non-negotiable.

## Driver & Boot Recovery Style
- Always detect missing storage/network drivers before boot fixes.
- Use hardware ID -> INF matching to reduce guesswork.
- Export driver INFs from a working PC as a first-class recovery step.
- Sync BCD to all EFI partitions after edits to reduce boot desync.

## Documentation Style
- Keep a one-page quick start + deep-dive runbooks.
- Document every new GUI action in `DOCUMENTATION/`.
- Keep a single place for known issues and release notes.

