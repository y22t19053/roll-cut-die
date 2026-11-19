extends Node3D
## Main — the conductor of one studio.
##
## Owns no rules of its own: it reads the map, builds the room, wires the
## systems together, and routes input to the managers that do know the rules.
## Every state change goes through TakeManager, so "what is happening" is never
## stored twice.

const RoomSpec = preload("res://scripts/world/room_spec.gd")
const RoomBuilder = preload("res://scripts/world/room_builder.gd")
const PlayerScript = preload("res://scripts/player/player.gd")
const CameraRigScript = preload("res://scripts/camera/camera_rig.gd")
const CameraMath = preload("res://scripts/camera/camera_math.gd")
const NpcScript = preload("res://scripts/npc/npc_patrol.gd")
const GhostActorScript = preload("res://scripts/ghost/ghost_actor.gd")
const GhostRecorderScript = preload("res://scripts/ghost/ghost_recorder.gd")
const GhostTrack = preload("res://scripts/ghost/ghost_track.gd")
const EvidenceScript = preload("res://scripts/case/evidence_prop.gd")
const SlateScript = preload("res://scripts/ui/slate_ui.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const InputSetup = preload("res://scripts/core/input_setup.gd")
const Loc = preload("res://scripts/core/loc.gd")
const Logger = preload("res://scripts/core/logger.gd")

const MAP_PATH := "res://data/studio_map.json"
const CASE_PATH := "res://data/case.json"
const ASK_RANGE := 1.35

## Only these three end the take. Everything else is a report that was handed
## back over the desk: the player keeps every flag, and the take continues.
const TERMINAL_VERDICTS := ["file_closed", "bury_registered", "reframe_held"]

enum Phase { ROLLING, DEAD, CUT, REPORT, COMPLETE }

var map_data: Dictionary = {}
var player: Node3D
var rig: Node3D
var npcs: Array = []
var evidence_props: Dictionary = {}
var ghost_nodes: Array = []
var recorder: Node
var slate: CanvasLayer
var hud: CanvasLayer

var spawn_pos := Vector3(2.0, 0.05, 16.6)
var report_pos := Vector3.ZERO
var report_radius := 1.5

var phase := Phase.ROLLING
var paused := false
var debug_on := false
var report_cursor := 0

var _occluder: Node = null


func _ready() -> void:
	InputSetup.ensure_actions()
	var problems := InputSetup.verify_actions()
	for p: String in problems:
		Logger.error("input: " + p)

	if not _load_map():
		return
	_load_case()
	_build_world()
	_build_actors()
	_build_ui()

	GameSession.takes.start_take(1)
	_begin_take()

	Logger.info("main ready: %d npcs, %d evidence, ghosts %d" % [npcs.size(), evidence_props.size(), ghost_nodes.size()])


# --- setup ---------------------------------------------------------------

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		Logger.error("missing data file: " + path)
		return null
	var txt := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(txt)
	if parsed == null:
		Logger.error("invalid json: " + path)
	return parsed


func _load_map() -> bool:
	var parsed: Variant = _read_json(MAP_PATH)
	if not (parsed is Dictionary):
		Logger.error("map: not a dictionary")
		return false
	map_data = parsed
	var problems := RoomSpec.validate(map_data)
	if not problems.is_empty():
		for p: String in problems:
			Logger.error("map: " + p)
		return false
	var sp: Array = map_data.get("spawn", [2.0, 16.6])
	spawn_pos = Vector3(float(sp[0]), 0.05, float(sp[1]))
	var rz: Dictionary = map_data.get("report_zone", {})
	var rp: Array = rz.get("pos", [2.6, 15.2])
	report_pos = Vector3(float(rp[0]), 0.0, float(rp[1]))
	report_radius = float(rz.get("radius", 1.5))
	return true


func _load_case() -> void:
	var parsed: Variant = _read_json(CASE_PATH)
	if not (parsed is Dictionary):
		Logger.warn("case.json missing or invalid — running with an empty case")
		parsed = {"evidence": [], "npcs": [], "report": {"stances": [], "verdicts": {}}}
	GameSession.case_state.load_data(parsed)


func _build_world() -> void:
	var built := RoomBuilder.build(self, map_data)
	var size_v: Vector2 = built["size"]

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.022, 0.026)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.66, 0.76)
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# The set stands on a stage floor. Without it the camera sees raw background
	# every time a swing takes it outside the room's footprint, which reads as a
	# hole in the world rather than as a dark stage.
	var stage := MeshInstance3D.new()
	stage.name = "Stage"
	var stage_plane := PlaneMesh.new()
	stage_plane.size = Vector2(72.0, 60.0)
	stage.mesh = stage_plane
	var stage_mat := StandardMaterial3D.new()
	stage_mat.albedo_color = Color(0.085, 0.088, 0.098)
	stage_mat.roughness = 1.0
	stage.material_override = stage_mat
	stage.position = Vector3(size_v.x * 0.5, -0.02, size_v.y * 0.5)
	add_child(stage)

	# Key light: high and slightly behind-left, the way a set is lit for
	# coverage. A low sun stretched every wall into a black parallelogram that
	# read as a pit in the floor.
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-72.0, -32.0, 0.0)
	sun.light_energy = 1.0
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.shadow_enabled = true
	sun.light_angular_distance = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 34.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.0
	add_child(sun)

	# Two practicals so the room has depth and the office reads as "lit set".
	for spot in [[6.0, 8.0, 4.0, Color(1.0, 0.85, 0.65), 1.2], [19.0, 10.0, 4.5, Color(0.75, 0.85, 1.0), 0.9]]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(float(spot[0]), 3.2, float(spot[1]))
		lamp.omni_range = float(spot[2])
		lamp.light_color = spot[3]
		lamp.light_energy = float(spot[4])
		add_child(lamp)

	Logger.info("room built %.0fx%.0f" % [size_v.x, size_v.y])


