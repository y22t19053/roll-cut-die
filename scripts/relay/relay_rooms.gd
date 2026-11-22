extends Node3D
## Repeatable nine-metre soundstages. Each seam is one continuous finish line.
const LENGTH := 9.0
const DECK := Color("514f50")
const FLAT := Color("847362")
const WHITE := Color("f3dfad")
const IRON := Color("333139")
const SET_INKS := {"straight":Color("bd5743"),"tee":Color("4f9187"),"cross":Color("bb914d"),"zig":Color("8075a3")}
const LETTER_INKS := {"s": Color("b96452"), "h": Color("579888"), "u": Color("c59c59"), "l": Color("8776a8"), "n": Color("6288ae"), "x": Color("a57b58"), "i": Color("7d8a96"), "o": Color("a8874f")}
## Plan view, north to south. Dots are walkable lanes; # becomes solid scenery.
## The outer columns are mouths, not decoration: the S must double back twice.
##
## Every shape here has to answer one question the turn asks: after the crew
## rebuilds the set the other way round, can you still read the way through?
## i is a single bar across the middle — turning it changes nothing, and that is
## the point of the shape (a breather). l keeps its corner in a different corner
## after a turn. o keeps its ring but swaps which side you went round. h and s are
## the two-lane shapes that turn into their own mirror.
const LANES := {
	"s": ["......#","#####.#","#.....#","#.#####","#......"],
	"h": ["#.###.#","#.###.#",".......","#.###.#","#.###.#"],
	"u": ["..###..","#.###.#","#.###.#","#.###.#","#.....#"],
	"l": ["..#####","#.#####","#.#####","#.#####","#......"],
	"n": ["#..##..","#...#.#","#.#...#","#.##..#","..###.#"],
	"x": ["..###..","#..#..#","##...##","#..#..#","..###.."],
	"i": [".......",".......","#######",".......","......."],
	"o": [".#####.",".#...#.",".#...#.",".#...#.",".#####."],
}
var _count := 0
var _cap: Node3D
var _inks := {}
var _rooms: Array[Node3D] = []
## Per room: the dollies that sweep it, each {node, phase, period, amp}. A mod may
## add a second one, or take the room's only one away.
var _dollies: Array = []
## Per room: where the belt runs, if the crew laid one (stage-local z).
var _belts := {}
## Per room: the crew member who crosses the set and never looks up.
var _runners := {}
var _doubles := {}
## Per room: where the deck is taped off as a goof (stage-local x, z).
var _goofs := {}
## Per room: the green screen's key square — stand in it and you are not in the plate.
var _keys := {}
## Per room: the mezzanine — a catwalk you can be up on while the deck sweeps under you.
var _mezz := {}
var _wires := {}
var _notes := {}
var _plans := {}
## You are on the hook when you stand on the painted mark: the rig does the rest.
func wire_at(world_pos: Vector3, room_index: int) -> bool:
	if not _wires.has(room_index): return false
	var p: Vector3 = (_rooms[room_index] as Node3D).to_local(world_pos)
	var w: Dictionary = _wires[room_index]
	if p.y < -0.35 or p.y > 0.55: return false
	return absf(p.x - float(w["x0"])) < .55 and absf(p.z - float(w["z"])) < .55

## Where the wire carries you, in world space, and how high off the deck.
func wire_ride(room_index: int) -> Dictionary:
	if not _wires.has(room_index): return {}
	var w: Dictionary = _wires[room_index]
	var room: Node3D = _rooms[room_index]
	return {"from": room.to_global(Vector3(float(w["x0"]), float(w["h"]), float(w["z"]))),
		"to": room.to_global(Vector3(float(w["x1"]), float(w["h"]), float(w["z"])))}
const BELT_SPEED := 1.6
const GOOF_RADIUS := 0.62
const KEY_RADIUS := 0.66
const MEZZ_H := 1.2

