class_name PlaceholderContracts
extends RefCounted
## DUMMY contract data for the shell slice. Isolated here by design —
## replaced wholesale by the real contract data model later.

static func all() -> Array[Dictionary]:
	return [
		{
			"id": &"freight_transfer",
			"title": "Freight Transfer",
			"client": "Maas Freight Co.",
			"reward_credits": 1400,
			"risk": "LOW",
			"district": "DOCKS",
			"encrypted": false,
		},
		{
			"id": &"data_retrieval",
			"title": "Data Retrieval",
			"client": "[REDACTED]",
			"reward_credits": 4200,
			"risk": "ELEVATED",
			"district": "SECTOR 9",
			"encrypted": false,
		},
		{
			"id": &"encrypted_offer",
			"title": "[ENCRYPTED OFFER]",
			"client": "UNKNOWN",
			"reward_credits": 0,
			"risk": "UNKNOWN",
			"district": "UNKNOWN",
			"encrypted": true,
		},
	]
