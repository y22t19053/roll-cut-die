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
const MODULES := 12
## The shapes the run draws from. I, L and O come first because they are the three
## honest answers to "what happens when the crew rebuilds it the other way round?":
## nothing, the corner moves, the other side of the ring. The rest wait in the wings.
const KINDS := ["l", "i", "o", "h", "s"]
## Everything the crew is allowed to do to a set. Acts 1–2 only ever see the
## first three; later acts draw from all of it and may stack two at once.
const EVENT_POOL := ["relight", "extra", "guide", "belt", "runner", "goof", "key", "mezz", "double", "wire"]
## A run is four acts of three sets: two quick sets and one long take. The long
## take is the only one allowed to hurt, and it is the one with the gate in it.
## Four acts, not three: the room count is what makes a run ten minutes long, and
## short sets never ask the player to walk the same floor five times.
const ACTS := 4
const SETS_PER_ACT := 3
const SHORT_PASSES := 2
const LONG_PASSES := 5
const TOUCH := 0.77
## A respawn is not a punishment: the tape hands you back with time to see where
## you are. The grace is part of the set now, so a respawn never asks for a blind
## dodge.
const GRACE := 1.2
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
var leg_event := "" # How the crew dressed this set: relight / extra / guide.
var _riding := false # On the wire: input is gone and the deck cannot reach you.
var _wire_used := false # The rig is good for one pass per set.
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
var _notes_read := {}
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
var pause_ui: CanvasLayer
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
## Takes crossed inside the light's patience, and how many spare MARKs that has
## bought this set. Reset whenever the spare pays out.
var _fast_legs := 0
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
## The key light, kept so a later act can lose the day.
var _sun: DirectionalLight3D
var _env: Environment
var _notice := ""
var _notice_left := 0.0
var _killer_mark: Node3D = null
var _cut_velocity := Vector3.ZERO
var _rng := RandomNumberGenerator.new()

var _foley := preload("res://scripts/ui/foley.gd").new()

func _ready() -> void:
	Engine.time_scale = 1.0 # A previous hit-stop must never outlive its run.
	add_child(_foley)
	desk = load("res://scripts/relay/cutting_desk.gd").new()
	add_child(desk)
	desk.picked.connect(_pick_card)
	slate = SlateUI.new()
	slate.name = "Slate"
	add_child(slate)
	pause_ui = load("res://scripts/relay/relay_pause.gd").new()
	pause_ui.name = "Pause"
	add_child(pause_ui)
	pause_ui.resumed.connect(func() -> void: _refresh())
	pause_ui.left_run.connect(_to_title)
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
		# The first set is the tutorial: the same dolly, running slow enough that
		# a player can watch it cross once and then walk through the gap.
		segments.append($Rooms.append_room("straight",0,"",false,"",0.72))
		# The opening set is the short one: two legs, one dolly, nothing else.
		required_passes = _slot_passes()
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
	_sun = sun
	_env = env
	_act_light()
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
	# The length of the job is on the title's start caption and in the pause page.
	# It is not the first thing to say here: the first thing is "walk to the line",
	# and two notices on top of each other is how a tutorial stops being read.

func _w(zh: String, en: String) -> String:
	return zh if Loc.language == "zh" else en

## The way out and the way back are not the same walk. Going out the lamp sits on
## the south wall, coming back it sits on the north one, so the return trip is a
## different read of the same floor instead of a mirror of the first leg.
## Where the light line points, off centre so out and back are not the same line.## It has to fit inside the grip throat: the grips sit at |z| 1.32 (2.16 − 0.84)
## on normal sets and 0.78 on throat sets, and the player is 0.32 wide.
const LANE := 0.40

## A take crossed faster than this counts as one the crew did not have to wait
## for. Pure generosity: missing it costs nothing, and the set pays either way.
const LIGHT_TARGET := 5.5

## The spare MARK pays when every pass of the set was quick enough.
static func _won_light(fast: int, need: int) -> bool:
	return need > 0 and fast >= need


func _start_leg(back: bool) -> void:
	returning = back
	route.clear()
	var room_node := $Rooms.get_child(segments.size() - 1) as Node3D
	# The lamp sits on one wall going out and the other coming back, so the return
	# trip is a different read of the floor instead of a mirror of the first leg.
	# It is built in the room's own frame: the crew may have turned the set.
	# The room says where its doors are; the light line and the crossing test read
	# the same plan, so a set may put its exit off the centre line.
	var ri := segments.size() - 1
	var plan: Dictionary = $Rooms.plan(ri)
	var local: Vector3 = plan.get("entry", Vector3(0.0, 0.05, 0.0)) if back else plan.get("exit", Vector3(SET_LENGTH, 0.05, 0.0))
	local.z += LANE if back else -LANE
	route.append(room_node.to_global(local) if room_node != null else local)
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
	_clear_killer_mark()
	score.resume_beds() # The room comes back with the new take.
	score.set_family(str((segments.back() as Dictionary).get("kind", "")))
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
	_show_notice(_w(zh, en), 3.5)


