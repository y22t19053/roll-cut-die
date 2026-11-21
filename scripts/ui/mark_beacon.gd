extends Node3D
## MarkBeacon — the floor marker left where the player pressed M.
##
## Gaffer-tape language: a flat disc on the floor, a thin pole that reads over
## furniture, and a billboard number. Shapes only, no art assets. It has no
## collision and no rules; it just says "you can come back here".

const COLOR := Color(0.55, 0.95, 0.85)
const DISC_RADIUS := 0.38
const POLE_HEIGHT := 1.3
## Above a standing figure (1.75 m), so the tag is never swallowed by a still.
const LABEL_HEIGHT := 1.95

var no := 0
var _label: Label3D
var _caption := ""


func setup(n: int, pos: Vector3, caption := "") -> void:
	no = n
	_caption = caption
	position = Vector3(pos.x, 0.0, pos.z)
	if _label != null:
		_label.text = _text()


func _text() -> String:
	return _caption if not _caption.is_empty() else "MARK %d" % no


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var disc := MeshInstance3D.new()
	disc.name = "Disc"
	var dm := CylinderMesh.new()
	dm.top_radius = DISC_RADIUS
	dm.bottom_radius = DISC_RADIUS
	dm.height = 0.02
	dm.radial_segments = 24
	disc.mesh = dm
	disc.material_override = mat
	disc.position = Vector3(0.0, 0.015, 0.0)
	add_child(disc)

	var pole := MeshInstance3D.new()
	pole.name = "Pole"
	var pm := CylinderMesh.new()
	pm.top_radius = 0.025
	pm.bottom_radius = 0.025
	pm.height = POLE_HEIGHT
	pm.radial_segments = 8
	pole.mesh = pm
	pole.material_override = mat
	pole.position = Vector3(0.0, POLE_HEIGHT * 0.5, 0.0)
	add_child(pole)

	_label = Label3D.new()
	_label.name = "Tag"
	_label.text = _text()
	_label.font_size = 40
	_label.pixel_size = 0.005
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 8
	_label.outline_modulate = Color(0, 0, 0, 0.85)
	_label.modulate = COLOR
	_label.no_depth_test = true
	_label.position = Vector3(0.0, LABEL_HEIGHT, 0.0)
	add_child(_label)
