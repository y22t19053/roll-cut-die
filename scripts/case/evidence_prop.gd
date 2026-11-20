extends Node3D
## EvidenceProp — a thing in the room that can be looked at and picked up.
##
## The prop is furniture; the marker floats above the nearest reachable edge so
## the player can see what is interactable without walking into the desk. The
## marker is a shape, not a sprite, so it reads from any camera angle.

const Loc = preload("res://scripts/core/loc.gd")

const REACH := 1.15

var id := ""
var meta: Dictionary = {}
var seen := false
var taken := false

var _marker: Node3D
var _label: Label3D
var _ring: MeshInstance3D
var _bob := 0.0


func setup(eid: String, pos: Vector3, m: Dictionary) -> void:
	id = eid
	meta = m
	position = pos


func _ready() -> void:
	_build()


func _build() -> void:
	_marker = Node3D.new()
	_marker.name = "Marker"
	_marker.position = Vector3(0.0, 1.05, 0.0)
	add_child(_marker)

	# A slanted card: the universal "this is a document" silhouette.
	var card := MeshInstance3D.new()
	card.name = "Card"
	var bm := BoxMesh.new()
	bm.size = Vector3(0.42, 0.02, 0.30)
	card.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.93, 0.86)
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.42, 0.34)
	mat.emission_energy_multiplier = 0.6
	card.material_override = mat
	card.rotation_degrees = Vector3(-28.0, 24.0, 0.0)
	_marker.add_child(card)

	var ring := MeshInstance3D.new()
	ring.name = "Ring"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.30
	tm.outer_radius = 0.34
	tm.rings = 12
	tm.ring_segments = 24
	ring.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.98, 0.86, 0.35, 0.55)
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = rmat
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	ring.position = Vector3(0.0, -0.42, 0.0)
	_marker.add_child(ring)
	_ring = ring

	_label = Label3D.new()
	_label.name = "Name"
	_label.text = Loc.t(meta.get("name", {}))
	_label.font_size = 36
	_label.pixel_size = 0.005
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 8
	_label.outline_modulate = Color(0, 0, 0, 0.85)
	_label.modulate = Color(1.0, 0.95, 0.8, 0.9)
	_label.position = Vector3(0.0, 0.55, 0.0)
	_marker.add_child(_label)
	for part in _marker.get_children():
		part.layers = 1 << 19 # live visuals are excluded from the historical camera


func refresh_language() -> void:
	_label.text = Loc.t(meta.get("name", {}))


func still_frame() -> Dictionary:
	return {"visible": is_visible_in_tree(), "pose": _marker.global_transform,
		"ring_pose": _ring.transform, "ring_visible": _ring.visible, "label": _label.text}


func make_still(frame: Dictionary) -> Node3D:
	var still := _marker.duplicate(0) as Node3D
	for part in still.get_children():
		part.layers = 1
	still.get_node("Ring").transform = frame.ring_pose
	still.get_node("Ring").visible = frame.ring_visible
	still.get_node("Name").text = frame.label
	return still


func _process(dt: float) -> void:
	if _marker == null or taken:
		return
	_bob += dt * 1.6
	_marker.position.y = 1.05 + sin(_bob) * 0.06
	if _ring != null:
		_ring.rotation_degrees.y = fmod(_ring.rotation_degrees.y + dt * 40.0, 360.0)


func mark_seen() -> void:
	seen = true
	if _ring != null:
		_ring.visible = false


func mark_taken() -> void:
	taken = true
	visible = false


## Distance from a world point to this prop's reachable centre.
func distance_to(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func in_reach(p: Vector3) -> bool:
	return not taken and distance_to(p) <= REACH
