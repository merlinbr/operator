extends "res://tests/test_base.gd"

const GameStateScript := preload("res://autoload/game_state.gd")
func _at_customs() -> Variant:
	var gs := GameStateScript.new()
	check(gs.accept_contract(&"cold_chain_delivery"), "accept setup succeeds")
	check(gs.proceed_contract(&"cold_chain_delivery"), "proceed setup succeeds")
	return gs

func _run() -> void:
	var gs := GameStateScript.new()

	check(gs.credits == 12480, "starts with 12480 credits")
	check(gs.district == "LOWER VESPER", "starts in LOWER VESPER")
	check(gs.workspace_collapsed == false, "workspace starts expanded")

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
	check(contract_gs.accept_contract(&"cold_chain_delivery"), "accepting C-1042 succeeds")
	check(contract_gs.active_contract_id == &"cold_chain_delivery", "accepted contract becomes active")
	check(contract_gs.get_contract(&"cold_chain_delivery").phase == &"ready_to_proceed",
		"accepted contract is ready to proceed")
	check(contract_gs.proceed_contract(&"cold_chain_delivery"), "proceeding active C-1042 succeeds")
	check(contract_gs.day == 15 and contract_gs.clock_text() == "01:01",
		"proceed advances exactly 80 minutes across midnight")
	check(contract_gs.get_contract(&"cold_chain_delivery").phase == &"customs_hold",
		"proceed exposes the Customs hold")
	contract_gs.free()
	var invalid_gs := GameStateScript.new()
	check(invalid_gs.accept_contract(&"cold_chain_delivery"), "invalid setup accepts")
	var invalid_active_id := invalid_gs.active_contract_id
	check(not invalid_gs.resolve_contract(&"cold_chain_delivery", &"pay_fee"),
		"cannot resolve before Customs")
	check(invalid_gs.active_contract_id == invalid_active_id and
		invalid_gs.get_contract(&"cold_chain_delivery").phase == &"ready_to_proceed",
		"invalid resolution leaves active contract unchanged")
	invalid_gs.free()

	var fee_gs: Variant = _at_customs()
	check(fee_gs.resolve_contract(&"cold_chain_delivery", &"pay_fee"), "fee resolves")
	check(fee_gs.credits == fee_gs.START_CREDITS + 1150, "fee awards net 1,150 CR")
	check(fee_gs.heat == 2, "fee preserves Heat")
	check(fee_gs.active_contract_id == &"", "fee clears active contract")
	check(fee_gs.get_contract(&"cold_chain_delivery").status == &"completed", "fee completes contract")
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
	check(abort_gs.resolve_contract(&"cold_chain_delivery", &"abort"), "abort resolves")
	check(abort_gs.credits == abort_gs.START_CREDITS and abort_gs.heat == 2,
		"abort changes neither Credits nor Heat")
	check(abort_gs.active_contract_id == &"", "abort clears active contract")
	check(abort_gs.get_contract(&"cold_chain_delivery").status == &"failed", "abort fails contract")
	abort_gs.free()

	gs.free()
