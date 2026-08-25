extends "res://tests/test_base.gd"

const GameStateScript := preload("res://autoload/game_state.gd")

func _run() -> void:
	var gs := GameStateScript.new()

	check(gs.credits == 12480, "starts with 12480 credits")
	check(gs.district == "LOWER VESPER", "starts in LOWER VESPER")
	check(gs.workspace_collapsed == false, "workspace starts expanded")

	var got_credits := [0]
	gs.credits_changed.connect(func(v: int) -> void: got_credits[0] = v)
	gs.add_credits(520)
	check(gs.credits == 13000, "add_credits adds")
	check(got_credits[0] == 13000, "credits_changed emitted with new value")
	gs.add_credits(-99999)
	check(gs.credits == 0, "credits clamp at zero")

	check(gs.clock_text() == "23:41", "initial clock text")
	gs.advance_minutes(30)
	check(gs.clock_text() == "00:11", "clock rolls over midnight")
	check(gs.day == 15, "day increments on midnight rollover")

	var collapsed_seen := [true]
	gs.workspace_collapsed_changed.connect(func(c: bool) -> void: collapsed_seen[0] = c)
	gs.set_workspace_collapsed(true)
	check(gs.workspace_collapsed and collapsed_seen[0], "set_workspace_collapsed emits")
	gs.set_workspace_collapsed(true)
	check(collapsed_seen[0], "no duplicate emit for same state")
	gs.toggle_workspace()
	check(gs.workspace_collapsed == false, "toggle_workspace flips state")

	var ticker_seen := ["", true]
	gs.ticker_message.connect(func(text: String, highlight: bool) -> void:
		ticker_seen[0] = text
		ticker_seen[1] = highlight)
	gs.push_ticker("test message", true)
	check(ticker_seen[0] == "test message" and ticker_seen[1] == true, "push_ticker emits")

	check(GameStateScript.format_credits(12480) == "12,480", "format_credits thousands")
	check(GameStateScript.format_credits(999) == "999", "format_credits below 1000")
	check(GameStateScript.format_credits(0) == "0", "format_credits zero")

	var active_seen := [&""]
	gs.active_module_changed.connect(func(id: StringName) -> void: active_seen[0] = id)
	gs.set_active_module(&"comms")
	check(gs.active_module == &"comms", "set_active_module sets active")
	check(active_seen[0] == &"comms", "active_module_changed emitted")
	gs.set_active_module(&"comms")
	check(active_seen[0] == &"comms", "no duplicate emit for same active module")

	var open_seen := [false]
	gs.module_open_changed.connect(func(o: bool) -> void: open_seen[0] = o)
	gs.set_module_open(true)
	check(gs.module_open and open_seen[0], "set_module_open(true) emits")
	gs.set_module_open(true)
	check(open_seen[0], "no duplicate emit for same open state")
	gs.set_module_open(false)
	check(gs.module_open == false and open_seen[0] == false, "set_module_open(false) closes")

	gs.free()
