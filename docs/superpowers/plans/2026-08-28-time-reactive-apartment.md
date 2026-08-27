# Time-Reactive Apartment Atmosphere Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Crossfade the existing localized apartment atmosphere between night, pre-dawn, and daylight visual targets in response to the existing GameState clock.

**Architecture:** `Main` injects its already-resolved GameState into `EnvironmentLayer` after instantiation. `EnvironmentLayer` classifies clock minutes into one of three pure authored bands, owns the one 25-second atmosphere tween, and adjusts only its local background/rain/spill/glint/ambient-grade controls. GameState continues to own and emit time; no contract or UI behavior changes.

**Tech Stack:** Godot 4.7.1, GDScript, existing native `Control` nodes and `Tween`, existing headless `SceneTree` test harness, PowerShell.

## Global Constraints

- Exact clock bands: `night` 20:00–02:59; `pre_dawn` 03:00–05:59; `daylight` 06:00–19:59.
- Exact transition duration: 25.0 seconds. Initial setup applies immediately; same-band updates do nothing; a new band kills the existing atmosphere tween before replacing it.
- Use existing `GameState.clock_changed(day, minute_of_day)` as read-only input. Add no clock controls, timers, deadline logic, or time mutation.
- Retain exactly four direct `EnvironmentLayer` children in order: `ApartmentBackground`, `WindowRain`, `ExteriorLight`, `Lightning`.
- `AmbientGrade` is a mouse-ignored first child of `ExteriorLight`, not a direct environment child; it maps to existing `ROOM_FLASH_UV_RECT`.
- Keep all workspace/UI layers and input unaffected. Do not tint `EnvironmentLayer` root, rewrite shaders, use screen sampling, or add post-processing.
- Preserve the rare lightning timer/tween behavior independently from the atmosphere tween.
- Do not modify contracts, catalog data, Credits, Heat, Mara favor, messages, HUD, rail, ticker, Comms, theme, or workspace layout.
- Prefix every shell command with `rtk`.

---

## File Map

| File | Responsibility after this plan |
|---|---|
| `scenes/main/environment.gd` | Clock injection, pure band classification, profile constants, localized `AmbientGrade`, tween lifecycle, and time-aware spill multiplier. |
| `scenes/main/main.gd` | Supplies its resolved GameState to the already-instantiated environment. |
| `tests/test_environment.gd` | Band-boundary, local-grade, injection, transition, and existing environment regression coverage. |
| `tests/test_main.gd` | Proves Main injects GameState and an emitted clock update changes the environment without changing workspace state. |

## Runtime Interfaces

`EnvironmentLayer` adds these members:

```gdscript
func setup(gs: Node) -> void
func time_band_for(minute_of_day: int) -> StringName
func _on_clock_changed(_day: int, minute_of_day: int) -> void
func _apply_time_band(band: StringName, immediate: bool = false) -> void
```

`Main._build_shell()` calls:

```gdscript
var environment := EnvironmentScene.instantiate()
add_child(environment)
environment.setup(gs)
```

---

### Task 1: Add time-band rendering to EnvironmentLayer

**Files:**
- Modify: `scenes/main/environment.gd`
- Modify: `tests/test_environment.gd`

**Interfaces:**
- Consumes: Existing `ROOM_FLASH_UV_RECT`, art-space layout helpers, `WindowRain`, `ExteriorLight` children, existing `_process(delta)` spill animation, and injected `GameState.clock_changed` signal.
- Produces: `setup(gs)`, `time_band_for(minute_of_day)`, an exactly-one-band `_time_band`, one `_atmosphere_tween`, nested `AmbientGrade`, and three precise local profiles.

- [ ] **Step 1: Add failing time-band and local-grade tests**

In `tests/test_environment.gd`, preload GameState under the existing constants:

```gdscript
const GameStateScript := preload("res://autoload/game_state.gd")
```

After the existing `ExteriorLight` variable declaration, add the localized-grade assertions:

```gdscript
var ambient_grade: ColorRect = exterior_light.get_node("AmbientGrade")
var expected_room_grade: Rect2 = environment._art_space_rect_for(
    environment.size, environment.ROOM_FLASH_UV_RECT)
check(ambient_grade.get_index() == 0 and ambient_grade.mouse_filter == Control.MOUSE_FILTER_IGNORE,
    "ambient grade is the input-safe first exterior-light child")
check(ambient_grade.position.is_equal_approx(expected_room_grade.position)
    and ambient_grade.size.is_equal_approx(expected_room_grade.size),
    "ambient grade follows the existing room art rectangle")
check(not environment.get_children().has(ambient_grade),
    "ambient grade is nested and preserves the four direct environment layers")
```

After the existing zero-size geometry assertions and before `environment.queue_free()`, add an isolated injected-state test. It directly exercises the pure band helper, immediate targets, same-band no-op, and signal-driven transition without waiting 25 seconds:

```gdscript
var gs := GameStateScript.new()
gs.name = "TimeState"
root.add_child(gs)
check(environment.time_band_for(179) == &"night"
    and environment.time_band_for(180) == &"pre_dawn"
    and environment.time_band_for(359) == &"pre_dawn"
    and environment.time_band_for(360) == &"daylight"
    and environment.time_band_for(1199) == &"daylight"
    and environment.time_band_for(1200) == &"night",
    "time bands classify every authored boundary")
check(environment.time_band_for(-1) == &"night"
    and environment.time_band_for(1440) == &"night",
    "time bands normalize minutes into one day")

environment.size = Vector2(1920.0, 1080.0)
environment.apply_environment_layout()
environment.setup(gs)
check(environment._time_band == &"night"
    and background.modulate.is_equal_approx(Color.WHITE)
    and is_equal_approx(window_rain.modulate.a, 1.0),
    "initial GameState setup applies night targets immediately")
var same_band_tween := environment._atmosphere_tween
gs.minute_of_day = 60
gs.clock_changed.emit(gs.day, gs.minute_of_day)
check(environment._time_band == &"night" and environment._atmosphere_tween == same_band_tween,
    "clock updates inside the active band do not restart atmosphere work")

environment._apply_time_band(&"pre_dawn", true)
check(environment._time_band == &"pre_dawn"
    and background.modulate.is_equal_approx(Color(0.86, 0.91, 1.0, 1.0))
    and is_equal_approx(window_rain.modulate.a, 0.72)
    and is_equal_approx(environment._spill_multiplier, 0.65)
    and is_equal_approx(ambient_grade.color.a, 0.12),
    "pre-dawn immediate application uses all authored targets")
environment._apply_time_band(&"daylight", true)
check(environment._time_band == &"daylight"
    and background.modulate.is_equal_approx(Color(0.94, 1.0, 1.0, 1.0))
    and is_equal_approx(window_rain.modulate.a, 0.40)
    and is_equal_approx(environment._spill_multiplier, 0.30)
    and is_equal_approx(ambient_grade.color.a, 0.06),
    "daylight immediate application uses all authored targets")
gs.minute_of_day = 1200
gs.clock_changed.emit(gs.day, gs.minute_of_day)
check(environment._time_band == &"night" and environment._atmosphere_tween != null,
    "a band crossing starts the night crossfade")
if environment._atmosphere_tween != null:
    environment._atmosphere_tween.kill()
gs.queue_free()
```

