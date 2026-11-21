extends Control
## TitleScreen — PLAY (Backlot rescue, else studio New), Continue, New Game,
## Settings, Quit.
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
const NightStage = preload("res://scripts/ui/night_stage.gd")
const NightStageMusic = preload("res://scripts/ui/night_stage_music.gd")

const BACKLOT_SCENE := "res://scenes/backlot/backlot.tscn"
const PLAY_TEXT_X := 98

var settings_panel: Control
var confirm: Control
var stage: NightStage
var music: NightStageMusic
var _menu: Control
var _motion_toggle: Button
var _in_credits := false
var _status_key := ""
var _summary: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Coming back from a paused take must never leave the tree frozen.
	get_tree().paused = false
	# The night shoot: drawn backdrop (frozen when Reduce motion is saved on)
	# and the quiet score, on Master so saved mute / volume apply from sample one.
	stage = NightStage.new()
	stage.name = "NightStage"
	stage.still = _reduced()
	add_child(stage)
	music = NightStageMusic.new()
	music.name = "Music"
	add_child(music)
	GameSession.settings_changed.connect(_on_setting_changed)
	_menu = Control.new()
	_menu.name = "Menu"
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_panel = SettingsPanel.new()
	settings_panel.name = "Settings"
	add_child(settings_panel)
	settings_panel.closed.connect(_focus_menu)
	confirm = ConfirmBox.new()
	confirm.name = "Confirm"
	add_child(confirm)
	confirm.answered.connect(_on_new_game_answer)
	GameSession.language_changed.connect(_on_language_changed)
	_summary = GameSession.save_summary()
	_render()
	_focus_menu()
	Logger.info("title ready (save: %s)" % ("ok" if _summary["ok"] else str(_summary["reason"])))


func _reduced() -> bool:
	return bool(GameSession.settings.get("reduce_motion", false))


## PLAY keeps first focus even though the motion row sits above it.
func _focus_menu() -> void:
	var play := _menu.find_child("Play", true, false) as Button
	if play != null and play.is_visible_in_tree() and not play.disabled:
		play.grab_focus()
	else:
		UiKit.focus_first(_menu)


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key != "reduce_motion":
		return
	stage.still = _reduced()
	if is_instance_valid(_motion_toggle):
		_motion_toggle.text = _motion_toggle_text()


func _motion_toggle_text() -> String:
	if Loc.language == "zh":
		return "减弱动态效果：" + ("开" if _reduced() else "关")
	return "Reduce motion: " + ("On" if _reduced() else "Off")


func _open_motion_settings() -> void:
	settings_panel.tab = "general"
	settings_panel.open()


## Brief bilingual motion notice with the static switch and a way into the
## existing Settings (General > Reduce motion), placed before PLAY.
func _motion_row() -> Control:
	var box := VBoxContainer.new()
	box.name = "MotionNotice"
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var zh := Loc.language == "zh"
	var note := UiKit.label(
		"镜头会随移动旋转，可能引起眩晕。开拍前可减弱动态效果" if zh
		else "Moving rotates the camera and may cause dizziness. You can reduce motion before you play.",
		16, UiKit.INK)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(620, 0)
	box.add_child(note)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	_motion_toggle = _secondary(UiKit.button(_motion_toggle_text(),
		func() -> void: GameSession.set_setting("reduce_motion", not _reduced())))
	_motion_toggle.name = "StaticBackdrop"
	row.add_child(_motion_toggle)
	var link := _secondary(UiKit.button("动效设置…" if zh else "Motion settings…", _open_motion_settings))
	link.name = "MotionSettings"
	row.add_child(link)
	for b: Button in [_motion_toggle, link]:
		b.custom_minimum_size = Vector2(230, 36)
		b.add_theme_font_size_override("font_size", 17)
	return box


func _on_language_changed(_lang: String) -> void:
	# Deferred: the language button that triggered this is rebuilt.
	_rerender.call_deferred()


func _rerender() -> void:
	_render()
	confirm.relocalize()
	if not settings_panel.is_open() and not confirm.is_open():
		_focus_menu()


