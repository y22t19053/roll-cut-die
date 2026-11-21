extends Node3D
## Local art for the oner soundstage. The parent owns all physics and floor lines.
const Run = preload("res://scripts/studiolot/oner_run.gd")
const IRON := Color("38383d")
const LUMBER := Color("bd976e")
const PLY := Color("786149")
const CAMERA_RED := Color("ac4233")
const AMBER := Color("ffd399")
var _bulbs: Array[StandardMaterial3D] = []
var _lights: Array[OmniLight3D] = []
var _east := true
var _paint := {}

func _ready() -> void:
	name = "OnerSet"
	# Dress the EXISTING solid box, not an invisible second obstacle. The
	# painted face and the grip's timber face identify the two routes.
	for side: int in [-1,1]:
		var face := Color("617774") if side > 0 else PLY
		_box(Vector3(0,.79,.701*side),Vector3(3.93,1.16,.012),face)
		for x: float in [-1.90,0,1.90]:
			_box(Vector3(x,.80,.716*side),Vector3(.08,1.16,.027),LUMBER)
		if side < 0:
			for x: float in [-.95,.95]:
				_box(Vector3(x,.78,-.725),Vector3(2.04,.08,.024),LUMBER).rotation.z = signf(x)*.48
		else:
			_box(Vector3(0,1.1,.724),Vector3(3.9,.065,.022),LUMBER)
		for x: float in [-1.64,1.64]:
			var wheel := _disc(Vector3(x,.19,.713*side),.18,.04,IRON)
			wheel.rotation.x = PI/2
		_box(Vector3(0,.34,.715*side),Vector3(3.98,.11,.04),IRON)
	_camera()
	for side: int in [-1,1]:
		var x := side * Run.LINE
		# Lamp standards stay up against the upstage wall; no freestanding
		# signs in either turning box. Both labels face the tracking camera.
		_box(Vector3(x,1,-3.24),Vector3(.08,2,.09),IRON)
		_box(Vector3(x,1.65,-3.21),Vector3(.79,.65,.11),IRON)
		var signboard := Label3D.new()
		signboard.text = "A" if side < 0 else "B"
		signboard.font_size = 80
		signboard.pixel_size = .0063
		signboard.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		signboard.position = Vector3(x,1.66,-3.11)
		add_child(signboard)
		var lamp := _disc(Vector3(x,2.12,-3.15),.20,.21,IRON)
		lamp.rotation.x = PI/2
		var glass := _disc(Vector3(x,2.12,-3.035),.161,.025,AMBER)
		glass.rotation.x = PI/2
		var bulb := glass.material_override.duplicate() as StandardMaterial3D
		glass.material_override = bulb
		_bulbs.append(bulb)
		var light := OmniLight3D.new()
		light.position = Vector3(x,2,-2.65)
		light.light_color = AMBER
		light.omni_range = 4.5
		add_child(light)
		_lights.append(light)
	set_direction(_east)

func set_direction(eastbound: bool) -> void:
	_east = eastbound
	for i in _bulbs.size():
		var live := (i == 1) == eastbound
		_bulbs[i].albedo_color = AMBER if live else Color("756353")
		_bulbs[i].emission_enabled = live
		_bulbs[i].emission = AMBER
		_lights[i].visible = live

func _camera() -> void:
	# A low geared head, black lens barrel and two magazine reels. All of
	# it fits on the centre flat; nothing protrudes into the walkable lanes.
	_box(Vector3(-.53,1.49,0),Vector3(.82,.18,.6),IRON)
	_disc(Vector3(-.53,1.68,0),.18,.3,IRON)
	_box(Vector3(-.5,1.96,0),Vector3(.83,.43,.46),CAMERA_RED)
	_disc(Vector3(.012,1.97,0),.16,.32,IRON).rotation.z = PI/2
	for x: float in [-.71,-.31]:
		_disc(Vector3(x,2.28,0),.196,.22,CAMERA_RED).rotation.x = PI/2
		_disc(Vector3(x,2.28,.118),.055,.025,IRON).rotation.x = PI/2

func _box(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(at,mesh,color)

func _disc(at: Vector3, radius: float, depth: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 16
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = depth
	return _part(at,mesh,color)

func _part(at: Vector3, mesh: Mesh, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	if not _paint.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = .86
		_paint[color] = mat
	part.material_override = _paint[color]
	part.mesh = mesh
	part.position = at
	add_child(part)
	return part