- [ ] **Step 2: Run the environment test and verify it fails on the absent time-band API**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_environment
```

Expected: script compilation fails because `AmbientGrade`, `setup`, `time_band_for`, `_time_band`, `_spill_multiplier`, and `_apply_time_band` do not exist.

- [ ] **Step 3: Add profile state and build the nested AmbientGrade**

At the top of `scenes/main/environment.gd`, below the existing glint rectangle constants, add the transition/profile constants. Keep these exact values from the approved design:

```gdscript
const ATMOSPHERE_TRANSITION_SECONDS := 25.0
const ATMOSPHERE_PROFILES := {
    &"night": {
        "background": Color(1.00, 1.00, 1.00, 1.00),
        "rain_alpha": 1.00,
        "spill_multiplier": 1.00,
        "glint_alpha": 1.00,
        "ambient": Color(0.00, 0.00, 0.00, 0.00),
    },
    &"pre_dawn": {
        "background": Color(0.86, 0.91, 1.00, 1.00),
        "rain_alpha": 0.72,
        "spill_multiplier": 0.65,
        "glint_alpha": 0.55,
        "ambient": Color(0.03, 0.09, 0.17, 0.12),
    },
    &"daylight": {
        "background": Color(0.94, 1.00, 1.00, 1.00),
        "rain_alpha": 0.40,
        "spill_multiplier": 0.30,
        "glint_alpha": 0.25,
        "ambient": Color(0.18, 0.27, 0.36, 0.06),
    },
}
```

Add these fields with the existing environment node fields:

```gdscript
var _ambient_grade: ColorRect
var _gs: Node
var _atmosphere_tween: Tween
var _time_band: StringName = &""
var _spill_multiplier := 1.0
```

In `_ready()`, create `AmbientGrade` immediately after constructing `_exterior_light` and before adding spills/glints:

```gdscript
_ambient_grade = ColorRect.new()
_ambient_grade.name = "AmbientGrade"
_ambient_grade.color = Color(0.0, 0.0, 0.0, 0.0)
_ambient_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
_exterior_light.add_child(_ambient_grade)
```

The existing children follow it unchanged, so the grade remains behind all spill/glint effects. Do not add a direct `EnvironmentLayer` child.

- [ ] **Step 4: Implement clock injection, pure band classification, and tween lifecycle**

Add these methods below `_ready()`:

```gdscript
func setup(gs: Node) -> void:
    if _gs == gs:
        return
    if _gs != null and _gs.clock_changed.is_connected(_on_clock_changed):
        _gs.clock_changed.disconnect(_on_clock_changed)
    _gs = gs
    if _gs == null:
        return
    _gs.clock_changed.connect(_on_clock_changed)
    _apply_time_band(time_band_for(_gs.minute_of_day), true)

func time_band_for(minute_of_day: int) -> StringName:
    var minute := minute_of_day % 1440
    if minute < 0:
        minute += 1440
    if minute < 180 or minute >= 1200:
        return &"night"
    if minute < 360:
        return &"pre_dawn"
    return &"daylight"

func _on_clock_changed(_day: int, minute_of_day: int) -> void:
    _apply_time_band(time_band_for(minute_of_day))

func _apply_time_band(band: StringName, immediate: bool = false) -> void:
    if band == _time_band:
        return
    var profile: Dictionary = ATMOSPHERE_PROFILES[band]
    _time_band = band
    if _atmosphere_tween != null:
        _atmosphere_tween.kill()
        _atmosphere_tween = null
    var rain_modulate := Color(1.0, 1.0, 1.0, float(profile.rain_alpha))
    var glint_modulate := Color(1.0, 1.0, 1.0, float(profile.glint_alpha))
    if immediate:
        _background.modulate = profile.background
        _window_rain.modulate = rain_modulate
        _spill_multiplier = float(profile.spill_multiplier)
        _monitor_glints.modulate = glint_modulate
        _neon_glints.modulate = glint_modulate
        _kitchen_glints.modulate = glint_modulate
        _ambient_grade.color = profile.ambient
        return
    _atmosphere_tween = create_tween()
    _atmosphere_tween.set_parallel()
    _atmosphere_tween.tween_property(_background, "modulate", profile.background,
        ATMOSPHERE_TRANSITION_SECONDS)
    _atmosphere_tween.tween_property(_window_rain, "modulate", rain_modulate,
        ATMOSPHERE_TRANSITION_SECONDS)
    _atmosphere_tween.tween_property(self, "_spill_multiplier", float(profile.spill_multiplier),
        ATMOSPHERE_TRANSITION_SECONDS)
    _atmosphere_tween.tween_property(_monitor_glints, "modulate", glint_modulate,
        ATMOSPHERE_TRANSITION_SECONDS)
    _atmosphere_tween.tween_property(_neon_glints, "modulate", glint_modulate,
        ATMOSPHERE_TRANSITION_SECONDS)
    _atmosphere_tween.tween_property(_kitchen_glints, "modulate", glint_modulate,
        ATMOSPHERE_TRANSITION_SECONDS)
    _atmosphere_tween.tween_property(_ambient_grade, "color", profile.ambient,
        ATMOSPHERE_TRANSITION_SECONDS)
