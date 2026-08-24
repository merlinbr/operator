# Workspace Polish — Design Specification

**Date:** 2026-08-25
**Status:** Approved design (after brainstorming), pending implementation plan
**Engine:** Godot 4.7.1
**Scope:** Follow-up to the terminal shell slice. Makes the "floating UI over environment"
concept actually hold: a sane navigation/interaction model, bounded panel proportions with
the environment visibly present, and a refined subtle rain effect.

Three sequential workstreams, in the agreed order:

1. **Navigation & interaction model** (`Phase 1`)
2. **Panel sizing / proportions** (`Phase 2`)
3. **Rain refinement** (`Phase 3`)

Do not spend time polishing the environment shader beyond these phases until the workspace
itself feels right.

---

## Phase 1 — Navigation & interaction model

### 1.1 Goal

Establish the fundamental interaction model every future module inherits:

- Clicking the **active** rail icon toggles that module's panel closed.
- Clicking a **different** rail icon switches modules (closing any open context panel).
- **Esc** closes the current/topmost panel.
- The top-right button stays the separate, global `Collapse / Expand Workspace` control.

The per-module close and the global collapse are **two distinct states** — this was the key
design decision. Per-module close is a lightweight per-panel hide (environment shows through);
global collapse is the whole-workspace toggle where chip/rail/ticker remain and the
environment is fully exposed.

### 1.2 State (`autoload/game_state.gd`)

Add two fields alongside the existing `workspace_collapsed`:

- `active_module: StringName` — the currently selected module id (`&""` when none).
- `module_open: bool` — whether the active module's primary panel is showing.

`workspace_collapsed: bool` is unchanged. Add two signals plus explicit setter methods that
emit **only on change**, mirroring the existing `set_workspace_collapsed()` guard pattern
(not the unconditional `set(value):` property blocks used by credits/heat/etc., since a change
guard is required here):

```
signal active_module_changed(id: StringName)
signal module_open_changed(open: bool)

var active_module: StringName = &""
var module_open := false

func set_active_module(id: StringName) -> void:
	if active_module == id:
		return
	active_module = id
	active_module_changed.emit(id)

func set_module_open(open: bool) -> void:
	if module_open == open:
		return
	module_open = open
	module_open_changed.emit(open)
```

`main.gd` connects to these signals to drive the rail highlight and the visibility rules.

### 1.3 Behaviors

| Input | Result |
|---|---|
| Click **active** rail icon | Toggle closed → `module_open=false` → primary hides, highlight clears, environment shows through |
| Click the **same** rail icon again | Toggle back open → `module_open=true` → primary re-shows |
| Click **different** rail icon | Switch → `active_module=id`, `module_open=true`; any open context panel is closed |
| **Esc** | Close topmost: context open → close context *else* primary open → close primary *else* nothing |
| Top-right **Collapse/Expand** | Toggle `workspace_collapsed`. Collapse hides primary+context (chip/rail/ticker + environment remain). Expand restores primary *if* `module_open` |
| Click any rail icon **while collapsed** | Un-collapse, then open that module |

Invariant: toggling a module closed keeps `active_module` set (so a second click re-opens the
same module) and only flips `module_open` to false — it does **not** change
`workspace_collapsed`. A rail icon is highlighted only while `active_module == id AND
module_open AND !workspace_collapsed`.

**Modules with no registered scene** (currently `alerts`, which is unlocked in the rail but has
no `MODULE_SCENES` entry) are **no-ops**: `select_module` early-returns, so clicking their rail
icon neither switches nor opens anything. This is called out explicitly because it is a
pre-existing dead button; Phase 1 keeps it as a no-op rather than breaking the interaction
model. See Out of scope.

### 1.4 Visibility rules (`main.gd`)

```
primary_host.visible = !workspace_collapsed && module_open
context_host.visible = !workspace_collapsed && module_open && context_host.child_count > 0
```

Closing the primary module also closes its context side panel (a context panel only exists
alongside an open primary).

### 1.5 Implementation notes

- `select_module(id)` in `main.gd` becomes the single entry point guarding all the state
  transitions above. It stays the only place that rebuilds the primary panel and updates the
  rail active highlight. A single guard, not scattered callers.
- **icon_rail** API changes. Today `set_active(id)` only encodes which module is active, and
  the rail has no reference to `GameState`. Under the new highlight rule (cyan only when
  `active ∧ open ∧ not collapsed`), `main.gd` computes the lit state and passes it in:

  ```
  icon_rail.set_active(id: StringName, lit: bool)
  ```

  `lit` controls whether the *active* button is highlighted cyan. With `lit == false` the
  active button renders in its normal (white / locked-dim) state, which is what happens when a
  module is toggled closed or the workspace is collapsed. Locked modules stay dimmed regardless.

  This is a **breaking change to `icon_rail.set_active`** — `test_icon_rail.gd:31-35` currently
  calls `set_active(&"comms")` and expects cyan; it becomes `set_active(&"comms", true)` for
  cyan and `set_active(&"comms", false)` for unlit.

