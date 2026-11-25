extends RefCounted

const NextMove = preload("res://scripts/relay/next_move.gd")


static func run(h, _tree = null) -> void:
	h.begin("next_move")
	var cases := [
		[9, false, 0, 0, "short", "差 7 棚。这条路是通的。", "7 sets short. The route holds."],
		[16, true, 0, 0, "unlock", "下一档已解锁。", "The next tier is open."],
		[16, true, 1, 2, "cleared", "这一档你早就通关了。往上挑一档。", "You cleared this tier already. Go one up."],
		[16, true, 2, 2, "top", "最高档。下一次只求更干净。", "Top tier. Next time, cleaner."],
	]
	for row: Array in cases:
		var id: String = row[4]
		var zh := NextMove.line(row[0], 16, row[1], row[2], row[3], true)
		var en := NextMove.line(row[0], 16, row[1], row[2], row[3], false)
		h.eq("%s key" % id, NextMove.key(row[0], 16, row[1], row[2], row[3]), id)
		h.eq("%s line (zh)" % id, zh, row[5])
		h.eq("%s line (en)" % id, en, row[6])
		h.ok("%s lines are nonempty and distinct" % id, not zh.is_empty() and not en.is_empty() and zh != en)

	h.eq("a loss at 16 still needs one set", NextMove.line(16, 16, false, 0, 0, true), "差 1 棚。这条路是通的。")
	h.eq("done above the total is clamped", NextMove.line(20, 16, false, 0, 0, false), "1 sets short. The route holds.")
	h.eq("negative done is clamped", NextMove.line(-1, 16, false, 0, 0, false), "16 sets short. The route holds.")
