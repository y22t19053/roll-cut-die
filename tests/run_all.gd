extends SceneTree
## One entry point for every automated check in the project.
##
##   godot --headless --path . --script tests/run_all.gd
##
## Exit code 0 means every assertion passed. Anything else is a red build and
## the failure text says which module and which rule.
##
## Module order is deliberate: pure logic first (fast, no scene), the room and
## its routes next, and the real scene last, because it is the only one that
## needs frames and timers.
##
## Contract: every module exposes `static func run(h, tree = null) -> void`.
## tree is the SceneTree, passed for modules that need frames or timers.
##
## The watchdog exists because a runtime error inside a module kills `_main`
## before it can print a summary or call quit(), leaving headless Godot spinning
## forever with no output. The watchdog is a separate coroutine, so it survives
## that abort and reports which module was running.

const Harness = preload("res://tests/harness.gd")

## Well under the 130 s ceiling of a single headless tool call.
const WATCHDOG_SECONDS := 100.0

const MODULES := [
	["camera", preload("res://tests/test_camera.gd")],
	["ghost", preload("res://tests/test_ghost.gd")],
	["npc", preload("res://tests/test_npc.gd")],
	["map", preload("res://tests/test_map.gd")],
	["case", preload("res://tests/test_case.gd")],
	["take", preload("res://tests/test_take.gd")],
	["mark", preload("res://tests/test_mark.gd")],
	["relay", preload("res://tests/test_relay.gd")],
	["save", preload("res://tests/test_save.gd")],
	["routes", preload("res://tests/test_routes.gd")],
	["scene", preload("res://tests/test_scene.gd")],
	["relay_death", preload("res://tests/test_relay_death.gd")],
	["relay_walk", preload("res://tests/test_relay_walk.gd")],
]

var _finished := false
var _current := "(startup)"


func _init() -> void:
	# The tree does not exist yet inside _init, and the scene test needs it.
	call_deferred("_main")


func _watchdog() -> void:
	await create_timer(WATCHDOG_SECONDS).timeout
	if _finished:
		return
	print("")
	print("RCD TESTS: WATCHDOG — no summary after %.0f s, still inside module '%s'."
		% [WATCHDOG_SECONDS, _current])
	print("RCD TESTS: a module raised a runtime error and killed the runner, or it is looping.")
	quit(3)


func _main() -> void:
	call_deferred("_watchdog")

	var passed := 0
	var failed := 0
	var broken: Array = []
	var started := Time.get_ticks_msec()

	for entry: Array in MODULES:
		var name := str(entry[0])
		var mod: RefCounted = entry[1]
		_current = name
		var h: Harness = Harness.new()
		var mod_started := Time.get_ticks_msec()
		print(">> %s" % name)
		await mod.run(h, self)
		passed += h.passed
		failed += h.failed
		print("<< %s %d/%d  %.2f s" % [name, h.passed, h.passed + h.failed,
			float(Time.get_ticks_msec() - mod_started) / 1000.0])
		if h.failed > 0:
			broken.append("%s (%d)" % [name, h.failed])

	_current = "(summary)"
	var secs := float(Time.get_ticks_msec() - started) / 1000.0
	print("")
	if failed == 0:
		print("RCD TESTS: ALL PASS — %d assertions in %.1f s" % [passed, secs])
	else:
		print("RCD TESTS: FAILED — %s" % ", ".join(broken))
		print("RCD TESTS: %d passed, %d failed, %.1f s" % [passed, failed, secs])
	_finished = true
	quit(0 if failed == 0 else 1)
