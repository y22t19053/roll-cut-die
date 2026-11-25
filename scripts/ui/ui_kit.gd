extends RefCounted
## Shared typography and printed-stock controls for the studio menus.

const INK := Color("f4efe4")
const DIM := Color("9e9688")
const ACCENT := Color("e2432e")
const PANEL_BG := Color(0.08, 0.08, 0.085, 0.97)
const SCRIM := Color(0.0, 0.0, 0.0, 0.62)
const RULE := Color("3a3630")


static func label(text: String, size: int = 20, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 2)
	return l


static func button(text: String, on_pressed: Callable, size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 46)
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", stock(Color("23211e"), RULE))
	b.add_theme_stylebox_override("hover", stock(Color("322824"), ACCENT, 4))
	b.add_theme_stylebox_override("focus", stock(Color.TRANSPARENT, ACCENT, 4, 2))
	b.add_theme_stylebox_override("pressed", stock(Color("482923"), ACCENT, 4))
	b.add_theme_stylebox_override("hover_pressed", stock(Color("54312a"), ACCENT, 4))
	b.add_theme_stylebox_override("disabled", stock(Color("1b1a19"), RULE))
	for state: String in ["font_color", "font_hover_color", "font_focus_color",
			"font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(state, INK)
	b.add_theme_color_override("font_disabled_color", DIM)
	b.pressed.connect(on_pressed)
	return b


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := stock(PANEL_BG, RULE, 1, 2)
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
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
