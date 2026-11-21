extends Node3D
## Each leg is a real recording. Geometry and supplies belong to the whole run;
## only a bookmark made in the current leg may restore that leg's progress.
const Player = preload("res://scripts/player/player.gd")
const Rig = preload("res://scripts/camera/camera_rig.gd")
const Orbit = preload("res://scripts/camera/roll_modes.gd").ORBIT
const Track = preload("res://scripts/ghost/ghost_track.gd")
const Ghost = preload("res://scripts/ghost/ghost_actor.gd")
const Rules = preload("res://scripts/relay/relay_rules.gd")
const Splice = preload("res://scripts/relay/safety_splice.gd")
const Loc = preload("res://scripts/core/loc.gd")
const MarkBeacon = preload("res://scripts/ui/mark_beacon.gd")
const CameraMath = preload("res://scripts/camera/camera_math.gd")
const SlateUI = preload("res://scripts/ui/slate_ui.gd")
const MODULES := 5
const KINDS := ["s", "h", "u", "l", "n", "x"]
const TOUCH := 0.77
const GRACE := 0.75
const PASSES := 4
## The projection a MARK leaves: the colour of the film, never the paint of the
## set. Alpha stays low so a MARK can never be mistaken for an obstacle.
const STILL_INK := Color(0.55, 0.95, 0.85)
const STILL_ALPHA := 0.30
const STILL_FADE := 0.28
var room_pass := 0
var room_track_start := 0
var cards: Array = []
var desk: CanvasLayer
var slate: CanvasLayer
var score: Node

enum Mode { PLAY, PICK, CUT, DONE, LOST, ITEM }
var phase := Mode.PLAY
var player := Player.new()
var rig := Rig.new()
var segments: Array[Dictionary] = []
var route := PackedVector3Array()
var cursor := 0
var returning := false
var tracks: Array = []
var anchors: Array[Dictionary] = []
var last_anchor := -1
var deaths := 0
var difficulty := Rules.selected_mode
var forced_cut := false
var splice := Splice.new()
var active_clock := 0.0
var mark_stock := Rules.mark_budget(difficulty)
var cut_stock := Rules.cut_budget(difficulty)
var live = Track.new()
var elapsed := 0.0
var grace := 0.0
var _actors: Array = []
var _selected := 0
var _preview_rig := Node3D.new()
var _preview_camera := Camera3D.new()
var _preview_still: Node3D
var _preview_ghosts: Array[Node3D] = []
var _preview_point: Node3D
var _mark_count := 0
var _arrival_locked := false
var _next_sample := 0.0
var _lamp := MeshInstance3D.new()
var _hud := Label.new()
var _notice := ""
var _notice_left := 0.0
var _cut_velocity := Vector3.ZERO
var _rng := RandomNumberGenerator.new()

var _foley := preload("res://scripts/ui/foley.gd").new()

func _ready() -> void:
	add_child(_foley)
	desk = load("res://scripts/relay/cutting_desk.gd").new()
	add_child(desk)
	desk.picked.connect(_pick_card)
	slate = SlateUI.new()
	slate.name = "Slate"
	add_child(slate)
	score = load("res://scripts/relay/relay_sound.gd").new()
	add_child(score)
	preload("res://scripts/core/input_setup.gd").ensure_actions()
	_rng.randomize()
	segments.append($Rooms.append_room("straight",0))
	player.name = "Player"
	add_child(player)
	player.teleport(segments[0].start,0)
	player.roll_mode = Orbit
	rig.name = "CameraRig"
	add_child(rig)
	rig.setup(player)
	rig.set_roll_mode(Orbit)
	rig.camera.fov = 53.0 # Frame both ends of the short set without changing ORBIT.
	add_child(_preview_rig)
	_preview_rig.add_child(_preview_camera)
	_preview_camera.fov = rig.camera.fov
	_preview_camera.near = rig.camera.near
	_preview_camera.far = rig.camera.far
	# Browsing a MARK shows what was on the film then: the live players and their
	# distance rings stay out of the frame, only the recorded stills are drawn.
	_preview_camera.cull_mask &= ~Ghost.LIVE_LAYER
	rig.camera.make_current()
	rig.reduce_motion = GameSession.settings.reduce_motion
	rig.roll_scale = GameSession.settings.roll_scale
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("28333e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e6e4dc")
	env.ambient_light_energy = 0.8
	var sky := WorldEnvironment.new()
	sky.environment = env
	add_child(sky)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54,-28,0)
	sun.shadow_enabled = true
	add_child(sun)
	var tape := BoxMesh.new()
	tape.size = Vector3(0.15,0.035,2.7)
	_lamp.mesh = tape
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color("ffde79")
	_lamp.material_override = ink
	add_child(_lamp)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(_hud)
	_hud.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_theme_font_size_override("font_size",24)
	_hud.add_theme_constant_override("outline_size",8)
	# Sample after the actual player and camera have stepped.
	process_physics_priority = 5
	_start_leg(false)

