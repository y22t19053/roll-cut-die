extends SceneTree
## Checks the death read-out, the ghost's visibility rules, and live ROLL mode
## switching on the real main scene.
##
##   godot --headless --path . --script res://tests/probe_death_hud.gd

const GhostTrack = preload("res://scripts/ghost/ghost_track.gd")
const GhostActorScript = preload("res://scripts/ghost/ghost_actor.gd")
const RollModes = preload("res://scripts/camera/roll_modes.gd")

var _fails := 0


func _init() -> void:
	call_deferred("_main")


func _check(name: String, cond: bool, detail := "") -> void:
	print("%s %s%s" % ["PASS" if cond else "FAIL", name, "" if detail == "" else "  [" + detail + "]"])
	if not cond:
		_fails += 1


func _main() -> void:
	var gs: Node = root.get_node("GameSession")
	var tr = GhostTrack.new()
	tr.take_id = 1
	for i in 30:
		tr.add_sample(float(i) * 0.1, Vector3(30.0 + float(i) * 0.1, 0.0, 30.0), 0.0, 0.0, 0.0)
	gs.add_ghost(tr)

	var inst: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	root.add_child(inst)
	var hud: Node = inst.get_node("Hud")
	var rig: Node = inst.get_node("CameraRig")
	var player: Node = inst.get_node("Player")

	# --- ROLL mode switch reaches camera, body and HUD --------------------
	_check("starts in CHASE", hud.roll_label.text == "ROLL: CHASE", hud.roll_label.text)
	for m in [RollModes.SNAP, RollModes.ORBIT, RollModes.CHASE]:
		inst.call("_set_roll_mode", m)
		var want := "ROLL: " + RollModes.mode_name(m)
		_check("switch -> %s: HUD" % want, hud.roll_label.text == want, hud.roll_label.text)
		_check("switch -> %s: rig" % want, rig.roll_mode == m)
		_check("switch -> %s: player" % want, player.roll_mode == m)
		_check("switch -> %s: session" % want, gs.get_roll_mode() == m)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F1
	key.pressed = true
	inst._unhandled_input(key)
	_check("F1 cycles CHASE -> SNAP", hud.roll_label.text == "ROLL: SNAP", hud.roll_label.text)
	key.physical_keycode = KEY_F7
	inst._unhandled_input(key)
	_check("F7 picks ORBIT", rig.roll_mode == RollModes.ORBIT)
	key.physical_keycode = KEY_F5
	inst._unhandled_input(key)
	_check("F5 picks CHASE", rig.roll_mode == RollModes.CHASE)

	# --- death read-out ----------------------------------------------------
	var frames := 0
	while frames < 400 and bool(player.get("frozen")):
		await process_frame
		frames += 1
	_check("ghost spawned in scene", (inst.get("ghost_nodes") as Array).size() == 1)
	_check("death label hidden while rolling", not hud.death_label.visible)
	inst.call("_on_ghost_caught", 1)
	var top: String = hud.take_label.text
	print("top bar on death: '%s'" % top)
	_check("top bar says DIED and names the take",
		top == "TAKE 01   ·   1 GHOST   ·   DIED — TAKE 01", top)
	_check("top bar no longer says ROLLING", not top.contains("ROLLING"))
	_check("centre says DIED TO TAKE 01",
		hud.death_label.visible and hud.death_label.text == "DIED TO TAKE 01", hud.death_label.text)
	# Headless frames are not 60 Hz: wait on the wall clock for the 2.05 s slate.
	var slate: Node = inst.get_node("Slate")
	var ts := Time.get_ticks_msec()
	while slate.is_running() and Time.get_ticks_msec() - ts < 5000:
		await process_frame
	await process_frame
	_check("slate DIE sequence finished", not slate.is_running(), "%d ms" % (Time.get_ticks_msec() - ts))
	_check("centre text survives the slate", hud.death_label.visible)
	_check("retake hint is up", hud.hint_label.text == "SPACE — RETAKE", hud.hint_label.text)
	key.physical_keycode = KEY_SPACE
	inst._unhandled_input(key)
	_check("SPACE clears the death text", not hud.death_label.visible)
	_check("top bar back to ROLLING on take 02", hud.take_label.text.begins_with("TAKE 02") and hud.take_label.text.ends_with("ROLLING"), hud.take_label.text)
	inst.queue_free()
	await process_frame

	# --- ghost visuals -----------------------------------------------------
	var g = GhostActorScript.new()
	root.add_child(g)
	g.setup(tr, 1)
	var ring: Node = g.get_node_or_null("DangerRing")
	_check("ghost has a floor ring", ring != null)
	if ring != null:
		_check("ring outer radius is DANGER_RADIUS",
			is_equal_approx(ring.mesh.outer_radius, GhostActorScript.DANGER_RADIUS))
	var lbl: Label3D = g.get_node("Tag")
	_check("tag reads TAKE 01", lbl.text == "TAKE 01")
	_check("tag visible during warmup", lbl.visible and lbl.modulate.a >= 0.9)
	g.playhead = GhostActorScript.WARMUP - 0.001
	await physics_frame
	await physics_frame
	_check("armed alpha >= 0.5", g._armed and g._alpha >= 0.5, "alpha %.2f" % g._alpha)
	g.playhead = tr.duration()
	await physics_frame
	await physics_frame
	_check("finished -> spent", g.spent)
	var t0 := Time.get_ticks_msec()
	while g.visible and Time.get_ticks_msec() - t0 < 3000:
		await process_frame
	var ms := Time.get_ticks_msec() - t0
	print("ghost hidden %d ms after finishing" % ms)
	_check("ghost hidden within ~1.2 s", not g.visible and ms <= 1400, "%d ms" % ms)
	_check("ghost alpha reached 0", g._alpha <= 0.001, "%.3f" % g._alpha)
	g.queue_free()
	await process_frame

	print("")
	print("DEATH/HUD PROBE: %s" % ("OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)
