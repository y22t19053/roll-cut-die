extends RefCounted

const FRAME := "res://scripts/relay/out_of_frame.gd"
const Save = preload("res://scripts/relay/relay_save.gd")


static func run(h, tree = null) -> void:
	h.begin("no_softlock")
	# Rebind the root script before instantiation. Replacing it on a live node
	# would orphan the player, camera and other nodes allocated by its initializers.
	var scene: PackedScene = load("res://scenes/relay/run.tscn").duplicate()
	var bundle := scene._bundled
	var index: int = bundle.variants.find(load("res://scripts/relay/relay_run.gd"))
	h.ok("real RelayRun script present", index >= 0)
	if index < 0:
		return
	bundle.variants[index] = load("res://tests/softlock_hit_probe.gd")
	scene._bundled = bundle
	var relay = scene.instantiate()
	var previous_save := Save.save_path
	Save.save_path = "user://rcd_test_saves/softlock_%s.json" % Crypto.new().generate_random_bytes(8).hex_encode()
	tree.root.add_child(relay)
	relay.slate.hide_slate()
	relay._prologue = 1
	var body = relay.player
	var start: Vector3 = relay.segments[0].start
	# Both wings, before the entrance, and beyond the exit. The player and
	# run keep their normal physics ordering, collision mask and hit handler.
	for x: float in [-6.0, 4.5, 15.0]:
		for side: float in [-1.0, 1.0]:
			var label := "outside x=%s side=%s " % [x, side]
			var outside := start + Vector3(x, 0.0, side * 11.0)
			body.teleport(outside, 0.0)
			body.input_override = Vector2(0.0, -side)
			relay.grace = 0.0
			var clock_before: float = relay.active_clock
			for tick in 8:
				await tree.physics_frame
			h.ok(label + "run kept ticking", relay.active_clock > clock_before)
			h.eq(label + "no hit attempted", relay.hit_calls, 0)
			h.eq(label + "no death", relay.deaths, 0)
			h.ok(label + "still in play", relay.phase == relay.Mode.PLAY and not relay._dying)
			h.ok(label + "finite position", body.global_position.is_finite())
			h.ok(label + "walks toward deck", (outside.z - body.global_position.z) * side > 0.02)
	body.input_override = Vector2.ZERO
	if ResourceLoader.exists(FRAME):
		for use_cut in [false, true]:
			await _recover(h, tree, relay, use_cut)
	else:
		h.note("SKIP no_softlock: OUT walk, empty CUT feedback and paid CUT BACK require " + FRAME)
	relay.queue_free()
	await tree.process_frame
	Save.clear()
	Save.save_path = previous_save


static func _recover(h, tree, relay, use_cut: bool) -> void:
	var frame = relay.get("out_of_frame")
	h.ok("OUT controller bound to run", is_instance_valid(frame))
	if not is_instance_valid(frame):
		return
	frame.reset_leg()
	for ng in frame.NG_LIMIT:
		frame.note_ng()
	frame.advance(frame.WARN_SECONDS)
	h.eq("recovery starts OUT", frame.state(), "OUT")
	if frame.state() != "OUT":
		return
	var body = relay.player
	if use_cut:
		relay.cut_stock = 1
		relay.touch_key(KEY_C)
		h.eq("CUT BACK charged once", relay.cut_stock, 0)
	else:
		relay.cut_stock = 0
		relay.touch_key(KEY_C)
		h.eq("empty CUT keeps walking available", frame.state(), "OUT")
		var labels = frame.find_children("*", "Label", true, false)
		var hint := false
		var loc = load("res://scripts/core/loc.gd")
		for label in labels:
			if label.is_visible_in_tree() and loc.STRINGS["frame.empty"].en in label.text:
				hint = true
		h.ok("empty CUT shows recovery hint", hint)
		body.input_override = Vector2.DOWN
	# Allow the doorway distance at walking speed, acceleration, and the CUT slate.
	var ticks := ceili((frame.WARN_SECONDS + 1.0) * Engine.physics_ticks_per_second)
	for tick in ticks:
		await tree.physics_frame
		if frame.state() == "IN":
			body.input_override = Vector2.ZERO
			if not body.frozen and body.is_on_floor():
				break
	var segment: Dictionary = relay.segments[relay.leg_room]
	h.eq("recovered within deadline (CUT=%s)" % use_cut, frame.state(), "IN")
	h.ok("back on floor", body.is_on_floor())
	h.ok("within room seams", body.position.x >= segment.start.x and body.position.x <= segment.end.x)
	h.ok("within deck width", absf(body.position.z - segment.start.z) <= 3.0)
	h.ok("control returned", not body.frozen and relay.phase == relay.Mode.PLAY)
	h.eq("recovery never hits player", relay.hit_calls, 0)
	body.input_override = Vector2.ZERO