## Same line, every time it happens (the wire is not a tutorial).
func _show_notice(text: String, seconds := 3.0) -> void:
	_notice = text
	_notice_left = seconds


## Everything a run remembers, in the order it was paid for.
func _serialize_run() -> Dictionary:
	var plan: Array = []
	for s in segments:
		plan.append({"kind": str(s.get("kind","")), "variant": int(s.get("variant",0)),
			"mod": str(s.get("mod","")), "final": bool(s.get("final", false)),
			"event": str(s.get("event",""))})
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
		segments.append($Rooms.append_room(str(r.get("kind","straight")), int(r.get("variant",0)),
			str(r.get("mod","")), bool(r.get("final", false)), str(r.get("event",""))))
	leg_event = str((segments.back() as Dictionary).get("event","")) if not segments.is_empty() else ""
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
		"cursor":cursor,"time":elapsed,"pass":room_pass,"cam_motion":rig.mark_motion(),"cam_yaw":rig.yaw,
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
	player.teleport(_clear_spot(p.pos), p.facing)
	rig.setup(player)
	rig.restore_mark_motion(p)
	_sample()
	last_anchor = i
	_restart_actors()
	_arm_mercy()
	_riding = false
	_wire_used = false
	desk.clear_sheet()
	score.resume_beds()
	# A respawn you cannot act on is not a respawn. The checkpoint is where the
	# take was, not a promise that the truck has left it.
	grace = maxf(act_grace, 2.0)
	_arrival_locked = player.global_position.distance_to(route[cursor]) <= TOUCH
	_show_target()

## Nudges a respawn out of whatever is standing on it. Being put back down inside
## a passing truck is what a player reads as "the controls stopped working", and
## three of those in a row is a bug report, not a difficulty curve.
## The first two sets are the tutorial, and the tutorial is four sentences shown
## when the thing they describe is on screen. Nothing here is a menu.
func _first_lessons() -> void:
	if phase != Mode.PLAY or act > 0 or segments.size() > 2: return
	if elapsed > 0.8 and not returning:
		_hint("lesson_line", "走到亮起来的那条线。", "Walk to the line that is lit.")
	if returning and elapsed > 0.8:
		_hint("lesson_back", "过了。回头，走到另一头那条线。", "Across. Now turn around for the line at the far end.")
	if returning and tracks.size() >= 1:
		_hint("lesson_ghost", "迎面过来的是你上一趟的录像。撞上就死。", "That is your last take, walking back. Touch it and you are done.")
	if not returning and tracks.size() >= 1:
		_hint("lesson_cut", "按 C 能看一眼自己留下的落点。看片不要钱。", "C shows where your own takes stopped. Looking is free.")
	if not returning and tracks.size() >= 2:
		_hint("lesson_mark", "M 在这里留一个落点。失手会自动回到最近的落点。", "M leaves a mark here. A collision returns you to the last one.")

func _clear_spot(pos: Vector3) -> Vector3:
	var room_index := segments.size() - 1
	if room_index < 0: return pos
	for dz: float in [0.0, 0.55, -0.55, 1.05, -1.05]:
		for dx: float in [0.0, 0.5, -0.5, 1.0, -1.0]:
			var spot := pos + Vector3(dx, 0.0, dz)
			if $Rooms.hazard_at(spot, room_index, elapsed): continue
			if $Rooms.crew_at(spot, room_index): continue
			if $Rooms.goof_at(spot, room_index): continue
			return spot
	return pos

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
	# Chasing the light: a take crossed inside LIGHT_TARGET counts as one the crew
	# did not have to wait for. Clear a whole set that way and the crew hands you a
	# spare. No penalty for being slow — the light is an offer, not a clock.
	if elapsed <= LIGHT_TARGET:
		_fast_legs += 1
	if _won_light(_fast_legs, required_passes):
		_fast_legs = 0
		mark_stock += 1
		_show_notice(_w("这一棚抢下天光。多给你一枚打点。", "You beat the light. One spare MARK."), 2.5)
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
		_act_light()
		cards = _offer_contracts()
		score.cue("clear")
		score.set_act(act)
		desk.show_draw(cards, Loc.language == "zh")
		desk.show_message(_w("第 %d 节。签一张。" % (act + 1), "Act %d. Sign one." % (act + 1)))
		_hint("act_%d" % act, _act_line(act, true), _act_line(act, false))
	else:
		phase = Mode.ITEM
		score.cue("clear")
		desk.show_items(Loc.language == "zh")
		_hint("lesson_item", "先拿一件东西，再选下一棚。", "Take one thing, then pick the next set.")

