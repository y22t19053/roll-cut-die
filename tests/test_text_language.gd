extends RefCounted
## The runtime half of the language rule: an English build shows no Chinese at
## all, and whatever a label shows, its own font can draw. The static half is
## tools/check_text_language.py — that one reads the source, this one reads the
## screens, including the text a desk draws by hand instead of in a Label.

const Harness = preload("res://tests/harness.gd")
const Loc = preload("res://scripts/core/loc.gd")
const RelaySave = preload("res://scripts/relay/relay_save.gd")


static func run(h: Harness, tree: SceneTree = null) -> void:
	h.begin("text_language")
	var session: Variant = tree.root.get_node("GameSession")
	var prior := Loc.language
	var prior_save := RelaySave.save_path
	RelaySave.save_path = "user://rcd_test_saves/text_language_%s.json" % Crypto.new().generate_random_bytes(8).hex_encode()

	_switch(session, "en")
	await _check_title(h, tree)
	await _check_run(h, tree, session)

	_switch(session, "zh")
	await _check_chinese_survives(h, tree)

	_switch(session, prior)
	RelaySave.save_path = prior_save
	h.finish()


static func _switch(session: Node, lang: String) -> void:
	Loc.set_language(lang)
	session.emit_signal("language_changed", lang)


## UI node text and the custom-drawn text exposed by the slate and cutting desk.
static func spoken(root: Node) -> Array[String]:
	var found: Array[String] = []
	_walk(root, found)
	return found


static func _walk(node: Node, found: Array[String]) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree():
		return
	if node.is_queued_for_deletion():
		return
	for prop: String in ["text", "tooltip_text", "placeholder_text"]:
		if node.has_method("get") and prop in node:
			var value: Variant = node.get(prop)
			if value is String and not (value as String).is_empty():
				found.append(value as String)
	if node is PopupMenu:
		var menu := node as PopupMenu
		for i: int in menu.item_count:
			found.append(menu.get_item_text(i))
	if node is ItemList:
		var list := node as ItemList
		for i: int in list.item_count:
			found.append(list.get_item_text(i))
	if node is TabBar:
		var bar := node as TabBar
		for i: int in bar.tab_count:
			found.append(bar.get_tab_title(i))
	# The cutting desk paints its own paper: these fields are exactly what its
	# _draw would put on screen, so reading them is the same as looking at it.
	if node.has_method("show_message") and node.has_method("show_call_sheet"):
		for prop: String in ["_message", "_sheet_title"]:
			var text: Variant = node.get(prop)
			if text is String and not (text as String).is_empty():
				found.append(text as String)
		var lines: Variant = node.get("_sheet_lines")
		if lines is Array:
			for line: Variant in lines:
				if line is String:
					found.append(line as String)
		var cards: Variant = node.get("_cards")
		if cards is Array:
			for card: Variant in cards:
				if card is Dictionary:
					for key: String in ["title", "name", "line", "line1", "line2", "stamp"]:
						if (card as Dictionary).has(key):
							found.append(str((card as Dictionary)[key]))
	for child: Node in node.get_children():
		_walk(child, found)


## The first offence is worth quoting: it names the screen and the string.
static func offence(lines: Array[String]) -> String:
	for line: String in lines:
		if _has_chinese(line):
			return line.strip_edges().replace("\n", " / ").substr(0, 90)
	return ""


static func _has_chinese(text: String) -> bool:
	# Code points, not a regex escape: \u ranges mean different things to
	# different engines, and a test that silently matches nothing is worse than
	# no test at all.
	for i: int in text.length():
		if _is_chinese(text.unicode_at(i)):
			return true
	return false


static func _is_chinese(c: int) -> bool:
	return (c >= 0x3400 and c <= 0x4dbf) or (c >= 0x4e00 and c <= 0x9fff) \
		or (c >= 0xf900 and c <= 0xfaff)


static func _no_chinese(h: Harness, where: String, lines: Array[String]) -> void:
	var bad := offence(lines)
	h.ok("English %s has no Chinese" % where, bad == "",
		("saw " + bad) if bad != "" else "")


static func _check_title(h: Harness, tree: SceneTree) -> void:
	var packed := load("res://scenes/front/title.tscn") as PackedScene
	h.ok("title scene loads", packed != null)
	if packed == null:
		return
	var inst: Variant = packed.instantiate()
	tree.root.add_child(inst)
	await tree.process_frame
	await tree.process_frame
	var lines := spoken(inst)
	h.at_least("English title speaks", lines.size(), 12)
	_no_chinese(h, "title screen", lines)
	inst.queue_free()
	await tree.process_frame


