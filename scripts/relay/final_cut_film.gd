extends Control
## A film frame and its one-shot replay. Only this card draws its perforations.
const Reel = preload("res://scripts/relay/final_cut_reel.gd")
const FRAME := Vector2(330.0, 330.0 / 2.35)
const PRINT := Color("e8ded0")
const FILM := Color("262623")

var _row: Dictionary
var _caption: Dictionary
var _number_only: bool
var _track: Variant
var _screen: SubViewport
var _ghost: Node3D
var _camera: Camera3D
var _last := Vector3.ZERO
var _replay_at := -1.0


func setup(row: Dictionary, data: Dictionary, stacked: bool, player_model: Node3D, ink: ShaderMaterial) -> void:
	_row = row
	_caption = Reel.card_text(row, data)
	_number_only = stacked
	material = ink
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track: Variant = row.get("track")
	if track != null and track.size() > 0 and not stacked:
		_build_replay(track, player_model)


func _build_replay(track: Variant, player_model: Node3D) -> void:
	_track = track
	_screen = SubViewport.new()
	_screen.size = Vector2i(320, 136)
	_screen.own_world_3d = true
	_screen.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_screen.gui_disable_input = true
	add_child(_screen)

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("111513")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("a9b9ac")
	env.environment.ambient_light_energy = 0.65
	_screen.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -35, 0)
	light.light_energy = 1.1
	_screen.add_child(light)

	_last = track.raw_at(track.size() - 1)["position"]
	var floor_center := Vector3(_last.x, _last.y - 0.13, _last.z)
	_set_piece(Vector3(22.0, 0.14, 22.0), floor_center, Color("262e28"))
	for i in range(-4, 5):
		_set_piece(Vector3(8.0, 0.01, 0.022), floor_center + Vector3(0, 0.075, i), Color("5c665b"))
		_set_piece(Vector3(0.022, 0.01, 8.0), floor_center + Vector3(i, 0.075, 0), Color("5c665b"))

	_ghost = player_model.make_still(_last, 0.0)
	_screen.add_child(_ghost)
	_camera = Camera3D.new()
	_camera.fov = 38.0
	_screen.add_child(_camera)
	_camera.current = true
	seek(1.0 if _row.get("kind") == "cut" else 0.0)


func _set_piece(dimensions: Vector3, location: Vector3, ink: Color) -> void:
	var instance := MeshInstance3D.new()
	var block := BoxMesh.new()
	block.size = dimensions
	instance.mesh = block
	var paint := StandardMaterial3D.new()
	paint.albedo_color = ink
	instance.material_override = paint
	instance.position = location
	_screen.add_child(instance)


func seek(seconds: float) -> void:
	if _screen == null:
		return
	var seconds_in_tail := 1.0 if _row.get("kind") == "cut" else clampf(seconds, 0.0, 1.0)
	if seconds_in_tail == _replay_at:
		return
	_replay_at = seconds_in_tail
	var at := maxf(0.0, _track.duration() - (1.0 - seconds_in_tail))
	var pose: Dictionary = _track.sample_at(at)
	var p: Vector3 = pose["position"]
	var yaw: float = pose["cam_yaw"]
	_ghost.position = p
	_ghost.rotation.y = pose["facing"]
	var center := p.lerp(_last, 0.20) + Vector3.UP * 0.79
	var offset := Vector3(0.0, 1.55, 4.35).rotated(Vector3.UP, yaw)
	_camera.position = center + offset
	_camera.look_at(center)
	_camera.rotate_object_local(Vector3.BACK, float(pose["cam_roll"]))
	_screen.render_target_update_mode = SubViewport.UPDATE_ONCE


func _draw() -> void:
	var body := Rect2(Vector2.ZERO, FRAME)
	var aperture := body.grow(-13)
	var face := Color("121513")
	if _row.get("kind") == "cut":
		body.size.x *= 0.5
		aperture.size.x = body.size.x - 26.0
		# The source remains a full negative. The strip holds its left half.
	draw_rect(body, FILM)
	draw_rect(aperture, face)
	if _screen != null:
		var source := Rect2(Vector2.ZERO, Vector2(_screen.size))
		if _row.get("kind") == "cut":
			source.size.x *= 0.57
		draw_texture_rect_region(_screen.get_texture(), aperture, source)
	for x in range(10, int(body.size.x) - 5, 16):
		draw_rect(Rect2(x, 4, 7, 5), PRINT.darkened(0.55))
		draw_rect(Rect2(x, body.size.y - 9, 7, 5), PRINT.darkened(0.55))
	draw_rect(body, PRINT.darkened(0.65), false, 1.0)
	var font := get_theme_default_font()
	var baseline := FRAME.y + 20.0
	if _number_only:
		draw_string(font, Vector2(11, 28), _caption["number"], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, PRINT)
		return
	draw_string(font, Vector2(0, baseline), _caption["number"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, PRINT)
	draw_string(font, Vector2(78, baseline), _caption["status"], HORIZONTAL_ALIGNMENT_LEFT, 181, 14, PRINT)
	draw_string(font, Vector2(258, baseline), _caption["clock"], HORIZONTAL_ALIGNMENT_RIGHT, 72, 14, PRINT)
