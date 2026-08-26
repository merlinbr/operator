extends "res://tests/test_base.gd"

const GameStateScript := preload("res://autoload/game_state.gd")
const HomePanel := preload("res://scenes/modules/home/home_panel.tscn")
const CommsPanel := preload("res://scenes/modules/comms/comms_panel.tscn")

func _run() -> void:
	var gs := GameStateScript.new()
	gs.name = "GameState"
	root.add_child(gs)

	var home := HomePanel.instantiate()
	root.add_child(home)
	home.setup(gs)
	var home_text := ""
	for label in home.find_children("*", "Label", true, false):
		home_text += label.text + "\n"
	check(home_text.contains("OPERATIONS TERMINAL v0.1"), "home title")
	check(home_text.contains("12,480 CR"), "home shows credits")
	check(home_text.contains("LOWER VESPER"), "home shows district")
	gs.add_credits(1000)
	var refreshed_text := ""
	for label in home.find_children("*", "Label", true, false):
		refreshed_text += label.text + "\n"
	check(refreshed_text.contains("13,480 CR"), "home refreshes on credits change")
	home.queue_free()

	var comms := CommsPanel.instantiate()
	root.add_child(comms)
	comms.setup(gs, gs.messages)
	var rows := comms.find_children("Row*", "HBoxContainer", true, false)
	check(rows.size() == 3, "three message rows — got %d" % rows.size())
	var first_row_text := ""
	for label in rows[0].find_children("*", "Label", true, false):
		first_row_text += label.text + " "
	check(first_row_text.contains("●") and first_row_text.contains("MARA"), "unread marker and sender")
	comms.queue_free()
	gs.queue_free()
