extends RefCounted
## relay: the run's supplies, the splice window, what a leg keeps, and the
## geometry a dolly set promises. The scene's own state machine is covered by
## tests/test_relay_scene.gd; everything here is pure and runs without frames.

const Rules = preload("res://scripts/relay/relay_rules.gd")
const Splice = preload("res://scripts/relay/safety_splice.gd")
const Track = preload("res://scripts/ghost/ghost_track.gd")
const Ghost = preload("res://scripts/ghost/ghost_actor.gd")
const Rooms = preload("res://scripts/relay/relay_rooms.gd")
const Save = preload("res://scripts/relay/relay_save.gd")
const Player = preload("res://scripts/player/player.gd")


static func run(h, tree = null) -> void:
	h.begin("relay")

	# Supplies belong to the difficulty, and an unknown mode gets nothing.
	h.eq("novice buys 6 marks", Rules._MARK[0], 6)
	h.eq("novice buys 3 cuts", Rules._CUT[0], 3)
	h.eq("expert buys 6 marks", Rules._MARK[1], 6)
	h.eq("expert buys 3 cuts", Rules._CUT[1], 3)
	h.eq("master buys 3 marks", Rules._MARK[2], 3)
	h.eq("master buys 2 cuts", Rules._CUT[2], 2)
	h.eq("three difficulties are priced", Rules._MARK.size(), 3)
	h.ok("novice is always open", Rules.unlocked(0))

	# The record book is read-only here: a test must never write a player's runs.
	var rec := Rules.meta()
	h.ok("the record keeps a run count", int(rec["runs"]) >= 0)
	h.ok("the record keeps a best set", int(rec["best_set"]) >= 0)
	var today := Rules.daily_seed()
	h.ok("the daily seed is stable within a day", today == Rules.daily_seed())
	h.ok("the daily seed prints in six hex digits", today >= 0 and today <= 0xFFFFFF)

	# A safety splice is one hit, protected for exactly its own window.
	var s = Splice.new()
	h.ok("no splice before the tray", not s.has_splice())
	h.ok("protect refuses when empty", not s.protect(0.0))
	s.offer()
	h.ok("splice held after the tray", s.has_splice())
	h.ok("protect spends it", s.protect(10.0))
	h.ok("spent splice is gone", not s.has_splice())
	h.ok("inside the window it keeps protecting", s.protect(10.4))
	h.ok("window is 1.5 s long", s.protect(11.6) == false)
	h.near("splice duration", Splice.DURATION, 1.5, 0.001)

	# A leg's own recording can be rewound to any earlier moment of itself.
	var tr = Track.new()
	tr.take_id = 1
	for i in 12:
		tr.add_sample(float(i) * 0.1, Vector3(float(i) * 0.3, 0.05, 0.0), 0.0, 0.0, 0.0)
	h.at_least("samples kept in order", tr.size(), 10)
	h.near("track duration", tr.duration(), 1.1, 0.05)
	var head = tr.head_until(0.5)
	h.ok("head_until never runs past the asked time", head.duration() <= 0.5 + 0.001)
	h.at_least("head_until keeps a prefix only", head.size(), 5)
	h.ok("head_until is shorter than the leg", head.size() < tr.size())
	h.near("sample_at interpolates", tr.sample_at(0.55).position.x, 1.65, 0.05)

	# A run written between takes has to come back as the same run: same seed,
	# same doors, same supplies, same recordings.
	Save.clear()
	h.ok("no run before one is written", not Save.has_run())
	h.ok("an empty file is not a run", Save.load_run().is_empty())
	var state := {"seed": 130334, "difficulty": 1, "required_passes": 4, "room_pass": 2,
		"segments": [{"kind":"straight","variant":0,"mod":""}, {"kind":"h","variant":1,"mod":"twin"}],
		"mark_stock": 5, "cut_stock": 2, "free_cut": 0, "splice": true, "deaths": 3,
		"tracks": [tr.to_dict()]}
	h.ok("a run is written", Save.save_run(state))
	h.ok("a written run is found", Save.has_run())
	var back: Dictionary = Save.load_run()
	h.eq("the seed survives", int(back.get("seed", 0)), 130334)
	h.eq("the doors survive", (back.get("segments", []) as Array).size(), 2)
	h.eq("a door keeps its condition", str((back["segments"] as Array)[1].get("mod", "")), "twin")
	h.eq("the legs done survive", int(back.get("room_pass", -1)), 2)
	h.eq("the supplies survive", int(back.get("cut_stock", -1)), 2)
	h.ok("the splice survives", bool(back.get("splice", false)))
	h.eq("the recordings survive", (back.get("tracks", []) as Array).size(), 1)
	var again = Track.from_dict((back["tracks"] as Array)[0])
	h.ok("a written track loads", again != null)
	if again != null:
		h.eq("the written track keeps its samples", again.size(), tr.size())
	Save.clear()
	h.ok("a finished run is not offered again", not Save.has_run())

	if tree == null:
		h.finish()
		return

	# The sets themselves: one room is nine metres, and a mod decides the traffic.
	var rooms = Rooms.new()
	tree.root.add_child(rooms)
	var plain: Dictionary = rooms.append_room("s", 0, "")
	h.near("a bay is nine metres long", plain.end.x - plain.start.x, Rooms.LENGTH, 0.01)
	h.eq("plain room has one dolly", rooms._dollies[0].size(), 1)
	rooms.append_room("s", 0, "twin")
	h.eq("twin room has two dollies", rooms._dollies[1].size(), 2)
	rooms.append_room("s", 0, "clean")
	h.eq("empty room has none", rooms._dollies[2].size(), 0)

	# Colour is not the only way to tell two past takes apart: each take gets one
	# notch on its floor ring, at a fixed angle, so the count reads in greyscale.
	var one = Ghost.new()
	one.setup(null, 1)
	tree.root.add_child(one)
	var three = Ghost.new()
	three.setup(null, 3)
	tree.root.add_child(three)
	var notches_one := 0
	for c in one.get_children():
		if str(c.name).begins_with("TakeNotch"): notches_one += 1
	var notches_three := 0
	for c in three.get_children():
		if str(c.name).begins_with("TakeNotch"): notches_three += 1
	h.eq("the first take has one notch", notches_one, 1)
	h.eq("the third take has three notches", notches_three, 3)
	one.queue_free()
	three.queue_free()
	rooms.append_room("s", 0, "fast")
	h.near("fast dolly runs a 3.4 s lap", float(rooms._dollies[3][0]["period"]), 3.4, 0.001)
	rooms.append_room("s", 0, "throat")
	h.near("throat keeps the plain lap", float(rooms._dollies[4][0]["period"]), 5.0, 0.001)
	# What the crew did to a set today is part of the room, and comes back with it.
	var extra: Dictionary = rooms.append_room("s", 0, "", false, "extra")
	h.eq("a rented dolly joins the set", rooms._dollies[5].size(), 2)
	h.eq("the plan remembers the event", str(extra.get("event", "")), "extra")
	rooms.append_room("s", 0, "", false, "relight")
	var lit := 0
	for child in (rooms._rooms[6] as Node3D).find_children("*", "OmniLight3D", true, false):
		lit += 1
	h.eq("a relamp hangs a light on the dolly", lit, 1)
	var last_set: Dictionary = rooms.append_room("h", 0, "", true, "guide")
	h.ok("the last set says it is the last", bool(last_set.get("final", false)))
	h.eq("a guide set brings no light and no extra dolly", (rooms._dollies[7] as Array).size(), 1)

	# The light line has to fit through the throat it points at. A straight walk
	# into the goal used to end against the inside face of a grip bay.
	var Run = load("res://scripts/relay/relay_run.gd")
	var widest_throat := 1.62 - 1.68 * 0.5
	h.ok("the line fits a throat set",
		float(Run.LANE) + float(Player.RADIUS) < widest_throat)
	h.ok("the line stays off centre", float(Run.LANE) > 0.05)

	# The crew opens one drawer at a time: the first set is clean, the second may
	# only show a ghost that cannot kill, and everything is available from the third.
	var first_pool: Array = Run._event_pool_for(0)
	h.ok("the first set is clean", first_pool.size() == 1 and str(first_pool[0]) == "")
	var second_pool: Array = Run._event_pool_for(1)
	var loud := 0
	for e: String in second_pool:
		if e != "" and e != "guide":
			loud += 1
	h.eq("only a demonstration joins the second set", loud, 0)
	var open_pool: Array = Run._event_pool_for(3)
	h.ok("the shop is open by the third set", open_pool.has("belt") and open_pool.has("wire"))

	# Chasing the light: only a whole set of quick passes pays, and a slow one just
	# does not pay (it never takes anything away).
	h.ok("one quick pass is not a set", not Run._won_light(1, 2))
	h.ok("every pass quick pays", Run._won_light(2, 2))
	h.ok("a longer set needs more quick passes", not Run._won_light(4, 5))
	h.ok("an empty set never pays", not Run._won_light(0, 0))

	# The three shapes that answer the turn three different ways.
	h.ok("I is a shape", Rooms.LANES.has("i"))
	h.ok("L is a shape", Rooms.LANES.has("l"))
	h.ok("O is a shape", Rooms.LANES.has("o"))
	var bar: Array = Rooms.LANES["i"]
	var bar_wall := 0
	for row: String in bar:
		bar_wall += row.count("#")
	h.eq("I is one bar across the middle", bar_wall, 7)
	h.eq("the bar sits on the centre line", bar[0].count("#"), 0)
	var ring: Array = Rooms.LANES["o"]
	h.eq("O is a closed ring", ring[2].count("#"), 2)
	h.eq("O keeps its inside empty", ring[2].substr(2, 3), "...")
	rooms.append_room("i", 0, "")
	rooms.append_room("o", 0, "")
	h.eq("an I room still runs one dolly", (rooms._dollies[8] as Array).size(), 1)
	h.eq("an O room still runs one dolly", (rooms._dollies[9] as Array).size(), 1)

	# The trolley's danger is its footprint, sampled at the time you ask for.
	rooms.set_clock(0, 0.0)
	var cart_x: float = float(rooms._dollies[0][0]["node"].position.x)
	h.ok("the cart is dangerous at its own footprint", rooms.hazard_at(Vector3(cart_x, 0.05, 0.0), 0, 0.0))
	h.ok("the same corner is safe away from the cart", not rooms.hazard_at(Vector3(cart_x, 0.05, 3.4), 0, 0.0))
	h.ok("a room with no dolly is always safe", not rooms.hazard_at(Vector3(cart_x, 0.05, 0.0), 2, 0.0))

	# The belt answers to the stage: turn the set end for end and it carries you
	# the other way in the world, with no new rule anywhere.
	rooms.append_room("s", 0, "", false, "belt")
	var belt_room: int = rooms._count - 1
	var belt_node: Node3D = rooms._rooms[belt_room]
	var belt_mid: Vector3 = belt_node.to_global(Vector3(4.6, 0.05, 0.0))
	var push_before: Vector3 = rooms.belt_push(belt_mid, belt_room)
	h.ok("the belt pushes you somewhere", push_before.length() > 1.0)
	h.ok("the belt does not push you off the deck", absf(push_before.y) < 0.001)
	var off_belt: Vector3 = belt_node.to_global(Vector3(4.6, 0.05, 2.4))
	h.ok("three metres off the belt is no push at all", rooms.belt_push(off_belt, belt_room).length() < 0.001)
	var plain_room: int = 0
	h.ok("a room with no belt never pushes", rooms.belt_push(belt_mid, plain_room).length() < 0.001)

	# The runner crosses because his business is on the other side.
	rooms.append_room("s", 0, "", false, "runner")
	var run_room: int = rooms._count - 1
	var runner: Node3D = rooms._runners[run_room]["node"]
	rooms.set_clock(run_room, 0.0)
	var at_start: float = runner.position.z
	rooms.set_clock(run_room, 1.0)
	h.ok("the runner is somewhere else a second later", absf(runner.position.z - at_start) > 0.4)
	var under_him: Vector3 = rooms._rooms[run_room].to_global(runner.position + Vector3(0, 0.05, 0))
	h.ok("standing where he is is fatal", rooms.crew_at(under_him, run_room))
	var clear_spot: Vector3 = rooms._rooms[run_room].to_global(Vector3(4.5, 0.05, runner.position.z + 2.4))
	h.ok("two metres away is clear", not rooms.crew_at(clear_spot, run_room))
	h.ok("a room with no runner has no crew", not rooms.crew_at(under_him, 0))

	# Taped-off deck: not a body in the way, a mistake the take cannot survive.
	rooms.append_room("s", 0, "", false, "goof")
	var goof_room: int = rooms._count - 1
	var goof_mid: Vector3 = rooms._rooms[goof_room].to_global(Vector3(5.4, 0.05, -0.9))
	h.ok("the taped deck knows where the tape is", rooms.goof_at(goof_mid, goof_room))
	h.ok("two metres off the tape is clear", not rooms.goof_at(goof_mid + Vector3(2.0, 0, 0), goof_room))
	h.ok("a set with no tape has no goof", not rooms.goof_at(goof_mid, 0))

	# The key square: you are not in the plate, so nothing in the room reaches you.
	rooms.append_room("s", 0, "", false, "key")
	var key_room: int = rooms._count - 1
	var key_mid: Vector3 = rooms._rooms[key_room].to_global(Vector3(2.2, 0.05, 2.1))
	h.ok("the key square is where the green screen says", rooms.key_at(key_mid, key_room))
	h.ok("a metre and a half away is out of the plate", not rooms.key_at(key_mid + Vector3(0, 0, -1.6), key_room))
	h.ok("a set with no green screen keys nothing", not rooms.key_at(key_mid, 0))

	# The catwalk: the floor is a height now, not always zero.
	rooms.append_room("l", 0, "", false, "mezz")
	var mezz_room: int = rooms._count - 1
	var mezz_x: float = rooms._rooms[mezz_room].to_global(Vector3(4.5, 0, -2.0)).x
	h.eq("the deck is still the deck where there is no catwalk", rooms.floor_height(rooms._rooms[mezz_room].to_global(Vector3(4.5, 0, 1.6)), mezz_room), 0.0)
	h.near("the catwalk is up over the lane", rooms.floor_height(rooms._rooms[mezz_room].to_global(Vector3(4.5, 0, -2.0)), mezz_room), 1.2, 1e-3)
	h.ok("the ramp climbs on the way in", rooms.floor_height(rooms._rooms[mezz_room].to_global(Vector3(1.5, 0, -2.0)), mezz_room) > 0.3)
	h.eq("the belt does not move the catwalk", rooms.belt_push(rooms._rooms[mezz_room].to_global(Vector3(4.5, 1.25, -2.0)), mezz_room), Vector3.ZERO)
	h.ok("a set with no catwalk is flat", rooms.floor_height(Vector3(mezz_x, 0.05, -2.0), 0) < 0.05)

	# A stand-in on the track: the dolly stops for him and the clock says so.
	rooms.append_room("s", 0, "", false, "double")
	var dbl_room: int = rooms._count - 1
	var dbl: Dictionary = rooms._doubles[dbl_room]
	h.ok("the stand-in is standing on the track", rooms._doubles.has(dbl_room))
	# Sweep two full seconds in small steps; the dolly has to reach him at least once.
	var stalled := 0.0
	for i in 240:
		rooms.set_clock(dbl_room, float(i) * 0.01)
	stalled = float(rooms._doubles[dbl_room]["stall"])
	h.ok("the dolly stalls when it reaches the stand-in", stalled > 0.05)
	# The hazard pose has to use the same clock, or the cart is not where it looks.
	var dbl_x: float = float(dbl["x"])
	var hit_pose: Vector3 = rooms._rooms[dbl_room].to_global(Vector3(dbl_x, 0.05, float(dbl["z"])))
	h.ok("what the cart looks like is what the cart is", rooms.hazard_at(hit_pose, dbl_room, 2.4) == rooms.hazard_at(hit_pose, dbl_room, 2.4 + stalled))

	# Later acts dress one set with two things at once. Both have to be real
	# geometry on the same room, not one overriding the other.
	var both: Dictionary = rooms.append_room("s", 0, "", false, "belt,mezz")
	var both_room: int = rooms._count - 1
	h.ok("a stacked set lays the belt", rooms._belts.has(both_room))
	h.ok("a stacked set also builds the catwalk", rooms._mezz.has(both_room))
	h.eq("a stacked set still runs one house dolly", (rooms._dollies[both_room] as Array).size(), 1)
	h.eq("the plan keeps both events", str(both.get("event", "")), "belt,mezz")
	h.ok("the belt still pushes on a stacked set", rooms.belt_push(rooms._rooms[both_room].to_global(Vector3(4.5, 0.05, 0.0)), both_room) != Vector3.ZERO)
	rooms.append_room("l", 0, "", false, "key,goof")
	var key_goof: int = rooms._count - 1
	h.ok("a keyed set keeps the green square", rooms._keys.has(key_goof))
	h.ok("a keyed set also keeps the taped patch", rooms._goofs.has(key_goof))

	# The flying rig: one pick-up, one drop, no steering.
	rooms.append_room("s", 0, "", false, "wire")
	var wire_room: int = rooms._count - 1
	h.ok("a wire set has a rig", rooms._wires.has(wire_room))
	var hook: Vector3 = rooms._rooms[wire_room].to_global(Vector3(1.0, 0.05, 0.9))
	h.ok("standing on the mark hooks you up", rooms.wire_at(hook, wire_room))
	h.ok("standing across the set does not", not rooms.wire_at(rooms._rooms[wire_room].to_global(Vector3(6.0, 0.05, -1.6)), wire_room))
	h.eq("a plain set has no rig", rooms.wire_at(hook, 0), false)
	var ride: Dictionary = rooms.wire_ride(wire_room)
	h.ok("the flight is long enough to matter", (ride["from"] as Vector3).distance_to(ride["to"] as Vector3) > 6.0)
	h.ok("the flight clears the dolly band", (ride["from"] as Vector3).y > 1.10)

	# The room reports its own doors, and the crossing test reads that plan. These
	# pin the straight behaviour first, then the off-axis one, so a later plan
	# cannot quietly move the finish line out from under the light.
	var plain_plan: Dictionary = rooms.plan(0)
	h.near("a straight set enters at its near seam", float((plain_plan["entry"] as Vector3).x), 0.0, 0.001)
	h.near("a straight set leaves at its far seam", float((plain_plan["exit"] as Vector3).x), 9.0, 0.001)
	h.near("a straight set leaves on the centre line", float((plain_plan["exit"] as Vector3).z), 0.0, 0.001)
	var straight: Node3D = rooms._rooms[0]
	h.ok("standing on the far line crosses it",
		rooms.crossed(straight.to_global(Vector3(9.02, 0.05, 0.40)), 0, false))
	h.ok("two metres short does not",
		not rooms.crossed(straight.to_global(Vector3(7.0, 0.05, 0.40)), 0, false))
	h.ok("the near seam ends a return leg",
		rooms.crossed(straight.to_global(Vector3(0.02, 0.05, -0.40)), 0, true))
	rooms.append_room("i", 1, "")
	var hollow_room: int = rooms._count - 1
	var hollow_plan: Dictionary = rooms.plan(hollow_room)
	h.ok("a hollow set enters low and leaves high",
		float((hollow_plan["entry"] as Vector3).z) < -1.0 and float((hollow_plan["exit"] as Vector3).z) > 1.0)
	h.ok("its far line is where the plan says it is",
		rooms.crossed(rooms._rooms[hollow_room].to_global(Vector3(9.0, 0.05, 1.95)), hollow_room, false))
	h.ok("its centre is not the door any more",
		not rooms.crossed(rooms._rooms[hollow_room].to_global(Vector3(9.0, 0.05, -1.6)), hollow_room, false))

	rooms.queue_free()
	h.finish()
