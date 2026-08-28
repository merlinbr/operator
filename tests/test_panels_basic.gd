extends "res://tests/test_base.gd"

const GameStateScript := preload("res://autoload/game_state.gd")
const HomePanel := preload("res://scenes/modules/home/home_panel.tscn")
const CommsPanel := preload("res://scenes/modules/comms/comms_panel.tscn")

func _run() -> void:
	var native_buses := [&"Master", &"Ambience", &"SFX"]
	var original_volumes: Dictionary = {}
	var original_mutes: Dictionary = {}
	for bus_name in native_buses:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index >= 0:
			original_volumes[bus_name] = AudioServer.get_bus_volume_db(bus_index)
			original_mutes[bus_name] = AudioServer.is_bus_mute(bus_index)
	var ambience_bus := AudioServer.get_bus_index(&"Ambience")
	var sfx_bus := AudioServer.get_bus_index(&"SFX")
	check(ambience_bus >= 0 and AudioServer.get_bus_send(ambience_bus) == &"Master",
		"Ambience bus routes to Master")
	check(sfx_bus >= 0 and AudioServer.get_bus_send(sfx_bus) == &"Master",
		"SFX bus routes to Master")
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
	var master := home.find_child("MasterSlider", true, false) as HSlider
	var ambience := home.find_child("AmbienceSlider", true, false) as HSlider
	var sfx := home.find_child("SfxSlider", true, false) as HSlider
	var mute := home.find_child("MuteButton", true, false) as Button
	var master_value := home.find_child("MasterValue", true, false) as Label
	check(master != null and ambience != null and sfx != null and mute != null,
		"Home exposes all audio controls")
	check(master.value == 80.0 and ambience.value == 100.0 and sfx.value == 50.0,
		"Home applies authored session defaults")
	master.value = 35.0
	master.value_changed.emit(master.value)
	check(master_value.text == "35%" and not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")),
		"Master slider exposes and applies its value")
	mute.pressed.emit()
	check(master.value == 0.0 and AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")),
		"Mute silences Master")
	mute.pressed.emit()
	check(master.value == 35.0 and not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")),
		"Mute restores the prior Master value")
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
	for bus_name in native_buses:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index >= 0 and original_volumes.has(bus_name):
			AudioServer.set_bus_volume_db(bus_index, original_volumes[bus_name])
			AudioServer.set_bus_mute(bus_index, original_mutes[bus_name])
	gs.queue_free()
