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
	"camera": preload("res://tests/test_camera.gd"),
	"ghost": preload("res://tests/test_ghost.gd"),
	"npc": preload("res://tests/test_npc.gd"),
	"map": preload("res://tests/test_map.gd"),
	"case": preload("res://tests/test_case.gd"),
	"take": preload("res://tests/test_take.gd"),
	"save": preload("res://tests/test_save.gd"),
	"routes": preload("res://tests/test_routes.gd"),
	"scene": preload("res://tests/test_scene.gd"),
}


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	var wanted := FileAccess.get_file_as_string("res://tests/only_module.txt").strip_edges()
	if not MODULES.has(wanted):
		print("ONLY: unknown module '", wanted, "'. Known: ", ", ".join(MODULES.keys()))
		quit(2)
		return
	var h := Harness.new()
	var t0 := Time.get_ticks_msec()
	await MODULES[wanted].run(h, self)
	var secs := float(Time.get_ticks_msec() - t0) / 1000.0
	print("ONLY %s: %.2f s" % [wanted, secs])
	print("RESULT %s %d/%d" % [wanted, h.passed, h.passed + h.failed])
	quit(0 if h.failed == 0 else 1)