func _build_actors() -> void:
	player = PlayerScript.new()
	player.name = "Player"
	add_child(player)
	player.teleport(spawn_pos, 0.0)

	rig = CameraRigScript.new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.setup(player)
	rig.reduce_motion = bool(GameSession.settings.get("reduce_motion", false))
	rig.roll_scale = float(GameSession.settings.get("roll_scale", 1.0))
	rig.mouse_sensitivity = float(GameSession.settings.get("mouse_sensitivity", 0.0022))

	for n: Variant in map_data.get("npcs", []):
		var nd: Dictionary = n
		var pts := PackedVector3Array()
		for pt: Variant in nd.get("route", []):
			var a: Array = pt
			pts.append(Vector3(float(a[0]), 0.0, float(a[1])))
		var node = NpcScript.new()
		node.name = "NPC_" + str(nd.get("id", "npc"))
		add_child(node)
		var meta: Dictionary = GameSession.case_state.npc_meta(str(nd.get("id", "")))
		var label := Loc.t(meta.get("name", {})).to_upper()
		if label.is_empty():
			label = str(nd.get("id", "")).to_upper()
		node.setup(str(nd.get("id", "")), label, pts, float(nd.get("speed", 1.0)),
			float(nd.get("dwell", 0.0)), str(nd.get("mode", "loop")))
		node.caught_player.connect(_on_npc_caught)
		npcs.append(node)

	for e: Variant in map_data.get("evidence", []):
		var ed: Dictionary = e
		var eid := str(ed.get("id", ""))
		var pos_arr: Array = ed.get("pos", [0.0, 0.0])
		var prop = EvidenceScript.new()
		prop.name = "Evidence_" + eid
		add_child(prop)
		prop.setup(eid, Vector3(float(pos_arr[0]), 0.0, float(pos_arr[1])),
			GameSession.case_state.evidence_meta(eid))
		evidence_props[eid] = prop

	recorder = GhostRecorderScript.new()
	recorder.name = "GhostRecorder"
	add_child(recorder)
	recorder.setup(player, rig, 1)


func _build_ui() -> void:
	hud = HudScript.new()
	hud.name = "Hud"
	add_child(hud)

	slate = SlateScript.new()
	slate.name = "Slate"
	add_child(slate)
	slate.sequence_finished.connect(_on_slate_finished)


# --- take flow -----------------------------------------------------------

