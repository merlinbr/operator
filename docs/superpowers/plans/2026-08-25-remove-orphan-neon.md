# Remove Orphaned Neon Accent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax to track progress.

**Goal:** Remove the standalone magenta environment accent that no longer has a building or sign context.

**Architecture:** Keep the existing procedural environment builder and remove only the unused pink neon definition and its rectangle. The cyan accent, skyline generation, parallax, rain, and UI remain unchanged.

**Tech Stack:** Godot 4.7.1, typed GDScript, headless tests, PowerShell project launch.

## Global Constraints

- Placeholder environment content remains in `scenes/main/environment.gd`; no new building or sign system is introduced.
- Keep the cyan neon accent unchanged.
- Do not alter skyline, rain, parallax, or workspace behavior.
- Verify with the existing 11-script headless suite and Godot 4.7.1 project launch.

---

### Task 1: Remove Orphaned Pink Neon

**Files:**
- Modify: `scenes/main/environment.gd:8,73-76`
- Verify: existing headless suite and project launch.

**Interfaces:**
- Consumes: existing `_build_neon()` rectangle builder.
- Produces: one intentional cyan neon accent instead of two, with no other environment behavior changes.

- [ ] **Step 1: Confirm the orphaned definition**

Verify `_build_neon()` currently defines these two entries:

```gdscript
const NEON_CYAN := Color(0.22353, 0.81569, 1.0)
const NEON_PINK := Color(1.0, 0.35294, 0.47059)

var specs := [
	[NEON_CYAN, Vector2(0.18, 0.62), Vector2(120, 12)],
	[NEON_PINK, Vector2(0.68, 0.48), Vector2(80, 10)],
]
```

- [ ] **Step 2: Remove only the orphaned accent**

Delete `NEON_PINK` and its `specs` entry. Leave the cyan definition and entry unchanged:

```gdscript
const NEON_CYAN := Color(0.22353, 0.81569, 1.0)

var specs := [
	[NEON_CYAN, Vector2(0.18, 0.62), Vector2(120, 12)],
]
```

- [ ] **Step 3: Verify behavior**

Run every existing test with `tests/run_test.ps1`; expect each command to end with `RESULT: ALL PASSED`. Launch the project:

```powershell
& "C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe" --path "C:\Users\merli\Documents\Godot Projects\operator"
```

Expected: no runtime errors, the environment loads, and only the cyan accent remains.

- [ ] **Step 4: Check the diff and commit**

Run `git diff --check`, then commit:

```powershell
git add scenes/main/environment.gd
git commit -m "polish: remove orphaned pink neon accent"
```