- **Esc** is handled once in `main.gd` via an `_unhandled_input` handler (or a
  `ui_cancel`-bound shortcut). Do not scatter Esc handling across panels.
- **Top-right button** becomes a labeled text button: `"Collapse Workspace"` shown when not
  collapsed, `"Expand Workspace"` when collapsed (text + tooltip), replacing the bare `⧉`
  glyph.

### 1.6 Testing

Update `tests/test_main.gd` to cover: active-icon toggle-close; module switch; Esc topmost-
close (context first, then primary, then nothing); and the separation of per-module close
from global collapse (closing a module does not set `workspace_collapsed`).

---

## Phase 2 — Panel sizing / proportions

### 2.1 Goal

Stop every module from expanding to fill the screen. Give modules defined max dimensions so
the **environment remains visibly present around the panel** while the workspace keeps a
stable origin, and panels expand naturally left-to-right.

### 2.2 Size classes (`scripts/module_def.gd`)

Add one field to `ModuleDef`:

```
@export var size_class: StringName = &"normal"   # compact | narrow | normal | wide | context
```

The `context` class is used only by the context panel (not a registry module), so it is a
constant in `main.gd` rather than a value on a `ModuleDef`.

Class fractions are defined once at the top of `main.gd` as a constant dictionary, expressed
as a fraction of the **inset content region** (see 2.3):

| Class | Width | Height | Intent |
|---|---|---|---|
| `compact` | ~34% | ~46% | Home — short status card |
| `narrow` | ~44% | ~68% | contracts list |
| `normal` | ~60% | ~72% | Comms (default primary) |
| `wide` | ~78% | ~82% | maps / markets (future) |
| `context` | ~31% | mirrors primary | contextual side panel |

Assignments: `home → compact`, `comms → normal`, `contracts → narrow`. `alerts` has no scene
in this slice, so it gets no size class yet. `contract_detail` (the context panel) is the one
consumer of the `context` class.

### 2.3 Layout algorithm (`main.gd` `_apply_layout`)

1. Compute the **inset content region**: start from the existing `panel_left` / `content_top`
   origin, then push in by a consistent `PANEL_INSET` (~18px) on *all* sides so panels float
   clear of the rail, the top status area, the right margin, and the ticker. (Note:
   `panel_left` already clears the rail via `RAIL_GAP`; the inset is an additional float.)
2. **Primary panel** → top-left anchored at the region origin, sized to its class fractions.
3. **Context panel** (when open) → `context` class width (~31%), top and height **mirror the
   primary** so they always align. Placed to the right of the primary with the existing
   `CONTEXT_GAP`. Both always fit: with the current assignments the widest total is `normal`
   (60%) + `context` (31%) = 91% < 100%, so the primary never needs to shrink.
4. Panels no longer stretch to fill; unused space on the right/below remains visible
   environment.

**Removed:** the old `CONTEXT_SPLIT` (0.62) ratio and its "shrink primary to fit" branch
(`main.gd:27`, used at `:219-225`). They only exist to serve a future `wide` module
(78% + 31% = 109%, which would overflow). No `wide` module exists in this slice, so this is
speculative flexibility for maps/markets that aren't built yet. **Defer the shrink rule until a
`wide` module is introduced** (YAGNI — nothing exercises it today). Deleting `CONTEXT_SPLIT`
is part of the clean cutover.

### 2.4 Testing

Update `tests/test_main.gd` layout assertions: primary and context no longer fill the region;
a non-zero environment region remains; primary **keeps its class width** when context opens.
(The existing `test_main.gd:27` "primary shrinks when context opens" assertion is **removed** —
under `narrow` the contracts primary is 44% whether or not context is open, so it would flip
false.) Add a check that the Home panel sizes to `compact`.

---

## Phase 3 — Rain refinement

### 3.1 Goal

Make the rain read as atmosphere: thinner, shorter, far more numerous but much less opaque,
slightly angled, varied in speed/length, and split into subtle depth layers.

### 3.2 Approach

Rewrite `scenes/main/rain.gdshader` (a single `canvas_item` fragment shader, unchanged
attachment in `environment.gd`) to render **three depth layers — Near / Mid / Far** in one
pass. `environment.gd` needs no structural change.

