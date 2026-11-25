extends RefCounted
const Phrasebook = preload("res://scripts/relay/phrasebook.gd")

static func run(h, _tree = null) -> void:
	h.begin("phrasebook")
	var path := "user://rcd/_test_lessons.cfg"
	Phrasebook.clear(path)
	h.ok("initially unseen", not Phrasebook.seen("props", path))
	h.ok("first mark persists", Phrasebook.mark("props", path))
	h.ok("seen after reload", Phrasebook.seen("props", path))
	h.ok("second mark rejected", not Phrasebook.mark("props", path))
	h.ok("other kind remains unseen", not Phrasebook.seen("gantry", path))
	var cfg := ConfigFile.new()
	h.eq("read persisted config", cfg.load(path), OK)
	h.eq("stored boolean", cfg.get_value("lessons", "props"), true)
	cfg.set_value("other", "keep", 42)
	h.eq("seed unrelated key", cfg.save(path), OK)
	h.ok("second kind persists", Phrasebook.mark("gantry", path))
	h.ok("first kind survives", Phrasebook.seen("props", path))
	h.ok("second kind seen", Phrasebook.seen("gantry", path))
	h.eq("reload merged config", cfg.load(path), OK)
	h.eq("unrelated key survives", cfg.get_value("other", "keep"), 42)
	h.eq("unknown Chinese", Phrasebook.line("unknown", true), "")
	h.eq("unknown English", Phrasebook.line("unknown", false), "")
	h.ok("unknown mark rejected", not Phrasebook.mark("unknown", path))
	h.eq("four verbs", Phrasebook.KINDS.size(), 4)
	var lines: Array[String] = []
	for kind in Phrasebook.KINDS:
		for zh in [true, false]:
			var text := Phrasebook.line(kind, zh)
			h.ok("nonempty " + kind + str(zh), not text.is_empty())
			h.ok("unique " + kind + str(zh), text not in lines)
			h.at_most("length " + kind + str(zh), text.length(), 34 if zh else 96)
			lines.append(text)
	h.note("persisted lessons after seen():\n" + FileAccess.get_file_as_string(path))
	Phrasebook.clear(path)
	h.ok("temporary file removed", not FileAccess.file_exists(path))
