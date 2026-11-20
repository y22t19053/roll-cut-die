extends SceneTree
## MARK -> CUT -> resume, on the real main scene, driven by injected key events.
##
##   godot --headless --path . --script res://tests/probe_mark_cut.gd
##
## Walk, press M, walk on, seize one evidence item, press C, pick the MARK in the
## panel, press SPACE. The take must come back on the MARK: place, facing,
## evidence, rolling phase, an outtake for the cut take, Retake stock untouched.
## The one non-input step is a teleport next to an evidence prop, so the probe
## does not depend on a long walk through NPC routes.

const MarkLedger = preload("res://scripts/take/mark_ledger.gd")
const CameraMath = preload("res://scripts/camera/camera_math.gd")

var _fails := 0


func _init() -> void:
	call_deferred("_main")


func _check(name: String, cond: bool, detail := "") -> void:
	print("%s %s%s" % ["PASS" if cond else "FAIL", name, "" if detail == "" else "  [" + detail + "]"])
	if not cond:
		_fails += 1


func _key(code: int, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)
	await process_frame
	await process_frame


func _tap(code: int) -> void:
	await _key(code, true)
	await _key(code, false)


func _hold(code: int, physics_frames: int) -> void:
	await _key(code, true)
	for i in physics_frames:
		await physics_frame
	await _key(code, false)
	for i in 20:
		await physics_frame


