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
## forever with no output. The watchdog uses a separate timer, so it survives
## that abort and reports which module was running.

const Harness = preload("res://tests/harness.gd")
const RelaySave = preload("res://scripts/relay/relay_save.gd")

## Well under the 130 s ceiling of a single headless tool call.
const WATCHDOG_SECONDS := 100.0

const MODULES := [
	["out_of_frame", preload("res://tests/test_out_of_frame.gd")],
	["camera", preload("res://tests/test_camera.gd")],
	["ghost", preload("res://tests/test_ghost.gd")],
	["npc", preload("res://tests/test_npc.gd")],
	["map", preload("res://tests/test_map.gd")],
	["case", preload("res://tests/test_case.gd")],
	["take", preload("res://tests/test_take.gd")],
	["final_cut", preload("res://tests/test_final_cut.gd")],
	["mark", preload("res://tests/test_mark.gd")],
	["craft", preload("res://tests/test_craft.gd")],
	["relay", preload("res://tests/test_relay.gd")],
	["room_families", preload("res://tests/test_room_families.gd")],
	["no_softlock", preload("res://tests/test_no_softlock.gd")],
	["set_props", preload("res://tests/test_set_props.gd")],
	["save", preload("res://tests/test_save.gd")],
	["routes", preload("res://tests/test_routes.gd")],
	["scene", preload("res://tests/test_scene.gd")],
	["relay_death", preload("res://tests/test_relay_death.gd")],
	["relay_walk", preload("res://tests/test_relay_walk.gd")],
	["relay_link", preload("res://tests/test_relay_link.gd")],
	["inrun_ui_deai", preload("res://tests/test_inrun_ui_and_deai.gd")],
	["touch_pad", preload("res://tests/test_touch_pad.gd")],
	["toy_score", preload("res://tests/test_toy_score.gd")],
	["score_layers", preload("res://tests/test_score_layers.gd")],
	["gantry", preload("res://tests/test_gantry.gd")],
	["gantry_room", preload("res://tests/test_gantry_room.gd")],
]

var _current := "(startup)"
var _retiring_meshes: Array[Mesh] = []


func _init() -> void:
	if DisplayServer.get_name() == "headless":
		node_removed.connect(_hold_mesh_through_teardown)
	# The tree does not exist yet inside _init, and the scene test needs it.
	call_deferred("_main")


func _hold_mesh_through_teardown(node: Node) -> void:
	# Godot 4.3 Dummy queries the mesh RID while destroying the instance, and it does
	# that after the GDScript reference is gone. One frame of retention is not enough
	# in a headless run — the deferred clear itself is what was dropping the resource
	# mid-teardown — so every mesh removed during the suite is simply kept until the
	# process exits. This lives in the test runner only and never ships.
	if node is MeshInstance3D and node.mesh != null:
		_retiring_meshes.append(node.mesh)


func _watchdog() -> void:
	print("")
	print("RCD TESTS: WATCHDOG — no summary after %.0f s, still inside module '%s'."
		% [WATCHDOG_SECONDS, _current])
	print("RCD TESTS: a module raised a runtime error and killed the runner, or it is looping.")
	quit(3)


func _main() -> void:
	var watchdog := create_timer(WATCHDOG_SECONDS)
	watchdog.timeout.connect(_watchdog)
	var prior_relay_save := RelaySave.save_path
	RelaySave.save_path = "user://rcd_test_saves/relay_run_%s.json" % Crypto.new().generate_random_bytes(8).hex_encode()

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
	RelaySave.clear()
	RelaySave.save_path = prior_relay_save
	await process_frame
	watchdog.timeout.disconnect(_watchdog)
	quit(0 if failed == 0 else 1)
