extends SceneTree
## Run exactly one test module, named by tests/only_module.txt.
##
##   echo camera > tests/only_module.txt
##   godot --headless --path . --script tests/only.gd
##
## Exists because a hung or slow module in run_all.gd swallows the whole run's
## stdout: this reports one module's timing and assertions on their own.

const Harness = preload("res://tests/harness.gd")

const MODULES := {
	"touch_layout": preload("res://tests/test_touch_layout.gd"),
	"camera": preload("res://tests/test_camera.gd"),
	"ghost": preload("res://tests/test_ghost.gd"),
	"npc": preload("res://tests/test_npc.gd"),
	"map": preload("res://tests/test_map.gd"),
	"case": preload("res://tests/test_case.gd"),
	"take": preload("res://tests/test_take.gd"),
	"mark": preload("res://tests/test_mark.gd"),
	"craft": preload("res://tests/test_craft.gd"),
	"next_move": preload("res://tests/test_next_move.gd"),
	"archive": preload("res://tests/test_archive.gd"),
	"save": preload("res://tests/test_save.gd"),
	"routes": preload("res://tests/test_routes.gd"),
	"scene": preload("res://tests/test_scene.gd"),
	"relay_link": preload("res://tests/test_relay_link.gd"),
	"set_props": preload("res://tests/test_set_props.gd"),
	"gantry": preload("res://tests/test_gantry.gd"),
	"room_families": preload("res://tests/test_room_families.gd"),
	"no_softlock": preload("res://tests/test_no_softlock.gd"),
	"score_layers": preload("res://tests/test_score_layers.gd"),
	"gantry_room": preload("res://tests/test_gantry_room.gd"),
	"run_length": preload("res://tests/test_run_length.gd"),
	"phrasebook": preload("res://tests/test_phrasebook.gd"),
	"sprint7_guard": preload("res://tests/test_sprint7_guard.gd"),
	"sprint8_guard": preload("res://tests/test_sprint8_guard.gd"),
	"focus_pause": preload("res://tests/test_focus_pause.gd"),
	"resume_pace": preload("res://tests/test_resume_pace.gd"),
	"difficulty": preload("res://tests/test_difficulty.gd"),
}

## A dead _main (runtime error inside a module) never reaches quit(), and the
## SceneTree then spins until the caller kills the process, losing stdout. Fail
## loudly instead.
const WATCHDOG_SECONDS := 60.0

var _finished := false
var _module := ""


func _init() -> void:
	call_deferred("_main")
	call_deferred("_watchdog")


func _watchdog() -> void:
	await create_timer(WATCHDOG_SECONDS).timeout
	if _finished:
		return
	print("ONLY WATCHDOG: '%s' still running after %.0f s — a runtime error killed _main." % [_module, WATCHDOG_SECONDS])
	quit(3)


func _main() -> void:
	# Same reason as run_all.gd: a module that plays a run to the end must not
	# write the player's archive.
	preload("res://scripts/relay/relay_rules.gd").set_recording(false)
	var wanted := FileAccess.get_file_as_string("res://tests/only_module.txt").strip_edges()
	_module = wanted
	if not MODULES.has(wanted):
		print("ONLY: unknown module '", wanted, "'. Known: ", ", ".join(MODULES.keys()))
		_finished = true
		quit(2)
		return
	var h := Harness.new()
	var t0 := Time.get_ticks_msec()
	await MODULES[wanted].run(h, self)
	var secs := float(Time.get_ticks_msec() - t0) / 1000.0
	print("ONLY %s: %.2f s" % [wanted, secs])
	print("RESULT %s %d/%d" % [wanted, h.passed, h.passed + h.failed])
	_finished = true
	quit(0 if h.failed == 0 else 1)
