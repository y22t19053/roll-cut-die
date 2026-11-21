extends RefCounted
## Coordinates are stage metres, not camera-relative. Both takes share this set.
const DOCK := Vector3(4,0.05,28)
const SWITCH := Vector3(28,0.05,4)
const DECK := Vector3(33,0.05,6)
const BOOTH := Vector3(33,0.05,27)

# Two opposing stage portals on the eastward approach from the loading dock.
# Map props supply the posts' visible surfaces and their actual collision.
const PORTAL_X := [6.0, 11.0]
const PORTAL_Z := 28.0
const OPENING := 2.0

static func layout() -> Dictionary:
	var plan := {"size":[38,32], "spawn":[4,28], "walls":[[0,0,38,0.45],[0,31.55,38,32],[0,0,0.45,32],[37.55,0,38,32]],
		"props":[
		{"id":"scenery_dock","rect":[2,8,8,23],"height":0.9,"color":[0.32,0.22,0.12]},
		{"id":"tank_west","rect":[12,8,16,23],"height":0.85,"color":[0.14,0.33,0.37]},
		{"id":"tank_east","rect":[20,8,24,23],"height":0.85,"color":[0.14,0.33,0.37]},
		{"id":"soundstage","rect":[28,9,35,22],"height":1.2,"color":[0.29,0.14,0.16]},
		{"id":"breaker","rect":[27,1.8,29,2.8],"height":1.4,"color":[0.65,0.29,0.12]},
		{"id":"recorder","rect":[32,3.7,34,4.8],"height":1.05,"color":[0.18,0.24,0.26]},
		{"id":"projector","rect":[32,28.4,34,29.4],"height":1.25,"color":[0.26,0.29,0.31]},
		{"id":"screen","rect":[28,30.6,37,30.8],"height":2.5,"color":[0.63,0.6,0.5]}],
		"evidence":[], "npcs":[{"id":"floor_crew","route":[[9.8,24.6],[26,24.6]],"speed":1.3,"mode":"pingpong"},
		{"id":"boom_op","route":[[25.7,8],[25.7,23]],"speed":1.65,"mode":"pingpong"}]}
	for i in PORTAL_X.size():
		var x: float = PORTAL_X[i]
		# Fixed glazed sidelight beside the opening: sight passes, bodies do not.
		plan.props.append({"id":"sidelight_%d" % i, "rect":[x-0.06,PORTAL_Z+1.28,x+0.06,PORTAL_Z+2.85], "height":2.10, "color":[0.55,0.78,0.80]})
		for side in [-1,1]:
			var z: float = PORTAL_Z + side * (OPENING * 0.5 + 0.14)
			plan.props.append({"id":"portal_%d_%d" % [i,side], "rect":[x-0.16,z-0.14,x+0.16,z+0.14], "height":2.35, "color":[0.65,0.32,0.15] if i == 0 else [0.23,0.47,0.49]})
	return plan
