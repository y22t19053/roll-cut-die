extends RefCounted
const Rules = preload("res://scripts/relay/relay_rules.gd")
const Props = preload("res://scripts/relay/set_props.gd")
const Frame = preload("res://scripts/relay/out_of_frame.gd")


static func run(h, tree = null) -> void:
	h.begin("difficulty")
	h.ok("pace strictly decreases", Rules.pace(0) > Rules.pace(1) and Rules.pace(1) > Rules.pace(2))
	h.ok("warning strictly decreases", Rules.warning_scale(0) > Rules.warning_scale(1) and Rules.warning_scale(1) > Rules.warning_scale(2))
	h.ok("EXPERT differs in two rules beyond budget", Rules.pace(1) < Rules.pace(0) and Rules.warning_scale(1) < Rules.warning_scale(0))
	for mode in [-1, 99]:
		h.eq("invalid pace falls back", Rules.pace(mode), Rules.pace(0))
		h.eq("invalid warning falls back", Rules.warning_scale(mode), Rules.warning_scale(0))
	var props := Props.new()
	h.eq("standalone props retain default", props.warn_scale, 1.0)
	var frame := Frame.new()
	h.eq("standalone frame retains default", frame.warn_scale, 1.0)
	frame.free()
	var durations: Array[float] = []
	for mode in 3:
		h.near("exact pace", Rules.pace(mode), [1.0, 0.92, 0.84][mode])
		h.near("exact warning scale", Rules.warning_scale(mode), [1.0, 0.85, 0.7][mode])
		h.eq("MARK budget unchanged", Rules.mark_budget(mode), [6, 6, 3][mode])
		h.eq("CUT budget unchanged", Rules.cut_budget(mode), [3, 3, 2][mode])
		var scene = load("res://scenes/relay/run.tscn").instantiate()
		scene.difficulty = mode
		tree.root.add_child(scene)
		scene.set_physics_process(false)
		scene._prologue = 1
		scene.slate.hide_slate()
		scene.phase = scene.Mode.PLAY
		for n in 3: scene.out_of_frame.note_ng()
		var remaining: float = scene.out_of_frame.debug_state().remaining
		durations.append(remaining)
		h.eq("real run enters warning", scene.out_of_frame.state(), "WARN")
		h.near("real warning duration", remaining, Frame.WARN_SECONDS * Rules.warning_scale(mode))
		h.ok("HUD shows actual scaled seconds", scene.out_of_frame._label.text.contains("%.1fs" % remaining))
		h.near("real props receive same scale", scene._props.warn_scale, Rules.warning_scale(mode))
		props.warn_scale = scene._props.warn_scale
		props.build(null, {"kind": "i"}, 6481, 8)
		props.tick(4.0, props.active_props()[0].at)
		h.near("prop arms with scaled warning", props.snapshot()[0].fire, 4.0 + Props.WARNING * Rules.warning_scale(mode))
		# Loading a different mode must replace the fresh scene's warning settings.
		scene._apply_run({"difficulty": 2 - mode})
		h.near("resume refreshes frame scale", scene.out_of_frame.warn_scale, Rules.warning_scale(2 - mode))
		h.near("resume refreshes prop scale", scene._props.warn_scale, Rules.warning_scale(2 - mode))
		scene.free()
		await tree.process_frame
	h.ok("MASTER real warning is shorter than NOVICE", durations[2] < durations[0])
	h.ok("EXPERT real warning is shorter than NOVICE", durations[1] < durations[0])
	h.finish()
