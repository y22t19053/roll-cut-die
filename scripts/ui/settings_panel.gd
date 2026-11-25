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
var _focus_key := ""
var _readout_font: SystemFont


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	GameSession.language_changed.connect(_on_language_changed)
	resized.connect(_queue_render)
	_readout_font = SystemFont.new()
	_readout_font.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "monospace"])


func _on_language_changed(_lang: String) -> void:
	_queue_render()


func _queue_render() -> void:
	if visible:
		_render.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _pick_tab(id: String) -> void:
	tab = id
	_focus_key = "tab_" + id
	# Deferred: the pressed button is one of the nodes the rebuild frees.
	_render.call_deferred()


func _pick_language(lang: String) -> void:
	if Loc.language != lang:
		GameSession.set_language(lang)


## The pad is the one setting that changes the picture for everyone watching a
## screen recording, so it gets a three-way choice rather than a checkbox.
func _pick_touch(id: String) -> void:
	GameSession.set_setting("touch_pad", id)
	_render.call_deferred()


func open() -> void:
	visible = true
	_focus_key = "tab_" + tab
	_render()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func _render() -> void:
	if not is_visible_in_tree():
		return
	var previous := get_viewport().gui_get_focus_owner()
	if previous != null and is_ancestor_of(previous) and _focus_key.is_empty():
		_focus_key = str(previous.get_meta("settings_focus", ""))
	UiKit.clear(self)
	add_child(UiKit.scrim())
	var p := UiKit.panel()
	UiKit.centered(self).add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	p.add_child(box)
	var zh: bool = Loc.language == "zh"
	box.add_child(UiKit.header_strip(
		"片场技术单  //  参数与偏好" if zh else "MACGUFFIN WORKS  //  TECH SPEC & PREFERENCES",
		Loc.ui("settings.title")))

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 2)
	box.add_child(tabs)
	var current_tab_button: Button
	for id: String in TABS:
		var b := UiKit.button(Loc.ui("settings.tab_" + id), _pick_tab.bind(id), 17)
		b.custom_minimum_size = Vector2(0, 36)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.button_pressed = id == tab
		b.set_meta("settings_focus", "tab_" + id)
		tabs.add_child(b)
		if id == tab:
			current_tab_button = b

	var scroll := ScrollContainer.new()
	var sheet_width := clampf(size.x - 54.0, 260.0, 680.0)
	scroll.custom_minimum_size = Vector2(sheet_width, clampf(size.y - 245.0, 85.0, 388.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	box.add_child(scroll)
	_page = VBoxContainer.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_constant_override("separation", 6)
	scroll.add_child(_page)
	match tab:
		"general":
			_general()
		"controls":
			_controls()
		"audio":
			_audio()
		"video":
			_video()

	box.add_child(UiKit.rule())
	_note = UiKit.label(Loc.ui("settings.save_failed") if not GameSession.prefs_error.is_empty()
		else Loc.ui("settings.saved_note"), 14, UiKit.DIM)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_note)
	var back := UiKit.button(Loc.ui("menu.back"), close, 18)
	back.custom_minimum_size = Vector2(0, 37)
	back.set_meta("settings_focus", "back")
	box.add_child(back)
	var focus: Control = current_tab_button
	if not _focus_key.is_empty():
		for child: Node in box.find_children("*", "Control", true, false):
			if str(child.get_meta("settings_focus", "")) == _focus_key:
				focus = child as Control
				break
	_focus_key = ""
	if focus != null:
		focus.grab_focus()


# --- pages -------------------------------------------------------------------

func _general() -> void:
	var row := _row(Loc.ui("settings.language"))
	for lang: String in Loc.SUPPORTED:
		var b := UiKit.button(Loc.language_name(lang), _pick_language.bind(lang), 20)
		b.custom_minimum_size = Vector2(0, 34)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("settings_focus", "language_" + lang)
		b.toggle_mode = true
		b.button_pressed = Loc.language == lang
		row.add_child(b)
	_check("settings.reduce_motion", "reduce_motion")
	_slider("settings.roll_scale", "roll_scale", 0.0, 1.5, 0.05, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))


