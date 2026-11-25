extends Node
## GameSession — the autoload that outlives every scene.
##
## It owns the take ledger and the case file, because those must survive a
## retake (the take counter goes up, but the evidence you already sealed stays
## sealed). Everything that needs to know "which take are we in" asks here, not
## the scene.
##
## It also owns the player's preferences (language, controls, audio, video).
## Those live in their own file, user://rcd/settings.cfg, never in the save:
## starting a new game, loading a save or a broken save never changes them.

const TakeManager = preload("res://scripts/take/take_manager.gd")
const CaseState = preload("res://scripts/case/case_state.gd")
const SaveManager = preload("res://scripts/save/save_manager.gd")
const GhostTrack = preload("res://scripts/ghost/ghost_track.gd")
const Logger = preload("res://scripts/core/logger.gd")
const Loc = preload("res://scripts/core/loc.gd")
const RollModes = preload("res://scripts/camera/roll_modes.gd")

const PREFS_PATH := "user://rcd/settings.cfg"
const PREFS_SECTION := "prefs"
const GAME_SCENE := "res://scenes/main/main.tscn"
const TITLE_SCENE := "res://scenes/front/title.tscn"

signal take_died(source: String)
signal take_cut()
signal report_filed(stance: String, verdict: String)
signal ghost_added(take_id: int)
## Fires on every add and every clear, so read-outs never wait for the next take.
signal ghosts_changed(count: int)
signal language_changed(lang: String)
## Any preference other than language changed (already applied and stored).
signal settings_changed(key: String, value: Variant)
signal focus_lost
signal focus_gained

var takes
var case_state
## Finished takes in order: [{take: int, track: GhostTrack}]
var ghosts: Array = []
## ROLL scheme under comparison: 0 CHASE, 1 SNAP, 2 ORBIT (scripts/camera/roll_modes.gd).
## ORBIT by default: the only scheme that never converges back onto the keys.
var roll_mode: int = RollModes.ORBIT
var settings := {
	"language": "en",
	"reduce_motion": false,
	"hud_scale": 1.0,
	"roll_scale": 1.0,
	"mouse_sensitivity": 0.0022,
	"master_volume": 0.8,
	"muted": false,
	"fullscreen": true,
	"vsync": true,
	"max_fps": 0,
	## "auto" shows the on-screen pad only where there is a touch screen,
	## "on"/"off" force it. A keyboard player never wants thumbs on screen.
	"touch_pad": "auto",
}
## Values a string preference may take; anything else falls back to the default.
const CHOICES := {
	"touch_pad": ["auto", "on", "off"],
}
## Valid range per numeric preference: [min, max].
const RANGES := {
	"roll_scale": [0.0, 1.5],
	"hud_scale": [0.8, 1.5],
	"mouse_sensitivity": [0.0005, 0.006],
	"master_volume": [0.0, 1.0],
	"max_fps": [0, 240],
}
## False for headless/tooling runs: they neither read nor write the player's
## preference file, and run in English so text assertions stay stable.
var persist_prefs := true
## Human-readable reason the last preference write failed, "" when fine.
var prefs_error := ""

## Set by the title screen before it opens the studio, consumed once by main.
## "" = direct launch (tests, trials, editor F6): take 1 on the current session.
var _start_request := ""
var _pending_save: Dictionary = {}


func _ready() -> void:
	takes = TakeManager.new()
	case_state = CaseState.new()
	_wire_takes()
	_wire_focus()
	_init_preferences()
	Logger.info("session ready, take %d, language %s" % [takes.take_index, Loc.language])


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			focus_lost.emit()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			focus_gained.emit()


## Browsers never send the application-level focus pair: switching tabs fires
## the canvas `blur`, which Godot forwards as a window focus signal. Both paths
## land on the same two signals so a run pauses wherever the player went.
func _wire_focus() -> void:
	var win := get_window()
	if win == null:
		return
	if not win.focus_exited.is_connected(_on_window_focus_out):
		win.focus_exited.connect(_on_window_focus_out)
	if not win.focus_entered.is_connected(_on_window_focus_in):
		win.focus_entered.connect(_on_window_focus_in)


func _on_window_focus_out() -> void:
	focus_lost.emit()


func _on_window_focus_in() -> void:
	focus_gained.emit()


func _wire_takes() -> void:
	takes.take_died.connect(func(src: String) -> void: take_died.emit(src))
	takes.take_cut.connect(func() -> void: take_cut.emit())
	takes.report_filed.connect(func(stance: String, verdict: String) -> void:
		report_filed.emit(stance, verdict)
	)


