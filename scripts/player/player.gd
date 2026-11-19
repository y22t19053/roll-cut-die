extends CharacterBody3D
## Player — world-anchored movement (§4.2 hard rule), plus the facing channel the
## camera chases.
##
## W is always world -Z, whatever the camera is doing. The camera then swings to
## get behind the direction you are walking, late and at a bounded speed, so the
## world appears to turn under a key that never changed meaning. That mismatch is
## the game.
##
## Camera-relative movement was the earlier implementation and is rejected by the
## bible: because facing is derived from the movement direction, a camera-relative
## basis closes a positive feedback loop (yaw → move dir → facing → yaw). Holding
## D spins the camera forever and holding W freezes it, which makes the headline
## key do nothing at all.

const CameraMath = preload("res://scripts/camera/camera_math.gd")

const SPEED := 3.2
const ACCEL := 20.0
const DECEL := 26.0
const TURN_RATE := 12.0
const RADIUS := 0.32
const HEIGHT := 1.7
const EYE := 1.45

## Body layer 2 — what NPC and ghost danger areas look for.
const LAYER := 2
## Collides with world geometry only (layer 1).
const MASK := 1

signal facing_changed(facing: float)

## Radians. 0 == world -Z. The camera chases this.
var facing := 0.0
var frozen := false
## Optional Vector2 driving the player instead of the keyboard (tests, replays).
var input_override: Variant = null

var _visual: Node3D
var _last_intent := Vector3.ZERO


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = MASK
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_max_angle = deg_to_rad(50.0)
	_build_body()


func _build_body() -> void:
	var shape := CollisionShape3D.new()
	shape.name = "Body"
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = HEIGHT
	shape.shape = cap
	shape.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	add_child(shape)

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var mesh := MeshInstance3D.new()
	mesh.name = "Body"
	var cm := CapsuleMesh.new()
	cm.radius = RADIUS
	cm.height = HEIGHT
	cm.radial_segments = 16
	cm.rings = 6
	mesh.mesh = cm
	mesh.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.83, 0.78)
	mat.roughness = 0.85
	mesh.material_override = mat
	_visual.add_child(mesh)

	var head := MeshInstance3D.new()
	head.name = "Head"
	var sm := SphereMesh.new()
	sm.radius = 0.17
	sm.height = 0.34
	head.mesh = sm
	head.position = Vector3(0.0, EYE, 0.0)
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.80, 0.74, 0.66)
	head.material_override = hm
	_visual.add_child(head)

	# A wide brim: the only part of the silhouette that is not rotationally
	# symmetric, so the player can always read which way they are facing.
	var brim := MeshInstance3D.new()
	brim.name = "Brim"
	var bm := CylinderMesh.new()
	bm.top_radius = 0.26
	bm.bottom_radius = 0.26
	bm.height = 0.035
	bm.radial_segments = 16
	brim.mesh = bm
	brim.position = Vector3(0.0, EYE + 0.16, 0.0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.13, 0.14, 0.16)
	brim.material_override = bmat
	_visual.add_child(brim)

	var nose := MeshInstance3D.new()
	nose.name = "Nose"
	var nm := BoxMesh.new()
	nm.size = Vector3(0.08, 0.06, 0.30)
	nose.mesh = nm
	nose.position = Vector3(0.0, EYE + 0.02, -0.22)
	var nmat := StandardMaterial3D.new()
	nmat.albedo_color = Color(0.13, 0.14, 0.16)
	nose.material_override = nmat
	_visual.add_child(nose)


func _read_input() -> Vector2:
	if input_override != null:
		return input_override
	var x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var y := Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	return Vector2(x, y)


func _physics_process(dt: float) -> void:
	if frozen:
		velocity = Vector3(0.0, velocity.y, 0.0)
		velocity.x = move_toward(velocity.x, 0.0, DECEL * dt)
		velocity.z = move_toward(velocity.z, 0.0, DECEL * dt)
		move_and_slide()
		return

	var ix := _read_input()
	# World axes, no camera basis: see the file header and §4.2.
	var dir := CameraMath.move_dir(ix)
	_last_intent = dir

	var target_v := dir * SPEED
	var rate := ACCEL if dir.length_squared() > 0.0001 else DECEL
	velocity.x = move_toward(velocity.x, target_v.x, rate * dt)
	velocity.z = move_toward(velocity.z, target_v.z, rate * dt)
	velocity.y = 0.0
	move_and_slide()

	if dir.length_squared() > 0.0001:
		var want := CameraMath.facing_from_dir(dir)
		var before := facing
		facing = lerp_angle(facing, want, clampf(TURN_RATE * dt, 0.0, 1.0))
		if _visual != null:
			_visual.rotation.y = facing
		if not is_equal_approx(before, facing):
			facing_changed.emit(facing)


func set_frozen(v: bool) -> void:
	frozen = v
	velocity = Vector3.ZERO


func teleport(pos: Vector3, face: float = 0.0) -> void:
	global_position = pos
	facing = face
	velocity = Vector3.ZERO
	if _visual != null:
		_visual.rotation.y = face


func intent() -> Vector3:
	return _last_intent


func speed_now() -> float:
	return Vector2(velocity.x, velocity.z).length()
