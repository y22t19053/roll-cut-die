extends RefCounted
## The studio lot: one 48 x 36 m floor in stage metres, shared by every take.
##
##   z 0  +--------------------+-------------------------------+
##        | PROJECTION HOUSE  [A]        TANK STAGE            |
##   z 13 +---door-------------+-----------------------door----+
##        |                EXTERIOR STREET                     |
##   z 21 +--door-------+--------------+-------------door------+
##        | EDITING    [B] FREIGHT LIFT    DEVELOPING LAB      |
##   z 36 +-------------+--------------+-----------------------+
##
## [A] and [B] are shutters latched on their far side: A from the tank stage,
## B from inside the lift car. Interior partitions are low flats so the camera
## reads over them; only the perimeter is full-height wall.

const SIZE := [48, 36]
const SITES := ["tank", "lab", "street"]
const FLAT := 1.3

## Five marks in the editing tower; successive takes start on different ones.
const SPAWNS := [Vector3(4, 0.05, 25), Vector3(6.5, 0.05, 27.5), Vector3(9.5, 0.05, 25.5),
	Vector3(11, 0.05, 29), Vector3(8, 0.05, 31)]

## Footprints drawn on the theatre screen: [id, rect, colour].
const ZONES := [
	["theatre", [0.5, 0.5, 17, 13], Color(0.30, 0.12, 0.14)],
	["tank", [17.5, 0.5, 47.5, 13], Color(0.08, 0.26, 0.30)],
	["street", [0.5, 13.5, 47.5, 20.5], Color(0.20, 0.20, 0.22)],
	["tower", [0.5, 21, 16, 35.5], Color(0.16, 0.20, 0.32)],
	["lift", [16.5, 28, 25.5, 32], Color(0.42, 0.34, 0.08)],
	["lab", [26, 21, 47.5, 35.5], Color(0.34, 0.14, 0.08)],
]
const SITE_CENTRE := {"tank": Vector2(32, 6.5), "lab": Vector2(37, 28), "street": Vector2(26, 17)}

const C_THEATRE := [0.42, 0.18, 0.20]
const C_TANK := [0.16, 0.38, 0.42]
const C_LAB := [0.52, 0.24, 0.14]
const C_TOWER := [0.24, 0.30, 0.46]
const C_LIFT := [0.72, 0.58, 0.14]
const C_STREET := [0.36, 0.36, 0.38]
const C_PED := [0.16, 0.16, 0.18]


