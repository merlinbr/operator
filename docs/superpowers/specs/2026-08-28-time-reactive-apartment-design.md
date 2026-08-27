# Time-Reactive Apartment Atmosphere

**Date:** 2026-08-28  
**Status:** Design approved; specification review pending  
**Scope:** Make the existing apartment environment respond visually to the already-existing game clock, without changing gameplay or the workspace.

## Goal

Give scripted contract travel visible environmental consequence. As `GameState.minute_of_day` crosses an authored time band, the apartment crossfades between localized night, pre-dawn, and daylight treatments. The clock remains purely a read-only input; the feature creates no time controls, game rules, contract behavior, or simulation.

## Player Experience

The player begins at Day 14 // 23:41 with the current cool-neon night apartment. When contract travel crosses 03:00, the room gradually becomes colder and quieter. At 06:00, it eases into a faint blue-grey daylight treatment. At 20:00, it returns to the night baseline.

The first load immediately presents the correct treatment. A later band transition crossfades over 25 seconds. Small clock changes within one band do nothing. A new crossing while a fade is active cancels the prior fade and moves toward the newest target.

## Clock Bands

`EnvironmentLayer` derives exactly one band from `minute_of_day`:

| Band | Inclusive range | Treatment |
|---|---|---|
| `night` | 20:00–02:59 | Existing cool neon baseline; full local rain, spill, and glint presence. |
| `pre_dawn` | 03:00–05:59 | Colder window, subtly deeper room shadow, reduced rain/spill/glints. |
| `daylight` | 06:00–19:59 | Faint blue-grey ambient lift with subdued rain and neon. |

Boundary values are exact: 02:59 is `night`; 03:00 is `pre_dawn`; 05:59 is `pre_dawn`; 06:00 is `daylight`; 19:59 is `daylight`; 20:00 is `night`.

## Visual Model

Use the existing localized layers. Do not rewrite the rain or glint shaders and do not tint the whole `EnvironmentLayer` root.

| Visual element | Night target | Pre-dawn target | Daylight target |
|---|---:|---:|---:|
| Apartment background modulation | `Color(1.00, 1.00, 1.00, 1.00)` | `Color(0.86, 0.91, 1.00, 1.00)` | `Color(0.94, 1.00, 1.00, 1.00)` |
| Window rain alpha | `1.00` | `0.72` | `0.40` |
| Cyan/magenta spill multiplier | `1.00` | `0.65` | `0.30` |
| Monitor/neon/kitchen glint alpha | `1.00` | `0.55` | `0.25` |
| Room-local ambient grade | transparent | `Color(0.03, 0.09, 0.17, 0.12)` | `Color(0.18, 0.27, 0.36, 0.06)` |

The background/rain/glint targets tween directly. The existing spill animation remains in `_process(delta)` but multiplies its established sine-wave alpha by one tweened `_spill_multiplier`, preventing the per-frame effect from overwriting the crossfade.

### AmbientGrade

Create one `ColorRect` named `AmbientGrade` as the first child of existing `ExteriorLight`. It:

- uses `Control.MOUSE_FILTER_IGNORE`;
- is sized and positioned from the existing `ROOM_FLASH_UV_RECT` transform;
- begins transparent;
- remains below `CyanSpill`, `MagentaSpill`, and all glints;
- remains below `Workspace` because it is inside `EnvironmentLayer`.

`AmbientGrade` is intentionally nested. `EnvironmentLayer` must retain exactly four direct visual children in the existing order:

```text
ApartmentBackground
WindowRain
ExteriorLight
Lightning
```

Do not reuse `RoomFlash`: lightning owns that transient effect and must remain independent of persistent atmospheric grading.

## Architecture and Ownership

### Main

After instantiating and adding `EnvironmentLayer`, call `environment.setup(gs)`. `Main` already resolves and owns the injected `GameState`; it does not calculate time bands, make tween decisions, or alter layout.

### Environment

Add a small injected-state boundary:

```gdscript
func setup(gs: Node) -> void
func time_band_for(minute_of_day: int) -> StringName
```

`setup(gs)` stores one GameState reference, connects to `clock_changed(day, minute_of_day)`, and applies the initial band immediately. If setup receives a different state after a prior connection, disconnect the old clock callback before connecting the new one. The normal game setup path calls it exactly once.

`time_band_for` is a pure helper. It returns `night`, `pre_dawn`, or `daylight` by the exact bands above. Invalid minute values are normalized into the 0–1439 day range before classification.

`Environment` owns a single atmosphere tween. The visual-application method:

1. returns without work when the requested band is already active;
2. kills a live atmosphere tween before a new transition;
3. applies targets synchronously when called for initial setup;
4. otherwise tweens every target over exactly 25 seconds;
5. retains the existing rare lightning tween and timer separately.

`clock_changed` is only an input. No environment method changes `GameState` time or connects to contract methods.

### GameState

No production change. Continue emitting its existing `clock_changed(day, minute_of_day)` signal from `advance_minutes()`.

## Error Handling and Invariants

- An environment without injected state retains its current night visual baseline and does not error.
- A duplicate `setup(gs)` with the same state must not duplicate the signal connection.
- Replacing injected state disconnects the old listener before connecting the new one.
- A clock update inside the active band does not allocate or restart an atmosphere tween.
- A new band transition kills the old atmosphere tween; lightning flash behavior remains independent.
- Every environment visual control and `AmbientGrade` ignores pointer input.
- Environment effects never sample, tint, intercept, or otherwise affect Workspace/UI rendering.

## Tests

Extend the existing headless test harness:

1. `time_band_for()` classifies all six transition boundaries correctly and normalizes out-of-range values.
2. An environment setup at the initial GameState time applies `night` targets synchronously.
3. Emitting a same-band clock update leaves the active atmosphere tween unchanged or absent.
4. Crossing 03:00 starts a 25-second transition toward pre-dawn targets; crossing 06:00 targets daylight; crossing 20:00 targets night.
5. `AmbientGrade` is a mouse-ignored first child of `ExteriorLight`, maps to `ROOM_FLASH_UV_RECT`, and is not a direct environment child.
6. Existing four-direct-layer ordering and all lightning/rain/glint geometry tests still pass.
7. Main injects its resolved GameState into Environment; an emitted clock signal changes Environment’s active target without changing workspace state, panels, or clock values.
8. The complete existing headless suite and a manual launch confirm that panels and input remain undistorted throughout a crossfade.

## Explicit Non-Goals

- No time controls, timers that advance game time, clock pause/speed, deadline expiry, or day/night gameplay mechanics.
- No contract, catalog, Credits, Heat, Mara-favor, message, or progression changes.
- No shader rewrite, fullscreen grade, screen sampling, post-processing pipeline, or new direct child of `EnvironmentLayer`.
- No new environment art, apartment tier, weather system, audio, particle system, or configurable display settings.
- No HUD, workspace, rail, ticker, Comms, theme, or layout redesign.