```

Do not call `setup()` from `_ready()`: Environment has no valid GameState reference until Main injects it.

- [ ] **Step 5: Keep spill animation time-aware and lay out AmbientGrade**

In `_process(delta)`, multiply the two existing spill alpha assignments by `_spill_multiplier`:

```gdscript
_cyan_spill.modulate.a = (0.09 + 0.02 * sin(_light_time * TAU / CYAN_PERIOD)) * _spill_multiplier
_magenta_spill.modulate.a = (0.075 + 0.018 * sin(_light_time * TAU / MAGENTA_PERIOD + 1.4)) * _spill_multiplier
```

In `apply_environment_layout()`, after deriving `room_flash_rect`, assign the same rect to the new grade before the existing room flash assignment:

```gdscript
_ambient_grade.position = room_flash_rect.position
_ambient_grade.size = room_flash_rect.size
```

Do not change window-rain, spill, glint, or lightning geometry.

- [ ] **Step 6: Run the focused environment test and verify the complete local behavior**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_environment
```

Expected: `RESULT: ALL PASSED`, including all existing crop/rain/spill/glint/lightning checks and the new exact boundaries, target values, nested grade, same-band no-op, and active-crossfade assertions.

- [ ] **Step 7: Commit EnvironmentLayer time response**

```powershell
rtk git add scenes/main/environment.gd tests/test_environment.gd
git commit -m "feat: react apartment atmosphere to clock"
```

---

### Task 2: Inject GameState from Main and protect workspace isolation

**Files:**
- Modify: `scenes/main/main.gd`
- Modify: `tests/test_main.gd`

**Interfaces:**
- Consumes: Task 1’s `Environment.setup(gs)` and `_time_band` state.
- Produces: GameState injection through Main’s existing single source of truth, with integration proof that a clock event changes environment state but not workspace state.

- [ ] **Step 1: Add failing Main injection and isolation assertions**

In `tests/test_main.gd`, after `_environment = environment` in `_run()`, add:

```gdscript
check(environment._gs == gs and environment._time_band == &"night",
    "Main injects GameState and Environment applies the initial night band")
```

After the existing initial Home/active-module checks, add and then restore a pre-dawn clock update before later contract tests begin:

```gdscript
var initial_module: StringName = gs.active_module
var initial_open: bool = gs.module_open
gs.minute_of_day = 180
gs.clock_changed.emit(gs.day, gs.minute_of_day)
check(environment._time_band == &"pre_dawn"
    and gs.active_module == initial_module and gs.module_open == initial_open
    and primary.visible,
    "clock updates change atmosphere without changing workspace state")
if environment._atmosphere_tween != null:
    environment._atmosphere_tween.kill()
gs.minute_of_day = gs.START_MINUTE
gs.day = gs.START_DAY
gs.clock_changed.emit(gs.day, gs.minute_of_day)
if environment._atmosphere_tween != null:
    environment._atmosphere_tween.kill()
```

The restoration keeps the existing contract-flow test’s clock assumptions intact. It does not need to wait for the visual tween.

- [ ] **Step 2: Run the Main test and verify it fails because Environment receives no state**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_main
```

Expected: the new assertion fails because `Main._build_shell()` creates EnvironmentLayer but does not call `environment.setup(gs)`.

- [ ] **Step 3: Inject GameState at Environment construction**

In `scenes/main/main.gd`, in `_build_shell()`, change the existing environment creation block from:

```gdscript
var environment := EnvironmentScene.instantiate()
add_child(environment)
```

to:

```gdscript
var environment := EnvironmentScene.instantiate()
add_child(environment)
environment.setup(gs)
```

Keep it before `Workspace` is created, preserving the existing render order. Do not pass GameState through any autoload lookup inside Environment.

- [ ] **Step 4: Run the Main integration test and verify workspace behavior remains intact**

Run:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_main
```

