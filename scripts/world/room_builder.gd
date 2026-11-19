extends RefCounted
## RoomBuilder — turns a validated map dictionary into geometry.
##
## Everything is built from primitives at load time: no imported art, no scene
## files to keep in sync. A wall is a rect plus a height; a prop is the same plus
## a colour. Collision is always the same box as the visual, so what you can see
## is what you can hit — the DIE system depends on that being true.

const RoomSpec = preload("res://scripts/world/room_spec.gd")

const WALL_HEIGHT := 3.0
const WALL_COLOR := Color(0.30, 0.30, 0.33)
const FLOOR_A := Color(0.20, 0.205, 0.215)
const FLOOR_B := Color(0.235, 0.24, 0.25)


## Builds into `root`. Returns {"size": Vector2, "walls": Array[Node], "props": Dictionary, "floor": Node3D}
static func build(root: Node3D, spec: Dictionary) -> Dictionary:
	var size_v: Array = spec.get("size", [24, 18])
	var w := float(size_v[0])
	var h := float(size_v[1])

	var layout := Node3D.new()
	layout.name = "Layout"
	root.add_child(layout)

	var floor_node := _make_floor(w, h)
	layout.add_child(floor_node)

	var walls: Array = []
	for r: Variant in spec.get("walls", []):
		var rr := RoomSpec.rect(r)
		var node := _make_box(rr, WALL_HEIGHT, WALL_COLOR, "Wall")
		layout.add_child(node)
		walls.append(node)

	var props: Dictionary = {}
	for p: Variant in spec.get("props", []):
		var pd: Dictionary = p
		var rr := RoomSpec.rect(pd.get("rect", [0, 0, 1, 1]))
		var col := Color(0.36, 0.33, 0.28)
		if pd.get("color") is Array and (pd["color"] as Array).size() >= 3:
			col = Color(float(pd["color"][0]), float(pd["color"][1]), float(pd["color"][2]))
		var node := _make_box(rr, float(pd.get("height", 0.8)), col, str(pd.get("id", "prop")))
		node.set_meta("prop_id", str(pd.get("id", "")))
		layout.add_child(node)
		props[str(pd.get("id", ""))] = node

	return {"size": Vector2(w, h), "walls": walls, "props": props, "floor": floor_node, "layout": layout}


static func _make_floor(w: float, h: float) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Floor"

	var plane := PlaneMesh.new()
	plane.size = Vector2(w, h)
	plane.subdivide_width = 0
	plane.subdivide_depth = 0

	var mi := MeshInstance3D.new()
	mi.name = "FloorMesh"
	mi.mesh = plane
	mi.position = Vector3(w * 0.5, 0.0, h * 0.5)

	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _checker_texture()
	mat.uv1_scale = Vector3(w / 4.0, h / 4.0, 1.0)
	mat.uv1_triplanar = false
	mat.roughness = 0.95
	mat.metallic = 0.0
	mi.material_override = mat
	holder.add_child(mi)

	var body := StaticBody3D.new()
	body.name = "FloorBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, 0.4, h)
	cs.shape = box
	cs.position = Vector3(w * 0.5, -0.2, h * 0.5)
	body.add_child(cs)
	holder.add_child(body)
	return holder


static func _make_box(r: Rect2, height: float, color: Color, node_name: String) -> Node3D:
	var holder := Node3D.new()
	holder.name = node_name

	var mesh := BoxMesh.new()
	mesh.size = Vector3(maxf(r.size.x, 0.05), height, maxf(r.size.y, 0.05))

	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mat.metallic = 0.05
	mi.material_override = mat
	holder.add_child(mi)

	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = mesh.size
	cs.shape = shape
	body.add_child(cs)
	holder.add_child(body)

	holder.position = Vector3(r.position.x + r.size.x * 0.5, height * 0.5, r.position.y + r.size.y * 0.5)
	return holder


## A 4x4 cell checker, generated once. Cells are 12.5 cm on a 4 m tile, which is
## enough texture for the eye to read motion and speed across the floor.
static func _checker_texture() -> ImageTexture:
	var px := 64
	var cells := 8
	var img := Image.create(px, px, false, Image.FORMAT_RGB8)
	var cell := int(px / cells)
	for y in px:
		for x in px:
			var cx := int(x / cell)
			var cy := int(y / cell)
			img.set_pixel(x, y, FLOOR_A if (cx + cy) % 2 == 0 else FLOOR_B)
	return ImageTexture.create_from_image(img)
