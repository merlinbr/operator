# Task 1 Report: Tier 1 Apartment Background

## Implementation

- Replaced the procedural sky, skyline, neon, global rain, and mouse-parallax environment code in `scenes/main/environment.gd`.
- Added the required `ART_SIZE`, `WINDOW_UV_RECT`, and `ApartmentTexture` constants, with the texture loaded from the exact `res://assets/tier-1-appartment.png` path.
- Added `art_rect_for(viewport_size)`, `window_rect_for(viewport_size)`, and `apply_environment_layout()` using cover-crop geometry and zero/negative-size guards.
- Added the direct `ApartmentBackground` `TextureRect` with aspect-preserving cover mode and ignored mouse input.
- Kept `EnvironmentLayer` as a full-rect, pointer-ignoring `Control`; resize and deferred initial layout remain connected.

## Focused Test

Command:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File ./tests/run_test.ps1 test_environment
```

Result: `RESULT: ALL PASSED`

The focused test covers 16:9 artwork coverage, square-viewport horizontal crop, the assigned apartment texture, `STRETCH_KEEP_ASPECT_COVERED`, and pointer-input isolation. The test queues the environment for freeing.

## Self-Review

- Only the requested implementation, focused test, and report files were changed for this task.
- No procedural placeholder environment behavior or compatibility path remains.
- Geometry uses the exact required artwork dimensions and normalized window rectangle.
- The supplied apartment asset and planning-context document were preserved as uncommitted user files.
- The focused run emitted Godot anchor-size warnings caused by the prescribed test setup assigning `size` to a full-rect anchored control; there were no test failures or script errors.

## Status

Task 1 implementation is complete and ready for commit as `feat: add tier 1 apartment background`.

## Review Fix Round 1

- Moved apartment background construction into `EnvironmentLayer._ready()` and retained the deferred first layout.
- Updated the focused test to defer its run until the SceneTree is ready, then verify deferred layout, resize-signal layout, and exact applied background geometry.
- Added exact square cover-crop and mapped window-rectangle assertions, including zero and negative dimensions.
- Added texture identity/path and root input-isolation checks, plus zero-size layout safety coverage.

Focused command:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File ./tests/run_test.ps1 test_environment
```

Focused output:

```text
PASS: environment root ignores pointer input
PASS: 16:9 art occupies the viewport
PASS: background follows the fitted artwork rectangle
PASS: Tier 1 apartment texture is assigned from the required path
PASS: background uses aspect-preserving cover crop
PASS: background ignores pointer input
PASS: square viewport uses exact horizontal cover crop
PASS: window rectangle maps through cropped artwork geometry
PASS: window rectangle is empty for zero or negative dimensions
PASS: resize signal reapplies cropped background layout
PASS: zero-size layout does not create invalid background geometry
PASS: art rectangle is empty for zero or negative dimensions
RESULT: ALL PASSED
```

The run still emits only Godot anchor-size warnings caused by assigning sizes to full-rect anchored controls in the prescribed lifecycle test; no script errors or assertion failures occurred.
