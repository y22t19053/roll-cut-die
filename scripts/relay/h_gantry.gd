extends RefCounted

static func build(parent: Node3D) -> Dictionary:
	var mat_ground: StandardMaterial3D = StandardMaterial3D.new()
	mat_ground.albedo_color = Color(0.18, 0.19, 0.21, 1.0)
	mat_ground.roughness = 0.85
	mat_ground.metallic = 0.1

	var mat_deck: StandardMaterial3D = StandardMaterial3D.new()
	mat_deck.albedo_color = Color(0.32, 0.34, 0.38, 1.0)
	mat_deck.roughness = 0.65
	mat_deck.metallic = 0.4

	var mat_frame: StandardMaterial3D = StandardMaterial3D.new()
	mat_frame.albedo_color = Color(0.22, 0.24, 0.28, 1.0)
	mat_frame.roughness = 0.5
	mat_frame.metallic = 0.75

	var mat_stripe: StandardMaterial3D = StandardMaterial3D.new()
	mat_stripe.albedo_color = Color(0.95, 0.76, 0.12, 1.0)
	mat_stripe.roughness = 0.4
	mat_stripe.metallic = 0.2

	var mat_light_housing: StandardMaterial3D = StandardMaterial3D.new()
	mat_light_housing.albedo_color = Color(0.12, 0.12, 0.13, 1.0)
	mat_light_housing.roughness = 0.6
	mat_light_housing.metallic = 0.5

	var mat_light_glow: StandardMaterial3D = StandardMaterial3D.new()
	mat_light_glow.albedo_color = Color(1.0, 0.95, 0.82, 1.0)
	mat_light_glow.emission_enabled = true
	mat_light_glow.emission = Color(1.0, 0.92, 0.75, 1.0)
	mat_light_glow.emission_energy_multiplier = 3.5

	var mat_station: StandardMaterial3D = StandardMaterial3D.new()
	mat_station.albedo_color = Color(0.1, 0.75, 0.95, 1.0)
	mat_station.emission_enabled = true
	mat_station.emission = Color(0.1, 0.75, 0.95, 1.0)
	mat_station.emission_energy_multiplier = 1.8

	# Ground deck: top y = 0.0
	var ground_thickness: float = 0.6
	_create_solid_box(
		parent,
		"GroundDeck",
		Vector3(26.0, ground_thickness, 22.0),
		Vector3(0.0, -ground_thickness * 0.5, 0.0),
		Vector3.ZERO,
		mat_ground
	)

	# Bridge deck: spans X at z = 0, width in Z = 2.1m, top y = 2.5, clearance underneath 2.25
	var deck_thickness: float = 0.25
	var bridge_center_y: float = 2.375
	var bridge_span_x: float = 7.9
	_create_solid_box(
		parent,
		"BridgeDeck",
		Vector3(bridge_span_x, deck_thickness, 2.1),
		Vector3(0.0, bridge_center_y, 0.0),
		Vector3.ZERO,
		mat_deck
	)

	# Aligned upper landings (2.1m x 2.1m) seamlessly continuing the bridge deck
	_create_solid_box(
		parent,
		"EastLanding",
		Vector3(2.1, deck_thickness, 2.1),
		Vector3(5.0, bridge_center_y, 0.0),
		Vector3.ZERO,
		mat_deck
	)
	_create_solid_box(
		parent,
		"WestLanding",
		Vector3(2.1, deck_thickness, 2.1),
		Vector3(-5.0, bridge_center_y, 0.0),
		Vector3.ZERO,
		mat_deck
	)

	# Ramps: Rise = 2.5m, Run = 5.0m -> Angle = 26.565 deg <= 30 deg
	var ramp_run: float = 5.0
	var ramp_rise: float = 2.5
	var ramp_thickness: float = 0.25
	var ramp_angle: float = atan2(ramp_rise, ramp_run)
	var ramp_len: float = sqrt(ramp_run * ramp_run + ramp_rise * ramp_rise)
	var cos_a: float = cos(ramp_angle)
	var sin_a: float = sin(ramp_angle)

	var ramp_center_y: float = ramp_rise * 0.5 - (ramp_thickness * 0.5) * cos_a
	var east_ramp_center_z: float = 1.05 + ramp_run * 0.5 - (ramp_thickness * 0.5) * sin_a
	var west_ramp_center_z: float = -1.05 - ramp_run * 0.5 + (ramp_thickness * 0.5) * sin_a

	var east_ramp: StaticBody3D = _create_solid_box(
		parent,
		"EastRamp",
		Vector3(2.1, ramp_thickness, ramp_len),
		Vector3(5.0, ramp_center_y, east_ramp_center_z),
		Vector3(ramp_angle, 0.0, 0.0),
		mat_deck
	)

	var west_ramp: StaticBody3D = _create_solid_box(
		parent,
		"WestRamp",
		Vector3(2.1, ramp_thickness, ramp_len),
		Vector3(-5.0, ramp_center_y, west_ramp_center_z),
		Vector3(-ramp_angle, 0.0, 0.0),
		mat_deck
	)

	# Flush painted tread lines on ramps (no step colliders)
	for idx: int in range(11):
		var local_z: float = -2.25 + float(idx) * 0.45
		var tread_pos: Vector3 = Vector3(0.0, ramp_thickness * 0.5 + 0.002, local_z)
		_create_deco_box(east_ramp, "EastTread_%d" % idx, Vector3(1.8, 0.004, 0.12), tread_pos, Vector3.ZERO, mat_stripe)
		_create_deco_box(west_ramp, "WestTread_%d" % idx, Vector3(1.8, 0.004, 0.12), tread_pos, Vector3.ZERO, mat_stripe)

	# Vertical support columns under gantry (clearance underneath bridge preserved)
	var col_h: float = 2.25
	var col_y: float = col_h * 0.5
	_create_solid_box(parent, "Column_EN", Vector3(0.3, col_h, 0.3), Vector3(3.85, col_y, 0.95), Vector3.ZERO, mat_frame)
	_create_solid_box(parent, "Column_ES", Vector3(0.3, col_h, 0.3), Vector3(3.85, col_y, -0.95), Vector3.ZERO, mat_frame)
	_create_solid_box(parent, "Column_WN", Vector3(0.3, col_h, 0.3), Vector3(-3.85, col_y, 0.95), Vector3.ZERO, mat_frame)
	_create_solid_box(parent, "Column_WS", Vector3(0.3, col_h, 0.3), Vector3(-3.85, col_y, -0.95), Vector3.ZERO, mat_frame)

	# Decorative overhead gantry arches with stylized worklights
	var arch_x_positions: Array[float] = [-3.85, 0.0, 3.85]
	for arch_idx: int in range(arch_x_positions.size()):
		var ax: float = arch_x_positions[arch_idx]
		_create_deco_box(parent, "ArchPillar_S_%d" % arch_idx, Vector3(0.14, 2.1, 0.14), Vector3(ax, 3.55, -1.12), Vector3.ZERO, mat_frame)
		_create_deco_box(parent, "ArchPillar_N_%d" % arch_idx, Vector3(0.14, 2.1, 0.14), Vector3(ax, 3.55, 1.12), Vector3.ZERO, mat_frame)
		_create_deco_box(parent, "ArchBar_%d" % arch_idx, Vector3(0.14, 0.14, 2.38), Vector3(ax, 4.55, 0.0), Vector3.ZERO, mat_frame)

		# Worklights mounted overhead facing down
		for light_idx: int in range(2):
			var lz: float = -0.55 if light_idx == 0 else 0.55
			_create_deco_box(parent, "WorklightHousing_%d_%d" % [arch_idx, light_idx], Vector3(0.28, 0.12, 0.28), Vector3(ax, 4.42, lz), Vector3.ZERO, mat_light_housing)
			_create_deco_box(parent, "WorklightGlow_%d_%d" % [arch_idx, light_idx], Vector3(0.2, 0.02, 0.2), Vector3(ax, 4.35, lz), Vector3.ZERO, mat_light_glow)

	# Decorative edge paint rails (keeping all ramp approaches and bridge paths unobstructed)
	_create_deco_box(parent, "BridgeRail_S", Vector3(bridge_span_x, 0.12, 0.08), Vector3(0.0, 2.56, -1.05), Vector3.ZERO, mat_stripe)
	_create_deco_box(parent, "BridgeRail_N", Vector3(bridge_span_x, 0.12, 0.08), Vector3(0.0, 2.56, 1.05), Vector3.ZERO, mat_stripe)
	_create_deco_box(parent, "EastLandingRail_S", Vector3(2.1, 0.12, 0.08), Vector3(5.0, 2.56, -1.05), Vector3.ZERO, mat_stripe)
	_create_deco_box(parent, "EastLandingRail_E", Vector3(0.08, 0.12, 2.1), Vector3(6.05, 2.56, 0.0), Vector3.ZERO, mat_stripe)
	_create_deco_box(parent, "WestLandingRail_N", Vector3(2.1, 0.12, 0.08), Vector3(-5.0, 2.56, 1.05), Vector3.ZERO, mat_stripe)
	_create_deco_box(parent, "WestLandingRail_W", Vector3(0.08, 0.12, 2.1), Vector3(-6.05, 2.56, 0.0), Vector3.ZERO, mat_stripe)

	# Visual station marker pads
	_create_deco_box(parent, "StationPad_GroundCenter", Vector3(1.2, 0.015, 1.2), Vector3(0.0, 0.0075, 0.0), Vector3.ZERO, mat_station)
	_create_deco_box(parent, "StationPad_UpperCenter", Vector3(1.2, 0.015, 1.2), Vector3(0.0, 2.5075, 0.0), Vector3.ZERO, mat_station)
	_create_deco_box(parent, "StationPad_GroundNorthWest", Vector3(1.2, 0.015, 1.2), Vector3(-5.0, 0.0075, 5.0), Vector3.ZERO, mat_station)

	var station_list: PackedVector3Array = PackedVector3Array([
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.0, 2.5, 0.0),
		Vector3(-5.0, 0.0, 5.0)
	])
	var spawn_pos: Vector3 = Vector3(5.0, 0.0, 7.2)
	var speed_rect: Rect2 = Rect2()

	return {
		"stations": station_list,
		"spawn": spawn_pos,
		"speed_zone": speed_rect
	}

static func _create_solid_box(
	parent_node: Node3D,
	box_name: String,
	box_size: Vector3,
	box_pos: Vector3,
	box_rot: Vector3,
	mat: Material
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = box_name
	body.collision_layer = 1
	body.collision_mask = 1
	body.position = box_pos
	body.rotation = box_rot

	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.name = box_name + "Mesh"
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = box_size
	mesh_inst.mesh = box_mesh
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	var col_shape: CollisionShape3D = CollisionShape3D.new()
	col_shape.name = box_name + "Shape"
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = box_size
	col_shape.shape = box_shape
	body.add_child(col_shape)

	parent_node.add_child(body)
	return body

static func _create_deco_box(
	parent_node: Node3D,
	deco_name: String,
	box_size: Vector3,
	box_pos: Vector3,
	box_rot: Vector3,
	mat: Material
) -> MeshInstance3D:
	var mesh_inst: MeshInstance3D = MeshInstance3D.new()
	mesh_inst.name = deco_name
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = box_size
	mesh_inst.mesh = box_mesh
	mesh_inst.material_override = mat
	mesh_inst.position = box_pos
	mesh_inst.rotation = box_rot
	parent_node.add_child(mesh_inst)
	return mesh_inst
