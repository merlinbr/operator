# Task 4 Implementation Report

## Status

Implemented the requested module navigation, visibility, Esc handling, and labeled workspace collapse button.

## Changes

- Replaced `select_module` with state-aware module toggling and opening behavior.
- Added `_build_primary_module` to rebuild the selected primary panel and route setup through the existing panel interfaces.
- Added `close_topmost` and `_unhandled_input` so Esc closes context first, then the primary module.
- Routed `open_context` and `close_context` through unified visibility application.
- Added `_apply_visibility` with the prescribed `module_open` and `workspace_collapsed` visibility rules.
- Kept per-module close separate from global collapse. Closing a module does not change `workspace_collapsed`, and expanding does not change `module_open`.
- Updated icon rail lighting through `set_active(id, lit)` so collapsed or closed workspaces do not highlight the active module.
- Changed the collapse button label and tooltip between `Collapse Workspace` and `Expand Workspace`.
- Added the complete prescribed `test_main.gd` body covering module toggling, context priority, Esc, collapse persistence, un-collapse selection, chrome survival, and button labeling.
- Preserved the existing `_apply_layout` sizing logic for Task 5.

## TDD Evidence

### RED

The prescribed test body was installed before the implementation and run with:

```powershell
.\tests\run_test.ps1 test_main
```

The test reached the new behavior and failed as expected:

```text
FAIL: active module is home
FAIL: module starts open
FAIL: active icon toggles panel closed
FAIL: active_module stays set while closed
FAIL: clicking closed active reopens it
FAIL: active module is contracts
SCRIPT ERROR: Invalid call. Nonexistent function 'close_topmost' in base 'Control (main.gd)'.
RESULT: 6 FAILURE(S)
```

The command exited with code 1.

### GREEN

The first implementation run exposed a Godot 4.7 type-inference error for the prescribed `var was_collapsed := gs.workspace_collapsed` expression because `gs` is a dynamically resolved `Node`. The local was changed to an explicit `bool`; no behavior or interface changed.

The focused test then passed:

```powershell
.\tests\run_test.ps1 test_main
```

Relevant passing checks included:

```text
PASS: active module is home
PASS: module starts open
PASS: active icon toggles panel closed
PASS: toggle-close does not collapse workspace
PASS: active_module stays set while closed
PASS: clicking closed active reopens it
PASS: Esc closes context first
PASS: Esc closes primary next
PASS: expand preserves module_open
PASS: selecting a module un-collapses
PASS: collapse button labeled
RESULT: ALL PASSED
```

The full existing suite also passed: `test_smoke`, `test_game_state`, `test_module_registry`, `test_theme`, `test_placeholder_data`, `test_status_chip`, `test_icon_rail`, `test_ticker_bar`, `test_panels_basic`, `test_contracts`, and `test_main`. Every test reported `RESULT: ALL PASSED` and the aggregate command exited with code 0.

`git diff --check` completed without whitespace errors.

## Commit

Required commit message: `feat: module toggle, Esc, visibility and labeled collapse button`

## Concerns

The existing test runner can report `RESULT: ALL PASSED` after some Godot runtime or parse errors and does not always propagate those errors as a nonzero process exit code. The focused RED run in this task did exit nonzero; the runner was not changed because that is outside Task 4.
