extends RefCounted

const Harness = preload("res://tests/harness.gd")
const RollModes = preload("res://scripts/camera/roll_modes.gd")
const Rig = preload("res://scripts/camera/camera_rig.gd")
const Ghost = preload("res://scripts/ghost/ghost_actor.gd")
const Player = preload("res://scripts/player/player.gd")
const Loc = preload("res://scripts/core/loc.gd")
const Rooms = preload("res://scripts/relay/relay_rooms.gd")
const Foley = preload("res://scripts/ui/foley.gd")
const Sound = preload("res://scripts/relay/relay_sound.gd")


static func run(h: Harness, tree: SceneTree = null) -> void:
	h.begin("inrun_ui_deai")
	h.near("ORBIT yaw degrees per second", RollModes.ORBIT_W_DEG, 30.0, 0.001)
	h.near("camera lean carve", Rig.LEAN_CARVE, 0.30)
	h.near("Ghost danger radius", Ghost.DANGER_RADIUS, 0.34)
	h.near("player collision radius", Player.RADIUS, 0.32)
	for kind: String in Foley.KINDS:
		_check_wav(h, "Foley " + kind, Foley.make_stream(kind))
	_check_wav(h, "S family bed", Sound.dress_for("s"))
	_check_wav(h, "L family hit", Sound.hit_for("l"))

	var sound_script: Script = Sound
	if sound_script.has_method("_compose_murmur"):
		var murmur: AudioStreamWAV = sound_script.call("_compose_murmur") as AudioStreamWAV
		_check_wav(h, "stillness crew murmur", murmur)
		if murmur != null:
			h.eq("soundstage mix rate", murmur.mix_rate, 22050)

	h.ok("live UI suite has a scene tree", tree != null)
	if tree != null:
		var session: Variant = tree.root.get_node("GameSession")
		var settings: Dictionary = session.settings
		var language: String = Loc.language
		var persist: bool = session.persist_prefs
		session.settings = settings.duplicate(true)
		session.persist_prefs = false
		await _settings(h, tree)
		await _pause(h, tree, session)
		tree.paused = false
		session.settings = settings
		Loc.set_language(language)
		session.apply_engine_settings()
		session.persist_prefs = persist
		await _desk(h, tree)
		await _run_cut_sync(h, tree)
		await _run_wrap(h, tree)
		_rooms(h, tree)
		await tree.process_frame
	h.finish()


static func _check_wav(h: Harness, cue: String, stream: AudioStream) -> void:
	var wav: AudioStreamWAV = stream as AudioStreamWAV
	h.ok(cue + " is WAV", wav != null)
	if wav != null:
		h.eq(cue + " is 16-bit PCM", wav.format, AudioStreamWAV.FORMAT_16_BITS)
		h.ok(cue + " has samples", wav.data.size() > 100)


static func _selected_tab(panel: Control, tab: String) -> bool:
	for button: Button in panel.find_children("*", "Button", true, false):
		if button.is_visible_in_tree() and button.button_pressed and button.text == Loc.ui("settings.tab_" + tab):
			return true
	return false


static func _settings(h: Harness, tree: SceneTree) -> void:
	# Resolve scripts that reference autoloads once the --script tree is ready.
	var panel: Variant = load("res://scripts/ui/settings_panel.gd").new()
	tree.root.add_child(panel)
	panel.open()
	h.ok("settings opened", panel.is_open())
	h.eq("settings tabs", panel.TABS, ["general", "controls", "audio", "video"])
	for tab: String in panel.TABS:
		panel._pick_tab(tab)
		await tree.process_frame
		h.ok("selected visible tab " + tab, _selected_tab(panel, tab))
	var other: String = "en" if Loc.language == "zh" else "zh"
	panel._pick_language(other)
	await tree.process_frame
	h.eq("settings changed language", Loc.language, other)
	h.ok("open video tab relabelled", _selected_tab(panel, "video"))
	panel.close()
	h.ok("settings closed", not panel.is_open())
	panel.free()
	await tree.process_frame