func _controls() -> void:
	var pad_row := _row(Loc.ui("settings.touch_pad"))
	for id: String in ["auto", "on", "off"]:
		var b := UiKit.button(Loc.ui("settings.touch_" + id), _pick_touch.bind(id), 15)
		b.custom_minimum_size = Vector2(0, 34)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("settings_focus", "pad_" + id)
		b.toggle_mode = true
		b.button_pressed = str(GameSession.settings.get("touch_pad", "auto")) == id
		pad_row.add_child(b)
	_slider("settings.mouse_sensitivity", "mouse_sensitivity", 0.0005, 0.006, 0.0001,
		func(v: float) -> String: return "%.1f" % (v * 1000.0))
	var zh: bool = Loc.language == "zh"
	var ledger := VBoxContainer.new()
	ledger.add_theme_constant_override("separation", 1)
	_page.add_child(ledger)
	ledger.add_child(UiKit.label("片场按键表" if zh else "SOUNDSTAGE KEY LEDGER", 14, UiKit.AMBER))
	var rows := [
		["WASD", Loc.ui("controls.move")],
		["E", Loc.ui("controls.interact")],
		["M", Loc.ui("controls.mark")],
		["C", "剪辑台" if zh else "CUTTING DESK"],
		["1 / 2 / 3", "选片条" if zh else "Pick strip"],
		["SPACE", "确认 / 重拍" if zh else "Confirm / Retake"],
		["R", "同种子重拍 / 报告" if zh else "Replay seed / Report"],
		["F2", "中文 / EN"],
		["F3", "镜头横倾" if zh else "Lens tilt"],
		["ESC", "暂停 / 返回" if zh else "Pause / Back"],
		[Loc.ui("controls.key_look"), Loc.ui("controls.look")],
		["F1 / F5 / F6 / F7", Loc.ui("controls.roll")],
	]
	for entry: Array in rows:
		ledger.add_child(UiKit.rule())
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var key := UiKit.label(str(entry[0]), 14, UiKit.AMBER)
		key.custom_minimum_size.x = 150
		line.add_child(key)
		line.add_child(UiKit.label(str(entry[1]), 15))
		ledger.add_child(line)


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
	row.add_theme_constant_override("separation", 7)
	var l := UiKit.label(caption, 17)
	l.custom_minimum_size.x = clampf(size.x * 0.22, 100.0, 195.0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	_page.add_child(row)
	return row


func _check(key: String, setting: String) -> void:
	var row := _row(Loc.ui(key))
	var b := UiKit.button("", Callable(), 16)
	b.custom_minimum_size = Vector2(125, 34)
	b.toggle_mode = true
	b.set_meta("settings_focus", setting)
	b.add_theme_stylebox_override("normal", UiKit.stock(UiKit.CARBON, UiKit.ACCENT.darkened(0.30), 3))
	b.add_theme_stylebox_override("pressed", UiKit.stock(Color("222f2c"), UiKit.MINT, 3))
	b.add_theme_stylebox_override("hover_pressed", UiKit.stock(Color("2c3935"), UiKit.MINT, 3))
	b.set_pressed_no_signal(bool(GameSession.settings.get(setting, false)))
	var word := func(on: bool) -> String:
		if Loc.language == "zh":
			return "[ 开 ]" if on else "[ 关 ]"
		return "[ ON ]" if on else "[ OFF ]"
	b.text = word.call(b.button_pressed)
	b.toggled.connect(func(on: bool) -> void:
		b.text = word.call(on)
		_apply_setting(setting, on))
	row.add_child(b)


func _slider(key: String, setting: String, lo: float, hi: float, step: float, fmt: Callable) -> void:
	var row := _row(Loc.ui(key))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(36, 29)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_ALL
	s.set_meta("settings_focus", setting)
	s.value = float(GameSession.settings.get(setting, lo))
	UiKit.style_slider(s)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiKit.stock(UiKit.CARBON, UiKit.RULE))
	var val := UiKit.label(fmt.call(s.value), 16, UiKit.AMBER)
	val.add_theme_font_override("font", _readout_font)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.custom_minimum_size.x = 38
	badge.add_child(val)
	s.value_changed.connect(_on_slider.bind(setting, val, fmt))
	row.add_child(s)
	row.add_child(badge)


func _on_slider(v: float, setting: String, val: Label, fmt: Callable) -> void:
	val.text = fmt.call(v)
	_apply_setting(setting, int(v) if GameSession.settings.get(setting) is int else v)


func _apply_setting(setting: String, value: Variant) -> void:
	GameSession.set_setting(setting, value)
	if _note != null:
		_note.text = Loc.ui("settings.save_failed") if not GameSession.prefs_error.is_empty() \
			else Loc.ui("settings.saved_note")
