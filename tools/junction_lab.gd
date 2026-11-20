extends "res://scripts/main.gd"
## Standalone F6 scene. Record A by walking it, then file R -> 3 at the desk.
## SPACE starts the next Take. Follow B; MARK before the crossing, observe,
## then CUT back to the MARK to try another decision on the same world clock.
## Routes describe floor paint only; they never steer a body or register a track.

## Operator walkthrough gives away the observation point. Hide that prompt in first-exposure sessions.
@export var coach_observation := true
var report_sign: Label3D

const CROSSING := Vector2(6, 8)
const OBSERVE := Vector2(6, 9.5)
const A := [Vector2(6,13), Vector2(6,12), Vector2(3,12), Vector2(3,8), Vector2(9,8), Vector2(9,4), Vector2(6,4), Vector2(6,2)]
const B := [Vector2(6,13), Vector2(6,12), Vector2(6,8), Vector2(6,4), Vector2(6,2)]


func route_points(route_id: String) -> PackedVector2Array:
	match route_id:
		"A": return PackedVector2Array(A)
		"B": return PackedVector2Array(B)
	return PackedVector2Array()


func _map_source() -> Variant:
	# A low island on either side defines the two turns without hiding an
	# approaching projection. The east bay keeps the case NPC off both routes.
	var map := {"schema_version": 1, "size": [17,16], "spawn": [6,13],
		"walls": [[0,0,17,0.4], [0,15.6,17,16], [0,0,0.4,16], [16.6,0,17,16], [12,0.4,12.4,15.6]],
		"props": [{"id":"south_flat", "rect":[3.9,9,5.1,11], "height":0.55},
			{"id":"north_flat", "rect":[7,5,8,7], "height":0.55}],
		"evidence": [{"id":"receipt", "pos":[1.5,3]}, {"id":"walkie", "pos":[10.5,13]},
			{"id":"clapboard", "pos":[2,14]}, {"id":"script_page", "pos":[10.5,2]}],
		"npcs": [{"id":"director", "route":[[14,5],[14,10]], "speed":1, "mode":"pingpong"}],
		"report_zone": {"pos":[6,2], "radius":1.1}}
	for id in ["A", "B"]:
		var points := route_points(id)
		for i in range(1, points.size()):
			var p := points[i-1]
			var q := points[i]
			# Side-by-side for the shared entrance and finish.
			var offset := Vector2(-0.09 if id == "A" else 0.09, 0)
			p += offset
			q += offset
			map.props.append({"id":"tape_%s_%d" % [id,i], "height":0.012 if id == "A" else 0.018,
				"rect":[minf(p.x,q.x)-0.045,minf(p.y,q.y)-0.045,maxf(p.x,q.x)+0.045,maxf(p.y,q.y)+0.045],
				"color":[0.88,0.54,0.16] if id == "A" else [0.20,0.74,0.78], "solid":false})
	return map


func _build_world() -> void:
	super._build_world()
	_sign("A   /   01", Vector2(3,12))
	_sign("B   /   02", Vector2(6,11.2))
	if coach_observation:
		_sign("M   /   WATCH", OBSERVE)
	_sign("+", CROSSING)
	report_sign = _sign("REPORT   /   R", Vector2(report_pos.x,report_pos.z))


func _sign(title: String, at: Vector2) -> Label3D:
	var sign := Label3D.new()
	sign.text = title
	sign.pixel_size = 0.007
	sign.font_size = 40
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(at.x,0.42,at.y)
	add_child(sign)
	return sign


## Observer-only state for acceptance; no track injection or movement shortcuts.
func junction_snapshot() -> Dictionary:
	return {"crossing_xz":CROSSING, "observe_xz":OBSERVE, "world_t":_world_t,
		"take":GameSession.takes.take_index, "phase":GameSession.takes.state_name(),
		"saved_tracks":GameSession.ghost_count(), "replay_actors":ghost_nodes.size(),
		"marks":marks.count(), "player_xz":Vector2(player.global_position.x,player.global_position.z)}


func _commit_state() -> void:
	pass # Experimental interactions and successful reports stay in memory.


func _load_latest_state() -> void:
	pass # F4 must not import the regular save.
