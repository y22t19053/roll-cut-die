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
const TouchPad = preload("res://scripts/relay/touch_pad.gd")
const ToyBridge = preload("res://scripts/relay/toy_bridge.gd")
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
## A run is a seed and twelve sets in four acts: the seed is printed on the call
## sheet so two runs can be compared, replayed or argued about.
static var next_seed := 0## A run that was written down between takes. The title screen decides whether
## New Game starts fresh or Continue picks this up.
static var pending_resume := {}
var run_seed := 0
## How many legs the current set asks for. A short set is faster; a long one
## pays a supply. This is the run's only real decision.
var required_passes := PASSES
## Which act of four the run is in, what was signed at the last seam, and how
## much grace that act allows. Nothing else changes between acts.
var act := 0
var act_mod := ""
var act_grace := GRACE
var leg_event := "" # How the crew dressed this set: relight / extra / guide.
var _riding := false # On the wire: input is gone and the deck cannot reach you.
var _wire_used := false # The rig is good for one pass per set.
# One death, one card. Without this the same ghost could bill you every frame
# while the board was still talking, which stacked respawns until nothing moved.
var _dying := false
# For a moment after a respawn the past is not allowed to bill you twice: while a
# ghost is still standing in the spot you were put down on, the grace keeps being
# topped up instead of expiring into another card.
var _safe_until := 0.0
## The first splice of a run is free: the player has to feel what a CUT costs
## before it can cost them anything.
var free_cut := 1
## A run is only written down in the record book once, however often the sheet
## ends up on screen.
var _recorded := false
## What this run was worth, and what the board said about it. Both are decided
## once, when the sheet goes up: a score that kept changing while the page was
## being read would be a number nobody could argue about.
var score_info := {}
var _score_sent := false
var _bridge: Node = null
## Cuts that actually cost a supply. The free first splice is a lesson, not a
## decision, so it is not on the bill.
var cuts_used := 0
## Takes crossed once the prologue was over: what the score is made of.
var run_legs := 0
var _seen_hints := {}
## Ghosts the tape handed you back inside of. They stop counting until you
## step out: a respawn is never the player's mistake.
var _inside := {}
var _notes_read := {}
var _spot_played := false
var _ghost_passed := false
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
var touch: Node2D
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

## The first four sets are a prologue, not part of the run: one thing per set, no
## doors, no events the player has not been told about. They are counted in
## `segments` like everything else, so `_prologue` is what keeps the HUD and the
## act ladder honest once the real run starts.
const TUTORIAL := [
	{"kind": "straight", "event": "", "hurry": 0.72},
	{"kind": "l", "event": "", "hurry": 1.0},
	{"kind": "s", "event": "belt", "hurry": 1.0},
	{"kind": "s", "event": "runner", "hurry": 1.0},
	{"kind": "h", "event": "", "hurry": 1.0},
	{"kind": "s", "event": "", "hurry": 1.0},
	{"kind": "l", "event": "mezz", "hurry": 1.0},
]
var _tutorial := 0      # index of the tutorial room being played; 0 once the prologue is over
var _tut_next := 1      # next tutorial room to build
var _prologue := 0      # how many sets belong to the prologue

func _in_prologue() -> bool:
	return _prologue == 0 and not segments.is_empty()

## Sets that count toward the run's four acts. During the prologue this is 0.
func _sets() -> int:
	return maxi(segments.size() - _prologue, 0)