**Technique (borrowed from the reference shaders):** the current `rain.gdshader` is already
O(1) per fragment (a `fract(sin(...))` hash + `step` gate + `smoothstep` streak, no loop). This
rewrite keeps that cost profile and restructures it into **three summed layer evaluations**,
borrowing the per-column grid variation — a `fract(sin(...))` hash for random speed/length and a
`mod()` cell remainder for horizontal thickness — from "Rain and Snow with Parallax Effect"
(Brian Smith, MIT). Each layer is a single procedural evaluation. (The loop-based "Simple
rain/snow shader" iterates `count` drops per fragment and is not used, but that's a perf
side-note, not the reason for the approach.)

**Layer parameters** (one `rain_layer(...)` helper evaluated 3×; slant kept broadly consistent,
depth comes mainly from speed/thickness/length/density/alpha):

| Layer | Grid density | Speed (UV/s) | Streak length | Thickness frac | Slant | Alpha (×intensity) |
|---|---|---|---|---|---|---|
| Near | 140 | 2.2–3.0 | 0.08–0.12 | 0.15 | ~0.05 | ~0.10 |
| Mid | 220 | 1.4–2.2 | 0.055–0.085 | 0.10 | ~0.045 | ~0.06 |
| Far | 320 | 0.8–1.6 | 0.035–0.055 | 0.06 | ~0.04 | ~0.035 |

- **Thinner:** each streak is a thin centered line in its cell (small thickness fraction),
  not a full-width band. Density is the grid cell count, not a drop count.
- **Shorter:** streak length is a small fraction of the screen height (today it spans ~35%).
- **More numerous, much less opaque:** total grid density ~680 across layers; per-layer alpha
  ~0.035–0.10 (today effective ~0.18). Total peak pixel alpha ≈ `(0.10+0.06+0.035) × ~0.5`
  ≈ 0.10 — subtle.
- **Angled:** a small per-layer shear of `UV.x` by `UV.y` so drops fall a few degrees
  off-vertical; kept broadly consistent across layers (depth from other params, not angle).
- **Varied speed & length:** per-column `rn` hash drives both.
- **Compositing:** the three layer contributions are **summed** (`a = near + mid + far`), then
  `COLOR = vec4(color.rgb, a * intensity)` — not max/overwrite.
- **Color:** single light rain color `vec4(0.706, 0.863, 1.0, 1.0)`; the Near layer reads
  brighter via higher alpha.

Keep the `intensity` uniform (default 0.5) as the master tuning knob.

### 3.3 Testing

Rain is a visual shader — verified by eye. There is no meaningful logic to unit-test; mark as
a deliberate simplification. Keep any existing shader sanity checks (if present) green.

---

## Out of scope (this effort)

- Panel dragging / free window management.
- Real game content behind the modules.
- An `alerts` module scene/content. `alerts` is unlocked in the rail but has no scene and no
  `MODULE_SCENES` entry, so it stays a **no-op** rail button this slice. Phase 1 keeps
  `select_module` tolerant of modules that have no registered scene.
- The "primary shrinks when context opens" rule until a `wide` module exists.
- Major environment shader work beyond the rain.
- Responsive layout below 1280×720 (unchanged).

## Success criteria

- Clicking the active rail icon closes its panel (highlight clears, environment shows);
  clicking another icon switches modules; Esc closes context → primary → nothing.
- Per-module close and global collapse are clearly distinct actions; collapse preserves
  `module_open` so expanding restores the prior panel.
- Top-right control is a labeled Collapse/Expand Workspace button.
- Home renders small (`compact`), Comms `normal`, Contracts `narrow`; context opens at ~31%
  aligned with its primary; environment is visibly present around open panels.
- Rain reads as subtle layered volume (thin, short, numerous, faint, angled, varied,
  depth-layered) at ~O(1) per-layer cost.
- Layout and interaction hold together at 1280×720 and look intended at 1920×1080.

## File changes

- `autoload/game_state.gd` — add `active_module` + `module_open`, `set_active_module()` /
  `set_module_open()` methods, and their signals.
- `scenes/main/main.gd` — rework `select_module` (incl. no-op guard for scene-less modules),
  add Esc handler, visibility rules, labeled collapse button, panel-inset sizing algorithm,
  size-class constant map; **delete `CONTEXT_SPLIT`** and its shrink-primary branch.
- `scenes/ui/icon_rail.gd` — change `set_active(id)` → `set_active(id, lit)`.
- `scripts/module_def.gd` — add `size_class`.
- `resources/module_registry.tres` / module defs — set size classes for home/comms/contracts.
- `scenes/main/rain.gdshader` — rewrite to 3-layer summed rain.
- `tests/test_main.gd` — new interaction/visibility assertions; remove the shrink assertion.
- `tests/test_icon_rail.gd` — update `set_active(id, lit)` contract.
