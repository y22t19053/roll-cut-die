extends SceneTree
## Minimal liveness probe: proves `--script` invocation and stdout capture work.

func _init() -> void:
	print("PROBE OK engine=", Engine.get_version_info()["string"])
	quit(0)