func _begin_take() -> void:
	phase = Phase.ROLLING
	var idx: int = GameSession.takes.take_index
	_clear_ghosts()
	_spawn_ghosts()
	for n: Node in npcs:
		n.set_active(true)
		n.reset_phase()
	player.teleport(spawn_pos, 0.0)
	player.set_frozen(true)
	_refresh_evidence()
	recorder.setup(player, rig, idx)
	recorder.start()
	slate.play_roll(idx)
	_update_hud()
	hud.set_hint("")


func _spawn_ghosts() -> void:
	for item: Dictionary in GameSession.ghosts:
		var tr: Variant = item.get("track")
		if tr == null:
			continue
		var g = GhostActorScript.new()
		g.name = "Ghost_%02d" % int(item.get("take", 0))
		add_child(g)
		g.setup(tr, int(item.get("take", 0)))
		g.caught_player.connect(_on_ghost_caught)
		ghost_nodes.append(g)


func _clear_ghosts() -> void:
	for g: Node in ghost_nodes:
		g.queue_free()
	ghost_nodes.clear()


func _on_npc_caught(npc_id: String) -> void:
	if phase != Phase.ROLLING:
		return
	var cap := npc_id.to_upper()
	var src := npc_id
	_die(src, cap)


func _on_ghost_caught(take_id: int) -> void:
	if phase != Phase.ROLLING:
		return
	_die("take_%02d" % take_id, "TAKE %02d" % take_id)


func _die(source_id: String, source_label: String) -> void:
	phase = Phase.DEAD
	player.set_frozen(true)
	rig.add_shake(1.4)
	recorder.recording = false
	for n: Node in npcs:
		n.set_active(false)
	GameSession.takes.die(source_id)
	var text := "DIED TO " + source_label if Loc.language == "en" else "死于 " + source_label
	slate.play_die(text, GameSession.takes.take_index)
	Logger.info("die: %s (take %d)" % [source_label, GameSession.takes.take_index])


func _manual_cut() -> void:
	if phase != Phase.ROLLING:
		return
	phase = Phase.CUT
	player.set_frozen(true)
	recorder.recording = false
	GameSession.takes.manual_cut()
	slate.play_cut(GameSession.takes.take_index)
	Logger.info("manual cut (take %d)" % GameSession.takes.take_index)


func _on_slate_finished(kind: String) -> void:
	match kind:
		"roll":
			if phase == Phase.ROLLING:
				player.set_frozen(false)
				recorder.start()
				_update_hud()
		"die":
			phase = Phase.DEAD
			hud.set_hint("SPACE — RETAKE")
		"cut":
			phase = Phase.CUT
			hud.set_hint("SPACE — RETAKE")
		"out":
			pass


func _retake() -> void:
	if phase != Phase.DEAD and phase != Phase.CUT and phase != Phase.COMPLETE:
		return
	for n: Node in npcs:
		n.set_active(true)
	GameSession.case_state.on_retake()
	GameSession.takes.retake()
	_begin_take()


# --- play loop -----------------------------------------------------------

func _process(dt: float) -> void:
	GameSession.takes.tick(dt)
	if paused:
		return
	_update_hint()
	if debug_on:
		hud.set_debug(_debug_text())
	elif hud.debug_label.visible:
		hud.set_debug("")


func _update_hint() -> void:
	if phase == Phase.REPORT:
		return
	if phase != Phase.ROLLING:
		return
	var p: Vector3 = player.global_position
	var e := _nearest_evidence()
	if e != null:
		var meta: Dictionary = GameSession.case_state.evidence_meta(e.id)
		var label := Loc.t(meta.get("name", {}))
		if not e.seen:
			hud.set_hint("[E] LOOK — %s" % label)
		else:
			hud.set_hint("[E] TAKE — %s" % label)
		return
	var npc := _nearest_npc()
	if npc != null:
		hud.set_hint("[E] ASK — %s" % npc.display_name)
		return
	if _in_report_zone(p):
		hud.set_hint("[R] FILE REPORT")
		return
	hud.set_hint("")


