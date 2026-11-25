extends CanvasLayer
## CutPanel — the timeline the player picks a CUT point from.
##
## A read-out like the HUD: the scene hands it finished strings and a selected
## row; the panel never touches game state. One row per point, the selected row
## gets a highlight bar and a ">" so it reads without colour too.

const UiKit = preload("res://scripts/ui/ui_kit.gd")

const ROW_H := 30.0
const WIDTH := 860.0
const HIGHLIGHT := Color("503029")

var title_label: Label
var footer_label: Label
var row_labels: Array = []
var selected := -1

var _root: Control
var _bg: ColorRect
var _bar: ColorRect
var _rule: ColorRect
var _rows: PackedStringArray = PackedStringArray()


func _ready() -> void:
	layer = 25
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_bg = ColorRect.new()
	_bg.color = Color("18191cf2")
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bg)

	_bar = ColorRect.new()
	_bar.color = HIGHLIGHT
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.visible = false
	_root.add_child(_bar)
	var edge := ColorRect.new()
	edge.color = UiKit.ACCENT
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(edge)
	edge.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	edge.offset_right = 3
	_rule = UiKit.rule()
	_rule.color = UiKit.ACCENT.darkened(0.30)
	_bg.add_child(_rule)
	_rule.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_rule.offset_bottom = 1

	title_label = _mk(22)
	title_label.add_theme_color_override("font_color", UiKit.AMBER)
	footer_label = _mk(16)
	visible = false


func _mk(fsize: int) -> Label:
	var l := UiKit.label("", fsize)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	_root.add_child(l)
	return l


func is_open() -> bool:
	return visible


func open(title: String, rows: PackedStringArray, footer: String) -> void:
	title_label.text = title
	footer_label.text = footer
	_rows = rows
	selected = -1
	_layout()
	visible = true


func close() -> void:
	visible = false
	selected = -1


func set_footer(text: String) -> void:
	footer_label.text = text


## Re-word an open panel (language switch) without moving the selection.
func retext(title: String, rows: PackedStringArray, footer: String) -> void:
	title_label.text = title
	footer_label.text = footer
	if rows.size() == _rows.size():
		_rows = rows
	_layout()


func set_selected(i: int) -> void:
	selected = i if i >= 0 and i < _rows.size() else -1
	_layout()


## What the panel shows right now, line by line (tests read this).
func lines() -> PackedStringArray:
	var out := PackedStringArray([title_label.text])
	for l: Label in row_labels:
		out.append(l.text)
	out.append(footer_label.text)
	return out


func _layout() -> void:
	while row_labels.size() < _rows.size():
		row_labels.append(_mk(18))
	var top := 110.0
	_place(title_label, top, 34.0)
	var y := top + 46.0
	for i in row_labels.size():
		var l: Label = row_labels[i]
		l.visible = i < _rows.size()
		if not l.visible:
			continue
		l.text = ("> " if i == selected else "  ") + "[%d] %s" % [i + 1, _rows[i]]
		_place(l, y, ROW_H)
		if i == selected:
			_bar.visible = true
			_bar.anchor_left = 0.5
			_bar.anchor_right = 0.5
			_bar.offset_left = -WIDTH * 0.5 + 8.0
			_bar.offset_right = WIDTH * 0.5 - 8.0
			_bar.offset_top = y - 2.0
			_bar.offset_bottom = y + ROW_H - 2.0
		y += ROW_H
	if selected < 0:
		_bar.visible = false
	_place(footer_label, y + 12.0, 48.0)
	_bg.anchor_left = 0.5
	_bg.anchor_right = 0.5
	_bg.offset_left = -WIDTH * 0.5
	_bg.offset_right = WIDTH * 0.5
	_bg.offset_top = top - 14.0
	_bg.offset_bottom = y + 68.0


func _place(l: Label, y: float, h: float) -> void:
	l.offset_left = -WIDTH * 0.5 + 18.0
	l.offset_right = WIDTH * 0.5 - 18.0
	l.offset_top = y
	l.offset_bottom = y + h
