extends RefCounted
## The save file is the only thing that survives closing the game, so its
## failure modes matter more than its happy path. Every one of them is tested.

const SaveManager = preload("res://scripts/save/save_manager.gd")


static func run(h, _tree = null) -> void:
	h.begin("save")
	var path := "user://rcd_test_saves/%s.json" % Crypto.new().generate_random_bytes(16).hex_encode()

	SaveManager.clear(path)
	h.ok("no save after clear", not SaveManager.exists(path))

	var missing: Dictionary = SaveManager.load_save(path)
	h.ok("missing save reports a reason", not bool(missing["ok"]))
	h.eq("missing reason", str(missing["reason"]), "missing")

	# --- happy path --------------------------------------------------------
	var payload := {
		"take_index": 3,
		"ghosts": [{"take": 1, "track": {"version": 1, "take_id": 1, "n": 0}}],
		"case": {"evidence": {"receipt": {"seen": true, "taken": true, "attached": true}}},
		"settings": {"language": "zh"},
	}
	h.ok("save succeeds", SaveManager.save(payload, path))
	h.ok("file now exists", SaveManager.exists(path))

	var loaded: Dictionary = SaveManager.load_save(path)
	h.ok("load succeeds", bool(loaded["ok"]))
	if bool(loaded["ok"]):
		h.eq("take index survives", int(loaded["data"]["take_index"]), 3)
		h.eq("language survives", str(loaded["data"]["settings"]["language"]), "zh")
		h.eq("one ghost survives", loaded["data"]["ghosts"].size(), 1)
		h.ok("nested case state survives",
			bool(loaded["data"]["case"]["evidence"]["receipt"]["taken"]))

	# --- corrupt file ------------------------------------------------------
	var f := FileAccess.open(path, FileAccess.WRITE)
	h.ok("corrupt test can write", f != null)
	if f != null:
		f.store_string("{ this is not json")
		f.close()
	var bad: Dictionary = SaveManager.load_save(path)
	h.ok("corrupt save is refused, not crashed", not bool(bad["ok"]))
	h.eq("corrupt reason", str(bad["reason"]), "corrupt")

	# Valid JSON can still be a damaged current-version envelope.
	for envelope in [{"version": 1}, {"version": 1, "data": []}, {"version": 1, "data": null}]:
		var raw := JSON.stringify(envelope)
		var fixture := FileAccess.open(path, FileAccess.WRITE)
		fixture.store_string(raw)
		fixture.close()
		var malformed := SaveManager.load_save(path)
		h.ok("refuse malformed envelope " + raw, not malformed.ok and malformed.reason == "corrupt")
		h.eq("leave malformed envelope untouched", FileAccess.get_file_as_string(path), raw)

	# --- version mismatch --------------------------------------------------
	var w := FileAccess.open(path, FileAccess.WRITE)
	if w != null:
		w.store_string(JSON.stringify({"version": 99, "payload": {}}))
		w.close()
	var old: Dictionary = SaveManager.load_save(path)
	h.ok("future version is refused", not bool(old["ok"]))
	h.ok("future version says why", str(old["reason"]).begins_with("version_"))

	# --- a failed write must not destroy the previous good save -----------
	SaveManager.clear(path)
	h.ok("saved once", SaveManager.save({"take_index": 1}, path))
	# Saving a value JSON cannot serialise (a Node) must fail without eating
	# the file we already have.
	var hostile := {"take_index": 2, "bad": Node.new()}
	var ok_write: bool = SaveManager.save(hostile, path)
	if not ok_write:
		var still: Dictionary = SaveManager.load_save(path)
		h.ok("old save survives a failed write",
			bool(still["ok"]) and int(still["data"]["take_index"]) == 1)
	else:
		h.note("engine serialised a Node into the save; skip the rollback check")
	hostile["bad"].free()

	SaveManager.clear(path)
	h.ok("cleared at the end", not SaveManager.exists(path))
