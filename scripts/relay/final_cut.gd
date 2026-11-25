class_name FinalCutController
extends Control
## One presentation clock for live playback, manual sampling and replay viewports.
signal finished

const Reel = preload("res://scripts/relay/final_cut_reel.gd")
const Film = preload("res://scripts/relay/final_cut_film.gd")
const Silhouettes = preload("res://scripts/relay/final_cut_silhouettes.gd")
const PlayerModel = preload("res://scripts/player/player.gd")
const Board = preload("res://scripts/ui/slate_board.gd")
const SlateAudio = preload("res://scripts/ui/slate_audio.gd")
const Loc = preload("res://scripts/core/loc.gd")
const FilmShader = preload("res://shaders/final_cut.gdshader")

const STARTS := [0.00, 1.05, 2.30, 3.10, 4.30, 5.30, 7.00, 8.70, 10.10, 11.90]
const BEAT_NAMES := [&"b1_slate", &"b2_cards", &"b3_silhouette", &"b4_break", &"b5_slash",
	&"b6_reorder", &"b7_assemble", &"b8_grade", &"b9_verdict", &"b10_wrap"]
const DURATION := 12.60
const EPSILON := 0.000001
const STAGE := Vector2(1440, 810)
const SILHOUETTE_ORIGIN := Vector2(560, 74)
const SILHOUETTE_SCALE := 1.43
const PIXELS_PER_METRE := 245.0
const NEUTRAL := Color(0.92, 0.88, 0.82)
const PALETTES := {"TRUTH": NEUTRAL, "COVER-UP": Color("d4a76a"), "FRAME-UP": Color("b5eff5")}
const ENDING_KEYS := {"TRUTH": "truth", "COVER-UP": "cover_up", "FRAME-UP": "frame_up"}

## Set before play() to control the clock with advance(). Rendering still runs
## in this mode when a display is available, so a beat can also be photographed.
var manual_time := false
var timeline_beat := 1

var _elapsed := 0.0
var _acting := false
var _played := false
var _edit := {}
var _player: AnimationPlayer
var _layers: Array[Control] = []
var _cards: Array[Control] = []
var _stack: Array[Control] = []
var _shards: Array[TextureRect] = []
var _base: Array[Vector2] = []
var _card_ink: ShaderMaterial
var _piece_ink: ShaderMaterial
var _board: Control
var _clack: AudioStreamPlayer
var _label: Label
var _ending_text := ""
var _verdict_lines: Array[String] = []
var _label_beat := 0
var _label_rows := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	set_process_input(false)


func play(data: Dictionary) -> void:
	if _played or not Reel.ENDINGS.has(data.get("verdict", "")):
		return
	_played = true
	_acting = true
	_edit = Reel.edit(data)
	if is_inside_tree():
		_build_clock()
		if DisplayServer.get_name() != "headless":
			_build_view(data)
	set_process(not manual_time)
	set_process_input(true)
	advance(0.0)


func _build_clock() -> void:
	_player = AnimationPlayer.new()
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	add_child(_player)
	var animation := Animation.new()
	animation.length = DURATION
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(":timeline_beat"))
	animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
	for index in STARTS.size():
		animation.track_insert_key(track, STARTS[index], index + 1)
	animation.set_meta(&"beat_names", BEAT_NAMES)
	var library := AnimationLibrary.new()
	library.add_animation(&"final_cut", animation)
	_player.add_animation_library(&"", library)
	_player.play(&"final_cut")


func _process(delta: float) -> void:
	advance(delta)


func _input(_event: InputEvent) -> void:
	if _acting:
		get_viewport().set_input_as_handled()


func advance(seconds: float) -> void:
	if not _acting:
		return
	var previous := _elapsed
	_elapsed = minf(DURATION, _elapsed + maxf(seconds, 0.0))
	if _player != null:
		_player.seek(minf(_elapsed + EPSILON, DURATION), true)
	else:
		while timeline_beat < STARTS.size() and _elapsed + EPSILON >= STARTS[timeline_beat]:
			timeline_beat += 1
	if _board != null:
		_render()
		if previous < STARTS[9] and _elapsed >= STARTS[9]:
			_clack.play()
	if _elapsed + EPSILON >= DURATION:
		_elapsed = DURATION
		_acting = false
		for surface in _layers:
			(surface.get_parent() as CanvasLayer).hide()
		set_process(false)
		set_process_input(false)
		finished.emit()


func debug_state() -> Dictionary:
	var pieces: Array = _edit.get("pieces", [])
	return {
		"beat": timeline_beat, "elapsed": _elapsed, "ending": _edit.get("ending", ""),
		"fragment_count": pieces.size(), "playing": _acting,
		"piece_order": pieces.map(func(piece: Dictionary) -> int: return piece["id"]),
		"piece_takes": pieces.map(func(piece: Dictionary) -> int: return piece["row"].get("take", 0)),
		"flights": pieces.map(func(piece: Dictionary) -> Dictionary: return piece["flight"].duplicate()),
		"holes": _edit.get("holes", []).duplicate(),
		"include_takes": _edit.get("included", []).duplicate(),
		"cards": _edit.get("cards", []).size(), "stacked": _edit.get("stacked", []).size(),
		"evidence_rows": _edit.get("evidence_rows", []).duplicate(),
	}


