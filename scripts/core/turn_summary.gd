class_name TurnSummary
extends RefCounted

# A receipt for what actually happened, not another prediction.
static func from_events(events: Array) -> Dictionary:
	var receipt := {"cut": 0, "matched": 0, "groups": 0, "rows": 0, "restock_rows": 0, "timer_rows": 0, "score": 0, "chain": 0}
	for event in events:
		if event.type == "pop":
			receipt.score += event.earned
			receipt.chain = maxi(receipt.chain, event.wave)
			if event.wave == 0:
				receipt.cut += event.points.size()
			else:
				receipt.matched += event.points.size()
				receipt.groups += event.groups.size()
		elif event.type == "row":
			receipt.rows += 1
			receipt.timer_rows += 1 if event.reason == "timer" else 0
			receipt.restock_rows += 1 if event.reason == "refill" else 0
	return receipt
