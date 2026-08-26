# Tier 1 Apartment Environment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the placeholder environment with the Tier 1 apartment art and add local-window rain, subtle exterior light, and rare lightning behind the workspace.

**Architecture:** `EnvironmentLayer` remains the first child of `Main`; `Workspace` remains its later sibling. The environment script builds exactly four direct visual children—background, local rain, exterior light, and lightning—and derives each effect rectangle from the same normalized artwork transform used by the cover-cropped background. The only shader runs in the window-sized rain control; light and lightning are transparent overlays below the UI.

**Tech Stack:** Godot 4.7.1, GDScript, `canvas_item` shader, Godot headless test harness, PowerShell.

## Global Constraints

- Use `res://assets/tier-1-appartment.png` as the background texture; preserve its 1672×941 (16:9) composition.
- Use cover-crop behavior at non-16:9 sizes: `scale = max(viewport_width / 1672, viewport_height / 941)`.
- Keep `EnvironmentLayer` before `Workspace`; environment code and materials MUST NOT affect, sample, or intercept UI rendering/input.
- `EnvironmentLayer` has exactly four direct visual children, in order: `ApartmentBackground`, `WindowRain`, `ExteriorLight`, `Lightning`.
- Every environment control uses `Control.MOUSE_FILTER_IGNORE`.
- Keep rain strictly window-local. Do not use a full-screen weather shader, particles, per-drop nodes, offscreen viewports, or per-frame allocations.
- Use the calibrated window pane `Rect2(0.555, 0.136, 0.219, 0.435)` in normalized artwork coordinates.
- Omit distortion/refraction. Add it only in later work if it remains a single local pass and is imperceptible at rest.
- Verify with `C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe` through `tests/run_test.ps1` and by launching the actual project.

---

## File Structure

- `scenes/main/environment.gd` — owns the four environment layers, normalized layout helpers, color spill animation, and lightning scheduling.
- `scenes/main/rain.gdshader` — renders the local window rain mask and three O(1) procedural rain bands; never samples the screen.
- `tests/test_environment.gd` — new deterministic environment unit/contract coverage for geometry, child structure, input isolation, and lightning state.
- `tests/test_main.gd` — adds the cross-sibling rendering-order assertion that protects workspace/UI isolation.

`scenes/main/environment.tscn` remains the existing full-rect script host. `scenes/main/main.gd` already instantiates `EnvironmentLayer` before it creates `Workspace`, so it needs no production change.

---

### Task 1: Replace Placeholder with Cover-Cropped Apartment Background

**Files:**
- Modify: `scenes/main/environment.gd`
- Create: `tests/test_environment.gd`

**Interfaces:**
- Consumes: `EnvironmentLayer` root from `scenes/main/environment.tscn`; `res://assets/tier-1-appartment.png`.
- Produces: `func art_rect_for(viewport_size: Vector2) -> Rect2`, `func window_rect_for(viewport_size: Vector2) -> Rect2`, `func apply_environment_layout() -> void`, and direct child `ApartmentBackground`.

- [ ] **Step 1: Write the failing geometry/background test**

Create `tests/test_environment.gd` with the harness and the following initial contract:

```gdscript
extends "res://tests/test_base.gd"

const EnvironmentScene := preload("res://scenes/main/environment.tscn")

func _run() -> void:
	var environment: Control = EnvironmentScene.instantiate()
	root.add_child(environment)
	environment.size = Vector2(1920.0, 1080.0)
	environment.apply_environment_layout()

	var art_16x9: Rect2 = environment.art_rect_for(Vector2(1920.0, 1080.0))
	check(art_16x9.position == Vector2.ZERO and art_16x9.size == Vector2(1920.0, 1080.0),
		"16:9 art occupies the viewport")
	var art_square: Rect2 = environment.art_rect_for(Vector2(1000.0, 1000.0))
	check(is_equal_approx(art_square.size.y, 1000.0) and art_square.size.x > 1000.0,
		"non-16:9 viewport crops covered artwork horizontally")

	var background: TextureRect = environment.get_node("ApartmentBackground")
	check(background.texture != null, "Tier 1 apartment texture is assigned")
	check(background.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED,
		"background uses aspect-preserving cover crop")
	check(background.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"background ignores pointer input")

	environment.queue_free()
```

- [ ] **Step 2: Run the focused test and confirm it fails**

Run:

```powershell
.\tests\run_test.ps1 test_environment
```

