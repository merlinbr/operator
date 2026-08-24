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

`workspace_collapsed: bool` is unchanged. Follow the existing one-signal-per-state pattern by
adding two signals with property setters that emit them:

```
signal active_module_changed(id: StringName)
signal module_open_changed(open: bool)

var active_module: StringName = &""
var module_open := false
```

Each field has a setter that emits its signal only on change (mirroring the existing
`set_workspace_collapsed` guard). `main.gd` connects to these to drive the rail highlight and
the visibility rules.

### 1.3 Behaviors

| Input | Result |
|---|---|
| Click **active** rail icon | Toggle closed → `module_open=false` → primary hides, highlight clears, environment shows through |
| Click **different** rail icon | Switch → `active_module=id`, `module_open=true`; any open context panel is closed |
| **Esc** | Close topmost: context open → close context *else* primary open → close primary *else* nothing |
| Top-right **Collapse/Expand** | Toggle `workspace_collapsed`. Collapse hides primary+context (chip/rail/ticker + environment remain). Expand restores primary *if* `module_open` |
| Click any rail icon **while collapsed** | Un-collapse, then open that module |

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
- **Esc** is handled once in `main.gd` via an `_unhandled_input` handler (or a
  `ui_cancel`-bound shortcut). Do not scatter Esc handling across panels.
- **Top-right button** becomes a labeled text button: `"Collapse Workspace"` shown when not
  collapsed, `"Expand Workspace"` when collapsed (text + tooltip), replacing the bare `⧉`
  glyph.
- **icon_rail** highlight rule: a rail icon is highlighted (cyan) only when it is the active
  module *and* the panel is open *and* the workspace is not collapsed. Locked modules stay
  dimmed.

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

Assignments: `home → compact`, `comms → normal`, `contracts → narrow`. `contract_detail`
(the context panel) is not a registry module, so its `context` size is a constant in
`main.gd`, not on a `ModuleDef`.

### 2.3 Layout algorithm (`main.gd` `_apply_layout`)

1. Compute the **inset content region**: start from the existing `panel_left` / `content_top`
   origin, then push in by a consistent `PANEL_INSET` (~18px) on *all* sides so panels float
   clear of the rail, the top status area, the right margin, and the ticker.
2. **Primary panel** → top-left anchored at the region origin, sized to its class fractions.
3. **Context panel** (when open) → `context` class width (~31%), top and height **mirror the
   primary** so they always align. Placed to the right of the primary with the existing
   `CONTEXT_GAP`. If primary + gap + context would exceed the region width, the primary
   **shrinks** to fit (context keeps its width).
4. Panels no longer stretch to fill; unused space on the right/below remains visible
   environment.

### 2.4 Testing

Update `tests/test_main.gd` layout assertions: primary and context no longer fill the region;
a non-zero environment region remains; primary shrinks when context opens. Add a check that
the Home panel sizes to `compact`.

---

## Phase 3 — Rain refinement

### 3.1 Goal

Make the rain read as atmosphere: thinner, shorter, far more numerous but much less opaque,
slightly angled, varied in speed/length, and split into subtle depth layers.

### 3.2 Approach

Rewrite `scenes/main/rain.gdshader` (a single `canvas_item` fragment shader, unchanged
attachment in `environment.gd`) to render **three depth layers — Near / Mid / Far** in one
pass. `environment.gd` needs no structural change.

**Technique (borrowed, per the reference shaders):** use the analytic O(1) grid approach from
"Rain and Snow with Parallax Effect" (Brian Smith, MIT) — derive per-column variation with a
`fract(sin(...))` hash, and gate horizontal thickness via the `mod()` cell remainder. This is
one procedural evaluation per layer, **no `for` loop over drops**, so a fullscreen 1920×1080
pass stays cheap. The `for`-loop approach in the "Simple rain/snow shader" is explicitly
**not** used (loops over `count` drops per fragment).

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

- `autoload/game_state.gd` — add `active_module`, `module_open` + signals.
- `scenes/main/main.gd` — rework `select_module`, Esc handler, visibility rules, labeled
  collapse button, panel-inset sizing algorithm, size-class constant map.
- `scenes/ui/icon_rail.gd` — highlight rule tied to `module_open`/collapse.
- `scripts/module_def.gd` — add `size_class`.
- `scripts/module_registry.tres` / module defs — set size classes for home/comms/contracts.
- `scenes/main/rain.gdshader` — rewrite to 3-layer O(1) rain.
- `tests/test_main.gd`, `tests/test_icon_rail.gd` — update for new behavior/visibility.
