extends RefCounted
## GhostTrack — one recorded take, stored small and replayed exactly.
##
## Quantisation on purpose:
##   time      centiseconds
##   position  millimetres
##   angle     centidegrees
## Worst-case position error is 0.5 mm, worst-case angle error is 0.005 deg.
## At 10 Hz a 90 second take costs ~47 KB as raw arrays; as JSON ints, still
## under 200 KB. The point of declaring the units here is that replay,
## interpolation and the file format cannot drift apart.

const VERSION := 1

const TIME_SCALE := 100.0  # per second
const POS_SCALE := 1000.0  # per metre
const ANG_SCALE := 100.0  # per degree

## bit flags per sample
const FLAG_ALIVE := 1
const FLAG_INTERACT := 2

var take_id := 0
var times := PackedInt32Array()
var px := PackedInt32Array()
var py := PackedInt32Array()
var pz := PackedInt32Array()
var facing_cd := PackedInt32Array()
var cam_yaw_cd := PackedInt32Array()
var cam_roll_cd := PackedInt32Array()
var flags := PackedByteArray()


static func quant_time(t: float) -> int:
	return int(round(t * TIME_SCALE))


static func dequant_time(i: int) -> float:
	return float(i) / TIME_SCALE


static func quant_pos(v: float) -> int:
	return int(round(v * POS_SCALE))


static func dequant_pos(i: int) -> float:
	return float(i) / POS_SCALE


static func quant_ang(a: float) -> int:
	var w := wrapf(a, -PI, PI)
	return int(round(w * 180.0 / PI * ANG_SCALE))


static func dequant_ang(i: int) -> float:
	return deg_to_rad(float(i) / ANG_SCALE)


func size() -> int:
	return times.size()


func duration() -> float:
	if times.is_empty():
		return 0.0
	return dequant_time(times[times.size() - 1])


func clear() -> void:
	times.clear()
	px.clear()
	py.clear()
	pz.clear()
	facing_cd.clear()
	cam_yaw_cd.clear()
	cam_roll_cd.clear()
	flags.clear()


## Append a sample. Out-of-order timestamps are refused (returns false).
##
## A standstill is stored as two samples, its first and its latest frame: when
## the last two samples already hold this exact pose and flag, the new frame only
## moves the last timestamp forward. The clock keeps running through the
## standstill (duration() is the real length of the take) and interpolating
## across it holds the pose, while a long wait still costs two samples, not one
## per tick. An interaction is never stretched: it is an instant of its own.
func add_sample(t: float, pos: Vector3, facing: float, cam_yaw: float, cam_roll: float, flag: int = FLAG_ALIVE) -> bool:
	var qt := quant_time(t)
	if not times.is_empty():
		var last := times.size() - 1
		if qt <= times[last]:
			return false
		if last >= 1 and (flag & FLAG_INTERACT) == 0 and flags[last] == flag and flags[last - 1] == flag \
				and _pose_is(last, pos, facing, cam_yaw, cam_roll) and _same_pose(last - 1, last):
			times[last] = qt
			return true
	times.append(qt)
	px.append(quant_pos(pos.x))
	py.append(quant_pos(pos.y))
	pz.append(quant_pos(pos.z))
	facing_cd.append(quant_ang(facing))
	cam_yaw_cd.append(quant_ang(cam_yaw))
	cam_roll_cd.append(quant_ang(cam_roll))
	flags.append(flag)
	return true


func _pose_is(i: int, pos: Vector3, facing: float, cam_yaw: float, cam_roll: float) -> bool:
	return px[i] == quant_pos(pos.x) and py[i] == quant_pos(pos.y) and pz[i] == quant_pos(pos.z) \
		and facing_cd[i] == quant_ang(facing) and cam_yaw_cd[i] == quant_ang(cam_yaw) \
		and cam_roll_cd[i] == quant_ang(cam_roll)


func _same_pose(i: int, j: int) -> bool:
	return px[i] == px[j] and py[i] == py[j] and pz[i] == pz[j] and facing_cd[i] == facing_cd[j] \
		and cam_yaw_cd[i] == cam_yaw_cd[j] and cam_roll_cd[i] == cam_roll_cd[j]


## Copy of the samples at or before `t` (the road to a MARK, kept when a CUT
## resumes from it).
func head_until(t: float) -> Variant:
	var out = new()
	out.take_id = take_id
	var qt := quant_time(t)
	for i in times.size():
		if times[i] > qt:
			break
		out.times.append(times[i])
		out.px.append(px[i])
		out.py.append(py[i])
		out.pz.append(pz[i])
		out.facing_cd.append(facing_cd[i])
		out.cam_yaw_cd.append(cam_yaw_cd[i])
		out.cam_roll_cd.append(cam_roll_cd[i])
		out.flags.append(flags[i])
	return out


