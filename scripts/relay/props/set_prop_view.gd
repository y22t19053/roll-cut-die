extends Node3D
## One prop entity per berth. Its meshes are silhouettes and floor paint only.
const Loc = preload("res://scripts/core/loc.gd")
const Sound = preload("res://scripts/relay/relay_sound.gd")
const INKS := {
	"crane": Color("ffa85d"), "clap": Color("c7adff"), "dolly": Color("82d4ff"),
	"rack": Color("f7ab76"), "film": Color("ffd46d"),
}
const SHADOW := Color("22242e")
const CHALK := Color("fbecd2")

var _units: Array[Dictionary] = []


func build(specs: Array[Dictionary]) -> void:
	var font := load("res://assets/fonts/RCD-Noto.otf") as Font
	for spec in specs:
		var kind: String = spec.kind
		var base := Node3D.new()
		base.name = kind.capitalize()
		base.position = spec.at
		add_child(base)
		var ink: Color = INKS[kind]
		var tape := _paint(ink)
		var part := Node3D.new()
		base.add_child(part)
		var lamp: MeshInstance3D
		match kind:
			"crane":
				_frame(base, 0.75, 0.43, tape)
				_box(base, Vector3(0, 0.90, 0.44), Vector3(0.14, 1.8, 0.12), SHADOW)
				_box(base, Vector3(0, 1.75, 0.44), Vector3(1.55, 0.09, 0.12), ink)
				_box(part, Vector3(0, 1.48, 0), Vector3(0.14, 0.14, 1.05), ink)
				_box(part, Vector3(0, 1.32, -0.37), Vector3(0.37, 0.25, 0.29), SHADOW)
				_box(part, Vector3(-0.21, 1.32, -0.37), Vector3(0.12, 0.15, 0.16), CHALK)
			"clap":
				_ring(base, 0.51, tape)
				_box(base, Vector3(0, 0.39, 0.3), Vector3(0.08, 0.78, 0.08), SHADOW)
				_box(base, Vector3(0, 0.83, 0.3), Vector3(0.67, 0.33, 0.13), SHADOW)
				lamp = _box(base, Vector3(0, 0.84, 0.30), Vector3(0.56, 0.19, 0.16), CHALK)
				part.position = Vector3(-0.33, 1.04, 0.3)
				_box(part, Vector3(0.33, 0, 0), Vector3(0.68, 0.11, 0.15), ink)
				for x: float in [0.10, 0.26, 0.42, 0.58]:
					_box(part, Vector3(x, 0, -0.081), Vector3(0.066, 0.10, 0.016), CHALK).rotation.z = -0.4
			"dolly":
				_frame(base, 0.75, 0.43, tape)
				for z: float in [-0.34, 0.34]:
					_box(base, Vector3(0, 0.033, z), Vector3(1.56, 0.02, 0.05), SHADOW)
				_box(part, Vector3(0, 0.21, 0), Vector3(0.49, 0.25, 0.81), ink)
				_box(part, Vector3(0.08, 0.49, 0.27), Vector3(0.07, 0.49, 0.09), CHALK)
				for z: float in [-0.32, 0.32]:
					_box(part, Vector3(0, 0.08, z), Vector3(0.42, 0.16, 0.16), SHADOW)
			"rack":
				_frame(base, 0.55, 0.44, tape)
				_box(base, Vector3(0, 0.54, 0.38), Vector3(1.10, 1.08, 0.09), SHADOW)
				for y: float in [0.30, 0.73]:
					_box(base, Vector3(0, y, 0.32), Vector3(1.10, 0.065, 0.24), CHALK)
				for x: float in [-0.33, 0, 0.33]:
					_box(part, Vector3(x, 0.89, 0.27), Vector3(0.26, 0.24, 0.24), ink)
			"film":
				_ring(base, 0.46, tape)
				_box(base, Vector3(0, 0.11, 0), Vector3(0.64, 0.22, 0.63), SHADOW)
				_reel(part, Vector3(0, 0.42, 0), 0.25, 0.10, _paint(ink))
				for k in 5:
					var a := TAU * k / 5.0
					_reel(part, Vector3(cos(a) * 0.145, 0.475, sin(a) * 0.145), 0.045, 0.01, _paint(SHADOW))
		var tag := Label3D.new()
		tag.position = Vector3(0, 2.27 if kind == "crane" else 1.86, 0)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.font = font
		tag.font_size = 42
		tag.pixel_size = 0.0044
		tag.outline_size = 13
		tag.modulate = ink
		base.add_child(tag)
		var action := _speaker(base)
		var result := _speaker(base)
		_units.append({"kind": kind, "base": base, "part": part, "tag": tag, "tape": tape,
			"action": action, "result": result, "lamp": lamp, "text": "", "ink": ink})