## The last line of the run. A wrap is loud on purpose: the run's whole promise
## is that the crossing is worth the takes it cost.
func _finish_line() -> void:
	score.resume_beds()
	slate.play_wrap(_w("全部接通", "ANSWER PRINT"), _w("这一卷是你的", "this reel is yours"))
	rig.add_shake(0.7)
	fx.flash(Color("ffeec4"), 0.46, 0.06, 0.42)
	_hint("finish", "冲线。这一卷是你的。", "Across the line. This reel is yours.")
	# The board closes first and the clack answers it; the four rising notes come
	# in behind that, so the last thing under the gate is the score, not the UI.
	get_tree().create_timer(0.34).timeout.connect(func() -> void: score.cue("win"))
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

## Three doors, and the choice is never "how much walking": the length is the
## set's place in the act. What the doors sell is what the crew does to the floor
## and what the set pays for it.
func _slot_passes() -> int:
	return LONG_PASSES if segments.size() % SETS_PER_ACT == SETS_PER_ACT - 1 else SHORT_PASSES


## Which things the crew is allowed to do to set number `tier` (0 = the first set
## after the opener). The first two sets stay quiet on purpose: the creator played
## this and said his head was going to explode by the third act, so the shop opens
## one drawer at a time. Set 1 is clean, set 2 may only offer a guide (a ghost that
## demonstrates and cannot kill), then the basic three, then everything.
static func _event_pool_for(tier: int) -> Array:
	if tier <= 0:
		return [""]
	if tier == 1:
		return ["", "", "guide"]
	var pool: Array = (EVENT_POOL.slice(0, 3) if tier < 2 else EVENT_POOL).duplicate()
	return pool


func _offer_doors() -> Array:
	var tier := segments.size() - 1
	var deck := KINDS.duplicate()
	# Later acts pull from the whole shop, not the three the first act knows, and
	# by then the crew is willing to dress one set with two things at once.
	var pool: Array = _event_pool_for(tier)
	var events: Array = []
	for k in 2:
		events.append(str(pool.pop_at(_rng.randi_range(0, pool.size() - 1))) if not pool.is_empty() else "")
	var passes := _slot_passes()
	var rewards: Array = ["", "mark", "cut" if tier >= 2 else "splice"]
	var out: Array = []
	for slot in 3:
		var ev := "" if slot == 0 else str(events[slot - 1])
		if ev != "" and tier >= 2 and _rng.randf() < 0.55:
			var second: String = str(pool.pop_at(_rng.randi_range(0, pool.size() - 1)))
			if second != "":
				ev = ev + "," + second
		var door := {"kind": deck.pop_at(_rng.randi_range(0, deck.size() - 1)),
			"variant": _rng.randi_range(0, 1), "mod": _roll_mod(tier, slot),
			"passes": passes, "reward": str(rewards[slot]),
			"event": ev}
		door["mod_label"] = _mod_label(str(door["mod"]))
		if str(door["event"]) != "":
			var tag := _events_short(str(door["event"]))
			door["mod_label"] = tag if str(door["mod_label"]) == "" else (str(door["mod_label"]) + " · " + tag)
		door["stake_label"] = _stake_label(int(door["passes"]), str(door["reward"]), str(door["event"]))
		door["stamp"] = _reward_stamp(str(door["reward"]))
		door["turn_note"] = _turn_note(str(door["kind"]))
		out.append(door)
	return out


## What the shape does after the crew rebuilds the set the other way round. This
## is the second half of every door: a set you already know is not the same wager
## as a set that will flip under you the moment you die in it.
func _turn_note(kind: String) -> String:
	var zh := Loc.language == "zh"
	match kind:
		"i":
			return "转过来也一样" if zh else "turns to the same set"
		"l":
			return "转过来换一角" if zh else "the corner moves"
		"o":
			return "转过来换半边" if zh else "the other side of the ring"
		"h":
			return "转过来换两条道" if zh else "the two lanes swap"
		"s":
			return "转过来换两道弯" if zh else "both bends swap"
		_:
			return ""


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


func _stake_label(passes: int, reward: String, _event := "") -> String:
	# One short line: the card is 196 px wide, so the price has to read at a
	# glance rather than spell itself out.
	var base := _w("%d 趟", "%d legs") % passes
	match reward:
		"mark": return base + _w(" · +1 MARK", " · +1 MARK")
		"cut": return base + _w(" · +1 CUT", " · +1 CUT")
		"splice": return base + _w(" · 接片", " · splice")
	return base + _w(" · 无补给", " · none")


