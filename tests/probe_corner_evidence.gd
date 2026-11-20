extends SceneTree
## Physical-key integration proof, not a player study. No state injection or saves.

const Scenes := ["res://tools/corner_evidence_a.tscn", "res://tools/corner_evidence_b.tscn"]
var failed := 0

func _initialize() -> void:
	call_deferred("run")

func key(code: int, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)

func ticks(n: int) -> void:
	for i in n:
		await physics_frame

func move(code: int, n: int) -> void:
	key(code, true)
	await ticks(n)
	key(code, false)
	await ticks(14)

func check(ok: bool, message: String) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		failed += 1

func run() -> void:
	create_timer(50.0).timeout.connect(func(): quit(3))
	var results: Array[Vector3] = []
	var baseline: Dictionary = {}
	var save_path := "user://rcd/save.json"
	var before := FileAccess.get_sha256(save_path) if FileAccess.file_exists(save_path) else ""
	for path in Scenes:
		var main = load(path).instantiate()
		root.add_child(main)
		var map: Dictionary = main.map_data.duplicate(true)
		var other_props := []
		var paint := []
		for prop in map.props:
			if str(prop.id).begins_with("trial_paint_"):
				paint.append(prop)
			else:
				other_props.append(prop)
		map.props = other_props
		if path == Scenes[0]:
			baseline = map
			check(paint.is_empty(), "A contains no trial paint")
		else:
			check(paint.size() == 3 and paint.all(func(p): return p.get("solid") == false), "B contains three non-colliding paint strips")
			check(map == baseline, "entire map matches A once paint is removed, including NPCs, evidence and report")
		for i in 360:
			if not main.player.frozen:
				break
			await physics_frame
		check(not main.player.frozen, path + " releases player")
		await move(KEY_D, 16)
		key(KEY_W, true)
		await ticks(225)
		var at_wall: Vector3 = main.player.global_position
		var yaw: float = main.rig.yaw
		await ticks(60)
		var stopped: Vector3 = main.player.global_position
		var sweep := absf(rad_to_deg(angle_difference(yaw, main.rig.yaw)))
		key(KEY_W, false)
		await ticks(14)
		check(absf(stopped.z - 6.67) < 0.08 and at_wall.distance_to(stopped) < 0.02 and sweep > 28.0,
			"west wall holds at %s while yaw sweeps %.1f deg" % [str(stopped), sweep])
		await move(KEY_D, 27)
		await move(KEY_W, 40)
		var stance: Vector3 = main.player.global_position
		await move(KEY_E, 3)
		await move(KEY_E, 3)
		var gs := root.get_node("GameSession")
		check(gs.case_state.is_taken("script_page"), "normal E,E collects SCRIPT PAGE from %s" % str(stance))
		await move(KEY_F4, 1)
		check(gs.case_state.is_taken("script_page"), "trial ignores production load binding")
		results.append(stance)
		main.queue_free()
		await process_frame
		await physics_frame
	check(results[0].distance_to(results[1]) < 0.02, "paint does not change the stance under identical input")
	var after := FileAccess.get_sha256(save_path) if FileAccess.file_exists(save_path) else ""
	check(after == before, "production save remains unchanged")
	quit(1 if failed else 0)