func _render() -> void:
	UiKit.clear(_menu)
	if _in_credits:
		_render_credits()
		return
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
	gap.custom_minimum_size = Vector2(0, 4)
	col.add_child(gap)
	col.add_child(_motion_row())

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(buttons)
	# Transport first: one deck PLAY key that rolls the Backlot rescue when it
	# ships, else a studio New Game (same confirm path as the New slate). It is
	# named "Play", which is what _focus_menu looks for.
	# Then the studio takes (continue / new) as slates with an orange ink edge;
	# housekeeping (settings / quit) sits below a ruled line, quieter.
	if ResourceLoader.exists("res://scenes/studiolot/world.tscn"):
		buttons.add_child(_play_key("制片厂" if Loc.language == "zh" else "The Studio Lot", _on_studiolot))
		buttons.add_child(_secondary(UiKit.button(Loc.ui("menu.backlot"), _on_backlot)))
	elif ResourceLoader.exists(BACKLOT_SCENE):
		buttons.add_child(_play_key(Loc.ui("menu.backlot"), _on_backlot))
	else:
		buttons.add_child(_play_key(Loc.ui("menu.new"), _on_new_game))
	var cont := _primary(UiKit.button(Loc.ui("menu.continue"), _on_continue))
	cont.disabled = not bool(_summary.get("ok", false))
	buttons.add_child(cont)
	buttons.add_child(_primary(UiKit.button(Loc.ui("menu.new"), _on_new_game)))
	var rule := ColorRect.new()
	rule.color = Color(UiKit.DIM, 0.35)
	rule.custom_minimum_size = Vector2(220, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.add_child(rule)
	buttons.add_child(_secondary(UiKit.button(Loc.ui("menu.settings"), func() -> void: settings_panel.open())))
	buttons.add_child(_secondary(UiKit.button("制作名单" if Loc.language == "zh" else "Credits", _credits.bind(true))))
	buttons.add_child(_secondary(UiKit.button(Loc.ui("menu.quit"), func() -> void: get_tree().quit())))

	var status := UiKit.label(_status_text(), 18, UiKit.DIM)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(640, 0)
	col.add_child(status)

	# Language: name the destination in the current interface language.
	var other := "en" if Loc.language == "zh" else "zh"
	var lang := UiKit.button(Loc.language_name(other), _switch_language.bind(other), 18)
	lang.custom_minimum_size = Vector2(150, 40)
	lang.anchor_left = 1.0
	lang.anchor_right = 1.0
	lang.offset_left = -236.0
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


## Slate-edge box: square corners, `edge` px ink strip on the left, `rule` px
## elsewhere. Focus boxes pass a transparent bg so they overlay hover/normal.
static func _slate(bg: Color, ink: Color, edge: int, rule: int, bottom: int = -1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = ink
	sb.set_corner_radius_all(0)
	sb.border_width_left = edge
	sb.border_width_top = rule
	sb.border_width_right = rule
	sb.border_width_bottom = rule if bottom < 0 else bottom
	# Capped so a thicker hover/focus edge doesn't shift the label.
	sb.content_margin_left = 14 + mini(edge, 6)
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


## The primary transport control: a tall slate with a recessed deck key and a
## procedurally drawn play triangle (no glyph dependency). The localized
## destination line identifies the scene that will open.
func _play_key(destination: String, on_pressed: Callable) -> Button:
	var b := _primary(UiKit.button(Loc.ui("menu.play"), on_pressed))
	b.name = "Play"
	b.custom_minimum_size = Vector2(400, 88)
	b.add_theme_font_size_override("font_size", 32)
	b.add_theme_stylebox_override("normal", _slate(Color(0.15, 0.13, 0.13, 0.98), UiKit.ACCENT, 8, 2))
	b.add_theme_stylebox_override("hover", _slate(Color(0.22, 0.17, 0.16, 0.98), UiKit.ACCENT, 10, 2))
	b.add_theme_stylebox_override("focus", _slate(Color(0, 0, 0, 0), Color.WHITE, 10, 3))
	# Room for the key on the left and the destination line underneath.
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := b.get_theme_stylebox(state) as StyleBoxFlat
		sb.content_margin_left = PLAY_TEXT_X
		sb.content_margin_bottom = 30
	var dest := UiKit.label(destination, 16, UiKit.DIM)
	dest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dest.clip_text = true
	dest.position = Vector2(PLAY_TEXT_X, 54)
	dest.size = Vector2(400 - PLAY_TEXT_X - 14, 24)
	b.add_child(dest)
	b.draw.connect(_draw_play_key.bind(b))
	return b


## Drawn over the button's own stylebox: a dark key well with an ink rim and
## the play triangle, lit white while the key is hovered or focused.
func _draw_play_key(b: Button) -> void:
	var lit := b.has_focus() or b.is_hovered()
	var side := b.size.y - 28.0
	var well := Rect2(22, 14, side, side)
	b.draw_rect(well, Color(0.03, 0.032, 0.038))
	b.draw_rect(well, Color(UiKit.ACCENT, 1.0 if lit else 0.6), false, 2.0)
	var c := well.get_center()
	var r := side * 0.28
	var tri := PackedVector2Array([
		Vector2(c.x - r * 0.8, c.y - r),
		Vector2(c.x + r, c.y),
		Vector2(c.x - r * 0.8, c.y + r),
	])
	b.draw_colored_polygon(tri, Color.WHITE if lit else UiKit.ACCENT)


## New / Continue: full-weight slates, film-orange ink edge.
static func _primary(b: Button) -> Button:
	b.custom_minimum_size = Vector2(340, 52)
	b.add_theme_font_size_override("font_size", 24)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var faded_ink := Color(UiKit.ACCENT, 0.55)
	b.add_theme_stylebox_override("normal", _slate(Color(0.12, 0.125, 0.14, 0.97), faded_ink, 6, 1))
	b.add_theme_stylebox_override("hover", _slate(Color(0.19, 0.17, 0.165, 0.98), UiKit.ACCENT, 10, 1))
	b.add_theme_stylebox_override("pressed", _slate(Color(UiKit.ACCENT, 0.85), UiKit.INK, 10, 1))
	b.add_theme_stylebox_override("focus", _slate(Color(0, 0, 0, 0), UiKit.ACCENT, 10, 2))
	b.add_theme_stylebox_override("disabled", _slate(Color(0.075, 0.075, 0.085, 0.9), Color(0.22, 0.2, 0.2), 6, 1))
	b.add_theme_color_override("font_color", UiKit.INK)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.38, 0.38, 0.4))
	return b


