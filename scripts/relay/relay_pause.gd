extends CanvasLayer
## ESC in the middle of a run. Nothing here touches the run: it stops the clock,
## offers the two switches a person actually reaches for mid-take (motion and
## language), and gets out of the way again.
##
## Deliberately small. There is no save button because the run saves itself
## between sets, and no difficulty switch because that is the door you signed.

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const Loc = preload("res://scripts/core/loc.gd")

signal resumed()
signal left_run()

var is_open := false
## Filled by the run before opening: the sheet you would want to glance at.
var briefing := {}

var _dim: ColorRect
var _col: VBoxContainer

func _ready() -> void:
	layer = 24
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.024, 0.026, 0.72)
	_dim.anchor_right = 1.0
	_dim.anchor_bottom = 1.0
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	var centre := CenterContainer.new()
	centre.anchor_right = 1.0
	centre.anchor_bottom = 1.0
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)
	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 12)
	_col.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_child(_col)
	refresh()

## Rebuilt on open and on language change, so the labels are never stale.
func refresh() -> void:
	for c in _col.get_children(): c.queue_free()
	var zh: bool = Loc.language == "zh"
	var head := UiKit.label("暂停" if zh else "PAUSED", 30, UiKit.INK)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_col.add_child(head)
	# Where you are, in the same words the HUD uses. A pause screen that only
	# says "paused" wastes the one moment the player is looking for information.
	if not briefing.is_empty():
		var where := ("棚 %02d / %d　　过线 %d / %d" if zh else "SET %02d / %d　　LINE %d / %d") % [
			int(briefing.get("set", 1)), int(briefing.get("sets", 1)),
			int(briefing.get("pass", 1)), int(briefing.get("passes", 1))]
		var seed_line := ("种子 %06X　　死亡 %d" if zh else "SEED %06X　　DEATHS %d") % [
			int(briefing.get("seed", 0)), int(briefing.get("deaths", 0))]
		for text: String in [where, seed_line]:
			var info := UiKit.label(text, 16, UiKit.DIM)
			info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_col.add_child(info)
	_col.add_child(_row("继续这一条" if zh else "Back to the take", _resume))
	var motion_on: bool = bool(GameSession.settings.get("reduce_motion", false))
	_col.add_child(_row(("减弱动态效果：%s" % ("开" if motion_on else "关")) if zh else ("REDUCE MOTION: %s" % ("ON" if motion_on else "OFF")), _toggle_motion))
	_col.add_child(_row(("语言：中文" if zh else "LANGUAGE: English"), _toggle_language))
	_col.add_child(_row("回到标题" if zh else "Back to the title", _leave))

func _row(text: String, cb: Callable) -> Button:
	var b := UiKit.button(text, cb)
	b.custom_minimum_size = Vector2(360, 52)
	return b

func open() -> void:
	if is_open: return
	is_open = true
	visible = true
	refresh()
	get_tree().paused = true

func close() -> void:
	if not is_open: return
	is_open = false
	visible = false
	get_tree().paused = false

func _resume() -> void:
	close()
	resumed.emit()

func _toggle_motion() -> void:
	var on: bool = not bool(GameSession.settings.get("reduce_motion", false))
	GameSession.set_setting("reduce_motion", on)
	GameSession.save_preferences()
	refresh()

func _toggle_language() -> void:
	Loc.set_language("en" if Loc.language == "zh" else "zh")
	GameSession.set_language(Loc.language)
	refresh()
	left_run_keep_open()

## The parent picks this up to re-render its own text after a language swap.
func left_run_keep_open() -> void:
	if is_open: visible = true

func _leave() -> void:
	close()
	left_run.emit()
