extends RefCounted
## MarkLedger: capacity, the full-ledger rule, and what a CUT keeps.

const MarkLedger = preload("res://scripts/take/mark_ledger.gd")


static func _point(x: float, t: float, seen: bool, taken: bool) -> Dictionary:
	return {
		"take": 1, "pos": Vector3(x, 0.05, 2.0), "facing": 0.5, "cam_yaw": 0.25, "cam_roll": 0.0,
		"evidence": {"a": {"seen": seen, "taken": taken, "attached": taken},
			"b": {"seen": false, "taken": false, "attached": false}},
		"time": t, "world_t": t, "rec_t": t,
	}


static func run(h, _tree = null) -> void:
	h.begin("mark")

	var m = MarkLedger.new()
	h.eq("default capacity is 3", m.capacity, 3)
	h.eq("starts empty", m.count(), 0)
	h.eq("no points without a checkpoint", m.points().size(), 0)
	m.checkpoint = _point(0.0, 0.0, false, false)
	m.checkpoint["kind"] = "checkpoint"
	h.ok("1st mark", m.add(_point(1.0, 1.0, false, false)))
	h.ok("2nd mark", m.add(_point(2.0, 2.0, true, false)))
	h.ok("3rd mark", m.add(_point(3.0, 3.0, true, true)))
	h.ok("ledger full", m.is_full())
	h.ok("4th mark refused, not rotated", not m.add(_point(4.0, 4.0, true, true)))
	h.eq("still three", m.count(), 3)
	h.eq("oldest mark survives a refused add", (m.marks[0]["pos"] as Vector3).x, 1.0)
	h.eq("marks are numbered 1..n", [int(m.marks[0]["no"]), int(m.marks[2]["no"])], [1, 3])
	h.eq("points: checkpoint first, then marks", m.points().size(), 4)
	h.eq("checkpoint label", MarkLedger.label(m.points()[0]), "START")
	h.eq("mark label", MarkLedger.label(m.points()[2]), "MARK 2")

	h.eq("evidence counts", MarkLedger.evidence_counts(m.marks[2]["evidence"]), Vector2i(1, 1))
	h.eq("clock format", MarkLedger.clock(75.24), "01:15.2")
	var row: String = MarkLedger.describe(m.marks[1])
	h.ok("row carries real values", row.begins_with("MARK 2") and row.contains("T 00:02.0")
		and row.contains("EVIDENCE 1 (0 TAKEN)") and row.contains("X 2.00  Z 2.00"), row)

	m.keep_through(1)
	h.eq("cut to MARK 1 keeps only MARK 1", m.count(), 1)
	h.ok("capacity comes back", m.add(_point(5.0, 5.0, false, false)))
	h.eq("new mark takes the next number", int(m.marks[1]["no"]), 2)
	m.clear()
	h.eq("cut to START clears marks", m.count(), 0)
	h.eq("checkpoint survives clear", m.points().size(), 1)
