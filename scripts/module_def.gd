class_name ModuleDef
extends Resource
## One rail module definition. Data only.

@export var id: StringName = &""
@export var display_name: String = ""
@export var glyph: String = "?"
@export var group: StringName = &"core" # core | operational | utility
@export var unlocked := false
