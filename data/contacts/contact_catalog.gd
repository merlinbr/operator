class_name ContactCatalog
extends RefCounted

const COLD := 0
const KNOWN := 1
const TRUSTED := 2

static func all() -> Array[Dictionary]:
	return [
		{"id": &"mara", "display_name": "MARA", "starting_standing": KNOWN},
		{"id": &"vesper_clinic", "display_name": "VESPER CLINIC", "starting_standing": COLD},
	]
static func by_id(id: StringName) -> Dictionary:
	for contact: Dictionary in all():
		if contact.id == id:
			return contact
	return {}

static func standing_label(standing: int) -> String:
	return ["COLD", "KNOWN", "TRUSTED"][clampi(standing, COLD, TRUSTED)]
