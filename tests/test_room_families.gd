extends RefCounted

const Rooms = preload("res://scripts/relay/relay_rooms.gd")
const REQUIRED := ["straight", "tee", "cross", "zig"]
const ROOM_COUNT := 12


static func run(h, tree = null) -> void:
	h.begin("room_families")
	var rooms := Rooms.new()
	tree.root.add_child(rooms)
	# Exercise registered families (including the letter sets) in stable order.
	var kinds := Rooms.SET_INKS.keys()
	kinds.append_array(Rooms.LANES.keys())
	h.at_least("registered families", kinds.size(), 4)
	for kind in REQUIRED:
		h.ok("registered family %s" % kind, Rooms.SET_INKS.has(kind))
	var snapshots := []
	var previous_end := Vector3.ZERO
	for i in ROOM_COUNT:
		var label := "set %d " % (i + 1)
		var kind: String = kinds[i % kinds.size()]
		var segment := rooms.append_room(kind, i % 2, "", i == ROOM_COUNT - 1)
		var plan := rooms.plan(i)
		snapshots.append(plan.duplicate(true))
		h.ok(label + "segment contract", segment.has_all(["start", "end", "stops", "kind", "variant", "mod", "event", "final"]))
		h.ok(label + "route contract", plan.has_all(["entry", "exit", "mids"]))
		if not segment.has_all(["start", "end", "kind"]) or not plan.has_all(["entry", "exit"]):
			continue
		h.eq(label + "selected family", segment.kind, kind)
		h.near(label + "entry on west seam", plan.entry.x, 0.0, 0.0001)
		h.near(label + "exit on east seam", plan.exit.x, Rooms.LENGTH, 0.0001)
		var target: Vector3 = rooms._rooms[i].to_global(plan.exit)
		h.ok(label + "target on deck", absf(target.z - segment.end.z) <= 3.0)
		h.near(label + "target above floor", target.y - rooms.floor_height(target, i), 0.05, 0.0001)
		if i > 0:
			h.at_most(label + "meets previous set", previous_end.distance_to(segment.start), 0.0001)
		previous_end = segment.end
	var rebuilt := Rooms.new()
	tree.root.add_child(rebuilt)
	for i in ROOM_COUNT:
		rebuilt.append_room(kinds[i % kinds.size()], i % 2, "", i == ROOM_COUNT - 1)
		h.eq("rebuilding reproduces plan %d" % i, rebuilt.plan(i), snapshots[i])
	for i in range(ROOM_COUNT - 1, -1, -1):
		h.eq("stable plan after building all sets %d" % i, rooms.plan(i), snapshots[i])
	rooms.queue_free()
	rebuilt.queue_free()
	await tree.process_frame
