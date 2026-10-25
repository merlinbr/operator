# Partial Resolutions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a contract resolve as `partial` when the player arrives above a route's Heat threshold, paying authored degraded rewards instead of hiding the route.

**Architecture:** Authored data on the choice (`partial_above_heat` + a `partial` block) plus one resolver in `GameState` (`_effective_outcome`) that every effect and every surface reads from. No new saved fields, no profile migration; the new `partial` status flows through the four existing consumers (validation, contract detail, contract list, dossier).

**Tech Stack:** Godot 4.7.1, GDScript, headless `SceneTree` test harness (no framework).

**Spec:** `docs/superpowers/specs/2026-10-25-partial-resolutions-design.md`

## Global Constraints

- Godot 4.7.1. Run one suite with `.\tests\run_test.ps1 <suite>` from the repo root; it passes when it prints `RESULT: ALL PASSED`. Run all with `.\tests\run_all.ps1`.
- `PROFILE_VERSION` stays `5`. No new saved keys, no migration, no new `_profile_payload()` field.
- Degradation fires on `heat > partial_above_heat`, never on `>=`.
- A degraded outcome keeps the choice's `heat_delta`, `mara_favor_delta`, `unlocks_contract_ids`, and `message_sender`. Only Credits, contact standing, `result`, `ticker`, `message_preview`, and `preview` change.
- `partial.credit_delta` may equal the clean `credit_delta` but never exceed it.
- After Task 1 no `max_heat` key exists anywhere. `min_heat` is untouched.
- No randomness in resolution. Deadline proximity is out of scope.
- Gates receive `GameState` through `setup()` injection, never the autoload global.
- Test convention: `check(cond, message)` from `res://tests/test_base.gd`; tests instantiate `GameStateScript.new()` without `add_child` unless the test needs `_ready()`.

## Review Focus

- A saved contract that is both `partial` and has `prep_paid_credits > 0` is rejected by the preparation-integrity rule in `_validate_contracts`, resetting the whole profile. Task 1 widens the rule; Task 4 tests it.
- `_available_choices()` used to append catalog dictionaries by reference. Substituting a degraded `preview` requires duplicating each entry first, or a degraded preview leaks into live state. Task 1 tests snapshot detachment.
- A catalog entry with `partial` but no `partial_above_heat` (or the reverse) silently never degrades. Task 1 pins both directions as a catalog invariant.
- A degraded route must publish exactly the clean successor set, once. Task 1 tests the successor set after a degraded resolution.
- A `partial` contract in the contracts list must read `PARTIAL // <title>` and stay non-selectable rather than falling through to the reward-row format. Task 2 tests the row.
- A purchased preparation that degrades must state the lost standing in the preview *before* the player commits. Task 4 tests the rendered preview.

---

### Task 1: Degradation rule, catalog data, and validation

**Files:**
- Modify: `data/contracts/contract_catalog.gd` (D-207 `spoof_credentials`; M-613 `buy_silence`; delete M-613 `buy_intermediary_silence`)
- Modify: `autoload/game_state.gd` (`_available_choices` 781-796, `resolve_contract` 904-950, `_validate_contracts` 421-507, new `_effective_outcome`)
- Create: `tests/test_partial_resolutions.gd`
- Modify: `tests/test_contract_catalog.gd:41-43`
- Modify: `tests/test_game_state.gd:103-147`
- Modify: `tests/test_persistence.gd:297`
- Modify: `tests/test_contracts.gd:185-204`

**Interfaces:**
- Consumes: catalog keys `partial_above_heat: int` and `partial: {credit_delta, contact_standing_delta, result, ticker, message_preview, preview}`.
- Produces: `GameState._effective_outcome(choice: Dictionary) -> Dictionary` with keys `credit_delta: int`, `contact_standing_delta: int`, `result: String`, `ticker: String`, `message_preview: String`, `message_sender: String`, `terminal_status: StringName` (`&"partial"` when degraded).
- Produces: every entry returned by `get_contract(id).complication.choices` carries the substituted degraded `preview` when degradation applies. Task 4 adds `partial_now: bool` to the same entries.

- [ ] **Step 1: Write the failing test**

Create `tests/test_partial_resolutions.gd`:

```gdscript
extends "res://tests/test_base.gd"

const GameStateScript := preload("res://autoload/game_state.gd")

func _reach_data(gs: Node, heat: int) -> void:
	check(gs.accept_contract(&"cold_chain_delivery"), "C-1042 accept setup succeeds")
	check(gs.proceed_contract(&"cold_chain_delivery"), "C-1042 proceed setup succeeds")
	check(gs.resolve_contract(&"cold_chain_delivery", &"pay_fee"), "C-1042 resolution setup succeeds")
	gs.heat = heat
	check(gs.accept_contract(&"data_retrieval"), "D-207 accept setup succeeds")
	check(gs.proceed_contract(&"data_retrieval"), "D-207 proceed setup succeeds")

func _reach_silent_partner(gs: Node, heat: int) -> void:
	check(gs.accept_contract(&"cold_chain_delivery"), "C-1042 accept setup succeeds")
	check(gs.proceed_contract(&"cold_chain_delivery"), "C-1042 proceed setup succeeds")
	check(gs.resolve_contract(&"cold_chain_delivery", &"call_mara"), "C-1042 setup calls Mara")
	check(gs.accept_contract(&"data_retrieval"), "D-207 accept setup succeeds")
	check(gs.proceed_contract(&"data_retrieval"), "D-207 proceed setup succeeds")
	check(gs.resolve_contract(&"data_retrieval", &"buy_token"), "D-207 setup buys a token")
	gs.heat = heat
	check(gs.accept_contract(&"silent_partner"), "M-613 accept setup succeeds")
	check(gs.proceed_contract(&"silent_partner"), "M-613 proceed setup succeeds")

func _run() -> void:
	_test_threshold_boundary()
	_test_degraded_effects()
	_test_silent_partner_degradation()
	_test_partial_survives_reload()
	var cleanup := GameStateScript.new()
	cleanup.reset_profile()
	cleanup.free()

func _test_threshold_boundary() -> void:
	var clean := GameStateScript.new()
	_reach_data(clean, 3)
	var credits: int = clean.credits
	var standing: int = clean.standing_for(&"mara")
	check(clean.resolve_contract(&"data_retrieval", &"spoof_credentials"),
		"D-207 spoof resolves at its threshold")
	check(clean.get_contract(&"data_retrieval").status == &"completed"
		and clean.credits == credits + 4200
		and clean.standing_for(&"mara") == mini(standing + 1, 2),
		"Heat 3 keeps the clean spoof outcome")
	clean.free()

	var dirty := GameStateScript.new()
	_reach_data(dirty, 4)
	credits = dirty.credits
	standing = dirty.standing_for(&"mara")
	check(dirty.resolve_contract(&"data_retrieval", &"spoof_credentials"),
		"D-207 spoof still resolves one point above the threshold")
	check(dirty.get_contract(&"data_retrieval").status == &"partial"
		and dirty.credits == credits + 3900
		and dirty.standing_for(&"mara") == standing
		and dirty.heat == 4,
		"Heat 4 degrades spoof to the authored payout with no standing gain")
	dirty.free()

func _test_degraded_effects() -> void:
	var gs := GameStateScript.new()
	_reach_data(gs, 4)
	var preview := ""
	for choice: Dictionary in gs.get_contract(&"data_retrieval").complication.choices:
		if choice.id == &"spoof_credentials":
			preview = String(choice.preview)
	check(preview.contains("CONTRACT PARTIAL") and preview.contains("3,900"),
		"a dirty arrival sees the degraded preview before committing")
	check(gs.get_contract(&"data_retrieval").complication.choices.any(
		func(choice: Dictionary) -> bool: return choice.id == &"spoof_credentials"),
		"spoof stays available above its Heat threshold")
	var snapshot: Dictionary = gs.get_contract(&"data_retrieval")
	snapshot.complication.choices[0].preview = "MUTATED"
	check(not String(gs.get_contract(&"data_retrieval").complication.choices[0].preview)
		.contains("MUTATED"), "degraded snapshots are detached from live state")
	check(gs.resolve_contract(&"data_retrieval", &"spoof_credentials"), "degraded spoof resolves")
	check(gs.get_contract(&"silent_partner").is_playable
		and gs.get_contract(&"clinic_asset_recovery").is_playable,
		"a degraded outcome publishes exactly the clean successors")
	gs.free()

func _test_silent_partner_degradation() -> void:
	var low := GameStateScript.new()
	_reach_silent_partner(low, 5)
	var credits: int = low.credits
	check(low.resolve_contract(&"silent_partner", &"buy_silence")
		and low.credits == credits + 4700
		and low.get_contract(&"silent_partner").status == &"completed",
		"Heat 5 keeps custodian silence clean")
	low.free()

	var high := GameStateScript.new()
	_reach_silent_partner(high, 6)
	credits = high.credits
	var standing: int = high.standing_for(&"mara")
	var favor: int = high.mara_favor_balance
	check(not high.get_contract(&"silent_partner").complication.choices.any(
		func(choice: Dictionary) -> bool: return choice.id == &"buy_intermediary_silence"),
		"the duplicated intermediary route is gone")
	check(high.resolve_contract(&"silent_partner", &"buy_silence")
		and high.credits == credits + 4300 and high.heat == 6
		and high.standing_for(&"mara") == standing and high.mara_favor_balance == favor
		and high.get_contract(&"silent_partner").status == &"partial",
		"Heat 6 degrades custodian silence to the intermediary outcome")
	high.free()

func _test_partial_survives_reload() -> void:
	var gs := GameStateScript.new()
	_reach_data(gs, 4)
	check(gs.resolve_contract(&"data_retrieval", &"spoof_credentials"), "partial outcome resolves")
	check(gs.save_profile(), "partial outcome saves")
	var restored := GameStateScript.new()
	check(restored.load_profile(), "a profile containing a partial outcome loads")
	check(restored.get_contract(&"data_retrieval").status == &"partial"
		and restored.get_contract(&"data_retrieval").resolution_id == &"spoof_credentials",
		"reload keeps the recorded partial outcome")
	restored.free()
	gs.free()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `.\tests\run_test.ps1 test_partial_resolutions`
Expected: FAIL — `spoof` resolves `completed` at Heat 4, `buy_intermediary_silence` still exists.

- [ ] **Step 3: Author the catalog data**

In `data/contracts/contract_catalog.gd`, on D-207 `spoof_credentials` replace `"max_heat": 3` with:

```gdscript
					"partial_above_heat": 3,
					"partial": {
						"credit_delta": 3900,
						"contact_standing_delta": 0,
						"result": "SPOOF PARTIALLY ACCEPTED // SHARD RETRIEVED // AUDIT FLAG",
						"ticker": "CONTRACT PARTIAL // +3,900 CR",
						"message_preview": "You have the shard. The audit kept a copy of your credential.",
						"preview": "+3,900 CR // HEAT +0 // CONTRACT PARTIAL",
					},
