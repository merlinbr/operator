# Contract Preparation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two optional, reliable preparation purchases that unlock situational contract responses without changing basic outcomes, game time, or deadlines.

**Architecture:** Keep authored preparation and outcomes in `ContractCatalog`; keep purchase guards, filtering, historical spending, and persistence in `GameState`. Extend the existing injected detail panel and main-scene action wiring. One historical integer per contract replaces a separate purchased flag; no inventory, additional phase, or new service.

**Tech Stack:** Godot 4.7.1, GDScript, existing SceneTree headless tests, PowerShell on Windows. No new dependencies.

## Global Constraints

- Approved specification: `docs/superpowers/specs/2026-09-05-contract-preparation-design.md`.
- Implementation starts only after the contract-deadlines feature is complete. Its approved baseline is `docs/superpowers/specs/2026-09-05-contract-deadlines-design.md`.
- At most one purchase per contract. Each of the two supported contracts has one authored preparation; the other five have none.
- Cold-Chain Delivery preparation costs **300 CR** and unlocks `precleared_documents`: resolution +1,400 CR, Heat +0, Mara standing +1, no favor changes; net +1,100 CR.
- Data Retrieval preparation costs **500 CR** and unlocks `verified_work_order`: resolution +4,200 CR, Heat +0, Mara standing +1, no favor changes; net +3,700 CR.
- Existing responses retain their requirements, rewards, Heat, standing, favor effects, and successors.
- Pay Credits upfront. Preparation consumes no game time, changes no travel duration, and never renews or extends a deadline.
- No switching, cancellation, or refunds. An abort or deadline failure retains the spent preparation cost. Purchases survive reload.
- Buying preparation itself awards no standing, changes no Heat or favor state, and does not complete the contract.
- Reputation in this slice means existing Contact standing only. No faction reputation, new Contacts, standing losses, or penalties added to basic responses.
- Every runtime contract gains `prep_paid_credits: int`, initially **0**. A positive value means the preparation was purchased and records the actual price paid.
- Preparation advances the deadline baseline's profile version 3 to **version 4**. Preserve migration stages 1 -> 2 -> 3 -> 4 and existing deadline validation/reconciliation.
- Components continue receiving state through `setup()` injection.
- Run save-writing tests and runtime smoke scenarios only under a disposable project/user-data identity. Never run the hard-coded real-profile wrapper unprotected.
- This document is a plan, not evidence that implementation, tests, or a playthrough have run.

---

## File map, ownership, and execution order

| Task | Files | Responsibility |
|---|---|---|
| 1 | `data/contracts/contract_catalog.gd`, `autoload/game_state.gd`, new `tests/test_preparation.gd`, `tests/test_contract_catalog.gd` | Authored options, purchase action, snapshot preview, eligibility and monetary boundaries |
| 2 | `autoload/game_state.gd`, `tests/test_persistence.gd` | Version-4 persistence, explicit migration stages, validation, historical paid amounts and deadline reconciliation |
| 3 | `scenes/modules/contracts/contract_detail.gd`, `scenes/main/main.gd`, `tests/test_contracts.gd`; existing `README.md`, `context.md`, `next-features.md` after runtime proof | Purchase controls, dynamic trade-off previews, net results, actual main-scene verification, current documentation |

Execute **1 -> 2 -> 3**. Tasks 1 and 2 deliberately serialize changes to `GameState`. Task 1 alone is not saved-game-ready; do not ship an intermediate task as the feature. Task 3 must preserve the completed deadline UI rather than reconstructing its pre-deadline version.

No changes are planned to `ContactCatalog`, the five unsupported jobs' choices, contract phases, clock processing, contract list behavior, housing, audio assets, or project configuration. A Godot-generated UID for the new test is acceptable if the editor creates it; do not hand-author UIDs.

### Preflight after deadlines finish

- Read the finished deadline implementation and its completion evidence before applying this plan. Confirm the baseline provides `current_minute()`, `deadline_at_minute`, `_deadline_passed()`, guarded actions, version-3 persistence, overdue-load reconciliation, `_render_deadline_result()`, `_render_timing_warning()`, and selected-detail refresh on `clock_changed`.
- The source was still being edited when this plan was written. The symbols below are navigation anchors, not patch line numbers. Read fresh sections before editing; do not overwrite the deadline agent's final changes with an earlier snapshot.
- Before changing exported symbols, request GDScript language-server references where a server is available. Otherwise search scripts/tests with the repository search tool. Cover `get_contract`, `resolve_contract`, `load_profile`, `_validate_contracts`, `_apply_profile`, detail `setup`, and `_add_action`; inspect `test_game_state`, `test_contracts`, `test_main`, and `test_persistence` consumers. New `prepare_contract` callers are explicitly owned below.
- Reuse existing patterns. Do not split the state singleton or create a generalized purchase framework.

## Disposable verification workspace

Use the same safety approach as the deadline plan. Run this setup through the harness's code-evaluation tool because it is multiline PowerShell. Keep `$source`, `$stage`, `$identity`, and the functions in the same verification session; re-stage before each focused check.

```powershell
$source = (Get-Location).Path
$godot = Join-Path (Split-Path $source -Parent) 'Godot_v4.7.1-stable_win64_console.exe'
$identity = 'OperatorPreparationVerification-' + [guid]::NewGuid().ToString('N')
$stage = Join-Path ([IO.Path]::GetTempPath()) $identity
New-Item -ItemType Directory -Path $stage | Out-Null
function Sync-PreparationStage {
    Get-ChildItem -LiteralPath $source -Force |
        Where-Object { $_.Name -notin @('.git', '.godot') } |
        Copy-Item -Destination $stage -Recurse -Force
    $projectFile = Join-Path $stage 'project.godot'
    $config = [IO.File]::ReadAllText($projectFile)
    if (-not $config.Contains('config/name="Operator"')) {
        throw 'Verify the project identity replacement before running save-writing checks'
    }
    $config = $config.Replace('config/name="Operator"', ('config/name="' + $identity + '"'))
    [IO.File]::WriteAllText($projectFile, $config)
}
function Invoke-PreparationSuite([string]$Name) {
    & $godot --headless --path $stage --script "res://tests/$Name.gd"
    if ($LASTEXITCODE -ne 0) { throw "$Name failed with exit $LASTEXITCODE" }
}
Sync-PreparationStage
& $godot --headless --editor --path $stage --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Disposable project import failed' }
```

Do not change the checked-in project name or test-runner paths. Use supervised processes for interactive Godot launches. All synthetic clock, standing, or save changes below are disposable verification fixtures, not gameplay APIs.

### Task 1: Authored preparation and authoritative purchases

**Files:**
- Modify `data/contracts/contract_catalog.gd`: seven default paid amounts; preparation metadata and one new outcome on each of the first two jobs.
- Modify `autoload/game_state.gd`: `get_contract`, `_available_choices`; add `prepare_contract`.
- Create `tests/test_preparation.gd` using `tests/test_base.gd`.
- Modify `tests/test_contract_catalog.gd`: add preparation integrity checks to the existing contract loop.

