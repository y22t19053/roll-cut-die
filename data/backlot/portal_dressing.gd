extends RefCounted
## Mesh-only stage carpentry. Nothing enters the opening below head height;
## both the passable air and the fixed pane stay exactly where the set put them.
const SetPlan = preload("res://data/backlot/set.gd")

static func install(root: Node3D) -> void:
	var flats := Node3D.new()
	flats.name = "DockDoorFlats"
	root.add_child(flats)
	for i in 2:
		var bay := Node3D.new()
		bay.name = "CrewLoading" if i == 0 else "GlazedPassage"
		bay.position = Vector3(SetPlan.PORTAL_X[i],0,SetPlan.PORTAL_Z)
		flats.add_child(bay)
		if i == 0:
			# Rolling shop flat parked beside its empty doorway. High pelmet,
			# dark track and two rollers give it a specific backstage purpose.
			var brick := Color("be6845")
			var ochre := Color("e8ab63")
			var iron := Color("493c37")
			# Replace the transparent skin visually, but keep its existing body.
			_box(bay, "ParkedPlywood", Vector3(0,1.05,2.065), Vector3(0.15,2.1,1.57), brick)
			_box(bay, "Valance", Vector3(0,2.53,0.82), Vector3(0.38,0.40,4.22), ochre)
			_box(bay, "Rail", Vector3(0,2.28,0.82), Vector3(0.31,0.09,4.19), iron)
			_box(bay, "KickPlate", Vector3(0,0.20,2.065), Vector3(0.16,0.38,1.55), iron)
			for z in [1.52,2.60]:
				_box(bay,"RollerHanger",Vector3(0,2.17,z),Vector3(0.19,0.21,0.10),iron)
			_box(bay,"Pull",Vector3(0,1.0,1.48),Vector3(0.22,0.40,0.06),ochre)
		else:
			# Unlike the rolling flat, this is a square steel shopfront. A deep
			# sill and a narrow upright outline the fixed pane from either side;
			# no middle mullion/opaque panel hides a passing performer.
			var enamel := Color("54878a")
			var lip := Color("a7c1bd")
			_box(bay,"FrameHead",Vector3(0,2.39,0.80),Vector3(0.30,0.20,4.18),enamel)
			_box(bay,"GlassHead",Vector3(0,2.19,2.055),Vector3(0.19,0.23,1.64),enamel)
			_box(bay,"OuterStile",Vector3(0,1.06,2.80),Vector3(0.18,2.12,0.10),enamel)
			_box(bay,"Sill",Vector3(0,0.18,2.065),Vector3(0.18,0.36,1.57),enamel)
			_box(bay,"SillCap",Vector3(0,0.38,2.065),Vector3(0.22,0.06,1.57),lip)

static func _box(parent: Node3D, id: String, at: Vector3, size: Vector3, tint: Color) -> void:
	var part := MeshInstance3D.new()
	part.name = id
	var box := BoxMesh.new()
	box.size = size
	var paint := StandardMaterial3D.new()
	paint.albedo_color = tint
	paint.roughness = 0.86
	box.material = paint
	part.mesh = box
	part.position = at
	parent.add_child(part,true)