```

On M-613 `buy_silence` replace `"max_heat": 5` with `"partial_above_heat": 5` and the matching `partial` block, reusing the intermediary wording and payout:

```gdscript
					"partial_above_heat": 5,
					"partial": {
						"credit_delta": 4300,
						"contact_standing_delta": 0,
						"result": "ELEVATED SCRUTINY REQUIRES INTERMEDIARY // FILE RELEASED",
						"ticker": "CONTRACT PARTIAL // INTERMEDIARY // +4,300 CR",
						"message_preview": "Elevated scrutiny requires an intermediary; the file is still yours.",
						"preview": "ELEVATED SCRUTINY // INTERMEDIARY REQUIRED // +4,300 CR // HEAT +0 // CONTRACT PARTIAL",
					},
```

Delete the entire `buy_intermediary_silence` entry from M-613's `choices`.

- [ ] **Step 4: Add `_effective_outcome` and route effects through it**

In `autoload/game_state.gd`, add below `_choice(choices, choice_id)`:

```gdscript
func _effective_outcome(choice: Dictionary) -> Dictionary:
```

It returns the seven keys listed in Interfaces, taken from `choice`. When `choice.has("partial")` and `heat > int(choice.partial_above_heat)`, it takes `credit_delta`, `contact_standing_delta`, `result`, `ticker`, and `message_preview` from the `partial` block and sets `terminal_status = &"partial"`.

In `_available_choices`, keep the `requires_prep`, `min_heat`, and `requires_mara_balance` filters, delete the `max_heat` filter, and append `choice.duplicate(true)` instead of `choice`. When the duplicate has a `partial` block and `heat > partial_above_heat`, set `entry.preview = String(entry.partial.preview)`.

In `resolve_contract`, resolve `var outcome := _effective_outcome(choice)` after the existing emptiness check and use `outcome.credit_delta`, `outcome.contact_standing_delta`, and `outcome.terminal_status` in place of the choice's own fields. `choice.heat_delta`, `choice.mara_favor_delta`, and `choice.unlocks_contract_ids` stay as they are. For the existing `trace_tag` debt-settled case, set `outcome.message_preview` to the existing replacement string and pass `outcome` to `_push_resolution_feedback`.

- [ ] **Step 5: Accept `partial` in the four validation sites**

In `_validate_contracts`:

1. Append `&"partial"` to `valid_statuses`.
2. Widen the preparation-integrity condition (`paid > 0 and (...)`) to allow `status == &"partial"`.
3. Widen the terminal branch guard `elif status == &"completed" or status == &"failed" or status == &"expired":` to include `&"partial"`.
4. Where the recorded resolution is checked against `choice.terminal_status != status`, also accept `status == &"partial"` when `choice.has("partial")`. Do not re-derive from current Heat.

- [ ] **Step 6: Run the new test to verify it passes**

Run: `.\tests\run_test.ps1 test_partial_resolutions`
Expected: `RESULT: ALL PASSED`

- [ ] **Step 7: Update the tests the change invalidates**

`tests/test_contract_catalog.gd:41-43` becomes:

```gdscript
	check(_choice(data_retrieval, &"spoof_credentials").partial_above_heat == 3
		and _choice(data_retrieval, &"routed_vendor_id").min_heat == 4,
		"D-207 prices high Heat on spoofing instead of hiding it")
