extends SceneTree
## Physical-key integration probe. No action overrides, teleports, direct rule calls or disk saves.
var lab
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, detail: String) -> bool:
	print("%s junction: %s" % ["PASS" if ok else "FAIL", detail])
	if not ok:
		failed = true
		quit(1)
	return ok

func ticks(n: int) -> void:
	for i in n:
		await physics_frame

func key(code: int, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func tap(code: int) -> void:
	key(code,true)
	await ticks(2)
	key(code,false)
	await ticks(1)

func released() -> bool:
	for i in 300:
		if not lab.player.frozen:
			return true
		await physics_frame
	return false

func xz() -> Vector2:
	return Vector2(lab.player.position.x,lab.player.position.z)

func walk(target: Vector2) -> bool:
	for axis in 2:
		var delta: float = target[axis] - xz()[axis]
		if absf(delta) < 0.23:
			continue
		var code := (KEY_D if delta > 0 else KEY_A) if axis == 0 else (KEY_S if delta > 0 else KEY_W)
		key(code,true)
		for i in 360:
			if (target[axis] - xz()[axis]) * signf(delta) <= 0.16:
				break
			await physics_frame
		key(code,false)
		await ticks(9)
	return check(xz().distance_to(target) < 0.3, "walk %s reached %s" % [target,xz()])

func crossing(track) -> Dictionary:
	var actor = lab.ghost_nodes[0]
	var last: Vector3 = actor.position
	for i in 480:
		await physics_frame
		var p: Vector3 = actor.position
		if last.x < lab.CROSSING.x and p.x >= lab.CROSSING.x and absf(p.z-lab.CROSSING.y) < 0.3:
			if not check(actor.playing and not actor.spent and actor.get_node("Danger").monitoring and actor.take_id == 1 and actor.track == track,
				"live eastbound TAKE 01 at %s, playhead %.3f" % [p,actor.playhead]): return {}
			return {"world":lab._world_t, "head":actor.playhead}
		last = p
	check(false,"eastbound projection did not cross within 480 ticks")
	return {}

func run() -> void:
	create_timer(45.0).timeout.connect(func(): print("FAIL junction: watchdog"); quit(2))
	lab = load("res://tools/junction_lab.tscn").instantiate()
	root.add_child(lab)
	if not check(await released(),"Take 01 releases"): return
	for p in lab.route_points("A"):
		if not await walk(p): return
	await tap(KEY_R)
	await tap(KEY_3)
	var gs := root.get_node("GameSession")
	if not check(lab.phase == lab.Phase.COMPLETE and gs.ghost_count() == 1,"R/3 accepted; one successful track"): return
	var track = gs.ghosts[0].track
	await tap(KEY_SPACE)
	if not check(await released() and lab.ghost_nodes.size() == 1,"Take 02 releases with one replay actor"): return
	if not await walk(lab.OBSERVE): return
	await tap(KEY_M)
	if not check(lab.marks.count() == 1,"one personal MARK on B"): return
	var mark: Dictionary = lab.marks.marks[0]
	var first := await crossing(track)
	if failed: return
	await tap(KEY_C)
	for i in 240:
		if lab.cut_panel.is_open(): break
		await physics_frame
	if not check(lab.cut_panel.is_open(),"manual CUT opened the timeline"): return
	await tap(KEY_2) # checkpoint is row 1, personal MARK is row 2.
	await tap(KEY_SPACE)
	if not check(await released() and xz().distance_to(lab.OBSERVE) < 0.3 and gs.takes.take_index == 3,"Take 03 resumed at observation MARK"): return
	if not check(gs.ghost_count() == 1 and lab.ghost_nodes.size() == 1,"CUT added no track or actor"): return
	var second := await crossing(track)
	if failed: return
	var world_error := absf(float(first.world)-float(second.world))
	var head_error := absf(float(first.head)-float(second.head))
	var tick := 1.0/Engine.physics_ticks_per_second
	if not check(maxf(world_error,head_error) <= tick + 0.0001 and gs.ghost_count() == 1 and lab.phase == lab.Phase.ROLLING,
		"mark %.3f; crossings world %.3f / %.3f; clock error %.3fs; head error %.3fs (budget %.3fs); tracks 1" % [mark.world_t,first.world,second.world,world_error,head_error,tick]): return
	quit(0)
