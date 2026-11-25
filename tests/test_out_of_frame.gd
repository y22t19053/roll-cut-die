extends RefCounted
const Frame = preload("res://scripts/relay/out_of_frame.gd")
const Loc = preload("res://scripts/core/loc.gd")
const Rooms = preload("res://scripts/relay/relay_rooms.gd")
const Player = preload("res://scripts/player/player.gd")
const Track = preload("res://scripts/ghost/ghost_track.gd")

static func run(h, tree = null) -> void:
	h.begin("out_of_frame")
	var f := Frame.new()
	h.eq("starts inside", f.state(), "IN")
	f.advance(20.0)
	h.eq("time alone never ejects", f.state(), "IN")
	for n in 2:
		f.note_ng()
		h.eq("first two NG stay inside", f.state(), "IN")
	f.note_ng()
	h.eq("third NG warns", f.state(), "WARN")
	h.near("full warning", f.debug_state().remaining, 2.5)
	f.advance(-8.0)
	f.advance(NAN)
	h.near("invalid time ignored", f.debug_state().remaining, 2.5)
	f.note_ng()
	h.near("extra NG does not shorten warning", f.debug_state().remaining, 2.5)
	f.advance(2.499)
	h.eq("warning boundary", f.state(), "WARN")
	f.advance(0.001)
	h.eq("out at 2.5", f.state(), "OUT")
	f.spend_cut = func() -> bool: return false
	h.eq("empty cut rejected", f.cut_back(), false)
	h.eq("empty cut leaves outside", f.state(), "OUT")
	f.spend_cut = func() -> bool: return true
	h.eq("paid cut accepted", f.cut_back(), true)
	h.eq("cut resolves", f.state(), "IN")
	h.eq("inside cannot spend", f.cut_back(), false)
	f.note_ng()
	h.eq("one event per leg", f.state(), "IN")
	for cancel_at: float in [0.0, 0.5, 2.499]:
		f.reset_leg()
		for n in 3: f.note_ng()
		f.advance(cancel_at)
		f.resolve()
		f.advance(9.0)
		h.eq("line cancels warning", f.state(), "IN")
		f.reset_leg()
		for n in 3: f.note_ng()
		f.advance(cancel_at)
		h.ok("cut cancels warning", f.cut_back())
		h.eq("warning cut stays inside", f.state(), "IN")
	f.reset_leg()
	h.eq("new leg resets count", f.debug_state().ng, 0)
	h.eq("new leg rearms", f.debug_state().triggered, false)
	f.set_history([])
	h.eq("no history has crew guide", f.debug_state().steps, [0.0,0.6])
	var track := Track.new()
	track.times = PackedInt32Array([0, 400, 900, 1400])
	track.px = PackedInt32Array([0, 700, 1400, 2100])
	track.pz = PackedInt32Array([0, 0, 0, 0])
	f.set_history([track])
	h.eq("history supplies three strides", f.debug_state().steps.size(), 3)
	h.near("history timing retained", f.debug_state().steps[0], Track.dequant_time(400))
	h.near("loop retains take duration", f.debug_state().duration, track.duration()+0.35)
	for key: String in ["frame.warn","frame.resolve","frame.out","frame.cut","frame.empty"]:
		h.ok("English present", not str(Loc.STRINGS[key].en).is_empty())
		h.ok("Chinese present", not str(Loc.STRINGS[key].zh).is_empty())
	f.free()
	# Sweep an actual player cylinder through every family door, including turned sets.
	var rooms := Rooms.new()
	tree.root.add_child(rooms)
	var player := Player.new()
	tree.root.add_child(player)
	player.set_physics_process(false)
	for kind: String in ["straight","l","i","o","h","s"]:
		for hand in 2:
			rooms.append_room(kind, hand, "clean")
			var room: Node3D = rooms._rooms.back()
			if hand == 1:
				room.rotation.y = PI
				room.position.x += 9.0
			player.global_position = room.to_global(Frame.OUT_POSITION)
			await tree.physics_frame
			var motion: Vector3 = room.global_basis * Vector3(0,0,2.8)
			var collision := player.move_and_collide(motion)
			h.eq("door cylinder sweep %s/%d" % [kind,hand], collision, null)
			h.near("walk reaches legal frame", room.to_local(player.global_position).z, -2.4)
	player.free()
	rooms.free()
	var run = load("res://scenes/relay/run.tscn").instantiate()
	tree.root.add_child(run)
	run.set_physics_process(false)
	run._prologue = 1
	run.slate.hide_slate()
	run.player.set_frozen(false)
	var frame = run.out_of_frame
	for mode in [run.Mode.CUT,run.Mode.PICK,run.Mode.DONE,run.Mode.LOST,run.Mode.ACT]:
		run.phase = mode
		frame.note_ng()
		h.eq("non-play phase ignored", frame.debug_state().ng, 0)
	run.phase = run.Mode.PLAY
	for n in 3: frame.note_ng()
	run._dying = true
	frame.advance(8.0)
	h.near("death card preserves actionable warning", frame.debug_state().remaining, 2.5)
	run._dying = false
	var stock: int = run.cut_stock
	var marks: int = run.mark_stock
	var anchors: int = run.anchors.size()
	frame.advance(2.5)
	h.eq("real run ejects", frame.state(), "OUT")
	h.eq("no warning CUT cost", run.cut_stock, stock)
	h.eq("no light MARK loss", run.mark_stock, marks)
	h.eq("anchors retained", run.anchors.size(), anchors)
	h.ok("fixed camera current", frame._camera.current)
	h.ok("follow disabled", not run.rig.is_physics_processing())
	h.ok("distant ambience active", run.score._out_of_frame)
	run.cut_stock = 0
	var pos: Vector3 = run.player.global_position
	run._press(KEY_C)
	h.eq("empty CUT remains out", frame.state(), "OUT")
	h.eq("no free teleport", run.player.global_position, pos)
	run.player.global_position = frame._room.to_global(Vector3(1.6,0.05,-2.4))
	frame.advance(0.1)
	h.eq("walking resolves", frame.state(), "IN")
	h.ok("normal camera restored", run.rig.camera.current)
	h.ok("audio restored", not run.score._out_of_frame)
	frame.reset_leg()
	for n in 3: frame.note_ng()
	frame.advance(2.5)
	run.cut_stock = 2
	var used: int = run.cuts_used
	run._press(KEY_C)
	h.eq("CUT key resolves OUT", frame.state(), "IN")
	h.eq("CUT costs one", run.cut_stock, 1)
	h.eq("CUT billed once", run.cuts_used, used+1)
	h.eq("free tutorial cut not consumed", run.free_cut, 1)
	run.slate.hide_slate()
	await tree.process_frame
	run.queue_free()
	await tree.process_frame
