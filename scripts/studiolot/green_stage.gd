extends Node3D
## Silent, non-solid exterior pickup stage. Local +Z opens toward the street.
## The take timeline is authoritative: seeking the same time restores the pose.
const PERIOD := 10.0
const TRANSIT := 3.5
const LEFT := -2.5
const HERO := 2.5
const CLOTH := Color("388448")
const IRON := Color("32393c")
const WOOD := Color("bb8350")
const CHALK := Color("f5eac5")
var _performer: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _clock := 0.0
var _materials := {}

func _ready() -> void:
	name = "GreenStage"
	_cyclorama()
	_box(self, Vector3(0, 3.28, -1.55), Vector3(7.85, .09, .09), IRON)
	for x: float in [-2.8, .35, 2.75]:
		var head := _pivot(self, Vector3(x, 2.97, -1.5))
		_box(head, Vector3(0,.16,0), Vector3(.06,.32,.06), IRON)
		var shade := _pivot(head, Vector3.ZERO)
		shade.rotation.x = deg_to_rad(27)
		_box(shade, Vector3.ZERO, Vector3(.82,.37,.34), IRON)
		_box(shade, Vector3(0,0,.18), Vector3(.69,.25,.025), Color("fff0cb"), true)
		_box(shade, Vector3(0,.19,.15), Vector3(.86,.045,.39), IRON)
	for i in 2:
		_apple_box(Vector3(-3.49, .24 * i, -1.13), .09 if i else 0.)
	# Start T and hero cross are marks on the floor, not map/HUD overlays.
	_box(self, Vector3(LEFT,.039,.25), Vector3(.58,.012,.074), CHALK)
	_box(self, Vector3(LEFT,.04,.13), Vector3(.072,.012,.30), CHALK)
	for angle: float in [-.785, .785]:
		_box(self, Vector3(HERO,.042,.06), Vector3(.84,.012,.095), CHALK).rotation.y = angle
	_performer = _pivot(self, Vector3.ZERO)
	_performer.name = "StandIn"
	_leg_l = _pivot(_performer, Vector3(0,.57,-.105))
	_leg_r = _pivot(_performer, Vector3(0,.57,.105))
	for leg in [_leg_l,_leg_r]:
		_box(leg, Vector3(0,-.25,0), Vector3(.15,.49,.15), IRON)
		_box(leg, Vector3(.048,-.48,0), Vector3(.25,.12,.16), Color("332f2e"))
	_box(_performer, Vector3(0,.81,0), Vector3(.28,.55,.48), Color("bf6442"))
	_box(_performer, Vector3(0,1.25,0), Vector3(.24,.32,.28), Color("cfaa82"))
	_box(_performer, Vector3(.04,1.42,0), Vector3(.34,.09,.33), IRON)
	set_take_time(_clock)

func on_mark() -> bool:
	var phase := fposmod(_clock, PERIOD)
	return phase >= TRANSIT and phase < PERIOD * .5

func set_take_time(seconds: float) -> void:
	_clock = seconds
	if not is_instance_valid(_performer): return
	var phase := fposmod(seconds, PERIOD)
	var leg_time := fmod(phase, PERIOD * .5)
	var u := clampf(leg_time / TRANSIT, 0, 1)
	var forward := phase < PERIOD * .5
	_performer.position.x = lerpf(LEFT, HERO, u if forward else 1.0-u)
	_performer.rotation.y = 0.0 if forward else PI
	var stride := sin(TAU * 4 * u) * .52
	_leg_l.rotation.z = stride
	_leg_r.rotation.z = -stride

func _cyclorama() -> void:
	# One continuous sheet: apron, tangent quarter circle, upright backing.
	var profile: Array[Vector2] = [Vector2(1.04,.022)]
	for j in 13:
		var a := float(j) * PI / 24.0
		profile.append(Vector2(-1.12 - .78*sin(a), .022 + .78*(1.0-cos(a))))
	profile.append(Vector2(-1.90, 2.78))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(profile.size()-1):
		for corner: int in [0,2,1,1,2,3]:
			var yz := profile[j + (corner >> 1)]
			st.add_vertex(Vector3(-3.9 if corner % 2 == 0 else 3.9, yz.y, yz.x))
	st.generate_normals()
	var sheet := MeshInstance3D.new()
	sheet.name = "InfinityCove"
	sheet.mesh = st.commit()
	sheet.material_override = _material(CLOTH, false)
	add_child(sheet)

func _apple_box(at: Vector3, yaw: float) -> void:
	var crate := _pivot(self,at)
	crate.rotation.y = yaw
	_box(crate, Vector3(0,.117,0), Vector3(.64,.23,.38), WOOD)
	_box(crate, Vector3(0,.14,.191), Vector3(.23,.055,.006), Color("533a29"))

func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	parent.add_child(n)
	return n

func _box(parent: Node3D, at: Vector3, size_m: Vector3, tint: Color, glow := false) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size_m
	n.mesh = box
	n.material_override = _material(tint, glow)
	n.position = at
	parent.add_child(n)
	return n

func _material(tint: Color, glow: bool) -> StandardMaterial3D:
	var key := tint.to_html() + str(glow)
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.roughness = .94
		if glow:
			mat.emission_enabled = true
			mat.emission = tint
			mat.emission_energy_multiplier = .65
		_materials[key] = mat
	return _materials[key]
