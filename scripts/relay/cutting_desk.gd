extends CanvasLayer
## Film edge numbers are the HUD. The desk itself only takes pointer input
## during a draw; numeric selection never shares the MARK/CUT actions.
signal picked(index: int)
const PAPER := Color("eee5cb")
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
var _remaining := 0.0
var _result := -1
var _sheet_title := ""
var _sheet_lines: Array = []
var _sheet_won := true
var _age := 0.0
var _hover := -1
var _font := SystemFont.new()

func _ready() -> void:
	layer = 12
	_font.font_names = PackedStringArray(["Consolas","Microsoft YaHei UI","Noto Sans CJK SC","sans-serif"])
	_sheet = Sheet.new()
	_sheet.owner_desk = self
	add_child(_sheet)
	_sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_refresh()

func _refresh() -> void:
	if not _sheet: return
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE if _cards.is_empty() else Control.MOUSE_FILTER_STOP
	_sheet.queue_redraw()

func update_run(room:int,total:int,pass_no:int,pass_total:int,mark_stock:int,cut_stock:int,splice:bool,zh:bool) -> void:
	if [_room,_rooms,_pass,_passes,_marks,_cuts,_splice,_zh] == [room,total,pass_no,pass_total,mark_stock,cut_stock,splice,zh]: return
	_room=room; _rooms=total; _pass=pass_no; _passes=pass_total
	_marks=mark_stock; _cuts=cut_stock; _splice=splice; _zh=zh
	_refresh()

func show_draw(cards:Array,zh:bool) -> void:
	_items=false; _zh=zh; _result=-1; _cards=cards.slice(0,3); _hover=-1; _age=0
	_refresh()

## Shares picked(index) with the map picker: 0 splice, 1 MARK, 2 CUT.
func show_items(zh:bool) -> void:
	_items=true; _zh=zh; _result=-1; _hover=-1; _age=0
	_cards=["splice","mark","cut"]; _refresh()

func show_message(text:String) -> void:
	_message=text; _remaining=3.0; _refresh()

func show_result(won:bool,zh:bool) -> void:
	_zh=zh; _result=int(won); _cards.clear(); _age=0
	_sheet_lines=[]; _refresh()


## The call sheet: what this run was, in lines a player can read out loud. The
## seed is on it so two runs can be compared, replayed or argued about.
func show_call_sheet(title:String, lines:Array, won:bool, zh:bool) -> void:
	_zh=zh; _sheet_title=title; _sheet_lines=lines; _sheet_won=won
	_cards.clear(); _items=false; _result=-1; _age=0
	_refresh()

func hide_draw() -> void:
	_cards.clear(); _hover=-1; _refresh()


## The call sheet belongs to a finished run. Once the next set is on, it is gone:
## a page from the last run lying over the next one reads as a bug, not a memory.
func clear_sheet() -> void:
	if _sheet_title == "" and _sheet_lines.is_empty(): return
	_sheet_title=""; _sheet_lines=[]; _refresh()

func _process(delta:float) -> void:
	if _remaining>0:
		_remaining-=delta
		if _remaining<=0: _refresh()
	if _age<0.5 and (_result>=0 or not _cards.is_empty()):
		_age+=delta; _refresh()

func _pick(i:int) -> void:
	if i<0 or i>=_cards.size(): return
	hide_draw(); picked.emit(i)

func _input(e:InputEvent) -> void:
	if _cards.is_empty() or not e is InputEventKey or not e.pressed or e.echo: return
	var keys := [KEY_1,KEY_2,KEY_3,KEY_KP_1,KEY_KP_2,KEY_KP_3]
	var i:=keys.find(e.keycode)
	if i>=0 and i%3<_cards.size():
		get_viewport().set_input_as_handled(); _pick(i%3)

