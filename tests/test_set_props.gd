extends RefCounted
const Props = preload("res://scripts/relay/set_props.gd")
const Rooms = preload("res://scripts/relay/relay_rooms.gd")
const Loc = preload("res://scripts/core/loc.gd")
const Sound = preload("res://scripts/relay/relay_sound.gd")
const Track = preload("res://scripts/ghost/ghost_track.gd")
const Ghost = preload("res://scripts/ghost/ghost_actor.gd")


static func run(h, tree = null) -> void:
	h.begin("Set props")
	var sampled: Dictionary = {}
	for family: String in ["i", "l", "o", "h", "s"]:
		var spec := {"kind": family, "variant": 0}
		var layout := Props.layout(spec, 6481, 8)
		h.eq(family + " seed reproduces layout", layout, Props.layout(spec, 6481, 8))
		h.ok(family + " entity budget", layout.size() > 0 and layout.size() <= 12)
		var kinds := {}
		for item in layout:
			kinds[item.kind] = true
		h.eq(family + " unique types", kinds.size(), layout.size())
		h.ok(family + " has a side reward", kinds.has("film"))
		var mirrored := Props.layout({"kind": family, "variant": 1}, 6481, 8)
		for i in 2:
			h.eq(family + " variant mirrors open cells", mirrored[i].at, layout[i].at * Vector3(1, 1, -1))
			var at: Vector3 = layout[i].at
			var row := roundi(at.z / 1.12) + 2
			var column := roundi((at.x - 2.46) / 0.68)
			h.eq(family + " hazard sits on an open cell", Rooms.LANES[family][row][column], ".")
		for module in range(7, 20):
			for item in Props.layout(spec, 6481, module):
				if item.kind != "film":
					sampled[item.kind] = module
	h.eq("prologue rule can opt out", Props.layout({}, 6481, 8), [])
	h.ok("seed changes the layout", Props.layout({"kind": "s"}, 6481, 8) != Props.layout({"kind": "s"}, 6482, 8))
	h.ok("module number changes the layout", Props.layout({"kind": "s"}, 6481, 8) != Props.layout({"kind": "s"}, 6481, 9))
	h.eq("all four mechanisms generated", sampled.size(), Props.TYPES.size())
	for kind: String in Props.TYPES:
		if sampled.has(kind):
			_check_mechanism(h, kind)
	_check_strings_and_sound(h)
	await _check_scene(h, tree)
	h.finish()


static func _has(events: Array, kind: String, status: String) -> bool:
	return events.has({"kind": kind, "status": status})


static func _with_kind(kind: String) -> Props:
	var props := Props.new()
	for module in range(7, 20):
		props.build(null, {"kind": "i"}, 6481, module)
		for item in props.active_props():
			if item.kind == kind:
				return props
	return props


static func _check_mechanism(h, kind: String) -> void:
	var props := _with_kind(kind)
	var center := Vector3.ZERO
	var hand := 1.0
	for item in props.active_props():
		if item.kind == kind:
			center = item.at
			hand = item.hand
	var contact_age := 0.20 if kind != "clap" else 0.0
	var impact := center
	if kind in ["crane", "dolly"]:
		impact.x += Props.sweep(kind, contact_age, hand)
	var approach := center - Vector3(2.8, 0, 0)
	h.ok(kind + " warns before entry", _has(props.tick(0.0, approach), kind, "warn"))
	h.ok(kind + " query sees warning", props.warned_at(approach).has(kind))
	props.tick(0.60, approach)
	h.ok(kind + " no contact after 600 ms", not props.trigger_at(impact).has(kind))
	h.ok(kind + " future footprint safe at 990 ms", not _has(props.tick(0.99, impact), kind, "hit"))
	h.ok(kind + " future footprint query stays safe", not props.trigger_at(impact).has(kind))
	var warning_state := props.snapshot()
	var first := props.tick(1.0 + contact_age, impact)
	h.ok(kind + " trigger event", _has(first, kind, "fire"))
	h.ok(kind + " hit event", _has(first, kind, "hit"))
	h.ok(kind + " contact query matches hit", props.trigger_at(impact).has(kind))
	h.near(kind + " drag applies", props.speed_scale(), 0.50)
	var state := props.debug_state()
	props.restore_take(warning_state, false, 0.99)
	h.eq(kind + " checkpoint replays same events", props.tick(1.0 + contact_age, impact), first)
	h.eq(kind + " checkpoint replays same state", props.debug_state(), state)
	h.ok(kind + " hit does not repeat", not _has(props.tick(1.25, impact), kind, "hit"))
	props.tick(3.0, Vector3(-40, 0, 0))
	h.near(kind + " drag expires", props.speed_scale(), 1.0)
	h.ok(kind + " rearms after retreat", _has(props.tick(3.1, approach), kind, "warn"))
	props.reset_take(false)
	props.tick(0.0, approach)
	var sky := center + Vector3.UP * 1.2
	var miss := props.tick(1.0, sky)
	miss.append_array(props.tick(2.3, sky))
	h.ok(kind + " miss reported separately", _has(miss, kind, "clear"))
	h.ok(kind + " never hits above deck", not _has(miss, kind, "hit"))
	h.near(kind + " dodge leaves speed intact", props.speed_scale(), 1.0)


