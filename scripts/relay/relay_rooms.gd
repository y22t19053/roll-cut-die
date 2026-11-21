extends Node3D
## Repeatable nine-metre soundstages. Each seam is one continuous finish line.
const LENGTH := 9.0
const DECK := Color("514f50")
const FLAT := Color("847362")
const WHITE := Color("f3dfad")
const IRON := Color("333139")
const SET_INKS := {"straight":Color("bd5743"),"tee":Color("4f9187"),"cross":Color("bb914d"),"zig":Color("8075a3")}
const LETTER_INKS := {"s": Color("b96452"), "h": Color("579888"), "u": Color("c59c59"), "l": Color("8776a8"), "n": Color("6288ae"), "x": Color("a57b58")}
## Plan view, north to south. Dots are walkable lanes; # becomes solid scenery.
## The outer columns are mouths, not decoration: the S must double back twice.
const LANES := {
	"s": ["......#","#####.#","#.....#","#.#####","#......"],
	"h": ["#.###.#","#.###.#",".......","#.###.#","#.###.#"],
	"u": ["..###..","#.###.#","#.###.#","#.###.#","#.....#"],
	"l": ["..#####","#.#####","#.#####","#.#####","#......"],
	"n": ["#..##..","#...#.#","#.#...#","#.##..#","..###.#"],
	"x": ["..###..","#..#..#","##...##","#..#..#","..###.."],
}
var _count := 0
var _cap: Node3D
var _inks := {}
var _rooms: Array[Node3D] = []
## Per room: the dollies that sweep it, each {node, phase, period, amp}. A mod may
## add a second one, or take the room's only one away.
var _dollies: Array = []

## What a room's card promises. The mods are the run's only real decisions:
## tension costs attention, a clean stage gives marks and cuts back.
const MODS := {
	"": {"zh":"净场","en":"CLEAN","period":5.0,"amp":2.24,"twin":false,"throat":0.0,"dollies":1},
	"clean": {"zh":"空棚","en":"EMPTY","period":5.0,"amp":2.24,"twin":false,"throat":0.0,"dollies":0},
	"fast": {"zh":"快车","en":"FAST","period":3.4,"amp":2.24,"twin":false,"throat":0.0,"dollies":1},
	"twin": {"zh":"双推轨","en":"TWIN","period":5.0,"amp":2.24,"twin":true,"throat":0.0,"dollies":1},
	"throat": {"zh":"窄喉","en":"THROAT","period":5.0,"amp":2.24,"twin":false,"throat":1.0,"dollies":1},
}

func append_room(kind: String, variant: int, mod := "") -> Dictionary:
	assert(is_inside_tree(), "Mount RelayRooms before requesting world positions")
	var spec: Dictionary = MODS.get(mod, MODS[""])
	var room := Node3D.new()
	room.name = "Bay%d_%s" % [_count+1,kind]
	room.position.x = _count*LENGTH
	add_child(room)
	_rooms.append(room)
	var ink: Color = SET_INKS.get(kind, LETTER_INKS.get(kind, SET_INKS.straight))
	var hand := 1 if posmod(variant,2)==0 else -1
	_box(room,Vector3(4.5,-.12,0),Vector3(9,.24,6),DECK,true)
	for z in [-1,1]:
		_box(room,Vector3(4.5,.48,z*2.94),Vector3(9,.96,.12),FLAT,true)
		_box(room,Vector3(4.5,.91,z*2.94),Vector3(8.84,.09,.14),ink)
		# Twin grip bays make a narrow throat at each end, not a sealed door.
		# THROAT walks them in to 1.62 m apart: the mouth is now a decision.
		var bay := .60 if LANES.has(kind) else 1.16
		var bay_z := 1.62 if float(spec["throat"]) > 0.0 else 2.16
		for x: float in [bay*.5,LENGTH-bay*.5]:
			_box(room,Vector3(x,.34,z*bay_z),Vector3(bay,.68,1.68),ink,true)
			_box(room,Vector3(x,.70,z*bay_z),Vector3(bay-.04,.04,1.64),IRON)
	if LANES.has(kind):
		_letter_lanes(room, LANES[kind], hand, ink)
	else:
		_island(room, kind, hand, ink)
	var first_x := 2.30 if hand>0 else 6.70
	if LANES.has(kind): first_x = 1.70 if hand>0 else 7.30
	var tracks: Array = []
	if int(spec["dollies"]) > 0:
		tracks.append(first_x)
	if bool(spec["twin"]): tracks.append(LENGTH-first_x)
	var room_dollies: Array = []
	for i in tracks.size():
		var cart := Node3D.new()
		cart.name = "CrossTrackDolly"
		room.add_child(cart)
		cart.position.x = tracks[i]
		_finish_cart(room, cart, ink, variant + i*2)
		_cart_patch(cart, ink)
		room_dollies.append({"node":cart,"phase":posmod(variant+i*2,4)*PI*.5,
			"period":float(spec["period"]),"amp":float(spec["amp"])})
	_dollies.append(room_dollies)
	set_clock(_count,0.0)
	if _count==0:
		_buffer(room,0,-1)
		_line(room,0)
	if is_instance_valid(_cap):
		for part: MeshInstance3D in _cap.find_children("*","MeshInstance3D",true,false): part.mesh = null
		_cap.get_parent().remove_child(_cap)
		_cap.queue_free()
	_cap = _buffer(room,LENGTH,1)
	_line(room,LENGTH)
	_count += 1
	var end := room.to_global(Vector3(LENGTH,.05,0))
	var stops: Array[Vector3] = [end]
	# The plan comes back with the room so a run can be written down and rebuilt
	# from the same five choices it was made of.
	return {"start":room.to_global(Vector3(0,.05,0)),"end":end,"stops":stops,
		"kind":kind,"variant":variant,"mod":mod}

