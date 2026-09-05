# Contract Deadlines Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enforce publication-relative contract deadlines, expiring unaccepted offers and failing active jobs without extending deadlines on acceptance or reload.

**Architecture:** Keep authored windows in `ContractCatalog` and all mutable cutoffs, publication, expiry, and clock advancement in `GameState`. Extend the existing minute-advance loop and contract UI; use the existing save, messages, ticker, and semantic signals. No scheduler service, real-time timer, generic outcome engine, or new gameplay subsystem.

**Tech Stack:** Godot 4.7.1, GDScript, existing SceneTree headless tests, PowerShell on Windows. No new dependencies.

## Global Constraints

- Approved specification: `docs/superpowers/specs/2026-09-05-contract-deadlines-design.md`.
- Publication means `is_playable` first becomes true, even when standing is insufficient. Acceptance does not reset a cutoff.
- Expiry uses `now >= deadline`, not `now > deadline` and not only midnight.
- Unaccepted expiry: `expired / resolved / deadline_missed`. Active expiry: `failed / resolved / deadline_missed`.
- Deadline outcomes award nothing and change no Heat, standing, or favors. Existing rent changes remain independent.
- Both outcomes publish existing abort-path successors. Existing standing gates remain; there is no guarantee of completing every job.
- Keep authored choices, rewards, proceed durations, housing restrictions, and time consumption unchanged.
- No Heat feature, late outcomes, extension mechanic, recovery jobs, inventory, preparation, or UI redesign.
- Version-1 and version-2 saves migrate without reset. Version-3 reloads never renew deadlines.
- Components continue receiving `GameState` through `setup()` injection.
- Run save-writing tests and runtime verification under a disposable project identity, not the user's real Operator profile.
- This document is a plan, not evidence that implementation or tests have run.

---

## File map and execution order

| Task | Files | Responsibility |
|---|---|---|
| 1 | `data/contracts/contract_catalog.gd`, `autoload/game_state.gd`, new `tests/test_deadlines.gd`, `tests/test_contract_catalog.gd` | Publication cutoffs, chronological clock processing, terminal transitions and action safety |
| 2 | `autoload/game_state.gd`, `tests/test_persistence.gd` | Version-3 persistence, legacy migration, validation and overdue-load reconciliation |
| 3 | `scenes/modules/contracts/contracts_panel.gd`, `scenes/modules/contracts/contract_detail.gd`, `scenes/main/main.gd`, `tests/test_contracts.gd`, `tests/test_main.gd`, `README.md`, `context.md`, `next-features.md` | Visible deadlines/warnings/results, runtime verification, current documentation |

Execute 1 → 2 → 3. Tasks 1 and 2 edit the same state file and are deliberately serial. Task 1's new persisted fields require Task 2 before ordinary saved-game play is considered complete; do not ship the intermediate task as the feature.

Before editing an existing exported symbol, request language-server references where a GDScript server is available; otherwise use the repository search tool across scripts/tests. Resolve these callsites specifically: `get_contract`, `is_contract_available`, `accept_contract`, `proceed_contract`, `resolve_contract`, `load_profile`, `_unlock_contracts`, `_validate_contracts`, `_advance_minutes`, and the contract detail's `setup`. The known main-scene action and refresh callers are around lines 273–316, and the test consumers are in `test_game_state`, `test_contracts`, `test_main`, and `test_persistence`. Read fresh ranges before editing; line numbers below are navigation hints, not patch anchors.

## Safe verification workspace

The checked-in `tests/run_test.ps1` hard-codes the real project path. `GameState` tests save and delete `user://operator_save.json`. Do not run that wrapper unprotected.

Use this throwaway PowerShell session to stage the current working files and give the copy its own Godot user-data identity. Re-stage changed files before each focused validation; retain the same `$stage` and `$identity` during one verification session. The snippet creates no checked-in harness or dependency.

```powershell
$source = (Get-Location).Path
$godot = Join-Path (Split-Path $source -Parent) 'Godot_v4.7.1-stable_win64_console.exe'
$identity = 'OperatorDeadlineVerification-' + [guid]::NewGuid().ToString('N')
$stage = Join-Path ([IO.Path]::GetTempPath()) $identity
New-Item -ItemType Directory -Path $stage | Out-Null
function Sync-DeadlineStage {
    Get-ChildItem -LiteralPath $source -Force |
        Where-Object { $_.Name -notin @('.git', '.godot') } |
        Copy-Item -Destination $stage -Recurse -Force
    $projectFile = Join-Path $stage 'project.godot'
    $config = [IO.File]::ReadAllText($projectFile)
    $config = $config.Replace('config/name="Operator"', ('config/name="' + $identity + '"'))
    [IO.File]::WriteAllText($projectFile, $config)
}
function Invoke-DeadlineSuite([string]$Name) {
    & $godot --headless --path $stage --script "res://tests/$Name.gd"
    if ($LASTEXITCODE -ne 0) { throw "$Name failed with exit $LASTEXITCODE" }
}
Sync-DeadlineStage
& $godot --headless --editor --path $stage --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Disposable project import failed' }
```

At execution time, run multiline/looping shell setup through the harness's code-evaluation tool. Use the supervised process tool for an interactive Godot launch. Do not alter the checked-in project name or test-runner paths.

### Task 1: Publication deadlines and chronological failure

**Files:**
- Modify `data/contracts/contract_catalog.gd`: all seven definitions.
- Modify `autoload/game_state.gd`: initialization/reset, `_advance_minutes`, availability/action guards, `_unlock_contracts`; add the deadline helpers below.
- Create `tests/test_deadlines.gd` using `tests/test_base.gd`.
- Modify `tests/test_contract_catalog.gd`: defend content requirements used by expiry.

