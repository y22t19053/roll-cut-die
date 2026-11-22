extends RefCounted
## Every set has to be walkable, in the only sense that matters: you can get from
## the seam you enter at to the lit line at the far end.
##
## This exists because one shape was not. The O ring used to span the full width
## of the deck, so a run that picked it could never cross — and since a death only
## turns the set around, turning a full-width wall around leaves a full-width
## wall. The check below is geometry, not a scripted walk: it samples the room
## with the player's own capsule and asks whether the west edge and the east edge
## are in the same connected pocket of free space.


const RELAY := "res://scenes/relay/run.tscn"
const KINDS := ["l", "i", "o", "h", "s"]
const STEP_X := 24
const STEP_Z := 19


static func run(h, tree = null) -> void:
	h.begin("relay_walk")
	if tree == null:
		h.ok("a tree is available for a physics check", false)
		return

	var packed = load(RELAY)
	h.ok("relay scene loads for the walk check", packed != null)
	if packed == null:
		return
	var inst: Node = (packed as PackedScene).instantiate()
	tree.root.add_child(inst)
	await tree.process_frame
	await tree.process_frame

	var rooms: Node3D = inst.get_node("Rooms")
	var space := rooms.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.00
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = cap
	params.collision_mask = 1

	for kind: String in KINDS:
		rooms.append_room(kind, 0)
		await tree.physics_frame
		await tree.physics_frame
		var room: Node3D = rooms.get_child(rooms._rooms.size() - 1)

		var free: Array = []
		for ix in STEP_X:
			var col: Array = []
			for iz in STEP_Z:
				var lx := float(ix) / float(STEP_X - 1) * 9.0
				var lz := float(iz) / float(STEP_Z - 1) * 5.7 - 2.85
				params.transform = Transform3D(Basis(), room.to_global(Vector3(lx, 0.85, lz)))
				col.append(space.intersect_shape(params, 1).is_empty())
			free.append(col)

		# Seed just inside the entry seam: column 0 is the grip bay itself.
		var seen: Dictionary = {}
		var queue: Array = []
		for iz in STEP_Z:
			if free[2][iz]:
				seen[Vector2i(2, iz)] = true
				queue.append(Vector2i(2, iz))
		var best := 0
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_back()
			best = maxi(best, cell.x)
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = cell + d
				if n.x < 0 or n.y < 0 or n.x >= STEP_X or n.y >= STEP_Z: continue
				if not free[n.x][n.y]: continue
				if seen.has(n): continue
				seen[n] = true
				queue.append(n)
		h.ok("set '%s' can be crossed end to end" % kind, best >= STEP_X - 3)

	inst.queue_free()
	await tree.process_frame