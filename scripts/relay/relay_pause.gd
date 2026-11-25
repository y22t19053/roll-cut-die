extends CanvasLayer
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Loc = preload("res://scripts/core/loc.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")

signal resumed()
signal left_run()

var is_open := false
## Filled by the run before opening: the sheet you would want to glance at.
var briefing := {}

var _dim: ColorRect
var _col: VBoxContainer
var _hold_card: PanelContainer
var _settings: SettingsPanel
var _rows: Dictionary = {}


func _ready() -> void:
	layer = 24
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _build() -> void:
	_dim = UiKit.scrim()
	add_child(_dim)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_hold_card = UiKit.panel()
	centre.add_child(_hold_card)
	_col = VBoxContainer.new()
	_col.custom_minimum_size.x = 426
	_col.add_theme_constant_override("separation", 5)
	_hold_card.add_child(_col)
	_hold_card.draw.connect(_draw_tape)
	_settings = SettingsPanel.new()
	_settings.name = "Settings"
	_settings.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_settings)
	_settings.closed.connect(_on_settings_closed)
	GameSession.language_changed.connect(_on_language_changed)
	refresh()


func _draw_tape() -> void:
	_hold_card.draw_set_transform(Vector2(31, -4), deg_to_rad(-2.0))
	_hold_card.draw_rect(Rect2(0, 0, 76, 9), Color("d9c9a6"))
	_hold_card.draw_set_transform(Vector2.ZERO)


func _on_language_changed(_lang: String) -> void:
	if is_open:
		refresh()


## Preserve the option being operated when its status or language is updated.
func refresh() -> void:
	if _col == null:
		return
	var focus := get_viewport().gui_get_focus_owner()
	var row_id: String = ""
	if focus != null and _col.is_ancestor_of(focus):
		row_id = str(focus.get_meta("hold_row", ""))
	UiKit.clear(_col)
	_rows.clear()
	var zh: bool = Loc.language == "zh"
	_col.add_child(UiKit.header_strip("拍摄暂停  //  片场挂起" if zh else "CALL SHEET  //  HOLD FOR WORK",
		"暂停场记" if zh else "HOLD FOR WORK", "MACGUFFIN WORKS"))
	if not briefing.is_empty():
		_status_strip()
	_row("resume", "继续这一条" if zh else "Back to the take", _resume)
	var scale_now: float = float(GameSession.settings.get("hud_scale", 1.0))
	_row("scale", "界面大小" if zh else "HUD SIZE", _cycle_hud_scale, "%d%%" % roundi(scale_now * 100.0))
	var pad_now: String = str(GameSession.settings.get("touch_pad", "auto"))
	var pad_stamp: String = str(PAD_NAMES_ZH.get(pad_now, "自动") if zh else PAD_NAMES_EN.get(pad_now, "AUTO"))
	_row("pad", "触控按键" if zh else "TOUCH PAD", _cycle_touch_pad, pad_stamp)
	var motion_on: bool = bool(GameSession.settings.get("reduce_motion", false))
	var motion_stamp: String = ("开" if motion_on else "关") if zh else ("ON" if motion_on else "OFF")
	_row("motion", "减弱动态效果" if zh else "REDUCE MOTION", _toggle_motion, motion_stamp)
	_row("language", "语言" if zh else "LANGUAGE", _toggle_language, "中文" if zh else "EN")
	_col.add_child(UiKit.rule())
	_row("settings", "更多设置…" if zh else "More settings…", _open_settings)
	_row("title", "回到标题" if zh else "Back to the title", _leave)
	if is_open and not _settings.is_open():
		_focus_row(row_id)


func _status_strip() -> void:
	var strip := HBoxContainer.new()
	strip.add_theme_constant_override("separation", 2)
	_col.add_child(strip)
	var cells: Array[String] = [
		"SET %02d/%02d" % [int(briefing.get("set", 1)), int(briefing.get("sets", 1))],
		"LINE %d/%d" % [int(briefing.get("pass", 1)), int(briefing.get("passes", 1))],
		"SEED %06X" % int(briefing.get("seed", 0)),
		"NG %d" % int(briefing.get("deaths", 0)),
	]
	for cell: String in cells:
		var stock := PanelContainer.new()
		stock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stock.add_theme_stylebox_override("panel", UiKit.stock(UiKit.CARBON, UiKit.RULE))
		var label := UiKit.label(cell, 14, UiKit.AMBER)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stock.add_child(label)
		strip.add_child(stock)


func _row(id: String, caption: String, cb: Callable, stamp := "") -> void:
	var b := UiKit.button(caption, cb, 18)
	b.custom_minimum_size = Vector2(0, 38)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.set_meta("hold_row", id)
	if not stamp.is_empty():
		var value := UiKit.label(stamp, 15, UiKit.MINT)
		value.mouse_filter = Control.MOUSE_FILTER_IGNORE
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		b.add_child(value)
		value.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		value.offset_right = -12
	_rows[id] = b
	_col.add_child(b)


func _focus_row(id: String) -> void:
	var button: Button = _rows.get(id, _rows.get("resume")) as Button
	if button != null:
		button.grab_focus()


func _open_settings() -> void:
	_hold_card.hide()
	_dim.hide()
	_settings.open()


func _on_settings_closed() -> void:
	_hold_card.show()
	_dim.show()
	if is_open:
		_focus_row("settings")


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _settings.is_open():
			_settings.close()
		else:
			_resume()


func open() -> void:
	is_open = true
	visible = true
	refresh()
	get_tree().paused = true


func close() -> void:
	if not is_open:
		return
	is_open = false
	_settings.close()
	visible = false
	get_tree().paused = false


func _resume() -> void:
	close()
	resumed.emit()

## Four stops, like Dead Cells' HUD scale, minus the catalogue. It only ever
## touches type: the deck, the cards and the criterion of the game stay put.
const HUD_STEPS := [0.8, 1.0, 1.25, 1.5]

## Auto / always / never. Auto is the default so a keyboard machine never shows
## thumbs, and a phone is never left without a way to move.
const PAD_STEPS := ["auto", "on", "off"]
const PAD_NAMES_ZH := {"auto": "自动", "on": "总是", "off": "从不"}
const PAD_NAMES_EN := {"auto": "AUTO", "on": "ALWAYS", "off": "NEVER"}

func _cycle_touch_pad() -> void:
	var now: String = str(GameSession.settings.get("touch_pad", "auto"))
	var at: int = PAD_STEPS.find(now)
	var next: String = PAD_STEPS[(at + 1) % PAD_STEPS.size()] if at >= 0 else "auto"
	GameSession.set_setting("touch_pad", next)
	refresh()

func _cycle_hud_scale() -> void:
	var now: float = float(GameSession.settings.get("hud_scale", 1.0))
	var next: float = HUD_STEPS[0]
	for i in HUD_STEPS.size():
		if HUD_STEPS[i] > now + 0.001:
			next = HUD_STEPS[i]
			break
	GameSession.set_setting("hud_scale", next)
	refresh()

func _toggle_motion() -> void:
	var on: bool = not bool(GameSession.settings.get("reduce_motion", false))
	GameSession.set_setting("reduce_motion", on)
	refresh()

func _toggle_language() -> void:
	GameSession.set_language("en" if Loc.language == "zh" else "zh")
	left_run_keep_open()

## The parent picks this up to re-render its own text after a language swap.
func left_run_keep_open() -> void:
	if is_open: visible = true

func _leave() -> void:
	close()
	left_run.emit()
