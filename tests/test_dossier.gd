extends "res://tests/test_base.gd"

const GameStateScript := preload("res://autoload/game_state.gd")

func _resolve(gs: Node, id: StringName, choice: StringName) -> void:
	check(gs.accept_contract(id), "scenario accepts %s" % id)
	check(gs.proceed_contract(id), "scenario proceeds %s" % id)
	check(gs.resolve_contract(id, choice), "scenario resolves %s" % id)

func _run() -> void:
	var gs := GameStateScript.new()
	var fresh: Dictionary = gs.dossier_snapshot()
	check(fresh.signature == {"clean": 0, "aggressive": 0, "community": 0}
		and fresh.operations.is_empty() and fresh.expired_offers.is_empty(),
		"fresh profile has no historical work")
	_resolve(gs, &"cold_chain_delivery", &"pay_fee")
	_resolve(gs, &"data_retrieval", &"spoof_credentials")
	_resolve(gs, &"dead_drop_audit", &"trace_tag")
	_resolve(gs, &"silent_partner", &"call_in_mara_favor")
	_resolve(gs, &"clinic_asset_recovery", &"maintenance_bypass")
	gs.heat = 9
	var populated: Dictionary = gs.dossier_snapshot()
	check(populated.signature == {"clean": 4, "aggressive": 1, "community": 1},
		"clinic completion overlaps aggressive work")
	check(populated.operations.map(func(row: Dictionary): return row.id)
		== [&"cold_chain_delivery", &"data_retrieval", &"dead_drop_audit",
			&"silent_partner", &"clinic_asset_recovery"],
		"history follows catalog order")
	check(populated.operations[1].outcome == "SPOOF SERVICE CREDENTIALS"
		and populated.operations[3].outcome == "CALL IN MARA'S FAVOR",
		"current Heat and spent favor do not hide historical actions")
	check(gs.go_to_ground(), "history scenario can lower Heat")
	check(gs.dossier_snapshot().signature == populated.signature,
		"lowering current Heat does not rewrite work signature")
	for scenario: Dictionary in [
		{"heat": 2, "band": "BELOW WARNING THRESHOLD"},
		{"heat": 3, "band": "ELEVATED"},
		{"heat": 5, "band": "ELEVATED"},
		{"heat": 6, "band": "WATCHED"},
		{"heat": 8, "band": "WATCHED"},
		{"heat": 9, "band": "CRITICAL"},
	]:
		gs.heat = scenario.heat
		var exposure: Dictionary = gs.dossier_snapshot()
		check(exposure.heat == scenario.heat and exposure.heat_band == scenario.band,
			"exposure follows Heat threshold boundary")
	gs.mara_favor_balance = -1
	gs.contact_standing[&"vesper_clinic"] = 2
	var before: Dictionary = gs._profile_payload()
	var detached: Dictionary = gs.dossier_snapshot()
	check(detached.contacts[0].favor_label == "YOU OWE MARA"
		and detached.contacts[1].standing == 2,
		"snapshot reflects current debt and clinic standing")
	detached.contacts[0].standing = 0
	detached.operations[0].status = &"failed"
	detached.expired_offers.clear()
	detached.signature.clean = 99
	check(gs._profile_payload() == before, "snapshot cannot mutate gameplay")
	gs.active_module = &"dossier"
	gs.module_open = true
	check(gs.save_profile(), "dossier scenario saves")
	var restored := GameStateScript.new()
	check(restored.load_profile(), "dossier scenario reloads")
	check(restored.active_module == &"dossier" and restored.module_open
		and restored.dossier_snapshot() == gs.dossier_snapshot(),
		"selection and derived dossier survive reload")
	restored.free()
	gs.free()

	var aborted := GameStateScript.new()
	_resolve(aborted, &"cold_chain_delivery", &"abort")
	check(aborted.dossier_snapshot().operations[0].status == &"failed"
		and aborted.dossier_snapshot().signature
			== {"clean": 0, "aggressive": 0, "community": 0},
		"abort is recorded but never counted as clean work")
	check(aborted.accept_contract(&"data_retrieval"), "accept deadline scenario")
	var active_cutoff: int = aborted.get_contract(&"data_retrieval").deadline_at_minute
	check(not aborted.dossier_snapshot().operations.any(
		func(row: Dictionary): return row.id == &"data_retrieval"),
		"active work is absent from historical records")
	aborted.advance_minutes(active_cutoff - aborted.current_minute())
	var missed: Dictionary = aborted.dossier_snapshot()
	var failed_job: Array = missed.operations.filter(
		func(row: Dictionary): return row.id == &"data_retrieval")
	check(failed_job.size() == 1 and failed_job[0].status == &"failed"
		and failed_job[0].outcome == "DEADLINE MISSED"
		and missed.signature == {"clean": 0, "aggressive": 0, "community": 0},
		"active deadline failure is recorded without route credit")
	aborted.free()

	var expired := GameStateScript.new()
	var cutoff: int = expired.get_contract(&"cold_chain_delivery").deadline_at_minute
	expired.advance_minutes(cutoff - expired.current_minute())
	var offers: Dictionary = expired.dossier_snapshot()
	check(offers.operations.is_empty()
		and offers.expired_offers.any(func(row: Dictionary):
			return row.id == &"cold_chain_delivery")
		and offers.signature == {"clean": 0, "aggressive": 0, "community": 0},
		"unaccepted expiry is separate from undertaken work")
	expired.free()
