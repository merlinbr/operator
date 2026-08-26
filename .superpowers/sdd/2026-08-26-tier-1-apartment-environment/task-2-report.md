# Task 2 Report: Strictly Local Window Rain Layer

## Implementation

- Added a preloaded `RainShader` resource and constructed exactly one direct `WindowRain` `ColorRect` after `ApartmentBackground` in `scenes/main/environment.gd`.
- Configured `WindowRain` with a `ShaderMaterial`, `res://scenes/main/rain.gdshader`, and `Control.MOUSE_FILTER_IGNORE`.
- Extended `apply_environment_layout()` so valid layouts map `WindowRain` position and size from `window_rect_for(size)`, while retaining the existing zero/negative-size early return.
- Replaced the previous global rain shader with a local-UV `canvas_item` shader containing exactly three direct `rain_band()` calls. Each band uses scalar per-column hashing for phase, speed, and length, with no loops, screen sampling, viewport coordinates, particles, or offscreen rendering.
- Added an actual rounded-box SDF mask around the local window before assigning output color; cumulative rain alpha remains low for apartment detail legibility.

## Focused Test

Command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./tests/run_test.ps1 test_environment
```

Result: `RESULT: ALL PASSED`

The focused test preserved all Task 1 assertions and now verifies the `WindowRain` type, mapped 16:9 geometry, `ShaderMaterial`, pointer-input isolation, viewport-relative size, and mapped geometry after applying a `1000x1000` non-16:9 layout. The run emitted only the existing Godot anchor-size warnings from the prescribed test setup; there were no shader, script, or assertion failures.

## Godot Import Check

Command:

```powershell
C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe --headless --path . --editor --quit
```

Result: completed successfully after filesystem scan, script class registration, and editor initialization; no import or shader errors were emitted.

## Self-Review

- Only the requested Task 2 source/test/report files were changed; unrelated user files remain untouched.
- `ApartmentBackground` remains the first direct child and `WindowRain` is the only second direct child.
- The rain shader is local-only and O(1): it uses only `UV`, `TIME`, scalar math/hash operations, exactly three procedural band calls, and no loops or screen texture access.
- The mask uses rounded-box SDF geometry rather than a square edge inset.
- Existing Task 1 geometry behavior and zero/negative-size safety remain intact.

## Status

Task 2 implementation, focused verification, headless editor/import verification, and self-review are complete. Commit subject: `feat: localize rain to apartment window`.
