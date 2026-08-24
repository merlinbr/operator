class_name PlaceholderMessages
extends RefCounted
## DUMMY comms data for the shell slice. Isolated here by design.

static func all() -> Array[Dictionary]:
	return [
		{
			"id": &"msg_mara_crate",
			"sender": "MARA",
			"preview": "that crate better not exist, operator",
			"unread": true,
		},
		{
			"id": &"msg_system_sweep",
			"sender": "SYSTEM",
			"preview": "corp sweep expected in Sector 9 tonight",
			"unread": true,
		},
		{
			"id": &"msg_vasquez_docks",
			"sender": "VASQUEZ",
			"preview": "docks shift change is at 04:00, not 03:00",
			"unread": false,
		},
	]
