extends "res://scripts/main.gd"
## Studio lot campaign. Each successful take carries material from a stage to
## the editing bench and stays on the lot as a recorded performer. The answer
## print is then walked to the projection house and screened.
const Plan = preload("res://scripts/studiolot/lot_plan.gd")
const SCENE_PATH := "res://scenes/studiolot/world.tscn"
const FONT_PATH := "res://assets/fonts/RCD-Noto.otf"
const REACH := 0.64 # capsule radius + arm, measured to the solid's footprint
const SCREEN_SPEED := 8.0
const NAMES := {"tank": ["水槽", "TANK"], "lab": ["冲印", "LAB"], "street": ["外景街", "STREET"]}

## Survives the scene reload that starts a new production.
static var production := 1

var variation := {}
var images := {} # site -> true, banked at the bench
var sounds := {} # site -> "sync" | "wild"
var gates := {} # "a"/"b" -> true; permanent for the production
var hand_image := ""
var hand_sound := ""
var has_print := false
var screened := false
var _rects := {}
var _items := {}
var _shelf := {}
var _carry := {}
var _signs: Array = []
var _site_labels := {}
var _screen_root: Node3D
var _screen_cam: Camera3D
var _reels: Array = []
var _reel_caption: Label3D
var _screen_t := 0.0
var _screen_total := 0.0
var _new_armed_ms := -100000


func _ready() -> void:
	GameSession.reset_run()
	super._ready()

func _load_map() -> bool:
	variation = Plan.variation(production)
	map_data = Plan.layout(variation)
	for prop: Dictionary in map_data.props:
		_rects[prop.id] = prop.rect
	return true

func _load_case() -> void:
	GameSession.case_state.load_data({"evidence": [], "npcs": [], "report": {}})

func _words(zh: String, en: String) -> String:
	return zh if Loc.language == "zh" else en

func _site(site: String) -> String:
	return _words(NAMES[site][0], NAMES[site][1])

# --- building ------------------------------------------------------------

func _build_world() -> void:
	super._build_world()
	for lamp in [[8, 6.5, Color(1, 0.8, 0.6)], [32, 6.5, Color(0.5, 0.9, 1)], [24, 17, Color(1, 0.95, 0.85)],
			[40, 17, Color(1, 0.95, 0.85)], [8, 28, Color(0.7, 0.8, 1)], [21, 30, Color(1, 0.85, 0.3)], [38, 28, Color(1, 0.3, 0.2)]]:
		var light := OmniLight3D.new()
		light.position = Vector3(lamp[0], 3.4, lamp[1])
		light.omni_range = 11.0
		light.light_color = lamp[2]
		light.light_energy = 1.3
		add_child(light)
	_sign("放映楼", "PROJECTION HOUSE", Vector3(8, 3.3, 12.8))
	_sign("水槽棚", "TANK STAGE", Vector3(42.7, 3.3, 12.8))
	_sign("外景街", "EXTERIOR STREET", Vector3(24, 3.6, 17))
	_sign("剪辑塔", "EDITING TOWER", Vector3(7.2, 3.3, 21.2))
	_sign("冲印间", "DEVELOPING LAB", Vector3(40.7, 3.3, 21.2))
	_sign("货梯", "FREIGHT LIFT", Vector3(21, 3.4, 30))
	_sign("剪辑台", "EDIT BENCH", Vector3(4, 1.9, 33.6))
	_sign("35 mm", "35 mm", Vector3(12.5, 2.0, 6.5))
	_sign("卷帘闩", "SHUTTER LATCH", Vector3(17.9, 1.9, 7.5))
	_sign("卷帘闩", "SHUTTER LATCH", Vector3(17.5, 1.9, 28.4))
	for i in Plan.SITES.size():
		var site: String = Plan.SITES[i]
		var ir: Array = _rects["img_" + site]
		var sr: Array = _rects["snd_" + site]
		var at_i := Vector3((ir[0] + ir[2]) * 0.5, 0.9, (ir[1] + ir[3]) * 0.5)
		var at_s := Vector3((sr[0] + sr[2]) * 0.5, 0.9, (sr[1] + sr[3]) * 0.5)
		_items["img_" + site] = _spool(self, at_i, 0.36, Color("e2ae59"))
		_items["snd_" + site] = _spool(self, at_s, 0.24, Color("59c7e2"))
		_sign("母版画面 · " + NAMES[site][0], "MASTER PICTURE · " + NAMES[site][1], at_i + Vector3(0, 0.9, 0))
		_sign("同期声 · " + NAMES[site][0], "SYNC SOUND · " + NAMES[site][1], at_s + Vector3(0, 0.9, 0))
		_shelf["img_" + site] = _spool(self, Vector3(2.7 + i * 1.3, 1.05, 33.6), 0.36, Color("e2ae59"))
		_shelf["snd_" + site] = _spool(self, Vector3(2.7 + i * 1.3, 1.22, 33.6), 0.24, Color("59c7e2"))
	_shelf["print"] = _spool(self, Vector3(12.5, 1.5, 6.5), 0.42, Color("f2f2ea"))
	_build_screen()
	_retext_signs()

