extends Node
## Loads every script and scene so parse errors show up in one run.
##   godot --headless --path game res://tests/check_scripts.tscn

func _ready() -> void:
	var bad := 0
	for path in _walk("res://"):
		if path.begins_with("res://.godot") or path.begins_with("res://tests/"):
			continue
		if path.ends_with(".gd") or path.ends_with(".gdshader"):
			var r := load(path)
			if r == null or (r is GDScript and not (r as GDScript).can_instantiate() and not path.begins_with("res://tools")):
				print("FAILED: ", path)
				bad += 1
	print("checked scripts, failures: ", bad)
	get_tree().quit(1 if bad > 0 else 0)


func _walk(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with("."):
			continue
		out.append_array(_walk(dir.path_join(d)))
	return out
