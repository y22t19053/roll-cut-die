extends RefCounted


const Rooms = preload("res://scripts/relay/relay_rooms.gd")
const Save = preload("res://scripts/relay/relay_save.gd")


static func run(h, tree = null) -> void:
	h.begin("relay_link")
	var SCENE = load("res://scenes/relay/run.tscn")
	var Run = load("res://scripts/relay/relay_run.gd")
	var rooms := Rooms.new()
	tree.root.add_child(rooms)
	h.eq("empty rooms have no index", rooms.room_at(Vector3.ZERO), -1)
	for i in 4:
		rooms.append_room("straight", 0, "clean")
		h.eq("bay count grows", rooms.bays(), i + 1)
	for i in 4:
		for offset: float in [0.0, 0.01, 4.5, 8.99]:
			h.eq("floor index %d %.2f" % [i, offset], rooms.room_at(Vector3(i * 9 + offset, 0, 0)), i)
	h.eq("requested midpoint boundary", rooms.room_at(Vector3(31.5, 0, 0)), 3)
	h.eq("negative clamp", rooms.room_at(Vector3(-999, 0, 0)), 0)
	h.eq("far clamp", rooms.room_at(Vector3(9999, 0, 0)), 3)
	rooms.queue_free()
	await tree.process_frame
	rooms = Rooms.new()
	tree.root.add_child(rooms)
	for i in 3: rooms.append_room("straight", 0, "clean")
	await tree.physics_frame
	await tree.physics_frame
	# 24 x 19 samples per bay, joined at their shared seams.
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = cap
	query.collision_mask = 1
	var space := rooms.get_world_3d().direct_space_state
	var free := {}
	for ix in 70:
		for iz in 19:
			query.transform = Transform3D(Basis(), Vector3(ix * 9.0 / 23.0, 0.85, iz * 5.7 / 18.0 - 2.85))
			if space.intersect_shape(query, 1).is_empty(): free[Vector2i(ix, iz)] = true
	var queue: Array[Vector2i] = [Vector2i(2, 9)]
	var seen := {Vector2i(2, 9): true}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for delta: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + delta
			if free.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	for ix in [22, 23, 24, 45, 46, 47, 67, 68, 69]:
		h.ok("connected corridor column %d" % ix, seen.has(Vector2i(ix, 9)))
	rooms.queue_free()
	await tree.process_frame

	var inst = SCENE.instantiate()
	tree.root.add_child(inst)
	await tree.process_frame
	inst.set_physics_process(false)
	inst.player.set_physics_process(false)
	# Two completed legs, each completing one tutorial bay, leave three ranges.
	for i in 2:
		inst.required_passes = 1
		inst.elapsed = 2.0
		inst.player.teleport(inst.route[-1], 0.0)
		inst._finish_leg()
	h.eq("two legs leave three bays", inst.segments.size(), 3)
	h.eq("one interval per bay", inst._track_ranges.size(), 3)
	for i in 2:
		h.eq("one recording in finished bay", inst._track_ranges[i].y - inst._track_ranges[i].x, 1)
		h.eq("intervals meet without overlap", inst._track_ranges[i].y, inst._track_ranges[i+1].x)
	h.eq("old bay actors survive restart", inst._actors.size(), 2)
	var ghost = inst._actors[0]
	ghost.playing = true
	var before: float = ghost.playhead
	await tree.create_timer(0.15).timeout
	h.ok("old recording keeps playing", ghost.playhead != before)
	inst._start_leg(true)
	inst.cursor = inst.route.size() - 1 # Old bay near the return seam used to finish.
	var passes: int = inst.room_pass
	var leg: int = inst.leg_room
	var count: int = inst.tracks.size()
	for x: float in [1.0, 4.5, 8.8, 9.1, 13.5, 17.8]:
		inst.player.teleport(Vector3(x, 0.05, 0), 0.7)
		inst.grace = 0.0
		inst._physics_process(0.1)
		h.eq("backtracking keeps leg %.1f" % x, inst.leg_room, leg)
		h.eq("backtracking cannot finish %.1f" % x, inst.tracks.size(), count)
		h.eq("backtracking keeps passes %.1f" % x, inst.room_pass, passes)
		h.ok("old set cannot kill %.1f" % x, not inst._dying)
	inst.player.teleport(Vector3(3, 0.05, 0.4), 0.7)
	var state: Dictionary = inst._serialize_run()
	h.ok("v2 save", Save.save_run(state))
	var loaded := Save.load_run()
	h.eq("v2 version", int(loaded.version), 2)
	h.eq("at room", int(loaded.at.room), 0)
	h.eq("at x", float(loaded.at.x), 3.0)
	h.ok("at z", is_equal_approx(float(loaded.at.z), 0.4))
	h.eq("at facing", float(loaded.at.facing), 0.7)
	inst.player.teleport(Vector3(18.1, 0.05, 0.4), 0.0)
	inst.grace = 10.0
	inst._physics_process(0.1)
	h.eq("reentering frontier restores crossing", inst.room_pass, passes + 1)
	inst.queue_free()
	await tree.process_frame
	Run.pending_resume = loaded
	inst = SCENE.instantiate()
	tree.root.add_child(inst)
	inst.set_physics_process(false)
	inst.player.set_physics_process(false)
	h.ok("v2 restores physical position", inst.player.global_position.distance_to(Vector3(3, 0.05, 0.4)) < 0.001)
	h.eq("v2 restores facing", inst.player.facing, 0.7)
	h.eq("resume keeps frontier objective", inst.leg_room, 2)
	h.eq("v2 restores ranges", inst._track_ranges.size(), 3)
	h.eq("v2 restores old actors", inst._actors.size(), 2)
	inst.queue_free()
	await tree.process_frame
	var reverse = load("res://scripts/ghost/ghost_track.gd").new()
	reverse.take_id = 3
	reverse.add_sample(0.0, Vector3(9, 0.05, 0), 0, 0, 0)
	reverse.add_sample(2.0, Vector3(0, 0.05, 0), 0, 0, 0)
	loaded.tracks.insert(1, reverse.to_dict())
	loaded.version = 1
	loaded.erase("at")
	loaded.erase("track_ranges")
	var f := FileAccess.open(Save.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(loaded))
	f.close()
	var old := Save.load_run()
	h.ok("real version 1 file loads", not old.is_empty())
	Run.pending_resume = old
	inst = SCENE.instantiate()
	tree.root.add_child(inst)
	inst.set_physics_process(false)
	inst.player.set_physics_process(false)
	h.ok("v1 falls back to last segment start", inst.player.global_position.distance_to(inst.segments.back().start) < 0.001)
	h.eq("v1 recovers old ghosts including seam return", inst._actors.size(), 3)
	h.eq("v1 first bay recovered", inst._track_ranges[0], Vector2i(0, 2))
	h.eq("v1 second bay recovered", inst._track_ranges[1], Vector2i(2, 3))
	inst.queue_free()
	await tree.process_frame
	await tree.process_frame
