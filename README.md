# Operator

A cyberpunk operations RPG — build a life and an organization as an independent operator in a dystopian corporate society.

> **Status:** early playable prototype. The current build contains the navigable operations-terminal shell, boot sequence, time-reactive Studio and Loft environments, a deterministic seven-contract early-game portfolio, publication-relative enforced deadlines with hard expiry/failure, contact standing, housing/rent progression, and a persistent single-profile save. It has no combat or procedural content systems.

Published contracts have persistent game-time deadlines. Unaccepted offers expire; active jobs fail at the cutoff. Deadline outcomes publish the same successors as an abort without paying rewards or changing Heat, standing, or favors. The remaining window is saved; acceptance and reload do not renew it.

## About

The player is an independent operator trying to survive and grow inside a dark corporate society — legitimate trader, smuggler, bounty hunter, mercenary, fixer, or a mix. The core loop is *discover → evaluate → prepare → execute → react → resolve → progress*, played through an **interactive event-sequence** model rather than an action game.

This is a **UI-first** game: the interface is an in-world operations terminal, and the environment behind it (an apartment, a skyline, the rain) is progression made visible — upgrade your life, and the view changes.

See the design documents for the full vision:

- [`docs/superpowers/specs/2026-09-05-contract-deadlines-design.md`](docs/superpowers/specs/2026-09-05-contract-deadlines-design.md) — publication-relative contract deadlines
- [`docs/superpowers/specs/2026-08-31-contact-contract-progression-design.md`](docs/superpowers/specs/2026-08-31-contact-contract-progression-design.md) — Mara/Vesper contract progression and standing
- [`docs/superpowers/specs/2026-08-31-lightning-room-illumination-design.md`](docs/superpowers/specs/2026-08-31-lightning-room-illumination-design.md) — diffuse window-originated lightning
- [`docs/superpowers/specs/2026-08-26-first-contract-vertical-slice-design.md`](docs/superpowers/specs/2026-08-26-first-contract-vertical-slice-design.md) — first playable contract slice
- [`docs/superpowers/specs/2026-08-28-early-contract-portfolio-design.md`](docs/superpowers/specs/2026-08-28-early-contract-portfolio-design.md) — three-contract early-game portfolio
- [`docs/superpowers/specs/2026-08-24-terminal-shell-design.md`](docs/superpowers/specs/2026-08-24-terminal-shell-design.md) — Slice 0 design spec
- [`docs/superpowers/plans/2026-08-24-terminal-shell.md`](docs/superpowers/plans/2026-08-24-terminal-shell.md) — Slice 0 implementation plan

## Requirements

- [Godot 4.7.1](https://godotengine.org/) (stable)

## Getting started

Open the project folder in the Godot editor and run — `res://scenes/boot/boot.tscn` is the entry scene and routes to the operations workspace at `res://scenes/main/main.tscn`.

From the command line:

```powershell
& "C:\path\to\Godot_v4.7.1-stable_win64_console.exe" --path .
```

## Testing

Headless GDScript tests (no framework — a minimal `SceneTree` harness). Run one:

```powershell
.\tests\run_test.ps1 test_game_state
```

Test files include focused coverage for boot, contracts, contract catalog, environment, game state, persistence, panels, main scene, theme, and UI components. Every suite prints `RESULT: ALL PASSED` on success; `.\tests\run_all.ps1` runs the complete set.

## Project structure

```
res://
  autoload/          GameState autoload (single source of truth for state)
  scenes/main/       main scene + layered environment (sky, skyline, neon, rain)
  scenes/ui/         status chip, icon rail, ticker bar
  scenes/modules/    home, comms, contracts (+ contract detail)
  scripts/           module definitions + registry (data-driven rail)
  resources/         operator theme and module registry
  data/contracts/    authored contract portfolio
  data/contacts/     authored contact identities and standing labels
  data/housing/      authored residence definitions
  tests/             headless tests + run_test.ps1
```

Architecture notes: components receive `GameState` via `setup()` injection (never the autoload global); authored contracts, contacts, and residences live in dedicated catalogs; `GameState` owns their mutable runtime state, single-profile persistence, and availability rules; the icon rail renders from `module_registry.tres` (add a module = add a definition + a scene, no rail-script edits).

## License

[MIT](LICENSE)