static func _check_strings_and_sound(h) -> void:
	var keys := ["countdown", "fired", "clear", "hit", "exposed", "pickup"]
	for kind: String in Props.TYPES + ["film"]:
		keys.append(kind)
		keys.append(kind + ".action")
	for id: String in keys:
		var key := "props." + id
		var strings: Dictionary = Loc.STRINGS.get(key, {})
		for language: String in Loc.SUPPORTED:
			h.ok(key + " " + language, not str(strings.get(language, "")).strip_edges().is_empty())
	for kind: String in Props.TYPES:
		var cues := {}
		for event: String in ["warn", "fire", "hit", "clear"]:
			cues[Sound.prop_cue(kind, event).data.hex_encode()] = true
		h.eq(kind + " four distinct audio waveforms", cues.size(), 4)
	h.ok("pickup has a different cue from a clear", Sound.prop_cue("film", "pickup").data != Sound.prop_cue("rack", "clear").data)


static func _check_scene(h, tree: SceneTree) -> void:
	var relay = load("res://scripts/relay/relay_run.gd")
	var seed := 6481
	while not Props.layout({"kind": "i"}, seed, 1).any(func(item: Dictionary) -> bool: return item.kind == "clap"):
		seed += 1
	var plan := [{"kind": "straight", "mod": "clean"}, {"kind": "i", "mod": "clean"}]
	relay.pending_resume = {"segments": plan, "seed": seed, "prologue": 1, "room_pass": 0,
		"required_passes": 2, "mark_stock": 2}
	var packed := load("res://scenes/relay/run.tscn") as PackedScene
	var scene = packed.instantiate()
	tree.root.add_child(scene)
	scene.set_physics_process(false)
	var props: Props = scene._props
	var claim_before: Dictionary = scene._serialize_run()
	h.eq("legacy Relay save allows pickup", claim_before.prop_film_room, -1)
	var film := Vector3.ZERO
	var clap := Vector3.ZERO
	for item in props.active_props():
		if item.kind == "film":
			film = item.at
		elif item.kind == "clap":
			clap = item.at
	var room: Node3D = props.room
	scene.elapsed = 0.1
	scene.player.teleport(room.to_global(film), 0.0)
	scene._step_set_props()
	scene.elapsed = 0.7
	scene._step_set_props()
	h.eq("film warns before payout", scene.mark_stock, 2)
	scene.elapsed = 1.2
	scene._step_set_props()
	h.eq("film grants one spendable MARK", scene.mark_stock, 3)
	h.eq("claim saved with the run", scene._serialize_run().prop_film_room, 1)
	scene._restore(0)
	h.eq("CUT keeps the reward", scene.mark_stock, 3)
	h.ok("CUT preserves the consumed reel", props.debug_state().film_taken)
	scene._start_leg(true)
	scene.set_physics_process(false)
	h.ok("next pass preserves the consumed reel", props.debug_state().film_taken)
	scene.player.teleport(room.to_global(clap), 0.0)
	scene.elapsed = 0.2
	scene._step_set_props()
	scene.elapsed = 1.25
	scene._step_set_props()
	h.ok("clap uses existing interaction flag on the track", scene.live.raw_at(scene.live.size() - 1).interact)
	h.eq("clap playback position round-trips", Track.from_dict(scene.live.to_dict()).raw_at(scene.live.size() - 1).position,
		scene.live.raw_at(scene.live.size() - 1).position)
	var ghost := Ghost.new()
	ghost.show_exposures = true
	ghost.setup(scene.live, 1)
	scene.add_child(ghost)
	ghost._physics_process(1.25)
	h.ok("ghost lights the exposed frame", ghost._exposure_left > 0.0)
	var written: Dictionary = scene._serialize_run()
	scene.queue_free()
	await tree.process_frame
	relay.pending_resume = written
	scene = packed.instantiate()
	tree.root.add_child(scene)
	h.ok("continue restores the consumed reel", scene._props.debug_state().film_taken)
	h.eq("continue restores one MARK reward", scene.mark_stock, 3)
	scene.queue_free()
	await tree.process_frame