func _reward_stamp(reward: String) -> String:
	# The stamp is the price tag on the call sheet, so it has to say what the
	# door actually hands over — a paper that reads "no supply" while the cost
	# line says "+1 MARK" is a lie on paper.
	match reward:
		"mark": return "+1 MARK"
		"cut": return "+1 CUT"
		"splice": return _w("接片", "SPLICE")
	return _w("无补给", "NO SUPPLY")


func _event_short(event: String) -> String:
	match event:
		"relight": return _w("带灯", "lamped")
		"extra": return _w("多一台车", "extra dolly")
		"guide": return _w("旧我示范", "ghost walks it")
		"belt": return _w("有传送带", "on a belt")
		"runner": return _w("有人在跑", "a runner")
		"goof": return _w("地上有胶带", "taped off")
		"key": return _w("有绿幕", "keyed")
		"mezz": return _w("搭了二层", "catwalk")
		"double": return _w("有替身", "stand-in")
		"wire": return _w("有威亚", "on a wire")
	return ""


## A door can promise more than one thing the crew did to the set; the label has
## to say all of them, or the card is lying about what you are walking into.
func _events_short(event: String) -> String:
	var out := ""
	for id in event.split(",", false):
		var tag := _event_short(id)
		if tag == "": continue
		out = tag if out == "" else (out + " · " + tag)
	return out


func _event_lines(event: String, zh: bool) -> String:
	var out := ""
	for id in event.split(",", false):
		var line := _event_line(id, zh)
		if line == "": continue
		out = line if out == "" else (out + "\n" + line)
	return out

func _mod_label(mod: String) -> String:
	match mod:
		"fast": return _w("快车 · 推轨更快", "FAST · quicker dolly")
		"twin": return _w("双推轨 · 两台车", "TWIN · two dollies")
		"throat": return _w("窄喉 · 口子更窄", "THROAT · narrower mouth")
		"clean": return _w("空棚 · 没有车", "EMPTY · no dolly")
	return ""


## One room in three has something the crew did to it today. Each one changes
## how you read the set, not how hard the numbers are.
func _roll_event() -> String:
	if segments.size() <= 1: return "" # The first set teaches the floor; leave it plain.
	var r := _rng.randf()
	if r < 0.16: return "relight"
	if r < 0.32: return "extra"
	if r < 0.40: return "guide"
	if r < 0.52: return "belt"
	if r < 0.64: return "runner"
	if r < 0.73: return "goof"
	if r < 0.83: return "key"
	if r < 0.92: return "mezz"
	if r < 1.01: return "double"
	return ""


func _event_line(event: String, zh: bool) -> String:
	match event:
		"relight": return _w("剧组换了灯：灯现在挂在推轨上。", "The crew relamped: the light rides the dolly.") if zh else "The crew relamped: the light rides the dolly."
		"extra": return "临时加了一条推轨。" if zh else "A dolly was rented for this set."
		"guide": return "这一次，上一次的你不碰人，它只是先走一遍。" if zh else "This take your past does not touch you. It shows the way."
		"belt": return "甲板上铺了一条传送带。它听棚的，不听你的镜头。" if zh else "There is a belt on the deck. It answers to the set, not to your lens."
		"runner": return "场务在跑。他不会为你停。" if zh else "A runner is crossing. He will not stop for you."
		"goof": return "地上贴了胶带。站进去，这一条就废了。" if zh else "The deck is taped off. Stand in it and the take is gone."
		"double": return "剧组留了一个替身站在那条轨道上。推轨会先撞他，停一拍。" if zh else "A stand-in was left on the track. The dolly hits him first and stalls a beat."
		"key": return "绿幕那一块不在画面里。站上去，谁都碰不到你。" if zh else "The key square is not in the plate. Stand on it and nothing can touch you."
		"mezz": return "这一棚搭了二层。车从下面过。" if zh else "This set has a catwalk. The dolly goes under you."
		"wire": return "甲板上画了一块。站上去，剧组把你吊到那一头。" if zh else "A mark is painted on the deck. Stand on it and the crew flies you across."
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
		_hint("lesson_pick", "这三张是下一棚。按 1 / 2 / 3 或点一下。", "Three sets for the next one. Press 1 / 2 / 3 or click.")
		_refresh()
		return
	if phase != Mode.PICK or i < 0 or i >= cards.size(): return
	var c: Dictionary = cards[i]
	var last := segments.size() == MODULES - 1
	leg_event = str(c.get("event", ""))
	if last and leg_event == "":
		# The last set never plays clean: it is the one where you either cross or
		# do not, so the crew always adds something to it.
		leg_event = "extra" if _rng.randf() < 0.5 else "relight"
	# The last two sets are the endgame: the crew speeds the dollies up before it
	# starts dressing them, so the last set is faster *and* busier.
	var hurry := 1.0
	if last: hurry = 1.25
	elif segments.size() >= MODULES - 2: hurry = 1.12
	var room: Dictionary = $Rooms.append_room(c.kind,c.variant,str(c.get("mod","")),last,leg_event,hurry)
	segments.append(room)
	if leg_event != "":
		_hint("event_" + leg_event, _event_lines(leg_event, true), _event_lines(leg_event, false))
	required_passes = int(c.get("passes", _slot_passes()))
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

