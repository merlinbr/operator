extends "res://tests/test_base.gd"

const BootScene := preload("res://scenes/boot/boot.tscn")

func _init() -> void:
	call_deferred("_run_after_ready")

func _run_after_ready() -> void:
	_run()
	finish()

func _run() -> void:
	var boot: Control = BootScene.instantiate()
	root.add_child(boot)
	var boot_sfx := boot.get_node_or_null("BootSfx") as AudioStreamPlayer
	check(boot_sfx != null and boot_sfx.bus == &"SFX"
		and boot_sfx.stream != null
		and boot_sfx.stream.resource_path == "res://assets/audio/ui/terminal_enter.ogg",
		"boot owns the terminal-entry SFX player")
	check(is_equal_approx(boot_sfx.volume_db, linear_to_db(0.5)),
		"boot SFX uses half gain")
	_suppress_routing(boot)

	var title: Label = boot.get_node("Center/BootPanel/Content/Title")
	var diagnostics: VBoxContainer = boot.get_node("Center/BootPanel/Content/Diagnostics")
	var enter: Button = boot.get_node("Center/BootPanel/Content/EnterOperations")
	var timer: Timer = boot.get_node("DiagnosticTimer")
	check(title.text == "OPERATOR // LOCAL TERMINAL", "boot title is exact")
	check(diagnostics.get_child_count() == 5, "boot has five diagnostics")
	check(enter.text == "ENTER OPERATIONS" and not enter.disabled and enter.visible,
		"entry action is immediate and enabled")
	check(timer.wait_time == 0.9 and not timer.one_shot and not timer.is_stopped(),
		"diagnostic timer starts at the authored cadence")

	var expected := [
		"NODE       LOWER VESPER",
		"UPLINK     SECURE",
		"LOCAL TIME DAY 14 // 23:41",
		"WORK QUEUE 01 AVAILABLE",
		"MESSAGE    MARA // UNREAD",
	]
	for index in diagnostics.get_child_count():
		var line := diagnostics.get_child(index) as Label
		check(line.text == expected[index] and not line.visible,
			"diagnostic %d starts hidden with exact copy" % index)

	for index in diagnostics.get_child_count():
		boot._reveal_next_line()
		for line_index in diagnostics.get_child_count():
			var line := diagnostics.get_child(line_index) as Label
			check(line.visible == (line_index <= index),
				"reveal %d shows only the expected prefix" % index)
	boot._reveal_next_line()
	check(timer.is_stopped(), "extra reveal is a safe no-op after completion")

	var enter_count := [0]
	boot.enter_requested.connect(func() -> void: enter_count[0] += 1)
	boot._enter_operations()
	check(boot._entering and timer.is_stopped() and enter_count[0] == 1,
		"entry marks the boot as entering, stops timer, and emits once")
	check(boot_sfx.playing, "accepted boot entry starts its cue")
	for line in diagnostics.get_children():
		check((line as Label).visible, "entry reveals every remaining diagnostic")
	boot._enter_operations()
	check(enter_count[0] == 1, "second entry attempt is ignored")
	boot.queue_free()

	var key_boot: Control = BootScene.instantiate()
	root.add_child(key_boot)
	_suppress_routing(key_boot)
	var key_count := [0]
	key_boot.enter_requested.connect(func() -> void: key_count[0] += 1)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_A
	key_boot._on_unhandled_input(key)
	check(key_boot._entering and key_count[0] == 1,
		"non-echo pressed key routes through entry")
	key_boot.queue_free()

	var action_boot: Control = BootScene.instantiate()
	root.add_child(action_boot)
	_suppress_routing(action_boot)
	var action_count := [0]
	action_boot.enter_requested.connect(func() -> void: action_count[0] += 1)
	var action := InputEventAction.new()
	action.action = &"ui_accept"
	action.pressed = true
	action_boot._on_unhandled_input(action)
	check(action_boot._entering and action_count[0] == 1,
		"ui_accept routes through entry")
	action_boot.queue_free()

func _suppress_routing(boot: Control) -> void:
	if boot.enter_requested.is_connected(boot._on_enter_requested):
		boot.enter_requested.disconnect(boot._on_enter_requested)
