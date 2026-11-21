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
const MODULES := 5
const KINDS := ["s", "h", "u", "l", "n", "x"]
const TOUCH := 0.77
const GRACE := 0.75
const PASSES := 4
var room_pass := 0
var room_track_start := 0
var cards: Array = []
var desk: CanvasLayer
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
	# Replace the tape for this physical system stop, rather than flooding the
	# timeline with duplicates at every round trip. User MARKs stay distinct.
	if not manual:
		for i in anchors.size():
			if not anchors[i].manual and anchors[i].pos.distance_to(p.pos) < TOUCH*2:
				anchors[i] = p
				last_anchor = i
				return
	anchors.append(p)
	last_anchor = anchors.size()-1

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
		_show_target()
		if phase == Mode.LOST: desk.show_result(false,Loc.language == "zh")
	else:
		_restore(last_anchor)
		desk.show_message(_w("撞到摄影车", "CAMERA DOLLY") if source == 0 else "TAKE %02d" % source)
	return true

func _unhandled_key_input(e: InputEvent) -> void:
	if not e is InputEventKey or not e.pressed or e.echo: return
	var key: int = e.physical_keycode
	if key == KEY_F2:
		Loc.set_language("en" if Loc.language == "zh" else "zh")
	elif phase == Mode.PICK and key >= KEY_1 and key <= KEY_3:
		_pick_card(key-KEY_1)
	elif phase in [Mode.DONE,Mode.LOST] and key == KEY_SPACE:
		get_tree().reload_current_scene()
	elif phase == Mode.CUT:
		match key:
			KEY_C, KEY_ESCAPE:
				if not forced_cut: _leave_cut()
			KEY_UP: _selected = posmod(_selected-1,anchors.size())
			KEY_DOWN: _selected = posmod(_selected+1,anchors.size())
			KEY_SPACE, KEY_ENTER:
				if cut_stock > 0:
					cut_stock -= 1
					forced_cut = false
					_leave_cut()
					_restore(_selected)
	elif phase == Mode.PLAY:
		match key:
			KEY_C:
				phase = Mode.CUT
				_selected = last_anchor
				_freeze()
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
		_hud.text = _w("剪辑台　↑ ↓　%02d / %02d", "CUT DESK   ↑ ↓   %02d / %02d") % [_selected+1, anchors.size()] + "\nTAKE %02d · %.1fs\n" % [p.leg,p.time] + _w("空格：剪回　−1 CUT", "SPACE: splice   −1 CUT")
	if _notice_left > 0:
		desk.show_message(_notice)
		_notice_left = 0