func _w(zh: String, en: String) -> String:
	return zh if Loc.language == "zh" else en

func _start_leg(back: bool) -> void:
	returning = back
	route.clear()
	var room := segments.back() as Dictionary
	route.append(room.start if back else room.end)
	cursor = 0
	_arrival_locked = false
	phase = Mode.PLAY
	player.set_frozen(false)
	rig.set_physics_process(true)
	live = Track.new()
	live.take_id = tracks.size()+1
	elapsed = 0.0
	_next_sample = 0.1
	_sample()
	_restart_actors()
	grace = GRACE
	_checkpoint(false)
	_show_target()
	# The board opens once per run, on the first take of the first set.
	if tracks.is_empty() and segments.size() == 1:
		_board_roll()

func _restart_actors() -> void:
	for old in _actors:
		old.playing = false
		old.hide()
		old.queue_free()
	_actors.clear()
	for tr in tracks.slice(room_track_start):
		if tr.duration() <= 0.0: continue
		var g := Ghost.new()
		g.loop_strip = true
		g.warmup_seconds = GRACE
		g.setup(tr,tr.take_id)
		add_child(g)
		g.strip_age = elapsed
		g.playhead = fposmod(elapsed, tr.duration())
		g.global_position = tr.sample_at(g.playhead).position
		_actors.append(g)

func _sample() -> void:
	live.add_sample(elapsed,player.global_position,player.facing,rig.yaw,rig.roll)

func _checkpoint(manual: bool) -> void:
	_sample()
	var p := {"leg":live.take_id,"pos":player.global_position,"facing":player.facing,
		"cursor":cursor,"time":elapsed,"cam_motion":rig.mark_motion(),"cam_yaw":rig.yaw,
		"cam_roll":rig.roll,"prefix":live.head_until(elapsed),"manual":manual}
	var frames := {}
	for ghost in _actors:
		frames[ghost.take_id] = ghost.still_frame()
	p["ghost_frames"] = frames
	# Replace the tape for this physical system stop, rather than flooding the
	# timeline with duplicates at every round trip. User MARKs stay distinct.
	if not manual:
		for i in anchors.size():
			if not anchors[i].manual and anchors[i].pos.distance_to(p.pos) < TOUCH*2:
				anchors[i] = p
				last_anchor = i
				return
	if manual:
		_mark_count += 1
		p["number"] = _mark_count
		_add_mark_still(p)
	anchors.append(p)
	last_anchor = anchors.size()-1


## A MARK is a place you can come back to, so it is drawn as yourself standing
## there: the projection of this take, not a prop and not a shadow.
func _add_mark_still(p: Dictionary) -> void:
	var beacon := MarkBeacon.new()
	beacon.setup(p.number, to_local(Vector3(p.pos)))
	add_child(beacon)
	var still := player.make_still(Vector3(0.0, 0.05, 0.0), float(p.facing))
	_tint_still(still, 0.0)
	beacon.add_child(still)
	_fade_in_still(still)


func _tint_still(still: Node3D, weight := 1.0) -> void:
	var ink := StandardMaterial3D.new()
	ink.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color(STILL_INK.r, STILL_INK.g, STILL_INK.b, STILL_ALPHA * weight)
	still.set_meta("ink", ink)
	for part in still.get_children():
		if part is MeshInstance3D:
			part.material_override = ink
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Brought up rather than popped in: the film is still settling on the mark.
func _fade_in_still(still: Node3D) -> void:
	var ink := still.get_meta("ink") as StandardMaterial3D
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		if is_instance_valid(ink):
			ink.albedo_color = Color(STILL_INK.r, STILL_INK.g, STILL_INK.b, STILL_ALPHA * k)
	, 0.0, 1.0, STILL_FADE)


func _close_preview() -> void:
	rig.camera.make_current()
	_clear_preview_nodes()


func _clear_preview_nodes() -> void:
	var nodes: Array = _preview_ghosts.duplicate()
	nodes.append(_preview_still)
	nodes.append(_preview_point)
	for node in nodes:
		if is_instance_valid(node):
			node.hide()
			node.queue_free()
	_preview_ghosts.clear()
	_preview_still = null
	_preview_point = null


