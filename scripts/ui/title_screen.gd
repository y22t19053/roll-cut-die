extends Control
## TitleScreen — New Game, Continue, Settings, Quit.
##
## Reads the save only to describe it; never writes or deletes it. New Game
## leaves the old save on disk until the new run's first save replaces it, and
## asks first when there is one. Language switches in place (F2 or the corner
## button) and is remembered independently of any save.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Loc = preload("res://scripts/core/loc.gd")
const Logger = preload("res://scripts/core/logger.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
const ConfirmBox = preload("res://scripts/ui/confirm_box.gd")

var settings_panel: Control
var confirm: Control
var _menu: Control
var _status_key := ""
var _summary: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Coming back from a paused take must never leave the tree frozen.
	get_tree().paused = false
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.038, 0.045)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu = Control.new()
	_menu.name = "Menu"
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_panel = SettingsPanel.new()
	settings_panel.name = "Settings"
	add_child(settings_panel)
	settings_panel.closed.connect(func() -> void: UiKit.focus_first(_menu))
	confirm = ConfirmBox.new()
	confirm.name = "Confirm"
	add_child(confirm)
	confirm.answered.connect(_on_new_game_answer)
	GameSession.language_changed.connect(_on_language_changed)
	_summary = GameSession.save_summary()
	_render()
	UiKit.focus_first(_menu)
	Logger.info("title ready (save: %s)" % ("ok" if _summary["ok"] else str(_summary["reason"])))


func _on_language_changed(_lang: String) -> void:
	# Deferred: the language button that triggered this is rebuilt.
	_rerender.call_deferred()


func _rerender() -> void:
	_render()
	confirm.relocalize()
	if not settings_panel.is_open() and not confirm.is_open():
		UiKit.focus_first(_menu)


func _render() -> void:
	UiKit.clear(_menu)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	UiKit.centered(_menu).add_child(col)

	var title := UiKit.label("ROLL CUT DIE", 84, UiKit.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 10)
	col.add_child(title)
	var tag := UiKit.label(Loc.ui("title.tagline"), 22, UiKit.DIM)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	col.add_child(gap)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(buttons)
	var cont := UiKit.button(Loc.ui("menu.continue"), _on_continue)
	cont.disabled = not bool(_summary.get("ok", false))
	buttons.add_child(cont)
	buttons.add_child(UiKit.button(Loc.ui("menu.new"), _on_new_game))
	if ResourceLoader.exists("res://scenes/backlot/backlot.tscn"):
		buttons.add_child(UiKit.button(Loc.ui("menu.backlot"), _on_backlot))
	buttons.add_child(UiKit.button(Loc.ui("menu.settings"), func() -> void: settings_panel.open()))
	buttons.add_child(UiKit.button(Loc.ui("menu.quit"), func() -> void: get_tree().quit()))

	var status := UiKit.label(_status_text(), 18, UiKit.DIM)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(640, 0)
	col.add_child(status)

	# Language: always one click away, written in the language it switches to.
	var other := "en" if Loc.language == "zh" else "zh"
	var lang := UiKit.button(Loc.language_name(other), _switch_language.bind(other), 18)
	lang.custom_minimum_size = Vector2(150, 40)
	lang.anchor_left = 1.0
	lang.anchor_right = 1.0
	lang.offset_left = -180.0
	lang.offset_right = -24.0
	lang.offset_top = 24.0
	lang.offset_bottom = 64.0
	_menu.add_child(lang)

	var foot := UiKit.label(Loc.ui("menu.footer"), 16, UiKit.DIM)
	foot.anchor_top = 1.0
	foot.anchor_bottom = 1.0
	foot.offset_left = 24.0
	foot.offset_top = -44.0
	foot.offset_right = 900.0
	foot.offset_bottom = -16.0
	_menu.add_child(foot)


## Under the menu: why Continue is unavailable, what it would load, or the
## last error.
func _status_text() -> String:
	if not _status_key.is_empty():
		return Loc.ui(_status_key)
	if bool(_summary.get("ok", false)):
		return Loc.ui("save.found", [int(_summary["take"]), int(_summary["ghosts"])])
	return Loc.ui(_reason_key(str(_summary.get("reason", "missing"))))


static func _reason_key(reason: String) -> String:
	if reason == "missing":
		return "save.none"
	if reason.begins_with("version_"):
		return "save.version"
	return "save.corrupt"


func _switch_language(lang: String) -> void:
	GameSession.set_language(lang)


func _on_backlot() -> void:
	GameSession.request_new_game()
	var err := get_tree().change_scene_to_file("res://scenes/backlot/backlot.tscn")
	if err != OK:
		_status_key = "error.scene"
		_rerender()


func _on_continue() -> void:
	var reason: String = GameSession.request_continue()
	if not reason.is_empty():
		Logger.warn("continue refused: " + reason)
		_summary = {"ok": false, "reason": reason}
		_status_key = _reason_key(reason)
		_render()
		UiKit.focus_first(_menu)
		return
	_open_studio()


func _on_new_game() -> void:
	if bool(_summary.get("ok", false)):
		confirm.ask("confirm.new_overwrite")
		return
	_start_new()


func _on_new_game_answer(yes: bool) -> void:
	if yes:
		_start_new()
	else:
		UiKit.focus_first(_menu)


func _start_new() -> void:
	GameSession.request_new_game()
	_open_studio()


func _open_studio() -> void:
	var err := get_tree().change_scene_to_file(GameSession.GAME_SCENE)
	if err != OK:
		Logger.error("cannot open studio: %s" % error_string(err))
		_status_key = "error.scene"
		_render()
		UiKit.focus_first(_menu)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).physical_keycode:
		KEY_F2:
			_switch_language("en" if Loc.language == "zh" else "zh")
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if confirm.is_open():
				confirm.cancel()
			elif settings_panel.is_open():
				settings_panel.close()
			get_viewport().set_input_as_handled()
