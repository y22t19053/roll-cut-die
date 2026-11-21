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
const MODULES := 7
const KINDS := ["tee", "cross", "zig"]
const TOUCH := 0.77
const GRACE := 2.5

enum Mode { PLAY, PICK, CUT, DONE, LOST }
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

func _ready() -> void:
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
	var ring := TorusMesh.new()
	ring.inner_radius = 0.58
	ring.outer_radius = 0.84
	_lamp.mesh = ring
	_lamp.scale.y = 0.22
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = Color("ffdf63")
	_lamp.material_override = ink
	add_child(_lamp)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(_hud)
	_hud.position = Vector2(22,18)
	_hud.add_theme_font_size_override("font_size",21)
	_hud.add_theme_constant_override("outline_size",7)
	_hud.add_theme_color_override("font_outline_color",Color("16202aff"))
	# Sample after the actual player and camera have stepped.
	process_physics_priority = 5
	_start_leg(false)

func _w(zh: String, en: String) -> String:
	return zh if Loc.language == "zh" else en

func _start_leg(back: bool) -> void:
	returning = back
	route.clear()
	for room in segments:
		for stop: Vector3 in room.stops:
			route.append(stop)
	if back:
		route.remove_at(route.size()-1) # Already standing at the turnaround.
		route.reverse()
		route.append(segments[0].start)
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
	for tr in tracks:
		if elapsed >= tr.duration(): continue
		var g := Ghost.new()
		add_child(g)
		g.setup(tr,tr.take_id)
		g.playhead = elapsed
		g.global_position = tr.sample_at(elapsed).position
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
	if not returning:
		_start_leg(true)
		return
	phase = Mode.DONE if segments.size() == MODULES else Mode.PICK
	if phase == Mode.DONE and Rules.unlocked(difficulty): Rules.record_clear(difficulty)
	_freeze()
	_show_target()

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
	if grace <= 0:
		for g in _actors:
			if not g.spent and g.playhead >= Ghost.WARMUP and g.global_position.distance_to(player.global_position) < Ghost.DANGER_RADIUS + Player.RADIUS:
				if splice.protect(active_clock):
					_notice = _w("保险片接上！原地续拍 1.5 秒。", "Spliced! Keep moving for 1.5 s.")
					_notice_left = 1.5
					break
				deaths += 1
				if difficulty > 0:
					forced_cut = cut_stock > 0
					phase = Mode.CUT if forced_cut else Mode.LOST
					_selected = last_anchor
					_freeze()
					_show_target()
					return
				_notice = _w("撞上第 %02d 条，已返回上次落点。", "Hit TAKE %02d. Back at your last anchor.") % g.take_id
				_notice_left = 3.5
				_restore(last_anchor)
				return
	var inside := player.global_position.distance_to(route[cursor]) <= TOUCH
	if not inside: _arrival_locked = false
	if inside and not _arrival_locked:
		cursor += 1
		if cursor == route.size():
			_finish_leg()
			return
		_checkpoint(false)
		_show_target()
	_refresh()

func _unhandled_key_input(e: InputEvent) -> void:
	if not e is InputEventKey or not e.pressed or e.echo: return
	var key: int = e.physical_keycode
	if key == KEY_F2:
		Loc.set_language("en" if Loc.language == "zh" else "zh")
	elif phase == Mode.PICK and key >= KEY_1 and key <= KEY_3:
		segments.append($Rooms.append_room(KINDS[key-KEY_1],_rng.randi_range(0,1)))
		if key == KEY_3: splice.offer()
		_start_leg(false)
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
	var lines := PackedStringArray()
	lines.append(_w("接力片场   %d/%d 间   ·   已录 %d 条", "RELAY   %d/%d rooms   ·   %d takes banked") % [segments.size(),MODULES,tracks.size()])
	match phase:
		Mode.PICK:
			lines.append(_w("选下一间，接在旧片场尽头：", "Extend the far end of the set:"))
			lines.append(_w("[1] 丁字支线    [2] 十字交叉    [3] 折线 + 保险片", "[1] T junction    [2] Crossroads    [3] Switchback + safety splice"))
		Mode.LOST:
			lines.append(_w("没有 CUT 可重拍。本局结束。 [空格] 重开", "Out of CUTs. Run over. [SPACE] Restart"))
		Mode.DONE:
			lines.append(_w("七间全部往返完成。收工！  [空格] 重新开拍", "Seven rooms, out and back. That's a wrap!  [SPACE] New run"))
		Mode.CUT:
			var p := anchors[_selected]
			if not forced_cut: lines.append(_w("[C] 原地继续", "[C] Resume here"))
			if forced_cut: lines.append(_w("失手：必须选点重拍。", "Caught: choose an anchor to retake."))
			lines.append(_w("剪辑台  ↑↓ 翻看 %d/%d", "CUT desk  ↑↓ Browse %d/%d") % [_selected+1,anchors.size()])
			lines.append(("MARK" if p.manual else _w("系统落点","Set anchor")) + "   TAKE %02d   %.1f s   (%.1f, %.1f)" % [p.leg,p.time,p.pos.x,p.pos.z])
			lines.append(_w("同趟恢复到当时；跨趟只移位置，目标仍要亲自踩。", "This leg: rewind. Older leg: move only; you must still reach the target."))
			lines.append(_w("[空格] 消耗 1 CUT；预览免费。", "[SPACE] Spend 1 CUT. Browsing is free.") if cut_stock > 0 else _w("CUT 已用完；按 C 继续。", "No CUTs left; C to resume."))
		Mode.PLAY:
			var delta := route[cursor]-player.global_position
			var direction := ("D" if delta.x>0 else "A") if absf(delta.x)>absf(delta.z) else ("S" if delta.z>0 else "W")
			var leg := _w("回程","RETURN") if returning else _w("去程","OUTBOUND")
			lines.append(leg + _w("：走进金环   %d/%d   ·   %s 方向 %.0f m", ": walk into the gold ring   %d/%d   ·   %s direction %.0f m") % [cursor+1,route.size(),direction,delta.length()])
			lines.append(_w("WASD 移动；键位不随镜头转。避开旧条里的人。", "WASD moves on fixed axes. Dodge the cast of earlier takes."))
			if _notice_left > 0: lines.append(_notice)
	lines.append(_w("[M] 标记 %d   [C] 剪辑 %d", "[M] MARK %d   [C] CUT %d") % [mark_stock,cut_stock])
	lines.append(_w("新手 · 失手自动重来，不限次", "NOVICE · Unlimited automatic retries") if difficulty == 0 else _w("失手必须剪辑；没有 CUT 就收工。","Collision requires a CUT; none left ends the run."))
	if splice.has_splice(): lines.append(_w("保险片在手 · 下次相撞原地续拍", "Safety splice loaded · protects the next hit"))
	_hud.text = "\n".join(lines)
