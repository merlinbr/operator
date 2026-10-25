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
