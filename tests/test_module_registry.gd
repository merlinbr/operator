extends "res://tests/test_base.gd"

func _run() -> void:
	var reg: ModuleRegistry = load("res://resources/module_registry.tres")
	check(reg != null, "registry loads")

	var home := reg.get_module(&"home")
	check(home != null and home.unlocked, "home exists and is unlocked")
	check(home.glyph == "◈", "home glyph")
	check(reg.get_module(&"assets") == null, "assets is absent (hidden by absence)")

	var crew := reg.get_module(&"crew")
	check(crew != null and not crew.unlocked, "crew exists and is locked")
	check(reg.get_module(&"market") != null and not reg.get_module(&"market").unlocked, "market locked")
	check(reg.get_module(&"map") != null and not reg.get_module(&"map").unlocked, "map locked")

	var order := reg.rail_order()
	var ids: Array = order.map(func(m: ModuleDef) -> StringName: return m.id)
	check(ids == ([&"home", &"comms", &"contracts", &"crew", &"market", &"map", &"alerts"] as Array),
		"rail order is core, operational, utility — got %s" % [ids])
	check(order[0].group == &"core" and order[6].group == &"utility", "groups ordered core→utility")
	check(reg.get_module(&"alerts").group == &"utility", "alerts is utility group")