## What a room's card promises. The mods are the run's only real decisions:
## tension costs attention, a clean stage gives marks and cuts back.
const MODS := {
	"": {"zh":"净场","en":"CLEAN","period":5.0,"amp":2.24,"twin":false,"throat":0.0,"dollies":1},
	"clean": {"zh":"空棚","en":"EMPTY","period":5.0,"amp":2.24,"twin":false,"throat":0.0,"dollies":0},
	"fast": {"zh":"快车","en":"FAST","period":3.4,"amp":2.24,"twin":false,"throat":0.0,"dollies":1},
	"twin": {"zh":"双推轨","en":"TWIN","period":5.0,"amp":2.24,"twin":true,"throat":0.0,"dollies":1},
	"throat": {"zh":"窄喉","en":"THROAT","period":5.0,"amp":2.24,"twin":false,"throat":1.0,"dollies":1},
}

func _has(event: String, id: String) -> bool:
	# One set can be dressed with more than one thing; the id list is comma-joined
	# so a door card can promise two changes without a second code path.
	return event == id or event.split(",", false).has(id)

func append_room(kind: String, variant: int, mod := "", final := false, event := "", hurry := 1.0) -> Dictionary:
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
	# One family opens a pocket in its side wall. The dollies never reach into it,
	# so it is a real place to stand and let a pass go by — that is the whole
	# reason to make the plan irregular instead of just re-arranging the inside.
	var pocket := kind == "l"
	for z in [-1,1]:
		if pocket and z == hand:
			for sx: float in [1.5, 7.5]:
				_box(room,Vector3(sx,.48,z*2.94),Vector3(3.0,.96,.12),FLAT,true)
				_box(room,Vector3(sx,.91,z*2.94),Vector3(2.9,.09,.14),ink)
			var pz: float = z*3.70
			_box(room,Vector3(4.5,-.12,pz),Vector3(3.0,.24,1.52),DECK,true)
			_box(room,Vector3(4.5,.48,pz+z*0.76),Vector3(3.0,.96,.12),FLAT,true)
			for px: float in [3.0,6.0]:
				_box(room,Vector3(px,.48,pz),Vector3(.12,.96,1.52),FLAT,true)
			# A painted frame around the opening: the eye needs to know that this
			# gap is a way through and not a seam in the wall.
			_box(room,Vector3(4.5,1.02,z*2.94),Vector3(3.2,.08,.16),WHITE)
			continue
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
			"period":float(spec["period"])/maxf(hurry,0.1),"amp":float(spec["amp"])})
	if _has(event, "extra"):
		# A dolly rented for the day: one more body on the track, faster than the
		# house one and out of phase, parked across the middle of the set.
		var extra := Node3D.new()
		extra.name = "CrossTrackDolly"
		room.add_child(extra)
		extra.position.x = LENGTH*.5
		_finish_cart(room, extra, ink, variant + 1)
		_cart_patch(extra, ink)
		room_dollies.append({"node":extra,"phase":PI*.5,"period":3.1/maxf(hurry,0.1),"amp":2.24})
	_dollies.append(room_dollies)
	set_clock(_count,0.0)
	if _has(event, "relight"):
		# The crew hung the lamp on the dolly: the only thing that can kill you is
		# now the brightest thing in the room, and the walls drop away.
		for d: Dictionary in room_dollies:
			var cart_node: Node3D = d["node"]
			var lamp := OmniLight3D.new()
			lamp.light_color = Color("ffd6a0")
			lamp.light_energy = 26.0
			lamp.omni_range = 3.8
			lamp.omni_attenuation = 0.5
			lamp.light_specular = 0.0
			lamp.position = Vector3(0.0, 1.05, 0.0)
			cart_node.add_child(lamp)
			_box(cart_node, Vector3(0.0, 1.02, 0.0), Vector3(.20, .16, .20), Color("ffde79"))
			# A pool of light painted on the deck as well: the omni light alone
			# loses against the key light's shadow, and this has to read at a
			# glance from twelve metres up.
			var pool := MeshInstance3D.new()
			var pool_mesh := BoxMesh.new()
			pool_mesh.size = Vector3(3.0, 0.01, 3.0)
			pool.mesh = pool_mesh
			pool.position = Vector3(0.0, 0.14, 0.0)
			var pool_mat := StandardMaterial3D.new()
			pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			pool_mat.albedo_color = Color(1.0, 0.84, 0.55, 0.22)
			pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			pool.material_override = pool_mat
			cart_node.add_child(pool)
	if _has(event, "belt"):
		# A belt on the deck. It answers to the stage: turn the set end for end
		# and it carries you the other way without a single line of new code.
		var belt_z := 0.0
		_box(room, Vector3(4.6, .015, belt_z), Vector3(6.4, .03, 1.24), Color("3b3f45"))
		_box(room, Vector3(4.6, .038, belt_z), Vector3(6.4, .01, .12), Color("9aa4ad"))
		for i in 4:
			_box(room, Vector3(2.4 + i*1.5, .04, belt_z - .44), Vector3(.34, .008, .07), Color("9aa4ad"))
			_box(room, Vector3(2.4 + i*1.5, .04, belt_z + .44), Vector3(.34, .008, .07), Color("9aa4ad"))
		_belts[_count] = belt_z
	if _has(event, "key"):
		# The green screen. Whatever stands on the key square is not in the plate:
		# the crew, the dolly and your own past all pass straight through you.
		var key_z := 2.1
		_box(room, Vector3(2.2, .012, key_z), Vector3(KEY_RADIUS*2.0, .024, KEY_RADIUS*2.0), Color("2f8f4e"))
		# Four white corner brackets, so the safe square is still a safe square
		# when green and white look the same to the person standing on it.
		var arm := KEY_RADIUS * 0.55
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var cx: float = 2.2 + sx * (KEY_RADIUS - arm * 0.5)
				var cz: float = key_z + sz * (KEY_RADIUS - arm * 0.5)
				_box(room, Vector3(cx, .018, key_z + sz * (KEY_RADIUS - .035)),
					Vector3(arm, .026, .07), WHITE)
				_box(room, Vector3(2.2 + sx * (KEY_RADIUS - .035), .018, cz),
					Vector3(.07, .026, arm), WHITE)
		_box(room, Vector3(2.2, .80, key_z + 0.78), Vector3(2.9, 1.6, .06), Color("3fae60"))
		_box(room, Vector3(2.2, .02, key_z + 0.78), Vector3(2.9, .04, .06), Color("22262a"))
		_keys[_count] = Vector2(2.2, key_z)
	if _has(event, "goof"):
		# Taped off: this patch is in the shot. Stand in it and the take is gone —
		# nobody kills you, you just are not in the movie that gets printed.
		var goof_x := 5.4
		var goof_z := -0.9 if variant % 2 == 0 else 0.9
		_box(room, Vector3(goof_x, .012, goof_z), Vector3(GOOF_RADIUS*2.0, .024, .10), WHITE)
		_box(room, Vector3(goof_x, .012, goof_z - GOOF_RADIUS*0.62), Vector3(.10, .024, GOOF_RADIUS*0.62), WHITE)
		_box(room, Vector3(goof_x, .012, goof_z + GOOF_RADIUS*0.62), Vector3(.10, .024, GOOF_RADIUS*0.62), WHITE)
		_box(room, Vector3(goof_x, .014, goof_z - .30), Vector3(.30, .02, .06), Color("c0503c"))
		_box(room, Vector3(goof_x, .014, goof_z + .30), Vector3(.30, .02, .06), Color("c0503c"))
		_goofs[_count] = Vector2(goof_x, goof_z)
	if _has(event, "double"):
		# A stand-in left on his mark. The dolly hits him, stalls a beat, and
		# carries on: the only thing on this set you can bet on instead of dodge.
		var stand := Node3D.new()
		stand.name = "Double"
		room.add_child(stand)
		_box(stand, Vector3(0, .58, 0), Vector3(.34, 1.10, .26), Color("efe6d2"))
		_box(stand, Vector3(0, 1.20, 0), Vector3(.22, .22, .22), Color("f6efe0"))
		var stand_x: float = 2.30 if _count % 2 == 1 else 6.70
		var stand_z := 1.05
		stand.position = Vector3(stand_x, 0.0, stand_z)
		# the mark he was left on
		_box(room, Vector3(stand_x, .012, stand_z - .22), Vector3(.34, .02, .05), Color("c0503c"))
		_box(room, Vector3(stand_x, .012, stand_z + .22), Vector3(.34, .02, .05), Color("c0503c"))
		_doubles[_count] = {"x": stand_x, "z": stand_z, "stall": 0.0, "held": 0.0, "last": 0.0, "node": stand}
	if _has(event, "runner"):
		# The crew's runner. He has a call to make on the far side and he is not
		# going to walk around the marks to make it.
		var body := Node3D.new()
		body.name = "Runner"
		room.add_child(body)
		_box(body, Vector3(0, .55, 0), Vector3(.40, 1.10, .32), Color("2e4258"))
		_box(body, Vector3(0, 1.17, 0), Vector3(.26, .26, .26), Color("d9c3a0"))
		_box(body, Vector3(.16, .74, .19), Vector3(.26, .02, .20), WHITE)
		body.position = Vector3(4.5, 0.0, -2.6)
		_runners[_count] = {"node": body, "speed": 1.5}
	if _has(event, "mezz"):
		# A catwalk over the lane. The deck sweeps under you instead of through you:
		# you buy the whole dolly lane with the walk up and down the two ramps.
		var mz0 := -2.7
		var mz1 := -1.4
		var mid_z := (mz0 + mz1) * 0.5
		var rise0 := 0.6
		var flat0 := 2.4
		var flat1 := 6.6
		var fall1 := 8.4
		_box(room, Vector3((flat0 + flat1) * 0.5, MEZZ_H - .06, mid_z), Vector3(flat1 - flat0, .12, mz1 - mz0), FLAT)
		# Legs, so it reads as a built thing instead of a floating slab.
		for lx in [flat0 + .3, (flat0 + flat1) * 0.5, flat1 - .3]:
			_box(room, Vector3(lx, MEZZ_H * 0.5, mz1 + .06), Vector3(.12, MEZZ_H, .12), IRON)
		# Two ramps, drawn as a stack of steps (0.15 m risers read fine from 12 m).
		var steps := 8
		for i in steps:
			var t0 := float(i) / float(steps)
			var t1 := float(i + 1) / float(steps)
			var h := MEZZ_H * (t0 + t1) * 0.5
			_box(room, Vector3(lerpf(rise0, flat0, (t0 + t1) * 0.5), h - .06, mid_z),
				Vector3((flat0 - rise0) / float(steps) + .02, .14, mz1 - mz0), FLAT)
			_box(room, Vector3(lerpf(flat1, fall1, (t0 + t1) * 0.5), h - .06, mid_z),
				Vector3((fall1 - flat1) / float(steps) + .02, .14, mz1 - mz0), FLAT)
		_mezz[_count] = {"rise0": rise0, "flat0": flat0, "flat1": flat1, "fall1": fall1,
			"z0": mz0, "z1": mz1, "h": MEZZ_H}
	if _has(event, "wire"):
		# A flying rig, and only one pick-up point: the crew hooks you at the near
		# end and drops you at the far end. You cannot steer it, and you cannot
		# use it twice — the wire is only good for the pass it was rigged for.
		var wz := 0.9
		_box(room, Vector3(1.0, 1.90, wz), Vector3(7.0, .035, .035), IRON)
		for px: float in [0.9, 8.1]:
			_box(room, Vector3(px, 1.0, wz), Vector3(.10, 2.0, .10), IRON)
		_box(room, Vector3(1.0, 1.86, wz), Vector3(.16, .12, .16), Color("e8c169"))
		# A painted mark on the deck: this is where you stand to be hooked up.
		_box(room, Vector3(1.0, .012, wz), Vector3(1.0, .02, 1.0), Color("e8c169"))
		_wires[_count] = {"x0": 1.0, "x1": 8.1, "z": wz, "h": 1.22}
	if _count==0:
		_buffer(room,0,-1)
		_line(room,0)
	_dress(room, kind, ink, variant)
	if is_instance_valid(_cap):
		for part: MeshInstance3D in _cap.find_children("*","MeshInstance3D",true,false): part.mesh = null
		_cap.get_parent().remove_child(_cap)
		_cap.queue_free()
	_cap = _buffer(room,LENGTH,1)
	# A strip room is the first hollow plan: you enter low and leave high, so the
	# crossing is diagonal instead of a walk straight down the middle.
	var exit_z := 1.95 if kind == "i" else 0.0
	var entry_z := -1.60 if kind == "i" else 0.0
	_plans[_count] = {"entry": Vector3(0,.05,entry_z), "exit": Vector3(LENGTH,.05,exit_z)}
	_line(room,LENGTH,final,exit_z,2.1 if kind == "i" else 2.62)
	_count += 1
	var end := room.to_global(Vector3(LENGTH,.05,0))
	var stops: Array[Vector3] = [end]
	# The plan comes back with the room so a run can be written down and rebuilt
	# from the same choices it was made of.
	return {"start":room.to_global(Vector3(0,.05,0)),"end":end,"stops":stops,
		"kind":kind,"variant":variant,"mod":mod,"final":final,"event":event}

