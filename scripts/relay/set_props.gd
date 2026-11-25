extends RefCounted
## Side-effect-free queries and a take-clock state machine in room-local metres.
## A prop arms on approach, fires once, and can rearm after the player backs away.
const Rooms = preload("res://scripts/relay/relay_rooms.gd")
const View = preload("res://scripts/relay/props/set_prop_view.gd")

const TYPES := ["crane", "clap", "dolly", "rack"]
const WARNING := 1.0
const APPROACH := 2.90
const FILM_RADIUS := 0.46
const ACTIVE := {"crane": 0.80, "clap": 0.0, "dolly": 0.90, "rack": 1.20}
const DRAG := {"crane": 0.60, "clap": 0.34, "dolly": 0.70, "rack": 0.95}
const CLEAR := Color("85dbef")
const HIT := Color("fc746c")
const FILM := Color("ffd46d")

var warn_scale := 1.0
var room: Node3D
var _view: Node3D
var _props: Array[Dictionary] = []
var _state: Array[Dictionary] = []
var _time := 0.0
var _film_taken := false


static func layout(spec: Dictionary, run_seed: int, module: int) -> Array[Dictionary]:
	var family := str(spec.get("kind", ""))
	if family not in ["i", "l", "o", "h", "s"]:
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d/set-props/%s/%d" % [run_seed, family, module]).hash()
	var hand := 1.0 if posmod(int(spec.get("variant", 0)), 2) == 0 else -1.0
	var types := TYPES.duplicate()
	var result: Array[Dictionary] = []
	var lanes: Array = Rooms.LANES[family]
	# The berth of each appliance fits one open cell in Z. The sweep runs
	# along that lane, so even the narrow S and L keep their corner approach.
	for columns: Array in [[1, 2], [4, 5]]:
		var berths: Array[Vector3] = []
		for column: int in columns:
			for row in lanes.size():
				if lanes[row][column] == ".":
					berths.append(Rooms.lane_center(column, row, hand))
		var kind: String = types.pop_at(rng.randi_range(0, types.size() - 1))
		result.append({"kind": kind, "at": berths[rng.randi_range(0, berths.size() - 1)],
			"hand": -1.0 if rng.randi_range(0, 1) == 0 else 1.0})
	var film_at := Vector3(7.82, 0.0, -1.95)
	if family == "l":
		film_at = Vector3(4.5, 0.0, 3.65 * hand)
	elif family != "i":
		film_at.z *= hand
	result.append({"kind": "film", "at": film_at, "hand": 1.0})
	return result


func build(root: Node3D, spec: Dictionary, run_seed: int, module: int) -> void:
	if is_instance_valid(_view):
		_view.hide()
		_view.stop()
		_view.queue_free()
		_view = null
	room = root
	_props = layout(spec, run_seed, module)
	if root != null and not _props.is_empty() and DisplayServer.get_name() != "headless":
		_view = View.new()
		_view.name = "SetProps"
		root.add_child(_view)
		_view.build(_props)
	reset_take(false)


func reset_take(film_taken: bool, clock := 0.0) -> void:
	_time = clock
	_film_taken = film_taken
	_state.clear()
	for prop in _props:
		_state.append({"fire": INF, "fired_at": -INF, "status": "", "until": 0.0, "drag": 0.0, "hit": false})
	if is_instance_valid(_view):
		_view.stop()
	_draw()


func snapshot() -> Array[Dictionary]:
	return _state.duplicate(true)


func restore_take(saved: Array, film_taken: bool, clock: float) -> void:
	reset_take(film_taken, clock)
	if saved.size() == _props.size():
		_state.assign(saved.duplicate(true))
		_draw()


func active_props() -> Array[Dictionary]:
	return _props.duplicate(true)


func debug_state() -> Dictionary:
	return {"time": _time, "film_taken": _film_taken, "props": snapshot()}


## Positions supplied to queries and tick are in the room's local frame.
func warned_at(pos: Vector3) -> Array[String]:
	var kinds: Array[String] = []
	for i in _props.size():
		if _near(i, pos) and _time < float(_state[i].fire) and _state[i].fire < INF:
			kinds.append(_props[i].kind)
	return kinds


func trigger_at(pos: Vector3) -> Array[String]:
	var kinds: Array[String] = []
	for i in _props.size():
		var prop := _props[i]
		var s := _state[i]
		var age := _time - float(s.fire)
		if age >= 0.0 and _on_deck(pos):
			if prop.kind == "film":
				if not _film_taken and _distance(prop, pos) <= FILM_RADIUS:
					kinds.append(prop.kind)
			elif _live_footprint(prop, s, pos, age):
				kinds.append(prop.kind)
	return kinds


