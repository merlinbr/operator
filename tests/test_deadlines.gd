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