## Every family gets its own furniture and its own floor inlay, so the five sets
## are five places rather than five wall layouts. Nothing here is solid: dressing
## must never change a route or a timing, only what the room looks like.
func _dress(room: Node3D, kind: String, ink: Color, variant: int) -> void:
	var side := 1.0 if variant % 2 == 0 else -1.0
	# A strip of paint down the lane: this is the family's colour on the deck.
	_box(room, Vector3(LENGTH * 0.5, .011, side * 2.62), Vector3(LENGTH - 1.2, .02, .30), ink.darkened(0.35))
	# One call note per set, near the far end and off the lane. Walking over it is
	# the only "lore" in the game: no dialogue, no menu, just the paperwork the
	# crew left on the deck.
	_box(room, Vector3(7.25, .014, 2.24), Vector3(.42, .02, .30), Color("e9dfc4"))
	_box(room, Vector3(7.55, .20, 2.42), Vector3(.05, .40, .05), IRON)
	_box(room, Vector3(7.55, .42, 2.42), Vector3(.13, .10, .13), Color("ffde79"))
	_notes[_count] = Vector3(7.25, .05, 2.24)
	match kind:
		"i":
			# A strip room: lighting stands and cable runs, nothing else.
			for x: float in [2.2, 6.8]:
				_box(room, Vector3(x, 1.05, -2.62), Vector3(.09, 2.1, .09), IRON)
				_box(room, Vector3(x, 2.12, -2.62), Vector3(.34, .10, .34), Color("ffde79"))
			_box(room, Vector3(LENGTH * 0.5, .06, 2.55), Vector3(LENGTH - 2.4, .10, .16), IRON)
		"l":
			# A corner room: crates stacked where the crew dumped them.
			_box(room, Vector3(1.6, .30, 2.35), Vector3(.9, .58, .9), FLAT)
			_box(room, Vector3(1.7, .78, 2.40), Vector3(.7, .44, .7), FLAT.darkened(0.12))
			_box(room, Vector3(2.5, .22, 2.55), Vector3(1.1, .42, .7), WHITE.darkened(0.55))
			_box(room, Vector3(7.4, .45, -2.45), Vector3(.5, .9, .5), IRON)
		"o":
			# A ring room: the scaffold that will be taken down tonight.
			for x: float in [2.9, 5.4, 7.9]:
				_box(room, Vector3(x, .95, -2.55), Vector3(.10, 1.9, .10), IRON)
			_box(room, Vector3(5.4, 1.92, -2.55), Vector3(5.4, .07, .07), IRON)
			_box(room, Vector3(3.0, 1.30, 2.50), Vector3(2.6, 2.2, .06), ink.darkened(0.55))
		"h":
			# Two lanes: an overhead rail with sandbags, the way a flat is braced.
			_box(room, Vector3(LENGTH * 0.5, 2.30, 0), Vector3(LENGTH - 1.0, .10, .10), IRON)
			for x: float in [2.4, 4.6, 6.8]:
				_box(room, Vector3(x, 2.05, 0), Vector3(.24, .40, .18), FLAT.darkened(0.2))
			_box(room, Vector3(1.2, .55, -2.55), Vector3(.8, 1.1, .5), FLAT)
		_:
			# Two bends: a duct and a painted mark where a rig used to stand.
			_box(room, Vector3(LENGTH * 0.5, .32, side * 2.55), Vector3(LENGTH - 1.6, .55, .5), IRON)
			_box(room, Vector3(7.2, .02, -side * 2.1), Vector3(1.4, .02, 1.4), ink.darkened(0.45))

