extends RefCounted
## SaveManager — one JSON file, versioned, written via a temp file.
##
## Save data is a plain Dictionary so a broken save can never stop the game from
## booting: an unreadable or wrong-version file reports itself and is left alone
## until the player saves again.

const DIR := "user://rcd"
const PATH := "user://rcd/save.json"
const TMP := "user://rcd/save.json.tmp"
const VERSION := 1


static func exists(path: String = PATH) -> bool:
	return FileAccess.file_exists(path)


static func save(data: Dictionary, path: String = PATH) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var payload := {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"data": data,
	}
	var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(payload, "  "))
	f.close()

	var abs_tmp := ProjectSettings.globalize_path(path + ".tmp")
	var abs_dst := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs_dst)
	var err := DirAccess.rename_absolute(abs_tmp, abs_dst)
	return err == OK


## Returns {"ok": bool, "reason": String, "data": Dictionary}.
static func load_save(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "reason": "missing", "data": {}}
	var txt := FileAccess.get_file_as_string(path)
	# JSON.new().parse() reports failure to us instead of printing an engine
	# error: a broken save is an expected state we handle, not a crash log line.
	var json := JSON.new()
	if json.parse(txt) != OK:
		return {"ok": false, "reason": "corrupt", "data": {}}
	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		return {"ok": false, "reason": "corrupt", "data": {}}
	var d: Dictionary = parsed
	var ver := int(d.get("version", 0))
	var payload: Dictionary = d.get("data", {}) if d.get("data") is Dictionary else {}
	if ver != VERSION:
		return {"ok": false, "reason": "version_%d" % ver, "data": payload}
	return {"ok": true, "reason": "", "data": payload}


static func clear(path: String = PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if FileAccess.file_exists(path + ".tmp"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