```

Add this loop after the existing per-contract loop at the end of `_run`:

```gdscript
	for contract: Dictionary in contracts:
		for choice: Dictionary in contract.complication.choices:
			check(not choice.has("max_heat"), "no response hides itself at high Heat")
			check(choice.has("partial") == choice.has("partial_above_heat"),
				"every degraded form has a threshold and every threshold a degraded form")
			if choice.has("partial"):
				check(int(choice.partial.credit_delta) <= int(choice.credit_delta),
					"a degraded payout never exceeds the clean payout")
	check(not contracts.any(func(contract: Dictionary) -> bool:
		return contract.complication.choices.any(func(choice: Dictionary) -> bool:
			return choice.id == &"buy_intermediary_silence")),
		"the duplicated intermediary route is not authored")
```

Replace the body of `_test_silent_partner_heat_choices` in `tests/test_game_state.gd` (lines 104-147) with a loop over `[5, 6]` that asserts, for each Heat: M-613 accepts and proceeds; `mirror_archive`, `abort`, and `buy_silence` are all present; `buy_intermediary_silence` is absent; `call_in_mara_favor` is rejected (balance is `-1`, so the `+1` requirement fails) without mutating credits, `active_contract_id`, or phase; then `buy_silence` resolves paying 4,700 with status `&"completed"` at Heat 5, and 4,300 with status `&"partial"` at Heat 6, with Heat unchanged in both cases. Keep the existing `gs.reset_profile()` / `gs.free()` teardown per iteration.

In `tests/test_persistence.gd:297`, change the rejected id from `&"buy_intermediary_silence"` to `&"nonexistent_choice"` and the message to `"unknown M-613 choice is rejected"`.

In `tests/test_contracts.gd`, change line 185-186 to assert `_button(detail, "SPOOF SERVICE CREDENTIALS") != null` with message `"high-Heat D-207 keeps spoof credentials available"`. Replace 195-204 with a lookup of `&"buy_silence"` from `high_heat_silent.complication.choices` asserting `_button(detail, degraded.label) != null` and `_text(detail).contains(degraded.preview)` for `"high-Heat Silent Partner renders the degraded silence preview"`, plus `_button(detail, "BUY INTERMEDIARY SILENCE // 1,300 CR") == null` for `"high-Heat Silent Partner no longer offers the duplicate intermediary route"`.

- [ ] **Step 8: Run the affected suites**

Run: `.\tests\run_test.ps1 test_partial_resolutions`, then `test_contract_catalog`, `test_game_state`, `test_persistence`, `test_contracts`.
Expected: each prints `RESULT: ALL PASSED`.

- [ ] **Step 9: Commit**

```bash
git add data/contracts/contract_catalog.gd autoload/game_state.gd tests/test_partial_resolutions.gd tests/test_contract_catalog.gd tests/test_game_state.gd tests/test_persistence.gd tests/test_contracts.gd
git commit -m "feat: resolve contracts as partial when arriving dirty"
```

---

### Task 2: Resolved screen and contract list

**Files:**
- Modify: `scenes/modules/contracts/contract_detail.gd:155-172`
- Modify: `scenes/modules/contracts/contracts_panel.gd:64-74`
- Modify: `autoload/game_state.gd` (`get_contract`, end of function)
- Test: `tests/test_contracts.gd`

**Interfaces:**
- Consumes: `get_contract(id).status == &"partial"` and the recorded `resolution_id` from Task 1.
- Produces: `get_contract(id)` returns the recorded choice with `credit_delta`, `contact_standing_delta`, and `result` replaced by the `partial` block when the contract resolved partial. `preparation.choice` aliases that same dictionary, so one substitution covers both.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_contracts.gd` before the final cleanup, using the existing `detail`, `panel`, `_button`, and `_text` helpers:

```gdscript
	var partial_gs := GameStateScript.new()
	check(partial_gs.accept_contract(&"cold_chain_delivery"), "partial screen accepts C-1042")
	check(partial_gs.proceed_contract(&"cold_chain_delivery"), "partial screen proceeds C-1042")
	check(partial_gs.resolve_contract(&"cold_chain_delivery", &"pay_fee"), "partial screen resolves C-1042")
	partial_gs.heat = 4
	check(partial_gs.accept_contract(&"data_retrieval"), "partial screen accepts D-207")
	check(partial_gs.proceed_contract(&"data_retrieval"), "partial screen proceeds D-207")
	check(partial_gs.resolve_contract(&"data_retrieval", &"spoof_credentials"),
		"partial screen degrades D-207")
	detail.setup(partial_gs, partial_gs.get_contract(&"data_retrieval"))
	check(_text(detail).contains("CONTRACT PARTIAL"), "resolved screen names the partial outcome")
	check(_text(detail).contains("SPOOF PARTIALLY ACCEPTED"),
		"resolved screen shows the degraded result text")
	check(_text(detail).contains("+3,900"), "resolved screen shows the degraded payout")
	panel.setup(partial_gs, partial_gs.contracts)
	var partial_row: Button = null
	for child in panel.find_children("*", "Button", true, false):
		if child.text.contains("DATA RETRIEVAL"):
			partial_row = child
	check(partial_row != null and partial_row.text.contains("PARTIAL // DATA RETRIEVAL")
		and partial_row.disabled, "the contracts list shows a disabled partial row")
	partial_gs.free()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `.\tests\run_test.ps1 test_contracts`
Expected: FAIL — the resolved title reads `CONTRACT FAILED` and the D-207 row reads `DATA RETRIEVAL   4,200 CR`.

- [ ] **Step 3: Substitute the degraded outcome in `get_contract`**

At the end of `get_contract`, when `snapshot.phase == &"resolved"` and `snapshot.status == &"partial"`, find the recorded choice in `snapshot.complication.choices` by `snapshot.resolution_id` and copy `credit_delta`, `contact_standing_delta`, and `result` from its `partial` block onto it. Skip silently when the recorded choice is missing or has no `partial` block.

- [ ] **Step 4: Title the resolved screen and label the list row**

In `contract_detail._render_resolved`, replace the one-line title assignment with a `match c.status` that sets `"CONTRACT COMPLETE"`, `"CONTRACT PARTIAL"`, and `"CONTRACT FAILED"` for `&"completed"`, `&"partial"`, and everything else.

In `contracts_panel._row_text`, add a `&"partial":` case to the existing `match` returning `"PARTIAL // " + contract.title`.

- [ ] **Step 5: Run the test to verify it passes**

Run: `.\tests\run_test.ps1 test_contracts`
Expected: `RESULT: ALL PASSED`

- [ ] **Step 6: Commit**

```bash
git add scenes/modules/contracts/contract_detail.gd scenes/modules/contracts/contracts_panel.gd autoload/game_state.gd tests/test_contracts.gd
git commit -m "feat: show partial outcomes in the contract screens"
```

---

### Task 3: Dossier counts and record

**Files:**
- Modify: `autoload/game_state.gd` (`dossier_snapshot` 264-300)
- Modify: `scenes/modules/dossier/dossier_panel.gd:47-52`
- Test: `tests/test_dossier.gd`

**Interfaces:**
- Consumes: contracts whose `status` is `&"partial"` (Task 1).
- Produces: `dossier_snapshot().signature` gains a `partial: int` key. The four counters are mutually exclusive: a partial operation increments only `partial`.

- [ ] **Step 1: Write the failing test**

In `tests/test_dossier.gd`, add after the `populated` assertions:

```gdscript
	var degraded := GameStateScript.new()
	_resolve(degraded, &"cold_chain_delivery", &"pay_fee")
	degraded.heat = 4
	_resolve(degraded, &"data_retrieval", &"spoof_credentials")
	var degraded_snapshot: Dictionary = degraded.dossier_snapshot()
	check(degraded_snapshot.signature == {"clean": 1, "aggressive": 0,
		"community": 0, "partial": 1},
		"a degraded route counts as partial without claiming clean work")
	check(degraded_snapshot.operations.any(func(row: Dictionary) -> bool:
		return row.id == &"data_retrieval" and row.status == &"partial"
			and row.outcome == "SPOOF SERVICE CREDENTIALS"),
		"partial operations stay in the record with their response label")
	degraded.free()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `.\tests\run_test.ps1 test_dossier`