func _build_actors() -> void:
	super._build_actors()
	_carry["image"] = _spool(player, Vector3(0.36, 0.85, 0), 0.22, Color("e2ae59"))
	_carry["sound"] = _spool(player, Vector3(-0.36, 0.85, 0), 0.15, Color("59c7e2"))
	_carry["print"] = _spool(player, Vector3(0, 1.85, 0), 0.26, Color("f2f2ea"))

func _sign(zh: String, en: String, at: Vector3) -> Label3D:
	var s := Label3D.new()
	if ResourceLoader.exists(FONT_PATH):
		s.font = load(FONT_PATH)
	s.pixel_size = 0.006
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.position = at
	add_child(s)
	_signs.append([s, zh, en])
	return s

func _retext_signs() -> void:
	for entry: Array in _signs:
		entry[0].text = _words(entry[1], entry[2])

func _spool(parent: Node, at: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.14
	item.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.35
	item.material_override = mat
	item.position = at
	parent.add_child(item)
	return item

func _slab(size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	m.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	m.material_override = mat
	m.position = at
	_screen_root.add_child(m)
	return m

## Lot metres -> a point on the theatre screen (seen from the east, x right-to-left).
func _on_screen(mx: float, mz: float, lift := 0.0) -> Vector3:
	return Vector3(1.27 + lift, 3.45 - mz / 36.0 * 3.3, 8.7 - mx / 48.0 * 4.4)

func _build_screen() -> void:
	_screen_root = Node3D.new()
	_screen_root.visible = false
	add_child(_screen_root)
	_slab(Vector3(0.01, 3.4, 4.5), Vector3(1.26, 1.8, 6.5), Color(0.02, 0.02, 0.03))
	for zone: Array in Plan.ZONES:
		var r: Array = zone[1]
		var slab := _slab(Vector3(0.01, (r[3] - r[1]) / 36.0 * 3.3, (r[2] - r[0]) / 48.0 * 4.4),
			_on_screen((r[0] + r[2]) * 0.5, (r[1] + r[3]) * 0.5, 0.01), zone[2])
		slab.set_meta("zone", zone[0])
	for site: String in Plan.SITES:
		var c: Vector2 = Plan.SITE_CENTRE[site]
		var label := Label3D.new()
		if ResourceLoader.exists(FONT_PATH):
			label.font = load(FONT_PATH)
		label.pixel_size = 0.0028
		label.rotation.y = PI * 0.5
		label.position = _on_screen(c.x, c.y, 0.04)
		_screen_root.add_child(label)
		_site_labels[site] = label
	_reel_caption = Label3D.new()
	_reel_caption.font = load(FONT_PATH)
	_reel_caption.pixel_size = 0.003
	_reel_caption.rotation.y = PI * 0.5
	_reel_caption.position = Vector3(1.34, 3.68, 6.5)
	_screen_root.add_child(_reel_caption)
	_screen_cam = Camera3D.new()
	_screen_cam.fov = 50.0
	_screen_cam.position = Vector3(9.5, 1.9, 6.5)
	_screen_cam.rotation.y = PI * 0.5 # looks west at the screen
	add_child(_screen_cam)

# --- take flow -----------------------------------------------------------

func _begin_take() -> void:
	hand_image = ""
	hand_sound = ""
	has_print = false
	var slots: Array = Plan.SPAWNS
	spawn_pos = slots[(GameSession.takes.take_index + int(variation.slot_shift)) % slots.size()]
	super._begin_take()
	# Nobody moves and nothing records until the slate claps.
	_world_running = false
	recorder.recording = false
	for npc in npcs:
		npc.set_active(false)
	for ghost in ghost_nodes:
		ghost.playing = false
		ghost.global_position = ghost.track.sample_at(0.0).position
	_sync_items()

func _sync_items() -> void:
	for site: String in Plan.SITES:
		_items["img_" + site].visible = not images.has(site) and hand_image != site
		_items["snd_" + site].visible = not sounds.has(site) and hand_sound != site
		_shelf["img_" + site].visible = images.has(site)
		_shelf["snd_" + site].visible = sounds.has(site)
	_shelf["print"].visible = screened
	_carry["image"].visible = hand_image != ""
	_carry["sound"].visible = hand_sound != ""
	_carry["print"].visible = has_print

func _snapshot() -> Dictionary:
	var p := super._snapshot()
	p["hand_image"] = hand_image
	p["hand_sound"] = hand_sound
	p["has_print"] = has_print
	return p

func _cut_to(p: Dictionary) -> void:
	super._cut_to(p)
	hand_image = str(p.get("hand_image", ""))
	hand_sound = str(p.get("hand_sound", ""))
	has_print = bool(p.get("has_print", false))
	_sync_items()

func _near(id: String) -> bool:
	var at := Vector2(player.global_position.x, player.global_position.z)
	var r: Array = _rects[id]
	var surface := Vector2(clampf(at.x, r[0], r[2]), clampf(at.y, r[1], r[3]))
	return at.distance_squared_to(surface) <= REACH * REACH

## What E would do here: [action, argument], or [] when nothing is in reach.
func _target() -> Array:
	for g: String in ["a", "b"]:
		if not gates.has(g) and _near("latch_" + g):
			return ["latch", g]
	for site: String in Plan.SITES:
		if hand_image == "" and not has_print and not images.has(site) and _near("img_" + site):
			return ["image", site]
		if hand_sound == "" and not has_print and not sounds.has(site) and _near("snd_" + site):
			return ["sound", site]
	if _near("bench"):
		if hand_image != "" or hand_sound != "":
			return ["deliver", ""]
		if not has_print and not images.is_empty():
			return ["print", ""]
	if has_print and _near("projector"):
		return ["screen", ""]
	return []

func _cue_text() -> String:
	var t := _target()
	if not t.is_empty():
		match str(t[0]):
			"latch": return _words("E　从这一侧拉开卷帘（本片永久打开）", "E   Unlatch the shutter from this side (stays open)")
			"image": return _words("E　取下母版画面：%s", "E   Lift master picture: %s") % _site(t[1])
			"sound": return _words("E　取下声带：%s（与同场画面同条送回才同步）", "E   Lift sound roll: %s (in sync only if delivered with its picture)") % _site(t[1])
			"deliver": return _words("E　交给剪辑台", "E   Hand in at the bench")
			"print": return _words("E　取出拷贝，送去放映楼", "E   Take the answer print to the projection house")
			"screen": return _words("E　穿片开映", "E   Thread and roll picture")
	if has_print:
		return _words("把拷贝送进放映楼的 35 mm 放映机。", "Carry the print to the 35 mm projector in the projection house.")
	if hand_image != "" or hand_sound != "":
		return _words("把手里的素材送回剪辑塔的剪辑台。", "Bring what you carry back to the bench in the editing tower.")
	if images.is_empty():
		return _words("去水槽棚、冲印间或外景街取一卷母版画面。", "Fetch a master picture from the tank stage, the lab or the street.")
	return _words("画面 %d/3。继续取材，或到剪辑台取拷贝去放映。", "Pictures %d/3. Fetch more, or take the print from the bench to screen it.") % images.size()

func _update_hint() -> void:
	if phase == Phase.ROLLING and not player.frozen:
		_show_hint(_cue_text())

func _interact() -> void:
	if paused or phase != Phase.ROLLING or player.frozen:
		return
	var t := _target()
	if t.is_empty():
		return
	recorder.mark(GhostTrack.FLAG_INTERACT)
	var arg := str(t[1])
	match str(t[0]):
		"latch":
			open_gate(arg)
			_flash(func() -> String: return _words("卷帘开了。这条回程以后一直通。", "Shutter open. This way back stays open."), 3.0)
		"image":
			hand_image = arg
			_flash(func() -> String: return _words("母版画面在手：", "Master picture in hand: ") + _site(arg))
		"sound":
			hand_sound = arg
			_flash(func() -> String: return _words("声带在手：", "Sound roll in hand: ") + _site(arg))
		"deliver":
			if hand_image != "":
				images[hand_image] = true
			if hand_sound != "":
				sounds[hand_sound] = "sync" if hand_sound == hand_image else "wild"
			hand_image = ""
			hand_sound = ""
			_complete_leg("deliver")
			return
		"print":
			has_print = true
			_flash(func() -> String: return _words("拷贝已出片。", "Answer print struck."))
		"screen":
			has_print = false
			screened = true
			_complete_leg("screen")
			_start_screening()
			return
	_sync_items()

func open_gate(g: String) -> void:
	gates[g] = true
	var node := get_node_or_null("Layout/gate_" + g)
	if node != null:
		node.visible = false
		node.get_node("Body").collision_layer = 0

func _complete_leg(result: String) -> void:
	GameSession.takes.begin_report()
	GameSession.takes.commit_report("studiolot", result)
	phase = Phase.COMPLETE
	player.set_frozen(true)
	_freeze_world()
	_finish_take() # The real recording of this take joins the lot.
	_sync_items()
	_update_hud()
	_set_hint(_idle_hint)

func _idle_hint() -> String:
	if phase == Phase.DEAD:
		return Loc.ui("hint.retake")
	if screened:
		return _words("空格：重放　B：回剪辑塔继续　N：开一部新片", "SPACE: run it again   B: back to editing   N: new production")
	return _words("素材入库，这一条留在片场。空格：下一条", "Banked. This take stays on the lot. SPACE: next take")

func _retake() -> void:
	if screened and phase == Phase.COMPLETE:
		_screen_t = 0.0
		return
	super._retake()

func _on_slate_finished(kind: String) -> void:
	if kind == "die" and phase != Phase.DEAD:
		return
	super._on_slate_finished(kind)

func _open_report() -> void:
	pass

func _load_latest_state() -> void:
	pass

func _commit_state() -> void:
	pass # The campaign lives in memory only; production saves are never written.

func _render_status() -> void:
	var text := Loc.ui("status.rolling")
	if _status_fn.is_valid():
		text = _status_fn.call()
	hud.set_take(GameSession.takes.take_index, GameSession.ghost_count(),
		text + _words("　第 %03d 部 #%d　画面 %d/3", "   PROD %03d #%d   PIC %d/3") % [production, int(variation.code), images.size()])

# --- ending --------------------------------------------------------------

func _start_screening() -> void:
	for reel: Dictionary in _reels:
		for node: Node in reel.nodes:
			node.queue_free()
	_reels.clear()
	_screen_t = 0.0
	_screen_total = 0.0
	for item: Dictionary in GameSession.ghosts:
		var tr: Variant = item.get("track")
		if tr == null:
			continue
		var hue := Color.from_hsv(fmod(int(item.get("take", 0)) * 0.17, 1.0), 0.55, 1.0)
		var nodes: Array = []
		for k in 6:
			var side := 0.14 - k * 0.018
			nodes.append(_slab(Vector3(0.01, side, side), Vector3.ZERO, hue.darkened(k * 0.12)))
		_reels.append({"track": tr, "take": tr.take_id, "start": _screen_total, "nodes": nodes})
		_screen_total += float(tr.duration())
	for child: Node in _screen_root.get_children():
		if child.has_meta("zone") and images.has(str(child.get_meta("zone"))):
			(child as MeshInstance3D).material_override.albedo_color = Color(0.85, 0.66, 0.30)
	_screen_root.visible = true
	_screen_cam.current = true
	_render_ending()
	_sync_items()

func _sound_word(site: String) -> String:
	match str(sounds.get(site, "")):
		"sync": return _words("同期声", "SYNC")
		"wild": return _words("声画不同步", "WILD")
	return _words("无声", "MOS")

func ending_lines() -> PackedStringArray:
	var n := images.size()
	var sync := 0
	var heard := 0
	var lines := PackedStringArray()
	var kind: String = [_words("单本短片", "ONE-REELER"), _words("两本片", "TWO-REELER"), _words("完整长片", "FULL FEATURE")][clampi(n - 1, 0, 2)]
	lines.append(_words("第 %03d 部　%s", "PRODUCTION %03d   %s") % [production, kind])
	for site: String in Plan.SITES:
		if images.has(site):
			lines.append("%s　%s" % [_site(site), _sound_word(site)])
			sync += int(sounds.get(site, "") == "sync")
			heard += int(sounds.has(site))
		else:
			lines.append(_words("%s　没拍到", "%s   never shot") % _site(site))
		_site_labels[site].text = "%s\n%s" % [_site(site), _sound_word(site) if images.has(site) else "—"]
	if sync == n:
		lines.append(_words("全片声画同步。观众听得见水声和脚步。", "Every reel in sync. The house hears the water and the footsteps."))
	elif heard == 0:
		lines.append(_words("一部默片。只有放映机在响。", "A silent picture. Only the projector speaks."))
	else:
		lines.append(_words("有的声音对不上嘴。它还是放完了。", "Some of the sound drifts off the lips. It still plays to the end."))
	var t = GameSession.takes
	lines.append(_words("银幕上是你真实走过的 %d 条，共 %s；废片 %d 条。", "On screen: your %d recorded takes, %s in all; %d outtakes.")
		% [_reels.size(), MarkLedger.clock(_screen_total), t.outtakes.size()])
	return lines

func _render_ending() -> void:
	hud.set_case_lines(ending_lines())
	_set_hint(_idle_hint)

func _process(dt: float) -> void:
	super._process(dt)
	if not screened or paused:
		return
	_screen_t += dt * SCREEN_SPEED
	if _screen_t > _screen_total + 2.0 * SCREEN_SPEED:
		_screen_t = 0.0
	var caption := "FIN"
	for reel: Dictionary in _reels:
		var local: float = _screen_t - float(reel.start)
		var dur: float = reel.track.duration()
		if local >= 0.0 and local < dur:
			caption = "TAKE %02d   %s" % [reel.take, MarkLedger.clock(local)]
		for k in reel.nodes.size():
			var node: MeshInstance3D = reel.nodes[k]
			node.visible = local >= 0.0
			var pos: Vector3 = reel.track.sample_at(clampf(local - k * 0.7, 0.0, dur)).position
			node.position = _on_screen(pos.x, pos.z, 0.03)

	_reel_caption.text = caption

## B at the ending: the print goes back; everything banked and recorded stays.
func return_to_editing() -> bool:
	if not screened or phase != Phase.COMPLETE or paused:
		return false
	screened = false
	_screen_root.visible = false
	rig.camera.current = true
	hud.set_case_lines(PackedStringArray())
	GameSession.takes.retake()
	_begin_take()
	return true

## A new production: new seed, empty bench, shut shutters, no recorded takes.
func new_production() -> void:
	production += 1
	paused = false
	var tree := get_tree()
	tree.paused = false
	if tree.current_scene == self:
		tree.change_scene_to_file(SCENE_PATH)
	else:
		var fresh: Node = load(SCENE_PATH).instantiate()
		get_parent().add_child.call_deferred(fresh)
		queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if screened and phase == Phase.COMPLETE and not paused and event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_B:
				return_to_editing()
				return
			KEY_N:
				if Time.get_ticks_msec() - _new_armed_ms < 4000:
					new_production()
				else:
					_new_armed_ms = Time.get_ticks_msec()
					_flash(func() -> String: return _words("再按一次 N：封存本片，开一部新片。", "Press N again: shelve this film and start a new production."), 4.0)
				return
	super._unhandled_input(event)

func _on_language_changed(lang: String) -> void:
	super._on_language_changed(lang)
	_retext_signs()
	if screened:
		_render_ending()