func _letter_lanes(room: Node3D, rows: Array, hand: int, ink: Color) -> void:
	# Consolidate horizontal wall runs; leave open vestibules to turn at either seam.
	for row in rows.size():
		var x := 0
		while x < 7:
			if rows[row][x] != "#":
				x += 1
				continue
			var first := x
			while x < 7 and rows[row][x] == "#": x += 1
			var width := (x-first)*0.68
			var z := (row-2)*1.12*hand
			_box(room, Vector3(2.12+first*.68+width*.5,.36,z), Vector3(width,.72,1.12), ink, true)
			# A chalk cap in the same off-white as the finish line: at fifty-five
			# degrees the wall face is a flat block, and the cap is what draws the
			# letter's line. The set keeps its own ink on the faces.
			_box(room, Vector3(2.12+first*.68+width*.5,.735,z), Vector3(width,.03,1.12), WHITE)


func _island(room: Node3D, kind: String, hand: int, ink: Color) -> void:
	var island := Vector3(4.5,.34,hand*.15)
	_box(room,island,Vector3(2.28,.68,1.30),ink,true)
	var top := island+Vector3.UP*.34
	match kind:
		"tee": # Fresnel lamp and lit face
			_box(room,top+Vector3.UP*.24,Vector3(.11,.48,.11),IRON)
			_box(room,top+Vector3.UP*.59,Vector3(.52,.48,.60),ink)
			_disc(room,top+Vector3(0,.59,.32),.2,.06,WHITE)
		"cross": # Two wound film reels and a crank
			for x in [-.38,.38]:
				_disc(room,top+Vector3(x,.37,0),.35,.25,IRON)
				_disc(room,top+Vector3(x,.37,.14),.11,.04,ink)
		"zig": # Slated clapstick with diagonal chalk bars
			_box(room,top+Vector3.UP*.40,Vector3(1.25,.79,.12),IRON)
			var stick := _box(room,top+Vector3(-.01,.92,0),Vector3(1.25,.13,.14),ink)
			stick.rotation.z = .19
			for x in [-.44,-.13,.18,.49]: _box(stick,Vector3(x,0,.076),Vector3(.10,.13,.012),WHITE).rotation.z = -.3
		_: # Camera body, lens and twin magazines
			_box(room,top+Vector3.UP*.29,Vector3(.94,.52,.5),ink)
			_disc(room,top+Vector3(0,.31,.34),.18,.25,IRON)
			for x in [-.23,.23]: _disc(room,top+Vector3(x,.69,0),.21,.24,IRON)

