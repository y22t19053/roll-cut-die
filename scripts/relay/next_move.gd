extends RefCounted


## One line that tells the player what the next run is for.
static func line(sets_done: int, modules: int, won: bool, tier: int, highest_unlocked: int, zh: bool) -> String:
	match key(sets_done, modules, won, tier, highest_unlocked):
		"short":
			var remaining := maxi(modules - clampi(sets_done, 0, modules), 1)
			return ("差 %d 棚。这条路是通的。" if zh else "%d sets short. The route holds.") % remaining
		"unlock":
			return "下一档已解锁。" if zh else "The next tier is open."
		"cleared":
			return "这一档你早就通关了。往上挑一档。" if zh else "You cleared this tier already. Go one up."
		_:
			return "最高档。下一次只求更干净。" if zh else "Top tier. Next time, cleaner."


static func key(_sets_done: int, _modules: int, won: bool, tier: int, highest_unlocked: int) -> String:
	if not won:
		return "short"
	if tier < 2 and tier >= highest_unlocked:
		return "unlock"
	if tier < highest_unlocked:
		return "cleared"
	return "top"