**Interfaces:**
- Consumes: existing `ContractCatalog.all()`, `ContactCatalog.by_id(id)`, `_contract_index`, `_choice`, `_settle_calendar_day`, `_add_message`, existing contract signals.
- Produces: `current_minute() -> int`, `_initialize_deadlines(at_minute: int) -> void`, `_deadline_passed(contract: Dictionary) -> bool`, `_settle_contract_deadlines(up_to_minute: int) -> bool`.
- Changes: `_unlock_contracts(ids: Array, published_at_minute: int) -> void`. Every caller passes the actual publication minute; no implicit wall-clock dependency.
- Changes `_choice`'s input annotation to `choices: Array` (same dictionary iteration and return type), because expiry and validation also consume the catalog's untyped choice arrays.
- Runtime records gain `deadline_at_minute: int`; authored records gain `deadline_window_minutes: int`.
- `proceed_contract(id) -> bool` still reports whether the action was accepted. Accepted travel that ends in failure returns true and saves; stale/invalid actions return false.

- [ ] **Step 1: Add focused boundary tests and run them red.**

Create `tests/test_deadlines.gd` with these cases. New tests use actual state transitions instead of asserting source text or helper implementation.

```gdscript
extends "res://tests/test_base.gd"

const GameStateScript := preload("res://autoload/game_state.gd")
const DELIVERY := &"cold_chain_delivery"

func _run() -> void:
	_test_offer_cutoff()
	_test_proceed_failure()
	_test_complication_cutoff()
	_test_long_advance()
	_test_midnight_tie()
	_test_simultaneous_expiry()

func _test_offer_cutoff() -> void:
	var gs := GameStateScript.new()
	var due: int = gs.get_contract(DELIVERY).deadline_at_minute
	check(gs.get_contract(&"data_retrieval").deadline_at_minute == -1,
		"unpublished work has no running deadline")
	gs.advance_minutes(due - gs.current_minute() - 1)
	check(gs.is_contract_available(gs.get_contract(DELIVERY)),
		"offer remains actionable one minute before cutoff")
	var credits: int = gs.credits
	var heat: int = gs.heat
	var standing: int = gs.standing_for(&"mara")
	gs.advance_minutes(1)
	check(gs.get_contract(DELIVERY).status == &"expired",
		"offer expires at equality within the day")
	check(not gs.accept_contract(DELIVERY), "expired offer cannot be accepted")
	check(gs.credits == credits and gs.heat == heat
		and gs.standing_for(&"mara") == standing and not gs.mara_favor_owed,
		"expiry has no reward, Heat, standing or favor effects")
	var data: Dictionary = gs.get_contract(&"data_retrieval")
	check(gs.is_contract_available(data)
		and data.deadline_at_minute == due + data.deadline_window_minutes,
		"expiry publishes an actionable successor with its full window")
	var messages: int = gs.messages.size()
	gs.advance_minutes(1)
	check(gs.messages.size() == messages, "expiry feedback occurs only once")
	check(gs.accept_contract(&"data_retrieval"), "successor can be accepted")
	check(gs.get_contract(&"data_retrieval").deadline_at_minute == data.deadline_at_minute,
		"acceptance does not renew the deadline")
	gs.free()

func _test_proceed_failure() -> void:
	var gs := GameStateScript.new()
	var c: Dictionary = gs.get_contract(DELIVERY)
	gs.advance_minutes(c.deadline_at_minute - gs.current_minute() - c.proceed_minutes)
	check(gs.accept_contract(DELIVERY), "late departure may still be accepted")
	var events: Array[StringName] = []
	gs.contract_proceeded.connect(func(_id: StringName) -> void: events.append(&"arrival"))
	gs.contract_resolved.connect(func(_id: StringName, status: StringName) -> void:
		events.append(status))
	check(gs.proceed_contract(DELIVERY), "travel is an accepted time-consuming action")
	var result: Dictionary = gs.get_contract(DELIVERY)
	check(result.status == &"failed" and result.phase == &"resolved"
		and result.resolution_id == &"deadline_missed" and gs.active_contract_id == &"",
		"travel reaching cutoff fails and frees the active slot")
	check(events == [&"failed"], "failure emits once without arrival")
	check(not gs.resolve_contract(DELIVERY, &"pay_fee") and not gs.proceed_contract(DELIVERY),
		"stale travel and resolution cannot revive deadline failure")
	check(gs.credits == gs.START_CREDITS and events == [&"failed"],
		"stale actions neither pay nor replay failure")
	gs.free()

func _test_complication_cutoff() -> void:
	var gs := GameStateScript.new()
	check(gs.accept_contract(DELIVERY) and gs.proceed_contract(DELIVERY),
		"on-time travel opens the complication")
	var due: int = gs.get_contract(DELIVERY).deadline_at_minute
	gs.advance_minutes(due - gs.current_minute())
	check(gs.get_contract(DELIVERY).status == &"failed"
		and not gs.resolve_contract(DELIVERY, &"call_mara")
		and not gs.mara_favor_owed and gs.credits == gs.START_CREDITS,
		"a complication cannot resolve for rewards after the cutoff")
	gs.free()

func _portfolio(gs: Node) -> Array:
	var result: Array = [gs.day, gs.minute_of_day, gs.credits,
		gs.rent_status, gs.next_rent_due_day, gs.active_contract_id]
	for c: Dictionary in gs.contracts:
		result.append([c.id, c.status, c.phase, c.resolution_id,
			c.is_playable, c.deadline_at_minute])
	for m: Dictionary in gs.messages:
		result.append([m.sender, m.preview])
	return result

func _test_long_advance() -> void:
	var whole := GameStateScript.new()
	var split := GameStateScript.new()
	var first_due: int = whole.get_contract(DELIVERY).deadline_at_minute
	var data_window: int = whole.get_contract(&"data_retrieval").deadline_window_minutes
	var delta: int = first_due - whole.current_minute() + data_window + 1
	whole.advance_minutes(delta)
	for minute in delta:
		split._advance_minutes(1) # same clock path, avoid hundreds of save writes
	check(_portfolio(whole) == _portfolio(split),
		"large and small advances have identical chronological consequences")
	var data: Dictionary = whole.get_contract(&"data_retrieval")
	var clinic: Dictionary = whole.get_contract(&"clinic_asset_recovery")
	var silent: Dictionary = whole.get_contract(&"silent_partner")
	check(data.status == &"expired" and clinic.is_playable
		and clinic.deadline_at_minute == first_due + data_window + clinic.deadline_window_minutes,
		"successor publication uses the crossed cutoff, not advance end")
	check(silent.is_playable and not whole.is_contract_available(silent)
		and silent.deadline_at_minute >= 0,
		"publication starts a clock even when standing prevents acceptance")
	whole._unlock_contracts([&"data_retrieval"], whole.current_minute())
	check(whole.get_contract(&"data_retrieval").status == &"expired"
		and whole.get_contract(&"data_retrieval").deadline_at_minute == data.deadline_at_minute,
		"repeated publication cannot renew or resurrect work")
	whole.free()
	split.free()

func _test_simultaneous_expiry() -> void:
	var gs := GameStateScript.new()
	check(gs.accept_contract(DELIVERY) and gs.proceed_contract(DELIVERY)
		and gs.resolve_contract(DELIVERY, &"abort"), "simultaneous fixture publishes two offers")
	var due: int = gs.current_minute() + 10
	for c: Dictionary in gs.contracts:
		if c.id in [&"data_retrieval", &"dead_drop_audit"]:
			c.deadline_at_minute = due
	var expired: Array[StringName] = []
	gs.contract_resolved.connect(func(id: StringName, status: StringName) -> void:
		if status == &"expired":
			expired.append(id))
	gs.advance_minutes(10)
	check(expired == [&"data_retrieval", &"dead_drop_audit"],
		"simultaneous deadlines settle once each in catalog order")
	var clinic: Dictionary = gs.get_contract(&"clinic_asset_recovery")
	check(clinic.deadline_at_minute == due + clinic.deadline_window_minutes,
		"simultaneous expiry publishes successors at the shared boundary")
	gs.free()

func _test_midnight_tie() -> void:
	var gs := GameStateScript.new()
	gs.next_rent_due_day = gs.day + 1
	var midnight: int = gs.day * 1440
	gs.contracts[0].deadline_at_minute = midnight
	gs.advance_minutes(midnight - gs.current_minute())
	check(gs.minute_of_day == 0 and gs.credits == gs.START_CREDITS - 2000
		and gs.next_rent_due_day == gs.day + 30,
		"midnight deadline does not skip or duplicate rent settlement")
	check(gs.get_contract(DELIVERY).status == &"expired",
		"deadline also settles at a rent boundary")
	var data: Dictionary = gs.get_contract(&"data_retrieval")
	check(data.deadline_at_minute == midnight + data.deadline_window_minutes,
		"midnight publication uses the boundary time")
	gs.free()
```

