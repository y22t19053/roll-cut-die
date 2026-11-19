extends Node
## GhostRecorder — samples the live player into a GhostTrack.
##
## Sampling is on a fixed 10 Hz grid driven by physics time, not by frame time,
## so a recording of the same input is the same file on any machine. The grid is
## independent of the camera: yaw and roll are sampled too, because the ghost
## has to reproduce the shot, not just the walk.

const GhostTrack = preload("res://scripts/ghost/ghost_track.gd")

const HZ := 10.0

var track
var recording := false

var _player: Node3D
var _cam: Node3D
var _take_id := 1
var _acc := 0.0
var _samples := 0
var _elapsed := 0.0


func _init() -> void:
	track = GhostTrack.new()


func setup(player: Node3D, cam: Node3D, take_id: int) -> void:
	_player = player
	_cam = cam
	_take_id = take_id
	track = GhostTrack.new()
	track.take_id = take_id
	_samples = 0
	_elapsed = 0.0
	_acc = 0.0


func start() -> void:
	# Every take records into a fresh track. start() is reachable without
	# setup() (retake, manual restart), and reusing the previous track would
	# restart the timestamps at 0 while the old samples are still in it, so
	# add_sample() would reject every new sample as out of order.
	track = GhostTrack.new()
	track.take_id = _take_id
	recording = true
	_acc = 1.0 / HZ  # take a sample on the first physics tick
	_elapsed = 0.0
	_samples = 0


func stop() -> Variant:
	recording = false
	return track


## Mark a moment worth remembering (evidence touched, report filed).
func mark(flag: int) -> void:
	if track.size() > 0:
		track.flags[track.size() - 1] = track.flags[track.size() - 1] | flag


func _physics_process(dt: float) -> void:
	if not recording or _player == null:
		return
	_elapsed += dt
	_acc += dt
	var step := 1.0 / HZ
	var guard := 0
	while _acc >= step and guard < 8:
		guard += 1
		_acc -= step
		_emit()


func _emit() -> void:
	var pos: Vector3 = _player.global_position
	var facing: float = _player.get("facing")
	var yaw := 0.0
	var roll := 0.0
	if _cam != null:
		yaw = _cam.get("yaw")
		roll = _cam.get("roll")
	var flag := GhostTrack.FLAG_ALIVE
	if _player.get("frozen") == true:
		flag = 0
	if track.add_sample(_samples / HZ, pos, facing, yaw, roll, flag):
		_samples += 1


func sample_count() -> int:
	return track.size()


func elapsed() -> float:
	return _samples / HZ
