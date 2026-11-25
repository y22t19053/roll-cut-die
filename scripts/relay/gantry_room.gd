extends RefCounted

const Gantry = preload("res://scripts/relay/h_gantry.gd")
const KIND := "gantry"
const LENGTH := 26.0
const HALF_WIDTH := 11.0
const DECK_TOP := 2.5


static func build(room: Node3D) -> PackedVector3Array:
	var set := Node3D.new()
	set.name = "LightingGantry"
	set.position.x = LENGTH * 0.5
	room.add_child(set)
	var parts := Gantry.build(set)
	var stations := PackedVector3Array()
	for station: Vector3 in parts["stations"]:
		stations.append(set.to_global(station))
	return stations


static func plan() -> Dictionary:
	return {"kind": KIND, "entry": Vector3(0, 0.05, 0),
		"exit": Vector3(LENGTH, 0.05, 0), "mids": [
			Vector3(8, 0.05, -6.8), Vector3(8, DECK_TOP, 0),
			Vector3(13, DECK_TOP, 0), Vector3(18, DECK_TOP, 0),
			Vector3(18, 0.05, 6.8),
		]}