Run after staging: `Invoke-DeadlineSuite test_deadlines`. Expected before implementation: failure for the missing deadline API/fields, not a green result. The looped test deliberately exercises `_advance_minutes` to avoid excessive disk writes; assertions remain about observable contract/calendar consequences.

- [ ] **Step 2: Replace authored dates and initialize mutable cutoffs.**

Replace each catalog record's two fixed-date fields with its window and unassigned runtime cutoff:

```gdscript
"deadline_window_minutes": 259,
"deadline_at_minute": -1,
```

Use 259, 360, 480, 720, 360, 480, 720 in existing catalog order. Remove all authored `deadline_day` / `deadline_minute` values; Task 3 moves presentation to the cutoff. Keep all existing proceed durations and choices.

Add initialization and helpers in `GameState`:

```gdscript
func current_minute() -> int:
	return (day - 1) * 1440 + minute_of_day

func _initialize_deadlines(at_minute: int) -> void:
	for contract: Dictionary in contracts:
		if contract.is_playable and contract.status == &"available":
			contract.deadline_at_minute = at_minute + int(contract.deadline_window_minutes)

func _init() -> void:
	_initialize_deadlines(current_minute())

func _deadline_passed(contract: Dictionary) -> bool:
	return int(contract.deadline_at_minute) >= 0 \
		and current_minute() >= int(contract.deadline_at_minute)

func _unlock_contracts(ids: Array, published_at_minute: int) -> void:
	for id: Variant in ids:
		var index := _contract_index(StringName(str(id)))
		if index < 0:
			continue
		var contract: Dictionary = contracts[index]
		if contract.is_playable or contract.status != &"available":
			continue
		contract.is_playable = true
		contract.deadline_at_minute = published_at_minute + int(contract.deadline_window_minutes)
```

In `reset_profile()`, invoke `_initialize_deadlines(current_minute())` after rebuilding contracts and resetting the clock, before reset returns. Do not invoke it during ordinary load. Change normal resolution to `_unlock_contracts(choice.unlocks_contract_ids, current_minute())`.

Change only the shared choice helper's input annotation; keep its existing body:

```gdscript
func _choice(choices: Array, choice_id: StringName) -> Dictionary:
	for choice: Dictionary in choices:
		if choice.id == choice_id:
			return choice
	return {}
```