**Interfaces:**
- Consumes: `_contract_index(id)`, `_choice(choices: Array, choice_id: StringName) -> Dictionary`, `_deadline_passed(contract)`, `current_minute()`, `save_profile()`, `contracts_changed`, `credits_changed`, `push_ticker()`.
- Produces: `prepare_contract(id: StringName) -> bool`.
- Runtime field: `prep_paid_credits: int = 0` on every contract.
- Authored supported-contract field: `preparation = {label: String, cost_credits: int, choice_id: StringName}`.
- Authored choice flag: `requires_prep: true` on only the two new choices.
- Snapshot-only field: `snapshot.preparation.choice`, copied from the unfiltered authored response before filtering the action list. Never persist this projection into runtime contracts.

- [ ] **Step 1: Write the focused gameplay regression script.**

Create this file. It tests spending, eligibility, ordinary outcomes, and terminal transitions rather than source text. Save writes are confined to the staged project identity.

```gdscript
extends "res://tests/test_base.gd"

const GameStateScript := preload("res://autoload/game_state.gd")
const DELIVERY := &"cold_chain_delivery"
const DATA := &"data_retrieval"
const PAPERS := &"precleared_documents"
const COVER := &"verified_work_order"

func _run() -> void:
	_test_purchase_and_resolution()
	_test_guards()
	_test_unused_and_failed_preparation()
	_test_data_tradeoffs()
	var cleanup := GameStateScript.new()
	cleanup.reset_profile()
	cleanup.free()

func _has_choice(gs: Node, id: StringName, choice_id: StringName) -> bool:
	for choice: Dictionary in gs.get_contract(id).complication.choices:
		if choice.id == choice_id:
			return true
	return false

func _test_purchase_and_resolution() -> void:
	var gs := GameStateScript.new()
	check(gs.accept_contract(DELIVERY), "accept delivery before preparation")
	var before: Dictionary = gs.get_contract(DELIVERY)
	var start: int = gs.credits
	var clock: int = gs.current_minute()
	var heat: int = gs.heat
	var standing: int = gs.standing_for(&"mara")
	check(not _has_choice(gs, DELIVERY, PAPERS), "unpurchased response is not actionable")
	var reentered: Array[bool] = []
	var on_credits := func(_credits: int) -> void:
		reentered.append(gs.prepare_contract(DELIVERY))
	gs.credits_changed.connect(on_credits)
	var feedback: Array[String] = []
	gs.ticker_message.connect(func(text: String, _highlight: bool) -> void:
		feedback.append(text))
	check(gs.prepare_contract(DELIVERY), "purchase succeeds")
	gs.credits_changed.disconnect(on_credits)
	check(reentered == [false] and gs.credits == start - 300,
		"notification re-entry cannot double-charge")
	check(gs.current_minute() == clock
		and gs.get_contract(DELIVERY).deadline_at_minute == before.deadline_at_minute
		and gs.heat == heat and gs.standing_for(&"mara") == standing
		and not gs.mara_favor_owed, "purchase changes only paid state and Credits")
	var count: int = feedback.size()
	check(count == 1 and not gs.prepare_contract(DELIVERY)
		and feedback.size() == count and gs.credits == start - 300,
		"duplicate purchase neither spends nor repeats confirmation")
	check(_has_choice(gs, DELIVERY, PAPERS)
		and _has_choice(gs, DELIVERY, &"pay_fee")
		and _has_choice(gs, DELIVERY, &"call_mara")
		and _has_choice(gs, DELIVERY, &"bypass")
		and _has_choice(gs, DELIVERY, &"abort"), "preparation is additive")
	check(gs.proceed_contract(DELIVERY) and gs.resolve_contract(DELIVERY, PAPERS),
		"purchased response completes the job")
	check(gs.credits == start + 1100 and gs.heat == heat
		and gs.standing_for(&"mara") == standing + 1 and not gs.mara_favor_owed,
		"outcome earns trust without debt or a second charge")
	check(gs.is_contract_available(gs.get_contract(DATA))
		and gs.get_contract(DATA).prep_paid_credits == 0,
		"normal successors publish without inheriting preparation")
	check(not gs.resolve_contract(DELIVERY, PAPERS) and gs.credits == start + 1100,
		"terminal response cannot pay twice")
	gs.free()

func _test_guards() -> void:
	var gs := GameStateScript.new()
	var start: int = gs.credits
	check(not gs.prepare_contract(DELIVERY) and not gs.prepare_contract(&"missing")
		and gs.credits == start, "unaccepted and unknown jobs cannot charge")
	check(gs.accept_contract(DELIVERY), "guard fixture accepts delivery")
	check(not gs.prepare_contract(DATA) and gs.credits == start,
		"wrong active ID cannot charge")
	gs.credits = 299
	check(not gs.prepare_contract(DELIVERY) and gs.credits == 299,
		"insufficient funds cannot be clamped into a purchase")
	gs.credits = 300
	check(gs.prepare_contract(DELIVERY) and gs.credits == 0,
		"exact affordability succeeds")
	gs.free()
	var departed := GameStateScript.new()
	check(departed.accept_contract(DELIVERY) and departed.proceed_contract(DELIVERY),
		"departed fixture reaches complication unprepared")
	start = departed.credits
	check(not departed.prepare_contract(DELIVERY)
		and not departed.resolve_contract(DELIVERY, PAPERS)
		and departed.credits == start, "late purchase and forged prepared response fail")
	check(departed.resolve_contract(DELIVERY, &"abort"), "publish unsupported job")
	check(departed.accept_contract(&"dead_drop_audit"), "accept unsupported job")
	check(not departed.prepare_contract(&"dead_drop_audit") and departed.credits == start,
		"unsupported active job cannot charge")
	departed.free()
	var stale := GameStateScript.new()
	check(stale.accept_contract(DELIVERY), "stale fixture accepts delivery")
	var cutoff: int = stale.get_contract(DELIVERY).deadline_at_minute
	# Synthetic stale active record: do not settle it before exercising the guard.
	stale.day = floori(float(cutoff) / 1440.0) + 1
	stale.minute_of_day = cutoff % 1440
	start = stale.credits
	var messages: int = stale.messages.size()
	check(not stale.prepare_contract(DELIVERY) and stale.credits == start
		and stale.get_contract(DELIVERY).status == &"active"
		and stale.messages.size() == messages, "cutoff equality rejects without hidden settlement")
	stale.free()

func _test_unused_and_failed_preparation() -> void:
	for choice_id: StringName in [&"pay_fee", &"abort", &"deadline_missed"]:
		var gs := GameStateScript.new()
		var start: int = gs.credits
		gs.mara_favor_owed = true
		check(gs.accept_contract(DELIVERY) and gs.prepare_contract(DELIVERY),
			"sunk-cost fixture purchases preparation")
		if choice_id == &"deadline_missed":
			var c: Dictionary = gs.get_contract(DELIVERY)
			gs.advance_minutes(c.deadline_at_minute - gs.current_minute() - c.proceed_minutes)
		check(gs.proceed_contract(DELIVERY), "travel remains accepted")
		if choice_id != &"deadline_missed":
			check(gs.resolve_contract(DELIVERY, choice_id), "basic response remains usable")
		else:
			check(gs.get_contract(DELIVERY).resolution_id == &"deadline_missed"
				and not gs.resolve_contract(DELIVERY, PAPERS), "deadline blocks purchased response")
		var payout := 1150 if choice_id == &"pay_fee" else 0
		check(gs.credits == start - 300 + payout and gs.mara_favor_owed
			and gs.standing_for(&"mara") == 1 and gs.heat == 2,
			"unused/failed preparation stays spent without outcome benefits")
		gs.free()
	var owed := GameStateScript.new()
	owed.mara_favor_owed = true
	check(owed.accept_contract(DELIVERY) and owed.prepare_contract(DELIVERY)
		and owed.proceed_contract(DELIVERY) and owed.resolve_contract(DELIVERY, PAPERS)
		and owed.mara_favor_owed, "prepared success does not erase an existing debt")
	owed.free()

func _data_outcome(high_heat: bool, trusted: bool, prepared: bool,
		choice_id: StringName) -> Dictionary:
	var gs := GameStateScript.new()
	check(gs.accept_contract(DELIVERY) and gs.proceed_contract(DELIVERY)
		and gs.resolve_contract(DELIVERY, &"bypass" if high_heat else &"pay_fee"),
		"publish Data through actual opening outcomes")
	if trusted:
		gs.contact_standing[&"mara"] = 2 # coherent cap fixture; not a gameplay action
	check(gs.accept_contract(DATA), "accept Data on time")
	var start: int = gs.credits
	if prepared:
		check(gs.prepare_contract(DATA), "purchase independent service cover")
	check(gs.proceed_contract(DATA) and gs.resolve_contract(DATA, choice_id),
		"chosen Data response is usable")
	var result := {"net": gs.credits - start, "heat": gs.heat,
		"standing": gs.standing_for(&"mara")}
	gs.free()
	return result

func _test_data_tradeoffs() -> void:
	var low_free := _data_outcome(false, false, false, &"spoof_credentials")
	var low_prepared := _data_outcome(false, false, true, COVER)
	check(low_free.net == 4200 and low_prepared.net == 3700
		and low_free.heat == low_prepared.heat and low_free.standing == low_prepared.standing,
		"at low Heat preparation buys no advantage over spoofing")
	var high_vendor := _data_outcome(true, false, false, &"routed_vendor_id")
	var high_prepared := _data_outcome(true, false, true, COVER)
	check(high_prepared.net - high_vendor.net == 150 and high_prepared.heat == 4
		and high_prepared.standing == 2 and high_vendor.standing == 2,
		"at high Heat preparation is a cheaper quiet trust route")
	var capped_token := _data_outcome(true, true, false, &"buy_token")
	var capped_prepared := _data_outcome(true, true, true, COVER)
	check(capped_token.net - capped_prepared.net == 100
		and capped_token.heat == capped_prepared.heat
		and capped_token.standing == capped_prepared.standing,
		"at capped trust the basic token is cheaper with the same benefits")
```