static func _pause(h: Harness, tree: SceneTree, session: Variant) -> void:
	session.set_language("en")
	session.set_setting("hud_scale", 1.0)
	session.set_setting("touch_pad", "auto")
	session.set_setting("reduce_motion", false)
	var pause: Variant = load("res://scripts/relay/relay_pause.gd").new()
	tree.root.add_child(pause)
	pause.briefing = {"set": 3, "sets": 12, "pass": 2, "passes": 5, "seed": 0x4A19C0, "deaths": 4}
	pause.open()
	h.ok("pause opened", pause.is_open)
	h.ok("pause stops the clock", tree.paused)
	pause._cycle_hud_scale()
	h.near("pause HUD scale advances", float(session.settings["hud_scale"]), 1.25)
	pause._cycle_touch_pad()
	h.eq("pause touch mode advances", session.settings["touch_pad"], "on")
	pause._toggle_motion()
	h.eq("pause toggles reduced motion", session.settings["reduce_motion"], true)
	for lang: String in ["zh", "en"]:
		pause._toggle_language()
		pause.refresh()
		await tree.process_frame
		h.eq("pause locale " + lang, Loc.language, lang)
		h.eq("pause language preference " + lang, session.settings["language"], lang)
		var found_seed: bool = false
		for label: Label in pause.find_children("*", "Label", true, false):
			if label.is_visible_in_tree() and "4A19C0" in label.text:
				found_seed = true
		h.ok("briefing shows the seed in " + lang, found_seed)
	pause.close()
	h.ok("pause closed", not pause.is_open)
	h.ok("closing resumes clock", not tree.paused)
	pause.free()
	await tree.process_frame


