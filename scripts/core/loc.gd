extends RefCounted
## Loc — resolves a bilingual text node into a string.
##
## Every player-visible string in data/*.json is a {"zh": "...", "en": "..."}
## pair. This is the only code that picks one. Plain strings pass through
## untouched so a partially migrated file still renders.

static var language := "en"

const SUPPORTED := ["zh", "en"]


static func set_language(lang: String) -> void:
	language = lang if SUPPORTED.has(lang) else "en"


static func toggle_language() -> String:
	set_language("zh" if language == "en" else "en")
	return language


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
