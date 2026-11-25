extends RefCounted

const Pad = preload("res://scripts/relay/touch_pad.gd")


static func run(h, _tree = null) -> void:
	h.begin("touch_layout")
	for vp: Vector2 in [Vector2(640, 360), Vector2(844, 390), Vector2(1280, 720), Vector2(1920, 1080)]:
		var tag := "%dx%d " % [vp.x, vp.y]
		var bounds := Rect2(Vector2.ZERO, vp)
		var data := Pad.layout(vp)
		var stick: Rect2 = data.stick
		var buttons: Array[Rect2] = data.buttons
		h.ok(tag + "stable on repeat", data == Pad.layout(vp))
		h.ok(tag + "HUD band", data.hud_top == 64.0)
		h.ok(tag + "sheet band", data.sheet_bottom == 96.0)
		h.ok(tag + "four action slots", buttons.size() == 4)
		h.ok(tag + "stick target", minf(stick.size.x, stick.size.y) >= 96.0)
		var controls: Array[Rect2] = [stick]
		for i in buttons.size():
			var slot := buttons[i]
			var label := tag + "slot %d " % i
			h.ok(label + "thumb target", minf(slot.size.x, slot.size.y) >= 44.0)
			h.ok(label + "clear of stick", not stick.intersects(slot))
			for j in i:
				h.ok(label + "clear of slot %d" % j, not slot.intersects(buttons[j]))
			controls.append(slot)
		for i in controls.size():
			var rect := controls[i]
			var label := tag + "control %d " % i
			h.ok(label + "inside viewport", bounds.encloses(rect))
			h.ok(label + "clear of HUD", rect.position.y >= data.hud_top)
			h.ok(label + "clear of sheet", rect.end.y <= vp.y - data.sheet_bottom)