- [ ] **Step 2: Stage and run the new script red.**

```powershell
Sync-PreparationStage
Invoke-PreparationSuite test_preparation
```

Before implementation, expect a missing preparation API/field failure. This is a future execution instruction, not a request to run incomplete gameplay during plan creation.

- [ ] **Step 3: Add the catalog records without altering existing choices.**

Add `"prep_paid_credits": 0` beside each of the seven runtime `resolution_id` fields. Reset already rebuilds contracts through `ContractCatalog.all()`; no second reset list is needed.

Add these metadata dictionaries to the named contracts:

```gdscript
# cold_chain_delivery
"preparation": {
	"label": "ARRANGE INDEPENDENT CLEARANCE // 300 CR",
	"cost_credits": 300,
	"choice_id": &"precleared_documents",
},

# data_retrieval
"preparation": {
	"label": "ARRANGE INDEPENDENT SERVICE COVER // 500 CR",
	"cost_credits": 500,
	"choice_id": &"verified_work_order",
},
```

Append the following complete response to the corresponding existing `choices` array. Append after existing records so old choices are neither reordered nor replaced.

```gdscript
# cold_chain_delivery.complication.choices
{
	"id": &"precleared_documents",
	"label": "SUBMIT PRE-CLEARED CARGO DOCUMENTS",
	"requires_prep": true,
	"credit_delta": 1400,
	"heat_delta": 0,
	"contact_standing_delta": 1,
	"terminal_status": &"completed",
	"unlocks_contract_ids": [&"data_retrieval", &"dead_drop_audit"],
	"preview": "+1,400 CR // HEAT +0 // CONTRACT COMPLETE",
	"result": "PRE-CLEARED DOCUMENTS ACCEPTED // CARGO RELEASED",
	"ticker": "CONTRACT COMPLETE // +1,400 CR",
	"message_sender": "MARA",
	"message_preview": "You handled clearance without calling me in. I can trust that.",
},

# data_retrieval.complication.choices
{
	"id": &"verified_work_order",
	"label": "PRESENT VERIFIED SUBCONTRACTOR WORK ORDER",
	"requires_prep": true,
	"credit_delta": 4200,
	"heat_delta": 0,
	"contact_standing_delta": 1,
	"terminal_status": &"completed",
	"unlocks_contract_ids": [&"silent_partner", &"clinic_asset_recovery"],
	"preview": "+4,200 CR // HEAT +0 // CONTRACT COMPLETE",
	"result": "VERIFIED WORK ORDER ACCEPTED // SHARD RETRIEVED",
	"ticker": "CONTRACT COMPLETE // +4,200 CR",
	"message_sender": "MARA",
	"message_preview": "The work order held. You kept the retrieval quiet without leaning on my vendor route.",
},
```

The static preview deliberately does not promise a standing increase at the cap. Task 3 renders effective standing dynamically. Do not add favor-setting or favor-clearing flags, Heat limits, or time costs to either response.

Inside `test_contract_catalog.gd`'s existing per-contract loop add:

```gdscript
var prep_choices: Array = contract.complication.choices.filter(
	func(choice: Dictionary) -> bool: return choice.get("requires_prep", false))
if contract.has("preparation"):
	check(typeof(contract.preparation.cost_credits) == TYPE_INT
		and contract.preparation.cost_credits > 0
		and prep_choices.size() == 1
		and prep_choices[0].id == contract.preparation.choice_id,
		"purchasable preparation references exactly one gated response")
else:
	check(prep_choices.is_empty(), "no inaccessible prepared responses on unsupported jobs")
```

The behavioral trade-off script owns price/payout assertions; do not add a second numeric balancing snapshot to the catalog suite.

- [ ] **Step 4: Implement the purchase and additive snapshot/filter path.**

Add this action beside the existing contract actions:

```gdscript
func prepare_contract(id: StringName) -> bool:
	var index := _contract_index(id)
	if index < 0 or active_contract_id != id:
		return false
	var contract: Dictionary = contracts[index]
	if contract.status != &"active" or contract.phase != &"ready_to_proceed" \
			or _deadline_passed(contract) or not contract.has("preparation") \
			or int(contract.prep_paid_credits) != 0:
		return false
	var cost := int(contract.preparation.cost_credits)
	if credits < cost:
		return false
	contract.prep_paid_credits = cost
	credits -= cost
	contracts_changed.emit()
	push_ticker("PREPARATION PURCHASED // %s // %s CR" % [
		contract.code, format_credits(cost)], true)
	save_profile()
	return true
```

