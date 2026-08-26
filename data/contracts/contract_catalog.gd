class_name ContractCatalog
extends RefCounted

static func all() -> Array[Dictionary]:
	return [
		{
			"id": &"cold_chain_delivery",
			"code": "C-1042",
			"title": "COLD-CHAIN DELIVERY",
			"client": "Vesper Logistics",
			"reward_credits": 1400,
			"risk": "LOW",
			"destination": "DOCK 17",
			"deadline_day": 15,
			"deadline_minute": 4 * 60,
			"is_playable": true,
			"status": &"available",
			"phase": &"offer",
			"resolution_id": &"",
			"proceed_minutes": 80,
			"complication": {
				"title": "CUSTOMS HOLD // DOCK 17",
				"body": "Cold-chain cargo flagged for manual inspection.",
				"choices": [
					{
						"id": &"pay_fee", "label": "PAY CLEARANCE FEE // 250 CR",
						"credit_delta": 1150, "heat_delta": 0, "terminal_status": &"completed",
					},
					{
						"id": &"call_mara", "label": "CALL MARA",
						"credit_delta": 1400, "heat_delta": 0, "terminal_status": &"completed",
						"sets_mara_favor_owed": true,
					},
					{
						"id": &"bypass", "label": "BYPASS INSPECTION",
						"credit_delta": 1400, "heat_delta": 2, "terminal_status": &"completed",
					},
					{
						"id": &"abort", "label": "ABORT DELIVERY",
						"credit_delta": 0, "heat_delta": 0, "terminal_status": &"failed",
					},
				],
			},
		},
		{
			"id": &"data_retrieval",
			"title": "Data Retrieval",
			"client": "[REDACTED]",
			"reward_credits": 4200,
			"risk": "ELEVATED",
			"destination": "SECTOR 9",
			"deadline_day": 0,
			"deadline_minute": 0,
			"is_playable": false,
			"status": &"available",
			"phase": &"offer",
			"resolution_id": &"",
		},
		{
			"id": &"encrypted_offer",
			"title": "[ENCRYPTED OFFER]",
			"client": "UNKNOWN",
			"reward_credits": 0,
			"risk": "UNKNOWN",
			"destination": "UNKNOWN",
			"deadline_day": 0,
			"deadline_minute": 0,
			"is_playable": false,
			"status": &"available",
			"phase": &"offer",
			"resolution_id": &"",
		},
	]