## Settings / Quit: narrower, smaller, no fill — just an ink underline.
static func _secondary(b: Button) -> Button:
	b.custom_minimum_size = Vector2(260, 40)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 19)
	var none := Color(0, 0, 0, 0)
	b.add_theme_stylebox_override("normal", _slate(none, Color(UiKit.DIM, 0.35), 0, 0, 1))
	b.add_theme_stylebox_override("hover", _slate(Color(1, 1, 1, 0.04), UiKit.INK, 0, 0, 2))
	b.add_theme_stylebox_override("pressed", _slate(Color(UiKit.ACCENT, 0.25), UiKit.ACCENT, 0, 0, 2))
	b.add_theme_stylebox_override("focus", _slate(none, UiKit.ACCENT, 0, 1, 2))
	b.add_theme_stylebox_override("disabled", _slate(none, Color(0.18, 0.18, 0.2), 0, 0, 1))
	b.add_theme_color_override("font_color", UiKit.DIM)
	b.add_theme_color_override("font_hover_color", UiKit.INK)
	b.add_theme_color_override("font_focus_color", UiKit.INK)
	b.add_theme_color_override("font_pressed_color", UiKit.INK)
	b.add_theme_color_override("font_hover_pressed_color", UiKit.INK)
	b.add_theme_color_override("font_disabled_color", Color(0.36, 0.36, 0.38))
	return b


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


func _credits(opened: bool) -> void:
	_in_credits = opened
	_rerender.call_deferred()

func _render_credits() -> void:
	var zh := Loc.language == "zh"
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	UiKit.centered(_menu).add_child(col)
	for line: String in ["ROLL CUT DIE", "出品与制作" if zh else "A GAME BY", "MacGuffin Works", "游戏引擎  ·  Godot Engine" if zh else "ENGINE  ·  Godot Engine", "字体  ·  Noto Sans CJK SC" if zh else "TYPE  ·  Noto Sans CJK SC", "© 2014–2021 Adobe  ·  SIL Open Font License 1.1"]:
		var label := UiKit.label(line, 38 if line == "MacGuffin Works" else 22, UiKit.INK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(label)
	col.add_child(UiKit.button("返回标题" if zh else "Back to title", _credits.bind(false)))

func _switch_language(lang: String) -> void:
	GameSession.set_language(lang)


## Every exit from the title goes through here so the score is cut before the
## scene swap; if the swap is refused the title stays, so the score resumes.
func _leave(path: String) -> Error:
	music.halt()
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		music.start()
	return err


func _on_studiolot() -> void:
	GameSession.request_new_game()
	if _leave("res://scenes/studiolot/world.tscn") != OK:
		_status_key = "error.scene"
		_rerender()


func _on_backlot() -> void:
	GameSession.request_new_game()
	var err := _leave(BACKLOT_SCENE)
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
		_focus_menu()
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
		_focus_menu()


func _start_new() -> void:
	GameSession.request_new_game()
	_open_studio()


func _open_studio() -> void:
	var err := _leave(GameSession.GAME_SCENE)
	if err != OK:
		Logger.error("cannot open studio: %s" % error_string(err))
		_status_key = "error.scene"
		_render()
		_focus_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match (event as InputEventKey).physical_keycode:
		KEY_F2:
			_switch_language("en" if Loc.language == "zh" else "zh")
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if _in_credits:
				_credits(false)
			elif confirm.is_open():
				confirm.cancel()
			elif settings_panel.is_open():
				settings_panel.close()
			get_viewport().set_input_as_handled()
