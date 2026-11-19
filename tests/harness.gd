extends RefCounted
## Harness — the entire test framework, on purpose.
##
## Godot has no built-in test runner worth the setup cost, and the project rule
## is to reuse what already works: a SceneTree script that prints RESULT n/n and
## exits non-zero on failure. That is enough to gate a commit.

var passed := 0
var failed := 0
var module := ""


func begin(name: String) -> void:
	module = name
	print("--- ", name)


static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func ok(name: String, cond: bool, detail := "") -> void:
	if cond:
		passed += 1
		return
	failed += 1
	var msg := "%s: %s" % [module, name]
	if detail != "":
		msg += "  [" + detail + "]"
	print("FAIL ", msg)


func eq(name: String, got: Variant, want: Variant) -> void:
	ok(name, got == want, "got %s want %s" % [str(got), str(want)])


func near(name: String, got: float, want: float, eps := 0.001) -> void:
	ok(name, absf(got - want) <= eps, "got %.5f want %.5f (eps %.5f)" % [got, want, eps])


func at_least(name: String, got: float, floor_v: float) -> void:
	ok(name, got >= floor_v, "got %.4f needs >= %.4f" % [got, floor_v])


func at_most(name: String, got: float, ceil_v: float) -> void:
	ok(name, got <= ceil_v, "got %.4f needs <= %.4f" % [got, ceil_v])


## Informational line: a measurement the doc will quote, not a verdict.
func note(msg: String) -> void:
	print("NOTE ", msg)


func finish() -> void:
	print("RESULT %s %d/%d" % [module, passed, passed + failed])
