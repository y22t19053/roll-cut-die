extends RefCounted
## A run in progress, written between takes.
##
## The save holds what a set remembers: the seed, the rooms already joined, the
## supplies, the deaths and every finished recording. A take that was still
## running when the game closed is not in it: the tape only keeps what it got to
## the end of, which is also what the rule says a MARK may restore.
const PATH := "user://rcd/relay_run.json"
const VERSION := 1
## Nothing here is trusted on load: a hand-edited file may only make a run
## stranger, never longer than its own seed.

static func has_run() -> bool:
	return FileAccess.file_exists(PATH)

static func clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

static func save_run(state: Dictionary) -> bool:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("relay save failed: %s" % PATH)
		return false
	var body := state.duplicate(true)
	body["version"] = VERSION
	f.store_string(JSON.stringify(body))
	f.flush()
	f.close()
	return true

static func load_run() -> Dictionary:
	if not FileAccess.file_exists(PATH): return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null: return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY: return {}
	var d: Dictionary = parsed
	if int(d.get("version",0)) != VERSION: return {}
	if not d.has("segments") or typeof(d["segments"]) != TYPE_ARRAY: return {}
	if (d["segments"] as Array).is_empty(): return {}
	return d
