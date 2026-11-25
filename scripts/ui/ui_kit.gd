extends RefCounted
## Shared typography and printed-stock controls for the studio menus.

const INK := Color("f4efe4")
const DIM := Color("9e9688")
const ACCENT := Color("e2432e")
const PANEL_BG := Color(0.08, 0.08, 0.085, 0.97)
const SCRIM := Color(0.0, 0.0, 0.0, 0.62)
const RULE := Color("3a3630")
const CARBON := Color("18191c")
const PAPER := Color("eee5cb")
const AMBER := Color("efb36a")
const MINT := Color("93cec0")
const PRINT_FONT_PATH := "res://assets/fonts/RCD-Noto.otf"

static var _print_font: Font


static func print_font() -> Font:
	if _print_font != null:
		return _print_font
	var import_info := ConfigFile.new()
	var can_load := ResourceLoader.exists(PRINT_FONT_PATH, "FontFile")
	if import_info.load(PRINT_FONT_PATH + ".import") == OK:
		var imported_path: String = str(import_info.get_value("remap", "path", ""))
		can_load = can_load and FileAccess.file_exists(imported_path)
	if can_load:
		_print_font = ResourceLoader.load(PRINT_FONT_PATH, "FontFile") as Font
	if _print_font == null and FileAccess.file_exists(PRINT_FONT_PATH):
		var disk_font := FontFile.new()
		if disk_font.load_dynamic_font(PRINT_FONT_PATH) == OK:
			_print_font = disk_font
	if _print_font == null:
		var system_font := SystemFont.new()
		system_font.font_names = PackedStringArray(["Consolas", "Microsoft YaHei UI", "Noto Sans CJK SC"])
		_print_font = system_font
	return _print_font


static func label(text: String, size: int = 20, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", print_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 2)
	return l


static func button(text: String, on_pressed: Callable, size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", print_font())
	b.custom_minimum_size = Vector2(320, 46)
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", stock(CARBON, RULE))
	b.add_theme_stylebox_override("hover", stock(Color("322824"), ACCENT, 4))
	b.add_theme_stylebox_override("focus", stock(Color.TRANSPARENT, AMBER, 1))
	b.add_theme_stylebox_override("pressed", stock(Color("422923"), ACCENT, 4))
	b.add_theme_stylebox_override("hover_pressed", stock(Color("503029"), ACCENT, 4))
	b.add_theme_stylebox_override("disabled", stock(Color("1b1a19"), RULE))
	for state: String in ["font_color", "font_hover_color", "font_focus_color",
			"font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, INK)
	b.add_theme_color_override("font_disabled_color", DIM)
	if on_pressed.is_valid():
		b.pressed.connect(on_pressed)
	return b


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := stock(PANEL_BG, RULE)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	p.add_theme_stylebox_override("panel", sb)
	return p


static func stock(bg: Color, border: Color, edge: int = 1, rule: int = 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(rule)
	sb.border_width_left = edge
	sb.set_corner_radius_all(1)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


## Full-rect dimmer that swallows mouse input under a modal.
static func scrim() -> ColorRect:
	var c := ColorRect.new()
	c.color = SCRIM
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


static func centered(parent: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


static func clear(node: Node) -> void:
	for c: Node in node.get_children():
		node.remove_child(c)
		c.queue_free()


## Focus the first enabled button below the given menu.
static func focus_first(root: Node) -> void:
	for c: Node in root.find_children("*", "BaseButton", true, false):
		var b := c as BaseButton
		if b.is_visible_in_tree() and not b.disabled and b.focus_mode != Control.FOCUS_NONE:
			b.grab_focus()
			return


static func header_strip(slug: String, title_text: String, stamp_text := "") -> Control:
	var strip := PanelContainer.new()
	var style := stock(CARBON, RULE, 0)
	style.content_margin_top = 7
	style.content_margin_bottom = 8
	style.border_width_bottom = 2
	style.border_color = ACCENT.darkened(0.30)
	strip.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	strip.add_child(column)
	column.add_child(label(slug, 13, AMBER))
	var row := HBoxContainer.new()
	column.add_child(row)
	var title := label(title_text, 27)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	if not stamp_text.is_empty():
		row.add_child(label(stamp_text, 14, MINT))
	return strip


static func rule() -> ColorRect:
	var divider := ColorRect.new()
	divider.color = RULE
	divider.custom_minimum_size.y = 1
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return divider


static func style_slider(s: HSlider) -> void:
	var track := stock(RULE, RULE, 0, 0)
	var fill := stock(AMBER, AMBER, 0, 0)
	for style: StyleBoxFlat in [track, fill]:
		style.content_margin_top = 2
		style.content_margin_bottom = 2
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	var active := fill.duplicate() as StyleBoxFlat
	active.bg_color = ACCENT
	s.add_theme_stylebox_override("grabber_area_highlight", active)
	var handle := GradientTexture2D.new()
	handle.width = 9
	handle.height = 18
	handle.gradient = Gradient.new()
	handle.gradient.colors = PackedColorArray([PAPER, PAPER])
	s.add_theme_icon_override("grabber", handle)
	s.add_theme_icon_override("grabber_highlight", handle)
	s.add_theme_stylebox_override("focus", stock(Color.TRANSPARENT, AMBER, 1))