The positive cost is an authored-catalog invariant, checked above; clients never supply it. Mark paid state before the Credits setter emits. Do not invoke `_advance_minutes`, settle deadlines from this guard, or emit contract accepted/proceeded/resolved events. Save failure retains the coherent in-memory purchase and uses existing error reporting.

In `get_contract`, immediately after its existing deep copy and **before** replacing `snapshot.complication.choices`, insert:

```gdscript
if snapshot.has("preparation"):
	snapshot.preparation.choice = _choice(snapshot.complication.choices,
		StringName(snapshot.preparation.choice_id))
```

This takes the preview response from the already-copied authored list. Do not attach it to `contracts[index]`. The UI otherwise could not preview a response removed by the unpurchased filter.

Inside `_available_choices`' existing loop, before its other eligibility checks, insert:

```gdscript
if choice.get("requires_prep", false) and int(contract.prep_paid_credits) == 0:
	continue
```

Retain the Heat/favor filters and `resolve_contract`'s lookup through `_available_choices`. Existing normal resolution applies the reward, capped standing, successors, and feedback without a second preparation charge. Deadline settlement does not erase `prep_paid_credits`; no clock or terminal-transition modification is needed.

- [ ] **Step 5: Run focused state checks.**

```powershell
Sync-PreparationStage
Invoke-PreparationSuite test_preparation
Invoke-PreparationSuite test_contract_catalog
Invoke-PreparationSuite test_game_state
Invoke-PreparationSuite test_deadlines
```

Expected: each suite prints `RESULT: ALL PASSED`. Do not use ordinary saved-game play as proof until Task 2 has migrated persistence. Preserve deadline boundary coverage; do not weaken guards to rescue invalid test fixtures.

- [ ] **Step 6: Commit the focused state change.**

Stage only this task's paths (and the generated test UID if present), never another agent's unrelated edits:

```bash
git add -- data/contracts/contract_catalog.gd autoload/game_state.gd tests/test_preparation.gd tests/test_contract_catalog.gd
git commit --only -m "feat: add optional contract preparation purchases" -- data/contracts/contract_catalog.gd autoload/game_state.gd tests/test_preparation.gd tests/test_contract_catalog.gd
```

### Task 2: Version-4 saves and preparation validation

**Files:**
- Modify `autoload/game_state.gd`: `PROFILE_VERSION`, `load_profile`, `_migrate_v2_profile`, `_validate_profile`, `_validate_contracts`, `_apply_profile`; add `_migrate_v3_profile`.
- Modify `tests/test_persistence.gd`: append preparation cases and update its real legacy fixture.

**Interfaces:**
- Consumes: Task 1's paid field, response IDs, `prepare_contract`, `get_contract` projection, and deadline baseline migrations/reconciliation.
- Produces: `PROFILE_VERSION = 4`, `_migrate_v3_profile(data: Dictionary) -> Dictionary`.
- Preserves: `_migrate_v1_profile` produces version 2; `_migrate_v2_profile` produces version 3; `_validate_contracts(raw_contracts: Variant, active_id: StringName, profile_version: int) -> String` retains its signature.

- [ ] **Step 1: Add file-load regression cases and run them red.**

Reuse `_write_deadline_profile(payload)` from the completed deadline tests rather than writing a second JSON-file helper. Add these calls at the end of `_run()` after existing cases:

```gdscript
_test_preparation_round_trip()
_test_v3_preparation_migration()
_test_prepared_overdue_load()
_test_invalid_preparation_profiles()
_test_preparation_save_failure()
```

Append:

