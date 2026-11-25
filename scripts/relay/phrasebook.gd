extends RefCounted
## One notice per player, per verb, forever.
const KINDS: Array[String] = ["props", "gantry", "frame", "final"]
const PATH := "user://rcd/relay_lessons.cfg"
const LINES := {
	"props": ["棚里会掉东西、会扫镜头。地上的黄框是它要来的地方。", "The set throws things and swings a boom. The yellow floor marks where it lands."],
	"gantry": ["这棚有两层。斜梯在两头，桥上看得更远。", "This stage has two floors. The ramps are at both ends; the bridge sees further."],
	"frame": ["取景框外没有墙。第三次过线之前，你会被踢出去。", "There is no wall past the frame. Cross out three times and you get ejected."],
	"final": ["这是你自己拍的片子——废条、喊卡、还有没剪的，都在里面。", "That was your own print: the bad takes, the cuts, everything you did not trim."],
}

static func seen(kind: String, path := PATH) -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(path) == OK and cfg.get_value("lessons", kind, false) == true

static func mark(kind: String, path := PATH) -> bool:
	if kind not in KINDS: return false
	var cfg := ConfigFile.new()
	var error := cfg.load(path)
	if error != OK and error != ERR_FILE_NOT_FOUND: return false
	if cfg.get_value("lessons", kind, false) == true: return false
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir())) != OK:
		return false
	cfg.set_value("lessons", kind, true)
	return cfg.save(path) == OK

static func line(kind: String, zh: bool) -> String:
	return str(LINES[kind][0 if zh else 1]) if LINES.has(kind) else ""

static func clear(path := PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
