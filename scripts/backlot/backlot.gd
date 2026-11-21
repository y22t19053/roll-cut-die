extends "res://scripts/main.gd"
## Isolated two-take job; success leaves exactly the route actually walked.
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
	_sign("01  /  DOCK", Vector3(4,1.3,23))
	_sign("02  /  TANK", Vector3(18,1.3,21))
	_sign("03  /  SOUND", Vector3(31,1.6,21))
	_sign("REC  /  STOP", SetPlan.SWITCH + Vector3(0,1.8,-1))
	_sign("MASTER", SetPlan.DECK + Vector3(0,1.6,-1))
	_sign("35 mm", SetPlan.BOOTH + Vector3(0,1.8,1))
	projection = _sign("END  /  001", Vector3(32.5,2,30.3))
	projection.visible = false
	reel = _spool(get_node("Layout"), SetPlan.DECK + Vector3(0,1.12,-1.4))

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
	spawn_pos = SetPlan.BOOTH if power_cut else SetPlan.DOCK
	super._begin_take()
	_sync_reel()

func _sync_reel() -> void:
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

func _near(pos: Vector3) -> bool:
	return player.global_position.distance_to(pos) < 1.7

func _update_hint() -> void:
	if phase != Phase.ROLLING or player.frozen:
		return
	if not power_cut:
		var left := ceili(maxf(LIMIT-_world_t,0))
		_show_hint(_words("原片即将覆盖 · %ds　穿过水槽或绕布景车道，到 REC 拉闸。", "Master overwrite in %ds. Cross the tank aisle or skirt the scenery dock to REC.") % left if not _near(SetPlan.SWITCH) else _words("E　切断覆录电源", "E   Stop overwrite"))
	elif not carrying:
		_show_hint(_words("从放映间出发。到录机 MASTER 取原片；留意上次拉闸的人影。", "From the booth, reach MASTER. Watch for your previous run.") if not _near(SetPlan.DECK) else _words("E　从录机卸下原片", "E   Unload master reel"))
	else:
		_show_hint(_words("带原片回 35 mm 放映间。录音棚窄道近，水槽外道宽。", "Return to 35 mm. Soundstage alley is short; the tank detour is wider.") if not _near(SetPlan.BOOTH) else _words("E　装片、放映", "E   Thread and project"))

func _interact() -> void:
	if paused or phase != Phase.ROLLING or player.frozen:
		return
	if not power_cut and _near(SetPlan.SWITCH):
		power_cut = true
		_complete_leg("stop_overwrite")
	elif power_cut and not carrying and _near(SetPlan.DECK):
		carrying = true
		_sync_reel()
	elif carrying and _near(SetPlan.BOOTH):
		screened = true
		_complete_leg("screen_master")
		_sync_reel()

func _complete_leg(result: String) -> void:
	GameSession.takes.begin_report()
	GameSession.takes.commit_report("master", result)
	phase = Phase.COMPLETE
	player.set_frozen(true)
	_freeze_world()
	_finish_take()
	_set_hint(func() -> String: return _words("原片已上银幕。空格回标题。", "The master is on screen. SPACE: title.") if screened else _words("覆录已停。空格换到放映间，去接原片。", "Overwrite stopped. SPACE: start at the booth and fetch the master."))

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