func _nearest_evidence() -> Node:
	var best: Node = null
	var bd := 1e9
	for id: String in evidence_props:
		var prop: Node = evidence_props[id]
		if prop.taken:
			continue
		var d: float = prop.distance_to(player.global_position)
		if d <= EvidenceScript.REACH and d < bd:
			bd = d
			best = prop
	return best


func _nearest_npc() -> Node:
	var best: Node = null
	var bd := ASK_RANGE
	for n: Node in npcs:
		var d := Vector2(n.global_position.x - player.global_position.x,
			n.global_position.z - player.global_position.z).length()
		if d < bd:
			bd = d
			best = n
	return best


func _in_report_zone(p: Vector3) -> bool:
	return Vector2(p.x - report_pos.x, p.z - report_pos.z).length() <= report_radius


func _interact() -> void:
	if phase != Phase.ROLLING:
		return
	var e := _nearest_evidence()
	if e != null:
		var result: String = GameSession.case_state.inspect(e.id)
		if result == "taken":
			e.mark_taken()
			recorder.mark(GhostTrack.FLAG_INTERACT)
			hud.flash("TAKEN — %s" % Loc.t(GameSession.case_state.evidence_meta(e.id).get("name", {})))
			Logger.info("evidence taken: " + e.id)
		elif result == "seen":
			e.mark_seen()
			recorder.mark(GhostTrack.FLAG_INTERACT)
			var meta: Dictionary = GameSession.case_state.evidence_meta(e.id)
			hud.flash(Loc.t(meta.get("inspect", {})))
			Logger.info("evidence seen: " + e.id)
		_refresh_evidence()
		_commit_state()
		return

	var npc := _nearest_npc()
	if npc != null:
		var line: Dictionary = GameSession.case_state.ask(npc.npc_id)
		hud.flash("%s — %s" % [npc.display_name, Loc.t(line.get("text", {}))], 4.5)
		Logger.info("asked " + npc.npc_id)
		_commit_state()


# --- report --------------------------------------------------------------

func _open_report() -> void:
	if phase != Phase.ROLLING:
		return
	if not _in_report_zone(player.global_position):
		return
	if not GameSession.takes.begin_report():
		return
	phase = Phase.REPORT
	player.set_frozen(true)
	recorder.recording = false
	report_cursor = 0
	_render_report()


func _close_report() -> void:
	if phase != Phase.REPORT:
		return
	GameSession.takes.cancel_report()
	phase = Phase.ROLLING
	player.set_frozen(false)
	recorder.recording = true
	hud.set_case_lines(PackedStringArray())
	hud.set_hint("")


func _render_report() -> void:
	var cs = GameSession.case_state
	var lines := PackedStringArray()
	lines.append("REPORT — TAKE %02d" % GameSession.takes.take_index)
	lines.append("")
	var ids: Array = cs.evidence_ids()
	for i in ids.size():
		var id: String = ids[i]
		var mark := "[x]" if cs.is_attached(id) else "[ ]"
		var state := "-"
		if cs.is_taken(id):
			state = "SEIZED"
		elif cs.is_seen(id):
			state = "SEEN"
		var cursor := ">" if i == report_cursor else " "
		lines.append("%s %s %s  %s" % [cursor, mark, Loc.t(cs.evidence_meta(id).get("name", {})), state])
	lines.append("")
	lines.append("A/D move · E list/unlist")
	lines.append("1 FILE · 2 BURY · 3 REFRAME")
	lines.append("R close")
	hud.set_case_lines(lines)
	hud.set_hint("[1] FILE   [2] BURY   [3] REFRAME")


func _file(stance_idx: int) -> void:
	if phase != Phase.REPORT:
		return
	var cs = GameSession.case_state
	var stances: Array = cs.stance_ids()
	if stance_idx >= stances.size():
		return
	var stance_id: String = stances[stance_idx]
	var verdict: String = cs.verdict(stance_id)
	cs.stance = stance_id

	if not TERMINAL_VERDICTS.has(verdict):
		# A rejected report is not a lost take. The clerk hands it back, the
		# player keeps everything they have, and the take continues.
		hud.flash(Loc.t(cs.verdict_text(verdict)), 6.0)
		hud.set_hint("[1] FILE   [2] BURY   [3] REFRAME   [R] CLOSE")
		_render_report()
		Logger.info("report returned: %s -> %s" % [stance_id, verdict])
		return

	if not GameSession.takes.commit_report(stance_id, verdict):
		return
	phase = Phase.COMPLETE
	var text := Loc.t(cs.verdict_text(verdict))
	hud.flash(text, 6.0)
	hud.set_case_lines(PackedStringArray())
	hud.set_hint("SPACE — NEXT TAKE")
	hud.set_take(GameSession.takes.take_index, GameSession.ghost_count(), "COMPLETE")
	_finish_take()
	Logger.info("report filed: %s -> %s" % [stance_id, verdict])