func _finish_cart(room: Node3D, cart: Node3D, ink: Color, variant: int) -> void:
	for x in [-.33,.33]:
		_box(room,Vector3(cart.position.x+x,.015,0),Vector3(.045,.025,5.32),IRON)
		for z in [-.28,.28]: _disc(cart,Vector3(x,.14,z),.14,.1,IRON).rotation.y = PI/2
	_box(cart,Vector3(0,.28,0),Vector3(.88,.17,.72),ink)
	_box(cart,Vector3(0,.53,0),Vector3(.14,.38,.15),IRON)
	_box(cart,Vector3(0,.83,0),Vector3(.58,.34,.35),ink)
	_disc(cart,Vector3(0,.84,.23),.12,.16,IRON)

## The trolley throws a pool of light on the deck. It is set lighting, not a
## danger ring: the eye should place the cart a beat before the body does.
func _cart_patch(cart: Node3D, ink: Color) -> void:
	var mi := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.radial_segments = 20
	disc.top_radius = .62
	disc.bottom_radius = .62
	disc.height = .008
	mi.mesh = disc
	mi.position = Vector3(0, .012, 0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(ink.r, ink.g, ink.b, .16)
	mi.material_override = mat
	cart.add_child(mi)


## Paper grain for the deck and the flats. Without a texture the set reads as
## untextured blocks no matter how good the light is.
static var _grain_tex: ImageTexture
static var _deck_tex: Texture2D
static var _flat_tex: Texture2D

## The two painted surfaces. Loaded once; the fallback is the procedural grain so
## a missing asset never leaves the set bare.
static func _surface(color: Color) -> Texture2D:
	if color == DECK:
		if _deck_tex == null: _deck_tex = _load_or_grain("res://assets/textures/deck.png")
		return _deck_tex
	if _flat_tex == null: _flat_tex = _load_or_grain("res://assets/textures/flat.png")
	return _flat_tex


static func _load_or_grain(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null: return tex
	# A build without an editor pass has no .import cache, so the paint would
	# vanish exactly where it matters. Read the PNG off disk instead.
	if FileAccess.file_exists(path):
		var img := Image.new()
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
			return ImageTexture.create_from_image(img)
	return _grain()

static func _grain() -> ImageTexture:
	if _grain_tex != null:
		return _grain_tex
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in 64:
		for x in 64:
			var v := 0.88 + rng.randf() * 0.12
			img.set_pixel(x, y, Color(v, v, v))
	_grain_tex = ImageTexture.create_from_image(img)
	return _grain_tex


func _line(room: Node3D, x: float) -> void:
	_box(room,Vector3(x,.016,0),Vector3(.13,.024,2.62),WHITE)

func _z_of(d: Dictionary,t: float) -> float:
	return float(d["amp"])*sin(TAU*t/float(d["period"])+float(d["phase"]))

func set_clock(room_index: int,t: float) -> void:
	if room_index<0 or room_index>=_dollies.size(): return
	for d: Dictionary in _dollies[room_index]: d["node"].position.z = _z_of(d,t)

func hazard_at(world_pos: Vector3,room_index: int,t: float) -> bool:
	if room_index<0 or room_index>=_rooms.size(): return false
	if room_index>=_dollies.size(): return false
	var p := _rooms[room_index].to_local(world_pos)
	if p.y<-.35 or p.y>1.10: return false
	# Circle vs cart footprint: the same pose as set_clock, even after a cut.
	for d: Dictionary in _dollies[room_index]:
		var dx := maxf(0,absf(p.x-d["node"].position.x)-.44)
		var dz := maxf(0,absf(p.z-_z_of(d,t))-.36)
		if dx*dx+dz*dz<=.32*.32: return true
	return false

func _disc(root: Node3D, at: Vector3, radius: float, depth: float, color: Color) -> MeshInstance3D:
	var mi := _box(root,at,Vector3.ONE,color)
	var wheel := CylinderMesh.new()
	wheel.radial_segments = 14
	wheel.top_radius = radius
	wheel.bottom_radius = radius
	wheel.height = depth
	mi.mesh = wheel
	mi.rotation.x = PI/2
	return mi

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
		# A little self-light keeps the flat paint readable through the fog
		# without turning the set into neon.
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = .10
		if color == DECK or color == FLAT:
			# Painted plywood, not a colour chip: the texture is what tells a
			# soundstage floor from a grey box at twelve metres.
			mat.albedo_texture = _surface(color)
			mat.uv1_scale = Vector3(3.2, 3.2, 3.2)
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
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
