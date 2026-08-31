extends "res://tests/test_base.gd"

const GameStateScript := preload("res://autoload/game_state.gd")
func _at_customs() -> Variant:
	var gs := GameStateScript.new()
	check(gs.accept_contract(&"cold_chain_delivery"), "accept setup succeeds")
	check(gs.proceed_contract(&"cold_chain_delivery"), "proceed setup succeeds")
	return gs

func _resolve_c1042(gs: Node, choice_id: StringName) -> void:
	check(gs.accept_contract(&"cold_chain_delivery"), "C-1042 accept setup succeeds")
	check(gs.proceed_contract(&"cold_chain_delivery"), "C-1042 proceed setup succeeds")
	check(gs.resolve_contract(&"cold_chain_delivery", choice_id), "C-1042 resolution setup succeeds")

func _at_data_customs(gs: Node, c1042_choice: StringName) -> void:
	_resolve_c1042(gs, c1042_choice)
	check(gs.accept_contract(&"data_retrieval"), "D-207 accept setup succeeds")
	check(gs.proceed_contract(&"data_retrieval"), "D-207 proceed setup succeeds")

func _choice_ids(contract: Dictionary) -> Array[StringName]:
	var ids: Array[StringName] = []
	for choice: Dictionary in contract.complication.choices:
		ids.append(choice.id)
	return ids