Add catalog assertions inside its existing contract loop, not a table that pins every balancing number:

```gdscript
check(contract.deadline_window_minutes > contract.proceed_minutes,
	"a newly published job permits an on-time journey")
check(not _choice(contract, &"abort").is_empty(),
	"every deadline outcome has an authored successor route")
```

- [ ] **Step 3: Add one deadline settlement path and integrate it into the clock.**

Use a bounded scan of the existing seven records; do not allocate a sorted event list on every tick. Each selected contract becomes terminal before the next scan, so newly published successors can be considered without duplicate expiry.

```gdscript
func _settle_contract_deadlines(up_to_minute: int) -> bool:
	var changed := false
	while true:
		var due_index := -1
		var earliest := up_to_minute + 1
		for index in contracts.size():
			var contract: Dictionary = contracts[index]
			if not contract.is_playable or (contract.status != &"available" and contract.status != &"active"):
				continue
			var cutoff := int(contract.deadline_at_minute)
			if cutoff >= 0 and cutoff <= up_to_minute and cutoff < earliest:
				due_index = index
				earliest = cutoff
		if due_index < 0:
			break
		var contract: Dictionary = contracts[due_index]
		var was_active: bool = contract.status == &"active"
		contract.status = &"failed" if was_active else &"expired"
		contract.phase = &"resolved"
		contract.resolution_id = &"deadline_missed"
		if active_contract_id == contract.id:
			active_contract_id = &""
		var abort_choice := _choice(contract.complication.choices, &"abort")
		_unlock_contracts(abort_choice.unlocks_contract_ids, earliest)
		var contact := ContactCatalog.by_id(contract.contact_id)
		push_ticker("DEADLINE MISSED // " + contract.code, true)
		_add_message(contact.display_name,
			"%s // %s: deadline missed. %s" % [contract.code, contract.title,
				"Contract failed." if was_active else "Offer expired."])
		contracts_changed.emit()
		contract_resolved.emit(contract.id, contract.status)
		changed = true
	return changed
```

Replace the body of `_advance_minutes` with boundary-based advancement. Keep `_settle_calendar_day()` housing-specific; its early returns for ownership/rent must not bypass deadline settlement.

```gdscript
func _advance_minutes(minutes: int) -> void:
	if minutes <= 0:
		return
	var target := current_minute() + minutes
	_settle_contract_deadlines(current_minute())
	while current_minute() < target:
		var midnight := day * 1440
		var boundary := mini(target, midnight)
		for contract: Dictionary in contracts:
			if contract.is_playable and (contract.status == &"available" or contract.status == &"active"):
				var cutoff := int(contract.deadline_at_minute)
				if cutoff > current_minute():
					boundary = mini(boundary, cutoff)
		day = boundary / 1440 + 1
		minute_of_day = boundary % 1440
		if boundary == midnight:
			_settle_calendar_day(day)
		_settle_contract_deadlines(boundary)
	clock_changed.emit(day, minute_of_day)
```

Use integer division in GDScript for the day conversion; if project warnings flag integer division, use `floori(float(boundary) / 1440.0)` rather than suppressing a warning. No new frame processing or timers.

- [ ] **Step 4: Guard every contract mutation and preserve terminal state after travel.**

Add the same `_deadline_passed` guard to availability and the preconditions in `proceed_contract` and `resolve_contract`:

```gdscript
func is_contract_available(contract: Dictionary) -> bool:
	return contract.is_playable and contract.status == &"available" \
		and not _deadline_passed(contract) \
		and standing_for(contract.contact_id) >= int(contract.minimum_contact_standing)
```

The proceed precondition becomes:

```gdscript
if contract.status != &"active" or contract.phase != &"ready_to_proceed" or _deadline_passed(contract):
	return false
```

Immediately after its existing `_advance_minutes(contract.proceed_minutes)` call, insert:

```gdscript
if contract.status != &"active" or active_contract_id != id:
	save_profile()
	return true
```

Only a still-active job receives `phase = customs_hold`, arrival feedback, and `contract_proceeded`. In `resolve_contract`, reject `_deadline_passed(contract)` alongside the existing active/customs checks before looking up or applying a choice. `accept_contract` already delegates to `is_contract_available`; keep that single source of truth. No method should settle deadlines from a read-only UI availability query.

- [ ] **Step 5: Run the focused state checks.**

```powershell
Sync-DeadlineStage
Invoke-DeadlineSuite test_deadlines
Invoke-DeadlineSuite test_game_state
Invoke-DeadlineSuite test_contract_catalog
```

Expected: all three suites print `RESULT: ALL PASSED`. Existing tests that manually jump the clock must not attempt newly invalid contract actions; change such setups to construct an on-time state rather than weakening deadline enforcement. Do not run the full suite until Tasks 2 and 3 have migrated save and UI consumers.

### Task 2: Persistent cutoffs and one-time legacy migration

**Files:**
- Modify `autoload/game_state.gd`: `PROFILE_VERSION`, `_read_profile_candidate`, `load_profile`, `_validate_profile`, `_validate_contracts`, `_apply_profile`; add `_migrate_v2_profile`.
- Modify `tests/test_persistence.gd`: add deadline cases, make its active-contract setup temporally valid, replace helper-only legacy migration assertions with load-through-file behavior.

**Interfaces:**
- Consumes: Task 1's `current_minute()`, `_settle_contract_deadlines(up_to_minute) -> bool`, cutoff field and terminal reason.
- Produces: `PROFILE_VERSION = 3`, `_migrate_v2_profile(data: Dictionary) -> Dictionary`.
- Changes: `_validate_contracts(raw_contracts: Variant, active_id: StringName, profile_version: int) -> String` and its single `_validate_profile` caller.
- `_migrate_v1_profile` remains the existing version-1 → version-2 contact migration stage, not an alias for the new migration.

