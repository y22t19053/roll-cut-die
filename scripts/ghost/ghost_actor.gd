extends Node3D
## GhostActor — a previous take, walking itself back into the room.
##
## A ghost replays a fixed track against its own clock. It never looks at the
## current player, never changes the world, and never touches other ghosts. Its
## only interaction is the one the design asks for: if the current player walks
## into it, the current player dies, and the death names the take.
##
## Bounds: a ghost plays once. When its track runs out collision goes off and it
## fades to nothing within FADE_OUT_S, then hides, so a slow player is not
## permanently walled in by a finished recording.

const GhostTrack = preload("res://scripts/ghost/ghost_track.gd")

signal caught_player(take_id: int)

const DANGER_RADIUS := 0.34
const BODY_RADIUS := 0.32
const BODY_HEIGHT := 1.7
const LIVE_LAYER := 1 << 19 # Preview camera omits live ghosts, draws visual-only stills on layer 1.
const FADE_OUT_S := 1.2
## The projection needs a moment to come up, and every take starts on the same
## mark as the ghosts do: without this window take 2 would begin inside take 1
## and die on the first frame. So the ghost is visible but harmless while it
## materialises, and the danger only comes on after it has walked clear.
const WARMUP := 2.0
var warmup_seconds := WARMUP # Compact relay uses its shorter entry guard.
## Alpha the body ramps up to while materialising (harmless).
const WARMUP_ALPHA := 0.30
## Alpha once armed: readable as a person, not as smoke.
const ARMED_ALPHA := 0.62
## The tag never fades with the body while the ghost is alive.
const LABEL_ALPHA := 0.95
## Floor ring line width; its outer edge sits exactly on DANGER_RADIUS.
const RING_WIDTH := 0.035

var track
var take_id := 0
var playing := false
var spent := false
var playhead := 0.0
## Relay never retires a successful strip until the room is cut.
var loop_strip := false
var strip_age := 0.0

var _danger: Area3D
var _visual: Node3D
var _label: Label3D
var _mat: StandardMaterial3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _alpha := 0.0
var _armed := false
var _notches: Array = []


func setup(t: Variant, id: int) -> void:
	track = t
	take_id = id
	playhead = 0.0
	strip_age = 0.0
	playing = true
	spent = false
	_armed = false
	_alpha = 0.0
	if _danger != null:
		_danger.monitoring = false
	if _label != null:
		_label.text = "TAKE %02d" % take_id
	if _ring_mat != null:
		_build_notches()


func _ready() -> void:
	_build()


func _hue() -> Color:
	# Stable per take, so the third take's two ghosts are told apart instantly.
	var h := fmod(0.55 + 0.13 * float(take_id), 1.0)
	return Color.from_hsv(h, 0.45, 1.0)


## Colour alone cannot carry this: one notch on the floor ring per take number,
## at fixed angles, so "which past take is this" is countable in greyscale too.
func _build_notches() -> void:
	for n in _notches:
		if is_instance_valid(n):
			n.queue_free()
	_notches.clear()
	if _ring_mat == null:
		return
	var count: int = clampi(take_id, 1, 6)
	for i in count:
		var notch := MeshInstance3D.new()
		notch.name = "TakeNotch%d" % (i + 1)
		var bm := BoxMesh.new()
		bm.size = Vector3(0.10, 0.02, 0.045)
		notch.mesh = bm
		notch.material_override = _ring_mat
		var ang := TAU * float(i) / 6.0 - PI * 0.5
		notch.position = Vector3(cos(ang) * (DANGER_RADIUS + 0.045), 0.018, sin(ang) * (DANGER_RADIUS + 0.045))
		notch.rotation.y = -ang
		notch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(notch)
		_notches.append(notch)