Expected: script compilation fails because `art_rect_for()` and `apply_environment_layout()` do not exist, and/or `ApartmentBackground` is absent.

- [ ] **Step 3: Replace the placeholder environment with the minimal background/layout implementation**

Replace the procedural skyline, neon, global-rain, and parallax fields/methods in `scenes/main/environment.gd`. Keep `extends Control`; add these constants and fields:

```gdscript
const ART_SIZE := Vector2(1672.0, 941.0)
const WINDOW_UV_RECT := Rect2(0.555, 0.136, 0.219, 0.435)
const ApartmentTexture := preload("res://assets/tier-1-appartment.png")

var _background: TextureRect
```

Build only the background in `_ready`, connect `resized` to `apply_environment_layout`, and defer one layout frame exactly as the current script does. Use this geometry contract:

```gdscript
func art_rect_for(viewport_size: Vector2) -> Rect2:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return Rect2()
	var scale := maxf(viewport_size.x / ART_SIZE.x, viewport_size.y / ART_SIZE.y)
	var art_size := ART_SIZE * scale
	return Rect2((viewport_size - art_size) * 0.5, art_size)

func window_rect_for(viewport_size: Vector2) -> Rect2:
	var art_rect := art_rect_for(viewport_size)
	return Rect2(
		art_rect.position + Vector2(
			art_rect.size.x * WINDOW_UV_RECT.position.x,
			art_rect.size.y * WINDOW_UV_RECT.position.y),
		Vector2(
			art_rect.size.x * WINDOW_UV_RECT.size.x,
			art_rect.size.y * WINDOW_UV_RECT.size.y))
```

`ApartmentBackground` is a full-rect `TextureRect` with `texture = ApartmentTexture`, `stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED`, and ignored mouse input. `apply_environment_layout()` must return without doing layout when `size` is zero; this first task only uses it to establish the stable API for later layers.

- [ ] **Step 4: Run the focused test and confirm it passes**

Run:

```powershell
.\tests\run_test.ps1 test_environment
```

Expected: `RESULT: ALL PASSED`; the background is the Tier 1 texture and both geometry assertions pass.

- [ ] **Step 5: Commit the background replacement**

```powershell
git add scenes/main/environment.gd tests/test_environment.gd
git commit -m "feat: add tier 1 apartment background"
```

### Task 2: Add the Strictly Local Window Rain Layer

**Files:**
- Modify: `scenes/main/environment.gd`
- Modify: `scenes/main/rain.gdshader`
- Modify: `tests/test_environment.gd`

**Interfaces:**
- Consumes: `window_rect_for(viewport_size)` and `apply_environment_layout()` from Task 1.
- Produces: direct child `WindowRain: ColorRect`, using `res://scenes/main/rain.gdshader`; `apply_environment_layout()` positions and sizes it to the calibrated window rectangle.

- [ ] **Step 1: Extend the failing environment test for local rain**

Append this test content after the background checks in `tests/test_environment.gd`:

```gdscript
	var window_rect: Rect2 = environment.window_rect_for(environment.size)
	var rain: ColorRect = environment.get_node("WindowRain")
	check(rain.position.is_equal_approx(window_rect.position)
		and rain.size.is_equal_approx(window_rect.size),
		"rain rectangle tracks the painted window")
	check(rain.material is ShaderMaterial, "rain uses a local shader material")
	check(rain.mouse_filter == Control.MOUSE_FILTER_IGNORE, "rain ignores pointer input")
	check(rain.size.x < environment.size.x and rain.size.y < environment.size.y,
		"rain shader is not a full-screen control")
```

- [ ] **Step 2: Run the focused test and confirm it fails**

Run:

```powershell
.\tests\run_test.ps1 test_environment
```

Expected: failure because `WindowRain` does not exist.

- [ ] **Step 3: Build the local rain node and replace the global shader**

In `environment.gd`, preload the shader and build `WindowRain` after `ApartmentBackground`:

```gdscript
const WindowRainShader := preload("res://scenes/main/rain.gdshader")

func _build_window_rain() -> void:
	var rain := ColorRect.new()
	rain.name = "WindowRain"
	rain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = WindowRainShader
	rain.material = material
	add_child(rain)
```

Store the node in `_window_rain`, and update its `position` and `size` from `window_rect_for(size)` inside `apply_environment_layout()`.

