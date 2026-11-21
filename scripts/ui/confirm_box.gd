extends Control
## ConfirmBox — a modal yes/no question. Caller supplies the message key; the
## box re-renders itself on a language switch.

signal answered(yes: bool)

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Loc = preload("res://scripts/core/loc.gd")

var message_key := ""
var _box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func ask(key: String) -> void:
	message_key = key
	_render()
	visible = true
	UiKit.focus_first(self)


func is_open() -> bool:
	return visible


func cancel() -> void:
	if visible:
		visible = false
		answered.emit(false)


func relocalize() -> void:
	if visible:
		_render()
		UiKit.focus_first(self)


func _render() -> void:
	UiKit.clear(self)
	add_child(UiKit.scrim())
	var p := UiKit.panel()
	UiKit.centered(self).add_child(p)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 22)
	p.add_child(_box)
	var msg := UiKit.label(Loc.ui(message_key), 22)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.custom_minimum_size = Vector2(560, 0)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(msg)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_box.add_child(row)
	# Cancel first: the safe answer is the one Enter hits by default.
	var no := UiKit.button(Loc.ui("confirm.no"), func() -> void: _answer(false))
	no.custom_minimum_size = Vector2(200, 46)
	row.add_child(no)
	var yes := UiKit.button(Loc.ui("confirm.yes"), func() -> void: _answer(true))
	yes.custom_minimum_size = Vector2(200, 46)
	row.add_child(yes)


func _answer(yes: bool) -> void:
	visible = false
	answered.emit(yes)
