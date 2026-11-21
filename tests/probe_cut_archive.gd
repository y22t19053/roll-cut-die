extends SceneTree
const Archive := preload("res://scripts/take/cut_archive.gd")
func _init() -> void:
	var a := Archive.new()
	var entry := {"device": [0]}
	for i in range(1, 6):
		entry.device[0] = i
		a.record_success(i, entry, {"xs": [i]})
	var redo := a.recut(1, 3)
	var ok: bool = redo.get("entry", {}) == {"device": [3]} and a.shot_ids(2) == [1, 2]
	redo.entry.device[0] = -1
	a.record_success(6, {"device": [3]}, {"xs": [99]})
	ok = ok and a.shot_ids(1) == [1,2,3,4,5] and a.shot_ids(2) == [1,2,6] and a.shot(3).entry.device == [3]
	ok = ok and a.recut(2, 4).is_empty() and a.active == 2
	print("CUT ARCHIVE: original=", a.shot_ids(1), " recut=", a.shot_ids(2), " PASS=", ok)
	quit(0 if ok else 1)