func _build_view(data: Dictionary) -> void:
	for layer_number in [30, 31, 32]:
		var layer := CanvasLayer.new()
		layer.layer = layer_number
		add_child(layer)
		if layer_number == 30:
			var backdrop := ColorRect.new()
			backdrop.color = Color.BLACK
			backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
			layer.add_child(backdrop)
			backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var surface := Control.new()
		surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(surface)
		_layers.append(surface)
	get_viewport().size_changed.connect(_layout)
	_layout()

	_card_ink = ShaderMaterial.new()
	_card_ink.shader = FilmShader
	_piece_ink = ShaderMaterial.new()
	_piece_ink.shader = FilmShader
	_board = Board.new()
	_layers[0].add_child(_board)
	_board.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_board.size = STAGE
	_board.headline = Loc.ui("final_cut.title")
	_board.scene_no = 12
	_board.field_labels.assign([Loc.ui("final_cut.scene"), Loc.ui("final_cut.take"), Loc.ui("final_cut.roll")])
	_clack = AudioStreamPlayer.new()
	_clack.stream = SlateAudio.clack_stream()
	_clack.volume_db = -14.0
	add_child(_clack)

	var model: Node3D = PlayerModel.new()
	model._build_body()
	for row: Dictionary in _edit["stacked"]:
		_stack.append(_add_card(row, data, true, model))
	for row: Dictionary in _edit["cards"]:
		_cards.append(_add_card(row, data, false, model))
	model.free()

	for piece: Dictionary in Silhouettes.make():
		var shard := TextureRect.new()
		shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shard.texture = piece["texture"]
		shard.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		shard.material = _piece_ink
		_layers[1].add_child(shard)
		_shards.append(shard)
		_base.append(SILHOUETTE_ORIGIN + (piece["offset"] as Vector2) * SILHOUETTE_SCALE)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override(&"font_color", NEUTRAL)
	_label.add_theme_constant_override(&"line_spacing", 6)
	_layers[2].add_child(_label)
	_ending_text = Loc.ui("final_cut." + ENDING_KEYS[_edit["ending"]])
	for key: String in ["line_one", "line_two", "record"]:
		_verdict_lines.append(Loc.ui("final_cut." + key))


func _add_card(row: Dictionary, data: Dictionary, stacked: bool, model: Node3D) -> Control:
	var card := Film.new()
	_layers[0].add_child(card)
	card.setup(row, data, stacked, model, _card_ink)
	return card


func _layout() -> void:
	var extent := get_viewport().get_visible_rect().size
	var fit := minf(extent.x / STAGE.x, extent.y / STAGE.y)
	for surface in _layers:
		surface.position = ((extent - STAGE * fit) * 0.5).round()
		surface.size = STAGE
		surface.scale = Vector2.ONE * fit


func _render() -> void:
	var t := _elapsed
	var beat := timeline_beat
	_board.visible = beat == 1
	if beat == 1:
		_board.alpha = _ramp(t, 0.0, 0.25) * (1.0 - _ramp(t, 0.82, 0.23))
		_board.position.y = lerpf(124.0, -64.0, _ramp(t, 0.0, 0.41))
		_board.stick = lerpf(-Board.OPEN_MAX, 0.0, _ramp(t, 0.37, 0.20))
		_board.queue_redraw()

	var phase := floorf(t * 12.0)
	_card_ink.set_shader_parameter("grain_phase", phase)
	_card_ink.set_shader_parameter("dissolve", _ramp(t, 4.34, 0.88) * 0.52)
	_piece_ink.set_shader_parameter("grain_phase", phase)
	_render_cards(t, beat)
	_render_pieces(t, beat)
	_render_label(t, beat)


func _card_pos(index: int) -> Vector2:
	if _cards.size() == 1 and (_edit["cards"] as Array)[0].is_empty():
		return Vector2(555, 337)
	var right := index % 2 == 1
	return Vector2(100.0 if not right else 1010.0, 105.0 + floorf(index / 2.0) * 218.0)


func _render_cards(t: float, beat: int) -> void:
	for i in _cards.size():
		var card := _cards[i]
		var start: float = STARTS[1] + 0.18 * i
		card.visible = t >= start and beat < 6
		if card.visible:
			var entrance := _ramp(t, start, 0.34)
			card.position = _card_pos(i) + Vector2.DOWN * (1.0 - entrance) * (0.40 * PIXELS_PER_METRE)
			card.modulate.a = entrance
			card.seek(t - start)
	for i in _stack.size():
		var card := _stack[i]
		var entrance := _ramp(t, STARTS[1] + i * 0.18, 0.38)
		card.visible = beat >= 2 and beat < 6
		card.position = Vector2(26.0 + i * 14.0, 590.0 + i * 24.0 + (1.0 - entrance) * 90.0)
		card.scale = Vector2.ONE * 0.60
		card.modulate.a = entrance * 0.70


