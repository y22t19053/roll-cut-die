extends RefCounted
## What a daily run is worth, and the day it belongs to. Nothing here touches the
## network or the SDK: the board wraps this, and the score has to be explainable
## as arithmetic before it is allowed to be a ranking.

const Rules = preload("res://scripts/relay/relay_rules.gd")
const Bridge = preload("res://scripts/relay/toy_bridge.gd")


static func run(h, _tree = null) -> void:
	h.begin("toy_score")

	# The day is counted in Beijing time: the board resets on that clock, and a map
	# that turned over at another moment would be a different competition.
	var key := Rules.daily_key()
	h.eq("the day prints as a date", key.length(), 10)
	h.ok("the day starts with the year", key.begins_with("20"))
	h.eq("the day has two separators", key.count("-"), 2)

	# Same date, same map, on every machine; different date, different map.
	var a := Rules.daily_seed_for("2026-11-23")
	h.eq("the same day gives the same seed", a, Rules.daily_seed_for("2026-11-23"))
	h.ok("the seed stays inside six hex digits", a > 0 and a <= 0xFFFFFF)
	h.ok("another day gives another seed", a != Rules.daily_seed_for("2026-11-24"))
	# A week of days must not repeat a map: two players arguing about "today" is
	# the whole point, and a collision would silently merge two days.
	var week := {}
	for day in range(20, 27):
		week[Rules.daily_seed_for("2026-11-%02d" % day)] = true
	h.eq("a week of days gives seven different maps", week.size(), 7)
	h.eq("today is the day the game thinks it is", Rules.daily_seed(), Rules.daily_seed_for(Rules.daily_key()))

	# The bill. Every term is something the player did.
	var cheap := Rules.run_score(0, 0, 0, 0, 0.0, false)
	h.eq("an empty run scores nothing", int(cheap["total"]), 0)
	var legs := Rules.run_score(12, 0, 0, 0, 60.0, false)
	h.eq("twelve legs at their price", int(legs["total"]), 12 * Rules.SCORE_LEG)
	var acts := Rules.run_score(12, 4, 0, 0, 60.0, false)
	h.eq("four signed acts add on top", int(acts["total"]), 12 * Rules.SCORE_LEG + 4 * Rules.SCORE_ACT)
	var clean := Rules.run_score(12, 4, 0, 0, 60.0, true)
	h.eq("a clean reel pays once", int(clean["total"]), int(acts["total"]) + Rules.SCORE_CLEAN)
	var died := Rules.run_score(12, 4, 2, 0, 60.0, true)
	h.eq("two deaths cost twice", int(died["total"]), int(clean["total"]) + 2 * Rules.SCORE_DEATH)
	var cut := Rules.run_score(12, 4, 2, 1, 60.0, true)
	h.eq("a spent cut costs once", int(cut["total"]), int(died["total"]) + Rules.SCORE_CUT)
	h.ok("the parts add up to the total",
		int(cut["total"]) == int(cut["legs"]) * Rules.SCORE_LEG + int(cut["acts"]) * Rules.SCORE_ACT
		+ Rules.SCORE_CLEAN + int(cut["deaths"]) * Rules.SCORE_DEATH + int(cut["cuts"]) * Rules.SCORE_CUT
		+ int(cut["overtime"]))

	# Time is free until the clock is out, and only then is it a price.
	var slow := Rules.run_score(12, 4, 0, 0, Rules.SCORE_GRACE - 1.0, false)
	h.eq("a slow run inside the window is not taxed", int(slow["overtime"]), 0)
	var late := Rules.run_score(12, 4, 0, 0, Rules.SCORE_GRACE + 30.0, false)
	h.eq("thirty seconds over costs thirty", int(late["overtime"]), -30)

	# Nothing can be worth less than nothing: a board of negative scores would rank
	# the worst run above a player who never finished.
	var awful := Rules.run_score(0, 0, 40, 9, 0.0, false)
	h.eq("a terrible run still scores zero", int(awful["total"]), 0)

	# One board per difficulty: boards are numbered 1..5, and a novice run must
	# never be ranked against a master run.
	h.eq("novice goes on board one", Rules.board_for(0), 1)
	h.eq("expert goes on board two", Rules.board_for(1), 2)
	h.eq("master goes on board three", Rules.board_for(2), 3)
	h.ok("an unknown mode still gets a legal board",
		Rules.board_for(7) >= 1 and Rules.board_for(7) <= 5)

	# The bridge is inert off the web: a missing platform is a normal state, not a
	# failure, and no test may depend on a browser being present.
	h.ok("no platform on a desktop build", not Bridge.available())