func _finish_take() -> void:
	var track: Variant = recorder.stop()
	if track != null and track.size() >= 2:
		track.take_id = GameSession.takes.take_index
		GameSession.add_ghost(track)
	GameSession.save()


# --- buttons -------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		rig.mouse_look(event.relative.x)
		return

	if not (event is InputEventKey) or event.echo:
		return
	var key := event as InputEventKey
	if not key.pressed:
		return
	var code := key.physical_keycode

	if code == KEY_F2:
		GameSession.set_language(Loc.toggle_language())
		_refresh_evidence()
		hud.flash("LANG — " + Loc.language.to_upper())
		return
	if code == KEY_F3:
		debug_on = not debug_on
		hud.toggle_debug()
		return
	if code == KEY_F4:
		GameSession.load_latest()
		return

	if phase == Phase.REPORT:
		match code:
			KEY_1:
				_file(0)
			KEY_2:
				_file(1)
			KEY_3:
				_file(2)
			KEY_R, KEY_ESCAPE:
				_close_report()
			KEY_A, KEY_LEFT:
				report_cursor = maxi(0, report_cursor - 1)
				_render_report()
			KEY_D, KEY_RIGHT:
				report_cursor = mini(GameSession.case_state.evidence_ids().size() - 1, report_cursor + 1)
				_render_report()
			KEY_E:
				var ids: Array = GameSession.case_state.evidence_ids()
				if report_cursor >= 0 and report_cursor < ids.size():
					GameSession.case_state.toggle_attach(ids[report_cursor])
					_render_report()
		return

	match code:
		KEY_ESCAPE:
			_toggle_pause()
		KEY_C:
			_manual_cut()
		KEY_E:
			_interact()
		KEY_R:
			_open_report()
		KEY_SPACE:
			_retake()


func _toggle_pause() -> void:
	if phase != Phase.ROLLING and not paused:
		return
	paused = not paused
	player.set_frozen(paused)
	if paused:
		hud.flash("PAUSED", 9999.0)
		hud.set_hint("ESC — RESUME")
	else:
		hud.clear_banner()
		_update_hint()


# --- helpers -------------------------------------------------------------

func _refresh_evidence() -> void:
	for id: String in evidence_props:
		var prop: Node = evidence_props[id]
		if GameSession.case_state.is_taken(id):
			prop.mark_taken()
		elif GameSession.case_state.is_seen(id):
			prop.mark_seen()


func _commit_state() -> void:
	GameSession.save()


func _update_hud() -> void:
	hud.set_take(GameSession.takes.take_index, GameSession.ghost_count(), "ROLLING")


func _debug_text() -> String:
	var snap: Dictionary = rig.snapshot()
	var v: Vector3 = player.velocity
	return "\n".join(PackedStringArray([
		"FPS %d" % Engine.get_frames_per_second(),
		"POS %.2f %.2f" % [player.global_position.x, player.global_position.z],
		"FACING %.1f  YAW %.1f" % [rad_to_deg(player.facing), snap["yaw_deg"]],
		"ROLL %.2f  PITCH %.1f  D %.1f" % [snap["roll_deg"], snap["pitch_deg"], snap["distance"]],
		"SPEED %.2f  (intent %.2f)" % [player.speed_now(), player.intent().length()],
		"TAKE %02d  GHOSTS %d" % [GameSession.takes.take_index, GameSession.ghosts.size()],
		"PHASE %s" % GameSession.takes.state_name(),
		"REC %d samples" % recorder.sample_count(),
	]))