## The paperwork on the deck. Returns true while the player is standing on it.
func note_at(world_pos: Vector3, room_index: int) -> bool:
	if not _notes.has(room_index): return false
	var room: Node3D = _rooms[room_index]
	if room == null: return false
	var p: Vector3 = room.to_local(world_pos)
	return p.y < 0.6 and Vector2(p.x, p.z).distance_to(Vector2(float(_notes[room_index].x), float(_notes[room_index].z))) < 0.55

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
	# Camera forward, counterweight back, push bars on both sides: the silhouette
	# tells you which way the thing will swing before it swings.
	_box(cart,Vector3(0,.86,.22),Vector3(.52,.30,.34),ink)
	_box(cart,Vector3(0,.86,-.26),Vector3(.30,.26,.22),IRON)
	_disc(cart,Vector3(0,.86,.41),.13,.12,IRON)
	_box(cart,Vector3(0,1.07,.22),Vector3(.34,.06,.20),IRON)
	for sx: float in [-.46,.46]:
		_box(cart,Vector3(sx,.62,-.06),Vector3(.06,.52,.06),IRON)

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
static var _wall_tex: Texture2D

## Three painted surfaces: the deck you walk on, the walls that hold the set in,
## and the flats that make the shapes. Each falls back to its own painted grain,
## and every one of them is a near-white multiply mask so the room colour still
## comes from the palette rather than from the photograph.
static func _surface(color: Color) -> Texture2D:
	if color == DECK:
		if _deck_tex == null: _deck_tex = _load_or_grain("res://assets/textures/deck_ai.png")
		return _deck_tex
	if color == IRON:
		if _flat_tex == null: _flat_tex = _load_or_grain("res://assets/textures/flat.png")
		return _flat_tex
	if _wall_tex == null: _wall_tex = _load_or_grain("res://assets/textures/wall.png")
	return _wall_tex


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


