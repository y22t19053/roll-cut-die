extends CanvasLayer
## PauseMenu — what ESC opens during a take. Runs while the tree is paused.
## It only asks; main decides (resume, leave to title, quit).

signal resume_requested
signal to_title_requested
signal quit_requested

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Loc = preload("res://scripts/core/loc.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
const ConfirmBox = preload("res://scripts/ui/confirm_box.gd")

var settings_panel: Control
var confirm: Control
var _root: Control
var _page: Control
var _pending := ""


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page = Control.new()
	_page.name = "Page"
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_page)
	_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_panel = SettingsPanel.new()
	settings_panel.name = "Settings"
	_root.add_child(settings_panel)
	settings_panel.closed.connect(_on_settings_closed)
	confirm = ConfirmBox.new()
	confirm.name = "Confirm"
	_root.add_child(confirm)
	confirm.answered.connect(_on_answer)
	visible = false


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true
	_render()


func close() -> void:
	settings_panel.visible = false
	_page.show()
	confirm.visible = false
	_pending = ""
	visible = false
	# A hidden focused button would still swallow arrows/Space (movement, retake).
	var f: Control = get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	if f != null and is_ancestor_of(f):
		f.release_focus()


## ESC while open. True when it only backed out of a sub-screen.
func back() -> bool:
	if confirm.is_open():
		confirm.cancel()
		return true
	if settings_panel.is_open():
		settings_panel.close()
		return true
	return false


func relocalize() -> void:
	if not visible:
		return
	if not settings_panel.is_open() and not confirm.is_open():
		_render.call_deferred()
	else:
		_render_page_only.call_deferred()
	confirm.relocalize()


func _render() -> void:
	_render_page_only()
	if not settings_panel.is_open() and not confirm.is_open():
		UiKit.focus_first(_page)


func _render_page_only() -> void:
	UiKit.clear(_page)
	_page.add_child(UiKit.scrim())
	var p := UiKit.panel()
	UiKit.centered(_page).add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	p.add_child(box)
	var zh: bool = Loc.language == "zh"
	box.add_child(UiKit.header_strip("拍摄暂停  //  片场挂起" if zh else "CALL SHEET  //  HOLD FOR WORK",
		"暂停场记" if zh else "HOLD FOR WORK", "STUDIO"))
	box.add_child(UiKit.button(Loc.ui("menu.resume"), func() -> void: resume_requested.emit()))
	box.add_child(UiKit.button(Loc.ui("menu.settings"), _open_settings))
	box.add_child(UiKit.button(Loc.ui("menu.to_title"), _ask.bind("to_title")))
	box.add_child(UiKit.button(Loc.ui("menu.quit"), _ask.bind("quit")))
	box.add_child(UiKit.rule())
	var hint := UiKit.label(Loc.ui("hint.paused"), 16, UiKit.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _open_settings() -> void:
	_page.hide()
	settings_panel.open()


func _on_settings_closed() -> void:
	_page.show()
	UiKit.focus_first(_page)


func _ask(what: String) -> void:
	_pending = what
	confirm.ask("confirm.quit" if what == "quit" else "confirm.to_title")


func _on_answer(yes: bool) -> void:
	var what := _pending
	_pending = ""
	if not yes:
		UiKit.focus_first(_page)
		return
	if what == "quit":
		quit_requested.emit()
	elif what == "to_title":
		to_title_requested.emit()
