extends SceneTree

## Rauchtest: lädt und instanziiert alle Prefabs und Einzelszenen.
## Aufruf: godot --headless --path . -s res://tests/smoke_prefabs.gd

const PREFAB_DIRS: Array[String] = ["res://scenes/objects", "res://scenes/ui", "res://scenes/items"]
const SINGLE_SCENES: Array[String] = ["res://scenes/player.tscn", "res://scenes/demo/demo_level.tscn", "res://scenes/demo/ship_cabin.tscn"]


func _init() -> void:
	var failed := 0
	var checked := 0
	var paths: Array[String] = []

	for dir in PREFAB_DIRS:
		for file_name in DirAccess.get_files_at(dir):
			if file_name.ends_with(".tscn"):
				paths.append(dir + "/" + file_name)
	paths.append_array(SINGLE_SCENES)

	for path in paths:
		checked += 1
		var packed := load(path) as PackedScene
		if packed == null:
			printerr("LOAD FAIL   ", path)
			failed += 1
			continue
		var instance := packed.instantiate()
		if instance == null:
			printerr("INSTANTIATE FAIL   ", path)
			failed += 1
			continue
		print("OK   ", path.get_file())
		instance.free()

	print("Szenen geprüft: %d, fehlgeschlagen: %d" % [checked, failed])
	quit(1 if failed > 0 else 0)
