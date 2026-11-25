extends RefCounted

const Rooms = preload("res://scripts/relay/relay_rooms.gd")
const Save = preload("res://scripts/relay/relay_save.gd")
const Track = preload("res://scripts/ghost/ghost_track.gd")
const CameraMath = preload("res://scripts/camera/camera_math.gd")
const STEP := 1.0 / 60.0


static func run(h, tree = null) -> void:
	var RelayRun = load("res://scripts/relay/relay_run.gd")
	h.begin("gantry_room")
	var rooms := Rooms.new()
	tree.root.add_child(rooms)
	for i in RelayRun.MODULES:
		h.eq("main slot %d planning" % i, rooms.plan(0, i).get("kind", ""), "gantry" if i in Rooms.GANTRY_SLOTS else "")
	var before := rooms.append_room("straight", 0, "clean")
	var bay := rooms.append_room("gantry", 0)
	var after := rooms.append_room("cross", 0, "clean")
	for key in before:
		h.ok("gantry retains %s" % key, bay.has(key))
	h.eq("room kind", bay.kind, "gantry")
	h.eq("initial ground height", bay.floor, 0.0)
	h.eq("bridge top", bay.deck_top, 2.5)
	h.eq("target at exit", bay.target, bay.end)
	h.eq("stages meet at west seam", bay.start, before.end)
	h.eq("stages meet at east seam", bay.end, after.start)
	h.near("26 m ground deck", bay.end.x - bay.start.x, 26.0)
	h.near("following stage still 9 m", after.end.x - after.start.x, 9.0)
	h.eq("built plan retains kind", rooms.plan(1).kind, "gantry")
	h.eq("built plan retains both ramp approaches", rooms.plan(1).mids.size(), 5)
	h.eq("three stations", bay.stations.size(), 3)
	for i in 3:
		var local: Vector3 = [Vector3(13, 0, 0), Vector3(13, 2.5, 0), Vector3(8, 0, 5)][i]
		h.eq("world station %d" % i, bay.stations[i], Vector3(9, 0, 0) + local)
	for x: float in [-1.0, 0.0, 8.99, 9.0, 17.99, 27.0, 34.99, 35.0, 40.0, 70.0]:
		var expected := 0 if x < 9.0 else (1 if x < 35.0 else 2)
		h.eq("seam ownership at %.2f" % x, rooms.room_at(Vector3(x, 2.5, 0)), expected)
	var bridge: Vector3 = bay.stations[1]
	h.ok("bridge mark is reachable on the deck", rooms.reached(bridge, 1, bridge))
	h.ok("walking under the bridge cannot claim its mark", not rooms.reached(bay.stations[0], 1, bridge))
	h.ok("bridge level cannot claim a ground door", not rooms.crossed(bay.end + Vector3.UP * 2.5, 1, false))
	h.ok("west door is reachable at ground level", rooms.crossed(bay.start, 1, true))
	h.ok("east door is reachable at ground level", rooms.crossed(bay.end, 1, false))
	rooms.queue_free()
	await tree.process_frame

	var prior_save := Save.save_path
	Save.save_path = "user://rcd_test_saves/gantry_%s.json" % Crypto.new().generate_random_bytes(8).hex_encode()
	var Run = load("res://scripts/relay/relay_run.gd")
	var Scene = load("res://scenes/relay/run.tscn")
	Run.next_seed = 62
	var relay = Scene.instantiate()
	tree.root.add_child(relay)
	relay.set_physics_process(false)
	relay.player.set_physics_process(false)
	var live_rooms: Node3D = relay.get_node("Rooms")
	for i in Rooms.GANTRY_SLOTS[0]:
		relay.segments.append(live_rooms.append_room("straight", i, "clean"))
	relay._prologue = 1
	relay.leg_room = relay.segments.size() - 1
	relay.cards = relay._offer_doors()
	h.eq("three choices at the scheduled slot", relay.cards.size(), 3)
	for card: Dictionary in relay.cards:
		h.eq("all choices deal the scheduled gantry", card.kind, "gantry")
		h.eq("gantry has no unsupported scenery modifier", card.mod, "")
		h.eq("gantry has no unsupported event", card.event, "")
		h.ok("door card describes the ramps", not card.mod_label.is_empty())
	h.eq("door rewards are still different", relay.cards[1].reward, "mark")
	relay.phase = Run.Mode.PICK
	relay._pick_card(1)
	h.eq("picking a door mounts the gantry", relay.segments.back().kind, "gantry")
	h.ok("picking the door enables gravity", relay.player.vertical_walk)
	h.eq("outbound route has both ramps, the bridge and the door", relay.route.size(), 6)
	var outward: PackedVector3Array = relay.route.duplicate()
	await tree.physics_frame
	await tree.physics_frame
	for pass_index in 2:
		relay.grace = 1000.0
		var peak := 0.0
		for frame in 950:
			if relay.room_pass > pass_index: break
			var goal: Vector3 = relay.route[relay.cursor]
			var delta: Vector3 = goal - relay.player.global_position
			relay.player.input_override = Vector2(delta.x, delta.z).normalized()
			relay.player._physics_process(STEP)
			relay.rig._physics_process(STEP)
			relay._physics_process(STEP)
			peak = maxf(peak, relay.player.global_position.y)
			await tree.physics_frame
		h.eq("leg %d reaches the opposite ground door" % pass_index, relay.room_pass, pass_index + 1)
		h.near("leg %d climbs to the bridge" % pass_index, peak, 2.5, 0.1)
		if relay.room_pass <= pass_index: break
		var take: RefCounted = relay.tracks[pass_index]
		var bridge_time := _bridge_time(take)
		h.ok("leg %d records the whole climb" % pass_index, bridge_time > 0.0)
		var restored: RefCounted = Track.from_dict(take.to_dict())
		h.near("leg %d serialized bridge sample" % pass_index, restored.sample_at(bridge_time).position.y, 2.5, 0.02)
		if pass_index == 0:
			h.ok("second leg runs east to west", relay.returning)
			for i in 5:
				h.eq("return waypoint %d uses the same ramp or deck" % i, relay.route[i], outward[4 - i])
			var actor: Node3D = relay._actors[0]
			actor.playhead = bridge_time - STEP
			actor._physics_process(STEP)
			h.near("Relay Ghost actor runs on the bridge", actor.global_position.y, 2.5, 0.02)

	h.eq("completing the closing set opens the act contracts", relay.phase, Run.Mode.ACT)
	h.ok("completing the set extinguishes the route lamp", not relay._lamp.visible)
	var midpoint: Vector3 = relay.segments.back().stations[1]
	relay.player.teleport(midpoint, 0.3)
	relay.rig._physics_process(STEP)
	h.near("camera focuses above the elevated player", relay.rig.global_position.y,
		midpoint.y + CameraMath.FOCUS_HEIGHT)
	var state: Dictionary = relay._serialize_run()
	h.near("save retains an elevated player", state.at.get("y", -1), 2.5)
	h.ok("save round trip writes the bridge position", Save.save_run(state))
	var loaded := Save.load_run()
	var west: Vector3 = relay.segments.back().start
	relay.player.teleport(west - Vector3(0.3, 0.0, 0.0))
	relay._physics_process(STEP)
	h.ok("the previous bay turns gravity off", not relay.player.vertical_walk)
	relay.player.teleport(west + Vector3(0.3, 0.0, 0.0))
	relay._physics_process(STEP)
	h.ok("reentering turns gravity back on", relay.player.vertical_walk)
	await _retire(relay, tree)

	Run.pending_resume = loaded
	relay = Scene.instantiate()
	tree.root.add_child(relay)
	relay.set_physics_process(false)
	relay.player.set_physics_process(false)
	h.eq("resume rebuilds the gantry", relay.segments.back().kind, "gantry")
	h.eq("resume keeps the player upstairs", relay.player.global_position, midpoint)
	h.ok("resume upstairs enables gravity", relay.player.vertical_walk)
	await _retire(relay, tree)
	Save.clear()
	Save.save_path = prior_save


static func _retire(relay: Node, tree: SceneTree) -> void:
	for voice in relay.score.get_children():
		if voice is AudioStreamPlayer: voice.stop()
	# Let the audio server release its playbacks before the suite exits.
	for i in 4: await tree.physics_frame
	relay.queue_free()
	await tree.process_frame


static func _bridge_time(take: RefCounted) -> float:
	for i in take.size() - 1:
		if absi(take.py[i] - 2500) < 20 and absi(take.py[i + 1] - 2500) < 20:
			return Track.dequant_time(take.times[i] + take.times[i + 1]) * 0.5
	return -1.0
