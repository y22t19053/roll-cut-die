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
const FrameFX = preload("res://scripts/relay/frame_fx.gd")
const Save = preload("res://scripts/relay/relay_save.gd")
const MODULES := 6
const KINDS := ["s", "h", "u", "l", "n", "x"]
## A run is three acts of two sets. The seam between acts is the only place the
## player is asked to sign something: a shorter act, a longer one, or an act with
## no mercy at all. Everything else is decided at a door.
const ACTS := 3
const SETS_PER_ACT := 2
const TOUCH := 0.77
const GRACE := 0.75
const PASSES := 4
## A run is a seed and six sets in three acts: the seed is printed on the call
## sheet so two runs can be compared, replayed or argued about.
static var next_seed := 0## A run that was written down between takes. The title screen decides whether
## New Game starts fresh or Continue picks this up.
static var pending_resume := {}
var run_seed := 0
## How many legs the current set asks for. A short set is faster; a long one
## pays a supply. This is the run's only real decision.
var required_passes := PASSES
## Which act of three the run is in, what was signed at the last seam, and how
## much grace that act allows. Nothing else changes between acts.
var act := 0
var act_mod := ""
var act_grace := GRACE
## The first splice of a run is free: the player has to feel what a CUT costs
## before it can cost them anything.
var free_cut := 1
## A run is only written down in the record book once, however often the sheet
## ends up on screen.
var _recorded := false
var _seen_hints := {}
## Ghosts the tape handed you back inside of. They stop counting until you
## step out: a respawn is never the player's mistake.
var _inside := {}
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
var fx: Node
var score: Node
## Last distance to each ghost, so a close pass can be told from a clean one.
var _gap := {}

enum Mode { PLAY, PICK, CUT, DONE, LOST, ITEM, ACT }
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
	fx = FrameFX.new()
	fx.name = "FrameFX"
	add_child(fx)
	slate.sequence_finished.connect(_slate_done)
	score = load("res://scripts/relay/relay_sound.gd").new()
	add_child(score)
	preload("res://scripts/core/input_setup.gd").ensure_actions()
	if next_seed != 0:
		run_seed = next_seed
		next_seed = 0
	else:
		run_seed = int(Time.get_unix_time_from_system()) & 0xFFFFFF
	_rng.seed = run_seed
	# A written-down run is rebuilt before the player exists: the rooms have to be
	# standing before anyone can stand in them.
	var resuming := not pending_resume.is_empty()
	if resuming:
		_apply_run(pending_resume)
		pending_resume = {}
	else:
		segments.append($Rooms.append_room("straight",0))
		Save.clear() # A new run throws away the one that was left open.
	player.name = "Player"
	add_child(player)
	player.teleport((segments.back() as Dictionary).start, 0)
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
	# Depth fog: the far end of a set goes soft, so "eight legs away" reads as a
	# distance and not as the same wall twice.
	env.fog_enabled = true
	env.fog_light_color = Color("28333e")
	env.fog_density = 0.006
	env.fog_aerial_perspective = 0.0
	var sky := WorldEnvironment.new()
	sky.environment = env
	add_child(sky)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54,-28,0)
	sun.shadow_enabled = true
	add_child(sun)
	# A cold bounce from the opposite side keeps the shadowed faces from going
	# flat black; it is a set light, never a gameplay signal.
	var bounce := DirectionalLight3D.new()
	bounce.rotation_degrees = Vector3(-24,146,0)
	bounce.light_color = Color("9fb8c8")
	bounce.light_energy = 0.32
	bounce.shadow_enabled = false
	add_child(bounce)
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
	_arm_mercy()
	desk.clear_sheet()
	score.resume_beds() # The room comes back with the new take.
	grace = act_grace
	_checkpoint(false)
	_show_target()
	# The board opens once per run, on the first take of the first set.
	if tracks.is_empty() and segments.size() == 1:
		_board_roll()
	elif segments.size() == 1 and room_pass == 1:
		_hint("first_ghost", "这一条是你刚才留下的。它会迎面回来。", "That is your last take. It comes back the other way.")


