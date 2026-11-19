extends RefCounted
## RollModes — the three ROLL schemes under comparison, and every number they use.
##
## All three keep the bible's §4.2 hard rules: movement is world-anchored, roll is
## derived from camera yaw speed only, and the camera takes part in no gameplay
## check. What differs is how the frame moves and how the body turns:
##
##   CHASE  continuous chase of facing through a deadzone and a speed cap
##          (CameraChase, the §4.3 baseline; its numbers stay in CameraMath).
##   SNAP   the frame only moves on a key press: one fixed step toward the new
##          heading, fast eased, then it holds still however long you walk.
##   ORBIT  while any direction is held the camera revolves around the player at
##          a fixed rate, the way your last sideways step pointed; release and it
##          stays where it stopped, it never returns.
##
## Comparison and measurements: docs/ROLL_SCHEME_STUDY.md, tests/probe_roll_modes.gd.

const CameraMath = preload("res://scripts/camera/camera_math.gd")

enum { CHASE = 0, SNAP = 1, ORBIT = 2 }
const COUNT := 3
const NAMES := ["CHASE", "SNAP", "ORBIT"]

# --- CHASE (mode 0) --------------------------------------------------------
## Body turn: exponential approach toward the walk direction, per second.
const CHASE_TURN_RATE := 12.0

# --- SNAP (mode 1) ---------------------------------------------------------
## One press moves the frame exactly this much, never more, never less.
const SNAP_STEP_DEG := 90.0
const SNAP_STEP := SNAP_STEP_DEG * PI / 180.0
## Duration of the eased swing. Short enough to read as a cut, long enough that
## the eye can follow which way the room turned.
const SNAP_TIME := 0.18
## Headings are read on an 8-way grid, so a key change is a discrete event.
const HEADING_GRID_DEG := 45.0
## Body turn: instant, the brim points at the new heading on the press frame.

# --- ORBIT (mode 2) --------------------------------------------------------
## Revolution rate while any direction is held. 30 deg/s = a full turn in 12 s:
## still visible on a long straight, slow enough that the straight stays readable.
const ORBIT_W_DEG := 30.0
const ORBIT_W := ORBIT_W_DEG * PI / 180.0
## Spin-up/spin-down; 0.25 s to full rate, so release stops almost in place.
const ORBIT_ACCEL_DEG := 180.0
const ORBIT_ACCEL := ORBIT_ACCEL_DEG * PI / 180.0
## A press must be at least this far sideways on screen to re-aim the spin;
## a pure screen-forward/back press keeps the previous sense.
const ORBIT_LATERAL_MIN := 0.1
## Body turn: constant angular speed cap instead of an exponential approach.
const ORBIT_TURN_DEG := 360.0
const ORBIT_TURN := ORBIT_TURN_DEG * PI / 180.0


static func clamp_mode(m: int) -> int:
	return posmod(m, COUNT)


static func mode_name(m: int) -> String:
	return NAMES[clamp_mode(m)]


## Snap a world heading onto the 8-way grid.
static func quantize_heading(a: float) -> float:
	var g := HEADING_GRID_DEG * PI / 180.0
	return CameraMath.wrap_angle(roundf(a / g) * g)


## One physics step of the body's facing toward the walk direction `want`.
static func step_facing(mode: int, facing: float, want: float, dt: float) -> float:
	match clamp_mode(mode):
		SNAP:
			return quantize_heading(want)
		ORBIT:
			var err := CameraMath.wrap_angle(want - facing)
			return CameraMath.wrap_angle(facing + clampf(err, -ORBIT_TURN * dt, ORBIT_TURN * dt))
	return lerp_angle(facing, want, clampf(CHASE_TURN_RATE * dt, 0.0, 1.0))


## Signed sideways component of a world direction as seen through a camera at
## `cam_yaw`: +1 = straight to screen-right, -1 = screen-left.
static func screen_lateral(dir: Vector3, cam_yaw: float) -> float:
	return dir.x * cos(cam_yaw) - dir.z * sin(cam_yaw)
