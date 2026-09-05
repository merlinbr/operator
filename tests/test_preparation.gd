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