## The tape hands you back at a MARK. If a ghost already stands there, it waits:
## it starts counting again only once you have stepped out of it. A respawn is
## never the player's mistake.
func _arm_mercy() -> void:
	_inside.clear()
	for g in _actors:
		if g.global_position.distance_to(player.global_position) < Ghost.DANGER_RADIUS + Player.RADIUS + 0.06:
			_inside[g.take_id] = true


## One line, once. The first minutes teach by naming what just happened.
func _hint(key: String, zh: String, en: String) -> void:
	if _seen_hints.has(key): return
	_seen_hints[key] = true
	_notice = _w(zh, en)
	_notice_left = 3.5


## Everything a run remembers, in the order it was paid for.
func _serialize_run() -> Dictionary:
	var plan: Array = []
	for s in segments:
		plan.append({"kind": str(s.get("kind","")), "variant": int(s.get("variant",0)),
			"mod": str(s.get("mod","")), "final": bool(s.get("final", false))})
	var rec: Array = []
	for t in tracks:
		rec.append(t.to_dict())
	return {"seed": run_seed, "difficulty": difficulty, "required_passes": required_passes,
		"room_pass": room_pass, "segments": plan, "mark_stock": mark_stock, "cut_stock": cut_stock,
		"free_cut": free_cut, "splice": splice.has_splice(), "deaths": deaths, "tracks": rec,
		"room_track_start": room_track_start, "act": act, "act_mod": act_mod, "act_grace": act_grace}


## Written between takes, never mid-take: a leg only counts once it is in the can.
func _save_run() -> void:
	if phase == Mode.DONE: return
	Save.save_run(_serialize_run())


func _apply_run(d: Dictionary) -> void:
	run_seed = int(d.get("seed", run_seed))
	_rng.seed = run_seed
	difficulty = int(d.get("difficulty", difficulty))
	required_passes = int(d.get("required_passes", PASSES))
	mark_stock = int(d.get("mark_stock", mark_stock))
	cut_stock = int(d.get("cut_stock", cut_stock))
	free_cut = int(d.get("free_cut", free_cut))
	deaths = int(d.get("deaths", 0))
	act = int(d.get("act", 0))
	act_mod = str(d.get("act_mod", ""))
	act_grace = float(d.get("act_grace", GRACE))
	if bool(d.get("splice", false)): splice.offer()
	tracks = []
	for raw in d.get("tracks", []):
		var tr = Track.from_dict(raw)
		if tr != null: tracks.append(tr)
	for s in d.get("segments", []):
		var r: Dictionary = s
		segments.append($Rooms.append_room(str(r.get("kind","straight")), int(r.get("variant",0)), str(r.get("mod","")), bool(r.get("final", false))))
	room_pass = int(d.get("room_pass", 0))
	# The ghosts this set already has: everything recorded since it was joined,
	# never the takes of a set the player has not entered yet.
	room_track_start = clampi(int(d.get("room_track_start", tracks.size())), 0, tracks.size())

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
	_arm_mercy()
	desk.clear_sheet()
	score.resume_beds()
	grace = act_grace
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
	rig.add_shake(0.2)
	fx.flash(Color("9ceccb"), 0.12, 0.0, 0.14)
	room_pass += 1
	if room_pass < required_passes:
		_save_run() # One take is in the can; a quit now costs nothing.
		score.cue("line")
		_start_leg(not returning)
		return
	if segments.size() >= MODULES:
		phase = Mode.DONE
		_freeze()
		_show_target()
		Save.clear() # A finished run is not a run to come back to.
		if Rules.unlocked(difficulty): Rules.record_clear(difficulty)
		_finish_line()
		return
	_freeze()
	_show_target()
	if segments.size() % SETS_PER_ACT == 0:
		# The seam between acts: sign one thing, and live with it for two sets.
		phase = Mode.ACT
		act += 1
		cards = _offer_contracts()
		score.cue("clear")
		desk.show_draw(cards, Loc.language == "zh")
		desk.show_message(_w("第 %d 节。签一张。" % (act + 1), "Act %d. Sign one." % (act + 1)))
	else:
		phase = Mode.ITEM
		score.cue("clear")
		desk.show_items(Loc.language == "zh")