func reset_run() -> void:
	ghosts.clear()
	ghosts_changed.emit(0)
	takes = TakeManager.new()
	_wire_takes()
	takes.start_take(1)


## Register a finished take so the next attempt has to walk around it.
func add_ghost(track: Variant) -> void:
	if track == null or track.size() < 2:
		return
	ghosts.append({"take": track.take_id, "track": track})
	ghost_added.emit(track.take_id)
	ghosts_changed.emit(ghosts.size())
	Logger.info("ghost registered for take %d (%d samples, %.1fs)" % [track.take_id, track.size(), track.duration()])


## How many ghosts the next attempt will have to dodge.
func ghost_count() -> int:
	return ghosts.size()


func set_roll_mode(m: int) -> int:
	roll_mode = RollModes.clamp_mode(m)
	return roll_mode


func get_roll_mode() -> int:
	return roll_mode


# --- preferences -----------------------------------------------------------

static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _init_preferences() -> void:
	settings["language"] = Loc.default_language()
	if is_headless():
		persist_prefs = false
		settings["language"] = "en"
	else:
		_load_preferences()
	# A one-run override for operators: `-- --lang=en`. Not stored.
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--lang="):
			var lang := arg.substr(7).strip_edges().to_lower()
			if Loc.is_supported(lang):
				settings["language"] = lang
	Loc.set_language(str(settings["language"]))
	settings["language"] = Loc.language
	apply_engine_settings()


func _load_preferences() -> void:
	if not FileAccess.file_exists(PREFS_PATH):
		return
	var cfg := ConfigFile.new()
	var err := cfg.load(PREFS_PATH)
	if err != OK:
		# A broken preference file is not fatal: defaults apply, the file is
		# left alone until the player changes a setting.
		Logger.warn("preferences unreadable (%s), using defaults" % error_string(err))
		return
	for k: String in settings:
		if cfg.has_section_key(PREFS_SECTION, k):
			settings[k] = _sanitize(k, cfg.get_value(PREFS_SECTION, k))


func _sanitize(key: String, value: Variant) -> Variant:
	var cur: Variant = settings.get(key)
	match key:
		"language":
			var lang := str(value).to_lower()
			return lang if Loc.is_supported(lang) else Loc.default_language()
	if CHOICES.has(key):
		var pick := str(value).to_lower()
		var allowed: Array = CHOICES[key]
		return pick if allowed.has(pick) else cur
	if cur is bool:
		return bool(value) if (value is bool or value is int or value is float) else cur
	if cur is int:
		if not (value is int or value is float):
			return cur
		var r: Array = RANGES.get(key, [-2147483648, 2147483647])
		return clampi(int(value), int(r[0]), int(r[1]))
	if cur is float:
		if not (value is int or value is float):
			return cur
		var r: Array = RANGES.get(key, [-1e9, 1e9])
		return clampf(float(value), float(r[0]), float(r[1]))
	return value


func save_preferences() -> bool:
	if not persist_prefs:
		return true
	DirAccess.make_dir_recursive_absolute(PREFS_PATH.get_base_dir())
	var cfg := ConfigFile.new()
	for k: String in settings:
		cfg.set_value(PREFS_SECTION, k, settings[k])
	var err := cfg.save(PREFS_PATH)
	if err != OK:
		prefs_error = error_string(err)
		Logger.error("preferences not saved: " + prefs_error)
		return false
	prefs_error = ""
	return true


func set_language(lang: String) -> void:
	Loc.set_language(lang)
	settings["language"] = Loc.language
	save_preferences()
	language_changed.emit(Loc.language)


## Change, apply and store one preference. Unknown keys are refused.
func set_setting(key: String, value: Variant) -> bool:
	if key == "language":
		set_language(str(value))
		return true
	if not settings.has(key):
		Logger.warn("unknown setting " + key)
		return false
	settings[key] = _sanitize(key, value)
	apply_engine_settings()
	var ok := save_preferences()
	settings_changed.emit(key, settings[key])
	return ok


## Push audio and video preferences into the engine. Camera and control
## preferences are read by the studio scene (settings_changed).
func apply_engine_settings() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		var vol := float(settings["master_volume"])
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(vol, 0.0001)))
		AudioServer.set_bus_mute(bus, bool(settings["muted"]) or vol <= 0.0)
	Engine.max_fps = int(settings["max_fps"])
	if is_headless():
		return
	var want_full := bool(settings["fullscreen"])
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if want_full and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not want_full and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	# The web display server cannot change V-Sync; asking it logs a user warning
	# into the browser console on every settings apply, for a preference no
	# browser build can honour anyway. Fullscreen stays — that one works.
	if DisplayServer.get_name() != "web":
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if bool(settings["vsync"]) else DisplayServer.VSYNC_DISABLED)