## The rig is a one-way trip: you are hooked at the painted mark and set down at
## the far post. No steering, no second pass — the decision is whether to take it.
func _start_wire_ride() -> void:
	var ride: Dictionary = $Rooms.wire_ride(segments.size()-1)
	if ride.is_empty(): return
	_riding = true
	_wire_used = true
	player.set_frozen(true)
	rig.set_physics_process(false)
	_show_notice(_w("剧组把你吊过去了。","The crew flies you across."), 2.0)
	var a: Vector3 = ride["from"]
	var b: Vector3 = ride["to"]
	player.global_position = a
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		player.global_position = a.lerp(b, t), 0.0, 1.0, 2.4)
	tw.tween_callback(_end_wire_ride)

func _end_wire_ride() -> void:
	_riding = false
	if not is_instance_valid(player): return
	player.global_position = Vector3(player.global_position.x, 0.05, player.global_position.z)
	player.set_frozen(false)
	rig.set_physics_process(true)
	grace = maxf(grace, 0.35)
	_show_target()

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
	# On the wire you are not walking: the rig carries you in a straight line and
	# nothing on the deck can reach you until it sets you down.
	if not _riding and not _wire_used and $Rooms.wire_at(player.global_position, segments.size()-1):
		_start_wire_ride()
		return
	if _riding: return
	# The catwalk is a height, not a jump: the walking surface is whatever the
	# room says it is at this point, and you follow it up and down the ramps.
	var floor_h: float = $Rooms.floor_height(player.global_position, segments.size()-1)
	player.global_position.y = lerpf(player.global_position.y, floor_h + 0.05, clampf(dt*14.0, 0.0, 1.0))
	# The deck can be doing something to you. The belt answers to the set, so a
	# turned set carries you the other way without any new rule.
	player.set_push($Rooms.belt_push(player.global_position, segments.size()-1))
	# On the green screen's key square you are not in the plate: the crew, the
	# dolly and your own past all pass through where you are standing.
	var keyed: bool = $Rooms.key_at(player.global_position, segments.size()-1)
	if grace <= 0 and not keyed:
		var reach: float = Ghost.DANGER_RADIUS + Player.RADIUS
		for g in _actors:
			# "guide": the past self walks the route and nobody dies from it. The
			# set is asking you to watch a crossing before you have to make one.
			if leg_event.split(",", false).has("guide"): break
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
		# The runner is not a trap with a rhythm: he crosses the set because his
		# business is on the other side, and he will not wait for your take.
		if $Rooms.crew_at(player.global_position,segments.size()-1):
			if _hit(2): return
		# The tape is not a threat: standing in it just means this take cannot be
		# printed, which costs exactly the same as being hit — one more walk.
		if $Rooms.goof_at(player.global_position,segments.size()-1):
			if _hit(3): return
	# The line is read in the room's own frame, not in world x: once the crew turns
	# the set the finish line is no longer the same wall, and a world-axis test
	# would count the crossing the moment the room moved.
	var ri_now := segments.size() - 1
	var inside: bool = $Rooms.crossed(player.global_position, ri_now, returning)
	if not inside: _arrival_locked = false
	if inside and not _arrival_locked:
		cursor += 1
		# Crossing is the one thing you do hundreds of times: it gets a mark, not
		# a celebration. A short cool wash, no sound, no number on screen.
		fx.flash(Color("9ceccb"), 0.10, 0.0, 0.12)
		if cursor == route.size():
			_finish_leg()
			return
		_checkpoint(false)
		_show_target()
	_track_gaps()
	_first_lessons()
	_read_note()
	_refresh()