func _run() -> void:
	var gs := GameStateScript.new()

	check(gs.credits == 12480, "starts with 12480 credits")
	check(gs.district == "LOWER VESPER", "starts in LOWER VESPER")
	check(gs.workspace_collapsed == false, "workspace starts expanded")
	check(gs.standing_for(&"mara") == 1 and gs.standing_for(&"vesper_clinic") == 0,
		"fresh Contact standings are Known and Cold")
	check(not gs.accept_contract(&"silent_partner"),
		"Trusted Mara work rejects a Known operator")
	var standing_gs := GameStateScript.new()
	var changed_contacts := [0]
	standing_gs.contacts_changed.connect(func() -> void: changed_contacts[0] += 1)
	_resolve_c1042(standing_gs, &"call_mara")
	check(standing_gs.standing_for(&"mara") == 2 and changed_contacts[0] == 1,
		"qualifying resolution raises only Mara to Trusted")
	standing_gs.free()

	var got_credits := [0]
	gs.credits_changed.connect(func(v: int) -> void: got_credits[0] = v)
	gs.add_credits(520)
	check(gs.credits == 13000, "add_credits adds")
	check(got_credits[0] == 13000, "credits_changed emitted with new value")
	gs.add_credits(-99999)
	check(gs.credits == 0, "credits clamp at zero")

	check(gs.clock_text() == "23:41", "initial clock text")
	gs.advance_minutes(30)
	check(gs.clock_text() == "00:11", "clock rolls over midnight")
	check(gs.day == 15, "day increments on midnight rollover")

	var collapsed_seen := [true]
	gs.workspace_collapsed_changed.connect(func(c: bool) -> void: collapsed_seen[0] = c)
	gs.set_workspace_collapsed(true)
	check(gs.workspace_collapsed and collapsed_seen[0], "set_workspace_collapsed emits")
	gs.set_workspace_collapsed(true)
	check(collapsed_seen[0], "no duplicate emit for same state")
	gs.toggle_workspace()
	check(gs.workspace_collapsed == false, "toggle_workspace flips state")

	var ticker_seen := ["", true]
	gs.ticker_message.connect(func(text: String, highlight: bool) -> void:
		ticker_seen[0] = text
		ticker_seen[1] = highlight)
	gs.push_ticker("test message", true)
	check(ticker_seen[0] == "test message" and ticker_seen[1] == true, "push_ticker emits")

	check(GameStateScript.format_credits(12480) == "12,480", "format_credits thousands")
	check(GameStateScript.format_credits(999) == "999", "format_credits below 1000")
	check(GameStateScript.format_credits(0) == "0", "format_credits zero")

	var active_seen := [&""]
	gs.active_module_changed.connect(func(id: StringName) -> void: active_seen[0] = id)
	gs.set_active_module(&"comms")
	check(gs.active_module == &"comms", "set_active_module sets active")
	check(active_seen[0] == &"comms", "active_module_changed emitted")
	gs.set_active_module(&"comms")
	check(active_seen[0] == &"comms", "no duplicate emit for same active module")

	var open_seen := [false]
	gs.module_open_changed.connect(func(o: bool) -> void: open_seen[0] = o)
	gs.set_module_open(true)
	check(gs.module_open and open_seen[0], "set_module_open(true) emits")
	gs.set_module_open(true)
	check(open_seen[0], "no duplicate emit for same open state")
	gs.set_module_open(false)
	check(gs.module_open == false and open_seen[0] == false, "set_module_open(false) closes")

	var contract_gs := GameStateScript.new()
	var delivery: Dictionary = contract_gs.get_contract(&"cold_chain_delivery")
	check(delivery.status == &"available" and delivery.phase == &"offer",
		"C-1042 starts available in offer phase")
	check(contract_gs.active_contract_id == &"", "no active contract at start")
	check(not contract_gs.proceed_contract(&"cold_chain_delivery"),
		"cannot proceed before accepting")
	var contract_events: Array[Dictionary] = []
	contract_gs.contract_accepted.connect(func(id: StringName) -> void:
		contract_events.append({"event": &"accepted", "id": id}))
	contract_gs.contract_proceeded.connect(func(id: StringName) -> void:
		contract_events.append({"event": &"proceeded", "id": id}))
	contract_gs.contract_resolved.connect(func(id: StringName, status: StringName) -> void:
		contract_events.append({"event": &"resolved", "id": id, "status": status}))
	check(contract_gs.accept_contract(&"cold_chain_delivery"), "accepting C-1042 succeeds")
	check(contract_gs.active_contract_id == &"cold_chain_delivery", "accepted contract becomes active")
	check(contract_gs.get_contract(&"cold_chain_delivery").phase == &"ready_to_proceed",
		"accepted contract is ready to proceed")
	check(contract_gs.proceed_contract(&"cold_chain_delivery"), "proceeding active C-1042 succeeds")
	check(contract_gs.day == 15 and contract_gs.clock_text() == "01:01",
		"proceed advances exactly 80 minutes across midnight")
	check(contract_gs.get_contract(&"cold_chain_delivery").phase == &"customs_hold",
		"proceed exposes the Customs hold")
	check(contract_events == [
		{"event": &"accepted", "id": &"cold_chain_delivery"},
		{"event": &"proceeded", "id": &"cold_chain_delivery"},
	], "accepted transitions emit ordered semantic events once")
	contract_gs.free()
	var invalid_gs := GameStateScript.new()
	check(invalid_gs.accept_contract(&"cold_chain_delivery"), "invalid setup accepts")
	var invalid_event_count := [0]
	invalid_gs.contract_accepted.connect(func(_id: StringName) -> void:
		invalid_event_count[0] += 1)
	invalid_gs.contract_proceeded.connect(func(_id: StringName) -> void:
		invalid_event_count[0] += 1)
	invalid_gs.contract_resolved.connect(func(_id: StringName, _status: StringName) -> void:
		invalid_event_count[0] += 1)
	var invalid_active_id := invalid_gs.active_contract_id
	check(not invalid_gs.resolve_contract(&"cold_chain_delivery", &"pay_fee"),
		"cannot resolve before Customs")
	check(invalid_gs.active_contract_id == invalid_active_id and
		invalid_gs.get_contract(&"cold_chain_delivery").phase == &"ready_to_proceed",
		"invalid resolution leaves active contract unchanged")
	check(invalid_event_count[0] == 0, "rejected resolution emits no semantic events")
	invalid_gs.free()

	var fee_gs: Variant = _at_customs()
	var resolution_events: Array[Dictionary] = []
	fee_gs.contract_resolved.connect(func(id: StringName, status: StringName) -> void:
		resolution_events.append({"event": &"resolved", "id": id, "status": status}))
	check(fee_gs.resolve_contract(&"cold_chain_delivery", &"pay_fee"), "fee resolves")
	check(fee_gs.credits == fee_gs.START_CREDITS + 1150, "fee awards net 1,150 CR")
	check(fee_gs.heat == 2, "fee preserves Heat")
	check(fee_gs.active_contract_id == &"", "fee clears active contract")
	check(fee_gs.get_contract(&"cold_chain_delivery").status == &"completed", "fee completes contract")
	check(resolution_events == [{
		"event": &"resolved", "id": &"cold_chain_delivery", "status": &"completed"
	}], "completed resolution emits its semantic event once")
	fee_gs.free()

	var mara_gs: Variant = _at_customs()
	check(mara_gs.resolve_contract(&"cold_chain_delivery", &"call_mara"), "Mara resolves")
	check(mara_gs.credits == mara_gs.START_CREDITS + 1400, "Mara awards full payout")
	check(mara_gs.heat == 2 and mara_gs.mara_favor_owed, "Mara creates only the favor boolean")
	check(mara_gs.active_contract_id == &"", "Mara clears active contract")
	check(mara_gs.messages.any(func(message: Dictionary) -> bool: return message.sender == "MARA"),
		"Mara resolution records a Comms message")
	mara_gs.free()

	var bypass_gs: Variant = _at_customs()
	check(bypass_gs.resolve_contract(&"cold_chain_delivery", &"bypass"), "bypass resolves")
	check(bypass_gs.credits == bypass_gs.START_CREDITS + 1400 and bypass_gs.heat == 4,
		"bypass trades Heat for full payout")
	check(bypass_gs.active_contract_id == &"", "bypass clears active contract")
	bypass_gs.free()

	var abort_gs: Variant = _at_customs()
	var abort_resolution_events: Array[Dictionary] = []
	abort_gs.contract_resolved.connect(func(id: StringName, status: StringName) -> void:
		abort_resolution_events.append({"event": &"resolved", "id": id, "status": status}))
	check(abort_gs.resolve_contract(&"cold_chain_delivery", &"abort"), "abort resolves")
	check(abort_gs.credits == abort_gs.START_CREDITS and abort_gs.heat == 2,
		"abort changes neither Credits nor Heat")
	check(abort_gs.active_contract_id == &"", "abort clears active contract")
	check(abort_gs.get_contract(&"cold_chain_delivery").status == &"failed", "abort fails contract")
	check(abort_resolution_events == [{
		"event": &"resolved", "id": &"cold_chain_delivery", "status": &"failed"
	}], "failed resolution emits its semantic event once")
	abort_gs.free()

	var locked_gs := GameStateScript.new()
	check(not locked_gs.get_contract(&"data_retrieval").is_playable
		and not locked_gs.get_contract(&"clinic_asset_recovery").is_playable,
		"only C-1042 is playable in fresh state")
	check(not locked_gs.accept_contract(&"data_retrieval"), "locked D-207 cannot be accepted")
	locked_gs.free()

	var failure_unlock_gs := GameStateScript.new()
	_resolve_c1042(failure_unlock_gs, &"abort")
	check(failure_unlock_gs.get_contract(&"data_retrieval").is_playable,
		"failed C-1042 still unlocks D-207")
	check(failure_unlock_gs.accept_contract(&"data_retrieval"),
		"D-207 accepts after failed C-1042")
	check(failure_unlock_gs.proceed_contract(&"data_retrieval"),
		"D-207 proceeds after failed C-1042")
	check(failure_unlock_gs.resolve_contract(&"data_retrieval", &"abort"), "D-207 abort resolves")
	check(failure_unlock_gs.get_contract(&"clinic_asset_recovery").is_playable,
		"failed D-207 still unlocks R-311")
	failure_unlock_gs.free()

	var low_heat_gs := GameStateScript.new()
	_at_data_customs(low_heat_gs, &"pay_fee")
	var low_heat_ids := _choice_ids(low_heat_gs.get_contract(&"data_retrieval"))
	check(low_heat_ids.has(&"spoof_credentials") and not low_heat_ids.has(&"routed_vendor_id"),
		"Heat below four exposes spoof credentials only")
	check(low_heat_gs.resolve_contract(&"data_retrieval", &"spoof_credentials"),
		"low-Heat spoof resolves")
	check(low_heat_gs.credits == low_heat_gs.START_CREDITS + 1150 + 4200
		and low_heat_gs.heat == 2,
		"spoof awards full data reward without Heat")
	check(low_heat_gs.get_contract(&"clinic_asset_recovery").is_playable,
		"D-207 completion unlocks R-311")
	low_heat_gs.free()

	var high_heat_gs := GameStateScript.new()
	_at_data_customs(high_heat_gs, &"bypass")
	var high_heat_ids := _choice_ids(high_heat_gs.get_contract(&"data_retrieval"))
	check(not high_heat_ids.has(&"spoof_credentials") and high_heat_ids.has(&"routed_vendor_id"),
		"Heat four replaces spoof credentials with routed vendor ID")
	var high_heat_credits := high_heat_gs.credits
	check(not high_heat_gs.resolve_contract(&"data_retrieval", &"spoof_credentials"),
		"hidden spoof credential choice is rejected")
	check(high_heat_gs.credits == high_heat_credits
		and high_heat_gs.active_contract_id == &"data_retrieval",
		"hidden choice rejection does not mutate state")
	check(high_heat_gs.resolve_contract(&"data_retrieval", &"routed_vendor_id"),
		"routed vendor ID resolves at Heat four")
	check(high_heat_gs.credits == high_heat_gs.START_CREDITS + 1400 + 3550
		and high_heat_gs.heat == 4,
		"routed vendor ID pays its authored reduced reward without new Heat")
	high_heat_gs.free()

	var favor_portfolio_gs := GameStateScript.new()
	_at_data_customs(favor_portfolio_gs, &"call_mara")
	check(favor_portfolio_gs.resolve_contract(&"data_retrieval", &"buy_token"),
		"Mara setup resolves D-207")
	check(favor_portfolio_gs.accept_contract(&"clinic_asset_recovery"),
		"R-311 accepts after D-207")
	check(favor_portfolio_gs.proceed_contract(&"clinic_asset_recovery"),
		"R-311 proceeds")
	var recovery_ids := _choice_ids(favor_portfolio_gs.get_contract(&"clinic_asset_recovery"))
	check(recovery_ids.has(&"settle_mara_favor"),
		"R-311 exposes favor settlement when owed")
	check(favor_portfolio_gs.resolve_contract(&"clinic_asset_recovery", &"settle_mara_favor"),
		"favor settlement resolves")
	check(not favor_portfolio_gs.mara_favor_owed
		and favor_portfolio_gs.credits == favor_portfolio_gs.START_CREDITS + 1400 + 3800 + 2600,
		"favor settlement clears the flag and applies its lower reward")
	favor_portfolio_gs.free()

	var no_favor_gs := GameStateScript.new()
	_at_data_customs(no_favor_gs, &"pay_fee")
	check(no_favor_gs.resolve_contract(&"data_retrieval", &"buy_token"),
		"no-favor setup resolves D-207")
	check(no_favor_gs.accept_contract(&"clinic_asset_recovery"),
		"no-favor R-311 accepts")
	check(no_favor_gs.proceed_contract(&"clinic_asset_recovery"),
		"no-favor R-311 proceeds")
	check(not _choice_ids(no_favor_gs.get_contract(&"clinic_asset_recovery")).has(&"settle_mara_favor"),
		"R-311 hides settlement when no favor is owed")
	check(not no_favor_gs.resolve_contract(&"clinic_asset_recovery", &"settle_mara_favor"),
		"hidden favor settlement is rejected")
	no_favor_gs.free()
	var housing_gs := GameStateScript.new()
	housing_gs.day = 29
	housing_gs.minute_of_day = 23 * 60 + 30
	housing_gs.active_contract_id = &"cold_chain_delivery"
	check(not housing_gs.rest_until_next_day(), "REST rejects while active contract")
	housing_gs.active_contract_id = &""
	check(housing_gs.rest_until_next_day(), "REST advances without active contract")
	check(housing_gs.day == 30 and housing_gs.minute_of_day == 0, "REST reaches next midnight")
	check(housing_gs.credits == 10480 and housing_gs.rent_status == &"current"
		and housing_gs.next_rent_due_day == 60, "REST auto-pays the 2,000 CR Studio rent")
	housing_gs.day = 59
	housing_gs.minute_of_day = 1439
	housing_gs.credits = 1000
	housing_gs.advance_minutes(2)
	check(housing_gs.day == 60 and housing_gs.rent_status == &"due"
		and housing_gs.rent_due_amount == 2000, "insufficient rent creates one Studio bill")
	housing_gs.advance_minutes(3 * 1440)
	check(housing_gs.rent_status == &"overdue" and housing_gs.rent_due_amount == 2000,
		"one unpaid bill becomes overdue after three days")
	housing_gs.credits = 3000
	check(housing_gs.pay_rent(), "PAY RENT settles an overdue bill")
	check(housing_gs.credits == 1000 and housing_gs.rent_status == &"current"
		and housing_gs.rent_due_amount == 0 and housing_gs.next_rent_due_day == 93,
		"PAY RENT schedules thirty days from payment")
	housing_gs.credits = 12480
	check(housing_gs.move_to_residence(&"sector_9_loft"), "moving to the Loft succeeds")
	check(housing_gs.credits == 4480 and housing_gs.current_residence_id == &"sector_9_loft"
		and housing_gs.next_rent_due_day == housing_gs.day + 30,
		"moving deducts exactly 8,000 CR and starts a Loft term")
	check(not housing_gs.buy_out_current_residence(), "Loft buyout is rejected")
	housing_gs.current_residence_id = &"lower_vesper_studio"
	housing_gs.credits = 150000
	housing_gs.rent_status = &"current"
	housing_gs.rent_due_amount = 0
	check(housing_gs.buy_out_current_residence(), "Studio buyout succeeds")
	check(housing_gs.credits == 0 and housing_gs.owned_residence_ids == [&"lower_vesper_studio"],
		"Studio buyout deducts exactly 150,000 CR and records ownership")
	var loft_rent_gs := GameStateScript.new()
	loft_rent_gs.current_residence_id = &"sector_9_loft"
	loft_rent_gs.day = 20
	loft_rent_gs.minute_of_day = 1439
	loft_rent_gs.next_rent_due_day = 21
	loft_rent_gs.credits = 12480
	loft_rent_gs.advance_minutes(2)
	check(loft_rent_gs.credits == 6480 and loft_rent_gs.next_rent_due_day == 51,
		"calendar settlement auto-pays the 6,000 CR Loft rent")
	loft_rent_gs.free()
	var multi_due_gs := GameStateScript.new()
	multi_due_gs.day = 29
	multi_due_gs.minute_of_day = 1439
	multi_due_gs.credits = 100000
	multi_due_gs.advance_minutes(31 * 1440 + 1)
	check(multi_due_gs.day == 61 and multi_due_gs.credits == 96000
		and multi_due_gs.next_rent_due_day == 90,
		"travel crossing multiple due dates settles each rent exactly once")
	multi_due_gs.free()
	housing_gs.free()
	var blocked_housing_gs := GameStateScript.new()
	blocked_housing_gs.rent_status = &"due"
	blocked_housing_gs.rent_due_amount = 2000
	blocked_housing_gs.credits = 200000
	check(not blocked_housing_gs.move_to_residence(&"sector_9_loft")
		and not blocked_housing_gs.buy_out_current_residence(),
		"due rent blocks moving and buying")
	blocked_housing_gs.free()

	gs.free()
