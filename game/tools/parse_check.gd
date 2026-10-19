extends Node

## Fast check: loads every script / scene (autoloads active), prints PARSE_OK.
##   godot --headless --path game res://tools/parse_check.tscn


func _ready() -> void:
	var bad := 0
	for path in _walk("res://scripts") + _walk("res://scenes") + _walk("res://tools"):
		if not (path.ends_with(".gd") or path.ends_with(".tscn")) or path.ends_with("parse_check.tscn"):
			continue
		if ResourceLoader.load(path) == null:
			print("FAIL load ", path)
			bad += 1
	print("PARSE_OK" if bad == 0 else "PARSE_FAIL %d" % bad)
	get_tree().quit()


func _walk(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		out.append(dir + "/" + f)
	for sub in d.get_directories():
		out.append_array(_walk(dir + "/" + sub))
	return out
