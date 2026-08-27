# Luna Handoff: Time-Reactive Apartment Atmosphere

## Start Here

Implement the approved plan in:

`docs/superpowers/plans/2026-08-28-time-reactive-apartment.md`

Read the approved design first:

`docs/superpowers/specs/2026-08-28-time-reactive-apartment-design.md`

The implementation plan is authoritative for task order, exact target values, method names, test assertions, commands, and commit boundaries. Read both documents before modifying code.

## Goal

Make the existing apartment atmosphere crossfade in response to the already-existing GameState clock:

```text
20:00–02:59  NIGHT
03:00–05:59  PRE-DAWN
06:00–19:59  DAYLIGHT
20:00        return to NIGHT
```

Initial setup applies its band immediately. A later band crossing uses one **25.0-second** crossfade. An update inside the active band does nothing. A newer crossing kills the prior atmosphere tween and targets the newest band.

This is an environmental presentation feature only. It must not change time, contracts, Credits, Heat, Mara favor, messages, availability, or workspace behavior.

## Required Architecture

| Owner | Required work | Must not own |
|---|---|---|
| `Main` | After instantiating and adding EnvironmentLayer, call `environment.setup(gs)` with its already-resolved GameState. | Time-band calculation, tween logic, gameplay state. |
| `EnvironmentLayer` | Clock subscription, pure band classification, target profiles, nested grade, one atmosphere tween, local visual updates. | GameState time mutation, UI/workspace behavior, contract behavior. |
| `GameState` | Existing `clock_changed(day, minute_of_day)` signal only. | Any production change for this feature. |

Keep GameState injection. Environment must not find `/root/GameState` itself.

## Non-Negotiable Rendering Rules

### Direct child hierarchy

`EnvironmentLayer` retains exactly four direct visual children, in this order:

```text
ApartmentBackground
WindowRain
ExteriorLight
Lightning
```

Create `AmbientGrade` as the **first child** of existing `ExteriorLight`—never as a direct EnvironmentLayer child. It is a mouse-ignored `ColorRect`, uses the existing `ROOM_FLASH_UV_RECT` layout mapping, and stays below spills/glints and below Workspace.

Do not reuse `RoomFlash`; lightning remains a separate transient effect.

### Exact target profiles

| Element | Night | Pre-dawn | Daylight |
|---|---:|---:|---:|
| Background modulation | `Color(1.00, 1.00, 1.00, 1.00)` | `Color(0.86, 0.91, 1.00, 1.00)` | `Color(0.94, 1.00, 1.00, 1.00)` |
| WindowRain alpha | `1.00` | `0.72` | `0.40` |
| Cyan/magenta spill multiplier | `1.00` | `0.65` | `0.30` |
| Monitor/neon/kitchen glint alpha | `1.00` | `0.55` | `0.25` |
| AmbientGrade color | transparent | `Color(0.03, 0.09, 0.17, 0.12)` | `Color(0.18, 0.27, 0.36, 0.06)` |

Keep rain and glint shaders unchanged. Do not tint the `EnvironmentLayer` root, rewrite shaders, use screen sampling/post-processing, or add a global overlay.

The existing spill sine animation in `_process(delta)` must multiply both alpha values by one tweened `_spill_multiplier`; otherwise `_process` will overwrite the crossfade’s spill target every frame.

## Required Environment Interface

Add exactly these methods and state to `scenes/main/environment.gd`:

```gdscript
func setup(gs: Node) -> void
func time_band_for(minute_of_day: int) -> StringName
func _on_clock_changed(_day: int, minute_of_day: int) -> void
func _apply_time_band(band: StringName, immediate: bool = false) -> void

var _gs: Node
var _ambient_grade: ColorRect
var _atmosphere_tween: Tween
var _time_band: StringName = &""
var _spill_multiplier := 1.0
```

`time_band_for()` must normalize invalid minute values into the 0–1439 range and classify exact boundaries:

- 02:59 (`179`) → `night`
- 03:00 (`180`) → `pre_dawn`
- 05:59 (`359`) → `pre_dawn`
- 06:00 (`360`) → `daylight`
- 19:59 (`1199`) → `daylight`
- 20:00 (`1200`) → `night`

`setup(gs)` connects once, disconnects a prior different GameState listener before replacement, and applies the received state’s initial band synchronously. It must not be called from `_ready()`; Main calls it once it has the resolved GameState.

`_apply_time_band()` returns immediately for the current band, kills a live atmosphere tween before a new transition, then either applies all profile targets synchronously or tweens all targets in parallel over exactly 25 seconds. Its tween is distinct from the existing lightning tween.

## Execute in This Exact Order

1. **Environment behavior and tests:** add failing boundary/local-grade/crossfade tests; add profiles, AmbientGrade, state injection, band classification, tween lifecycle, spill multiplier, and grade layout; run `test_environment`; commit.
2. **Main injection and integration:** add failing injection/workspace-isolation assertions; call `environment.setup(gs)` after adding EnvironmentLayer; run `test_main`; commit.
3. **Final verification:** run focused and full suites; launch the real project; force/test an 02:59 → 03:00 crossing, wait 25 seconds, verify the gradual localized transition and a non-16:9 resize.

Do not fold tasks, skip red/green checks, change commit boundaries, or refactor unrelated systems.

## Test Commands

Run every shell command through `rtk`:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_environment
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_main
rtk powershell -NoProfile -Command "\$tests = 'test_smoke','test_game_state','test_module_registry','test_theme','test_contract_catalog','test_status_chip','test_icon_rail','test_ticker_bar','test_panels_basic','test_contracts','test_main','test_environment'; foreach (\$test in \$tests) { & .\tests\run_test.ps1 \$test; if (\$LASTEXITCODE -ne 0) { exit \$LASTEXITCODE } }"
```

Required tests prove:

- exact band boundaries and invalid-minute normalization;
- immediate initial Night application;
- same-band updates do not restart a tween;
- a crossing starts an atmosphere tween toward its new profile;
- AmbientGrade is first under ExteriorLight, mouse-ignored, room-rect aligned, and not direct;
- existing four direct-layer order, crop/rain/spill/glint/lightning tests remain green;
- Main passes GameState to Environment and a clock update changes only environment state, not workspace state, active module, visibility, or contracts.

## Explicitly Out of Scope

- Time controls, time-advance timers, pause/speed, deadline expiry, or day/night mechanics.
- Contract/catalog/gameplay changes, Credits, Heat, Mara favor, messages, or unlock changes.
- Shader rewrites, fullscreen grade, post-processing, screen sampling, new art, weather systems, particles, audio, display settings, or apartment tiers.
- HUD, rail, panels, ticker, Comms, theme, workspace layout, or input changes.

## Deliverable Standard

Do not report completion until `test_environment`, `test_main`, and the complete headless suite pass; and the running project has shown an actual 25-second 02:59 → 03:00 crossfade plus a non-16:9 resize. The workspace must remain visually and interactively untouched throughout.