func speed_scale() -> float:
	for s in _state:
		if _time < float(s.drag):
			return 0.50
	return 1.0


func tick(clock: float, pos: Vector3) -> Array[Dictionary]:
	_time = clock
	var events: Array[Dictionary] = []
	for i in _props.size():
		var prop := _props[i]
		var s := _state[i]
		var kind: String = prop.kind
		if kind == "film" and _film_taken:
			continue
		var near := _near(i, pos)
		if s.fire == INF:
			if near:
				s.fire = clock + WARNING * warn_scale
				_emit(events, i, "warn", 0.0)
			continue
		var age := clock - float(s.fire)
		if age < 0.0:
			continue
		if kind == "film":
			if _on_deck(pos) and _distance(prop, pos) <= FILM_RADIUS:
				_film_taken = true
				_emit(events, i, "pickup", 1.35)
			continue
		var active: float = ACTIVE[kind]
		if s.status == "warn":
			s.fired_at = clock
			_emit(events, i, "fire", 0.0)
		if not s.hit and _on_deck(pos) and _live_footprint(prop, s, pos, age):
			s.hit = true
			s.drag = clock + float(DRAG[kind])
			_emit(events, i, "hit", 1.05)
		if age >= active and s.status == "fire":
			_emit(events, i, "clear", 0.85)
		if not near and clock >= maxf(float(s.until), float(s.drag)) and age >= active:
			s.fire = INF
			s.hit = false
			s.status = ""
	_draw()
	return events


func _emit(events: Array[Dictionary], i: int, status: String, hold: float) -> void:
	var s := _state[i]
	s.status = status
	s.until = _time + hold
	events.append({"kind": _props[i].kind, "status": status})
	if is_instance_valid(_view):
		_view.play(i, status)


func _near(i: int, pos: Vector3) -> bool:
	return _on_deck(pos) and _distance(_props[i], pos) <= APPROACH


func _live_footprint(prop: Dictionary, s: Dictionary, pos: Vector3, age: float) -> bool:
	var live_now := _time == float(s.fired_at) if prop.kind == "clap" else age <= float(ACTIVE[prop.kind])
	return live_now and _in_footprint(prop, pos, age)


static func _on_deck(pos: Vector3) -> bool:
	return pos.y >= -0.25 and pos.y <= 0.60


static func _distance(prop: Dictionary, pos: Vector3) -> float:
	var center: Vector3 = prop.at
	return Vector2(pos.x - center.x, pos.z - center.z).length()


static func sweep(kind: String, age: float, hand: float) -> float:
	var travel := clampf(age / float(ACTIVE[kind]), 0.0, 1.0)
	if kind == "dolly":
		return hand * lerpf(-0.46, 0.46, sin(PI * travel))
	return hand * lerpf(-0.46, 0.46, travel)


static func _in_footprint(prop: Dictionary, pos: Vector3, age: float) -> bool:
	var offset: Vector3 = pos - prop.at
	match str(prop.kind):
		"clap":
			return _distance(prop, pos) <= 0.51
		"rack":
			return age >= 0.18 and absf(offset.x) <= 0.55 and absf(offset.z) <= 0.44
		"crane", "dolly":
			var width := 0.21 if prop.kind == "crane" else 0.26
			return absf(offset.x - sweep(prop.kind, age, prop.hand)) <= width and absf(offset.z) <= 0.43
	return false


func _draw() -> void:
	if not is_instance_valid(_view):
		return
	for i in _props.size():
		var prop := _props[i]
		var s := _state[i]
		var kind: String = prop.kind
		var age := _time - float(s.fire)
		var travel := sweep(kind, age, prop.hand) if kind in ["crane", "dolly"] else 0.0
		var status: String = s.status
		if kind == "film" and status == "warn" and age >= 0.0:
			status = ""
		if status != "warn" and status != "fire" and _time >= float(s.until):
			status = ""
		var tint: Color = {"warn": Color("ffbd68"), "fire": Color("fff5de"), "hit": HIT,
			"clear": CLEAR, "pickup": FILM}.get(status, Color.TRANSPARENT)
		_view.draw_prop(i, _time, s.fire, age, travel, status, tint, _film_taken)
