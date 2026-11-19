extends Node
## GameSession — the autoload that outlives every scene.
##
## It owns the take ledger and the case file, because those must survive a
## retake (the take counter goes up, but the evidence you already sealed stays
## sealed). Everything that needs to know "which take are we in" asks here, not
## the scene.

const TakeManager = preload("res://scripts/take/take_manager.gd")
const CaseState = preload("res://scripts/case/case_state.gd")
const SaveManager = preload("res://scripts/save/save_manager.gd")
const GhostTrack = preload("res://scripts/ghost/ghost_track.gd")
const Logger = preload("res://scripts/core/logger.gd")
const Loc = preload("res://scripts/core/loc.gd")

signal take_died(source: String)
signal take_cut()
signal report_filed(stance: String, verdict: String)
signal ghost_added(take_id: int)
signal language_changed(lang: String)

var takes
var case_state
## Finished takes in order: [{take: int, track: GhostTrack}]
var ghosts: Array = []
var settings := {
	"language": "en",
	"reduce_motion": false,
	"roll_scale": 1.0,
	"mouse_sensitivity": 0.0022,
}


func _ready() -> void:
	takes = TakeManager.new()
	case_state = CaseState.new()
	takes.take_died.connect(func(src: String) -> void: take_died.emit(src))
	takes.take_cut.connect(func() -> void: take_cut.emit())
	takes.report_filed.connect(func(stance: String, verdict: String) -> void:
		report_filed.emit(stance, verdict)
	)
	Loc.set_language(str(settings.get("language", "en")))
	Logger.info("session ready, take %d" % takes.take_index)


func reset_run() -> void:
	ghosts.clear()
	takes = TakeManager.new()
	takes.take_died.connect(func(src: String) -> void: take_died.emit(src))
	takes.take_cut.connect(func() -> void: take_cut.emit())
	takes.report_filed.connect(func(stance: String, verdict: String) -> void:
		report_filed.emit(stance, verdict)
	)
	takes.start_take(1)


## Register a finished take so the next attempt has to walk around it.
func add_ghost(track: Variant) -> void:
	if track == null or track.size() < 2:
		return
	ghosts.append({"take": track.take_id, "track": track})
	ghost_added.emit(track.take_id)
	Logger.info("ghost registered for take %d (%d samples, %.1fs)" % [track.take_id, track.size(), track.duration()])


## How many ghosts the next attempt will have to dodge.
func ghost_count() -> int:
	return ghosts.size()


func set_language(lang: String) -> void:
	settings["language"] = lang
	Loc.set_language(lang)
	language_changed.emit(Loc.language)


func to_dict() -> Dictionary:
	var g: Array = []
	for item: Dictionary in ghosts:
		var tr: Variant = item.get("track")
		if tr != null:
			g.append(tr.to_dict())
	return {
		"take_index": takes.take_index,
		"history": takes.history.duplicate(true),
		"outtakes": takes.outtakes.duplicate(true),
		"case": case_state.to_dict(),
		"ghosts": g,
		"settings": settings.duplicate(true),
	}


func from_dict(d: Dictionary) -> void:
	if d.is_empty():
		return
	takes.history = d.get("history", [])
	takes.outtakes = d.get("outtakes", [])
	case_state.from_dict(d.get("case", {}))
	for raw: Variant in d.get("ghosts", []):
		if raw is Dictionary:
			var tr: Variant = GhostTrack.from_dict(raw)
			if tr != null:
				ghosts.append({"take": tr.take_id, "track": tr})
	if d.get("settings") is Dictionary:
		for k: String in settings:
			if d["settings"].has(k):
				settings[k] = d["settings"][k]
	Loc.set_language(str(settings.get("language", "en")))


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