static func _desk(h: Harness, tree: SceneTree) -> void:
	var desk: Variant = load("res://scripts/relay/cutting_desk.gd").new()
	tree.root.add_child(desk)
	await tree.process_frame
	desk.set_hud_scale(0.5)
	h.near("HUD lower bound", desk._hud, 0.8)
	desk.set_hud_scale(2.0)
	h.near("HUD upper bound", desk._hud, 1.5)
	desk.update_run(2, 12, 1, 2, 5, 3, true, true)
	h.eq("HUD run and supplies", [desk._room, desk._rooms, desk._pass, desk._passes,
		desk._marks, desk._cuts, desk._splice], [2, 12, 1, 2, 5, 3, true])
	desk.show_draw([{"kind": "s", "mod_label": "FAST", "stake_label": "2 PASSES", "stamp": "+1 MARK"}], true)
	await tree.process_frame
	h.eq("room cards take pointer input", desk._sheet.mouse_filter, Control.MOUSE_FILTER_STOP)
	desk.hide_draw()
	h.eq("closed cards release input", desk._sheet.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	desk.show_items(false)
	await tree.process_frame
	h.eq("three supply choices", desk._cards.size(), 3)
	desk.hide_draw()
	desk.show_message("TAKE NOTE")
	await tree.process_frame
	h.eq("desk notice", desk._message, "TAKE NOTE")
	desk.show_call_sheet("PRINT", ["SEED 123456", "SETS 12/12"], true, true)
	desk.append_sheet_lines(["RANK #1"])
	await tree.process_frame
	h.eq("ranking appended to print", desk._sheet_lines, ["SEED 123456", "SETS 12/12", "RANK #1"])
	desk.clear_sheet()
	h.ok("call sheet cleared", desk._sheet_lines.is_empty() and desk._sheet_title.is_empty())
	if desk.has_method("set_cut_preview"):
		desk.call("set_cut_preview", {"active": true, "index": 2, "total": 4, "tag": "MARK 1",
			"take": 3, "time": 4.2, "lost": 1.8, "back_pass": 0, "free": true,
			"forced": false, "cuts": 3}, true)
		desk._sheet.queue_redraw()
		await tree.process_frame
		h.eq("CUT loupe displays the chosen MARK", desk._cut_preview.get("tag"), "MARK 1")
		h.eq("CUT loupe leaves input free", desk._sheet.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		var can_hide: bool = desk.has_method("hide_cut_preview")
		h.ok("CUT loupe has a dismissal", can_hide)
		if can_hide:
			desk.call("hide_cut_preview")
			h.ok("CUT loupe cleared", desk._cut_preview.is_empty())
	desk.free()


static func _run_cut_sync(h: Harness, tree: SceneTree) -> void:
	var packed: PackedScene = load("res://scenes/relay/run.tscn") as PackedScene
	h.ok("relay run scene loads for CUT loupe sync", packed != null)
	if packed == null:
		return
	var inst: Node = packed.instantiate()
	tree.root.add_child(inst)
	await tree.process_frame
	await tree.process_frame
	var slate: Node = inst.get("slate") as Node
	if slate != null and slate.call("is_running"):
		slate.call("_process", 1.0)
	inst.set("mark_stock", 2)
	inst.set("cut_stock", 2)
	inst.call("_press", KEY_M)
	inst.call("_press", KEY_C)
	var desk: Variant = inst.get("desk")
	h.eq("CUT loupe opens on latest anchor (0-based)", int(desk._cut_preview.get("index", -1)), int(inst.get("_selected")))
	inst.call("_press", KEY_UP)
	h.eq("CUT loupe steps to anchor 0 (0-based)", int(desk._cut_preview.get("index", -1)), 0)
	h.eq("CUT loupe total matches anchors", int(desk._cut_preview.get("total", 0)), (inst.get("anchors") as Array).size())
	inst.call("_press", KEY_ESCAPE)
	h.ok("leaving CUT clears loupe preview", desk._cut_preview.is_empty())
	inst.queue_free()
	await tree.process_frame
	await tree.process_frame


static func _run_wrap(h: Harness, tree: SceneTree) -> void:
	## The wrap is the last thing a run does, and only for a win. A plain relay
	## run never files a case report, so if the wrap only listened to a filed
	## verdict it would never play in the mode the game ships.
	var packed: PackedScene = load("res://scenes/relay/run.tscn") as PackedScene
	h.ok("relay run scene loads for the wrap", packed != null)
	if packed == null:
		return
	var inst: Node = packed.instantiate()
	tree.root.add_child(inst)
	await tree.process_frame
	await tree.process_frame
	var slate: Node = inst.get("slate") as Node
	if slate != null and slate.call("is_running"):
		slate.call("_process", 1.0)
	inst.set("deaths", 2)
	inst.set("cuts_used", 0)
	inst.call("_show_sheet", true)
	var cut: Variant = inst.get("_final_cut")
	h.ok("a relay win starts the final cut", cut != null)
	h.eq("the run's own ledger picks the ending", str(inst.get("verdict")), "reframe_held")
	h.eq("the wrap is marked played", bool(inst.get("_final_cut_played")), true)
	inst.call("_show_sheet", true)
	h.eq("the wrap cannot start twice", inst.get("_final_cut"), cut)
	if cut != null:
		cut.call("advance", 12.61)
		h.near("the wrap runs the full 12.60 s", float(cut.call("debug_state").get("elapsed", 0.0)), 12.6, 0.05)
		await tree.process_frame
		await tree.process_frame
		h.ok("the wrap hands the run back to the call sheet", inst.get("_final_cut") == null)
		h.ok("the call sheet still settles the run", not (inst.get("score_info") as Dictionary).is_empty())
	inst.queue_free()
	await tree.process_frame
	await tree.process_frame


static func _rooms(h: Harness, tree: SceneTree) -> void:
	var rooms: Rooms = Rooms.new()
	tree.root.add_child(rooms)
	var families: Array[String] = ["i", "l", "o", "h", "s"]
	for idx: int in families.size():
		var kind: String = families[idx]
		rooms.append_room(kind, idx, "", false, "runner,belt,key,goof,mezz,wire")
		var origin: Vector3 = Vector3(idx * Rooms.LENGTH, 0, 0)
		var exit_z: float = 1.95 if kind == "i" else 0.0
		var goof_z: float = -0.9 if idx % 2 == 0 else 0.9
		var runner: Vector3 = origin + Vector3(4.5, 0, 1.15)
		var off_lane: Vector3 = origin + Vector3(4.5, 0, 2.78)
		rooms.set_clock(idx, 2.5)
		h.ok(kind + " runner reaches crossing", rooms.crew_at(runner, idx))
		rooms.set_clock(idx, 0.0)
		h.ok(kind + " rewind clears crossing", not rooms.crew_at(runner, idx))
		rooms.set_clock(idx, 2.5)
		rooms.notice_player(runner + Vector3.RIGHT, idx, 0.1)
		h.ok(kind + " replay restores crossing", rooms.crew_at(runner, idx))
		h.ok(kind + " off-lane crew clearance", not rooms.crew_at(off_lane, idx))
		h.ok(kind + " exit crosses forward", rooms.crossed(origin + Vector3(Rooms.LENGTH, 0, exit_z), idx, false))
		h.ok(kind + " crossing requires the exit", not rooms.crossed(runner, idx, false))
		h.eq(kind + " belt carries forward", rooms.belt_push(origin + Vector3(4, 0, 0), idx), Vector3.RIGHT * Rooms.BELT_SPEED)
		h.eq(kind + " belt excludes side lane", rooms.belt_push(off_lane, idx), Vector3.ZERO)
		h.ok(kind + " key square", rooms.key_at(origin + Vector3(2.2, 0, 2.1), idx) and not rooms.key_at(off_lane, idx))
		h.ok(kind + " goof patch", rooms.goof_at(origin + Vector3(5.4, 0, goof_z), idx) and not rooms.goof_at(off_lane, idx))
		h.near(kind + " mezzanine surface", rooms.floor_height(origin + Vector3(4, 0, -2), idx), 1.2)
		h.near(kind + " deck surface", rooms.floor_height(off_lane, idx), 0.0)
		h.ok(kind + " wire mark", rooms.wire_at(origin + Vector3(1, 0, 0.9), idx) and not rooms.wire_at(off_lane, idx))
	rooms.free()