static func _check_run(h: Harness, tree: SceneTree, session: Node) -> void:
	var packed := load("res://scenes/relay/run.tscn") as PackedScene
	h.ok("relay run scene loads", packed != null)
	if packed == null:
		return
	var inst: Variant = packed.instantiate()
	tree.root.add_child(inst)
	await tree.process_frame
	await tree.process_frame

	_no_chinese(h, "relay opening", spoken(inst))

	# The pause menu and its settings page are the two screens a player opens
	# without being told to, and the settings page owns the key ledger.
	inst._open_pause()
	await tree.process_frame
	_no_chinese(h, "pause menu", spoken(inst))
	inst.pause_ui._open_settings()
	await tree.process_frame
	await tree.process_frame
	var settings_lines := spoken(inst)
	h.at_least("English settings page speaks", settings_lines.size(), 12)
	_no_chinese(h, "settings page", settings_lines)
	var settings: Variant = inst.pause_ui.get_node("Settings")
	for tab: String in ["controls", "audio", "video"]:
		settings._pick_tab(tab)
		await tree.process_frame
		await tree.process_frame
		var page := spoken(settings._page)
		h.at_least("English %s settings content is visible" % tab, page.size(), 2)
		_no_chinese(h, "%s settings" % tab, page)
		if tab == "controls":
			h.ok("controls exposes its language hotkey", page.has("F2") and page.has("LANGUAGE"))
	settings.close()
	inst.pause_ui.close()
	await tree.process_frame

	_switch(session, "zh")
	inst.phase = inst.Mode.ACT
	inst.cards = inst._offer_contracts()
	inst.desk.show_draw(inst.cards, true)
	inst.desk.show_message(inst._w("正在拍摄", "Filming"))
	h.ok("Chinese contracts are present before switching", offence(spoken(inst)) != "")
	_switch(session, "en")
	h.eq("existing contract is retranslated", inst.cards[0]["title"], "RUSH")
	h.eq("old-language notice is cleared", inst.desk._message, "")
	_no_chinese(h, "contracts after live language switch", spoken(inst))
	inst.desk.hide_draw()
	# Exercise the result renderer without touching the user's career ledger or
	# leaderboard. The actual settlement side effects are covered elsewhere.
	inst._recorded = true
	if inst._is_daily():
		inst.run_seed += 1

	# The desk writes the run's own notices; drive the ones a run really emits.
	for notice: Array in [
			["你踩进了画面", "CUT BACK TO MARK"],
			["没看见你。", "The dolly did not see you."],
			["撞上旧条里的人。", "You hit the past take."],
			["没事发生。", "Nothing happened."]]:
		inst.desk.show_message(inst._w(notice[0], notice[1]), 3.0)
		await tree.process_frame
		_no_chinese(h, "desk notice", spoken(inst))

	# Winning plays the final cut first and hands the screen back to the call
	# sheet afterwards, so walk the wrap beat by beat and check the sheet that
	# the wrap returns to.
	inst.deaths = 0
	inst._show_sheet(true)
	for i: int in 3:
		await tree.process_frame
	if inst._final_cut != null:
		for beat: int in 6:
			inst._final_cut.advance(1.6)
			await tree.process_frame
			_no_chinese(h, "final cut beat %d" % beat, spoken(inst))
		inst._final_cut.advance(6.0)
		for i: int in 3:
			await tree.process_frame
		_no_chinese(h, "final cut end card", spoken(inst))

	var win_lines := spoken(inst)
	_no_chinese(h, "victory call sheet", win_lines)
	# A collector that quietly found nothing would pass every language check on
	# this screen. Pin one string the sheet is known to print.
	var stamped := false
	for line: String in win_lines:
		if line.contains("ANSWER PRINT"):
			stamped = true
	h.ok("the victory sheet is collected, not just empty", stamped)

	# Losing the reel still has to speak English: this is the screen a player
	# sees most often, and the one most likely to keep a hard-coded Chinese line.
	inst.deaths = 2
	inst._show_sheet(false)
	for i: int in 6:
		await tree.process_frame
	_no_chinese(h, "NG call sheet", spoken(inst))
	_switch(session, "zh")
	h.ok("result sheet switches to Chinese", offence(spoken(inst)) != "")
	_switch(session, "en")
	h.eq("existing loss sheet is retranslated", inst.desk._sheet_title, "END OF REEL")
	_no_chinese(h, "loss sheet after live language switch", spoken(inst))

	inst.queue_free()
	await tree.process_frame
	await tree.process_frame


static func _check_case(h: Harness, tree: SceneTree) -> void:
	var packed := load("res://scenes/main/main.tscn") as PackedScene
	h.ok("case scene loads", packed != null)
	if packed == null:
		return
	var inst: Variant = packed.instantiate()
	tree.root.add_child(inst)
	for i: int in 4:
		await tree.process_frame
	_no_chinese(h, "case scene", spoken(inst))
	inst.queue_free()
	await tree.process_frame
	await tree.process_frame


## A Chinese build is allowed its English jargon, but it must still be Chinese,
## and every label that holds a Chinese character must sit on a font that has
## that character — otherwise the line renders as empty boxes.
static func _check_chinese_survives(h: Harness, tree: SceneTree) -> void:
	var packed := load("res://scenes/front/title.tscn") as PackedScene
	if packed == null:
		return
	var inst: Variant = packed.instantiate()
	tree.root.add_child(inst)
	await tree.process_frame
	await tree.process_frame
	var lines := spoken(inst)
	var chinese := 0
	for line: String in lines:
		if _has_chinese(line):
			chinese += 1
	h.at_least("Chinese title still speaks Chinese", chinese, 3)
	var tofu := _missing_glyphs(inst)
	h.ok("every Chinese label sits on a font that can draw it", tofu == "",
		("tofu on " + tofu) if tofu != "" else "")
	inst.queue_free()
	await tree.process_frame


static func _missing_glyphs(root: Node) -> String:
	if root is CanvasItem and not (root as CanvasItem).is_visible_in_tree():
		return ""
	if root.is_queued_for_deletion():
		return ""
	if root is Control and "text" in root:
		var text := str(root.get("text"))
		var found := _tofu_in(root as Control, text)
		if found != "":
			return found
	for child: Node in root.get_children():
		var deeper := _missing_glyphs(child)
		if deeper != "":
			return deeper
	return ""


static func _tofu_in(control: Control, text: String) -> String:
	if not _has_chinese(text):
		return ""
	var font := control.get_theme_font("font")
	if font == null:
		return ""
	for i: int in text.length():
		var c := text.unicode_at(i)
		if _is_chinese(c) and not font.has_char(c):
			return "%s [%s]" % [text.strip_edges().substr(0, 40), control.name]
	return ""
