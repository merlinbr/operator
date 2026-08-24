extends "res://tests/test_base.gd"

func _run() -> void:
	var theme: Theme = load("res://resources/operator_theme.tres")
	check(theme != null, "theme loads")
	check(theme.default_font != null, "default font is set")
	check(theme.default_font_size == 15, "default font size 15")
	check(theme.has_stylebox("panel", "PanelContainer"), "PanelContainer floating stylebox")
	check(theme.has_color("font_color", "Button"), "Button font color")
	check(theme.has_stylebox("normal", "Button"), "Button normal stylebox")
	check(theme.has_stylebox("disabled", "Button"), "Button disabled stylebox")
	check(theme.has_color("font_color", "Label"), "Label font color")
