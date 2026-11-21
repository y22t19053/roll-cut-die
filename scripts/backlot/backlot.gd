extends "res://scripts/main.gd"
## Each successful shot advances the rescue; failed takes do not change the job.
enum Shot { STOP, UNLOAD, DELIVER, LAMP, SCREEN, DONE }
var shot := Shot.STOP
const SetPlan = preload("res://data/backlot/set.gd")
const LIMIT := 90.0
var power_cut := false
var carrying := false
var screened := false
var reel: MeshInstance3D
var carry_reel: MeshInstance3D
var projection: Label3D

func _ready() -> void:
	GameSession.reset_run()
	super._ready()

func _load_map() -> bool:
	# The office validator requires exactly four evidence props. This isn't a case.
	map_data = SetPlan.layout()
	return true

func _load_case() -> void:
	GameSession.case_state.load_data({"evidence":[],"npcs":[],"report":{}})

func _build_world() -> void:
	super._build_world()
	for i in SetPlan.PORTAL_X.size():
		var pane: MeshInstance3D = get_node("Layout/sidelight_%d/Mesh" % i)
		var glass := pane.material_override as StandardMaterial3D
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.albedo_color = Color(0.55, 0.78, 0.80, 0.23)
		glass.render_priority = 1 # Composite the pane after the translucent performer.
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sign("01  /  DOCK", Vector3(4,1.3,23))
	_sign("02  /  TANK", Vector3(18,1.3,21))
	_sign("03  /  SOUND", Vector3(31,1.6,21))
	_sign("REC  /  STOP", SetPlan.SWITCH + Vector3(0,1.8,-1))
	_sign("MASTER", SetPlan.DECK + Vector3(0,1.6,-1))
	_sign("35 mm", SetPlan.BOOTH + Vector3(0,1.8,1))
	projection = _sign("END  /  001", Vector3(32.5,2,30.3))
	projection.visible = false
	reel = _spool(get_node("Layout"), SetPlan.DECK + Vector3(0,1.12,-1.4))
	preload("res://data/backlot/portal_dressing.gd").install(self)

func _build_actors() -> void:
	super._build_actors()
	carry_reel = _spool(player, Vector3(0.34,0.83,0))
	carry_reel.scale = Vector3.ONE * 0.58

func _sign(words: String, at: Vector3) -> Label3D:
	var s := Label3D.new()
	s.text = words
	s.pixel_size = 0.006
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.position = at
	add_child(s)
	return s

func _spool(parent: Node, at: Vector3) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.42
	disc.bottom_radius = 0.42
	disc.height = 0.15
	item.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("e2ae59")
	item.material_override = mat
	item.position = at
	parent.add_child(item)
	return item

func _begin_take() -> void:
	carrying = false
	# Different crew positions and hand-offs; never mirror the recorded world.
	spawn_pos = [SetPlan.DOCK, SetPlan.BOOTH_EXIT, SetPlan.DECK, Vector3(18,0.05,25.8), Vector3(28,0.05,5.6)][mini(shot,Shot.SCREEN)]
	super._begin_take()
	# Neither performer gets a head start while the new take's slate is closed.
	_world_running = false
	recorder.recording = false
	for npc in npcs:
		npc.set_active(false)
	for ghost in ghost_nodes:
		ghost.playing = false
		ghost.global_position = ghost.track.sample_at(0.0).position
	_sync_reel()

func _sync_reel() -> void:
	reel.position = (SetPlan.BOOTH + Vector3(0,1.3,1.8)) if shot >= Shot.LAMP else (SetPlan.DECK + Vector3(0,1.12,-1.4))
	reel.visible = not carrying and not screened
	carry_reel.visible = carrying and not screened
	projection.visible = screened

func _snapshot() -> Dictionary:
	var p := super._snapshot()
	p["carrying"] = carrying
	return p

func _select_point(i: int) -> void:
	super._select_point(i)
	if cut_cursor < 0:
		_sync_reel()
		return
	var held := bool(marks.points()[cut_cursor].get("carrying", false))
	reel.visible = not held
	carry_reel.visible = false
	if held:
		_spool(player_still, Vector3(0.34,0.83,0)).scale = Vector3.ONE * 0.58

