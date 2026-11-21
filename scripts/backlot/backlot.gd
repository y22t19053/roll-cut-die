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
## Every cut of the rescue: the first five-shot edit and any recut forked from it.
const RecutLedger = preload("res://scripts/backlot/recut_ledger.gd")
const RECUT_ORDINAL := 3 # A recut keeps successes 1-2 and reshoots from here.
var recut := RecutLedger.new()
## Mission state the shot in progress was entered with; archived with its success.
var _entry := {}

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
	_entry = _mission_state()
	recut.stand(_entry)
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
	var take: int = GameSession.takes.take_index
	var ghost := {}
	if not GameSession.ghosts.is_empty() and int(GameSession.ghosts[-1].get("take", 0)) == take:
		ghost = GameSession.ghosts[-1]
	recut.record_success(take, _entry, ghost)
	shot += 1
	recut.stand(_mission_state())
	projection.text = "END  /  %03d" % recut.active
	_sync_reel()
	_update_hud()
	_set_hint(_idle_hint)

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

# --- recut ---------------------------------------------------------------

## Branch-local scene state only. Retake stock and the take counter are global
## and are never stored in, or restored from, a cut.
func _mission_state() -> Dictionary:
	return {"shot": shot, "power_cut": power_cut, "screened": screened, "carrying": carrying}

## The slate is not holding a live take: after a success, after a death, or with
## the CUT panel open. The same moments SPACE or the pause menu are available.
func _can_switch_cut() -> bool:
	if paused:
		return false
	return phase == Phase.COMPLETE or phase == Phase.DEAD or (phase == Phase.CUT and cut_panel.is_open())

func _can_fork() -> bool:
	return screened and phase == Phase.COMPLETE and not paused and recut.success_count(recut.active) >= RECUT_ORDINAL

## X on a finished cut: keep it, and start a new cut just before `ordinal`.
func fork_before(ordinal: int = RECUT_ORDINAL) -> bool:
	if not _can_fork():
		return false
	var made := recut.fork(recut.active, ordinal)
	if made.is_empty():
		return false
	_enter_cut(made.entry)
	var words := [int(made.cut), ordinal]
	_flash(func() -> String: return _words("第 %03d 版：从第 %d 镜重来，前面的照旧。", "Cut %03d: reshooting from shot %d. Earlier shots stand.") % words, 3.0)
	return true

## V: step to another cut. A finished cut is screened; an unfinished one resumes
## as a new take at the entry of its next shot.
func view_cut(cut: int) -> bool:
	if not _can_switch_cut() or cut == recut.active:
		return false
	var state := recut.open(cut)
	if state.is_empty():
		return false
	_enter_cut(state)
	return true

func _enter_cut(state: Dictionary) -> void:
	_clear_preview_stills()
	if cut_panel.is_open():
		cut_panel.close()
	cut_cursor = -1
	rig.camera.current = true
	rig.set_physics_process(true)
	shot = int(state.shot)
	power_cut = bool(state.power_cut)
	screened = bool(state.screened)
	carrying = false
	# Only this cut's own successes walk the set, on the tracks they recorded.
	GameSession.ghosts.clear()
	GameSession.ghosts.append_array(recut.ghosts(recut.active))
	GameSession.ghosts_changed.emit(GameSession.ghosts.size())
	projection.text = "END  /  %03d" % recut.active
	if screened:
		_screen_cut()
	else:
		GameSession.takes.retake() # Next id in the one global sequence; stock untouched.
		_begin_take()

## A finished cut on view: its recorded performers replay, nothing is live.
func _screen_cut() -> void:
	phase = Phase.COMPLETE
	recorder.recording = false
	_freeze_world()
	_clear_ghosts()
	_spawn_ghosts()
	if not ghost_nodes.is_empty():
		var last = ghost_nodes[-1].track
		var pose: Dictionary = last.sample_at(last.duration())
		player.teleport(pose.position, float(pose.get("facing", player.facing)))
	player.set_frozen(true)
	marks.clear()
	_sync_beacons()
	_death_fn = Callable()
	hud.clear_death()
	slate.hide_slate()
	_sync_reel()
	_update_hud()
	_set_hint(_idle_hint)

func _idle_hint() -> String:
	var other := _words("　V：看别的版本", "   V: other cut") if recut.cut_count() > 1 else ""
	if phase == Phase.DEAD:
		return Loc.ui("hint.retake") + other
	if not screened:
		return _words("本镜完成。空格交班。", "Shot complete. SPACE: hand off.") + other
	var line := _words("原片已上银幕。空格：就用这版　X：从第 %d 镜重剪", "The master is on screen. SPACE: keep this ending   X: recut from shot %d") % RECUT_ORDINAL
	if recut.cut_count() > 1:
		line = _words("第 %03d 版　", "Cut %03d   ") % recut.active + line
	return line + other

func _render_status() -> void:
	if recut.cut_count() <= 1:
		super._render_status()
		return
	var text := Loc.ui("status.rolling")
	if _status_fn.is_valid():
		text = _status_fn.call()
	hud.set_take(GameSession.takes.take_index, GameSession.ghost_count(), text + _words("　第 %03d 版", "   CUT %03d") % recut.active)

func _on_slate_finished(kind: String) -> void:
	if kind == "die" and phase != Phase.DEAD:
		return # A cut was opened while the DIE slate was still closing.
	super._on_slate_finished(kind)
	if kind == "die" and recut.cut_count() > 1:
		_set_hint(_idle_hint)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_X:
				if fork_before():
					return
			KEY_V:
				if recut.cut_count() > 1 and view_cut(recut.next_cut()):
					return
	super._unhandled_input(event)
