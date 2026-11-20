extends Node3D
## Isolated comparison scene. Uses the shipping player and camera as-is.

const Player = preload("res://scripts/player/player.gd")
const Rig = preload("res://scripts/camera/camera_rig.gd")
const Modes = preload("res://scripts/camera/roll_modes.gd")
const Inputs = preload("res://scripts/core/input_setup.gd")
const STATIONS := ["Straight wall", "Right-angle turn", "Recess", "Narrow lane"]
const WALLS := [
	[Rect2(-4, -2, 8, 0.4)],
	[Rect2(-4, -2, 5, 0.4), Rect2(-4, -1.6, 0.4, 5.6)],
	[Rect2(-1.6, -2, 3.2, 0.4), Rect2(-1.6, -1.6, 0.4, 3.2), Rect2(1.2, -1.6, 0.4, 3.2)],
	[Rect2(-1, -2, 2, 0.4), Rect2(-1, -1.6, 0.4, 4), Rect2(0.6, -1.6, 0.4, 4)],
]
const EXITS := [
	[Vector2(-3, 1), Vector2(3, 1)],
	[Vector2(3, 0), Vector2(0, 4)],
	[Vector2(-2, 4), Vector2(2, 4)],
	[Vector2(-2, 4), Vector2(2, 4)],
]
const CYAN := Color("59d8df")
const AMBER := Color("ffd486")

var station := 0
var mode := Modes.ORBIT
var player: Player
var rig: Rig
var hud: Label
var _letters: Array[Vector3] = []
var _floor_guides: Array[Node3D] = []
var _guides_on := false


func _ready() -> void:
	Inputs.ensure_actions()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-73, -30, 0)
	sun.light_energy = 1.15
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("1a2028")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c2d0dd")
	env.environment.ambient_light_energy = 0.8
	add_child(env)
	for i in STATIONS.size():
		var origin := Vector3(i * 32.0, 0, 0)
		_block(origin + Vector3(0, -0.1, 0), Vector3(22, 0.2, 22), Color("323a43"), true)
		for j in range(-5, 6):
			_block(origin + Vector3(j, 0.005, 0), Vector3(0.018, 0.01, 10), Color("56616a"), false)
			_block(origin + Vector3(0, 0.006, j), Vector3(10, 0.01, 0.018), Color("56616a"), false)
		for rect: Rect2 in WALLS[i]:
			var c := rect.get_center()
			_block(origin + Vector3(c.x, 1.2, c.y), Vector3(rect.size.x, 2.4, rect.size.y), Color("89929b"), true)
		for side in 2:
			var e: Vector2 = EXITS[i][side]
			var pos := origin + Vector3(e.x, 0, e.y)
			var tint := CYAN if side == 0 else AMBER
			_block(pos + Vector3.UP * 0.035, Vector3(0.95, 0.06, 0.95), tint, false)
			var marker := Label3D.new()
			marker.text = "EXIT A" if side == 0 else "EXIT B"
			marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			marker.modulate = tint
			marker.font_size = 64
			marker.pixel_size = 0.011
			marker.position = pos + Vector3.UP * 0.6
			add_child(marker)
		_block(origin + Vector3(0, 0.012, 0), Vector3(0.3, 0.015, 0.3), Color("c5cdd4"), false)
		# Paint only: each route backs out to its turn, then branches sideways.
		var turn_z := 0.0 if i == 1 else (1.0 if i == 0 else 3.0)
		for side in 2:
			var e: Vector2 = EXITS[i][side]
			var tint := CYAN.darkened(0.30) if side == 0 else AMBER.darkened(0.30)
			var lane_x := -0.18 if side == 0 else 0.18
			if i == 1 and side == 1:
				_guide(origin, Vector2(lane_x, -0.9), Vector2(lane_x, e.y), tint)
				_guide(origin, Vector2(lane_x, e.y), e, tint)
			else:
				_guide(origin, Vector2(lane_x, -0.9), Vector2(lane_x, turn_z), tint)
				_guide(origin, Vector2(lane_x, turn_z), Vector2(e.x, turn_z), tint)
				_guide(origin, Vector2(e.x, turn_z), e, tint)
	player = Player.new()
	add_child(player)
	rig = Rig.new()
	add_child(rig)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(22, 16)
	hud.add_theme_font_size_override("font_size", 20)
	hud.add_theme_constant_override("outline_size", 7)
	layer.add_child(hud)
	reset_trial(0, mode)


func _block(pos: Vector3, size: Vector3, tint: Color, solid: bool) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	visual.material_override = material
	visual.position = pos
	add_child(visual)
	if solid:
		var body := StaticBody3D.new()
		body.position = pos
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		add_child(body)


func _guide(origin: Vector3, a: Vector2, b: Vector2, tint: Color) -> void:
	if a.is_equal_approx(b):
		return
	var middle := (a + b) * 0.5
	var stripe := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.075, 0.012, a.distance_to(b))
	stripe.mesh = mesh
	var paint := StandardMaterial3D.new()
	paint.albedo_color = tint
	stripe.material_override = paint
	stripe.position = origin + Vector3(middle.x, 0.018, middle.y)
	stripe.rotation.y = atan2(b.x - a.x, b.y - a.y)
	stripe.hide()
	add_child(stripe)
	_floor_guides.append(stripe)


func set_guides(enabled: bool) -> void:
	_guides_on = enabled
	for stripe in _floor_guides:
		stripe.visible = enabled
	_update_hud()


func reset_trial(index: int, roll_mode: int) -> void:
	station = index
	mode = roll_mode
	var origin := Vector3(station * 32.0, 0, 0)
	player.teleport(origin + Vector3.UP * 0.05, PI / 2.0)
	player.roll_mode = mode
	rig.set_roll_mode(mode)
	rig.setup(player)
	_letters.clear()
	for e: Vector2 in EXITS[station]:
		_letters.append(origin + Vector3(e.x, 0.6, e.y))
	_update_hud()


func _update_hud() -> void:
	hud.text = "CORNER LAB  /  %s  /  %s  /  PAINT %s\nWASD move   1–4 stations   F5–F7 modes   R resets   G toggles paint\nTry holding W against the wall, then pick a marked exit." % [STATIONS[station], Modes.mode_name(mode), "ON" if _guides_on else "OFF"]


func exit_visibility() -> int:
	var bits := 0
	var camera := rig.camera
	for i in _letters.size():
		var point := _letters[i]
		if not camera.is_position_in_frustum(point):
			continue
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, point, 1)
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			bits |= 1 << i
	return bits


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	var key: int = event.physical_keycode
	if key >= KEY_1 and key <= KEY_4:
		reset_trial(key - KEY_1, mode)
	elif key >= KEY_F5 and key <= KEY_F7:
		reset_trial(station, key - KEY_F5)
	elif key == KEY_R:
		reset_trial(station, mode)
	elif key == KEY_G:
		set_guides(not _guides_on)
