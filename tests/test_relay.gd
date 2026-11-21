extends RefCounted
## relay: the run's supplies, the splice window, what a leg keeps, and the
## geometry a dolly set promises. The scene's own state machine is covered by
## tests/test_relay_scene.gd; everything here is pure and runs without frames.

const Rules = preload("res://scripts/relay/relay_rules.gd")
const Splice = preload("res://scripts/relay/safety_splice.gd")
const Track = preload("res://scripts/ghost/ghost_track.gd")
const Rooms = preload("res://scripts/relay/relay_rooms.gd")


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
	rooms.append_room("s", 0, "fast")
	h.near("fast dolly runs a 3.4 s lap", float(rooms._dollies[3][0]["period"]), 3.4, 0.001)
	rooms.append_room("s", 0, "throat")
	h.near("throat keeps the plain lap", float(rooms._dollies[4][0]["period"]), 5.0, 0.001)

	# The trolley's danger is its footprint, sampled at the time you ask for.
	rooms.set_clock(0, 0.0)
	var cart_x: float = float(rooms._dollies[0][0]["node"].position.x)
	h.ok("the cart is dangerous at its own footprint", rooms.hazard_at(Vector3(cart_x, 0.05, 0.0), 0, 0.0))
	h.ok("the same corner is safe away from the cart", not rooms.hazard_at(Vector3(cart_x, 0.05, 3.4), 0, 0.0))
	h.ok("a room with no dolly is always safe", not rooms.hazard_at(Vector3(cart_x, 0.05, 0.0), 2, 0.0))

	rooms.queue_free()
	h.finish()