## Index of the last sample at or before `t`, or -1.
func _index_before(t: float) -> int:
	var qt := quant_time(t)
	var lo := 0
	var hi := times.size() - 1
	if hi < 0:
		return -1
	if qt < times[0]:
		return -1
	if qt >= times[hi]:
		return hi
	while lo < hi:
		var mid := int((lo + hi + 1) / 2)
		if times[mid] <= qt:
			lo = mid
		else:
			hi = mid - 1
	return lo


## Interpolated pose at time t. Before the first sample it holds the first pose;
## after the last it holds the last pose (and callers may choose to retire the
## ghost instead — see ghost_actor.gd).
func sample_at(t: float) -> Dictionary:
	if times.is_empty():
		return {"position": Vector3.ZERO, "facing": 0.0, "cam_yaw": 0.0, "cam_roll": 0.0, "finished": true, "interact": false}
	var i := _index_before(t)
	if i < 0:
		return _pose(0, 0.0)
	if i >= times.size() - 1:
		var held := _pose(i, 0.0)
		# The recording is over: the pose holds, and the flag says so. Callers may
		# retire on this instead of comparing clocks (ghost_actor.gd currently
		# retires on its own playhead, which is the same instant).
		held["finished"] = t >= duration()
		return held
	var t0 := dequant_time(times[i])
	var t1 := dequant_time(times[i + 1])
	var span := maxf(t1 - t0, 0.0001)
	var a := clampf((t - t0) / span, 0.0, 1.0)
	return _pose(i, a)


func _pose(i: int, alpha: float) -> Dictionary:
	var j := mini(i + 1, times.size() - 1)
	var p := Vector3(
		lerpf(dequant_pos(px[i]), dequant_pos(px[j]), alpha),
		lerpf(dequant_pos(py[i]), dequant_pos(py[j]), alpha),
		lerpf(dequant_pos(pz[i]), dequant_pos(pz[j]), alpha)
	)
	return {
		"position": p,
		"facing": lerp_angle(dequant_ang(facing_cd[i]), dequant_ang(facing_cd[j]), alpha),
		"cam_yaw": lerp_angle(dequant_ang(cam_yaw_cd[i]), dequant_ang(cam_yaw_cd[j]), alpha),
		"cam_roll": lerpf(dequant_ang(cam_roll_cd[i]), dequant_ang(cam_roll_cd[j]), alpha),
		"finished": false,
		"interact": (flags[i] & FLAG_INTERACT) != 0,
	}


## Exact sample at an index, no interpolation (used when re-recording a ghost).
func raw_at(i: int) -> Dictionary:
	return _pose(clampi(i, 0, times.size() - 1), 0.0)


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"take_id": take_id,
		"n": times.size(),
		"t": Array(times),
		"x": Array(px),
		"y": Array(py),
		"z": Array(pz),
		"f": Array(facing_cd),
		"cy": Array(cam_yaw_cd),
		"cr": Array(cam_roll_cd),
		"fl": Array(flags),
	}


static func from_dict(d: Dictionary) -> Variant:
	if not d.has("version") or int(d["version"]) != VERSION:
		return null
	var tr := new()
	tr.take_id = int(d.get("take_id", 0))
	tr.times = _i32(d.get("t", []))
	tr.px = _i32(d.get("x", []))
	tr.py = _i32(d.get("y", []))
	tr.pz = _i32(d.get("z", []))
	tr.facing_cd = _i32(d.get("f", []))
	tr.cam_yaw_cd = _i32(d.get("cy", []))
	tr.cam_roll_cd = _i32(d.get("cr", []))
	tr.flags = _u8(d.get("fl", []))
	# A truncated or spliced file must be refused, not half-loaded: the declared
	# sample count has to match every channel.
	var n := int(d.get("n", tr.times.size()))
	if n != tr.times.size():
		return null
	if tr.px.size() != n or tr.py.size() != n or tr.pz.size() != n:
		return null
	if tr.facing_cd.size() != n or tr.cam_yaw_cd.size() != n or tr.cam_roll_cd.size() != n:
		return null
	if tr.flags.size() != n:
		tr.flags.resize(n)
		tr.flags.fill(FLAG_ALIVE)
	return tr


static func _i32(arr: Variant) -> PackedInt32Array:
	var out := PackedInt32Array()
	if arr is Array:
		out.resize(arr.size())
		for i in arr.size():
			out[i] = int(arr[i])
	return out


static func _u8(arr: Variant) -> PackedByteArray:
	var out := PackedByteArray()
	if arr is Array:
		out.resize(arr.size())
		for i in arr.size():
			out[i] = int(arr[i]) & 0xFF
	return out


## Cheap trajectory comparison used by tests to prove replay fidelity.
func max_deviation(other) -> float:
	var worst := 0.0
	var n := mini(times.size(), other.times.size())
	for i in n:
		var a := Vector3(dequant_pos(px[i]), 0.0, dequant_pos(pz[i]))
		var b := Vector3(dequant_pos(other.px[i]), 0.0, dequant_pos(other.pz[i]))
		worst = maxf(worst, a.distance_to(b))
	return worst
