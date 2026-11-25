extends RefCounted
## Relay progression is separate from campaign saves. Mode selection and all
## consumables are session-only; the highest unlocked difficulty is permanent.
const Loc = preload("res://scripts/core/loc.gd")
const MODULES := 16
const _PATH := "user://rcd/relay_progress.cfg"
const _META_PATH := "user://rcd/relay_meta.cfg"
const _VERSION := 1
const _META_VERSION := 2
const _META_DEFAULTS := {
	"runs": 0, "best_set": 0, "deaths": 0, "wins": 0, "last_seed": 0,
	"marks_total": 0, "cuts_total": 0, "truth": 0, "coverup": 0, "frameup": 0,
}
## The suite drives real scenes, and a real scene ends a real run: without this
## gate the archive would count test runs as the player's career. Tests that need
## the write path flip it back on with their own user directory. Set through a
## function because a static var cannot be assigned through a preloaded script.
static var recording_enabled := true


static func set_recording(on: bool) -> bool:
	recording_enabled = on
	return recording_enabled
const _ARCHIVE_NAMES := [
	{"en": "Empty Archive", "zh": "空档案"},
	{"en": "Clapperboard", "zh": "场记板"},
	{"en": "Second Assistant", "zh": "第二助理"},
	{"en": "First Assistant", "zh": "第一助理"},
	{"en": "Lead Controller", "zh": "主控"},
]
const _VERDICT_KEYS := {
	"file_closed": "truth", "bury_registered": "coverup", "reframe_held": "frameup",
}
const _ARCHIVE_THRESHOLDS := [3, 9, 21, 41]
const _MARK := [6, 6, 3]
const _CUT := [3, 3, 2]
const _PACE := [1.0, 0.92, 0.84]
const _WARNING_SCALE := [1.0, 0.85, 0.7]
static var selected_mode: int = 0

static func pace(mode: int) -> float:
	return _PACE[mode] if mode >= 0 and mode < _PACE.size() else _PACE[0]

static func warning_scale(mode: int) -> float:
	return _WARNING_SCALE[mode] if mode >= 0 and mode < _WARNING_SCALE.size() else _WARNING_SCALE[0]

static func mark_budget(mode: int) -> int:
	return _MARK[mode] if mode >= 0 and mode < _MARK.size() else 0

static func cut_budget(mode: int) -> int:
	return _CUT[mode] if mode >= 0 and mode < _CUT.size() else 0

static func unlocked(mode: int) -> bool:
	return _unlocked_at(mode, _PATH)

static func record_clear(mode: int) -> void:
	_record_clear_at(mode, _PATH)

## -1 denotes unreadable or unrecognised data. Allow novice play without
## overwriting a file written by another version of the game.
static func _highest(path: String) -> int:
	if not FileAccess.file_exists(path): return 0
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK: return -1
	var version: Variant = cfg.get_value("relay", "version", null)
	if typeof(version) != TYPE_INT or version != _VERSION: return -1
	var highest: Variant = cfg.get_value("relay", "highest_unlocked", -1)
	if typeof(highest) != TYPE_INT or highest < 0 or highest > 2: return -1
	return int(highest)

static func _unlocked_at(mode: int, path: String) -> bool:
	return mode == 0 or (mode > 0 and mode <= 2 and mode <= _highest(path))

static func _record_clear_at(mode: int, path: String) -> void:
	if mode < 0 or mode >= 2: return # Master has no further unlock.
	var highest := _highest(path)
	if mode != highest: return # Locked, replayed, or an unknown save format.
	var cfg := ConfigFile.new()
	cfg.set_value("relay", "version", _VERSION)
	cfg.set_value("relay", "highest_unlocked", mode + 1)
	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if err == OK: err = cfg.save(path)
	if err != OK: push_warning("Relay unlock could not be saved: %s" % error_string(err))


## What the player has already done, kept between sessions. Nothing in here makes
## a run easier: it is a record, not a reward. Supplies stay per-run and per-mode.
static func meta() -> Dictionary:
	return _meta_from_config(_load_meta_config())


static func merge_meta(raw: Dictionary) -> Dictionary:
	var out := _META_DEFAULTS.duplicate()
	for key: String in out:
		var value: Variant = raw.get(key, 0)
		if typeof(value) == TYPE_INT:
			out[key] = value
	return out


static func archive_rank(marks_total: int) -> int:
	for rank: int in _ARCHIVE_THRESHOLDS.size():
		if marks_total < _ARCHIVE_THRESHOLDS[rank]:
			return rank
	return _ARCHIVE_THRESHOLDS.size()


## How many more marks the archive needs for the next rank; 0 at the top rank.
static func archive_next_gap(marks_total: int) -> int:
	var rank := archive_rank(marks_total)
	if rank == _ARCHIVE_THRESHOLDS.size():
		return 0
	return _ARCHIVE_THRESHOLDS[rank] - maxi(marks_total, 0)


static func archive_name(rank: int) -> String:
	return Loc.t(_ARCHIVE_NAMES[clampi(rank, 0, _ARCHIVE_NAMES.size() - 1)])


static func _load_meta_config() -> ConfigFile:
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(_META_PATH) and cfg.load(_META_PATH) != OK:
		cfg.clear()
	return cfg


static func _meta_from_config(cfg: ConfigFile) -> Dictionary:
	var version: Variant = cfg.get_value("meta", "version", 0)
	if typeof(version) != TYPE_INT or (version != 1 and version != _META_VERSION):
		return merge_meta({})
	var raw := {}
	for key: String in cfg.get_section_keys("meta"):
		raw[key] = cfg.get_value("meta", key)
	return merge_meta(raw)