Replace `rain.gdshader` with a `canvas_item` shader that evaluates exactly three local-UV O(1) rain bands: fine streaks, slower droplets, and rare longer trails. Reuse a scalar hash and a per-column `rain_layer` helper; include no loops, `SCREEN_TEXTURE`, `BackBufferCopy`, refraction, or global UV coordinate. Multiply the summed alpha by a rounded-rectangle local mask before output:

```glsl
float rounded_rect_mask(vec2 uv, float radius) {
	vec2 edge = min(uv, 1.0 - uv);
	float corner = min(edge.x, edge.y);
	return smoothstep(0.0, 0.012, corner - radius + 0.012);
}

void fragment() {
	float alpha = 0.0;
	alpha += rain_layer(UV, 150.0, 1.15, 0.070, 0.025, 0.050, 0.10, 1.0);
	alpha += rain_layer(UV, 225.0, 0.72, 0.035, 0.018, 0.030, 0.06, 7.0);
	alpha += rain_layer(UV, 90.0, 0.42, 0.110, 0.050, 0.075, 0.045, 13.0);
	COLOR = vec4(0.72, 0.86, 1.0, alpha * rounded_rect_mask(UV, 0.035));
}
```

Define `rain_layer` with parameters matching the calls above: `uv`, density, speed, base/variable length, alpha, and seed. Per-column hashing must vary phase, speed, and length. Keep summed alpha restrained so the city remains clear.

- [ ] **Step 4: Run the focused test and shader import check**

Run:

```powershell
.\tests\run_test.ps1 test_environment
& "C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe" --headless --path "C:\Users\merli\Documents\Godot Projects\operator" --editor --quit
```

Expected: the test reports `RESULT: ALL PASSED`; the editor import pass exits without shader parse errors.

- [ ] **Step 5: Commit local rain**

```powershell
git add scenes/main/environment.gd scenes/main/rain.gdshader tests/test_environment.gd
git commit -m "feat: localize rain to apartment window"
```

### Task 3: Add Restrained Exterior Spill and Rare Lightning

**Files:**
- Modify: `scenes/main/environment.gd`
- Modify: `tests/test_environment.gd`

**Interfaces:**
- Consumes: normalized art layout, `WindowRain`, and `apply_environment_layout()` from Tasks 1–2.
- Produces: direct children `ExteriorLight` and `Lightning`; `func _trigger_lightning(strength: float = 1.0) -> void` for deterministic contract coverage; one-shot child timer `Lightning/LightningTimer`.

- [ ] **Step 1: Extend the test with spill and lightning contracts**

Append these checks after the rain checks:

```gdscript
	var exterior_light: Control = environment.get_node("ExteriorLight")
	check(exterior_light.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"exterior light ignores pointer input")
	check(exterior_light.get_node("CyanSpill") is TextureRect
		and exterior_light.get_node("MagentaSpill") is TextureRect,
		"exterior light has both colored spill overlays")

	var lightning: Control = environment.get_node("Lightning")
	var lightning_timer: Timer = lightning.get_node("LightningTimer")
	check(lightning.mouse_filter == Control.MOUSE_FILTER_IGNORE and lightning_timer.one_shot,
		"lightning is input-safe and scheduled by a one-shot timer")
	environment._trigger_lightning()
	check(lightning.get_node("WindowFlash").modulate.a > 0.0
		and lightning.get_node("RoomFlash").modulate.a > 0.0,
		"triggered lightning starts local window and room flashes")
```

- [ ] **Step 2: Run the focused test and confirm it fails**

Run:

```powershell
.\tests\run_test.ps1 test_environment
```

Expected: failure because `ExteriorLight` and `Lightning` are absent.

- [ ] **Step 3: Implement gradient spill and lightning lifecycle without full-screen shaders**

Build `ExteriorLight` after `WindowRain`. Create `CyanSpill` and `MagentaSpill` as child `TextureRect`s backed by `GradientTexture2D` resources. For each gradient, use `GradientTexture2D.FILL_RADIAL`, a solid colored center with transparent edge, `STRETCH_SCALE`, and ignored mouse input. Position the spill overlays from normalized art-space rectangles that cover only the window-adjacent wall/floor area; do not create a full-viewport lighting overlay.

Advance only existing scalar time in `_process(delta)` and set the child alpha with distinct slow sine periods, for example:

```gdscript
_light_time += delta
_cyan_spill.modulate.a = lerpf(0.025, 0.065, 0.5 + 0.5 * sin(_light_time * TAU / 13.0))
_magenta_spill.modulate.a = lerpf(0.020, 0.055, 0.5 + 0.5 * sin(_light_time * TAU / 19.0 + 1.7))
```