Expected: `RESULT: ALL PASSED`, including initial state injection, pre-dawn signal response, restored clock state, environment-before-workspace ordering, contract workspace flow, collapse behavior, and status HUD behavior.

- [ ] **Step 5: Commit Main environment injection**

```powershell
rtk git add scenes/main/main.gd tests/test_main.gd
git commit -m "feat: wire clock into apartment atmosphere"
```

---

### Task 3: Run final headless and visual verification

**Files:**
- Verify: `scenes/main/environment.gd`
- Verify: `scenes/main/main.gd`
- Verify: `tests/test_environment.gd`
- Verify: `tests/test_main.gd`

**Interfaces:**
- Consumes: completed localized atmosphere implementation and Main injection.
- Produces: regression proof that visual time response coexists with environment geometry, workspace behavior, and the actual game surface.

- [ ] **Step 1: Run focused environment and Main regressions**

Run:

```powershell
rtk powershell -NoProfile -Command "\$tests = 'test_environment','test_main'; foreach (\$test in \$tests) { & .\tests\run_test.ps1 \$test; if (\$LASTEXITCODE -ne 0) { exit \$LASTEXITCODE } }"
```

Expected: both scripts print `RESULT: ALL PASSED`.

- [ ] **Step 2: Run the complete existing headless suite**

Run:

```powershell
rtk powershell -NoProfile -Command "\$tests = 'test_smoke','test_game_state','test_module_registry','test_theme','test_contract_catalog','test_status_chip','test_icon_rail','test_ticker_bar','test_panels_basic','test_contracts','test_main','test_environment'; foreach (\$test in \$tests) { & .\tests\run_test.ps1 \$test; if (\$LASTEXITCODE -ne 0) { exit \$LASTEXITCODE } }"
```

Expected: every test prints `RESULT: ALL PASSED`.

- [ ] **Step 3: Launch the actual project and inspect a 25-second transition**

Run:

```powershell
rtk powershell -NoProfile -Command "& 'C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe' --path ."
```

Using a temporary debug signal or the already existing `GameState.advance_minutes()` in a local debug session, cross the clock from 02:59 to 03:00, then inspect for 25 seconds. Verify:

1. The apartment shifts gradually into the colder pre-dawn target with no visible snap.
2. Window rain, spill/glint intensity, and the room-local grade move together; lightning remains independent.
3. The StatusChip, rail, Contract Network/Detail panels, ticker, text, and pointer interaction remain unchanged and undistorted.
4. At a non-16:9 resize, local rain, ambient grade, spills, glints, and flashes still align to the cover-cropped artwork.

- [ ] **Step 4: Commit final verification marker only if verification required a tracked test correction**

If Steps 1–3 require no source/test correction, do not create an empty commit. If they expose a deterministic regression, fix it with a focused test in the owning task file, rerun Steps 1–3, then commit only the corrected files with a message describing that regression.

## Plan Self-Review

- **Spec coverage:** Task 1 implements all exact time bands, targets, immediate/crossfade lifecycle, nested grade placement, state injection boundary, same-band behavior, and independent lightning/spill behavior. Task 2 contains the sole Main production integration and proves workspace isolation. Task 3 supplies focused/full headless and actual-surface verification, including non-16:9 layout.
- **Placeholder scan:** No unfilled work markers, deferred implementation language, unspecified tests, or unspecified error handling remains.
- **Type consistency:** `setup(gs)`, `time_band_for(minute_of_day)`, `_time_band`, `_atmosphere_tween`, and `_spill_multiplier` are defined by Task 1 and consumed consistently by Task 2/tests. The profile keys used by `_apply_time_band` are `background`, `rain_alpha`, `spill_multiplier`, `glint_alpha`, and `ambient` throughout.
