extends RefCounted
## Exported Godot has project.binary, not the staging project.godot. Compare the
## hash of the raw manifest with an independently held build receipt offline.
const PATH := "res://tools/trial_build_config.json"

static func enabled() -> bool:
	return ProjectSettings.get_setting("research/west_trial/enabled", false) == true

static func hex_digest(text: Variant, size: int) -> bool:
	if not text is String or text.length() != size:
		return false
	for c in text:
		if not "0123456789abcdef".contains(c):
			return false
	return true

static func verified(condition: String) -> Dictionary:
	if not enabled() or not FileAccess.file_exists(PATH):
		return {}
	var manifest: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not manifest is Dictionary or manifest.get("condition") != condition:
		return {}
	var git: Variant = manifest.get("git_commit")
	var staged: Variant = manifest.get("project_godot_sha256")
	if not hex_digest(git, 40) or git != ProjectSettings.get_setting("research/west_trial/git_commit", "") or not hex_digest(staged, 64):
		return {}
	var digest := FileAccess.get_sha256(PATH)
	var exe := FileAccess.get_sha256(OS.get_executable_path())
	if not hex_digest(digest, 64) or not hex_digest(exe, 64):
		return {}
	return {"project_config_sha256":digest, "staged_project_sha256":staged, "git_commit":git, "exe_sha256":exe}