Expected: FAIL — `signature` has no `partial` key and the D-207 operation is absent from `operations`.

- [ ] **Step 3: Include partial operations and count them**

In `dossier_snapshot`, widen the resolved-operation guard to accept `&"partial"` alongside `&"completed"` and `&"failed"`, initialise `signature` with `"partial": 0`, and add a `elif contract.status == &"partial": signature.partial += 1` branch that bypasses the clean/aggressive/community counting.

- [ ] **Step 4: Show the counter**

In `dossier_panel.gd`, extend the work-signature label to `"CLEAN %d // AGGRESSIVE %d // COMMUNITY %d // PARTIAL %d"` and extend the explanatory line to state that partial means the job landed but not cleanly.

- [ ] **Step 5: Update the exact-dict assertions**

Every signature literal in `tests/test_dossier.gd` (lines 13, 23, 73-74, 87, 98) gains `"partial": 0`. Leave the scenario expectations otherwise unchanged.

- [ ] **Step 6: Run the test to verify it passes**

Run: `.\tests\run_test.ps1 test_dossier`
Expected: `RESULT: ALL PASSED`

- [ ] **Step 7: Commit**

```bash
git add autoload/game_state.gd scenes/modules/dossier/dossier_panel.gd tests/test_dossier.gd
git commit -m "feat: record partial operations in the dossier"
```

---

### Task 4: Prepared routes degrade too

**Files:**
- Modify: `data/contracts/contract_catalog.gd` (C-1042 `precleared_documents`; D-207 `verified_work_order`)
- Modify: `autoload/game_state.gd` (`_available_choices`, `get_contract`)
- Modify: `scenes/modules/contracts/contract_detail.gd:194-206`
- Test: `tests/test_preparation.gd`

**Interfaces:**
- Consumes: Task 1's `_effective_outcome` and Task 2's substitution.
- Produces: choices returned by `_available_choices` carry `partial_now: bool` when degradation applies at the current Heat. `get_contract(id).preparation.choice` is the entry from that same list, so it carries `partial_now` and the degraded `preview`.

- [ ] **Step 1: Write the failing test**

In `tests/test_preparation.gd`, add `_test_heat_degraded_preparation()` to `_run`'s call list and preload the detail scene at the top:

```gdscript
const ContractDetail := preload("res://scenes/modules/contracts/contract_detail.tscn")
```

