extends RefCounted
## Relay progression is separate from campaign saves. Mode selection and all
## consumables are session-only; the highest unlocked difficulty is permanent.
const _PATH := "user://rcd/relay_progress.cfg"
const _VERSION := 1
const _MARK := [6, 6, 3]
const _CUT := [3, 3, 2]
static var selected_mode: int = 0

static func mark_budget(mode: int) -> int:
	return _MARK[mode] if mode >= 0 and mode < _MARK.size() else 0

static func cut_budget(mode: int) -> int:
	return _CUT[mode] if mode >= 0 and mode < _CUT.size() else 0

static func unlocked(mode: int) -> bool:
	return _unlocked_at(mode, _PATH)

static func record_clear(mode: int) -> void:
	_record_clear_at(mode, _PATH)

## -1 denotes unreadable or unrecognised data. Allow novice play without
## overwriting a file written by another version of the game.
static func _highest(path: String) -> int:
	if not FileAccess.file_exists(path): return 0
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK: return -1
	var version: Variant = cfg.get_value("relay", "version", null)
	if typeof(version) != TYPE_INT or version != _VERSION: return -1
	var highest: Variant = cfg.get_value("relay", "highest_unlocked", -1)
	if typeof(highest) != TYPE_INT or highest < 0 or highest > 2: return -1
	return int(highest)

static func _unlocked_at(mode: int, path: String) -> bool:
	return mode == 0 or (mode > 0 and mode <= 2 and mode <= _highest(path))

static func _record_clear_at(mode: int, path: String) -> void:
	if mode < 0 or mode >= 2: return # Master has no further unlock.
	var highest := _highest(path)
	if mode != highest: return # Locked, replayed, or an unknown save format.
	var cfg := ConfigFile.new()
	cfg.set_value("relay", "version", _VERSION)
	cfg.set_value("relay", "highest_unlocked", mode + 1)
	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if err == OK: err = cfg.save(path)
	if err != OK: push_warning("Relay unlock could not be saved: %s" % error_string(err))
