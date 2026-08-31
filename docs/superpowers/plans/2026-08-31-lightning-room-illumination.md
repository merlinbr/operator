# Lightning Room Illumination Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve lightning while replacing the hard-edged room flash with diffuse, window-originated illumination.

**Architecture:** `Environment` continues to own one `Lightning` control, its timer, and both flash tweens. `WindowFlash` remains a `ColorRect`; `RoomFlash` becomes a `TextureRect` with a radial `GradientTexture2D`. A small private helper derives the texture source from the existing per-residence `window` and `room_flash` UV rectangles, avoiding new profile fields.

**Tech Stack:** Godot 4.7, GDScript, built-in `GradientTexture2D`, existing headless `SceneTree` tests.

## Global Constraints

- Preserve the 45–150 second randomized lightning timing and the 25% delayed-secondary-strike behavior.
- Preserve `WindowFlash`, the existing flash alphas and tween durations, UI layering, and mouse-input safety.
- Reuse the existing residence art profiles; do not add a weather system, shader, scene, dependency, or configuration.
- `RoomFlash` must have a fully transparent gradient edge and derive its source from the active residence's mapped window.

---

### Task 1: Lock down diffuse room-flash behavior

**Files:**
- Modify: `tests/test_environment.gd:155-181`

**Interfaces:**
- Consumes: `Environment`'s existing `Lightning`, `WindowFlash`, `RoomFlash`, `_trigger_lightning()`, and `_art_profile` members.
- Produces: Regression coverage requiring `RoomFlash` to be a radial, transparent-edged texture whose source follows the active profile's window.

- [ ] **Step 1: Change the room-flash fixture type and add texture checks**

Replace the flat-rectangle fixture assertion with the following test setup and check after `window_flash` is retrieved:

```gdscript
var room_flash: TextureRect = lightning.get_node("RoomFlash")
var room_texture := room_flash.texture as GradientTexture2D
var room_gradient := room_texture.gradient
var room_rect: Rect2 = environment._art_profile.room_flash
var window_rect: Rect2 = environment._art_profile.window
var expected_source := (window_rect.get_center() - room_rect.position) / room_rect.size
check(room_texture != null
	and room_texture.fill == GradientTexture2D.FILL_RADIAL
	and room_texture.fill_from.is_equal_approx(expected_source)
	and is_zero_approx(room_gradient.get_color(1).a),
	"room flash is radial, window-originated, and transparent at its edge")
```

Keep the existing input-safety, mapped-bounds, alpha-rise, and alpha-decay checks; they must now operate on the `TextureRect`.

- [ ] **Step 2: Run the focused test to verify it fails**

Run:

```powershell
rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_environment
```

Expected: failure because `RoomFlash` is still a `ColorRect`, not a radial `GradientTexture2D`.

### Task 2: Render room illumination as a radial texture

**Files:**
- Modify: `scenes/main/environment.gd:84,155-161,200-209,286-318`
- Test: `tests/test_environment.gd:155-181`

**Interfaces:**
- Consumes: the existing `ART_PROFILES` dictionaries, each containing `window` and `room_flash` `Rect2` UV rectangles; `apply_environment_layout()` continues to map `RoomFlash` with `room_flash`.
- Produces: `_make_room_flash(profile: Dictionary) -> TextureRect` and `_room_flash_source(profile: Dictionary) -> Vector2`, used only by `Environment`.

- [ ] **Step 1: Replace the room-flash field and construction**

Change the field type and replace the current flat `ColorRect` construction:

```gdscript
var _room_flash: TextureRect
```

```gdscript
_room_flash = _make_room_flash(_art_profile)
_lightning.add_child(_room_flash)
```

Keep `WindowFlash` unchanged.

- [ ] **Step 2: Add a profile-derived source helper and room-flash factory**

Add these private methods next to `_make_spill`:

```gdscript
func _room_flash_source(profile: Dictionary) -> Vector2:
	var window: Rect2 = profile.window
	var room: Rect2 = profile.room_flash
	return (window.get_center() - room.position) / room.size

func _make_room_flash(profile: Dictionary) -> TextureRect:
	var flash := TextureRect.new()
	flash.name = "RoomFlash"
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.stretch_mode = TextureRect.STRETCH_SCALE
	var texture := GradientTexture2D.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.53, 0.70, 1.0, 1.0))
	gradient.set_color(1, Color(0.53, 0.70, 1.0, 0.0))
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	_apply_room_flash_profile(texture, profile)
	flash.texture = texture
	flash.modulate.a = 0.0
	return flash

func _apply_room_flash_profile(texture: GradientTexture2D, profile: Dictionary) -> void:
	var source := _room_flash_source(profile)
	var radius := maxf(
		source.distance_to(Vector2.ZERO),
		source.distance_to(Vector2(1.0, 0.0)),
		source.distance_to(Vector2(0.0, 1.0)),
		source.distance_to(Vector2.ONE))
	texture.fill_from = source
	texture.fill_to = source + Vector2(radius, 0.0)
```

The radius reaches the farthest texture corner, so every visible room-flash boundary is transparent rather than a hard lit edge.

- [ ] **Step 3: Retarget the room texture on a residence change**

In `_apply_residence_art`, after assigning `_art_profile`, update the existing room texture before applying layout:

```gdscript
var room_texture := _room_flash.texture as GradientTexture2D
if room_texture != null:
	_apply_room_flash_profile(room_texture, profile)
```

Guard it with `_room_flash != null` so `setup()` remains safe before `_ready()` creates visual nodes.

- [ ] **Step 4: Run focused regression coverage**

Run:

```powershell
rtk powershell -ExecutionPolicy Bypass -File tests/run_test.ps1 test_environment
```

Expected: `RESULT: ALL PASSED`.

- [ ] **Step 5: Perform a visual smoke check**

Run the project, wait for a natural lightning strike or call `_trigger_lightning()` from the editor debugger, and inspect both residences. The room must brighten diffusely from the window without a rectangular edge; the window flash and workspace UI must remain unchanged.

- [ ] **Step 6: Run the complete suite**

Run:

```powershell
rtk powershell -ExecutionPolicy Bypass -File tests/run_all.ps1
```

Expected: every suite reports `RESULT: ALL PASSED` and the runner exits zero.

- [ ] **Step 7: Commit the focused change**

```powershell
rtk git add scenes/main/environment.gd tests/test_environment.gd docs/superpowers/specs/2026-08-31-lightning-room-illumination-design.md docs/superpowers/plans/2026-08-31-lightning-room-illumination.md
rtk git commit -m "fix: soften apartment lightning illumination"
```

## Self-review

- **Spec coverage:** Task 1 locks down the radial, transparent-edged, window-derived texture; Task 2 preserves timing, tween behavior, room layout, residence changes, and interactive verification.
- **Placeholder scan:** no deferred implementation, unspecified interfaces, or generic testing steps remain.
- **Type consistency:** `_room_flash` is `TextureRect` in both the test and implementation; `_make_room_flash`, `_room_flash_source`, and `_apply_room_flash_profile` use `Dictionary`, `TextureRect`, `GradientTexture2D`, and `Vector2` consistently.
