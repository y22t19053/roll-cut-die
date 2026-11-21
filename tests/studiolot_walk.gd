extends SceneTree
## Input-only production 001 walkthrough. Observe the lot; never drive an actor or recorder.
const WORLD := "res://scenes/studiolot/world.tscn"
var lot
var held := {}
var failed := false

func _initialize() -> void:
	call_deferred("run")

func key(code: int, down: bool) -> void:
	if held.has(code) == down: return
	if down: held[code] = true
	else: held.erase(code)
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func tap(code: int) -> void:
	key(code,true)
	await physics_frame
	key(code,false)
	await physics_frame

func check(ok: bool, reason: String) -> bool:
	if not ok and not failed:
		failed = true
		push_error("LOT WALK: %s, position=%s" % [reason,lot.player.position])
		for code in held.keys(): key(code,false)
		quit(1)
	return ok

func walk(p: Vector2) -> void:
	for frame in 1100:
		var at: Vector3 = lot.player.position
		var d := p - Vector2(at.x,at.z)
		if d.length() < 0.13: break
		if not check(not lot.player.frozen and frame < 1099,"blocked on approach to %s" % p): return
		key(KEY_A,d.x < -0.085); key(KEY_D,d.x > 0.085)
		key(KEY_W,d.y < -0.085); key(KEY_S,d.y > 0.085)
		await physics_frame
	for code in held.keys(): key(code,false)
	for i in 10: await physics_frame

func path(points: Array) -> void:
	for p in points:
		await walk(p)
		if failed: return

func live() -> void:
	for i in 360:
		await physics_frame
		if not lot.player.frozen: return
	check(false,"ROLL did not release")

func run() -> void:
	if change_scene_to_file(WORLD) != OK: quit(1); return
	while current_scene == null: await process_frame
	lot = current_scene
	await live()
	await path([Vector2(7.25,25),Vector2(7.25,17),Vector2(42.75,17),Vector2(42.75,6.7),Vector2(19.9,6.7),Vector2(19.9,4.3)])
	await tap(KEY_E)
	if not check(lot.hand_image == "tank", "failed to take tank master"): return
	await path([Vector2(18.25,4.4),Vector2(18.25,7.5)])
	var shutter = lot.get_node("Layout/gate_a/Body")
	if not check(shutter.collision_layer != 0 and lot.player.position.x > 17.75,"not at far side of closed A"): return
	await tap(KEY_E)
	if not check(lot.gates.has("a") and shutter.collision_layer == 0,"far latch did not open A"): return
	await path([Vector2(18.35,9.5),Vector2(15.8,9.5),Vector2(15.8,11.8),Vector2(8,11.8),Vector2(8,16.8),Vector2(7.25,16.8),Vector2(7.25,31),Vector2(4,32.5)])
	await tap(KEY_E)
	var session = root.get_node("GameSession")
	if not check(lot.images.keys() == ["tank"] and session.ghost_count() == 1,"shortcut delivery did not bank picture + take"): return
	await tap(KEY_SPACE)
	await live()
	await path([Vector2(7,31.5),Vector2(4,32.5)])
	await tap(KEY_E)
	if not check(lot.has_print,"no answer print at bench"): return
	await path([Vector2(7.25,31),Vector2(7.25,17),Vector2(8,17),Vector2(8,11.6),Vector2(12.5,11.6),Vector2(12.5,7.5)])
	await tap(KEY_E)
	if not check(lot.screened and lot._screen_cam.current and lot._reels.size()==2,"projector did not screen two recorded takes"): return
	if not check("001" in lot.ending_lines()[0],"production number missing"): return
	for i in 2:
		if not check(lot._reels[i].track == session.ghosts[i].track and lot._reels[i].take == i+1,"screen substituted a track"): return
	var seen := {}
	for i in 1000:
		await process_frame
		for reel in lot._reels:
			if not lot._reel_caption.text.begins_with("TAKE %02d" % reel.take): continue
			var expect := "TANK PICTURE" if reel.take == 1 else "PRINT DELIVERY"
			if not check(lot._delivery_credit(reel.take) == expect and expect in lot._reel_caption.text,"credit mismatch: " + lot._reel_caption.text): return
			var t: float = lot._screen_t - reel.start
			var pos: Vector3 = reel.track.sample_at(t).position
			var dot = reel.nodes[0]
			if t > 1.0 and dot.visible and dot.position.distance_to(lot._on_screen(pos.x,pos.z,0.03)) < 0.001: seen[reel.take] = true
		if seen.size()==2: break
	if not check(seen.size()==2,"screen did not display both moving tracks"): return
	await tap(KEY_SPACE)
	if not check(current_scene == lot and lot.screened and lot._screen_cam.current and lot._screen_t < 1.0,"SPACE did not replay in place"): return
	print("STUDIOLOT_PHYSICAL_KEYS_OK: production 001; tank -> far latch A -> shortcut -> bench -> answer print -> 35 mm; screen takes ",seen.keys(),"; SPACE replayed")
	quit(0)
