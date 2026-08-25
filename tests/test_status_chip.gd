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
	check(labels[2].custom_minimum_size.x == 80.0, "day field uses 80 px minimum width")
	check(labels[3].custom_minimum_size.x == 80.0, "time field uses 80 px minimum width")
	check(labels[2].horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
		"day value is centered")
	check(labels[3].horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER,
		"time value is centered")
	check(labels[1].custom_minimum_size.x == 0.0,
		"location field remains content-sized")
	check(chip.custom_minimum_size == Vector2(0.0, 38.0),
		"HUD removes fixed width while retaining 38 px height")

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
	var row: HBoxContainer = null
	var rows := chip.find_children("*", "HBoxContainer", true, false)
	if not rows.is_empty():
		row = rows[0] as HBoxContainer
	check(row != null, "status fields share one horizontal row")
	var row_children: Array = row.get_children() if row != null else []
	check(row_children.size() == 9, "status row removes the flexible spacer")

	var separators := chip.find_children("*", "VSeparator", true, false)
	check(separators.size() == 4, "chip has three status dividers plus the action divider")

	for child_index in [1, 3, 5]:
		var padded_divider: MarginContainer = null
		if row_children.size() > child_index:
			padded_divider = row_children[child_index] as MarginContainer
		check(padded_divider != null, "status divider %d uses a MarginContainer" % child_index)
		if padded_divider == null:
			continue
		check(padded_divider.get_child_count() == 1 and padded_divider.get_child(0) is VSeparator,
			"status divider %d contains one VSeparator" % child_index)
		check(padded_divider.get_theme_constant("margin_left") == 16,
			"status divider %d has 16 px left padding" % child_index)
		check(padded_divider.get_theme_constant("margin_right") == 16,
			"status divider %d has 16 px right padding" % child_index)

	check(row_children.size() > 7 and row_children[7] is VSeparator,
		"existing divider remains immediately after the time field")
	check(row_children.size() > 8 and row_children[8] == action,
		"workspace action remains the final row child")
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
