extends RefCounted
## Loc — every player-visible string, in both languages.
##
## Two sources of text:
##   * data/*.json carries {"zh": "...", "en": "..."} nodes, resolved by t().
##   * UI chrome lives in STRINGS below, resolved by ui(key, args).
## Nothing else in the project picks a language. The English column is the
## reference wording that tests read, so change it only together with them.

static var language := "en"

const SUPPORTED := ["zh", "en"]
## Fallback when neither a stored preference nor rcd/default_language exists.
## The festival build starts in English; stored preferences take precedence.
const FALLBACK_DEFAULT := "en"
const SETTING_DEFAULT := "rcd/default_language"

## Name the destination in the active UI language (shared by both pickers).
const LANGUAGE_NAMES := {
	"zh": {"en": "简体中文", "zh": "简体中文"},
	"en": {"en": "English", "zh": "English"},
}

const STRINGS := {
	# --- HUD -------------------------------------------------------------
	"hud.take_one": {"en": "TAKE %02d   ·   %d GHOST   ·   %s", "zh": "第 %02d 条   ·   %d 个残影   ·   %s"},
	"hud.take_many": {"en": "TAKE %02d   ·   %d GHOSTS   ·   %s", "zh": "第 %02d 条   ·   %d 个残影   ·   %s"},
	"hud.marks": {"en": "MARK %d/%d", "zh": "标记 %d/%d"},
	"hud.roll": {"en": "ROLL: %s", "zh": "ROLL 镜头：%s"},
	"status.rolling": {"en": "ROLLING", "zh": "拍摄中"},
	"status.cut": {"en": "CUT", "zh": "已喊卡"},
	"status.complete": {"en": "COMPLETE", "zh": "已完成"},
	"status.died": {"en": "DIED — %s", "zh": "阵亡 — %s"},
	"death.text": {"en": "DIED TO %s", "zh": "死于 %s"},
	"source.take": {"en": "TAKE %02d", "zh": "第 %02d 条"},

	# --- prompts ---------------------------------------------------------
	"hint.retake": {"en": "SPACE — RETAKE", "zh": "空格 — 重拍"},
	"hint.next_take": {"en": "SPACE — NEXT TAKE", "zh": "空格 — 下一条"},
	"hint.look": {"en": "[E] LOOK — %s", "zh": "[E] 查看 — %s"},
	"hint.take": {"en": "[E] TAKE — %s", "zh": "[E] 收取 — %s"},
	"hint.ask": {"en": "[E] ASK — %s", "zh": "[E] 询问 — %s"},
	"hint.file_report": {"en": "[R] FILE REPORT", "zh": "[R] 提交报告"},
	"hint.report": {"en": "[1] FILE   [2] BURY   [3] REFRAME", "zh": "[1] 立案   [2] 压下   [3] 改写"},
	"hint.report_returned": {"en": "[1] FILE   [2] BURY   [3] REFRAME   [R] CLOSE", "zh": "[1] 立案   [2] 压下   [3] 改写   [R] 关闭"},
	"hint.cut_panel": {"en": "[UP/DOWN] PICK A POINT   [SPACE] CUT HERE   [ESC] FREE VIEW", "zh": "[上/下] 选择节点   [空格] 从此处重拍   [ESC] 自由视角"},
	"hint.paused": {"en": "ESC — RESUME", "zh": "ESC — 继续"},

	# --- banners ---------------------------------------------------------
	"flash.mark": {"en": "MARK %d/%d", "zh": "标记 %d/%d"},
	"flash.marks_full": {"en": "MARKS FULL %d/%d — CUT BACK TO FREE ONE", "zh": "标记已满 %d/%d — 喊卡回退以释放一个"},
	"flash.pick_first": {"en": "PICK A POINT FIRST", "zh": "请先选择一个节点"},
	"flash.taken": {"en": "TAKEN — %s", "zh": "已收取 — %s"},
	"flash.said": {"en": "%s — %s", "zh": "%s — %s"},
	"flash.lang": {"en": "LANG — EN", "zh": "语言 — 中文"},
	"flash.load_ok": {"en": "SAVE LOADED", "zh": "已读取存档"},

	# --- CUT panel -------------------------------------------------------
	"cut.title": {"en": "CUT — TAKE %02d ABANDONED   ·   RETAKES %d (CUT COSTS NONE)   ·   MARK %d/%d",
		"zh": "喊卡 — 放弃第 %02d 条   ·   剩余重拍 %d（喊卡不消耗）   ·   标记 %d/%d"},
	"cut.free": {"en": "FREE VIEW — pick a point to see the shot it holds", "zh": "自由视角 — 选择一个节点，预览它保存的镜头"},
	"cut.preview": {"en": "PREVIEW %s — FACING %.1f°   CAM YAW %.1f°   ROLL %.2f°   WORLD T %.1f s",
		"zh": "预览 %s — 朝向 %.1f°   镜头偏航 %.1f°   倾转 %.2f°   世界时间 %.1f 秒"},
	"cut.row": {"en": "%-7s TAKE %02d   T %s   EVIDENCE %d (%d TAKEN)   X %.2f  Z %.2f",
		"zh": "%-5s 第 %02d 条   时间 %s   证据 %d（已收取 %d）   X %.2f  Z %.2f"},
	"point.start": {"en": "START", "zh": "起点"},
	"point.mark": {"en": "MARK %d", "zh": "标记 %d"},

	# --- report ----------------------------------------------------------
	"report.title": {"en": "REPORT — TAKE %02d", "zh": "报告 — 第 %02d 条"},
	"report.seized": {"en": "SEIZED", "zh": "已收取"},
	"report.seen": {"en": "SEEN", "zh": "已查看"},
	"report.help_move": {"en": "A/D move · E list/unlist", "zh": "A/D 移动 · E 列入/移出"},
	"report.help_file": {"en": "1 FILE · 2 BURY · 3 REFRAME", "zh": "1 立案 · 2 压下 · 3 改写"},
	"report.help_close": {"en": "R close", "zh": "R 关闭"},

	# --- slate -----------------------------------------------------------
	"slate.roll_corner": {"en": "SCENE 12 · TAKE %02d", "zh": "第 12 场 · 第 %02d 条"},
	"slate.roll_sub": {"en": "ROLL CUT DIE", "zh": "ROLL CUT DIE · 开拍"},
	"slate.cut_corner": {"en": "ABANDONED · TAKE %02d", "zh": "放弃 · 第 %02d 条"},
	"slate.die_corner": {"en": "TAKE %02d", "zh": "第 %02d 条"},

	# --- front end -------------------------------------------------------
	"title.tagline": {"en": "One set. Every take you finish walks it again.", "zh": "一个片场。你拍完的每一条，都会再走一遍。"},
	"menu.play": {"en": "PLAY", "zh": "开拍 / PLAY"},
	"menu.backlot": {"en": "Backlot · Save the Negative", "zh": "外景片场 · 抢救原片"},
	"menu.new": {"en": "New Game", "zh": "新游戏"},
	"menu.continue": {"en": "Continue", "zh": "继续游戏"},
	"menu.settings": {"en": "Settings", "zh": "设置"},
	"menu.quit": {"en": "Quit", "zh": "退出游戏"},
	"menu.resume": {"en": "Resume", "zh": "继续"},
	"menu.to_title": {"en": "Quit to Title", "zh": "返回标题"},
	"menu.paused": {"en": "PAUSED", "zh": "已暂停"},
	"menu.back": {"en": "Back", "zh": "返回"},
	"menu.footer": {"en": "Mouse or arrow keys + Enter · F2 language", "zh": "鼠标或方向键 + 回车 · F2 切换语言"},
	"confirm.yes": {"en": "Yes", "zh": "确定"},
	"confirm.no": {"en": "Cancel", "zh": "取消"},
	"confirm.quit": {"en": "Quit the game?\nProgress is saved when you take evidence, ask, or file a report.",
		"zh": "确定退出游戏？\n收取证据、询问或提交报告时会自动存档。"},
	"confirm.to_title": {"en": "Return to the title screen?\nThe take in progress is abandoned; saved progress is kept.",
		"zh": "确定返回标题画面？\n当前这一条将被放弃，已保存的进度会保留。"},
	"confirm.new_overwrite": {"en": "Start a new game?\nYour saved progress will be replaced the first time the new game saves.",
		"zh": "确定开始新游戏？\n新游戏第一次存档时将覆盖现有进度。"},
	"save.none": {"en": "No saved game yet.", "zh": "尚无存档。"},
	"save.corrupt": {"en": "The save file could not be read. It has been left untouched.", "zh": "存档无法读取，文件已原样保留。"},
	"save.version": {"en": "The save is from another version and cannot be continued. It has been left untouched.",
		"zh": "存档来自其他版本，无法继续。文件已原样保留。"},
	"save.found": {"en": "Saved: take %02d · %d ghosts", "zh": "存档：第 %02d 条 · %d 个残影"},
	"error.scene": {"en": "Could not open the studio. See user://rcd/runtime.log.", "zh": "无法打开片场，详见 user://rcd/runtime.log。"},

	# --- settings --------------------------------------------------------
	"settings.title": {"en": "SETTINGS", "zh": "设置"},
	"settings.tab_general": {"en": "General", "zh": "通用"},
	"settings.tab_controls": {"en": "Controls", "zh": "操作"},
	"settings.tab_audio": {"en": "Audio", "zh": "音频"},
	"settings.tab_video": {"en": "Video", "zh": "画面"},
	"settings.language": {"en": "Language", "zh": "语言"},
	"settings.reduce_motion": {"en": "Reduce camera motion", "zh": "减弱镜头晃动"},
	"settings.roll_scale": {"en": "Camera roll strength", "zh": "镜头倾转强度"},
	"settings.mouse_sensitivity": {"en": "Mouse look sensitivity (hold right button)", "zh": "鼠标视角灵敏度（按住右键）"},
	"settings.touch_pad": {"en": "On-screen pad", "zh": "触控按键"},
	"settings.touch_auto": {"en": "Auto (touch screens only)", "zh": "自动（仅触摸屏）"},
	"settings.touch_on": {"en": "Always", "zh": "总是显示"},
	"settings.touch_off": {"en": "Never", "zh": "从不显示"},
	"settings.master_volume": {"en": "Master volume", "zh": "主音量"},
	"settings.mute": {"en": "Mute", "zh": "静音"},
	"settings.fullscreen": {"en": "Fullscreen", "zh": "全屏"},
	"settings.vsync": {"en": "V-Sync", "zh": "垂直同步"},
	"settings.max_fps": {"en": "Frame rate limit (0 = none)", "zh": "帧率上限（0 = 不限）"},
	"settings.saved_note": {"en": "Changes apply at once and are remembered on this computer.", "zh": "修改立即生效，并保存在本机。"},
	"settings.save_failed": {"en": "Settings could not be written; they apply until you quit.", "zh": "设置无法写入磁盘，本次运行期间仍然有效。"},
	"controls.move": {"en": "Move", "zh": "移动"},
	"controls.interact": {"en": "Look / take / ask", "zh": "查看 / 收取 / 询问"},
	"controls.mark": {"en": "MARK a point", "zh": "标记当前位置"},
	"controls.cut": {"en": "CUT (pick a point to resume from)", "zh": "喊卡（选择节点重拍）"},
	"controls.report": {"en": "File report at the desk", "zh": "在前台提交报告"},
	"controls.retake": {"en": "Retake / next take", "zh": "重拍 / 下一条"},
	"controls.look": {"en": "Turn camera", "zh": "转动镜头"},
	"controls.roll": {"en": "ROLL scheme: cycle / CHASE / SNAP / ORBIT", "zh": "ROLL 方案：轮换 / CHASE / SNAP / ORBIT"},
	"controls.language": {"en": "Switch language", "zh": "切换语言"},
	"controls.pause": {"en": "Pause menu", "zh": "暂停菜单"},
	"controls.key_move": {"en": "W A S D / arrows", "zh": "W A S D / 方向键"},
	"controls.key_look": {"en": "Hold right mouse button + drag", "zh": "按住鼠标右键拖动"},
	"controls.key_space": {"en": "Space", "zh": "空格"},
}

