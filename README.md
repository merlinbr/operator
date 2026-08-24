# Operator

A cyberpunk operations RPG — build a life and an organization as an independent operator in a dystopian corporate society.

> **Status:** early prototype. The current build is the "operations terminal" shell (Slice 0) — a working, navigable UI over a layered living environment. No real gameplay systems yet.

## About

The player is an independent operator trying to survive and grow inside a dark corporate society — legitimate trader, smuggler, bounty hunter, mercenary, fixer, or a mix. The core loop is *discover → evaluate → prepare → execute → react → resolve → progress*, played through an **interactive event-sequence** model rather than an action game.

This is a **UI-first** game: the interface is an in-world operations terminal, and the environment behind it (an apartment, a skyline, the rain) is progression made visible — upgrade your life, and the view changes.

See the design documents for the full vision:

- [`context.md`](context.md) — project context and design pillars
- [`docs/superpowers/specs/2026-08-24-terminal-shell-design.md`](docs/superpowers/specs/2026-08-24-terminal-shell-design.md) — Slice 0 design spec
- [`docs/superpowers/plans/2026-08-24-terminal-shell.md`](docs/superpowers/plans/2026-08-24-terminal-shell.md) — Slice 0 implementation plan

## Requirements

- [Godot 4.7.1](https://godotengine.org/) (stable)

## Getting started

Open the project folder in the Godot editor and run — the main scene is `res://scenes/main/main.tscn`.

From the command line:

```powershell
& "C:\path\to\Godot_v4.7.1-stable_win64_console.exe" --path .
```

## Testing

Headless GDScript tests (no framework — a minimal `SceneTree` harness). Run one:

```powershell
.\tests\run_test.ps1 test_game_state
```

Test files: `test_smoke`, `test_game_state`, `test_module_registry`, `test_theme`, `test_placeholder_data`, `test_status_chip`, `test_icon_rail`, `test_ticker_bar`, `test_panels_basic`, `test_contracts`, `test_main`. Each prints `RESULT: ALL PASSED` on success.

## Project structure

```
res://
  autoload/          GameState autoload (single source of truth for state)
  scenes/main/       main scene + layered environment (sky, skyline, neon, rain)
  scenes/ui/         status chip, icon rail, ticker bar
  scenes/modules/    home, comms, contracts (+ contract detail)
  scripts/           module definitions + registry (data-driven rail)
  resources/         operator theme, module registry
  data/placeholder/  dummy contracts/messages (isolated, easy to replace)
  assets/fonts/      JetBrains Mono
  tests/             headless tests + run_test.ps1
```

Architecture notes: components receive `GameState` via `setup()` injection (never the autoload global); the icon rail renders from `module_registry.tres` (add a module = add a definition + a scene, no rail-script edits); placeholder game content lives only in `data/placeholder/`.

## License

[MIT](LICENSE)
