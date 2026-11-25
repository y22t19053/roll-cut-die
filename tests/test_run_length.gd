extends RefCounted

const Rooms = preload("res://scripts/relay/relay_rooms.gd")
const GantryRoom = preload("res://scripts/relay/gantry_room.gd")


static func run(h, tree = null) -> void:
	var RelayRun = load("res://scripts/relay/relay_run.gd")
	h.begin("run_length")
	h.eq("sixteen sets", RelayRun.MODULES, 16)
	h.eq("four sets per act", RelayRun.SETS_PER_ACT, 4)
	h.eq("four acts", RelayRun.ACTS, 4)
	h.eq("act ladder covers the run", RelayRun.MODULES, RelayRun.ACTS * RelayRun.SETS_PER_ACT)
	var rooms := Rooms.new()
	tree.root.add_child(rooms)
	var distance := 0.0
	var gantries := 0
	for i in RelayRun.MODULES:
		var closing: bool = i % RelayRun.SETS_PER_ACT == RelayRun.SETS_PER_ACT - 1
		var planned := rooms.plan(i, i)
		h.eq("slot %d gantry schedule" % i, planned.get("kind", "") == "gantry", closing)
		var previous_cap: Node3D = rooms._cap
		var segment := rooms.append_room(str(planned.get("kind", "straight")), 0, "", i == RelayRun.MODULES - 1)
		if is_instance_valid(previous_cap):
			h.eq("slot %d removes old frontier cap" % i, previous_cap.get_parent(), null)
		var length := GantryRoom.LENGTH if closing else Rooms.LENGTH
		h.eq("slot %d start table" % i, rooms._starts[i], distance)
		h.eq("slot %d world start" % i, segment.start.x, distance)
		h.eq("slot %d seam belongs to new room" % i, rooms.room_at(Vector3(distance, 0, 0)), i)
		if i > 0:
			h.eq("slot %d west of seam belongs to previous room" % i, rooms.room_at(Vector3(distance - 0.01, 0, 0)), i - 1)
		distance += length
		h.eq("slot %d world end" % i, segment.end.x, distance)
		h.eq("slot %d accumulated length" % i, rooms._next_x, distance)
		h.eq("slot %d interior belongs to room" % i, rooms.room_at(Vector3(distance - 0.01, 0, 0)), i)
		h.eq("slot %d cap belongs only to latest room" % i, rooms._cap.get_parent(), rooms._rooms[i])
		h.eq("slot %d cap at east seam" % i, rooms._cap.global_position.x, distance)
		if closing:
			gantries += 1
			h.ok("gantry %d retains kind" % i, rooms.is_gantry(i))
			h.ok("gantry %d west door" % i, rooms.crossed(segment.start, i, true))
			h.ok("gantry %d east door" % i, rooms.crossed(segment.end, i, false))
	h.eq("four gantries built", gantries, RelayRun.ACTS)
	var expected: float = (RelayRun.MODULES - RelayRun.ACTS) * Rooms.LENGTH + RelayRun.ACTS * GantryRoom.LENGTH
	h.eq("exact total from room constants", rooms._next_x, expected)
	h.eq("all starts retained", rooms._starts.size(), RelayRun.MODULES)
	h.ok("fourth gantry retains solid end buffer", rooms._cap.find_children("*", "StaticBody3D", true, false).size() > 0)
	await tree.physics_frame
	await tree.physics_frame
	var space := rooms.get_world_3d().direct_space_state
	for i in Rooms.GANTRY_SLOTS:
		for x: float in [rooms._starts[i], rooms._starts[i] + GantryRoom.LENGTH]:
			var west := Vector3(x - 0.4, 0.5, 0)
			var east := Vector3(x + 0.4, 0.5, 0)
			h.ok("gantry %d door %.1f eastbound clear" % [i, x], space.intersect_ray(PhysicsRayQueryParameters3D.create(west, east)).is_empty())
			h.ok("gantry %d door %.1f westbound clear" % [i, x], space.intersect_ray(PhysicsRayQueryParameters3D.create(east, west)).is_empty())
	h.ok("final buffer blocks beyond the fourth gantry", not space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(distance + 1, 0.5, 0), Vector3(distance + 3, 0.5, 0))).is_empty())
	h.note("main run measured length: %.1f m" % rooms._next_x)
	rooms.queue_free()
	await tree.process_frame
	h.finish()