## The last line of the run. A wrap is loud on purpose: the run's whole promise
## is that the crossing is worth the takes it cost.
func _finish_line() -> void:
	score.cue("win")
	score.resume_beds()
	slate.play_wrap(_w("全部接通", "ANSWER PRINT"), _w("这一卷是你的", "this reel is yours"))
	rig.add_shake(0.7)
	fx.flash(Color("ffeec4"), 0.46, 0.06, 0.42)
	_hint("finish", "冲线。这一卷是你的。", "Across the line. This reel is yours.")
	# The board names the crossing first; the call sheet comes in after the clack
	# has landed, the way a wrap is called before the paperwork.
	get_tree().create_timer(0.72).timeout.connect(func() -> void: _show_sheet(true))

## Three contracts, each a price on the next two sets. Nothing hidden: the cost
## is printed on the card, and it is paid the moment you sign.
func _offer_contracts() -> Array:
	return [
		{"kind": "contract", "contract": "rush", "title": _w("赶一条", "RUSH"),
			"line1": _w("下一节每棚 3 趟", "next act: 3 legs a set"),
			"line2": _w("现在扣 1 MARK", "costs 1 MARK now"), "stamp": _w("−1 MARK", "−1 MARK")},
		{"kind": "contract", "contract": "overtime", "title": _w("多留一条", "OVERTIME"),
			"line1": _w("下一节每棚 5 趟", "next act: 5 legs a set"),
			"line2": _w("现在给 1 CUT", "pays 1 CUT now"), "stamp": _w("+1 CUT", "+1 CUT")},
		{"kind": "contract", "contract": "blackout", "title": _w("不许宽限", "BLACKOUT"),
			"line1": _w("下一节没有 0.75 秒宽限", "next act: no 0.75 s grace"),
			"line2": _w("接片作废，给 2 MARK", "no splice, +2 MARK now"), "stamp": _w("+2 MARK", "+2 MARK")},
	]

func _apply_contract(id: String) -> void:
	act_mod = id
	act_grace = GRACE
	match id:
		"rush":
			mark_stock = maxi(mark_stock - 1, 0)
		"overtime":
			cut_stock += 1
		"blackout":
			mark_stock += 2
			splice = Splice.new()
			act_grace = 0.30
	score.cue("pickup")

## Three doors, three stakes. A short set is quick and pays nothing; a long one
## costs legs and pays a supply. The condition is on the door, never a surprise
## after the pick.
func _offer_doors() -> Array:
	var tier := segments.size() - 1
	var deck := KINDS.duplicate()
	var stakes := [[3, ""], [PASSES, ""], [PASSES + 1, "mark"]]
	if tier >= 2:
		stakes = [[3, ""], [PASSES + 1, "cut"], [PASSES + 1, "mark"]]
	var out: Array = []
	for slot in 3:
		var st: Array = stakes[slot]
		var door := {"kind": deck.pop_at(_rng.randi_range(0, deck.size() - 1)),
			"variant": _rng.randi_range(0, 1), "mod": _roll_mod(tier, slot),
			"passes": int(st[0]), "reward": str(st[1])}
		door["mod_label"] = _mod_label(str(door["mod"]))
		door["stake_label"] = _stake_label(int(door["passes"]), str(door["reward"]))
		out.append(door)
	return out


## Threat climbs with depth. The first set is the teaching one: at most a quick
## trolley. Deeper in, twin tracks and narrow mouths show up on the doors.
func _roll_mod(tier: int, _slot := 0) -> String:
	var r := _rng.randf()
	if tier <= 0:
		return "" if r < 0.65 else "fast"
	var hard := clampf(0.16 + float(tier) * 0.09, 0.0, 0.50)
	if r < 1.0 - hard: return "" if r < 0.5 else "fast"
	if r < 1.0 - hard * 0.55: return "twin"
	if r < 1.0 - hard * 0.22: return "throat"
	return "clean"


func _stake_label(passes: int, reward: String) -> String:
	var base := _w("%d 趟", "%d legs") % passes
	match reward:
		"mark": return base + _w("　多给 1 MARK", "   +1 MARK")
		"cut": return base + _w("　多给 1 CUT", "   +1 CUT")
		"splice": return base + _w("　送一片接片", "   free splice")
	return base + _w("　无补给", "   no supply")