## The only lore in the game: a call note left on the deck. One per set, read by
## walking over it, said once, never repeated in that run.
func _read_note() -> void:
	if not $Rooms.note_at(player.global_position, segments.size() - 1): return
	var key := segments.size()
	if _notes_read.has(key): return
	_notes_read[key] = true
	var lines := [
		"通告：今天补第一条。上一条被剪了，剪的人没留名。",
		"地上那圈胶带是昨天的走位。标得比你准。",
		"灯不够了。场务说再拍两条就收，他没说拍不拍得完。",
		"门那头是交货口。过线，这一卷就不是你的了。",
	]
	var en := [
		"Call sheet: one take to reshoot today. The last one was cut, and nobody signed it.",
		"The tape on the deck is where they stood yesterday. They stood it better.",
		"Not enough light left. The gaffer says two more takes, and does not say two more of what.",
		"Past that door is the delivery bay. Cross the line and this reel is somebody else's.",
	]
	_show_notice(_w(lines[clampi(act, 0, 3)], en[clampi(act, 0, 3)]), 5.0)

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

## Stopping time for a tenth of a second is the cheapest way to say "that hit you".
## The timer ignores the time scale it is restoring, otherwise it would freeze too.
func _punch() -> void:
	if Engine.time_scale < 1.0: return
	Engine.time_scale = 0.22
	get_tree().create_timer(0.14, true, false, true).timeout.connect(_unpunch)

func _unpunch() -> void:
	Engine.time_scale = 1.0

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
	# The frame stops for a beat. Long enough to feel hit, short enough that it
	# never reads as a stutter — and it runs on real time so the card is not
	# slowed down with it.
	_punch()
	_drop_photogram(player.global_position, player.facing)
	_mark_killer(player.global_position)
	if difficulty > 0:
		forced_cut = cut_stock > 0
		phase = Mode.CUT if forced_cut else Mode.LOST
		_selected = last_anchor
		_freeze()
		_board_die()
		_rotate_stage()
		_show_target()
		if phase == Mode.CUT: _show_preview()
		else:
			Save.clear()
			_show_sheet(false)
	else:
		_board_die()
		# You get to look at where it happened before the run puts you back:
		# restoring first meant the death spot sat behind the card or off screen.
		_hint("first_death", "撞上就重来一条，别的什么都不扣。", "A collision costs one take and nothing else.")
		desk.show_message(_death_line(source))
		_hold_until_board()
		_after_death()
	return true


## The call sheet. Win or lose, a run ends with one page that says what it was:
## how far, how many takes, how many deaths, and the seed to replay it.
func _show_sheet(won: bool) -> void:
	if not is_inside_tree(): return
	# The run is over, so the board gets out of the way instead of printing the
	# DIE. card over the page that explains what the run was.
	if slate.is_running(): slate.hide_slate()
	var prev_best: int = int(Rules.meta().get("best_set", 0))
	if not _recorded:
		_recorded = true
		Rules.record_run(segments.size(), deaths, won, run_seed)
	var lines: Array = [
		_w("走完 %d / %d 棚　　废条 %d　　死亡 %d", "SETS %d / %d   WASTED %d   DEATHS %d") % [segments.size(),MODULES,maxi(tracks.size()-segments.size(),0),deaths],
		_w("手上还剩　标记 %d　剪 %d", "LEFT   MARKS %d   CUTS %d") % [mark_stock,cut_stock],
		_w("种子 %06X", "SEED %06X") % run_seed,
		_w("空格：再来一局　R：同种子重开", "SPACE: new run   R: same seed"),
	]
	# The only thing this game keeps between runs is how far you got. Saying it out
	# loud is the whole progression: there is no tree, no currency, no unlocks.
	if segments.size() > prev_best:
		lines.insert(0, _w("走得最远的一次。", "The furthest you have been."))
	if won:
		desk.show_call_sheet(_w("全部接通","ANSWER PRINT"), lines, true, Loc.language == "zh")
	else:
		lines.insert(0,_w("最后一趟没走出来。","The last take never made it out."))
		# The story of a failed run is one sentence: the take was wasted, the crew
		# keeps going, you come back and shoot it again.
		lines.insert(1,_w("这条废了。场务会剪掉它，明天再来一条。","That take is wasted. The crew will cut it, and you shoot again tomorrow."))
		desk.show_call_sheet(_w("这卷到头了","END OF REEL"), lines, false, Loc.language == "zh")

## ESC is the only key that stops the clock. Everything else in this game is a
## decision about the take; this one is a decision about the person playing it.
func _open_pause() -> void:
	if pause_ui == null: return
	if pause_ui.is_open:
		pause_ui.close()
		_refresh()
		return
	pause_ui.briefing = {
		"set": segments.size(),
		"sets": MODULES,
		"pass": mini(room_pass + 1, required_passes),
		"passes": required_passes,
		"seed": run_seed,
		"deaths": deaths,
	}
	pause_ui.refresh()
	pause_ui.open()

