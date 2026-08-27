# Luna Handoff: Terminal Boot Sequence

## Start Here

Implement the approved plan in:

`docs/superpowers/plans/2026-08-28-terminal-boot.md`

Read the approved design first:

`docs/superpowers/specs/2026-08-28-terminal-boot-design.md`

The plan is authoritative for task order, exact text, timing, input behavior, node names, test assertions, commands, and commit boundaries. Read both files before editing.

## Goal

Launch Operator through a brief, skippable in-world terminal boot scene, then route to the unchanged operations workspace:

```text
project start
→ Boot scene
→ diagnostics reveal every 0.9 seconds
→ immediate ENTER OPERATIONS / skip input
→ 0.2-second panel fade
→ existing Main scene
```

This is presentation-only. Do not initialize, inspect, save, reset, or otherwise touch gameplay state.

## Required Screen Content

Title, shown immediately:

```text
OPERATOR // LOCAL TERMINAL
```

Diagnostics, initially hidden and revealed in this exact order every **0.9 seconds**:

```text
NODE       LOWER VESPER
UPLINK     SECURE
LOCAL TIME DAY 14 // 23:41
WORK QUEUE 01 AVAILABLE
MESSAGE    MARA // UNREAD
```

Button, shown and enabled at first frame:

```text
ENTER OPERATIONS
```

The opening location/time/queue/message values are static premise copy. They must not read GameState—the project has no save system and Boot owns no gameplay state.

## Required Entry Behavior

All of these must invoke the same guarded `_enter_operations()` path:

- `ENTER OPERATIONS` button press;
- primary click on the Boot background;
- `ui_accept` (Enter/Space);
- `ui_cancel` (Escape);
- any non-echo pressed key.

The first input must:

1. reveal all hidden diagnostics;
2. stop the reveal timer;
3. set `_entering = true`;
4. emit `enter_requested` exactly once;
5. fade the centered panel to transparent over exactly **0.2 seconds**;
6. load `res://scenes/main/main.tscn`.

Every later input during the fade is a no-op. No duplicate scene transitions or errors are acceptable.

## Required Ownership

| File | Owns | Must not own |
|---|---|---|
| `scenes/boot/boot.tscn` | Full-rect Boot scene root with `boot.gd`. | Any Main or GameState behavior. |
| `scenes/boot/boot.gd` | Programmatic local layout, diagnostic Timer, input, duplicate guard, fade, and Main route. | Contracts, clock, Credits, Heat, messages, environment, save state. |
| `project.godot` | `run/main_scene="res://scenes/boot/boot.tscn"`. | Any unrelated configuration change. |
| `tests/test_boot.gd` | Headless Boot rendering/reveal/input/guard test. | Real scene transition. |
| `tests/test_smoke.gd` | Boot entry-scene initialization smoke test. | Full interaction test. |
| `README.md` | Accurate Boot/Main scene entry description and test list. | Broader documentation rewrite. |

Do not modify `Main`, GameState, contracts, environment, HUD, rail, ticker, Comms, theme, or workspace layout.

## Exact Scene Rules

- `boot.tscn` is a full-rect `Control` with `boot.gd` attached.
- In `_ready()`, load `res://resources/operator_theme.tres`, set root mouse filtering to `STOP`, build the controls, connect `enter_requested` to `_on_enter_requested`, then start the 0.9-second timer.
- Use opaque `Color(0.012, 0.020, 0.031, 1.0)` for a full-rect near-black background.
- Build one centered `PanelContainer` with `custom_minimum_size.x = 480.0`.
- Use `JetBrainsMono-Bold.ttf` at 18 px for the title. Use existing theme defaults for diagnostic labels and button.
- Names required by test: `Center`, `BootPanel`, `Content`, `Title`, `Diagnostics`, `EnterOperations`, `DiagnosticTimer`.
- Do not add art, audio, logo assets, shader effects, splash plugins, save slots, settings, quit button, cinematic, or title-menu options.

## Required Interface

```gdscript
signal enter_requested

func _reveal_next_line() -> void
func _enter_operations() -> void
func _on_enter_requested() -> void
func _on_unhandled_input(event: InputEvent) -> void
```

`_reveal_next_line()` must stop safely after five visible lines; a sixth call does nothing. `_on_enter_requested()` owns the tween and `change_scene_to_packed(MainScene)` callback. The signal connection is intentionally private so tests can disconnect it before asserting `enter_requested` without changing the headless test tree.

## Execute in This Exact Order

1. **Boot scene:** write failing `test_boot.gd`; create scene/script; implement exact layout, diagnostic reveal, input behavior, self-routing signal, and duplicate guard; run `test_boot`; commit.
2. **Entry configuration:** replace the trivial smoke test with Boot initialization coverage; set Boot as `run/main_scene`; run smoke + headless editor import; commit.
3. **Verification:** update README’s entry-scene/test-list text; run focused/full tests; manually verify all five entry paths from fresh launches; commit README.

Do not combine tasks, skip red/green checks, alter commit boundaries, or refactor unrelated code.

## Test Commands

Every shell command uses `rtk`:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_boot
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_smoke
rtk powershell -NoProfile -Command "& 'C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe' --headless --path . --editor --quit"
rtk powershell -NoProfile -Command "\$tests = 'test_boot','test_smoke','test_game_state','test_module_registry','test_theme','test_contract_catalog','test_status_chip','test_icon_rail','test_ticker_bar','test_panels_basic','test_contracts','test_main','test_environment'; foreach (\$test in \$tests) { & .\tests\run_test.ps1 \$test; if (\$LASTEXITCODE -ne 0) { exit \$LASTEXITCODE } }"
```

Tests must prove:

- exact title, five exact diagnostics, immediate enabled button, and 0.9-second repeating timer;
- diagnostics start hidden and reveal only the expected ordered prefix;
- extra reveal safely stops/no-ops;
- entry reveals all lines, stops timer, emits once, and ignores a second invocation;
- a non-echo key and `ui_accept` follow entry behavior;
- test disconnects `_on_enter_requested` before triggering entry, while production retains that connection;
- Boot builds as the configured entry-scene smoke surface;
- the existing full suite remains green.

## Manual Smoke Requirements

Launch the real project on fresh runs and verify:

1. Boot title and entry button are present immediately.
2. Diagnostics reveal at the paced 0.9-second rhythm.
3. Button click, Enter, Escape, an ordinary letter key, and background click each skip and enter the unchanged Home workspace.
4. The boot panel fades for 0.2 seconds; repeated input during that fade does nothing visibly and produces no errors.
5. Home, Status HUD, rail, Contract Network, ticker, and apartment remain exactly as before after entry.

## Explicitly Out of Scope

- Save/profile/settings/options/quit/version/update UI.
- Audio, logo art, new fonts, cinematic, loading system, splash-screen plugin, shader, or animation framework.
- GameState reads or writes; contract opening, Credits, Heat, clock, Mara, messages, or availability changes.
- Any Main, environment, HUD, workspace, navigation, theme, or gameplay-system refactor.

## Deliverable Standard

Do not report completion until focused Boot/smoke checks, headless editor import, and full suite pass; and all manual entry paths reach the unchanged operations workspace without a duplicated transition or runtime error.
