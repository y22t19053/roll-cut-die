extends Node
## The Bilibili TOY SDK, wrapped so nothing else in the game touches JavaScript.
##
## Everything here is a request with a deadline. The platform can be slow, absent
## (desktop, itch, the editor), or refusing (a preview page is not allowed to
## write), and the game has to keep playing in all three cases: a leaderboard is
## a reason to come back tomorrow, never a thing that can stop a run from ending.
##
## The SDK is a global injected by the host page (`window.Toy`, with the callable
## instance on `.toy`). Its boards are numbered 1..5 and a score must be an
## integer inside +/- 2^24, so the game maps one board per difficulty and never
## sends fractions.

signal ranks_ready(rows: Array, mine: Dictionary)
signal score_sent(ok: bool, mine: Dictionary, message: String)

## About four seconds at 60 fps. Long enough for a slow phone, short enough that
## nobody is left staring at a sheet that will never finish.
const POLL_FRAMES := 240

var _busy := false
var _pending := ""      # "send" | "peek"
var _frames := 0
var _last_message := ""

static func available() -> bool:
	if not OS.has_feature("web"): return false
	var probe: Variant = JavaScriptBridge.eval(
		"!!(window.Toy && (window.Toy.toy || window.Toy.Toy || window.Toy))", true)
	return probe is bool and bool(probe)


## The installer is idempotent: it keeps whatever result the last call produced
## and adds two polled slots, so GDScript only ever reads a small JSON string.
const _INSTALL := """
(function () {
	if (window.__rcd) { return; }
	var wrap = function (v) {
		return (v && typeof v.then === 'function') ? v : Promise.resolve(v);
	};
	var api = function () {
		return (window.Toy && (window.Toy.toy || window.Toy.Toy || window.Toy)) || null;
	};
	var fail = function (out, e) {
		out.done = true;
		out.ok = false;
		out.code = (e && e.code) || 0;
		out.message = String((e && e.message) || e || '');
	};
	var mineThen = function (a, out, board, period, limit) {
		return wrap(a.getMyRank({board: board, period: period})).then(function (mine) {
			out.mine = mine;
			return wrap(a.getRankList({board: board, period: period, limit: limit}));
		}).then(function (list) {
			out.list = list;
			out.done = true;
			out.ok = true;
		}).catch(function (e) { fail(out, e); });
	};
	window.__rcd = {
		peek: function (board, period, limit) {
			var a = api();
			var out = window.__rcdPeek = {done: false, ok: false};
			if (!a) { out.done = true; out.message = 'no sdk'; return; }
			mineThen(a, out, board, period, limit);
		},
		send: function (board, score, period, limit) {
			var a = api();
			var out = window.__rcdOut = {done: false, ok: false};
			if (!a) { out.done = true; out.message = 'no sdk'; return; }
			wrap(a.submitScore({board: board, score: score}))
				.then(function () { return mineThen(a, out, board, period, limit); })
				.catch(function (e) { fail(out, e); });
		},
		read: function () { return JSON.stringify(window.__rcdOut || null); },
		readPeek: function () { return JSON.stringify(window.__rcdPeek || null); }
	};
})();
"""


func probe_ranks(board: int, period: String = "day", limit: int = 5) -> void:
	if not available(): return
	if not _install(): return
	var ok: Variant = _js("window.__rcd.peek(%d, %s, %d); true" % [board, _q(period), limit])
	if ok == null: return
	_pending = "peek"
	_start_poll()


func send_score(board: int, score: int, period: String = "day", limit: int = 5) -> void:
	if not available(): return
	if not _install(): return
	# The platform takes integers inside +/- 2^24 and nothing else.
	var clean_score := clampi(score, -16777216, 16777215)
	var ok: Variant = _js("window.__rcd.send(%d, %d, %s, %d); true" % [board, clean_score, _q(period), limit])
	if ok == null: return
	_pending = "send"
	_start_poll()


func is_busy() -> bool:
	return _busy


func last_message() -> String:
	return _last_message


func _start_poll() -> void:
	_busy = true
	_frames = 0
	set_process(true)


func _process(_dt: float) -> void:
	if not _busy:
		set_process(false)
		return
	_frames += 1
	var raw: Variant = _js("window.__rcd.read()" if _pending == "send" else "window.__rcd.readPeek()")
	var data: Variant = JSON.parse_string(str(raw)) if raw != null else null
	if data is Dictionary and bool((data as Dictionary).get("done", false)):
		_finish(data as Dictionary)
	elif _frames > POLL_FRAMES:
		_finish({"ok": false, "message": "timeout"})


func _finish(data: Dictionary) -> void:
	_busy = false
	set_process(false)
	var ok := bool(data.get("ok", false))
	_last_message = str(data.get("message", ""))
	var mine := _row(data.get("mine", {}))
	var rows := _rows(data.get("list", []))
	if _pending == "send":
		score_sent.emit(ok, mine, _last_message)
	else:
		ranks_ready.emit(rows, mine)
	_pending = ""


## The platform's entry shape is not ours to assume: read the few keys that make
## sense for a board and leave everything else alone.
func _row(v: Variant) -> Dictionary:
	if not v is Dictionary: return {}
	var d: Dictionary = v
	var nick := str(d.get("nickname", d.get("name", d.get("uname", ""))))
	var user: Variant = d.get("user", null)
	if nick.is_empty() and user is Dictionary:
		var u: Dictionary = user
		nick = str(u.get("nickname", u.get("name", u.get("uname", ""))))
	return {"rank": int(d.get("rank", 0)), "score": int(d.get("score", 0)), "name": nick}


func _rows(v: Variant) -> Array:
	var out: Array = []
	if not v is Array: return out
	for entry: Variant in v:
		var r := _row(entry)
		if not r.is_empty(): out.append(r)
	return out


func _install() -> bool:
	var ok: Variant = _js(_INSTALL + "\ntrue")
	return ok != null


func _js(code: String) -> Variant:
	if not OS.has_feature("web"): return null
	return JavaScriptBridge.eval(code, true)


static func _q(s: String) -> String:
	return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"") + "\""