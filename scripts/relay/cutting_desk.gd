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
var _cards := []
var _message := ""
var _remaining := 0.0
var _result := -1
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
	_zh=zh; _result=-1; _cards=cards.slice(0,3); _hover=-1; _age=0
	_refresh()

func show_message(text:String) -> void:
	_message=text; _remaining=3.0; _refresh()

func show_result(won:bool,zh:bool) -> void:
	_zh=zh; _result=int(won); _cards.clear(); _age=0
	_refresh()

func hide_draw() -> void:
	_cards.clear(); _hover=-1; _refresh()

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
		return Rect2(w*0.5-n*103+i*206+5,h*0.5-83,196,170)
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
		var dark:=Color("1d2224ee")
		rect(14,12,246,38,dark);rect(14,12,4,38,AMBER)
		text(26,37,word("棚 %02d/%02d","SET %02d/%02d")%[d._room,d._rooms],17,PAPER)
		text(148,37,word("趟 %d/%d","PASS %d/%d")%[d._pass,d._passes],16,AMBER)
		var stock:String="MARK %d   CUT %d"%[d._marks,d._cuts]
		if d._splice: stock+=word("   接片","   SPLICE")
		var sw:float=d._font.get_string_size(stock,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x+28
		rect(w-sw-14,12,sw,38,dark); text(w-sw,37,stock,16,MINT)
		if not d._cards.is_empty():
			rect(0,0,w,h,Color("101817cf"))
			var left:=card(0).position.x
			text(left,h*.5-105,word("剪辑台   /   接哪一段？","CUTTING DESK   /   Choose the next strip"),22,PAPER)
			for i in d._cards.size(): draw_strip(i)
			text(left,h*.5+122,word("点选胶片，或按 1 / 2 / 3","Click a strip, or press 1 / 2 / 3"),16,PAPER)
		elif d._result>=0:
			var x:=w*.5-192;var y:=h*.5-60
			rect(x,y,384,120,INK)
			var accent:=MINT if d._result==1 else AMBER
			rect(x,y,384*minf(d._age/.36,1),5,accent)
			text(x+22,y+39,"35 MM   /   " + ("ANSWER PRINT" if d._result==1 else "OUTTAKE"),16,accent)
			text(x+22,y+89,word("全片接通","PRINT COMPLETE") if d._result==1 else word("这卷到头了","END OF REEL"),32,PAPER)
		if d._remaining>0 and d._message!="":
			var span:=minf(w-32,d._font.get_string_size(d._message,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x+32)
			rect((w-span)*.5,h-51,span,36,dark)
			draw_string(d._font,Vector2((w-span)*.5+14,h-27),d._message,HORIZONTAL_ALIGNMENT_LEFT,span-24,17,PAPER)
	func draw_strip(i:int) -> void:
		var d=owner_desk; var r:=card(i);var x:=r.position.x;var y:=r.position.y
		var selected:bool=i==d._hover
		var data:Dictionary=d._cards[i];var kind:=str(data.get("kind","straight"))
		var title:String={"tee":word("丁字支棚","T-JUNCTION"),"cross":word("十字支棚","CROSSING"),"zig":word("折线通道","DOGLEG"),"straight":word("直棚","STRAIGHT")}.get(kind,kind)
		rect(x+3,y+5,196,170,Color("101210"));rect(x,y,196,170,AMBER if selected else PAPER)
		for j in 11:
			for edge in [4,158]:rect(x+7+j*17,y+edge,9,7,INK)
		rect(x+8,y+17,180,84,INK)
		var pts:=PackedVector2Array([Vector2(22,60),Vector2(174,60)])
		if kind=="zig":pts=PackedVector2Array([Vector2(22,60),Vector2(56,60),Vector2(56,44),Vector2(98,44),Vector2(98,77),Vector2(142,77),Vector2(142,60),Vector2(174,60)])
		for k in pts.size():pts[k]+=Vector2(x,y)
		draw_polyline(pts,MINT,4,true)
		if kind in ["tee","cross"]:draw_line(Vector2(x+98,y+37),Vector2(x+98,y+(82 if kind=="cross" else 60)),MINT,4,true)
		text(x+11,y+126,"%02d"%(i+1),17,INK);text(x+47,y+126,title,19,INK)
		if data.get("splice",false):text(x+47,y+149,word("附安全接片","+ SAFETY SPLICE"),14,INK)
