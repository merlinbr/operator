# Task 4 Report: Protect Main Layering and Verification Coverage

## Status

Task 4 test changes are complete. No production files were modified.

## Commit

- Subject: `test: protect apartment environment layering`
- The final commit contains the two focused test updates and this report.

## Changes

- Updated `tests/test_main.gd` to resolve `EnvironmentLayer`, assert it renders before `Workspace`, and assert the final environment has exactly four direct visual layers after the SceneTree lifecycle completes.
- Preserved all existing Main lifecycle, workspace, module, contract, collapse, and HUD assertions.
- Updated `tests/test_environment.gd` to preserve the existing direct-layer checks while asserting the exact ordered names `ApartmentBackground`, `WindowRain`, `ExteriorLight`, and `Lightning`.
- Added an exact `ShaderMaterial.shader.resource_path` assertion for `res://scenes/main/rain.gdshader`.
- Retained input-ignore assertions for the environment root, direct visual layers, spill overlays, lightning flashes, and `WindowRain`.

## Focused Test Summary

Commands run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./tests/run_test.ps1 test_environment
powershell -NoProfile -ExecutionPolicy Bypass -File ./tests/run_test.ps1 test_main
```

Results:

- `test_environment`: `RESULT: ALL PASSED`
- `test_main`: `RESULT: ALL PASSED`

The environment test emitted only the existing anchor-size warnings from its prescribed layout setup. No assertion, script, resource, or production behavior failures occurred.

## Self-Review

- Only `tests/test_main.gd`, `tests/test_environment.gd`, and this report are in scope.
- `scenes/main/main.gd`, `scenes/main/environment.gd`, `scenes/main/rain.gdshader`, scenes, UI, theme, gameplay, and unrelated tests were not modified.
- Existing assertions and asynchronous environment lifecycle coverage were retained.
- Main's test-only deferred completion lets the environment child `_ready` lifecycle settle before checking the four-child count, while preserving the prior synchronous Main assertions.

## Concerns

- None. The controller should run the required full headless suite and actual application smoke check after review.

## Report Path

`.superpowers/sdd/2026-08-26-tier-1-apartment-environment/task-4-report.md`