var _foley := preload("res://scripts/ui/foley.gd").new()

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if is_instance_valid(_bridge):
		_bridge.set_process(false)
		if _bridge.get_parent() == null:
			_bridge.queue_free()
	# Parented helpers are freed with the run; release any detached previews.
	for helper: Node in [_preview_camera, _preview_rig, _preview_still, _preview_point]:
		if is_instance_valid(helper) and helper.get_parent() == null:
			helper.queue_free()


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
		# The prologue opens with the long straight: one dolly, running slow
		# enough to watch cross once, and nothing else to learn from it.
		segments.append($Rooms.append_room("straight",0,"",false,"",0.72))
		_tutorial = 0
		_tut_next = 1
		_prologue = 0
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
	# Touch controls sit above the set and under the cards: a thumb may never cover
	# a sheet the player is reading. Nothing here changes a rule — it sends the same
	# keycodes and the same four world directions.
	var pad_layer := CanvasLayer.new()
	pad_layer.name = "TouchLayer"
	pad_layer.layer = 6
	add_child(pad_layer)
	touch = TouchPad.new()
	touch.name = "TouchPad"
	touch.relay = self
	touch.player = player
	touch.rig = rig
	pad_layer.add_child(touch)
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
	# the same plan, so a set may put its exit off the centre line — or bend the
	# route with corner stops that are crossed one at a time.
	var ri := segments.size() - 1
	var plan: Dictionary = $Rooms.plan(ri)
	var entry: Vector3 = plan.get("entry", Vector3(0.0, 0.05, 0.0))
	var exitp: Vector3 = plan.get("exit", Vector3(SET_LENGTH, 0.05, 0.0))
	var mids: Array = plan.get("mids", [])
	if back:
		for i in range(mids.size() - 1, -1, -1):
			var m: Vector3 = mids[i]
			m.z = -m.z if m.z != 0.0 else m.z
			route.append(room_node.to_global(m) if room_node != null else m)
		var near := entry
		near.z += LANE
		route.append(room_node.to_global(near) if room_node != null else near)
	else:
		for m: Vector3 in mids:
			route.append(room_node.to_global(m) if room_node != null else m)
		var far := exitp
		far.z += -LANE
		route.append(room_node.to_global(far) if room_node != null else far)
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
	_spot_played = false
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
		"room_track_start": room_track_start, "act": act, "act_mod": act_mod, "act_grace": act_grace,
		"tutorial": _tutorial, "tut_next": _tut_next, "prologue": _prologue}


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
	_tutorial = int(d.get("tutorial", -1))
	_tut_next = int(d.get("tut_next", 0))
	_prologue = int(d.get("prologue", 0))
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
	# The card owed you one walk, and it is paid. Whatever happened while it was up
	# is not allowed to leave the keyboard dead.
	_dying = false
	_safe_until = active_clock + 4.0
	player.set_frozen(false)
	if phase == Mode.PLAY: rig.set_physics_process(true)
	_show_target()

## The first four sets are the tutorial, and the tutorial is what the room is doing
## to you right now, said once. Order matters more than wording: each line waits
## until the thing it names is on screen, and nothing is named before it is seen.
## Set 1 teaches the line, set 2 teaches M and C, set 3 introduces a deck that is
## not just a dolly, and set 4 (the drill) says nothing at all.
func _first_lessons() -> void:
	if phase != Mode.PLAY or not _in_prologue(): return
	if _tutorial == 0:
		if elapsed > 0.8 and not returning:
			_hint("lesson_line", "走到亮起来的那条线。", "Walk to the line that is lit.")
		if returning and elapsed > 0.8:
			_hint("lesson_back", "过了。回头，走到另一头那条线。", "Across. Now turn around for the line at the far end.")
		# The ghost is named only after it has walked past you once: naming it first
		# turns a curiosity into a rule, and the rule into a wall.
		if _ghost_passed:
			_hint("lesson_ghost", "刚才走过去的是你上一趟的录像。撞上就死。",
				"That one that just walked past was your last take. Touch it and you are done.")
	elif _tutorial == 1:
		if elapsed > 1.2:
			_demo_mark()
			_hint("lesson_mark", "刚才那个点是我替你钉的。按 M 就能自己钉一个。",
				"That mark was mine. Press M and you can leave your own.")
		if elapsed > 4.0:
			_hint("lesson_cut", "按 C 能看见你走过的这几条。看片不要钱。",
				"C shows the takes you have walked. Looking is free.")
	elif _tutorial == 2:
		if elapsed > 0.9:
			_hint("lesson_belt", "地上的带子在动。它听棚的，不听你。",
				"The deck is moving. It answers to the set, not to you.")
	elif _tutorial == 3:
		if elapsed > 0.9:
			_hint("lesson_runner", "有人在跑。他不会为你停。",
				"Somebody is walking through. He will not stop for you.")


## Builds the next prologue set and starts it. The plan is fixed on purpose: the
## opening sets are a lesson, and a lesson that rerolls is not a lesson.
func _build_tutorial_room() -> void:
	_freeze()
	_show_target()
	if _tut_next >= TUTORIAL.size():
		# The lesson is over. The sets already standing stay standing; the run
		# starts counting from whatever the player picks next.
		_prologue = segments.size()
		_tutorial = -1
		_tut_next = 0
		phase = Mode.ITEM
		score.cue("clear")
		desk.show_items(Loc.language == "zh")
		_hint("tut_over", "教完了。以后每棚会多一点东西，纸上会写。",
			"That is the lesson. From here the sets get stranger, and the paper says how.")
		_save_run()
		_refresh()
		return
	var plan: Dictionary = TUTORIAL[_tut_next]
	var room: Dictionary = $Rooms.append_room(str(plan["kind"]), 0, "", false,
		str(plan["event"]), float(plan["hurry"]))
	segments.append(room)
	_tutorial = _tut_next
	_tut_next += 1
	room_pass = 0
	required_passes = SHORT_PASSES
	leg_event = str(plan["event"])
	if leg_event != "":
		_hint("event_" + leg_event, _event_lines(leg_event, true), _event_lines(leg_event, false))
	player.teleport(room.start, 0.0)
	desk.hide_draw()
	score.set_family(str(plan["kind"]))
	_start_leg(false)


