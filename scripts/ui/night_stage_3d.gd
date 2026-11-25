extends Node3D
## Title-only set. All animation is sampled from one clock, including the tails.

const DECK_PATH := "res://assets/textures/deck.png"
const FLAT_PATH := "res://assets/textures/flat.png"
const METAL_PATH := "res://assets/textures/metal.png"
const WALL_PATH := "res://assets/textures/wall.png"

static var _tex_cache: Dictionary = {}

const TAKE_INKS: Array[Color] = [Color("f3af64"), Color("89e3df"), Color("ed8aa9")]
const TUNGSTEN := Color("f4c483")
const DOOR_INK := Color("fce8c2")
const DOOR_Z := -5.65
const LAMP_SWING := 9.0
const CREW_PASS := 18.0
const ECHO_COUNT := 5
const WHEEL_RADIUS := 0.115

class Exposure:
	var runner: Node3D
	var legs: Array[Node3D] = []
	var marks: Array[MeshInstance3D] = []

var _camera: Camera3D
var _lamp: Node3D
var _dolly: Node3D
var _wheels: Array[MeshInstance3D] = []
var _crew: Node3D
var _crew_legs: Array[Node3D] = []
var _takes: Array[Exposure] = []
var _clock := 0.0
var _still_time := 7.4
var _frozen := false
var _aspect := 16.0 / 9.0


func _ready() -> void:
	# The dummy renderer never displays this set. Keep the world and clock,
	# and avoid allocating meshes or lights against dummy storage.
	var has_display := DisplayServer.get_name() != "headless"
	set_process(has_display and not _frozen)
	if not has_display:
		return

	_build_environment()
	_build_deck()
	_build_door()
	_build_lamp()
	_build_dolly()
	_build_takes()
	_camera = Camera3D.new()
	_camera.fov = 38.0
	_camera.near = 0.25
	_camera.far = 48.0
	add_child(_camera)
	_camera.make_current()
	_sample(_still_time if _frozen else _clock)


func set_frozen(frozen: bool, still_time: float) -> void:
	_frozen = frozen
	_still_time = still_time
	if frozen:
		_clock = still_time
	set_process(not frozen and is_instance_valid(_camera))
	_sample(_clock)


func set_aspect(aspect: float) -> void:
	if is_equal_approx(_aspect, aspect):
		return
	_aspect = aspect
	if is_instance_valid(_camera):
		_sample_camera(_clock)


func _process(delta: float) -> void:
	_clock += delta
	_sample(_clock)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0b0c0e")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("96908a")
	env.ambient_light_energy = 0.33
	env.fog_enabled = true
	env.fog_light_color = Color("343637")
	env.fog_density = 0.013
	env.fog_sky_affect = 0.0
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var rim := DirectionalLight3D.new()
	rim.light_color = Color("a8b8c4")
	rim.light_energy = 0.40
	rim.light_specular = 0.20
	rim.rotation_degrees = Vector3(-27.0, 144.0, 0.0)
	add_child(rim)


func _build_deck() -> void:
	var concrete := _stock(Color("53504a"), DECK_PATH, Vector3(7.0, 7.0, 7.0))
	var timber := _stock(Color("9e8871"), DECK_PATH, Vector3(4.0, 3.0, 1.0))
	var cyc := _stock(Color("123e25"), WALL_PATH, Vector3(3.0, 2.0, 1.0))
	var wall := _stock(Color("3b3731"), WALL_PATH, Vector3(2.0, 2.0, 1.0))
	var tape := _ink(Color("f4dfaa"))
	_box(self, Vector3(38.0, 0.28, 28.0), Vector3(0.0, -0.33, 0.0), concrete)
	_box(self, Vector3(11.8, 0.20, 6.4), Vector3(6.05, -0.10, 0.0), timber)
	_mesh(self, _cove_mesh(), Vector3.ZERO, cyc)
	_box(self, Vector3(1.22, 7.0, 0.28), Vector3(8.51, 3.2, DOOR_Z), wall)
	_box(self, Vector3(9.1, 7.0, 0.28), Vector3(15.55, 3.2, DOOR_Z), wall)
	_box(self, Vector3(1.88, 4.4, 0.28), Vector3(10.06, 4.92, DOOR_Z), wall)
	_box(self, Vector3(0.30, 7.0, 11.0), Vector3(14.65, 3.2, -0.2), wall)

	for x: float in [1.10, 11.00]:
		_box(self, Vector3(0.095, 0.012, 4.94), Vector3(x, 0.008, 0.0), tape)
		for z: float in [-2.47, 2.47]:
			_box(self, Vector3(0.44, 0.013, 0.095), Vector3(x, 0.009, z), tape)
	var spike := _stock(Color("6c5e4f"))
	for x: float in [3.7, 6.1, 8.5]:
		_box(self, Vector3(0.28, 0.009, 0.046), Vector3(x, 0.006, -2.89), spike)

	_crate(Vector3(2.05, -0.19, -4.28), Vector3(1.34, 0.72, 0.88), 3.0)
	_crate(Vector3(4.02, -0.19, -4.59), Vector3(1.16, 0.96, 0.91), -5.0)
	_crate(Vector3(12.36, -0.19, -2.24), Vector3(1.43, 1.06, 0.97), 6.5)
	_crate(Vector3(13.10, -0.19, 0.36), Vector3(0.91, 0.61, 0.72), -18.0)


