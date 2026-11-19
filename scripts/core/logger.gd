extends RefCounted
## Logger — append-only runtime log at user://rcd/runtime.log.
##
## Kept deliberately dumb: one line per event, timestamped from the engine
## clock, flushed immediately so a crash still leaves the last line on disk.

const DIR := "user://rcd"
const PATH := "user://rcd/runtime.log"
const MAX_BYTES := 2 * 1024 * 1024

static var _ready_dir := false


static func _ensure() -> void:
	if _ready_dir:
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	_ready_dir = true


static func line(tag: String, msg: String) -> void:
	# Print first. Console output must never depend on the file working, and a
	# silent logger is worse than no logger: it makes every later diagnosis a
	# guessing game.
	print("[%s] %s" % [tag, msg])
	_ensure()

	var secs := float(Time.get_ticks_msec()) / 1000.0
	var entry := "%9.3f  %-8s %s" % [secs, tag, msg]

	# FileAccess.READ_WRITE does NOT create the file: on a fresh install it
	# returns null. Create it once, then append.
	if not FileAccess.file_exists(PATH):
		var created := FileAccess.open(PATH, FileAccess.WRITE)
		if created == null:
			return
		created.close()

	var f := FileAccess.open(PATH, FileAccess.READ_WRITE)
	if f == null:
		return
	if f.get_length() > MAX_BYTES:
		f.close()
		var w := FileAccess.open(PATH, FileAccess.WRITE)
		if w != null:
			w.store_line("# rotated")
			w.close()
		f = FileAccess.open(PATH, FileAccess.READ_WRITE)
		if f == null:
			return
	f.seek_end()
	f.store_line(entry)
	f.close()


static func info(msg: String) -> void:
	line("info", msg)


static func warn(msg: String) -> void:
	line("warn", msg)


static func error(msg: String) -> void:
	line("error", msg)


static func read() -> String:
	if not FileAccess.file_exists(PATH):
		return ""
	return FileAccess.get_file_as_string(PATH)