class Sheet extends Control:
	var owner_desk
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
		if idx!=owner_desk._hover:
			owner_desk._hover=idx; queue_redraw()
		if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:
			accept_event(); owner_desk._pick(idx)
	func _draw() -> void:
		_layout(); draw_set_transform(Vector2.ZERO,0,Vector2.ONE*s)
		var d=owner_desk
		# HUD: type on the frame, no furniture. Two groups, one hairline each,
		# so the deck is what you look at and the numbers are what you glance at.
		var line_y := 34.0
		draw_line(Vector2(20,line_y+8),Vector2(214,line_y+8),Color(AMBER.r,AMBER.g,AMBER.b,0.55),1.0)
		text(22,line_y,word("棚 %02d/%02d","SET %02d/%02d")%[d._room,d._rooms],18,PAPER)
		text(146,line_y,word("过线 %d/%d","LINE %d/%d")%[d._pass,d._passes],18,AMBER)
		var stock:String="MARK %d   CUT %d"%[d._marks,d._cuts]
		if d._splice: stock+=word("   接片","   SPLICE")
		var sw:float=d._font.get_string_size(stock,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
		draw_line(Vector2(w-sw-22,line_y+8),Vector2(w-22,line_y+8),Color(MINT.r,MINT.g,MINT.b,0.55),1.0)
		text(w-sw-20,line_y,stock,18,MINT)
		if not d._cards.is_empty():
			rect(0,0,w,h,Color("101817cf"))
			var left:=card(0).position.x
			var head := word("剪辑台   /   接哪一段？","CUTTING DESK   /   Choose the next strip")
			if d._items: head = word("道具盘   /   带走一件","SUPPLY TRAY   /   Take one")
			elif d._cards.size() > 0 and not str(d._cards[0].get("contract","")).is_empty():
				head = word("换场单   /   签哪一张？","NEW CALL   /   Sign one")
			text(left,h*.5-105,head,22,PAPER)
			for i in d._cards.size():
				if d._items: draw_supply(i)
				elif not str(d._cards[i].get("contract","")).is_empty(): draw_contract(i)
				else: draw_strip(i)
			text(left,h*.5+122,word("点选，或按 1 / 2 / 3","Click your pick, or press 1 / 2 / 3"),16,PAPER)
		elif not d._sheet_lines.is_empty():
			# The end of a reel is a sheet of paper too, not a black plate: same
			# paper, same ruled rows, so the run ends on the object that started it.
			var bw: float = 460.0
			var bh: float = 118.0 + float(d._sheet_lines.size()) * 30.0
			var bx: float = (w-bw)*.5
			var by: float = (h-bh)*.5
			rect(bx+3,by+6,bw,bh,Color("101210"))
			rect(bx,by,bw,bh,PAPER)
			rect(bx,by,bw,26,INK)
			text(bx+12,by+18,"CALL SHEET  /  %s"%("PRINT" if d._sheet_won else "OUTTAKE"),12,MINT if d._sheet_won else AMBER)
			text(bx+12,by+56,d._sheet_title,24,INK)
			draw_line(Vector2(bx+12,by+66),Vector2(bx+bw-12,by+66),Color("b8b09a"),1)
			var row: float = by+92
			for line: String in d._sheet_lines:
				text(bx+12,row,_fit(line,15,bx+12,bx+bw-12),15,INK)
				draw_line(Vector2(bx+12,row+6),Vector2(bx+bw-12,row+6),Color("ddd3b8"),1)
				row+=30
			var stamp := word("当天收工","WRAPPED") if d._sheet_won else word("没用上","WASTED")
			var tw2: float = d._font.get_string_size(stamp,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+16.0
			rect(bx+bw-12-tw2,by+bh-30,tw2,20,Color("8c2f22"))
			text(bx+bw-12-tw2+8,by+bh-16,stamp,12,PAPER)
		elif d._result>=0:
			var x:=w*.5-192;var y:=h*.5-60
			rect(x,y,384,120,INK)
			var accent:=MINT if d._result==1 else AMBER
			rect(x,y,384*minf(d._age/.36,1),5,accent)
			text(x+22,y+39,"35 MM   /   " + ("ANSWER PRINT" if d._result==1 else "OUTTAKE"),16,accent)
			text(x+22,y+89,word("全片接通","PRINT COMPLETE") if d._result==1 else word("这卷到头了","END OF REEL"),32,PAPER)
		if d._remaining>0 and d._message!="":
			var span:=minf(w-32,d._font.get_string_size(d._message,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x+32)
			# One line of type over a soft scrim: enough to read, not a panel.
			rect((w-span)*.5,h-51,span,36,Color(0.043,0.051,0.055,0.62))
			draw_string(d._font,Vector2((w-span)*.5+14,h-27),d._message,HORIZONTAL_ALIGNMENT_LEFT,span-24,17,PAPER)
	func draw_contract(i:int) -> void:
		var d=owner_desk; var r:=card(i); var x:=r.position.x; var y:=r.position.y
		var selected:bool=i==d._hover
		var data:Dictionary=d._cards[i]
		rect(x+3,y+5,196,188,Color("101210"));rect(x,y,196,188,AMBER if selected else PAPER)
		# A contract is a page of the call sheet, not a strip of film: ruled
		# paper, a stamped price, and the act it covers written on the line.
		rect(x,y,196,26,INK)
		text(x+10,y+19,"CALL  /  0%d"%(i+1),14,MINT)
		text(x+12,y+58,str(data.get("title","")),24,INK)
		draw_line(Vector2(x+12,y+68),Vector2(x+184,y+68),Color("837e70"),1)
		text(x+12,y+92,str(data.get("line1","")),14,INK)
		text(x+12,y+114,str(data.get("line2","")),14,INK)
		rect(x+12,y+131,170,28,INK)
		text(x+22,y+151,str(data.get("stamp","")),17,AMBER)

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
		var d=owner_desk; var r:=card(i);var x:=r.position.x;var y:=r.position.y
		var selected:bool=i==d._hover
		var data:Dictionary=d._cards[i];var kind:=str(data.get("kind","straight"))
		var title:String=word("棚型  ","SET  ")+kind.to_upper()
		# A call sheet, not a poster: paper, a ruled header, dotted leaders, and
		# one rubber stamp for what it costs.
		rect(x+3,y+5,196,188,Color("101210"))
		rect(x,y,196,188,AMBER if selected else PAPER)
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
		var tw: float = d._font.get_string_size(stamp,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+16.0
		rect(x+185-tw,y+158,tw,20,Color("8c2f22"))
		text(x+185-tw+8,y+172,stamp,12,PAPER)

	func draw_supply(i:int) -> void:
		var r:=card(i); var x:=r.position.x; var y:=r.position.y
		var selected:bool=i==owner_desk._hover
		var names:=[word("保险接片","Safety splice"),word("补打点","Spare MARK"),word("补剪","Spare CUT")]
		var stamps:=["1.5 s", "+1 MARK", "+1 CUT"]
		var first:=[word("下次撞上旧条里的人，","Hit a past take?"),word("多一次手动打点。","One extra MARK."),word("多一次主动剪辑。","One extra CUT.")]
		var second:=[word("免死，原地续拍 1.5 秒。","Keep rolling 1.5 s."),word("按 M 留下自己的落点。","Press M to mark."),word("选好落点，确认才花。","Spend on confirm.")]
		rect(x+3,y+5,196,188,Color("101210"));rect(x,y,196,188,AMBER if selected else PAPER)
		rect(x,y,196,28,INK);text(x+10,y+20,"PROP  /  0%d"%(i+1),14,MINT)
		text(x+12,y+57,names[i],20,INK)
		draw_line(Vector2(x+12,y+68),Vector2(x+184,y+68),Color("837e70"),1)
		text(x+12,y+94,first[i],15,INK);text(x+12,y+114,second[i],15,INK)
		rect(x+12,y+131,170,28,INK);text(x+23,y+151,stamps[i],17,MINT)