func _wait_until(cond: Callable, ms: int) -> int:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < ms:
		await process_frame
	return Time.get_ticks_msec() - t0


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _main() -> void:
	var gs: Node = root.get_node("GameSession")
	var main: Node = (load("res://scenes/main/main.tscn") as PackedScene).instantiate()
	# Runtime load: the standalone SceneTree script compiles before autoloads exist.
	var fixture := load("res://tests/main_without_persistence.gd") as Script
	if fixture == null or not fixture.can_instantiate():
		main.free()
		quit(2)
		return
	main.set_script(fixture)
	root.add_child(main)
	var player: Node3D = main.get_node("Player")
	var hud: Node = main.get_node("Hud")
	var panel: Node = main.get_node("CutPanel")
	var rig: Node = main.get_node("CameraRig")
	var takes = gs.takes
	var cs = gs.case_state

	await _wait_until(func() -> bool: return not bool(player.get("frozen")), 5000)
	_check("released after ROLL", not bool(player.get("frozen")))
	_check("HUD shows MARK 0/3", hud.mark_label.text == "MARK 0/3", hud.mark_label.text)
	await _tap(KEY_ESCAPE)
	var stopped_time: float = main._world_t
	var stopped_rec: float = main.recorder.elapsed()
	var stopped_npc: Vector3 = main.npcs[0].global_position
	await _hold(KEY_W, 18)
	await _tap(KEY_C)
	_check("ESC freezes world, recorder and NPC; C cannot abandon paused take", paused and main._world_t == stopped_time and main.recorder.elapsed() == stopped_rec and main.npcs[0].global_position == stopped_npc and main.phase == 0)
	await _tap(KEY_ESCAPE)
	for i in 4: await physics_frame
	_check("second ESC resumes the same take clock", not paused and main._world_t > stopped_time and takes.take_index == 1)
	var stock0: int = takes.retake_stock
	var take0: int = takes.take_index

	# --- walk two steps, MARK ------------------------------------------------
	var p0 := player.global_position
	await _hold(KEY_W, 30)
	_check("W walked the player", _flat(player.global_position).distance_to(_flat(p0)) > 0.8,
		"%.2f m" % _flat(player.global_position).distance_to(_flat(p0)))
	# Give the anchor something to restore: one item seen, a turned body.
	var seen_id: String = main.evidence_props.keys()[1]
	var seen_prop: Node3D = main.evidence_props[seen_id]
	player.teleport(seen_prop.global_position + Vector3(0.0, 0.05, 0.6), 0.0)  # setup, not input
	await physics_frame
	await _tap(KEY_E)
	_check("E saw %s" % seen_id, cs.is_seen(seen_id) and not cs.is_taken(seen_id))
	await _key(KEY_D, true)
	for i in 12:
		await physics_frame
	_check("body turned before the mark", absf(float(player.facing)) > 0.05, "%.3f rad" % float(player.facing))
	await _tap(KEY_M)
	await _key(KEY_D, false)
	var point: Dictionary = main.marks.marks[0]
	var mark_pos: Vector3 = point.pos
	var mark_facing: float = point.facing
	var marked_w: float = point.cam_motion.w
	_check("M captured the moving orbit", absf(rad_to_deg(marked_w)) > 28.0, "%.2f deg/s" % rad_to_deg(marked_w))
	var mark_yaw: float = main.marks.marks[0]["cam_yaw"] if main.marks.count() > 0 else 0.0
	var mark_ev: Vector2i = MarkLedger.evidence_counts(cs.evidence)
	_check("M stored one anchor", main.marks.count() == 1)
	_check("HUD shows MARK 1/3", hud.mark_label.text == "MARK 1/3", hud.mark_label.text)
	_check("floor beacon placed", main.beacons.size() == 1
		and _flat(main.beacons[0].global_position).distance_to(_flat(mark_pos)) < 0.01)
	if main.marks.count() > 0:
		var m: Dictionary = main.marks.marks[0]
		_check("anchor record is complete", m.has_all(["take", "pos", "facing", "cam_yaw", "cam_roll",
			"evidence", "time", "world_t", "rec_t"]), str(m.keys()))
		_check("anchor time is the game clock", float(m["time"]) > 0.3, "%.2f s" % float(m["time"]))

	_check("anchor holds the seen item", mark_ev == Vector2i(1, 0), str(mark_ev))

	# --- walk on, seize evidence --------------------------------------------
	await _hold(KEY_S, 30)
	_check("player left the mark", _flat(player.global_position).distance_to(_flat(mark_pos)) > 0.8)
	var ev_id: String = main.evidence_props.keys()[0]
	var prop: Node3D = main.evidence_props[ev_id]
	player.teleport(prop.global_position + Vector3(0.0, 0.05, 0.6), 0.0)  # setup, not input
	await physics_frame
	await _tap(KEY_E)
	await _tap(KEY_E)
	_check("E,E seized %s" % ev_id, cs.is_taken(ev_id) and not prop.visible)
	_check("still rolling before C", int(main.phase) == 0, "phase %d" % int(main.phase))

	# --- C: CUT panel ---------------------------------------------------------
	rig.mouse_look(120.0) # A pending correction would normally decay over the CUT animation.
	var cut_from := player.global_position
	await _tap(KEY_C)
	_check("C enters Phase.CUT", int(main.phase) == 2, "phase %d" % int(main.phase))
	var cut_motion: Dictionary = rig.mark_motion()
	var frozen_camera: Transform3D = rig.camera.global_transform
	var ms: int = await _wait_until(func() -> bool: return panel.is_open(), 4000)
	_check("panel opens after the CUT slate", panel.is_open(), "%d ms" % ms)
	var lines: PackedStringArray = panel.lines()
	print("--- panel ---\n" + "\n".join(lines))
	_check("panel lists START and MARK 1", lines.size() == 4 and lines[1].contains("START")
		and lines[2].contains("MARK 1"))
	_check("MARK row carries its real position", lines[2].contains("X %.2f  Z %.2f" % [mark_pos.x, mark_pos.z]),
		lines[2])
	_check("title shows the real Retake stock", lines[0].contains("RETAKES %d" % stock0), lines[0])

	# frozen world
	var npc: Node3D = main.npcs[0]
	var npc_at := npc.global_position
	await _hold(KEY_W, 20)
	_check("no movement in CUT", player.global_position.distance_to(cut_from) < 0.001)
	_check("CUT holds live camera pose and pending correction", absf(cut_motion.offset) > 0.1 and rig.mark_motion() == cut_motion and frozen_camera.is_equal_approx(rig.camera.global_transform))
	_check("NPC frozen in CUT", npc.global_position.distance_to(npc_at) < 0.001 and not npc.is_active())
	await _tap(KEY_E)
	_check("no interaction in CUT", int(main.phase) == 2)

	# --- select, preview, ESC, reselect -------------------------------------
	await _tap(KEY_DOWN)
	await _tap(KEY_DOWN)
	_check("DOWN DOWN selects MARK 1", main.cut_cursor == 1 and panel.selected == 1)
	var pv: Camera3D = main.preview_cam
	var want_focus := mark_pos + Vector3.UP * CameraMath.FOCUS_HEIGHT
	_check("preview camera is live", pv.current and not rig.camera.current)
	_check("preview sits on the mark", main.preview_rig.global_position.distance_to(want_focus) < 0.001)
	_check("preview faces the recorded yaw", absf(angle_difference(main.preview_rig.rotation.y, mark_yaw)) < 0.001)
	var still: Node3D = main.player_still
	_check("preview player is at MARK and faces its recorded heading", still.global_position.distance_to(mark_pos) < 0.01 and absf(angle_difference(still.rotation.y, mark_facing)) < 0.01)
	_check("preview draws only the player still and no duplicate collision body", (pv.cull_mask & still.get_node("Body").layers) != 0 and (pv.cull_mask & player.get_node("Visual/Body").layers) == 0 and still.find_children("*", "CollisionObject3D", true, false).is_empty())
	_check("preview did not move the player", player.global_position.distance_to(cut_from) < 0.001)
	_check("later pickup is visible only as a historical marker", main.evidence_stills.has(ev_id) and main.evidence_stills[ev_id].is_visible_in_tree() and main.evidence_stills[ev_id].get_node("Ring").visible and not prop.visible and cs.is_taken(ev_id))
	_check("previously inspected marker has no uninspected ring", main.evidence_stills.has(seen_id) and not main.evidence_stills[seen_id].get_node("Ring").visible)
	_check("footer reads the preview", panel.footer_label.text.begins_with("PREVIEW MARK 1"), panel.footer_label.text)
	await _tap(KEY_ESCAPE)
	_check("ESC clears the selection", main.cut_cursor == -1 and rig.camera.current and panel.is_open())
	await _tap(KEY_2)
	_check("2 selects MARK 1", main.cut_cursor == 1)

	# --- SPACE: cut to MARK 1 ------------------------------------------------
	await _tap(KEY_SPACE)
	_check("panel closed", not panel.is_open())
	_check("camera back on the rig", rig.camera.current)
	_check("player on the mark", player.global_position.distance_to(mark_pos) < 0.01,
		"%.3f m" % player.global_position.distance_to(mark_pos))
	_check("facing restored", absf(angle_difference(float(player.facing), mark_facing)) < 0.001)
	_check("camera yaw restored", absf(angle_difference(float(rig.yaw), mark_yaw)) < 0.001)
	for i in 15:
		await physics_frame
	_check("retake slate preserves marked angular speed without advancing yaw", player.frozen and not rig.is_physics_processing() and is_equal_approx(rig.active().w, marked_w) and absf(angle_difference(rig.yaw, mark_yaw)) < 0.001)
	var ev_now := MarkLedger.evidence_counts(cs.evidence)
	_check("evidence count restored", ev_now == mark_ev, "%s vs %s" % [ev_now, mark_ev])
	_check("seized item rolled back", not cs.is_taken(ev_id) and not cs.is_seen(ev_id) and prop.visible)
	_check("item seen before the mark is still seen", cs.is_seen(seen_id))
	_check("Phase.ROLLING", int(main.phase) == 0, "phase %d" % int(main.phase))
	_check("next take", takes.take_index == take0 + 1)
	var last: Dictionary = takes.outtakes[-1] if not takes.outtakes.is_empty() else {}
	_check("outtake recorded for the cut take", str(last.get("kind", "")) == "cut"
		and int(last.get("take", 0)) == take0 and str(last.get("resume", "")) == "MARK 1", str(last))
	_check("Retake stock not spent", takes.retake_stock == stock0, "%d vs %d" % [takes.retake_stock, stock0])
	_check("MARK 1 kept", main.marks.count() == 1 and hud.mark_label.text == "MARK 1/3")

	await _wait_until(func() -> bool: return not bool(player.get("frozen")), 5000)
	_check("control returns after ROLL", not bool(player.get("frozen")) and npc.is_active())
	_check("recorder resumed on the mark's clock",
		main.recorder.recording and main.recorder.elapsed() >= float(main.marks.marks[0]["rec_t"]))
	_check("moving MARK records rightward velocity", point.velocity.x > 3.0)
	# Input is now released: the stored velocity must brake under normal physics.
	for i in 12:
		await physics_frame
	var slide: Vector3 = player.global_position - mark_pos
	_check("released body coasts from the MARK then stops", slide.x > 0.12 and slide.x < 0.24 and absf(slide.z) < 0.01 and player.velocity.length() < 0.01, str(slide))

	for i in 5:
		await physics_frame
	_check("on release camera coasts in the recorded direction", rig.is_physics_processing() and signf(angle_difference(mark_yaw, rig.yaw)) == signf(marked_w) and absf(rig.active().w) < absf(marked_w))
	_check("production save requests intercepted", main.intercepted_writes > 0, str(main.intercepted_writes))
	main.queue_free()
	await process_frame
	print("")
	print("MARK/CUT PROBE: %s" % ("OK" if _fails == 0 else "%d FAILED" % _fails))
	quit(0 if _fails == 0 else 1)
