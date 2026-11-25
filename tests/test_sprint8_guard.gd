extends RefCounted

const PHRASEBOOK := "res://scripts/relay/phrasebook.gd"
const NEXT_MOVE := "res://scripts/relay/next_move.gd"


static func run(h, _tree = null) -> void:
	h.begin("sprint8_guard")
	var relay: Script = load("res://scripts/relay/relay_run.gd")
	var rooms: Script = load("res://scripts/relay/relay_rooms.gd")
	h.eq("main set count", relay.get_script_constant_map().get("MODULES"), 16)
	h.eq("gantry indices", rooms.get_script_constant_map().get("GANTRY_SLOTS"), [3, 7, 11, 15])

	var registry: Array = load("res://tests/run_all.gd").MODULES
	for module_path: String in [PHRASEBOOK, NEXT_MOVE]:
		var name := module_path.get_file().get_basename()
		var test_path := "res://tests/test_%s.gd" % name
		var has_test := ResourceLoader.exists(test_path)
		if has_test or ResourceLoader.exists(module_path):
			h.ok("%s test registered" % name, has_test and registry.has([name, load(test_path)]))

	if ResourceLoader.exists(PHRASEBOOK):
		_phrasebook(h, load(PHRASEBOOK))
	else:
		h.note("skipped phrasebook: module absent")
	if ResourceLoader.exists(NEXT_MOVE):
		_next_move(h, load(NEXT_MOVE))
	else:
		h.note("skipped next_move: module absent")

	var rules: Script = load("res://scripts/relay/relay_rules.gd")
	if rules.has_method("archive_next_gap"):
		var gaps := {0: 3, 3: 6, 9: 12, 21: 20, 41: 0}
		for marks in gaps:
			h.eq("next rank gap at %d marks" % marks, rules.call("archive_next_gap", marks), gaps[marks])
	else:
		h.note("skipped archive_next_gap: method absent")


static func _phrasebook(h, book) -> void:
	var path := "user://sprint8_guard_%s.cfg" % Crypto.new().generate_random_bytes(8).hex_encode()
	var kinds := ["props", "gantry", "frame", "final"]
	for kind in kinds:
		h.eq("first mark for " + kind, book.mark(kind, path), true)
		for zh in [true, false]:
			h.ok("lesson %s (zh=%s)" % [kind, zh], not book.line(kind, zh).strip_edges().is_empty())
	for kind in kinds:
		h.eq("repeat mark for " + kind, book.mark(kind, path), false)
	for zh in [true, false]:
		h.eq("unknown lesson (zh=%s)" % zh, book.line("unknown", zh), "")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _next_move(h, move) -> void:
	h.ok("seven sets short", move.line(9, 16, false, 0, 0, true).contains("7"))
	h.ok("no zero-set deficit", not move.line(16, 16, false, 0, 0, true).contains("差 0"))
	h.eq("unfinished run", move.key(9, 16, false, 0, 0), "short")
	h.eq("new tier unlocked", move.key(16, 16, true, 0, 0), "unlock")
	h.eq("replayed lower tier", move.key(16, 16, true, 0, 1), "cleared")
	h.eq("highest tier cleared", move.key(16, 16, true, 2, 2), "top")