## Before telling anyone what M does, show one appearing at their feet. A mark is
## a small thing on a busy deck, and the sentence alone leaves them looking for it.
var _mark_demo := false

func _demo_mark() -> void:
	if _mark_demo: return
	_mark_demo = true
	var beacon := MarkBeacon.new()
	beacon.setup(1, to_local(player.global_position))
	beacon.scale = Vector3.ONE * 0.02
	add_child(beacon)
	var tw := create_tween()
	tw.tween_property(beacon, "scale", Vector3.ONE, 0.22)
	tw.tween_interval(0.85)
	tw.tween_property(beacon, "scale", Vector3.ONE * 0.02, 0.40)
	tw.tween_callback(beacon.queue_free)

## A death puts you back at the last mark, and the ghost that hit you may still be
## standing on it. For a few seconds after a respawn the grace is topped up while
## the past is within reach, so one death buys exactly one death instead of a card
## you cannot get out from under.
func _top_up_grace() -> void:
	if _safe_until <= 0.0: return
	if active_clock >= _safe_until:
		_safe_until = 0.0
		return
	var reach: float = Ghost.DANGER_RADIUS + Player.RADIUS + 0.05
	for g in _actors:
		if g.spent: continue
		if g.global_position.distance_to(player.global_position) < reach:
			grace = maxf(grace, 0.30)
			return

func _clear_spot(pos: Vector3) -> Vector3:
	var room_index := segments.size() - 1
	if room_index < 0: return pos
	var ghost_reach: float = Ghost.DANGER_RADIUS + Player.RADIUS + 0.15
	for dz: float in [0.0, 0.55, -0.55, 1.05, -1.05]:
		for dx: float in [0.0, 0.5, -0.5, 1.0, -1.0]:
			var spot := pos + Vector3(dx, 0.0, dz)
			if $Rooms.hazard_at(spot, room_index, elapsed): continue
			if $Rooms.crew_at(spot, room_index): continue
			if $Rooms.goof_at(spot, room_index): continue
			# Putting the player back inside the past is the same death again with
			# a card in front of it. Find a spot the recording is not standing on.
			var taken := false
			for g in _actors:
				if g.spent: continue
				if g.global_position.distance_to(spot) < ghost_reach:
					taken = true
					break
			if taken: continue
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
	# The prologue is teaching, not a run: its takes are real recordings but they
	# are not on the bill, and every player crosses them the same number of times.
	if not _in_prologue():
		run_legs += 1
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
	# The prologue hands the run over one set at a time and never asks a question:
	# no doors, no tray, no contract until the four lessons are done.
	if _in_prologue():
		_save_run()
		_build_tutorial_room()
		return
	if _sets() >= MODULES:
		phase = Mode.DONE
		_freeze()
		_show_target()
		Save.clear() # A finished run is not a run to come back to.
		if Rules.unlocked(difficulty): Rules.record_clear(difficulty)
		_finish_line()
		return
	_freeze()
	_show_target()
	if _sets() % SETS_PER_ACT == 0:
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
			"line1": _w("下一节宽限压到 0.3 秒", "next act: 0.3 s grace only"),
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
	# The card is up. Nothing on the deck is allowed to bill you again while it
	# is talking, or one ghost standing on the checkpoint bills you every frame.
	if _dying: return
	active_clock += dt
	elapsed += dt
	grace = maxf(grace-dt,0)
	_top_up_grace()
	_notice_left -= dt
	if elapsed >= _next_sample:
		_sample()
		_next_sample = elapsed + 0.10
	$Rooms.set_clock(segments.size()-1,elapsed)
	# Somebody else is in the room, and he notices you.
	$Rooms.notice_player(player.global_position, segments.size()-1, dt)
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
	var inside: bool = $Rooms.reached(player.global_position, ri_now, route[cursor])
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
	_watch_ghosts()
	_first_lessons()
	_read_note()
	_brush_spot()
	_refresh()

