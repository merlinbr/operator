extends "res://tests/test_base.gd"

const IconRailScene := preload("res://scenes/ui/icon_rail.tscn")

func _run() -> void:
	var reg: ModuleRegistry = load("res://resources/module_registry.tres")
	var rail := IconRailScene.instantiate()
	root.add_child(rail)

	var seen := [&""]
	rail.module_selected.connect(func(id: StringName) -> void: seen[0] = id)
	rail.setup(reg)

	var buttons: Array[Button] = []
	for child in rail.find_children("*", "Button", true, false):
		buttons.append(child)
	check(buttons.size() == 7, "seven module buttons — got %d" % buttons.size())

	var home_btn: Button = rail.get_button(&"home")
	check(home_btn != null and not home_btn.disabled, "home enabled")
	var crew_btn: Button = rail.get_button(&"crew")
	check(crew_btn != null and crew_btn.disabled, "crew disabled (locked)")
	check(crew_btn.tooltip_text.contains("LOCKED"), "locked tooltip")

	var seps := rail.find_children("*", "HSeparator", true, false)
	check(seps.size() == 2, "separators before operational and utility groups")

	home_btn.pressed.emit()
	check(seen[0] == &"home", "pressing home emits module_selected(home)")

	rail.set_active(&"comms", true)
	var comms_btn: Button = rail.get_button(&"comms")
	check(comms_btn.modulate == Color(0.22353, 0.81569, 1.0), "active+lit module highlighted cyan")
	check(home_btn.modulate == Color.WHITE, "previous unlocked module unhighlighted")
	check(crew_btn.modulate == Color(1.0, 1.0, 1.0, 0.4), "locked module stays dimmed")

	rail.set_active(&"crew", true)
	check(crew_btn.modulate == Color(1.0, 1.0, 1.0, 0.4), "active+lit locked module stays dimmed")

	rail.set_active(&"comms", false)
	check(comms_btn.modulate == Color.WHITE, "active but unlit module not highlighted")

	rail.queue_free()
