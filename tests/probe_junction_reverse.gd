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
	if not check(lab.ghost_nodes.size() == 1 and lab.ghost_nodes[0].track.sample_at(0.0).position.distance_to(lab.SOUTH) < 0.15,"successful track still starts in south"): return
	await tap(KEY_R)
	if not check(lab.phase == lab.Phase.ROLLING,"former desk no longer files"): return
	# The direct return meets TAKE 01 in the crossing. Go around the west flat instead.
	for p in [Vector2(1.5,2), Vector2(1.5,13), Vector2(6,13)]:
		if not await walk(p): return
	await tap(KEY_R)
	await tap(KEY_3)
	if not check(lab.phase == lab.Phase.COMPLETE,"south report accepted"): return
	await tap(KEY_SPACE)
	if not check(await released() and xz().distance_to(Vector2(6,13)) < 0.1 and lab.ghost_nodes.size() == 2,"third roll restores south start with both histories"): return
	quit(0)
