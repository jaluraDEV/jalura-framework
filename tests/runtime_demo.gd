extends SceneTree

## Lädt das Demo-Level in einen echten Baum und prüft Aufbau und Objekte.
## Aufruf: godot --headless --path . -s res://tests/runtime_demo.gd

const SCENE: String = "res://scenes/demo/demo_level.tscn"


func _init() -> void:
	var packed := load(SCENE) as PackedScene
	if packed == null:
		printerr("Demo-Level nicht ladbar")
		quit(1)
		return

	var level := packed.instantiate()
	root.add_child(level)

	await process_frame
	await physics_frame
	await physics_frame

	var player := level.find_child("Player", true, false)
	var hud := level.find_child("HUD", true, false)
	var bodies := level.find_children("*", "StaticBody3D", true, false)
	var pickups := level.find_children("*", "PickableItem", true, false)

	print("Player: ", player != null, " | HUD: ", hud != null)
	print("Statische Körper: ", bodies.size())
	print("Pickups: ", pickups.size())
	if player:
		print("Player-Position: ", player.global_position)
	if pickups.size() > 0:
		print("Pickup-Item: ", pickups[0].get("item_id"))

	var ok := player != null and hud != null and bodies.size() >= 10 and pickups.size() >= 2
	print("DEMO OK: ", ok)
	quit(0 if ok else 1)
