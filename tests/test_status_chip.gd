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
	check(labels.size() == 2, "chip has two labels")
	check(labels[0].text == "12,480 CR", "credits label formatted — got '%s'" % labels[0].text)
	check(labels[1].text.begins_with("LOWER VESPER // "), "district/clock label")

	gs.add_credits(520)
	check(labels[0].text == "13,000 CR", "credits label updates on signal")
	gs.advance_minutes(19)
	check(labels[1].text == "LOWER VESPER // 00:00", "clock label updates — got '%s'" % labels[1].text)

	chip.queue_free()
	gs.queue_free()
