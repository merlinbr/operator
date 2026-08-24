extends SceneTree
## Minimal headless test base. Subclass:
##   extends "res://tests/test_base.gd"
##   func _run() -> void:
##       check(1 + 1 == 2, "math works")
## Run: .\tests\run_test.ps1 <script_name_without_extension>

var _failures := 0

func _init() -> void:
	_run()
	finish()

func _run() -> void:
	pass

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: " + msg)
	else:
		_failures += 1
		printerr("  FAIL: " + msg)

func finish() -> void:
	if _failures == 0:
		print("RESULT: ALL PASSED")
		quit(0)
	else:
		printerr("RESULT: %d FAILURE(S)" % _failures)
		quit(1)
