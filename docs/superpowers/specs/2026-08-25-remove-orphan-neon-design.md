# Remove Orphaned Neon Accent

**Date:** 2026-08-25
**Status:** Approved

## Goal

Remove the standalone magenta light strip that no longer has a building or sign context in the environment.

## Design

In `scenes/main/environment.gd`, remove the unused `NEON_PINK` constant and the second entry in `_build_neon()`'s `specs` array. Keep the cyan accent unchanged. Do not add a replacement building, move the strip, or alter skyline, rain, parallax, or UI behavior.

## Verification

Run the existing headless test suite and launch the Godot project to confirm the environment still loads without errors and the cyan accent remains.
