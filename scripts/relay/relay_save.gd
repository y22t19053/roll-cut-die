extends RefCounted
## A run in progress, written between takes.
##
## The save holds what a set remembers: the seed, the rooms already joined, the
## supplies, the deaths and every finished recording. A take that was still
## running when the game closed is not in it: the tape only keeps what it got to
## the end of, which is also what the rule says a MARK may restore.
const PATH := "user://rcd/relay_run.json"
const VERSION := 2
static var save_path := PATH
## Nothing here is trusted on load: a hand-edited file may only make a run
## stranger, never longer than its own seed.

static func has_run() -> bool:
	return FileAccess.file_exists(save_path)

static func clear() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

static func save_run(state: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path).get_base_dir())
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("relay save failed: %s" % save_path)
		return false
	var body := state.duplicate(true)
	body["version"] = VERSION
	f.store_string(JSON.stringify(body))
	f.flush()
	f.close()
	return true

static func load_run() -> Dictionary:
	if not FileAccess.file_exists(save_path): return {}
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null: return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY: return {}
	var d: Dictionary = parsed
	if int(d.get("version",0)) not in [1, VERSION]: return {}
	if not d.has("segments") or typeof(d["segments"]) != TYPE_ARRAY: return {}
	if (d["segments"] as Array).is_empty(): return {}
	return d


## Just enough of a run to say where it stopped, for a title screen that would
## rather tell you than make you open the save to find out.
static func summary() -> Dictionary:
	var run := load_run()
	if run.is_empty(): return {}
	return {
		"sets": (run.get("segments", []) as Array).size(),
		"act": int(run.get("act", 0)),
		"seed": int(run.get("seed", 0)),
	}