func _cove_mesh() -> ArrayMesh:
	var profile: Array[Vector2] = []
	for step: int in 9:
		var turn := PI * 0.5 * float(step) / 8.0
		profile.append(Vector2(1.6 * (1.0 - cos(turn)) - 0.19, -3.85 - 1.6 * sin(turn)))
	profile.append(Vector2(7.0, -5.45))

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for step: int in range(profile.size() - 1):
		for corner: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0),
				Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var row := step + corner.y
			var yz: Vector2 = profile[row]
			var turn := PI * 0.5 * float(mini(row, 8)) / 8.0
			surface.set_normal(Vector3(0.0, cos(turn), sin(turn)))
			surface.set_uv(Vector2(float(corner.x), (yz.x + 0.19) / 8.0))
			surface.add_vertex(Vector3(lerpf(-16.0, 7.9, corner.x), yz.x, yz.y))
	return surface.commit()


func _crate(at: Vector3, dimensions: Vector3, cant: float) -> void:
	var crate := Node3D.new()
	crate.position = at
	crate.rotation_degrees.y = cant
	add_child(crate)
	var shell := _stock(Color("5c4e3e"), FLAT_PATH)
	var metal := _stock(Color("777471"), METAL_PATH)
	var stamp := _stock(Color("b6a482"))
	var center := dimensions.y * 0.5
	_box(crate, dimensions, Vector3(0.0, center, 0.0), shell)
	_box(crate, Vector3(dimensions.x + 0.03, 0.065, dimensions.z + 0.03),
		Vector3(0.0, dimensions.y - 0.09, 0.0), metal)
	for side: float in [-1.0, 1.0]:
		_box(crate, Vector3(0.08, dimensions.y, dimensions.z + 0.025),
			Vector3(side * (dimensions.x * 0.5 - 0.04), center, 0.0), metal)
	var tag := _box(crate, Vector3(0.27, 0.11, 0.012),
		Vector3(-0.11, center + 0.065, dimensions.z * 0.5), stamp)
	tag.rotation_degrees.z = -4.0