func play(i: int, status: String) -> void:
	var unit := _units[i]
	var channel: AudioStreamPlayer3D = unit.action if status in ["warn", "fire"] else unit.result
	channel.stream = Sound.prop_cue(unit.kind, status)
	channel.play()


func stop() -> void:
	for unit in _units:
		unit.action.stop()
		unit.result.stop()


func draw_prop(i: int, clock: float, fire: float, age: float, travel: float,
		status: String, tint: Color, film_taken: bool) -> void:
	var unit := _units[i]
	var kind: String = unit.kind
	var part: Node3D = unit.part
	var tag: Label3D = unit.tag
	var film := kind == "film"
	unit.base.visible = not film or not film_taken or status == "pickup"
	part.visible = not film or not film_taken
	var message := ""
	match status:
		"warn":
			message = Loc.ui("props.countdown", [Loc.ui("props." + kind + ".action"), maxf(0.0, fire - clock)])
		"fire":
			message = Loc.ui("props.fired", [Loc.ui("props." + kind + ".action")])
		"hit":
			message = Loc.ui("props.exposed" if kind == "clap" else "props.hit")
		"clear", "pickup":
			message = Loc.ui("props." + status)
		_:
			message = Loc.ui("props.film.action") if film else Loc.ui("props." + kind + ".action")
	var content := Loc.ui("props." + kind) + "\n" + message
	if unit.text != content:
		unit.text = content
		tag.text = content
	var color: Color = tint if tint.a > 0.0 else unit.ink
	tag.modulate = color
	unit.tape.albedo_color = color * (0.65 if status.is_empty() else 1.0)
	match kind:
		"crane", "dolly":
			part.position.x = travel
		"clap":
			part.rotation.z = 0.04 if age >= 0.0 and age < 0.4 else 0.38
			unit.lamp.visible = age >= 0.0 and age < 0.17
		"rack":
			var fall := 0.0 if age < 0.0 else smoothstep(0.0, 0.18, age) * (1.0 - smoothstep(1.2, 1.65, age))
			part.position = Vector3(0, -0.74 * fall, -0.25 * fall)
			part.rotation.z = -0.20 * fall
		"film":
			part.rotation.y = clock * 1.8


func _speaker(base: Node3D) -> AudioStreamPlayer3D:
	var audio := AudioStreamPlayer3D.new()
	audio.position.y = 0.7
	audio.unit_size = 3.0
	audio.max_distance = 16.0
	audio.volume_db = 0.0
	base.add_child(audio)
	return audio


func _frame(base: Node3D, x: float, z: float, tape: StandardMaterial3D) -> void:
	for side: float in [-1.0, 1.0]:
		_mesh_box(base, Vector3(side * x, 0.045, 0), Vector3(0.045, 0.015, z * 2.0), tape)
		_mesh_box(base, Vector3(0, 0.045, side * z), Vector3(x * 2.0, 0.015, 0.045), tape)


func _ring(base: Node3D, radius: float, tape: StandardMaterial3D) -> void:
	var shape := TorusMesh.new()
	shape.outer_radius = radius
	shape.inner_radius = radius - 0.043
	shape.rings = 20
	shape.ring_segments = 4
	var mesh := _mesh(base, Vector3(0, 0.045, 0), shape, tape)
	mesh.scale.y = 0.20


func _reel(base: Node3D, at: Vector3, radius: float, height: float, ink: StandardMaterial3D) -> void:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 20
	_mesh(base, at, shape, ink)


func _box(base: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	return _mesh_box(base, at, size, _paint(color))


func _mesh_box(base: Node3D, at: Vector3, size: Vector3, ink: StandardMaterial3D) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _mesh(base, at, shape, ink)


func _mesh(base: Node3D, at: Vector3, shape: Mesh, ink: StandardMaterial3D) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.position = at
	mesh.mesh = shape
	mesh.material_override = ink
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	base.add_child(mesh)
	return mesh


func _paint(color: Color) -> StandardMaterial3D:
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = color
	return ink
