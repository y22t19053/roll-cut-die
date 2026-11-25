extends CanvasLayer
## One warning per leg. Explicit time makes every transition headless-driveable.
const Loc = preload("res://scripts/core/loc.gd")
const Track = preload("res://scripts/ghost/ghost_track.gd")
const WARN_SECONDS := 2.5
const NG_LIMIT := 3
const OUT_POSITION := Vector3(1.6, 0.05, -5.2)
const DOOR := Vector3(1.6, 0.05, -2.94)
var _state := "IN"
var _ng := 0
var _left := 0.0
var _triggered := false
var _run: Node
var _camera: Camera3D
var _room: Node3D
var _overlay: FrameOverlay
var _label: Label
var _warn_sounded := false
var _loop := 0.0
var _steps: Array[float] = []
var _duration := 1.2
var _step := 0
var spend_cut := Callable()
signal changed(value: String)

class FrameOverlay extends Control:
	var warning := false
	var clock := 0.0
	func _draw() -> void:
		if not warning: return
		var ink := Color(1.0, 0.16, 0.12, 0.65 + 0.3 * sin(clock * 9.0))
		for corner: Vector2 in [Vector2(24,24),Vector2(size.x-24,24),Vector2(24,size.y-24),size-Vector2(24,24)]:
			var dx := 1.0 if corner.x < size.x/2 else -1.0
			var dy := 1.0 if corner.y < size.y/2 else -1.0
			draw_line(corner, corner+Vector2(dx*125,0), ink, 7.0)
			draw_line(corner, corner+Vector2(0,dy*100), ink, 7.0)

func bind(run: Node) -> void:
	_run = run
	spend_cut = _pay_cut

func _ready() -> void:
	layer = 13
	_overlay = FrameOverlay.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label = Label.new()
	_overlay.add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_label.position.y = 105
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 25)
	_label.add_theme_color_override("font_color", Color("ffdbbb"))
	_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_label.add_theme_constant_override("shadow_offset_x", 2)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.fov = 58.0
	_render()

func playable() -> bool:
	return _run == null or (_run.phase == _run.Mode.PLAY and not _run._dying and not _run._riding and not _run.slate.is_running() and _run._final_cut == null and not _run.get_tree().paused and not _run._in_prologue())

func state() -> String:
	return _state

func debug_state() -> Dictionary:
	return {"state": _state, "ng": _ng, "remaining": _left, "triggered": _triggered, "steps": _steps.duplicate(), "duration": _duration}

func note_ng() -> void:
	if not playable(): return
	_ng += 1
	if _ng == NG_LIMIT and not _triggered:
		_triggered = true
		_left = WARN_SECONDS
		_set_state("WARN")

func advance(seconds: float) -> void:
	if not is_finite(seconds) or seconds < 0.0: return
	if not playable():
		_render()
		return
	if _state == "WARN":
		if not _warn_sounded and _run != null:
			_run.score.frame_warning()
			_warn_sounded = true
		_left = maxf(0.0, _left - seconds)
		if _left <= 0.000001: _enter_out()
	elif _state == "OUT" and _run != null:
		var p: Vector3 = _room.to_local(_run.player.global_position)
		if p.x >= 0.32 and p.x <= 8.68 and absf(p.z) <= 2.55:
			resolve()
		else:
			_loop += seconds
			while _loop >= _duration:
				_loop -= _duration
				_step = 0
			while _step < _steps.size() and _steps[_step] <= _loop:
				_run.score.frame_step(_room.to_global(DOOR))
				_step += 1
	_render()

func reset_leg() -> void:
	resolve()
	_ng = 0
	_triggered = false
	_warn_sounded = false

func resolve() -> void:
	if _state == "OUT" and _run != null:
		_run.rig.camera.make_current()
		_run.rig.set_physics_process(true)
		_run.score.set_out_of_frame(false)
		_run.grace = maxf(_run.grace, 0.75)
	_left = 0.0
	_set_state("IN")

func cut_back() -> bool:
	if _state == "IN" or not playable(): return false
	if not spend_cut.is_valid() or not spend_cut.call():
		_render()
		return false
	resolve()
	if _run != null:
		_run._board_cut()
		_run._restore(_run.last_anchor)
		_run._hold_until_board()
	return true

func _pay_cut() -> bool:
	if _run.cut_stock <= 0 or _run.last_anchor < 0:
		_run._foley.play("deny")
		return false
	_run.cut_stock -= 1
	_run.cuts_used += 1
	_run._foley.play("splice")
	_run._final_outtakes.append(_run.FinalReel.relay_outtake(_run.live, _run.elapsed, "cut"))
	return true

func set_history(history: Array) -> void:
	_steps.clear()
	_duration = 1.2
	for track in history:
		if track.size() < 2: continue
		var distance := 0.0
		var previous := Vector2(Track.dequant_pos(track.px[0]), Track.dequant_pos(track.pz[0]))
		for i in range(1, track.size()):
			var point := Vector2(Track.dequant_pos(track.px[i]), Track.dequant_pos(track.pz[i]))
			distance += previous.distance_to(point)
			previous = point
			if distance >= 0.65:
				_steps.append(Track.dequant_time(track.times[i]))
				distance = fmod(distance, 0.65)
		if not _steps.is_empty():
			_duration = maxf(track.duration()+0.35, 0.5)
			break
	# No walking history yet: the crew taps a steady guide at the same doorway.
	if _steps.is_empty(): _steps.assign([0.0, 0.6])
	_loop = 0.0
	_step = 0

func _enter_out() -> void:
	_set_state("OUT")
	if _run == null: return
	_room = _run.get_node("Rooms").get_child(_run.leg_room)
	_run.player.set_push(Vector3.ZERO)
	_run.player.teleport(_room.to_global(OUT_POSITION), _run.player.facing)
	_run.rig.set_physics_process(false)
	_camera.global_position = _room.to_global(Vector3(4.5, 10.5, -13.5))
	_camera.look_at(_room.to_global(Vector3(4.1, 0.0, -1.3)))
	_camera.make_current()
	_run.score.set_out_of_frame(true)
	var history: Array = []
	var span: Vector2i = _run._track_ranges[_run.leg_room]
	for i in range(span.x, span.y): history.append(_run.tracks[i])
	set_history(history)

func _set_state(value: String) -> void:
	if _state == value: return
	_state = value
	changed.emit(value)
	_render()

func _both(key: String) -> String:
	var words: Dictionary = Loc.STRINGS[key]
	return str(words.en) + " / " + str(words.zh)

func _render() -> void:
	if _overlay == null: return
	_overlay.visible = _state != "IN" and playable()
	_overlay.warning = _state == "WARN"
	_overlay.clock = WARN_SECONDS - _left
	_overlay.queue_redraw()
	if _state == "WARN":
		_label.text = _both("frame.warn") + "  %.1fs" % _left + "\n" + _both("frame.resolve")
	else:
		_label.text = "OUT OF FRAME / " + _both("frame.out") + "\n" + _both("frame.empty" if _run != null and _run.cut_stock <= 0 else "frame.cut")
