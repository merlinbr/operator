class_name ResidenceCatalog
extends RefCounted

static func all() -> Array[Dictionary]:
	return [
		{
			"id": &"lower_vesper_studio",
			"name": "Lower Vesper Studio",
			"artwork_path": "res://assets/tier-1-appartment.png",
			"monthly_rent": 2000,
			"move_in_cost": 0,
			"buyout_cost": 150000,
		},
		{
			"id": &"sector_9_loft",
			"name": "Sector 9 Loft",
			"artwork_path": "res://assets/tier-2-appartment-update.png",
			"monthly_rent": 6000,
			"move_in_cost": 8000,
			"buyout_cost": 0,
		},
	]
