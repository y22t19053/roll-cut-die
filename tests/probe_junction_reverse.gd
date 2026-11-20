extends "res://tests/probe_junction_retry.gd"

func run() -> void:
	create_timer(45.0).timeout.connect(func(): quit(2))
	lab = load("res://tools/junction_reverse.tscn").instantiate()
	root.add_child(lab)
	if not check(await released(),"initial roll"): return
	for p in lab.route_points("A"):
		if not await walk(p): return
	await tap(KEY_R)
	await tap(KEY_3)
	if not check(lab.phase == lab.Phase.COMPLETE,"north report accepted"): return
	await tap(KEY_SPACE)
	if not check(await released() and xz().distance_to(Vector2(6,2)) < 0.1,"second roll begins at former report"): return
	if not check(lab.report_sign.is_visible_in_tree() and lab.report_sign.global_position.distance_to(Vector3(6,0.42,13)) < 0.01,"visible desk marker follows new report zone south"): return
	if not check(lab.ghost_nodes.size() == 1 and lab.ghost_nodes[0].track.sample_at(0.0).position.distance_to(lab.SOUTH) < 0.15,"successful track still starts in south"): return
	await tap(KEY_R)
	if not check(lab.phase == lab.Phase.ROLLING,"former desk no longer files"): return
	# Compare both choices against the same recorded take, including normal death recovery.
	var gs := root.get_node("GameSession")
	var stock: int = gs.takes.retake_stock
	var track = gs.ghosts[0].track
	key(KEY_S,true)
	for i in 180:
		if lab.phase == lab.Phase.DEAD: break
		await physics_frame
	key(KEY_S,false)
	if not check(lab.phase == lab.Phase.DEAD and gs.takes.death_source == "take_01", "direct return collides with the recorded performer"): return
	if not check(gs.takes.retake_stock == stock - 1 and gs.ghost_count() == 1, "death spends one retake and does not create a success"): return
	await ticks(120)
	await tap(KEY_SPACE)
	if not check(await released() and xz().distance_to(Vector2(6,2)) < 0.1 and lab.report_pos == lab.SOUTH, "death retry preserves north-to-south assignment"): return
	if not check(lab.ghost_nodes.size() == 1 and lab.ghost_nodes[0].track == track, "retry reuses the same successful recording"): return
	# Take the west detour on this retry.
	for p in [Vector2(1.5,2), Vector2(1.5,13), Vector2(6,13)]:
		if not await walk(p): return
	await tap(KEY_R)
	await tap(KEY_3)
	if not check(lab.phase == lab.Phase.COMPLETE,"south report accepted"): return
	await tap(KEY_SPACE)
	if not check(await released() and xz().distance_to(Vector2(6,13)) < 0.1 and lab.ghost_nodes.size() == 2,"after two successful reports the south start returns with both histories"): return
	quit(0)