static var _missing_logged := {}


static func set_language(lang: String) -> void:
	language = lang if SUPPORTED.has(lang) else default_language()


static func toggle_language() -> String:
	set_language("zh" if language == "en" else "en")
	return language


static func is_supported(lang: String) -> bool:
	return SUPPORTED.has(lang)


## The language a first launch uses: rcd/default_language when the project (or
## an export override) sets a supported one, otherwise Chinese.
static func default_language() -> String:
	if ProjectSettings.has_setting(SETTING_DEFAULT):
		var v := str(ProjectSettings.get_setting(SETTING_DEFAULT)).strip_edges().to_lower()
		if SUPPORTED.has(v):
			return v
	return FALLBACK_DEFAULT


static func language_name(lang: String) -> String:
	return t(LANGUAGE_NAMES.get(lang, lang))


## Resolve one text node. Never returns null.
static func t(node: Variant) -> String:
	if node == null:
		return ""
	if node is String or node is StringName:
		return String(node)
	if node is Dictionary:
		var d: Dictionary = node
		if d.has(language):
			return str(d[language])
		# Fall back in a fixed order so a missing translation never blanks the UI.
		for k: String in SUPPORTED:
			if d.has(k):
				return str(d[k])
		return ""
	if node is Array:
		var parts: PackedStringArray = []
		for x: Variant in node:
			parts.append(t(x))
		return "".join(parts)
	return str(node)


## UI string by key. Dictionary/Array args are bilingual nodes and are resolved
## in the current language too, so a stored (key, args) pair re-renders
## correctly after a language switch. An unknown key renders as the key itself.
static func ui(key: String, args: Array = []) -> String:
	if not STRINGS.has(key):
		if not _missing_logged.has(key):
			_missing_logged[key] = true
			push_warning("Loc: missing string '%s'" % key)
		return key
	var fmt := t(STRINGS[key])
	if args.is_empty():
		return fmt
	var resolved: Array = []
	for a: Variant in args:
		resolved.append(t(a) if (a is Dictionary or a is Array) else a)
	return fmt % resolved