func plan(room_index: int) -> Dictionary:
	return _plans.get(room_index, {})

## Did the player just reach the door this leg was pointed at? The light line and
## this test read the same plan, so a room whose exit sits off-axis needs no
## second rule — only a different point.
func crossed(world_pos: Vector3, room_index: int, returning: bool) -> bool:
	var p := plan(room_index)
	if p.is_empty(): return false
	var room: Node3D = _rooms[room_index]
	if room == null: return false
	var goal: Vector3 = p["entry"] if returning else p["exit"]
	var lp: Vector3 = room.to_local(world_pos)
	return Vector2(lp.x, lp.z).distance_to(Vector2(goal.x, goal.z)) <= 1.35


func _line(room: Node3D, x: float, final := false, zc := 0.0, span := 2.62) -> void:
	_box(room,Vector3(x,.016,zc),Vector3(.13,.024,span),WHITE)
	if not final: return
	# The last line of the run is dressed like a wrap: tape under the chalk line
	# and a gate you run under. Low and pale, so it reads at fifty-five degrees
	# from the far seam instead of getting lost against the dark.
	var gx := x - 0.25
	_box(room,Vector3(x-.12,.012,0),Vector3(.30,.018,2.86),Color("ffde79"))
	for z: float in [-1.95,1.95]:
		_box(room,Vector3(gx,.62,z),Vector3(.09,1.24,.09),WHITE)
		_box(room,Vector3(gx,.26,z),Vector3(.17,.12,.17),Color("ffde79"))
	_box(room,Vector3(gx,1.26,0),Vector3(.10,.10,3.98),WHITE)
	_box(room,Vector3(gx,1.26,0),Vector3(.05,.22,.92),Color("ffde79"))

