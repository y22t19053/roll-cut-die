extends Control
## The title is a call sheet for the relay, with its own preview soundstage.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Loc = preload("res://scripts/core/loc.gd")
const Logger = preload("res://scripts/core/logger.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
const NightStage = preload("res://scripts/ui/night_stage.gd")
const NightStageMusic = preload("res://scripts/ui/night_stage_music.gd")
const RunScript = preload("res://scripts/relay/relay_run.gd")
const Rules = preload("res://scripts/relay/relay_rules.gd")
const Save = preload("res://scripts/relay/relay_save.gd")
const ToyBridge = preload("res://scripts/relay/toy_bridge.gd")
const PRINT_FONT_PATH := "res://assets/fonts/RCD-Noto.otf"

static var _print_font: Font
static var _print_font_probed := false

const RUN_SCENE := "res://scenes/relay/run.tscn"
const STUDIO_SLUG := "MACGUFFIN WORKS  //  SOUNDSTAGE NO. 04  ·  ORBIT 30°/S"
const PAPER := Color("c8bfa8")
const MODE_KEYS: Array[String] = ["relay.mode_novice", "relay.mode_expert", "relay.mode_master"]
const MODE_EN: Array[String] = ["NOVICE", "EXPERT", "MASTER"]
const MODE_ZH: Array[String] = ["场记 NOVICE", "剪辑师 EXPERT", "导演 MASTER"]

var settings_panel: SettingsPanel
var stage: NightStage
var music: NightStageMusic
var _menu: Control
var _sheet: Control
var _body: VBoxContainer
var _head: VBoxContainer
var _tools: HBoxContainer
var _motion_toggle: Button
var _mode_tabs: Array[Button] = []
var _mode_spec: Label
var _focus_rows: Array[Array] = []
var _in_credits := false
var _failed := false

var _bridge: ToyBridge
var _today: Label
var _board_rows: Array = []
var _board_mine: Dictionary = {}
var _board_tries := 0
var _board_retry: SceneTreeTimer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().paused = false

	stage = NightStage.new()
	stage.name = "NightStage"
	stage.still = _reduced()
	add_child(stage)
	music = NightStageMusic.new()
	music.name = "Music"
	music.still = _reduced()
	add_child(music)

	_menu = Control.new()
	_menu.name = "Menu"
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_panel = SettingsPanel.new()
	settings_panel.name = "Settings"
	add_child(settings_panel)
	settings_panel.closed.connect(_on_settings_closed)
	settings_panel.child_entered_tree.connect(_on_settings_child_entered)

	GameSession.settings_changed.connect(_on_setting_changed)
	GameSession.language_changed.connect(_on_language_changed)
	resized.connect(_reflow, CONNECT_DEFERRED)
	get_window().size_changed.connect(_reflow, CONNECT_DEFERRED)
	_render()
	_start_board()
	UiKit.focus_first(_menu)
	Logger.info("title ready")


func _reduced() -> bool:
	return bool(GameSession.settings.get("reduce_motion", false))


func _on_setting_changed(key: String, _value: Variant) -> void:
	if key == "reduce_motion":
		stage.still = _reduced()
		music.still = _reduced()
		if is_instance_valid(_motion_toggle):
			_motion_toggle.text = _motion_toggle_text()


func _motion_toggle_text() -> String:
	if Loc.language == "zh":
		return "动效：静态" if _reduced() else "动效：开"
	return "MOTION: STILL" if _reduced() else "MOTION: LIVE"


func _toggle_motion() -> void:
	GameSession.set_setting("reduce_motion", not _reduced())


func _on_language_changed(_lang: String) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var previous := String(focused.name) if focused != null and _menu.is_ancestor_of(focused) else ""
	_rerender.call_deferred(previous)


func _rerender(previous: String = "") -> void:
	_render()
	if settings_panel.is_open():
		_set_menu_focus(false)
		return
	var button := _menu.find_child(previous, true, false) as Button if not previous.is_empty() else null
	if button != null and not button.disabled:
		button.grab_focus()
	else:
		UiKit.focus_first(_menu)


func _premise() -> String:
	return Loc.ui("title.tagline")


func _render() -> void:
	UiKit.clear(_menu)
	_focus_rows.clear()
	_mode_tabs.clear()
	_today = null
	_sheet = Control.new()
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(_sheet)

	var zh := Loc.language == "zh"
	# The body comes first in scene order so focus_first lands on the shoot.
	_body = _column(8)
	_sheet.add_child(_body)
	_body.minimum_size_changed.connect(_reflow, CONNECT_DEFERRED)
	if _in_credits:
		_build_credits(zh)
	else:
		_build_call_sheet(zh)
	_build_header(zh)

	_wire_focus()
	_reflow()


func _build_header(zh: bool) -> void:
	_head = _column(6)
	_sheet.add_child(_head)
	var clapper := Control.new()
	clapper.custom_minimum_size = Vector2(0.0, 4.0)
	clapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clapper.draw.connect(_draw_clapper.bind(clapper))
	_head.add_child(clapper)

	var slug := _print(STUDIO_SLUG, 13, PAPER)
	var base_font := _get_print_font()
	if base_font != null:
		var tracked := FontVariation.new()
		tracked.base_font = base_font
		tracked.spacing_glyph = 1
		slug.add_theme_font_override("font", tracked)
	_head.add_child(slug)

	_tools = _row(6)
	_sheet.add_child(_tools)
	var language := _key("中文 / EN  ·  F2", _toggle_language, 13, 34)
	language.name = "Language"
	language.tooltip_text = "切换语言 · F2" if zh else "Switch language · F2"
	_tools.add_child(language)
	_motion_toggle = _key(_motion_toggle_text(), _toggle_motion, 13, 34)
	_motion_toggle.name = "StaticBackdrop"
	_motion_toggle.tooltip_text = ("若画面运动引起不适，可在这里切到静态。更多选项见设置 → 通用。" if zh
		else "Switch to a still stage if screen motion is uncomfortable. See Settings → General for more.")
	_tools.add_child(_motion_toggle)
	_focus_rows.push_front([language, _motion_toggle])


func _draw_clapper(bar: Control) -> void:
	bar.draw_rect(Rect2(0.0, 0.0, 52.0, 4.0), Color("0b0c0e"))
	for stripe: int in 5:
		var x := float(stripe) * 10.0
		bar.draw_colored_polygon(PackedVector2Array([Vector2(x + 4.0, 0.0),
			Vector2(x + 9.0, 0.0), Vector2(x + 5.0, 4.0), Vector2(x, 4.0)]), PAPER)
	bar.draw_rect(Rect2(58.0, 3.0, maxf(0.0, bar.size.x - 58.0), 1.0), UiKit.RULE)


func _get_print_font() -> Font:
	if not _print_font_probed:
		_print_font_probed = true
		if ResourceLoader.exists(PRINT_FONT_PATH):
			_print_font = load(PRINT_FONT_PATH) as Font
	return _print_font


func _build_call_sheet(zh: bool) -> void:
	var masthead := _print("ROLL\nCUT DIE", 72, UiKit.INK)
	masthead.name = "Masthead"
	var base_font := _get_print_font()
	if base_font != null:
		var heavy := FontVariation.new()
		heavy.base_font = base_font
		heavy.variation_embolden = 0.65
		heavy.spacing_glyph = -2
		masthead.add_theme_font_override("font", heavy)
	masthead.add_theme_constant_override("line_spacing", -22)
	_body.add_child(masthead)
	var accent := _rule(UiKit.ACCENT, 3)
	accent.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	accent.custom_minimum_size.x = 52.0
	_body.add_child(accent)
	var premise := _print(_premise(), 17, PAPER)
	premise.name = "Premise"
	premise.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(premise)

	if Save.has_run():
		var here: Dictionary = Save.summary()
		var valid := not here.is_empty()
		var cont := _shoot_key("继续这一卷" if zh else "CONTINUE REEL", _on_continue, 22, 50)
		cont.name = "Continue"
		cont.disabled = not valid
		var badge := "片门待续" if zh else "IN THE GATE"
		if valid:
			var set_number: int = int(here.get("sets", 1))
			var act_number: int = int(here.get("act", 0)) + 1
			cont.tooltip_text = ("棚 %02d / %d · 第 %d 节" if zh else "SET %02d / %d · ACT %d") % [
				set_number, RunScript.MODULES, act_number]
		else:
			badge = "存档无法读取" if zh else "SAVE UNREADABLE"
			cont.tooltip_text = Loc.ui("save.corrupt")
		_stamp(cont, badge, PAPER, 138.0)
		_body.add_child(cont)
		_focus_rows.append([cont])

	var new_game := _shoot_key("开拍新片" if zh else "NEW SHOOT", _on_new_game, 25, 52)
	new_game.name = "NewGame"
	_body.add_child(new_game)
	_focus_rows.append([new_game])

	_build_difficulty(zh)
	_build_daily(zh)
	_build_ledger(zh)
	_build_footer(zh)


func _build_difficulty(zh: bool) -> void:
	if not Rules.unlocked(Rules.selected_mode):
		Rules.selected_mode = 0

	var section := _column(4)
	_body.add_child(section)
	var tabs := _row(6)
	section.add_child(tabs)
	var locked := false
	var unlock_hint := "通关上一档解锁" if zh else "Clear the previous tier to unlock"
	for tier: int in MODE_KEYS.size():
		var key: String = MODE_KEYS[tier]
		var text: String = Loc.ui(key) if Loc.STRINGS.has(key) else (MODE_ZH[tier] if zh else MODE_EN[tier])
		var tab := _key(text, _select_mode.bind(tier), 13, 44)
		tab.name = "Mode%d" % tier
		tab.toggle_mode = true
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.clip_text = false
		tab.disabled = not Rules.unlocked(tier)
		if tab.disabled:
			tab.text += "\n未解锁" if zh else "\nLOCKED"
			tab.tooltip_text = unlock_hint
			tab.focus_mode = Control.FOCUS_NONE
			tab.draw.connect(_draw_lock.bind(tab))
			locked = true
		tabs.add_child(tab)
		_mode_tabs.append(tab)
	_focus_rows.append(_mode_tabs.duplicate())

	_mode_spec = _print("", 14, PAPER)
	_mode_spec.name = "ModeCaption"
	section.add_child(_mode_spec)
	if locked:
		section.add_child(_print(unlock_hint, 12, UiKit.DIM))
	_update_modes()


func _select_mode(tier: int) -> void:
	if not Rules.unlocked(tier):
		return
	Rules.selected_mode = tier
	_update_modes()
	_board_rows.clear()
	_board_mine.clear()
	_refresh_today()
	_start_board()


func _update_modes() -> void:
	for tier: int in _mode_tabs.size():
		var tab: Button = _mode_tabs[tier]
		tab.set_pressed_no_signal(tier == Rules.selected_mode)
	_mode_spec.text = _mode_caption(Loc.language == "zh", Rules.selected_mode)


func _mode_caption(zh: bool, mode: int) -> String:
	var notes: PackedStringArray = PackedStringArray(["宽限重拍", "死亡翻景 180°", "严苛片场"]) if zh else PackedStringArray([
		"GRACE RETAKES", "DEATH TURNS SET 180°", "STRICT SET"])
	var note: String = notes[clampi(mode, 0, notes.size() - 1)]
	return "%d MARK · %d CUT · %s" % [Rules.mark_budget(mode), Rules.cut_budget(mode), note]


func _build_daily(zh: bool) -> void:
	var slip := PanelContainer.new()
	slip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stock := UiKit.stock(Color("211f1c"), UiKit.RULE)
	stock.content_margin_left = 7
	stock.content_margin_right = 7
	stock.content_margin_top = 6
	stock.content_margin_bottom = 6
	slip.add_theme_stylebox_override("panel", stock)
	_body.add_child(slip)
	var lines := _column(3)
	slip.add_child(lines)

	var daily := _key("每日通告" if zh else "DAILY CALL", _on_daily, 17, 37)
	daily.name = "Daily"
	daily.alignment = HORIZONTAL_ALIGNMENT_LEFT
	daily.tooltip_text = "所有人拍同一张图，按难度排行。" if zh else "Shoot the same map as everyone else on your tier."
	lines.add_child(daily)
	_focus_rows.append([daily])
	if Rules.daily_played():
		_stamp(daily, "✓ 已拍" if zh else "✓ PLAYED", PAPER, 86.0)

	var data := _row(8)
	lines.add_child(data)
	var date := _print(("%s · 北京" if zh else "%s · BEIJING") % Rules.daily_key(), 12, PAPER)
	date.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	data.add_child(date)
	data.add_child(_print("#%06X" % Rules.daily_seed(), 13, PAPER))
	_today = _print(_today_text(zh), 13, UiKit.DIM)
	_today.name = "Today"
	_today.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.add_child(_today)
	slip.draw.connect(_draw_tape.bind(slip))


func _draw_tape(slip: Control) -> void:
	var x := slip.size.x - 44.0
	slip.draw_colored_polygon(PackedVector2Array([Vector2(x, -0.7), Vector2(x + 30.0, -0.4),
		Vector2(x + 31.0, 4.7), Vector2(x - 1.0, 4.4)]), Color(PAPER, 0.64))


func _build_ledger(zh: bool) -> void:
	var stats: Dictionary = Rules.meta()
	var labels: PackedStringArray = PackedStringArray(["拍过", "最远", "废片", "收工"]) if zh else PackedStringArray([
		"RUNS", "BEST SET", "DEATHS", "WRAPS"])
	var keys: PackedStringArray = PackedStringArray(["runs", "best_set", "deaths", "wins"])
	var ink: Color = PAPER if int(stats.get("runs", 0)) > 0 else UiKit.DIM
	var ledger := _column(4)
	ledger.name = "Record"
	_body.add_child(ledger)
	ledger.add_child(_print("片场台账" if zh else "CAREER LEDGER", 12, PAPER))
	ledger.add_child(_rule(UiKit.RULE, 1))
	var fields := _row(0)
	ledger.add_child(fields)
	for i: int in keys.size():
		if i > 0:
			var divider := _rule(UiKit.RULE, 1)
			divider.custom_minimum_size.x = 1.0
			fields.add_child(divider)
		var field := _row(5)
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field.alignment = BoxContainer.ALIGNMENT_CENTER
		fields.add_child(field)
		var caption: String = labels[i]
		var key: String = keys[i]
		field.add_child(_print(caption, 12, UiKit.DIM))
		field.add_child(_print("%02d" % int(stats.get(key, 0)), 17, ink))
	ledger.add_child(_rule(UiKit.RULE, 1))


func _build_footer(zh: bool) -> void:
	var tools := _row(6)
	_body.add_child(tools)
	var settings := _key(Loc.ui("menu.settings"), _open_settings, 14, 36)
	settings.name = "OpenSettings"
	var credits := _key("制作名单" if zh else "Credits", _credits.bind(true), 14, 36)
	credits.name = "Credits"
	var buttons: Array[Button] = [settings, credits]
	if not OS.has_feature("web"):
		var quit := _key(Loc.ui("menu.quit"), func() -> void: get_tree().quit(), 14, 36)
		quit.name = "Quit"
		buttons.append(quit)
	for item: Button in buttons:
		tools.add_child(item)
	_focus_rows.append(buttons)

	var hint := _print("WASD + ORBIT · M 落点 · C 剪回 · F2 语言" if zh
		else "WASD + ORBIT · M MARK · C CUT · F2 LANGUAGE", 12, UiKit.DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(hint)
	if not FileAccess.file_exists(GameSession.PREFS_PATH):
		var motion_note := _print("画面运动引起不适时，可在上方切到静态。" if zh
			else "If screen motion is uncomfortable, switch to STILL above.", 13, UiKit.DIM)
		motion_note.name = "MotionNotice"
		motion_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(motion_note)
	if _failed:
		var status := _print(Loc.ui("error.scene"), 14, PAPER)
		status.name = "Status"
		status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_body.add_child(status)


func _build_credits(zh: bool) -> void:
	var slate := UiKit.panel()
	slate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(slate)
	var lines := _column(12)
	slate.add_child(lines)
	lines.add_child(_print("制作名单" if zh else "PRODUCTION CREDITS", 14, PAPER))
	lines.add_child(_print("ROLL CUT DIE", 42, UiKit.INK))
	lines.add_child(_rule(UiKit.ACCENT, 2))
	lines.add_child(_print("出品与制作" if zh else "A GAME BY", 12, PAPER))
	lines.add_child(_print("MacGuffin Works", 32, UiKit.INK))
	lines.add_child(_rule(UiKit.RULE, 1))
	lines.add_child(_print("游戏引擎  ·  Godot Engine" if zh else "ENGINE  ·  Godot Engine", 16))
	lines.add_child(_print("字体  ·  Noto Sans CJK SC" if zh else "TYPE  ·  Noto Sans CJK SC", 16))
	var license := _print("© 2014–2021 Adobe  ·  SIL Open Font License 1.1", 13, UiKit.DIM)
	license.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.add_child(license)
	var back := _key("返回标题  ·  ESC" if zh else "Back to title  ·  ESC", _credits.bind(false), 15, 42)
	back.name = "BackToTitle"
	lines.add_child(back)
	_focus_rows.append([back])


func _reflow() -> void:
	if not is_instance_valid(_body) or not is_instance_valid(_tools):
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return

	# canvas_items keeps a large logical viewport on a phone. Compose the
	# compact sheet against the actual window width, then fit its full height.
	var window_width := float(get_window().size.x)
	var compact := window_width <= 700.0 or size.x < size.y * 1.18
	var preferred_scale := 1.0
	if compact:
		preferred_scale = size.x / clampf(window_width, 360.0, 560.0)
	var left := 24.0 if compact else clampf(size.x * 0.05, 72.0, 88.0)
	var column := minf(528.0, size.x / preferred_scale - left * 2.0)
	var body_min := _body.get_combined_minimum_size()
	column = maxf(maxf(column, 360.0), body_min.x)
	var head_min := _head.get_combined_minimum_size()
	var tools_min := _tools.get_combined_minimum_size()
	var header_height := maxf(head_min.y, tools_min.y)
	if compact:
		header_height = head_min.y + tools_min.y + 9.0
	var required_width := maxf(column, maxf(head_min.x, tools_min.x)) + left * 2.0
	var required_height := header_height + body_min.y + 58.0
	var fit := minf(preferred_scale, minf(size.x / required_width, size.y / required_height))
	_sheet.scale = Vector2.ONE * fit

	var frame := size / fit
	var top := 18.0 if compact else 32.0
	_head.position = Vector2(left, top)
	_head.size = Vector2(maxf(head_min.x, column), head_min.y)
	_tools.position = Vector2(left, top + head_min.y + 9.0) if compact else Vector2(
		frame.x - tools_min.x - 32.0, top)
	_tools.size = tools_min
	var below := top + header_height + 12.0
	var spare := maxf(0.0, frame.y - below - body_min.y - 14.0)
	var body_top := below + minf(spare * 0.44, 24.0 if compact else 95.0)
	_body.position = Vector2(left, body_top)
	_body.size = Vector2(column, body_min.y)
	_fit_settings()


func _on_settings_child_entered(_child: Node) -> void:
	_fit_settings.call_deferred()


func _fit_settings() -> void:
	if not settings_panel.is_open() or size.x <= 0.0 or size.y <= 0.0:
		return
	var panels := settings_panel.find_children("*", "PanelContainer", true, false)
	if panels.is_empty():
		return
	var panel: PanelContainer = panels[0] as PanelContainer
	var bounds := panel.get_combined_minimum_size() + Vector2(38.0, 30.0)
	var factor := minf(maxf(1.0, _sheet.scale.x), minf(size.x / bounds.x, size.y / bounds.y))
	settings_panel.scale = Vector2.ONE * factor
	settings_panel.size = size / factor


func _wire_focus() -> void:
	var enabled: Array[Array] = []
	var sequence: Array[Button] = []
	for row: Array in _focus_rows:
		var open_row: Array[Button] = []
		for key: Button in row:
			if not key.disabled:
				open_row.append(key)
				sequence.append(key)
		if not open_row.is_empty():
			enabled.append(open_row)

	for y: int in enabled.size():
		var row: Array = enabled[y]
		var above: Array = enabled[posmod(y - 1, enabled.size())]
		var below: Array = enabled[(y + 1) % enabled.size()]
		for x: int in row.size():
			var key: Button = row[x]
			var left: Button = row[posmod(x - 1, row.size())]
			var right: Button = row[(x + 1) % row.size()]
			var up: Button = above[mini(x, above.size() - 1)]
			var down: Button = below[mini(x, below.size() - 1)]
			key.focus_neighbor_left = key.get_path_to(left)
			key.focus_neighbor_right = key.get_path_to(right)
			key.focus_neighbor_top = key.get_path_to(up)
			key.focus_neighbor_bottom = key.get_path_to(down)
	for i: int in sequence.size():
		var key: Button = sequence[i]
		key.focus_previous = key.get_path_to(sequence[posmod(i - 1, sequence.size())])
		key.focus_next = key.get_path_to(sequence[(i + 1) % sequence.size()])


func _set_menu_focus(enabled: bool) -> void:
	for row: Array in _focus_rows:
		for key: Button in row:
			if not key.disabled:
				key.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func _open_settings() -> void:
	_set_menu_focus(false)
	settings_panel.open()


func _on_settings_closed() -> void:
	_set_menu_focus(true)
	var button := _menu.find_child("OpenSettings", true, false) as Button
	if button != null:
		button.grab_focus()


func _credits(opened: bool) -> void:
	_in_credits = opened
	_rerender.call_deferred("" if opened else "Credits")


func _toggle_language() -> void:
	GameSession.set_language("en" if Loc.language == "zh" else "zh")


func _on_new_game() -> void:
	RunScript.pending_resume = {}
	RunScript.next_seed = 0
	_leave(RUN_SCENE)


func _on_daily() -> void:
	RunScript.pending_resume = {}
	RunScript.next_seed = Rules.daily_seed()
	_leave(RUN_SCENE)


func _on_continue() -> void:
	var state: Dictionary = Save.load_run()
	if state.is_empty():
		_rerender.call_deferred()
		return
	RunScript.pending_resume = state
	RunScript.next_seed = 0
	_leave(RUN_SCENE)


func _leave(path: String) -> void:
	music.halt()
	var err := get_tree().change_scene_to_file(path)
	if err == OK:
		return
	RunScript.pending_resume = {}
	RunScript.next_seed = 0
	music.start()
	Logger.error("cannot open relay run: %s" % error_string(err))
	_failed = true
	_rerender.call_deferred()


func _start_board() -> void:
	if not ToyBridge.available():
		if OS.has_feature("web") and _board_retry == null and _board_tries < 8:
			_board_tries += 1
			_board_retry = get_tree().create_timer(1.5)
			_board_retry.timeout.connect(_retry_board)
		return
	_board_tries = 0
	if _bridge == null:
		_bridge = ToyBridge.new()
		_bridge.name = "ToyBridge"
		add_child(_bridge)
		_bridge.ranks_ready.connect(_on_ranks)
	_bridge.probe_ranks(Rules.board_for(Rules.selected_mode), "day", 3)


func _retry_board() -> void:
	_board_retry = null
	if _bridge == null:
		_start_board()


func _on_ranks(rows: Array, mine: Dictionary) -> void:
	_board_rows = rows
	_board_mine = mine
	_refresh_today()


func _refresh_today() -> void:
	if is_instance_valid(_today):
		_today.text = _today_text(Loc.language == "zh")


func _today_text(zh: bool) -> String:
	var best: int = Rules.daily_best()
	var head := ("今日最佳 %d" if zh else "YOUR BEST %d") % best
	var lead := 0
	if not _board_rows.is_empty():
		var first: Dictionary = _board_rows[0]
		lead = int(first.get("score", 0))
	var rank: int = int(_board_mine.get("rank", 0))
	if rank > 0:
		head += (" · 今日第 %d 名" if zh else " · TODAY #%d") % rank
	if lead > 0:
		head += (" · 榜首 %d" if zh else " · LEADER %d") % lead
	return head


func _input(event: InputEvent) -> void:
	if not is_instance_valid(settings_panel):
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and (
			key.physical_keycode == KEY_F2 or key.keycode == KEY_F2):
		_toggle_language()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if settings_panel.is_open():
			settings_panel.close()
		elif _in_credits:
			_credits(false)
		else:
			return
		get_viewport().set_input_as_handled()


func _shoot_key(text: String, action: Callable, font_size: int, height: int) -> Button:
	var button := _key(text, action, font_size, height)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_stylebox_override("normal", UiKit.stock(Color("30231e"), UiKit.ACCENT, 4, 0))
	return button


func _draw_lock(tab: Button) -> void:
	var at := Vector2(tab.size.x * 0.5 + 31.0, tab.size.y * 0.5 + 9.0)
	tab.draw_arc(at, 2.0, PI, TAU, 8, UiKit.DIM, 1.0, true)
	tab.draw_rect(Rect2(at + Vector2(-3.0, 0.0), Vector2(6.0, 4.0)), UiKit.DIM, false, 1.0)


func _stamp(button: Button, text: String, ink: Color, width: float) -> void:
	var label := _print(text, 12, ink)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	label.offset_left = -width - 14.0
	label.offset_right = -14.0
	label.offset_top = -10.0
	label.offset_bottom = 10.0
	label.rotation_degrees = -1.3
	label.draw.connect(_draw_stamp.bind(label, ink))


func _draw_stamp(label: Label, ink: Color) -> void:
	label.draw_rect(Rect2(Vector2.ZERO, label.size), Color(ink, 0.46), false, 1.0)


func _key(text: String, action: Callable, font_size: int, height: int) -> Button:
	var button := UiKit.button(text, action, font_size)
	button.custom_minimum_size = Vector2(0.0, height)
	return button


func _print(text: String, font_size: int, ink: Color = UiKit.INK) -> Label:
	var label := UiKit.label(text, font_size, ink)
	label.add_theme_constant_override("outline_size", 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _rule(ink: Color, height: int) -> ColorRect:
	var rule := ColorRect.new()
	rule.color = ink
	rule.custom_minimum_size = Vector2(0.0, height)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


func _row(gap: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", gap)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row


func _column(gap: int) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", gap)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return column