func _build_door() -> void:
	var frame := _stock(Color("4e4940"), METAL_PATH)
	var leaf := _stock(Color("51463b"), FLAT_PATH)
	var dark := _ink(Color("181614"))
	for x: float in [9.12, 11.0]:
		_box(self, Vector3(0.15, 2.91, 0.27), Vector3(x, 1.27, DOOR_Z + 0.03), frame)
	_box(self, Vector3(2.02, 0.15, 0.30), Vector3(10.06, 2.70, DOOR_Z + 0.03), frame)
	_box(self, Vector3(1.87, 2.83, 0.065), Vector3(10.06, 1.23, DOOR_Z - 1.31), _ink(DOOR_INK))
	_box(self, Vector3(1.77, 0.04, 1.49), Vector3(10.06, -0.17, DOOR_Z - 0.63), _ink(Color("927b59")))

	var hinge := Node3D.new()
	hinge.position = Vector3(10.95, 1.23, DOOR_Z + 0.04)
	hinge.rotation_degrees.y = -48.0
	add_child(hinge)
	_box(hinge, Vector3(1.78, 2.77, 0.09), Vector3(-0.89, 0.0, 0.0), leaf)
	_box(hinge, Vector3(0.13, 0.06, 0.06), Vector3(-1.58, -0.05, 0.06), frame)

	_build_door_spill()
	var spill := SpotLight3D.new()
	spill.position = Vector3(9.52, 2.08, DOOR_Z + 0.33)
	spill.light_color = DOOR_INK
	spill.light_energy = 2.8
	spill.spot_range = 7.5
	spill.spot_angle = 31.0
	add_child(spill)
	spill.look_at(Vector3(10.1, -0.18, -2.7))

	_crew = Node3D.new()
	add_child(_crew)
	_capsule(_crew, 0.21, 0.92, Vector3(0.0, 1.00, 0.0), dark)
	_sphere(_crew, 0.145, Vector3(0.0, 1.61, -0.025), dark)
	_box(_crew, Vector3(0.54, 0.21, 0.28), Vector3(0.0, 1.29, 0.0), dark)
	for side: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.108, 0.67, 0.0)
		_crew.add_child(hip)
		_capsule(hip, 0.080, 0.68, Vector3(0.0, -0.32, 0.0), dark)
		_crew_legs.append(hip)


func _build_door_spill() -> void:
	# Painted onto the concrete as a soft-edged projection so the door reads
	# in both Forward+ and the web renderer.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var near_left := Vector3(9.27, -0.185, DOOR_Z)
	var near_right := Vector3(9.89, -0.185, DOOR_Z)
	var far_left := Vector3(8.2, -0.185, -3.21)
	var far_right := Vector3(11.6, -0.185, -3.21)
	for strip: int in 4:
		var a := float(strip) / 4.0
		var b := float(strip + 1) / 4.0
		for corner: Vector2 in [Vector2(a, 0), Vector2(b, 0), Vector2(a, 1),
				Vector2(b, 0), Vector2(b, 1), Vector2(a, 1)]:
			var edge := sin(corner.x * PI)
			surface.set_color(Color(DOOR_INK, edge * lerpf(0.53, 0.03, corner.y)))
			surface.add_vertex(near_left.lerp(near_right, corner.x).lerp(
				far_left.lerp(far_right, corner.x), corner.y))
	var mat := _ink(Color.WHITE)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(self, surface.commit(), Vector3.ZERO, mat, false)


func _build_lamp() -> void:
	var steel := _stock(Color("494644"), METAL_PATH)
	var pipe := CylinderMesh.new()
	pipe.top_radius = 0.077
	pipe.bottom_radius = 0.077
	pipe.height = 23.0
	pipe.radial_segments = 10
	var rig := _mesh(self, pipe, Vector3(2.70, 6.0, -1.1), steel)
	rig.rotation_degrees.z = 90.0
	for x: float in [0.1, 6.25, 11.9]:
		_box(self, Vector3(0.052, 2.4, 0.052), Vector3(x, 7.2, -1.1), steel)

	_lamp = Node3D.new()
	_lamp.position = Vector3(6.25, 6.0, -1.1)
	add_child(_lamp)
	_box(_lamp, Vector3(0.052, 0.72, 0.052), Vector3(0.0, -0.37, 0.0), steel)
	_box(_lamp, Vector3(1.12, 0.34, 0.69), Vector3(0.0, -0.84, 0.0), steel)
	_box(_lamp, Vector3(0.89, 0.032, 0.51), Vector3(0.0, -1.023, 0.0), _ink(TUNGSTEN), false)
	var spot := SpotLight3D.new()
	spot.position = Vector3(0.0, -1.05, 0.0)
	spot.rotation_degrees = Vector3(-74.0, 180.0, 0.0)
	spot.light_color = TUNGSTEN
	spot.light_energy = 5.0
	spot.spot_range = 15.0
	spot.spot_angle = 55.0
	spot.spot_angle_attenuation = 0.85
	spot.shadow_enabled = true
	_lamp.add_child(spot)


