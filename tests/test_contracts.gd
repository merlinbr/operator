extends "res://tests/test_base.gd"

const GameStateScript := preload("res://autoload/game_state.gd")
const ContractsPanel := preload("res://scenes/modules/contracts/contracts_panel.tscn")

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

	panel.queue_free()
	gs.queue_free()
