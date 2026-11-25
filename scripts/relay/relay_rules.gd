extends RefCounted
## Relay progression is separate from campaign saves. Mode selection and all
## consumables are session-only; the highest unlocked difficulty is permanent.
const _PATH := "user://rcd/relay_progress.cfg"
const _META_PATH := "user://rcd/relay_meta.cfg"
const _VERSION := 1
const _META_VERSION := 1
const _MARK := [6, 6, 3]
const _CUT := [3, 3, 2]
static var selected_mode: int = 0

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
	var out := {"runs": 0, "best_set": 0, "deaths": 0, "wins": 0, "last_seed": 0}
	if not FileAccess.file_exists(_META_PATH): return out
	var cfg := ConfigFile.new()
	if cfg.load(_META_PATH) != OK: return out
	if int(cfg.get_value("meta", "version", 0)) != _META_VERSION: return out
	for key: String in out.keys():
		out[key] = int(cfg.get_value("meta", key, 0))
	return out


static func record_run(sets: int, deaths: int, won: bool, seed: int) -> Dictionary:
	var m := meta()
	m["runs"] = int(m["runs"]) + 1
	m["best_set"] = maxi(int(m["best_set"]), sets)
	m["deaths"] = int(m["deaths"]) + deaths
	m["wins"] = int(m["wins"]) + (1 if won else 0)
	m["last_seed"] = seed
	# Read before writing: this file also carries the daily best, and a records
	# write that starts from a blank ConfigFile would quietly delete it.
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(_META_PATH): cfg.load(_META_PATH)
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
	cfg.set_value("daily", "key", key)
	cfg.set_value("daily", "best", best)
	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_META_PATH.get_base_dir()))
	if err == OK: err = cfg.save(_META_PATH)
	if err != OK: push_warning("Daily best could not be saved: %s" % error_string(err))
	return best