## Each family owns one object in its set (crates, a ring, the rail). Brushing it
## plays that family's voice once per leg: the loop tells you which room you are
## in, this tells you where in the room you are.
func _brush_spot() -> void:
	if _spot_played: return
	var ri := segments.size() - 1
	var sp: Vector3 = $Rooms.spot_at(ri)
	if sp == Vector3.ZERO: return
	if Vector2(sp.x, sp.z).distance_to(Vector2(player.global_position.x, player.global_position.z)) > 1.5: return
	_spot_played = true
	score.family_hit(str((segments.back() as Dictionary).get("kind", "")))

## Did one of your own past takes walk close enough that you would have noticed it?
## The tutorial uses this instead of "a ghost exists", because a ghost on the far
## side of the set is not something a first-time player has seen yet.
func _watch_ghosts() -> void:
	if _ghost_passed: return
	for g in _actors:
		if g.spent: continue
		if g.global_position.distance_to(player.global_position) < 3.0:
			_ghost_passed = true
			return


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
	var line := _w(lines[clampi(act, 0, 3)], en[clampi(act, 0, 3)])
	# The same sheet also says how tonight's set is built: every family walks a
	# different way, and the crew would rather tell you than watch you find out.
	var how: String = $Rooms.family_note(str((segments.back() as Dictionary).get("kind", "")), Loc.language == "zh")
	if how != "":
		line += "\n" + how
	_show_notice(line, 5.0)

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
	# One card per death. While it is up nothing else collects.
	if _dying: return false
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
	_dying = true
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
		desk.show_message(_death_line(source))
		_hold_until_board()
		# The ring is still on the deck when the board lifts; the sentence lands
		# after it, so the first thing a new player sees is where it happened.
		_hint("first_death", "这一条废了。你被送回上一个落点，别的什么都不扣。",
			"This take is wasted. You go back to the last mark, and nothing else is spent.")
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
	var daily := _is_daily()
	# One number, decided once, from the run's own record: how far, how clean,
	# what it cost. Time is free until the clock is out.
	score_info = Rules.run_score(run_legs, act, deaths, cuts_used, active_clock, deaths == 0)
	var best: int = Rules.record_daily(int(score_info["total"])) if daily else 0
	if not _recorded:
		_recorded = true
		Rules.record_run(segments.size(), deaths, won, run_seed)
	var lines: Array = [
		_w("走完 %d / %d 棚　　废条 %d　　死亡 %d", "SETS %d / %d   WASTED %d   DEATHS %d") % [segments.size(),MODULES,maxi(tracks.size()-segments.size(),0),deaths],
		_w("手上还剩　标记 %d　剪 %d", "LEFT   MARKS %d   CUTS %d") % [mark_stock,cut_stock],
	]
	if daily:
		lines.append(_w("今日 %s　得分 %d　自己最好 %d", "DAY %s   SCORE %d   YOUR BEST %d")
			% [Rules.daily_key(), int(score_info["total"]), maxi(best, int(score_info["total"]))])
	else:
		lines.append(_w("这一条值 %d 分", "THIS REEL IS WORTH %d") % int(score_info["total"]))
	# The bill, in the same units the number was made of. A player who reads it can
	# see which line they would have to change to score better, which is the only
	# way a score is a reason to play a second time.
	lines.append(_w("趟 %d×%d　节 %d×%d　死 −%d　剪 −%d",
		"LEGS %d×%d   ACTS %d×%d   DEATHS −%d   CUTS −%d")
		% [int(score_info["legs"]), Rules.SCORE_LEG, int(score_info["acts"]), Rules.SCORE_ACT,
			int(score_info["deaths"]) * -Rules.SCORE_DEATH, int(score_info["cuts"]) * -Rules.SCORE_CUT])
	lines.append(_w("种子 %06X", "SEED %06X") % run_seed)
	lines.append(_w("空格：再来一局　R：同种子重开", "SPACE: new run   R: same seed"))
	# The only thing this game keeps between runs is how far you got. Saying it out
	# loud is the whole progression: there is no tree, no currency, no unlocks.
	if segments.size() > prev_best:
		lines.insert(0, _w("走得最远的一次。", "The furthest you have been."))
	if not won and daily:
		# A board needs one rule or it is just a list of numbers: the reels that
		# ran out are the ones that count.
		lines.insert(0, _w("没接通的一局不上榜。", "A reel that never ran out does not go on the board."))
	if won:
		desk.show_call_sheet(_w("全部接通","ANSWER PRINT"), lines, true, Loc.language == "zh")
	else:
		lines.insert(0,_w("最后一趟没走出来。","The last take never made it out."))
		# One sentence, one person, one time. A failed run should read like a note
		# left by somebody who was there, not like a system message about a score.
		lines.insert(1,_w("场务把这条剪了。他说明天再来。","The stagehand cut this one. He says come back tomorrow."))
		desk.show_call_sheet(_w("这卷到头了","END OF REEL"), lines, false, Loc.language == "zh")
	# Only a finished reel goes on the board, and only if the platform is there:
	# on a desktop build, in the editor, or on a preview page this is a no-op.
	if won and daily: _send_score()


