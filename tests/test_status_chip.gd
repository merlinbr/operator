extends "res://tests/test_base.gd"

const GameStateScript := preload("res://autoload/game_state.gd")
const StatusChipScene := preload("res://scenes/ui/status_chip.tscn")

func _run() -> void:
	var gs := GameStateScript.new()
	gs.name = "GameState"
	root.add_child(gs)

	var chip := StatusChipScene.instantiate()
	root.add_child(chip)
	chip.setup(gs)

	var labels: Array[Label] = []
	for label in chip.find_children("*", "Label", true, false):
		labels.append(label)
	check(labels.size() == 4, "chip has four status labels")
	check(labels[0].text == "12,480 CR", "credits label formatted — got '%s'" % labels[0].text)
	check(labels[1].text == "LOWER VESPER", "district label — got '%s'" % labels[1].text)
	check(labels[2].text == "DAY 14", "day label — got '%s'" % labels[2].text)
	check(labels[3].text == "23:41", "time label — got '%s'" % labels[3].text)

	gs.add_credits(520)
	check(labels[0].text == "13,000 CR", "credits label updates on signal")
	gs.clock_changed.emit(27, 999)
	check(labels[2].text == "DAY 27", "day label uses signal day — got '%s'" % labels[2].text)
	check(labels[3].text == "23:41", "time label uses GameState clock — got '%s'" % labels[3].text)
	gs.advance_minutes(19)
	check(labels[2].text == "DAY 15", "day label updates on clock signal")
	check(labels[3].text == "00:00", "time label updates on clock signal")
	gs.district = "GLASS MARKET"
	check(labels[1].text == "GLASS MARKET", "district label updates independently")

	var action := chip.find_child("WorkspaceAction", true, false) as Button
	check(action != null, "integrated workspace action exists")
	check(action.text == "COLLAPSE ▲", "expanded action label")
	check(action.tooltip_text == "Collapse workspace", "expanded action tooltip")
	var requested := [false]
	chip.collapse_requested.connect(func() -> void: requested[0] = true)
	action.pressed.emit()
	check(requested[0], "action emits collapse intent")

	var initial_gs := GameStateScript.new()
	initial_gs.workspace_collapsed = true
	root.add_child(initial_gs)
	var collapsed_chip := StatusChipScene.instantiate()
	root.add_child(collapsed_chip)
	collapsed_chip.setup(initial_gs)
	var collapsed_action := collapsed_chip.find_child("WorkspaceAction", true, false) as Button
	check(collapsed_action.text == "EXPAND ▼", "initially collapsed action label")
	check(collapsed_action.tooltip_text == "Expand workspace", "initially collapsed action tooltip")

	chip.queue_free()
	gs.queue_free()
	collapsed_chip.queue_free()
	initial_gs.queue_free()