- [ ] **Step 1: Add save/reload tests through actual files.**

Append these helper methods to `tests/test_persistence.gd` and call them at the end of `_run()`, after its existing nodes have been freed. Each case uses `reset_profile()` to isolate the disposable save paths. Retain existing recovery tests.

```gdscript
func _write_deadline_profile(payload: Dictionary) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	check(file != null, "deadline save fixture opens")
	if file == null:
		return
	file.store_string(JSON.stringify(payload))
	file.close()

func _test_deadline_round_trip() -> void:
	var gs := GameStateScript.new()
	gs.reset_profile()
	var original_due: int = gs.get_contract(&"cold_chain_delivery").deadline_at_minute
	gs.advance_minutes(30)
	check(gs.accept_contract(&"cold_chain_delivery"), "deadline round-trip accepts on time")
	var restored := GameStateScript.new()
	check(restored.load_profile(), "version-3 active profile loads")
	check(restored.get_contract(&"cold_chain_delivery").deadline_at_minute == original_due,
		"load retains remaining time rather than assigning a new window")
	restored.advance_minutes(original_due - restored.current_minute())
	var again := GameStateScript.new()
	check(again.load_profile()
		and again.get_contract(&"cold_chain_delivery").resolution_id == &"deadline_missed"
		and again.get_contract(&"cold_chain_delivery").status == &"failed"
		and again.active_contract_id == &"",
		"deadline failure round-trips without resurrection")
	again.reset_profile()
	gs.free()
	restored.free()
	again.free()

func _test_legacy_deadline_migration(version: int) -> void:
	var gs := GameStateScript.new()
	gs.reset_profile()
	check(gs.accept_contract(&"cold_chain_delivery"), "legacy fixture has an active job")
	var payload: Dictionary = gs._profile_payload()
	payload.version = version
	payload.day = 27
	payload.minute_of_day = 321
	payload.credits = 98765
	for c: Dictionary in payload.contracts:
		c.erase("deadline_at_minute")
	if version == 1:
		payload.erase("contact_standing")
		payload.contracts = payload.contracts.filter(func(c: Dictionary) -> bool:
			return c.id in [&"cold_chain_delivery", &"data_retrieval", &"clinic_asset_recovery"])
	_write_deadline_profile(payload)
	var restored := GameStateScript.new()
	check(restored.load_profile(), "legacy profile migrates through the load path")
	var c: Dictionary = restored.get_contract(&"cold_chain_delivery")
	check(restored.day == 27 and restored.minute_of_day == 321 and restored.credits == 98765
		and c.status == &"active" and c.deadline_at_minute == restored.current_minute() + c.deadline_window_minutes,
		"legacy job receives one full window without losing progress")
	var migrated_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var persisted: Dictionary = JSON.parse_string(migrated_file.get_as_text())
	migrated_file.close()
	check(persisted.version == 3, "migration is persisted immediately")
	restored.advance_minutes(1)
	var again := GameStateScript.new()
	check(again.load_profile() and again.get_contract(&"cold_chain_delivery").deadline_at_minute == c.deadline_at_minute,
		"subsequent load does not renew the migrated window")
	again.reset_profile()
	gs.free()
	restored.free()
	again.free()

func _test_overdue_deadline_load() -> void:
	var gs := GameStateScript.new()
	gs.reset_profile()
	var due: int = gs.get_contract(&"cold_chain_delivery").deadline_at_minute
	var payload: Dictionary = gs._profile_payload()
	var saved_time: int = due + 361
	payload.day = saved_time / 1440 + 1
	payload.minute_of_day = saved_time % 1440
	_write_deadline_profile(payload)
	var restored := GameStateScript.new()
	check(restored.load_profile(), "valid overdue current-version profile loads")
	check(restored.current_minute() == saved_time and restored.credits == gs.credits
		and restored.get_contract(&"cold_chain_delivery").status == &"expired"
		and restored.get_contract(&"data_retrieval").status == &"expired",
		"load reconciles historical cutoffs without advancing the clock or charging rent")
	var count: int = restored.messages.size()
	var again := GameStateScript.new()
	check(again.load_profile() and again.messages.size() == count,
		"repeated load neither replays messages nor republishes successors")
	again.reset_profile()
	gs.free()
	restored.free()
	again.free()
```

Call `_test_deadline_round_trip()`, `_test_legacy_deadline_migration(1)`, `_test_legacy_deadline_migration(2)`, and `_test_overdue_deadline_load()` from `_run()`.

Run `Invoke-DeadlineSuite test_persistence` after staging. Before implementation, deadline restoration/migration assertions must fail. Its current Day-27 active-job setup may also fail because it accepts the opening contract long after its cutoff; fix that setup in Step 4, not by relaxing enforcement.

- [ ] **Step 2: Migrate only validated legacy data and persist the migration once.**

Set `PROFILE_VERSION := 3`. Let `_read_profile_candidate` retain the existing version-1 → version-2 migration, then validate version 2 or 3. `_validate_profile` accepts only these two versions at this internal staging point and passes the actual version into `_validate_contracts`. Version-2 records do not yet require a cutoff; version-3 records do. Noninteger versions remain invalid. Guard legacy `contracts` as an Array before iterating it; malformed input follows the existing candidate-rejection path instead of throwing.

The current `_migrate_v1_profile` ends with `migrated.version = PROFILE_VERSION`; change that line to `migrated.version = 2`. Otherwise bumping the global constant would incorrectly skip the version-2 deadline migration:

```gdscript
migrated.version = 2
```

Add:

```gdscript
func _migrate_v2_profile(data: Dictionary) -> Dictionary:
	var migrated := data.duplicate(true)
	var authored := ContractCatalog.all()
	var saved_minute := (int(data.day) - 1) * 1440 + int(data.minute_of_day)
	for index in authored.size():
		var record: Dictionary = migrated.contracts[index]
		record.deadline_at_minute = -1
		if record.is_playable and (record.status == &"available" or record.status == &"active"):
			record.deadline_at_minute = saved_minute + int(authored[index].deadline_window_minutes)
	migrated.version = PROFILE_VERSION
	return migrated
```

The function consumes a validated canonical version-2 contract list; do not call it on unvalidated JSON. In `load_profile`'s successful candidate branch, use this sequence instead of immediately applying and returning:

```gdscript
var migrated := int(parsed.version) == 2
if migrated:
	parsed = _migrate_v2_profile(parsed)
	if not _validate_profile(parsed).is_empty():
		continue
_apply_profile(parsed)
var reconciled := _settle_contract_deadlines(current_minute())
if migrated or reconciled:
	save_profile()
return true
```

`save_profile()` already reports a write failure and protects the prior file. A write failure here must not reset successfully loaded in-memory progress or pretend persistence succeeded. `load_profile()` still reports that loading succeeded; the save error remains visible. A subsequent retry of an unpersisted migration uses the unchanged legacy saved clock, so it cannot manufacture extra time relative to that save.

- [ ] **Step 3: Restore and validate deadline state, without trusting saved content.**

`_profile_payload` already serializes runtime contracts; no second deadline map is needed. Add only `deadline_at_minute` to `_apply_profile`'s mutable-field copy list:

```gdscript
for key in [&"is_playable", &"status", &"phase", &"resolution_id", &"deadline_at_minute"]:
	restored_contracts[index][key] = record[key]
```

Keep the catalog's authored windows and choices; never restore serialized `deadline_window_minutes` or reward data.

In `_validate_contracts`, add `expired` to the status set only for version 3. Continue validating types before conversions. Add the following version-3 cutoff checks after `status` and `phase` are parsed:

```gdscript
if profile_version == 3:
	if not _is_int_value(record.get("deadline_at_minute", null)):
		return "profile contract deadline is invalid"
	var cutoff := int(record.deadline_at_minute)
	if cutoff < -1:
		return "profile contract deadline is invalid"
	if not record.is_playable and cutoff != -1:
		return "profile unpublished contract deadline is invalid"
	if record.is_playable and (status == &"available" or status == &"active") and cutoff < 0:
		return "profile published contract deadline is missing"
	if record.resolution_id == &"deadline_missed":
		if not record.is_playable or cutoff < 0 or phase != &"resolved" \
				or (status != &"expired" and status != &"failed"):
			return "profile deadline outcome is invalid"
	elif status == &"expired":
		return "profile expired contract reason is invalid"
```

Extend the existing terminal phase branch to include `expired`. For normal completed/failed records, verify the resolution ID exists in that record's authored complication choices and its `terminal_status` agrees; do not look up `deadline_missed` as an authored choice. Reject `deadline_missed` in version 2. Enforce that an active record is published and that its ID equals `active_id`, in addition to the existing active-count constraints. Legacy terminal records with cutoff `-1` remain valid.

Add a malformed-save case using actual loading, then reuse it for two distinct corruptions (noninteger cutoff and illegal terminal reason):

```gdscript
func _test_invalid_deadline_profile() -> void:
	var gs := GameStateScript.new()
	gs.reset_profile()
	var payload: Dictionary = gs._profile_payload()
	payload.credits = 98765
	payload.contracts[0].deadline_at_minute = "tomorrow"
	_write_deadline_profile(payload)
	var restored := GameStateScript.new()
	check(not restored.load_profile() and restored.credits == restored.START_CREDITS,
		"malformed cutoff follows existing invalid-profile recovery")
	restored.reset_profile()
	payload = restored._profile_payload()
	payload.contracts[0].status = &"completed"
	payload.contracts[0].phase = &"resolved"
	payload.contracts[0].resolution_id = &"deadline_missed"
	_write_deadline_profile(payload)
	check(not restored.load_profile(), "deadline-missed cannot be a successful completion")
	restored.reset_profile()
	gs.free()
	restored.free()
```

Call it from `_run()` after the other added cases. Tests run in the disposable identity; the existing invalid-profile reset behavior is not being redesigned.

- [ ] **Step 4: Update the old save fixture and run persistence coverage.**

The existing test sets Day 27 before accepting the opening job. Keep its scalar save coverage but create a fresh published window at that synthetic clock:

```gdscript
clean.contracts[0].deadline_at_minute = clean.current_minute() + int(clean.contracts[0].deadline_window_minutes)
check(clean.accept_contract(&"cold_chain_delivery"), "contract mutation setup succeeds")
```

This is test fixture construction only, not a gameplay deadline reset API. Replace the direct `_migrate_v1_profile` assertion block with the new version-1 file-load test; do not simply re-pin an internal migration version number. Ensure hand-built `GameStateScript.new()` nodes in save tests remain internally coherent.

```powershell
Sync-DeadlineStage
Invoke-DeadlineSuite test_persistence
Invoke-DeadlineSuite test_deadlines
```

Expected: successful current/legacy round-trips, idempotent overdue recovery, rejected malformed profiles, and existing atomic-file fallback tests all pass. Expected error output from deliberate invalid/write-failure cases is not a reason to suppress diagnostics.

### Task 3: Player-facing deadlines, runtime proof, and documentation