func _build_dolly() -> void:
	var steel := _stock(Color("74716d"), METAL_PATH, Vector3(5.0, 1.0, 1.0))
	steel.metallic = 0.48
	var rubber := _stock(Color("373532"))
	for z: float in [3.39, 4.07]:
		_box(self, Vector3(11.2, 0.085, 0.068), Vector3(6.28, -0.105, z), steel)
	for x: float in [0.72, 2.55, 4.40, 6.24, 8.08, 9.94, 11.78]:
		_box(self, Vector3(0.17, 0.048, 1.03), Vector3(x, -0.16, 3.73), rubber)

	_dolly = Node3D.new()
	add_child(_dolly)
	_box(_dolly, Vector3(1.04, 0.15, 0.88), Vector3(0.0, 0.29, 0.0), steel)
	_box(_dolly, Vector3(0.11, 0.71, 0.10), Vector3(-0.06, 0.64, 0.0), steel)
	_box(_dolly, Vector3(0.53, 0.31, 0.27), Vector3(0.04, 1.08, 0.0), rubber)
	_box(_dolly, Vector3(0.27, 0.19, 0.19), Vector3(0.39, 1.08, 0.0), steel)
	var wheel := CylinderMesh.new()
	wheel.top_radius = WHEEL_RADIUS
	wheel.bottom_radius = WHEEL_RADIUS
	wheel.height = 0.08
	wheel.radial_segments = 12
	for x: float in [-0.39, 0.39]:
		for z: float in [-0.34, 0.34]:
			var roller := _mesh(_dolly, wheel, Vector3(x, 0.12, z), rubber)
			_box(roller, Vector3(0.025, 0.091, 0.11), Vector3.ZERO, steel)
			_wheels.append(roller)


func _build_takes() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.363
	ring.outer_radius = 0.409
	ring.rings = 24
	ring.ring_segments = 6
	for take: int in TAKE_INKS.size():
		var ink: Color = TAKE_INKS[take]
		var trail := Node3D.new()
		add_child(trail)
		var exposure := Exposure.new()
		_takes.append(exposure)

		var runner := Node3D.new()
		trail.add_child(runner)
		exposure.runner = runner
		exposure.marks.append(_mesh(trail, ring, Vector3.ZERO, _ink(ink), false))

		var body_ink := _stock(ink.darkened(0.14))
		body_ink.emission_enabled = true
		body_ink.emission = ink
		body_ink.emission_energy_multiplier = 0.28
		_capsule(runner, 0.23, 1.08, Vector3(0.0, 0.73, 0.0), body_ink, false)
		_sphere(runner, 0.165, Vector3(0.0, 1.44, 0.0), _ink(ink), false)
		var brim := CylinderMesh.new()
		brim.top_radius = 0.22
		brim.bottom_radius = 0.22
		brim.height = 0.052
		brim.radial_segments = 18
		_mesh(runner, brim, Vector3(0.0, 1.55, -0.075), body_ink, false)
		for side: float in [-1.0, 1.0]:
			var leg := _capsule(runner, 0.082, 0.64,
				Vector3(side * 0.105, 0.33, side * 0.084), body_ink, false)
			exposure.legs.append(leg)
		for echo: int in ECHO_COUNT:
			var tail := _ink(Color(ink, lerpf(0.68, 0.15, float(echo) / float(ECHO_COUNT - 1))))
			tail.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			exposure.marks.append(_mesh(trail, ring, Vector3.ZERO, tail, false))


func _sample(t: float) -> void:
	if not is_instance_valid(_camera):
		return
	_sample_camera(t)
	_lamp.rotation_degrees.z = sin(TAU * t / LAMP_SWING) * 2.0
	var travel := cos(TAU * (t - _still_time) / 24.0) * 1.15
	_dolly.position = Vector3(3.35 + travel, -0.07, 3.73)
	var axle := Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, -travel / WHEEL_RADIUS)
	for roller: MeshInstance3D in _wheels:
		roller.basis = axle
	_sample_crew(t)
	for take: int in _takes.size():
		var exposure: Exposure = _takes[take]
		var runner := exposure.runner
		runner.position = _take_at(take, t)
		var stride := sin(t * 10.0 + take * 2.0)
		runner.position.y += 0.025 * absf(stride)
		var direction := _take_at(take, t + 0.02) - runner.position
		runner.rotation.y = atan2(-direction.x, -direction.z)
		runner.rotation.x = -0.12
		exposure.legs[0].rotation.x = stride * 0.47
		exposure.legs[1].rotation.x = -stride * 0.47
		for echo: int in exposure.marks.size():
			var mark: MeshInstance3D = exposure.marks[echo]
			mark.position = _take_at(take, t - float(echo) * 0.28)
			mark.position.y = 0.043
			mark.scale = Vector3.ONE * (1.0 - 0.078 * echo)