func _render_pieces(t: float, beat: int) -> void:
	var ending: String = _edit["ending"]
	var grade := _ramp(t, STARTS[7], 1.4)
	var palette := NEUTRAL.lerp(PALETTES[ending], grade)
	if ending == "COVER-UP":
		palette = palette.darkened(grade * 0.12)
	_piece_ink.set_shader_parameter("edge_light", grade * 0.84 if ending == "FRAME-UP" else 0.0)
	_piece_ink.set_shader_parameter("grain_contrast", 1.0 - grade * 0.42 if ending == "COVER-UP" else 1.0)
	var print_fade := lerpf(1.0, 0.12, _ramp(t, STARTS[9], 0.70))
	var pieces: Array = _edit["pieces"]
	var holes: Array = _edit["holes"]
	for order in pieces.size():
		var piece: Dictionary = pieces[order]
		var id: int = piece["id"]
		var shard := _shards[id]
		shard.visible = beat >= 3
		if not shard.visible:
			continue
		var base := _base[id]
		var flight: Dictionary = piece["flight"]
		var thrown: Vector2 = (flight["offset"] as Vector2) * PIXELS_PER_METRE
		var row: Dictionary = piece["row"]
		var hole := holes.has(id)
		var ink := palette
		var alpha := print_fade
		var at := base
		var magnitude := SILHOUETTE_SCALE
		var queue_position := Vector2(114.0 + order * 109.0, 364.0) - shard.texture.get_size() * 0.38
		if beat == 3:
			var rise := _ramp(t, STARTS[2] + id * 0.014, 0.60)
			var origin := _card_pos(id % _cards.size()) + Film.FRAME * 0.5
			at = origin.lerp(base, rise)
			magnitude *= lerpf(0.34, 1.0, rise)
			alpha = lerpf(0.35, 1.0, rise)
		elif beat == 4:
			at += thrown * _ramp(t, STARTS[3] + id * 0.10, 0.33)
		elif beat == 5:
			var clear_frame := _ramp(t, STARTS[4], 1.0)
			var reached := _ramp(STARTS[4], STARTS[3] + id * 0.10, 0.33)
			at += thrown * lerpf(reached, 1.38, clear_frame)
			if hole or not flight["alive"]:
				ink = palette.lerp(Color.BLACK, clear_frame * 0.90)
		elif beat == 6:
			var arrange := _ramp(t, STARTS[5] + order * 0.035, 1.06)
			at = (base + thrown * 1.38).lerp(queue_position, arrange)
			magnitude = lerpf(SILHOUETTE_SCALE, 0.76, arrange)
			if ending == "COVER-UP" and row.get("hidden", false):
				ink = palette.darkened(0.82)
			elif not flight["alive"]:
				ink = palette.darkened(0.90)
		elif beat == 7:
			var return_at: float = STARTS[6] + order * 0.06
			var settle := _ramp(t, return_at, 0.87)
			var arc := sin(settle * PI) * (45.0 + id * 3.0)
			at = queue_position.lerp(base, settle) - Vector2.DOWN * arc
			magnitude = lerpf(0.76, SILHOUETTE_SCALE, settle)
			if hole:
				var fatal_chest := ending == "FRAME-UP" and id == 1
				ink = palette.darkened(0.18 if fatal_chest else 0.82)
				alpha *= 1.0 - _ramp(settle, 0.82 if fatal_chest else 0.0, 0.18)
			elif not flight["alive"]:
				ink = palette.darkened(0.90)
		else:
			if hole:
				alpha = 0.0
			elif not flight["alive"]:
				ink = palette.darkened(0.90)
		shard.position = at
		shard.scale = Vector2.ONE * magnitude
		shard.modulate = Color(ink, alpha)


func _render_label(t: float, beat: int) -> void:
	_label.visible = beat >= 8
	if not _label.visible:
		return
	var label_beat := mini(beat, 9)
	if label_beat != _label_beat:
		_label_beat = label_beat
		_label_rows = -1
		if beat == 8:
			_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_label.add_theme_font_size_override(&"font_size", 24)
			_label.position = Vector2(920, 555)
			_label.size = Vector2(421, 0)
		else:
			_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_label.add_theme_font_size_override(&"font_size", 28)
			_label.position = Vector2(0, 682)
			_label.size = Vector2(STAGE.x, 0)
	if beat == 8:
		var evidence: Array = _edit["evidence_rows"]
		var rows := mini(evidence.size(), floori((t - STARTS[7]) / 0.26))
		if rows != _label_rows:
			_label_rows = rows
			_label.text = "\n".join([_ending_text] + evidence.slice(0, rows))
		_label.modulate.a = _ramp(t, STARTS[7], 0.30)
	else:
		var rows := 1 + int(t >= STARTS[8] + 0.90) + int(t >= 11.55)
		if rows != _label_rows:
			_label_rows = rows
			_label.text = "\n".join(_verdict_lines.slice(0, rows))
		_label.modulate.a = _ramp(t, STARTS[8], 0.19) * (1.0 - _ramp(t, STARTS[9], 0.70))


static func _ramp(t: float, start: float, duration: float) -> float:
	return smoothstep(0.0, 1.0, clampf((t - start) / duration, 0.0, 1.0))
