extends SceneTree

## Prüft, ob der Player im Baum ankommt und Animationen mitbringt.
## Aufruf: godot --headless --path . -s res://tests/inspect_player.gd

const SCENE: String = "res://tests/player_runtime.tscn"


func _init() -> void:
	var packed := load(SCENE) as PackedScene
	if packed == null:
		printerr("Szene nicht ladbar")
		quit(1)
		return

	var instance := packed.instantiate()
	root.add_child(instance)

	await process_frame
	await process_frame
	await physics_frame
	await physics_frame

	var player := instance.get_node_or_null("Player")
	if player == null:
		printerr("Kein Player-Knoten")
		quit(1)
		return

	print("Player-Klasse: ", player.get_class(), " / Skript: ", player.get_script().resource_path if player.get_script() else "-")
	print("Position nach 2 Physik-Frames: ", player.global_position)
	print("Kinder: ", player.get_children().map(func(c): return c.name))

	var anim := player.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim == null:
		printerr("Kein AnimationPlayer gefunden")
		quit(1)
		return

	var names := anim.get_animation_list()
	print("Animationen: ", names.size())
	for n in names.slice(0, 10):
		print("  - ", n)

	quit(0)