static func record_run(sets: int, deaths: int, won: bool, seed: int) -> Dictionary:
	return record_run_full(sets, deaths, won, seed, 0, 0, "")


static func record_run_full(sets: int, deaths: int, won: bool, seed: int, marks: int, cuts: int, verdict: String) -> Dictionary:
	if not recording_enabled: return meta()
	var cfg := _load_meta_config()
	var m := _meta_from_config(cfg)
	m["runs"] = int(m["runs"]) + 1
	m["best_set"] = maxi(int(m["best_set"]), sets)
	m["deaths"] = int(m["deaths"]) + deaths
	m["wins"] = int(m["wins"]) + (1 if won else 0)
	m["last_seed"] = seed
	m["marks_total"] += marks
	m["cuts_total"] += cuts
	_add_verdict(m, verdict)
	return _write_meta(cfg, m)


static func record_verdict(verdict: String) -> Dictionary:
	if not recording_enabled: return meta()
	var cfg := _load_meta_config()
	var m := _meta_from_config(cfg)
	if _add_verdict(m, verdict):
		return _write_meta(cfg, m)
	return m


static func _add_verdict(m: Dictionary, verdict: String) -> bool:
	var key: String = _VERDICT_KEYS.get(verdict, "")
	if key.is_empty():
		return false
	m[key] += 1
	return true


static func _write_meta(cfg: ConfigFile, m: Dictionary) -> Dictionary:
	# Read before writing: this file also carries the daily best, and a records
	# write that starts from a blank ConfigFile would quietly delete it.
	cfg.set_value("meta", "version", _META_VERSION)
	for key: String in m.keys():
		cfg.set_value("meta", key, m[key])
	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_META_PATH.get_base_dir()))
	if err == OK: err = cfg.save(_META_PATH)
	if err != OK: push_warning("Relay record could not be saved: %s" % error_string(err))
	return m


## One seed a day, the same for everyone: the only run two people can argue about.
## The day is counted in Beijing time because that is the clock the Bilibili board
## resets on; a map that turns over at a different moment than the board would be
## two different competitions wearing one name.
const DAY_OFFSET := 8 * 3600

static func daily_key() -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + DAY_OFFSET)
	return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]

static func daily_seed() -> int:
	return daily_seed_for(daily_key())

## Same date in, same map out, on every machine. FNV-1a folded to 24 bits and
## kept off zero, because zero is the "pick your own seed" sentinel.
static func daily_seed_for(key: String) -> int:
	var h := 2166136261
	for i in key.length():
		h = (h ^ key.unicode_at(i)) & 0xFFFFFFFF
		h = (h * 16777619) & 0xFFFFFFFF
	return maxi(int(h & 0xFFFFFF), 1)

static func daily_played() -> bool:
	return int(meta().get("last_seed", 0)) == daily_seed()


## What a run is worth. Every term is something the player did, not something the
## game handed over: legs are takes actually taken, acts are sets that got signed,
## a clean run pays once, and deaths and spent cuts are the only things that cost.
## Time is free until the clock is out, so a careful run is never worth less than
## a rushed one.
const SCORE_LEG := 40
const SCORE_ACT := 120
const SCORE_CLEAN := 250
const SCORE_DEATH := -80
const SCORE_CUT := -20
const SCORE_GRACE := 480.0
## Per second past the grace window, rounded up by the int() truncation below.
const SCORE_OVERTIME := -1.0

static func run_score(legs: int, acts: int, deaths: int, cuts: int, seconds: float, clean: bool) -> Dictionary:
	var base := legs * SCORE_LEG + acts * SCORE_ACT + (SCORE_CLEAN if clean else 0)
	var cost := deaths * SCORE_DEATH + cuts * SCORE_CUT
	var over := int(maxf(seconds - SCORE_GRACE, 0.0) * SCORE_OVERTIME)
	return {
		"total": maxi(base + cost + over, 0),
		"legs": legs, "acts": acts, "deaths": deaths, "cuts": cuts,
		"clean": clean, "seconds": seconds, "overtime": over,
	}

## The platform's boards are numbered, not named: 1..5, defaulting to 1. One board
## per difficulty keeps a novice run from being ranked against a master run.
static func board_for(mode: int) -> int:
	return clampi(mode + 1, 1, 5)

## A local copy of the day's best, so the title screen has something to say when
## the network, the SDK or the platform says nothing.
static func daily_best() -> int:
	if not FileAccess.file_exists(_META_PATH): return 0
	var cfg := ConfigFile.new()
	if cfg.load(_META_PATH) != OK: return 0
	if str(cfg.get_value("daily", "key", "")) != daily_key(): return 0
	return int(cfg.get_value("daily", "best", 0))

static func record_daily(score: int) -> int:
	var key := daily_key()
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(_META_PATH): cfg.load(_META_PATH)
	var best := 0
	if str(cfg.get_value("daily", "key", "")) == key:
		best = int(cfg.get_value("daily", "best", 0))
	best = maxi(best, score)
	if not recording_enabled: return best
	cfg.set_value("daily", "key", key)
	cfg.set_value("daily", "best", best)
	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_META_PATH.get_base_dir()))
	if err == OK: err = cfg.save(_META_PATH)
	if err != OK: push_warning("Daily best could not be saved: %s" % error_string(err))
	return best
