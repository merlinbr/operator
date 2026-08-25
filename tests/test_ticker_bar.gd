extends "res://tests/test_base.gd"

const TickerBarScene := preload("res://scenes/ui/ticker_bar.tscn")

func _run() -> void:
	var ticker := TickerBarScene.instantiate()
	root.add_child(ticker)
	ticker._build_children() # headless harness never fires _ready(); build now

	var label: Label = ticker.find_children("*", "Label", true, false)[0]
	check(label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "ticker text is vertically centered")
	check(label.text == "", "empty on start")

	ticker.push_message("first")
	check(label.text == ">> first", "shows first message")
	ticker.push_message("second", true)
	ticker.push_message("third")
	check(label.text == ">> first", "still shows first after pushes")

	ticker._advance()
	check(label.text == ">> second", "advances to second")
	check(label.get_theme_color("font_color") == Color(0.22353, 0.81569, 1.0),
		"highlight color cyan")
	ticker._advance()
	ticker._advance()
	check(label.text == ">> first", "wraps around")

	ticker.queue_free()
