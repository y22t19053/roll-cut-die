extends RefCounted
## A single local JSONL stream. Only a closed stream has the trial.jsonl name.
const CONSENT := "--west-trial-consent"
const KEYS := {KEY_W:"W", KEY_A:"A", KEY_S:"S", KEY_D:"D", KEY_UP:"UP", KEY_DOWN:"DOWN", KEY_LEFT:"LEFT", KEY_RIGHT:"RIGHT", KEY_E:"E"}
const SCHEMA := "west-corner-v1"
const LIMIT_US := 300_000_000 # Five real minutes; independent of pause, FPS and timescale.
var session := ""
var directory := ""
var _file: FileAccess
var _start_us := 0
var _frame := 0
var _bytes := 0

static func valid_session(s: String) -> bool:
	if s.length() != 32:
		return false
	for c in s:
		if not "0123456789abcdef".contains(c):
			return false
	return true

static func isolated_operator_dir(custom: bool, configured: String, actual: String) -> bool:
	var prefix := "RCD-Research/isolated/"
	if not custom or not configured.begins_with(prefix):
		return false
	var run_id := configured.trim_prefix(prefix)
	return valid_session(run_id) and actual.replace("\\", "/").ends_with("/" + configured)

func begin(args: PackedStringArray, condition: String, config: Dictionary, synthetic := false) -> bool:
	if not session.is_empty() or args != PackedStringArray([CONSENT]) or condition not in ["A", "B"]:
		return false
	if not synthetic and not isolated_operator_dir(ProjectSettings.get_setting("application/config/use_custom_user_dir", false), ProjectSettings.get_setting("application/config/custom_user_dir_name", ""), OS.get_user_data_dir()):
		push_warning("West trial refused: prepare an isolated A/B project before recording.")
		return false
	var base := "user://west_trials_qa" if synthetic else "user://west_trials"
	if DirAccess.make_dir_recursive_absolute(base) != OK:
		push_error("Cannot create west trial output directory")
		return false
	# mkdir (nonrecursive) reserves a fresh private namespace even across processes.
	session = Crypto.new().generate_random_bytes(16).hex_encode()
	directory = base.path_join(session)
	if not valid_session(session) or DirAccess.dir_exists_absolute(directory) or DirAccess.make_dir_absolute(directory) != OK:
		push_error("Cannot reserve new west trial session; no retry or overwrite")
		return false
	_file = FileAccess.open(directory.path_join("trial.partial"), FileAccess.WRITE)
	if not _file:
		push_error("Cannot open new west trial")
		return false
	_start_us = Time.get_ticks_usec()
	_frame = Engine.get_physics_frames()
	append("header", {"schema": SCHEMA, "session":session, "condition":condition,
		"source":"synthetic_QA" if synthetic else "operator_opt_in", "config":config})
	return active()

func active() -> bool:
	return _file != null

func check_deadline() -> void:
	if active() and Time.get_ticks_usec() - _start_us >= LIMIT_US:
		finish("time_limit", false)

func append(kind: String, fields: Dictionary) -> void:
	if not active():
		return
	var elapsed := Time.get_ticks_usec() - _start_us
	if elapsed >= LIMIT_US:
		if kind != "outcome":
			finish("time_limit", false)
			return
		fields = {"reason":"time_limit", "script_page_taken":false}
	var row := fields.duplicate()
	row.type = kind
	row.t_us = elapsed
	row.frame = Engine.get_physics_frames() - _frame
	var line := JSON.stringify(row) + "\n"
	_file.store_string(line)
	_bytes += line.to_utf8_buffer().size()
	if _file.get_error() != OK or _file.get_position() != _bytes:
		_file.close()
		_file = null
		push_error("West trial write failed; partial file is not evidence")

func key(e: InputEventKey) -> void:
	if KEYS.has(e.physical_keycode) and not e.echo:
		append("key", {"key":KEYS[e.physical_keycode], "pressed":e.pressed})

func finish(reason: String, taken: bool) -> bool:
	if not active():
		return false
	append("outcome", {"reason":reason, "script_page_taken":taken})
	if not active():
		return false
	_file.flush()
	var ok := _file.get_error() == OK and _file.get_length() == _bytes
	_file.close()
	_file = null
	var dest := directory.path_join("trial.jsonl")
	if not ok or FileAccess.file_exists(dest) or DirAccess.rename_absolute(directory.path_join("trial.partial"), dest) != OK:
		push_error("West trial not published; partial file is not evidence")
		return false
	print("West trial finalized: ", dest)
	return true