func _sample_camera(t: float) -> void:
	var drift := TAU * t / 14.0
	var narrow := clampf((1.60 - _aspect) / 0.60, 0.0, 1.0)
	_camera.keep_aspect = Camera3D.KEEP_WIDTH if _aspect < 1.0 else Camera3D.KEEP_HEIGHT
	_camera.position = Vector3(9.30 + sin(drift) * 0.16, 8.10 + cos(drift) * 0.085, 17.4)
	_camera.look_at(Vector3(lerpf(0.45, 5.85, narrow), 1.27, -1.40))


func _sample_crew(t: float) -> void:
	var local := fposmod(t, CREW_PASS)
	_crew.visible = local >= 5.2 and local <= 11.2
	if not _crew.visible:
		return
	var progress := inverse_lerp(5.2, 11.2, local)
	var start := Vector3(8.02, -0.18, -5.05)
	var turn := Vector3(9.70, -0.18, DOOR_Z + 0.17)
	var exit := Vector3(9.75, -0.17, DOOR_Z - 1.46)
	var doorway := 0.44
	if progress < doorway:
		_crew.position = start.lerp(turn, progress / doorway)
		_crew.rotation.y = -1.23
	else:
		_crew.position = turn.lerp(exit, inverse_lerp(doorway, 1.0, progress))
		_crew.rotation.y = -0.04
	var gait := sin(t * 6.4)
	_crew.position.y += absf(gait) * 0.022
	_crew_legs[0].rotation.x = gait * 0.32
	_crew_legs[1].rotation.x = -gait * 0.32


func _take_at(take: int, t: float) -> Vector3:
	var clock := t - _still_time
	match take:
		0:
			var along := sin(clock * 0.39 - 0.68)
			return Vector3(6.0 + along * 4.25, 0.0, -1.72 + along * 0.94 + along * along * 0.84)
		1:
			var along := sin(clock * 0.33 - 0.58)
			return Vector3(6.2 - along * 4.45, 0.0, -0.12 - cos(clock * 0.40) * 0.74)
		_:
			var along := sin(clock * 0.44 + 0.10)
			return Vector3(5.8 + along * 4.28, 0.0, 1.63 - 2.25 * along * along)


func _stock(color: Color, tex_path: String = "", tiling: Vector3 = Vector3.ONE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if not tex_path.is_empty():
		mat.albedo_texture = _load_tex(tex_path)
	mat.uv1_scale = tiling
	mat.roughness = 0.86
	return mat


static func _load_tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = (load(path) as Texture2D) if ResourceLoader.exists(path) else null
	return _tex_cache[path] as Texture2D


func _ink(color: Color) -> StandardMaterial3D:
	var mat := _stock(color)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _mesh(parent: Node3D, geometry: Mesh, at: Vector3, mat: Material,
		shadows: bool = true) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = geometry
	instance.material_override = mat
	if not shadows:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.position = at
	parent.add_child(instance)
	return instance


func _box(parent: Node3D, dimensions: Vector3, at: Vector3, mat: Material,
		shadows: bool = true) -> MeshInstance3D:
	var geometry := BoxMesh.new()
	geometry.size = dimensions
	return _mesh(parent, geometry, at, mat, shadows)


func _capsule(parent: Node3D, radius: float, height: float, at: Vector3, mat: Material,
		shadows: bool = true) -> MeshInstance3D:
	var geometry := CapsuleMesh.new()
	geometry.radius = radius
	geometry.height = height
	geometry.radial_segments = 16
	geometry.rings = 6
	return _mesh(parent, geometry, at, mat, shadows)


func _sphere(parent: Node3D, radius: float, at: Vector3, mat: Material,
		shadows: bool = true) -> MeshInstance3D:
	var geometry := SphereMesh.new()
	geometry.radius = radius
	geometry.height = radius * 2.0
	geometry.radial_segments = 16
	geometry.rings = 8
	return _mesh(parent, geometry, at, mat, shadows)