func _cut_to(p: Dictionary) -> void:
	super._cut_to(p)
	carrying = bool(p.get("carrying",false))
	_sync_reel()

func _physics_process(dt: float) -> void:
	super._physics_process(dt)
	if not power_cut and phase == Phase.ROLLING and _world_running and _world_t >= LIMIT and not player.frozen:
		_die("overwrite", _words("原片已覆盖", "Master overwritten"))

func _words(zh: String,en: String) -> String:
	return zh if Loc.language == "zh" else en

# From the capsule centre: 0.32 m body radius + 0.32 m arm extension.
# Use the solid's actual footprint rather than a radius around a walkway sign.
func _near(device: String) -> bool:
	var at := Vector2(player.global_position.x, player.global_position.z)
	for prop in map_data.props:
		if prop.id == device:
			var r: Array = prop.rect
			var surface := Vector2(clampf(at.x,r[0],r[2]), clampf(at.y,r[1],r[3]))
			return at.distance_squared_to(surface) <= 0.64 * 0.64
	return false

func _cue_text() -> String:
	match shot:
		Shot.STOP:
			return _words("原片即将覆盖 · %ds　找 REC 急停。", "Overwrite in %ds. Find the REC breaker.") % ceili(maxf(LIMIT-_world_t,0)) if not _near("breaker") else _words("E　切断覆录", "E   Stop overwrite")
		Shot.UNLOAD:
			return _words("录机停了。到 MASTER 松开压片轮。", "Deck stopped. Release the pinch roller at MASTER.") if not _near("recorder") else _words("E　松开压片轮", "E   Release pinch roller")
		Shot.DELIVER:
			if not carrying:
				return _words("E　卸下原片", "E   Lift reel off deck") if _near("recorder") else _words("原片已松开，等在 MASTER 上。", "Reel released. Pick it up at MASTER.")
			return _words("E　穿片", "E   Thread reel") if _near("projector") else _words("把原片送进 35 mm 放映机。", "Thread the master into the 35 mm projector.")
		Shot.LAMP:
			return _words("E　接通放映灯", "E   Energize lamp circuit") if _near("breaker") else _words("片穿好了，灯还不亮。去 REC 配电台接通灯路。", "Film threaded. Switch on the lamp circuit at REC.")
	return _words("E　开映", "E   Roll picture") if _near("projector") else _words("灯路已通。到 35 mm 开映。", "Lamp circuit live. Roll picture at 35 mm.")

func _update_hint() -> void:
	if phase == Phase.ROLLING and not player.frozen:
		_show_hint(_cue_text())

func _interact() -> void:
	if paused or phase != Phase.ROLLING or player.frozen:
		return
	match shot:
		Shot.STOP:
			if _near("breaker"):
				power_cut = true
				_complete_leg("stop_overwrite")
		Shot.UNLOAD:
			if _near("recorder"): _complete_leg("release_roller")
		Shot.DELIVER:
			if not carrying and _near("recorder"):
				carrying = true
				_sync_reel()
				hud.flash(_words("原片已卸下", "Master off deck"), 2.2, "pickup")
			elif carrying and _near("projector"):
				carrying = false
				_complete_leg("thread_projector")
		Shot.LAMP:
			if _near("breaker"): _complete_leg("energize_lamp")
		Shot.SCREEN:
			if _near("projector"):
				screened = true
				_complete_leg("screen_master")

func _complete_leg(result: String) -> void:
	GameSession.takes.begin_report()
	GameSession.takes.commit_report("master", result)
	phase = Phase.COMPLETE
	player.set_frozen(true)
	_freeze_world()
	_finish_take()
	shot += 1
	_sync_reel()
	_set_hint(func() -> String: return _words("原片已上银幕。空格回标题。", "The master is on screen. SPACE: title.") if screened else _words("本镜完成。空格交班。", "Shot complete. SPACE: hand off."))

func _retake() -> void:
	if screened and phase == Phase.COMPLETE:
		_quit_to_title()
	else:
		super._retake()

func _open_report() -> void:
	pass

func _load_latest_state() -> void:
	pass

func _commit_state() -> void:
	pass