## Everything that differs between productions, decided once from the
## production number. Nothing here is rolled again for a retake.
static func variation(production: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("rcd-studiolot-%d" % production)
	return {
		"code": 1000 + int(rng.randi() % 9000),
		"truck_north": rng.randi() % 2 == 0,
		"tank_sound_south": rng.randi() % 2 == 0,
		"lab_sound_mid": rng.randi() % 2 == 0,
		"diver_north": rng.randi() % 2 == 0,
		"slot_shift": int(rng.randi() % SPAWNS.size()),
	}


static func _p(id: String, rect: Array, height: float, color: Array, solid := true) -> Dictionary:
	return {"id": id, "rect": rect, "height": height, "color": color, "solid": solid}


static func layout(v: Dictionary) -> Dictionary:
	var props: Array = []
	# --- partitions between the street and the four buildings ---------------
	props.append(_p("n_wall_w", [0.45, 13, 7, 13.5], FLAT, C_THEATRE))
	props.append(_p("n_wall_mid", [9, 13, 41.5, 13.5], FLAT, C_STREET))
	props.append(_p("n_wall_e", [44, 13, 47.55, 13.5], FLAT, C_TANK))
	props.append(_p("s_wall_w", [0.45, 20.5, 6, 21], FLAT, C_TOWER))
	props.append(_p("s_wall_mid", [8.5, 20.5, 39.5, 21], FLAT, C_STREET))
	props.append(_p("s_wall_e", [42, 20.5, 47.55, 21], FLAT, C_LAB))
	# --- projection house | tank stage, with shutter A ----------------------
	props.append(_p("div_n", [17, 0.45, 17.5, 8.5], FLAT, C_THEATRE))
	props.append(_p("div_s", [17, 10.5, 17.5, 13], FLAT, C_THEATRE))
	props.append(_p("gate_a", [17, 8.5, 17.5, 10.5], 1.9, [0.80, 0.42, 0.12]))
	props.append(_p("latch_a", [17.5, 7.2, 17.75, 7.8], 1.4, [0.92, 0.80, 0.20]))
	# --- editing tower | freight lift | lab, with shutter B -----------------
	props.append(_p("tower_e_n", [16, 21, 16.5, 29], FLAT, C_TOWER))
	props.append(_p("tower_e_s", [16, 31, 16.5, 35.55], FLAT, C_TOWER))
	props.append(_p("gate_b", [16, 29, 16.5, 31], 1.9, [0.80, 0.42, 0.12]))
	props.append(_p("lift_wall_n", [16.5, 27.5, 25.5, 28], FLAT, C_LIFT))
	props.append(_p("lift_wall_s", [16.5, 32, 25.5, 32.5], FLAT, C_LIFT))
	props.append(_p("lift_plate", [16.5, 28, 25.5, 32], 0.04, [0.50, 0.42, 0.12], false))
	props.append(_p("latch_b", [17.2, 28, 17.8, 28.25], 1.4, [0.92, 0.80, 0.20]))
	props.append(_p("lift_headframe", [17, 21.5, 25, 27], 2.7, [0.30, 0.27, 0.16]))
	props.append(_p("lift_counterweight", [17, 33, 25, 35], 1.6, [0.26, 0.24, 0.16]))
	props.append(_p("lab_w_n", [25.5, 21, 26, 28], FLAT, C_LAB))
	props.append(_p("lab_w_s", [25.5, 32, 26, 35.55], FLAT, C_LAB))
	# --- projection house ----------------------------------------------------
	props.append(_p("screen", [1, 3.5, 1.25, 9.5], 3.8, [0.63, 0.60, 0.50]))
	for i in 3:
		var x := 4.0 + 2.0 * i
		props.append(_p("seats_%d" % i, [x, 3.5, x + 0.6, 9.5], 0.5, [0.36, 0.10, 0.12]))
	props.append(_p("projector", [12, 6, 13, 7], 1.25, [0.26, 0.29, 0.31]))
	# --- tank stage: three lanes west, two gaps between the tanks -----------
	props.append(_p("tank_e_n", [34, 3, 40, 6], 0.85, C_TANK))
	props.append(_p("tank_e_s", [34, 7.4, 40, 10.4], 0.85, C_TANK))
	props.append(_p("tank_w_n", [24, 3, 30, 6], 0.85, C_TANK))
	props.append(_p("tank_w_s", [24, 7.4, 30, 10.4], 0.85, C_TANK))
	props.append(_p("img_tank", [19.5, 3, 20.3, 3.8], 0.8, C_PED))
	props.append(_p("snd_tank", [31.6, 9, 32.4, 9.8] if v.tank_sound_south else [31.6, 3.6, 32.4, 4.4], 0.8, C_PED))
	# --- developing lab: two baffles make a zigzag east to west -------------
	props.append(_p("baffle_e", [36, 21, 36.5, 31], FLAT, C_LAB))
	props.append(_p("baffle_w", [31, 25.5, 31.5, 35.55], FLAT, C_LAB))
	props.append(_p("bath", [43, 24, 46, 26], 0.7, [0.10, 0.34, 0.34]))
	props.append(_p("img_lab", [27, 33.8, 27.8, 34.6], 0.8, C_PED))
	props.append(_p("snd_lab", [32, 33.8, 32.8, 34.6] if v.lab_sound_mid else [45.5, 33.5, 46.3, 34.3], 0.8, C_PED))
	# --- exterior street ------------------------------------------------------
	props.append(_p("truck", [20, 14.1, 26, 16.5] if v.truck_north else [20, 17.5, 26, 19.9], 1.8, [0.55, 0.50, 0.18]))
	props.append(_p("lamp_0", [14.8, 13.55, 15.1, 13.85], 2.7, [0.12, 0.12, 0.13]))
	props.append(_p("lamp_1", [32.8, 13.55, 33.1, 13.85], 2.7, [0.12, 0.12, 0.13]))
	props.append(_p("lamp_2", [29.8, 20.15, 30.1, 20.45], 2.7, [0.12, 0.12, 0.13]))
	props.append(_p("img_street", [46, 16.6, 46.8, 17.4], 0.8, C_PED))
	props.append(_p("snd_street", [1.2, 16.6, 2, 17.4], 0.8, C_PED))
	# --- editing tower --------------------------------------------------------
	props.append(_p("bench", [2, 33, 6, 34.2], 0.95, [0.20, 0.26, 0.40]))
	props.append(_p("vault", [12, 22, 15, 25], 2.8, [0.18, 0.22, 0.34]))
	props.append(_p("splicer", [1, 23, 2, 27], 0.8, [0.22, 0.24, 0.30]))

	var dolly_z := 18.6 if v.truck_north else 15.4
	var diver_z := 1.7 if v.diver_north else 11.7
	return {
		"size": SIZE, "spawn": [4, 25],
		"walls": [[0, 0, 48, 0.45], [0, 35.55, 48, 36], [0, 0, 0.45, 36], [47.55, 0, 48, 36]],
		"props": props, "evidence": [],
		"npcs": [
			{"id": "dolly_crew", "route": [[12, dolly_z], [36, dolly_z]], "speed": 1.6, "mode": "pingpong"},
			{"id": "safety_diver", "route": [[22, diver_z], [40, diver_z]], "speed": 1.4, "mode": "pingpong"},
			{"id": "lab_tech", "route": [[33.75, 23], [33.75, 34]], "speed": 1.5, "mode": "pingpong"},
		],
	}