func _to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/front/title.tscn")

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
			KEY_ESCAPE:
				_open_pause()
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
	desk.set_hud_scale(float(GameSession.settings.get("hud_scale", 1.0)))
	desk.update_run(segments.size(),MODULES,mini(room_pass+1,required_passes),required_passes,mark_stock,cut_stock,splice.has_splice(),zh)
	_hud.visible = phase == Mode.CUT
	if _hud.visible:
		var p := anchors[_selected]
		var tag := ("MARK %d" % int(p.get("number",0))) if p.manual else _w("起点","START")
		# What the CUT costs, in seconds you already walked, and in passes you
		# gave back. Looking is free; this line is the only place the price shows.
		var lost := maxf(elapsed - float(p.time), 0.0)
		var back := maxi(room_pass - int(p.get("pass", room_pass)), 0)
		var price := _w("剪回去：少 %.1f 秒走位" % lost, "SPLICE BACK: %.1f s of walking" % lost)
		if back > 0:
			price += _w("，本棚回到第 %d 趟" % (back + 1), ", back to pass %d" % (back + 1))
		_hud.text = _w("剪辑台　↑ ↓　%02d / %02d", "CUT DESK   ↑ ↓   %02d / %02d") % [_selected+1, anchors.size()] + "\n%s · TAKE %02d · %.1fs\n" % [tag,p.leg,p.time] + price + "\n" + _w("空格：剪回　−1 CUT", "SPACE: splice   −1 CUT")
	if _notice_left > 0:
		desk.show_message(_notice)
		_notice_left = 0

## The board, three ways. It never changes state itself: it names what just
## happened and gets out of the way, so the player learns one object for all of
## ROLL, CUT and DIE.
func _board_roll() -> void:
	var n := maxi(live.take_id,1)
	score.duck(true)
	# The premise, in the place the player is already looking: you are not the
	# first one shooting this take, and nobody on the floor will stop for you.
	slate.play_roll(n, _w("第 %02d 条" % n, "TAKE %02d" % n),
		_w("你是来补拍的。原来那条，废了。\n棚子每晚换搭，站进镜头的只有几个。",
			"You are here to reshoot. The take before this was ruined.\nThe set is rebuilt every night, and only a few will stand in it."))


## 抢天光: the day is going. Each act the key light drops and warms, so the last
## act is shot at the end of the afternoon — long shadows, and whatever lamps the
## crew hung on the set become the light you can actually read.
func _act_light() -> void:
	if _sun == null: return
	var t := clampf(float(act) / float(maxi(ACTS - 1, 1)), 0.0, 1.0)
	_sun.light_energy = lerpf(1.0, 0.56, t)
	_sun.light_color = Color("fff6e6").lerp(Color("ffb877"), t)
	if _env != null:
		_env.ambient_light_energy = lerpf(0.80, 0.60, t)


## The cause of a death, in one line, the way a set would say it out loud.
func _death_line(source: int) -> String:
	if source == 0:
		return _w("推轨没有看见你。", "The dolly did not see you.")
	if source == 2:
		return _w("你撞上了场务。他手里还拿着通告。", "You hit the runner. He was holding the call sheet.")
	if source == 3:
		return _w("你踩进了画面。这条废了。", "You stepped into the shot. This take is gone.")
	return _w("你撞上了第 %02d 条的你。" % source, "You hit your take %02d." % source)


## A floor announcement at the top of an act: where the run stands, in one line.
func _act_line(n: int, zh: bool) -> String:
	match n:
		1: return "第二场。场务开始记账了。" if zh else "Act two. The floor starts keeping score."
		2: return "第三场。这一条要交片。" if zh else "Act three. This take has to print."
	return ("第 %d 场。" % (n + 1)) if zh else ("Act %d." % (n + 1))

func _board_cut() -> void:
	var n := maxi(live.take_id,1)
	score.duck(true)
	slate.play_cut(n, _w("第 %02d 条" % n, "TAKE %02d" % n))

## A death is when the crew rebuilds: the set is turned end for end, and the ghost
## that killed you keeps walking the way it was walking. The floor turns around
## its own centre, so whoever stands on it stays on the same plank.
##
## It turns 180°, not 90°: a set is 9 × 6, so a quarter turn would swing half the
## floor (and every ghost recorded on it) out into the dark. Half a turn keeps the
## footprint, keeps the ghosts standing on deck, and reads as "they rebuilt it the
## other way round". Quarter turns come back when the sets get square footprints.
const SET_LENGTH := 9.0
const SET_TURN := PI
var _turn_room: Node3D
var _turn_center := Vector3.ZERO
var _turn_local_player := Vector3.ZERO
var _turn_local_target := Vector3.ZERO