```gdscript
func _test_preparation_round_trip() -> void:
	for outcome: StringName in [&"precleared_documents", &"pay_fee", &"abort"]:
		var gs := GameStateScript.new()
		gs.reset_profile()
		gs.mara_favor_owed = true
		check(gs.accept_contract(&"cold_chain_delivery")
			and gs.prepare_contract(&"cold_chain_delivery"), "round-trip purchases preparation")
		var due: int = gs.get_contract(&"cold_chain_delivery").deadline_at_minute
		var after_purchase: int = gs.credits
		var restored := GameStateScript.new()
		check(restored.load_profile() and restored.credits == after_purchase,
			"ready purchase reloads without another debit")
		var c: Dictionary = restored.get_contract(&"cold_chain_delivery")
		check(c.prep_paid_credits == 300 and c.deadline_at_minute == due
			and c.complication.choices.any(func(choice: Dictionary) -> bool:
				return choice.id == &"precleared_documents"),
			"reload retains cost, cutoff and unlocked response")
		check(not restored.prepare_contract(c.id) and restored.credits == after_purchase,
			"reload cannot purchase twice")
		check(restored.proceed_contract(c.id) and restored.resolve_contract(c.id, outcome),
			"restored job can use prepared or basic outcome")
		var result_credits: int = restored.credits
		var again := GameStateScript.new()
		check(again.load_profile() and again.credits == result_credits
			and again.get_contract(c.id).prep_paid_credits == 300
			and again.get_contract(c.id).resolution_id == outcome and again.mara_favor_owed,
			"terminal reload preserves spent preparation and existing debt")
		again.reset_profile()
		gs.free()
		restored.free()
		again.free()

func _test_v3_preparation_migration() -> void:
	for at_complication: bool in [false, true]:
		var gs := GameStateScript.new()
		gs.reset_profile()
		gs.mara_favor_owed = true
		check(gs.accept_contract(&"cold_chain_delivery"), "version-3 fixture accepts on time")
		if at_complication:
			check(gs.proceed_contract(&"cold_chain_delivery"), "legacy fixture departs unprepared")
		var payload: Dictionary = gs._profile_payload()
		payload.version = 3
		for record: Dictionary in payload.contracts:
			record.erase("prep_paid_credits")
		var clock: int = gs.current_minute()
		var due: int = gs.get_contract(&"cold_chain_delivery").deadline_at_minute
		_write_deadline_profile(payload)
		var restored := GameStateScript.new()
		check(restored.load_profile() and restored.current_minute() == clock
			and restored.credits == gs.credits and restored.mara_favor_owed
			and restored.get_contract(&"cold_chain_delivery").deadline_at_minute == due
			and restored.get_contract(&"cold_chain_delivery").prep_paid_credits == 0,
			"version-3 migration preserves progress and does not renew the cutoff")
		var persisted_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var persisted: Dictionary = JSON.parse_string(persisted_file.get_as_text())
		persisted_file.close()
		check(persisted.version == 4 and persisted.contracts[0].prep_paid_credits == 0,
			"migration writes the new on-disk schema immediately")
		var again := GameStateScript.new()
		check(again.load_profile()
			and again.get_contract(&"cold_chain_delivery").deadline_at_minute == due,
			"subsequent load preserves remaining time")
		if at_complication:
			check(not again.prepare_contract(&"cold_chain_delivery"),
				"legacy departed job cannot prepare retroactively")
		else:
			check(again.prepare_contract(&"cold_chain_delivery"),
				"legacy ready job may purchase after migration")
		again.reset_profile()
		gs.free()
		restored.free()
		again.free()

func _test_prepared_overdue_load() -> void:
	var gs := GameStateScript.new()
	gs.reset_profile()
	check(gs.accept_contract(&"cold_chain_delivery")
		and gs.prepare_contract(&"cold_chain_delivery"), "overdue fixture purchases preparation")
	var payload: Dictionary = gs._profile_payload()
	var due: int = gs.get_contract(&"cold_chain_delivery").deadline_at_minute
	payload.day = floori(float(due) / 1440.0) + 1
	payload.minute_of_day = due % 1440
	_write_deadline_profile(payload)
	var restored := GameStateScript.new()
	check(restored.load_profile() and restored.credits == gs.credits
		and restored.get_contract(&"cold_chain_delivery").resolution_id == &"deadline_missed"
		and restored.get_contract(&"cold_chain_delivery").prep_paid_credits == 300
		and restored.active_contract_id == &"", "overdue load fails the job without refund")
	var messages: int = restored.messages.size()
	var again := GameStateScript.new()
	check(again.load_profile() and again.messages.size() == messages
		and again.credits == gs.credits
		and again.get_contract(&"cold_chain_delivery").prep_paid_credits == 300,
		"repeated overdue load retains sunk cost without replay")
	again.reset_profile()
	gs.free()
	restored.free()
	again.free()

func _test_invalid_preparation_profiles() -> void:
	var gs := GameStateScript.new()
	gs.reset_profile()
	check(gs.accept_contract(&"cold_chain_delivery"), "invalid fixtures start from active state")
	var valid: Dictionary = gs._profile_payload()
	var cases: Array[Dictionary] = []
	for bad: Variant in [null, -1, 0.5, "300", true]:
		var invalid: Dictionary = valid.duplicate(true)
		if bad == null:
			invalid.contracts[0].erase("prep_paid_credits")
		else:
			invalid.contracts[0].prep_paid_credits = bad
		cases.append(invalid)
	var unaccepted: Dictionary = valid.duplicate(true)
	unaccepted.active_contract_id = ""
	unaccepted.contracts[0].status = "available"
	unaccepted.contracts[0].phase = "offer"
	unaccepted.contracts[0].prep_paid_credits = 300
	cases.append(unaccepted)
	var unsupported: Dictionary = valid.duplicate(true)
	unsupported.contracts[2].prep_paid_credits = 300
	cases.append(unsupported)
	var unpaid_result: Dictionary = valid.duplicate(true)
	unpaid_result.active_contract_id = ""
	unpaid_result.contracts[0].status = "completed"
	unpaid_result.contracts[0].phase = "resolved"
	unpaid_result.contracts[0].resolution_id = "precleared_documents"
	cases.append(unpaid_result)
	for version: int in [2, 3]:
		var legacy_result: Dictionary = unpaid_result.duplicate(true)
		legacy_result.version = version
		cases.append(legacy_result)
	for invalid: Dictionary in cases:
		gs.reset_profile() # remove alternate candidates before corrupting the primary
		_write_deadline_profile(invalid)
		var restored := GameStateScript.new()
		check(not restored.load_profile(), "invalid paid amount or impossible purchase is rejected")
		restored.free()
	# A historical price differs from today's catalog but remains valid.
	gs.reset_profile()
	var historical: Dictionary = valid.duplicate(true)
	historical.contracts[0].prep_paid_credits = 275
	historical.contracts[0].preparation.cost_credits = 1
	_write_deadline_profile(historical)
	var restored := GameStateScript.new()
	check(restored.load_profile()
		and restored.get_contract(&"cold_chain_delivery").prep_paid_credits == 275
		and restored.get_contract(&"cold_chain_delivery").preparation.cost_credits == 300,
		"historical spending restores without trusting saved authored prices")
	restored.reset_profile()
	gs.free()
	restored.free()

func _test_preparation_save_failure() -> void:
	var gs := GameStateScript.new()
	gs.reset_profile()
	check(gs.accept_contract(&"cold_chain_delivery"), "save-failure fixture accepts delivery")
	var before: int = gs.credits
	var blocker := ProjectSettings.globalize_path(GameStateScript.PROFILE_BACKUP_PATH)
	check(DirAccess.make_dir_absolute(blocker) == OK, "block atomic replacement")
	check(gs.prepare_contract(&"cold_chain_delivery") and gs.credits == before - 300
		and gs.get_contract(&"cold_chain_delivery").prep_paid_credits == 300,
		"accepted purchase remains coherent when persistence reports failure")
	check(not gs.prepare_contract(&"cold_chain_delivery") and gs.credits == before - 300,
		"failed disk write does not make the purchase repeatable in memory")
	check(DirAccess.remove_absolute(blocker) == OK, "remove only the deliberate blocker")
	check(gs.save_profile(), "normal save can persist the existing purchase without repurchasing")
	var restored := GameStateScript.new()
	check(restored.load_profile() and restored.credits == before - 300
		and restored.get_contract(&"cold_chain_delivery").prep_paid_credits == 300,
		"save recovery retains the single debit")
	restored.reset_profile()
	gs.free()
	restored.free()
```

Run:

```powershell
Sync-PreparationStage
Invoke-PreparationSuite test_persistence
```

Expected before Task 2: lost paid-state restoration and absent migration/validation cause failures. Expected error output from intentional corrupt/save-failure fixtures is not a reason to suppress diagnostics.

- [ ] **Step 2: Implement explicit schema migration and restoration.**

Set:

```gdscript
const PROFILE_VERSION := 4
```

Keep `_migrate_v1_profile`'s final `migrated.version = 2`. Change only `_migrate_v2_profile`'s output version to:

```gdscript
migrated.version = 3
```

Add:

```gdscript
func _migrate_v3_profile(data: Dictionary) -> Dictionary:
	var migrated := data.duplicate(true)
	for record: Dictionary in migrated.contracts:
		record.prep_paid_credits = 0
	migrated.version = 4
	return migrated
```

`_read_profile_candidate` continues parsing JSON, running the existing guarded v1 contact migration, and validating candidates. In `_validate_profile`, accept these internal staging versions after its existing integer check:

```gdscript
if profile_version != 2 and profile_version != 3 and profile_version != 4:
	return "profile version is incompatible"
```

Replace the successful-candidate branch in `load_profile` with:

```gdscript
if parsed != null:
	var migrated := int(parsed.version) < PROFILE_VERSION
	if int(parsed.version) == 2:
		parsed = _migrate_v2_profile(parsed)
		if not _validate_profile(parsed).is_empty():
			continue
	if int(parsed.version) == 3:
		parsed = _migrate_v3_profile(parsed)
		if not _validate_profile(parsed).is_empty():
			continue
	_apply_profile(parsed)
	var reconciled := _settle_contract_deadlines(current_minute())
	if migrated or reconciled:
		save_profile()
	return true
```

Keep candidate iteration, invalid-profile handling, and atomic file behavior. Do not migrate unvalidated candidate arrays. Save failure reports the existing error but does not reset successfully loaded progress or make loading report a false failure.

In `_apply_profile`, add the paid amount to the existing mutable-field list:

```gdscript
for key in [&"is_playable", &"status", &"phase", &"resolution_id",
		&"deadline_at_minute", &"prep_paid_credits"]:
	restored_contracts[index][key] = record[key]
```

`_profile_payload` already serializes runtime contracts. Do not introduce a second save map or restore saved preparation dictionaries/choices. Snapshot-only `preparation.choice` never enters runtime contracts.

- [ ] **Step 3: Extend validation without disabling deadline checks in version 4.**

In `_validate_contracts`' existing branches, make **both** positive version-3 deadline conditions use `>= 3`:

```gdscript
if profile_version >= 3:
	valid_statuses.append(&"expired")
```

The existing cutoff type/state validation block also begins with `if profile_version >= 3:` and retains its body. In the terminal `deadline_missed` branch replace its version rejection with:

```gdscript
if profile_version < 3:
	return "profile deadline outcome is invalid"
```

After existing cutoff validation and before active/available/terminal phase branches, insert:

```gdscript
if profile_version == 4:
	if not _is_int_value(record.get("prep_paid_credits", null)):
		return "profile preparation spending is invalid"
	var paid := int(record.prep_paid_credits)
	if paid < 0:
		return "profile preparation spending is invalid"
	if paid > 0 and (not authored[index].has("preparation")
			or not record.is_playable or int(record.deadline_at_minute) < 0
			or (status != &"active" and status != &"completed" and status != &"failed")):
		return "profile preparation state is invalid"
```

Within the normal terminal outcome branch, after its existing authored-choice lookup and terminal-status check, insert:

```gdscript
if choice.get("requires_prep", false):
	if profile_version < 4:
		return "profile legacy preparation outcome is invalid"
	if int(record.prep_paid_credits) == 0:
		return "profile preparation outcome is unpaid"
```

Do not require historical `paid` to equal today's cost. Preserve the deadline reason's dedicated branch; `deadline_missed` is not an authored preparation or complication choice. Paid jobs ending in basic outcomes, including abort, remain valid.

- [ ] **Step 4: Update the legacy fixture and run persistence coverage.**

In `_test_legacy_deadline_migration`'s loop removing `deadline_at_minute`, also remove the new field so the saved record is genuinely legacy:

```gdscript
c.erase("prep_paid_credits")
```

Replace the old assertion pinning on-disk version 3 with this schema/persistence check (not an internal helper-version assertion):

```gdscript
check(persisted.version == 4 and persisted.contracts[0].prep_paid_credits == 0,
	"legacy migration persists the complete current schema without charging preparation")
```

Retain its existing progress/cutoff and subsequent-load assertions. Existing deadline round-trip checks now exercise current-version deadlines too; names or messages saying version 3 may be made version-neutral without changing their behavior.

```powershell
Sync-PreparationStage
Invoke-PreparationSuite test_persistence
Invoke-PreparationSuite test_preparation
Invoke-PreparationSuite test_deadlines
```

Expected: all three suites pass, including legacy deadline windows, paid state, candidate recovery, and deliberate write-error handling.

- [ ] **Step 5: Commit the persistence cutover.**

```bash
git add -- autoload/game_state.gd tests/test_persistence.gd
git commit --only -m "feat: persist preparation spending in version 4 profiles" -- autoload/game_state.gd tests/test_persistence.gd
```

### Task 3: Purchase controls, outcome accounting, and runtime proof

**Files:**
- Modify `scenes/modules/contracts/contract_detail.gd` and `scenes/main/main.gd`.
- Modify `tests/test_contracts.gd` for the new paid-result edge scenario; retain existing main-scene/audio suites.
- Modify `README.md`, `context.md`, `next-features.md` only after runtime proof.
- Create the temporary main-scene smoke script only in the disposable stage, not in the repository.

**Interfaces:**
- Consumes: `prepare_contract(id)`, injected `get_contract` snapshots including `preparation.choice`, `prep_paid_credits`, deadline UI helpers, existing `contracts_changed` refresh.
- Produces: detail signal `preparation_requested(contract_id: StringName)`; main handler `_on_contract_preparation(id: StringName) -> void`.
- Changes: `_add_action(text: String, callback: Callable) -> Button`; `_render_customs(gs: Node, c: Dictionary) -> void` with its `setup` caller.
- Adds detail helpers: `_render_preparation(gs: Node, c: Dictionary) -> void`, `_prepared_outcome_text(gs: Node, c: Dictionary, choice: Dictionary, paid: int) -> String`, `_append_preparation_accounting(c: Dictionary, payout: int) -> void`.

- [ ] **Step 1: Add one focused paid-result UI regression and run it red.**

At the end of `test_contracts.gd`'s `_run()`, call `_test_preparation_result_ui()`. Append this helper; it uses existing `_text` and `_button` functions and actual state actions. Avoid another mock fixture solely for main signal forwarding.

```gdscript
func _test_preparation_result_ui() -> void:
	var gs := GameStateScript.new()
	gs.reset_profile()
	check(gs.accept_contract(&"cold_chain_delivery")
		and gs.prepare_contract(&"cold_chain_delivery"), "paid UI fixture purchases clearance")
	var detail := ContractDetail.instantiate()
	detail.setup(gs, gs.get_contract(&"cold_chain_delivery"))
	check(_button(detail, "ARRANGE INDEPENDENT CLEARANCE // 300 CR") == null
		and _button(detail, "PROCEED TO DOCK 17") != null,
		"purchased view removes buying but retains travel")
	var c: Dictionary = gs.get_contract(&"cold_chain_delivery")
	gs.advance_minutes(c.deadline_at_minute - gs.current_minute() - c.proceed_minutes)
	check(gs.proceed_contract(c.id), "late purchased journey advances")
	detail.setup(gs, gs.get_contract(c.id))
	var text := _text(detail)
	check(text.contains("DEADLINE MISSED") and text.contains("-300 CR")
		and _button(detail, "ACKNOWLEDGE") != null
		and _button(detail, "SUBMIT PRE-CLEARED CARGO DOCUMENTS") == null
		and _button(detail, "PROCEED TO DOCK 17") == null,
		"deadline result retains sunk cost and removes stale purchased actions")
	detail.free()
	gs.reset_profile()
	gs.free()
```

```powershell
Sync-PreparationStage
Invoke-PreparationSuite test_contracts
```

Before UI implementation, expect the monetary explanation assertion to fail: the deadline result currently shows only zero resolution Credits and cannot explain preparation spending.

- [ ] **Step 2: Add the purchase control and truthful outcome preview.**

In the detail script, add the catalog constant and new intent signal:

```gdscript
const ContactCatalog := preload("res://data/contacts/contact_catalog.gd")
signal preparation_requested(contract_id: StringName)
```

Change `_add_action`'s return annotation to `Button` and append `return button` after its existing `pressed.connect(callback)`. Existing callers can ignore the return; the purchase control uses it to disable unaffordable purchases. Preserve the existing button styling and callback pattern.

Add:

```gdscript
func _prepared_outcome_text(gs: Node, c: Dictionary, choice: Dictionary, paid: int) -> String:
	var contact := ContactCatalog.by_id(c.contact_id)
	var standing: int = gs.standing_for(c.contact_id)
	var gain := mini(int(choice.contact_standing_delta), ContactCatalog.TRUSTED - standing)
	var standing_text := "%s STANDING +%d" % [contact.display_name, gain]
	if standing >= ContactCatalog.TRUSTED:
		standing_text += " // ALREADY TRUSTED"
	return "\n".join([
		"PAYOUT %s CR // HEAT %+d" % [_credit_delta_text(int(choice.credit_delta)), int(choice.heat_delta)],
		"NET AFTER PREP %s CR" % _credit_delta_text(int(choice.credit_delta) - paid),
		standing_text,
		"NO NEW FAVOR DEBT // EXISTING DEBT UNCHANGED",
	])

func _render_preparation(gs: Node, c: Dictionary) -> void:
	if not c.has("preparation"):
		return
	var prep: Dictionary = c.preparation
	var choice: Dictionary = prep.choice
	var paid := int(c.prep_paid_credits)
	var cost := int(prep.cost_credits)
	if paid > 0:
		_add_preview("PREPARATION PURCHASED // %s CR PAID\nUNLOCKED: %s" % [
			GameStateScript.format_credits(paid), choice.label])
		_add_preview(_prepared_outcome_text(gs, c, choice, paid))
		return
	_add_preview("OPTIONAL PREPARATION\nUNLOCKS: " + str(choice.label))
	_add_preview(_prepared_outcome_text(gs, c, choice, cost))
	_add_preview("PAY UPFRONT // NO TIME COST // NO REFUNDS\nBenefits apply only if you use the unlocked response.")
	var button := _add_action(str(prep.label),
		func() -> void: preparation_requested.emit(_contract_id))
	button.disabled = gs.credits < cost or gs.current_minute() >= int(c.deadline_at_minute)
	if gs.credits < cost:
		_add_preview("INSUFFICIENT CREDITS // NEED %s CR" % GameStateScript.format_credits(cost))
```

Call `_render_preparation(gs, c)` in `_render_ready` after the existing `_render_timing_warning(gs, c)` and before PROCEED. Keep all existing cutoff/duration text and CLOSE behavior. Do not call it on the offer or complication view, and do not add a SKIP phase/button.

The preview exposes both cost and benefit even if the player cannot afford it. It does not disable a financially unattractive purchase or a still-valid late departure. The state action remains authoritative when a stale signal arrives.

- [ ] **Step 3: Render purchased outcomes and historical net accounting.**

Change the `setup` customs dispatch to `_render_customs(gs, c)` and update its signature. In its existing choice loop, replace only the preview call with:

```gdscript
if choice.get("requires_prep", false):
	_add_preview(_prepared_outcome_text(gs, c, choice, int(c.prep_paid_credits)))
else:
	_add_preview(choice.preview)
	if int(c.prep_paid_credits) > 0:
		_add_preview("NET AFTER PREP %s CR" % _credit_delta_text(
			int(choice.credit_delta) - int(c.prep_paid_credits)))
```

Keep the existing choice button callback unchanged. This preserves static authored previews on basic choices and makes unused-preparation costs visible when choosing one. The only additional action is the one already admitted by state filtering.

Add:

```gdscript
func _append_preparation_accounting(c: Dictionary, payout: int) -> void:
	var paid := int(c.prep_paid_credits)
	if paid == 0:
		return
	_body.text += "\nPREP PAID   -%s CR\nNET         %s CR" % [
		GameStateScript.format_credits(paid), _credit_delta_text(payout - paid)]
```

Invoke it immediately after setting `_body.text` in each result renderer, before ACKNOWLEDGE:

```gdscript
# _render_resolved: after its normal authored-choice body
_append_preparation_accounting(c, int(choice.credit_delta))

# _render_deadline_result: after its existing zero-award body
_append_preparation_accounting(c, 0)
```

Keep `_render_resolved`'s `deadline_missed` branch before any authored-choice lookup. Do not label the earlier paid amount as a new deadline penalty or deduct it while rendering. Paid outcomes need the historical amount, not the current catalog price.

- [ ] **Step 4: Wire the action through main's existing refresh flow.**

In `_on_contract_selected`, connect the new signal alongside accept/proceed/resolution:

```gdscript
detail.preparation_requested.connect(_on_contract_preparation)
```

Add the handler beside `_on_contract_accept`:

```gdscript
func _on_contract_preparation(id: StringName) -> void:
	gs.prepare_contract(id)
```

`contracts_changed` already rebuilds the selected detail; `credits_changed` already updates the HUD. Keep the deadline agent's `clock_changed` connection. No new semantic contract event, sound, polling, or standalone purchase confirmation panel.

The context host clips children and normally mirrors the Contracts panel's height. Keep new copy compact and use explicit line breaks as above. During the real surface check below, verify no preparation text or action falls outside that host at the project's 1920x1080 viewport. Do not declare UI completion from a green parser or headless unit test; any clipping caused by the added content must be corrected before shipping, without redesigning unrelated panels.

- [ ] **Step 5: Run focused UI checks and the existing suite once.**

```powershell
Sync-PreparationStage
Invoke-PreparationSuite test_contracts
Invoke-PreparationSuite test_main
Get-ChildItem -LiteralPath (Join-Path $stage 'tests') -Filter 'test_*.gd' |
    Where-Object { $_.BaseName -ne 'test_base' } |
    ForEach-Object { Invoke-PreparationSuite $_.BaseName }
```

Expected: every executed suite prints `RESULT: ALL PASSED`, with zero nonzero exits. Do not run `run_all.ps1`, which delegates to the real-project wrapper. Remove in-scope assertions that merely pin broken wording/internal layout rather than re-pinning them; retain behavioral deadline, stale-action, and accounting coverage. New assertions must defend consumer-visible behavior, not signal forwarding or helper output alone.

- [ ] **Step 6: Exercise the actual main scene in the disposable project.**

Create `preparation_smoke.gd` **only in `$stage`**, using this driver. It uses the actual autoload and main scene, clicks the real detail buttons through their signals, and throws on failure via an explicit nonzero exit. No mock state service or replacement UI is involved.