# --- front end ---------------------------------------------------------------

## Read-only look at the save for the title screen. Never writes or deletes.
## Returns {ok: bool, reason: String, take: int, ghosts: int}.
func save_summary() -> Dictionary:
	var r := SaveManager.load_save()
	if not r["ok"]:
		return {"ok": false, "reason": str(r["reason"]), "take": 0, "ghosts": 0}
	var d: Dictionary = r["data"]
	var g: Variant = d.get("ghosts", [])
	return {"ok": true, "reason": "", "take": int(d.get("take_index", 1)),
		"ghosts": (g as Array).size() if g is Array else 0}


## Title -> New Game. The old save stays on disk until this run saves.
func request_new_game() -> void:
	reset_run()
	_pending_save = {}
	_start_request = "new"


## Title -> Continue. Returns "" when the studio may open, otherwise the
## SaveManager reason (missing / corrupt / version_N). Nothing is written.
func request_continue() -> String:
	var r := SaveManager.load_save()
	if not r["ok"]:
		return str(r["reason"])
	reset_run()
	_pending_save = r["data"]
	_start_request = "continue"
	return ""


## Called by main after the case file is loaded. Returns the take to roll.
## A continued run resumes on the take after the one that was saved, like a
## retake: sealed evidence stays sealed, merely seen evidence is un-seen.
func consume_start_request() -> int:
	var req := _start_request
	_start_request = ""
	if req != "continue" or _pending_save.is_empty():
		_pending_save = {}
		return 1
	var data := _pending_save
	_pending_save = {}
	from_dict(data)
	case_state.on_retake()
	var next := maxi(int(data.get("take_index", 0)) + 1, 1)
	Logger.info("continue: take %d, %d ghosts" % [next, ghosts.size()])
	return next


# --- save ----------------------------------------------------------------------

func to_dict() -> Dictionary:
	var g: Array = []
	for item: Dictionary in ghosts:
		var tr: Variant = item.get("track")
		if tr != null:
			g.append(tr.to_dict())
	return {
		"take_index": takes.take_index,
		"retake_stock": takes.retake_stock,
		"mark_stock": takes.mark_stock,
		"cut_stock": takes.cut_stock,
		"history": takes.history.duplicate(true),
		"outtakes": takes.outtakes.duplicate(true),
		"case": case_state.to_dict(),
		"ghosts": g,
		"settings": settings.duplicate(true),
	}


## Restores the run. Preferences are deliberately not taken from the save:
## they belong to the player, not to the run.
func from_dict(d: Dictionary) -> void:
	if d.is_empty():
		return
	# Continue starts with a fresh ledger. In-run restores can only lower it;
	# legacy/malformed fields leave the existing stock untouched.
	for key in ["mark_stock", "cut_stock"]:
		if typeof(d.get(key)) in [TYPE_INT, TYPE_FLOAT]:
			takes.set(key, clampi(int(d[key]), 0, int(takes.get(key))))
	var stored_stock: Variant = d.get("retake_stock", takes.retake_stock)
	if typeof(stored_stock) in [TYPE_FLOAT, TYPE_INT]:
		takes.retake_stock = maxi(0, int(stored_stock))
	takes.history = d.get("history", []) if d.get("history") is Array else []
	takes.outtakes = d.get("outtakes", []) if d.get("outtakes") is Array else []
	case_state.from_dict(d.get("case", {}) if d.get("case") is Dictionary else {})
	ghosts.clear()
	var raw_ghosts: Variant = d.get("ghosts", [])
	if raw_ghosts is Array:
		for raw: Variant in raw_ghosts:
			if raw is Dictionary:
				var tr: Variant = GhostTrack.from_dict(raw)
				if tr != null:
					ghosts.append({"take": tr.take_id, "track": tr})
	ghosts_changed.emit(ghosts.size())


func save() -> bool:
	var ok := SaveManager.save(to_dict())
	Logger.info("save %s" % ("ok" if ok else "FAILED"))
	return ok


func load_latest() -> bool:
	var r := SaveManager.load_save()
	if not r["ok"]:
		Logger.info("no save loaded (%s)" % r["reason"])
		return false
	from_dict(r["data"])
	return true
