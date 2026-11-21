extends RefCounted
## A scenery flat on a caster deck. The front is painted scenery; the grip on
## the far side sees raw lumber and the braces used to push it along the flat.
## The lot owns the latch state, parent visibility and the original box body.
static func decorate(layout: Node3D) -> void:
	for id: String in ["gate_a", "gate_b"]:
		var gate := layout.get_node_or_null(id) as Node3D
		if not gate or gate.has_node("SceneryWagon"): continue
		var old := gate.get_node_or_null("Mesh") as MeshInstance3D
		if not old or not old.mesh is BoxMesh: continue
		var size := (old.mesh as BoxMesh).size
		var cart := Node3D.new()
		cart.name = "SceneryWagon"
		gate.add_child(cart)
		old.hide()
		# Design coordinates are metres in the original 0.5 x 1.9 x 2 box.
		cart.scale = size / Vector3(.5,1.9,2.)
		var wood := _paint(Color("a07850"))
		var deck := _paint(Color("463e37"))
		var tyre := _paint(Color("242629"))
		var ply := _paint(Color("795b44"))
		var light := _paint(Color("c9b489"))
		var face := _paint(Color("777e91") if id == "gate_a" else Color("748b81"))
		_part(cart, Vector3(0,-.71,0), Vector3(.48,.12,1.99), deck)
		for z: float in [-.76,.76]:
			for x: float in [-.16,.16]:
				var wheel := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = .115
				cyl.bottom_radius = .115
				cyl.radial_segments = 12
				cyl.height = .075
				wheel.mesh = cyl
				wheel.material_override = tyre
				wheel.rotation.z = PI/2
				wheel.position = Vector3(x,-.835,z)
				cart.add_child(wheel)
		_part(cart, Vector3(-.13,.14,0), Vector3(.08,1.60,1.96), ply)
		_part(cart, Vector3(-.18,.14,0), Vector3(.025,1.59,1.95), face)
		# Front: a cropped window flat for A, two panelled wainscots for B.
		if id == "gate_a":
			_part(cart, Vector3(-.20,.32,-.08), Vector3(.02,.82,1.12), deck)
			_part(cart, Vector3(-.22,.32,-.08), Vector3(.02,.82,.044), light)
			_part(cart, Vector3(-.22,.39,-.08), Vector3(.02,.044,1.12), light)
		else:
			_part(cart, Vector3(-.20,-.12,0), Vector3(.035,.074,1.95), light)
			for z: float in [-.48,.48]:
				_part(cart, Vector3(-.20,-.40,z), Vector3(.03,.36,.67), ply)
				_part(cart, Vector3(-.22,-.40,z), Vector3(.015,.29,.59), face)
		# Rear: two stiles, a diagonal shop brace and a push handle. No ribs.
		for z: float in [-.89,.89]:
			_part(cart, Vector3(-.055,.14,z), Vector3(.07,1.6,.075), wood)
		_part(cart, Vector3(-.05,.88,0), Vector3(.08,.09,1.82), wood)
		_part(cart, Vector3(-.05,-.59,0), Vector3(.08,.09,1.82), wood)
		_part(cart, Vector3(.008,.14,0), Vector3(.064,.085,2.18), wood).rotation.x = -.69
		for z: float in [-.24,.24]:
			_part(cart, Vector3(.06,.04,z), Vector3(.28,.045,.05), deck)
		_part(cart, Vector3(.20,.04,0), Vector3(.055,.065,.53), deck)

		gate.visibility_changed.connect(_visibility.bind(gate, cart, layout))

## The real gate is already open on this frame. Slide a visual duplicate along
## the wall, never a physics body. Ancestor visibility changes are not openings.
static func _visibility(gate: Node3D, cart: Node3D, layout: Node3D) -> void:
	var key := NodePath("Strike_" + str(gate.name))
	var outgoing := layout.get_node_or_null(key) as Node3D
	if outgoing:
		layout.remove_child(outgoing)
		outgoing.queue_free()
	if gate.visible or not layout.is_inside_tree() or not layout.is_visible_in_tree(): return
	var slide := cart.duplicate(0) as Node3D
	slide.name = str(key)
	layout.add_child(slide)
	slide.transform = gate.transform * cart.transform
	var tween := slide.create_tween()
	tween.tween_property(slide, "position:z", slide.position.z + 2.05, .33).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(slide.queue_free)

static func _paint(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = .91
	return mat

static func _part(cart: Node3D, at: Vector3, size: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	part.mesh = box
	part.position = at
	part.material_override = mat
	cart.add_child(part)
	return part