```gdscript
func _test_heat_degraded_preparation() -> void:
	var warm := GameStateScript.new()
	check(warm.accept_contract(DELIVERY) and warm.prepare_contract(DELIVERY), "warm fixture prepares")
	warm.heat = 6
	check(warm.proceed_contract(DELIVERY), "warm fixture proceeds")
	var warm_choice: Dictionary = warm.get_contract(DELIVERY).preparation.choice
	check(not warm_choice.get("partial_now", false), "Heat 6 keeps prepared trust")
	var warm_credits: int = warm.credits
	var warm_standing: int = warm.standing_for(&"mara")
	check(warm.resolve_contract(DELIVERY, PAPERS)
		and warm.credits == warm_credits + 1400
		and warm.standing_for(&"mara") == warm_standing + 1,
		"Heat 6 prepared work still earns trust")
	warm.free()

	var hot := GameStateScript.new()
	check(hot.accept_contract(DELIVERY) and hot.prepare_contract(DELIVERY), "hot fixture prepares")
	hot.heat = 7
	check(hot.proceed_contract(DELIVERY), "hot fixture proceeds")
	var hot_choice: Dictionary = hot.get_contract(DELIVERY).preparation.choice
	check(hot_choice.get("partial_now", false), "Heat 7 marks the prepared response degraded")
	var detail := ContractDetail.instantiate()
	root.add_child(detail)
	detail.setup(hot, hot.get_contract(DELIVERY))
	var preview := ""
	for label in detail.find_children("*", "Label", true, false):
		preview += label.text + "\n"
	check(preview.contains("NO STANDING GAIN") and not preview.contains("STANDING +1"),
		"a degraded prepared preview states the lost standing before commitment")
	var credits: int = hot.credits
	var standing: int = hot.standing_for(&"mara")
	check(hot.resolve_contract(DELIVERY, PAPERS)
		and hot.credits == credits + 1400
		and hot.standing_for(&"mara") == standing
		and hot.get_contract(DELIVERY).status == &"partial",
		"Heat 7 prepared work keeps its payout and earns no trust")
	check(hot.save_profile(), "degraded prepared work saves")
	var restored := GameStateScript.new()
	check(restored.load_profile()
		and restored.get_contract(DELIVERY).status == &"partial",
		"a prepared partial outcome reloads")
	restored.free()
	var cleanup := GameStateScript.new()
	cleanup.reset_profile()
	cleanup.free()
	hot.free()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `.\tests\run_test.ps1 test_preparation`
Expected: FAIL — `partial_now` is absent and Heat 7 prepared work completes with a standing gain.

- [ ] **Step 3: Author the prepared degraded forms**

In `data/contracts/contract_catalog.gd`, on D-207 `verified_work_order` and on C-1042 `precleared_documents`, add `"partial_above_heat": 6` and a `partial` block whose `credit_delta` equals the clean payout (4,200 and 1,400), whose `contact_standing_delta` is 0, and whose `preview` is `"+<payout> CR // HEAT +0 // CONTRACT PARTIAL // NO STANDING GAIN"`. The `result`, `ticker`, and `message_preview` state that the cover held but earned no trust.

- [ ] **Step 4: Expose the flag and rebind the prepared choice**

In `_available_choices`, set `entry.partial_now = true` alongside the existing degraded `preview` substitution.

In `get_contract`, assign the resolved choice list to a local before mutating `snapshot.complication.choices`, and set `snapshot.preparation.choice` from that same local by `snapshot.preparation.choice_id`. Keep the existing behaviour when the contract is resolved.

- [ ] **Step 5: State the lost standing in the prepared preview**

In `_prepared_outcome_text`, when `choice.get("partial_now", false)` is true, replace the computed `"%s STANDING +%d"` line with `"%s STANDING +0 // NO STANDING GAIN"` and do not emit the preparation gain. Everything else in that function keeps its current output.

- [ ] **Step 6: Run the test to verify it passes**

Run: `.\tests\run_test.ps1 test_preparation`
Expected: `RESULT: ALL PASSED`

- [ ] **Step 7: Run the full suite**

Run: `.\tests\run_all.ps1`
Expected: `ALL SUITES PASSED`

- [ ] **Step 8: Manual check on the real surface**

Run the project with `& "C:\Users\merli\Documents\Godot Projects\Godot_v4.7.1-stable_win64_console.exe" --path .` and confirm on the actual contract detail panel: D-207 spoof at Heat 3 resolves `CONTRACT COMPLETE` at 4,200 CR, at Heat 4 resolves `CONTRACT PARTIAL` at 3,900 CR with no standing gain; M-613 `BUY CUSTODIAN SILENCE // 900 CR` at Heat 5 pays 4,700 CR and at Heat 6 pays 4,300 CR as `CONTRACT PARTIAL`; a purchased C-1042 or D-207 preparation at Heat 7 shows `NO STANDING GAIN` in its preview before committing. Restore any save file you overwrote.

- [ ] **Step 9: Commit**

```bash
git add data/contracts/contract_catalog.gd autoload/game_state.gd scenes/modules/contracts/contract_detail.gd tests/test_preparation.gd
git commit -m "feat: degrade prepared routes under critical Heat"
```
