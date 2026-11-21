extends "res://scripts/main.gd"
## Experimental west approach. Enter from spawn and collect SCRIPT PAGE normally.
## Both conditions share the same solid geometry; only the route paint differs.

const TURN_WALL := [0.4, 6.0, 3.35, 6.35]
const PAINT := [
	[2.66, 6.90, 2.74, 7.55],
	[2.70, 6.86, 4.04, 6.94],
	[4.00, 5.65, 4.08, 6.90],
]

@export var route_paint := false
var trial: Node

func _ready() -> void:
	super._ready()
	if preload("res://tools/trial_build.gd").enabled() or OS.get_cmdline_user_args() == PackedStringArray(["--west-trial-consent"]):
		_install_trial(false)

func _install_trial(synthetic: bool) -> void:
	if trial != null or (synthetic and DisplayServer.get_name() != "headless"):
		return
	trial = preload("res://tools/trial_controller.gd").new()
	trial.synthetic = synthetic
	add_child(trial)

func _interact() -> void:
	super._interact()
	if trial != null:
		trial.check_collection()


func _map_source() -> Variant:
	var map: Dictionary = super._map_source()
	map["walls"].append(TURN_WALL.duplicate())
	if route_paint:
		for i in PAINT.size():
			map["props"].append({
				"id": "trial_paint_%d" % i,
				"rect": PAINT[i].duplicate(),
				"height": 0.02,
				"color": [0.82, 0.73, 0.52],
				"solid": false,
			})
	return map


func _quit_to_title() -> void:
	# The trial executable has no route into the production game/title save flow.
	get_tree().quit()


func _commit_state() -> void:
	# Trials never write the player's regular save, even when a report succeeds.
	pass


func _load_latest_state() -> void:
	# Trials do not import progress from a previous run.
	pass
