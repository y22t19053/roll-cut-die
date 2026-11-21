extends Node3D
## Seven 3m bays per room. Only the temporary terminal buffer is replaced;
## rooms, props and their original wall bodies survive every append.
const CELL := 3.0
const LENGTH := 21.0
const DECK := Color("555456")
const FLAT := Color("746854")
const WARM := Color("e3a559")
const COOL := Color("72b8b4")
var _count := 0
var _cap: Node3D
var _inks := {}

func append_room(kind: String, variant: int) -> Dictionary:
	assert(is_inside_tree(), "Mount RelayRooms before requesting world positions")
	var room := Node3D.new()
	room.name = "Bay%d_%s" % [_count+1, kind]
	room.position.x = _count * LENGTH
	add_child(room)
	var tiles := {}
	var marks: Array[Vector2i] = []
	var side := 1 if posmod(variant,2)==0 else -1
	# Pattern coordinates are hand-authored, then mirrored as one piece.
	match kind:
		"tee":
			_strip(tiles,0,6,0)
			for z in [1,2]: tiles[Vector2i(3,z*side)] = true
			marks.append(Vector2i(3,2*side))
		"cross":
			_strip(tiles,0,6,0)
			for z in [-2,-1,1,2]: tiles[Vector2i(3,z)] = true
			marks.assign([Vector2i(3,2*side), Vector2i(3,-2*side)])
		"zig":
			_strip(tiles,0,1,0)
			_strip(tiles,1,3,side)
			_strip(tiles,3,5,-side)
			_strip(tiles,5,6,0)
			tiles[Vector2i(3,0)] = true
			marks.assign([Vector2i(2,side), Vector2i(4,-side)])
		_: # A clear sightline end-to-end, with a side passage around the flat.
			_strip(tiles,0,6,0)
			_strip(tiles,1,5,2*side)
			for x in [1,5]: tiles[Vector2i(x,side)] = true
	var stops: Array[Vector3] = []
	for cell: Vector2i in tiles:
		var p := _center(cell)
		_box(room,p+Vector3.DOWN*.12,Vector3(3,.24,3),DECK,true)
		for dir: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if tiles.has(cell+dir): continue
			if (cell == Vector2i.ZERO and dir == Vector2i.LEFT) or (cell == Vector2i(6,0) and dir == Vector2i.RIGHT): continue
			var lateral := dir.x != 0
			var offset := Vector3(dir.x,0,dir.y)*1.48
			var size := Vector3(.12,1.15,3) if lateral else Vector3(3,1.15,.12)
			_box(room,p+offset+Vector3.UP*.575,size,FLAT,true)
			if cell.y != 0:
				var rail := Vector3(.15,.085,2.85) if lateral else Vector3(2.85,.085,.15)
				_box(room,p+offset+Vector3.UP*1.03,rail,WARM if cell.y*side>0 else COOL)
	# Scenic panels stand outside the rail, never inside either lane.
	var first_mark := Vector2i(3,2*side) if kind != "zig" else Vector2i(2,side)
	var flat := _center(first_mark)+Vector3(0,0,1.70*side)
	_box(room,flat+Vector3.UP*.85,Vector3(2.48,1.70,.16),Color("536c69") if side>0 else Color("8c6553"))
	for x: float in [-1.08,1.08]:
		_box(room,flat+Vector3(x,.85,-side*.105),Vector3(.085,1.68,.07),Color("bb9b70"))
	_box(room,flat+Vector3(0,1.04,-side*.11),Vector3(2.43,.09,.065),Color("bb9b70")).rotation.z = side*.30
	for cell: Vector2i in marks:
		var p := _center(cell)
		stops.append(room.to_global(p+Vector3.UP*.05))
		# Gaffer's tape cross, flush with the deck. No trigger physics.
		_box(room,p+Vector3.UP*.013,Vector3(.16,.018,1.20),WARM)
		_box(room,p+Vector3.UP*.016,Vector3(1.20,.018,.16),WARM)
	if _count == 0: _buffer(room,0,-1)
	if is_instance_valid(_cap):
		_cap.get_parent().remove_child(_cap)
		_cap.queue_free()
	_cap = _buffer(room,LENGTH,1)
	_box(room,Vector3(LENGTH-.07,.012,0),Vector3(.12,.02,2.82),COOL)
	_count += 1
	var end := room.to_global(Vector3(LENGTH,.05,0))
	stops.append(end)
	return {"start":room.to_global(Vector3(0,.05,0)),"end":end,"stops":stops}

func _strip(tiles: Dictionary, lo: int, hi: int, z: int) -> void:
	for x in range(lo,hi+1): tiles[Vector2i(x,z)] = true

func _center(cell: Vector2i) -> Vector3:
	return Vector3((cell.x+.5)*CELL,0,cell.y*CELL)

func _buffer(room: Node3D, x: float, direction: int) -> Node3D:
	var node := Node3D.new()
	room.add_child(node)
	node.position.x = x
	_box(node,Vector3(direction, -.12,0),Vector3(2,.24,3),DECK,true)
	_box(node,Vector3(direction*1.97,.575,0),Vector3(.12,1.15,3),FLAT,true)
	for z in [-1.48,1.48]:
		_box(node,Vector3(direction,.575,z),Vector3(2,1.15,.12),FLAT,true)
	return node

func _box(root: Node3D, at: Vector3, size: Vector3, color: Color, solid := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = at
	if not _inks.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = .90
		_inks[color] = mat
	mi.material_override = _inks[color]
	root.add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		mi.add_child(body)
		body.add_child(cs)
	return mi