func _build() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	_mat = StandardMaterial3D.new()
	var c := _hue()
	_mat.albedo_color = Color(c.r, c.g, c.b, _alpha)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.no_depth_test = false
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mesh := MeshInstance3D.new()
	mesh.name = "Body"
	var cm := CapsuleMesh.new()
	cm.radius = BODY_RADIUS
	cm.height = BODY_HEIGHT
	cm.radial_segments = 12
	cm.rings = 4
	mesh.mesh = cm
	mesh.position = Vector3(0.0, BODY_HEIGHT * 0.5, 0.0)
	mesh.material_override = _mat
	_visual.add_child(mesh)

	_label = Label3D.new()
	_label.name = "Tag"
	_label.text = "TAKE %02d" % take_id
	_label.font_size = 40
	_label.pixel_size = 0.0055
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.modulate = Color(c.r, c.g, c.b, LABEL_ALPHA)
	_label.outline_size = 8
	_label.outline_modulate = Color(0, 0, 0, 0.7)
	_label.position = Vector3(0.0, BODY_HEIGHT + 0.3, 0.0)
	add_child(_label)

	# The kill radius drawn on the floor, so "how close is too close" is visible.
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_color = Color(c.r, c.g, c.b, _alpha)
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ring = MeshInstance3D.new()
	_ring.name = "DangerRing"
	var tm := TorusMesh.new()
	tm.outer_radius = DANGER_RADIUS
	tm.inner_radius = DANGER_RADIUS - RING_WIDTH
	tm.rings = 48
	tm.ring_segments = 4
	_ring.mesh = tm
	_ring.scale = Vector3(1.0, 0.15, 1.0)
	_ring.position = Vector3(0.0, 0.02, 0.0)
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_build_notches()

	mesh.layers = LIVE_LAYER
	_ring.layers = LIVE_LAYER
	_label.layers = LIVE_LAYER
	_danger = Area3D.new()
	_danger.name = "Danger"
	_danger.collision_layer = 8
	_danger.collision_mask = 2
	_danger.monitoring = false
	_danger.monitorable = false
	var dc := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = DANGER_RADIUS
	cyl.height = BODY_HEIGHT
	dc.shape = cyl
	dc.position = Vector3(0.0, BODY_HEIGHT * 0.5, 0.0)
	_danger.add_child(dc)
	add_child(_danger)
	_danger.body_entered.connect(_on_body_entered)


## Capture only render state. Never rewind the live Area or playback clock to browse a MARK.
func still_frame() -> Dictionary:
	return {"pose": global_transform, "facing": _visual.rotation.y, "shown": visible,
		"body": _mat.albedo_color, "ring": _ring_mat.albedo_color,
		"tag": _label.text, "ink": _label.modulate}

func make_still(frame: Dictionary) -> Node3D:
	var still := Node3D.new()
	still.name = "Still_%02d" % take_id
	var visual := _visual.duplicate(0) as Node3D
	visual.rotation.y = frame.facing
	still.add_child(visual)
	var body := visual.get_node("Body") as MeshInstance3D
	var mat := _mat.duplicate() as StandardMaterial3D
	mat.albedo_color = frame.body
	body.material_override = mat
	var ring := _ring.duplicate(0) as MeshInstance3D
	var ring_mat := _ring_mat.duplicate() as StandardMaterial3D
	ring_mat.albedo_color = frame.ring
	ring.material_override = ring_mat
	still.add_child(ring)
	var tag := _label.duplicate(0) as Label3D
	tag.text = frame.tag
	tag.modulate = frame.ink
	still.add_child(tag)
	body.layers = 1
	ring.layers = 1
	tag.layers = 1
	still.visible = frame.shown
	return still

func _on_body_entered(body: Node3D) -> void:
	if spent or not playing or not _armed:
		return
	if body is CharacterBody3D and body.get("frozen") != null:
		caught_player.emit(take_id)


func _physics_process(dt: float) -> void:
	if track == null or not playing:
		return
	strip_age += dt
	playhead += dt
	if loop_strip and track.duration() > 0.0:
		playhead = fposmod(playhead, track.duration())
	var s: Dictionary = track.sample_at(playhead)
	global_position = s["position"]
	if _visual != null:
		_visual.rotation.y = s["facing"]
	if not _armed:
		if (strip_age if loop_strip else playhead) >= warmup_seconds:
			_armed = true
			if _danger != null:
				_danger.set_deferred("monitoring", true)
			if _label != null:
				_label.text = "TAKE %02d" % take_id
			_set_alpha(ARMED_ALPHA)
		else:
			_set_alpha(WARMUP_ALPHA * clampf(playhead / maxf(warmup_seconds,0.001), 0.0, 1.0))
	if not loop_strip and track.duration() > 0.0 and playhead > track.duration():
		_finish()


func _finish() -> void:
	playing = false
	spent = true
	if _danger != null:
		_danger.set_deferred("monitoring", false)
	if _label != null:
		_label.text = "TAKE %02d · OUT" % take_id
	# Fade body, ring and tag together to nothing, then leave the scene graph's
	# draw list entirely: a finished take is not an obstacle and not a decoy.
	var a0 := _alpha
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		_set_alpha(a0 * k)
		if _label != null:
			_label.modulate.a = LABEL_ALPHA * k
	, 1.0, 0.0, FADE_OUT_S)
	tw.tween_callback(func() -> void: visible = false)


func _set_alpha(a: float) -> void:
	_alpha = a
	if _mat != null:
		var c := _mat.albedo_color
		_mat.albedo_color = Color(c.r, c.g, c.b, a)
	if _ring_mat != null:
		var rc := _ring_mat.albedo_color
		_ring_mat.albedo_color = Color(rc.r, rc.g, rc.b, minf(1.0, a * 1.4))