## Browsing costs nothing: the camera stands where the take stood, with the
## stills of that instant laid over the empty set. Only the splice spends a CUT.
func _show_preview() -> void:
	_clear_preview_nodes()
	var p := anchors[_selected]
	var pos: Vector3 = p.pos
	if not p.manual:
		_preview_point = MarkBeacon.new()
		_preview_point.setup(0, to_local(pos), _w("起点","START"))
		add_child(_preview_point)
		_preview_still = player.make_still(to_local(pos), float(p.facing))
		_tint_still(_preview_still)
		add_child(_preview_still)
	_preview_rig.global_position = pos + Vector3.UP * CameraMath.FOCUS_HEIGHT
	_preview_rig.rotation.y = float(p.cam_yaw)
	_preview_camera.position = CameraMath.camera_offset(rig.pitch_deg, rig.distance)
	_preview_camera.rotation = CameraMath.camera_euler(rig.pitch_deg, float(p.cam_roll))
	if p.leg == live.take_id:
		for ghost in _actors:
			if not p.ghost_frames.has(ghost.take_id): continue
			var frame: Dictionary = p.ghost_frames[ghost.take_id]
			var still: Node3D = ghost.make_still(frame)
			add_child(still)
			still.global_transform = frame.pose
			_preview_ghosts.append(still)
	_preview_camera.make_current()

func _restore(i: int) -> void:
	var p := anchors[i]
	if p.leg == live.take_id:
		cursor = p.cursor
		elapsed = p.time
		live = p.prefix.head_until(elapsed)
		_next_sample = elapsed+0.1
	else:
		_sample() # No old room, objective, inventory or success is rolled back.
		elapsed += 0.011 # Preserve a jump instead of interpolating a long false walk.
	player.teleport(p.pos,p.facing)
	rig.setup(player)
	rig.restore_mark_motion(p)
	_sample()
	last_anchor = i
	_restart_actors()
	grace = GRACE
	_arrival_locked = player.global_position.distance_to(route[cursor]) <= TOUCH
	_show_target()

func _show_target() -> void:
	_lamp.visible = phase == Mode.PLAY
	if _lamp.visible: _lamp.position = route[cursor]+Vector3.UP*0.10
	_refresh()

func _finish_leg() -> void:
	_sample()
	tracks.append(live)
	slate.clack(-8.0) # One take is in the can.
	room_pass += 1
	if room_pass < PASSES:
		score.cue("line")
		_start_leg(not returning)
		return
	phase = Mode.DONE if segments.size() == MODULES else Mode.ITEM
	_freeze()
	_show_target()
	if phase == Mode.DONE:
		if Rules.unlocked(difficulty): Rules.record_clear(difficulty)
		score.cue("win")
		desk.show_result(true, Loc.language == "zh")
	else:
		score.cue("clear")
		desk.show_items(Loc.language == "zh")

func _pick_card(i: int) -> void:
	if phase == Mode.ITEM and i >= 0 and i < 3:
		match i:
			0: splice.offer()
			1: mark_stock += 1
			2: cut_stock += 1
		score.cue("pickup")
		phase = Mode.PICK
		cards.clear()
		var deck := KINDS.duplicate()
		for _slot in 3:
			cards.append({"kind": deck.pop_at(_rng.randi_range(0, deck.size() - 1)), "variant": _rng.randi_range(0, 1)})
		desk.show_draw(cards, Loc.language == "zh")
		_refresh()
		return
	if phase != Mode.PICK or i < 0 or i >= cards.size(): return
	var c: Dictionary = cards[i]
	var room: Dictionary = $Rooms.append_room(c.kind,c.variant)
	segments.append(room)
	score.cue("choose")
	room_track_start = tracks.size()
	room_pass = 0
	player.teleport(room.start,player.facing)
	desk.hide_draw()
	_start_leg(false)

func _freeze() -> void:
	_cut_velocity = player.velocity
	player.set_frozen(true)
	rig.set_physics_process(false)
	for g in _actors: g.playing = false

func _leave_cut() -> void:
	_close_preview()
	phase = Mode.PLAY
	player.set_frozen(false)
	player.velocity = _cut_velocity
	rig.set_physics_process(true)
	for g in _actors: g.playing = not g.spent
	_show_target()

