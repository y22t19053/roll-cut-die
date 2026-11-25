extends CanvasLayer
## Film edge numbers, splice tickets and the paperwork handled between takes.
signal picked(index: int)
const UiKit = preload("res://scripts/ui/ui_kit.gd")
const PAPER := UiKit.PAPER
const CARBON := UiKit.CARBON
const CHALK := UiKit.INK
const ACCENT := UiKit.ACCENT
const PAPER_RULE := Color("b8b09a")
const STAMP_RED := Color("8c2f22")
const INK := Color("222321")
const AMBER := Color("efb36a")
const MINT := Color("93cec0")
var _sheet: Sheet
var _zh := false
var _room := 1
var _rooms := 1
var _pass := 1
var _passes := 1
var _marks := 0
var _cuts := 0
var _splice := false
var _items := false
var _cards := []
var _message := ""
var _message_on_sheet := false
var _remaining := 0.0
var _result := -1
var _sheet_title := ""
var _sheet_lines: Array = []
var _sheet_won := true
var _age := 0.0
var _hover := -1
var _font: Font
var _cut_preview: Dictionary = {}
## Scale for the four HUD numbers only (D-049): 0.8 … 1.5 in the pause menu.
var _hud := 1.0

func set_hud_scale(v: float) -> void:
	var scale := clampf(v, 0.8, 1.5)
	if not is_equal_approx(scale, _hud):
		_hud = scale
		_refresh()


func _ready() -> void:
	layer = 12
	_font = UiKit.print_font()
	if _font == null:
		_font = SystemFont.new()
	_sheet = Sheet.new()
	_sheet.owner_desk = self
	add_child(_sheet)
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sheet.resized.connect(_sheet.queue_redraw)
	_hud = clampf(float(GameSession.settings.get("hud_scale", 1.0)), 0.8, 1.5)
	_refresh()


func _refresh() -> void:
	if _sheet == null:
		return
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE if _cards.is_empty() else Control.MOUSE_FILTER_STOP
	_sheet.queue_redraw()


func update_run(room: int, total: int, pass_no: int, pass_total: int, mark_stock: int, cut_stock: int, splice: bool, zh: bool) -> void:
	if [_room, _rooms, _pass, _passes, _marks, _cuts, _splice, _zh] == [room, total, pass_no, pass_total, mark_stock, cut_stock, splice, zh]:
		return
	_room = room
	_rooms = total
	_pass = pass_no
	_passes = pass_total
	_marks = mark_stock
	_cuts = cut_stock
	_splice = splice
	_zh = zh
	_refresh()


func show_draw(cards: Array, zh: bool) -> void:
	_open_picker(cards.slice(0, 3), zh, false)


## Shares picked(index) with the map picker: 0 splice, 1 MARK, 2 CUT.
func show_items(zh: bool) -> void:
	_open_picker(["splice", "mark", "cut"], zh, true)


func _open_picker(cards: Array, zh: bool, items: bool) -> void:
	_items = items
	_zh = zh
	_result = -1
	_cards = cards
	_hover = 0
	_refresh()


func set_cut_preview(info: Dictionary, zh: bool) -> void:
	_cut_preview = info.duplicate()
	_zh = zh
	_refresh()


func hide_cut_preview() -> void:
	if not _cut_preview.is_empty():
		_cut_preview.clear()
		_refresh()


func show_message(text: String, seconds := 3.0, on_sheet := false) -> void:
	_message_on_sheet = on_sheet
	_message = text
	_remaining = seconds
	_refresh()


func show_result(won: bool, zh: bool) -> void:
	_zh = zh
	_result = int(won)
	_cards.clear()
	_age = 0.0
	_sheet_lines = []
	_refresh()


## The seed is on the sheet so two runs can be compared and replayed.
func show_call_sheet(title: String, lines: Array, won: bool, zh: bool) -> void:
	_zh = zh
	_sheet_title = title
	_sheet_lines = lines
	_sheet_won = won
	_cards.clear()
	_items = false
	_result = -1
	_refresh()


func hide_draw() -> void:
	_cards.clear()
	_hover = -1
	_refresh()


## The leaderboard can answer after the sheet is already on screen.
func append_sheet_lines(more: Array) -> void:
	if not more.is_empty():
		_sheet_lines.append_array(more)
		_refresh()


func clear_sheet() -> void:
	if not _sheet_title.is_empty() or not _sheet_lines.is_empty():
		_sheet_title = ""
		_sheet_lines = []
		_refresh()


