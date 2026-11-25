extends RefCounted

const Craft = preload("res://scripts/relay/craft.gd")


static func run(h, _tree = null) -> void:
	h.begin("craft")
	var empty_clean := Craft.shoot(0, 0, 0)
	h.eq("no deaths earns clean tier", empty_clean.tier, "clean")
	h.eq("clean with nothing left earns 20", empty_clean.bonus, 20)

	var clean := Craft.shoot(3, 2, 0)
	h.eq("marks, cuts, and clean bonus add up", clean.bonus, 80)
	h.eq("clean verdict names both resources (zh)", clean.zh, "省下 3 枚标记、2 次喊卡：一条干净的成片。")
	h.eq("clean verdict names both resources (en)", clean.en, "3 marks and 2 cuts unspent: a clean answer print.")

	var steady := Craft.shoot(1, 0, 2)
	h.eq("two deaths still earns steady tier", steady.tier, "steady")
	h.eq("steady verdict omits empty stock (zh)", steady.zh, "剩 1 枚标记：剪得稳，但不算干净。")
	h.eq("steady verdict uses singular (en)", steady.en, "1 mark left over: steady, not clean.")

	var scrambled := Craft.shoot(5, 5, 3)
	h.eq("three deaths earns scrambled tier", scrambled.tier, "scrambled")
	h.eq("bonus is capped at 100", scrambled.bonus, 100)
	h.eq("very large stock still earns the cap", Craft.shoot(9223372036854775807, 0, 3).bonus, 100)

	var negatives := Craft.shoot(-3, -2, 3)
	h.eq("negative stocks are treated as zero", negatives.bonus, 0)
	h.eq("negative marks do not cancel a cut", Craft.shoot(-3, 1, 3).bonus, 15)
	h.eq("nothing left verdict (zh)", negatives.zh, "什么都没剩下。")
	h.eq("nothing left verdict (en)", negatives.en, "Nothing left over.")

	var line := Craft.score_line(3, 2, 0, true)
	var line_en := Craft.score_line(3, 2, 0, false)
	h.eq("same stocks produce the same line", Craft.score_line(3, 2, 0, true), line)
	h.ok("line includes the Chinese verdict", not clean.zh.is_empty() and line.contains(clean.zh))
	h.ok("line shows the bonus", line.contains("+80"))
	h.ok("Chinese line stays Chinese", not line.contains(clean.en) and line.contains("成片质量"))
	h.ok("English line stays English", line_en.contains(clean.en) and not line_en.contains("成片质量"))
	h.ok("both lines fit on one row", not line.contains("\n") and not line_en.contains("\n"))
