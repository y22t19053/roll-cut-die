extends CanvasLayer
## Participant and operator controls. No text entry, clipboard, OS hooks or storage.
signal agreed
signal declined
var _panel: ColorRect
var _box: VBoxContainer
var _heading: Label
var _copy: Label
var _buttons: HBoxContainer
var _badge: Label
var _state := "choice"

func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = ColorRect.new()
	_panel.color = Color("15191e")
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_panel.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 18)
	center.add_child(_box)
	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", 30)
	_box.add_child(_heading)
	_copy = Label.new()
	_copy.add_theme_font_size_override("font_size", 19)
	_box.add_child(_copy)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 16)
	_box.add_child(_buttons)
	_add_button("同意，等待主持人  /  Agree and wait", func(): agreed.emit())
	_add_button("无采集试玩  /  Play without recording", func(): declined.emit())
	_badge = Label.new()
	_badge.position = Vector2(12, 80)
	_badge.add_theme_color_override("font_outline_color",Color.BLACK)
	_badge.add_theme_constant_override("outline_size",5)
	add_child(_badge)
	_heading.text = "是否参加本地试玩记录？  /  Allow local trial recording?"
	_copy.text = "自愿参加；不参加也能玩相同游戏。不会写入正式存档。\nParticipation is optional. The same game is available without recording or saving progress.\n\n记录随机场次号、实验版本、相对时间、移动及互动按键的按下与松开、\n角色位置、镜头、碰墙和结果，供主持人在本机离线分析。最长 5 分钟。\nWe record a random session ID, build, elapsed time, movement/interact key transitions,\nposition, camera, wall contact and outcome for local offline analysis (up to 5 minutes).\n\n不采集姓名、输入文本、画面或声音，不联网。选同意后仍需主持人按 F8。\nNo names, typed text, screen or audio capture, or uploads. F8 starts after consent.\nF9 需提示／F10 随时停止；切换窗口即结束。结束前已记录的数据保留。\nF9: help needed. F10: stop anytime. Leaving the window ends recording; prior rows remain."

func _add_button(text: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(callback)
	_buttons.add_child(b)

func waiting(id: String) -> void:
	_state = "waiting"
	_heading.text = "等待主持人  /  Waiting for operator"
	_copy.text = "匿名场次  /  Anonymous session\n%s\n\n尚未记录。请松开移动键，回到游戏窗口并按 F8 开始。\nNot recording. Release movement keys, focus the game and press F8.\n也可改选无采集试玩。 / You can still play without recording." % id
	_buttons.get_child(0).hide()

func unavailable() -> void:
	_state = "invalid"
	_heading.text = "记录不可用  /  Recording unavailable"
	_copy.text = "无法验证隔离目录或构建信息，或无法打开新文件。\nCould not verify isolation/build or open a new file. Use unrecorded play."
	_buttons.get_child(0).hide()

func play(status: String) -> void:
	_state = "play"
	_panel.hide()
	_badge.text = status

func _input(event: InputEvent) -> void:
	# Suppress gameplay shortcuts (including pause/resume) behind the consent page.
	# Buttons remain mouse accessible; Tab, Space and Enter remain GUI-accessible.
	if _state != "play" and event is InputEventKey and event.physical_keycode not in [KEY_F8, KEY_TAB, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
