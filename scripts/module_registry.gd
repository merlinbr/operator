class_name ModuleRegistry
extends Resource
## Data-driven list of terminal modules. The icon rail renders from this.
## Adding a module = adding a ModuleDef here (+ a scene + one entry in
## main.gd MODULE_SCENES). Hidden late-game systems are simply absent.

const GROUP_ORDER := {&"core": 0, &"operational": 1, &"utility": 2}

@export var modules: Array = [] # of ModuleDef

func get_module(id: StringName) -> ModuleDef:
	for m: ModuleDef in modules:
		if m.id == id:
			return m
	return null

func rail_order() -> Array:
	var sorted := modules.duplicate()
	sorted.sort_custom(func(a: ModuleDef, b: ModuleDef) -> bool:
		return int(GROUP_ORDER.get(a.group, 9)) < int(GROUP_ORDER.get(b.group, 9)))
	return sorted