func _process(delta: float) -> void:
	if _remaining > 0.0:
		_remaining -= delta
		if _remaining <= 0.0:
			_refresh()
	if _age < 0.5 and _result >= 0:
		_age += delta
		_refresh()


func _pick(i: int) -> void:
	if i >= 0 and i < _cards.size():
		hide_draw()
		picked.emit(i)


func _input(e: InputEvent) -> void:
	if _cards.is_empty() or not e is InputEventKey or not e.pressed or e.echo:
		return
	var key: int = e.physical_keycode if e.physical_keycode != KEY_NONE else e.keycode
	var keys := [KEY_1, KEY_2, KEY_3, KEY_KP_1, KEY_KP_2, KEY_KP_3]
	var index: int = keys.find(key)
	if index >= 0:
		get_viewport().set_input_as_handled()
		_pick(index % 3)
		return
	match key:
		KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D:
			get_viewport().set_input_as_handled()
			var step := -1 if key == KEY_LEFT or key == KEY_A else 1
			_hover = posmod(_hover + step, _cards.size())
			_refresh()
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			_pick(_hover)


class Sheet extends Control:
	var owner_desk
	const CARD_TILTS := [-0.009, 0.009, -0.010]
	var s:=1.0
	var w:=1.0
	var h:=1.0
	func _layout() -> void:
		s=clampf(minf(size.x/730.0,size.y/430.0),0.1,1.5)
		w=size.x/s; h=size.y/s
	func rect(x:float,y:float,b:float,d:float,c:Color) -> void:
		draw_rect(Rect2(x,y,b,d),c)
	func text(x:float,y:float,t:String,fs:int,c:Color) -> void:
		draw_string(owner_desk._font,Vector2(x,y),t,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,c)
	func word(zh:String,en:String) -> String: return zh if owner_desk._zh else en
	func card(i:int) -> Rect2:
		var n:int=owner_desk._cards.size()
		return Rect2(w*0.5-n*103+i*206+5,h*0.5-94,196,188)
	func _gui_input(e:InputEvent) -> void:
		if owner_desk._cards.is_empty():return
		if not (e is InputEventMouseMotion or e is InputEventMouseButton): return
		_layout()
		var idx:=-1
		for i in owner_desk._cards.size():
			if card(i).has_point(e.position/s): idx=i
		if idx>=0 and idx!=owner_desk._hover:
			owner_desk._hover=idx; queue_redraw()
		if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:
			accept_event(); owner_desk._pick(idx)
	func _draw() -> void:
		_layout()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * s)
		var d = owner_desk
		if bool(d._cut_preview.get("active", false)):
			draw_loupe(d._cut_preview)
			return
		draw_run_header()
		if not d._cards.is_empty():
			draw_picker()
		elif not d._sheet_lines.is_empty():
			draw_call_sheet()
			if d._message_on_sheet and d._remaining > 0:
				draw_notice(d._message)
		elif d._result >= 0:
			var x := w * 0.5 - 192
			var y := h * 0.5 - 60
			rect(x, y, 384, 120, CARBON)
			var accent := MINT if d._result == 1 else ACCENT
			rect(x, y, 384 * minf(d._age / 0.36, 1.0), 4, accent)
			text(x + 22, y + 39, "35 MM  //  " + ("ANSWER PRINT" if d._result == 1 else "OUTTAKE"), 16, accent)
			text(x + 22, y + 89, word("当天收工", "WRAPPED") if d._result == 1 else word("这卷到头了", "END OF REEL"), 30, CHALK)
		elif d._remaining > 0 and not d._message.is_empty():
			draw_notice(d._message)

	func width(t: String, fs: int) -> float:
		return owner_desk._font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

	func hairline(x: float, y: float, end: float, ink: Color) -> void:
		draw_line(Vector2(x, y), Vector2(end, y), ink, 1.0)

	func draw_run_header() -> void:
		var d = owner_desk
		var hs: float = d._hud
		var fs := roundi(18.0 * hs)
		var left := 20.0
		var right := w - 20.0
		var y := 19.0 + 15.0 * hs
		var set_text: String = "SET %02d/%02d" % [d._room, d._rooms]
		var pass_text: String = "LINE %d/%d" % [d._pass, d._passes]
		var pip_x := left + width(set_text, fs) + width(pass_text, fs) + 27.0
		var ledger_end: float = pip_x + maxf(float(d._passes) - 1.0, 0.0) * 10.0 * hs + 8.0
		rect(left - 6, 12, ledger_end - left + 10, y + 7 - 12, Color("121316d9"))
		text(left, y, set_text, fs, CHALK)
		text(left + width(set_text, fs) + 12, y, pass_text, fs, AMBER)
		for i in int(d._passes):
			var done := i < int(d._pass)
			draw_circle(Vector2(pip_x + i * 10.0 * hs, y - 5.0 * hs), 2.7 * hs,
				AMBER if done else Color("a28e72"), done, -1.0 if done else 1.0, true)
		hairline(left - 6, y + 7, ledger_end + 4, AMBER.darkened(0.42))

		var mark_text: String = "[M] MARK %d" % d._marks
		var cut_text: String = "[C] CUT %d" % d._cuts
		var splice_text := word("接片", "SPLICE") if d._splice else ""
		var splice_w := width(splice_text, fs) + 15.0 if d._splice else 0.0
		var cut_x := right - width(cut_text, fs) - splice_w
		var mark_x := cut_x - width(mark_text, fs) - 14.0
		rect(mark_x - 6, 12, right - mark_x + 12, y + 7 - 12, Color("121316d9"))
		text(mark_x, y, mark_text, fs, CHALK if d._marks > 0 else Color("c76e5e"))
		text(cut_x, y, cut_text, fs, CHALK if d._cuts > 0 else Color("c76e5e"))
		if d._splice:
			rect(right - splice_w + 7, y - fs, splice_w - 1, fs + 5, Color("263a36"))
			text(right - splice_w + 11, y, splice_text, fs, MINT)
		hairline(mark_x - 6, y + 7, right + 6, MINT.darkened(0.42))

	func draw_loupe(info: Dictionary) -> void:
		var top := minf(66.0, h * 0.175)
		var gate := minf(110.0, h * 0.175)
		var y := h - gate
		rect(0, 0, w, top, Color("121316eb"))
		rect(0, y, w, gate, Color("121316f5"))
		hairline(0, top, w, UiKit.RULE)
		hairline(0, y, w, AMBER.darkened(0.38))
		var total := maxi(1, int(info.get("total", 1)))
		var index := clampi(int(info.get("index", 0)), 0, total - 1)
		var spacing := minf(33.0, (w - 70.0) / float(total))
		var start := (w - spacing * float(total - 1)) * 0.5
		for i in total:
			var px := start + i * spacing
			var current := i == index
			var pip := "%d" % (i + 1)
			var tile := Rect2(px - spacing * 0.40, top * 0.5 - 13, spacing * 0.80, 25)
			draw_rect(tile, Color("3e2d23") if current else CARBON)
			draw_rect(tile, AMBER.darkened(0.35) if current else UiKit.RULE, false, 1.0)
			text(px - width(pip, 13) * 0.5, top * 0.5 + 4, pip, 13, AMBER if current else Color("bfb49e"))
			if current:
				rect(tile.position.x, top * 0.5 + 12, tile.size.x, 2, AMBER)

		var left := 24.0
		var right := w - 24.0
		var mid := w * 0.47
		var forced := bool(info.get("forced", false))
		var free := bool(info.get("free", false))
		var cut_count := int(info.get("cuts", 0))
		var stamp := word("−1 CUT（剩 %d）", "−1 CUT (%d LEFT)") % cut_count
		var ink := AMBER if cut_count > 0 else Color("c76e5e")
		if forced:
			stamp = word("必须剪回", "FORCED CUT")
			ink = Color("f0806b")
		elif free:
			stamp = word("首剪免费", "FREE 1ST SPLICE")
			ink = MINT
		text(left, y + 19, word("剪辑台回看", "STEENBECK // CUT DESK"), 13, AMBER)
		var detail := "%02d / %02d  ·  %s  ·  TAKE %02d @ %.1fs" % [index + 1, total,
			str(info.get("tag", "")), int(info.get("take", 0)), float(info.get("time", 0.0))]
		text(left, y + 40, _fit(detail, 16, left, mid - 14.0), 16, CHALK)
		var cost := word("剪回少走 %.1fs", "REWIND %.1fs") % float(info.get("lost", 0.0))
		text(mid, y + 38, cost, 16, CHALK)
		var back := int(info.get("back_pass", 0))
		if back > 0:
			text(mid, y + 19, word("回退 %d 趟", "BACK %d PASS" if back == 1 else "BACK %d PASSES") % back,
				12, UiKit.DIM)
		var stamp_w := width(stamp, 14) + 18.0
		draw_rect(Rect2(right - stamp_w, y + 12, stamp_w, 28), ink.darkened(0.32), false, 1.0)
		text(right - stamp_w + 9, y + 31, stamp, 14, ink)
		hairline(left, y + 48, right, UiKit.RULE)
		var keys := word("[↑/↓] 选帧    [SPACE] 落剪确认", "[↑/↓] SELECT FRAME    [SPACE] SPLICE")
		if not forced:
			keys += word("    [C / ESC] 退出看片（免费）", "    [C / ESC] EXIT VIEWING (FREE)")
		text(left, y + 67, keys, 13, UiKit.PAPER)

	func draw_picker() -> void:
		var d = owner_desk
		rect(0, 0, w, h, Color("121316d9"))
		var left := card(0).position.x
		var head := word("CUTTING DESK  //  接哪一棚？", "CUTTING DESK  //  Choose next set")
		var slug := word("剪辑台", "NEXT SET")
		if d._items:
			head = word("MEAL BREAK · SUPPLY TRAY  //  放饭补给 · 带走一件", "MEAL BREAK  //  Take one supply")
			slug = "SUPPLY TRAY"
		elif not str(d._cards[0].get("contract", "")).is_empty():
			head = word("COMPANY MOVE  //  转场通告 · 签哪一张？", "COMPANY MOVE  //  Sign call sheet")
			slug = word("转场通告", "CALL SHEETS")
		var upper := h * 0.5 - 120
		text(left, upper - 26, slug, 12, AMBER)
		text(left, upper, head, 22, CHALK)
		for i in d._cards.size():
			if d._items:
				draw_supply(i)
			elif not str(d._cards[i].get("contract", "")).is_empty():
				draw_contract(i)
			else:
				draw_strip(i)
		text(left, h * 0.5 + 122, word("[←/→] 选卡   [SPACE] 确认   [1 / 2 / 3] 快选",
			"[←/→] SELECT   [SPACE] CONFIRM   [1 / 2 / 3] DIRECT PICK"), 14, PAPER)

	func draw_call_sheet() -> void:
		var d = owner_desk
		rect(0, 0, w, h, Color("121316d9"))
		var bw := 510.0
		var bx := (w - bw) * 0.5
		var paragraphs: Array[TextParagraph] = []
		var bh := 111.0
		for line: String in d._sheet_lines:
			var paragraph := TextParagraph.new()
			paragraph.width = bw - 32.0
			paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
			paragraph.add_string(line, d._font, 15)
			bh += paragraph.get_size().y + 7.0
			paragraphs.append(paragraph)
		var by := maxf(12.0, (h - bh) * 0.5)
		var bounds := Rect2(bx, by, bw, bh)
		var angle := -0.009
		paper(bounds, angle, false)
		rect(bx, by, bw, 26, INK)
		var slug := "MACGUFFIN WORKS  //  FINAL CALL SHEET · PRINT" if d._sheet_won else "OUTTAKE REPORT · REEL ENDED"
		text(bx + 16, by + 18, slug, 13, MINT if d._sheet_won else AMBER)
		text(bx + 16, by + 56, _fit(d._sheet_title, 24, bx + 16, bx + 278), 24, INK)
		var stamp := word("当天收工", "WRAPPED") if d._sheet_won else word("NG · 未成片", "NG · OUTTAKE")
		var stamp_ink := Color("285548") if d._sheet_won else STAMP_RED
		var stamp_w := width(stamp, 15) + 18.0
		var stamp_box := Rect2(bx + bw - 17 - stamp_w, by + 34, stamp_w, 25)
		tilt(stamp_box.get_center(), -0.035, bounds.get_center(), angle)
		draw_rect(stamp_box, stamp_ink, false, 1.4, true)
		text(stamp_box.position.x + 9, stamp_box.position.y + 17, stamp, 15, stamp_ink)
		tilt(bounds.get_center(), angle)
		hairline(bx + 16, by + 66, bx + bw - 16, PAPER_RULE)
		var row := by + 70.0
		for paragraph in paragraphs:
			paragraph.draw(get_canvas_item(), Vector2(bx + 16, row), INK)
			row += paragraph.get_size().y + 7
			hairline(bx + 16, row - 3, bx + bw - 16, Color("d5cbb0"))
		rect(bx, by + bh - 32, bw, 32, INK)
		var keys := word("[SPACE] 新开一卷  ·  [R] 同种子重拍  ·  [ESC] 暂停/返回标题",
			"[SPACE] NEW REEL  ·  [R] REPLAY SEED  ·  [ESC] PAUSE / TITLE")
		text(bx + 16, by + bh - 12, keys, 13, CHALK)
		paper_marks(bounds, angle, bx + 281, by + 53)

	func draw_notice(message: String) -> void:
		var lines := message.split("\n", false)
		if lines.is_empty():
			return
		var ink := AMBER
		var lower := message.strip_edges().to_lower()
		for keyword: String in ["ng ", "ng/", "ng·", "take failed", "the dolly did not see", "you hit ",
				"you stepped into", "no marks left", "no cuts left", "no mark stock", "no cut stock",
				"out of mark", "out of cut", "empty stock", "collision!", "撞上", "没看见你",
				"踩进了画面", "用完", "耗尽"]:
			if lower.contains(keyword):
				ink = ACCENT
				break
		if lower == "ng":
			ink = ACCENT
		var widest := 0.0
		for line: String in lines:
			widest = maxf(widest, width(line, 17))
		var span := minf(w - 32, widest + 34)
		var box_h := 22.0 * float(lines.size()) + 12.0
		var x := (w - span) * 0.5
		var y := h - 15.0 - box_h
		rect(x, y, span, box_h, Color("121316e8"))
		rect(x, y, 3, box_h, ink)
		for i in lines.size():
			text(x + 14, y + 19 + 22.0 * i, _fit(lines[i], 17, x + 14, x + span - 12), 17, CHALK)

	func tilt(center: Vector2, angle: float, parent_center := Vector2.ZERO, parent_angle := 0.0) -> void:
		var origin := center - center.rotated(angle)
		origin = parent_center + (origin - parent_center).rotated(parent_angle)
		draw_set_transform(origin * s, angle + parent_angle, Vector2.ONE * s)

	func paper(bounds: Rect2, angle: float, selected: bool) -> void:
		tilt(bounds.get_center(), angle)
		draw_rect(Rect2(bounds.position + Vector2(3, 5), bounds.size), Color("101210"))
		draw_rect(bounds, Color("f3dab0") if selected else PAPER)
		if selected:
			draw_rect(bounds, AMBER, false, 2.0)
			rect(bounds.position.x, bounds.position.y, 3, bounds.size.y, ACCENT)

	func paper_marks(bounds: Rect2, angle: float, note_x: float, note_y: float) -> void:
		var tape := Rect2(bounds.position + Vector2(34, -4), Vector2(37, 8))
		tilt(tape.get_center(), 0.035, bounds.get_center(), angle)
		draw_rect(tape, Color("d9c9a6"))
		tilt(bounds.get_center(), angle)
		var note := "TAKE 01"
		var faded_ink := Color("52493a")
		text(note_x, note_y, note, 10, faded_ink)
		draw_line(Vector2(note_x - 1, note_y + 1), Vector2(note_x + width(note, 10) + 2, note_y - 8),
			Color(STAMP_RED, 0.58), 1.1, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * s)

	func draw_contract(i:int) -> void:
		var d = owner_desk
		var r := card(i)
		var x := r.position.x
		var y := r.position.y
		var selected:bool=i==d._hover
		var data:Dictionary=d._cards[i]
		var angle: float = CARD_TILTS[i % CARD_TILTS.size()]
		paper(r, angle, selected)
		# A contract is a page of the call sheet, not a strip of film: ruled
		# paper, a stamped price, and the act it covers written on the line.
		rect(x,y,196,26,INK)
		text(x+10,y+19,"CALL  /  0%d"%(i+1),14,MINT)
		text(x+12,y+58,_fit(str(data.get("title","")),22,x+12,x+184),22,INK)
		draw_line(Vector2(x+12,y+68),Vector2(x+184,y+68),Color("837e70"),1)
		text(x+12,y+92,_fit(str(data.get("line1","")),14,x+12,x+184),14,INK)
		text(x+12,y+114,_fit(str(data.get("line2","")),14,x+12,x+184),14,INK)
		rect(x+12,y+131,170,28,INK)
		text(x+22,y+151,_fit(str(data.get("stamp","")),16,x+22,x+173),16,AMBER)
		paper_marks(r, angle, x + 13, y + 176)

	## Cut a line down to what the card can actually hold. A crew call that runs
	## off the paper reads as a bug, not as a busy night.
	func _fit(s: String, px: int, x0: float, x1: float) -> String:
		var font: Font = owner_desk._font
		if font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x <= x1 - x0:
			return s
		var out := s
		while out.length() > 1 and font.get_string_size(out + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > x1 - x0:
			out = out.substr(0, out.length() - 1)
		return out + "…"

	func draw_strip(i:int) -> void:
		var d = owner_desk
		var r := card(i)
		var x := r.position.x
		var y := r.position.y
		var selected:bool=i==d._hover
		var data: Dictionary = d._cards[i]
		var kind := str(data.get("kind", "straight"))
		var title:String=word("棚型  ","SET  ")+kind.to_upper()
		# A call sheet, not a poster: paper, a ruled header, dotted leaders, and
		# one rubber stamp for what it costs.
		var angle: float = CARD_TILTS[i % CARD_TILTS.size()]
		paper(r, angle, selected)
		rect(x,y,196,26,INK)
		text(x+10,y+18,"CALL SHEET  /  %02d"%(i+1),12,MINT)
		# the shape, drawn small in the header's right corner
		var diagrams:={"s":[[2,0,3,5,8,6]],"h":[[0,6],[3,5],[2,8]],"u":[[0,6,8,2]],"l":[[0,6,8]],"n":[[6,0,8,2]],"x":[[0,8],[6,2]],"i":[[1,7]],"o":[[0,2,8,6,0]]}
		for stroke:Array in diagrams.get(kind.to_lower(),[[3,5]]):
			var pts:=PackedVector2Array()
			for cell:int in stroke: pts.append(Vector2(x+150+11*(cell%3),y+9+6*floori(cell/3.0)))
			draw_polyline(pts,MINT,2,true)
		text(x+11,y+48,title,19,INK)
		var rows:Array=[]
		var mod := str(data.get("mod_label",""))
		if mod != "": rows.append([word("布景","CREW"),mod])
		var stake := str(data.get("stake_label",""))
		if stake != "": rows.append([word("代价","COST"),stake])
		var note := str(data.get("turn_note",""))
		if note != "": rows.append([word("转过来","TURNED"),note])
		var ry := y+70.0
		for row:Array in rows:
			text(x+11,ry,str(row[0]),11,Color("6b6656"))
			text(x+58,ry,_fit(str(row[1]),13,x+58,x+178),13,INK)
			draw_line(Vector2(x+11,ry+5),Vector2(x+185,ry+5),Color("b8b09a"),1)
			ry += 22.0
		# the stamp: the price of taking this door, boxed like a rubber stamp
		var stamp := str(data.get("stamp",""))
		if stamp == "": stamp = word("无补给","NO SUPPLY")
		stamp = _fit(stamp, 12, x + 68, x + 174)
		var tw := width(stamp, 12) + 16.0
		rect(x+185-tw,y+158,tw,20,STAMP_RED)
		text(x+185-tw+8,y+172,stamp,12,PAPER)
		paper_marks(r, angle, x + 13, y + 173)

	func draw_supply(i:int) -> void:
		var r := card(i)
		var x := r.position.x
		var y := r.position.y
		var selected:bool=i==owner_desk._hover
		var names:=[word("保险接片","Safety splice"),word("补打点","Spare MARK"),word("补剪","Spare CUT")]
		var stamps:=["1.5 s", "+1 MARK", "+1 CUT"]
		var first:=[word("下次撞上旧条里的人，","Hit a past take?"),word("多一次手动打点。","One extra MARK."),word("多一次主动剪辑。","One extra CUT.")]
		var second:=[word("免死，原地续拍 1.5 秒。","Keep rolling 1.5 s."),word("按 M 留下自己的落点。","Press M to mark."),word("选好落点，确认才花。","Spend on confirm.")]
		var angle: float = CARD_TILTS[i % CARD_TILTS.size()]
		paper(r, angle, selected)
		rect(x,y,196,28,INK)
		text(x+10,y+20,"PROP  /  0%d"%(i+1),14,MINT)
		text(x+12,y+57,names[i],20,INK)
		draw_line(Vector2(x+12,y+68),Vector2(x+184,y+68),Color("837e70"),1)
		text(x+12,y+94,first[i],15,INK)
		text(x+12,y+114,second[i],15,INK)
		rect(x+12,y+131,170,28,INK)
		text(x+23,y+151,stamps[i],17,MINT)
		paper_marks(r, angle, x + 13, y + 176)
