extends Node
## Exists only in the two opt-in scenes (or headless synthetic QA). No global input hooks.
const Stream = preload("res://tools/trial_recorder.gd")
const Modes = preload("res://scripts/camera/roll_modes.gd")
var stream := Stream.new()
var synthetic := false
var _qa_focused := false
var _taken := false
var _scene
var _west_body: Node
const Build = preload("res://tools/trial_build.gd")
const Consent = preload("res://tools/trial_consent.gd")
var _ui: CanvasLayer
var _pending_id := ""
var _build: Dictionary = {}
var _live := false
var _condition: String:
	get: return "B" if _scene.route_paint else "A"

func _ready() -> void:
	# The operator must be able to stop recording even when gameplay is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_scene = get_parent()
	# RoomBuilder emits floor, then walls in map order. TURN_WALL was appended last.
	_west_body = _scene.get_node("Layout").get_child(_scene.map_data.walls.size()).get_node("Body")
	process_physics_priority = 100 # after body and rig
	get_window().focus_exited.connect(_focus_lost)
	if Build.enabled() and not synthetic:
		get_tree().paused = true
		_ui = Consent.new()
		add_child(_ui)
		_ui.agreed.connect(_agree)
		_ui.declined.connect(_decline)
	print("West trial not recording.")

func _agree() -> void:
	if not _pending_id.is_empty() or not _ui._panel.visible:
		return
	if not Stream.isolated_operator_dir(ProjectSettings.get_setting("application/config/use_custom_user_dir", false), ProjectSettings.get_setting("application/config/custom_user_dir_name", ""), OS.get_user_data_dir()):
		_ui.unavailable()
		return
	_build = Build.verified(_condition)
	if _build.is_empty():
		_ui.unavailable()
		return
	_pending_id = Crypto.new().generate_random_bytes(16).hex_encode()
	if not Stream.valid_session(_pending_id):
		_pending_id = ""
		_ui.unavailable()
		return
	_ui.waiting(_pending_id)

func _decline() -> void:
	_pending_id = ""
	_build.clear()
	get_tree().paused = false
	_ui.play("无采集试玩  /  Not recording")
	set_process_unhandled_input(false)
	set_physics_process(false)

func _process(_dt: float) -> void:
	if _live and not stream.active():
		_live = false
		_ui.play("记录已结束  /  Recording ended\n" + stream.session)

func focused() -> bool:
	return _qa_focused if synthetic else get_window().has_focus()

func _focus_lost() -> void:
	stream.finish("focus_lost", _taken)

func _unhandled_input(event: InputEvent) -> void:
	if not focused() or not event is InputEventKey or event.echo:
		return
	var e := event as InputEventKey
	var ui_start := _ui != null and not _pending_id.is_empty() and e.physical_keycode == KEY_F8
	if _ui != null and not stream.active() and not ui_start:
		return
	if not ui_start and get_tree().paused and e.physical_keycode not in [KEY_F9, KEY_F10]:
		return
	if e.physical_keycode == KEY_F8 and e.pressed and stream.session.is_empty():
		# A first exposure must start at spawn, after the opening slate, on Take 01.
		var pos: Vector3 = _scene.player.global_position
		var spawn: Vector3 = _scene.spawn_pos
		# UI holds the whole tree at its untouched opening slate until F8.
		if (not ui_start and _scene.player.frozen) or GameSession.takes.take_index != 1 or Vector2(pos.x - spawn.x, pos.z - spawn.z).length() > 0.05:
			return
		var rig = _scene.rig
		if rig.roll_mode != Modes.ORBIT:
			print("West trial not started: select ORBIT before recording.")
			return
		var config := {"protocol":"B3-B/1", "engine":Engine.get_version_info().string,
			"project_config_sha256":_build.get("project_config_sha256", "") if ui_start else FileAccess.get_sha256("res://project.godot"),
			"map_sha256":FileAccess.get_sha256(_scene.MAP_PATH), "case_sha256":FileAccess.get_sha256(_scene.CASE_PATH),
			"physics_hz":Engine.physics_ticks_per_second, "wall_xz":_scene.TURN_WALL,
			"paint_xz":_scene.PAINT if _scene.route_paint else [], "orbit_deg_s":Modes.ORBIT_W_DEG,
			"reduce_motion":rig.reduce_motion, "roll_scale":rig.roll_scale, "initial_camera":rig.snapshot()}
		config.merge(_build, true)
		var args := PackedStringArray([Stream.CONSENT]) if synthetic or ui_start else OS.get_cmdline_user_args()
		if stream.begin(args, _condition, config, synthetic, _pending_id):
			print("West trial recording: ", stream.session)
			if ui_start:
				_pending_id = ""
				_live = true
				get_tree().paused = false
				_ui.play("记录中  /  Recording   ·   F9 提示 / Help   ·   F10 停止 / Stop\n" + stream.session)
		elif ui_start:
			_pending_id = ""
			_ui.unavailable()
		return
	if not stream.active():
		return
	if e.pressed and e.physical_keycode in [KEY_F9, KEY_F10]:
		stream.finish("hint_required" if e.physical_keycode == KEY_F9 else "operator_stop", _taken)
	else:
		stream.key(e)

func check_collection() -> void:
	if not stream.active() or not focused():
		return
	_taken = _scene.evidence_props.script_page.taken
	if _taken:
		stream.finish("collected", true)

func _physics_process(_delta: float) -> void:
	if not stream.active():
		return
	if not focused():
		_focus_lost()
		return
	if get_tree().paused:
		stream.check_deadline()
		return
	var body: CharacterBody3D = _scene.player
	var west := false
	for i in body.get_slide_collision_count():
		if body.get_slide_collision(i).get_collider() == _west_body:
			west = true
	var p := body.global_position
	stream.append("sample", {"x":p.x, "z":p.z, "facing_rad":body.get("facing"),
		"yaw_rad":_scene.rig.yaw, "roll_rad":_scene.rig.roll, "roll_mode":_scene.rig.roll_mode,
		"wall_contact":west, "frozen":body.get("frozen"), "phase":_scene.phase,
		"page_seen":_scene.evidence_props.script_page.seen, "take":GameSession.takes.take_index})

func _exit_tree() -> void:
	stream.finish("scene_exit", _taken)
