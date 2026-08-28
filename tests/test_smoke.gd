extends "res://tests/test_base.gd"

const BootScene := preload("res://scenes/boot/boot.tscn")

func _run() -> void:
	var boot: Control = BootScene.instantiate()
	root.add_child(boot)
	check(boot.get_node_or_null("Center/BootPanel/Content/EnterOperations") is Button,
		"configured boot scene builds its immediate entry action")
	check(boot.get_node_or_null("DiagnosticTimer") is Timer,
		"configured boot scene starts its diagnostic timer")
	boot.queue_free()
