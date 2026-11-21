extends Control
## SettingsPanel — language, controls, audio and video, shared by the title
## screen and the pause menu. Every change goes through GameSession.set_setting
## / set_language, which applies it at once and stores it in the preference
## file; the panel itself holds no state but the open tab.

signal closed

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Loc = preload("res://scripts/core/loc.gd")

const TABS := ["general", "controls", "audio", "video"]

var tab := "general"
var _page: VBoxContainer
var _note: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	GameSession.language_changed.connect(_on_language_changed)


func _on_language_changed(_lang: String) -> void:
	if visible:
		_render.call_deferred()


func _pick_tab(id: String) -> void:
	tab = id
	# Deferred: the pressed button is one of the nodes the rebuild frees.
	_render.call_deferred()


func _pick_language(lang: String) -> void:
	if Loc.language != lang:
		GameSession.set_language(lang)


func open() -> void:
	visible = true
	_render()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func _render() -> void:
	UiKit.clear(self)
	add_child(UiKit.scrim())
	var p := UiKit.panel()
	UiKit.centered(self).add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	p.add_child(box)

	box.add_child(UiKit.label(Loc.ui("settings.title"), 30, UiKit.ACCENT))

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	box.add_child(tabs)
	var current_tab_button: Button = null
	for id: String in TABS:
		var b := UiKit.button(Loc.ui("settings.tab_" + id), _pick_tab.bind(id), 19)
		b.custom_minimum_size = Vector2(170, 40)
		b.toggle_mode = true
		b.button_pressed = id == tab
		tabs.add_child(b)
		if id == tab:
			current_tab_button = b

	_page = VBoxContainer.new()
	_page.custom_minimum_size = Vector2(760, 330)
	_page.add_theme_constant_override("separation", 12)
	box.add_child(_page)
	match tab:
		"general":
			_general()
		"controls":
			_controls()
		"audio":
			_audio()
		"video":
			_video()

	_note = UiKit.label(Loc.ui("settings.save_failed") if not GameSession.prefs_error.is_empty()
		else Loc.ui("settings.saved_note"), 16, UiKit.DIM)
	box.add_child(_note)
	var back := UiKit.button(Loc.ui("menu.back"), close)
	box.add_child(back)
	if current_tab_button != null:
		current_tab_button.grab_focus()


# --- pages -------------------------------------------------------------------

func _general() -> void:
	var row := _row(Loc.ui("settings.language"))
	for lang: String in Loc.SUPPORTED:
		var b := UiKit.button(Loc.language_name(lang), _pick_language.bind(lang), 20)
		b.custom_minimum_size = Vector2(150, 40)
		b.toggle_mode = true
		b.button_pressed = Loc.language == lang
		row.add_child(b)
	_check("settings.reduce_motion", "reduce_motion")
	_slider("settings.roll_scale", "roll_scale", 0.0, 1.5, 0.05, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))


func _controls() -> void:
	_slider("settings.mouse_sensitivity", "mouse_sensitivity", 0.0005, 0.006, 0.0001,
		func(v: float) -> String: return "%.1f" % (v * 1000.0))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 6)
	_page.add_child(grid)
	var rows := [
		[Loc.ui("controls.key_move"), "controls.move"],
		["E", "controls.interact"],
		["M", "controls.mark"],
		["C", "controls.cut"],
		["R", "controls.report"],
		[Loc.ui("controls.key_space"), "controls.retake"],
		[Loc.ui("controls.key_look"), "controls.look"],
		["F1 / F5 / F6 / F7", "controls.roll"],
		["F2", "controls.language"],
		["Esc", "controls.pause"],
	]
	for r: Array in rows:
		grid.add_child(UiKit.label(str(r[0]), 18, UiKit.ACCENT))
		grid.add_child(UiKit.label(Loc.ui(str(r[1])), 18))


func _audio() -> void:
	_slider("settings.master_volume", "master_volume", 0.0, 1.0, 0.05, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_check("settings.mute", "muted")


func _video() -> void:
	_check("settings.fullscreen", "fullscreen")
	_check("settings.vsync", "vsync")
	_slider("settings.max_fps", "max_fps", 0.0, 240.0, 30.0, func(v: float) -> String: return str(int(v)))


# --- widgets -----------------------------------------------------------------

func _row(caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := UiKit.label(caption, 19)
	l.custom_minimum_size = Vector2(380, 0)
	row.add_child(l)
	_page.add_child(row)
	return row


func _check(key: String, setting: String) -> void:
	var row := _row(Loc.ui(key))
	var c := CheckButton.new()
	c.button_pressed = bool(GameSession.settings.get(setting, false))
	c.focus_mode = Control.FOCUS_ALL
	c.toggled.connect(func(on: bool) -> void: _apply_setting(setting, on))
	row.add_child(c)


func _slider(key: String, setting: String, lo: float, hi: float, step: float, fmt: Callable) -> void:
	var row := _row(Loc.ui(key))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(260, 28)
	s.focus_mode = Control.FOCUS_ALL
	s.value = float(GameSession.settings.get(setting, lo))
	var val := UiKit.label(fmt.call(s.value), 18, UiKit.DIM)
	val.custom_minimum_size = Vector2(70, 0)
	s.value_changed.connect(_on_slider.bind(setting, val, fmt))
	row.add_child(s)
	row.add_child(val)


func _on_slider(v: float, setting: String, val: Label, fmt: Callable) -> void:
	val.text = fmt.call(v)
	_apply_setting(setting, int(v) if GameSession.settings.get(setting) is int else v)


func _apply_setting(setting: String, value: Variant) -> void:
	GameSession.set_setting(setting, value)
	if _note != null:
		_note.text = Loc.ui("settings.save_failed") if not GameSession.prefs_error.is_empty() \
			else Loc.ui("settings.saved_note")
