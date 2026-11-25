extends RefCounted

const RUN := "res://scripts/relay/relay_run.gd"
const ROOMS := "res://scripts/relay/relay_rooms.gd"
const SCENE := "res://scenes/relay/run.tscn"
const CRAFT := "res://scripts/relay/craft.gd"
const RULES := "res://scripts/relay/relay_rules.gd"
const Save = preload("res://scripts/relay/relay_save.gd")


static func _optional(path: String) -> Resource:
	return load(path) if ResourceLoader.exists(path) else null


static func run(h, tree = null) -> void:
	h.begin("sprint7_guard")
	var relay_script := _optional(RUN) as Script
	var rooms_script := _optional(ROOMS) as Script
	var scale := relay_script.get_script_constant_map() if relay_script else {}
	if scale.has_all(["MODULES", "SETS_PER_ACT", "ACTS"]):
		h.eq("total main sets", scale.MODULES, scale.SETS_PER_ACT * scale.ACTS)
		if scale.MODULES == 12 and scale.SETS_PER_ACT == 3:
			h.note("skipped MODULES >= 16 and SETS_PER_ACT == 4 (12/3，待 G 支合并)")
		else:
			h.at_least("main set count", scale.MODULES, 16)
			h.eq("sets per act", scale.SETS_PER_ACT, 4)
	else:
		h.note("skipped scale: relay_run or scale constants unavailable")

	var layout := rooms_script.get_script_constant_map() if rooms_script else {}
	if layout.has("GANTRY_SLOTS"):
		var slots = layout.GANTRY_SLOTS
		h.eq("four gantry slots", slots.size(), 4)
		for slot in [3, 7, 11, 15]:
			h.ok("act ends with gantry at main index %d" % slot, slot in slots)
	else:
		h.note("skipped gantry slots: GANTRY_SLOTS unavailable")

	if relay_script and rooms_script and ResourceLoader.exists(SCENE):
		await _walk(h, tree, load(SCENE))
	else:
		h.note("skipped long run: relay scene or scripts unavailable")
	_shoot(h)
	_ranks(h)
	var gate := FileAccess.get_file_as_string("res://tools/verify_all.py")
	for option in ["--noise-budget", "--baseline"]:
		h.ok("verify_all registers " + option, gate.contains('add_argument("' + option + '"'))


static func _walk(h, tree, scene: PackedScene) -> void:
	if scene == null:
		h.note("skipped long run: relay scene unavailable")
		return
	var relay := scene.instantiate()
	var rooms = relay.get_node_or_null("Rooms")
	if not rooms or not rooms.has_method("append_room") or not rooms.has_method("floor_height") or not rooms.has_method("room_at"):
		h.note("skipped long run: Rooms or room methods unavailable")
		relay.free()
		return
	var prior_save := Save.save_path
	Save.save_path = "user://rcd_test_saves/sprint7_%s.json" % Crypto.new().generate_random_bytes(8).hex_encode()
	tree.root.add_child(relay)
	relay.set_physics_process(false)
	relay.player.set_physics_process(false)
	# _ready builds the prologue. Append the 16 main sets after it.
	var segments: Array = relay.segments.duplicate()
	for i in 16:
		var kind := "gantry" if i % 4 == 3 else "straight"
		segments.append(rooms.append_room(kind, i, "clean"))
	await tree.physics_frame
	await tree.physics_frame
	var space: PhysicsDirectSpaceState3D = rooms.get_world_3d().direct_space_state
	for i in segments.size():
		var start: Vector3 = segments[i].start
		var end: Vector3 = segments[i].end
		if i > 0:
			h.eq("seam before room %d" % i, start, segments[i - 1].end)
		h.ok("room %d has a finite forward span" % i, start.is_finite() and end.is_finite() and end.x > start.x)
		if not start.is_finite() or not end.is_finite() or end.x <= start.x:
			continue
		# floor_height also returns zero on ordinary decks. Confirm the physical
		# floor just inside both edges and at intervals of at most half a metre.
		var steps := ceili((end.x - start.x) * 2)
		var gap := ""
		for step in range(steps + 1):
			var pos := start.lerp(end, float(step) / steps)
			var owner: int = rooms.room_at(pos)
			var height: float = rooms.floor_height(pos, owner)
			pos.x = clampf(pos.x, start.x + 0.01, end.x - 0.01)
			var ray := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.15, pos + Vector3.DOWN * 0.25)
			if not is_finite(height) or rooms.room_at(pos) != i or space.intersect_ray(ray).is_empty():
				gap = "step %d/%d at %s (height %s)" % [step, steps, pos, height]
				break
		h.ok("continuous floor in room %d" % i, gap.is_empty(), gap)
	for voice in relay.score.get_children():
		if voice is AudioStreamPlayer:
			voice.stop()
	for tick in 4:
		await tree.physics_frame
	relay.queue_free()
	await tree.process_frame
	Save.clear()
	Save.save_path = prior_save


static func _shoot(h) -> void:
	var craft := _optional(CRAFT)
	if not craft or not craft.has_method("shoot"):
		h.note("skipped four shoot cases: craft.gd or shoot unavailable")
		return
	var empty_bonus = null
	for inputs in [[0, 0, 0], [-1, -1, -1], [1000000, 1000000, 0], [0, 0, 1000000]]:
		var shot = craft.callv("shoot", inputs)
		var label := "shoot %s" % str(inputs)
		h.ok(label + " returns bonus and tier", shot is Dictionary and shot.has_all(["bonus", "tier"]))
		if shot is Dictionary and shot.has("bonus"):
			var bonus = shot.bonus
			h.ok(label + " finite nonnegative bonus", (bonus is int or bonus is float) and is_finite(bonus) and bonus >= 0)
			if inputs == [0, 0, 0]:
				empty_bonus = bonus
			elif inputs == [1000000, 1000000, 0] and (empty_bonus is int or empty_bonus is float):
				h.ok("saved resources improve the bonus", (bonus is int or bonus is float) and bonus > empty_bonus)
		h.eq(label + " is repeatable", shot, craft.callv("shoot", inputs))


static func _ranks(h) -> void:
	var rules := _optional(RULES)
	if not rules or not rules.has_method("archive_rank"):
		h.note("skipped nine archive_rank cases: RelayRules or archive_rank unavailable")
		return
	var previous = null
	var zero_rank = null
	for total in [-1000000, -1, 0, 1, 9, 10, 99, 100, 1000000]:
		var rank_value = rules.call("archive_rank", total)
		h.ok("integer rank at %d" % total, rank_value is int)
		if rank_value is int:
			h.ok("nondecreasing rank at %d" % total, previous == null or rank_value >= previous)
			if total == 0:
				zero_rank = rank_value
			elif total == 1000000 and zero_rank != null:
				h.ok("a large archive advances beyond the starting rank", rank_value > zero_rank)
			previous = rank_value
		h.eq("repeatable rank at %d" % total, rank_value, rules.call("archive_rank", total))
