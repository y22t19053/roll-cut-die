extends Node
## NightStageMusic — the title's score: the project's own felt-mallet cue
## (after_wrap), faded in quietly on Master. Playing on Master means the saved
## mute / volume (GameSession.apply_engine_settings) govern it from the first
## sample and follow any change made in Settings at once.

const SCORE_PATH := "res://assets/audio/studiolot/after_wrap.res"
const FLOOR_DB := -60.0
const LEVEL_DB := -20.0

var _player: AudioStreamPlayer
var _fade: Tween


func _ready() -> void:
	if not ResourceLoader.exists(SCORE_PATH):
		return
	var stream := load(SCORE_PATH) as AudioStream
	if stream == null:
		return
	_player = AudioStreamPlayer.new()
	_player.stream = stream
	_player.bus = &"Master"
	add_child(_player)
	start()


func start() -> void:
	if _player == null or _player.playing:
		return
	_player.volume_db = FLOOR_DB
	_player.play()
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_player, "volume_db", LEVEL_DB, 1.8)


## Cut at once: called before a scene change and again when leaving the tree.
func halt() -> void:
	if _fade != null:
		_fade.kill()
		_fade = null
	if _player != null:
		_player.stop()


func _exit_tree() -> void:
	halt()