func _z_of(d: Dictionary,t: float) -> float:
	return float(d["amp"])*sin(TAU*t/float(d["period"])+float(d["phase"]))

## The double stands on a mark in the dolly's lane. The dolly hits him, stops for a
## beat, and goes on: one bet you can make about the crew, not about yourself.
## `stall` is subtracted from the stage clock for both drawing and hazard tests, so
## what you see is what kills you.
func _stall_t(room_index: int,t: float) -> float:
	if not _doubles.has(room_index): return t
	var d: Dictionary = _doubles[room_index]
	var dt := maxf(t-float(d["last"]),0.0)
	d["last"] = t
	var here := t-float(d["stall"])
	var touching := false
	for c: Dictionary in _dollies[room_index]:
		if absf(_z_of(c,here)-float(d["z"]))<0.55: touching = true
	if touching and float(d["held"])<0.9:
		d["stall"] = float(d["stall"])+dt
		d["held"] = float(d["held"])+dt
	elif not touching:
		d["held"] = 0.0
	return t-float(d["stall"])

func set_clock(room_index: int,t: float) -> void:
	if room_index<0 or room_index>=_dollies.size(): return
	var te := _stall_t(room_index,t)
	for d: Dictionary in _dollies[room_index]: d["node"].position.z = _z_of(d,te)
	# The one crew member who does not respect the marks keeps walking across.
	if _runners.has(room_index):
		var r: Dictionary = _runners[room_index]
		var span := 5.2
		var s := fposmod(t*float(r["speed"])/span,2.0)
		var z := -span*0.5 + (s if s<=1.0 else 2.0-s)*span
		var body: Node3D = r["node"]
		body.position.z = z
		body.rotation.y = 0.0 if s<=1.0 else PI