Build `Lightning` after `ExteriorLight`. It contains a window-sized `WindowFlash`, a conservative cold `RoomFlash` sized to the art-space apartment area, and a one-shot `LightningTimer`. Both flashes begin fully transparent, ignore input, and remain under `Workspace` because their parent is `EnvironmentLayer`.

Seed one `RandomNumberGenerator` once in `_ready`. Start the timer with `randf_range(45.0, 150.0)`. On timeout, call `_trigger_lightning()`, schedule the next interval immediately, and use a random branch for a weaker second invocation after `await get_tree().create_timer(0.18).timeout`. `_trigger_lightning()` must set both initial alpha values immediately, kill a prior flash tween if live, then tween both `modulate:a` values to `0.0` over a short natural decay. Do not allocate nodes or gradients from `_process`.

- [ ] **Step 4: Run the focused environment test**

Run:

```powershell
.\tests\run_test.ps1 test_environment
```

Expected: `RESULT: ALL PASSED`; direct-node contracts verify low-level layer composition and immediate flash state.

- [ ] **Step 5: Commit exterior lighting and lightning**

```powershell
git add scenes/main/environment.gd tests/test_environment.gd
git commit -m "feat: animate apartment exterior lighting"
```

### Task 4: Protect Main Layering and Verify the Real Surface

**Files:**
- Modify: `tests/test_main.gd`
- Modify: `tests/test_environment.gd`

**Interfaces:**
- Consumes: the finalized `EnvironmentLayer` hierarchy and existing `Main._build_shell()` ordering.
- Produces: regression coverage that environment effects remain below `Workspace`, plus the verified interactive game surface.

- [ ] **Step 1: Add the failing main-layering assertion**

Immediately after `workspace` is resolved in `tests/test_main.gd`, add:

```gdscript
	var environment: Control = main.get_node("EnvironmentLayer")
	check(main.get_children().find(environment) < main.get_children().find(workspace),
		"environment renders before the workspace UI")
	check(environment.get_child_count() == 4, "environment has four visual layers")
```

Add the ordered-name assertion to `tests/test_environment.gd`:

```gdscript
	var layer_names: Array[StringName] = []
	for child in environment.get_children():
		layer_names.append(child.name)
	check(layer_names == [&"ApartmentBackground", &"WindowRain", &"ExteriorLight", &"Lightning"],
		"environment visual layers keep their rendering order")
```

- [ ] **Step 2: Run the new layer-protection tests**

Run:

```powershell
.\tests\run_test.ps1 test_environment
.\tests\run_test.ps1 test_main
```

Expected: both scripts print `RESULT: ALL PASSED`. The production hierarchy was created in Tasks 1–3; these assertions now lock its order against regressions.

- [ ] **Step 3: Verify the protected hierarchy and rerun headless checks**

Ensure `environment.gd` adds no direct visual child beyond the four specified layers. Keep `LightningTimer` nested under `Lightning`, not under `EnvironmentLayer`. Ensure `Main._build_shell()` still adds `EnvironmentLayer` before `Workspace`.

Run:

```powershell
.\tests\run_test.ps1 test_environment
.\tests\run_test.ps1 test_main
```

Expected: both scripts exit `0` and print `RESULT: ALL PASSED`.

- [ ] **Step 4: Launch and inspect the actual game**

Run:

```powershell
& "C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe" --path "C:\Users\merli\Documents\Godot Projects\operator"
```

Inspect at the default 1920×1080 size, then resize the window to a non-16:9 aspect. Confirm all of the following before closing:

- Apartment art cover-crops without stretching.
- Rain begins and ends inside the window pane, including its rounded corners.
- City detail remains legible through rain.
- Cyan/magenta spill changes are faint and localized.
- A forced `_trigger_lightning()` during a debug run is brief, cold, and below the UI.
- Status chip, icon rail, panels, ticker, and their pointer interaction remain undistorted and functional.

- [ ] **Step 5: Commit layer protection and verification coverage**

```powershell
git add tests/test_main.gd tests/test_environment.gd
git commit -m "test: protect apartment environment layering"
```

## Final Verification

Run the focused tests once after all commits:

```powershell
.\tests\run_test.ps1 test_environment
.\tests\run_test.ps1 test_main
```

Expected: both print `RESULT: ALL PASSED`. The visual smoke test in Task 4 is required because clipping, crop alignment, and atmospheric restraint are player-visible contracts that headless tests cannot establish.
