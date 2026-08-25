# Rain Speed Tuning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the existing layered rain subtly slower and calmer without changing its visual depth structure.

**Architecture:** Keep the existing single `canvas_item` shader and its three summed O(1) layer evaluations. Only the speed base and variation arguments in the Near, Mid, and Far calls change; density, length, thickness, alpha, slant, color, and intensity remain unchanged.

**Tech Stack:** Godot 4.7.1, GLSL-like Godot canvas_item shader, PowerShell verification.

## Global Constraints

- Keep `uniform float intensity : hint_range(0.0, 1.0) = 0.5` unchanged.
- Keep the three summed O(1) Near/Mid/Far layer evaluations; do not add a drop loop.
- Keep the existing density, slant, length, width, alpha, seed, and color parameters unchanged.
- Reduce each layer's speed base and variation by exactly 25%.
- Verify with the Godot 4.7.1 executable at `C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe`.

---

### Task 1: Slow Layer Speeds

**Files:**
- Modify: `scenes/main/rain.gdshader:30-32`
- Verify: run the project; no logic test is needed for this visual-only tuning.

**Interfaces:**
- Consumes: existing `rain_layer(...)` shader helper and `intensity` uniform.
- Produces: the same shader with slower Near/Mid/Far motion.

- [ ] **Step 1: Confirm the current layer parameters**

Verify the three calls currently use these speed pairs:

```glsl
// Near: speed_base 2.2, speed_var 0.8
// Mid:  speed_base 1.4, speed_var 0.8
// Far:  speed_base 0.8, speed_var 0.8
```

- [ ] **Step 2: Apply the minimal shader edit**

Change only the speed arguments to:

```glsl
a += rain_layer(uv, 140.0, 0.05, 1.65, 0.6, 0.08, 0.04, 0.15, 0.10, 1.0);  // near
a += rain_layer(uv, 220.0, 0.045, 1.05, 0.6, 0.055, 0.03, 0.10, 0.06, 7.0); // mid
a += rain_layer(uv, 320.0, 0.04, 0.6, 0.6, 0.035, 0.02, 0.06, 0.035, 13.0); // far
```

Do not change the helper, uniform, output color, or any other layer argument.

- [ ] **Step 3: Verify the project**

Run:

```powershell
& "C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe" --path "C:\Users\merli\Documents\Godot Projects\operator"
```

Expected: the project starts without shader compilation/runtime errors; rain remains visibly moving but calmer.

- [ ] **Step 4: Check the diff and commit**

Run `git diff --check`, then commit:

```powershell
git add scenes/main/rain.gdshader
git commit -m "polish: subtly slow rain motion"
```