func _physics_process(dt: float) -> void:
	if phase != Mode.PLAY: return
	active_clock += dt
	elapsed += dt
	grace = maxf(grace-dt,0)
	_notice_left -= dt
	if elapsed >= _next_sample:
		_sample()
		_next_sample = elapsed + 0.10
	$Rooms.set_clock(segments.size()-1,elapsed)
	if grace <= 0:
		for g in _actors:
			if not g.spent and g.strip_age >= GRACE and g.global_position.distance_to(player.global_position) < Ghost.DANGER_RADIUS + Player.RADIUS:
				if _hit(g.take_id): return
				break
		if $Rooms.hazard_at(player.global_position,segments.size()-1,elapsed):
			if _hit(0): return
	var inside := player.position.x <= route[cursor].x + 0.1 if returning else player.position.x >= route[cursor].x - 0.1
	if not inside: _arrival_locked = false
	if inside and not _arrival_locked:
		cursor += 1
		if cursor == route.size():
			_finish_leg()
			return
		_checkpoint(false)
		_show_target()
	_refresh()

func _hit(source: int) -> bool:
	var held := splice.has_splice()
	if splice.protect(active_clock):
		if held and not splice.has_splice():
			_foley.play("splice")
			desk.show_message(_w("接片续拍", "SPLICED"))
		return false
	deaths += 1
	score.cue("trap" if source == 0 else "hit")
	if difficulty > 0:
		forced_cut = cut_stock > 0
		phase = Mode.CUT if forced_cut else Mode.LOST
		_selected = last_anchor
		_freeze()
		_board_die()
		_show_target()
		if phase == Mode.CUT: _show_preview()
		else: desk.show_result(false,Loc.language == "zh")
	else:
		_board_die()
		_restore(last_anchor)
		desk.show_message(_w("撞到摄影车", "CAMERA DOLLY") if source == 0 else "TAKE %02d" % source)
	return true

func _unhandled_key_input(e: InputEvent) -> void:
	if not e is InputEventKey or not e.pressed or e.echo: return
	var key: int = e.physical_keycode
	if key == KEY_F2:
		Loc.set_language("en" if Loc.language == "zh" else "zh")
		return
	# The board is talking. Nothing else gets a say until the clack has landed.
	if slate.is_running(): return
	if phase in [Mode.ITEM, Mode.PICK] and key >= KEY_1 and key <= KEY_3:
		_pick_card(key-KEY_1)
	elif phase in [Mode.DONE,Mode.LOST] and key == KEY_SPACE:
		get_tree().reload_current_scene()
	elif phase == Mode.CUT:
		match key:
			KEY_C, KEY_ESCAPE:
				if not forced_cut: _leave_cut()
			KEY_UP:
				_selected = posmod(_selected-1,anchors.size())
				_show_preview()
			KEY_DOWN:
				_selected = posmod(_selected+1,anchors.size())
				_show_preview()
			KEY_SPACE, KEY_ENTER:
				if cut_stock > 0:
					cut_stock -= 1
					forced_cut = false
					_board_cut()
					_leave_cut()
					_restore(_selected)
	elif phase == Mode.PLAY:
		match key:
			KEY_C:
				phase = Mode.CUT
				_selected = last_anchor
				_freeze()
				_show_preview()
			KEY_M:
				if mark_stock > 0:
					mark_stock -= 1
					_checkpoint(true)
					_notice = _w("已标记；失手会自动回到这里。","Marked. A collision returns you here.")
				else: _notice = _w("标记已用完。","No MARKs left.")
				_notice_left = 2.5
	_refresh()

func _refresh() -> void:
	var zh := Loc.language == "zh"
	desk.update_run(segments.size(),MODULES,mini(room_pass+1,PASSES),PASSES,mark_stock,cut_stock,splice.has_splice(),zh)
	_hud.visible = phase == Mode.CUT
	if _hud.visible:
		var p := anchors[_selected]
		var tag := ("MARK %d" % int(p.get("number",0))) if p.manual else _w("起点","START")
		_hud.text = _w("剪辑台　↑ ↓　%02d / %02d", "CUT DESK   ↑ ↓   %02d / %02d") % [_selected+1, anchors.size()] + "\n%s · TAKE %02d · %.1fs\n" % [tag,p.leg,p.time] + _w("空格：剪回　−1 CUT　（看片不要钱）", "SPACE: splice   −1 CUT   (looking is free)")
	if _notice_left > 0:
		desk.show_message(_notice)
		_notice_left = 0

## The board, three ways. It never changes state itself: it names what just
## happened and gets out of the way, so the player learns one object for all of
## ROLL, CUT and DIE.
func _board_roll() -> void:
	var n := maxi(live.take_id,1)
	slate.play_roll(n, _w("第 %02d 条" % n, "TAKE %02d" % n))

func _board_cut() -> void:
	var n := maxi(live.take_id,1)
	slate.play_cut(n, _w("第 %02d 条" % n, "TAKE %02d" % n))

func _board_die() -> void:
	var n := maxi(live.take_id,1)
	slate.play_die(n, _w("第 %02d 条" % n, "TAKE %02d" % n))
