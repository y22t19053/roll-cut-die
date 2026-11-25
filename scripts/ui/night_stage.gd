extends Control
## Isolated studio render with a stationary reading scrim over the view.

const NightStage3D = preload("res://scripts/ui/night_stage_3d.gd")
const STILL_TIME := 7.4
const CHARCOAL := Color("111315")

var still := false: set = set_still
var _viewport: SubViewport
var _stage: NightStage3D
var _frame: Control
var _headless := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_headless = DisplayServer.get_name() == "headless"

	var screen := SubViewportContainer.new()
	screen.name = "SoundstageView"
	screen.stretch = true
	screen.stretch_shrink = 2 if OS.has_feature("web") else 1
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.visible = not _headless
	add_child(screen)

	_viewport = SubViewport.new()
	_viewport.name = "SoundstageWorld"
	_viewport.own_world_3d = true
	_viewport.gui_disable_input = true
	_viewport.positional_shadow_atlas_size = 512 if OS.has_feature("web") else 1024
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	screen.add_child(_viewport)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_stage = NightStage3D.new()
	_stage.name = "NightStage3D"
	_viewport.add_child(_stage)

	_frame = Control.new()
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.draw.connect(_draw_frame)
	_frame.resized.connect(_frame.queue_redraw)
	resized.connect(queue_redraw)
	get_window().size_changed.connect(_frame.queue_redraw)
	screen.resized.connect(_refresh_view)
	# The container can reset its child viewport's update mode on visibility changes.
	screen.visibility_changed.connect(_refresh_view, CONNECT_DEFERRED)
	set_still(still)


func set_still(on: bool) -> void:
	still = on
	if is_instance_valid(_stage):
		_stage.set_frozen(on, STILL_TIME)
		_refresh_view()


func _refresh_view() -> void:
	if not is_instance_valid(_viewport):
		return
	if _headless or not is_visible_in_tree():
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_stage.set_aspect(size.x / maxf(size.y, 1.0))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if still else SubViewport.UPDATE_ALWAYS


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), CHARCOAL)


func _draw_frame() -> void:
	var w := _frame.size.x
	var h := _frame.size.y
	if w < 2.0 or h < 2.0:
		return
	var shade := Color(CHARCOAL, 0.96)
	var clear := Color(CHARCOAL, 0.0)
	var reading_edge := clampf((size.x - size.y * 0.75) * 0.5, w * 0.24, w * 0.39)
	_frame.draw_rect(Rect2(0.0, 0.0, reading_edge, h), shade)
	_band(Rect2(reading_edge, 0.0, w * 0.24, h), shade, clear, true)
	_band(Rect2(0.0, 0.0, w, h * 0.18), Color(CHARCOAL, 0.70), clear, false)
	_band(Rect2(0.0, h * 0.78, w, h * 0.22), clear, Color(CHARCOAL, 0.74), false)
	if w < h * 1.18 or get_window().size.x <= 700:
		_frame.draw_rect(Rect2(Vector2.ZERO, _frame.size), Color(CHARCOAL, 0.54))


func _band(rect: Rect2, start: Color, end: Color, horizontal: bool) -> void:
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y)])
	var colors := PackedColorArray([start, end, end, start] if horizontal else [start, start, end, end])
	_frame.draw_polygon(points, colors)
