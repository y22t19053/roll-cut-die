extends SceneTree
const Logger = preload("res://scripts/core/logger.gd")


func _init() -> void:
	print("A: script loaded, path const = ", Logger.PATH)
	Logger.info("hello from logger")
	Logger.error("and an error line")
	print("B: dir exists = ", DirAccess.dir_exists_absolute(Logger.DIR))
	print("C: log length = ", Logger.read().length())
	quit(0)
