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


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


static func save(data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var payload := {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"data": data,
	}
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(payload, "  "))
	f.close()

	var abs_tmp := ProjectSettings.globalize_path(TMP)
	var abs_dst := ProjectSettings.globalize_path(PATH)
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(abs_dst)
	var err := DirAccess.rename_absolute(abs_tmp, abs_dst)
	return err == OK


## Returns {"ok": bool, "reason": String, "data": Dictionary}.
static func load_save() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {"ok": false, "reason": "missing", "data": {}}
	var txt := FileAccess.get_file_as_string(PATH)
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


static func clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	if FileAccess.file_exists(TMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))