**Files:**
- Modify `scenes/modules/contracts/contracts_panel.gd`: expired row state.
- Modify `scenes/modules/contracts/contract_detail.gd`: time details/warning and system terminal outcome.
- Modify `scenes/main/main.gd`: refresh selected contract detail when the clock changes.
- Modify `tests/test_contracts.gd`, `tests/test_main.gd`: remove broken incidental assertions; keep/add behavioral edge coverage below.
- Modify existing `README.md`, `context.md`, `next-features.md` after runtime proof.

**Interfaces:**
- Consumes: injected `gs.current_minute()`, `deadline_at_minute`, `proceed_minutes`, `resolution_id = deadline_missed`, existing `clock_changed`, `contracts_changed`, and acknowledgement flow.
- Produces: detail helpers `_deadline_text(c: Dictionary) -> String`, `_render_timing_warning(gs: Node, c: Dictionary) -> void`, `_render_deadline_result(c: Dictionary) -> void`.
- Changes internal render signatures to `_render_offer(gs: Node, c: Dictionary)` and `_render_ready(gs: Node, c: Dictionary)`; update both `setup` dispatch calls. No additional state singleton access.

- [ ] **Step 1: Render expired rows and deadline results before authored-choice lookup.**

Add a row branch in the existing status match:

```gdscript
&"expired":
	return "EXPIRED // " + contract.title
```

The existing selectable predicate already disables terminal records. Keep unpublished and standing-gated row presentation otherwise unchanged.

In the detail panel's `_render_resolved`, branch before `_choice(c, c.resolution_id)`:

```gdscript
if c.resolution_id == &"deadline_missed":
	_render_deadline_result(c)
	return
```

Add:

```gdscript
func _render_deadline_result(c: Dictionary) -> void:
	_body.add_theme_color_override("font_color", COLOR_DIM)
	_title.text = "OFFER EXPIRED" if c.status == &"expired" else "CONTRACT FAILED"
	_body.text = "\n".join([
		c.title,
		"RESULT      DEADLINE MISSED",
		_deadline_text(c),
		"CREDITS     +0 CR",
		"HEAT        +0",
	])
	_add_action("ACKNOWLEDGE", func() -> void: acknowledge_requested.emit())
```

Do not invent a dummy authored choice or insert `deadline_missed` into the complication menu. Keep normal completion and player-abort result rendering unchanged.

- [ ] **Step 2: Show calculated timing and late-arrival risk without a new panel.**

Rename `setup`'s `_gs` parameter to `gs` and pass it to `_render_offer` / `_render_ready`. Replace each old fixed-date format block with `_deadline_text(c)` plus the execution-duration line. Use the same helper for both screens:

```gdscript
func _deadline_text(c: Dictionary) -> String:
	var cutoff := int(c.deadline_at_minute)
	if cutoff < 0:
		return "DEADLINE    NOT PUBLISHED"
	var due_day: int = cutoff / 1440 + 1
	var due_minute := cutoff % 1440
	return "DEADLINE    DAY %d // %02d:%02d" % [
		due_day, floori(due_minute / 60.0), due_minute % 60,
	]

func _render_timing_warning(gs: Node, c: Dictionary) -> void:
	if gs.current_minute() + int(c.proceed_minutes) >= int(c.deadline_at_minute):
		_add_preview("WARNING // PROCEEDING WILL MISS THE DEADLINE")
```

Add `"EXECUTION   %d MIN" % c.proceed_minutes` to both offer/ready body arrays. Invoke `_render_timing_warning(gs, c)` before their action buttons. The warning uses text as well as existing styling; do not rely on color alone. It does not disable a still-valid action.

In `main.gd`, connect `clock_changed` near the existing state-signal connections:

```gdscript
gs.clock_changed.connect(func(_day: int, _minute: int) -> void:
	if gs.active_module == &"contracts" and gs.module_open \
			and _selected_contract_id != &"" and context_host.get_child_count() > 0:
		context_host.get_child(0).setup(gs, gs.get_contract(_selected_contract_id)))
```

Keep `_on_contracts_changed` for list/terminal refresh. Do not replay contract audio on clock or panel refreshes; only the existing semantic events trigger it. Check the references before adding this connection in case an existing connection already covers the selected detail.

- [ ] **Step 3: Defend deadline-result rendering and stale-action removal.**

In `tests/test_contracts.gd`, reuse its `_text` / `_button` helpers for this focused scenario, inserted before the detail is freed:

```gdscript
var late_gs := GameStateScript.new()
var late: Dictionary = late_gs.get_contract(&"cold_chain_delivery")
late_gs.advance_minutes(late.deadline_at_minute - late_gs.current_minute() - late.proceed_minutes)
check(late_gs.accept_contract(late.id), "late UI scenario accepts on time")
detail.setup(late_gs, late_gs.get_contract(late.id))
check(_text(detail).contains("WARNING") and _button(detail, "PROCEED TO DOCK 17") != null,
	"late-arrival risk is visible while proceeding remains a player choice")
check(late_gs.proceed_contract(late.id), "late UI journey advances time")
detail.setup(late_gs, late_gs.get_contract(late.id))
check(_text(detail).contains("DEADLINE MISSED")
	and _button(detail, "ACKNOWLEDGE") != null
	and _button(detail, "PROCEED TO DOCK 17") == null
	and _button(detail, "PAY CLEARANCE FEE // 250 CR") == null,
	"deadline result explains failure and removes stale gameplay actions")
late_gs.free()
```

