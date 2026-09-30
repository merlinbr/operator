extends "res://tests/test_base.gd"

func _run() -> void:
	var reg: ModuleRegistry = load("res://resources/module_registry.tres")
	check(reg != null, "registry loads")

	var home := reg.get_module(&"home")
	check(home != null and home.unlocked, "home exists and is unlocked")
	check(reg.get_module(&"assets") == null, "assets is absent (hidden by absence)")

	var crew := reg.get_module(&"crew")
	check(crew != null and not crew.unlocked, "crew exists and is locked")
	check(reg.get_module(&"market") != null and not reg.get_module(&"market").unlocked, "market locked")
	check(reg.get_module(&"map") != null and not reg.get_module(&"map").unlocked, "map locked")

	var order := reg.rail_order()
	var ids: Array = order.map(func(m: ModuleDef) -> StringName: return m.id)
	check(ids == ([&"home", &"comms", &"contracts", &"dossier", &"crew", &"market", &"map"] as Array),
		"rail order is core then operational — got %s" % [ids])
	check(order[0].group == &"core" and order[4].group == &"operational"
		and order[6].group == &"operational", "groups ordered core→operational")
	check(reg.get_module(&"alerts") == null, "Alerts module is absent")
