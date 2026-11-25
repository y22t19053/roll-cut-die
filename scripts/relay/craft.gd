extends RefCounted


## What a run's leftovers are worth on the answer print.
static func shoot(marks_left: int, cuts_left: int, deaths: int) -> Dictionary:
	var marks := maxi(marks_left, 0)
	var cuts := maxi(cuts_left, 0)
	# Cap each contribution before multiplying so even large stocks cannot overflow.
	var bonus := mini(marks, 10) * 10 + mini(cuts, 7) * 15
	if deaths == 0:
		bonus += 20
	bonus = mini(bonus, 100)

	var zh_stock := PackedStringArray()
	var en_stock := PackedStringArray()
	if marks > 0:
		zh_stock.append("%d 枚标记" % marks)
		en_stock.append("%d %s" % [marks, "mark" if marks == 1 else "marks"])
	if cuts > 0:
		zh_stock.append("%d 次喊卡" % cuts)
		en_stock.append("%d %s" % [cuts, "cut" if cuts == 1 else "cuts"])
	var zh_left := "、".join(zh_stock)
	var en_left := " and ".join(en_stock)
	var zh := "什么都没剩下。"
	var en := "Nothing left over."
	var tier := "scrambled"
	if deaths == 0:
		tier = "clean"
		zh = "一条干净的成片。"
		en = "A clean answer print."
		if not zh_stock.is_empty():
			zh = "省下 %s：一条干净的成片。" % zh_left
			en = "%s unspent: a clean answer print." % en_left
	elif deaths <= 2:
		tier = "steady"
		zh = "剪得稳，但不算干净。"
		en = "Steady, not clean."
		if not zh_stock.is_empty():
			zh = "剩 %s：剪得稳，但不算干净。" % zh_left
			en = "%s left over: steady, not clean." % en_left
	elif not zh_stock.is_empty():
		zh = "剩 %s：这一卷剪乱了。" % zh_left
		en = "%s left over: a scrambled reel." % en_left
	return {"bonus": bonus, "tier": tier, "zh": zh, "en": en}


## One language, like every other line on the call sheet: the sheet is read, not
## deciphered, and printing both at once made the widest line the hardest one.
static func score_line(marks_left: int, cuts_left: int, deaths: int, zh: bool) -> String:
	var print_info := shoot(marks_left, cuts_left, deaths)
	if zh:
		return "成片质量 +%d　%s" % [print_info.bonus, print_info.zh]
	return "CRAFT +%d  %s" % [print_info.bonus, print_info.en]