The currently hard-coded `DAY 15 // 04:00` assertion in the old offer test pins an incidental value; remove it rather than re-pinning a new balancing value. Retain the new cutoff boundary tests as the authority on gameplay timing. Where source changes break other wording-only/internal-field assertions, remove those assertions instead of expanding the snapshot surface.

For integration, exercise the selected detail through the actual main scene during the smoke below; do not create a second mocked main-scene fixture solely to assert the added signal connection. Existing normal accepted/proceeded/failed audio tests in `test_main.gd` must still pass.

- [ ] **Step 4: Run focused UI checks, then the complete existing suite once.**

```powershell
Sync-DeadlineStage
Invoke-DeadlineSuite test_contracts
Invoke-DeadlineSuite test_main
Get-ChildItem -LiteralPath (Join-Path $stage 'tests') -Filter 'test_*.gd' |
    ForEach-Object { Invoke-DeadlineSuite $_.BaseName }
```

Expected: every suite prints `RESULT: ALL PASSED`, with zero nonzero exits. Use the staged direct invocation, not `run_all.ps1` (which delegates to the hard-coded real-project runner). Any new parser errors, crashes, lost save progress, or stale actions block completion.

- [ ] **Step 5: Verify the real UI in the disposable project.**

Launch the staged project normally and use a fresh profile:

1. Open Contracts and the first offer. Confirm the Day/Time cutoff and 80-minute execution duration are legible.
2. Close the detail, open Home, and REST to Day 15 00:00; the opening offer remains available. REST again to Day 16 00:00; the opening offer is EXPIRED, not selectable, and successors have been processed according to their own windows. Confirm Comms explains missed jobs without rewards or new Heat.
3. Stop the disposable game before preparing the late-active scenario.

Create this throwaway script only in the staged copy as `deadline_smoke.gd`:

```gdscript
extends SceneTree
const GameStateScript := preload("res://autoload/game_state.gd")
func _init() -> void:
	var gs := GameStateScript.new()
	gs.reset_profile()
	var c: Dictionary = gs.get_contract(&"cold_chain_delivery")
	gs.advance_minutes(c.deadline_at_minute - gs.current_minute() - c.proceed_minutes)
	assert(gs.accept_contract(c.id))
	assert(gs.save_profile())
	print("Deadline smoke profile ready; user data: ", OS.get_user_data_dir())
	gs.free()
	quit()
```

Run its finite seed command, then relaunch the normal staged game through the supervised process tool:

```powershell
& $godot --headless --path $stage --script res://deadline_smoke.gd
if ($LASTEXITCODE -ne 0) { throw 'Deadline smoke seed failed' }
```

Continue the saved profile, open Contracts, select the active delivery, and confirm the late-arrival warning. Press PROCEED. The detail must immediately show deadline failure with ACKNOWLEDGE; no customs-choice buttons appear, the failure cue plays once, and the active slot is freed. Acknowledge, select Data Retrieval, and confirm it is usable with its own calculated deadline. Relaunch once more: no deadline renewal or duplicate failure message.

Use available Godot runtime/debug tools and screenshots or direct surface inspection for evidence. If graphical interaction is unavailable, explicitly report that visual verification was not performed; exercise the actual main scene with a disposable smoke driver rather than claiming screenshots or a playthrough. Record the user-data directory printed by the seed so cleanup targets are known.

- [ ] **Step 6: Update current documentation after runtime proof, then remove disposable artifacts.**

Update existing documentation only:

- `README.md`: current status now includes publication-relative enforced deadlines and hard expiry/failure; describe saving the remaining window rather than renewing it. Keep the early-prototype and no-combat boundaries.
- `context.md`: add the deadline vocabulary and implemented behavior under current implementation; do not rewrite historical design intent or claim recovery content exists.
- `next-features.md`: mark the deadline item implemented, link the approved spec, and replace its stale display-only/midnight-only assertions. State that the accepted design uses publication windows instead of fixed calendar dates. Leave Heat, preparation, and favors as future work.

Suggested factual addition for README/context:

```text
Published contracts have persistent game-time deadlines. Unaccepted offers expire; active jobs fail at the cutoff. Deadline outcomes publish the same successors as an abort without paying rewards or changing Heat, standing, or favors. Acceptance and reload do not extend the window.
```

No changelog currently exists; do not create one just for this feature. Stop the verification process and remove the temporary seed, staged project, and only the unique verification user-data directory reported by the smoke. Never delete or reset the real Operator profile.

## Completion evidence

The final implementation report must name:

- Focused suites and full-suite outcome actually observed, not merely commands proposed here.
- The real UI scenario exercised, or the explicit graphical-verification limitation and substitute main-scene smoke result.
- Confirmation that current-version reload preserved cutoffs and legacy migration preserved progress.
- Any actual deviations from the approved specification; obtain approval before narrowing behavior.

## Plan self-review / coverage map

| Approved requirement | Implementation / proof |
|---|---|
| Publication windows, unpublished immunity, standing gates | Task 1 Steps 1–2; delayed successors and gated published job |
| Equality cutoff and same-day expiry | Task 1 offer and travel boundary cases |
| Hard failure, no rewards/penalties, no duplicate actions | Task 1 settlement and action guards; complication and stale-action cases |
| Chronological successors, long rests, midnight rent ordering | Task 1 clock loop; long-advance equivalence and midnight tie |
| Persisted cutoffs, v1/v2 migration, validation, overdue reconciliation | Task 2 load-through-file cases and validation changes |
| Calculated dates, duration, warning, expired rows, result acknowledgement | Task 3 UI edits, focused result case, real main-scene smoke |
| No player-save damage, no extra subsystems | Disposable verification identity; explicit file map and non-goals |
| Existing behavior and current docs retained | Final suite plus post-smoke updates to the three existing docs |