## A daily run is the one that carries today's seed: the same map for everyone,
## which is the only thing two strangers can fairly be ranked on.
func _is_daily() -> bool:
	return run_seed == Rules.daily_seed()


func _send_score() -> void:
	if _score_sent: return
	if not ToyBridge.available(): return
	_score_sent = true
	if _bridge == null:
		_bridge = ToyBridge.new()
		_bridge.name = "ToyBridge"
		_bridge.score_sent.connect(_on_score_sent)
		add_child(_bridge)
	_bridge.send_score(Rules.board_for(difficulty), int(score_info.get("total", 0)), "day", 5)


func _on_score_sent(ok: bool, mine: Dictionary, message: String) -> void:
	if not is_inside_tree(): return
	if not ok:
		# Silence is not an error the player should have to act on: the run is
		# still over, the page still says what it was, and one line says why there
		# is no rank on it.
		desk.append_sheet_lines([_w("榜单没有回应（%s）。", "The board did not answer (%s).") % message])
		return
	var rank := int(mine.get("rank", 0))
	if rank <= 0:
		desk.append_sheet_lines([_w("今日榜：这次没排上。", "TODAY: not ranked yet.")])
	else:
		desk.append_sheet_lines([_w("今日榜第 %d 名。", "TODAY: number %d on the board.") % rank])

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
	_press(key)


## One path for both hands: the pad synthesises the same keycodes the keyboard
## sends, so a thumb cannot drift into a second set of rules.
func touch_key(key: int) -> void:
	_press(key)


func _press(key: int) -> void:
	# Whatever else is on screen, ESC always does something. On the cutting desk it
	# leaves the desk (the old behaviour, and the cheapest way out); everywhere
	# else it opens the pause menu, including while a card is up — a card that
	# leaves the player in a room with no exit turns a bug into a broken keyboard.
	if key == KEY_ESCAPE:
		if phase == Mode.CUT and not forced_cut:
			_leave_cut()
		else:
			_open_pause()
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
						cuts_used += 1
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

## The set is framed for 53 deg at 12 m, and every screen this ships to is held
## sideways — a laptop lid, or a phone turned landscape. The phone does not get a
## different camera: it gets the same frame, scaled down, plus a pad. Distance is
## presentation only, and the player can pinch it either way at any time.
func _refresh() -> void:
	var zh := Loc.language == "zh"
	desk.set_hud_scale(float(GameSession.settings.get("hud_scale", 1.0)))
	if _in_prologue():
		desk.update_run(_tutorial + 1,TUTORIAL.size(),mini(room_pass+1,required_passes),required_passes,mark_stock,cut_stock,splice.has_splice(),zh)
	else:
		desk.update_run(_sets(),MODULES,mini(room_pass+1,required_passes),required_passes,mark_stock,cut_stock,splice.has_splice(),zh)
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
		_hud.text = _w("剪辑台　↑ ↓　%02d / %02d", "CUT DESK   ↑ ↓   %02d / %02d") % [_selected+1, anchors.size()] + "\n%s · TAKE %02d · %.1fs\n" % [tag,p.leg,p.time] + price + "\n" + _w("空格：剪回　−1 CUT　·　C 退出（看片不要钱）", "SPACE: splice   −1 CUT   ·   C to back out (looking is free)")
	if _notice_left > 0:
		desk.show_message(_notice)
		_notice_left = 0

## The board, three ways. It never changes state itself: it names what just
## happened and gets out of the way, so the player learns one object for all of
## ROLL, CUT and DIE.
func _board_roll() -> void:
	var n := maxi(live.take_id,1)
	score.duck(true)
	# The board carries the take number and nothing else: the premise belongs to the
	# title page now, and a board that explains itself delays the first step.
	slate.play_roll(n, _w("第 %02d 条" % n, "TAKE %02d" % n), "")


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
	await _board_gone()
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
	await _board_gone()
	_clear_killer_mark() # The mark lives exactly as long as the death card.
	if phase == Mode.PLAY and not _dying:
		player.set_frozen(was_frozen)
		rig.set_physics_process(true)

## A signal that already fired never fires again. Wait on the board's own state
## with a ceiling, so a race can cost a second of stillness, never the keyboard.
func _board_gone() -> void:
	if not slate.is_running(): return
	var frames := 0
	while slate.is_running() and frames < 900:
		await get_tree().process_frame
		frames += 1
