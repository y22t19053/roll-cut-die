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
const RollModes = preload("res://scripts/camera/roll_modes.gd")
const NpcScript = preload("res://scripts/npc/npc_patrol.gd")
const GhostActorScript = preload("res://scripts/ghost/ghost_actor.gd")
const GhostRecorderScript = preload("res://scripts/ghost/ghost_recorder.gd")
const GhostTrack = preload("res://scripts/ghost/ghost_track.gd")
const EvidenceScript = preload("res://scripts/case/evidence_prop.gd")
const SlateScript = preload("res://scripts/ui/slate_ui.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const CutPanelScript = preload("res://scripts/ui/cut_panel.gd")
const MarkBeaconScript = preload("res://scripts/ui/mark_beacon.gd")
const PauseMenuScript = preload("res://scripts/ui/pause_menu.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const MarkLedger = preload("res://scripts/take/mark_ledger.gd")
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
var cut_panel: CanvasLayer
var preview_rig: Node3D
var preview_cam: Camera3D
var ghost_stills: Array[Node3D] = []
var npc_stills: Array[Node3D] = []
var evidence_stills := {}
var player_still: Node3D

## Personal anchors and the system checkpoint of the current timeline.
var marks = MarkLedger.new()
var beacons: Array = []
## Row selected in the CUT panel, -1 = free view.
var cut_cursor := -1

var spawn_pos := Vector3(2.0, 0.05, 16.6)
var report_pos := Vector3.ZERO
var report_radius := 1.5

var phase := Phase.ROLLING
var paused := false
var debug_on := false
var report_cursor := 0

var _occluder: Node = null
## Physics seconds the NPCs and ghosts have run this take. A CUT puts the world
## back on the chosen point's clock, so this must count exactly what they count.
var _world_t := 0.0
var _world_running := false
## Point the current take resumes from; consumed when the ROLL slate releases.
var _resume_point: Dictionary = {}

var pause_menu: CanvasLayer
## Everything on screen that is worded is kept as a Callable that produces the
## words, so a language switch re-renders it in place without touching state.
var _status_fn := Callable()
var _death_fn := Callable()
var _hint_fn := Callable()
var _banner_fn := Callable()


func _ready() -> void:
	InputSetup.ensure_actions()
	var problems := InputSetup.verify_actions()
	for p: String in problems:
		Logger.error("input: " + p)

	if not _load_map():
		_show_fatal()
		return
	_load_case()
	# New Game / Continue from the title screen; take 1 on a direct launch.
	var first_take: int = GameSession.consume_start_request()
	_build_world()
	_build_actors()
	_build_ui()
	var pause_input := preload("res://scripts/ui/pause_input.gd").new()
	add_child(pause_input)
	pause_input.resume_requested.connect(_on_pause_escape)
	pause_input.language_requested.connect(_toggle_language)
	GameSession.language_changed.connect(_on_language_changed)
	GameSession.settings_changed.connect(_on_setting_changed)

	GameSession.takes.start_take(first_take)
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


func _map_source() -> Variant:
	return _read_json(MAP_PATH)


func _load_map() -> bool:
	var parsed: Variant = _map_source()
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
		prop.setup(eid, Vector3(float(pos_arr[0]), 0.0, float(pos_arr[1])),
			GameSession.case_state.evidence_meta(eid))
		add_child(prop) # _ready builds the label from this evidence's metadata.
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

	cut_panel = CutPanelScript.new()
	cut_panel.name = "CutPanel"
	add_child(cut_panel)

	pause_menu = PauseMenuScript.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	pause_menu.resume_requested.connect(_toggle_pause)
	pause_menu.to_title_requested.connect(_quit_to_title)
	pause_menu.quit_requested.connect(_quit_game)

	# Preview camera for the CUT panel: same geometry as CameraRig, parked on a
	# recorded point. Only `current` moves between the two cameras.
	preview_rig = Node3D.new()
	preview_rig.name = "PreviewRig"
	add_child(preview_rig)
	preview_cam = Camera3D.new()
	preview_cam.name = "Camera"
	preview_cam.fov = CameraMath.FOV
	preview_cam.near = 0.05
	preview_cam.far = 250.0
	preview_cam.cull_mask &= ~GhostActorScript.LIVE_LAYER
	preview_cam.current = false
	preview_rig.add_child(preview_cam)
	GameSession.ghosts_changed.connect(hud.set_ghost_count)

	_set_roll_mode(GameSession.get_roll_mode())


## One switch for all three places the mode lives: camera, body, HUD.
func _set_roll_mode(m: int) -> void:
	m = GameSession.set_roll_mode(m)
	rig.set_roll_mode(m)
	player.roll_mode = m
	hud.set_roll_mode(RollModes.mode_name(m))
	Logger.info("roll mode -> %s" % RollModes.mode_name(m))


# --- take flow -----------------------------------------------------------

func _begin_take() -> void:
	phase = Phase.ROLLING
	var idx: int = GameSession.takes.take_index
	_clear_ghosts()
	_spawn_ghosts()
	# Experimental inherited scenes keep their authored spawn and timing protocol.
	var studio := scene_file_path == "res://scenes/main/main.tscn"
	var entrance := spawn_pos
	if studio:
		var selected: Variant = preload("res://scripts/world/safe_entrance.gd").choose(map_data,spawn_pos,GameSession.ghosts)
		if selected == null:
			Logger.error("no clear entrance for the opening tracks")
			_freeze_world()
			player.set_frozen(true)
			set_process_unhandled_input(false)
			_show_fatal()
			return
		entrance = selected
		for g: Node in ghost_nodes:
			g.playing = false
			g.global_position = g.track.sample_at(0).position
	for n: Node in npcs:
		n.reset_phase()
		n.set_active(not studio)
	player.teleport(entrance, 0.0)
	player.set_frozen(true)
	_refresh_evidence()
	recorder.setup(player, rig, idx)
	recorder.recording = false
	if not studio:
		recorder.start()
	_world_t = 0.0
	_world_running = not studio
	_resume_point = {}
	marks.clear()
	marks.checkpoint = _snapshot()
	_sync_beacons()
	slate.play_roll(idx)
	_update_hud()
	_death_fn = Callable()
	hud.clear_death()
	_set_hint(Callable())


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
	_die(npc_id, npc_id.to_upper(), _npc_label_fn(npc_id))


func _on_ghost_caught(take_id: int) -> void:
	if phase != Phase.ROLLING:
		return
	_die("take_%02d" % take_id, "TAKE %02d" % take_id,
		func() -> String: return Loc.ui("source.take", [take_id]))


## `source_label` is the log's wording; `label_fn` words the cause on screen in
## whichever language is active when it is drawn.
func _die(source_id: String, source_label: String, label_fn := Callable()) -> void:
	phase = Phase.DEAD
	player.set_frozen(true)
	rig.add_shake(1.4)
	recorder.recording = false
	_world_running = false
	for n: Node in npcs:
		n.set_active(false)
	GameSession.takes.die(source_id)
	var who := label_fn
	if not who.is_valid():
		who = func() -> String: return source_label
	_set_status(func() -> String: return Loc.ui("status.died", [who.call()]))
	_death_fn = func() -> String: return Loc.ui("death.text", [who.call()])
	hud.show_death(_death_fn.call())
	slate.play_die(GameSession.takes.take_index)
	Logger.info("die: %s (take %d)" % [source_label, GameSession.takes.take_index])


## An NPC's on-screen name, upper-cased, in the language active at draw time.
func _npc_label_fn(npc_id: String) -> Callable:
	return func() -> String:
		var t := Loc.t(GameSession.case_state.npc_meta(npc_id).get("name", {})).to_upper()
		return t if not t.is_empty() else npc_id.to_upper()


## C: freeze the world and open the timeline once the slate has clapped.
## Refused while paused (bible §6.1) and while the ROLL slate still holds the
## player, so a CUT always starts from a take that was actually rolling.
func _manual_cut() -> void:
	if phase != Phase.ROLLING or paused or bool(player.get("frozen")):
		return
	phase = Phase.CUT
	rig.set_physics_process(false) # Keep the last live shot fixed while the editor is open.
	player.set_frozen(true)
	recorder.recording = false
	_freeze_world()
	GameSession.takes.manual_cut()
	_set_status(func() -> String: return Loc.ui("status.cut"))
	_set_hint(Callable())
	slate.play_cut(GameSession.takes.take_index)
	Logger.info("manual cut (take %d)" % GameSession.takes.take_index)


func _freeze_world() -> void:
	_world_running = false
	for n: Node in npcs:
		n.set_active(false)
	for g: Node in ghost_nodes:
		g.playing = false


# --- MARK ----------------------------------------------------------------

## Everything a CUT needs to put the take back on this instant.
func _snapshot() -> Dictionary:
	var frames := {}
	for actor in ghost_nodes:
		frames[actor.take_id] = actor.still_frame()
	var npc_frames := {}
	var npc_phases := {}
	for actor in npcs:
		npc_frames[actor.npc_id] = actor.still_frame()
		npc_phases[actor.npc_id] = actor.mark_phase()
	var evidence_frames := {}
	for id in evidence_props:
		evidence_frames[id] = evidence_props[id].still_frame()
	return {
		"evidence_frames": evidence_frames,
		"npc_frames": npc_frames,
		"npc_phases": npc_phases,
		"ghost_frames": frames,
		"kind": "checkpoint",
		"no": 0,
		"take": GameSession.takes.take_index,
		"pos": player.global_position,
		"velocity": player.velocity,
		"facing": float(player.facing),
		"cam_yaw": float(rig.yaw),
		"cam_roll": float(rig.roll),
		"cam_motion": rig.mark_motion(),
		"evidence": GameSession.case_state.evidence.duplicate(true),
		"time": GameSession.takes.elapsed,
		"world_t": _world_t,
		"rec_t": recorder.elapsed(),
	}


func _mark() -> void:
	if phase != Phase.ROLLING or paused or bool(player.get("frozen")):
		return
	if not marks.add(_snapshot()):
		var full := [marks.count(), marks.capacity]
		_flash(func() -> String: return Loc.ui("flash.marks_full", full))
		return
	_sync_beacons()
	var used := [marks.count(), marks.capacity]
	_flash(func() -> String: return Loc.ui("flash.mark", used), 1.4)
	Logger.info("mark %d at %.2f %.2f (take %d)" % [marks.count(), player.global_position.x,
		player.global_position.z, GameSession.takes.take_index])


func _sync_beacons() -> void:
	for b: Node in beacons:
		b.queue_free()
	beacons.clear()
	for p: Dictionary in marks.marks:
		var b = MarkBeaconScript.new()
		b.name = "Mark_%d" % int(p["no"])
		add_child(b)
		b.setup(int(p["no"]), p["pos"])
		beacons.append(b)
	hud.set_marks(marks.count(), marks.capacity)


# --- CUT panel -----------------------------------------------------------

func _open_cut_panel() -> void:
	cut_cursor = -1
	cut_panel.open(_cut_title(), _cut_rows(), _cut_footer())
	_set_hint(func() -> String: return Loc.ui("hint.cut_panel"))


func _cut_title() -> String:
	var t = GameSession.takes
	return Loc.ui("cut.title", [t.take_index, t.retake_stock, marks.count(), marks.capacity])


func _cut_rows() -> PackedStringArray:
	var rows := PackedStringArray()
	for p: Dictionary in marks.points():
		rows.append(_describe_point(p))
	return rows


## MarkLedger.describe, worded in the active language (identical in English).
func _describe_point(p: Dictionary) -> String:
	var ev := MarkLedger.evidence_counts(p.get("evidence", {}))
	var pos: Vector3 = p.get("pos", Vector3.ZERO)
	return Loc.ui("cut.row", [_point_label(p), int(p.get("take", 0)),
		MarkLedger.clock(float(p.get("time", 0.0))), ev.x, ev.y, pos.x, pos.z])


func _point_label(p: Dictionary) -> String:
	if str(p.get("kind", "")) == "mark":
		return Loc.ui("point.mark", [int(p.get("no", 0))])
	return Loc.ui("point.start")


func _cut_footer() -> String:
	var pts: Array = marks.points()
	if cut_cursor < 0 or cut_cursor >= pts.size():
		return Loc.ui("cut.free")
	var p: Dictionary = pts[cut_cursor]
	return Loc.ui("cut.preview", [_point_label(p), rad_to_deg(float(p["facing"])),
		rad_to_deg(float(p["cam_yaw"])), rad_to_deg(float(p["cam_roll"])), float(p["world_t"])])


func _cut_input(code: int) -> void:
	if not cut_panel.is_open():
		return
	var n: int = marks.points().size()
	match code:
		KEY_UP:
			_select_point(n - 1 if cut_cursor < 0 else maxi(cut_cursor - 1, 0))
		KEY_DOWN:
			_select_point(0 if cut_cursor < 0 else mini(cut_cursor + 1, n - 1))
		KEY_ESCAPE:
			_select_point(-1)
		KEY_SPACE:
			if cut_cursor >= 0:
				_cut_to(marks.points()[cut_cursor])
			else:
				_flash(func() -> String: return Loc.ui("flash.pick_first"), 1.4)
		_:
			if code >= KEY_1 and code <= KEY_9 and code - KEY_1 < n:
				_select_point(code - KEY_1)


## Real preview: the camera goes where the point's camera was. Player, world
## and case state are not touched.
func _clear_preview_stills() -> void:
	if is_instance_valid(player_still):
		player_still.hide()
		player_still.queue_free()
		player_still = null
	for still in ghost_stills + npc_stills + evidence_stills.values():
		still.hide()
		still.queue_free()
	ghost_stills.clear()
	npc_stills.clear()
	evidence_stills.clear()

func _select_point(i: int) -> void:
	_clear_preview_stills()
	var pts: Array = marks.points()
	cut_cursor = i if i >= 0 and i < pts.size() else -1
	cut_panel.set_selected(cut_cursor)
	cut_panel.set_footer(_cut_footer())
	if cut_cursor < 0:
		rig.camera.current = true
		return
	var p: Dictionary = pts[cut_cursor]
	player_still = player.make_still(to_local(p.pos), p.facing)
	add_child(player_still)
	var ev_frames: Dictionary = p.get("evidence_frames", {})
	for id in ev_frames:
		var frame: Dictionary = ev_frames[id]
		if frame.visible and evidence_props.has(id):
			var still: Node3D = evidence_props[id].make_still(frame)
			add_child(still)
			still.global_transform = frame.pose
			evidence_stills[id] = still
	var npc_frames: Dictionary = p.get("npc_frames", {})
	for actor in npcs:
		if npc_frames.has(actor.npc_id):
			var frame: Dictionary = npc_frames[actor.npc_id]
			var still: Node3D = actor.make_still(frame)
			add_child(still)
			still.global_transform = frame.pose
			npc_stills.append(still)
	var frames: Dictionary = p.get("ghost_frames", {})
	for actor in ghost_nodes:
		if frames.has(actor.take_id):
			var frame: Dictionary = frames[actor.take_id]
			var still: Node3D = actor.make_still(frame)
			add_child(still)
			still.global_transform = frame.pose
			ghost_stills.append(still)
	preview_rig.global_position = (p["pos"] as Vector3) + Vector3.UP * CameraMath.FOCUS_HEIGHT
	preview_rig.rotation = Vector3(0.0, float(p["cam_yaw"]), 0.0)
	preview_cam.position = CameraMath.camera_offset(rig.pitch_deg, rig.distance)
	preview_cam.rotation = CameraMath.camera_euler(rig.pitch_deg, float(p["cam_roll"]))
	preview_cam.current = true


## SPACE in the panel: the cut take becomes an outtake and the next take starts
## on the chosen point — place, facing, camera, evidence and world clock.
## Everything recorded after that point rolls back; the Retake stock does not.
func _cut_to(p: Dictionary) -> void:
	var point := p.duplicate(true)
	var t = GameSession.takes
	var idx: int = t.resume_after_cut(MarkLedger.label(point), float(point["time"]))
	if idx < 0:
		return
	_clear_preview_stills()
	cut_panel.close()
	cut_cursor = -1
	rig.camera.current = true

	GameSession.case_state.evidence = (point["evidence"] as Dictionary).duplicate(true)
	if str(point["kind"]) == "mark":
		marks.keep_through(int(point["no"]))
	else:
		marks.clear()
	_sync_beacons()
	_refresh_evidence()

	var wt := float(point["world_t"])
	_world_t = wt
	_world_running = false
	_clear_ghosts()
	_spawn_ghosts()
	for g: Node in ghost_nodes:
		g.playing = false
		g.playhead = wt
		g.global_position = g.track.sample_at(wt)["position"]
	# Restore the leg and remaining wait, without simulating the entire take again.
	for n: Node in npcs:
		n.set_active(false)
		n.restore_phase(point.npc_phases[n.npc_id])

	player.teleport(point["pos"], float(point["facing"]))
	player.set_frozen(true)
	rig.setup(player)
	rig.restore_mark_motion(point)
	rig.set_physics_process(false) # Do not consume the saved momentum behind the slate.

	_resume_point = point
	phase = Phase.ROLLING
	slate.play_roll(idx)
	_update_hud()
	_set_hint(Callable())
	Logger.info("cut to %s -> take %d (retakes %d)" % [MarkLedger.label(point), idx, t.retake_stock])


## The ROLL slate after a CUT has clapped: world, player and recorder start
## together on the point's clock.
func _release_resumed() -> void:
	var p := _resume_point
	_resume_point = {}
	rig.set_physics_process(true)
	player.set_frozen(false)
	player.velocity = p.get("velocity", Vector3.ZERO) # Restore on release, never during the slate.
	for n: Node in npcs:
		n.set_active(true)
	for g: Node in ghost_nodes:
		if not g.spent:
			g.playing = true
	recorder.resume_from(float(p["rec_t"]), GameSession.takes.take_index)
	_world_running = true
	_update_hud()


func _on_slate_finished(kind: String) -> void:
	match kind:
		"roll":
			if phase == Phase.ROLLING:
				if not _resume_point.is_empty():
					_release_resumed()
					return
				if not _world_running:
					for n: Node in npcs:
						n.set_active(true)
					for g: Node in ghost_nodes:
						g.playing = true
					_world_running = true
				player.set_frozen(false)
				recorder.start()
				marks.checkpoint = _snapshot()
				_update_hud()
		"die":
			phase = Phase.DEAD
			_set_hint(func() -> String: return Loc.ui("hint.retake"))
		"cut":
			if phase == Phase.CUT:
				_open_cut_panel()
		"out":
			pass


func _retake() -> void:
	if phase != Phase.DEAD and phase != Phase.COMPLETE:
		return
	for n: Node in npcs:
		n.set_active(true)
	GameSession.case_state.on_retake()
	GameSession.takes.retake()
	_begin_take()


# --- play loop -----------------------------------------------------------

func _physics_process(dt: float) -> void:
	if _world_running:
		_world_t += dt


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
		_show_hint(Loc.ui("hint.look" if not e.seen else "hint.take", [label]))
		return
	var npc := _nearest_npc()
	if npc != null:
		_show_hint(Loc.ui("hint.ask", [npc.display_name]))
		return
	if _in_report_zone(p):
		_show_hint(Loc.ui("hint.file_report"))
		return
	_show_hint("")


## Per-frame proximity prompt: worded fresh every frame, so it needs no stored
## Callable, and any stored one is dropped.
func _show_hint(text: String) -> void:
	_hint_fn = Callable()
	hud.set_hint(text)


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
			var name_node: Variant = GameSession.case_state.evidence_meta(e.id).get("name", {})
			_flash(func() -> String: return Loc.ui("flash.taken", [Loc.t(name_node)]))
			Logger.info("evidence taken: " + e.id)
		elif result == "seen":
			e.mark_seen()
			recorder.mark(GhostTrack.FLAG_INTERACT)
			var meta: Dictionary = GameSession.case_state.evidence_meta(e.id)
			var inspect_node: Variant = meta.get("inspect", {})
			_flash(func() -> String: return Loc.t(inspect_node))
			Logger.info("evidence seen: " + e.id)
		_refresh_evidence()
		_commit_state()
		return

	var npc := _nearest_npc()
	if npc != null:
		var line: Dictionary = GameSession.case_state.ask(npc.npc_id)
		var who := _npc_label_fn(str(npc.npc_id))
		var said: Variant = line.get("text", {})
		_flash(func() -> String: return Loc.ui("flash.said", [who.call(), Loc.t(said)]), 4.5)
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
	_set_hint(Callable())


func _render_report() -> void:
	var cs = GameSession.case_state
	var lines := PackedStringArray()
	lines.append(Loc.ui("report.title", [GameSession.takes.take_index]))
	lines.append("")
	var ids: Array = cs.evidence_ids()
	for i in ids.size():
		var id: String = ids[i]
		var mark := "[x]" if cs.is_attached(id) else "[ ]"
		var state := "-"
		if cs.is_taken(id):
			state = Loc.ui("report.seized")
		elif cs.is_seen(id):
			state = Loc.ui("report.seen")
		var cursor := ">" if i == report_cursor else " "
		lines.append("%s %s %s  %s" % [cursor, mark, Loc.t(cs.evidence_meta(id).get("name", {})), state])
	lines.append("")
	lines.append(Loc.ui("report.help_move"))
	lines.append(Loc.ui("report.help_file"))
	lines.append(Loc.ui("report.help_close"))
	hud.set_case_lines(lines)
	_set_hint(func() -> String: return Loc.ui("hint.report"))


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
		var returned: Dictionary = cs.verdict_text(verdict)
		_flash(func() -> String: return Loc.t(returned), 6.0)
		_render_report()
		_set_hint(func() -> String: return Loc.ui("hint.report_returned"))
		Logger.info("report returned: %s -> %s" % [stance_id, verdict])
		return

	if not GameSession.takes.commit_report(stance_id, verdict):
		return
	phase = Phase.COMPLETE
	var verdict_node: Dictionary = cs.verdict_text(verdict)
	_flash(func() -> String: return Loc.t(verdict_node), 6.0)
	hud.set_case_lines(PackedStringArray())
	_set_hint(func() -> String: return Loc.ui("hint.next_take"))
	_set_status(func() -> String: return Loc.ui("status.complete"))
	_finish_take()
	Logger.info("report filed: %s -> %s" % [stance_id, verdict])


func _finish_take() -> void:
	var track: Variant = recorder.stop()
	if track != null and track.size() >= 2:
		track.take_id = GameSession.takes.take_index
		GameSession.add_ghost(track)
	_commit_state()


# --- buttons -------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if phase == Phase.ROLLING and not paused and not player.frozen:
			rig.mouse_look(event.relative.x)
		return

	if not (event is InputEventKey) or event.echo:
		return
	var key := event as InputEventKey
	if not key.pressed:
		return
	var code := key.physical_keycode

	# F2/F3/F4 already belong to language/debug/load (InputSetup), so the ROLL
	# scheme gets F1 to cycle and F5/F6/F7 to pick directly.
	match code:
		KEY_F1:
			_set_roll_mode(GameSession.get_roll_mode() + 1)
			return
		KEY_F5:
			_set_roll_mode(RollModes.CHASE)
			return
		KEY_F6:
			_set_roll_mode(RollModes.SNAP)
			return
		KEY_F7:
			_set_roll_mode(RollModes.ORBIT)
			return

	if code == KEY_F2:
		_toggle_language()
		return
	if code == KEY_F3:
		debug_on = not debug_on
		hud.toggle_debug()
		return
	if code == KEY_F4:
		_load_latest_state()
		return

	if phase == Phase.CUT:
		# ESC in free view (nothing to deselect) opens the menu instead.
		if code == KEY_ESCAPE and cut_panel.is_open() and cut_cursor < 0:
			_toggle_pause()
			return
		_cut_input(code)
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
		KEY_M:
			_mark()
		KEY_E:
			_interact()
		KEY_R:
			_open_report()
		KEY_SPACE:
			_retake()


func _toggle_pause() -> void:
	if not paused and not _can_pause():
		return
	paused = not paused
	get_tree().paused = paused
	if paused:
		hud.set_hint(Loc.ui("hint.paused"))
		pause_menu.open()
	else:
		pause_menu.close()
		_restore_hint()


## The menu opens whenever no slate is holding a live take: while rolling
## (not behind the ROLL slate), after a death, after a filed report, and from
## the CUT panel's free view. The rules for C and MARK are unchanged: both
## already refuse while paused.
func _can_pause() -> bool:
	match phase:
		Phase.ROLLING:
			return not player.frozen
		Phase.DEAD, Phase.COMPLETE:
			return true
		Phase.CUT:
			return cut_panel.is_open()
	return false


## ESC while the tree is paused: back out of a sub-screen, else resume.
func _on_pause_escape() -> void:
	if pause_menu != null and pause_menu.is_open() and pause_menu.back():
		return
	_toggle_pause()


func _quit_to_title() -> void:
	if not ResourceLoader.exists(GameSession.TITLE_SCENE):
		Logger.error("title scene missing: " + GameSession.TITLE_SCENE)
		_quit_game()
		return
	# Leaving abandons the take in progress. Nothing is written: the last save
	# (made at the last interaction or report) is what Continue offers.
	paused = false
	get_tree().paused = false
	Logger.info("quit to title (take %d)" % GameSession.takes.take_index)
	get_tree().change_scene_to_file(GameSession.TITLE_SCENE)


func _quit_game() -> void:
	Logger.info("quit from pause menu")
	get_tree().quit()


# --- language & settings -------------------------------------------------

func _toggle_language() -> void:
	GameSession.set_language("zh" if Loc.language == "en" else "en")
	_flash(func() -> String: return Loc.ui("flash.lang"))


## Every worded thing re-renders from its source; no game state moves.
func _on_language_changed(_lang: String) -> void:
	for prop in evidence_props.values():
		prop.refresh_language()
	for npc in npcs:
		npc.display_name = _npc_label_fn(str(npc.npc_id)).call()
	_refresh_evidence()
	hud.relocalize()
	_render_status()
	if _death_fn.is_valid() and hud.death_label.visible:
		hud.show_death(_death_fn.call())
	if _banner_fn.is_valid():
		hud.retext_banner(_banner_fn.call())
	if phase == Phase.REPORT:
		_render_report()
	if phase == Phase.CUT and cut_panel.is_open():
		cut_panel.retext(_cut_title(), _cut_rows(), _cut_footer())
	slate.relocalize()
	if paused:
		hud.set_hint(Loc.ui("hint.paused"))
		pause_menu.relocalize()
	else:
		_restore_hint()


func _on_setting_changed(key: String, value: Variant) -> void:
	match key:
		"reduce_motion":
			rig.reduce_motion = bool(value)
		"roll_scale":
			rig.roll_scale = float(value)
		"mouse_sensitivity":
			rig.mouse_sensitivity = float(value)


# --- worded read-outs ----------------------------------------------------

func _set_status(fn: Callable) -> void:
	_status_fn = fn
	_render_status()


func _render_status() -> void:
	var text := Loc.ui("status.rolling")
	if _status_fn.is_valid():
		text = _status_fn.call()
	hud.set_take(GameSession.takes.take_index, GameSession.ghost_count(), text)


func _set_hint(fn: Callable) -> void:
	_hint_fn = fn
	hud.set_hint(fn.call() if fn.is_valid() else "")


func _restore_hint() -> void:
	if phase == Phase.ROLLING:
		_update_hint()
	else:
		hud.set_hint(_hint_fn.call() if _hint_fn.is_valid() else "")


func _flash(fn: Callable, seconds: float = 2.2) -> void:
	_banner_fn = fn
	hud.flash(fn.call(), seconds)


## The studio could not be built (bad map data). Say so instead of leaving a
## black window, and offer the only useful ways out.
func _show_fatal() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Fatal"
	layer.layer = 100
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var p := UiKit.panel()
	UiKit.centered(root).add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	p.add_child(box)
	box.add_child(UiKit.label(Loc.ui("error.scene"), 22))
	if ResourceLoader.exists(GameSession.TITLE_SCENE):
		box.add_child(UiKit.button(Loc.ui("menu.to_title"), _leave_to_title_now))
	box.add_child(UiKit.button(Loc.ui("menu.quit"), _quit_game))


func _leave_to_title_now() -> void:
	get_tree().change_scene_to_file(GameSession.TITLE_SCENE)


# --- helpers -------------------------------------------------------------

## Props follow the case both ways: a retake or a CUT can un-see and un-take.
func _refresh_evidence() -> void:
	for id: String in evidence_props:
		var prop: Node = evidence_props[id]
		var taken: bool = GameSession.case_state.is_taken(id)
		var seen: bool = GameSession.case_state.is_seen(id)
		prop.taken = taken
		prop.seen = seen
		prop.visible = not taken
		var ring: Node3D = prop.get_node_or_null("Marker/Ring")
		if ring != null:
			ring.visible = not seen


func _commit_state() -> void:
	GameSession.save()


func _load_latest_state() -> void:
	GameSession.load_latest()


func _update_hud() -> void:
	_set_status(Callable())


func _debug_text() -> String:
	var snap: Dictionary = rig.snapshot()
	var v: Vector3 = player.velocity
	return "\n".join(PackedStringArray([
		"FPS %d  ROLL %s" % [Engine.get_frames_per_second(), snap["mode"]],
		"POS %.2f %.2f" % [player.global_position.x, player.global_position.z],
		"FACING %.1f  YAW %.1f" % [rad_to_deg(player.facing), snap["yaw_deg"]],
		"ROLL %.2f  PITCH %.1f  D %.1f" % [snap["roll_deg"], snap["pitch_deg"], snap["distance"]],
		"SPEED %.2f  (intent %.2f)" % [player.speed_now(), player.intent().length()],
		"TAKE %02d  GHOSTS %d" % [GameSession.takes.take_index, GameSession.ghosts.size()],
		"PHASE %s" % GameSession.takes.state_name(),
		"REC %d samples  %.1f s" % [recorder.sample_count(), recorder.elapsed()],
		"WORLD T %.1f  MARK %d/%d" % [_world_t, marks.count(), marks.capacity],
	]))
