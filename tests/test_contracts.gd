extends "res://tests/test_base.gd"

const GameStateScript := preload("res://autoload/game_state.gd")
const ContractsPanel := preload("res://scenes/modules/contracts/contracts_panel.tscn")
const ContractDetail := preload("res://scenes/modules/contracts/contract_detail.tscn")

func _run() -> void:
	var gs := GameStateScript.new()
	gs.name = "GameState"
	root.add_child(gs)

	var panel := ContractsPanel.instantiate()
	root.add_child(panel)

	var seen_id := [&""]
	panel.contract_selected.connect(func(id: StringName) -> void: seen_id[0] = id)
	panel.setup(gs, gs.contracts)

	var buttons: Array[Button] = []
	for child in panel.find_children("*", "Button", true, false):
		buttons.append(child)
	check(buttons.size() == 3, "three catalog rows")
	check(buttons[0].text.contains("COLD-CHAIN DELIVERY") and buttons[0].text.contains("1,400 CR"),
		"C-1042 shows its available reward")
	check(not buttons[0].disabled, "C-1042 is selectable")
	check(buttons[1].disabled and buttons[1].text.contains("NETWORK OFFLINE"),
		"Data Retrieval is visibly unavailable")
	check(buttons[2].disabled and buttons[2].text.contains("NETWORK OFFLINE"),
		"encrypted offer is visibly unavailable")
	buttons[0].pressed.emit()
	check(seen_id[0] == &"cold_chain_delivery", "C-1042 emits only its ID")

	var active_contracts: Array = gs.contracts.duplicate(true)
	active_contracts[0].status = &"active"
	panel.setup(gs, active_contracts)
	buttons = []
	for child in panel.find_children("*", "Button", true, false):
		buttons.append(child)
	check(not buttons[0].disabled and buttons[0].text.contains("ACTIVE"),
		"active C-1042 is selectable and visibly active")

	var completed_contracts: Array = gs.contracts.duplicate(true)
	completed_contracts[0].status = &"completed"
	panel.setup(gs, completed_contracts)
	buttons = []
	for child in panel.find_children("*", "Button", true, false):
		buttons.append(child)
	check(buttons[0].disabled and buttons[0].text.contains("COMPLETED"),
		"completed C-1042 is disabled and visibly completed")

	var failed_contracts: Array = gs.contracts.duplicate(true)
	failed_contracts[0].status = &"failed"
	panel.setup(gs, failed_contracts)
	buttons = []
	for child in panel.find_children("*", "Button", true, false):
		buttons.append(child)
	check(buttons[0].disabled and buttons[0].text.contains("FAILED"),
		"failed C-1042 is disabled and visibly failed")
	var detail := ContractDetail.instantiate()
	root.add_child(detail)
	var offer := gs.get_contract(&"cold_chain_delivery")
	var baseline_credits := gs.credits
	var baseline_heat := gs.heat
	var baseline_day := gs.day
	var baseline_phase: StringName = gs.get_contract(&"cold_chain_delivery").phase
	var accept_id := [&""]
	var proceed_id := [&""]
	var resolution_contract := [&""]
	var resolution_choice := [&""]
	var close_count := [0]
	var acknowledge_count := [0]
	detail.accept_requested.connect(func(id: StringName) -> void: accept_id[0] = id)
	detail.proceed_requested.connect(func(id: StringName) -> void: proceed_id[0] = id)
	detail.resolution_requested.connect(
		func(contract_id: StringName, choice_id: StringName) -> void:
			resolution_contract[0] = contract_id
			resolution_choice[0] = choice_id
	)
	detail.close_requested.connect(func() -> void: close_count[0] += 1)
	detail.acknowledge_requested.connect(func() -> void: acknowledge_count[0] += 1)

	detail.setup(gs, offer)
	var offer_text := _text(detail)
	check(offer_text.contains("DAY 15 // 04:00"), "offer shows the deadline")
	check(_button(detail, "ACCEPT") != null, "offer shows ACCEPT")
	check(_button(detail, "CLOSE") != null, "offer shows CLOSE")
	check(_button(detail, "DECLINE") == null, "offer does not show DECLINE")
	check(detail.find_children("*", "Button", true, false).size() == 2, "offer action cleanup starts clean")
	_button(detail, "ACCEPT").pressed.emit()
	check(accept_id[0] == &"cold_chain_delivery", "ACCEPT emits only the contract ID")
	_button(detail, "CLOSE").pressed.emit()
	check(close_count[0] == 1, "CLOSE emits its intent")

	var active := offer.duplicate(true)
	active.status = &"active"
	active.phase = &"ready_to_proceed"
	detail.setup(gs, active)
	check(_text(detail).contains("CARGO IN TRANSIT"), "active shows transit status")
	check(_button(detail, "PROCEED TO DOCK 17") != null, "active shows the dock action")
	check(_button(detail, "ACCEPT") == null, "active clears offer actions")
	_button(detail, "PROCEED TO DOCK 17").pressed.emit()
	check(proceed_id[0] == &"cold_chain_delivery", "PROCEED emits only the contract ID")

	var customs := offer.duplicate(true)
	customs.status = &"active"
	customs.phase = &"customs_hold"
	detail.setup(gs, customs)
	var customs_text := _text(detail)
	for choice: Dictionary in customs.complication.choices:
		var choice_button := _button(detail, choice.label)
		check(choice_button != null, "customs shows " + choice.label)
		check(customs_text.contains(choice.preview), "customs previews " + choice.id)
		choice_button.pressed.emit()
		check(resolution_contract[0] == &"cold_chain_delivery" and resolution_choice[0] == choice.id,
			"customs emits the selected choice ID")
	check(detail.find_children("*", "Button", true, false).size() == 4,
		"customs action cleanup leaves only current choices")

	var completed := offer.duplicate(true)
	completed.status = &"completed"
	completed.phase = &"resolved"
	completed.resolution_id = &"pay_fee"
	detail.setup(gs, completed)
	var completed_text := _text(detail)
	check(completed_text.contains("CONTRACT COMPLETE"), "completed shows terminal status")
	check(completed_text.contains(completed.complication.choices[0].result),
		"completed shows the authored operational result")
	check(completed_text.contains("CREDITS     +1,150 CR"),
		"completed formats the credit delta")
	check(_button(detail, "ACKNOWLEDGE") != null, "completed shows ACKNOWLEDGE")
	_button(detail, "ACKNOWLEDGE").pressed.emit()
	check(acknowledge_count[0] == 1, "completed ACKNOWLEDGE emits its intent")

	var failed := offer.duplicate(true)
	failed.status = &"failed"
	failed.phase = &"resolved"
	failed.resolution_id = &"abort"
	detail.setup(gs, failed)
	var failed_text := _text(detail)
	check(failed_text.contains("CONTRACT FAILED"), "failed shows terminal status")
	check(failed_text.contains(failed.complication.choices[3].result),
		"failed shows the authored operational result")
	check(failed_text.contains("CREDITS     +0 CR"),
		"failed formats a zero credit delta")
	check(_button(detail, "ACKNOWLEDGE") != null, "failed shows ACKNOWLEDGE")
	check(detail.find_children("*", "Button", true, false).size() == 1,
		"resolved action cleanup leaves only ACKNOWLEDGE")
	_button(detail, "ACKNOWLEDGE").pressed.emit()
	check(acknowledge_count[0] == 2, "failed ACKNOWLEDGE emits its intent")

	check(gs.credits == baseline_credits, "detail actions do not mutate credits")
	check(gs.heat == baseline_heat, "detail actions do not mutate heat")
	check(gs.day == baseline_day, "detail actions do not mutate day")
	check(gs.get_contract(&"cold_chain_delivery").phase == baseline_phase,
		"detail actions do not mutate contract phase")

	detail.setup(gs, {})
	check(detail.find_children("*", "Button", true, false).is_empty(),
		"empty setup clears prior actions synchronously")
	detail.queue_free()

	panel.queue_free()
	gs.queue_free()

func _text(control: Control) -> String:
	var out := ""
	for label: Label in control.find_children("*", "Label", true, false):
		out += label.text + "\n"
	return out

func _button(control: Control, text: String) -> Button:
	for button: Button in control.find_children("*", "Button", true, false):
		if button.text == text:
			return button
	return null
