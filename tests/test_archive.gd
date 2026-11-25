extends RefCounted

const Rules = preload("res://scripts/relay/relay_rules.gd")
const Loc = preload("res://scripts/core/loc.gd")


static func run(h, _tree = null) -> void:
	h.begin("archive")

	var defaults := Rules.merge_meta({})
	h.eq("empty record has all ten counters at zero", defaults, {
		"runs": 0, "best_set": 0, "deaths": 0, "wins": 0, "last_seed": 0,
		"marks_total": 0, "cuts_total": 0, "truth": 0, "coverup": 0, "frameup": 0,
	})
	var malformed := Rules.merge_meta({"runs": "3", "marks_total": 7.9, "bogus": 1})
	h.ok("string run count becomes integer zero", typeof(malformed["runs"]) == TYPE_INT and malformed["runs"] == 0)
	h.ok("float mark count becomes integer zero", typeof(malformed["marks_total"]) == TYPE_INT and malformed["marks_total"] == 0)
	h.ok("unknown keys are discarded", not malformed.has("bogus"))
	var valid := {"runs": 3, "best_set": 4, "deaths": 2, "wins": 1, "last_seed": 42,
		"marks_total": 9, "cuts_total": 5, "truth": 1, "coverup": 2, "frameup": 3}
	h.eq("known integer fields are preserved", Rules.merge_meta(valid), valid)

	for edge: Array in [[0, 0], [2, 0], [3, 1], [8, 1], [9, 2], [20, 2],
			[21, 3], [40, 3], [41, 4], [999, 4]]:
		h.eq("archive rank at %d marks" % edge[0], Rules.archive_rank(edge[0]), edge[1])

	var prior_language := Loc.language
	for language: String in ["en", "zh"]:
		Loc.set_language(language)
		for rank: int in range(5):
			h.ok("archive rank %d has a name in %s" % [rank, language], not Rules.archive_name(rank).is_empty())
	Loc.set_language(prior_language)