func _mod_label(mod: String) -> String:
	match mod:
		"fast": return _w("快车 · 推轨更快", "FAST · quicker dolly")
		"twin": return _w("双推轨 · 两台车", "TWIN · two dollies")
		"throat": return _w("窄喉 · 口子更窄", "THROAT · narrower mouth")
		"clean": return _w("空棚 · 没有车", "EMPTY · no dolly")
	return ""

func _pick_card(i: int) -> void:
	if phase == Mode.ACT and i >= 0 and i < cards.size():
		_apply_contract(str(cards[i].get("contract", "rush")))
		phase = Mode.PICK
		cards = _offer_doors()
		desk.show_draw(cards, Loc.language == "zh")
		_refresh()
		return
	if phase == Mode.ITEM and i >= 0 and i < 3:
		match i:
			0: splice.offer()
			1: mark_stock += 1
			2: cut_stock += 1
		score.cue("pickup")
		phase = Mode.PICK
		cards = _offer_doors()
		desk.show_draw(cards, Loc.language == "zh")
		_refresh()
		return
	if phase != Mode.PICK or i < 0 or i >= cards.size(): return
	var c: Dictionary = cards[i]
	var last := segments.size() == MODULES - 1
	var room: Dictionary = $Rooms.append_room(c.kind,c.variant,str(c.get("mod","")),last)
	segments.append(room)
	required_passes = int(c.get("passes",PASSES))
	if act_mod == "rush": required_passes = maxi(required_passes - 1, 2)
	elif act_mod == "overtime": required_passes += 1
	match str(c.get("reward","")):
		"mark": mark_stock += 1
		"cut": cut_stock += 1
		"splice": splice.offer()
	act_mod = "" # A contract covers one act, never the whole run.
	score.cue("choose")
	room_track_start = tracks.size()
	room_pass = 0
	player.teleport(room.start,player.facing)
	desk.hide_draw()
	_save_run() # The door is taken: the next set starts where this one began.
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
		var reach: float = Ghost.DANGER_RADIUS + Player.RADIUS
		for g in _actors:
			if g.spent or g.strip_age < GRACE: continue
			var d: float = g.global_position.distance_to(player.global_position)
			if _inside.get(g.take_id, false):
				if d > reach + 0.25: _inside.erase(g.take_id)
				continue
			if d < reach:
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
	_track_gaps()
	_refresh()

## The nearest ghost sets the tension bed; the moment a close pass becomes a
## clean one, a single click says so. Nothing here scores, slows or pushes.
func _track_gaps() -> void:
	var near := Ghost.DANGER_RADIUS + 1.0
	var loudest := 0.0
	for g in _actors:
		var id: int = g.take_id
		var d: float = player.global_position.distance_to(g.global_position)
		var prev: float = float(_gap.get(id, 99.0))
		_gap[id] = d
		if g.spent: continue
		if d < 2.1:
			loudest = maxf(loudest, clampf((1.7 - d) / 1.1, 0.0, 1.0))
		# Out of the near zone alive: that, and only that, is worth a click.
		if prev <= near and d > near and player.speed_now() > 1.0:
			score.cue("near")
			rig.add_shake(0.12)
	score.set_danger(loudest if grace <= 0.0 else 0.0)

## The board is done talking: the score comes back up. The clack is the loudest
## thing in the room for as long as the board is on screen.
func _slate_done(_kind: String) -> void:
	score.duck(false)

func _hit(source: int) -> bool:
	var held := splice.has_splice()
	if splice.protect(active_clock):
		if held and not splice.has_splice():
			_foley.play("splice")
			rig.add_shake(0.5)
			fx.flash(Color("9ceccb"), 0.22, 0.0, 0.18)
			desk.show_message(_w("接片续拍", "SPLICED"))
		return false
	deaths += 1
	score.cue("trap" if source == 0 else "hit")
	rig.add_shake(1.0)
	fx.flash(Color("f3dfad"), 0.34, 0.0, 0.22)
	if difficulty > 0:
		forced_cut = cut_stock > 0
		phase = Mode.CUT if forced_cut else Mode.LOST
		_selected = last_anchor
		_freeze()
		_board_die()
		_show_target()
		if phase == Mode.CUT: _show_preview()
		else:
			Save.clear()
			_show_sheet(false)
	else:
		_board_die()
		_restore(last_anchor)
		_hint("first_death", "撞上就重来一条，别的什么都不扣。", "A collision costs one take and nothing else.")
		desk.show_message(_w("撞到摄影车", "CAMERA DOLLY") if source == 0 else "TAKE %02d" % source)
	return true


