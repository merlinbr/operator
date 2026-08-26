# Luna Handoff: Tier 1 Apartment Environment

## Start Here

Implement the approved plan in:

`docs/superpowers/plans/2026-08-26-tier-1-apartment-environment.md`

Read the approved design first:

`docs/superpowers/specs/2026-08-26-tier-1-apartment-environment-design.md`

The plan is authoritative for task order, exact test assertions, method names, resource paths, commands, and commit boundaries. Read both documents before modifying code.

## Goal

Replace the current procedural placeholder environment with the Tier 1 apartment artwork and make only the painted window feel alive:

```text
Tier 1 apartment art
→ window-local rain
→ faint cyan/magenta exterior spill
→ rare cold lightning
→ unchanged floating Workspace/UI above all environment effects
```

The rest state must remain almost identical to the source artwork. Effects support the workspace atmosphere; they must not compete with it.

## Non-Negotiable Rendering Facts

- Use `res://assets/tier-1-appartment.png`; its spelling is `appartment`.
- Preserve the art's 1672×941 16:9 composition. Non-16:9 viewports cover-crop; they never stretch or letterbox.
- `Main` adds `EnvironmentLayer` before `Workspace`. Preserve that sibling order.
- `EnvironmentLayer` has exactly these direct visual children, in this order:
  1. `ApartmentBackground`
  2. `WindowRain`
  3. `ExteriorLight`
  4. `Lightning`
- Every environment `Control` uses `Control.MOUSE_FILTER_IGNORE`.
- The rain shader runs only on the `WindowRain` rectangle. It must not be a full-screen shader and must not read `SCREEN_TEXTURE`.
- No environment material, overlay, or node may sample, distort, modulate, cover, or intercept `Workspace`.
- Do not add distortion/refraction. The approved design explicitly omits it because the local rain effect is sufficient and safer.
- Delete the placeholder sky, procedural skyline, neon sign, global rain, and mouse parallax. Do not keep compatibility paths.

## Required Geometry Contract

In `scenes/main/environment.gd`, retain these exact API names for contract coverage:

```gdscript
func art_rect_for(viewport_size: Vector2) -> Rect2
func window_rect_for(viewport_size: Vector2) -> Rect2
func apply_environment_layout() -> void
```

Use these constants:

```gdscript
const ART_SIZE := Vector2(1672.0, 941.0)
const WINDOW_UV_RECT := Rect2(0.555, 0.136, 0.219, 0.435)
```

Calculate the fitted artwork rectangle once per resize:

```text
scale = max(viewport_width / 1672, viewport_height / 941)
art_size = (1672, 941) * scale
art_origin = (viewport_size - art_size) / 2
```

Map all effect rectangles from normalized art coordinates through that same `art_origin` and `art_size`. A zero-size environment defers layout; it must not create invalid geometry.

## Required Behavior

### Rain

`WindowRain` is a local `ColorRect` using `res://scenes/main/rain.gdshader`. Render three sparse O(1) procedural bands: fine streaks, slower/smaller droplets, and rare longer trails. Use low alpha and a rounded local mask, so rain never leaks out of the painted pane and city detail remains visible. No particles, loops, node-per-drop work, or offscreen viewports.

### Exterior light

`ExteriorLight` contains `CyanSpill` and `MagentaSpill` gradient overlays. They are low-alpha, localized to the window-adjacent wall/floor, and drift independently over long (roughly 8–20 second) periods. Do not relight the full painting or create an external lighting system.

### Lightning

`Lightning` contains `WindowFlash`, `RoomFlash`, and nested one-shot `LightningTimer`. Seed one RNG once, schedule events in the 45–150 second range, and make an occasional second flash weaker. The direct method contract is:

```gdscript
func _trigger_lightning(strength: float = 1.0) -> void
```

It must set both flash alphas immediately, then tween them back to transparent. Keep it rare, cold, brief, and below the workspace.

## File Ownership

| File | Owns | Must not own |
|---|---|---|
| `scenes/main/environment.gd` | All environment visual nodes, resize mapping, spill alpha, lightning schedule | Workspace UI, gameplay state, weather systems |
| `scenes/main/rain.gdshader` | Rounded local mask and three O(1) rain bands | Screen sampling, refraction, full-viewport effects |
| `tests/test_environment.gd` | Geometry, direct-child order, local-rain bounds, input isolation, lightning state | Pixel-perfect appearance |
| `tests/test_main.gd` | Environment-before-workspace regression assertion | Environment implementation details |
| `scenes/main/main.gd` | Existing environment/workspace sibling order | New environment behavior |

## Execute in This Exact Order

1. **Background and geometry** — add `test_environment.gd`, establish `art_rect_for`, `window_rect_for`, `apply_environment_layout`, and replace the procedural environment with `ApartmentBackground`.
2. **Local rain** — add `WindowRain`, replace `rain.gdshader` with a local-only shader, and test that its control matches the mapped window rectangle and is smaller than the viewport.
3. **Spill and lightning** — add gradient spills plus a nested one-shot timer and deterministic `_trigger_lightning()` contract coverage.
4. **Layer protection and actual-surface check** — add child-order/UI-order assertions, run headless checks, then launch the project at 16:9 and non-16:9 sizes.

Keep the plan's red/green/commit steps intact. Do not fold tasks together or refactor unrelated shell, theme, panel, or game-state code.

## Test Commands

Run all commands through `rtk`:

```powershell
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_environment
rtk powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_test.ps1 test_main
```

After the focused tests pass, run every existing `tests/test_*.gd` script through `tests/run_test.ps1`, failing on the first nonzero exit. Then launch the actual application:

```powershell
rtk "C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe" --path "C:\Users\merli\Documents\Godot Projects\operator"
```

Manually confirm cover-crop alignment at 16:9 and non-16:9; rain stays inside the rounded window; city remains legible; spill is faint/localized; a forced lightning flash stays below the UI; and all existing workspace controls remain interactive.

## Explicitly Out of Scope

- Refraction/distortion, screen-space/post-processing, full-screen rain, particles, or weather simulation.
- Environmental audio, weather settings, accessibility/configuration menus, calibration controls, or art variants.
- Relighting the illustration, dynamic shadows, global illumination, or a lighting engine.
- Workspace redesign, panel/theme changes, gameplay/autoload/state changes, or new dependencies.

## Deliverable Standard

Do not report completion until focused and full headless tests pass and the running project has been inspected at both aspect classes. The player must see a static Tier 1 apartment at rest with restrained motion only inside and near the window; UI must remain unchanged, above the effects, and fully usable.