```gdscript
extends SceneTree

const MainScene := preload("res://scenes/main/main.tscn")
const DELIVERY := &"cold_chain_delivery"
const DATA := &"data_retrieval"
var gs: Node
var main: Control
var failures := 0

func _init() -> void:
	call_deferred("_run")

func require(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func detail() -> Control:
	return main.context_host.get_child(0)

func press(label: String) -> void:
	for button: Button in detail().find_children("*", "Button", true, false):
		if button.text == label:
			require(not button.disabled, "disabled action: " + label)
			if not button.disabled:
				button.pressed.emit()
			return
	require(false, "missing action: " + label)

func text() -> String:
	var result := ""
	for label: Label in detail().find_children("*", "Label", true, false):
		result += label.text + "\n"
	return result

func _run() -> void:
	gs = root.get_node("GameState")
	gs.reset_profile()
	main = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	await process_frame
	main.select_module(&"contracts")
	main._on_contract_selected(DELIVERY)
	press("ACCEPT")
	var clock: int = gs.current_minute()
	var start: int = gs.credits
	var purchase_events: Array[StringName] = []
	var on_accepted := func(_id: StringName) -> void: purchase_events.append(&"accepted")
	var on_proceeded := func(_id: StringName) -> void: purchase_events.append(&"proceeded")
	var on_resolved := func(_id: StringName, _status: StringName) -> void: purchase_events.append(&"resolved")
	gs.contract_accepted.connect(on_accepted)
	gs.contract_proceeded.connect(on_proceeded)
	gs.contract_resolved.connect(on_resolved)
	press("ARRANGE INDEPENDENT CLEARANCE // 300 CR")
	require(gs.credits == start - 300 and gs.current_minute() == clock
		and purchase_events.is_empty(), "purchase must debit once without clock or contract-audio events")
	gs.contract_accepted.disconnect(on_accepted)
	gs.contract_proceeded.disconnect(on_proceeded)
	gs.contract_resolved.disconnect(on_resolved)
	press("PROCEED TO DOCK 17")
	press("SUBMIT PRE-CLEARED CARGO DOCUMENTS")
	require(gs.credits == start + 1100 and not gs.mara_favor_owed
		and text().contains("+1,100 CR"), "prepared result must show the net payout")
	press("ACKNOWLEDGE")
	main._on_contract_selected(DATA)
	press("ACCEPT")
	require(text().contains("ALREADY TRUSTED"), "capped trust must be disclosed")
	press("PROCEED TO TRANSIT EXCHANGE")
	press("SPOOF SERVICE CREDENTIALS")
	require(gs.get_contract(DATA).status == &"completed"
		and gs.get_contract(DATA).prep_paid_credits == 0, "skipping preparation must keep the free clean route")
	main.close_context()
	gs.reset_profile()
	gs.set_active_module(&"contracts")
	gs.set_module_open(true)
	var c: Dictionary = gs.get_contract(DELIVERY)
	gs.advance_minutes(c.deadline_at_minute - gs.current_minute() - c.proceed_minutes)
	main._on_contract_selected(DELIVERY)
	press("ACCEPT")
	press("ARRANGE INDEPENDENT CLEARANCE // 300 CR")
	require(text().contains("WARNING"), "preparation must not remove the late warning")
	press("PROCEED TO DOCK 17")
	require(text().contains("DEADLINE MISSED") and text().contains("-300 CR")
		and gs.active_contract_id == &"", "purchased late trip must fail without refund")
	print("Preparation smoke user data: ", OS.get_user_data_dir())
	print("PREPARATION MAIN-SCENE SMOKE: ", "PASSED" if failures == 0 else "FAILED")
	main.queue_free()
	await process_frame
	gs.reset_profile()
	quit(0 if failures == 0 else 1)
```

Run the finite smoke driver after staging (write the driver after any staging operation that would overwrite it):

```powershell
& $godot --headless --path $stage --script res://preparation_smoke.gd
if ($LASTEXITCODE -ne 0) { throw 'Preparation main-scene smoke failed' }
```

For graphical verification, launch the staged game normally through the supervised process tool and use its disposable fresh profile. Exercise:

1. Accept Delivery. Inspect price, payout, net, debt text, no-time/no-refund text and the existing deadline information. Buy preparation, confirm immediate HUD debit, proceed, choose documents, and inspect the +1,100 CR net result.
2. Continue to Data at low Heat/Trusted Mara. Confirm capped standing is explicit; skip purchase, proceed, and select free spoofing. No prepared button should appear.
3. Start a fresh disposable profile, bypass Delivery to reach Heat 4 with Known Mara, then accept Data. Inspect the 500 CR purchase and +3,700 CR net; buy and use the work order. Compare the retained 650 CR vendor and 400 CR token alternatives. New Heat must remain zero and standing must reach Trusted.
4. On a fresh accepted Delivery, use a disposable fixture with 299 Credits to inspect the disabled purchase and explanation; 300 Credits permits it. Do not use the real profile for fixture edits.
5. Inspect prepared and unprepared screens, all action buttons, and terminal accounting within the clipped context host at the configured viewport. Confirm one additional response only, no repeated feedback on refresh, and no purchase-triggered contract sound. Restart once with an outstanding purchase to inspect retained state.

Record screenshots/direct surface observations where available. If graphical interaction is unavailable, report that limitation and the actual driver result; do not claim a visual playthrough from the headless smoke. The automated driver covers main-scene purchase/resolve/skip/deadline integration; it does not prove visual layout, audio playback, or the manual affordability/high-Heat scenarios by itself.

- [ ] **Step 7: Update current documentation after proof and remove disposable artifacts.**

Add the following factual summary to the relevant current-implementation sections of `README.md` and `context.md`, fitting their existing structure:

```text
Cold-Chain Delivery and Data Retrieval offer optional preparation before departure. A one-time upfront payment unlocks an additional response without replacing basic options or advancing time. Preparation can trade Credits for a quiet, trust-earning route without creating a new favor debt. Spending is saved, is not refunded on abort or deadline failure, and is included in the contract's net result. Other contracts have no preparation purchase; faction reputation remains deferred.
```

In `next-features.md`, mark this narrow preparation slice implemented and link the approved preparation specification. Replace the stale proposed mandatory `preparing` phase description with the actual optional ready-screen purchase. Preserve the deadline agent's completed status, publication-relative timing corrections, and its links. Leave Heat, Alerts, aftermath, and favors as future work. Do not claim a general equipment system or all-seven-contract preparation support.

No changelog exists in the inspected baseline; do not create one solely for this feature. Stop the supervised verification process, remove `preparation_smoke.gd` with the disposable stage, and remove only the unique verification user-data directory printed by the driver. Do not delete or reset the real Operator profile.

- [ ] **Step 8: Commit UI and documentation after verification.**

```bash
git add -- scenes/modules/contracts/contract_detail.gd scenes/main/main.gd tests/test_contracts.gd README.md context.md next-features.md
git commit --only -m "feat: expose optional preparation and net contract results" -- scenes/modules/contracts/contract_detail.gd scenes/main/main.gd tests/test_contracts.gd README.md context.md next-features.md
```

## Completion evidence

The implementation report must identify:

- The focused suites and final existing-suite outcomes actually observed.
- Real main-scene smoke output and the graphical scenarios actually exercised, or the explicit visual-verification limitation.
- Confirmed single charging, persistence of paid/unused/failed preparation, and preserved legacy/current deadline windows.
- The two supported purchases, the five unchanged jobs, and the absence of clock/favor/faction expansion.
- Any deviation from the approved specification; obtain user approval before narrowing behavior.

## Plan self-review / coverage map

| Approved requirement | Implementation and proof |
|---|---|
| Two authored additive purchases, exact prices and outcomes | Task 1 catalog records and behavioral trade-off script |
| One purchase, reliable result, affordability, stale/direct request safety | Task 1 action plus purchase/re-entry/guard tests |
| Preview exists before response becomes actionable | Task 1 snapshot-only projection; Task 3 actual purchase surface |
| No time, cutoff, immediate standing/Heat/favor effects | Task 1 state assertions and unchanged clock/resolution paths |
| Useful purchase versus sensible skip, capped standing | Task 1 low/high/capped Data comparisons; Task 3 dynamic preview and runtime scenarios |
| No refunds, basic alternatives, debt preservation, no second charge | Task 1 outcome cases; Task 2 terminal reloads; Task 3 net accounting |
| Version-4 schema, v1/v2/v3 migration, historical spending, rejected corruptions | Task 2 migration/validation and load-through-file tests |
| Deadline validation still applies in v4; late travel and overdue load | Task 2 broadened deadline version conditions; Tasks 1-3 deadline fixtures |
| Existing signals/setup injection, no purchase contract audio | Task 3 wiring and actual main-scene driver; existing main/audio suite |
| Actual readable UI, no clipped new controls | Task 3 graphical surface scenarios; explicit limitation if unavailable |
| No real-profile damage and no shared deadline implementation edits now | Disposable identity; implementation prerequisite and file ownership map |
| Current docs accurately describe limited scope | Task 3 post-proof documentation updates |
