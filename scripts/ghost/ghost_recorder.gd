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
## Grid ticks since start(). Tick k is stamped k / HZ whether or not the track
## kept that frame, so a standstill cannot stop the clock.
var _ticks := 0
var _elapsed := 0.0


func _init() -> void:
	track = GhostTrack.new()


func setup(player: Node3D, cam: Node3D, take_id: int) -> void:
	_player = player
	_cam = cam
	_take_id = take_id
	track = GhostTrack.new()
	track.take_id = take_id
	_ticks = 0
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
	_ticks = 0


## Continue the current recording from `t` seconds into it: samples up to `t`
## stay as the road that led there, and the grid carries on after them.
func resume_from(t: float, take_id: int) -> void:
	_take_id = take_id
	track = track.head_until(t)
	track.take_id = take_id
	recording = true
	_elapsed = t
	_ticks = int(floor(t * HZ + 0.000001)) + 1
	_acc = 1.0 / HZ


func stop() -> Variant:
	recording = false
	return track


## Mark a moment worth remembering (evidence touched, report filed). The mark is
## a new sample at the current physics time; it never rewrites an older sample,
## which may be the start of a standstill seconds ago.
func mark(flag: int) -> void:
	if _player != null and _emit_at(_elapsed, flag):
		return
	# Refused only when the newest sample shares this centisecond: it is "now".
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
	_emit_at(float(_ticks) / HZ, 0)
	_ticks += 1


func _emit_at(t: float, extra_flag: int) -> bool:
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
	return track.add_sample(t, pos, facing, yaw, roll, flag | extra_flag)


func sample_count() -> int:
	return track.size()


## Physics seconds since start(), standstills included.
func elapsed() -> float:
	return _elapsed