func _rotate_stage() -> void:
	if phase != Mode.PLAY and phase != Mode.CUT: return
	if segments.is_empty(): return
	var room := $Rooms.get_child(segments.size() - 1) as Node3D
	if room == null: return
	set_meta("turned", int(get_meta("turned", 0)) + 1)
	_turn_room = room
	_turn_center = room.global_transform * Vector3(SET_LENGTH * 0.5, 0.0, 0.0)
	_turn_local_player = room.to_local(player.global_position)
	_turn_local_target = room.to_local(route[cursor])
	var a0 := room.rotation.y
	var tw := create_tween()
	tw.tween_method(_apply_stage_angle, a0, a0 + SET_TURN, 0.45)
	rig.add_shake(0.35)
	fx.flash(Color("cfd6e0"), 0.16, 0.02, 0.20)
	score.cue("choose")


func _apply_stage_angle(a: float) -> void:
	if _turn_room == null or not is_instance_valid(_turn_room): return
	var off := Vector3(SET_LENGTH * 0.5, 0.0, 0.0)
	var turn := Basis(Vector3.UP, a)
	_turn_room.rotation.y = a
	# Keep the set's centre where it was. Rotating about the room's own origin
	# would swing the whole stage out from under whoever is standing on it.
	_turn_room.global_position = _turn_center - turn * off
	var room_xform := _turn_room.global_transform
	player.global_position = room_xform * _turn_local_player
	route[cursor] = room_xform * _turn_local_target
	if _lamp.visible: _lamp.position = route[cursor] + Vector3.UP * 0.10


## The frame you died on, printed on the floor of the set. It is dressing, not
## geometry: nothing collides with it, and it turns with the stage.
func _drop_photogram(pos: Vector3, facing: float) -> void:
	if segments.is_empty(): return
	var room := $Rooms.get_child(segments.size() - 1) as Node3D
	if room == null: return
	var print := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(0.86, 1.42)
	print.mesh = quad
	print.name = "Photogram"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.93, 0.78, 0.22)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	print.material_override = mat
	room.add_child(print)
	var flat := Basis(Vector3.UP, facing) * Basis(Vector3.RIGHT, -PI * 0.5)
	print.global_transform = Transform3D(flat, pos + Vector3.UP * 0.012)

## Where it happened. The death line says who; this says exactly where, so a
## player can look at the frozen frame and answer both questions without moving.
## It fades out on its own — it is a mark on the floor, not a new object to learn.
func _mark_killer(pos: Vector3) -> void:
	_clear_killer_mark()
	var mark := Node3D.new()
	mark.name = "KillerMark"
	var ring := MeshInstance3D.new()
	var band := TorusMesh.new()
	band.inner_radius = 1.16
	band.outer_radius = 1.26
	band.rings = 48
	ring.mesh = band
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Chalk white, not red: the set is already full of red props, so a red halo
	# reads as scenery. Nothing else on the floor is this colour at this size.
	mat.albedo_color = Color(1.0, 0.96, 0.88, 0.85)
	ring.material_override = mat
	ring.position = Vector3(0.0, 0.02, 0.0)
	mark.add_child(ring)
	add_child(mark)
	mark.global_position = Vector3(pos.x, 0.055, pos.z)
	_killer_mark = mark
	# Stays readable for the whole death card, then leaves on its own.
	var tw := create_tween()
	tw.tween_method(func(a: float) -> void: mat.albedo_color.a = a, 0.85, 0.70, 1.0)
	tw.tween_method(func(a: float) -> void: mat.albedo_color.a = a, 0.70, 0.0, 0.5)
	tw.tween_callback(mark.queue_free)

func _board_die() -> void:
	var n := maxi(live.take_id,1)
	score.duck(true)
	slate.play_die(n, _w("第 %02d 条" % n, "TAKE %02d" % n))


func _clear_killer_mark() -> void:
	if is_instance_valid(_killer_mark):
		_killer_mark.queue_free()
	_killer_mark = null


## Runs on its own: the death card finishes first, so the player sees the frame
## they lost before the run hands the controls back at the checkpoint.
func _after_death() -> void:
	if slate.is_running():
		await slate.sequence_finished
	_restore(last_anchor)
	_rotate_stage() # A death is a rebuild: the set turns under you.
	_show_target()


## Hold the controls until the board is gone. A respawn that hands you a frozen
## screen and a live keyboard at the same time is how a fair death becomes a
## blind one.
func _hold_until_board() -> void:
	if not slate.is_running(): return
	var was_frozen := player.frozen
	player.set_frozen(true)
	rig.set_physics_process(false)
	await slate.sequence_finished
	_clear_killer_mark() # The mark lives exactly as long as the death card.
	if phase == Mode.PLAY:
		player.set_frozen(was_frozen)
		rig.set_physics_process(true)
