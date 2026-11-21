extends Control
## TitleScreen — New Game (straight into the relay run), Settings, Credits,
## Quit.
##
## There is no Continue: the relay run has no persistence yet, and the title
## never reads, writes or deletes the old studio save. Language switches in
## place (F2 or the corner button) and is remembered independently.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Loc = preload("res://scripts/core/loc.gd")
const Logger = preload("res://scripts/core/logger.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
const NightStage = preload("res://scripts/ui/night_stage.gd")
const NightStageMusic = preload("res://scripts/ui/night_stage_music.gd")

const RUN_SCENE := "res://scenes/relay/run.tscn"
const GLYPH_X := 64

var settings_panel: Control
var stage: NightStage
var music: NightStageMusic
var _menu: Control
var _motion_toggle: Button
var _in_credits := false
var _failed := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Coming back from a paused take must never leave the tree frozen.
	get_tree().paused = false
	# The night shoot: drawn backdrop (frozen when Reduce motion is saved on)
	# and the quiet score, on Master so saved mute / volume apply from sample
	# one; Reduce motion also drops the score's rhythmic pulse.
	stage = NightStage.new()
	stage.name = "NightStage"
	stage.still = _reduced()
	add_child(stage)
	music = NightStageMusic.new()
	music.name = "Music"
	music.still = _reduced()
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
	GameSession.language_changed.connect(_on_language_changed)
	_render()
	_focus_menu()
	Logger.info("title ready")


func _reduced() -> bool:
	return bool(GameSession.settings.get("reduce_motion", false))


## New Game keeps first focus even though the motion row sits above it.
func _focus_menu() -> void:
	var play := _menu.find_child("NewGame", true, false) as Button
	if play != null and play.is_visible_in_tree() and not play.disabled:
		play.grab_focus()
	else:
		UiKit.focus_first(_menu)


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key != "reduce_motion":
		return
	stage.still = _reduced()
	music.still = _reduced()
	if is_instance_valid(_motion_toggle):
		_motion_toggle.text = _motion_toggle_text()


func _motion_toggle_text() -> String:
	if Loc.language == "zh":
		return "减弱动态效果：" + ("开" if _reduced() else "关")
	return "Reduce motion: " + ("On" if _reduced() else "Off")


func _open_motion_settings() -> void:
	settings_panel.tab = "general"
	settings_panel.open()


## Brief localized motion notice with the static switch and a way into the
## existing Settings (General > Reduce motion), placed before New Game.
func _motion_row() -> Control:
	var box := VBoxContainer.new()
	box.name = "MotionNotice"
	box.add_theme_constant_override("separation", 6)
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var zh := Loc.language == "zh"
	var note := UiKit.label(
		"画面运动可能引起不适，开始前可在此减弱动态效果。" if zh
		else "Screen motion can be uncomfortable. You can reduce it here before you start.",
		16, UiKit.DIM)
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
	if not settings_panel.is_open():
		_focus_menu()


## How to play in one line: the controls and the goal.
func _tagline() -> String:
	if Loc.language == "zh":
		return "WASD 或方向键移动 · 走到亮起的线"
	return "Move with WASD or the arrow keys · Go to the lit line"


func _render() -> void:
	UiKit.clear(_menu)
	if _in_credits:
		_render_credits()
		return
	var zh := Loc.language == "zh"
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var placement := UiKit.centered(_menu)
	placement.anchor_right = 0.49
	placement.add_child(col)

	var title := UiKit.label("ROLL\nCUT DIE", 76, UiKit.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 10)
	col.add_child(title)
	var tag := UiKit.label(_tagline(), 22, UiKit.INK)
	tag.name = "Tagline"
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
	# One way in, then housekeeping below a ruled line, quieter.
	var save = load("res://scripts/relay/relay_save.gd")
	# An open run is offered before a new one: closing the game should never be
	# the most expensive decision in it.
	if save.has_run():
		var cont := _primary(UiKit.button("继续这一卷" if zh else "CONTINUE", _on_continue))
		cont.name = "Continue"
		cont.custom_minimum_size = Vector2(340, 52)
		cont.add_theme_font_size_override("font_size", 24)
		buttons.add_child(cont)
	buttons.add_child(_new_game_key())
	var rules = load("res://scripts/relay/relay_rules.gd")
	var modes := OptionButton.new()
	modes.name = "Difficulty"
	modes.tooltip_text = "通关当前难度以解锁下一档" if zh else "Clear a difficulty to unlock the next one"
	for i in 3:
		var text: String = (["新手", "专家", "大师"] if zh else ["Novice", "Expert", "Master"])[i]
		var available: bool = rules.unlocked(i)
		if not available:
			text += (["", " · 新手通关解锁", " · 专家通关解锁"] if zh else ["", " · clear Novice", " · clear Expert"])[i]
		modes.add_item(text, i)
		modes.set_item_disabled(i, not available)
	if not rules.unlocked(rules.selected_mode): rules.selected_mode = 0
	modes.select(rules.selected_mode)
	modes.item_selected.connect(func(i: int) -> void: rules.selected_mode = i)
	buttons.add_child(modes)
	# What the player has done before: a record, never a head start.
	var ran: Dictionary = rules.meta()
	var record := UiKit.label(
		("已跑 %d 卷 · 最远 %d / %d 棚" if zh else "%d runs · best set %d / %d") % [int(ran["runs"]), int(ran["best_set"]), 6],
		16, UiKit.DIM)
	record.name = "Record"
	record.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	buttons.add_child(record)
	var daily := _secondary(UiKit.button(
		("每日种子 %06X" if zh else "DAILY SEED %06X") % rules.daily_seed(), _on_daily))
	daily.name = "Daily"
	buttons.add_child(daily)
	var rule := ColorRect.new()
	rule.color = Color(UiKit.DIM, 0.35)
	rule.custom_minimum_size = Vector2(220, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.add_child(rule)
	buttons.add_child(_secondary(UiKit.button(Loc.ui("menu.settings"), func() -> void: settings_panel.open())))
	buttons.add_child(_secondary(UiKit.button("制作名单" if zh else "Credits", _credits.bind(true))))
	buttons.add_child(_secondary(UiKit.button(Loc.ui("menu.quit"), func() -> void: get_tree().quit())))

	if _failed:
		var status := UiKit.label(
			"无法开始新游戏，详见 user://rcd/runtime.log。" if zh
			else "Could not start a new game. See user://rcd/runtime.log.",
			18, UiKit.DIM)
		status.name = "Status"
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		status.custom_minimum_size = Vector2(640, 0)
		col.add_child(status)

	# Language: name the destination in the current interface language.
	var other := "en" if zh else "zh"
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


## The one primary control: a slate with a procedurally drawn play triangle
## (no glyph dependency, no PLAY wording) beside the localized "New Game".
func _new_game_key() -> Button:
	var b := _primary(UiKit.button(Loc.ui("menu.new"), _on_new_game))
	b.name = "NewGame"
	b.custom_minimum_size = Vector2(340, 68)
	b.add_theme_font_size_override("font_size", 30)
	b.add_theme_stylebox_override("normal", _slate(Color(0.15, 0.13, 0.13, 0.98), UiKit.ACCENT, 8, 2))
	b.add_theme_stylebox_override("hover", _slate(Color(0.22, 0.17, 0.16, 0.98), UiKit.ACCENT, 10, 2))
	b.add_theme_stylebox_override("focus", _slate(Color(0, 0, 0, 0), Color.WHITE, 10, 3))
	# Room for the glyph on the left.
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := b.get_theme_stylebox(state) as StyleBoxFlat
		sb.content_margin_left = GLYPH_X
	b.draw.connect(_draw_play_glyph.bind(b))
	return b


## Drawn over the button's own stylebox; lit white while hovered or focused.
func _draw_play_glyph(b: Button) -> void:
	var lit := b.has_focus() or b.is_hovered()
	var c := Vector2(GLYPH_X * 0.5 + 8.0, b.size.y * 0.5)
	var r := b.size.y * 0.2
	var tri := PackedVector2Array([
		Vector2(c.x - r * 0.8, c.y - r),
		Vector2(c.x + r, c.y),
		Vector2(c.x - r * 0.8, c.y + r),
	])
	b.draw_colored_polygon(tri, Color.WHITE if lit else UiKit.ACCENT)


## New Game: full-weight slate, film-orange ink edge.
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


## Settings / Credits / Quit: narrower, smaller, no fill — an ink underline.
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


## Straight into the relay run. Deliberately no GameSession.request_new_game:
## that belongs to the old studio flow and its save.
func _on_new_game() -> void:
	var run = load("res://scripts/relay/relay_run.gd")
	run.pending_resume = {} # A new run never continues the one left open.
	var err := _leave(RUN_SCENE)
	if err != OK:
		Logger.error("cannot open relay run: %s" % error_string(err))
		_failed = true
		_render()
		_focus_menu()


## The daily seed: one seed a day for everyone, so two runs can be compared
## without either player having to type anything.
func _on_daily() -> void:
	var rules = load("res://scripts/relay/relay_rules.gd")
	var run = load("res://scripts/relay/relay_run.gd")
	run.pending_resume = {}
	run.next_seed = rules.daily_seed()
	var err := _leave(RUN_SCENE)
	if err != OK:
		Logger.error("cannot open relay run: %s" % error_string(err))
		_failed = true
		_render()
		_focus_menu()


## Pick the written-down run up at the set it was left in. The save is read here,
## on the title screen, so the run scene only ever gets state it can trust.
func _on_continue() -> void:
	var save = load("res://scripts/relay/relay_save.gd")
	var state: Dictionary = save.load_run()
	if state.is_empty():
		_render()
		return
	var run = load("res://scripts/relay/relay_run.gd")
	run.pending_resume = state
	var err := _leave(RUN_SCENE)
	if err != OK:
		run.pending_resume = {}
		Logger.error("cannot open relay run: %s" % error_string(err))
		_failed = true
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
			elif settings_panel.is_open():
				settings_panel.close()
			get_viewport().set_input_as_handled()
