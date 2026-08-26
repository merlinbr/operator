# Tier 1 Apartment Environment Design

## Goal

Replace the procedural placeholder environment with `res://assets/tier-1-appartment.png` and add restrained apartment-only ambience. The illustration remains the dominant visual; rain, exterior neon, and lightning run behind the interactive workspace.

## Scope

- Render the Tier 1 apartment artwork as the environment background.
- Keep its 16:9 composition and use cover-crop behavior for non-16:9 viewports.
- Animate rain strictly inside the painted window.
- Add subtle cyan and magenta exterior-light variation near the window.
- Add rare, low-intensity lightning.
- Keep every environment node below `Workspace` and ignore pointer input.

Not included: synthetic skyline/neon, mouse parallax, global rain, weather simulation, audio, art relighting, or full-screen post-processing.

## Scene Architecture

`Main._build_shell()` retains its child order:

1. `EnvironmentLayer`
2. `Workspace`

`EnvironmentLayer` owns four ordered children:

1. `ApartmentBackground` — full-rect `TextureRect` using `tier-1-appartment.png` with `STRETCH_KEEP_ASPECT_COVERED`.
2. `WindowRain` — window-sized `ColorRect` with a local canvas shader.
3. `ExteriorLight` — a container for cyan and magenta low-alpha gradient overlays, each positioned from the artwork coordinate system.
4. `Lightning` — a container for a window flash and a low-alpha cold room flash.

Every environment control uses `Control.MOUSE_FILTER_IGNORE`. No environment material samples, modulates, or otherwise touches `Workspace`; sibling rendering order ensures the UI is excluded from rain, glow, distortion, and lightning.

## Artwork Coordinates and Resizing

The source art is 1672×941 (16:9). `EnvironmentLayer` derives one fitted artwork rectangle whenever its size changes:

```text
scale = max(viewport_width / 1672, viewport_height / 941)
art_size = (1672, 941) * scale
art_origin = (viewport_size - art_size) / 2
```

`ApartmentBackground` covers the viewport with this transform. Each effect rectangle converts its normalized artwork `Rect2` through the same `art_origin + normalized_position * art_size` mapping. Thus cropping happens at the artwork edges while the window effects remain registered to the painted window.

The initial window pane calibration is `Rect2(0.555, 0.136, 0.219, 0.435)`. The rain material applies a rounded local alpha mask so corners do not spill outside the pane. This is a visual calibration constant, not a user-facing setting.

## Effects

### Window Rain

`WindowRain` is the only animated shader region. The shader uses three sparse procedural bands:

- fine, moderately fast downward streaks;
- smaller, slower droplets;
- very infrequent longer trails.

Bands use fixed hash variation for per-column speed, length, and phase. Alpha stays low enough that the city remains legible. The shader does not include refraction/distortion initially: rain motion is the required effect, while distortion would add sampling complexity with little atmospheric gain. It may be added later only if it remains a single local pass and is visually imperceptible at rest.

### Exterior Light

Cyan and magenta radial-gradient overlays sit near the window, adjacent wall, and floor reflection area. Their low opacity varies independently over roughly 8–20-second spans. They are not intended to simulate physically correct lighting or recolor the full painting.

### Lightning

A one-shot timer selects the next event uniformly in the 45–150-second range. An event briefly raises a window-local cold flash and a faint room-light overlay, then decays naturally. A weaker second flash has a modest random chance. The effect is rare and remains behind `Workspace`.

## Lifecycle and Failure Behavior

`EnvironmentLayer` builds the four children once in `_ready`, recalculates geometry after the first valid layout and on `resized`, and advances only time-based effect state each frame.

The new image and shader are preloaded resources. A missing or invalid resource follows Godot's ordinary load error path; the implementation does not retain or reconstruct the old procedural scene as a fallback. Before nonzero dimensions exist, layout work is deferred rather than producing invalid transforms.

## Performance

- One window-sized canvas shader; no full-screen weather shader.
- A small fixed number of controls and gradient textures.
- No particles, per-drop nodes, offscreen viewports, or per-frame allocations.
- Geometry is recalculated only on resize, not each frame.

## Verification

Extend focused main/environment coverage to verify:

- `EnvironmentLayer` is added before `Workspace`.
- The four named environment children exist in their defined order.
- The background uses the Tier 1 texture and cover-crop stretch mode.
- Each effect control ignores mouse input.
- Normalized artwork-to-viewport conversion keeps the window rain region aligned for a 16:9 viewport and a non-16:9 cover-cropped viewport.
- Lightning state resets after a triggered flash and never changes workspace/UI modulation.

Run the game and inspect the actual scene at 16:9 and a non-16:9 viewport. Confirm the window edge contains all rain, the artwork is undistorted at rest, the UI remains fully legible and interactive, spill varies only faintly, and a forced lightning event stays atmospheric.

## Acceptance Criteria

- The placeholder sky, skyline, neon sign, full-screen rain, and parallax are gone.
- The Tier 1 art fills the environment with preserved aspect ratio and cover-crop behavior.
- Rain is visible only through the painted window and does not obscure the city.
- Cyan/magenta variation and rare lightning add motion without competing with UI.
- No environmental effect renders above, changes, or intercepts the floating game UI.
- The implementation continuously runs without full-screen weather processing or node-per-drop work.
