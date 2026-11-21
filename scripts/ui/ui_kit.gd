extends RefCounted
## UiKit — the few widgets every menu screen shares, built in code so the
## front end, pause menu and settings look like one product.

const INK := Color(0.95, 0.94, 0.90)
const DIM := Color(0.62, 0.62, 0.60)
const ACCENT := Color(0.886, 0.263, 0.180)  # film orange #E2432E
const PANEL_BG := Color(0.055, 0.06, 0.07, 0.96)
const SCRIM := Color(0.0, 0.0, 0.0, 0.62)


static func label(text: String, size: int = 20, color: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	return l


static func button(text: String, on_pressed: Callable, size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 46)
	b.add_theme_font_size_override("font_size", size)
	b.focus_mode = Control.FOCUS_ALL
	var normal := _box(Color(0.12, 0.125, 0.14, 0.95), Color(0.3, 0.3, 0.32))
	var hover := _box(Color(0.2, 0.2, 0.22, 0.98), ACCENT)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", _box(Color(0.886, 0.263, 0.180, 0.8), ACCENT))
	b.add_theme_stylebox_override("disabled", _box(Color(0.08, 0.08, 0.09, 0.9), Color(0.18, 0.18, 0.2)))
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.4, 0.42))
	b.pressed.connect(on_pressed)
	return b


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _box(PANEL_BG, Color(0.25, 0.25, 0.27))
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 26
	sb.content_margin_bottom = 26
	p.add_theme_stylebox_override("panel", sb)
	return p


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
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


## Focus the first enabled button below `root` (keyboard/gamepad users).
static func focus_first(root: Node) -> void:
	for c: Node in root.find_children("*", "BaseButton", true, false):
		var b := c as BaseButton
		if b.is_visible_in_tree() and not b.disabled:
			b.grab_focus()
			return