## What the deck is doing under your feet here. Stage-local, so a set that has been
## turned end for end pushes you the other way in the world — the belt answers to
## the stage, not to the camera.
func belt_push(world_pos: Vector3,room_index: int) -> Vector3:
	if not _belts.has(room_index): return Vector3.ZERO
	var room: Node3D = _rooms[room_index]
	var p := room.to_local(world_pos)
	if p.y > 0.5: return Vector3.ZERO # The belt moves the deck, not the catwalk over it.
	if p.x<1.0 or p.x>8.0: return Vector3.ZERO
	if absf(p.z-float(_belts[room_index]))>.62: return Vector3.ZERO
	var dir := room.global_transform.basis.x
	dir.y = 0.0
	return dir.normalized()*BELT_SPEED

## How high the walking surface is at this point of the room. Only the catwalk
## changes it; everywhere else the deck is the deck.
func floor_height(world_pos: Vector3, room_index: int) -> float:
	if not _mezz.has(room_index): return 0.0
	var m: Dictionary = _mezz[room_index]
	var p: Vector3 = (_rooms[room_index] as Node3D).to_local(world_pos)
	if p.z < float(m["z0"]) or p.z > float(m["z1"]): return 0.0
	var h := float(m["h"])
	var x := p.x
	if x >= float(m["flat0"]) and x <= float(m["flat1"]): return h
	if x >= float(m["rise0"]) and x < float(m["flat0"]):
		return h * (x - float(m["rise0"])) / maxf(float(m["flat0"]) - float(m["rise0"]), 0.001)
	if x > float(m["flat1"]) and x <= float(m["fall1"]):
		return h * (float(m["fall1"]) - x) / maxf(float(m["fall1"]) - float(m["flat1"]), 0.001)
	return 0.0

## The runner is not a trap you can learn the timing of by watching a mark: he
## crosses wherever he likes, whenever he likes, all set long.
func crew_at(world_pos: Vector3,room_index: int) -> bool:
	if not _runners.has(room_index): return false
	var p := _rooms[room_index].to_local(world_pos)
	if p.y<-.35 or p.y>0.95: return false
	var r: Dictionary = _runners[room_index]
	var body: Node3D = r["node"]
	return absf(p.x-body.position.x)<.20+.32 and absf(p.z-body.position.z)<.17+.32

## You are standing in the shot. This is not a hazard you can body-check: it is a
## mistake the take cannot survive.
## Standing on the key square means you are not in the plate: nothing here can
## touch you, because you are not in the image that gets printed.
func key_at(world_pos: Vector3,room_index: int) -> bool:
	if not _keys.has(room_index): return false
	var p := _rooms[room_index].to_local(world_pos)
	if p.y<-.35 or p.y>1.35: return false
	var k: Vector2 = _keys[room_index]
	return Vector2(p.x-k.x,p.z-k.y).length() < KEY_RADIUS

func goof_at(world_pos: Vector3,room_index: int) -> bool:
	if not _goofs.has(room_index): return false
	var p := _rooms[room_index].to_local(world_pos)
	if p.y<-.35 or p.y>1.35: return false
	var g: Vector2 = _goofs[room_index]
	return Vector2(p.x-g.x,p.z-g.y).length() < GOOF_RADIUS

func hazard_at(world_pos: Vector3,room_index: int,t: float) -> bool:
	if room_index<0 or room_index>=_rooms.size(): return false
	if room_index>=_dollies.size(): return false
	var p := _rooms[room_index].to_local(world_pos)
	if p.y<-.35 or p.y>1.10: return false
	# Read the same stage clock the carts were drawn with, so a stalled cart is
	# actually where it looks like it is.
	if _doubles.has(room_index): t -= float(_doubles[room_index]["stall"])
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
