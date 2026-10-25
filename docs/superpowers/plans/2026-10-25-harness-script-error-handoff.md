# Handoff: Make the Test Harness Fail on Engine Errors

## Start Here

Fix the harness before any new feature work. Nothing else is in flight; the branch is clean and pushed at `5fc4c9a`.

Context lives in the "Known gaps and defects" section of `next-features.md`. This handoff is the whole task.

## Goal

Make `tests/run_test.ps1` exit non-zero when Godot emits `SCRIPT ERROR`, so a runtime failure inside the game code can never again look like a passing suite.

`tests/test_base.gd` counts only `check()` results. A Godot `SCRIPT ERROR` prints to the log, execution continues (often skipping the rest of the method that errored), `finish()` sees zero failures, and the suite prints `RESULT: ALL PASSED`. `run_all.ps1` repeats that verdict. The exit code from Godot is 0 in that case, so nothing downstream can tell.

## Why this is urgent

Commit `427e6f8` bound the preparation panel's response from a filtered list that omits an unpaid prepared choice. `_render_preparation()` then read `choice.label` on an empty `Dictionary`:

```
SCRIPT ERROR: Invalid access to property or key 'label' on a base object of type 'Dictionary'.
   at: _render_preparation (contract_detail.gd:230)
```

Every ready-phase render of a preparation contract hit it, so the purchase button was never created — preparation was unbuyable. `test_contracts` printed the error on each render and `test_main` printed it nine times; every suite still reported `RESULT: ALL PASSED`. It survived a full green run and was only caught by a fresh reviewer reading code. Fixed in `b87c9a0`. This harness gap is the reason it shipped, and it will do it again.

## Evidence from a clean run (gathered 2026-10-25)

Run at `5fc4c9a`, all 19 suites green:

| Pattern | Count | Verdict |
|---|---|---|
| `SCRIPT ERROR` | **0** | Safe to fail on — never expected |
| `ERROR: Unable to load operator profile: ... Starting clean.` | 19 | Deliberate (invalid-profile tests) |
| `ERROR: Playback can only happen when a node is inside the scene tree` | 12 | Known harness audio noise |
| `ERROR: Unable to replace operator profile.` | 2 | Deliberate (save-failure tests) |
| `ERROR: 2 resources still in use at exit` | 2 | Known teardown noise |

So gate on `SCRIPT ERROR` alone. Do **not** gate on `ERROR:` — that would need a four-pattern whitelist and would break the deliberate failure tests.

## Required change

`tests/run_test.ps1` currently streams and forwards the exit code:

```powershell
& $godot --headless --path $project --script "res://tests/$Test.gd"
exit $LASTEXITCODE
```

Capture, replay, inspect, then exit:

```powershell
$output = & $godot --headless --path $project --script "res://tests/$Test.gd" 2>&1
$code = $LASTEXITCODE
$output | ForEach-Object { Write-Host "$_" }
$errors = @($output | ForEach-Object { "$_" } | Select-String -Pattern 'SCRIPT ERROR' -SimpleMatch)
if ($errors.Count -gt 0) {
    Write-Host "FAILED: $Test emitted $($errors.Count) script error(s)"
    exit 1
}
exit $code
```

Notes that matter:

- Read `$LASTEXITCODE` immediately after the call, before any pipeline.
- Keep replaying the captured output; `run_all.ps1` filters for `RESULT`, and humans read the `FAIL:` lines.
- Do not modify `run_all.ps1`. It already propagates `run_test.ps1`'s exit code and prints `FAILED: <suite>`.
- No allowlist mechanism yet. If a future test needs to provoke a script error on purpose, add an explicit `-AllowScriptErrors` switch then — not a pattern list.

This also catches a broken test file: a GDScript parse error surfaces as `SCRIPT ERROR: Parse Error`, which currently yields no `RESULT` line and a zero exit code.

## Verification

1. **Prove the gate.** Temporarily add a line to `scenes/modules/contracts/contract_detail.gd` that fails at runtime, e.g. `func _render_ready(...)` starting with `var probe := {}` then `probe.missing`. Run `.\tests\run_test.ps1 test_main` — expected exit 1 with `FAILED: test_main emitted N script error(s)`. Revert with `git checkout -- scenes/modules/contracts/contract_detail.gd`.
2. **Prove the aggregate.** With the same planted error, `.\tests\run_all.ps1` must print `FAILED: test_main` and exit non-zero.
3. **Prove no false positives.** After reverting, `.\tests\run_all.ps1` must print `ALL SUITES PASSED` and exit 0, with the same 4 `ERROR:` patterns and still 0 `SCRIPT ERROR`.
4. Update the README testing paragraph to state that a suite fails on a script error as well as on a failed check.

## Out of scope

- Rewriting `test_base.gd` or migrating the harness to a framework.
- Removing the known `ERROR:` noise (audio playback, teardown, deliberate profile failures).
- Any gameplay, catalog, or UI change. This is two PowerShell files and one README sentence.

## Commit boundary

One commit: `test: fail suites on engine script errors`. Include the README line. Stop after verification; do not start the venues work in the same branch.