## The call sheet. Win or lose, a run ends with one page that says what it was:
## how far, how many takes, how many deaths, and the seed to replay it.
func _show_sheet(won: bool) -> void:
	if not is_inside_tree(): return
	# The run is over, so the board gets out of the way instead of printing the
	# DIE. card over the page that explains what the run was.
	if slate.is_running(): slate.hide_slate()
	if not _recorded:
		_recorded = true
		Rules.record_run(segments.size(), deaths, won, run_seed)
	var lines: Array = [
		_w("棚 %d / %d　条 %d　死 %d", "SETS %d / %d   TAKES %d   DEATHS %d") % [segments.size(),MODULES,tracks.size(),deaths],
		_w("标记 %d　剪 %d　种子 %06X", "MARKS %d   CUTS %d   SEED %06X") % [mark_stock,cut_stock,run_seed],
		_w("空格：再来一局　R：同种子重开", "SPACE: new run   R: same seed"),
	]
	if won:
		desk.show_call_sheet(_w("全部接通","ANSWER PRINT"), lines, true, Loc.language == "zh")
	else:
		lines.insert(0,_w("最后一趟没走出来。","The last take never made it out."))
		desk.show_call_sheet(_w("这卷到头了","END OF REEL"), lines, false, Loc.language == "zh")

func _unhandled_key_input(e: InputEvent) -> void:
	if not e is InputEventKey or not e.pressed or e.echo: return
	var key: int = e.physical_keycode
	if key == KEY_F2:
		Loc.set_language("en" if Loc.language == "zh" else "zh")
		return
	if key == KEY_F3:
		# A/B switch for the handheld bank: F3 must give the old picture back.
		rig.tilt_enabled = not rig.tilt_enabled
		_notice = _w("镜头横倾：开" if rig.tilt_enabled else "镜头横倾：关",
			"LENS TILT: ON" if rig.tilt_enabled else "LENS TILT: OFF")
		_notice_left = 2.0
		return
	# The board is talking. Nothing else gets a say until the clack has landed.
	if slate.is_running(): return
	if phase in [Mode.ITEM, Mode.PICK, Mode.ACT] and key >= KEY_1 and key <= KEY_3:
		_pick_card(key-KEY_1)
	elif phase in [Mode.DONE,Mode.LOST]:
		match key:
			KEY_SPACE:
				next_seed = 0
				get_tree().reload_current_scene()
			KEY_R:
				next_seed = run_seed
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
				# The first splice of the run is free: knowing what a CUT costs
				# has to happen before it can cost anything.
				var cost := 0 if (free_cut > 0 and not forced_cut) else 1
				if cut_stock >= cost:
					if cost == 0:
						free_cut = 0
						desk.show_message(_w("第一次剪回不收钱。", "The first splice is free."))
					else:
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
				_hint("cut_desk", "↑ ↓ 选一段，空格才花 CUT。看片不要钱。", "↑ ↓ to pick a strip. Looking is free; SPACE spends the CUT.")
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
	desk.update_run(segments.size(),MODULES,mini(room_pass+1,required_passes),required_passes,mark_stock,cut_stock,splice.has_splice(),zh)
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
	score.duck(true)
	slate.play_roll(n, _w("第 %02d 条" % n, "TAKE %02d" % n))

func _board_cut() -> void:
	var n := maxi(live.take_id,1)
	score.duck(true)
	slate.play_cut(n, _w("第 %02d 条" % n, "TAKE %02d" % n))

func _board_die() -> void:
	var n := maxi(live.take_id,1)
	score.duck(true)
	slate.play_die(n, _w("第 %02d 条" % n, "TAKE %02d" % n))
